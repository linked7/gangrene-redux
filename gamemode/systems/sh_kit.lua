-- Fate kits and aim (step 11.1), read from fate data so no code names a fate:
--
--   Kit = { "permit_tool", { "scrap", "scrap_pipe" } }   items handed out when a life starts; an entry
--                                                         that is a list gives one of them at random
--   AccuracyMulti = 1.25                                  scales every bullet's spread
--   RecoilMulti = 1.3                                     adds view kick per shot in proportion
--
-- Also defines the items those kits need: the permit tool (lets you Build, sh_build.lua) and scrap.
Kit = Kit or {}

Items.Define( "permit_tool", {
	Name = "Permit Tool",
	Description = "A stamp and a folding rule. Lets you build with the state's blessing (hold C, look at the ground).",
	Weight = 1,
	Model = "models/props_c17/tools_wrench01a.mdl",
	Tags = { Builds = true },
} )

Items.Define( "scrap_pipe", {
	Name = "Scrap Pipe",
	Description = "A length of rusted pipe.",
	Weight = 2,
	Model = "models/props_canal/mattpipe.mdl",
} )

Items.Define( "scrap_gear", {
	Name = "Scrap Gear",
	Description = "A cog off some dead machine.",
	Weight = 1,
	Model = "models/props_wasteland/gear02.mdl",
} )

Kit.RECOIL_KICK = 2 -- degrees of extra kick per shot for each 1.0 of RecoilMulti above 1

-- Scales a bullet's spread and kicks the shooter's view by their fate's aim multipliers.
-- Returns true if `data` was changed.
function Kit.ModifyBullets( ply, data )
	local acc = ply:FateHas( "AccuracyMulti" )
	local changed = false
	if isnumber( acc ) and acc ~= 1 and data.Spread then
		data.Spread = data.Spread * acc
		changed = true
	end
	local recoil = ply:FateHas( "RecoilMulti" )
	if SERVER and isnumber( recoil ) and recoil > 1 then
		local kick = Kit.RECOIL_KICK * ( recoil - 1 )
		ply:ViewPunch( Angle( -kick, math.Rand( -kick, kick ) * 0.5, 0 ) )
	end
	return changed
end

hook.Add( "EntityFireBullets", "gr_kit", function( ent, data )
	if not IsValid( ent ) or not ent:IsPlayer() then return end
	-- weapon_gr_base weapons apply AccuracyMulti and RecoilMulti themselves (sh_weapons.lua).
	local wep = ent:GetActiveWeapon()
	if IsValid( wep ) and wep.GR_Base then return end
	-- Only answer when changed: a returned value stops the hooks after this one.
	if Kit.ModifyBullets( ent, data ) then return true end
end )

if CLIENT then return end

-- The item ids a kit hands out this time (random picks resolved).
function Kit.Roll( kit )
	local out = {}
	for _, entry in ipairs( kit or {} ) do
		if istable( entry ) then
			if #entry > 0 then table.insert( out, entry[ math.random( #entry ) ] ) end
		else
			table.insert( out, entry )
		end
	end
	return out
end

-- A new life gets the kit; a revived (or risen) body keeps what it had instead.
hook.Add( "GR_FateEnter", "gr_kit", function( ply, f, reason )
	if Fates.SameLife( reason ) or not f.Kit then return end
	for _, id in ipairs( Kit.Roll( f.Kit ) ) do
		if not Inventory.Add( ply, id, 1, true ) then
			Log.Warn( "kit", "%s: could not give %s", f.id, tostring( id ) )
		elseif f.KitAmmo and Items.Get( id ).Weapon then
			Guns.GiveAmmo( ply, Items.Get( id ).Weapon, f.KitAmmo ) -- KitAmmo clips of reserve per gun
		end
	end
end )
