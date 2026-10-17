-- Step 11 brewing: the brew_barrel's lever picks beer or spirits, a ration touching it is swallowed,
-- Brew.HITS melee hits or shakes finish Brew.YIELD bottles into the stockpile (no timer); spirit
-- cures pox without touching despair; bottles sell at the stockpile; beer and spirits aren't seeded.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:tbrew_%'" )
	Econ.ResetRound()
	T.Equal( Econ.Stock( "fear_beer" ), 0, "beer is not seeded" )
	T.Equal( Econ.Stock( "spirits" ), 0, "spirits are not seeded" )
	T.Check( Config.BrewTime == nil, "there is no brew timer" )

	local function items()
		local out = {}
		for _, e in ents.Iterator() do
			if IsValid( e ) and e:GetClass() == "gr_item" then table.insert( out, e ) end
		end
		return out
	end

	local function bot( name, fate )
		local b = player.CreateNextBot( "tbrew_" .. name )
		b:SetRank( RANK_FRIEND )
		b:SetStemCells( 10 )
		Fates.Take( b, fate )
		return b
	end
	local p = bot( "prole", "prole" )
	T.Wait( 1 )

	local barrel = ents.Create( "brew_barrel" )
	barrel:SetPos( p:GetPos() + p:GetForward() * 80 + Vector( 0, 0, 20 ) )
	barrel:Spawn()
	T.Wait( 0.2 )
	T.Equal( Brew.Count(), 1, "the barrel is tracked" )
	T.Equal( barrel:GetBrew(), 1, "the lever starts on beer" )
	T.Check( Brew.FlipLever( barrel ), "the lever flips" )
	T.Equal( Brew.KINDS[ barrel:GetBrew() ], "spirits", "to spirits" )
	T.Check( Brew.OnLever( barrel, Brew.LeverPos( barrel ) ) and not Brew.OnLever( barrel, barrel:GetPos() ), "the lever is a spot on the rim" )

	T.Check( not Brew.Agitate( barrel ), "an empty barrel doesn't brew" )
	local junk = Items.Spawn( "spirits", 1, barrel:GetPos() + Vector( 0, 0, 60 ) )
	T.Check( not Brew.Feed( barrel, junk ), "only a ration is swallowed" )
	junk:Remove()

	-- A ration dropped onto the barrel is swallowed by touch.
	local loaf = Items.Spawn( Econ.BREAD, 1, barrel:GetPos() + Vector( 0, 0, 50 ) )
	T.WaitUntil( function() return not IsValid( loaf ) end, 5, "the ration is swallowed on touch" )
	T.Equal( barrel:GetState(), Brew.BREWING, "the barrel is brewing" )
	local second = Items.Spawn( Econ.BREAD, 1, barrel:GetPos() + Vector( 0, 0, 200 ) )
	T.Check( not Brew.Feed( barrel, second ), "a full barrel takes no second ration" )
	second:Remove()

	-- Melee hits.
	local d = DamageInfo()
	d:SetDamage( 20 ) d:SetAttacker( p ) d:SetDamageType( DMG_CLUB )
	for _ = 1, 3 do barrel:TakeDamageInfo( d ) end
	T.Equal( barrel:GetHits(), 3, "melee hits count" )
	d:SetDamageType( DMG_BULLET )
	barrel:TakeDamageInfo( d )
	T.Equal( barrel:GetHits(), 3, "bullets don't" )
	T.Check( IsValid( barrel ), "the barrel can't be smashed" )
	-- Shakes.
	T.Check( not Brew.Shake( barrel, 10 ), "a soft bump doesn't count" )
	barrel.GR_NextShake = 0
	T.Check( Brew.Shake( barrel, 400 ), "a hard shake counts" )
	T.Check( not Brew.Shake( barrel, 400 ), "the same bump isn't counted twice" )
	T.Equal( barrel:GetHits(), 4, "4 of 8" )
	local stock = Econ.Stock( "spirits" )
	for _ = 1, Brew.HITS - 5 do Brew.Agitate( barrel ) end
	T.Equal( Econ.Stock( "spirits" ), stock, "not done before the last hit" )
	T.Equal( Brew.Agitate( barrel ), "spirits", "the last hit finishes the batch" )
	T.Equal( Econ.Stock( "spirits" ), stock + 3, "3 spirits went into the stockpile" )
	T.Equal( barrel:GetState(), Brew.IDLE, "the barrel is empty again" )
	T.Equal( barrel:GetHits(), 0, "hits reset" )

	-- A beer batch.
	Brew.FlipLever( barrel )
	local beer = Econ.Stock( "fear_beer" )
	T.Check( Brew.Feed( barrel, Items.Spawn( Econ.BREAD, 1, p:GetPos() + Vector( 0, -80, 40 ) ) ), "fed again" )
	for _ = 1, Brew.HITS do Brew.Agitate( barrel ) end
	T.Equal( Econ.Stock( "fear_beer" ), beer + 3, "3 beers went into the stockpile" )

	-- Spirit cures pox and leaves despair alone.
	Inventory.Add( p, "spirits", 2, true )
	Needs.Add( p, "Pox", 60, "test" )
	Needs.Add( p, "Despair", 40, "test" )
	local dsp = Needs.Get( p, "Despair" )
	Inventory.Use( p, "spirits" )
	T.Equal( Needs.Get( p, "Pox" ), 0, "spirit cures the pox" )
	T.Equal( Needs.Get( p, "Despair" ), dsp, "spirit doesn't touch despair" )
	T.Check( ( Items.Get( "fear_beer" ).Effects.Despair or 0 ) < 0, "beer lowers despair" )

	-- Selling back at a stockpile port (the port's one sell path, Shop.Sell).
	local port = ents.Create( "stockpile_port" )
	port:SetPos( p:GetPos() + Vector( 0, 60, 0 ) )
	port:Spawn()
	local bones, stock = p:GetBones(), Econ.Stock( "spirits" )
	T.Check( Shop.Sell( p, port, "spirits" ), "a bottle sells at the port" )
	T.Equal( p:GetBones(), bones + Shop.Price( "spirits" ), "for the buy price" )
	T.Equal( Econ.Stock( "spirits" ), stock + 1, "into the stock" )
	T.Equal( Inventory.Count( p, "spirits" ), 0, "out of the inventory" )
	port:Remove()

	barrel:Remove()
	for _, e in ipairs( items() ) do e:Remove() end
	p:Kick( "done" )
end
