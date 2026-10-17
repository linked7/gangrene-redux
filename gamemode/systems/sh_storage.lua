-- Storage crates (design default, beyond the plan): a prole-built, lockable box that holds up to
-- Storage.CAPACITY items. Items move between it and the inventory (sh_inventory.lua) one at a time
-- through the C menu: Store... lists what you carry (the item in hand first), Take... lists what
-- is inside. It starts locked; while locked only its builder can open it, and the builder can
-- Lock / Unlock it. Anyone else can pry it: a Storage.PRY_TIME action, stopped by moving or by
-- being hurt, which unlocks it and is reported as theft (Crime.Report). Removing it drops the
-- contents as items, except at round reset (sh_build.lua removes built things then).
--
--   Storage.CanOpen( ply, box )                  shared
--   Storage.Contents( box ) -> { id -> n }       shared (clients read the networked mirror)
--   Storage.Put( ply, box, id ) / Storage.Take( ply, box, id ) -> ok
--   Storage.SetLocked( ply, box, locked ) -> ok  builder only
--   Storage.StartPry( ply, box ) -> ok, Storage.FinishPry( ply, box ), Storage.Spill( box )
Storage = Storage or {}

Storage.CAPACITY = 8
Storage.PRY_TIME = 30
Storage.PRY_RANGE = 120
Storage.PRY_MOVE = 24 -- units a prier may drift before the pry stops

local function isBox( ent ) return IsValid( ent ) and ent:GetClass() == "storage_crate" end
local function living( ply ) return IsValid( ply ) and ply:Alive() and not ply:IsGhost() end

function Storage.CanOpen( ply, box )
	return isBox( box ) and ( not box:GetLocked() or Build.IsBuilder( ply, box ) )
end

function Storage.Contents( box )
	if SERVER then return box.GR_Items or {} end
	local out = {}
	for id, n in string.gmatch( box:GetContents(), "([%w_]+)=(%d+)" ) do out[ id ] = tonumber( n ) end
	return out
end

function Storage.Total( box )
	local n = 0
	for _, c in pairs( Storage.Contents( box ) ) do n = n + c end
	return n
end

local function itemName( id )
	local def = Items.Get( id )
	return def and def.Name or id
end

-- Item ids sorted by name, for stable menus.
local function sortedIds( map )
	local ids = {}
	for id in pairs( map ) do if Items.Get( id ) then table.insert( ids, id ) end end
	table.sort( ids, function( a, b ) return itemName( a ) < itemName( b ) end )
	return ids
end

-- The inventory item whose weapon `ply` holds, if any.
local function inHand( ply )
	local wep = ply:GetActiveWeapon()
	if not IsValid( wep ) then return end
	local class = wep:GetClass()
	for id in pairs( Inventory.Items( ply ) ) do
		local def = Items.Get( id )
		if def and def.Weapon == class then return id end
	end
end

Interact.Add( "storage_store", {
	label = function( ply, ent ) return string.format( "Store... (%d/%d)", Storage.Total( ent ), Storage.CAPACITY ) end,
	show = function( ply, ent ) return Storage.CanOpen( ply, ent ) and not ply:IsGhost() end,
	choices = function( ply, ent )
		local out, held = {}, inHand( ply )
		if held then table.insert( out, { itemName( held ) .. " (in hand)", held } ) end
		local items = Inventory.Items( ply )
		for _, id in ipairs( sortedIds( items ) ) do
			if id ~= held then table.insert( out, { string.format( "%s (x%d)", itemName( id ), items[ id ] ), id } ) end
		end
		return out
	end,
	run = function( ply, ent, id ) Storage.Put( ply, ent, id ) end,
} )

Interact.Add( "storage_take", {
	label = "Take...",
	show = function( ply, ent ) return Storage.CanOpen( ply, ent ) and not ply:IsGhost() and Storage.Total( ent ) > 0 end,
	choices = function( ply, ent )
		local out, inside = {}, Storage.Contents( ent )
		for _, id in ipairs( sortedIds( inside ) ) do
			table.insert( out, { string.format( "%s (x%d)", itemName( id ), inside[ id ] ), id } )
		end
		return out
	end,
	run = function( ply, ent, id ) Storage.Take( ply, ent, id ) end,
} )

Interact.Add( "storage_lock", {
	label = function( ply, ent ) return ent:GetLocked() and "Unlock the crate" or "Lock the crate" end,
	show = function( ply, ent ) return isBox( ent ) and not ply:IsGhost() and Build.IsBuilder( ply, ent ) end,
	run = function( ply, ent ) Storage.SetLocked( ply, ent, not ent:GetLocked() ) end,
} )

Interact.Add( "storage_pry", {
	label = "Pry the crate open",
	range = Storage.PRY_RANGE,
	show = function( ply, ent )
		return isBox( ent ) and not ply:IsGhost() and ent:GetLocked() and not Build.IsBuilder( ply, ent )
	end,
	run = function( ply, ent ) Storage.StartPry( ply, ent ) end,
} )

if CLIENT then return end

-- Mirror the contents to clients as "id=n,id=n" (at most CAPACITY entries, so it stays short).
local function sync( box )
	local parts = {}
	for _, id in ipairs( sortedIds( box.GR_Items ) ) do
		table.insert( parts, id .. "=" .. box.GR_Items[ id ] )
	end
	box:SetContents( table.concat( parts, "," ) )
end

local function refuseClosed( ply, box )
	if Storage.CanOpen( ply, box ) then return false end
	Notify( ply, "The crate is locked." )
	return true
end

-- `ply` puts one `id` (default: the item in hand) into `box`.
function Storage.Put( ply, box, id )
	if not living( ply ) or not isBox( box ) or refuseClosed( ply, box ) then return false end
	id = id or inHand( ply )
	if not id or not Items.Get( id ) or Inventory.Count( ply, id ) < 1 then
		Notify( ply, "You don't have that." )
		return false
	end
	if Storage.Total( box ) >= Storage.CAPACITY then
		Notify( ply, "The crate is full." )
		return false
	end
	if not Inventory.Remove( ply, id, 1 ) then return false end
	box.GR_Items = box.GR_Items or {}
	box.GR_Items[ id ] = ( box.GR_Items[ id ] or 0 ) + 1
	sync( box )
	return true
end

-- `ply` takes one `id` out of `box`, if they can carry it.
function Storage.Take( ply, box, id )
	if not living( ply ) or not isBox( box ) or refuseClosed( ply, box ) then return false end
	local items = box.GR_Items or {}
	if not id or ( items[ id ] or 0 ) < 1 then
		Notify( ply, "That isn't in the crate." )
		return false
	end
	if Inventory.Fits( ply, id ) < 1 then
		Notify( ply, "You can't carry that." )
		return false
	end
	items[ id ] = items[ id ] - 1
	if items[ id ] <= 0 then items[ id ] = nil end
	Inventory.Add( ply, id, 1, true )
	sync( box )
	return true
end

function Storage.SetLocked( ply, box, locked )
	if not isBox( box ) then return false end
	if not Build.IsBuilder( ply, box ) then
		Notify( ply, "This isn't your crate." )
		return false
	end
	box:SetLocked( locked and true or false )
	Notify( ply, locked and "You lock the crate." or "You unlock the crate." )
	return true
end

function Storage.StartPry( ply, box )
	if not living( ply ) or not isBox( box ) then return false end
	if not box:GetLocked() or Build.IsBuilder( ply, box ) then
		Notify( ply, "You can just open it." )
		return false
	end
	local from = ply:GetPos()
	local ok = Actions.Start( ply, "storage_pry", box, Storage.PRY_TIME, {
		label = "Prying the crate open",
		range = Storage.PRY_RANGE,
		cancelOnDamage = true,
		canContinue = function( p )
			if p:GetPos():DistToSqr( from ) <= Storage.PRY_MOVE * Storage.PRY_MOVE then return true end
			Notify( p, "You moved." )
			return false
		end,
		onDone = function( p, b ) Storage.FinishPry( p, b ) end,
	} )
	if not ok then Notify( ply, "You are busy." ) end
	return ok
end

-- The pry ended: the crate is open to anyone, and breaking into someone's crate is theft.
function Storage.FinishPry( ply, box )
	if not isBox( box ) then return false end
	box:SetLocked( false )
	Crime.Report( ply, "theft", { madeBy = box.GR_BuiltBy, pos = box:GetPos() } )
	Notify( ply, "The lid gives way." )
	return true
end

-- Map cleanup and shutdown remove everything at once; nothing should be spawned then.
local quiet = false
hook.Add( "PreCleanupMap", "gr_storage", function() quiet = true end )
hook.Add( "PostCleanupMap", "gr_storage", function() quiet = false end )
hook.Add( "ShutDown", "gr_storage", function() quiet = true end )

-- The crate is going away (ENT:OnRemove): its contents fall out as item stacks.
function Storage.Spill( box )
	local items = box.GR_Items
	box.GR_Items = {}
	if quiet or box.GR_RoundReset or not items then return end
	local base, i = box:GetPos() + Vector( 0, 0, 10 ), 0
	for _, id in ipairs( sortedIds( items ) ) do
		Items.Spawn( id, items[ id ], base + Vector( ( i % 3 - 1 ) * 14, math.floor( i / 3 ) * 14, 0 ) )
		i = i + 1
	end
end
