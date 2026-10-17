-- Needs: one table of definitions, one mutator, one scheduled tick.
--
--   Needs.Define( name, { rate, max, scope, thresholds = { [80] = "text" }, onTick, onChange, onMax } )
--   Needs.Add( ply, name, amount, source )   the only way to change a need (R4)
--   Needs.Modifiers                          functions ( ply, name, amount, source ) -> amount,
--                                            applied in order; quirks and fates hook in here
--
-- The exact value is a float on the server. Clients see a whole-number State field
-- (Need_<name>), which only goes out when the whole number changes.
Needs = Needs or {}
Needs.Modifiers = Needs.Modifiers or {}

local defs, order = {}, {}

function Needs.Define( name, def )
	def.name = name
	def.max = def.max or 100
	def.rate = def.rate or 0
	def.thresholds = def.thresholds or {}
	def.field = State.Field( "Need_" .. name, "UInt", 7, def.scope or State.OWNER, 0 )
	if not defs[ name ] then table.insert( order, name ) end
	defs[ name ] = def
end

function Needs.Get( ply, name )
	if CLIENT then return ply[ "GetNeed_" .. name ]( ply ) end
	return ply.GR_Needs and ply.GR_Needs[ name ] or 0
end

function Needs.All() return order end
function Needs.Def( name ) return defs[ name ] end

-- The core needs ----------------------------------------------------------------------------
-- Survival is meant to be hard: thirst fills in about 25 min and hunger in about 40, and either
-- one at 100 drains HP until the player dies. A 60-minute round needs two meals and 2-3 drinks.

local function starve( ply )
	ply:TakeDamage( 1, game.GetWorld(), game.GetWorld() )
end

Needs.Define( "Emptiness", {
	rate = 1 / 24,
	thresholds = { [ 60 ] = "Your stomach growls.", [ 80 ] = "You are starving.", [ 100 ] = "Hunger is eating you alive." },
	onTick = function( ply, v )
		if v < 100 then return end
		starve( ply )
		if Needs.Get( ply, "Despair" ) < 90 then Needs.Add( ply, "Despair", 1, "starving" ) end
	end,
} )

Needs.Define( "Dryness", {
	rate = 1 / 15,
	thresholds = { [ 60 ] = "Your mouth is dry.", [ 80 ] = "You are parched.", [ 100 ] = "Your throat cracks with thirst." },
	onTick = function( ply, v )
		if v >= 100 then starve( ply ) end
	end,
} )

Needs.Define( "Despair", {
	rate = 0, -- rises from crimes, witnessing death and hunger; never on its own
	thresholds = { [ 50 ] = "Everything feels heavy.", [ 80 ] = "Your chest is tight. You can't go on like this." },
	onMax = function( ply ) Needs.HeartAttack( ply ) end,
} )

-- Pox: sickness from dirty water. It never rises on its own and lowers max HP, down to half at 100.
Needs.Define( "Pox", {
	rate = 0,
	thresholds = { [ 30 ] = "Your skin itches and weeps.", [ 70 ] = "Sores cover your body." },
	onChange = function( ply ) Needs.ApplyPox( ply ) end,
} )

if CLIENT then return end

-- Server ------------------------------------------------------------------------------------

local function crossed( def, old, new )
	for at, text in pairs( def.thresholds ) do
		if old < at and new >= at then return text end
	end
end

function Needs.Add( ply, name, amount, source )
	local def = defs[ name ]
	if not def then error( "Needs.Add: unknown need " .. tostring( name ), 2 ) end
	if not ply.GR_Needs then return end -- ghosts and the dead have no needs

	for _, mod in ipairs( Needs.Modifiers ) do
		amount = mod( ply, name, amount, source ) or amount
	end

	local old = ply.GR_Needs[ name ]
	local new = math.Clamp( old + amount, 0, def.max )
	if new == old then return end
	ply.GR_Needs[ name ] = new
	ply[ "SetNeed_" .. name ]( ply, math.floor( new ) )

	if def.onChange then def.onChange( ply, new, old ) end
	local text = crossed( def, old, new )
	if text then Notify( ply, text ) end
	if new >= def.max and old < def.max and def.onMax then def.onMax( ply ) end
end

function Needs.ApplyPox( ply )
	local f = ply:GetFateDef()
	local base = f and f.Health or 100
	local max = math.max( 1, math.floor( base * ( 1 - Needs.Get( ply, "Pox" ) / 200 ) ) )
	if ply:GetInjured() then max = math.min( max, Config.InjuredMaxHealth ) end -- step 7
	ply:SetMaxHealth( max )
	if ply:Health() > max then ply:SetHealth( max ) end
end

-- Despair at 100: a heart attack. The death lands two seconds later, as a timestamp the
-- needs tick checks (rule 6: timed effects are state, not timers).
local HEART_ATTACK_DELAY = 2

function Needs.HeartAttack( ply )
	if ply.GR_HeartAttackAt then return end
	ply.GR_HeartAttackAt = CurTime() + HEART_ATTACK_DELAY
	Needs.Add( ply, "Despair", -40, "heart attack" )
	ply:SetStemCells( math.max( ply:GetStemCells() - 1, 0 ) )
	Notify( ply, "IT'S TOO MUCH! MY HEART!" )
	for _, other in player.Iterator() do
		if other ~= ply and other:GetPos():DistToSqr( ply:GetPos() ) < 600 * 600 then
			Notify( other, ply:Nick() .. " clutches their chest and gasps!" )
		end
	end
	Log.Debug( "needs", "%s has a heart attack", ply:Nick() )
end

-- One second of needs for one player. The scheduler runs it once a second per player.
function Needs.Tick( ply )
	if ply.GR_HeartAttackAt and CurTime() >= ply.GR_HeartAttackAt then
		ply.GR_HeartAttackAt = nil
		if ply:Alive() then ply:Kill() end
		return
	end
	if not ply.GR_Needs or not ply:Alive() then return end

	for _, name in ipairs( order ) do
		local def = defs[ name ]
		if def.rate ~= 0 then Needs.Add( ply, name, def.rate, "tick" ) end
		if def.onTick then def.onTick( ply, ply.GR_Needs[ name ] ) end
	end
end
Sched.EachPlayer( "needs", 1, function( ply ) Needs.Tick( ply ) end )

-- Every new life starts with empty needs; ghosts have none. A revive or get-up keeps the old life's needs.
hook.Add( "GR_FateEnter", "gr_needs", function( ply, f, reason )
	ply.GR_HeartAttackAt = nil
	if f.index == FATE_GHOST then
		ply.GR_Needs = nil
		return
	end
	if not Fates.SameLife( reason ) or not ply.GR_Needs then
		ply.GR_Needs = {}
		for _, name in ipairs( order ) do ply.GR_Needs[ name ] = 0 end
	end
	for _, name in ipairs( order ) do ply[ "SetNeed_" .. name ]( ply, math.floor( ply.GR_Needs[ name ] ) ) end
	Needs.ApplyPox( ply )
end )
