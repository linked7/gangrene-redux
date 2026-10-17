-- Bodies on the ground. Every player ragdoll is a corpse record in one registry (P2): added when
-- made, dropped on EntityRemoved, so nothing ever searches with FindByClass.
--
-- A record's state is one of:
--   "unconscious"  the player passed out and is alive; the body wakes up (sh_consciousness.lua)
--   "bleedout"     the player is downed: dead, watching a dark screen, can still be revived
--   "dead"         the player is a ghost now; the body despawns after DECAY seconds
--
-- Leaving "bleedout": Corpse.Revive (the one revive path, R2), Corpse.FinishOff, or the timer.
-- Other systems listen to:
--   GR_PlayerDowned( ply, rag )             move inventory and bones onto rag.GR_Corpse
--   GR_PlayerRevived( ply, rag, reviver )   move them back
--   GR_FinishedOff( victim, attacker, rag ) judge the killing
--   GR_CorpseRemoved( rag )                 whatever the body still holds goes back to the world
Corpse = Corpse or {}

State.Field( "BleedoutUntil", "Float", 0, State.OWNER, 0 )

if CLIENT then
	hook.Add( "HUDPaint", "gr_corpse", function()
		local ply = LocalPlayer()
		local left = ply:GetBleedoutUntil() - CurTime()
		if ply:Alive() or left <= 0 then return end
		surface.SetDrawColor( 0, 0, 0, 255 )
		surface.DrawRect( 0, 0, ScrW(), ScrH() )
		draw.SimpleText( "You are bleeding out.", "DermaLarge", ScrW() / 2, ScrH() / 2, Color( 150, 20, 20 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		draw.SimpleText( math.ceil( left ), "DermaLarge", ScrW() / 2, ScrH() / 2 + 40, Color( 90, 90, 90 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end )
	return
end

Corpse.BLEEDOUT = 60     -- seconds a downed player waits for a korpsman
Corpse.DECAY = 300       -- seconds a dead body lies before it despawns
Corpse.REVIVE_TIME = 5   -- seconds a korpsman works on the body
Corpse.REVIVE_HEALTH = 10

local registry = {}      -- rag -> record

function Corpse.All() return registry end
function Corpse.Get( rag ) return registry[ rag ] end
function Corpse.Of( ply )
	local rag = ply.GR_Corpse
	if IsValid( rag ) then return rag, registry[ rag ] end
end

local LAST_THOUGHTS = {
	"Not today, not ever.",
	"That's not how I wanted to waste my life.",
	"My flies will miss me.",
	"I can feel Her gaze.",
	"Everything vanishes in a matter of seconds.",
	"What will they do without me?",
	"And things were going so well.",
	"Endless empty.",
}

-- What the body looks like, in the same shape as a fate's Appearance, so a revive restores it.
local function captureLook( ply )
	local look = { model = ply:GetModel(), skin = ply:GetSkin(), bodygroups = {} }
	for i = 0, ply:GetNumBodyGroups() - 1 do
		look.bodygroups[ ply:GetBodygroupName( i ) ] = ply:GetBodygroup( i )
	end
	local race = ply:GetRaceDef()
	look.race = race and race.id
	return look
end

-- A ragdoll posed like the player, thrown by the killing blow.
local function makeRagdoll( ply, force )
	local rag = ents.Create( "prop_ragdoll" )
	rag:SetPos( ply:GetPos() )
	rag:SetAngles( ply:GetAngles() )
	rag:SetModel( ply:GetModel() )
	rag:SetSkin( ply:GetSkin() )
	for i = 0, ply:GetNumBodyGroups() - 1 do rag:SetBodygroup( i, ply:GetBodygroup( i ) ) end
	rag:Spawn()
	rag:Activate()
	rag:SetCollisionGroup( COLLISION_GROUP_WEAPON )

	local vel = ply:GetVelocity()
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum( i )
		local pos, ang = ply:GetBonePosition( rag:TranslatePhysBoneToBone( i ) )
		if IsValid( phys ) and pos then
			phys:SetPos( pos )
			phys:SetAngles( ang )
			phys:SetVelocity( vel )
			if force then phys:ApplyForceCenter( force ) end
		end
	end
	return rag
end

-- Makes the body for `ply` in the given state and registers it.
function Corpse.Create( ply, state, force )
	local f = ply:GetFateDef()
	local rag = makeRagdoll( ply, force )
	local rec = {
		owner = ply,
		ownerKey = DB.Key( ply ),
		fate = f and f.id,
		name = ply:Nick(),
		look = captureLook( ply ),
		state = state,
		inventory = {},
		bones = 0,
		createdAt = CurTime(),
		decayAt = math.huge,
	}
	rag.GR_Corpse = rec
	registry[ rag ] = rec
	ply.GR_Corpse = rag
	return rag, rec
end

-- Lethal damage: the player dies, and the body waits in "bleedout" for help.
function Corpse.Down( ply, dmg )
	local rag, rec = Corpse.Of( ply )
	if rec and rec.state == "unconscious" then
		ply:SetNoDraw( false ) -- the hidden living body is gone now; the ragdoll stays
	else
		rag, rec = Corpse.Create( ply, "bleedout", dmg and dmg:GetDamageForce() )
	end
	rec.state = "bleedout"
	rec.bleedUntil = CurTime() + Corpse.BLEEDOUT

	ply.GR_RespawnAt = math.huge
	ply:SetBleedoutUntil( rec.bleedUntil )
	Notify( ply, LAST_THOUGHTS[ math.random( #LAST_THOUGHTS ) ] )
	hook.Run( "GR_PlayerDowned", ply, rag )
	Log.Debug( "corpse", "%s is downed", ply:Nick() )
	return rag
end

-- The body is beyond help: its player becomes a ghost, and it rots.
function Corpse.Die( rag, reason )
	local rec = registry[ rag ]
	if not rec or rec.state == "dead" then return end
	rec.state = "dead"
	rec.decayAt = CurTime() + Corpse.DECAY
	local ply = rec.owner
	if IsValid( ply ) and ply.GR_Corpse == rag then
		ply.GR_Corpse = nil
		ply:SetBleedoutUntil( 0 )
		Lifecycle.FinalDeath( ply, rec.fate )
	end
	Log.Debug( "corpse", "%s died (%s)", rec.name, reason or "?" )
end

function Corpse.FinishOff( rag, attacker )
	local rec = registry[ rag ]
	if not rec or rec.state ~= "bleedout" then return false end
	-- Judge before the death lands, while the victim still holds their fate.
	if IsValid( rec.owner ) then hook.Run( "GR_FinishedOff", rec.owner, attacker, rag ) end
	Corpse.Die( rag, "finished off" )
	return true
end

-- The one revive path (R2): the same fate, name and body, back where the corpse lies.
function Corpse.Revive( rag, reviver )
	local rec = registry[ rag ]
	if not rec or rec.state ~= "bleedout" then return false end
	local ply = rec.owner
	if not IsValid( ply ) or ply:Alive() or ply.GR_Corpse ~= rag then return false end

	ply.GR_Reviving = rag
	ply:Spawn() -- GM:PlayerSpawn sees GR_Reviving and calls Corpse.Restore
	return true
end

function Corpse.Restore( ply, rag )
	local rec = registry[ rag ]
	Fates.Apply( ply, rec.fate, { reason = "revive", identity = { name = rec.name, look = rec.look } } )
	ply:SetPos( rag:GetPos() + Vector( 0, 0, 8 ) )
	ply:SetHealth( Corpse.REVIVE_HEALTH )
	ply:SetBleedoutUntil( 0 )
	ply.GR_Corpse = nil
	rec.state = "revived"
	hook.Run( "GR_PlayerRevived", ply, rag, rec.reviver )
	rag:Remove()
	Log.Debug( "corpse", "%s is revived", ply:Nick() )
end

-- A korpsman (or anyone with CanRevive) working on a downed body: a timed action.
function Corpse.StartRevive( ply, rag )
	local rec = registry[ rag ]
	if not rec or rec.state ~= "bleedout" or not ply:FateHas( "CanRevive" ) or ply:IsGhost() then return false end
	return Actions.Start( ply, "revive", rag, Corpse.REVIVE_TIME, {
		label = "Reviving " .. rec.name,
		canContinue = function() return rec.state == "bleedout" end,
		onDone = function( doctor )
			rec.reviver = doctor
			Corpse.Revive( rag, doctor )
		end,
	} )
end

hook.Add( "PlayerUse", "gr_corpse", function( ply, ent )
	if registry[ ent ] and not ply.GR_Action then Corpse.StartRevive( ply, ent ) end
end )

-- Hitting a downed body with a weapon finishes it off. Damage to an unconscious body lands on
-- its (hidden, living) player.
hook.Add( "EntityTakeDamage", "gr_corpse", function( ent, dmg )
	local rec = registry[ ent ]
	if not rec then return end
	local attacker = dmg:GetAttacker()
	if rec.state == "unconscious" then
		if IsValid( rec.owner ) and rec.owner:Alive() then rec.owner:TakeDamageInfo( dmg ) end
	elseif rec.state == "bleedout" and IsValid( attacker ) and attacker:IsPlayer() and attacker:Alive()
		and bit.band( dmg:GetDamageType(), DMG_CRUSH ) == 0 then
		Corpse.FinishOff( ent, attacker )
	end
end )

hook.Add( "EntityRemoved", "gr_corpse", function( ent )
	local rec = registry[ ent ]
	if not rec then return end
	registry[ ent ] = nil
	hook.Run( "GR_CorpseRemoved", ent )
	-- A body cleaned up while its player still waited on it: they die with it.
	local ply = rec.owner
	if rec.state == "bleedout" and IsValid( ply ) and ply.GR_Corpse == ent then
		ply.GR_Corpse = nil
		ply:SetBleedoutUntil( 0 )
		Lifecycle.FinalDeath( ply, rec.fate )
	end
end )

Sched.Every( "corpses", 0.5, function()
	local now = CurTime()
	for rag, rec in pairs( registry ) do
		if not IsValid( rag ) then
			registry[ rag ] = nil
		elseif rec.state == "bleedout" and now >= rec.bleedUntil then
			Corpse.Die( rag, "bled out" )
		elseif rec.state == "dead" and now >= rec.decayAt then
			rag:Remove()
		end
	end
end )

-- Every death of a living fate goes through here, whether from damage or ply:Kill().
function GM:DoPlayerDeath( ply, attacker, dmg )
	if ply:IsGhost() then return end
	Corpse.Down( ply, dmg )
end

hook.Add( "PlayerDisconnected", "gr_corpse", function( ply )
	local rag, rec = Corpse.Of( ply )
	if not rec then return end
	if rec.state == "unconscious" then
		rag:Remove()
	else
		Corpse.Die( rag, "disconnected" )
	end
end )
