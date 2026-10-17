-- Wading slowdown: any water scales speed x0.8 / x0.6 / x0.5 by WaterLevel(); dry ground is untouched.
return function( T )
	T.Equal( Movement.WadeScale( 0 ), 1, "dry ground is full speed" )
	T.Equal( Movement.WadeScale( 1 ), 0.8, "ankle-deep is x0.8" )
	T.Equal( Movement.WadeScale( 2 ), 0.6, "waist-deep is x0.6" )
	T.Equal( Movement.WadeScale( 3 ), 0.5, "under water is x0.5" )
	T.Check( hook.GetTable().SetupMove and hook.GetTable().SetupMove.gr_wading, "the SetupMove hook is installed" )
end
