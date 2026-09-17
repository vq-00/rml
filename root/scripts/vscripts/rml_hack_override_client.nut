// =========================================================
//  EMERGENCY SYSTEM OVERRIDE -- CLIENT
//  Static dependency tree with deactivation + conflicts.
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

const ST_OFFLINE      = 0;
const ST_INITIALIZING = 1;
const ST_ONLINE       = 2;

const INIT_TIME = 0.7;

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
COLOR_HEADER_DIM    <- [  90, 130, 140, 255 ];

COLOR_PANEL_BG      <- [   5,  13,  21, 245 ];
COLOR_PANEL_INNER   <- [  12,  30,  38, 255 ];
COLOR_PANEL_BORDER  <- [  61, 163, 157, 200 ];

COLOR_NODE_OFFLINE      <- [  14,  30,  38, 255 ];
COLOR_NODE_OFFLINE_HOV  <- [  32,  72,  90, 255 ];
COLOR_NODE_INIT         <- [  48,  44,  15, 255 ];
COLOR_NODE_ONLINE       <- [  15,  48,  38, 255 ];
COLOR_NODE_CONFLICT     <- [  55,  22,  22, 255 ];
COLOR_NODE_TARGET_BG    <- [  38,  32,  10, 255 ];
COLOR_NODE_TARGET_LINE  <- [ 240, 200,  80, 255 ];

COLOR_BORDER_OFFLINE    <- [  60,  90, 100, 255 ];
COLOR_BORDER_HOV        <- [ 104, 241, 220, 255 ];
COLOR_BORDER_INIT       <- [ 220, 180,  80, 255 ];
COLOR_BORDER_ONLINE     <- [  83, 220, 150, 255 ];
COLOR_BORDER_CONFLICT   <- [ 220,  90,  90, 255 ];

COLOR_EDGE_INACTIVE     <- [  50,  80,  90, 255 ];
COLOR_EDGE_ACTIVE       <- [  83, 220, 150, 255 ];
COLOR_EDGE_CONFLICT     <- [ 220,  90,  90, 255 ];

COLOR_LED_OFFLINE       <- [ 180,  50,  50, 255 ];
COLOR_LED_INIT          <- [ 240, 200,  80, 255 ];
COLOR_LED_ONLINE        <- [  83, 220, 150, 255 ];

COLOR_OK_GREEN          <- [  83, 220, 150, 255 ];
COLOR_MISS_RED          <- [ 240, 100,  90, 255 ];
COLOR_INIT_YELLOW       <- [ 240, 200,  80, 255 ];
COLOR_WARN_YELLOW       <- [ 240, 200,  80, 255 ];
COLOR_WARN_RED          <- [ 222,  67,  61, 255 ];
COLOR_WARN_GREEN        <- [  83, 220, 150, 255 ];
COLOR_TARGET_GOLD       <- [ 240, 200,  80, 255 ];

COLOR_FEEDBACK_BG       <- [   0,   0,   0, 210 ];

// ----- State -----
Phase          <- "standby";
Systems_t      <- [];

Depth_t        <- [];
Col_t          <- [];
ScreenX_t      <- [];
ScreenY_t      <- [];

HoverRow       <- -1;
bPressedLMB    <- false;
bSentStart     <- false;
bSentEnd       <- false;
LastTickTime   <- 0.0;
GlobalTime     <- 0.0;
DebugLastLog   <- 0.0;

FeedbackText   <- "";
FeedbackColor   <- [ 255, 255, 255 ];
FeedbackExpire <- 0.0;

// ----- Layout constants -----
const TREE_PANEL_X0 = 100.0;
const TREE_PANEL_X1 = 1500.0;
const TREE_PANEL_Y0 = 120.0;
const TREE_PANEL_Y1 = 755.0;
const TREE_PAD      = 20.0;

const NODE_W = 300.0;
const NODE_H = 64.0;

const DETAIL_PANEL_X0 = 100.0;
const DETAIL_PANEL_X1 = 1500.0;
const DETAIL_PANEL_Y0 = 765.0;
const DETAIL_PANEL_Y1 = 882.0;

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

function DrawLine( v, x0, y0, x1, y1, t, c )
{
	local dx = x1 - x0, dy = y1 - y0;
	local adx = fabs(dx), ady = fabs(dy);
	local span = adx > ady ? adx : ady;
	local steps = (span / 2.0).tointeger();
	if ( steps < 4 ) steps = 4;
	if ( steps > 200 ) steps = 200;
	for ( local i = 0; i <= steps; i++ )
	{
		local f = i.tofloat() / steps;
		local px = x0 + dx*f;
		local py = y0 + dy*f;
		PaintColorRect( v, px-t*0.5, py-t*0.5, px+t*0.5, py+t*0.5, c );
	}
}

// =========================================================
//  SYSTEM DEFINITIONS
// =========================================================
function BuildSystems()
{
	local defs = [];

	if ( DIFFICULTY == 0 )
	{
		// 5 systems, linear chain. Target = last.
		defs = [
			{ name = "AUX POWER",     deps = [],         conflicts = [], isTarget = false },
			{ name = "REACTOR",       deps = [0],        conflicts = [], isTarget = false },
			{ name = "COOLING",       deps = [1],        conflicts = [], isTarget = false },
			{ name = "LIFE SUPPORT",  deps = [2],        conflicts = [], isTarget = false },
			{ name = "SECURITY",      deps = [3],        conflicts = [], isTarget = true }
		];
	}
	else if ( DIFFICULTY == 2 )
	{
		// 13 systems. EMERGENCY MODE conflicts with WEAPONS LOCK and
		// STEALTH MODE. FIREWALL needs BOTH WEAPONS LOCK and STEALTH MODE.
		defs = [
			{ name = "AUX POWER",        deps = [],          conflicts = [],     isTarget = false },  // 0
			{ name = "LIFE SUPPORT",     deps = [0],         conflicts = [],     isTarget = false },  // 1
			{ name = "COMMUNICATIONS",   deps = [0],         conflicts = [],     isTarget = false },  // 2
			{ name = "REACTOR CONTROL",  deps = [0],         conflicts = [],     isTarget = false },  // 3
			{ name = "VENTILATION",      deps = [1],         conflicts = [],     isTarget = false },  // 4
			{ name = "COOLING",          deps = [1, 3],      conflicts = [],     isTarget = false },  // 5
			{ name = "FIRE SUPPRESSION", deps = [1, 3],      conflicts = [],     isTarget = false },  // 6
			{ name = "EMERGENCY MODE",   deps = [2, 3],      conflicts = [9, 10], isTarget = false },  // 7
			{ name = "SECURITY",         deps = [2, 5],      conflicts = [],     isTarget = false },  // 8
			{ name = "WEAPONS LOCK",     deps = [8, 11],     conflicts = [7],    isTarget = false },  // 9
			{ name = "STEALTH MODE",     deps = [2, 3, 4],   conflicts = [7],    isTarget = false },  // 10
			{ name = "DOOR CONTROL",     deps = [5, 6],      conflicts = [],     isTarget = false },  // 11
			{ name = "FIREWALL",         deps = [9, 10],     conflicts = [],     isTarget = true  }   // 12
		];
	}
	else
	{
		// 8 systems, branching. Target = last.
		defs = [
			{ name = "AUX POWER",        deps = [],         conflicts = [], isTarget = false },
			{ name = "LIFE SUPPORT",     deps = [0],        conflicts = [], isTarget = false },
			{ name = "COMMUNICATIONS",   deps = [0],        conflicts = [], isTarget = false },
			{ name = "REACTOR CONTROL",  deps = [0],        conflicts = [], isTarget = false },
			{ name = "COOLING",          deps = [1, 3],     conflicts = [], isTarget = false },
			{ name = "SECURITY",         deps = [2, 4],     conflicts = [], isTarget = false },
			{ name = "FIRE SUPPRESSION", deps = [1, 3],     conflicts = [], isTarget = false },
			{ name = "DOOR CONTROL",     deps = [5, 6],     conflicts = [], isTarget = true  }
		];
	}

	Systems_t = [];
	for ( local i = 0; i < defs.len(); i++ )
	{
		Systems_t.push({
			name      = defs[i].name,
			deps      = defs[i].deps,
			conflicts = defs[i].conflicts,
			isTarget  = defs[i].isTarget,
			state     = ST_OFFLINE,
			initEnd   = 0.0,
			flashEnd  = 0.0
		});
	}
}

// =========================================================
//  TREE LAYOUT
// =========================================================
function ComputeDepth( i, memo )
{
	if ( i < 0 || i >= Systems_t.len() ) return 0;
	if ( memo[i] >= 0 ) return memo[i];
	if ( memo[i] == -2 ) return 0;
	memo[i] = -2;
	local deps = Systems_t[i].deps;
	if ( deps.len() == 0 ) { memo[i] = 0; return 0; }
	local maxD = -1;
	for ( local k = 0; k < deps.len(); k++ )
	{
		local d = ComputeDepth( deps[k], memo );
		if ( d > maxD ) maxD = d;
	}
	if ( maxD < 0 ) maxD = 0;
	memo[i] = maxD + 1;
	return memo[i];
}

function RebuildTree()
{
	local n = Systems_t.len();
	if ( n == 0 ) return;

	local memo = [];
	for ( local i = 0; i < n; i++ ) memo.push( -1 );
	Depth_t = [];
	local maxDepth = 0;
	for ( local i = 0; i < n; i++ )
	{
		local d = ComputeDepth( i, memo );
		Depth_t.push( d );
		if ( d > maxDepth ) maxDepth = d;
	}

	local levels = [];
	for ( local d = 0; d <= maxDepth; d++ ) levels.push( [] );
	for ( local i = 0; i < n; i++ ) levels[ Depth_t[i] ].push( i );

	for ( local d = 0; d <= maxDepth; d++ )
	{
		local arr = levels[d];
		local m = arr.len();
		for ( local j = m - 1; j > 0; j-- )
		{
			local k = RandomInt( 0, j );
			local tmp = arr[j]; arr[j] = arr[k]; arr[k] = tmp;
		}
	}

	Col_t = [];
	for ( local i = 0; i < n; i++ ) Col_t.push( 0 );
	local maxCols = 1;
	for ( local d = 0; d <= maxDepth; d++ )
	{
		local arr = levels[d];
		for ( local j = 0; j < arr.len(); j++ ) Col_t[ arr[j] ] = j;
		if ( arr.len() > maxCols ) maxCols = arr.len();
	}

	local minPitchX = NODE_W + 24.0;
	local minPitchY = NODE_H + 20.0;

	local availW = (TREE_PANEL_X1 - TREE_PANEL_X0) - NODE_W - TREE_PAD * 2.0;
	local availH = (TREE_PANEL_Y1 - TREE_PANEL_Y0) - NODE_H - TREE_PAD * 2.0;

	local pitchX = minPitchX;
	if ( maxCols > 1 )
	{
		local maxFitX = availW / (maxCols - 1);
		if ( maxFitX < pitchX ) pitchX = maxFitX;
	}

	local pitchY = minPitchY;
	if ( maxDepth > 0 )
	{
		local maxFitY = availH / maxDepth;
		if ( maxFitY < pitchY ) pitchY = maxFitY;
	}

	local panelCX = (TREE_PANEL_X0 + TREE_PANEL_X1) * 0.5;
	local treeH = maxDepth * pitchY + NODE_H;
	local topY  = TREE_PANEL_Y0 + TREE_PAD
	            + ( ( (TREE_PANEL_Y1 - TREE_PANEL_Y0) - TREE_PAD * 2 ) - treeH ) * 0.5
	            + NODE_H * 0.5;

	ScreenX_t = [];
	ScreenY_t = [];
	for ( local i = 0; i < n; i++ )
	{
		local d = Depth_t[i];
		local c = Col_t[i];
		local cnt = levels[d].len();
		local offset = ( c - (cnt - 1) * 0.5 ) * pitchX;
		// Slight jitter for single-node levels so overlapping edges
		// don't run through an intermediate node.
		if ( cnt == 1 && maxCols > 1 )
			offset += ( RandomInt( 0, 1 ) == 0 ) ? -50.0 : 50.0;
		ScreenX_t.push( panelCX + offset );
		ScreenY_t.push( topY + d * pitchY );
	}
}

// =========================================================
//  LOGIC
// =========================================================
function AllPrereqsOnline( sys )
{
	for ( local k = 0; k < sys.deps.len(); k++ )
	{
		local d = sys.deps[k];
		if ( d < 0 || d >= Systems_t.len() ) continue;
		if ( Systems_t[d].state != ST_ONLINE ) return false;
	}
	return true;
}

function CountMissingPrereqs( sys )
{
	local n = 0;
	for ( local k = 0; k < sys.deps.len(); k++ )
	{
		local d = sys.deps[k];
		if ( d < 0 || d >= Systems_t.len() ) continue;
		if ( Systems_t[d].state != ST_ONLINE ) n++;
	}
	return n;
}

function HasConflict( sys )
{
	for ( local k = 0; k < sys.conflicts.len(); k++ )
	{
		local c = sys.conflicts[k];
		if ( c < 0 || c >= Systems_t.len() ) continue;
		local st = Systems_t[c].state;
		if ( st == ST_ONLINE || st == ST_INITIALIZING ) return true;
	}
	return false;
}

function FirstConflictIdx( sys )
{
	for ( local k = 0; k < sys.conflicts.len(); k++ )
	{
		local c = sys.conflicts[k];
		if ( c < 0 || c >= Systems_t.len() ) continue;
		local st = Systems_t[c].state;
		if ( st == ST_ONLINE || st == ST_INITIALIZING ) return c;
	}
	return -1;
}

function CountOnline()
{
	local n = 0;
	for ( local i = 0; i < Systems_t.len(); i++ )
		if ( Systems_t[i].state == ST_ONLINE ) n++;
	return n;
}

function TargetOnline()
{
	for ( local i = 0; i < Systems_t.len(); i++ )
		if ( Systems_t[i].isTarget && Systems_t[i].state == ST_ONLINE ) return true;
	return false;
}

function ShowFeedback( text, color, duration )
{
	FeedbackText = text;
	FeedbackColor = color;
	FeedbackExpire = Time() + duration;
}

function AttemptActivate( idx )
{
	if ( idx < 0 || idx >= Systems_t.len() ) return;
	local sys = Systems_t[idx];

	// ---- Deactivate ----
	if ( sys.state == ST_ONLINE || sys.state == ST_INITIALIZING )
	{
		sys.state = ST_OFFLINE;
		sys.initEnd = 0.0;
		ShowFeedback( "DEACTIVATING " + sys.name, COLOR_HEADER_STATUS, 0.9 );
		return;
	}

	// ---- Activation: check prereqs ----
	if ( !AllPrereqsOnline( sys ) )
	{
		sys.flashEnd = Time() + 1.2;
		local missing = CountMissingPrereqs( sys );
		local word = ( missing == 1 ) ? "PREREQUISITE" : "PREREQUISITES";
		ShowFeedback( "ACCESS DENIED -- " + missing.tostring() + " " + word + " OFFLINE",
			COLOR_WARN_RED, 1.2 );
		return;
	}

	// ---- Activation: check conflicts ----
	local confIdx = FirstConflictIdx( sys );
	if ( confIdx >= 0 )
	{
		sys.flashEnd = Time() + 1.2;
		ShowFeedback( "CONFLICT -- DEACTIVATE " + Systems_t[confIdx].name + " FIRST",
			COLOR_WARN_RED, 1.4 );
		return;
	}

	sys.state = ST_INITIALIZING;
	sys.initEnd = Time() + INIT_TIME;
	ShowFeedback( "INITIALIZING " + sys.name + "...", COLOR_INIT_YELLOW, 0.9 );
}

function StartRun()
{
	BuildSystems();
	RebuildTree();
	FeedbackText = "";
	FeedbackExpire = 0.0;
	Phase = "running";
}

function Tick( dt )
{
	if ( Phase != "running" ) return;

	local now = Time();
	for ( local i = 0; i < Systems_t.len(); i++ )
	{
		local sys = Systems_t[i];
		if ( sys.state == ST_INITIALIZING && now >= sys.initEnd )
		{
			sys.state = ST_ONLINE;
			ShowFeedback( sys.name + " ONLINE", COLOR_WARN_GREEN, 0.9 );
		}
	}

	if ( TargetOnline() )
	{
		Phase = "complete";
		if ( !bSentEnd ) { bSentEnd = true; self.SendInput( INPUT_SUCCESS ); }
	}
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

	Tick( dt );
	UpdateFromServer();

	if ( bDebugLog && now - DebugLastLog > 1.0 )
	{
		DebugLastLog = now;
		Msg( "override pkt: [" + self.GetString(0) + "] phase=" + Phase );
	}

	local view  = GetDesignView();
	local pulse = ( sin( Time() * 1.2 ) + 1.0 ) * 0.5;

	PaintBackground( view, pulse );
	PaintHeader( view );
	PaintInfoRow( view );
	PaintTreePanel( view );
	PaintDetailPanel( view );
	PaintFeedback( view );
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
	PaintColorText( v, 78, 22, COLOR_HEADER_TEXT, "EMERGENCY CONTROL SYSTEM" );

	local statusText, statusColor;
	if ( Phase == "standby" )       { statusText = "STANDBY";   statusColor = COLOR_HEADER_STATUS; }
	else if ( Phase == "complete" ) { statusText = "RESTORED";  statusColor = COLOR_WARN_GREEN; }
	else                            { statusText = "DEGRADED";  statusColor = COLOR_WARN_RED; }

	local w = TextWideDesign( v, statusText );
	PaintColorText( v, 1500 - w, 26, statusColor, statusText );

	PaintColorRect( v, 70, 68, 1530, 69, COLOR_BG_EDGE );
}

function PaintInfoRow( v )
{
	local online = CountOnline();
	local total  = Systems_t.len();

	// ONLINE: X / M
	PaintSmallText( v, 78, 88, COLOR_HEADER_STATUS, "ONLINE:" );
	local lw = SmallTextWideDesign( v, "ONLINE:" );
	local valStr = online.tostring() + " / " + total.tostring();
	local vcol = ( total > 0 && online == total ) ? COLOR_WARN_GREEN : COLOR_HEADER_TEXT;
	PaintSmallText( v, 78 + lw + 12, 88, vcol, valStr );

	// TARGET indicator
	local targetOnline = TargetOnline();
	local tLabel = "TARGET: ";
	local tValue = targetOnline ? "ONLINE" : "OFFLINE";
	local tCol   = targetOnline ? COLOR_WARN_GREEN : COLOR_TARGET_GOLD;
	PaintSmallText( v, 340, 88, COLOR_HEADER_STATUS, tLabel );
	local tlw = SmallTextWideDesign( v, tLabel );
	PaintSmallText( v, 340 + tlw + 4, 88, tCol, tValue );

	// Instruction
	local instr = "CLICK TO ACTIVATE / DEACTIVATE";
	local iw = SmallTextWideDesign( v, instr );
	PaintSmallText( v, 1500 - iw - 20, 88, COLOR_HEADER_DIM, instr );

	PaintColorRect( v, 70, 118, 1530, 119, COLOR_BG_EDGE );
}

function PaintTreePanel( v )
{
	PaintColorRect( v, TREE_PANEL_X0, TREE_PANEL_Y0, TREE_PANEL_X1, TREE_PANEL_Y1, COLOR_PANEL_BG );
	PaintColorRect( v, TREE_PANEL_X0+4, TREE_PANEL_Y0+4, TREE_PANEL_X1-4, TREE_PANEL_Y1-4, COLOR_PANEL_INNER );
	PaintColorRect( v, TREE_PANEL_X0, TREE_PANEL_Y0, TREE_PANEL_X1, TREE_PANEL_Y0+3, COLOR_PANEL_BORDER );
	PaintColorRect( v, TREE_PANEL_X0, TREE_PANEL_Y1-3, TREE_PANEL_X1, TREE_PANEL_Y1, COLOR_PANEL_BORDER );
	PaintColorRect( v, TREE_PANEL_X0, TREE_PANEL_Y0, TREE_PANEL_X0+3, TREE_PANEL_Y1, COLOR_PANEL_BORDER );
	PaintColorRect( v, TREE_PANEL_X1-3, TREE_PANEL_Y0, TREE_PANEL_X1, TREE_PANEL_Y1, COLOR_PANEL_BORDER );

	if ( Systems_t.len() == 0 ) return;

	// Edges
	for ( local i = 0; i < Systems_t.len(); i++ )
	{
		local sys = Systems_t[i];
		local sx = ScreenX_t[i];
		local sy = ScreenY_t[i];

		for ( local k = 0; k < sys.deps.len(); k++ )
		{
			local d = sys.deps[k];
			if ( d < 0 || d >= Systems_t.len() ) continue;

			local px = ScreenX_t[d];
			local py = ScreenY_t[d];

			local pOnline = ( Systems_t[d].state == ST_ONLINE );
			local cOnline = ( sys.state == ST_ONLINE );
			local edgeCol = ( pOnline && cOnline ) ? COLOR_EDGE_ACTIVE : COLOR_EDGE_INACTIVE;
			local edgeT   = ( pOnline && cOnline ) ? 3.0 : 2.0;

			local pyBottom = py + NODE_H * 0.5;
			local syTop    = sy - NODE_H * 0.5;
			local midY     = ( pyBottom + syTop ) * 0.5;

			DrawLine( v, px, pyBottom, px, midY, edgeT, edgeCol );
			DrawLine( v, px, midY,     sx, midY, edgeT, edgeCol );
			DrawLine( v, sx, midY,     sx, syTop, edgeT, edgeCol );

			PaintColorRect( v, sx - 6, syTop - 8, sx + 6, syTop - 4, edgeCol );
			PaintColorRect( v, sx - 3, syTop - 4, sx + 3, syTop - 1, edgeCol );
		}
	}

	for ( local i = 0; i < Systems_t.len(); i++ )
		PaintNode( v, i );
}

function PaintNode( v, i )
{
	local sys = Systems_t[i];
	local cx = ScreenX_t[i];
	local cy = ScreenY_t[i];

	local x0 = cx - NODE_W * 0.5;
	local y0 = cy - NODE_H * 0.5;
	local x1 = x0 + NODE_W;
	local y1 = y0 + NODE_H;

	local hovered  = ( HoverRow == i );
	local flashing = ( Time() < sys.flashEnd );
	local hasConf  = HasConflict( sys );

	// ---- Base colors ----
	local bg, bc;
	if ( sys.state == ST_ONLINE )
	{
		bg = COLOR_NODE_ONLINE; bc = COLOR_BORDER_ONLINE;
	}
	else if ( sys.state == ST_INITIALIZING )
	{
		bg = COLOR_NODE_INIT; bc = COLOR_BORDER_INIT;
	}
	else
	{
		if ( sys.isTarget ) bg = COLOR_NODE_TARGET_BG;
		else                bg = COLOR_NODE_OFFLINE;
		if ( hovered ) bg = COLOR_NODE_OFFLINE_HOV;
		bc = COLOR_BORDER_OFFLINE;
	}

	if ( hovered ) bc = COLOR_BORDER_HOV;
	if ( hasConf ) bc = COLOR_BORDER_CONFLICT;
	if ( flashing )
	{
		local ft = ( sys.flashEnd - Time() ) / 1.2;
		if ( ft < 0 ) ft = 0;
		bg = [ bg[0] + 80*ft, bg[1] + 15*ft, bg[2] + 15*ft, 255 ];
		bc = COLOR_WARN_RED;
	}

	PaintColorRect( v, x0+3, y0+3, x1+3, y1+3, [0, 0, 0, 120] );
	PaintColorRect( v, x0, y0, x1, y1, bg );
	PaintColorRect( v, x0, y0, x1, y0+2, bc );
	PaintColorRect( v, x0, y1-2, x1, y1, bc );
	PaintColorRect( v, x0, y0, x0+2, y1, bc );
	PaintColorRect( v, x1-2, y0, x1, y1, bc );

	// ---- Target marker: gold corner tab ----
	if ( sys.isTarget )
	{
		PaintColorRect( v, x0, y0, x0+20, y0+2, COLOR_TARGET_GOLD );
		PaintColorRect( v, x0, y0, x0+2, y0+20, COLOR_TARGET_GOLD );
		PaintColorRect( v, x1-20, y1-2, x1, y1, COLOR_TARGET_GOLD );
		PaintColorRect( v, x1-2, y1-20, x1, y1, COLOR_TARGET_GOLD );
	}

	// ---- LED + name ----
	local padX = 16.0;
	local ledSize = 10.0;
	local ledX = x0 + padX;
	local ledY = y0 + 14;

	local ledCol;
	if ( sys.state == ST_ONLINE ) ledCol = COLOR_LED_ONLINE;
	else if ( sys.state == ST_INITIALIZING )
	{
		local pulseAmt = 0.5 + 0.5 * sin( Time() * 8.0 );
		ledCol = [ ( 200 + 40 * pulseAmt ).tointeger(),
		           ( 160 + 60 * pulseAmt ).tointeger(),
		           40, 255 ];
	}
	else ledCol = COLOR_LED_OFFLINE;

	PaintColorRect( v, ledX-1, ledY-1, ledX+ledSize+1, ledY+ledSize+1, [0, 0, 0, 170] );
	PaintColorRect( v, ledX, ledY, ledX+ledSize, ledY+ledSize, ledCol );

	local nameX = ledX + ledSize + 12;
	local nameTopY = y0 + 12;
	PaintSmallText( v, nameX, nameTopY, COLOR_HEADER_TEXT, sys.name );

	// ---- Bottom row: state / prompt ----
	local statusY = y0 + NODE_H - 22;

	if ( hovered )
	{
		if ( sys.state == ST_OFFLINE )
		{
			if ( hasConf )
				PaintSmallText( v, nameX, statusY, COLOR_MISS_RED, "X CONFLICT" );
			else if ( AllPrereqsOnline( sys ) )
				PaintSmallText( v, nameX, statusY, COLOR_HEADER_TEXT, "> ACTIVATE" );
			else
				PaintSmallText( v, nameX, statusY, COLOR_MISS_RED, "X LOCKED" );
		}
		else if ( sys.state == ST_ONLINE )
		{
			PaintSmallText( v, nameX, statusY, COLOR_WARN_YELLOW, "< DEACTIVATE" );
		}
		else // INITIALIZING
		{
			PaintSmallText( v, nameX, statusY, COLOR_WARN_RED, "< CANCEL" );
		}
	}
	else
	{
		local stateText, stateCol;
		if ( sys.state == ST_ONLINE )            { stateText = "ONLINE";       stateCol = COLOR_WARN_GREEN; }
		else if ( sys.state == ST_INITIALIZING ) { stateText = "INITIALIZING"; stateCol = COLOR_INIT_YELLOW; }
		else                                     { stateText = "OFFLINE";      stateCol = COLOR_HEADER_DIM; }
		PaintSmallText( v, nameX, statusY, stateCol, stateText );
	}
}

function PaintDetailPanel( v )
{
	PaintColorRect( v, DETAIL_PANEL_X0, DETAIL_PANEL_Y0, DETAIL_PANEL_X1, DETAIL_PANEL_Y1, COLOR_PANEL_BG );
	PaintColorRect( v, DETAIL_PANEL_X0+4, DETAIL_PANEL_Y0+4, DETAIL_PANEL_X1-4, DETAIL_PANEL_Y1-4, COLOR_PANEL_INNER );
	PaintColorRect( v, DETAIL_PANEL_X0, DETAIL_PANEL_Y0, DETAIL_PANEL_X1, DETAIL_PANEL_Y0+3, COLOR_PANEL_BORDER );
	PaintColorRect( v, DETAIL_PANEL_X0, DETAIL_PANEL_Y1-3, DETAIL_PANEL_X1, DETAIL_PANEL_Y1, COLOR_PANEL_BORDER );
	PaintColorRect( v, DETAIL_PANEL_X0, DETAIL_PANEL_Y0, DETAIL_PANEL_X0+3, DETAIL_PANEL_Y1, COLOR_PANEL_BORDER );
	PaintColorRect( v, DETAIL_PANEL_X1-3, DETAIL_PANEL_Y0, DETAIL_PANEL_X1, DETAIL_PANEL_Y1, COLOR_PANEL_BORDER );

	local idx = HoverRow;
	if ( idx < 0 || idx >= Systems_t.len() )
	{
		PaintSmallText( v, DETAIL_PANEL_X0+24, DETAIL_PANEL_Y0+22, COLOR_HEADER_DIM,
			"HOVER A NODE TO SEE ITS REQUIREMENTS" );
		return;
	}

	local sys = Systems_t[idx];

	// ----- Header -----
	local nameX = DETAIL_PANEL_X0 + 24;
	local headerY = DETAIL_PANEL_Y0 + 14;
	PaintColorText( v, nameX, headerY, COLOR_HEADER_TEXT, sys.name );
	local nameW = TextWideDesign( v, sys.name );

	local stateText, stateCol;
	if ( sys.state == ST_ONLINE )            { stateText = "ONLINE";       stateCol = COLOR_WARN_GREEN; }
	else if ( sys.state == ST_INITIALIZING ) { stateText = "INITIALIZING"; stateCol = COLOR_INIT_YELLOW; }
	else                                     { stateText = "OFFLINE";      stateCol = COLOR_HEADER_DIM; }
	PaintSmallText( v, nameX + nameW + 22, headerY + 10, stateCol, stateText );

	if ( sys.isTarget )
	{
		local targetStr = "[ TARGET ]";
		local tw = SmallTextWideDesign( v, targetStr );
		PaintSmallText( v, DETAIL_PANEL_X1 - tw - 30, headerY + 10, COLOR_TARGET_GOLD, targetStr );
	}

	PaintColorRect( v, DETAIL_PANEL_X0+20, DETAIL_PANEL_Y0+50, DETAIL_PANEL_X1-20, DETAIL_PANEL_Y0+51, [40, 70, 78, 200] );

	// ----- Requires row -----
	local reqLabelX = DETAIL_PANEL_X0 + 24;
	local reqY = DETAIL_PANEL_Y0 + 66;

	PaintSmallText( v, reqLabelX, reqY, COLOR_HEADER_DIM, "REQUIRES:" );
	local reqLabelW = SmallTextWideDesign( v, "REQUIRES:" );
	local cx = reqLabelX + reqLabelW + 26;

	if ( sys.deps.len() == 0 )
	{
		PaintSmallText( v, cx, reqY, COLOR_OK_GREEN, "[ none ]" );
	}
	else
	{
		for ( local k = 0; k < sys.deps.len(); k++ )
		{
			local d = sys.deps[k];
			if ( d < 0 || d >= Systems_t.len() ) continue;
			local met = ( Systems_t[d].state == ST_ONLINE );
			local mcol = met ? COLOR_OK_GREEN : COLOR_MISS_RED;
			PaintColorRect( v, cx, reqY + 5, cx + 11, reqY + 16, mcol );
			cx += 17;
			PaintSmallText( v, cx, reqY, mcol, Systems_t[d].name );
			cx += SmallTextWideDesign( v, Systems_t[d].name );
			if ( k < sys.deps.len() - 1 ) cx += 28;
		}
	}

	// ----- Conflicts row (only if any) -----
	if ( sys.conflicts.len() > 0 )
	{
		local confY = DETAIL_PANEL_Y0 + 96;
		PaintSmallText( v, reqLabelX, confY, COLOR_HEADER_DIM, "CONFLICTS:" );
		local confLabelW = SmallTextWideDesign( v, "CONFLICTS:" );
		local cxx = reqLabelX + confLabelW + 26;

		for ( local k = 0; k < sys.conflicts.len(); k++ )
		{
			local c = sys.conflicts[k];
			if ( c < 0 || c >= Systems_t.len() ) continue;
			local online = ( Systems_t[c].state == ST_ONLINE || Systems_t[c].state == ST_INITIALIZING );
			local ccol = online ? COLOR_MISS_RED : COLOR_HEADER_DIM;

			PaintColorRect( v, cxx, confY + 5, cxx + 11, confY + 16, ccol );
			cxx += 17;
			PaintSmallText( v, cxx, confY, ccol, Systems_t[c].name );
			cxx += SmallTextWideDesign( v, Systems_t[c].name );
			if ( k < sys.conflicts.len() - 1 ) cxx += 24;
		}
	}
}

function PaintFeedback( v )
{
	if ( Time() >= FeedbackExpire ) return;
	if ( FeedbackText == "" ) return;

	local cx = DESIGN_W * 0.5;
	local cy = 152.0;
	local w = TextWideDesign( v, FeedbackText );

	PaintColorRect( v, cx - w*0.5 - 30, cy - 18, cx + w*0.5 + 30, cy + 18, COLOR_FEEDBACK_BG );
	PaintColorRect( v, cx - w*0.5 - 30, cy - 18, cx + w*0.5 + 30, cy - 15, FeedbackColor );
	PaintColorRect( v, cx - w*0.5 - 30, cy + 15, cx + w*0.5 + 30, cy + 18, FeedbackColor );
	PaintCenteredText( v, cx, cy, FeedbackColor, FeedbackText );
}

function PaintComplete( v )
{
	local cx = (TREE_PANEL_X0 + TREE_PANEL_X1) * 0.5;
	local cy = (TREE_PANEL_Y0 + TREE_PANEL_Y1) * 0.5;
	local w = 780.0;
	local h = 100.0;

	PaintColorRect( v, cx - w*0.5, cy - h*0.5, cx + w*0.5, cy + h*0.5, [ 5, 30, 28, 240 ] );
	PaintColorRect( v, cx - w*0.5, cy - h*0.5, cx + w*0.5, cy - h*0.5 + 3, COLOR_WARN_GREEN );
	PaintColorRect( v, cx - w*0.5, cy + h*0.5 - 3, cx + w*0.5, cy + h*0.5, COLOR_WARN_GREEN );

	PaintCenteredText( v, cx, cy - 18, COLOR_HEADER_TEXT, "EMERGENCY SYSTEMS RESTORED" );
	PaintCenteredText( v, cx, cy + 20, COLOR_HEADER_STATUS, "FACILITY CONTROL REGAINED" );
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

	local newHover = -1;
	for ( local i = 0; i < Systems_t.len(); i++ )
	{
		local cx = ScreenX_t[i];
		local cy = ScreenY_t[i];
		if ( PointInRect( dx, dy, cx - NODE_W*0.5, cy - NODE_H*0.5,
		                        cx + NODE_W*0.5, cy + NODE_H*0.5 ) )
		{
			newHover = i;
			break;
		}
	}
	HoverRow = newHover;

	local lmb = false;
	if ( "mouse_left" in table && table["mouse_left"] ) lmb = true;
	if ( !lmb ) { bPressedLMB = false; return; }
	if ( bPressedLMB ) return;
	bPressedLMB = true;

	if ( Phase != "running" ) return;
	if ( HoverRow < 0 ) return;

	AttemptActivate( HoverRow );
}

// =========================================================
//  INIT
// =========================================================
LastTickTime <- Time();
GlobalTime <- LastTickTime;
DebugLastLog <- 0.0;