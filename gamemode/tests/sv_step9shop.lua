-- Step 9: the C-menu shop. Every living fate buys every item; the bones go to the treasury, the
-- stock count falls and the item lands in front of the buyer. Sold-out goods, poor buyers, the
-- ration limit and ghosts are refused, StockpileAccess withdraws shop goods free, no drift.
local TREASURY = Econ.TREASURY

return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t9s_%'" )
	Econ.ResetRound()
	local seed = Econ.Setting( "shop_stock" )
	T.Equal( seed, 10, "shop_stock defaults to 10" )
	T.Equal( Econ.Stock( "knife" ), seed, "knife is seeded at round start" )
	for _, good in ipairs( { "fear_beer", "spirits" } ) do
		T.Equal( Econ.Stock( good ), 0, good .. " is brewed, not seeded" )
		WorldState.Set( "stock." .. good, seed )
	end
	T.Equal( Econ.Setting( "sell.fear_beer" ), 35, "fear beer costs 35" )
	T.Equal( Econ.Setting( "sell.spirits" ), 85, "spirits cost 85" )
	T.Equal( Econ.Setting( "sell.knife" ), 40, "a knife costs 40" )
	T.Equal( Items.Get( "knife" ).Model, "models/weapons/w_knife_t.mdl", "the knife has the original's model" )
	Econ.SetSetting( "ration_limit", 0 )
	Econ.SetSetting( "reserve.ration", 0 )
	WorldState.Set( "stock.ration", 100 )

	local fates = { { "prole", RANK_FRIEND }, { "sanitar", RANK_FRIEND }, { "korpsman", RANK_FRIEND },
		{ "slave", RANK_FOOLISH }, { "kaiser", RANK_KAISER } }
	local bots = {}
	for i, fr in ipairs( fates ) do
		local b = player.CreateNextBot( "t9s_" .. fr[ 1 ] )
		b:SetRank( fr[ 2 ] )
		b:SetStemCells( 10 )
		Fates.Take( b, fr[ 1 ] )
		bots[ i ] = b
	end
	T.Wait( 0.5 )

	for i, b in ipairs( bots ) do
		local fate = fates[ i ][ 1 ]
		T.Check( b:GetFateDef() and b:GetFateDef().id == fate and Econ.CanShop( b ), fate .. " is alive and can shop" )
		Econ.Transfer( TREASURY, b, 200, "test" )
		for _, good in ipairs( Econ.SHOP ) do
			local t0, s0, b0 = Econ.Treasury(), Econ.Stock( good ), b:GetBones()
			local price = Econ.Setting( "sell." .. good )
			local ok, why, ent = Econ.ShopBuy( b, good )
			T.Check( ok, string.format( "%s buys %s (%s)", fate, good, tostring( why ) ) )
			T.Equal( Econ.Treasury(), t0 + price, fate .. ": the treasury rises by the price of " .. good )
			T.Equal( b:GetBones(), b0 - price, fate .. " pays for " .. good )
			T.Equal( Econ.Stock( good ), s0 - 1, fate .. ": the " .. good .. " count falls by 1" )
			T.Check( IsValid( ent ),
				fate .. ": the " .. good .. " appears" )
			if IsValid( ent ) then
				local d = ent:GetPos() - b:GetPos()
				d.z = 0
				T.Check( d:Length() < 80 and d:GetNormalized():Dot( b:GetForward() ) > 0.5,
					fate .. ": the " .. good .. " is in front of the buyer" )
				ent:Remove()
			end
			if b:GetBones() < 85 then Econ.Transfer( TREASURY, b, 200, "test" ) end
		end
	end
	local p = bots[ 1 ]

	-- The last loaf ----------------------------------------------------------------------------
	WorldState.Set( "stock.ration", 1 )
	local ok, _, ent = Econ.ShopBuy( p, "ration" )
	T.Check( ok, "the last loaf sells" )
	T.Equal( Econ.Stock( "ration" ), 0, "buying the last loaf empties the ration count" )
	if IsValid( ent ) then ent:Remove() end
	local t0 = Econ.Treasury()
	ok = Econ.ShopBuy( p, "ration" )
	T.Check( not ok and Econ.Treasury() == t0, "an empty ration count refuses the sale" )

	-- Sold out, too poor, ghosts, junk --------------------------------------------------------
	WorldState.Set( "stock.knife", 0 )
	ok = Econ.ShopBuy( p, "knife" )
	T.Check( not ok and Econ.Treasury() == t0, "a sold-out knife is refused" )
	local poor = bots[ 4 ]
	Econ.Transfer( poor, TREASURY, poor:GetBones(), "test" )
	Econ.Transfer( TREASURY, poor, 30, "test" )
	local s0 = Econ.Stock( "spirits" )
	ok = Econ.ShopBuy( poor, "spirits" )
	T.Check( not ok and poor:GetBones() == 30 and Econ.Stock( "spirits" ) == s0, "a buyer who can't afford it is refused" )
	ok = Econ.ShopBuy( p, "clean_water" )
	T.Check( not ok, "a good the shop doesn't list is refused" )
	ok = Econ.ShopBuy( p, "nonsense" )
	T.Check( not ok, "an unknown item is refused" )

	-- The ration limit still applies
	Econ.SetSetting( "ration_limit", 2 ) -- the sanitar already bought one loaf above
	WorldState.Set( "stock.ration", 10 )
	local fresh = bots[ 2 ]
	Econ.Transfer( TREASURY, fresh, 100, "test" )
	local ok1, _, e1 = Econ.ShopBuy( fresh, "ration" )
	if IsValid( e1 ) then e1:Remove() end
	local ok2 = Econ.ShopBuy( fresh, "ration" )
	T.Check( ok1 and not ok2, "the ration limit caps shop loaves" )

	-- Free withdrawal for key holders
	local san = bots[ 2 ]
	T.Check( san:FateHas( "StockpileAccess" ), "the sanitar holds a key" )
	local b0 = Econ.Stock( "fear_beer" )
	local bones0 = san:GetBones()
	T.Check( Econ.Withdraw( san, "fear_beer" ), "the sanitar withdraws fear beer" )
	T.Equal( Econ.Stock( "fear_beer" ), b0 - 1, "the withdrawal takes one off the count" )
	T.Equal( san:GetBones(), bones0, "the withdrawal is free" )

	-- Dead buyers
	p:KillSilent()
	ok = Econ.ShopBuy( p, "fear_beer" )
	T.Check( not ok, "a dead player can't shop" )

	T.Equal( ( Econ.Audit() ), 0, "econ_audit shows zero drift" )
	for _, b in ipairs( bots ) do if IsValid( b ) then b:Kick( "test over" ) end end
	Econ.ResetSettings()
end
