-- Coach, ported from the original's weapon_cc_coach with its stats, sounds and models.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.Firearm = true
SWEP.Slot = 2
SWEP.PrintName = "Coach"
SWEP.ViewModel = "models/weapons/c_coach.mdl"
SWEP.WorldModel = "models/weapons/w_coach.mdl"
SWEP.ViewModelFlip = false
SWEP.HoldType = "shotgun"
SWEP.HoldTypeAim = "rpg"
SWEP.HoldTypeHolster = "passive"
SWEP.IgnoreMovementInacc = true
SWEP.Primary.ClipSize = 2
SWEP.Primary.Ammo = "cc_shotgun"
SWEP.Primary.Automatic = false
SWEP.Primary.Sound = "tekka/weapons/weapon_shotgun2.wav"
SWEP.Primary.ReloadSound = "Weapon_357.Reload"
SWEP.Primary.Damage = 12
SWEP.Primary.Force = 4
SWEP.Primary.Accuracy = 0.15
SWEP.Primary.Delay = 0.35
SWEP.Primary.Recoil = 4
SWEP.Primary.NumBullets = 8
SWEP.MeleeDamage = 35
SWEP.MeleeKnockback = 150
SWEP.MeleeHeavy = true
SWEP.MeleeDelay = 4
SWEP.MeleeStun = 3
SWEP.Primary.DefaultClip = 2
SWEP.HolsterPos = Vector(0, 0, 0)
SWEP.HolsterAng = Angle(-6.04,34.25,0)
SWEP.ReloadTime = 2.0 -- the reload sequence's length in the .mdl
