// =========================================================
//  BINARY PULSE SEQUENCER -- SERVER
//  Client is authoritative. Only tracks complete.
// =========================================================

const INPUT_START   = 1;
const INPUT_SUCCESS = 2;

bStarted  <- false;
bComplete <- false;

function SendState()
{
	local state;
	if ( bComplete )      state = "complete";
	else if ( bStarted )  state = "active";
	else                  state = "standby";
	self.SetString( 0, state + "|||" );
}

function Input( nInput )
{
	local n = nInput.tointeger();
	if ( n == INPUT_START )
	{
		if ( !bStarted && !bComplete ) { bStarted = true; SendState(); }
		return;
	}
	if ( n == INPUT_SUCCESS )
	{
		if ( !bComplete ) { bComplete = true; SendState(); }
		return;
	}
}

function Think() { SendState(); return 1.0; }

bStarted  = false;
bComplete = false;
SendState();
AddThinkToEnt( self, "Think" );