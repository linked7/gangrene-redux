-- XOMBOKOM (step 11.4): /xombokom <text> (alias /xk), Kaiser only (fate flag Xombokom). Every
-- client shows the text upper case in large red (180,0,0) at top centre for about 8 s, then it
-- fades; a new one replaces it. A random kidneydagger/broadcast1-7.wav plays globally at pitch
-- 80-120. Nothing goes to chat (original: sh_chat.lua:1380, CC.Advertise for the kommandant).
Xombokom = Xombokom or {}
Xombokom.MAX = 120
Xombokom.COOLDOWN = 30
Xombokom.SHOW = 8
Xombokom.FADE = 1.5
Xombokom.COLOR = Color( 180, 0, 0 )

Net.Pool( "gr_xombokom" )

if SERVER then
	local RED = Color( 200, 0, 0 )

	-- Returns the recipients (everyone), or nil and why (already told to the speaker).
	-- GR_Xombokom( ply, text, sound, pitch ) lets tests listen.
	function Xombokom.Send( ply, text )
		text = string.Trim( text or "" )
		if text == "" then return nil, "empty" end
		if not ply:Alive() or not ply:FateHas( "Xombokom" ) then
			Chat.Tell( ply, RED, "Only the Kaiser can use the XOMBOKOM." )
			return nil, "fate"
		end
		if utf8.len( text ) and utf8.len( text ) > Xombokom.MAX or #text > Xombokom.MAX * 4 then
			Chat.Tell( ply, RED, "The XOMBOKOM takes at most " .. Xombokom.MAX .. " characters." )
			return nil, "length"
		end
		local last = ply.GR_LastXombokom
		if last and CurTime() < last + Xombokom.COOLDOWN then
			Chat.Tell( ply, RED, "Wait " .. math.ceil( last + Xombokom.COOLDOWN - CurTime() ) .. " seconds to use the XOMBOKOM again." )
			return nil, "cooldown"
		end
		ply.GR_LastXombokom = CurTime()

		text = string.upper( text )
		local snd = "kidneydagger/broadcast" .. math.random( 1, 7 ) .. ".wav"
		local pitch = math.random( 80, 120 )
		net.Start( "gr_xombokom" )
		net.WriteString( text )
		net.WriteString( snd )
		net.WriteUInt( pitch, 8 )
		net.Broadcast()
		hook.Run( "GR_Xombokom", ply, text, snd, pitch )
		Log.Info( "chat", "[XOMBOKOM] %s (%s): %s", ply:Nick(), ply:SteamName(), text )
		return player.GetHumans()
	end
end

if CLIENT then
	local cur -- { text, at }

	Net.Receive( "gr_xombokom", nil, function()
		local text, snd, pitch = net.ReadString(), net.ReadString(), net.ReadUInt( 8 )
		cur = { text = text, at = CurTime() }
		LocalPlayer():EmitSound( snd, 0, pitch )
	end )

	HUD.Layer( 115, "xombokom", function()
		if not cur then return end
		local t = CurTime() - cur.at
		if t > Xombokom.SHOW + Xombokom.FADE then cur = nil return end
		local a = t > Xombokom.SHOW and 1 - ( t - Xombokom.SHOW ) / Xombokom.FADE or 1
		local font = HUD.Font( "ChatBig" )
		local text = HUD.FormatLine( "[XOMBOKOM] " .. cur.text, font, ScrW() * 0.8 )
		local c = Xombokom.COLOR
		draw.DrawText( text, font, ScrW() / 2 + 2, HUD.S( 40 ) + 2, Color( 0, 0, 0, 255 * a ), TEXT_ALIGN_CENTER )
		draw.DrawText( text, font, ScrW() / 2, HUD.S( 40 ), Color( c.r, c.g, c.b, 255 * a ), TEXT_ALIGN_CENTER )
	end )
end
