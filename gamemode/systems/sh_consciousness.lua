-- Consciousness, 0-100. Blunt hits lower it; at 0 the player passes out into a ragdoll, and
-- wakes when it climbs back to WAKE_AT. It recovers about a point a second, slower when hungry.
Consciousness = Consciousness or {}

State.Field( "Consciousness", "UInt", 7, State.OWNER, 100 )
State.Field( "PassedOut", "Bool", 0, State.OWNER, false )

if CLIENT then
	hook.Add( "HUDPaint", "gr_consciousness", function()
		if not LocalPlayer():GetPassedOut() then return end
		surface.SetDrawColor( 0, 0, 0, 255 )
		surface.DrawRect( 0, 0, ScrW(), ScrH() )
		draw.SimpleText( "You are unconscious.", "DermaLarge", ScrW() / 2, ScrH() / 2, Color( 90, 90, 90 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end )
	return
end

Consciousness.WAKE_AT = 50
Consciousness.BLUNT_SCALE = 1.5  -- consciousness lost per point of blunt damage
local BLUNT = bit.bor( DMG_CLUB, DMG_CRUSH, DMG_FALL )

function Consciousness.Get( ply ) return ply.GR_Consciousness or 100 end

local function set( ply, v )
	ply.GR_Consciousness = math.Clamp( v, 0, 100 )
	ply:SetConsciousness( math.floor( ply.GR_Consciousness ) )
end

function Consciousness.Hurt( ply, amount )
	if ply:IsGhost() or not ply:Alive() then return end
	set( ply, Consciousness.Get( ply ) - amount )
	if ply.GR_Consciousness <= 0 and not ply:GetPassedOut() then Consciousness.PassOut( ply ) end
end

function Consciousness.PassOut( ply )
	Corpse.Create( ply, "unconscious" )
	Actions.Cancel( ply )
	ply:SetPassedOut( true )
	ply:SetNoDraw( true )
	ply:SetNotSolid( true )
	ply:Freeze( true )
	local wep = ply:GetActiveWeapon()
	if IsValid( wep ) then wep:SetNoDraw( true ) end
	Log.Debug( "consciousness", "%s passed out", ply:Nick() )
end

function Consciousness.WakeUp( ply )
	local rag, rec = Corpse.Of( ply )
	ply:SetPassedOut( false )
	ply:SetNoDraw( false )
	ply:SetNotSolid( false )
	ply:Freeze( false )
	local wep = ply:GetActiveWeapon()
	if IsValid( wep ) then wep:SetNoDraw( false ) end
	if rec and rec.state == "unconscious" then
		ply:SetPos( rag:GetPos() + Vector( 0, 0, 8 ) )
		ply.GR_Corpse = nil
		rag:Remove()
	end
	Notify( ply, "You come to." )
end

-- Armor dulls blunt hits (0.75, as in the original); the health damage still lands.
Damage.Add( "Consciousness", "blunt", function( ply, dmg )
	if bit.band( dmg:GetDamageType(), BLUNT ) == 0 then return end
	local amount = dmg:GetDamage() * Consciousness.BLUNT_SCALE
	if ply:Armor() > 0 then amount = amount * 0.75 end
	Consciousness.Hurt( ply, amount )
end )

Sched.EachPlayer( "consciousness", 1, function( ply )
	if not ply:Alive() or ply:IsGhost() then return end
	local v = Consciousness.Get( ply )
	if v < 100 then
		-- 1 point per (0.3 + emptiness/100) seconds, as in the original's ConsciousThink.
		set( ply, v + 1 / ( 0.3 + Needs.Get( ply, "Emptiness" ) / 100 ) )
	end
	if ply:GetPassedOut() then
		local rag = Corpse.Of( ply )
		if rag then ply:SetPos( rag:GetPos() ) end
		if ply.GR_Consciousness >= Consciousness.WAKE_AT then Consciousness.WakeUp( ply ) end
	end
end )

hook.Add( "GR_FateEnter", "gr_consciousness", function( ply )
	ply.GR_Consciousness = 100
end )
