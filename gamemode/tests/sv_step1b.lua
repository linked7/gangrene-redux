-- Step 1, part b: run after step1a on a fresh server (step1a's server was killed, not shut down).
return function( T )
	local bot = player.CreateNextBot( "t1_a" )
	T.Equal( DB.Get( bot, "stem_cells" ), 456, "flushed stem cells survive a killed server; the unflushed 789 is lost" )
	T.Equal( DB.Get( bot, "rank" ), 1, "rank survives" )
	T.Equal( DB.GetWorld( "t1_treasury" ), "50", "world value survives" )
	T.Check( DB.Get( bot, "playtime" ) >= 0, "playtime readable" )
end
