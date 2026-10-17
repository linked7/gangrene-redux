-- Recruiting (step 11.4): there is no station for a recruited fate. A fate with
-- Recruits = { from = <fate id>, to = <fate id> } (the Kaiser) gets a context action on a living
-- player of `from` within Recruit.RANGE; the target gets a yes/no prompt and on yes becomes `to`
-- at no stem-cell cost. A fate marked Recruited = true gets no fate_station (Layout.DefaultSet).
--
--   Recruit.Offer( ply, target )   server; validates and sends the prompt
--   Recruit.Answer( target, yes )  server; the target's reply, validated again
Recruit = Recruit or {}
Recruit.RANGE = 100
Recruit.TIMEOUT = 30

local function fateName( id )
	local f = Fates.Get( id )
	return f and f.Name or tostring( id )
end

-- Shared: whether `ply` may offer `target` its recruitment, and why not.
function Recruit.Can( ply, target )
	local r = ply:FateHas( "Recruits" )
	if not r then return false, "You recruit no one." end
	if not ply:Alive() or ply:IsGhost() then return false, "The dead recruit no one." end
	if not ( IsValid( target ) and target:IsPlayer() ) or target == ply then return false, "Recruit whom?" end
	local def = target:GetFateDef()
	if not target:Alive() or target:IsGhost() or not def or def.id ~= r.from then
		return false, "Only a living " .. fateName( r.from ) .. " can be recruited."
	end
	if ply:GetPos():DistToSqr( target:GetPos() ) > Recruit.RANGE * Recruit.RANGE then return false, "Get closer." end
	local to = Fates.Get( r.to )
	if not to then return false, "There is no such purpose." end
	if Fates.Count( r.to ) >= Fates.SlotLimit( to ) then return false, "There is no free " .. to.Name .. " slot." end
	return true
end

Interact.Add( "recruit", {
	label = function( ply )
		local r = ply:FateHas( "Recruits" )
		return "Recruit as " .. ( r and fateName( r.to ) or "?" )
	end,
	range = Recruit.RANGE,
	show = function( ply, ent )
		local r = ply:FateHas( "Recruits" )
		if not r or not ent:IsPlayer() or ply:IsGhost() then return false end
		local def = ent:GetFateDef()
		return def ~= nil and def.id == r.from and ent:Alive()
	end,
	run = function( ply, ent ) Recruit.Offer( ply, ent ) end,
} )

if CLIENT then
	local function answer( yes )
		net.Start( "gr_recruit_answer" )
		net.WriteBool( yes )
		net.SendToServer()
	end
	Net.Receive( "gr_recruit_offer", nil, function()
		local by = net.ReadString()
		local to = net.ReadString()
		Derma_Query( by .. " offers to make you a " .. to .. ".", "Recruitment",
			"Accept", function() answer( true ) end,
			"Refuse", function() answer( false ) end )
	end )
	return
end

-- Server ------------------------------------------------------------------------------------

Net.Pool( "gr_recruit_offer" )
Recruit.pending = Recruit.pending or {} -- target -> { by, expires }

function Recruit.Offer( ply, target )
	local ok, why = Recruit.Can( ply, target )
	if not ok then Notify( ply, why ) return false, why end
	local to = fateName( ply:FateHas( "Recruits" ).to )
	Recruit.pending[ target ] = { by = ply, expires = CurTime() + Recruit.TIMEOUT }
	Notify( ply, "You offer " .. target:Nick() .. " a place as " .. to .. "." )
	if Net.IsClient( target ) then
		net.Start( "gr_recruit_offer" )
		net.WriteString( ply:Nick() )
		net.WriteString( to )
		net.Send( target )
	end
	return true
end

function Recruit.Answer( target, yes )
	local p = Recruit.pending[ target ]
	Recruit.pending[ target ] = nil
	if not p or CurTime() > p.expires or not IsValid( p.by ) then return false, "No offer stands." end
	local ply = p.by
	if not yes then
		Notify( ply, target:Nick() .. " refuses." )
		return false, "refused"
	end
	local ok, why = Recruit.Can( ply, target )
	if not ok then
		Notify( target, "The offer no longer stands." )
		Notify( ply, why )
		return false, why
	end
	Fates.Apply( target, ply:FateHas( "Recruits" ).to, { reason = "pick" } )
	Notify( ply, target:Nick() .. " accepts." )
	Log.Info( "recruit", "%s recruited %s", ply:Nick(), target:Nick() )
	return true
end

Net.Receive( "gr_recruit_answer", { rate = 2, alive = true }, function( ply )
	Recruit.Answer( ply, net.ReadBool() )
end )

hook.Add( "PlayerDisconnected", "gr_recruit", function( ply ) Recruit.pending[ ply ] = nil end )
