-- Rocket turret (sh_rocketturret.lua, turret_rocket): one at a time, tracked by reference; targets
-- a visible living player in range; permit and noclip exempt; fires boosted rockets; a hit locks
-- it and costs integrity; destroyed it drops rockets and a machine brain; idles on GR_TurretIdle.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:trt_%'" )
	T.Wait( 0.2 )
	local b = player.CreateNextBot( "trt_target" )
	b:SetRank( RANK_FRIEND )
	b:SetStemCells( 10 )
	T.Check( Fates.Take( b, "prole" ), "the bot takes prole" )
	T.Wait( 0.5 )

	local pos = b:GetPos() + Vector( 0, 0, 100 )
	local t = RocketTurret.Spawn( pos )
	T.Check( IsValid( t ), "a turret spawns" )
	T.Equal( RocketTurret.Get(), t, "tracked by reference" )
	T.Check( RocketTurret.Spawn( pos ) == nil, "only one at a time" )
	T.Check( t:GetIntegrity() >= 4 and t:GetIntegrity() <= 6, "integrity 4-6" )
	T.Equal( t:GetMoveType(), MOVETYPE_FLY, "flies" )
	T.Check( t.Sleeping, "starts asleep" )

	T.Check( t:ValidTarget( b ), "a living prole is a target" )
	Inventory.Add( b, "permit_turret", 1, true )
	T.Check( not t:ValidTarget( b ), "a turret permit exempts" )
	Inventory.Remove( b, "permit_turret", 1 )
	b:AddEFlags( EFL_NOCLIP_ACTIVE )
	T.Check( not t:ValidTarget( b ), "noclip exempts" )
	b:RemoveEFlags( EFL_NOCLIP_ACTIVE )

	t.NextAct = 0
	local found = t:SearchForTarget()
	T.Equal( found, b, "the search finds the bot" )
	T.Equal( t:GetTarget(), b, "target networked" )
	T.Check( not t.Sleeping, "wakes on a find" )

	local r = t:FireRocket()
	T.Check( IsValid( r ) and r:GetClass() == "rpg_missile", "fires an rpg_missile" )
	T.Equal( t.RocketSpeedBoost, 10, "boost grows 10 per shot" )
	if IsValid( r ) then r:Remove() end

	-- Idle
	hook.Add( "GR_TurretIdle", "test_rt", function() return true end )
	t.NextAct = 0
	local fired = t.Fired
	t:Tick()
	T.Equal( t.Fired, fired, "idle: no fire" )
	hook.Remove( "GR_TurretIdle", "test_rt" )

	-- Hit: lock and lose integrity
	local before = t:GetIntegrity()
	local d = DamageInfo()
	d:SetDamage( 10 ) d:SetDamageType( DMG_BULLET ) d:SetAttacker( b ) d:SetDamagePosition( t:GetPos() )
	t:TakeDamageInfo( d )
	T.Equal( t:GetIntegrity(), before - 1, "a hit costs integrity" )
	T.Check( t:GetLocked() and t.NextAct >= CurTime() + 9, "a hit locks it 10-35 s" )
	t:TakeDamageInfo( d )
	T.Equal( t:GetIntegrity(), before - 1, "locked: no further loss" )

	-- Destroy
	t:SetIntegrity( 1 )
	t:SetLocked( false )
	t:TakeDamageInfo( d )
	T.Wait( 4 )
	T.Check( not IsValid( t ) and RocketTurret.Get() == nil, "destroyed and forgotten" )
	local rockets, brains = 0, 0
	for _, e in ipairs( ents.FindInSphere( pos, 250 ) ) do
		local id = e.GetItemId and e:GetItemId()
		if id == "rocket" then rockets = rockets + 1 elseif id == "artifact_ai" then brains = brains + 1 end
	end
	T.Check( rockets >= 4, "drops rockets (" .. rockets .. ")" )
	T.Equal( brains, 1, "drops one machine brain" )
	b:Kick()
end
