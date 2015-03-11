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

DefaultProperties
{
}
