-- Crates and the stockpile (step 11.1): food only exists because someone made it and hauled it.
--
--   ent_crate      made by the lunch machine (systems/sh_lunch.lua) and stamped with its crew: everyone
--                  who pressed a correct panel button or turned the boiler's valve while its panel was
--                  cleared. A ~30 kg prop carried with GMod's own +use pickup. The carrier's weapon is
--                  holstered and they can only walk; the crate drops where it is when they are hit, go
--                  down or jump, and it can be pushed along the ground. A full water_barrel and a whole
--                  bone_capsule are carried the same way.
--                  Touching a crate to a state_stockpile delivers it. A crew member's delivery splits
--                  the buy price evenly across the crew (Econ.Deliver); anyone else is paid the whole
--                  price but reported for theft (Crime.Report). Opening it puts its contents in the
--                  opener's inventory, and opening a crate you didn't crew is theft too.
--                  At most Crates.PER_STATION crates per machine wait in the world.
--   The stockpile's lock is beaten open, not pried (sh_locks.lua).
--
-- Server API (other systems rely on it):
--   Crates.HeldBy( ply ) -> crate or nil         the crate (or full barrel) `ply` is carrying
--   crate.GR_Crew  (set of DB.Keys, SERVER only), crate.GR_Kind  (the good)
--   Crates.Crew( { ply, ... } ) -> set, Crates.OnCrew( crate, ply ), Crates.Stolen( crate, ply )
--   hook GR_CrateDelivered( ply, crate )          before the delivered crate is removed
--   Crates.Spawn( kind, pos, crew, station ), Crates.Waiting( station ), Crates.Deliver, Crates.Open
Crates = Crates or {}

Crates.PER_STATION = 3     -- crates a machine may have waiting in the world
Crates.CONTENTS = 2        -- items in an opened crate
Crates.THROW_GRACE = 3     -- seconds a dropped or thrown crate still counts as its carrier's delivery

local function living( ply ) return IsValid( ply ) and ply:Alive() and not ply:IsGhost() end
local function isClass( ent, class ) return IsValid( ent ) and ent:GetClass() == class end

-- Heavy things are carried like crates: a crate, a whole bone capsule, or a barrel full of water.
function Crates.IsHeavy( ent )
	if isClass( ent, "ent_crate" ) or isClass( ent, "bone_capsule" ) then return true end
	return isClass( ent, "water_barrel" ) and ent:GetFull()
end

-- Context-menu options. show() runs on both realms, run() on the server.
Interact.Add( "crate_open", {
	label = "Open the crate",
	range = 100,
	show = function( ply, ent ) return isClass( ent, "ent_crate" ) and not ent:GetLocked() and not ply:IsGhost() end,
	run = function( ply, ent ) Crates.Open( ply, ent ) end,
} )

if CLIENT then return end

-- Walk only while carrying: no slowdown multiplier, just no running (step 5).
Fates.SpeedMods.crate = function( ply ) return 1, IsValid( ply.GR_HeldCrate ) end

-- Registry: machine -> { crate = true }, so the cap never searches the world (P2).
local waiting = setmetatable( {}, { __mode = "k" } )

function Crates.Waiting( station )
	local n = 0
	for crate in pairs( waiting[ station ] or {} ) do
		if IsValid( crate ) and not crate.GR_Taken then n = n + 1 end
	end
	return n
end

-- The crates still waiting at a station.
function Crates.WaitingList( station )
	local list = {}
	for crate in pairs( waiting[ station ] or {} ) do
		if IsValid( crate ) and not crate.GR_Taken then table.insert( list, crate ) end
	end
	return list
end

-- The crew stamp for a list of players: { [DB.Key] = true }.
function Crates.Crew( players )
	local crew = {}
	for _, p in ipairs( players or {} ) do
		if IsValid( p ) and p:IsPlayer() then crew[ DB.Key( p ) ] = true end
	end
	return crew
end

function Crates.OnCrew( crate, ply )
	return crate.GR_Crew ~= nil and IsValid( ply ) and crate.GR_Crew[ DB.Key( ply ) ] == true
end

-- A stamped crate that `ply` didn't crew. An unstamped one (spawned by staff) belongs to nobody.
function Crates.Stolen( crate, ply )
	return crate.GR_Crew ~= nil and not Crates.OnCrew( crate, ply )
end

-- Makes a crate of `kind` at `pos`, stamped with `crew` (a Crates.Crew set) and counted against `station`.
-- `work` is { [DB.Key] = points }, the steps each worker put into it (server-only GR_Work).
function Crates.Spawn( kind, pos, crew, station, work )
	local crate = ents.Create( "ent_crate" )
	if not IsValid( crate ) then return end
	crate.GR_Kind = kind
	crate.GR_Crew = crew and table.Copy( crew ) or nil
	crate.GR_Station = station
	crate.GR_Work = work and table.Copy( work ) or {}
	crate:SetKind( kind )
	crate:SetPos( pos )
	crate:Spawn()
	if IsValid( station ) then
		waiting[ station ] = waiting[ station ] or {}
		waiting[ station ][ crate ] = true
	end
	return crate
end

-- Carrying -----------------------------------------------------------------------------------

function Crates.HeldBy( ply )
	local crate = ply.GR_HeldCrate
	if IsValid( crate ) and crate.GR_Holder == ply then return crate end
	return nil
end

-- `ply` now carries `crate`: both hands full (weapon holstered) and walking until they let go.
function Crates.Hold( ply, crate )
	if Crates.HeldBy( ply ) == crate then return end
	Crates.Release( ply )
	crate.GR_Holder = ply
	ply.GR_HeldCrate = crate
	local wep = ply:GetActiveWeapon()
	ply.GR_Holstered = IsValid( wep ) and wep:GetClass() or nil
	ply:SetActiveWeapon( NULL )
	Fates.ApplySpeed( ply )
end

-- `ply` lets go of whatever crate they carry. keepSpeed: a new life already set the speeds.
function Crates.Release( ply, keepSpeed )
	local crate = ply.GR_HeldCrate
	ply.GR_HeldCrate = nil
	if IsValid( crate ) and crate.GR_Holder == ply then
		crate.GR_Holder = nil
		crate.GR_LastHolder = ply
		crate.GR_LetGoAt = CurTime()
	end
	local holstered = ply.GR_Holstered
	ply.GR_Holstered = nil
	if keepSpeed then return end -- a new life set up its own body
	Fates.ApplySpeed( ply )
	if holstered and ply:Alive() and ply:HasWeapon( holstered ) then ply:SelectWeapon( holstered ) end
end

-- Let go of the physics object too, so it falls where it is; Release follows from the drop hook.
function Crates.Drop( ply )
	local crate = Crates.HeldBy( ply )
	if not crate then return end
	ply:DropObject()
	Crates.Release( ply )
end

hook.Add( "OnPlayerPhysicsPickup", "gr_crates", function( ply, ent )
	if Crates.IsHeavy( ent ) then Crates.Hold( ply, ent ) end
end )
hook.Add( "OnPlayerPhysicsDrop", "gr_crates", function( ply, ent )
	if ply.GR_HeldCrate == ent then Crates.Release( ply ) end
end )
hook.Add( "GR_FateEnter", "gr_crates", function( ply ) Crates.Release( ply, true ) end )
hook.Add( "PlayerDeath", "gr_crates", function( ply ) Crates.Drop( ply ) end )
-- Hands are full: no drawing a weapon while carrying.
hook.Add( "PlayerSwitchWeapon", "gr_crates", function( ply ) if Crates.HeldBy( ply ) then return true end end )
hook.Add( "KeyPress", "gr_crates", function( ply, key ) if key == IN_JUMP then Crates.Drop( ply ) end end )
-- Any hit makes the carrier drop it (a Damage stage, since the pipeline swallows the hit).
Damage.Add( "Scale", "crate_drop", function( ply ) Crates.Drop( ply ) end )

-- Who a touch at the stockpile counts for: the carrier, or whoever let go of it just now.
function Crates.Deliverer( crate )
	if living( crate.GR_Holder ) then return crate.GR_Holder end
	local last = crate.GR_LastHolder
	if living( last ) and CurTime() - ( crate.GR_LetGoAt or 0 ) <= Crates.THROW_GRACE then return last end
end

-- Removing a crate (delivered, opened, cleaned up) frees its carrier and its machine slot.
-- A barrel uses it too when it empties or goes away.
function Crates.Forget( crate )
	local holder = crate.GR_Holder
	if IsValid( holder ) and holder.GR_HeldCrate == crate then Crates.Release( holder ) end
	local station = crate.GR_Station
	if station and waiting[ station ] then waiting[ station ][ crate ] = nil end
end

-- Theft -------------------------------------------------------------------------------------

local function reportTheft( ply, crate )
	if Crates.Stolen( crate, ply ) then
		Crime.Report( ply, "theft", { crew = crate.GR_Crew, crate = crate } )
	end
end

local function take( crate )
	if not IsValid( crate ) or crate.GR_Taken then return false end
	crate.GR_Taken = true -- Remove is deferred; stop a second taker in the same tick
	Crates.Forget( crate ) -- and free the carrier and the machine slot now, not at removal
	return true
end

-- Delivering and opening ------------------------------------------------------------------------

-- Who a delivery by `ply` pays: the living crew when `ply` crewed the crate (deliverer first), else `ply` alone.
function Crates.Payees( ply, crate )
	if not Crates.OnCrew( crate, ply ) then return { ply } end
	local out = { ply }
	for _, p in player.Iterator() do
		if p ~= ply and living( p ) and crate.GR_Crew[ DB.Key( p ) ] then table.insert( out, p ) end
	end
	return out
end

-- Splits `price` for a crate: half to its workers by points (floor), the rest to the hauler.
-- Returns { {key, amount}, ... } with the hauler (haulerKey) last.
function Crates.Split( price, work, haulerKey )
	local total, keys = 0, {}
	for k, pts in pairs( work or {} ) do
		if pts > 0 then total = total + pts table.insert( keys, k ) end
	end
	table.sort( keys )
	local out, given = {}, 0
	if total > 0 then
		local half = math.floor( price / 2 )
		for _, k in ipairs( keys ) do
			local amt = math.floor( half * work[ k ] / total )
			if amt > 0 then table.insert( out, { k, amt } ) given = given + amt end
		end
	end
	table.insert( out, { haulerKey, price - given } )
	return out
end

-- `ply` brings `crate` to `stockpile`: the stock rises and the buy price is paid, half to the
-- crate's workers by work points and half (plus remainders) to the hauler, stolen or not.
-- Returns the bones `ply` was paid, or false if it wasn't a delivery.
function Crates.Deliver( ply, crate, stockpile )
	if not living( ply ) or not isClass( crate, "ent_crate" ) or not isClass( stockpile, "state_stockpile" ) then return false end
	if crate.GR_Taken or crate:GetLocked() or not Econ.GOOD_DEFAULTS[ crate.GR_Kind ] then return false end
	take( crate )
	reportTheft( ply, crate )
	local kind = crate.GR_Kind
	Econ.AddStock( kind, 1 )
	local price = Econ.Setting( "buy." .. kind )
	local paid = 0
	if Econ.Treasury() < price then
		Notify( ply, "The treasury is empty. Your delivery was not paid for." )
	else
		local byKey = {}
		for _, p in player.Iterator() do byKey[ DB.Key( p ) ] = p end
		local hauler = DB.Key( ply )
		for _, row in ipairs( Crates.Split( price, crate.GR_Work, hauler ) ) do
			local to = row[ 1 ] == hauler and ply or byKey[ row[ 1 ] ]
			-- A worker who has left gets nothing; their share stays with the hauler.
			if not IsValid( to ) then to = ply end
			if row[ 2 ] > 0 and Econ.Transfer( Econ.TREASURY, to, row[ 2 ], "crate" ) and to == ply then
				paid = paid + row[ 2 ]
			end
		end
	end
	hook.Run( "GR_CrateDelivered", ply, crate )
	crate:Remove()
	return paid
end

-- `ply` breaks a crate open on the spot. What doesn't fit falls on the ground.
function Crates.Open( ply, crate )
	if not living( ply ) or not isClass( crate, "ent_crate" ) or crate:GetLocked() or not take( crate ) then return false end
	reportTheft( ply, crate )
	local kind, pos = crate.GR_Kind, crate:GetPos()
	crate:Remove()
	local fits = math.min( Crates.CONTENTS, Inventory.Fits( ply, kind ) )
	if fits > 0 then Inventory.Add( ply, kind, fits ) end
	if fits < Crates.CONTENTS then
		Items.Spawn( kind, Crates.CONTENTS - fits, pos + Vector( 0, 0, 10 ) )
		Notify( ply, "You can't carry all of it." )
	end
	return true
end
