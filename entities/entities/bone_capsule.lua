-- A bone capsule (step 11.1), copied from the original's fleshcapsule: raw material for the lunch
-- machine. Smash it (melee or bullets take its Integrity, shown as "Blood") into two meat chunks,
-- or carry it whole like a crate. Thrown, it hurts at a tenth of physics damage. Spawned and
-- removed by systems/sh_lunch.lua.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Bone Capsule"
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "Integrity" )
end

if CLIENT then
	-- The cross-texts (cl_crosshair.lua), as the original's fleshcapsule: the name and a "Blood" bar.
	function ENT:CrossTexts( ply, ct )
		local small = HUD.Font( "LabelSmall" )
		table.insert( ct, { text = "Bone Capsule" } )
		table.insert( ct, { text = "Blood", bar = math.Clamp( self:GetIntegrity() / Lunch.CAPSULE_INTEGRITY, 0, 1 ), color = Color( 150, 0, 0 ) } )
		table.insert( ct, { text = "Take it to a lunch factory.", font = small } )
		table.insert( ct, { text = "Alternatively, break it for resources.", font = small } )
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
