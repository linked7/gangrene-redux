-- A water barrel (step 11.1). Empty, it fills over Lunch.FILL_TIME s while it is in map water;
-- full, it is heavy (carried like a crate, Crates.IsHeavy) and pours Lunch.BARREL_WATER (half a
-- boiler) into a line_boiler it touches, then is empty again. Players build them (Build, capped).
-- Pumps never fill it: they are for drinking. The rules are in systems/sh_lunch.lua.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Water Barrel"
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar( "Bool", 0, "Full" )
end

if CLIENT then
	-- The cross-texts (cl_crosshair.lua), not text floating over it.
	function ENT:CrossTexts( ply, ct )
		table.insert( ct, { text = "Water Barrel" } )
		table.insert( ct, { text = self:GetFull() and "Full. Pour it into the boiler." or "Empty. Leave it in water to fill.",
			font = HUD.Font( "LabelSmall" ), color = self:GetFull() and Color( 120, 180, 255 ) or nil } )
	end
	return
end

function ENT:Initialize()
	self:SetModel( "models/props_borealis/bluebarrel001.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then
		phys:SetMass( Lunch.BARREL_MASS_EMPTY )
		phys:Wake()
	end
	Lunch.Track( self )
end

function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() or not activator:Alive() or activator:IsGhost() then return end
	if self:IsPlayerHolding() then return end
	activator:PickupObject( self )
end

function ENT:OnRemove()
	Crates.Forget( self )
end
