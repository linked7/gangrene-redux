-- Step 16c: the lunch machine (step 11.1), on gm_construct's layout machine and boiler. Bone
-- capsules (spawn, cap, lifetime, what breaks them, the burst into chunks, carrying, thrown damage),
-- water barrels (fill, carry, pour, by touch), feeding the maw (by call and by touch), the boiler's
-- bands (dark, running, overload shocks, the vent and its scald, dry), the valve, the panel (wrong
-- press shocks late, right presses darken, clearing makes a crate stamped with the crew), the lever,
-- the explosion, the 3-crate cap, the crew's delivery split and theft, give bones, building a barrel
-- and its cap, and that ration_press is gone.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t16c_%'" )

	local saved = {}
	for _, k in ipairs( { "DRIFT_MIN", "DRIFT_MAX", "OVERLOAD_CHANCE", "REROLL_CHANCE", "CAPSULE_MAX", "InWater" } ) do saved[ k ] = Lunch[ k ] end
	local barrelCap = Build.KINDS.water_barrel.cap
	Lunch.DRIFT_MIN, Lunch.DRIFT_MAX = 0, 0 -- the pressure only moves when the test moves it
	Lunch.OVERLOAD_CHANCE = 0

	local made, exploded = {}, {}
	hook.Add( "GR_CrateMade", "t16c", function( crate ) table.insert( made, crate ) timer.Simple( 0, function() if IsValid( crate ) then crate:SetLocked( false ) end end ) end )
	local sanitarHook = hook.GetTable().GR_CrateMade and hook.GetTable().GR_CrateMade.gr_sanitar -- sealed crates are sv_sanitarwork's business
	hook.Remove( "GR_CrateMade", "gr_sanitar" )
	hook.Add( "GR_LunchExplode", "t16c", function( m ) table.insert( exploded, m ) end )

	local function bot( name, fate, rank )
		local b = player.CreateNextBot( "t16c_" .. name )
		b:SetRank( rank )
		b:SetStemCells( 10 )
		T.Check( Fates.Take( b, fate ), name .. " takes " .. fate )
		return b
	end
	local function setBones( b, n )
		Econ.Transfer( b, Econ.TREASURY, b:GetBones(), "test" )
		Econ.Transfer( Econ.TREASURY, b, n, "test" )
	end
	local function heal( list ) for _, b in ipairs( list ) do b:SetHealth( b:GetMaxHealth() ) end end

	T.Wait( 0.2 )
	local p1 = bot( "presser", "prole", RANK_FRIEND )
	local p2 = bot( "valve", "prole", RANK_FRIEND )
	local p3 = bot( "other", "slave", RANK_FOOLISH )
	local all = { p1, p2, p3 }
	Econ.ResetRound()

	-- The layout's machine, boiler and stockpile.
	local m, boiler, stockpile
	for _, e in ipairs( Layout.Entries() ) do
		local ent = Layout.Spawned( e )
		if e.class == "lunch_machine" then m = ent end
		if e.class == "line_boiler" then boiler = ent end
		if e.class == "state_stockpile" then stockpile = ent end
	end
	T.Check( IsValid( m ) and IsValid( boiler ) and IsValid( stockpile ), "the layout has a lunch machine, a boiler and a stockpile" )
	T.Equal( Lunch.BoilerOf( m ), boiler, "the machine works with the boiler beside it" )
	T.Equal( Lunch.MachineOf( boiler ), m, "and the boiler knows its machine" )
	Lunch.Reset()

	local function place( b, offset )
		local at = Layout.Floor( m:GetPos() + offset ) or ( m:GetPos() + offset )
		b:SetMoveType( MOVETYPE_NONE )
		b:SetPos( at + Vector( 0, 0, 2 ) )
	end
	local function near() place( p1, Vector( -80, -30, 0 ) ) place( p2, Vector( -80, 30, 0 ) ) place( p3, Vector( -80, 90, 0 ) ) end
	local function far() for i, b in ipairs( all ) do place( b, Vector( -700, -200 + i * 80, 0 ) ) end end
	far()

	local function settle( pressure, water )
		Lunch.SetPressure( boiler, 0 ) -- ends any vent
		Lunch.SetPressure( boiler, pressure or 55 )
		boiler:SetWater( water or Lunch.BOILER_WATER )
	end
	local function fresh()
		m.GR_Crew = {}
		Lunch.Reroll( m )
	end
	local function matching()
		for k = 1, Lunch.BUTTONS do
			if m:GetButton( k ) > 0 and m:GetButton( k ) == m:GetLight() then return k end
		end
	end
	local function wrongButton()
		for k = 1, Lunch.BUTTONS do
			if m:GetButton( k ) > 0 and m:GetButton( k ) ~= m:GetLight() then return k end
		end
	end
	-- Right presses by `who` until the panel is clear. Returns the last press's result.
	local function clear( who )
		local r
		for _ = 1, Lunch.BUTTONS do
			local k = matching()
			if not k then break end
			r = Lunch.Press( who, m, k )
			if r ~= "right" then break end
		end
		return r
	end

	-- Bone capsules --------------------------------------------------------------------------------

	T.Equal( #Lunch.All( "capsule_spawn" ), 4, "four capsule points on gm_construct" )
	local c = Lunch.SpawnCapsule()
	T.Check( IsValid( c ) and c:GetClass() == "bone_capsule", "a capsule spawns" )
	local atPoint = false
	for _, pt in ipairs( Lunch.All( "capsule_spawn" ) ) do
		if c:GetPos():Distance( pt:GetPos() ) < 40 then atPoint = true end
	end
	T.Check( atPoint, "at one of the capsule points" )
	T.Equal( c:GetModel(), "models/gibs/antlion_gib_large_3.mdl", "the antlion gib model" )
	T.Equal( c:GetIntegrity(), Lunch.CAPSULE_INTEGRITY, "full of blood" )
	T.Check( math.abs( c.GR_DieAt - ( CurTime() + Lunch.CAPSULE_LIFE ) ) < 1, "gone in 15 minutes" )
	Lunch.CAPSULE_MAX = #Lunch.All( "bone_capsule" )
	T.Equal( Lunch.SpawnCapsule(), nil, "none past the cap" )
	Lunch.CAPSULE_MAX = saved.CAPSULE_MAX
	T.Equal( Lunch.CAPSULE_MAX, 12, "the cap is 12" )
	T.Check( Lunch.SPAWN_MIN == 15 and Lunch.SPAWN_MAX == 20, "one every 15-20 s" )

	local old = Lunch.SpawnCapsule()
	old.GR_DieAt = CurTime() - 1
	T.WaitUntil( function() return not IsValid( old ) end, 2, "an expired capsule is removed by the slow job" )

	local d = DamageInfo()
	d:SetDamage( 50 ) d:SetDamageType( DMG_BURN ) d:SetAttacker( p1 ) d:SetInflictor( p1 )
	c:TakeDamageInfo( d )
	T.Equal( c:GetIntegrity(), Lunch.CAPSULE_INTEGRITY, "fire doesn't hurt a capsule" )
	d = DamageInfo()
	d:SetDamage( 30 ) d:SetDamageType( DMG_CLUB ) d:SetAttacker( p1 ) d:SetInflictor( p1 )
	c:TakeDamageInfo( d )
	T.Equal( c:GetIntegrity(), Lunch.CAPSULE_INTEGRITY - 30, "a melee hit takes its blood" )
	d = DamageInfo()
	d:SetDamage( 20 ) d:SetDamageType( DMG_BULLET ) d:SetAttacker( p1 ) d:SetInflictor( p1 )
	c:TakeDamageInfo( d )
	T.Equal( c:GetIntegrity(), Lunch.CAPSULE_INTEGRITY - 50, "and so does a bullet" )

	-- Carried whole, like a crate.
	T.Check( Crates.IsHeavy( c ), "a whole capsule is heavy" )
	local walk = p1:GetWalkSpeed()
	Crates.Hold( p1, c )
	T.Equal( p1:GetRunSpeed(), walk, "its carrier can only walk" )
	Crates.Release( p1 )

	-- Thrown: a tenth of the physics damage.
	heal( all )
	d = DamageInfo()
	d:SetDamage( 50 ) d:SetDamageType( DMG_CRUSH ) d:SetAttacker( c ) d:SetInflictor( c )
	p3:TakeDamageInfo( d )
	local lost = p3:GetMaxHealth() - p3:Health()
	T.Check( lost > 0 and lost <= 5, "a thrown capsule hits for a tenth: lost " .. lost )
	heal( all )

	local chunksBefore = #Lunch.All( "meat_chunk" )
	T.Check( Lunch.Hurt( c, 100 ), "out of blood, it bursts" )
	T.Wait( 0.1 )
	T.Check( not IsValid( c ), "the capsule is gone" )
	local chunks = Lunch.All( "meat_chunk" )
	T.Equal( #chunks - chunksBefore, Lunch.CHUNKS, "into two meat chunks" )
	local chunk = chunks[ #chunks ]
	T.Check( chunk.GR_DieAt and math.abs( chunk.GR_DieAt - ( CurTime() + Lunch.CHUNK_LIFE ) ) < 1, "that rot in 2 minutes" )
	T.Check( not Crates.IsHeavy( chunk ), "a chunk is light" )

	-- Feeding the maw ------------------------------------------------------------------------------

	m:SetBiomass( 0 )
	T.Check( Lunch.Feed( m, chunk ), "a chunk goes in" )
	T.Equal( m:GetBiomass(), 1, "for 1 biomass" )
	local whole = Lunch.SpawnCapsule()
	T.Check( Lunch.Feed( m, whole ), "a whole capsule goes in" )
	T.Equal( m:GetBiomass(), 3, "for 2" )
	T.Check( not Lunch.Feed( m, stockpile ), "the stockpile is not food" )

	-- By touch: a chunk held against the machine's side.
	local loose = ents.Create( "meat_chunk" )
	loose:SetPos( m:LocalToWorld( Vector( 0, m:OBBMaxs().y + 6, ( m:OBBMins().z + m:OBBMaxs().z ) / 2 ) ) )
	loose:Spawn()
	local lp = loose:GetPhysicsObject()
	if IsValid( lp ) then lp:EnableMotion( false ) end
	T.WaitUntil( function() return m:GetBiomass() == 4 end, 2, "a chunk touching the machine is swallowed" )
	T.Wait( 0.1 )
	T.Check( not IsValid( loose ), "and gone" )
	for _, e in ipairs( Lunch.All( "meat_chunk" ) ) do e:Remove() end

	-- Water barrels ---------------------------------------------------------------------------------

	local barrel = ents.Create( "water_barrel" )
	barrel:SetPos( m:GetPos() + Vector( -200, -200, 40 ) )
	barrel:Spawn()
	T.Check( not barrel:GetFull() and not Crates.IsHeavy( barrel ), "a new barrel is empty and light" )
	Lunch.TickBarrel( barrel, Lunch.FILL_TIME )
	T.Check( not barrel:GetFull(), "it doesn't fill out of water" )
	Lunch.InWater = function() return true end
	Lunch.TickBarrel( barrel, Lunch.FILL_TIME - 1 )
	T.Check( not barrel:GetFull(), "not filled before FILL_TIME" )
	Lunch.TickBarrel( barrel, 1 )
	T.Check( barrel:GetFull(), "in water, it fills" )
	Lunch.InWater = saved.InWater
	T.Check( Crates.IsHeavy( barrel ), "full, it is carried like a crate" )
	T.Equal( barrel:GetPhysicsObject():GetMass(), Lunch.BARREL_MASS_FULL, "and heavy" )

	boiler:SetWater( 0 )
	T.Check( Lunch.Pour( boiler, barrel ), "a full barrel pours into the boiler" )
	T.Equal( boiler:GetWater(), Lunch.BARREL_WATER, "half the boiler" )
	T.Check( not barrel:GetFull() and not Crates.IsHeavy( barrel ), "and is empty again" )
	T.Check( not Lunch.Pour( boiler, barrel ), "an empty barrel pours nothing" )
	boiler:SetWater( Lunch.BOILER_WATER )
	Lunch.SetBarrelFull( barrel, true )
	T.Check( not Lunch.Pour( boiler, barrel ), "a full boiler takes no more" )

	-- By touch.
	boiler:SetWater( 0 )
	barrel:SetPos( boiler:LocalToWorld( Vector( 0, boiler:OBBMaxs().y + 16, ( boiler:OBBMins().z + boiler:OBBMaxs().z ) / 2 ) ) )
	local bp = barrel:GetPhysicsObject()
	if IsValid( bp ) then bp:EnableMotion( false ) end
	T.WaitUntil( function() return boiler:GetWater() == Lunch.BARREL_WATER end, 2, "a full barrel touching the boiler pours" )
	barrel:Remove()

	-- The boiler -----------------------------------------------------------------------------------

	settle( 55 )
	fresh()
	T.Equal( Lunch.Status( m ), "on", "40-70: the panel runs" )
	Lunch.SetPressure( boiler, 30 )
	T.Equal( Lunch.Status( m ), "low", "under 40: dark" )
	T.Equal( Lunch.Press( p1, m, matching() ), "dark", "and presses do nothing" )
	settle( 55, 0 )
	T.Equal( Lunch.Status( m ), "dry", "no water: dark" )
	Lunch.TickBoiler( boiler, 1 )
	T.Equal( boiler:GetPressure(), 55 - Lunch.DRY_DROP, "and the pressure falls" )
	Lunch.SetPressure( boiler, 2 )
	Lunch.TickBoiler( boiler, 1 )
	T.Equal( boiler:GetPressure(), 0, "to 0" )

	-- The valve: red vents VALVE_RATE a second, black builds it; the turner joins the crew.
	settle( 55 )
	fresh()
	T.Check( Lunch.TurnValve( p2, boiler, "vent" ), "the red handle turns" )
	T.Equal( boiler:GetPressure(), 55 - Lunch.VALVE_RATE, "down a second's turn" )
	T.Check( Lunch.TurnValve( p2, boiler, "build" ), "the black handle turns" )
	T.Equal( boiler:GetPressure(), 55, "up a second's turn" )
	T.Check( not Lunch.TurnValve( p2, boiler, "sideways" ), "no third handle" )
	T.Check( Lunch.CrewOf( m )[ DB.Key( p2 ) ], "turning the valve puts you on the crew" )
	T.Check( Lunch.StartTurn( p2, boiler, "vent" ) and boiler:GetTurning() == "vent", "a held turn starts on the wheel" )
	T.WaitUntil( function() return boiler:GetTurning() == "" end, 2, "and stops when Use is not held" )
	local recv = Net.Receivers[ "gr_valve" ]
	T.Check( recv and recv.opts.target and recv.opts.alive and recv.opts.range and recv.opts.rate, "gr_valve is a validated, rate-limited receiver" )

	-- Overload: running, but a right press may shock.
	near()
	settle( 78 )
	fresh()
	T.Equal( Lunch.Status( m ), "overload", "70-90: overload" )
	Lunch.OVERLOAD_CHANCE = 1
	heal( all )
	T.Equal( Lunch.Press( p1, m, matching() ), "right", "a right press still works" )
	lost = p1:GetMaxHealth() - p1:Health()
	T.Check( lost >= Lunch.OVERLOAD_MIN - 1 and lost <= Lunch.OVERLOAD_MAX, "and shocks for 4-6: lost " .. lost )
	Lunch.OVERLOAD_CHANCE = 0
	heal( all )

	-- The vent: over 90 it scalds everyone near, and stays dark until under 70.
	Lunch.SetPressure( boiler, 95 )
	T.Check( boiler:GetVenting(), "over 90: it vents" )
	T.Equal( Lunch.Status( m ), "venting", "the panel is dark" )
	place( p3, Vector( -700, 0, 0 ) )
	local hit = Lunch.Scald( boiler, 1 )
	T.Check( table.HasValue( hit, p1 ) and table.HasValue( hit, p2 ), "the steam reaches everyone near" )
	T.Check( not table.HasValue( hit, p3 ), "but not someone far off" )
	T.Check( p1:Health() < p1:GetMaxHealth(), "and scalds them" )
	Lunch.SetPressure( boiler, 80 )
	T.Check( boiler:GetVenting() and Lunch.Status( m ) == "venting", "at 80 it is still venting" )
	Lunch.TickBoiler( boiler, 1 )
	T.Equal( boiler:GetPressure(), 80 - Lunch.VENT_DROP, "venting lets the pressure out" )
	Lunch.SetPressure( boiler, 69 )
	T.Check( not boiler:GetVenting(), "under 70 the vent stops" )
	T.Equal( Lunch.Status( m ), "on", "and the panel runs" )
	far()
	heal( all )

	-- The panel ------------------------------------------------------------------------------------

	settle( 55 )
	fresh()
	local tries = 0
	while not wrongButton() and tries < 20 do Lunch.Reroll( m ) tries = tries + 1 end
	local wk = wrongButton()
	T.Equal( Lunch.Press( p3, m, wk ), "wrong", "a press off the light is wrong" )
	T.Equal( p3:Health(), p3:GetMaxHealth(), "the shock isn't instant" )
	T.Check( m:GetButton( wk ) > 0, "and the button stays lit" )
	T.WaitUntil( function() return p3:Health() < p3:GetMaxHealth() end, 2, "a second later, the shock" )
	T.Check( p3:GetMaxHealth() - p3:Health() >= Lunch.WRONG_SHOCK / 2, "a hard one: " .. ( p3:GetMaxHealth() - p3:Health() ) )
	T.Check( not Lunch.CrewOf( m )[ DB.Key( p3 ) ], "a wrong press doesn't make you crew" )
	heal( all )

	local k = matching()
	T.Equal( Lunch.Press( p1, m, k ), "right", "a matching press is right" )
	T.Equal( m:GetButton( k ), 0, "and darkens the button" )
	T.Equal( Lunch.Press( p1, m, k ), "dead", "a dark button does nothing" )
	T.Equal( Lunch.Press( p1, m, 9 ), nil, "there is no ninth button" )

	-- The light moves on when its symbol is gone.
	for i = 1, Lunch.BUTTONS do m:SetButton( i, ( i <= 4 ) and 1 or 2 ) end
	m:SetLight( 1 )
	Lunch.REROLL_CHANCE = 0
	for i = 1, 3 do Lunch.Press( p1, m, i ) end
	T.Equal( m:GetLight(), 1, "while hearts are left, the light stays (no random reroll)" )
	Lunch.Press( p1, m, 4 )
	T.Equal( m:GetLight(), 2, "the last heart gone, the light moves to what is left" )
	Lunch.REROLL_CHANCE = saved.REROLL_CHANCE

	-- A ration: p1 presses, p2 works the valve, p3 watches.
	settle( 55 )
	fresh()
	m:SetBiomass( 2 )
	m:SetOutput( "ration" )
	Lunch.TurnValve( p2, boiler, "vent" )
	Lunch.TurnValve( p2, boiler, "build" )
	local water = boiler:GetWater()
	local n = #made
	T.Equal( clear( p1 ), "done", "clearing all 8 buttons finishes the panel" )
	local crate = made[ n + 1 ]
	T.Check( IsValid( crate ) and crate.GR_Kind == "ration", "a ration crate comes out" )
	T.Check( crate:GetPos():Distance( m:GetPos() + m:GetForward() * 50 ) < 60, "at the output" )
	T.Check( Crates.OnCrew( crate, p1 ) and Crates.OnCrew( crate, p2 ), "stamped with the presser and the valve turner" )
	T.Check( not Crates.OnCrew( crate, p3 ), "not the one who only watched (and pressed wrong)" )
	T.Equal( m:GetBiomass(), 1, "it used 1 biomass" )
	T.Equal( boiler:GetWater(), water - 1, "and 1 water" )
	T.Equal( next( Lunch.CrewOf( m ) ), nil, "the next panel starts a new crew" )
	local lit = 0
	for i = 1, Lunch.BUTTONS do if m:GetButton( i ) > 0 then lit = lit + 1 end end
	T.Equal( lit, Lunch.BUTTONS, "and a fresh panel" )

	-- The lever: clean water needs only water.
	T.Check( Lunch.FlipLever( p1, m ), "the lever flips" )
	T.Equal( m:GetOutput(), "clean_water", "to clean water" )
	m:SetBiomass( 0 )
	water = boiler:GetWater()
	clear( p1 )
	local cw = made[ #made ]
	T.Check( IsValid( cw ) and cw.GR_Kind == "clean_water", "a clean water crate, with no biomass" )
	T.Equal( boiler:GetWater(), water - 1, "for 1 water" )
	Lunch.FlipLever( p1, m )
	T.Equal( m:GetOutput(), "ration", "flipped back to ration" )

	-- 3 crates waiting: the panel goes dark.
	T.Equal( Crates.Waiting( m ), 2, "two crates waiting" )
	m:SetBiomass( 1 )
	clear( p1 )
	T.Equal( Crates.Waiting( m ), 3, "three" )
	T.Equal( Lunch.Status( m ), "full", "the output is full: dark" )
	T.Equal( Lunch.Press( p1, m, matching() or 1 ), "dark", "presses do nothing" )
	local third = made[ #made ]
	cw:Remove()
	third:Remove()
	T.Wait( 0.1 )
	T.Equal( Lunch.Status( m ), "on", "hauling them off lights it again" )

	-- A ration with no biomass: it blows up and burns.
	near()
	place( p1, Vector( -700, 0, 0 ) )
	place( p2, Vector( -700, 80, 0 ) )
	place( p3, Vector( -700, 160, 0 ) )
	fresh()
	m:SetBiomass( 0 )
	n = #made
	clear( p1 )
	T.Equal( #made, n, "no crate" )
	T.Equal( exploded[ 1 ], m, "the machine explodes" )
	T.Check( IsValid( m.GR_Fire ) and m.GR_Fire:GetClass() == "env_fire", "and leaves a fire" )
	T.Check( IsValid( m ), "the machine itself survives" )
	if IsValid( m.GR_Fire ) then m.GR_Fire:Remove() end
	heal( all )

	-- Delivery: the crew splits the price; anyone else is paid in full and reported -------------------

	Econ.ResetRound()
	local price = Econ.Setting( "buy.ration" )
	local b1, b2, b3 = p1:GetBones(), p2:GetBones(), p3:GetBones()
	local paid = Crates.Deliver( p1, crate, stockpile )
	T.Equal( paid, p1:GetBones() - b1, "a crew member delivers: Deliver returns the hauler's own take" )
	T.Equal( p1:GetBones() - b1 + p2:GetBones() - b2, price, "the whole price is split between the crew" )
	T.Check( p2:GetBones() > b2 and paid >= price / 2, "half by work points, the rest (and remainders) to the hauler" )
	T.Equal( p3:GetBones(), b3, "the watcher gets nothing" )
	T.Check( not Crime.Evidence( p1 ).theft, "no theft" )

	local stolen = Crates.Spawn( "ration", m:GetPos() + m:GetForward() * 50 + Vector( 0, 0, 30 ), Crates.Crew( { p1, p2 } ), m ) stolen:SetLocked( false )
	b1, b3 = p1:GetBones(), p3:GetBones()
	T.Equal( Crates.Deliver( p3, stolen, stockpile ), price, "an outsider's delivery pays" )
	T.Equal( p3:GetBones(), b3 + price, "all of it to them" )
	T.Equal( p1:GetBones(), b1, "nothing to the crew" )
	T.Check( Crime.Evidence( p3 ).theft ~= nil, "and it is reported as theft" )
	Crime.TakeEvidence( p3, "theft" )

	local opened = Crates.Spawn( "ration", m:GetPos() + m:GetForward() * 50 + Vector( 0, 0, 30 ), Crates.Crew( { p1, p2 } ), m ) opened:SetLocked( false )
	T.Check( Crates.Open( p3, opened ), "an outsider opens the crew's crate" )
	T.Check( Crime.Evidence( p3 ).theft ~= nil, "theft" )
	Crime.TakeEvidence( p3, "theft" )
	local own = Crates.Spawn( "ration", m:GetPos() + m:GetForward() * 50 + Vector( 0, 0, 30 ), Crates.Crew( { p1, p2 } ), m ) own:SetLocked( false )
	T.Check( Crates.Open( p2, own ), "a crew member opens it" )
	T.Check( not Crime.Evidence( p2 ).theft, "no theft" )

	-- Give bones ---------------------------------------------------------------------------------------

	place( p1, Vector( -200, 0, 0 ) )
	place( p2, Vector( -200, 40, 0 ) )
	place( p3, Vector( -200, 600, 0 ) )
	setBones( p1, 30 )
	b2 = p2:GetBones()
	T.Check( not GiveBones.Give( p1, p2, 7 ), "only the listed amounts" )
	T.Check( not GiveBones.Give( p1, p2, 50 ), "not more than you have" )
	T.Check( not GiveBones.Give( p1, p3, 5 ), "not out of reach" )
	T.Check( not GiveBones.Give( p1, p1, 5 ), "not to yourself" )
	T.Equal( p1:GetBones(), 30, "refusals take nothing" )
	T.Check( GiveBones.Give( p1, p2, 10 ), "10 bones to the crewmate" )
	T.Check( p1:GetBones() == 20 and p2:GetBones() == b2 + 10, "moved" )
	local choices = Interact.Get( "give_bones" ).choices( p1, p2 )
	T.Equal( #choices, 3, "with 20 bones the C menu offers 1, 5 and 10" )
	T.Check( Interact.Run( p1, "give_bones", p2, "5" ), "giving through Interact" )
	T.Check( p1:GetBones() == 15 and p2:GetBones() == b2 + 15, "5 more moved" )

	-- Building a barrel -------------------------------------------------------------------------------

	setBones( p1, 40 )
	p1:SetEyeAngles( Angle( 60, 0, 0 ) )
	local tr = util.TraceLine( { start = p1:EyePos(), endpos = p1:EyePos() + p1:GetAimVector() * 120, filter = p1 } )
	local count = Lunch.BarrelCount()
	local built = Build.Place( p1, "water_barrel", tr.HitPos )
	T.Check( IsValid( built ) and built:GetClass() == "water_barrel", "a water barrel is built" )
	T.Equal( p1:GetBones(), 25, "for 15 bones" )
	T.Equal( Lunch.BarrelCount(), count + 1, "and counted" )
	Build.KINDS.water_barrel.cap = Lunch.BarrelCount()
	T.Check( not Build.Place( p1, "water_barrel", tr.HitPos ), "none past the cap" )
	T.Equal( p1:GetBones(), 25, "and nothing taken" )
	Build.KINDS.water_barrel.cap = barrelCap
	T.Equal( barrelCap, 8, "the cap is 8" )
	if IsValid( built ) then built:Remove() end

	-- Gone ----------------------------------------------------------------------------------------------

	T.Equal( scripted_ents.Get( "ration_press" ), nil, "there is no ration_press" )
	T.Equal( Layout.CLASSES.ration_press, nil, "and no layout class for one" )
	T.Equal( ( Econ.Audit() ), 0, "no bone drift" )

	-- Cleanup
	for _, e in ipairs( made ) do if IsValid( e ) then e:Remove() end end
	for k, v in pairs( saved ) do Lunch[ k ] = v end
	hook.Remove( "GR_CrateMade", "t16c" )
	if sanitarHook then hook.Add( "GR_CrateMade", "gr_sanitar", sanitarHook ) end
	hook.Remove( "GR_LunchExplode", "t16c" )
	Lunch.Reset()
	for _, b in ipairs( all ) do b:Kick( "test" ) end
	T.Wait( 0.3 )
end
