class BotBalancerUIFrontendConfig extends UTUIFrontEnd;

//**********************************************************************************
// Variables
//**********************************************************************************

var() transient localized string Title;

//'''''''''''''''''''''''''
// Workflow variables
//'''''''''''''''''''''''''

var transient array<SUIIdStringCollectionInfo> CollectionsIdStr;
var transient UTUIDataStore_2DStringList StringDatastore;
var() transient class<UTUIDataStore_2DStringList> StringDatastoreClass;
var transient array<name> RegisteredDatafields;
var() transient string DataFieldPrefix;

var() transient class<Settings> SettingsClass;
var() transient class<Object> ConfigClass;

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

/** Scene activated event, sets up the title for the scene. */
event SceneActivated(bool bInitialActivation)
{
	Super.SceneActivated(bInitialActivation);

	FocusList();
}

/** Called just after this scene is removed from the active scenes array */
event SceneDeactivated()
{
	local int i;

	if (StringDatastore != none)
	{
		for (i=0; i<RegisteredDatafields.Length; i++)
		{
			StringDatastore.RemoveField(RegisteredDatafields[i]);
		}
		StringDatastore = none;
	}

	super.SceneDeactivated();
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
// Init funtions
//**********************************************************************************

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

		if (PopulateMenuOption(n, CurMenuOpt))
		{
			OptionsList.DynamicOptionTemplates.AddItem(CurMenuOpt);
		}
	}

	// Generate the option controls
	i = OptionsList.CurrentIndex;

	OptionsList.OnSetupOptionBindings = SetupOptionBindings;
	OptionsList.RegenerateOptions();

	// If the list index was set, return to the previous position
	FocusList(i);
}

// Setup the data source bindings (but not the values)
function SetupOptionBindings()
{
	local UIObject CurObject;
	local int i;
	local name n;
	local string value, newvalue;

	local Settings SettingsObj;
	local int PropertyId;

	`Log(name$"::SetupOptionBindings",,'BotBalancer');

	SettingsObj = new SettingsClass;
	SettingsObj.SetSpecialValue('WebAdmin_Init', "");

	// Generate list collections
	for (i=0; i<OptionsList.GeneratedObjects.Length; i++)
	{
		PopulateMenuObject(OptionsList.GeneratedObjects[i]);
	}

	// Set values to menu items
	for (i=0; i<SettingsObj.PropertyMappings.Length; i++) 
	{
		n = SettingsObj.PropertyMappings[i].Name;
		if (SettingsObj.GetPropertyId(n, PropertyId) &&
			SettingsObj.HasProperty(PropertyId) &&
			FindOptionObjectByName(OptionsList, n, CurObject))
		{
			value = SettingsObj.GetPropertyAsString(PropertyId);
			if (GetCollectionIndexValue(n, value, newvalue))
			{
				value = newvalue;
			}

			SetOptionObjectValue(CurObject, value);
		}
	}

	bRegeneratingOptions = False;
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
					if (prop_mapping.ValueMappings.Length <= 2)
					{
						menuopt.OptionType = UTOT_CheckBox;
						ret = true;
					}
					else if (prop_mapping.ValueMappings.Length == 0)
					{
						menuopt.OptionType = UTOT_CheckBox;
						ret = true;
					}
					else
					{
						// more than 2
						menuopt.OptionType = UTOT_ComboReadOnly;

						//menuopt.OptionType = UTOT_Slider;
						//menuopt.RangeData = EmptyRange;
						//menuopt.RangeData.MinValue = 0;
						//menuopt.RangeData.MaxValue = prop_mapping.ValueMappings.Length-1;
						//menuopt.RangeData.bIntRange = true;
						ret = true;
					}
				}
				//else if (prop_mapping.MappingType == PVMT_Ranged)
				//{
				//	menuopt.OptionType = UTOT_Slider;
				//	menuopt.RangeData = EmptyRange;
				//	menuopt.RangeData.MinValue = prop_mapping.MinVal;
				//	menuopt.RangeData.MaxValue = prop_mapping.MaxVal;
				//	menuopt.RangeData.bIntRange = true;

				//	menuopt.RangeData.NudgeValue = prop_mapping.RangeIncrement;
				//	ret = true;
				//}
				else if (prop_mapping.MappingType == PVMT_Ranged)
				{
					menuopt.OptionType = UTOT_Spinner;
					menuopt.RangeData = EmptyRange;
					menuopt.RangeData.MinValue = prop_mapping.MinVal;
					menuopt.RangeData.MaxValue = prop_mapping.MaxVal;
					menuopt.RangeData.NudgeValue = prop_mapping.RangeIncrement;
					menuopt.RangeData.bIntRange = true;
					ret = true;
				}

				// PVMT_RawValue
				else
				{
					menuopt.OptionType = UTOT_EditBox;
					menuopt.EditboxAllowedChars = CHARSET_NumericOnly;

					ret = true;
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

			case SDT_Int64:
				if (prop_mapping.MappingType == PVMT_IDMapped)
				{
					if (prop_mapping.ValueMappings.Length < 2)
					{
						menuopt.OptionType = UTOT_CheckBox;
						ret = true;
					}
					else
					{
						menuopt.OptionType = UTOT_ComboReadOnly;
						ret = true;
					}
				}
				else
				{
					menuopt.OptionType = UTOT_EditBox;
					menuopt.EditboxAllowedChars = CHARSET_NumericOnly;

					ret = true;
				}
				break;

		}
	}
	
	return ret;
}

function bool PopulateMenuObject(GeneratedObjectInfo OI)
{
	local UIComboBox CurComboBox;
	//local UISlider CurSlider;
	local UIEditBox CurEditBox;
	local UILabel CurLabel;
	local int i;
	local array<int> arrids;
	local array<string> arrnames;
	local string markupstring;

	if (Left(OI.OptionProviderName, 9) ~= "Separator")
	{
		// DOES NOT WORK WITH SCROLLING
		//OI.OptionObj.SetVisibility(false);

		CurEditBox = UIEditBox(OI.OptionObj);
		if (CurEditBox != none)
		{
			CurEditBox.BackgroundImageComponent.SetOpacity(0.0);
			CurEditBox.StringRenderComponent.SetOpacity(0.0);
			CurEditBox.SetReadOnly(true);

			// DOES NOT WORK; SAME EFFECT AS SetVisibility(false)
			//CurEditBox.SetPrivateBehavior(PRIVATE_NotFocusable, true);
		}

		CurLabel = UILabel(OI.LabelObj);
		if (CurLabel != none)
		{
			CurLabel.SetTextAlignment(UIALIGN_Center, UIALIGN_Right);
			CurLabel.SetWidgetStyleByName('String Style', 'SceneTitles01'); //ToolTips
		}
		return true;
	}

	CurComboBox = UIComboBox(OI.OptionObj);
	if (UIComboBox(OI.OptionObj) != none && GetSettingsCollection(OI.OptionProviderName, arrids, arrnames))
	{
		markupstring = CreateDataStoreStringList(OI.OptionProviderName, arrnames);
		CurComboBox.ComboList.SetDataStoreBinding(markupstring);
		CurComboBox.ComboList.RefreshSubscriberValue();

		i = CollectionsIdStr.Length;
		CollectionsIdStr.Add(1);

		CollectionsIdStr[i].Ids = arrids;
		CollectionsIdStr[i].Names = arrnames;
		CollectionsIdStr[i].Option = OI.OptionProviderName;
		return true;
	}

	// DOES NOT WORK

	//CurSlider = UISlider(OI.OptionObj);
	//if (CurSlider != none && GetSettingsCollection(OI.OptionProviderName, arrids, arrnames))
	//{
	//	markupstring = CreateDataStoreStringList(OI.OptionProviderName, arrnames);
	//	CurSlider.DataSource.
	//	CurSlider.SetDataStoreBinding(markupstring);
	//	CurSlider.RefreshSubscriberValue();

	//	i = CollectionsIdStr.Length;
	//	CollectionsIdStr.Add(1);

	//	CollectionsIdStr[i].Ids = arrids;
	//	CollectionsIdStr[i].Names = arrnames;
	//	CollectionsIdStr[i].Option = OI.OptionProviderName;
	//	return true;
	//}

	return false;
}

//**********************************************************************************
// UI callbacks
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
	else if (OptionsPage != none)
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
	local int i;
	local name n;
	local string value, newvalue;

	local Settings SettingsObj;

	`Log(name$"::OnAccept",,'BotBalancer');

	SettingsObj = new SettingsClass;
	SettingsObj.SetSpecialValue('WebAdmin_Init', "");
	for (i=0; i<SettingsObj.PropertyMappings.Length; i++) 
	{
		n = SettingsObj.PropertyMappings[i].Name;
		if (FindOptionObjectByName(OptionsList, n, CurObject) &&
			GetOptionObjectValue(CurObject, value))
		{
			if (GetCollectionIndexId(n, value, newvalue))
			{
				value = newvalue;
			}

			SettingsObj.SetPropertyFromStringByName(n, value);
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

//**********************************************************************************
// UI functions
//**********************************************************************************

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

function FocusList(optional int index = INDEX_NONE)
{
	local int i;

	if (OptionsList == none)
		return;

	if (index == INDEX_NONE)
		index = 0;
	
	// find element which is not a separator
	for (i=index; i<OptionsList.GeneratedObjects.Length; i++)
	{
		if (Left(OptionsList.GeneratedObjects[i].OptionProviderName, 9) ~= "Separator") continue;

		index = i;
		break;
	}
	
	OptionsList.GeneratedObjects[index].OptionObj.SetFocus(None);

	// Disable the initiated selection change animation, so that it jumps to the focused object immediately
	OptionsList.bAnimatingBGPrefab = False;
}

function string GetDescriptionOfSetting(name PropertyName, optional Settings Setts)
{
	local string ret;
	local string str;

	ret = Localize(SettingsClass.name$" Tooltips", string(PropertyName), string(class.GetPackageName()));
	if (Len(ret) == 0 || Left(ret, 1) == "?")
	{
		ret = "";

		if (Setts == none)
		{
			Setts = new SettingsClass;
		}

		if (Setts != none)
		{
			str = "PropertyDescription"$"_"$PropertyName;
			ret = Setts.GetSpecialValue(name(str));
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

function bool GetSettingsCollection(name PropertyName, out array<int> out_ids, out array<string> out_names)
{
	local SettingsProperty prop;
	local SettingsPropertyPropertyMetaData prop_mapping;
	local int i;
	local string str;

	if (GetSettingsProperties(PropertyName, prop, prop_mapping))
	{
		out_ids.Length = 0;
		out_names.Length = 0;
		for (i=0; i<prop_mapping.ValueMappings.Length; i++)
		{
			out_ids.AddItem(prop_mapping.ValueMappings[i].Id);

			str = string(prop_mapping.ValueMappings[i].Name);
			out_names.AddItem(str);
		}
		return true;
	}

	return false;
}

function bool GetCollectionName(name PropertyName, string str_index, out string out_value)
{
	local int index, i;
	index = CollectionsIdStr.Find('Option', PropertyName);
	if (index != INDEX_NONE)
	{
		i = int(str_index);
		if (i >= INDEX_NONE && i < CollectionsIdStr[index].Names.Length)
		{
			out_value = CollectionsIdStr[index].Names[i];
			return true;
		}			
	}

	return false;
}

function bool GetCollectionIndexValue(name PropertyName, string str_index, out string out_value)
{
	local int index, i;
	index = CollectionsIdStr.Find('Option', PropertyName);
	if (index != INDEX_NONE)
	{
		i = CollectionsIdStr[index].Ids.Find(int(str_index));
		if (i != INDEX_NONE)
		{
			out_value = CollectionsIdStr[index].Names[i];
			return true;
		}				
	}

	return false;
}

function bool GetCollectionIndexId(name PropertyName, string value, out string out_id)
{
	local int index, i;
	index = CollectionsIdStr.Find('Option', PropertyName);
	if (index != INDEX_NONE)
	{
		i = CollectionsIdStr[index].Names.Find(value);
		if (i != INDEX_NONE)
		{
			out_id = ""$CollectionsIdStr[index].Ids[i];
			return true;
		}				
	}

	return false;
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

function string CreateDataStoreStringList(name listname, array<string> entries)
{
	local DataStoreClient DSC;
	local string fieldstr, ret;
	local name fieldname;
	local int i;

	// Get a reference to (or create) a 2D string list data store
	DSC = Class'UIInteraction'.static.GetDataStoreClient();

	if (StringDatastore == none)
	{
		StringDatastore = UTUIDataStore_2DStringList(DSC.FindDataStore(StringDatastoreClass.default.Tag));
		if (StringDatastore == none)
		{
			StringDatastore = DSC.CreateDataStore(StringDatastoreClass);
			DSC.RegisterDataStore(StringDatastore);
		}
	}

	fieldstr = DataFieldPrefix$listname;
	fieldname = name(fieldstr);
	// Setup and fill the data fields within the data store (if they are not already set)
	if (StringDatastore.GetFieldIndex(fieldname) == INDEX_None)
	{
		i = StringDataStore.AddField(fieldname);
		StringDatastore.AddFieldList(i, listname);
		StringDataStore.UpdateFieldList(i, listname, entries);

		RegisteredDatafields.AddItem(fieldname);
	}

	ret = "<"$StringDatastore.Tag$":"$fieldname$">";
	return ret;
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

static final function bool GetOptionObjectValue(UIObject obj, out string value)
{
	local UICheckbox CurCheckBox;
	local UIEditBox CurEditBox;
	local UINumericEditBox CurNumEditBox;
	local UIComboBox CurComboBox;
	//local UISlider CurSlider;
	local bool boolvalue;
	local float floatvalue;
	
	CurCheckBox = UICheckbox(obj);
	if (CurCheckBox != none)
	{
		boolvalue = CurCheckBox.IsChecked();
		value = string(int(boolvalue));
			
		return true;
	}

	CurNumEditBox = UINumericEditBox(obj);
	if (CurNumEditBox != none)
	{
		//floatvalue = CurNumEditBox.GetNumericValue();
		floatvalue = float(CurNumEditBox.GetValue(true));

		value = string(floatvalue);
		
		return true;
	}

	CurEditBox = UIEditBox(obj);
	if (CurEditBox != none)
	{
		value = CurEditBox.GetValue(true);
		
		return true;
	}

	CurComboBox = UIComboBox(obj);
	if (CurComboBox != none)
	{
		value = CurComboBox.ComboEditbox.GetValue(true);
		
		return true;
	}

	//CurSlider = UISlider(obj);
	//if (CurSlider != none)
	//{
	//	value = string(CurSlider.GetValue());
		
	//	return true;
	//}

	return false;
}

static final function bool SetOptionObjectValue(UIObject obj, string value, optional string markupstring)
{
	local UICheckbox CurCheckBox;
	local UIEditBox CurEditBox;
	local UINumericEditBox CurNumEditBox;
	local UIComboBox CurComboBox;
	//local UISlider CurSlider;
	local bool boolvalue;
	local float floatvalue;
	local int index;
	
	CurCheckBox = UICheckbox(obj);
	if (CurCheckBox != none)
	{
		boolvalue = bool(value);
		CurCheckBox.SetValue(boolvalue);

		return true;
	}

	CurNumEditBox = UINumericEditBox(obj);
	if (CurNumEditBox != none)
	{
		floatvalue = class'NoMoreDemoGuy'.static.ParseFloat(value);
		CurNumEditBox.SetNumericValue(floatvalue, true);
		return true;
	}

	CurEditBox = UIEditBox(obj);
	if (CurEditBox != none)
	{
		CurEditBox.SetDataStoreBinding(value);
		return true;
	}

	CurComboBox = UIComboBox(obj);
	if (CurComboBox != none)
	{
		index = CurComboBox.ComboList.FindItemIndex(value);
		if (index != INDEX_NONE)
		{
			CurComboBox.ComboEditbox.SetDataStoreBinding(value);
			CurComboBox.ComboList.SetIndex(index);
		}
		//index = int(value);
		//if (index < arrstring.Length)
		//{
		//	//CurComboBox.ComboEditbox.SetDataStoreBinding(arrstring[index]);
		//	//CurComboBox.ComboList.SetIndex(index);
		//}
		return true;
	}

	//CurSlider = UISlider(obj);
	//if (CurSlider != none)
	//{
	//	CurSlider.SetValue(value);
	//}

	return false;
}

defaultproperties
{
	Title="Configure BotBalancer"

	SettingsClass=class'BotBalancerMutatorSettings'
	ConfigClass=class'BotBalancerMutator'

	StringDatastoreClass=class'UTUIDataStore_2DStringList'
	DataFieldPrefix="BotBalancer_"
}
