-- Step 11: sanitar work. Rust stops a machine and a sanitar's bullets clean it; made crates are
-- locked until a sanitar starts extraction; corpses dragged to the incinerator burn.
local function bot( name )
	local b = player.CreateNextBot( name )
	b:SetRank( RANK_FRIEND )
	b:SetStemCells( 10 )
	return b
end

local function shoot( attacker, ent )
	local d = DamageInfo()
	d:SetDamage( 10 ) d:SetDamageType( DMG_BULLET ) d:SetAttacker( attacker ) d:SetInflictor( attacker )
	ent:TakeDamageInfo( d )
end

return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:tsan_%'" )
	local san, prole, dead = bot( "tsan_san" ), bot( "tsan_prole" ), bot( "tsan_dead" )
	T.Wait( 0.3 )
	T.Check( Fates.Take( san, "sanitar" ), "sanitar taken" )
	T.Check( Fates.Take( prole, "prole" ), "prole taken" )
	T.Check( Fates.Take( dead, "prole" ), "second prole taken" )
	T.Wait( 0.2 )

	local m = ents.Create( "lunch_machine" )
	m:SetPos( Vector( 0, 0, -9000 ) ) m:Spawn()
	T.Wait( 0.1 )

	-- Rust: at the max the machine is seized.
	m:SetRust( Sanitar.RUST_MAX )
	T.Check( Sanitar.Rusted( m ), "max rust means rusted" )
	T.Equal( Lunch.Status( m ), "rusted", "a rusted machine reports rusted" )

	-- A prole's bullet does nothing; a sanitar's knocks rust off.
	shoot( prole, m )
	T.Equal( m:GetRust(), Sanitar.RUST_MAX, "a prole's shot leaves the rust" )
	shoot( san, m )
	T.Equal( m:GetRust(), Sanitar.RUST_MAX - Sanitar.RUST_PER_SHOT, "a sanitar's shot clears rust" )
	T.Check( not Sanitar.Rusted( m ), "no longer seized" )

	-- A made crate is locked and adds rust.
	m:SetRust( 0 )
	local crate = Crates.Spawn( "ration", m:GetPos() + Vector( 0, 60, 0 ), Crates.Crew( { prole } ), m )
	local other = Crates.Spawn( "ration", m:GetPos() + Vector( 0, -60, 0 ), Crates.Crew( { prole } ), m )
	hook.Run( "GR_CrateMade", crate, m )
	hook.Run( "GR_CrateMade", other, m )
	T.Check( crate:GetLocked() and other:GetLocked(), "made crates are locked" )
	T.Equal( m:GetRust(), 2 * Sanitar.RUST_PER_CRATE, "each crate wears the machine" )
	T.Check( not Crates.Open( prole, crate ), "a locked crate won't open" )
	T.Check( not Sanitar.Extract( prole, crate ), "a prole can't extract" )
	T.Check( Sanitar.Extract( san, crate ), "the sanitar extracts" )
	T.Check( not crate:GetLocked() and not other:GetLocked(), "extraction unlocks the machine's crates" )
	T.Check( Crates.Open( prole, other ), "an unlocked crate opens for anyone" )
	crate:Remove()

	-- Corpses at the incinerator burn.
	local inc = ents.Create( "gr_incinerator" )
	inc:SetPos( Vector( 400, 0, -9000 ) ) inc:Spawn()
	local rag = Corpse.Create( dead, "dead" )
	dead.GR_Corpse = nil
	T.Check( IsValid( rag ), "a corpse exists" )
	rag:SetPos( inc:GetPos() + Vector( 0, 0, 10 ) )
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local p = rag:GetPhysicsObjectNum( i )
		if IsValid( p ) then p:SetPos( inc:GetPos() + Vector( 0, 0, 10 ) ) p:EnableMotion( false ) end
	end
	T.Wait( 1.5 )
	T.Check( not IsValid( rag ), "the incinerator burned the corpse" )
	T.Check( Corpse.All()[ rag ] == nil, "the corpse record is gone" )

	inc:Remove() m:Remove()
	san:Kick() prole:Kick() dead:Kick()
end
