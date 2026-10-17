-- Economy, shared half: the goods, the Economy table's schema and read access to the public
-- economy values. Everything that moves bones is in sv_econ.lua.
--
-- Public world state (WorldState keys):
--   treasury, upgrade_fund, bones_supply   bone counts
--   stock.<good>                           stockpile counts
--   econ.<setting>                         the Economy table
Econ = Econ or {}

-- Goods the stockpile holds, with the default prices the state pays and charges for them.
Econ.GOODS = { "ration", "clean_water", "fear_beer", "spirits", "knife" }
Econ.GOOD_DEFAULTS = {
	ration = { buy = 20, sell = 15 },
	clean_water = { buy = 20, sell = 15 },
	fear_beer = { buy = 25, sell = 35 },
	spirits = { buy = 60, sell = 85 },
	knife = { buy = 30, sell = 40 },
}
-- The C-menu shop (step 9) sells these at sell.<good>, out of the same stock counts. Every good
-- here but the ration starts each round with `shop_stock` in the stockpile.
Econ.SHOP = { "ration", "fear_beer", "spirits", "knife" }
Econ.BREWED = { fear_beer = true, spirits = true } -- brewed in a brew_barrel, never seeded
Econ.SHOP_SET = {}
for _, good in ipairs( Econ.SHOP ) do Econ.SHOP_SET[ good ] = true end
-- The bread line hands out this good.
Econ.BREAD = "ration"

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

if SERVER then return end

-- Adds the shop's Buy submenu to an open context menu (sh_interact.lua builds the menu).
function Econ.AddShopMenu( menu )
	local sub = menu:AddSubMenu( "Buy" )
	for _, good in ipairs( Econ.SHOP ) do
		local def = Items.Get( good )
		local n = Econ.Stock( good )
		local text = string.format( "%s - %d bones (%s)", def and def.Name or good, Econ.Setting( "sell." .. good ),
			n > 0 and n .. " left" or "sold out" )
		sub:AddOption( text, function()
			net.Start( "nShopBuy" )
			net.WriteString( good )
			net.SendToServer()
		end )
	end
end

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
