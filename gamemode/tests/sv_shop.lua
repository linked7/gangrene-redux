-- The shop (gr_shop): nShopBuy sells from the list to living buyers who can pay, takes one
-- from the stock, spawns the item in front of them, and refuses the poor, the dead, unknown
-- items, sold-out goods and spammers. StockpileAccess takes for free. Bones balance throughout.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:tshop_%'" )
	local buyer = player.CreateNextBot( "tshop_a" )
	buyer:SetRank( RANK_FRIEND ) buyer:SetStemCells( 10 )
	T.Wait( 0.2 )
	Fates.Take( buyer, "prole" )
	Econ.ResetRound()
	local told = {}
	local oldNotify = Notify
	Notify = function( ply, msg, ... ) if ply == buyer then table.insert( told, msg ) end return oldNotify( ply, msg, ... ) end

	local shop = ents.Create( "gr_shop" )
	shop:SetPos( buyer:GetPos() + buyer:GetForward() * 60 )
	shop:Spawn()

	-- Fire the real receiver with stubbed reads.
	local recv = net.Receivers[ "nshopbuy" ]
	T.Check( recv ~= nil, "nShopBuy is registered" )
	local rEnt, rStr = net.ReadEntity, net.ReadString
	local function send( id )
		net.ReadEntity = function() return shop end
		net.ReadString = function() return id end
		recv( 0, buyer )
		net.ReadEntity, net.ReadString = rEnt, rStr
	end
	local function items( id )
		local n = 0
		for _, e in ipairs( ents.FindInSphere( buyer:GetPos(), 120 ) ) do -- test only
			if e:GetClass() == "gr_item" and e:GetItemId() == id then n = n + 1 end
		end
		return n
	end

	T.Equal( Econ.Stock( "fear_beer" ), GetConVar( "shop_stock" ):GetInt(), "beer seeded from shop_stock" )
	Econ.Transfer( Econ.TREASURY, buyer, 100, "test" )
	local bones, stock = buyer:GetBones(), Econ.Stock( "fear_beer" )
	send( "fear_beer" )
	T.Equal( buyer:GetBones(), bones - 35, "a beer costs 35" )
	T.Equal( Econ.Stock( "fear_beer" ), stock - 1, "and one leaves the stock" )
	T.Equal( items( "fear_beer" ), 1, "the beer appears in front of the buyer" )

	T.Wait( 1.1 )
	bones = buyer:GetBones()
	send( "spirits" )
	T.Equal( buyer:GetBones(), bones, "too poor: no bones taken" )
	T.Equal( items( "spirits" ), 0, "and nothing spawned" )

	T.Wait( 1.1 )
	send( "scrap" )
	T.Equal( items( "scrap" ), 0, "an item not on the list is refused" )

	T.Wait( 1.1 )
	WorldState.Set( "stock.knife", 0 )
	send( "knife" )
	T.Equal( buyer:GetBones(), bones, "sold out: no bones taken" )
	T.Equal( items( "knife" ), 0, "and no knife" )

	local function listed( id )
		for _, e in ipairs( Shop.Listed() ) do if e.id == id then return true end end
		return false
	end
	T.Check( not listed( "knife" ), "a sold-out knife is left off the menu" )
	WorldState.Set( "stock.ration", Econ.Setting( "reserve.ration" ) )
	T.Check( not listed( "ration" ), "rations held at the reserve are left off the menu" )
	WorldState.Set( "stock.ration", Econ.Setting( "reserve.ration" ) + 1 )
	T.Check( listed( "ration" ), "and listed again once there is one to sell" )
	T.Check( listed( "fear_beer" ), "stocked beer is listed" )

	T.Wait( 1.1 )
	WorldState.Set( "stock.knife", 5 )
	for _ = 1, 8 do send( "knife" ) end
	T.Check( items( "knife" ) <= 4, "rate limit stops a burst (" .. items( "knife" ) .. " knives)" )

	T.Wait( 1.1 )
	bones = buyer:GetBones()
	buyer:KillSilent()
	send( "fear_beer" )
	T.Equal( buyer:GetBones(), bones, "a dead buyer is refused" )
	buyer:Spawn()
	T.Wait( 0.2 )

	T.Check( Econ.Audit() == 0, "bones balance (Econ.Audit)" )
	Notify = oldNotify
	for _, e in ipairs( ents.FindInSphere( buyer:GetPos(), 120 ) ) do if e:GetClass() == "gr_item" then e:Remove() end end -- test cleanup
	shop:Remove()
	buyer:Kick()
end
