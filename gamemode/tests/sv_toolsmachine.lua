-- The tools machine chain (sh_toolsmachine.lua): scrap and biofuel imports land in stock, exports
-- pay the treasury from the upgrade fund, a powered crucible smelts, the tools machine builds on a
-- right press and shocks on a wrong one, and a broken boulder gives ore.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:ttool_%'" )

	local function bot( name, fate )
		local b = player.CreateNextBot( "ttool_" .. name )
		b:SetRank( RANK_FRIEND )
		b:SetStemCells( 10 )
		T.Check( Fates.Take( b, fate ), name .. " takes " .. fate )
		return b
	end

	T.Wait( 0.2 )
	local k = bot( "kaiser", "kaiser" )
	local w = bot( "worker", "prole" )
	T.Wait( 0.5 )

	local made = {}
	local function spawn( class, offset )
		local e = ents.Create( class )
		e:SetPos( w:GetPos() + offset )
		e:Spawn()
		table.insert( made, e )
		return e
	end

	-- Imports and exports ----------------------------------------------------------------------

	WorldState.Set( "treasury", Econ.Treasury() + 2000 )
	WorldState.Set( "upgrade_fund", Econ.UpgradeFund() + 2000 )
	local scrap, bio = Econ.Stock( "scrap" ), Econ.Stock( "biofuel" )
	T.Check( Imports.Order( k, "scrap" ), "the Kaiser imports scrap" )
	T.Check( Imports.Order( k, "biofuel" ), "and biofuel" )
	T.Equal( Econ.Stock( "scrap" ), scrap + 1, "scrap goes to stock" )
	T.Equal( Econ.Stock( "biofuel" ), bio + 1, "biofuel goes to stock" )

	Econ.AddStock( "material_metal_ballistic", 1 )
	local ball, tre, fund = Econ.Stock( "material_metal_ballistic" ), Econ.Treasury(), Econ.UpgradeFund()
	local price = Econ.Setting( "sell.material_metal_ballistic" )
	T.Check( not Exports.Export( w, "material_metal_ballistic" ), "only the Kaiser exports" )
	T.Check( not Exports.Export( k, "ore" ), "ore can't be exported" )
	T.Check( Exports.Export( k, "material_metal_ballistic" ), "the Kaiser exports ballistic metal" )
	T.Equal( Econ.Stock( "material_metal_ballistic" ), ball - 1, "it leaves stock" )
	T.Equal( Econ.Treasury(), tre + price, "the treasury gets the sell price" )
	T.Equal( Econ.UpgradeFund(), fund - price, "from the upgrade fund" )

	-- Generator and crucible -------------------------------------------------------------------

	local gen = spawn( "machine_generator", Vector( 0, 200, 0 ) )
	local vat = spawn( "vat_metal", Vector( 100, 200, 0 ) )
	local m = spawn( "machine_tools", Vector( -100, 200, 0 ) )
	T.Wait( 0.2 )
	T.Equal( ToolsMachine.GeneratorOf( vat ), gen, "the crucible finds the generator" )
	T.Check( not ToolsMachine.Powered( vat ), "unpowered while off" )
	gen:SetFuel( 50 )
	T.Check( ToolsMachine.Toggle( w, gen ), "a worker switches it on" )
	T.Check( ToolsMachine.Powered( vat ), "now the crucible is powered" )

	Econ.AddStock( "ore", 5 )
	local ore, pot = Econ.Stock( "ore" ), Econ.Stock( "material_metal_pot" )
	if pot >= ToolsMachine.POT_CAP then Econ.AddStock( "material_metal_pot", -pot ) pot = 0 end
	vat:SetHeat( 1000 )
	vat.GR_Next = 0
	T.WaitUntil( function() return Econ.Stock( "material_metal_pot" ) > pot end, 4, "a hot crucible smelts pot metal" )
	T.Equal( Econ.Stock( "ore" ), ore - 1, "from one ore" )
	T.Check( ToolsMachine.CycleVat( w, vat ) and vat:GetMode() == 2, "use switches it to ballistic" )

	-- Tools machine ----------------------------------------------------------------------------

	local function find( right )
		for b = 1, ToolsMachine.BUTTONS do
			if ( ToolsMachine.Symbol( m, b ) == m:GetTarget() ) == right then return b end
		end
	end
	Econ.AddStock( "material_metal_pot", 5 )
	local hp = w:Health()
	local wrong = find( false )
	if wrong then
		T.Equal( ToolsMachine.Press( w, m, wrong ), false, "a wrong button builds nothing" )
		T.Wait( 1.2 )
		T.Check( w:Health() < hp, "and shocks a second later" )
	end
	w:SetHealth( w:GetMaxHealth() )
	local bones = w:GetBones()
	local tool = ToolsMachine.Press( w, m, find( true ) )
	T.Check( isstring( tool ) and ToolsMachine.TOOLS[ tool ] ~= nil, "the right button builds a tool" )
	if tool then T.Check( Econ.Stock( tool ) >= 1, "into stock" ) end
	T.Equal( w:GetBones(), bones + ToolsMachine.LABOR_TOOL, "and pays labor" )

	-- Boulder ----------------------------------------------------------------------------------

	local b = spawn( "boulder", Vector( 0, -200, 0 ) )
	T.Wait( 0.2 )
	ore = Econ.Stock( "ore" )
	local dmg = DamageInfo()
	dmg:SetDamage( ToolsMachine.BOULDER_INTEGRITY )
	dmg:SetAttacker( w )
	b:TakeDamageInfo( dmg )
	T.Check( b:GetBroken(), "the boulder breaks" )
	T.Check( Econ.Stock( "ore" ) >= ore + 3, "into ore in stock" )
	ToolsMachine.RestoreBoulder( b )
	T.Check( not b:GetBroken() and b:GetIntegrity() == ToolsMachine.BOULDER_INTEGRITY, "and comes back whole" )

	for _, e in ipairs( made ) do if IsValid( e ) then e:Remove() end end
end
