// Class created with the Owner as a UIDynamicFieldProvider wich gets access to protected members

class BotBalancerPersistentConfigHelper extends Object
	within UIDynamicFieldProvider;

function RemoveFieldCustom(name FieldName)
{
	local int i;

	i = FindFieldIndex(FieldName, true);
	if (i != INDEX_NONE)
	{
		PersistentDataFields.Remove(i, 1);
	}
}
