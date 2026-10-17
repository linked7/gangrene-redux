-- Placeholder: step 11 adds reviving for a fee, faster regeneration and surgery.
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
	Names = function() return NAMES[ math.random( #NAMES ) ] .. " #" .. math.random( 100 ) end,
	Appearance = function()
		return { model = string.format( "models/player/group03m/male_0%d.mdl", math.random( 9 ) ), race = "gangral" }
	end,
} )
