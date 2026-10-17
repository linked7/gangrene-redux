-- Ghost rules: ghosts can't be hurt, can't touch the world except fate stations, are seen and
-- heard only by other ghosts, and make no footsteps. Suffering and haunting are deferred.
-- Ghost text chat is routed by sh_chat.lua (Chat.Recipients); voice stays here.

-- Footsteps (docs/05 §11, the original's GM:PlayerFootstep): ghosts make none; anyone else gets
-- the engine's step plus their fate's own Footstep( ply, foot ), played from the server.
hook.Add( "PlayerFootstep", "gr_ghost", function( ply, pos, foot )
	if ply:IsGhost() then return true end
	if SERVER then
		local step = ply:FateHas( "Footstep" )
		if isfunction( step ) then step( ply, foot ) end
	end
end )

if CLIENT then
	hook.Add( "PrePlayerDraw", "gr_ghost", function( ply )
		if ply:IsGhost() and not LocalPlayer():IsGhost() then return true end
	end )
	return
end

hook.Add( "PlayerShouldTakeDamage", "gr_ghost", function( ply )
	if ply:IsGhost() then return false end
end )

hook.Add( "PlayerUse", "gr_ghost", function( ply, ent )
	if ply:IsGhost() and ent:GetClass() ~= "fate_station" then return false end
end )

hook.Add( "PlayerCanPickupWeapon", "gr_ghost", function( ply )
	if ply:IsGhost() then return false end
end )

hook.Add( "PlayerCanPickupItem", "gr_ghost", function( ply )
	if ply:IsGhost() then return false end
end )

hook.Add( "PlayerCanHearPlayersVoice", "gr_ghost", function( listener, speaker )
	if speaker:IsGhost() and not listener:IsGhost() then return false end
end )
