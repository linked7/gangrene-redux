-- A brew barrel (step 11): the original's unfinished "Booze Bucket", finished. A prole seals a loaf
-- in it, it ferments, a prole opens it for bottles. Sealed, anyone can smash it or carry it off.
-- The rules are in systems/sh_brewing.lua.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Brew Barrel"
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "State" )
	self:NetworkVar( "Int", 1, "Brew" )
	self:NetworkVar( "Int", 2, "Integrity" )
	self:NetworkVar( "Float", 0, "FinishAt" )
	self:NetworkVar( "String", 0, "BuiltBy" )
end

if CLIENT then
	function ENT:CrossTexts( ply, ct )
		table.insert( ct, { text = "Brew Barrel" } )
		local small = HUD.Font( "LabelSmall" )
		local id = Brew.KINDS[ self:GetBrew() ]
		local name = id and Items.Get( id ) and Items.Get( id ).Name or ""
		local state = self:GetState()
		if state == Brew.BREWING then
			local left = math.max( 0, math.ceil( self:GetFinishAt() - CurTime() ) )
			table.insert( ct, { text = string.format( "Brewing %s: %d:%02d", name, math.floor( left / 60 ), left % 60 ), font = small } )
			table.insert( ct, { text = "Sealed", bar = math.Clamp( self:GetIntegrity() / Brew.INTEGRITY, 0, 1 ) } )
		elseif state == Brew.DONE then
			table.insert( ct, { text = name .. " is ready. A prole can open it.", font = small, color = Color( 200, 170, 90 ) } )
		else
			table.insert( ct, { text = "Empty. A prole can brew a loaf in it.", font = small } )
		end
	end
	return
end

function ENT:Initialize()
	self:SetModel( "models/props_c17/oildrum001.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then
		phys:SetMass( 40 )
		phys:Wake()
	end
	if self.GR_BuiltBy then self:SetBuiltBy( self.GR_BuiltBy ) end
	Brew.Track( self )
end

function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() or not activator:Alive() or activator:IsGhost() then return end
	if self:IsPlayerHolding() then return end
	activator:PickupObject( self )
end

function ENT:OnTakeDamage( dmg )
	if self:GetState() ~= Brew.BREWING or self.GR_Smashed then return end
	self:SetIntegrity( math.max( 0, self:GetIntegrity() - math.ceil( dmg:GetDamage() ) ) )
	self:EmitSound( "physics/wood/wood_box_impact_bullet" .. math.random( 1, 4 ) .. ".wav" )
	if self:GetIntegrity() <= 0 then
		self.GR_Smashed = true
		Brew.Smash( self )
	end
end
