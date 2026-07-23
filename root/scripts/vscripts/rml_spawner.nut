fDist <- self.GetKeyValue( "NearDistance" ).tofloat();

function SpawnerThink()
{
	local hCloseMarine = Entities.FindByClassnameNearest( "asw_marine", self.GetOrigin(), fDist );
	if ( !hCloseMarine )
		return 0.1;
		
	EntFireByHandle( self, "StartSpawning", "", 0.0, null, null );
	
	return 99999.0;
}

if ( fDist < 9999.0 )
	AddThinkToEnt( self, "SpawnerThink" );

function ActivateHoldout( hCaller )
{
	if ( ( hCaller.GetOrigin() - self.GetOrigin() ).Length() > 1280.0 )
		return;
		
	EntFireByHandle( self, "StartSpawning", "", 0.0, null, null );
}