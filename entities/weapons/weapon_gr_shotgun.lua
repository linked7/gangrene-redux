-- A pump shotgun: a sanitar's long arm. Six shells, a wide cone.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.PrintName = "Shotgun"
SWEP.Slot = 2
SWEP.ViewModel = "models/weapons/c_shotgun.mdl"
SWEP.WorldModel = "models/weapons/w_shotgun.mdl"
SWEP.HoldType = "shotgun"
SWEP.HoldTypeHolster = "passive"
SWEP.Firearm = true
SWEP.Primary.ClipSize = 6
SWEP.Primary.DefaultClip = 6
SWEP.Primary.Ammo = "Buckshot"
SWEP.Primary.Automatic = false
SWEP.Primary.Sound = "Weapon_Shotgun.Single"
SWEP.Primary.ReloadSound = "Weapon_Shotgun.Reload"
SWEP.Primary.Damage = 9
SWEP.Primary.NumBullets = 8
SWEP.Primary.Force = 2
SWEP.Primary.Accuracy = 0.08
SWEP.Primary.Delay = 0.9
SWEP.Primary.Recoil = 4
