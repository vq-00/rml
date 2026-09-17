// =========================================================
//  DATA PACKET ROUTING -- CLIENT
//  Infinite attempts. Only success ends the minigame.
//  Pieces: corners only (no T-junctions, no straights).
//  Packets pause on their input cell before moving.
// =========================================================
FONT_DEFAULTLARGE <- self.LookupFont("DefaultLarge");

// ----- Design space -----
const DESIGN_W = 1600.0;
const DESIGN_H = 900.0;

// ----- Direction bits -----
const DIR_UP    = 1;
const DIR_RIGHT = 2;
const DIR_DOWN  = 4;
const DIR_LEFT  = 8;

// ----- Network grid area -----
const GRID_X      = 340.0;
const GRID_Y      = 220.0;
const GRID_AREA_W = 820.0;
const GRID_AREA_H = 540.0;

// ----- Difficulty: 0 = EASY, 1 = NORMAL, 2 = HARD -----
const DIFFICULTY = 1;

GRID_COLS        <- 5;
GRID_ROWS        <- 4;
STEP_TIME        <- 0.65;
SPAWN_INTERVAL   <- 2.20;
SPAWN_HOLD_TIME  <- 1.20;
MAX_ACTIVE       <- 2;
PACKETS_REQUIRED <- 8;

if ( DIFFICULTY == 0 )
{
	GRID_COLS = 4; GRID_ROWS = 3;
	STEP_TIME = 0.90; SPAWN_INTERVAL = 3.0; SPAWN_HOLD_TIME = 1.5; MAX_ACTIVE = 1;
	PACKETS_REQUIRED = 5;
}
else if ( DIFFICULTY == 2 )
{
	GRID_COLS = 6; GRID_ROWS = 4;
	STEP_TIME = 0.50; SPAWN_INTERVAL = 1.6; SPAWN_HOLD_TIME = 1.0; MAX_ACTIVE = 3;
	PACKETS_REQUIRED = 12;
}

const LINGER_TIME = 0.7;

// Input codes sent to server.
const INPUT_START   = 1;
const INPUT_SUCCESS = 2;

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
COLOR_SUBTITLE      <- [ 130, 180, 184, 255 ];

COLOR_PANEL_BG      <- [   5,  13,  21, 245 ];
COLOR_PANEL_INNER   <- [  12,  30,  38, 255 ];
COLOR_PANEL_BORDER  <- [  61, 163, 157, 200 ];

COLOR_CELL_BG       <- [   8,  22,  30, 255 ];
COLOR_CELL_BG_HOVER <- [  22,  54,  66, 255 ];
COLOR_CELL_EDGE     <- [  30,  68,  78, 255 ];
COLOR_CELL_EDGE_HOV <- [  94, 214, 222, 255 ];

COLOR_WIRE          <- [  66, 138, 148, 255 ];
COLOR_NODE_BG       <- [  20,  45,  55, 255 ];
COLOR_NODE_IN       <- [  80, 180, 130, 255 ];
COLOR_NODE_OUT      <- [ 240, 180,  90, 255 ];

COLOR_WARN_YELLOW   <- [ 240, 200,  80, 255 ];
COLOR_WARN_RED      <- [ 222,  67,  61, 255 ];
COLOR_WARN_GREEN    <- [  83, 220, 150, 255 ];

COLOR_DEST_0        <- [ 240, 100,  90, 255 ];
COLOR_DEST_1        <- [ 240, 200,  80, 255 ];
COLOR_DEST_2        <- [  83, 220, 150, 255 ];
COLOR_DEST_3        <- [ 104, 180, 240, 255 ];

// ----- State -----
Phase          <- "standby";
Cells_t        <- [];
Packets_t      <- [];
Delivered      <- 0;
Lost           <- 0;
Spawned        <- 0;
NextSpawnTime  <- 0.0;
LastTickTime   <- 0.0;
bSentStart     <- false;
bSentEnd       <- false;
HoverCell      <- -1;
bPressedLMF    <- false;
bPressedRMF    <- false;

// ----- Cell layout helpers -----
function CellW() { return GRID_AREA_W / GRID_COLS; }
function CellH() { return GRID_AREA_H / GRID_ROWS; }

function GetDestColor(r)
{
	if ( r == 0 ) return COLOR_DEST_0;
	if ( r == 1 ) return COLOR_DEST_1;
	if ( r == 2 ) return COLOR_DEST_2;
	return COLOR_DEST_3;
}

// ----- Bit helpers -----
function RotateMaskCW(m)  { return ((m << 1) & 15) | ((m >> 3) & 1); }
function RotateMaskCCW(m) { return ((m >> 1) & 15) | ((m << 3) & 15); }
function OppositeDir(d)
{
	if ( d == DIR_UP )    return DIR_DOWN;
	if ( d == DIR_DOWN )  return DIR_UP;
	if ( d == DIR_LEFT )  return DIR_RIGHT;
	if ( d == DIR_RIGHT ) return DIR_LEFT;
	return 0;
}
function ClockwiseDir(d)
{
	if ( d == DIR_UP )    return DIR_RIGHT;
	if ( d == DIR_RIGHT ) return DIR_DOWN;
	if ( d == DIR_DOWN )  return DIR_LEFT;
	if ( d == DIR_LEFT )  return DIR_UP;
	return 0;
}
function CounterClockwiseDir(d)
{
	if ( d == DIR_UP )    return DIR_LEFT;
	if ( d == DIR_LEFT )  return DIR_DOWN;
	if ( d == DIR_DOWN )  return DIR_RIGHT;
	if ( d == DIR_RIGHT ) return DIR_UP;
	return 0;
}
function Has(m, d) { return (m & d) != 0; }

// ----- View / painting helpers -----
function GetDesignView()
{
	local viewW = ScreenHeight().tofloat() * 0.65 * 1024.0 / 768.0;
	local viewH = ScreenHeight().tofloat() * 0.65;
	return [ 0.0, 0.0, viewW, viewH ];
}
function X( view, value ) { return view[0] + value / DESIGN_W * view[2]; }
function Y( view, value ) { return view[1] + value / DESIGN_H * view[3]; }
function PaintColorRect( view, x0, y0, x1, y1, color )
{
	self.PaintRectangle( X( view, x0 ), Y( view, y0 ), X( view, x1 ), Y( view, y1 ),
		color[0], color[1], color[2], color[3] );
}
function PaintColorText( view, x, y, color, text )
{
	self.PaintText( X( view, x ), Y( view, y ),
		color[0], color[1], color[2], color[3], FONT_DEFAULTLARGE, text );
}
function PaintCenteredText( view, cx, cy, color, text )
{
	local w = self.GetTextWide( FONT_DEFAULTLARGE, text );
	local h = self.GetFontTall( FONT_DEFAULTLARGE );
	self.PaintText( X( view, cx ) - w * 0.5, Y( view, cy ) - h * 0.5,
		color[0], color[1], color[2], color[3], FONT_DEFAULTLARGE, text );
}
function TextWideDesign( view, text )
{
	return self.GetTextWide( FONT_DEFAULTLARGE, text ) * DESIGN_W / view[2];
}

// ----- Network generation -----
// Interior pieces are corners only.
//   Corners: 3 (R+D), 6 (D+L), 12 (L+U), 9 (U+R)
//   Straights (currently disabled): 5 (U+D), 10 (L+R)
function RandomInteriorMask()
{
	// if ( RandomInt( 0, 99 ) < 40 )
	// {
	// 	if ( RandomInt( 0, 1 ) == 0 ) return 5;
	// 	return 10;
	// }
	local opts = [ 3, 6, 12, 9 ];
	return opts[ RandomInt( 0, 3 ) ];
}

function InitializeNetwork()
{
	Cells_t = [];
	for ( local r = 0; r < GRID_ROWS; r++ )
	{
		for ( local c = 0; c < GRID_COLS; c++ )
		{
			local mask, canRotate;
			if ( c == 0 ) { mask = DIR_RIGHT; canRotate = false; }
			else if ( c == GRID_COLS - 1 ) { mask = DIR_LEFT; canRotate = false; }
			else
			{
				mask = RandomInteriorMask();
				canRotate = true;
			}
			Cells_t.push({ mask = mask, canRotate = canRotate });
		}
	}
}

// ----- Destination selection (parity-aware) -----
// With corners-only routing, a packet's net vertical displacement is
// always congruent to (GRID_COLS - 2) mod 2:
//   * every horizontal step is immediately followed by a vertical step
//     (corners always turn), so #vertical-steps shares parity with the
//     number of horizontal steps,
//   * reaching col GRID_COLS-1 requires an even number of net rightward
//     moves, which forces the total vertical displacement parity.
// Concretely:
//   GRID_COLS = 5 -> destination row parity DIFFERS from input row.
//   GRID_COLS = 4 -> destination row parity MATCHES  input row.
//   GRID_COLS = 6 -> destination row parity MATCHES  input row.
// Picking a destination with the wrong parity would make the puzzle
// impossible to solve, so ChooseDest only returns reachable rows.
function ChooseDest(r_in)
{
	local pOff = GRID_COLS % 2;   // 1 if odd columns, 0 if even
	local opts = [];
	for ( local r = 0; r < GRID_ROWS; r++ )
		if ( ( r % 2 ) == ( ( r_in + pOff ) % 2 ) )
			opts.push( r );
	if ( opts.len() == 0 ) return r_in;
	return opts[ RandomInt( 0, opts.len() - 1 ) ];
}

// ----- Game start -----
function StartGame()
{
	InitializeNetwork();
	Packets_t = [];
	Delivered = 0;
	Lost = 0;
	Spawned = 0;
	LastTickTime = Time();
	NextSpawnTime = LastTickTime + 1.0;
	Phase = "running";
}

// ----- Packet management -----
function ActiveCount()
{
	local n = 0;
	for ( local i = 0; i < Packets_t.len(); i++ )
		if ( Packets_t[i].state == "flying" ) n++;
	return n;
}
function IsInputBusy(r)
{
	for ( local i = 0; i < Packets_t.len(); i++ )
	{
		local p = Packets_t[i];
		if ( p.state == "flying" && p.r == r && p.c == 0 ) return true;
	}
	return false;
}

function TrySpawn()
{
	if ( ActiveCount() >= MAX_ACTIVE ) return;

	local avail = [];
	for ( local r = 0; r < GRID_ROWS; r++ )
		if ( !IsInputBusy( r ) ) avail.push( r );
	if ( avail.len() == 0 ) return;

	local r_in = avail[ RandomInt( 0, avail.len() - 1 ) ];
	local dest = ChooseDest( r_in );

	Packets_t.push({
		r = r_in, c = 0,
		dir = DIR_RIGHT,
		progress = 0.0,
		dest = dest,
		state = "flying",
		id = Spawned + 1,
		endTime = 0.0,
		holdTime = SPAWN_HOLD_TIME,
	});
	Spawned++;
}

// 2-arm pieces: entering via one arm means exiting via the other.
// moveDir is the direction the packet is currently moving. The
// cell accepted it because it has OppositeDir(moveDir). Exit is
// whichever other arm the piece has.
function ChooseExitDir(mask, moveDir)
{
	if ( Has( mask, moveDir ) ) return moveDir;
	local cw = ClockwiseDir( moveDir );
	if ( Has( mask, cw ) ) return cw;
	local ccw = CounterClockwiseDir( moveDir );
	if ( Has( mask, ccw ) ) return ccw;
	return 0;
}

function AdvancePacket(p)
{
	if ( p.dir == 0 ) { p.state = "lost"; p.endTime = Time(); Lost++; return; }

	local dr = 0, dc = 0;
	if ( p.dir == DIR_UP )         dr = -1;
	else if ( p.dir == DIR_DOWN )  dr =  1;
	else if ( p.dir == DIR_LEFT )  dc = -1;
	else if ( p.dir == DIR_RIGHT ) dc =  1;

	local nr = p.r + dr;
	local nc = p.c + dc;

	if ( nc < 0 || nc >= GRID_COLS || nr < 0 || nr >= GRID_ROWS )
	{
		p.state = "lost"; p.endTime = Time(); p.dir = 0;
		Lost++;
		return;
	}

	p.r = nr; p.c = nc;

	if ( nc == GRID_COLS - 1 )
	{
		if ( nr == p.dest ) { p.state = "delivered"; Delivered++; }
		else                { p.state = "lost";      Lost++; }
		p.endTime = Time();
		p.dir = 0;
		return;
	}

	if ( nc == 0 )
	{
		p.state = "lost"; p.endTime = Time(); p.dir = 0;
		Lost++;
		return;
	}

	local cell = Cells_t[ nr * GRID_COLS + nc ];
	local inDir = OppositeDir( p.dir );
	if ( !Has( cell.mask, inDir ) )
	{
		p.state = "lost"; p.endTime = Time(); p.dir = 0;
		Lost++;
		return;
	}
	local outDir = ChooseExitDir( cell.mask, p.dir );
	if ( outDir == 0 )
	{
		p.state = "lost"; p.endTime = Time(); p.dir = 0;
		Lost++;
		return;
	}
	p.dir = outDir;
}

function UpdatePackets(dt)
{
	for ( local i = 0; i < Packets_t.len(); i++ )
	{
		local p = Packets_t[i];
		if ( p.state != "flying" ) continue;

		// Hold phase: packet sits on its input cell so the player
		// can read its destination before it starts moving.
		if ( p.holdTime > 0 )
		{
			p.holdTime -= dt;
			if ( p.holdTime < 0 ) p.holdTime = 0;
			continue;
		}

		p.progress += dt / STEP_TIME;
		while ( p.progress >= 1.0 && p.state == "flying" )
		{
			p.progress -= 1.0;
			AdvancePacket( p );
		}
	}
}

function PrunePackets()
{
	local now = Time();
	local keep = [];
	for ( local i = 0; i < Packets_t.len(); i++ )
	{
		local p = Packets_t[i];
		if ( p.state == "flying" ) { keep.push( p ); continue; }
		if ( now - p.endTime < LINGER_TIME ) keep.push( p );
	}
	Packets_t = keep;
}

// ----- Game loop -----
function Tick()
{
	if ( Phase != "running" ) return;

	local now = Time();
	local dt = now - LastTickTime;
	if ( dt < 0.0 ) dt = 0.0;
	if ( dt > 0.15 ) dt = 0.15;
	LastTickTime = now;

	UpdatePackets( dt );
	PrunePackets();

	if ( now >= NextSpawnTime )
	{
		TrySpawn();
		NextSpawnTime = now + SPAWN_INTERVAL;
	}

	if ( Delivered >= PACKETS_REQUIRED )
	{
		Phase = "complete";
		if ( !bSentEnd ) { bSentEnd = true; self.SendInput( INPUT_SUCCESS ); }
	}
}

// ----- Packet position -----
function GetPacketPos(p)
{
	local dr = 0, dc = 0;
	if ( p.dir == DIR_UP )         dr = -1;
	else if ( p.dir == DIR_DOWN )  dr =  1;
	else if ( p.dir == DIR_LEFT )  dc = -1;
	else if ( p.dir == DIR_RIGHT ) dc =  1;

	local cw = CellW();
	local ch = CellH();
	local fx = GRID_X + ( p.c + dc * p.progress + 0.5 ) * cw;
	local fy = GRID_Y + ( p.r + dr * p.progress + 0.5 ) * ch;
	return [ fx, fy ];
}

// =========================================================
//  PAINT
// =========================================================
function Paint()
{
	Tick();
	UpdateFromServer();

	local view  = GetDesignView();
	local pulse = ( sin( Time() * 1.2 ) + 1.0 ) * 0.5;

	PaintBackground( view, pulse );
	PaintHeader( view );
	PaintDiagnostics( view );
	PaintLeftPanel( view );
	PaintRightPanel( view );
	PaintNetwork( view, pulse );
	if ( Phase == "complete" ) PaintComplete( view );
}

function PaintBackground( view, pulse )
{
	local left = 0.0, right = DESIGN_W;
	local top = 0.0, bottom = DESIGN_H;

	PaintColorRect( view, left - 16, top + 8, right + 16, bottom + 12, COLOR_BG_SHADOW );
	PaintColorRect( view, left - 8, top, right + 8, bottom, COLOR_BG_FRAME );
	PaintColorRect( view, left - 4, top + 4, right + 4, bottom - 4, COLOR_BG_BEZEL );
	PaintColorRect( view, left, top + 8, right, bottom - 8, COLOR_BG_SCREEN );

	PaintColorRect( view, left, top + 8, right, top + 12, COLOR_BG_EDGE );
	PaintColorRect( view, left, bottom - 12, right, bottom - 8, COLOR_BG_BOTTOM );
	PaintColorRect( view, left, top + 12, left + 5, bottom - 12, COLOR_BG_SIDE );
	PaintColorRect( view, right - 5, top + 12, right, bottom - 12, COLOR_BG_SIDE );

	for ( local x = 80; x <= 1520; x += 80 )
		PaintColorRect( view, x, 82, x + 1, 836, COLOR_BG_GRID );
	for ( local y = 82; y <= 836; y += 27 )
		PaintColorRect( view, 62, y, 1538, y + 1, COLOR_BG_GRID_FAINT );

	PaintColorRect( view, 62, 82, 1538, 84, COLOR_BG_SIDE );
	PaintColorRect( view, 62, 836, 1538, 838, COLOR_BG_SIDE );
	local sweepY = 84.0 + pulse * 744.0;
	PaintColorRect( view, 62, sweepY, 1538, sweepY + 1, COLOR_BG_SWEEP );
}

function PaintHeader( view )
{
	PaintColorText( view, 78, 26, COLOR_HEADER_TEXT, "DATA PACKET ROUTING" );

	local statusText, statusColor;
	if ( Phase == "standby" )       { statusText = "STANDBY";           statusColor = COLOR_HEADER_STATUS; }
	else if ( Phase == "complete" ) { statusText = "TRANSFER COMPLETE"; statusColor = COLOR_WARN_GREEN; }
	else                            { statusText = "ACTIVE";            statusColor = COLOR_HEADER_STATUS; }

	local w = TextWideDesign( view, statusText );
	PaintColorText( view, 1500 - w, 30, statusColor, statusText );

	PaintColorRect( view, 70, 74, 1530, 76, COLOR_BG_EDGE );
}

function PaintDiagnostics( view )
{
	PaintColorText( view, 78, 88, COLOR_SUBTITLE,
		"PROTOCOL: MIL-NET/7    CHANNEL: INTERNAL    ROUTER: 04" );
	PaintColorText( view, 78, 116, COLOR_SUBTITLE,
		"LINK QUALITY: 98.7%    LATENCY: 0.42ms    REMOTE HOST: UNKNOWN" );

	local hexTable = [ "0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F" ];
	local t = ( Time() * 8.0 ).tointeger();
	local line = "";
	for ( local i = 0; i < 30; i++ )
	{
		local idx = ( t + i * 7 ) % 16;
		if ( idx < 0 ) idx += 16;
		line += hexTable[idx];
		if ( i % 2 == 1 ) line += " ";
	}
	PaintColorText( view, 78, 144, COLOR_HEADER_STATUS, line );

	local ledX = 1420.0, ledY = 92.0;
	local litRed    = ( sin( Time() * 2.5 ) > 0.6 );
	local litYellow = ( sin( Time() * 3.7 ) > 0.4 );
	local litGreen  = ( Phase == "running" );

	PaintColorRect( view, ledX,      ledY, ledX + 14, ledY + 14, litRed    ? COLOR_WARN_RED    : [40, 20, 20, 255] );
	PaintColorRect( view, ledX + 22, ledY, ledX + 36, ledY + 14, litYellow ? COLOR_WARN_YELLOW : [40, 36, 12, 255] );
	PaintColorRect( view, ledX + 44, ledY, ledX + 58, ledY + 14, litGreen  ? COLOR_WARN_GREEN  : [20, 40, 26, 255] );
}

function PaintLeftPanel( view )
{
	local px0 = 78, px1 = 296;
	local py0 = 180, py1 = 820;
	PaintColorRect( view, px0, py0, px1, py1, COLOR_PANEL_BG );
	PaintColorRect( view, px0 + 4, py0 + 4, px1 - 4, py1 - 4, COLOR_PANEL_INNER );
	PaintColorRect( view, px0, py0, px1, py0 + 3, COLOR_PANEL_BORDER );
	PaintColorRect( view, px0, py1 - 3, px1, py1, COLOR_PANEL_BORDER );

	PaintColorText( view, px0 + 12, py0 + 12, COLOR_HEADER_TEXT, "IN FLIGHT" );

	local rowY = py0 + 60;
	local rowH = 84;
	local shown = 0;
	for ( local i = 0; i < Packets_t.len(); i++ )
	{
		local p = Packets_t[i];
		if ( p.state != "flying" ) continue;
		if ( rowY + rowH > py1 - 10 ) break;

		local col = GetDestColor( p.dest );
		PaintColorRect( view, px0 + 10, rowY, px0 + 20, rowY + 32, col );
		PaintColorText( view, px0 + 30, rowY - 6, COLOR_HEADER_STATUS, "P" + p.id.tostring() );
		PaintColorText( view, px0 + 30, rowY + 24, col, "SRV-" + p.dest.tostring() );
		rowY += rowH;
		shown++;
	}
	if ( shown == 0 )
		PaintColorText( view, px0 + 12, py0 + 60, COLOR_SUBTITLE, "(idle)" );
}

function PaintRightPanel( view )
{
	local px0 = 1190, px1 = 1582;
	local py0 = 180, py1 = 820;
	PaintColorRect( view, px0, py0, px1, py1, COLOR_PANEL_BG );
	PaintColorRect( view, px0 + 4, py0 + 4, px1 - 4, py1 - 4, COLOR_PANEL_INNER );
	PaintColorRect( view, px0, py0, px1, py0 + 3, COLOR_PANEL_BORDER );
	PaintColorRect( view, px0, py1 - 3, px1, py1, COLOR_PANEL_BORDER );

	PaintColorText( view, px0 + 14, py0 + 14, COLOR_HEADER_TEXT, "NETWORK STATUS" );

	local y = py0 + 66;
	PaintColorText( view, px0 + 14, y, COLOR_SUBTITLE, "REQUIRED" );
	PaintColorText( view, px0 + 14, y + 30, COLOR_HEADER_TEXT, PACKETS_REQUIRED.tostring() );
	y += 70;

	PaintColorText( view, px0 + 14, y, COLOR_SUBTITLE, "DELIVERED" );
	PaintColorText( view, px0 + 14, y + 30, COLOR_WARN_GREEN, Delivered.tostring() );
	y += 70;

	PaintColorText( view, px0 + 14, y, COLOR_SUBTITLE, "DROPPED" );
	PaintColorText( view, px0 + 14, y + 30, COLOR_WARN_RED, Lost.tostring() );
	y += 70;

	PaintColorText( view, px0 + 14, y, COLOR_SUBTITLE, "IN FLIGHT" );
	PaintColorText( view, px0 + 14, y + 30, COLOR_HEADER_STATUS,
		ActiveCount().tostring() + " / " + MAX_ACTIVE.tostring() );
	y += 70;

	PaintColorText( view, px0 + 14, y, COLOR_HEADER_TEXT, "DESTINATIONS" );
	y += 30;
	for ( local r = 0; r < GRID_ROWS; r++ )
	{
		local col = GetDestColor( r );
		PaintColorRect( view, px0 + 14, y + 10, px0 + 26, y + 38, col );
		PaintColorText( view, px0 + 34, y, COLOR_HEADER_STATUS, "SRV-" + r.tostring() );
		y += 30;
	}
}

function PaintNetwork( view, pulse )
{
	local cw = CellW();
	local ch = CellH();

	local gx0 = GRID_X - 12;
	local gy0 = GRID_Y - 12;
	local gx1 = GRID_X + GRID_COLS * cw + 12;
	local gy1 = GRID_Y + GRID_ROWS * ch + 12;

	PaintColorRect( view, gx0, gy0, gx1, gy1, COLOR_PANEL_BG );
	PaintColorRect( view, gx0 + 4, gy0 + 4, gx1 - 4, gy1 - 4, COLOR_PANEL_INNER );
	PaintColorRect( view, gx0, gy0, gx1, gy0 + 3, COLOR_PANEL_BORDER );
	PaintColorRect( view, gx0, gy1 - 3, gx1, gy1, COLOR_PANEL_BORDER );
	PaintColorRect( view, gx0, gy0, gx0 + 3, gy1, COLOR_PANEL_BORDER );
	PaintColorRect( view, gx1 - 3, gy0, gx1, gy1, COLOR_PANEL_BORDER );

	for ( local r = 0; r < GRID_ROWS; r++ )
		for ( local c = 0; c < GRID_COLS; c++ )
		{
			local cx = GRID_X + c * cw;
			local cy = GRID_Y + r * ch;
			PaintCell( view, r, c, cx, cy, cw, ch, ( r * GRID_COLS + c ) == HoverCell );
		}

	for ( local i = 0; i < Packets_t.len(); i++ )
		PaintPacket( view, Packets_t[i], pulse );
}

function PaintCell( view, r, c, cx, cy, cw, ch, hovered )
{
	local isInput  = ( c == 0 );
	local isOutput = ( c == GRID_COLS - 1 );

	local inset = 8.0;
	local x0 = cx + inset;
	local y0 = cy + inset;
	local x1 = cx + cw - inset;
	local y1 = cy + ch - inset;

	local bg = hovered ? COLOR_CELL_BG_HOVER : COLOR_CELL_BG;
	PaintColorRect( view, x0, y0, x1, y1, bg );

	local borderCol = hovered ? COLOR_CELL_EDGE_HOV : COLOR_CELL_EDGE;
	PaintColorRect( view, x0, y0, x1, y0 + 2, borderCol );
	PaintColorRect( view, x0, y1 - 2, x1, y1, borderCol );
	PaintColorRect( view, x0, y0, x0 + 2, y1, borderCol );
	PaintColorRect( view, x1 - 2, y0, x1, y1, borderCol );

	local ccx = ( x0 + x1 ) * 0.5;
	local ccy = ( y0 + y1 ) * 0.5;
	local wt = ( cw < ch ? cw : ch ) * 0.13;
	if ( wt < 10 ) wt = 10;
	if ( wt > 16 ) wt = 16;
	local hw = wt * 0.5;

	local mask = Cells_t[ r * GRID_COLS + c ].mask;

	if ( Has( mask, DIR_UP ) )
		PaintColorRect( view, ccx - hw, y0,      ccx + hw, ccy + hw, COLOR_WIRE );
	if ( Has( mask, DIR_DOWN ) )
		PaintColorRect( view, ccx - hw, ccy - hw, ccx + hw, y1,      COLOR_WIRE );
	if ( Has( mask, DIR_LEFT ) )
		PaintColorRect( view, x0,      ccy - hw, ccx + hw, ccy + hw, COLOR_WIRE );
	if ( Has( mask, DIR_RIGHT ) )
		PaintColorRect( view, ccx - hw, ccy - hw, x1,      ccy + hw, COLOR_WIRE );

	local nsize = 30.0;
	local nh = nsize * 0.5;
	local nodeCol = COLOR_NODE_BG;
	if ( isInput )  nodeCol = COLOR_NODE_IN;
	if ( isOutput ) nodeCol = COLOR_NODE_OUT;
	PaintColorRect( view, ccx - nh, ccy - nh, ccx + nh, ccy + nh, nodeCol );

	if ( isInput )
	{
		local col = GetDestColor( r );
		PaintColorRect( view, x0 - 5, y0, x0 - 1, y1, col );
	}
	if ( isOutput )
	{
		local col = GetDestColor( r );
		PaintColorRect( view, x1 + 1, y0, x1 + 5, y1, col );
	}

	if ( isInput )
	{
		local label = "IN-" + r.tostring();
		PaintCenteredText( view, ccx, cy + 20.0, COLOR_NODE_IN, label );
	}
	if ( isOutput )
	{
		local label = "SRV-" + r.tostring();
		local col = GetDestColor( r );
		PaintCenteredText( view, ccx, cy + 20.0, col, label );
	}
}

function PaintPacket( view, p, pulse )
{
	local pos = GetPacketPos( p );
	local cx = pos[0];
	local cy = pos[1];

	local col;
	local fill;
	if ( p.state == "delivered" ) { fill = COLOR_WARN_GREEN; col = COLOR_WARN_GREEN; }
	else if ( p.state == "lost" ) { fill = COLOR_WARN_RED;   col = COLOR_WARN_RED; }
	else
	{
		fill = [ 235, 250, 250, 255 ];
		col  = GetDestColor( p.dest );
	}

	local size = 34.0;
	local borderT = 4.0;
	if ( p.state == "flying" )
	{
		if ( p.holdTime > 0 )
		{
			// Held on its input cell: pulse bigger so the player notices.
			size = 42.0 + pulse * 10.0;
			borderT = 5.0;
		}
		else
		{
			size = 34.0 + pulse * 5.0;
		}
	}

	local h = size * 0.5;
	PaintColorRect( view, cx - h, cy - h, cx + h, cy + h, fill );
	PaintColorRect( view, cx - h, cy - h, cx + h, cy - h + borderT, col );
	PaintColorRect( view, cx - h, cy + h - borderT, cx + h, cy + h, col );
	PaintColorRect( view, cx - h, cy - h, cx - h + borderT, cy + h, col );
	PaintColorRect( view, cx + h - borderT, cy - h, cx + h, cy + h, col );
	local dh = 5.0;
	PaintColorRect( view, cx - dh, cy - dh, cx + dh, cy + dh, col );
}

function PaintComplete( view )
{
	local x0 = 400, x1 = 1200, y0 = 90, y1 = 176;
	PaintColorRect( view, x0, y0, x1, y1, [ 8, 45, 42, 250 ] );
	PaintColorRect( view, x0, y0, x1, y0 + 3, COLOR_WARN_GREEN );
	PaintColorRect( view, x0, y1 - 3, x1, y1, COLOR_WARN_GREEN );
	PaintCenteredText( view, ( x0 + x1 ) * 0.5, y0 + 26, COLOR_HEADER_TEXT, "DATA TRANSFER COMPLETE" );
	PaintCenteredText( view, ( x0 + x1 ) * 0.5, y0 + 62, COLOR_HEADER_STATUS, "NETWORK ACCESS ESTABLISHED" );
}

// ----- Server sync -----
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
		local insideView = ( mx >= view[0] + 12.0 && mx <= view[0] + view[2] - 12.0 &&
		                     my >= view[1] + 12.0 && my <= view[1] + view[3] - 12.0 );
		if ( insideView )
		{
			bSentStart = true;
			StartGame();
			self.SendInput( INPUT_START );
		}
	}

	local newHover = -1;
	if ( designX >= GRID_X && designX < GRID_X + GRID_COLS * CellW() &&
	     designY >= GRID_Y && designY < GRID_Y + GRID_ROWS * CellH() )
	{
		local c = ( ( designX - GRID_X ) / CellW() ).tointeger();
		local r = ( ( designY - GRID_Y ) / CellH() ).tointeger();
		if ( c >= 0 && c < GRID_COLS && r >= 0 && r < GRID_ROWS )
		{
			local idx = r * GRID_COLS + c;
			if ( idx < Cells_t.len() && Cells_t[idx].canRotate )
				newHover = idx;
		}
	}
	HoverCell = newHover;

	local lmbDown = false, rmbDown = false;
	if ( "mouse_left"  in table && table["mouse_left"]  ) lmbDown = true;
	if ( "mouse_right" in table && table["mouse_right"] ) rmbDown = true;

	if ( !lmbDown ) bPressedLMF = false;
	if ( !rmbDown ) bPressedRMF = false;

	if ( Phase != "running" ) return;
	if ( HoverCell < 0 ) return;

	if ( lmbDown && !bPressedLMF )
	{
		bPressedLMF = true;
		Cells_t[ HoverCell ].mask = RotateMaskCW( Cells_t[ HoverCell ].mask );
	}
	if ( rmbDown && !bPressedRMF )
	{
		bPressedRMF = true;
		Cells_t[ HoverCell ].mask = RotateMaskCCW( Cells_t[ HoverCell ].mask );
	}
}