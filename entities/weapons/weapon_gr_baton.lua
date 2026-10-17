-- The baton: a sanitar's club. Blocks with right-click held (half damage taken).
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.PrintName = "Baton"
SWEP.Slot = 1
SWEP.ViewModel = "models/weapons/c_stunstick.mdl"
SWEP.WorldModel = "models/weapons/w_stunbaton.mdl"
SWEP.HoldType = "melee"
SWEP.HoldTypeHolster = "normal"
SWEP.Melee = true
SWEP.SecondaryBlock = true
SWEP.BlockMul = 0.5
SWEP.Length = 60
SWEP.Damage = 20
SWEP.HitDelay = 1
SWEP.MissDelay = 1.5
SWEP.DamageType = DMG_CLUB -- blunt, so it knocks people out (sh_consciousness.lua)
SWEP.MovementMult = 0.9
SWEP.SprintUnholstered = true
SWEP.SwingSound = { "placenta/weapons/swing_blunt1.ogg", "placenta/weapons/swing_blunt2.ogg", "placenta/weapons/swing_blunt3.ogg" }
SWEP.HitFleshSound = "placenta/weapons/club.ogg"
SWEP.HitWallSound = { "physics/metal/metal_solid_impact_hard1.wav", "physics/metal/metal_solid_impact_hard4.wav", "physics/metal/metal_solid_impact_hard5.wav" }
