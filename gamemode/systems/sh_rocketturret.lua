-- The rocket turret (Liver Failure sv_think RocketTurretSpots): one turret_rocket at a time,
-- spawned every 600-900 s at one of the map's spots, tracked by reference (never FindByClass).
--   RocketTurret.Get()                the live turret or nil
--   RocketTurret.Spawn( [pos] )       spawn one now (replaces nothing; returns nil if one stands)
--   RocketTurret.SPOTS[ map ]         spawn points
-- The turret idles at night, in meat or ritual weather and during a ceasefire (GR_TurretIdle).
RocketTurret = RocketTurret or {}
RocketTurret.SPOTS = {
	rp_slumtown = { Vector( 5191, 367, 654 ), Vector( 4024, 750, 538 ), Vector( 3089, 253, 689 ) },
}
RocketTurret.MIN, RocketTurret.MAX = 600, 900

Items.Define( "rocket", {
	Name = "Rocket",
	Description = "A live rocket pried from a turret.",
	Weight = 3,
	Model = "models/weapons/w_missile_closed.mdl",
} )
Items.Define( "artifact_ai", {
	Name = "Machine Brain",
	Description = "The thinking part of a rocket turret. Still warm.",
	Weight = 2,
	Model = "models/Combine_Helicopter/helicopter_bomb01.mdl",
} )
Items.Define( "permit_turret", {
	Name = "Turret Permit",
	Description = "The turrets will not fire on whoever carries this.",
	Weight = 0.1,
	Model = "models/props_c17/paper01.mdl",
} )

if CLIENT then
	HUD.CrossTexts.turret_rocket = function( ent, ply, ct )
		table.insert( ct, { text = "Rocket Turret", color = Color( 220, 40, 40 ) } )
		table.insert( ct, { text = "Integrity: " .. ent:GetIntegrity(), color = Color( 200, 200, 200 ) } )
		if ent:GetLocked() then table.insert( ct, { text = "Locked down", color = Color( 160, 160, 160 ) } ) end
	end
	return
end

local turret

function RocketTurret.Get() return IsValid( turret ) and turret or nil end

function RocketTurret.Spawn( pos )
	if RocketTurret.Get() then return nil end
	if not pos then
		local spots = RocketTurret.SPOTS[ game.GetMap() ]
		if not spots or #spots == 0 then return nil end
		pos = spots[ math.random( #spots ) ]
	end
	local e = ents.Create( "turret_rocket" )
	e:SetPos( pos )
	e:SetAngles( Angle( math.random( 0, 360 ), math.random( 0, 360 ), math.random( 0, 360 ) ) )
	e:Spawn()
	e:Activate()
	e:EmitSound( "ambient/machines/teleport3.wav", 150, 60 + math.random( 1, 20 ), 1 )
	turret = e
	return e
end

-- Weather and ceasefire, when those systems exist
hook.Add( "GR_TurretIdle", "gr_rocketturret", function()
	if Weather and Weather.Current and ( Weather.Current == WEATHER_NIGHT or Weather.Current == WEATHER_MEAT
		or ( WEATHER_RITUAL and Weather.Current == WEATHER_RITUAL ) ) then return true end
	if Ceasefire and Ceasefire.Active and Ceasefire.Active() then return true end
end )

local nextSpawn = CurTime() + math.random( RocketTurret.MIN, RocketTurret.MAX )
Sched.Every( "rocketturret", 0.2, function()
	local t = RocketTurret.Get()
	if t then t:Tick() return end
	if CurTime() >= nextSpawn then
		nextSpawn = CurTime() + math.random( RocketTurret.MIN, RocketTurret.MAX )
		RocketTurret.Spawn()
	end
end )
