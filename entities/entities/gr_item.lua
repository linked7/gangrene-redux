-- A dropped stack of one inventory item. Using it picks up as much as fits (Inventory.PickUp).
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Item"
ENT.Spawnable = false

local FALLBACK_MODEL = "models/props_junk/cardboard_box004a.mdl"

function ENT:SetupDataTables()
	self:NetworkVar( "String", 0, "ItemId" )
	self:NetworkVar( "Int", 0, "Count" )
end

if CLIENT then return end

function ENT:Initialize()
	local def = Items.Get( self:GetItemId() )
	if not def then
		Log.Error( "items", "gr_item spawned with unknown item %s", tostring( self:GetItemId() ) )
		self:Remove()
		return
	end
	local model = def.Model
	if not model or not util.IsValidModel( model ) then model = FALLBACK_MODEL end
	self:SetModel( model )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
	-- Items shouldn't block doors or be used to climb.
	self:SetCollisionGroup( COLLISION_GROUP_WEAPON )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:Wake() end
end

function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() then return end
	Inventory.PickUp( activator, self )
end
