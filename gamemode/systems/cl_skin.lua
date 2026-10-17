-- The Derma skin, ported from the original's gui/cl_skin.lua ("CombineControl") and the button
-- behaviour of its gui/cl_dbutton.lua. Every panel in the gamemode (and GMod's own Derma while
-- playing) gets the dark greys, the blood-red highlights and the CombineControl fonts.
-- The original skin was missing most functions and relied on the engine's fallback; here
-- everything it does not define is inherited from the default skin explicitly.
--
-- Buttons: rainbow jittering text and weapon_select on hover, menu_open on press, buttonrelease
-- on release, a red throb circle on click, a red border, a dark-red overlay when disabled.
local SKIN = {}
SKIN.PrintName = "CombineControl"
SKIN.Author = "disseminate"
SKIN.DermaVersion = 1
SKIN.fontFrame = "CombineControl.Window"
SKIN.fontTab = "CombineControl.Window"
SKIN.control_color = Color( 255, 255, 255, 255 )
SKIN.control_color_highlight = Color( 150, 150, 150, 255 )
SKIN.control_color_active = Color( 255, 10, 10, 255 )
SKIN.control_color_bright = Color( 90, 90, 90, 255 )
SKIN.control_color_dark = Color( 40, 40, 40, 255 )
SKIN.colTextEntryText = Color( 200, 200, 200, 255 )
SKIN.colTextEntryTextHighlight = Color( 40, 40, 40, 255 )
SKIN.colTextEntryTextCursor = Color( 200, 200, 200, 255 )

local COLOURS = {
	Window = { TitleActive = Color( 200, 200, 200, 255 ), TitleInactive = Color( 200, 200, 200, 255 ) },
	Button = { Normal = Color( 200, 200, 200, 255 ), Hover = Color( 255, 255, 255, 255 ), Down = Color( 255, 0, 0, 255 ),
		Disabled = Color( 150, 150, 150, 255 ) },
	Label = { Default = Color( 200, 200, 200, 255 ), Bright = Color( 255, 255, 255, 255 ), Dark = Color( 150, 150, 150, 255 ),
		Highlight = Color( 255, 0, 0, 255 ) },
	Tree = { Lines = Color( 160, 160, 160, 255 ), Normal = Color( 160, 160, 160, 255 ), Hover = Color( 255, 255, 255, 255 ),
		Selected = Color( 200, 200, 200, 255 ) },
	TooltipText = Color( 200, 200, 200, 255 ),
}

function SKIN:PaintFrame( panel, w, h )
	draw.RoundedBox( 0, 0, 0, w, h, Color( 30, 30, 30, 230 ) )
	draw.RoundedBox( 0, 0, 0, w, 24, Color( 20, 20, 20, 255 ) )
	surface.DrawOutlinedRect( 0, 0, w, h )
end

-- cl_dbutton.lua's DButton:Paint, run for real DButtons only (not scroll grips or arrows).
local function buttonExtras( panel, w, h )
	local enabled = panel:IsEnabled()
	if panel.Hovered and enabled then
		if not panel.GR_Throb then
			surface.SetFont( panel:GetFont() )
			local text = panel:GetText()
			local tW, tH = surface.GetTextSize( text )
			surface.SetTextColor( HSVToColor( ( CurTime() * 66 ) % 360, 1, 1 ) )
			surface.SetTextPos( w / 2 - tW / 2 + math.random( -2, 2 ), h / 2 - tH / 2 + math.random( -2, 2 ) )
			surface.DrawText( text )
			if not panel.GR_Played then
				panel.GR_Played = 1
				surface.PlaySound( HUD.Sound( "weapon_select" ) )
			end
		end
	elseif panel.GR_Played then
		panel.GR_Played = nil
	end

	local down = panel:IsDown()
	if panel.GR_Played == 1 and down then
		panel.GR_Played = 2
		surface.PlaySound( HUD.Sound( "menu_open" ) )
	elseif panel.GR_Played == 2 and not down then
		panel.GR_Played = nil
		surface.PlaySound( HUD.Sound( "button_release" ) )
		panel.GR_Throb = 1
	end

	if panel.GR_Throb then
		local t = Lerp( 0.03, panel.GR_Throb, 0 )
		panel.GR_Throb = t
		surface.SetDrawColor( 200 * t, 0, 0, 255 * t )
		draw.NoTexture()
		HUD.Circle( w / 2 + math.random( -2, 2 ), h / 2 + math.random( -2, 2 ), w / 2 - ( w / 2 * t ) * 0.5, 25 )
		if t < 0.1 then panel.GR_Throb = nil end
	end

	if panel.m_bBorder ~= false then
		if enabled then surface.SetDrawColor( 200, 20, 20, 100 ) else surface.SetDrawColor( 100, 20, 20, 100 ) end
		surface.DrawOutlinedRect( 0, 0, w, h )
	end
	if not enabled then
		surface.SetDrawColor( 40, 10, 10, 100 )
		surface.DrawRect( 0, 0, w, h )
	end
end

local function paintButtonBack( panel, w, h )
	if not panel.m_bBackground then return end
	surface.SetDrawColor( 40, 40, 40, 255 )
	surface.DrawRect( 0, 0, w, h )
	if not panel:IsEnabled() then
		surface.SetDrawColor( 30, 30, 30, 255 )
		surface.DrawRect( 1, 1, w - 2, h - 2 )
		return
	end
	surface.SetDrawColor( 60, 60, 60, 255 )
	surface.DrawRect( 1, 1, w - 2, h - 2 )
end

function SKIN:PaintButton( panel, w, h )
	paintButtonBack( panel, w, h )
	if panel.ThisClass == "DButton" then buttonExtras( panel, w, h ) end
end

function SKIN:PaintTooltip( panel, w, h )
	surface.SetFont( "CombineControl.LabelSmall" )
	local tW, tH = surface.GetTextSize( panel:GetText() )
	draw.RoundedBox( 10 + 10 * math.sin( CurTime() ), 4, 0, tW + 2, tH + 6, Color( 64, 64, 64 ) )
	if not panel.GR_SetUp then
		panel.GR_SetUp = true
		panel:SetFont( "CombineControl.LabelSmall" )
		panel:SetTextColor( Color( 160, 0, 0 ) )
	end
end

function SKIN:PaintWindowCloseButton( panel, w, h ) end

function SKIN:PaintTextEntry( panel, w, h )
	if panel.m_bBackground then
		surface.SetDrawColor( 30, 30, 30, 255 )
		surface.DrawRect( 0, 0, w, h )
		surface.SetDrawColor( 40, 40, 40, 255 )
		surface.DrawRect( 1, 1, w - 2, h - 2 )
	end
	panel:DrawTextEntryText( panel:GetTextColor(), panel:GetHighlightColor(), panel:GetCursorColor() )
end

local function arrow( self, panel, w, h, glyph )
	if not panel.GR_LaidOut then
		panel.GR_LaidOut = true
		panel:SetText( glyph )
		panel:SetFont( "marlett" )
	end
	paintButtonBack( panel, w, h )
end
function SKIN:PaintButtonDown( panel, w, h ) arrow( self, panel, w, h, "u" ) end
function SKIN:PaintButtonUp( panel, w, h ) arrow( self, panel, w, h, "t" ) end
function SKIN:PaintVScrollBar( panel, w, h ) end
function SKIN:PaintScrollBarGrip( panel, w, h ) paintButtonBack( panel, w, h ) end

function SKIN:PaintListView( panel, w, h )
	surface.SetDrawColor( 30, 30, 30, 255 )
	surface.DrawRect( 0, 0, w, h )
	surface.SetDrawColor( 20, 20, 20, 100 )
	surface.DrawOutlinedRect( 0, 0, w, h )
end

function SKIN:PaintListViewLine( panel, w, h )
	if panel:IsSelected() then
		surface.SetDrawColor( 60, 60, 60, 255 )
	elseif panel.Hovered then
		surface.SetDrawColor( 50, 50, 50, 255 )
	elseif panel.m_bAlt then
		surface.SetDrawColor( 40, 40, 40, 255 )
	else
		return
	end
	surface.DrawRect( 0, 0, w, h )
end

function SKIN:PaintComboDownArrow( panel, w, h )
	draw.DrawText( "u", "marlett", 0, 0, Color( 200, 200, 200, 255 ) )
end

function SKIN:PaintComboBox( panel, w, h )
	surface.SetDrawColor( 30, 30, 30, 255 )
	surface.DrawRect( 0, 0, w, h )
	if panel.Depressed or panel:IsMenuOpen() then
		surface.SetDrawColor( 60, 60, 60, 255 )
	elseif not panel:IsEnabled() then
		surface.SetDrawColor( 30, 30, 30, 255 )
	else
		surface.SetDrawColor( 40, 40, 40, 255 )
	end
	surface.DrawRect( 1, 1, w - 2, h - 2 )
end

function SKIN:PaintMenu( panel, w, h )
	local odd = true
	for i = 0, h, 22 do
		if odd then surface.SetDrawColor( 40, 40, 40, 255 ) else surface.SetDrawColor( 50, 50, 50, 255 ) end
		surface.DrawRect( 0, i, w, 22 )
		odd = not odd
	end
end

function SKIN:PaintMenuOption( panel, w, h )
	if not panel.GR_LaidOut then
		panel.GR_LaidOut = true
		panel:SetFont( "CombineControl.LabelSmall" )
		panel:SetTextColor( Color( 200, 200, 200, 255 ) )
	end
	if panel.m_bBackground and ( panel.Hovered or panel.Highlight ) then
		surface.SetDrawColor( 70, 70, 70, 255 )
		surface.DrawRect( 0, 0, w, h )
	end
	if panel:GetChecked() and self.tex and self.tex.Menu_Check then self.tex.Menu_Check( 5, h / 2 - 7, 15, 15 ) end
end

-- Inherit whatever is not overridden (textures, tabs, categories, properties) from the default skin.
local base = derma.GetDefaultSkin()
if base then
	SKIN.Colours = table.Copy( base.Colours or {} )
	for k, v in pairs( base ) do
		if SKIN[ k ] == nil then SKIN[ k ] = v end
	end
else
	SKIN.Colours = {}
end
for group, cols in pairs( COLOURS ) do
	if istable( cols ) and not IsColor( cols ) then
		SKIN.Colours[ group ] = SKIN.Colours[ group ] or {}
		for k, v in pairs( cols ) do SKIN.Colours[ group ][ k ] = v end
	else
		SKIN.Colours[ group ] = cols
	end
end

derma.DefineSkin( "CombineControl", "Gangrene's skin, from the original Liver Failure.", SKIN )
hook.Add( "ForceDermaSkin", "gr_skin", function() return "CombineControl" end )
derma.RefreshSkins()
