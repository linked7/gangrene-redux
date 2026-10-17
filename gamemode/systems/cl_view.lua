-- The view, ported from the original's GM:CalcView (gui/cl_hud.lua 288, docs/05 §4): smoothed
-- angles, the head bob (cc_noheadbob 1 turns it off), the strafe roll (cc_noviewroll 1), the
-- sway while downed, head-wounded or a ghost, the ghost's over-the-shoulder camera, and the
-- weapon FOV lerp.
--
--   HUD.ThirdPerson( ply )  true when the camera sits behind the player: ghosts always (§13).
--                           The cc_thirdperson option and the held-item cases are §12's; they
--                           extend this function rather than adding a second CalcView.
local noHeadBob = CreateClientConVar( "cc_noheadbob", "0", true, false, "Turn off the head bob." )
local noViewRoll = CreateClientConVar( "cc_noviewroll", "0", true, false, "Turn off the strafe and ghost view roll." )

local CT = CurTime
local dyn = { roll = 0, bob = 0, fov = nil }
local third = { pos = nil, ang = nil }

function HUD.ThirdPerson( ply )
	return ply:IsGhost()
end

-- GM:ShouldDoThirdPerson: never while scoped, in noclip or looking through another entity.
local function canThirdPerson( ply )
	local wep = ply:GetActiveWeapon()
	if IsValid( wep ) and ( wep.Zoom_InZoom or ( wep.InScope and wep:InScope() ) ) then return false end
	if ply:GetMoveType() == MOVETYPE_NOCLIP then return false end
	if ply:GetViewEntity() ~= ply then return false end
	return true
end

local function holstered( ply )
	return ply.Holstered ~= nil and ply:Holstered() or false
end

hook.Add( "CalcView", "gr_view", function( ply, pos, ang, fov, znear, zfar )
	if ply:InVehicle() then return end
	-- The base first (weapon CalcView and so on), as the original's self.BaseClass:CalcView.
	local base = GAMEMODE.BaseClass and GAMEMODE.BaseClass.CalcView
	local view = base and base( GAMEMODE, ply, pos, ang, fov, znear, zfar ) or {}
	view.origin, view.angles, view.fov = view.origin or pos, view.angles or ang, view.fov or fov
	local t = CT()

	local wep = ply:GetActiveWeapon()
	local sighted = false
	if not noHeadBob:GetBool() then
		local target = 0
		local len2d = ply:GetVelocity():Length2D()
		if not holstered( ply ) and IsValid( wep ) and ( ply:KeyDown( IN_ATTACK2 ) and wep.IronMode or wep.Zoom_InZoom ) then
			sighted = true
		end
		if not sighted then len2d = len2d + 20 end
		if len2d > 5 and ply:GetMoveType() ~= MOVETYPE_NOCLIP then target = math.Clamp( len2d / 300, 0, 0.75 ) end
		dyn.bob = Lerp( 0.01, dyn.bob, target * 2 )
		if dyn.bob > 0 and not sighted then
			view.angles = Angle( view.angles.p + math.sin( t * 3 ) * dyn.bob * 2, view.angles.y + math.cos( t ) * dyn.bob, view.angles.r )
		end
	end

	local roll = 0
	local left, right = ply:KeyDown( IN_MOVELEFT ), ply:KeyDown( IN_MOVERIGHT )
	if left and not right then roll = -5 elseif right and not left then roll = 5 end

	local wound = HUD.Headwounded and HUD.Headwounded() or 0
	if not ply:Alive() then
		view.angles = Angle( view.angles.p + math.cos( t * 2 ), view.angles.y + math.sin( t * 3.3 ), 10 * math.sin( t * 3 ) )
		view.fov = view.fov + math.sin( t * 0.5 ) * 45
	elseif wound > 0 then
		view.angles = Angle( view.angles.p + math.cos( t * 2 ) * wound * 1.5, view.angles.y + math.sin( t * 3.3 ) * wound,
			math.sin( t * 3 ) * wound * 2 )
	elseif ply:IsGhost() and not noViewRoll:GetBool() then
		view.angles = Angle( view.angles.p + math.cos( t * 2 ), view.angles.y + math.sin( t * 3.3 ), 15 * math.sin( t ) )
		view.fov = view.fov + math.sin( t * 0.5 ) * 30
	end

	dyn.roll = Lerp( 0.03, dyn.roll, roll )
	if not noViewRoll:GetBool() then
		view.angles = Angle( view.angles.p, view.angles.y, dyn.roll )
	end
	-- /roll's lean (sh_chat's Chat.ViewRoll, when that is loaded).
	local lean = Chat and Chat.ViewRoll and Chat.ViewRoll() or 0
	if lean ~= 0 then view.angles = Angle( view.angles.p, view.angles.y, view.angles.r + lean ) end

	if ply:Alive() and HUD.ThirdPerson( ply ) and canThirdPerson( ply ) then
		third.pos = third.pos or ply:GetPos()
		third.ang = third.ang or Angle()
		local targetPos = ply:EyePos() + ply:GetAimVector() * -40 + ply:GetForward() * -10 + ply:GetRight() * 35
		local distance = sighted and 25 or 50
		local destAng = view.angles
		local dest = targetPos - destAng:Forward() * distance
		local tr = util.TraceLine( { start = view.origin, endpos = dest, filter = ply } )
		dest = view.origin + tr.Normal * ( distance - 2 ) * tr.Fraction
		third.pos = LerpVector( 0.08, third.pos, dest )
		third.ang = LerpAngle( ( holstered( ply ) and not ply:IsGhost() ) and 0.08 or 0.5, third.ang, destAng )
		view.origin, view.angles = third.pos, third.ang
	else
		third.pos, third.ang = view.origin, view.angles
	end

	dyn.fov = dyn.fov or fov
	if IsValid( wep ) then
		if wep.TranslateFOV then dyn.fov = Lerp( 0.05, dyn.fov, wep:TranslateFOV( fov ) ) end
		view.fov = dyn.fov
	end
	return view
end )

hook.Add( "ShouldDrawLocalPlayer", "gr_view", function( ply )
	if HUD.ThirdPerson( ply ) and canThirdPerson( ply ) then return true end
end )
