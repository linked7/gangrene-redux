-- Economy, shared half: the goods, the Economy table's schema and read access to the public
-- economy values. Everything that moves bones is in sv_econ.lua.
--
-- Public world state (WorldState keys):
--   treasury, upgrade_fund, bones_supply   bone counts
--   stock.<good>                           stockpile counts
--   econ.<setting>                         the Economy table
Econ = Econ or {}

-- Goods the stockpile holds, with the default prices the state pays and charges for them.
Econ.GOODS = { "ration", "clean_water", "fear_beer", "spirits", "knife", "coat", "lighter" }
Econ.GOODS = { "ration", "clean_water", "fear_beer", "spirits", "knife", "coat",
	-- The tools machine chain (systems/sh_toolsmachine.lua). Placeholder prices.
	"scrap", "biofuel", "ore", "material_metal_pot", "material_metal_ballistic", "formic_steel",
	"pipe", "hammer", "crowbar", "bat", "fryingpan", "pickaxe", "axe", "shovel", "meatsaw", "crackhammer" }
Econ.GOOD_DEFAULTS = {
	ration = { buy = 20, sell = 15 },
	clean_water = { buy = 20, sell = 15 },
	fear_beer = { buy = 25, sell = 35 },
	spirits = { buy = 60, sell = 85 },
	knife = { buy = 30, sell = 40 },
	coat = { buy = 30, sell = 40 },
	lighter = { buy = 10, sell = 15 },
	scrap = { buy = 10, sell = 15 },
	biofuel = { buy = 15, sell = 20 },
	ore = { buy = 10, sell = 15 },
	material_metal_pot = { buy = 20, sell = 30 },
	material_metal_ballistic = { buy = 50, sell = 80 },
	formic_steel = { buy = 90, sell = 140 },
	pipe = { buy = 20, sell = 30 },
	hammer = { buy = 30, sell = 40 },
	crowbar = { buy = 30, sell = 40 },
	bat = { buy = 20, sell = 30 },
	fryingpan = { buy = 25, sell = 35 },
	pickaxe = { buy = 40, sell = 55 },
	axe = { buy = 40, sell = 55 },
	shovel = { buy = 30, sell = 40 },
	meatsaw = { buy = 80, sell = 110 },
	crackhammer = { buy = 120, sell = 160 },
}
-- The C-menu shop (step 9) sells these at sell.<good>, out of the same stock counts. Every good
-- here but the ration starts each round with `shop_stock` in the stockpile.
Econ.BREWED = { fear_beer = true, spirits = true } -- brewed in a brew_barrel, never seeded
Econ.SHOP = { "ration", "fear_beer", "spirits", "knife", "coat" }
Econ.SHOP = { "ration", "fear_beer", "spirits", "knife", "coat", "lighter" }
Econ.SHOP_SET = {}
for _, good in ipairs( Econ.SHOP ) do Econ.SHOP_SET[ good ] = true end
-- The bread line hands out this good.
Econ.BREAD = "ration"

-- The stockpile port's materials side section: bought in bulk from stock at the material's sell
-- price. A material is on sale only once it is an item and has a `sell.<m>` setting; until then
-- its row reads "not sold" and the server refuses it.
Econ.MATERIALS = { "wood", "biomass", "biofuel", "scrap", "ore", "water", "meat", "seeds" }
Econ.MATERIAL_SET = {}
for _, m in ipairs( Econ.MATERIALS ) do Econ.MATERIAL_SET[ m ] = true end
Econ.MATERIAL_MAX = 255 -- one purchase at most; sent as an 8-bit count

-- The price of one `m`, or nil when the port doesn't sell it.
function Econ.MaterialPrice( m )
	if not Econ.MATERIAL_SET[ m ] or not Items.Get( m ) then return nil end
	if not Econ.SchemaByKey[ "sell." .. m ] then return nil end
	return Econ.Setting( "sell." .. m )
end

-- How many `m` the port can sell: the stock less any reserve.
function Econ.MaterialAvailable( m )
	local reserve = Econ.SchemaByKey[ "reserve." .. m ] and Econ.Setting( "reserve." .. m ) or 0
	return math.max( 0, Econ.Stock( m ) - reserve )
end

-- The Economy table schema. Values are whole numbers between min and max; max = nil means
-- bones_supply. These are sanity checks only, never balance clamps: the Kaiser may set anything sane.
Econ.Schema = {}      -- ordered list of { key, type, min, max, default }
Econ.SchemaByKey = {}

local function setting( key, default, max )
	local def = { key = key, type = "int", min = 0, max = max, default = default }
	table.insert( Econ.Schema, def )
	Econ.SchemaByKey[ key ] = def
end

for _, good in ipairs( Econ.GOODS ) do
	setting( "buy." .. good, Econ.GOOD_DEFAULTS[ good ].buy )   -- paid per delivered crate
	setting( "sell." .. good, Econ.GOOD_DEFAULTS[ good ].sell ) -- charged at the counter
	setting( "reserve." .. good, 0 )                          -- the counter stops selling at this stock
end
-- One wage per fate, keyed by fate id as data. The default comes from the fate's own Wage field.
for _, f in ipairs( Fates.All() ) do
	if f.index ~= FATE_GHOST then setting( "wage." .. f.id, f.Wage or 0 ) end
end
setting( "ration_limit", 0 )     -- counter purchases per player per 10 min; 0 = unlimited
setting( "breadline", 0 )        -- minutes between free rations per player; 0 = off
setting( "revive_fee", 50, 100 ) -- percent of a patient's carried bones (step 11.2)
setting( "export_rations", 20 ) -- rations the Kaiser's train takes out per trip (sh_export.lua)
setting( "train_trip", 180 )    -- seconds before the train comes back with the import
setting( "shop_stock", 10 )      -- shop goods (not the ration) seeded into the stockpile each round
setting( "sales_tax", 0, 100 )   -- percent added to sales prices (the autostitcher reads it)

function Econ.Supply() return WorldState.Get( "bones_supply", 0 ) end
function Econ.Treasury() return WorldState.Get( "treasury", 0 ) end
function Econ.UpgradeFund() return WorldState.Get( "upgrade_fund", 0 ) end
function Econ.Stock( good ) return WorldState.Get( "stock." .. good, 0 ) end

function Econ.Setting( key )
	local def = Econ.SchemaByKey[ key ]
	return WorldState.Get( "econ." .. key, def and def.default or 0 )
end

-- The stockpile counter's actions, as sent by `gr_counter` (UInt 2).
Econ.COUNTER_BUY, Econ.COUNTER_TAKE, Econ.COUNTER_FREE = 0, 1, 2

-- Living players of any fate can use the shop.
function Econ.CanShop( ply )
	return IsValid( ply ) and ply:Alive() and not ply:IsGhost()
end

-- The server tells a player who used a stockpile to open its port panel.
Net.Pool( "gr_port_open" )

if SERVER then return end

-- Until the counter has a UI: `gr_counter <buy|take|free> [good]` while looking at a stockpile.
local ACTIONS = { buy = Econ.COUNTER_BUY, take = Econ.COUNTER_TAKE, free = Econ.COUNTER_FREE }

concommand.Add( "gr_counter", function( ply, _, args )
	local action = ACTIONS[ args[ 1 ] or "" ]
	local ent = ply:GetEyeTrace().Entity
	if not action or not IsValid( ent ) then return end
	net.Start( "gr_counter" )
	net.WriteEntity( ent )
	net.WriteUInt( action, 2 )
	net.WriteString( args[ 2 ] or Econ.BREAD )
	net.SendToServer()
end )

-- The stockpile port's panel, which is the whole shop: the dealer-style Buy list of shop goods on
-- the left, the materials side section beside it (one text row per material with a count slider,
-- 1 to what's in stock, and a Buy button). The server decides; this only asks.
function Econ.OpenPort( port )
	if IsValid( Econ.PortFrame ) then Econ.PortFrame:Remove() end
	local f = vgui.Create( "DFrame" )
	Econ.PortFrame = f
	f:SetTitle( "Stockpile port" )
	f:SetSize( 760, 60 + math.max( #Econ.MATERIALS, #Econ.SHOP ) * 30 )
	f:Center()
	f:MakePopup()
	f.Think = function( self )
		if not IsValid( port ) or LocalPlayer():GetPos():DistToSqr( port:GetPos() ) > 214 ^ 2 then self:Remove() end -- counter range plus slack
	end
	local shop = vgui.Create( "DScrollPanel", f )
	shop:Dock( LEFT )
	shop:SetWide( 280 )
	shop:DockMargin( 0, 0, 10, 0 )
	for _, good in ipairs( Econ.SHOP ) do
		local def = Items.Get( good )
		local n = Econ.Stock( good )
		local b = shop:Add( "DButton" )
		b:Dock( TOP )
		b:SetTall( 26 )
		b:DockMargin( 0, 2, 0, 2 )
		b:SetText( string.format( "%s - %d bones (%s)", def and def.Name or good, Econ.Setting( "sell." .. good ),
			n > 0 and n .. " left" or "sold out" ) )
		b:SetEnabled( n > 0 )
		b.DoClick = function()
			net.Start( "nShopBuy" )
			net.WriteEntity( port )
			net.WriteString( good )
			net.SendToServer()
			f:Remove()
		end
	end
	for _, m in ipairs( Econ.MATERIALS ) do
		local row = vgui.Create( "DPanel", f )
		row:Dock( TOP )
		row:SetTall( 26 )
		row:DockMargin( 0, 2, 0, 2 )
		row.Paint = nil
		local price, avail = Econ.MaterialPrice( m ), math.min( Econ.MaterialAvailable( m ), Econ.MATERIAL_MAX )
		local label = vgui.Create( "DLabel", row )
		label:Dock( LEFT )
		label:SetWide( 170 )
		if not price then
			label:SetText( m .. ": not sold" )
		elseif avail < 1 then
			label:SetText( string.format( "%s: sold out (%d bones)", m, price ) )
		else
			label:SetText( string.format( "%s: %d in stock, %d bones", m, avail, price ) )
			local buy = vgui.Create( "DButton", row )
			buy:Dock( RIGHT )
			buy:SetWide( 60 )
			buy:SetText( "Buy" )
			local slider = vgui.Create( "DNumSlider", row )
			slider:Dock( FILL )
			slider:SetText( "" )
			slider:SetMin( 1 )
			slider:SetMax( avail )
			slider:SetDecimals( 0 )
			slider:SetValue( 1 )
			buy.DoClick = function()
				net.Start( "nShopBuyMaterial" )
				net.WriteEntity( port )
				net.WriteString( m )
				net.WriteUInt( math.Clamp( math.Round( slider:GetValue() ), 1, Econ.MATERIAL_MAX ), 8 )
				net.SendToServer()
				f:Remove()
			end
		end
	end
end

Net.Receive( "gr_port_open", nil, function()
	local port = net.ReadEntity()
	if IsValid( port ) then Econ.OpenPort( port ) end
end )
