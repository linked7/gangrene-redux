-- Ghost start: everyone joins and starts each round as a ghost, and a fate is only taken by
-- walking to its purpose in life (fate_station); the menu refuses a ghost who is far from one.
return function( T )
	local a, b = unpack( T.Bots( 2 ) )
	for _, p in ipairs( { a, b } ) do p:SetRank( RANK_FRIEND ) p:SetStemCells( 5 ) end
	T.Wait( 0.3 )
	T.Check( a:IsGhost() and b:IsGhost(), "joining players start as ghosts" )

	local st = T.AtStation( a, "prole" )
	T.Check( IsValid( st ) and Fates.Stations[ st ], "a station is in the registry" )
	b:SetPos( st:GetPos() + Vector( Fates.STATION_REACH * 4, 0, 0 ) )
	local ok, why = Fates.Request( b, "prole" )
	T.Check( not ok and b:IsGhost(), "a far-off ghost cannot take a fate from the menu: " .. tostring( why ) )
	T.Check( Fates.Request( a, "prole" ), "a ghost at the station can" )
	st:Use( b, b )
	T.Equal( b:GetFateDef().id, "prole", "and using the station grants it" )

	Round.Start()
	T.Wait( 0.3 )
	T.Check( a:IsGhost() and b:IsGhost(), "a new round makes everyone a ghost again" )
end
