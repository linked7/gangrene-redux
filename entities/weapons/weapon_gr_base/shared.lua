-- The weapon base every Gangrene Redux weapon derives from (the original's weapon_cc_base, §9 of
-- docs/05-ui-effects-parity.md). Holstering is central: the owner's Holstered field (sh_weapons.lua)
-- says whether the weapon is out. Holstered, right-click picks up props; out, a weapon slows its
-- holder (MovementMult, SprintUnholstered, applied as a Fates.SpeedMods entry) and attacks.
--
--   sh_melee.lua    charge-and-release melee, heavy hits, blocking, fist pain, head bursts, prop pickup
--   sh_firing.lua   bullets, recoil, spread, reloading, aim zoom, the melee shove (G with a gun out)
--
-- A weapon sets Melee = true or Firearm = true plus its own stats; everything else is shared here.
AddCSLuaFile()
AddCSLuaFile( "sh_melee.lua" )
AddCSLuaFile( "sh_firing.lua" )

SWEP.GR_Base = true -- sh_weapons.lua and sh_kit.lua recognise the remake's weapons by this
SWEP.PrintName = "Base"
SWEP.Spawnable = false
SWEP.Slot = 1
SWEP.SlotPos = 1
SWEP.ViewModelFOV = 54
SWEP.ViewModel = ""
SWEP.WorldModel = ""
SWEP.UseHands = true
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.SwayScale = 0 -- no default sway or bob (parity)
SWEP.BobScale = 0

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Ammo = "none"
SWEP.Primary.Automatic = false
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Automatic = false

SWEP.HoldType = "normal"
SWEP.HoldTypeHolster = "normal"
SWEP.Holsterable = true
SWEP.MovementMult = 0.5        -- speed x this while the weapon is out
SWEP.SprintUnholstered = false -- no sprinting while the weapon is out
SWEP.HeavyCharge = 0.5         -- seconds attack must be held for a heavy swing
SWEP.PickupMass = 115          -- heaviest prop a holstered hand picks up
SWEP.PickupRange = 84

include( "sh_melee.lua" )
include( "sh_firing.lua" )

function SWEP:SetupDataTables()
	self:NetworkVar( "Float", 0, "ChargeStart" )
	self:NetworkVar( "Float", 1, "ReloadEnd" )
	self:NetworkVar( "Bool", 0, "MeleeAttack" )
	self:NetworkVar( "Bool", 1, "HeavyAttack" )
	self:NetworkVar( "Bool", 2, "Reloading" )
end

-- Out (unholstered) or not. A weapon that can't be holstered is always out.
function SWEP:IsOut()
	local owner = self:GetOwner()
	if not IsValid( owner ) or not owner:IsPlayer() then return false end
	if not self.Holsterable then return true end
	return owner.GetHolstered ~= nil and not owner:GetHolstered()
end

function SWEP:Initialize()
	self:SetHoldType( self.HoldTypeHolster or self.HoldType )
	self.GR_HoldOut = false
end

function SWEP:PlaySound( snd, vol, pitch )
	if not SERVER or not snd then return end
	if istable( snd ) then snd = snd[ math.random( #snd ) ] end
	local owner = self:GetOwner()
	if IsValid( owner ) then owner:EmitSound( snd, vol or 75, pitch or 100 ) end
end

function SWEP:Deploy()
	self:SetMeleeAttack( false )
	self:SetHeavyAttack( false )
	self:SetReloading( false )
	self:SetNextPrimaryFire( CurTime() + 0.5 )
	return true
end

function SWEP:Holster()
	self:SetMeleeAttack( false )
	self:SetHeavyAttack( false )
	self:SetReloading( false )
	return true
end

function SWEP:PrimaryAttack()
	if not self:IsOut() then return end
	if self.Firearm then
		self:PrimaryFirearm()
	elseif self.Melee then
		self:PrimaryMelee()
	end
end

function SWEP:SecondaryAttack()
	if not self:IsOut() then
		if SERVER then self:SecondaryHolstered() end
	end
	-- Out: blocking (melee) and aiming (firearms) are held, not pressed; see IsBlocking/TranslateFOV.
end

function SWEP:Think()
	local out = self:IsOut()
	if out ~= self.GR_HoldOut then
		self.GR_HoldOut = out
		self:SetHoldType( out and self.HoldType or self.HoldTypeHolster or "normal" )
		if not out then
			self:SetMeleeAttack( false )
			self:SetHeavyAttack( false )
		end
	end
	if self.Firearm then self:ThinkReload() end
	if self.Melee then self:ThinkMelee() end
end
