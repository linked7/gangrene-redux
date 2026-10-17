-- Step 15b: the client UI's server side. The fate menu's gr_take_fate receiver (only ghosts get
-- through; Fates.Request re-checks with CanTake and returns its reason), every field the HUD and
-- the menu read reaches the client, and every client file is listed and sent.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t15b_%'" )

	local function bot( name, rank, stem )
		local b = player.CreateNextBot( "t15b_" .. name )
		b:SetRank( rank )
		b:SetStemCells( stem or 0 )
		return b
	end

	-- The receiver -------------------------------------------------------------------------------

	local r = Net.Receivers.gr_take_fate
	T.Check( r ~= nil and net.Receivers.gr_take_fate ~= nil, "gr_take_fate is a registered receiver" )
	T.Check( r and r.opts.ghost == true, "only ghosts get through it" )
	T.Check( r and r.rate > 0 and r.rate <= 4, "and it is rate-limited: " .. tostring( r and r.rate ) )

	local ghost = bot( "ghost", RANK_FRIEND, 1 )
	local fool = bot( "fool", RANK_FOOLISH, 5 )
	local poor = bot( "poor", RANK_FRIEND, 0 )
	T.Wait( 0.3 )
	T.Check( ghost:IsGhost() and fool:IsGhost() and poor:IsGhost(), "the bots start as ghosts" )

	local ok, why = Fates.Request( ghost, "prole" )
	T.Check( ok, "a ghost takes prole through the menu path" )
	T.Equal( why, nil, "with no reason given" )
	T.Equal( ghost:GetFateDef().id, "prole", "and is a prole" )
	T.Equal( ghost:GetStemCells(), 0, "the cost is charged" )

	local canOk, canWhy = Fates.CanTake( ghost, "korpsman" )
	ok, why = Fates.Request( ghost, "korpsman" )
	T.Check( not ok and not canOk, "a living player is refused" )
	T.Equal( why, canWhy, "with CanTake's reason: " .. tostring( why ) )
	T.Equal( ghost:GetFateDef().id, "prole", "and keeps their fate" )

	canOk, canWhy = Fates.CanTake( fool, "prole" )
	ok, why = Fates.Request( fool, "prole" )
	T.Check( not ok and not canOk, "a Foolish ghost is refused prole" )
	T.Equal( why, canWhy, "with CanTake's reason: " .. tostring( why ) )
	T.Check( fool:IsGhost(), "and stays a ghost" )
	T.Check( Fates.Request( fool, "slave" ), "but may take slave" )

	canOk, canWhy = Fates.CanTake( poor, "sanitar" )
	ok, why = Fates.Request( poor, "sanitar" )
	T.Check( not ok and isstring( why ) and why == canWhy, "too few stem cells: " .. tostring( why ) )
	T.Check( not Fates.Request( poor, "ghost" ) and not Fates.Request( poor, "nonsense" ), "ghost and unknown ids are refused" )
	T.Check( not Fates.Request( poor, nil ) and not Fates.Request( poor, 5 ), "so is a missing or non-string id" )
	T.Check( poor:IsGhost() and poor:GetStemCells() == 0, "nothing changed for the refused ghost" )

	-- What the client can see ----------------------------------------------------------------------

	local needed = { "Fate", "CharName", "Rank", "StemCells", "Bones", "Injured", "Bullet", "Wanted", "WantedUntil",
		"WantedReason", "Teeth", "PassedOut" }
	for _, name in ipairs( Needs.All() ) do table.insert( needed, "Need_" .. name ) end
	for _, f in ipairs( Fates.All() ) do table.insert( needed, "Cooldown_" .. f.id ) end
	for _, name in ipairs( needed ) do
		local f = State.FieldByName( name )
		T.Check( f ~= nil and f.scope ~= State.SERVER, name .. " reaches its owner's client" )
	end
	for _, name in ipairs( { "Fate", "CharName", "Rank" } ) do
		T.Equal( State.FieldByName( name ).scope, State.PUBLIC, name .. " is public (scoreboard, CanTake slot counts)" )
	end
	for _, name in ipairs( { "Bones", "StemCells" } ) do
		T.Equal( State.FieldByName( name ).scope, State.OWNER, name .. " is the owner's alone" )
	end

	-- Client files ----------------------------------------------------------------------------------

	local root = GAMEMODE.FolderName .. "/gamemode/"
	local manifest = include( GAMEMODE.FolderName .. "/gamemode/manifest.lua" )
	for _, dir in ipairs( { "core", "systems" } ) do
		local listed = {}
		for _, name in ipairs( manifest[ dir ] ) do listed[ name ] = true end
		for _, name in ipairs( file.Find( root .. dir .. "/cl_*.lua", "LUA" ) ) do
			T.Check( listed[ name ], dir .. "/" .. name .. " is in the manifest" )
			T.Check( Loader.Sent[ root .. dir .. "/" .. name ], dir .. "/" .. name .. " is sent to clients" )
		end
	end
	for _, name in ipairs( { "cl_hud.lua", "cl_fates.lua", "cl_scoreboard.lua", "cl_help.lua" } ) do
		T.Check( Loader.Sent[ root .. "systems/" .. name ], name .. " is sent to clients" )
	end
end
