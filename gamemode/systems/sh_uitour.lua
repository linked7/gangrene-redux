-- UI tour: a hands-free real-client check. With `gr_uitour 1` on the server, every client that
-- joins is walked through the HUD, F2 picker, TAB, F1, the C menu, the lunch machine, its boiler,
-- the stockpile lock, drawing, swinging and holstering a weapon, and chat in every mode, with a
-- `jpeg` screenshot of each (garrysmod/screenshots/), so a client nobody can type into still gets
-- checked. Dev tool only: off by default. The server only moves the player, hands out one of our
-- weapons and takes a fate the normal way; everything else is the client pressing its own keys.

if SERVER then
	local enabled = CreateConVar( "gr_uitour", "0", FCVAR_ARCHIVE, "Walk joining clients through the UI and screenshot it" )
	cvars.AddChangeCallback( "gr_uitour", function( _, _, v ) print( "[gr:uitour] gr_uitour is " .. v ) end, "gr_uitour" )

	-- Stands `ply` `dist` units in front of the nearest `class` and looks at `aim` on it (its centre).
	-- With `spawn`, a class the map lacks is made in front of the player first (frozen, so it stays put).
	local function faceNearest( ply, class, aim, spawn, dist )
		local best, bestD
		for _, ent in ents.Iterator() do -- one-off, dev tool only
			local d = ent:GetClass() == class and ent:GetPos():DistToSqr( ply:GetPos() )
			if d and ( not bestD or d < bestD ) then best, bestD = ent, d end
		end
		local clearDir, spawned
		if not IsValid( best ) and spawn then
			-- Put it in open floor: the first of eight directions with room for the player hull and the entity.
			local origin = ply:GetPos()
			local mins, maxs = ply:GetHullDuck()
			for i = 0, 7 do
				local dir = Angle( 0, i * 45, 0 ):Forward()
				local tr = util.TraceHull( { start = origin + Vector( 0, 0, 4 ), endpos = origin + dir * 200 + Vector( 0, 0, 4 ),
					mins = mins, maxs = maxs, filter = ply } )
				if not tr.Hit and not tr.StartSolid then clearDir = dir break end
			end
			clearDir = clearDir or ply:GetForward()
			local e = ents.Create( class )
			if IsValid( e ) then
				e:SetPos( origin + clearDir * 80 + Vector( 0, 0, 4 ) ) -- close enough to be lit and in frame
				e:SetAngles( Angle( 0, clearDir:Angle().y + 180, 0 ) ) -- its front faces the player
				e:Spawn()
				e:Activate()
				local phys = e:GetPhysicsObject()
				if IsValid( phys ) then phys:EnableMotion( false ) end
				best = e
				spawned = origin
				ply:Flashlight( true ) -- spawned props sit in unlit floor; the torch and a short-lived lamp light the shot
				local lamp = ents.Create( "light_dynamic" )
				if IsValid( lamp ) then
					lamp:SetKeyValue( "_light", "255 240 220 400" )
					lamp:SetKeyValue( "distance", "300" )
					lamp:SetKeyValue( "brightness", "4" )
					lamp:SetPos( origin + clearDir * 40 + Vector( 0, 0, 70 ) )
					lamp:Spawn()
					lamp:Fire( "TurnOn" )
					SafeRemoveEntityDelayed( lamp, 8 )
				end
				print( "[gr:uitour] spawned a " .. class )
			end
		end
		if not IsValid( best ) then
			print( "[gr:uitour] no " .. class .. " on this map" )
			return
		end
		local target = aim and aim( best ) or best:WorldSpaceCenter()
		if spawned then
			ply:SetPos( spawned )
		else
			local spot = best:GetPos() + best:GetForward() * ( dist or 70 )
			spot.z = best:GetPos().z
			ply:SetPos( spot )
		end
		ply:SetEyeAngles( ( target - ply:EyePos() ):Angle() )
	end

	-- name -> { class, aim, spawn, dist }
	local function centre( e ) return e:LocalToWorld( e:OBBCenter() ) end
	local TARGET = {
		fate_station = { "fate_station" },
		lunch_machine = { "lunch_machine", function( m ) return m:LocalToWorld( Vector( 13, 4, 18 ) ) end }, -- the button row
		lunch_machine_far = { "lunch_machine", centre, false, 140 },
		line_boiler = { "line_boiler", function( b ) return Lunch.HandlePos( b, "vent" ) end },
		boiler_build = { "line_boiler", function( b ) return Lunch.HandlePos( b, "build" ) end },
		boiler_dial = { "line_boiler", centre, false, 110 },
		state_stockpile = { "state_stockpile", centre, true },
		water_barrel = { "water_barrel", centre, true },
		bone_capsule = { "bone_capsule", centre, true },
		meat_chunk = { "meat_chunk", centre, true },
		storage_crate = { "storage_crate", centre, true },
	}

	hook.Add( "GR_PlayerReady", "gr_uitour", function( ply )
		if not enabled:GetBool() or ply:IsBot() then return end
		timer.Simple( 6, function() if IsValid( ply ) then ply:ConCommand( "gr_uitour_run" ) end end )
	end )

	concommand.Add( "gr_uitour_face", function( ply, _, args )
		local class = args[ 1 ] or "fate_station"
		local t = TARGET[ class ]
		if IsValid( ply ) and enabled:GetBool() and t then faceNearest( ply, t[ 1 ], t[ 2 ], t[ 3 ], t[ 4 ] ) end
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
	{ "09b_boiler_black_wheel", function() RunConsoleCommand( "gr_uitour_face", "boiler_build" ) end },
	{ "09c_boiler_dial", function() RunConsoleCommand( "gr_uitour_face", "boiler_dial" ) end },
	{ "09d_boiler_red_wheel_turning", function()
		RunConsoleCommand( "gr_uitour_face", "line_boiler" )
		timer.Simple( 0.5, function() press( "use", 3 ) end )
	end, 2 },
	{ "09e_lunch_machine_far", function() RunConsoleCommand( "gr_uitour_face", "lunch_machine_far" ) end },
	{ "09f_water_barrel", function() RunConsoleCommand( "gr_uitour_face", "water_barrel" ) end },
	{ "09g_bone_capsule", function() RunConsoleCommand( "gr_uitour_face", "bone_capsule" ) end },
	{ "09h_meat_chunk", function() RunConsoleCommand( "gr_uitour_face", "meat_chunk" ) end },
	{ "09i_storage_crate", function() RunConsoleCommand( "gr_uitour_face", "storage_crate" ) end },
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
