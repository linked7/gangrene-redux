-- The round (step 13): the unit of play. One map load is one round.
--
--   Round.Start()          on map load: the world entities (Layout.Spawn), fresh economy
--                          (Econ.ResetRound), then hook GR_RoundStart
--   Round.End( reason )    the timer ran out ("time") or an admin ended it: free the surviving
--                          slaves, run hook GR_RoundEnd, flush the DB, show the end screen, and
--                          Config.RoundEndDelay s later change level (Round.ChangeLevel)
--
-- Only stem cells, rank and playtime outlive a round. The round number is kept in the world table.
-- WorldState "round.number", "round.endsAt" (CurTime) and "round.over" are public for the HUD.
Round = Round or {}

function Round.Number() return WorldState.Get( "round.number", 0 ) end
function Round.EndsAt() return WorldState.Get( "round.endsAt", 0 ) end
function Round.IsOver() return WorldState.Get( "round.over", false ) end

if CLIENT then return end

Net.Pool( "gr_round_end" )

function Round.Start()
	local n = ( tonumber( DB.GetWorld( "round", 0 ) ) or 0 ) + 1
	DB.SetWorld( "round", n )
	Round.changeAt = nil
	WorldState.Set( "round.number", n )
	WorldState.Set( "round.endsAt", CurTime() + Config.RoundLength )
	WorldState.Set( "round.over", false )
	Layout.Spawn() -- the world entities first (sv_layout.lua); only missing ones on a repeat
	Econ.ResetRound()
	hook.Run( "GR_RoundStart", n )
	Log.Info( "round", "round %d begins (%d min)", n, Config.RoundLength / 60 )
end

-- Changes to the same map. Never while a test scenario runs: tests call Round.End freely.
function Round.ChangeLevel()
	if Test and Test.IsRunning and Test.IsRunning() then
		Log.Info( "round", "level change skipped: a test is running" )
		return false
	end
	RunConsoleCommand( "changelevel", game.GetMap() )
	return true
end

function Round.End( reason )
	if Round.IsOver() then return false end
	reason = reason or "time"
	WorldState.Set( "round.over", true )

	local freed = {}
	for _, p in player.Iterator() do
		if Rank.SurvivedRound( p ) then
			local name = p:Nick()
			if Rank.Free( p, "round" ) then table.insert( freed, name ) end
		end
	end
	hook.Run( "GR_RoundEnd", reason, freed )
	DB.Flush()

	net.Start( "gr_round_end" )
	net.WriteString( reason )
	net.WriteUInt( #freed, 8 )
	for i = 1, math.min( #freed, 255 ) do net.WriteString( freed[ i ] ) end
	net.WriteFloat( Config.RoundEndDelay )
	net.Broadcast()

	Round.changeAt = CurTime() + Config.RoundEndDelay
	Log.Info( "round", "round %d ends (%s); %d slaves freed", Round.Number(), reason, #freed )
	return true, freed
end

-- One clock for both the round timer and the level change after the end screen.
Sched.Every( "round", 1, function()
	local now = CurTime()
	if Round.changeAt then
		if now >= Round.changeAt then
			Round.changeAt = nil
			Round.ChangeLevel()
		end
	elseif not Round.IsOver() and Round.EndsAt() > 0 and now >= Round.EndsAt() then
		Round.End( "time" )
	end
end )

hook.Add( "InitPostEntity", "gr_round", Round.Start )

-- round_end [reason]: server console or staff (Admin.IsStaff, sv_admin.lua).
concommand.Add( "round_end", function( ply, _, args )
	if not Admin.IsStaff( ply ) then return end
	Log.Info( "admin", "%s ended the round", IsValid( ply ) and ply:SteamName() or "console" )
	Round.End( args[ 1 ] or "admin" )
end )
