-- Step 14a: the net audit and admin basics. Every server receiver goes through Net.Receive with a
-- rate; payload checks the audit added (string caps, finite vectors, no self-grant); staff kick,
-- ban (refused at connect), unban, set rank, set fate and noclip, with Admin.IsStaff stubbed
-- because bots are never admins.
return function( T )
	Config.FateCosts = true -- these checks cover the stem-cell cost, which is off in play for now
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t14a_%'" )
	DB.Query( "DELETE FROM bans WHERE steamid LIKE 'bot:t14a_%' OR steamid = '76561190000014001'" )

	-- Net registry ------------------------------------------------------------------------------

	local n = 0
	for name, r in pairs( Net.Receivers ) do
		n = n + 1
		T.Check( net.Receivers[ string.lower( name ) ] ~= nil, "receiver " .. name .. " is listening" )
		T.Check( isnumber( r.rate ) and r.rate > 0, "receiver " .. name .. " has a rate" )
		T.Check( Net.Pools[ name ] == true and util.NetworkStringToID( name ) ~= 0, "receiver " .. name .. " is pooled" )
	end
	T.Check( Net.Receivers.properties and Net.Receivers.editvariable, "GMod's own receivers are adopted behind the rate limit" )
	T.Check( n >= 15, "every receiver is registered: " .. n )

	local known = {}
	for name in pairs( Net.Receivers ) do known[ string.lower( name ) ] = true end
	for name in pairs( net.Receivers ) do
		T.Check( known[ name ], "net.Receivers[" .. name .. "] came through Net.Receive" )
	end
	for name in pairs( Net.Pools ) do
		T.Check( util.NetworkStringToID( name ) ~= 0, "pool " .. name .. " is a network string" )
	end

	T.Check( not Net.Finite( Vector( 0 / 0, 0, 0 ) ) and not Net.Finite( math.huge ) and not Net.Finite( "1" ), "NaN, inf and strings aren't finite" )
	T.Check( Net.Finite( Vector( 1, 2, 3 ) ) and Net.Finite( -5 ), "ordinary numbers are" )

	-- Bots and the staff stub ---------------------------------------------------------------------

	local function bot( name )
		local b = player.CreateNextBot( "t14a_" .. name )
		b:SetRank( RANK_FRIEND )
		return b
	end
	local staff, user, victim = bot( "staff" ), bot( "user" ), bot( "victim" )
	T.Wait( 0.3 )

	T.Check( Admin.IsStaff( nil ) and Admin.IsStaff( NULL ), "the server console is staff" )
	T.Check( not Admin.IsStaff( staff ), "a bot isn't staff" )
	local realStaff = Admin.IsStaff
	Admin.IsStaff = function( p ) return not IsValid( p ) or p == staff end

	T.Equal( Admin.Find( "t14a_vic" ), victim, "Find takes a unique partial name" )
	T.Equal( Admin.Find( "bot:t14a_user" ), user, "and a DB key" )
	T.Check( Admin.Find( "t14a_" ) == nil, "an ambiguous name finds nobody" )

	-- Set fate, bypassing cost, rank, slots ----------------------------------------------------

	victim:SetStemCells( 0 )
	T.Check( not ( Fates.CanTake( victim, "kaiser" ) ), "the victim couldn't take the kaiser fate themselves" )
	T.Check( not Admin.SetFate( user, victim, "kaiser" ), "a non-staff player can't set fates" )
	T.Check( Admin.SetFate( staff, victim, "kaiser" ), "staff sets the victim's fate" )
	T.Equal( victim:GetFateDef().id, "kaiser", "the victim is the kaiser" )
	T.Equal( victim:GetStemCells(), 0, "no stem cells spent" )
	T.Check( Admin.SetFate( staff, user, "kaiser" ), "a second kaiser past the slot limit" )
	T.Check( not Admin.SetFate( staff, user, "nonsense" ), "an unknown fate is refused" )
	T.Check( Admin.SetFate( nil, user, "prole" ), "the console sets fates too" )

	-- Audit fixes: the Kaiser can't grant to themselves; a non-finite build spot is refused.
	local before, userBefore = victim:GetBones(), user:GetBones()
	T.Check( not Econ.Grant( victim, victim, 10 ), "the kaiser can't grant to themselves" )
	T.Equal( victim:GetBones(), before, "and gets nothing" )
	T.Check( Econ.Grant( victim, user, 10 ), "but can grant to a living player" )
	T.Equal( user:GetBones(), userBefore + 10, "who gets it" )

	Inventory.Add( user, "permit_tool", 1, true )
	userBefore = user:GetBones()
	T.Check( not Build.Place( user, "storage_crate", Vector( 0 / 0, 0 / 0, 0 / 0 ) ), "a NaN build spot is refused" )
	T.Equal( user:GetBones(), userBefore, "and costs nothing" )
	T.Equal( ( Econ.Audit() ), 0, "the economy holds" )

	T.Check( not GAMEMODE:CanProperty( user, "remover", user ), "context-menu properties stay off" )

	-- Noclip ------------------------------------------------------------------------------------

	T.Check( GAMEMODE:PlayerNoClip( staff, true ) == false, "a ghost can't toggle noclip, even staff" )
	Admin.SetFate( staff, staff, "prole" )
	T.Check( GAMEMODE:PlayerNoClip( staff, true ) == true, "living staff may noclip" )
	T.Check( GAMEMODE:PlayerNoClip( user, true ) == false, "others may not" )

	-- Set rank ----------------------------------------------------------------------------------

	T.Check( not Admin.SetRank( user, victim, RANK_KAPITAN ), "a non-staff player can't set ranks" )
	T.Check( Admin.SetRank( staff, victim, RANK_KAPITAN ), "staff sets a rank" )
	T.Equal( victim:GetRank(), RANK_KAPITAN, "the rank changed" )
	local row = sql.QueryRow( "SELECT rank FROM players WHERE steamid = 'bot:t14a_victim'" )
	T.Equal( row and tonumber( row.rank ), RANK_KAPITAN, "and is in the DB at once" )
	T.Check( not Admin.SetRank( staff, victim, 9 ), "rank 9 doesn't exist" )

	-- Chat aliases ------------------------------------------------------------------------------

	T.Equal( hook.Run( "PlayerSay", staff, "!setrank t14a_victim 1", false ), "", "!setrank is swallowed" )
	T.Equal( victim:GetRank(), RANK_FRIEND, "and sets the rank" )
	hook.Run( "PlayerSay", user, "!setrank t14a_victim 3", false )
	T.Equal( victim:GetRank(), RANK_FRIEND, "a non-staff !setrank does nothing" )
	hook.Run( "PlayerSay", staff, '!setfate "t14a_victim" ghost', false )
	T.Check( victim:IsGhost(), "!setfate with a quoted name" )
	T.Check( Admin.Command( nil, "setrank", { "t14a_victim", "2" } ) and victim:GetRank() == RANK_KAPITAN, "the console command path" )

	-- Ban ---------------------------------------------------------------------------------------

	local sid = "76561190000014001"
	T.Check( DB.CheckBan( sid ) == nil, "an unbanned steamid may connect" )
	T.Check( not Admin.Ban( user, sid, 60, "x" ), "a non-staff player can't ban" )
	T.Check( Admin.Ban( staff, sid, 60, "griefing" ), "staff bans an offline steamid for an hour" )
	local ban = sql.QueryRow( "SELECT * FROM bans WHERE steamid = '" .. sid .. "'" )
	T.Check( ban ~= nil and ban.reason == "griefing" and tonumber( ban[ "until" ] ) > os.time() + 3500, "the ban is in the DB" )
	local ok, msg = DB.CheckBan( sid )
	T.Check( ok == false and isstring( msg ) and string.find( msg, "griefing", 1, true ) ~= nil, "a banned steamid is refused at connect: " .. tostring( msg ) )
	ok = hook.Run( "CheckPassword", sid, "127.0.0.1", "", "", "x" )
	T.Equal( ok, false, "through the CheckPassword hook too" )
	T.Check( Admin.Unban( staff, sid ), "unban" )
	T.Check( DB.CheckBan( sid ) == nil, "and they may connect again" )
	T.Check( Admin.Ban( staff, "STEAM_0:1:7", 0, "forever" ) and DB.CheckBan( util.SteamIDTo64( "STEAM_0:1:7" ) ) == false, "a STEAM_ id is banned by its SteamID64" )
	Admin.Unban( nil, "STEAM_0:1:7" )
	T.Check( not Admin.Ban( staff, "not an id", 0, "x" ), "garbage isn't banned" )

	local banned = bot( "banned" )
	T.Wait( 0.3 )
	T.Check( Admin.Ban( staff, banned, 0, "test ban" ), "staff bans an online player" )
	T.WaitUntil( function() return not IsValid( banned ) end, 5, "the banned player is gone" )
	T.Check( DB.CheckBan( "bot:t14a_banned" ) == false, "and their key is refused" )
	Admin.Unban( staff, "bot:t14a_banned" )

	-- Kick --------------------------------------------------------------------------------------

	T.Check( not Admin.Kick( user, victim, "x" ), "a non-staff player can't kick" )
	T.Check( IsValid( victim ), "the victim is still here" )
	hook.Run( "PlayerSay", staff, "!kick t14a_victim being rude", false )
	T.WaitUntil( function() return not IsValid( victim ) end, 5, "!kick kicks" )

	Admin.IsStaff = realStaff
	T.Equal( ( Econ.Audit() ), 0, "the economy still holds" )
	DB.Query( "DELETE FROM bans WHERE steamid LIKE 'bot:t14a_%'" )
end
