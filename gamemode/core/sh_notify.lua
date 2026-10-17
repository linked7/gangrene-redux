-- Notify( ply, text ): the one way to tell a player why something didn't work (R5).
if SERVER then
	Net.Pool( "gr_notify" )

	function Notify( ply, text )
		net.Start( "gr_notify" )
		net.WriteString( text )
		net.Send( ply )
	end
else
	Net.Receive( "gr_notify", nil, function()
		chat.AddText( Color( 200, 0, 0 ), net.ReadString() )
		surface.PlaySound( "buttons/button10.wav" )
	end )
end
