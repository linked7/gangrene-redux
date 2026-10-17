-- Notify( ply, text ): the one way to tell a player why something didn't work (R5).
if SERVER then
	Net.Pool( "gr_notify" )

	function Notify( ply, text )
		net.Start( "gr_notify" )
		net.WriteString( text )
		net.Send( ply )
	end
else
	-- The original's notification stack (cl_hud.lua's HUD.Notify), bottom right.
	Net.Receive( "gr_notify", nil, function()
		local text = net.ReadString()
		if HUD and HUD.Notify then
			HUD.Notify( text, Color( 200, 0, 0 ) )
		else
			chat.AddText( Color( 200, 0, 0 ), text )
		end
	end )
end
