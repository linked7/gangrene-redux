-- Step 9: the closed economy. Transfers, the stockpile counter, every Economy setting, Grant and
-- Fine, the ledger, an empty treasury, corpses, disconnects, and a small soak ending in zero drift.
local TREASURY = Econ.TREASURY

local function bot( name, rank, fate )
	local b = player.CreateNextBot( name )
	b:SetRank( rank )
	b:SetStemCells( 10 )
	if fate then Fates.Take( b, fate ) end
	return b
end

local function fakeCorpse( pos )
	local rag = ents.Create( "prop_ragdoll" )
	rag:SetModel( "models/player/group01/male_07.mdl" )
	rag:SetPos( pos )
	rag:Spawn()
	rag.GR_Corpse = { bones = 0 }
	return rag
end

local function hasSource( source )
	for _, e in ipairs( Econ.Ledger( 50 ) ) do
		if e.source == source then return true end
	end
	return false
end

return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t9_%'" )

	-- Notices go through Notify; record them so the test can see what players were told.
	local told = {}
	local realNotify = Notify
	Notify = function( ply, text )
		table.insert( told, { ply = ply, text = text } )
		realNotify( ply, text )
	end
	local function wasTold( ply, substr )
		for _, n in ipairs( told ) do
			if n.ply == ply and string.find( n.text, substr, 1, true ) then return true end
		end
		return false
	end

	-- Round start --------------------------------------------------------------------------
	Econ.ResetRound()
	local supply = GetConVar( "bones_supply" ):GetInt()
	T.Equal( supply, 3000, "bones_supply defaults to 3000" )
	T.Equal( Econ.Treasury(), supply, "the treasury holds every bone at round start" )
	T.Equal( Econ.Supply(), supply, "the supply is public world state" )
	T.Equal( ( Econ.Audit() ), 0, "no drift at round start" )
	Econ.SetSetting( "breadline", 3 )
	T.Check( table.HasValue( WorldState.Pending(), "econ.breadline" ), "a setting change is queued for the next net tick" )
	T.Wait( 0.3 )
	T.Equal( #WorldState.Pending(), 0, "the net tick sends it" )
	Econ.ResetSettings()
	T.Check( Sched.Get( "econ_audit" ) ~= nil and Sched.Get( "econ_wages" ) ~= nil, "audit and wage jobs are scheduled" )

	local a = bot( "t9_a", RANK_FRIEND, "prole" )
	local b = bot( "t9_b", RANK_FRIEND, "prole" )
	local s = bot( "t9_s", RANK_FRIEND, "sanitar" )
	local k = bot( "t9_k", RANK_KAISER, "kaiser" )
	T.Wait( 0.3 )
	T.Check( k:FateHas( "RunsEconomy" ) and k:FateHas( "StockpileAccess" ), "the kaiser runs the economy and holds a key" )
	T.Check( s:FateHas( "StockpileAccess" ) and not a:FateHas( "StockpileAccess" ), "the sanitar has a key, the prole doesn't" )
	for _, p in ipairs( { a, b, s } ) do p:SetPos( k:GetPos() + Vector( 40, 0, 0 ) ) end

	-- Transfer -----------------------------------------------------------------------------
	local ok, why = Econ.Transfer( a, b, 5, "test" )
	T.Check( not ok and why == "cannot afford", "a transfer the sender can't afford is refused" )
	T.Check( not Econ.Transfer( TREASURY, a, -5, "test" ), "negative amounts are refused" )
	T.Check( not Econ.Transfer( TREASURY, a, 1.5, "test" ), "fractional amounts are refused" )
	T.Check( not Econ.Transfer( TREASURY, game.GetWorld(), 5, "test" ), "a non-holder is refused" )
	T.Check( not Econ.Transfer( TREASURY, TREASURY, 5, "test" ), "a holder can't pay itself" )
	T.Equal( Econ.Treasury(), supply, "refused transfers move nothing" )
	T.Check( Econ.Transfer( TREASURY, Econ.UPGRADE_FUND, 25, "test" ), "the upgrade fund holds bones" )
	T.Equal( ( Econ.Audit() ), 0, "the upgrade fund counts toward the invariant" )
	Econ.Transfer( Econ.UPGRADE_FUND, TREASURY, 25, "test" )

	-- Delivery and the counter ---------------------------------------------------------------
	T.Equal( Econ.Deliver( a, "ration" ), 20, "a delivered crate pays the buy price" )
	T.Equal( a:GetBones(), 20, "the deliverer got the bones" )
	T.Equal( Econ.Treasury(), supply - 20, "from the treasury" )
	T.Equal( Econ.Stock( "ration" ), 1, "the stock count rose" )

	local given = {}
	hook.Add( "GR_StockpileDispense", "t9", function( ply, good, how ) table.insert( given, { ply, good, how } ) end )
	T.Check( Econ.Buy( a, "ration" ), "buying a ration works" )
	T.Equal( a:GetBones(), 5, "it cost the sell price" )
	T.Equal( Econ.Treasury(), supply - 5, "and the bones went back to the treasury" )
	T.Equal( Econ.Stock( "ration" ), 0, "the stock count fell" )
	T.Check( given[ 1 ] and given[ 1 ][ 1 ] == a and given[ 1 ][ 3 ] == "buy", "the buyer was handed the good" )
	T.Equal( Inventory.Count( a, "ration" ), 1, "the ration is in the buyer's inventory" )
	T.Check( not Econ.Buy( a, "ration" ), "the counter can't sell what it doesn't have" )
	T.Check( not Econ.Buy( a, "gold" ), "unknown goods are refused" )

	local stockpile = ents.Create( "state_stockpile" )
	stockpile:SetPos( k:GetPos() + Vector( 80, 0, 0 ) )
	stockpile:Spawn()
	T.Check( IsValid( stockpile ), "the state_stockpile entity spawns" )
	Econ.Deliver( b, "clean_water" )
	T.Check( Econ.Counter( b, stockpile, Econ.COUNTER_BUY, "clean_water" ), "the counter message buys clean water" )
	T.Equal( b:GetBones(), 5, "clean water pays 20 and sells for 15" )

	-- Grant and Fine ---------------------------------------------------------------------------
	T.Check( not Econ.Grant( a, b, 10 ), "only the economy's runner may grant" )
	T.Check( Econ.Grant( k, b, 100 ), "the kaiser grants from the treasury" )
	T.Equal( b:GetBones(), 105, "the grant arrived" )
	T.Check( not Econ.Grant( k, b, supply * 2 ), "a grant the treasury can't cover fails" )
	T.Check( Econ.Fine( k, b, 30 ), "the kaiser fines" )
	T.Equal( b:GetBones(), 75, "the fine was taken" )
	T.Check( Econ.Fine( k, b, 1000 ), "a fine above what they carry still lands" )
	T.Equal( b:GetBones(), 0, "capped at what they carry" )
	T.Check( wasTold( b, "fined you" ), "the fined player is told" )
	T.Check( hasSource( "grant" ) and hasSource( "fine" ) and hasSource( "delivery" ) and hasSource( "sale" ), "the ledger shows each movement by source" )
	local inflow, outflow = Econ.Flows()
	T.Equal( inflow.fine, 105, "flows count fines into the treasury" )
	T.Equal( outflow.grant, 100, "flows count grants out of the treasury" )

	-- Every setting changes the next payment or purchase ------------------------------------------
	T.Check( Econ.KaiserSet( k, "buy.ration", 30 ), "the kaiser sets a buy price" )
	T.Equal( Econ.Deliver( a, "ration" ), 30, "buy.ration changes the next crate payment" )
	Econ.KaiserSet( k, "buy.clean_water", 7 )
	T.Equal( Econ.Deliver( a, "clean_water" ), 7, "buy.clean_water changes the next crate payment" )
	Econ.KaiserSet( k, "sell.ration", 4 )
	Econ.Deliver( a, "ration" )
	local before = a:GetBones()
	Econ.Buy( a, "ration" )
	T.Equal( a:GetBones(), before - 4, "sell.ration changes the next purchase" )
	Econ.KaiserSet( k, "sell.clean_water", 9 )
	before = a:GetBones()
	Econ.Buy( a, "clean_water" )
	T.Equal( a:GetBones(), before - 9, "sell.clean_water changes the next purchase" )

	-- reserve: the counter stops at the reserve, but a key ignores it.
	T.Equal( Econ.Stock( "ration" ), 1, "one ration left" )
	Econ.KaiserSet( k, "reserve.ration", 1 )
	T.Check( not Econ.Buy( a, "ration" ), "reserve.ration stops sales at the reserve" )
	Econ.KaiserSet( k, "breadline", 5 )
	T.Check( not Econ.Breadline( a ), "the reserve stops the bread line too" )
	T.Check( not Econ.Withdraw( a, "ration" ), "a prole can't withdraw" )
	T.Check( Econ.Withdraw( s, "ration" ), "the sanitar withdraws below the reserve" )
	T.Equal( Econ.Stock( "ration" ), 0, "withdrawn" )
	T.Check( not Econ.Withdraw( k, "ration" ), "nothing to withdraw from an empty stockpile" )
	Econ.KaiserSet( k, "reserve.ration", 0 )
	Econ.Deliver( b, "clean_water" ) Econ.Deliver( b, "clean_water" )
	Econ.KaiserSet( k, "reserve.clean_water", 2 )
	T.Check( not Econ.Buy( b, "clean_water" ), "reserve.clean_water stops sales at the reserve" )
	Econ.KaiserSet( k, "reserve.clean_water", 0 )

	-- breadline: one free ration per player per interval.
	for _ = 1, 4 do Econ.Deliver( b, "ration" ) end
	local bonesBefore = a:GetBones()
	T.Check( Econ.Breadline( a ), "the bread line gives a free ration" )
	T.Equal( a:GetBones(), bonesBefore, "for free" )
	T.Check( not Econ.Breadline( a ), "only once per interval" )
	T.Check( Econ.Breadline( b ), "per player" )
	Econ.KaiserSet( k, "breadline", 0 )
	T.Check( not Econ.Breadline( s ), "breadline 0 turns it off" )

	-- ration_limit: purchases per player per 10 min. b already bought clean water once.
	Econ.KaiserSet( k, "ration_limit", 2 )
	Econ.Grant( k, b, 50 )
	T.Check( Econ.Buy( b, "ration" ), "first purchase under the limit" )
	T.Check( not Econ.Buy( b, "ration" ), "ration_limit stops the next purchase" )
	Econ.KaiserSet( k, "ration_limit", 0 )
	T.Check( Econ.Buy( b, "ration" ), "ration_limit 0 is unlimited" )

	-- wages: from the treasury, by fate.
	T.Equal( Econ.Setting( "wage.sanitar" ), 40, "the sanitar's default wage comes from the fate" )
	T.Equal( Econ.Setting( "wage.prole" ), 0, "other fates default to 0" )
	Econ.KaiserSet( k, "wage.prole", 7 )
	local aB, sB, kB, tB = a:GetBones(), s:GetBones(), k:GetBones(), Econ.Treasury()
	Econ.PayWages()
	T.Equal( a:GetBones(), aB + 7, "wage.prole changes the next wage" )
	T.Equal( s:GetBones(), sB + 40, "the sanitar is paid its wage" )
	T.Equal( k:GetBones(), kB, "there is no kaiser wage" )
	T.Equal( Econ.Treasury(), tB - 7 - 7 - 40, "wages come from the treasury" )

	T.Check( Econ.KaiserSet( k, "revive_fee", 30 ), "revive_fee is stored" )
	T.Equal( Econ.Setting( "revive_fee" ), 30, "revive_fee reads back" )

	-- Out-of-schema values are rejected.
	T.Check( not Econ.KaiserSet( k, "buy.ration", -1 ), "negative values are rejected" )
	T.Check( not Econ.KaiserSet( k, "buy.ration", supply + 1 ), "values above the supply are rejected" )
	T.Check( not Econ.KaiserSet( k, "buy.ration", 2.5 ), "fractions are rejected" )
	T.Check( not Econ.KaiserSet( k, "kaiser_wage", 10 ), "unknown keys are rejected" )
	T.Check( not Econ.KaiserSet( k, "revive_fee", 101 ), "revive_fee is a percentage" )
	T.Check( not Econ.KaiserSet( a, "buy.ration", 1 ), "a prole can't set the economy" )
	T.Equal( Econ.Setting( "buy.ration" ), 30, "rejected sets change nothing" )
	T.Check( wasTold( k, "between" ), "the kaiser is told why" )
	T.Equal( ( Econ.Audit() ), 0, "no drift after the counter, settings, grants and fines" )

	-- An empty treasury ------------------------------------------------------------------------
	Econ.Transfer( TREASURY, Econ.UPGRADE_FUND, Econ.Treasury(), "test" )
	T.Equal( Econ.Treasury(), 0, "the treasury is drained" )
	local stock = Econ.Stock( "ration" )
	aB, sB = a:GetBones(), s:GetBones()
	T.Equal( Econ.Deliver( a, "ration" ), 0, "an empty treasury doesn't pay for crates" )
	T.Equal( Econ.Stock( "ration" ), stock + 1, "but the crate is still stocked" )
	T.Check( wasTold( a, "The treasury is empty." ), "the deliverer is told the treasury is empty" )
	Econ.PayWages()
	T.Equal( s:GetBones(), sB, "an empty treasury pays no wages" )
	T.Check( wasTold( s, "The treasury is empty." ), "the unpaid sanitar is told why" )
	T.Check( not Econ.Grant( k, a, 1 ), "an empty treasury grants nothing" )
	T.Check( wasTold( k, "The treasury is empty." ), "the kaiser is told the treasury is empty" )
	Econ.Transfer( Econ.UPGRADE_FUND, TREASURY, Econ.UpgradeFund(), "test" )

	-- Drift is noticed -------------------------------------------------------------------------
	T.ExpectError( "bone drift" )
	a:SetBones( a:GetBones() + 3 ) -- a bug elsewhere minting bones
	T.Equal( Econ.AuditJob(), 3, "the audit job reports minted bones as drift" )
	a:SetBones( a:GetBones() - 3 )
	T.Equal( Econ.AuditJob(), 0, "and zero once they are gone" )
	RunConsoleCommand( "econ_audit" )

	-- Corpses (the step 7 contract) --------------------------------------------------------------
	Econ.Grant( k, a, 50 )
	local carried = a:GetBones()
	local rag = fakeCorpse( a:GetPos() + Vector( 0, 60, 10 ) )
	hook.Run( "GR_PlayerDowned", a, rag )
	T.Equal( a:GetBones(), 0, "a downed player's bones leave them" )
	T.Equal( rag.GR_Corpse.bones, carried, "and go to the corpse" )
	T.Equal( ( Econ.Audit() ), 0, "corpses count toward the invariant" )
	hook.Run( "GR_PlayerRestored", a, rag, "revive" )
	T.Equal( a:GetBones(), carried, "revival returns the corpse's bones" )
	T.Equal( rag.GR_Corpse.bones, 0, "the corpse is empty" )
	hook.Run( "GR_PlayerDowned", a, rag )
	local tB2 = Econ.Treasury()
	hook.Run( "GR_CorpseRemoved", rag )
	rag:Remove()
	T.Equal( Econ.Treasury(), tB2 + carried, "a removed corpse's bones go to the treasury" )
	local rag2 = fakeCorpse( b:GetPos() + Vector( 0, 60, 10 ) )
	Econ.Grant( k, b, 12 )
	local bCarried = b:GetBones()
	hook.Run( "GR_PlayerDowned", b, rag2 )
	tB2 = Econ.Treasury()
	rag2:Remove() -- no GR_CorpseRemoved: the EntityRemoved safety net catches it
	T.Wait( 0.1 )
	T.Equal( Econ.Treasury(), tB2 + bCarried, "a corpse removed without the hook still returns its bones" )
	T.Equal( ( Econ.Audit() ), 0, "no drift after corpses come and go" )

	-- Disconnect and rejoin ----------------------------------------------------------------------
	Econ.Grant( k, s, 33 )
	local sBones = s:GetBones()
	s:Kick( "test" )
	T.WaitUntil( function() return not IsValid( s ) end, 5, "the sanitar left" )
	T.Equal( Econ.Held( "bot:t9_s" ), sBones, "their bones are held for them" )
	T.Equal( ( Econ.Audit() ), 0, "held bones count toward the invariant" )
	T.Wait( 0.3 )
	s = player.CreateNextBot( "t9_s" )
	T.Equal( s:GetBones(), sBones, "rejoining restores the bones" )
	T.Equal( Econ.Held( "bot:t9_s" ), 0, "and clears the holding" )
	T.Equal( ( Econ.Audit() ), 0, "no drift after a rejoin" )

	-- The Kaiser's death resets the Economy table ----------------------------------------------------
	a:Kill()
	T.Wait( 0.1 )
	T.Equal( Econ.Setting( "buy.ration" ), 30, "a prole's death leaves the settings alone" )
	k:Kill()
	T.Wait( 0.1 )
	T.Equal( Econ.Setting( "buy.ration" ), 30, "a downed kaiser keeps the settings (they may be revived)" )
	Corpse.Die( ( Corpse.Of( k ) ), "test" )
	T.Equal( Econ.Setting( "buy.ration" ), 20, "the kaiser's death resets buy.ration" )
	T.Equal( Econ.Setting( "wage.prole" ), 0, "and the wages" )
	T.Equal( Econ.Setting( "revive_fee" ), 50, "and the revive fee" )
	T.Check( wasTold( b, "The Kaiser is dead" ), "everyone is told" )

	-- Soak: 10 bots, random movements, deaths, kicks and rejoins, then zero drift -----------------------
	local soak = {}
	for i = 1, 10 do
		local p = bot( "t9_soak" .. i, RANK_FRIEND, i % 3 == 0 and "korpsman" or "prole" )
		table.insert( soak, p )
	end
	T.Wait( 0.3 )
	local function anyHolder()
		local r = math.random( 10 )
		if r == 1 then return TREASURY end
		if r == 2 then return Econ.UPGRADE_FUND end
		local p = soak[ math.random( #soak ) ]
		return IsValid( p ) and p or TREASURY
	end
	local live = {}
	for round = 1, 6 do
		for _ = 1, 60 do
			Econ.Transfer( anyHolder(), anyHolder(), math.random( 0, 200 ), "soak" )
		end
		for _ = 1, 5 do
			local p = soak[ math.random( #soak ) ]
			if IsValid( p ) then Econ.Deliver( p, Econ.GOODS[ math.random( #Econ.GOODS ) ] ) end
			if IsValid( p ) and p:Alive() then Econ.Buy( p, "ration" ) end
		end
		Econ.PayWages()

		-- Down two, revive one, let the other's corpse rot.
		local d1, d2 = soak[ round ], soak[ round + 4 ]
		if IsValid( d1 ) and IsValid( d2 ) then
			local r1, r2 = fakeCorpse( d1:GetPos() + Vector( 0, 50, 10 ) ), fakeCorpse( d2:GetPos() + Vector( 0, -50, 10 ) )
			hook.Run( "GR_PlayerDowned", d1, r1 )
			hook.Run( "GR_PlayerDowned", d2, r2 )
			Econ.Transfer( TREASURY, r1, 5, "soak" ) -- bones dropped on a body
			table.insert( live, r2 )
			hook.Run( "GR_PlayerRestored", d1, r1, "getup" )
			r1:Remove()
			d2:Kill()
		end

		-- Kick one and bring it straight back.
		local idx = 10 - round + 1
		local leaving = soak[ idx ]
		local name = leaving:SteamName()
		leaving:Kick( "soak" )
		T.WaitUntil( function() return not IsValid( leaving ) end, 5, "soak bot " .. name .. " left" )
		T.Equal( ( Econ.Audit() ), 0, "no drift while " .. name .. " is away" )
		T.Wait( 0.3 )
		soak[ idx ] = bot( name, RANK_FRIEND, "prole" )
		T.Wait( 0.2 )
	end
	T.Equal( ( Econ.Audit() ), 0, "no drift with corpses still lying around" )
	for _, r in ipairs( live ) do
		if IsValid( r ) then r:Remove() end
	end
	T.Wait( 0.5 )
	local drift, parts = Econ.Audit()
	T.Note( "soak end: players %d, corpses %d, held %d, fund %d, treasury %d", parts.players, parts.corpses, parts.held, parts.fund, parts.treasury )
	T.Equal( drift, 0, "econ_audit reports zero drift after the soak" )
	T.Equal( parts.corpses, 0, "every rotted corpse's bones went back to the treasury" )

	-- Next round: everything goes back to the treasury.
	Econ.ResetRound()
	T.Equal( Econ.Treasury(), supply, "ResetRound refills the treasury" )
	T.Equal( b:GetBones(), 0, "and empties every pocket" )
	T.Equal( ( Econ.Audit() ), 0, "no drift after a reset" )

	hook.Remove( "GR_StockpileDispense", "t9" )
	Notify = realNotify
	stockpile:Remove()
end
