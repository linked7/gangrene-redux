-- Kaptivist, ported from the original's weapon_cc_kaptivist with its stats, sounds and models.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.Firearm = true
SWEP.Slot = 2
SWEP.PrintName = "Kaptivist"
SWEP.ViewModel = "models/tnb/weapons/c_ks23.mdl"
SWEP.WorldModel = "models/tnb/weapons/w_ks23.mdl"
SWEP.HoldType = "shotgun"
SWEP.HoldTypeAim = "rpg"
SWEP.HoldTypeHolster = "passive"
SWEP.UnholsterPitch = 60
SWEP.MovementMult = 0.6
SWEP.IgnoreMovementInacc = true
SWEP.Primary.ClipSize = 4
SWEP.Primary.Ammo = "cc_shotgun"
SWEP.Primary.Automatic = true
SWEP.Primary.Sound = "weapons/shotgun/shotgun_dbl_fire.wav"
SWEP.Primary.ReloadSound = "Weapon_Shotgun.Reload"
SWEP.Primary.Damage = 6
SWEP.Primary.Force = 1
SWEP.Primary.Accuracy = 0.2
SWEP.Primary.Delay = 1.8
SWEP.Primary.Recoil = 20
SWEP.Primary.NumBullets = 20
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
