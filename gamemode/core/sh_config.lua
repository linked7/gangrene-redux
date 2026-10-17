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
