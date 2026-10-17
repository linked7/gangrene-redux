-- Net.Receive: the only way to listen for net messages.
-- On the server every message from a client is rate-limited and its sender and target are
-- checked before the handler runs, so handlers can trust what they are given (pitfalls S1, S2).
--
-- Server options:
--   rate   messages per second allowed per player (default 4); burst = 2 * rate
--   alive  sender must be alive and not a ghost
--   fate   sender's fate must have this capability (ply:FateHas)
--   target "entity" or "player": read one entity first and check it is valid
--   range  with target, the sender must be within this many units of it
--   ghost  sender must be a ghost
-- Server handler: fn(ply, target, len). Client handler: fn(len).
--
-- Registry (server): Net.Pools[ name ] = true for every pooled name, Net.Receivers[ name ] =
-- { rate, opts } for every client->server receiver. The step 14 test checks it against
-- net.Receivers, so a raw net.Receive (also banned by tools/check_syntax.sh) shows up.
--
-- Payload helpers for handlers: Net.ReadString( max ) returns nil for a string longer than
-- `max` (default Net.MAX_STRING); Net.Finite( n | Vector ) is false for NaN and infinities.
Net = Net or {}
Net.Pools = Net.Pools or {}
Net.Receivers = Net.Receivers or {}
Net.MAX_STRING = 64

local buckets = setmetatable( {}, { __mode = "k" } )

function Net.Pool( name )
	if SERVER then
		util.AddNetworkString( name )
		Net.Pools[ name ] = true
	end
end

function Net.ReadString( max )
	local s = net.ReadString()
	if #s > ( max or Net.MAX_STRING ) then return nil end
	return s
end

local function finite( n ) return n == n and n ~= math.huge and n ~= -math.huge end

function Net.Finite( v )
	if isnumber( v ) then return finite( v ) end
	if isvector( v ) then return finite( v.x ) and finite( v.y ) and finite( v.z ) end
	return false
end

local function isGhost( ply )
	return ply.IsGhost ~= nil and ply:IsGhost()
end

local function reject( ply, name, why )
	Log.Debug( "net", "dropped %s from %s: %s", name, tostring( ply ), why )
end

local function takeToken( ply, name, rate )
	local perPly = buckets[ ply ]
	if not perPly then
		perPly = {}
		buckets[ ply ] = perPly
	end

	local now = RealTime()
	local b = perPly[ name ]
	local burst = rate * 2
	if not b then
		b = { tokens = burst, at = now }
		perPly[ name ] = b
	end

	b.tokens = math.min( burst, b.tokens + ( now - b.at ) * rate )
	b.at = now
	if b.tokens < 1 then return false end
	b.tokens = b.tokens - 1
	return true
end

function Net.Receive( name, opts, fn )
	if CLIENT then
		net.Receive( name, fn )
		return
	end

	if not istable( opts ) then error( "Net.Receive: server receiver " .. name .. " needs an opts table", 2 ) end
	Net.Pool( name )
	local rate = opts.rate or 4
	Net.Receivers[ name ] = { rate = rate, opts = opts }

	net.Receive( name, function( len, ply )
		if not IsValid( ply ) then return end
		if not takeToken( ply, name, rate ) then return reject( ply, name, "rate" ) end
		if opts.alive and ( not ply:Alive() or isGhost( ply ) ) then return reject( ply, name, "not alive" ) end
		if opts.ghost and not isGhost( ply ) then return reject( ply, name, "not a ghost" ) end
		if opts.fate and not ( ply.FateHas and ply:FateHas( opts.fate ) ) then return reject( ply, name, "fate lacks " .. opts.fate ) end

		local target
		if opts.target then
			target = net.ReadEntity()
			if not IsValid( target ) then return reject( ply, name, "invalid target" ) end
			if opts.target == "player" and not target:IsPlayer() then return reject( ply, name, "target not a player" ) end
			if opts.range and ply:GetPos():DistToSqr( target:GetPos() ) > opts.range * opts.range then
				return reject( ply, name, "out of range" )
			end
		end

		local ok, err = xpcall( fn, debug.traceback, ply, target, len )
		if not ok then Log.Error( "net", "%s handler: %s", name, err ) end
	end )
end

-- GMod's own libraries listen with raw net.Receive ("properties", "editvariable"). Adopting one
-- puts its handler behind the same rate limit and sender checks and registers it like ours.
function Net.Adopt( name, opts )
	if CLIENT then return end
	local raw = net.Receivers[ string.lower( name ) ]
	if not raw or Net.Receivers[ name ] then return end
	Net.Receive( name, opts, function( ply, _, len ) raw( len, ply ) end )
end

-- Ready handshake: the client says when it has finished loading, and the server runs
-- hook GR_PlayerReady(ply) exactly once. Anything that must reach a fresh client waits for it.
-- Bots run no client Lua, so they count as ready one tick after their first spawn.
if SERVER then
	local function markReady( ply )
		if ply.GR_Ready then return end
		ply.GR_Ready = true
		hook.Run( "GR_PlayerReady", ply )
	end

	Net.Receive( "gr_ready", { rate = 1 }, markReady )

	hook.Add( "PlayerInitialSpawn", "gr_ready_bots", function( ply )
		if not ply:IsBot() then return end
		timer.Simple( 0, function()
			if IsValid( ply ) then markReady( ply ) end
		end )
	end )
else
	hook.Add( "InitPostEntity", "gr_ready", function()
		net.Start( "gr_ready" )
		net.SendToServer()
	end )
end
