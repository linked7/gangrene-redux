-- WINTER (step 13): the first malady. Outdoors (sky overhead) the Cold need rises faster each
-- stage; water is lethal from stage 2. A fire, a roof, a recent burn or a full belly warm you;
-- a coat cuts the cold. Freezing alone in late winter is quicker. Cold at 100 kills.
Winter = Winter or {}
Winter.OUTDOOR = { 0.4, 0.8, 1.5, 2.5 } -- Cold per second outdoors, by stage
Winter.WATER = { 0, 6, 40, 40 }         -- extra Cold per second in water, by stage
Winter.ALONE_LETHAL = 25                -- extra when alone outdoors at stage 4
Winter.FIRE_RANGE = 250
Winter.ALONE_RANGE = 400
Winter.WARM = { fire = 4, indoors = 1.5, burn = 4, fed = 0.5 }
Winter.COAT_MULT = 0.4

Needs.Define( "Cold", {
	rate = 0,
	thresholds = {
		[ 30 ] = "It's so very cold.",
		[ 60 ] = "You can't feel your fingers anymore.",
		[ 85 ] = "Remorseless winter gnaws at your bones.",
	},
	onMax = function( ply ) if SERVER and ply:Alive() then ply:Kill() end end,
} )

Items.Define( "coat", {
	Name = "Winter Coat",
	Description = "A padded coat for the Ghoulag's freezing climate. They only make these for guards.",
	Weight = 3,
	Model = "models/ccr/clothing/itemouterwear.mdl",
	Tags = { clothing = true },
	OnUse = function( ply ) if SERVER then Winter.Wear( ply, not ply.GR_Coat ) end end,
} )

Maladies.Register( "winter", {
	Name = "WINTER",
	Stages = {
		"The air turns bitter. Winter is coming to the Ghoulag.",
		"Snow falls. The water has turned deadly cold.",
		"A hard frost grips the city. Stay by the fires.",
		"Remorseless winter. Nobody survives the cold alone.",
	},
	OnEnd = function()
		if CLIENT then return end
		for _, p in player.Iterator() do Needs.Add( p, "Cold", -1000, "winter_end" ) end
	end,
} )

if CLIENT then return end

function Winter.Wear( ply, on )
	ply.GR_Coat = on and true or nil
	local bg = ply:FindBodygroupByName( "coat" )
	if bg and bg >= 0 then ply:SetBodygroup( bg, on and 1 or 0 ) end
	Notify( ply, on and "You put on the coat." or "You take off the coat." )
end

function Winter.Indoors( ply )
	local pos = ply:EyePos()
	local tr = util.TraceLine( { start = pos, endpos = pos + Vector( 0, 0, 4096 ), mask = MASK_SOLID_BRUSHONLY } )
	return tr.Hit and not tr.HitSky
end

function Winter.NearFire( ply )
	for _, e in ipairs( ents.FindInSphere( ply:GetPos(), Winter.FIRE_RANGE ) ) do
		if e:GetClass() == "env_fire" or e:IsOnFire() then return true end
	end
	return false
end

function Winter.Alone( ply )
	for _, e in ipairs( ents.FindInSphere( ply:GetPos(), Winter.ALONE_RANGE ) ) do
		if e ~= ply and e:IsPlayer() and e:Alive() then return false end
	end
	return true
end

-- Cold gained and warmth regained per second for `ply` at `stage`.
function Winter.Rate( ply, stage )
	local cold, warm = 0, 0
	if ply:WaterLevel() >= 2 then cold = cold + ( Winter.WATER[ stage ] or 0 ) end
	if Winter.Indoors( ply ) then
		warm = warm + Winter.WARM.indoors
	else
		cold = cold + ( Winter.OUTDOOR[ stage ] or 0 )
		if stage >= 4 and Winter.Alone( ply ) then cold = cold + Winter.ALONE_LETHAL end
	end
	if Winter.NearFire( ply ) then warm = warm + Winter.WARM.fire end
	if CurTime() - ( ply.GR_BurnAt or -100 ) < 5 then warm = warm + Winter.WARM.burn end
	if Needs.Get( ply, "Emptiness" ) < 30 then warm = warm + Winter.WARM.fed end
	return cold, warm
end

table.insert( Needs.Modifiers, function( ply, name, amount, source )
	if name == "Cold" and source == "winter" and ply.GR_Coat then return amount * Winter.COAT_MULT end
	return amount
end )

hook.Add( "EntityTakeDamage", "gr_winter", function( ent, dmg )
	if ent:IsPlayer() and dmg:IsDamageType( DMG_BURN ) then ent.GR_BurnAt = CurTime() end
end )
hook.Add( "PlayerSpawn", "gr_winter", function( ply ) ply.GR_Coat = nil end )

Sched.EachPlayer( "winter", 1, function( ply )
	if not Maladies.Is( "winter", 1 ) or not ply:Alive() or ply:IsGhost() then return end
	local cold, warm = Winter.Rate( ply, Maladies.Stage() )
	if cold > 0 then Needs.Add( ply, "Cold", cold, "winter" ) end
	if warm > 0 then Needs.Add( ply, "Cold", -warm, "warmth" ) end
end )
