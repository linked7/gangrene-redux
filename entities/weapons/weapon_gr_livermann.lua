-- Livermann 98, ported from the original's weapon_cc_livermann with its stats, sounds and models.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.Firearm = true
SWEP.Slot = 2
SWEP.PrintName = "Livermann 98"
SWEP.ViewModel = "models/weapons/c_livermann.mdl"
SWEP.WorldModel = "models/weapons/w_livermann.mdl"
SWEP.HoldType = "ar2"
SWEP.HoldTypeAim = "rpg"
SWEP.HoldTypeHolster = "passive"
SWEP.HoldTypeCrouch = "shotgun"
SWEP.UnholsterPitch = 75
SWEP.Primary.ClipSize = 6
SWEP.Primary.Ammo = "cc_sniper"
SWEP.Primary.Automatic = true
SWEP.Primary.Sound = "placenta/weapons/enforcer.wav"
SWEP.Primary.ReloadSound = "weapons/357/357_reload3.wav"
SWEP.Primary.Damage = 55
SWEP.Primary.Force = 4
SWEP.Primary.Accuracy = 0.01
SWEP.Primary.Delay = 1.25
SWEP.Primary.Recoil = 6
SWEP.MeleeDamage = 20
SWEP.MeleeKnockback = 50
SWEP.MeleeHeavy = false
SWEP.MeleeDelay = 2
SWEP.MeleeStun = 2
SWEP.JamChance = 5
SWEP.Primary.DefaultClip = 6
SWEP.HolsterPos = Vector(6.58, -4.1, -10)
SWEP.HolsterAng = Angle(-0.7,50,-9.14)
SWEP.ReloadTime = 2.9333 -- the reload sequence's length in the .mdl
SWEP.AimFOV = 60
