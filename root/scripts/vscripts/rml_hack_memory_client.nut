// =========================================================
//  MEMORY BANK ALIGNMENT -- CLIENT
//  Each sector has a UNIQUE random target orientation.
//  A small housing marker shows where the sector's index
//  dot must land.  Rotate dot under marker -> aligned.
// =========================================================
FONT_DEFAULTLARGE <- self.LookupFont("DefaultLarge");

bDebugLog <- false;

const DESIGN_W = 1600.0;
const DESIGN_H = 900.0;
const PI = 3.14159265;

// ----- Difficulty: 0 = EASY, 1 = NORMAL, 2 = HARD -----
const DIFFICULTY = 2;

const INPUT_START   = 1;
const INPUT_SUCCESS = 2;

const ANIM_SPEED_DEG = 540.0;

SECTOR_COUNT <- 4;
ROTATIONS    <- 4;
StepAngleDeg <- 90.0;
SYNC_ENABLED <- false;
SyncPairs_t  <- [];

if ( DIFFICULTY == 0 )
{
	SECTOR_COUNT = 3; ROTATIONS = 4; StepAngleDeg = 90.0;
}
else if ( DIFFICULTY == 2 )
{
	SECTOR_COUNT = 5; ROTATIONS = 16; StepAngleDeg = 15.0;
	//SYNC_ENABLED = true;
	//SyncPairs_t = [ [1, 3] ];
}

// ----- Palette -----
COLOR_BG_SHADOW     <- [   0,   0,   0, 155 ];
COLOR_BG_FRAME      <- [   5,  13,  21, 255 ];
COLOR_BG_BEZEL      <- [  20,  57,  65, 230 ];
COLOR_BG_SCREEN     <- [   4,  12,  20, 255 ];
COLOR_BG_EDGE       <- [  61, 163, 157, 180 ];
COLOR_BG_BOTTOM     <- [  18,  55,  67, 230 ];
COLOR_BG_SIDE       <- [  34, 102, 111, 180 ];
COLOR_BG_GRID       <- [  18,  42,  52, 100 ];
COLOR_BG_GRID_FAINT <- [  18,  42,  52,  72 ];
COLOR_BG_SWEEP      <- [  73, 184, 176,  32 ];

COLOR_HEADER_TEXT   <- [ 104, 241, 220, 255 ];
COLOR_HEADER_STATUS <- [ 120, 180, 184, 255 ];

COLOR_PANEL_BG      <- [   5,  13,  21, 245 ];
COLOR_PANEL_INNER   <- [  12,  30,  38, 255 ];
COLOR_PANEL_BORDER  <- [  61, 163, 157, 200 ];

COLOR_RING_OUTER    <- [  72,  92,  98, 255 ];
COLOR_RING_INNER    <- [   8,  18,  24, 255 ];
COLOR_TICK_DIM      <- [  70,  90,  95, 255 ];
COLOR_TICK_BRIGHT   <- [ 104, 241, 220, 255 ];

COLOR_TRACE_ALIGNED <- [  83, 220, 150, 255 ];
COLOR_TRACE_WRONG   <- [ 200, 140,  80, 255 ];

COLOR_DOT_IDLE      <- [ 240, 200,  80, 255 ];
COLOR_DOT_ALIGNED   <- [  83, 220, 150, 255 ];

COLOR_MARKER        <- [ 100, 200, 210, 255 ];
COLOR_MARKER_HOT    <- [ 104, 241, 220, 255 ];

COLOR_BRIDGE_OK     <- [  83, 220, 150, 255 ];
COLOR_BRIDGE_BAD    <- [  40,  60,  65, 255 ];

COLOR_WARN_YELLOW   <- [ 240, 200,  80, 255 ];
COLOR_WARN_RED      <- [ 222,  67,  61, 255 ];
COLOR_WARN_GREEN    <- [  83, 220, 150, 255 ];

// ----- State -----
Phase          <- "standby";
Rot_t          <- [];      // current step index (0..ROTATIONS-1)
TargetRot_t    <- [];      // correct step index for each sector
VisualAngle_t  <- [];      // animated current angle in degrees
LocalTrace_t   <- [];      // trace's local angle so it's horizontal when aligned
FlashTime_t    <- [];
LastTickTime   <- 0.0;
GlobalTime     <- 0.0;
bSentStart     <- false;
bSentEnd       <- false;
bPressedLMB    <- false;
bPressedRMB    <- false;
HoverSector    <- -1;
DebugLastLog   <- 0.0;

// ----- Layout -----
SectorCX_t <- [];
SectorCY   <- 455.0;
SectorR    <- 100.0;

// =========================================================
//  HELPERS
// =========================================================
function GetDesignView()
{
	local w = ScreenHeight().tofloat() * 0.65 * 1024.0 / 768.0;
	local h = ScreenHeight().tofloat() * 0.65;
	return [ 0.0, 0.0, w, h ];
}
function X( v, n ) { return v[0] + n / DESIGN_W * v[2]; }
function Y( v, n ) { return v[1] + n / DESIGN_H * v[3]; }

function PaintColorRect( v, x0, y0, x1, y1, c )
{
	self.PaintRectangle( X(v,x0), Y(v,y0), X(v,x1), Y(v,y1), c[0],c[1],c[2],c[3] );
}
function PaintColorText( v, x, y, c, s )
{
	self.PaintText( X(v,x), Y(v,y), c[0],c[1],c[2],c[3], FONT_DEFAULTLARGE, s );
}
function PaintCenteredText( v, cx, cy, c, s )
{
	local w = self.GetTextWide( FONT_DEFAULTLARGE, s );
	local h = self.GetFontTall( FONT_DEFAULTLARGE );
	self.PaintText( X(v,cx) - w*0.5, Y(v,cy) - h*0.5, c[0],c[1],c[2],c[3], FONT_DEFAULTLARGE, s );
}
function TextWideDesign( v, s ) { return self.GetTextWide(FONT_DEFAULTLARGE,s) * DESIGN_W / v[2]; }

function DrawLine( v, x0, y0, x1, y1, t, c )
{
	local dx = x1-x0, dy = y1-y0;
	local adx = fabs(dx), ady = fabs(dy);
	local span = adx > ady ? adx : ady;
	local steps = (span/2.0).tointeger();
	if ( steps < 4 )   steps = 4;
	if ( steps > 160 ) steps = 160;
	for ( local i = 0; i <= steps; i++ )
	{
		local f = i.tofloat() / steps;
		local px = x0 + dx*f;
		local py = y0 + dy*f;
		PaintColorRect( v, px-t*0.5, py-t*0.5, px+t*0.5, py+t*0.5, c );
	}
}

// Return a point at (cx + r*sin(θ), cy - r*cos(θ)) so θ=0 is screen-up.
function PointOnCircle( cx, cy, r, angleDeg )
{
	local a = angleDeg * PI / 180.0;
	return [ cx + r * sin(a), cy - r * cos(a) ];
}

// =========================================================
//  LAYOUT
// =========================================================
function BuildLayout()
{
	SectorCX_t = [];
	local leftX  = 290.0;
	local rightX = 1310.0;
	local span   = rightX - leftX;

	for ( local i = 0; i < SECTOR_COUNT; i++ )
	{
		if ( SECTOR_COUNT <= 1 )
			SectorCX_t.push( (leftX + rightX) * 0.5 );
		else
			SectorCX_t.push( leftX + span * i / (SECTOR_COUNT - 1).tofloat() );
	}

	local spacing = (SECTOR_COUNT > 1) ? span / (SECTOR_COUNT - 1).tofloat() : span;
	SectorR = spacing * 0.40;
	if ( SectorR > 130.0 ) SectorR = 130.0;
	if ( SectorR <  60.0 ) SectorR =  60.0;
}

// =========================================================
//  PUZZLE
// =========================================================
function GetSyncPartner( idx )
{
	if ( !SYNC_ENABLED ) return -1;
	for ( local p = 0; p < SyncPairs_t.len(); p++ )
	{
		if ( SyncPairs_t[p][0] == idx ) return SyncPairs_t[p][1];
		if ( SyncPairs_t[p][1] == idx ) return SyncPairs_t[p][0];
	}
	return -1;
}

function GeneratePuzzle()
{
	Rot_t = []; TargetRot_t = []; VisualAngle_t = [];
	LocalTrace_t = []; FlashTime_t = [];

	for ( local i = 0; i < SECTOR_COUNT; i++ )
	{
		local target = RandomInt( 0, ROTATIONS - 1 );
		TargetRot_t.push( target );
		LocalTrace_t.push( -target * StepAngleDeg );

		local r = RandomInt( 0, ROTATIONS - 1 );
		Rot_t.push( r );
		VisualAngle_t.push( r * StepAngleDeg );
		FlashTime_t.push( 0.0 );
	}

	// Sync pair: force partner to share rotation + target so the
	// linked-rotation constraint stays solvable.
	if ( SYNC_ENABLED )
	{
		for ( local p = 0; p < SyncPairs_t.len(); p++ )
		{
			local a = SyncPairs_t[p][0];
			local b = SyncPairs_t[p][1];
			if ( a < SECTOR_COUNT && b < SECTOR_COUNT )
			{
				TargetRot_t[b] = TargetRot_t[a];
				LocalTrace_t[b] = LocalTrace_t[a];
				Rot_t[b] = Rot_t[a];
				VisualAngle_t[b] = VisualAngle_t[a];
			}
		}
	}

	// Not solved at start.
	local solved = true;
	for ( local i = 0; i < SECTOR_COUNT; i++ )
		if ( Rot_t[i] != TargetRot_t[i] ) { solved = false; break; }
	if ( solved )
	{
		local pick = -1;
		for ( local i = 0; i < SECTOR_COUNT; i++ )
			if ( GetSyncPartner( i ) == -1 ) { pick = i; break; }
		if ( pick < 0 ) pick = 0;
		Rot_t[pick] = ( TargetRot_t[pick] + 1 ) % ROTATIONS;
		VisualAngle_t[pick] = Rot_t[pick] * StepAngleDeg;
	}
}

function RotateSector( idx, dirCW )
{
	if ( idx < 0 || idx >= Rot_t.len() ) return;
	local delta = dirCW ? 1 : ( ROTATIONS - 1 );

	Rot_t[idx] = ( Rot_t[idx] + delta ) % ROTATIONS;
	FlashTime_t[idx] = Time();

	local p = GetSyncPartner( idx );
	if ( p >= 0 && p < Rot_t.len() )
	{
		Rot_t[p] = ( Rot_t[p] + delta ) % ROTATIONS;
		FlashTime_t[p] = Time();
	}
}

function IsSectorAligned( idx )
{
	return idx >= 0 && idx < Rot_t.len() && Rot_t[idx] == TargetRot_t[idx];
}
function CountAligned()
{
	local n = 0;
	for ( local i = 0; i < Rot_t.len(); i++ )
		if ( Rot_t[i] == TargetRot_t[i] ) n++;
	return n;
}
function IsFullyAligned()
{
	for ( local i = 0; i < Rot_t.len(); i++ )
		if ( Rot_t[i] != TargetRot_t[i] ) return false;
	return true;
}

// =========================================================
//  TICK
// =========================================================
function Tick( dt )
{
	for ( local i = 0; i < Rot_t.len(); i++ )
	{
		local targetDeg = Rot_t[i] * StepAngleDeg;
		local diff = targetDeg - VisualAngle_t[i];
		while ( diff >  180.0 ) diff -= 360.0;
		while ( diff < -180.0 ) diff += 360.0;
		local step = ANIM_SPEED_DEG * dt;
		if ( fabs( diff ) <= step ) VisualAngle_t[i] = targetDeg;
		else if ( diff > 0 )        VisualAngle_t[i] += step;
		else                        VisualAngle_t[i] -= step;
		while ( VisualAngle_t[i] >= 360.0 ) VisualAngle_t[i] -= 360.0;
		while ( VisualAngle_t[i] <  0.0 )   VisualAngle_t[i] += 360.0;
	}

	if ( Phase == "running" && IsFullyAligned() )
	{
		Phase = "complete";
		if ( !bSentEnd ) { bSentEnd = true; self.SendInput( INPUT_SUCCESS ); }
	}
}

// =========================================================
//  PAINT
// =========================================================
function Paint()
{
	local now = Time();
	local dt = now - LastTickTime;
	if ( dt < 0 ) dt = 0;
	if ( dt > 0.15 ) dt = 0.15;
	LastTickTime = now;
	GlobalTime = now;

	if ( Phase == "running" || Phase == "complete" ) Tick( dt );

	UpdateFromServer();

	if ( bDebugLog && now - DebugLastLog > 1.0 )
	{
		DebugLastLog = now;
		Msg( "memory pkt: [" + self.GetString( 0 ) + "]  phase=" + Phase );
	}

	local view  = GetDesignView();
	local pulse = ( sin( Time() * 1.2 ) + 1.0 ) * 0.5;

	PaintBackground( view, pulse );
	PaintHeader( view );
	PaintInfoRow( view );
	PaintArrayPanel( view );
	PaintSectors( view, pulse );
	PaintBridges( view, pulse );
	if ( Phase == "complete" ) PaintComplete( view );
}

function PaintBackground( v, pulse )
{
	PaintColorRect( v, -16,   8, DESIGN_W+16, DESIGN_H+12, COLOR_BG_SHADOW );
	PaintColorRect( v,  -8,   0, DESIGN_W+8,  DESIGN_H,     COLOR_BG_FRAME );
	PaintColorRect( v,  -4,   4, DESIGN_W+4,  DESIGN_H-4,   COLOR_BG_BEZEL );
	PaintColorRect( v,   0,   8, DESIGN_W,    DESIGN_H-8,   COLOR_BG_SCREEN );

	PaintColorRect( v, 0,   8, DESIGN_W, 12,        COLOR_BG_EDGE );
	PaintColorRect( v, 0, DESIGN_H-12, DESIGN_W, DESIGN_H-8, COLOR_BG_BOTTOM );
	PaintColorRect( v, 0,  12, 5,       DESIGN_H-12, COLOR_BG_SIDE );
	PaintColorRect( v, DESIGN_W-5, 12, DESIGN_W, DESIGN_H-12, COLOR_BG_SIDE );

	for ( local x = 80; x <= 1520; x += 80 )
		PaintColorRect( v, x, 82, x+1, 836, COLOR_BG_GRID );
	for ( local y = 82; y <= 836; y += 27 )
		PaintColorRect( v, 62, y, 1538, y+1, COLOR_BG_GRID_FAINT );

	PaintColorRect( v, 62, 82, 1538, 84, COLOR_BG_SIDE );
	PaintColorRect( v, 62, 836, 1538, 838, COLOR_BG_SIDE );
	local sweepY = 84.0 + pulse * 744.0;
	PaintColorRect( v, 62, sweepY, 1538, sweepY+1, COLOR_BG_SWEEP );
}

function PaintHeader( v )
{
	PaintColorText( v, 78, 26, COLOR_HEADER_TEXT, "MEMORY BANK ALIGNMENT" );

	local statusText, statusColor;
	if ( Phase == "standby" )       { statusText = "STANDBY";       statusColor = COLOR_HEADER_STATUS; }
	else if ( Phase == "complete" ) { statusText = "RECONSTRUCTED"; statusColor = COLOR_WARN_GREEN; }
	else                            { statusText = "ALIGNING";      statusColor = COLOR_HEADER_STATUS; }

	local w = TextWideDesign( v, statusText );
	PaintColorText( v, 1500 - w, 30, statusColor, statusText );

	PaintColorRect( v, 70, 74, 1530, 76, COLOR_BG_EDGE );
}

// Two-row header info block. No hex dumps, no subtitle.
function PaintInfoRow( v )
{
	local aligned = CountAligned();
	local total   = Rot_t.len();

	local arrayState = ( aligned == total ) ? "MEMORY ARRAY: RECONSTRUCTED" : "MEMORY ARRAY: CORRUPTED";
	local arrayCol   = ( aligned == total ) ? COLOR_WARN_GREEN : COLOR_WARN_RED;
	PaintColorText( v, 78, 90, arrayCol, arrayState );

	local alignStr = "SECTORS ALIGNED: " + aligned.tostring() + " / " + total.tostring();
	local alignW = TextWideDesign( v, alignStr );
	local alignCol = ( aligned == total ) ? COLOR_WARN_GREEN : COLOR_HEADER_TEXT;
	PaintColorText( v, 1500 - alignW, 90, alignCol, alignStr );

	if ( SYNC_ENABLED )
	{
		local warn = "!! SYNCHRONIZED MEMORY SECTORS DETECTED -- LINKED ROTATION ACTIVE !!";
		local warnW = TextWideDesign( v, warn );
		PaintColorText( v, (DESIGN_W - warnW) * 0.5, 124, COLOR_WARN_YELLOW, warn );
	}

	PaintColorRect( v, 70, 158, 1530, 159, COLOR_BG_EDGE );
}

function PaintArrayPanel( v )
{
	local px0 = 80.0;
	local px1 = 1520.0;
	local py0 = 175.0;
	local py1 = 760.0;

	PaintColorRect( v, px0, py0, px1, py1, COLOR_PANEL_BG );
	PaintColorRect( v, px0+4, py0+4, px1-4, py1-4, COLOR_PANEL_INNER );
	PaintColorRect( v, px0, py0, px1, py0+3, COLOR_PANEL_BORDER );
	PaintColorRect( v, px0, py1-3, px1, py1, COLOR_PANEL_BORDER );
	PaintColorRect( v, px0, py0, px0+3, py1, COLOR_PANEL_BORDER );
	PaintColorRect( v, px1-3, py0, px1, py1, COLOR_PANEL_BORDER );

	local bs = 7, bpad = 10;
	PaintColorRect( v, px0+bpad,     py0+bpad,     px0+bpad+bs, py0+bpad+bs, [40,70,78,255] );
	PaintColorRect( v, px1-bpad-bs,  py0+bpad,     px1-bpad,    py0+bpad+bs, [40,70,78,255] );
	PaintColorRect( v, px0+bpad,     py1-bpad-bs,  px0+bpad+bs, py1-bpad,    [40,70,78,255] );
	PaintColorRect( v, px1-bpad-bs,  py1-bpad-bs,  px1-bpad,    py1-bpad,    [40,70,78,255] );
}

function PaintSectors( v, pulse )
{
	for ( local i = 0; i < SECTOR_COUNT; i++ )
		PaintSector( v, i, pulse );
}

function PaintSector( v, i, pulse )
{
	local cx = SectorCX_t[i];
	local cy = SectorCY;
	local R  = SectorR;

	local aligned = IsSectorAligned( i );
	local visual  = VisualAngle_t[i];
	local targetAngleDeg = TargetRot_t[i] * StepAngleDeg;

	local flashAge = Time() - FlashTime_t[i];
	local flashAmt = 0.0;
	if ( flashAge >= 0.0 && flashAge < 0.25 )
		flashAmt = 1.0 - flashAge / 0.25;

	// ----- Rings & face -----
	DrawRing( v, cx, cy, R,       5, COLOR_RING_OUTER );
	DrawRing( v, cx, cy, R - 8,   3, COLOR_RING_OUTER );
	DrawDisc( v, cx, cy, R - 10, COLOR_RING_INNER );

	// ----- Static tick ring -----
	for ( local j = 0; j < ROTATIONS; j++ )
	{
		local tickAngle = j * StepAngleDeg;
		local outer = PointOnCircle( cx, cy, R * 0.96, tickAngle );
		local inner = PointOnCircle( cx, cy, R * 0.82, tickAngle );

		local tickCol = COLOR_TICK_DIM;
		local tickT   = 2.0;
		if ( j == 0 ) { tickCol = COLOR_TICK_BRIGHT; tickT = 3.0; }

		DrawLine( v, outer[0], outer[1], inner[0], inner[1], tickT, tickCol );
	}

	// ----- Rotating trace (a diameter through the disk) -----
	// Drawn at local angle LocalTrace_t[i].  Its world angle is
	// LocalTrace_t[i] + VisualAngle_t[i]; when the disk is at its
	// target rotation, that sum is 0 (horizontal).
	local traceWorld = LocalTrace_t[i] + visual;
	local tp1 = PointOnCircle( cx, cy, R * 0.90, traceWorld );
	local tp2 = PointOnCircle( cx, cy, R * 0.90, traceWorld + 180.0 );

	local traceCol, traceT;
	if ( aligned )
	{
		local a = ( 210 + pulse * 45 ).tointeger();
		traceCol = [ 83, 220, 150, a ];
		traceT = 12.0;
	}
	else
	{
		traceCol = COLOR_TRACE_WRONG;
		traceT = 10.0;
	}
	DrawLine( v, tp1[0], tp1[1], tp2[0], tp2[1], traceT, traceCol );

	// ----- Housing target marker (fixed on the panel, outside the ring) -----
	// Small inward-pointing triangle at the target world angle.
	local mp = PointOnCircle( cx, cy, R + 20, targetAngleDeg );
	local ap = PointOnCircle( cx, cy, R + 6,  targetAngleDeg );

	local markCol = aligned ? COLOR_WARN_GREEN : COLOR_MARKER;

	// Triangle base (a little wider at the far edge)
	local bx0 = mp[0] - 10;
	local by0 = mp[1] - 10;
	local bx1 = mp[0] + 10;
	local by1 = mp[1] + 10;
	PaintColorRect( v, bx0, by0, bx1, by1, [0,0,0,120] );
	PaintColorRect( v, mp[0]-6, mp[1]-6, mp[0]+6, mp[1]+6, markCol );
	PaintColorRect( v, ap[0]-3, ap[1]-3, ap[0]+3, ap[1]+3, markCol );

	// Radial guide line from disk edge to marker
	DrawLine( v, ap[0], ap[1], mp[0], mp[1], 2.0, markCol );

	// ----- Rotating index dot -----
	local dotPos = PointOnCircle( cx, cy, R * 0.94, visual );

	local dotCol, dotSize;
	if ( aligned )
	{
		dotCol  = COLOR_DOT_ALIGNED;
		dotSize = 9.0 + pulse * 3.0;
	}
	else
	{
		dotCol  = COLOR_DOT_IDLE;
		dotSize = 8.0 + flashAmt * 4.0;
	}
	PaintColorRect( v, dotPos[0]-dotSize-1, dotPos[1]-dotSize-1,
	                    dotPos[0]+dotSize+1, dotPos[1]+dotSize+1, [0,0,0,150] );
	PaintColorRect( v, dotPos[0]-dotSize, dotPos[1]-dotSize,
	                    dotPos[0]+dotSize, dotPos[1]+dotSize, dotCol );

	// ----- Center hub -----
	PaintColorRect( v, cx-7, cy-7, cx+7, cy+7, COLOR_RING_OUTER );
	PaintColorRect( v, cx-3, cy-3, cx+3, cy+3, COLOR_RING_INNER );

	// ----- Hover ring -----
	if ( HoverSector == i )
		DrawRing( v, cx, cy, R + 6, 3, COLOR_TICK_BRIGHT );

	// ----- Labels -----
	local name = "SEC-" + (i+1).tostring();
	local nameCol = aligned ? COLOR_WARN_GREEN : COLOR_HEADER_TEXT;
	PaintCenteredText( v, cx, cy + R + 34, nameCol, name );

	local statusText = aligned ? "ALIGNED" : "MISALIGNED";
	local statusCol  = aligned ? COLOR_WARN_GREEN : COLOR_WARN_YELLOW;
	PaintCenteredText( v, cx, cy + R + 60, statusCol, statusText );

	if ( SYNC_ENABLED && GetSyncPartner( i ) >= 0 )
		PaintCenteredText( v, cx, cy + R + 86, COLOR_WARN_YELLOW, "[ SYNC ]" );
}

function DrawDisc( v, cx, cy, r, col )
{
	local step = 5.0;
	local n = (r / step).tointeger();
	for ( local ix = -n; ix <= n; ix++ )
	{
		for ( local iy = -n; iy <= n; iy++ )
		{
			local px = cx + ix * step;
			local py = cy + iy * step;
			local dx = px - cx;
			local dy = py - cy;
			if ( dx*dx + dy*dy <= r*r )
				PaintColorRect( v, px - step*0.5, py - step*0.5,
				                   px + step*0.5, py + step*0.5, col );
		}
	}
}

function DrawRing( v, cx, cy, r, thickness, col )
{
	local stepAng = 3.0;
	local a = 0.0;
	while ( a < 360.0 )
	{
		local rad = a * PI / 180.0;
		local px = cx + cos(rad) * r;
		local py = cy - sin(rad) * r;
		PaintColorRect( v, px - thickness*0.5, py - thickness*0.5,
		                   px + thickness*0.5, py + thickness*0.5, col );
		a += stepAng;
	}
}

function PaintBridges( v, pulse )
{
	for ( local i = 0; i < SECTOR_COUNT - 1; i++ )
	{
		local cxL = SectorCX_t[i];
		local cxR = SectorCX_t[i+1];
		local cy  = SectorCY;

		local x0 = cxL + SectorR * 0.92;
		local x1 = cxR - SectorR * 0.92;

		local bothAligned = IsSectorAligned( i ) && IsSectorAligned( i+1 );

		if ( bothAligned )
		{
			local a = ( 230 + pulse * 25 ).tointeger();
			DrawLine( v, x0, cy, x1, cy, 16, [83, 220, 150, 80] );
			DrawLine( v, x0, cy, x1, cy,  8, [83, 220, 150, a] );
			local midX = (x0 + x1) * 0.5;
			local sz = 5.0 + pulse * 4.0;
			PaintColorRect( v, midX - sz, cy - sz, midX + sz, cy + sz, COLOR_WARN_GREEN );
		}
		else
		{
			DrawLine( v, x0, cy, x1, cy, 6, COLOR_BRIDGE_BAD );
		}
	}
}

function PaintComplete( v )
{
	local x0 = 350, x1 = 1250, y0 = 90, y1 = 176;
	PaintColorRect( v, x0, y0, x1, y1, [ 8, 45, 42, 250 ] );
	PaintColorRect( v, x0, y0, x1, y0+3, COLOR_WARN_GREEN );
	PaintColorRect( v, x0, y1-3, x1, y1, COLOR_WARN_GREEN );
	PaintCenteredText( v, (x0+x1)*0.5, y0+26, COLOR_HEADER_TEXT, "MEMORY ARRAY RECONSTRUCTED" );
	PaintCenteredText( v, (x0+x1)*0.5, y0+62, COLOR_HEADER_STATUS, "DATA INTEGRITY: 100%" );
}

// =========================================================
//  SERVER SYNC
// =========================================================
function UpdateFromServer()
{
	local packet = self.GetString( 0 );
	if ( packet == "" ) return;
	local fields = split( packet, "|" );
	if ( fields.len() < 1 ) return;
	local newState = fields[0];
	if ( newState == "complete" && Phase != "complete" ) Phase = "complete";
}

// =========================================================
//  INTERACTION
// =========================================================
function Control( table )
{
	local view = GetDesignView();

	local mx = 0.0, my = 0.0;
	if ( "mouse_x" in table ) mx = table["mouse_x"].tofloat();
	if ( "mouse_y" in table ) my = table["mouse_y"].tofloat();

	local designX = ( mx - view[0] ) / view[2] * DESIGN_W;
	local designY = ( my - view[1] ) / view[3] * DESIGN_H;

	if ( !bSentStart )
	{
		local inside = ( mx >= view[0]+12 && mx <= view[0]+view[2]-12 &&
		                 my >= view[1]+12 && my <= view[1]+view[3]-12 );
		if ( inside )
		{
			bSentStart = true;
			Phase = "running";
			self.SendInput( INPUT_START );
		}
	}

	local newHover = -1;
	local hitR = SectorR + 12.0;
	for ( local i = 0; i < SECTOR_COUNT; i++ )
	{
		local dx = designX - SectorCX_t[i];
		local dy = designY - SectorCY;
		if ( dx*dx + dy*dy <= hitR*hitR ) { newHover = i; break; }
	}
	HoverSector = newHover;

	local lmb = false, rmb = false;
	if ( "mouse_left"  in table && table["mouse_left"]  ) lmb = true;
	if ( "mouse_right" in table && table["mouse_right"] ) rmb = true;

	if ( !lmb ) bPressedLMB = false;
	if ( !rmb ) bPressedRMB = false;

	if ( Phase != "running" ) return;
	if ( HoverSector < 0 ) return;

	if ( lmb && !bPressedLMB )
	{
		bPressedLMB = true;
		RotateSector( HoverSector, true );
	}
	else if ( rmb && !bPressedRMB )
	{
		bPressedRMB = true;
		RotateSector( HoverSector, false );
	}
}

// =========================================================
//  INIT
// =========================================================
BuildLayout();
GeneratePuzzle();
LastTickTime = Time();
GlobalTime = LastTickTime;