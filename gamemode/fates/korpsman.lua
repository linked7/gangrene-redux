-- The revive and healing loop (step 11.2). The rules live in systems/sh_medicine.lua and read these
-- fields: RegenMulti, ReviveFee, Surgeon, Lovebox.
local NAMES = { "Medic", "Doctor", "Physician", "Helix", "Haruspex", "Bachelor", "Dissector", "Surgeon", "Nurse",
	"Practitioner", "Traumist", "Paramedic" }

Fates.Define( "korpsman", {
	Name = "Korpsman",
	Description = "The healer of all maladies physical and pathological. Only Gangrene's finest should be treated for free.",
	Color = Color( 200, 200, 200 ),
	Cost = 1,
	DeathCooldown = 60,
	Slots = function( pop ) return math.Clamp( 2 + math.floor( pop / 10 ), 2, 5 ) end,
	Citizen = true,
	Radio = { "medic" },
	CanRevive = true,
	ReviveFee = true, -- takes the Economy's revive_fee percent of the patient's carried bones
	RegenMulti = 3,
	Surgeon = true,
	Lovebox = true,   -- only once the Kaiser buys the korpsman upgrade
	Kit = { "surgical_tools" }, -- sh_kit.lua; a revived korpsman keeps what the body held
	Names = function() return NAMES[ math.random( #NAMES ) ] .. " #" .. math.random( 100 ) end,
	Appearance = function()
		return { model = string.format( "models/player/group03m/male_0%d.mdl", math.random( 9 ) ), race = "gangral" }
	end,
} )
