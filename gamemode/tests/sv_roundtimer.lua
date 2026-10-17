-- Round timer (step 13): Round.Start seeds the round but the clock waits ("Awaiting Kaiser")
-- until the first Kaiser spawns; the round-flow marks count from that moment.
return function( T )
	local oldClose = Config.StationsCloseAt
	Config.StationsCloseAt = 2
	local a, q = unpack( T.Bots( 2 ) )
	Round.Start()
	T.Wait( 0.5 )
	T.Check( Round.Number() > 0, "Round.Start still seeds the round" )
	T.Check( not Round.ClockStarted(), "the clock waits for a Kaiser" )
	T.Equal( Round.EndsAt(), 0, "no end time before a Kaiser" )
	T.Equal( RoundFlow.Elapsed(), 0, "round-flow time stands still before a Kaiser" )
	T.Wait( 3 )
	local left = 0
	for ent in pairs( Fates.Stations ) do if IsValid( ent ) then left = left + 1 end end
	T.Check( left > 0, "stations stay open while awaiting the Kaiser" )

	Fates.Apply( q, "kaiser", { reason = "test" } )
	T.Check( Round.ClockStarted(), "the first Kaiser starts the clock" )
	local ends = Round.EndsAt()
	T.Check( math.abs( ends - ( CurTime() + Config.RoundLength ) ) < 1, "the round runs its full length from the Kaiser" )
	T.Check( RoundFlow.Elapsed() < 1, "round-flow marks count from the Kaiser" )
	Fates.Apply( a, "kaiser", { reason = "test" } )
	T.Equal( Round.EndsAt(), ends, "a later Kaiser does not restart the clock" )
	T.Wait( 3.5 )
	left = 0
	for ent in pairs( Fates.Stations ) do if IsValid( ent ) then left = left + 1 end end
	T.Equal( left, 0, "stations close StationsCloseAt after the Kaiser" )
	Config.StationsCloseAt = oldClose
end
