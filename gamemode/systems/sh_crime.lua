-- Crime and police (step 10). Two rules tables decide what an act is worth, so the law reads as
-- data instead of nested ifs (R12):
--
--   Crime.Judge( attacker, victim )   a kill; the corpse system calls it via GR_PlayerKilled
--   Crime.Report( ply, act, ctx )     everything else: "theft" (ctx.crew or ctx.madeBy), "lock_alarm" (ctx.pos),
--                                     "break_in" (the stockpile's lock beaten off, sh_locks.lua)
--
-- Each rule is { name, when = fn, crime, wanted | evidence, duration, stem, despair, teeth, alarm, say }.
-- Rules are checked in order and the first match ends the scan, unless it says `fallthrough`;
-- then later matches fill in only the fields it left empty. Both return the outcome they applied, or nil.
--
-- Wanted (level, until, reason) is PUBLIC. Evidence is latent crime, kept on the server; police
-- get a one-line summary of it. Wanted time only runs out while no police can see the player.
Crime = Crime or {}

WANTED_NONE, WANTED_TORMENT, WANTED_JUDGMENT, WANTED_DEATH = 0, 1, 2, 3

State.Field( "Wanted", "UInt", 2, State.PUBLIC, WANTED_NONE )
State.Field( "WantedUntil", "Float", 0, State.PUBLIC, 0 )
State.Field( "WantedReason", "String", 0, State.PUBLIC, "" )
State.Field( "Teeth", "UInt", 8, State.OWNER, 0 ) -- a sanitar's bounty, spent in step 11

local meta = FindMetaTable( "Player" )
function meta:IsWanted() return self:GetWanted() > WANTED_NONE end

-- Seconds of wanted time left, as last counted (it is paused while police watch).
function Crime.WantedLeft( ply )
	if not ply:IsWanted() then return 0 end
	return math.max( ply:GetWantedUntil() - CurTime(), 0 )
end

-- Police see a summary of each player's evidence: entindex -> text.
Crime.Summaries = Crime.Summaries or {}

if CLIENT then
	Net.Receive( "gr_crime_evidence", nil, function()
		local idx = net.ReadUInt( 8 )
		local text = net.ReadString()
		Crime.Summaries[ idx ] = text ~= "" and text or nil
	end )
	return
end

-- Server ------------------------------------------------------------------------------------

Net.Pool( "gr_crime_evidence" )

local SIGHT_RANGE = 2500 -- police farther than this never count as seeing anyone (P3 prefilter)

Crime.stats = { traces = 0 }

-- Line of sight from one policeman to one player: distance, then PVS, then one trace.
function Crime.CanSee( police, ply )
	if police:GetPos():DistToSqr( ply:GetPos() ) > SIGHT_RANGE * SIGHT_RANGE then return false end
	if not police:TestPVS( ply ) then return false end
	Crime.stats.traces = Crime.stats.traces + 1
	local tr = util.TraceLine( {
		start = police:EyePos(),
		endpos = ply:EyePos(),
		filter = { police, ply },
		-- MASK_BLOCKLOS and MASK_OPAQUE pass straight through props on this engine (tested);
		-- this one stops at props and at other bodies, so a crowd can hide you too.
		mask = MASK_OPAQUE_AND_NPCS,
	} )
	return not tr.Hit
end

local function isPolice( p ) return p:Alive() and p:FateHas( "Police" ) end

function Crime.SeenByPolice( ply )
	for _, p in player.Iterator() do
		if p ~= ply and isPolice( p ) and Crime.CanSee( p, ply ) then return true end
	end
	return false
end

local function tellPolice( text, except )
	for _, p in player.Iterator() do
		if p ~= except and isPolice( p ) then Notify( p, text ) end
	end
end

-- Wanted ------------------------------------------------------------------------------------

-- A harsher level replaces the reason; time only ever extends.
-- The whole city hears who is wanted (the original's SetWanted): three alarms on the criminal,
-- one big red line to everyone, a little despair, and a word on how long to hide.
Crime.PUNISHMENT = { "TORMENT", "JUDGMENT", "DEATH" }
function Crime.Announce( ply, level, duration, reason )
	for _ = 1, 3 do ply:EmitSound( "ambient/alarms/manhack_alert_pass1.wav", 0, math.random( 60, 80 ) ) end
	Chat.Big( nil, Color( 200, 0, 0 ), string.format( "%s to %s for %s!",
		Crime.PUNISHMENT[ level ] or Crime.PUNISHMENT[ 1 ], ply:Nick(), reason ) )
	Needs.Add( ply, "Despair", 1, "wanted" )
	Chat.Tell( ply, Color( 200, 0, 0 ), "You should hide for " .. string.NiceTime( duration ) .. "." )
end

function Crime.MakeWanted( ply, level, duration, reason )
	local now = CurTime()
	-- Only news that makes it worse is shouted: a higher level, or a longer sentence than is left.
	local news = not ply:IsWanted() or level > ply:GetWanted() or now + duration > ply:GetWantedUntil()
	-- One episode runs from becoming wanted until it clears, and remembers every crime in it
	-- (a bounty is paid once per episode, step 11.3).
	if not ply:IsWanted() or not ply.GR_WantedEpisode then ply.GR_WantedEpisode = { crimes = {} } end
	ply.GR_WantedEpisode.crimes[ reason ] = true
	if level >= ply:GetWanted() then ply:SetWantedReason( reason ) end
	ply:SetWantedUntil( math.max( now + duration, ply:IsWanted() and ply:GetWantedUntil() or 0 ) )
	ply:SetWanted( math.max( level, ply:GetWanted() ) )
	ply.GR_WantedCheckedAt = now
	Notify( ply, string.format( "You are wanted for %s.", reason ) )
	if news then Crime.Announce( ply, level, duration, reason ) end
	tellPolice( string.format( "%s is wanted for %s.", ply:Nick(), reason ), ply )
	Log.Debug( "crime", "%s wanted (%d) for %s, %d s", ply:Nick(), level, reason, duration )
end

function Crime.ClearWanted( ply )
	ply:SetWanted( WANTED_NONE )
	ply:SetWantedUntil( 0 )
	ply:SetWantedReason( "" )
	ply.GR_WantedCheckedAt = nil
	ply.GR_WantedEpisode = nil
end

-- Evidence ----------------------------------------------------------------------------------
-- ply.GR_Evidence: crime -> { level, duration, expires }. It dies with the life (GR_FateEnter).

local function summarize( ply )
	local parts = {}
	for crime, e in SortedPairs( ply.GR_Evidence or {} ) do
		table.insert( parts, string.format( "%s (%d s)", crime, math.max( math.ceil( e.expires - CurTime() ), 0 ) ) )
	end
	return table.concat( parts, ", " )
end

local function sendSummary( ply, recipients )
	net.Start( "gr_crime_evidence" )
	net.WriteUInt( ply:EntIndex(), 8 )
	net.WriteString( summarize( ply ) )
	net.Send( recipients )
end

local function policeList()
	local out = {}
	for _, p in player.Iterator() do
		if isPolice( p ) and not p:IsBot() then table.insert( out, p ) end
	end
	return out
end

function Crime.Summary( ply ) return summarize( ply ) end

-- Drops expired entries and returns the live table.
function Crime.Evidence( ply )
	local ev = ply.GR_Evidence
	if not ev then return {} end
	local changed = false
	for crime, e in pairs( ev ) do
		if CurTime() >= e.expires then
			ev[ crime ] = nil
			changed = true
		end
	end
	if changed then sendSummary( ply, policeList() ) end
	return ev
end

function Crime.AddEvidence( ply, crime, level, duration )
	ply.GR_Evidence = ply.GR_Evidence or {}
	local old = ply.GR_Evidence[ crime ]
	local expires = CurTime() + duration
	ply.GR_Evidence[ crime ] = {
		level = math.max( level, old and old.level or 0 ),
		duration = duration,
		expires = math.max( expires, old and old.expires or 0 ),
	}
	sendSummary( ply, policeList() )
	Log.Debug( "crime", "%s: evidence of %s, %d s", ply:Nick(), crime, duration )
end

-- Removes and returns one piece of evidence, for Inspect and Sentence to act on (step 11).
function Crime.TakeEvidence( ply, crime )
	local e = Crime.Evidence( ply )[ crime ]
	if not e then return nil end
	ply.GR_Evidence[ crime ] = nil
	sendSummary( ply, policeList() )
	return e
end

-- Rules -------------------------------------------------------------------------------------

local function sameFaction( a, b )
	local f = a:FateHas( "Faction" )
	return f and f == b:FateHas( "Faction" )
end

local function outranked( a, b ) return ( a:FateHas( "Authority" ) or 0 ) < ( b:FateHas( "Authority" ) or 0 ) end

Crime.JudgeRules = {
	{ name = "sovereign", when = function( a ) return a:FateHas( "Sovereign" ) end },
	{ name = "execution", teeth = 1,
		when = function( a, v ) return a:FateHas( "Police" ) and v:GetWanted() == WANTED_DEATH end },
	-- Betrayals only weigh on the killer; the crime itself comes from the rules below.
	{ name = "own_leader", fallthrough = true, stem = -666, despair = 100, say = "MY LEADER!! MY STEM CELLS!!!",
		when = function( a, v ) return sameFaction( a, v ) and v:FateHas( "Sovereign" ) end },
	{ name = "overseer", fallthrough = true, stem = -20, despair = 60, say = "My overseer!! What have I done!!!",
		when = function( a, v ) return sameFaction( a, v ) and outranked( a, v ) end },
	{ name = "policide", crime = "policide", wanted = WANTED_DEATH, duration = 450, stem = -1, despair = 30,
		when = function( _, v ) return v:FateHas( "Police" ) end },
	{ name = "high_assassination", crime = "high assassination", wanted = WANTED_DEATH, duration = 600, stem = -1, despair = 30,
		when = function( _, v ) return v:FateHas( "Sovereign" ) end },
	{ name = "murder", crime = "murder", wanted = WANTED_DEATH, duration = 300, stem = -1, despair = 30,
		say = "I just killed them, didn't I?",
		when = function( _, v ) return v:FateHas( "Citizen" ) end },
}

-- A crate is stolen when its crew (a set of DB keys) lacks the player; a built thing, when
-- someone else built it (ctx.madeBy).
local function stolen( ply, ctx )
	if ctx.crew ~= nil then return not ctx.crew[ DB.Key( ply ) ] end
	return ctx.madeBy ~= nil and ctx.madeBy ~= DB.Key( ply )
end

Crime.ReportRules = {
	{ name = "sovereign", when = function( ply ) return ply:FateHas( "Sovereign" ) end },
	{ name = "theft_caught", crime = "theft from the People", wanted = WANTED_TORMENT, duration = 180,
		when = function( ply, act, ctx ) return act == "theft" and stolen( ply, ctx ) and Crime.SeenByPolice( ply ) end },
	{ name = "theft", crime = "theft", evidence = WANTED_TORMENT, duration = 300,
		when = function( ply, act, ctx ) return act == "theft" and stolen( ply, ctx ) end },
	-- Spit on the law (sh_weapons.lua): a sovereign spitter is already let off by the rule above.
	{ name = "spit_sovereign", crime = "disrespecting the Witch Kaiser", evidence = WANTED_TORMENT, duration = 300,
		when = function( _, act, ctx ) return act == "spit" and not ctx.victim:IsWanted() and ctx.victim:FateHas( "Sovereign" ) end },
	{ name = "spit_police", crime = "disrespecting Sanitar Squad", evidence = WANTED_TORMENT, duration = 180,
		when = function( _, act, ctx ) return act == "spit" and not ctx.victim:IsWanted() and ctx.victim:FateHas( "Police" ) end },
	{ name = "lock_alarm", alarm = "state", when = function( _, act ) return act == "lock_alarm" end },
	{ name = "break_in", crime = "breaking into the stockpile", wanted = WANTED_JUDGMENT, duration = 300,
		when = function( _, act ) return act == "break_in" end },
}

local FIELDS = { "crime", "wanted", "evidence", "duration", "stem", "despair", "teeth", "alarm", "say" }

-- Walks a rules table; returns the merged outcome of the matching rules, or nil.
local function evaluate( rules, ... )
	local out
	for _, rule in ipairs( rules ) do
		if rule.when( ... ) then
			out = out or { rules = {} }
			table.insert( out.rules, rule.name )
			for _, k in ipairs( FIELDS ) do
				if out[ k ] == nil then out[ k ] = rule[ k ] end
			end
			if not rule.fallthrough then break end
		end
	end
	return out
end

-- Sends `text` to everyone whose fate listens on radio `channel`; returns who got it.
function Crime.Alarm( channel, text )
	local got = {}
	for _, p in player.Iterator() do
		local radio = p:Alive() and p:FateHas( "Radio" )
		if radio and table.HasValue( radio, channel ) then
			Notify( p, text )
			table.insert( got, p )
		end
	end
	return got
end

local function apply( ply, out, ctx )
	if out.wanted then Crime.MakeWanted( ply, out.wanted, out.duration, out.crime ) end
	if out.evidence then Crime.AddEvidence( ply, out.crime, out.evidence, out.duration ) end
	if out.stem then ply:SetStemCells( math.max( ply:GetStemCells() + out.stem, 0 ) ) end
	if out.teeth then
		ply:SetTeeth( ply:GetTeeth() + out.teeth )
		Notify( ply, "TEETH: " .. ply:GetTeeth() )
	end
	if out.say then Notify( ply, out.say ) end
	if out.alarm then
		local pos = ctx and ctx.pos or ply:GetPos()
		out.alarmed = Crime.Alarm( out.alarm, string.format( "ALARM: the stockpile is being broken into at (%d, %d, %d)!",
			pos.x, pos.y, pos.z ) )
	end
	-- Last, because full despair is a heart attack.
	if out.despair then Needs.Add( ply, "Despair", out.despair, out.crime or "crime" ) end
end

function Crime.Judge( attacker, victim )
	if not ( IsValid( attacker ) and attacker:IsPlayer() and IsValid( victim ) and victim:IsPlayer() ) then return end
	if attacker == victim or attacker:IsGhost() then return end
	local out = evaluate( Crime.JudgeRules, attacker, victim )
	if out then apply( attacker, out ) end
	Log.Debug( "crime", "judge %s -> %s: %s", attacker:Nick(), victim:Nick(), out and table.concat( out.rules, "," ) or "no rule" )
	return out
end

function Crime.Report( ply, act, ctx )
	if not IsValid( ply ) or ply:IsGhost() then return end
	ctx = ctx or {}
	local out = evaluate( Crime.ReportRules, ply, act, ctx )
	if out then apply( ply, out, ctx ) end
	return out
end

-- The corpse system (step 7) fires this in exactly two places: a downed player is finished off
-- (killer = who did it), or a dying player bleeds out (killer = who downed them). Getting up
-- from a wounded down is never judged.
hook.Add( "GR_PlayerKilled", "gr_crime", function( victim, killer )
	Crime.Judge( killer, victim )
end )

-- Once a second per player: wanted time counts down only while no police can see them,
-- and expired evidence drops off. Unwanted players without evidence cost nothing.
function Crime.Tick( ply )
	if ply.GR_Evidence and next( ply.GR_Evidence ) then Crime.Evidence( ply ) end
	if not ply:IsWanted() then return end

	local now = CurTime()
	local last = ply.GR_WantedCheckedAt or now
	ply.GR_WantedCheckedAt = now
	if Crime.SeenByPolice( ply ) then
		ply:SetWantedUntil( ply:GetWantedUntil() + ( now - last ) )
	elseif now >= ply:GetWantedUntil() then
		Notify( ply, "You are no longer wanted." )
		Crime.ClearWanted( ply )
	end
end
Sched.EachPlayer( "crime", 1, function( ply ) Crime.Tick( ply ) end )

-- A new life starts clean (State.Reset already cleared Wanted); new police get the summaries.
hook.Add( "GR_FateEnter", "gr_crime", function( ply )
	local had = ply.GR_Evidence and next( ply.GR_Evidence )
	ply.GR_Evidence = nil
	ply.GR_WantedCheckedAt = nil
	if had then sendSummary( ply, policeList() ) end
	if ply:FateHas( "Police" ) and not ply:IsBot() then
		for _, p in player.Iterator() do
			if p.GR_Evidence and next( p.GR_Evidence ) then sendSummary( p, ply ) end
		end
	end
end )
