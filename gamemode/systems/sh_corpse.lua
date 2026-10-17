-- Bodies on the ground. Every player ragdoll is a corpse record in one registry (P2): added when
-- made, dropped on EntityRemoved, so nothing ever searches with FindByClass.
--
-- A record's state is one of:
--   "unconscious"  the player passed out and is alive; the body wakes up (sh_consciousness.lua)
--   "downed"       HP hit 0: the player is down (engine-dead, dark screen). rec.down says how bad:
--                    "wounded"  the hit went less than Config.LethalOverkill past 0 HP; the player
--                               gets up on their own after Config.WakeTime, Injured
--                    "dying"    the hit went further, or a wounded body was hit again; the player
--                               becomes a ghost after Config.BleedoutTime unless revived
--   "dead"         the player is a ghost now; the body despawns after DECAY seconds
--   "restored"     the player got up or was revived; the body is being removed
--
-- Leaving "downed": Corpse.GetUp (wounded, the timer), Corpse.Revive (the one revive path, R2,
-- either state), Corpse.FinishOff (a timed context action, either state), or bleeding out (dying).
-- Only the last two judge the downer, and only they and Corpse.Die make a ghost.
--
-- The downed state is also the player's SERVER field DownState ("", "wounded", "dying"); the
-- player who downed them is rec.downer. Tunables live in Config (sh_config.lua).
--
-- Other systems listen to:
--   GR_PlayerDowned( ply, rag )               move inventory and bones onto rag.GR_Corpse
--   GR_PlayerRestored( ply, rag, how )        move them back; how = "revive" or "getup"
--   GR_PlayerRevived( ply, rag, reviver )     a korpsman brought them back (after Restored)
--   GR_PlayerGotUp( ply, rag )                a wounded player got up on their own (after Restored)
--   GR_PlayerKilled( victim, killer, rag, how ) judge the killing; how = "finished off" or "bled out".
--                                             killer may be nil. Runs while the victim still holds their fate.
--   GR_CorpseRemoved( rag )                   whatever the body still holds goes back to the world
Corpse = Corpse or {}

State.Field( "BleedoutUntil", "Float", 0, State.OWNER, 0 ) -- dying: when the player becomes a ghost
State.Field( "WakeUntil", "Float", 0, State.OWNER, 0 )     -- wounded: when the player gets up
State.Field( "DownState", "String", 0, State.SERVER, "" )
-- Got up from a wounded down: max health capped at Config.InjuredMaxHealth until a korpsman treats it.
State.Field( "Injured", "Bool", 0, State.PUBLIC, false )

-- The finish-off option on a downed body. sh_interact.lua loads after this file.
local function addInteract()
	Interact.Add( "finish_off", {
		label = "Finish off",
		range = 100,
		show = function( ply, ent )
			if ply:IsGhost() then return false end
			if CLIENT then return ent:GetClass() == "prop_ragdoll" end
			local rec = Corpse.Get( ent )
			return rec ~= nil and rec.state == "downed" and rec.owner ~= ply
		end,
		run = function( ply, ent ) Corpse.StartFinishOff( ply, ent ) end,
	} )
end
if Interact and Interact.Add then addInteract() else hook.Add( "PostGamemodeLoaded", "gr_corpse", addInteract ) end

if CLIENT then
	local function screen( text, left, col )
		surface.SetDrawColor( 0, 0, 0, 255 )
		surface.DrawRect( 0, 0, ScrW(), ScrH() )
		draw.SimpleText( text, "DermaLarge", ScrW() / 2, ScrH() / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		draw.SimpleText( math.ceil( left ), "DermaLarge", ScrW() / 2, ScrH() / 2 + 40, Color( 90, 90, 90 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end
	hook.Add( "HUDPaint", "gr_corpse", function()
		local ply = LocalPlayer()
		if ply:Alive() then return end
		local bleed = ply:GetBleedoutUntil() - CurTime()
		local wake = ply:GetWakeUntil() - CurTime()
		if bleed > 0 then
			screen( "You are bleeding out.", bleed, Color( 150, 20, 20 ) )
		elseif wake > 0 then
			screen( "You are down. You will get up.", wake, Color( 120, 120, 120 ) )
		end
	end )
	return
end

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

-- A ragdoll posed like the player, thrown by the downing blow.
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

-- The damage pipeline's Health stage notes a lethal hit here just before the engine kills, so
-- Corpse.Down can tell how far past 0 HP it went and who dealt it.
function Corpse.NoteLethalHit( ply, overkill, attacker )
	ply.GR_LethalHit = { overkill = overkill, attacker = attacker, at = CurTime() }
end

local function playerOrNil( ent, except )
	if IsValid( ent ) and ent:IsPlayer() and ent ~= except then return ent end
end

-- Puts a downed record into `down` ("wounded" or "dying") with a fresh timer.
local function setDown( rec, down )
	local ply = rec.owner
	rec.down = down
	local untilTime = CurTime() + ( down == "dying" and Config.BleedoutTime or Config.WakeTime )
	rec.downUntil = untilTime
	if not IsValid( ply ) then return end
	ply:SetDownState( down )
	ply:SetBleedoutUntil( down == "dying" and untilTime or 0 )
	ply:SetWakeUntil( down == "wounded" and untilTime or 0 )
end

-- HP 0: the player goes down. A hit without a noted overkill (ply:Kill(), a heart attack) is dying.
function Corpse.Down( ply, dmg, attacker )
	local hit = ply.GR_LethalHit
	ply.GR_LethalHit = nil
	if hit and hit.at ~= CurTime() then hit = nil end
	local overkill = hit and hit.overkill or math.huge

	local rag, rec = Corpse.Of( ply )
	if rec and rec.state == "unconscious" then
		ply:SetNoDraw( false ) -- the hidden living body is gone now; the ragdoll stays
		ply:SetPassedOut( false )
	else
		rag, rec = Corpse.Create( ply, "downed", dmg and dmg:GetDamageForce() )
	end
	rec.state = "downed"
	rec.downedAt = CurTime()
	rec.downer = playerOrNil( hit and hit.attacker or attacker, ply )
	setDown( rec, overkill >= Config.LethalOverkill and "dying" or "wounded" )

	ply.GR_RespawnAt = math.huge
	Notify( ply, LAST_THOUGHTS[ math.random( #LAST_THOUGHTS ) ] )
	hook.Run( "GR_PlayerDowned", ply, rag )
	Log.Debug( "corpse", "%s is downed (%s, overkill %s)", ply:Nick(), rec.down, tostring( overkill ) )
	return rag
end

-- A wounded body that takes any more damage is dying. Whoever made it so is the one judged later.
function Corpse.Worsen( rag, attacker )
	local rec = registry[ rag ]
	if not rec or rec.state ~= "downed" or rec.down ~= "wounded" then return false end
	rec.downer = playerOrNil( attacker, rec.owner ) or rec.downer
	setDown( rec, "dying" )
	if IsValid( rec.owner ) then Notify( rec.owner, "You are bleeding out." ) end
	Log.Debug( "corpse", "%s is dying", rec.name )
	return true
end

-- The body is beyond help: its player becomes a ghost, and it rots. No judging here; callers
-- that judge (bleeding out, finishing off) do it first.
function Corpse.Die( rag, reason )
	local rec = registry[ rag ]
	if not rec or rec.state == "dead" then return end
	rec.state = "dead"
	rec.decayAt = CurTime() + Corpse.DECAY
	local ply = rec.owner
	if IsValid( ply ) and ply.GR_Corpse == rag then
		ply.GR_Corpse = nil
		ply:SetBleedoutUntil( 0 )
		ply:SetWakeUntil( 0 )
		Lifecycle.FinalDeath( ply, rec.fate )
	end
	Log.Debug( "corpse", "%s died (%s)", rec.name, reason or "?" )
end

-- Judge, then die. Judging comes first, while the victim still holds their fate.
local function kill( rag, rec, killer, how )
	if IsValid( rec.owner ) then hook.Run( "GR_PlayerKilled", rec.owner, killer, rag, how ) end
	Corpse.Die( rag, how )
end

function Corpse.FinishOff( rag, attacker )
	local rec = registry[ rag ]
	if not rec or rec.state ~= "downed" then return false end
	kill( rag, rec, attacker, "finished off" )
	return true
end

-- Finishing off is a short timed action on a downed body (wounded or dying), offered through Interact.
function Corpse.StartFinishOff( ply, rag )
	local rec = registry[ rag ]
	if not rec or rec.state ~= "downed" or rec.owner == ply or ply:IsGhost() or not ply:Alive() then return false end
	return Actions.Start( ply, "finish_off", rag, Config.FinishOffTime, {
		label = "Finishing off " .. rec.name,
		canContinue = function() return rec.state == "downed" end,
		onDone = function( killer ) Corpse.FinishOff( rag, killer ) end,
	} )
end

-- Bringing the player back to the body: the revive and the get-up share this. GM:PlayerSpawn sees
-- GR_Reviving and calls Corpse.Restore.
local function bringBack( rag, how, reviver )
	local rec = registry[ rag ]
	if not rec or rec.state ~= "downed" then return false end
	local ply = rec.owner
	if not IsValid( ply ) or ply:Alive() or ply.GR_Corpse ~= rag then return false end
	rec.how = how
	rec.reviver = reviver
	ply.GR_Reviving = rag
	ply:Spawn()
	return true
end

-- The one revive path (R2): the same fate, name and body, back where the corpse lies. No Injured.
function Corpse.Revive( rag, reviver )
	return bringBack( rag, "revive", reviver )
end

-- A wounded player gets up on their own: not a revive (no reviver, no fee), and they are Injured.
function Corpse.GetUp( rag )
	local rec = registry[ rag ]
	if not rec or rec.down ~= "wounded" then return false end
	return bringBack( rag, "getup" )
end

function Corpse.Restore( ply, rag )
	local rec = registry[ rag ]
	local how = rec.how or "revive"
	Fates.Apply( ply, rec.fate, { reason = how, identity = { name = rec.name, look = rec.look } } )
	ply:SetPos( rag:GetPos() + Vector( 0, 0, 8 ) )
	if how == "getup" then
		Corpse.SetInjured( ply, true )
		ply:SetHealth( math.min( Config.WakeHealth, ply:GetMaxHealth() ) )
	else
		ply:SetHealth( Corpse.REVIVE_HEALTH )
	end
	ply:SetBleedoutUntil( 0 )
	ply:SetWakeUntil( 0 )
	ply:SetDownState( "" )
	ply.GR_Corpse = nil
	rec.state = "restored"
	hook.Run( "GR_PlayerRestored", ply, rag, how )
	if how == "getup" then
		Notify( ply, "You get back up. Something is broken; a korpsman should look at it." )
		hook.Run( "GR_PlayerGotUp", ply, rag )
	else
		hook.Run( "GR_PlayerRevived", ply, rag, rec.reviver )
	end
	rag:Remove()
	Log.Debug( "corpse", "%s is back up (%s)", ply:Nick(), how )
end

-- Injured caps max health (sh_needs.lua's Needs.ApplyPox works the cap out). Surgery clears it.
function Corpse.SetInjured( ply, injured )
	ply:SetInjured( injured )
	Needs.ApplyPox( ply )
end

-- A korpsman (or anyone with CanRevive) working on a downed body: a timed action.
function Corpse.StartRevive( ply, rag )
	local rec = registry[ rag ]
	if not rec or rec.state ~= "downed" or not ply:FateHas( "CanRevive" ) or ply:IsGhost() then return false end
	return Actions.Start( ply, "revive", rag, Corpse.REVIVE_TIME, {
		label = "Reviving " .. rec.name,
		canContinue = function() return rec.state == "downed" end,
		onDone = function( doctor ) Corpse.Revive( rag, doctor ) end,
	} )
end

hook.Add( "PlayerUse", "gr_corpse", function( ply, ent )
	if registry[ ent ] and not ply.GR_Action then Corpse.StartRevive( ply, ent ) end
end )

-- Damage to an unconscious body lands on its (hidden, living) player. Damage to a wounded body
-- makes it dying; plain physics bumps (crush with no player behind it) don't count, nor do the
-- rest of the hits from the same tick that downed it.
hook.Add( "EntityTakeDamage", "gr_corpse", function( ent, dmg )
	local rec = registry[ ent ]
	if not rec then return end
	local attacker = dmg:GetAttacker()
	if rec.state == "unconscious" then
		if IsValid( rec.owner ) and rec.owner:Alive() then rec.owner:TakeDamageInfo( dmg ) end
	elseif rec.state == "downed" and rec.down == "wounded" and dmg:GetDamage() > 0 and CurTime() > rec.downedAt then
		local byPlayer = IsValid( attacker ) and attacker:IsPlayer()
		if byPlayer or bit.band( dmg:GetDamageType(), DMG_CRUSH ) == 0 then Corpse.Worsen( ent, attacker ) end
	end
end )

hook.Add( "EntityRemoved", "gr_corpse", function( ent )
	local rec = registry[ ent ]
	if not rec then return end
	registry[ ent ] = nil
	hook.Run( "GR_CorpseRemoved", ent )
	-- A body cleaned up while its player still waited on it: they die with it (no judging).
	local ply = rec.owner
	if rec.state == "downed" and IsValid( ply ) and ply.GR_Corpse == ent then
		ply.GR_Corpse = nil
		ply:SetBleedoutUntil( 0 )
		ply:SetWakeUntil( 0 )
		Lifecycle.FinalDeath( ply, rec.fate )
	end
end )

-- One corpse tick: a wounded body whose time is up gets up, a dying one bleeds out.
function Corpse.Tick()
	local now = CurTime()
	for rag, rec in pairs( registry ) do
		if not IsValid( rag ) then
			registry[ rag ] = nil
		elseif rec.state == "downed" and now >= rec.downUntil then
			if rec.down == "wounded" then
				if not Corpse.GetUp( rag ) then Corpse.Die( rag, "could not get up" ) end
			else
				kill( rag, rec, rec.downer, "bled out" )
			end
		elseif rec.state == "dead" and now >= rec.decayAt then
			rag:Remove()
		end
	end
end
Sched.Every( "corpses", 0.5, Corpse.Tick )

-- Every death of a living fate goes through here, whether from damage or ply:Kill().
function GM:DoPlayerDeath( ply, attacker, dmg )
	if ply:IsGhost() then return end
	Corpse.Down( ply, dmg, attacker )
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
