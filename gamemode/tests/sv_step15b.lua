-- Step 15b: the client UI's server side. The fate menu's gr_take_fate receiver (only ghosts get
-- through; Fates.Request re-checks with CanTake and returns its reason), every field the HUD and
-- the menu read reaches the client, and every client file is listed and sent. The UI parity pass
-- (docs/05): the body registry message (Corpse.Sync), the screen-effect message (FX.Send and the
-- GR_Judged hook that starts the scares), the downed screen's LastThought and the content pack;
-- fate footsteps and the music list (§11); the ghost's look, hearing, grade and radio (§13).
return function( T )
	Config.SlaveGating = true -- these checks cover the gate itself; it is off by default for now
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
		"WantedReason", "Teeth", "PassedOut", "LastThought", "WakeUntil", "BleedoutUntil", "Race", "Consciousness" }
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
	for _, name in ipairs( { "cl_hud.lua", "cl_fates.lua", "cl_scoreboard.lua", "cl_help.lua", "cl_skin.lua", "cl_effects.lua",
		"cl_view.lua", "cl_crosshair.lua", "cl_chatbox.lua", "sh_fx.lua" } ) do
		T.Check( Loader.Sent[ root .. "systems/" .. name ], name .. " is sent to clients" )
	end
	local pos = {}
	for i, name in ipairs( manifest.systems ) do pos[ name ] = i end
	T.Check( pos[ "sh_fx.lua" ] and pos[ "sv_damage.lua" ] and pos[ "sh_fx.lua" ] > pos[ "sv_damage.lua" ], "sh_fx loads after the damage pipeline" )

	-- UI parity (docs/05) ---------------------------------------------------------------------------

	T.Equal( State.FieldByName( "LastThought" ).scope, State.OWNER, "the downed screen's last thought is the owner's" )
	T.Equal( Config.UI.ContentWorkshop, "3067207405", "the content pack is Workshop 3067207405" )
	for _, key in ipairs( { "cross_hover", "cross_unhover", "weapon_hover", "weapon_select", "weapon_choose", "menu_open", "button_release" } ) do
		local pair = Config.UI.Sounds[ key ]
		T.Check( pair and isstring( pair[ 1 ] ) and isstring( pair[ 2 ] ), "UI sound " .. key .. " has a pack path and a stock fallback" )
	end
	for _, name in ipairs( { "gr_corpse", "gr_fx" } ) do
		T.Check( util.NetworkStringToID( name ) > 0, name .. " is a pooled message" )
	end
	T.Check( isfunction( Corpse.Sync ) and isnumber( Corpse.DECAY ), "Corpse.Sync exists and the decay time is shared" )
	T.Check( isfunction( FX.Send ) and FX.ID.headwound and FX.ID.frighten and FX.ID.jumpscare and FX.ID.flash, "FX.Send and its four kinds" )
	T.Check( #FX.KINDS < 8, "the kinds fit the 3-bit id" )
	T.Check( hook.GetTable().GR_Judged and hook.GetTable().GR_Judged.gr_fx, "a judged killing starts a scare (gr_fx)" )
	T.Check( hook.GetTable().GR_PlayerRestored and hook.GetTable().GR_PlayerRestored.gr_fx, "getting up frightens (gr_fx)" )

	-- Crime.Judge fires GR_Judged with its outcome, whether or not a rule matched.
	local seen = {}
	hook.Add( "GR_Judged", "t15b", function( a, v, o ) table.insert( seen, { a = a, v = v, out = o } ) end )
	local killer, victim = bot( "killer", RANK_FRIEND ), bot( "victim", RANK_FRIEND )
	T.Wait( 0.3 )
	Fates.Apply( killer, "prole", { reason = "admin" } )
	Fates.Apply( victim, "prole", { reason = "admin" } )
	local out = Crime.Judge( killer, victim )
	hook.Remove( "GR_Judged", "t15b" )
	T.Equal( #seen, 1, "Crime.Judge ran GR_Judged once" )
	T.Check( seen[ 1 ] and seen[ 1 ].a == killer and seen[ 1 ].v == victim and seen[ 1 ].out == out, "with the attacker, victim and outcome" )
	T.Check( pcall( FX.Send, killer, "jumpscare" ) and pcall( FX.Send, killer, "nonsense" ), "FX.Send skips bots and unknown kinds" )
	T.Check( pcall( Corpse.Sync, killer ), "Corpse.Sync ignores what isn't a body" )

	-- Sound (§11): fate footsteps from the server, none for ghosts; the music list.
	T.Check( hook.GetTable().PlayerFootstep and hook.GetTable().PlayerFootstep.gr_ghost, "PlayerFootstep runs the fate's Footstep" )
	for _, id in ipairs( { "korpsman", "slave", "sanitar" } ) do
		T.Check( isfunction( Fates.Get( id ).Footstep ), id .. " has its own footsteps" )
	end
	T.Check( pcall( Fates.Get( "slave" ).Footstep, killer, 0 ), "a Footstep runs on a player" )
	T.Equal( hook.GetTable().PlayerFootstep.gr_ghost( killer, killer:GetPos(), 0 ), nil, "a living step keeps the engine sound" )
	T.Check( istable( Config.UI.Music ) and #Config.UI.Music > 0, "the music list is in Config.UI" )
	local kinds = {}
	for _, s in ipairs( Config.UI.Music ) do
		T.Check( isstring( s[ 1 ] ) and isnumber( s[ 2 ] ) and s[ 2 ] > 0 and isstring( s[ 4 ] ), "track " .. tostring( s[ 1 ] ) .. " has a length and name" )
		kinds[ s[ 3 ] ] = true
	end
	T.Check( kinds.idle and kinds.alert, "there are idle and ghost (alert) tracks" )
	T.Check( Loader.Sent[ root .. "systems/cl_music.lua" ], "cl_music.lua is sent to clients" )

	-- Ghosts (§13): the look on entering, cleared on leaving; the feel is fate data.
	local g = Fates.Get( "ghost" )
	T.Equal( g.Appearance.model, "models/player/skeleton.mdl", "ghosts are skeletons" )
	T.Equal( g.DSP, 4, "with muffled hearing" )
	T.Equal( g.CustomRadio, "Suffering Eternal", "the ghost radio is Suffering Eternal" )
	T.Check( g.NoRadioSound == true and g.ColorModOverride == true, "with no radio sound, and the grade replaces the usual one" )
	local grade = g.ColorMod( killer )
	T.Check( istable( grade ) and isnumber( grade[ "$pp_colour_contrast" ] ) and grade[ "$pp_colour_mulr" ] == 5, "the grade is red at no Suffering" )
	T.Check( g.MotionBlur and g.MotionBlur[ 1 ] == 0.08, "and blurred" )
	Fates.Apply( killer, "ghost", { reason = "admin" } )
	T.Check( killer:IsGhost(), "the killer is a ghost" )
	T.Equal( killer:GetSubMaterial( 0 ), "effects/tp_eyefx/tpeye", "with the glowing eyes" )
	T.Equal( killer:GetRenderFX(), 16, "and the hologram effect" )
	T.Equal( hook.GetTable().PlayerFootstep.gr_ghost( killer, killer:GetPos(), 0 ), true, "and silent steps" )
	Fates.Apply( killer, "prole", { reason = "admin" } )
	T.Equal( killer:GetSubMaterial( 0 ), "", "leaving the ghost clears the eyes" )
	T.Equal( killer:GetRenderFX(), kRenderFxNone, "and the effect" )
	killer:Kick( "test" )
	victim:Kick( "test" )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t15b_%'" )
end
