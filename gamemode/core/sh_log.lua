-- Console logging. Log.Debug only prints while the gr_debug convar is on.
Log = Log or {}
Log.counts = Log.counts or { error = 0, warn = 0 } -- read by the soak (systems/sv_soak.lua)

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
	-- tools/srv.sh fails a test run on any "ERROR:" line.
	if level == "error" then msg = "ERROR: " .. msg end
	if Log.counts[ level ] then Log.counts[ level ] = Log.counts[ level ] + 1 end
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
