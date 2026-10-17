-- Admin basics for staff (step 14). Staff are GMod usergroups (ply:IsAdmin(), which superadmins
-- pass too) or the server console; game ranks (sh_rank.lua) have nothing to do with it.
--
--   Admin.IsStaff( ply )                     the one check; nil/NULL is the console. Tests override it.
--   Admin.Find( text ) -> ply | nil, why     SteamID64, SteamID, DB key, exact or unique partial name
--   Admin.Kick( by, ply, reason )
--   Admin.Ban( by, ply | steamid, minutes, reason )   minutes 0 = forever; bans table in sv_db.lua,
--                                                     refused at connect by DB.CheckBan (CheckPassword)
--   Admin.Unban( by, steamid )
--   Admin.SetRank( by, ply, rank )           written to the DB at once
--   Admin.SetFate( by, ply, fateId )         no cost, slot, rank or cooldown checks
--   noclip                                   GM:PlayerNoClip: staff only, never ghosts (they float already)
--
-- Each returns true, or false and why, and every action is logged under "admin".
-- Console: gr_kick, gr_ban, gr_unban, gr_setrank, gr_setfate. Chat: !kick, !ban, !unban, !setrank, !setfate.
Admin = Admin or {}

Admin.MAX_BAN_MINUTES = 60 * 24 * 365 * 10

function Admin.IsStaff( ply )
	if not IsValid( ply ) then return true end
	return ply:IsAdmin() or ply:IsSuperAdmin()
end

local function who( ply )
	if not IsValid( ply ) then return "console" end
	return string.format( "%s (%s)", ply:SteamName(), DB.Key( ply ) )
end

local function reply( ply, msg )
	if IsValid( ply ) then Notify( ply, msg ) else print( msg ) end
end

local function refuse( by, why )
	reply( by, why )
	return false, why
end

local function act( by, fmt, ... )
	Log.Info( "admin", "%s " .. fmt, who( by ), ... )
	return true
end

-- A SteamID64 for any form of steamid, or nil.
local function toSteamID64( text )
	if string.match( text, "^7656%d+$" ) then return text end
	if string.match( text, "^STEAM_%d:%d:%d+$" ) then return util.SteamIDTo64( text ) end
end

function Admin.Find( text )
	text = string.Trim( tostring( text or "" ) )
	if text == "" then return nil, "Whom?" end
	local id64 = toSteamID64( text )
	local lower = string.lower( text )
	local partial = {}
	for _, p in player.Iterator() do
		if DB.Key( p ) == text or ( id64 and not p:IsBot() and p:SteamID64() == id64 ) then return p end
		local names = { string.lower( p:SteamName() ), string.lower( p:Nick() ) }
		for _, n in ipairs( names ) do
			if n == lower then return p end
		end
		for _, n in ipairs( names ) do
			if string.find( n, lower, 1, true ) then table.insert( partial, p ) break end
		end
	end
	if #partial == 1 then return partial[ 1 ] end
	if #partial > 1 then return nil, string.format( "%d players match %q.", #partial, text ) end
	return nil, string.format( "No player matches %q.", text )
end

local function check( by, target )
	if not Admin.IsStaff( by ) then return false, "You are not staff." end
	if not ( IsValid( target ) and target:IsPlayer() ) then return false, "No such player." end
	return true
end

function Admin.Kick( by, target, reason )
	local ok, why = check( by, target )
	if not ok then return refuse( by, why ) end
	reason = reason ~= nil and reason ~= "" and reason or "Kicked by staff"
	act( by, "kicked %s: %s", who( target ), reason )
	target:Kick( reason )
	return true
end

-- `target` is an online player or a steamid (SteamID64, STEAM_x:y:z, or a bot's DB key).
function Admin.Ban( by, target, minutes, reason )
	if not Admin.IsStaff( by ) then return refuse( by, "You are not staff." ) end
	minutes = math.Clamp( math.floor( tonumber( minutes ) or 0 ), 0, Admin.MAX_BAN_MINUTES )
	reason = reason ~= nil and reason ~= "" and reason or "Banned by staff"
	local key, label
	if isentity( target ) then
		if not ( IsValid( target ) and target:IsPlayer() ) then return refuse( by, "No such player." ) end
		key, label = DB.Key( target ), who( target )
	else
		local text = tostring( target or "" )
		key = toSteamID64( text ) or ( string.match( text, "^bot:" ) and text )
		if not key then return refuse( by, "That is not a SteamID." ) end
		label = key
	end
	DB.Ban( key, minutes * 60, reason, who( by ) )
	act( by, "banned %s %s: %s", label, minutes == 0 and "forever" or ( minutes .. " minutes" ), reason )
	if isentity( target ) then target:Kick( "Banned: " .. reason ) end
	return true
end

function Admin.Unban( by, steamid )
	if not Admin.IsStaff( by ) then return refuse( by, "You are not staff." ) end
	local text = tostring( steamid or "" )
	local key = toSteamID64( text ) or ( string.match( text, "^bot:" ) and text )
	if not key then return refuse( by, "That is not a SteamID." ) end
	if not DB.GetBan( key ) then return refuse( by, key .. " is not banned." ) end
	DB.Unban( key )
	return act( by, "unbanned %s", key )
end

function Admin.SetRank( by, target, rank )
	local ok, why = check( by, target )
	if not ok then return refuse( by, why ) end
	rank = tonumber( rank )
	if not rank or not Rank.NAMES[ rank ] then return refuse( by, "Ranks are 0-3." ) end
	target:SetRank( rank )
	DB.FlushPlayer( target )
	Notify( target, "Your rank is now " .. Rank.Name( rank ) .. "." )
	return act( by, "set %s to rank %s", who( target ), Rank.Name( rank ) )
end

function Admin.SetFate( by, target, fateId )
	local ok, why = check( by, target )
	if not ok then return refuse( by, why ) end
	local f = Fates.Get( tostring( fateId or "" ) )
	if not f then return refuse( by, "There is no such fate." ) end
	if not target:Alive() then return refuse( by, "They are dead; wait for them to come back." ) end
	Fates.Apply( target, f.id, { reason = "admin" } )
	return act( by, "set %s to fate %s", who( target ), f.id )
end

-- Noclip: staff only. Ghosts already fly, and toggling would drop them to the floor.
function GM:PlayerNoClip( ply, desired )
	if not Admin.IsStaff( ply ) or not ply:Alive() or ply:IsGhost() then return false end
	act( ply, "noclip %s", desired and "on" or "off" )
	return true
end

-- GMod's own receivers: properties are off in base-derived gamemodes (GM:CanProperty) and
-- variable editing is admin-only (GM:CanEditVariable), but both still read messages, so they
-- get the same rate limit as ours.
Net.Adopt( "properties", { rate = 2 } )
Net.Adopt( "editvariable", { rate = 2 } )

-- Commands ----------------------------------------------------------------------------------

-- Each takes ( caller, args ); args are already split (quotes keep spaces in names).
local COMMANDS = {
	kick = {
		usage = "kick <player> [reason]",
		run = function( by, args )
			local p, why = Admin.Find( args[ 1 ] )
			if not p then return refuse( by, why ) end
			return Admin.Kick( by, p, table.concat( args, " ", 2 ) )
		end,
	},
	ban = {
		usage = "ban <player|steamid> <minutes, 0 = forever> [reason]",
		run = function( by, args )
			if not args[ 2 ] or not tonumber( args[ 2 ] ) then return false end
			local target = Admin.Find( args[ 1 ] )
			return Admin.Ban( by, target or args[ 1 ], args[ 2 ], table.concat( args, " ", 3 ) )
		end,
	},
	unban = {
		usage = "unban <steamid>",
		run = function( by, args ) return Admin.Unban( by, args[ 1 ] ) end,
	},
	setrank = {
		usage = "setrank <player> <0-3>",
		run = function( by, args )
			local p, why = Admin.Find( args[ 1 ] )
			if not p then return refuse( by, why ) end
			return Admin.SetRank( by, p, args[ 2 ] )
		end,
	},
	setfate = {
		usage = "setfate <player> <fate id>",
		run = function( by, args )
			local p, why = Admin.Find( args[ 1 ] )
			if not p then return refuse( by, why ) end
			return Admin.SetFate( by, p, args[ 2 ] )
		end,
	},
}

function Admin.Command( by, name, args )
	local c = COMMANDS[ name ]
	if not c then return false end
	if not Admin.IsStaff( by ) then return refuse( by, "You are not staff." ) end
	if not args[ 1 ] then return refuse( by, "usage: " .. c.usage ) end
	local ok, why = c.run( by, args )
	if ok == false and why == nil then reply( by, "usage: " .. c.usage ) end
	return ok, why
end

for name in pairs( COMMANDS ) do
	concommand.Add( "gr_" .. name, function( ply, _, args ) Admin.Command( ply, name, args ) end )
end

-- Splits chat text like the console does: words, or "quoted words".
local function split( text )
	local out, i = {}, 1
	while i <= #text do
		local c = string.sub( text, i, i )
		if string.match( c, "%s" ) then
			i = i + 1
		elseif c == '"' then
			local j = string.find( text, '"', i + 1, true ) or #text + 1
			table.insert( out, string.sub( text, i + 1, j - 1 ) )
			i = j + 1
		else
			local j = string.find( text, '[%s"]', i ) or #text + 1
			table.insert( out, string.sub( text, i, j - 1 ) )
			i = j
		end
	end
	return out
end
Admin.Split = split

hook.Add( "PlayerSay", "gr_admin", function( ply, text )
	local name, rest = string.match( string.Trim( text ), "^[!/](%a+)%s*(.*)$" )
	if not name or not COMMANDS[ string.lower( name ) ] then return end
	Admin.Command( ply, string.lower( name ), split( rest ) )
	return ""
end )
