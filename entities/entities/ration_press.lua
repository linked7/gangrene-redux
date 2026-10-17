-- A work station (step 11.1). Working it (Use, or "Work the press" in the C menu) is a timed
-- action that ends with a crate of its good beside it; Crates (systems/sh_crates.lua) runs the loop.
-- The `good` key value picks what it makes: "ration" (default) or "clean_water".
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Ration Press"
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar( "String", 0, "Good" )
end

function ENT:KeyValue( key, value )
	if key == "good" then self:SetGood( value ) end
end

if CLIENT then return end

function ENT:Initialize()
	if self:GetGood() == "" then self:SetGood( "ration" ) end
	self:SetModel( "models/props_wasteland/laundry_washer003.mdl" )
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
