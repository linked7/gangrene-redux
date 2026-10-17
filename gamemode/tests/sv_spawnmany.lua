-- Items.SpawnMany: a list of item ids spawned at one spot, one every 0.25 s instead of all in one
-- frame. The first appears at once; ids and { id, count } stacks mix; unknown ids are skipped;
-- two batches run side by side; a round start drops what is still queued.
return function( T )
	local bot = player.CreateNextBot( "tsm_a" )
	local pos = bot:GetPos() + bot:GetForward() * 60 + Vector( 0, 0, 40 )

	local batch = Items.SpawnMany( { "ration", "no_such_item", { "scrap", 3 }, "ration" }, pos )
	T.Equal( #batch.spawned, 1, "the first one appears at once" )
	T.Check( not batch.done, "the rest are queued" )
	T.Wait( 0.15 )
	T.Equal( #batch.spawned, 1, "nothing more before 0.25 s" )
	T.Wait( 0.2 )
	T.Equal( #batch.spawned, 2, "the second after 0.25 s (the unknown id is skipped)" )
	T.Check( IsValid( batch.spawned[ 2 ] ) and batch.spawned[ 2 ]:GetItemId() == "scrap" and batch.spawned[ 2 ]:GetCount() == 3,
		"{ id, count } spawns one stack of count" )
	T.WaitUntil( function() return batch.done end, 2, "the batch finishes" )
	T.Equal( #batch.spawned, 3, "three spawned in all" )
	local first, last = batch.spawned[ 1 ], batch.spawned[ 3 ]
	T.Check( IsValid( first ) and IsValid( last ) and first:GetItemId() == "ration" and last:GetItemId() == "ration", "in list order" )
	for _, e in ipairs( batch.spawned ) do if IsValid( e ) then e:Remove() end end

	local a = Items.SpawnMany( { "ration", "ration", "ration" }, pos )
	local b = Items.SpawnMany( { "scrap", "scrap" }, pos + Vector( 100, 0, 0 ) )
	T.Wait( 0.35 )
	T.Check( #a.spawned == 2 and #b.spawned == 2, "two batches run side by side" )
	T.Check( b.done, "the shorter one is done" )
	hook.GetTable().GR_RoundStart.gr_items_spawn_many()
	T.Wait( 0.4 )
	T.Equal( #a.spawned, 2, "a round start drops what is still queued" )
	for _, e in ipairs( a.spawned ) do if IsValid( e ) then e:Remove() end end
	for _, e in ipairs( b.spawned ) do if IsValid( e ) then e:Remove() end end

	local empty = Items.SpawnMany( {}, pos )
	T.Check( empty.done and #empty.spawned == 0, "an empty list is done at once" )
	bot:Kick()
end
