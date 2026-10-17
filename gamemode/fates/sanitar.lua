-- Sanitar: the police (step 11.3). Police = true is what Crime and Police (sh_police.lua) look for:
-- inspect, arrest, bounties in Teeth and the sanitation station. Kit is the baton and the scope,
-- as items, so they lie on the body when the sanitar goes down.
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
	Kit = { "baton", "scope" }, -- sh_kit.lua; a revived sanitar gets the body's own kit back instead
} )
