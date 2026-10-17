-- Step 9 ports and crate pay: stockpile_port seeds only knives, sells beer back into the stock at
-- its buy price, spawns purchases at the port; a crate pays half to its workers by work points
-- and half (plus remainders) to the hauler, all as "crate" transfers, stolen or not.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:tsp_%'" )
	local a = player.CreateNextBot( "tsp_a" )
	local b = player.CreateNextBot( "tsp_b" )
	local c = player.CreateNextBot( "tsp_c" )
	for _, p in ipairs( { a, b, c } ) do p:SetRank( RANK_FRIEND ) p:SetStemCells( 10 ) end
	T.Wait( 0.2 )
	for _, p in ipairs( { a, b, c } ) do Fates.Take( p, "prole" ) end
	Econ.ResetRound()

	T.Equal( Shop.RANGE, 100, "ports work within 100 units" )
	T.Equal( Econ.Stock( "fear_beer" ), 0, "beer not seeded" )
	T.Equal( Econ.Stock( "spirits" ), 0, "spirits not seeded" )
	T.Equal( Econ.Stock( "knife" ), GetConVar( "shop_stock" ):GetInt(), "knives seeded" )

	local port = ents.Create( "stockpile_port" )
	port:SetPos( a:GetPos() + a:GetForward() * 60 )
	port:Spawn()
	T.Check( IsValid( port ), "stockpile_port spawns" )

	-- Selling beer through the real receiver.
	local recv = net.Receivers[ "nshopsell" ]
	T.Check( recv ~= nil, "nShopSell is registered" )
	local rEnt, rStr = net.ReadEntity, net.ReadString
	local function sell( id )
		net.ReadEntity = function() return port end
		net.ReadString = function() return id end
		recv( 0, a )
		net.ReadEntity, net.ReadString = rEnt, rStr
	end
	Inventory.Add( a, "fear_beer", 1, true )
	local bones = a:GetBones()
	sell( "fear_beer" )
	T.Equal( a:GetBones(), bones + Shop.Price( "fear_beer" ), "beer sells for its buy price" )
	T.Equal( Econ.Stock( "fear_beer" ), 1, "and the stock rises" )
	T.Equal( Inventory.Count( a, "fear_beer" ), 0, "and leaves the seller" )
	T.Wait( 1.1 )
	bones = a:GetBones()
	sell( "ration" )
	T.Equal( a:GetBones(), bones, "rations can't be sold at a port" )

	-- Buying it back: it appears at the port.
	T.Wait( 1.1 )
	T.Check( Shop.Buy( a, port, "fear_beer" ), "beer can be bought back" )
	local near = false
	for _, e in ipairs( ents.FindInSphere( port:GetPos(), 60 ) ) do -- test only
		if e:GetClass() == "gr_item" and e:GetItemId() == "fear_beer" then near = true e:Remove() end
	end
	T.Check( near, "the beer spawns at the port" )

	-- Crate pay split.
	local stockpile for _, e in ipairs( ents.GetAll() ) do if e:GetClass() == "state_stockpile" then stockpile = e break end end
	local own = false
	if not IsValid( stockpile ) then
		stockpile = ents.Create( "state_stockpile" ) stockpile:SetPos( a:GetPos() + Vector( 300, 0, 0 ) ) stockpile:Spawn() own = true
	end
	local ka, kb, kc = DB.Key( a ), DB.Key( b ), DB.Key( c )
	local split = Crates.Split( 21, { [ ka ] = 1, [ kb ] = 2 }, kc )
	local sum, got = 0, {}
	for _, r in ipairs( split ) do sum = sum + r[ 2 ] got[ r[ 1 ] ] = r[ 2 ] end
	T.Equal( sum, 21, "the split pays the whole price" )
	T.Equal( got[ ka ], 3, "worker with 1/3 of the points gets floor(10/3)" )
	T.Equal( got[ kb ], 6, "worker with 2/3 gets floor(20/3)" )
	T.Equal( got[ kc ], 12, "the hauler gets half plus the remainder" )

	local price = Econ.Setting( "buy.ration" )
	local crate = Crates.Spawn( "ration", stockpile:GetPos() + Vector( 0, 0, 200 ), Crates.Crew( { a, b } ), nil, { [ ka ] = 1, [ kb ] = 3 } )
	local ba, bb, bc = a:GetBones(), b:GetBones(), c:GetBones()
	local stock = Econ.Stock( "ration" )
	local reasons = {}
	local oldTransfer = Econ.Transfer
	Econ.Transfer = function( f, t, amt, why, ... ) table.insert( reasons, why ) return oldTransfer( f, t, amt, why, ... ) end
	local paid = Crates.Deliver( c, crate, stockpile ) -- c stole it
	Econ.Transfer = oldTransfer
	local half = math.floor( price / 2 )
	local wa, wb = math.floor( half * 1 / 4 ), math.floor( half * 3 / 4 )
	T.Equal( Econ.Stock( "ration" ), stock + 1, "a delivered crate adds stock" )
	T.Equal( a:GetBones() - ba, wa, "worker a paid by points even though the crate was stolen" )
	T.Equal( b:GetBones() - bb, wb, "worker b paid by points" )
	T.Equal( c:GetBones() - bc, price - wa - wb, "the thief hauler gets the rest" )
	T.Equal( paid, price - wa - wb, "Deliver returns the hauler's pay" )
	local allCrate = #reasons > 0
	for _, r in ipairs( reasons ) do if r ~= "crate" then allCrate = false end end
	T.Check( allCrate, "every payout is a 'crate' transfer" )

	-- Lunch.Crew counts work points.
	local m = { }
	Lunch.Crew( m, a ) Lunch.Crew( m, a ) Lunch.Crew( m, b, 0 )
	T.Equal( Lunch.WorkOf( m )[ ka ], 2, "each step is a work point" )
	T.Equal( Lunch.WorkOf( m )[ kb ], nil, "a zero-point touch joins the crew without points" )
	T.Check( Lunch.CrewOf( m )[ kb ], "but is still crew" )

	T.Check( Econ.Audit() == 0, "bones balance (Econ.Audit)" )
	port:Remove()
	if own then stockpile:Remove() end
	for _, p in ipairs( { a, b, c } ) do p:Kick() end
end
