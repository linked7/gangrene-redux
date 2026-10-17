-- Step 11 brewing: a prole seals a loaf in a brew_barrel, it ferments for Config.BrewTime, only a
-- prole opens it for 3 bottles; a sealed barrel can be smashed; spirit cures pox without touching
-- despair; bottles sell at the stockpile for the buy price; beer and spirits aren't seeded.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:tbrew_%'" )
	Econ.ResetRound()
	T.Equal( Econ.Stock( "fear_beer" ), 0, "beer is not seeded" )
	T.Equal( Econ.Stock( "spirits" ), 0, "spirits are not seeded" )
	T.Equal( Config.BrewTime, 300, "brew_time defaults to 5 minutes" )

	local function bot( name, fate )
		local b = player.CreateNextBot( "tbrew_" .. name )
		b:SetRank( RANK_FRIEND )
		b:SetStemCells( 10 )
		Fates.Take( b, fate )
		return b
	end
	local p = bot( "prole", "prole" )
	local s = bot( "sanitar", "sanitar" )
	T.Wait( 1 )
	T.Check( p:FateHas( "Proletariat" ) and not s:FateHas( "Proletariat" ), "fates taken" )

	local barrel = ents.Create( "brew_barrel" )
	barrel:SetPos( p:GetPos() + p:GetForward() * 50 + Vector( 0, 0, 20 ) )
	barrel:Spawn()
	T.Wait( 0.2 )
	T.Equal( Brew.Count(), 1, "the barrel is tracked" )

	Inventory.Add( s, Econ.BREAD, 1, true )
	T.Check( not Brew.Fill( s, barrel, "fear_beer" ), "a non-prole can't brew" )
	T.Check( not Brew.Fill( p, barrel, "fear_beer" ), "a prole without a loaf can't brew" )
	Inventory.Add( p, Econ.BREAD, 1, true )
	T.Check( not Brew.Fill( p, barrel, "vodka" ), "an unknown brew is refused" )
	Interact.Run( p, "brew_fill", barrel, "spirits" )
	T.Equal( barrel:GetState(), Brew.BREWING, "the barrel is sealed" )
	T.Equal( Inventory.Count( p, Econ.BREAD ), 0, "the loaf went in" )

	-- Smashing a sealed barrel.
	local other = ents.Create( "brew_barrel" )
	other:SetPos( barrel:GetPos() + Vector( 60, 0, 0 ) )
	other:Spawn()
	Inventory.Add( p, Econ.BREAD, 1, true )
	T.Check( Brew.Fill( p, other, "fear_beer" ), "a second barrel sealed" )
	local d = DamageInfo()
	d:SetDamage( 60 ) d:SetAttacker( s ) d:SetDamageType( DMG_CLUB )
	other:TakeDamageInfo( d )
	T.Equal( other:GetIntegrity(), 40, "a hit takes integrity" )
	other:TakeDamageInfo( d )
	T.Wait( 0.2 )
	T.Check( not IsValid( other ), "at 0 integrity the barrel bursts" )

	-- Fermenting.
	barrel:SetFinishAt( CurTime() + 0.5 )
	T.Check( not Brew.Open( p, barrel ), "a brewing barrel can't be opened" )
	T.WaitUntil( function() return barrel:GetState() == Brew.DONE end, 3, "the barrel finishes" )
	T.Check( not Brew.Open( s, barrel ), "only a prole opens it" )
	local before = #ents.FindByClass( "gr_item" )
	Interact.Run( p, "brew_open", barrel )
	T.WaitUntil( function() return #ents.FindByClass( "gr_item" ) - before >= 3 end, 5, "3 bottles fall out" )
	local n = 0
	for _, e in ipairs( ents.FindByClass( "gr_item" ) ) do
		if e:GetItemId() == "spirits" then n = n + 1 end
	end
	T.Equal( n, 3, "they are spirits" )
	T.Equal( barrel:GetState(), Brew.IDLE, "the barrel is empty again" )

	-- Spirit cures pox and leaves despair alone.
	Inventory.Add( p, "spirits", 2, true )
	Needs.Add( p, "Pox", 60, "test" )
	Needs.Add( p, "Despair", 40, "test" )
	local dsp = Needs.Get( p, "Despair" )
	Inventory.Use( p, "spirits" )
	T.Equal( Needs.Get( p, "Pox" ), 0, "spirit cures the pox" )
	T.Equal( Needs.Get( p, "Despair" ), dsp, "spirit doesn't touch despair" )
	T.Check( ( Items.Get( "fear_beer" ).Effects.Despair or 0 ) < 0, "beer lowers despair" )

	-- Selling at the stockpile.
	local pile = ents.FindByClass( "state_stockpile" )[ 1 ]
	if not IsValid( pile ) then
		pile = ents.Create( "state_stockpile" )
		pile:SetPos( p:GetPos() + Vector( 0, 80, 0 ) )
		pile:Spawn()
	end
	local bones, stock = p:GetBones(), Econ.Stock( "spirits" )
	T.Check( Brew.Sell( p, pile, "spirits" ), "a bottle sells" )
	T.Equal( p:GetBones(), bones + Econ.Setting( "buy.spirits" ), "for the buy price" )
	T.Equal( Econ.Stock( "spirits" ), stock + 1, "into the stock" )
	T.Equal( Inventory.Count( p, "spirits" ), 0, "out of the inventory" )
	T.Check( not Brew.Sell( p, barrel, "spirits" ), "not at a barrel" )

	barrel:Remove()
	for _, e in ipairs( ents.FindByClass( "gr_item" ) ) do e:Remove() end
	p:Kick( "done" ) s:Kick( "done" )
end
