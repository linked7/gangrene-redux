-- Rotting and corpse recycling, as in Gangrene. A dead body goes through four stages: fresh,
-- fast zombie, charred, skeleton. Each stage keeps 3/4 of the bones. A cop can feed a body to
-- the corpse washer for a payout. Bleedout (downed) bodies never rot. Fire (stage 5) is left out.
Rotting = Rotting or {}

Rotting.STAGES = {
	{ word = "Fresh Cadaver" },
	{ word = "Rotting", model = "models/zombie/fast.mdl" },
	{ word = "Charred", model = "models/player/charple.mdl" },
	{ word = "Skeleton", model = "models/player/skeleton.mdl" },
}
Rotting.FIRST = 60          -- seconds in stage 1 (a fate's DecayOverride replaces it)
Rotting.LATER = 120         -- seconds in stages 2 and 3
Rotting.SKELETON_LIFE = 900 -- how long a skeleton lasts before the despawn cap takes it
Rotting.KEEP = 0.75
Rotting.REWARD_MIN, Rotting.REWARD_MAX, Rotting.PAY_MAX = 30, 500, 150
Rotting.CLEAN_MIN, Rotting.CLEAN_MAX = 28, 32
Rotting.DESPAIR = 2
Rotting.RANGE = 120
Rotting.MIASMA_RANGE = 250
Rotting.MIASMA_POX = { 0.5, 1.5, 3 }   -- Pox per second by stage; the skeleton is dry and gives off nothing
Rotting.MIASMA_DAMAGE = { 0, 1, 2 }    -- poison damage per second by stage

Net.Pool( "gr_rot" )

function Rotting.Reward( bones )
	return math.Clamp( bones, Rotting.REWARD_MIN, Rotting.REWARD_MAX )
end
function Rotting.CopCut( reward )
	return math.min( Rotting.PAY_MAX, math.floor( reward / 4 ) + 30 )
end

if CLIENT then
	Rotting.Info = Rotting.Info or {}
	Net.Receive( "gr_rot", nil, function()
		local idx = net.ReadUInt( 16 )
		Rotting.Info[ idx ] = { stage = net.ReadUInt( 3 ), start = net.ReadFloat(), finish = net.ReadFloat() }
	end )

	-- The miasma: a purple fog that thickens with the stage, seen from afar
	local nextPuff = 0
	hook.Add( "Think", "gr_rotting_miasma", function()
		if CurTime() < nextPuff then return end
		nextPuff = CurTime() + 0.25
		local em
		for idx, info in pairs( Rotting.Info ) do
			local rag = Entity( idx )
			local n = Rotting.MIASMA_POX[ info.stage ]
			if n and IsValid( rag ) and not rag:IsDormant() and rag:GetPos():DistToSqr( EyePos() ) < 1200 * 1200 then
				em = em or ParticleEmitter( EyePos(), false )
				for _ = 1, info.stage do
					local pos = rag:GetPos() + VectorRand() * 40
					local part = em:Add( "particle/smokesprites_000" .. math.random( 1, 9 ), pos )
					if part then
						part:SetDieTime( math.Rand( 3, 5 ) )
						part:SetStartAlpha( 40 + info.stage * 15 ); part:SetEndAlpha( 0 )
						part:SetStartSize( 30 ); part:SetEndSize( 60 + info.stage * 40 )
						part:SetColor( 110 + math.random( 0, 40 ), 20, 140 + math.random( 0, 40 ) )
						part:SetVelocity( Vector( math.Rand( -8, 8 ), math.Rand( -8, 8 ), math.Rand( 8, 22 ) ) )
						part:SetGravity( Vector( 0, 0, 4 ) )
						part:SetRoll( math.Rand( 0, 360 ) )
					end
				end
			end
		end
		if em then em:Finish() end
	end )
	return
end

local FLIES = { "ambient/creatures/flies1.wav", "ambient/creatures/flies2.wav", "ambient/creatures/flies3.wav",
	"ambient/creatures/flies4.wav", "ambient/creatures/flies5.wav" }

local function stageLength( rec, stage )
	if stage == 1 then
		local f = rec.fate and Fates.Get( rec.fate )
		return ( f and f.DecayOverride ) or Rotting.FIRST
	end
	if stage < #Rotting.STAGES then return Rotting.LATER end
	return Rotting.SKELETON_LIFE
end

local function sync( rag, rec, to )
	net.Start( "gr_rot" )
	net.WriteUInt( rag:EntIndex(), 16 )
	net.WriteUInt( rec.rotStage, 3 )
	net.WriteFloat( rec.rotStart )
	net.WriteFloat( rec.rotFinish )
	if to then net.Send( to ) else net.Broadcast() end
end

local function begin( rag, rec, stage, now )
	rec.rotStage = stage
	rec.rotStart = now
	rec.rotFinish = now + stageLength( rec, stage )
	rec.decayAt = rec.rotFinish + 5 -- the despawn waits for the last stage
end

-- Swaps the body for the next stage's ragdoll, keeping its record, inventory and bones.
function Rotting.Advance( rag )
	local rec = Corpse.Get( rag )
	if not rec or rec.state ~= "dead" or not rec.rotStage then return nil end
	local nextStage = rec.rotStage + 1
	local def = Rotting.STAGES[ nextStage ]
	if not def then return nil end
	local new = ents.Create( "prop_ragdoll" )
	if not IsValid( new ) then return nil end
	new:SetModel( def.model )
	new:SetPos( rag:GetPos() )
	new:SetAngles( rag:GetAngles() )
	new:Spawn()
	new:SetCollisionGroup( COLLISION_GROUP_WEAPON )
	local now = CurTime()
	Corpse.Rebind( rag, new )
	Econ.TrackCorpse( new )
	-- bones: 3/4 of the old pile go back to the treasury
	local keep = math.floor( ( rec.bones or 0 ) * Rotting.KEEP )
	local lost = ( rec.bones or 0 ) - keep
	if lost > 0 then Econ.Transfer( new, Econ.TREASURY, lost, "corpse rotted" ) end
	begin( new, rec, nextStage, now )
	rag:Remove()
	-- frozen for a second so it settles
	for i = 0, new:GetPhysicsObjectCount() - 1 do
		local p = new:GetPhysicsObjectNum( i )
		if IsValid( p ) then p:EnableMotion( false ) end
	end
	rec.thawAt = now + 1
	new:EmitSound( FLIES[ math.random( #FLIES ) ], 70 )
	Corpse.Sync( new )
	sync( new, rec )
	Log.Debug( "rotting", "%s rotted to stage %d", rec.name or "?", nextStage )
	return new
end

hook.Add( "GR_CorpseDied", "gr_rotting", function( rag, rec )
	begin( rag, rec, 1, CurTime() )
	sync( rag, rec )
	Corpse.Sync( rag )
end )

hook.Add( "GR_PlayerReady", "gr_rotting", function( ply )
	for rag, rec in pairs( Corpse.All() ) do
		if rec.rotStage then sync( rag, rec, ply ) end
	end
end )

-- The miasma of a rotting body sickens everyone nearby who is not a sanitar
function Rotting.Miasma( rag, rec )
	local pox = rec.rotStage and Rotting.MIASMA_POX[ rec.rotStage ]
	if not pox or rec.state ~= "dead" or not IsValid( rag ) then return end
	local pos, r2 = rag:GetPos(), Rotting.MIASMA_RANGE ^ 2
	for _, ply in ipairs( player.GetAll() ) do
		local def = ply:Alive() and ply:GetFateDef()
		if def and def.id ~= "sanitar" and ply:GetPos():DistToSqr( pos ) < r2 then
			Needs.Add( ply, "Pox", pox, "miasma" )
			local dmg = Rotting.MIASMA_DAMAGE[ rec.rotStage ]
			if dmg > 0 then
				local d = DamageInfo()
				d:SetDamage( dmg ); d:SetDamageType( DMG_POISON ); d:SetAttacker( game.GetWorld() ); d:SetInflictor( game.GetWorld() )
				ply:TakeDamageInfo( d )
			end
		end
	end
end

Sched.Every( "rotting", 1, function()
	local now = CurTime()
	for rag, rec in pairs( Corpse.All() ) do
		if rec.thawAt and now >= rec.thawAt then
			rec.thawAt = nil
			for i = 0, rag:GetPhysicsObjectCount() - 1 do
				local p = rag:GetPhysicsObjectNum( i )
				if IsValid( p ) then p:EnableMotion( true ); p:Wake() end
			end
		end
		if rec.state == "dead" and rec.rotStage and rec.rotStage < #Rotting.STAGES and now >= rec.rotFinish then
			Rotting.Advance( rag )
		end
		Rotting.Miasma( rag, rec )
	end
end )

-- Recycling: a cop puts a body into the corpse washer -----------------------------------------

local function isCop( ply ) return IsValid( ply ) and ply:IsPlayer() and ply:FateHas( "Police" ) end

function Rotting.Recycle( rag, cop, washer )
	local rec = Corpse.Get( rag )
	if not rec or rec.state ~= "dead" or not IsValid( rag ) then return false end
	local reward = Rotting.Reward( rec.bones or 0 )
	local cut = Rotting.CopCut( reward )
	if IsValid( cop ) then
		local ok = Econ.Transfer( Econ.TREASURY, cop, math.min( cut, Econ.Treasury() ), "recycled corpse" )
		if ok then Notify( cop, string.format( "The washer pays you %d bones for the corpse.", math.min( cut, Econ.Treasury() + 0 ) ) ) end
		Needs.Add( cop, "Despair", Rotting.DESPAIR, "corpse washer" )
	end
	local pos = rag:GetPos()
	if #( rec.inventory or {} ) > 0 then Items.SpawnMany( rec.inventory, IsValid( washer ) and washer:GetPos() + Vector( 0, 0, 40 ) or pos, Angle() ) end
	rec.inventory = {}
	local fx = EffectData()
	fx:SetOrigin( IsValid( washer ) and washer:GetPos() or pos )
	fx:SetScale( 0.5 )
	util.Effect( "VortDispel", fx )
	rag:Remove() -- the audit sweeps the remaining bones to the treasury
	return true
end

Interact.Add( "recycle_corpse", {
	label = "Wash corpse",
	range = Rotting.RANGE,
	show = function( ply, ent )
		local rec = Corpse.Get( ent )
		return isCop( ply ) and rec ~= nil and rec.state == "dead" and rec.rotStage ~= nil
	end,
	run = function( ply, ent )
		local washer = Rotting.NearestWasher and Rotting.NearestWasher( ent )
		if not washer then Notify( ply, "Drag the body to a corpse washer first." ) return end
		local dur = math.Rand( Rotting.CLEAN_MIN, Rotting.CLEAN_MAX )
		Actions.Start( ply, "recycle", ent, dur, {
			label = "Washing corpse", range = Rotting.RANGE + 100,
			onDone = function() if IsValid( ent ) then Rotting.Recycle( ent, ply, washer ) end end,
		} )
		washer:EmitSound( "ambient/levels/canals/toxic_slime_loop1.wav", 60 )
	end,
} )

-- Washers register themselves; a body counts as "in" one when it lies within this distance.
Rotting.washers = setmetatable( {}, { __mode = "k" } )
Rotting.WASHER_RANGE = 150
function Rotting.NearestWasher( rag )
	local best, bd = nil, Rotting.WASHER_RANGE ^ 2
	for w in pairs( Rotting.washers ) do
		if IsValid( w ) then
			local d = w:GetPos():DistToSqr( rag:GetPos() )
			if d <= bd then best, bd = w, d end
		end
	end
	return best
end
