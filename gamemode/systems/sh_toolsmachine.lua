-- The tools machine chain (step 11). Boulders broken with anything (a pickaxe hits twice as hard)
-- put ore in stock. A generator burns biofuel from stock and powers the crucible (vat_metal) and the
-- tools machine. The crucible heats and smelts ore -> pot metal -> ballistic -> formic steel, all in
-- stock. The tools machine shows a symbol; pressing the matching button builds a random tool the
-- stock can pay for, a wrong one shocks. The Kaiser exports ballistic and formic steel (Exports tab:
-- the outside world, the upgrade fund, pays the treasury). Everything made lands in stock.<good>.
--   ToolsMachine.Toggle( ply, gen )   ToolsMachine.Feed( gen, ent )   ToolsMachine.Press( ply, m, k )
--   ToolsMachine.CycleVat( ply, vat )   ToolsMachine.BoulderDamaged( b, dmg )   Exports.Export( ply, good )
ToolsMachine = ToolsMachine or {}
Exports = Exports or {}

ToolsMachine.RANGE = 300
ToolsMachine.FUEL_MAX, ToolsMachine.FUEL_PER_BIOFUEL, ToolsMachine.OVERFILL = 100, 25, 75
ToolsMachine.BURN = 1          -- fuel per second while running
ToolsMachine.POT_CAP = 50      -- the generator won't run the chain past this much pot metal
ToolsMachine.SYMBOLS = { "fire", "cog", "link" }
ToolsMachine.BUTTONS = 8
ToolsMachine.SHOCK = 25         -- a wrong button (misuse)
ToolsMachine.SHOCK_UNAUTHORIZED = 65 -- a fate without Proletariat at the buttons (misuse)
ToolsMachine.RUST_MAX = 100
ToolsMachine.RUST_BITE = { 4, 6 }  -- damage when a rotten machine bites (1 in 3 presses at full rust)
ToolsMachine.BITES = {
	"npc/headcrab_poison/ph_poisonbite2.wav", "npc/headcrab_poison/ph_poisonbite1.wav",
	"npc/headcrab_poison/ph_warning1.wav", "npc/headcrab_poison/ph_warning2.wav", "npc/headcrab_poison/ph_warning3.wav",
	"npc/headcrab_fast/headbite.wav", "npc/barnacle/barnacle_crunch2.wav", "npc/barnacle/barnacle_crunch3.wav",
}
ToolsMachine.LABOR_TOOL, ToolsMachine.LABOR_BOULDER = 5, 15
ToolsMachine.BOULDER_INTEGRITY, ToolsMachine.BOULDER_RESPAWN = 200, 60
ToolsMachine.HEAT_RATE, ToolsMachine.HEAT_MAX = 100, 4000
-- Crucible modes: the heat each needs and what it eats from stock for one of its output.
ToolsMachine.VAT = {
	{ out = "material_metal_pot", heat = 1000, cost = { ore = 1 } },
	{ out = "material_metal_ballistic", heat = 2500, cost = { material_metal_pot = 2 } },
	{ out = "formic_steel", heat = 3500, cost = { material_metal_ballistic = 2, scrap = 1 } },
}
ToolsMachine.TOOLS = {
	pipe = { material_metal_pot = 1 }, bat = { material_metal_pot = 1 },
	hammer = { material_metal_pot = 2 }, crowbar = { material_metal_pot = 2 },
	fryingpan = { material_metal_pot = 2 }, shovel = { material_metal_pot = 2 },
	pickaxe = { material_metal_pot = 3 }, axe = { material_metal_pot = 3 },
	meatsaw = { material_metal_ballistic = 2 }, crackhammer = { formic_steel = 2 },
}
Exports.GOODS = { "material_metal_ballistic", "formic_steel" }
Exports.SET = { material_metal_ballistic = true, formic_steel = true }

local ITEMS = {
	ore = { "Ore", "Rock with metal in it.", 3, "models/props_junk/rock001a.mdl" },
	biofuel = { "Biofuel", "Something rotten in a can. It burns.", 2, "models/props_junk/gascan001a.mdl" },
	material_metal_pot = { "Pot Metal", "Cheap cast metal.", 2, "models/gibs/metal_gib2.mdl" },
	material_metal_ballistic = { "Ballistic Metal", "Hard metal.", 2, "models/gibs/metal_gib1.mdl" },
	formic_steel = { "Formic Steel", "The best steel there is.", 2, "models/gibs/metal_gib5.mdl" },
	pipe = { "Pipe", "A length of lead pipe.", 2, "models/props_canal/mattpipe.mdl" },
	hammer = { "Hammer", "A hammer.", 2, "models/weapons/w_crowbar.mdl" },
	crowbar = { "Crowbar", "A crowbar.", 2, "models/weapons/w_crowbar.mdl" },
	bat = { "Bat", "A bat.", 2, "models/weapons/w_crowbar.mdl" },
	fryingpan = { "Frying Pan", "A heavy pan.", 2, "models/props_c17/metalpot002a.mdl" },
	pickaxe = { "Pickaxe", "Breaks rock twice as fast.", 3, "models/weapons/w_crowbar.mdl" },
	axe = { "Axe", "An axe.", 3, "models/weapons/w_crowbar.mdl" },
	shovel = { "Shovel", "A shovel.", 3, "models/weapons/w_crowbar.mdl" },
	meatsaw = { "Meat Saw", "A saw for meat.", 3, "models/weapons/w_crowbar.mdl" },
	crackhammer = { "Crack Hammer", "A hammer of formic steel.", 4, "models/weapons/w_crowbar.mdl" },
}
for id, d in pairs( ITEMS ) do
	if not ( Items.Get and Items.Get( id ) ) then
		Items.Define( id, { Name = d[ 1 ], Description = d[ 2 ], Weight = d[ 3 ], Model = d[ 4 ] } )
	end
end

-- The button symbols, button k at local offsets on the machine's front.
function ToolsMachine.ButtonPos( m, k ) return m:LocalToWorld( Vector( 14, -21 + ( k - 1 ) * 6, 30 ) ) end
function ToolsMachine.ButtonAt( m, pos )
	local best, bestD = nil, 3.5 * 3.5
	for k = 1, ToolsMachine.BUTTONS do
		local d = ToolsMachine.ButtonPos( m, k ):DistToSqr( pos )
		if d <= bestD then best, bestD = k, d end
	end
	return best
end

if CLIENT then return end

Net.Pool( "nKaiserExport" )

-- Registry ------------------------------------------------------------------------------------

ToolsMachine.CLASSES = { "machine_generator", "machine_tools", "vat_metal", "boulder" }
local reg = ToolsMachine.reg or {}
ToolsMachine.reg = reg
for _, c in ipairs( ToolsMachine.CLASSES ) do reg[ c ] = reg[ c ] or setmetatable( {}, { __mode = "k" } ) end

function ToolsMachine.Track( ent )
	local r = reg[ ent:GetClass() ]
	if r then r[ ent ] = true end
end

function ToolsMachine.All( class )
	local out = {}
	for ent in pairs( reg[ class ] or {} ) do if IsValid( ent ) then table.insert( out, ent ) end end
	return out
end

local function living( ply ) return IsValid( ply ) and ply:IsPlayer() and ply:Alive() and not ply:IsGhost() end
local function isClass( ent, class ) return IsValid( ent ) and ent:GetClass() == class end

local function nearest( class, pos, range )
	local best, bestD = nil, range * range
	for _, ent in ipairs( ToolsMachine.All( class ) ) do
		local d = ent:GetPos():DistToSqr( pos )
		if d <= bestD then best, bestD = ent, d end
	end
	return best
end

local function shock( ply, src, amount )
	if not living( ply ) then return end
	local d = DamageInfo()
	d:SetDamage( amount )
	d:SetDamageType( DMG_SHOCK )
	d:SetAttacker( src )
	d:SetInflictor( src )
	d:SetDamagePosition( ply:EyePos() )
	ply:TakeDamageInfo( d )
	local e = EffectData()
	e:SetOrigin( ply:EyePos() )
	e:SetMagnitude( 1 )
	e:SetScale( 1 )
	e:SetRadius( 2 )
	util.Effect( "Sparks", e )
	src:EmitSound( "ambient/energy/zap" .. math.random( 3 ) .. ".wav", 70 )
end

function ToolsMachine.Explode( ent )
	local pos = ent:WorldSpaceCenter()
	util.ScreenShake( pos, 25, 150, 1, 750 )
	local explo = ents.Create( "env_explosion" )
	explo:SetOwner( ent )
	explo:SetPos( pos )
	explo:SetKeyValue( "iMagnitude", "75" )
	explo:SetKeyValue( "iRadiusOverride", "150" )
	explo:Spawn()
	explo:Activate()
	explo:Fire( "Explode" )
	local fire = ents.Create( "env_fire" )
	fire:SetPos( ent:GetPos() + ent:GetForward() * 30 )
	fire:SetKeyValue( "spawnflags", "1" )
	fire:SetKeyValue( "attack", tostring( math.random( 10, 15 ) ) )
	fire:SetKeyValue( "firesize", tostring( math.random( 100, 150 ) ) )
	fire:Spawn()
	fire:Activate()
	fire:Fire( "StartFire" )
	fire:Fire( "Kill", "", math.random( 60, 70 ) )
	hook.Run( "GR_ToolsExplode", ent )
end

local function affords( cost )
	for good, n in pairs( cost ) do if Econ.Stock( good ) < n then return false end end
	return true
end
local function spend( cost ) for good, n in pairs( cost ) do Econ.AddStock( good, -n ) end end

-- Generator -----------------------------------------------------------------------------------

function ToolsMachine.GeneratorOf( ent ) return nearest( "machine_generator", ent:GetPos(), ToolsMachine.RANGE ) end
function ToolsMachine.Powered( ent )
	local g = ToolsMachine.GeneratorOf( ent )
	return IsValid( g ) and g:GetOn() and g:GetFuel() > 0
end

function ToolsMachine.Toggle( ply, gen )
	if not living( ply ) or not isClass( gen, "machine_generator" ) then return false end
	if not gen:GetOn() and gen:GetFuel() <= 0 and Econ.Stock( "biofuel" ) <= 0 then
		Notify( ply, "No fuel. Import biofuel or feed it some." )
		return false
	end
	gen:SetOn( not gen:GetOn() )
	gen:EmitSound( gen:GetOn() and "ambient/machines/thumper_startup1.wav" or "ambient/machines/thumper_shutdown1.wav" )
	return true
end

-- A biofuel item thrown into the generator. Overfilling it blows it up.
function ToolsMachine.Feed( gen, ent )
	if not isClass( gen, "machine_generator" ) or not isClass( ent, "gr_item" ) or ent:GetItemId() ~= "biofuel" then return false end
	if ent.GR_Fed then return false end
	ent.GR_Fed = true
	ent:Remove()
	if gen:GetFuel() > ToolsMachine.OVERFILL then
		gen:SetOn( false )
		gen:SetFuel( 0 )
		ToolsMachine.Explode( gen )
		return false, "overfilled"
	end
	gen:SetFuel( math.min( ToolsMachine.FUEL_MAX, gen:GetFuel() + ToolsMachine.FUEL_PER_BIOFUEL * ent:GetCount() ) )
	return true
end

function ToolsMachine.TickGenerator( gen, dt )
	for _, e in ipairs( ents.FindInSphere( gen:WorldSpaceCenter(), 50 ) ) do
		if isClass( e, "gr_item" ) and e:GetItemId() == "biofuel" then ToolsMachine.Feed( gen, e ) end
	end
	if not gen:GetOn() then return end
	if gen:GetFuel() <= 0 then
		if Econ.Stock( "biofuel" ) > 0 then
			Econ.AddStock( "biofuel", -1 )
			gen:SetFuel( ToolsMachine.FUEL_PER_BIOFUEL )
		else
			gen:SetOn( false )
			gen:EmitSound( "ambient/machines/thumper_shutdown1.wav" )
			return
		end
	end
	gen:SetFuel( math.max( 0, gen:GetFuel() - ToolsMachine.BURN * dt ) )
	gen:SetRust( math.min( 100, gen:GetRust() + 0.05 * dt ) )
end

-- Crucible ------------------------------------------------------------------------------------

function ToolsMachine.CycleVat( ply, vat )
	if not living( ply ) or not isClass( vat, "vat_metal" ) then return false end
	vat:SetMode( vat:GetMode() % #ToolsMachine.VAT + 1 )
	vat:EmitSound( "buttons/lever7.wav" )
	return true
end

function ToolsMachine.TickVat( vat, dt )
	if not ToolsMachine.Powered( vat ) then
		vat:SetHeat( math.max( 0, vat:GetHeat() - ToolsMachine.HEAT_RATE * dt ) )
		return
	end
	vat:SetHeat( math.min( ToolsMachine.HEAT_MAX, vat:GetHeat() + ToolsMachine.HEAT_RATE * dt ) )
	local mode = ToolsMachine.VAT[ vat:GetMode() ]
	if not mode or vat:GetHeat() < mode.heat or not affords( mode.cost ) then return end
	if mode.out == "material_metal_pot" and Econ.Stock( mode.out ) >= ToolsMachine.POT_CAP then return end
	vat.GR_Next = vat.GR_Next or 0
	if CurTime() < vat.GR_Next then return end
	vat.GR_Next = CurTime() + 5
	spend( mode.cost )
	Econ.AddStock( mode.out, 1 )
	vat:EmitSound( "ambient/levels/canals/toxic_slime_sizzle" .. math.random( 2, 4 ) .. ".wav" )
end

-- Tools machine -------------------------------------------------------------------------------

function ToolsMachine.Reroll( m )
	m:SetTarget( math.random( #ToolsMachine.SYMBOLS ) )
	local syms = {}
	for k = 1, ToolsMachine.BUTTONS do syms[ k ] = math.random( #ToolsMachine.SYMBOLS ) end
	syms[ math.random( ToolsMachine.BUTTONS ) ] = m:GetTarget()
	m:SetButtons( table.concat( syms ) )
end

function ToolsMachine.Symbol( m, k ) return tonumber( m:GetButtons():sub( k, k ) ) or 0 end

-- One random tool the stock can pay for, or nil.
function ToolsMachine.Affordable()
	local can = {}
	for tool, cost in SortedPairs( ToolsMachine.TOOLS ) do if affords( cost ) then table.insert( can, tool ) end end
	return can[ math.random( #can ) ]
end

-- Misuse: the klaxon, then a second later a beam from the machine.
function ToolsMachine.Zap( ply, m, amount )
	m:EmitSound( "ambient/alarms/klaxon1.wav" )
	timer.Simple( 1, function()
		if not IsValid( m ) or not living( ply ) then return end
		local e = EffectData()
		e:SetStart( m:WorldSpaceCenter() )
		e:SetOrigin( ply:EyePos() )
		e:SetEntity( m )
		util.Effect( "vortigaunt_beam", e )
		m:EmitSound( "beams/beamstart5.wav" )
		shock( ply, m, amount )
	end )
end

-- Rust: a rotten machine bites 1 in 3 presses, and 1 in 4 bites it catches fire.
function ToolsMachine.Bite( ply, m )
	m:EmitSound( ToolsMachine.BITES[ math.random( #ToolsMachine.BITES ) ], 75, math.random( 70, 90 ) )
	local d = DamageInfo()
	d:SetDamage( math.random( ToolsMachine.RUST_BITE[ 1 ], ToolsMachine.RUST_BITE[ 2 ] ) )
	d:SetDamageType( DMG_SLASH )
	d:SetAttacker( m )
	d:SetInflictor( m )
	ply:TakeDamageInfo( d )
	if math.random( 1, 4 ) == 1 then m:Ignite( math.random( 3, 6 ), 150 ) end
	hook.Run( "GR_ToolsBite", m, ply )
end

function ToolsMachine.AddRust( m, n )
	m:SetRust( math.Clamp( m:GetRust() + n, 0, ToolsMachine.RUST_MAX ) )
end

function ToolsMachine.Press( ply, m, k )
	if not living( ply ) or not isClass( m, "machine_tools" ) then return nil end
	if m:GetRust() >= ToolsMachine.RUST_MAX and math.random( 1, 3 ) == 1 then ToolsMachine.Bite( ply, m ) end
	if not living( ply ) then return nil end
	if not ToolsMachine.Powered( m ) then
		Notify( ply, "It needs a running generator nearby." )
		return nil
	end
	if not ply:FateHas( "Proletariat" ) then
		Chat.Big( ply, Color( 255, 0, 0 ), "UNAUTHORIZED PERSONNEL!" )
		ToolsMachine.Zap( ply, m, ToolsMachine.SHOCK_UNAUTHORIZED )
		hook.Run( "GR_ToolsMisuse", m, ply, "unauthorized" )
		return false
	end
	if ToolsMachine.Symbol( m, k ) ~= m:GetTarget() then
		ToolsMachine.Zap( ply, m, ToolsMachine.SHOCK )
		ToolsMachine.Reroll( m )
		hook.Run( "GR_ToolsMisuse", m, ply, "wrong" )
		return false
	end
	ToolsMachine.Reroll( m )
	local tool = ToolsMachine.Affordable()
	if not tool then
		-- Operator error: running it with no metal to pay for a tool.
		ToolsMachine.Explode( m )
		return false
	end
	local cost = 0
	for _, n in pairs( ToolsMachine.TOOLS[ tool ] ) do cost = cost + n end
	spend( ToolsMachine.TOOLS[ tool ] )
	Econ.AddStock( tool, 1 )
	ToolsMachine.AddRust( m, cost + math.random( 10, 20 ) ) -- the original: metal + build time
	Econ.Transfer( Econ.TREASURY, ply, ToolsMachine.LABOR_TOOL, "labor" )
	m:EmitSound( "ambient/machines/catapult_throw.wav" )
	hook.Run( "GR_ToolMade", tool, m, ply )
	return tool
end

function ToolsMachine.Use( ply, m )
	if not living( ply ) then return end
	local tr = util.TraceLine( { start = ply:GetShootPos(), endpos = ply:GetShootPos() + ply:GetAimVector() * 96, filter = ply } )
	if tr.Entity ~= m then return end
	local k = ToolsMachine.ButtonAt( m, tr.HitPos )
	if k then return ToolsMachine.Press( ply, m, k ) end
end

-- Boulders ------------------------------------------------------------------------------------

function ToolsMachine.BoulderDamaged( b, dmg )
	if b:GetBroken() then return end
	local amount = dmg:GetDamage()
	local att = dmg:GetAttacker()
	if IsValid( att ) and att:IsPlayer() and Inventory.Count( att, "pickaxe" ) > 0 then amount = amount * 2 end
	b:SetIntegrity( math.max( 0, b:GetIntegrity() - amount ) )
	if b:GetIntegrity() > 0 then return end
	b:SetBroken( true )
	b:SetNoDraw( true )
	b:SetNotSolid( true )
	local phys = b:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
	b.GR_RespawnAt = CurTime() + ToolsMachine.BOULDER_RESPAWN
	Econ.AddStock( "ore", 1 + math.random( 2, 3 ) )
	if living( att ) then Econ.Transfer( Econ.TREASURY, att, ToolsMachine.LABOR_BOULDER, "labor" ) end
	b:EmitSound( "physics/concrete/boulder_impact_hard" .. math.random( 4 ) .. ".wav" )
end

function ToolsMachine.RestoreBoulder( b )
	-- back to where it first spawned, loose again
	b.GR_Home = b.GR_Home or { b:GetPos(), b:GetAngles() }
	b:SetPos( b.GR_Home[ 1 ] ); b:SetAngles( b.GR_Home[ 2 ] )
	local phys = b:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( true ); phys:Wake() end
	b:SetBroken( false )
	b:SetNoDraw( false )
	b:SetNotSolid( false )
	b:SetIntegrity( ToolsMachine.BOULDER_INTEGRITY )
	b.GR_RespawnAt = nil
end

-- Exports -------------------------------------------------------------------------------------

function Exports.Export( ply, good )
	if not IsValid( ply ) or not ply:Alive() or not ply:FateHas( "RunsEconomy" ) then return false end
	if not Exports.SET[ good ] then
		Notify( ply, "That can't be exported." )
		return false
	end
	if Econ.Stock( good ) <= 0 then
		Notify( ply, "There is none in the stockpile." )
		return false
	end
	local price = Econ.Setting( "sell." .. good )
	if not Econ.Transfer( Econ.UPGRADE_FUND, Econ.TREASURY, price, "export " .. good ) then
		Notify( ply, "Nobody abroad can pay for it." )
		return false
	end
	Econ.AddStock( good, -1 )
	Notify( ply, string.format( "Exported for %d bones.", price ) )
	return true
end

Net.Receive( "nKaiserExport", { rate = 2, alive = true, fate = "RunsEconomy" }, function( ply )
	Exports.Export( ply, Net.ReadString() )
end )

-- Ticks and reset -----------------------------------------------------------------------------

Sched.Every( "toolsmachine", 1, function()
	for _, g in ipairs( ToolsMachine.All( "machine_generator" ) ) do ToolsMachine.TickGenerator( g, 1 ) end
	for _, v in ipairs( ToolsMachine.All( "vat_metal" ) ) do ToolsMachine.TickVat( v, 1 ) end
	for _, b in ipairs( ToolsMachine.All( "boulder" ) ) do
		if b.GR_RespawnAt and CurTime() >= b.GR_RespawnAt then ToolsMachine.RestoreBoulder( b ) end
	end
end )

function ToolsMachine.Reset()
	for _, g in ipairs( ToolsMachine.All( "machine_generator" ) ) do g:SetOn( false ) g:SetFuel( 0 ) g:SetRust( 0 ) end
	for _, v in ipairs( ToolsMachine.All( "vat_metal" ) ) do v:SetHeat( 0 ) v:SetMode( 1 ) end
	for _, m in ipairs( ToolsMachine.All( "machine_tools" ) ) do ToolsMachine.Reroll( m ) m:SetRust( math.random( 0, 20 ) ) end
	for _, b in ipairs( ToolsMachine.All( "boulder" ) ) do ToolsMachine.RestoreBoulder( b ) end
end
hook.Add( "GR_RoundStart", "gr_toolsmachine", ToolsMachine.Reset )
