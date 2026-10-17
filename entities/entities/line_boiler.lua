-- The lunch machine's boiler (step 11.1). Holds water (full barrels touching it pour in); its
-- pressure 0-100 creeps up on its own. Holding Use on the red valve wheel vents, on the black one
-- builds (the gr_valve receiver). Too high and it vents scalding steam (systems/sh_lunch.lua). Pressure, water
-- and the vent are public and shown in its cross-texts.
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
	self:NetworkVar( "String", 0, "Turning" ) -- "vent", "build" or "": the wheel someone is holding
end

if CLIENT then
	-- The two valves are real valve wheels (clientside models): red vents, black builds. A wheel
	-- turns while someone holds Use on it (GetTurning), and stays where it was left.
	local VALVE = "models/props_pipes/valvewheel001.mdl"
	local VALVES = { vent = Color( 200, 30, 30 ), build = Color( 40, 40, 40 ) }

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
		local p, small = self:GetPressure(), HUD.Font( "LabelSmall" )
		-- Pressure is coloured by band: grey under GREEN_MIN, green to GREEN_MAX, orange to VENT_AT, red above.
		local col = p < Lunch.GREEN_MIN and Color( 160, 160, 160 ) or p <= Lunch.GREEN_MAX and Color( 80, 200, 80 )
			or p < Lunch.VENT_AT and Color( 230, 150, 30 ) or Color( 255, 60, 60 )
		table.insert( ct, { text = "Boiler" } )
		table.insert( ct, { text = string.format( "Pressure %d (green %d-%d)", math.floor( p ), Lunch.GREEN_MIN, Lunch.GREEN_MAX ), font = small, color = col } )
		table.insert( ct, { text = self:GetVenting() and "VENTING" or ( "Water: " .. self:GetWater() ), font = small,
			color = ( self:GetVenting() or self:GetWater() == 0 ) and Color( 255, 80, 80 ) or nil } )
		table.insert( ct, { text = "Hold use on the red wheel to vent, the black one to build pressure.", font = small } )
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
