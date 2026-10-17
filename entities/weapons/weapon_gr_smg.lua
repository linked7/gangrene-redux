-- A submachine gun: fast, loose, thirty rounds.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.PrintName = "SMG"
SWEP.Slot = 2
SWEP.ViewModel = "models/weapons/c_smg1.mdl"
SWEP.WorldModel = "models/weapons/w_smg1.mdl"
SWEP.HoldType = "smg"
SWEP.HoldTypeHolster = "passive"
SWEP.Firearm = true
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Automatic = true
SWEP.Primary.Sound = "Weapon_SMG1.Single"
SWEP.Primary.ReloadSound = "Weapon_SMG1.Reload"
SWEP.Primary.Damage = 14
SWEP.Primary.Force = 1
SWEP.Primary.Accuracy = 0.05
SWEP.Primary.Delay = 0.09
SWEP.Primary.Recoil = 0.8
