-- Breakables: doors burst under club/blast and stay burst; props break into gibs without fire;
-- wood and metal (props and func_breakable brushes) drop wood and scrap.
return function( T )
	local base = Vector( 0, 0, 0 )
	for _, e in ipairs( ents.GetAll() ) do
		if e:GetClass() == "info_player_start" then base = e:GetPos() + Vector( 0, 0, 40 ) break end
	end
	local function count( id )
		local n = 0
		for _, e in ipairs( ents.GetAll() ) do
			if e:GetClass() == "gr_item" and e:GetItemId() == id then n = n + e:GetCount() end
		end
		return n
	end
	local function hit( ent, amt, typ )
		local d = DamageInfo()
		d:SetDamage( amt ) d:SetDamageType( typ ) d:SetAttacker( game.GetWorld() ) d:SetInflictor( game.GetWorld() )
		d:SetDamageForce( Vector( 1, 0, 0 ) )
		ent:TakeDamageInfo( d )
	end

	T.Check( Items.Get == nil or Items.Get( "wood" ) ~= nil, "wood is an item" )

	-- Door
	local door = ents.Create( "prop_door_rotating" )
	door:SetModel( "models/props_c17/door01_left.mdl" )
	door:SetPos( base + Vector( 200, 0, 0 ) )
	door:Spawn()
	hit( door, 500, DMG_BULLET )
	T.Check( not door.GR_Burst, "bullets don't burst a door" )
	hit( door, 60, DMG_CLUB )
	T.Check( not door.GR_Burst and Breakables.Health( door ) == 40, "a ram takes club damage" )
	hit( door, 60, DMG_BLAST )
	T.Check( door.GR_Burst and door:GetNoDraw(), "a blast bursts it open" )
	T.Wait( 2 )
	T.Check( IsValid( door ) and door:GetNoDraw() and door.GR_Burst, "and it stays burst" )

	-- Props
	local wood0, scrap0 = count( "wood" ), count( "scrap" )
	local crate = ents.Create( "prop_physics" )
	crate:SetModel( "models/props_junk/wood_crate001a.mdl" )
	crate:SetPos( base + Vector( 0, 200, 0 ) )
	crate:Spawn()
	T.Equal( Breakables.Yield( crate ), "wood", "a crate is wood" )
	hit( crate, 1, DMG_CLUB )
	T.Check( IsValid( crate ) and crate:GetColor().r < 255, "a hit prop darkens" )
	hit( crate, 100000, DMG_BURN )
	T.Check( not IsValid( crate ) or crate.GR_Broken, "it breaks" )
	T.Check( not IsValid( crate ) or not crate:IsOnFire(), "without fire" )
	T.Wait( 2 )
	T.Check( count( "wood" ) > wood0, "and drops wood" )

	local drum = ents.Create( "prop_physics" )
	drum:SetModel( "models/props_c17/oildrum001.mdl" )
	drum:SetPos( base + Vector( 0, -200, 0 ) )
	drum:Spawn()
	T.Equal( Breakables.Yield( drum ), "scrap", "a drum is metal" )
	hit( drum, 100000, DMG_CLUB )
	T.Wait( 2 )
	T.Check( count( "scrap" ) > scrap0, "a broken drum drops scrap" )

	-- func_breakable brushes, by material
	for mat, id in pairs( { [ "1" ] = "wood", [ "2" ] = "scrap" } ) do
		local b = ents.Create( "func_breakable" )
		b:SetKeyValue( "material", mat )
		b:SetPos( base + Vector( -200, 0, 0 ) )
		b:Spawn()
		T.Equal( Breakables.Yield( b ), id, "material " .. mat .. " brush yields " .. id )
		local before = count( id )
		Breakables.BrushBroken( b )
		T.Wait( 2 )
		T.Check( count( id ) > before, "a broken brush drops " .. id )
		b:Remove()
	end
	local glass = ents.Create( "func_breakable" )
	glass:SetKeyValue( "material", "0" )
	glass:Spawn()
	T.Equal( Breakables.Yield( glass ), nil, "glass yields nothing" )
	glass:Remove()
	door:Remove()
end
