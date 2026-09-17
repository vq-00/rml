// =========================================================
//  SECURITY HANDSHAKE -- SERVER
//  The client is authoritative for the game loop. This script
//  only tracks complete/failed so the parent objective can act.
// =========================================================

const INPUT_START   = 1;
const INPUT_SUCCESS = 2;
const INPUT_FAILURE = 3;

bStarted  <- false;
bComplete <- false;
bFailed   <- false;

function SendState()
{
	local state;
	if ( bComplete )      state = "complete";
	else if ( bFailed )   state = "failed";
	else if ( bStarted )  state = "active";
	else                  state = "standby";

	self.SetString( 0, state + "|||" );
}

function Input( nInput )
{
	local n = nInput.tointeger();

	if ( n == INPUT_START )
	{
		if ( !bStarted && !bComplete && !bFailed )
		{
			bStarted = true;
			SendState();
		}
		return;
	}
	if ( n == INPUT_SUCCESS )
	{
		if ( !bComplete && !bFailed )
		{
			bComplete = true;
			SendState();
		}
		return;
	}
	if ( n == INPUT_FAILURE )
	{
		if ( !bComplete && !bFailed )
		{
			bFailed = true;
			SendState();
		}
		return;
	}
}

function Think()
{
	SendState();
	return 1.0;
}

// ----- Init -----
bStarted  = false;
bComplete = false;
bFailed   = false;
SendState();
AddThinkToEnt( self, "Think" );