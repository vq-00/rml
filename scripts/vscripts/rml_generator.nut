//ScriptScopePostSpawn_t <- clone self.GetScriptScope();

const PATH_UP = 1;
const PATH_DOWN = 2;
const PATH_LEFT = 3;
const PATH_RIGHT = 4;
const PATH_NONE = 0;

function CreateRandomLayout( nSizeX = 10, nSizeY = 10, nLengthMin = 10, nLengthMax = -1, nFailCount = 0, nStartTimeSecond = -1 )
{
	local TimeTable_t = {};
	LocalTime( TimeTable_t );
	local nCurTimeSecond = TimeTable_t[ "second" ];
	
	if ( nStartTimeSecond == -1 )
		nStartTimeSecond = nCurTimeSecond;
		
	if ( nLengthMax <= 0 )
		nLengthMax = nSizeX * nSizeY;
	
	local Layout_t = [];
	// make empty canvas
	for ( local y = 0; y < nSizeY; y++ )
	{
		Layout_t.push([]);
		for ( local x = 0; x < nSizeX; x++ )
		{
			Layout_t[y].push( ' ' );
		}
	}
	
	//local vecCurPos = Vector( 1, 1, 0 );
	local vecCurPos = Vector( RandomHQUniformIntDistribution( 0, nSizeX - 1 ), RandomHQUniformIntDistribution( 0, nSizeY - 1 ), 0 );
	
	local nHorizMoves = 0;
	local nVerticMoves = 0;
	local nCurLen = 0;
	while ( nCurLen < nLengthMax )
	{
		local nDir = GetRandomValidPathDirection( Layout_t, vecCurPos );
		if ( nDir == PATH_NONE )
			break;
		
		nCurLen++;
		local cDirSymbol = ' ';
		
		switch ( nDir )
		{
			case PATH_UP:
			{
				cDirSymbol = nCurLen == 1 ? 'U' : '^';
				Layout_t[ vecCurPos.y ][ vecCurPos.x ] = cDirSymbol;
				vecCurPos.y--;
				nVerticMoves++;
				break;
			}
			case PATH_DOWN:
			{
				cDirSymbol = nCurLen == 1 ? 'D' : 'v';
				Layout_t[ vecCurPos.y ][ vecCurPos.x ] = cDirSymbol;
				vecCurPos.y++;
				nVerticMoves++;
				break;
			}
			case PATH_LEFT:
			{
				cDirSymbol = nCurLen == 1 ? 'L' : '<';
				Layout_t[ vecCurPos.y ][ vecCurPos.x ] = cDirSymbol;
				vecCurPos.x--;
				nHorizMoves++;
				break;
			}
			case PATH_RIGHT:
			{
				cDirSymbol = nCurLen == 1 ? 'R' : '>';
				Layout_t[ vecCurPos.y ][ vecCurPos.x ] = cDirSymbol;
				vecCurPos.x++;
				nHorizMoves++;
				break;
			}
		}
	}
	
	Layout_t[ vecCurPos.y ][ vecCurPos.x ] = 'E';
	
	if ( nCurLen < nLengthMin || nCurLen > nLengthMax )
	{
		// failed to generate a layout after 5 seconds of bruteforce
		if ( ( nCurTimeSecond - nStartTimeSecond + 60 ) % 60 >= 5 )
		{
			ClientPrint( null, 3, "Unable to create base layout with size current settings in under 5 seconds, fail count = %s1", nFailCount );
			return [ Layout_t, nCurLen, nHorizMoves, nVerticMoves, nFailCount ];
		}
		
		return CreateRandomLayout( nSizeX, nSizeY, nLengthMin, nLengthMax, ++nFailCount, nStartTimeSecond );
	}
	
	// center the layout so creating branch layouts doesnt fail sometimes
	CenterLayout( Layout_t, nSizeX, nSizeY );
	
	return [ Layout_t, nCurLen, nHorizMoves, nVerticMoves, nFailCount ];
}

function CenterLayout( Layout_t, nSizeX, nSizeY )
{
// center horizontally
	local nRightEmpty = 0;
	local nLeftEmpty = 0;
	for ( local x = 0; x < nSizeX; x++ )
	{
		for ( local y = 0; y < nSizeY; y++ )
		{
			if ( Layout_t[y][x] != ' ' )
			{
				x = nSizeX;
				break;
			}
			
			nLeftEmpty++;
		}
	}
	
	for ( local x = nSizeX - 1; x >= 0; x-- )
	{
		for ( local y = 0; y < nSizeY; y++ )
		{
			if ( Layout_t[y][x] != ' ' )
			{
				x = -1;
				break;
			}
			
			nRightEmpty++;
		}
	}
	
	nRightEmpty /= nSizeX;
	nLeftEmpty /= nSizeX;
	
	if ( nRightEmpty - nLeftEmpty > 1 )
	{
		for ( local i = 0; i < ( nRightEmpty - nLeftEmpty ) / 2; i++ )
		{
			DoMoveLayout( PATH_LEFT, Layout_t );
		}
	}
	else if ( nRightEmpty - nLeftEmpty < -1 )
	{
		for ( local i = 0; i < ( nLeftEmpty - nRightEmpty ) / 2; i++ )
		{
			DoMoveLayout( PATH_RIGHT, Layout_t );
		}
	}
	
// center vertically
	local nUpEmpty = 0;
	local nDownEmpty = 0;
	for ( local y = 0; y < nSizeY; y++ )
	{
		for ( local x = 0; x < nSizeX; x++ )
		{
			if ( Layout_t[y][x] != ' ' )
			{
				y = nSizeY;
				break;
			}
			
			nUpEmpty++;
		}
	}
	
	for ( local y = nSizeY - 1; y >= 0; y-- )
	{
		for ( local x = 0; x < nSizeX; x++ )
		{
			if ( Layout_t[y][x] != ' ' )
			{
				y = -1;
				break;
			}
			
			nDownEmpty++;
		}
	}
	
	nUpEmpty /= nSizeY;
	nDownEmpty /= nSizeY;
	
	if ( nUpEmpty - nDownEmpty > 1 )
	{
		for ( local i = 0; i < ( nUpEmpty - nDownEmpty ) / 2; i++ )
		{
			DoMoveLayout( PATH_DOWN, Layout_t );
		}
	}
	else if ( nUpEmpty - nDownEmpty < -1 )
	{
		for ( local i = 0; i < ( nDownEmpty - nUpEmpty ) / 2; i++ )
		{
			DoMoveLayout( PATH_UP, Layout_t );
		}
	}
}

function GetRandomValidPathDirection( Layout_t, vecCurPos, bAllowMove = true )
{
	local nTries = 0;
	local nMaxTries = 20;
	local nDir = PATH_NONE;
	local nSizeY = Layout_t.len();
	local nSizeX = Layout_t[0].len();
	
	local DirWeights_t = ComputeDirectionWeights( nSizeX, nSizeY );
	
	while ( nTries < nMaxTries )
	{
		nTries++;
		
		local vecNewPos = Vector( vecCurPos.x, vecCurPos.y, vecCurPos.z );
		
		//nDir = RandomInt( PATH_UP, PATH_RIGHT );
		nDir = GetRandomDirectionFromWeights( DirWeights_t );
		switch ( nDir )
		{
			case PATH_UP:
			{
				--vecNewPos.y;
				if ( vecNewPos.y < 0 )
				{
					if ( !bAllowMove || !DoMoveLayout( PATH_UP, Layout_t ) )
					{
						break;
					}
					else
					{
						++vecCurPos.y;
						return nDir;
					}
				}
				else if ( Layout_t[ vecNewPos.y ][ vecNewPos.x ] == ' ' )
					return nDir;
				
				break;
			}
			case PATH_DOWN:
			{
				++vecNewPos.y;
				if ( vecNewPos.y >= nSizeY )
				{
					if ( !bAllowMove || !DoMoveLayout( PATH_DOWN, Layout_t ) )
					{
						break;
					}
					else
					{
						--vecCurPos.y;
						return nDir;
					}
				}
				else if ( Layout_t[ vecNewPos.y ][ vecNewPos.x ] == ' ' )
					return nDir;
				
				break;
			}
			case PATH_LEFT:
			{
				--vecNewPos.x;
				if ( vecNewPos.x < 0 )
				{
					if ( !bAllowMove || !DoMoveLayout( PATH_LEFT, Layout_t ) )
					{
						break;
					}
					else
					{
						++vecCurPos.x;
						return nDir;
					}
				}
				else if ( Layout_t[ vecNewPos.y ][ vecNewPos.x ] == ' ' )
					return nDir;
				
				break;
			}
			case PATH_RIGHT:
			{
				++vecNewPos.x;
				if ( vecNewPos.x >= nSizeX )
				{
					if ( !bAllowMove || !DoMoveLayout( PATH_RIGHT, Layout_t ) )
					{
						break;
					}
					else
					{
						--vecCurPos.x;
						return nDir;
					}
				}
				else if ( Layout_t[ vecNewPos.y ][ vecNewPos.x ] == ' ' )
					return nDir;
				
				break;
			}
		}
	}
	
	return PATH_NONE;
}

function GetNearbySeperatePathTile( LayoutBase_t, BranchLayout_t, x, y )
{
	local nSizeY = LayoutBase_t.len();
	local nSizeX = LayoutBase_t[0].len();
	
	function RandomSort( left, right ) { return RandomHQUniformIntDistribution( -1, 1 ); }
	
	local LookDirections_t = [ '^', 'v', '<', '>' ]; 
	try { LookDirections_t.sort( RandomSort ) }catch(_){}
	
	local vecStart = GetStartAndEndTilePos( LayoutBase_t )[0];
	for ( local i = 0; i < 4; i++ )
	{
		if ( LookDirections_t[i] == '^' && y > 0 && BranchLayout_t[y-1][x] == ' ' && LayoutBase_t[y-1][x] != ' ' && LayoutBase_t[y-1][x] != 'T' && ( x != vecStart.x && y-1 != vecStart.y ) && LayoutBase_t[y-1][x] != 'E' )
			return Vector( x, y-1, '^' );
			
		if ( LookDirections_t[i] == 'v' && y < nSizeY - 1 && BranchLayout_t[y+1][x] == ' ' && LayoutBase_t[y+1][x] != ' ' && LayoutBase_t[y+1][x] != 'T' && ( x != vecStart.x && y+1 != vecStart.y ) && LayoutBase_t[y+1][x] != 'E' )
			return Vector( x, y+1, 'v' );
			
		if ( LookDirections_t[i] == '<' && x > 0 && BranchLayout_t[y][x-1] == ' ' && LayoutBase_t[y][x-1] != ' ' && LayoutBase_t[y][x-1] != 'T' && ( x-1 != vecStart.x && y != vecStart.y ) && LayoutBase_t[y][x-1] != 'E' )
			return Vector( x-1, y, '<' );
			
		if ( LookDirections_t[i] == '>' && x < nSizeX - 1 && BranchLayout_t[y][x+1] == ' ' && LayoutBase_t[y][x+1] != ' ' && LayoutBase_t[y][x+1] != 'T' && ( x+1 != vecStart.x && y != vecStart.y ) && LayoutBase_t[y][x+1] != 'E' )
			return Vector( x+1, y, '>' );
	}
	
	return null;
}


// "dead" branches are those that end in a dead end
// "alive" branches are those that connect back to main path, resulting in two different paths to one place
function CreateDeadBranchLayout( Layout_t, nBranchesDead, nBranchDeadLengthMin, nBranchDeadLengthMax, nFailCount = 0 )
{
	if ( nFailCount > 10000 )
		return null;
	
	local nSizeY = Layout_t.len();
	local nSizeX = Layout_t[0].len();

	local BranchLayout_t = [];
	for ( local y = 0; y < nSizeY; y++ )
	{
		BranchLayout_t.push([]);
		for ( local x = 0; x < nSizeX; x++ )
		{
			BranchLayout_t[y].push( ' ' );
		}
	}

	local TilesAsBranches_t = {};
	for ( local i = 0; i < nBranchesDead; i++ )
	{
		local xRand = -1;
		local yRand = -1;
		local cTile = ' ';
		while ( cTile != '^' && cTile != 'v' && cTile != '<' && cTile != '>' )
		{	
			xRand = RandomHQUniformIntDistribution( 0, nSizeX - 1 );
			yRand = RandomHQUniformIntDistribution( 0, nSizeY - 1 );
			
			local strTile = xRand.tostring() + "," + yRand.tostring();
			if ( strTile in TilesAsBranches_t )
				continue;
			
			cTile = Layout_t[ yRand ][ xRand ];
			TilesAsBranches_t[ strTile ] <- true;
		}

		local vecCurPos = Vector( xRand, yRand, 0 );
		local nCurLen = 0;
		while ( nCurLen < nBranchDeadLengthMax )
		{
			local _vecCurPos = Vector( vecCurPos.x, vecCurPos.y, vecCurPos.z );
			local CombinedLayout_t = CombineMainLayoutAndBranchLayout( Layout_t, BranchLayout_t );
			local nDir = GetRandomValidPathDirection( CombinedLayout_t, vecCurPos, false );
			if ( nDir == PATH_NONE )
			{
				if ( nCurLen < nBranchDeadLengthMin )
				{
					// failed to create a lenghty enough branch
					return CreateDeadBranchLayout( Layout_t, nBranchesDead, nBranchDeadLengthMin, nBranchDeadLengthMax, ++nFailCount );
				}
				
				BranchLayout_t[ vecCurPos.y ][ vecCurPos.x ] = 'e';
				
				break;
			}
			
			nCurLen++;
			
			if ( nCurLen == nBranchDeadLengthMax )
			{
				BranchLayout_t[ vecCurPos.y ][ vecCurPos.x ] = 'e';
				break;
			}
			
			vecCurPos = Vector( _vecCurPos.x, _vecCurPos.y, _vecCurPos.z );
			local cDirSymbol = ' ';
			
			switch ( nDir )
			{
				case PATH_UP:
				{
					cDirSymbol = nCurLen == 1 ? 'U' : '^';
					BranchLayout_t[ vecCurPos.y ][ vecCurPos.x ] = cDirSymbol;
					vecCurPos.y--;
					break;
				}
				case PATH_DOWN:
				{
					cDirSymbol = nCurLen == 1 ? 'D' : 'v';
					BranchLayout_t[ vecCurPos.y ][ vecCurPos.x ] = cDirSymbol;
					vecCurPos.y++;
					break;
				}
				case PATH_LEFT:
				{
					cDirSymbol = nCurLen == 1 ? 'L' : '<';
					BranchLayout_t[ vecCurPos.y ][ vecCurPos.x ] = cDirSymbol;
					vecCurPos.x--;
					break;
				}
				case PATH_RIGHT:
				{
					cDirSymbol = nCurLen == 1 ? 'R' : '>';
					BranchLayout_t[ vecCurPos.y ][ vecCurPos.x ] = cDirSymbol;
					vecCurPos.x++;
					break;
				}
			}
		}
	}

	return BranchLayout_t;
}

function CreateAliveBranchLayout( Layout_t, BranchLayout_t, nBranchesAlive, nBranchAliveLengthMin, nBranchAliveLengthMax, nFailCount = 0 )
{
	if ( nFailCount > 10000 )
		return null;
	
	local nSizeY = Layout_t.len();
	local nSizeX = Layout_t[0].len();

	local _Layout_t = [];
	for ( local y = 0; y < nSizeY; y++ )
	{
		_Layout_t.push([]);
		for ( local x = 0; x < nSizeX; x++ )
		{
			_Layout_t[y].push( Layout_t[y][x] );
		}
	}

	local _BranchLayout_t = [];
	for ( local y = 0; y < nSizeY; y++ )
	{
		_BranchLayout_t.push([]);
		for ( local x = 0; x < nSizeX; x++ )
		{
			_BranchLayout_t[y].push( BranchLayout_t[y][x] );
		}
	}

	local TilesAsBranches_t = {};
	for ( local i = 0; i < nBranchesAlive; i++ )
	{
		local xRand = -1;
		local yRand = -1;
		local cTile = ' ';
		while ( cTile != '^' && cTile != 'v' && cTile != '<' && cTile != '>' )
		{	
			xRand = RandomHQUniformIntDistribution( 0, nSizeX - 1 );
			yRand = RandomHQUniformIntDistribution( 0, nSizeY - 1 );
			
			local strTile = xRand.tostring() + "," + yRand.tostring();
			if ( strTile in TilesAsBranches_t || DirLetterToSymbol( _BranchLayout_t[ yRand ][ xRand ] ) )
				continue;
			
			cTile = _Layout_t[ yRand ][ xRand ];
			TilesAsBranches_t[ strTile ] <- true;
		}

		local vecCurPos = Vector( xRand, yRand, 0 );
		local nCurLen = 0;
		while ( nCurLen < nBranchAliveLengthMax )
		{
			local _vecCurPos = Vector( vecCurPos.x, vecCurPos.y, vecCurPos.z );
			local CombinedLayout_t = CombineMainLayoutAndBranchLayout( _Layout_t, _BranchLayout_t );
			
			// try to create an alive branch
			if ( nCurLen >= nBranchAliveLengthMin && nCurLen <= nBranchAliveLengthMax )
			{
				local vecData = GetNearbySeperatePathTile( _Layout_t, _BranchLayout_t, _vecCurPos.x, _vecCurPos.y );
				if ( vecData )
				{
					_BranchLayout_t[ _vecCurPos.y ][ _vecCurPos.x ] = vecData.z.tointeger();
					_BranchLayout_t[ vecData.y ][ vecData.x ] = DirSymbolToLetter( _Layout_t[ vecData.y ][ vecData.x ] );
					_Layout_t[ vecData.y ][ vecData.x ] = 'T';
					
					break;
				}
			}
			
			local nDir = GetRandomValidPathDirection( CombinedLayout_t, vecCurPos, false );
			if ( nDir == PATH_NONE )
			{
				return CreateAliveBranchLayout( Layout_t, BranchLayout_t, nBranchesAlive, nBranchAliveLengthMin, nBranchAliveLengthMax, ++nFailCount );
			}
			
			nCurLen++;
			
			if ( nCurLen == nBranchAliveLengthMax )
			{
				return CreateAliveBranchLayout( Layout_t, BranchLayout_t, nBranchesAlive, nBranchAliveLengthMin, nBranchAliveLengthMax, ++nFailCount );
			}
			
			vecCurPos = Vector( _vecCurPos.x, _vecCurPos.y, _vecCurPos.z );
			local cDirSymbol = ' ';
			
			switch ( nDir )
			{
				case PATH_UP:
				{
					cDirSymbol = nCurLen == 1 ? 'U' : '^';
					_BranchLayout_t[ vecCurPos.y ][ vecCurPos.x ] = cDirSymbol;
					vecCurPos.y--;
					break;
				}
				case PATH_DOWN:
				{
					cDirSymbol = nCurLen == 1 ? 'D' : 'v';
					_BranchLayout_t[ vecCurPos.y ][ vecCurPos.x ] = cDirSymbol;
					vecCurPos.y++;
					break;
				}
				case PATH_LEFT:
				{
					cDirSymbol = nCurLen == 1 ? 'L' : '<';
					_BranchLayout_t[ vecCurPos.y ][ vecCurPos.x ] = cDirSymbol;
					vecCurPos.x--;
					break;
				}
				case PATH_RIGHT:
				{
					cDirSymbol = nCurLen == 1 ? 'R' : '>';
					_BranchLayout_t[ vecCurPos.y ][ vecCurPos.x ] = cDirSymbol;
					vecCurPos.x++;
					break;
				}
			}
		}
	}
	
	Layout_t = _Layout_t;
	BranchLayout_t = _BranchLayout_t;
	
	return BranchLayout_t;
}

function DirSymbolToLetter( cDir )
{
	if ( cDir == '^' )
		return 'U';
		
	if ( cDir == 'v' )
		return 'D';
		
	if ( cDir == '<' )
		return 'L';
		
	if ( cDir == '>' )
		return 'R';
		
	return null;
}

function DirLetterToSymbol( cDir )
{
	if ( cDir == 'U' )
		return '^';
		
	if ( cDir == 'D' )
		return 'v';
		
	if ( cDir == 'L' )
		return '<';
		
	if ( cDir == 'R' )
		return '>';
		
	return null;
}

/*
11: at 2,0 decided to merge branch, (vector : (3.000000, 0.000000, 62.000000))
11: at 4,5 decided to merge branch, (vector : (3.000000, 5.000000, 60.000000))
0   >v     
1vL ^v     
2>v ^>v    
3 v>^ v    
4 >^v<<    
5  v<      
6  v       
7  v       
8 v<   >>>E
9 >>>>>^   
 0123456789
------
0>>>       
1U         
2D         
3v         
4v   D     
5>e  <     
6e         
7^   >v    
8^   ^e    
9^L  U     
 0123456789
 */
function CombineMainLayoutAndBranchLayout( Layout_t, BranchLayout_t )
{
	local nSizeY = Layout_t.len();
	local nSizeX = Layout_t[0].len();
	
	local CombinedLayout_t = [];
	for ( local y = 0; y < nSizeY; y++ )
	{
		CombinedLayout_t.push([]);
		for ( local x = 0; x < nSizeX; x++ )
		{
			CombinedLayout_t[y].push( ' ' );
		}
	}
	
	for ( local y = 0; y < nSizeY; y++ )
	{
		for ( local x = 0; x < nSizeX; x++ )
		{
			if ( Layout_t[y][x] != ' ' )
				CombinedLayout_t[y][x] = Layout_t[y][x];
			else if ( BranchLayout_t[y][x] != ' ' )
				CombinedLayout_t[y][x] = BranchLayout_t[y][x];
				
			if ( Layout_t[y][x] != ' ' && BranchLayout_t[y][x] != ' ' )
				CombinedLayout_t[y][x] = 'T';
		}
	}
	
	return CombinedLayout_t;
}

function DoMoveLayout( nDir, Layout_t )
{
	local nSizeY = Layout_t.len();
	local nSizeX = Layout_t[0].len();
	
	switch ( nDir )
	{
		case PATH_UP:
		{
			// we want a path up which is out of bounds, move the layout down to make it in-bounds
			// last row must be clear to be able to move layout down
			for ( local x = 0; x < nSizeX; x++ )
				if ( Layout_t[ nSizeY - 1 ][x] != ' ' )
					return false;

			// last row is clear, move the layout by moving last row to the top
			for ( local y = nSizeY - 1; y > 0; y-- )
				for ( local x = 0; x < nSizeX; x++ )
					Layout_t[y][x] = Layout_t[ y - 1 ][x];

			for ( local x = 0; x < nSizeX; x++ )
				Layout_t[0][x] = ' ';

			return true;
		}
		case PATH_DOWN:
		{
			for ( local x = 0; x < nSizeX; x++ )
				if ( Layout_t[0][x] != ' ' )
					return false;

			for ( local y = 0; y < nSizeY - 1; y++ )
				for ( local x = 0; x < nSizeX; x++ )
					Layout_t[y][x] = Layout_t[ y + 1 ][x];

			for ( local x = 0; x < nSizeX; x++ )
				Layout_t[ nSizeY - 1 ][x] = ' ';

			return true;
		}
		case PATH_LEFT:
		{
			for ( local y = 0; y < nSizeY; y++ )
				if ( Layout_t[y][ nSizeX - 1 ] != ' ' )
					return false;

			for ( local x = nSizeX - 1; x > 0; x-- )
				for ( local y = 0; y < nSizeY; y++ )
					Layout_t[y][x] = Layout_t[y][ x - 1 ];

			for ( local y = 0; y < nSizeY; y++ )
				Layout_t[y][0] = ' ';

			return true;
		}
		case PATH_RIGHT:
		{
			for ( local y = 0; y < nSizeY; y++ )
				if ( Layout_t[y][0] != ' ' )
					return false;

			for ( local x = 0; x < nSizeX - 1; x++ )
				for ( local y = 0; y < nSizeY; y++ )
					Layout_t[y][x] = Layout_t[y][ x + 1 ];

			for ( local y = 0; y < nSizeY; y++ )
				Layout_t[y][ nSizeX - 1 ] = ' ';

			return true;
		}
	}
	
	return false;
}  

function ComputeDirectionWeights( nSizeX, nSizeY )
{
	local strComputedVarName = "DirWeights_" + nSizeX.tostring() + "_" + nSizeY.tostring()
	
	// compute only once for same dimensions
	if ( strComputedVarName in getroottable() )
		return getroottable()[ strComputedVarName ];
	
	local fRatio = nSizeX.tofloat() / nSizeY.tofloat();
	
	local DirWeights_t = [ 100.0 * pow( 1.0 / fRatio, 0.4 ), 100.0 * pow( 1.0 / fRatio, 0.4 ), 100.0 * pow( fRatio, 0.4 ), 100.0 * pow( fRatio, 0.4	) ];
	local roottable = getroottable();
	roottable[ strComputedVarName ] <- DirWeights_t;
	setroottable( roottable );
	
	return DirWeights_t;
}

function GetRandomDirectionFromWeights( DirWeights_t )
{
	local nTotalWeight = 0;
	for ( local i = 0; i < DirWeights_t.len(); i++ )
		nTotalWeight += DirWeights_t[i];
		
	local nRandom = RandomHQUniformIntDistribution( 0, nTotalWeight );
	local nCurWeightBoundIndex = 0;
	local nCurWeightBound = DirWeights_t[0];
	while ( nRandom > nCurWeightBound )
	{
		nCurWeightBoundIndex++;
		nCurWeightBound += DirWeights_t[ nCurWeightBoundIndex ];
	}
	
	return nCurWeightBoundIndex + 1;
}

function GetStartAndEndTilePos( Layout_t )
{
	local nSizeY = Layout_t.len();
	local nSizeX = Layout_t[0].len();
	
	local vecStart = Vector( -1, -1, -1 );
	local vecEnd = Vector( -1, -1, -1 );
	
	for ( local y = 0; y < nSizeY; y++ )
	{
		for ( local x = 0; x < nSizeX; x++ )
		{
			if ( Layout_t[y][x] == 'U' || Layout_t[y][x] == 'D' || Layout_t[y][x] == 'L' || Layout_t[y][x] == 'R' )
				vecStart = Vector( x, y, 0 );
				
			if ( Layout_t[y][x] == 'E' )
				vecEnd = Vector( x, y, 0 );
		}
	}
	
	return [ vecStart, vecEnd ];
}

function PrintLayout( Layout_t )
{
	local nSizeY = Layout_t.len();
	local nSizeX = Layout_t[0].len();
	
	for ( local y = 0; y < nSizeY; y++ )
	{
		local strRow = "";
		for ( local x = 0; x < nSizeX; x++ )
		{
			strRow += Layout_t[y][x].tochar();
		}
		
		printl( strRow );
	}
}

// make threads see those
// todo automate the additions to this table with a for loop fetching functions from getscriptscope
//getroottable()[ "CreateRandomLayout" ] <- CreateRandomLayout;
//getroottable()[ "GetRandomValidPathDirection" ] <- GetRandomValidPathDirection;
//getroottable()[ "CreateBranchLayout" ] <- CreateBranchLayout;
//getroottable()[ "CombineMainLayoutAndBranchLayout" ] <- CombineMainLayoutAndBranchLayout;
//getroottable()[ "ComputeDirectionWeights" ] <- ComputeDirectionWeights;
//getroottable()[ "GetRandomDirectionFromWeights" ] <- GetRandomDirectionFromWeights;
//getroottable()[ "DoMoveLayout" ] <- DoMoveLayout;
//getroottable()[ "PrintLayout" ] <- PrintLayout;

//foreach( strVar, pVar in self.GetScriptScope() )
//{	
//	if ( strVar in ScriptScopePostSpawn_t )
//		continue;
//	
//	if ( typeof( pVar ) == "function" )
//		getroottable()[ strVar ] <- pVar;
//}

