-- Bastard, ported from the original's weapon_cc_bastard with its stats, sounds and models.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.Firearm = true
SWEP.Slot = 2
SWEP.PrintName = "Bastard"
SWEP.ViewModel = "models/weapons/c_bastard.mdl"
SWEP.WorldModel = "models/weapons/w_bastard.mdl"
SWEP.HoldType = "ar2"
SWEP.HoldTypeAim = "rpg"
SWEP.HoldTypeHolster = "passive"
SWEP.HoldTypeCrouch = "shotgun"
SWEP.MovementMult = 0.75
SWEP.Primary.ClipSize = 32
SWEP.Primary.Ammo = "cc_smg"
SWEP.Primary.Automatic = true
SWEP.Primary.Sound = "tekka/weapons/weapon_smg.wav"
SWEP.Primary.ReloadSound = "weapons/ump45/ump45_boltslap.wav"
SWEP.Primary.Damage = 12
SWEP.Primary.Force = 2
SWEP.Primary.Accuracy = 0.075
SWEP.Primary.Delay = 0.09
SWEP.Primary.Recoil = 0.5
SWEP.MeleeDamage = 20
SWEP.MeleeKnockback = 50
SWEP.MeleeHeavy = false
SWEP.MeleeDelay = 2
SWEP.MeleeStun = 2
SWEP.JamChance = 2
SWEP.Primary.DefaultClip = 32
SWEP.HolsterPos = Vector(0, 0, 0)
SWEP.HolsterAng = Angle(-6.04,34.25,0)
SWEP.ReloadTime = 2.381 -- the reload sequence's length in the .mdl
