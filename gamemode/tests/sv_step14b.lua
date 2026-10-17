-- Step 14b: soak hygiene. Past Corpse.MAX_DEAD dead bodies the oldest unclaimed ones despawn
-- early; downed bodies and dragged ones are never taken, so step 7's rules hold under load.
local function count( t )
	local n = 0
	for _ in pairs( t ) do n = n + 1 end
	return n
end

local function bot( name )
	local b = player.CreateNextBot( name )
	b:SetRank( RANK_FRIEND )
	b:SetStemCells( 10 )
	return b
end

-- Six bodies made on one spot would shove each other about; frozen, they lie still.
local function freeze( rag )
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum( i )
		if IsValid( phys ) then phys:EnableMotion( false ) end
	end
end

return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t14h_%'" )
	local owner, victim, dragger = bot( "t14h_owner" ), bot( "t14h_victim" ), bot( "t14h_dragger" )
	T.Wait( 0.3 )
	Fates.Take( owner, "prole" ) Fates.Take( victim, "prole" ) Fates.Take( dragger, "prole" )
	T.Wait( 0.2 )
	local saved = Corpse.MAX_DEAD
	Corpse.MAX_DEAD = 3

	-- A dying body: downed, waiting on its bleed-out timer. The cap must never touch it.
	local d = DamageInfo()
	d:SetDamage( 500 ) d:SetDamageType( DMG_BULLET ) d:SetAttacker( owner ) d:SetInflictor( owner )
	victim:TakeDamageInfo( d )
	local downed, drec = Corpse.Of( victim )
	T.Check( IsValid( downed ) and drec.state == "downed", "the victim is downed" )

	-- Six dead bodies, oldest first. The oldest is being dragged.
	local dead = {}
	for i = 1, 6 do
		local rag, rec = Corpse.Create( owner, "dead" )
		owner.GR_Corpse = nil
		rec.diedAt = CurTime() - 100 + i
		rec.decayAt = CurTime() + 600
		freeze( rag )
		dead[ i ] = rag
	end
	-- The dragger stands still on the frozen body, inside Drag's slack, so the drag never snaps.
	dragger:SetMoveType( MOVETYPE_NONE )
	dragger:SetPos( dead[ 1 ]:GetPhysicsObjectNum( 0 ):GetPos() - Vector( 0, 0, 24 ) )
	T.Check( Drag.Start( dragger, dead[ 1 ] ), "the oldest dead body is dragged" )
	T.Equal( count( Corpse.All() ), 7, "seven bodies before the cap runs" )

	T.WaitUntil( function() return count( Corpse.All() ) == 4 end, 2, "the cap leaves three dead bodies and the downed one" )
	T.Check( IsValid( downed ) and Corpse.Get( downed ).state == "downed", "the downed body is untouched" )
	T.Check( IsValid( dead[ 1 ] ) and Drag.Of( dragger ) == dead[ 1 ], "the dragged body is claimed and kept, though oldest" )
	T.Check( not IsValid( dead[ 2 ] ) and not IsValid( dead[ 3 ] ) and not IsValid( dead[ 4 ] ), "the oldest unclaimed ones went first" )
	T.Check( IsValid( dead[ 5 ] ) and IsValid( dead[ 6 ] ), "the newest stay" )
	T.Check( victim.GR_Corpse == downed and not victim:IsGhost(), "the downed player still waits on their body" )

	-- Let go: the dragged body is now the oldest unclaimed one, and over the cap it goes.
	Drag.Stop( dragger )
	local extra, xrec = Corpse.Create( owner, "dead" )
	owner.GR_Corpse = nil
	freeze( extra )
	xrec.diedAt, xrec.decayAt = CurTime(), CurTime() + 600
	T.WaitUntil( function() return not IsValid( dead[ 1 ] ) end, 2, "once let go, the oldest goes when the cap is passed" )
	T.Check( IsValid( extra ) and IsValid( dead[ 5 ] ) and IsValid( dead[ 6 ] ), "the three newest dead bodies remain" )

	-- Under the cap, decay is the only clock again.
	Corpse.MAX_DEAD = saved
	for _, rec in pairs( Corpse.All() ) do
		if rec.state == "dead" then rec.decayAt = CurTime() end
	end
	Corpse.Die( downed, "test" )
	T.WaitUntil( function() return victim:IsGhost() end, 3, "the victim becomes a ghost when the body dies" )
	for _, rec in pairs( Corpse.All() ) do rec.decayAt = CurTime() end
	T.WaitUntil( function() return count( Corpse.All() ) == 0 end, 2, "dead bodies decay as before" )
end
