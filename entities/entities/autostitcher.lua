-- An autostitcher, the original's autostitcher.lua: a wall charger the map layout places. The rules
-- are in systems/sh_autostitcher.lua; its screen and the stitching beam are drawn here, as in the original.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Autostitcher"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.Model = "models/props_combine/health_charger001.mdl"

function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "Charges" )
	self:NetworkVar( "Entity", 0, "Patient" )
end

if CLIENT then
	local beam = Material( "cable/hydra" )

	function ENT:CrossTexts( ply, ct )
		if self:GetPatient() == ply then
			table.insert( ct, { text = "Ohh YES!..." } )
			table.insert( ct, { text = "You can give it " .. Autostitcher.PARASITE_PRICE .. " more Bones to remove parasites.", font = HUD.Font( "LabelSmall" ) } )
			return
		end
		table.insert( ct, { text = "Autosuture" } )
		table.insert( ct, { text = "Charge", bar = self:GetCharges() / Autostitcher.MAX_CHARGES } )
		if ply:FateHas( "Surgeon" ) then
			table.insert( ct, { text = "Using it with your Lovebox out will add a new charge\nbut hurt you a little in the process.", font = HUD.Font( "LabelSmall" ) } )
			table.insert( ct, { text = "...or, just smack it, if you don't have one.", font = HUD.Font( "LabelSmall" ) } )
		elseif self:GetCharges() <= 0 then
			table.insert( ct, { text = "This one is empty. You're screwed.\nYou can attempt to force a charge by abusing it with a blunt weapon.", font = HUD.Font( "LabelSmall" ) } )
		else
			table.insert( ct, { text = "For " .. Autostitcher.Price() .. " Bones this will heal you fully.\nFor "
				.. Autostitcher.PARASITE_PRICE .. " extra Bones each you can get parasites removed during the trip.", font = HUD.Font( "LabelSmall" ) } )
		end
	end

	function ENT:Draw() self:DrawModel() end

	function ENT:DrawTranslucent()
		local t = CurTime()
		local p = self:GetPatient()
		if IsValid( p ) then
			render.SetMaterial( beam )
			render.DrawBeam( p:EyePos() + p:GetForward() * 2 - p:GetUp() * 16,
				self:GetPos() + self:GetForward() * 6 + self:GetRight() * 2.4, 2 + math.cos( t ), 0, 1, color_white )
		end
		local ang = self:GetAngles()
		ang:RotateAroundAxis( ang:Forward(), 90 )
		ang:RotateAroundAxis( ang:Right(), -90 )
		cam.Start3D2D( self:GetPos() + self:GetUp() * 42 + self:GetRight() * 1, ang, 0.2 )
			draw.SimpleText( HUD.Stutter( "Autostitcher" ), "CloseCaption_Bold", 0, 60, HSVToColor( ( t * 23 ) % 360, 1, 1 ), TEXT_ALIGN_CENTER )
			if self:GetCharges() > 0 then
				draw.SimpleText( "CHARGES: " .. self:GetCharges(), "CloseCaption_Bold", 0, 80, HSVToColor( ( t * 38 ) % 360, 1, 1 ), TEXT_ALIGN_CENTER )
			else
				draw.SimpleText( "NO CHARGES", "CloseCaption_Bold", 0, 80, Color( 200 + 50 * math.sin( t ), 1, 1 ), TEXT_ALIGN_CENTER )
			end
		cam.End3D2D()
	end
	return
end

function ENT:Initialize()
	self:SetModel( self.Model )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetUseType( SIMPLE_USE )
	self:SetCharges( math.random( 0, 1 ) )
	Autostitcher.Track( self )
end

function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() then return end
	Autostitcher.Use( activator, self )
end

function ENT:OnTakeDamage( dmg )
	Autostitcher.Damaged( self, dmg )
end
