-- Screen effects the server starts on one player's screen (docs/05 §3), as the original's
-- nHeadwound / nFrighten / nJumpscare messages did. Presentation only: cl_effects.lua plays them.
--
--   FX.Send( ply, kind )   kind: "headwound", "frighten", "jumpscare" or "flash"
--
-- Sent from here:
--   a hit to the head                    headwound (and the headshot sound, as the original)
--   getting up or being revived          frighten (the original frightened on every revive)
--   an unjust killing (Crime.Judge)      jumpscare if it cost stem cells, else frighten
-- Other systems call FX.Send for their own moments (thoughtcrime's jumpscare, a melee red flash).
FX = FX or {}
FX.KINDS = { "headwound", "frighten", "jumpscare", "flash" }
FX.ID = {}
for i, k in ipairs( FX.KINDS ) do FX.ID[ k ] = i end

Net.Pool( "gr_fx" )

if CLIENT then return end

function FX.Send( ply, kind )
	local id = FX.ID[ kind ]
	if not id or not IsValid( ply ) or ply:IsBot() then return end
	net.Start( "gr_fx" )
	net.WriteUInt( id, 3 )
	net.Send( ply )
end

-- The original's ScalePlayerDamage: a head hit plays the headshot sound and wounds the view.
-- The Scale stage runs before anything can block the hit; the hitgroup scaling is sv_damage's.
Damage.Add( "Scale", "fx_head", function( ply, dmg, ctx )
	if ctx.hitgroup ~= HITGROUP_HEAD or ply:IsGhost() or dmg:GetDamage() <= 0 then return end
	ply:EmitSound( "player/headshot" .. math.random( 1, 2 ) .. ".wav" )
	FX.Send( ply, "headwound" )
end )

hook.Add( "GR_PlayerRestored", "gr_fx", function( ply ) FX.Send( ply, "frighten" ) end )

hook.Add( "GR_Judged", "gr_fx", function( attacker, _, out )
	if not out or not ( out.wanted or out.evidence or ( out.stem and out.stem < 0 ) ) then return end
	FX.Send( attacker, ( out.stem and out.stem < 0 ) and "jumpscare" or "frighten" )
end )
