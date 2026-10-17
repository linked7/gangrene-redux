-- Long actions (rule 6): reviving, surgery, building, prying. An action is a record on the
-- player, checked by one scheduled job, never a timer. It is cancelled when the player dies,
-- changes fate, moves out of range of the target, or (if asked) takes damage.
--
--   Actions.Start( ply, kind, target, duration, {
--       label, range = 120, cancelOnDamage, canContinue( ply, target ) -> bool,
--       onDone( ply, target ), onCancel( ply, target, why ) } ) -> ok
Actions = Actions or {}

State.Field( "ActionStart", "Float", 0, State.OWNER, 0 )
State.Field( "ActionEnd", "Float", 0, State.OWNER, 0 )
State.Field( "ActionLabel", "String", 0, State.OWNER, "" )

-- The bar is cl_hud.lua's "progress" layer (the original's DrawTimedProgress).
if CLIENT then return end

local DEFAULT_RANGE = 120

function Actions.Get( ply ) return ply.GR_Action end

function Actions.Start( ply, kind, target, duration, opts )
	if ply.GR_Action then return false end
	opts = opts or {}
	local now = CurTime()
	ply.GR_Action = {
		kind = kind, target = target, startedAt = now, duration = duration,
		range = opts.range or DEFAULT_RANGE, opts = opts,
	}
	ply:SetActionStart( now )
	ply:SetActionEnd( now + duration )
	ply:SetActionLabel( opts.label or kind )
	return true
end

local function clear( ply )
	ply.GR_Action = nil
	ply:SetActionStart( 0 )
	ply:SetActionEnd( 0 )
	ply:SetActionLabel( "" )
end

local function call( a, name, ... )
	local fn = a.opts[ name ]
	if not fn then return end
	local ok, err = xpcall( fn, debug.traceback, ... )
	if not ok then Log.Error( "actions", "%s.%s: %s", a.kind, name, err ) end
end

function Actions.Cancel( ply, why )
	local a = ply.GR_Action
	if not a then return end
	clear( ply )
	if why and IsValid( ply ) then Notify( ply, why ) end
	call( a, "onCancel", ply, a.target, why )
end

local function inRange( ply, a )
	if not IsValid( a.target ) then return false end
	return ply:GetPos():DistToSqr( a.target:GetPos() ) <= a.range * a.range
end

Sched.Every( "actions", 0.1, function()
	local now = CurTime()
	for _, ply in player.Iterator() do
		local a = ply.GR_Action
		if not a then
		elseif not ply:Alive() then
			Actions.Cancel( ply )
		elseif not inRange( ply, a ) then
			Actions.Cancel( ply, "You moved away." )
		elseif a.opts.canContinue and not a.opts.canContinue( ply, a.target ) then
			Actions.Cancel( ply )
		elseif now >= a.startedAt + a.duration then
			clear( ply )
			call( a, "onDone", ply, a.target )
		end
	end
end )

hook.Add( "GR_FateEnter", "gr_actions", function( ply ) Actions.Cancel( ply ) end )
hook.Add( "PlayerDeath", "gr_actions", function( ply ) Actions.Cancel( ply ) end )
-- A stage of the damage pipeline, not an EntityTakeDamage hook: the pipeline's own hook returns
-- true for every hit it applies, which would stop a plain hook from ever seeing it.
Damage.Add( "Scale", "actions", function( ply, dmg )
	if dmg:GetDamage() > 0 and ply.GR_Action and ply.GR_Action.opts.cancelOnDamage then
		Actions.Cancel( ply, "You were hurt." )
	end
end )
