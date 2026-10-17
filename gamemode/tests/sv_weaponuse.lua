-- Weapon usage parity (sh_weaponuse.lua and friends): jamming, the B toggle's limits and callbacks,
-- banned pickups, re-equipped guns coming back empty, slaves and weapon items, the undroppable
-- vengeance, Bullets loading on pickup, and no switching off your hands while passed out.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:twuse_%'" )

	T.Equal( weapons.Get( "weapon_gr_obrez" ).JamChance, 10, "the obrez jams one shot in ten for a GunJam fate" )
	T.Check( Weapons.BANNED_PICKUPS.weapon_smg1 and Weapons.BANNED_PICKUPS.weapon_annabelle, "HL2 guns are banned pickups" )
	T.Equal( Items.Get( "vengeance" ).Droppable, false, "the vengeance can't be dropped" )
	T.Check( string.find( Items.Get( "vengeance" ).Description, "It is stuck with you forever.", 1, true ) ~= nil, "and says so" )
	T.Check( Fates.Get( "slave" ).NoItemWeapons and not Fates.Get( "prole" ).NoItemWeapons, "only slaves get no item weapons" )

	local k = player.CreateNextBot( "twuse_kaiser" )
	k:SetRank( RANK_KAISER )
	k:SetStemCells( 10 )
	T.Wait( 0.2 )
	T.Check( Fates.Take( k, "kaiser" ), "a bot takes kaiser" )
	local smg = ents.Create( "weapon_smg1" )
	T.Check( hook.Run( "PlayerCanPickupWeapon", k, smg ) == false, "the bot can't pick up an HL2 smg" )
	smg:Remove()

	-- Jamming -----------------------------------------------------------------------------------
	Inventory.Add( k, "obrez", 1, true )
	k:SelectWeapon( "weapon_gr_obrez" )
	T.Wait( 0.6 )
	Weapons.SetHolstered( k, false )
	T.Wait( 1.6 )
	local wep = k:GetActiveWeapon()
	T.Check( IsValid( wep ) and wep:GetClass() == "weapon_gr_obrez", "the obrez is out" )
	local kaiser = Fates.Get( "kaiser" )
	kaiser.GunJam = true -- no Redux fate jams yet (the original's lumpenprole and skinshape did)
	wep.JamChance = 100
	local clip = wep:Clip1()
	wep:SetNextPrimaryFire( 0 )
	wep:PrimaryAttack()
	T.Check( k:GetGunJammed(), "a GunJam fate's gun jams" )
	T.Equal( wep:Clip1(), clip, "and the jam spends no round" )
	wep:SetNextPrimaryFire( 0 )
	wep:PrimaryAttack()
	T.Equal( wep:Clip1(), clip, "a jammed gun won't fire" )
	k:GiveAmmo( 10, "cc_sniper", true )
	kaiser.GunJam = nil
	wep:Reload()
	T.Check( not k:GetGunJammed() and wep:GetReloading(), "a reload on a full clip clears the jam" )
	T.WaitUntil( function() return not wep:GetReloading() end, 4, "the reload finishes" )
	k:SelectWeapon( "weapon_gr_novoluger" )
	T.Wait( 0.3 )
	k:SetGunJammed( true )
	k:SelectWeapon( "weapon_gr_obrez" )
	T.Wait( 0.3 )
	T.Check( not k:GetGunJammed(), "switching to a jamming gun clears the jam" )
	k:SelectWeapon( "weapon_gr_novoluger" )
	T.Wait( 0.3 )

	-- Holster toggle ------------------------------------------------------------------------------
	local cb = {}
	local nov = k:GetActiveWeapon()
	nov.OnUnholster = function() cb.out = true end
	nov.OnHolster = function() cb.away = true end
	Weapons.SetHolstered( k, true )
	Weapons.ToggleHolster( k )
	Weapons.ToggleHolster( k )
	T.Check( cb.out and cb.away, "B calls the weapon's OnUnholster and OnHolster" )

	-- Re-equip: the second time a class is held, it comes back empty -------------------------------
	Inventory.Remove( k, "obrez", 1 )
	T.Check( not k:HasWeapon( "weapon_gr_obrez" ), "the obrez left with its item" )
	Inventory.Add( k, "obrez", 1, true )
	T.Equal( IsValid( k:GetWeapon( "weapon_gr_obrez" ) ) and k:GetWeapon( "weapon_gr_obrez" ):Clip1(), 0, "an obrez held before comes back empty" )

	-- Undroppable -----------------------------------------------------------------------------------
	Inventory.Add( k, "vengeance", 1, true )
	T.Check( Inventory.Drop( k, "vengeance", 1 ) == nil and Inventory.Count( k, "vengeance" ) == 1, "the vengeance won't drop" )
	Inventory.Remove( k, "vengeance", 1 )
	Inventory.Remove( k, "obrez", 1 )

	-- Bullets load on pickup --------------------------------------------------------------------------
	k:SelectWeapon( "weapon_gr_novoluger" )
	T.Wait( 0.3 )
	k:SetAmmo( 0, "cc_pistol" )
	local b = Items.Spawn( "pickup_ammo", 2, k:GetPos() + Vector( 0, 0, 40 ) )
	T.Equal( Inventory.PickUp( k, b ), 1, "picking up bullets with a gun in hand" )
	T.Equal( k:GetAmmoCount( "cc_pistol" ), 24, "loads three clips" )
	T.Equal( Inventory.Count( k, "pickup_ammo" ), 0, "without carrying them" )
	T.Equal( b:GetCount(), 1, "one off the stack" )
	T.Equal( Inventory.PickUp( k, b ), 1, "full up, the rest are carried" )
	T.Equal( Inventory.Count( k, "pickup_ammo" ), 1, "into the inventory" )

	-- Passed out: no switching off the hands ----------------------------------------------------------
	k:SelectWeapon( Weapons.HANDS )
	T.Wait( 0.3 )
	k:SetPassedOut( true )
	T.Check( hook.Run( "PlayerSwitchWeapon", k, k:GetActiveWeapon(), k:GetWeapon( "weapon_gr_novoluger" ) ) == true, "passed out, the switch is refused" )
	k:SetPassedOut( false )

	-- Slaves carry weapon items but don't get the weapon ------------------------------------------------
	local s = player.CreateNextBot( "twuse_slave" )
	T.Wait( 0.2 )
	T.Check( Fates.Take( s, "slave" ), "a bot takes slave" )
	Inventory.Add( s, "pacifier", 1, true )
	T.Check( Inventory.Count( s, "pacifier" ) == 1 and not s:HasWeapon( "weapon_gr_pacifier" ), "a slave carries a pacifier without holding it" )
end
