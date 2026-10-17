-- Step 12: chat ranges from the one table, radio by fate channel, and ghosts kept to themselves.
-- The parity details (muffling, commands, thoughtcrime, the downed) are in sv_step16e.lua.
return function( T )
	local oldOOC = Config.OOCDelay
	Config.OOCDelay = 0 -- OOC is off by default; these checks are about who hears it
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t12_%'" )

	local function bot( name, fate, rank )
		local b = player.CreateNextBot( "t12_" .. name )
		b.T12 = name
		if fate then
			b:SetRank( rank or RANK_FRIEND ) b:SetStemCells( 10 )
			T.Check( Fates.Take( b, fate ), name .. " takes " .. fate )
		end
		return b
	end

	-- Recipient lists as a sorted string of test names, so a check reads like the expected cast.
	local function names( list )
		if not list then return "nil" end
		local out = {}
		for _, p in ipairs( list ) do table.insert( out, p.T12 or p:SteamName() ) end
		table.sort( out )
		return table.concat( out, "," )
	end
	local function hears( speaker, mode, want, msg )
		T.Equal( names( Chat.Recipients( speaker, mode ) ), want, msg )
	end

	local k = bot( "k", "kaiser", RANK_KAISER )
	local s = bot( "s", "sanitar" )
	local d = bot( "d", "sanitar" )
	local m = bot( "m", "korpsman" )
	local p = bot( "p", "prole" )
	local g1 = bot( "g1" )
	local g2 = bot( "g2" )
	T.Wait( 0.2 )
	T.Check( g1:IsGhost() and g2:IsGhost(), "fresh bots are ghosts" )

	-- Everyone around the kaiser, each on their own bearing so nobody stands in another's line
	-- of sight (an unseen listener only hears within the muffled range).
	local base = Vector( -2000, -2000, 200 )
	local at = { k = { 0, 0 }, m = { 50, 0 }, g1 = { 80, 60 }, p = { 350, 120 }, s = { 700, 180 }, d = { 3000, 240 }, g2 = { 5000, 300 } }
	local function spot( name )
		local r, a = at[ name ][ 1 ], math.rad( at[ name ][ 2 ] )
		return base + Vector( r * math.cos( a ), r * math.sin( a ), 0 )
	end
	local function place()
		for _, b in ipairs( { k, s, d, m, p, g1, g2 } ) do
			b:SetPos( spot( b.T12 ) )
			b:SetVelocity( -b:GetVelocity() )
		end
	end

	-- Ranges.
	place()
	T.Check( Chat.CanHear( k, p ), "the kaiser can see the prole (open ground)" )
	hears( k, "whisper", "g1,k,m", "whisper reaches 128 units" )
	hears( k, "say", "g1,k,m,p", "say reaches 512 units" )
	hears( k, "me", "g1,k,m,p", "/me has say's range" )
	hears( k, "looc", "g1,k,m,p", "LOOC has say's range" )
	hears( k, "yell", "g1,k,m,p,s", "yell carries to 1024" )
	hears( k, "ooc", "d,g1,g2,k,m,p,s", "OOC from the living reaches everyone" )
	T.Equal( Chat.Mode( "say" ).range, 512, "say range comes from Chat.Modes" )
	T.Equal( Chat.Mode( "say" ).muffled, 256, "say muffled range" )
	T.Equal( Chat.Mode( "yell" ).range .. "/" .. Chat.Mode( "yell" ).muffled, "1024/768", "yell ranges" )
	T.Equal( Chat.Mode( "whisper" ).range .. "/" .. Chat.Mode( "whisper" ).muffled, "128/0", "whisper ranges" )

	-- Radio: shared channels only, at any distance.
	hears( k, "radio", "d,k,s", "state radio reaches the sanitars, not medics, proles or ghosts" )
	hears( d, "radio", "d,k,s", "a far sanitar reaches the kaiser" )
	hears( m, "radio", "m", "the medic channel has only the korpsman" )
	local none, why = Chat.Recipients( p, "radio" )
	T.Check( none == nil and why == "You need a radio for this.", "a prole has no radio" )

	-- Ghosts talk only to ghosts.
	hears( g1, "say", "g1", "a ghost's say reaches no living player, even close by" )
	g2:SetPos( spot( "g1" ) + ( spot( "g1" ) - base ):GetNormalized() * 60 )
	hears( g1, "say", "g1,g2", "nearby ghosts hear each other" )
	place()
	hears( g1, "ooc", "g1,g2", "ghost OOC stays among ghosts" )
	hears( g1, "radio", "g1,g2", "ghost radio reaches every ghost" )
	hears( g1, "yell", "g1", "a far ghost doesn't hear a yell out of range" )

	-- Downed is still in the body: the living hear the whisper, and the radio still crackles in
	-- their ear. Once the body is past saving, the player is dead until they come back as a ghost.
	d:Kill()
	T.Check( not d:Alive() and Chat.IsDowned( d ) and not Chat.IsDead( d ), "the killed sanitar is downed, not dead" )
	hears( k, "radio", "d,k,s", "a downed sanitar still hears the state radio" )
	local rag = Corpse.Of( d )
	k:SetPos( rag:WorldSpaceCenter() + Vector( 100, 0, 0 ) ) -- the body lies where it fell, far from everyone else
	T.Equal( names( Chat.Recipients( d, "whisper" ) ), "d,k", "a downed whisper reaches the living by the body" )
	Corpse.Die( rag, "test" ) -- skip the bleed-out (step 7)
	T.Check( Chat.IsDead( d ) and not d:IsGhost(), "past saving: dead, not yet a ghost" )
	hears( k, "radio", "k,s", "the dead are off the state radio" )
	T.WaitUntil( function() return d:Alive() and d:IsGhost() end, 6, "respawned as a ghost" )
	place()
	hears( g1, "radio", "d,g1,g2", "the new ghost joins the ghost channel" )

	-- Parsing.
	local function parsed( text ) local mode, body = Chat.Parse( text ) return mode.id .. "|" .. body end
	T.Equal( parsed( "hello there" ), "say|hello there", "plain text is say" )
	T.Equal( parsed( "/r report in" ), "radio|report in", "/r is radio" )
	T.Equal( parsed( "/radio report in" ), "radio|report in", "/radio is radio" )
	T.Equal( parsed( "/rant" ), "say|/rant", "a prefix needs a word boundary" )
	T.Equal( parsed( "/W psst" ), "whisper|psst", "prefixes ignore case" )
	T.Equal( parsed( "/y HEY" ), "yell|HEY", "/y is yell" )
	T.Equal( parsed( "/me waves" ), "me|waves", "/me is an emote" )
	T.Equal( parsed( "//lag?" ), "ooc|lag?", "// needs no space" )
	T.Equal( parsed( "/ooc lag?" ), "ooc|lag?", "/ooc is OOC" )
	T.Equal( parsed( ".//lag?" ), "looc|lag?", ".// is LOOC, not OOC" )
	T.Equal( parsed( "[[lag?" ), "looc|lag?", "[[ is LOOC" )
	T.Equal( parsed( "/looc lag?" ), "looc|lag?", "/looc is LOOC" )
	T.Equal( parsed( "/a help" ), "admin|help", "/a is the staff channel" )
	T.Equal( parsed( "/pm t12_k hi" ), "pm|t12_k hi", "/pm is a private message" )
	T.Equal( parsed( "/roll" ), "roll|", "/roll is not /r" )

	-- The PlayerSay route sends through Chat.Handle and suppresses GMod's broadcast.
	local got
	hook.Add( "GR_Chat", "t12", function( speaker, mode, text, to ) got = { mode = mode.id, text = text, to = names( to ) } end )
	T.Equal( hook.Run( "PlayerSay", k, "/r all units", false ), "", "PlayerSay suppresses the default chat" )
	T.Check( got and got.mode == "radio" and got.text == "All units." and got.to == "k,s",
		"PlayerSay radio goes to the state channel, grammar fixed" )
	got = nil
	hook.Run( "PlayerSay", m, "anyone there", true )
	T.Check( got and got.mode == "radio" and got.to == "m", "team chat is radio" )
	got = nil
	T.Equal( hook.Run( "PlayerSay", p, "/r hello?", false ), "", "a prole's radio attempt is swallowed" )
	T.Check( got == nil, "and sends nothing" )
	hook.Run( "PlayerSay", p, "/y   ", false )
	T.Check( got == nil, "an empty message sends nothing" )

	-- Races never change speech: only AutoGrammar touches spoken lines, and /me and OOC are as typed.
	T.Check( Races.Get( "gangral" ).ModifySpeech == nil, "races have no speech hook" )
	Chat.Send( k, "say", "quiet please" )
	T.Equal( got and got.text, "Quiet please.", "say passes through AutoGrammar only" )
	Chat.Send( k, "me", "nods" )
	T.Equal( got and got.text, "nods", "/me is not spoken, so it is as typed" )
	Chat.Send( k, "ooc", "brb" )
	T.Equal( got and got.text, "brb", "OOC is as typed" )
	hook.Remove( "GR_Chat", "t12" )
	Config.OOCDelay = oldOOC
end
