-- Step 11: Kaiser export. Rations leave on the train; a sealed, heavy import crate comes back.
local function bot( name )
	local b = player.CreateNextBot( name )
	b:SetRank( RANK_FRIEND )
	b:SetStemCells( 10 )
	return b
end

return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:tkex_%'" )
	local kaiser, prole = bot( "tkex_kaiser" ), bot( "tkex_prole" )
	T.Wait( 0.3 )
	T.Check( Fates.Take( kaiser, "kaiser" ), "kaiser taken" )
	T.Check( Fates.Take( prole, "prole" ), "prole taken" )
	T.Wait( 0.2 )

	local st = ents.Create( "train_station" )
	st:SetPos( Vector( 0, 0, -9000 ) ) st:Spawn()
	T.Wait( 0.1 )
	local n = Econ.Setting( "export_rations" )
	local savedStock, savedTrip = Econ.Stock( "ration" ), Econ.Setting( "train_trip" )
	WorldState.Set( "econ.train_trip", 1 )
	local before = Econ.Audit()

	kaiser:SetPos( st:GetPos() + Vector( 0, 1000, 0 ) )
	prole:SetPos( st:GetPos() + Vector( 0, 50, 0 ) )
	WorldState.Set( "stock.ration", n - 1 )
	T.Check( not Export.Send( prole, st, "guns" ), "a prole can't export" )
	T.Check( not Export.Send( kaiser, st, "guns" ), "the Kaiser must be at the station" )
	kaiser:SetPos( st:GetPos() + Vector( 0, 60, 0 ) )
	T.Check( not Export.Send( kaiser, st, "guns" ), "not enough rations" )
	WorldState.Set( "stock.ration", n + 5 )
	T.Check( not Export.Send( kaiser, st, "bread" ), "bad cargo is refused" )
	T.Check( Export.Send( kaiser, st, "guns" ), "the train leaves" )
	T.Equal( Econ.Stock( "ration" ), 5, "the rations left the stockpile" )
	T.Check( st:GetAway(), "the train is away" )
	T.Check( not Export.Send( kaiser, st, "tools" ), "only one trip at a time" )

	T.Wait( 2.5 )
	T.Check( not st:GetAway(), "the train came home" )
	local found = st.GR_LastImport
	T.Check( IsValid( found ), "an import crate arrived" )
	if IsValid( found ) then
		T.Equal( found.GR_Kind, "pistol", "guns bring pistols" )
		T.Check( found:GetLocked(), "the import is sealed" )
		T.Check( Crates.IsHeavy( found ), "the import is heavy cargo" )
		local phys = found:GetPhysicsObject()
		T.Check( IsValid( phys ) and phys:GetMass() >= Export.MASS, "the import is heavy" )
		found:Remove()
	end
	T.Equal( Econ.Audit(), before, "the audit is unchanged" )

	WorldState.Set( "stock.ration", savedStock )
	WorldState.Set( "econ.train_trip", savedTrip )
	st:Remove()
	kaiser:Kick() prole:Kick()
end
