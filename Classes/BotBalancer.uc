`define NO_CONSOLE 1

`if( `notdefined(FINAL_RELEASE) )

`if( `isdefined(NO_CONSOLE) )
class BotBalancer extends Object;
`endif // ELSE `notdefined(NO_CONSOLE)
`if( `notdefined(NO_CONSOLE) )
class BotBalancer extends Interaction;

// INGAME LOG
//
// Controls Keyboard:
// Shift + Space	        = Toggle opacity
// Shift + BackSpace	    = Toggle visibility
// Shift + MouseScroll	    = Scroll up and down
// Shift + PageUp			= Scroll up (1 line)
// Shift + PageDown	        = Scroll down (1 line)
// Shift + Ctrl + PageUp	= Scroll up (5 lines)
// Shift + Ctrl + PageDown	= Scroll down (5 lines)
// Shift + Home	            = Go to the beginning
// Shift + End	            = Go to the latest log

// Controls PS3:
// Select + X               = Toggle opacity
// Select + /\              = Toggle visibility
// Select + LeftStick       = Scroll up and down (1x)
// Select + L3 + LeftStick  = Scroll up (5x)
// Select + L3 + LeftStick  = Scroll down (5x)
// Select + DPad-Up         = Go to the beginning
// Select + DPad-Down       = Go to the latest log

// Struct for storing extra data within a map entry (implemented like this to maximize flexibility)
struct LogStruct
{
	var name Key;
	var string Value;
	var bool bWarn;
};

var private editconst BotBalancer Logger;

var LocalPlayer LP;
var Console ViewportConsole;

/** Holds the scrollback buffer */
var array<LogStruct> Scrollback;

/**  Where in the scrollback buffer are we */
var float SBHead, SBPos;

/** True while a control key is pressed. */
var bool bMode;

/** True while CTRL key is pressed. */
var bool bCtrl;

var bool bHidden;
var bool bFullVisible;

/**
 * Called when the current map is being unloaded.  Cleans up any references which would prevent garbage collection.
 */
function NotifyGameSessionEnded()
{
	local BotBalancer templogger;

	if (GetDefault(templogger))
	{
		templogger.Logger = none;
	}
	if (LP != none)
	{
		LP.ViewportClient.GlobalInteractions.RemoveItem(self);
		LP = none;
	}

	ViewportConsole = none;
}

static function bool CreateLogger()
{
	local WorldInfo WI;
	local PlayerController PC;
	local BotBalancer templogger;

	if (!GetDefault(templogger))
		return false;

	WI = class'Engine'.static.GetCurrentWorldInfo();
	if (WI != none)
	{
		foreach WI.AllControllers(class'PlayerController', PC)
		{
			if (LocalPlayer(PC.Player) != none)
			{
				InitLoggerFor(templogger, PC, LocalPlayer(PC.Player));
				break;
			}
		}

		return templogger.Logger != none;
	}

	return false;
}

static function InitLoggerFor(BotBalancer DefaultLogger, PlayerController InPC, Localplayer InLP)
{
	DefaultLogger.Logger = new default.Class;

	// add to global for GC and to PC for drawing
	if (HasInteraction(InPC.Interactions))
		return;

	InPC.Interactions.InsertItem(0, DefaultLogger.Logger);
	if (!HasInteraction(InLP.ViewportClient.GlobalInteractions))
	{
		InLP.ViewportClient.InsertInteraction(DefaultLogger.Logger, 0);
	}

	DefaultLogger.Logger.Scrollback = DefaultLogger.Scrollback;
	DefaultLogger.Logger.SBHead = DefaultLogger.Scrollback.Length-1;
	DefaultLogger.Logger.ViewportConsole = InLP.ViewportClient.ViewportConsole;
	DefaultLogger.Logger.LP = InLP;
}

static function StaticAddMessage(string msg, optional name tag, optional bool bWarn)
{
	local BotBalancer templogger;
	if (!GetDefault(templogger))
		return;

	templogger.AddMessage(msg, tag);
}

function AddMessage(string msg, optional name tag, optional bool bWarn)
{
	local int index;
	index = Scrollback.Length;
	Scrollback.Add(1);
	Scrollback[index].Key = tag;
	Scrollback[index].Value = msg;
	if (bWarn) Scrollback[index].bWarn = true;
	SBHead += 1;
}

/**
 * Called once a frame to allow the interaction to draw to the canvas
 * @param Canvas Canvas object to draw to
 */
event PostRender(Canvas Canvas)
{
	local float Height;
	local float xl,yl,y, tempY;
	local string OutStr;
	local int idx;

	// render the buffer

	if (bHidden)
		return;

	// Blank out a space
	if ( ViewportConsole == none || !ViewportConsole.IsUIConsoleOpen() )
	{
		Canvas.Font	 = class'Engine'.Static.GetSmallFont();

		// the height of the buffer will be 75% of the height of the screen
		Height = Canvas.ClipY*0.75;

		// change the draw color to white
	    Canvas.SetDrawColor(255,255,255,bFullVisible ? 255: 66);

	    // move the pen to the top-left pixel
		Canvas.SetPos(0,0);

		// draw the black background tile
		Canvas.DrawTile( class'Console'.default.DefaultTexture_Black, Canvas.ClipX, Height,0,0,32,32);

		OutStr = "O";

		// determine the height of the text
		Canvas.Strlen(OutStr,xl,yl);

		// figure out which element of the scrollback buffer to should appear first (at the top of the screen)
		idx = SBHead - int(SBPos);
		y = Height-16-(yl*2);

		// change the draw color to green
		Canvas.SetDrawColor(0,255,0,bFullVisible ? 255 : 100);

		// move the pen to the bottom of the console buffer area
		Canvas.SetPos(0,Height);

		// draw the bottom status region border
		Canvas.DrawTile( class'Console'.default.DefaultTexture_White, Canvas.ClipX, 2,0,0,32,32);

		// center the pen between the two borders
		Canvas.SetPos(0,Height-5-yl);
		Canvas.bCenter = False;

		// render the text
		OutStr = "Log entries: "@Scrollback.Length@" Viewing:"@(idx-int(y/yl)+1)$"-"$idx+1;
		Canvas.DrawText( OutStr, false );

		if (ScrollBack.Length==0)
			return;

		// while we have enough room to draw another line and there are more lines to draw
		while (y>-yl && idx>=0)
		{
			if (Scrollback[idx].bWarn)
			{
				// change the draw color to yellow
				Canvas.SetDrawColor(255,255,0, bFullVisible ? 255 : 100);
			}
			else
			{
				// change the draw color to white
				Canvas.SetDrawColor(255,255,255, bFullVisible ? 255 : 100);
			}

			// move the pen to the correct position
			Canvas.StrLen(Scrollback[idx].Value, xl, tempY);
			Canvas.SetPos(0, y-(FMax(yl, tempY)-yl));

			// draw the next line down in the buffer
			Canvas.DrawText(Scrollback[idx].Value, false);
			idx--;
			y-=FMax(yl, tempY);
		}
	}
}

/**
 * @return	return TRUE to indicate that the input event was handled.  if the return value is TRUE, the input event will not
 *			be processed by this Interaction's native code.
 */
event bool OnInputKey( int ControllerId, name Key, EInputEvent Event, optional float AmountDepressed=1.f, optional bool bGamepad )
{
	if (!ProcessControlKey(Key, Event) && bMode && (Event == IE_Pressed || Event == IE_Repeat))
	{
		if ( Key=='SpaceBar' || Key=='XboxTypeS_A' )
		{
			bFullVisible = !bFullVisible;
			return true;
		}
		else if ( Key=='BackSpace' || Key=='XboxTypeS_Y' )
		{
			bHidden = !bHidden;
			return true;
		}

		else if ( Key=='home' || Key=='XBoxTypeS_DPad_Up' || Key=='GamePad_LeftStick_Up')
		{
			SBPos = ScrollBack.Length-1;
			return true;
		}
		else if (Key=='end' || Key=='XBoxTypeS_DPad_Down' || Key=='GamePad_LeftStick_Down')
		{
			SBPos = 0;
			return true;
		}

		else if ( Key=='pageup' || Key=='mousescrollup')
		{
			if (SBPos<ScrollBack.Length-1)
			{
				if (bCtrl)
					SBPos+=5;
				else
					SBPos+=1;

				if (SBPos>=ScrollBack.Length)
				  SBPos = ScrollBack.Length-1;
			}

			return true;
		}
		else if ( Key=='pagedown' || Key=='mousescrolldown')
		{
			if (SBPos>0)
			{
				if (bCtrl)
					SBPos-=5;
				else
					SBPos-=1;

				if (SBPos<0)
					SBPos = 0;
			}

			return true;
		}
	}

	return false;
}

/**
 * @return	return TRUE to indicate that the input event was handled.  if the return value is TRUE, the input event will not
 *			be processed by this Interaction's native code.
 */
event bool OnInputAxis( int ControllerId, name Key, float Delta, float DeltaTime, optional bool bGamepad )
{
	if (ControllerId == LP.ControllerId && bMode)
	{
		if ( Key=='XboxTypeS_LeftY')
		{
			if (Delta > 0)
			{
				if (SBPos>0)
				{
					if (bCtrl)
						SBPos-=5*Abs(Delta);
					else
						SBPos-= Abs(Delta);

					if (SBPos<0)
						SBPos = 0;
				}
			}
			else
			{
				if (SBPos<ScrollBack.Length-1)
				{
					if (bCtrl)
						SBPos+=5*Abs(Delta);
					else
						SBPos+=Abs(Delta);

					if (SBPos>=ScrollBack.Length)
					  SBPos = ScrollBack.Length-1;
				}
			}

			return true;
		}
	}

	return false;
}

/** looks for Control key presses and the copy/paste combination that apply to both the console bar and the full open console */
function bool ProcessControlKey(name Key, EInputEvent Event)
{
	if (Key == 'LeftShift' || Key == 'RightShift' || Key == 'XboxTypeS_Back')
	{
		if (Event == IE_Released)
		{
			bMode = false;
		}
		else if (Event == IE_Pressed)
		{
			bMode = true;
		}

		return true;
	}
	else if (Key == 'LeftControl' || Key == 'RightControl' || Key == 'XboxTypeS_LeftThumbstick')
	{
		if (Event == IE_Released)
		{
			bCtrl = false;
		}
		else if (Event == IE_Pressed)
		{
			bCtrl = true;
		}

		return true;
	}

	return false;
}

private static final function bool GetDefault(out BotBalancer OutLogger)
{
	OutLogger = BotBalancer(FindObject(default.Class.GetPackageName()$".Default__"$string(default.Class), default.Class));
	return OutLogger != none;
}

private static final function bool HasInteraction(array<Interaction> Interactions)
{
	local int i;
	for (i=0; i<Interactions.Length; i++)
	{
		if (Interactions[i].IsA(default.Class.name))
		{
			return true;
		}
	}

	return false;
}

`endif // END `isdefined(NO_CONSOLE)
static function LogHud(string msg, optional name tag)
{
	LogInternal(msg, tag);

`if( `notdefined(NO_CONSOLE) )
	if (class'BotBalancer'.default.Logger == none && !class'BotBalancer'.static.CreateLogger())
	{
		class'BotBalancer'.static.StaticAddMessage(msg, tag);
	}
	else
	{
		class'BotBalancer'.default.Logger.AddMessage(msg, tag);
	}
`endif // END `notdefined(NO_CONSOLE)
}

static function WarnHud(string msg, optional name tag)
{
	WarnInternal(msg);

`if( `notdefined(NO_CONSOLE) )
	if (class'BotBalancer'.default.Logger == none && !class'BotBalancer'.static.CreateLogger())
	{
		class'BotBalancer'.static.StaticAddMessage(msg, tag, true);
	}
	else
	{
		class'BotBalancer'.default.Logger.AddMessage(msg, tag, true);
	}
`endif // END `notdefined(NO_CONSOLE)
}

`else // ELSE isdefined(FINAL_RELEASE) )
class BotBalancer extends Object;
`endif // END `notdefined(FINAL_RELEASE)

Defaultproperties
{
`if( `notdefined(FINAL_RELEASE) )
`if( `notdefined(NO_CONSOLE) )
	OnReceivedNativeInputKey=OnInputKey
	OnReceivedNativeInputAxis=OnInputAxis
`endif
`endif
}