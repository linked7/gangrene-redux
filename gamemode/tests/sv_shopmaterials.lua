-- The stockpile port's materials side section: a material with an item and a sell price is
-- bought in bulk from stock and comes out at the port as one stack; unsold, unknown, short,
-- over-limit, poor and ghost buys are refused, the port must be a stockpile, no drift.
local TREASURY = Econ.TREASURY

return function( T )
	Econ.ResetRound()
	T.Equal( #Econ.MATERIALS, 8, "eight materials are listed" )
	-- No material has a price yet; every row reads "not sold" and the server refuses it.
	for _, m in ipairs( Econ.MATERIALS ) do
		if not Econ.SchemaByKey[ "sell." .. m ] then
			T.Check( Econ.MaterialPrice( m ) == nil, m .. " is not sold without a price" )
		end
	end

	local port = ents.Create( "state_stockpile" )
	port:SetPos( Vector( 0, 0, -10000 ) )
	port:Spawn()
	local b = player.CreateNextBot( "tsm_buyer" )
	Fates.Take( b, "prole" )
	T.Wait( 0.5 )
	T.Check( Econ.CanShop( b ), "the buyer can shop" )

	local ok, why = Econ.PortBuyMaterial( b, port, "wood", 1 )
	T.Check( not ok, "wood isn't sold yet (" .. tostring( why ) .. ")" )
	ok = Econ.PortBuyMaterial( b, port, "plutonium", 1 )
	T.Check( not ok, "a non-material is refused" )

	-- Give scrap a price for the test only.
	local injected = not Econ.SchemaByKey[ "sell.scrap" ]
	if injected then Econ.SchemaByKey[ "sell.scrap" ] = { key = "sell.scrap", type = "int", min = 0, default = 3 } end
	local price = Econ.MaterialPrice( "scrap" )
	T.Check( price ~= nil, "scrap is sold once it has a price" )
	price = price or 0
	WorldState.Set( "stock.scrap", 20 )
	Econ.Transfer( TREASURY, b, price * 10 + 5, "test" )

	local t0, b0 = Econ.Treasury(), b:GetBones()
	local ent
	ok, why, ent = Econ.PortBuyMaterial( b, port, "scrap", 7 )
	T.Check( ok, "the buyer buys 7 scrap (" .. tostring( why ) .. ")" )
	T.Equal( Econ.Stock( "scrap" ), 13, "the scrap stock falls by 7" )
	T.Equal( Econ.Treasury(), t0 + price * 7, "the treasury gets 7 times the price" )
	T.Equal( b:GetBones(), b0 - price * 7, "the buyer pays 7 times the price" )
	T.Check( IsValid( ent ) and ent:GetCount() == 7, "one stack of 7 scrap appears" )
	if IsValid( ent ) then
		T.Check( ent:GetPos():Distance( port:WorldSpaceCenter() ) < 120, "the scrap comes out at the port" )
		ent:Remove()
	end

	ok = Econ.PortBuyMaterial( b, port, "scrap", 14 )
	T.Check( not ok, "more than the stock is refused" )
	ok = Econ.PortBuyMaterial( b, port, "scrap", 0 )
	T.Check( not ok, "a zero count is refused" )
	ok = Econ.PortBuyMaterial( b, port, "scrap", 2.5 )
	T.Check( not ok, "a fractional count is refused" )
	ok = Econ.PortBuyMaterial( b, port, "scrap", 256 )
	T.Check( not ok, "a count over the limit is refused" )
	ok = Econ.PortBuyMaterial( b, b, "scrap", 1 )
	T.Check( not ok, "only a stockpile is a port" )
	Econ.Transfer( b, TREASURY, b:GetBones(), "test" )
	local s0 = Econ.Stock( "scrap" )
	ok = Econ.PortBuyMaterial( b, port, "scrap", 1 )
	T.Check( price == 0 or not ok, "a broke buyer is refused" )
	if price > 0 then T.Equal( Econ.Stock( "scrap" ), s0, "a refused buy leaves the stock" ) end
	for _, e in ipairs( ents.FindByClass( "gr_item" ) ) do
		if e:GetPos():Distance( port:WorldSpaceCenter() ) < 200 then e:Remove() end
	end

	T.Check( Net.Receivers[ "nShopBuyMaterial" ] ~= nil, "the purchase receiver is registered" )
	T.Check( Net.Pools[ "gr_port_open" ] == true, "the port panel message is pooled" )

	T.Equal( ( Econ.Audit() ), 0, "econ_audit shows zero drift" )
	if injected then Econ.SchemaByKey[ "sell.scrap" ] = nil end
	WorldState.Set( "stock.scrap", 0 )
	if IsValid( b ) then b:Kick( "test over" ) end
	port:Remove()
	Econ.ResetSettings()
end
