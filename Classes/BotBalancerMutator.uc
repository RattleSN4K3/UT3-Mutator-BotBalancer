class BotBalancerMutator extends UTMutator;

`if(`notdefined(FINAL_RELEASE))
	var bool bShowDebug;

	var bool bDebugSwitchToSpectator;
`endif

//**********************************************************************************
// Constant variables
//**********************************************************************************

var() const byte DEFAULT_TEAM_UNSET;
var() const byte DEFAULT_TEAM_BOT;
var() const byte DEFAULT_TEAM_PLAYER;

//**********************************************************************************
// Workflow variables
//**********************************************************************************

/** Set when GRI is initialized */
var bool bGRIInitialized;

/** Single instanced config instance which holds all the config variables */
var BotBalancerConfig MyConfig;

/** Readonly. Set when match has started (MatchStarting was called) */
var bool bMatchStarted;

var bool bForceDesiredPlayerCount;
var int DesiredPlayerCount;

var bool bOriginalForceAllRed;
var bool bIsOriginalForceAllRedSet;

var private UTTeamGame CacheGame;
var private class<UTBot> CacheBotClass;
var private array<UTBot> BotsWaitForRespawn;
var private array<PlayerController> PlayersWaitForChangeTeam;
var private array<UTBot> BotsSetOrders;

/** Used to track down spawned bots within the custom addbots code */
var private array<UTBot> BotsSpawnedOnce;

// ---=== Override config ===---

var bool bPlayersBalanceTeams;
var bool PlayersVsBots;
var float BotRatio;

/** Team index. Always valid index to GRI.Teams. Never 255/unset */
var byte PlayersSide;

//**********************************************************************************
// State for GRI initialization
//**********************************************************************************

auto state InitGRI
{
	function NotifyLogin(Controller NewPlayer)
	{
		`Log(name$"::NotifyLogin - NewPlayer:"@NewPlayer,,'BotBalancer');
		global.NotifyLogin(NewPlayer);

		// GRI related initialization
		SetGRI(WorldInfo.GRI);
	}
	
	function bool AllowChangeTeam(Controller Other, out int num, bool bNewTeam)
	{
		// GRI related initialization
		SetGRI(WorldInfo.GRI);

		return global.AllowChangeTeam(Other, num, bNewTeam);
	}
}

//**********************************************************************************
// Inherited functions
//**********************************************************************************

event Destroyed()
{
	MyConfig = none;
	super.Destroyed();
}

function bool MutatorIsAllowed()
{
	//only allow mutator in Team games (except Duel)
	return UTTeamGame(WorldInfo.Game) != None && UTDuelGame(WorldInfo.Game) == None && Super.MutatorIsAllowed();
}

function InitMutator(string Options, out string ErrorMessage)
{
	local string InOpt;

	`Log(name$"::InitMutator - Options:"@Options,,'BotBalancer');
	super.InitMutator(Options, ErrorMessage);

	CacheGame = UTTeamGame(WorldInfo.Game);
	if (CacheGame == none)
	{
		Destroy();
		return;
	}

	InitConfig();

	// set bot class to a null class (abstract) which prevents
	// bots being spawned by commands like (addbots, addbluebots,...)
	// but also timed by NeedPlayers in GameInfo::Timer
	CacheBotClass = CacheGame.BotClass;
	CacheGame.BotClass = class'BotBalancerNullBot';

	// Disable auto balancing of bot teams.
	CacheGame.bCustomBots = true;

	// override player-balance flag
	if (class'GameInfo'.static.HasOption(Options, "BalanceTeams"))
	{
		InOpt = class'GameInfo'.static.ParseOption(Options, "BalanceTeams");
		bPlayersBalanceTeams = bool(InOpt);
	}
}

// overridden. but not called. called manually
function SetGRI(GameReplicationInfo GRI)
{
	if (GRI == none || bGRIInitialized)
		return;

	// set random team if desired
	if (MyConfig.PlayersSide < 0)
		PlayersSide = Rand(WorldInfo.GRI.Teams.Length);
	else if (MyConfig.PlayersSide < WorldInfo.GRI.Teams.Length)
		PlayersSide = MyConfig.PlayersSide;
	//else if (MyConfig.PlayersSide < DEFAULT_TEAM_UNSET)
	//	PlayersSide = DEFAULT_TEAM_PLAYER;
	else
		PlayersSide = DEFAULT_TEAM_PLAYER;

	bGRIInitialized = true;
	GotoState('');
}

// called when gameplay actually starts
function MatchStarting()
{
	local string InOpt;

	`Log(name$"::MatchStarting",,'BotBalancer');
	super.MatchStarting();

	if (CacheGame == none)
		return;

	if (MyConfig.UseLevelRecommendation)
	{
		CacheGame.bAutoNumBots = true;
		DesiredPlayerCount = CacheGame.LevelRecommendedPlayers();
		bForceDesiredPlayerCount = true;
	}
	else if (CacheGame.HasOption(CacheGame.ServerOptions, "NumPlay"))
	{
		// clear desired player count which then uses
		// the Game's desired value in the next timer
		DesiredPlayerCount = -1;
	}
	else
	{
		// just cache desired player count, also prevents adding bots at start
		DesiredPlayerCount = CacheGame.DesiredPlayerCount;
	}

	// override player-vs-bots vars
	if (class'GameInfo'.static.HasOption(CacheGame.ServerOptions, "VsBots"))
	{
		InOpt = class'GameInfo'.static.ParseOption(CacheGame.ServerOptions, "VsBots");
		if (InOpt ~= "false" || InOpt ~= "true")
		{
			PlayersVsBots = bool(InOpt);
		}
		else if (float(InOpt) > 0.0)
		{
			PlayersVsBots = true;
			BotRatio = float(InOpt);
		}
	}

	// override ratio var
	if (class'GameInfo'.static.HasOption(CacheGame.ServerOptions, "BotRatio"))
	{
		InOpt = class'GameInfo'.static.ParseOption(CacheGame.ServerOptions, "BotRatio");
		BotRatio = float(InOpt);
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
		// attach helper which trigger events for death. this is used to revert bSpawnedByKismet and set bForceAllRed
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
			SemaForceAllRed(false);

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
	local BotBalancerTimerHelper parmtimer;

	if (super.AllowChangeTeam(Other, num, bNewTeam))
	{
		// disallow changing team if PlayersVsBots is set
		if (PlayersVsBots && PlayerController(Other) != none && bNewTeam &&
			num != PlayersSide && !MyConfig.AllowTeamChangeVsBots)
		{
			//@TODO: add support for Multi-Team
			PlayerController(Other).ReceiveLocalizedMessage(class'UTTeamGameMessage', PlayersSide == 0 ? 1 : 2);
			return false;
		}
	}

	// clear forced flag to allow team change for players
	if (PlayerController(Other) != none && bNewTeam)
	{
		SemaForceAllRed(true);
		CacheGame.bForceAllRed = false;

		PlayersWaitForChangeTeam.AddItem(PlayerController(Other));

		// as other mutators can disallow chaning, we need to remove this PC from PlayersWaitForChangeTeam
		// we call a parameterized timer the next tick which removes that player from the array
		parmtimer = new class'BotBalancerTimerHelper';
		parmtimer.PC = PlayerController(Other);
		parmtimer.Callback = self;
		SetTimer(0.001, false, 'TimedChangedTeam', parmtimer);
	}

	if (PlayersVsBots)
	{
		// spawning player/bot into the correct team
		if (!bNewTeam) 
		{
			num = GetNextTeamIndex(AIController(Other) != none);
		}
	}
	else if (bPlayersBalanceTeams && PlayerController(Other) != none)
	{
		num = GetNextTeamIndex(false);
	}

	return True;
}

function NotifySetTeam(Controller Other, TeamInfo OldTeam, TeamInfo NewTeam, bool bNewTeam)
{
	`Log(name$"::NotifySetTeam - Other:"@Other$" - OldTeam:"@OldTeam$" - NewTeam:"@NewTeam$" - bNewTeam:"@bNewTeam,,'BotBalancer');
	super.NotifySetTeam(Other, OldTeam, NewTeam, bNewTeam);

	if (PlayerController(Other) != none && bNewTeam)
	{
		// remove swapped player from array
		PlayersWaitForChangeTeam.RemoveItem(PlayerController(Other));
		// also remove invalid references, just in case
		PlayersWaitForChangeTeam.RemoveItem(none);
	}

	CheckAndClearForceRedAll();

	if (bMatchStarted && UTBot(Other) == none)
	{
		BalanceBotsTeams();
	}
}

`if(`notdefined(FINAL_RELEASE))
function Mutate(string MutateString, PlayerController Sender)
{
	local string str, value, value2;
	local int i;
	local UTBot bot;

	`Log(name$"::Mutate - MutateString:"@MutateString$" - Sender:"@Sender,,'NoMoreDemoGuy');
	super.Mutate(MutateString, Sender);

	if (Sender == none)
		return;

	str = "BB SwitchBot"; // BB SwitchBot FromTeam ToTeam
	if (Left(MutateString, Len(str)) ~= str)
	{
		value = Mid(MutateString, Len(str)+1); // FromTeam ToTeam
		i = InStr(value, " ");
		if (i != INDEX_NONE)
		{
			value2 = Mid(value, i+1); // ToTeam
			value = Left(value, i); // FromTeam

			if (int(value) < WorldInfo.GRI.Teams.Length && int(value2) < WorldInfo.GRI.Teams.Length)
			{
				if (GetRandomPlayerByTeam(WorldInfo.GRI.Teams[int(value)], bot))
				{
					SwitchBot(bot, int(value2));
					Sender.ClientMessage("Bot"@bot.GetHumanReadableName()@"switched");
				}
				else
				{
					Sender.ClientMessage("Unable to get random bot from team"@value);
				}
			}
			else
			{
				Sender.ClientMessage("Invalid team indizes");
			}
		}
		return;
	}
}
`endif

//**********************************************************************************
// Events
//**********************************************************************************

event TimerCheckPlayerCount()
{
	if (CacheGame == none)
		ClearTimer();

	if (CacheGame.DesiredPlayerCount != DesiredPlayerCount)
	{
		if (bForceDesiredPlayerCount)
		{
			CacheGame.DesiredPlayerCount = DesiredPlayerCount;
			bForceDesiredPlayerCount = false;
		}

		// attempted to add bots through external code, use custom code now
		AddBots(CacheGame.DesiredPlayerCount);

		// clear player count again to stop throw error messages (due to timed NeedPlayers-call)
		DesiredPlayerCount = CacheGame.DesiredPlayerCount;
	}
}

event TimerChangedTeam(PlayerController PC)
{
	PlayersWaitForChangeTeam.RemoveItem(PC);
	CheckAndClearForceRedAll();
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

	// set bForceAllRed to bail out TooManyBots until Player respawned
	SemaForceAllRed(true);
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

function InitConfig()
{
	`log(name$"::InitConfig",bShowDebug,'BotBalancer');

	MyConfig = class'BotBalancerConfig'.static.GetConfig();
	MyConfig.Validate();

	MyConfig.SaveConfig();

	// set runtime vars from config values
	bPlayersBalanceTeams = MyConfig.bPlayersBalanceTeams;
	PlayersVsBots = MyConfig.PlayersVsBots;
	BotRatio = MyConfig.BotRatio;
}

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

			// stock games use 2 teams as max
			return Clamp(1 - PlayersSide, 0, 1); // use opposite
			break;
		default:
			if (WorldInfo.GRI.Teams.Length == 1)
				return WorldInfo.GRI.Teams[0].TeamIndex;
			else if (WorldInfo.GRI.Teams.Length == 2)
				return Clamp(1 - PlayersSide, 0, 1);
			else if (WorldInfo.GRI.Teams.Length > 2)
			{
				// get team index from all teams but players team
				count = WorldInfo.GRI.Teams.Length;
				index = PlayersSide + Rand(count-1) % count;
				return index;
			}
		}
		
		return 255;
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
			count = MaxInt;
			prefer = 0;
			index = INDEX_NONE;
			if (!bBot && bPlayersBalanceTeams)
			{
				// find team with lowest real player count
				for ( i=0; i<PlayersCount.Length; i++)
				{
					if (PlayersCount[i] < count)
					{
						count = PlayersCount[i];
						index = i;
					}
				}
			}
			else
			{
				// find team with lowest calculated player count (prefer team with lower net players)
				for ( i=0; i<TeamsCount.Length; i++)
				{
					if (TeamsCount[i] < count || (TeamsCount[i] == count && PlayersCount[i] < prefer))
					{
						count = TeamsCount[i];
						prefer = PlayersCount[i];
						index = i;
					}
				}
			}

			// if a proper team could be found, use that team
			if (index != INDEX_NONE)
			{
				return index;
			}
		}

		// use original algorithm to find proper team index
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
	SemaForceAllRed(true);
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
		SemaForceAllRed(false);
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
				SwitchCount = Round(float(diff)/2.0 + 0.5);
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
	SemaForceAllRed(true);
	CacheGame.bForceAllRed = false;
	if (CacheGame.ChangeTeam(bot, TeamNum, true) && CacheGame.bTeamGame && bot.PlayerReplicationInfo.Team != OldTeam)
	{
		if (bot.Pawn != None)
		{
			bot.Pawn.PlayerChangedTeam();
		}

		BotsWaitForRespawn.AddItem(bot);
	}
	else 
	{
		CheckAndClearForceRedAll();
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

private function SemaForceAllRed(bool bSet)
{
	if (bSet && !bIsOriginalForceAllRedSet)
	{
		bIsOriginalForceAllRedSet = true;
		bOriginalForceAllRed = CacheGame.bForceAllRed;
	}
	else if (!bSet && bIsOriginalForceAllRedSet)
	{
		bIsOriginalForceAllRedSet = false;
		CacheGame.bForceAllRed = bOriginalForceAllRed;
	}
}

private function CheckAndClearForceRedAll()
{
	if (BotsWaitForRespawn.Length < 1 && PlayersWaitForChangeTeam.Length < 1)
	{
		SemaForceAllRed(false);
	}
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

	DEFAULT_TEAM_BOT=1
	DEFAULT_TEAM_PLAYER=0
	DEFAULT_TEAM_UNSET=255
}
