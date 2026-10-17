-- The shop (gr_shop): a buy menu opened with E, styled after the original capitalist_public.
-- Prices go to the treasury through Econ.Transfer( "shop" ). Stock is world state "stock.<id>",
-- the same counter as the stockpile: the ration sells down to reserve.ration under ration_limit,
-- the rest are seeded with shop_stock at round start and stay gone once sold out.
-- StockpileAccess holders take shop goods for free.
Shop = Shop or {}
Shop.RANGE = 150
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

Items.Define( "knife", {
	Name = "Knife",
	Description = "A short kitchen knife.",
	Weight = 1,
	Model = "models/weapons/w_knife_t.mdl",
} )

-- In menu order. `kind` picks the icon outline, as in the original.
Shop.LIST = {
	{ id = "ration", name = "Soylent Loaf", kind = "food", price = function() return Econ.Setting( "sell.ration" ) end },
	{ id = "fear_beer", kind = "booze", price = 35 },
	{ id = "spirits", kind = "booze", price = 85 },
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

if SERVER then
	CreateConVar( "shop_stock", "10", FCVAR_ARCHIVE, "Shop goods (beer, spirits, knives) seeded at round start" )
	Net.Pool( "nShopOpen" )

	-- Econ.ResetRound zeroes the stockpile goods; the shop's own goods are seeded here.
	hook.Add( "GR_EconReset", "GR_Shop", function()
		local n = GetConVar( "shop_stock" ):GetInt()
		for _, e in ipairs( Shop.LIST ) do
			if e.id ~= "ration" then WorldState.Set( "stock." .. e.id, n ) end
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

		local fwd = ply:GetForward()
		fwd.z = 0
		fwd:Normalize()
		Items.Spawn( id, 1, ply:GetPos() + fwd * 40 + Vector( 0, 0, 40 ), Angle( 0, ply:EyeAngles().y, 0 ) )
		ent:EmitSound( Shop.SOUNDS[ math.random( #Shop.SOUNDS ) ] )
		return true
	end

	Net.Receive( "nShopBuy", { rate = 2, alive = true, target = "entity", range = Shop.RANGE }, function( ply, ent )
		if ent:GetClass() ~= "gr_shop" then return end
		Shop.Buy( ply, ent, net.ReadString() )
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
	menu:SetTitle( "Personal bloodsucking" )
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
		mdl:SetModel( def.Model )
		local mn, mx = mdl.Entity:GetRenderBounds()
		local size = math.max( mx:Distance( mn ), 1 )
		mdl:SetCamPos( Vector( size, size, size * 0.5 ) )
		mdl:SetLookAt( ( mn + mx ) / 2 )
		title:SetText( Shop.Name( id ) ) title:SizeToContents()
		desc:SetText( def.Description or "" )
		weight:SetText( "Weight: " .. def.Weight ) weight:SizeToContents()
	end
	function menu:Think()
		if not IsValid( ent ) then return self:Remove() end
		if not selected then return end
		cost:SetText( "Costs: " .. Shop.Price( selected ) .. " Bones" ) cost:SizeToContents()
		stock:SetText( "Available stock: " .. Shop.Available( selected ) ) stock:SizeToContents()
	end

	local x, y = 4, 4
	for _, e in ipairs( Shop.LIST ) do
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
	show( Shop.LIST[ 1 ].id )

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
end )
