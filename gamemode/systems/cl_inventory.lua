-- A plain inventory window: `gr_inventory` in the console, or /inv in chat. Double-click uses
-- an item; the buttons use or drop the selected one. It only reads Inventory.Local and sends
-- requests; the server decides everything.
local frame

local function refresh()
	if not IsValid( frame ) then return end
	local list = frame.List
	local selected = list:GetSelectedLine() and list:GetLine( list:GetSelectedLine() ).ItemId
	list:Clear()

	local inv = Inventory.Local
	local ids = table.GetKeys( inv.items )
	table.sort( ids, function( a, b ) return Items.Get( a ).index < Items.Get( b ).index end )
	for _, id in ipairs( ids ) do
		local def = Items.Get( id )
		local n = inv.items[ id ]
		local line = list:AddLine( def.Name, n, string.format( "%.1f", def.Weight * n ) )
		line.ItemId = id
		line:SetTooltip( def.Description )
		if id == selected then line:SetSelected( true ) end
	end
	frame.Weight:SetText( string.format( "Carrying %.1f / %.1f", Inventory.Weight( LocalPlayer() ), Inventory.Limit( LocalPlayer() ) ) )
end

local function selectedId()
	local i = IsValid( frame ) and frame.List:GetSelectedLine()
	return i and frame.List:GetLine( i ).ItemId
end

local function open()
	if IsValid( frame ) then
		frame:Remove()
		return
	end
	frame = vgui.Create( "DFrame" )
	frame:SetTitle( "Belongings" )
	frame:SetSize( 340, 380 )
	frame:Center()
	frame:MakePopup()

	frame.Weight = vgui.Create( "DLabel", frame )
	frame.Weight:Dock( TOP )

	local buttons = vgui.Create( "DPanel", frame )
	buttons:Dock( BOTTOM )
	buttons:SetTall( 26 )
	buttons:SetPaintBackground( false )

	local use = vgui.Create( "DButton", buttons )
	use:SetText( "Use" )
	use:Dock( LEFT )
	use:SetWide( 150 )
	use.DoClick = function()
		local id = selectedId()
		if id then Inventory.RequestUse( id ) end
	end

	local drop = vgui.Create( "DButton", buttons )
	drop:SetText( "Drop" )
	drop:Dock( RIGHT )
	drop:SetWide( 150 )
	drop.DoClick = function()
		local id = selectedId()
		if id then Inventory.RequestDrop( id, 1 ) end
	end

	local list = vgui.Create( "DListView", frame )
	list:Dock( FILL )
	list:SetMultiSelect( false )
	list:AddColumn( "Item" )
	list:AddColumn( "Count" ):SetFixedWidth( 50 )
	list:AddColumn( "Weight" ):SetFixedWidth( 60 )
	list.DoDoubleClick = function( _, _, line ) Inventory.RequestUse( line.ItemId ) end
	frame.List = list

	refresh()
end

concommand.Add( "gr_inventory", open )
hook.Add( "GR_InventoryChanged", "gr_inventory_panel", refresh )
