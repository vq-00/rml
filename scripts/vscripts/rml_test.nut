ScriptScopePostSpawn_t <- clone self.GetScriptScope();

IncludeScript( "rml_generator.nut" );

const TILE_SIZE = 1280;
const MAP_MAX_SIZE_X = 20;
const MAP_MAX_SIZE_Y = 20;

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

	local hScenery = null;
	while ( hScenery = Entities.FindByName( hScenery, "scenery_tile_" + strTile ) )
		if ( hScenery.GetOrigin().z < -1000.0 )
			hScenery.SetParent( hNewTile );
			
	local hClip = null;
	while ( hClip = Entities.FindByName( hClip, "clip_tile_" + strTile ) )
		if ( hClip.GetOrigin().z < -1000.0 )
			hClip.SetParent( hNewTile );

	local vecOrigin = GetTileWorldCoordinates( x, y );
	
	hNewTile.SetOrigin( vecOrigin );
	hNewTile.SetAngles( 0.0, fRotate, 0.0 );
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
			
		TileVariants_t[ strTile ].push( strName.slice( strTile.len() ) );
	}
	
	return TileVariants_t[ strTile ];
}

function PickRandomTileVariant( Variants_t )
{
	if ( !Variants_t.len() )
		return "";
	
	return Variants_t[ RandomHQUniformIntDistribution( 0, Variants_t.len() - 1 ) ];
}

hSelf <- self;
function BuildLayout( Layout_t )
{
	local nSizeY = Layout_t.len();
	local nSizeX = Layout_t[0].len();

	for ( local y = 0; y < nSizeY; y++ )
	{
		for ( local x = 0; x < nSizeX; x++ )
		{
			//if ( Layout_t[y][x] == ' ' )
			//	continue;

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
			Trace_t[ "mask" ] <- MASK_PLAYERSOLID;
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
			}
		}
	}
}

Nodes_t <- {};
InfoNodes.GetAllNodes( Nodes_t );
foreach ( strNode, hNode in Nodes_t )
	hNode.ClearLinks();

function DeleteMap()
{
	DoEntFire( "brush_acid*", "Disable", "", 0.0, null, null );
	DoEntFire( "tile_*", "Kill", "", 0.0, null, null );
	
	foreach ( strNode, hNode in Nodes_t )
		hNode.ClearLinks();
}

MapInfo_t <- [];

function SpawnMap( nSeed = -1 )
{
	DeleteMap();
	
	// need a delay for the engine to free previous edicts properly
	EntFireByHandle( self, "RunScriptCode", "newthread( _SpawnMap ).call( " + nSeed.tostring() + " );", 0.03, null, null );
	EntFireByHandle( self, "RunScriptCode", "newthread( BuildNavigation ).call();", 0.08, null, null );
	DoEntFire( "clip_tile_*", "Kill", "", 0.1, null, null );
}

function _SpawnMap( nSeed )
{
	if ( nSeed == -1 )
		nSeed = RandomInt( 100000, 999999 );

	RandomHQSetSeed( nSeed );
	
	DoEntFire( "brush_acid" + RandomHQUniformIntDistribution( 1, 3 ).tostring(), "Enable", "", 0.0, null, null );
	
	printl( "seed " + nSeed.tostring() );
	
	//local LayoutBase_t = newthread( CreateRandomLayout ).call( MAP_MAX_SIZE_X, MAP_MAX_SIZE_Y, 50, 75 )[0];
	local LayoutBase_t = CreateRandomLayout( MAP_MAX_SIZE_X, MAP_MAX_SIZE_Y, 10, 15 )[0];
	
	PrintLayout( LayoutBase_t );
	printl("-------------")
	
	//some cool settings: 
	// 3, 1, 3, 3, 2, 5
	//local BranchLayout_t = newthread( CreateBranchLayout ).call( LayoutBase_t, 3, 3, 6, 3, 1, 6 );
	local BranchLayout_t = CreateDeadBranchLayout( LayoutBase_t, 3, 1, 3 );
	if ( !BranchLayout_t )
		return ClientPrint( null, 3, "failed to create a deadbranch layout after 10000 tries" );
		
	PrintLayout( BranchLayout_t );
		
	BranchLayout_t = CreateAliveBranchLayout( LayoutBase_t, BranchLayout_t, 0, 1, 4 );
	if ( !BranchLayout_t )
		return ClientPrint( null, 3, "failed to create a alivebranch layout after 10000 tries" );
	
	PrintLayout( LayoutBase_t );
	printl( "------" );
	
	PrintLayout( BranchLayout_t );
	
	local CombinedLayout_t = CombineMainLayoutAndBranchLayout( LayoutBase_t, BranchLayout_t );
	
	printl( "---------" )
	
	PrintLayout( CombinedLayout_t );
	
	MapInfo_t <- [ LayoutBase_t, BranchLayout_t, CombinedLayout_t ];
	
	BuildLayout( CombinedLayout_t );
	
	//EntFireByHandle( hSelf, "RunScriptCode", "BuildNavigation();", 0.05, null, null );
	
	// spawn players on start tile
	local vecStart = GetStartAndEndTilePos( LayoutBase_t )[0];
	local vecStartWorld = GetTileWorldCoordinates( vecStart.x, vecStart.y );
	
	local hMarine = null;
	while ( hMarine = Entities.FindByClassname( hMarine, "asw_marine" ) )
	{
		hMarine.SetOrigin( vecStartWorld + Vector( 0.0, 0.0, 64.0 ) );
		NetProps.SetPropFloat( hMarine.GetCommander(), "m_flMovementAxisYaw", GetTileRotation( -1, -1, LayoutBase_t[ vecStart.y ][ vecStart.x ], ' ' ) - 90.0 );
	}
}

foreach( strVar, pVar in self.GetScriptScope() )
{	
	if ( strVar in ScriptScopePostSpawn_t )
		continue;
	
	//if ( typeof( pVar ) == "function" || typeof( pVar ) == "table" || typeof( pVar ) == "array" )
		getroottable()[ strVar ] <- pVar;
}
