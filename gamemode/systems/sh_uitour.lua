-- UI tour: a hands-free real-client check. With `gr_uitour 1` on the server, every client that
-- joins is walked through the HUD, F2 picker, TAB, F1, the C menu, the lunch machine, its boiler,
-- the stockpile lock, drawing, swinging and holstering a weapon, and chat in every mode, with a
-- `jpeg` screenshot of each (garrysmod/screenshots/), so a client nobody can type into still gets
-- checked. Dev tool only: off by default. The server only moves the player, hands out one of our
-- weapons and takes a fate the normal way; everything else is the client pressing its own keys.

if SERVER then
	local enabled = CreateConVar( "gr_uitour", "0", FCVAR_ARCHIVE, "Walk joining clients through the UI and screenshot it" )
	cvars.AddChangeCallback( "gr_uitour", function( _, _, v ) print( "[gr:uitour] gr_uitour is " .. v ) end, "gr_uitour" )

	-- Stands `ply` 70 units in front of the nearest `class` and looks at `aim` on it (its centre).
	local function faceNearest( ply, class, aim )
		local best, bestD
		for _, ent in ents.Iterator() do -- one-off, dev tool only
			local d = ent:GetClass() == class and ent:GetPos():DistToSqr( ply:GetPos() )
			if d and ( not bestD or d < bestD ) then best, bestD = ent, d end
		end
		if not IsValid( best ) then
			print( "[gr:uitour] no " .. class .. " on this map" )
			return
		end
		local target = aim and aim( best ) or best:WorldSpaceCenter()
		local spot = best:GetPos() + best:GetForward() * 70
		spot.z = best:GetPos().z
		ply:SetPos( spot )
		ply:SetEyeAngles( ( target - ply:EyePos() ):Angle() )
	end

	local AIM = {
		lunch_machine = function( m ) return m:LocalToWorld( Vector( 13, 4, 18 ) ) end, -- the button row
		line_boiler = function( b ) return Lunch.HandlePos( b, "vent" ) end,
	}
	local FACE = { fate_station = true, lunch_machine = true, line_boiler = true, state_stockpile = true }

	hook.Add( "GR_PlayerReady", "gr_uitour", function( ply )
		if not enabled:GetBool() or ply:IsBot() then return end
		timer.Simple( 6, function() if IsValid( ply ) then ply:ConCommand( "gr_uitour_run" ) end end )
	end )

	concommand.Add( "gr_uitour_face", function( ply, _, args )
		local class = args[ 1 ] or "fate_station"
		if IsValid( ply ) and enabled:GetBool() and FACE[ class ] then faceNearest( ply, class, AIM[ class ] ) end
	end )

	-- One of the remake's weapons, in hand and holstered.
	concommand.Add( "gr_uitour_give", function( ply, _, args )
		local class = args[ 1 ] or ""
		if not IsValid( ply ) or not enabled:GetBool() or not ply:Alive() or ply:IsGhost() then return end
		local def = weapons.Get( class )
		if not def or not def.GR_Base then return end
		if not ply:HasWeapon( class ) then ply:Give( class ) end
		ply:SelectWeapon( class )
	end )
	return
end

local function press( cmd, hold )
	RunConsoleCommand( "+" .. cmd )
	timer.Simple( hold, function() RunConsoleCommand( "-" .. cmd ) end )
end

-- Lines said one after another, half a second apart.
local function sayAll( lines )
	for i, line in ipairs( lines ) do
		timer.Simple( ( i - 1 ) * 0.5, function() RunConsoleCommand( line[ 1 ], line[ 2 ] ) end )
	end
end

-- { name, fn, shot }: shot is when the screenshot is taken, seconds after fn (default 3).
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
		RunConsoleCommand( "gr_uitour_face", "fate_station" )
		timer.Simple( 1, function() hook.Run( "OnContextMenuOpen" ) end )
	end },
	{ "07_lunch_machine", function()
		hook.Run( "OnContextMenuClose" )
		CloseDermaMenus()
		RunConsoleCommand( "gr_uitour_face", "lunch_machine" )
	end },
	{ "08_boiler", function() RunConsoleCommand( "gr_uitour_face", "line_boiler" ) end },
	{ "09_stockpile_lock", function() RunConsoleCommand( "gr_uitour_face", "state_stockpile" ) end },
	{ "10_hands_drawn", function() RunConsoleCommand( "rp_toggleholster" ) end },
	{ "11_hands_swing", function() press( "attack", 0.1 ) end, 0.4 },
	{ "12_hands_holstered", function() RunConsoleCommand( "rp_toggleholster" ) end },
	{ "13_baton_drawn", function()
		RunConsoleCommand( "gr_uitour_give", "weapon_gr_baton" )
		timer.Simple( 1, function() RunConsoleCommand( "rp_toggleholster" ) end )
	end },
	{ "14_baton_heavy_swing", function() press( "attack", 0.8 ) end, 1 },
	{ "15_baton_block", function() press( "attack2", 3.5 ) end, 2 },
	{ "16_baton_holstered", function() RunConsoleCommand( "rp_toggleholster" ) end },
	{ "17_chat_ic", function()
		sayAll( {
			{ "say", "hello there" },
			{ "say", "/y look out" },
			{ "say", "/w psst" },
			{ "say", "/me looks around." },
		} )
	end },
	{ "18_chat_ooc", function()
		sayAll( {
			{ "say", ".// local ooc line" },
			{ "say", "// global ooc line" },
			{ "say", "/r radio check" },
			{ "say_team", "team chat is radio" },
			{ "say", "/a staff line" },
			{ "say", "/pm " .. LocalPlayer():SteamName() .. " a private note" },
			{ "say", "/roll" },
		} )
	end, 4 },
	{ "19_done", function() RunConsoleCommand( "gr_uitour_face", "fate_station" ) end },
}

concommand.Add( "gr_uitour_run", function()
	print( "[gr:uitour] start" )
	for i, step in ipairs( steps ) do
		timer.Simple( i * 5, function()
			local ok, err = pcall( step[ 2 ] )
			print( "[gr:uitour] " .. step[ 1 ] .. ( ok and "" or ( " FAILED: " .. tostring( err ) ) ) )
			timer.Simple( step[ 3 ] or 3, function() RunConsoleCommand( "jpeg", "gr_" .. step[ 1 ] ) end )
		end )
	end
	timer.Simple( #steps * 5 + 5, function() print( "[gr:uitour] end" ) end )
end )
