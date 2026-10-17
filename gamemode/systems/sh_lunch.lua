-- The lunch machine (step 11.1): the one factory, placed by the map layout, rebuilt from the
-- original's machine_lunch with a boiler in place of its generator. All of it is hands-on: no timed
-- actions, no menus.
--
--   bone_capsule   spawned every SPAWN_MIN-SPAWN_MAX s at a random capsule_spawn point (at most
--                  CAPSULE_MAX, each gone after CAPSULE_LIFE). Melee hits and bullets take its
--                  Integrity; at 0 it bursts into CHUNKS meat_chunks (gone after CHUNK_LIFE). Whole,
--                  it is heavy and carried like a crate; thrown, it hurts at THROWN_SCALE.
--   water_barrel   empty, it fills over FILL_TIME s while it is in map water; full, it is carried
--                  like a crate and pours BARREL_WATER crates' worth into a boiler it touches.
--   line_boiler    holds water. Pressure 0-100 creeps up with a wobble (falls to 0 with no water).
--                  Use on its red handle vents VALVE_STEP, on its black handle builds VALVE_STEP
--                  (the gr_valve receiver). Under GREEN_MIN the machine's panel is dark;
--                  GREEN_MIN-GREEN_MAX it runs; GREEN_MAX-VENT_AT it runs but each correct press may
--                  shock the presser; over VENT_AT it vents steam on everyone near and the panel stays
--                  dark until the pressure is back under GREEN_MAX.
--   lunch_machine  the maw: a meat chunk (1) or a whole capsule (2) touching it becomes biomass.
--                  The lever (use on it) picks ration (1 biomass + 1 water) or clean water (1 water).
--                  The panel: 8 buttons of heart, pill and drop, and a light showing one symbol.
--                  A matching press darkens the button; the light moves on when its symbol is gone
--                  (or REROLL_CHANCE after a correct press). A wrong press sounds the klaxon and shocks
--                  WRONG_SHOCK after WRONG_DELAY s. Clearing all 8 makes a crate at the output, stamped
--                  with the crew (everyone who pressed right or turned the valve meanwhile). A ration
--                  finished with no biomass blows the machine up instead, leaving a fire. With
--                  Crates.PER_STATION crates waiting, the panel is dark.
-- A machine works with the nearest boiler within RANGE. Every entity here is in a registry.
--
-- The core is plain server functions; Use, touch, damage and the receiver only call them:
--   Lunch.Press( ply, machine, k ) -> "right" | "done" | "wrong" | "dead" | "dark"
--   Lunch.FlipLever( ply, machine ), Lunch.Feed( machine, ent ), Lunch.Pour( boiler, barrel )
--   Lunch.TurnValve( ply, boiler, "vent" | "build" ), Lunch.SetPressure( boiler, p )
--   Lunch.Hurt( capsule, amount, attacker ), Lunch.Burst( capsule ), Lunch.SpawnCapsule()
--   Lunch.Status( machine ) -> code, Lunch.Finish( machine ) -> crate | nil, Lunch.Crew( machine, ply )
--   Lunch.ButtonAt( machine, pos ) -> k, Lunch.ButtonPos( machine, k ), Lunch.HandleAt( boiler, pos )
--   hooks GR_CrateMade( crate, machine ), GR_LunchExplode( machine ), GR_BoilerVent( boiler )
Lunch = Lunch or {}

Lunch.CAPSULE_MAX = 12
Lunch.CAPSULE_LIFE = 900
Lunch.SPAWN_MIN, Lunch.SPAWN_MAX = 15, 20
Lunch.CAPSULE_INTEGRITY = 100
Lunch.CAPSULE_MASS = 30      -- just under the hand-pickup limit, like a crate
Lunch.CHUNKS = 2
Lunch.CHUNK_LIFE = 120
Lunch.CHUNK_MASS = 5
Lunch.THROWN_SCALE = 0.1     -- a thrown capsule hurts at a tenth of physics damage
Lunch.BIOMASS = { meat_chunk = 1, bone_capsule = 2 }
Lunch.BIOMASS_MAX = 50

Lunch.FILL_TIME = 4
Lunch.BARREL_WATER = 4
Lunch.BARREL_CAP = 8
Lunch.BARREL_MASS_FULL, Lunch.BARREL_MASS_EMPTY = 30, 8
Lunch.BOILER_WATER = 16      -- the most a boiler holds

Lunch.PRESSURE_START = 55
Lunch.GREEN_MIN, Lunch.GREEN_MAX = 40, 70
Lunch.VENT_AT = 90
Lunch.VALVE_STEP = 8
Lunch.DRIFT_MIN, Lunch.DRIFT_MAX = -0.4, 1.2 -- per second; about +0.4 on average
Lunch.DRY_DROP = 3           -- per second with no water
Lunch.VENT_DROP = 5          -- per second while venting
Lunch.VENT_DAMAGE = 8        -- per second, to everyone within VENT_RANGE
Lunch.VENT_RANGE = 200
Lunch.OVERLOAD_CHANCE = 0.3  -- per correct press between GREEN_MAX and VENT_AT
Lunch.OVERLOAD_MIN, Lunch.OVERLOAD_MAX = 4, 6
Lunch.WRONG_SHOCK = 20
Lunch.WRONG_DELAY = 1
Lunch.REROLL_CHANCE = 0.5
Lunch.FIRE_TIME = 60
Lunch.RANGE = 400            -- machine to boiler
Lunch.TOUCH = 12             -- units between two bodies that count as touching
Lunch.BUTTONS = 8
Lunch.SYMBOLS = { "heart", "pill", "drop" }

Lunch.OUTPUTS = { ration = { biomass = 1, water = 1 }, clean_water = { biomass = 0, water = 1 } }

Lunch.STATUS_TEXT = {
	no_boiler = "NO BOILER",
	full = "OUTPUT FULL",
	dry = "BOILER DRY",
	venting = "VENTING",
	low = "NO POWER",
	overload = "OVERLOAD",
	on = "RUNNING",
}

-- Where things are on the models (local coordinates), shared so the client draws what the server checks.
-- The panel is the original's: 8 buttons across the front of the cart, 3 lights below them.
local BUTTON_Y = { -6, -3, 0, 3, 6, 9, 12, 15 }
local BUTTON_TOLERANCE = 2.5
local LEVER = Vector( 13, -12, 8 )
local LEVER_TOLERANCE = 6

function Lunch.ButtonPos( machine, k ) return machine:LocalToWorld( Vector( 13, BUTTON_Y[ k ], 18 ) ) end
function Lunch.LightPos( machine, i ) return machine:LocalToWorld( Vector( 14.5, ( { 1, 6, 11.5 } )[ i ], 0.5 ) ) end
function Lunch.LeverPos( machine ) return machine:LocalToWorld( LEVER ) end

function Lunch.ButtonAt( machine, pos )
	for k = 1, Lunch.BUTTONS do
		if Lunch.ButtonPos( machine, k ):Distance( pos ) <= BUTTON_TOLERANCE then return k end
	end
end

function Lunch.OnLever( machine, pos ) return Lunch.LeverPos( machine ):Distance( pos ) <= LEVER_TOLERANCE end

-- The boiler's two valve handles stand out of its front: red (vent) on the left, black (build) on the right.
function Lunch.HandlePos( boiler, dir )
	local mins, maxs = boiler:OBBMins(), boiler:OBBMaxs()
	return boiler:LocalToWorld( Vector( maxs.x + 2, dir == "vent" and -10 or 10, ( mins.z + maxs.z ) / 2 ) )
end

-- The handle nearest `pos` (an aim point on the boiler), or nil when neither is within reach of it.
function Lunch.HandleAt( boiler, pos )
	local v, b = Lunch.HandlePos( boiler, "vent" ):Distance( pos ), Lunch.HandlePos( boiler, "build" ):Distance( pos )
	if math.min( v, b ) > 16 then return nil end
	return v <= b and "vent" or "build"
end

function Lunch.OutputName( kind )
	local def = Items.Get( kind )
	return def and def.Name or tostring( kind )
end

local function isClass( ent, class ) return IsValid( ent ) and ent:GetClass() == class end


if CLIENT then
	-- Use on a boiler handle turns the valve: the client says which handle, the server checks the rest.
	hook.Add( "KeyPress", "gr_lunch_valve", function( ply, key )
		if key ~= IN_USE or ply ~= LocalPlayer() or not IsFirstTimePredicted() then return end
		local tr = ply:GetEyeTrace()
		if not isClass( tr.Entity, "line_boiler" ) or tr.HitPos:Distance( ply:EyePos() ) > 100 then return end
		local dir = Lunch.HandleAt( tr.Entity, tr.HitPos )
		if not dir then return end
		net.Start( "gr_valve" )
		net.WriteEntity( tr.Entity )
		net.WriteString( dir )
		net.SendToServer()
	end )
	return
end

-- Registries ------------------------------------------------------------------------------------

Lunch.CLASSES = { "bone_capsule", "meat_chunk", "capsule_spawn", "water_barrel", "line_boiler", "lunch_machine" }
local reg = Lunch.reg or {}
Lunch.reg = reg
for _, class in ipairs( Lunch.CLASSES ) do reg[ class ] = reg[ class ] or setmetatable( {}, { __mode = "k" } ) end

-- Each of these entities calls this from Initialize.
function Lunch.Track( ent )
	local r = reg[ ent:GetClass() ]
	if r then r[ ent ] = true end
end

function Lunch.All( class )
	local out = {}
	for ent in pairs( reg[ class ] or {} ) do
		if IsValid( ent ) and not ent.GR_Gone then table.insert( out, ent ) end
	end
	return out
end

function Lunch.BarrelCount() return #Lunch.All( "water_barrel" ) end

local function living( ply ) return IsValid( ply ) and ply:IsPlayer() and ply:Alive() and not ply:IsGhost() end

local function gone( ent )
	ent.GR_Gone = true
	ent:Remove()
end

local function nearest( class, pos, range )
	local best, bestD = nil, range * range
	for _, ent in ipairs( Lunch.All( class ) ) do
		local d = ent:GetPos():DistToSqr( pos )
		if d <= bestD then best, bestD = ent, d end
	end
	return best
end

function Lunch.BoilerOf( machine )
	if not IsValid( machine.GR_Boiler ) then machine.GR_Boiler = nearest( "line_boiler", machine:GetPos(), Lunch.RANGE ) end
	return machine.GR_Boiler
end

function Lunch.MachineOf( boiler ) return nearest( "lunch_machine", boiler:GetPos(), Lunch.RANGE ) end

-- Two bodies touch when their nearest surface points (bounding boxes) are within TOUCH units.
function Lunch.Touching( a, b )
	local pa = a:NearestPoint( b:WorldSpaceCenter() )
	local pb = b:NearestPoint( pa )
	return pa:DistToSqr( pb ) <= Lunch.TOUCH * Lunch.TOUCH
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

-- Bone capsules ---------------------------------------------------------------------------------

-- A capsule at a random capsule_spawn point, if there is room. Returns it.
function Lunch.SpawnCapsule( at )
	if #Lunch.All( "bone_capsule" ) >= Lunch.CAPSULE_MAX then return nil end
	if not at then
		local points = Lunch.All( "capsule_spawn" )
		if #points == 0 then return nil end
		at = points[ math.random( #points ) ]:GetPos() + Vector( 0, 0, 16 )
	end
	local c = ents.Create( "bone_capsule" )
	if not IsValid( c ) then return nil end
	c:SetPos( at )
	c:SetAngles( Angle( math.random( 0, 360 ), math.random( 0, 360 ), math.random( 0, 360 ) ) )
	c:Spawn()
	c:Activate()
	c.GR_DieAt = CurTime() + Lunch.CAPSULE_LIFE
	c:EmitSound( "npc/antlion_guard/angry" .. math.random( 3 ) .. ".wav", 100, 60 + math.random( 20 ) )
	return c
end

-- Takes `amount` of the capsule's Integrity; at 0 it bursts. Returns true when it burst.
function Lunch.Hurt( capsule, amount, pos )
	if not isClass( capsule, "bone_capsule" ) or capsule.GR_Gone or amount <= 0 then return false end
	local e = EffectData()
	e:SetOrigin( pos or capsule:WorldSpaceCenter() )
	e:SetScale( 6 )
	util.Effect( "BloodImpact", e )
	capsule:EmitSound( "npc/headcrab/pain" .. math.random( 3 ) .. ".wav" )
	capsule:SetIntegrity( math.max( 0, capsule:GetIntegrity() - math.ceil( amount ) ) )
	if capsule:GetIntegrity() <= 0 then
		Lunch.Burst( capsule )
		return true
	end
	return false
end

-- The capsule bursts into gore and CHUNKS meat chunks. Returns the chunks.
function Lunch.Burst( capsule )
	if not isClass( capsule, "bone_capsule" ) or capsule.GR_Gone then return {} end
	local pos = capsule:WorldSpaceCenter()
	Crates.Forget( capsule )
	gone( capsule )
	capsule:EmitSound( "physics/flesh/flesh_bloody_break.wav" )
	local e = EffectData()
	e:SetOrigin( pos )
	e:SetScale( 60 )
	util.Effect( "BloodImpact", e )
	local out = {}
	for i = 1, Lunch.CHUNKS do
		local chunk = ents.Create( "meat_chunk" )
		if IsValid( chunk ) then
			chunk:SetPos( pos + Vector( 0, ( i - 1.5 ) * 12, 4 ) )
			chunk:SetAngles( AngleRand() )
			chunk:Spawn()
			chunk.GR_DieAt = CurTime() + Lunch.CHUNK_LIFE
			local phys = chunk:GetPhysicsObject()
			if IsValid( phys ) then phys:SetVelocity( VectorRand() * 80 + Vector( 0, 0, 80 ) ) end
			table.insert( out, chunk )
		end
	end
	return out
end

-- Melee and bullets break capsules; nothing else does (fire, falls and crushing leave them).
local BREAKS = bit.bor( DMG_CLUB, DMG_SLASH, DMG_BULLET, DMG_BUCKSHOT )
function Lunch.CapsuleDamaged( capsule, dmg )
	if bit.band( dmg:GetDamageType(), BREAKS ) == 0 then return false end
	return Lunch.Hurt( capsule, dmg:GetDamage(), dmg:GetDamagePosition() )
end

-- A thrown capsule hurts whoever it hits at a tenth of physics damage (a stage of the pipeline).
Damage.Add( "Scale", "capsule_throw", function( ply, dmg )
	if isClass( dmg:GetInflictor(), "bone_capsule" ) and bit.band( dmg:GetDamageType(), DMG_CRUSH ) ~= 0 then
		dmg:ScaleDamage( Lunch.THROWN_SCALE )
	end
end )

-- Water -----------------------------------------------------------------------------------------

-- Map water at the barrel: the engine's water level, or water brush contents at its base.
function Lunch.InWater( ent )
	if ent:WaterLevel() > 0 then return true end
	local base = ent:LocalToWorld( Vector( 0, 0, ent:OBBMins().z + 4 ) )
	return bit.band( util.PointContents( base ), CONTENTS_WATER ) ~= 0
end

function Lunch.SetBarrelFull( barrel, full )
	barrel:SetFull( full )
	barrel.GR_Fill = 0
	local phys = barrel:GetPhysicsObject()
	if IsValid( phys ) then phys:SetMass( full and Lunch.BARREL_MASS_FULL or Lunch.BARREL_MASS_EMPTY ) end
	-- An empty barrel is light: whoever carried it full may run again.
	if not full then Crates.Forget( barrel ) end
end

function Lunch.TickBarrel( barrel, dt )
	if barrel:GetFull() then return end
	if not Lunch.InWater( barrel ) then
		barrel.GR_Fill = 0
		return
	end
	barrel.GR_Fill = ( barrel.GR_Fill or 0 ) + dt
	if barrel.GR_Fill >= Lunch.FILL_TIME then
		Lunch.SetBarrelFull( barrel, true )
		barrel:EmitSound( "ambient/water/water_splash" .. math.random( 3 ) .. ".wav", 60 )
	end
end

-- A full barrel pours into the boiler and is empty. Returns true, or false and why.
function Lunch.Pour( boiler, barrel )
	if not isClass( boiler, "line_boiler" ) or not isClass( barrel, "water_barrel" ) then return false, "not a barrel" end
	if not barrel:GetFull() then return false, "empty" end
	if boiler:GetWater() + Lunch.BARREL_WATER > Lunch.BOILER_WATER then return false, "full" end
	boiler:SetWater( boiler:GetWater() + Lunch.BARREL_WATER )
	Lunch.SetBarrelFull( barrel, false )
	boiler:EmitSound( "ambient/water/water_spray" .. math.random( 3 ) .. ".wav", 70 )
	return true
end

-- The boiler ------------------------------------------------------------------------------------

-- Sets the pressure; crossing VENT_AT starts a vent, falling under GREEN_MAX ends it.
function Lunch.SetPressure( boiler, p )
	p = math.Clamp( p, 0, 100 )
	boiler:SetPressure( p )
	if not boiler:GetVenting() and p > Lunch.VENT_AT then
		boiler:SetVenting( true )
		boiler:EmitSound( "ambient/gas/steam2.wav", 80 )
		hook.Run( "GR_BoilerVent", boiler )
	elseif boiler:GetVenting() and p < Lunch.GREEN_MAX then
		boiler:SetVenting( false )
		boiler:StopSound( "ambient/gas/steam2.wav" )
	end
end

-- Steam scalds every living player near a venting boiler, through the damage pipeline.
function Lunch.Scald( boiler, dt )
	local hit = {}
	local r2 = Lunch.VENT_RANGE * Lunch.VENT_RANGE
	for _, p in player.Iterator() do
		if living( p ) and p:GetPos():DistToSqr( boiler:GetPos() ) <= r2 then
			local d = DamageInfo()
			d:SetDamage( Lunch.VENT_DAMAGE * dt )
			d:SetDamageType( DMG_BURN )
			d:SetAttacker( boiler )
			d:SetInflictor( boiler )
			d:SetDamagePosition( boiler:WorldSpaceCenter() )
			p:TakeDamageInfo( d )
			table.insert( hit, p )
		end
	end
	return hit
end

function Lunch.TickBoiler( boiler, dt )
	if boiler:GetVenting() then
		Lunch.Scald( boiler, dt )
		Lunch.SetPressure( boiler, boiler:GetPressure() - Lunch.VENT_DROP * dt )
	elseif boiler:GetWater() <= 0 then
		Lunch.SetPressure( boiler, boiler:GetPressure() - Lunch.DRY_DROP * dt )
	else
		Lunch.SetPressure( boiler, boiler:GetPressure() + math.Rand( Lunch.DRIFT_MIN, Lunch.DRIFT_MAX ) * dt )
	end
end

-- One notch of the valve: "vent" lowers by VALVE_STEP, "build" raises. The turner joins the crew.
function Lunch.TurnValve( ply, boiler, dir )
	if dir ~= "vent" and dir ~= "build" then return false end
	if not isClass( boiler, "line_boiler" ) then return false end
	Lunch.SetPressure( boiler, boiler:GetPressure() + ( dir == "build" and Lunch.VALVE_STEP or -Lunch.VALVE_STEP ) )
	boiler:EmitSound( "ambient/machines/squeak_" .. math.random( 8 ) .. ".wav", 60 )
	local machine = Lunch.MachineOf( boiler )
	if machine and living( ply ) then Lunch.Crew( machine, ply ) end
	return true
end

Net.Receive( "gr_valve", { rate = 4, alive = true, target = "entity", range = 120 }, function( ply, boiler )
	local dir = Net.ReadString( 8 )
	if not isClass( boiler, "line_boiler" ) or ( dir ~= "vent" and dir ~= "build" ) then return end
	Lunch.TurnValve( ply, boiler, dir )
end )

-- The machine -----------------------------------------------------------------------------------

function Lunch.Crew( machine, ply )
	machine.GR_Crew = machine.GR_Crew or {}
	machine.GR_Crew[ DB.Key( ply ) ] = true
end

function Lunch.CrewOf( machine ) return machine.GR_Crew or {} end

-- Why the panel is lit or dark, as a Lunch.STATUS_TEXT key. "on" and "overload" are lit.
function Lunch.Status( machine )
	local boiler = Lunch.BoilerOf( machine )
	if not boiler then return "no_boiler" end
	if Crates.Waiting( machine ) >= Crates.PER_STATION then return "full" end
	if boiler:GetVenting() then return "venting" end
	if boiler:GetWater() <= 0 then return "dry" end
	local p = boiler:GetPressure()
	if p < Lunch.GREEN_MIN then return "low" end
	if p > Lunch.GREEN_MAX then return "overload" end
	return "on"
end

function Lunch.Powered( machine )
	local s = Lunch.Status( machine )
	return s == "on" or s == "overload"
end

-- A swallowed chunk or capsule becomes biomass. Returns true, or false and why.
function Lunch.Feed( machine, ent )
	if not isClass( machine, "lunch_machine" ) or not IsValid( ent ) or ent.GR_Gone then return false, "nothing" end
	local add = Lunch.BIOMASS[ ent:GetClass() ]
	if not add then return false, "not food" end
	if machine:GetBiomass() + add > Lunch.BIOMASS_MAX then return false, "full" end
	Crates.Forget( ent )
	gone( ent )
	machine:SetBiomass( machine:GetBiomass() + add )
	machine:EmitSound( "npc/barnacle/barnacle_pull" .. math.random( 3 ) .. ".wav" )
	local e = EffectData()
	e:SetOrigin( ent:GetPos() )
	e:SetScale( 1 )
	e:SetMagnitude( 1 )
	e:SetRadius( 3 )
	util.Effect( "Sparks", e )
	return true
end

function Lunch.FlipLever( ply, machine )
	if not isClass( machine, "lunch_machine" ) then return false end
	machine:SetOutput( machine:GetOutput() == "ration" and "clean_water" or "ration" )
	machine:EmitSound( "buttons/lever" .. math.random( 1, 8 ) .. ".wav", 70 )
	return true
end

-- The light moves to another symbol still on the panel (the original's NewLight).
function Lunch.NewLight( machine )
	local cur = machine:GetLight()
	local left = {}
	for k = 1, Lunch.BUTTONS do
		local s = machine:GetButton( k )
		if s > 0 and s ~= cur and not table.HasValue( left, s ) then table.insert( left, s ) end
	end
	if #left > 0 then
		machine:SetLight( left[ math.random( #left ) ] )
		machine:EmitSound( "ambient/tones/elev1.wav", 75, math.random( 75, 95 ) )
	end
end

-- A fresh panel: 8 random symbols, and the light on one of them.
function Lunch.Reroll( machine )
	for k = 1, Lunch.BUTTONS do machine:SetButton( k, math.random( #Lunch.SYMBOLS ) ) end
	machine:SetLight( machine:GetButton( math.random( Lunch.BUTTONS ) ) )
end

local function lit( machine, symbol )
	for k = 1, Lunch.BUTTONS do
		if machine:GetButton( k ) == symbol then return true end
	end
	return false
end

-- Out of biomass on a ration: the original's explosion, and a fire that burns for FIRE_TIME.
function Lunch.Explode( machine )
	local pos = machine:WorldSpaceCenter()
	util.ScreenShake( pos, 25, 150, 1, 750 )
	local explo = ents.Create( "env_explosion" )
	explo:SetOwner( machine )
	explo:SetPos( pos )
	explo:SetKeyValue( "iMagnitude", "50" )
	explo:SetKeyValue( "iRadiusOverride", "150" )
	explo:Spawn()
	explo:Activate()
	explo:Fire( "Explode" )
	local fire = ents.Create( "env_fire" )
	fire:SetPos( machine:GetPos() + machine:GetForward() * 30 )
	fire:SetKeyValue( "spawnflags", "1" )
	fire:SetKeyValue( "attack", tostring( math.random( 10, 15 ) ) )
	fire:SetKeyValue( "firesize", tostring( math.random( 100, 150 ) ) )
	fire:Spawn()
	fire:Activate()
	fire:Fire( "StartFire" )
	fire:Fire( "Kill", "", Lunch.FIRE_TIME ) -- the entity's own input queue, not a Lua timer
	machine.GR_Fire = fire
	hook.Run( "GR_LunchExplode", machine )
end

local function outputPos( machine, n )
	local side = ( n % 3 - 1 ) * 30
	return machine:GetPos() + machine:GetForward() * 50 + machine:GetRight() * side + Vector( 0, 0, 30 )
end

-- All 8 buttons are cleared: a crate of the lever's product, or the explosion. Returns the crate.
function Lunch.Finish( machine )
	local kind = Lunch.OUTPUTS[ machine:GetOutput() ] and machine:GetOutput() or "ration"
	local need = Lunch.OUTPUTS[ kind ]
	local boiler = Lunch.BoilerOf( machine )
	local crew = Lunch.CrewOf( machine )
	machine.GR_Crew = {}
	Lunch.Reroll( machine )
	if need.biomass > 0 and machine:GetBiomass() < need.biomass then
		Lunch.Explode( machine )
		return nil
	end
	if not boiler or boiler:GetWater() < need.water then return nil end
	local crate = Crates.Spawn( kind, outputPos( machine, Crates.Waiting( machine ) ), crew, machine )
	if not crate then return nil end
	machine:SetBiomass( machine:GetBiomass() - need.biomass )
	boiler:SetWater( boiler:GetWater() - need.water )
	machine:EmitSound( "items/suitchargeok1.wav", 75, math.random( 75, 95 ) )
	hook.Run( "GR_CrateMade", crate, machine )
	return crate
end

local pendingShocks = {}

-- `ply` presses button k. Returns what happened: "dark" (no power), "dead" (already pressed),
-- "wrong" (klaxon, then a shock), "right", or "done" (that press finished the panel).
function Lunch.Press( ply, machine, k )
	if not living( ply ) or not isClass( machine, "lunch_machine" ) then return nil end
	k = tonumber( k )
	if not k or k < 1 or k > Lunch.BUTTONS or k ~= math.floor( k ) then return nil end
	if not Lunch.Powered( machine ) then
		machine:EmitSound( "buttons/button10.wav", 60 )
		return "dark"
	end
	local symbol = machine:GetButton( k )
	if symbol == 0 then
		machine:EmitSound( "buttons/button2.wav", 75, math.random( 75, 95 ) )
		return "dead"
	end
	if symbol ~= machine:GetLight() then
		machine:EmitSound( "ambient/alarms/klaxon1.wav" )
		table.insert( pendingShocks, { ply = ply, machine = machine, at = CurTime() + Lunch.WRONG_DELAY } )
		return "wrong"
	end
	machine:SetButton( k, 0 )
	machine:EmitSound( "buttons/blip1.wav", 75, math.random( 75, 95 ) )
	Lunch.Crew( machine, ply )
	if Lunch.Status( machine ) == "overload" and math.random() < Lunch.OVERLOAD_CHANCE then
		shock( ply, machine, math.random( Lunch.OVERLOAD_MIN, Lunch.OVERLOAD_MAX ) )
	end
	local any = false
	for i = 1, Lunch.BUTTONS do
		if machine:GetButton( i ) > 0 then any = true break end
	end
	if not any then
		Lunch.Finish( machine )
		return "done"
	end
	if not lit( machine, symbol ) or math.random() < Lunch.REROLL_CHANCE then Lunch.NewLight( machine ) end
	return "right"
end

-- What a player's use on the machine hits: a button, the lever, or nothing.
function Lunch.Use( ply, machine )
	local tr = util.TraceLine( { start = ply:GetShootPos(), endpos = ply:GetShootPos() + ply:GetAimVector() * 96, filter = ply } )
	if tr.Entity ~= machine then return nil end
	local k = Lunch.ButtonAt( machine, tr.HitPos )
	if k then return Lunch.Press( ply, machine, k ) end
	if Lunch.OnLever( machine, tr.HitPos ) then return Lunch.FlipLever( ply, machine ) end
end

-- Jobs ------------------------------------------------------------------------------------------

-- Loose things touching a machine or a boiler go in.
local function touchPosts()
	local machines, boilers = Lunch.All( "lunch_machine" ), Lunch.All( "line_boiler" )
	local function check( item, posts, fn )
		for _, post in ipairs( posts ) do
			if item:GetPos():DistToSqr( post:GetPos() ) < 250 * 250 and Lunch.Touching( post, item ) then
				fn( post, item )
				return
			end
		end
	end
	if #machines > 0 then
		for _, c in ipairs( Lunch.All( "meat_chunk" ) ) do check( c, machines, Lunch.Feed ) end
		for _, c in ipairs( Lunch.All( "bone_capsule" ) ) do check( c, machines, Lunch.Feed ) end
	end
	if #boilers > 0 then
		for _, b in ipairs( Lunch.All( "water_barrel" ) ) do
			if b:GetFull() then check( b, boilers, Lunch.Pour ) end
		end
	end
end

local FAST = 0.25
Sched.Every( "lunch", FAST, function()
	touchPosts()
	local now = CurTime()
	for i = #pendingShocks, 1, -1 do
		local s = pendingShocks[ i ]
		if now >= s.at then
			table.remove( pendingShocks, i )
			if IsValid( s.machine ) then
				s.machine:EmitSound( "beams/beamstart5.wav" )
				shock( s.ply, s.machine, Lunch.WRONG_SHOCK )
			end
		end
	end
	for _, m in ipairs( Lunch.All( "lunch_machine" ) ) do m:SetStatus( Lunch.Status( m ) ) end
end )

local nextCapsule = 0
Sched.Every( "lunch_slow", 1, function()
	for _, boiler in ipairs( Lunch.All( "line_boiler" ) ) do Lunch.TickBoiler( boiler, 1 ) end
	for _, barrel in ipairs( Lunch.All( "water_barrel" ) ) do Lunch.TickBarrel( barrel, 1 ) end
	local now = CurTime()
	for _, class in ipairs( { "bone_capsule", "meat_chunk" } ) do
		for _, e in ipairs( Lunch.All( class ) ) do
			if e.GR_DieAt and now >= e.GR_DieAt then
				Crates.Forget( e )
				gone( e )
			end
		end
	end
	if now >= nextCapsule then
		nextCapsule = now + math.Rand( Lunch.SPAWN_MIN, Lunch.SPAWN_MAX )
		Lunch.SpawnCapsule()
	end
end )

-- A new round: settled boiler, fresh panel, empty gauge, empty barrels, no loose capsules or chunks.
function Lunch.Reset()
	for _, b in ipairs( Lunch.All( "line_boiler" ) ) do
		b:SetVenting( false )
		b:SetPressure( Lunch.PRESSURE_START )
		b:SetWater( 0 )
	end
	for _, m in ipairs( Lunch.All( "lunch_machine" ) ) do
		m:SetBiomass( 0 )
		m:SetOutput( "ration" )
		m.GR_Crew = {}
		Lunch.Reroll( m )
	end
	for _, b in ipairs( Lunch.All( "water_barrel" ) ) do Lunch.SetBarrelFull( b, false ) end
	for _, class in ipairs( { "bone_capsule", "meat_chunk" } ) do
		for _, e in ipairs( Lunch.All( class ) ) do gone( e ) end
	end
	pendingShocks = {}
end

hook.Add( "GR_RoundStart", "gr_lunch", Lunch.Reset )
