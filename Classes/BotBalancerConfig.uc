class BotBalancerConfig extends Object
	config(NoMoreDemoGuy)
	perobjectconfig;

`if(`notdefined(FINAL_RELEASE))
	var bool bShowDebug;
`endif

//**********************************************************************************
// Config variables
//**********************************************************************************

var() config bool UseLevelRecommendation;
var() config bool PlayersVsBots;
var() config byte PlayersSide;
var() config float BotRatio;
var() config bool AllowTeamChangeVsBots;

// ---=== UT3 override config ===---

var() config bool bPlayersBalanceTeams;

//**********************************************************************************
// Workflow variables
//**********************************************************************************

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
/*native*/ simulated static function string Localize( string SectionName, string KeyName, string PackageName )
{
	local BotBalancerConfig cfg;

	if (SectionName ~= "WebAbdmin_ResetToDefaults" && KeyName == "" && PackageName == "")
	{
		cfg = GetConfig();
		cfg.ResetConfig();
		cfg.SaveConfig();
		return "";
	}

	return super.Localize(SectionName, KeyName, PackageName);
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
}

final function Validate()
{
	if (BotRatio <= 0.0) BotRatio = 2.0;
}

// Somehow the archetype values are changed. We need to reset the value hardcoded
function ResetConfig()
{
	`Log(name$"::ResetConfig",bShowDebug,'NoMoreDemoGuy');

	UseLevelRecommendation=false;
	PlayersVsBots=false;
	PlayersSide=0;
	BotRatio=2.0;
	AllowTeamChangeVsBots=false;

	// --- UT3 override config ---
	bPlayersBalanceTeams=true;
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

		case 'UseLevelRecommendation': return OutputBool(UseLevelRecommendation);
		case 'PlayersVsBots': return OutputBool(PlayersVsBots);
		case 'PlayersSide': return string(PlayersSide);
		case 'BotRatio': return string(BotRatio);
		case 'AllowTeamChangeVsBots': return OutputBool(AllowTeamChangeVsBots);

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

		case 'UseLevelRecommendation': UseLevelRecommendation = ParseBool(NewValue);break;
		case 'PlayersVsBots': PlayersVsBots = ParseBool(NewValue);break;
		case 'PlayersSide': PlayersSide = ParseInt(NewValue);break;
		case 'BotRatio': BotRatio = ParseFloat(NewValue);break;
		case 'AllowTeamChangeVsBots': AllowTeamChangeVsBots = ParseBool(NewValue);break;
	
		// UT3 override config

		case 'bPlayersBalanceTeams': bPlayersBalanceTeams = ParseBool(NewValue);break;

	}
}

//**********************************************************************************
// Static functions
//**********************************************************************************

function string OutputBool(bool value)
{
	return value ? "1" : "0";
}

function bool ParseBool(string value, optional bool defaultvalue = false)
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

function float ParseFloat(string value)
{
	if (InStr(value, ",", false) != INDEX_NONE)
	{
		value = Repl(value, ",", "."); 
	}

	return float(value);
}

function int ParseInt(string value)
{
	return int(value);
}

DefaultProperties
{
	Variables.Add("UseLevelRecommendation")
	Variables.Add("PlayersVsBots")
	Variables.Add("PlayersSide")
	Variables.Add("BotRatio")
	Variables.Add("AllowTeamChangeVsBots")

	Variables.Add("bPlayersBalanceTeams")


	// ---=== Config ===---

	UseLevelRecommendation=false
	PlayersVsBots=false
	PlayersSide=0
	BotRatio=2.0
	AllowTeamChangeVsBots=false

	// --- UT3 override config ---
	bPlayersBalanceTeams=true
}
