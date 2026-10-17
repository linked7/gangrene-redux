-- Painkiller, ported from the original's weapon_cc_painkiller with its stats, sounds and models.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.Firearm = true
SWEP.Slot = 2
SWEP.PrintName = "Painkiller"
SWEP.ViewModel = "models/weapons/c_painkiller.mdl"
SWEP.WorldModel = "models/weapons/w_painkiller.mdl"
SWEP.HoldType = "pistol"
SWEP.HoldTypeAim = "revolver"
SWEP.HoldTypeHolster = "normal"
SWEP.HoldTypeCrouch = "pistol"
SWEP.Bodygroup = 1
SWEP.MovementMult = 0.8
SWEP.SprintUnholstered = true
SWEP.Primary.ClipSize = 6
SWEP.Primary.Ammo = "cc_357"
SWEP.Primary.Automatic = true
SWEP.Primary.Sound = "tekka/weapons/weapon_western.wav"
SWEP.Primary.ReloadSound = "weapons/357/357_spin1.wav"
SWEP.Primary.Damage = 55
SWEP.Primary.Force = 3
SWEP.Primary.Accuracy = 0.03
SWEP.Primary.Delay = 0.75
SWEP.Primary.Recoil = 8
SWEP.MeleeDamage = 10
SWEP.MeleeKnockback = 20
SWEP.MeleeHeavy = false
SWEP.MeleeDelay = 1
SWEP.MeleeStun = 1
SWEP.Primary.DefaultClip = 6
SWEP.HolsterPos = Vector(0, 0, 0)
SWEP.HolsterAng = Angle(-15.86,0,0)
SWEP.ReloadTime = 3.6667 -- the reload sequence's length in the .mdl
