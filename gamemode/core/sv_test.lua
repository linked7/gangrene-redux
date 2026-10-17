-- Headless test runner. tools/srv.sh writes data/gr_autotest.txt with a scenario name; once the
-- map is up the runner loads gamemode/tests/sv_<name>.lua, runs it as a coroutine and writes
-- data/gr_tests/<name>.txt with one PASS/FAIL line per check and a final DONE line.
-- `gr_test <name>` in the server console runs a scenario by hand. Inert otherwise.
Test = Test or {}

local root = GM.FolderName .. "/gamemode/tests/"
local running

local function finish( reason )
	local r = running
	running = nil
	hook.Remove( "Think", "gr_test" )
	if reason then table.insert( r.lines, "FAIL " .. reason ) r.fail = r.fail + 1 end
	table.insert( r.lines, string.format( "DONE pass=%d fail=%d", r.pass, r.fail ) )
	file.CreateDir( "gr_tests" )
	file.Write( "gr_tests/" .. r.name .. ".txt", table.concat( r.lines, "\n" ) .. "\n" )
	Log.Info( "test", "%s finished: %d passed, %d failed", r.name, r.pass, r.fail )
end

local function newContext( r )
	local T = {}

	function T.Check( cond, msg )
		if cond then
			r.pass = r.pass + 1
			table.insert( r.lines, "PASS " .. msg )
		else
			r.fail = r.fail + 1
			table.insert( r.lines, "FAIL " .. msg )
			Log.Warn( "test", "FAIL %s", msg )
		end
		return cond
	end

	function T.Equal( got, want, msg )
		return T.Check( got == want, string.format( "%s (got %s, want %s)", msg, tostring( got ), tostring( want ) ) )
	end

	-- Log lines containing `text` are expected errors, and tools/srv.sh won't fail the run for them.
	function T.ExpectError( text )
		table.insert( r.lines, "EXPECT_ERROR " .. text )
	end

	function T.Note( fmt, ... )
		table.insert( r.lines, "NOTE " .. string.format( fmt, ... ) )
	end

	-- Yield until `seconds` of game time have passed.
	function T.Wait( seconds )
		r.wakeAt = CurTime() + seconds
		coroutine.yield()
	end

	-- Yield until fn() is truthy; fails the check `msg` after `timeout` seconds.
	function T.WaitUntil( fn, timeout, msg )
		local deadline = CurTime() + ( timeout or 10 )
		while not fn() do
			if CurTime() > deadline then return T.Check( false, msg .. " (timed out)" ) end
			T.Wait( 0.1 )
		end
		return T.Check( true, msg )
	end

	function T.Bots( n )
		local made = {}
		for _ = 1, n do
			local bot = player.CreateNextBot( "bot" .. ( #player.GetBots() + 1 ) )
			if IsValid( bot ) then table.insert( made, bot ) end
		end
		return made
	end

	return T
end

-- True while a scenario runs; Round.End checks it so a test never changes the level.
function Test.IsRunning() return running ~= nil end

function Test.Run( name )
	if running then return Log.Warn( "test", "%s is still running", running.name ) end
	if not string.match( name, "^[%w_]+$" ) then return Log.Warn( "test", "bad scenario name %q", name ) end

	local scenario = include( root .. "sv_" .. name .. ".lua" )
	running = { name = name, lines = {}, pass = 0, fail = 0, wakeAt = 0 }
	if not isfunction( scenario ) then return finish( "tests/sv_" .. name .. ".lua must return a function" ) end

	local T = newContext( running )
	local co = coroutine.create( scenario )
	Log.Info( "test", "running %s", name )

	hook.Add( "Think", "gr_test", function()
		if CurTime() < running.wakeAt then return end
		local ok, err = coroutine.resume( co, T )
		if not ok then
			finish( "error: " .. debug.traceback( co, tostring( err ) ) )
		elseif coroutine.status( co ) == "dead" then
			finish()
		end
	end )
end

concommand.Add( "gr_test", function( ply, _, args )
	if IsValid( ply ) then return end -- server console only
	Test.Run( args[ 1 ] or "" )
end )

hook.Add( "InitPostEntity", "gr_autotest", function()
	local name = file.Read( "gr_autotest.txt", "DATA" )
	if not name then return end
	file.Delete( "gr_autotest.txt" )
	-- Give the map a moment to settle before the scenario starts.
	timer.Simple( 1, function() Test.Run( string.Trim( name ) ) end )
end )
