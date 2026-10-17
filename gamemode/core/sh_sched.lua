-- The scheduler: every periodic job in the gamemode runs from here, never from its own timer
-- or Think hook. Each call is wrapped in xpcall, so one failing job can't stop the others (P1, B9).
--
--   Sched.Every( name, interval, fn )        fn() every `interval` seconds
--   Sched.EachPlayer( name, interval, fn )   fn( ply ) for every player once per `interval`,
--                                            spread evenly across the ticks in between
--
-- Registering a name again replaces the job. `sched_debug 1` prints per-job cost every 5 s.
Sched = Sched or {}

local jobs = {}   -- name -> job
local order = {}  -- names in registration order, so jobs run in a stable order
local debugVar = CreateConVar( "sched_debug", "0", FCVAR_NONE, "Print scheduler job costs every 5 s." )

local function add( name, job )
	if not jobs[ name ] then table.insert( order, name ) end
	job.name = name
	job.calls, job.errors, job.total, job.max = 0, 0, 0, 0
	jobs[ name ] = job
end

function Sched.Every( name, interval, fn )
	add( name, { interval = interval, fn = fn, nextRun = CurTime() + interval } )
end

function Sched.EachPlayer( name, interval, fn )
	add( name, { interval = interval, fn = fn, perPlayer = true, queue = {}, cursor = 1, budget = 0 } )
end

function Sched.Remove( name )
	if not jobs[ name ] then return end
	jobs[ name ] = nil
	table.RemoveByValue( order, name )
end

function Sched.Get( name ) return jobs[ name ] end
-- Job names in run order (read-only).
function Sched.Names() return order end

local function call( job, arg )
	local start = SysTime()
	local ok, err = xpcall( job.fn, debug.traceback, arg )
	local cost = SysTime() - start
	job.calls = job.calls + 1
	job.total = job.total + cost
	if cost > job.max then job.max = cost end
	if not ok then
		job.errors = job.errors + 1
		Log.Error( "sched", "job %s failed: %s", job.name, err )
	end
end

-- Runs about n * dt / interval players per tick, carrying fractions over, so each player
-- comes up once per interval whatever the tick rate.
local function runPerPlayer( job, dt )
	if job.cursor > #job.queue then
		job.queue = player.GetAll()
		job.cursor = 1
	end
	local n = #job.queue
	if n == 0 then return end

	job.budget = math.min( job.budget + n * dt / job.interval, n )
	while job.budget >= 1 and job.cursor <= n do
		local ply = job.queue[ job.cursor ]
		job.cursor = job.cursor + 1
		job.budget = job.budget - 1
		if IsValid( ply ) then call( job, ply ) end
	end
end

local lastTick = CurTime()
local function tick()
	local now = CurTime()
	local dt = now - lastTick
	lastTick = now

	for _, name in ipairs( order ) do
		local job = jobs[ name ]
		if job.perPlayer then
			runPerPlayer( job, dt )
		elseif now >= job.nextRun then
			-- Schedule from the planned time so intervals don't drift, but never queue up a backlog.
			job.nextRun = math.max( job.nextRun + job.interval, now )
			call( job )
		end
	end
end

hook.Add( "Think", "gr_sched", tick )

local nextReport = 0
hook.Add( "Think", "gr_sched_debug", function()
	if not debugVar:GetBool() or CurTime() < nextReport then return end
	nextReport = CurTime() + 5
	for _, name in ipairs( order ) do
		local j = jobs[ name ]
		Log.Info( "sched", "%-24s calls=%-6d errors=%-4d total=%.2fms max=%.3fms",
			name, j.calls, j.errors, j.total * 1000, j.max * 1000 )
	end
end )
