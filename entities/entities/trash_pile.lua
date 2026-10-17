-- A trash pile (plan step 8), ported from the original's lootable.lua. Search it for 1-3 items at the
-- cost of Pox, maybe a parasite, maybe a cut hand; it then stays empty for 300 + 120-360 s.
AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Trash Pile"
ENT.Spawnable = false
ENT.PhysgunDisabled = true
ENT.m_tblToolsAllowed = {}
ENT.DoNotDuplicate = true

ENT.MODEL = "models/props_junk/garbage128_composite001a.mdl"
ENT.SOUNDS = {
	"physics/plastic/plastic_barrel_break1.wav", "physics/plastic/plastic_barrel_break2.wav",
	"physics/plastic/plastic_box_break1.wav", "physics/plastic/plastic_box_break2.wav",
	"physics/plaster/ceilingtile_break1.wav", "physics/plaster/ceilingtile_break2.wav",
	"physics/cardboard/cardboard_box_break1.wav", "physics/cardboard/cardboard_box_break2.wav",
	"physics/cardboard/cardboard_box_break3.wav",
}
ENT.ACTIONS = {
	"goes dumpster diving", "scrapes the trash", "digs for treasure", "sifts through the garbage",
	"looks for valuables", "scavenges, like a rat", "hunts for treasure", "makes a mess",
	"sticks both hands in the junk",
}
-- Weights out of 16. bone_capsule is an entity, the rest are items.
ENT.LOOT = { { "bone_capsule", 14 }, { "rotten_food", 1 }, { "clean_water", 1 } }
ENT.PARASITE_CHANCE = 1 / 6
ENT.CUT_CHANCE = 1 / 8

function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "NextLoot" )
	self:NetworkVar( "String", 0, "LootName" )
end

function ENT:KeyValue( k, v )
	if k == "model" then self.kvModel = v elseif k == "lootname" then self.kvName = v end
end

function ENT:Lootable() return CurTime() >= self:GetNextLoot() end

function ENT:CrossTexts( ply, ct )
	table.insert( ct, { text = self:GetLootName() } )
	local function small( c, t ) table.insert( c, { text = t, font = HUD.Font( "LabelSmall" ) } ) end
	if self:Lootable() then
		small( ct, "Use to dumpster dive.\nIt isn't healthy to do, and you'll probably catch something nasty." )
	else
		small( ct, "You must wait before there is more to take." )
	end
end

if CLIENT then return end

function ENT:Initialize()
	self:SetModel( self.kvModel or self.MODEL )
	self:SetLootName( self.kvName or "Garbage" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetUseType( SIMPLE_USE )
	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
end

function ENT:RollLoot()
	local r = math.random( 16 )
	for _, e in ipairs( self.LOOT ) do
		r = r - e[ 2 ]
		if r <= 0 then return e[ 1 ] end
	end
end

function ENT:Search( ply )
	if not self:Lootable() then
		FX.Send( ply, "frighten" )
		Chat.Tell( ply, Color( 200, 0, 0 ), "There is nothing." )
		return false
	end
	self:SetNextLoot( CurTime() + 300 + math.random( 120, 360 ) )
	ply:EmitSound( self.SOUNDS[ math.random( #self.SOUNDS ) ] )
	Chat.Area( ply, Color( 200, 100, 100 ), ply:Nick() .. " " .. self.ACTIONS[ math.random( #self.ACTIONS ) ] .. "." )

	local tr = ply:GetEyeTrace()
	local eye = ply:EyePos()
	local pos = tr.HitPos
	if pos:Distance( eye ) > 100 then pos = eye + ( pos - eye ):GetNormalized() * 100 end
	pos = pos + Vector( 0, 0, 4 )
	local items = {}
	for _ = 1, math.random( 3 ) do
		local id = self:RollLoot()
		if id == "bone_capsule" then
			local c = ents.Create( "bone_capsule" )
			if IsValid( c ) then c:SetPos( pos + VectorRand() * 4 ) c:Spawn() end
		else
			table.insert( items, id )
		end
	end
	if #items > 0 then Items.SpawnMany( items, pos, Angle() ) end

	Needs.Add( ply, "Pox", 2, "trash" )
	if math.random() < self.PARASITE_CHANCE then
		Medicine.SetParasites( ply, Medicine.Parasites( ply ) + 1 )
	end
	if math.random() < self.CUT_CHANCE then
		Chat.Area( ply, Color( 200, 0, 0 ), ply:Nick() .. " slices their hand open on something sharp!" )
		ply:TakeDamage( math.random( 10, 20 ), self, self )
	end
	return true
end

function ENT:Use( ply )
	if not IsValid( ply ) or not ply:IsPlayer() or not ply:Alive() or ply:IsGhost() then return end
	self:Search( ply )
end
