GM.Name = "Gangrene Redux"
GM.Author = "linked7"
GM.Email = ""
GM.Website = "https://github.com/linked7/gangrene-redux"

DeriveGamemode( "base" )

-- The loader runs on both realms; it reads manifest.lua and includes every listed file.
if SERVER then AddCSLuaFile( "loader.lua" ) end
include( "loader.lua" )
