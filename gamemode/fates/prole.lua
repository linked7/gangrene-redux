-- Placeholder: step 11 adds the work loop, construction and aim penalty.
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
	Names = function() return ADJ[ math.random( #ADJ ) ] .. " " .. NOUN[ math.random( #NOUN ) ] end,
	Appearance = function()
		return { model = string.format( "models/player/group01/male_0%d.mdl", math.random( 9 ) ), race = "gangral" }
	end,
} )
