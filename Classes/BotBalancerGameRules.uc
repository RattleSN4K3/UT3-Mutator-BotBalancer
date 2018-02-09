class BotBalancerGameRules extends GameRules;

//'''''''''''''''''''''''''
// Server variables
//'''''''''''''''''''''''''

var BotBalancerMutator Callback;

//**********************************************************************************
// Inherited funtions
//**********************************************************************************

event Destroyed()
{
	// remove from list
	RemoveGameRules();

	super.Destroyed();
}

function ScoreObjective(PlayerReplicationInfo Scorer, Int Score)
{
	super.ScoreObjective(Scorer, Score);

	if (Callback != none)
	{
		Callback.NotifyScoreObjective(Scorer, Score);
	}
}

function ScoreKill(Controller Killer, Controller Killed)
{
	super.ScoreKill(Killer, Killed);

	if (Callback != none)
	{
		Callback.NotifyScoreKill(Killer, Killed);
	}
}

//**********************************************************************************
// Private funtions
//**********************************************************************************

/**
 * RemoveGameRules()
 * Remove a GameRules from the game rules modifiers list
 */
function RemoveGameRules()
{
	local GameRules G;
	local GameRules GameRulesToRemove;

	if (WorldInfo.Game == none)
		return;

	GameRulesToRemove = self;

	// remove game rules list
	if ( WorldInfo.Game.GameRulesModifiers == GameRulesToRemove )
	{
		WorldInfo.Game.GameRulesModifiers = GameRulesToRemove.NextGameRules;
	}
	else if ( WorldInfo.Game.GameRulesModifiers != None )
	{
		for ( G=WorldInfo.Game.GameRulesModifiers; G!=none; G=G.NextGameRules )
		{
			if ( G.NextGameRules == GameRulesToRemove )
			{
				G.NextGameRules = GameRulesToRemove.NextGameRules;
				break;
			}
		}
	}
}

DefaultProperties
{
}
