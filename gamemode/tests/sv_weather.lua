-- Weather cycle: clear -> night -> clear/yellow/meat, with shortened timers.
return function( T )
	T.Check( Weather and Weather.Set, "Weather loaded" )
	T.Check( Sched.Get( "weather" ) ~= nil, "weather Sched job registered" )
	local seen = {}
	hook.Add( "GR_WeatherChanged", "test_weather", function( id ) seen[ #seen + 1 ] = id end )

	Weather.ClearTime, Weather.ClearJitter, Weather.NightMin, Weather.NightMax = 3, 0, 2, 2
	Weather.Set( WEATHER_CLEAR )
	Weather.Start()
	seen = {}
	T.Wait( 4.5 )
	T.Equal( Weather.Current, WEATHER_NIGHT, "clear turns to night" )
	T.Wait( 3 )
	T.Check( Weather.Current ~= WEATHER_NIGHT, "night ends after its duration" )
	T.Check( Weather.Fog[ Weather.Current ] ~= nil, "post-night weather is valid" )

	-- Distribution of the post-night pick.
	local counts = { 0, 0, 0, 0 }
	for i = 1, 600 do
		Weather.Current = WEATHER_NIGHT
		local dur = Weather.Advance()
		counts[ Weather.Current ] = counts[ Weather.Current ] + 1
		if i == 1 then T.Equal( dur, 3, "clear duration" ) end
	end
	T.Equal( counts[ WEATHER_NIGHT ], 0, "night never follows night" )
	T.Check( counts[ WEATHER_YELLOW ] > 60 and counts[ WEATHER_MEAT ] > 30 and counts[ WEATHER_CLEAR ] > 300,
		"clear/yellow/meat all reachable" )
	local d = Weather.Advance()
	T.Equal( Weather.Current, WEATHER_NIGHT, "non-night advances to night" )
	T.Equal( d, 2, "night duration" )

	hook.Remove( "GR_WeatherChanged", "test_weather" )
	Weather.ClearTime, Weather.ClearJitter, Weather.NightMin, Weather.NightMax = 900, 30, 100, 130
	Weather.Set( WEATHER_CLEAR )
	Weather.Start()
end
