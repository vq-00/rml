// =========================================================
//  SECURITY HANDSHAKE -- CLIENT
//  Client is authoritative for the game loop.
//  No attempts limit, no overall timer.
// =========================================================
FONT_DEFAULTLARGE <- self.LookupFont("DefaultLarge");

// ----- Design space -----
const DESIGN_W = 1600.0;
const DESIGN_H = 900.0;

// ----- Layout landmarks -----
const CENTER_Y0 = 200.0;
const CENTER_Y1 = 440.0;
const RECON_Y0  = 460.0;
const RECON_Y1  = 550.0;
const KEYPAD_Y0 = 570.0;

const BTN_W = 200.0;
const BTN_H = 110.0;
const BTN_GAP = 12.0;

// ----- Game constants -----
const TRANSMIT_TIME = 2.5;
const VERIFY_TIME   = 1.5;

const SEQ_LENGTH   = 5;
const SYMBOL_COUNT = 8;

// Input codes sent to the server.
const INPUT_START   = 1;
const INPUT_SUCCESS = 2;
const INPUT_FAILURE = 3;

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

COLOR_SYMBOL_ON     <- [ 104, 241, 220, 255 ];
COLOR_SYMBOL_DIM    <- [ 140, 200, 205, 230 ];
COLOR_SYMBOL_EMPTY  <- [  46,  80,  90, 255 ];
COLOR_SYMBOL_ERR    <- [ 240, 100,  90, 255 ];

COLOR_BTN_BG        <- [  10,  26,  34, 255 ];
COLOR_BTN_BG_HOVER  <- [  22,  62,  76, 255 ];
COLOR_BTN_BORDER    <- [  30,  70,  80, 255 ];
COLOR_BTN_BORDER_H  <- [  94, 214, 222, 255 ];
COLOR_BTN_SHADOW    <- [   0,   0,   0, 140 ];

COLOR_WARN_YELLOW   <- [ 240, 200,  80, 255 ];
COLOR_WARN_RED      <- [ 222,  67,  61, 255 ];
COLOR_WARN_GREEN    <- [  83, 220, 150, 255 ];

// ----- State -----
Phase          <- "standby";
Sequence_t     <- [];
Entered_t      <- [];
PhaseStartTime <- 0.0;
bSentStart     <- false;
bSentEnd       <- false;
HoverBtn       <- -1;
bPressedLastFrame <- false;

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

// ----- Symbol drawing -----
function DrawSymbol( view, cx, cy, size, sym, col )
{
	local h  = size * 0.5;
	local x0 = cx - h;
	local y0 = cy - h;
	local x1 = cx + h;
	local y1 = cy + h;
	local t  = size * 0.14;

	if ( sym == 0 )
	{
		PaintColorRect( view, cx - t*0.5, y0, cx + t*0.5, y1, col );
		PaintColorRect( view, x0, cy - t*0.5, x1, cy + t*0.5, col );
	}
	else if ( sym == 1 )
	{
		PaintColorRect( view, x0, y0, x1, y0+t, col );
		PaintColorRect( view, x0, y1-t, x1, y1, col );
		PaintColorRect( view, x0, y0+t, x0+t, y1-t, col );
		PaintColorRect( view, x1-t, y0+t, x1, y1-t, col );
	}
	else if ( sym == 2 )
	{
		local steps = 10;
		local sh = size / steps.tofloat();
		for ( local i = 0; i < steps; i++ )
		{
			local frac = i.tofloat() / ( steps - 1 );
			local w = h * frac;
			local yy = y0 + i * sh;
			PaintColorRect( view, cx - w, yy, cx + w, yy + sh + 1.0, col );
		}
	}
	else if ( sym == 3 )
	{
		local steps = 10;
		local sh = size / steps.tofloat();
		local half = ( steps - 1 ) * 0.5;
		for ( local i = 0; i < steps; i++ )
		{
			local frac;
			if ( i <= half ) frac = i / half;
			else frac = ( steps - 1 - i ) / half;
			local w = h * frac;
			local yy = y0 + i * sh;
			PaintColorRect( view, cx - w, yy, cx + w, yy + sh + 1.0, col );
		}
	}
	else if ( sym == 4 )
	{
		PaintColorRect( view, x0, y0, x1, y0+t, col );
		PaintColorRect( view, x0, y1-t, x1, y1, col );
		PaintColorRect( view, x0, y0+t, x0+t, y1-t, col );
		PaintColorRect( view, x1-t, y0+t, x1, y1-t, col );
		local inner = size * 0.22;
		PaintColorRect( view, cx - inner, cy - inner, cx + inner, cy + inner, col );
	}
	else if ( sym == 5 )
	{
		local bw = size * 0.16;
		local gap = ( size - 3 * bw ) / 4.0;
		for ( local i = 0; i < 3; i++ )
		{
			local bx = x0 + gap + i * ( bw + gap );
			PaintColorRect( view, bx, y0, bx + bw, y1, col );
		}
	}
	else if ( sym == 6 )
	{
		local ds = size * 0.3;
		local gap = ( size - 2 * ds ) / 3.0;
		for ( local r = 0; r < 2; r++ )
			for ( local c = 0; c < 2; c++ )
			{
				local bx = x0 + gap + c * ( ds + gap );
				local by = y0 + gap + r * ( ds + gap );
				PaintColorRect( view, bx, by, bx + ds, by + ds, col );
			}
	}
	else if ( sym == 7 )
	{
		PaintColorRect( view, cx - t*0.5, y0 + size*0.35, cx + t*0.5, y1, col );
		local headTop = y0;
		local headBottom = y0 + size * 0.4;
		local steps = 8;
		local sh = ( headBottom - headTop ) / steps.tofloat();
		for ( local i = 0; i < steps; i++ )
		{
			local frac = i.tofloat() / ( steps - 1 );
			local w = h * 0.8 * frac;
			local yy = headTop + i * sh;
			PaintColorRect( view, cx - w, yy, cx + w, yy + sh + 1.0, col );
		}
	}
	else if ( sym == 8 )
	{
		local n = 6;
		local sh = size / n.tofloat();
		for ( local i = 0; i < n; i++ )
		{
			local yy = y0 + i * sh;
			local offX;
			if ( i % 2 == 0 ) offX = -size * 0.15;
			else              offX =  size * 0.15;
			PaintColorRect( view, cx - size*0.35 + offX, yy + 1,
				cx + size*0.35 + offX, yy + sh - 1, col );
		}
	}
	else if ( sym == 9 )
	{
		PaintColorRect( view, x0 + size*0.22, y0,     x1 - size*0.22, y0 + t, col );
		PaintColorRect( view, x0 + size*0.22, y1 - t, x1 - size*0.22, y1,     col );
		PaintColorRect( view, x0, y0 + size*0.22, x0 + t, cy, col );
		PaintColorRect( view, x0, cy,             x0 + t, y1 - size*0.22, col );
		PaintColorRect( view, x1 - t, y0 + size*0.22, x1, cy, col );
		PaintColorRect( view, x1 - t, cy,             x1, y1 - size*0.22, col );
	}
	else if ( sym == 10 )
	{
		PaintColorRect( view, x0 + size*0.18, y0,
			x0 + size*0.18 + t*1.5, y1 - size*0.1, col );
		PaintColorRect( view, x0 + size*0.18, y1 - size*0.1 - t*1.5,
			x1 - size*0.1, y1 - size*0.1, col );
	}
	else
	{
		local segs = 4;
		local sh = size / segs.tofloat();
		for ( local i = 0; i < segs; i++ )
		{
			local yy = y0 + i * sh;
			PaintColorRect( view, cx - h*0.8, yy + 1.5, cx + h*0.8, yy + sh - 2.5, col );
		}
	}
}

// ----- Keypad layout -----
function GetKeypadCols()
{
	local cols = ( SYMBOL_COUNT + 1 ) / 2;
	if ( cols < 4 ) cols = 4;
	return cols;
}
function GetBtnRect( i )
{
	local cols = GetKeypadCols();
	local totalW = cols * BTN_W + ( cols - 1 ) * BTN_GAP;
	local startX = ( DESIGN_W - totalW ) * 0.5;
	local c = i % cols;
	local r = ( i / cols ).tointeger();
	local bx = startX + c * ( BTN_W + BTN_GAP );
	local by = KEYPAD_Y0 + r * ( BTN_H + BTN_GAP );
	return [ bx, by, bx + BTN_W, by + BTN_H ];
}

// ----- Local game logic -----
function GenerateSequence()
{
	Sequence_t = [];
	for ( local i = 0; i < SEQ_LENGTH; i++ )
		Sequence_t.push( RandomInt( 0, SYMBOL_COUNT - 1 ) );
}

function StartRound()
{
	GenerateSequence();
	Entered_t = [];
	PhaseStartTime = Time();
	Phase = "transmit";
}

function Tick()
{
	local now = Time();

	if ( Phase == "complete" || Phase == "failed" || Phase == "standby" )
		return;

	if ( Phase == "transmit" )
	{
		if ( now - PhaseStartTime >= TRANSMIT_TIME )
		{
			Phase = "recall";
			PhaseStartTime = now;
		}
	}
	else if ( Phase == "verify_ok" )
	{
		if ( now - PhaseStartTime >= VERIFY_TIME )
		{
			Phase = "complete";
			if ( !bSentEnd ) { bSentEnd = true; self.SendInput( INPUT_SUCCESS ); }
		}
	}
	else if ( Phase == "verify_bad" )
	{
		if ( now - PhaseStartTime >= VERIFY_TIME )
		{
			StartRound();
		}
	}
}

// ----- Paint -----
function Paint()
{
	Tick();
	UpdateFromServer();

	local view  = GetDesignView();
	local pulse = ( sin( Time() * 1.2 ) + 1.0 ) * 0.5;

	PaintBackground( view, pulse );
	PaintHeader( view );
	PaintDiagnostics( view );
	PaintCenterDisplay( view, pulse );
	PaintReconstruction( view );
	if ( Phase == "recall" ) PaintKeypad( view, pulse );
}

function PaintBackground( view, pulse )
{
	local left = 0.0;
	local right = DESIGN_W;
	local top = 0.0;
	local bottom = DESIGN_H;

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
	PaintColorText( view, 78, 26, COLOR_HEADER_TEXT, "SECURITY HANDSHAKE" );

	local statusText, statusColor;
	if ( Phase == "standby" )        { statusText = "STANDBY";                statusColor = COLOR_HEADER_STATUS; }
	else if ( Phase == "complete" )  { statusText = "AUTHENTICATION ACCEPTED"; statusColor = COLOR_WARN_GREEN; }
	else if ( Phase == "failed" )    { statusText = "SECURITY LOCKOUT";        statusColor = COLOR_WARN_RED; }
	else if ( Phase == "verify_ok" ) { statusText = "HANDSHAKE VERIFIED";      statusColor = COLOR_WARN_GREEN; }
	else if ( Phase == "verify_bad" ){ statusText = "AUTHENTICATION ERROR";    statusColor = COLOR_WARN_RED; }
	else                             { statusText = "AUTHENTICATING";          statusColor = COLOR_HEADER_STATUS; }

	local statusW = TextWideDesign( view, statusText );
	PaintColorText( view, 1500 - statusW, 30, statusColor, statusText );

	PaintColorRect( view, 70, 74, 1530, 76, COLOR_BG_EDGE );
}

function PaintDiagnostics( view )
{
	PaintColorText( view, 78, 88, COLOR_SUBTITLE,
		"ENCRYPTION: MIL-SEC/7    CHANNEL: INTERNAL    AUTH NODE: 04" );
	PaintColorText( view, 78, 116, COLOR_SUBTITLE,
		"PACKET LOSS: 0.02%       REMOTE HOST: UNKNOWN" );

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

	local ledX = 1420.0;
	local ledY = 92.0;
	local litRed    = ( sin( Time() * 2.5 ) > 0.6 );
	local litYellow = ( sin( Time() * 3.7 ) > 0.4 );
	local litGreen  = ( Phase == "recall" ) || ( Phase == "verify_ok" );

	PaintColorRect( view, ledX,      ledY, ledX + 14, ledY + 14, litRed    ? COLOR_WARN_RED    : [40, 20, 20, 255] );
	PaintColorRect( view, ledX + 22, ledY, ledX + 36, ledY + 14, litYellow ? COLOR_WARN_YELLOW : [40, 36, 12, 255] );
	PaintColorRect( view, ledX + 44, ledY, ledX + 58, ledY + 14, litGreen  ? COLOR_WARN_GREEN  : [20, 40, 26, 255] );
}

function PaintCenterDisplay( view, pulse )
{
	PaintColorRect( view, 200, CENTER_Y0, 1400, CENTER_Y1, COLOR_PANEL_BG );
	PaintColorRect( view, 206, CENTER_Y0 + 6, 1394, CENTER_Y1 - 6, COLOR_PANEL_INNER );
	PaintColorRect( view, 200, CENTER_Y0, 1400, CENTER_Y0 + 3, COLOR_PANEL_BORDER );
	PaintColorRect( view, 200, CENTER_Y1 - 3, 1400, CENTER_Y1, COLOR_PANEL_BORDER );

	local cx = 800.0;
	local midY = ( CENTER_Y0 + CENTER_Y1 ) * 0.5;

	if ( Phase == "standby" )
	{
		PaintCenteredText( view, cx, midY - 30, COLOR_HEADER_STATUS, "AWAITING TERMINAL ACCESS" );
		local blink = ( sin( Time() * 3.0 ) > 0.3 );
		PaintCenteredText( view, cx, midY + 20, blink ? COLOR_WARN_YELLOW : COLOR_HEADER_STATUS,
			"OPERATOR INPUT REQUIRED" );
	}
	else if ( Phase == "transmit" )
	{
		PaintCenteredText( view, cx, CENTER_Y0 + 30, COLOR_HEADER_STATUS, "INCOMING SECURITY HANDSHAKE" );
		PaintCenteredText( view, cx, CENTER_Y0 + 62, COLOR_WARN_YELLOW, "CAPTURE SIGNAL..." );

		local n = Sequence_t.len();
		if ( n > 0 )
		{
			local spacing = 130.0;
			local totalW  = ( n - 1 ) * spacing;
			local startX  = cx - totalW * 0.5;
			local symY    = midY + 25.0;
			for ( local i = 0; i < n; i++ )
			{
				local sx = startX + i * spacing;
				PaintColorRect( view, sx - 55, symY - 55, sx + 55, symY + 55, [ 15, 40, 48, 255 ] );
				PaintColorRect( view, sx - 55, symY - 55, sx + 55, symY - 51, COLOR_PANEL_BORDER );
				PaintColorRect( view, sx - 55, symY + 51, sx + 55, symY + 55, COLOR_PANEL_BORDER );
				PaintColorRect( view, sx - 55, symY - 55, sx - 51, symY + 55, COLOR_PANEL_BORDER );
				PaintColorRect( view, sx + 51, symY - 55, sx + 55, symY + 55, COLOR_PANEL_BORDER );
				DrawSymbol( view, sx, symY, 78.0, Sequence_t[i], COLOR_SYMBOL_ON );
			}
		}
	}
	else if ( Phase == "recall" )
	{
		PaintCenteredText( view, cx, CENTER_Y0 + 55, COLOR_HEADER_TEXT, "REPRODUCE HANDSHAKE" );
		PaintCenteredText( view, cx, CENTER_Y0 + 108, COLOR_HEADER_STATUS,
			"SELECT SYMBOLS IN THE ORDER SHOWN" );

		local need = Sequence_t.len();
		local have = Entered_t.len();
		local dotY = CENTER_Y0 + 195;
		local dotSpacing = 34.0;
		local dotStartX = cx - ( need - 1 ) * dotSpacing * 0.5;
		for ( local i = 0; i < need; i++ )
		{
			local dx = dotStartX + i * dotSpacing;
			local filled = i < have;
			local col = filled ? COLOR_SYMBOL_ON : COLOR_SYMBOL_EMPTY;
			PaintColorRect( view, dx - 10, dotY - 10, dx + 10, dotY + 10, col );
		}
	}
	else if ( Phase == "verify_ok" )
	{
		local flashCol = ( sin( Time() * 15.0 ) > 0 ) ? COLOR_WARN_GREEN : COLOR_HEADER_TEXT;
		PaintCenteredText( view, cx, midY - 25, flashCol, "AUTHENTICATION ACCEPTED" );
		PaintCenteredText( view, cx, midY + 25, COLOR_HEADER_STATUS, "SECURITY HANDSHAKE COMPLETE" );
	}
	else if ( Phase == "verify_bad" )
	{
		local flashCol = ( sin( Time() * 22.0 ) > 0 ) ? COLOR_WARN_RED : [ 240, 145, 125, 255 ];
		PaintCenteredText( view, cx, midY - 25, flashCol, "AUTHENTICATION ERROR" );
		PaintCenteredText( view, cx, midY + 25, COLOR_HEADER_STATUS, "RETRYING HANDSHAKE..." );
	}
	else if ( Phase == "complete" )
	{
		PaintCenteredText( view, cx, midY - 25, COLOR_WARN_GREEN, "AUTHENTICATION ACCEPTED" );
		PaintCenteredText( view, cx, midY + 25, COLOR_HEADER_STATUS, "SECURITY HANDSHAKE COMPLETE" );
	}
	else if ( Phase == "failed" )
	{
		PaintCenteredText( view, cx, midY - 25, COLOR_WARN_RED, "AUTHENTICATION REJECTED" );
		PaintCenteredText( view, cx, midY + 25, COLOR_HEADER_STATUS, "SECURITY LOCKOUT" );
	}
}

function PaintReconstruction( view )
{
	if ( Phase != "recall" && Phase != "verify_ok" && Phase != "verify_bad" ) return;
	if ( Sequence_t.len() == 0 ) return;

	PaintColorRect( view, 300, RECON_Y0, 1300, RECON_Y1, [ 8, 22, 30, 245 ] );
	PaintColorRect( view, 300, RECON_Y0, 1300, RECON_Y0 + 2, COLOR_PANEL_BORDER );
	PaintColorRect( view, 300, RECON_Y1 - 2, 1300, RECON_Y1, COLOR_PANEL_BORDER );

	PaintColorText( view, 320, RECON_Y0 + 12, COLOR_HEADER_STATUS, "ENTERED:" );

	local n = Sequence_t.len();
	local spacing = 78.0;
	local totalW  = ( n - 1 ) * spacing;
	local startX  = 820 - totalW * 0.5;
	local symY    = ( RECON_Y0 + RECON_Y1 ) * 0.5 + 4.0;

	for ( local i = 0; i < n; i++ )
	{
		local sx = startX + i * spacing;
		local filled = i < Entered_t.len();

		local boxCol = filled ? COLOR_PANEL_BORDER : [ 30, 55, 65, 200 ];
		PaintColorRect( view, sx - 32, symY - 32, sx + 32, symY + 32, [ 15, 35, 42, 255 ] );
		PaintColorRect( view, sx - 32, symY - 32, sx + 32, symY - 29, boxCol );
		PaintColorRect( view, sx - 32, symY + 29, sx + 32, symY + 32, boxCol );
		PaintColorRect( view, sx - 32, symY - 32, sx - 29, symY + 32, boxCol );
		PaintColorRect( view, sx + 29, symY - 32, sx + 32, symY + 32, boxCol );

		if ( filled )
		{
			local col = COLOR_SYMBOL_ON;
			if ( Phase == "verify_bad" && i < Sequence_t.len() && Entered_t[i] != Sequence_t[i] )
				col = COLOR_SYMBOL_ERR;
			DrawSymbol( view, sx, symY, 46.0, Entered_t[i], col );
		}
	}
}

function PaintKeypad( view, pulse )
{
	for ( local i = 0; i < SYMBOL_COUNT; i++ )
	{
		local r = GetBtnRect( i );
		local x0 = r[0], y0 = r[1], x1 = r[2], y1 = r[3];
		local hovered = ( HoverBtn == i );

		PaintColorRect( view, x0 + 3, y0 + 3, x1 + 3, y1 + 3, COLOR_BTN_SHADOW );
		PaintColorRect( view, x0, y0, x1, y1, hovered ? COLOR_BTN_BG_HOVER : COLOR_BTN_BG );

		local bc = hovered ? COLOR_BTN_BORDER_H : COLOR_BTN_BORDER;
		PaintColorRect( view, x0, y0, x1, y0 + 2, bc );
		PaintColorRect( view, x0, y1 - 2, x1, y1, bc );
		PaintColorRect( view, x0, y0, x0 + 2, y1, bc );
		PaintColorRect( view, x1 - 2, y0, x1, y1, bc );

		PaintColorRect( view, x0 + 5, y0 + 5, x0 + 12, y0 + 12, hovered ? COLOR_BTN_BORDER_H : COLOR_BTN_BORDER );

		local cx = ( x0 + x1 ) * 0.5;
		local cy = ( y0 + y1 ) * 0.5;
		DrawSymbol( view, cx, cy, 62.0, i, hovered ? COLOR_SYMBOL_ON : COLOR_SYMBOL_DIM );
	}
}

// ----- Server sync (only cares about complete/failed) -----
function UpdateFromServer()
{
	local packet = self.GetString( 0 );
	if ( packet == "" ) return;
	local fields = split( packet, "|" );
	if ( fields.len() < 1 ) return;

	local newState = fields[0];
	if ( newState == "complete" && Phase != "complete" )
		Phase = "complete";
	else if ( newState == "failed" && Phase != "failed" && Phase != "complete" )
		Phase = "failed";
}

// ----- Interaction -----
function Control( table )
{
	local view = GetDesignView();

	local mx = 0.0, my = 0.0;
	if ( "mouse_x" in table ) mx = table["mouse_x"].tofloat();
	if ( "mouse_y" in table ) my = table["mouse_y"].tofloat();

	local designX = ( mx - view[0] ) / view[2] * DESIGN_W;
	local designY = ( my - view[1] ) / view[3] * DESIGN_H;

	// ----- Start the round the first time the cursor enters the view -----
	if ( !bSentStart )
	{
		local insideView = ( mx >= view[0] + 12.0 && mx <= view[0] + view[2] - 12.0 &&
		                     my >= view[1] + 12.0 && my <= view[1] + view[3] - 12.0 );
		if ( insideView )
		{
			bSentStart = true;
			StartRound();
			self.SendInput( INPUT_START );
		}
	}

	// ----- Hover on keypad -----
	local newHover = -1;
	if ( Phase == "recall" )
	{
		for ( local i = 0; i < SYMBOL_COUNT; i++ )
		{
			local r = GetBtnRect( i );
			if ( designX >= r[0] && designX <= r[2] && designY >= r[1] && designY <= r[3] )
			{
				newHover = i;
				break;
			}
		}
	}
	HoverBtn = newHover;

	// ----- Click on keypad -----
	local lmbDown = false;
	if ( "mouse_left" in table && table["mouse_left"] ) lmbDown = true;

	if ( !lmbDown ) { bPressedLastFrame = false; return; }
	if ( bPressedLastFrame ) return;
	bPressedLastFrame = true;

	if ( Phase != "recall" ) return;
	if ( HoverBtn < 0 ) return;
	if ( Entered_t.len() >= SEQ_LENGTH ) return;

	Entered_t.push( HoverBtn );

	if ( Entered_t.len() == SEQ_LENGTH )
	{
		local ok = true;
		for ( local i = 0; i < SEQ_LENGTH; i++ )
			if ( Entered_t[i] != Sequence_t[i] ) { ok = false; break; }

		PhaseStartTime = Time();
		if ( ok )
		{
			Phase = "verify_ok";
		}
		else
		{
			Phase = "verify_bad";
		}
	}
}