Net.Receive( "gr_hello", nil, function()
	chat.AddText( Color( 180, 40, 40 ), "hello" )
	Log.Info( "hello", "server said hello" )
end )
