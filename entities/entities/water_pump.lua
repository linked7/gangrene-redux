-- A water pump: a drinking faucet. Anyone alive drinks dirty water straight from it, then waits Inventory.PUMP_COOLDOWN.
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

-- Drinking straight from the tap, as the original faucet: one gulp per use, then a short wait.
local TASTE = { "Worms in the water!", "Tastes horrible.", "Tastes terrible.", "There's something squirming.", "The faucet gurgles.", "Scum and worms.", "Putrid stench." }

function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() or not activator:Alive() or activator:IsGhost() then return end
	local now = CurTime()
	if ( activator.GR_PumpReadyAt or 0 ) > now then return end
	activator.GR_PumpReadyAt = now + Inventory.PUMP_COOLDOWN
	local def = Items.Get( "dirty_water" )
	for name, amount in pairs( def.Effects ) do Needs.Add( activator, name, amount, "faucet" ) end
	def.OnUse( activator )
	activator:EmitSound( "npc/barnacle/barnacle_gulp" .. math.random( 1, 2 ) .. ".wav", 75, math.random( 80, 110 ) )
	self:EmitSound( "ambient/water/water_pump_drainin1.wav", 60, math.random( 80, 120 ) )
	if math.random( 1, 3 ) == 1 then Notify( activator, TASTE[ math.random( #TASTE ) ] ) end
end
