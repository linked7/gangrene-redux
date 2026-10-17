-- Stockpile ports (stockpile_port): a buy/sell menu opened with E, styled after the original
-- capitalist_public. Every port shares the one stockpile and treasury. Small goods (beer, spirits)
-- sell back at their buy price and raise the stock; crates only go to the main stockpile.
-- Prices go to the treasury through Econ.Transfer( "shop" ). Stock is world state "stock.<id>",
-- the same counter as the stockpile: the ration sells down to reserve.ration under ration_limit,
-- the knife is seeded with shop_stock at round start; beer and spirits start at 0.
-- StockpileAccess holders take shop goods for free.
Shop = Shop or {}
Shop.RANGE = 100
Shop.CLASS = "stockpile_port"
Shop.SOUNDS = { "placenta/coinkeeper1.wav", "placenta/coinkeeper2.wav", "placenta/coinkeeper3.wav", "placenta/coinkeeper4.wav" }

Items.Define( "fear_beer", {
	Name = "Fear Beer",
	Description = "Brewed in a bathtub. It drowns the dread, a little.",
	Weight = 1,
	Model = "models/props_junk/garbage_glassbottle003a.mdl",
	Effects = { Despair = -15 },
} )

Items.Define( "spirits", {
	Name = "Spirits",
	Description = "Clear, strong and nameless.",
	Weight = 1,
	Model = "models/props_junk/glassjug01.mdl",
	Effects = { Despair = -40 },
} )

-- In menu order. `kind` picks the icon outline, as in the original.
Shop.LIST = {
	{ id = "ration", name = "Soylent Loaf", kind = "food", price = function() return Econ.Setting( "sell.ration" ) end },
	{ id = "fear_beer", kind = "booze", price = 35, sellable = true },
	{ id = "spirits", kind = "booze", price = 85, sellable = true },
	{ id = "knife", kind = "weapon", price = 40 },
}
local byId = {}
for _, e in ipairs( Shop.LIST ) do byId[ e.id ] = e end

function Shop.Entry( id ) return byId[ id ] end
function Shop.Price( id )
	local e = byId[ id ]
	if not e then return nil end
	return isfunction( e.price ) and e.price() or e.price
end
function Shop.Name( id )
	local e = byId[ id ]
	return e and ( e.name or Items.Get( id ).Name ) or id
end
-- What can be bought now: the ration keeps its reserve back.
function Shop.Available( id )
	local floor = id == "ration" and Econ.Setting( "reserve.ration" ) or 0
	return math.max( Econ.Stock( id ) - floor, 0 )
end
-- The entries the menu shows: anything with nothing to sell is left off.
function Shop.Listed()
	local out = {}
	for _, e in ipairs( Shop.LIST ) do
		if Shop.Available( e.id ) > 0 then table.insert( out, e ) end
	end
	return out
end

if SERVER then
	CreateConVar( "shop_stock", "10", FCVAR_ARCHIVE, "Knives seeded into the stockpile at round start" )
	Net.Pool( "nShopOpen" )
	Net.Pool( "nShopBuy" )
	Net.Pool( "nShopSell" )

	-- Econ.ResetRound zeroes the stockpile goods; the shop's own goods are seeded here.
	hook.Add( "GR_EconReset", "GR_Shop", function()
		local n = GetConVar( "shop_stock" ):GetInt()
		for _, e in ipairs( Shop.LIST ) do
			if e.id ~= "ration" then WorldState.Set( "stock." .. e.id, e.id == "knife" and n or 0 ) end
		end
		Shop.purchases = {}
	end )

	function Shop.Open( ply, ent )
		ent:EmitSound( "ambient/machines/combine_terminal_idle" .. math.random( 1, 4 ) .. ".wav" )
		net.Start( "nShopOpen" )
		net.WriteEntity( ent )
		net.Send( ply )
	end

	-- The ration limit counts shop rations on their own window (Econ.LIMIT_WINDOW).
	Shop.purchases = Shop.purchases or {}
	local function recentRations( ply )
		local key, since, kept = DB.Key( ply ), CurTime() - Econ.LIMIT_WINDOW, {}
		for _, t in ipairs( Shop.purchases[ key ] or {} ) do
			if t >= since then table.insert( kept, t ) end
		end
		Shop.purchases[ key ] = kept
		return kept
	end

	-- Returns ok, and a reason when refused (already told to the player).
	function Shop.Buy( ply, ent, id )
		local function refuse( why ) Notify( ply, why ) return false, why end
		local e = byId[ id ]
		if not e then return refuse( "The shop doesn't sell that." ) end
		if Shop.Available( id ) <= 0 then return refuse( "Sold out." ) end

		local free = ply:FateHas( "StockpileAccess" )
		local bought
		if id == "ration" and not free then
			local limit = Econ.Setting( "ration_limit" )
			bought = recentRations( ply )
			if limit > 0 and #bought >= limit then return refuse( "You have bought your share. Come back later." ) end
		end
		local price = Shop.Price( id )
		if not free and not Econ.Transfer( ply, Econ.TREASURY, price, "shop" ) then
			return refuse( string.format( "You can't afford that. It costs %d bones.", price ) )
		end
		if bought then table.insert( bought, CurTime() ) end
		WorldState.Set( "stock." .. id, Econ.Stock( id ) - 1 )

		local fwd = ent:GetForward()
		fwd.z = 0
		fwd:Normalize()
		Items.Spawn( id, 1, ent:GetPos() + fwd * 30 + Vector( 0, 0, 40 ), Angle( 0, ent:GetAngles().y, 0 ) )
		ent:EmitSound( Shop.SOUNDS[ math.random( #Shop.SOUNDS ) ] )
		return true
	end

	-- `ply` sells one small good from their inventory at its buy price; the stock goes up.
	function Shop.Sell( ply, ent, id )
		local function refuse( why ) Notify( ply, why ) return false, why end
		local e = byId[ id ]
		if not e or not e.sellable then return refuse( "The port only takes beer and spirits. Crates go to the stockpile." ) end
		if Inventory.Count( ply, id ) <= 0 then return refuse( "You have none to sell." ) end
		local price = Shop.Price( id )
		if Econ.Treasury() < price then return refuse( "The treasury is empty." ) end
		if not Inventory.Remove( ply, id, 1 ) then return refuse( "You have none to sell." ) end
		if not Econ.Transfer( Econ.TREASURY, ply, price, "shop" ) then
			Inventory.Add( ply, id, 1 )
			return refuse( "The treasury is empty." )
		end
		WorldState.Set( "stock." .. id, Econ.Stock( id ) + 1 )
		ent:EmitSound( Shop.SOUNDS[ math.random( #Shop.SOUNDS ) ] )
		return true
	end

	Net.Receive( "nShopBuy", { rate = 2, alive = true, target = "entity", range = Shop.RANGE }, function( ply, ent )
		if ent:GetClass() ~= Shop.CLASS then return end
		Shop.Buy( ply, ent, net.ReadString() )
	end )
	Net.Receive( "nShopSell", { rate = 2, alive = true, target = "entity", range = Shop.RANGE }, function( ply, ent )
		if ent:GetClass() ~= Shop.CLASS then return end
		Shop.Sell( ply, ent, net.ReadString() )
	end )
	return
end

-- Client: the menu ------------------------------------------------------------------------
local OUTLINE = { food = Color( 200, 200, 0 ), weapon = Color( 150, 150, 255 ), booze = Color( 165, 42, 42 ) }

local menu
Net.Receive( "nShopOpen", nil, function()
	local ent = net.ReadEntity()
	if not IsValid( ent ) then return end
	if IsValid( menu ) then menu:Remove() end
	local W, H = 800, 500
	menu = vgui.Create( "DFrame" )
	menu:SetSize( W, H )
	menu:Center()
	menu:SetTitle( "Stockpile Port" )
	menu.PerformLayout = HUD.FrameLayout
	menu:MakePopup()
	surface.PlaySound( HUD.Sound( "menu_open" ) )

	local bones = vgui.Create( "DLabel", menu )
	bones:SetPos( 12, 30 )
	bones:SetFont( HUD.Font( "LabelMedium" ) )
	bones:SetTextColor( Color( 200, 200, 0 ) )
	function bones:Think() self:SetText( "You currently possess " .. LocalPlayer():GetBones() .. " Bones." ) self:SizeToContents() end

	local pane = vgui.Create( "DScrollPanel", menu )
	pane:SetPos( 10, 106 )
	pane:SetSize( 400, H - 156 )
	function pane:Paint( w, h )
		surface.SetDrawColor( 0, 0, 0, 70 ) surface.DrawRect( 0, 0, w, h )
		surface.SetDrawColor( 0, 0, 0, 100 ) surface.DrawOutlinedRect( 0, 0, w, h )
	end

	local mdl = vgui.Create( "DModelPanel", menu )
	mdl:SetPos( 420, 30 )
	mdl:SetSize( W - 430, 190 )
	local title = vgui.Create( "DLabel", menu )
	title:SetPos( 420, 220 )
	title:SetFont( HUD.Font( "LabelMedium" ) )
	local desc = vgui.Create( "DLabel", menu )
	desc:SetPos( 420, 250 )
	desc:SetSize( W - 430, 120 )
	desc:SetFont( HUD.Font( "LabelSmall" ) )
	desc:SetWrap( true )
	desc:SetContentAlignment( 7 )
	local cost, stock, weight = vgui.Create( "DLabel", menu ), vgui.Create( "DLabel", menu ), vgui.Create( "DLabel", menu )
	for i, l in ipairs( { cost, stock, weight } ) do
		l:SetPos( 420, H - 90 + i * 20 - 20 )
		l:SetFont( HUD.Font( "LabelSmall" ) )
		l:SetText( "" )
	end
	cost:SetTextColor( Color( 200, 0, 0 ) )
	stock:SetTextColor( Color( 200, 200, 0 ) )

	local selected
	local function show( id )
		selected = id
		local def = Items.Get( id )
		mdl:SetVisible( true )
		mdl:SetModel( def.Model )
		local mn, mx = mdl.Entity:GetRenderBounds()
		local size = math.max( mx:Distance( mn ), 1 )
		mdl:SetCamPos( Vector( size, size, size * 0.5 ) )
		mdl:SetLookAt( ( mn + mx ) / 2 )
		title:SetText( Shop.Name( id ) ) title:SizeToContents()
		desc:SetText( def.Description or "" )
		weight:SetText( "Weight: " .. def.Weight ) weight:SizeToContents()
	end
	local listed
	local function rebuild()
		pane:Clear()
		local ids = {}
		local x, y = 4, 4
		for _, e in ipairs( Shop.Listed() ) do
			table.insert( ids, e.id )
			local def = Items.Get( e.id )
			local icon = vgui.Create( "SpawnIcon", pane )
			icon:SetPos( x, y )
			icon:SetSize( 48, 48 )
			icon:SetModel( def.Model )
			icon:SetTooltip( Shop.Name( e.id ) )
			local col = OUTLINE[ e.kind ]
			function icon:PaintOver( w, h )
				surface.SetDrawColor( col ) surface.DrawOutlinedRect( 0, 0, w, h )
			end
			function icon:DoClick()
				surface.PlaySound( "ambient/machines/keyboard" .. math.random( 1, 6 ) .. "_clicks.wav" )
				show( e.id )
			end
			x = x + 52
			if x + 48 > 396 then x, y = 4, y + 52 end
		end
		listed = table.concat( ids, "," )
		if selected and Shop.Available( selected ) > 0 then return end
		if ids[ 1 ] then return show( ids[ 1 ] ) end
		-- Sold out of everything.
		selected = nil
		mdl:SetVisible( false )
		title:SetText( "Nothing in stock." ) title:SizeToContents()
		for _, l in ipairs( { desc, cost, stock, weight } ) do l:SetText( "" ) end
	end

	function menu:Think()
		if not IsValid( ent ) then return self:Remove() end
		-- Stock is world state, so re-list whenever what's available changes.
		local now = {}
		for _, e in ipairs( Shop.Listed() ) do table.insert( now, e.id ) end
		if table.concat( now, "," ) ~= listed then rebuild() end
		if not selected then return end
		cost:SetText( "Costs: " .. Shop.Price( selected ) .. " Bones" ) cost:SizeToContents()
		stock:SetText( "Available stock: " .. Shop.Available( selected ) ) stock:SizeToContents()
	end

	rebuild()

	local order = vgui.Create( "DButton", menu )
	order:SetSize( 100, 20 )
	order:SetPos( W - 110, H - 30 )
	order:SetText( "ORDER IT" )
	function order:DoClick()
		if not selected then return end
		net.Start( "nShopBuy" )
		net.WriteEntity( ent )
		net.WriteString( selected )
		net.SendToServer()
		surface.PlaySound( "ambient/machines/keyboard7_clicks_enter.wav" )
		menu:Close()
	end

	-- Selling: one button per small good the player carries.
	local x = 10
	for _, e in ipairs( Shop.LIST ) do
		if e.sellable then
			local sell = vgui.Create( "DButton", menu )
			sell:SetSize( 150, 20 )
			sell:SetPos( x, H - 30 )
			x = x + 160
			function sell:Think()
				local n = Inventory.Count( LocalPlayer(), e.id )
				self:SetText( string.format( "SELL %s (%d) +%d", Shop.Name( e.id ), n, Shop.Price( e.id ) ) )
				self:SetEnabled( n > 0 )
			end
			function sell:DoClick()
				net.Start( "nShopSell" )
				net.WriteEntity( ent )
				net.WriteString( e.id )
				net.SendToServer()
				surface.PlaySound( "ambient/machines/keyboard7_clicks_enter.wav" )
			end
		end
	end
end )
