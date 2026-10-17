-- The music player, ported from the original's framework/cl_music.lua (docs/05 §11): one song at
-- a time from Config.UI.Music, picked at random from the idle list (the alert list for ghosts)
-- after a 5 s gap, faded out over a second when it ends or is replaced. cc_musicvolume (0-100,
-- default 50; 0 turns it off) sets the volume; a fate change restarts the gap, like the original's
-- nResetMusic. Songs come from the content pack; a song that isn't installed is skipped.
--
--   HUD.PlayMusic( path, fade )   play a song now (fading the current one out over `fade` s)
--   HUD.FadeOutMusic( fade )
local volume = CreateClientConVar( "cc_musicvolume", "50", true, false, "Music volume, 0-100 (0 turns the music off).", 0, 100 )

local CT = CurTime
local M = { patch = nil, finished = 0, nextAuto = nil, fadeAt = nil, fading = false, next = nil, fate = nil }
local installed = {} -- path -> bool, checked once

local function song( path )
	for _, s in ipairs( Config.UI.Music or {} ) do
		if s[ 1 ] == path then return s end
	end
end

local function have( path )
	if installed[ path ] == nil then installed[ path ] = file.Exists( "sound/" .. path, "GAME" ) end
	return installed[ path ]
end

local function pick( kind )
	local list = {}
	for _, s in ipairs( Config.UI.Music or {} ) do
		if s[ 3 ] == kind and have( s[ 1 ] ) then list[ #list + 1 ] = s end
	end
	return list[ math.random( #list ) ]
end

local function canPlay() return volume:GetInt() > 0 end

function HUD.PlayMusic( path, fade )
	if not canPlay() then return end
	fade = fade or 1
	local now = CT()
	if M.patch then
		if fade > 0 and not M.fading and now < M.finished - 1 then
			M.patch:ChangeVolume( 0, fade )
			M.fadeAt = now + fade
		else
			M.fadeAt = now
		end
		M.next = path
		M.fading = true
		return
	end
	local ply = LocalPlayer()
	local s = song( path )
	if not IsValid( ply ) or not s then return end
	M.patch = CreateSound( ply, path )
	M.patch:SetSoundLevel( 0 )
	M.patch:Play()
	M.patch:ChangeVolume( volume:GetInt() / 100 )
	M.finished = now + s[ 2 ]
	M.nextAuto = now + s[ 2 ] + 5
	MsgC( Color( 150, 150, 150 ), "Now playing ", Color( 150, 220, 0 ), s[ 4 ], Color( 150, 150, 150 ), "...\n" )
end

function HUD.FadeOutMusic( fade )
	fade = fade or 1
	if not M.patch or M.fading then return end
	M.fading = true
	if fade > 0 then
		M.patch:ChangeVolume( 0, fade )
		M.fadeAt = CT() + fade
		M.finished = CT() + fade
	else
		M.patch:Stop()
		M.patch = nil
		M.fading = false
	end
end

local nextThink = 0
hook.Add( "Think", "gr_music", function()
	local now = CT()
	if now < nextThink then return end
	nextThink = now + 0.25
	local ply = LocalPlayer()
	if not IsValid( ply ) then return end
	M.nextAuto = M.nextAuto or now + 5

	-- A new fate starts the gap again (the original's nResetMusic on OnChange).
	local fate = ply:GetFate()
	if fate ~= M.fate then
		if M.fate ~= nil then M.nextAuto, M.finished = now + 5, now end
		M.fate = fate
	end

	if M.patch and not canPlay() then HUD.FadeOutMusic( 0 ) end
	-- The volume follows cc_musicvolume while a song plays (the original only read it at the start).
	local vol = volume:GetInt()
	if M.patch and not M.fading and vol ~= M.vol then M.patch:ChangeVolume( vol / 100 ) end
	M.vol = vol
	if M.patch and now > M.finished then HUD.FadeOutMusic() end
	if M.patch and M.fadeAt and now >= M.fadeAt then
		M.patch:Stop()
		M.patch, M.fadeAt, M.fading = nil, nil, false
	end
	if M.next and not M.patch then
		local path = M.next
		M.next = nil
		HUD.PlayMusic( path )
	end

	if not M.patch and canPlay() and ply:Alive() and now >= M.finished + 1 and now >= M.nextAuto then
		local s = pick( ply:IsGhost() and "alert" or "idle" )
		if s then HUD.PlayMusic( s[ 1 ] ) else M.nextAuto = now + 60 end
	end
end )
