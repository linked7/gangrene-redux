-- Brewing (step 11): beer and surgical spirit are made by hand, not seeded into the stock. No timer.
--
--   brew_barrel   the original's "Booze Bucket". A two-position lever on its rim (use on it) picks
--                 beer or spirits. A ration touching the barrel is swallowed (it must be empty);
--                 then Brew.HITS melee hits or hard shakes (bumps over Brew.SHAKE_SPEED) finish
--                 the batch: Brew.YIELD bottles go straight into the stockpile (the port sells them).
--                 Beer lowers despair, spirit cures the pox (sh_items.lua).
--
-- Server API: Brew.Track( ent ), Brew.Count(), Brew.FlipLever( ent ), Brew.Feed( ent, item ),
--             Brew.Agitate( ent ), Brew.Use( ply, ent )
Brew = Brew or {}

Brew.IDLE, Brew.BREWING = 0, 1
Brew.KINDS = { "fear_beer", "spirits" }          -- index = the barrel's Brew NetworkVar (the lever)
Brew.KIND_INDEX = { fear_beer = 1, spirits = 2 }
Brew.YIELD = 3
Brew.HITS = 8
Brew.SHAKE_SPEED = 120
Brew.SHAKE_GAP = 0.25 -- debounce so one bump isn't counted twice

local LEVER = Vector( 0, 12, 40 )
local LEVER_TOLERANCE = 7
function Brew.LeverPos( ent ) return ent:LocalToWorld( LEVER ) end
function Brew.OnLever( ent, pos ) return Brew.LeverPos( ent ):Distance( pos ) <= LEVER_TOLERANCE end

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

local function isBarrel( ent ) return IsValid( ent ) and ent:GetClass() == "brew_barrel" end

function Brew.FlipLever( ent )
	if not isBarrel( ent ) then return false end
	ent:SetBrew( ent:GetBrew() == 1 and 2 or 1 )
	ent:EmitSound( "buttons/lever" .. math.random( 1, 8 ) .. ".wav", 70 )
	return true
end

-- A ration touching an empty barrel is swallowed (the original's gulp and splash).
function Brew.Feed( ent, item )
	if not isBarrel( ent ) or ent:GetState() ~= Brew.IDLE then return false end
	if not IsValid( item ) or item.GR_Gone or item:GetClass() ~= "gr_item" or item:GetItemId() ~= Econ.BREAD then return false end
	item.GR_Gone = true
	item:EmitSound( "npc/barnacle/barnacle_gulp" .. math.random( 1, 2 ) .. ".wav" )
	local e = EffectData()
	e:SetOrigin( item:GetPos() )
	e:SetScale( 0.5 )
	util.Effect( "StriderBlood", e )
	item:Remove()
	ent:SetState( Brew.BREWING )
	ent:SetHits( 0 )
	return true
end

-- One melee hit or shake. The last one empties the batch into the stockpile.
function Brew.Agitate( ent )
	if not isBarrel( ent ) or ent:GetState() ~= Brew.BREWING then return false end
	ent:SetHits( ent:GetHits() + 1 )
	ent:EmitSound( "ambient/levels/canals/toxic_slime_sizzle" .. math.random( 1, 4 ) .. ".wav", 60, math.random( 70, 90 ) )
	if ent:GetHits() < Brew.HITS then return true end
	local id = Brew.KINDS[ ent:GetBrew() ] or Brew.KINDS[ 1 ]
	Econ.AddStock( id, Brew.YIELD )
	ent:SetState( Brew.IDLE )
	ent:SetHits( 0 )
	ent:EmitSound( "ambient/levels/canals/toxic_slime_gurgle6.wav", 70, math.random( 90, 100 ) )
	ent:EmitSound( "ambient/materials/flush" .. math.random( 1, 2 ) .. ".wav", 70, math.random( 90, 100 ) )
	local e = EffectData()
	e:SetOrigin( ent:GetPos() )
	e:SetScale( 0.6 )
	util.Effect( "BloodImpact", e )
	Log.Info( "brew", "a barrel finished %d %s into the stockpile", Brew.YIELD, id )
	return id
end

function Brew.Shake( ent, speed )
	if speed < Brew.SHAKE_SPEED or ( ent.GR_NextShake or 0 ) > CurTime() then return false end
	ent.GR_NextShake = CurTime() + Brew.SHAKE_GAP
	return Brew.Agitate( ent )
end

-- Use on the lever flips it; anywhere else picks the barrel up.
function Brew.Use( ply, ent )
	local tr = util.TraceLine( { start = ply:GetShootPos(), endpos = ply:GetShootPos() + ply:GetAimVector() * 96, filter = ply } )
	if tr.Entity == ent and Brew.OnLever( ent, tr.HitPos ) then return Brew.FlipLever( ent ) end
	if not ent:IsPlayerHolding() then ply:PickupObject( ent ) end
end
