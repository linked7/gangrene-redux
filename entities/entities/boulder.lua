-- A boulder (step 11, systems/sh_toolsmachine.lua). Break it (a pickaxe hits twice as hard) for
-- ore in stock and labor pay; it comes back a minute later.
AddCSLuaFile()

ENT.Type = "anim"
ENT.GR_Panel3D2D = true
ENT.Base = "base_anim"
ENT.PrintName = "Boulder"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar( "Float", 0, "Integrity" )
	self:NetworkVar( "Bool", 0, "Broken" )
end

if CLIENT then
	function ENT:CrossTexts( ply, ct )
		if self:GetBroken() then return end
		table.insert( ct, { text = "Boulder" } )
		table.insert( ct, { text = "Break it for ore. A pickaxe helps.", font = HUD.Font( "LabelSmall" ) } )
	end

	function ENT:DrawTranslucent()
		if self:GetBroken() then return end
		local ang = self:GetAngles()
		ang:RotateAroundAxis( ang:Up(), 90 )
		ang:RotateAroundAxis( ang:Forward(), 90 )
		cam.Start3D2D( self:LocalToWorld( Vector( 0, 0, self:OBBMaxs().z + 6 ) ), ang, 0.16 )
			surface.SetDrawColor( 0, 0, 0, 200 )
			surface.DrawRect( -100, -12, 200, 24 )
			surface.SetDrawColor( 160, 140, 110, 255 )
			surface.DrawRect( -98, -10, 196 * self:GetIntegrity() / ToolsMachine.BOULDER_INTEGRITY, 20 )
		cam.End3D2D()
	end
	return
end

function ENT:Initialize()
	-- Loose physics rocks, as in Gangrene: they drop where they spawn and hits knock them about
	local mdls = { "models/props_wasteland/rockgranite03a.mdl", "models/props_wasteland/rockgranite03b.mdl", "models/props_wasteland/rockgranite03c.mdl" }
	self:SetModel( mdls[ math.random( #mdls ) ] )
	self:PhysicsInit( SOLID_VPHYSICS )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:Wake() end
	self.GR_Home = { self:GetPos(), self:GetAngles() }
	self:SetIntegrity( ToolsMachine.BOULDER_INTEGRITY )
	ToolsMachine.Track( self )
end

function ENT:OnTakeDamage( dmg )
	self:TakePhysicsDamage( dmg )
	ToolsMachine.BoulderDamaged( self, dmg )
end
