-- A stockpile port (replaces the old gr_shop): a window onto the one shared stockpile and treasury.
-- Use opens the menu (systems/sh_shop.lua): buy goods out of stock, or sell small goods (beer,
-- spirits) back into it. Bulk crates still go to the main state_stockpile.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Stockpile Port"
ENT.Spawnable = false

if CLIENT then
	function ENT:CrossTexts( ply, ct )
		table.insert( ct, { text = "Stockpile Port" } )
		table.insert( ct, { text = "Press E to buy, or to sell beer and spirits.", font = HUD.Font( "LabelSmall" ) } )
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
