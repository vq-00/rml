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

const WAVE_COUNT = 4;
const MATCH_TOLERANCE = 0.05;
const MATCH_HOLD_TIME = 0.55;
const INITIAL_FREQUENCY = 0.0;
const TARGET_FREQUENCY_MIN = 0.15;
const TARGET_FREQUENCY_MAX = 0.85;
const TARGET_AMPLITUDE_MIN = 0.15;
const TARGET_AMPLITUDE_MAX = 0.85;
const SESSION_KEY = "waveform";

SessionState <- GetGameState( SESSION_KEY );

WaveFrequency_t <- ( "WaveFrequency_t" in SessionState ) ? clone SessionState.WaveFrequency_t : [ INITIAL_FREQUENCY, INITIAL_FREQUENCY, INITIAL_FREQUENCY, INITIAL_FREQUENCY ];
WaveAmplitude_t <- ( "WaveAmplitude_t" in SessionState ) ? clone SessionState.WaveAmplitude_t : [ 0.50, 0.50, 0.50, 0.50 ];
TargetFrequency_t <- ( "TargetFrequency_t" in SessionState ) ? clone SessionState.TargetFrequency_t : [ 0.50, 0.50, 0.50, 0.50 ];
TargetAmplitude_t <- ( "TargetAmplitude_t" in SessionState ) ? clone SessionState.TargetAmplitude_t : [ 0.50, 0.50, 0.50, 0.50 ];
Locked_t <- ( "Locked_t" in SessionState ) ? clone SessionState.Locked_t : [ false, false, false, false ];
MatchedTime_t <- ( "MatchedTime_t" in SessionState ) ? clone SessionState.MatchedTime_t : [ 0.0, 0.0, 0.0, 0.0 ];
LastUpdateTime <- Time();
bComplete <- ( "complete" in SessionState ) ? SessionState.complete : false;

function EnsureSessionState()
{
	if ( !( "complete" in SessionState ) ) SessionState.complete <- false;
	if ( !( "WaveFrequency_t" in SessionState ) ) SessionState.WaveFrequency_t <- clone WaveFrequency_t;
	if ( !( "WaveAmplitude_t" in SessionState ) ) SessionState.WaveAmplitude_t <- clone WaveAmplitude_t;
	if ( !( "TargetFrequency_t" in SessionState ) ) SessionState.TargetFrequency_t <- clone TargetFrequency_t;
	if ( !( "TargetAmplitude_t" in SessionState ) ) SessionState.TargetAmplitude_t <- clone TargetAmplitude_t;
	if ( !( "Locked_t" in SessionState ) ) SessionState.Locked_t <- clone Locked_t;
	if ( !( "MatchedTime_t" in SessionState ) ) SessionState.MatchedTime_t <- clone MatchedTime_t;
}

function SyncSessionState()
{
	EnsureSessionState();
	SessionState.complete = bComplete;
	SessionState.WaveFrequency_t = clone WaveFrequency_t;
	SessionState.WaveAmplitude_t = clone WaveAmplitude_t;
	SessionState.TargetFrequency_t = clone TargetFrequency_t;
	SessionState.TargetAmplitude_t = clone TargetAmplitude_t;
	SessionState.Locked_t = clone Locked_t;
	SessionState.MatchedTime_t = clone MatchedTime_t;
}

function BuildListString( values )
{
	local result = "";
	for ( local i = 0; i < values.len(); i++ )
	{
		if ( i ) result += ",";
		result += values[i].tostring();
	}
	return result;
}

function SendState()
{
	local targets = [];
	for ( local i = 0; i < WAVE_COUNT; i++ )
	{
		targets.push( TargetFrequency_t[i] );
		targets.push( TargetAmplitude_t[i] );
	}
	local lockMask = 0;
	for ( local i = 0; i < WAVE_COUNT; i++ )
		if ( Locked_t[i] ) lockMask = lockMask | ( 1 << i );
	self.SetString( 0, ( bComplete ? "complete" : "active" ) + "|" + BuildListString( targets ) + "|" + lockMask.tostring() );
}

function UpdateTargets()
{
	local now = Time();
	local delta = now - LastUpdateTime;
	if ( delta < 0.08 )
		return;
	LastUpdateTime = now;

	local allLocked = true;
	for ( local i = 0; i < WAVE_COUNT; i++ )
	{
		if ( Locked_t[i] )
			continue;

		local matched = fabs( WaveFrequency_t[i] - TargetFrequency_t[i] ) <= MATCH_TOLERANCE && fabs( WaveAmplitude_t[i] - TargetAmplitude_t[i] ) <= MATCH_TOLERANCE;
		if ( matched )
			MatchedTime_t[i] += delta;
		else
			MatchedTime_t[i] = 0.0;
		if ( MatchedTime_t[i] >= MATCH_HOLD_TIME )
			Locked_t[i] = true;
		else
			allLocked = false;
	}
	for ( local i = 0; i < WAVE_COUNT; i++ )
		if ( !Locked_t[i] ) allLocked = false;
	if ( allLocked )
		bComplete = true;
	SyncSessionState();
	SendState();
}

function Clamp01( value )
{
	if ( value < 0.0 ) return 0.0;
	if ( value > 1.0 ) return 1.0;
	return value;
}

function InitializeTargets()
{
	for ( local i = 0; i < WAVE_COUNT; i++ )
	{
		TargetFrequency_t[i] = RandomFloat( TARGET_FREQUENCY_MIN, TARGET_FREQUENCY_MAX );
		TargetAmplitude_t[i] = RandomFloat( TARGET_AMPLITUDE_MIN, TARGET_AMPLITUDE_MAX );
	}
	SyncSessionState();
}

function Input( nInput )
{
	if ( bComplete )
		return;
	local wave = ( nInput / 10201 ).tointeger();
	local remainder = nInput % 10201;
	local frequency = ( remainder / 101 ).tointeger();
	local amplitude = remainder % 101;
	if ( wave < 0 || wave >= WAVE_COUNT )
		return;
	if ( Locked_t[wave] )
		return;
	WaveFrequency_t[wave] = Clamp01( frequency / 100.0 );
	WaveAmplitude_t[wave] = Clamp01( amplitude / 100.0 );
	SyncSessionState();
	SendState();
}

function Think()
{
	UpdateTargets();
	return 0.08;
}

InitializeTargets();
SendState();
AddThinkToEnt( self, "Think" );