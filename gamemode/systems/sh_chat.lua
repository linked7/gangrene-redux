-- Chat: local speech, emotes, OOC and radio. GMod's own chat broadcast is replaced: the server
-- picks the recipients with Chat.Recipients and sends gr_chat to exactly those players.
--
-- Two rules hold for every mode:
--   * Dead speakers (ghosts, or bodies waiting to respawn) reach only the dead, so the living
--     never hear ghosts. The dead may still hear the living nearby, and OOC, but not their radio.
--   * Radio reach is data: /r goes to everyone whose fate's Radio list shares a channel with
--     the speaker's (R9). Ghosts have their own channel, so ghost radio stays among ghosts.
Chat = Chat or {}

-- The one range table. range = nil means everyone (subject to the dead rule above).
-- spoken: the words pass through the race's ModifySpeech hook. Order is the parse order.
Chat.Modes = {
	{ id = "say", range = 400, spoken = true },
	{ id = "yell", prefixes = { "/y", "/yell" }, range = 1000, spoken = true },
	{ id = "whisper", prefixes = { "/w", "/whisper" }, range = 100, spoken = true },
	{ id = "me", prefixes = { "/me" }, range = 400 },
	{ id = "ooc", prefixes = { "//", "/ooc" } },
	{ id = "radio", prefixes = { "/r", "/radio" }, radio = true, spoken = true },
}

local byId = {}
for i, m in ipairs( Chat.Modes ) do
	m.index = i
	byId[ m.id ] = m
end
function Chat.Mode( id ) return byId[ id ] end

-- Dead for chat purposes: a ghost, or a body that hasn't respawned as one yet.
function Chat.IsDead( ply )
	return ply:IsGhost() or not ply:Alive()
end

Net.Pool( "gr_chat" )

if CLIENT then
	local OOC_COLOR = Color( 150, 150, 220 )
	local TEXT_COLOR = Color( 230, 230, 230 )
	local formats = {
		say = function( name, text ) return name, ": " .. text end,
		yell = function( name, text ) return name, " yells: " .. text end,
		whisper = function( name, text ) return name, " whispers: " .. text end,
		me = function( name, text ) return "* " .. name, " " .. text end,
		radio = function( name, text ) return "[Radio] " .. name, ": " .. text end,
	}

	Net.Receive( "gr_chat", nil, function()
		local speaker = net.ReadEntity()
		local mode = Chat.Modes[ net.ReadUInt( 3 ) ]
		local text = net.ReadString()
		if not IsValid( speaker ) or not mode then return end

		if mode.id == "ooc" then
			chat.AddText( OOC_COLOR, "[OOC] " .. speaker:SteamName(), TEXT_COLOR, ": " .. text )
			return
		end
		local f = speaker:GetFateDef()
		local name, rest = formats[ mode.id ]( speaker:Nick(), text )
		chat.AddText( f and f.Color or TEXT_COLOR, name, TEXT_COLOR, rest )
	end )
	return
end

-- Splits raw chat into a mode and the message body. Plain text is "say".
function Chat.Parse( text )
	for _, m in ipairs( Chat.Modes ) do
		for _, prefix in ipairs( m.prefixes or {} ) do
			local n = #prefix
			local after = string.sub( text, n + 1, n + 1 )
			-- A word prefix needs a space after it ("/r hi", not "/rant"); "//hi" needs none.
			local bounded = after == "" or after == " " or not string.match( prefix, "%a$" )
			if bounded and string.lower( string.sub( text, 1, n ) ) == prefix then
				return m, string.Trim( string.sub( text, n + 1 ) )
			end
		end
	end
	return byId.say, string.Trim( text )
end

local function shareChannel( a, b )
	if not a or not b then return false end
	for _, x in ipairs( a ) do
		for _, y in ipairs( b ) do
			if x == y then return true end
		end
	end
	return false
end

-- Who receives `speaker`'s message in `mode` (an id or a Chat.Modes entry).
-- Returns the list of players, speaker included, or nil and a reason the speaker can't use it.
function Chat.Recipients( speaker, mode )
	mode = istable( mode ) and mode or byId[ mode ]
	if not mode then return nil, "There is no such way to speak." end

	local channels = mode.radio and speaker:FateHas( "Radio" )
	if mode.radio and ( not channels or #channels == 0 ) then return nil, "You have no radio." end

	local dead = Chat.IsDead( speaker )
	local pos = speaker:GetPos()
	local rangeSqr = mode.range and mode.range * mode.range
	local out = { speaker }
	for _, p in player.Iterator() do
		local pDead = Chat.IsDead( p )
		-- Radio needs both ends on the same side: a body waiting to respawn hears no living radio.
		if p ~= speaker
			and ( not dead or pDead )
			and ( not rangeSqr or pos:DistToSqr( p:GetPos() ) <= rangeSqr )
			and ( not mode.radio or ( pDead == dead and shareChannel( channels, p:FateHas( "Radio" ) ) ) ) then
			table.insert( out, p )
		end
	end
	return out
end

-- Sends `text` from `speaker` in `mode`. Returns the recipients, or nil and a reason.
function Chat.Send( speaker, mode, text )
	mode = istable( mode ) and mode or byId[ mode ]
	if text == "" then return nil, "Say something." end
	local to, why = Chat.Recipients( speaker, mode )
	if not to then return nil, why end

	-- The single hook point for speech mangling (racial quirks, grammar); deferred for now.
	local race = mode.spoken and speaker:GetRaceDef()
	if race and race.ModifySpeech then
		local ok, out = xpcall( race.ModifySpeech, debug.traceback, speaker, text )
		if ok and isstring( out ) then text = out
		elseif not ok then Log.Error( "chat", "%s.ModifySpeech: %s", race.id, out ) end
	end

	net.Start( "gr_chat" )
	net.WriteEntity( speaker )
	net.WriteUInt( mode.index, 3 )
	net.WriteString( text )
	net.Send( to )
	hook.Run( "GR_Chat", speaker, mode, text, to )
	return to
end

-- Replaces GMod's broadcast; team chat (the other chat key) is a shortcut for radio.
function GM:PlayerSay( ply, text, teamChat )
	local mode, body
	if teamChat then mode, body = byId.radio, string.Trim( text )
	else mode, body = Chat.Parse( text ) end

	local ok, why = Chat.Send( ply, mode, body )
	if not ok and body ~= "" then Notify( ply, why ) end
	return ""
end
