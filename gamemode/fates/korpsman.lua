-- The revive and healing loop (step 11.2). The rules live in systems/sh_medicine.lua and read these
-- fields: RegenMulti, ReviveFee, Surgeon, Lovebox.
local NAMES = { "Medic", "Doctor", "Physician", "Helix", "Haruspex", "Bachelor", "Dissector", "Surgeon", "Nurse",
	"Practitioner", "Traumist", "Paramedic" }
-- Boots (the original's korpsman Footstep): quiet at a walk, loud at a run.
local BOOTS = { "npc/footsteps/hardboot_generic1.wav", "npc/footsteps/hardboot_generic2.wav", "npc/footsteps/hardboot_generic3.wav",
	"npc/footsteps/hardboot_generic4.wav", "npc/footsteps/hardboot_generic5.wav", "npc/footsteps/hardboot_generic6.wav",
	"npc/footsteps/hardboot_generic8.wav" }

Fates.Define( "korpsman", {
	Name = "Korpsman",
	Description = "The healer of all maladies physical and pathological. Only Gangrene's finest should be treated for free.",
	Color = Color( 200, 200, 200 ),
	ChatSounds = { "placenta/speech/korps1.wav", "placenta/speech/korps2.wav", "placenta/speech/korps3.wav", "placenta/speech/korps4.wav" },
	Cost = 1,
	DeathCooldown = 60,
	Slots = function( pop ) return math.Clamp( 2 + math.floor( pop / 10 ), 2, 5 ) end,
	Citizen = true,
	Radio = { "medic" },
	CanRevive = true,
	ReviveFee = true, -- takes the Economy's revive_fee percent of the patient's carried bones
	RegenMulti = 3,
	Footstep = function( ply ) ply:EmitSound( BOOTS[ math.random( #BOOTS ) ], ply:GetVelocity():Length2D() < 150 and 35 or 75 ) end,
	Surgeon = true,
	Lovebox = true,   -- only once the Kaiser buys the korpsman upgrade
	Kit = { "surgical_tools" }, -- sh_kit.lua; a revived korpsman keeps what the body held
	Names = function() return NAMES[ math.random( #NAMES ) ] .. " #" .. math.random( 100 ) end,
	Appearance = function()
		return { model = string.format( "models/player/group03m/male_0%d.mdl", math.random( 9 ) ), race = "gangral" }
	end,
} )
