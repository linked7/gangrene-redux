-- The lovebox: the korpsman's reward for a first revive. No bar, no menu: hold the button near a patient.
--   Primary:   heals the patient (+2 HP per tick) at 1 HP a tick from you.
--   Secondary: lowers the patient's Pox, and you may catch some.
--   Reload:    on a patient below a quarter health, pulls out one of their parasites.
AddCSLuaFile()

SWEP.Base = "weapon_gr_base"
SWEP.PrintName = "Lovebox"
SWEP.Slot = 4
SWEP.ViewModel = "models/weapons/c_medkit.mdl"
SWEP.WorldModel = "models/weapons/w_medkit.mdl"
SWEP.HoldType = "slam"
SWEP.MovementMult = 0.8

SWEP.Range = 85
SWEP.HealTick = 0.2
SWEP.HealAmount = 2
SWEP.PoxTick = 0.4
SWEP.PoxAmount = 3

if CLIENT then return end

-- The nearest living, visible-by-range player other than the holder.
function SWEP:FindPatient()
	local owner = self:GetOwner()
	if not IsValid( owner ) then return end
	local best, bestD
	for _, p in ipairs( player.GetAll() ) do
		if p ~= owner and p:Alive() and not p:IsGhost() then
			local d = p:GetPos():Distance( owner:GetPos() )
			if d <= self.Range and ( not bestD or d < bestD ) then best, bestD = p, d end
		end
	end
	return best
end

-- The lovebox costs the holder blood; at 1 HP they can't pay and it won't fire.
function SWEP:Pay( owner, hp )
	if owner:Health() - hp < 1 then
		Notify( owner, "You're too weak to give any more." )
		return false
	end
	owner:SetHealth( owner:Health() - hp )
	return true
end

function SWEP:Love( target )
	local owner = self:GetOwner()
	target = target or self:FindPatient()
	if not IsValid( owner ) or not IsValid( target ) then return false end
	if target:Health() >= Medicine.MaxHealth( target ) then return false end
	if not self:Pay( owner, 1 ) then return false end
	Medicine.Heal( target, self.HealAmount )
	return true
end

function SWEP:Soothe( target )
	local owner = self:GetOwner()
	target = target or self:FindPatient()
	if not IsValid( owner ) or not IsValid( target ) then return false end
	local pox = Needs.Get( target, "Pox" )
	if pox <= 0 then return false end
	if not self:Pay( owner, 2 ) then return false end
	Needs.Add( target, "Pox", -self.PoxAmount, "lovebox" )
	if math.random() < pox / 100 then Needs.Add( owner, "Pox", 1, "lovebox" ) end
	return true
end

function SWEP:Extract( target )
	local owner = self:GetOwner()
	target = target or self:FindPatient()
	if not IsValid( owner ) or not IsValid( target ) then return false end
	if target:Health() >= target:GetMaxHealth() / 4 then
		Notify( owner, "They aren't sick enough for that." )
		return false
	end
	local n = Medicine.Parasites( target )
	if n <= 0 then return false end
	Medicine.SetParasites( target, n - 1 )
	Items.Spawn( "parasite", 1, target:GetPos() + Vector( 0, 0, 20 ) )
	return true
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire( CurTime() + self.HealTick )
	self:Love()
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire( CurTime() + self.PoxTick )
	self:Soothe()
end

function SWEP:Reload()
	if ( self.GR_NextExtract or 0 ) > CurTime() then return end
	self.GR_NextExtract = CurTime() + 1
	self:Extract()
end
