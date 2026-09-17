const WAVE_COUNT = 4;
const MATCH_TOLERANCE = 0.05;
const MATCH_HOLD_TIME = 0.55;
const INITIAL_FREQUENCY = 0.0;
const TARGET_FREQUENCY_MIN = 0.15;
const TARGET_FREQUENCY_MAX = 0.85;
const TARGET_AMPLITUDE_MIN = 0.15;
const TARGET_AMPLITUDE_MAX = 0.85;

WaveFrequency_t <- [ INITIAL_FREQUENCY, INITIAL_FREQUENCY, INITIAL_FREQUENCY, INITIAL_FREQUENCY ];
WaveAmplitude_t <- [ 0.50, 0.50, 0.50, 0.50 ];
TargetFrequency_t <- [ 0.50, 0.50, 0.50, 0.50 ];
TargetAmplitude_t <- [ 0.50, 0.50, 0.50, 0.50 ];
Locked_t <- [ false, false, false, false ];
MatchedTime_t <- [ 0.0, 0.0, 0.0, 0.0 ];
LastUpdateTime <- Time();
bComplete <- false;

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