-- Screen effects, ported from the original's gui/cl_hud.lua (docs/05 §3): the constant breathing
-- bloom, each fate's ColorMod / MotionBlur, the aberrations, the map colour filter, low-health
-- blur, the despair sharpen, the red damage flash, the head wound, Frighten and Jumpscare (a
-- hallucination image, a contrast spike and DSP 28), and "I HAVE NO MOUTH AND I MUST SCREAM".
--
--   HUD.Frighten( snd )   HUD.Jumpscare( snd )   HUD.Headwound()   HUD.FlashRed()
--   HUD.Headwounded()     how hard the head wound still is (cl_view.lua sways the view with it)
--
-- The server starts them with gr_fx (sh_fx.lua); the red flash starts here when health drops.
-- Differences from the original, for cost only (docs/05 §6):
--   * the smoothed despair / pox / health are module locals updated once a frame, not HUD globals;
--   * DSP and the scare timings are one state read in Think, not timer chains, so overlapping
--     scares extend each other instead of one switching the other's DSP off;
--   * gr_lowfx 1 skips the bloom, the motion blurs and the sharpen passes (the colour grade stays).
local UI = Config.UI
local CT = CurTime

-- Smoothed values, one place, once a frame ------------------------------------------------------

local S = { despair = 0, pox = 0, health = 100, maxHealth = 100 }
local lastHealth, lastAlive
local flashStart, headwounded = nil, 0

local function need( ply, name )
	local get = ply[ "GetNeed_" .. name ]
	return get and get( ply ) or 0
end

-- DSP: one decision a frame, from the effect state. A scare opens a DSP 28 window from +0.2 s to
-- +0.5 s (the original's two timers); a scare during a window extends it. Then the head wound's
-- 35, then the base (HUD.BaseDSP: 0, or the ghost's muffled hearing).
local dsp = { from = 0, to = 0, current = nil }
local function baseDSP( ply ) return 0 end
HUD.BaseDSP = baseDSP
local function scareDSP()
	local now = CT()
	if now >= dsp.to then dsp.from = now + 0.2 end
	dsp.to = math.max( dsp.to, now + 0.5 )
end

hook.Add( "Think", "gr_effects", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) then return end
	local now = CT()
	S.despair = need( ply, "Despair" )
	S.pox = need( ply, "Pox" )
	S.maxHealth = math.max( ply:GetMaxHealth(), 1 )
	local h, alive = ply:Health(), ply:Alive()
	S.health = h
	if alive and lastAlive and lastHealth and h < lastHealth then HUD.FlashRed() end
	lastHealth, lastAlive = h, alive

	local want
	if now >= dsp.from and now < dsp.to then
		want = 28
	elseif headwounded > 0.5 then
		want = 35
	else
		want = HUD.BaseDSP( ply )
	end
	if want ~= dsp.current then
		dsp.current = want
		ply:SetDSP( want )
	end
end )

-- Scares ----------------------------------------------------------------------------------------

local hall = { start = nil, mat = nil, double = false }
local hallMats = {}
local function hallucination()
	local names = UI.Hallucinations
	local n = #names + UI.Postals
	for _ = 1, 6 do
		local i = math.random( n )
		local path = i <= #names and ( "placenta/" .. names[ i ] .. ".png" ) or ( "placenta/postal" .. ( i - #names ) .. ".png" )
		local m = hallMats[ path ]
		if m == nil then
			m = Material( path )
			if m:IsError() then m = false end
			hallMats[ path ] = m
		end
		if m then return m end
	end
end

local frightenPool
local function frightenSound()
	if not frightenPool then
		frightenPool = {}
		for _, s in ipairs( UI.FrightenFallback ) do table.insert( frightenPool, s ) end
		for _, s in ipairs( UI.Frighten ) do
			if file.Exists( "sound/" .. s, "GAME" ) then table.insert( frightenPool, s ) end
		end
	end
	return frightenPool[ math.random( #frightenPool ) ]
end

local function noScares() return not IsValid( LocalPlayer() ) end

function HUD.Frighten( snd )
	if noScares() then return end
	hall.start, hall.mat, hall.double = CT(), hallucination(), false
	LocalPlayer():EmitSound( snd or frightenSound(), 60, math.random( 80, 120 ) )
	scareDSP()
end

function HUD.Jumpscare( snd )
	if noScares() then return end
	hall.start, hall.mat, hall.double = CT(), hallucination(), true
	if not snd then
		snd = HUD.SoundPath( "placenta/jumpscare" .. math.min( math.random( 1, 9 ), UI.Jumpscares ) .. ".wav", UI.JumpscareFallback )
	end
	LocalPlayer():EmitSound( snd, 60, math.random( 60, 80 ) )
	scareDSP()
end

-- sh_chat (thoughtcrime, PMs) calls GAMEMODE:Jumpscare() / GAMEMODE:Frighten() when they exist.
local gm = GM or GAMEMODE
if gm then
	function gm:Jumpscare( snd ) HUD.Jumpscare( snd ) end
	function gm:Frighten( snd ) HUD.Frighten( snd ) end
end

function HUD.Headwound() headwounded = 2 end
function HUD.Headwounded() return headwounded end
function HUD.FlashRed() flashStart = CT() end

local FX_KINDS = { HUD.Headwound, function() HUD.Frighten() end, function() HUD.Jumpscare() end, HUD.FlashRed }
Net.Receive( "gr_fx", nil, function()
	local f = FX_KINDS[ net.ReadUInt( 3 ) ]
	if f then f() end
end )

-- The original's DrawDamage, under the HUD (layer 30) ------------------------------------------

HUD.Layer( 30, "damage", function( ply )
	local w, h = ScrW(), ScrH()
	local low = HUD.LowFx()
	if flashStart and ply:Alive() then
		local t = CT() - flashStart
		local a = 0
		if t < 0.1 then a = 0.5 elseif t < 0.6 then a = 0.5 - ( t - 0.1 ) end
		if a > 0 then
			surface.SetDrawColor( 128, 0, 0, 255 * a )
			surface.DrawRect( 0, 0, w, h )
		else
			flashStart = nil
		end
	end

	if headwounded > 0.1 then
		headwounded = Lerp( 0.01, headwounded, 0 )
		HUD.Blur( headwounded / 3 )
		if not low then DrawSharpen( headwounded / 2, headwounded ) end
	elseif headwounded > 0 then
		headwounded = 0
	end

	if hall.start then
		local t = CT() - hall.start
		local a = 0
		if t < 0.1 then
			a = hall.double and 1.5 or 1
		elseif t < 5 then
			a = ( hall.double and 1.5 or 1 ) - ( t - 0.1 ) / 2
		end
		if a > 0 and hall.mat then
			surface.SetMaterial( hall.mat )
			surface.SetDrawColor( 255, 255, 255, 255 * math.min( a, 1 ) )
			surface.DrawTexturedRect( 0, 0, w, h )
		end
		local contrast = 0
		if t < 0.1 then contrast = 3 elseif t < 6 then contrast = 3 - ( t - 2 ) end
		if contrast > 0 and hall.double and not low then DrawSharpen( contrast, contrast * 10 ) end
		if t >= 6 then hall.start = nil end
	end
end )

-- Voice: the original frightened and shouted at anyone who opened their mouth (the game is
-- text-only; voice is off on dedicated servers, §8). Only the local speaker gets it here.
local mic = { on = false, start = 0, nextFrighten = 0 }
hook.Add( "PlayerStartVoice", "gr_effects", function( ply )
	if ply ~= LocalPlayer() then return end
	HUD.Frighten()
	mic.on, mic.start, mic.nextFrighten = true, CT(), CT() + 0.23
end )
hook.Add( "PlayerEndVoice", "gr_effects", function( ply )
	if ply == LocalPlayer() then mic.on = false end
end )

HUD.Layer( 125, "warnings", function()
	if not mic.on or CT() - mic.start >= 3 then return end
	if CT() >= mic.nextFrighten then
		mic.nextFrighten = CT() + 0.23
		HUD.Frighten()
	end
	local col = HSVToColor( ( CT() * 666 ) % 360, 0.5, 1 )
	local col2 = HSVToColor( ( CT() * 2323 ) % 360, 0.5, 1 )
	local font = HUD.Font( "LabelStupid" )
	surface.SetFont( font )
	local text = "I HAVE NO MOUTH AND I MUST SCREAM"
	local tW = surface.GetTextSize( text )
	HUD.TextShadow( text, font, ScrW() / 2 - tW / 2, ( ScrH() - 250 ) / 2 + 20, col, col2, 0 )
end )

-- RenderScreenspaceEffects ----------------------------------------------------------------------

local ABERRATIONS = {
	{ r = 0, g = 0, b = 0, col = 0, con = 0, bri = 0 },
	{ r = 0, g = 0, b = 0, col = 0, con = 3, bri = -0.04 },
	{ r = 3, g = 3, b = 0, col = 0, con = 0, bri = -0.03 },
	{ r = 0, g = 0, b = 0, col = -4, con = 0, bri = -0.03 },
	{ r = 0, g = 0, b = 0, col = 0, con = 0, bri = 0 },
}
local aberration, nextAberration = 1, 0

-- The default map colour filter: rp_slumtown's MapColorFilter (the original's main map). A race
-- may tint it with ColorTable = { addr, addg, addb, mulr, mulg, mulb, colour, brightness, contrast }.
local grade = {}
local function mapFilter( ply, ab )
	local t = CT()
	local race = ply.GetRaceDef and ply:GetRaceDef()
	local rc = race and race.ColorTable
	local hurt = 1 - S.health / S.maxHealth
	local brightsin = ply.GetInjured and ply:GetInjured() and ( 0.25 * math.sin( t ) + 0.70 ) or 1
	local despair, pox = S.despair, S.pox
	grade[ "$pp_colour_addr" ] = rc and rc[ 1 ] or 0
	grade[ "$pp_colour_addg" ] = rc and rc[ 2 ] or 0
	grade[ "$pp_colour_addb" ] = rc and rc[ 3 ] or 0
	grade[ "$pp_colour_brightness" ] = ( 0 + ab.bri ) * ( rc and rc[ 8 ] or 1 )
	grade[ "$pp_colour_contrast" ] = ( 1 + ab.con + 0.2 * math.cos( t * 0.8 ) ) * ( rc and rc[ 9 ] or 1 ) * brightsin
	grade[ "$pp_colour_colour" ] = ( 2 + ab.col - despair / 100 + 0.5 * math.sin( t * 0.5 ) - hurt ) * ( rc and rc[ 7 ] or 1 )
	grade[ "$pp_colour_mulr" ] = ( 1 + ab.r + 0.1 * math.sin( t * ( 0.75 + hurt ) ) ) * ( rc and rc[ 4 ] or 1 )
	grade[ "$pp_colour_mulg" ] = ( 0 + ab.g + ( 3 * pox / 100 ) * math.cos( t * ( 0.5 + 3 * pox / 100 ) ) ) * ( rc and rc[ 5 ] or 1 )
	grade[ "$pp_colour_mulb" ] = ( 3 + ab.b + ( 3 * despair / 100 ) * math.cos( t * ( 0.5 + 3 * despair / 100 ) ) ) * ( rc and rc[ 6 ] or 1 )
	DrawColorModify( grade )
end
HUD.MapColorFilter = mapFilter

hook.Add( "RenderScreenspaceEffects", "gr_effects", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) or ply:GetMoveType() == MOVETYPE_NOCLIP then return end
	local t = CT()
	local low = HUD.LowFx()
	if not low then
		DrawBloom( 0.43, 2, 10 + 5 * math.sin( t ), 5 + 3 * math.cos( t * 0.3 ), 1, 3, 1, 1, 1 )
	end
	if not ply:Alive() then return end -- the corpse view's decomposition grade is deferred

	local fate = ply:GetFateDef()
	local override = false
	if fate then
		if fate.ColorMod then
			DrawColorModify( isfunction( fate.ColorMod ) and fate.ColorMod( ply ) or fate.ColorMod )
		end
		override = fate.ColorModOverride and true or false
		if fate.MotionBlur and not low then DrawMotionBlur( fate.MotionBlur[ 1 ], fate.MotionBlur[ 2 ], fate.MotionBlur[ 3 ] ) end
	end

	if not override then
		if t >= nextAberration then
			if aberration > 1 then
				aberration = 1
				nextAberration = t + math.random( 90, 300 )
			else
				aberration = math.random( 2, #ABERRATIONS )
				nextAberration = t + math.random( 1, 3 )
			end
		end
		HUD.MapColorFilter( ply, ABERRATIONS[ aberration ] )
		if S.health < 50 and not low then
			local hurt = 1 - S.health / S.maxHealth
			DrawMotionBlur( 0.15 * hurt, 0.8 * hurt, 0.2 )
		end
	end

	if not low and S.despair > 0 then
		DrawSharpen( 1 * math.sin( t * 0.5 ), 4 * math.Rand( 0.8, 1.2 ) * ( S.despair / 100 ) )
	end
end )
