-- Tuning values that several systems read. One place, so a balance pass touches one file.
Config = Config or {}

-- Movement: slower than GMod's defaults. Fates scale these with SpeedMulti; nothing else sets speed.
Config.WalkSpeed = 130
Config.RunSpeed = 200

-- Rounds and meta-progression (step 13). Times in seconds.
Config.RoundLength = 60 * 60          -- Round.End fires when this runs out
Config.RoundEndDelay = 15             -- the end screen shows this long before the level changes
Config.SlaveGating = false            -- Foolish players may only be Slaves (step 13); off for now, user 2026-10-17
Config.FateCosts = false              -- fates cost stem cells to pick; off for now, user 2026-10-17
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
	-- Music (cl_music.lua): { path, seconds, kind, name }, the original's GM.Music idle and alert
	-- tracks. Idle plays while alive, alert for ghosts. Pack-only: a track that isn't installed is
	-- skipped, and with none installed there is no music.
	Music = {
		{ "placenta/music/liverdamage.ogg", 173, "idle", "Liver Damage" },
		{ "placenta/music/ademonicalteration.ogg", 332, "idle", "A Demonic Alteration" },
		{ "placenta/music/fallen.ogg", 369, "idle", "Fallen" },
		{ "placenta/music/somenamelessthing.ogg", 151, "idle", "Some Nameless Thing" },
		{ "placenta/music/stainedglass.ogg", 247, "idle", "Stained Glass Under Dim Arches" },
		{ "placenta/music/ashadowedportal.ogg", 293, "idle", "A Shadowed Portal" },
		{ "placenta/music/seethingchaos.ogg", 282, "idle", "An Abyss of Seething Chaos and Cerulean Splendor" },
		{ "placenta/music/oilyriver.ogg", 304, "idle", "An Oily River That Flows Under Endless Onyx Bridges To A Black Putrid Sea" },
		{ "placenta/music/wintersolsticeprocession.ogg", 383, "idle", "Winter Solstice Procession" },
		{ "placenta/music/damnation.ogg", 335, "idle", "Damnation" },
		{ "placenta/music/falling.ogg", 212, "idle", "Falling" },
		{ "placenta/music/reaction.ogg", 315, "idle", "The Reaction" },
		{ "placenta/music/milestomidnight.ogg", 295, "idle", "Miles To Midnight" },
		{ "placenta/music/quietdays.ogg", 404, "idle", "Quiet Days on Earth" },
		{ "placenta/music/carnophage.ogg", 262, "idle", "The Carnophage" },
		{ "placenta/music/eyes.ogg", 424, "idle", "The Eyes Are Part Of The Brain" },
		{ "placenta/music/safe.ogg", 111, "idle", "Desperately Safe" },
		{ "placenta/music/burnedbodies.ogg", 80, "idle", "Burned Bodies" },
		{ "placenta/music/notsafe.ogg", 79, "idle", "Not Safe" },
		{ "placenta/music/rudiments.ogg", 47, "idle", "Some Rudiments of Propriety" },
		{ "placenta/music/todayisworst.ogg", 59, "idle", "Today Is Worst" },
		{ "placenta/music/yesterdaywasbetter.ogg", 119, "idle", "Yesterday Was Better" },
		{ "placenta/music/endlesshallway.ogg", 76, "idle", "Endless Hallway" },
		{ "placenta/music/rainyday.ogg", 47, "idle", "Rainy Day" },
		{ "placenta/music/moltenmist.ogg", 509, "idle", "Molten Mist" },
		{ "placenta/music/hydrabreath.ogg", 443, "idle", "Hydra Breath" },
		{ "placenta/music/ironandsteel.ogg", 580, "idle", "Iron and Steel" },
		{ "placenta/music/meltingdiamonds.ogg", 541, "idle", "Melting Diamonds" },
		{ "placenta/music/blastfurnace.ogg", 751, "idle", "Blast Furnace" },
		{ "placenta/music/truesuffering.ogg", 239, "alert", "True Suffering Is Not Known" },
	},
}

-- Chat (step 12, parity 05 §8). The lists are the original's (config/sh_config.lua), copied as they
-- were for the user to review: they mix slurs, memes and out-of-setting words.
--   ChatBadWords      thoughtcrime if found anywhere in a line ("stop acting so *autistic*")
--   ChatBadSentences  thoughtcrime if it is the whole line; whitespace is ignored ("among us" == "amongus")
--   ChatCircumventions  applied before the checks above, so "b4sed" is "based"
-- Thoughtcrime: the line is not sent, the speaker gets a jumpscare and the word echoed in red,
-- wanted for ChatThoughtcrimeWanted seconds, and staff see it. Staff are exempt.
Config.ChatThoughtcrimeWanted = 60
Config.ChatBadWords = { "nigger", "tranny", "nigga", "kike", "autism", "autistic", "autist", "tranny", "trannies", "faggot", "fag", "fgt", "libtard", "gmyza", "poggers", "pogchamp", "prole gaming", "omegalol", "kekw", "trihard7", "ur mom", "ur mum", "bri-ish", "bri'ish", "poop", "nword", "rdm", "nlr", "failrp", "chad", "hoes mad", "yeet", "corpsed", "kek", "chungus", "pog", "fortnite", "skinwalk", "skinshift", "skin walk", "skin shift", "unbindall", "white walking", "weeb", "weeaboo", "amogus", "amog us", "pretty cringe", "that's cringe", "redpilled", "tradcath", "zoomer", "boomer", "doomer", "groyper", "bluepill", "redpill", "tradwife", "blackpill", "big chungus", "spongebob", "impostor among us", "imposter among us", "ligma", "trolled", "deez", "swag", "font", "bussin", "sussy", "bussy", "meme", "koom", "niglet", "stem cell meat", "make me butcher", "nlgger", "nlgga", "nlg", "bruh", "allah", "akbar", "alahu", "ackbar", "lifeweb", "cuck", "coom", "tryhard", "morbius", "morbin", "/advert", "skibidi", "rizz", "admin", "rizz", "gyatt", "fortnite", "begotten", "ANIV", "blaj", "<color", "д", "я", "ф", "и", "л", "ю" }
Config.ChatBadSentences = { "based", "among us", "furry", "cringe", "gaming", "prole gaming", "cope", "seethe", "gaming", "based.", "xd", "sus" }
Config.ChatCircumventions = {
	[ "$" ] = "s", [ "@" ] = "a", [ "4" ] = "a", [ "1" ] = "i", [ "0" ] = "o", [ "5" ] = "s",
	[ "8" ] = "b", [ "7" ] = "l", [ "3" ] = "e", [ "ß" ] = "b", [ "|" ] = "l", [ "6" ] = "g",
}

-- AutoGrammar: chat-speak corrected before spoken lines are sent (say, yell, whisper, radio).
Config.ChatStupidMistakes = {
	[ "liver failure forever" ] = "Gangrene Eternal",
	[ "liver failure" ] = "Gangrene",
	[ "kommandant" ] = "Kaiser",
	[ "i" ] = "I",
	[ "u" ] = "you",
	[ "r" ] = "are",
	[ "dont" ] = "don't",
	[ "cant" ] = "can't",
	[ "wont" ] = "won't",
	[ "doesnt" ] = "doesn't",
	[ "didnt" ] = "didn't",
	[ "youve" ] = "you've",
	[ "i'll" ] = "I'll",
	[ "itll" ] = "it'll",
	[ "wouldnt" ] = "wouldn't",
	[ "shouldnt" ] = "shouldn't",
	[ "couldnt" ] = "couldn't",
	[ "whos" ] = "who's",
	[ "weve" ] = "we've",
	[ "arent" ] = "aren't",
	[ "ive" ] = "I've",
	[ "i've" ] = "I've",
	[ "hes" ] = "he's",
	[ "shes" ] = "she's",
	[ "her's" ] = "hers",
	[ "whatre" ] = "what're",
	[ "wheres" ] = "where's",
	[ "youre" ] = "you're",
	[ "theres" ] = "there's",
	[ "theyre" ] = "they're",
	[ "theyve" ] = "they've",
	[ "im" ] = "I'm",
	[ "i'm" ] = "I'm",
	[ "youll" ] = "you'll",
	[ "ol" ] = "ol'",
	[ "k" ] = "okay",
	[ "ok" ] = "okay",
	[ "ye" ] = "yeah",
	[ "yea" ] = "yeah",
	[ "idk" ] = "I don't know",
	[ "wtf" ] = "what the fuck",
	[ "ngl" ] = "not gonna lie",
	[ "rn" ] = "right now",
	[ "gtg" ] = "gotta go",
	[ "brb" ] = "be right back",
	[ "cmon" ] = "c'mon",
	[ "lol" ] = "heh",
	[ "lel" ] = "*gag*",
	[ "kek" ] = "hrk",
	[ "lmao" ] = "haha",
	[ "rofl" ] = "pfftaha",
	[ "roflmao" ] = "PFFFTHAH",
	[ "nvm" ] = "never mind",
	[ "aint" ] = "ain't",
	[ "killin" ] = "killin'",
	[ "yknow" ] = "y'know",
	[ "n" ] = "n'",
	[ "fuckin" ] = "fuckin'",
	[ "eatin" ] = "eatin'",
	[ "drinkin" ] = "drinkin'",
	[ "huntin" ] = "huntin'",
	[ "lookin" ] = "lookin'",
	[ "searchin" ] = "searchin'",
	[ "shittin" ] = "shittin'",
	[ "jokin" ] = "jokin'",
	[ "gettin" ] = "gettin'",
	[ "lettin" ] = "lettin'",
	[ "fightin" ] = "fightin'",
	[ "motherfuckin" ] = "motherfuckin'",
	[ "ballin" ] = "ballin'",
	[ "rockin" ] = "rockin'",
	[ "bangin" ] = "bangin'",
	[ "rollin" ] = "rollin'",
	[ "movin" ] = "movin'",
	[ "somethin" ] = "somethin'",
	[ "doin" ] = "doin'",
	[ "th" ] = "th'",
	[ "tha" ] = "tha'",
	[ "tho" ] = "though",
	[ "frick" ] = "fuck",
	[ "pls" ] = "please",
	[ "plz" ] = "please",
	[ "pwned" ] = "ruined",
	[ "pwn" ] = "ruin",
	[ "rekt" ] = "ruined",
	[ "cuz" ] = "because",
	[ "dw" ] = "don't worry",
	[ "ty" ] = "thank you",
	[ "np" ] = "no problem",
	[ "omw" ] = "on my way",
	[ "thx" ] = "thanks",
	[ "gg" ] = "gluh",
	[ "money" ] = "bone",
	[ "would of" ] = "would've",
	[ "should of" ] = "should've",
	[ "could of" ] = "could've",
	[ "alot" ] = "a lot",
	[ "mb" ] = "my bad",
	[ "turkey" ] = "yurkey",
	[ "holy shit" ] = "holy heart failure",
	[ "jesus christ" ] = "Sotla eternal",
	[ "jesus fucking christ" ] = "Sotla's fucking eye",
	[ "jesus" ] = "Sotla",
	[ "mother of god" ] = "mother of Sotla",
	[ "brother in christ" ] = "brother in Sotla",
	[ "mfer" ] = "friend of mine",
	[ "arrythmia" ] = "ROTTINGHAM",
	[ "kidneystan" ] = "Prohlada Union",
	[ "liverish" ] = "Gangrel",
	[ "arrythmian" ] = "rottish",
	[ " 's" ] = "'s",
}

-- OOC: seconds between one player's OOC lines (staff are exempt). ChatOOCOff or more turns OOC
-- off for everyone but staff, as the original's 666 did. Staff change it live with gr_oocdelay.
Config.OOCDelay = 666 -- off by default (plan step 12); staff turn it on with gr_oocdelay
Config.ChatOOCOff = 666

-- Talking gestures when the weapon is holstered: 1 in 3 lines, then a 5-15 s cooldown.
-- A fate may set its own ChatGestures list.
Config.ChatGestures = { "a_gesture18", "a_gesture16" }
