-- rp_slumtown's world entities (systems/sv_layout.lua), the core map. Server only;
-- data/gangrene/layouts/rp_slumtown.json (written by gr_layout_save) wins over this.
--
-- Converted from the original Liver Failure map file
-- liverfailurewar/gamemode/liverfailure-modules/maps/list/rp_slumtown.lua (plan step 4, map layouts).
-- Positions and angles are copied unchanged; entries commented out there stay out.
--   GM.Purposes      purpose_in_life for the kept fates -> fate_station:
--                    kommandant -> kaiser, sanitator -> sanitar, korpsman -> korpsman, proletariat -> prole
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

	{ class = "fate_station", pos = Vector( -773, -417, 129 ), ang = Angle( 0, -45, 0 ), kv = { fate = "sanitar" }, drop = true },
	{ class = "fate_station", pos = Vector( -773, -446, 1 ), ang = Angle( 0, -44, 0 ), kv = { fate = "sanitar" }, drop = true }, -- bunker
	{ class = "fate_station", pos = Vector( 1068, 117, 273 ), ang = Angle( 0, -177, 0 ), kv = { fate = "sanitar" }, drop = true },
	{ class = "fate_station", pos = Vector( -766, -512, 129 ), ang = Angle( 1, 46, 0 ), kv = { fate = "sanitar" }, drop = true },
	{ class = "fate_station", pos = Vector( 940, 120, 273 ), ang = Angle( 0, -178, 1 ), kv = { fate = "sanitar" }, drop = true }, -- gate area

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
	{ class = "sanitation_station", pos = Vector( -733, -377, 158 ), ang = Angle( 0, 225, 0 ), kv = {}, drop = true },

	-- The lunch hall: the machine at the first machine_lunch spot, the boiler at the one beside it.
	{ class = "lunch_machine", pos = Vector( -2599, 608, 172 ), ang = Angle( 0, 0, 1 ), kv = {}, drop = true },
	{ class = "line_boiler", pos = Vector( -2599, 532, 172 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true },
	-- Three water barrels in a row across the hall, clear of the machine's front (not in the old file).
	{ class = "water_barrel", pos = Vector( -2439, 530, 166 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true },
	{ class = "water_barrel", pos = Vector( -2439, 570, 166 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true },
	{ class = "water_barrel", pos = Vector( -2439, 610, 166 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true },

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
}
