-- The train station: the Kaiser sends rations out and an import crate comes back (sh_export.lua).
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Train Station"
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar( "Bool", 0, "Away" )      -- the train is out
	self:NetworkVar( "Float", 0, "ReturnAt" ) -- CurTime it comes back
	self:NetworkVar( "String", 0, "Cargo" )   -- the import kind it brings
end

function ENT:Initialize()
	if CLIENT then return end
	self:SetModel( "models/props_trainstation/trainstation_clock001.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
	Export.Track( self )
end

if SERVER then return end

function ENT:CrossTexts( ply, ct )
	table.insert( ct, { text = "Train Station" } )
	local line
	if self:GetAway() then
		line = string.format( "The train is out for %s; back in %ds.", self:GetCargo(), math.max( 0, math.ceil( self:GetReturnAt() - CurTime() ) ) )
	else
		line = string.format( "The train is home. The Kaiser can export %d rations for tools or guns.", Econ.Setting( "export_rations" ) )
	end
	table.insert( ct, { text = line, font = HUD.Font( "LabelSmall" ) } )
end
