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
