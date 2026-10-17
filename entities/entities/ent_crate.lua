-- A crate of one good, made by the lunch machine (step 11.1, systems/sh_lunch.lua). Use picks it up (physics carry, which
-- slows the carrier); touching it to a state_stockpile delivers it; "Open the crate" in the C menu
-- breaks it open. Server-only fields: GR_Kind (the good), GR_Crew (the crew's DB.Keys), GR_Station (the machine).
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Crate"
ENT.Spawnable = false

local MASS = 30 -- light enough for a hand pickup

function ENT:SetupDataTables()
	self:NetworkVar( "String", 0, "Kind" ) -- for labels; the server reads GR_Kind
end

if CLIENT then return end

function ENT:Initialize()
	self:SetModel( "models/props_junk/wood_crate001a.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then
		phys:SetMass( MASS )
		phys:Wake()
	end
end

function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() or not activator:Alive() or activator:IsGhost() then return end
	if self:IsPlayerHolding() then return end
	activator:PickupObject( self )
end

-- Removing an entity inside a physics callback is unsafe, so the touch is handled in Think.
function ENT:PhysicsCollide( data )
	local hit = data.HitEntity
	if IsValid( hit ) and hit:GetClass() == "state_stockpile" and not self.GR_Taken then
		self.GR_TouchedStockpile = hit
		self:NextThink( CurTime() )
	end
end

function ENT:Think()
	local stockpile = self.GR_TouchedStockpile
	if not stockpile then return end
	self.GR_TouchedStockpile = nil
	local ply = Crates.Deliverer( self )
	if ply then Crates.Deliver( ply, self, stockpile ) end
end

function ENT:OnRemove()
	Crates.Forget( self )
end
