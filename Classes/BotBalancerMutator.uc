class BotBalancerMutator extends UTMutator
	config(BotBalancer);

//**********************************************************************************
// Workflow variables
//**********************************************************************************

var int DesiredPlayerCount;

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
	local UTGame G;

	`Log(name$"::InitMutator - Options:"@Options,,'BotBalancer');
	 super.InitMutator(Options, ErrorMessage);

	G = UTGame(WorldInfo.Game);
	if (G == none) return;

	// set bot class to a null class (abstract) which prevents
	// bots being spawned by commands like (addbots, addbluebots,...)
	//but also timed by NeedPlayers in GameInfo::Timer
	G.BotClass = class'BotBalancerNullBot';

	// Disable auto balancing of bot teams.
	G.bCustomBots = true;

	// override
	G.bPlayersVsBots = PlayersVsBots;
	G.BotRatio = BotRatio;
}

// called when gameplay actually starts
function MatchStarting()
{
	local UTGame G;

	`Log(name$"::MatchStarting",,'BotBalancer');
	super.MatchStarting();

	G = UTGame(WorldInfo.Game);
	if (G == none) return;

	if (UseLevelRecommendation)
	{
		G.bAutoNumBots = true;
		DesiredPlayerCount = G.LevelRecommendedPlayers();
	}
	else
	{
		DesiredPlayerCount = G.DesiredPlayerCount;
	}

	SetTimer(1.0, true, 'TimerCheckPlayerCount');
}

//**********************************************************************************
// Events
//**********************************************************************************

event TimerCheckPlayerCount()
{
	local UTGame G;
	
	G = UTGame(WorldInfo.Game);
	if (G == none) return;
	
	if (G.DesiredPlayerCount > 0)
	{
		// attempted to add bots through external code, use custom code now


		// clear player count again to stop throw error messages (due to timed NeedPlayers-call)
		G.DesiredPlayerCount = 0;
	}
}

DefaultProperties
{
	// --- Config ---
	
	UseLevelRecommendation=true
	PlayersVsBots=false
	BotRatio=1.0
}
