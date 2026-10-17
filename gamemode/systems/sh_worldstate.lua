-- WorldState: public values that belong to the world rather than a player (the treasury,
-- stockpile counts, the Economy table). It is State's counterpart for the world: changes mark
-- the key dirty, dirty keys go out to every client in one message per tick, and a client that
-- finishes loading gets every key in one snapshot. No SetGlobal* anywhere (P4, R8).
--
--   WorldState.Set( key, value )      server only; value is a number, string or bool
--   WorldState.Get( key, default )    both realms
--
-- Clients run hook GR_WorldChanged( key, new, old ) when a value arrives.
WorldState = WorldState or {}
WorldState.NET_INTERVAL = 0.1

local values = {}  -- key -> value; on the server this is the authoritative copy

local T_NUMBER, T_STRING, T_BOOL = 0, 1, 2
local COUNT_BITS = 12  -- up to 4095 keys per message

function WorldState.Get( key, default )
	local v = values[ key ]
	if v == nil then return default end
	return v
end

local function readValue()
	local t = net.ReadUInt( 2 )
	if t == T_NUMBER then return net.ReadDouble() end
	if t == T_STRING then return net.ReadString() end
	return net.ReadBool()
end

if CLIENT then
	Net.Receive( "gr_world", nil, function()
		for _ = 1, net.ReadUInt( COUNT_BITS ) do
			local key = net.ReadString()
			local v = readValue()
			local old = values[ key ]
			values[ key ] = v
			if old ~= v then hook.Run( "GR_WorldChanged", key, v, old ) end
		end
	end )
	return
end

-- Server ------------------------------------------------------------------------------------

Net.Pool( "gr_world" )
local dirty = {}

local function writeValue( v )
	if isnumber( v ) then
		net.WriteUInt( T_NUMBER, 2 )
		net.WriteDouble( v )
	elseif isstring( v ) then
		net.WriteUInt( T_STRING, 2 )
		net.WriteString( v )
	else
		net.WriteUInt( T_BOOL, 2 )
		net.WriteBool( v )
	end
end

function WorldState.Set( key, value )
	if not ( isnumber( value ) or isstring( value ) or isbool( value ) ) then
		error( "WorldState.Set " .. tostring( key ) .. ": value must be a number, string or bool", 2 )
	end
	if values[ key ] == value then return end
	values[ key ] = value
	dirty[ key ] = true
end

-- Keys waiting for the next tick; for tests and debugging.
function WorldState.Pending() return table.GetKeys( dirty ) end

local function send( recipients, keys )
	if #recipients == 0 or #keys == 0 then return end
	net.Start( "gr_world" )
	net.WriteUInt( #keys, COUNT_BITS )
	for _, key in ipairs( keys ) do
		net.WriteString( key )
		writeValue( values[ key ] )
	end
	net.Send( recipients )
end

local function readyClients()
	local out = {}
	for _, ply in player.Iterator() do
		if ply.GR_Ready and Net.IsClient( ply ) then table.insert( out, ply ) end
	end
	return out
end

function WorldState.NetTick()
	if not next( dirty ) then return end
	local keys = table.GetKeys( dirty )
	dirty = {}
	send( readyClients(), keys )
end

Sched.Every( "world_net", WorldState.NET_INTERVAL, WorldState.NetTick )

hook.Add( "GR_PlayerReady", "gr_world_snapshot", function( ply )
	if Net.IsClient( ply ) then send( { ply }, table.GetKeys( values ) ) end
end )
