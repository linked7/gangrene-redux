-- The F3 player menu, ported from the original's gui/cl_playermenu.lua: the player's belongings
-- orbit their body on an ellipse (left click uses, right click drops), the name over a gradient,
-- the capacity bar, "i have N Bones in my body" / "N Stem Cells in my brain", and the burden bars
-- down the left, all under the hand cursor and a background blur (cl_hud.lua's menu blur layer).
-- F3 (gm_showspare1), `gr_inventory` or /inv opens it. It reads Inventory.Local and State fields
-- and sends requests; the server decides everything.
--
-- Where the remake's extra status went: Injured and a lodged bullet are burden rows like the
-- original's statuses. Ghosts and the dead get "You have N stem cells." instead of the menu.
local menu
local UI = Config.UI

local handFrame, nextHandFrame, handAnimation = 1, 0, false
local function handMat()
	local now = CurTime()
	if now > nextHandFrame and ( handAnimation or handFrame > 1 ) then
		nextHandFrame = now + 0.2
		handFrame = handFrame + 1
		if handFrame >= #UI.HandFrames then handFrame = 1 end
	end
	return HUD.Mat( UI.HandFrames[ handFrame ] )
end

local function drawCursor( panel, mat )
	mat = mat or handMat()
	if not mat then return end
	local x, y = panel:LocalCursorPos()
	surface.SetDrawColor( 255, 255, 255, 240 )
	surface.SetMaterial( mat )
	surface.DrawTexturedRect( x, y, 32, 32 )
end

-- The burdens, in the original's order, plus the remake's injuries.
local function need( ply, name )
	local get = ply[ "GetNeed_" .. name ]
	return get and get( ply ) or 0
end
local BURDENS = {
	function( ply, t ) local v = need( ply, "Pox" ) if v > 5 then return "pox", v / 100, Color( 100 + math.max( 0, 56 * math.sin( t ) ), 100 + math.max( 0, 56 * math.sin( t ) ), 0 ) end end,
	function( ply, t ) local v = need( ply, "Despair" ) local g = 128 + 64 * math.sin( t ) if v > 5 then return "despair", v / 100, Color( g, g, g ) end end,
	function( ply, t ) local v = need( ply, "Emptiness" ) if v > 5 then return "emptiness", v / 100, Color( 0, 128 + 64 * math.sin( t ), 0 ) end end,
	function( ply, t ) local v = need( ply, "Dryness" ) if v > 5 then return "dryness", v / 100, Color( 0, 128 + 64 * math.sin( t ), 128 + 64 * math.sin( t ) ) end end,
	function( ply, t ) if ply:GetInjured() then return "injured", 1, Color( 128 + 64 * math.sin( t ), 0, 0 ) end end,
	function( ply, t ) if ply:GetBullet() then return "bullet lodged", 1, Color( 100 + 50 * math.sin( t ), 100, 100 ) end end,
}

local function close()
	if not IsValid( menu ) then return end
	menu:Remove()
	menu = nil
	HUD.PlayerMenu = nil
	surface.PlaySound( HUD.Sound( "menu_close" ) )
	gui.HideGameUI()
end

local function iconCam( icon, def )
	if def.LookAt then
		icon:SetFOV( ( def.FOV or 30 ) / 1.5 )
		icon:SetCamPos( def.CamPos )
		icon:SetLookAt( def.LookAt )
	elseif IsValid( icon.Entity ) then
		local a, b = icon.Entity:GetModelBounds()
		icon:SetFOV( 10 )
		icon:SetCamPos( Vector( math.abs( a.x ), math.abs( a.y ), math.abs( a.z ) ) * 5 )
		icon:SetLookAt( ( a + b ) / 2 )
	end
end

local function buildIcons()
	if not IsValid( menu ) then return end
	for _, v in ipairs( menu.Icons or {} ) do
		if IsValid( v ) then v:Remove() end
	end
	menu.Icons = {}
	local ids = table.GetKeys( Inventory.Local.items )
	table.sort( ids, function( a, b ) return Items.Get( a ).index < Items.Get( b ).index end )
	for _, id in ipairs( ids ) do
		local def = Items.Get( id )
		local icon = vgui.Create( "DModelPanel", menu.Content )
		icon.Item = id
		icon.Amount = Inventory.Local.items[ id ]
		icon:SetModel( def.Model or "models/props_junk/cardboard_box004a.mdl" )
		icon:SetSize( 64, 64 )
		if HUD.Mat( UI.HandFrames[ 1 ] ) then icon:SetCursor( "blank" ) end
		if def.Skin and IsValid( icon.Entity ) then icon.Entity:SetSkin( def.Skin ) end
		iconCam( icon, def )
		icon:SetDrawOnTop( true )
		icon.DoClick = function() Inventory.RequestUse( id ) end
		icon.DoRightClick = function() Inventory.RequestDrop( id, 1 ) end
		icon.PaintOver = function( self ) drawCursor( self ) end
		table.insert( menu.Icons, icon )
	end
end

local function build()
	local ply = LocalPlayer()
	local W, H = ScrW(), ScrH()
	local F_MEDIUM, F_BIG, F_GIANT = HUD.Font( "LabelMedium" ), HUD.Font( "LabelBig" ), HUD.Font( "LabelGiant" )
	local hasHand = HUD.Mat( UI.HandFrames[ 1 ] ) ~= nil

	menu = vgui.Create( "DFrame" )
	HUD.PlayerMenu = menu
	menu:SetSize( W, H )
	menu:SetPos( 0, 0 )
	menu:SetTitle( "" )
	menu:SetDraggable( false )
	menu:ShowCloseButton( false )
	menu.PerformLayout = HUD.FrameLayout
	menu:MakePopup()
	if hasHand then menu:SetCursor( "blank" ) end
	surface.PlaySound( HUD.Sound( "menu_open" ) )

	menu.Content = vgui.Create( "DPanel", menu )
	menu.Content:SetPos( 0, 0 )
	menu.Content:SetSize( W, H )
	if hasHand then menu.Content:SetCursor( "blank" ) end
	menu.Content.Paint = function( self ) drawCursor( self ) end

	-- The body: a 200 x 500 model at FOV 25; clicking it hurts.
	local model = vgui.Create( "DModelPanel", menu.Content )
	model:SetModel( ply:GetModel() )
	model:SetSize( 200, 500 )
	model:SetPos( W / 2 - 100, H / 5 )
	model:SetFOV( 25 )
	model:SetCamPos( Vector( 50, 0, 60 ) )
	model:SetLookAt( Vector( -80, 0, 10 ) )
	if hasHand then model:SetCursor( "blank" ) end
	if IsValid( model.Entity ) then
		model.Entity:SetSkin( ply:GetSkin() )
		for i = 0, ply:GetNumBodyGroups() - 1 do model.Entity:SetBodygroup( i, ply:GetBodygroup( i ) ) end
		model.Entity.GetPlayerColor = function() return IsValid( ply ) and ply:GetPlayerColor() or Vector( 1, 1, 1 ) end
	end
	model.LayoutEntity = function() end
	local fov = 35
	model.DoClick = function()
		local punches = { "npc/vort/foot_hit.wav", "weapons/crossbow/hitbod1.wav", "weapons/crossbow/hitbod2.wav" }
		surface.PlaySound( punches[ math.random( #punches ) ] )
		fov = 40
	end
	model.Think = function( self )
		if self:IsHovered() then handAnimation = true end
		fov = Lerp( 0.1, fov, 35 )
		self:SetFOV( fov )
	end
	model.PaintOver = function( self ) drawCursor( self ) end
	menu.Model = model

	-- The name, fading in blood red over the gradient.
	local name = vgui.Create( "DLabel", menu.Content )
	name:SetFont( F_GIANT )
	name.Alpha = 0
	name.Think = function( self )
		local txt = HUD.Stutter( ply:Nick() )
		self.Alpha = Lerp( 0.03, self.Alpha, 255 )
		self:SetTextColor( Color( 128 * self.Alpha / 255, 0, 0, self.Alpha ) )
		self:SetText( txt )
		surface.SetFont( F_GIANT )
		local tW, tH = surface.GetTextSize( txt )
		self:SetSize( tW, tH )
		self:SetPos( W / 2 - tW / 2, H / 6 )
	end
	name.Paint = function( self, w, h )
		local g = 64 + math.abs( 64 * math.sin( CurTime() ) )
		local grad = HUD.Mat( "gradient" )
		if grad then
			surface.SetDrawColor( g, g, g, self.Alpha )
			surface.SetMaterial( grad )
			surface.DrawTexturedRect( 0, 0, w, h )
		end
	end

	-- Burden bars down the left, at 0.2 W from 0.1 H.
	menu.StatusAlpha = 0
	local y = H * 0.1
	surface.SetFont( F_BIG )
	local _, rowH = surface.GetTextSize( "despair" )
	for i, burden in ipairs( BURDENS ) do
		local row = vgui.Create( "DPanel", menu.Content )
		y = y + rowH + 6
		row:SetPos( W * 0.2, y )
		row:SetSize( 200, rowH + 6 )
		row.Prog = nil
		row.Paint = function( self, w, h )
			local label, prog, col = burden( ply, CurTime() )
			if not label then return end
			menu.StatusAlpha = Lerp( 0.05, menu.StatusAlpha, 1 )
			local a = menu.StatusAlpha
			local scratch = HUD.Mat( "scratch" )
			if scratch then surface.SetMaterial( scratch ) else draw.NoTexture() end
			surface.SetDrawColor( 64, 64, 64, a * 128 )
			surface.DrawTexturedRect( 0, 0, w, h )
			self.Prog = Lerp( 0.05, self.Prog or prog, prog )
			surface.SetDrawColor( col.r, col.g, col.b, a * 255 )
			surface.DrawTexturedRect( 0, 0, w * self.Prog * a, h )
			surface.SetFont( F_BIG )
			local tW = surface.GetTextSize( label )
			surface.SetTextPos( w / 2 - tW / 2, 0 )
			surface.SetTextColor( 128, 0, 0, a * 255 )
			surface.DrawText( HUD.Stutter( label ) )
		end
		row.PaintOver = function( self ) drawCursor( self ) end
		if hasHand then row:SetCursor( "blank" ) end
	end

	menu.Paint = function( self )
		local t = CurTime()
		surface.SetFont( F_MEDIUM )
		for _, v in ipairs( self.Icons or {} ) do
			if IsValid( v ) then
				local def = Items.Get( v.Item )
				local n = def and def.Name or v.Item
				local tW = surface.GetTextSize( n )
				surface.SetTextPos( v:GetX() + v:GetWide() / 2 - tW / 2, v:GetY() - 24 )
				surface.SetTextColor( HSVToColor( ( t * 44 ) % 360, 1, 1 ) )
				surface.DrawText( HUD.Stutter( n ) )
				if v.Amount and v.Amount > 1 then
					surface.SetFont( F_BIG )
					local aW = surface.GetTextSize( tostring( v.Amount ) )
					surface.SetTextPos( v:GetX() + v:GetWide() / 2 - aW / 2, v:GetY() + 64 )
					surface.SetTextColor( HSVToColor( ( t * 66 ) % 360, 1, 1 ) )
					surface.DrawText( tostring( v.Amount ) )
					surface.SetFont( F_MEDIUM )
				end
			end
		end

		-- Capacity.
		local weight, limit = Inventory.Weight( ply ), math.max( Inventory.Limit( ply ), 0.01 )
		self.WeightPct = Lerp( 0.05, self.WeightPct or 0, weight / limit )
		local txt = string.format( "capacity - %g/%g - %d%%", math.Round( weight, 1 ), math.Round( limit, 1 ), math.ceil( self.WeightPct * 100 ) )
		local bx = W / 2 - 100 - 100 + 20 * math.sin( t )
		local scratch = HUD.Mat( "scratch" )
		if scratch then surface.SetMaterial( scratch ) else draw.NoTexture() end
		surface.SetDrawColor( 64, 64, 64, 128 )
		surface.DrawTexturedRect( bx, H * 0.65, 400, 40 )
		surface.SetDrawColor( 128 + 64 * math.sin( self.WeightPct > 1 and t * 3 or t ), 0, 0, 128 )
		surface.DrawTexturedRect( bx, H * 0.65, math.min( 400 * self.WeightPct, 400 ), 40 )
		surface.SetFont( F_MEDIUM )
		surface.SetTextPos( W / 2 - 100 + 20, H * 0.655 )
		surface.SetTextColor( 128, 128, 128 )
		surface.DrawText( HUD.Stutter( txt ) )

		local function line( s, yy, col, wave )
			local tW = surface.GetTextSize( s )
			surface.SetTextPos( W / 2 - tW / 2 + 30 * wave, yy )
			surface.SetTextColor( col )
			surface.DrawText( HUD.Stutter( s ) )
		end
		line( "i have " .. ply:GetBones() .. " Bones in my body", H * 0.725, Color( 0, 200, 0 ), math.cos( t ) )
		line( "i have " .. ply:GetStemCells() .. " Stem Cells in my brain", H * 0.745, Color( 0, 128, 0 ), math.sin( t ) )
		line( "i suffer less than others.", H * 0.2, Color( 128, 0, 0 ), math.cos( t ) )
	end

	-- Item descriptions follow the cursor while an icon is hovered.
	menu.Hover = { a = 0, t = "" }
	menu.PaintOver = function( self )
		local x, yy = self:CursorPos()
		local hovered
		for _, v in ipairs( self.Icons or {} ) do
			if IsValid( v ) and v:IsHovered() then hovered = v break end
		end
		if hovered then
			local def = Items.Get( hovered.Item )
			self.Hover.t = "Weight: " .. ( def.Weight or 0 ) .. "\n" .. ( def.Description or "" )
			self.Hover.a = Lerp( 0.05, self.Hover.a, 1 )
			yy = yy + 32
		elseif self.Hover.a > 0 then
			self.Hover.a = Lerp( 0.05, self.Hover.a, 0 )
		end
		if self.Hover.a < 0.01 then return end
		local col = HSVToColor( ( CurTime() * 38 ) % 360, 1, 1 )
		col.a = self.Hover.a * 255
		local g = 64 + math.abs( 64 * math.sin( CurTime() ) )
		local grad = HUD.Mat( "gradient" )
		surface.SetFont( F_MEDIUM )
		for _, s in ipairs( string.Explode( "\n", HUD.Stutter( self.Hover.t ) ) ) do
			local tW, tH = surface.GetTextSize( s )
			if grad then
				surface.SetDrawColor( g, g, g, col.a )
				surface.SetMaterial( grad )
				surface.DrawTexturedRect( math.max( 0, x - tW / 2 ), yy, tW, tH )
			end
			surface.SetTextColor( col )
			surface.SetTextPos( math.max( 0, x - tW / 2 ), yy )
			surface.DrawText( s )
			yy = yy + tH
		end
	end

	-- Orbit, and close on ESC / F3 or when the mouse leaves the middle of the screen.
	local opened, rot = CurTime(), 0
	menu.Think = function( self )
		if not ply:Alive() or ply:IsGhost() then return close() end
		if CurTime() >= opened + 0.2 then
			handAnimation = false
			local mx, my = gui.MouseX(), gui.MouseY()
			if input.IsKeyDown( KEY_ESCAPE ) or input.IsKeyDown( KEY_F3 ) or mx < W * 0.2 or my < H * 0.1 or mx > W * 0.8 or my > H * 0.9 then
				return close()
			end
		end
		local icons = self.Icons or {}
		local moused = false
		for _, v in ipairs( icons ) do
			if IsValid( v ) and v:IsHovered() then moused = true end
		end
		if moused then handAnimation = true else rot = rot + FrameTime() end
		if #icons == 0 or moused then return end
		local angle = rot * 0.25 % ( 2 * math.pi )
		local offset = 2 * math.pi / #icons
		for k, v in ipairs( icons ) do
			local a = angle + offset * ( k - 1 )
			v:SetPos( W / 2.05 - math.cos( a ) * W * 0.2, H / 2.15 - math.sin( a ) * H * 0.35 )
		end
	end

	buildIcons()
end

local function open()
	if IsValid( menu ) then return close() end
	local ply = LocalPlayer()
	if ply:IsGhost() or not ply:Alive() or ply:Health() <= 0 then
		chat.AddText( Color( 200, 0, 0 ), "You have " .. ply:GetStemCells() .. " stem cells." )
		return
	end
	if ply:FateHas( "NoInventory" ) then
		chat.AddText( Color( 200, 0, 0 ), "You have no soul or possessions." )
		return
	end
	build()
end

concommand.Add( "gr_inventory", open )
hook.Add( "PlayerBindPress", "gr_playermenu", function( _, bind, pressed )
	if pressed and string.find( bind, "gm_showspare1", 1, true ) then
		open()
		return true
	end
end )
hook.Add( "GR_InventoryChanged", "gr_inventory_panel", buildIcons )
