// =========================================================
//  SECURITY HANDSHAKE -- SERVER
//  The client is authoritative for the game loop. This script
//  only tracks complete/failed so the parent objective can act.
// =========================================================

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
const INPUT_FAILURE = 3;
const SESSION_KEY    = "handshake";

SessionState <- GetGameState( SESSION_KEY );

bStarted  <- SessionState.started;
bComplete <- SessionState.complete;
bFailed   <- SessionState.failed;

function SyncSessionState()
{
	SessionState.started = bStarted;
	SessionState.complete = bComplete;
	SessionState.failed = bFailed;
}

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
			SyncSessionState();
			SendState();
		}
		return;
	}
	if ( n == INPUT_SUCCESS )
	{
		if ( !bComplete && !bFailed )
		{
			bComplete = true;
			SyncSessionState();
			SendState();
		}
		return;
	}
	if ( n == INPUT_FAILURE )
	{
		if ( !bComplete && !bFailed )
		{
			bFailed = true;
			SyncSessionState();
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
bStarted  = SessionState.started;
bComplete = SessionState.complete;
bFailed   = SessionState.failed;
SyncSessionState();
SendState();
AddThinkToEnt( self, "Think" );