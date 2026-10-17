-- Player fields that belong to no single system. Systems declare their own fields in their files.
-- Bones are per-round money: kept across fate changes, never written to the DB (step 9).
State.Field( "Bones", "UInt", 24, State.OWNER, 0, { keep = true } )
State.Field( "StemCells", "UInt", 10, State.OWNER, 0, { persist = "stem_cells" } )
State.Field( "Rank", "UInt", 4, State.PUBLIC, 0, { persist = "rank" } )

-- Game ranks (step 13). New accounts are Foolish and may only play fates marked ForNewPlayers.
RANK_FOOLISH, RANK_FRIEND, RANK_KAPITAN, RANK_KAISER = 0, 1, 2, 3
