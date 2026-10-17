-- Movement and body (§12 of docs/05-ui-effects-parity.md). Speeds themselves are Fates.ApplySpeed's;
-- this file keeps the original's other movement rules:
--
--   Jumping   blocked for 6 + 10 x Emptiness% seconds after a bullet in the leg, while reloading,
--             and while frozen (which also blocks crouching). Pressing jump interrupts surgery.
--             Movement.CanJump( ply ) is checked in StartCommand on both realms, so it predicts.
--   Dragging  "Drag" on a body (sh_corpse.lua: unconscious, downed or dead) pulls it along behind
--             you. Get more than Drag.SNAP (128) units from it and it snaps free with a barnacle
--             tongue sound. The OWNER field Dragging holds the body's entity index (0: nothing).
--   View      the cc_thirdperson client option; ghosts always see themselves in third person.
Movement = Movement or {}
Drag = Drag or {}

State.Field( "LegShotAt", "Float", 0, State.OWNER, 0 ) -- when a bullet last hit a leg (0: never)
State.Field( "Dragging", "UInt", 13, State.OWNER, 0 )

Movement.LEG_LOCK = 6       -- seconds no jumping after a leg shot...
Movement.LEG_LOCK_EMPTY = 10 -- ...plus this many more at full Emptiness
Drag.SNAP = 128
Drag.RANGE = 100

-- Seconds of the leg-shot jump lock left (0 when free).
function Movement.JumpLockLeft( ply )
	local at = ply:GetLegShotAt()
	if at <= 0 then return 0 end
	local length = Movement.LEG_LOCK + Movement.LEG_LOCK_EMPTY * Needs.Get( ply, "Emptiness" ) / 100
	return math.max( 0, at + length - CurTime() )
end

function Movement.CanJump( ply )
	if ply:IsFrozen() then return false end
	if Movement.JumpLockLeft( ply ) > 0 then return false end
	local wep = ply:GetActiveWeapon()
	if IsValid( wep ) and wep.GetReloading and wep:GetReloading() then return false end
	return true
end

hook.Add( "StartCommand", "gr_movement", function( ply, cmd )
	if not ply:Alive() then return end
	local jump = cmd:KeyDown( IN_JUMP )
	if SERVER then
		if jump and not ply.GR_JumpHeld then Movement.JumpPressed( ply ) end
		ply.GR_JumpHeld = jump
	end
	if jump and not Movement.CanJump( ply ) then cmd:RemoveKey( IN_JUMP ) end
	if ply:IsFrozen() and cmd:KeyDown( IN_DUCK ) then cmd:RemoveKey( IN_DUCK ) end
end )

-- Drag and let go, offered on bodies. The client only knows it's a ragdoll; the server checks the rest.
local function addInteract()
	Interact.Add( "drag", {
		label = "Drag",
		range = Drag.RANGE,
		show = function( ply, ent )
			if ply:IsGhost() or ent:GetClass() ~= "prop_ragdoll" then return false end
			if ply:GetDragging() == ent:EntIndex() then return false end
			if CLIENT then return true end
			return Drag.CanDrag( ply, ent )
		end,
		run = function( ply, ent ) Drag.Start( ply, ent ) end,
	} )
	Interact.Add( "drag_stop", {
		label = "Let go",
		range = Drag.SNAP,
		show = function( ply, ent ) return ply:GetDragging() == ent:EntIndex() end,
		run = function( ply ) Drag.Stop( ply ) end,
	} )
end
if Interact and Interact.Add then addInteract() else hook.Add( "PostGamemodeLoaded", "gr_movement", addInteract ) end

if CLIENT then
	local third = CreateClientConVar( "cc_thirdperson", "0", true, false, "See yourself from behind." )
	local HULL = Vector( 4, 4, 4 )

	local function thirdPerson( ply )
		return ply:Alive() and ( ply:IsGhost() or third:GetBool() )
	end

	hook.Add( "CalcView", "gr_thirdperson", function( ply, origin, angles, fov )
		if not thirdPerson( ply ) then return end
		local tr = util.TraceHull( {
			start = origin, endpos = origin - angles:Forward() * 90 + angles:Right() * 15,
			filter = ply, mins = -HULL, maxs = HULL, mask = MASK_SOLID_BRUSHONLY,
		} )
		return { origin = tr.HitPos, angles = angles, fov = fov, drawviewer = true }
	end )

	hook.Add( "ShouldDrawLocalPlayer", "gr_thirdperson", function( ply )
		if thirdPerson( ply ) then return true end
	end )
	return
end

-- A bullet in the leg: no jumping for a while.
Damage.Add( "Scale", "legshot", function( ply, dmg, ctx )
	if ctx.hitgroup ~= HITGROUP_LEFTLEG and ctx.hitgroup ~= HITGROUP_RIGHTLEG then return end
	if bit.band( dmg:GetDamageType(), DMG_BULLET ) == 0 then return end
	ply:SetLegShotAt( CurTime() )
end )

-- A fresh press of jump (whether or not the jump is allowed): it interrupts surgery.
function Movement.JumpPressed( ply )
	local a = Actions.Get( ply )
	if a and a.kind == "surgery" then Actions.Cancel( ply, "You jumped and lost your place." ) end
end

-- Dragging -------------------------------------------------------------------------------------

local dragging = {} -- ply -> { rag, bone }

function Drag.Of( ply )
	local d = dragging[ ply ]
	if d and IsValid( d.rag ) then return d.rag end
end

local function draggable( rec )
	return rec ~= nil and ( rec.state == "unconscious" or rec.state == "downed" or rec.state == "dead" )
end

function Drag.CanDrag( ply, rag )
	if not ply:Alive() or ply:IsGhost() or ply:GetPassedOut() then return false end
	if not draggable( Corpse.Get( rag ) ) then return false end
	if IsValid( rag.GR_DraggedBy ) and rag.GR_DraggedBy ~= ply and Drag.Of( rag.GR_DraggedBy ) == rag then return false end
	return true
end

-- The physics bone of `rag` nearest `pos`.
local function nearestBone( rag, pos )
	local best, bestDist = 0, math.huge
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum( i )
		if IsValid( phys ) then
			local d = phys:GetPos():DistToSqr( pos )
			if d < bestDist then best, bestDist = i, d end
		end
	end
	return best
end

function Drag.Start( ply, rag )
	if not Drag.CanDrag( ply, rag ) then return false end
	Drag.Stop( ply )
	dragging[ ply ] = { rag = rag, bone = nearestBone( rag, ply:GetShootPos() ) }
	rag.GR_DraggedBy = ply
	ply:SetDragging( rag:EntIndex() )
	return true
end

-- snapped: the body tore free (too far away), with the barnacle-tongue sound.
function Drag.Stop( ply, snapped )
	local d = dragging[ ply ]
	dragging[ ply ] = nil
	if IsValid( ply ) then ply:SetDragging( 0 ) end
	if not d then return end
	if IsValid( d.rag ) and d.rag.GR_DraggedBy == ply then d.rag.GR_DraggedBy = nil end
	if snapped and IsValid( ply ) then ply:EmitSound( "npc/barnacle/barnacle_tongue_pull" .. math.random( 1, 3 ) .. ".wav" ) end
end

local SLACK = 40   -- the body follows once it is this far behind
local PULL = 6     -- speed per unit of distance past the slack
local MAX_PULL = 350

-- One step for every drag: end the broken ones, snap the stretched ones, pull the rest.
function Drag.Tick()
	for ply, d in pairs( dragging ) do
		local rag = d.rag
		local phys = IsValid( rag ) and rag:GetPhysicsObjectNum( d.bone )
		if not IsValid( ply ) or not IsValid( phys ) or not ply:Alive() or ply:IsGhost() or ply:GetPassedOut()
			or not draggable( Corpse.Get( rag ) ) then
			Drag.Stop( ply )
		else
			local to = ply:GetPos() + Vector( 0, 0, 24 )
			local dist = phys:GetPos():Distance( to )
			if dist > Drag.SNAP then
				Drag.Stop( ply, true )
			elseif dist > SLACK then
				phys:Wake()
				phys:SetVelocity( ( to - phys:GetPos() ):GetNormalized() * math.min( ( dist - SLACK ) * PULL, MAX_PULL ) )
			end
		end
	end
end

Sched.Every( "drag", 0.05, Drag.Tick )

hook.Add( "GR_FateEnter", "gr_movement", function( ply ) Drag.Stop( ply ) end )
hook.Add( "PlayerDisconnected", "gr_movement", function( ply ) Drag.Stop( ply ) end )
