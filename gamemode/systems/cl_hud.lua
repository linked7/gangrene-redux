-- The main HUD, replacing GMod's health, armor and ammo boxes. Bottom left: fate, name, health
-- (out of the current max, which Pox and a lodged bullet lower), armor, needs once they matter,
-- Injured / Bullet / Wanted markers, then bones, stem cells and rank. Bottom right: ammo.
-- Ghosts get one line telling them to pick a purpose. Presentation only; it reads State fields.
--
-- Also the shared look for the other client panels (cl_fates, cl_scoreboard, cl_help):
-- HUD.S( n ) scales a 1080p pixel size to the screen, HUD.COLORS and the gr_hud_* fonts.
HUD = HUD or {}

HUD.COLORS = {
	back = Color( 12, 12, 10, 200 ),
	panel = Color( 24, 24, 21, 235 ),
	line = Color( 60, 58, 52, 255 ),
	text = Color( 205, 202, 192 ),
	dim = Color( 125, 122, 114 ),
	blood = Color( 150, 30, 30 ),
	warn = Color( 230, 200, 60 ),
	armor = Color( 90, 100, 110 ),
	need = Color( 140, 120, 70 ),
}
local C = HUD.COLORS

-- Sizes are written for 1080p; 720p is scaled a little less than proportionally to stay readable.
function HUD.S( n ) return math.Round( n * math.max( ScrH() / 1080, 0.75 ) ) end

local function makeFonts()
	surface.CreateFont( "gr_hud_big", { font = "Trebuchet MS", size = HUD.S( 30 ), weight = 700 } )
	surface.CreateFont( "gr_hud", { font = "Trebuchet MS", size = HUD.S( 22 ), weight = 600 } )
	surface.CreateFont( "gr_hud_small", { font = "Trebuchet MS", size = HUD.S( 18 ), weight = 500 } )
end
makeFonts()
hook.Add( "OnScreenSizeChanged", "gr_hud", makeFonts )

local HIDE = {
	CHudHealth = true, CHudBattery = true, CHudAmmo = true, CHudSecondaryAmmo = true, CHudSuitPower = true,
}
hook.Add( "HUDShouldDraw", "gr_hud", function( name )
	if HIDE[ name ] then return false end
end )
-- No name-and-health tag on the player you look at, and no kill feed: deaths aren't announced.
hook.Add( "HUDDrawTargetID", "gr_hud", function() return true end )
hook.Add( "DrawDeathNotice", "gr_hud", function() return true end )

-- A need shows this many points before its first warning, and stays while it is that high.
local NEED_SHOW_BEFORE = 15

local function firstThreshold( def )
	local low = def.max
	for at in pairs( def.thresholds ) do low = math.min( low, at ) end
	return low
end

local WANTED_NAMES = { [ WANTED_TORMENT ] = "Torment", [ WANTED_JUDGMENT ] = "Judgment", [ WANTED_DEATH ] = "Death" }

local function bar( x, y, w, h, frac, col, label )
	surface.SetDrawColor( 0, 0, 0, 220 )
	surface.DrawRect( x, y, w, h )
	surface.SetDrawColor( col )
	surface.DrawRect( x + 1, y + 1, math.max( ( w - 2 ) * math.Clamp( frac, 0, 1 ), 0 ), h - 2 )
	if label then
		draw.SimpleText( label, "gr_hud_small", x + HUD.S( 6 ), y + h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	end
end

-- Rows are { height, draw( x, y, w ) }, laid out top to bottom inside one box.
local function rows( ply )
	local out = {}
	local function add( h, fn ) table.insert( out, { h, fn } ) end
	local small, line = draw.GetFontHeight( "gr_hud_small" ), HUD.S( 6 )

	local f = ply:GetFateDef()
	add( draw.GetFontHeight( "gr_hud_big" ), function( x, y )
		draw.SimpleText( f.Name, "gr_hud_big", x, y, f.Color or C.text )
	end )
	if ply:GetCharName() ~= "" then
		add( draw.GetFontHeight( "gr_hud" ) + line, function( x, y )
			draw.SimpleText( ply:GetCharName(), "gr_hud", x, y, C.dim )
		end )
	end

	local barH = HUD.S( 22 )
	add( barH + line, function( x, y, w )
		local hp, max = math.max( ply:Health(), 0 ), math.max( ply:GetMaxHealth(), 1 )
		bar( x, y, w, barH, hp / max, C.blood, string.format( "Health  %d / %d", hp, max ) )
	end )
	if ply:Armor() > 0 then
		add( barH + line, function( x, y, w )
			bar( x, y, w, barH, ply:Armor() / math.max( f.Armor or 100, ply:Armor() ), C.armor, "Armor  " .. ply:Armor() )
		end )
	end

	local needH = HUD.S( 14 )
	for _, name in ipairs( Needs.All() ) do
		local def, v = Needs.Def( name ), Needs.Get( ply, name )
		if v > 0 and v >= firstThreshold( def ) - NEED_SHOW_BEFORE then
			add( small + needH + line, function( x, y, w )
				draw.SimpleText( name, "gr_hud_small", x, y, v >= firstThreshold( def ) and C.warn or C.dim )
				bar( x, y + small, w, needH, v / def.max, C.need )
			end )
		end
	end

	local marks = {}
	if ply:GetInjured() then table.insert( marks, { "Injured", C.warn } ) end
	if ply:GetBullet() then table.insert( marks, { "Bullet lodged", C.blood } ) end
	if ply:IsWanted() then
		table.insert( marks, { string.format( "Wanted for %s: %s (%d s)", WANTED_NAMES[ ply:GetWanted() ] or "?",
			ply:GetWantedReason(), math.ceil( Crime.WantedLeft( ply ) ) ), C.blood } )
	end
	for _, m in ipairs( marks ) do
		add( small + HUD.S( 2 ), function( x, y ) draw.SimpleText( m[ 1 ], "gr_hud_small", x, y, m[ 2 ] ) end )
	end

	add( line + small, function( x, y, w )
		surface.SetDrawColor( C.line )
		surface.DrawRect( x, y + line / 2, w, 1 )
		local text = string.format( "%d bones    %d stem cells    %s", ply:GetBones(), ply:GetStemCells(), Rank.Name( ply:GetRank() ) )
		if ply:FateHas( "Police" ) then text = text .. "    " .. ply:GetTeeth() .. " teeth" end
		draw.SimpleText( text, "gr_hud_small", x, y + line, C.dim )
	end )
	return out
end

local function drawLiving( ply )
	local pad, margin, w = HUD.S( 12 ), HUD.S( 24 ), HUD.S( 330 )
	local list = rows( ply )
	local h = pad * 2
	for _, r in ipairs( list ) do h = h + r[ 1 ] end
	local x, y = margin, ScrH() - margin - h
	draw.RoundedBox( 4, x, y, w, h, C.back )
	y = y + pad
	for _, r in ipairs( list ) do
		r[ 2 ]( x + pad, y, w - pad * 2 )
		y = y + r[ 1 ]
	end
end

local function drawAmmo( ply )
	local wep = ply:GetActiveWeapon()
	if not IsValid( wep ) or wep.DrawAmmo == false then return end
	local clip, kind = wep:Clip1(), wep:GetPrimaryAmmoType()
	if clip < 0 and kind < 0 then return end
	local reserve = kind >= 0 and ply:GetAmmoCount( kind ) or 0
	local text = clip >= 0 and string.format( "%d / %d", clip, reserve ) or tostring( reserve )

	local margin, pad = HUD.S( 24 ), HUD.S( 12 )
	surface.SetFont( "gr_hud_big" )
	local tw, th = surface.GetTextSize( text )
	local name = wep:GetPrintName()
	surface.SetFont( "gr_hud_small" )
	local nw, nh = surface.GetTextSize( name )
	local w, h = math.max( tw, nw ) + pad * 2, th + nh + pad * 2
	local x, y = ScrW() - margin - w, ScrH() - margin - h
	draw.RoundedBox( 4, x, y, w, h, C.back )
	draw.SimpleText( name, "gr_hud_small", x + w - pad, y + pad, C.dim, TEXT_ALIGN_RIGHT )
	draw.SimpleText( text, "gr_hud_big", x + w - pad, y + pad + nh, clip == 0 and C.blood or C.text, TEXT_ALIGN_RIGHT )
end

local function drawGhost( ply )
	local x, y = ScrW() / 2, ScrH() - HUD.S( 70 )
	draw.SimpleText( "You are dead. Press F2 to choose a purpose in life.", "gr_hud", x, y, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
	draw.SimpleText( string.format( "%d stem cells    %s    F1 for help", ply:GetStemCells(), Rank.Name( ply:GetRank() ) ),
		"gr_hud_small", x, y + HUD.S( 4 ), C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
end

hook.Add( "HUDPaint", "gr_hud", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) or not ply:Alive() or ply:GetPassedOut() or Round.IsOver() then return end
	if ply:IsGhost() then
		drawGhost( ply )
		return
	end
	if not ply:GetFateDef() then return end
	drawLiving( ply )
	drawAmmo( ply )
end )
