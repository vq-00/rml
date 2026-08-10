const fSpinRate = 360.0;
const fThinkSpeed = 0.016;

function Think()
{
	if ( !self || !self.IsValid() )
		return;

	self.SetAnglesVector( self.GetAngles() + Vector( 0.0, -fSpinRate * fThinkSpeed, 0.0 ) );

	EntFireByHandle( self, "RunScriptCode", "Think()", fThinkSpeed, null, null );
}

Think();