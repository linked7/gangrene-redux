-- Kaiser imports: goods no factory makes reach the stockpile only this way. The Kaiser orders
-- one from the panel (Imports tab), the treasury pays its buy price to the outside world (the
-- upgrade fund), and a crate of it appears at the gate. Someone hauls it to the stockpile like
-- any other crate (Crates.Deliver), which is the only way its stock rises. Coats come first.
--   Imports.GOODS[ good ] = true     Imports.IsImport( good )     Imports.Order( ply, good )
Imports = Imports or {}
Imports.GOODS = { coat = true, scrap = true, biofuel = true }
-- These go straight into stock, no crate (the tools machine chain's raw inputs).
Imports.TO_STOCK = { scrap = true, biofuel = true }

function Imports.IsImport( good ) return Imports.GOODS[ good ] == true end

if CLIENT then return end

-- Where import crates land: by the immigration konsole, else the wasteland arrival, else `ply`.
function Imports.GatePos( ply )
	for e in pairs( Layout.present or {} ) do
		if IsValid( e ) and e:GetClass() == "konsole_immigration" then
			return e:GetPos() + e:GetForward() * 60 + Vector( 0, 0, 20 )
		end
	end
	local pos = RoundFlow.WASTELAND and RoundFlow.WASTELAND[ game.GetMap() ]
	if pos then return pos + Vector( 0, 0, 20 ) end
	return IsValid( ply ) and ply:GetPos() + ply:GetForward() * 60 + Vector( 0, 0, 20 ) or vector_origin
end

function Imports.Order( ply, good )
	if not IsValid( ply ) or not ply:Alive() or not ply:FateHas( "RunsEconomy" ) then return false end
	if not Imports.IsImport( good ) or not Econ.GOOD_DEFAULTS[ good ] then
		Notify( ply, "That can't be imported." )
		return false
	end
	local price = Econ.Setting( "buy." .. good )
	if not Econ.Transfer( Econ.TREASURY, Econ.UPGRADE_FUND, price, "import " .. good ) then
		Notify( ply, string.format( "The treasury can't cover the %d bones this import costs.", price ) )
		return false
	end
	if Imports.TO_STOCK[ good ] then
		Econ.AddStock( good, 1 )
		Notify( ply, "The import is in the stockpile." )
		return true
	end
	local crate = Crates.Spawn( good, Imports.GatePos( ply ) )
	Notify( ply, "An import crate has arrived at the gate. Have it hauled to the stockpile." )
	return crate
end

Net.Receive( "nKaiserImport", { rate = 2, alive = true, fate = "RunsEconomy" }, function( ply )
	Imports.Order( ply, Net.ReadString() )
end )
