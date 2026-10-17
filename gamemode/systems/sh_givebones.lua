-- Give bones (step 11.1): hand bones to a living player within GiveBones.RANGE, from the C menu
-- ("Give bones" > an amount). The lunch machine's crew uses it to settle shares by hand.
--
--   GiveBones.Give( ply, target, amount ) -> ok, why    the core; Interact only calls it
GiveBones = GiveBones or {}

GiveBones.RANGE = 100
GiveBones.AMOUNTS = { 1, 5, 10, 25, 50 }

local valid = {}
for _, n in ipairs( GiveBones.AMOUNTS ) do valid[ n ] = true end

local function living( p ) return IsValid( p ) and p:IsPlayer() and p:Alive() and not p:IsGhost() end

Interact.Add( "give_bones", {
	label = "Give bones",
	range = GiveBones.RANGE,
	show = function( ply, ent ) return ent ~= ply and living( ply ) and living( ent ) end,
	choices = function( ply )
		local out = {}
		for _, n in ipairs( GiveBones.AMOUNTS ) do
			if ply:GetBones() >= n then table.insert( out, { n .. " bones", n } ) end
		end
		return out
	end,
	run = function( ply, ent, choice ) GiveBones.Give( ply, ent, tonumber( choice or "" ) ) end,
} )

if CLIENT then return end

function GiveBones.Give( ply, target, amount )
	if not valid[ amount ] then return false, "amount" end
	if not living( ply ) or not living( target ) or ply == target then return false, "target" end
	if ply:GetPos():DistToSqr( target:GetPos() ) > GiveBones.RANGE * GiveBones.RANGE then return false, "range" end
	if not Econ.Transfer( ply, target, amount, "gift" ) then
		Notify( ply, "You don't have " .. amount .. " bones." )
		return false, "funds"
	end
	Notify( ply, "You gave " .. target:Nick() .. " " .. amount .. " bones." )
	Notify( target, ply:Nick() .. " gave you " .. amount .. " bones." )
	return true
end
