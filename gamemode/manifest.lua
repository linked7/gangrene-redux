-- Load order for the whole gamemode. Every file under core/ and systems/ must be listed here.
-- core/ loads first, then systems/, each in the order written. The prefix picks the realm:
--   sv_  server only
--   sh_  both
--   cl_  client only (sent to clients by the server)
return {
	core = {
		"sh_log.lua",
		"sh_net.lua",
		"sh_sched.lua",
		"sv_test.lua",
		"sv_db.lua",
		"sh_state.lua",
		"sh_fields.lua",
	},
	systems = {
		"sv_hello.lua",
		"cl_hello.lua",
	},
}
