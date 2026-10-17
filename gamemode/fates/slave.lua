-- Slave: probation for new players (step 11.5). It plays exactly like a Prole; it only looks
-- different and decides who may take it. Every Foolish-rank player takes it, and only them
-- (ForNewPlayers, checked by Fates.CanTake). Cost 0, unlimited slots, and the Prole's 15 s death
-- cooldown come from the base. No gameplay code checks for slaves: anything that applies to a
-- slave applies to a prole. The way out is Rank.Free (systems/sh_rank.lua).
local NOUN = { "Drone", "Slave", "Servant", "Serf", "Laborer", "Captive", "Vassal", "Peon" }
local MODELS = { 2, 4, 6, 8 }
-- Shuffling (the original's slave Footstep): quiet at a walk, loud at a run.
local SHUFFLE = { "npc/zombie/foot1.wav", "npc/zombie/foot2.wav", "npc/zombie/foot3.wav" }

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
	ChatSounds = { "npc/headcrab_poison/ph_talk1.wav", "npc/headcrab_poison/ph_talk2.wav", "npc/headcrab_poison/ph_talk3.wav" }, -- not the prole's
	Cost = 0,
	ForNewPlayers = true,
	NoItemWeapons = true, -- carries weapon items but never gets the weapon (the original's slave)
	Footstep = function( ply ) ply:EmitSound( SHUFFLE[ math.random( #SHUFFLE ) ], ply:GetVelocity():Length2D() < 150 and 35 or 75 ) end,
	PainSounds = {}, -- not the prole's: the plain grunts
	DeathSounds = { "npc/zombie_poison/pz_warn1.wav", "npc/zombie_poison/pz_warn2.wav" },
	IntroTexts = {
		{ Color( 200, 200, 0 ), "You are new slave of Gangrene. Survive the day, or earn a free citizen's word, to be freed.\nBe cautious to not give a bad first impression.\nThis world offers great freedom to its occupants, but you must first earn it as a slave." },
		{ Color( 100, 100, 100 ), "Your barcode reads %name." },
	},
	Marker = "Newcomer", -- drawn over their head for everyone (cl_round.lua); the Fate field is public
	Names = function( ply ) return NOUN[ math.random( #NOUN ) ] .. " #" .. barcode( ply ) end,
	Appearance = function()
		return { model = string.format( "models/player/group02/male_0%d.mdl", MODELS[ math.random( #MODELS ) ] ), race = "gangral" }
	end,
} )
