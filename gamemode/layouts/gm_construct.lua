-- gm_construct's world entities (systems/sv_layout.lua). Server only; data/gangrene/layouts/gm_construct.json
-- (written by gr_layout_save) wins over this. The spawn room's players face west (yaw 180) into the
-- yard: the purposes stand at its mouth, the stockpile, the lunch machine and its boiler, two water
-- barrels, four capsule spawn points, the pumps and the sanitation station in the yard beyond, each
-- facing back towards the spawn. Heights are the traced floor plus each model's base; the lunch
-- machine's entries are `drop`ped to the floor on their first spawn.
return {
	{ class = "fate_station", pos = Vector( 450, -390, -100 ), ang = Angle( 0, 43, 0 ), kv = { fate = "prole" }, drop = true },
	{ class = "fate_station", pos = Vector( 450, -215, -100 ), ang = Angle( 0, 25, 0 ), kv = { fate = "slave" }, drop = true },
	{ class = "fate_station", pos = Vector( 450, -40, -100 ), ang = Angle( 0, 0, 0 ), kv = { fate = "korpsman" }, drop = true },
	{ class = "fate_station", pos = Vector( 450, 135, -100 ), ang = Angle( 0, 335, 0 ), kv = { fate = "sanitar" }, drop = true },
	{ class = "fate_station", pos = Vector( 450, 310, -100 ), ang = Angle( 0, 317, 0 ), kv = { fate = "kaiser" }, drop = true },
	{ class = "state_stockpile", pos = Vector( 100, -40, -104.1 ), ang = Angle( 0, 0, 0 ), kv = {} },
	{ class = "lunch_machine", pos = Vector( 100, -380, -100 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true },
	{ class = "line_boiler", pos = Vector( 100, -250, -100 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true },
	{ class = "water_barrel", pos = Vector( -30, -400, -100 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true },
	{ class = "water_barrel", pos = Vector( -30, -340, -100 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true },
	{ class = "capsule_spawn", pos = Vector( -350, -150, -100 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true },
	{ class = "capsule_spawn", pos = Vector( -350, 100, -100 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true },
	{ class = "capsule_spawn", pos = Vector( -50, 300, -100 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true },
	{ class = "capsule_spawn", pos = Vector( 250, 250, -100 ), ang = Angle( 0, 0, 0 ), kv = {}, drop = true },
	{ class = "water_pump", pos = Vector( -200, -300, -147.7 ), ang = Angle( 0, 14, 0 ), kv = {} },
	{ class = "water_pump", pos = Vector( -200, 220, -147.7 ), ang = Angle( 0, 346, 0 ), kv = {} },
	{ class = "sanitation_station", pos = Vector( -150, -40, -112.2 ), ang = Angle( 0, 0, 0 ), kv = {} },
}
