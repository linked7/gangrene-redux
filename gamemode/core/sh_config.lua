-- Tuning values that several systems read. One place, so a balance pass touches one file.
Config = Config or {}

-- Movement: slower than GMod's defaults. Fates scale these with SpeedMulti; nothing else sets speed.
Config.WalkSpeed = 130
Config.RunSpeed = 200

-- Rounds and meta-progression (step 13). Times in seconds.
Config.RoundLength = 60 * 60          -- Round.End fires when this runs out
Config.RoundEndDelay = 15             -- the end screen shows this long before the level changes
Config.SlaveMinRoundTime = 20 * 60    -- time as a Slave this round needed to be freed at Round.End
Config.PlaytimePerStemCell = 20 * 60  -- living (non-ghost) time that earns one stem cell
Config.KapitanStemCells = 25          -- a Friend holding this many stem cells becomes Kapitan

-- Downed (step 7). HP 0 downs a player; how far past 0 the hit went picks wounded or dying.
Config.LethalOverkill = 30            -- a hit this far past 0 HP (or any hit on a wounded body) is dying
Config.WakeTime = 45                  -- a wounded player gets up on their own after this long
Config.BleedoutTime = 120             -- a dying player becomes a ghost after this long unless revived
Config.WakeHealth = 25                -- health after getting up
Config.InjuredMaxHealth = 50          -- Injured caps max health here until a korpsman treats it
Config.FinishOffTime = 3              -- the timed action that kills a downed body

-- The client look (docs/05 §1). Every asset path and font face lives here. Defaults are the
-- original's own files from its content pack (Workshop 3067207405, sent by init.lua). Each sound
-- and material has a stock fallback the client uses when the pack is missing: a pair is
-- { pack path, stock path }, checked once with file.Exists / Material():IsError() (cl_hud.lua).
Config.UI = {
	ContentWorkshop = "3067207405",
	Face = "Smash",                    -- the original's CombineControl.* face
	FaceFallback = "Trebuchet MS",     -- used when the Smash font file is not installed
	ChatFace = "Verdana",
	RadioFace = "Lucida Console",
	Sounds = {
		cross_hover = { "placenta/ui/cross_hover.wav", "ui/buttonrollover.wav" },
		cross_unhover = { "placenta/ui/cross_unhover.wav", "ui/buttonclickrelease.wav" },
		weapon_hover = { "placenta/ui/weapon_hover.wav", "ui/buttonrollover.wav" },
		weapon_select = { "placenta/ui/weapon_select.wav", "common/wpn_moveselect.wav" },
		weapon_choose = { "placenta/ui/weapon_choose.wav", "common/wpn_hudoff.wav" },
		menu_open = { "placenta/ui/menu_open.wav", "ui/buttonclick.wav" },
		menu_close = { "placenta/ui/menu_close.wav", "ui/buttonclickrelease.wav" },
		button_release = { "placenta/ui/buttonrelease.wav", "ui/buttonclickrelease.wav" },
		notify = { "ui/buttonrollover.wav", "ui/buttonrollover.wav" },
		error = { "buttons/button10.wav", "buttons/button10.wav" },
		announce = { "buttons/bell1.wav", "buttons/bell1.wav" },
		headshot = { "player/headshot1.wav", "player/headshot1.wav" },
	},
	Materials = {
		vignette = { "placenta/ui/vignetta.png", false },  -- no stock stand-in: skipped when missing, as in the original
		gradient = { "placenta/ui/bg_gradient.png", "gui/gradient" },
		scratch = { "placenta/ui/scratch.png", "vgui/white" },
		dirty = { "placenta/ui/dirty.png", "vgui/white" },
		hand1 = { "placenta/cursor/hand1.png", false },
		hand2 = { "placenta/cursor/hand2.png", false },
		hand3 = { "placenta/cursor/hand3.png", false },
		fm1 = { "placenta/ui/fm1.png", false },            -- fate menu backdrops, one per tab
		fm2 = { "placenta/ui/fm2.png", false },
		fm3 = { "placenta/ui/fm3.png", false },
		fm4 = { "placenta/ui/fm4.jpg", false },
		rank0 = { "placenta/ooc/slave.png", "icon16/user_gray.png" },
		rank1 = { "placenta/ooc/friend.png", "icon16/user.png" },
		rank2 = { "placenta/ooc/kap.png", "icon16/user_red.png" },
		rank3 = { "placenta/ooc/kaiser.png", "icon16/star.png" },
	},
	HandFrames = { "hand1", "hand2", "hand3", "hand2" },  -- the F3 cursor, 0.2 s a frame
	-- Jumpscare: "placenta/jumpscare<n>.wav", n = 1..8 (the original's min( rand( 1, 9 ), 8 )).
	Jumpscares = 8,
	JumpscareFallback = "npc/stalker/go_alert2a.wav",
	-- Frighten: the ghost's BecomeSounds, picked from at random: the stock HL2 town sounds (always)
	-- plus whichever of the pack's sounds are installed.
	Frighten = {
		"placenta/tormented.wav", "placenta/frighten1.wav", "placenta/frighten2.wav", "placenta/frighten3.wav",
		"placenta/frighten4.wav", "placenta/comic1.ogg", "placenta/comic2.ogg", "placenta/comic3.ogg",
		"placenta/comic4.ogg", "placenta/screaminbase.wav", "placenta/screamloud.wav",
	},
	FrightenFallback = {
		"ambient/creatures/town_child_scream1.wav", "ambient/creatures/town_moan1.wav", "ambient/creatures/town_muffled_cry1.wav",
		"ambient/creatures/town_scared_breathing1.wav", "ambient/creatures/town_scared_breathing2.wav",
		"ambient/creatures/town_scared_sob1.wav", "ambient/creatures/town_scared_sob2.wav", "ambient/creatures/town_zombie_call1.wav",
	},
	-- Hallucination images: placenta/<name>.png, plus placenta/postal1..Postals.png.
	Hallucinations = {
		"eyes", "eyes2", "sisters", "garalina", "hands", "claws", "girl", "shower", "moviegoers", "mary", "watcher", "sink",
		"teeth", "mask", "hiding", "door", "comehome", "seer", "bestfriend", "shadowpeople", "soulseeker", "furry",
		"piercing", "trauma", "fear", "joy", "fallingaway", "finaltrip", "biter",
	},
	Postals = 27,
}
