class BotBalancerMutator extends UTMutator
	config(BotBalancer);

`if(`notdefined(FINAL_RELEASE))
	var bool bShowDebug;

	var bool bDebugSwitchToSpectator;
`endif

//**********************************************************************************
// Workflow variables
//**********************************************************************************

/** Readonly. Set when match has started (MatchStarting was called) */
var bool bMatchStarted;

var bool bForcDesiredPlayerCount;
var int DesiredPlayerCount;

var bool bOriginalForceAllRed;

var private UTTeamGame CacheGame;
var private class<UTBot> CacheBotClass;
var private array<UTBot> BotsWaitForRespawn;
var private array<UTBot> BotsSetOrders;

/** Used to track down spawned bots within the custom addbots code */
var private array<UTBot> BotsSpawnedOnce;

//**********************************************************************************
// Config
//**********************************************************************************

var() config bool UseLevelRecommendation;
var() config bool PlayersVsBots;
var() config byte PlayersSide;
var() config float BotRatio;

//**********************************************************************************
// Inherited functions
//**********************************************************************************

function bool MutatorIsAllowed()
{
	//only allow mutator in Team games (except Duel)
	return UTTeamGame(WorldInfo.Game) != None && UTDuelGame(WorldInfo.Game) == None && Super.MutatorIsAllowed();
}

function InitMutator(string Options, out string ErrorMessage)
{
	`Log(name$"::InitMutator - Options:"@Options,,'BotBalancer');
	super.InitMutator(Options, ErrorMessage);

	CacheGame = UTTeamGame(WorldInfo.Game);
	if (CacheGame == none)
	{
		Destroy();
		return;
	}

	// set bot class to a null class (abstract) which prevents
	// bots being spawned by commands like (addbots, addbluebots,...)
	// but also timed by NeedPlayers in GameInfo::Timer
	CacheBotClass = CacheGame.BotClass;
	CacheGame.BotClass = class'BotBalancerNullBot';

	// Disable auto balancing of bot teams.
	CacheGame.bCustomBots = true;

	//@TODO: check if needed
	// override
	//CacheGame.bPlayersVsBots = PlayersVsBots;
	//CacheGame.BotRatio = BotRatio;
}

// called when gameplay actually starts
function MatchStarting()
{
	`Log(name$"::MatchStarting",,'BotBalancer');
	super.MatchStarting();

	if (CacheGame == none)
		return;

	if (UseLevelRecommendation)
	{
		CacheGame.bAutoNumBots = true;
		DesiredPlayerCount = CacheGame.LevelRecommendedPlayers();
		bForcDesiredPlayerCount = true;
	}
	else if (CacheGame.HasOption(CacheGame.ServerOptions, "NumPlay"))
	{
		// clear desired player count which then uses
		// the Game's desired value in the next timer
		DesiredPlayerCount = 0;
	}
	else
	{
		// just cache desired player count, also prevents adding bots at start
		DesiredPlayerCount = CacheGame.DesiredPlayerCount;
	}

	bMatchStarted = true;
	SetTimer(1.0, true, 'TimerCheckPlayerCount');
}

`if(`notdefined(FINAL_RELEASE))
function NotifyLogin(Controller NewPlayer)
{
	local PlayerController PC;

	`Log(name$"::NotifyLogin - NewPlayer:"@NewPlayer,,'BotBalancer');
	super.NotifyLogin(NewPlayer);

	PC = PlayerController(NewPlayer);
	if (PC != none && PC.bIsPlayer && PC.PlayerReplicationInfo != none)
	{
		if (bDebugSwitchToSpectator && PC.IsLocalPlayerController())
		{
			PC.PlayerReplicationInfo.bIsSpectator = true;
			PC.PlayerReplicationInfo.bOnlySpectator = true;
			PC.PlayerReplicationInfo.bOutOfLives = true;

			if (UTPlayerController(PC) != none)
			{
				UTPlayerController(PC).ServerSpectate();
				PC.ClientGotoState('Spectating');
			}
			else
			{
				PC.GotoState('Spectating');
				PC.ClientGotoState('Spectating');
			}

			PC.UpdateURL("SpectatorOnly", "1", false);
		}
	}
}
`endif

function NotifyLogout(Controller Exiting)
{
	`Log(name$"::NotifyLogout - Exiting:"@Exiting,,'BotBalancer');
	super.NotifyLogout(Exiting);
	BotsSpawnedOnce.RemoveItem(UTBot(Exiting));

	if (bMatchStarted && UTBot(Exiting) == none)
	{
		BalanceBotsTeams();
	}
}

/* called by GameInfo.RestartPlayer()
	change the players jumpz, etc. here
*/
function ModifyPlayer(Pawn Other)
{
	local UTBot bot;
	local BotBalancerHelperPawnDeath pd;

	`Log(name$"::ModifyPlayer - Other:"@Other,,'BotBalancer');
	super.ModifyPlayer(Other);

	if (Other == none || UTBot(Other.Controller) == none) return;
	bot = UTBot(Other.Controller);

	foreach Other.BasedActors(class'BotBalancerHelperPawnDeath', pd)
		break;

	if (pd == none)
	{
		// attach helper which trigger events fro death. this is used to revert bSpawnedByKismet and set bForceAllRed
		pd = Other.Spawn(class'BotBalancerHelperPawnDeath');
		pd.SetPlayerDeathDelegate(OnBotDeath_PreCheck, OnBotDeath_PostCheck);
		pd.SetBase(Other);
	}

	// prevents from calling TooManyBots whenever the bot idles
	// (and also from checking for too many bots or unbalanced teams)
	bot.bSpawnedByKismet = true;

	
	if (BotsWaitForRespawn.Length > 0)
	{
		// remove spawning bot from array
		BotsWaitForRespawn.RemoveItem(bot);
		// also remove invalid references, just in case
		BotsWaitForRespawn.RemoveItem(none);

		// cache bot to re-set orders
		BotsSetOrders.AddItem(bot);

		// revert to original if all bots respawned (at least once)
		if (BotsWaitForRespawn.Length < 1)
		{
			CacheGame.bForceAllRed = bOriginalForceAllRed;

			// re-set all bot orders for spawned bots
			ResetBotOrders(BotsSetOrders);

			// clear cache as all orders are set
			BotsSetOrders.Length = 0;
		}
	}

	// add bots to array of spawned bots
	if (BotsSpawnedOnce.Find(bot) == INDEX_NONE)
	{
		BotsSpawnedOnce.AddItem(bot);
	}
}

function bool AllowChangeTeam(Controller Other, out int num, bool bNewTeam)
{
	if (super.AllowChangeTeam(Other, num, bNewTeam))
	{
		if (PlayersVsBots)
		{
			// disallow changing team if PlayersVsBots is set
			if (bNewTeam && num != PlayersSide)
			{
				PlayerController(Other).ReceiveLocalizedMessage(class'UTTeamGameMessage', PlayersSide == 0 ? 1 : 2);
				return false;
			}
			else if (!bNewTeam) // spawning player into the correct 
			{
				num = GetNextTeamIndex(AIController(Other));
			}
		}
	}

	return True;
}

function NotifySetTeam(Controller Other, TeamInfo OldTeam, TeamInfo NewTeam, bool bNewTeam)
{
	`Log(name$"::NotifySetTeam - Other:"@Other$" - OldTeam:"@OldTeam$" - NewTeam:"@NewTeam$" - bNewTeam:"@bNewTeam,,'BotBalancer');
	super.NotifySetTeam(Other, OldTeam, NewTeam, bNewTeam);

	if (bMatchStarted && UTBot(Other) == none)
	{
		BalanceBotsTeams();
	}
}

//**********************************************************************************
// Events
//**********************************************************************************

event TimerCheckPlayerCount()
{
	if (CacheGame == none)
		ClearTimer();

	if (CacheGame.DesiredPlayerCount != DesiredPlayerCount)
	{
		if (bForcDesiredPlayerCount)
		{
			CacheGame.DesiredPlayerCount = DesiredPlayerCount;
			bForcDesiredPlayerCount = false;
		}

		// attempted to add bots through external code, use custom code now
		AddBots(CacheGame.DesiredPlayerCount);

		// clear player count again to stop throw error messages (due to timed NeedPlayers-call)
		DesiredPlayerCount = CacheGame.DesiredPlayerCount;
	}
}

//**********************************************************************************
// Delegate callbacks
//**********************************************************************************

function OnBotDeath_PreCheck(Pawn Other, Object Sender)
{
	local Controller C;
	`log(name$"::OnBotDeath_PreCheck - Other:"@Other$" - Sender:"@Sender,,'BotBalancer');
	
	if (GetController(Other, C) && UTBot(C) != none)
	{
		// revert so bot spawns normally (and does not get destroyed)
		UTBot(C).bSpawnedByKismet = false;
		BotsWaitForRespawn.AddItem(UTBot(C));
	}
	CacheGame.bForceAllRed = true;
}

function OnBotDeath_PostCheck(Pawn Other, Actor Sender)
{
	`log(name$"::OnBotDeath_PostCheck - Other:"@Other$" - Sender:"@Sender,,'BotBalancer');
	//CacheGame.bForceAllRed = false;
}

//**********************************************************************************
// Private functions
//**********************************************************************************

function int GetNextTeamIndex(bool bBot)
{
	local UTTeamInfo BotTeam;
	local name packagename;
	local bool bSwap;

	local int i, index, count, prefer;
	local array<int> PlayersCount, TeamsCount;
	
	if (PlayersVsBots && bBot)
	{
		packagename = CacheGame.class.GetPackageName();
		switch (packagename)
		{
		case 'UTGame':
		case 'UTGameContent':
		case 'UT3GoldGame':
			if (UTDuelGame(CacheGame) != none) // in case, but in general Duel isn't allowed to run this mutator
			{
				//@TODO: add support for Duel
				return 0;
			}
			return Clamp(1 - PlayersSide, 0, 1);
			break;
		default:
			if (WorldInfo.GRI.Teams.Length == 1)
				return WorldInfo.GRI.Teams[0].TeamIndex;
			else if (WorldInfo.GRI.Teams.Length == 2)
				return Clamp(1 - PlayersSide, 0, 1);
			else if (WorldInfo.GRI.Teams.Length > 2)
			{
				//@TODO: add support for MultiTeam (4-teams)
				return PlayersSide;
			}
		}
		
		return 1;
	}
	else if (PlayersVsBots)
	{
		// put net player into the given team
		return PlayersSide;
	}

	if (CacheGame != none)
	{
		if (GetAdjustedTeamPlayerCount(PlayersCount, TeamsCount))
		{
			// find team with lowest real player count (prefer team with lower net players)
			count = MaxInt;
			prefer = 0;
			index = INDEX_NONE;
			for ( i=0; i<TeamsCount.Length; i++)
			{
				if (TeamsCount[i] < count || (TeamsCount[i] == count && PlayersCount[i] < prefer))
				{
					count = TeamsCount[i];
					prefer = PlayersCount[i];
					index = i;
				}
			}

			// if a proper team could be found, use that team
			if (index != INDEX_NONE)
			{
				return index;
			}
		}

		// use original algorthim to find proper team index
		// to prevent using always the Red team, we swap that flag temporarily
		bSwap = CacheGame.bForceAllRed;
		CacheGame.bForceAllRed = false;
		BotTeam = CacheGame.GetBotTeam();
		CacheGame.bForceAllRed = bSwap;

		if (BotTeam != none)
		{
			return BotTeam.TeamIndex;
		}
	}

	return 0;
}

function AddBots(int InDesiredPlayerCount)
{
	local int TeamNum, OldBotCount;
	local UTBot bot;
	local array<UTBot> tempbots;

	OldBotCount = BotsSpawnedOnce.Length;

	// force TooManyBots fail out. it is called right on initial spawn for bots
	bOriginalForceAllRed = CacheGame.bForceAllRed;
	CacheGame.bForceAllRed = true;

	DesiredPlayerCount = Clamp(InDesiredPlayerCount, 1, 32);
	while (CacheGame.NumPlayers + CacheGame.NumBots < DesiredPlayerCount)
	{
		// restore Game's original bot class
		CacheGame.BotClass = CacheBotClass;

		// add bot to the specific team
		TeamNum = GetNextTeamIndex(true);
		bot = CacheGame.AddBot(,true,TeamNum);

		// revert to null class to preven adding bots;
		CacheGame.BotClass = class'BotBalancerNullBot';

		if (bot == none)
			break;
		
		tempbots.AddItem(bot);
		if (BotsSpawnedOnce.Find(bot) == INDEX_NONE)
		{
			BotsWaitForRespawn.AddItem(bot);
		}
	}

	// revert to original if not bot was added to array
	if (BotsWaitForRespawn.Length < 1)
	{
		CacheGame.bForceAllRed = bOriginalForceAllRed;
	}

	if (OldBotCount != BotsSpawnedOnce.Length && !CacheGame.bForceAllRed)
	{
		ResetBotOrders(tempbots);
	}
}

function ResetBotOrders(array<UTBot> bots)
{
	local UTBot bot;

	bots.RemoveItem(none);
	foreach bots(bot)
	{
		if (bot.PlayerReplicationInfo != none && UTTeamInfo(bot.PlayerReplicationInfo.Team) != none)
		{
			UTTeamInfo(bot.PlayerReplicationInfo.Team).SetBotOrders(bot);
		}
	}
}

function BalanceBotsTeams()
{
	local array<int> PlayersCount, TeamsCount;
	local int i;
	local int LowestCount, LowestIndex;
	local int HighestCount, HighestIndex;
	local int SwitchCount, diff;
	local UTBot Bot;
	
	if (GetAdjustedTeamPlayerCount(PlayersCount, TeamsCount))
	{
		// find team with lowest real player count (prefer team with lower net players)
		LowestCount = MaxInt;
		LowestIndex = INDEX_NONE;
		HighestCount = -1;
		HighestIndex = INDEX_NONE;
		for ( i=0; i<TeamsCount.Length; i++)
		{
			if (TeamsCount[i] < LowestCount)
			{
				LowestCount = TeamsCount[i];
				LowestIndex = i;
			}
			if (TeamsCount[i] > HighestCount)
			{
				HighestCount = TeamsCount[i];
				HighestIndex = i;
			}
		}

		if (LowestIndex != INDEX_NONE && HighestIndex != INDEX_NONE && HighestIndex != LowestIndex)
		{
			diff = HighestCount - LowestCount;
			if (diff > 1/* && Abs(PlayersCount[HighestIndex] - PlayersCount[LowestIndex]) > 1*/)
			{
				SwitchCount = diff/2;
			}
		}
	}

	for (i=0; i<SwitchCount; i++)
	{
		// change from highest to lowest team
		if (!GetRandomPlayerByTeam(WorldInfo.GRI.Teams[HighestIndex], bot))
			break;

		SwitchBot(bot, LowestIndex);
	}
}

function SwitchBot(UTBot bot, int TeamNum)
{
	local TeamInfo OldTeam;

	OldTeam = bot.PlayerReplicationInfo.Team;
	CacheGame.ChangeTeam(bot, TeamNum, true);
	if (CacheGame.bTeamGame && bot.PlayerReplicationInfo.Team != OldTeam)
	{
		if (bot.Pawn != None)
		{
			bot.Pawn.PlayerChangedTeam();
		}
	}
}

function bool GetRandomPlayerByTeam(TeamInfo team, out UTBot OutBot)
{
	local int i;
	local array<PlayerReplicationInfo> randoms;
	
	for ( i=0; i<WorldInfo.GRI.PRIArray.Length; i++ )
	{
		// check for team and ignore net players
		if (WorldInfo.GRI.PRIArray[i].Team != Team || !IsValidPlayer(WorldInfo.GRI.PRIArray[i], true, true))
			continue;

		randoms.AddItem(WorldInfo.GRI.PRIArray[i]);
	}

	if (randoms.Length > 0)
	{
		i = Rand(randoms.Length);
		OutBot = UTBot(randoms[i].Owner);
		return true;
	}

	return false;
}

function bool GetAdjustedTeamPlayerCount(out array<int> PlayersCount, out array<int> TeamsCount)
{
	local int i, index, count;

	// init team count array
	PlayersCount.Add(WorldInfo.GRI.Teams.Length);

	// count real-players
	for ( i=0; i<WorldInfo.GRI.PRIArray.Length; i++ )
	{
		// only count non-bots and non-players
		if (!IsValidPlayer(WorldInfo.GRI.PRIArray[i]))
			continue;

		// fill up array if needed
		index = WorldInfo.GRI.PRIArray[i].Team.TeamIndex;
		if (PlayersCount.Length <= index)
		{
			PlayersCount.Add(index-PlayersCount.Length+1);
		}

		PlayersCount[index]++;
	}

	// take botratio into account and calculate resulting player count
	for ( i=0; i<PlayersCount.Length; i++)
	{
		// get bot count from team size
		count = WorldInfo.GRI.Teams[i].Size - PlayersCount[i];

		// use botratio to know how many proper player a team would have
		TeamsCount[i] = PlayersCount[i]*BotRatio + count;
	}

	return true;
}

//**********************************************************************************
// Helper functions
//**********************************************************************************

/** Returns whether the given player is a valid player (no spectator, valid team, etc.).
 *  By default, only net players are taken into account
 *  @param PRI the net player (or bot) to check
 *  @param bCheckBot whether to ignore bots
 */
function bool IsValidPlayer(PlayerReplicationInfo PRI, optional bool bCheckBot, optional bool bOnlyBots)
{
	if (PRI == none || PRI.bOnlySpectator || (!bCheckBot && PRI.bBot) || PRI.Team == none || 
		PRI.Owner == none || (bOnlyBots && UTBot(PRI.Owner) == none))
		return false;

	return true;
}

function bool GetController(Pawn P, out Controller C)
{
	if (P == none)
		return false;

	C = P.Controller;
	if (C == None && P.DrivenVehicle != None)
	{
		C = P.DrivenVehicle.Controller;
	}

	return C != none;
}

DefaultProperties
{
	`if(`notdefined(FINAL_RELEASE))
		bShowDebug=true
		bDebugSwitchToSpectator=false
	`endif

	// --- Config ---
	
	UseLevelRecommendation=false
	PlayersVsBots=false
	PlayersSide=0
	BotRatio=2.0
}
