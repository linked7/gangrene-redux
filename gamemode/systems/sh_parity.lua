-- Small gameplay pieces of the original that had no home yet (docs/05 §7-§14, step 17a):
--   teams           ghosts are on the spectator team, the living on the citizen team
--   bones notices   "Got 5 Bones" / "Lost 5 Bones" whenever a player's bones move (Econ.Transfer)
--   get-up line     "<name> gets up." to everyone near a body that gets back up or is revived
--   Call Korpsman   a citizen pays 50 bones to call the korpsmen; whoever heals them to full gets it
--   unholster       a poor shot drawing a gun warns everyone near: "<name> prepares to fire!"
--   pain and death  grunts when hurt, a scream on going down and at final death (fate PainSounds/DeathSounds)
--   intro texts     a fate's IntroTexts, told when it is taken
Parity = Parity or {}

TEAM_CITIZEN = 1
function GM:CreateTeams()
	team.SetUp( TEAM_CITIZEN, "Doomed", Color( 0, 120, 0, 255 ), false )
	team.SetUp( TEAM_SPECTATOR, "Undead", Color( 120, 120, 120, 255 ), false )
end

State.Field( "Emergency", "Bool", 0, State.PUBLIC, false ) -- called the korpsmen and not yet healed

Parity.CALL_COST = 50
Parity.CALL_MAX_HEALTH = 90 -- above this, it isn't an emergency

if CLIENT then
	-- Bones notices: the HUD can take them over through GR_Notice; until then they go to chat.
	Net.Receive( "gr_notice", nil, function()
		local col = net.ReadColor( false )
		local text = net.ReadString()
		if hook.Run( "GR_Notice", col, text ) == nil then chat.AddText( col, text ) end
	end )

	-- The context menu (UI) sends this for "Call Korpsman (50 Bones)".
	concommand.Add( "gr_call_korpsman", function()
		net.Start( "gr_call_korpsman" )
		net.SendToServer()
	end )
	return
end

resource.AddWorkshop( "3067207405" ) -- the original's content pack (models, sounds, materials)

Net.Pool( "gr_notice" )

-- One coloured notice to one player. GR_NoticeSent( ply, color, text ) lets tests listen.
function Parity.Notice( ply, color, text )
	hook.Run( "GR_NoticeSent", ply, color, text )
	net.Start( "gr_notice" )
	net.WriteColor( color, false )
	net.WriteString( text )
	net.Send( ply )
end

-- Teams -------------------------------------------------------------------------------------

hook.Add( "GR_FateEnter", "gr_parity_team", function( ply )
	ply:SetTeam( ply:IsGhost() and TEAM_SPECTATOR or TEAM_CITIZEN )
end )

-- Bones notices -----------------------------------------------------------------------------

-- Moves the player never sees as money changing hands: their own bones riding on their body.
Parity.SILENT_SOURCES = { downed = true, [ "got up" ] = true, revived = true, disconnect = true, rejoin = true }
-- Sources with a name the player is told (the original's AddMoney src).
Parity.SOURCE_LABELS = { [ "revive fee" ] = "Revival Fee", [ "korpsman call" ] = "Paramedics", [ "emergency paid" ] = "Paramedics" }

local function bonesNotice( holder, amount, source )
	if not ( IsValid( holder ) and holder:IsPlayer() ) then return end
	local label = Parity.SOURCE_LABELS[ source ]
	local prefix = label and ( label .. ": " ) or ""
	if amount > 0 then
		Parity.Notice( holder, Color( 0, 200, 0 ), prefix .. "Got " .. amount .. " Bones" )
	else
		Parity.Notice( holder, Color( 200, 0, 0 ), prefix .. "Lost " .. -amount .. " Bones" )
	end
end

hook.Add( "GR_BonesMoved", "gr_parity_notice", function( from, to, amount, source )
	if Parity.SILENT_SOURCES[ source ] then return end
	bonesNotice( from, -amount, source )
	bonesNotice( to, amount, source )
end )

-- Get-up line -------------------------------------------------------------------------------

Parity.STANDUP_LINES = {
	" groans and struggles up.",
	" painfully puts himself back together.",
	" joins the living once more.",
	" is alive once more.",
	" struggles alive.",
	"'s body says \"Not yet.\"",
	" lives!!!",
	" won't die.",
}

hook.Add( "GR_PlayerRestored", "gr_parity_standup", function( ply )
	local txt = " gets up."
	if math.random( 1, 10 ) == 1 then txt = Parity.STANDUP_LINES[ math.random( #Parity.STANDUP_LINES ) ] end
	Chat.Area( ply, Color( 80, 125, 80 ), ply:Nick() .. txt )
	ply:EmitSound( "placenta/speech/jump.wav" )
end )

-- Call Korpsman -----------------------------------------------------------------------------

local function korpsmen()
	local out = {}
	for _, p in player.Iterator() do
		if p:FateHas( "CanRevive" ) and p:Alive() and not p:GetPassedOut() then table.insert( out, p ) end
	end
	return out
end

-- Returns true, or false and the refusal the player was told.
function Parity.CallKorpsman( ply )
	local function refuse( why ) Notify( ply, why ) return false, why end
	if not ply:Alive() or ply:IsGhost() then return refuse( "Korpsmen cannot cure death." ) end
	if not ply:FateHas( "Citizen" ) then return refuse( "This action is only available to citizens." ) end
	if ply:Health() > Parity.CALL_MAX_HEALTH then
		return refuse( "No Korpsman would consider your condition a medical emergency." )
	end
	local km = korpsmen()
	if #km == 0 then return refuse( "There are no korpsmen to answer." ) end
	if not Econ.Transfer( ply, Econ.TREASURY, Parity.CALL_COST, "korpsman call" ) then
		return refuse( "An emergency call requires 50 Bones. It sucks to be poor!" )
	end
	ply:SetEmergency( true )
	Chat.Tell( ply, Color( 200, 200, 0 ), "Korpsmen have been alerted to your location." )
	for _, p in ipairs( km ) do p:EmitSound( "npc/turret_floor/active.wav" ) end
	Chat.Big( km, Color( 200, 0, 0 ), "Someone is requesting assistance! You will get paid 50 bones after fully healing them." )
	Log.Debug( "parity", "%s called the korpsmen", ply:Nick() )
	return true
end

Net.Receive( "gr_call_korpsman", { rate = 1, alive = true }, function( ply ) Parity.CallKorpsman( ply ) end )

local function healed( ply ) return ply:Health() >= Medicine.MaxHealth( ply ) end

-- Whoever (with CanRevive) treats an emergency patient to full health is paid the call.
hook.Add( "GR_Treated", "gr_parity_emergency", function( doctor, target )
	if not target:GetEmergency() or not healed( target ) then return end
	target:SetEmergency( false )
	if doctor ~= target and doctor:FateHas( "CanRevive" ) then
		Econ.Transfer( Econ.TREASURY, doctor, Parity.CALL_COST, "emergency paid" )
	end
end )

-- Healed some other way (regeneration): the emergency is over and nobody is paid.
Sched.EachPlayer( "emergency", 1, function( ply )
	if ply:GetEmergency() and ( not ply:Alive() or healed( ply ) ) then ply:SetEmergency( false ) end
end )

-- Unholster warning -------------------------------------------------------------------------

Parity.UNHOLSTER_COOLDOWN = 3
Parity.UNHOLSTER_FIRE_DELAY = 1.5

hook.Add( "GR_Unholstered", "gr_parity_unholster", function( ply, wep )
	if not wep.Firearm or ( ply:FateHas( "AccuracyMulti" ) or 1 ) <= 1 then return end
	if CurTime() < ( ply.GR_UnholsterWarnAt or 0 ) then return end
	ply.GR_UnholsterWarnAt = CurTime() + Parity.UNHOLSTER_COOLDOWN
	ply:EmitSound( "placenta/unholster.wav", 85 )
	Chat.Area( ply, Color( 220, 220, 0 ), ply:Nick() .. " prepares to fire!" )
	wep:SetNextPrimaryFire( CurTime() + Parity.UNHOLSTER_FIRE_DELAY )
end )

-- Pain and death sounds ---------------------------------------------------------------------

Parity.PAIN_SOUNDS = {
	generic = { "vo/npc/male01/ow01.wav", "vo/npc/male01/ow02.wav", "vo/npc/male01/pain01.wav", "vo/npc/male01/pain02.wav",
		"vo/npc/male01/pain03.wav", "vo/npc/male01/pain04.wav", "vo/npc/male01/pain05.wav", "vo/npc/male01/pain06.wav",
		"vo/npc/male01/pain07.wav", "vo/npc/male01/pain08.wav", "vo/npc/male01/pain09.wav", "vo/npc/male01/startle01.wav",
		"vo/npc/male01/startle02.wav", "vo/npc/male01/imhurt01.wav", "vo/npc/male01/imhurt02.wav", "vo/npc/male01/mygut02.wav" },
	gut = { "vo/npc/male01/hitingut01.wav", "vo/npc/male01/hitingut02.wav" },
	arm = { "vo/npc/male01/myarm01.wav", "vo/npc/male01/myarm02.wav" },
	leg = { "vo/npc/male01/myleg01.wav", "vo/npc/male01/myleg02.wav" },
}
local AREA = {
	[ HITGROUP_LEFTARM ] = "arm", [ HITGROUP_RIGHTARM ] = "arm",
	[ HITGROUP_LEFTLEG ] = "leg", [ HITGROUP_RIGHTLEG ] = "leg",
}

local function pick( list ) return list and #list > 0 and list[ math.random( #list ) ] or nil end

-- The sound `ply` grunts for a hit on `hitgroup`, or nil.
function Parity.PainSound( ply, hitgroup )
	local own = ply:FateHas( "PainSounds" )
	return pick( own ) or pick( Parity.PAIN_SOUNDS[ AREA[ hitgroup ] or "generic" ] )
end

-- Grunts on hits that leave the player standing, at most every 1-3 s. Runs before Health applies the hit.
Damage.Add( "Consciousness", "pain_grunt", function( ply, dmg, ctx )
	ply.GR_PainGroup = ctx.hitgroup
	if ply:IsGhost() or not ply:Alive() or dmg:GetDamage() <= 0 or dmg:GetDamage() >= ply:Health() then return end
	if CurTime() < ( ply.GR_NextGrunt or 0 ) then return end
	ply.GR_NextGrunt = CurTime() + math.random( 1, 3 )
	local snd = Parity.PainSound( ply, ctx.hitgroup )
	if snd then ply:EmitSound( snd ) end
end )

-- Going down screams, unless the last hit was to the head.
hook.Add( "GR_PlayerDowned", "gr_parity_scream", function( ply, rag )
	local group = ply.GR_PainGroup
	ply.GR_PainGroup = nil
	if group == HITGROUP_HEAD then return end
	local snd = pick( ply:FateHas( "DeathSounds" ) )
	if snd and IsValid( rag ) then rag:EmitSound( snd ) end
end )

-- Final death screams again, unless the fate says not to or the head is gone.
hook.Add( "GR_CorpseDied", "gr_parity_scream", function( rag, rec )
	local f = Fates.Get( rec.fate )
	if not f or f.NoFinalDeathSound or rag.GR_Headless then return end
	local snd = pick( f.DeathSounds )
	if snd then rag:EmitSound( snd ) end
end )

-- Intro texts -------------------------------------------------------------------------------

hook.Add( "GR_FateEnter", "gr_parity_intro", function( ply, f, reason )
	if reason ~= "pick" or not f.IntroTexts then return end
	for _, line in ipairs( f.IntroTexts ) do
		Chat.Tell( ply, line[ 1 ], string.Replace( line[ 2 ], "%name", ply:Nick() ) )
	end
end )
