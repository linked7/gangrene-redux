-- Locks (step 11.1): there is no timed pry; a lock is beaten open, and loudly.
--
--   A lock's Integrity is PUBLIC on its entity (NetworkVar "Integrity") and drawn as a bar under the
--   crosshair when you look at it. Every melee hit or bullet from a player who may beat it takes
--   Locks.PER_HIT, whatever the weapon, with a heavy clang that carries across streets and a small
--   screen shake nearby. After Locks.IDLE s without a hit it recovers Locks.RECOVER a second.
--
--   state_stockpile  beaten by anyone without StockpileAccess (about 40 baton hits). The first hit
--                    raises the state-radio alarm (Crime.Report "lock_alarm") and starts a klaxon,
--                    which rings until Locks.KLAXON_TAIL s after the lock breaks or recovers fully.
--                    Breaking it drops Locks.LOOT rations from the stock and is a break-in
--                    (Crime.Report "break_in"); the lock re-forms whole Locks.REFORM s later.
--   storage_crate    only while locked, by anyone but its builder (about 15 hits). Breaking it
--                    unlocks it and is theft (Storage.BreakOpen). No klaxon, no alarm.
--
-- Hits arrive through their own EntityTakeDamage hook: the Damage pipeline (sv_damage.lua) only
-- handles players. Recovery, re-forming and the klaxon run from one scheduler job over a registry.
--
--   Locks.Register( ent )            ENT:Initialize of a lock-bearing class; sets a whole lock
--   Locks.Max( ent ), Locks.HasLock( ent ), Locks.CanBeat( ply, ent )   shared
--   Locks.Hit( ent, ply ) -> ok      one blow (server); Locks.Reset( ent ), Locks.Tick()
--   Locks.IsBlow( dmg ) -> bool      a melee hit or a bullet
--   Locks.KlaxonOn( ent ) -> bool
Locks = Locks or {}

Locks.PER_HIT = 1
Locks.IDLE = 10          -- seconds without a hit before a lock starts to recover
Locks.RECOVER = 1        -- Integrity a second while recovering
Locks.REFORM = 120       -- seconds until a broken stockpile lock is whole again
Locks.KLAXON_TAIL = 30   -- the klaxon rings this long after the lock breaks or recovers fully
Locks.LOOT = 3           -- rations a broken stockpile drops
Locks.SNDLVL = 140       -- the clang carries across several streets
Locks.KLAXON_SNDLVL = 110
Locks.SHAKE_RADIUS = 600
Locks.SHOW_RANGE = 200   -- the bar shows when you look at a lock this close

Locks.KINDS = {
	state_stockpile = {
		max = 40,
		label = "Stockpile lock",
		klaxon = true,
		canBeat = function( ply ) return not ply:FateHas( "StockpileAccess" ) end,
		hasLock = function( ent ) return ent:GetIntegrity() > 0 end,
	},
	storage_crate = {
		max = 15,
		label = "Crate lock",
		canBeat = function( ply, ent ) return not Build.IsBuilder( ply, ent ) end,
		hasLock = function( ent ) return ent:GetLocked() end,
	},
}

local function kindOf( ent ) return IsValid( ent ) and Locks.KINDS[ ent:GetClass() ] or nil end

function Locks.Max( ent )
	local def = kindOf( ent )
	return def and def.max or 0
end

function Locks.HasLock( ent )
	local def = kindOf( ent )
	return def ~= nil and def.hasLock( ent ) == true
end

function Locks.CanBeat( ply, ent )
	local def = kindOf( ent )
	if not def or not IsValid( ply ) or not ply:IsPlayer() or not ply:Alive() or ply:IsGhost() then return false end
	return def.canBeat( ply, ent ) == true
end

if CLIENT then
	-- The cross-texts (cl_crosshair.lua): the lock's name and an Integrity bar under the entity's own.
	hook.Add( "GR_CrossTexts", "gr_locks", function( ent, me, ct )
		local def = kindOf( ent )
		if not def or me:GetPos():DistToSqr( ent:GetPos() ) > Locks.SHOW_RANGE * Locks.SHOW_RANGE then return end
		local broken = not def.hasLock( ent )
		if broken and not def.klaxon then return end -- an unlocked crate has no lock to show
		table.insert( ct, { text = broken and def.label .. ": broken" or def.label, bar = broken and 0 or math.Clamp( ent:GetIntegrity() / math.max( def.max, 1 ), 0, 1 ) } )
	end )
	return
end

-- Registry: every lock-bearing entity, so the scheduler never searches the world (P2).
local locks = setmetatable( {}, { __mode = "k" } )

function Locks.All() return locks end

function Locks.Register( ent )
	if not kindOf( ent ) then return end
	locks[ ent ] = true
	ent:SetIntegrity( Locks.Max( ent ) )
end

local KLAXON = "ambient/alarms/alarm_citizen_loop1.wav"
local CLANGS = {
	"physics/metal/metal_box_impact_hard1.wav",
	"physics/metal/metal_box_impact_hard2.wav",
	"physics/metal/metal_box_impact_hard3.wav",
}

function Locks.KlaxonOn( ent ) return ent.GR_Klaxon ~= nil end

local function klaxon( ent, on )
	if on then
		ent.GR_KlaxonStop = nil
		if ent.GR_Klaxon then return end
		ent.GR_Klaxon = CreateSound( ent, KLAXON )
		ent.GR_Klaxon:SetSoundLevel( Locks.KLAXON_SNDLVL )
		ent.GR_Klaxon:Play()
	elseif ent.GR_Klaxon then
		ent.GR_Klaxon:Stop()
		ent.GR_Klaxon, ent.GR_KlaxonStop = nil, nil
	end
end

-- A whole lock again: full Integrity, nothing pending, no klaxon.
function Locks.Reset( ent )
	if not kindOf( ent ) then return end
	ent:SetIntegrity( Locks.Max( ent ) )
	ent.GR_ReformAt, ent.GR_LastHit = nil, nil
	klaxon( ent, false )
end

-- What breaking each kind does.
local function breakStockpile( ent, ply )
	local now = CurTime()
	ent.GR_ReformAt = now + Locks.REFORM
	ent.GR_KlaxonStop = now + Locks.KLAXON_TAIL
	local n = Econ.TakeStock( Econ.BREAD, Locks.LOOT )
	local base = ent:GetPos() + ent:GetForward() * 40 + Vector( 0, 0, 20 )
	for i = 1, n do Items.Spawn( Econ.BREAD, 1, base + Vector( 0, ( i - 2 ) * 12, 0 ) ) end
	Notify( ply, n > 0 and "The lock gives way." or "The lock gives way. The stockpile is empty." )
	Crime.Report( ply, "break_in", { pos = ent:GetPos() } )
end

local BREAK = {
	state_stockpile = breakStockpile,
	storage_crate = function( ent, ply ) Storage.BreakOpen( ply, ent ) end,
}

-- One blow on `ent`'s lock by `ply`. Returns true if it counted.
function Locks.Hit( ent, ply )
	if not locks[ ent ] or not Locks.HasLock( ent ) or not Locks.CanBeat( ply, ent ) then return false end
	local def = kindOf( ent )
	local before = ent:GetIntegrity()
	local left = math.max( before - Locks.PER_HIT, 0 )
	ent:SetIntegrity( left )
	ent.GR_LastHit = CurTime()

	local pos = ent:GetPos()
	ent:EmitSound( CLANGS[ math.random( #CLANGS ) ], Locks.SNDLVL, math.random( 85, 100 ) )
	util.ScreenShake( pos, 3, 20, 0.4, Locks.SHAKE_RADIUS )

	if def.klaxon and before >= def.max then
		-- The first hit on a whole lock: the state radio hears of it and the klaxon starts.
		Crime.Report( ply, "lock_alarm", { pos = pos } )
		klaxon( ent, true )
	elseif def.klaxon then
		ent.GR_KlaxonStop = nil -- still being beaten: keep ringing
		klaxon( ent, true )
	end
	if left <= 0 then BREAK[ ent:GetClass() ]( ent, ply ) end
	return true
end

-- Melee and bullets count, whatever the weapon; fire, falls, blasts and thrown props don't.
local BLOWS = bit.bor( DMG_BULLET, DMG_BUCKSHOT, DMG_CLUB, DMG_SLASH )
function Locks.IsBlow( dmg )
	local t = dmg:GetDamageType()
	return t == DMG_GENERIC or bit.band( t, BLOWS ) ~= 0
end

-- Locks aren't players, so they don't go through the Damage pipeline (sv_damage.lua).
hook.Add( "EntityTakeDamage", "gr_locks", function( ent, dmg )
	if not locks[ ent ] or not Locks.IsBlow( dmg ) then return end
	Locks.Hit( ent, dmg:GetAttacker() )
end )

-- Once a second: recover idle locks, re-form broken ones, and stop klaxons whose time is up.
function Locks.Tick()
	local now = CurTime()
	for ent in pairs( locks ) do
		if not IsValid( ent ) then
			locks[ ent ] = nil
		else
			local def = kindOf( ent )
			local n = ent:GetIntegrity()
			if ent.GR_ReformAt then
				if now >= ent.GR_ReformAt then
					ent.GR_ReformAt = nil
					ent:SetIntegrity( def.max )
				end
			elseif n < def.max and def.hasLock( ent ) and now - ( ent.GR_LastHit or 0 ) >= Locks.IDLE then
				n = math.min( n + Locks.RECOVER, def.max )
				ent:SetIntegrity( n )
				if n >= def.max and ent.GR_Klaxon then ent.GR_KlaxonStop = now + Locks.KLAXON_TAIL end
			end
			if ent.GR_KlaxonStop and now >= ent.GR_KlaxonStop then klaxon( ent, false ) end
		end
	end
end
Sched.Every( "locks", 1, Locks.Tick )

-- A new round starts with whole locks and silence.
hook.Add( "GR_RoundStart", "gr_locks", function()
	for ent in pairs( locks ) do
		if IsValid( ent ) and ent:GetClass() == "state_stockpile" then Locks.Reset( ent ) end
	end
end )
