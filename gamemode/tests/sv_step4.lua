-- Step 4: ghost state, fate registry, CanTake rules, slots under contention, death cooldowns.
local function setup( ply, rank, stem )
	ply:SetRank( rank )
	ply:SetStemCells( stem )
end

return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t4_%'" )

	T.Equal( Fates.Get( "ghost" ).index, FATE_GHOST, "ghost is fate 1" )
	T.Equal( #Fates.All(), 6, "ghost plus five fates registered" )
	T.Equal( Fates.Get( "slave" ).DeathCooldown, 15, "slave inherits from its prole base" )
	T.Check( not Fates.Get( "prole" ).ForNewPlayers, "base does not inherit ForNewPlayers back" )
	T.Check( not pcall( Fates.Define, "t4_bad", { Name = "x" } ), "missing Description is a load error" )
	T.Check( not pcall( Fates.Define, "t4_bad", { Name = "x", Description = "y", Cost = "free" } ), "wrong field type is a load error" )
	T.Check( Fates.Get( "t4_bad" ) == nil, "invalid fate is not registered" )

	local g = player.CreateNextBot( "t4_ghost" )
	T.Wait( 0.2 )
	T.Check( g:IsGhost(), "players spawn as ghosts" )
	T.Equal( g:GetMoveType(), MOVETYPE_NOCLIP, "ghosts float" )
	T.Check( g:IsSolid() == false, "ghosts are not solid" )
	local hp = g:Health()
	g:TakeDamage( 50, game.GetWorld(), game.GetWorld() )
	T.Equal( g:Health(), hp, "ghosts take no damage" )
	T.Check( not g:FateHas( "Police" ), "ghost has no police capability" )

	-- Rank gates, both ways.
	setup( g, RANK_FOOLISH, 10 )
	local ok, why = Fates.CanTake( g, "prole" )
	T.Check( not ok, "Foolish refused prole: " .. tostring( why ) )
	T.Check( Fates.CanTake( g, "slave" ), "Foolish may take slave" )
	setup( g, RANK_FRIEND, 10 )
	ok, why = Fates.CanTake( g, "slave" )
	T.Check( not ok, "Friend refused slave: " .. tostring( why ) )
	-- No rank gate above Friend for now (plan, step 11.4): a Friend with the stem cells may be Kaiser.
	ok, why = Fates.CanTake( g, "kaiser" )
	T.Check( ok, "Friend may take kaiser (no rank gate yet): " .. tostring( why ) )
	setup( g, RANK_FRIEND, 1 )
	ok, why = Fates.CanTake( g, "sanitar" )
	T.Check( not ok, "1 stem cell refused a 2-cell fate: " .. tostring( why ) )
	T.Check( not Fates.CanTake( g, "ghost" ), "ghost is not takeable" )

	-- One bot takes each of the five fates.
	local plan = {
		{ "slave", RANK_FOOLISH, 0 }, { "prole", RANK_FRIEND, 3 }, { "korpsman", RANK_FRIEND, 3 },
		{ "sanitar", RANK_FRIEND, 3 }, { "kaiser", RANK_KAISER, 6 },
	}
	local takers = {}
	for _, p in ipairs( plan ) do
		local bot = player.CreateNextBot( "t4_" .. p[ 1 ] )
		setup( bot, p[ 2 ], p[ 3 ] )
		local took = Fates.Take( bot, p[ 1 ] )
		T.Check( took and bot:GetFateDef().id == p[ 1 ], "a ghost can take " .. p[ 1 ] )
		T.Equal( bot:GetStemCells(), p[ 3 ] - ( Fates.Get( p[ 1 ] ).Cost or 0 ), p[ 1 ] .. " charges its cost" )
		takers[ p[ 1 ] ] = bot
	end
	local k = takers.kaiser
	T.Equal( k:Armor(), 75, "kaiser gets fate armor" )
	T.Equal( k:GetMoveType(), MOVETYPE_WALK, "living fates walk" )
	T.Check( takers.sanitar:FateHas( "Police" ), "sanitar has Police capability" )
	T.Check( not Fates.Take( k, "prole" ), "the living can't take another fate" )

	-- Ten bots try for the sanitar slots in the same tick.
	local crowd = T.Bots( 10 )
	for _, b in ipairs( crowd ) do setup( b, RANK_FRIEND, 5 ) end
	local limit = Fates.SlotLimit( Fates.Get( "sanitar" ) )
	local granted = 0
	for _, b in ipairs( crowd ) do
		if Fates.Take( b, "sanitar" ) then granted = granted + 1 end
	end
	T.Equal( Fates.Count( "sanitar" ), limit, "sanitar count stops at its slot limit" )
	T.Equal( granted, limit - 1, "only the free slots were granted (one was already taken)" )

	-- Station: a ghost uses it.
	local station = ents.Create( "fate_station" )
	station:SetKeyValue( "fate", "prole" )
	station:SetPos( Vector( 0, 0, 0 ) )
	station:Spawn()
	setup( g, RANK_FRIEND, 2 )
	station:Use( g, g )
	T.Equal( g:GetFateDef().id, "prole", "using a station applies its fate" )
	T.Equal( g:GetStemCells(), 1, "station charged the cost" )

	-- Death: back to ghost, with this fate's cooldown.
	g:Kill()
	T.Check( Corpse.Of( g ) ~= nil, "dying downs the player first" )
	Corpse.Die( Corpse.Of( g ), "test" ) -- skip the bleed-out (step 7)
	local diedAt = CurTime()
	T.WaitUntil( function() return g:Alive() end, 6, "dead player respawns" )
	T.Check( g:IsGhost(), "respawns as a ghost" )
	ok, why = Fates.CanTake( g, "prole" )
	T.Check( not ok and string.find( why, "Wait" ) ~= nil, "prole cooldown applies: " .. tostring( why ) )
	T.Equal( g:GetCooldown_korpsman(), 0, "other fates are not on cooldown" )
	T.Equal( math.Round( g:GetCooldown_prole() - diedAt ), 15, "cooldown is the fate's 15 s" )

	-- Cooldown survives a reconnect.
	g:Kick( "test" )
	T.WaitUntil( function() return not IsValid( g ) end, 5, "ghost bot left" )
	T.Wait( 0.3 )
	g = player.CreateNextBot( "t4_ghost" )
	T.Check( g:GetCooldown_prole() > CurTime(), "cooldown survives reconnecting" )
	station:Remove()
end
