-- The chat box, ported from the original's framework/chat/cl_chat.lua and gui/cl_ccchat.lua
-- (docs/05 §2, §5): the engine chat box is never shown. Lines fade in bottom left (x 12, from
-- ScrH() - 40 up, at most 9, gone after 10 s, stuttering while they fade) as HUD layer 140, and
-- messagemode opens a borderless full-width panel: All / LOCAL / OOC filter buttons, the history
-- and an entry (500 characters, ESC closes, an over-long message is kept for next time).
--
--   chat.AddText( ... )        lands here (colours, strings and players, as the engine's)
--   GR_ChatLine( mode, font, ... )   sh_chat's hook for its lines: the mode picks the filter
--                              (ooc, looc, pm and admin are OOC) and the font (ChatBig, ChatSmall,
--                              ChatRadio) replaces ChatNormal.
--   HUD.ChatOpen()             true while the panel is up
--
-- What is typed goes to the server as `say`, so sh_chat's PlayerSay parsing is the one path.
-- Lines are laid out (wrapped, per-colour runs) once when added and kept, so drawing them is
-- only SetTextPos / DrawText (docs/05 §6).
local CT = CurTime
local MAX_LINES, MAX_CHARS = 100, 500
local OOC = { ooc = true, looc = true, pm = true, admin = true }
local FILTER_ALL, FILTER_IC, FILTER_OOC = 1, 2, 3

local lines = {}
local filter = FILTER_ALL
local panel, pending

local function width() return math.min( ScreenScale( 419 ), ScrW() - 40 ) end

-- Splits runs of { col, text } into rows no wider than `w` in `font`, word by word.
local function layout( runs, font, w )
	surface.SetFont( font )
	local rows, row, x = {}, {}, 0
	local _, lineH = surface.GetTextSize( "W" )
	local function newRow()
		table.insert( rows, row )
		row, x = {}, 0
	end
	for _, r in ipairs( runs ) do
		if string.find( r.text, "^%s+$" ) then x = x + surface.GetTextSize( r.text ) end
		for word in string.gmatch( r.text, "%s*%S+%s*" ) do
			local tw = surface.GetTextSize( word )
			if x > 0 and x + tw > w then newRow() end
			table.insert( row, { x = x, text = word, col = r.col } )
			x = x + tw
		end
	end
	if #row > 0 or #rows == 0 then table.insert( rows, row ) end
	return rows, lineH
end

local function add( mode, font, ... )
	local runs, col, plain = {}, Color( 200, 200, 200 ), {}
	for _, v in ipairs( { ... } ) do
		if istable( v ) and v.r and v.g and v.b then
			col = Color( v.r, v.g, v.b )
			table.insert( plain, col )
		elseif type( v ) == "Player" then
			local name = IsValid( v ) and v:Nick() or "?"
			table.insert( runs, { col = col, text = name } )
			table.insert( plain, name )
		elseif v ~= nil then
			table.insert( runs, { col = col, text = tostring( v ) } )
			table.insert( plain, tostring( v ) )
		end
	end
	table.insert( plain, "\n" )
	MsgC( unpack( plain ) )
	local f = HUD.Font( font or "ChatNormal" )
	local rows, h = layout( runs, f, width() )
	table.insert( lines, { at = CT(), font = f, rows = rows, h = h, ooc = mode and OOC[ mode ] or nil, ic = mode ~= nil and not OOC[ mode ] } )
	while #lines > MAX_LINES do table.remove( lines, 1 ) end
	if not system.HasFocus() then system.FlashWindow() end
end

local function shown( l )
	if filter == FILTER_IC then return not l.ooc end
	if filter == FILTER_OOC then return not l.ic end
	return true
end

chat.GR_EngineAddText = chat.GR_EngineAddText or chat.AddText
function chat.AddText( ... ) add( nil, nil, ... ) end

hook.Add( "GR_ChatLine", "gr_chatbox", function( mode, font, ... )
	add( mode, font, ... )
	return true
end )

hook.Add( "ChatText", "gr_chatbox", function() return true end )
hook.Add( "StartChat", "gr_chatbox", function() return true end )

-- Draws one laid-out line with its bottom at y; returns its height.
local function drawLine( l, x, y, alpha, scramble )
	local n = #l.rows
	local top = y - n * l.h
	surface.SetFont( l.font )
	for i, row in ipairs( l.rows ) do
		local ry = top + ( i - 1 ) * l.h
		for _, seg in ipairs( row ) do
			local t = scramble and HUD.Stutter( seg.text ) or seg.text
			surface.SetTextColor( 0, 0, 0, alpha )
			surface.SetTextPos( x + seg.x + 1, ry + 1 )
			surface.DrawText( t )
			surface.SetTextColor( seg.col.r, seg.col.g, seg.col.b, alpha )
			surface.SetTextPos( x + seg.x, ry )
			surface.DrawText( t )
		end
	end
	return n * l.h
end

function HUD.ChatOpen() return IsValid( panel ) end

HUD.Layer( 140, "chat", function()
	if IsValid( panel ) then return end
	local now, y, drawn = CT(), ScrH() - 40, 0
	for i = #lines, 1, -1 do
		local l = lines[ i ]
		local age = now - l.at
		if age >= 10 or drawn >= 9 then break end
		if shown( l ) then
			local amul = age < 5 and math.min( age, 1 ) or age < 9 and 1 or 1 - ( age - 9 )
			y = y - drawLine( l, 12, y, 255 * amul, amul < 1 )
			drawn = drawn + 1
		end
	end
end )

-- The panel ---------------------------------------------------------------------------------

local function close()
	if IsValid( panel ) then panel:Remove() end
	panel = nil
end

local function open()
	if IsValid( panel ) then return end
	local h = cookie.GetNumber( "cc_chatheight", 300 )
	local p = vgui.Create( "EditablePanel" )
	panel = p
	p:SetSize( ScrW(), h )
	p:SetPos( 0, ScrH() - h )
	p:MakePopup()
	p.Paint = function() return true end
	p.Think = function( self )
		if input.IsKeyDown( KEY_ESCAPE ) then
			close()
			gui.HideGameUI()
		end
	end

	local scroll = vgui.Create( "DScrollPanel", p )
	scroll:SetPos( 10, 40 )
	scroll:SetSize( ScrW() - 20, h - 80 )
	scroll.Paint = function() end
	local content = vgui.Create( "EditablePanel" )
	content:SetSize( ScrW() - 20, 20 )
	content.Paint = function( self, pw, ph )
		local total = 0
		for _, l in ipairs( lines ) do
			if shown( l ) then total = total + #l.rows * l.h end
		end
		local y = 0
		for _, l in ipairs( lines ) do
			if shown( l ) then y = y + drawLine( l, 2, y + #l.rows * l.h, 255, false ) end
		end
		if ph ~= math.max( total, 20 ) then
			self:SetTall( math.max( total, 20 ) )
			scroll:PerformLayout()
			if scroll.VBar then scroll.VBar:SetScroll( math.huge ) end
		end
	end
	scroll:AddItem( content )

	local entry = vgui.Create( "DTextEntry", p )
	entry:SetFont( HUD.Font( "ChatNormal" ) )
	entry:SetPos( 10, h - 30 )
	entry:SetSize( ScrW() - 20, 20 )
	entry.OnEnter = function( self )
		local text = self:GetValue() or ""
		if #text > MAX_CHARS then
			add( nil, nil, Color( 200, 0, 0 ), "The maximum chat length is " .. MAX_CHARS .. " characters. Your message was " .. #text .. " characters long." )
			pending = text
		elseif #text > 0 then
			RunConsoleCommand( "say", text )
			pending = nil
		else
			pending = nil
		end
		close()
	end
	if pending then entry:SetValue( pending ) pending = nil end
	entry:RequestFocus()
	entry:SetCaretPos( #entry:GetValue() )

	local buttons = {}
	local function button( label, x, which )
		local b = vgui.Create( "DButton", p )
		b:SetFont( HUD.Font( "LabelSmall" ) )
		b:SetText( label )
		b:SetPos( x, 15 )
		b:SetSize( 100, 20 )
		b:SetDisabled( filter == which )
		b.DoClick = function()
			filter = which
			for w, other in pairs( buttons ) do other:SetDisabled( w == which ) end
		end
		buttons[ which ] = b
	end
	button( "All", 0, FILTER_ALL )
	button( "LOCAL", 100, FILTER_IC )
	button( "OOC", 200, FILTER_OOC )
end

hook.Add( "PlayerBindPress", "gr_chatbox", function( _, bind, pressed )
	if pressed and string.find( bind, "messagemode", 1, true ) then
		open()
		return true
	end
end )
