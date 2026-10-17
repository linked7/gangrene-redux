-- Candlewood, ported from the original's weapon_cc_candlewood with its stats, sounds and models.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.Firearm = true
SWEP.Slot = 2
SWEP.PrintName = "Candlewood"
SWEP.ViewModel = "models/weapons/c_candlewood.mdl"
SWEP.WorldModel = "models/weapons/w_candlewood.mdl"
SWEP.HoldType = "shotgun"
SWEP.HoldTypeAim = "rpg"
SWEP.HoldTypeHolster = "passive"
SWEP.UnholsterPitch = 80
SWEP.IgnoreMovementInacc = true
SWEP.Primary.ClipSize = 4
SWEP.Primary.Ammo = "cc_shotgun"
SWEP.Primary.Automatic = true
SWEP.Primary.Sound = "tekka/weapons/weapon_shotgun.wav"
SWEP.Primary.ReloadSound = "Weapon_Shotgun.Reload"
SWEP.Primary.Damage = 8
SWEP.Primary.Force = 2
SWEP.Primary.Accuracy = 0.095
SWEP.Primary.Delay = 0.85
SWEP.Primary.Recoil = 5
SWEP.Primary.NumBullets = 11
SWEP.MeleeDamage = 35
SWEP.MeleeKnockback = 150
SWEP.MeleeHeavy = true
SWEP.MeleeDelay = 4
SWEP.MeleeStun = 3
SWEP.Primary.DefaultClip = 4
SWEP.HolsterPos = Vector(0, 0, 0)
SWEP.HolsterAng = Angle(-5.19,37.39,0)
SWEP.ShellReload = true
SWEP.ShellTimes = { 0.4571, 0.6222, 1.0286 } -- reload start, each shell, finish
SWEP.PumpTimes = { 1.1562, 1.0 } -- shoot1, shoot2
