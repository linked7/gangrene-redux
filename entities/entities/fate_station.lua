-- A "purpose in life": a ghost uses it to take the fate named by its `fate` key value.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Purpose in Life"
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar( "String", 0, "FateId" )
end

function ENT:KeyValue( key, value )
	if key == "fate" then self:SetFateId( value ) end
end

if CLIENT then
	function ENT:Draw()
		-- Only the dead see purposes; the living walk past them.
		if LocalPlayer():IsGhost() then self:DrawModel() end
	end

	function ENT:Initialize() Fates.Stations[ self ] = true end
	function ENT:OnRemove() Fates.Stations[ self ] = nil end

	-- Ghost sight: purposes glow through walls, labelled and coloured by their fate.
	local function fateOf( ent )
		local f = Fates.Get( ent:GetFateId() )
		return f, ( f and f.Color ) or color_white
	end

	hook.Add( "PreDrawHalos", "GR_FateStationGhostSight", function()
		local lp = LocalPlayer()
		if not IsValid( lp ) or not lp:IsGhost() then return end
		for ent in pairs( Fates.Stations ) do if IsValid( ent ) then
			local _, col = fateOf( ent )
			halo.Add( { ent }, col, 2, 2, 1, true, true )
		end end
	end )

	hook.Add( "HUDPaint", "GR_FateStationGhostSight", function()
		local lp = LocalPlayer()
		if not IsValid( lp ) or not lp:IsGhost() then return end
		for ent in pairs( Fates.Stations ) do if IsValid( ent ) then
			local f, col = fateOf( ent )
			local scr = ( ent:GetPos() + Vector( 0, 0, 16 ) ):ToScreen()
			if scr.visible then
				draw.SimpleTextOutlined( f and f.Name or ent:GetFateId(), "DermaDefaultBold",
					scr.x, scr.y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, color_black )
			end
		end end
	end )
	return
end

function ENT:Initialize()
	-- The original's purpose in life: a sawblade with the Combine interface material (no hologram).
	self:SetModel( "models/props_junk/sawblade001a.mdl" )
	self:SetMaterial( "models/props_combine/masterinterface01c" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetUseType( SIMPLE_USE )
	self:SetCollisionGroup( COLLISION_GROUP_WORLD )
	Fates.Stations[ self ] = true
end

function ENT:OnRemove()
	Fates.Stations[ self ] = nil
end

function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() or not activator:IsGhost() then return end
	Fates.Take( activator, self:GetFateId() )
end
