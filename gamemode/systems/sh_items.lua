-- Item definitions: Items.Define( id, { ... } ) with the fields below, keyed by id so Items.Get
-- is one table lookup (P7). Definitions run in the same order on both realms, so an item's
-- index is the same everywhere and is what goes over the wire.
--
-- Use on the server: OnUse( ply, def ) runs first and returning false cancels the use; then
-- every Effects entry goes through Needs.Add; then one is consumed if Consumable is set.
Items = Items or {}

local list = {}  -- index -> item
local byId = {}  -- id -> item

-- Field -> allowed Lua type. Unlike fates, an unknown key is an error, so a typo can't hide.
local SCHEMA = {
	Name = "string",
	Description = "string",
	Weight = "number",      -- default 1
	Model = "string",       -- world model when dropped
	CarryAdd = "number",    -- raises the carry limit while carried (bags)
	Weapon = "string",      -- weapon class held while at least one is carried
	Effects = "table",      -- { needName = amount } applied on use; implies Consumable
	Consumable = "boolean", -- using it uses one up
	OnUse = "function",     -- ( ply, def ) -> false to cancel
	Tags = "table",         -- free-form flags for other systems: { Permit = true }
}
local REQUIRED = { "Name", "Description" }

local function validate( id, def )
	if not isstring( id ) or not string.match( id, "^[%w_]+$" ) then error( "item id must be a word, got " .. tostring( id ), 3 ) end
	for _, key in ipairs( REQUIRED ) do
		if def[ key ] == nil then error( "item " .. id .. ": missing required field " .. key, 3 ) end
	end
	for key, value in pairs( def ) do
		local want = SCHEMA[ key ]
		if not want then error( "item " .. id .. ": unknown field " .. tostring( key ), 3 ) end
		if type( value ) ~= want then
			error( string.format( "item %s: %s should be %s, not %s", id, key, want, type( value ) ), 3 )
		end
	end
	if def.Weight and def.Weight < 0 then error( "item " .. id .. ": Weight can't be negative", 3 ) end
	for name, amount in pairs( def.Effects or {} ) do
		if not Needs.Def( name ) then error( "item " .. id .. ": Effects names unknown need " .. tostring( name ), 3 ) end
		if not isnumber( amount ) then error( "item " .. id .. ": Effects." .. name .. " should be a number", 3 ) end
	end
end

function Items.Define( id, def )
	validate( id, def )
	def.Weight = def.Weight or 1
	def.CarryAdd = def.CarryAdd or 0
	if def.Effects then def.Consumable = true end

	local existing = byId[ id ]
	def.id = id
	def.index = existing and existing.index or #list + 1
	list[ def.index ] = def
	byId[ id ] = def
	return def
end

function Items.Get( id ) return byId[ id ] end
function Items.ByIndex( index ) return list[ index ] end
function Items.All() return list end

-- The starting set ------------------------------------------------------------------------
-- Weights are multiples of 0.5, which add up exactly in floating point, so the cached weight
-- never drifts.

-- Clean water only comes from the stockpile (step 9); the pump gives dirty water.
local DIRTY_WATER_POX_CHANCE = 0.25
Items.DIRTY_WATER_POX_CHANCE = DIRTY_WATER_POX_CHANCE

Items.Define( "ration", {
	Name = "Ration",
	Description = "A grey brick of state food. It fills you.",
	Weight = 1,
	Model = "models/props_junk/garbage_takeoutcarton001a.mdl",
	Effects = { Emptiness = -50 },
} )

Items.Define( "clean_water", {
	Name = "Clean Water",
	Description = "A sealed bottle from the stockpile.",
	Weight = 1,
	Model = "models/props_junk/glassbottle01a.mdl",
	Effects = { Dryness = -50 },
} )

-- Shop goods (step 9), with the original's models.
Items.Define( "fear_beer", {
	Name = "Fear Beer",
	Description = "A bottle of cheap beer. It isn't filling, but it takes the edge off.",
	Weight = 1,
	Model = "models/props_junk/garbage_glassbottle003a.mdl",
	Effects = { Dryness = -40, Despair = -15 },
} )

Items.Define( "spirits", {
	Name = "Spirits",
	Description = "A jug of strong liquor. It eases the sickness and the sadness, but it burns.",
	Weight = 1,
	Model = "models/props_junk/glassjug01.mdl",
	Effects = { Dryness = -25, Despair = -30, Pox = -30 },
	OnUse = function( ply ) ply:TakeDamage( 10 ) end,
} )

-- No knife weapon exists yet; for now it is a carried item with the original's world model.
Items.Define( "knife", {
	Name = "Knife",
	Description = "A short blade.",
	Weight = 1,
	Model = "models/weapons/w_knife_t.mdl",
} )

Items.Define( "dirty_water", {
	Name = "Dirty Water",
	Description = "Pumped from the ground. It quenches, a little. It might make you sick.",
	Weight = 1,
	Model = "models/props_junk/garbage_glassbottle001a.mdl",
	Effects = { Dryness = -25 },
	OnUse = function( ply )
		if math.random() < Items.DIRTY_WATER_POX_CHANCE then
			Needs.Add( ply, "Pox", 10, "dirty water" )
			Notify( ply, "The water tastes of rust and rot." )
		end
	end,
} )

Items.Define( "scrap", {
	Name = "Scrap",
	Description = "Twisted metal. Someone will want it.",
	Weight = 2,
	Model = "models/gibs/metal_gib4.mdl",
} )

Items.Define( "bandage", {
	Name = "Bandage",
	Description = "Dirty cloth that stops some of the bleeding.",
	Weight = 0.5,
	Model = "models/items/healthkit.mdl",
	Consumable = true,
	OnUse = function( ply )
		if ply:Health() >= ply:GetMaxHealth() then
			Notify( ply, "You are not bleeding." )
			return false
		end
		ply:SetHealth( math.min( ply:Health() + 15, ply:GetMaxHealth() ) )
	end,
} )

-- Used by korpsman surgery in step 11; carrying them does nothing yet.
Items.Define( "surgical_tools", {
	Name = "Surgical Tools",
	Description = "Saws, clamps and a needle. Not clean.",
	Weight = 2,
	Model = "models/props_lab/box01a.mdl",
} )

-- Weapons map to stock HL2 classes until the gamemode has its own.
Items.Define( "baton", {
	Name = "Baton",
	Description = "A heavy stick for keeping order.",
	Weight = 2,
	Model = "models/weapons/w_stunbaton.mdl",
	Weapon = "weapon_gr_baton",
} )

Items.Define( "pistol", {
	Name = "Pistol",
	Description = "A sidearm. Owning one without a permit is a crime.",
	Weight = 2,
	Model = "models/weapons/w_pistol.mdl",
	Weapon = "weapon_gr_pistol",
} )

local function showPermit( ply, def )
	for _, other in player.Iterator() do
		if other ~= ply and not other:IsGhost() and other:GetPos():DistToSqr( ply:GetPos() ) < 200 * 200 then
			Notify( other, ply:Nick() .. " shows you a " .. string.lower( def.Name ) .. "." )
		end
	end
	Notify( ply, "You hold up your " .. string.lower( def.Name ) .. "." )
end

Items.Define( "weapon_permit", {
	Name = "Weapon Permit",
	Description = "Stamped paper that makes carrying a gun legal.",
	Weight = 0,
	Model = "models/props_c17/paper01.mdl",
	Tags = { Permit = "weapon" },
	OnUse = showPermit,
} )

Items.Define( "trade_permit", {
	Name = "Trade Permit",
	Description = "Stamped paper that lets you sell to other citizens.",
	Weight = 0,
	Model = "models/props_c17/paper01.mdl",
	Tags = { Permit = "trade" },
	OnUse = showPermit,
} )

Items.Define( "sack", {
	Name = "Sack",
	Description = "A burlap sack. You can carry more with it.",
	Weight = 1,
	Model = "models/props_junk/cardboard_box003a.mdl",
	CarryAdd = 10,
} )
