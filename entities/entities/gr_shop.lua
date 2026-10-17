-- The shop, rebuilt from the original's capitalist_public. Use on it opens the buy menu
-- (systems/sh_shop.lua); every living fate can buy.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Shop"
ENT.Spawnable = false

if CLIENT then
	function ENT:CrossTexts( ply, ct )
		table.insert( ct, { text = "Shop" } )
		table.insert( ct, { text = "Personal bloodsucking. Press E to buy.", font = HUD.Font( "LabelSmall" ) } )
	end
	return
end

function ENT:Initialize()
	self:SetModel( "models/props_c17/FurnitureFridge001a.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetUseType( SIMPLE_USE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
end

function ENT:Use( activator )
	if IsValid( activator ) and activator:IsPlayer() then Shop.Open( activator, self ) end
end
