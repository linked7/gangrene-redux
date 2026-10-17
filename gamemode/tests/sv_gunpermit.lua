-- Gun permits (sh_gunpermit.lua): the Kaiser issues one free, in the holder's name; it makes holding
-- a gun legal; without one an armed citizen leaves evidence, or is wanted when police see it; police
-- and the Kaiser are exempt; a found permit is worthless; the Kaiser and police revoke it.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:tgp_%'" )

	local function bot( name, fate )
		local b = player.CreateNextBot( "tgp_" .. name )
		b:SetRank( RANK_FRIEND )
		b:SetStemCells( 10 )
		T.Check( Fates.Take( b, fate ), name .. " takes " .. fate )
		return b
	end

	T.Wait( 0.2 )
	local k = bot( "kaiser", "kaiser" )
	local p = bot( "prole", "prole" )
	local p2 = bot( "prole2", "prole" )
	local san = bot( "san", "sanitar" )
	T.Wait( 0.5 )

	local def = Items.Get( GunPermit.ITEM )
	T.Check( def and def.Model == "models/props_c17/paper01.mdl", "the permit is a paper" )
	T.Check( Net.Receivers.nKaiserPermit and Net.Receivers.nKaiserPermit.opts.range, "the Kaiser's receiver has a range" )

	-- Exempt fates
	T.Check( GunPermit.Legal( san ), "police need no permit" )
	T.Check( GunPermit.Legal( k ), "the Kaiser needs no permit" )
	T.Check( not GunPermit.Legal( p ), "a prole needs one" )

	-- Armed without a permit, out of police sight: evidence
	san:SetPos( p:GetPos() + Vector( 0, 0, -5000 ) )
	p:Give( "weapon_gr_pacifier" )
	T.Check( GunPermit.Firearm( p ) ~= nil, "the prole holds a gun" )
	local seen = Crime.SeenByPolice( p )
	GunPermit.Tick( p )
	if seen then
		T.Check( p:IsWanted(), "seen armed by police: wanted" )
	else
		T.Check( Crime.Evidence( p )[ GunPermit.CRIME ] ~= nil, "armed unseen: evidence" )
	end
	Crime.ClearWanted( p )
	Crime.TakeEvidence( p, GunPermit.CRIME )

	-- Issue
	T.Check( not GunPermit.Issue( p2, p ), "a prole can't issue one" )
	T.Check( not GunPermit.Issue( k, san ), "police get none" )
	T.Check( GunPermit.Issue( k, p ), "the Kaiser issues one" )
	T.Equal( p:GetGunPermit(), p:Nick(), "made out to the holder" )
	T.Equal( Inventory.Count( p, GunPermit.ITEM ), 1, "the paper is in their pockets" )
	T.Check( not GunPermit.Issue( k, p ), "one at a time" )
	T.Check( GunPermit.Legal( p ), "the holder is legal" )
	GunPermit.Tick( p )
	T.Check( not p:IsWanted() and not Crime.Evidence( p )[ GunPermit.CRIME ], "an armed holder commits no crime" )

	-- Someone else's paper is worthless
	Inventory.Add( p2, GunPermit.ITEM, 1, true )
	T.Check( not GunPermit.Legal( p2 ), "a found permit is not theirs" )
	Inventory.Remove( p2, GunPermit.ITEM, 1 )

	-- Dropping your own paper makes you illegal again
	Inventory.Remove( p, GunPermit.ITEM, 1 )
	T.Check( not GunPermit.Legal( p ), "a holder without the paper is not legal" )
	Inventory.Add( p, GunPermit.ITEM, 1, true )

	-- Police revoke through Interact
	san:SetPos( p:GetPos() + Vector( 40, 0, 0 ) )
	p2:SetPos( p:GetPos() + Vector( -40, 0, 0 ) )
	T.Wait( 0.1 )
	T.Check( not Interact.Run( p2, "revoke_permit", p ), "a prole can't revoke" )
	T.Check( Interact.Run( san, "revoke_permit", p ), "police revoke it" )
	T.Equal( p:GetGunPermit(), "", "the permit is gone" )
	T.Equal( Inventory.Count( p, GunPermit.ITEM ), 0, "the paper is torn up" )

	-- The Kaiser revokes too
	T.Check( GunPermit.Issue( k, p ), "issued again" )
	T.Check( GunPermit.Revoke( k, p ), "the Kaiser revokes it" )
	T.Check( not GunPermit.Revoke( k, p ), "nothing left to revoke" )

	-- A new life starts without one
	T.Check( GunPermit.Issue( k, p ), "issued once more" )
	p:KillSilent()
	p:Spawn()
	T.Wait( 0.3 )
	T.Equal( p:GetGunPermit(), "", "a new life holds no permit" )

	for _, b in ipairs( { k, p, p2, san } ) do b:Kick() end
end
