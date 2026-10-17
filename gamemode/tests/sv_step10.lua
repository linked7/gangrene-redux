-- Step 10: every Judge and Report rule fires, evidence is stored and summarised, and wanted time
-- only runs out while no police can see the player (distance, PVS and trace prefilter).
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t10_%'" )

	local function bot( name, fate, rank, stem )
		local b = player.CreateNextBot( "t10_" .. name )
		b:SetRank( rank )
		b:SetStemCells( stem )
		T.Check( Fates.Take( b, fate ), name .. " takes " .. fate )
		return b
	end

	T.Wait( 0.2 )
	local k = bot( "kaiser", "kaiser", RANK_KAISER, 10 )
	local s1 = bot( "san1", "sanitar", RANK_FRIEND, 10 )
	local s2 = bot( "san2", "sanitar", RANK_FRIEND, 10 )
	local p1 = bot( "prole1", "prole", RANK_FRIEND, 10 )
	local p2 = bot( "prole2", "prole", RANK_FRIEND, 10 )
	local p3 = bot( "prole3", "prole", RANK_FRIEND, 10 )
	local sl = bot( "slave", "slave", RANK_FOOLISH, 10 )
	local all = { k, s1, s2, p1, p2, p3, sl }

	-- Nobody can see anybody: each bot alone, 4000 units apart, pinned in place.
	local base = s1:GetPos()
	local function far( b, i ) b:SetPos( base + Vector( 4000 * i, 0, 0 ) ) end
	for i, b in ipairs( all ) do
		b:SetMoveType( MOVETYPE_NONE )
		far( b, i )
	end
	local function reset()
		for _, b in ipairs( all ) do
			if IsValid( b ) and b:Alive() then
				Crime.ClearWanted( b )
				b.GR_Evidence = nil
			end
		end
	end
	local function left( b ) return Crime.WantedLeft( b ) end
	local function near( v, want ) return math.abs( v - want ) < 2 end

	T.Check( k:FateHas( "Sovereign" ) and not s1:FateHas( "Sovereign" ), "only the kaiser is Sovereign" )
	T.Equal( k:FateHas( "Faction" ), s1:FateHas( "Faction" ), "kaiser and sanitar share a faction" )
	T.Check( k:FateHas( "Authority" ) > s1:FateHas( "Authority" ), "kaiser outranks sanitar" )
	T.Check( sl:FateHas( "Citizen" ), "slaves are citizens like proles" )

	-- Judge -----------------------------------------------------------------------------------

	local o = Crime.Judge( k, p1 )
	T.Check( o and o.rules[ 1 ] == "sovereign" and o.crime == nil, "the kaiser's kills are no crime" )
	T.Check( not k:IsWanted(), "kaiser not wanted" )
	T.Equal( Crime.Judge( p1, p1 ), nil, "killing yourself is not judged" )

	local cells = p1:GetStemCells()
	o = Crime.Judge( p1, p2 )
	T.Equal( o and o.crime, "murder", "prole kills prole: murder" )
	T.Equal( p1:GetWanted(), WANTED_DEATH, "murder makes the killer death-wanted" )
	T.Equal( p1:GetWantedReason(), "murder", "wanted reason is public" )
	T.Check( near( left( p1 ), 300 ), "murder is 300 s: " .. left( p1 ) )
	T.Equal( p1:GetStemCells(), cells - 1, "murder costs a stem cell" )
	T.Equal( Needs.Get( p1, "Despair" ), 30, "murder adds 30 despair" )

	o = Crime.Judge( p3, sl )
	T.Equal( o and o.crime, "murder", "killing a slave is murder" )
	o = Crime.Judge( sl, p2 )
	T.Equal( o and o.crime, "murder", "a slave can murder" )
	T.Equal( sl:GetWanted(), WANTED_DEATH, "a slave can be wanted" )

	-- p1 is death-wanted now: a sanitar may execute them.
	o = Crime.Judge( s1, p1 )
	T.Check( o and o.crime == nil and o.teeth == 1, "sanitar executes a death-wanted player: no crime" )
	T.Equal( s1:GetTeeth(), 1, "execution earns a tooth" )
	T.Check( not s1:IsWanted(), "the executioner is not wanted" )
	o = Crime.Judge( s1, p2 )
	T.Equal( o and o.crime, "murder", "sanitar kills an innocent prole: murder" )
	T.Equal( s1:GetTeeth(), 1, "no tooth for an innocent" )
	reset()

	o = Crime.Judge( p2, s2 )
	T.Equal( o and o.crime, "policide", "prole kills sanitar: policide" )
	T.Check( p2:GetWanted() == WANTED_DEATH and near( left( p2 ), 450 ), "policide is death-wanted 450 s: " .. left( p2 ) )
	reset()

	cells = p3:GetStemCells()
	o = Crime.Judge( p3, k )
	T.Equal( o and o.crime, "high assassination", "prole kills kaiser: high assassination" )
	T.Check( p3:GetWanted() == WANTED_DEATH and near( left( p3 ), 600 ), "high assassination is death-wanted 600 s: " .. left( p3 ) )
	T.Equal( p3:GetStemCells(), cells - 1, "an outsider pays the usual stem cell" )
	reset()

	-- Wanted levels only climb, and time only extends.
	Crime.MakeWanted( p2, WANTED_JUDGMENT, 100, "test a" )
	Crime.MakeWanted( p2, WANTED_TORMENT, 50, "test b" )
	T.Check( p2:GetWanted() == WANTED_JUDGMENT and p2:GetWantedReason() == "test a", "a milder crime doesn't lower wanted" )
	T.Check( near( left( p2 ), 100 ), "nor shorten it" )
	reset()

	-- Report: theft -----------------------------------------------------------------------------

	T.Equal( Crime.Report( p1, "theft", { madeBy = DB.Key( p1 ) } ), nil, "delivering your own crate is no crime" )
	o = Crime.Report( p1, "theft", { madeBy = DB.Key( p2 ) } )
	T.Equal( o and o.evidence, WANTED_TORMENT, "unseen theft leaves evidence" )
	T.Check( not p1:IsWanted(), "unseen theft is not wanted" )
	local e = Crime.Evidence( p1 ).theft
	T.Check( e and near( e.expires - CurTime(), 300 ), "theft evidence lasts 300 s" )
	T.Check( string.find( Crime.Summary( p1 ), "theft", 1, true ) ~= nil, "police summary: " .. Crime.Summary( p1 ) )
	o = Crime.Report( sl, "theft", { madeBy = DB.Key( p2 ) } )
	T.Check( o and Crime.Evidence( sl ).theft, "slaves leave theft evidence too" )
	o = Crime.Report( k, "theft", { madeBy = DB.Key( p2 ) } )
	T.Check( o and o.crime == nil and not k:IsWanted() and not Crime.Evidence( k ).theft, "the kaiser can't steal from the state" )
	T.Check( Crime.TakeEvidence( p1, "theft" ) and not Crime.Evidence( p1 ).theft, "evidence can be taken for Inspect" )

	-- Caught in the act: a sanitar a short walk away, nothing between them.
	local dir
	for _, d in ipairs( { Vector( 1, 0, 0 ), Vector( -1, 0, 0 ), Vector( 0, 1, 0 ), Vector( 0, -1, 0 ) } ) do
		-- Clear at standing and crouched eye height: bots pinned in the void end up crouched.
		local clear = true
		for _, h in ipairs( { 28, 64 } ) do
			local up = Vector( 0, 0, h )
			if util.TraceLine( { start = base + up, endpos = base + d * 250 + up, mask = MASK_BLOCKLOS } ).Hit then clear = false end
		end
		if clear then dir = d break end
	end
	T.Check( dir ~= nil, "found open ground near the spawn" )
	dir = dir or Vector( 1, 0, 0 )
	s1:SetPos( base )
	p2:SetPos( base + dir * 200 )
	T.Check( Crime.SeenByPolice( p2 ), "a sanitar 200 units away sees the prole" )
	o = Crime.Report( p2, "theft", { madeBy = DB.Key( p3 ) } )
	T.Equal( o and o.crime, "theft from the People", "theft in sight of police: caught" )
	T.Check( p2:GetWanted() == WANTED_TORMENT and near( left( p2 ), 180 ), "caught theft is torment-wanted 180 s" )
	T.Check( not Crime.Evidence( p2 ).theft, "caught theft is wanted, not evidence" )
	reset()

	-- Report: stockpile -------------------------------------------------------------------------

	o = Crime.Report( p3, "lock_alarm", { pos = Vector( 1, 2, 3 ) } )
	local alarmed = {}
	for _, p in ipairs( o and o.alarmed or {} ) do alarmed[ p ] = true end
	T.Check( alarmed[ s1 ] and alarmed[ s2 ] and alarmed[ k ], "the lock alarm reaches everyone on the state radio" )
	T.Check( not alarmed[ p3 ] and not alarmed[ p1 ], "proles don't hear the alarm" )
	T.Check( not p3:IsWanted(), "the first hit on the lock is not yet a crime" )
	Crime.Report( p3, "break_in" )
	T.Check( p3:GetWanted() == WANTED_JUDGMENT and near( left( p3 ), 300 ), "a broken stockpile lock is judgment-wanted 300 s" )
	T.Equal( p3:GetWantedReason(), "breaking into the stockpile", "break-in reason" )
	reset()

	-- Wanted expiry -----------------------------------------------------------------------------

	-- Far from all police: the prefilter rejects without a trace, and the timer runs out.
	far( s1, 2 )
	local traces = Crime.stats.traces
	T.Check( not Crime.CanSee( s1, p1 ) and not Crime.CanSee( s2, p1 ), "distant police can't see" )
	T.Equal( Crime.stats.traces, traces, "distant pairs cost no trace" )
	Crime.MakeWanted( p1, WANTED_TORMENT, 2, "test" )
	T.WaitUntil( function() return not p1:IsWanted() end, 4.5, "wanted expires while unseen" )

	-- In plain sight: the timer pauses.
	s1:SetPos( base )
	p2:SetPos( base + dir * 200 )
	Crime.MakeWanted( p2, WANTED_TORMENT, 2, "test" )
	T.Wait( 4 )
	T.Check( p2:IsWanted(), "wanted does not expire while police watch" )
	T.Check( left( p2 ) > 0.5, "the timer was paused: " .. left( p2 ) )

	-- A wall between them: in range and in the PVS, but the one trace is blocked.
	local wall = ents.Create( "prop_physics" )
	wall:SetModel( "models/hunter/plates/plate4x4.mdl" )
	wall:SetPos( base + dir * 100 + Vector( 0, 0, 64 ) )
	wall:SetAngles( Angle( 90, dir:Angle().y, 0 ) )
	wall:Spawn()
	local phys = wall:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
	T.Wait( 0.1 )
	traces = Crime.stats.traces
	T.Check( not Crime.CanSee( s1, p2 ), "a wall blocks the sanitar's view" )
	T.Equal( Crime.stats.traces, traces + 1, "one trace for a pair in range" )
	T.WaitUntil( function() return not p2:IsWanted() end, 4.5, "behind the wall, wanted expires" )
	wall:Remove()

	-- Death and evidence ------------------------------------------------------------------------

	Crime.Report( p1, "theft", { madeBy = "someone" } )
	Crime.MakeWanted( p1, WANTED_DEATH, 100, "test" )
	p1:Kill()
	Corpse.Die( Corpse.Of( p1 ), "test" ) -- skip the bleed-out (step 7)
	T.WaitUntil( function() return p1:Alive() end, 6, "p1 respawns" )
	T.Check( not p1:IsWanted() and not Crime.Evidence( p1 ).theft, "a new life is clean" )

	-- The corpse contract: a kill (finish off or bleed out) is judged.
	hook.Run( "GR_PlayerKilled", p2, p3, NULL, "finished off" )
	T.Equal( p3:GetWantedReason(), "murder", "GR_PlayerKilled runs Crime.Judge" )
	reset()

	-- Last, because the despair is a heart attack: a sanitar kills their own Kaiser.
	s2:SetStemCells( 700 )
	o = Crime.Judge( s2, k )
	T.Equal( o and o.crime, "high assassination", "sanitar kills kaiser: high assassination" )
	T.Equal( s2:GetStemCells(), 33, "killing your own leader costs 666 stem cells (and 1 for the heart attack)" )
	T.Equal( Needs.Get( s2, "Despair" ) <= 60, true, "full despair: heart attack" )
end
