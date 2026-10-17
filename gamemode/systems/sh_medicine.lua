-- Medicine: natural regeneration, lodged bullets, the revive fee, surgery and the lovebox (step 11.2).
-- Everything here reads fate data, never fate names:
--   RegenMulti = 3       regenerates that many times faster
--   ReviveFee = true     reviving someone takes the Economy's revive_fee percent of their carried bones
--   Surgeon = true       may operate (needs surgical_tools in the inventory)
--   Lovebox = true       gets the lovebox heal once the Kaiser has bought this fate's upgrade
--
-- A Kaiser upgrade for a fate is the public world value "upgrade_<fateId>" (step 11.4), reset each round.
--
-- Surgery is a timed action offered through Interact. The server rolls failure when the action
-- finishes; nothing the client sends can choose the outcome (B19).
Medicine = Medicine or {}

-- A lodged bullet: no natural regeneration and health capped until a surgeon takes it out.
State.Field( "Bullet", "Bool", 0, State.OWNER, false )

Medicine.SURGERY_RANGE = 100
Medicine.LOVEBOX_RANGE = 100

function Medicine.Upgraded( ply )
	local f = ply:GetFateDef()
	return f ~= nil and WorldState.Get( "upgrade_" .. f.id, false ) == true
end

local function canOperate( ply, ent )
	return ent:IsPlayer() and ent ~= ply and ent:Alive() and not ent:IsGhost()
		and not ply:IsGhost() and ply:FateHas( "Surgeon" ) == true
end

-- Procedures: duration in seconds, fail chance 0..1 (tests set it to 0 or 1), and server-side
-- need( ply, target ) -> why-not and done( ply, target ) for a success.
Medicine.PROCEDURES = {
	{
		-- Also treats Injured (step 7): the cap on max health comes off, then the wounds are stitched.
		id = "heal", label = "Surgery: stitch wounds", duration = 8, fail = 0.15,
		need = function( _, t )
			if t:Health() >= Medicine.MaxHealth( t ) and not t:GetInjured() then return "They have no wounds to stitch." end
		end,
		done = function( _, t )
			if t:GetInjured() then Corpse.SetInjured( t, false ) end
			t:SetHealth( Medicine.MaxHealth( t ) )
		end,
	},
	{
		id = "pox", label = "Surgery: cut out the pox", duration = 12, fail = 0.3,
		need = function( _, t ) if Needs.Get( t, "Pox" ) <= 0 then return "They have no pox." end end,
		done = function( _, t ) Needs.Add( t, "Pox", -Needs.Def( "Pox" ).max, "surgery" ) end,
	},
	{
		id = "bullet", label = "Surgery: remove a bullet", duration = 10, fail = 0.25,
		need = function( _, t ) if not t:GetBullet() then return "There is no bullet in them." end end,
		done = function( _, t ) t:SetBullet( false ) end,
	},
}

function Medicine.Procedure( id )
	for _, p in ipairs( Medicine.PROCEDURES ) do
		if p.id == id then return p end
	end
end

-- The menu shows every procedure to a surgeon; whether the patient needs it is server knowledge
-- (pox and bullets are OWNER fields), so the server answers that when the option is picked.
for _, proc in ipairs( Medicine.PROCEDURES ) do
	Interact.Add( "surgery_" .. proc.id, {
		label = proc.label,
		range = Medicine.SURGERY_RANGE,
		show = canOperate,
		run = function( ply, ent ) Medicine.StartSurgery( ply, ent, proc.id ) end,
	} )
end

Interact.Add( "lovebox", {
	label = "Lovebox: heal",
	range = Medicine.LOVEBOX_RANGE,
	show = function( ply, ent )
		return ent:IsPlayer() and ent ~= ply and ent:Alive() and not ent:IsGhost() and not ply:IsGhost()
			and ply:FateHas( "Lovebox" ) == true and Medicine.Upgraded( ply )
	end,
	run = function( ply, ent ) Medicine.Lovebox( ply, ent ) end,
} )

if CLIENT then return end

-- Server ------------------------------------------------------------------------------------

Medicine.REGEN_RATE = 0.1          -- HP per second for an ordinary body
Medicine.BULLET_CHANCE = 0.3       -- a bullet hit that doesn't kill lodges with this chance
Medicine.BULLET_CAP = 0.75         -- fraction of max health a body with a bullet can't heal past
Medicine.FAIL_DAMAGE = 15          -- a botched operation hurts the patient (never kills)
Medicine.LOVEBOX_HEAL = 25
Medicine.LOVEBOX_COOLDOWN = 30

-- The most health `ply` may have right now.
function Medicine.MaxHealth( ply )
	local max = ply:GetMaxHealth()
	if ply:GetBullet() then return math.max( 1, math.floor( max * Medicine.BULLET_CAP ) ) end
	return max
end

-- Heals `amount`, up to MaxHealth. Never lowers health.
function Medicine.Heal( ply, amount )
	local cap = Medicine.MaxHealth( ply )
	if ply:Health() >= cap then return end
	ply:SetHealth( math.min( cap, ply:Health() + amount ) )
end

-- Regeneration -------------------------------------------------------------------------------

-- `dt` seconds of natural healing. Fractions carry over, so slow rates still add up.
function Medicine.Regen( ply, dt )
	if not ply:Alive() or ply:IsGhost() then return end
	if ply:GetBullet() then
		local cap = Medicine.MaxHealth( ply )
		if ply:Health() > cap then ply:SetHealth( cap ) end
		ply.GR_RegenFrac = 0
		return
	end
	if ply:Health() >= ply:GetMaxHealth() then
		ply.GR_RegenFrac = 0
		return
	end
	local acc = ( ply.GR_RegenFrac or 0 ) + Medicine.REGEN_RATE * ( ply:FateHas( "RegenMulti" ) or 1 ) * dt
	local whole = math.floor( acc )
	ply.GR_RegenFrac = acc - whole
	if whole > 0 then Medicine.Heal( ply, whole ) end
end

Sched.EachPlayer( "regen", 1, function( ply ) Medicine.Regen( ply, 1 ) end )

hook.Add( "GR_FateEnter", "gr_medicine", function( ply )
	ply.GR_RegenFrac = 0
	ply.GR_LoveboxAt = nil
end )

-- Bullets ------------------------------------------------------------------------------------

-- After armor, so only a hit that reaches the body can lodge, and before Health applies it.
Damage.Add( "Consciousness", "bullet", function( ply, dmg )
	if bit.band( dmg:GetDamageType(), DMG_BULLET ) == 0 or dmg:GetDamage() <= 0 then return end
	if dmg:GetDamage() >= ply:Health() or ply:GetBullet() then return end
	if math.random() < Medicine.BULLET_CHANCE then
		ply:SetBullet( true )
		Notify( ply, "A bullet is lodged in you. It won't heal until it's cut out." )
	end
end )

-- Revive fee ---------------------------------------------------------------------------------

-- Only a revive pays a fee; getting up on your own (GR_PlayerGotUp) doesn't. sh_corpse.lua runs
-- GR_PlayerRestored (sv_econ hands the body's bones back) before this, but the fee is taken from
-- wherever the bones are now (corpse first), so it doesn't depend on that order.
hook.Add( "GR_PlayerRevived", "gr_medicine", function( ply, rag, doctor )
	if not IsValid( doctor ) or not doctor:IsPlayer() or doctor == ply or not doctor:FateHas( "ReviveFee" ) then return end
	local rec = Corpse.Get( rag ) or rag.GR_Corpse
	local onBody = rec and rec.bones or 0
	local carried = onBody + ply:GetBones()
	local fee = math.floor( carried * Econ.Setting( "revive_fee" ) / 100 )
	if fee <= 0 then return end
	local fromBody = math.min( fee, onBody )
	if fromBody > 0 then Econ.Transfer( rag, doctor, fromBody, "revive fee" ) end
	if fee > fromBody then Econ.Transfer( ply, doctor, fee - fromBody, "revive fee" ) end
	Notify( ply, string.format( "%s took %d bones for bringing you back.", doctor:Nick(), fee ) )
	Notify( doctor, string.format( "You took %d bones for the revive.", fee ) )
end )

-- Surgery ------------------------------------------------------------------------------------

function Medicine.StartSurgery( ply, target, id )
	local proc = Medicine.Procedure( id )
	if not proc or not IsValid( target ) or not canOperate( ply, target ) then return false end
	if Inventory.Count( ply, "surgical_tools" ) < 1 then
		Notify( ply, "You need surgical tools." )
		return false
	end
	local why = proc.need( ply, target )
	if why then
		Notify( ply, why )
		return false
	end
	local ok = Actions.Start( ply, "surgery", target, proc.duration, {
		label = proc.label .. " on " .. target:Nick(),
		range = Medicine.SURGERY_RANGE,
		cancelOnDamage = true,
		canContinue = function( _, t ) return IsValid( t ) and t:Alive() and not t:IsGhost() end,
		onDone = function( doctor, t ) Medicine.FinishSurgery( doctor, t, proc ) end,
	} )
	if ok then Notify( target, ply:Nick() .. " begins operating on you." ) end
	return ok
end

function Medicine.FinishSurgery( doctor, target, proc )
	if math.random() < proc.fail then
		target:SetHealth( math.max( 1, target:Health() - Medicine.FAIL_DAMAGE ) )
		Notify( doctor, "Your hand slips. The operation failed." )
		Notify( target, "The operation went wrong." )
		Log.Debug( "medicine", "%s botched %s on %s", doctor:Nick(), proc.id, target:Nick() )
		return false
	end
	proc.done( doctor, target )
	Notify( doctor, "The operation succeeded." )
	Notify( target, "The operation succeeded." )
	hook.Run( "GR_Treated", doctor, target )
	Log.Debug( "medicine", "%s did %s on %s", doctor:Nick(), proc.id, target:Nick() )
	return true
end

-- Lovebox --------------------------------------------------------------------------------------

function Medicine.Lovebox( ply, target )
	if not ply:FateHas( "Lovebox" ) or not Medicine.Upgraded( ply ) then return false end
	if not IsValid( target ) or not target:IsPlayer() or not target:Alive() or target:IsGhost() then return false end
	local wait = ( ply.GR_LoveboxAt or -math.huge ) + Medicine.LOVEBOX_COOLDOWN - CurTime()
	if wait > 0 then
		Notify( ply, string.format( "The lovebox is recharging. %d seconds.", math.ceil( wait ) ) )
		return false
	end
	ply.GR_LoveboxAt = CurTime()
	Medicine.Heal( target, Medicine.LOVEBOX_HEAL )
	Notify( target, ply:Nick() .. " soothes you with the lovebox." )
	hook.Run( "GR_Treated", ply, target )
	return true
end
