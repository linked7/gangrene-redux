-- A brew barrel (step 11): the original's "Booze Bucket" (brew.lua), finished without a timer.
-- A lever picks beer or spirits, a ration touching it is swallowed, 8 hits or shakes finish 3
-- bottles into the stockpile. The rules are in systems/sh_brewing.lua.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Brew Barrel"
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "State" )
	self:NetworkVar( "Int", 1, "Brew" ) -- the lever: index into Brew.KINDS
	self:NetworkVar( "Int", 2, "Hits" )
	self:NetworkVar( "String", 0, "BuiltBy" )
end

if CLIENT then
	function ENT:CrossTexts( ply, ct )
		table.insert( ct, { text = "Booze Barrel" } )
		local small = HUD.Font( "LabelSmall" )
		local id = Brew.KINDS[ self:GetBrew() ]
		local name = id and Items.Get( id ) and Items.Get( id ).Name or ""
		table.insert( ct, { text = "Lever: " .. name, font = small } )
		if self:GetState() == Brew.BREWING then
			table.insert( ct, { text = "Fermenting", bar = math.Clamp( self:GetHits() / Brew.HITS, 0, 1 ) } )
			table.insert( ct, { text = "Hit it or shake it to finish the batch.", font = small } )
		else
			table.insert( ct, { text = "Pull the lever for beer or spirits.\nFeed it a ration, then hit or shake it.\n" .. Brew.YIELD .. " bottles go to the stockpile.", font = small } )
		end
	end

	function ENT:Draw()
		self:DrawModel()
		local lever = Brew.LeverPos( self )
		local beer = self:GetBrew() ~= 2
		local tip = lever + self:GetUp() * 6 + self:GetRight() * ( beer and -3 or 3 )
		render.SetColorMaterial()
		render.DrawBeam( lever, tip, 1, 0, 1, Color( 60, 60, 60 ) )
		render.DrawSphere( tip, 1.2, 8, 8, beer and Color( 200, 150, 40 ) or Color( 160, 200, 230 ) )
	end
	return
end

function ENT:Initialize()
	self:SetModel( "models/props_c17/oildrum001.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
	self:SetSkin( math.random( 0, 6 ) )
	self:SetBrew( 1 )
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
	Brew.Use( activator, self )
end

function ENT:OnTakeDamage( dmg )
	if dmg:IsDamageType( DMG_CLUB ) or dmg:IsDamageType( DMG_SLASH ) then Brew.Agitate( self ) end
end

function ENT:PhysicsCollide( data )
	local other = data.HitEntity
	if IsValid( other ) and other:GetClass() == "gr_item" then
		timer.Simple( 0, function() Brew.Feed( self, other ) end ) -- can't remove inside a physics callback
		return
	end
	Brew.Shake( self, data.Speed )
end
