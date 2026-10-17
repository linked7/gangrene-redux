-- Einhesna, ported from the original's weapon_cc_einhesna with its stats, sounds and models.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.Firearm = true
SWEP.Slot = 2
SWEP.PrintName = "Einhesna"
SWEP.ViewModel = "models/weapons/c_einhesna.mdl"
SWEP.WorldModel = "models/weapons/w_einhesna.mdl"
SWEP.HoldType = "smg"
SWEP.HoldTypeAim = "rpg"
SWEP.HoldTypeHolster = "passive"
SWEP.HoldTypeCrouch = "smg"
SWEP.MovementMult = 0.75
SWEP.SprintUnholstered = false
SWEP.Primary.ClipSize = 32
SWEP.Primary.Ammo = "cc_smg"
SWEP.Primary.Automatic = true
SWEP.Primary.Sound = "tekka/weapons/weapon_p226.wav"
SWEP.Primary.ReloadSound = "weapons/ump45/ump45_boltslap.wav"
SWEP.Primary.Damage = 15
SWEP.Primary.Force = 2
SWEP.Primary.Accuracy = 0.09
SWEP.Primary.Delay = 0.10
SWEP.Primary.Recoil = 1.3
SWEP.MeleeDamage = 20
SWEP.MeleeKnockback = 50
SWEP.MeleeHeavy = false
SWEP.MeleeDelay = 2
SWEP.MeleeStun = 2
SWEP.JamChance = 1
SWEP.Primary.DefaultClip = 32
SWEP.HolsterPos = Vector(0, 0, 0)
SWEP.HolsterAng = Angle(-6.04,34.25,0)
SWEP.ReloadTime = 3.0789 -- the reload sequence's length in the .mdl
