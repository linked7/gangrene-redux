-- Fate registry. A fate is data: fates/<id>.lua calls Fates.Define( id, { ... } ) with the fields
-- below. Code never compares fate ids or names; it asks ply:FateHas( "Police" ) and the like (D1).
--
-- Fates.CanTake is shared, so the HUD and the server give the same answer (R7).
-- Fates.Apply is the only way to change a player's fate (R1).
Fates = Fates or {}

local list = {}  -- index -> fate
local byId = {}  -- id -> fate

-- Field -> allowed Lua types. Name and Description are required; everything else is optional.
local SCHEMA = {
	Name = { "string" },
	Description = { "string" },
	Base = { "string" },           -- inherit every field not set here from this fate
	Cost = { "number" },           -- stem cells to take it
	MinRank = { "number" },
	ForNewPlayers = { "boolean" }, -- the only fates Foolish players may take, and only they
	Slots = { "number", "function" }, -- number, or function( population ) -> number; nil = unlimited
	DeathCooldown = { "number" },  -- seconds before this player may take it again after dying
	Health = { "number" },
	Armor = { "number" },
	SpeedMulti = { "number" },     -- scales Config.WalkSpeed and Config.RunSpeed
	Loadout = { "table" },         -- weapon classes
	Radio = { "table" },           -- radio channel names
	Appearance = { "table", "function" }, -- { model, skin, bodygroups = { name = value }, race = id }
	Names = { "table", "function" }, -- list of names, or function( ply ) -> name; nil = Steam name
	Color = { "table" },           -- for HUD and chat
	Faction = { "string" },        -- fates sharing a faction answer to each other (step 10)
	Authority = { "number" },      -- rank inside the faction; higher outranks lower
	OnEnter = { "function" },      -- ( ply, reason )
	OnLeave = { "function" },      -- ( ply, newFate )
}
local REQUIRED = { "Name", "Description" }

local function validate( id, def )
	for _, key in ipairs( REQUIRED ) do
		if def[ key ] == nil then error( "fate " .. id .. ": missing required field " .. key, 3 ) end
	end
	for key, value in pairs( def ) do
		local allowed = SCHEMA[ key ]
		-- Unlisted keys are capabilities (Police = true, CanSentence = true, CarryBonus = 5...).
		if allowed and not table.HasValue( allowed, type( value ) ) then
			error( string.format( "fate %s: %s should be %s, not %s", id, key, table.concat( allowed, " or " ), type( value ) ), 3 )
		end
	end
end

function Fates.Define( id, def )
	if def.Base then
		local base = byId[ def.Base ]
		if not base then error( "fate " .. id .. ": base " .. def.Base .. " must be defined first", 2 ) end
		for key, value in pairs( base ) do
			if def[ key ] == nil and key ~= "id" and key ~= "index" and key ~= "ForNewPlayers" then def[ key ] = value end
		end
	end
	validate( id, def )

	local existing = byId[ id ]
	def.id = id
	def.index = existing and existing.index or #list + 1
	list[ def.index ] = def
	byId[ id ] = def

	-- One cooldown field per fate, kept across resets, so a death timer survives respawning.
	State.Field( "Cooldown_" .. id, "Float", 0, State.OWNER, 0, { keep = true } )
	return def
end

function Fates.Get( id ) return byId[ id ] end
function Fates.ByIndex( index ) return list[ index ] end
function Fates.All() return list end

FATE_GHOST = 1
State.Field( "Fate", "UInt", 4, State.PUBLIC, FATE_GHOST, { keep = true } )
State.Field( "CharName", "String", 0, State.PUBLIC, "" )

local meta = FindMetaTable( "Player" )

-- In character, a player is called by their assigned name; SteamName() is the account name.
meta.SteamName = meta.SteamName or meta.Nick
function meta:Nick()
	local name = self:GetCharName()
	if name == "" then return self:SteamName() end
	return name
end
meta.Name = meta.Nick
meta.GetName = meta.Nick

function meta:GetFateDef() return list[ self:GetFate() ] end
function meta:IsGhost() return self:GetFate() == FATE_GHOST end

-- Reads a capability or setting from the player's fate: ply:FateHas( "Police" ).
function meta:FateHas( key )
	local f = list[ self:GetFate() ]
	return f ~= nil and f[ key ]
end

function Fates.SlotLimit( f )
	if f.Slots == nil then return math.huge end
	if isfunction( f.Slots ) then return f.Slots( player.GetCount() ) end
	return f.Slots
end

function Fates.Count( id )
	local index = byId[ id ].index
	local n = 0
	for _, p in player.Iterator() do
		if p:GetFate() == index then n = n + 1 end
	end
	return n
end

-- Returns ok, reason. Checks in order: state, rank, stem cells, slots, death cooldown.
function Fates.CanTake( ply, id )
	local f = byId[ id ]
	if not f or f.index == FATE_GHOST then return false, "There is no such purpose." end
	if not ply:IsGhost() then return false, "You already have a purpose in life." end

	local rank = ply:GetRank()
	if rank == RANK_FOOLISH and not f.ForNewPlayers then
		return false, "You are not yet trusted with this purpose. Prove yourself first."
	end
	if rank > RANK_FOOLISH and f.ForNewPlayers then
		return false, "You have been freed. This purpose is beneath you now."
	end
	if f.MinRank and rank < f.MinRank then return false, "Your rank is too low for this purpose." end

	if ply:GetStemCells() < ( f.Cost or 0 ) then
		return false, string.format( "This purpose costs %d stem cells.", f.Cost )
	end

	if Fates.Count( id ) >= Fates.SlotLimit( f ) then return false, "This purpose is already taken." end

	local wait = ply[ "GetCooldown_" .. id ]( ply ) - CurTime()
	if wait > 0 then
		return false, string.format( "You died in this purpose too recently. Wait %d seconds.", math.ceil( wait ) )
	end
	return true
end

if CLIENT then return end

local function callHook( f, name, ... )
	if not f[ name ] then return end
	local ok, err = xpcall( f[ name ], debug.traceback, ... )
	if not ok then Log.Error( "fates", "%s.%s: %s", f.id, name, err ) end
end

-- Speed = config x the fate's SpeedMulti x every factor in Fates.SpeedMods (needs weakness, a
-- carried crate). Nothing else sets speed: a system that slows players adds a mod and calls
-- Fates.ApplySpeed( ply ) when its factor changes.
Fates.SpeedMods = Fates.SpeedMods or {}

function Fates.ApplySpeed( ply, f )
	f = f or ply:GetFateDef()
	local speed = f and f.SpeedMulti or 1
	for _, mod in pairs( Fates.SpeedMods ) do speed = speed * ( mod( ply ) or 1 ) end
	ply:SetWalkSpeed( Config.WalkSpeed * speed )
	ply:SetRunSpeed( Config.RunSpeed * speed )
end

-- Physical setup shared by every fate; ghosts float, pass through everything and can't be hurt.
local function applyBody( ply, f, look )
	local ghost = f.index == FATE_GHOST
	ply:SetNoDraw( false )
	ply:Freeze( false )
	ply:SetMoveType( ghost and MOVETYPE_NOCLIP or MOVETYPE_WALK )
	ply:SetNotSolid( ghost )
	ply:SetNoTarget( ghost )
	ply:SetRenderMode( RENDERMODE_TRANSCOLOR )
	ply:SetColor( ghost and Color( 255, 255, 255, 60 ) or color_white )
	ply:SetMaxHealth( f.Health or 100 )
	ply:SetHealth( f.Health or 100 )
	ply:SetArmor( f.Armor or 0 )
	Fates.ApplySpeed( ply, f )

	look = look or f.Appearance
	if isfunction( look ) then look = look( ply ) end
	look = look or {}
	ply:SetModel( look.model or "models/player/group01/male_07.mdl" )
	ply:SetSkin( look.skin or 0 )
	for i = 0, ply:GetNumBodyGroups() - 1 do ply:SetBodygroup( i, 0 ) end
	for name, value in pairs( look.bodygroups or {} ) do
		local i = ply:FindBodygroupByName( name )
		if i >= 0 then ply:SetBodygroup( i, value ) end
	end
	local race = look.race and Races.Get( look.race )
	if look.race and not race then Log.Error( "fates", "%s: unknown race %s", f.id, look.race ) end
	ply:SetRace( race and race.index or 0 )
	ply:SetupHands()
end

local function pickName( ply, f )
	local names = f.Names
	if isfunction( names ) then return names( ply ) end
	if istable( names ) then return names[ math.random( #names ) ] end
	return ""
end

function GM:PlayerSetHandsModel( ply, hands )
	local race = ply:GetRaceDef()
	local info = race and race.Hands or player_manager.TranslatePlayerHands( player_manager.TranslateToPlayerModelName( ply:GetModel() ) )
	if not info then return end
	hands:SetModel( info.model )
	hands:SetSkin( info.skin or 0 )
	hands:SetBodyGroups( info.body or "0000000" )
end

-- Whether a fate entry continues the same life (a revive, or getting up from a wounded down):
-- needs, kit and inventory carry over instead of starting fresh.
function Fates.SameLife( reason ) return reason == "revive" or reason == "getup" end

-- Changes `ply`'s fate in one synchronous pass. opts.reason: "spawn", "pick", "revive", "getup", "admin".
-- opts.identity = { name, look } keeps a character's name and body (a revive) instead of rolling new ones.
function Fates.Apply( ply, id, opts )
	local f = byId[ id ] or list[ id ]
	if not f then error( "Fates.Apply: unknown fate " .. tostring( id ), 2 ) end
	local reason = opts and opts.reason or "pick"

	local old = ply:GetFateDef()
	if old then callHook( old, "OnLeave", ply, f ) end

	State.Reset( ply )
	ply:SetFate( f.index )
	local identity = opts and opts.identity
	ply:SetCharName( identity and identity.name or pickName( ply, f ) )
	applyBody( ply, f, identity and identity.look )

	ply:StripWeapons()
	for _, class in ipairs( f.Loadout or {} ) do ply:Give( class ) end

	-- Systems that set up per-life state (needs, inventory...) listen here.
	hook.Run( "GR_FateEnter", ply, f, reason )
	callHook( f, "OnEnter", ply, reason )
	Log.Debug( "fates", "%s -> %s (%s)", ply:Nick(), f.id, reason )
end

-- What a fate station does: check, charge, apply. Returns whether it worked.
function Fates.Take( ply, id )
	local ok, why = Fates.CanTake( ply, id )
	if not ok then
		Notify( ply, why )
		return false
	end
	local f = byId[ id ]
	if ( f.Cost or 0 ) > 0 then ply:SetStemCells( ply:GetStemCells() - f.Cost ) end
	Fates.Apply( ply, id, { reason = "pick" } )
	return true
end
