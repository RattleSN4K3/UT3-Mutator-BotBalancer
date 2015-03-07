class BotBalancerEventPawnDeath extends SeqAct_Latent;

delegate OnPawnDeath(Pawn Other, Object Sender);

function AbortFor(Actor latentActor)
{
	local Pawn P;

	P = Pawn(latentActor);
	if (P != none)
	{
		OnPawnDeath(P, self);
	}
}

public function SetPawnDeathEventDelegate(delegate<OnPawnDeath> DeathDelegate)
{
	OnPawnDeath = DeathDelegate;
}

public function Kill()
{
	OnPawnDeath = none;
}

DefaultProperties
{
}
