-- Placeholder: step 11 adds the baton, scope and Teeth.
local NOUNS = { "Cleaner", "Janitor", "Officer", "Sanitator", "Purifier", "Filter", "Operator", "Enforcer",
	"Disinfectant", "Antiseptic", "Cleanser" }

Fates.Define( "sanitar", {
	Name = "Sanitar",
	Description = "The keeper of all things moral, safe, and clean... hopefully.",
	Color = Color( 0, 200, 0 ),
	Cost = 2,
	DeathCooldown = 120,
	Slots = function( pop ) return math.Clamp( 2 + math.floor( pop / 10 ), 2, 6 ) end,
	Police = true,
	StockpileAccess = true, -- guarding the stockpile is part of the job
	Wage = 40,              -- default wage.sanitar in the Economy table
	Faction = "state",
	Authority = 1,
	Radio = { "state" },
	Names = function() return NOUNS[ math.random( #NOUNS ) ] .. " #" .. math.random( 11, 99 ) end,
	Appearance = { model = "models/player/police.mdl", race = "gangral" },
} )
