-- Player fields that belong to no single system. Systems declare their own fields in their files.
State.Field( "Bones", "UInt", 24, State.OWNER, 0, { persist = "bones" } )
State.Field( "StemCells", "UInt", 10, State.OWNER, 0, { persist = "stem_cells" } )
State.Field( "Rank", "UInt", 4, State.PUBLIC, 0, { persist = "rank" } )
