-- The HUD, ported from the original's gui/cl_hud.lua (docs/05 §2), and the shared client look.
--
-- Library (used by every other cl_ file, always through HUD.x at run time):
--   HUD.Font( name )            "LabelMedium" -> "CombineControl.LabelMedium" (only used fonts exist)
--   HUD.Sound( key )            a Config.UI.Sounds path, the pack's or the stock fallback
--   HUD.Mat( key )              a Config.UI.Materials material, or nil when neither path loads
--   HUD.Stutter( text )         the despair text effect, cached per text and despair band for 0.1 s
--   HUD.TextShadow( text, font, x, y, col, shadow, align, thick, bar )   draw.DrawTextShadow
--   HUD.Blur( frac )            the original's pp/videoscale background blur
--   HUD.Notify( text, col )     the notification stack on the right (Notify() lands here)
--   HUD.EndText( text, col, atime, etime, x, y, font )   timed centre lines (announcements)
--   HUD.Layer( order, id, fn )  the HUDPaint pipeline: layers draw in order, like GM:HUDPaint did
--   HUD.LowFx()                 true when gr_lowfx is set: the costly passes are skipped
--   HUD.COLORS, HUD.S( n )      the panel palette and pixel scaling for cl_fates / cl_scoreboard / cl_help
--
-- Core layers here: menu blur, vignette, the downed and passed-out screens, consciousness blur,
-- health and need bars, ammo, the timed-action bar, notifications, end text and the wanted line.
-- Presentation only: everything is read from State fields.
HUD = HUD or {}
local UI = Config.UI
local CT = CurTime

-- gr_lowfx 0 (default) is the full look; 1 skips blurs, bloom, sharpen and the vignette trace.
local lowfx = CreateClientConVar( "gr_lowfx", "0", true, false, "Skip the costly screen effects (blur, bloom, sharpen)." )
function HUD.LowFx() return lowfx:GetBool() end

-- Palette for the Derma panels: the original skin's greys and blood red.
HUD.COLORS = {
	back = Color( 30, 30, 30, 230 ),
	panel = Color( 20, 20, 20, 255 ),
	line = Color( 40, 40, 40, 255 ),
	text = Color( 200, 200, 200 ),
	dim = Color( 150, 150, 150 ),
	blood = Color( 150, 20, 20 ),
	warn = Color( 255, 0, 0 ),
	armor = Color( 0, 0, 156 ),
	need = Color( 0, 128, 0 ),
}
local WHITE, BLACK = Color( 200, 200, 200, 255 ), Color( 0, 0, 0, 255 )

-- Panel sizes are written for 1080p; the HUD itself uses the original's fixed pixel sizes.
function HUD.S( n ) return math.Round( n * math.max( ScrH() / 1080, 0.75 ) ) end

-- Fonts -----------------------------------------------------------------------------------------

-- The Smash face ships with the content pack; without it the fallback face keeps the sizes.
local function smashInstalled()
	for _, f in ipairs( file.Find( "resource/fonts/*", "GAME" ) or {} ) do
		if string.find( string.lower( f ), string.lower( UI.Face ), 1, true ) then return true end
	end
	return false
end
HUD.Face = smashInstalled() and UI.Face or UI.FaceFallback

-- Only the variants something draws with (the original made Italic and Bold copies of all).
local FONTS = {
	Window = { 14, 500 }, GUIClose = { 16, 900 }, LabelTiny = { 16, 500 }, LabelSmall = { 20, 500 },
	LabelMedium = { 24, 500 }, LabelBig = { 30, 500 }, LabelGiant = { 36, 500 }, LabelMassive = { 44, 500 },
	LabelStupid = { 60, 500 }, PlayerFont = { 17, 700 }, HUDAmmo = { 50, 500 }, HUDAmmoSmall = { 30, 500 },
	ChatSmall = { 20, 100, "chat" }, ChatNormal = { 24, 500, "chat" }, ChatBig = { 32, 700, "chat" }, ChatRadio = { 16, 500, "radio" },
}
for name, f in pairs( FONTS ) do
	local face = f[ 3 ] == "chat" and UI.ChatFace or f[ 3 ] == "radio" and UI.RadioFace or HUD.Face
	surface.CreateFont( "CombineControl." .. name, { font = face, size = f[ 1 ], weight = f[ 2 ] } )
end
function HUD.Font( name ) return "CombineControl." .. name end
local F_TINY, F_SMALL, F_MEDIUM, F_BIG, F_GIANT = HUD.Font( "LabelTiny" ), HUD.Font( "LabelSmall" ),
	HUD.Font( "LabelMedium" ), HUD.Font( "LabelBig" ), HUD.Font( "LabelGiant" )

-- Assets ----------------------------------------------------------------------------------------

local sounds, mats = {}, {}
function HUD.Sound( key )
	local s = sounds[ key ]
	if s then return s end
	local pair = UI.Sounds[ key ]
	if not pair then return key end
	s = file.Exists( "sound/" .. pair[ 1 ], "GAME" ) and pair[ 1 ] or pair[ 2 ]
	sounds[ key ] = s
	return s
end

-- Any path, pack-first: returns `path` if it exists, else `fallback`.
function HUD.SoundPath( path, fallback )
	if file.Exists( "sound/" .. path, "GAME" ) then return path end
	return fallback
end

function HUD.Mat( key )
	local m = mats[ key ]
	if m ~= nil then return m or nil end
	local pair = UI.Materials[ key ]
	m = false
	if pair then
		for i = 1, 2 do
			if pair[ i ] then
				local mat = Material( pair[ i ], "smooth" )
				if not mat:IsError() then m = mat break end
			end
		end
	end
	mats[ key ] = m
	return m or nil
end

function HUD.Play( key, pitch, vol )
	LocalPlayer():EmitSound( HUD.Sound( key ), 0, pitch or 100, vol or 1 )
end

-- Stutter ---------------------------------------------------------------------------------------

local function despair()
	local ply = LocalPlayer()
	return IsValid( ply ) and ply.GetNeed_Despair and ply:GetNeed_Despair() or 0
end

local SCRAMBLE = { "@", "#", "!", "$", "%", "^", "&", "*" }
local function stutter( text, d )
	local chance = 1 + 5 * ( d / 100 )
	local scramble = d >= 50
	local out = {}
	for i = 1, #text do
		local c = string.sub( text, i, i )
		if math.random( 1, 100 ) <= chance then
			if scramble and math.random( 2 ) == 1 then c = SCRAMBLE[ math.random( #SCRAMBLE ) ] else c = string.upper( c ) end
		end
		out[ i ] = c
	end
	return table.concat( out )
end

-- Per text: the last result, its despair band and when it was made (docs/05 §6).
local cache, cacheSize = {}, 0
function HUD.Stutter( text )
	if text == nil or text == "" then return text or "" end
	local d = despair()
	local band, now = math.floor( d / 10 ), RealTime()
	local c = cache[ text ]
	if c and c.band == band and now - c.at < 0.1 then return c.out end
	if not c then
		if cacheSize > 512 then cache, cacheSize = {}, 0 end
		c = {}
		cache[ text ] = c
		cacheSize = cacheSize + 1
	end
	c.band, c.at, c.out = band, now, stutter( text, d )
	return c.out
end

-- Drawing helpers -------------------------------------------------------------------------------

function HUD.TextShadow( text, font, x, y, col1, col2, align, thick, bar )
	thick = thick or 2
	local t = CT()
	surface.SetFont( font )
	if align ~= 0 then
		if bar then
			local tW, tH = surface.GetTextSize( text )
			local g = 25 + 5 * math.sin( t )
			local grad = HUD.Mat( "gradient" )
			surface.SetDrawColor( g, g, g, col1.a )
			if grad then surface.SetMaterial( grad ) else draw.NoTexture() end
			surface.DrawTexturedRect( x - tW / 2, y, tW, tH )
		end
		draw.DrawText( text, font, x + math.sin( t * 0.8 ) * thick, y + math.sin( t ) * thick, col2, align )
		draw.DrawText( text, font, x, y, col1, align )
	else
		surface.SetTextColor( col2 )
		surface.SetTextPos( x + math.sin( t * 0.8 ) * thick, y + math.sin( t ) * thick )
		surface.DrawText( text )
		surface.SetTextColor( col1 )
		surface.SetTextPos( x, y )
		surface.DrawText( text )
		if bar then
			local tW, tH = surface.GetTextSize( text )
			local g = 100 + 50 * math.sin( t )
			local grad = HUD.Mat( "gradient" )
			surface.SetDrawColor( g, g, g, 200 )
			if grad then surface.SetMaterial( grad ) else draw.NoTexture() end
			surface.DrawTexturedRect( x, y, tW, tH )
		end
	end
end

local blurMat = Material( "pp/videoscale" )
function HUD.Blur( frac )
	if lowfx:GetBool() then
		surface.SetDrawColor( 0, 0, 0, 120 * math.Clamp( frac, 0, 1 ) )
		surface.DrawRect( 0, 0, ScrW(), ScrH() )
		return
	end
	DisableClipping( true )
	surface.SetMaterial( blurMat )
	surface.SetDrawColor( 255, 255, 255, 255 )
	blurMat:SetFloat( "$scale", math.max( 0, frac * 7 + 6 * math.sin( CT() ) ) )
	blurMat:SetFloat( "$multiply", 1 - 0.2 * frac )
	blurMat:Recompute()
	render.UpdateScreenEffectTexture()
	surface.DrawTexturedRect( 0, 0, ScrW(), ScrH() )
	DisableClipping( false )
end

-- A filled circle (the button throb and the F3 menu use it).
function HUD.Circle( x, y, radius, seg )
	local cir = { { x = x, y = y, u = 0.5, v = 0.5 } }
	for i = 0, seg do
		local a = math.rad( ( i / seg ) * -360 )
		table.insert( cir, { x = x + math.sin( a ) * radius, y = y + math.cos( a ) * radius,
			u = math.sin( a ) / 2 + 0.5, v = math.cos( a ) / 2 + 0.5 } )
	end
	surface.DrawPoly( cir )
end

-- Word-wraps `str` to `width` pixels in `font` (the original's GM:FormatLine). Returns the text, lines - 1.
function HUD.FormatLine( str, font, width )
	surface.SetFont( font )
	local lines, line = {}, ""
	for word in string.gmatch( str or "", "%S+" ) do
		local try = line == "" and word or line .. " " .. word
		if line ~= "" and surface.GetTextSize( try ) >= width then
			table.insert( lines, line )
			line = word
		else
			line = try
		end
	end
	table.insert( lines, line )
	return table.concat( lines, "\n" ), #lines - 1
end

-- The original's frame layout (CCFramePerformLayout): marlett close button top right, no
-- maximise or minimise, the title in CombineControl.Window. The skin (cl_skin.lua) paints it.
function HUD.FrameLayout( self )
	if IsValid( self.btnClose ) then
		self.btnClose:SetPos( self:GetWide() - 24, 0 )
		self.btnClose:SetSize( 24, 24 )
		self.btnClose:SetFont( "marlett" )
		self.btnClose:SetText( "r" )
	end
	if IsValid( self.btnMaxim ) then self.btnMaxim:Remove() end
	if IsValid( self.btnMinim ) then self.btnMinim:Remove() end
	if IsValid( self.lblTitle ) then
		self.lblTitle:SetPos( 6, 0 )
		self.lblTitle:SetSize( self:GetWide() - 25, 24 )
	end
end

function HUD.Frame( w, h, title )
	local f = vgui.Create( "DFrame" )
	f:SetSize( math.min( w, ScrW() ), math.min( h, ScrH() ) )
	f:Center()
	f:SetTitle( title or "" )
	if IsValid( f.lblTitle ) then f.lblTitle:SetFont( HUD.Font( "Window" ) ) end
	f.PerformLayout = HUD.FrameLayout
	f:MakePopup()
	f:InvalidateLayout( true )
	return f
end

function HUD.Label( parent, text, font, x, y, col )
	local l = vgui.Create( "DLabel", parent )
	l:SetText( text )
	l:SetFont( font )
	l:SetPos( x, y )
	l:SetTextColor( col or WHITE )
	l:SizeToContents()
	return l
end

-- The layer pipeline ----------------------------------------------------------------------------

local layers = {}
function HUD.Layer( order, id, fn )
	for i, l in ipairs( layers ) do
		if l.id == id then table.remove( layers, i ) break end
	end
	table.insert( layers, { order = order, id = id, fn = fn } )
	table.sort( layers, function( a, b ) return a.order < b.order end )
end

hook.Add( "HUDPaint", "gr_hud", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) then return end
	for _, l in ipairs( layers ) do
		local ok, err = pcall( l.fn, ply )
		if not ok then
			l.failed = ( l.failed or 0 ) + 1
			if l.failed == 1 then ErrorNoHalt( "[gr_hud] layer " .. l.id .. ": " .. tostring( err ) .. "\n" ) end
		end
	end
end )

local HIDE = {
	CHudHealth = true, CHudBattery = true, CHudAmmo = true, CHudSecondaryAmmo = true, CHudSuitPower = true,
	CHudWeaponSelection = true, CHudDamageIndicator = true, CHudChat = true,
}
local TOOL_CROSSHAIR = { gmod_tool = true, weapon_physgun = true, weapon_physcannon = true }
hook.Add( "HUDShouldDraw", "gr_hud", function( name )
	if HIDE[ name ] then return false end
	if name == "CHudCrosshair" then
		local wep = LocalPlayer():GetActiveWeapon()
		return IsValid( wep ) and TOOL_CROSSHAIR[ wep:GetClass() ] or false
	end
end )
hook.Add( "HUDDrawTargetID", "gr_hud", function() return true end )
hook.Add( "DrawDeathNotice", "gr_hud", function() return true end )

-- Is the F3 menu up? (cl_playermenu.lua sets HUD.PlayerMenu)
function HUD.MenuOpen() return IsValid( HUD.PlayerMenu ) end

-- Menu blur and vignette ------------------------------------------------------------------------

local blurProg = 0
HUD.Layer( 10, "menublur", function()
	if HUD.MenuOpen() then
		blurProg = Lerp( 0.05, blurProg, 2 )
	elseif blurProg > 0.1 then
		blurProg = Lerp( 0.1, blurProg, 0 )
	else
		blurProg = 0
	end
	if blurProg > 0 then HUD.Blur( blurProg ) end
end )

local vig = { target = 100, alpha = nil, next = 0 }
HUD.Layer( 20, "vignette", function( ply )
	local mat = HUD.Mat( "vignette" )
	if not mat then return end
	-- Darker under a roof: one trace a second (skipped on gr_lowfx).
	if CT() >= vig.next and not lowfx:GetBool() then
		vig.next = CT() + 1
		local start = ply:GetShootPos()
		local tr = util.TraceLine( { start = start, endpos = start + ply:GetUp() * 512, filter = ply } )
		vig.target = ( tr.HitWorld or tr.HitNonWorld ) and 235 or 100
	end
	vig.alpha = Lerp( 0.05, vig.alpha or vig.target, vig.target )
	surface.SetMaterial( mat )
	surface.SetDrawColor( 0, 0, 0, vig.alpha + math.abs( 20 * math.sin( CT() * 0.5 ) ) )
	surface.DrawTexturedRect( 0, 0, ScrW(), ScrH() )
end )

-- Downed screens, consciousness ------------------------------------------------------------------

local death = { alpha = nil, kind = nil }
local wakeAt
local EVENTUALLY_UP = "Eventually you will get up, assuming nothing finishes you off."
local SPEAK = "Speak \"MOTHER OF DEATH, I CALL ON THEE\" if you wish to perish, instead."
local EVENTUALLY_ROT = "Eventually you will rot, be mutilated, or revived."

local function centred( text, font, y, col, shadow )
	surface.SetFont( font )
	local tW, tH = surface.GetTextSize( text )
	HUD.TextShadow( text, font, ScrW() / 2 - tW / 2, y, col, shadow, 0 )
	return tH
end

HUD.Layer( 40, "consciousness", function( ply )
	local now = CT()
	local kind
	if not ply:Alive() then
		if ply:GetWakeUntil() > now then kind = "wounded" elseif ply:GetBleedoutUntil() > now then kind = "dying" end
	end
	if kind ~= death.kind then
		death.kind = kind
		death.alpha = kind == "wounded" and 10 or 0
	end
	if kind then
		death.alpha = Lerp( 0.0005, death.alpha, 255 )
		local a = death.alpha
		local function maybe( s ) return a < 128 and HUD.Stutter( s ) or s end
		local h = ScrH() / 2
		surface.SetFont( F_GIANT )
		if kind == "wounded" then
			local col = HSVToColor( ( now * 23 ) % 360, 1, 1 )
			local col2 = HSVToColor( ( now * 38 ) % 360, 1, 1 )
			col.a, col2.a = a, a
			local thought = ply:GetLastThought()
			local _, tH = surface.GetTextSize( thought ~= "" and thought or " " )
			if thought ~= "" then centred( maybe( thought ), F_GIANT, h - 70, col, col2 ) end
			centred( maybe( EVENTUALLY_UP ), F_GIANT, h + tH, col2, col )
			centred( maybe( SPEAK ), F_GIANT, h + 75, col2, col )
		else
			local col, col2 = Color( 255, 0, 0, a ), Color( 25, 25, 25, a )
			local tH = centred( maybe( "DEATH" ), F_GIANT, h, col, col2 )
			centred( maybe( EVENTUALLY_ROT ), F_GIANT, h + tH, col2, col )
		end
	end

	local c = ply:GetConsciousness()
	if ply:Alive() and not ply:GetPassedOut() and c < 60 then
		HUD.Blur( 1 - c / 60 )
		surface.SetDrawColor( 0, 0, 0, 150 * ( 1 - c / 60 ) )
		surface.DrawRect( 0, 0, ScrW(), ScrH() )
	end
	if wakeAt and now - wakeAt <= 3 then
		local frac = ( now - wakeAt ) / 3
		HUD.Blur( 1 - frac )
		surface.SetDrawColor( 0, 0, 0, 255 * ( 1 - frac ) )
		surface.DrawRect( 0, 0, ScrW(), ScrH() )
	end
end )

hook.Add( "GR_StateChanged", "gr_hud", function( _, name, v, old )
	if name == "PassedOut" and old == true and v == false then wakeAt = CT() end
end )

HUD.Layer( 90, "passedout", function( ply )
	if not ply:GetPassedOut() then return end
	local w, h = ScrW(), ScrH()
	local frac = math.min( ply:GetConsciousness() / 100, 1 )
	surface.SetDrawColor( 0, 0, 0, frac * 100 + 155 )
	surface.DrawRect( 0, 0, w, h )
	surface.SetDrawColor( 30, 30, 30, 150 )
	surface.DrawRect( w / 2 - 200, h / 2 + 40, 400, 10 )
	surface.SetDrawColor( 20, 20, 20, 100 )
	surface.DrawOutlinedRect( w / 2 - 200, h / 2 + 40, 400, 10 )
	surface.SetDrawColor( 150, 20, 20, 255 )
	surface.DrawRect( w / 2 - 199, h / 2 + 41, 398 * frac, 8 )
	-- "..." while the body is still being thrown about.
	local rag = HUD.OwnCorpse and HUD.OwnCorpse()
	if IsValid( rag ) and rag:GetVelocity():Length() > 15 then
		draw.DrawText( "...", F_MEDIUM, w / 2, h / 2 + 40 + 15, WHITE, 1 )
	end
end )

-- Health and need bars --------------------------------------------------------------------------

local shown = {}
local function lerped( key, target, cap )
	local v = shown[ key ] or target
	if v ~= target then v = Lerp( 0.05, v, target ) end
	if cap then v = math.min( cap, v ) end
	shown[ key ] = v
	return v
end

local function barLabel( text, font, x, y, fits )
	surface.SetFont( font )
	local tW = surface.GetTextSize( text )
	if fits >= tW then HUD.TextShadow( HUD.Stutter( text ), font, x, y, WHITE, BLACK, 1 ) end
end

local function poxLabel( p )
	if p < 15 then return "illness" elseif p < 35 then return "sickness" elseif p < 55 then return "disease" end
	return "pox"
end

local NEED_BARS = {
	{ "Emptiness", "emptiness", function( t ) return Color( 0, 128 + math.max( 0, 72 * math.sin( t ) ), 0, 180 ) end },
	{ "Dryness", "dryness", function( t ) return Color( 0, 128 + math.max( 0, 72 * math.sin( t ) ), 128 + math.max( 0, 72 * math.cos( t ) ), 180 ) end },
	{ "Despair", "despair", function( t ) local g = 100 + math.max( 0, 56 * math.sin( t ) ) return Color( g, g, g, 180 ) end },
}

local function need( ply, name )
	local get = ply[ "GetNeed_" .. name ]
	return get and get( ply ) or 0
end

HUD.Layer( 60, "healthbars", function( ply )
	if not ply:Alive() or ply:IsGhost() or not ply:GetFateDef() or HUD.MenuOpen() then return end
	local t = CT()
	local health = lerped( "health", ply:Health(), 500 )
	local pox = lerped( "pox", need( ply, "Pox" ), 100 )
	local carapace = lerped( "armor", ply:Armor(), 250 )

	local width = ScrW() * 0.4
	local x, y = ScrW() / 2 - width / 2 + 2 * 5 * math.sin( t * 0.333 ), 36 + 5 * math.sin( t )
	local smallSpace, largeSpace = -16, -27.5

	if ply:FateHas( "Police" ) and ply:GetTeeth() > 0 then
		local n = ply:GetTeeth()
		HUD.TextShadow( HUD.Stutter( n .. ( n == 1 and " TOOTH" or " TEETH" ) ), F_BIG, x + width * 0.09 + width, y - 32,
			HSVToColor( ( t * 23 ) % 360, 1, 1 ), BLACK, 1 )
	end

	if health < 95 then
		local drawn = math.min( health / 100, 1 )
		draw.RoundedBox( 4, x + 4, y - 30, width, 20, Color( 0, 0, 0, 200 ) )
		if health <= 0 then
			HUD.TextShadow( HUD.Stutter( "death" ), F_SMALL, x + width / 2, y - 32, WHITE, BLACK, 1 )
		else
			draw.RoundedBox( 4, x + 5, y - 29, width * drawn - 1, 18, Color( 100 + math.max( 0, 56 * math.sin( t ) ), 0, 0, 180 ) )
			barLabel( "blood", F_SMALL, x + width * drawn / 2, y - 32, width * drawn )
		end
		if pox > 1 then
			local pd = math.min( pox / 100, 1 )
			local g = 100 + math.max( 0, 56 * math.sin( t ) )
			draw.RoundedBox( 4, x + 5 + width - width * pd, y - 29, width * pd - 1, 18, Color( g, g, 0, 180 ) )
			barLabel( poxLabel( pox ), F_SMALL, x + width - width * pd + width * pd / 2, y - 32, width * pd )
		end
		y = y - largeSpace
	end

	if carapace > 1 then
		y = y - 6
		local drawn = math.min( carapace / 100, 1 )
		draw.RoundedBox( 4, x + 4, y - 30, width, 20, Color( 0, 0, 0, 200 ) )
		draw.RoundedBox( 4, x + 5, y - 29, width * drawn - 1, 18, Color( 0, 0, 100 + math.max( 0, 56 * math.sin( t ) ), 180 ) )
		barLabel( "carapace", F_SMALL, x + width * drawn / 2, y - 32, width * drawn )
		y = y - largeSpace
	end

	for _, b in ipairs( NEED_BARS ) do
		local v = lerped( b[ 1 ], need( ply, b[ 1 ] ), 100 )
		if v > 5 then
			local drawn = math.min( v / 100, 1 )
			draw.RoundedBox( 4, x + 4, y - 35, width, 14, Color( 0, 0, 0, 200 ) )
			draw.RoundedBox( 4, x + 5, y - 34, width * drawn - 1, 12, b[ 3 ]( t ) )
			barLabel( b[ 2 ], F_TINY, x + width * drawn / 2, y - 37, width * drawn )
			y = y - smallSpace
		end
	end
end )

-- Ammo: shown while reloading or for two seconds after pressing reload, as the original's ammo check.
local ammoCheck = 0
hook.Add( "PlayerBindPress", "gr_hud_ammo", function( _, bind, pressed )
	if pressed and string.find( bind, "+reload", 1, true ) then ammoCheck = CT() + 2 end
end )

HUD.Layer( 70, "ammo", function( ply )
	if not ply:Alive() or ply:IsGhost() or ply:InVehicle() then return end
	local wep = ply:GetActiveWeapon()
	if not IsValid( wep ) or wep.DrawAmmo == false then return end
	local max = wep.Primary and wep.Primary.ClipSize or wep:GetMaxClip1()
	if not max or max <= 0 then return end
	local left = ammoCheck - CT()
	if left <= 0 then return end
	local alpha = 180 * math.min( left / 2, 1 )
	local clip, reserve = wep:Clip1(), ply:GetAmmoCount( wep:GetPrimaryAmmoType() )
	local frac = clip == 0 and 0 or math.Clamp( clip / max, 0.2, clip ~= max and 0.8 or 1 )
	local width = ScrW() * 0.4
	local x, y = 20, 40
	local t = CT()
	draw.RoundedBox( 4, ScrW() - width / 2 - x - 2, ScrH() - 40 - y, x + 8, y + 28, Color( 0, 0, 0, alpha / 2 ) )
	draw.RoundedBox( 4, ScrW() - width / 2 - x, ScrH() - 38 - y, x + 4, ( y + 24 ) * frac,
		Color( 200 + math.max( 0, 56 * math.sin( t ) ), 100 + math.max( 0, 56 * math.sin( t ) ), 0, alpha ) )
	local mags = math.ceil( reserve / max )
	HUD.TextShadow( HUD.Stutter( mags .. ( mags == 1 and " mag" or " mags" ) ), F_SMALL, ScrW() - width / 2 + 16, ScrH() - 60,
		Color( 200, 200, 200, alpha ), Color( 0, 0, 0, alpha / 2 ), 0 )
end )

-- Timed action bar (sh_actions.lua's State fields), the original's DrawTimedProgress.
HUD.Layer( 80, "progress", function( ply )
	local finish = ply:GetActionEnd()
	local now = CT()
	if finish <= now then return end
	local start = ply:GetActionStart()
	local frac = math.min( ( now - start ) / math.max( finish - start, 0.01 ), 1 )
	local yc = 60
	local bx = ScrW() / 2 - ( 375 + 50 * math.sin( now * 4 ) ) / 2
	local by = ScrH() / 2 + ( 37.5 + 5 * math.sin( now * 2 ) ) + yc
	surface.SetDrawColor( 30, 30, 30, 200 )
	surface.DrawRect( bx, by, 400, 40 )
	surface.SetDrawColor( 150 + 50 * math.sin( now * 3 ), 20, 20 + 20 * math.sin( now ), 255 )
	surface.DrawRect( bx + 1, by + 1, 398 * frac, 38 )
	draw.DrawText( ply:GetActionLabel(), F_BIG, ScrW() / 2 - 15 * math.sin( now * 8 ), by + 15 - 10, WHITE, 1 )
end )

-- Notifications ---------------------------------------------------------------------------------

local notes = {}
function HUD.Notify( text, col )
	if string.find( text, "\n", 1, true ) then
		for _, line in ipairs( string.Explode( "\n", text ) ) do HUD.Notify( line, col ) end
		return
	end
	local used = {}
	for _, n in ipairs( notes ) do used[ n.slot ] = true end
	local slot = 0
	while used[ slot ] do slot = slot + 1 end
	surface.PlaySound( HUD.Sound( "notify" ) )
	table.insert( notes, { text = text, at = CT(), slot = slot, col = col } )
	MsgC( col or WHITE, text, "\n" )
end

HUD.Layer( 100, "notifications", function()
	local now = CT()
	for i = #notes, 1, -1 do
		if now - notes[ i ].at > 10 then table.remove( notes, i ) end
	end
	surface.SetFont( F_BIG )
	for _, n in ipairs( notes ) do
		local age, txt, a = now - n.at, n.text, 1
		if age < 0.5 then
			a = age / 0.5
			txt = HUD.Stutter( txt )
		elseif age > 3 then
			a = math.max( 0, 1 - ( age - 3 ) / 2 )
			txt = HUD.Stutter( txt )
		end
		if a > 0 then
			local c = n.col or WHITE
			local tW, tH = surface.GetTextSize( n.text )
			HUD.TextShadow( txt, F_BIG, ScrW() - 22 - tW, ScrH() - 180 - n.slot * tH, Color( c.r, c.g, c.b, 255 * a ),
				Color( 0, 0, 0, 255 * a ), 0 )
		end
	end
end )

-- End text: lines that fade in after `atime` and out over the last 4 s before `etime`.
local endTexts = {}
function HUD.EndText( text, col, atime, etime, x, y, font )
	font = font or F_GIANT
	surface.SetFont( font )
	local lines = string.Explode( "\n", text )
	for i, line in ipairs( lines ) do
		local _, tH = surface.GetTextSize( line )
		table.insert( endTexts, { text = line, at = CT() + atime, et = CT() + etime, col = col, x = x,
			y = y + ( tH + 20 ) * ( i - 1 ), font = font } )
	end
end

HUD.Layer( 110, "endtext", function()
	local now = CT()
	for i = #endTexts, 1, -1 do
		if now > endTexts[ i ].et then table.remove( endTexts, i ) end
	end
	for _, e in ipairs( endTexts ) do
		local a, txt = 1, e.text
		if now < e.at then
			a = 0
		elseif now - e.at < 2 then
			a = math.min( ( now - e.at ) / 1.5, 1 )
			txt = HUD.Stutter( txt )
		elseif e.et - now < 4 then
			a = math.max( 0, ( e.et - now ) / 4 )
			txt = HUD.Stutter( txt )
		end
		if a > 0 then
			local c = e.col or WHITE
			local x = e.x
			if x == nil then
				surface.SetFont( e.font )
				x = ScrW() / 2 - surface.GetTextSize( e.text ) / 2
			end
			HUD.TextShadow( txt, e.font, x, e.y, Color( c.r, c.g, c.b, 255 * a ), Color( 0, 0, 0, 255 * a ), 0 )
		end
	end
end )

-- Own wanted line, bottom centre. (The original also listed your own latent evidence; the remake
-- keeps evidence on the server, so only police see it, over the suspect: sh_police.lua.)
HUD.Layer( 120, "wanted", function( ply )
	if not ply:Alive() or ply:IsGhost() or not ply:IsWanted() then return end
	local t = CT()
	local txt = ply:GetWantedReason() .. ": " .. math.floor( Crime.WantedLeft( ply ) )
	surface.SetFont( F_MEDIUM )
	local tW, tH = surface.GetTextSize( txt )
	HUD.TextShadow( txt, F_MEDIUM, ScrW() / 2 - tW * 0.5, ScrH() - 22 - tH,
		Color( math.max( 0, 200 * math.sin( t * 3 ) ), 0, math.max( 0, -200 * math.sin( t * 3 ) ) ), BLACK, 0 )
end )

-- Ghosts get no HUD line (the original had none); the F2 hint goes through the notification stack.
hook.Add( "GR_StateChanged", "gr_hud_ghost", function( idx, name, v )
	if name ~= "Fate" or v ~= FATE_GHOST or idx ~= LocalPlayer():EntIndex() then return end
	HUD.Notify( "You are dead. Press F2 to choose a purpose in life." )
end )
