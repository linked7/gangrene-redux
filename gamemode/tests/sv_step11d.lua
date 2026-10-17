-- Step 11.4: the Kaiser. Taking the role (rank, cost, slot, armor, kit), Sentence and Forgive with
-- every target check, forgiveness paid by the forgiven, upgrades into the fund with zero drift and
-- cleared at round reset, the ledger fetch, and the Economy table reset on the final death only.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t11d_%'" )

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

	local function bot( name, rank, stem )
		local b = player.CreateNextBot( "t11d_" .. name )
		b:SetRank( rank )
		b:SetStemCells( stem or 10 )
		return b
	end

	Econ.ResetRound()
	local supply = Econ.Supply()
	T.Wait( 0.2 )

	-- Taking the role ------------------------------------------------------------------------------
	-- No rank gate above Friend for now (plan, step 11.4): stem cells and the free slot decide.
	local friend = bot( "friend", RANK_FRIEND, 10 )
	local ok, why = Fates.CanTake( friend, "kaiser" )
	T.Check( ok, "a Friend with 5 stem cells may take the Kaiser: " .. tostring( why ) )
	local fool = bot( "fool", RANK_FOOLISH, 10 )
	T.Check( not Fates.CanTake( fool, "kaiser" ), "a Foolish player can't" )
	local poor = bot( "poor", RANK_KAISER, 4 )
	T.Check( not Fates.CanTake( poor, "kaiser" ), "the Kaiser costs 5 stem cells" )

	local k = bot( "kaiser", RANK_KAISER, 10 )
	T.Check( Fates.Take( k, "kaiser" ), "Kaiser rank with 5 stem cells takes the role" )
	T.Equal( k:GetStemCells(), 5, "5 stem cells were spent" )
	T.Equal( k:Armor(), 75, "75 armor" )
	T.Equal( Inventory.Count( k, "novoluger" ), 1, "the kit holds the novoluger" )
	T.Equal( Inventory.Count( k, "strategy_book" ), 1, "and the strategy book" )
	T.Check( k:HasWeapon( "weapon_gr_pistol" ), "the novoluger is in hand (stock pistol placeholder)" )
	local k2 = bot( "kaiser2", RANK_KAISER, 10 )
	T.Check( not Fates.CanTake( k2, "kaiser" ), "there is one Kaiser slot" )
	T.Check( k:FateHas( "CanSentence" ) and k:FateHas( "RunsEconomy" ) and k:FateHas( "StockpileAccess" ), "the kaiser sentences, runs the economy and holds a key" )
	T.Check( Inventory.Use( k, "strategy_book" ), "the kaiser opens the book" )

	for _, name in ipairs( { "nkaisersentence", "nkaiserforgive", "nkaiserupgrade", "nkaiserledger", "nkaiserecon", "nkaisergrant", "nkaiserfine" } ) do
		T.Check( net.Receivers[ name ] ~= nil, "receiver " .. name .. " is registered" )
	end

	local p = bot( "prole", RANK_FRIEND )
	Fates.Take( p, "prole" )
	local p2 = bot( "prole2", RANK_FRIEND )
	Fates.Take( p2, "prole" )
	local far = bot( "far", RANK_FRIEND )
	Fates.Take( far, "prole" )
	local ghost = bot( "ghost", RANK_FRIEND )
	T.Wait( 0.2 )
	Inventory.Add( p, "strategy_book", 1, true )
	T.Check( not Inventory.Use( p, "strategy_book" ), "a prole can't use the strategy book" )
	T.Check( wasTold( p, "mean nothing" ), "and is told so" )
	T.Check( ghost:IsGhost() and p:FateHas( "Citizen" ), "a ghost and proles are about" )

	local base = k:GetPos()
	for _, b in ipairs( { k, p, p2, far, ghost } ) do b:SetMoveType( MOVETYPE_NONE ) end
	p:SetPos( base + Vector( 60, 0, 0 ) )
	p2:SetPos( base + Vector( 0, 60, 0 ) )
	ghost:SetPos( base + Vector( -60, 0, 0 ) )
	far:SetPos( base + Vector( 4000, 0, 0 ) )

	-- Sentence ---------------------------------------------------------------------------------------
	T.Check( not Kaiser.Sentence( p2, p, WANTED_JUDGMENT ), "a non-kaiser can't sentence" )
	T.Equal( p:GetWanted(), WANTED_NONE, "and nothing happened" )
	T.Check( not Kaiser.Sentence( k, ghost, WANTED_JUDGMENT ), "a ghost can't be sentenced" )
	T.Check( wasTold( k, "beyond your judgment" ), "the kaiser is told why" )
	T.Check( not Kaiser.Sentence( k, far, WANTED_JUDGMENT ), "an unseen target out of range can't be sentenced" )
	T.Check( wasTold( k, "can't see them" ), "the kaiser is told they're out of sight" )
	T.Equal( far:GetWanted(), WANTED_NONE, "the far prole is not wanted" )
	T.Check( not Kaiser.Sentence( k, k, WANTED_DEATH ), "the kaiser can't sentence themself" )
	T.Check( not Kaiser.Sentence( k, p, 0 ), "no sentence of level none" )
	T.Check( not Kaiser.Sentence( k, p, 7 ), "no unknown sentence levels" )
	T.Check( not Kaiser.Sentence( k, game.GetWorld(), WANTED_DEATH ), "the world is not a target" )
	T.Check( Kaiser.Sentence( k, p, WANTED_JUDGMENT ), "the kaiser sentences a prole in range" )
	T.Equal( p:GetWanted(), WANTED_JUDGMENT, "the prole is wanted at judgment" )
	T.Equal( p:GetWantedReason(), Kaiser.SENTENCE_REASON, "for the Kaiser's sentence" )
	T.Check( math.abs( Crime.WantedLeft( p ) - Kaiser.SENTENCES[ WANTED_JUDGMENT ] ) < 1, "for the sentence's duration" )
	T.Check( wasTold( p, "wanted" ), "the sentenced prole is told" )

	-- Sentence by sight: out of range but in plain view.
	p2:SetPos( base + Vector( 0, Kaiser.RANGE + 200, 0 ) )
	local seen = Crime.CanSee( k, p2 )
	T.Note( "p2 at %d units is %s", Kaiser.RANGE + 200, seen and "visible" or "hidden" )
	T.Equal( Kaiser.Sentence( k, p2, WANTED_TORMENT ) == true, seen, "beyond range, sentence works exactly when the target is visible" )
	Crime.ClearWanted( p2 )
	p2:SetPos( base + Vector( 0, 60, 0 ) )

	-- Forgive ----------------------------------------------------------------------------------------
	T.Check( not Kaiser.Forgive( p2, p ), "a non-kaiser can't forgive" )
	T.Check( not Kaiser.Forgive( k, ghost ), "a ghost can't be forgiven" )
	T.Check( not Kaiser.Forgive( k, far ), "an unseen target out of range can't be forgiven" )
	T.Check( not Kaiser.Forgive( k, p2 ), "an innocent has nothing to forgive" )
	local paid
	ok, paid = Kaiser.Forgive( k, p )
	T.Check( ok, "a sentence is forgiven" )
	T.Equal( paid, 0, "forgiving a sentence is free" )
	T.Equal( p:GetWanted(), WANTED_NONE, "the prole is no longer wanted" )

	-- A caught thief: forgiveness costs 300, paid by the thief.
	Crime.MakeWanted( p, WANTED_TORMENT, 180, "theft from the People" )
	local treasury = Econ.Treasury()
	T.Equal( p:GetBones(), 0, "the thief is broke" )
	T.Check( not Kaiser.Forgive( k, p ), "a thief who can't pay 300 isn't forgiven" )
	T.Equal( p:GetWanted(), WANTED_TORMENT, "and stays wanted" )
	T.Equal( Econ.Treasury(), treasury, "nothing moved" )
	T.Check( wasTold( p, "can't pay" ) and wasTold( k, "can't pay" ), "both are told why" )
	Econ.Grant( k, p, 350 )
	treasury = Econ.Treasury()
	ok, paid = Kaiser.Forgive( k, p )
	T.Check( ok, "a thief who can pay is forgiven" )
	T.Equal( paid, 300, "for 300" )
	T.Equal( p:GetBones(), 50, "paid by the thief" )
	T.Equal( Econ.Treasury(), treasury + 300, "into the treasury" )
	T.Equal( p:GetWanted(), WANTED_NONE, "the theft is forgiven" )

	-- An unseen theft (evidence only) costs the same, and clears the evidence.
	Crime.Report( p2, "theft", { madeBy = "bot:someone_else" } )
	T.Check( Crime.Evidence( p2 ).theft ~= nil, "the unseen thief has theft evidence" )
	Econ.Grant( k, p2, 300 )
	ok, paid = Kaiser.Forgive( k, p2 )
	T.Check( ok and paid == 300, "theft evidence is forgiven for 300" )
	T.Equal( p2:GetBones(), 0, "paid in full" )
	T.Check( Crime.Evidence( p2 ).theft == nil, "and the evidence is gone" )
	local ledgerHas = false
	for _, e in ipairs( Econ.Ledger( 10 ) ) do
		if e.source == "forgiveness" and e.toTreasury then ledgerHas = true end
	end
	T.Check( ledgerHas, "the ledger shows forgiveness payments" )
	T.Equal( ( Econ.Audit() ), 0, "no drift after forgiveness" )

	-- Upgrades ---------------------------------------------------------------------------------------
	local prices = k:FateHas( "Upgrades" )
	T.Check( istable( prices ) and prices.prole == 125 and prices.korpsman == 150, "the upgrade table is data on the fate" )
	T.Check( not Kaiser.Upgrade( p, "prole" ), "a non-kaiser can't buy upgrades" )
	T.Check( not Kaiser.Upgrade( k, "sanitar" ), "fates not in the table can't be upgraded" )
	T.Check( not Kaiser.Upgrade( k, "nonsense" ), "unknown fates are refused" )
	treasury = Econ.Treasury()
	T.Check( Kaiser.Upgrade( k, "prole" ), "the kaiser upgrades the prole" )
	T.Equal( Econ.Treasury(), treasury - 125, "125 left the treasury" )
	T.Equal( Econ.UpgradeFund(), 125, "into the upgrade fund" )
	T.Check( Kaiser.Upgraded( "prole" ) and WorldState.Get( "upgrade_prole" ) == true, "upgrade_prole is set in world state" )
	T.Check( wasTold( p, "invested" ), "everyone hears of it" )
	T.Check( not Kaiser.Upgrade( k, "prole" ), "an upgrade is bought once per round" )
	T.Equal( Econ.UpgradeFund(), 125, "the second attempt cost nothing" )
	T.Check( Kaiser.Upgrade( k, "korpsman" ), "the kaiser upgrades the korpsman" )
	T.Equal( Econ.UpgradeFund(), 275, "150 more in the fund" )
	T.Equal( ( Econ.Audit() ), 0, "econ_audit: zero drift with bones in the upgrade fund" )

	-- Ledger fetch
	T.Check( Kaiser.SendLedger( k ) > 0, "the ledger fetch sends rows" )

	-- A new round clears the upgrades and empties the fund back into the treasury.
	Econ.ResetRound()
	T.Check( not Kaiser.Upgraded( "prole" ) and not Kaiser.Upgraded( "korpsman" ), "the round reset clears every upgrade" )
	T.Equal( WorldState.Get( "upgrade_prole" ), false, "upgrade_prole is false again" )
	T.Equal( Econ.UpgradeFund(), 0, "the fund is empty" )
	T.Equal( Econ.Treasury(), supply, "the treasury holds the whole supply" )
	T.Equal( ( Econ.Audit() ), 0, "no drift after the reset" )

	-- An empty treasury can't fund an upgrade.
	Econ.Transfer( Econ.TREASURY, p, Econ.Treasury(), "test" )
	T.Check( not Kaiser.Upgrade( k, "prole" ), "an empty treasury buys no upgrade" )
	T.Check( not Kaiser.Upgraded( "prole" ), "and nothing is set" )
	T.Check( wasTold( k, "can't cover" ), "the kaiser is told" )
	Econ.Transfer( p, Econ.TREASURY, p:GetBones(), "test" )

	-- The Kaiser's death -----------------------------------------------------------------------------
	T.Check( Econ.KaiserSet( k, "buy.ration", 33 ), "the kaiser sets a price" )
	T.Check( not Econ.KaiserSet( p, "buy.ration", 1 ), "a prole can't" )
	T.Check( not Econ.Grant( p, p2, 10 ) and not Econ.Fine( p, p2, 10 ), "a prole can't grant or fine" )
	k:Kill()
	T.Wait( 0.2 )
	T.Equal( Econ.Setting( "buy.ration" ), 33, "a downed kaiser's economy stands (they may be revived)" )
	Corpse.Die( ( Corpse.Of( k ) ), "test" )
	T.Equal( Econ.Setting( "buy.ration" ), Econ.GOOD_DEFAULTS.ration.buy, "the final death resets the Economy table" )
	T.Check( wasTold( p, "The Kaiser is dead" ) and wasTold( far, "The Kaiser is dead" ), "everyone is told" )
	T.Check( math.abs( k:GetCooldown_kaiser() - CurTime() - 600 ) < 1, "the role is on a 600 s cooldown" )
	T.WaitUntil( function() return k:Alive() and k:IsGhost() end, 5, "the kaiser comes back as a ghost" )
	k:SetStemCells( 10 )
	T.Check( not Fates.CanTake( k, "kaiser" ), "and can't take the role again yet" )
	T.Check( Fates.CanTake( k2, "kaiser" ), "the slot is free for another Kaiser-ranked player" )

	Notify = realNotify
end
