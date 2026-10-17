-- Trooper, ported from the original's weapon_cc_trooper with its stats, sounds and models.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.Firearm = true
SWEP.Slot = 2
SWEP.PrintName = "Trooper"
SWEP.ViewModel = "models/weapons/c_trooper.mdl"
SWEP.WorldModel = "models/weapons/w_trooper.mdl"
SWEP.HoldType = "ar2"
SWEP.HoldTypeAim = "rpg"
SWEP.HoldTypeHolster = "passive"
SWEP.HoldTypeCrouch = "shotgun"
SWEP.Bodygroup = 6
SWEP.UnholsterPitch = 80
SWEP.ChamberAnim = ACT_VM_DRAW
SWEP.IdleAnim = ACT_VM_PRIMARYATTACK
SWEP.Primary.ClipSize = 18
SWEP.Primary.Ammo = "cc_rifle"
SWEP.Primary.Automatic = true
SWEP.Primary.Sound = "tekka/weapons/weapon_m4.wav"
SWEP.Primary.ReloadSound = "weapons/ak47/ak47_boltpull.wav"
SWEP.Primary.Damage = 35
SWEP.Primary.Force = 2
SWEP.Primary.Accuracy = 0.05
SWEP.Primary.Delay = 0.3
SWEP.Primary.Recoil = 1.5
SWEP.MeleeDamage = 20
SWEP.MeleeKnockback = 50
SWEP.MeleeHeavy = false
SWEP.MeleeDelay = 2
SWEP.MeleeStun = 2
SWEP.JamChance = 0
SWEP.Primary.DefaultClip = 18
SWEP.HolsterPos = Vector(0, 0, 0)
SWEP.HolsterAng = Angle(-6.04,34.25,0)
SWEP.ReloadTime = 2.9762 -- the reload sequence's length in the .mdl
