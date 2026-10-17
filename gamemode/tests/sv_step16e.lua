-- Step 16e: chat parity (05 §8). Muffled ranges behind a wall, the commands' formats, thoughtcrime,
-- the dead and the downed, kill sentences, AutoGrammar, fate babble and voice chat being off.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t16e_%'" )

	local function bot( name, fate, rank )
		local b = player.CreateNextBot( "t16e_" .. name )
		b.T16 = name
		if fate then
			b:SetRank( rank or RANK_FRIEND ) b:SetStemCells( 10 )
			T.Check( Fates.Take( b, fate ), name .. " takes " .. fate )
		end
		return b
	end
	local function names( list )
		if not list then return "nil" end
		local out = {}
		for _, p in ipairs( list ) do table.insert( out, p.T16 or p:SteamName() ) end
		table.sort( out )
		return table.concat( out, "," )
	end

	local a = bot( "a", "prole" )
	local b = bot( "b", "prole" )
	local m = bot( "m", "korpsman" )
	local s = bot( "s", "sanitar" )
	local staff = bot( "staff", "prole" )
	local sl = bot( "sl", "slave", RANK_FOOLISH )
	local g = bot( "g" )
	T.Wait( 0.2 )

	local realStaff = Admin.IsStaff
	Admin.IsStaff = function( p ) return not IsValid( p ) or p == staff end

	-- Everyone else stands well away, so only a and b are in play for the range checks.
	local base = Vector( -2000, -2000, 200 )
	local far = { m = 3000, s = 3500, staff = 4000, sl = 4500, g = 5000 }
	local function park()
		for _, p in ipairs( { m, s, staff, sl, g } ) do p:SetPos( base + Vector( 0, far[ p.T16 ], 0 ) ) end
	end
	park()
	local function heard( mode, dist, msg, want )
		a:SetPos( base )
		b:SetPos( base + Vector( dist, 0, 0 ) )
		T.Equal( names( Chat.Recipients( a, mode ) ), want and "a,b" or "a", msg )
	end

	-- Ranges in the open: say 512, yell 1024, whisper 128.
	heard( "say", 500, "say reaches 500 in the open", true )
	heard( "say", 520, "but not 520", false )
	heard( "yell", 1000, "yell reaches 1000 in the open", true )
	heard( "yell", 1040, "but not 1040", false )
	heard( "whisper", 120, "whisper reaches 120 in the open", true )
	heard( "whisper", 140, "but not 140", false )

	-- Behind a wall the muffled range applies: say 256, yell 768, whisper not at all.
	local wall = ents.Create( "prop_physics" )
	wall:SetModel( "models/hunter/plates/plate4x4.mdl" )
	wall:SetPos( base + Vector( 60, 0, 40 ) )
	wall:SetAngles( Angle( 90, 0, 0 ) )
	wall:Spawn()
	local phys = wall:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
	T.Wait( 0.1 )
	a:SetPos( base ) b:SetPos( base + Vector( 200, 0, 0 ) )
	T.Check( not Chat.CanHear( a, b ), "the wall blocks sight" )
	heard( "say", 200, "say behind a wall reaches 200 (muffled 256)", true )
	heard( "say", 300, "say behind a wall misses 300 (muffled 256)", false )
	heard( "yell", 700, "yell behind a wall reaches 700 (muffled 768)", true )
	heard( "yell", 800, "yell behind a wall misses 800", false )
	heard( "whisper", 100, "a whisper doesn't pass a wall", false )
	heard( "me", 300, "/me behind a wall is muffled too", false )
	wall:Remove()
	T.Wait( 0.1 )
	heard( "say", 300, "without the wall 300 hears say again", true )

	-- Formats and colours, word for word.
	local function line( kind, name, text, ch ) return Chat.Plain( Chat.Format( kind, name, text, ch ) ) end
	T.Equal( line( "say", "Worker", "Hello." ), 'Worker says, "Hello."', "say format" )
	T.Equal( line( "yell", "Worker", "HELLO!" ), 'Worker yells, "HELLO!"', "yell format" )
	T.Equal( line( "whisper", "Worker", "Psst." ), 'Worker whispers, "Psst."', "whisper format" )
	T.Equal( line( "me", "Worker", "waves" ), "Worker waves", "me format" )
	T.Equal( line( "looc", "Worker", "lag" ), "[LOOC] Worker: lag", "LOOC format" )
	T.Equal( line( "ooc", "steamguy", "lag" ), "[OOC] steamguy: lag", "OOC format" )
	T.Equal( line( "radio", "Medic", "Report.", "Radio" ), '[Radio] Medic crackles, "Report."', "radio format" )
	T.Equal( line( "radio", "Medic", "Report.", "" ), 'Medic says over the radio, "Report."', "radio bystander format" )
	T.Equal( line( "admin", "steamguy", "help" ), "[NECROMANCER] steamguy: help", "staff channel format" )
	T.Equal( line( "pm_from", "steamguy", "hi" ), "[OOC PM from steamguy]: hi", "PM received format" )
	T.Equal( line( "pm_to", "steamguy", "hi" ), "[OOC PM to steamguy]: hi", "PM sent format" )
	local say = Chat.Format( "say", "x", "y" )[ 1 ]
	T.Equal( string.format( "%d,%d,%d", say.r, say.g, say.b ), "180,150,0", "say is gold" )
	local me = Chat.Format( "me", "x", "y" )[ 1 ]
	T.Equal( string.format( "%d,%d,%d", me.r, me.g, me.b ), "132,198,118", "/me is green" )
	T.Equal( Chat.Mode( "yell" ).font, "ChatBig", "yell is big" )
	T.Equal( Chat.Mode( "whisper" ).font, "ChatSmall", "whisper is small" )
	T.Equal( Chat.Mode( "radio" ).font, "ChatRadio", "radio has its own font" )

	-- What gets sent, and to whom.
	local got, told = nil, {}
	hook.Add( "GR_Chat", "t16e", function( speaker, mode, text, to ) got = { mode = mode.id, text = text, to = names( to ) } end )
	hook.Add( "GR_ChatTell", "t16e", function( ply, col, text, fx )
		table.insert( told, { who = ply.T16, text = text, fx = fx, col = string.format( "%d,%d,%d", col.r, col.g, col.b ) } )
	end )
	local function toldTo( who )
		local out = {}
		for _, t in ipairs( told ) do if t.who == who then table.insert( out, t.text ) end end
		return table.concat( out, " | " )
	end
	local function say( ply, text )
		got, told = nil, {}
		T.Equal( hook.Run( "PlayerSay", ply, text, false ), "", "PlayerSay swallows: " .. text )
	end

	a:SetPos( base ) b:SetPos( base + Vector( 100, 0, 0 ) )
	say( a, "/y help me" )
	T.Check( got and got.mode == "yell" and got.text == "HELP ME!", "a yell is upper case with a bang" )
	say( a, "/y what?" )
	T.Equal( got and got.text, "WHAT?!", "a yelled question gets ?!" )
	say( a, "/me scratches his head" )
	T.Equal( got and got.text, "scratches his head", "/me is as typed" )
	say( a, ".//are you lagging" )
	T.Check( got and got.mode == "looc" and got.to == "a,b", "LOOC reaches the one nearby" )
	say( a, "/a someone is stuck" )
	T.Check( got and got.mode == "admin" and got.to == "a,staff", "/a reaches the speaker and staff only" )

	-- OOC: a cooldown, and a switch that turns it off.
	local oldDelay = Config.OOCDelay
	Config.OOCDelay = 30
	a.GR_LastOOC = nil
	say( a, "// first" )
	T.Check( got and got.mode == "ooc", "OOC goes through" )
	say( a, "// second" )
	T.Check( got == nil and string.find( toldTo( "a" ), "^Wait %d+ seconds to talk in OOC%.$" ) ~= nil, "a second OOC within the delay is refused" )
	T.Equal( told[ 1 ] and told[ 1 ].fx, 1, "with a fright" )
	Config.OOCDelay = Config.ChatOOCOff
	say( b, "// anyone?" )
	T.Equal( toldTo( "b" ), "OOC has been disabled.\nConsider using our discord or LOOC with .// instead.", "OOC can be turned off" )
	say( staff, "// staff may still" )
	T.Check( got and got.mode == "ooc", "staff ignore the switch" )
	Config.OOCDelay = oldDelay

	-- PM: target and sender, and staff see a copy.
	say( a, "/pm t16e_b meet me at the press" )
	T.Check( got and got.mode == "pm" and got.text == "meet me at the press" and got.to == "a,b", "a PM reaches the target" )
	T.Equal( toldTo( "staff" ), "[PM] (t16e_a to t16e_b): meet me at the press", "staff see the PM" )
	say( a, "/pm nobodyatall hi" )
	T.Equal( toldTo( "a" ), "Nobody could be found named 'nobodyatall'.", "an unknown PM target" )

	-- Radio: the channel hears the crackle, bystanders hear the speaker's side.
	m:SetPos( base + Vector( 0, 150, 0 ) )
	local channel = Chat.Recipients( m, "radio" )
	T.Equal( names( channel ), "m", "the medic channel" )
	T.Equal( names( Chat.Bystanders( m, channel ) ), "a,b", "the proles beside the korpsman hear him use the radio" )
	say( a, "/r hello" )
	T.Equal( toldTo( "a" ), "You need a radio for this.", "no radio" )
	Corpse.SetInjured( m, true )
	say( m, "/r help" )
	T.Equal( toldTo( "m" ), "Your feeble voice isn't picked up by the radio.", "an injured voice doesn't carry" )
	Corpse.SetInjured( m, false )
	hook.Add( "GR_RadioJammed", "t16e", function() return true end )
	say( m, "/r help" )
	T.Equal( toldTo( "m" ), "Your radio refuses to work.", "a jammed radio" )
	hook.Remove( "GR_RadioJammed", "t16e" )
	park()

	-- AutoGrammar on sample lines.
	local samples = {
		{ "i dont know u", "I don't know you." },
		{ "liver failure forever", "Gangrene Eternal." },
		{ "lol ok", "Heh okay." },
		{ "where r u?", "Where are u?" },
		{ "hello, how are you", "Hello, how are you." },
		{ "wait!", "Wait!" },
		{ "idk, ask the kommandant", "Idk, ask the Kaiser." }, -- a first word before a comma stays, as in the original
		{ "we need money", "We need bone." },
	}
	for _, pair in ipairs( samples ) do
		T.Equal( Chat.AutoGrammar( pair[ 1 ] ), pair[ 2 ], "AutoGrammar: " .. pair[ 1 ] )
	end
	T.Equal( Chat.AutoGrammar( "Hello there", true ), "hello there.", "AutoGrammar lower" )

	-- Thoughtcrime: not sent, a scare and the word in red, 60 s wanted, and staff told.
	Crime.ClearWanted( a )
	say( a, "you are a chungus" )
	T.Check( got == nil, "the banned line is not sent" )
	T.Equal( toldTo( "a" ), "'chungus'", "the speaker sees the word echoed" )
	T.Check( told[ 1 ] and told[ 1 ].fx == 2 and told[ 1 ].col == "200,0,0", "in red, with a jumpscare" )
	T.Equal( toldTo( "staff" ), a:Nick() .. " (t16e_a) wanted to say 'chungus'.", "staff are told" )
	T.Equal( a:GetWanted(), WANTED_TORMENT, "the speaker is wanted" )
	T.Equal( a:GetWantedReason(), "thoughtcrime", "for thoughtcrime" )
	T.Check( math.abs( Crime.WantedLeft( a ) - 60 ) < 1, "for 60 seconds" )
	Crime.ClearWanted( a )
	say( a, "b 4 s 3 d" )
	T.Equal( toldTo( "a" ), "'based'", "circumvented banned sentences are caught" )
	Crime.ClearWanted( a )
	say( a, "it is based on facts" )
	T.Check( got ~= nil and not a:IsWanted(), "a banned sentence inside a longer line is fine" )
	say( staff, "the admin is here" )
	T.Check( got ~= nil and not staff:IsWanted(), "staff are exempt" )
	say( g, "pog" )
	T.Equal( toldTo( "g" ), "'pog'", "a ghost is scared too" )
	T.Check( not g:IsWanted() and toldTo( "staff" ) == "", "but a ghost isn't wanted and staff aren't told" )
	T.Check( Config.ChatBadWords ~= nil and Config.ChatBadSentences ~= nil, "the lists live in Config" )

	-- The dead and the downed.
	say( g, "/y boo" )
	T.Equal( toldTo( "g" ), "The dead must speak quietly and politely.", "ghosts can't yell" )
	Consciousness.PassOut( a )
	say( a, "hello" )
	T.Equal( toldTo( "a" ), "You're unconscious. You can't talk.", "the unconscious can't talk" )
	say( a, "/me twitches" )
	T.Check( got and got.mode == "me", "but can still /me" )
	Consciousness.WakeUp( a )

	b:Kill()
	T.Check( Chat.IsDowned( b ), "b is downed" )
	a:SetPos( Corpse.Of( b ):WorldSpaceCenter() + Vector( 100, 0, 0 ) )
	say( b, "help me" )
	T.Check( got and got.mode == "whisper" and got.text == "Help me." and got.to == "a,b", "a downed player's say is a whisper the living nearby hear" )
	say( b, "/y HELP" )
	T.Equal( got and got.mode, "whisper", "and so is a yell" )
	say( b, "/me bleeds" )
	T.Equal( toldTo( "b" ), "You can't do this while dead.", "no /me on the ground" )
	say( b, "mother of death, i call on thee" )
	T.Check( got and got.mode == "whisper" and Chat.IsDowned( b ), "the kill sentence is case-sensitive" )
	say( b, "MOTHER OF DEATH,I CALL ON THEE" )
	T.Equal( toldTo( "b" ), "SO BE IT", "the kill sentence is answered" )
	T.Check( got == nil and not Chat.IsDowned( b ) and Chat.IsDead( b ), "and the body is finished" )
	say( b, "hello" )
	T.Equal( toldTo( "b" ), "Your tongue has all but rotted away.", "the dead body can't say" )
	say( b, "/y hello" )
	T.Equal( toldTo( "b" ), "The dead must speak quietly and politely.", "nor yell" )
	say( b, "/w hello" )
	T.Equal( toldTo( "b" ), "Noone will hear your whimpers anymore.", "nor whisper" )
	say( b, "/r hello" )
	T.Equal( toldTo( "b" ), "You need a radio for this.", "a dead prole still has no radio" )
	T.WaitUntil( function() return b:IsGhost() end, 6, "b comes back as a ghost" )

	s:SetPos( base + Vector( 500, 500, 0 ) )
	s:Kill()
	say( s, "I GIVE MY SOUL ETERNALLY" )
	T.Check( not Chat.IsDowned( s ) and Chat.IsDead( s ), "the other kill sentence works too" )
	T.WaitUntil( function() return s:IsGhost() end, 6, "s comes back as a ghost" )

	-- Babble: each fate's ChatSounds (data), at the mode's level.
	local function babble( ply ) return table.concat( Chat.Babble( ply, 75 ), "," ) end
	T.Check( string.match( babble( m ), "^placenta/speech/korps%d%.wav$" ) ~= nil, "the korpsman babbles korps*.wav" )
	T.Check( string.match( babble( sl ), "^npc/headcrab_poison/ph_talk%d%.wav$" ) ~= nil, "the slave chatters like a poison headcrab, not like its prole base" )
	a:SetHealth( 100 )
	T.Check( string.match( babble( a ), "^placenta/speech/prole%d%.wav$" ) ~= nil, "a healthy prole babbles prole*.wav" )
	a:SetHealth( 30 )
	T.Check( string.match( babble( a ), "^npc/zombie/zombie_voice_idle%d+%.wav" ) ~= nil, "a hurt prole groans" )
	a:SetHealth( 100 )
	T.Check( string.match( babble( g ), "^placenta/ghost%d%.ogg$" ) ~= nil, "a ghost wails" )
	T.Check( isfunction( Fates.Get( "sanitar" ).ChatSounds ), "the sanitar's babble is a function" )
	T.Check( istable( Fates.Get( "kaiser" ).ChatSounds ), "the kaiser's is a list" )

	-- Voice chat is off on a dedicated server.
	T.Check( game.IsDedicated(), "the test server is dedicated" )
	T.Equal( hook.Run( "PlayerCanHearPlayersVoice", a, staff ), false, "nobody hears voice chat" )

	hook.Remove( "GR_Chat", "t16e" )
	hook.Remove( "GR_ChatTell", "t16e" )
	Admin.IsStaff = realStaff
end
