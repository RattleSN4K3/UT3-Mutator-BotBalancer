class BotBalancerUIFrontendConfig extends UTUIFrontEnd;

// Constants
// -----------------

Const SkinPath = "UI_Skin_Derived.UTDerivedSkin";

//**********************************************************************************
// Variables
//**********************************************************************************

var() transient localized string Title;

//'''''''''''''''''''''''''
// Workflow variables
//'''''''''''''''''''''''''

var transient bool bPendingClose;
var transient bool bRegeneratingOptions;	// Used to detect when the options are being regenerated

var() transient class<Object> SettingsClass;
var() transient class<Object> ConfigClass;

//'''''''''''''''''''''''''
// UI element variables
//'''''''''''''''''''''''''

/** Reference to the messagebox scene. */
var transient UTUIScene_MessageBox MessageBoxReference;

var transient UISkin OriginalSkin;

//**********************************************************************************
// Inherited funtions
//**********************************************************************************

/** Post initialize callback */
event PostInitialize()
{
	`Log(name$"::PostInitialize",,'BotBalancer');

	//AdjustSkin();
	super.PostInitialize();

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
	// revert skin before we set the pending close flag otherwise it doesn't get reverted
	//RevertSkin();
	bPendingClose = true;

	super.SceneDeactivated();
}

event NotifyGameSessionEnded()
{
	`Log(name$"::NotifyGameSessionEnded",,'BotBalancer');

	bPendingClose = true;

	// clear references
	OriginalSkin = none;

	super.NotifyGameSessionEnded();
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

	return bResult;
}

//**********************************************************************************
// Init funtions
//**********************************************************************************

// Initializes the menu option templates, and regenerates the option list
function SetupMenuOptions()
{
}

// Setup the data source bindings (but not the values)
function SetupOptionBindings()
{
}

function bool PopulateMenuOption(name PropertyName, out DynamicMenuOption menuopt)
{
	return false;
}

function bool PopulateMenuObject(GeneratedObjectInfo OI)
{
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
	local Object SettingsObj;

	`Log(name$"::OnAccept",,'BotBalancer');

	SettingsObj = new SettingsClass;
	SettingsObj.SetSpecialValue('WebAdmin_Init', "");

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

	//if (bPendingClose)
	//	return;

//	// make sure we're using the right skin
//	Skin = UISkin(DynamicLoadObject(SkinPath,class'UISkin'));
//	if ( Skin != none )
//	{
		//if (OriginalSkin == none)
		//{
		//	OriginalSkin = SceneClient.ActiveSkin;
		//}
//		SceneClient.ChangeActiveSkin(Skin);
//	}
//}

//function RevertSkin()
//{
//	if (bPendingClose)
//		return;

//	if (OriginalSkin != none)
//	{
//		SceneClient.ChangeActiveSkin(OriginalSkin);
//		OriginalSkin = none;
//	}
//}

function FocusList(optional int index = INDEX_NONE)
{
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
		floatvalue = ParseFloat(value);
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

static function float ParseFloat(string value)
{
	if (InStr(value, ",", false) != INDEX_NONE)
	{
		value = Repl(value, ",", "."); 
	}

	return float(value);
}

defaultproperties
{
	Title="Configure BotBalancer"

	SettingsClass=class'BotBalancerMutatorSettings'
	ConfigClass=class'BotBalancerMutator'
}
