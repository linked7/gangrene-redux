-- Race registry. A race is data in races/<id>.lua: Races.Define( id, { Name, Hands, ... } ).
-- A fate picks its race through Appearance.race. "No race shown" is race = nil (Race field 0).
-- Code uses the lore names (gangral, outsider, rottish, prohladian, skinless).
-- Races never change speech (user decision): there is no accent or speech hook here.
Races = Races or {}

local list, byId = {}, {}

local SCHEMA = {
	Name = { "string" },
	Nation = { "string" },  -- gangrene, rottingham, prohlada; nil for the stateless
	Hands = { "table" },    -- { model, skin, body } for the first-person hands
}

function Races.Define( id, def )
	if not def.Name then error( "race " .. id .. ": missing Name", 2 ) end
	for key, value in pairs( def ) do
		local allowed = SCHEMA[ key ]
		if not allowed then error( "race " .. id .. ": unknown field " .. key, 2 ) end
		if not table.HasValue( allowed, type( value ) ) then error( "race " .. id .. ": " .. key .. " has the wrong type", 2 ) end
	end
	local existing = byId[ id ]
	def.id = id
	def.index = existing and existing.index or #list + 1
	list[ def.index ] = def
	byId[ id ] = def
	return def
end

function Races.Get( id ) return byId[ id ] end
function Races.ByIndex( index ) return list[ index ] end

State.Field( "Race", "UInt", 4, State.PUBLIC, 0 )

FindMetaTable( "Player" ).GetRaceDef = function( ply )
	return list[ ply:GetRace() ]
end
