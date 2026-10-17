-- A munitionizer, the original's munitionizer.lua: proles build it (Build), anyone holding a gun buys
-- a clip from it. The rules are in systems/sh_munitionizer.lua; its screen is drawn on the pump in
-- 3D2D, as in the original. GR_BuiltBy / GetBuiltBy() is the builder's DB.Key; Deployer the builder.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Munitionizer"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.Model = "models/props_wasteland/gaspump001a.mdl"

function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "Kits" )
	self:NetworkVar( "Int", 1, "Integrity" )
	self:NetworkVar( "Entity", 0, "Deployer" )
	self:NetworkVar( "String", 0, "BuiltBy" )
end

if CLIENT then
	local noise = Material( "effects/tvscreen_noise001a" )

	function ENT:Draw() self:DrawModel() end

	function ENT:DrawTranslucent()
		local ply = LocalPlayer()
		local pos = self:GetPos() + self:GetUp() * 58 + self:GetForward() * 10 + self:GetRight() * 14.8
		local ang = self:GetAngles()
		ang:RotateAroundAxis( ang:Up(), -90 )
		ang:RotateAroundAxis( ang:Forward(), 90 )
		ang:RotateAroundAxis( ang:Right(), -180 )
		local hue = HSVToColor( ( CurTime() * 23 ) % 360, 1, 1 )
		cam.Start3D2D( pos, ang, 0.1 )
			surface.SetMaterial( noise )
			surface.SetDrawColor( 255, 255, 255, 255 )
			surface.DrawTexturedRect( 0, 0, 296, 236 )
			draw.SimpleText( HUD.Stutter( "Munitionizer" ), "CloseCaption_Bold", 144, 60, hue, TEXT_ALIGN_CENTER )

			local wep = ply:GetActiveWeapon()
			local text = ""
			if not IsValid( wep ) or not wep.Firearm or not wep.Primary or wep.Primary.ClipSize <= 0 then
				text = HUD.Stutter( "Equip a firearm" )
			else
				local clips = ply:GetAmmoCount( wep.Primary.Ammo ) / wep.Primary.ClipSize
				if clips >= 3 then
					text = HUD.Stutter( "You're fully loaded" )
				else
					text = HUD.Stutter( Munitionizer.Price( ply, self ) .. " Bones for a full reload (up to " .. math.ceil( 3 - clips ) .. ")" )
				end
			end
			draw.SimpleText( text, "Trebuchet18", 144, 95, hue, TEXT_ALIGN_CENTER )
			draw.SimpleText( HUD.Stutter( "You have " .. ply:GetBones() .. " Bones" ), "Trebuchet18", 144, 120,
				HSVToColor( ( CurTime() * 66 ) % 360, 1, 1 ), TEXT_ALIGN_CENTER )

			surface.SetDrawColor( 0, 0, 0, 255 )
			surface.DrawRect( 20, 150, 254, 36 )
			surface.SetDrawColor( 150 + 100 * math.sin( CurTime() ), 0, 0, 255 )
			surface.DrawRect( 22, 152, 248 * ( self:GetKits() / Munitionizer.MAX_KITS ), 32 )
		cam.End3D2D()
	end
	return
end

function ENT:Initialize()
	self:SetModel( self.Model )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:Wake() end
	self:SetKits( 0 )
	self:SetIntegrity( Munitionizer.INTEGRITY )
	if self.GR_BuiltBy then self:SetBuiltBy( self.GR_BuiltBy ) end
	if IsValid( self.GR_Deployer ) then self:SetDeployer( self.GR_Deployer ) end
	Munitionizer.Track( self )
end

function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() then return end
	Munitionizer.Use( activator, self )
end

function ENT:OnTakeDamage( dmg )
	self:TakePhysicsDamage( dmg )
	Munitionizer.Damaged( self, dmg )
end
