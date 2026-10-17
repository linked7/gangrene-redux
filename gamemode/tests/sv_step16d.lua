-- Step 16d: breaking locks is physical and loud (step 11.1). The old timed pries are gone; locks
-- have a public Integrity beaten down by melee hits and bullets through the real damage path.
-- Stockpile: about 40 hits, key holders can't hurt it, the first hit alarms the state radio and
-- starts the klaxon, idle recovery after 10 s (the real scheduler), breaking drops 3 rations and is a
-- judgment-wanted break-in, the klaxon stops after its tail, the lock re-forms. Storage crate: about
-- 15 hits, the builder's hits do nothing, breaking it unlocks it and is theft, no alarm or klaxon.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t16d_%'" )

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

	local saved = { reform = Locks.REFORM, tail = Locks.KLAXON_TAIL }
	T.Equal( Locks.REFORM, 120, "a broken lock re-forms after 2 minutes by default" )
	T.Equal( Locks.IDLE, 10, "and recovers after 10 s untouched" )
	T.Check( Locks.SNDLVL >= 120, "every clang carries far (sound level " .. Locks.SNDLVL .. ")" )

	local function bot( name, fate, rank )
		local b = player.CreateNextBot( "t16d_" .. name )
		b:SetRank( rank )
		b:SetStemCells( 10 )
		T.Check( Fates.Take( b, fate ), name .. " takes " .. fate )
		return b
	end
	local function setBones( b, n )
		Econ.Transfer( b, Econ.TREASURY, b:GetBones(), "test" )
		Econ.Transfer( Econ.TREASURY, b, n, "test" )
	end
	-- One blow through the engine's damage path (EntityTakeDamage), like a baton swing.
	local function hit( ent, by, kind, amount )
		local d = DamageInfo()
		d:SetDamage( amount or math.random( 5, 40 ) )
		d:SetDamageType( kind or DMG_CLUB )
		d:SetAttacker( by )
		d:SetInflictor( by )
		d:SetDamagePosition( ent:GetPos() )
		ent:TakeDamageInfo( d )
	end
	local function near( v, want ) return math.abs( v - want ) < 2 end

	T.Wait( 0.2 )
	local p1 = bot( "beater", "prole", RANK_FRIEND )
	local p2 = bot( "builder", "prole", RANK_FRIEND )
	local san = bot( "san", "sanitar", RANK_FRIEND )
	Econ.ResetRound()
	local base = p1:GetPos()
	for _, b in ipairs( { p1, p2, san } ) do b:SetMoveType( MOVETYPE_NONE ) end
	p2:SetPos( base + Vector( 0, -60, 0 ) )
	san:SetPos( base + Vector( 4000, 0, 0 ) ) -- out of sight; the radio still reaches them

	-- The old pries are gone --------------------------------------------------------------------------------

	T.Check( Interact.Get( "stockpile_pry" ) == nil, "no stockpile pry in the C menu" )
	T.Check( Interact.Get( "storage_pry" ) == nil, "no storage crate pry in the C menu" )
	T.Check( Crates.StartPry == nil and Crates.FinishPry == nil and Crates.PRY_TIME == nil, "Crates has no pry" )
	T.Check( Storage.StartPry == nil and Storage.FinishPry == nil and Storage.PRY_TIME == nil, "Storage has no pry" )

	-- The stockpile's lock ----------------------------------------------------------------------------------

	local stockpile = ents.Create( "state_stockpile" )
	stockpile:SetPos( base + Vector( -110, 0, 0 ) )
	stockpile:Spawn()
	T.Check( Locks.All()[ stockpile ] == true, "the stockpile is in the lock registry" )
	T.Equal( stockpile:GetIntegrity(), 40, "its lock starts whole at 40 (public Integrity)" )
	T.Check( Locks.HasLock( stockpile ), "it has a lock" )
	T.Check( Locks.CanBeat( p1, stockpile ) and not Locks.CanBeat( san, stockpile ), "proles may beat it, key holders not" )

	told = {}
	for _ = 1, 5 do hit( stockpile, san ) end
	T.Equal( stockpile:GetIntegrity(), 40, "a sanitar's blows do nothing to it" )
	T.Check( not Locks.KlaxonOn( stockpile ) and not wasTold( san, "ALARM" ), "and raise no alarm" )
	hit( stockpile, p1, DMG_BURN )
	hit( stockpile, p1, DMG_CRUSH )
	T.Equal( stockpile:GetIntegrity(), 40, "fire and thrown props aren't blows" )
	hit( stockpile, game.GetWorld() )
	T.Equal( stockpile:GetIntegrity(), 40, "nor is damage with no player behind it" )

	-- First hit: alarm and klaxon.
	hit( stockpile, p1 )
	T.Equal( stockpile:GetIntegrity(), 39, "a baton hit takes one" )
	T.Check( wasTold( san, "ALARM" ), "the first hit alarms the state radio" )
	T.Check( not wasTold( p2, "ALARM" ), "proles don't hear it" )
	local where = stockpile:GetPos()
	T.Check( wasTold( san, string.format( "(%d, %d, %d)", where.x, where.y, where.z ) ), "the alarm gives the stockpile's location" )
	T.Check( Locks.KlaxonOn( stockpile ), "the klaxon rings at the stockpile" )
	T.Check( not p1:IsWanted(), "beating the lock isn't a break-in yet" )
	told = {}
	hit( stockpile, p1, DMG_BULLET, 1 )
	T.Equal( stockpile:GetIntegrity(), 38, "a bullet takes one too, whatever its damage" )
	T.Check( not wasTold( san, "ALARM" ), "later hits don't alarm again" )

	-- Recovery, on the real scheduler.
	Locks.KLAXON_TAIL = 0.5
	T.Wait( 8.5 )
	T.Equal( stockpile:GetIntegrity(), 38, "no recovery within 10 s of the last hit" )
	T.WaitUntil( function() return stockpile:GetIntegrity() == 40 end, 5, "then +1 a second back to whole" )
	T.WaitUntil( function() return not Locks.KlaxonOn( stockpile ) end, 2.5, "the klaxon stops its tail after full recovery" )
	Locks.KLAXON_TAIL = saved.tail

	-- Recovery logic directly: idle time decides.
	hit( stockpile, p1 )
	T.Check( Locks.KlaxonOn( stockpile ), "a new attack on a whole lock starts the klaxon again" )
	stockpile.GR_LastHit = CurTime() - 9
	Locks.Tick()
	T.Equal( stockpile:GetIntegrity(), 39, "9 s idle: nothing yet" )
	stockpile.GR_LastHit = CurTime() - 10
	Locks.Tick()
	T.Equal( stockpile:GetIntegrity(), 40, "10 s idle: +1" )
	T.Check( Locks.KlaxonOn( stockpile ) and near( stockpile.GR_KlaxonStop - CurTime(), 30 ), "the klaxon runs on 30 s after full recovery" )
	Locks.Reset( stockpile )
	T.Check( not Locks.KlaxonOn( stockpile ), "a reset lock is silent" )

	-- Breaking it.
	for _ = 1, 3 do Econ.Deliver( nil, "ration" ) end
	local stock = Econ.Stock( "ration" )
	Locks.REFORM = 1.5
	told = {}
	local hits = 0
	while stockpile:GetIntegrity() > 0 and hits < 200 do
		hit( stockpile, p1 )
		hits = hits + 1
	end
	T.Equal( hits, 40, "the stockpile lock takes 40 baton hits" )
	T.Check( wasTold( san, "ALARM" ), "the alarm went out on the first of them" )
	T.Check( p1:GetWanted() == WANTED_JUDGMENT and near( Crime.WantedLeft( p1 ), 300 ), "breaking it is judgment-wanted for 300 s" )
	T.Equal( p1:GetWantedReason(), "breaking into the stockpile", "the break-in rule ran" )
	T.Equal( Econ.Stock( "ration" ), stock - 3, "three rations came out of the stock" )
	local loose = 0
	for _, e in ipairs( ents.FindInSphere( stockpile:GetPos(), 150 ) ) do
		if e:GetClass() == "gr_item" and e:GetItemId() == "ration" then
			loose = loose + e:GetCount()
			e:Remove()
		end
	end
	T.Equal( loose, 3, "and lie on the ground" )
	T.Check( Locks.KlaxonOn( stockpile ) and near( stockpile.GR_KlaxonStop - CurTime(), 30 ), "the klaxon rings on for 30 s after the break" )
	T.Check( not Locks.HasLock( stockpile ), "the lock is broken" )
	Crime.ClearWanted( p1 )
	stock = Econ.Stock( "ration" )
	for _ = 1, 5 do hit( stockpile, p1 ) end
	T.Check( stockpile:GetIntegrity() == 0 and not p1:IsWanted() and Econ.Stock( "ration" ) == stock, "blows on a broken lock do nothing" )
	T.WaitUntil( function() return stockpile:GetIntegrity() == 40 end, 4, "the lock re-forms whole (REFORM shortened)" )
	stockpile.GR_KlaxonStop = CurTime()
	Locks.Tick()
	T.Check( not Locks.KlaxonOn( stockpile ), "the klaxon stops when its time is up" )
	Locks.REFORM = saved.reform
	told = {}
	hit( stockpile, p1 )
	T.Check( wasTold( san, "ALARM" ) and Locks.KlaxonOn( stockpile ), "a re-formed lock alarms again on its first hit" )
	Locks.Reset( stockpile )

	-- A storage crate's lock --------------------------------------------------------------------------------

	setBones( p2, 100 )
	local tr = util.TraceLine( { start = p2:EyePos(), endpos = p2:EyePos() + Vector( 0, -60, -100 ), filter = p2 } )
	local box = Build.Place( p2, "storage_crate", tr.HitPos )
	T.Check( IsValid( box ), "p2 builds a storage crate" )
	box:SetMoveType( MOVETYPE_NONE )
	box:SetPos( base + Vector( 40, 0, 10 ) )
	T.Check( box:GetLocked() and box:GetIntegrity() == 15, "it starts locked, its lock whole at 15" )
	T.Check( Locks.CanBeat( p1, box ) and not Locks.CanBeat( p2, box ), "others may beat it, the builder not" )

	told = {}
	for _ = 1, 20 do hit( box, p2 ) end
	T.Check( box:GetIntegrity() == 15 and box:GetLocked(), "the builder's own hits do nothing" )

	for _ = 1, 5 do hit( box, p1 ) end
	T.Equal( box:GetIntegrity(), 10, "others' hits take Integrity" )
	T.Check( not Locks.KlaxonOn( box ), "no klaxon at a storage crate" )
	T.Check( not wasTold( san, "ALARM" ), "and no radio alarm" )
	Storage.SetLocked( p2, box, false )
	T.Check( not Locks.HasLock( box ), "an unlocked crate has no lock to beat" )
	hit( box, p1 )
	T.Check( not Crime.Evidence( p1 ).theft, "and hitting it is nothing" )
	Storage.SetLocked( p2, box, true )
	T.Equal( box:GetIntegrity(), 15, "locking it again fits a whole new lock" )

	hits = 0
	while box:GetLocked() and hits < 100 do
		hit( box, p1 )
		hits = hits + 1
	end
	T.Equal( hits, 15, "a storage crate's lock takes 15 baton hits" )
	T.Check( not box:GetLocked(), "breaking it unlocks the crate" )
	T.Check( Crime.Evidence( p1 ).theft ~= nil, "and is reported as theft" )
	T.Check( not p1:IsWanted(), "unseen theft is evidence, not a break-in" )
	T.Check( not wasTold( san, "ALARM" ) and not Locks.KlaxonOn( box ), "still no alarm, no klaxon" )
	T.Check( Storage.CanOpen( p1, box ), "anyone can open it now" )
	Crime.TakeEvidence( p1, "theft" )

	T.Equal( ( Econ.Audit() ), 0, "no drift" )

	-- Cleanup
	for _, e in ipairs( { box, stockpile } ) do if IsValid( e ) then e:Remove() end end
	Locks.REFORM, Locks.KLAXON_TAIL = saved.reform, saved.tail
	Notify = realNotify
end
