-- Step 11.3: the sanitar. Kit and slots, Inspect (seen and unseen theft, range, police only),
-- the once-per-episode Teeth bounty for beating and arresting, the sanitation station, and
-- wages that stop when the treasury is empty.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t11c_%'" )

	local function bot( name, fate, stem )
		local b = player.CreateNextBot( "t11c_" .. name )
		b:SetRank( RANK_FRIEND )
		b:SetStemCells( stem or 10 )
		T.Check( Fates.Take( b, fate ), name .. " takes " .. fate )
		return b
	end

	T.Wait( 0.2 )
	local s = bot( "san", "sanitar" )
	local p1 = bot( "thief", "prole" )
	local p2 = bot( "maker", "prole" )
	local all = { s, p1, p2 }

	-- Data -------------------------------------------------------------------------------------

	local f = Fates.Get( "sanitar" )
	T.Equal( f.Slots( 0 ), 2, "slots: 2 at an empty server" )
	T.Equal( f.Slots( 19 ), 3, "slots: 3 at 19 players" )
	T.Equal( f.Slots( 20 ), 4, "slots: 4 at 20 players" )
	T.Equal( f.Slots( 100 ), 6, "slots: at most 6" )
	T.Equal( Fates.SlotLimit( f ), f.Slots( player.GetCount() ), "the slot limit follows the population" )

	T.Check( s:FateHas( "Police" ) and not p1:FateHas( "Police" ), "only the sanitar is police" )
	T.Check( table.HasValue( s:FateHas( "Radio" ), "state" ), "the sanitar is on the state radio" )
	T.Check( string.match( s:Nick(), "^%a+ #%d%d$" ) ~= nil, "codename: " .. s:Nick() )
	T.Check( Inventory.Count( s, "baton" ) == 1 and Inventory.Count( s, "scope" ) == 1, "kit: baton and scope" )
	T.Check( s:HasWeapon( "weapon_gr_baton" ), "the baton is in hand" )
	T.Equal( Inventory.Count( p1, "baton" ), 0, "proles get no baton" )
	T.Equal( s:GetTeeth(), 0, "teeth start at 0" )

	-- Placement: open ground in one direction from the sanitar.
	local base = s:GetPos()
	local dir
	for _, d in ipairs( { Vector( 1, 0, 0 ), Vector( -1, 0, 0 ), Vector( 0, 1, 0 ), Vector( 0, -1, 0 ) } ) do
		local clear = true
		for _, h in ipairs( { 28, 64 } ) do
			local up = Vector( 0, 0, h )
			if util.TraceLine( { start = base + up, endpos = base + d * 250 + up, mask = MASK_BLOCKLOS } ).Hit then clear = false end
		end
		if clear then dir = d break end
	end
	T.Check( dir ~= nil, "found open ground near the spawn" )
	dir = dir or Vector( 1, 0, 0 )
	local side = Vector( -dir.y, dir.x, 0 )
	for _, b in ipairs( all ) do b:SetMoveType( MOVETYPE_NONE ) end
	local function at( b, d, sideways ) b:SetPos( base + dir * d + side * ( sideways or 0 ) ) end
	local function far( b ) b:SetPos( base + dir * 5000 + side * 5000 ) end
	at( s, 0 )
	at( p2, 0, 300 )

	-- Crates (step 11.1) may not be merged yet: stub who carries what.
	local carried = {}
	local hadCrates = Crates ~= nil
	Crates = Crates or {}
	local oldHeldBy = Crates.HeldBy
	Crates.HeldBy = function( ply ) return carried[ ply ] end

	-- Inspect ----------------------------------------------------------------------------------

	-- Unseen theft: no police nearby, so it is only evidence.
	far( p1 )
	T.Check( not Crime.SeenByPolice( p1 ), "the thief is out of sight" )
	Crime.Report( p1, "theft", { madeBy = DB.Key( p2 ) } )
	T.Check( Crime.Evidence( p1 ).theft and not p1:IsWanted(), "unseen theft leaves evidence only" )
	carried[ p1 ] = { GR_Crew = { [ DB.Key( p2 ) ] = true } }

	-- Out of range, then a non-police inspector: both refused, nothing changes.
	at( p1, 150 )
	T.Check( not Interact.Run( s, "inspect", p1 ), "inspect beyond 100 units is refused" )
	at( p1, 60 )
	at( p2, 60, 40 )
	T.Check( not Interact.Run( p2, "inspect", p1 ), "a prole can't inspect" )
	T.Check( Crime.Evidence( p1 ).theft and not p1:IsWanted(), "refused inspections change nothing" )
	T.Check( not Interact.Run( s, "inspect", s ), "a sanitar can't inspect themself" )
	at( p2, 0, 300 )

	local r = Police.Inspect( s, p1 )
	T.Check( r.stolenCrate, "inspect sees the crate someone else made" )
	T.Check( string.find( r.evidence, "theft", 1, true ) ~= nil, "inspect shows the evidence summary: " .. r.evidence )
	T.Check( p1:GetWanted() == WANTED_TORMENT and p1:GetWantedReason() == Police.THEFT_CRIME, "theft evidence becomes torment-wanted" )
	T.Check( math.abs( Crime.WantedLeft( p1 ) - 180 ) < 2, "for 180 s: " .. Crime.WantedLeft( p1 ) )
	T.Check( not Crime.Evidence( p1 ).theft, "the evidence is used up" )

	-- Own crate, no evidence: nothing to find.
	carried[ p1 ] = { GR_Crew = { [ DB.Key( p1 ) ] = true } }
	Crime.ClearWanted( p1 )
	r = Police.Inspect( s, p1 )
	T.Check( not r.stolenCrate and r.evidence == "" and not p1:IsWanted(), "an honest worker inspects clean" )
	carried[ p1 ] = nil
	r = Police.Inspect( s, p1 )
	T.Check( not r.stolenCrate, "no crate, nothing stolen" )

	-- Seen theft: wanted on the spot; a later inspection finds no evidence to add.
	T.Check( Crime.SeenByPolice( p1 ), "the sanitar watches the thief" )
	Crime.Report( p1, "theft", { madeBy = DB.Key( p2 ) } )
	T.Check( p1:GetWanted() == WANTED_TORMENT and not Crime.Evidence( p1 ).theft, "seen theft is wanted at once" )
	T.Check( Interact.Run( s, "inspect", p1 ), "inspect through the context menu" )
	T.Check( p1:GetWanted() == WANTED_TORMENT and math.abs( Crime.WantedLeft( p1 ) - 180 ) < 2, "still torment-wanted, nothing added" )

	-- Bounty -----------------------------------------------------------------------------------

	local function hit( attacker, victim, kind )
		local dmg = DamageInfo()
		dmg:SetDamage( 5 )
		dmg:SetDamageType( kind or DMG_CLUB )
		dmg:SetAttacker( attacker )
		dmg:SetInflictor( attacker )
		victim:TakeDamageInfo( dmg )
	end

	T.Check( Police.TheftWanted( p1 ), "p1 is theft-wanted" )
	hit( p2, p1 )
	T.Equal( p2:GetTeeth(), 0, "a prole's beating earns nothing" )
	hit( s, p1, DMG_BULLET )
	T.Equal( s:GetTeeth(), 0, "a shot is not a beating" )
	hit( s, p1 )
	T.Equal( s:GetTeeth(), 1, "beating a theft-wanted player earns a tooth" )
	hit( s, p1 )
	T.Equal( s:GetTeeth(), 1, "only once per wanted episode" )

	-- Arrest: knock them out, then arrest the body. Already paid this episode.
	Consciousness.PassOut( p1 )
	local rag = Corpse.Of( p1 )
	T.Check( IsValid( rag ), "the thief is out cold" )
	at( p2, 60, 40 )
	T.Check( not Interact.Run( p2, "arrest", rag ), "a prole can't arrest" )
	T.Check( Interact.Run( s, "arrest", rag ), "the sanitar arrests the body" )
	T.Check( not p1:IsWanted(), "arrest clears wanted" )
	T.Equal( s:GetTeeth(), 1, "no second bounty for the same episode" )

	-- A new episode pays again, for the arrest this time.
	Crime.MakeWanted( p1, WANTED_TORMENT, 180, Police.THEFT_CRIME )
	T.Check( Interact.Run( s, "arrest", rag ), "arrest the thief again" )
	T.Equal( s:GetTeeth(), 2, "a new episode's arrest earns a tooth" )
	Consciousness.WakeUp( p1 )
	T.Check( not p1:GetPassedOut(), "the thief wakes" )
	at( p1, 60 )

	-- Wanted for something else: no bounty.
	Crime.MakeWanted( p1, WANTED_JUDGMENT, 100, "breaking into the stockpile" )
	hit( s, p1 )
	T.Equal( s:GetTeeth(), 2, "beating a non-thief earns nothing" )
	Crime.ClearWanted( p1 )
	hit( s, p1 )
	T.Equal( s:GetTeeth(), 2, "beating the innocent earns nothing" )

	-- Sanitation station ------------------------------------------------------------------------

	local st = ents.Create( "sanitation_station" )
	st:SetPos( base + dir * 80 + side * -60 + Vector( 0, 0, 40 ) )
	st:Spawn()
	T.Check( IsValid( st ), "the sanitation_station spawns" )
	at( p2, 60, -40 )
	T.Check( not Interact.Run( p2, "station_pistol", st ), "a prole can't shop at the station" )
	T.Check( Interact.Run( s, "station_pistol", st ), "the sanitar buys a pistol" )
	T.Equal( s:GetTeeth(), 0, "the pistol costs 2 teeth" )
	T.Check( Inventory.Count( s, "pistol" ) == 1 and s:HasWeapon( "weapon_gr_pistol" ), "the pistol is in hand" )
	local ok = Police.Buy( s, "pistol" )
	T.Check( not ok and Inventory.Count( s, "pistol" ) == 1 and s:GetTeeth() == 0, "no teeth, no sale" )
	s:SetTeeth( 10 )
	T.Check( not Police.Buy( s, "crowbar" ), "unknown offers are refused" )
	T.Equal( s:GetTeeth(), 10, "a refused sale costs nothing" )
	far( s )
	T.Check( not Interact.Run( s, "station_smg", st ), "the station is out of reach" )
	at( s, 0 )
	st:Remove()

	-- Wages ------------------------------------------------------------------------------------

	T.Equal( Econ.Setting( "wage.sanitar" ), 40, "the sanitar's wage is 40" )
	local held = Econ.Treasury()
	T.Check( Econ.Transfer( Econ.TREASURY, Econ.UPGRADE_FUND, held, "test" ), "empty the treasury" )
	local bones = s:GetBones()
	Econ.PayWages()
	T.Equal( s:GetBones(), bones, "an empty treasury pays no wage" )
	T.Check( Econ.Transfer( Econ.UPGRADE_FUND, Econ.TREASURY, held, "test" ), "refill the treasury" )
	Econ.PayWages()
	T.Equal( s:GetBones(), bones + 40, "a full treasury pays the wage" )
	T.Equal( p1:GetBones(), 0, "proles draw no wage" )
	T.Equal( ( Econ.Audit() ), 0, "no bone drift" )

	Crates.HeldBy = oldHeldBy
	if not hadCrates then Crates = nil end
end
