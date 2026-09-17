FONT_DEFAULTLARGE <- self.LookupFont( "DefaultLarge" );
FONT_DEFAULTLARGEBLUR <- self.LookupFont( "DefaultLargeBlur" );

const WAVE_COUNT = 4;
const DESIGN_W = 1600.0;
const DESIGN_H = 900.0;
const PI = 3.14159265;
const WAVE_SEGMENTS = 256;
const PLAYER_LINE_THICKNESS = 2.5;
const TARGET_LINE_THICKNESS = 1.5;
const INITIAL_FREQUENCY = 0.0;
const CONTROL_START_X = 330.0;
const CONTROL_COLUMN_STEP = 300.0;
const CONTROL_WIDTH = 260.0;
const CONTROL_LABEL_GAP = 8.0;
const CHANNEL_LABEL_GAP = -16.0;

COLOR_BG_SHADOW <- [ 0, 0, 0, 155 ];
COLOR_BG_FRAME <- [ 5, 13, 21, 255 ];
COLOR_BG_BEZEL <- [ 20, 57, 65, 230 ];
COLOR_BG_SCREEN <- [ 4, 12, 20, 255 ];
COLOR_BG_EDGE <- [ 61, 163, 157, 180 ];
COLOR_BG_BOTTOM <- [ 18, 55, 67, 230 ];
COLOR_BG_SIDE <- [ 34, 102, 111, 180 ];
COLOR_BG_GRID <- [ 18, 42, 52, 100 ];
COLOR_BG_GRID_FAINT <- [ 18, 42, 52, 72 ];
COLOR_BG_SWEEP <- [ 73, 184, 176, 32 ];
COLOR_HEADER_TEXT <- [ 104, 241, 220, 255 ];
COLOR_HEADER_STATUS <- [ 120, 180, 184, 255 ];
COLOR_SCOPE_CENTER <- [ 48, 103, 106, 185 ];
COLOR_LABEL_PANEL <- [ 8, 22, 29, 210 ];
COLOR_LABEL_EDGE <- [ 61, 163, 157, 255 ];
COLOR_LABEL_TEXT <- [ 175, 214, 207, 255 ];
COLOR_SLIDER_SHADOW <- [ 0, 0, 0, 150 ];
COLOR_BADGE_SHADOW <- [ 3, 8, 13, 240 ];

WaveFrequency_t <- [ INITIAL_FREQUENCY, INITIAL_FREQUENCY, INITIAL_FREQUENCY, INITIAL_FREQUENCY ];
WaveAmplitude_t <- [ 0.50, 0.50, 0.50, 0.50 ];
TargetFrequency_t <- [ 0.50, 0.50, 0.50, 0.50 ];
TargetAmplitude_t <- [ 0.50, 0.50, 0.50, 0.50 ];
Locked_t <- [ false, false, false, false ];
SelectedWave <- 0;
bDragging <- false;
bPressedLMBLastFrame <- false;
LastServerState <- "";
ServerState <- "active";

function Paint()
{
	UpdateFromServer();
	local view = GetDesignView();
	PaintBackground( view );
	PaintHeader( view );
	PaintOscilloscopes( view );
	PaintControls( view );
	if ( ServerState == "complete" )
		PaintCompletion();
}

function GetDesignView()
{
	local viewW = ScreenHeight().tofloat() * 0.65 * 1024.0 / 768.0;
	local viewH = ScreenHeight().tofloat() * 0.65;
	return [ 0.0, 0.0, viewW, viewH ];
}

function X( view, value )
{
	return view[0] + value / DESIGN_W * view[2];
}

function Y( view, value )
{
	return view[1] + value / DESIGN_H * view[3];
}

function PaintBackground( view )
{
	local pulse = ( sin( Time() * 0.8 ) + 1.0 ) * 0.5;
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

function PaintColorRect( view, x0, y0, x1, y1, color )
{
	self.PaintRectangle( X( view, x0 ), Y( view, y0 ), X( view, x1 ), Y( view, y1 ), color[0], color[1], color[2], color[3] );
}

function PaintColorText( view, x, y, color, text )
{
	self.PaintText( X( view, x ), Y( view, y ), color[0], color[1], color[2], color[3], FONT_DEFAULTLARGE, text );
}

function PaintHeader( view )
{
	local lockedCount = 0;
	for ( local i = 0; i < WAVE_COUNT; i++ )
		if ( Locked_t[i] ) lockedCount++;
	local statusText = "SIGNAL ARRAY:  " + lockedCount.tostring() + " / 4";
	local statusWidth = self.GetTextWide( FONT_DEFAULTLARGE, statusText );
	PaintColorText( view, 78, 30, COLOR_HEADER_TEXT, "FREQUENCY MATCHING" );
	PaintColorText( view, 1490 - statusWidth * DESIGN_W / view[2], 34, COLOR_HEADER_STATUS, statusText );
	PaintColorRect( view, 70, 70, 1530, 72, COLOR_BG_EDGE );
}

function PaintOscilloscopes( view )
{
	for ( local wave = 0; wave < WAVE_COUNT; wave++ )
	{
		local top = 105.0 + wave * 165.0;
		local left = 105.0;
		local right = 1150.0;
		local center = top + 62.0;
		local height = 48.0 * WaveAmplitude_t[wave];
		local locked = Locked_t[wave];
		local waveRed = locked ? 145 : 70;
		local waveGreen = locked ? 150 : 224;
		local waveBlue = locked ? 154 : 205;
		local targetRed = locked ? 160 : 225;
		local targetGreen = locked ? 165 : 190;
		local targetBlue = locked ? 170 : 91;

		DrawScopePanel( view, left, right, top, locked );
		DrawWave( view, left, right, center, height, WaveFrequency_t[wave], waveRed, waveGreen, waveBlue, 245, PLAYER_LINE_THICKNESS );
		DrawWave( view, left, right, center, 48.0 * TargetAmplitude_t[wave], TargetFrequency_t[wave], targetRed, targetGreen, targetBlue, 220, TARGET_LINE_THICKNESS );

		DrawWaveNumber( view, 66.0, top, wave + 1, locked );
		DrawStatusBadge( view, 1210.0, top + 34.0, locked );
	}
}

function DrawScopePanel( view, left, right, top, locked )
{
	local borderRed = locked ? 72 : 28;
	local borderGreen = locked ? 82 : 108;
	local borderBlue = locked ? 88 : 118;
	local gridRed = locked ? 31 : 26;
	local gridGreen = locked ? 44 : 65;
	local gridBlue = locked ? 49 : 72;

	self.PaintRectangle( X( view, left - 12 ), Y( view, top + 7 ), X( view, right + 12 ), Y( view, top + 134 ), 0, 0, 0, 150 );
	self.PaintRectangle( X( view, left - 8 ), Y( view, top - 4 ), X( view, right + 8 ), Y( view, top + 130 ), 5, 12, 18, 255 );
	self.PaintRectangle( X( view, left - 5 ), Y( view, top - 1 ), X( view, right + 5 ), Y( view, top + 127 ), borderRed, borderGreen, borderBlue, 255 );
	self.PaintRectangle( X( view, left ), Y( view, top + 3 ), X( view, right ), Y( view, top + 123 ), locked ? 10 : 3, locked ? 17 : 15, locked ? 21 : 23, 245 );
	self.PaintRectangle( X( view, left ), Y( view, top + 3 ), X( view, right ), Y( view, top + 5 ), borderRed, borderGreen, borderBlue, 150 );
	self.PaintRectangle( X( view, left ), Y( view, top + 121 ), X( view, right ), Y( view, top + 123 ), 0, 4, 8, 220 );

	for ( local x = left + 40.0; x < right; x += 80.0 )
		self.PaintRectangle( X( view, x ), Y( view, top + 3 ), X( view, x + 1.0 ), Y( view, top + 123 ), gridRed, gridGreen, gridBlue, 145 );
	for ( local y = top + 23.0; y < top + 123; y += 20.0 )
		self.PaintRectangle( X( view, left ), Y( view, y ), X( view, right ), Y( view, y + 1.0 ), gridRed, gridGreen, gridBlue, 145 );
	self.PaintRectangle( X( view, left ), Y( view, top + 62.0 ), X( view, right ), Y( view, top + 63.0 ), 48, 103, 106, 185 );
}

function DrawWaveNumber( view, x, top, number, locked )
{
	local width = 38.0;
	local height = 48.0;
	local y = top + 39.0;
	local accentRed = locked ? 126 : 61;
	local accentGreen = locked ? 137 : 224;
	local accentBlue = locked ? 145 : 205;
	local text = number.tostring();
	local centerX = ( X( view, x ) + X( view, x + width ) ) * 0.5;
	local centerY = ( Y( view, y ) + Y( view, y + height ) ) * 0.5;

	self.PaintRectangle( X( view, x - 4 ), Y( view, y + 4 ), X( view, x + width + 4 ), Y( view, y + height + 4 ), 0, 0, 0, 130 );
	self.PaintRectangle( X( view, x ), Y( view, y ), X( view, x + width ), Y( view, y + height ), 7, 19, 27, 245 );
	self.PaintRectangle( X( view, x ), Y( view, y ), X( view, x + 4 ), Y( view, y + height ), accentRed, accentGreen, accentBlue, 255 );
	self.PaintRectangle( X( view, x + 4 ), Y( view, y ), X( view, x + width ), Y( view, y + 2 ), accentRed, accentGreen, accentBlue, 180 );
	self.PaintText( centerX - self.GetTextWide( FONT_DEFAULTLARGE, text ) * 0.5, centerY - self.GetFontTall( FONT_DEFAULTLARGE ) * 0.5, accentRed, accentGreen, accentBlue, 255, FONT_DEFAULTLARGE, text );
}

function DrawStatusBadge( view, x, y, locked )
{
	local label = locked ? "UNLOCKED" : "LOCKED";
	local width = 300.0;
	local height = 48.0;
	local textWidth = self.GetTextWide( FONT_DEFAULTLARGE, label );
	local red = locked ? 23 : 112;
	local green = locked ? 105 : 27;
	local blue = locked ? 71 : 31;
	local accentRed = locked ? 83 : 222;
	local accentGreen = locked ? 220 : 67;
	local accentBlue = locked ? 150 : 61;

	self.PaintRectangle( X( view, x - 8 ), Y( view, y - 6 ), X( view, x + width + 8 ), Y( view, y + height + 6 ), 3, 8, 13, 240 );
	self.PaintRectangle( X( view, x ), Y( view, y ), X( view, x + width ), Y( view, y + height ), red, green, blue, 245 );
	self.PaintRectangle( X( view, x ), Y( view, y ), X( view, x + 7 ), Y( view, y + height ), accentRed, accentGreen, accentBlue, 255 );
	self.PaintRectangle( X( view, x + 7 ), Y( view, y ), X( view, x + width ), Y( view, y + 3 ), accentRed, accentGreen, accentBlue, 190 );
	self.PaintRectangle( X( view, x + width - 7 ), Y( view, y + height - 3 ), X( view, x + width ), Y( view, y + height ), 8, 18, 24, 180 );
	local panelCenterX = ( X( view, x ) + X( view, x + width ) ) * 0.5;
	local panelCenterY = ( Y( view, y ) + Y( view, y + height ) ) * 0.5;
	self.PaintText( panelCenterX - textWidth * 0.5, panelCenterY - self.GetFontTall( FONT_DEFAULTLARGE ) * 0.5, 255, 255, 255, 255, FONT_DEFAULTLARGE, label );
}

function DrawWave( view, left, right, center, height, frequency, red, green, blue, alpha, thickness )
{
	local segments = WAVE_SEGMENTS;
	for ( local i = 0; i < segments; i++ )
	{
		local x0 = left + ( right - left ) * i / segments.tofloat();
		local x1 = left + ( right - left ) * ( i + 1 ) / segments.tofloat();
		local y0 = center - sin( i.tofloat() / segments.tofloat() * PI * 2.0 * ( 1.0 + frequency * 5.0 ) ) * height;
		local y1 = center - sin( ( i + 1 ).tofloat() / segments.tofloat() * PI * 2.0 * ( 1.0 + frequency * 5.0 ) ) * height;
		DrawWaveSegment( view, x0, y0, x1, y1, thickness, red, green, blue, alpha );
	}
}

function DrawWaveSegment( view, x0, y0, x1, y1, thickness, red, green, blue, alpha )
{
	local yMin = y0;
	local yMax = y1;
	if ( yMax < yMin )
	{
		local swap = yMin;
		yMin = yMax;
		yMax = swap;
	}
	self.PaintRectangle( X( view, x0 ), Y( view, yMin - thickness ), X( view, x1 + 1.0 ), Y( view, yMax + thickness ), red, green, blue, alpha );
}

function PaintControls( view )
{
	local frequencyLabelY = 778.0;
	local amplitudeLabelY = frequencyLabelY + 50.0 + CONTROL_LABEL_GAP;
	local channelLabelY = frequencyLabelY - 44.0 - CONTROL_LABEL_GAP - CHANNEL_LABEL_GAP;
	DrawControlLabel( view, "FREQUENCY", 35, frequencyLabelY );
	DrawControlLabel( view, "AMPLITUDE", 35, amplitudeLabelY );
	for ( local wave = 0; wave < WAVE_COUNT; wave++ )
	{
		local x = CONTROL_START_X + wave * CONTROL_COLUMN_STEP;
		DrawSlider( view, x, 802.0, WaveFrequency_t[wave], wave == SelectedWave, Locked_t[wave] );
		DrawSlider( view, x, 854.0, WaveAmplitude_t[wave], wave == SelectedWave, Locked_t[wave] );
		DrawChannelLabel( view, x, channelLabelY, "CH-" + ( wave + 1 ).tostring(), Locked_t[wave] );
	}
}

function DrawControlLabel( view, label, x, y )
{
	local width = 250.0;
	local height = 50.0;
	self.PaintRectangle( X( view, x ), Y( view, y ), X( view, x + width ), Y( view, y + height ), 8, 22, 29, 210 );
	self.PaintRectangle( X( view, x ), Y( view, y ), X( view, x + 4.0 ), Y( view, y + height ), 61, 163, 157, 255 );
	local panelCenterX = ( X( view, x ) + X( view, x + width ) ) * 0.5;
	local panelCenterY = ( Y( view, y ) + Y( view, y + height ) ) * 0.5;
	local textWidth = self.GetTextWide( FONT_DEFAULTLARGE, label );
	local textHeight = self.GetFontTall( FONT_DEFAULTLARGE );
	self.PaintText( panelCenterX - textWidth * 0.5, panelCenterY - textHeight * 0.5, 175, 214, 207, 255, FONT_DEFAULTLARGE, label );
}

function DrawChannelLabel( view, x, panelY, label, locked )
{
	local width = CONTROL_WIDTH;
	local height = 44.0;
	local color = locked ? 145 : 104;
	local green = locked ? 150 : 241;
	local blue = locked ? 154 : 220;
	self.PaintRectangle( X( view, x ), Y( view, panelY ), X( view, x + width ), Y( view, panelY + height ), 6, 17, 24, 200 );
	self.PaintRectangle( X( view, x ), Y( view, panelY ), X( view, x + width ), Y( view, panelY + 2.0 ), color, green, blue, 210 );
	local panelCenterX = ( X( view, x ) + X( view, x + width ) ) * 0.5;
	local panelCenterY = ( Y( view, panelY ) + Y( view, panelY + height ) ) * 0.5;
	local textWidth = self.GetTextWide( FONT_DEFAULTLARGE, label );
	local textHeight = self.GetFontTall( FONT_DEFAULTLARGE );
	self.PaintText( panelCenterX - textWidth * 0.5, panelCenterY - textHeight * 0.5, color, green, blue, 255, FONT_DEFAULTLARGE, label );
}

function DrawSlider( view, x, y, value, selected, locked )
{
	local trackRed = locked ? 55 : 31;
	local trackGreen = locked ? 62 : 72;
	local trackBlue = locked ? 65 : 76;
	local fillRed = locked ? 105 : 61;
	local fillGreen = locked ? 112 : 163;
	local fillBlue = locked ? 116 : 157;
	PaintColorRect( view, x + 3, y + 3, x + CONTROL_WIDTH + 3, y + 13, COLOR_SLIDER_SHADOW );
	self.PaintRectangle( X( view, x ), Y( view, y ), X( view, x + CONTROL_WIDTH ), Y( view, y + 8 ), trackRed, trackGreen, trackBlue, 255 );
	self.PaintRectangle( X( view, x ), Y( view, y ), X( view, x + CONTROL_WIDTH * value ), Y( view, y + 8 ), fillRed, fillGreen, fillBlue, 255 );
	for ( local tick = 0; tick <= 4; tick++ )
	{
		local tickX = x + tick * CONTROL_WIDTH / 4.0;
		self.PaintRectangle( X( view, tickX ), Y( view, y - 3 ), X( view, tickX + 2 ), Y( view, y + 11 ), locked ? 95 : 188, locked ? 102 : 220, locked ? 108 : 205, 210 );
	}
	local knobX = x + CONTROL_WIDTH * value;
	self.PaintRectangle( X( view, knobX - 7 ), Y( view, y - 6 ), X( view, knobX + 7 ), Y( view, y + 14 ), 4, 12, 17, 220 );
	self.PaintRectangle( X( view, knobX - 5 ), Y( view, y - 8 ), X( view, knobX + 5 ), Y( view, y + 16 ), locked ? 125 : ( selected ? 245 : 200 ), locked ? 130 : ( selected ? 215 : 200 ), locked ? 135 : 126, 255 );
}

function UpdateFromServer()
{
	local packet = self.GetString( 0 );
	local fields = split( packet, "|" );
	if ( fields.len() < 2 )
		return;

	ServerState = fields[0];
	local targets = fields[1];
	if ( targets != LastServerState && targets.len() )
	{
		local values = split( targets, "," );
		if ( values.len() >= WAVE_COUNT * 2 )
		{
			for ( local i = 0; i < WAVE_COUNT; i++ )
			{
				TargetFrequency_t[i] = values[i * 2].tofloat();
				TargetAmplitude_t[i] = values[i * 2 + 1].tofloat();
			}
		}
		LastServerState = targets;
	}
	if ( fields.len() >= 3 )
	{
		local lockMask = fields[2].tointeger();
		for ( local i = 0; i < WAVE_COUNT; i++ )
			Locked_t[i] = ( lockMask & ( 1 << i ) ) != 0;
	}
}

function PaintCompletion()
{
	local view = GetDesignView();
	local panelLeft = 460.0;
	local panelRight = 1140.0;
	local label = "SIGNAL UNLOCKED";
	local labelWidth = self.GetTextWide( FONT_DEFAULTLARGE, label );
	self.PaintRectangle( X( view, panelLeft ), Y( view, 385 ), X( view, panelRight ), Y( view, 515 ), 8, 33, 35, 245 );
	self.PaintRectangle( X( view, panelLeft ), Y( view, 385 ), X( view, panelRight ), Y( view, 389 ), 61, 220, 180, 255 );
	self.PaintText( X( view, ( panelLeft + panelRight ) * 0.5 ) - labelWidth * 0.5, Y( view, 410 ), 104, 241, 220, 255, FONT_DEFAULTLARGE, label );
}

function Control( table )
{
	local view = GetDesignView();
	local x = table["mouse_x"].tofloat();
	local y = table["mouse_y"].tofloat();
	local inside = x >= view[0] && x <= view[0] + view[2] && y >= view[1] && y <= view[1] + view[3];

	if ( !table["mouse_left"] )
	{
		bPressedLMBLastFrame = false;
		bDragging = false;
		return;
	}

	local designX = ( x - view[0] ) / view[2] * DESIGN_W;
	local designY = ( y - view[1] ) / view[3] * DESIGN_H;
	if ( !inside )
		return;

	if ( !bPressedLMBLastFrame )
	{
		bPressedLMBLastFrame = true;
		if ( designY >= 785.0 && designY <= 875.0 )
		{
			for ( local i = 0; i < WAVE_COUNT; i++ )
			{
				local sliderX = CONTROL_START_X + i * CONTROL_COLUMN_STEP;
				if ( Locked_t[i] )
					continue;
				if ( designX >= sliderX - 18.0 && designX <= sliderX + CONTROL_WIDTH + 18.0 )
				{
					SelectedWave = i;
					bDragging = true;
					break;
				}
			}
		}
	}

	if ( bDragging )
	{
		if ( Locked_t[SelectedWave] )
		{
			bDragging = false;
			return;
		}
		local sliderX = CONTROL_START_X + SelectedWave * CONTROL_COLUMN_STEP;
		local value = ( designX - sliderX ) / CONTROL_WIDTH;
		if ( value < 0.0 ) value = 0.0;
		if ( value > 1.0 ) value = 1.0;
		if ( designY < 830.0 )
			WaveFrequency_t[SelectedWave] = value;
		else
			WaveAmplitude_t[SelectedWave] = value;
		self.SendInput( SelectedWave * 10201 + ( WaveFrequency_t[SelectedWave] * 100.0 ).tointeger() * 101 + ( WaveAmplitude_t[SelectedWave] * 100.0 ).tointeger() );
	}
}