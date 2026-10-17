-- Step 6, part b: with no food or water a bot never takes damage from it, but grows slower and
-- weaker from about minute 12, and its Pox rises once Dryness is full. A body downed at full
-- hunger can't be revived. Steps Needs.Tick (one second each) directly, so no real time passes.
local function hit( victim, attacker, amount )
	local d = DamageInfo()
	d:SetDamage( amount )
	d:SetDamageType( DMG_BULLET )
	d:SetAttacker( attacker )
	d:SetInflictor( attacker )
	victim:TakeDamageInfo( d )
end

return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t6b_%'" )
	local b = player.CreateNextBot( "t6b_thirst" )
	local v = player.CreateNextBot( "t6b_target" )
	local k = player.CreateNextBot( "t6b_medic" )
	T.Wait( 0.2 )
	for _, p in ipairs( { b, v, k } ) do p:SetRank( RANK_FRIEND ) p:SetStemCells( 5 ) end
	Fates.Take( b, "prole" ) Fates.Take( v, "prole" ) Fates.Take( k, "korpsman" )
	Sched.Remove( "needs" ) -- only the simulated seconds count

	local walk0 = b:GetWalkSpeed()
	local function tick( n ) for _ = 1, n do Needs.Tick( b ) end end

	tick( 11 * 60 )
	T.Equal( b:GetWalkSpeed(), walk0, "full speed at minute 11" )
	tick( 4 * 60 )
	T.Check( b:GetWalkSpeed() < walk0, "slower by minute 15: " .. b:GetWalkSpeed() )
	T.Check( Needs.Weakness( b ) > 0, "weakness has started" )

	-- Run to an hour: the bot never dies of it and never loses HP.
	local hurt, firstPox = 0, nil
	hook.Add( "EntityTakeDamage", "t6b", function( ent ) if ent == b then hurt = hurt + 1 end end )
	for s = 1, 45 * 60 do
		tick( 1 )
		if not firstPox and Needs.Get( b, "Pox" ) > 0 then firstPox = 15 * 60 + s end
	end
	T.Check( b:Alive(), "still alive after an hour without food or water" )
	hook.Remove( "EntityTakeDamage", "t6b" )
	T.Equal( hurt, 0, "hunger and thirst never deal damage" )
	T.Check( Needs.Get( b, "Dryness" ) >= 100 and Needs.Get( b, "Emptiness" ) >= 100, "both full" )
	T.Check( firstPox and firstPox > 24 * 60 and firstPox < 27 * 60, "Pox starts once Dryness is full: " .. tostring( firstPox and firstPox / 60 ) )
	T.Check( Needs.Get( b, "Pox" ) > 10, "Pox keeps rising: " .. Needs.Get( b, "Pox" ) )
	T.Equal( Needs.Weakness( b ), 1, "fully weak" )
	T.Check( math.abs( b:GetWalkSpeed() - walk0 * Needs.WEAK_SPEED ) < 1, "speed x0.7 at full weakness" )
	T.Check( math.abs( b:GetRunSpeed() - Config.RunSpeed * Needs.WEAK_SPEED ) < 1, "run speed too" )

	-- Pox floor.
	Needs.Add( b, "Pox", 100, "test" )
	T.Check( b:GetMaxHealth() >= Needs.POX_FLOOR, "Pox never takes max HP below the floor" )

	-- Damage dealt x0.6.
	v:SetHealth( 100 )
	hit( v, b, 50 )
	T.Check( math.abs( v:Health() - 70 ) <= 1, "a fully weak player deals 60% damage: " .. v:Health() )

	-- Eating restores strength.
	b.GR_Needs.Emptiness = 0 b.GR_Needs.Dryness = 0
	tick( 1 )
	T.Equal( b:GetWalkSpeed(), walk0, "fed and watered: full speed again" )

	-- Downed at full hunger: no revive; a wounded one still gets up.
	b.GR_Needs.Emptiness = 100
	b:SetHealth( 1 )
	hit( b, v, 200 ) -- far past 0: dying
	local rag, rec = Corpse.Of( b )
	T.Check( rec and rec.starved, "the body is marked starved" )
	k:SetPos( rag:GetPos() + Vector( 30, 0, 0 ) )
	T.Check( not Corpse.StartRevive( k, rag ), "a korpsman can't revive a body downed at full hunger" )
	T.Check( not Corpse.Revive( rag, k ), "nor can the revive path itself" )
	Corpse.Die( rag, "test" )

	Sched.EachPlayer( "needs", 1, function( ply ) Needs.Tick( ply ) end )
end
