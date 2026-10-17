-- Round flow (step 13) on shortened timers: stations close, ghosts arrive as migrants with
-- papers, the immigration konsole trades papers for a passport and Prole citizenship, and the
-- Kaiser recruits Prole korpsmen up to the number of korpsmen lost.
return function( T )
	local oldClose, oldWave = Config.StationsCloseAt, Config.MigrantWave
	Config.StationsCloseAt, Config.MigrantWave = 2, 1
	local a, s, k, q = unpack( T.Bots( 4 ) )
	a:SetRank( RANK_FRIEND ) k:SetRank( RANK_FRIEND ) q:SetRank( RANK_FRIEND ) s:SetRank( RANK_FOOLISH )
	Round.Start()
	T.Wait( 0.5 )
	T.Check( a:IsGhost() and s:IsGhost(), "everyone starts as a ghost" )
	T.Equal( RoundFlow.Lost(), 0, "no korpsmen lost at round start" )
	Fates.Apply( q, "kaiser", { reason = "test" } )

	T.Wait( 3.5 )
	local left = 0
	for ent in pairs( Fates.Stations ) do if IsValid( ent ) then left = left + 1 end end
	T.Equal( left, 0, "every fate_station is gone after the cutoff" )
	T.Equal( a:GetFateDef().id, "prole", "a waiting ghost arrives as a Prole migrant" )
	T.Check( a.grMigrant and Inventory.Count( a, "papers" ) == 1, "the migrant carries papers" )
	T.Check( s:IsGhost(), "a Foolish ghost skips the migrant path" )

	local kon = ents.Create( "konsole_immigration" )
	kon:SetPos( a:GetPos() + Vector( 40, 0, 0 ) )
	kon:Spawn()
	Interact.Run( a, "gate_passport", kon )
	T.Equal( a:GetFateDef().id, "prole", "the konsole makes the migrant a Prole" )
	T.Check( Inventory.Count( a, "papers" ) == 0 and Inventory.Count( a, "passport" ) == 1, "papers became a passport" )
	T.Check( not a.grMigrant, "no longer a migrant" )
	kon:Remove()

	q:SetPos( a:GetPos() + Vector( 30, 0, 0 ) )
	T.Wait( 0.1 )
	T.Check( not RoundFlow.Offer( q, a ), "no korpsman recruit while none were lost" )
	Fates.Apply( k, "korpsman", { reason = "test" } )
	k:Kill()
	T.Wait( 0.2 )
	T.Equal( RoundFlow.Lost(), 1, "a dead korpsman counts as lost" )
	q:SetPos( a:GetPos() + Vector( 30, 0, 0 ) )
	T.Wait( 0.1 )
	T.Check( RoundFlow.Offer( q, a ), "the Kaiser may now offer one korpsman place" )
	RoundFlow.Answer( a, false )
	T.Equal( a:GetFateDef().id, "prole", "a refusal keeps the Prole" )
	Interact.Run( q, "recruit_korpsman", a )
	T.Check( RoundFlow.Answer( a, true ), "an accepted offer recruits" )
	T.Equal( a:GetFateDef().id, "korpsman", "the Prole becomes a Korpsman" )
	T.Check( not RoundFlow.CanRecruit( q, s ), "the replacement slot is now full" )

	Config.StationsCloseAt, Config.MigrantWave = oldClose, oldWave
	Round.Start()
	T.Wait( 0.3 )
end
