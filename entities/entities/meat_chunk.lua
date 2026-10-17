-- A meat chunk (step 11.1): what a burst bone capsule leaves. A light prop; touching it to the
-- lunch machine's maw adds 1 biomass. Gone after Lunch.CHUNK_LIFE (systems/sh_lunch.lua).
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Meat Chunk"
ENT.Spawnable = false

if CLIENT then return end

function ENT:Initialize()
	self:SetModel( "models/gibs/antlion_gib_medium_2.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then
		phys:SetMass( Lunch.CHUNK_MASS )
		phys:Wake()
	end
	Lunch.Track( self )
end

function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() or not activator:Alive() or activator:IsGhost() then return end
	if self:IsPlayerHolding() then return end
	activator:PickupObject( self )
end
