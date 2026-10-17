-- rp_slumtown's world entities (systems/sv_layout.lua), the core map. Server only;
-- data/gangrene/layouts/rp_slumtown.json (written by gr_layout_save) wins over this.
--
-- Converted from the original Liver Failure map file
-- liverfailurewar/gamemode/liverfailure-modules/maps/list/rp_slumtown.lua (plan step 4, map layouts).
-- Positions and angles are copied unchanged; entries commented out there stay out.
--   GM.Purposes      purpose_in_life for the kept fates -> fate_station:
--                    kommandant -> kaiser, sanitator dropped (sanitars are recruited), korpsman -> korpsman, proletariat -> prole
--   GM.OtherEnts     machine_lunch (four spots in one room) -> one lunch_machine at the first spot
--                    and its line_boiler at the spot beside it (the old generator's job)
--                    faucet -> water_pump candidates; two are enabled (step 8: one or two per map)
--   GM.Capsules      -> the 12 capsule_spawn points
--   Everything else in the old file (other purposes, loot, gangs, war, other machines) is ignored.
-- The old file has no stockpile, slave purpose, sanitation station or water barrels. Those are
-- placed here from free floor spots found on the real map (Layout.Ring and a hull probe, 2026-10-17);
-- staff can move them with gr_layout_add / gr_layout_save.
-- The old positions are the old models' origins, so every model entry is `drop`ped to the floor
-- under it on its first spawn; capsule spawn points stay exactly where the original spawned them.
return {
	-- Purposes
	{ class = "fate_station", pos = Vector( 1157, -427, 401 ), ang = Angle( 0, -178, 0 ), kv = { fate = "kaiser" }, drop = true },


	{ class = "fate_station", pos = Vector( -1291, -129, 1 ), ang = Angle( 0, 180, 0 ), kv = { fate = "korpsman" }, drop = true },

	{ class = "fate_station", pos = Vector( 251, 47, 137 ), ang = Angle( 0, -90, 0 ), kv = { fate = "prole" }, drop = true },
	{ class = "fate_station", pos = Vector( -71, 546, 1 ), ang = Angle( 0, 136, 0 ), kv = { fate = "prole" }, drop = true },
	{ class = "fate_station", pos = Vector( 412, 127, 1 ), ang = Angle( 0, 1, 0 ), kv = { fate = "prole" }, drop = true },
	{ class = "fate_station", pos = Vector( -138, 627, 1 ), ang = Angle( 0, 143, 0 ), kv = { fate = "prole" }, drop = true },
	{ class = "fate_station", pos = Vector( -849, 1536, 129 ), ang = Angle( 1, 172, 0 ), kv = { fate = "prole" }, drop = true }, -- arms break room

	-- Not in the old file: the slave purpose by the town-centre proles, the stockpile by the Kaiser,
	-- the sanitation station in the sanitars' room.
	{ class = "fate_station", pos = Vector( 612, 349, 30 ), ang = Angle( 0, 228, 0 ), kv = { fate = "slave" }, drop = true },
	{ class = "state_stockpile", pos = Vector( 1249, -141, 430 ), ang = Angle( 0, 252, 0 ), kv = {}, drop = true },
	{ class = "stockpile_port", pos = Vector( 1300, -60, 430 ), ang = Angle( 0, 252, 0 ), kv = {}, drop = true },
	{ class = "train_station", pos = Vector( 1249, -20, 430 ), ang = Angle( 0, 252, 0 ), kv = {}, drop = true },
	{ class = "gr_incinerator", pos = Vector( -733, -260, 158 ), ang = Angle( 0, 225, 0 ), kv = {}, drop = true },
	{ class = "sanitation_station", pos = Vector( -733, -377, 158 ), ang = Angle( 0, 225, 0 ), kv = {}, drop = true },
	-- the corpse washer, beside it: cops bring rotted bodies here.
	{ class = "corpse_washer", pos = Vector( -700, -420, 158 ), ang = Angle( 0, 135, 0 ), kv = {}, drop = true },

	-- The lunch hall: the machine at the first machine_lunch spot, the boiler at the one beside it.
	{ class = "lunch_machine", pos = Vector( -2599, 608, 172 ), ang = Angle( 0, 0, 1 ), kv = {}, drop = true },
	{ class = "line_boiler", pos = Vector( -2599, 532, 172 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true },
	-- Four water barrels (plan step 4) in a row across the hall, clear of the machine's front (not in the old file).
	{ class = "water_barrel", pos = Vector( -2439, 530, 166 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true },
	{ class = "water_barrel", pos = Vector( -2439, 570, 166 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true },
	{ class = "konsole_immigration", pos = Vector( 1409, 52, 91 ), ang = Angle( 2, -90, 1 ), kv = {} },
	{ class = "water_barrel", pos = Vector( -2439, 610, 166 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true },
	{ class = "water_barrel", pos = Vector( -2479, 610, 166 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true },

	-- Autostitchers (the old autostitcher spawns): wall chargers, so not dropped.
	{ class = "autostitcher", pos = Vector( -1168, 411, 60 ), ang = Angle( 0, 180, 0 ), kv = {} },
	{ class = "autostitcher", pos = Vector( -908, -25, 60 ), ang = Angle( 0, 180, 0 ), kv = {} },
	{ class = "autostitcher", pos = Vector( -908, -103, 60 ), ang = Angle( 0, 180, 0 ), kv = {} },

	-- GM.Capsules: where bone capsules appear. Spawn points, not models, so they stay where they are.
	{ class = "capsule_spawn", pos = Vector( -303, -80, 435 ), ang = Angle( 0, 0, 0 ), kv = {} },
	{ class = "capsule_spawn", pos = Vector( -304, -208, 478 ), ang = Angle( 0, 0, 0 ), kv = {} },
	{ class = "capsule_spawn", pos = Vector( -302, 149, 477 ), ang = Angle( 0, 0, 0 ), kv = {} },
	{ class = "capsule_spawn", pos = Vector( -305, 467, 408 ), ang = Angle( 0, 0, 0 ), kv = {} },
	{ class = "capsule_spawn", pos = Vector( -325, 574, 481 ), ang = Angle( 0, 0, 0 ), kv = {} },
	{ class = "capsule_spawn", pos = Vector( -306, 737, 301 ), ang = Angle( 0, 0, 0 ), kv = {} },
	{ class = "capsule_spawn", pos = Vector( -306, 736, 481 ), ang = Angle( 0, 0, 0 ), kv = {} },
	{ class = "capsule_spawn", pos = Vector( -664, 567, 87 ), ang = Angle( 0, 0, 0 ), kv = {} },
	{ class = "capsule_spawn", pos = Vector( -870, 583, 91 ), ang = Angle( 0, 0, 0 ), kv = {} },
	{ class = "capsule_spawn", pos = Vector( -528, 71, -66 ), ang = Angle( 0, 0, 0 ), kv = {} },
	{ class = "capsule_spawn", pos = Vector( -507, -0, -59 ), ang = Angle( 0, 0, 0 ), kv = {} },
	{ class = "capsule_spawn", pos = Vector( 286, 75, -143 ), ang = Angle( 0, 0, 0 ), kv = {} },

	-- Faucets: the town-centre one and the arms break room one pump, far apart; the others are spares.
	{ class = "water_pump", pos = Vector( -603, 532, 174 ), ang = Angle( 1, 90, 1 ), kv = {}, drop = true, candidate = true },
	{ class = "water_pump", pos = Vector( -204, 466, 39 ), ang = Angle( 3, 1, 0 ), kv = {}, drop = true },
	{ class = "water_pump", pos = Vector( 140, 149, -137 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true, candidate = true },
	{ class = "water_pump", pos = Vector( -842, 1485, 166 ), ang = Angle( 1, 91, 0 ), kv = {}, drop = true },
	-- Trash piles (step 8): GM.Lootables, model and name kept
	{ class = "trash_pile", pos = Vector( -467, -50, -266 ), ang = Angle( 0, 90, 0 ), kv = { model = "models/props_junk/garbage128_composite001a.mdl", lootname = "Wet Garbage" }, drop = true },
	{ class = "trash_pile", pos = Vector( -260, 787, -117 ), ang = Angle( -0, 177, 1 ), kv = { model = "models/props_junk/garbage128_composite001a.mdl", lootname = "Wet Garbage" }, drop = true },
	{ class = "trash_pile", pos = Vector( -466, 964, 5 ), ang = Angle( -0, -82, -0 ), kv = { model = "models/props_junk/garbage128_composite001b.mdl", lootname = "Garbage" }, drop = true },
	{ class = "trash_pile", pos = Vector( 8121, 5085, -289 ), ang = Angle( 5, -149, 107 ), kv = { model = "models/props_lab/bigrock.mdl", lootname = "Mold Farm" }, drop = true },
	{ class = "trash_pile", pos = Vector( 8696, 6000, -384 ), ang = Angle( 0, 0, 0 ), kv = { model = "models/props_lab/bigrock.mdl", lootname = "Mold Farm" }, drop = true },
	{ class = "trash_pile", pos = Vector( 7297, 4925, -331 ), ang = Angle( 0, 0, 0 ), kv = { model = "models/props/plantbase.mdl", lootname = "Loose Soil" }, drop = true },
	{ class = "trash_pile", pos = Vector( 9823, 5160, -364 ), ang = Angle( -1, -90, 4 ), kv = { model = "models/props/plantbase.mdl", lootname = "Loose Soil" }, drop = true },
	{ class = "trash_pile", pos = Vector( 9024, 5798, -340 ), ang = Angle( 1, 7, -10 ), kv = { model = "models/props/plantbase.mdl", lootname = "Loose Soil" }, drop = true },
	{ class = "trash_pile", pos = Vector( 8290, 5381, -355 ), ang = Angle( 6, 161, 16 ), kv = { model = "models/props/plantbase.mdl", lootname = "Loose Soil" }, drop = true },
	{ class = "trash_pile", pos = Vector( 7549, 5804, -355 ), ang = Angle( 6, -141, -13 ), kv = { model = "models/props/plantbase.mdl", lootname = "Loose Soil" }, drop = true },
	{ class = "trash_pile", pos = Vector( 6879, 5760, -361 ), ang = Angle( 11, -102, -4 ), kv = { model = "models/props/plantbase.mdl", lootname = "Loose Soil" }, drop = true },
	{ class = "trash_pile", pos = Vector( 9959, 421, -365 ), ang = Angle( 12, 30, 1 ), kv = { model = "models/props/plantbase.mdl", lootname = "Loose Soil" }, drop = true },
	{ class = "trash_pile", pos = Vector( 10300, 3783, -352 ), ang = Angle( -6, 91, -5 ), kv = { model = "models/props/plantbase.mdl", lootname = "Loose Soil" }, drop = true },
	{ class = "trash_pile", pos = Vector( 9794, 2196, -359 ), ang = Angle( 6, 35, 5 ), kv = { model = "models/props/plantbase.mdl", lootname = "Loose Soil" }, drop = true },
	{ class = "trash_pile", pos = Vector( 7643, 767, -306 ), ang = Angle( -1, -21, 4 ), kv = { model = "models/props_combine/combine_debris128pile001a.mdl", lootname = "Scrap Pile" }, drop = true },
	{ class = "trash_pile", pos = Vector( 3865, -134, -345 ), ang = Angle( 4, 34, -0 ), kv = { model = "models/props_combine/combine_debris128pile001a.mdl", lootname = "Scrap Pile" }, drop = true },
	{ class = "trash_pile", pos = Vector( 7719, 2659, 341 ), ang = Angle( -0, -93, -0 ), kv = { model = "models/props_combine/combine_debris128pile001a.mdl", lootname = "Scrap Pile" }, drop = true },
	{ class = "trash_pile", pos = Vector( 6927, -1127, -301 ), ang = Angle( -89, -89, 180 ), kv = { model = "models/props_vents/vent_large_grill001.mdl", lootname = "Abandoned Vent" }, drop = true },
	{ class = "trash_pile", pos = Vector( 7959, 2618, -359 ), ang = Angle( 0, 180, 0 ), kv = { model = "models/props/de_prodigy/ammo_can_01.mdl", lootname = "Abandoned Depot" }, drop = true },
	{ class = "trash_pile", pos = Vector( 6627, 4637, -353 ), ang = Angle( 1, 132, 1 ), kv = { model = "models/tnb/items/workbench.mdl", lootname = "Abandoned Workbench" }, drop = true },
	{ class = "trash_pile", pos = Vector( 10695, 3614, -345 ), ang = Angle( -0, -89, 3 ), kv = { model = "models/tnb/items/workbench.mdl", lootname = "Abandoned Workbench" }, drop = true },
	{ class = "trash_pile", pos = Vector( 11450, 1336, -189 ), ang = Angle( 2, -89, -5 ), kv = { model = "models/props_hive/websackhalf.mdl", lootname = "Spider Nest" }, drop = true },
	{ class = "trash_pile", pos = Vector( 8862, 6021, -162 ), ang = Angle( -17, -93, 17 ), kv = { model = "models/props_hive/websackhalf.mdl", lootname = "Spider Nest" }, drop = true },
	{ class = "trash_pile", pos = Vector( 533, -358, 23 ), ang = Angle( -0, 174, -0 ), kv = { model = "models/props_c17/furniturewashingmachine001a.mdl", lootname = "Ancient Machine" }, drop = true },
	{ class = "trash_pile", pos = Vector( 116, 531, 26 ), ang = Angle( 1, -36, 1 ), kv = { model = "models/props_junk/trashdumpster01a.mdl", lootname = "Dumpster" }, drop = true },
	{ class = "trash_pile", pos = Vector( 692, 755, -53 ), ang = Angle( -0, -13, -0 ), kv = { model = "models/props_c17/oildrum001.mdl", lootname = "Junk Barrel" }, drop = true },
	{ class = "trash_pile", pos = Vector( -743, -968, -501 ), ang = Angle( -7, 49, 16 ), kv = { model = "models/props_junk/trashdumpster01a.mdl", lootname = "Abandoned Dumpster" }, drop = true },
	{ class = "trash_pile", pos = Vector( 336, 80, -56 ), ang = Angle( -89, 0, 180 ), kv = { model = "models/props_vents/vent_large_grill001.mdl", lootname = "Not a Smuggler" }, drop = true },
	{ class = "trash_pile", pos = Vector( 210, 711, -251 ), ang = Angle( -0, -105, -0 ), kv = { model = "models/props_junk/garbage128_composite001b.mdl", lootname = "Garbage" }, drop = true },
	{ class = "trash_pile", pos = Vector( 216, 294, -533 ), ang = Angle( -29, 150, -77 ), kv = { model = "models/props_lab/bigrock.mdl", lootname = "Mold Farm" }, drop = true },
	{ class = "trash_pile", pos = Vector( -612, 312, -483 ), ang = Angle( 0, 180, -0 ), kv = { model = "models/props_wasteland/controlroom_storagecloset001a.mdl", lootname = "Old Cabinet" }, drop = true },
	{ class = "trash_pile", pos = Vector( -1056, 934, -473 ), ang = Angle( -0, 95, 1 ), kv = { model = "models/props_wasteland/kitchen_stove002a.mdl", lootname = "Abandoned Implement" }, drop = true },
	{ class = "trash_pile", pos = Vector( 323, 954, -473 ), ang = Angle( 11, 92, -22 ), kv = { model = "models/props_lab/bigrock.mdl", lootname = "Flesh Colony" }, drop = true },
	{ class = "trash_pile", pos = Vector( -165, -793, -432 ), ang = Angle( 4, 47, 1 ), kv = { model = "models/props_c17/gravestone002a.mdl", lootname = "Ancient Grave" }, drop = true },
	{ class = "trash_pile", pos = Vector( 270, -659, -677 ), ang = Angle( 6, 0, 6 ), kv = { model = "models/props_c17/oildrum001.mdl", lootname = "Marked Cache" }, drop = true },
	{ class = "trash_pile", pos = Vector( -410, 674, -244 ), ang = Angle( 1, 56, 1 ), kv = { model = "models/props_c17/lampshade001a.mdl", lootname = "Polyp" }, drop = true },
	{ class = "trash_pile", pos = Vector( 6317, -1073, -908 ), ang = Angle( 6, 110, 2 ), kv = { model = "models/props_c17/lampshade001a.mdl", lootname = "Polyp" }, drop = true },
	{ class = "trash_pile", pos = Vector( -324, 2711, -481 ), ang = Angle( -2, -179, -3 ), kv = { model = "models/props_junk/trashdumpster01a.mdl", lootname = "Marked Dumpster" }, drop = true },
	{ class = "trash_pile", pos = Vector( 306, 2541, -258 ), ang = Angle( -0, -112, -0 ), kv = { model = "models/props_junk/trashdumpster01a.mdl", lootname = "Dumpster" }, drop = true },
	{ class = "trash_pile", pos = Vector( 2397, 2744, 141 ), ang = Angle( -0, 163, 1 ), kv = { model = "models/props_junk/wood_crate002a.mdl", lootname = "Leftover Supplies" }, drop = true },
	{ class = "trash_pile", pos = Vector( -857, -231, 21 ), ang = Angle( -0, 8, 1 ), kv = { model = "models/props_trainstation/trashcan_indoor001b.mdl", lootname = "Trash Can" }, drop = true },
	{ class = "trash_pile", pos = Vector( -1190, 613, 144 ), ang = Angle( -0, -179, -0 ), kv = { model = "models/props_lab/filecabinet02.mdl", lootname = "Someone's Cache" }, drop = true },
	{ class = "trash_pile", pos = Vector( -198, 547, 11 ), ang = Angle( -0, -43, 1 ), kv = { model = "models/props_junk/cardboard_box003a.mdl", lootname = "Soapbox" }, drop = true },
	{ class = "trash_pile", pos = Vector( -1484, 2315, -173 ), ang = Angle( 5, -130, -2 ), kv = { model = "models/props_debris/concrete_debris128pile001b.mdl", lootname = "Debris" }, drop = true },
	{ class = "trash_pile", pos = Vector( -2281, -73, -142 ), ang = Angle( -2, 75, -4 ), kv = { model = "models/props_debris/barricade_short01a.mdl", lootname = "Debris" }, drop = true },
	{ class = "trash_pile", pos = Vector( -1955, -372, -41 ), ang = Angle( -0, 1, 0 ), kv = { model = "models/props_wasteland/controlroom_storagecloset001b.mdl", lootname = "SCIENCE Supplies" }, drop = true },
	{ class = "trash_pile", pos = Vector( -481, -354, 16 ), ang = Angle( 1, -117, 1 ), kv = { model = "models/props_wasteland/controlroom_filecabinet001a.mdl", lootname = "Trusty's Cache" }, drop = true },
	{ class = "trash_pile", pos = Vector( -27, -513, 26 ), ang = Angle( -0, 177, -0 ), kv = { model = "models/props_junk/trashdumpster01a.mdl", lootname = "Dumpster" }, drop = true },
	{ class = "trash_pile", pos = Vector( -11, -343, 137 ), ang = Angle( 0, 171, -0 ), kv = { model = "models/props_debris/broken_pile001a.mdl", lootname = "Debris" }, drop = true },
	{ class = "trash_pile", pos = Vector( 746, -299, 166 ), ang = Angle( 5, 90, 1 ), kv = { model = "models/props_trainstation/trashcan_indoor001a.mdl", lootname = "Marked Cache" }, drop = true },
	{ class = "trash_pile", pos = Vector( 900, 538, 27 ), ang = Angle( 4, -179, 0 ), kv = { model = "models/props_junk/trashdumpster01a.mdl", lootname = "Dumpster" }, drop = true },
	{ class = "trash_pile", pos = Vector( -887, -322, 21 ), ang = Angle( -0, 0, 1 ), kv = { model = "models/props_junk/trashbin01a.mdl", lootname = "Trash Bin" }, drop = true },
	{ class = "trash_pile", pos = Vector( -1212, 497, 59 ), ang = Angle( -0, 180, 0 ), kv = { model = "models/props_wasteland/prison_pipefaucet001a.mdl", lootname = "Poison Socket" }, drop = true },
	{ class = "trash_pile", pos = Vector( 7749, 1937, -315 ), ang = Angle( 0, 165, 1 ), kv = { model = "models/props_c17/gravestone_cross001b.mdl", lootname = "Shallow Grave" }, drop = true },
	{ class = "trash_pile", pos = Vector( 7793, 2040, -358 ), ang = Angle( -1, -177, 7 ), kv = { model = "models/props_c17/gravestone004a.mdl", lootname = "Shallow Grave" }, drop = true },
	{ class = "trash_pile", pos = Vector( 7694, 1858, -330 ), ang = Angle( 3, 146, 1 ), kv = { model = "models/props_c17/gravestone002a.mdl", lootname = "Shallow Grave" }, drop = true },
}
