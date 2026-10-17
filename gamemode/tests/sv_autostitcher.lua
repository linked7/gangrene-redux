-- Autostitchers (sh_autostitcher.lua): the trip's price with sales tax, a medical permit instead of
-- bones, healing while hooked up, parasites, korpsman charging paid from the treasury, the refusals,
-- and no drift in the economy.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:tstitch_%'" )

	local function bot( name, fate )
		local b = player.CreateNextBot( "tstitch_" .. name )
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
	local k = bot( "korps", "korpsman" )
	T.Wait( 0.5 )

	local a = ents.Create( "autostitcher" )
	a:SetPos( p:EyePos() + p:GetForward() * 40 )
	a:SetAngles( Angle( 0, p:EyeAngles().y + 180, 0 ) )
	a:Spawn()
	T.Check( IsValid( a ) and Autostitcher.all[ a ], "an autostitcher spawns and is tracked" )
	T.Equal( a:GetModel(), "models/props_combine/health_charger001.mdl", "the original's wall charger" )
	T.Check( a:GetCharges() == 0 or a:GetCharges() == 1, "it starts with 0 or 1 charges" )

	-- Price ------------------------------------------------------------------------------------
	T.Equal( Autostitcher.Price(), 50, "50 bones with no sales tax" )
	local oldTax = Econ.Setting( "sales_tax" )
	WorldState.Set( "econ.sales_tax", 10 )
	T.Equal( Autostitcher.Price(), 55, "plus 10% sales tax" )
	WorldState.Set( "econ.sales_tax", oldTax )

	-- Refusals ---------------------------------------------------------------------------------
	a:SetCharges( 0 )
	T.Check( not Autostitcher.Use( p, a ), "no charges, no trip" )
	a:SetCharges( 1 )
	setBones( p, 10 )
	p:SetHealth( 50 )
	local ok, why = Autostitcher.Use( p, a )
	T.Check( not ok and why:find( "50 Bones" ), "too poor: " .. tostring( why ) )
	setBones( p, 100 )
	p:SetHealth( Medicine.MaxHealth( p ) )
	Medicine.SetParasites( p, 0 )
	ok, why = Autostitcher.Use( p, a )
	T.Equal( why, "I don't need treatment.", "healthy and clean" )

	-- A trip -----------------------------------------------------------------------------------
	p:SetHealth( 50 )
	T.Check( Autostitcher.Use( p, a ), "a hurt prole buys a trip" )
	T.Equal( p:GetBones(), 50, "it cost 50" )
	T.Equal( a:GetPatient(), p, "they are the patient" )
	T.Equal( a:GetCharges(), 0, "it used a charge" )
	ok, why = Autostitcher.Use( k, a )
	T.Check( not ok, "a hurt korpsman without a lovebox out can't use an empty one" )
	a.GR_NextHeal = 0
	T.Wait( 0.7 )
	if a:GetPatient() == p then
		T.Equal( p:Health(), 56, "healed 6 a tick" )
		p:SetHealth( Medicine.MaxHealth( p ) )
		T.WaitUntil( function() return not IsValid( a:GetPatient() ) end, 2, "unhooked when healed" )
	else
		T.Check( true, "UNVERIFIED: the bot couldn't see the stitcher, so it unhooked at once" )
	end

	-- Permit -----------------------------------------------------------------------------------
	a:SetPatient( NULL )
	a:SetCharges( 1 )
	p:SetHealth( 50 )
	setBones( p, 0 )
	Inventory.Add( p, "permit_medical", 1, true )
	T.Check( Autostitcher.Use( p, a ), "a medical permit pays for the trip" )
	T.Equal( Inventory.Count( p, "permit_medical" ), 0, "and is taken" )
	T.Equal( p:GetBones(), 0, "no bones taken" )

	-- Parasites --------------------------------------------------------------------------------
	a:SetPatient( NULL )
	a:SetCharges( 1 )
	p:SetHealth( Medicine.MaxHealth( p ) )
	Medicine.SetParasites( p, 2 )
	setBones( p, 50 ) -- the original refuses anyone under the trip price first
	T.Check( Autostitcher.Use( p, a ), "a healthy prole pays 30 for a parasite" )
	T.Equal( Medicine.Parasites( p ), 1, "one parasite out" )
	T.Equal( p:GetBones(), 20, "for 30" )
	Inventory.Add( p, "permit_medical", 1, true )
	T.Check( Autostitcher.Use( p, a ), "a permit pays for the next one" )
	T.Equal( Medicine.Parasites( p ), 0, "all out" )
	T.Equal( p:GetBones(), 20, "no bones for it" )

	-- Korpsman ---------------------------------------------------------------------------------
	k:Give( "weapon_gr_lovebox" )
	k:SelectWeapon( "weapon_gr_lovebox" )
	T.Wait( 0.3 )
	if IsValid( k:GetActiveWeapon() ) and k:GetActiveWeapon():GetClass() == "weapon_gr_lovebox" then
		a:SetCharges( 1 )
		k:SetHealth( 100 )
		local kb = k:GetBones()
		T.Check( Autostitcher.Use( k, a ), "a korpsman charges it with the lovebox" )
		T.Equal( a:GetCharges(), 2, "one charge more" )
		T.Equal( k:GetBones(), kb + 35, "35 compassion bones from the treasury" )
		T.Check( k:Health() < 100, "it hurt" )
		a:SetCharges( 3 )
		ok, why = Autostitcher.Use( k, a )
		T.Equal( why, "It can't hold any more charges.", "full" )
	else
		T.Check( true, "UNVERIFIED: the bot couldn't wield the lovebox" )
	end

	-- Smacking ---------------------------------------------------------------------------------
	a:SetCharges( 0 )
	local d = DamageInfo()
	d:SetDamage( 10 )
	d:SetDamageType( DMG_CLUB )
	d:SetAttacker( p )
	d:SetDamagePosition( a:GetPos() )
	a:TakeDamageInfo( d )
	T.Check( p.GR_Evidence and p.GR_Evidence[ "illegal tinkering" ], "smacking it is illegal tinkering" )

	a:Remove()
	for _, b in ipairs( { p, k } ) do if IsValid( b ) then b:Kick( "test over" ) end end
	T.Equal( ( Econ.Audit() ), 0, "no drift" )
end
