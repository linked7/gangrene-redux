-- Step 16b: rp_slumtown's shipped layout, checked on gm_construct (the test server has no
-- rp_slumtown). The file loads with nothing skipped; the purposes, the lunch machine, capsule points and pumps match the
-- conversion from the original map file; every fate id is a real, takeable fate; only two pumps
-- are enabled and the rest are candidates that never spawn; the slave purpose, stockpile, sanitation
-- station and barrels placed on the real map make it complete; nothing is topped up from the default
-- set. Then the `drop` and `candidate` flags on a
-- fake map's json: a dropped entry lands on the floor, a candidate stays out and survives a save.
return function( T )
	local SLUM = "rp_slumtown"
	local FAKE = "t16b_nomap"
	local function wipe() file.Delete( Layout.DataPath( FAKE ) ) end
	wipe()

	local function living()
		local out = {}
		for e in pairs( Layout.present ) do
			if IsValid( e ) then table.insert( out, e ) end
		end
		return out
	end

	-- The file itself -------------------------------------------------------------------------------

	T.Check( not file.Exists( Layout.DataPath( SLUM ), "DATA" ), "no server json for rp_slumtown shadows the shipped file" )
	local raw = include( GAMEMODE.FolderName .. "/gamemode/layouts/" .. SLUM .. ".lua" )
	T.Check( istable( raw ), "the shipped file returns a list" )
	local entries, source = Layout.Load( SLUM )
	T.Check( entries ~= nil and string.find( source or "", "layouts/rp_slumtown.lua", 1, true ) ~= nil, "Layout.Load reads the shipped file" )
	entries = entries or {}
	T.Equal( #entries, #raw, "no entry is skipped as invalid" )
	T.Equal( #entries, 112, "8 purposes (no sanitar: recruited), trash piles, the machine, its boiler and 4 barrels, 12 capsule points, 4 pump spots, stockpile, sanitation, corpse washer, summoner and rocketturret spots" )

	local classes, fates = {}, {}
	local enabledPumps, candidates, allDrop, validFates = 0, 0, true, true
	for _, e in ipairs( entries ) do
		classes[ e.class ] = ( classes[ e.class ] or 0 ) + 1
		if e.class == "fate_station" then
			local f = Fates.Get( e.kv.fate )
			if not f or f.index == FATE_GHOST then validFates = false T.Note( "bad fate %s", tostring( e.kv.fate ) ) end
			fates[ e.kv.fate ] = ( fates[ e.kv.fate ] or 0 ) + 1
		end

		if e.candidate then
			candidates = candidates + 1
			if e.class ~= "water_pump" then T.Note( "%s is a candidate", e.class ) end
		elseif e.class == "water_pump" then
			enabledPumps = enabledPumps + 1
		end
		if not e.drop and e.class ~= "capsule_spawn" and e.class ~= "autostitcher" and e.class ~= "konsole_immigration" and e.class ~= "summoner" then allDrop = false end
		if e.drop and e.class == "capsule_spawn" then allDrop = false end
	end
	T.Equal( classes.fate_station, 8, "7 old purposes (sanitar ones removed, commented-out proles stay out) and the slave's" )
	T.Check( validFates, "every purpose names a takeable fate" )
	T.Equal( fates.kaiser, 1, "kommandant -> one kaiser purpose" )
	T.Equal( fates.sanitar, nil, "no sanitar purposes: sanitars are recruited" )
	T.Equal( fates.korpsman, 1, "korpsman -> one korpsman purpose" )
	T.Equal( fates.prole, 5, "proletariat -> five prole purposes" )
	T.Equal( fates.slave, 1, "one slave purpose, placed on the real map" )
	T.Equal( classes.ration_press, nil, "no ration_press is left" )
	T.Equal( classes.lunch_machine, 1, "machine_lunch -> one lunch machine" )
	T.Equal( classes.line_boiler, 1, "and its boiler" )
	T.Equal( classes.corpse_washer, 1, "and the corpse washer" )
	T.Equal( classes.capsule_spawn, 12, "GM.Capsules -> 12 capsule points" )
	T.Equal( classes.water_barrel, 4, "four water barrels in the lunch hall" )
	local machinePos, boilerPos
	for _, e in ipairs( entries ) do
		if e.class == "lunch_machine" then machinePos = e.pos end
		if e.class == "line_boiler" then boilerPos = e.pos end
	end
	T.Check( machinePos and boilerPos and machinePos:Distance( boilerPos ) < Lunch.RANGE, "the boiler is in reach of the machine" )
	T.Equal( classes.water_pump, 4, "faucet -> four pump spots (the commented-out one stays out)" )
	T.Equal( enabledPumps, 2, "two pumps enabled (step 8: one or two per map)" )
	T.Equal( candidates, 2, "the other two are candidates, and only pumps are" )
	T.Equal( classes.state_stockpile, 1, "one stockpile" )
	T.Equal( classes.sanitation_station, 1, "one sanitation station" )
	T.Check( allDrop, "every converted model drops to the floor; capsule points and wall-mounted summoners stay where they were" )
	T.Equal( entries[ 1 ].ang, Angle( 0, -178, 0 ), "angles are kept from the original" )
	T.Equal( entries[ 1 ].pos, Vector( 1157, -427, 401 ), "and so are positions" )

	local missing = Layout.WarnMissing( entries, SLUM )
	table.sort( missing )
	T.Equal( table.concat( missing, "," ), "", "nothing is missing" )

	-- Spawning it: no fallback stockpile, candidates stay out --------------------------------------

	Layout.Clear()
	T.Wait( 0.1 )
	T.Equal( #living(), 0, "gm_construct's layout is cleared" )
	local n = Layout.Spawn( SLUM )
	T.Equal( n, 110, "every entry but the two candidates spawns" )
	local stockpiles, spare = 0, 0
	for _, ent in ipairs( living() ) do
		if ent:GetClass() == "state_stockpile" then stockpiles = stockpiles + 1 end
	end
	for _, e in ipairs( Layout.Entries() ) do
		if e.candidate and IsValid( Layout.Spawned( e ) ) then spare = spare + 1 end
	end
	T.Equal( stockpiles, 1, "only the shipped stockpile, no fallback on top of it" )
	T.Equal( spare, 0, "no candidate spawned" )
	T.Equal( #living(), 110, "nothing else in the world" )
	T.Equal( Layout.Spawn( SLUM ), 0, "a second spawn adds nothing" )

	-- The flags on a fake map's json ---------------------------------------------------------------

	Layout.Clear()
	T.Wait( 0.1 )
	local first
	for _, e in ents.Iterator() do
		if e:GetClass() == "info_player_start" then first = e:GetPos() break end
	end
	local floor = Layout.Floor( first + Vector( 200, 0, 0 ) )
	T.Check( floor ~= nil, "a floor beside the spawn" )
	floor = floor or first
	file.CreateDir( "gangrene/layouts" )
	file.Write( Layout.DataPath( FAKE ), util.TableToJSON( {
		{ class = "water_pump", pos = { floor.x, floor.y, floor.z + 30 }, ang = { 0, 90, 0 }, kv = {}, drop = true },
		{ class = "water_pump", pos = { floor.x + 150, floor.y, floor.z + 30 }, ang = { 0, 0, 0 }, kv = {}, drop = true, candidate = true },
	} ) )
	T.Equal( Layout.Spawn( FAKE ), 1, "the candidate isn't spawned" )
	local list = Layout.Entries()
	local pump = Layout.Spawned( list[ 1 ] )
	T.Check( IsValid( pump ), "the dropped pump stands" )
	if IsValid( pump ) then
		local base = pump:GetPos() + Vector( 0, 0, pump:OBBMins().z )
		T.Check( math.abs( base.z - floor.z ) < 2, "on the floor, not 30 units above it" )
		T.Check( math.abs( math.NormalizeAngle( pump:GetAngles().y - 90 ) ) < 0.5, "facing as given" )
	end
	T.Equal( list[ 1 ].drop, nil, "drop is spent once it has landed" )
	T.Check( list[ 2 ].candidate and list[ 2 ].drop, "the candidate keeps both flags" )

	local realStaff = Admin.IsStaff
	Admin.IsStaff = function( p ) return not IsValid( p ) end
	local ok, lines = Layout.List( nil )
	T.Check( ok and string.find( lines[ 2 ] or "", "candidate", 1, true ) ~= nil, "gr_layout_list marks the candidate" )
	T.Check( Layout.Save( nil ), "the console saves" )
	Admin.IsStaff = realStaff
	local back = util.JSONToTable( file.Read( Layout.DataPath( FAKE ), "DATA" ) or "" ) or {}
	T.Check( back[ 2 ] and back[ 2 ].candidate == true and back[ 2 ].drop == true, "the save keeps the candidate's flags" )
	T.Check( back[ 1 ] and not back[ 1 ].drop and math.abs( back[ 1 ].pos[ 3 ] - floor.z ) < 64, "and the landed pump's floor position" )

	-- Back to the real map ------------------------------------------------------------------------

	wipe()
	Layout.Clear()
	T.Wait( 0.1 )
	Layout.Spawn()
	T.Equal( #Layout.Entries(), 19, "gm_construct's layout is back" )
end
