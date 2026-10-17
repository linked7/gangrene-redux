-- Step 6, part b: a bot with no food or water dies of thirst in about 30 minutes.
-- Steps Needs.Tick (one second each) directly, so the 30 minutes take no real time.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t6b_%'" )
	local b = player.CreateNextBot( "t6b_thirst" )
	T.Wait( 0.2 )
	b:SetRank( RANK_FRIEND ) b:SetStemCells( 5 )
	Fates.Take( b, "prole" )
	Sched.Remove( "needs" ) -- only the simulated seconds count

	local seconds = 0
	while b:Alive() and seconds < 60 * 60 do
		Needs.Tick( b )
		seconds = seconds + 1
	end
	local minutes = seconds / 60
	T.Note( string.format( "died after %.1f simulated min", minutes ) )
	T.Check( not b:Alive(), "dies with no food or water" )
	T.Check( minutes > 24 and minutes < 32, string.format( "thirst kills in about 30 min (%.1f)", minutes ) )
	T.Check( Needs.Get( b, "Emptiness" ) < 100, "thirst, not hunger, killed it" )
end
