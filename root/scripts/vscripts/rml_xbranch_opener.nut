EntityKillList_t <- [];

function PostSpawn()
{
	local hOpener = null;
	while ( hOpener = Entities.FindByClassname( hOpener, "info_target" ) )
	{
		if ( hOpener == self )
			continue;
			
		if ( ( self.GetOrigin() - hOpener.GetOrigin() ).Length() < 8.0 )
			return OpenPath();
	}
}

function OpenPath()
{
	foreach( strEntity in EntityKillList_t )
	{
		local hEnt = null;
		while ( hEnt = Entities.FindByName( hEnt, strEntity ) )
			if ( hEnt.GetMoveParent() == self.GetMoveParent() )
				hEnt.Destroy();
	}
}

EntFireByHandle( self, "RunScriptCode", "PostSpawn()", 0.05, null, null );
EntFireByHandle( self, "Kill", "", 2.0, null, null );