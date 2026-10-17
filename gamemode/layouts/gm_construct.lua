-- gm_construct's world entities (systems/sv_layout.lua). Server only; data/gangrene/layouts/gm_construct.json
-- (written by gr_layout_save) wins over this. The spawn room's players face west (yaw 180) into the
-- yard: the purposes stand at its mouth, the stockpile, presses, pumps and sanitation station in the
-- yard beyond, each facing back towards the spawn. Heights are the traced floor plus each model's base.
return {
	{ class = "fate_station", pos = Vector( 450, -390, -114.1 ), ang = Angle( 0, 43, 0 ), kv = { fate = "prole" } },
	{ class = "fate_station", pos = Vector( 450, -215, -114.1 ), ang = Angle( 0, 25, 0 ), kv = { fate = "slave" } },
	{ class = "fate_station", pos = Vector( 450, -40, -114.6 ), ang = Angle( 0, 0, 0 ), kv = { fate = "korpsman" } },
	{ class = "fate_station", pos = Vector( 450, 135, -114.7 ), ang = Angle( 0, 335, 0 ), kv = { fate = "sanitar" } },
	{ class = "fate_station", pos = Vector( 450, 310, -114.2 ), ang = Angle( 0, 317, 0 ), kv = { fate = "kaiser" } },
	{ class = "state_stockpile", pos = Vector( 100, -40, -104.1 ), ang = Angle( 0, 0, 0 ), kv = {} },
	{ class = "ration_press", pos = Vector( 100, -400, -120.7 ), ang = Angle( 0, 26, 0 ), kv = { good = "ration" } },
	{ class = "ration_press", pos = Vector( 100, 320, -120.7 ), ang = Angle( 0, 334, 0 ), kv = { good = "clean_water" } },
	{ class = "water_pump", pos = Vector( -200, -300, -147.7 ), ang = Angle( 0, 14, 0 ), kv = {} },
	{ class = "water_pump", pos = Vector( -200, 220, -147.7 ), ang = Angle( 0, 346, 0 ), kv = {} },
	{ class = "sanitation_station", pos = Vector( -150, -40, -112.2 ), ang = Angle( 0, 0, 0 ), kv = {} },
}
