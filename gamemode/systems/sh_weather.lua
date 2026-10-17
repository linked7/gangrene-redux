-- Weather (step 5), ported from the original's sh_weather.lua and the cycle in sv_think.lua.
-- Visual only: fog, sky and a chat line. The server owns the cycle and networks the weather id;
-- clients lerp fog towards the target. The sky is painted on the map's env_skypaint server-side
-- (its values are networked entity vars).
-- Cycle: clear 900 +-30 s -> night 100-130 s -> clear (yellow 1/5, else meat 1/6).
-- Ritual and forced weathers hook in later.
Weather = Weather or {}

WEATHER_CLEAR, WEATHER_NIGHT, WEATHER_MEAT, WEATHER_YELLOW = 1, 2, 3, 4

Weather.Current = Weather.Current or WEATHER_CLEAR
Weather.ClearTime = 900 -- tests shorten these
Weather.ClearJitter = 30
Weather.NightMin, Weather.NightMax = 100, 130

Weather.Fog = {
	[ WEATHER_CLEAR ]  = { r = 200, g = 100, b = 200, start = 500, finish = 1000, density = 0 },
	[ WEATHER_NIGHT ]  = { r = 0, g = 0, b = 0, start = 0, finish = 300, density = 1 },
	[ WEATHER_MEAT ]   = { r = 50, g = 0, b = 0, start = 0, finish = 666, density = 1 },
	[ WEATHER_YELLOW ] = { r = 200, g = 175, b = 75, start = 300, finish = 1500, density = 0.4 },
}

Weather.Sky = {
	[ WEATHER_CLEAR ]  = { top = Vector( 0, 0, 0 ), bottom = Vector( 0.1, 0, 0.05 ), dusk = 0.5, stars = "skybox/starfield", starSpeed = 0.1 },
	[ WEATHER_NIGHT ]  = { top = Vector( 0, 0, 0 ), bottom = Vector( 0, 0, 0 ), dusk = 0, stars = "skybox/starfield", starSpeed = 0.1 },
	[ WEATHER_MEAT ]   = { top = Vector( 75, 0, 0 ), bottom = Vector( 50, 0, 0 ), dusk = 0, stars = "models/flesh", starSpeed = 0.3 },
	[ WEATHER_YELLOW ] = { top = Vector( 0.05, 0.025, 0 ), bottom = Vector( 0.392, 0.343, 0.147 ), dusk = 1, stars = "skybox/starfield", starSpeed = 0.1 },
}

Weather.Chat = {
	[ WEATHER_NIGHT ] = { Color( 100, 0, 0 ), { "Darkness falls upon Gangrene!", "Sotla's eye closes. You are alone.", "The hateful sky descends into a dark void.", "The darkest night is upon us.", "The air turns black. The light is gone.", "Night has fallen.", "You hope to see the light of day again." } },
	[ WEATHER_MEAT ] = { Color( 255, 0, 0 ), { "The sky turns red.", "The sky lifts to reveal the rotting flesh it hid.", "Smells like blood.", "Another red day in Gangrene." } },
	[ WEATHER_CLEAR ] = { Color( 200, 0, 100 ), { "The sky returns to its usual acrid smog.", "The air clears.", "Light shines on Gangrene once more.", "The sky is clear. For now." } },
	[ WEATHER_YELLOW ] = { Color( 200, 175, 75 ), { "Rottingham winds blast the city.", "Hot air from the west rolls in.", "The caustic sea blows acrid air over Gangrene.", "Yellow smog engulfs the city." } },
}

if SERVER then
	Net.Pool( "gr_weather" )

	hook.Add( "OnEntityCreated", "gr_weather", function( e )
		if e:GetClass() == "env_skypaint" then Weather.SkyEnt = e end
	end )

	local function paintSky( id )
		local s, sp = Weather.Sky[ id ], Weather.SkyEnt
		if not s or not IsValid( sp ) then return end
		sp:SetTopColor( s.top )
		sp:SetBottomColor( s.bottom )
		sp:SetDuskIntensity( s.dusk )
		sp:SetDuskScale( s.dusk )
		sp:SetSunSize( 0 )
		sp:SetStarTexture( s.stars )
		sp:SetStarScale( 1 )
		sp:SetStarSpeed( s.starSpeed )
	end

	local function send( id, to )
		net.Start( "gr_weather" )
		net.WriteUInt( id, 4 )
		if to then net.Send( to ) else net.Broadcast() end
	end

	function Weather.Set( id )
		if not Weather.Fog[ id ] then return end
		Weather.Current = id
		paintSky( id )
		send( id )
		hook.Run( "GR_WeatherChanged", id )
	end

	-- One step of the original cycle; returns seconds until the next step.
	function Weather.Advance()
		if Weather.Current ~= WEATHER_NIGHT then
			Weather.Set( WEATHER_NIGHT )
			return math.random( Weather.NightMin, Weather.NightMax )
		end
		local nextId = WEATHER_CLEAR
		if math.random( 1, 5 ) == 1 then nextId = WEATHER_YELLOW
		elseif math.random( 1, 6 ) == 1 then nextId = WEATHER_MEAT end
		Weather.Set( nextId )
		return Weather.ClearTime + math.random( -Weather.ClearJitter, Weather.ClearJitter )
	end

	function Weather.Start()
		Weather.Next = CurTime() + Weather.ClearTime + math.random( -Weather.ClearJitter, Weather.ClearJitter )
	end

	Weather.Start()
	Sched.Every( "weather", 1, function()
		if CurTime() < Weather.Next then return end
		Weather.Next = CurTime() + Weather.Advance()
	end )

	hook.Add( "InitPostEntity", "gr_weather", function() paintSky( Weather.Current ) end )
	hook.Add( "GR_PlayerReady", "gr_weather", function( ply ) send( Weather.Current, ply ) end )
else
	local cur = table.Copy( Weather.Fog[ Weather.Current ] )
	local target = Weather.Fog[ Weather.Current ]

	Net.Receive( "gr_weather", function()
		local id = net.ReadUInt( 4 )
		if not Weather.Fog[ id ] or id == Weather.Current then return end
		Weather.Current = id
		target = Weather.Fog[ id ]
		if id == WEATHER_NIGHT then
			surface.PlaySound( "placenta/impendingdoom" .. ( { 1, 2, 4 } )[ math.random( 3 ) ] .. ".wav" )
		end
		local c = Weather.Chat[ id ]
		chat.AddText( c[ 1 ], c[ 2 ][ math.random( #c[ 2 ] ) ] )
	end )

	local function fog()
		local rate = math.min( FrameTime() * 0.25, 1 )
		for k, v in pairs( target ) do cur[ k ] = Lerp( rate, cur[ k ], v ) end
		render.FogMode( MATERIAL_FOG_LINEAR )
		render.FogColor( cur.r, cur.g, cur.b )
		render.FogStart( cur.start )
		render.FogEnd( cur.finish )
		render.FogMaxDensity( cur.density )
		return true
	end
	-- Same hook ids as cl_atmosphere, so weather replaces its static fog (loaded after it).
	hook.Add( "SetupWorldFog", "gr_atmosphere", fog )
	hook.Add( "SetupSkyboxFog", "gr_atmosphere", function() return fog() end )
end
