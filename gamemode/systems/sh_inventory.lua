-- Inventory: one map { itemId -> count } per player, held on the server and belonging to one life.
-- Weight and the CarryAdd total are cached and adjusted on every change, never recounted (P7).
-- Changed counts collect in a dirty set and go to the owner once per net tick as absolute
-- values, so a lost or repeated delta can't leave the client wrong for long.
--
--   Inventory.Count( ply, id )  Inventory.Weight( ply )  Inventory.Limit( ply )   shared
--   Inventory.Fits( ply, id ) -> how many more of `id` fit
--   Inventory.Add( ply, id, n, force ) -> ok, why     force ignores the weight limit
--   Inventory.Remove( ply, id, n ) -> ok
--   Inventory.Use( ply, id )  Inventory.Drop( ply, id, n ) -> ent  Inventory.PickUp( ply, ent ) -> n
--   Inventory.TakeAll( ply ) -> map    Inventory.GiveAll( ply, map )    for corpses (step 7)
--   Items.Spawn( id, count, pos ) -> gr_item entity
--   Items.SpawnMany( { id, id, { id, count }, ... }, pos, ang ) -> batch   one every 0.25 s
--
-- Carry limit = Inventory.CARRY_BASE + fate CarryBonus + every carried item's CarryAdd.
Inventory = Inventory or {}
Inventory.CARRY_BASE = 20
Inventory.PUMP_COOLDOWN = 3 -- seconds between uses of any water pump, per player

local ITEM_BITS = 10   -- up to 1023 item kinds
local COUNT_BITS = 16
local MAX_COUNT = 2 ^ COUNT_BITS - 1

local function newInv()
	return { items = {}, weight = 0, carryAdd = 0, dirty = {}, full = false }
end

-- The one place counts change, on both realms, so the cached totals can't disagree with the map.
local function setCount( inv, def, n )
	local old = inv.items[ def.id ] or 0
	local delta = n - old
	inv.items[ def.id ] = n > 0 and n or nil
	inv.weight = inv.weight + delta * def.Weight
	inv.carryAdd = inv.carryAdd + delta * def.CarryAdd
	return old
end

if CLIENT then
	Inventory.Local = Inventory.Local or newInv()
	function Inventory.Of( ply )
		if ply == LocalPlayer() then return Inventory.Local end
		return newInv() -- other players' inventories are never sent
	end
else
	function Inventory.Of( ply )
		local inv = ply.GR_Inv
		if not inv then
			inv = newInv()
			ply.GR_Inv = inv
		end
		return inv
	end
end

function Inventory.Count( ply, id ) return Inventory.Of( ply ).items[ id ] or 0 end
function Inventory.Items( ply ) return Inventory.Of( ply ).items end
function Inventory.Weight( ply ) return Inventory.Of( ply ).weight end

function Inventory.Limit( ply )
	return Inventory.CARRY_BASE + ( tonumber( ply:FateHas( "CarryBonus" ) ) or 0 ) + Inventory.Of( ply ).carryAdd
end

-- How many more of `id` fit under the limit. Bags pay for themselves, so they can always fit.
function Inventory.Fits( ply, id )
	local def = Items.Get( id )
	if not def or ply:IsGhost() then return 0 end
	local perUnit = def.Weight - def.CarryAdd
	local room = Inventory.Limit( ply ) - Inventory.Weight( ply )
	if perUnit <= 0 then return room >= 0 and MAX_COUNT or 0 end
	return math.max( 0, math.floor( room / perUnit + 1e-6 ) )
end

if CLIENT then
	Net.Receive( "gr_inv", nil, function()
		local inv = Inventory.Local
		if net.ReadBool() then
			inv.items, inv.weight, inv.carryAdd = {}, 0, 0
		end
		for _ = 1, net.ReadUInt( ITEM_BITS ) do
			local def = Items.ByIndex( net.ReadUInt( ITEM_BITS ) )
			local n = net.ReadUInt( COUNT_BITS )
			if def then setCount( inv, def, n ) end
		end
		hook.Run( "GR_InventoryChanged" )
	end )

	function Inventory.RequestUse( id )
		local def = Items.Get( id )
		if not def then return end
		net.Start( "gr_inv_use" )
		net.WriteUInt( def.index, ITEM_BITS )
		net.SendToServer()
	end

	function Inventory.RequestDrop( id, n )
		local def = Items.Get( id )
		if not def then return end
		net.Start( "gr_inv_drop" )
		net.WriteUInt( def.index, ITEM_BITS )
		net.WriteUInt( math.Clamp( n or 1, 1, MAX_COUNT ), COUNT_BITS )
		net.SendToServer()
	end
	return
end

-- Server ----------------------------------------------------------------------------------

Net.Pool( "gr_inv" )

-- Item weapons follow the count: given at the first one, taken with the last.
local function syncWeapon( ply, def, n )
	if not def.Weapon then return end
	if n > 0 then
		if ply:Alive() and not ply:IsGhost() and not ply:HasWeapon( def.Weapon ) then ply:Give( def.Weapon ) end
	elseif ply:HasWeapon( def.Weapon ) then
		ply:StripWeapon( def.Weapon )
	end
end

local function set( ply, def, n )
	local inv = Inventory.Of( ply )
	n = math.Clamp( math.floor( n ), 0, MAX_COUNT )
	if setCount( inv, def, n ) == n then return end
	inv.dirty[ def.id ] = true
	syncWeapon( ply, def, n )
	hook.Run( "GR_InventoryChanged", ply, def.id, n )
end

local function living( ply )
	return IsValid( ply ) and ply:Alive() and not ply:IsGhost()
end

function Inventory.Add( ply, id, n, force )
	local def = Items.Get( id )
	n = math.floor( n or 1 )
	if not def then return false, "There is no such thing." end
	if n < 1 then return false, "Nothing to add." end
	if ply:IsGhost() then return false, "The dead carry nothing." end
	if not force and Inventory.Fits( ply, id ) < n then return false, "You can't carry that much." end
	set( ply, def, Inventory.Count( ply, id ) + n )
	return true
end

function Inventory.Remove( ply, id, n )
	local def = Items.Get( id )
	n = math.floor( n or 1 )
	local have = Inventory.Count( ply, id )
	if not def or n < 1 or have < n then return false end
	set( ply, def, have - n )
	return true
end

-- Empties the inventory and returns what was in it. The caller now owns the map.
function Inventory.TakeAll( ply )
	local inv = Inventory.Of( ply )
	local taken = inv.items
	for id in pairs( taken ) do syncWeapon( ply, Items.Get( id ), 0 ) end
	inv.items, inv.weight, inv.carryAdd = {}, 0, 0
	inv.dirty, inv.full = {}, true
	if next( taken ) then hook.Run( "GR_InventoryChanged", ply ) end
	return taken
end

-- Adds every item in `map`, ignoring the weight limit (a revived body keeps what it had).
function Inventory.GiveAll( ply, map )
	for id, n in pairs( map or {} ) do
		local def = Items.Get( id )
		if def then
			set( ply, def, Inventory.Count( ply, id ) + n )
		else
			Log.Warn( "inventory", "GiveAll: unknown item %s dropped", tostring( id ) )
		end
	end
end

function Inventory.Clear( ply )
	Inventory.TakeAll( ply )
end

function Inventory.Use( ply, id )
	local def = Items.Get( id )
	if not def or not living( ply ) or Inventory.Count( ply, id ) < 1 then return false end

	if def.Weapon and not def.OnUse and not def.Effects then
		ply:SelectWeapon( def.Weapon )
		return true
	end
	if not def.OnUse and not def.Effects then
		Notify( ply, "You can't do anything with that." )
		return false
	end
	if def.OnUse and def.OnUse( ply, def ) == false then return false end
	for name, amount in pairs( def.Effects or {} ) do Needs.Add( ply, name, amount, def.id ) end
	if def.Consumable then Inventory.Remove( ply, id, 1 ) end
	return true
end

-- A dropped stack is one gr_item entity holding `count` of one item.
function Items.Spawn( id, count, pos, ang )
	local ent = ents.Create( "gr_item" )
	if not IsValid( ent ) then return end
	ent:SetItemId( id )
	ent:SetCount( count or 1 )
	ent:SetPos( pos )
	ent:SetAngles( ang or angle_zero )
	ent:Spawn()
	return ent
end

-- Several items at one spot, one every Items.SPAWN_GAP seconds instead of all in one frame, where
-- they would spawn inside each other and fight the physics. Use it in place of a loop of
-- Items.Spawn. `list` holds item ids, or { id, count } for a stack; unknown ids are skipped.
-- The first one appears at once. Batches run side by side. Returns the batch: `batch.spawned`
-- fills in as they appear, and `batch.done` is set after the last.
Items.SPAWN_GAP = 0.25
local batches = {}

local function spawnNext( batch )
	while batch.i <= #batch.list do
		local entry = batch.list[ batch.i ]
		batch.i = batch.i + 1
		local id, count = entry, 1
		if istable( entry ) then id, count = entry[ 1 ], entry[ 2 ] or 1 end
		if Items.Get( id ) then
			local ent = Items.Spawn( id, count, batch.pos, batch.ang )
			if IsValid( ent ) then table.insert( batch.spawned, ent ) end
			break
		end
	end
	batch.done = batch.i > #batch.list or nil
	batch.nextAt = CurTime() + Items.SPAWN_GAP
	return batch.done
end

function Items.SpawnMany( list, pos, ang )
	local batch = { list = table.Copy( list or {} ), pos = pos, ang = ang, i = 1, spawned = {} }
	if not spawnNext( batch ) then table.insert( batches, batch ) end
	return batch
end

-- Nothing still queued spills into a cleaned map or a new round.
local function dropBatches() batches = {} end
hook.Add( "PreCleanupMap", "gr_items_spawn_many", dropBatches )
hook.Add( "GR_RoundStart", "gr_items_spawn_many", dropBatches )

Sched.Every( "items_spawn_many", 0.05, function()
	if #batches == 0 then return end
	local now = CurTime()
	for i = #batches, 1, -1 do
		if now >= batches[ i ].nextAt and spawnNext( batches[ i ] ) then table.remove( batches, i ) end
	end
end )

function Inventory.Drop( ply, id, n )
	if not living( ply ) then return end
	n = math.min( math.floor( n or 1 ), Inventory.Count( ply, id ) )
	if n < 1 or not Inventory.Remove( ply, id, n ) then return end

	-- In front of the player, pulled back from any wall the trace hits.
	local start = ply:GetShootPos()
	local dir = ply:GetAimVector()
	local tr = util.TraceLine( { start = start, endpos = start + dir * 40, filter = ply } )
	local pos = tr.HitPos - dir * 10
	return Items.Spawn( id, n, pos, Angle( 0, ply:EyeAngles().y, 0 ) )
end

-- Takes as much of the stack as fits. Returns how many were taken.
function Inventory.PickUp( ply, ent )
	if not IsValid( ent ) or ent:GetClass() ~= "gr_item" or ent.GR_Taken or not living( ply ) then return 0 end
	local id, count = ent:GetItemId(), ent:GetCount()
	local n = math.min( count, Inventory.Fits( ply, id ) )
	if n < 1 then
		Notify( ply, "You can't carry any more." )
		return 0
	end
	Inventory.Add( ply, id, n, true )
	if n >= count then
		ent.GR_Taken = true -- Remove is deferred; stop a second taker in the same tick
		ent:Remove()
	else
		ent:SetCount( count - n )
		Notify( ply, "You can't carry all of it." )
	end
	return n
end

-- Networking ------------------------------------------------------------------------------

-- What the owner should be sent now: { full = bool, entries = { { index, count } } }, or nil.
-- Clears the pending set.
function Inventory.Collect( ply )
	local inv = ply.GR_Inv
	if not inv or ( not inv.full and not next( inv.dirty ) ) then return end
	local out = { full = inv.full, entries = {} }
	local source = inv.full and inv.items or inv.dirty
	for id in pairs( source ) do
		table.insert( out.entries, { Items.Get( id ).index, inv.items[ id ] or 0 } )
	end
	inv.dirty, inv.full = {}, false
	return out
end

local function send( ply, d )
	net.Start( "gr_inv" )
	net.WriteBool( d.full )
	net.WriteUInt( #d.entries, ITEM_BITS )
	for _, e in ipairs( d.entries ) do
		net.WriteUInt( e[ 1 ], ITEM_BITS )
		net.WriteUInt( e[ 2 ], COUNT_BITS )
	end
	net.Send( ply )
end

Sched.Every( "inventory_net", State.NET_INTERVAL, function()
	for _, ply in player.Iterator() do
		-- A client that isn't ready yet keeps its pending set until it is.
		if ply.GR_Ready then
			local d = Inventory.Collect( ply )
			if d and Net.IsClient( ply ) then send( ply, d ) end
		end
	end
end )

hook.Add( "GR_PlayerReady", "gr_inventory", function( ply )
	Inventory.Of( ply ).full = true
end )

Net.Receive( "gr_inv_use", { rate = 4, alive = true }, function( ply )
	local def = Items.ByIndex( net.ReadUInt( ITEM_BITS ) )
	if def then Inventory.Use( ply, def.id ) end
end )

Net.Receive( "gr_inv_drop", { rate = 4, alive = true }, function( ply )
	local def = Items.ByIndex( net.ReadUInt( ITEM_BITS ) )
	local n = net.ReadUInt( COUNT_BITS )
	if def then Inventory.Drop( ply, def.id, n ) end
end )

hook.Add( "PlayerSay", "gr_inventory", function( ply, text )
	local cmd = string.lower( string.Trim( text ) )
	if cmd == "/inv" or cmd == "!inv" then
		ply:ConCommand( "gr_inventory" )
		return ""
	end
end )

-- Life cycle ------------------------------------------------------------------------------

-- The inventory belongs to one life: becoming a ghost clears it. Any other fate entry (including
-- a revive, which must keep it) gives back the weapons Fates.Apply just stripped.
hook.Add( "GR_FateEnter", "gr_inventory", function( ply, f, reason )
	if f.index == FATE_GHOST and reason ~= "revive" then
		Inventory.Clear( ply )
		return
	end
	for id, n in pairs( Inventory.Items( ply ) ) do syncWeapon( ply, Items.Get( id ), n ) end
end )

-- Corpse contract with step 7: rag.GR_Corpse.inventory is a map the corpse owns.
hook.Add( "GR_PlayerDowned", "gr_inventory", function( ply, rag )
	local corpse = rag and rag.GR_Corpse
	if not corpse then return end
	corpse.inventory = corpse.inventory or {}
	for id, n in pairs( Inventory.TakeAll( ply ) ) do
		corpse.inventory[ id ] = ( corpse.inventory[ id ] or 0 ) + n
	end
end )

-- Revived or got up on their own: either way the body's things come back.
hook.Add( "GR_PlayerRestored", "gr_inventory", function( ply, rag )
	local corpse = rag and rag.GR_Corpse
	if not corpse or not corpse.inventory then return end
	Inventory.GiveAll( ply, corpse.inventory )
	-- Emptied in place, since the corpse system may hold the same table.
	for id in pairs( corpse.inventory ) do corpse.inventory[ id ] = nil end
end )

-- Goods bought or taken at the stockpile counter (step 9) arrive as items. The sale is already
-- paid, so the weight limit doesn't refuse it.
hook.Add( "GR_StockpileDispense", "gr_inventory", function( ply, good )
	if Items.Get( good ) then Inventory.Add( ply, good, 1, true ) end
end )
