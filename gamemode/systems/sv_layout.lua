-- The map layout (step 15a): where the world entities stand when the map doesn't place them.
-- No map ships state_stockpile, the lunch machine (lunch_machine, line_boiler), capsule_spawn
-- points, water_barrel, water_pump, sanitation_station or fate_station, so
-- the gamemode places them itself at Round.Start, before the economy resets.
--
--   Layout source, first found wins:
--     data/gangrene/layouts/<map>.json    the server's own, written by gr_layout_save
--     gamemode/layouts/<map>.lua          shipped with the gamemode: returns
--                                         { { class, pos = Vector, ang = Angle, kv = { fate = "prole" } }, ... }
--     a ring around the first info_player_start (Layout.Ring), with a warning in the log
--   If the map places any of these classes itself, nothing is spawned. A loaded layout is never
--   topped up from the default set: a class or fate it lacks (rp_slumtown ships without a stockpile,
--   a slave purpose, a sanitation station and water barrels) is only warned about, for staff to place and save.
--
--   Optional entry flags:
--     candidate = true   listed but not spawned: a spot staff may switch on (rp_slumtown's spare
--                        pump spots). gr_layout_list marks it; edit the json to enable it.
--     drop = true        pos is only near the floor (converted from another model's origin): the
--                        first spawn traces down to the floor and stands the model on it.
--
--   Layout.Spawn( [map] )            spawn every entry not already standing; returns the count spawned
--   Layout.Clear()                   remove what Layout spawned and forget the loaded layout
--   Layout.Entries() / Layout.Spawned( entry ) / Layout.MapPlaced()
--   Layout.Add( by, class, kv, [pos, ang] ), Layout.Remove( by, [ent] ), Layout.Save( by ), Layout.List( by )
--
-- Staff editor (Admin.IsStaff): gr_layout_add <class> [key=value ...] places it where the caller
-- looks, facing them; gr_layout_remove removes the looked-at one; gr_layout_save writes the json;
-- gr_layout_list prints the entries. Chat: !layout_add, !layout_remove, !layout_save, !layout_list.
Layout = Layout or {}

local root = GM.FolderName .. "/gamemode/layouts/"
local DATA_DIR = "gangrene/layouts"

Layout.RING_RADIUS = 300  -- the fallback ring's first radius around the spawn
Layout.RING_GAP = 120     -- minimum distance between two fallback placements

-- The world entities a layout may hold, and the key values each accepts (value -> ok).
Layout.CLASSES = {
	state_stockpile = {},
	water_pump = {},
	sanitation_station = {},
	-- The lunch machine (systems/sh_lunch.lua): it works with the nearest boiler.
	line_boiler = {},
	lunch_machine = {
		output = function( v ) return Lunch.OUTPUTS[ v ] ~= nil end,
	},
	water_barrel = {},
	capsule_spawn = {},
	stockpile_port = {}, -- stockpile ports (systems/sh_shop.lua)
	fate_station = {
		fate = function( v )
			local f = Fates.Get( v )
			return f ~= nil and f.index ~= FATE_GHOST
		end,
	},
}

-- Every entity of a layout class, map-placed or not; registered as it is created.
local present = Layout.present or setmetatable( {}, { __mode = "k" } )
Layout.present = present
for _, e in ents.Iterator() do
	if Layout.CLASSES[ e:GetClass() ] then present[ e ] = true end
end
hook.Add( "OnEntityCreated", "gr_layout", function( e )
	if IsValid( e ) and Layout.CLASSES[ e:GetClass() ] then present[ e ] = true end
end )

local entries          -- the loaded layout for Layout.map, or nil
local spawned = {}     -- entry -> entity

local function who( ply )
	return IsValid( ply ) and string.format( "%s (%s)", ply:SteamName(), DB.Key( ply ) ) or "console"
end

local function reply( ply, msg )
	if IsValid( ply ) then Notify( ply, msg ) else print( msg ) end
	return msg
end

local function round1( n ) return math.Round( n, 1 ) end

local function safeMap( map ) return string.gsub( string.lower( map ), "[^%w_%-]", "_" ) end

function Layout.DataPath( map ) return DATA_DIR .. "/" .. safeMap( map or Layout.map or game.GetMap() ) .. ".json" end

function Layout.Entries() return entries end
function Layout.Spawned( entry ) return spawned[ entry ] end

-- True when the map itself placed at least one layout class.
function Layout.MapPlaced()
	for e in pairs( present ) do
		if IsValid( e ) and e:CreatedByMap() then return true end
	end
	return false
end

-- Checks one entry; returns a clean copy or nil, why.
local function clean( raw )
	if not istable( raw ) then return nil, "not a table" end
	local keys = Layout.CLASSES[ raw.class ]
	if not keys then return nil, "unknown class " .. tostring( raw.class ) end
	local pos, ang = raw.pos, raw.ang or Angle( 0, 0, 0 )
	if istable( pos ) then pos = Vector( tonumber( pos[ 1 ] ) or 0, tonumber( pos[ 2 ] ) or 0, tonumber( pos[ 3 ] ) or 0 ) end
	if istable( ang ) then ang = Angle( tonumber( ang[ 1 ] ) or 0, tonumber( ang[ 2 ] ) or 0, tonumber( ang[ 3 ] ) or 0 ) end
	if not isvector( pos ) or not Net.Finite( pos ) then return nil, "bad position" end
	if not isangle( ang ) then return nil, "bad angle" end
	local kv = {}
	for k, v in pairs( raw.kv or {} ) do
		k, v = tostring( k ), tostring( v )
		if not keys[ k ] or not keys[ k ]( v ) then return nil, string.format( "bad key value %s=%s for %s", k, v, raw.class ) end
		kv[ k ] = v
	end
	return { class = raw.class, pos = pos, ang = ang, kv = kv,
		candidate = raw.candidate == true or nil, drop = raw.drop == true or nil }
end

local function cleanList( list, source )
	local out = {}
	for i, raw in ipairs( istable( list ) and list or {} ) do
		local e, why = clean( raw )
		if e then table.insert( out, e ) else Log.Warn( "layout", "%s entry %d skipped: %s", source, i, why ) end
	end
	return out
end

-- The default set for a map with no layout: one purpose per takeable fate, a stockpile, a
-- lunch machine and its boiler, three capsule spawn points, two water barrels, two pumps and a
-- sanitation station.
function Layout.DefaultSet()
	local set = {}
	for _, f in ipairs( Fates.All() ) do
		if f.index ~= FATE_GHOST then table.insert( set, { class = "fate_station", kv = { fate = f.id } } ) end
	end
	table.insert( set, { class = "state_stockpile", kv = {} } )
	for _, class in ipairs( { "lunch_machine", "line_boiler", "capsule_spawn", "capsule_spawn", "capsule_spawn", "water_barrel", "water_barrel" } ) do
		table.insert( set, { class = class, kv = {} } )
	end
	table.insert( set, { class = "water_pump", kv = {} } )
	table.insert( set, { class = "water_pump", kv = {} } )
	table.insert( set, { class = "sanitation_station", kv = {} } )
	return set
end

-- Player spawn classes the fallback ring keeps clear of.
local SPAWNS = { info_player_start = true, info_player_deathmatch = true, info_player_combine = true,
	info_player_rebel = true, info_player_counterterrorist = true, info_player_terrorist = true }

-- The floor under `pos`, or nil when there is none within reach.
function Layout.Floor( pos )
	local tr = util.TraceLine( { start = pos + Vector( 0, 0, 48 ), endpos = pos - Vector( 0, 0, 1024 ), mask = MASK_SOLID_BRUSHONLY } )
	if tr.StartSolid or not tr.Hit then return nil end
	return tr.HitPos
end

-- A free floor spot within sight of `center`, at least RING_GAP from every spot in `taken`.
local function freeSpot( center, taken )
	for r = Layout.RING_RADIUS, Layout.RING_RADIUS + 1500, 150 do
		local steps = math.max( 8, math.floor( 2 * math.pi * r / Layout.RING_GAP ) )
		for k = 0, steps - 1 do
			local a = math.rad( k / steps * 360 )
			local floor = Layout.Floor( center + Vector( math.cos( a ) * r, math.sin( a ) * r, 0 ) )
			local ok = floor and math.abs( floor.z - center.z ) < 64
			for _, t in ipairs( ok and taken or {} ) do
				if t:Distance( floor ) < Layout.RING_GAP then ok = false break end
			end
			if ok then
				local sight = util.TraceLine( { start = center + Vector( 0, 0, 40 ), endpos = floor + Vector( 0, 0, 40 ), mask = MASK_SOLID_BRUSHONLY } )
				local hull = util.TraceHull( { start = floor + Vector( 0, 0, 4 ), endpos = floor + Vector( 0, 0, 4 ),
					mins = Vector( -40, -40, 0 ), maxs = Vector( 40, 40, 80 ), mask = MASK_SOLID } )
				if not sight.Hit and not hull.Hit then return floor end
			end
		end
	end
end

-- The default set in rings around `center`, each facing it and clear of every player spawn.
-- Positions are floor points (onFloor).
function Layout.Ring( center, set )
	local out, taken = {}, {}
	for _, e in ents.Iterator() do
		if SPAWNS[ e:GetClass() ] then table.insert( taken, e:GetPos() ) end
	end
	for _, item in ipairs( set or Layout.DefaultSet() ) do
		local floor = freeSpot( center, taken )
		if not floor then
			Log.Warn( "layout", "no room left for %s around %s", item.class, tostring( center ) )
		else
			table.insert( taken, floor )
			table.insert( out, { class = item.class, pos = floor, ang = Angle( 0, ( center - floor ):Angle().y, 0 ),
				kv = table.Copy( item.kv or {} ), onFloor = true } )
		end
	end
	return out
end

local function firstSpawn()
	for _, e in ents.Iterator() do
		if e:GetClass() == "info_player_start" then return e:GetPos() end
	end
end

-- Reads the layout for `map`: the server's json, then the shipped Lua file, then nil.
function Layout.Load( map )
	local path = Layout.DataPath( map )
	if file.Exists( path, "DATA" ) then
		local list = util.JSONToTable( file.Read( path, "DATA" ) or "" )
		if istable( list ) then return cleanList( list, path ), path end
		Log.Warn( "layout", "%s is not valid json; ignoring it", path )
	end
	local lua = root .. safeMap( map ) .. ".lua"
	if file.Exists( lua, "LUA" ) then
		local ok, list = pcall( include, lua )
		if ok and istable( list ) then return cleanList( list, lua ), lua end
		Log.Warn( "layout", "%s did not return a list; ignoring it", lua )
	end
end

local function spawnEntry( entry )
	if entry.drop then
		local floor = Layout.Floor( entry.pos )
		if floor then
			entry.pos, entry.onFloor = floor, true
		else
			Log.Warn( "layout", "no floor under %s at %s; placing it as given", entry.class, tostring( entry.pos ) )
		end
		entry.drop = nil
	end
	local ent = ents.Create( entry.class )
	if not IsValid( ent ) then return nil end
	ent:SetPos( entry.pos )
	ent:SetAngles( entry.ang )
	for k, v in pairs( entry.kv ) do ent:SetKeyValue( k, v ) end
	ent:Spawn()
	ent:Activate()
	if entry.onFloor then
		-- Stand the model on the floor point, then remember where it ended up.
		ent:SetPos( entry.pos - Vector( 0, 0, ent:OBBMins().z ) )
		local p = ent:GetPos()
		entry.pos = Vector( round1( p.x ), round1( p.y ), round1( p.z ) )
		entry.onFloor = nil
	end
	ent.GR_Layout = entry
	spawned[ entry ] = ent
	return ent
end

-- Logs what a loaded layout lacks against the default set (classes, and a purpose per fate).
-- Nothing is placed for it: staff add it with gr_layout_add and keep it with gr_layout_save.
function Layout.WarnMissing( list, map )
	local have = {}
	for _, e in ipairs( list ) do
		if not e.candidate then have[ e.class .. ( e.kv.fate and ( ":" .. e.kv.fate ) or "" ) ] = true end
	end
	local missing = {}
	for _, item in ipairs( Layout.DefaultSet() ) do
		local key = item.class .. ( item.kv.fate and ( ":" .. item.kv.fate ) or "" )
		if not have[ key ] and not table.HasValue( missing, key ) then table.insert( missing, key ) end
	end
	if #missing > 0 then
		Log.Warn( "layout", "%s's layout has no %s. Staff: gr_layout_add <class> [fate=<id>], then gr_layout_save",
			map, table.concat( missing, ", " ) )
	end
	return missing
end

function Layout.Spawn( map )
	map = map or game.GetMap()
	if Layout.MapPlaced() then
		Log.Info( "layout", "%s places its own world entities; no layout spawned", map )
		return 0
	end
	if map ~= Layout.map or not entries then
		Layout.Clear()
		Layout.map = map
		local source
		entries, source = Layout.Load( map )
		if entries then
			Log.Info( "layout", "%s: %d entries from %s", map, #entries, source )
			Layout.WarnMissing( entries, map )
		else
			local center = firstSpawn()
			entries = center and Layout.Ring( center ) or {}
			Log.Warn( "layout", "%s has no layout: placed %d defaults around the spawn. Staff can fix it with gr_layout_add/remove/save", map, #entries )
		end
	end
	local n = 0
	for _, entry in ipairs( entries ) do
		if not entry.candidate and not IsValid( spawned[ entry ] ) and spawnEntry( entry ) then n = n + 1 end
	end
	if n > 0 then Log.Info( "layout", "spawned %d of %d layout entities", n, #entries ) end
	return n
end

function Layout.Clear()
	for _, ent in pairs( spawned ) do
		if IsValid( ent ) then ent:Remove() end
	end
	spawned, entries, Layout.map = {}, nil, nil
end

-- Editor ------------------------------------------------------------------------------------

local function refuse( by, why ) reply( by, why ) return false, why end

-- `kv` is { key = value } or a list of "key=value" words.
local function parseKV( list )
	local kv = {}
	for k, v in pairs( list or {} ) do
		if isnumber( k ) then
			local a, b = string.match( tostring( v ), "^([%w_]+)=(.+)$" )
			if a then kv[ a ] = b end
		else
			kv[ k ] = v
		end
	end
	return kv
end

-- Places `class` at `pos` (a floor point) facing `ang`, or where `by` looks, facing them.
function Layout.Add( by, class, kv, pos, ang )
	if not Admin.IsStaff( by ) then return refuse( by, "You are not staff." ) end
	if not entries then return refuse( by, "No layout is loaded." ) end
	if not pos then
		if not IsValid( by ) then return refuse( by, "The console has no eyes: stand where it goes." ) end
		local tr = by:GetEyeTrace()
		if not tr.Hit or tr.HitSky then return refuse( by, "Look at the floor where it goes." ) end
		pos = tr.HitPos
		ang = Angle( 0, ( by:GetPos() - pos ):Angle().y, 0 )
	end
	local entry, why = clean( { class = class, pos = pos, ang = ang or Angle( 0, 0, 0 ), kv = parseKV( kv ) } )
	if not entry then return refuse( by, "Can't add that: " .. why ) end
	if entry.class == "fate_station" and not entry.kv.fate then return refuse( by, "A fate_station needs fate=<id>." ) end
	entry.onFloor = true
	local ent = spawnEntry( entry )
	if not ent then return refuse( by, "Couldn't create " .. entry.class ) end
	table.insert( entries, entry )
	Log.Info( "layout", "%s added %s at %s on %s", who( by ), entry.class, tostring( entry.pos ), Layout.map )
	reply( by, string.format( "Added %s (#%d). gr_layout_save to keep it.", entry.class, #entries ) )
	return true, ent
end

-- Removes the layout entity `ent` (default: the one `by` looks at).
function Layout.Remove( by, ent )
	if not Admin.IsStaff( by ) then return refuse( by, "You are not staff." ) end
	if ent == nil and IsValid( by ) then ent = by:GetEyeTrace().Entity end
	local entry = IsValid( ent ) and ent.GR_Layout
	if not entry or not entries or not table.HasValue( entries, entry ) then return refuse( by, "That isn't part of the layout." ) end
	table.RemoveByValue( entries, entry )
	spawned[ entry ] = nil
	ent:Remove()
	Log.Info( "layout", "%s removed %s at %s on %s", who( by ), entry.class, tostring( entry.pos ), Layout.map )
	reply( by, "Removed " .. entry.class .. ". gr_layout_save to keep it." )
	return true
end

-- Writes the loaded layout to data/gangrene/layouts/<map>.json, which then wins over the shipped one.
function Layout.Save( by )
	if not Admin.IsStaff( by ) then return refuse( by, "You are not staff." ) end
	if not entries then return refuse( by, "No layout is loaded." ) end
	local out = {}
	for _, e in ipairs( entries ) do
		table.insert( out, { class = e.class, pos = { round1( e.pos.x ), round1( e.pos.y ), round1( e.pos.z ) },
			ang = { round1( e.ang.p ), round1( e.ang.y ), round1( e.ang.r ) }, kv = e.kv,
			candidate = e.candidate, drop = e.drop } )
	end
	file.CreateDir( DATA_DIR )
	local path = Layout.DataPath()
	file.Write( path, util.TableToJSON( out, true ) )
	Log.Info( "layout", "%s saved %d entries to %s", who( by ), #out, path )
	reply( by, string.format( "Saved %d entries to data/%s.", #out, path ) )
	return true, path
end

function Layout.List( by )
	if not Admin.IsStaff( by ) then return refuse( by, "You are not staff." ) end
	local lines = {}
	for i, e in ipairs( entries or {} ) do
		local kv = {}
		for k, v in pairs( e.kv ) do table.insert( kv, k .. "=" .. v ) end
		table.insert( lines, string.format( "%d. %s %s %s%s", i, e.class, tostring( e.pos ), table.concat( kv, " " ),
			e.candidate and " (candidate, not spawned)" or "" ) )
	end
	local msg = string.format( "%s: %d entries. %s", Layout.map or game.GetMap(), #lines, table.concat( lines, "; " ) )
	if IsValid( by ) then by:PrintMessage( HUD_PRINTCONSOLE, msg ) end
	reply( by, msg )
	return true, lines
end

local COMMANDS = {
	layout_add = function( by, args )
		if not args[ 1 ] then return refuse( by, "usage: gr_layout_add <class> [key=value ...]" ) end
		return Layout.Add( by, args[ 1 ], { unpack( args, 2 ) } )
	end,
	layout_remove = function( by ) return Layout.Remove( by ) end,
	layout_save = function( by ) return Layout.Save( by ) end,
	layout_list = function( by ) return Layout.List( by ) end,
}

for name, fn in pairs( COMMANDS ) do
	concommand.Add( "gr_" .. name, function( ply, _, args ) fn( ply, args ) end )
end

hook.Add( "PlayerSay", "gr_layout", function( ply, text )
	local name, rest = string.match( string.Trim( text ), "^[!/]([%a_]+)%s*(.*)$" )
	local fn = name and COMMANDS[ string.lower( name ) ]
	if not fn then return end
	fn( ply, Admin.Split( rest ) )
	return ""
end )
