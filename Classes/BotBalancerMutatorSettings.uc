class BotBalancerMutatorSettings extends Settings;

struct WebAdminGroups
{
	var localized string Name;
	var string ids;
	var int id;

	structdefaultproperties
	{
		id=-1
	}
};

var localized array<string> PropertyDescriptions;

var array<BotBalancerMutatorSettings.WebAdminGroups> Groups;

function SetSpecialValue(name PropertyName, string NewValue)
{
	local BotBalancerConfig cfg;

	local string CurProperty;
	local int i;

	`Log(name$"::SetSpecialValue - PropertyName:"@PropertyName@" - NewValue:"@NewValue,,'BotBalancer');
	
	if (PropertyName == 'WebAdmin_Init')
	{
		cfg = class'BotBalancerConfig'.static.GetConfig();
		for (i=0; i<PropertyMappings.Length; i++)
		{
			if (PropertyMappings[i].Name != '')
			{
				CurProperty = cfg.GetSpecialValue(PropertyMappings[i].Name);
				SetPropertyFromStringByName(PropertyMappings[i].Name, CurProperty);
			}
		}
	}

	else if (PropertyName == 'WebAdmin_Save')
	{
		cfg = class'BotBalancerConfig'.static.GetConfig();
		for (i=0; i<PropertyMappings.Length; i++)
		{
			if (PropertyMappings[i].Name != '')
			{
				CurProperty = GetPropertyAsStringByName(PropertyMappings[i].Name);
				cfg.SetSpecialValue(PropertyMappings[i].Name, CurProperty);
			}
		}

		cfg.Validate();
		cfg.SaveConfigCustom();
	}
}

function string GetSpecialValue(name PropertyName)
{
	local int i, index;
	local string ret;
	local string propstr;
	local array<string> GroupMapping;

	if (PropertyName == 'WebAdmin_groups')
	{
		for (i=0; i<Groups.Length; i++)
		{
			if (Groups[i].id < 0) continue;
			propstr = Groups[i].id$"|"$i;
			GroupMapping.AddItem(propstr);
		}
		BubbleSort(GroupMapping);

		ret = "";
		for (index=0; index<GroupMapping.Length; index++)
		{
			i = int(Split(GroupMapping[index], "|", true));
			ret $= Groups[i].Name;
			ret $= "=";
			ret $= Groups[i].ids;

			if (index < Groups.Length-1) ret $= ";";
		}
	}

	propstr = string(PropertyName);
	i = InStr(propstr, "_");
	if (i != INDEX_NONE && Left(propstr, i) ~= "PropertyDescription")
	{
		propstr = Mid(propstr, i+1);
		i = PropertyMappings.Find('Name', name(propstr));
		if (i != INDEX_NONE)
		{
			ret = PropertyDescriptions[i];
		}
	}

	return ret;
}

function SetPropertyValue(name PropertyName, coerce string PropertyValue)
{
	SetPropertyFromStringByName(PropertyName, PropertyValue);
}

function bool GetPropertyValue(name PropertyName, out string PropertyValue)
{
	local int PropId;
	if (GetPropertyId(PropertyName, PropId) && HasProperty(PropId))
	{
		PropertyValue = GetPropertyAsString(PropId);
		return true;
	}
	
	return false;
}

static function BubbleSort(out array<string> arr)
{
	local int i, n;
	local string value;

	for (i=0; i<arr.Length-1; i++)
	{
		for (n=i+1; n<arr.Length; n++)
		{
			if (arr[i] > arr[n])
			{
				// switch them
				value  = arr[i];
				arr[i] = arr[n];
				arr[n] = value;
			}
		}
	}
}

DefaultProperties
{
	Groups[0]=(id=0,Name="General",ids="0,1")
	Groups[1]=(id=1,Name="Level recommendation",ids="20,25")
	Groups[2]=(id=2,Name="Players vs. Bots",ids="30,33")
	Groups[3]=(id=6,Name="UT3 stock settings",ids="50,50")
	Groups[4]=(id=5,Name="Advanced",ids="100,102")
	Groups[5]=(id=3,Name="Skill adjustment",ids="70,71")
	Groups[6]=(id=4,Name="Skill adjustment - Adjustable",ids="72,80")


	Properties(0)=(PropertyID=0,Data=(Type=SDT_Float))
	PropertyMappings(0)=(ID=0,Name="BotRatio",ColumnHeaderText="Bot/Player Ratio",MappingType=PVMT_Ranged,MinVal=0.0001,MaxVal=64.0,RangeIncrement=0.5)
	PropertyDescriptions(0)="The number of bots to balance for each player in the opponent team. Basically this values represents how much player a human player results. A value of 2.0 would mean that a human player is as strong as 2 bots."

	Properties(1)=(PropertyID=20,Data=(Type=SDT_Int32))
	PropertyMappings(1)=(ID=20,Name="UseLevelRecommendation",ColumnHeaderText="Use Level Recommendation",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(1)="Whether to use the level recommended player count for each map. Once  this is set, the player count will be adjusted to what ever the map has defined as min and max player count. A mean value will be used as bot player count."

	Properties(2)=(PropertyID=21,Data=(Type=SDT_Float))
	PropertyMappings(2)=(ID=21,Name="LevelRecommendationMultiplier",ColumnHeaderText="Recommended player multiplier",MappingType=PVMT_Ranged,MinVal=0.1,MaxVal=8.0,RangeIncrement=0.1)
	PropertyDescriptions(2)="A factor which will be used to multiply the recommended player count for the value. Using a mulitplier of 2.0 would double up the player count where 0.5 would reduce the player count by half."

	Properties(3)=(PropertyID=22,Data=(Type=SDT_Int32))
	PropertyMappings(3)=(ID=22,Name="LevelRecommendationOffsetPost",ColumnHeaderText="Recommended player adjustment",MappingType=PVMT_Ranged,MinVal=-31,MaxVal=31,RangeIncrement=1)
	PropertyDescriptions(3)="A value which will be added or substracted to/from the (multiplied) recommended player count for each level. This can be used to adjust the count by an absolute number like adding additional 2 bots."

	Properties(4)=(PropertyID=30,Data=(Type=SDT_Int32))
	PropertyMappings(4)=(ID=30,Name="PlayersVsBots",ColumnHeaderText="Players vs. Bots",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(4)="Whether to play a match with bots on one side (or multi sides with Multi-Team support) and humans players all in one team."

	Properties(5)=(PropertyID=31,Data=(Type=SDT_Int32))
	PropertyMappings(5)=(ID=31,Name="PlayersSide",ColumnHeaderText="Player side (for Player vs. Bots)",MappingType=PVMT_IdMapped,ValueMappings=((Id=-1,Name="Random"),(Id=0,Name="Red"),(Id=1,Name="Blue"),(Id=2,Name="Green"),(Id=3,Name="Gold"),(Id=255,Name="Unset")))
	PropertyDescriptions(5)="The player side in which all the human players will be put in when they connected. They can still change to the other side unless 'Allow Team Change' not allowed."

	Properties(6)=(PropertyID=32,Data=(Type=SDT_Int32))
	PropertyMappings(6)=(ID=32,Name="AllowTeamChangeVsBots",ColumnHeaderText="Allow Team Change (in Player vs. Bots)",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(6)="Whether to allow team changes for human player in Players vs. Bots mode. When this value is set, the any human player will be forced to play on the human side."

	// ---=== UT3 override config ===---
	Properties(7)=(PropertyID=50,Data=(Type=SDT_Int32))
	PropertyMappings(7)=(ID=50,Name="bPlayersBalanceTeams",ColumnHeaderText="Players Balance Teams",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(7)="Whether joining players will join the team with the least players."


	Properties(8)=(PropertyID=1,Data=(Type=SDT_Float))
	PropertyMappings(8)=(ID=1,Name="TeamRatio",ColumnHeaderText="Team Ratio",MappingType=PVMT_Ranged,MinVal=0.0001,MaxVal=64.0,RangeIncrement=0.2)
	PropertyDescriptions(8)="The ratio of human players teams versus bot team. A value of 2.0 would mean that a bot player team will get twice as players as the human player team."

	Properties(9)=(PropertyID=23,Data=(Type=SDT_Int32))
	PropertyMappings(9)=(ID=23,Name="PreferUIMapInfo",ColumnHeaderText="Prefer UI MapInfo",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(9)="Whether to prefer the stored RecommendedPlayersMap (provided by the game's localization), otherwise the map's author recommended player count is used."

	Properties(10)=(PropertyID=24,Data=(Type=SDT_Int32))
	PropertyMappings(10)=(ID=24,Name="UseUIMapInfoGametypeMultiplier",ColumnHeaderText="Use Maps' Gametype Multiplier",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(10)="Whether to use GameType multipliers stored for each map info in RecommendedPlayersMap which increase the recommended player count based on RecommendedPlayersGametypeMultipliers."

	Properties(11)=(PropertyID=25,Data=(Type=SDT_Int32))
	PropertyMappings(11)=(ID=25,Name="UseGlobalGametypeMultiplier",ColumnHeaderText="Use Global Gametype Multiplier",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(11)="Whether to use global GameType multipliers which increase the recommended player count based on RecommendedPlayersGametypeMultipliers."

	Properties(12)=(PropertyID=100,Data=(Type=SDT_Int32))
	PropertyMappings(12)=(ID=100,Name="SupportDeathmatch",ColumnHeaderText="Support Deathmatch",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(12)="Whether to support bot balanced in Deathmatch games. This will generally support adjusting the skill level of bots dynamically."

	Properties(13)=(PropertyID=101,Data=(Type=SDT_Int32))
	PropertyMappings(13)=(ID=101,Name="EarlyInitialization",ColumnHeaderText="Early Initialization",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(13)="Whether to early initialize the mutator and the amount of bots. If you face problems with default character models, set this option in order to initialize character models early in the game (additionally set 'Try Loading Character Models')"

	Properties(14)=(PropertyID=102,Data=(Type=SDT_Int32))
	PropertyMappings(14)=(ID=102,Name="TryLoadingCharacterModels",ColumnHeaderText="Try Loading Character Models",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(14)="Whether to try loading character models for bots joining the game within the match (when the map/game is already fully loaded). If you fac problems with default character models, enable this option."

	Properties(15)=(PropertyID=70,Data=(Type=SDT_Int32))
	PropertyMappings(15)=(ID=70,Name="AdjustBotSkill",ColumnHeaderText="Adjust Bot Skill",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(15)="Whether to adjust the bot skill dynamically and adapt to the skill of the player based on the score difference."

	Properties(16)=(PropertyID=71,Data=(Type=SDT_Int64))
	PropertyMappings(16)=(ID=71,Name="SkillAdjustment",ColumnHeaderText="Skill Adjustment",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="Original "),(ID=1,Name="Adjustable ")))
	PropertyDescriptions(16)="The type of skill adjustment. 'Original' is the same as the campaign mode, 'Adjustable' is simlar to that but configurable with the options provided here."

	Properties(17)=(PropertyID=72,Data=(Type=SDT_Float))
	PropertyMappings(17)=(ID=72,Name="SkillAdjustmentFactor",ColumnHeaderText="Skill Adjustment Factor",MappingType=PVMT_Ranged,MinVal=0.0,MaxVal=7.0,RangeIncrement=0.2)
	PropertyDescriptions(17)="The skill value to adjust the bot skill level."

	Properties(18)=(PropertyID=73,Data=(Type=SDT_Int32))
	PropertyMappings(18)=(ID=73,Name="SkillAdjustmentThreshold",ColumnHeaderText="Skill Adjustment Threshold",MappingType=PVMT_Ranged,MinVal=1,MaxVal=64,RangeIncrement=1)
	PropertyDescriptions(18)="The amount of kills/score the difference of both players (bot and human player) has to have in order to adjust the skill level."

	Properties(19)=(PropertyID=74,Data=(Type=SDT_Float))
	PropertyMappings(19)=(ID=74,Name="SkillAdjustmentDisparity",ColumnHeaderText="Skill Adjustment Disparity",MappingType=PVMT_Ranged,MinVal=-1.0,MaxVal=7.0,RangeIncrement=0.25)
	PropertyDescriptions(19)="The maximum difference of the bot skill from the game's difficulty level (in both directions)."

	Properties(20)=(PropertyID=75,Data=(Type=SDT_Int32))
	PropertyMappings(20)=(ID=75,Name="SkillAdjustmentLikeCampaign",ColumnHeaderText="Skill Adjustment like Campaign mode",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(20)="Whether to adjust specific players (like Akasha or Loque) based on set conditions."

	Properties(21)=(PropertyID=76,Data=(Type=SDT_Float))
	PropertyMappings(21)=(ID=76,Name="SkillAdjustmentCampaignReduce",ColumnHeaderText="Skill Adjustment Campaign-Decrease",MappingType=PVMT_Ranged,MinVal=0.0,MaxVal=7.0,RangeIncrement=0.25)
	PropertyDescriptions(21)="The skill value to adjust for the campaign-like adjustement if the skill has to be reduced."

	Properties(22)=(PropertyID=77,Data=(Type=SDT_Float))
	PropertyMappings(22)=(ID=77,Name="SkillAdjustmentCampaignIncrease",ColumnHeaderText="Skill Adjustment Campaign-Increase",MappingType=PVMT_Ranged,MinVal=0.0,MaxVal=7.0,RangeIncrement=0.25)
	PropertyDescriptions(22)="The skill value to adjust for the campaign-like adjustement if the skill has to be increased."

	Properties(23)=(PropertyID=78,Data=(Type=SDT_Int64))
	PropertyMappings(23)=(ID=78,Name="SkillAdjustmentIndividual",ColumnHeaderText="Skill Adjustment Individual",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="Game's difficulty "),(ID=1,Name="Bot skill ")))
	PropertyDescriptions(23)="Whether to adjust the bot skill individually per player and not increase the overall game's difficulty."

	Properties(24)=(PropertyID=79,Data=(Type=SDT_Float))
	PropertyMappings(24)=(ID=79,Name="SkillAdjustmentMinSkill",ColumnHeaderText="Skill Adjustment Skill (min)",MappingType=PVMT_Ranged,MinVal=-1.0,MaxVal=7.0,RangeIncrement=0.1)
	PropertyDescriptions(24)="The minimum skill level the skill adjustment should have afterall."

	Properties(25)=(PropertyID=80,Data=(Type=SDT_Float))
	PropertyMappings(25)=(ID=80,Name="SkillAdjustmentMaxSkill",ColumnHeaderText="Skill Adjustment Skill (max)",MappingType=PVMT_Ranged,MinVal=-1.0,MaxVal=7.0,RangeIncrement=0.1)
	PropertyDescriptions(25)="The maximum skill level the skill adjustment should have afterall."
}
