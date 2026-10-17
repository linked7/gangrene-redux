-- Step 1, part a: rows, write-behind, disconnect flush, world table, bans.
-- Leaves bones = 456 flushed and 789 unflushed; step1b checks what survives the killed server.
local function stored( key, col )
	return tonumber( sql.QueryValue( "SELECT " .. col .. " FROM players WHERE steamid = " .. sql.SQLStr( key ) ) )
end

return function( T )
	T.Equal( tonumber( sql.QueryValue( "SELECT version FROM schema_version" ) ), 1, "schema version" )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t1_%'" )
	DB.Query( "DELETE FROM world WHERE key = 't1_treasury'" )

	local bot = player.CreateNextBot( "t1_a" )
	T.Equal( DB.Key( bot ), "bot:t1_a", "bot key" )
	T.Check( stored( "bot:t1_a", "created" ) ~= nil, "joining creates a row" )
	T.Equal( DB.Get( bot, "rank" ), 0, "new players start at rank 0 (Foolish)" )

	DB.Set( bot, "bones", 123 )
	T.Equal( DB.Get( bot, "bones" ), 123, "set changes the cache" )
	T.Equal( stored( "bot:t1_a", "bones" ), 0, "set does not write immediately" )

	bot:Kick( "test" )
	T.WaitUntil( function() return not IsValid( bot ) end, 5, "bot left" )
	T.Equal( stored( "bot:t1_a", "bones" ), 123, "disconnect flushes" )

	T.Wait( 0.5 )
	bot = player.CreateNextBot( "t1_a" )
	T.Equal( DB.Get( bot, "bones" ), 123, "rejoin keeps bones" )

	DB.Set( bot, "bones", 456 )
	DB.SetWorld( "t1_treasury", 50 )
	DB.Flush()
	T.Equal( stored( "bot:t1_a", "bones" ), 456, "flush writes dirty rows" )
	T.Equal( sql.QueryValue( "SELECT value FROM world WHERE key = 't1_treasury'" ), "50", "flush writes world keys" )

	DB.Set( bot, "rank", 1 )
	DB.FlushPlayer( bot )
	T.Equal( stored( "bot:t1_a", "rank" ), 1, "FlushPlayer writes now" )

	DB.Set( bot, "bones", 789 ) -- never flushed: the killed server should lose it

	local evil = "7656119' OR '1'='1"
	DB.Ban( "76561190000000001", 60, "test ban", "step1a" )
	T.Equal( hook.Run( "CheckPassword", "76561190000000001", "", "", "", "x" ), false, "banned id is refused" )
	T.Check( DB.GetBan( evil ) == nil, "quoted steamid matches nothing" )
	DB.Unban( "76561190000000001" )
	T.Check( DB.GetBan( "76561190000000001" ) == nil, "unban lifts the ban" )
	DB.Ban( "76561190000000002", -1, "expired", "step1a" )
	DB.Query( "UPDATE bans SET until = 1 WHERE steamid = '76561190000000002'" )
	T.Check( DB.GetBan( "76561190000000002" ) == nil, "expired ban is ignored" )
	DB.Unban( "76561190000000002" )
end
