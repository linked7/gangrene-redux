-- Placeholder: step 11.5 adds harmlessness, the new-player marker and the ways out.
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
	Description = "An almost-worker.",
	Color = Color( 120, 120, 100 ),
	Cost = 0,
	ForNewPlayers = true,
	Names = function( ply ) return NOUN[ math.random( #NOUN ) ] .. " #" .. barcode( ply ) end,
	Appearance = function()
		return { model = string.format( "models/player/group02/male_0%d.mdl", MODELS[ math.random( #MODELS ) ] ), race = "gangral" }
	end,
} )
