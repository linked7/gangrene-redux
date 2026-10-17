-- Slave: probation for new players (step 11.5). It plays exactly like a Prole; it only looks
-- different and decides who may take it. Every Foolish-rank player takes it, and only them
-- (ForNewPlayers, checked by Fates.CanTake). Cost 0, unlimited slots, and the Prole's 15 s death
-- cooldown come from the base. No gameplay code checks for slaves: anything that applies to a
-- slave applies to a prole. The way out is Rank.Free (systems/sh_rank.lua).
local NOUN = { "Drone", "Slave", "Servant", "Serf", "Laborer", "Captive", "Vassal", "Peon" }
local MODELS = { 2, 4, 6, 8 }

-- The barcode is the tail of the account id, so the same newcomer keeps the same number.
local function barcode( ply )
	if ply:IsBot() then return string.format( "%04d", ply:EntIndex() ) end
	return string.sub( ply:SteamID64(), -6 )
end

Fates.Define( "slave", {
	Base = "prole",
	Name = "Slave",
	Description = "An almost-worker. Survive the day, or earn a free citizen's word, to be freed.",
	Color = Color( 120, 120, 100 ),
	Cost = 0,
	ForNewPlayers = true,
	Marker = "Newcomer", -- drawn over their head for everyone (cl_round.lua); the Fate field is public
	Names = function( ply ) return NOUN[ math.random( #NOUN ) ] .. " #" .. barcode( ply ) end,
	Appearance = function()
		return { model = string.format( "models/player/group02/male_0%d.mdl", MODELS[ math.random( #MODELS ) ] ), race = "gangral" }
	end,
} )
