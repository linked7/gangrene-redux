-- The tools machine (step 11, systems/sh_toolsmachine.lua). Shows a symbol; pressing the matching
-- one of its 8 buttons builds a random tool from stock metal, a wrong one shocks. Needs a running
-- generator nearby.
AddCSLuaFile()

ENT.Type = "anim"
ENT.GR_Panel3D2D = true
ENT.Base = "base_anim"
ENT.PrintName = "Tools Machine"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "Target" )
	self:NetworkVar( "String", 0, "Buttons" )
end

if CLIENT then
	local COLORS = { Color( 255, 110, 30 ), Color( 180, 180, 180 ), Color( 80, 160, 255 ) }

	function ENT:CrossTexts( ply, ct )
		table.insert( ct, { text = "Tools Machine" } )
		table.insert( ct, { text = "Press the button that matches the symbol.", font = HUD.Font( "LabelSmall" ) } )
	end

	function ENT:DrawTranslucent()
		local ang = self:GetAngles()
		ang:RotateAroundAxis( ang:Up(), 90 )
		ang:RotateAroundAxis( ang:Forward(), 90 )
		local t = self:GetTarget()
		cam.Start3D2D( self:LocalToWorld( Vector( 15, 0, 40 ) ), ang, 0.1 )
			surface.SetDrawColor( 0, 0, 0, 230 )
			surface.DrawRect( -120, -30, 240, 40 )
			draw.SimpleText( "MAKE: " .. string.upper( ToolsMachine.SYMBOLS[ t ] or "?" ), "Trebuchet24", 0, -25,
				COLORS[ t ] or color_white, TEXT_ALIGN_CENTER )
		cam.End3D2D()
		for k = 1, ToolsMachine.BUTTONS do
			local s = ToolsMachine.Symbol( self, k )
			cam.Start3D2D( ToolsMachine.ButtonPos( self, k ), ang, 0.1 )
				surface.SetDrawColor( COLORS[ s ] or color_white )
				surface.DrawRect( -25, -25, 50, 50 )
				draw.SimpleText( string.upper( ( ToolsMachine.SYMBOLS[ s ] or "?" ):sub( 1, 1 ) ), "Trebuchet24", 0, 0,
					color_black, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			cam.End3D2D()
		end
	end
	return
end

function ENT:Initialize()
	self:SetModel( "models/props_wasteland/laundry_washer003.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetUseType( SIMPLE_USE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
	ToolsMachine.Reroll( self )
	ToolsMachine.Track( self )
end

function ENT:Use( activator ) ToolsMachine.Use( activator, self ) end
