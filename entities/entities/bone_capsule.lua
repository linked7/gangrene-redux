-- A bone capsule (step 11.1), copied from the original's fleshcapsule: raw material for the lunch
-- machine. Smash it (melee or bullets take its Integrity, shown as "Blood") into two meat chunks,
-- or carry it whole like a crate. Thrown, it hurts at a tenth of physics damage. Spawned and
-- removed by systems/sh_lunch.lua.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Bone Capsule"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "Integrity" )
end

if CLIENT then
	-- The cross-text, when looked at: the name and a "Blood" bar.
	function ENT:DrawTranslucent()
		local ply = LocalPlayer()
		if ply:GetEyeTrace().Entity ~= self or ply:GetPos():DistToSqr( self:GetPos() ) > 400 * 400 then return end
		local ang = Angle( 0, ply:EyeAngles().y - 90, 90 )
		cam.Start3D2D( self:WorldSpaceCenter() + Vector( 0, 0, 20 ), ang, 0.1 )
			draw.SimpleTextOutlined( "Bone Capsule", "Trebuchet24", 0, -30, Color( 200, 200, 200 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black )
			surface.SetDrawColor( 0, 0, 0, 200 )
			surface.DrawRect( -80, -12, 160, 20 )
			surface.SetDrawColor( 150, 0, 0, 255 )
			surface.DrawRect( -78, -10, 156 * math.Clamp( self:GetIntegrity() / Lunch.CAPSULE_INTEGRITY, 0, 1 ), 16 )
			draw.SimpleText( "Blood", "Trebuchet18", 0, -2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			draw.SimpleTextOutlined( "Take it to the lunch machine, or break it.", "Trebuchet18", 0, 22, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black )
		cam.End3D2D()
	end
	return
end

function ENT:Initialize()
	self:SetModel( "models/gibs/antlion_gib_large_3.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
	self:SetIntegrity( Lunch.CAPSULE_INTEGRITY )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then
		phys:SetMass( Lunch.CAPSULE_MASS )
		phys:Wake()
	end
	Lunch.Track( self )
end

function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() or not activator:Alive() or activator:IsGhost() then return end
	if self:IsPlayerHolding() then return end
	activator:PickupObject( self )
	activator:EmitSound( "physics/body/body_medium_impact_soft" .. math.random( 3 ) .. ".wav", 75 )
end

function ENT:OnTakeDamage( dmg )
	self:TakePhysicsDamage( dmg )
	Lunch.CapsuleDamaged( self, dmg )
end

function ENT:OnRemove()
	Crates.Forget( self )
end
