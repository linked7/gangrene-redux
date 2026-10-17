-- Sanitar Summon (sh_summoner.lua): a civilian turns it on and police are told; only police turn it
-- off by use (then it sleeps); a civilian attacking it turns it off and leaves evidence; it stops by itself.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:tsm_%'" )

	local told = {}
	hook.Add( "GR_ChatTell", "T_Summoner", function( ply, color, text ) told[ #told + 1 ] = { ply = ply, text = text } end )
	local function heard( ply, pat )
		for _, m in ipairs( told ) do if m.ply == ply and string.find( m.text, pat, 1, true ) then return true end end
		return false
	end

	local function bot( name, fate )
		local b = player.CreateNextBot( "tsm_" .. name )
		b:SetRank( RANK_FRIEND )
		b:SetStemCells( 10 )
		T.Check( Fates.Take( b, fate ), name .. " takes " .. fate )
		return b
	end

	T.Wait( 0.2 )
	local p = bot( "prole", "prole" )
	local san = bot( "san", "sanitar" )
	T.Wait( 0.5 )

	T.Check( Layout.CLASSES.summoner and Layout.CLASSES.summoner.area, "the layout knows summoners" )
	if game.GetMap() == "rp_slumtown" then
		T.Equal( table.Count( Summoner.All ), 16, "rp_slumtown has 16 summoners" )
	end

	local e = ents.Create( "summoner" )
	e:SetKeyValue( "area", "Test Pit" )
	e:SetPos( p:GetPos() + Vector( 40, 0, 0 ) )
	e:Spawn()
	T.Equal( e:GetArea(), "Test Pit", "the area comes from the key value" )
	T.Equal( e:GetModel(), "models/props_combine/combine_smallmonitor001.mdl", "the monitor model" )
	san:SetPos( e:GetPos() + Vector( -40, 30, 0 ) )

	-- Validation: too far does nothing
	local far = san:GetPos()
	san:SetPos( e:GetPos() + Vector( 2000, 0, 0 ) )
	Summoner.Use( e, san )
	T.Check( not e:GetOn(), "too far away does nothing" )
	san:SetPos( far )

	-- Civilian turns it on
	Summoner.Use( e, p )
	T.Check( e:GetOn(), "a prole turns it on" )
	T.Check( heard( p, "Sanitar Squad is alerted" ), "the prole is told" )
	T.Check( heard( san, "ACHTUNG -- " .. p:Nick() ), "police are alerted" )
	T.Check( heard( san, "Test Pit" ), "the alert names the area" )
	Summoner.Use( e, p )
	T.Check( e:GetOn() and heard( p, "You'll have to hit it" ), "a prole can't use it off" )

	-- Police turn it off, then it sleeps
	Summoner.Use( e, san )
	T.Check( not e:GetOn(), "police turn it off" )
	T.Check( heard( san, "situation was resolved" ), "police are told it's resolved" )
	T.Check( e:GetNextToggle() > CurTime() + 170, "it sleeps after" )
	Summoner.Use( e, p )
	T.Check( not e:GetOn() and heard( p, "It's sleeping" ), "a sleeping summon refuses" )

	-- Attacking it while on
	e:SetNextToggle( 0 )
	Summoner.Use( e, p )
	T.Check( e:GetOn(), "on again" )
	local crush = DamageInfo() crush:SetDamage( 10 ) crush:SetDamageType( DMG_CRUSH ) crush:SetAttacker( p )
	e:TakeDamageInfo( crush )
	T.Check( e:GetOn(), "crush damage doesn't stop it" )
	local hit = DamageInfo() hit:SetDamage( 10 ) hit:SetDamageType( DMG_CLUB ) hit:SetAttacker( p )
	e:TakeDamageInfo( hit )
	T.Check( not e:GetOn(), "a hit turns it off" )
	T.Check( Crime.Evidence( p )[ "obstruction of sanitation" ], "the attacker leaves evidence" )

	-- It stops by itself
	Summoner.Use( e, p )
	e.AutoStop = CurTime() + 0.5
	T.Wait( 1.5 )
	T.Check( not e:GetOn(), "it stops by itself" )

	hook.Remove( "GR_ChatTell", "T_Summoner" )
	e:Remove()
	p:Kick() san:Kick()
end
