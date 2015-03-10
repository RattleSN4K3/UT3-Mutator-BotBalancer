class BotBalancerUIFrontendConfig extends UTUIFrontEnd;

//**********************************************************************************
// Variables
//**********************************************************************************

var transient localized string Title;

//'''''''''''''''''''''''''
// Workflow variables
//'''''''''''''''''''''''''

var transient class<Settings> SettingsClass;
var transient class<Object> ConfigClass;

var transient bool bRegeneratingOptions;	// Used to detect when the options are being regenerated

//'''''''''''''''''''''''''
// UI element variables
//'''''''''''''''''''''''''

/** Reference to the messagebox scene. */
var transient UTUIScene_MessageBox MessageBoxReference;

// Reference to the options page and list
var transient UTUITabPage_DynamicOptions OptionsPage;
var transient UTUIDynamicOptionList OptionsList;

//**********************************************************************************
// Inherited funtions
//**********************************************************************************

/** Post initialize callback */
event PostInitialize()
{
	`Log(name$"::PostInitialize",,'BotBalancer');

	super.PostInitialize();

	OptionsPage = UTUITabPage_DynamicOptions(FindChild('pnlOptions', True));
	//OptionsPage.OnOptionChanged = OnOptionChanged;

	OptionsList = UTUIDynamicOptionList(FindChild('lstOptions', True));

	SetupMenuOptions();
}

/** Sets the title for this scene. */
function SetTitle()
{
	//local string FinalStr;
	local UILabel TitleLabel;

	`Log(name$"::SetTitle",,'BotBalancer');

	TitleLabel = GetTitleLabel();
	if ( TitleLabel != None )
	{
		if(TabControl == None)
		{
			//FinalStr = Caps(Localize("Titles", string(SceneTag), string(GetPackageName())));
			TitleLabel.SetDataStoreBinding(Title);
		}
		else
		{
			TitleLabel.SetDataStoreBinding("");
		}
	}
}

function SetupButtonBar()
{
	`Log(name$"::SetupButtonBar",,'BotBalancer');

	if (ButtonBar != none)
	{
		ButtonBar.Clear();
		ButtonBar.AppendButton("<Strings:UTGameUI.ButtonCallouts.Back>", OnButtonBar_Back);
		ButtonBar.AppendButton("<Strings:UTGameUI.ButtonCallouts.Accept>", OnButtonBar_Accept);
		ButtonBar.AppendButton("<Strings:UTGameUI.ButtonCallouts.ResetToDefaults>", OnButtonBar_ResetToDefaults);
	}
}


/**
 * Provides a hook for unrealscript to respond to input using actual input key names (i.e. Left, Tab, etc.)
 *
 * Called when an input key event is received which this widget responds to and is in the correct state to process.  The
 * keys and states widgets receive input for is managed through the UI editor's key binding dialog (F8).
 *
 * This delegate is called BEFORE kismet is given a chance to process the input.
 *
 * @param	EventParms	information about the input event.
 *
 * @return	TRUE to indicate that this input key was processed; no further processing will occur on this input key event.
 */
function bool HandleInputKey( const out InputEventParameters EventParms )
{
	local bool bResult;

	`Log(name$"::HandleInputKey",,'BotBalancer');

	// Let the binding list get first chance at the input because the user may be binding a key.
	bResult=OptionsPage != none && OptionsPage.HandleInputKey(EventParms);

	if(bResult == false)
	{
		if(EventParms.EventType==IE_Released)
		{
			if(EventParms.InputKeyName=='XboxTypeS_B' || EventParms.InputKeyName=='Escape')
			{
				OnBack();
				bResult=true;
			}
			else if(EventParms.InputKeyName=='XboxTypeS_LeftTrigger')
			{
				OnResetToDefaults();
				bResult=true;
			}
		}
	}

	return bResult;
}

//**********************************************************************************
// Delegate callbacks
//**********************************************************************************

/** Button bar callbacks */
function bool OnButtonBar_Accept(UIScreenObject InButton, int PlayerIndex)
{
	`Log(name$"::OnButtonBar_Accept - InButton:"@InButton$" - PlayerIndex:"@PlayerIndex,,'BotBalancer');

	OnAccept();
	CloseScene(Self);

	return true;
}

function bool OnButtonBar_Back(UIScreenObject InButton, int PlayerIndex)
{
	`Log(name$"::OnButtonBar_Back - InButton:"@InButton$" - PlayerIndex:"@PlayerIndex,,'BotBalancer');
	OnBack();

	return true;
}

/** Buttonbar Callback. */
function bool OnButtonBar_ResetToDefaults(UIScreenObject InButton, int InPlayerIndex)
{
	`Log(name$"::OnButtonBar_ResetToDefaults - InButton:"@InButton$" - InPlayerIndex:"@InPlayerIndex,,'BotBalancer');
	OnResetToDefaults();

	return true;
}

/**
 * Callback for the reset to defaults confirmation dialog box.
 *
 * @param SelectionIdx	Selected item
 * @param PlayerIndex	Index of player that performed the action.
 */
function OnResetToDefaults_Confirm(UTUIScene_MessageBox MessageBox, int SelectionIdx, int PlayerIndex)
{
	`Log(name$"::OnResetToDefaults_Confirm - MessageBox:"@MessageBox$" - SelectionIdx:"@SelectionIdx$" - PlayerIndex:"@PlayerIndex,,'BotBalancer');

	if(SelectionIdx==0)
	{
		ResetToDefaults();
		CloseScene(self);
	}
	else
	{
		OptionsPage.OptionList.SetFocus(none);
	}
}

//**********************************************************************************
// Button functions
//**********************************************************************************

function OnBack()
{
	`Log(name$"::OnBack",,'BotBalancer');
	CloseScene(self);
}

function OnAccept()
{
	local UIObject CurObject;
	local UICheckbox CurCheckBox;
	//local UIEditBox CurEditBox;
	local int i;
	local name n;
	local string value;
	local bool boolvalue;

	local Settings SettingsObj;

	`Log(name$"::OnAccept",,'BotBalancer');

	SettingsObj = new SettingsClass;
	SettingsObj.SetSpecialValue('WebAdmin_Init', "");
	for (i=0; i<SettingsObj.PropertyMappings.Length; i++) 
	{
		n = SettingsObj.PropertyMappings[i].Name;
		if (FindOptionObjectByName(OptionsList, n, CurObject))
		{
			CurCheckBox = UICheckbox(CurObject);
			if (CurCheckBox != none)
			{
				boolvalue = CurCheckBox.IsChecked();
				value = string(int(boolvalue));
				SettingsObj.SetPropertyFromStringByName(n, value);
				continue;
			}
		}
	}

	`Log(name$"::OnAccept - Save config",,'BotBalancer');
	SettingsObj.SetSpecialValue('WebAdmin_Save', "");
}

/** Reset to defaults callback. */
function OnResetToDefaults()
{
	local array<string> MessageBoxOptions;

	`Log(name$"::OnResetToDefaults",,'BotBalancer');

	MessageBoxReference = GetMessageBoxScene();

	if(MessageBoxReference != none)
	{
		MessageBoxOptions.AddItem("<Strings:UTGameUI.ButtonCallouts.ResetToDefaultAccept>");
		MessageBoxOptions.AddItem("<Strings:UTGameUI.ButtonCallouts.Cancel>");

		MessageBoxReference.SetPotentialOptions(MessageBoxOptions);
		MessageBoxReference.Display("<Strings:UTGameUI.MessageBox.ResetToDefaults_Message>", "<Strings:UTGameUI.MessageBox.ResetToDefaults_Title>", OnResetToDefaults_Confirm, 1);
	}
}

//function AdjustSkin()
//{
//	local UISkin Skin;

//	// make sure we're using the right skin
//	Skin = UISkin(DynamicLoadObject("UI_Skin_Derived.UTDerivedSkin",class'UISkin'));
//	if ( Skin != none )
//	{
//		SceneClient.ChangeActiveSkin(Skin);
//	}
//}

//**********************************************************************************
// Init funtions
//**********************************************************************************

function string GetFriendlyNameOfSetting(name PropertyName)
{
	local string ret;
	local int index;
	index = SettingsClass.default.PropertyMappings.Find('Name', PropertyName);
	if (index != INDEX_NONE)
		ret = SettingsClass.default.PropertyMappings[index].ColumnHeaderText;

	return ret;
}

function string GetDescriptionOfSetting(name PropertyName)
{
	local string ret;
	local Settings Setts;
	local string str;

	ret = Localize(SettingsClass.name$" Tooltips", string(PropertyName), string(SettingsClass.GetPackageName()));
	if (Left(ret, 1) == "?")
	{
		ret = "";

		Setts = new SettingsClass;
		if (Setts != none)
		{
			str = "PropertyDescription"$"_"$PropertyName;
			ret = Setts.GetSpecialValue(name(str));
		}
	}
	
	return ret;
}

function bool PopulateMenuOption(name PropertyName, out DynamicMenuOption menuopt)
{
	local bool ret;
	local SettingsProperty prop;
	local SettingsPropertyPropertyMetaData prop_mapping;
	local UIRangeData EmptyRange;

	if (GetSettingsProperties(PropertyName, prop, prop_mapping))
	{
		///** Means the data in the OnlineData value fields should be ignored */
		//SDT_Empty,
		///** 32 bit integer goes in Value1 only*/
		//SDT_Int32,
		///** 64 bit integer stored in both value fields */
		//SDT_Int64,
		///** Double (8 byte) stored in both value fields */
		//SDT_Double,
		///** Unicode string pointer in Value2 with length in Value1 */
		//SDT_String,
		///** Float (4 byte) stored in Value1 fields */
		//SDT_Float,
		///** Binary data with count in Value1 and pointer in Value2 */
		//SDT_Blob,
		///** Date/time structure. Date in Value1 and time Value2 */
		//SDT_DateTime
		switch (prop.Data.Type)
		{

			//	UTOT_ComboReadOnly,
			//	UTOT_ComboNumeric,
			//	UTOT_CheckBox,
			//	UTOT_Slider,
			//	UTOT_Spinner,
			//	UTOT_EditBox,
			//	UTOT_CollectionCheckBox

			case SDT_String:
				menuopt.OptionType = UTOT_EditBox;

				///** Allows all charcters */
				//CHARSET_All,
				///** Ignores special characters like !@# */
				//CHARSET_NoSpecial,
				///** Allows only alphabetic characters */
				//CHARSET_AlphaOnly,
				///** Allows only numeric characters */
				//CHARSET_NumericOnly,
				///** Allows alpha numeric characters (a-z,A-Z,0-9) */
				//CHARSET_AlphaNumeric,
				menuopt.EditboxAllowedChars = CHARSET_All;

				ret = true;
				break;
			case SDT_Int32:
				if (prop_mapping.MappingType == PVMT_IDMapped)
				{
					if (prop_mapping.ValueMappings.Length == 2)
					{
						menuopt.OptionType = UTOT_CheckBox;
						ret = true;
					}
				}
				break;
			case SDT_Float:
				if (prop_mapping.MappingType == PVMT_RawValue || prop_mapping.MappingType == PVMT_Ranged)
				{
					menuopt.OptionType = UTOT_Spinner;
					menuopt.RangeData = EmptyRange;
					menuopt.RangeData.MinValue = prop_mapping.MinVal;
					menuopt.RangeData.MaxValue = prop_mapping.MaxVal;

					if (prop_mapping.MappingType == PVMT_RawValue)
						menuopt.RangeData.bIntRange = true;
					else
						menuopt.RangeData.bIntRange = false;

					menuopt.RangeData.NudgeValue = prop_mapping.RangeIncrement;
					ret = true;
				}
				
				break;

		}
	}
	
	return ret;
}

function bool GetSettingsProperties(name PropertyName, out SettingsProperty out_Property, out SettingsPropertyPropertyMetaData out_PropertyMapping)
{
	local int index;
	index = SettingsClass.default.PropertyMappings.Find('Name', PropertyName);
	if (index != INDEX_NONE)
	{
		out_PropertyMapping = SettingsClass.default.PropertyMappings[index];
		if (index < SettingsClass.default.Properties.Length)
		{
			out_Property = SettingsClass.default.Properties[index];
			return true;
		}
	}

	return false;
}

// Initializes the menu option templates, and regenerates the option list
function SetupMenuOptions()
{
	local DynamicMenuOption CurMenuOpt, EmptyMenuOpt;
	local int i;
	local name n;

	`Log(name$"::SetupMenuOptions",,'BotBalancer');

	if (OptionsPage == none || OptionsList == none)
		return;

	bRegeneratingOptions = True;
	OptionsList.DynamicOptionTemplates.Length = 0;

	for (i=0; i<SettingsClass.default.PropertyMappings.Length; i++) 
	{
		n = SettingsClass.default.PropertyMappings[i].Name;

		CurMenuOpt = EmptyMenuOpt;
		CurMenuOpt.OptionName = n;
		CurMenuOpt.OptionType = UTOT_CheckBox;
		CurMenuOpt.FriendlyName = SettingsClass.default.PropertyMappings[i].ColumnHeaderText;
		CurMenuOpt.Description = GetDescriptionOfSetting(n);

		OptionsList.DynamicOptionTemplates.AddItem(CurMenuOpt);
	}

	// Generate the option controls
	i = OptionsList.CurrentIndex;

	OptionsList.OnSetupOptionBindings = SetupOptionBindings;
	OptionsList.RegenerateOptions();

	// If the list index was set, return to the previous position
	if (i != INDEX_NONE)
	{
		i = Clamp(i, 0, OptionsList.GeneratedObjects.Length-1);
		OptionsList.GeneratedObjects[i].OptionObj.SetFocus(None);

		// Disable the initiated selection change animation, so that it jumps to the focused object immediately
		OptionsList.bAnimatingBGPrefab = False;
	}
}

// Setup the data source bindings (but not the values)
function SetupOptionBindings()
{
	local UICheckbox CurCheckBox;
	//local UIEditBox CurEditBox;
	local UIObject CurObject;
	local int i;
	local name n;
	local string value;
	local bool boolvalue;

	local Settings SettingsObj;
	local int PropertyId;

	`Log(name$"::SetupOptionBindings",,'BotBalancer');

	SettingsObj = new SettingsClass;
	SettingsObj.SetSpecialValue('WebAdmin_Init', "");
	for (i=0; i<SettingsObj.PropertyMappings.Length; i++) 
	{
		n = SettingsObj.PropertyMappings[i].Name;
		if (SettingsObj.GetPropertyId(n, PropertyId) &&
			SettingsObj.HasProperty(PropertyId) &&
			FindOptionObjectByName(OptionsList, n, CurObject))
		{
			value = SettingsObj.GetPropertyAsString(PropertyId);

			CurCheckBox = UICheckbox(CurObject);
			if (CurCheckBox != none)
			{
				`Log(name$"::SetupOptionBindings - Set to checkbox",,'BotBalancer');
				boolvalue = bool(value);
				CurCheckBox.SetValue(boolvalue);
				continue;
			}
		}
	}

	bRegeneratingOptions = False;
}


//**********************************************************************************
// Private functions
//**********************************************************************************

function ResetToDefaults()
{
	`Log(name$"::ResetToDefaults",,'BotBalancer');

	ConfigClass.static.Localize("WebAdmin_ResetToDefaults", "", "");
	ConfigClass.static.StaticSaveConfig();
}

// Handles finding and casting generated option controls
static final function UICheckbox FindOptionCheckBoxByName(UTUIOptionList List, name OptionName)
{
	local int i;

	i = List.GetObjectInfoIndexFromName(OptionName);

	if (i != INDEX_None)
		return UICheckbox(List.GeneratedObjects[i].OptionObj);

	return None;
}

// Handles finding generated option controls
static final function bool FindOptionObjectByName(UTUIOptionList List, name OptionName, out UIObject obj)
{
	local int i;

	i = List.GetObjectInfoIndexFromName(OptionName);

	if (i != INDEX_None)
		obj = List.GeneratedObjects[i].OptionObj;
	else
		obj = none;

	return (obj != none);
}

defaultproperties
{
	Title="Configure BotBalancer"

	SettingsClass=class'BotBalancerMutatorSettings'
	ConfigClass=class'BotBalancerMutator'
}
