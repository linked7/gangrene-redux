-- Console logging. Log.Debug only prints while the gr_debug convar is on.
Log = Log or {}

local debugVar = CreateConVar( "gr_debug", "0", FCVAR_REPLICATED + FCVAR_ARCHIVE, "Print Gangrene Redux debug output." )

local realm = SERVER and "sv" or "cl"
local colors = {
	info = Color( 200, 200, 200 ),
	warn = Color( 255, 200, 60 ),
	error = Color( 255, 80, 80 ),
	debug = Color( 120, 180, 255 ),
}

local function write( level, tag, fmt, ... )
	local msg = select( "#", ... ) > 0 and string.format( fmt, ... ) or fmt
	MsgC( colors[ level ], "[gr:" .. realm .. "][" .. tag .. "] " .. msg .. "\n" )
end

function Log.Info( tag, fmt, ... ) write( "info", tag, fmt, ... ) end
function Log.Warn( tag, fmt, ... ) write( "warn", tag, fmt, ... ) end
function Log.Error( tag, fmt, ... ) write( "error", tag, fmt, ... ) end

function Log.Debug( tag, fmt, ... )
	if debugVar:GetBool() then write( "debug", tag, fmt, ... ) end
end

function Log.DebugOn()
	return debugVar:GetBool()
end
