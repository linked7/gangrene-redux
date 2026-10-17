-- Hands: everyone alive has them. Holstered, right-click picks things up; out, fists (they hurt on walls).
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.PrintName = "Hands"
SWEP.Slot = 0
SWEP.SlotPos = 1
SWEP.ViewModel = "models/weapons/c_arms.mdl"
SWEP.WorldModel = ""
SWEP.HoldType = "fist"
SWEP.HoldTypeHolster = "normal"
SWEP.Melee = true
SWEP.MovementMult = 1
SWEP.SprintUnholstered = true
SWEP.SecondaryBlock = false
SWEP.BlockMul = 0.5
SWEP.Length = 50
SWEP.Damage = 10
SWEP.HitDelay = 0.8
SWEP.MissDelay = 1.2
SWEP.DamageType = DMG_CLUB
SWEP.HitFleshSound = { "npc/vort/foot_hit.wav", "weapons/crossbow/hitbod1.wav", "weapons/crossbow/hitbod2.wav" }
SWEP.HitWallSound = { "physics/body/body_medium_break2.wav", "physics/body/body_medium_break3.wav", "physics/body/body_medium_break4.wav" }
SWEP.SwingSound = { "npc/vort/claw_swing1.wav", "npc/vort/claw_swing2.wav" }

function SWEP:DrawWorldModel() end

if CLIENT then
	-- The original's hands: holstered, the arms are pushed far out of view; out, the fists show.
	function SWEP:GetViewModelPosition( pos, ang )
		if not self:IsOut() then return pos - ang:Forward() * 666, ang end
		return pos, ang
	end
end
