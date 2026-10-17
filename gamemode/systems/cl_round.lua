-- Client side of rounds and ranks: the big announcement line, the time left, the end-of-round
-- screen, and the marker over anyone whose fate has a `Marker` (the Slave's "Newcomer").
local ending -- { reason, freed = { names }, until }

Net.Receive( "gr_announce", nil, function()
	chat.AddText( Color( 230, 200, 60 ), net.ReadString() )
	surface.PlaySound( "buttons/bell1.wav" )
end )

Net.Receive( "gr_round_end", nil, function()
	local e = { reason = net.ReadString(), freed = {} }
	for _ = 1, net.ReadUInt( 8 ) do table.insert( e.freed, net.ReadString() ) end
	e.untilTime = CurTime() + net.ReadFloat()
	ending = e
end )

local REASONS = { time = "The day is over.", admin = "The day has been cut short." }

hook.Add( "HUDPaint", "gr_round", function()
	local w, h = ScrW(), ScrH()
	if ending then
		surface.SetDrawColor( 0, 0, 0, 230 )
		surface.DrawRect( 0, 0, w, h )
		draw.SimpleText( REASONS[ ending.reason ] or ending.reason, "DermaLarge", w / 2, h / 3, Color( 200, 40, 40 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		local y = h / 3 + 50
		if #ending.freed > 0 then
			draw.SimpleText( "Freed by surviving the day:", "DermaDefaultBold", w / 2, y, Color( 230, 200, 60 ), TEXT_ALIGN_CENTER )
			for _, name in ipairs( ending.freed ) do
				y = y + 18
				draw.SimpleText( name, "DermaDefault", w / 2, y, color_white, TEXT_ALIGN_CENTER )
			end
		end
		draw.SimpleText( string.format( "A new day begins in %d", math.max( math.ceil( ending.untilTime - CurTime() ), 0 ) ),
			"DermaDefaultBold", w / 2, h * 0.8, Color( 150, 150, 150 ), TEXT_ALIGN_CENTER )
		return
	end

	local left = Round.EndsAt() - CurTime()
	if Round.EndsAt() > 0 and left > 0 then
		draw.SimpleText( string.format( "Day %d  %d:%02d", Round.Number(), math.floor( left / 60 ), math.floor( left % 60 ) ),
			"DermaDefault", w - 12, 12, Color( 160, 160, 160 ), TEXT_ALIGN_RIGHT )
	end
end )

-- The marker over other players' heads, drawn from their (public) fate.
local MARKER_RANGE = 600
hook.Add( "HUDPaint", "gr_rank_marker", function()
	local me = LocalPlayer()
	for _, p in player.Iterator() do
		local marker = p ~= me and p:Alive() and not p:GetNoDraw() and p:FateHas( "Marker" )
		if marker and me:GetPos():DistToSqr( p:GetPos() ) < MARKER_RANGE * MARKER_RANGE then
			local pos = ( p:GetPos() + Vector( 0, 0, 80 ) ):ToScreen()
			if pos.visible then
				draw.SimpleTextOutlined( marker, "DermaDefaultBold", pos.x, pos.y, Color( 230, 200, 60 ),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black )
			end
		end
	end
end )
