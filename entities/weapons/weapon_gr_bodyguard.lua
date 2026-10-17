-- Bodyguard, ported from the original's weapon_cc_bodyguard with its stats, sounds and models.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.Firearm = true
SWEP.Slot = 2
SWEP.PrintName = "Bodyguard"
SWEP.ViewModel = "models/weapons/c_bodyguard.mdl"
SWEP.WorldModel = "models/weapons/w_bodyguard.mdl"
SWEP.HoldType = "pistol"
SWEP.HoldTypeAim = "revolver"
SWEP.HoldTypeHolster = "normal"
SWEP.HoldTypeCrouch = "pistol"
SWEP.MovementMult = 0.8
SWEP.SprintUnholstered = true
SWEP.Primary.ClipSize = 5
SWEP.Primary.Ammo = "cc_357"
SWEP.Primary.Automatic = true
SWEP.Primary.Sound = "tekka/weapons/weapon_1911.wav"
SWEP.Primary.ReloadSound = "weapons/smg1/switch_burst.wav"
SWEP.Primary.Damage = 40
SWEP.Primary.Force = 3
SWEP.Primary.Accuracy = 0.05
SWEP.Primary.Delay = 0.75
SWEP.Primary.Recoil = 2
SWEP.MeleeDamage = 10
SWEP.MeleeKnockback = 20
SWEP.MeleeHeavy = false
SWEP.MeleeDelay = 1
SWEP.MeleeStun = 1
SWEP.Primary.DefaultClip = 5
SWEP.HolsterPos = Vector(0, 0, 0)
SWEP.HolsterAng = Angle(-15.86,0,0)
SWEP.ReloadTime = 3.6667 -- the reload sequence's length in the .mdl
