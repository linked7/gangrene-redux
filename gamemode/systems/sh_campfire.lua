-- Campfires (step 13). Three or more wood chunks within BUILD_RANGE fall into an unlit campfire;
-- there is no menu. Anything burning lights it, or a lighter (an import). It burns BASE seconds,
-- each more chunk adds PER_CHUNK up to MAX; burnt out it is a pit that new wood builds up again.
-- A lit fire ignites what touches it and is winter warmth (Winter.NearFire counts IsOnFire).
-- Unlit fires cost nothing: only lit ones are visited by the burn job.
Campfire = Campfire or {}
Campfire.BUILD_RANGE = 48
Campfire.BUILD_COUNT = 3
Campfire.BASE = 180
Campfire.PER_CHUNK = 60
Campfire.MAX = 480
Campfire.TOUCH_RANGE = 40
Campfire.LIGHTER_RANGE = 120

local function isFire( ent ) return IsValid( ent ) and ent:GetClass() == "gr_campfire" end

Items.Define( "lighter", {
	Name = "Lighter",
	Description = "A brass petrol lighter. Look at a campfire and use it to light it.",
	Weight = 0.2,
	Model = "models/props_junk/PopCan01a.mdl",
	OnUse = function( ply )
		local fire = ply:GetEyeTrace().Entity
		if not isFire( fire ) or ply:GetPos():Distance( fire:GetPos() ) > Campfire.LIGHTER_RANGE then
			if SERVER then Notify( ply, "Look at a campfire to light it." ) end
			return false
		end
		if SERVER and not Campfire.Light( fire ) then Notify( ply, "It won't take." ) end
		return false -- a lighter isn't used up
	end,
} )

Interact.Add( "campfire_light", {
	label = "Light the campfire",
	range = Campfire.LIGHTER_RANGE,
	show = function( ply, ent )
		return isFire( ent ) and not ent:GetLit() and ent:FuelLeft() > 0 and Inventory.Count( ply, "lighter" ) > 0
	end,
	run = function( ply, ent ) Campfire.Light( ent ) end,
} )

if not SERVER then return end

local fires = Campfire.fires or setmetatable( {}, { __mode = "k" } )
local lit = Campfire.lit or setmetatable( {}, { __mode = "k" } )
local items = Campfire.items or setmetatable( {}, { __mode = "k" } )
Campfire.fires, Campfire.lit, Campfire.items = fires, lit, items

function Campfire.Track( ent ) fires[ ent ] = true end
function Campfire.IsLit( ent ) return lit[ ent ] == true end

hook.Add( "OnEntityCreated", "gr_campfire_items", function( ent )
	if ent:GetClass() == "gr_item" then items[ ent ] = true end
end )

function Campfire.AddFuel( fire, secs )
	if fire:GetLit() then
		fire:SetBurnEnd( math.min( fire:GetBurnEnd() + secs, CurTime() + Campfire.MAX ) )
	else
		fire:SetFuel( math.min( fire:GetFuel() + secs, Campfire.MAX ) )
	end
end

function Campfire.Light( fire )
	if not isFire( fire ) or fire:GetLit() or fire:GetFuel() <= 0 then return false end
	fire:SetBurnEnd( CurTime() + fire:GetFuel() )
	fire:SetFuel( 0 )
	fire:SetLit( true )
	fire:Ignite( Campfire.MAX + 60, 0 )
	lit[ fire ] = true
	return true
end

-- Out of wood: the fire dies down to a pit.
function Campfire.Douse( fire )
	lit[ fire ] = nil
	if not IsValid( fire ) then return end
	fire:SetLit( false )
	fire:SetFuel( 0 )
	fire:Extinguish()
end

function Campfire.Build( pos, chunks )
	local fire = ents.Create( "gr_campfire" )
	fire:SetPos( pos )
	fire:Spawn()
	fire:SetFuel( math.min( Campfire.BASE + ( chunks - Campfire.BUILD_COUNT ) * Campfire.PER_CHUNK, Campfire.MAX ) )
	return fire
end

-- Something touching a fire: a burning thing lights it, a lit fire sets the thing alight.
function Campfire.Touched( fire, other )
	if not IsValid( other ) or other == fire or other:IsWorld() then return end
	if not fire:GetLit() then
		if other:IsOnFire() then Campfire.Light( fire ) end
		return
	end
	if ( other:IsPlayer() and other:Alive() ) or other:GetClass():sub( 1, 5 ) == "prop_" then
		if not other:IsOnFire() then other:Ignite( 5, 0 ) end
	end
end

local function near( a, b ) return a:GetPos():DistToSqr( b:GetPos() ) <= Campfire.BUILD_RANGE ^ 2 end

-- Wood on the ground: feeds a fire it lies by, or enough chunks together become a new one.
Sched.Every( "campfire_build", 1, function()
	local wood = {}
	for e in pairs( items ) do
		if not IsValid( e ) then items[ e ] = nil
		elseif e:GetItemId() == "wood" then wood[ #wood + 1 ] = e end
	end
	if #wood == 0 then return end
	local used = {}
	for _, w in ipairs( wood ) do
		for f in pairs( fires ) do
			if IsValid( f ) and near( w, f ) then
				Campfire.AddFuel( f, w:GetCount() * Campfire.PER_CHUNK )
				used[ w ] = true
				w:Remove()
				break
			end
		end
	end
	for _, w in ipairs( wood ) do
		if not used[ w ] then
			local group, n, sum = {}, 0, Vector( 0, 0, 0 )
			for _, o in ipairs( wood ) do
				if not used[ o ] and near( w, o ) then
					group[ #group + 1 ] = o
					n = n + o:GetCount()
					sum = sum + o:GetPos() * o:GetCount()
				end
			end
			if n >= Campfire.BUILD_COUNT then
				local pos = sum / n
				local tr = util.TraceLine( { start = pos + Vector( 0, 0, 8 ), endpos = pos - Vector( 0, 0, 64 ), mask = MASK_SOLID_BRUSHONLY } )
				for _, o in ipairs( group ) do used[ o ] = true o:Remove() end
				Campfire.Build( tr.HitPos, n )
			end
		end
	end
end )

-- Lit fires only: burn down, and set alight whoever stands in them.
Sched.Every( "campfire_burn", 0.5, function()
	local now = CurTime()
	for fire in pairs( lit ) do
		if not IsValid( fire ) then lit[ fire ] = nil
		elseif now >= fire:GetBurnEnd() then Campfire.Douse( fire )
		else
			if not fire:IsOnFire() then fire:Ignite( Campfire.MAX + 60, 0 ) end
			for _, e in ipairs( ents.FindInSphere( fire:GetPos(), Campfire.TOUCH_RANGE ) ) do
				Campfire.Touched( fire, e )
			end
		end
	end
end )
