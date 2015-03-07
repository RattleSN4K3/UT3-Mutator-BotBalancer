class BotBalancerHelperPawnDeath extends Info;

var transient BotBalancerEventPawnDeath EventDeathHandler;

event Destroyed()
{
	if (EventDeathHandler != none)
	{
		EventDeathHandler.Kill();
		EventDeathHandler = none;
	}

	super.Destroyed();
}

event BaseChange()
{
	local Pawn P;
	local BotBalancerEventPawnDeath evnt;
	super.BaseChange();

	P = Pawn(Base);
	if (P != none)
	{
		evnt = new(Outer) class'BotBalancerEventPawnDeath';
		evnt.SetPawnDeathEventDelegate(OnEventPawnDeath);
		P.LatentActions.AddItem(evnt);

		EventDeathHandler = evnt;
	}
}

/* PawnBaseDied()
The pawn on which this actor is based has just died
*/
function PawnBaseDied()
{
	local Pawn P;

	`Log(name$"::PawnBaseDied",,'BotBalancer');

	P = Pawn(Base);
	OnPawnDiedPost(P, self);
	if (P != none)
	{
		P.LatentActions.RemoveItem(EventDeathHandler);
	}

	Destroy();
}

delegate OnPawnDiedPre(Pawn Other, Object Sender);
delegate OnPawnDiedPost(Pawn Other, Actor Sender);

function SetPlayerDeathDelegate(delegate<OnPawnDiedPre> PreDeathDelegate, delegate<OnPawnDiedPost> PostDeathDelegate)
{
	OnPawnDiedPre = PreDeathDelegate;
	OnPawnDiedPost = PostDeathDelegate;
}

function OnEventPawnDeath(Pawn Other, Object Sender)
{
	OnPawnDiedPre(Pawn(Base), Sender);
}

DefaultProperties
{
}
