-- Step 8: trash piles (ported lootable.lua).
return function( T )
	local b = player.CreateNextBot( "t_trash" )
	b:SetRank( RANK_FRIEND ) b:SetStemCells( 5 )
	Fates.Take( b, "prole" )
	T.Check( Items.Get( "rotten_food" ) ~= nil, "rotten_food is defined" )
	T.Check( Layout.CLASSES.trash_pile ~= nil, "trash_pile is a layout class" )

	local n = 0
	for _, e in ipairs( include( GAMEMODE.FolderName .. "/gamemode/layouts/rp_slumtown.lua" ) or {} ) do
		if e.class == "trash_pile" then n = n + 1 end
	end
	T.Equal( n, 56, "one pile per uncommented GM.Lootables entry" )

	local p = ents.Create( "trash_pile" )
	p:SetKeyValue( "model", "models/props_junk/garbage128_composite001b.mdl" )
	p:SetKeyValue( "lootname", "Garbage" )
	p:SetPos( b:GetPos() + b:GetForward() * 40 ) p:Spawn()
	T.Equal( p:GetLootName(), "Garbage", "the layout name is networked" )
	T.Equal( p:GetModel(), "models/props_junk/garbage128_composite001b.mdl", "the layout model is used" )
	T.Check( p:Lootable(), "a fresh pile is lootable" )
	T.Check( p.PhysgunDisabled and p.DoNotDuplicate, "no physgun, no dupe" )

	local function count( cls ) return #ents.FindByClass( cls ) end
	local before = count( "bone_capsule" ) + count( "gr_item" )
	local pox = Needs.Get and Needs.Get( b, "Pox" ) or nil
	T.Check( p:Search( b ), "the first search finds something" )
	local got = count( "bone_capsule" ) + count( "gr_item" ) - before
	T.Check( got >= 1 and got <= 3, "1-3 drops: " .. got )
	if pox then T.Check( Needs.Get( b, "Pox" ) >= pox + 2 - 0.01, "adds 2 Pox" ) end
	local left = p:GetNextLoot() - CurTime()
	T.Check( left >= 419 and left <= 661, "empty for 300 + 120-360 s: " .. left )
	T.Check( not p:Lootable(), "the pile is empty" )
	T.Check( p:Search( b ) == false, "a second search finds nothing" )

	local seen = {}
	for _ = 1, 2000 do seen[ p:RollLoot() ] = ( seen[ p:RollLoot() ] or 0 ) + 1 end
	T.Check( seen.bone_capsule and seen.rotten_food and seen.clean_water and not seen.white_mold, "the loot table" )

	p:Remove() b:Kick()
end
