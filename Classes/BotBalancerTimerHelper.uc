// Parameterized timer (multiple used and split by the called event)

class BotBalancerTimerHelper extends Object;

var PlayerController PC;
var BotBalancerMutator Callback;

var bool bCalled;

event TimedChangedTeam()
{
	bCalled = true;

	if (PC != none && Callback != none)
	{
		Callback.TimerChangedTeam(self, PC);
	}
}

event TimedBecamePlayer()
{
	bCalled = true;

	if (PC != none && Callback != none)
	{
		Callback.TimerBecamePlayer(self, PC);
	}
}

DefaultProperties
{
}
