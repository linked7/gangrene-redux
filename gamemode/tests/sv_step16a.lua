-- Step 16a: built things that do something. Factory sites: the 2-per-player cap, anyone working
-- one into a crate stamped with the worker, the 3-crate cap, the builder's kind switch. Storage
-- crates: store and take, the 8-item limit, the lock refusing others, lock/unlock, the pry
-- (cancelled by damage and by moving, then theft), the drop on removal, and the round reset.
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

	local made = {}
	hook.Add( "GR_CrateMade", "t16a", function( ply, crate, station ) table.insert( made, { ply = ply, crate = crate, station = station } ) end )

	local saved = { press = Crates.PRESS_TIME, pry = Storage.PRY_TIME }
	Crates.PRESS_TIME = 0.5
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

	-- Placement caps ---------------------------------------------------------------------------------

	setBones( p1, 200 )
	local site = Build.Place( p1, "factory_site", spot( -50 ) )
	T.Check( IsValid( site ) and site:GetClass() == "factory_site", "a factory site is built" )
	local site2 = Build.Place( p1, "factory_site", spot( 50 ) )
	T.Check( IsValid( site2 ), "a second one is allowed" )
	T.Equal( Build.Count( p1, "factory_site" ), 2, "two sites counted for the builder" )
	local bones = p1:GetBones()
	T.Check( not Build.Place( p1, "factory_site", spot( 0 ) ), "a third site is refused" )
	T.Check( wasTold( p1, "already have 2 factory sites" ), "with the reason" )
	T.Equal( p1:GetBones(), bones, "and nothing was charged" )
	setBones( p2, 100 )
	local tr2 = util.TraceLine( { start = p2:EyePos(), endpos = p2:EyePos() + Vector( 0, -60, -100 ), filter = p2 } )
	local other = Build.Place( p2, "factory_site", tr2.HitPos )
	if IsValid( other ) then
		T.Check( true, "the cap is per player: p2 can still build" )
		T.Equal( Build.Count( p2, "factory_site" ), 1, "p2's count is separate" )
		other:Remove()
	else
		T.Note( "no clear spot in front of p2" )
		T.Equal( Build.Count( p2, "factory_site" ), 0, "p2's count is separate" )
	end
	T.Equal( Build.Count( p1, "factory_site" ), 2, "p1 still has two" )

	T.Equal( site:GetGood(), "ration", "a new site makes rations" )
	T.Equal( site:GetBuiltBy(), DB.Key( p1 ), "the builder's key is networked" )
	T.Check( Build.IsBuilder( p1, site ) and not Build.IsBuilder( p2, site ), "Build.IsBuilder knows the builder" )

	-- Working a factory into a crate -----------------------------------------------------------------

	T.Check( Interact.Get( "factory_work" ).show( p2, site ), "anyone is offered Work the factory" )
	T.Check( Interact.Run( p2, "factory_work", site ), "p2 works p1's site" )
	T.Equal( Actions.Get( p2 ) and Actions.Get( p2 ).kind, "press", "it is the same timed work action" )
	T.WaitUntil( function() return #made >= 1 end, 3, "the site makes a crate" )
	local crate = made[ 1 ].crate
	T.Check( IsValid( crate ) and crate:GetClass() == "ent_crate", "an ent_crate" )
	T.Equal( made[ 1 ].station, site, "made at the site" )
	T.Equal( crate.GR_Kind, "ration", "of the site's kind" )
	T.Equal( crate.GR_MadeBy, DB.Key( p2 ), "stamped with the worker, not the builder" )
	T.Equal( Crates.Waiting( site ), 1, "one crate waiting at the site" )

	-- Kind switch ----------------------------------------------------------------------------------

	local kind = Interact.Get( "factory_kind" )
	T.Check( kind.show( p1, site ) and not kind.show( p2, site ), "only the builder is offered Make..." )
	T.Check( not Interact.Run( p2, "factory_kind", site, "clean_water" ), "p2 can't switch it through the menu" )
	T.Check( not Factory.SetKind( p2, site, "clean_water" ), "nor directly" )
	T.Equal( site:GetGood(), "ration", "still rations" )
	T.Check( Interact.Run( p1, "factory_kind", site, "clean_water" ), "the builder switches it" )
	T.Equal( site:GetGood(), "clean_water", "now clean water" )
	T.Check( not Factory.SetKind( p1, site, "bones" ), "a kind outside Factory.Kinds is refused" )
	T.Check( not Factory.SetKind( p1, site, nil ), "and so is no kind" )
	T.Equal( site:GetGood(), "clean_water", "unchanged" )
	local water = Crates.FinishWork( p1, site )
	T.Equal( water and water.GR_Kind, "clean_water", "the next crate is clean water" )

	-- Crate cap ----------------------------------------------------------------------------------------

	T.Equal( Crates.Waiting( site ), 2, "two waiting" )
	local third = Crates.FinishWork( p2, site )
	T.Check( IsValid( third ), "a third is made" )
	T.Equal( Crates.FinishWork( p2, site ), nil, "a fourth is not" )
	T.Check( not Crates.Work( p2, site ), "and the site refuses work" )
	T.Check( wasTold( p2, "piling up" ), "the worker is told why" )
	T.Equal( Crates.Waiting( site2 ), 0, "the cap is per site" )
	for _, c in ipairs( { crate, water, third } ) do if IsValid( c ) then c:Remove() end end
	T.Wait( 0.1 )
	T.Equal( Crates.Waiting( site ), 0, "hauled away" )

	-- Storage: store and take ------------------------------------------------------------------------------

	local box = Build.Place( p1, "storage_crate", spot( 0 ) )
	T.Check( IsValid( box ) and box:GetClass() == "storage_crate", "a storage crate is built" )
	T.Check( box:GetLocked(), "it starts locked" )
	T.Equal( box:GetBuiltBy(), DB.Key( p1 ), "the builder's key is networked" )
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
	T.Check( not IsValid( site ) and not IsValid( site2 ), "factory sites are gone at round reset" )
	T.Check( not IsValid( box2 ), "so is the storage crate" )
	loose = 0
	for _, e in ipairs( ents.FindInSphere( where, 80 ) ) do
		if e:GetClass() == "gr_item" then loose = loose + 1 e:Remove() end
	end
	T.Equal( loose, 0, "and nothing spills into the new round" )
	T.Equal( Build.Count( p1, "factory_site" ), 0, "the builder's cap is free again" )
	T.Equal( ( Econ.Audit() ), 0, "no drift" )

	-- Cleanup
	for _, m in ipairs( made ) do if IsValid( m.crate ) then m.crate:Remove() end end
	Crates.PRESS_TIME, Storage.PRY_TIME = saved.press, saved.pry
	hook.Remove( "GR_CrateMade", "t16a" )
	Notify = realNotify
end
