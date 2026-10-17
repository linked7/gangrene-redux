-- Maladies (step 13): one city-wide threat per round, WINTER first; plus Kaiser imports (coats).
return function( T )
	local oldDay = Config.MaladyDayLength
	local a, k = unpack( T.Bots( 2 ) )
	Round.Start()
	T.Wait( 0.5 )
	T.Equal( Econ.Stock( "coat" ), 0, "coats are not seeded: they arrive only by import" )
	T.Check( Imports.IsImport( "coat" ), "coats are an import good" )

	Maladies.Set( "winter" )
	T.Equal( Maladies.Active(), "winter", "winter can be forced" )
	T.Equal( Maladies.Stage(), 0, "stage 0 before the clock starts" )
	Config.MaladyDayLength = 2
	T.Wait( 1.5 )
	T.Equal( Maladies.Stage(), 0, "still stage 0 while awaiting a Kaiser" )
	Fates.Apply( k, "kaiser", { reason = "test" } )
	T.Wait( 1.5 )
	T.Equal( Maladies.Stage(), 1, "stage 1 once the clock starts" )
	T.Wait( 2.5 )
	T.Check( Maladies.Stage() >= 2, "the stage rises each malady day" )

	-- Cold and the coat
	Fates.Apply( a, "prole", { reason = "admin" } )
	T.Wait( 0.5 )
	local cold = Winter.Rate( a, 3 )
	T.Check( cold >= 0, "Winter.Rate returns a cold rate" )
	Needs.Add( a, "Cold", -1000, "test" )
	a.GR_Coat = nil
	Needs.Add( a, "Cold", 10, "winter" )
	T.Equal( Needs.Get( a, "Cold" ), 10, "uncoated cold applies in full" )
	Winter.Wear( a, true )
	Needs.Add( a, "Cold", 10, "winter" )
	T.Equal( Needs.Get( a, "Cold" ), 14, "a coat cuts the cold" )
	Needs.Add( a, "Cold", -5, "warmth" )
	T.Equal( Needs.Get( a, "Cold" ), 9, "warmth is not cut by the coat" )

	-- Imports
	local treasury, supply = Econ.Treasury(), Econ.Supply()
	T.Check( not Imports.Order( a, "coat" ), "only the Kaiser can import" )
	local crate = Imports.Order( k, "coat" )
	T.Check( IsValid( crate ) and crate.GR_Kind == "coat", "an import spawns a coat crate" )
	T.Equal( Econ.Treasury(), treasury - Econ.Setting( "buy.coat" ), "the treasury pays for the import" )
	T.Equal( Econ.Supply(), supply, "the bone supply is unchanged" )
	T.Check( not Imports.Order( k, "ration" ), "factory goods can't be imported" )
	local stockpile = ents.Create( "state_stockpile" )
	stockpile:SetPos( k:GetPos() + Vector( 200, 0, 0 ) )
	stockpile:Spawn()
	T.Check( Crates.Deliver( a, crate, stockpile ), "hauling the import to the stockpile delivers it" )
	T.Equal( Econ.Stock( "coat" ), 1, "the delivery stocks a coat" )
	stockpile:Remove()

	Maladies.Set( nil )
	T.Equal( Needs.Get( a, "Cold" ), 0, "ending winter clears the cold" )
	Config.MaladyDayLength = oldDay
end
