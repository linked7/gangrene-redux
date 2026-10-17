-- Rattler, ported from the original's weapon_cc_rattler with its stats, sounds and models.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.Firearm = true
SWEP.Slot = 2
SWEP.PrintName = "Rattler"
SWEP.ViewModel = "models/tnb/weapons/c_sten.mdl"
SWEP.WorldModel = "models/tnb/weapons/w_sten.mdl"
SWEP.HoldType = "ar2"
SWEP.HoldTypeAim = "rpg"
SWEP.HoldTypeHolster = "passive"
SWEP.HoldTypeCrouch = "shotgun"
SWEP.Bodygroup = 1
SWEP.MovementMult = 0.75
SWEP.Primary.ClipSize = 32
SWEP.Primary.Ammo = "cc_smg"
SWEP.Primary.Automatic = true
SWEP.Primary.Sound = "tekka/weapons/weapon_smg.wav"
SWEP.Primary.ReloadSound = "weapons/ump45/ump45_boltslap.wav"
SWEP.Primary.Damage = 14
SWEP.Primary.Force = 2
SWEP.Primary.Accuracy = 0.07
SWEP.Primary.Delay = 0.09
SWEP.Primary.Recoil = 0.45
SWEP.MeleeDamage = 20
SWEP.MeleeKnockback = 50
SWEP.MeleeHeavy = false
SWEP.MeleeDelay = 2
SWEP.MeleeStun = 2
SWEP.JamChance = 2
SWEP.Primary.DefaultClip = 32
SWEP.HolsterPos = Vector(0, 0, 0)
SWEP.HolsterAng = Angle(-6.04,34.25,0)
SWEP.ReloadTime = 2.9762 -- the reload sequence's length in the .mdl
