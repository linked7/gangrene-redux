-- Client side of rounds and ranks, in the original's end-text style (docs/05 §2): announcements
-- (promotions and the like) are a gold centre line through HUD.EndText plus the chat line, the
-- end of a round is the doom screen's gold lines over a black fade with the countdown, and the
-- marker over anyone whose fate has a `Marker` (the Slave's "Newcomer") is drawn like the
-- original's overhead names (PlayerFont, shadowed). The day's time left is in the scoreboard
-- header (cl_scoreboard.lua), not on the HUD.
local GOLD = Color( 175, 150, 0 )
local ending -- { reason, freed = { names }, untilTime, at }

Net.Receive( "gr_announce", nil, function()
	local text = net.ReadString()
	chat.AddText( GOLD, text )
	HUD.EndText( text, GOLD, 0, 8, nil, ScrH() / 4, HUD.Font( "LabelGiant" ) )
	surface.PlaySound( HUD.Sound( "announce" ) )
end )

local REASONS = { time = "THE DAY IS OVER.", admin = "THE DAY HAS BEEN CUT SHORT." }

Net.Receive( "gr_round_end", nil, function()
	local e = { reason = net.ReadString(), freed = {}, at = CurTime() }
	for _ = 1, net.ReadUInt( 8 ) do table.insert( e.freed, net.ReadString() ) end
	local delay = net.ReadFloat()
	e.untilTime = CurTime() + delay
	ending = e
	local h = ScrH()
	HUD.EndText( REASONS[ e.reason ] or string.upper( e.reason ), GOLD, 1, delay, nil, h / 2.3, HUD.Font( "LabelStupid" ) )
	if #e.freed > 0 then
		HUD.EndText( "FREED BY SURVIVING THE DAY: " .. string.upper( table.concat( e.freed, ", " ) ), GOLD, 3, delay, nil,
			h / 2 + 20, HUD.Font( "LabelMassive" ) )
	end
end )

-- cl_hud.lua loads after this file: the layers are added once the gamemode has loaded.
local function layers()
	-- The black fade under the end text (HUD layer 105: over the bars, under the end text) and the countdown.
	HUD.Layer( 105, "roundend", function()
		if not ending then return end
		local now = CurTime()
		local left = ending.untilTime - now
		if left < -5 then ending = nil return end
		local w, h = ScrW(), ScrH()
		surface.SetDrawColor( 0, 0, 0, 230 * math.Clamp( now - ending.at, 0, 1 ) )
		surface.DrawRect( 0, 0, w, h )
		local txt = HUD.Stutter( string.format( "A new day begins in %d", math.max( math.ceil( left ), 0 ) ) )
		local font = HUD.Font( "LabelBig" )
		surface.SetFont( font )
		local tw = surface.GetTextSize( txt )
		HUD.TextShadow( txt, font, w / 2 - tw / 2, h * 0.8, Color( 125, 125, 125 ), Color( 0, 0, 0 ), 0 )
	end )

	-- The marker over other players' heads, drawn from their (public) fate.
	local MARKER_RANGE = 600
	HUD.Layer( 50, "markers", function( me )
		local font = HUD.Font( "PlayerFont" )
		local t = CurTime()
		for _, p in player.Iterator() do
			local marker = p ~= me and p:Alive() and not p:GetNoDraw() and p:FateHas( "Marker" )
			if marker and me:GetPos():DistToSqr( p:GetPos() ) < MARKER_RANGE * MARKER_RANGE then
				local pos = ( p:GetPos() + Vector( 0, 0, 80 ) ):ToScreen()
				if pos.visible then
					HUD.TextShadow( HUD.Stutter( marker ), font, pos.x, pos.y, Color( 200 + 50 * math.sin( t ), 150, 0 ),
						Color( 0, 0, 0 ), 1 )
				end
			end
		end
	end )
end
if HUD and HUD.Layer then layers() else hook.Add( "PostGamemodeLoaded", "gr_round", layers ) end
