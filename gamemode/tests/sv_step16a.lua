-- Step 16a: built things that do something. Factory sites are dropped (players can't build
-- production), so only their absence is checked. Storage crates: store and take, the 8-item limit,
-- the lock refusing others, lock/unlock, the pry (cancelled by damage and by moving, then theft),
-- the drop on removal, and the round reset.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t16a_%'" )

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

	local saved = { pry = Storage.PRY_TIME }
	Storage.PRY_TIME = 0.5

	local function bot( name, fate, rank )
		local b = player.CreateNextBot( "t16a_" .. name )
		b:SetRank( rank )
		b:SetStemCells( 10 )
		T.Check( Fates.Take( b, fate ), name .. " takes " .. fate )
		return b
	end
	local function setBones( b, n )
		Econ.Transfer( b, Econ.TREASURY, b:GetBones(), "test" )
		Econ.Transfer( Econ.TREASURY, b, n, "test" )
	end

	T.Wait( 0.2 )
	local p1 = bot( "builder", "prole", RANK_FRIEND )
	local p2 = bot( "other", "prole", RANK_FRIEND )
	Econ.ResetRound()
	local base = p1:GetPos()
	for _, b in ipairs( { p1, p2 } ) do b:SetMoveType( MOVETYPE_NONE ) end
	p2:SetPos( base + Vector( 0, -40, 0 ) )

	local function spot( dx )
		local tr = util.TraceLine( { start = p1:EyePos(), endpos = p1:EyePos() + Vector( dx, 60, -100 ), filter = p1 } )
		return tr.HitPos
	end

	setBones( p1, 200 )
	T.Check( not Build.KINDS.factory_site and not table.HasValue( Build.ORDER, "factory_site" ), "factory sites are gone from Build" )
	T.Check( not scripted_ents.GetStored( "factory_site" ), "and the entity is gone" )
	T.Check( not Build.Place( p1, "factory_site", spot( 0 ) ), "so one can't be placed" )
	T.Equal( p1:GetBones(), 200, "and nothing was charged" )

	-- Storage: store and take ------------------------------------------------------------------------------

	local box = Build.Place( p1, "storage_crate", spot( 0 ) )
	T.Check( IsValid( box ) and box:GetClass() == "storage_crate", "a storage crate is built" )
	T.Check( box:GetLocked(), "it starts locked" )
	T.Equal( box:GetBuiltBy(), DB.Key( p1 ), "the builder's key is networked" )
	T.Check( Build.IsBuilder( p1, box ) and not Build.IsBuilder( p2, box ), "Build.IsBuilder knows the builder" )
	box:SetMoveType( MOVETYPE_NONE ) -- keep it where the bots can reach it
	box:SetPos( base + Vector( 40, 0, 10 ) )

	Inventory.Add( p1, "ration", 9, true )
	local had = Inventory.Count( p1, "ration" )
	T.Check( Interact.Get( "storage_store" ).show( p1, box ), "the builder is offered Store..." )
	T.Check( Interact.Run( p1, "storage_store", box, "ration" ), "the builder stores a ration" )
	T.Equal( Inventory.Count( p1, "ration" ), had - 1, "it left the inventory" )
	T.Equal( Storage.Total( box ), 1, "and is in the crate" )
	T.Equal( box:GetContents(), "ration=1", "the contents are mirrored for the menu" )
	for _ = 1, 7 do Storage.Put( p1, box, "ration" ) end
	T.Equal( Storage.Total( box ), Storage.CAPACITY, "filled to capacity" )
	T.Check( not Storage.Put( p1, box, "ration" ), "a ninth item is refused" )
	T.Check( wasTold( p1, "full" ), "the crate is full" )
	T.Equal( Inventory.Count( p1, "ration" ), had - 8, "and stays in the inventory" )
	T.Check( not Storage.Put( p1, box, "pickaxe_of_dreams" ), "items you don't have are refused" )
	T.Check( Interact.Get( "storage_take" ).show( p1, box ), "the builder is offered Take..." )
	T.Check( Interact.Run( p1, "storage_take", box, "ration" ), "the builder takes one back" )
	T.Equal( Storage.Total( box ), 7, "seven left inside" )
	T.Equal( Inventory.Count( p1, "ration" ), had - 7, "one came back" )
	T.Check( not Storage.Take( p1, box, "clean_water" ), "taking what isn't there is refused" )

	-- The lock -----------------------------------------------------------------------------------------------

	T.Check( not Interact.Get( "storage_take" ).show( p2, box ), "others aren't offered Take on a locked crate" )
	T.Check( not Interact.Get( "storage_store" ).show( p2, box ), "nor Store" )
	T.Check( not Interact.Run( p2, "storage_take", box, "ration" ), "the menu path refuses them" )
	T.Check( not Storage.Take( p2, box, "ration" ), "taking from a locked crate is refused" )
	T.Check( wasTold( p2, "locked" ), "they are told it is locked" )
	Inventory.Add( p2, "ration", 1, true )
	T.Check( not Storage.Put( p2, box, "ration" ), "so is storing" )
	T.Equal( Storage.Total( box ), 7, "nothing moved" )
	T.Check( not Interact.Get( "storage_lock" ).show( p2, box ), "others can't lock or unlock it" )
	T.Check( not Storage.SetLocked( p2, box, false ), "not even directly" )
	T.Check( box:GetLocked(), "still locked" )

	T.Check( Interact.Run( p1, "storage_lock", box ), "the builder unlocks it" )
	T.Check( not box:GetLocked(), "unlocked" )
	T.Check( Storage.Take( p2, box, "ration" ), "now anyone can take" )
	T.Equal( Storage.Total( box ), 6, "six left" )
	T.Check( not Interact.Get( "storage_pry" ).show( p2, box ), "an unlocked crate isn't offered for prying" )
	T.Check( Interact.Run( p1, "storage_lock", box ), "the builder locks it again" )
	T.Check( box:GetLocked(), "locked" )

	-- Pry --------------------------------------------------------------------------------------------------

	local pry = Interact.Get( "storage_pry" )
	T.Check( not pry.show( p1, box ), "the builder isn't offered the pry" )
	T.Check( not Storage.StartPry( p1, box ), "and can't pry their own crate" )
	T.Check( pry.show( p2, box ), "others are" )

	T.Check( Interact.Run( p2, "storage_pry", box ), "p2 starts prying" )
	T.Equal( Actions.Get( p2 ) and Actions.Get( p2 ).kind, "storage_pry", "a timed action" )
	p2:TakeDamage( 1 )
	T.Check( Actions.Get( p2 ) == nil, "taking damage stops it" )
	T.Check( box:GetLocked(), "still locked" )
	p2:SetHealth( p2:GetMaxHealth() )

	local p2pos = p2:GetPos()
	T.Check( Storage.StartPry( p2, box ), "p2 starts again" )
	p2:SetPos( p2pos + Vector( 0, -40, 0 ) )
	T.WaitUntil( function() return Actions.Get( p2 ) == nil end, 1, "moving stops it" )
	T.Check( box:GetLocked(), "still locked" )
	T.Check( wasTold( p2, "moved" ), "the prier is told why" )
	p2:SetPos( p2pos )

	T.Check( not Crime.Evidence( p2 ).theft, "no theft yet" )
	T.Check( Storage.StartPry( p2, box ), "p2 pries for real" )
	T.WaitUntil( function() return not box:GetLocked() end, 3, "a finished pry unlocks the crate" )
	T.Check( Crime.Evidence( p2 ).theft ~= nil, "prying someone's crate is reported as theft" )
	T.Check( Storage.Take( p2, box, "ration" ), "and its contents are there for the taking" )
	T.Equal( Storage.Total( box ), 5, "five left" )
	Crime.TakeEvidence( p2, "theft" )

	-- Drop on removal ----------------------------------------------------------------------------------------

	local where = box:GetPos()
	box:Remove()
	T.Wait( 0.2 )
	local loose = 0
	for _, e in ipairs( ents.FindInSphere( where, 80 ) ) do
		if e:GetClass() == "gr_item" and e:GetItemId() == "ration" then
			loose = loose + e:GetCount()
			e:Remove()
		end
	end
	T.Equal( loose, 5, "removing the crate drops its five rations" )

	-- Round reset ----------------------------------------------------------------------------------------------

	setBones( p1, 100 )
	local box2 = Build.Place( p1, "storage_crate", spot( 0 ) )
	T.Check( IsValid( box2 ), "another storage crate" )
	box2:SetMoveType( MOVETYPE_NONE )
	Storage.Put( p1, box2, "ration" )
	where = box2:GetPos()
	hook.GetTable().GR_RoundStart.gr_build()
	T.Wait( 0.2 )
	T.Check( not IsValid( box2 ), "so is the storage crate" )
	loose = 0
	for _, e in ipairs( ents.FindInSphere( where, 80 ) ) do
		if e:GetClass() == "gr_item" then loose = loose + 1 e:Remove() end
	end
	T.Equal( loose, 0, "and nothing spills into the new round" )
	T.Equal( ( Econ.Audit() ), 0, "no drift" )

	-- Cleanup
	Storage.PRY_TIME = saved.pry
	Notify = realNotify
end
