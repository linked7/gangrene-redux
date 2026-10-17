-- State registry: every replicated player field is declared once, here or in a system file,
-- with a wire type and a scope. Declarations must run in the same order on both realms (use sh_
-- files), because a field's position is its wire id.
--
--   State.Field( "Bones", "UInt", 24, State.OWNER, 0, { persist = "bones" } )
--
-- generates ply:GetBones() on both realms and ply:SetBones( v ) on the server. Setters do nothing
-- when the value is unchanged; otherwise they mark the field dirty (and the DB row, with persist).
-- Every NET_INTERVAL the server sends each ready client one message holding the dirty fields it
-- may see: PUBLIC fields of everyone, OWNER fields of itself only. SERVER fields never leave.
-- A client that finishes loading gets everything it may see in one snapshot message.
State = State or {}
State.OWNER, State.PUBLIC, State.SERVER = 1, 2, 3
State.NET_INTERVAL = 0.1

local fields = {}      -- id -> field
local byName = {}      -- name -> field
local values = {}      -- entindex -> { [id] = value }

local ID_BITS = 8      -- up to 255 fields
local INDEX_BITS = 8   -- player entity indices 1..255

local writers = {
	UInt = function( v, bits ) net.WriteUInt( v, bits ) end,
	Int = function( v, bits ) net.WriteInt( v, bits ) end,
	Bool = function( v ) net.WriteBool( v ) end,
	Float = function( v ) net.WriteFloat( v ) end,
	String = function( v ) net.WriteString( v ) end,
}
local readers = {
	UInt = function( bits ) return net.ReadUInt( bits ) end,
	Int = function( bits ) return net.ReadInt( bits ) end,
	Bool = function() return net.ReadBool() end,
	Float = function() return net.ReadFloat() end,
	String = function() return net.ReadString() end,
}

-- Brings a value into the field's range, so a bad set can't corrupt the wire format.
local function coerce( f, v )
	if f.type == "Bool" then return v and true or false end
	if f.type == "String" then return tostring( v ) end
	v = tonumber( v ) or f.default
	if f.type == "Float" then return v end
	v = math.floor( v )
	local lo, hi
	if f.type == "UInt" then
		lo, hi = 0, 2 ^ f.bits - 1
	else
		lo, hi = -( 2 ^ ( f.bits - 1 ) ), 2 ^ ( f.bits - 1 ) - 1
	end
	if v < lo or v > hi then
		Log.Warn( "state", "%s = %s is out of range, clamped", f.name, tostring( v ) )
		v = math.Clamp( v, lo, hi )
	end
	return v
end

local function getRaw( idx, f )
	local t = values[ idx ]
	local v = t and t[ f.id ]
	if v == nil then return f.default end
	return v
end

function State.Field( name, wireType, bits, scope, default, opts )
	assert( writers[ wireType ], "State.Field " .. name .. ": unknown type " .. tostring( wireType ) )
	assert( scope == State.OWNER or scope == State.PUBLIC or scope == State.SERVER, "State.Field " .. name .. ": bad scope" )
	opts = opts or {}

	local f = byName[ name ]
	if not f then
		f = { id = #fields + 1, name = name }
		assert( f.id < 2 ^ ID_BITS, "too many state fields" )
		fields[ f.id ] = f
		byName[ name ] = f
	end
	f.type, f.bits, f.scope, f.default = wireType, bits, scope, default
	f.persist = opts.persist
	f.keep = opts.keep or opts.persist ~= nil -- kept across State.Reset

	local meta = FindMetaTable( "Player" )
	meta[ "Get" .. name ] = function( ply ) return getRaw( ply:EntIndex(), f ) end
	if SERVER then
		meta[ "Set" .. name ] = function( ply, v ) State.Set( ply, f, v ) end
	end
	return f
end

function State.Get( ply, name ) return getRaw( ply:EntIndex(), byName[ name ] ) end
function State.Fields() return fields end
function State.FieldByName( name ) return byName[ name ] end

-- Clients: apply a message ----------------------------------------------------------------

if CLIENT then
	Net.Receive( "gr_state", nil, function()
		while true do
			local idx = net.ReadUInt( INDEX_BITS )
			if idx == 0 then break end
			local t = values[ idx ] or {}
			values[ idx ] = t
			for _ = 1, net.ReadUInt( ID_BITS ) do
				local f = fields[ net.ReadUInt( ID_BITS ) ]
				local v = readers[ f.type ]( f.bits )
				local old = getRaw( idx, f )
				t[ f.id ] = v
				if old ~= v then hook.Run( "GR_StateChanged", idx, f.name, v, old ) end
			end
		end
	end )
	return
end

-- Server ----------------------------------------------------------------------------------

Net.Pool( "gr_state" )
local dirty = {}  -- entindex -> { [id] = true }

function State.Set( ply, f, v )
	if isstring( f ) then f = byName[ f ] end
	v = coerce( f, v )
	local idx = ply:EntIndex()
	local t = values[ idx ]
	if not t then
		t = {}
		values[ idx ] = t
	end
	if getRaw( idx, f ) == v then return end
	t[ f.id ] = v

	if f.scope ~= State.SERVER then
		local d = dirty[ idx ] or {}
		dirty[ idx ] = d
		d[ f.id ] = true
	end
	if f.persist then DB.Set( ply, f.persist, v ) end
end

-- Puts every field without `keep` (that is, every non-persistent one) back to its default.
function State.Reset( ply )
	for _, f in ipairs( fields ) do
		if not f.keep then State.Set( ply, f, f.default ) end
	end
end

local function canSee( f, idx, recipientIdx )
	return f.scope == State.PUBLIC or ( f.scope == State.OWNER and idx == recipientIdx )
end

-- Lists what `recipient` should receive as { {idx, {field ids}}, ... }.
-- With `all`, every visible field of every player; otherwise only dirty ones.
function State.Collect( recipient, all )
	local rIdx = recipient:EntIndex()
	local out = {}
	local source = dirty
	if all then
		source = {}
		for _, p in player.Iterator() do source[ p:EntIndex() ] = true end
	end

	for idx, marks in pairs( source ) do
		local ids = {}
		for _, f in ipairs( fields ) do
			if ( all or marks[ f.id ] ) and canSee( f, idx, rIdx ) then table.insert( ids, f.id ) end
		end
		if #ids > 0 then table.insert( out, { idx, ids } ) end
	end
	return out
end

State.stats = { messages = 0, bytes = 0, ticks = 0 }

local function send( recipient, entries )
	if #entries == 0 then return end
	net.Start( "gr_state" )
	for _, e in ipairs( entries ) do
		local idx, ids = e[ 1 ], e[ 2 ]
		net.WriteUInt( idx, INDEX_BITS )
		net.WriteUInt( #ids, ID_BITS )
		for _, id in ipairs( ids ) do
			local f = fields[ id ]
			net.WriteUInt( id, ID_BITS )
			writers[ f.type ]( getRaw( idx, f ), f.bits )
		end
	end
	net.WriteUInt( 0, INDEX_BITS )
	State.stats.bytes = State.stats.bytes + net.BytesWritten()
	State.stats.messages = State.stats.messages + 1
	net.Send( recipient )
end

function State.NetTick()
	State.stats.ticks = State.stats.ticks + 1
	if not next( dirty ) then return end
	for _, ply in player.Iterator() do
		if ply.GR_Ready and not ply:IsBot() then send( ply, State.Collect( ply ) ) end
	end
	dirty = {}
end

timer.Create( "gr_state_net", State.NET_INTERVAL, 0, State.NetTick )

hook.Add( "GR_PlayerReady", "gr_state_snapshot", function( ply )
	if not ply:IsBot() then send( ply, State.Collect( ply, true ) ) end
end )

-- A new player's fields reach everyone on the next tick, overwriting whatever the previous
-- owner of that entity index left in client caches.
hook.Add( "PlayerInitialSpawn", "gr_state", function( ply )
	local d = {}
	for _, f in ipairs( fields ) do
		if f.scope ~= State.SERVER then d[ f.id ] = true end
	end
	dirty[ ply:EntIndex() ] = d
end )

-- Persistent fields take their values from the DB row once it has loaded.
hook.Add( "GR_PlayerLoaded", "gr_state", function( ply )
	local t = values[ ply:EntIndex() ] or {}
	values[ ply:EntIndex() ] = t
	for _, f in ipairs( fields ) do
		if f.persist then t[ f.id ] = coerce( f, DB.Get( ply, f.persist ) ) end
	end
end )

hook.Add( "PlayerDisconnected", "gr_state", function( ply )
	local idx = ply:EntIndex()
	-- Clear after this tick's hooks, so disconnect handlers can still read the values.
	timer.Simple( 0, function()
		values[ idx ] = nil
		dirty[ idx ] = nil
	end )
end )
