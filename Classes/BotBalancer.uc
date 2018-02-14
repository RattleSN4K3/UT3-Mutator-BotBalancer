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

struct RecommendedPlayersGametypeMultiplierInfo
{
	/** Game type name for this map info */
	var() name Gametype;

	var() class<GameInfo> GameClass;

	var() float Multiplier;
	var() int OffsetPost;

	structdefaultproperties
	{
		Multiplier=1.0
		OffsetPost=0
	}
};

struct RecommendedPlayersGametypeMultiplierMapInfo extends RecommendedPlayersGametypeMultiplierInfo
{
	var() name MapPrefix;
};

struct RecommendedPlayersMapInfo
{
	/** map name for this map info */
	var() name Map;

	/** recommended player count range - for display on the UI and the auto number of bots setting */
	var() int Min, Max;

	/** recommended player count range - for display on the UI and the auto number of bots setting */
	var() array<RecommendedPlayersGametypeMultiplierInfo> Gametypes;

	structdefaultproperties
	{
		Min=-1
		Max=-1
	}
};

DefaultProperties
{
}
