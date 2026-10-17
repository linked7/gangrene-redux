-- A "purpose in life": a ghost uses it to take the fate named by its `fate` key value.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Purpose in Life"
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar( "String", 0, "FateId" )
end

function ENT:KeyValue( key, value )
	if key == "fate" then self:SetFateId( value ) end
end

if CLIENT then
	function ENT:Draw()
		-- Only the dead see purposes; the living walk past them.
		if LocalPlayer():IsGhost() then self:DrawModel() end
	end
	return
end

function ENT:Initialize()
	-- The original's purpose in life: a sawblade with the Combine interface material (no hologram).
	self:SetModel( "models/props_junk/sawblade001a.mdl" )
	self:SetMaterial( "models/props_combine/masterinterface01c" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetUseType( SIMPLE_USE )
	self:SetCollisionGroup( COLLISION_GROUP_WORLD )
end

function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() or not activator:IsGhost() then return end
	Fates.Take( activator, self:GetFateId() )
end
