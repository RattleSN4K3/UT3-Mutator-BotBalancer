class BotBalancerMutator extends UTMutator
	config(BotBalancer);

//**********************************************************************************
// Workflow variables
//**********************************************************************************

var int DesiredPlayerCount;

var private UTTeamGame CacheGame;
var private class<UTBot> CacheBotClass;
var private array<UTBot> WaitBotsRespawn;

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
	local bool bAbort;

	// force TooManyBots fail out. it is called right on initial spawn for bots
	bOriginalForceAllRed = CacheGame.bForceAllRed;
	CacheGame.bForceAllRed = true;

	DesiredPlayerCount = Clamp(InDesiredPlayerCount, 1, 32);
	while (!bAbort && CacheGame.NumPlayers + CacheGame.NumBots < DesiredPlayerCount)
	{
		// restore Game's original bot class
		CacheGame.BotClass = CacheBotClass;

		// add bot to the specific team
		TeamNum = GetNextTeamIndex(true);
		bAbort = CacheGame.AddBot(,true,TeamNum) == none;

		// revert to null class to preven adding bots;
		CacheGame.BotClass = class'BotBalancerNullBot';

		if (bAbort) break;
	}

	// revert to original if not bot was added to array
	if (WaitBotsRespawn.Length < 1)
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
