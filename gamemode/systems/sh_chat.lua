-- Chat: local speech, emotes, LOOC, OOC, radio, staff and private messages (step 12, parity 05 §8).
-- GMod's own chat broadcast is replaced: GM:PlayerSay hands every line to Chat.Handle, the server
-- picks the recipients and sends gr_chat to exactly those players. The client only formats.
--
--   Chat.Handle( ply, text, teamChat )  the whole pipeline: kill sentences, thoughtcrime, parse, send
--   Chat.Send( speaker, mode, text )    one line in one mode -> recipients, or nil and the refusal
--   Chat.Recipients( speaker, mode )    who would hear it (speaker included), or nil and why
--   Chat.AutoGrammar( text, lower )     chat-speak corrected (Config.ChatStupidMistakes)
--   Chat.Thoughtcrime( text )           the banned word or sentence found, or nil
--   Chat.Babble( ply, level, filter )   the fate's ChatSounds; returns the sounds played
--   Chat.Tell( ply, color, text, fx )   one coloured line to one player (refusals, notices)
--
-- Rules:
--   * Ranges come from Chat.Modes. A listener the speaker can't see (one trace) hears only within
--     the muffled range (the original's GetRF).
--   * Dead speakers (ghosts, or bodies already dead) reach only the dead, so the living never hear
--     ghosts. The dead may still hear the living nearby. Staff and private messages are exempt.
--   * The downed (lying in their body, not yet dead) count as living: plain speech becomes a
--     whisper, and the kill sentences end them.
--   * Radio reach is data: /r goes to everyone whose fate's Radio list shares a channel (R9).
--   * Races never change speech (user decision): no Accent, no RacialQuirks.
--   * Voice chat is off on dedicated servers; this is text roleplay.
Chat = Chat or {}

local RED = Color( 200, 0, 0 )

-- The one range table. range = nil means everyone (subject to the dead rule). muffled is the range
-- when the speaker can't see the listener. sound is the babble level. Order is the wire index.
Chat.Modes = {
	{ id = "say", range = 512, muffled = 256, spoken = true, sound = 75, tag = " " },
	{ id = "yell", prefixes = { "/y", "/yell" }, range = 1024, muffled = 768, spoken = true, sound = 85, tag = "Y", font = "ChatBig" },
	{ id = "whisper", prefixes = { "/w", "/whisper" }, range = 128, muffled = 0, spoken = true, sound = 25, tag = "W", font = "ChatSmall" },
	{ id = "me", prefixes = { "/me" }, range = 512, muffled = 256, tag = "M" },
	{ id = "looc", prefixes = { ".//", "[[", "/looc" }, range = 512, muffled = 256, ooc = true, tag = "L" },
	{ id = "ooc", prefixes = { "//", "/ooc" }, ooc = true, tag = "O" },
	{ id = "radio", prefixes = { "/r", "/radio" }, radio = true, spoken = true, range = 512, muffled = 256, tag = "R", font = "ChatRadio" },
	{ id = "admin", prefixes = { "/a" }, staff = true, ooc = true, tag = "A" },
	{ id = "pm", prefixes = { "/pm" }, ooc = true, tag = "P" },
	{ id = "roll", prefixes = { "/roll" }, self = true },
	{ id = "help", prefixes = { "/help" }, self = true },
	{ id = "content", prefixes = { "/content" }, self = true },
}

local byId = {}
local prefixes = {} -- { prefix, mode }, longest first, as the original sorted its commands
for i, m in ipairs( Chat.Modes ) do
	m.index = i
	byId[ m.id ] = m
	for _, p in ipairs( m.prefixes or {} ) do table.insert( prefixes, { p, m } ) end
end
table.sort( prefixes, function( a, b )
	if #a[ 1 ] ~= #b[ 1 ] then return #a[ 1 ] > #b[ 1 ] end
	return a[ 1 ] < b[ 1 ]
end )
function Chat.Mode( id ) return byId[ id ] end

-- The content pack (05 §1), opened by /content.
Chat.CONTENT_URL = "https://steamcommunity.com/sharedfiles/filedetails/?id=3067207405"

-- How each line reads (05 §8, the original's formats and colours): chat.AddText's arguments.
-- channel is the radio label, or "" for a bystander hearing the speaker's side.
local GREY = Color( 160, 160, 160 )
local formats = {
	say = function( name, text ) return { Color( 180, 150, 0 ), name .. " says, \"" .. text .. "\"" } end,
	yell = function( name, text ) return { RED, name .. " yells, \"" .. text .. "\"" } end,
	whisper = function( name, text ) return { Color( 200, 200, 200 ), name .. " whispers, \"" .. text .. "\"" } end,
	me = function( name, text ) return { Color( 132, 198, 118 ), name .. " " .. text } end,
	looc = function( name, text )
		return { Color( 158, 0, 0 ), "[LOOC] ", Color( 141, 187, 89 ), name .. ": ", Color( 87, 149, 179 ), text }
	end,
	ooc = function( name, text )
		return { RED, "[OOC] ", Color( 183, 239, 119 ), name .. ": ", Color( 119, 201, 239 ), text }
	end,
	radio = function( name, text, channel )
		if channel == "" then return { GREY, name .. " says over the radio, \"" .. text .. "\"" } end
		return { GREY, "[" .. channel .. "] " .. name .. " crackles, \"" .. text .. "\"" }
	end,
	admin = function( name, text ) return { Color( 198, 51, 51 ), "[NECROMANCER] " .. name .. ": " .. text } end,
	pm_from = function( name, text ) return { Color( 255, 183, 58 ), "[OOC PM from " .. name .. "]: " .. text } end,
	pm_to = function( name, text ) return { Color( 255, 183, 58 ), "[OOC PM to " .. name .. "]: " .. text } end,
}
function Chat.Format( kind, name, text, channel )
	local f = formats[ kind ]
	return f and f( name, text, channel or "" )
end

-- Plain text of a formatted line (tests and logs).
function Chat.Plain( line )
	local out = {}
	for _, part in ipairs( line or {} ) do
		if isstring( part ) then table.insert( out, part ) end
	end
	return table.concat( out )
end

Net.Pool( "gr_chat" )
Net.Pool( "gr_chat_line" )
Net.Pool( "gr_chat_pm" )
Net.Pool( "gr_chat_self" )
Net.Pool( "gr_chat_gesture" )

-- Client ------------------------------------------------------------------------------------
if CLIENT then
	-- The chat box (owned by the UI pass) can take a line over: return true from
	-- GR_ChatLine( modeId, font, ... ) to draw it yourself. `...` are chat.AddText's arguments;
	-- font is nil, "ChatBig", "ChatSmall" or "ChatRadio" (CombineControl.* in the original).
	local function addLine( modeId, font, ... )
		if hook.Run( "GR_ChatLine", modeId, font, ... ) == true then return end
		chat.AddText( ... )
	end
	Chat.AddLine = addLine

	Net.Receive( "gr_chat", nil, function()
		local mode = Chat.Modes[ net.ReadUInt( 4 ) ]
		local name = net.ReadString()
		local text = net.ReadString()
		local channel = net.ReadString() -- radio: the channel label, or "" for a bystander
		if not mode then return end
		local line = Chat.Format( mode.id, name, text, channel )
		if line then addLine( mode.id, mode.font, unpack( line ) ) end
	end )

	-- Jumpscare and Frighten are the UI pass's (05 §2, §7). Until they exist, the sound and DSP.
	local dspAt, dspOff
	local function jumpscare()
		if GAMEMODE.Jumpscare then GAMEMODE:Jumpscare() return end
		LocalPlayer():EmitSound( "placenta/jumpscare" .. math.min( math.random( 1, 9 ), 8 ) .. ".wav", 60, math.random( 60, 80 ) )
		dspAt, dspOff = CurTime() + 0.2, CurTime() + 0.5
		hook.Run( "GR_Jumpscare" )
	end
	Chat.Jumpscare = jumpscare
	hook.Add( "Think", "gr_chat_dsp", function()
		if dspAt and CurTime() >= dspAt then LocalPlayer():SetDSP( 28 ) dspAt = nil end
		if dspOff and CurTime() >= dspOff then LocalPlayer():SetDSP( 0 ) dspOff = nil end
	end )
	local function frighten()
		if GAMEMODE.Frighten then GAMEMODE:Frighten() else hook.Run( "GR_Frighten" ) end
	end

	-- fx: 0 none, 1 frighten, 2 jumpscare (thoughtcrime).
	Net.Receive( "gr_chat_line", nil, function()
		local col = net.ReadColor( false )
		local text = net.ReadString()
		local fx = net.ReadUInt( 2 )
		if fx == 1 then frighten() elseif fx == 2 then jumpscare() end
		addLine( "notice", nil, col, text )
	end )

	Net.Receive( "gr_chat_pm", nil, function()
		local from = net.ReadBool()
		local name = net.ReadString()
		local text = net.ReadString()
		addLine( "pm", nil, unpack( Chat.Format( from and "pm_from" or "pm_to", name, text ) ) )
		LocalPlayer():EmitSound( "ambient/creatures/town_child_scream1.wav", 0, math.random( 80, 120 ) )
	end )

	-- /roll leans the view over and back (the original's ViewRoll target of -300 for half a second).
	-- Chat.ViewRoll() steps and returns the current lean; cl_view.lua's CalcView calls it once a
	-- frame and adds it to the roll (one CalcView answers, so there is no hook here).
	local rollUntil, viewRoll = 0, 0
	function Chat.ViewRoll()
		viewRoll = Lerp( 0.03, viewRoll, CurTime() < rollUntil and -300 or 0 )
		if math.abs( viewRoll ) < 0.5 then viewRoll = 0 end
		return viewRoll
	end

	Net.Receive( "gr_chat_self", nil, function()
		local what = net.ReadString()
		if what == "roll" then
			rollUntil = CurTime() + 0.5
			LocalPlayer():EmitSound( "ambient/machines/catapult_throw.wav" )
		elseif what == "help" then
			RunConsoleCommand( "gr_help" )
		elseif what == "content" then
			gui.OpenURL( Chat.CONTENT_URL )
		end
	end )

	Net.Receive( "gr_chat_gesture", nil, function()
		local ply = net.ReadEntity()
		local seq = net.ReadString()
		if not IsValid( ply ) then return end
		local id = ply:LookupSequence( seq )
		if id and id >= 0 then ply:AddVCDSequenceToGestureSlot( GESTURE_SLOT_CUSTOM, id, 0, true ) end
	end )
	return
end

-- Server ------------------------------------------------------------------------------------

-- Splits raw chat into a mode and the message body. Plain text is "say".
function Chat.Parse( text )
	local lower = string.lower( text )
	for _, entry in ipairs( prefixes ) do
		local prefix, m = entry[ 1 ], entry[ 2 ]
		local n = #prefix
		local after = string.sub( text, n + 1, n + 1 )
		-- A word prefix needs a space after it ("/r hi", not "/rant"); "//hi" needs none.
		local bounded = after == "" or after == " " or not string.match( prefix, "%a$" )
		if bounded and string.sub( lower, 1, n ) == prefix then
			return m, string.Trim( string.sub( text, n + 1 ) )
		end
	end
	return byId.say, string.Trim( text )
end

-- States -------------------------------------------------------------------------------------

-- Downed: HP hit 0 and the body lies there, wounded or dying (sh_corpse.lua). The original's
-- "bleedout" ragdoll.
function Chat.IsDowned( ply )
	if ply:Alive() then return false end
	local _, rec = Corpse.Of( ply )
	return rec ~= nil and rec.state == "downed"
end

-- Dead for chat: a ghost, or a body that is past saving and hasn't come back as a ghost yet.
function Chat.IsDead( ply )
	return ply:IsGhost() or ( not ply:Alive() and not Chat.IsDowned( ply ) )
end

-- Where a player speaks and listens from: their body on the ground while downed.
local function body( ply )
	if not ply:Alive() then
		local rag = Corpse.Of( ply )
		if IsValid( rag ) then return rag end
	end
	return ply
end
function Chat.Pos( ply ) return body( ply ):GetPos() end
local function ear( ply )
	local b = body( ply )
	return b == ply and ply:EyePos() or b:WorldSpaceCenter()
end

-- One trace, speaker's eyes to the listener's: true if nothing solid is in between.
function Chat.CanHear( speaker, listener )
	local from, to = body( speaker ), body( listener )
	local tr = util.TraceLine( { start = ear( speaker ), endpos = ear( listener ), filter = { speaker, from }, mask = MASK_SOLID } )
	return not tr.Hit or tr.Entity == listener or tr.Entity == to
end

-- In earshot for a ranged mode: the muffled range applies when the speaker can't see them.
function Chat.InRange( speaker, listener, mode )
	if not mode.range then return true end
	local dist = Chat.Pos( speaker ):Distance( Chat.Pos( listener ) )
	if dist >= mode.range then return false end
	if mode.muffled ~= mode.range and dist >= mode.muffled and not Chat.CanHear( speaker, listener ) then return false end
	return true
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

local function isStaff( p ) return Admin and Admin.IsStaff( p ) and IsValid( p ) end

-- Who receives `speaker`'s message in `mode` (an id or a Chat.Modes entry).
-- Returns the list of players, speaker included, or nil and a reason the speaker can't use it.
-- Radio returns the channel; Chat.Bystanders adds the people standing near the speaker.
function Chat.Recipients( speaker, mode )
	mode = istable( mode ) and mode or byId[ mode ]
	if not mode then return nil, "There is no such way to speak." end

	local channels = mode.radio and speaker:FateHas( "Radio" )
	if mode.radio and ( not channels or #channels == 0 ) then return nil, "You need a radio for this." end

	local dead = Chat.IsDead( speaker )
	local out = { speaker }
	for _, p in player.Iterator() do
		if p ~= speaker then
			local pDead = Chat.IsDead( p )
			local ok
			if mode.staff then ok = isStaff( p )
			elseif mode.radio then ok = pDead == dead and shareChannel( channels, p:FateHas( "Radio" ) )
			else ok = ( not dead or pDead ) and Chat.InRange( speaker, p, mode ) end
			if ok then table.insert( out, p ) end
		end
	end
	return out
end

-- Radio bystanders: people near the speaker who are not on the channel hear the speaker's side.
function Chat.Bystanders( speaker, channel )
	local on = {}
	for _, p in ipairs( channel ) do on[ p ] = true end
	local dead = Chat.IsDead( speaker )
	local out = {}
	for _, p in player.Iterator() do
		if not on[ p ] and ( not dead or Chat.IsDead( p ) ) and Chat.InRange( speaker, p, byId.radio ) then
			table.insert( out, p )
		end
	end
	return out
end

-- Refusals and redirects (05 §8, the original's lines). Returns the mode to use, or nil and the line.
function Chat.Route( speaker, mode )
	if mode.ooc or mode.self then return mode end
	local downed = Chat.IsDowned( speaker )
	local deadBody = not speaker:Alive() and not downed
	local out = speaker:GetPassedOut()
	local id = mode.id

	if id == "me" then
		if not speaker:Alive() then return nil, "You can't do this while dead." end
		return mode
	end
	if id == "radio" then
		local channels = speaker:FateHas( "Radio" )
		if not channels or #channels == 0 then return nil, "You need a radio for this." end
		if not speaker:Alive() then return nil, "You're cursed. You can't talk while dead." end
		if out then return nil, "You're unconscious. You can't talk." end
		if hook.Run( "GR_RadioJammed", speaker ) == true then return nil, "Your radio refuses to work." end
		if speaker:GetInjured() then return nil, "Your feeble voice isn't picked up by the radio." end
		return mode
	end

	if deadBody then
		if id == "yell" then return nil, "The dead must speak quietly and politely." end
		if id == "whisper" then return nil, "Noone will hear your whimpers anymore." end
		return nil, "Your tongue has all but rotted away."
	end
	if id == "yell" and speaker:IsGhost() then return nil, "The dead must speak quietly and politely." end
	if out then return nil, "You're unconscious. You can't talk." end
	if downed then return byId.whisper end -- bleeding out, the voice is a whisper
	return mode
end

-- AutoGrammar ----------------------------------------------------------------------------------

local mistakes -- sorted once: longest first, so "liver failure forever" wins over "liver failure"
local function mistakeList()
	if mistakes then return mistakes end
	mistakes = {}
	for k, v in pairs( Config.ChatStupidMistakes ) do table.insert( mistakes, { k, v } ) end
	table.sort( mistakes, function( a, b )
		if #a[ 1 ] ~= #b[ 1 ] then return #a[ 1 ] > #b[ 1 ] end
		return a[ 1 ] < b[ 1 ]
	end )
	return mistakes
end

-- The original's GM:AutoGrammar: each mistake is fixed once in the middle, before a comma, at the
-- start and at the end; then the first letter is capitalised (lowered with `lower`) and a full
-- stop added if the line has no closing punctuation.
function Chat.AutoGrammar( arg, lower )
	for _, pair in ipairs( mistakeList() ) do
		local k, v = pair[ 1 ], pair[ 2 ]
		local s, e = string.find( string.lower( arg ), " " .. k .. " ", 1, true )
		if s then arg = string.sub( arg, 1, s - 1 ) .. " " .. v .. " " .. string.sub( arg, e + 1 ) end

		s, e = string.find( arg, " " .. k .. ",", 1, true )
		if s then arg = string.sub( arg, 1, s - 1 ) .. " " .. v .. "," .. string.sub( arg, e + 1 ) end

		if string.sub( arg, 1, #k + 1 ) == k .. " " or string.lower( arg ) == k then
			arg = v .. string.sub( arg, #k + 1 )
		end

		if string.sub( arg, #arg - #k ) == " " .. k then
			arg = string.sub( arg, 1, #arg - #k - 1 ) .. " " .. v
		end
	end

	local first = string.sub( arg, 1, 1 )
	arg = ( lower and string.lower( first ) or string.upper( first ) ) .. string.sub( arg, 2 )
	local last = string.sub( arg, -1 )
	if last ~= "." and last ~= "!" and last ~= "?" and last ~= ":" and last ~= ";" and last ~= "," then
		arg = arg .. "."
	end
	return arg
end

-- Thoughtcrime and kill sentences -----------------------------------------------------------------

local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"

-- Common circumventions undone ("b4s3d" -> "based"), character by character.
function Chat.Uncircumvent( text )
	return ( string.gsub( text, UTF8_CHAR, Config.ChatCircumventions ) )
end

-- The banned word or sentence in `text`, or nil.
function Chat.Thoughtcrime( text )
	local check = string.lower( Chat.Uncircumvent( text ) )
	for _, w in ipairs( Config.ChatBadWords ) do
		if string.find( check, string.lower( w ), 1, true ) then return w end
	end
	local bare = string.gsub( check, "%s+", "" )
	for _, s in ipairs( Config.ChatBadSentences ) do
		if string.gsub( s, "%s+", "" ) == bare then return s end
	end
end

function Chat.IsKillSentence( text )
	local bare = string.gsub( Chat.Uncircumvent( text ), "%s+", "" )
	for _, s in ipairs( Config.ChatKillSentences ) do
		if string.gsub( s, "%s+", "" ) == bare then return true end
	end
	return false
end

-- Lines to one player ---------------------------------------------------------------------------

-- fx: 0 none, 1 frighten, 2 jumpscare. GR_ChatTell( ply, color, text, fx ) lets tests listen.
function Chat.Tell( ply, color, text, fx )
	hook.Run( "GR_ChatTell", ply, color, text, fx or 0 )
	net.Start( "gr_chat_line" )
	net.WriteColor( color, false )
	net.WriteString( text )
	net.WriteUInt( fx or 0, 2 )
	net.Send( ply )
end

local function tellStaff( color, text )
	for _, p in player.Iterator() do
		if isStaff( p ) then Chat.Tell( p, color, text ) end
	end
end

-- Sounds and gestures -----------------------------------------------------------------------------

-- Only the dead hear a dead speaker's sounds.
local function deadFilter()
	local rf = RecipientFilter()
	for _, p in player.Iterator() do
		if Chat.IsDead( p ) then rf:AddPlayer( p ) end
	end
	return rf
end
local function soundFilter( ply ) return Chat.IsDead( ply ) and deadFilter() or nil end

-- The fate's ChatSounds: a list of sounds (pitch 80-120), or function( ply, emit ) that calls
-- emit( sound, pitch ) itself. Plays at `level` from the speaker; returns the sounds played.
function Chat.Babble( ply, level, filter )
	local played = {}
	local function emit( snd, pitch )
		pitch = pitch or math.random( 80, 120 )
		table.insert( played, snd )
		ply:EmitSound( snd, level, pitch, 1, CHAN_AUTO, 0, 0, filter )
	end
	local sounds = ply:FateHas( "ChatSounds" )
	if isfunction( sounds ) then
		local ok, err = xpcall( sounds, debug.traceback, ply, emit )
		if not ok then Log.Error( "chat", "ChatSounds: %s", err ) end
	elseif istable( sounds ) and #sounds > 0 then
		emit( sounds[ math.random( #sounds ) ] )
	end
	return played
end

local SIGHS = { "placenta/suffering/sigh2.ogg", "placenta/suffering/sigh3.ogg", "placenta/suffering/sigh4.ogg" }

-- Holstered: nothing in hand. A holster system may define ply:IsHolstered() and is asked first.
function Chat.IsHolstered( ply )
	if ply.IsHolstered then return ply:IsHolstered() end
	return not IsValid( ply:GetActiveWeapon() )
end

local function gesture( ply, to )
	if not ply:Alive() or ( ply.GR_GestureAt or 0 ) > CurTime() or not Chat.IsHolstered( ply ) then return end
	if math.random( 1, 3 ) ~= 1 then return end
	local list = ply:FateHas( "ChatGestures" ) or Config.ChatGestures
	if not list or #list == 0 then return end
	ply.GR_GestureAt = CurTime() + math.random( 5, 15 )
	net.Start( "gr_chat_gesture" )
	net.WriteEntity( ply )
	net.WriteString( list[ math.random( #list ) ] )
	net.Send( to )
end

-- Sending -----------------------------------------------------------------------------------------

local function send( to, mode, name, text, channel )
	net.Start( "gr_chat" )
	net.WriteUInt( mode.index, 4 )
	net.WriteString( name )
	net.WriteString( text )
	net.WriteString( channel or "" )
	net.Send( to )
end

local function radioSound( ply, channel )
	if ply:FateHas( "NoRadioSound" ) then return end
	local snd = "ambient/levels/prison/radio_random" .. math.random( 1, 15 ) .. ".wav"
	local filter = soundFilter( ply )
	for _, p in ipairs( channel ) do p:EmitSound( snd, 75, math.random( 80, 120 ), 1, CHAN_AUTO, 0, 0, filter ) end
end

-- Sends `text` from `speaker` in `mode`. Returns the recipients, or nil and the refusal line.
-- The mode may change on the way (a downed speaker's say is a whisper).
function Chat.Send( speaker, mode, text )
	mode = istable( mode ) and mode or byId[ mode ]
	if not mode then return nil, "There is no such way to speak." end
	text = string.Trim( text or "" )
	if text == "" then return nil end
	local why
	mode, why = Chat.Route( speaker, mode )
	if not mode then return nil, why end

	local to
	to, why = Chat.Recipients( speaker, mode )
	if not to then return nil, why end

	if mode.spoken then text = Chat.AutoGrammar( text ) end
	if mode.id == "yell" then
		text = string.upper( text )
		local punc = string.sub( text, -1 )
		if punc == "." then text = string.sub( text, 1, -2 ) .. "!"
		elseif punc == "?" then text = text .. "!" end
	end

	-- Names: in character the RP name; OOC and staff lines the account name.
	local name = ( mode.id == "ooc" or mode.id == "admin" ) and speaker:SteamName() or speaker:Nick()
	if mode.radio then
		local label = speaker:FateHas( "CustomRadio" ) or "Radio"
		send( to, mode, name, text, label )
		local near = Chat.Bystanders( speaker, to )
		if #near > 0 then send( near, mode, name, text, "" ) end
		radioSound( speaker, to )
	else
		send( to, mode, name, text )
	end

	if mode.sound then
		local filter = soundFilter( speaker )
		if speaker:Alive() then
			Chat.Babble( speaker, mode.sound, filter )
		elseif mode.id == "whisper" and Chat.IsDowned( speaker ) then
			body( speaker ):EmitSound( SIGHS[ math.random( #SIGHS ) ], 55, math.random( 80, 120 ) )
		end
	end
	if mode.id == "say" then gesture( speaker, to ) end

	Log.Info( "chat", "%s, [%s] %s: %s", speaker:SteamName(), mode.tag or "?", name, text )
	hook.Run( "GR_Chat", speaker, mode, text, to )
	return to
end

-- OOC cooldown and the off switch. Returns true, or false after telling the speaker.
local function oocAllowed( ply )
	if isStaff( ply ) then return true end
	local delay = Config.OOCDelay
	if delay >= Config.ChatOOCOff then
		Chat.Tell( ply, Color( 200, 200, 200 ), "OOC has been disabled.\nConsider using our discord or LOOC with .// instead.", 1 )
		return false
	end
	local last = ply.GR_LastOOC
	if last and CurTime() < last + delay then
		Chat.Tell( ply, Color( 200, 200, 200 ), "Wait " .. math.Round( last + delay - CurTime() ) .. " seconds to talk in OOC.", 1 )
		return false
	end
	ply.GR_LastOOC = CurTime()
	return true
end

-- /pm <name> <message>: the target, the sender, and staff see it.
function Chat.PM( ply, body )
	local targ = string.Explode( " ", body )[ 1 ] or ""
	local text = string.Trim( string.sub( body, #targ + 2 ) )
	local target = targ ~= "" and Admin.Find( targ )
	if not IsValid( target ) then
		Chat.Tell( ply, RED, "Nobody could be found named '" .. targ .. "'." )
		return nil
	end
	if text == "" then return nil end
	net.Start( "gr_chat_pm" ) net.WriteBool( true ) net.WriteString( ply:SteamName() ) net.WriteString( text ) net.Send( target )
	net.Start( "gr_chat_pm" ) net.WriteBool( false ) net.WriteString( target:SteamName() ) net.WriteString( text ) net.Send( ply )
	local line = "[PM] (" .. ply:SteamName() .. " to " .. target:SteamName() .. "): " .. text
	tellStaff( Color( 138, 100, 30 ), line )
	Log.Info( "chat", "[P] (%s) [PM to %s]: %s", ply:SteamName(), target:SteamName(), text )
	hook.Run( "GR_Chat", ply, byId.pm, text, { ply, target } )
	return target
end

-- The kill sentence: said while downed, the head bursts and the body is finished.
function Chat.BurstHead( ply )
	local rag = Corpse.Of( ply )
	if not IsValid( rag ) then return false end
	Chat.Tell( ply, Color( 255, 0, 0 ), "SO BE IT" )
	local bone = rag:LookupBone( "ValveBiped.Bip01_Head1" )
	if bone then
		rag:ManipulateBoneScale( bone, Vector( 0, 0, 0 ) )
		local fx = EffectData()
		fx:SetOrigin( rag:GetBonePosition( bone ) )
		fx:SetScale( 0.4 )
		util.Effect( "BloodImpact", fx )
	end
	rag:EmitSound( "placenta/head_explodie_0" .. math.random( 1, 4 ) .. ".ogg", 100, 100, 1 )
	rag:EmitSound( "physics/flesh/flesh_squishy_impact_hard" .. math.random( 1, 4 ) .. ".wav", 100, 100, 1 )
	Log.Info( "chat", "%s spoke the kill sentence", ply:Nick() )
	return Corpse.FinishOff( rag )
end

-- Thoughtcrime: nothing is sent; the speaker is scared and shown the word, and the living are
-- wanted and reported to staff.
function Chat.Punish( ply, word )
	Chat.Tell( ply, RED, "'" .. word .. "'", 2 )
	if ply:IsGhost() then return end
	tellStaff( RED, ply:Nick() .. " (" .. ply:SteamName() .. ") wanted to say '" .. word .. "'." )
	Crime.MakeWanted( ply, WANTED_TORMENT, Config.ChatThoughtcrimeWanted, "thoughtcrime" )
	Log.Info( "chat", "%s (%s) thoughtcrime: %s", ply:Nick(), ply:SteamName(), word )
end

-- One line of chat from a player, start to finish. Team chat (the other chat key) is radio.
-- Returns the recipients, or nil and why (refusals are already told to the player).
function Chat.Handle( ply, text, teamChat )
	text = string.Trim( text or "" )
	if text == "" then return nil end

	if Chat.IsDowned( ply ) and Chat.IsKillSentence( text ) then
		Chat.BurstHead( ply )
		return nil, "kill sentence"
	end
	if not isStaff( ply ) then
		local word = Chat.Thoughtcrime( text )
		if word then
			Chat.Punish( ply, word )
			return nil, "thoughtcrime"
		end
	end

	local mode, body
	if teamChat then mode, body = byId.radio, text
	else mode, body = Chat.Parse( text ) end

	if mode.self then
		net.Start( "gr_chat_self" ) net.WriteString( mode.id ) net.Send( ply )
		return { ply }
	end
	if body == "" then return nil end
	if mode.id == "pm" then return Chat.PM( ply, body ) end
	if mode.id == "ooc" and not oocAllowed( ply ) then return nil, "ooc" end

	local to, why = Chat.Send( ply, mode, body )
	if not to and why then Chat.Tell( ply, RED, why ) end
	return to, why
end

-- Replaces GMod's broadcast.
function GM:PlayerSay( ply, text, teamChat )
	Chat.Handle( ply, text, teamChat )
	return ""
end

-- Voice chat is off on dedicated servers (the original's sv_player.lua). Ghost voice: sh_ghost.lua.
function GM:PlayerCanHearPlayersVoice( listener, talker )
	return not game.IsDedicated()
end

-- gr_oocdelay <seconds>: staff set the OOC cooldown; Config.ChatOOCOff or more turns OOC off.
concommand.Add( "gr_oocdelay", function( ply, _, args )
	if not Admin.IsStaff( ply ) then return end
	local n = tonumber( args[ 1 ] )
	if not n or n ~= n or n < 0 then return end
	Config.OOCDelay = n
	Log.Info( "admin", "%s set the OOC delay to %s", IsValid( ply ) and ply:SteamName() or "console", n )
end )
