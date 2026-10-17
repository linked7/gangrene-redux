-- Vengeance, ported from the original's weapon_cc_vengeance with its stats, sounds and models.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.Firearm = true
SWEP.Slot = 2
SWEP.PrintName = "Vengeance"
SWEP.ViewModel = "models/tnb/weapons/c_mg3.mdl"
SWEP.WorldModel = "models/tnb/weapons/w_mg3.mdl"
SWEP.HoldType = "smg"
SWEP.HoldTypeAim = "rpg"
SWEP.HoldTypeHolster = "passive"
SWEP.HoldTypeCrouch = "smg"
SWEP.UnholsterPitch = 60
SWEP.MovementMult = 0.75
SWEP.SprintUnholstered = false
SWEP.Primary.ClipSize = 100
SWEP.Primary.Ammo = "cc_sniper"
SWEP.Primary.Automatic = true
SWEP.Primary.Sound = "tekka/weapons/weapon_mgthud.wav"
SWEP.Primary.ReloadSound = "Weapon_357.Reload"
SWEP.Primary.Damage = 18
SWEP.Primary.Force = 5
SWEP.Primary.Accuracy = 0.08
SWEP.Primary.Delay = 0.06
SWEP.Primary.Recoil = 0.55
SWEP.MeleeDamage = 45
SWEP.MeleeKnockback = 250
SWEP.MeleeHeavy = true
SWEP.MeleeDelay = 6
SWEP.MeleeStun = 4
SWEP.JamChance = 10
SWEP.Primary.DefaultClip = 100
SWEP.HolsterPos = Vector(0, 0, 0)
SWEP.HolsterAng = Angle(-6.04,34.25,0)
SWEP.ReloadTime = 5.7333 -- the reload sequence's length in the .mdl
