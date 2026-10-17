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

-- Chat (step 12, parity 05 §8). The lists are the original's (config/sh_config.lua), copied as they
-- were for the user to review: they mix slurs, memes and out-of-setting words.
--   ChatBadWords      thoughtcrime if found anywhere in a line ("stop acting so *autistic*")
--   ChatBadSentences  thoughtcrime if it is the whole line; whitespace is ignored ("among us" == "amongus")
--   ChatKillSentences said while downed, the head bursts. Case-sensitive; whitespace is ignored
--   ChatCircumventions  applied before the checks above, so "b4sed" is "based"
-- Thoughtcrime: the line is not sent, the speaker gets a jumpscare and the word echoed in red,
-- wanted for ChatThoughtcrimeWanted seconds, and staff see it. Staff are exempt.
Config.ChatThoughtcrimeWanted = 60
Config.ChatBadWords = { "nigger", "tranny", "nigga", "kike", "autism", "autistic", "autist", "tranny", "trannies", "faggot", "fag", "fgt", "libtard", "gmyza", "poggers", "pogchamp", "prole gaming", "omegalol", "kekw", "trihard7", "ur mom", "ur mum", "bri-ish", "bri'ish", "poop", "nword", "rdm", "nlr", "failrp", "chad", "hoes mad", "yeet", "corpsed", "kek", "chungus", "pog", "fortnite", "skinwalk", "skinshift", "skin walk", "skin shift", "unbindall", "white walking", "weeb", "weeaboo", "amogus", "amog us", "pretty cringe", "that's cringe", "redpilled", "tradcath", "zoomer", "boomer", "doomer", "groyper", "bluepill", "redpill", "tradwife", "blackpill", "big chungus", "spongebob", "impostor among us", "imposter among us", "ligma", "trolled", "deez", "swag", "font", "bussin", "sussy", "bussy", "meme", "koom", "niglet", "stem cell meat", "make me butcher", "nlgger", "nlgga", "nlg", "bruh", "allah", "akbar", "alahu", "ackbar", "lifeweb", "cuck", "coom", "tryhard", "morbius", "morbin", "/advert", "skibidi", "rizz", "admin", "rizz", "gyatt", "fortnite", "begotten", "ANIV", "blaj", "<color", "д", "я", "ф", "и", "л", "ю" }
Config.ChatBadSentences = { "based", "among us", "furry", "cringe", "gaming", "prole gaming", "cope", "seethe", "gaming", "based.", "xd", "sus" }
Config.ChatKillSentences = { "MOTHER OF DEATH, I CALL ON THEE", "I GIVE MY SOUL ETERNALLY", "MOTHER OF DEATH I CALL ON THEE" }
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
Config.OOCDelay = 30
Config.ChatOOCOff = 666

-- Talking gestures when the weapon is holstered: 1 in 3 lines, then a 5-15 s cooldown.
-- A fate may set its own ChatGestures list.
Config.ChatGestures = { "a_gesture18", "a_gesture16" }
