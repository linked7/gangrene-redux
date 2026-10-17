-- Step 5: names, models, race and the Nick override, applied in one pass.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t5_%'" )

	for _, f in ipairs( Fates.All() ) do
		for _ = 1, 5 do
			local look = isfunction( f.Appearance ) and f.Appearance() or f.Appearance
			if not util.IsValidModel( look.model ) then T.Check( false, f.id .. " model exists: " .. look.model ) end
		end
	end
	T.Check( true, "every fate's models exist on the server" )

	local b = player.CreateNextBot( "t5_a" )
	T.Wait( 0.2 )
	T.Equal( b:Nick(), "t5_a", "ghosts go by their account name" )
	T.Equal( b:GetRace(), 0, "ghosts show no race" )
	T.Equal( b:GetModel(), "models/player/charple.mdl", "ghost model" )

	b:SetRank( RANK_FRIEND ) b:SetStemCells( 10 )
	Fates.Take( b, "sanitar" )
	T.Check( string.match( b:Nick(), "^%a+ #%d%d$" ) ~= nil, "sanitar gets a codename: " .. b:Nick() )
	T.Equal( b:SteamName(), "t5_a", "SteamName keeps the account name" )
	T.Equal( DB.Key( b ), "bot:t5_a", "DB key ignores the character name" )
	T.Equal( b:GetModel(), "models/player/police.mdl", "sanitar model" )
	T.Equal( b:GetWalkSpeed(), Config.WalkSpeed, "walk speed comes from the config" )
	T.Equal( b:GetRunSpeed(), Config.RunSpeed, "run speed comes from the config" )
	T.Equal( b:GetRaceDef() and b:GetRaceDef().id, "gangral", "sanitar is Gangral" )
	local hands = b:GetHands()
	T.Check( IsValid( hands ) and hands:GetModel() == "models/weapons/c_arms_citizen.mdl", "hands come from the race" )

	local s = player.CreateNextBot( "t5_slave" )
	Fates.Take( s, "slave" )
	T.Check( string.match( s:Nick(), "^%a+ #%d+$" ) ~= nil, "slave gets a barcode name: " .. s:Nick() )

	local p = player.CreateNextBot( "t5_prole" )
	p:SetRank( RANK_FRIEND ) p:SetStemCells( 5 )
	Fates.Take( p, "prole" )
	T.Check( string.match( p:Nick(), "^[%a%-]+ %a+$" ) ~= nil, "prole gets a worker name: " .. p:Nick() )
	T.Check( string.find( p:GetModel(), "group01" ) ~= nil, "prole wears a citizen model" )

	b:Kill()
	Corpse.Die( Corpse.Of( b ), "test" ) -- skip the bleed-out (step 7)
	T.WaitUntil( function() return b:Alive() end, 6, "respawned" )
	T.Equal( b:GetCharName(), "", "dying clears the character name" )
	T.Equal( b:GetModel(), "models/player/charple.mdl", "back to the ghost model" )
end
