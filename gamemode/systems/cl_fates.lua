-- The fate menu (F2 or `gr_fates`), ported from the original's potentials/sh_fatemenu.lua:
-- a 691 x 835 "To dwell is to suffer" frame, the ALL / NEUTRAL / EVIL / LOYAL tabs over a
-- backdrop, and one 680 x 96 row per fate with "Name — N STEM CELLS" and an ENVISION button.
-- The original listed potentials in the world; the remake lists every fate a ghost could take.
-- ENVISION is disabled, with Fates.CanTake's reason as its tooltip (the same check the server
-- runs, R7), and sends gr_take_fate; the server checks again (Fates.Request in core/sh_fates.lua).
-- Opens by itself on becoming a ghost and once after joining (everyone joins as one).
local frame
local tab = 1
local TABS = {
	{ "ALL", nil, "All of the potential this world has to offer." },
	{ "NEUTRAL", Color( 200, 200, 75 ), "Men only looking out for their own good, be it for better or worse." },
	{ "EVIL", Color( 250, 75, 75 ), "An antagonistic force who, one way or another, seeks to murder GANGRENE." },
	{ "LOYAL", Color( 75, 75, 250 ), "Souls loyal to the city of GANGRENE, ready to give their lives for it's existence." },
}

-- Which tab a fate sits under: a fate's own MenuType, else the law and the Kaiser are LOYAL.
local function category( f )
	if f.MenuType then return f.MenuType end
	if f.Police or f.Kaiser or f.id == "kaiser" then return 4 end
	return 2
end

local function close()
	if IsValid( frame ) then frame:Remove() end
end

local function costText( f )
	local cost = f.Cost or 0
	if cost == 0 or not Config.FateCosts then return "FREE" end
	return cost .. " STEM CELLS"
end

local function addRow( pane, f, y )
	local F_SMALL, F_MEDIUM = HUD.Font( "LabelSmall" ), HUD.Font( "LabelMedium" )
	local row = vgui.Create( "DPanel" )
	row:SetPos( 0, y )
	row:SetSize( 680, 96 )
	row.Paint = function( _, w, h )
		surface.SetDrawColor( 0, 0, 0, 70 )
		surface.DrawRect( 0, 0, w, h )
		surface.SetDrawColor( 0, 0, 0, 100 )
		surface.DrawOutlinedRect( 0, 0, w, h )
	end

	local name = HUD.Label( row, f.Name .. " — " .. costText( f ), F_MEDIUM, 10, 5, f.Color or Color( 255, 0, 0 ) )
	local d = HUD.FormatLine( f.MenuDescription or f.Description or "", F_SMALL, 480 )
	HUD.Label( row, d, F_SMALL, 10, 29 )

	local take = vgui.Create( "DButton", row )
	take:SetFont( F_SMALL )
	take:SetText( "ENVISION" )
	take:SetPos( 540, 25 )
	take:SetSize( 128, 42 )
	take.DoClick = function()
		net.Start( "gr_take_fate" )
		net.WriteString( f.id )
		net.SendToServer()
	end

	local nextCheck = 0
	row.Think = function()
		if RealTime() < nextCheck then return end
		nextCheck = RealTime() + 0.25
		local ply = LocalPlayer()
		local ok, reason = Fates.CanTake( ply, f.id )
		take:SetEnabled( ok )
		local wait = ply[ "GetCooldown_" .. f.id ]( ply ) - CurTime()
		take:SetText( wait > 0 and not ok and ( math.ceil( wait ) .. "s" ) or "ENVISION" )
		take:SetTooltip( ok and ( f.Tooltip or false ) or reason or false )
		name:SetText( f.Name .. " — " .. costText( f ) )
		name:SizeToContents()
	end
	row:Think()
	pane:AddItem( row )
end

local function open()
	close()
	local fates = {}
	for _, f in ipairs( Fates.All() ) do
		if f.index ~= FATE_GHOST and ( tab == 1 or category( f ) == tab ) then table.insert( fates, f ) end
	end

	frame = HUD.Frame( 691, 835, "To dwell is to suffer" )
	local ply = LocalPlayer()
	local baseThink = frame.Think
	frame.Think = function( self )
		-- Taking a fate (or being revived) ends the menu's purpose.
		if not ply:IsGhost() then
			self:Remove()
			return
		end
		baseThink( self )
	end

	local any = 0
	for _, f in ipairs( Fates.All() ) do
		if f.index ~= FATE_GHOST then any = any + 1 end
	end
	if any == 0 then
		HUD.Label( frame, "THERE IS NO POTENTIAL IN THIS WORLD", HUD.Font( "LabelGiant" ), 20, 30 )
	else
		HUD.Label( frame, "I BESTOW UPON YOU THESE FATES", HUD.Font( "LabelGiant" ), 70, 30 )
	end

	local buttons = vgui.Create( "DPanel", frame )
	buttons:SetSize( 691, 55 )
	buttons:SetPos( 0, 75 )
	buttons.Paint = function( _, w, h )
		surface.SetDrawColor( 0, 0, 0, 70 )
		surface.DrawRect( 0, 0, w, h )
		surface.SetDrawColor( 0, 0, 0, 100 )
		surface.DrawOutlinedRect( 0, 0, w, h )
	end
	for i, t in ipairs( TABS ) do
		local b = vgui.Create( "DButton", buttons )
		b:SetFont( HUD.Font( "LabelSmall" ) )
		b:SetText( t[ 1 ] )
		if t[ 2 ] then b:SetColor( t[ 2 ] ) end
		b:SetTooltip( t[ 3 ] )
		b:SetPos( ( i - 1 ) * 172, 0 )
		b:SetSize( 172, 55 )
		b:SetEnabled( i ~= tab )
		b.DoClick = function()
			tab = i
			open()
		end
	end

	local pane = vgui.Create( "DScrollPanel", frame )
	pane:SetSize( 700, 700 )
	pane:SetPos( 0, 134 )
	local backdrop = "fm" .. tab
	pane.Paint = function( _, w, h )
		surface.SetDrawColor( 30, 30, 30, 255 )
		surface.DrawRect( 0, 0, w, h )
		surface.SetDrawColor( 20, 20, 20, 100 )
		surface.DrawOutlinedRect( 0, 0, w, h )
		local mat = HUD.Mat( backdrop )
		if mat then
			surface.SetDrawColor( 255, 255, 255, 100 )
			surface.SetMaterial( mat )
			surface.DrawTexturedRect( 0, 0, w, h )
		end
	end

	if #fates == 0 then
		HUD.Label( pane, "THE ENDLESS EMPTY", HUD.Font( "LabelStupid" ), 75, 300 )
	end
	local y = 0
	for _, f in ipairs( fates ) do
		addRow( pane, f, y )
		y = y + 101
	end
end

local function toggle()
	if IsValid( frame ) then
		close()
	elseif LocalPlayer():IsGhost() then
		open()
	else
		HUD.Notify( "Only the dead choose a purpose.", Color( 200, 0, 0 ) )
	end
end

concommand.Add( "gr_fates", toggle )

hook.Add( "PlayerBindPress", "gr_fates", function( _, bind, pressed )
	if pressed and string.find( bind, "gm_showteam", 1, true ) then
		toggle()
		return true
	end
end )

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
