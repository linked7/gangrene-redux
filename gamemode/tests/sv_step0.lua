-- Step 0: the gamemode boots, core loads, bots join and become ready.
return function( T )
	T.Equal( engine.ActiveGamemode(), "gangreneredux", "active gamemode" )
	T.Check( Log and Net and Test, "core globals loaded" )

	local ready = {}
	hook.Add( "GR_PlayerReady", "test_step0", function( ply ) ready[ ply ] = true end )

	local bots = T.Bots( 2 )
	T.Equal( #bots, 2, "bots created" )
	T.WaitUntil( function() return ready[ bots[ 1 ] ] and ready[ bots[ 2 ] ] end, 5, "bots fire GR_PlayerReady" )
	hook.Remove( "GR_PlayerReady", "test_step0" )
end
