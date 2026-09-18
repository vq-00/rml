SessionState_t <- {};

function GetSessionScope()
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
	local scope = GetSessionScope();
	if ( !( "Games_t" in scope ) )
		scope.Games_t <- {};
	if ( !( key in scope.Games_t ) )
		scope.Games_t[key] <- { started = false, complete = false, failed = false };
	return scope.Games_t[key];
}
