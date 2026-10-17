-- The lunch machine's boiler (step 11.1). Holds water (full barrels touching it pour in); its
-- pressure 0-100 creeps up on its own. Holding Use on the red valve wheel vents, on the black one
-- builds (the gr_valve receiver). Too high and it vents scalding steam (systems/sh_lunch.lua). Pressure, water
-- and the vent are public and drawn on it.
AddCSLuaFile()

ENT.Type = "anim"
ENT.GR_Panel3D2D = true
ENT.Base = "base_anim"
ENT.PrintName = "Boiler"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar( "Float", 0, "Pressure" )
	self:NetworkVar( "Bool", 0, "Venting" )
	self:NetworkVar( "Int", 0, "Water" )
	self:NetworkVar( "String", 0, "Turning" ) -- "vent", "build" or "": the wheel someone is holding
end

if CLIENT then
	-- The two valves are real valve wheels (clientside models): red vents, black builds. A wheel
	-- turns while someone holds Use on it (GetTurning), and stays where it was left.
	local VALVE = "models/props_pipes/valvewheel001.mdl"
	local VALVES = { vent = Color( 255, 255, 255 ), build = Color( 40, 40, 40 ) }

	function ENT:Valve( dir )
		self.GR_Valves = self.GR_Valves or {}
		local m = self.GR_Valves[ dir ]
		if not IsValid( m ) then
			m = ClientsideModel( VALVE, RENDERGROUP_OPAQUE )
			if not IsValid( m ) then return end
			m:SetNoDraw( true )
			m:SetModelScale( 0.5 )
			m:SetColor( VALVES[ dir ] )
			self.GR_Valves[ dir ] = m
		end
		return m
	end

	function ENT:Draw()
		self:DrawModel()
		self.GR_Spin = self.GR_Spin or { vent = 0, build = 0 }
		local turning = self:GetTurning()
		if VALVES[ turning ] then
			self.GR_Spin[ turning ] = self.GR_Spin[ turning ] + FrameTime() * ( turning == "vent" and -240 or 240 )
		end
		for dir, col in pairs( VALVES ) do
			local m = self:Valve( dir )
			if m then
				local ang = self:GetAngles()
				ang:RotateAroundAxis( ang:Right(), -90 ) -- the wheel faces out of the boiler's front
				ang:RotateAroundAxis( ang:Up(), self.GR_Spin[ dir ] )
				m:SetPos( Lunch.HandlePos( self, dir ) )
				m:SetAngles( ang )
				render.SetColorModulation( col.r / 255, col.g / 255, col.b / 255 )
				m:DrawModel()
				render.SetColorModulation( 1, 1, 1 )
			end
		end
	end

	function ENT:OnRemove()
		for _, m in pairs( self.GR_Valves or {} ) do if IsValid( m ) then m:Remove() end end
	end

	function ENT:CrossTexts( ply, ct )
		table.insert( ct, { text = "Boiler" } )
		table.insert( ct, { text = "Hold use on the red wheel to vent, the black one to build pressure.", font = HUD.Font( "LabelSmall" ) } )
	end

	function ENT:DrawTranslucent()
		local ang = self:GetAngles()
		ang:RotateAroundAxis( ang:Up(), 90 )
		ang:RotateAroundAxis( ang:Forward(), 90 )
		local top = self:LocalToWorld( Vector( self:OBBMaxs().x + 1, 0, self:OBBMaxs().z - 6 ) )
		local p = self:GetPressure()
		cam.Start3D2D( top, ang, 0.16 )
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
