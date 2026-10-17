-- The scoreboard (hold TAB), ported from the original's gui/cl_scoreboard.lua: a 500 x 600 panel,
-- "<count> <random title>" stuttered in LabelMassive over a 50 px header, then 48 px rows with
-- avatar, name, ping (green to red) and the rank icon (tooltip: the rank's name).
-- The remake's one rule on top: like chat, the living never see ghosts; ghosts and admins do.
-- Nobody's bones, stem cells or fate are shown (the original showed none either). The header
-- also carries the day's time left (cl_round.lua used to draw it on the HUD).
local panel

local TITLES = { "failing livers", "friendly faces", "rotten bastards", "treacherous misfits", "beating hearts", "fresh meals",
	"enemy soldiers", "scheming cultists", "violent workmen", "skittering spiders", "organ donors", "helpless slaves",
	"serial killers", "dead bodies", "whispering ghosts", "doomed migrants", "incoming missiles", "growing tumors",
	"sneaky skinshapes", "abusive sanitars", "eyes in the sky", "unspeakable horrors", "terrible curses",
	"seconds until midnight", "stab wounds", "empty graves", "loathesome leeches", "frostbitten prisoners" }

local function visible( me )
	local seeGhosts = me:IsGhost() or me:IsAdmin()
	local out = {}
	for _, p in player.Iterator() do
		if seeGhosts or not p:IsGhost() then table.insert( out, p ) end
	end
	return out
end

local function addRow( list, ply, y, shade )
	local entry = vgui.Create( "DPanel", list )
	entry:SetSize( 500, 48 )
	entry:SetPos( 0, y )
	entry:SetTooltip( Rank.Name( ply:GetRank() ) )
	entry.Paint = function( self, w, h )
		if not IsValid( ply ) then
			self:Remove()
			return
		end
		if shade then draw.RoundedBox( 0, 0, 0, w, h, Color( 20, 20, 20, 130 ) ) end
		surface.SetFont( HUD.Font( "LabelSmall" ) )
		surface.SetTextColor( 200, 200, 200, 255 )
		surface.SetTextPos( 58, 5 )
		surface.DrawText( ply:Nick() )
		local ping = ply:Ping()
		local pw = surface.GetTextSize( tostring( ping ) )
		surface.SetTextPos( w - 30 - pw, 10 )
		surface.SetTextColor( math.min( ping, 255 ), math.max( 255 - ping, 0 ), 0, 255 )
		surface.DrawText( tostring( ping ) )
		local mat = HUD.Mat( "rank" .. ply:GetRank() )
		if mat then
			surface.SetMaterial( mat )
			surface.SetDrawColor( 255, 255, 255, 255 )
			surface.DrawTexturedRect( 58, 30, 16, 16 )
		end
	end

	local icon = vgui.Create( "AvatarImage", entry )
	icon:SetPos( 0, 0 )
	icon:SetSize( 48, 48 )
	icon:SetPlayer( ply, 64 )

	local but = vgui.Create( "DButton", entry )
	but:SetPos( 0, 0 )
	but:SetSize( 48, 48 )
	but:SetText( "" )
	but.Paint = function() end
	but.DoClick = function()
		if IsValid( ply ) then ply:ShowProfile() end
	end
	list:AddItem( entry )
end

local function show()
	if IsValid( panel ) then panel:Remove() end
	local title = TITLES[ math.random( #TITLES ) ]
	panel = vgui.Create( "DPanel" )
	panel:SetSize( 500, 600 )
	panel:Center()
	panel:MakePopup()
	panel:SetKeyboardInputEnabled( false )
	panel.Paint = function( _, w, h )
		draw.RoundedBox( 0, 0, 0, w, h, Color( 30, 30, 30, 230 ) )
		draw.RoundedBox( 0, 0, 0, w, 50, Color( 20, 20, 20, 255 ) )
		surface.SetFont( HUD.Font( "LabelMassive" ) )
		surface.SetTextColor( 200, 200, 200, 255 )
		surface.SetTextPos( 10, 2 )
		surface.DrawText( HUD.Stutter( player.GetCount() .. " " .. title ) )
		-- The day and its time left (the remake's rounds; kept off the HUD, which the original never had).
		local left = Round.EndsAt() - CurTime()
		if Round.EndsAt() > 0 and left > 0 then
			local txt = string.format( "Day %d  %d:%02d", Round.Number(), math.floor( left / 60 ), math.floor( left % 60 ) )
			surface.SetFont( HUD.Font( "LabelSmall" ) )
			local tw = surface.GetTextSize( txt )
			surface.SetTextColor( 150, 150, 150, 255 )
			surface.SetTextPos( w - 10 - tw, 15 )
			surface.DrawText( txt )
		end
		return true
	end

	local list = vgui.Create( "DScrollPanel", panel )
	list:SetPos( 0, 50 )
	list:SetSize( 500, 550 )
	list.Paint = function() end
	local y, shade = 0, true
	for _, p in ipairs( visible( LocalPlayer() ) ) do
		addRow( list, p, y, shade )
		y = y + 48
		shade = not shade
	end
end

hook.Add( "ScoreboardShow", "gr_scoreboard", function()
	show()
	return true
end )
hook.Add( "ScoreboardHide", "gr_scoreboard", function()
	if IsValid( panel ) then panel:Remove() end
	panel = nil
	return true
end )
