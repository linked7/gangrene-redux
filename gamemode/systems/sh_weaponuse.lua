-- Who may hold and use weapons, and how: the original's rules from its sh_weapons.lua, sv_player.lua,
-- sh_items.lua and weapon_cc_base (parity notes in docs). Holstering itself is sh_weapons.lua.
--
--   Jamming     a fate with GunJam = true rolls each gun's JamChance (percent) on every shot: the gun
--               jams with a clank and won't fire (a dry click) until reloaded, even on a full clip,
--               or until switched to. GunJammed is a player field, as in the original.
--   Switching   passed out, you can't switch off your hands.
--   Pickups     the Half-Life 2 weapons lying in maps can't be picked up.
--   Re-equip    a weapon class a player has held before comes back empty (the original's
--               InfiniteAmmoFix, kept per connection as there) unless it sets NoAmmoFix.
--
-- Elsewhere: slaves carry weapon items without getting the weapon (NoItemWeapons, sh_inventory.lua);
-- undroppable guns (Droppable = false, sh_guns.lua); Bullets load on pickup (sh_guns.lua).
State.Field( "GunJammed", "Bool", 0, State.OWNER, false )

Weapons.JAM_SOUND = "physics/metal/metal_sheet_impact_bullet1.wav"
Weapons.JAMMED_SOUND = "weapons/smg1/switch_burst.wav"
Weapons.BANNED_PICKUPS = {
	weapon_crowbar = true, weapon_stunstick = true, weapon_pistol = true, weapon_smg1 = true, weapon_ar2 = true,
	weapon_shotgun = true, weapon_crossbow = true, weapon_357 = true, weapon_rpg = true, weapon_annabelle = true,
}

-- Called by weapon_gr_base before a shot of a gun with JamChance. True: no shot this time.
function Weapons.TryJam( ply, wep )
	if not IsValid( ply ) then return false end
	if SERVER and not ply:GetGunJammed() and ply:FateHas( "GunJam" ) and math.random( 1, 100 ) <= wep.JamChance then
		ply:SetGunJammed( true )
		ply:EmitSound( Weapons.JAM_SOUND )
		return true
	end
	if ply:GetGunJammed() then
		if SERVER then wep:EmitSound( Weapons.JAMMED_SOUND ) end
		return true
	end
	return false
end

hook.Add( "PlayerSwitchWeapon", "gr_weaponuse", function( ply, old, new )
	if not IsValid( new ) then return end
	if ply:GetPassedOut() and new:GetClass() ~= Weapons.HANDS then return true end
	if SERVER and new.JamChance and ply:GetGunJammed() then ply:SetGunJammed( false ) end
end )

if CLIENT then return end

hook.Add( "PlayerCanPickupWeapon", "gr_weaponuse", function( ply, wep )
	if Weapons.BANNED_PICKUPS[ wep:GetClass() ] then return false end
end )

hook.Add( "WeaponEquip", "gr_weaponuse", function( wep, ply )
	local class = wep:GetClass()
	if not string.StartWith( class, "weapon_gr_" ) or wep.NoAmmoFix then return end
	ply.GR_PickedWeapons = ply.GR_PickedWeapons or {}
	if ply.GR_PickedWeapons[ class ] then
		wep:SetClip1( 0 )
	else
		ply.GR_PickedWeapons[ class ] = true
	end
end )
