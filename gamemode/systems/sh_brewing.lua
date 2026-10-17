-- Brewing (step 11): beer and surgical spirit are made by proles, not seeded into the stock.
--
--   brew_barrel   a prole drops in one loaf (Econ.BREAD) and picks beer or spirit; the barrel seals
--                 and ferments for Config.BrewTime s. Anyone can smash a sealed barrel (Integrity
--                 Brew.INTEGRITY) or carry it off; only a prole opens a finished one: Brew.YIELD
--                 bottles fall out. Beer lowers despair, spirit cures the pox (sh_items.lua).
--   Bottles sell back at a stockpile_port for their buy price (Shop.Sell, sh_shop.lua).
--
-- Server API: Brew.Track( ent ), Brew.Count(), Brew.Fill( ply, ent, kind ), Brew.Open( ply, ent ),
--             Brew.Think()  (Sched "brew", every second)
Brew = Brew or {}

Brew.IDLE, Brew.BREWING, Brew.DONE = 0, 1, 2
Brew.KINDS = { "fear_beer", "spirits" }          -- index = the barrel's Brew NetworkVar
Brew.KIND_INDEX = { fear_beer = 1, spirits = 2 }
Brew.YIELD = 3
Brew.INTEGRITY = 100
Brew.RANGE = 100

local function living( ply ) return IsValid( ply ) and ply:Alive() and not ply:IsGhost() end
local function isBarrel( ent ) return IsValid( ent ) and ent:GetClass() == "brew_barrel" end
local function prole( ply ) return living( ply ) and ply:FateHas( "Proletariat" ) end

Interact.Add( "brew_fill", {
	label = "Brew",
	range = Brew.RANGE,
	show = function( ply, ent )
		return isBarrel( ent ) and ent:GetState() == Brew.IDLE and prole( ply ) and Inventory.Count( ply, Econ.BREAD ) > 0
	end,
	choices = function()
		local out = {}
		for i, id in ipairs( Brew.KINDS ) do table.insert( out, { Items.Get( id ).Name, id } ) end
		return out
	end,
	run = function( ply, ent, choice ) Brew.Fill( ply, ent, choice ) end,
} )

Interact.Add( "brew_open", {
	label = "Open the barrel",
	range = Brew.RANGE,
	show = function( ply, ent ) return isBarrel( ent ) and ent:GetState() == Brew.DONE and prole( ply ) end,
	run = function( ply, ent ) Brew.Open( ply, ent ) end,
} )

if CLIENT then return end

local barrels = {}

function Brew.Track( ent ) barrels[ ent ] = true end
function Brew.Count()
	local n = 0
	for ent in pairs( barrels ) do
		if IsValid( ent ) then n = n + 1 else barrels[ ent ] = nil end
	end
	return n
end

function Brew.Fill( ply, ent, kind )
	if not isBarrel( ent ) or ent:GetState() ~= Brew.IDLE or not prole( ply ) then return false end
	local idx = Brew.KIND_INDEX[ kind or "" ]
	if not idx then return false end
	if Inventory.Count( ply, Econ.BREAD ) < 1 or not Inventory.Remove( ply, Econ.BREAD, 1 ) then
		Notify( ply, "You need a loaf to brew." )
		return false
	end
	ent:SetBrew( idx )
	ent:SetState( Brew.BREWING )
	ent:SetFinishAt( CurTime() + Config.BrewTime )
	ent:SetIntegrity( Brew.INTEGRITY )
	ent:EmitSound( "physics/wood/wood_box_impact_hard3.wav" )
	Log.Info( "brew", "%s sealed a barrel of %s", ply:Nick(), kind )
	return true
end

function Brew.Open( ply, ent )
	if not isBarrel( ent ) or ent:GetState() ~= Brew.DONE or not prole( ply ) then return false end
	local id = Brew.KINDS[ ent:GetBrew() ]
	if not id then return false end
	ent:SetState( Brew.IDLE )
	ent:SetBrew( 0 )
	ent:SetFinishAt( 0 )
	ent:EmitSound( "ambient/water/water_splash1.wav" )
	return Items.SpawnMany( { { id, 1 }, { id, 1 }, { id, 1 } }, ent:GetPos() + Vector( 0, 0, 50 ), ent:GetAngles() )
end

-- A sealed barrel that has been hit loses Integrity (brew_barrel's OnTakeDamage); at 0 it bursts.
function Brew.Smash( ent )
	ent:EmitSound( "physics/wood/wood_crate_break" .. math.random( 1, 5 ) .. ".wav" )
	local fx = EffectData()
	fx:SetOrigin( ent:WorldSpaceCenter() )
	util.Effect( "WaterSplash", fx )
	ent:Remove()
end

function Brew.Think()
	local now = CurTime()
	for ent in pairs( barrels ) do
		if not IsValid( ent ) then
			barrels[ ent ] = nil
		elseif ent:GetState() == Brew.BREWING and now >= ent:GetFinishAt() then
			ent:SetState( Brew.DONE )
			ent:EmitSound( "ambient/levels/canals/toxic_slime_gurgle4.wav" )
		end
	end
end

Sched.Every( "brew", 1, Brew.Think )
