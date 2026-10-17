-- Sanitar recruiting (step 11.4): the Kaiser's context action on a living prole within range,
-- the yes/no answer, slot and range checks, no stem-cell cost, and no sanitar fate_station.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:tsr_%'" )

	local function bot( name, fate )
		local b = player.CreateNextBot( "tsr_" .. name )
		b:SetRank( RANK_FRIEND )
		b:SetStemCells( 10 )
		T.Check( Fates.Take( b, fate ), name .. " takes " .. fate )
		return b
	end

	-- No station for the sanitar.
	local hasStation = false
	for _, e in ipairs( Layout.DefaultSet() ) do
		if e.class == "fate_station" and e.kv.fate == "sanitar" then hasStation = true end
	end
	T.Check( not hasStation, "the default layout has no sanitar fate_station" )
	T.Check( Layout.DefaultSet()[ 1 ] ~= nil, "the default layout still has stations" )

	local k = bot( "kaiser", "kaiser" )
	local p = bot( "prole", "prole" )
	local k2 = bot( "korps", "korpsman" )
	T.Wait( 0.3 )
	p:SetPos( k:GetPos() + Vector( 50, 0, 0 ) )
	k2:SetPos( k:GetPos() + Vector( 0, 50, 0 ) )

	local d = Interact.Get( "recruit" )
	T.Check( d ~= nil, "the recruit action is registered" )
	T.Equal( d.label( k, p ), "Recruit as Sanitar", "label names the fate" )
	T.Check( d.show( k, p ), "the Kaiser sees it on a prole" )
	T.Check( not d.show( k, k2 ), "not on a korpsman" )
	T.Check( not d.show( p, k2 ), "a prole has no such action" )
	T.Check( not Interact.Run( p, "recruit", k2 ), "a prole cannot run it" )

	-- Refusal leaves the prole a prole.
	T.Check( Interact.Run( k, "recruit", p ), "the Kaiser offers" )
	T.Check( Recruit.pending[ p ] ~= nil, "the offer is pending" )
	T.Check( not Recruit.Answer( p, false ), "the prole refuses" )
	T.Equal( p:GetFateDef().id, "prole", "still a prole after refusing" )
	T.Check( not Recruit.Answer( p, true ), "no answer without an offer" )

	-- Out of range.
	p:SetPos( k:GetPos() + Vector( 300, 0, 0 ) )
	T.Check( not Recruit.Offer( k, p ), "out of range is refused" )
	p:SetPos( k:GetPos() + Vector( 50, 0, 0 ) )

	-- Acceptance, at no stem-cell cost.
	local cells = p:GetStemCells()
	T.Check( Recruit.Offer( k, p ), "offer again" )
	T.Check( Recruit.Answer( p, true ), "the prole accepts" )
	T.Equal( p:GetFateDef().id, "sanitar", "the prole is now a sanitar" )
	T.Equal( p:GetStemCells(), cells, "no stem cells spent" )
	T.Check( not d.show( k, p ), "no action on a sanitar" )

	-- Slots full: fill the remaining sanitar slots and try once more.
	local limit = Fates.SlotLimit( Fates.Get( "sanitar" ) )
	local extra = {}
	for i = Fates.Count( "sanitar" ) + 1, limit do
		local s = player.CreateNextBot( "tsr_s" .. i )
		Fates.Apply( s, "sanitar", { reason = "admin" } )
		table.insert( extra, s )
	end
	local p2 = bot( "prole2", "prole" )
	T.Wait( 0.3 )
	p2:SetPos( k:GetPos() + Vector( -50, 0, 0 ) )
	local ok, why = Recruit.Offer( k, p2 )
	T.Check( not ok, "no free slot is refused: " .. tostring( why ) )

	for _, b in ipairs( { k, p, k2, p2, unpack( extra ) } ) do b:Kick( "test done" ) end
end
