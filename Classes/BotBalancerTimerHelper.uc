// Parameterized timer (multiple used and split by the called event)

class BotBalancerTimerHelper extends Object;

var PlayerController PC;
var BotBalancerMutator Callback;

event TimedChangedTeam()
{
	if (PC != none && Callback != none)
	{
		Callback.TimerChangedTeam(PC);
	}
}

event TimedBecamePlayer()
{
	if (PC != none && Callback != none)
	{
		Callback.TimerBecamePlayer(PC);
	}
}

DefaultProperties
{
}
