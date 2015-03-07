class BotBalancerMutator extends UTMutator
	config(BotBalancer);

//**********************************************************************************
// Workflow variables
//**********************************************************************************

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

	`Log(name$"::ModifyPlayer - Other:"@Other,,'BotBalancer');
	super.ModifyPlayer(Other);

	if (Other == none || UTBot(Other.Controller) == none) return;
	bot = UTBot(Other.Controller);

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

//**********************************************************************************
// Events
//**********************************************************************************

event TimerCheckPlayerCount()
{
	if (CacheGame == none)
		ClearTimer();

	if (CacheGame.DesiredPlayerCount != DesiredPlayerCount)
	{
		// attempted to add bots through external code, use custom code now
		AddBots(CacheGame.DesiredPlayerCount);

		// clear player count again to stop throw error messages (due to timed NeedPlayers-call)
		DesiredPlayerCount = CacheGame.DesiredPlayerCount;
	}
}

//**********************************************************************************
// Private functions
//**********************************************************************************

function int GetNextTeamIndex(bool bBot)
{
	local UTTeamInfo BotTeam;
	
	if (PlayersVsBots && bBot)
	{
		return 1;
	}

	if (CacheGame != none)
	{
		BotTeam = CacheGame.GetBotTeam();
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

DefaultProperties
{
	// --- Config ---
	
	UseLevelRecommendation=true
	PlayersVsBots=false
	BotRatio=1.0
}
