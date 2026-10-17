-- Placeholder: step 11 adds the tax panel, sentencing, upgrades and the novoluger.
Fates.Define( "kaiser", {
	Name = "Witch Kaiser",
	Description = "The most stressful job in Gangrene.",
	Color = Color( 200, 0, 0 ),
	Cost = 5,
	MinRank = RANK_KAISER,
	Slots = 1,
	DeathCooldown = 600,
	Health = 100,
	Armor = 75,
	Radio = { "state" },
	RunsEconomy = true,     -- sets the Economy table, grants and fines (step 9)
	StockpileAccess = true, -- takes from the stockpile for free
	Names = function() return math.random( 100 ) == 1 and "Watch Kaiser Thule" or "Witch Kaiser Thule" end,
	Appearance = { model = "models/player/breen.mdl", race = "gangral" },
} )
