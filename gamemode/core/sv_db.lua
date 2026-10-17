-- SQLite persistence through GMod's built-in sql library (garrysmod/sv.db).
-- Writes are write-behind: DB.Set changes the cached row and marks it dirty, and DB.Flush
-- writes every dirty row in one transaction (every FLUSH_INTERVAL s, on disconnect, on shutdown).
-- Every value passes through sql.SQLStr, and column names come from a fixed whitelist (S4).
DB = DB or {}
DB.FLUSH_INTERVAL = 60

local Q = sql.SQLStr

-- Columns of `players` that game code may read and write, with their defaults.
local PLAYER_COLUMNS = {
	stem_cells = 0,
	rank = 0,
	bones = 0,
	playtime = 0,
}

local MIGRATIONS = {
	[ 1 ] = {
		[[CREATE TABLE IF NOT EXISTS players (
			steamid TEXT PRIMARY KEY,
			stem_cells INTEGER NOT NULL DEFAULT 0,
			rank INTEGER NOT NULL DEFAULT 0,
			bones INTEGER NOT NULL DEFAULT 0,
			playtime INTEGER NOT NULL DEFAULT 0,
			created INTEGER NOT NULL,
			last_seen INTEGER NOT NULL)]],
		[[CREATE TABLE IF NOT EXISTS bans (
			steamid TEXT PRIMARY KEY,
			until INTEGER NOT NULL,
			reason TEXT NOT NULL,
			by TEXT NOT NULL)]],
		[[CREATE TABLE IF NOT EXISTS world (
			key TEXT PRIMARY KEY,
			value TEXT NOT NULL)]],
	},
}

local rows = {}        -- key -> { fields..., dirty = { field = true } }
local worldCache = {}  -- key -> string value
local worldDirty = {}

function DB.Query( q )
	local res = sql.Query( q )
	if res == false then
		Log.Error( "db", "%s\n  in: %s", tostring( sql.LastError() ), q )
	end
	return res
end

local function migrate()
	DB.Query( "CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)" )
	local version = tonumber( sql.QueryValue( "SELECT version FROM schema_version" ) )
	if not version then
		DB.Query( "INSERT INTO schema_version (version) VALUES (0)" )
		version = 0
	end

	for v = version + 1, #MIGRATIONS do
		DB.Query( "BEGIN" )
		for _, stmt in ipairs( MIGRATIONS[ v ] ) do DB.Query( stmt ) end
		DB.Query( "UPDATE schema_version SET version = " .. v )
		DB.Query( "COMMIT" )
		Log.Info( "db", "schema migrated to v%d", v )
	end
end

-- Bots have no SteamID, so they are keyed by name; a bot that rejoins with the same name
-- gets its row back, which is what the persistence tests rely on.
function DB.Key( ply )
	if ply:IsBot() then return "bot:" .. ply:Nick() end
	return ply:SteamID64()
end

function DB.LoadPlayer( ply )
	local key = DB.Key( ply )
	local now = os.time()
	local row = sql.QueryRow( "SELECT * FROM players WHERE steamid = " .. Q( key ) )

	if not row then
		DB.Query( string.format( "INSERT INTO players (steamid, created, last_seen) VALUES (%s, %d, %d)", Q( key ), now, now ) )
		row = {}
	end

	local cached = { dirty = {}, joinedAt = now }
	for col, default in pairs( PLAYER_COLUMNS ) do
		cached[ col ] = tonumber( row[ col ] ) or default
	end
	rows[ key ] = cached
	ply.GR_DBKey = key

	hook.Run( "GR_PlayerLoaded", ply )
	return cached
end

function DB.Get( ply, col )
	local row = rows[ ply.GR_DBKey ]
	if not row then return PLAYER_COLUMNS[ col ] end
	return row[ col ]
end

function DB.Set( ply, col, value )
	if PLAYER_COLUMNS[ col ] == nil then error( "DB.Set: unknown column " .. tostring( col ), 2 ) end
	local row = rows[ ply.GR_DBKey ]
	if not row or row[ col ] == value then return end
	row[ col ] = value
	row.dirty[ col ] = true
end

function DB.GetWorld( key, default )
	if worldCache[ key ] == nil then
		worldCache[ key ] = sql.QueryValue( "SELECT value FROM world WHERE key = " .. Q( key ) ) or false
	end
	local v = worldCache[ key ]
	if v == false then return default end
	return v
end

function DB.SetWorld( key, value )
	value = tostring( value )
	if worldCache[ key ] == value then return end
	worldCache[ key ] = value
	worldDirty[ key ] = true
end

-- Adds the playtime since the last flush to every online player's row.
local function accruePlaytime( now )
	for _, ply in player.Iterator() do
		local row = rows[ ply.GR_DBKey ]
		if row then
			local secs = now - row.joinedAt
			if secs > 0 then
				row.playtime = row.playtime + secs
				row.joinedAt = now
				row.dirty.playtime = true
			end
		end
	end
end

local function rowUpdate( key, row, now )
	local sets = { "last_seen = " .. now }
	for col in pairs( row.dirty ) do
		table.insert( sets, col .. " = " .. Q( tostring( row[ col ] ) ) )
	end
	row.dirty = {}
	return "UPDATE players SET " .. table.concat( sets, ", " ) .. " WHERE steamid = " .. Q( key )
end

-- Writes one player's dirty columns now. Only for changes that must never be lost, such as
-- Rank.Free; everything else waits for DB.Flush.
function DB.FlushPlayer( ply )
	local row = rows[ ply.GR_DBKey ]
	if row and next( row.dirty ) then DB.Query( rowUpdate( ply.GR_DBKey, row, os.time() ) ) end
end

function DB.Flush()
	local now = os.time()
	local start = SysTime()
	accruePlaytime( now )

	local stmts = {}
	for key, row in pairs( rows ) do
		if next( row.dirty ) then table.insert( stmts, rowUpdate( key, row, now ) ) end
	end
	for key in pairs( worldDirty ) do
		table.insert( stmts, string.format( "INSERT OR REPLACE INTO world (key, value) VALUES (%s, %s)", Q( key ), Q( worldCache[ key ] ) ) )
	end
	worldDirty = {}
	if #stmts == 0 then return 0 end

	DB.Query( "BEGIN" )
	for _, s in ipairs( stmts ) do DB.Query( s ) end
	DB.Query( "COMMIT" )
	Log.Debug( "db", "flushed %d rows in %.2f ms", #stmts, ( SysTime() - start ) * 1000 )
	return #stmts
end

-- Bans --------------------------------------------------------------------------------------

-- seconds = 0 bans forever.
function DB.Ban( steamid, seconds, reason, by )
	local untilTime = seconds > 0 and os.time() + seconds or 0
	DB.Query( string.format( "INSERT OR REPLACE INTO bans (steamid, until, reason, by) VALUES (%s, %d, %s, %s)",
		Q( steamid ), untilTime, Q( reason ), Q( by ) ) )
end

function DB.Unban( steamid )
	DB.Query( "DELETE FROM bans WHERE steamid = " .. Q( steamid ) )
end

-- Returns the ban row if `steamid` is banned right now.
function DB.GetBan( steamid )
	return sql.QueryRow( string.format( "SELECT * FROM bans WHERE steamid = %s AND (until = 0 OR until > %d)", Q( steamid ), os.time() ) )
end

-- Hooks -------------------------------------------------------------------------------------

hook.Add( "Initialize", "gr_db", migrate )

hook.Add( "CheckPassword", "gr_db_bans", function( steamid64 )
	local ban = DB.GetBan( steamid64 )
	if ban then return false, "Banned: " .. ban.reason end
end )

hook.Add( "PlayerInitialSpawn", "gr_db", function( ply )
	DB.LoadPlayer( ply )
end )

hook.Add( "PlayerDisconnected", "gr_db", function( ply )
	DB.Flush()
	rows[ ply.GR_DBKey or "" ] = nil
end )

hook.Add( "ShutDown", "gr_db", DB.Flush )

Sched.Every( "db_flush", DB.FLUSH_INTERVAL, DB.Flush )
