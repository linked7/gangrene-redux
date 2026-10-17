-- A storage crate a worker paid to put down (step 11.1 construction, sh_build.lua). A physical
-- placeholder for now; storing items in it comes with later work. GR_BuiltBy is the builder's DB.Key.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Storage Crate"
ENT.Spawnable = false

if CLIENT then return end

function ENT:Initialize()
	self:SetModel( "models/props_junk/wood_crate002a.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:Wake() end
end
