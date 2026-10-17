-- Sanitar work (step 11): machines rust and stop, a sanitar shoots the rust off (each clear costs
-- bullets), finished crates stay locked until a sanitar starts extraction, and corpses dragged to
-- a gr_incinerator are burned. Teeth and Inspect live elsewhere.
--
--   Sanitar.Rusted( machine ), Sanitar.Track( incinerator ), Sanitar.Extract( ply, crate )
Sanitar = Sanitar or {}

Sanitar.RUST_MAX = 100
Sanitar.RUST_PER_CRATE = 20   -- each finished crate wears the machine
Sanitar.RUST_TICK = 6         -- seconds per point of rust while running
Sanitar.RUST_PER_SHOT = 10    -- rust a sanitar's bullet knocks off
Sanitar.BURN_RANGE = 80       -- a corpse this close to an incinerator burns

function Sanitar.Rusted( m )
	return IsValid( m ) and m.GetRust ~= nil and m:GetRust() >= Sanitar.RUST_MAX
end

local function isSanitar( ply ) return IsValid( ply ) and ply:IsPlayer() and ply:FateHas( "Police" ) end

local incinerators = setmetatable( {}, { __mode = "k" } )
function Sanitar.Track( ent ) incinerators[ ent ] = true end
function Sanitar.Incinerators()
	local out = {}
	for e in pairs( incinerators ) do if IsValid( e ) then table.insert( out, e ) end end
	return out
end

Interact.Add( "extract", {
	label = "Start extraction",
	range = 100,
	show = function( ply, ent )
		return IsValid( ent ) and ent:GetClass() == "ent_crate" and ent:GetLocked() and ply:Alive() and not ply:IsGhost() and ply:FateHas( "Police" )
	end,
	run = function( ply, ent ) Sanitar.Extract( ply, ent ) end,
} )

if CLIENT then return end

-- A sanitar unlocks a crate, and everything else waiting at the same machine.
function Sanitar.Extract( ply, crate )
	if not isSanitar( ply ) or not IsValid( crate ) or crate:GetClass() ~= "ent_crate" or not crate:GetLocked() then return false end
	crate:SetLocked( false )
	if IsValid( crate.GR_Station ) then
		for _, c in ipairs( Crates.WaitingList( crate.GR_Station ) ) do c:SetLocked( false ) end
	end
	Notify( ply, "Extraction started: the crates may be hauled." )
	return true
end

local function addRust( m, n )
	m:SetRust( math.Clamp( m:GetRust() + n, 0, Sanitar.RUST_MAX ) )
end
Sanitar.AddRust = addRust

hook.Add( "GR_CrateMade", "gr_sanitar", function( crate, machine )
	if IsValid( crate ) then crate:SetLocked( true ) end
	if IsValid( machine ) and machine.SetRust then addRust( machine, Sanitar.RUST_PER_CRATE ) end
end )

-- Only a sanitar's bullets clean; each hit costs the bullet that made it.
hook.Add( "EntityTakeDamage", "gr_sanitar", function( ent, dmg )
	if not IsValid( ent ) or ( ent:GetClass() ~= "lunch_machine" and ent:GetClass() ~= "machine_tools" ) then return end
	if not dmg:IsBulletDamage() or not isSanitar( dmg:GetAttacker() ) then return end
	addRust( ent, -Sanitar.RUST_PER_SHOT )
	return true
end )

local acc = 0
Sched.Every( "sanitar", 1, function()
	acc = acc + 1
	if acc >= Sanitar.RUST_TICK then
		acc = 0
		for _, m in ipairs( Lunch.All( "lunch_machine" ) ) do
			local s = m:GetStatus()
			if s == "on" or s == "overload" then addRust( m, 1 ) end
		end
	end
	local burners = Sanitar.Incinerators()
	if #burners == 0 then return end
	for rag in pairs( Corpse.All() ) do
		if IsValid( rag ) then
			for _, inc in ipairs( burners ) do
				if rag:GetPos():Distance( inc:GetPos() ) <= Sanitar.BURN_RANGE then rag:Remove() break end
			end
		end
	end
end )

hook.Add( "GR_RoundStart", "gr_sanitar", function()
	for _, m in ipairs( Lunch.All( "lunch_machine" ) ) do m:SetRust( 0 ) end
end )
