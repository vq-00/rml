ScriptScopePostSpawn_t <- clone self.GetScriptScope();

IncludeScript( "rml_generator.nut" );

const TILE_SIZE = 1280;
const MAP_MAX_SIZE_X = 10;
const MAP_MAX_SIZE_Y = 10;

function GetTileWorldCoordinates( x, y )
{
	return Vector( 	
			( TILE_SIZE * MAP_MAX_SIZE_X ) / -2.0 + ( TILE_SIZE * x + TILE_SIZE / 2.0 ), 
			( TILE_SIZE * MAP_MAX_SIZE_Y ) / 2.0 - ( TILE_SIZE * y + TILE_SIZE / 2.0 ),
			-32.0 
				);
}

function GetTileFromWorldCoordinates( vecPos )
{
	return [ 
				( ( vecPos.x + ( TILE_SIZE * MAP_MAX_SIZE_X / 2.0 ) ) / TILE_SIZE ).tointeger(),
				MAP_MAX_SIZE_Y - 1 - ( ( vecPos.y + ( TILE_SIZE * MAP_MAX_SIZE_Y / 2.0 ) ) / TILE_SIZE ).tointeger()
					];
}

function PlaceTileInPlace( x, y, fRotate, strTile )
{
	// get new tile handle
	local bFound = false;
	local hNewTile = null;
	while ( hNewTile = Entities.FindByName( hNewTile, "tile_" + strTile ) )
	{
		// find one which just spawned and hasnt been placed yet
		if ( hNewTile.GetOrigin().z < -1000.0 )
		{	
			hNewTile.ValidateScriptScope();
			hNewTile.GetScriptScope().bHasScenery <- true;
			hNewTile.GetScriptScope().Scenery_t <- [];
			hNewTile.GetScriptScope().SceneryData_t <- [];
			hNewTile.GetScriptScope().RMLThink <- function()
			{
				if ( !self || !( self.IsValid() ) )
					return 9999.0;
					
				local hMarine = null;
				local fDist = 9999.0;
				while ( hMarine = Entities.FindByClassname( hMarine, "asw_marine" ) )
					if ( ( self.GetOrigin() - hMarine.GetOrigin() ).Length() < fDist )
						fDist = ( self.GetOrigin() - hMarine.GetOrigin() ).Length();
						
				if ( bHasScenery && fDist > 1280.0 * 2.0 )
				{
					foreach( hScenery in Scenery_t )
						EntFireByHandle( hScenery, "Kill", "", 0.0, null, null );
						
					Scenery_t <- [];
					
					bHasScenery <- false;
					return 1.0;
				}
				
				if ( !bHasScenery && fDist < 1280.0 * 2.0 )
				{
					foreach( Data_t in SceneryData_t )
					{
						local hScenery = Entities.CreateByClassname( "prop_dynamic" );
						hScenery.SetModel( Data_t[0] );
						hScenery.SetName( Data_t[1] );
						hScenery.SetOrigin( self.GetOrigin() - Data_t[2] );
						hScenery.SetAnglesVector( Data_t[3] );
						hScenery.__KeyValueFromString( "rendercolor", Data_t[4] );
						NetProps.SetPropInt( hScenery, "m_nSkin", Data_t[5] );
						hScenery.__KeyValueFromString( "modelscale", Data_t[6] );
						hScenery.Spawn();
						
						if ( !hScenery || !( hScenery.IsValid() ) )
						{
							ClientPrint( null, 3, "failed to spawn scenery prop " + Data_t[0] );
							continue;
						}
						
						hScenery.Activate();
						
						hScenery.SetParent( self );
						
						Scenery_t.push( hScenery );
					}
					
					bHasScenery <- true;
					return 1.0;
				}
				
				return 1.0;
			}
			
			bFound = true;
			break;
		}
	}
	
	if ( !bFound )
	{
		if ( strTile != "empty" )
			ClientPrint( null, 3, "uh oh didnt find " + strTile );
	
		return;
	}

	local PropScenery_t = [];
	local hScenery = null;
	while ( hScenery = Entities.FindByName( hScenery, "scenery_tile_" + strTile ) )
	{
		if ( hScenery.GetOrigin().z > -1000.0 )
			continue;
			
		hScenery.SetParent( hNewTile );
		
		if ( hScenery.GetClassname() == "prop_dynamic" )
			PropScenery_t.push( hScenery );
		
		// disable props/brushes that could block node links from generating
		if ( !( NetProps.GetPropInt( hScenery, "m_Collision.m_usSolidFlags" ) & 4 ) )
		{
			EntFireByHandle( hScenery, "Disable", "", 0.0, null, null );
			EntFireByHandle( hScenery, "DisableCollision", "", 0.0, null, null );
			EntFireByHandle( hScenery, "Enable", "", 0.5, null, null );
			EntFireByHandle( hScenery, "EnableCollision", "", 0.5, null, null );
		}
		
		// spawners are cool kids gangsters mafia members who dont want to have parents
		if ( hScenery.GetClassname() != "asw_spawner" )
			continue;
		
		hScenery.ValidateScriptScope();
		hScenery.GetScriptScope().hParent <- hNewTile;
		
		local hSpawnerPos = Entities.CreateByClassname( "info_target" );
		hSpawnerPos.SetOrigin( hScenery.GetOrigin() );
		hSpawnerPos.SetAnglesVector( hScenery.GetAngles() );
		hSpawnerPos.SetParent( hNewTile );
		hSpawnerPos.Spawn();
		hSpawnerPos.Activate();
		hSpawnerPos.ValidateScriptScope();
		hSpawnerPos.GetScriptScope().hSpawner <- hScenery;
	}	
	
	local hClip = null;
	while ( hClip = Entities.FindByName( hClip, "clip_tile_" + strTile ) )
		if ( hClip.GetOrigin().z < -1000.0 )
			hClip.SetParent( hNewTile );

	local vecOrigin = GetTileWorldCoordinates( x, y );
	
	hNewTile.SetOrigin( vecOrigin );
	hNewTile.SetAngles( 0.0, fRotate, 0.0 );
	
	local hSpawnerHelper = null;
	while ( hSpawnerHelper = Entities.FindByClassname( hSpawnerHelper, "info_target" ) )
	{
		hSpawnerHelper.ValidateScriptScope();
		if ( !( "hSpawner" in hSpawnerHelper.GetScriptScope() ) )
			continue;
			
		local hSpawner = hSpawnerHelper.GetScriptScope().hSpawner;
		hSpawner.SetOrigin( hSpawnerHelper.GetOrigin() );
		hSpawner.SetAnglesVector( hSpawnerHelper.GetAngles() );
		hSpawnerHelper.Destroy();
	}
	
	foreach( hProp in PropScenery_t )
	{
		hNewTile.GetScriptScope().Scenery_t.push( hProp );
		hNewTile.GetScriptScope().SceneryData_t.push( [ hProp.GetModelName(), hProp.GetName(), hNewTile.GetOrigin() - hProp.GetOrigin(), hProp.GetAngles(), hProp.GetKeyValue( "rendercolor" ), NetProps.GetPropInt( hProp, "m_nSkin" ), hProp.GetKeyValue( "modelscale" ) ] );
	}
	
	//AddThinkToEnt( hNewTile, "RMLThink" );
}

function GetPreviousTile( Layout_t, x, y, cIgnore = ' ' )
{
	local nSizeY = Layout_t.len();
	local nSizeX = Layout_t[0].len();
	
	if ( cIgnore != '>' && x != 0 && ( Layout_t[y][x-1] == '>' || Layout_t[y][x-1] == 'R' || ( Layout_t[y][x-1] == 'T' && ( MapInfo_t[0][y][x-1] == '>' || MapInfo_t[1][y][x-1] == 'R' ) ) ) )
		return '>';
	
	if ( cIgnore != '<' && ( x != nSizeX - 1 ) && ( Layout_t[y][x+1] == '<' || Layout_t[y][x+1] == 'L' || ( Layout_t[y][x+1] == 'T' && ( MapInfo_t[0][y][x+1] == '<' || MapInfo_t[1][y][x+1] == 'L' ) ) ) )
		return '<';
		
	if ( cIgnore != 'v' && y != 0 && ( Layout_t[y-1][x] == 'v' || Layout_t[y-1][x] == 'D' || ( Layout_t[y-1][x] == 'T' && ( MapInfo_t[0][y-1][x] == 'v' || MapInfo_t[1][y-1][x] == 'D' ) ) ) )
		return 'v';
		
	if ( cIgnore != '^' && ( y != nSizeY - 1 ) && ( Layout_t[y+1][x] == '^' || Layout_t[y+1][x] == 'U' || ( Layout_t[y+1][x] == 'T' && ( MapInfo_t[0][y+1][x] == '^' || MapInfo_t[1][y+1][x] == 'U' ) ) ) )
		return '^';
		
	return ' ';
}

function GetDirectionSymbol( cSymbol )
{
	if ( cSymbol == 'U' )
		return '^';
	
	if ( cSymbol == 'D' )
		return 'v';
		
	if ( cSymbol == 'L' )
		return '<';
		
	if ( cSymbol == 'R' )
		return '>';
		
	return cSymbol;
}

function GetTileRotation( x, y, cCurTile, cPrevTile )
{
// empty and bgdeco tiles
	if ( cCurTile == ' ' )
		return RandomHQUniformFloatDistribution( 0.0, 360.0 );

// straight tiles
	if ( cCurTile == cPrevTile && ( cCurTile == 'v' || cCurTile == '^' ) )
		return 0.0;
		
	if ( cCurTile == cPrevTile && ( cCurTile == '>' || cCurTile == '<' ) )
		return 90.0;
		
// end and branchend tiles
	if ( cCurTile == 'E' || cCurTile == 'e' )
	{
		if ( cPrevTile == '^' )
			return 0.0;
			
		if ( cPrevTile == 'v' )
			return 180.0;
			
		if ( cPrevTile == '<' )
			return 90.0;
			
		if ( cPrevTile == '>' )
			return 270.0;
	}
	
// start tile
	if ( cCurTile == 'U' )
		return 180.0;
		
	if ( cCurTile == 'D' )
		return 0.0;
		
	if ( cCurTile == 'L' )
		return 270.0;
		
	if ( cCurTile == 'R' )
		return 90.0;
	
// branch tiles, figure out rotation by which side it is blocking
	if ( cCurTile == 'T' )
	{
		local Directions_t = {};
		Directions_t['^'] <- true;
		Directions_t['v'] <- true;
		Directions_t['<'] <- true;
		Directions_t['>'] <- true;
		
		cPrevTile = GetDirectionSymbol( cPrevTile );
		local cOpening = ' ';
		if ( cPrevTile == 'v' )
			cOpening = '^';
		if ( cPrevTile == '^' )
			cOpening = 'v';
		if ( cPrevTile == '<' )
			cOpening = '>';
		if ( cPrevTile == '>' )
			cOpening = '<';
		
		MapInfo_t <- getroottable()[ "MapInfo_t" ];
		
		local cDirBase = GetDirectionSymbol( MapInfo_t[0][y][x] );
		local cDirBranch = GetDirectionSymbol( MapInfo_t[1][y][x] );
		
		Directions_t.rawdelete( cDirBase );
		Directions_t.rawdelete( cDirBranch );
		Directions_t.rawdelete( cOpening );
		
		cPrevTile = GetPreviousTile( MapInfo_t[2], x, y, cPrevTile );
		cOpening = ' ';
		if ( cPrevTile == 'v' )
			cOpening = '^';
		if ( cPrevTile == '^' )
			cOpening = 'v';
		if ( cPrevTile == '<' )
			cOpening = '>';
		if ( cPrevTile == '>' )
			cOpening = '<';
		
		// some pussy bitchs alive branches can have multiple prev tiles
		Directions_t.rawdelete( cOpening );
		
		foreach ( cDir, _ in Directions_t )
		{
			if ( cDir == '>' )
				return 0.0;
				
			if ( cDir == 'v' )
				return 270.0;
				
			if ( cDir == '<' )
				return 180.0;
				
			if ( cDir == '^' )
				return 90.0;
		}
	}
	
// turn tiles
	// current pointing to, previous pointing to
	// down, right = 0.0
	// left, up = 0.0
	if ( ( cCurTile == 'v' && cPrevTile == '>' ) || ( cCurTile == '<' && cPrevTile == '^' ) )
		return 0.0;
	// up, right = 270.0
	// left, down = 270.0
	if ( ( cCurTile == '^' && cPrevTile == '>' ) || ( cCurTile == '<' && cPrevTile == 'v' ) )
		return 270.0;
	// right, down = 180.0
	// up, left = 180.0
	if ( ( cCurTile == '>' && cPrevTile == 'v' ) || ( cCurTile == '^' && cPrevTile == '<' ) )
		return 180.0;
	// down, left = 90.0
	// right, up = 90.0
	if ( ( cCurTile == 'v' && cPrevTile == '<' ) || ( cCurTile == '>' && cPrevTile == '^' ) )
		return 90.0;
	
	// make it obvious to see if something went wrong
	return 45.0;
}

function FindTileType( Layout_t, x, y )
{
	local nSizeY = Layout_t.len();
	local nSizeX = Layout_t[0].len();
	
	local cCurTile = Layout_t[y][x];
	local cPrevTile = GetPreviousTile( Layout_t, x, y );
	
	if ( cCurTile == ' ' )
	{
		// find whether this tile neighbours a playable tile, make it a bgdeco
		if ( ( y < nSizeY - 1 && Layout_t[y + 1][x] != ' ' ) ||
			 ( y > 0 && Layout_t[y - 1][x] != ' ' ) || 
			 ( x < nSizeX - 1 && Layout_t[y][x + 1] != ' ' ) || 
			 ( x > 0 && Layout_t[y][x - 1] != ' ' )
			)
			return "bgdeco";
		
		return "empty";
	}
	
	if ( cCurTile == 'E' )
		return "end";
		
	if ( cCurTile == 'e' )
		return "branchend";
		
	if ( cCurTile == 'T' )
		return "branchstart";
		
	if ( cPrevTile == ' ' )
		return "start";
		
	if ( cCurTile == cPrevTile )
		return "straight";
		
	return "turn";
}

TileVariants_t <- {};
function GetTileVariants( strTile, bRecompute = true )
{
	strTile = "template_tile_" + strTile;
	if ( !bRecompute && strTile in TileVariants_t )
		return TileVariants_t[ strTile ];
	
	TileVariants_t[ strTile ] <- [];
	
	local hTemplate = null;
	while ( hTemplate = Entities.FindByClassname( hTemplate, "point_template" ) )
	{
		if ( NetProps.GetPropInt( hTemplate, "m_iEFlags" ) & 1 )
			continue;
		
		local strName = hTemplate.GetName();
		if ( strName.len() < strTile.len() || strTile != strName.slice( 0, strTile.len() ) )
			continue;
			
		local nSpawnWeight = hTemplate.GetHealth();
		if ( !nSpawnWeight )
			nSpawnWeight = 100;
			
		if ( nSpawnWeight > 0 )
			TileVariants_t[ strTile ].push( [ strName.slice( strTile.len() ), nSpawnWeight ] );
	}
	
	return TileVariants_t[ strTile ];
}

function PickRandomTileVariant( Variants_t )
{
	if ( !Variants_t.len() )
		return "";
		
	if ( Variants_t.len() == 1 )
		return Variants_t[0][0];
	
	local nTotalWeight = 0;
	for ( local i = 0; i < Variants_t.len(); i++ )
		nTotalWeight += Variants_t[i][1];
		
	local nRand = RandomHQUniformIntDistribution( 0, nTotalWeight );
	local nCurWeight = 0;
	for ( local i = 0; i < Variants_t.len(); i++ )
	{
		nCurWeight += Variants_t[i][1];
		
		if ( nCurWeight >= nRand )
			return Variants_t[i][0];
	}
	
	return Variants_t.pop()[0];
}

function BuildLayout( Layout_t )
{
	local nSizeY = Layout_t.len();
	local nSizeX = Layout_t[0].len();

	for ( local y = 0; y < nSizeY; y++ )
	{
		for ( local x = 0; x < nSizeX; x++ )
		{
			local strTile = FindTileType( Layout_t, x, y );
			local strRandomVariant = PickRandomTileVariant( GetTileVariants( strTile ) );
			
			DoEntFire( "template_tile_" + strTile + strRandomVariant, "ForceSpawn", "", 0.0, null, null );
			EntFireByHandle( hSelf, "RunScriptCode", "PlaceTileInPlace( " + x.tostring() + ", " + y.tostring() + ", GetTileRotation( " + x.tostring() + ", " + y.tostring() + ", " + Layout_t[y][x].tostring() + ", " + GetPreviousTile( Layout_t, x, y ).tostring() + " ), \"" + strTile + strRandomVariant + "\" );", 0.0, null, null );
		}
	}
}

function GetNextTilePos( Layout_t, x, y )
{
	local cCurTile = Layout_t[y][x];
	
	if ( cCurTile == '^' || cCurTile == 'U' )
		return Vector( x, y - 1, 0 );
	
	if ( cCurTile == 'v' || cCurTile == 'D' )
		return Vector( x, y + 1, 0 );
		
	if ( cCurTile == '<' || cCurTile == 'L' )
		return Vector( x - 1, y, 0 );
		
	if ( cCurTile == '>' || cCurTile == 'R' )
		return Vector( x + 1, y, 0 );
		
	return null;
}

function BuildNavigation()
{
	local CombinedLayout_t = MapInfo_t[ 2 ];
	local UsedNodes_t = {};
	
	foreach ( strNode, hNode in Nodes_t )
	{
		local NearNodes_t = {};
		InfoNodes.GetAllNearestNodes( null, hNode.GetOrigin(), 16, NearNodes_t );
		
		foreach ( strNearNode, hNearNode in NearNodes_t )
		{
			local Tile_t = GetTileFromWorldCoordinates( hNearNode.GetOrigin() );
			if ( CombinedLayout_t[ Tile_t[1] ][ Tile_t[0] ] == ' ' )
				continue;
			
			if ( hNearNode == hNode || hNode.GetLink( hNearNode.GetId() ) )
				continue;
			
			local Trace_t = {};
			Trace_t[ "start" ] <- hNode.GetOrigin() + Vector( 0.0, 0.0, 16.0 );
			Trace_t[ "end" ] <- hNearNode.GetOrigin() + Vector( 0.0, 0.0, 16.0 );
			Trace_t[ "collisiongroup" ] <- 9;
			Trace_t[ "mask" ] <- MASK_PLAYERSOLID_BRUSHONLY;
			TraceLineTable( Trace_t );
			
			if ( !Trace_t[ "hit" ] )
			{
				local hLink = InfoNodes.CreateLink( hNode.GetId(), hNearNode.GetId() );
				if ( !hLink )
				{
					ClientPrint( null, 3, "failed to create what must have been valid link %s1->%s2", hNode.GetId().tostring(), hNearNode.GetId().tostring() );
					continue;
				}
				
				for ( local i = 0; i <= 12; i++ )
					hLink.SetAcceptedMoveTypes( i, 1 );
					
				UsedNodes_t[ hNode ] <- true;
				UsedNodes_t[ hNearNode ] <- true;
			}
		}
	}
	
	foreach ( strNode, hNode in Nodes_t )
		if ( !( hNode in UsedNodes_t ) )
			hNode.Lock(9999.0);
}

Nodes_t <- {};
InfoNodes.GetAllNodes( Nodes_t );
foreach ( strNode, hNode in Nodes_t )
{
	hNode.Unlock();
	hNode.ClearLinks();
}

function DeleteMap()
{
	DoEntFire( "brush_acid*", "Disable", "", 0.0, null, null );
	DoEntFire( "scenery_tile_*", "Kill", "", 0.0, null, null );
	DoEntFire( "tile_*", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_objective_*", "SetIncomplete", "", 0.0, null, null );
	DoEntFire( "obj_power", "SetVisible", "1", 0.0, null, null );
	DoEntFire( "obj_reserves", "SetVisible", "1", 0.0, null, null );
	DoEntFire( "asw_marker", "SetIncomplete", "", 0.0, null, null );
	DoEntFire( "asw_marker", "Disable", "", 0.0, null, null );
	DoEntFire( "counter_*", "SetValue", "0", 0.0, null, null );
	DoEntFire( "objmarker_escape", "Disable", "", 0.0, null, null );
	
	//asw_clearhouse equivalent
	DoEntFire( "asw_drone", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_buzzer", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_parasite", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_shieldbug", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_grub", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_drone_jumper", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_harvester", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_parasite_defanged", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_queen", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_boomer", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_ranger", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_mortarbug", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_shaman", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_drone_uber", "Kill", "", 0.0, null, null );
	DoEntFire( "npc_antlionguard_normal", "Kill", "", 0.0, null, null );
	DoEntFire( "npc_antlionguard_cavern", "Kill", "", 0.0, null, null );
	DoEntFire( "npc_antlion", "Kill", "", 0.0, null, null );
	DoEntFire( "pc_antlion_worker", "Kill", "", 0.0, null, null );
	DoEntFire( "npc_zombie", "Kill", "", 0.0, null, null );
	DoEntFire( "npc_zombie_torso", "Kill", "", 0.0, null, null );
	DoEntFire( "npc_poisonzombie", "Kill", "", 0.0, null, null );
	DoEntFire( "npc_fastzombie", "Kill", "", 0.0, null, null );
	DoEntFire( "npc_fastzombie_torso", "Kill", "", 0.0, null, null );
	DoEntFire( "npc_headcrab", "Kill", "", 0.0, null, null );
	DoEntFire( "npc_headcrab_fast", "Kill", "", 0.0, null, null );
	DoEntFire( "npc_headcrab_poison", "Kill", "", 0.0, null, null );
	DoEntFire( "npc_zombine", "Kill", "", 0.0, null, null );
	DoEntFire( "npc_combine_s", "Kill", "", 0.0, null, null );
	DoEntFire( "npc_combine_shotgun", "Kill", "", 0.0, null, null );
	DoEntFire( "npc_combine_elite", "Kill", "", 0.0, null, null );
	DoEntFire( "npc_hunter", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_alien_goo", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_grub_sac", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_spawner", "Kill", "", 0.0, null, null );
	DoEntFire( "asw_egg", "Kill", "", 0.0, null, null );
	
	foreach ( strNode, hNode in Nodes_t )
	{
		hNode.Unlock();
		hNode.ClearLinks();
	}
}

MapInfo_t <- [];

function SpawnMap( nSeed = -1 )
{
	DeleteMap();
	
	if ( nSeed == -1 )
		nSeed = RandomInt( 100000, 999999 );
	
	// need a delay for the engine to free previous edicts properly
	EntFireByHandle( hSelf, "RunScriptCode", "local nSeed = " + nSeed.tostring() + ";while( !newthread( _SpawnMap ).call( nSeed ) ){ ClientPrint( null, 3, \"Failed to spawn map with seed \" + nSeed.tostring() + \", retrying with random seed\" ); nSeed = RandomHQUniformIntDistribution( 100000, 999999 ) };", 0.2, null, null );
	// dont build nav earlier than 0.1s after map spawn (the entfire above)
	EntFireByHandle( hSelf, "RunScriptCode", "newthread( BuildNavigation ).call();", 0.3, null, null );
	DoEntFire( "clip_tile_*", "Kill", "", 0.35, null, null );
}

function _SpawnMap( nSeed )
{
	if ( nSeed == -1 )
		nSeed = RandomInt( 100000, 999999 );

	RandomHQSetSeed( nSeed );
	
	DoEntFire( "brush_acid" + RandomHQUniformIntDistribution( 1, 3 ).tostring(), "Enable", "", 0.0, null, null );
	
	printl( "seed " + nSeed.tostring() );
	
	local LayoutBase_t = CreateRandomLayout( MAP_MAX_SIZE_X, MAP_MAX_SIZE_Y, 10, 15 )[0];
	
	PrintLayout( LayoutBase_t );
	printl("-------------")
	
	local BranchLayout_t = CreateDeadBranchLayout( LayoutBase_t, 3, 1, 3 );
	if ( !BranchLayout_t )
		return ClientPrint( null, 3, "failed to create a deadbranch layout after 1000 tries" );
		
	PrintLayout( BranchLayout_t );
		
	BranchLayout_t = CreateAliveBranchLayout( LayoutBase_t, BranchLayout_t, 2, 1, 4 );
	if ( !BranchLayout_t )
		return ClientPrint( null, 3, "failed to create a alivebranch layout after 1000 tries" );
	
	PrintLayout( LayoutBase_t );
	printl( "------" );
	
	PrintLayout( BranchLayout_t );
	
	local CombinedLayout_t = CombineMainLayoutAndBranchLayout( LayoutBase_t, BranchLayout_t );
	
	printl( "---------" )
	
	PrintLayout( CombinedLayout_t );
	
	MapInfo_t <- [ LayoutBase_t, BranchLayout_t, CombinedLayout_t ];
	
	BuildLayout( CombinedLayout_t );
	
	EntFireByHandle( hSelf, "RunScriptCode", "MapPostSpawn()", 0.1, null, null );
	
	return true;
}

function MapPostSpawn()
{
// complete hacks objective
	local hMarker = null;
	local nCompAreas = 0;
	local hCompArea = null;
	while ( hCompArea = Entities.FindByClassname( hCompArea, "trigger_asw_computer_area" ) )
	{
		nCompAreas++;
		hMarker = Entities.FindByName( hMarker, "objmarker_hacks" );
		EntFireByHandle( hMarker, "Enable", "", 0.0, null, null );
		hMarker.SetOrigin( hCompArea.GetOrigin() );
	}
	
	DoEntFire( "obj_hacks_real", "SetMaxProgress", nCompAreas.tostring(), 0.0, null, null );
	DoEntFire( "counter_hacks", "addoutput", "max " + nCompAreas.tostring(), 0.0, null, null );
// destroy power sources objective
	hMarker = null;
	local nButtAreas = 0;
	local hButtArea = null;
	while ( hButtArea = Entities.FindByClassname( hButtArea, "trigger_asw_button_area" ) )
	{
		if ( hButtArea.GetHealth() != 1 )
			continue;
		
		nButtAreas++;
		hMarker = Entities.FindByName( hMarker, "objmarker_power" );
		EntFireByHandle( hMarker, "Enable", "", 0.0, null, null );
		hMarker.SetOrigin( hButtArea.GetOrigin() );
	}
	
	DoEntFire( "obj_power", "SetMaxProgress", nButtAreas.tostring(), 0.0, null, null );
	DoEntFire( "counter_power", "addoutput", "max " + nButtAreas.tostring(), 0.0, null, null );
	if ( nButtAreas == 0 )
	{
		DoEntFire( "obj_power", "SetVisible", "0", 0.0, null, null );
		DoEntFire( "counter_power", "addoutput", "max 1", 0.0, null, null );
		DoEntFire( "counter_power", "Add", "1", 0.0, null, null );
	}
// oil reserves objective
	hMarker = null;
	local nButtAreas = 0;
	local hButtArea = null;
	while ( hButtArea = Entities.FindByClassname( hButtArea, "trigger_asw_button_area" ) )
	{
		if ( hButtArea.GetHealth() != 2 )
			continue;
		
		nButtAreas++;
		hMarker = Entities.FindByName( hMarker, "objmarker_reserves" );
		EntFireByHandle( hMarker, "Enable", "", 0.0, null, null );
		hMarker.SetOrigin( hButtArea.GetOrigin() );
	}
	
	DoEntFire( "obj_reserves", "SetMaxProgress", nButtAreas.tostring(), 0.0, null, null );
	DoEntFire( "counter_reserves", "addoutput", "max " + nButtAreas.tostring(), 0.0, null, null );
	if ( nButtAreas == 0 )
	{
		DoEntFire( "obj_reserves", "SetVisible", "0", 0.0, null, null );
		DoEntFire( "counter_reserves", "addoutput", "max 1", 0.0, null, null );
		DoEntFire( "counter_reserves", "Add", "1", 0.0, null, null );
	}
	
	DoEntFire( "objmarker_escape", "RunScriptCode", "self.SetOrigin( Entities.FindByClassname( null, \"trigger_asw_door_area\" ).GetOrigin() )", 0.0, null, null );
	
	local nLaser = 0;
	local hLaser = null;
	while ( hLaser = Entities.FindByClassname( hLaser, "env_laser" ) )
	{
		nLaser++;
		
		local hTarget = Entities.FindByClassnameNearest( "info_target", hLaser.GetOrigin(), 512.0 );
		hTarget.SetName( "lasertarget_" + nLaser.tostring() );
		
		NetProps.SetPropString( hLaser, "m_iszLaserTarget", hTarget.GetName() );
		
		EntFireByHandle( hLaser, "TurnOn", "", 0.0, null, null );
	}
	
	// spawn players on start tile
	local LayoutBase_t = MapInfo_t[0];
	local vecStart = GetStartAndEndTilePos( LayoutBase_t )[0];
	local fMarineStartRotation = GetTileRotation( -1, -1, LayoutBase_t[ vecStart.y ][ vecStart.x ], ' ' ) - 90.0;
	
	local hMarine = null;
	local hStart = null;
	while ( hMarine = Entities.FindByClassname( hMarine, "asw_marine" ) )
	{
		hStart = Entities.FindByClassname( hStart, "info_player_start" );
		hMarine.SetOrigin( hStart.GetOrigin() );
		NetProps.SetPropFloat( hMarine.GetCommander(), "m_flMovementAxisYaw", fMarineStartRotation );
	}
	
	local hPropPhysics = null;
	while ( hPropPhysics = Entities.FindByClassname( hPropPhysics, "prop_physics" ) )
	{
		EntFireByHandle( hPropPhysics, "ClearParent", "", 0.0, null, null );
		EntFireByHandle( hPropPhysics, "EnableMotion", "", 0.05, null, null );
	}

	local hPropAswBarrelExplosive = null;
	while ( hPropAswBarrelExplosive = Entities.FindByClassname( hPropAswBarrelExplosive, "asw_barrel_explosive" ) )
	{
		EntFireByHandle( hPropAswBarrelExplosive, "ClearParent", "", 0.0, null, null );
		EntFireByHandle( hPropAswBarrelExplosive, "EnableMotion", "", 0.05, null, null );
	}

	local hPropAswBarrelRadioactive = null;
	while ( hPropAswBarrelRadioactive = Entities.FindByClassname( hPropAswBarrelRadioactive, "asw_barrel_radioactive" ) )
	{
		EntFireByHandle( hPropAswBarrelRadioactive, "ClearParent", "", 0.0, null, null );
		EntFireByHandle( hPropAswBarrelRadioactive, "EnableMotion", "", 0.05, null, null );
	}
	
	local Eggs_t = [];
	local hEgg = null;
	while ( hEgg = Entities.FindByClassname( hEgg, "asw_egg" ) )
		Eggs_t.push( hEgg );
	
	foreach ( hEgg in Eggs_t )
	{
		local hNewEgg = Entities.CreateByClassname( "asw_egg" );
		hNewEgg.SetOrigin( hEgg.GetOrigin() );
		hNewEgg.SetAnglesVector( hEgg.GetAngles() );
		hNewEgg.Spawn();
		hNewEgg.Activate();
		hEgg.Destroy();
	}
}

function OnGameplayStart()
{
	local vecStart = GetStartAndEndTilePos( MapInfo_t[0] )[0];
	local fMarineStartRotation = GetTileRotation( -1, -1, MapInfo_t[0][ vecStart.y ][ vecStart.x ], ' ' ) - 90.0;
	local hMarine = null;
	while ( hMarine = Entities.FindByClassname( hMarine, "asw_marine" ) )
	{
		hMarine.__KeyValueFromString( "rendercolor", "255 150 255 255" );
		DoEntFire( hMarine.GetName() + "_weapon", "addoutput", "rendercolor 255 150 255 255", 0.0, null, null );
		
		NetProps.SetPropFloat( hMarine.GetCommander(), "m_flMovementAxisYaw", fMarineStartRotation );
		
		hMarine.ValidateScriptScope();
		hMarine.GetScriptScope().RMLThink <- function()
		{
			if ( !self || !self.IsValid() )
				return;
				
			local hGround = NetProps.GetPropEntity( self, "m_hGroundEntity" );
			local strGroundName = hGround ? hGround.GetName() : ""
			if ( strGroundName.len() > ("brush_acid").len() && strGroundName.slice( 0, ("brush_acid").len() ) == "brush_acid" )
				self.TakeDamage( 5.0, 262144, null );
			
			EntFireByHandle( self, "RunScriptCode", "RMLThink()", 0.1, null, null );
		}
		
		hMarine.GetScriptScope().RMLThink();
	}
}

hSelf <- self;

foreach( strVar, pVar in self.GetScriptScope() )
{	
	if ( strVar in ScriptScopePostSpawn_t && strVar != "hSelf" )
		continue;

	getroottable()[ strVar ] <- pVar;
}

SpawnMap();