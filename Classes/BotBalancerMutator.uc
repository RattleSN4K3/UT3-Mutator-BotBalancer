class BotBalancerMutator extends UTMutator
	config(BotBalancer);

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
		G.DesiredPlayerCount = G.LevelRecommendedPlayers();
	}
}

DefaultProperties
{
	// --- Config ---
	
	UseLevelRecommendation=true
	PlayersVsBots=false
}
