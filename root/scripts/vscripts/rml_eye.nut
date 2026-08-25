const fThinkSpeed = 0.05;
const fSeeDist = 192.0;
const fDangerTime = 15.0;

hLockedMarine <- null;
fLockedMarineTime <- Time();

hSprite <- Entities.CreateByClassname( "env_sprite" );
hSprite.__KeyValueFromInt( "spawnflags", 1 );
hSprite.__KeyValueFromString( "Model", "materials/Sprites/light_glow03.vmt" );
hSprite.__KeyValueFromString( "rendercolor", "255 255 255 255" );
hSprite.__KeyValueFromFloat( "GlowProxySize", 24.0 );
hSprite.__KeyValueFromInt( "renderamt", 255 );
hSprite.__KeyValueFromInt( "rendermode", 9 );
hSprite.__KeyValueFromFloat( "scale", 0.5 );
hSprite.SetOrigin( self.GetOrigin() + Vector( 6.0, 0.0, 0.0 ) );
hSprite.SetParent( self );
hSprite.Spawn();
hSprite.Activate();

function Think()
{
	if ( !self || !self.IsValid() )
		return;

	local hCloseMarine = Entities.FindByClassnameNearest( "asw_marine", vecSee, fSeeDist );
	if ( !hCloseMarine )
	{
		self.SetOrigin( vecNoSee );
		hLockedMarine <- null;
		fLockedMarineTime <- Time();
		
		return EntFireByHandle( self, "RunScriptCode", "Think()", fThinkSpeed, null, null );
	}
	else
	{
		self.SetOrigin( vecSee );
	}

	if ( !hLockedMarine || !hLockedMarine.IsValid() || ( self.GetOrigin() - hLockedMarine.GetOrigin() ).Length() > fSeeDist )
	{
		hLockedMarine <- hCloseMarine;
		fLockedMarineTime <- Time();
	}
	
	self.SetAngles( 0.0, GetYawFromVector( self.GetOrigin() - hLockedMarine.GetOrigin() ) + 180.0, 0.0 );
	local nRenderAmt = 30 + ( ( Time() - fLockedMarineTime ) / fDangerTime * 200.0 ).tointeger();
	
	if ( Time() - fLockedMarineTime > fDangerTime - 1.0 )
		hSprite.__KeyValueFromString( "rendercolor", "255 " + ( 255 - ( 255.0 * ( Time() - fLockedMarineTime - fDangerTime - 1.0 ) ).tointeger() ).tostring() + " " + ( 255 - ( 255.0 * ( Time() - fLockedMarineTime - fDangerTime - 1.0 ) ).tointeger() ).tostring() + " " + nRenderAmt.tostring() );
	else
		hSprite.__KeyValueFromString( "rendercolor", "255 255 255 " + nRenderAmt.tostring() );

	if ( Time() - fLockedMarineTime > fDangerTime )
	{
		local hBarrel = Entities.CreateByClassname( "asw_barrel_explosive" );
		hBarrel.SetOrigin( hLockedMarine.GetOrigin() + Vector( 0.0, 0.0, 2000.0 ) );
		hBarrel.Spawn();
		hBarrel.Activate();
		hBarrel.SetVelocity( Vector( 0.0, 0.0, -1000.0 ) );
		EntFireByHandle( hBarrel, "RunScriptCode", "self.TakeDamage( 100, 0, null );", 1.75, null, null );
		
		self.Destroy();
		
		return;
	}

	EntFireByHandle( self, "RunScriptCode", "Think()", fThinkSpeed, null, null );
}

function NormalizeVector( vec )
{
    local vecOutput = Vector( 0.0, 0.0, 0.0 );
	local mod = 0.0;

	foreach( dir in vec )
        mod += dir * dir;

    local mag = pow( mod, 0.5 );

    if ( mag == 0.0 )
		return vecOutput;

	vecOutput.x = vec.x / mag;
	vecOutput.y = vec.y / mag;
	vecOutput.z = vec.z / mag;

    return vecOutput;
}

function GetYawFromVector( vec )
{
	local nSign = vec.y < 0.0 ? -1 : 1;

	vec = NormalizeVector( vec );

	return 57.2958 * acos( vec.x ) * nSign;
}

EntFireByHandle( self, "RunScriptCode", "self.ClearParent()", 0.9, null, null );
EntFireByHandle( self, "RunScriptCode", "vecSee <- self.GetOrigin()", 0.9, null, null );
EntFireByHandle( self, "RunScriptCode", "vecNoSee <- vecSee + Vector( 0.0, 0.0, 4000.0 )", 0.9, null, null );
EntFireByHandle( self, "RunScriptCode", "Think();", 1.0, null, null );