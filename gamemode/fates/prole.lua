-- The worker: makes the city's food at the lunch machine and hauls it to the stockpile (systems/sh_crates.lua),
-- builds with the permit tool (systems/sh_build.lua). Kit and aim are data read by systems/sh_kit.lua.
-- Models are stock GMod placeholders until the gamemode has its own content.
local ADJ = { "Proud", "Reliable", "Trustworthy", "Beloved", "Respected", "Diligent", "Complacent", "Happy",
	"Fulfilled", "Accomplished", "Industrious", "Calloused", "Greasy", "Jittery", "Nervous", "Common", "Burned",
	"Dead-eyed", "Tainted", "Gamma", "Omicron", "Sweaty" }
local NOUN = { "Worker", "Laborer", "Comrade", "Workman", "Drone", "Prole", "Rotter", "Proletariat", "Operator",
	"Dweller", "Citizen", "Wager", "Producer", "Everyman", "Plebeian", "Grinder" }

Fates.Define( "prole", {
	Name = "Prole",
	Description = "A standard worker. The body and blood of our town.",
	Color = Color( 180, 140, 90 ),
	Cost = 1,
	DeathCooldown = 15,
	Citizen = true,
	CarryBonus = 5, -- workers haul; slaves inherit it
	-- Each entry is an item id, or a list to pick one from at random.
	Kit = { "permit_tool", { "scrap", "scrap_pipe", "scrap_gear" } },
	AccuracyMulti = 1.25, -- bullet spread x1.25
	RecoilMulti = 1.3,    -- view kick x1.3
	Names = function() return ADJ[ math.random( #ADJ ) ] .. " " .. NOUN[ math.random( #NOUN ) ] end,
	Appearance = function()
		return { model = string.format( "models/player/group01/male_0%d.mdl", math.random( 9 ) ), race = "gangral" }
	end,
} )
