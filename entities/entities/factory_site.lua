-- A factory site a worker paid to put down (step 11.1 construction, sh_build.lua). It is a work
-- station like the ration press: anyone may work it (Crates runs the loop) and the crate gets the
-- worker's key. Its builder picks what it makes from Factory.Kinds (systems/sh_factory.lua).
-- GR_BuiltBy (server) / GetBuiltBy() (networked) is the builder's DB.Key.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Factory Site"
ENT.Spawnable = false
ENT.WorkVerb = "Making"

function ENT:SetupDataTables()
	self:NetworkVar( "String", 0, "Good" )
	self:NetworkVar( "String", 1, "BuiltBy" )
end

if CLIENT then return end

function ENT:Initialize()
	if self:GetGood() == "" then self:SetGood( Factory.DEFAULT ) end
	if self.GR_BuiltBy then self:SetBuiltBy( self.GR_BuiltBy ) end
	self:SetModel( "models/props_c17/pallet01a.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetUseType( SIMPLE_USE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
end

function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() then return end
	Crates.Work( activator, self )
end
