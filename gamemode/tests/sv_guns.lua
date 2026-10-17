-- The original's guns (sh_guns.lua): every gun's stats against weapon_cc_<name>, the ammo types,
-- the station's tiers and two clips per purchase, the sanitar's tooth, the Kaiser's novoluger with two
-- clips, the Bullets item, firing and reloading (magazine and shell-by-shell with the pump).
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:tguns_%'" )

	-- The original's values: clip, ammo, damage, force, accuracy, delay, recoil, pellets, fire sound,
	-- reload sound, movement multiplier, reload time.
	local ORIGINAL = {
		pacifier = { 15, "cc_pistol", 20, 1, 0.05, 0.3, 2, 1, "tekka/weapons/weapon_m92.wav", "weapons/glock/glock_clipout.wav", 0.8, 2.7429 },
		obrez = { 5, "cc_sniper", 65, 5, 0.1, 1.25, 8, 1, "tekka/weapons/weapon_sbr.wav", "Weapon_357.Reload", 0.65, 2.9333 },
		brutality = { 18, "cc_pistol", 15, 1, 0.05, 0.2, 1, 1, "tekka/weapons/weapon_pistolcrack.wav", "weapons/glock/glock_clipout.wav", 0.8, 2.7429 },
		coach = { 2, "cc_shotgun", 12, 4, 0.15, 0.35, 4, 8, "tekka/weapons/weapon_shotgun2.wav", "Weapon_357.Reload", 0.5, 2.0 },
		bastard = { 32, "cc_smg", 12, 2, 0.075, 0.09, 0.5, 1, "tekka/weapons/weapon_smg.wav", "weapons/ump45/ump45_boltslap.wav", 0.75, 2.381 },
		livermann = { 6, "cc_sniper", 55, 4, 0.01, 1.25, 6, 1, "placenta/weapons/enforcer.wav", "weapons/357/357_reload3.wav", 0.5, 2.9333 },
		candlewood = { 4, "cc_shotgun", 8, 2, 0.095, 0.85, 5, 11, "tekka/weapons/weapon_shotgun.wav", "Weapon_Shotgun.Reload", 0.5 },
		brainpaster = { 8, "cc_pistol", 35, 1, 0.07, 0.3, 2, 1, "tekka/weapons/weapon_canon.wav", "weapons/glock/glock_clipout.wav", 0.8, 2.7429 },
		trista = { 64, "cc_smg", 12, 2, 0.08, 0.08, 0.7, 1, "tekka/weapons/weapon_smg2.wav", "weapons/ump45/ump45_boltslap.wav", 0.65, 2.7838 },
		einhesna = { 32, "cc_smg", 15, 2, 0.09, 0.10, 1.3, 1, "tekka/weapons/weapon_p226.wav", "weapons/ump45/ump45_boltslap.wav", 0.75, 3.0789 },
		kaptivist = { 4, "cc_shotgun", 6, 1, 0.2, 1.8, 20, 20, "weapons/shotgun/shotgun_dbl_fire.wav", "Weapon_Shotgun.Reload", 0.6 },
		bodyguard = { 5, "cc_357", 40, 3, 0.05, 0.75, 2, 1, "tekka/weapons/weapon_1911.wav", "weapons/smg1/switch_burst.wav", 0.8, 3.6667 },
		rattler = { 32, "cc_smg", 14, 2, 0.07, 0.09, 0.45, 1, "tekka/weapons/weapon_smg.wav", "weapons/ump45/ump45_boltslap.wav", 0.75, 2.9762 },
		painkiller = { 6, "cc_357", 55, 3, 0.03, 0.75, 8, 1, "tekka/weapons/weapon_western.wav", "weapons/357/357_spin1.wav", 0.8, 3.6667 },
		vengeance = { 100, "cc_sniper", 18, 5, 0.08, 0.06, 0.55, 1, "tekka/weapons/weapon_mgthud.wav", "Weapon_357.Reload", 0.75, 5.7333 },
		trooper = { 18, "cc_rifle", 35, 2, 0.05, 0.3, 1.5, 1, "tekka/weapons/weapon_m4.wav", "weapons/ak47/ak47_boltpull.wav", 0.5, 2.9762 },
		novoluger = { 8, "cc_pistol", 30, 1, 0.03, 0.2, 1, 1, "tekka/weapons/weapon_pistolcrack.wav", "weapons/glock/glock_clipout.wav", 0.75, 1.4333 },
	}

	-- Stats ------------------------------------------------------------------------------------

	local n = 0
	for id, o in pairs( ORIGINAL ) do
		n = n + 1
		local w = weapons.Get( "weapon_gr_" .. id )
		T.Check( w ~= nil and w.Firearm, id .. ": the weapon exists" )
		if w then
			local p = w.Primary
			local got = { p.ClipSize, p.Ammo, p.Damage, p.Force, p.Accuracy, p.Delay, p.Recoil, p.NumBullets or 1,
				p.Sound, p.ReloadSound, w.MovementMult, w.ReloadTime }
			local same = true
			for i = 1, 12 do
				if got[ i ] ~= o[ i ] then
					same = false
					T.Check( false, string.format( "%s: field %d is %s, the original has %s", id, i, tostring( got[ i ] ), tostring( o[ i ] ) ) )
				end
			end
			if same then T.Check( true, id .. ": stats, sounds and reload time match the original" ) end
			T.Equal( p.DefaultClip, p.ClipSize, id .. ": spawns with a full clip" )
			T.Check( game.GetAmmoID( p.Ammo ) > 0, id .. ": its ammo type " .. p.Ammo .. " exists" )
			local def = Items.Get( id )
			T.Check( def ~= nil and def.Weapon == "weapon_gr_" .. id, id .. ": the item gives the weapon" )
		end
	end
	T.Equal( n, 17, "17 guns" )
	T.Check( weapons.Get( "weapon_gr_obrez" ).Primary.Automatic == false and weapons.Get( "weapon_gr_coach" ).Primary.Automatic == false
		and weapons.Get( "weapon_gr_bastard" ).Primary.Automatic, "only the obrez and the coach are semi-automatic" )
	T.Check( weapons.Get( "weapon_gr_candlewood" ).ShellReload and weapons.Get( "weapon_gr_kaptivist" ).ShellReload, "the pump shotguns load by the shell" )
	T.Check( weapons.Get( "weapon_gr_coach" ).IgnoreMovementInacc and weapons.Get( "weapon_gr_coach" ).MeleeHeavy, "the coach ignores movement spread and shoves heavy" )
	T.Equal( weapons.Get( "weapon_gr_livermann" ).AimFOV, 60, "the livermann aims at 60 FOV" )
	T.Equal( weapons.Get( "weapon_gr_trooper" ).Bodygroup, 6, "the trooper's bodygroup" )
	T.Equal( weapons.Get( "weapon_gr_obrez" ).UnholsterPitch, 80, "the obrez's unholster pitch" )
	T.Check( Items.Get( "shotgun" ) == nil and Items.Get( "smg" ) == nil, "the HL2 placeholder guns are gone" )

	-- Station and loadouts -----------------------------------------------------------------------

	local tiers = {}
	for _, o in ipairs( Police.OFFERS ) do tiers[ o.item ] = o.teeth end
	T.Check( tiers.pacifier == 1 and tiers.obrez == 1 and tiers.brutality == 1 and tiers.coach == 1, "tier one costs a tooth" )
	T.Check( tiers.bastard == 2 and tiers.livermann == 2 and tiers.candlewood == 2, "tier two costs two" )
	T.Check( tiers.brainpaster == 4 and tiers.trista == 4 and tiers.einhesna == 4 and tiers.kaptivist == 4, "tier three costs four" )
	T.Equal( #Police.OFFERS, 11, "eleven guns on sale" )

	local s = player.CreateNextBot( "tguns_san" )
	s:SetRank( RANK_FRIEND )
	s:SetStemCells( 10 )
	T.Wait( 0.2 )
	T.Check( Fates.Take( s, "sanitar" ), "a bot takes sanitar" )
	T.Equal( s:GetTeeth(), 1, "the sanitar starts with one tooth" )
	T.Check( Inventory.Count( s, "baton" ) == 1 and Inventory.Count( s, "scope" ) == 1, "and the baton and scope" )
	T.Check( Police.Buy( s, "pacifier" ), "one tooth buys a pacifier" )
	T.Check( s:HasWeapon( "weapon_gr_pacifier" ), "the pacifier is in hand" )
	T.Equal( s:GetAmmoCount( "cc_pistol" ), 30, "with two clips of reserve" )
	T.Check( not Police.Buy( s, "kaptivist" ), "no teeth for a kaptivist" )

	local k = player.CreateNextBot( "tguns_kaiser" )
	k:SetRank( RANK_KAISER )
	k:SetStemCells( 10 )
	T.Wait( 0.2 )
	T.Check( Fates.Take( k, "kaiser" ), "a bot takes kaiser" )
	T.Check( k:HasWeapon( "weapon_gr_novoluger" ), "the Kaiser holds the novoluger" )
	T.Equal( k:GetAmmoCount( "cc_pistol" ), 16, "with two clips of reserve" )
	T.Equal( k:GetWeapon( "weapon_gr_novoluger" ):Clip1(), 8, "and a full clip" )

	-- Firing and reloading -----------------------------------------------------------------------

	k:SelectWeapon( "weapon_gr_novoluger" )
	T.Wait( 0.6 )
	Weapons.SetHolstered( k, false )
	T.Wait( 1.6 )
	local wep = k:GetActiveWeapon()
	T.Check( IsValid( wep ) and wep:GetClass() == "weapon_gr_novoluger", "the novoluger is out" )
	wep:SetNextPrimaryFire( 0 )
	wep:PrimaryAttack()
	T.Equal( wep:Clip1(), 7, "a shot spends a round" )
	T.Check( math.abs( wep:GetNextPrimaryFire() - CurTime() - 0.2 ) < 0.05, "the next shot waits 0.2 s" )
	wep:SetNextPrimaryFire( 0 )
	wep:Reload()
	T.Check( wep:GetReloading(), "reloading" )
	T.Check( math.abs( wep:GetReloadEnd() - CurTime() - 1.4333 ) < 0.05, "for the reload sequence's 1.43 s" )
	T.Wait( 1.6 )
	T.Equal( wep:Clip1(), 8, "the clip is full again" )
	T.Equal( k:GetAmmoCount( "cc_pistol" ), 15, "from the reserve" )

	Inventory.Add( k, "candlewood", 1, true )
	k:GiveAmmo( 8, "cc_shotgun", true )
	k:SelectWeapon( "weapon_gr_candlewood" )
	T.Wait( 0.6 )
	Weapons.SetHolstered( k, false )
	T.Wait( 0.6 )
	local sg = k:GetActiveWeapon()
	T.Check( IsValid( sg ) and sg:GetClass() == "weapon_gr_candlewood", "the candlewood is out" )
	sg:SetNextPrimaryFire( 0 )
	sg:PrimaryAttack()
	T.Check( sg:GetNeedPump(), "a shot needs a pump" )
	T.Check( sg:GetNextPrimaryFire() - CurTime() < 0.5, "the pump comes after the shot's sequence less 0.7 s" )
	sg:Reload()
	T.Check( not sg:GetReloading(), "no reloading before the pump" )
	T.WaitUntil( function() return not sg:GetNeedPump() end, 1, "the gun pumps" )
	T.Check( sg:GetNextPrimaryFire() - CurTime() > 0.8, "the pump takes the shot's sequence again" )
	T.Wait( 1.2 )
	sg:SetClip1( 1 )
	sg:Reload()
	T.Check( sg:GetReloading(), "shell reload starts" )
	T.Wait( 0.5 + 0.65 )
	T.Equal( sg:Clip1(), 3, "a shell at a time (two so far)" )
	T.WaitUntil( function() return not sg:GetReloading() end, 3, "the reload finishes" )
	T.Equal( sg:Clip1(), 4, "the tube is full" )
	T.Equal( k:GetAmmoCount( "cc_shotgun" ), 5, "three shells left the reserve" )

	-- Bullets ------------------------------------------------------------------------------------

	k:SetAmmo( 0, "cc_shotgun" )
	Inventory.Add( k, "pickup_ammo", 2, true )
	T.Check( Inventory.Use( k, "pickup_ammo" ), "loading bullets" )
	T.Equal( k:GetAmmoCount( "cc_shotgun" ), 12, "gives three clips" )
	Inventory.Use( k, "pickup_ammo" )
	T.Equal( k:GetAmmoCount( "cc_shotgun" ), 12, "but never more than three clips held" )
	T.Equal( Inventory.Count( k, "pickup_ammo" ), 0, "both were used up" )
end
