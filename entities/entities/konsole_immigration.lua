-- The Immigration Kontrol Konsole (step 13, new: the original had none). It stands in the
-- Gate Antechamber. A migrant holding `papers` uses it through Interact "gate_passport"
-- (systems/sh_roundflow.lua): the papers become a passport and the migrant a Prole.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Immigration Kontrol Konsole"
ENT.Spawnable = false

if CLIENT then
	function ENT:CrossTexts( ply, ct )
		table.insert( ct, { text = "Immigration Kontrol Konsole" } )
		table.insert( ct, { text = "Hand over your papers to enter Gangrene.", font = HUD.Font( "LabelSmall" ) } )
	end
	return
end

function ENT:Initialize()
	self:SetModel( "models/props_lab/monitor02.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetUseType( SIMPLE_USE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
end

function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() or activator:IsGhost() then return end
	RoundFlow.Trade( activator )
end
