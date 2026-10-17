-- Step 7: damage pipeline, consciousness, downed / revive / finish off / bleed out, corpse registry.
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
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t7_%'" )
	local b, a, k = prole( "t7_victim" ), prole( "t7_attacker" ), prole( "t7_medic" )
	T.Wait( 0.3 )
	Fates.Take( b, "prole" ) Fates.Take( a, "prole" ) Fates.Take( k, "korpsman" )

	-- Pipeline order and blocking.
	local seen = {}
	for _, stage in ipairs( Damage.STAGES ) do
		Damage.Add( stage, "t7_trace", function() table.insert( seen, stage ) end )
	end
	hit( b, a, 10 )
	-- The Health stage's own hook applies a non-lethal hit and stops there.
	T.Equal( table.concat( seen, "," ), "Scale,Armor,Consciousness", "stages run in order" )
	for _, stage in ipairs( Damage.STAGES ) do Damage.Remove( stage, "t7_trace" ) end
	T.Equal( b:Health(), 90, "plain hit takes health" )

	Damage.Add( "Scale", "t7_block", function() return true end )
	hit( b, a, 50 )
	Damage.Remove( "Scale", "t7_block" )
	T.Equal( b:Health(), 90, "a hook can block a hit" )

	b:SetArmor( 50 )
	hit( b, a, 20 )
	T.Equal( b:Armor(), 38, "armor soaks 60% and wears down" )
	T.Equal( b:Health(), 82, "the rest reaches health" )
	b:SetArmor( 0 )

	-- Consciousness: blunt hits knock out, and the body wakes up on its own.
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
	T.Wait( 0.1 )
	T.Equal( count( Corpse.All() ), 0, "registry is empty again" )

	-- Lethal damage downs: the body holds what the player carried.
	local carried
	hook.Add( "GR_PlayerDowned", "t7", function( ply, r ) r.GR_Corpse.inventory = { ration = 2 } end )
	hook.Add( "GR_PlayerRevived", "t7", function( ply, r ) carried = r.GR_Corpse.inventory end )
	local nameBefore, modelBefore = b:Nick(), b:GetModel()
	b:SetHealth( 100 )
	hit( b, a, 500 )
	T.Check( not b:Alive(), "lethal damage kills" )
	rag, rec = Corpse.Of( b )
	T.Check( rec ~= nil and rec.state == "bleedout", "the body is downed, not dead" )
	T.Check( b:GetBleedoutUntil() > CurTime(), "the player sees a bleed-out timer" )
	T.Wait( 3.5 )
	T.Check( not b:Alive(), "a downed player doesn't respawn on their own" )

	-- A revive is a timed action; walking away cancels it.
	k:SetPos( rag:GetPos() + Vector( 30, 0, 0 ) )
	T.Check( not Corpse.StartRevive( a, rag ), "a prole can't revive" )
	T.Check( Corpse.StartRevive( k, rag ), "a korpsman starts reviving" )
	T.Check( k:GetActionEnd() > CurTime(), "the action shows a progress bar" )
	T.Wait( 1 )
	k:SetPos( rag:GetPos() + Vector( 2000, 0, 0 ) )
	T.WaitUntil( function() return Actions.Get( k ) == nil end, 2, "moving away cancels the revive" )
	T.Wait( Corpse.REVIVE_TIME )
	T.Check( not b:Alive(), "a cancelled revive does nothing" )

	k:SetPos( rag:GetPos() + Vector( 30, 0, 0 ) )
	local ragPos = rag:GetPos()
	Corpse.StartRevive( k, rag )
	T.WaitUntil( function() return b:Alive() end, Corpse.REVIVE_TIME + 2, "the revive finishes" )
	T.Equal( b:GetFateDef().id, "prole", "revived into the same fate" )
	T.Equal( b:Nick(), nameBefore, "same name" )
	T.Equal( b:GetModel(), modelBefore, "same body" )
	T.Equal( b:Health(), Corpse.REVIVE_HEALTH, "revived weak" )
	T.Check( carried ~= nil and carried.ration == 2, "the corpse's inventory came back" )
	T.Check( b:GetPos():DistToSqr( ragPos ) < 100 * 100, "revived where the body lay" )
	T.Wait( 0.1 )
	T.Equal( count( Corpse.All() ), 0, "the revived body leaves the registry" )

	-- Finishing off: a weapon on a downed body ends it.
	local judged
	hook.Add( "GR_FinishedOff", "t7", function( victim, attacker ) judged = { victim, attacker, victim:GetFateDef().id } end )
	hit( b, a, 500 )
	rag = Corpse.Of( b )
	hit( rag, a, 10 )
	T.Check( judged ~= nil and judged[ 1 ] == b and judged[ 2 ] == a, "finishing off is reported with victim and attacker" )
	T.Equal( judged and judged[ 3 ], "prole", "the victim still holds their fate when judged" )
	T.Equal( Corpse.Get( rag ).state, "dead", "the body is dead" )
	T.WaitUntil( function() return b:Alive() end, 3, "finished-off player comes back" )
	T.Check( b:IsGhost(), "as a ghost" )
	T.Check( b:GetCooldown_prole() > CurTime(), "the fate's cooldown starts at the final death" )
	T.Check( not Corpse.StartRevive( k, rag ), "a dead body can't be revived" )

	-- Bleeding out: the timer ends the same way.
	local c = prole( "t7_bleeder" )
	T.Wait( 0.2 )
	Fates.Take( c, "prole" )
	Corpse.BLEEDOUT = 1
	hit( c, a, 500 )
	Corpse.BLEEDOUT = 60
	T.WaitUntil( function() return c:Alive() end, 4, "bleeding out ends in a respawn" )
	T.Check( c:IsGhost(), "as a ghost" )

	-- Dead bodies despawn and leave the registry.
	for r, rr in pairs( Corpse.All() ) do rr.decayAt = CurTime() end
	T.WaitUntil( function() return count( Corpse.All() ) == 0 end, 2, "dead bodies despawn" )

	-- "Never calls FindByClass" is enforced for all code by tools/check_syntax.sh.
	hook.Remove( "GR_PlayerDowned", "t7" ) hook.Remove( "GR_PlayerRevived", "t7" ) hook.Remove( "GR_FinishedOff", "t7" )
end
