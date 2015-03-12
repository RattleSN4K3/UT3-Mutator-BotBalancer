class BotBalancerMutatorSettings extends Settings;

struct WebAdminGroups
{
	var localized string Name;
	var string ids;
	var int id;
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
	Groups[0]=(id=0,Name="General",ids="0,2")
	Groups[1]=(id=1,Name="Players vs. Bots",ids="20,23")
	Groups[2]=(id=2,Name="UT3 stock settings",ids="50,51")


	Properties(0)=(PropertyID=0,Data=(Type=SDT_Int32))
	PropertyMappings(0)=(ID=0,Name="UseLevelRecommendation",ColumnHeaderText="Use Level Recommendation",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(0)="Whether to use the level recommended player count for each map. Once  this is set, the player count will be adjusted to what ever the map has defined as min and max player count. A mean value will be used as bot player count."

	Properties(1)=(PropertyID=20,Data=(Type=SDT_Int32))
	PropertyMappings(1)=(ID=20,Name="PlayersVsBots",ColumnHeaderText="Players vs. Bots",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(1)="Whether to play a match with bots on one side (or multi sides with Multi-Team support) and humans players all in one team."

	Properties(2)=(PropertyID=21,Data=(Type=SDT_Int32))
	PropertyMappings(2)=(ID=21,Name="PlayersSide",ColumnHeaderText="Player side (for Player vs. Bots)",MappingType=PVMT_IdMapped,ValueMappings=((Id=-1,Name="Random"),(Id=0,Name="Red"),(Id=1,Name="Blue"),(Id=2,Name="Green"),(Id=3,Name="Gold"),(Id=255,Name="Unset")))
	PropertyDescriptions(2)="The player side in which all the human players will be put in when they connected. They can still change to the other side unless 'Allow Team Change' not allowed."

	Properties(3)=(PropertyID=1,Data=(Type=SDT_Float))
	PropertyMappings(3)=(ID=1,Name="BotRatio",ColumnHeaderText="Bot/Player Ratio",MappingType=PVMT_Ranged,MinVal=0.0001,MaxVal=64.0,RangeIncrement=0.5)
	PropertyDescriptions(3)="The number of bots to balance for each player in the oppoenent team. Basically this values represents how much player a human player results. A value of 2.0 would mean that a human player is as strong as 2 bots."

	Properties(4)=(PropertyID=22,Data=(Type=SDT_Int32))
	PropertyMappings(4)=(ID=22,Name="AllowTeamChangeVsBots",ColumnHeaderText="Allow Team Change (in Player vs. Bots)",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(4)="Whether to allow team changes for human player in Players vs. Bots mode. When this value is set, the any human player will be forced to play on the human side."


	// ---=== UT3 override config ===---

	Properties(5)=(PropertyID=50,Data=(Type=SDT_Int32))
	PropertyMappings(5)=(ID=50,Name="bPlayersBalanceTeams",ColumnHeaderText="Players Balance Teams",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="no "),(ID=1,Name="yes ")))
	PropertyDescriptions(5)="Joining players will join the team with the least players."
}
