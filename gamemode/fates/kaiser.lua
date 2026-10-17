-- The head of state (step 11.4). The tools live in systems/sh_kaiser.lua; this file only says
-- what the role may do. The kit (novoluger and strategy book) is defined there as items.
Fates.Define( "kaiser", {
	Name = "Witch Kaiser",
	Description = "The most stressful job in Gangrene.",
	Color = Color( 200, 0, 0 ),
	ChatSounds = { "placenta/speech/kaiser1.wav", "placenta/speech/kaiser2.wav", "placenta/speech/kaiser3.wav", "placenta/speech/kaiser4.wav", "placenta/speech/kaiser5.wav", "placenta/speech/kaiser6.wav" },
	Cost = 5,
	-- No rank gate for now (plan, step 11.4): stem cells and the one slot decide. Gates are undecided.
	Slots = 1,
	DeathCooldown = 600,
	Health = 100,
	Armor = 75,
	Radio = { "state" },
	RunsEconomy = true,     -- sets the Economy table, grants and fines (step 9); no wage
	StockpileAccess = true, -- takes from the stockpile for free
	PainSounds = { "placenta/pain/sanitar1.wav", "placenta/pain/sanitar2.wav", "placenta/pain/sanitar3.wav", "placenta/pain/sanitar4.wav" },
	DeathSounds = { "placenta/death/sanitar1.wav", "placenta/death/sanitar2.wav" },
	NoFinalDeathSound = true,
	SpitDespair = 8, -- being spat on by the head of state hurts twice as much (sh_weapons.lua)
	SpitLine = "The Witch Kaiser spit on me!",
	IntroTexts = {
		{ Color( 200, 200, 0 ), "You command the laws and other various variables of our belovungure. Don't get overwhelmed, you need to be on your best alert to avoid assassinations. You can also communicate with the sanitars over your radio (/r)." },
		{ Color( 100, 100, 100 ), "You were known now and forever as the sole Witch Kaiser of Gangrene. You can use your context menu (C by default) to sentence people to death or to forgive them.\nAs the most important position in Gangrene, abusing this role or breaking character is very likely to have you recieve a harsh punishment." },
	},
	Sovereign = true, -- the law itself: kills by the head of state are never crimes
	CanSentence = true, -- sentences and forgives (sh_kaiser.lua)
	-- Fate upgrades the Kaiser may buy, fate id -> bones from the treasury into the upgrade fund (R3).
	Upgrades = { prole = 125, korpsman = 150 },
	Kit = { "novoluger", "strategy_book" }, -- items handed over when the role is taken
	KitAmmo = 2,                              -- two clips of reserve for the novoluger (the original kommandant)
	Faction = "state",
	Authority = 3, -- leader
	Names = function() return math.random( 100 ) == 1 and "Watch Kaiser Thule" or "Witch Kaiser Thule" end,
	Appearance = { model = "models/player/breen.mdl", race = "gangral" },
} )
