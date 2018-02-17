class BotBalancerConfig extends Object
	config(BotBalancer);

//`define ALLOW_PERSISTENT 1

`if(`notdefined(FINAL_RELEASE))

	//`define CLEAR_PERSISTENT 1
	//`define FORCE_CONSOLE 1

	var bool bShowDebug;
`endif

//**********************************************************************************
// Config variables
//**********************************************************************************

var() config float BotRatio;
var() config float TeamRatio;

var() config bool UseLevelRecommendation;
var() config float LevelRecommendationMultiplier;
var() config int LevelRecommendationOffsetPost;

/** Whether to use RecommendedPlayersMap, otherwise the stored in-level MapInfo is used */
var() config bool PreferUIMapInfo;
var() config bool UseUIMapInfoGametypeMultiplier;
var() config bool UseGlobalGametypeMultiplier;

var() config bool PlayersVsBots;
var() config int PlayersSide;
var() config bool AllowTeamChangeVsBots;
var() config bool SupportDeathmatch;

var() config bool AdjustBotSkill;
var() config ESkillAdjustmentAlgorithm SkillAdjustment;

/** The amount of skill factor (in absolute value; based on 0-7 available skill) to use for a single adjustment */
var() config float SkillAdjustmentFactor;
/** The number of kills/score the killed/killer player needs to different to consider adjustments */
var() config int SkillAdjustmentThreshold;
/** The maximum skill level to differ from the game difficulty */
var() config float SkillAdjustmentDisparity;
/** Adjust skill like campaign mode (Akash/Loque increases skill, higher sized team decreases skill, etc.) */
var() config bool SkillAdjustmentLikeCampaign;
/** The amount to reduce the skill of the higher numbered team */
var() config float SkillAdjustmentCampaignReduce;
/** The amount to increase the skill of the outnumbered team */
var() config float SkillAdjustmentCampaignIncrease;

/** Whether to adjust the bot skill individually */
var() config bool SkillAdjustmentIndividual;

/** The min skill level */
var() config float SkillAdjustmentMinSkill;
/** The max skill level */
var() config float SkillAdjustmentMaxSkill;

var() config bool EarlyInitialization;
var() config bool TryLoadingCharacterModels;

// ---=== UT3 override config ===---

var() config bool bPlayersBalanceTeams;

//**********************************************************************************
// Workflow variables
//**********************************************************************************

var() transient string DataFieldPrefix;

var array<string> Variables;
var array<name> VariablesNames;

var array<string> NonNotifyVariables;
var array<name> NonNotifyVariablesNames;

var array<string> AllVariables;
var array<name> AllVariablesNames;

//==================================================================================
//==================================================================================
//==================================================================================

//**********************************************************************************
// Public funtions
//**********************************************************************************

static final function BotBalancerConfig GetConfig()
{
	local BotBalancerConfig cfg;
	local string ConfigName;

	ConfigName = string(default.Class.Name);
	cfg = BotBalancerConfig(FindObject("Transient" $"."$ ConfigName, default.Class));

	// If there is no existing instance of this object class, create one
	if (cfg == none) {
		cfg = new(none, ConfigName) default.Class;
		cfg.Init();
	}

	return cfg;
}

// For config support
// called by UI menu
/*native*/ static function string Localize( string SectionName, string KeyName, string PackageName )
{
	local BotBalancerConfig cfg;

	if (SectionName ~= "WebAdmin_ResetToDefaults" && KeyName == "" && PackageName == "")
	{
		cfg = GetConfig();
		cfg.ResetConfig();
		cfg.SaveConfigCustom();
		return "";
	}

	return super.Localize(SectionName, KeyName, PackageName);
}

final function SaveConfigCustom()
{
	local UIDynamicFieldProvider RegistryProvider;
	local UIProviderScriptFieldValue field, emptyfield;
	local string str;
	local name n;
`if(`notdefined(FINAL_RELEASE))
`if(`notdefined(ALLOW_PERSISTENT))
`if(`isdefined(CLEAR_PERSISTENT))
	local BotBalancerPersistentConfigHelper remover;
`endif
`endif
`endif

	// if console, save values into registry
	if (IsConsole())
	{
		if (GetRegistry(RegistryProvider))
		{
`if(`notdefined(FINAL_RELEASE))
`if(`notdefined(ALLOW_PERSISTENT))
`if(`isdefined(CLEAR_PERSISTENT))
			// as persistent registry entries are not cleared (only in editor)
			// we have to create an object within (living inside) the registry provider
			// which let us have access into protected members to remove the config property
			remover = new(RegistryProvider) class'BotBalancerPersistentConfigHelper';
`endif
`endif
`endif

			foreach AllVariablesNames(n)
			{
				if (n == '') continue;

				str = GetSpecialValue(n);
					
				field = emptyfield;
				//field.PropertyTag = n;
				field.PropertyType = DATATYPE_Property;
				field.StringValue = str;

`if(`notdefined(FINAL_RELEASE))
`if(`notdefined(ALLOW_PERSISTENT))
`if(`isdefined(CLEAR_PERSISTENT))
				RegistryProvider.RemoveField(name(DataFieldPrefix$n));
				remover.RemoveFieldCustom(name(DataFieldPrefix$n));
`endif
`endif
`endif

`if(`isdefined(ALLOW_PERSISTENT))
				RegistryProvider.AddField(name(DataFieldPrefix$n), DATATYPE_Property, true);
				RegistryProvider.SetField(name(DataFieldPrefix$n), field);
`else
`if(`notdefined(CLEAR_PERSISTENT))
				RegistryProvider.SetField(name(DataFieldPrefix$n), field, false);
`endif
`endif
			}

			RegistryProvider.SavePersistentProviderData();
		}
	}
	else
	{
		// ...otherwise save values into ini file
		SaveConfig();
	}			
}

final function LoadConfigCustom()
{
	local UIDynamicFieldProvider RegistryProvider;
	local UIProviderScriptFieldValue field;
	local name n;

	// only on console, we need to restore values from the registry
	if (IsConsole())
	{
		if (GetRegistry(RegistryProvider))
		{
			foreach AllVariablesNames(n)
			{
				if (n != '' && RegistryProvider.GetField(name(DataFieldPrefix$n), field))
				{
					SetSpecialValue(n, field.StringValue);
				}
			}
		}
	}
}

//**********************************************************************************
// Private funtions
//**********************************************************************************

final function Init()
{
	local string s;

	foreach Variables(s)
		VariablesNames.AddItem(name(s));

	foreach NonNotifyVariables(s)
		NonNotifyVariablesNames.AddItem(name(s));

	foreach NonNotifyVariables(s)
	{
		AllVariables.AddItem(s);
		AllVariablesNames.AddItem(name(s));
	}

	foreach Variables(s)
	{
		AllVariables.AddItem(s);
		AllVariablesNames.AddItem(name(s));
	}

	LoadConfigCustom();
}

final function Validate()
{
	if (BotRatio <= 0.0) BotRatio = 2.0;
	if (TeamRatio <= 0.0) TeamRatio = 2.0;

	if (LevelRecommendationMultiplier < 0)
		LevelRecommendationMultiplier = Abs(LevelRecommendationMultiplier);
	else if (LevelRecommendationMultiplier == 0.0)
		LevelRecommendationMultiplier = 1.0;

	if (SkillAdjustment == Algo_MAX)
		SkillAdjustment = Algo_Original;

	SkillAdjustmentFactor = FClamp(SkillAdjustmentFactor, 0.0, 7.0);
	if (SkillAdjustmentThreshold < 0)
		SkillAdjustmentThreshold = 1;
	if (SkillAdjustmentDisparity > 0.0)
		SkillAdjustmentDisparity = FMin(SkillAdjustmentDisparity, 7.0);

	if (SkillAdjustmentCampaignReduce < 0) SkillAdjustmentCampaignReduce = 0.5;
	else SkillAdjustmentCampaignReduce = FMin(SkillAdjustmentCampaignReduce, 7.0);
	if (SkillAdjustmentCampaignIncrease < 0) SkillAdjustmentCampaignIncrease = 0.75;
	else SkillAdjustmentCampaignIncrease = FMin(SkillAdjustmentCampaignIncrease, 7.0);

	if (SkillAdjustmentMinSkill >= 0.0) SkillAdjustmentMinSkill = FMin(SkillAdjustmentMinSkill, 7.0);
	if (SkillAdjustmentMaxSkill > 0.0) SkillAdjustmentMaxSkill = FMin(SkillAdjustmentMaxSkill, 7.0);
}

// Somehow the archetype values are changed. We need to reset the value hardcoded
function ResetConfig()
{
	`Log(name$"::ResetConfig",bShowDebug,'BotBalancer');

	BotRatio=2.0;
	TeamRatio=2.0;

	UseLevelRecommendation=false;
	LevelRecommendationMultiplier=1.0;
	LevelRecommendationOffsetPost=0;

	PreferUIMapInfo=true;
	UseUIMapInfoGametypeMultiplier=true;
	UseGlobalGametypeMultiplier=true;

	PlayersVsBots=false;
	PlayersSide=-1;
	AllowTeamChangeVsBots=false;
	SupportDeathmatch=false;

	AdjustBotSkill=true;
	SkillAdjustment=Algo_Adjustable;

	SkillAdjustmentFactor=0.15;
	SkillAdjustmentThreshold=1;
	SkillAdjustmentDisparity=1.25;
	SkillAdjustmentLikeCampaign=false;
	SkillAdjustmentCampaignReduce=0.5;
	SkillAdjustmentCampaignIncrease=0.75;
	SkillAdjustmentIndividual=true;
	SkillAdjustmentMinSkill=0;
	SkillAdjustmentMaxSkill=-1;

	EarlyInitialization=true;
	TryLoadingCharacterModels=true;

	// --- UT3 override config ---
	bPlayersBalanceTeams=true;
}

final function bool GetRegistry(out UIDynamicFieldProvider RegistryProvider)
{
	local DataStoreClient DSClient;
	local UIDataStore_Registry RegistryDS;

	DSClient = class'UIInteraction'.static.GetDataStoreClient();
	if ( DSClient != None )
	{
		RegistryDS = UIDataStore_Registry(DSClient.FindDataStore('Registry'));
		if ( RegistryDS != None )
		{
			RegistryProvider = RegistryDS.GetDataProvider();
			if ( RegistryProvider != None )
			{
				return true;
			}
		}
	}

	return false;
}

//**********************************************************************************
// Getter/Setter
//**********************************************************************************

function string GetSpecialValue(name PropertyName)
{
	local string str;
	`Log(name$"::GetSpecialValue - PropertyName:"@PropertyName,bShowDebug,'BotBalancer');

	switch (PropertyName)
	{
		case 'Variables':
			JoinArray(Variables, str, "|");
			return str;
		case 'AllVariables':
			JoinArray(AllVariables, str, "|");
			return str;
		case 'NonNotifyVariables':
			JoinArray(NonNotifyVariables, str, "|");
			return str;


		// Config

		case 'BotRatio': return string(BotRatio);
		case 'TeamRatio': return string(TeamRatio);
		
		case 'UseLevelRecommendation': return OutputBool(UseLevelRecommendation);
		case 'LevelRecommendationMultiplier': return string(LevelRecommendationMultiplier);
		case 'LevelRecommendationOffsetPost': return string(LevelRecommendationOffsetPost);

		case 'PreferUIMapInfo': return OutputBool(PreferUIMapInfo);
		case 'UseUIMapInfoGametypeMultiplier': return OutputBool(UseUIMapInfoGametypeMultiplier);
		case 'UseGlobalGametypeMultiplier': return OutputBool(UseGlobalGametypeMultiplier);

		case 'PlayersVsBots': return OutputBool(PlayersVsBots);
		case 'PlayersSide': return string(PlayersSide);
		case 'AllowTeamChangeVsBots': return OutputBool(AllowTeamChangeVsBots);
		case 'SupportDeathmatch': return OutputBool(SupportDeathmatch);

		case 'AdjustBotSkill': return OutputBool(AdjustBotSkill);
		case 'SkillAdjustment': return string(int(SkillAdjustment));

		case 'SkillAdjustmentFactor': return string(SkillAdjustmentFactor);
		case 'SkillAdjustmentThreshold': return string(SkillAdjustmentThreshold);
		case 'SkillAdjustmentDisparity': return string(SkillAdjustmentDisparity);
		case 'SkillAdjustmentLikeCampaign': return OutputBool(SkillAdjustmentLikeCampaign);
		case 'SkillAdjustmentCampaignReduce': return string(SkillAdjustmentCampaignReduce);
		case 'SkillAdjustmentCampaignIncrease': return string(SkillAdjustmentCampaignIncrease);
		case 'SkillAdjustmentIndividual': return OutputBool(SkillAdjustmentIndividual);
		case 'SkillAdjustmentMinSkill': return string(SkillAdjustmentMinSkill);
		case 'SkillAdjustmentMaxSkill': return string(SkillAdjustmentMaxSkill);

		case 'EarlyInitialization': return OutputBool(EarlyInitialization);
		case 'TryLoadingCharacterModels': return OutputBool(TryLoadingCharacterModels);

		// UT3 override config

		case 'bPlayersBalanceTeams': return OutputBool(bPlayersBalanceTeams);

	}

	`Log(name$"::GetSpecialValue - Nothing found. Return ZERO",bShowDebug,'BotBalancer');
	return "";
}

function SetSpecialValue(name PropertyName, string NewValue)
{
	`Log(name$"::SetSpecialValue - PropertyName:"@PropertyName@" - NewValue:"@NewValue,bShowDebug,'BotBalancer');

	switch (PropertyName)
	{
		// Config

		case 'BotRatio': BotRatio = ParseFloat(NewValue);break;
		case 'TeamRatio': TeamRatio = ParseFloat(NewValue);break;
		
		case 'UseLevelRecommendation': UseLevelRecommendation = ParseBool(NewValue);break;
		case 'LevelRecommendationMultiplier': LevelRecommendationMultiplier = ParseFloat(NewValue);break;
		case 'LevelRecommendationOffsetPost': LevelRecommendationOffsetPost = ParseInt(NewValue);break;

		case 'PreferUIMapInfo': PreferUIMapInfo = ParseBool(NewValue);break;
		case 'UseUIMapInfoGametypeMultiplier': UseUIMapInfoGametypeMultiplier = ParseBool(NewValue);break;
		case 'UseGlobalGametypeMultiplier': UseGlobalGametypeMultiplier = ParseBool(NewValue);break;

		case 'PlayersVsBots': PlayersVsBots = ParseBool(NewValue);break;
		case 'PlayersSide': PlayersSide = ParseInt(NewValue);break;
		case 'AllowTeamChangeVsBots': AllowTeamChangeVsBots = ParseBool(NewValue);break;
		case 'SupportDeathmatch': SupportDeathmatch = ParseBool(NewValue);break;

		case 'AdjustBotSkill': AdjustBotSkill = ParseBool(NewValue);break;
		case 'SkillAdjustment': SkillAdjustment = ESkillAdjustmentAlgorithm(int(NewValue));break;

		case 'SkillAdjustmentFactor': SkillAdjustmentFactor = ParseFloat(NewValue);break;
		case 'SkillAdjustmentThreshold': SkillAdjustmentThreshold = ParseInt(NewValue);break;
		case 'SkillAdjustmentDisparity': SkillAdjustmentDisparity = ParseFloat(NewValue);break;
		case 'SkillAdjustmentLikeCampaign': SkillAdjustmentLikeCampaign = ParseBool(NewValue);break;
		case 'SkillAdjustmentCampaignReduce': SkillAdjustmentCampaignReduce = ParseFloat(NewValue);break;
		case 'SkillAdjustmentCampaignIncrease': SkillAdjustmentCampaignIncrease = ParseFloat(NewValue);break;
		case 'SkillAdjustmentIndividual': SkillAdjustmentIndividual = ParseBool(NewValue);break;
		case 'SkillAdjustmentMinSkill': SkillAdjustmentMinSkill = ParseFloat(NewValue);break;
		case 'SkillAdjustmentMaxSkill': SkillAdjustmentMaxSkill = ParseFloat(NewValue);break;

		case 'EarlyInitialization': EarlyInitialization = ParseBool(NewValue);break;
		case 'TryLoadingCharacterModels': TryLoadingCharacterModels = ParseBool(NewValue);break;
	
		// UT3 override config

		case 'bPlayersBalanceTeams': bPlayersBalanceTeams = ParseBool(NewValue);break;

	}
}

//**********************************************************************************
// Static functions
//**********************************************************************************

static function string OutputBool(bool value)
{
	return value ? "1" : "0";
}

static function bool ParseBool(string value, optional bool defaultvalue = false)
{
	local string tmp;
	tmp = Locs(value);
	switch (tmp)
	{
		case "1":
		case "true":
		case "on":
		case "yes":
			return true;
			break;

		case "0":
		case "false":
		case "off":
		case "no":
			return false;
			break;

		default:
			return defaultvalue;
	}
}

static function float ParseFloat(string value)
{
	if (InStr(value, ",", false) != INDEX_NONE)
	{
		value = Repl(value, ",", "."); 
	}

	return float(value);
}

static function int ParseInt(string value)
{
	return int(value);
}

//**********************************************************************************
// Helper functions
//**********************************************************************************

/** Wrapper method for IsConsole which supports forcing PS3 on PC (on debug). Check FORCE_CONSOLE */
static function bool IsConsole()
{
	if (class'UIRoot'.static.IsConsole()

`if(`notdefined(FINAL_RELEASE))
`if(`isdefined(FORCE_CONSOLE))

		|| true

`endif
`endif

	)
	{
		return true;
	}

	return false;
}

DefaultProperties
{
	Variables.Add("BotRatio")
	Variables.Add("TeamRatio")
	
	Variables.Add("UseLevelRecommendation")
	Variables.Add("LevelRecommendationMultiplier")
	Variables.Add("LevelRecommendationOffsetPost")

	Variables.Add("PreferUIMapInfo")
	Variables.Add("UseUIMapInfoGametypeMultiplier")
	Variables.Add("UseGlobalGametypeMultiplier")
	
	Variables.Add("PlayersVsBots")
	Variables.Add("PlayersSide")
	Variables.Add("AllowTeamChangeVsBots")
	Variables.Add("SupportDeathmatch")

	Variables.Add("AdjustBotSkill")
	Variables.Add("SkillAdjustment")

	Variables.Add("SkillAdjustmentFactor")
	Variables.Add("SkillAdjustmentThreshold")
	Variables.Add("SkillAdjustmentDisparity")
	Variables.Add("SkillAdjustmentLikeCampaign")
	Variables.Add("SkillAdjustmentCampaignReduce")
	Variables.Add("SkillAdjustmentCampaignIncrease")
	Variables.Add("SkillAdjustmentIndividual")
	Variables.Add("SkillAdjustmentMinSkill")
	Variables.Add("SkillAdjustmentMaxSkill")

	Variables.Add("EarlyInitialization")
	Variables.Add("TryLoadingCharacterModels")

	Variables.Add("bPlayersBalanceTeams")

	DataFieldPrefix="BotBalancer_"

	// ---=== Config ===---

	BotRatio=2.0
	TeamRatio=2.0

	UseLevelRecommendation=true
	LevelRecommendationMultiplier=1.0
	LevelRecommendationOffsetPost=0

	PreferUIMapInfo=true
	UseUIMapInfoGametypeMultiplier=true
	UseGlobalGametypeMultiplier=true

	PlayersVsBots=false
	PlayersSide=-1
	AllowTeamChangeVsBots=false
	SupportDeathmatch=true

	AdjustBotSkill=true
	SkillAdjustment=Algo_Adjustable

	SkillAdjustmentFactor=0.15
	SkillAdjustmentThreshold=1
	SkillAdjustmentDisparity=1.25
	SkillAdjustmentLikeCampaign=false
	SkillAdjustmentCampaignReduce=0.5
	SkillAdjustmentCampaignIncrease=0.75
	SkillAdjustmentIndividual=true
	SkillAdjustmentMinSkill=0.0
	SkillAdjustmentMaxSkill=-1

	EarlyInitialization=true
	TryLoadingCharacterModels=true

	// --- UT3 override config ---
	bPlayersBalanceTeams=true
}
