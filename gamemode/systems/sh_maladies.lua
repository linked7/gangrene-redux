-- Maladies (step 13): one city-wide threat per round. Round.Start rolls one registered malady
-- (equal odds) or none with Config.MaladyNoneChance. It sits at stage 0 until the round clock
-- starts (first Kaiser), then rises one stage per Config.MaladyDayLength seconds up to 4.
--   Maladies.Register( id, { Name, Stages = { [1] = "text", ... }, OnStage( stage ), OnEnd() } )
--   Maladies.Active() -> id or nil     Maladies.Stage() -> 0..4     Maladies.Is( id, minStage )
Maladies = Maladies or {}
Maladies.List = Maladies.List or {}
Maladies.MAX_STAGE = 4

function Maladies.Register( id, def )
	def.id = id
	def.Stages = def.Stages or {}
	Maladies.List[ id ] = def
end

function Maladies.Active()
	local id = GetGlobalString( "GR_Malady", "" )
	return id ~= "" and id or nil
end
function Maladies.Stage() return GetGlobalInt( "GR_MaladyStage", 0 ) end
function Maladies.Is( id, minStage )
	return Maladies.Active() == id and Maladies.Stage() >= ( minStage or 1 )
end

if CLIENT then return end

local function setStage( n )
	local def = Maladies.List[ Maladies.Active() or "" ]
	if not def or n == Maladies.Stage() then return end
	SetGlobalInt( "GR_MaladyStage", n )
	if def.OnStage then def.OnStage( n ) end
	local text = def.Stages[ n ]
	if text then for _, p in ipairs( player.GetAll() ) do Notify( p, text ) end end
end

-- Force a malady (or nil for none); used by the roll and by tests.
function Maladies.Set( id )
	local old = Maladies.List[ Maladies.Active() or "" ]
	if old and old.OnEnd then old.OnEnd() end
	SetGlobalInt( "GR_MaladyStage", 0 )
	SetGlobalString( "GR_Malady", id or "" )
end

function Maladies.Roll()
	local ids = table.GetKeys( Maladies.List )
	table.sort( ids )
	if #ids == 0 or math.random() < ( Config.MaladyNoneChance or 0.25 ) then return Maladies.Set( nil ) end
	Maladies.Set( ids[ math.random( #ids ) ] )
end

hook.Add( "GR_RoundStart", "gr_maladies", function() Maladies.Roll() end )
hook.Add( "GR_RoundEnd", "gr_maladies", function() Maladies.Set( nil ) end )

function Maladies.Update()
	if not Maladies.Active() or not Round.ClockStarted() then return end
	local day = math.max( Config.MaladyDayLength or 600, 1 )
	setStage( math.min( Maladies.MAX_STAGE, 1 + math.floor( Round.Elapsed() / day ) ) )
end
Sched.Every( "maladies", 1, Maladies.Update )
