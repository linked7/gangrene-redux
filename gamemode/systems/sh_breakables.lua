-- Breakables (step 7): doors burst under rams and blasts, props smash into gibs, and wood and
-- metal leave something to carry away.
--
--   Doors (func_door, func_door_rotating, prop_door_rotating) take only club and blast damage,
--   from a pool of Breakables.DOOR_HEALTH. At 0 they burst open: the door goes non-solid and
--   invisible, and a physics copy of a model door flies off. They never repair during the round.
--   Props (prop_physics*) have BoundingRadius*8 health (or ent.health). Hits scale like the
--   original (x1.25, bullets x0.8), they darken as they wear down, and at 0 break into gibs.
--   They never ignite.
--   Yield: wooden props and wood-material func_breakable brushes drop 1-3 `wood` (campfire, step
--   13); metal props and metal-material brushes drop 1-3 `scrap` (step 8).
--
--   Breakables.Health( ent ), Breakables.Max( ent )                 server
--   Breakables.BurstDoor( door, force ), Breakables.BreakProp( ent, force )
--   Breakables.Yield( ent ) -> "wood" | "scrap" | nil
--   Breakables.Drop( id, pos ) -> count
--   Breakables.BrushBroken( ent )    a func_breakable broke (called from its removal)
--   hooks GR_DoorBurst( door ), GR_PropBreak( ent )
Breakables = Breakables or {}

Breakables.DOOR_HEALTH = 100
Breakables.WOOD = "wood"
Breakables.SCRAP = "scrap"
Breakables.DOORS = { func_door = true, func_door_rotating = true, prop_door_rotating = true }
Breakables.PROPS = { prop_physics = true, prop_physics_multiplayer = true, prop_physics_respawnable = true }

Items.Define( Breakables.WOOD, {
	Name = "Wood",
	Description = "A splintered chunk of wood. Burns, if you have enough of it.",
	Weight = 1,
	Model = "models/gibs/wood_gib01a.mdl",
} )

local function isDoor( ent ) return IsValid( ent ) and Breakables.DOORS[ ent:GetClass() ] == true end
local function isProp( ent ) return IsValid( ent ) and Breakables.PROPS[ ent:GetClass() ] == true end

if SERVER then
	-- func_breakable "material" keyvalue
	local BRUSH_YIELD = { [ 1 ] = Breakables.WOOD, [ 2 ] = Breakables.SCRAP }

	function Breakables.Max( ent )
		if isDoor( ent ) then return Breakables.DOOR_HEALTH end
		if isProp( ent ) then return ent.health or math.max( ent:BoundingRadius() * 8, 1 ) end
		return 0
	end

	function Breakables.Health( ent )
		if ent.GR_BreakHP == nil then ent.GR_BreakHP = Breakables.Max( ent ) end
		return ent.GR_BreakHP
	end

	function Breakables.Yield( ent )
		if not IsValid( ent ) then return nil end
		if ent:GetClass() == "func_breakable" then
			return BRUSH_YIELD[ tonumber( ent:GetInternalVariable( "m_Material" ) ) or -1 ]
		end
		local phys = ent:GetPhysicsObject()
		local s = string.lower( ( IsValid( phys ) and phys:GetMaterial() or "" ) .. " " .. ( ent:GetModel() or "" ) )
		if string.find( s, "wood", 1, true ) then return Breakables.WOOD end
		if string.find( s, "metal", 1, true ) then return Breakables.SCRAP end
		return nil
	end

	function Breakables.Drop( id, pos )
		local n = math.random( 1, 3 )
		local list = {}
		for i = 1, n do list[ i ] = id end
		Items.SpawnMany( list, pos + Vector( 0, 0, 8 ) )
		return n
	end

	local function dropYield( ent )
		local id = Breakables.Yield( ent )
		if id then Breakables.Drop( id, ent:WorldSpaceCenter() ) end
	end

	function Breakables.BurstDoor( door, force )
		if door.GR_Burst then return end
		door.GR_Burst = true
		door.GR_BreakHP = 0
		door:EmitSound( "physics/wood/wood_crate_break" .. math.random( 1, 5 ) .. ".wav" )
		door:SetNotSolid( true )
		door:SetNoDraw( true )
		door:SetNW2Float( "GR_BreakFrac", 0 )
		local mdl = door:GetModel() or ""
		if mdl ~= "" and mdl:sub( 1, 1 ) ~= "*" then
			local gib = ents.Create( "prop_physics" )
			if IsValid( gib ) then
				gib:SetModel( mdl )
				gib:SetSkin( door:GetSkin() )
				gib:SetPos( door:GetPos() )
				gib:SetAngles( door:GetAngles() )
				gib:Spawn()
				local phys = gib:GetPhysicsObject()
				if IsValid( phys ) then phys:SetVelocity( ( force or vector_origin ) * 300 ) end
			end
		end
		hook.Run( "GR_DoorBurst", door )
	end

	function Breakables.BreakProp( ent, force )
		if ent.GR_Broken then return end
		ent.GR_Broken = true
		if ent:IsOnFire() then ent:Extinguish() end
		dropYield( ent )
		hook.Run( "GR_PropBreak", ent )
		ent:GibBreakServer( force or vector_origin )
		ent:Remove()
	end

	function Breakables.BrushBroken( ent )
		if ent.GR_Broken then return end
		ent.GR_Broken = true
		dropYield( ent )
	end

	local DOOR_DMG = bit.bor( DMG_CLUB, DMG_BLAST )

	hook.Add( "EntityTakeDamage", "gr_breakables", function( ent, dmg )
		if isDoor( ent ) then
			if ent.GR_Burst or bit.band( dmg:GetDamageType(), DOOR_DMG ) == 0 then return end
			ent.GR_BreakHP = Breakables.Health( ent ) - dmg:GetDamage()
			ent:SetNW2Float( "GR_BreakFrac", math.max( ent.GR_BreakHP, 0 ) / Breakables.DOOR_HEALTH )
			if ent.GR_BreakHP <= 0 then Breakables.BurstDoor( ent, dmg:GetDamageForce():GetNormalized() ) end
			return
		end
		if isProp( ent ) then
			if ent.GR_Broken then return true end
			local amt = dmg:GetDamage() * ( dmg:IsBulletDamage() and 0.8 or 1.25 )
			ent.GR_BreakHP = Breakables.Health( ent ) - amt
			local frac = math.Clamp( ent.GR_BreakHP / Breakables.Max( ent ), 0, 1 )
			local c = math.floor( 100 + 155 * frac )
			ent:SetColor( Color( c, c, c, ent:GetColor().a ) )
			ent:SetNW2Float( "GR_BreakFrac", frac )
			if ent.GR_BreakHP <= 0 then Breakables.BreakProp( ent, dmg:GetDamageForce() ) end
			return true -- our pool, not the engine's: no engine break, no ignition
		end
		-- A func_breakable keeps the engine's own health; when it breaks it is removed.
		if ent:GetClass() == "func_breakable" and not ent.GR_YieldWatch and Breakables.Yield( ent ) then
			ent.GR_YieldWatch = true
			ent:CallOnRemove( "gr_breakables", function( e )
				if e:Health() <= 0 then Breakables.BrushBroken( e ) end
			end )
		end
	end )
	return
end

-- Cross-texts (cl_crosshair.lua): the condition of a damaged door or prop.
local function condition( f )
	if f <= 0 then return "Smashed" elseif f < 0.25 then return "Nearly broken" elseif f < 0.6 then return "Battered" end
	return "Scuffed"
end

hook.Add( "GR_CrossTexts", "gr_breakables", function( ent, me, ct )
	if not isDoor( ent ) and not isProp( ent ) then return end
	local f = ent:GetNW2Float( "GR_BreakFrac", 1 )
	if f >= 1 then return end
	table.insert( ct, { text = condition( f ), bar = math.Clamp( f, 0, 1 ) } )
end )
