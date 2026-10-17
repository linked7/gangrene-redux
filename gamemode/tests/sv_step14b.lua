-- Step 14b: the hardening pass. Every receiver names a rate and a valid target kind; every
-- receiver that reads a target has a range (four documented exceptions, see docs/net-audit.md);
-- staff can't kick or ban themselves or each other; reasons are capped; Admin.Noclip toggles.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t14b_%'" )
	DB.Query( "DELETE FROM bans WHERE steamid LIKE 'bot:t14b_%'" )

	-- Receivers with a target but no range, on purpose: sight or a gift, not reach.
	local NO_RANGE = { nKaiserSentence = true, nKaiserForgive = true, nKaiserGrant = true, nKaiserFine = true }
	local kinds = { player = true, entity = true, any = true }

	for name, r in pairs( Net.Receivers ) do
		local o = r.opts or {}
		T.Check( isnumber( o.rate ) and o.rate > 0, name .. " names its own rate" )
		if o.target then
			T.Check( o.target == true or kinds[ o.target ], name .. " has a known target kind" )
			T.Check( o.range or NO_RANGE[ name ], name .. " has a target range" )
		end
		T.Check( not o.range or o.target, name .. " has no range without a target" )
	end
	for name in pairs( NO_RANGE ) do
		T.Check( Net.Receivers[ name ], "exception " .. name .. " still exists" )
	end

	T.Check( not pcall( Net.Receive, "t14b_bad", { rate = 0 }, function() end ), "rate 0 is refused" )
	T.Check( not pcall( Net.Receive, "t14b_bad", { range = 10 }, function() end ), "a range without a target is refused" )
	T.Check( not pcall( Net.Receive, "t14b_bad", { target = "wall" }, function() end ), "an unknown target kind is refused" )

	-- Admin ---------------------------------------------------------------------------------------

	local function bot( name )
		local b = player.CreateNextBot( "t14b_" .. name )
		b:SetRank( RANK_FRIEND )
		return b
	end
	local staff, other, user = bot( "staff" ), bot( "other" ), bot( "user" )
	T.Wait( 0.3 )
	local realStaff = Admin.IsStaff
	Admin.IsStaff = function( p ) return not IsValid( p ) or p == staff or p == other end

	T.Check( not Admin.Kick( staff, staff, "x" ), "staff can't kick themselves" )
	T.Check( not Admin.Kick( staff, other, "x" ), "staff can't kick staff" )
	T.Check( not Admin.Ban( staff, other, 5, "x" ), "staff can't ban staff" )
	T.Check( not Admin.Kick( user, user, "x" ), "a non-staff player can't kick" )
	T.Check( IsValid( staff ) and IsValid( other ) and IsValid( user ), "nobody left")

	local long = string.rep( "a", 500 )
	T.Check( Admin.Ban( staff, "bot:t14b_ghost", 5, long ), "staff bans a steamid" )
	local ban = DB.GetBan( "bot:t14b_ghost" )
	T.Check( ban and #ban.reason <= Admin.MAX_REASON, "the reason is capped" )
	T.Check( Admin.Unban( staff, "bot:t14b_ghost" ), "and lifts it" )
	T.Check( Admin.Ban( nil, user, 1, "console" ), "the console may ban a player" )
	DB.Unban( DB.Key( user ) )

	-- Noclip --------------------------------------------------------------------------------------

	Admin.SetFate( staff, staff, "prole" )
	T.Wait( 0.2 )
	T.Check( not Admin.Noclip( user ), "a non-staff player can't noclip" )
	T.Check( not Admin.Noclip( nil ), "the console has no body to noclip" )
	if staff:Alive() and not staff:IsGhost() then
		T.Check( Admin.Noclip( staff ), "staff toggles noclip on" )
		T.Equal( staff:GetMoveType(), MOVETYPE_NOCLIP, "moving through walls" )
		T.Check( Admin.Noclip( staff ), "and off" )
		T.Equal( staff:GetMoveType(), MOVETYPE_WALK, "walking again" )
	else
		T.Check( false, "staff is alive and solid for the noclip check" )
	end

	Admin.IsStaff = realStaff
	for _, b in ipairs( { staff, other, user } ) do if IsValid( b ) then b:Kick( "done" ) end end
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t14b_%'" )
	DB.Query( "DELETE FROM bans WHERE steamid LIKE 'bot:t14b_%'" )
	T.Equal( ( Econ.Audit() ), 0, "no bone drift" )
end
