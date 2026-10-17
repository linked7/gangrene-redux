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
	self:NetworkVar( "Bool", 3, "NeedPump" ) -- a pump shotgun fired and has yet to pump
	self:NetworkVar( "Bool", 4, "Chamber" )  -- this reload started from an empty clip
	self:NetworkVar( "Float", 2, "PumpTime" )
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
	self:SetNeedPump( false )
	self:SetNextPrimaryFire( CurTime() + 0.5 )
	if self.Bodygroup then
		local vm = IsValid( self:GetOwner() ) and self:GetOwner():GetViewModel()
		if IsValid( vm ) then vm:SetBodygroup( 1, self.Bodygroup ) end
	end
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

-- The hold type for now: holstered, crouched (HoldTypeCrouch), aiming (HoldTypeAim) or plain out.
function SWEP:CurrentHoldType( out )
	if not out then return self.HoldTypeHolster or "normal" end
	local owner = self:GetOwner()
	if self.HoldTypeCrouch and owner:Crouching() then return self.HoldTypeCrouch end
	if self.HoldTypeAim and owner:KeyDown( IN_ATTACK2 ) then return self.HoldTypeAim end
	return self.HoldType
end

function SWEP:Think()
	local out = self:IsOut()
	if out ~= self.GR_HoldOut then
		self.GR_HoldOut = out
		if not out then
			self:SetMeleeAttack( false )
			self:SetHeavyAttack( false )
		end
	end
	local hold = self:CurrentHoldType( out )
	if hold ~= self.GR_Hold then
		self.GR_Hold = hold
		self:SetHoldType( hold )
	end
	if self.Firearm then
		self:ThinkPump()
		self:ThinkReload()
	end
	if self.Melee then self:ThinkMelee() end
end

if CLIENT then
	function SWEP:DrawWorldModel()
		if self.Bodygroup then self:SetBodygroup( 1, self.Bodygroup ) end
		self:DrawModel()
	end

	-- The original's CalcIron: firearms sit 4 units left and lower toward HolsterPos/HolsterAng when
	-- holstered; the shot kicks the model back (RecoilZ) and it lags behind turns and sways with speed.
	local swaymul = 0
	function SWEP:GetViewModelPosition( pos, ang )
		if not self.Firearm then return pos, ang end
		local out = self:IsOut()
		local tpos = out and ( self.ViewOrigin or vector_origin ) or ( self.HolsterPos or vector_origin )
		local tang = out and angle_zero or ( self.HolsterAng or angle_zero )
		local rate = out and ( self.ViewOrigin and 0.2 or 0.4 ) or 0.1
		self.IronNetPos = LerpVector( rate, self.IronNetPos or Vector(), tpos )
		self.IronNetAng = LerpAngle( rate, self.IronNetAng or Angle(), tang )
		local forward = ang:Forward()
		ang = Angle( ang )
		ang:RotateAroundAxis( ang:Right(), self.IronNetAng.p )
		ang:RotateAroundAxis( ang:Up(), self.IronNetAng.y )
		ang:RotateAroundAxis( ang:Forward(), self.IronNetAng.r )
		pos = pos + ( self.IronNetPos.x - 4 ) * ang:Right() + self.IronNetPos.y * ang:Up()
		local z = self.IronNetPos.z
		if self.RecoilZ then
			z = z + self.RecoilZ
			self.RecoilZ = Lerp( 0.1, self.RecoilZ, 1 )
			if self.RecoilZ >= 1 then self.RecoilZ = nil end
		end
		pos = pos + z * ang:Forward()
		-- Lag behind turns.
		self.LastFacing = self.LastFacing or forward
		local diff = self.LastFacing - forward
		local speed = 7
		if diff:Length() > 1.5 then speed = speed * diff:Length() / 1.5 end
		diff:Normalize()
		self.LastFacing = ( self.LastFacing + diff * speed * FrameTime() ):GetNormalized()
		pos = pos - diff * 5
		-- Sway with speed.
		local owner = self:GetOwner()
		local len = owner:GetVelocity():Length2D() * 2 + 50
		local target = owner:GetMoveType() ~= MOVETYPE_NOCLIP and math.Clamp( len / 200, 0, 1.5 ) or 0
		swaymul = Lerp( 0.1, swaymul, target )
		pos = pos + ang:Up() * math.sin( CurTime() * 1.2 ) * swaymul + ang:Right() * math.sin( CurTime() * 1.5 ) * swaymul * 1.2
		return pos - forward * 5, ang
	end
end
