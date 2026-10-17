-- Medicine: natural regeneration, lodged bullets, the revive fee, surgery and the lovebox (step 11.2).
-- Everything here reads fate data, never fate names:
--   RegenMulti = 3          regenerates that many times faster
--   ReviveFee = true        reviving someone takes the Economy's revive_fee percent of their carried bones
--   Surgeon = true          may operate (needs a blade or the procedure's consumable)
--   SurgeryFailChance = 10  base failure percent, plus 100 minus the tool's success percent
--
-- The first successful revive promotes a korpsman (UpgradedMedic) and gives them a lovebox, whose
-- SWEP is entities/weapons/weapon_gr_lovebox.lua. Surgery is one timed action offered through
-- Interact; both players are frozen and the server rolls the outcome when it finishes (B19).
Medicine = Medicine or {}

-- A lodged bullet: no natural regeneration and health capped until a surgeon takes it out.
State.Field( "Bullet", "Bool", 0, State.OWNER, false )

Medicine.SURGERY_RANGE = 100
Medicine.LOVEBOX_RANGE = 85

local function canOperate( ply, ent )
	return ent:IsPlayer() and ent ~= ply and ent:Alive() and not ent:IsGhost()
		and not ply:IsGhost() and ply:FateHas( "Surgeon" ) == true
end

-- Parasites live on the server; the lovebox's Reload and parasitectomy take them out.
function Medicine.Parasites( ply ) return ply.GR_Parasites or 0 end
function Medicine.SetParasites( ply, n ) ply.GR_Parasites = math.max( 0, n ) end

-- The best blade carried: returns its item id and a success percent rolled from its range.
function Medicine.BestBlade( ply )
	local bestId, bestPct
	for id in pairs( Inventory.Items( ply ) ) do
		local def = Items.Get( id )
		local blade = def and def.Tags and def.Tags.Blade
		if blade and ( not bestPct or blade[ 2 ] > bestPct ) then bestId, bestPct = id, blade[ 2 ] end
	end
	if not bestId then return end
	local r = Items.Get( bestId ).Tags.Blade
	return bestId, math.random( r[ 1 ], r[ 2 ] )
end

-- The first carried item tagged `tag` (a consumable), or nil.
function Medicine.FindTagged( ply, tag )
	for id in pairs( Inventory.Items( ply ) ) do
		local def = Items.Get( id )
		if def and def.Tags and def.Tags[ tag ] then return id end
	end
end

local function pox( t, lo, hi ) Needs.Add( t, "Pox", math.random( lo, hi ), "surgery" ) end

-- Procedures: duration in seconds; tool = "blade" or a consumable tag; fail is an optional 0..1
-- override (tests); need( ply, target ) -> why-not; done / failed( ply, target ).
Medicine.PROCEDURES = {
	{
		id = "seal", label = "Seal Wounds", duration = 5, tool = "Seal", steps = 1, consume = true,
		need = function( _, t ) if Needs.Get( t, "Pox" ) <= 0 and t:Health() >= Medicine.MaxHealth( t ) then return "They have no wounds to seal." end end,
		done = function( _, t ) pox( t, -10, -5 ) end,
		failed = function( _, t ) pox( t, 5, 10 ) end,
	},
	{
		id = "bloodletting", label = "Bloodletting", duration = 10, tool = "blade", steps = 2,
		need = function( _, t ) if Needs.Get( t, "Pox" ) <= 0 then return "They have no pox." end end,
		done = function( _, t ) Needs.Add( t, "Pox", -40, "surgery" ) end,
		failed = function( _, t ) Needs.Add( t, "Pox", -5, "surgery" ) end,
	},
	{
		id = "thinning", label = "Blood thinning", duration = 15, tool = "blade", steps = 3,
		done = function( _, t ) Needs.Add( t, "Dryness", 50, "surgery" ) end,
	},
	{
		id = "sanguinary", label = "Sanguinary Remedy", duration = 12, tool = "Blood", steps = 2, consume = true,
		need = function( _, t ) if t:Health() >= Medicine.MaxHealth( t ) then return "They have blood enough." end end,
		done = function( _, t ) Medicine.Heal( t, 25 ) end,
	},
	{
		id = "parasitectomy", label = "Parasitectomy", duration = 10, tool = "blade", steps = 2,
		done = function( doc, t )
			if Medicine.Parasites( t ) > 0 then
				Medicine.SetParasites( t, Medicine.Parasites( t ) - 1 )
				Items.Spawn( "parasite", 1, t:GetPos() + Vector( 0, 0, 16 ) )
			else
				Needs.Add( doc, "Pox", 10, "surgery" )
				Notify( doc, "You found no parasite, and what you touched has infected you." )
			end
		end,
		failed = function( _, t ) pox( t, 5, 5 ) end,
	},
	{
		id = "laparotomy", label = "Exploratory laparotomy", duration = 6, tool = "blade", steps = 1,
		done = function( doc, t )
			Notify( doc, string.format( "%s: %d/%d health, pox %d, %d parasites%s%s.", t:Nick(), t:Health(), t:GetMaxHealth(),
				Needs.Get( t, "Pox" ), Medicine.Parasites( t ), t:GetBullet() and ", a bullet" or "", t:GetInjured() and ", crippled" or "" ) )
		end,
	},
	{
		id = "cripplement", label = "Cripplement solution", duration = 15, tool = "blade", steps = 3,
		need = function( _, t ) if not t:GetInjured() then return "They are not crippled." end end,
		done = function( _, t ) Corpse.SetInjured( t, false ); t:SetHealth( t:GetMaxHealth() ) end,
	},
	{
		id = "plastic", label = "Plastic surgery", duration = 15, tool = "blade", steps = 3,
		need = function( _, t ) if not t.GR_Charred then return "They are not charred." end end,
		done = function( _, t ) t.GR_Charred = nil end,
	},
	{
		id = "cardiac", label = "Cardiac encouragement", duration = 24, tool = "blade", steps = 4,
		need = function( _, t ) if not t.GR_HeartAttackAt then return "Their heart is fine." end end,
		done = function( _, t ) t.GR_HeartAttackAt = nil end,
	},
	{
		id = "rage", label = "Rage therapy", duration = 14, tool = "blade", steps = 3,
		done = function( doc ) Needs.Add( doc, "Despair", -30, "surgery" ) end,
	},
	{
		id = "bullet", label = "Remove a bullet", duration = 10, tool = "blade", steps = 2,
		need = function( _, t ) if not t:GetBullet() then return "There is no bullet in them." end end,
		done = function( _, t ) t:SetBullet( false ) end,
	},
}

function Medicine.Procedure( id )
	for _, p in ipairs( Medicine.PROCEDURES ) do
		if p.id == id then return p end
	end
end

-- Whether the patient needs it is server knowledge, so the server answers when the option is picked.
for _, proc in ipairs( Medicine.PROCEDURES ) do
	Interact.Add( "surgery_" .. proc.id, {
		label = proc.label,
		range = Medicine.SURGERY_RANGE,
		show = canOperate,
		run = function( ply, ent ) Medicine.StartSurgery( ply, ent, proc.id ) end,
	} )
end

if CLIENT then return end

-- Server ------------------------------------------------------------------------------------

Medicine.REGEN_RATE = 0.1          -- HP per second for an ordinary body
Medicine.BULLET_CHANCE = 0.3       -- a bullet hit that doesn't kill lodges with this chance
Medicine.BULLET_CAP = 0.75         -- fraction of max health a body with a bullet can't heal past
Medicine.FAIL_DAMAGE = 10          -- a botched operation hurts the patient (never kills)
Medicine.FAIL_DESPAIR = 10         -- and weighs on the surgeon
Medicine.STUN_TIME = 2             -- an interrupted patient stays frozen this long
Medicine.MALPRACTICE_LEVEL = 15
Medicine.MALPRACTICE_TIME = 300

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
	ply.GR_UpgradedMedic = nil
	ply.GR_Charred = nil
end )

function Medicine.UpgradedMedic( ply ) return ply.GR_UpgradedMedic == true end

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
-- wherever the bones are now (corpse first), so it doesn't depend on that order. The first revive
-- also promotes the reviver and hands them a lovebox, fee or no fee.
hook.Add( "GR_PlayerRevived", "gr_medicine", function( ply, rag, doctor )
	if not IsValid( doctor ) or not doctor:IsPlayer() or doctor == ply or not doctor:FateHas( "ReviveFee" ) then return end
	if not doctor.GR_UpgradedMedic then
		doctor.GR_UpgradedMedic = true
		Inventory.Add( doctor, "lovebox", 1 )
		Notify( doctor, "Your first revive earned you a lovebox." )
	end
	local rec = Corpse.Get( rag ) or rag.GR_Corpse
	local onBody = rec and rec.bones or 0
	local carried = onBody + ply:GetBones()
	local fee = math.floor( carried * Econ.Setting( "revive_fee" ) / 100 )
	if fee <= 0 then return end
	local fromBody = math.min( fee, onBody )
	if fromBody > 0 then Econ.Transfer( rag, doctor, fromBody, "revive_fee" ) end
	if fee > fromBody then Econ.Transfer( ply, doctor, fee - fromBody, "revive_fee" ) end
	Notify( ply, string.format( "%s took %d bones for bringing you back.", doctor:Nick(), fee ) )
	Notify( doctor, string.format( "You took %d bones for the revive.", fee ) )
end )

-- Surgery ------------------------------------------------------------------------------------

local function chat( ply, col, text )
	if IsValid( ply ) then ply:ChatPrint( text ) end
end

-- Both players hold still for the operation. An interrupted patient stays stunned a moment longer.
local function release( doctor, target, stun )
	if IsValid( doctor ) then doctor:Freeze( false ) end
	if not IsValid( target ) then return end
	if stun and target:Alive() then
		target:Freeze( true )
		timer.Simple( Medicine.STUN_TIME, function() if IsValid( target ) and not target.GR_Action then target:Freeze( false ) end end )
	else
		target:Freeze( false )
	end
end

-- The tool for a procedure: returns toolId, success percent (a consumable is always 100).
local function findTool( ply, proc )
	if proc.tool == "blade" then return Medicine.BestBlade( ply ) end
	local id = Medicine.FindTagged( ply, proc.tool )
	if id then return id, 100 end
end

function Medicine.StartSurgery( ply, target, id )
	local proc = Medicine.Procedure( id )
	if not proc or not IsValid( target ) or not canOperate( ply, target ) then return false end
	local tool, pct = findTool( ply, proc )
	if not tool then
		Notify( ply, proc.tool == "blade" and "You need a blade." or "You need something to " .. string.lower( proc.label ) .. " with." )
		return false
	end
	local why = proc.need and proc.need( ply, target )
	if why then
		Notify( ply, why )
		return false
	end
	local ok = Actions.Start( ply, "surgery", target, proc.duration, {
		label = proc.label .. " on " .. target:Nick(),
		range = Medicine.SURGERY_RANGE,
		cancelOnDamage = true,
		canContinue = function( _, t ) return IsValid( t ) and t:Alive() and not t:IsGhost() end,
		onDone = function( doctor, t ) Medicine.FinishSurgery( doctor, t, proc, tool, pct ) end,
		onCancel = function( doctor, t )
			release( doctor, t, true )
			chat( doctor, nil, "You haphazardly interrupted the " .. string.lower( proc.label ) .. "." )
			chat( t, nil, doctor:Nick() .. " haphazardly interrupted the operation." )
		end,
	} )
	if not ok then return false end
	ply:Freeze( true )
	target:Freeze( true )
	-- Every step cuts the patient a little.
	local steps = proc.steps or 1
	for i = 1, steps do
		timer.Simple( proc.duration * i / ( steps + 1 ), function()
			local a = ply.GR_Action
			if IsValid( ply ) and IsValid( target ) and a and a.target == target and target:Alive() then
				target:SetHealth( math.max( 1, target:Health() - 1 ) )
			end
		end )
	end
	Notify( target, ply:Nick() .. " begins operating on you." )
	return true
end

-- Rolled on the server when the timer runs out (B19). pct is the tool's success percent.
function Medicine.FinishSurgery( doctor, target, proc, tool, pct )
	release( doctor, target, false )
	local chance = proc.fail
	if chance == nil then chance = ( ( doctor:FateHas( "SurgeryFailChance" ) or 10 ) + 100 - ( pct or 100 ) ) / 100 end
	local patientPolice = target:FateHas( "Police" ) == true
	if proc.consume and tool then Inventory.Remove( doctor, tool, 1 ) end
	if math.random() < chance then
		target:SetHealth( math.max( 1, target:Health() - Medicine.FAIL_DAMAGE ) )
		Needs.Add( doctor, "Despair", Medicine.FAIL_DESPAIR, "surgery" )
		if proc.failed then proc.failed( doctor, target ) end
		local named = proc.label
		if math.random( 6 ) == 1 then
			local other = Medicine.PROCEDURES[ math.random( #Medicine.PROCEDURES ) ]
			named = other.label
		end
		chat( doctor, nil, "You botched a " .. string.lower( named ) .. " surgery." )
		chat( target, nil, doctor:Nick() .. " botched a " .. string.lower( named ) .. " surgery on you." )
		if patientPolice then
			Crime.AddEvidence( doctor, "malpractice", Medicine.MALPRACTICE_LEVEL, Medicine.MALPRACTICE_TIME )
		end
		if tool and not proc.consume and math.random( 0, 10 ) < chance * 10 and Items.Get( tool ) and Items.Get( tool ).Tags.Blade then
			Inventory.Remove( doctor, tool, 1 )
			Notify( doctor, "Your blade broke in the wound." )
		end
		Log.Debug( "medicine", "%s botched %s on %s", doctor:Nick(), proc.id, target:Nick() )
		return false
	end
	proc.done( doctor, target )
	local steps = proc.steps or 1
	Medicine.Heal( target, steps )
	if patientPolice then Crime.TakeEvidence( doctor, "malpractice" ) end
	chat( doctor, nil, "The " .. string.lower( proc.label or proc.id ) .. " succeeded." )
	chat( target, nil, "The " .. string.lower( proc.label or proc.id ) .. " on you succeeded." )
	hook.Run( "GR_Treated", doctor, target )
	Log.Debug( "medicine", "%s did %s on %s", doctor:Nick(), proc.id, target:Nick() )
	return true
end
