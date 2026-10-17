-- A pistol (also the novoluger's stand-in). Eight rounds.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.PrintName = "Pistol"
SWEP.Slot = 1
SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"
SWEP.HoldType = "pistol"
SWEP.HoldTypeHolster = "normal"
SWEP.Firearm = true
SWEP.Primary.ClipSize = 8
SWEP.Primary.DefaultClip = 8
SWEP.Primary.Ammo = "Pistol"
SWEP.Primary.Automatic = true
SWEP.Primary.Sound = "Weapon_Pistol.Single"
SWEP.Primary.ReloadSound = "Weapon_Pistol.Reload"
SWEP.Primary.Damage = 30
SWEP.Primary.Force = 1
SWEP.Primary.Accuracy = 0.03
SWEP.Primary.Delay = 0.2
SWEP.Primary.Recoil = 1
