// =========================================================
//  COOLANT PRESSURE BALANCING -- CLIENT
//  Client is authoritative. Infinite attempts.
//  Drift applies only to isolated zones, so connected-zone
//  equilibrium matches the generator's average calculation.
// =========================================================
FONT_DEFAULTLARGE <- self.LookupFont("DefaultLarge");

bDebugLog <- false;

const DESIGN_W = 1600.0;
const DESIGN_H = 900.0;
const PI = 3.14159265;

const DIFFICULTY = 2;

const DRIFT_RATE      = 0.60;
const TRANSFER_RATE   = 1.80;
const VALVE_ANIM_RATE = 5.00;
const STABLE_HOLD_TIME = 1.5;

const INPUT_START   = 1;
const INPUT_SUCCESS = 2;

ZONE_COUNT  <- 4;
SAFE_MIN    <- 45;
SAFE_MAX    <- 65;
CRIT_MARGIN <- 15;

if ( DIFFICULTY == 0 )
{
	ZONE_COUNT = 3; SAFE_MIN = 42; SAFE_MAX = 68; CRIT_MARGIN = 20;
}
else if ( DIFFICULTY == 2 )
{
	ZONE_COUNT = 6; SAFE_MIN = 48; SAFE_MAX = 62; CRIT_MARGIN = 12;
}

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

COLOR_PIPE_DARK     <- [  22,  42,  48, 255 ];
COLOR_PIPE_LIGHT    <- [  50,  85,  92, 255 ];
COLOR_PIPE_FLOW     <- [  83, 200, 190, 255 ];

COLOR_GAUGE_BEZEL   <- [  72,  92,  98, 255 ];
COLOR_GAUGE_FACE    <- [   6,  15,  20, 255 ];
COLOR_GAUGE_TICK    <- [ 160, 190, 195, 255 ];

COLOR_SAFE          <- [  83, 220, 150, 255 ];
COLOR_WARN          <- [ 240, 200,  80, 255 ];
COLOR_CRIT          <- [ 222,  67,  61, 255 ];
COLOR_NEEDLE        <- [ 240, 240, 240, 255 ];
COLOR_NEEDLE_SHADOW <- [   0,   0,   0, 210 ];

COLOR_VALVE_BODY    <- [  50,  66,  72, 255 ];
COLOR_VALVE_HUB     <- [  95, 115, 120, 255 ];
COLOR_VALVE_HANDLE  <- [ 210, 215, 215, 255 ];
COLOR_VALVE_CLOSED  <- [ 200,  90,  75, 255 ];
COLOR_VALVE_OPEN    <- [  83, 220, 150, 255 ];
COLOR_VALVE_HOVER   <- [ 104, 241, 220, 255 ];

COLOR_WARN_YELLOW   <- [ 240, 200,  80, 255 ];
COLOR_WARN_RED      <- [ 222,  67,  61, 255 ];
COLOR_WARN_GREEN    <- [  83, 220, 150, 255 ];

Phase          <- "standby";
Zones_t        <- [];
Valves_t       <- [];
StableTimer    <- 0.0;
LastTickTime   <- 0.0;
GlobalTime     <- 0.0;
bSentStart     <- false;
bSentEnd       <- false;
bPressedLMF    <- false;
HoverValve     <- -1;
DebugLastLog   <- 0.0;

// =========================================================
//  VIEW / PAINT HELPERS
// =========================================================
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
function ClampF( v, lo, hi )
{
	if ( v < lo ) return lo;
	if ( v > hi ) return hi;
	return v;
}

function DrawLine( view, x0, y0, x1, y1, thickness, col )
{
	local dx = x1 - x0;
	local dy = y1 - y0;
	local adx = fabs(dx);
	local ady = fabs(dy);
	local span = adx > ady ? adx : ady;
	local steps = ( span / 2.0 ).tointeger();
	if ( steps < 4 ) steps = 4;
	if ( steps > 120 ) steps = 120;

	for ( local i = 0; i <= steps; i++ )
	{
		local t = i.tofloat() / steps;
		local x = x0 + dx * t;
		local y = y0 + dy * t;
		PaintColorRect( view, x - thickness * 0.5, y - thickness * 0.5,
			x + thickness * 0.5, y + thickness * 0.5, col );
	}
}

function DrawArc( view, cx, cy, r, a0, a1, thickness, col )
{
	local spanAng = fabs( a0 - a1 );
	local steps = ( spanAng / 3.0 ).tointeger();
	if ( steps < 8 ) steps = 8;
	if ( steps > 120 ) steps = 120;

	for ( local i = 0; i <= steps; i++ )
	{
		local t = i.tofloat() / steps;
		local a = ( a0 + ( a1 - a0 ) * t ) * PI / 180.0;
		local x = cx + r * cos(a);
		local y = cy - r * sin(a);
		PaintColorRect( view, x - thickness * 0.5, y - thickness * 0.5,
			x + thickness * 0.5, y + thickness * 0.5, col );
	}
}

// =========================================================
//  LAYOUT -- bigger panels, valves in clear gaps between them
// =========================================================
function BuildLayout()
{
	if ( ZONE_COUNT == 3 )
	{
		local pw = 420, ph = 320;
		local xs = [90, 590, 1090];
		local yPos = 300;
		for ( local i = 0; i < 3; i++ )
		{
			Zones_t[i].panelX = xs[i];
			Zones_t[i].panelY = yPos;
			Zones_t[i].panelW = pw;
			Zones_t[i].panelH = ph;
		}
		local cy = yPos + ph * 0.5;
		Valves_t[0].x = ( xs[0] + pw + xs[1] ) * 0.5;
		Valves_t[0].y = cy;
		Valves_t[1].x = ( xs[1] + pw + xs[2] ) * 0.5;
		Valves_t[1].y = cy;
	}
	else if ( ZONE_COUNT == 4 )
	{
		local pw = 440, ph = 270;
		Zones_t[0].panelX = 90;   Zones_t[0].panelY = 175; Zones_t[0].panelW = pw; Zones_t[0].panelH = ph;
		Zones_t[1].panelX = 1070; Zones_t[1].panelY = 175; Zones_t[1].panelW = pw; Zones_t[1].panelH = ph;
		Zones_t[2].panelX = 1070; Zones_t[2].panelY = 540; Zones_t[2].panelW = pw; Zones_t[2].panelH = ph;
		Zones_t[3].panelX = 90;   Zones_t[3].panelY = 540; Zones_t[3].panelW = pw; Zones_t[3].panelH = ph;

		Valves_t[0].x = ( Zones_t[0].panelX + pw + Zones_t[1].panelX ) * 0.5;
		Valves_t[0].y = Zones_t[0].panelY + ph * 0.5;

		Valves_t[1].x = Zones_t[1].panelX + pw * 0.5;
		Valves_t[1].y = ( Zones_t[1].panelY + ph + Zones_t[2].panelY ) * 0.5;

		Valves_t[2].x = ( Zones_t[3].panelX + pw + Zones_t[2].panelX ) * 0.5;
		Valves_t[2].y = Zones_t[2].panelY + ph * 0.5;

		Valves_t[3].x = Zones_t[0].panelX + pw * 0.5;
		Valves_t[3].y = ( Zones_t[0].panelY + ph + Zones_t[3].panelY ) * 0.5;
	}
	else
	{
		local pw = 380, ph = 220;
		local xs = [100, 610, 1120];
		local ys = [200, 560];

		Zones_t[0].panelX = xs[0]; Zones_t[0].panelY = ys[0]; Zones_t[0].panelW = pw; Zones_t[0].panelH = ph;
		Zones_t[1].panelX = xs[1]; Zones_t[1].panelY = ys[0]; Zones_t[1].panelW = pw; Zones_t[1].panelH = ph;
		Zones_t[2].panelX = xs[2]; Zones_t[2].panelY = ys[0]; Zones_t[2].panelW = pw; Zones_t[2].panelH = ph;
		Zones_t[3].panelX = xs[2]; Zones_t[3].panelY = ys[1]; Zones_t[3].panelW = pw; Zones_t[3].panelH = ph;
		Zones_t[4].panelX = xs[1]; Zones_t[4].panelY = ys[1]; Zones_t[4].panelW = pw; Zones_t[4].panelH = ph;
		Zones_t[5].panelX = xs[0]; Zones_t[5].panelY = ys[1]; Zones_t[5].panelW = pw; Zones_t[5].panelH = ph;

		Valves_t[0].x = ( xs[0] + pw + xs[1] ) * 0.5; Valves_t[0].y = ys[0] + ph * 0.5;
		Valves_t[1].x = ( xs[1] + pw + xs[2] ) * 0.5; Valves_t[1].y = ys[0] + ph * 0.5;
		Valves_t[2].x = xs[2] + pw * 0.5;             Valves_t[2].y = ( ys[0] + ph + ys[1] ) * 0.5;
		Valves_t[3].x = ( xs[1] + pw + xs[2] ) * 0.5; Valves_t[3].y = ys[1] + ph * 0.5;
		Valves_t[4].x = ( xs[0] + pw + xs[1] ) * 0.5; Valves_t[4].y = ys[1] + ph * 0.5;
		Valves_t[5].x = xs[0] + pw * 0.5;             Valves_t[5].y = ( ys[0] + ph + ys[1] ) * 0.5;
	}
}

// =========================================================
//  PUZZLE GENERATION
// =========================================================
function GetValveTopology()
{
	if ( ZONE_COUNT == 3 ) return [ [0,1], [1,2] ];
	if ( ZONE_COUNT == 4 ) return [ [0,1], [1,2], [2,3], [3,0] ];
	return [ [0,1], [1,2], [2,3], [3,4], [4,5], [5,0] ];
}

// With drift-on-isolated only, equilibrium is:
//   isolated zones sit at their base pressure
//   connected zones sit at the average of bases in their component
// This is exactly what the physical simulation converges to, so this
// function's answer matches the real physics.
function ComputeEquilibrium( bases, openList, topo )
{
	local n = bases.len();
	local rootArr = [];
	for ( local i = 0; i < n; i++ ) rootArr.push( i );

	for ( local v = 0; v < openList.len(); v++ )
	{
		if ( !openList[v] ) continue;
		local a = topo[v][0];
		local b = topo[v][1];

		local ra = a;
		while ( rootArr[ra] != ra ) ra = rootArr[ra];
		local rb = b;
		while ( rootArr[rb] != rb ) rb = rootArr[rb];
		if ( ra != rb ) rootArr[ra] = rb;
	}
	for ( local i = 0; i < n; i++ )
	{
		local r = i;
		while ( rootArr[r] != r ) r = rootArr[r];
		rootArr[i] = r;
	}

	local sumArr = [], cntArr = [];
	for ( local i = 0; i < n; i++ ) { sumArr.push( 0.0 ); cntArr.push( 0 ); }
	for ( local i = 0; i < n; i++ )
	{
		local r = rootArr[i];
		sumArr[r] += bases[i];
		cntArr[r]++;
	}
	local res = [];
	for ( local i = 0; i < n; i++ )
		res.push( sumArr[ rootArr[i] ] / cntArr[ rootArr[i] ] );
	return res;
}

function AllInSafe( pressures, sMin, sMax )
{
	for ( local i = 0; i < pressures.len(); i++ )
		if ( pressures[i] < sMin || pressures[i] > sMax ) return false;
	return true;
}

function CountDiff( a, b )
{
	local n = 0;
	for ( local i = 0; i < a.len(); i++ ) if ( a[i] != b[i] ) n++;
	return n;
}

function GeneratePuzzle()
{
	local n = ZONE_COUNT;
	local topo = GetValveTopology();
	local vCount = topo.len();
	local total = 1;
	for ( local i = 0; i < vCount; i++ ) total *= 2;

	local result = null;

	for ( local attempt = 0; attempt < 400; attempt++ )
	{
		local bases = [];
		for ( local i = 0; i < n; i++ )
			bases.push( RandomFloat( 12.0, 88.0 ) );

		local startOpen = [];
		for ( local v = 0; v < vCount; v++ )
			startOpen.push( RandomInt( 0, 1 ) == 0 );

		local startEq = ComputeEquilibrium( bases, startOpen, topo );
		if ( AllInSafe( startEq, SAFE_MIN, SAFE_MAX ) ) continue;

		local bestDiff = -1;
		local bestSub = null;
		for ( local sub = 0; sub < total; sub++ )
		{
			local subset = [];
			for ( local v = 0; v < vCount; v++ )
				subset.push( ( ( sub >> v ) & 1 ) != 0 );

			local eq = ComputeEquilibrium( bases, subset, topo );
			if ( !AllInSafe( eq, SAFE_MIN, SAFE_MAX ) ) continue;

			local diff = CountDiff( subset, startOpen );
			if ( diff >= 2 && diff > bestDiff )
			{
				bestDiff = diff;
				bestSub = subset;
			}
		}
		if ( bestSub == null ) continue;

		result = { baseArr = bases, startOpen = startOpen };
		break;
	}

	if ( result == null )
	{
		local bases = [];
		for ( local i = 0; i < n; i++ )
			bases.push( 30.0 + i * 10.0 );
		local startOpen = [];
		for ( local v = 0; v < vCount; v++ )
			startOpen.push( false );
		result = { baseArr = bases, startOpen = startOpen };
	}
	return result;
}

// =========================================================
//  GAME START
// =========================================================
function StartGame()
{
	local n = ZONE_COUNT;
	local topo = GetValveTopology();

	local puzzle = GeneratePuzzle();
	local names = ["A","B","C","D","E","F"];

	// Zones start at the equilibrium of the start-valve state.
	local startEq = ComputeEquilibrium( puzzle.baseArr, puzzle.startOpen, topo );

	Zones_t = [];
	for ( local i = 0; i < n; i++ )
	{
		Zones_t.push({
			name = names[i],
			basePressure = puzzle.baseArr[i],
			pressure = startEq[i],
			safeMin = SAFE_MIN,
			safeMax = SAFE_MAX,
			panelX = 0, panelY = 0, panelW = 0, panelH = 0
		});
	}

	Valves_t = [];
	for ( local v = 0; v < topo.len(); v++ )
	{
		local isOpen = puzzle.startOpen[v];
		Valves_t.push({
			a = topo[v][0],
			b = topo[v][1],
			openness = isOpen ? 1.0 : 0.0,
			target   = isOpen ? 1.0 : 0.0,
			x = 0, y = 0
		});
	}

	BuildLayout();

	StableTimer = 0.0;
	LastTickTime = Time();
	GlobalTime = Time();
	Phase = "running";
}

function GetZoneStatus( z )
{
	if ( z.pressure >= z.safeMin && z.pressure <= z.safeMax ) return "safe";
	if ( z.pressure < z.safeMin )
	{
		if ( z.pressure < z.safeMin - CRIT_MARGIN ) return "crit_low";
		return "low";
	}
	if ( z.pressure > z.safeMax + CRIT_MARGIN ) return "crit_high";
	return "high";
}
function GetZoneStatusText( st )
{
	if ( st == "safe" )      return "SAFE";
	if ( st == "low" )       return "LOW";
	if ( st == "high" )      return "HIGH";
	if ( st == "crit_low" )  return "CRIT LOW";
	return "CRIT HIGH";
}
function GetZoneStatusColor( st )
{
	if ( st == "safe" ) return COLOR_SAFE;
	if ( st == "crit_low" || st == "crit_high" ) return COLOR_CRIT;
	return COLOR_WARN;
}

// =========================================================
//  SIMULATION
// =========================================================
function UpdateSimulation( dt )
{
	local n = Zones_t.len();

	// Advance valve animation; record which zones have an active valve.
	local connected = [];
	for ( local i = 0; i < n; i++ ) connected.push( 0 );

	for ( local v = 0; v < Valves_t.len(); v++ )
	{
		local val = Valves_t[v];
		local d = val.target - val.openness;
		local step = VALVE_ANIM_RATE * dt;
		if ( fabs( d ) <= step ) val.openness = val.target;
		else if ( d > 0 )        val.openness += step;
		else                     val.openness -= step;

		if ( val.openness > 0.01 )
		{
			connected[val.a]++;
			connected[val.b]++;
		}
	}

	// Only ISOLATED zones drift toward their base pressure.
	for ( local i = 0; i < n; i++ )
	{
		if ( connected[i] > 0 ) continue;
		local z = Zones_t[i];
		z.pressure += ( z.basePressure - z.pressure ) * DRIFT_RATE * dt;
	}

	// Transfer through open valves.
	for ( local v = 0; v < Valves_t.len(); v++ )
	{
		local val = Valves_t[v];
		if ( val.openness <= 0.01 ) continue;

		local a = Zones_t[val.a];
		local b = Zones_t[val.b];
		local flow = ( a.pressure - b.pressure ) * TRANSFER_RATE * val.openness * dt;
		a.pressure -= flow;
		b.pressure += flow;
	}

	for ( local i = 0; i < n; i++ )
		Zones_t[i].pressure = ClampF( Zones_t[i].pressure, 0.0, 100.0 );

	local allSafe = true;
	for ( local i = 0; i < n; i++ )
		if ( GetZoneStatus( Zones_t[i] ) != "safe" ) { allSafe = false; break; }

	if ( allSafe ) StableTimer += dt;
	else           StableTimer = 0.0;

	if ( StableTimer >= STABLE_HOLD_TIME && Phase == "running" )
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
	if ( dt < 0.0 ) dt = 0.0;
	if ( dt > 0.15 ) dt = 0.15;
	LastTickTime = now;
	GlobalTime = now;

	if ( Phase == "running" ) UpdateSimulation( dt );
	else
	{
		for ( local v = 0; v < Valves_t.len(); v++ )
		{
			local val = Valves_t[v];
			local d = val.target - val.openness;
			local step = VALVE_ANIM_RATE * dt;
			if ( fabs( d ) <= step ) val.openness = val.target;
			else if ( d > 0 )        val.openness += step;
			else                     val.openness -= step;
		}
	}

	UpdateFromServer();

	if ( bDebugLog && now - DebugLastLog > 1.0 )
	{
		DebugLastLog = now;
		Msg( "coolant pkt: [" + self.GetString( 0 ) + "]" );
	}

	local view  = GetDesignView();
	local pulse = ( sin( Time() * 1.2 ) + 1.0 ) * 0.5;

	// Draw order: background -> header -> pipes -> zones -> valves -> overlay.
	// Valves come AFTER zones so they are never hidden by panel edges.
	PaintBackground( view, pulse );
	PaintHeader( view );
	PaintLEDs( view );
	PaintPipes( view );
	PaintZones( view );
	PaintValves( view );
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
	PaintColorText( view, 78, 26, COLOR_HEADER_TEXT, "COOLANT PRESSURE BALANCING" );

	local statusText, statusColor;
	if ( Phase == "standby" )       { statusText = "STANDBY";         statusColor = COLOR_HEADER_STATUS; }
	else if ( Phase == "complete" ) { statusText = "PRESSURE STABLE"; statusColor = COLOR_WARN_GREEN; }
	else                            { statusText = "BALANCING";       statusColor = COLOR_HEADER_STATUS; }

	local w = TextWideDesign( view, statusText );
	PaintColorText( view, 1500 - w, 30, statusColor, statusText );

	PaintColorRect( view, 70, 74, 1530, 76, COLOR_BG_EDGE );
}

function PaintLEDs( view )
{
	local ledX = 1420.0;
	local ledY = 92.0;

	local anyCrit = false;
	for ( local i = 0; i < Zones_t.len(); i++ )
	{
		local st = GetZoneStatus( Zones_t[i] );
		if ( st == "crit_low" || st == "crit_high" ) { anyCrit = true; break; }
	}
	local blink = ( sin( Time() * 8.0 ) > 0 );
	local litRed    = anyCrit && blink;
	local litYellow = ( StableTimer > 0.0 ) && !anyCrit;
	local litGreen  = ( Phase == "complete" );

	PaintColorRect( view, ledX,      ledY, ledX + 14, ledY + 14, litRed    ? COLOR_WARN_RED    : [40, 20, 20, 255] );
	PaintColorRect( view, ledX + 22, ledY, ledX + 36, ledY + 14, litYellow ? COLOR_WARN_YELLOW : [40, 36, 12, 255] );
	PaintColorRect( view, ledX + 44, ledY, ledX + 58, ledY + 14, litGreen  ? COLOR_WARN_GREEN  : [20, 40, 26, 255] );
}

function EdgePointToward( z, tx, ty )
{
	local cx = z.panelX + z.panelW * 0.5;
	local cy = z.panelY + z.panelH * 0.5;
	local dx = tx - cx;
	local dy = ty - cy;
	if ( fabs(dx) > fabs(dy) )
	{
		if ( dx > 0 ) return [ z.panelX + z.panelW, cy ];
		return [ z.panelX, cy ];
	}
	if ( dy > 0 ) return [ cx, z.panelY + z.panelH ];
	return [ cx, z.panelY ];
}

function PaintPipes( view )
{
	for ( local v = 0; v < Valves_t.len(); v++ )
	{
		local val = Valves_t[v];
		local za = Zones_t[val.a];
		local zb = Zones_t[val.b];

		local aEdge = EdgePointToward( za, val.x, val.y );
		local bEdge = EdgePointToward( zb, val.x, val.y );

		DrawLine( view, aEdge[0], aEdge[1], val.x, val.y, 22, COLOR_PIPE_DARK );
		DrawLine( view, val.x, val.y, bEdge[0], bEdge[1], 22, COLOR_PIPE_DARK );
		DrawLine( view, aEdge[0], aEdge[1], val.x, val.y, 10, COLOR_PIPE_LIGHT );
		DrawLine( view, val.x, val.y, bEdge[0], bEdge[1], 10, COLOR_PIPE_LIGHT );

		if ( val.openness > 0.1 )
		{
			local diff = Zones_t[val.a].pressure - Zones_t[val.b].pressure;
			if ( fabs( diff ) > 2.0 )
			{
				local srcX = ( diff > 0 ) ? aEdge[0] : bEdge[0];
				local srcY = ( diff > 0 ) ? aEdge[1] : bEdge[1];
				local dstX = ( diff > 0 ) ? bEdge[0] : aEdge[0];
				local dstY = ( diff > 0 ) ? bEdge[1] : aEdge[1];

				local t0 = GlobalTime * 1.5;
				for ( local k = 0; k < 3; k++ )
				{
					local t = t0 + k * 0.33;
					while ( t >= 1.0 ) t -= 1.0;
					while ( t < 0.0 ) t += 1.0;

					local dotX = srcX + ( dstX - srcX ) * t;
					local dotY = srcY + ( dstY - srcY ) * t;
					PaintColorRect( view, dotX - 3, dotY - 3, dotX + 3, dotY + 3, COLOR_PIPE_FLOW );
				}
			}
		}
	}
}

// ----- Zones -----
function PaintZones( view )
{
	for ( local i = 0; i < Zones_t.len(); i++ )
		PaintZonePanel( view, Zones_t[i] );
}

function PaintZonePanel( view, z )
{
	local x0 = z.panelX;
	local y0 = z.panelY;
	local x1 = x0 + z.panelW;
	local y1 = y0 + z.panelH;

	local st = GetZoneStatus( z );
	local statusCol = GetZoneStatusColor( st );

	local jitterX = 0.0, jitterY = 0.0;
	if ( st == "crit_low" || st == "crit_high" )
	{
		jitterX = sin( Time() * 60.0 ) * 2.0;
		jitterY = cos( Time() * 55.0 ) * 2.0;
	}
	x0 += jitterX; x1 += jitterX;
	y0 += jitterY; y1 += jitterY;

	// Panel body.
	PaintColorRect( view, x0, y0, x1, y1, COLOR_PANEL_BG );
	PaintColorRect( view, x0 + 4, y0 + 4, x1 - 4, y1 - 4, COLOR_PANEL_INNER );
	PaintColorRect( view, x0, y0, x1, y0 + 3, COLOR_PANEL_BORDER );
	PaintColorRect( view, x0, y1 - 3, x1, y1, COLOR_PANEL_BORDER );
	PaintColorRect( view, x0, y0, x0 + 3, y1, COLOR_PANEL_BORDER );
	PaintColorRect( view, x1 - 3, y0, x1, y1, COLOR_PANEL_BORDER );

	// Corner bolts.
	local bs = 6, bpad = 8;
	PaintColorRect( view, x0 + bpad, y0 + bpad, x0 + bpad + bs, y0 + bpad + bs, [40, 70, 78, 255] );
	PaintColorRect( view, x1 - bpad - bs, y0 + bpad, x1 - bpad, y0 + bpad + bs, [40, 70, 78, 255] );
	PaintColorRect( view, x0 + bpad, y1 - bpad - bs, x0 + bpad + bs, y1 - bpad, [40, 70, 78, 255] );
	PaintColorRect( view, x1 - bpad - bs, y1 - bpad - bs, x1 - bpad, y1 - bpad, [40, 70, 78, 255] );

	// Header strip.
	PaintColorText( view, x0 + 18, y0 + 10, COLOR_HEADER_TEXT, "ZONE " + z.name );

	local statusText = GetZoneStatusText( st );
	local stW = TextWideDesign( view, statusText );
	PaintColorText( view, x1 - 18 - stW, y0 + 10, statusCol, statusText );
	PaintColorRect( view, x0 + 14, y0 + 36, x1 - 14, y0 + 37, [40, 70, 78, 200] );

	// Gauge radius scales with panel size.
	local gaugeR;
	if ( z.panelH >= 300 )      gaugeR = 100;
	else if ( z.panelH >= 250 ) gaugeR = 88;
	else                        gaugeR = 62;

	local gaugeCx = x0 + z.panelW * 0.5;
	local gaugeCy = y0 + 36 + 8 + gaugeR;

	// Bezel ring (outer metal ring).
	DrawArc( view, gaugeCx, gaugeCy, gaugeR,     240, -60, 6, COLOR_GAUGE_BEZEL );
	// Face (thick dark ring).
	DrawArc( view, gaugeCx, gaugeCy, gaugeR - 10, 240, -60, 16, COLOR_GAUGE_FACE );

	// Angular layout: 0% -> 210, 100% -> -30.
	local pCritLow  = ClampF( ( z.safeMin - CRIT_MARGIN ).tofloat(), 0.0, 100.0 );
	local pSafeMin  = z.safeMin.tofloat();
	local pSafeMax  = z.safeMax.tofloat();
	local pCritHigh = ClampF( ( z.safeMax + CRIT_MARGIN ).tofloat(), 0.0, 100.0 );

	local a_0        =  210.0;
	local a_critLow  =  210.0 - ( pCritLow  / 100.0 ) * 240.0;
	local a_safeMin  =  210.0 - ( pSafeMin  / 100.0 ) * 240.0;
	local a_safeMax  =  210.0 - ( pSafeMax  / 100.0 ) * 240.0;
	local a_critHigh =  210.0 - ( pCritHigh / 100.0 ) * 240.0;
	local a_100      =  -30.0;

	// Color bands sit on the ring at radius gaugeR - 14, thickness 10.
	local bandR = gaugeR - 14.0;
	if ( pCritLow > 0.5 )
		DrawArc( view, gaugeCx, gaugeCy, bandR, a_0,        a_critLow,  10, COLOR_CRIT );
	DrawArc( view, gaugeCx, gaugeCy, bandR, a_critLow,  a_safeMin,  10, COLOR_WARN );
	DrawArc( view, gaugeCx, gaugeCy, bandR, a_safeMin,  a_safeMax,  10, COLOR_SAFE );
	DrawArc( view, gaugeCx, gaugeCy, bandR, a_safeMax,  a_critHigh, 10, COLOR_WARN );
	if ( pCritHigh < 99.5 )
		DrawArc( view, gaugeCx, gaugeCy, bandR, a_critHigh, a_100,      10, COLOR_CRIT );

	// Tick marks inside the bands.
	for ( local p = 0; p <= 100; p += 10 )
	{
		local ang = ( 210.0 - ( p.tofloat() / 100.0 ) * 240.0 ) * PI / 180.0;
		local outerR = gaugeR - 24;
		local innerR = gaugeR - 30;
		if ( p == 0 || p == 50 || p == 100 ) innerR = gaugeR - 36;

		local tx0 = gaugeCx + cos(ang) * outerR;
		local ty0 = gaugeCy - sin(ang) * outerR;
		local tx1 = gaugeCx + cos(ang) * innerR;
		local ty1 = gaugeCy - sin(ang) * innerR;

		DrawLine( view, tx0, ty0, tx1, ty1, 2.0, COLOR_GAUGE_TICK );
	}

	// Needle.
	local needleA = ( 210.0 - ( z.pressure / 100.0 ) * 240.0 ) * PI / 180.0;
	local nlen = gaugeR - 30;
	local nx = gaugeCx + cos(needleA) * nlen;
	local ny = gaugeCy - sin(needleA) * nlen;

	DrawLine( view, gaugeCx + 1, gaugeCy + 1, nx + 1, ny + 1, 5, COLOR_NEEDLE_SHADOW );
	DrawLine( view, gaugeCx, gaugeCy, nx, ny, 3, COLOR_NEEDLE );

	// Center hub.
	PaintColorRect( view, gaugeCx - 8, gaugeCy - 8, gaugeCx + 8, gaugeCy + 8, COLOR_GAUGE_BEZEL );
	PaintColorRect( view, gaugeCx - 4, gaugeCy - 4, gaugeCx + 4, gaugeCy + 4, COLOR_GAUGE_FACE );

	// Pressure readout (below gauge).
	local pText = ( z.pressure + 0.5 ).tointeger().tostring() + "%";
	PaintCenteredText( view, gaugeCx, y0 + z.panelH - 44, statusCol, pText );

	// Safe range caption.
	local safeText = "SAFE " + z.safeMin.tostring() + "-" + z.safeMax.tostring() + "%";
	PaintCenteredText( view, gaugeCx, y0 + z.panelH - 16, COLOR_GAUGE_TICK, safeText );

	// Critical effects.
	if ( st == "crit_high" )
	{
		for ( local k = 0; k < 4; k++ )
		{
			local t = GlobalTime * 0.8 + k * 0.25;
			while ( t >= 1.0 ) t -= 1.0;
			local steamX = gaugeCx + sin( GlobalTime * 3.0 + k * 2.0 ) * 15.0;
			local steamY = y0 - t * 40.0;
			local size = 8.0 + t * 6.0;
			local alpha = ( ( 1.0 - t ) * 180.0 ).tointeger();
			PaintColorRect( view, steamX - size, steamY - size, steamX + size, steamY + size,
				[ 200, 200, 200, alpha ] );
		}
	}
	if ( st == "crit_low" )
	{
		if ( sin( Time() * 10.0 ) > 0.3 )
		{
			PaintColorRect( view, x0 + 3, y0 + 3, x1 - 3, y0 + 6, COLOR_CRIT );
			PaintColorRect( view, x0 + 3, y1 - 6, x1 - 3, y1 - 3, COLOR_CRIT );
		}
	}
}

// ----- Valves (drawn ON TOP of zones) -----
function PaintValves( view )
{
	for ( local v = 0; v < Valves_t.len(); v++ )
	{
		local val = Valves_t[v];
		local cx = val.x;
		local cy = val.y;
		local r = 36.0;
		local hovered = ( HoverValve == v );

		PaintColorRect( view, cx - r, cy - r, cx + r, cy + r, COLOR_VALVE_BODY );

		local ringCol;
		if ( hovered )                ringCol = COLOR_VALVE_HOVER;
		else if ( val.openness > 0.5 ) ringCol = COLOR_VALVE_OPEN;
		else                          ringCol = COLOR_VALVE_CLOSED;

		local rt = 4.0;
		PaintColorRect( view, cx - r,      cy - r,      cx + r,      cy - r + rt, ringCol );
		PaintColorRect( view, cx - r,      cy + r - rt, cx + r,      cy + r,      ringCol );
		PaintColorRect( view, cx - r,      cy - r,      cx - r + rt, cy + r,      ringCol );
		PaintColorRect( view, cx + r - rt, cy - r,      cx + r,      cy + r,      ringCol );

		// Handle bar.
		local angle = -90.0 + 90.0 * val.openness;
		local a = angle * PI / 180.0;
		local barLen = r - 6;
		local bx = cos(a) * barLen;
		local by = -sin(a) * barLen;

		local barT = 5.0;
		local steps = 10;
		for ( local i = 0; i <= steps; i++ )
		{
			local t = ( i.tofloat() / steps ) * 2.0 - 1.0;
			local px = cx + bx * t;
			local py = cy + by * t;
			PaintColorRect( view, px - barT*0.5, py - barT*0.5, px + barT*0.5, py + barT*0.5, COLOR_VALVE_HANDLE );
		}

		// Hub with label.
		PaintColorRect( view, cx - 14, cy - 14, cx + 14, cy + 14, COLOR_VALVE_HUB );
		PaintColorRect( view, cx - 11, cy - 11, cx + 11, cy + 11, COLOR_VALVE_BODY );

		local label = "V" + ( v + 1 ).tostring();
		PaintCenteredText( view, cx, cy, COLOR_HEADER_TEXT, label );
	}
}

function PaintComplete( view )
{
	local x0 = 350, x1 = 1250, y0 = 90, y1 = 176;
	PaintColorRect( view, x0, y0, x1, y1, [ 8, 45, 42, 250 ] );
	PaintColorRect( view, x0, y0, x1, y0 + 3, COLOR_WARN_GREEN );
	PaintColorRect( view, x0, y1 - 3, x1, y1, COLOR_WARN_GREEN );
	PaintCenteredText( view, ( x0 + x1 ) * 0.5, y0 + 26, COLOR_HEADER_TEXT, "COOLANT PRESSURE STABLE" );
	PaintCenteredText( view, ( x0 + x1 ) * 0.5, y0 + 62, COLOR_HEADER_STATUS, "REACTOR TEMPERATURE NOMINAL" );
}

function UpdateFromServer()
{
	local packet = self.GetString( 0 );
	if ( packet == "" ) return;
	local fields = split( packet, "|" );
	if ( fields.len() < 1 ) return;

	local newState = fields[0];
	if ( newState == "complete" && Phase != "complete" ) Phase = "complete";
}

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
	local hitR = 44.0;
	for ( local v = 0; v < Valves_t.len(); v++ )
	{
		local val = Valves_t[v];
		local dx = designX - val.x;
		local dy = designY - val.y;
		if ( dx*dx + dy*dy <= hitR*hitR ) { newHover = v; break; }
	}
	HoverValve = newHover;

	local lmbDown = false;
	if ( "mouse_left" in table && table["mouse_left"] ) lmbDown = true;

	if ( !lmbDown ) { bPressedLMF = false; return; }
	if ( bPressedLMF ) return;
	bPressedLMF = true;

	if ( Phase != "running" ) return;
	if ( HoverValve < 0 ) return;

	local val = Valves_t[ HoverValve ];
	if ( val.target > 0.5 ) val.target = 0.0;
	else                    val.target = 1.0;
}