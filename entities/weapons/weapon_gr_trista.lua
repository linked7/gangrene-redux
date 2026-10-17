-- Trista, ported from the original's weapon_cc_trista with its stats, sounds and models.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.Firearm = true
SWEP.Slot = 2
SWEP.PrintName = "Trista"
SWEP.ViewModel = "models/weapons/c_trista.mdl"
SWEP.WorldModel = "models/weapons/w_trista.mdl"
SWEP.HoldType = "ar2"
SWEP.HoldTypeAim = "rpg"
SWEP.HoldTypeHolster = "passive"
SWEP.HoldTypeCrouch = "shotgun"
SWEP.MovementMult = 0.65
SWEP.ChamberAnim = ACT_VM_DRAW
SWEP.Primary.ClipSize = 64
SWEP.Primary.Ammo = "cc_smg"
SWEP.Primary.Automatic = true
SWEP.Primary.Sound = "tekka/weapons/weapon_smg2.wav"
SWEP.Primary.ReloadSound = "weapons/ump45/ump45_boltslap.wav"
SWEP.Primary.Damage = 12
SWEP.Primary.Force = 2
SWEP.Primary.Accuracy = 0.08
SWEP.Primary.Delay = 0.08
SWEP.Primary.Recoil = 0.7
SWEP.MeleeDamage = 20
SWEP.MeleeKnockback = 50
SWEP.MeleeHeavy = false
SWEP.MeleeDelay = 2
SWEP.MeleeStun = 2
SWEP.JamChance = 2
SWEP.Primary.DefaultClip = 64
SWEP.HolsterPos = Vector(0, 0, 0)
SWEP.HolsterAng = Angle(-4.49,36.98,0)
SWEP.ReloadTime = 2.7838 -- the reload sequence's length in the .mdl
