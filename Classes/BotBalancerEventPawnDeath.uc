class BotBalancerEventPawnDeath extends SeqAct_Latent;

delegate OnPawnDeath(Pawn Other, Object Sender);

function AbortFor(Actor latentActor)
{
	local Pawn P;

	P = (UTBot(latentActor) != none ? UTBot(latentActor).Pawn : Pawn(latentActor));
	OnPawnDeath(P, self);
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
