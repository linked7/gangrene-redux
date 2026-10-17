-- Step 12: chat ranges from the one table, radio by fate channel, and ghosts kept to themselves.
return function( T )
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

	-- Everyone on one line from the kaiser, so the distance is the x offset.
	local base = Vector( -2000, -2000, 200 )
	local function place()
		local at = { k = 0, m = 50, g1 = 80, p = 350, s = 700, d = 3000, g2 = 5000 }
		for _, b in ipairs( { k, s, d, m, p, g1, g2 } ) do b:SetPos( base + Vector( at[ b.T12 ], 0, 0 ) ) end
	end

	-- Ranges.
	place()
	hears( k, "whisper", "g1,k,m", "whisper reaches only the closest" )
	hears( k, "say", "g1,k,m,p", "say reaches 400 units" )
	hears( k, "me", "g1,k,m,p", "/me has say's range" )
	hears( k, "yell", "g1,k,m,p,s", "yell carries further" )
	hears( k, "ooc", "d,g1,g2,k,m,p,s", "OOC from the living reaches everyone" )
	T.Equal( Chat.Mode( "say" ).range, 400, "ranges come from Chat.Modes" )

	-- Radio: shared channels only, at any distance.
	hears( k, "radio", "d,k,s", "state radio reaches the sanitars, not medics, proles or ghosts" )
	hears( d, "radio", "d,k,s", "a far sanitar reaches the kaiser" )
	hears( m, "radio", "m", "the medic channel has only the korpsman" )
	local none, why = Chat.Recipients( p, "radio" )
	T.Check( none == nil and why ~= nil, "a prole has no radio" )

	-- Ghosts talk only to ghosts.
	hears( g1, "say", "g1", "a ghost's say reaches no living player, even close by" )
	g2:SetPos( base + Vector( 100, 0, 0 ) )
	hears( g1, "say", "g1,g2", "nearby ghosts hear each other" )
	place()
	hears( g1, "ooc", "g1,g2", "ghost OOC stays among ghosts" )
	hears( g1, "radio", "g1,g2", "ghost radio reaches every ghost" )
	hears( g1, "yell", "g1", "a far ghost doesn't hear a yell out of range" )

	-- A body waiting to respawn counts as dead: it hears no radio and the living don't hear it.
	d:Kill()
	T.Check( not d:Alive() and not d:IsGhost(), "the killed sanitar is waiting to respawn" )
	hears( k, "radio", "k,s", "a dead sanitar is off the state radio" )
	d:SetPos( base + Vector( 20, 0, 0 ) )
	hears( d, "say", "d,g1", "the dead body's words reach only the dead" )
	Corpse.Die( Corpse.Of( d ), "test" ) -- skip the bleed-out (step 7)
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

	-- The PlayerSay route sends through Chat.Send and suppresses GMod's broadcast.
	local got
	hook.Add( "GR_Chat", "t12", function( speaker, mode, text, to ) got = { mode = mode.id, text = text, to = names( to ) } end )
	T.Equal( hook.Run( "PlayerSay", k, "/r all units", false ), "", "PlayerSay suppresses the default chat" )
	T.Check( got and got.mode == "radio" and got.text == "all units" and got.to == "k,s",
		"PlayerSay radio goes to the state channel" )
	got = nil
	hook.Run( "PlayerSay", m, "anyone there", true )
	T.Check( got and got.mode == "radio" and got.to == "m", "team chat is radio" )
	got = nil
	T.Equal( hook.Run( "PlayerSay", p, "/r hello?", false ), "", "a prole's radio attempt is swallowed" )
	T.Check( got == nil, "and sends nothing" )
	hook.Run( "PlayerSay", p, "/y   ", false )
	T.Check( got == nil, "an empty message sends nothing" )

	-- The speech-mangling hook point: spoken modes only.
	local race = Races.Get( "gangral" )
	race.ModifySpeech = function( _, text ) return string.upper( text ) end
	Chat.Send( k, "say", "quiet please" )
	T.Equal( got and got.text, "QUIET PLEASE", "say passes through the race's ModifySpeech" )
	Chat.Send( k, "me", "nods" )
	T.Equal( got and got.text, "nods", "/me is not spoken, so it isn't mangled" )
	Chat.Send( k, "ooc", "brb" )
	T.Equal( got and got.text, "brb", "OOC is never mangled" )
	race.ModifySpeech = nil
	hook.Remove( "GR_Chat", "t12" )
end
