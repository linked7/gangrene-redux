-- Campfire: three wood chunks fall into an unlit fire, more wood feeds it (capped), a lighter
-- lights it, it warms and ignites, burns out to a pit that wood builds up again. The lighter is an import.
return function( T )
	local base = Vector( 0, 0, 0 )
	for _, e in ipairs( ents.GetAll() ) do
		if e:GetClass() == "info_player_start" then base = e:GetPos() + Vector( 0, 0, 10 ) break end
	end
	local function fires()
		local out = {}
		for f in pairs( Campfire.fires ) do if IsValid( f ) then out[ #out + 1 ] = f end end
		return out
	end
	for _, f in ipairs( fires() ) do f:Remove() end
	-- wood chunks roll; pin the test's chunks where they land
	local function wood( n, pos )
		local e = Items.Spawn( "wood", n, pos )
		local phys = e:GetPhysicsObject()
		if IsValid( phys ) then phys:EnableMotion( false ) end
		return e
	end

	T.Check( Imports.IsImport( "lighter" ), "the lighter is an import" )
	Econ.ResetRound()
	T.Equal( Econ.Stock( "lighter" ), 0, "with no shop stock" )

	local spot = base + Vector( 60, 0, 0 )
	wood( 1, spot )
	wood( 1, spot + Vector( 20, 0, 0 ) )
	T.Wait( 2 )
	T.Equal( #fires(), 0, "two chunks are just wood" )
	wood( 1, spot + Vector( 0, 20, 0 ) )
	T.Wait( 2.5 )
	local fire = fires()[ 1 ]
	T.Check( IsValid( fire ), "three chunks become a campfire" )
	if not IsValid( fire ) then return end
	T.Check( not fire:GetLit() and fire:GetFuel() == Campfire.BASE, "unlit, with 3 minutes of wood" )
	T.Check( not Campfire.IsLit( fire ), "and the burn job skips it" )

	wood( 2, fire:GetPos() + Vector( 0, 0, 20 ) )
	T.Wait( 2.5 )
	T.Equal( fire:GetFuel(), Campfire.BASE + 2 * Campfire.PER_CHUNK, "each chunk adds a minute" )
	wood( 10, fire:GetPos() + Vector( 0, 0, 20 ) )
	T.Wait( 2.5 )
	T.Equal( fire:GetFuel(), Campfire.MAX, "up to 8 minutes" )

	local bots = T.Bots( 1 )
	local ply = bots[ 1 ]
	ply:SetStemCells( 10 )
	T.Wait( 0.2 )
	T.Check( Fates.Take( ply, "kaiser" ), "a bot takes a fate" )
	ply:SetPos( fire:GetPos() + Vector( 70, 0, 0 ) )
	T.Check( not Interact.Get( "campfire_light" ).show( ply, fire ), "no lighter, no option" )
	Inventory.Add( ply, "lighter", 1, true )
	T.Check( Interact.Get( "campfire_light" ).show( ply, fire ), "a lighter offers to light it" )
	Interact.Run( ply, "campfire_light", fire )
	T.Check( fire:GetLit() and fire:IsOnFire() and Campfire.IsLit( fire ), "and lights it" )
	T.Equal( Inventory.Count( ply, "lighter" ), 1, "the lighter is kept" )
	T.Check( Winter.NearFire( ply ), "a lit fire is warmth" )

	local crate = ents.Create( "prop_physics" )
	crate:SetModel( "models/props_junk/cardboard_box004a.mdl" )
	crate:SetPos( fire:GetPos() + Vector( 0, 0, 20 ) )
	crate:Spawn()
	T.Wait( 1.5 )
	T.Check( not IsValid( crate ) or crate:IsOnFire() or crate.GR_Broken, "touching it sets a prop alight" )

	fire:SetBurnEnd( CurTime() + 0.2 )
	T.Wait( 1.5 )
	T.Check( not fire:GetLit() and not fire:IsOnFire() and fire:FuelLeft() == 0, "out of wood it dies to a pit" )
	T.Check( not Campfire.Light( fire ), "an empty pit won't light" )

	-- a burning thing lights a refuelled pit
	wood( 1, fire:GetPos() + Vector( 0, 0, 20 ) )
	T.Wait( 2.5 )
	T.Equal( fire:GetFuel(), Campfire.PER_CHUNK, "new wood builds the pit up" )
	local torch = ents.Create( "prop_physics" )
	torch:SetModel( "models/props_junk/wood_crate001a.mdl" )
	torch:SetPos( fire:GetPos() + Vector( 0, 0, 100 ) )
	torch:Spawn()
	torch:Ignite( 30, 0 )
	Campfire.Touched( fire, torch )
	T.Check( fire:GetLit(), "and anything burning lights it" )
	if IsValid( torch ) then torch:Remove() end
	if IsValid( crate ) then crate:Remove() end
	fire:Remove()
end
