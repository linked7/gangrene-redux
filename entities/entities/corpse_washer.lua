AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Corpse Washer"
ENT.Spawnable = false

if CLIENT then return end

function ENT:Initialize()
	self:SetModel( "models/props_c17/FurnitureBathtub001a.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
	Rotting.washers[ self ] = true
end

function ENT:OnRemove() Rotting.washers[ self ] = nil end
