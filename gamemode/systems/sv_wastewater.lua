-- Wasteland water: 1:1 port of the original sv_player.lua:3421-3437. Every 1 s a living, non-ghost
-- player in water inside the map's Wasteland box takes WaterLevel() damage and gains WaterLevel()
-- Pox. A Respirator or the outsider race blocks the Pox (not the damage); the aquatic quirk is
-- exempt. Only x/y of the box are checked, as in the original. City water does nothing.
Wastewater = Wastewater or {}
Wastewater.BOXES = Wastewater.BOXES or {
	rp_slumtown = { Vector( 1667, -1529, 1276 ), Vector( 12122, 7142, -809 ) },
}
Wastewater.box = Wastewater.box or Wastewater.BOXES[ game.GetMap() ]

function Wastewater.InBox( pos )
	local b = Wastewater.box
	if not b then return false end
	return pos.x > b[ 1 ].x and pos.x < b[ 2 ].x and pos.y > b[ 1 ].y and pos.y < b[ 2 ].y
end

-- Quirks and the respirator item land in later steps; until then a player flag or item stands in.
function Wastewater.Aquatic( ply )
	if ply.GetQuirk then return ply:GetQuirk() == "aquatic" end
	return ply.GR_Quirk == "aquatic"
end

function Wastewater.Respirator( ply )
	return ply.GR_Respirator == true or ( Inventory and Inventory.Count( ply, "respirator" ) > 0 ) or false
end

function Wastewater.Outsider( ply )
	local r = ply:GetRaceDef()
	return r ~= nil and r.id == "outsider"
end

function Wastewater.Level( ply ) return ply:WaterLevel() end

function Wastewater.Tick( ply )
	if Wastewater.Aquatic( ply ) then return end
	local lvl = Wastewater.Level( ply )
	if lvl <= 0 or not ply:Alive() or ply:IsGhost() or not Wastewater.InBox( ply:GetPos() ) then return end
	local dmg = DamageInfo()
	dmg:SetDamage( lvl )
	dmg:SetDamageType( DMG_POISON )
	dmg:SetAttacker( game.GetWorld() )
	dmg:SetInflictor( game.GetWorld() )
	ply.GR_WasteWaterHit = true
	ply:TakeDamageInfo( dmg )
	ply.GR_WasteWaterHit = nil
	if not ( Wastewater.Respirator( ply ) or Wastewater.Outsider( ply ) ) then
		Needs.Add( ply, "Pox", lvl, "wasteland water" )
	end
end

-- Water damage is flat, like the original's TakeDamage: it never counts as a hitgroup hit.
Damage.Add( "Scale", "wastewater", function( ply, dmg, ctx )
	if ply.GR_WasteWaterHit then ctx.hitgroup = HITGROUP_GENERIC end
end )

Sched.EachPlayer( "wastewater", 1, Wastewater.Tick )
