-- The work loop (step 11.1): food only exists because someone made it and hauled it.
--
--   ration_press   working it is a timed action; when it ends an ent_crate of the press's good
--                  appears beside it. At most Crates.PER_STATION crates per press wait in the world.
--                  Any class in Crates.STATIONS works the same way (GetGood() names its good).
--                  Only the presses the map layout places exist; players can't build production.
--   ent_crate      a ~30 kg prop carried with GMod's own +use pickup. The carrier's weapon is
--                  holstered and they can only walk; the crate drops where it is when they are hit,
--                  go down or jump, and it can be pushed along the ground. Touching it to a
--                  state_stockpile delivers it (Econ.Deliver pays the deliverer the buy price);
--                  opening it puts its contents in the opener's inventory. Either one, done to a
--                  crate someone else made, is reported as theft (Crime.Report).
--   The stockpile's lock is beaten open, not pried (sh_locks.lua).
--
-- Server API (other systems rely on it):
--   Crates.HeldBy( ply ) -> crate or nil         the crate `ply` is carrying
--   crate.GR_MadeBy  (DB.Key of the maker), crate.GR_Kind  (the good)
--   hook GR_CrateDelivered( ply, crate )          before the delivered crate is removed
--   hook GR_CrateMade( ply, crate, station )      a press finished a crate
--   Crates.Spawn( kind, pos, maker, station ), Crates.Work, Crates.Deliver, Crates.Open
Crates = Crates or {}

Crates.PRESS_TIME = 30     -- seconds of work per crate
Crates.PER_STATION = 3     -- crates a press may have waiting in the world
Crates.CONTENTS = 2        -- items in an opened crate
Crates.THROW_GRACE = 3     -- seconds a dropped or thrown crate still counts as its carrier's delivery
Crates.STATIONS = Crates.STATIONS or {}  -- class -> true: entities that run the work loop
Crates.STATIONS.ration_press = true

local function living( ply ) return IsValid( ply ) and ply:Alive() and not ply:IsGhost() end
local function isClass( ent, class ) return IsValid( ent ) and ent:GetClass() == class end

-- Context-menu options. show() runs on both realms, run() on the server.
Interact.Add( "press_work", {
	label = "Work the press",
	show = function( ply, ent ) return isClass( ent, "ration_press" ) and not ply:IsGhost() end,
	run = function( ply, ent ) Crates.Work( ply, ent ) end,
} )

Interact.Add( "crate_open", {
	label = "Open the crate",
	range = 100,
	show = function( ply, ent ) return isClass( ent, "ent_crate" ) and not ply:IsGhost() end,
	run = function( ply, ent ) Crates.Open( ply, ent ) end,
} )

if CLIENT then return end

-- Walk only while carrying: no slowdown multiplier, just no running (step 5).
Fates.SpeedMods.crate = function( ply ) return 1, IsValid( ply.GR_HeldCrate ) end

-- Registry: press -> { crate = true }, so the cap never searches the world (P2).
local waiting = setmetatable( {}, { __mode = "k" } )

function Crates.Waiting( station )
	local n = 0
	for crate in pairs( waiting[ station ] or {} ) do
		if IsValid( crate ) and not crate.GR_Taken then n = n + 1 end
	end
	return n
end

-- Makes a crate of `kind` at `pos`, stamped with `maker`'s key and counted against `station`.
function Crates.Spawn( kind, pos, maker, station )
	local crate = ents.Create( "ent_crate" )
	if not IsValid( crate ) then return end
	crate.GR_Kind = kind
	crate.GR_MadeBy = IsValid( maker ) and DB.Key( maker ) or nil
	crate.GR_Station = station
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
	if isClass( ent, "ent_crate" ) then Crates.Hold( ply, ent ) end
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

-- Removing a crate (delivered, opened, cleaned up) frees its carrier and its press slot.
function Crates.Forget( crate )
	local holder = crate.GR_Holder
	if IsValid( holder ) and holder.GR_HeldCrate == crate then Crates.Release( holder ) end
	local station = crate.GR_Station
	if station and waiting[ station ] then waiting[ station ][ crate ] = nil end
end

-- Theft -------------------------------------------------------------------------------------

local function reportTheft( ply, crate )
	local madeBy = crate.GR_MadeBy
	if madeBy and madeBy ~= DB.Key( ply ) then
		Crime.Report( ply, "theft", { madeBy = madeBy, crate = crate } )
	end
end

local function take( crate )
	if not IsValid( crate ) or crate.GR_Taken then return false end
	crate.GR_Taken = true -- Remove is deferred; stop a second taker in the same tick
	Crates.Forget( crate ) -- and free the carrier and the press slot now, not at removal
	return true
end

-- Working the press ---------------------------------------------------------------------------

local function besideStation( station, n )
	local side = ( n % 3 - 1 ) * 30
	return station:GetPos() + station:GetForward() * 50 + station:GetRight() * side + Vector( 0, 0, 30 )
end

function Crates.IsStation( ent ) return IsValid( ent ) and Crates.STATIONS[ ent:GetClass() ] == true end

function Crates.Work( ply, station )
	if not living( ply ) or not Crates.IsStation( station ) then return false end
	if Crates.Waiting( station ) >= Crates.PER_STATION then
		Notify( ply, "Crates are piling up here. Haul some away first." )
		return false
	end
	local good = station:GetGood()
	if not Econ.GOOD_DEFAULTS[ good ] then
		Log.Error( "crates", "press %d makes unknown good %s", station:EntIndex(), tostring( good ) )
		return false
	end
	local ok = Actions.Start( ply, "press", station, Crates.PRESS_TIME, {
		label = "Pressing " .. ( Items.Get( good ) and Items.Get( good ).Name or good ),
		onDone = function( p, st ) Crates.FinishWork( p, st ) end,
	} )
	if not ok then Notify( ply, "You are busy." ) end
	return ok
end

-- The press's action ended: the crate appears, if there is still room for it.
function Crates.FinishWork( ply, station )
	if not IsValid( station ) then return end
	local n = Crates.Waiting( station )
	if n >= Crates.PER_STATION then
		Notify( ply, "Crates are piling up here. Your work went to waste." )
		return
	end
	local crate = Crates.Spawn( station:GetGood(), besideStation( station, n ), ply, station )
	if crate then hook.Run( "GR_CrateMade", ply, crate, station ) end
	return crate
end

-- Delivering and opening ------------------------------------------------------------------------

-- `ply` brings `crate` to `stockpile`: the stock rises and the deliverer is paid the buy price.
-- Returns the bones paid, or false if it wasn't a delivery.
function Crates.Deliver( ply, crate, stockpile )
	if not living( ply ) or not isClass( crate, "ent_crate" ) or not isClass( stockpile, "state_stockpile" ) then return false end
	if crate.GR_Taken or not Econ.GOOD_DEFAULTS[ crate.GR_Kind ] then return false end
	take( crate )
	reportTheft( ply, crate )
	local paid = Econ.Deliver( ply, crate.GR_Kind )
	hook.Run( "GR_CrateDelivered", ply, crate )
	crate:Remove()
	return paid
end

-- `ply` breaks a crate open on the spot. What doesn't fit falls on the ground.
function Crates.Open( ply, crate )
	if not living( ply ) or not isClass( crate, "ent_crate" ) or not take( crate ) then return false end
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
