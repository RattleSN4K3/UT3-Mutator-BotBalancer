class BotBalancerMutator extends UTMutator
	config(BotBalancer);

//**********************************************************************************
// Workflow variables
//**********************************************************************************

var int DesiredPlayerCount;

var private UTTeamGame CacheGame;

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
	CacheGame.BotClass = class'BotBalancerNullBot';

	// Disable auto balancing of bot teams.
	CacheGame.bCustomBots = true;

	// override
	CacheGame.bPlayersVsBots = PlayersVsBots;
	CacheGame.BotRatio = BotRatio;
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

	if (CacheGame.DesiredPlayerCount > 0)
	{
		// attempted to add bots through external code, use custom code now


		// clear player count again to stop throw error messages (due to timed NeedPlayers-call)
		CacheGame.DesiredPlayerCount = 0;
	}
}

DefaultProperties
{
	// --- Config ---
	
	UseLevelRecommendation=true
	PlayersVsBots=false
	BotRatio=1.0
}
