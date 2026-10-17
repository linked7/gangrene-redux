-- Step 3: scheduler intervals, per-player staggering, and error isolation.
return function( T )
	local bots = T.Bots( 10 )
	T.Equal( #bots, 10, "10 bots" )

	T.ExpectError( "job t3_bad failed" )
	local okRuns, badRuns = 0, 0
	Sched.Every( "t3_ok", 0.5, function() okRuns = okRuns + 1 end )
	Sched.Every( "t3_bad", 1, function() badRuns = badRuns + 1 error( "deliberate" ) end )

	local seen, perTick, tickNo = {}, {}, 0
	hook.Add( "Tick", "t3_count", function() tickNo = tickNo + 1 end )
	Sched.EachPlayer( "t3_each", 1, function( ply )
		seen[ ply ] = ( seen[ ply ] or 0 ) + 1
		perTick[ tickNo ] = ( perTick[ tickNo ] or 0 ) + 1
	end )

	T.Wait( 3.05 )
	Sched.Remove( "t3_ok" )
	Sched.Remove( "t3_bad" )
	Sched.Remove( "t3_each" )
	hook.Remove( "Tick", "t3_count" )

	T.Check( okRuns >= 5 and okRuns <= 7, "0.5 s job ran about 6 times in 3 s (ran " .. okRuns .. ")" )
	T.Check( badRuns >= 2 and badRuns <= 4, "failing 1 s job kept being called (ran " .. badRuns .. ")" )
	T.Check( Sched.Get( "db_flush" ) and Sched.Get( "state_net" ).calls > 20, "core jobs keep running beside the failing one" )

	local n = player.GetCount()
	local minSeen, maxSeen = math.huge, 0
	for _, ply in player.Iterator() do
		local c = seen[ ply ] or 0
		minSeen = math.min( minSeen, c )
		maxSeen = math.max( maxSeen, c )
	end
	T.Check( minSeen >= 2 and maxSeen <= 4, string.format( "each of %d players visited ~3 times in 3 s (min %d, max %d)", n, minSeen, maxSeen ) )

	local busiest = 0
	for _, c in pairs( perTick ) do busiest = math.max( busiest, c ) end
	T.Check( busiest <= 2, "per-player work is spread across ticks (max " .. busiest .. " in one tick)" )
end
