-- Step 11.5: the Slave. Fate gating by rank, the public marker, commendation (success and every
-- refusal) and freeing at the end of the round (alive vs downed vs too little time).
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t11e_%'" )

	local function bot( name, rank, stem )
		local b = player.CreateNextBot( "t11e_" .. name )
		b:SetRank( rank )
		b:SetStemCells( stem or 0 )
		return b
	end

	local friend = bot( "friend", RANK_FRIEND, 10 )
	local friend2 = bot( "friend2", RANK_FRIEND, 10 )
	local fool = bot( "fool", RANK_FOOLISH, 10 )
	local s1 = bot( "slave1", RANK_FOOLISH )
	local s2 = bot( "slave2", RANK_FOOLISH )
	local s3 = bot( "slave3", RANK_FOOLISH )
	local s4 = bot( "slave4", RANK_FOOLISH )
	T.Wait( 0.3 )

	-- Gating ------------------------------------------------------------------------------------

	local slave = Fates.Get( "slave" )
	T.Check( slave.Cost == 0 and Fates.SlotLimit( slave ) == math.huge and slave.DeathCooldown == 15,
		"slave: cost 0, unlimited slots, 15 s death cooldown" )
	T.Equal( slave.Marker, "Newcomer", "slave carries the public marker" )
	T.Check( not Fates.Get( "prole" ).Marker, "proles carry no marker" )
	T.Equal( slave.CarryBonus, Fates.Get( "prole" ).CarryBonus, "slave inherits the prole's rules" )

	T.Check( not Fates.CanTake( s1, "prole" ), "a Foolish player can't take prole" )
	T.Check( not Fates.CanTake( s1, "korpsman" ), "nor korpsman" )
	T.Check( not Fates.CanTake( friend, "slave" ), "a Friend can't take slave" )
	for _, s in ipairs( { s1, s2, s3, s4 } ) do T.Check( Fates.Take( s, "slave" ), s:SteamName() .. " takes slave" ) end
	T.Check( Fates.Take( friend, "prole" ) and Fates.Take( friend2, "prole" ), "friends take prole" )
	T.Check( s1:FateHas( "Marker" ) == "Newcomer" and not friend:FateHas( "Marker" ), "marker comes from the public fate" )
	T.Check( string.find( s1:Nick(), " #", 1, true ) ~= nil, "barcode name: " .. s1:Nick() )
	-- A Foolish account outside a slave fate (only an admin could do this) to test the rank check.
	Fates.Apply( fool, "prole", { reason = "admin" } )

	-- Place everyone: pinned, spread along x.
	local base = friend:GetPos()
	local all = { friend, friend2, fool, s1, s2, s3, s4 }
	for _, b in ipairs( all ) do b:SetMoveType( MOVETYPE_NONE ) end
	local function at( b, x, y ) b:SetPos( base + Vector( x, y or 0, 0 ) ) end
	at( friend, 0 ) at( s1, 100 ) at( fool, 0, 100 ) at( friend2, 0, -100 )
	at( s2, 100, 100 ) at( s3, 2000 ) at( s4, 2000, 300 )

	-- Commendation: refusals --------------------------------------------------------------------

	local ok, why = Rank.Commend( fool, s1 )
	T.Check( not ok and s1:GetRank() == RANK_FOOLISH, "Foolish rank can't commend: " .. tostring( why ) )
	ok, why = Rank.Commend( s2, s1 )
	T.Check( not ok and s1:GetRank() == RANK_FOOLISH, "a slave can't commend: " .. tostring( why ) )
	ok, why = Rank.Commend( friend, s3 )
	T.Check( not ok and s3:GetRank() == RANK_FOOLISH, "out of range (2000 units): " .. tostring( why ) )
	T.Equal( Interact.Run( friend, "commend", s3 ), false, "the interact receiver refuses out of range too" )
	ok = Rank.Commend( friend, friend2 )
	T.Check( not ok, "only slaves can be commended" )
	T.Check( not friend:GetCommended(), "refusals don't use up the commendation" )

	-- Commendation: success ---------------------------------------------------------------------

	local cells, fcells = s1:GetStemCells(), friend:GetStemCells()
	T.Check( Interact.Get( "commend" ).show( friend, s1 ), "Commend is offered on a slave" )
	T.Check( not Interact.Get( "commend" ).show( friend, friend2 ), "and not on a free player" )
	T.Equal( Interact.Run( friend, "commend", s1 ), true, "friend commends slave1 through Interact" )
	T.Equal( s1:GetRank(), RANK_FRIEND, "slave1 is freed: rank Friend" )
	T.Equal( s1:GetStemCells(), cells + 1, "the freed slave gets a stem cell" )
	T.Equal( friend:GetStemCells(), fcells + 1, "the commender gets a stem cell" )
	T.Check( friend:GetCommended(), "the commendation is used" )
	local row = sql.QueryRow( "SELECT rank, stem_cells FROM players WHERE steamid = 'bot:t11e_slave1'" )
	T.Check( row and tonumber( row.rank ) == RANK_FRIEND and tonumber( row.stem_cells ) == cells + 1,
		"freedom is written to the DB at once" )
	T.Check( s1:FateHas( "ForNewPlayers" ), "a freed slave stays a slave until death" )
	T.Check( not Interact.Get( "commend" ).show( friend2, s1 ), "a freed slave can't be commended again" )

	ok, why = Rank.Commend( friend, s2 )
	T.Check( not ok and s2:GetRank() == RANK_FOOLISH, "one commendation per round: " .. tostring( why ) )
	ok, why = Rank.Commend( s1, s2 )
	T.Check( not ok and s2:GetRank() == RANK_FOOLISH, "a freed slave still in the fate can't commend: " .. tostring( why ) )

	-- The used commendation survives a reconnect.
	friend:Kick( "test" )
	T.Wait( 0.5 )
	friend = bot( "friend", RANK_FRIEND )
	T.Wait( 0.3 )
	T.Check( friend:GetCommended(), "reconnecting doesn't reset the commendation" )

	-- A freed slave who dies may take any fate.
	s1:Kill()
	Corpse.Die( Corpse.Of( s1 ), "test" )
	T.WaitUntil( function() return s1:Alive() and s1:IsGhost() end, 6, "slave1 respawns as a ghost" )
	T.Check( not Fates.CanTake( s1, "slave" ), "freed: slave is beneath them now" )
	T.Check( Fates.Take( s1, "prole" ), "freed: takes prole" )

	-- Surviving the round -----------------------------------------------------------------------

	local oldMin = Config.SlaveMinRoundTime
	Config.SlaveMinRoundTime = 3
	at( s2, 4000 ) -- out of everyone's way
	s2:SetSlaveTime( 0 )
	s3:SetSlaveTime( 0 )
	s4:SetSlaveTime( 0 )
	-- The clock runs while alive in the fate.
	T.WaitUntil( function() return s2:GetSlaveTime() >= 3 end, 6, "slave time accumulates" )
	s3:SetSlaveTime( 0.5 ) -- too little
	s4:Kill()               -- downed at the end
	T.Check( not s4:Alive() and select( 2, Corpse.Of( s4 ) ).state == "bleedout", "slave4 is downed" )
	s4:SetSlaveTime( 100 )

	T.Check( Rank.SurvivedRound( s2 ), "slave2 survived long enough" )
	T.Check( not Rank.SurvivedRound( s3 ), "slave3 too little time" )
	T.Check( not Rank.SurvivedRound( s4 ), "slave4 is downed" )
	local ended, freed = Round.End( "test" )
	T.Check( ended, "Round.End runs" )
	T.Equal( freed and #freed, 1, "one slave freed at the end" )
	T.Equal( s2:GetRank(), RANK_FRIEND, "alive slave with enough time is freed" )
	T.Equal( s3:GetRank(), RANK_FOOLISH, "too little time: still Foolish" )
	T.Equal( s4:GetRank(), RANK_FOOLISH, "downed: still Foolish" )
	T.Equal( Round.End( "again" ), false, "a round ends once" )

	-- A new round clears the clocks and commendations.
	Round.Start()
	T.Check( not friend:GetCommended() and s3:GetSlaveTime() < 1.5, "Round.Start resets the per-round fields" )
	Config.SlaveMinRoundTime = oldMin
end
