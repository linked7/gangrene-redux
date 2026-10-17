-- The Sanitar Summon, ported 1:1 from the original entities/summoner.lua (docs/03, Sanitar Summon).
-- Logic lives in systems/sh_summoner.lua; this is the body and the screen.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Sanitar Summon"
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar( "Bool", 0, "On" )
	self:NetworkVar( "Bool", 1, "Blink" )
	self:NetworkVar( "Int", 0, "NextToggle" )
	self:NetworkVar( "String", 0, "Area" )
end

function ENT:KeyValue( k, v )
	if k == "area" then self:SetArea( tostring( v ) ) end
end

function ENT:OnRemove()
	if Summoner then Summoner.All[ self ] = nil end
end

if CLIENT then
	function ENT:Initialize()
		if Summoner then Summoner.All[ self ] = true end
	end
end

if SERVER then
	function ENT:Initialize()
		if Summoner then Summoner.All[ self ] = true end
		self:SetModel( "models/props_combine/combine_smallmonitor001.mdl" )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_VPHYSICS )
		self:SetUseType( SIMPLE_USE )
		local phys = self:GetPhysicsObject()
		if IsValid( phys ) then phys:EnableMotion( false ) end
		if self:GetArea() == "" then self:SetArea( "Somewhere" ) end
		self.NextSound = 0
		self.AutoStop = CurTime() + 90
	end

	function ENT:Use( ply )
		if Summoner then Summoner.Use( self, ply ) end
	end

	function ENT:OnTakeDamage( dmg )
		if Summoner then Summoner.Damage( self, dmg ) end
	end

	function ENT:Think()
		if Summoner then Summoner.Think( self ) end
		self:NextThink( CurTime() + 0.5 )
		return true
	end
	return
end

local MAT_ON, MAT_OFF = Material( "effects/combinedisplay002b" ), Material( "effects/tvscreen_noise001a" )
local function rainbow( t ) return HSVToColor( ( t * 23 ) % 360, 1, 1 ) end

function ENT:Draw()
	self:DrawModel()
	local pos, ang = self:GetPos(), self:GetAngles()
	pos = pos + ang:Up() * 19 + ang:Forward() * 13 + ang:Right() * 7
	ang:RotateAroundAxis( ang:Up(), -90 )
	ang:RotateAroundAxis( ang:Forward(), 90 )
	ang:RotateAroundAxis( ang:Right(), -180 )
	local t = CurTime()
	cam.Start3D2D( pos, ang, 0.1 )
		if self:GetOn() then
			surface.SetMaterial( MAT_ON )
			surface.SetDrawColor( 128 + math.abs( math.sin( t ) ) * 127, 0, 0, 255 )
		else
			surface.SetMaterial( MAT_OFF )
			surface.SetDrawColor( 255, 255, 255, 255 )
		end
		surface.DrawTexturedRect( 0, 0, 164, 164 )
		draw.SimpleText( "Sanitar Summon", "Trebuchet24", 80, 16, rainbow( t ), TEXT_ALIGN_CENTER )
		if self:GetOn() then
			draw.SimpleText( "THEY'RE COMING", "Trebuchet24", 80, 40, HSVToColor( 0, 1, ( t % 60 ) / 60 ), TEXT_ALIGN_CENTER )
		elseif self:GetNextToggle() > t then
			draw.SimpleText( "Relaxing for " .. string.NiceTime( self:GetNextToggle() - t ) .. "...", "Trebuchet18", 80, 40, rainbow( t ), TEXT_ALIGN_CENTER )
		else
			draw.SimpleText( "Use to request help", "Trebuchet18", 80, 40, rainbow( t ), TEXT_ALIGN_CENTER )
		end
	cam.End3D2D()
end
