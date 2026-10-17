-- Sanitar: the police (step 11.3). Police = true is what Crime and Police (sh_police.lua) look for:
-- inspect, arrest, bounties in Teeth and the sanitation station. Kit is the baton and the scope,
-- as items, so they lie on the body when the sanitar goes down.
local NOUNS = { "Cleaner", "Janitor", "Officer", "Sanitator", "Purifier", "Filter", "Operator", "Enforcer",
	"Disinfectant", "Antiseptic", "Cleanser" }
-- Boots on a run only (the original's sanitator Footstep).
local BOOTS = { "npc/footsteps/hardboot_generic1.wav", "npc/footsteps/hardboot_generic2.wav", "npc/footsteps/hardboot_generic3.wav",
	"npc/footsteps/hardboot_generic4.wav", "npc/footsteps/hardboot_generic5.wav", "npc/footsteps/hardboot_generic6.wav",
	"npc/footsteps/hardboot_generic8.wav" }

Fates.Define( "sanitar", {
	Name = "Sanitar",
	Description = "The keeper of all things moral, safe, and clean... hopefully.",
	Color = Color( 0, 200, 0 ),
	ChatSounds = function( _, emit ) emit( "placenta/speech/chatter" .. math.random( 1, 15 ) .. ".ogg", 100 ) end,
	Cost = 2,
	DeathCooldown = 120,
	Slots = function( pop ) return math.Clamp( 2 + math.floor( pop / 10 ), 2, 6 ) end,
	PainSounds = { "placenta/pain/sanitar1.wav", "placenta/pain/sanitar2.wav", "placenta/pain/sanitar3.wav", "placenta/pain/sanitar4.wav" },
	DeathSounds = { "placenta/death/sanitar1.wav", "placenta/death/sanitar2.wav" },
	IntroTexts = {
		{ Color( 200, 200, 0 ), "You are the protector of the innocent and the cleaner of the dead. You also have a radio that lets you talk to the other sanitars and the Witch Kaiser (/r).\nYou innately hold more power than the rest of Gangrene's residents... through force." },
		{ Color( 200, 0, 0 ), "Abusing the authority and force of being a sanitar is much more likely to get you punished than as other lots in life. Kill yourself if you can't handle this responsibility." },
		{ Color( 100, 100, 100 ), "Your codename is %name.\nYou may earn teeth via judicial murder of a criminal." },
	},
	Police = true,
	Footstep = function( ply )
		if ply:GetVelocity():Length2D() >= 150 then ply:EmitSound( BOOTS[ math.random( #BOOTS ) ], 75, math.random( 85, 95 ) ) end
	end,
	StockpileAccess = true, -- guarding the stockpile is part of the job
	Wage = 40,              -- default wage.sanitar in the Economy table
	Faction = "state",
	Authority = 1,
	Radio = { "state" },
	Names = function() return NOUNS[ math.random( #NOUNS ) ] .. " #" .. math.random( 11, 99 ) end,
	Appearance = { model = "models/player/police.mdl", race = "gangral" },
	Kit = { "baton", "scope" }, -- sh_kit.lua; a revived sanitar gets the body's own kit back instead
} )
