-- A water barrel (step 11.1). Empty, it fills over Lunch.FILL_TIME s while it is in map water;
-- full, it is heavy (carried like a crate, Crates.IsHeavy) and pours Lunch.BARREL_WATER crates'
-- worth into a line_boiler it touches, then is empty again. Players build them (Build, capped).
-- Pumps never fill it: they are for drinking. The rules are in systems/sh_lunch.lua.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Water Barrel"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar( "Bool", 0, "Full" )
end

if CLIENT then
	function ENT:DrawTranslucent()
		if LocalPlayer():GetPos():DistToSqr( self:GetPos() ) > 300 * 300 then return end
		local ang = Angle( 0, LocalPlayer():EyeAngles().y - 90, 90 )
		cam.Start3D2D( self:GetPos() + Vector( 0, 0, self:OBBMaxs().z + 6 ), ang, 0.1 )
			draw.SimpleTextOutlined( self:GetFull() and "Full" or "Empty", "Trebuchet24", 0, 0,
				self:GetFull() and Color( 120, 180, 255 ) or Color( 200, 200, 200 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black )
		cam.End3D2D()
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
