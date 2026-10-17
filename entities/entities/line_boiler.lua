-- The lunch machine's boiler (step 11.1). Holds water (full barrels touching it pour in); its
-- pressure 0-100 creeps up on its own. Use on the red handle vents, on the black one builds (the
-- gr_valve receiver). Too high and it vents scalding steam (systems/sh_lunch.lua). Pressure, water
-- and the vent are public and drawn on it.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Boiler"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar( "Float", 0, "Pressure" )
	self:NetworkVar( "Bool", 0, "Venting" )
	self:NetworkVar( "Int", 0, "Water" )
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
		render.SetColorMaterial()
		local center = self:LocalToWorld( Vector( self:OBBMaxs().x - 2, 0, ( self:OBBMins().z + self:OBBMaxs().z ) / 2 ) )
		for _, h in ipairs( { { "vent", Color( 200, 30, 30 ) }, { "build", Color( 25, 25, 25 ) } } ) do
			local p = Lunch.HandlePos( self, h[ 1 ] )
			render.DrawBeam( center, p, 1.5, 0, 1, Color( 90, 90, 90 ) )
			render.DrawSphere( p, 2.5, 10, 10, h[ 2 ] )
		end
	end

	function ENT:DrawTranslucent()
		local ang = self:GetAngles()
		ang:RotateAroundAxis( ang:Up(), 90 )
		ang:RotateAroundAxis( ang:Forward(), 90 )
		local top = self:LocalToWorld( Vector( self:OBBMaxs().x + 1, 0, self:OBBMaxs().z - 6 ) )
		local p = self:GetPressure()
		cam.Start3D2D( top, ang, 0.1 )
			local w, h = 260, 110
			local x, y = -w / 2, -h
			surface.SetDrawColor( 0, 0, 0, 230 )
			surface.DrawRect( x, y, w, h )
			-- The dial: dark under GREEN_MIN, green to GREEN_MAX, orange to VENT_AT, red above.
			local bx, bw = x + 10, w - 20
			local bands = { { 0, Lunch.GREEN_MIN, Color( 50, 50, 50 ) }, { Lunch.GREEN_MIN, Lunch.GREEN_MAX, Color( 40, 150, 40 ) },
				{ Lunch.GREEN_MAX, Lunch.VENT_AT, Color( 200, 120, 0 ) }, { Lunch.VENT_AT, 100, Color( 180, 20, 20 ) } }
			for _, b in ipairs( bands ) do
				surface.SetDrawColor( b[ 3 ] )
				surface.DrawRect( bx + bw * b[ 1 ] / 100, y + 40, bw * ( b[ 2 ] - b[ 1 ] ) / 100, 20 )
			end
			surface.SetDrawColor( 255, 255, 255, 255 )
			surface.DrawRect( bx + bw * p / 100 - 2, y + 34, 4, 32 )
			draw.SimpleText( string.format( "PRESSURE %d", math.floor( p ) ), "Trebuchet24", 0, y + 6,
				self:GetVenting() and Color( 255, 60, 60 ) or color_white, TEXT_ALIGN_CENTER )
			draw.SimpleText( self:GetVenting() and "VENTING" or ( "Water: " .. self:GetWater() ), "Trebuchet18", 0, y + 74,
				self:GetWater() == 0 and Color( 255, 80, 80 ) or color_white, TEXT_ALIGN_CENTER )
		cam.End3D2D()
	end

	function ENT:Think()
		if not self:GetVenting() then return end
		local emitter = ParticleEmitter( self:GetPos() )
		if not emitter then return end
		for _ = 1, 3 do
			local p = emitter:Add( "particle/particle_smokegrenade", self:WorldSpaceCenter() + Vector( 0, 0, 30 ) )
			if p then
				p:SetVelocity( VectorRand() * 120 + Vector( 0, 0, 80 ) )
				p:SetDieTime( 1.2 )
				p:SetStartAlpha( 120 )
				p:SetEndAlpha( 0 )
				p:SetStartSize( 12 )
				p:SetEndSize( 60 )
				p:SetColor( 230, 230, 230 )
			end
		end
		emitter:Finish()
		self:SetNextClientThink( CurTime() + 0.1 )
		return true
	end
	return
end

function ENT:Initialize()
	self:SetModel( "models/props_c17/furnitureboiler001a.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
	self:SetPressure( Lunch.PRESSURE_START )
	Lunch.Track( self )
end

function ENT:OnRemove()
	self:StopSound( "ambient/gas/steam2.wav" )
end
