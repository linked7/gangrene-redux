-- The closed economy (step 9). At round start the treasury holds every bone that exists
-- (bones_supply). After that bones only move, through Econ.Transfer; nothing mints or destroys
-- them, so this holds at all times:
--
--   players + corpses + disconnected holdings + upgrade fund + treasury = bones_supply
--
-- econ_audit checks it on demand and a scheduled job checks it every 60 s.
--
--   Econ.Transfer( from, to, amount, source )   the one primitive that moves bones
--   Econ.ResetRound()                            refill the treasury, clear everything else
--   Econ.Deliver( ply, good )                    a crate reached the stockpile (step 11.1)
--   Econ.Buy / Econ.Withdraw / Econ.Breadline    the stockpile counter
--   Econ.SetSetting / Econ.Grant / Econ.Fine     the Kaiser's tools
--   Econ.Audit() -> drift, parts                 drift is 0 when the invariant holds
--
-- A holder is a player, a corpse ragdoll (rag.GR_Corpse.bones, step 7), Econ.TREASURY or
-- Econ.UPGRADE_FUND.
local supplyVar = CreateConVar( "bones_supply", "3000", FCVAR_ARCHIVE, "Bones in existence each round.", 0, 2 ^ 24 - 1 )

Econ.TREASURY = Econ.TREASURY or { name = "treasury" }
Econ.UPGRADE_FUND = Econ.UPGRADE_FUND or { name = "upgrade fund" }

Econ.LEDGER_SIZE = 1000
Econ.FLOW_WINDOW = 300     -- the Kaiser's panel shows money in and out over this many seconds
Econ.WAGE_INTERVAL = 300
Econ.AUDIT_INTERVAL = 60
Econ.LIMIT_WINDOW = 600    -- ration_limit counts purchases over this many seconds
Econ.COUNTER_RANGE = 150
Econ.FINE_RANGE = 600      -- Fine reaches this far, or further if the Kaiser can see the target

local EMPTY = "The treasury is empty."

-- Per-round server state. Disconnected holdings, purchases and bread line use are keyed by
-- DB.Key, so leaving and rejoining neither loses bones nor resets a limit.
local held = {}        -- DB key -> bones carried when they left
local purchases = {}   -- DB key -> { CurTime of each counter purchase }
local breadAt = {}     -- DB key -> CurTime of the last free ration
local ledger = {}      -- oldest first
-- Corpses Econ.Transfer has touched, for the audit until step 7's Corpse.All() exists.
local corpses = setmetatable( {}, { __mode = "k" } )

-- Holders ----------------------------------------------------------------------------------

local function corpseRecord( h )
	if not IsEntity( h ) or not IsValid( h ) or h:IsPlayer() then return nil end
	local rec = h.GR_Corpse
	return istable( rec ) and rec or nil
end

-- A holder's bones, or nil if `h` can't hold bones.
local function balance( h )
	if h == Econ.TREASURY then return Econ.Treasury() end
	if h == Econ.UPGRADE_FUND then return Econ.UpgradeFund() end
	if IsEntity( h ) and IsValid( h ) and h:IsPlayer() then return h:GetBones() end
	local rec = corpseRecord( h )
	if rec then return rec.bones or 0 end
end

local function setBalance( h, v )
	if h == Econ.TREASURY then
		WorldState.Set( "treasury", v )
	elseif h == Econ.UPGRADE_FUND then
		WorldState.Set( "upgrade_fund", v )
	elseif h:IsPlayer() then
		h:SetBones( v )
	else
		h.GR_Corpse.bones = v
		corpses[ h ] = true
	end
end

local function label( h )
	if istable( h ) and h.name then return h.name end
	if isstring( h ) then return h end
	if IsEntity( h ) and IsValid( h ) then
		if h:IsPlayer() then return string.format( "%s [%s]", h:Nick(), DB.Key( h ) ) end
		return "corpse #" .. h:EntIndex()
	end
	return tostring( h )
end

-- Ledger -----------------------------------------------------------------------------------

local function record( from, to, amount, source )
	table.insert( ledger, { t = CurTime(), from = label( from ), to = label( to ), amount = amount,
		source = source or "unknown", fromTreasury = from == Econ.TREASURY, toTreasury = to == Econ.TREASURY } )
	-- Trim in batches so a busy round doesn't shift the whole list on every transfer.
	if #ledger > Econ.LEDGER_SIZE * 2 then
		local keep = {}
		for i = #ledger - Econ.LEDGER_SIZE + 1, #ledger do table.insert( keep, ledger[ i ] ) end
		ledger = keep
	end
	Log.Debug( "econ", "%s -> %s: %d (%s)", label( from ), label( to ), amount, source or "unknown" )
end

-- The last `n` movements, newest first.
function Econ.Ledger( n )
	local out = {}
	for i = #ledger, math.max( 1, #ledger - ( n or 20 ) + 1 ), -1 do table.insert( out, ledger[ i ] ) end
	return out
end

-- Bones into and out of the treasury over the last `seconds`, by source.
function Econ.Flows( seconds )
	local since = CurTime() - ( seconds or Econ.FLOW_WINDOW )
	local inflow, outflow = {}, {}
	for i = #ledger, 1, -1 do
		local e = ledger[ i ]
		if e.t < since then break end
		if e.toTreasury then inflow[ e.source ] = ( inflow[ e.source ] or 0 ) + e.amount end
		if e.fromTreasury then outflow[ e.source ] = ( outflow[ e.source ] or 0 ) + e.amount end
	end
	return inflow, outflow
end

-- Transfer ---------------------------------------------------------------------------------

-- Moves `amount` whole bones. Returns true, or false and why; nothing changes on false.
function Econ.Transfer( from, to, amount, source )
	if not isnumber( amount ) or amount ~= math.floor( amount ) or amount < 0 then return false, "bad amount" end
	if from == to then return false, "same holder" end
	local have, theirs = balance( from ), balance( to )
	if have == nil or theirs == nil then return false, "not a holder" end
	if amount == 0 then return true end
	if have < amount then return false, "cannot afford" end

	setBalance( from, have - amount )
	setBalance( to, theirs + amount )
	record( from, to, amount, source )
	hook.Run( "GR_BonesMoved", from, to, amount, source )
	return true
end

-- Round reset ------------------------------------------------------------------------------

function Econ.ResetSettings()
	for _, def in ipairs( Econ.Schema ) do WorldState.Set( "econ." .. def.key, def.default ) end
end

-- Every bone goes back to the treasury and every count to zero. Round.Start (sh_round.lua) calls
-- it on map load, so each round starts fresh.
function Econ.ResetRound()
	local supply = math.Clamp( math.floor( supplyVar:GetInt() ), 0, 2 ^ 24 - 1 )
	for _, p in player.Iterator() do p:SetBones( 0 ) end
	for rag in pairs( corpses ) do
		local rec = corpseRecord( rag )
		if rec then rec.bones = 0 end
	end
	if Corpse and Corpse.All then
		for _, rec in pairs( Corpse.All() ) do
			if istable( rec ) then rec.bones = 0 end
		end
	end
	held, purchases, breadAt, ledger = {}, {}, {}, {}

	for _, good in ipairs( Econ.GOODS ) do WorldState.Set( "stock." .. good, 0 ) end
	WorldState.Set( "bones_supply", supply )
	WorldState.Set( "upgrade_fund", 0 )
	WorldState.Set( "treasury", supply )
	Econ.ResetSettings()
	local seed = Econ.Setting( "shop_stock" )
	-- Beer and spirits are brewed by proles (sh_brewing.lua) and sold in, never seeded.
	for _, good in ipairs( Econ.SHOP ) do
		if good ~= Econ.BREAD and not Econ.BREWED[ good ] and not ( Imports and Imports.IsImport( good ) ) then WorldState.Set( "stock." .. good, seed ) end
	end
	Log.Info( "econ", "new round: the treasury holds all %d bones", supply )
	hook.Run( "GR_EconReset" )
end

-- Audit ------------------------------------------------------------------------------------

-- Returns drift (0 when the invariant holds) and the sum held by each kind of holder.
function Econ.Audit()
	local parts = { players = 0, corpses = 0, held = 0, fund = Econ.UpgradeFund(), treasury = Econ.Treasury() }
	for _, p in player.Iterator() do parts.players = parts.players + p:GetBones() end

	local seen = {}
	local function addCorpse( rag )
		if seen[ rag ] then return end
		seen[ rag ] = true
		local rec = corpseRecord( rag )
		if rec then parts.corpses = parts.corpses + ( rec.bones or 0 ) end
	end
	if Corpse and Corpse.All then
		for rag in pairs( Corpse.All() ) do addCorpse( rag ) end
	end
	for rag in pairs( corpses ) do addCorpse( rag ) end
	for _, n in pairs( held ) do parts.held = parts.held + n end

	local total = parts.players + parts.corpses + parts.held + parts.fund + parts.treasury
	return total - Econ.Supply(), parts
end

local function describe( parts )
	return string.format( "players %d, corpses %d, held %d, fund %d, treasury %d, supply %d",
		parts.players, parts.corpses, parts.held, parts.fund, parts.treasury, Econ.Supply() )
end

function Econ.AuditJob()
	local drift, parts = Econ.Audit()
	if drift ~= 0 then Log.Error( "econ", "bone drift %+d (%s)", drift, describe( parts ) ) end
	return drift
end

Sched.Every( "econ_audit", Econ.AUDIT_INTERVAL, Econ.AuditJob )

-- Players come and go ----------------------------------------------------------------------

function Econ.Held( key ) return held[ key ] or 0 end

hook.Add( "PlayerDisconnected", "gr_econ", function( ply )
	local n = ply:GetBones()
	if n <= 0 then return end
	local key = DB.Key( ply )
	held[ key ] = ( held[ key ] or 0 ) + n
	ply:SetBones( 0 )
	record( ply, "held " .. key, n, "disconnect" )
end )

hook.Add( "PlayerInitialSpawn", "gr_econ", function( ply )
	local key = DB.Key( ply )
	local n = held[ key ]
	if not n then return end
	held[ key ] = nil
	ply:SetBones( ply:GetBones() + n )
	record( "held " .. key, ply, n, "rejoin" )
end )

-- Corpses (contract with step 7) -----------------------------------------------------------

hook.Add( "GR_PlayerDowned", "gr_econ", function( ply, rag )
	local ok, why = Econ.Transfer( ply, rag, ply:GetBones(), "downed" )
	if not ok then Log.Warn( "econ", "downed %s: bones stay on the player (%s)", ply:Nick(), why ) end
end )

-- Revived or got up on their own (how): the bones on the body go back to its owner.
hook.Add( "GR_PlayerRestored", "gr_econ", function( ply, rag, how )
	local rec = corpseRecord( rag )
	if rec then Econ.Transfer( rag, ply, rec.bones or 0, how == "getup" and "got up" or "revived" ) end
end )

-- A replacement ragdoll (Corpse.Rebind) joins the audit's set.
function Econ.TrackCorpse( rag ) corpses[ rag ] = true end

local function sweepCorpse( rag )
	local rec = corpseRecord( rag )
	if rec and ( rec.bones or 0 ) > 0 then Econ.Transfer( rag, Econ.TREASURY, rec.bones, "corpse removed" ) end
	corpses[ rag ] = nil
end

hook.Add( "GR_CorpseRemoved", "gr_econ", sweepCorpse )
-- Safety net: a corpse removed without the hook (map cleanup, an admin tool) still gives its bones back.
hook.Add( "EntityRemoved", "gr_econ", function( ent )
	if ent.GR_Corpse then sweepCorpse( ent ) end
end )

-- Stockpile --------------------------------------------------------------------------------

local function isGood( good ) return Econ.GOOD_DEFAULTS[ good ] ~= nil end

local function addStock( good, n )
	WorldState.Set( "stock." .. good, math.max( 0, Econ.Stock( good ) + n ) )
end

-- Raises (or lowers) a stockpile good's count without paying; crate deliveries pay themselves.
function Econ.AddStock( good, n )
	if isGood( good ) then addStock( good, n ) end
end

-- Hands goods to a player. The item system (step 8) listens for GR_StockpileDispense; `how` is
-- "buy", "take" or "free".
local function dispense( ply, good, how )
	addStock( good, -1 )
	hook.Run( "GR_StockpileDispense", ply, good, how )
end

-- A crate of `good` reached the stockpile: the count goes up and the deliverer is paid the buy
-- price, if the treasury can cover it. `payees` (default { ply }) split the price evenly; the
-- first of them (the deliverer) also gets what doesn't divide. Returns the bones paid in all, or
-- false for an unknown good.
function Econ.Deliver( ply, good, payees )
	if not isGood( good ) then return false end
	addStock( good, 1 )
	local price = Econ.Setting( "buy." .. good )
	if not IsValid( ply ) then return 0 end
	local list = {}
	for _, p in ipairs( payees or { ply } ) do
		if IsValid( p ) then table.insert( list, p ) end
	end
	if #list == 0 then list = { ply } end
	if Econ.Treasury() < price then
		Notify( ply, EMPTY .. " Your delivery was not paid for." )
		return 0
	end
	local share = math.floor( price / #list )
	local paid = 0
	for i, p in ipairs( list ) do
		local amount = share + ( i == 1 and price - share * #list or 0 )
		if amount > 0 and Econ.Transfer( Econ.TREASURY, p, amount, "delivery" ) then paid = paid + amount end
	end
	return paid
end

-- Takes up to `n` of a good out of the stock without paying (a stockpile break-in, step 11.1).
-- Returns how many were taken.
function Econ.TakeStock( good, n )
	if not isGood( good ) then return 0 end
	local taken = math.min( math.max( math.floor( n ), 0 ), Econ.Stock( good ) )
	addStock( good, -taken )
	return taken
end

local function recentPurchases( key )
	local since = CurTime() - Econ.LIMIT_WINDOW
	local kept = {}
	for _, t in ipairs( purchases[ key ] or {} ) do
		if t >= since then table.insert( kept, t ) end
	end
	purchases[ key ] = kept
	return kept
end

-- Buying at the counter for the sell price, within the reserve and the ration limit.
-- Returns ok, and a reason when refused (already told to the player).
function Econ.Buy( ply, good )
	local function refuse( why ) Notify( ply, why ) return false, why end
	if not isGood( good ) then return refuse( "The counter doesn't sell that." ) end
	if Econ.Stock( good ) <= Econ.Setting( "reserve." .. good ) then return refuse( "The counter has none to sell." ) end

	local key = DB.Key( ply )
	local limit = Econ.Setting( "ration_limit" )
	local bought = recentPurchases( key )
	if limit > 0 and #bought >= limit then return refuse( "You have bought your share. Come back later." ) end

	local price = Econ.Setting( "sell." .. good )
	if not Econ.Transfer( ply, Econ.TREASURY, price, "sale" ) then
		return refuse( string.format( "You can't afford that. It costs %d bones.", price ) )
	end
	table.insert( bought, CurTime() )
	dispense( ply, good, "buy" )
	return true
end

-- Free withdrawal for fates with StockpileAccess. Ignores the limit and the reserve.
function Econ.Withdraw( ply, good )
	local function refuse( why ) Notify( ply, why ) return false, why end
	if not ply:FateHas( "StockpileAccess" ) then return refuse( "You have no key to the stockpile." ) end
	if not isGood( good ) then return refuse( "The stockpile holds no such thing." ) end
	if Econ.Stock( good ) <= 0 then return refuse( "The stockpile is empty." ) end
	dispense( ply, good, "take" )
	return true
end

-- The bread line: one free ration every `breadline` minutes per player, down to the reserve.
function Econ.Breadline( ply )
	local function refuse( why ) Notify( ply, why ) return false, why end
	local minutes = Econ.Setting( "breadline" )
	if minutes <= 0 then return refuse( "There is no bread line." ) end
	if Econ.Stock( Econ.BREAD ) <= Econ.Setting( "reserve." .. Econ.BREAD ) then return refuse( "The bread line has run dry." ) end

	local key = DB.Key( ply )
	local wait = ( breadAt[ key ] or -math.huge ) + minutes * 60 - CurTime()
	if wait > 0 then return refuse( string.format( "Your next free ration is in %d seconds.", math.ceil( wait ) ) ) end
	breadAt[ key ] = CurTime()
	dispense( ply, Econ.BREAD, "free" )
	return true
end

-- One server function per counter message, so tests can call it without a client.
function Econ.Counter( ply, ent, action, good )
	if ent:GetClass() ~= "state_stockpile" then return false end
	if action == Econ.COUNTER_BUY then return Econ.Buy( ply, good ) end
	if action == Econ.COUNTER_TAKE then return Econ.Withdraw( ply, good ) end
	if action == Econ.COUNTER_FREE then return Econ.Breadline( ply ) end
	return false
end

Net.Receive( "gr_counter", { rate = 4, alive = true, target = "entity", range = Econ.COUNTER_RANGE }, function( ply, ent )
	local action = net.ReadUInt( 2 )
	Econ.Counter( ply, ent, action, Net.ReadString() )
end )

-- The shop (step 9) ------------------------------------------------------------------------

Econ.SHOP_SOUNDS = { "placenta/coinkeeper1.wav", "placenta/coinkeeper2.wav", "placenta/coinkeeper3.wav", "placenta/coinkeeper4.wav" }
Econ.SHOP_DROP = 40   -- the bought item lands this far in front of the buyer

-- Buys one `good` from the C-menu shop: the sell price goes to the treasury, the stock count
-- falls by one and the item appears in front of the buyer. The loaf obeys the reserve and the
-- ration limit as at the counter. Returns ok, the reason when refused (told to the player) and
-- the spawned gr_item on success.
function Econ.ShopBuy( ply, good )
	local function refuse( why ) Notify( ply, why ) return false, why end
	if not Econ.CanShop( ply ) then return false, "dead" end
	if not Econ.SHOP_SET[ good ] or not Items.Get( good ) then return refuse( "The shop doesn't sell that." ) end
	local reserve = good == Econ.BREAD and Econ.Setting( "reserve." .. good ) or 0
	if Econ.Stock( good ) <= reserve then return refuse( "That is sold out." ) end

	local bought
	if good == Econ.BREAD then
		local limit = Econ.Setting( "ration_limit" )
		bought = recentPurchases( DB.Key( ply ) )
		if limit > 0 and #bought >= limit then return refuse( "You have bought your share. Come back later." ) end
	end

	local price = Econ.Setting( "sell." .. good )
	if not Econ.Transfer( ply, Econ.TREASURY, price, "shop" ) then
		return refuse( string.format( "You can't afford that. It costs %d bones.", price ) )
	end
	if bought then table.insert( bought, CurTime() ) end
	addStock( good, -1 )

	local fwd = ply:GetForward()
	fwd.z = 0
	fwd:Normalize()
	local pos = ply:GetPos() + fwd * Econ.SHOP_DROP + Vector( 0, 0, 40 )
	local tr = util.TraceLine( { start = ply:EyePos(), endpos = pos, filter = ply } )
	if tr.Hit then pos = tr.HitPos + tr.HitNormal * 8 end
	local ent = Items.Spawn( good, 1, pos, Angle( 0, ply:EyeAngles().y, 0 ) )
	ply:EmitSound( Econ.SHOP_SOUNDS[ math.random( #Econ.SHOP_SOUNDS ) ] )
	hook.Run( "GR_ShopBuy", ply, good, ent )
	return true, nil, ent
end

Net.Receive( "nShopBuy", { rate = 4, alive = true }, function( ply )
	local good = Net.ReadString()
	if good then Econ.ShopBuy( ply, good ) end
end )

-- Wages ------------------------------------------------------------------------------------

-- Pays every living player their fate's wage from the treasury. A wage the treasury can't
-- cover isn't paid, and that player is told why.
function Econ.PayWages()
	for _, p in player.Iterator() do
		local f = p:GetFateDef()
		if p:Alive() and f and f.index ~= FATE_GHOST then
			local wage = Econ.Setting( "wage." .. f.id )
			if wage > 0 and not Econ.Transfer( Econ.TREASURY, p, wage, "wage" ) then
				Notify( p, EMPTY .. " No wage was paid." )
			end
		end
	end
end

Sched.Every( "econ_wages", Econ.WAGE_INTERVAL, Econ.PayWages )

-- The Kaiser's tools -----------------------------------------------------------------------

-- Returns the value if `key` and `value` fit the schema, or nil and why.
function Econ.ValidateSetting( key, value )
	local def = Econ.SchemaByKey[ key ]
	if not def then return nil, "There is no such setting." end
	if not isnumber( value ) or value ~= math.floor( value ) then return nil, "Settings are whole numbers." end
	local max = def.max or Econ.Supply()
	if value < def.min or value > max then return nil, string.format( "%s must be between %d and %d.", key, def.min, max ) end
	return value
end

function Econ.SetSetting( key, value, by )
	local v, why = Econ.ValidateSetting( key, value )
	if v == nil then return false, why end
	WorldState.Set( "econ." .. key, v )
	Log.Info( "econ", "%s set %s = %d", by and label( by ) or "console", key, v )
	return true
end

-- What nKaiserEcon does. The receiver has already checked the sender runs the economy.
function Econ.KaiserSet( ply, key, value )
	if not ply:FateHas( "RunsEconomy" ) then return false end
	local ok, why = Econ.SetSetting( key, value, ply )
	if not ok then Notify( ply, why ) end
	return ok
end

local function livingTarget( target )
	return IsValid( target ) and target:IsPlayer() and target:Alive() and not target:IsGhost()
end

-- Never to themselves: the Kaiser runs the economy but doesn't get rich from it (no pocket withdrawal).
function Econ.Grant( ply, target, amount )
	if not ply:FateHas( "RunsEconomy" ) or not livingTarget( target ) or target == ply then return false end
	local ok, why = Econ.Transfer( Econ.TREASURY, target, amount, "grant" )
	if ok then return true end
	if why == "cannot afford" then Notify( ply, Econ.Treasury() == 0 and EMPTY or string.format( "The treasury holds only %d bones.", Econ.Treasury() ) ) end
	return false
end

-- Same target checks as Sentence: alive, not a ghost, and in range or in sight.
function Econ.Fine( ply, target, amount )
	if not ply:FateHas( "RunsEconomy" ) or not livingTarget( target ) or target == ply then return false end
	if not isnumber( amount ) or amount ~= math.floor( amount ) or amount <= 0 then return false end
	local near = ply:GetPos():DistToSqr( target:GetPos() ) <= Econ.FINE_RANGE * Econ.FINE_RANGE
	if not near and not ply:Visible( target ) then
		Notify( ply, "You can't see them from here." )
		return false
	end
	amount = math.min( amount, target:GetBones() )
	if amount <= 0 then return false end
	local ok = Econ.Transfer( target, Econ.TREASURY, amount, "fine" )
	if ok then Notify( target, string.format( "The Kaiser fined you %d bones.", amount ) ) end
	return ok
end

Net.Receive( "nKaiserEcon", { rate = 4, alive = true, fate = "RunsEconomy" }, function( ply )
	local key = Net.ReadString()
	Econ.KaiserSet( ply, key, net.ReadDouble() )
end )

Net.Receive( "nKaiserGrant", { rate = 4, alive = true, fate = "RunsEconomy", target = "player" }, function( ply, target )
	Econ.Grant( ply, target, net.ReadUInt( 24 ) )
end )

Net.Receive( "nKaiserFine", { rate = 4, alive = true, fate = "RunsEconomy", target = "player" }, function( ply, target )
	Econ.Fine( ply, target, net.ReadUInt( 24 ) )
end )

-- The Economy table outlives no Kaiser: it goes back to its defaults when they die for good
-- (a downed Kaiser who is revived keeps it).
hook.Add( "GR_FinalDeath", "gr_econ", function( ply, f )
	if not f.RunsEconomy then return end
	Econ.ResetSettings()
	for _, p in player.Iterator() do Notify( p, "The Kaiser is dead. The economy returns to its old ways." ) end
	Log.Info( "econ", "the Kaiser died; Economy table reset" )
end )

-- Console ----------------------------------------------------------------------------------

local function adminOnly( ply ) return Admin.IsStaff( ply ) end

local function reply( ply, fmt, ... )
	local msg = string.format( fmt, ... )
	if IsValid( ply ) then ply:PrintMessage( HUD_PRINTCONSOLE, msg ) else print( msg ) end
end

concommand.Add( "econ_audit", function( ply )
	if not adminOnly( ply ) then return end
	local drift, parts = Econ.Audit()
	reply( ply, "econ_audit: drift %+d (%s)", drift, describe( parts ) )
	for _, good in ipairs( Econ.GOODS ) do reply( ply, "  stock.%s = %d", good, Econ.Stock( good ) ) end
	for _, def in ipairs( Econ.Schema ) do reply( ply, "  %s = %d", def.key, Econ.Setting( def.key ) ) end
	for _, e in ipairs( Econ.Ledger( 10 ) ) do
		reply( ply, "  %.0f  %s -> %s  %d  (%s)", e.t, e.from, e.to, e.amount, e.source )
	end
end )

-- Debug only, until the Kaiser's panel (step 11.4): econ_set <key> <value>.
concommand.Add( "econ_set", function( ply, _, args )
	if not adminOnly( ply ) then return end
	local ok, why = Econ.SetSetting( args[ 1 ] or "", tonumber( args[ 2 ] or "" ), ply )
	reply( ply, ok and "ok" or why )
end )
