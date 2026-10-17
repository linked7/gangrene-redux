-- A factory site a worker paid to put down (step 11.1 construction, sh_build.lua). It only marks
-- the ground for now; what gets built on it comes with later work. GR_BuiltBy is the builder's DB.Key.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Factory Site"
ENT.Spawnable = false

if CLIENT then return end

function ENT:Initialize()
	self:SetModel( "models/props_c17/pallet01a.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
end
