-- Step 15a: the map layout. gm_construct's shipped layout spawns once at Round.Start and a second
-- Round.Start doesn't double it; the economy and the purposes work on what it spawned; a map with no
-- layout gets the default set in a ring around the spawn; the staff editor adds, removes and saves,
-- and the saved json wins on the next load; non-staff are refused.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t15a_%'" )
	local FAKE = "t15a_nomap"
	local function wipe() file.Delete( Layout.DataPath( FAKE ) ) end
	wipe()

	local function count( list )
		local n = {}
		for _, e in ipairs( list ) do n[ e.class ] = ( n[ e.class ] or 0 ) + 1 end
		return n
	end
	local function living()
		local out = {}
		for e in pairs( Layout.present ) do
			if IsValid( e ) then table.insert( out, e ) end
		end
		return out
	end

	-- The shipped gm_construct layout ---------------------------------------------------------------

	local map = game.GetMap()
	T.Equal( Layout.map, map, "the layout for this map is loaded" )
	local entries = Layout.Entries()
	T.Equal( #entries, 23, "gm_construct's layout has every entry" )
	local n = count( entries )
	T.Equal( n.fate_station, #Fates.All() - 2, "one purpose per fate but ghost and sanitar (sanitars are recruited)" )
	T.Equal( n.state_stockpile, 1, "a stockpile" )
	T.Equal( n.lunch_machine, 1, "a lunch machine" )
	T.Equal( n.line_boiler, 1, "its boiler" )
	T.Equal( n.capsule_spawn, 4, "four capsule points" )
	T.Equal( n.water_barrel, 2, "two water barrels" )
	T.Equal( n.water_pump, 2, "two pumps" )
	T.Equal( n.sanitation_station, 1, "a sanitation station" )
	local all = true
	for _, e in ipairs( entries ) do
		local ent = Layout.Spawned( e )
		if not IsValid( ent ) or ent:GetClass() ~= e.class then all = false end
	end
	T.Check( all, "every entry stands in the world" )
	T.Check( not Layout.MapPlaced(), "gm_construct places none itself" )

	local fates, machine = {}, nil
	for _, e in ipairs( entries ) do
		local ent = Layout.Spawned( e )
		if e.class == "fate_station" then fates[ ent:GetFateId() ] = ent end
		if e.class == "lunch_machine" then machine = ent end
	end
	for _, f in ipairs( Fates.All() ) do
		if f.index ~= FATE_GHOST and f.id ~= "sanitar" then T.Check( IsValid( fates[ f.id ] ), "a purpose for " .. f.id ) end
	end
	T.Check( IsValid( machine ) and Lunch.BoilerOf( machine ) ~= nil, "the lunch machine has its boiler in reach" )

	-- On the floor: a short trace down from each base hits the world.
	local grounded = true
	for _, e in ipairs( entries ) do
		local ent = Layout.Spawned( e )
		local base = ent:GetPos() + Vector( 0, 0, ent:OBBMins().z )
		local tr = util.TraceLine( { start = base + Vector( 0, 0, 8 ), endpos = base - Vector( 0, 0, 8 ), mask = MASK_SOLID_BRUSHONLY } )
		if not tr.Hit then grounded = false T.Note( "%s not on the floor at %s", e.class, tostring( ent:GetPos() ) ) end
	end
	T.Check( grounded, "everything stands on the floor" )

	-- Round.Start again: nothing doubles.
	local before = #living()
	local ids = {}
	for _, e in ipairs( entries ) do ids[ e ] = Layout.Spawned( e ) end
	Round.Start()
	T.Equal( #living(), before, "a second Round.Start spawns nothing" )
	local same = true
	for _, e in ipairs( Layout.Entries() ) do
		if Layout.Spawned( e ) ~= ids[ e ] then same = false end
	end
	T.Check( same, "and keeps the same entities" )

	-- A missing one comes back on the next start, alone.
	local gone = entries[ 1 ]
	Layout.Spawned( gone ):Remove()
	T.Wait( 0.1 )
	T.Equal( Layout.Spawn(), 1, "only the removed entry respawns" )
	T.Check( IsValid( Layout.Spawned( gone ) ), "and it stands again" )

	-- The world works: a ghost takes a purpose, the stockpile takes a crate --------------------------

	local g = player.CreateNextBot( "t15a_worker" )
	g:SetRank( RANK_FRIEND )
	g:SetStemCells( 10 )
	T.Wait( 0.3 )
	fates.prole = nil
	for _, e in ipairs( Layout.Entries() ) do
		local ent = Layout.Spawned( e )
		if e.class == "fate_station" and ent:GetFateId() == "prole" then fates.prole = ent end
	end
	T.Check( g:IsGhost(), "the worker starts a ghost" )
	fates.prole:Use( g, g, USE_ON, 1 )
	T.Equal( g:GetFateDef().id, "prole", "using the layout's prole purpose makes a prole" )

	local stockpile
	for _, e in ipairs( Layout.Entries() ) do
		if e.class == "state_stockpile" then stockpile = Layout.Spawned( e ) end
	end
	local stock = Econ.Stock( "ration" )
	local crate = Crates.Spawn( "ration", stockpile:GetPos() + stockpile:GetForward() * 80 + Vector( 0, 0, 40 ), Crates.Crew( { g } ), machine )
	T.Check( Crates.Deliver( g, crate, stockpile ), "a crate delivered to the layout's stockpile pays" )
	T.Equal( Econ.Stock( "ration" ), stock + 1, "and the stock rises" )
	T.Equal( ( Econ.Audit() ), 0, "the economy holds" )

	-- No layout: the default ring around the spawn ------------------------------------------------

	Layout.Clear()
	T.Wait( 0.1 )
	T.Equal( #living(), 0, "Clear removes what Layout spawned" )
	Layout.Spawn( FAKE )
	entries = Layout.Entries()
	local default = Layout.DefaultSet()
	T.Equal( #entries, #default, "a map with no layout gets the whole default set" )
	T.Equal( #living(), #default, "all of it spawned" )
	local spawns, first = {}, nil
	for _, e in ents.Iterator() do
		if e:GetClass() == "info_player_start" then
			first = first or e:GetPos()
			table.insert( spawns, e:GetPos() )
		end
	end
	local near, clear, floored = true, true, true
	for _, e in ipairs( entries ) do
		local ent = Layout.Spawned( e )
		if not IsValid( ent ) or ent:GetPos():Distance( first ) > Layout.RING_RADIUS + 1600 then near = false end
		for _, s in ipairs( spawns ) do
			if IsValid( ent ) and ( ent:GetPos() * Vector( 1, 1, 0 ) ):Distance( s * Vector( 1, 1, 0 ) ) < Layout.RING_GAP - 1 then clear = false end
		end
		local base = ent:GetPos() + Vector( 0, 0, ent:OBBMins().z )
		local tr = util.TraceLine( { start = base + Vector( 0, 0, 8 ), endpos = base - Vector( 0, 0, 8 ), mask = MASK_SOLID_BRUSHONLY } )
		if not tr.Hit then floored = false end
	end
	T.Check( near, "the ring stands around the first spawn" )
	T.Check( clear, "clear of every player spawn" )
	T.Check( floored, "on the floor" )
	T.Equal( count( entries ).lunch_machine, 1, "one lunch machine in the ring" )

	-- Editor ----------------------------------------------------------------------------------------

	local staff = player.CreateNextBot( "t15a_staff" )
	local user = player.CreateNextBot( "t15a_user" )
	T.Wait( 0.3 )
	local realStaff = Admin.IsStaff
	Admin.IsStaff = function( p ) return not IsValid( p ) or p == staff end

	local victim = Layout.Spawned( entries[ 1 ] )
	T.Check( not Layout.Add( user, "water_pump" ), "a non-staff player can't add" )
	T.Check( not Layout.Remove( user, victim ), "or remove" )
	T.Check( not Layout.Save( user ), "or save" )
	T.Check( not Layout.List( user ), "or list" )
	hook.Run( "PlayerSay", user, "!layout_save" )
	T.Check( not file.Exists( Layout.DataPath( FAKE ), "DATA" ), "the chat command refuses them too" )
	T.Equal( #Layout.Entries(), #default, "nothing changed" )

	-- Staff look at the floor in the open and add a pump and a purpose there.
	local spot = Layout.Floor( first + ( Layout.Spawned( entries[ 2 ] ):GetPos() - first ) * Vector( 1, 1, 0 ) * 0.5 )
	staff:SetPos( spot + Vector( 0, 0, 4 ) )
	staff:SetEyeAngles( Angle( 89, 0, 0 ) )
	T.Wait( 0.2 )
	local ok, pump = Layout.Add( staff, "water_pump" )
	T.Check( ok and IsValid( pump ), "staff add a pump where they look" )
	T.Check( IsValid( pump ) and pump:GetPos():Distance( staff:GetEyeTrace().HitPos ) < 80, "at their eye trace" )
	T.Equal( #Layout.Entries(), #default + 1, "it joins the layout" )

	hook.Run( "PlayerSay", staff, "!layout_add fate_station fate=kaiser" )
	local last = Layout.Entries()[ #Layout.Entries() ]
	T.Check( last.class == "fate_station" and last.kv.fate == "kaiser", "the chat command adds a purpose with its key value" )
	T.Equal( IsValid( Layout.Spawned( last ) ) and Layout.Spawned( last ):GetFateId(), "kaiser", "which reads the key value" )

	local size = #Layout.Entries()
	T.Check( not Layout.Add( staff, "fate_station", { "fate=ghost" } ), "no purpose for ghost" )
	T.Check( not Layout.Add( staff, "fate_station" ), "a purpose needs a fate" )
	T.Check( not Layout.Add( staff, "lunch_machine", { "output=gold" } ), "a lunch machine makes a known output" )
	T.Check( not Layout.Add( staff, "prop_physics" ), "only layout classes" )
	T.Check( not Layout.Add( nil, "water_pump" ), "the console has no eye trace" )
	T.Equal( #Layout.Entries(), size, "refusals add nothing" )

	T.Check( Layout.Remove( staff, victim ), "staff remove an entry" )
	T.Wait( 0.1 )
	T.Check( not IsValid( victim ), "it is gone from the world" )
	T.Equal( #Layout.Entries(), size - 1, "and from the layout" )
	local prop = ents.Create( "prop_physics" )
	prop:SetModel( "models/props_junk/wood_crate001a.mdl" )
	prop:SetPos( spot + Vector( 0, 0, 200 ) )
	prop:Spawn()
	T.Check( not Layout.Remove( staff, prop ), "a non-layout entity can't be removed" )
	prop:Remove()

	T.Check( Layout.List( staff ), "staff list it" )
	local saved = {}
	for _, e in ipairs( Layout.Entries() ) do
		table.insert( saved, { class = e.class, pos = e.pos, fate = e.kv.fate, good = e.kv.good } )
	end
	hook.Run( "PlayerSay", staff, "!layout_save" )
	T.Check( file.Exists( Layout.DataPath( FAKE ), "DATA" ), "the save writes data/gangrene/layouts/<map>.json" )
	T.Equal( #( util.JSONToTable( file.Read( Layout.DataPath( FAKE ), "DATA" ) ) or {} ), #saved, "with every entry" )

	-- Reload: the json wins over the ring.
	Layout.Clear()
	T.Wait( 0.1 )
	Layout.Spawn( FAKE )
	local back = Layout.Entries()
	T.Equal( #back, #saved, "the saved layout loads back" )
	local match = #back == #saved
	for i, s in ipairs( saved ) do
		local b = back[ i ]
		if not b or b.class ~= s.class or b.pos:Distance( s.pos ) > 0.2 or b.kv.fate ~= s.fate or b.kv.good ~= s.good then
			match = false
		end
	end
	T.Check( match, "entry for entry: class, place and key values" )
	T.Equal( #living(), #saved, "and all of it spawned" )

	-- Back to the real map ------------------------------------------------------------------------

	Admin.IsStaff = realStaff
	wipe()
	Layout.Clear()
	T.Wait( 0.1 )
	Layout.Spawn()
	T.Equal( #Layout.Entries(), 23, "gm_construct's layout is back" )
	for _, b in ipairs( { g, staff, user } ) do b:Kick( "test" ) end
	T.Wait( 0.3 )
end
