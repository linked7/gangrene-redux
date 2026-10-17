-- Step 13: meta-progression. Stem cells from playtime and objectives, lost to unjust kills and
-- heart attacks, spent without minting bones; Friend -> Kapitan promotion; the round starts on
-- map load and Round.End never changes level while a test runs.
return function( T )
	Config.FateCosts = true -- these checks cover the stem-cell cost, which is off in play for now
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t11e_%'" )

	local function bot( name, rank, stem )
		local b = player.CreateNextBot( "t11e_" .. name )
		b:SetRank( rank )
		b:SetStemCells( stem or 0 )
		return b
	end

	-- The round began on map load.
	T.Check( Round.Number() >= 1, "a round is running: " .. Round.Number() )
	T.Check( not Round.IsOver(), "and isn't over" )
	Round.StartClock() -- the clock starts on the first Kaiser spawn
	T.Check( math.abs( Round.EndsAt() - CurTime() - Config.RoundLength ) < 120, "it ends round_length after the clock starts" )
	T.Equal( Econ.Treasury(), Econ.Supply(), "Round.Start filled the treasury (Econ.ResetRound)" )
	T.Equal( tonumber( DB.GetWorld( "round", 0 ) ), Round.Number(), "the round number is kept in the world table" )

	local p = bot( "worker", RANK_FRIEND, 1 ) -- pays for prole
	local v = bot( "victim", RANK_FRIEND, 1 )
	local g = bot( "ghost", RANK_FRIEND, 0 )
	T.Wait( 0.3 )
	T.Check( Fates.Take( p, "prole" ) and Fates.Take( v, "prole" ), "two proles" )

	-- Earning -----------------------------------------------------------------------------------

	local oldPer, oldKap = Config.PlaytimePerStemCell, Config.KapitanStemCells
	Config.PlaytimePerStemCell = 100
	Config.KapitanStemCells = 5

	Rank.PlaytimeTick( p, 60 )
	T.Equal( p:GetStemCells(), 0, "60 s of 100: nothing yet" )
	Rank.PlaytimeTick( p, 60 )
	T.Equal( p:GetStemCells(), 1, "120 s: one stem cell" )
	Rank.PlaytimeTick( p, 280 )
	T.Equal( p:GetStemCells(), 4, "the remainder carries over: 400 s is four" )
	Rank.PlaytimeTick( g, 1000 )
	T.Equal( g:GetStemCells(), 0, "ghost time earns nothing" )

	hook.Run( "GR_Objective", v, 2, "test objective" )
	T.Equal( v:GetStemCells(), 2, "an objective pays stem cells" )
	T.Equal( v:GetRank(), RANK_FRIEND, "below the threshold: still Friend" )

	-- Promotion ---------------------------------------------------------------------------------

	T.Equal( p:GetRank(), RANK_FRIEND, "4 of 5: still Friend" )
	hook.Run( "GR_Objective", p, 1, "test objective" )
	T.Equal( p:GetRank(), RANK_KAPITAN, "5 stem cells: promoted to Kapitan" )
	local row = sql.QueryRow( "SELECT rank FROM players WHERE steamid = 'bot:t11e_worker'" )
	T.Equal( row and tonumber( row.rank ), RANK_KAPITAN, "promotion is written to the DB" )
	p:SetStemCells( 0 )
	Rank.PlaytimeTick( p, 100 )
	T.Equal( p:GetRank(), RANK_KAPITAN, "spending stem cells doesn't demote" )
	local foolish = bot( "fool", RANK_FOOLISH, 50 )
	T.Check( not Rank.Promote( foolish ), "a Foolish player isn't promoted past Friend by stem cells" )
	local kaiser = bot( "kaiser", RANK_KAISER, 50 )
	T.Check( not Rank.Promote( kaiser ) and kaiser:GetRank() == RANK_KAISER, "a Kaiser-rank player isn't demoted" )

	-- Losing and spending -----------------------------------------------------------------------

	v:SetStemCells( 5 )
	Crime.Judge( v, p )
	T.Equal( v:GetStemCells(), 4, "an unjust kill costs a stem cell" )
	Needs.HeartAttack( v )
	T.Equal( v:GetStemCells(), 3, "a heart attack costs a stem cell" )

	g:SetStemCells( 5 )
	g:SetBones( 0 )
	local treasury = Econ.Treasury()
	T.Check( Fates.Take( g, "prole" ), "ghost takes prole for a stem cell" )
	T.Equal( g:GetStemCells(), 4, "taking a fate spends its cost" )
	T.Equal( g:GetBones(), 0, "spending stem cells gives no bones" )
	T.Equal( Econ.Treasury(), treasury, "nor touches the treasury" )
	T.Equal( ( Econ.Audit() ), 0, "the economy holds" )

	Config.PlaytimePerStemCell, Config.KapitanStemCells = oldPer, oldKap

	-- Round end ---------------------------------------------------------------------------------

	local oldDelay = Config.RoundEndDelay
	Config.RoundEndDelay = 1
	local realChange = Round.ChangeLevel
	local changes, results = 0, {}
	Round.ChangeLevel = function()
		changes = changes + 1
		local r = realChange()
		table.insert( results, r )
		return r
	end
	local started = 0
	hook.Add( "GR_RoundStart", "t13", function() started = started + 1 end )
	local endedWith
	hook.Add( "GR_RoundEnd", "t13", function( reason ) endedWith = reason end )

	T.Check( Round.End( "admin" ), "an admin ends the round" )
	T.Equal( endedWith, "admin", "GR_RoundEnd runs with the reason" )
	T.Check( Round.IsOver(), "the round is over" )
	T.WaitUntil( function() return changes > 0 end, 4, "the level change comes after the end screen" )
	T.Equal( results[ 1 ], false, "but a running test skips it" )
	T.Wait( 1.5 )
	T.Equal( changes, 1, "only once" )

	-- And the timer: a round past its time ends by itself.
	local n = Round.Number()
	Round.Start()
	T.Equal( started, 1, "Round.Start runs GR_RoundStart" )
	T.Equal( Round.Number(), n + 1, "the round number goes up" )
	T.Check( not Round.IsOver(), "the new round is running" )
	WorldState.Set( "round.endsAt", CurTime() + 0.5 )
	T.WaitUntil( function() return Round.IsOver() end, 3, "the round timer ends the round" )
	T.Equal( endedWith, "time", "with reason time" )
	T.WaitUntil( function() return changes == 2 end, 4, "the timer's end changes level too (skipped)" )

	hook.Remove( "GR_RoundStart", "t13" )
	hook.Remove( "GR_RoundEnd", "t13" )
	Round.ChangeLevel = realChange
	Config.RoundEndDelay = oldDelay
	Round.Start()
end
