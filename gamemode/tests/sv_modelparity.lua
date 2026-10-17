-- Ground rule 9: a ported entity wears the original's model and material. Each row is our class,
-- the original file under liverfailurewar/entities/entities/, and what that file sets on spawn
-- (type variants and broken effects left out: bone_capsule's 1-in-15 flesh skin, faucet's broken skin).
local PORTS = {
	{ "bone_capsule",  "fleshcapsule.lua",   "models/gibs/antlion_gib_large_3.mdl",  "" },
	{ "lunch_machine", "machine_lunch.lua",  "models/props_lab/reciever_cart.mdl",   "" },
	{ "fate_station",  "purpose_in_life.lua", "models/props_junk/sawblade001a.mdl",  "models/props_combine/masterinterface01c" },
	{ "water_pump",    "faucet.lua",         "models/props_interiors/sinkkitchen01a.mdl", "" },
}

return function( T )
	local bot = player.CreateNextBot( "tmp_a" )
	local pos = bot:GetPos() + bot:GetForward() * 120 + Vector( 0, 0, 40 )
	for _, row in ipairs( PORTS ) do
		local class, orig, model, mat = row[ 1 ], row[ 2 ], row[ 3 ], row[ 4 ]
		local ent = ents.Create( class )
		T.Check( IsValid( ent ), class .. " spawns (port of " .. orig .. ")" )
		if IsValid( ent ) then
			ent:SetPos( pos )
			ent:Spawn()
			ent:Activate()
			T.Equal( string.lower( ent:GetModel() ), string.lower( model ), class .. " model matches " .. orig )
			T.Equal( ent:GetMaterial(), mat, class .. " material matches " .. orig )
			ent:Remove()
		end
	end
	bot:Kick()
end
