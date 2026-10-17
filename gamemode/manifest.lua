-- Load order for the whole gamemode. Every file under core/ and systems/ must be listed here.
-- core/ loads first, then races/ and fates/ (shared data, no prefix), then systems/, each in
-- the order written. In core/ and systems/ the prefix picks the realm:
--   sv_  server only
--   sh_  both
--   cl_  client only (sent to clients by the server)
return {
	core = {
		"sh_log.lua",
		"sh_config.lua",
		"sh_net.lua",
		"sh_sched.lua",
		"sv_test.lua",
		"sv_db.lua",
		"sh_state.lua",
		"sh_fields.lua",
		"sh_notify.lua",
		"sh_races.lua",
		"sh_fates.lua",
	},
	-- The core is Gangral-only; Outsider, Rottish, Prohladian and skinless come with later features.
	races = {
		"gangral.lua",
	},
	-- Order matters: a fate with Base must come after its base. Ghost must be first (FATE_GHOST = 1).
	fates = {
		"ghost.lua",
		"prole.lua",
		"slave.lua",
		"korpsman.lua",
		"sanitar.lua",
		"kaiser.lua",
	},
	systems = {
		"sv_hello.lua",
		"cl_hello.lua",
		"sv_lifecycle.lua",
		"sh_ghost.lua",
		"sh_needs.lua",
		"cl_atmosphere.lua",
		"sh_items.lua",
		"sh_inventory.lua",
		"cl_inventory.lua",
	},
}
