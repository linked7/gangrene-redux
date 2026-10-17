-- A water pump: anyone alive gets one dirty water per use, then waits Inventory.PUMP_COOLDOWN.
-- The cooldown is a timestamp on the player, shared by every pump, so pump-hopping doesn't help.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Water Pump"
ENT.Spawnable = false

if CLIENT then return end

function ENT:Initialize()
	self:SetModel( "models/props_interiors/sinkkitchen01a.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetUseType( SIMPLE_USE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
end

function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() or not activator:Alive() or activator:IsGhost() then return end
	local now = CurTime()
	if ( activator.GR_PumpReadyAt or 0 ) > now then
		Notify( activator, "The pump is still dry. Wait a moment." )
		return
	end
	local ok, why = Inventory.Add( activator, "dirty_water", 1 )
	if not ok then
		Notify( activator, why )
		return
	end
	activator.GR_PumpReadyAt = now + Inventory.PUMP_COOLDOWN
	self:EmitSound( "ambient/water/water_spray1.wav", 60 )
end
