-- The fate picker: every fate a ghost could take, with its description, cost, slots and the
-- player's cooldown, greyed out with the reason Fates.CanTake gives (the same function the server
-- runs, R7). Opens by itself on becoming a ghost; F2 or `gr_fates` toggles it. Taking sends
-- gr_take_fate; the server checks everything again (Fates.Request in core/sh_fates.lua).
local C = HUD.COLORS
local frame

local function close()
	if IsValid( frame ) then frame:Remove() end
end

local function slotsText( f )
	local limit = Fates.SlotLimit( f )
	if limit == math.huge then return "Open to all" end
	return string.format( "Taken %d / %d", Fates.Count( f.id ), limit )
end

local function infoText( ply, f )
	local parts = { ( f.Cost or 0 ) > 0 and string.format( "%d stem cell%s", f.Cost, f.Cost == 1 and "" or "s" ) or "Free", slotsText( f ) }
	if f.ForNewPlayers then table.insert( parts, "New players only" ) end
	if f.MinRank then table.insert( parts, Rank.Name( f.MinRank ) .. " or above" ) end
	local wait = ply[ "GetCooldown_" .. f.id ]( ply ) - CurTime()
	if wait > 0 then table.insert( parts, string.format( "Cooldown %d s", math.ceil( wait ) ) ) end
	return table.concat( parts, "    " )
end

local function addEntry( list, f )
	local pad = HUD.S( 10 )
	local entry = list:Add( "DPanel" )
	entry:Dock( TOP )
	entry:DockMargin( 0, 0, 0, HUD.S( 6 ) )
	entry:DockPadding( pad, pad, pad, pad )

	local take = vgui.Create( "DButton", entry )
	take:Dock( RIGHT )
	take:SetWide( HUD.S( 110 ) )
	take:SetFont( "gr_hud" )
	take:SetText( "Take" )
	take.DoClick = function()
		net.Start( "gr_take_fate" )
		net.WriteString( f.id )
		net.SendToServer()
	end

	local name = vgui.Create( "DLabel", entry )
	name:Dock( TOP )
	name:SetFont( "gr_hud_big" )
	name:SetText( f.Name )
	name:SizeToContentsY()

	local desc = vgui.Create( "DLabel", entry )
	desc:Dock( TOP )
	desc:DockMargin( 0, HUD.S( 2 ), pad, 0 )
	desc:SetFont( "gr_hud_small" )
	desc:SetTextColor( C.text )
	desc:SetWrap( true )
	desc:SetAutoStretchVertical( true )
	desc:SetText( f.Description )

	local info = vgui.Create( "DLabel", entry )
	info:Dock( TOP )
	info:DockMargin( 0, HUD.S( 4 ), 0, 0 )
	info:SetFont( "gr_hud_small" )
	info:SetTextColor( C.dim )
	info:SizeToContentsY()

	local why = vgui.Create( "DLabel", entry )
	why:Dock( TOP )
	why:SetFont( "gr_hud_small" )
	why:SetTextColor( C.blood )
	why:SetWrap( true )
	why:SetAutoStretchVertical( true )

	local col = f.Color or C.text
	local nextCheck = 0
	entry.Paint = function( self, w, h )
		draw.RoundedBox( 4, 0, 0, w, h, take:IsEnabled() and C.panel or C.back )
		surface.SetDrawColor( col )
		surface.DrawRect( 0, 0, HUD.S( 3 ), h )
	end
	entry.Think = function( self )
		if RealTime() < nextCheck then return end
		nextCheck = RealTime() + 0.25
		local ply = LocalPlayer()
		local ok, reason = Fates.CanTake( ply, f.id )
		take:SetEnabled( ok )
		name:SetTextColor( ok and col or C.dim )
		info:SetText( infoText( ply, f ) )
		why:SetText( ok and "" or reason or "" )
		-- Wrapped labels stretch on their own; the entry is as tall as what it holds.
		local h = pad * 2 + name:GetTall() + HUD.S( 2 ) + desc:GetTall() + HUD.S( 4 ) + info:GetTall()
		if not ok then h = h + why:GetTall() end
		why:SetVisible( not ok )
		self:SetTall( math.max( h, HUD.S( 60 ) ) )
	end
	entry:Think()
end

local function open()
	close()
	local ply = LocalPlayer()
	frame = vgui.Create( "DFrame" )
	frame:SetTitle( "" )
	frame:SetSize( math.min( HUD.S( 620 ), ScrW() - 40 ), math.min( HUD.S( 720 ), ScrH() - 40 ) )
	frame:Center()
	frame:MakePopup()
	frame:SetKeyboardInputEnabled( false )
	frame:DockPadding( HUD.S( 14 ), HUD.S( 34 ), HUD.S( 14 ), HUD.S( 14 ) )
	frame.Paint = function( self, w, h )
		draw.RoundedBox( 6, 0, 0, w, h, C.back )
		draw.SimpleText( "A Purpose in Life", "gr_hud", HUD.S( 14 ), HUD.S( 8 ), C.text )
		draw.SimpleText( string.format( "%d stem cells    %s", ply:GetStemCells(), Rank.Name( ply:GetRank() ) ),
			"gr_hud_small", w - HUD.S( 40 ), HUD.S( 10 ), C.dim, TEXT_ALIGN_RIGHT )
	end
	local baseThink = frame.Think
	frame.Think = function( self )
		-- Taking a fate (or being revived) ends the menu's purpose.
		if not ply:IsGhost() then
			self:Remove()
			return
		end
		baseThink( self )
	end

	local hint = vgui.Create( "DLabel", frame )
	hint:Dock( BOTTOM )
	hint:DockMargin( 0, HUD.S( 8 ), 0, 0 )
	hint:SetFont( "gr_hud_small" )
	hint:SetTextColor( C.dim )
	hint:SetText( "F2 closes and reopens this. F1 explains how to live." )
	hint:SizeToContentsY()

	local list = vgui.Create( "DScrollPanel", frame )
	list:Dock( FILL )
	for _, f in ipairs( Fates.All() ) do
		if f.index ~= FATE_GHOST then addEntry( list, f ) end
	end
end

local function toggle()
	if IsValid( frame ) then
		close()
	elseif LocalPlayer():IsGhost() then
		open()
	else
		chat.AddText( C.dim, "Only the dead choose a purpose." )
	end
end

concommand.Add( "gr_fates", toggle )

hook.Add( "PlayerBindPress", "gr_fates", function( _, bind, pressed )
	if pressed and string.find( bind, "gm_showteam", 1, true ) then
		toggle()
		return true
	end
end )

-- Open on becoming a ghost, and once after joining (everyone joins as one).
hook.Add( "GR_StateChanged", "gr_fates", function( idx, name, v )
	local me = LocalPlayer()
	if name == "Fate" and v == FATE_GHOST and IsValid( me ) and idx == me:EntIndex() then open() end
end )

local joinedAt
hook.Add( "Think", "gr_fates_join", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) then return end
	joinedAt = joinedAt or RealTime()
	if RealTime() - joinedAt < 3 then return end
	hook.Remove( "Think", "gr_fates_join" )
	if ply:IsGhost() and ply:Alive() and not IsValid( frame ) then open() end
end )
