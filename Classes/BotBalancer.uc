class BotBalancer extends Object;

//**********************************************************************************
// Enums
//**********************************************************************************

enum ESkillAdjustmentAlgorithm
{
	Algo_Original,
	Algo_Adjustable,
};

//**********************************************************************************
// Structs
//**********************************************************************************

struct RecommendedPlayersMapInfo
{
	/** map name for this map info */
	var() name Map;

	/** Game type name for this map info */
	var() name Gametype;

	/** recommended player count range - for display on the UI and the auto number of bots setting */
	var() int Min, Max;

	structdefaultproperties
	{
		Min=-1
		Max=-1
	}
};

DefaultProperties
{
}
