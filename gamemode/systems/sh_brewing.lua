-- Brewing (step 11): beer and surgical spirit are made by proles, not seeded into the stock.
--
--   brew_barrel   a prole drops in one loaf (Econ.BREAD) and picks beer or spirit; the barrel seals
--                 and ferments for Config.BrewTime s. Anyone can smash a sealed barrel (Integrity
--                 Brew.INTEGRITY) or carry it off; only a prole opens a finished one: Brew.YIELD
--                 bottles fall out. Beer lowers despair, spirit cures the pox (sh_items.lua).
--   Bottles sell at the stockpile (Brew.SELL_AT) for the buy price, through Econ.Deliver.
--
-- Server API: Brew.Track( ent ), Brew.Count(), Brew.Fill( ply, ent, kind ), Brew.Open( ply, ent ),
--             Brew.Sell( ply, ent, good ), Brew.Think()  (Sched "brew", every second)
Brew = Brew or {}

Brew.IDLE, Brew.BREWING, Brew.DONE = 0, 1, 2
Brew.KINDS = { "fear_beer", "spirits" }          -- index = the barrel's Brew NetworkVar
Brew.KIND_INDEX = { fear_beer = 1, spirits = 2 }
Brew.YIELD = 3
Brew.INTEGRITY = 100
Brew.RANGE = 100
Brew.SELL_AT = { state_stockpile = true, gr_port = true }

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

Interact.Add( "brew_sell", {
	label = "Sell bottles",
	range = 120,
	show = function( ply, ent )
		if not living( ply ) or not IsValid( ent ) or not Brew.SELL_AT[ ent:GetClass() ] then return false end
		for _, id in ipairs( Brew.KINDS ) do
			if Inventory.Count( ply, id ) > 0 then return true end
		end
		return false
	end,
	choices = function( ply )
		local out = {}
		for _, id in ipairs( Brew.KINDS ) do
			if Inventory.Count( ply, id ) > 0 then
				table.insert( out, { string.format( "%s - %d bones", Items.Get( id ).Name, Econ.Setting( "buy." .. id ) ), id } )
			end
		end
		return out
	end,
	run = function( ply, ent, choice ) Brew.Sell( ply, ent, choice ) end,
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

function Brew.Sell( ply, ent, good )
	if not living( ply ) or not IsValid( ent ) or not Brew.SELL_AT[ ent:GetClass() ] then return false end
	if not Brew.KIND_INDEX[ good or "" ] or Inventory.Count( ply, good ) < 1 then return false end
	if not Inventory.Remove( ply, good, 1 ) then return false end
	return Econ.Deliver( ply, good )
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
