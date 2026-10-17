-- The crucible (step 11, systems/sh_toolsmachine.lua). Heats near a running generator and smelts
-- stock: ore -> pot metal -> ballistic -> formic steel. Use changes what it smelts.
AddCSLuaFile()

ENT.Type = "anim"
ENT.GR_Panel3D2D = true
ENT.Base = "base_anim"
ENT.PrintName = "Crucible"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar( "Float", 0, "Heat" )
	self:NetworkVar( "Int", 0, "Mode" )
end

if CLIENT then
	function ENT:CrossTexts( ply, ct )
		table.insert( ct, { text = "Crucible" } )
		table.insert( ct, { text = "Use to change what it smelts. Needs a running generator.", font = HUD.Font( "LabelSmall" ) } )
	end

	function ENT:DrawTranslucent()
		local ang = self:GetAngles()
		ang:RotateAroundAxis( ang:Up(), 90 )
		ang:RotateAroundAxis( ang:Forward(), 90 )
		local mode = ToolsMachine.VAT[ self:GetMode() ]
		local item = mode and Items.Get( mode.out )
		cam.Start3D2D( self:LocalToWorld( Vector( self:OBBMaxs().x + 1, 0, self:OBBMaxs().z + 4 ) ), ang, 0.16 )
			surface.SetDrawColor( 0, 0, 0, 230 )
			surface.DrawRect( -130, -60, 260, 60 )
			draw.SimpleText( string.format( "HEAT %d", self:GetHeat() ), "Trebuchet24", 0, -58,
				mode and self:GetHeat() >= mode.heat and Color( 255, 120, 30 ) or color_white, TEXT_ALIGN_CENTER )
			draw.SimpleText( item and item.Name or "?", "Trebuchet18", 0, -28, color_white, TEXT_ALIGN_CENTER )
		cam.End3D2D()
	end
	return
end

function ENT:Initialize()
	self:SetModel( "models/props_c17/oildrum001.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetUseType( SIMPLE_USE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
	self:SetMode( 1 )
	ToolsMachine.Track( self )
end

function ENT:Use( activator ) ToolsMachine.CycleVat( activator, self ) end
