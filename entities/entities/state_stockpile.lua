-- The state stockpile: the counter where the city's food is kept. It holds counts, not entities;
-- the counts are public world state owned by Econ (stock.<good>), so every stockpile on the map
-- shares one store. Buying, free withdrawal and the bread line go through `gr_counter`.
-- Step 11.1's crates call Econ.Deliver when they touch it.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "State Stockpile"
ENT.Spawnable = false

if CLIENT then return end

function ENT:Initialize()
	self:SetModel( "models/props_wasteland/controlroom_storagecloset001a.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetUseType( SIMPLE_USE )
end

-- Until the counter has a UI, using it reads out what is on offer.
function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() or activator:IsGhost() then return end
	local lines = {}
	for _, good in ipairs( Econ.GOODS ) do
		table.insert( lines, string.format( "%s: %d in stock, %d bones", good, Econ.Stock( good ), Econ.Setting( "sell." .. good ) ) )
	end
	Notify( activator, table.concat( lines, "; " ) .. ". (gr_counter buy|take|free <good>)" )
end
