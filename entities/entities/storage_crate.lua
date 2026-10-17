-- A storage crate a worker paid to put down (step 11.1 construction, sh_build.lua): a lockable
-- box of up to Storage.CAPACITY items. Storage (systems/sh_storage.lua) holds the logic; the
-- contents live in self.GR_Items { itemId -> count } and are mirrored to clients as "Contents".
-- GR_BuiltBy (server) / GetBuiltBy() (networked) is the builder's DB.Key.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Storage Crate"
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar( "Bool", 0, "Locked" )
	self:NetworkVar( "String", 0, "BuiltBy" )
	self:NetworkVar( "String", 1, "Contents" ) -- "id=n,id=n", for the Take menu
end

if CLIENT then return end

function ENT:Initialize()
	self.GR_Items = self.GR_Items or {}
	if self.GR_BuiltBy then self:SetBuiltBy( self.GR_BuiltBy ) end
	self:SetLocked( true ) -- a new crate starts locked; its builder can open it up
	self:SetModel( "models/props_junk/wood_crate002a.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:Wake() end
end

function ENT:OnRemove()
	Storage.Spill( self )
end
