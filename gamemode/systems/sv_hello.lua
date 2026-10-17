-- Step 0 smoke test: greet each client once it has loaded.
Net.Pool( "gr_hello" )

hook.Add( "GR_PlayerReady", "gr_hello", function( ply )
	Log.Info( "hello", "%s is ready", ply:Nick() )
	net.Start( "gr_hello" )
	net.Send( ply )
end )
