-- The generator (step 11, systems/sh_toolsmachine.lua). Use switches it on and off; it burns
-- biofuel from stock, or biofuel items thrown into it (overfilling blows it up). Powers the
-- crucible and the tools machine in range.
AddCSLuaFile()

ENT.Type = "anim"
ENT.GR_Panel3D2D = true
ENT.Base = "base_anim"
ENT.PrintName = "Generator"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar( "Bool", 0, "On" )
	self:NetworkVar( "Float", 0, "Fuel" )
	self:NetworkVar( "Float", 1, "Rust" )
end

if CLIENT then
	function ENT:CrossTexts( ply, ct )
		table.insert( ct, { text = "Generator" } )
		table.insert( ct, { text = "Use to switch it on or off. Feed it biofuel, but not too much.", font = HUD.Font( "LabelSmall" ) } )
	end

	function ENT:DrawTranslucent()
		local ang = self:GetAngles()
		ang:RotateAroundAxis( ang:Up(), 90 )
		ang:RotateAroundAxis( ang:Forward(), 90 )
		local top = self:LocalToWorld( Vector( self:OBBMaxs().x + 1, 0, self:OBBMaxs().z + 4 ) )
		cam.Start3D2D( top, ang, 0.16 )
			surface.SetDrawColor( 0, 0, 0, 230 )
			surface.DrawRect( -130, -60, 260, 60 )
			draw.SimpleText( string.format( "%s  FUEL %d  RUST %d", self:GetOn() and "ON" or "OFF", self:GetFuel(), self:GetRust() ),
				"Trebuchet24", 0, -45, self:GetOn() and Color( 120, 255, 120 ) or color_white, TEXT_ALIGN_CENTER )
		cam.End3D2D()
	end
	return
end

function ENT:Initialize()
	self:SetModel( "models/props_vehicles/generatortrailer01.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetUseType( SIMPLE_USE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
	ToolsMachine.Track( self )
end

function ENT:Use( activator ) ToolsMachine.Toggle( activator, self ) end
