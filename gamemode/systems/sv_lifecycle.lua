-- Spawning and dying. Everyone spawns as a ghost; dying in a fate starts that fate's cooldown,
-- and the player comes back as a ghost a few seconds later.
-- Step 7 replaces the plain death with downed / bleed-out / revive.
local RESPAWN_DELAY = 3

-- Cooldowns by DB key, so reconnecting doesn't clear a death timer.
local savedCooldowns = {}

function GM:PlayerSpawn( ply )
	ply:UnSpectate()
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

hook.Add( "PlayerDeath", "gr_lifecycle", function( ply )
	ply.GR_RespawnAt = CurTime() + RESPAWN_DELAY
	local f = ply:GetFateDef()
	if not f or f.index == FATE_GHOST or not f.DeathCooldown then return end

	local untilTime = CurTime() + f.DeathCooldown
	ply[ "SetCooldown_" .. f.id ]( ply, untilTime )
	local saved = savedCooldowns[ DB.Key( ply ) ] or {}
	savedCooldowns[ DB.Key( ply ) ] = saved
	saved[ f.id ] = untilTime
end )

hook.Add( "GR_PlayerLoaded", "gr_lifecycle", function( ply )
	for id, untilTime in pairs( savedCooldowns[ DB.Key( ply ) ] or {} ) do
		if untilTime > CurTime() then ply[ "SetCooldown_" .. id ]( ply, untilTime ) end
	end
end )

function GM:CanPlayerSuicide( ply )
	return not ply:IsGhost()
end
