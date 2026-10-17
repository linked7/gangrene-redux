-- Damage pipeline (D4). Every hit on a player runs these stages in order; fates and items add
-- hooks to a stage instead of editing one huge EntityTakeDamage.
--
--   Damage.Add( stage, id, fn( ply, dmg, ctx ) )   stage: "Scale", "Armor", "Consciousness", "Health"
--
-- ctx.hitgroup is the body part hit. A hook may change dmg; returning true blocks the hit.
-- The Health stage applies non-lethal damage itself, so the engine's own armor rules never run.
-- Lethal damage goes through to the engine, which kills the player (GM:DoPlayerDeath downs them,
-- never killing outright; see sh_corpse.lua for wounded and dying).
Damage = Damage or {}
Damage.STAGES = { "Scale", "Armor", "Consciousness", "Health" }

local stages = {}
for _, name in ipairs( Damage.STAGES ) do stages[ name ] = {} end

function Damage.Add( stage, id, fn )
	local list = stages[ stage ]
	if not list then error( "Damage.Add: unknown stage " .. tostring( stage ), 2 ) end
	for _, h in ipairs( list ) do
		if h.id == id then h.fn = fn return end
	end
	table.insert( list, { id = id, fn = fn } )
end

function Damage.Remove( stage, id )
	local list = stages[ stage ]
	for i, h in ipairs( list ) do
		if h.id == id then table.remove( list, i ) return end
	end
end

-- The engine scales by hitgroup before EntityTakeDamage; we only record where the hit landed.
function GM:ScalePlayerDamage( ply, hitgroup )
	ply.GR_LastHitGroup = hitgroup
end

hook.Add( "EntityTakeDamage", "gr_damage", function( ply, dmg )
	if not ply:IsPlayer() then return end
	-- The pipeline applies health itself, so it must honour the usual veto (ghosts take none).
	if hook.Run( "PlayerShouldTakeDamage", ply, dmg:GetAttacker() ) == false then return true end
	local ctx = { hitgroup = ply.GR_LastHitGroup or HITGROUP_GENERIC }
	ply.GR_LastHitGroup = nil

	for _, stage in ipairs( Damage.STAGES ) do
		for _, h in ipairs( stages[ stage ] ) do
			local ok, block = xpcall( h.fn, debug.traceback, ply, dmg, ctx )
			if not ok then
				Log.Error( "damage", "%s/%s: %s", stage, h.id, block )
			elseif block then
				return true
			end
		end
	end
end )

-- Default hooks -----------------------------------------------------------------------------

local HITGROUP_SCALE = {
	[ HITGROUP_HEAD ] = 2,
	[ HITGROUP_LEFTARM ] = 0.5, [ HITGROUP_RIGHTARM ] = 0.5,
	[ HITGROUP_LEFTLEG ] = 0.5, [ HITGROUP_RIGHTLEG ] = 0.5,
}
Damage.Add( "Scale", "hitgroup", function( ply, dmg, ctx )
	local s = HITGROUP_SCALE[ ctx.hitgroup ]
	if s then dmg:ScaleDamage( s ) end
end )

-- A fate may take more or less damage: DamageTaken = 0.8.
Damage.Add( "Scale", "fate", function( ply, dmg )
	local s = ply:FateHas( "DamageTaken" )
	if s then dmg:ScaleDamage( s ) end
end )

-- A player weak from hunger or thirst hits softer (step 6).
Damage.Add( "Scale", "weakness", function( ply, dmg )
	local attacker = dmg:GetAttacker()
	if IsValid( attacker ) and attacker:IsPlayer() and attacker.GR_Needs then
		dmg:ScaleDamage( Needs.WeakScale( attacker, Needs.WEAK_DAMAGE ) )
	end
end )

-- Armor soaks most of a hit and wears down by what it soaks. Falls and drowning go around it.
local ARMOR_SOAK = 0.6
local ARMOR_BYPASS = bit.bor( DMG_FALL, DMG_DROWN, DMG_POISON, DMG_RADIATION )
Damage.Add( "Armor", "armor", function( ply, dmg )
	local armor = ply:Armor()
	if armor <= 0 or bit.band( dmg:GetDamageType(), ARMOR_BYPASS ) ~= 0 then return end
	local soaked = math.min( dmg:GetDamage() * ARMOR_SOAK, armor )
	ply:SetArmor( armor - math.ceil( soaked ) )
	dmg:SubtractDamage( soaked )
end )

Damage.Add( "Health", "apply", function( ply, dmg )
	local amount = dmg:GetDamage()
	if amount <= 0 then return true end
	if amount < ply:Health() then
		ply:SetHealth( ply:Health() - math.ceil( amount ) )
		return true
	end
	-- Lethal: let the engine kill with this attacker and inflictor. GM:DoPlayerDeath downs the
	-- player, wounded or dying by how far past 0 HP this hit went (sh_corpse.lua).
	Corpse.NoteLethalHit( ply, amount - ply:Health(), dmg:GetAttacker() )
	ply:SetArmor( 0 )
end )
