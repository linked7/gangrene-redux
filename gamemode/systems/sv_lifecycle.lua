-- Spawning and dying. Everyone spawns as a ghost. A living fate that dies is downed first
-- (sh_corpse.lua); only when that body is beyond help does the final death land here: the
-- fate's cooldown starts and the player comes back as a ghost a moment later.
Lifecycle = Lifecycle or {}
local RESPAWN_DELAY = 3

-- Cooldowns by DB key, so reconnecting doesn't clear a death timer.
local savedCooldowns = {}

function GM:PlayerSpawn( ply )
	ply:UnSpectate()
	local rag = ply.GR_Reviving
	if rag then
		ply.GR_Reviving = nil
		if IsValid( rag ) then return Corpse.Restore( ply, rag ) end
	end
	Fates.Apply( ply, FATE_GHOST, { reason = "spawn" } )
end

-- Respawning is a scheduler job rather than PlayerDeathThink, which bots never run.
function GM:PlayerDeathThink() end

Sched.Every( "respawn", 0.25, function()
	local now = CurTime()
	for _, ply in player.Iterator() do
		if not ply:Alive() and now >= ( ply.GR_RespawnAt or 0 ) then ply:Spawn() end
	end
end )

-- A ghost that dies (ply:Kill from an admin) just respawns; a downed player waits on the body.
hook.Add( "PlayerDeath", "gr_lifecycle", function( ply )
	if not ply.GR_Corpse then ply.GR_RespawnAt = CurTime() + RESPAWN_DELAY end
end )

-- The life is over: start the fate's cooldown and bring the player back as a ghost.
-- Systems that act on a final death (not a downing) listen to GR_FinalDeath( ply, fate ).
function Lifecycle.FinalDeath( ply, fateId )
	ply.GR_RespawnAt = CurTime() + 1
	local f = fateId and Fates.Get( fateId )
	if not f or f.index == FATE_GHOST then return end
	hook.Run( "GR_FinalDeath", ply, f )
	if not f.DeathCooldown then return end

	local untilTime = CurTime() + f.DeathCooldown
	ply[ "SetCooldown_" .. f.id ]( ply, untilTime )
	local saved = savedCooldowns[ DB.Key( ply ) ] or {}
	savedCooldowns[ DB.Key( ply ) ] = saved
	saved[ f.id ] = untilTime
end

hook.Add( "GR_PlayerLoaded", "gr_lifecycle", function( ply )
	for id, untilTime in pairs( savedCooldowns[ DB.Key( ply ) ] or {} ) do
		if untilTime > CurTime() then ply[ "SetCooldown_" .. id ]( ply, untilTime ) end
	end
end )

-- No suicide, for anyone (step 7).
function GM:CanPlayerSuicide( ply )
	return false
end
