-- A capsule_spawn point (step 11.1): where bone capsules appear. Placed by the map layout
-- (rp_slumtown's come from the original's GM.Capsules); systems/sh_lunch.lua picks one at random.
AddCSLuaFile()

ENT.Type = "point"
ENT.Base = "base_point"
ENT.PrintName = "Capsule Spawn"
ENT.Spawnable = false

function ENT:Initialize()
	if SERVER then Lunch.Track( self ) end
end
