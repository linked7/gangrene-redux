-- The scoreboard (hold TAB): players grouped by fate, with name, rank and ping. Nobody's bones
-- or stem cells are shown. Like chat, the living never see ghosts; ghosts and admins do. Only
-- admins see account names; everyone else sees character names.
local C = HUD.COLORS
local showing = false

hook.Add( "ScoreboardShow", "gr_scoreboard", function()
	showing = true
	return true
end )
hook.Add( "ScoreboardHide", "gr_scoreboard", function()
	showing = false
	return true
end )

local function groups( me )
	local seeGhosts = me:IsGhost() or me:IsAdmin()
	local byFate = {}
	for _, p in player.Iterator() do
		local i = p:GetFate()
		if i ~= FATE_GHOST or seeGhosts then
			byFate[ i ] = byFate[ i ] or {}
			table.insert( byFate[ i ], p )
		end
	end
	local out = {}
	for _, f in ipairs( Fates.All() ) do
		local members = byFate[ f.index ]
		if members and f.index ~= FATE_GHOST then table.insert( out, { f, members } ) end
	end
	-- The dead go last.
	if byFate[ FATE_GHOST ] then table.insert( out, { Fates.ByIndex( FATE_GHOST ), byFate[ FATE_GHOST ] } ) end
	for _, g in ipairs( out ) do
		table.sort( g[ 2 ], function( a, b ) return string.lower( a:Nick() ) < string.lower( b:Nick() ) end )
	end
	return out
end

hook.Add( "HUDDrawScoreBoard", "gr_scoreboard", function()
	if not showing then return end
	local me = LocalPlayer()
	local list = groups( me )
	local admin = me:IsAdmin() -- staff also see account names next to character names
	local pad, rowH = HUD.S( 14 ), draw.GetFontHeight( "gr_hud" ) + HUD.S( 6 )
	local headH = draw.GetFontHeight( "gr_hud_big" ) + HUD.S( 10 )
	local h = pad * 2 + headH
	for _, g in ipairs( list ) do h = h + rowH * ( #g[ 2 ] + 1 ) + HUD.S( 6 ) end
	local w = math.min( HUD.S( 720 ), ScrW() - 40 )
	h = math.min( h, ScrH() - 40 )
	local x, y = ( ScrW() - w ) / 2, math.max( ( ScrH() - h ) / 2, 20 )
	local bottom = y + h - pad

	draw.RoundedBox( 6, x, y, w, h, C.back )
	local left, right = x + pad, x + w - pad
	local rankX, pingX = right - HUD.S( 200 ), right
	draw.SimpleText( "Gangrene", "gr_hud_big", left, y + pad, C.text )
	draw.SimpleText( string.format( "Day %d    %d souls", Round.Number(), player.GetCount() ), "gr_hud_small",
		right, y + pad + HUD.S( 8 ), C.dim, TEXT_ALIGN_RIGHT )
	y = y + pad + headH

	for _, g in ipairs( list ) do
		if y + rowH > bottom then break end
		local f, members = g[ 1 ], g[ 2 ]
		draw.SimpleText( string.format( "%s (%d)", f.Name, #members ), "gr_hud", left, y, f.Color or C.text )
		draw.SimpleText( "Rank", "gr_hud_small", rankX, y + HUD.S( 3 ), C.dim )
		draw.SimpleText( "Ping", "gr_hud_small", pingX, y + HUD.S( 3 ), C.dim, TEXT_ALIGN_RIGHT )
		y = y + rowH
		surface.SetDrawColor( C.line )
		surface.DrawRect( left, y - HUD.S( 4 ), right - left, 1 )
		for _, p in ipairs( members ) do
			if y + rowH > bottom then break end
			local name = p:Nick()
			if admin and name ~= p:SteamName() then name = name .. "  (" .. p:SteamName() .. ")" end
			draw.SimpleText( name, "gr_hud", left + HUD.S( 12 ), y, p == me and C.warn or ( p:Alive() and C.text or C.dim ) )
			draw.SimpleText( Rank.Name( p:GetRank() ), "gr_hud", rankX, y, C.dim )
			draw.SimpleText( p:IsBot() and "bot" or p:Ping(), "gr_hud", pingX, y, C.dim, TEXT_ALIGN_RIGHT )
			y = y + rowH
		end
		y = y + HUD.S( 6 )
	end
end )
