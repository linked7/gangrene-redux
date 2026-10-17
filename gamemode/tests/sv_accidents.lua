-- Workplace accidents at the tools machine (sh_toolsmachine.lua): an unauthorized fate gets the
-- 65 shock, a wrong button the 25 shock a second after the klaxon, a rotten machine bites, tools
-- wear rust in, a sanitar shoots it clean, and running it with no metal blows it up.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:tacc_%'" )
	local function bot( name, fate )
		local b = player.CreateNextBot( "tacc_" .. name )
		b:SetRank( RANK_FRIEND )
		b:SetStemCells( 10 )
		T.Check( Fates.Take( b, fate ), name .. " takes " .. fate )
		return b
	end
	T.Wait( 0.2 )
	local k = bot( "kaiser", "kaiser" )
	local w = bot( "worker", "prole" )
	local s = bot( "slave", "slave" )
	local san = bot( "sanitar", "sanitar" )
	T.Wait( 0.5 )

	local bigs, misuse, bites, booms = {}, {}, 0, 0
	hook.Add( "GR_ChatBig", "tacc", function( to, col, text ) table.insert( bigs, text ) end )
	hook.Add( "GR_ToolsMisuse", "tacc", function( m, ply, kind ) table.insert( misuse, kind ) end )
	hook.Add( "GR_ToolsBite", "tacc", function() bites = bites + 1 end )
	hook.Add( "GR_ToolsExplode", "tacc", function() booms = booms + 1 end )

	local gen = ents.Create( "machine_generator" )
	gen:SetPos( w:GetPos() + Vector( 0, 300, 0 ) )
	gen:Spawn()
	local m = ents.Create( "machine_tools" )
	m:SetPos( w:GetPos() + Vector( -100, 300, 0 ) )
	m:Spawn()
	T.Wait( 0.2 )
	T.Check( m:GetRust() >= 0 and m:GetRust() <= 20, "a new machine starts at 0-20 rust" )
	m:SetRust( 0 )
	gen:SetFuel( 50 )
	T.Check( ToolsMachine.Toggle( w, gen ), "the generator runs" )
	local function find( right )
		for b = 1, ToolsMachine.BUTTONS do
			if ( ToolsMachine.Symbol( m, b ) == m:GetTarget() ) == right then return b end
		end
	end

	-- Unauthorized personnel
	k:SetHealth( 100 )
	k:SetArmor( 0 )
	T.Equal( ToolsMachine.Press( k, m, find( true ) ), false, "the Kaiser can't run it" )
	T.Check( table.HasValue( bigs, "UNAUTHORIZED PERSONNEL!" ), "UNAUTHORIZED PERSONNEL!" )
	T.Equal( k:Health(), 100, "no shock during the klaxon second" )
	T.Wait( 1.2 )
	T.Equal( k:Health(), 100 - ToolsMachine.SHOCK_UNAUTHORIZED, "then the 65 beam" )

	-- Wrong button
	w:SetHealth( 100 )
	T.Equal( ToolsMachine.Press( w, m, find( false ) ), false, "a wrong button builds nothing" )
	T.Wait( 1.2 )
	T.Equal( w:Health(), 100 - ToolsMachine.SHOCK, "and beams 25 a second later" )
	T.Equal( misuse[ 1 ], "unauthorized", "misuse kind: unauthorized" )
	T.Equal( misuse[ 2 ], "wrong", "misuse kind: wrong" )

	-- Rust growth; slaves are not immune
	Econ.AddStock( "material_metal_pot", 5 )
	local tool = ToolsMachine.Press( s, m, find( true ) )
	T.Check( isstring( tool ), "a slave builds a tool" )
	T.Check( m:GetRust() >= 11, "the tool wears rust in" )
	m:SetRust( 500 )
	ToolsMachine.AddRust( m, 1 )
	T.Equal( m:GetRust(), ToolsMachine.RUST_MAX, "rust caps at 100" )

	-- Rust bite (1 in 3 presses)
	for i = 1, 40 do
		if bites > 0 then break end
		s:SetHealth( 100 )
		ToolsMachine.Press( s, m, find( false ) )
	end
	T.Check( bites > 0, "a rotten machine bites" )

	-- A sanitar shoots it clean
	m:SetRust( 100 )
	local d = DamageInfo()
	d:SetDamage( 10 )
	d:SetAttacker( san )
	d:SetDamageType( DMG_BULLET )
	m:TakeDamageInfo( d )
	T.Check( m:GetRust() < 100, "a sanitar's bullet cleans it" )
	m:SetRust( 0 )

	-- Operator error: running it with no metal
	booms = 0
	for _, cost in pairs( ToolsMachine.TOOLS ) do
		for mat in pairs( cost ) do Econ.AddStock( mat, -Econ.Stock( mat ) ) end
	end
	T.Wait( 1.2 )
	T.Equal( ToolsMachine.Press( w, m, find( true ) ), false, "no metal: nothing built" )
	T.Equal( booms, 1, "operator error: it explodes" )

	for _, n in ipairs( { "GR_ChatBig", "GR_ToolsMisuse", "GR_ToolsBite", "GR_ToolsExplode" } ) do hook.Remove( n, "tacc" ) end
	for _, e in ipairs( { gen, m } ) do if IsValid( e ) then e:Remove() end end
end
