-- Pacifier, ported from the original's weapon_cc_pacifier with its stats, sounds and models.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.Firearm = true
SWEP.Slot = 2
SWEP.PrintName = "Pacifier"
SWEP.ViewModel = "models/weapons/c_pacifier.mdl"
SWEP.WorldModel = "models/weapons/w_pacifier.mdl"
SWEP.HoldType = "pistol"
SWEP.HoldTypeAim = "revolver"
SWEP.HoldTypeHolster = "normal"
SWEP.HoldTypeCrouch = "pistol"
SWEP.MovementMult = 0.8
SWEP.SprintUnholstered = true
SWEP.Primary.ClipSize = 15
SWEP.Primary.Ammo = "cc_pistol"
SWEP.Primary.Automatic = true
SWEP.Primary.Sound = "tekka/weapons/weapon_m92.wav"
SWEP.Primary.ReloadSound = "weapons/glock/glock_clipout.wav"
SWEP.Primary.Damage = 20
SWEP.Primary.Force = 1
SWEP.Primary.Accuracy = 0.05
SWEP.Primary.Delay = 0.3
SWEP.Primary.Recoil = 2
SWEP.MeleeDamage = 10
SWEP.MeleeKnockback = 20
SWEP.MeleeHeavy = false
SWEP.MeleeDelay = 1
SWEP.MeleeStun = 1
SWEP.Primary.DefaultClip = 15
SWEP.HolsterPos = Vector(0, -5.95, -9.2)
SWEP.HolsterAng = Angle(27.48,0,0)
SWEP.ReloadTime = 2.7429 -- the reload sequence's length in the .mdl
