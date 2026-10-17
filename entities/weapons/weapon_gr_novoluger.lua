-- Novoluger, ported from the original's weapon_cc_novoluger with its stats, sounds and models.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.Firearm = true
SWEP.Slot = 2
SWEP.PrintName = "Novoluger"
SWEP.ViewModel = "models/weapons/c_novoluger.mdl"
SWEP.WorldModel = "models/weapons/w_novoluger.mdl"
SWEP.HoldType = "pistol"
SWEP.HoldTypeAim = "revolver"
SWEP.HoldTypeHolster = "normal"
SWEP.HoldTypeCrouch = "pistol"
SWEP.MovementMult = 0.75
SWEP.SprintUnholstered = true
SWEP.Primary.ClipSize = 8
SWEP.Primary.Ammo = "cc_pistol"
SWEP.Primary.Automatic = true
SWEP.Primary.Sound = "tekka/weapons/weapon_pistolcrack.wav"
SWEP.Primary.ReloadSound = "weapons/glock/glock_clipout.wav"
SWEP.Primary.Damage = 30
SWEP.Primary.Force = 1
SWEP.Primary.Accuracy = 0.03
SWEP.Primary.Delay = 0.2
SWEP.Primary.Recoil = 1
SWEP.MeleeDamage = 10
SWEP.MeleeKnockback = 20
SWEP.MeleeHeavy = false
SWEP.MeleeDelay = 1
SWEP.MeleeStun = 1
SWEP.Primary.DefaultClip = 8
SWEP.HolsterPos = Vector(0, -5.95, -9.2)
SWEP.HolsterAng = Angle(27.48,0,0)
SWEP.ReloadTime = 1.4333 -- the reload sequence's length in the .mdl
