-- The head of state (step 11.4). The tools live in systems/sh_kaiser.lua; this file only says
-- what the role may do. The kit (novoluger and strategy book) is defined there as items.
Fates.Define( "kaiser", {
	Name = "Witch Kaiser",
	Description = "The most stressful job in Gangrene.",
	Color = Color( 200, 0, 0 ),
	Cost = 5,
	-- No rank gate for now (plan, step 11.4): stem cells and the one slot decide. Gates are undecided.
	Slots = 1,
	DeathCooldown = 600,
	Health = 100,
	Armor = 75,
	Radio = { "state" },
	RunsEconomy = true,     -- sets the Economy table, grants and fines (step 9); no wage
	StockpileAccess = true, -- takes from the stockpile for free
	Sovereign = true, -- the law itself: kills by the head of state are never crimes
	CanSentence = true, -- sentences and forgives (sh_kaiser.lua)
	-- Fate upgrades the Kaiser may buy, fate id -> bones from the treasury into the upgrade fund (R3).
	Upgrades = { prole = 125, korpsman = 150 },
	Kit = { "novoluger", "strategy_book" }, -- items handed over when the role is taken
	Faction = "state",
	Authority = 3, -- leader
	Names = function() return math.random( 100 ) == 1 and "Watch Kaiser Thule" or "Witch Kaiser Thule" end,
	Appearance = { model = "models/player/breen.mdl", race = "gangral" },
} )
