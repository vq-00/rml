// =========================================================
//  INTRUSION DETECTION -- CLIENT
//  Processes travel along lanes. Each shows PID, name, and
//  four status dots (SIG/ORG/PRIV/MEM). Red dot = flag.
//  Hostile = 2+ flags.  Legit = 0-1 flags.
//  Continuous waves; only SUCCESS ends the run.
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

LANE_COUNT      <- 4;
WAVE_TOTAL      <- 8;
WAVE_MALICIOUS  <- 3;
SPAWN_INTERVAL  <- 1.30;
PROC_SPEED      <- 140.0;
TARGET_CONTAINED <- 3;

if ( DIFFICULTY == 0 )
{
	LANE_COUNT = 3; WAVE_TOTAL = 5; WAVE_MALICIOUS = 2;
	SPAWN_INTERVAL = 1.50; PROC_SPEED = 100.0; TARGET_CONTAINED = 2;
}
else if ( DIFFICULTY == 2 )
{
	LANE_COUNT = 4; WAVE_TOTAL = 20; WAVE_MALICIOUS = 8;
	SPAWN_INTERVAL = 0.30; PROC_SPEED = 360.0; TARGET_CONTAINED = 8;
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

COLOR_PROC_BG       <- [  15,  30,  38, 255 ];
COLOR_PROC_BG_SEL   <- [  30,  50,  60, 255 ];
COLOR_PROC_BORDER   <- [  60,  90, 100, 255 ];
COLOR_PROC_HOVER    <- [  90, 160, 170, 255 ];
COLOR_PROC_SELECTED <- [ 104, 241, 220, 255 ];

COLOR_OK            <- [  83, 220, 150, 255 ];
COLOR_FLAG          <- [ 240, 100,  90, 255 ];
COLOR_WARN_YELLOW   <- [ 240, 200,  80, 255 ];
COLOR_WARN_RED      <- [ 222,  67,  61, 255 ];
COLOR_WARN_GREEN    <- [  83, 220, 150, 255 ];

COLOR_BTN_ALLOW_BG     <- [  25,  70,  45, 255 ];
COLOR_BTN_ALLOW_BG_HOV <- [  40, 100,  70, 255 ];
COLOR_BTN_TERM_BG      <- [  80,  25,  25, 255 ];
COLOR_BTN_TERM_BG_HOV  <- [ 120,  40,  40, 255 ];

// ----- State -----
Phase          <- "standby";
Procs_t        <- [];
SpawnQueue_t   <- [];
NextSpawnIdx   <- 0;
NextSpawnTime  <- 0.0;
Contained      <- 0;
FalsePositives <- 0;
TotalTarget    <- 0;
SelectedProc   <- null;
HoverProc      <- null;
HoverButton    <- -1;
bSentStart     <- false;
bSentEnd       <- false;
bPressedLMB    <- false;
LastTickTime   <- 0.0;
GlobalTime     <- 0.0;
DebugLastLog   <- 0.0;

Message        <- "";
MessageColor   <- [ 255, 255, 255 ];
MessageExpire  <- 0.0;

// ----- Layout -----
const ARENA_X0 = 80.0;
const ARENA_X1 = 1520.0;
const ARENA_Y0 = 165.0;
const ARENA_Y1 = 625.0;
const PROC_W   = 260.0;
const PROC_H   = 84.0;

PROC_SPAWN_X   <- ARENA_X0 + 14.0;
// Despawn well before the card's right edge crosses the arena border,
// even accounting for one tick of overshoot (PROC_SPEED * dt).
PROC_DESPAWN_X <- ARENA_X1 - PROC_W - 40.0;

const DETAIL_X0 = 80.0;
const DETAIL_Y0 = 640.0;
const DETAIL_X1 = 1520.0;
const DETAIL_Y1 = 858.0;

const BTN_ALLOW_X0 = 1000.0;
const BTN_ALLOW_X1 = 1240.0;
const BTN_TERM_X0  = 1260.0;
const BTN_TERM_X1  = 1500.0;
const BTN_Y0       = 795.0;
const BTN_Y1       = 850.0;

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

function PickRandom(arr) { return arr[ RandomInt(0, arr.len()-1) ]; }

function GetLaneCenterY( lane )
{
	local laneH = (ARENA_Y1 - ARENA_Y0) / LANE_COUNT;
	return ARENA_Y0 + laneH * 0.5 + lane * laneH;
}

// Stats row: small label + large value, returns x after value.
function PaintSmallLabelLargeValue( v, lx, ly, label, value, valCol )
{
	PaintSmallText( v, lx, ly + 4.0, COLOR_HEADER_STATUS, label );
	local lw = SmallTextWideDesign( v, label );
	local vx = lx + lw + 10.0;
	PaintColorText( v, vx, ly, valCol, value );
	local vw = TextWideDesign( v, value );
	return vx + vw;
}

// Info field: small label + small value, no flag dot. Returns x after value.
function PaintInfoField( v, lx, ly, label, value, valCol )
{
	PaintSmallText( v, lx, ly, COLOR_HEADER_STATUS, label );
	local lw = SmallTextWideDesign( v, label );
	local vx = lx + lw + 10.0;
	PaintSmallText( v, vx, ly, valCol, value );
	local vw = SmallTextWideDesign( v, value );
	return vx + vw;
}

// Attribute row: small label + small value + flag dot. Returns x after dot.
function PaintAttrRow( v, lx, ly, label, value, flagged )
{
	PaintSmallText( v, lx, ly, COLOR_HEADER_STATUS, label );
	local lw = SmallTextWideDesign( v, label );
	local vx = lx + lw + 10.0;

	local valCol = flagged ? COLOR_FLAG : COLOR_OK;
	PaintSmallText( v, vx, ly, valCol, value );
	local vw = SmallTextWideDesign( v, value );

	local dotX = vx + vw + 12.0;
	local dotY = ly + 3.0;
	PaintColorRect( v, dotX-1, dotY-1, dotX + 9, dotY + 9, [0,0,0,150] );
	PaintColorRect( v, dotX,   dotY,   dotX + 8, dotY + 8, valCol );

	return dotX + 16.0;
}

// =========================================================
//  PROCESS GENERATION
// =========================================================
SigGreen_t  <- [ "VERIFIED", "SIGNED", "TRUSTED" ];
SigRed_t    <- [ "UNSIGNED", "INVALID", "REVOKED", "EXPIRED" ];
OrigGreen_t <- [ "LOCAL", "INTERNAL", "TRUSTED" ];
OrigRed_t   <- [ "EXTERNAL", "UNKNOWN", "SUSPECT" ];
PrivGreen_t <- [ "USER", "SVC", "ADMIN" ];
PrivRed_t   <- [ "ROOT", "KERNEL", "SYS_ADMIN" ];
MemGreen_t  <- [ "NOMINAL", "LOW", "STABLE" ];
MemRed_t    <- [ "ELEVATED", "ANOMALOUS", "CORRUPTED" ];

Name_t <- [
	"AUTH_SERVICE", "DB_INDEX", "NET_STACK", "FILE_CACHE",
	"SENSOR_POLL", "MEM_MGR", "LOG_WRITER", "TASK_SCHED",
	"POWER_MON", "SYS_PATCH", "TLS_HANDSHAKE", "SEG_HANDLER",
	"CRYPTO_KEYMGR", "DNS_RESOLVER", "GPU_QUEUE"
];
Dest_t <- [
	"SECTOR_DB", "AUTH_CORE", "MEMORY_BANK", "DATA_VAULT",
	"NET_IFACE", "GPU_QUEUE", "LOG_ARCHIVE", "CRYPTO_STORE"
];

function GenerateProcess( malicious )
{
	local flags = [ false, false, false, false ];

	if ( malicious )
	{
		if ( DIFFICULTY == 0 )
		{
			flags[0] = true;
			flags[1] = true;
		}
		else
		{
			local first = RandomInt(0, 1);
			flags[first] = true;
			local extra = RandomInt(1, 2);
			local pool = [];
			for ( local i = 0; i < 4; i++ )
				if ( !flags[i] ) pool.push( i );
			for ( local k = 0; k < extra && pool.len() > 0; k++ )
			{
				local pick = RandomInt(0, pool.len()-1);
				flags[ pool[pick] ] = true;
				pool.remove( pick );
			}
		}
	}
	else
	{
		local redCount = 0;
		if ( DIFFICULTY == 2 )      redCount = RandomInt(0, 1);
		else if ( DIFFICULTY == 1 ) redCount = ( RandomInt(0, 3) == 0 ) ? 1 : 0;
		if ( redCount == 1 ) flags[ RandomInt(0,3) ] = true;
	}

	return {
		pid         = RandomInt(1000, 9999),
		name        = PickRandom(Name_t),
		destination = PickRandom(Dest_t),
		sig         = flags[0] ? PickRandom(SigRed_t)   : PickRandom(SigGreen_t),
		orig        = flags[1] ? PickRandom(OrigRed_t)  : PickRandom(OrigGreen_t),
		priv        = flags[2] ? PickRandom(PrivRed_t)  : PickRandom(PrivGreen_t),
		mem         = flags[3] ? PickRandom(MemRed_t)   : PickRandom(MemGreen_t),
		sigFlag     = flags[0],
		origFlag    = flags[1],
		privFlag    = flags[2],
		memFlag     = flags[3],
		isMalicious = malicious,
		lane        = 0,
		x           = PROC_SPAWN_X,
		state       = "alive"
	};
}

// =========================================================
//  WAVE
// =========================================================
function PopulateSpawnQueue()
{
	SpawnQueue_t = [];

	for ( local i = 0; i < WAVE_TOTAL; i++ )
	{
		local mal = ( i < WAVE_MALICIOUS );
		SpawnQueue_t.push( GenerateProcess( mal ) );
	}

	for ( local i = SpawnQueue_t.len() - 1; i > 0; i-- )
	{
		local j = RandomInt(0, i);
		local tmp = SpawnQueue_t[i];
		SpawnQueue_t[i] = SpawnQueue_t[j];
		SpawnQueue_t[j] = tmp;
	}

	NextSpawnIdx = 0;
	NextSpawnTime = Time() + 0.8;
}

function StartRun()
{
	Procs_t = [];
	Contained = 0;
	FalsePositives = 0;
	TotalTarget = TARGET_CONTAINED;
	SelectedProc = null;
	HoverProc = null;
	Message = "";
	MessageExpire = 0.0;
	PopulateSpawnQueue();
}

// =========================================================
//  GAME LOGIC
// =========================================================
function ShowMessage( text, color, duration )
{
	Message = text;
	MessageColor = color;
	MessageExpire = Time() + duration;
}

function FindFreeLane()
{
	local free = [];
	for ( local L = 0; L < LANE_COUNT; L++ )
	{
		local clear = true;
		for ( local i = 0; i < Procs_t.len(); i++ )
		{
			local p = Procs_t[i];
			if ( p.state != "alive" ) continue;
			if ( p.lane != L ) continue;
			if ( p.x < PROC_SPAWN_X + PROC_W + 50.0 ) { clear = false; break; }
		}
		if ( clear ) free.push( L );
	}
	return free;
}

function UpdateProcesses( dt )
{
	local now = Time();
	if ( NextSpawnIdx < SpawnQueue_t.len() && now >= NextSpawnTime )
	{
		local free = FindFreeLane();
		if ( free.len() > 0 )
		{
			local proc = SpawnQueue_t[ NextSpawnIdx ];
			proc.lane = free[ RandomInt(0, free.len()-1) ];
			proc.x = PROC_SPAWN_X;
			proc.state = "alive";
			Procs_t.push( proc );
			NextSpawnIdx++;
			NextSpawnTime = now + SPAWN_INTERVAL;
		}
	}

	for ( local i = 0; i < Procs_t.len(); i++ )
	{
		local proc = Procs_t[i];
		if ( proc.state != "alive" ) continue;
		if ( proc == SelectedProc ) continue;

		proc.x += PROC_SPEED * dt;

		if ( proc.x >= PROC_DESPAWN_X )
		{
			// Clamp so the final rendered frame stays inside the arena.
			proc.x = PROC_DESPAWN_X;
			proc.state = "escaped";
			if ( proc.isMalicious )
				ShowMessage( "THREAT ESCAPED", COLOR_WARN_RED, 1.0 );
		}
	}

	local keep = [];
	for ( local i = 0; i < Procs_t.len(); i++ )
	{
		if ( Procs_t[i].state == "alive" ) keep.push( Procs_t[i] );
		else if ( Procs_t[i] == SelectedProc ) SelectedProc = null;
	}
	Procs_t = keep;
}

function Tick( dt )
{
	if ( Phase != "running" ) return;

	UpdateProcesses( dt );

	if ( Contained >= TotalTarget )
	{
		Phase = "complete";
		if ( !bSentEnd ) { bSentEnd = true; self.SendInput( INPUT_SUCCESS ); }
		return;
	}

	if ( NextSpawnIdx >= SpawnQueue_t.len() && Procs_t.len() == 0 )
		PopulateSpawnQueue();
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
		Msg( "intrusion pkt: [" + self.GetString(0) + "]  phase=" + Phase );
	}

	local view  = GetDesignView();
	local pulse = ( sin( Time() * 1.2 ) + 1.0 ) * 0.5;

	PaintBackground( view, pulse );
	PaintHeader( view );
	PaintStats( view );
	PaintArena( view, pulse );
	PaintDetail( view );
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
	PaintColorText( v, 78, 26, COLOR_HEADER_TEXT, "INTRUSION DETECTION" );

	local statusText, statusColor;
	if ( Phase == "standby" )       { statusText = "STANDBY";    statusColor = COLOR_HEADER_STATUS; }
	else if ( Phase == "complete" ) { statusText = "CONTAINED";  statusColor = COLOR_WARN_GREEN; }
	else                            { statusText = "ACTIVE";     statusColor = COLOR_WARN_YELLOW; }

	local w = TextWideDesign( v, statusText );
	PaintColorText( v, 1500 - w, 30, statusColor, statusText );

	PaintColorRect( v, 70, 74, 1530, 76, COLOR_BG_EDGE );
}

function PaintStats( v )
{
	local ly = 92.0;
	local cx = 78.0;

	cx = PaintInfoField( v, cx, ly, "INTRUSION:",
		( Phase == "complete" ) ? "CONTAINED" : "ACTIVE",
		( Phase == "complete" ) ? COLOR_WARN_GREEN : COLOR_WARN_YELLOW );
	cx += 46.0;

	cx = PaintInfoField( v, cx, ly, "PROCESSES:",
		Procs_t.len().tostring(), COLOR_HEADER_TEXT );
	cx += 46.0;

	cx = PaintInfoField( v, cx, ly, "CONTAINED:",
		Contained.tostring() + " / " + TotalTarget.tostring(),
		( Contained >= TotalTarget ) ? COLOR_WARN_GREEN : COLOR_WARN_YELLOW );
	cx += 46.0;

	PaintInfoField( v, cx, ly, "FALSE POS:",
		FalsePositives.tostring(),
		( FalsePositives > 0 ) ? COLOR_WARN_RED : COLOR_HEADER_TEXT );

	PaintColorRect( v, 70, 124, 1530, 125, COLOR_BG_EDGE );
}

function PaintArena( v, pulse )
{
	PaintColorRect( v, ARENA_X0, ARENA_Y0, ARENA_X1, ARENA_Y1, COLOR_PANEL_BG );
	PaintColorRect( v, ARENA_X0+4, ARENA_Y0+4, ARENA_X1-4, ARENA_Y1-4, COLOR_PANEL_INNER );
	PaintColorRect( v, ARENA_X0, ARENA_Y0, ARENA_X1, ARENA_Y0+3, COLOR_PANEL_BORDER );
	PaintColorRect( v, ARENA_X0, ARENA_Y1-3, ARENA_X1, ARENA_Y1, COLOR_PANEL_BORDER );
	PaintColorRect( v, ARENA_X0, ARENA_Y0, ARENA_X0+3, ARENA_Y1, COLOR_PANEL_BORDER );
	PaintColorRect( v, ARENA_X1-3, ARENA_Y0, ARENA_X1, ARENA_Y1, COLOR_PANEL_BORDER );

	local laneH = (ARENA_Y1 - ARENA_Y0) / LANE_COUNT;
	for ( local i = 1; i < LANE_COUNT; i++ )
	{
		local ly = ARENA_Y0 + laneH * i;
		PaintColorRect( v, ARENA_X0+6, ly, ARENA_X1-6, ly+1, [30, 55, 65, 200] );
	}

	for ( local x = ARENA_X0 + 100; x < ARENA_X1; x += 100 )
		PaintColorRect( v, x, ARENA_Y0+6, x+1, ARENA_Y1-6, COLOR_BG_GRID_FAINT );

	PaintColorRect( v, ARENA_X1-4, ARENA_Y0+6, ARENA_X1-3, ARENA_Y1-6, [200, 90, 75, 200] );

	for ( local i = 0; i < Procs_t.len(); i++ )
		PaintProcess( v, Procs_t[i], pulse );
}

function PaintProcess( v, proc, pulse )
{
	local x0 = proc.x;
	local cy = GetLaneCenterY( proc.lane );
	local y0 = cy - PROC_H * 0.5;
	local x1 = x0 + PROC_W;
	local y1 = y0 + PROC_H;

	// Safety: never draw past the arena border.
	if ( x1 > ARENA_X1 - 4 ) return;

	local selected = ( proc == SelectedProc );
	local hovered  = ( proc == HoverProc );

	PaintColorRect( v, x0+3, y0+3, x1+3, y1+3, [0, 0, 0, 120] );

	local bg = selected ? COLOR_PROC_BG_SEL : COLOR_PROC_BG;
	PaintColorRect( v, x0, y0, x1, y1, bg );

	local bc = COLOR_PROC_BORDER;
	if ( selected )     bc = COLOR_PROC_SELECTED;
	else if ( hovered ) bc = COLOR_PROC_HOVER;
	PaintColorRect( v, x0, y0, x1, y0+2, bc );
	PaintColorRect( v, x0, y1-2, x1, y1, bc );
	PaintColorRect( v, x0, y0, x0+2, y1, bc );
	PaintColorRect( v, x1-2, y0, x1, y1, bc );

	// Top row: PID (small) + 4 status dots (right-aligned)
	local rowY = y0 + 14.0;
	PaintSmallText( v, x0 + 14, rowY, COLOR_HEADER_STATUS, "PID " + pidPad( proc.pid ) );

	local flags = [ proc.sigFlag, proc.origFlag, proc.privFlag, proc.memFlag ];
	local dotSize = 14.0;
	local dotGap  = 6.0;
	local dotsTotalW = 4.0 * dotSize + 3.0 * dotGap;
	local dotsX0 = x1 - 14.0 - dotsTotalW;
	for ( local i = 0; i < 4; i++ )
	{
		local dotX = dotsX0 + i * (dotSize + dotGap);
		local dotY = rowY - 3.0;
		local dc = flags[i] ? COLOR_FLAG : COLOR_OK;
		PaintColorRect( v, dotX-1, dotY-1, dotX+dotSize+1, dotY+dotSize+1, [0, 0, 0, 170] );
		PaintColorRect( v, dotX,   dotY,   dotX+dotSize,   dotY+dotSize,   dc );
	}

	// Bottom row: process name (large, centered)
	local nameCy = y0 + PROC_H - 26.0;
	PaintSmallCenteredText( v, (x0+x1)*0.5, nameCy, COLOR_HEADER_TEXT, proc.name );

	if ( selected )
	{
		local cx = x0 + PROC_W * 0.5;
		PaintColorRect( v, cx-22, y0 - 12, cx+22, y0 - 7, COLOR_PROC_SELECTED );
	}
}

function PaintDetail( v )
{
	local x0 = DETAIL_X0, y0 = DETAIL_Y0;
	local x1 = DETAIL_X1, y1 = DETAIL_Y1;

	PaintColorRect( v, x0, y0, x1, y1, COLOR_PANEL_BG );
	PaintColorRect( v, x0+4, y0+4, x1-4, y1-4, COLOR_PANEL_INNER );
	PaintColorRect( v, x0, y0, x1, y0+3, COLOR_PANEL_BORDER );
	PaintColorRect( v, x0, y1-3, x1, y1, COLOR_PANEL_BORDER );
	PaintColorRect( v, x0, y0, x0+3, y1, COLOR_PANEL_BORDER );
	PaintColorRect( v, x1-3, y0, x1, y1, COLOR_PANEL_BORDER );

	PaintColorText( v, x0+22, y0+2, COLOR_HEADER_TEXT, "PROCESS ANALYSIS" );

	if ( SelectedProc == null )
	{
		PaintCenteredText( v, (x0+x1)*0.5, (y0+y1)*0.5, COLOR_HEADER_STATUS,
			"SELECT A PROCESS TO ANALYZE" );
		return;
	}

	local proc = SelectedProc;

	// Anomaly score (large, top-right)
	local flagCount = (proc.sigFlag?1:0)+(proc.origFlag?1:0)+(proc.privFlag?1:0)+(proc.memFlag?1:0);
	local fcCol = ( flagCount >= 2 ) ? COLOR_FLAG : COLOR_OK;
	local scoreStr = "ANOMALY SCORE: " + flagCount.tostring();
	local scoreW = TextWideDesign( v, scoreStr );
	PaintColorText( v, x1 - 24 - scoreW, y0 + 2, fcCol, scoreStr );

	PaintColorRect( v, x0+18, y0+40, x1-18, y0+41, [40, 70, 78, 200] );

	// Info row: PID / NAME / DEST -- no flag dots, just info.
	local rowY = y0 + 52;
	local cx = x0 + 22;
	cx = PaintInfoField( v, cx, rowY, "PID", pidPad(proc.pid), COLOR_HEADER_TEXT );
	cx += 40;
	cx = PaintInfoField( v, cx, rowY, "NAME", proc.name, COLOR_HEADER_TEXT );
	cx += 40;
	PaintInfoField( v, cx, rowY, "DEST", proc.destination, COLOR_HEADER_TEXT );

	// Attribute rows -- small font, two columns, well clear of buttons.
	local attrY1 = y0 + 86;
	local attrY2 = y0 + 114;

	local lcx = x0 + 22;
	PaintAttrRow( v, lcx, attrY1, "SIGNATURE:", proc.sig, proc.sigFlag );
	PaintAttrRow( v, lcx, attrY2, "PRIVILEGE:", proc.priv, proc.privFlag );

	local rcx = x0 + 620;
	PaintAttrRow( v, rcx, attrY1, "ORIGIN:", proc.orig, proc.origFlag );
	PaintAttrRow( v, rcx, attrY2, "MEMORY:", proc.mem, proc.memFlag );

	local allowHov = ( HoverButton == 0 );
	local aBg = allowHov ? COLOR_BTN_ALLOW_BG_HOV : COLOR_BTN_ALLOW_BG;
	PaintColorRect( v, BTN_ALLOW_X0, BTN_Y0, BTN_ALLOW_X1, BTN_Y1, aBg );
	PaintColorRect( v, BTN_ALLOW_X0, BTN_Y0, BTN_ALLOW_X1, BTN_Y0+2, COLOR_OK );
	PaintColorRect( v, BTN_ALLOW_X0, BTN_Y1-2, BTN_ALLOW_X1, BTN_Y1, COLOR_OK );
	PaintColorRect( v, BTN_ALLOW_X0, BTN_Y0, BTN_ALLOW_X0+2, BTN_Y1, COLOR_OK );
	PaintColorRect( v, BTN_ALLOW_X1-2, BTN_Y0, BTN_ALLOW_X1, BTN_Y1, COLOR_OK );
	PaintCenteredText( v, (BTN_ALLOW_X0+BTN_ALLOW_X1)*0.5, (BTN_Y0+BTN_Y1)*0.5,
		[ 220, 245, 230, 255 ], "ALLOW" );

	local termHov = ( HoverButton == 1 );
	local tBg = termHov ? COLOR_BTN_TERM_BG_HOV : COLOR_BTN_TERM_BG;
	PaintColorRect( v, BTN_TERM_X0, BTN_Y0, BTN_TERM_X1, BTN_Y1, tBg );
	PaintColorRect( v, BTN_TERM_X0, BTN_Y0, BTN_TERM_X1, BTN_Y0+2, COLOR_FLAG );
	PaintColorRect( v, BTN_TERM_X0, BTN_Y1-2, BTN_TERM_X1, BTN_Y1, COLOR_FLAG );
	PaintColorRect( v, BTN_TERM_X0, BTN_Y0, BTN_TERM_X0+2, BTN_Y1, COLOR_FLAG );
	PaintColorRect( v, BTN_TERM_X1-2, BTN_Y0, BTN_TERM_X1, BTN_Y1, COLOR_FLAG );
	PaintCenteredText( v, (BTN_TERM_X0+BTN_TERM_X1)*0.5, (BTN_Y0+BTN_Y1)*0.5,
		[ 255, 210, 210, 255 ], "TERMINATE" );
}

function pidPad( n )
{
	local s = n.tostring();
	while ( s.len() < 4 ) s = "0" + s;
	return s;
}

function PaintBanner( v )
{
	if ( Time() >= MessageExpire ) return;
	if ( Message == "" ) return;

	local cx = DESIGN_W * 0.5;
	local cy = 400.0;
	local w = TextWideDesign( v, Message );

	PaintColorRect( v, cx - w*0.5 - 30, cy - 30, cx + w*0.5 + 30, cy + 30, [0, 0, 0, 210] );
	PaintColorRect( v, cx - w*0.5 - 30, cy - 30, cx + w*0.5 + 30, cy - 27, MessageColor );
	PaintColorRect( v, cx - w*0.5 - 30, cy + 27, cx + w*0.5 + 30, cy + 30, MessageColor );
	PaintCenteredText( v, cx, cy, MessageColor, Message );
}

function PaintComplete( v )
{
	PaintBanner( v );
	local x0 = 300, x1 = 1300, y0 = 90, y1 = 176;
	PaintColorRect( v, x0, y0, x1, y1, [ 8, 45, 42, 250 ] );
	PaintColorRect( v, x0, y0, x1, y0+3, COLOR_WARN_GREEN );
	PaintColorRect( v, x0, y1-3, x1, y1, COLOR_WARN_GREEN );
	PaintCenteredText( v, (x0+x1)*0.5, y0+26, COLOR_HEADER_TEXT, "INTRUSION CONTAINED" );
	PaintCenteredText( v, (x0+x1)*0.5, y0+62, COLOR_HEADER_STATUS, "HOSTILE PROCESSES PURGED" );
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
//  INPUT
// =========================================================
function PointInRect( px, py, x0, y0, x1, y1 )
{
	return px >= x0 && px <= x1 && py >= y0 && py <= y1;
}

function PointInProc( px, py, proc )
{
	local cy = GetLaneCenterY( proc.lane );
	local y0 = cy - PROC_H * 0.5;
	local x0 = proc.x;
	return PointInRect( px, py, x0, y0, x0 + PROC_W, y0 + PROC_H );
}

function TerminateProc()
{
	if ( SelectedProc == null ) return;
	local proc = SelectedProc;

	if ( proc.isMalicious )
	{
		Contained++;
		ShowMessage( "THREAT CONTAINED", COLOR_WARN_GREEN, 1.0 );
	}
	else
	{
		FalsePositives++;
		ShowMessage( "CRITICAL PROCESS TERMINATED", COLOR_WARN_RED, 1.2 );
	}

	proc.state = "terminated";
	SelectedProc = null;
}

function AllowProc()
{
	if ( SelectedProc == null ) return;
	SelectedProc = null;
}

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
			Phase = "running";
			StartRun();
			LastTickTime = Time();
			self.SendInput( INPUT_START );
		}
	}

	local newHoverProc = null;
	for ( local i = 0; i < Procs_t.len(); i++ )
	{
		if ( PointInProc( dx, dy, Procs_t[i] ) ) { newHoverProc = Procs_t[i]; break; }
	}
	HoverProc = newHoverProc;

	local newHoverBtn = -1;
	if ( SelectedProc != null )
	{
		if ( PointInRect( dx, dy, BTN_ALLOW_X0, BTN_Y0, BTN_ALLOW_X1, BTN_Y1 ) ) newHoverBtn = 0;
		else if ( PointInRect( dx, dy, BTN_TERM_X0, BTN_Y0, BTN_TERM_X1, BTN_Y1 ) ) newHoverBtn = 1;
	}
	HoverButton = newHoverBtn;

	local lmb = false;
	if ( "mouse_left" in table && table["mouse_left"] ) lmb = true;
	if ( !lmb ) { bPressedLMB = false; return; }
	if ( bPressedLMB ) return;
	bPressedLMB = true;

	if ( Phase != "running" ) return;

	if ( SelectedProc != null )
	{
		if ( HoverButton == 0 ) { AllowProc(); return; }
		if ( HoverButton == 1 ) { TerminateProc(); return; }
	}

	if ( HoverProc != null )
	{
		if ( HoverProc == SelectedProc ) SelectedProc = null;
		else SelectedProc = HoverProc;
		return;
	}

	SelectedProc = null;
}

// =========================================================
//  INIT
// =========================================================
LastTickTime <- Time();
GlobalTime <- LastTickTime;
DebugLastLog <- 0.0;