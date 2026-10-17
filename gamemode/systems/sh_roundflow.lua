-- Round flow (step 13): fate stations close, migrants come through the gate.
--
--   At Config.StationsCloseAt (10 min) every fate_station is removed. After that, every
--   Config.MigrantWave (1 min) each waiting ghost (not Foolish: slaves skip this path) spawns
--   in the wasteland as a Prole migrant carrying `papers`.
--   At the konsole_immigration in the Gate Antechamber, Interact "gate_passport" (or Use) takes
--   the papers, gives a `passport` and makes the migrant a Prole citizen. There is no fate list.
--   The Kaiser gets "Recruit as Korpsman" on a living Prole within RoundFlow.RANGE, like
--   gr/sanitar-recruit: a yes/no prompt, no stem-cell cost; the cap is the korpsmen lost this round.
RoundFlow = RoundFlow or {}
RoundFlow.RANGE = 100
RoundFlow.TIMEOUT = 30
Config.StationsCloseAt = Config.StationsCloseAt or 600
Config.MigrantWave = Config.MigrantWave or 60

Items.Define( "papers", {
	Name = "Migrant Papers",
	Description = "Crumpled entry papers. Take them to the Gates of Gangrene.",
	Weight = 1,
	Model = "models/props_c17/paper01.mdl",
} )

Items.Define( "passport", {
	Name = "Gangrene Passport",
	Description = "Proof of citizenship within Gangrene.",
	Weight = 1,
	Model = "models/props_lab/clipboard.mdl",
} )

function RoundFlow.Lost() return WorldState.Get( "roundflow.korpsLost", 0 ) end
-- Korpsmen recruited this round. Dead korpsmen keep the fate until the round ends, so the
-- replacement slots count recruits, not Fates.Count.
function RoundFlow.KorpsIn() return WorldState.Get( "roundflow.korpsIn", 0 ) end

-- Shared: whether the Kaiser `ply` may offer `target` a korpsman place, and why not.
function RoundFlow.CanRecruit( ply, target )
	local mine = ply:GetFateDef()
	if not mine or mine.id ~= "kaiser" then return false, "You recruit no one." end
	if not ply:Alive() or ply:IsGhost() then return false, "The dead recruit no one." end
	if not ( IsValid( target ) and target:IsPlayer() ) or target == ply then return false, "Recruit whom?" end
	local def = target:GetFateDef()
	if not target:Alive() or target:IsGhost() or not def or def.id ~= "prole" then
		return false, "Only a living Prole can be recruited."
	end
	if ply:GetPos():DistToSqr( target:GetPos() ) > RoundFlow.RANGE * RoundFlow.RANGE then return false, "Get closer." end
	if RoundFlow.KorpsIn() >= RoundFlow.Lost() then return false, "There is no free Korpsman slot." end
	return true
end

Interact.Add( "recruit_korpsman", {
	label = "Recruit as Korpsman",
	range = RoundFlow.RANGE,
	show = function( ply, ent )
		local mine = ply:GetFateDef()
		if not mine or mine.id ~= "kaiser" or not ent:IsPlayer() or ply:IsGhost() then return false end
		local def = ent:GetFateDef()
		return def ~= nil and def.id == "prole" and ent:Alive()
	end,
	run = function( ply, ent ) RoundFlow.Offer( ply, ent ) end,
} )

Interact.Add( "gate_passport", {
	label = "Hand over your papers",
	range = 150,
	show = function( ply, ent )
		return ent:GetClass() == "konsole_immigration" and Inventory.Count( ply, "papers" ) > 0
	end,
	run = function( ply, ent ) RoundFlow.Trade( ply ) end,
} )

if CLIENT then
	local function answer( yes )
		net.Start( "gr_korps_answer" )
		net.WriteBool( yes )
		net.SendToServer()
	end
	Net.Receive( "gr_korps_offer", nil, function()
		local by = net.ReadString()
		Derma_Query( by .. " offers to make you a Korpsman.", "Recruitment",
			"Accept", function() answer( true ) end,
			"Refuse", function() answer( false ) end )
	end )
	return
end

-- Server ------------------------------------------------------------------------------------

Net.Pool( "gr_korps_offer" )
RoundFlow.pending = RoundFlow.pending or {} -- target -> { by, expires }

function RoundFlow.Offer( ply, target )
	local ok, why = RoundFlow.CanRecruit( ply, target )
	if not ok then Notify( ply, why ) return false, why end
	RoundFlow.pending[ target ] = { by = ply, expires = CurTime() + RoundFlow.TIMEOUT }
	Notify( ply, "You offer " .. target:Nick() .. " a place as Korpsman." )
	if Net.IsClient( target ) then
		net.Start( "gr_korps_offer" )
		net.WriteString( ply:Nick() )
		net.Send( target )
	end
	return true
end

function RoundFlow.Answer( target, yes )
	local p = RoundFlow.pending[ target ]
	RoundFlow.pending[ target ] = nil
	if not p or CurTime() > p.expires or not IsValid( p.by ) then return false, "No offer stands." end
	local ply = p.by
	if not yes then
		Notify( ply, target:Nick() .. " refuses." )
		return false, "refused"
	end
	local ok, why = RoundFlow.CanRecruit( ply, target )
	if not ok then
		Notify( target, "The offer no longer stands." )
		Notify( ply, why )
		return false, why
	end
	Fates.Apply( target, "korpsman", { reason = "pick" } )
	WorldState.Set( "roundflow.korpsIn", RoundFlow.KorpsIn() + 1 )
	Notify( ply, target:Nick() .. " accepts." )
	Log.Info( "recruit", "%s recruited %s as korpsman", ply:Nick(), target:Nick() )
	return true
end

Net.Receive( "gr_korps_answer", { rate = 2, alive = true }, function( ply )
	RoundFlow.Answer( ply, net.ReadBool() )
end )

hook.Add( "PlayerDisconnected", "gr_roundflow", function( ply ) RoundFlow.pending[ ply ] = nil end )

function RoundFlow.Elapsed()
	local start = RoundFlow.startedAt or ( Round.EndsAt() - Config.RoundLength )
	return CurTime() - start
end

-- The konsole: papers -> passport, and the migrant stays (or becomes) a Prole citizen.
function RoundFlow.Trade( ply )
	if Inventory.Count( ply, "papers" ) < 1 then
		Notify( ply, "The konsole wants papers. You have none." )
		return false
	end
	Inventory.Remove( ply, "papers", 1 )
	local def = ply:GetFateDef()
	if not def or def.id ~= "prole" then
		local pos = ply:GetPos()
		Fates.Apply( ply, "prole", { reason = "gate" } )
		ply:SetPos( pos )
	end
	Inventory.Add( ply, "passport", 1, true )
	ply.grMigrant = nil
	Notify( ply, "The konsole takes your papers and gives you a passport. Welcome to Gangrene, Prole." )
	return true
end

function RoundFlow.CloseStations()
	if RoundFlow.closed then return end
	RoundFlow.closed = true
	for ent in pairs( Fates.Stations ) do
		if IsValid( ent ) then ent:Remove() end
	end
	Log.Info( "round", "fate stations closed; migrants only now" )
end

-- Where migrants arrive, per map. Unlisted maps keep the normal spawn.
RoundFlow.WASTELAND = { rp_slumtown = Vector( 3400, -64, 64 ) }

function RoundFlow.SpawnMigrant( ply )
	Fates.Apply( ply, "prole", { reason = "migrant" } )
	local pos = RoundFlow.WASTELAND[ game.GetMap() ]
	if pos then ply:SetPos( pos ) end
	Inventory.Add( ply, "papers", 1, true )
	ply.grMigrant = true
	Notify( ply, "You arrive from the wasteland. Take your papers to the Gates of Gangrene." )
end

function RoundFlow.Wave()
	local n = 0
	for _, p in player.Iterator() do
		if p:IsGhost() and p:GetRank() > RANK_FOOLISH then
			RoundFlow.SpawnMigrant( p )
			n = n + 1
		end
	end
	if n > 0 then Log.Info( "round", "migrant wave: %d", n ) end
	return n
end

function RoundFlow.Reset()
	RoundFlow.startedAt = CurTime()
	RoundFlow.closed = false
	RoundFlow.nextWave = nil
	RoundFlow.pending = {}
	WorldState.Set( "roundflow.korpsLost", 0 )
	WorldState.Set( "roundflow.korpsIn", 0 )
end

hook.Add( "GR_RoundStart", "gr_roundflow", RoundFlow.Reset )

hook.Add( "PlayerDeath", "gr_roundflow", function( ply )
	local f = ply:GetFateDef()
	if f and f.id == "korpsman" then WorldState.Set( "roundflow.korpsLost", RoundFlow.Lost() + 1 ) end
end )

Sched.Every( "roundflow", 1, function()
	if Round.IsOver() then return end
	if RoundFlow.Elapsed() < Config.StationsCloseAt then return end
	RoundFlow.CloseStations()
	local now = CurTime()
	RoundFlow.nextWave = RoundFlow.nextWave or now
	if now >= RoundFlow.nextWave then
		RoundFlow.nextWave = now + Config.MigrantWave
		RoundFlow.Wave()
	end
end )
