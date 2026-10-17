-- A campfire (step 13): three or more wood chunks left together fall into one. It starts unlit;
-- anything burning, or a lighter, lights it. The rules live in systems/sh_campfire.lua.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Campfire"
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar( "Bool", 0, "Lit" )
	self:NetworkVar( "Float", 0, "Fuel" ) -- seconds of burning stored while unlit
	self:NetworkVar( "Float", 1, "BurnEnd" ) -- CurTime() the fire goes out, while lit
end

-- Seconds of fire left, lit or not.
function ENT:FuelLeft()
	if self:GetLit() then return math.max( 0, self:GetBurnEnd() - CurTime() ) end
	return self:GetFuel()
end

if SERVER then
	function ENT:Initialize()
		self:SetModel( "models/props_debris/wood_chunk03a.mdl" )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_VPHYSICS )
		self:SetTrigger( true )
		Campfire.Track( self )
	end

	function ENT:StartTouch( other ) Campfire.Touched( self, other ) end
	function ENT:PhysicsCollide( data ) Campfire.Touched( self, data.HitEntity ) end

	function ENT:OnTakeDamage( dmg )
		if dmg:IsDamageType( DMG_BURN ) then Campfire.Light( self ) end
	end
end

if CLIENT then
	local function clock( s ) return string.format( "%d:%02d", math.floor( s / 60 ), math.floor( s % 60 ) ) end

	function ENT:CrossTexts( ply, ct )
		local left = self:FuelLeft()
		if self:GetLit() then
			table.insert( ct, { text = "Campfire (burning)" } )
			table.insert( ct, { text = clock( left ) .. " of wood left. Keep clear.", font = HUD.Font( "LabelSmall" ) } )
		elseif left <= 0 then
			table.insert( ct, { text = "Fire pit" } )
			table.insert( ct, { text = "Burnt out. Drop wood on it to build it up again.", font = HUD.Font( "LabelSmall" ) } )
		else
			table.insert( ct, { text = "Campfire (unlit)" } )
			table.insert( ct, { text = clock( left ) .. " of wood. Light it with a lighter or a flame.", font = HUD.Font( "LabelSmall" ) } )
		end
	end
end
