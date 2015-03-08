class BotBalancerMutator extends UTMutator
	config(BotBalancer);

//**********************************************************************************
// Workflow variables
//**********************************************************************************

var bool bForcDesiredPlayerCount;
var int DesiredPlayerCount;

var bool bOriginalForceAllRed;

var private UTTeamGame CacheGame;
var private class<UTBot> CacheBotClass;
var private array<UTBot> BotsWaitForRespawn;
var private array<UTBot> BotsSetOrders;

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
	else
	{
		DesiredPlayerCount = CacheGame.DesiredPlayerCount;
	}

	SetTimer(1.0, true, 'TimerCheckPlayerCount');
}

/* called by GameInfo.RestartPlayer()
	change the players jumpz, etc. here
*/
function ModifyPlayer(Pawn Other)
{
	local UTBot bot, botset;
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
	//@TODO: revert on pre death
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
			BotsSetOrders.RemoveItem(none);
			foreach BotsSetOrders(botset)
			{
				if (botset.PlayerReplicationInfo != none && UTTeamInfo(botset.PlayerReplicationInfo.Team) != none)
				{
					UTTeamInfo(botset.PlayerReplicationInfo.Team).SetBotOrders(botset);
				}
			}
		}
	}
}

function bool AllowChangeTeam(Controller Other, out int num, bool bNewTeam)
{
	if (super.AllowChangeTeam(Other, num, bNewTeam))
	{
		// disallow players changing team if PlayersVsBots is set
		if (PlayersVsBots && PlayerController(Other) != none)
		{
			if (bNewTeam && num != PlayersSide)
			{
				PlayerController(Other).ReceiveLocalizedMessage(class'UTTeamGameMessage', 1);
				return false;
			}
			else if (!bNewTeam)
			{
				num = PlayersSide;
			}
		}
	}

	return True;
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

	if (CacheGame != none)
	{
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
	local int TeamNum;
	local UTBot bot;

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
		
		BotsWaitForRespawn.AddItem(bot);
	}

	// revert to original if not bot was added to array
	if (BotsWaitForRespawn.Length < 1)
	{
		CacheGame.bForceAllRed = bOriginalForceAllRed;
	}
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
	// --- Config ---
	
	UseLevelRecommendation=true
	PlayersVsBots=false
	PlayersSide=0
	BotRatio=1.0
}
