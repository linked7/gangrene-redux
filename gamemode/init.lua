AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

-- The original's content pack (the Smash font, UI sounds and materials, scares): clients download it.
resource.AddWorkshop( Config.UI.ContentWorkshop )
