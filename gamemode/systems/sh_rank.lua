-- Game ranks and stem cells (steps 11.5 and 13). Ranks are Foolish, Friend, Kapitan and Kaiser
-- (RANK_* in core/sh_fields.lua); admin powers are GMod usergroups and have nothing to do with them.
--
--   Rank.Free( ply, how, commender )   Foolish -> Friend, flushed to the DB at once; how = "commend" | "round"
--   Rank.Commend( ply, target )        a Friend or better vouches for a slave, once per round
--   Rank.Reward( ply, n, why )         stem cells earned (playtime, objectives, freeing)
--   Rank.Promote( ply )                Friend -> Kapitan once they hold Config.KapitanStemCells
--
-- New accounts are Foolish and may only take fates marked ForNewPlayers (Fates.CanTake). Being
-- freed doesn't end the current life: a freed slave stays one until they die.
--
-- Stem cells are lost elsewhere: unjust kills (Crime.JudgeRules `stem`) and heart attacks
-- (Needs.HeartAttack). Spending them on a fate (Fates.Take) gives nothing back, no bones.
--
-- Objectives call hook.Run( "GR_Objective", ply, cells, why ) to pay stem cells.
Rank = Rank or {}

Rank.NAMES = {
	[ RANK_FOOLISH ] = "Foolish",
	[ RANK_FRIEND ] = "Friend",
	[ RANK_KAPITAN ] = "Kapitan",
	[ RANK_KAISER ] = "Kaiser",
}
Rank.COMMEND_RANGE = 200

-- Per-round, server only; kept across fate changes. Round.Start zeroes them.
State.Field( "SlaveTime", "Float", 0, State.SERVER, 0, { keep = true } )  -- seconds alive as a Slave
State.Field( "Commended", "Bool", 0, State.SERVER, false, { keep = true } ) -- used this round's commendation

function Rank.Name( r ) return Rank.NAMES[ r ] or ( "rank " .. tostring( r ) ) end

-- The target is someone who can still be freed: in a new player's fate and not yet freed.
local function isSlave( p ) return p:FateHas( "ForNewPlayers" ) and p:GetRank() == RANK_FOOLISH end

-- Shared, so the context menu shows Commend only where the server would accept it. The
-- once-per-round flag is a SERVER field, so only the server can refuse for that.
function Rank.CanCommend( ply, target )
	if not ( IsValid( target ) and target:IsPlayer() ) or target == ply then return false, "Commend whom?" end
	if not ply:Alive() or ply:IsGhost() then return false, "The dead vouch for no one." end
	if ply:FateHas( "ForNewPlayers" ) then return false, "Slaves can't commend anyone." end
	if ply:GetRank() < RANK_FRIEND then return false, "Your word carries no weight yet." end
	if not target:Alive() or not isSlave( target ) then return false, "Only slaves can be commended." end
	if ply:GetPos():DistToSqr( target:GetPos() ) > Rank.COMMEND_RANGE * Rank.COMMEND_RANGE then
		return false, "Get closer."
	end
	if ply:GetCommended() then return false, "You have already commended someone this round." end
	return true
end

Interact.Add( "commend", {
	label = "Commend",
	range = Rank.COMMEND_RANGE,
	-- Offered on any slave; Rank.Commend says why when it refuses.
	show = function( ply, ent ) return ent:IsPlayer() and isSlave( ent ) and not ply:IsGhost() end,
	run = function( ply, ent ) Rank.Commend( ply, ent ) end,
} )

if CLIENT then return end

-- Server ------------------------------------------------------------------------------------

Net.Pool( "gr_announce" )

-- One big chat line for everyone.
function Rank.Announce( text )
	net.Start( "gr_announce" )
	net.WriteString( text )
	net.Broadcast()
	Log.Info( "announce", "%s", text )
end

function Rank.Promote( ply )
	if ply:GetRank() ~= RANK_FRIEND or ply:GetStemCells() < Config.KapitanStemCells then return false end
	ply:SetRank( RANK_KAPITAN )
	DB.FlushPlayer( ply )
	Notify( ply, "You have been promoted to Kapitan." )
	Log.Info( "rank", "%s (%s) promoted to Kapitan", ply:SteamName(), DB.Key( ply ) )
	return true
end

function Rank.Reward( ply, n, why )
	if n <= 0 then return end
	ply:SetStemCells( ply:GetStemCells() + n )
	Notify( ply, string.format( "+%d stem cell%s: %s", n, n == 1 and "" or "s", why ) )
	Log.Debug( "rank", "%s +%d stem cells (%s)", ply:Nick(), n, why )
	Rank.Promote( ply )
end

hook.Add( "GR_Objective", "gr_rank", function( ply, cells, why )
	if IsValid( ply ) and ply:IsPlayer() then Rank.Reward( ply, cells or 1, why or "objective" ) end
end )

-- Foolish -> Friend. Returns whether it happened.
function Rank.Free( ply, how, commender )
	if not IsValid( ply ) or ply:GetRank() ~= RANK_FOOLISH then return false end
	local name = ply:Nick()
	ply:SetRank( RANK_FRIEND )
	ply:SetStemCells( ply:GetStemCells() + 1 )
	DB.FlushPlayer( ply ) -- the one exception to write-behind: freedom is never lost

	local by = IsValid( commender ) and commender:Nick() or "surviving the round"
	Rank.Announce( string.format( "%s has been freed by %s!", name, by ) )
	Notify( ply, "You are free. When this life ends you may choose any purpose you can afford." )
	if IsValid( commender ) then Rank.Reward( commender, 1, "freeing a slave" ) end
	Rank.Promote( ply )
	Log.Info( "rank", "%s (%s) freed: %s%s", ply:SteamName(), DB.Key( ply ), how,
		IsValid( commender ) and ( " by " .. commender:SteamName() .. " (" .. DB.Key( commender ) .. ")" ) or "" )
	hook.Run( "GR_Freed", ply, how, commender )
	return true
end

function Rank.Commend( ply, target )
	local ok, why = Rank.CanCommend( ply, target )
	if not ok then
		Notify( ply, why )
		Log.Info( "rank", "%s (%s) commend refused: %s", ply:SteamName(), DB.Key( ply ), why )
		return false, why
	end
	ply:SetCommended( true )
	Log.Info( "rank", "%s (%s) commends %s (%s)", ply:SteamName(), DB.Key( ply ), target:SteamName(), DB.Key( target ) )
	Rank.Free( target, "commend", ply )
	return true
end

-- Freeing at the end of the round: alive, not downed, a Slave long enough this round.
function Rank.SurvivedRound( ply )
	if not ply:Alive() or ply:IsGhost() or not isSlave( ply ) then return false end
	local _, rec = Corpse.Of( ply )
	if rec and rec.state == "downed" then return false end
	return ply:GetSlaveTime() >= Config.SlaveMinRoundTime
end

-- Clocks ------------------------------------------------------------------------------------

Rank.SLAVE_TICK = 1
Rank.PLAYTIME_TICK = 60

Sched.EachPlayer( "rank_slave_time", Rank.SLAVE_TICK, function( ply )
	if ply:Alive() and isSlave( ply ) then ply:SetSlaveTime( ply:GetSlaveTime() + Rank.SLAVE_TICK ) end
end )

-- Living time (not as a ghost) earns stem cells; the remainder carries over within the session.
function Rank.PlaytimeTick( ply, secs )
	if not ply:Alive() or ply:IsGhost() then return end
	ply.GR_PlaySecs = ( ply.GR_PlaySecs or 0 ) + secs
	local cells = math.floor( ply.GR_PlaySecs / Config.PlaytimePerStemCell )
	if cells < 1 then return end
	ply.GR_PlaySecs = ply.GR_PlaySecs - cells * Config.PlaytimePerStemCell
	Rank.Reward( ply, cells, "time served" )
end

Sched.EachPlayer( "rank_playtime", Rank.PLAYTIME_TICK, function( ply ) Rank.PlaytimeTick( ply, Rank.PLAYTIME_TICK ) end )

-- Round state by DB key, so leaving and rejoining keeps the slave clock and the used
-- commendation (no farming commendations by reconnecting).
local saved = {}

hook.Add( "PlayerDisconnected", "gr_rank", function( ply )
	saved[ DB.Key( ply ) ] = { slaveTime = ply:GetSlaveTime(), commended = ply:GetCommended() }
end )

hook.Add( "GR_PlayerLoaded", "gr_rank", function( ply )
	local s = saved[ DB.Key( ply ) ]
	if s then
		ply:SetSlaveTime( s.slaveTime )
		ply:SetCommended( s.commended )
	end
	Rank.Promote( ply )
end )

hook.Add( "GR_RoundStart", "gr_rank", function()
	saved = {}
	for _, p in player.Iterator() do
		p:SetSlaveTime( 0 )
		p:SetCommended( false )
	end
end )

-- Staff set ranks with gr_setrank / !setrank (sv_admin.lua).
