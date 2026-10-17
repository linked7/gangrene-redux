-- Step 8: items, inventory, weight limit, pick up / drop / use, the corpse contract and the pump.
local function living( name, fate )
	local b = player.CreateNextBot( name )
	b:SetRank( RANK_FRIEND ) b:SetStemCells( 5 )
	Fates.Take( b, fate or "prole" )
	Inventory.Clear( b ) -- start empty: the fate's kit (step 11.1) is tested in step11a
	return b
end

local function entriesById( d )
	local out = {}
	for _, e in ipairs( d and d.entries or {} ) do out[ Items.ByIndex( e[ 1 ] ).id ] = e[ 2 ] end
	return out
end

return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t8_%'" )

	-- Definitions ---------------------------------------------------------------------------
	T.Check( #Items.All() >= 10, "about ten starting items: " .. #Items.All() )
	for _, id in ipairs( { "ration", "clean_water", "dirty_water", "scrap", "bandage", "surgical_tools", "baton", "pistol", "weapon_permit", "trade_permit" } ) do
		T.Check( Items.Get( id ) ~= nil and Items.ByIndex( Items.Get( id ).index ) == Items.Get( id ), "item " .. id .. " is defined and indexed" )
	end
	for _, def in ipairs( Items.All() ) do
		T.Check( util.IsValidModel( def.Model ), def.id .. " model exists: " .. def.Model )
	end
	T.Check( not pcall( Items.Define, "t8_bad", { Name = "x" } ), "missing Description is a load error" )
	T.Check( not pcall( Items.Define, "t8_bad", { Name = "x", Description = "y", Wieght = 2 } ), "a misspelled field is a load error" )
	T.Check( not pcall( Items.Define, "t8_bad", { Name = "x", Description = "y", Weight = "heavy" } ), "a wrong type is a load error" )
	T.Check( not pcall( Items.Define, "t8_bad", { Name = "x", Description = "y", Effects = { Hunger = 1 } } ), "an unknown need in Effects is a load error" )
	T.Check( Items.Get( "t8_bad" ) == nil, "invalid items are not registered" )

	-- Ghosts carry nothing --------------------------------------------------------------------
	local g = player.CreateNextBot( "t8_ghost" )
	T.Wait( 0.2 )
	T.Check( not Inventory.Add( g, "ration" ), "a ghost can't receive items" )
	T.Equal( Inventory.Fits( g, "ration" ), 0, "nothing fits a ghost" )

	-- Weight limit ------------------------------------------------------------------------------
	local a = living( "t8_a" )
	T.Wait( 0.2 )
	T.Equal( Inventory.Limit( a ), Inventory.CARRY_BASE + 5, "prole limit is base + CarryBonus" )
	local s = living( "t8_san", "sanitar" )
	T.Equal( Inventory.Limit( s ), Inventory.CARRY_BASE, "a fate without CarryBonus gets the base" )

	T.Check( Inventory.Add( a, "scrap", 12 ), "12 scrap (24) fits under 25" )
	T.Equal( Inventory.Weight( a ), 24, "weight is cached" )
	T.Equal( Inventory.Fits( a, "scrap" ), 0, "no more scrap fits" )
	local ok, why = Inventory.Add( a, "scrap", 1 )
	T.Check( not ok, "13th scrap refused: " .. tostring( why ) )
	T.Equal( Inventory.Count( a, "scrap" ), 12, "refused add changed nothing" )
	T.Check( Inventory.Add( a, "sack" ), "a sack pays for its own weight" )
	T.Equal( Inventory.Limit( a ), Inventory.CARRY_BASE + 5 + 10, "CarryAdd raises the limit" )
	T.Equal( Inventory.Fits( a, "scrap" ), 5, "the sack makes room for 5 more scrap" )
	T.Check( Inventory.Add( a, "weapon_permit", 3 ), "weightless items fit at the limit" )
	T.Check( Inventory.Add( a, "scrap", 3, true ) and Inventory.Count( a, "scrap" ) == 15, "force ignores the limit" )
	T.Check( Inventory.Remove( a, "scrap", 15 ) and Inventory.Remove( a, "sack" ) and Inventory.Remove( a, "weapon_permit", 3 ), "removing everything" )
	T.Check( not Inventory.Remove( a, "scrap" ), "can't remove what isn't there" )
	T.Equal( Inventory.Weight( a ), 0, "weight returns to 0" )
	T.Equal( next( Inventory.Items( a ) ), nil, "the map holds no zero counts" )

	-- Delta message ---------------------------------------------------------------------------
	Inventory.Collect( a )
	Inventory.Add( a, "ration", 2 )
	Inventory.Add( a, "clean_water", 1 )
	local d = Inventory.Collect( a )
	local e = entriesById( d )
	T.Check( d and not d.full and e.ration == 2 and e.clean_water == 1 and #d.entries == 2, "delta holds exactly the changed items" )
	Inventory.Remove( a, "ration", 1 )
	e = entriesById( Inventory.Collect( a ) )
	T.Check( e.ration == 1 and e.clean_water == nil, "the next delta holds only the ration" )
	T.Equal( Inventory.Collect( a ), nil, "nothing pending after a collect" )
	Inventory.Add( a, "scrap", 1 )
	T.WaitUntil( function() return not next( a.GR_Inv.dirty ) end, 2, "the net tick flushes the pending delta" )
	Inventory.Remove( a, "scrap", 1 )
	Inventory.Collect( a )

	-- Use ---------------------------------------------------------------------------------------
	Needs.Add( a, "Emptiness", 80, "test" )
	Needs.Add( a, "Dryness", 80, "test" )
	local hungry = Needs.Get( a, "Emptiness" )
	T.Check( Inventory.Use( a, "ration" ), "eating a ration" )
	T.Check( Needs.Get( a, "Emptiness" ) < hungry - 40, "the ration lowers Emptiness" )
	T.Equal( Inventory.Count( a, "ration" ), 0, "the ration is consumed" )
	T.Check( not Inventory.Use( a, "ration" ), "can't use what you don't have" )
	local dry = Needs.Get( a, "Dryness" )
	Inventory.Use( a, "clean_water" )
	local cleanDrop = dry - Needs.Get( a, "Dryness" )

	Needs.Add( a, "Dryness", 80, "test" )
	dry = Needs.Get( a, "Dryness" )
	Inventory.Add( a, "dirty_water", 1 )
	Inventory.Use( a, "dirty_water" )
	local dirtyDrop = dry - Needs.Get( a, "Dryness" )
	T.Check( dirtyDrop > 0 and dirtyDrop < cleanDrop, string.format( "dirty water quenches less than clean (%.1f < %.1f)", dirtyDrop, cleanDrop ) )

	-- Drinking dirty water sometimes adds Pox: count the Pox adds over many drinks.
	local poxed = 0
	local function count( _, name, amount, source )
		if name == "Pox" and amount > 0 and source == "dirty water" then poxed = poxed + 1 end
	end
	table.insert( Needs.Modifiers, count )
	local drinks = 200
	Inventory.GiveAll( a, { dirty_water = drinks } )
	for _ = 1, drinks do Inventory.Use( a, "dirty_water" ) end
	table.RemoveByValue( Needs.Modifiers, count )
	T.Equal( Inventory.Count( a, "dirty_water" ), 0, "every dirty water was drunk" )
	T.Check( poxed > 20 and poxed < 80, string.format( "dirty water adds Pox about 25%% of the time (%d of %d)", poxed, drinks ) )
	T.Check( Needs.Get( a, "Pox" ) > 0, "the drinker has Pox" )
	Needs.Add( a, "Pox", -100, "test" )

	Inventory.Add( a, "bandage", 1 )
	a:SetHealth( a:GetMaxHealth() )
	T.Check( not Inventory.Use( a, "bandage" ) and Inventory.Count( a, "bandage" ) == 1, "a bandage isn't wasted at full health" )
	a:SetHealth( 50 )
	T.Check( Inventory.Use( a, "bandage" ) and a:Health() == 65 and Inventory.Count( a, "bandage" ) == 0, "a bandage heals 15" )
	Inventory.Add( a, "scrap", 1 )
	T.Check( not Inventory.Use( a, "scrap" ) and Inventory.Count( a, "scrap" ) == 1, "scrap has no use and isn't consumed" )

	-- Weapons follow the count ----------------------------------------------------------------
	Inventory.Add( a, "pistol", 1 )
	T.Check( a:HasWeapon( "weapon_gr_pistol" ), "carrying a pistol item gives the weapon" )
	T.Check( Inventory.Use( a, "pistol" ) and Inventory.Count( a, "pistol" ) == 1, "using a weapon draws it, not consumes it" )

	-- Drop and pick up ------------------------------------------------------------------------
	local b = living( "t8_b" )
	T.Wait( 0.2 )
	local ent = Inventory.Drop( a, "pistol" )
	T.Check( IsValid( ent ) and ent:GetClass() == "gr_item", "dropping makes a gr_item" )
	T.Check( not a:HasWeapon( "weapon_gr_pistol" ), "dropping the pistol takes the weapon" )
	T.Equal( Inventory.Count( a, "pistol" ), 0, "the pistol left the inventory" )
	T.Check( ent:GetItemId() == "pistol" and ent:GetCount() == 1, "the entity holds the pistol" )
	ent:Use( b, b )
	T.Equal( Inventory.Count( b, "pistol" ), 1, "using the entity picks it up" )
	T.Check( b:HasWeapon( "weapon_gr_pistol" ), "the new owner has the weapon" )
	T.WaitUntil( function() return not IsValid( ent ) end, 2, "the picked-up entity is removed" )

	Inventory.Remove( a, "scrap", Inventory.Count( a, "scrap" ) )
	Inventory.Add( a, "scrap", 5 )
	ent = Inventory.Drop( a, "scrap", 3 )
	T.Check( IsValid( ent ) and ent:GetCount() == 3 and Inventory.Count( a, "scrap" ) == 2, "dropping 3 scrap makes one stack of 3" )
	T.Equal( Inventory.Drop( a, "ration", 1 ), nil, "can't drop what you don't have" )
	-- b has room for exactly one scrap.
	Inventory.Add( b, "scrap", math.floor( ( Inventory.Limit( b ) - Inventory.Weight( b ) - 2 ) / 2 ) )
	T.Equal( Inventory.Fits( b, "scrap" ), 1, "b has room for one scrap" )
	T.Equal( Inventory.PickUp( b, ent ), 1, "picking up takes as much as fits" )
	T.Check( IsValid( ent ) and ent:GetCount() == 2, "the rest stays on the ground" )
	T.Equal( Inventory.PickUp( b, ent ), 0, "a full player takes nothing" )
	T.Equal( Inventory.PickUp( a, ent ), 2, "another player takes the rest" )
	T.Equal( Inventory.PickUp( s, ent ), 0, "a stack can't be taken twice in one tick" )
	local spawned = Items.Spawn( "ration", 1, a:GetPos() + Vector( 0, 0, 40 ) )
	T.Check( IsValid( spawned ), "Items.Spawn places an item in the world" )
	spawned:Remove()

	-- Corpse contract (step 7 runs these hooks) ----------------------------------------------
	Inventory.TakeAll( a )
	Inventory.Add( a, "ration", 2 )
	Inventory.Add( a, "baton", 1 )
	Inventory.Add( a, "sack", 1 )
	local weight = Inventory.Weight( a )
	local rag = { GR_Corpse = { inventory = {} } }
	hook.Run( "GR_PlayerDowned", a, rag )
	T.Equal( next( Inventory.Items( a ) ), nil, "downing empties the player's inventory" )
	T.Equal( Inventory.Weight( a ), 0, "and its weight" )
	T.Check( not a:HasWeapon( "weapon_gr_baton" ), "the baton went with it" )
	local held = rag.GR_Corpse.inventory
	T.Check( held.ration == 2 and held.baton == 1 and held.sack == 1, "the corpse holds the items" )

	-- A revive keeps the corpse's items however Fates.Apply and the hook are ordered.
	Fates.Apply( a, "prole", { reason = "revive" } )
	hook.Run( "GR_PlayerRestored", a, rag, "revive" )
	T.Check( Inventory.Count( a, "ration" ) == 2 and Inventory.Count( a, "baton" ) == 1, "revive gives the items back" )
	T.Equal( Inventory.Weight( a ), weight, "the weight is restored" )
	T.Check( a:HasWeapon( "weapon_gr_baton" ), "the baton is in hand again" )
	T.Equal( next( held ), nil, "the corpse is empty after the revive" )
	Fates.Apply( a, "prole", { reason = "revive" } )
	T.Equal( Inventory.Count( a, "ration" ), 2, "a revive fate entry keeps the inventory" )
	T.Check( a:HasWeapon( "weapon_gr_baton" ), "and gives item weapons back after the strip" )

	-- GiveAll ignores the limit; TakeAll returns a map.
	Inventory.GiveAll( a, { scrap = 50 } )
	T.Equal( Inventory.Count( a, "scrap" ), 50, "GiveAll ignores the weight limit" )
	local map = Inventory.TakeAll( a )
	T.Check( map.scrap == 50 and map.ration == 2, "TakeAll returns the whole map" )
	T.Check( Inventory.Collect( a ).full, "TakeAll sends a full reset" )

	-- Pump --------------------------------------------------------------------------------------
	local pump = ents.Create( "water_pump" )
	pump:SetPos( a:GetPos() + Vector( 60, 0, 0 ) )
	pump:Spawn()
	pump:Use( a, a )
	T.Equal( Inventory.Count( a, "dirty_water" ), 1, "the pump gives one dirty water" )
	pump:Use( a, a )
	T.Equal( Inventory.Count( a, "dirty_water" ), 1, "the pump has a cooldown" )
	pump:Use( b, b )
	T.Equal( Inventory.Count( b, "dirty_water" ), 1, "the cooldown is per player" )
	T.Wait( Inventory.PUMP_COOLDOWN + 0.1 )
	pump:Use( a, a )
	T.Equal( Inventory.Count( a, "dirty_water" ), 2, "the pump works again after the cooldown" )
	pump:Use( g, g )
	T.Equal( Inventory.Count( g, "dirty_water" ), 0, "ghosts can't pump" )
	pump:Remove()

	-- One life ----------------------------------------------------------------------------------
	Fates.Apply( a, FATE_GHOST, { reason = "admin" } )
	T.Equal( next( Inventory.Items( a ) ), nil, "becoming a ghost clears the inventory" )
	Inventory.Add( b, "ration", 1 )
	b:Kill()
	Corpse.Die( Corpse.Of( b ), "test" ) -- skip the bleed-out (step 7)
	T.WaitUntil( function() return b:Alive() and b:IsGhost() end, 6, "b dies and comes back a ghost" )
	T.Equal( Inventory.Count( b, "ration" ), 0, "the next life starts with nothing" )
end
