-- Munitionizers (sh_munitionizer.lua): only proles build them, kits restock, a kit is one clip of
-- the gun's Redux ammo type up to three clips, the price by who you are, bones to the builder, scrap
-- when shot down, and no drift in the economy.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:tmun_%'" )

	local function bot( name, fate )
		local b = player.CreateNextBot( "tmun_" .. name )
		b:SetRank( RANK_FRIEND )
		b:SetStemCells( 10 )
		T.Check( Fates.Take( b, fate ), name .. " takes " .. fate )
		return b
	end
	local function setBones( b, n )
		Econ.Transfer( b, Econ.TREASURY, b:GetBones(), "test" )
		Econ.Transfer( Econ.TREASURY, b, n, "test" )
	end

	T.Wait( 0.2 )
	local p = bot( "prole", "prole" )
	local p2 = bot( "prole2", "prole" )
	local san = bot( "san", "sanitar" )
	T.Wait( 0.5 )

	-- Building ---------------------------------------------------------------------------------

	local spot = util.TraceLine( { start = p:EyePos(), endpos = p:EyePos() + Vector( 0, 60, -100 ), filter = p } ).HitPos
	Inventory.Add( san, "permit_tool", 1, true )
	setBones( san, 100 )
	T.Check( not Build.Place( san, "munitionizer", san:EyePos() + Vector( 0, 0, -60 ) ), "a sanitar can't build one, even with a permit" )
	setBones( p, 100 )
	local m = Build.Place( p, "munitionizer", spot )
	T.Check( IsValid( m ) and m:GetClass() == "munitionizer", "a prole builds a munitionizer" )
	if not IsValid( m ) then return end
	T.Equal( p:GetBones(), 100 - Build.KINDS.munitionizer.cost, "it cost bones" )
	T.Equal( m:GetModel(), "models/props_wasteland/gaspump001a.mdl", "the original's gas pump" )
	T.Equal( m:GetDeployer(), p, "the builder is its deployer" )
	T.Equal( m:GetKits(), 0, "it starts empty" )
	T.Equal( m:GetIntegrity(), 200, "with 200 integrity" )

	-- Restock ----------------------------------------------------------------------------------

	T.WaitUntil( function() return m:GetKits() == 1 end, 8, "the first kit comes after 5 s" )
	m.GR_NextKit = 0
	T.Wait( 1.2 )
	T.Equal( m:GetKits(), 2, "then one every 45 s" )
	m:SetKits( 15 )
	m.GR_NextKit = 0
	T.Wait( 1.2 )
	T.Equal( m:GetKits(), 15, "never more than 15" )

	-- Buying -----------------------------------------------------------------------------------

	T.Check( not Munitionizer.Use( p2, m ), "no gun, no ammo" )
	p2:Give( "weapon_gr_pacifier" )
	p2:SelectWeapon( "weapon_gr_pacifier" )
	p2:SetAmmo( 0, "cc_pistol" )
	T.Wait( 0.2 )
	setBones( p2, 0 )
	T.Check( not Munitionizer.Use( p2, m ), "no bones, no ammo" )
	setBones( p2, 100 )
	setBones( p, 0 )
	T.Check( Munitionizer.Use( p2, m ), "a clip is bought" )
	T.Equal( p2:GetAmmoCount( "cc_pistol" ), 15, "one clip of cc_pistol" )
	T.Equal( p2:GetBones(), 75, "for 25 bones" )
	T.Equal( p:GetBones(), 25, "paid to the builder" )
	T.Equal( m:GetKits(), 14, "one kit used" )
	p2:SetAmmo( 40, "cc_pistol" )
	T.Check( Munitionizer.Use( p2, m ), "topping up" )
	T.Equal( p2:GetAmmoCount( "cc_pistol" ), 45, "never past three clips" )
	T.Check( not Munitionizer.Use( p2, m ), "full is refused" )
	T.Equal( m:GetKits(), 13, "refusals use no kit" )

	san:Give( "weapon_gr_pacifier" )
	san:SelectWeapon( "weapon_gr_pacifier" )
	san:SetAmmo( 0, "cc_pistol" )
	T.Wait( 0.2 )
	T.Equal( Munitionizer.Price( san, m ), 15, "police pay 15" )
	T.Check( Munitionizer.Use( san, m ) and san:GetBones() == 85, "and are charged 15" )
	p:Give( "weapon_gr_pacifier" )
	p:SelectWeapon( "weapon_gr_pacifier" )
	p:SetAmmo( 0, "cc_pistol" )
	T.Wait( 0.2 )
	local treasury = Econ.Treasury()
	T.Check( Munitionizer.Use( p, m ), "the builder buys" )
	T.Equal( p:GetBones(), 25 + 25 + 15 - 10, "for 10 (after earning 65 from the others)" )
	T.Equal( Econ.Treasury(), treasury + 10, "paid to the treasury" )
	m:SetKits( 0 )
	p:SetAmmo( 0, "cc_pistol" )
	T.Check( not Munitionizer.Use( p, m ), "empty is refused" )

	-- Breaking ---------------------------------------------------------------------------------

	local dmg = DamageInfo()
	dmg:SetDamage( 250 )
	dmg:SetDamageType( DMG_BULLET )
	dmg:SetAttacker( p2 )
	dmg:SetDamagePosition( m:GetPos() )
	m:TakeDamageInfo( dmg )
	T.Wait( 0.2 )
	T.Check( not IsValid( m ), "200 damage breaks it" )
	T.Equal( ( Econ.Audit() ), 0, "no drift" )
end
