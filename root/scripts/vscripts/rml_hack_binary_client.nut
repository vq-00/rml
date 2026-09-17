// =========================================================
//  BINARY PULSE SEQUENCER -- CLIENT
//  Target sequence is fixed. Player applies operations to
//  make CURRENT match TARGET. All operations are reversible
//  in spirit; RESET restores the starting state.
// =========================================================
FONT_DEFAULTLARGE <- self.LookupFont("DefaultLarge");
FONT_SMALL        <- self.LookupFont("DefaultSmall");

bDebugLog <- false;

const DESIGN_W = 1600.0;
const DESIGN_H = 900.0;

const INPUT_START   = 1;
const INPUT_SUCCESS = 2;

// ----- Difficulty: 0 = EASY, 1 = NORMAL, 2 = HARD -----
const DIFFICULTY = 2;

BIT_COUNT    <- 8;
SOLUTION_LEN <- 3;

if ( DIFFICULTY == 0 )      { BIT_COUNT = 5;  SOLUTION_LEN = 2; }
else if ( DIFFICULTY == 2 ) { BIT_COUNT = 16; SOLUTION_LEN = 5; }

// Operation codes -- values must match the display order in OP_NAMES
const OP_SHIFT_L = 0;
const OP_SHIFT_R = 1;
const OP_INVERT  = 2;
const OP_ROT_L   = 3;
const OP_ROT_R   = 4;
const OP_REVERSE = 5;

OP_NAMES <- [ "SHIFT L", "SHIFT R", "INVERT", "ROTATE L", "ROTATE R", "REVERSE" ];

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
COLOR_HEADER_DIM    <- [  70, 110, 120, 255 ];

COLOR_PANEL_BG      <- [   5,  13,  21, 245 ];
COLOR_PANEL_INNER   <- [  12,  30,  38, 255 ];
COLOR_PANEL_BORDER  <- [  61, 163, 157, 200 ];

COLOR_BIT_ONE       <- [ 180, 255, 240, 255 ];
COLOR_BIT_ZERO      <- [  80, 120, 130, 255 ];
COLOR_BIT_BG_HI     <- [  28,  65,  75, 255 ];
COLOR_BIT_BG_LO     <- [  12,  28,  34, 255 ];
COLOR_BIT_BG_HOVER  <- [  42,  90, 105, 255 ];

COLOR_OP_BG          <- [  18,  40,  52, 255 ];
COLOR_OP_BG_HOV      <- [  36,  80, 100, 255 ];
COLOR_OP_BORDER      <- [  60, 110, 125, 255 ];
COLOR_OP_BORDER_HOV  <- [ 104, 241, 220, 255 ];

COLOR_RESET_BG       <- [  90,  32,  32, 255 ];   // was [60,24,24]
COLOR_RESET_BG_HOV   <- [ 140,  55,  55, 255 ];   // was [110,45,45]
COLOR_RESET_BORDER   <- [ 220,  90,  90, 255 ];   // was [180,70,70]
COLOR_RESET_BORDER_HOV <- [ 240, 100,  90, 255 ];

COLOR_WARN_YELLOW   <- [ 240, 200,  80, 255 ];
COLOR_WARN_RED      <- [ 222,  67,  61, 255 ];
COLOR_WARN_GREEN    <- [  83, 220, 150, 255 ];

// ----- State -----
Phase          <- "standby";
Target_t       <- [];
Start_t        <- [];
Current_t      <- [];
History_t      <- [];   // array of { op, idx }

HoverOp        <- -1;
HoverBit       <- -1;
bHoverReset    <- false;
bPressedLMB    <- false;
bSentStart     <- false;
bSentEnd       <- false;
LastTickTime   <- 0.0;
GlobalTime     <- 0.0;
LastActionTime <- 0.0;
DebugLastLog   <- 0.0;

// ----- Layout -----
const LEFT_X0 = 60.0;
const LEFT_X1 = 1540.0;
const RIGHT_X0 = 1080.0;
const RIGHT_X1 = 1540.0;

const BIT_GAP = 14.0;
const BIT_H   = 70.0;

// Computed at StartRun (or first Paint).
CellW        <- 60.0;
BitRowX0     <- 520.0;
BitRowTotalW <- 0.0;

// Op button rects
OpRects_t <- [];

ResetBtn <- [ 400.0, 745.0, 1200.0, 825.0 ];

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

function PaintSmallText( v, x, y, c, s )
{
	self.PaintText( X(v,x), Y(v,y), c[0],c[1],c[2],c[3], FONT_SMALL, s );
}
function PaintSmallCenteredText( v, cx, cy, c, s )
{
	local w = self.GetTextWide( FONT_SMALL, s );
	local h = self.GetFontTall( FONT_SMALL );
	self.PaintText( X(v,cx) - w*0.5, Y(v,cy) - h*0.5, c[0],c[1],c[2],c[3], FONT_SMALL, s );
}
function SmallTextWideDesign( v, s ) { return self.GetTextWide(FONT_SMALL,s) * DESIGN_W / v[2]; }

function PointInRect( px, py, x0, y0, x1, y1 )
{
	return px >= x0 && px <= x1 && py >= y0 && py <= y1;
}

// =========================================================
//  SEQUENCE OPERATIONS
// =========================================================
function OpShiftL( seq )
{
	local n = seq.len();
	local out = [];
	for ( local i = 1; i < n; i++ ) out.push( seq[i] );
	out.push( 0 );
	return out;
}
function OpShiftR( seq )
{
	local n = seq.len();
	local out = [ 0 ];
	for ( local i = 0; i < n-1; i++ ) out.push( seq[i] );
	return out;
}
function OpRotL( seq )
{
	local n = seq.len();
	local out = [];
	for ( local i = 1; i < n; i++ ) out.push( seq[i] );
	out.push( seq[0] );
	return out;
}
function OpRotR( seq )
{
	local n = seq.len();
	local out = [ seq[n-1] ];
	for ( local i = 0; i < n-1; i++ ) out.push( seq[i] );
	return out;
}
function OpInvert( seq )
{
	local out = [];
	for ( local i = 0; i < seq.len(); i++ ) out.push( 1 - seq[i] );
	return out;
}
function OpReverse( seq )
{
	local n = seq.len();
	local out = [];
	for ( local i = 0; i < n; i++ ) out.push( seq[n-1-i] );
	return out;
}

function ApplyOp( seq, op )
{
	if ( op == OP_SHIFT_L ) return OpShiftL( seq );
	if ( op == OP_SHIFT_R ) return OpShiftR( seq );
	if ( op == OP_INVERT )  return OpInvert( seq );
	if ( op == OP_ROT_L )   return OpRotL( seq );
	if ( op == OP_ROT_R )   return OpRotR( seq );
	if ( op == OP_REVERSE ) return OpReverse( seq );
	return seq;
}

function ToggleBit( seq, idx )
{
	local out = [];
	for ( local i = 0; i < seq.len(); i++ ) out.push( seq[i] );
	out[idx] = 1 - out[idx];
	return out;
}

function SequencesEqual( a, b )
{
	if ( a.len() != b.len() ) return false;
	for ( local i = 0; i < a.len(); i++ )
		if ( a[i] != b[i] ) return false;
	return true;
}

// =========================================================
//  PUZZLE GENERATION
// =========================================================
function GeneratePuzzle()
{
	local tries = 0;
	while ( tries < 80 )
	{
		tries++;

		// 1. Random target.
		local target = [];
		for ( local i = 0; i < BIT_COUNT; i++ ) target.push( RandomInt( 0, 1 ) );

		// 2. Random solution built from bijective ops only.
		local bijective = [ OP_ROT_L, OP_ROT_R, OP_INVERT, OP_REVERSE ];
		local solution = [];
		for ( local i = 0; i < SOLUTION_LEN; i++ )
			solution.push( bijective[ RandomInt( 0, bijective.len()-1 ) ] );

		// 3. Work backwards from target applying inverses.
		local start = [];
		for ( local i = 0; i < BIT_COUNT; i++ ) start.push( target[i] );

		for ( local i = solution.len() - 1; i >= 0; i-- )
		{
			local op = solution[i];
			if ( op == OP_ROT_L )      start = ApplyOp( start, OP_ROT_R );
			else if ( op == OP_ROT_R ) start = ApplyOp( start, OP_ROT_L );
			else                       start = ApplyOp( start, op );
		}

		if ( SequencesEqual( start, target ) ) continue;

		Target_t = target;
		Start_t = start;
		Current_t = [];
		for ( local i = 0; i < BIT_COUNT; i++ ) Current_t.push( start[i] );
		History_t = [];
		return;
	}

	// Fallback: near-impossible to hit.
	Target_t = [];
	for ( local i = 0; i < BIT_COUNT; i++ ) Target_t.push( RandomInt( 0, 1 ) );
	Start_t = OpInvert( Target_t );
	Current_t = [];
	for ( local i = 0; i < BIT_COUNT; i++ ) Current_t.push( Start_t[i] );
	History_t = [];
}

// =========================================================
//  LAYOUT
// =========================================================
function ComputeLayout()
{
	local availW = 1080.0;
	local totalGap = (BIT_COUNT - 1) * BIT_GAP;
	CellW = (availW - totalGap) / BIT_COUNT;
	BitRowTotalW = BIT_COUNT * CellW + (BIT_COUNT - 1) * BIT_GAP;
	BitRowX0 = 260.0;   // fixed start; row is exactly availW wide

    // Op button rects: 3 columns, 2 rows, centered in the panel.
	// Panel spans LEFT_X0..LEFT_X1 = 60..1540, so center = 800.
	// 3 * 300 + 2 * 40 = 980 wide -> start at 800 - 490 = 310.
	OpRects_t = [];
	local colX = [ 310.0, 650.0, 990.0 ];
	local rowY = [ 490.0, 595.0 ];
	local bw = 300.0;
	local bh = 80.0;
	for ( local r = 0; r < 2; r++ )
	{
		for ( local c = 0; c < 3; c++ )
		{
			local bx = colX[c];
			local by = rowY[r];
			OpRects_t.push( [ bx, by, bx + bw, by + bh ] );
		}
	}
}

// =========================================================
//  WAVE / RUN
// =========================================================
function StartRun()
{
	ComputeLayout();
	GeneratePuzzle();
	Phase = "running";
	LastActionTime = Time();
}

function DoReset()
{
	Current_t = [];
	for ( local i = 0; i < BIT_COUNT; i++ ) Current_t.push( Start_t[i] );
	History_t = [];
	LastActionTime = Time();
}

function DoApplyOp( op )
{
	Current_t = ApplyOp( Current_t, op );
	History_t.push( { op = op, idx = -1 } );
	LastActionTime = Time();
}

function DoToggleBit( idx )
{
	Current_t = ToggleBit( Current_t, idx );
	History_t.push( { op = -1, idx = idx } );
	LastActionTime = Time();
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

	UpdateFromServer();

	if ( Phase == "running" && SequencesEqual( Current_t, Target_t ) )
	{
		Phase = "complete";
		if ( !bSentEnd ) { bSentEnd = true; self.SendInput( INPUT_SUCCESS ); }
	}

	if ( bDebugLog && now - DebugLastLog > 1.0 )
	{
		DebugLastLog = now;
		Msg( "binary pkt: [" + self.GetString(0) + "] phase=" + Phase );
	}

	local view  = GetDesignView();
	local pulse = ( sin( Time() * 1.2 ) + 1.0 ) * 0.5;

	PaintBackground( view, pulse );
	PaintHeader( view );
	PaintTargetPanel( view );
	PaintCurrentPanel( view, pulse );
	PaintOpsPanel( view );
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
	PaintColorText( v, 78, 26, COLOR_HEADER_TEXT, "BINARY PULSE SEQUENCER" );

	local statusText, statusColor;
	if ( Phase == "standby" )       { statusText = "STANDBY";     statusColor = COLOR_HEADER_STATUS; }
	else if ( Phase == "complete" ) { statusText = "SEQUENCE MATCH"; statusColor = COLOR_WARN_GREEN; }
	else                            { statusText = "SEQUENCING";  statusColor = COLOR_WARN_YELLOW; }

	local w = TextWideDesign( v, statusText );
	PaintColorText( v, 1500 - w, 30, statusColor, statusText );

	PaintColorRect( v, 70, 74, 1530, 76, COLOR_BG_EDGE );
}

// ----- Bits → hex string -----
function BitsToHex( bits )
{
	local n = bits.len();
	local pad = ( 4 - ( n % 4 ) ) % 4;
	local padded = [];
	for ( local i = 0; i < pad; i++ ) padded.push( 0 );
	for ( local i = 0; i < n; i++ ) padded.push( bits[i] );

	local hexChars = "0123456789ABCDEF";
	local out = "";
	for ( local i = 0; i < padded.len(); i += 4 )
	{
		local nib = padded[i]*8 + padded[i+1]*4 + padded[i+2]*2 + padded[i+3];
		out += hexChars[nib].tochar();
	}
	return "0x" + out;
}

// ----- Target panel -----
function PaintTargetPanel( v )
{
	PaintColorRect( v, LEFT_X0, 90, LEFT_X1, 220, COLOR_PANEL_BG );
	PaintColorRect( v, LEFT_X0+4, 94, LEFT_X1-4, 216, COLOR_PANEL_INNER );
	PaintColorRect( v, LEFT_X0, 90, LEFT_X1, 93, COLOR_PANEL_BORDER );
	PaintColorRect( v, LEFT_X0, 217, LEFT_X1, 220, COLOR_PANEL_BORDER );

	PaintColorText( v, LEFT_X0+22, 102, COLOR_HEADER_TEXT, "TARGET" );

	local hexStr = BitsToHex( Target_t );
	local hexW = TextWideDesign( v, hexStr );
	PaintColorText( v, LEFT_X1 - 22 - hexW, 102, COLOR_HEADER_STATUS, hexStr );

	PaintBitRow( v, Target_t, BitRowX0, 140, false, -1, -1 );
}

// ----- Current panel -----
function PaintCurrentPanel( v, pulse )
{
	PaintColorRect( v, LEFT_X0, 230, LEFT_X1, 410, COLOR_PANEL_BG );
	PaintColorRect( v, LEFT_X0+4, 234, LEFT_X1-4, 406, COLOR_PANEL_INNER );
	PaintColorRect( v, LEFT_X0, 230, LEFT_X1, 233, COLOR_PANEL_BORDER );
	PaintColorRect( v, LEFT_X0, 407, LEFT_X1, 410, COLOR_PANEL_BORDER );

	PaintColorText( v, LEFT_X0+22, 242, COLOR_HEADER_TEXT, "CURRENT" );

	local hexStr = BitsToHex( Current_t );
	local hexW = TextWideDesign( v, hexStr );
	local hexCol = SequencesEqual( Current_t, Target_t ) ? COLOR_WARN_GREEN : COLOR_HEADER_STATUS;
	PaintColorText( v, LEFT_X1 - 22 - hexW, 242, hexCol, hexStr );

	// Bit index labels
	for ( local i = 0; i < BIT_COUNT; i++ )
	{
		local cx = BitRowX0 + i * (CellW + BIT_GAP) + CellW*0.5;
		PaintSmallCenteredText( v, cx, 280, COLOR_HEADER_DIM, i.tostring() );
	}

	// Flash on recent action (whole row tint)
	local flashAge = Time() - LastActionTime;
	local flashAmt = 0.0;
	if ( flashAge >= 0.0 && flashAge < 0.25 ) flashAmt = 1.0 - flashAge / 0.25;

	PaintBitRow( v, Current_t, BitRowX0, 290, true, HoverBit, flashAmt );

	PaintSmallText( v, LEFT_X0+22, 378, COLOR_HEADER_DIM,
		"CLICK ANY BIT TO TOGGLE IT. USE OPERATIONS BELOW TO TRANSFORM THE WHOLE ROW." );
}

function PaintBitRow( v, bits, x0, y0, interactive, hoverIdx, flashAmt )
{
	if ( flashAmt == null ) flashAmt = 0.0;
	for ( local i = 0; i < bits.len(); i++ )
	{
		local bx = x0 + i * (CellW + BIT_GAP);
		local bx1 = bx + CellW;
		local by = y0;
		local by1 = by + BIT_H;

		local bit = bits[i];
		local hovered = interactive && (hoverIdx == i);

		// Background
		local bg;
		if ( bit == 1 ) bg = interactive ? COLOR_BIT_BG_HI : [ 22, 50, 60, 255 ];
		else            bg = interactive ? COLOR_BIT_BG_LO : [ 12, 26, 32, 255 ];
		if ( hovered ) bg = COLOR_BIT_BG_HOVER;
		if ( flashAmt > 0.0 )
		{
			bg = [ bg[0] + 20 * flashAmt, bg[1] + 40 * flashAmt, bg[2] + 30 * flashAmt, 255 ];
		}
		PaintColorRect( v, bx, by, bx1, by1, bg );

		// Border
		local bc = COLOR_PANEL_BORDER;
		if ( interactive ) bc = [ 80, 140, 150, 255 ];
		if ( hovered ) bc = COLOR_HEADER_TEXT;
		PaintColorRect( v, bx, by, bx1, by+2, bc );
		PaintColorRect( v, bx, by1-2, bx1, by1, bc );
		PaintColorRect( v, bx, by, bx+2, by1, bc );
		PaintColorRect( v, bx1-2, by, bx1, by1, bc );

		// Digit
		local digit = ( bit == 1 ) ? "1" : "0";
		local col;
		if ( bit == 1 )
			col = hovered ? [ 220, 255, 250, 255 ] : COLOR_BIT_ONE;
		else
			col = hovered ? [ 160, 210, 220, 255 ] : COLOR_BIT_ZERO;

		PaintCenteredText( v, (bx+bx1)*0.5, (by+by1)*0.5, col, digit );
	}
}

// ----- Operations -----
function PaintOpsPanel( v )
{
	PaintColorRect( v, LEFT_X0, 430, LEFT_X1, 720, COLOR_PANEL_BG );
	PaintColorRect( v, LEFT_X0+4, 434, LEFT_X1-4, 716, COLOR_PANEL_INNER );
	PaintColorRect( v, LEFT_X0, 430, LEFT_X1, 433, COLOR_PANEL_BORDER );
	PaintColorRect( v, LEFT_X0, 717, LEFT_X1, 720, COLOR_PANEL_BORDER );

	PaintColorText( v, LEFT_X0+22, 442, COLOR_HEADER_TEXT, "OPERATIONS" );

	for ( local i = 0; i < OpRects_t.len(); i++ )
	{
		local r = OpRects_t[i];
		local hovered = ( HoverOp == i );
		local bg = hovered ? COLOR_OP_BG_HOV : COLOR_OP_BG;
		PaintColorRect( v, r[0], r[1], r[2], r[3], bg );

		local bc = hovered ? COLOR_OP_BORDER_HOV : COLOR_OP_BORDER;
		PaintColorRect( v, r[0], r[1], r[2], r[1]+2, bc );
		PaintColorRect( v, r[0], r[3]-2, r[2], r[3], bc );
		PaintColorRect( v, r[0], r[1], r[0]+2, r[3], bc );
		PaintColorRect( v, r[2]-2, r[1], r[2], r[3], bc );

		local label = OP_NAMES[i];
		local col = hovered ? COLOR_HEADER_TEXT : [ 180, 220, 220, 255 ];
		PaintCenteredText( v, (r[0]+r[2])*0.5, (r[1]+r[3])*0.5, col, label );
	}

	// Reset button (distinct styling)
	local resetHov = bHoverReset;
	local rbg = resetHov ? COLOR_RESET_BG_HOV : COLOR_RESET_BG;
	PaintColorRect( v, ResetBtn[0], ResetBtn[1], ResetBtn[2], ResetBtn[3], rbg );
	local rbc = resetHov ? COLOR_RESET_BORDER_HOV : COLOR_RESET_BORDER;
	PaintColorRect( v, ResetBtn[0], ResetBtn[1], ResetBtn[2], ResetBtn[1]+2, rbc );
	PaintColorRect( v, ResetBtn[0], ResetBtn[3]-2, ResetBtn[2], ResetBtn[3], rbc );
	PaintColorRect( v, ResetBtn[0], ResetBtn[1], ResetBtn[0]+2, ResetBtn[3], rbc );
	PaintColorRect( v, ResetBtn[2]-2, ResetBtn[1], ResetBtn[2], ResetBtn[3], rbc );
	PaintCenteredText( v, (ResetBtn[0]+ResetBtn[2])*0.5, (ResetBtn[1]+ResetBtn[3])*0.5,
		[ 255, 200, 200, 255 ], "RESET SEQUENCE" );
}

// ----- Success banner -----
function PaintComplete( v )
{
	local x0 = 300, x1 = 1300, y0 = 90, y1 = 176;
	PaintColorRect( v, x0, y0, x1, y1, [ 8, 45, 42, 250 ] );
	PaintColorRect( v, x0, y0, x1, y0+3, COLOR_WARN_GREEN );
	PaintColorRect( v, x0, y1-3, x1, y1, COLOR_WARN_GREEN );
	PaintCenteredText( v, (x0+x1)*0.5, y0+26, COLOR_HEADER_TEXT, "SEQUENCE MATCH" );
	PaintCenteredText( v, (x0+x1)*0.5, y0+62, COLOR_HEADER_STATUS, "PROTOCOL ACCEPTED" );
}

// =========================================================
//  INPUT
// =========================================================
function Control( table )
{
	local view = GetDesignView();
	local mx = 0.0, my = 0.0;
	if ( "mouse_x" in table ) mx = table["mouse_x"].tofloat();
	if ( "mouse_y" in table ) my = table["mouse_y"].tofloat();

	local dx = (mx - view[0]) / view[2] * DESIGN_W;
	local dy = (my - view[1]) / view[3] * DESIGN_H;

	if ( !bSentStart )
	{
		local inside = ( mx >= view[0]+12 && mx <= view[0]+view[2]-12 &&
		                 my >= view[1]+12 && my <= view[1]+view[3]-12 );
		if ( inside )
		{
			bSentStart = true;
			StartRun();
			LastTickTime = Time();
			self.SendInput( INPUT_START );
		}
	}

	// Hover: operations
	local newHoverOp = -1;
	for ( local i = 0; i < OpRects_t.len(); i++ )
	{
		local r = OpRects_t[i];
		if ( PointInRect( dx, dy, r[0], r[1], r[2], r[3] ) ) { newHoverOp = i; break; }
	}
	HoverOp = newHoverOp;

	// Hover: reset
	bHoverReset = PointInRect( dx, dy, ResetBtn[0], ResetBtn[1], ResetBtn[2], ResetBtn[3] );

	// Hover: current-row bits
	local newHoverBit = -1;
	for ( local i = 0; i < BIT_COUNT; i++ )
	{
		local bx = BitRowX0 + i * (CellW + BIT_GAP);
		if ( PointInRect( dx, dy, bx, 290, bx + CellW, 290 + BIT_H ) )
		{ newHoverBit = i; break; }
	}
	HoverBit = newHoverBit;

	local lmb = false;
	if ( "mouse_left" in table && table["mouse_left"] ) lmb = true;
	if ( !lmb ) { bPressedLMB = false; return; }
	if ( bPressedLMB ) return;
	bPressedLMB = true;

	if ( Phase != "running" ) return;

	if ( bHoverReset ) { DoReset(); return; }
	if ( HoverOp >= 0 ) { DoApplyOp( HoverOp ); return; }
	if ( HoverBit >= 0 ) { DoToggleBit( HoverBit ); return; }
}

// =========================================================
//  INIT
// =========================================================
ComputeLayout();
LastTickTime <- Time();
GlobalTime <- LastTickTime;
DebugLastLog <- 0.0;