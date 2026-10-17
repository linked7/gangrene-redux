-- The sanitation station: where police spend Teeth on weapons. The offers are data
-- (Police.OFFERS, sh_police.lua) and each one is a context-menu option on this entity.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Sanitation Station"
ENT.Spawnable = false

if CLIENT then return end

function ENT:Initialize()
	self:SetModel( "models/props_c17/lockers001a.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetUseType( SIMPLE_USE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
end

-- Using it reads out the price list; buying is in the context menu (hold C).
function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() or activator:IsGhost() then return end
	if not activator:FateHas( "Police" ) then
		Notify( activator, "The station is locked. It serves the sanitation service only." )
		return
	end
	local lines = {}
	for _, o in ipairs( Police.OFFERS ) do
		table.insert( lines, string.format( "%s: %d teeth", Items.Get( o.item ).Name, o.teeth ) )
	end
	Notify( activator, string.format( "You have %d teeth. %s. (hold C to buy)", activator:GetTeeth(), table.concat( lines, "; " ) ) )
end
