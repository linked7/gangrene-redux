-- The lunch machine (step 11.1), rebuilt from the original's machine_lunch. Use on a panel button
-- presses it, use on the lever flips the product; meat chunks and capsules touching it are
-- swallowed as biomass. Its state is public and drawn on it in 3D2D, as in the original.
-- The rules are in systems/sh_lunch.lua; the `output` key value sets the starting product.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Lunch Machine"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "Biomass" )
	self:NetworkVar( "Int", 1, "Light" )
	self:NetworkVar( "String", 0, "Output" )
	self:NetworkVar( "String", 1, "Status" )
	for k = 1, 8 do self:NetworkVar( "Int", 1 + k, "Button" .. k ) end
end

function ENT:GetButton( k ) return self[ "GetButton" .. k ]( self ) end
function ENT:SetButton( k, v ) self[ "SetButton" .. k ]( self, v ) end

function ENT:KeyValue( key, value )
	if key == "output" then self.GR_StartOutput = value end
end

if CLIENT then
	local MATS = { Material( "icon16/heart.png" ), Material( "icon16/pill.png" ), Material( "icon16/water.png" ) }
	local OFF = Material( "icon16/lightbulb_off.png" )
	local noise = Material( "effects/tvscreen_noise001a" )

	-- Machines keep their state drawn on the model in 3D2D; the cross-texts only name it.
	function ENT:CrossTexts( ply, ct )
		table.insert( ct, { text = "Lunch Machine" } )
		table.insert( ct, { text = "Feed it bone capsules and meat. Pull the lever, press the lit button.", font = HUD.Font( "LabelSmall" ) } )
	end

	local function lit( self ) return self:GetStatus() == "on" or self:GetStatus() == "overload" end

	function ENT:Draw()
		self:DrawModel()
		local t = CurTime()
		-- The lever: a short bar that leans left for ration, right for clean water.
		local lever = Lunch.LeverPos( self )
		local tip = lever + self:GetUp() * 6 + self:GetRight() * ( self:GetOutput() == "ration" and -3 or 3 )
		render.SetColorMaterial()
		render.DrawBeam( lever, tip, 1, 0, 1, Color( 60, 60, 60 ) )
		render.DrawSphere( tip, 1.2, 8, 8, self:GetOutput() == "ration" and Color( 200, 60, 40 ) or Color( 60, 120, 220 ) )
		if not lit( self ) then return end
		for i = 1, 3 do
			render.SetMaterial( MATS[ i ] )
			local s = self:GetLight() == i and 4 + math.sin( t * 10 ) or 3
			render.DrawSprite( Lunch.LightPos( self, i ), s, s, self:GetLight() == i and color_white or Color( 90, 90, 90 ) )
		end
		local aim = LocalPlayer():GetEyeTrace()
		local near = aim.Entity == self and Lunch.ButtonAt( self, aim.HitPos )
		for k = 1, Lunch.BUTTONS do
			local idx = self:GetButton( k )
			local c = 255
			if idx == 0 then
				render.SetMaterial( OFF )
				c = 100
			else
				render.SetMaterial( MATS[ idx ] )
				c = k == near and 205 + 50 * math.sin( t * 3 ) or 155 + 100 * math.cos( t )
			end
			render.DrawSprite( Lunch.ButtonPos( self, k ), 4, 4, Color( c, c, c ) )
		end
	end

	function ENT:DrawTranslucent()
		local ang = self:GetAngles()
		ang:RotateAroundAxis( ang:Up(), -90 )
		ang:RotateAroundAxis( ang:Forward(), 90 )
		ang:RotateAroundAxis( ang:Right(), -180 )
		local f, r, u = self:GetForward(), self:GetRight(), self:GetUp()
		local pos = self:GetPos()

		-- The title and what the panel is doing.
		cam.Start3D2D( pos + u * 28 + f * 13 + r * 7.4, ang, 0.1 )
			surface.SetMaterial( noise )
			surface.SetDrawColor( 255, 255, 255, 255 )
			surface.DrawTexturedRect( 0, 0, 236, 78 )
			draw.SimpleText( "Lunch Machine", "Trebuchet24", 118, 24, HSVToColor( ( CurTime() * 23 ) % 180, 1, 1 ), TEXT_ALIGN_CENTER )
			local status = self:GetStatus()
			draw.SimpleText( Lunch.STATUS_TEXT[ status ] or status, "Trebuchet18", 118, 52,
				lit( self ) and ( status == "overload" and Color( 255, 160, 0 ) or Color( 120, 255, 120 ) ) or Color( 255, 60, 60 ), TEXT_ALIGN_CENTER )
		cam.End3D2D()

		-- The biomass gauge.
		cam.Start3D2D( pos + u * 14.7 + f * 13 + r * 3, ang, 0.1 )
			local b = self:GetBiomass()
			surface.SetDrawColor( 0, 0, 0, 255 )
			surface.DrawRect( 0, 0, 140, 36 )
			local glow = 150 + 100 * math.sin( CurTime() )
			surface.SetDrawColor( glow, glow, 0, 255 )
			surface.DrawRect( 0, 36 - 36 * math.min( b / Lunch.BIOMASS_MAX, 1 ), 140 * 1, 36 * math.min( b / Lunch.BIOMASS_MAX, 1 ) )
			draw.SimpleText( b .. " Biomass", "TargetID", 70, 8, b == 0 and Color( 255, 80, 80 ) or color_white, TEXT_ALIGN_CENTER )
		cam.End3D2D()

		-- The product.
		cam.Start3D2D( pos + u * 10.7 + f * 13 + r * 6.15, ang, 0.1 )
			surface.SetDrawColor( 0, 0, 0, 255 )
			surface.DrawRect( 0, 0, 209, 40 )
			draw.SimpleText( "Making: " .. Lunch.OutputName( self:GetOutput() ), "Trebuchet18", 104, 10, color_white, TEXT_ALIGN_CENTER )
		cam.End3D2D()
	end
	return
end

function ENT:Initialize()
	self:SetModel( "models/props_lab/reciever_cart.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetUseType( SIMPLE_USE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
	self:SetOutput( Lunch.OUTPUTS[ self.GR_StartOutput or "" ] and self.GR_StartOutput or "ration" )
	self:SetStatus( "low" )
	Lunch.Reroll( self )
	Lunch.Track( self )
end

function ENT:Use( activator )
	if IsValid( activator ) and activator:IsPlayer() then Lunch.Use( activator, self ) end
end
