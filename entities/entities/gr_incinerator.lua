-- The incinerator: bodies dragged here by hand are burned (sh_sanitar.lua).
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Incinerator"
ENT.Spawnable = false

function ENT:Initialize()
	if CLIENT then return end
	self:SetModel( "models/props_c17/furnitureboiler001a.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
	Sanitar.Track( self )
end

if SERVER then return end

function ENT:CrossTexts( ply, ct )
	table.insert( ct, { text = "Incinerator" } )
	table.insert( ct, { text = "Drag bodies here to burn them.", font = HUD.Font( "LabelSmall" ) } )
end
