-- UI tour: a hands-free real-client check. With `gr_uitour 1` on the server, every client that
-- joins is walked through the HUD, F2 picker, TAB, F1 and the C menu, with a `jpeg` screenshot of
-- each (garrysmod/screenshots/), so a client nobody can type into still gets checked. Dev tool only:
-- off by default, and the server only ever moves the player and takes a fate the normal way.

if SERVER then
	local enabled = CreateConVar( "gr_uitour", "0", FCVAR_ARCHIVE, "Walk joining clients through the UI and screenshot it" )

	local function faceNearest( ply )
		local best, bestD
		for _, ent in ipairs( ents.FindInSphere( ply:GetPos(), 3000 ) ) do -- one-off, dev tool only
			if ent:GetClass() == "fate_station" then
				local d = ent:GetPos():DistToSqr( ply:GetPos() )
				if not bestD or d < bestD then best, bestD = ent, d end
			end
		end
		if not IsValid( best ) then return end
		local spot = best:GetPos() + best:GetForward() * 70
		ply:SetPos( spot )
		ply:SetEyeAngles( ( best:WorldSpaceCenter() - ply:EyePos() ):Angle() )
	end

	hook.Add( "GR_PlayerReady", "gr_uitour", function( ply )
		if not enabled:GetBool() or ply:IsBot() then return end
		timer.Simple( 6, function() if IsValid( ply ) then ply:ConCommand( "gr_uitour_run" ) end end )
	end )

	concommand.Add( "gr_uitour_face", function( ply )
		if IsValid( ply ) and enabled:GetBool() then faceNearest( ply ) end
	end )
	return
end

local steps = {
	{ "01_ghost_hud", function() end },
	{ "02_fate_picker", function() if not vgui.GetKeyboardFocus() then RunConsoleCommand( "gr_fates" ) end end },
	{ "03_alive_hud", function()
		RunConsoleCommand( "gr_fates" ) -- closes the picker
		net.Start( "gr_take_fate" ) net.WriteString( "prole" ) net.SendToServer()
	end },
	{ "04_scoreboard", function() hook.Run( "ScoreboardShow" ) end },
	{ "05_help", function() hook.Run( "ScoreboardHide" ) RunConsoleCommand( "gr_help" ) end },
	{ "06_context_menu", function()
		RunConsoleCommand( "gr_help" )
		RunConsoleCommand( "gr_uitour_face" )
		timer.Simple( 1, function() hook.Run( "OnContextMenuOpen" ) end )
	end },
	{ "07_done", function() hook.Run( "OnContextMenuClose" ) CloseDermaMenus() end },
}

concommand.Add( "gr_uitour_run", function()
	print( "[gr:uitour] start" )
	for i, step in ipairs( steps ) do
		timer.Simple( i * 5, function()
			local ok, err = pcall( step[ 2 ] )
			print( "[gr:uitour] " .. step[ 1 ] .. ( ok and "" or ( " FAILED: " .. tostring( err ) ) ) )
			timer.Simple( 3, function() RunConsoleCommand( "jpeg", "gr_" .. step[ 1 ] ) end )
		end )
	end
	timer.Simple( #steps * 5 + 5, function() print( "[gr:uitour] end" ) end )
end )
