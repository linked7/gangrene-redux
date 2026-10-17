-- rp_slumtown's world entities (systems/sv_layout.lua), the core map. Server only;
-- data/gangrene/layouts/rp_slumtown.json (written by gr_layout_save) wins over this.
--
-- Converted from the original Liver Failure map file
-- liverfailurewar/gamemode/liverfailure-modules/maps/list/rp_slumtown.lua (plan step 4, map layouts).
-- Positions and angles are copied unchanged; entries commented out there stay out.
--   GM.Purposes      purpose_in_life for the kept fates -> fate_station:
--                    kommandant -> kaiser, sanitator -> sanitar, korpsman -> korpsman, proletariat -> prole
--   GM.OtherEnts     machine_lunch -> ration_press (two rations, two clean water)
--                    faucet -> water_pump candidates; two are enabled (step 8: one or two per map)
--   Everything else in the old file (other purposes, loot, gangs, war, other machines) is ignored.
-- The old file has no stockpile, slave purpose or sanitation station: staff place those with
-- gr_layout_add, then gr_layout_save (the server logs what is missing at round start).
-- The old positions are the old models' origins, so every entry is `drop`ped to the floor under it
-- on its first spawn.
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

	-- The lunch hall's machines
	{ class = "ration_press", pos = Vector( -2599, 608, 172 ), ang = Angle( 0, 0, 1 ), kv = { good = "ration" }, drop = true },
	{ class = "ration_press", pos = Vector( -2599, 532, 172 ), ang = Angle( 0, 0, 0 ), kv = { good = "ration" }, drop = true },
	{ class = "ration_press", pos = Vector( -2168, 613, 172 ), ang = Angle( 0, 180, 0 ), kv = { good = "clean_water" }, drop = true },
	{ class = "ration_press", pos = Vector( -2411, 330, 172 ), ang = Angle( 0, 90, 0 ), kv = { good = "clean_water" }, drop = true },

	-- Faucets: the town-centre one and the arms break room one pump, far apart; the others are spares.
	{ class = "water_pump", pos = Vector( -603, 532, 174 ), ang = Angle( 1, 90, 1 ), kv = {}, drop = true, candidate = true },
	{ class = "water_pump", pos = Vector( -204, 466, 39 ), ang = Angle( 3, 1, 0 ), kv = {}, drop = true },
	{ class = "water_pump", pos = Vector( 140, 149, -137 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true, candidate = true },
	{ class = "water_pump", pos = Vector( -842, 1485, 166 ), ang = Angle( 1, 91, 0 ), kv = {}, drop = true },
}
