-- Wasteland water: waist-deep in the box costs WaterLevel() HP and Pox each second; a Respirator or
-- the outsider race blocks only the Pox; aquatic is exempt; city water does nothing.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:tww_%'" )
	local b = player.CreateNextBot( "tww_wader" )
	T.Wait( 0.3 )
	b:SetRank( RANK_FRIEND ); b:SetStemCells( 10 )
	T.Check( Fates.Take( b, "sanitar" ), "the wader takes a fate" )
	T.Check( Sched.Get( "wastewater" ) and Sched.Get( "wastewater" ).interval == 1, "the water job runs every second" )

	local oldBox, oldLevel, oldOut = Wastewater.box, Wastewater.Level, Wastewater.Outsider
	local p = b:GetPos()
	Wastewater.box = { p - Vector( 100, 100, 0 ), p + Vector( 100, 100, 0 ) }
	Wastewater.Level = function() return 2 end
	local function reset() b:SetHealth( 50 ); Needs.Add( b, "Pox", -Needs.Get( b, "Pox" ), "test" ) end

	reset()
	T.WaitUntil( function() return b:Health() < 50 end, 3, "the scheduled job hurts a wader" )
	reset()
	Wastewater.Tick( b )
	T.Equal( b:Health(), 48, "waist-deep costs 2 HP" )
	T.Equal( math.Round( Needs.Get( b, "Pox" ) ), 2, "waist-deep adds 2 Pox" )

	reset(); b.GR_Respirator = true
	Wastewater.Tick( b )
	T.Equal( b:Health(), 48, "a respirator still takes the HP" )
	T.Equal( math.Round( Needs.Get( b, "Pox" ) ), 0, "a respirator blocks the Pox" )
	b.GR_Respirator = nil

	reset(); Wastewater.Outsider = function() return true end
	Wastewater.Tick( b )
	T.Equal( b:Health(), 48, "an outsider still takes the HP" )
	T.Equal( math.Round( Needs.Get( b, "Pox" ) ), 0, "an outsider gets no Pox" )
	Wastewater.Outsider = oldOut

	reset(); b.GR_Quirk = "aquatic"
	Wastewater.Tick( b )
	T.Equal( b:Health(), 50, "aquatic takes no damage" )
	T.Equal( math.Round( Needs.Get( b, "Pox" ) ), 0, "aquatic gets no Pox" )
	b.GR_Quirk = nil

	reset(); Wastewater.box = { p + Vector( 500, 500, 0 ), p + Vector( 900, 900, 0 ) }
	Wastewater.Tick( b )
	T.Equal( b:Health(), 50, "city water does nothing" )

	reset(); Wastewater.box = { p - Vector( 100, 100, 0 ), p + Vector( 100, 100, 0 ) }
	Wastewater.Level = function() return 0 end
	Wastewater.Tick( b )
	T.Equal( b:Health(), 50, "dry ground does nothing" )

	Wastewater.Level = oldLevel
	Wastewater.box = oldBox
	b:Kick( "test done" )
end
