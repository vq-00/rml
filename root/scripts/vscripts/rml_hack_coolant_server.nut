function GetSharedSessionScope()
{
	local hSession = Entities.FindByName( null, "ct_rml_hack_global_state" );
	if ( !hSession )
	{
		hSession = Entities.CreateByClassname( "asw_challenge_thinker" );
		hSession.__KeyValueFromString( "vscripts", "rml_hack_session.nut" );
		hSession.SetName( "ct_rml_hack_global_state" );
		hSession.Spawn();
		hSession.Activate();
		hSession.ValidateScriptScope();
	}
	return hSession.GetScriptScope();
}

function GetGameState( key )
{
	local scope = GetSharedSessionScope();
	if ( !( "Games_t" in scope ) ) scope.Games_t <- {};
	if ( !( key in scope.Games_t ) ) scope.Games_t[key] <- { started = false, complete = false, failed = false };
	return scope.Games_t[key];
}

const INPUT_START   = 1;
const INPUT_SUCCESS = 2;
const SESSION_KEY    = "coolant";

SessionState <- GetGameState( SESSION_KEY );

bStarted  <- SessionState.started;
bComplete <- SessionState.complete;

function SyncSessionState()
{
	SessionState.started = bStarted;
	SessionState.complete = bComplete;
}

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
		if ( !bStarted && !bComplete ) { bStarted = true; SyncSessionState(); SendState(); }
		return;
	}
	if ( n == INPUT_SUCCESS )
	{
		if ( !bComplete ) { bComplete = true; SyncSessionState(); SendState(); }
		return;
	}
}

function Think() { SendState(); return 1.0; }

bStarted  = SessionState.started;
bComplete = SessionState.complete;
SyncSessionState();
SendState();
AddThinkToEnt( self, "Think" );