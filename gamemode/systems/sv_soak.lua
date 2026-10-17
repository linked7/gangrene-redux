-- Bot soak (plan step 14): N bots live through the real systems for a while, and the server
-- samples its own health once a minute. Inert unless started:
--
--   data/gr_soak.txt holding "<minutes> <bots> [seed] [pace] [skip,list]" when the map loads (tools/soak.sh writes it), or
--   gr_soak <minutes> <bots> [seed] in the server console
--
-- Bots run no client Lua, so the driver calls the same server functions the receivers call:
-- Fates.Take, Interact.Run, Lunch.Press / TurnValve / Feed / Pour, Econ.Counter, Crates.Deliver, the Kaiser's Econ/Kaiser functions,
-- ply:Say for chat, TakeDamageInfo for violence. Positions are teleports next to the target.
-- Randomness is seeded; physics and the scheduler's spread still make runs differ a little.
--
-- Output in data/gr_soak/: metrics.csv (one row a minute), sched.csv (per job per minute) and
-- summary.txt, whose last line is "DONE pass" or "DONE fail <reasons>". It fails on any Log.Error,
-- any bone drift, or transient entities (dropped items, crates, bodies) growing without bound.
-- Round.ChangeLevel is a no-op while the soak runs; the soak ends one round halfway and one at the end.
Soak = Soak or {}

local PREFIX = "t14s_"
local DIR = "gr_soak"
local SAMPLE = 60        -- seconds between metric rows
local CHURN = 120        -- seconds between a bot leaving and another (or the same) joining
local ACT_MIN, ACT_MAX = 2, 6

local S                  -- the running soak, or nil

local function rnd( a, b ) return a + math.random() * ( b - a ) end
local function pick( t ) return t[ math.random( #t ) ] end
local function chance( p ) return math.random() < p end

local function living( p ) return IsValid( p ) and p:Alive() and not p:IsGhost() and not p:GetPassedOut() end

local function soakBots()
	local out = {}
	for _, b in ipairs( player.GetBots() ) do
		if string.StartWith( b:SteamName(), PREFIX ) then table.insert( out, b ) end
	end
	return out
end

local function livingOthers( bot )
	local out = {}
	for _, p in player.Iterator() do
		if p ~= bot and living( p ) then table.insert( out, p ) end
	end
	return out
end

-- Ground under `pos`, or `pos` itself.
local function ground( pos )
	local tr = util.TraceLine( { start = pos + Vector( 0, 0, 64 ), endpos = pos - Vector( 0, 0, 256 ), mask = MASK_PLAYERSOLID_BRUSHONLY } )
	if tr.Hit and not tr.StartSolid then return tr.HitPos + Vector( 0, 0, 2 ) end
	return pos
end

-- Puts `bot` on the ground about `r` units from `target` (an entity or a vector), on a spot its
-- hull fits (not inside a crate, body or player). Real players walk; a teleport while carrying a
-- physics object, or into one, is something only this driver does, so it lets go first.
local function goNear( bot, target, r )
	local at = isvector( target ) and target or target:GetPos()
	bot:DropObject()
	local mins, maxs = bot:GetHull()
	local pos
	for _ = 1, 6 do
		local a = math.random() * math.pi * 2
		pos = ground( at + Vector( math.cos( a ), math.sin( a ), 0 ) * ( r or 50 ) )
		local tr = util.TraceHull( { start = pos, endpos = pos, mins = mins, maxs = maxs, mask = MASK_PLAYERSOLID, filter = bot } )
		if not tr.StartSolid then break end
	end
	bot:SetPos( pos )
	bot:SetEyeAngles( ( at - pos ):Angle() )
end

-- A spot `dist` units from the base in direction `yaw`, pulled back from walls.
local function spot( yaw, dist )
	local dir = Angle( 0, yaw, 0 ):Forward()
	local from = S.base + Vector( 0, 0, 40 )
	local tr = util.TraceLine( { start = from, endpos = from + dir * dist, mask = MASK_SOLID_BRUSHONLY } )
	local d = tr.Hit and math.max( 40, tr.Fraction * dist - 80 ) or dist
	return ground( S.base + dir * d )
end

local function spawnAt( class, pos, yaw, kv )
	local ent = ents.Create( class )
	for k, v in pairs( kv or {} ) do ent:SetKeyValue( k, v ) end
	ent:SetPos( pos )
	ent:SetAngles( Angle( 0, yaw or 0, 0 ) )
	ent:Spawn()
	return ent
end

local function skipped( what ) return S.skip[ what ] end

local function count( what ) S.counts[ what ] = ( S.counts[ what ] or 0 ) + 1 end

-- Registries of what the soak watches, filled by hooks (no FindByClass).
local tracked = { gr_item = {}, ent_crate = {}, storage_crate = {} }

hook.Add( "OnEntityCreated", "gr_soak", function( ent )
	if not S then return end
	local set = tracked[ ent:GetClass() ]
	if set then set[ ent ] = CurTime() end
end )

hook.Add( "EntityRemoved", "gr_soak", function( ent )
	local set = tracked[ ent:GetClass() ]
	if set then set[ ent ] = nil end
end )

local function trackedList( class )
	local out = {}
	for ent in pairs( tracked[ class ] ) do
		if IsValid( ent ) and not ent.GR_Taken then table.insert( out, ent ) end
	end
	return out
end

-- Fates -------------------------------------------------------------------------------------

-- Weighted fate wishes, rolled every time a ghost picks.
local WISHES = { prole = 5, slave = 5, sanitar = 2, korpsman = 2, kaiser = 2 }

local function takeFate( bot )
	if chance( 0.15 ) then return end -- linger as a ghost for a while
	local list = {}
	for id, w in pairs( WISHES ) do
		for _ = 1, w do table.insert( list, id ) end
	end
	table.sort( list )
	for i = #list, 2, -1 do
		local j = math.random( i )
		list[ i ], list[ j ] = list[ j ], list[ i ]
	end
	-- Kaiser-rank bots want the throne first, so the state usually has a head.
	if bot:GetRank() >= RANK_KAISER and chance( 0.7 ) then table.insert( list, 1, "kaiser" ) end
	local tried = {}
	for _, id in ipairs( list ) do
		if not tried[ id ] then
			tried[ id ] = true
			local f = Fates.Get( id )
			-- Stem cells are given as needed: the soak is about the systems, not the grind.
			if f and ( f.Cost or 0 ) > bot:GetStemCells() then bot:SetStemCells( f.Cost ) end
			if Fates.CanTake( bot, id ) then
				if Fates.Take( bot, id ) then count( "fate_" .. id ) return end
			end
		end
	end
end

-- Needs -------------------------------------------------------------------------------------

local NEED_GOOD = { Emptiness = "ration", Dryness = "clean_water" }

local function counter( bot, good )
	goNear( bot, S.stockpile, 70 )
	if bot:FateHas( "StockpileAccess" ) and Econ.Counter( bot, S.stockpile, Econ.COUNTER_TAKE, good ) then
		count( "counter_take" ) return true
	end
	if good == Econ.BREAD and Econ.Setting( "breadline" ) > 0 and chance( 0.5 )
		and Econ.Counter( bot, S.stockpile, Econ.COUNTER_FREE, good ) then
		count( "counter_free" ) return true
	end
	if Econ.Counter( bot, S.stockpile, Econ.COUNTER_BUY, good ) then count( "counter_buy" ) return true end
	count( "counter_refused" )
	return false
end

-- Eats or drinks when a need is high, buying first if needed. Returns true if it did anything.
local function tendNeeds( bot )
	for need, good in pairs( NEED_GOOD ) do
		if Needs.Get( bot, need ) >= 45 then
			if Inventory.Count( bot, good ) < 1 then counter( bot, good ) end
			if Inventory.Count( bot, good ) > 0 and Inventory.Use( bot, good ) then count( "use_" .. good ) return true end
		end
	end
	if Needs.Get( bot, "Dryness" ) >= 70 and Inventory.Count( bot, "dirty_water" ) > 0 then
		return Inventory.Use( bot, "dirty_water" )
	end
	return false
end

-- Work ----------------------------------------------------------------------------------------

local function deliver( bot, crate )
	if skipped( "deliver" ) then return end
	goNear( bot, crate, 40 )
	crate:Use( bot, bot ) -- the real pickup: PickupObject, then OnPlayerPhysicsPickup
	if Crates.HeldBy( bot ) ~= crate then Crates.Hold( bot, crate ) end
	goNear( bot, S.stockpile, 70 ) -- lets go of the crate; delivery below names the bot directly
	Crates.Release( bot )
	if chance( 0.3 ) and not skipped( "drop_on_stockpile" ) then
		-- Through the entity's own touch path: drop it above the stockpile and let it fall on it.
		local top = S.stockpile:GetPos() + Vector( 0, 0, S.stockpile:OBBMaxs().z + 20 )
		crate:SetPos( top )
		local phys = crate:GetPhysicsObject()
		if IsValid( phys ) then phys:Wake() phys:SetVelocity( Vector( 0, 0, -200 ) ) end
		count( "crate_drop_on_stockpile" )
		return
	end
	if Crates.Deliver( bot, crate, S.stockpile ) then count( "crate_delivered" ) end
end

-- The lunch machine: the same core calls its Use, touch and valve receiver make. Bots can't find
-- map water, so a barrel fetch fills the barrel where it stands (the rest is the real pour).
local function lunchAct( bot )
	local m, boiler = S.machine, S.boiler
	if not IsValid( m ) or not IsValid( boiler ) then return end
	local p = boiler:GetPressure()
	if boiler:GetVenting() or p > Lunch.GREEN_MAX - 5 or ( p < Lunch.GREEN_MIN + 5 and chance( 0.8 ) ) then
		goNear( bot, boiler, 60 )
		if Lunch.TurnValve( bot, boiler, p >= Lunch.GREEN_MIN + 5 and "vent" or "build" ) then count( "valve" ) end
		return
	end
	if boiler:GetWater() < Lunch.BOILER_WATER - Lunch.BARREL_WATER and chance( 0.5 ) then
		local barrel = pick( S.barrels )
		if IsValid( barrel ) then
			goNear( bot, barrel, 40 )
			Lunch.SetBarrelFull( barrel, true )
			if Lunch.Pour( boiler, barrel ) then count( "barrel_poured" ) end
		end
		return
	end
	if m:GetBiomass() < 2 and chance( 0.6 ) then
		local capsules = Lunch.All( "bone_capsule" )
		local chunks = Lunch.All( "meat_chunk" )
		if #chunks > 0 then
			if Lunch.Feed( m, pick( chunks ) ) then count( "fed_chunk" ) end
		elseif #capsules > 0 then
			local c = pick( capsules )
			goNear( bot, c, 50 )
			if chance( 0.5 ) then
				if Lunch.Feed( m, c ) then count( "fed_capsule" ) end
			elseif Lunch.Hurt( c, 40 ) then
				count( "capsule_burst" )
			end
		end
		return
	end
	if chance( 0.05 ) then
		if Lunch.FlipLever( bot, m ) then count( "lever" ) end
		return
	end
	goNear( bot, m, 60 )
	local right, wrong = {}, {}
	for k = 1, Lunch.BUTTONS do
		local s = m:GetButton( k )
		if s > 0 then table.insert( s == m:GetLight() and right or wrong, k ) end
	end
	local k = ( #wrong > 0 and chance( 0.05 ) ) and pick( wrong ) or ( #right > 0 and pick( right ) )
	if not k then return end
	local r = Lunch.Press( bot, m, k )
	if r then count( "press_" .. r ) end
end

local function workerAct( bot )
	local crates = trackedList( "ent_crate" )
	if #crates > 0 and chance( 0.7 ) then
		local crate = pick( crates )
		if IsValid( crate.GR_Holder ) then return end
		if chance( 0.12 ) then
			if skipped( "open" ) then return end
			goNear( bot, crate, 40 )
			if Interact.Run( bot, "crate_open", crate ) then count( "crate_opened" ) end
			return
		end
		return deliver( bot, crate )
	end
	if chance( 0.01 ) and not bot:FateHas( "StockpileAccess" ) and not skipped( "lock" ) then
		-- A few blows on the stockpile's lock, through the real damage path (sh_locks.lua).
		goNear( bot, S.stockpile, 80 )
		for _ = 1, math.random( 3, 12 ) do
			local dmg = DamageInfo()
			dmg:SetDamage( 10 )
			dmg:SetDamageType( DMG_CLUB )
			dmg:SetAttacker( bot )
			dmg:SetInflictor( bot )
			local had = S.stockpile:GetIntegrity()
			S.stockpile:TakeDamageInfo( dmg )
			if S.stockpile:GetIntegrity() < had then count( "lock_hit" ) end
			if had > 0 and S.stockpile:GetIntegrity() == 0 then count( "lock_broken" ) end
		end
		return
	end
	if chance( 0.004 ) and Build.CanBuild( bot ) and not skipped( "build" ) then
		local kind = pick( Build.ORDER )
		bot:SetEyeAngles( Angle( 45, math.random( 360 ), 0 ) )
		local tr = util.TraceLine( { start = bot:EyePos(), endpos = bot:EyePos() + bot:GetAimVector() * 140, filter = bot } )
		if tr.HitWorld and Build.Place( bot, kind, tr.HitPos ) then count( "built" ) end
		return
	end
	if skipped( "press" ) then return end
	lunchAct( bot )
end

-- Police, medicine, the Kaiser ------------------------------------------------------------------

local function bodies( state )
	local out = {}
	for rag, rec in pairs( Corpse.All() ) do
		if IsValid( rag ) and rec.state == state then table.insert( out, rag ) end
	end
	return out
end

local function policeAct( bot )
	local wanted = {}
	for _, p in ipairs( livingOthers( bot ) ) do
		if p:IsWanted() then table.insert( wanted, p ) end
	end
	local downed = {}
	for _, rag in ipairs( bodies( "bleedout" ) ) do
		local owner = Corpse.Get( rag ).owner
		if IsValid( owner ) and owner:IsWanted() then table.insert( downed, rag ) end
	end
	if #downed > 0 and chance( 0.6 ) then
		local rag = pick( downed )
		goNear( bot, rag, 50 )
		if Interact.Run( bot, "arrest", rag ) then count( "arrest" ) end
	elseif #wanted > 0 and chance( 0.5 ) then
		local t = pick( wanted )
		goNear( bot, t, 50 )
		local dmg = DamageInfo()
		dmg:SetAttacker( bot )
		dmg:SetInflictor( bot )
		dmg:SetDamageType( DMG_CLUB )
		dmg:SetDamage( rnd( 10, 40 ) )
		t:TakeDamageInfo( dmg )
		count( "beating" )
	elseif chance( 0.1 ) then
		local offer = pick( Police.OFFERS )
		goNear( bot, S.station, 60 )
		if Interact.Run( bot, "station_" .. offer.item, S.station ) then count( "station_buy" ) end
	else
		local others = livingOthers( bot )
		if #others == 0 then return end
		local t = pick( others )
		goNear( bot, t, 50 )
		if Interact.Run( bot, "inspect", t ) then count( "inspect" ) end
	end
end

local function medicAct( bot )
	local downed = bodies( "bleedout" )
	if #downed > 0 then
		local rag = pick( downed )
		goNear( bot, rag, 40 )
		if Corpse.StartRevive( bot, rag ) then count( "revive_start" ) end
		return
	end
	local hurt = {}
	for _, p in ipairs( livingOthers( bot ) ) do
		if p:Health() < p:GetMaxHealth() or p:GetBullet() then table.insert( hurt, p ) end
	end
	if #hurt == 0 then return end
	local t = pick( hurt )
	goNear( bot, t, 50 )
	if Medicine.Upgraded( bot ) and chance( 0.3 ) and Interact.Run( bot, "lovebox", t ) then count( "lovebox" ) return end
	local proc = t:GetBullet() and "bullet" or pick( { "heal", "heal", "pox" } )
	if Interact.Run( bot, "surgery_" .. proc, t ) then count( "surgery_" .. proc ) end
end

-- Sane values for the Kaiser to set, by key prefix.
local SETTING_RANGES = {
	{ "^buy%.", 10, 40 }, { "^sell%.", 5, 40 }, { "^reserve%.", 0, 3 }, { "^wage%.", 0, 50 },
	{ "^ration_limit$", 0, 6 }, { "^breadline$", 0, 2 }, { "^revive_fee$", 0, 100 },
}

local function kaiserAct( bot )
	local r = math.random()
	local others = livingOthers( bot )
	if r < 0.35 then
		local def = pick( Econ.Schema )
		for _, range in ipairs( SETTING_RANGES ) do
			if string.match( def.key, range[ 1 ] ) then
				if Econ.KaiserSet( bot, def.key, math.random( range[ 2 ], range[ 3 ] ) ) then count( "kaiser_set" ) end
				break
			end
		end
	elseif r < 0.55 and #others > 0 then
		if Econ.Grant( bot, pick( others ), math.random( 10, 60 ) ) then count( "kaiser_grant" ) end
	elseif r < 0.7 and #others > 0 then
		local t = pick( others )
		goNear( bot, t, 200 )
		if Econ.Fine( bot, t, math.random( 5, 40 ) ) then count( "kaiser_fine" ) end
	elseif r < 0.75 then
		local ids = table.GetKeys( bot:FateHas( "Upgrades" ) or {} )
		table.sort( ids )
		if #ids > 0 and Kaiser.Upgrade( bot, pick( ids ) ) then count( "kaiser_upgrade" ) end
	elseif r < 0.82 and #others > 0 then
		local t = pick( others )
		goNear( bot, t, 200 )
		if Kaiser.Sentence( bot, t, pick( { WANTED_TORMENT, WANTED_JUDGMENT, WANTED_DEATH } ) ) then count( "kaiser_sentence" ) end
	elseif r < 0.9 then
		for _, t in ipairs( others ) do
			if t:IsWanted() then
				goNear( bot, t, 200 )
				if Kaiser.Forgive( bot, t ) then count( "kaiser_forgive" ) end
				break
			end
		end
	else
		Kaiser.SendLedger( bot )
		count( "kaiser_ledger" )
	end
end

-- Everyone ------------------------------------------------------------------------------------

local LINES = { "Glory to the Kaiser.", "Where is the bread?", "My back hurts.", "Has anyone seen my sack?",
	"The press is jammed again.", "Ration day!", "I saw nothing.", "Long live the People." }
local MODES = { "", "", "", "/y ", "/w ", "/me ", "// ", "/r " }

local function chatAct( bot )
	bot:Say( pick( MODES ) .. pick( LINES ), chance( 0.05 ) )
	count( "chat" )
end

local function violence( bot )
	local downed = bodies( "bleedout" )
	if #downed > 0 and chance( 0.25 ) then
		local rag = pick( downed )
		goNear( bot, rag, 50 )
		local dmg = DamageInfo()
		dmg:SetAttacker( bot )
		dmg:SetInflictor( bot )
		dmg:SetDamageType( DMG_BULLET )
		dmg:SetDamage( 30 )
		rag:TakeDamageInfo( dmg )
		count( "finish_off" )
		return
	end
	local others = livingOthers( bot )
	if #others == 0 then return end
	local t = pick( others )
	goNear( bot, t, 60 )
	local dmg = DamageInfo()
	dmg:SetAttacker( bot )
	dmg:SetInflictor( bot )
	dmg:SetDamageType( pick( { DMG_BULLET, DMG_CLUB, DMG_SLASH } ) )
	dmg:SetDamage( chance( 0.15 ) and 250 or rnd( 5, 35 ) )
	dmg:SetDamagePosition( t:GetPos() + Vector( 0, 0, 40 ) )
	t:TakeDamageInfo( dmg )
	count( "hurt" )
end

local function commendAct( bot )
	for _, p in ipairs( livingOthers( bot ) ) do
		if p:FateHas( "ForNewPlayers" ) and p:GetRank() == RANK_FOOLISH then
			goNear( bot, p, 60 )
			if Interact.Run( bot, "commend", p ) then count( "commend" ) end
			return
		end
	end
end

local KEEP = { permit_tool = true, surgical_tools = true, baton = true, scope = true, novoluger = true, strategy_book = true }

local function itemsAct( bot )
	local items = trackedList( "gr_item" )
	if #items > 0 and chance( 0.6 ) then
		local ent = pick( items )
		goNear( bot, ent, 30 )
		ent:Use( bot, bot )
		count( "pickup" )
		return
	end
	local ids = {}
	for id in pairs( Inventory.Items( bot ) ) do
		if not KEEP[ id ] then table.insert( ids, id ) end
	end
	table.sort( ids )
	if #ids == 0 then return end
	bot:SetEyeAngles( Angle( 20, math.random( 360 ), 0 ) )
	if Inventory.Drop( bot, pick( ids ), 1 ) then count( "drop" ) end
end

local function act( bot )
	if not IsValid( bot ) or not bot:Alive() then return end
	if bot:IsGhost() then
		if chance( 0.1 ) then chatAct( bot ) end
		return takeFate( bot )
	end
	if bot:GetPassedOut() or Actions.Get( bot ) then return end
	if tendNeeds( bot ) then return end

	local r = math.random()
	if r < 0.5 then
		if bot:FateHas( "RunsEconomy" ) then return not skipped( "kaiser" ) and kaiserAct( bot ) end
		if bot:FateHas( "Police" ) then return not skipped( "police" ) and policeAct( bot ) end
		if bot:FateHas( "CanRevive" ) then return not skipped( "medic" ) and medicAct( bot ) end
		return workerAct( bot )
	end
	if r < 0.65 then return not skipped( "chat" ) and chatAct( bot ) end
	if r < 0.75 then return not skipped( "violence" ) and violence( bot ) end
	if r < 0.77 then return commendAct( bot ) end
	if r < 0.9 then return not skipped( "items" ) and itemsAct( bot ) end
	if r < 0.93 then return counter( bot, pick( { "ration", "clean_water" } ) ) end
	if r < 0.935 then
		bot:Kill()
		count( "suicide" )
	end
end

-- Bots coming and going -------------------------------------------------------------------------

local function addBot( name )
	local b = player.CreateNextBot( name )
	if not IsValid( b ) then
		Log.Warn( "soak", "could not add bot %s", name )
		return
	end
	S.nextAct[ name ] = CurTime() + rnd( 1, ACT_MAX )
	return b
end

local function churn()
	local bots = soakBots()
	if #bots == 0 then return end
	local b = pick( bots )
	local name = b:SteamName()
	b:DropObject()
	b:Kick( "soak churn" )
	count( "churn_leave" )
	S.rejoin = { name = name, at = CurTime() + 10 }
end

local function rejoin()
	local r = S.rejoin
	S.rejoin = nil
	local b = addBot( r.name )
	if not b then return end
	count( "churn_join" )
	-- Some come back as newcomers again, so there are always slaves to free.
	if chance( 0.3 ) and b:GetRank() ~= RANK_KAISER then
		b:SetRank( RANK_FOOLISH )
		DB.FlushPlayer( b )
	end
end

-- Metrics ---------------------------------------------------------------------------------------

local function memKB() return collectgarbage( "count" ) end

local function transient()
	local n = { gr_item = 0, ent_crate = 0, bodies = 0, buildings = 0 }
	for ent in pairs( tracked.gr_item ) do if IsValid( ent ) then n.gr_item = n.gr_item + 1 end end
	for ent in pairs( tracked.ent_crate ) do if IsValid( ent ) then n.ent_crate = n.ent_crate + 1 end end
	for ent in pairs( tracked.storage_crate ) do if IsValid( ent ) then n.buildings = n.buildings + 1 end end
	for rag in pairs( Corpse.All() ) do if IsValid( rag ) then n.bodies = n.bodies + 1 end end
	return n
end

local CSV_HEAD = "t,players,alive,ents,gr_item,ent_crate,bodies,buildings,lua_kb,net_Bps,net_msgs_s,flush_last_ms,flush_max_ms,flushes,max_frame_ms,drift,errors,warns,treasury,fund,stock_ration,stock_water"

local function sample( final )
	local now = SysTime()
	local dt = math.max( now - S.lastSampleAt, 0.001 )
	local net = Net.stats
	local bps = ( net.bytes - S.lastNet.bytes ) / dt
	local mps = ( net.messages - S.lastNet.messages ) / dt
	S.lastNet = { bytes = net.bytes, messages = net.messages }
	S.lastSampleAt = now

	local alive = 0
	for _, p in player.Iterator() do if living( p ) then alive = alive + 1 end end
	local drift = Econ.Audit()
	local tr = transient()
	local t = math.floor( CurTime() - S.startedAt )
	local flushMax = DB.stats.windowMaxMs
	DB.stats.windowMaxMs = 0
	local frame = S.maxFrame * 1000
	S.maxFrame = 0

	local row = {
		t = t, players = player.GetCount(), alive = alive, ents = ents.GetCount(), gr_item = tr.gr_item,
		ent_crate = tr.ent_crate, bodies = tr.bodies, buildings = tr.buildings, lua_kb = memKB(), net_Bps = bps,
		net_msgs_s = mps, flush_last_ms = DB.stats.lastMs, flush_max_ms = math.max( flushMax, 0 ),
		flushes = DB.stats.flushes, max_frame_ms = frame, drift = drift, errors = Log.counts.error, warns = Log.counts.warn,
		treasury = Econ.Treasury(), fund = Econ.UpgradeFund(), stock_ration = Econ.Stock( "ration" ),
		stock_water = Econ.Stock( "clean_water" ),
	}
	table.insert( S.rows, row )
	local cells = {}
	for col in string.gmatch( CSV_HEAD, "[^,]+" ) do
		local v = row[ col ]
		table.insert( cells, ( isnumber( v ) and v ~= math.floor( v ) ) and string.format( "%.2f", v ) or tostring( v ) )
	end
	file.Append( DIR .. "/metrics.csv", table.concat( cells, "," ) .. "\n" )
	if drift ~= 0 then S.driftSeen = S.driftSeen or drift end

	-- Scheduler: calls, average and worst cost per job over the window.
	local lines = {}
	for _, name in ipairs( Sched.Names() ) do
		local j = Sched.Get( name )
		local prev = S.lastSched[ name ] or { calls = 0, total = 0 }
		local calls, total = j.calls - prev.calls, j.total - prev.total
		local avg = calls > 0 and total / calls * 1000 or 0
		table.insert( lines, string.format( "%d,%s,%d,%.4f,%.4f,%.3f", t, name, calls, avg, j.max * 1000, total * 1000 ) )
		local agg = S.schedAgg[ name ] or { calls = 0, total = 0, peak = 0, worstAvg = 0 }
		agg.calls, agg.total = agg.calls + calls, agg.total + total
		agg.peak = math.max( agg.peak, j.max )
		agg.worstAvg = math.max( agg.worstAvg, calls > 0 and total / calls or 0 )
		S.schedAgg[ name ] = agg
		S.lastSched[ name ] = { calls = j.calls, total = j.total }
		j.max = 0
	end
	file.Append( DIR .. "/sched.csv", table.concat( lines, "\n" ) .. "\n" )

	Log.Info( "soak", "t=%ds players=%d alive=%d ents=%d items=%d crates=%d bodies=%d mem=%.0fKB net=%.0fB/s flush=%.2fms frame=%.1fms drift=%d errors=%d",
		t, row.players, alive, row.ents, tr.gr_item, tr.ent_crate, tr.bodies, row.lua_kb, bps, row.flush_last_ms, frame, drift, row.errors )
end

hook.Add( "Think", "gr_soak_frame", function()
	if not S then return end
	local now = SysTime()
	if S.lastThink then S.maxFrame = math.max( S.maxFrame, now - S.lastThink ) end
	S.lastThink = now
end )

local function stat( list, key )
	local sum, peak = 0, -math.huge
	for _, r in ipairs( list ) do
		sum = sum + r[ key ]
		peak = math.max( peak, r[ key ] )
	end
	return #list > 0 and sum / #list or 0, peak
end

local function finish()
	sample( true )
	local rows, out, fails = S.rows, {}, {}
	local function say( fmt, ... ) table.insert( out, string.format( fmt, ... ) ) end

	local drift = Econ.Audit()
	if drift ~= 0 then table.insert( fails, "drift " .. drift ) end
	if S.driftSeen then table.insert( fails, "drift seen during the run: " .. S.driftSeen ) end
	if Log.counts.error > 0 then table.insert( fails, Log.counts.error .. " Log.Error lines" ) end

	-- Unbounded growth: the transient entities at the end against the worst of the first half.
	local half = math.max( 1, math.floor( #rows / 2 ) )
	local firstPeak = 0
	for i = 1, half do
		local r = rows[ i ]
		firstPeak = math.max( firstPeak, r.gr_item + r.ent_crate + r.bodies )
	end
	local last = rows[ #rows ]
	local lastN = last.gr_item + last.ent_crate + last.bodies
	if #rows >= 6 and lastN > firstPeak * 2 + 20 then
		table.insert( fails, string.format( "transient entities grew: %d at the end, peak %d in the first half", lastN, firstPeak ) )
	end

	say( "soak: %d min, %d bots, seed %d, %d samples", S.minutes, S.botCount, S.seed, #rows )
	local avgNet, peakNet = stat( rows, "net_Bps" )
	say( "net: avg %.0f B/s, peak %.0f B/s (%.1f B/s per player)", avgNet, peakNet, avgNet / math.max( S.botCount, 1 ) )
	local _, peakFlush = stat( rows, "flush_max_ms" )
	say( "db flush: %d flushes, %d rows, worst %.2f ms, last %.2f ms", DB.stats.flushes, DB.stats.rows, math.max( DB.stats.maxMs, peakFlush ), DB.stats.lastMs )
	local _, peakFrame = stat( rows, "max_frame_ms" )
	say( "worst frame gap: %.1f ms", peakFrame )
	local q = math.max( 1, math.floor( #rows / 4 ) )
	say( "lua memory KB: start %.0f, 25%% %.0f, 50%% %.0f, 75%% %.0f, end %.0f", rows[ 1 ].lua_kb, rows[ q ].lua_kb,
		rows[ math.min( #rows, 2 * q ) ].lua_kb, rows[ math.min( #rows, 3 * q ) ].lua_kb, last.lua_kb )
	say( "entities: start %d, 25%% %d, 50%% %d, 75%% %d, end %d (items %d, crates %d, bodies %d, buildings %d at the end)",
		rows[ 1 ].ents, rows[ q ].ents, rows[ math.min( #rows, 2 * q ) ].ents, rows[ math.min( #rows, 3 * q ) ].ents, last.ents,
		last.gr_item, last.ent_crate, last.bodies, last.buildings )
	say( "drift at the end: %d; Log.Error lines: %d; Log.Warn lines: %d", drift, Log.counts.error, Log.counts.warn )

	say( "sched (job: calls, avg ms/call, worst window avg ms, peak ms, total ms):" )
	local names = table.GetKeys( S.schedAgg )
	table.sort( names, function( a, b ) return S.schedAgg[ a ].total > S.schedAgg[ b ].total end )
	for _, name in ipairs( names ) do
		local a = S.schedAgg[ name ]
		say( "  %-20s %8d  %.4f  %.4f  %.3f  %.1f", name, a.calls, a.calls > 0 and a.total / a.calls * 1000 or 0,
			a.worstAvg * 1000, a.peak * 1000, a.total * 1000 )
	end
	local acts = table.GetKeys( S.counts )
	table.sort( acts )
	local parts = {}
	for _, k in ipairs( acts ) do table.insert( parts, k .. "=" .. S.counts[ k ] ) end
	say( "actions: %s", table.concat( parts, " " ) )
	say( #fails == 0 and "DONE pass" or ( "DONE fail " .. table.concat( fails, "; " ) ) )

	file.Write( DIR .. "/summary.txt", table.concat( out, "\n" ) .. "\n" )
	for _, l in ipairs( out ) do Log.Info( "soak", "%s", l ) end
	Soak.Stop()
end

-- The driver ------------------------------------------------------------------------------------

local function setup()
	S.ready = true
	-- Round.Start ran on map load too; the real round timer stays out of the way.
	WorldState.Set( "round.endsAt", S.endsAt + 600 )
	local bots = soakBots()
	S.base = ground( bots[ 1 ] and bots[ 1 ]:GetPos() or Vector( 0, 0, 0 ) )
	S.stockpile = spawnAt( "state_stockpile", spot( 0, 260 ), 180 )
	S.station = spawnAt( "sanitation_station", spot( 180, 260 ), 0 )
	S.machine = spawnAt( "lunch_machine", spot( 90, 260 ), 270 )
	S.boiler = spawnAt( "line_boiler", spot( 45, 300 ), 225 )
	S.machine.GR_Boiler = S.boiler -- not the map layout's boiler, wherever that stands
	S.barrels = { spawnAt( "water_barrel", spot( 135, 300 ), 0 ), spawnAt( "water_barrel", spot( 270, 260 ), 0 ) }
	S.capsulePoint = spawnAt( "capsule_spawn", spot( 315, 260 ), 0 )
	Log.Info( "soak", "world set up around %s", tostring( S.base ) )
	-- Ranks: two Kaiser-rank bots, about a third newcomers, the rest freed citizens.
	for i, b in ipairs( bots ) do
		local rank = i <= 2 and RANK_KAISER or ( i <= 2 + math.floor( #bots * 0.3 ) and RANK_FOOLISH or RANK_FRIEND )
		b:SetRank( rank )
		b:SetStemCells( 3 )
	end
end

local function roundStart()
	Round.Start()
	-- The real round timer stays out of the way; the soak ends rounds itself.
	WorldState.Set( "round.endsAt", S.endsAt + 600 )
	S.roundRestartAt = nil
end

function Soak.Tick()
	if not S then return end
	local now = CurTime()
	if not S.ready then return setup() end

	if now >= S.nextSample then
		S.nextSample = now + SAMPLE
		sample()
	end
	if now >= S.endsAt then return finish() end

	-- Rounds: one ends halfway (and a new one starts), the last one shortly before the end.
	if not S.midEnded and now >= S.startedAt + ( S.endsAt - S.startedAt ) / 2 then
		S.midEnded = true
		Round.End( "soak" )
		S.roundRestartAt = now + Config.RoundEndDelay + 5
	end
	if S.roundRestartAt and now >= S.roundRestartAt then roundStart() end
	if not S.finalEnded and not S.roundRestartAt and now >= S.endsAt - 60 then
		S.finalEnded = true
		Round.End( "soak" )
	end

	if now >= S.nextChurn and not S.rejoin and not skipped( "churn" ) then
		S.nextChurn = now + CHURN
		churn()
	end
	if S.rejoin and now >= S.rejoin.at then rejoin() end

	for _, b in ipairs( soakBots() ) do
		local name = b:SteamName()
		if now >= ( S.nextAct[ name ] or 0 ) then
			S.nextAct[ name ] = now + rnd( ACT_MIN, ACT_MAX ) / S.pace
			local ok, err = xpcall( act, debug.traceback, b )
			if not ok then Log.Error( "soak", "bot %s: %s", name, err ) end
		end
	end
end

-- pace > 1 makes bots act that many times more often (for hunting crashes); skip is a set of
-- activity names to leave out: deliver, drop_on_stockpile, open, lock, build, press, violence,
-- items, chat, churn, police, medic, kaiser.
function Soak.Start( minutes, bots, seed, pace, skip )
	if S then return Log.Warn( "soak", "already running" ) end
	seed = seed or os.time()
	math.randomseed( seed )
	file.CreateDir( DIR )
	file.Write( DIR .. "/metrics.csv", CSV_HEAD .. "\n" )
	file.Write( DIR .. "/sched.csv", "t,job,calls,avg_ms,window_max_ms,total_ms\n" )
	file.Delete( DIR .. "/summary.txt" )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:" .. PREFIX .. "%'" )

	local now = CurTime()
	S = {
		minutes = minutes, botCount = bots, seed = seed, pace = pace or 1, skip = skip or {}, startedAt = now, endsAt = now + minutes * 60,
		nextSample = now + 5, nextChurn = now + CHURN, nextAct = {}, counts = {}, rows = {},
		lastNet = { bytes = Net.stats.bytes, messages = Net.stats.messages }, lastSampleAt = SysTime(),
		lastSched = {}, schedAgg = {}, maxFrame = 0,
	}
	for _, name in ipairs( Sched.Names() ) do
		local j = Sched.Get( name )
		S.lastSched[ name ] = { calls = j.calls, total = j.total }
		j.max = 0
	end

	Net.BotsAsClients = true
	Soak.realChangeLevel = Soak.realChangeLevel or Round.ChangeLevel
	Round.ChangeLevel = function()
		Log.Info( "soak", "level change skipped" )
		return false
	end
	DB.stats.windowMaxMs = 0

	for i = 1, bots do addBot( PREFIX .. i ) end
	Sched.Every( "soak", 0.25, Soak.Tick )
	Log.Info( "soak", "started: %d min, %d bots, seed %d", minutes, bots, seed )
end

function Soak.Stop()
	if not S then return end
	S = nil
	Sched.Remove( "soak" )
	Net.BotsAsClients = false
	if Soak.realChangeLevel then Round.ChangeLevel = Soak.realChangeLevel end
end

function Soak.Running() return S ~= nil end

concommand.Add( "gr_soak", function( ply, _, args )
	if IsValid( ply ) then return end -- server console only
	local minutes, bots = tonumber( args[ 1 ] or "" ), tonumber( args[ 2 ] or "" )
	if not minutes or not bots then return print( "usage: gr_soak <minutes> <bots> [seed]" ) end
	Soak.Start( minutes, bots, tonumber( args[ 3 ] or "" ) )
end )

hook.Add( "InitPostEntity", "gr_soak", function()
	local spec = file.Read( "gr_soak.txt", "DATA" )
	if not spec then return end
	file.Delete( "gr_soak.txt" )
	local words = string.Explode( "%s+", string.Trim( spec ), true )
	local minutes, bots = tonumber( words[ 1 ] or "" ), tonumber( words[ 2 ] or "" )
	if not minutes or not bots then return Log.Warn( "soak", "bad gr_soak.txt: %q", spec ) end
	local skip = {}
	for _, w in ipairs( string.Explode( ",", words[ 5 ] or "" ) ) do
		if w ~= "" and w ~= "-" then skip[ w ] = true end
	end
	Soak.Start( minutes, bots, tonumber( words[ 3 ] or "" ), tonumber( words[ 4 ] or "" ), skip )
end )
