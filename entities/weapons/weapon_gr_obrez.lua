-- Obrez, ported from the original's weapon_cc_obrez with its stats, sounds and models.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.Firearm = true
SWEP.Slot = 2
SWEP.PrintName = "Obrez"
SWEP.ViewModel = "models/weapons/c_obrez.mdl"
SWEP.WorldModel = "models/weapons/w_obrez.mdl"
SWEP.HoldType = "ar2"
SWEP.HoldTypeHolster = "normal"
SWEP.UnholsterPitch = 80
SWEP.MovementMult = 0.65
SWEP.Primary.ClipSize = 5
SWEP.Primary.Ammo = "cc_sniper"
SWEP.Primary.Automatic = false
SWEP.Primary.Sound = "tekka/weapons/weapon_sbr.wav"
SWEP.Primary.ReloadSound = "Weapon_357.Reload"
SWEP.Primary.Damage = 65
SWEP.Primary.Force = 5
SWEP.Primary.Accuracy = 0.1
SWEP.Primary.Delay = 1.25
SWEP.Primary.Recoil = 8
SWEP.MeleeDamage = 20
SWEP.MeleeKnockback = 50
SWEP.MeleeHeavy = false
SWEP.MeleeDelay = 2
SWEP.MeleeStun = 2
SWEP.JamChance = 10
SWEP.Primary.DefaultClip = 5
SWEP.HolsterPos = Vector(0, 0, 0)
SWEP.HolsterAng = Angle(-6.04,34.25,0)
SWEP.ReloadTime = 2.9333 -- the reload sequence's length in the .mdl
SWEP.AimFOV = 75
