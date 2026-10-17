-- Includes core/, races/, fates/ then systems/ in the order given by manifest.lua, routing each file by prefix.
local root = GM.FolderName .. "/gamemode/"

if SERVER then AddCSLuaFile( "manifest.lua" ) end
local manifest = include( "manifest.lua" )

local function loadFile( dir, name )
	local path = root .. dir .. "/" .. name
	-- Race and fate definitions are plain data used by both realms.
	local prefix = ( dir == "races" or dir == "fates" ) and "sh_" or string.sub( name, 1, 3 )

	if prefix == "sv_" then
		if SERVER then include( path ) end
	elseif prefix == "sh_" then
		if SERVER then AddCSLuaFile( path ) end
		include( path )
	elseif prefix == "cl_" then
		if SERVER then AddCSLuaFile( path ) else include( path ) end
	else
		ErrorNoHalt( "[gr] loader: no realm prefix on " .. path .. "\n" )
	end
end

for _, dir in ipairs( { "core", "races", "fates", "systems" } ) do
	local listed = {}
	for _, name in ipairs( manifest[ dir ] ) do
		listed[ name ] = true
		loadFile( dir, name )
	end

	-- A file on disk but missing from the manifest is almost always a mistake.
	if SERVER then
		for _, name in ipairs( file.Find( root .. dir .. "/*.lua", "LUA" ) ) do
			if not listed[ name ] then
				ErrorNoHalt( "[gr] loader: " .. dir .. "/" .. name .. " is not in manifest.lua\n" )
			end
		end
	end
end
