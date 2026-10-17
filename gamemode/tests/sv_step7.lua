-- Step 7: damage pipeline, consciousness, downed (wounded / dying), get up Injured, revive,
-- finish off, bleed out, corpse registry.
local function hit( victim, attacker, amount, kind )
	local d = DamageInfo()
	d:SetDamage( amount )
	d:SetDamageType( kind or DMG_BULLET )
	d:SetAttacker( attacker )
	d:SetInflictor( attacker )
	victim:TakeDamageInfo( d )
end

local function count( t )
	local n = 0
	for _ in pairs( t ) do n = n + 1 end
	return n
end

local function prole( name )
	local b = player.CreateNextBot( name )
	b:SetRank( RANK_FRIEND ) b:SetStemCells( 10 )
	return b
end

return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t7b_%'" )
	local b, a, k = prole( "t7b_victim" ), prole( "t7b_attacker" ), prole( "t7b_medic" )
	local c, v2, v3, v4 = prole( "t7b_second" ), prole( "t7b_overkill" ), prole( "t7b_finw" ), prole( "t7b_find" )
	T.Wait( 0.3 )
	Fates.Take( b, "prole" ) Fates.Take( a, "prole" ) Fates.Take( k, "korpsman" ) Fates.Take( c, "prole" )
	Fates.Take( v2, "prole" ) Fates.Take( v3, "prole" ) Fates.Take( v4, "prole" )

	local saved = {
		wake = Config.WakeTime, bleed = Config.BleedoutTime, finish = Config.FinishOffTime,
		revive = Corpse.REVIVE_TIME, regen = Medicine.REGEN_RATE, bullet = Medicine.BULLET_CHANCE,
	}
	Medicine.REGEN_RATE = 0 -- exact health values are checked across waits
	Medicine.BULLET_CHANCE = 0 -- a lodged bullet would cap max health too
	local heal = Medicine.Procedure( "cripplement" )
	local healSaved = { heal.duration, heal.fail }

	-- Who got judged: GR_PlayerKilled is the only place a kill is judged (step 10).
	local judged = {}
	hook.Add( "GR_PlayerKilled", "t7b", function( victim, killer, rag, how )
		table.insert( judged, { victim = victim, killer = killer, how = how, fate = victim:GetFateDef().id } )
	end )
	local revived, gotUp = 0, 0
	hook.Add( "GR_PlayerRevived", "t7b", function() revived = revived + 1 end )
	hook.Add( "GR_PlayerGotUp", "t7b", function() gotUp = gotUp + 1 end )

	-- Pipeline order and blocking.
	local seen = {}
	for _, stage in ipairs( Damage.STAGES ) do
		Damage.Add( stage, "t7b_trace", function() table.insert( seen, stage ) end )
	end
	hit( b, a, 10 )
	-- The Health stage's own hook applies a non-lethal hit and stops there.
	T.Equal( table.concat( seen, "," ), "Scale,Armor,Consciousness", "stages run in order" )
	for _, stage in ipairs( Damage.STAGES ) do Damage.Remove( stage, "t7b_trace" ) end
	T.Equal( b:Health(), 90, "plain hit takes health" )

	Damage.Add( "Scale", "t7b_block", function() return true end )
	hit( b, a, 50 )
	Damage.Remove( "Scale", "t7b_block" )
	T.Equal( b:Health(), 90, "a hook can block a hit" )

	b:SetArmor( 50 )
	hit( b, a, 20 )
	T.Equal( b:Armor(), 38, "armor soaks 60% and wears down" )
	T.Equal( b:Health(), 82, "the rest reaches health" )
	b:SetArmor( 0 )

	-- Consciousness: blunt hits knock out, and the body wakes up on its own, uninjured.
	b:SetHealth( 100 )
	hit( b, a, 40, DMG_CLUB )
	T.Check( b:GetConsciousness() <= 40 and not b:GetPassedOut(), "blunt hit lowers consciousness: " .. b:GetConsciousness() )
	hit( b, a, 30, DMG_CLUB )
	T.Check( b:GetPassedOut(), "consciousness 0 passes out" )
	T.Check( b:Alive(), "passed out is alive" )
	local rag, rec = Corpse.Of( b )
	T.Check( rec ~= nil and rec.state == "unconscious", "an unconscious body is in the registry" )
	T.Check( b:GetNoDraw(), "the player is hidden while the ragdoll lies there" )
	b.GR_Consciousness = Consciousness.WAKE_AT - 0.5
	T.WaitUntil( function() return not b:GetPassedOut() end, 3, "wakes up" )
	T.Check( not IsValid( rag ) or rag:IsMarkedForDeletion(), "the ragdoll is gone after waking" )
	T.Check( not b:GetInjured(), "passing out leaves no injury" )
	T.Wait( 0.1 )
	T.Equal( count( Corpse.All() ), 0, "registry is empty again" )

	-- Wounded: a light hit downs, and the player gets up on their own, Injured ----------------------
	Inventory.Add( b, "ration", 2 )
	local nameBefore, modelBefore = b:Nick(), b:GetModel()
	b:SetHealth( 100 )
	Config.WakeTime = 1.5
	hit( b, a, 100 + Config.LethalOverkill - 1 )
	T.Check( not b:Alive(), "HP 0 downs the player" )
	rag, rec = Corpse.Of( b )
	T.Check( rec ~= nil and rec.state == "downed" and rec.down == "wounded", "a hit under lethal_overkill past 0 is wounded" )
	T.Equal( b:GetDownState(), "wounded", "DownState (SERVER) says wounded" )
	T.Check( rec and rec.downer == a, "the downer is remembered" )
	T.Equal( rec and rec.inventory.ration, 2, "the body holds what the player carried" )
	T.Equal( Inventory.Count( b, "ration" ), 0, "the downed player holds nothing" )
	T.Check( b:GetWakeUntil() > CurTime() and b:GetBleedoutUntil() == 0, "the player sees a get-up timer, not a bleed-out" )
	local ragPos
	T.WaitUntil( function()
		if IsValid( rag ) then ragPos = rag:GetPos() end
		return b:Alive()
	end, 4, "the wounded player gets up after wake_time" )
	T.Equal( b:GetFateDef().id, "prole", "same fate" )
	T.Equal( b:Nick(), nameBefore, "same name" )
	T.Equal( b:GetModel(), modelBefore, "same body" )
	T.Equal( b:Health(), Config.WakeHealth, "gets up at wake HP" )
	T.Check( b:GetInjured(), "and Injured" )
	T.Equal( b:GetMaxHealth(), Config.InjuredMaxHealth, "Injured caps max HP" )
	T.Equal( Inventory.Count( b, "ration" ), 2, "the inventory came back" )
	T.Check( b:GetPos():DistToSqr( ragPos ) < 100 * 100, "gets up where the body lay" )
	T.Equal( b:GetDownState(), "", "DownState is cleared" )
	T.Equal( #judged, 0, "getting up is never judged" )
	T.Check( gotUp == 1 and revived == 0, "getting up is not a revive" )
	T.Wait( 0.1 )
	T.Equal( count( Corpse.All() ), 0, "the body leaves the registry" )
	Config.WakeTime = saved.wake

	-- Injured doesn't wear off; a korpsman's surgery treats it.
	T.Wait( 1.5 )
	T.Check( b:GetInjured(), "Injured doesn't wear off" )
	heal.duration, heal.fail = 0.3, 0
	b:SetHealth( Config.InjuredMaxHealth )
	k:SetPos( b:GetPos() + Vector( 40, 0, 0 ) )
	T.Check( Medicine.StartSurgery( k, b, "cripplement" ), "surgery is offered for an Injured body even at its capped max" )
	T.WaitUntil( function() return not b:GetInjured() end, 2, "the korpsman's treatment clears Injured" )
	T.Equal( b:GetMaxHealth(), 100, "max HP is back" )
	T.Equal( b:Health(), 100, "and the wounds are stitched" )

	-- Revive while wounded: no Injured afterwards, inventory intact ----------------------------------
	local revive = function( victim, body, label )
		k:SetPos( body:GetPos() + Vector( 30, 0, 0 ) )
		T.Check( Corpse.StartRevive( k, body ), label .. ": a korpsman starts reviving" )
		T.WaitUntil( function()
			if IsValid( body ) then k:SetPos( body:GetPos() + Vector( 30, 0, 0 ) ) end
			return victim:Alive()
		end, Corpse.REVIVE_TIME + 2, label .. ": the revive finishes" )
	end
	b:SetHealth( 100 )
	Corpse.SetInjured( b, true ) -- as if they had got up before
	hit( b, a, 60 )
	rag, rec = Corpse.Of( b )
	T.Check( rec and rec.down == "wounded", "downed wounded again" )
	T.Check( not Corpse.StartRevive( a, rag ), "a prole can't revive" )
	Corpse.REVIVE_TIME = 0.5
	revive( b, rag, "wounded" )
	T.Equal( b:Health(), Corpse.REVIVE_HEALTH, "revived weak" )
	T.Check( not b:GetInjured(), "a revived player has no Injured" )
	T.Equal( b:GetMaxHealth(), 100, "and full max HP" )
	T.Equal( Inventory.Count( b, "ration" ), 2, "revive keeps the inventory (wounded)" )
	T.Equal( revived, 1, "a revive is a revive" )

	-- Dying: a hit lethal_overkill past 0 ---------------------------------------------------------
	b:SetHealth( 100 )
	hit( b, a, 100 + Config.LethalOverkill )
	rag, rec = Corpse.Of( b )
	T.Check( rec and rec.state == "downed" and rec.down == "dying", "a hit lethal_overkill past 0 is dying" )
	T.Equal( b:GetDownState(), "dying", "DownState says dying" )
	T.Check( b:GetBleedoutUntil() > CurTime() and b:GetWakeUntil() == 0, "the player sees a bleed-out timer" )
	T.Wait( 3.5 )
	T.Check( not b:Alive(), "a dying player doesn't respawn on their own" )
	-- A stray hit on a downed body no longer finishes it off.
	hit( rag, a, 10 )
	T.Check( rec.state == "downed" and #judged == 0, "a weapon hit on a dying body doesn't finish it" )

	-- A revive is a timed action; walking away cancels it.
	Corpse.REVIVE_TIME = 2
	k:SetPos( rag:GetPos() + Vector( 30, 0, 0 ) )
	T.Check( Corpse.StartRevive( k, rag ), "a korpsman starts reviving" )
	T.Check( k:GetActionEnd() > CurTime(), "the action shows a progress bar" )
	T.Wait( 0.5 )
	k:SetPos( rag:GetPos() + Vector( 2000, 0, 0 ) )
	T.WaitUntil( function() return Actions.Get( k ) == nil end, 2, "moving away cancels the revive" )
	T.Wait( Corpse.REVIVE_TIME )
	T.Check( not b:Alive(), "a cancelled revive does nothing" )
	Corpse.REVIVE_TIME = 0.5
	revive( b, rag, "dying" )
	T.Equal( Inventory.Count( b, "ration" ), 2, "revive keeps the inventory (dying)" )
	T.Check( not b:GetInjured(), "no Injured after a revive from dying" )
	T.Wait( 0.1 )
	T.Equal( count( Corpse.All() ), 0, "the revived body leaves the registry" )

	-- A second hit on a wounded body makes it dying; it bleeds out and the downer is judged ----------
	b:SetHealth( 100 )
	hit( b, a, 105 )
	rag, rec = Corpse.Of( b )
	T.Check( rec and rec.down == "wounded", "wounded first" )
	T.Wait( 0.1 )
	Config.BleedoutTime = 1
	hit( rag, c, 5 )
	Config.BleedoutTime = saved.bleed
	T.Equal( rec.down, "dying", "any damage to a wounded body makes it dying" )
	T.Equal( b:GetDownState(), "dying", "DownState follows" )
	T.Check( rec.downer == c, "whoever made it dying is the one judged" )
	T.WaitUntil( function() return b:Alive() end, 4, "a dying player bleeds out and comes back" )
	T.Check( b:IsGhost(), "as a ghost" )
	T.Check( #judged == 1 and judged[ 1 ].victim == b and judged[ 1 ].killer == c and judged[ 1 ].how == "bled out",
		"bleeding out judges the downer" )
	T.Equal( judged[ 1 ] and judged[ 1 ].fate, "prole", "the victim still holds their fate when judged" )
	T.Equal( c:GetWantedReason(), "murder", "Crime.Judge ran against the downer" )
	T.Check( b:GetCooldown_prole() > CurTime(), "the fate's cooldown starts at the final death" )
	T.Check( not Corpse.StartRevive( k, rag ), "a dead body can't be revived" )
	Crime.ClearWanted( c )

	-- Overkill straight to dying, then bleed out.
	Config.BleedoutTime = 1
	hit( v2, a, 500 )
	Config.BleedoutTime = saved.bleed
	T.WaitUntil( function() return v2:Alive() end, 4, "an overkill hit bleeds out" )
	T.Check( v2:IsGhost() and #judged == 2 and judged[ 2 ].killer == a, "and the downer is judged" )
	Crime.ClearWanted( a ) Needs.Add( a, "Despair", -100, "test" ) -- three murders would stop a heart

	-- Finish off: an explicit timed context action, in either state -------------------------------
	Config.FinishOffTime = 0.3
	local function finishOff( victim, label )
		local body = Corpse.Of( victim )
		T.Wait( 1 ) -- let the thrown body settle
		a:SetPos( body:GetPos() + Vector( 30, 0, 0 ) )
		local n = #judged
		T.Check( not Interact.Run( victim, "finish_off", body ), label .. ": the dead can't use it" )
		T.Check( Interact.Run( a, "finish_off", body ), label .. ": finish off is a context action" )
		T.Check( Actions.Get( a ) ~= nil and #judged == n, label .. ": it takes time" )
		-- A ragdoll can still roll; keep the attacker beside it so the action stays in range.
		T.WaitUntil( function()
			if IsValid( body ) then a:SetPos( body:GetPos() + Vector( 30, 0, 0 ) ) end
			return #judged > n
		end, 2, label .. ": finish off lands" )
		local j = judged[ #judged ]
		T.Check( j.victim == victim and j.killer == a and j.how == "finished off" and j.fate == "prole",
			label .. ": finishing off is judged with victim and attacker" )
		T.Equal( Corpse.Get( body ).state, "dead", label .. ": the body is dead" )
		T.WaitUntil( function() return victim:Alive() end, 3, label .. ": finished-off player comes back" )
		T.Check( victim:IsGhost(), label .. ": as a ghost" )
		Crime.ClearWanted( a ) Needs.Add( a, "Despair", -100, "test" ) -- three murders would stop a heart
	end
	hit( v3, a, 105 )
	T.Equal( select( 2, Corpse.Of( v3 ) ).down, "wounded", "v3 is wounded" )
	finishOff( v3, "wounded" )
	hit( v4, a, 500 )
	T.Equal( select( 2, Corpse.Of( v4 ) ).down, "dying", "v4 is dying" )
	finishOff( v4, "dying" )

	T.Check( hook.Run( "CanPlayerSuicide", c ) == false, "no suicide" )
	-- ply:Kill() has no overkill to measure: dying.
	c:Kill()
	T.Equal( select( 2, Corpse.Of( c ) ).down, "dying", "ply:Kill() is dying" )
	Corpse.Die( Corpse.Of( c ), "test" )

	-- Dead bodies despawn and leave the registry.
	for _, rr in pairs( Corpse.All() ) do rr.decayAt = CurTime() end
	T.WaitUntil( function() return count( Corpse.All() ) == 0 end, 2, "dead bodies despawn" )

	-- "Never calls FindByClass" is enforced for all code by tools/check_syntax.sh.
	Config.FinishOffTime = saved.finish
	Corpse.REVIVE_TIME = saved.revive
	Medicine.REGEN_RATE = saved.regen
	Medicine.BULLET_CHANCE = saved.bullet
	heal.duration, heal.fail = healSaved[ 1 ], healSaved[ 2 ]
	hook.Remove( "GR_PlayerKilled", "t7b" )
	hook.Remove( "GR_PlayerRevived", "t7b" )
	hook.Remove( "GR_PlayerGotUp", "t7b" )
end
