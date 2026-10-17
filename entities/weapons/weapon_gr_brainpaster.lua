-- Brainpaster, ported from the original's weapon_cc_brainpaster with its stats, sounds and models.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.Firearm = true
SWEP.Slot = 2
SWEP.PrintName = "Brainpaster"
SWEP.ViewModel = "models/weapons/c_brainpaster.mdl"
SWEP.WorldModel = "models/weapons/w_brainpaster.mdl"
SWEP.HoldType = "pistol"
SWEP.HoldTypeAim = "revolver"
SWEP.HoldTypeHolster = "normal"
SWEP.HoldTypeCrouch = "pistol"
SWEP.MovementMult = 0.8
SWEP.SprintUnholstered = true
SWEP.Primary.ClipSize = 8
SWEP.Primary.Ammo = "cc_pistol"
SWEP.Primary.Automatic = true
SWEP.Primary.Sound = "tekka/weapons/weapon_canon.wav"
SWEP.Primary.ReloadSound = "weapons/glock/glock_clipout.wav"
SWEP.Primary.Damage = 35
SWEP.Primary.Force = 1
SWEP.Primary.Accuracy = 0.07
SWEP.Primary.Delay = 0.3
SWEP.Primary.Recoil = 2
SWEP.MeleeDamage = 10
SWEP.MeleeKnockback = 20
SWEP.MeleeHeavy = false
SWEP.MeleeDelay = 1
SWEP.MeleeStun = 1
SWEP.Primary.DefaultClip = 8
SWEP.HolsterPos = Vector(0, -5.95, -9.2)
SWEP.HolsterAng = Angle(27.48,0,0)
SWEP.ReloadTime = 2.7429 -- the reload sequence's length in the .mdl
