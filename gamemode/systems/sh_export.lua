-- Kaiser export (step 11): the Kaiser sends export_rations out on the train from a train_station;
-- train_trip seconds later one heavy, sealed import crate of tools or guns comes back.
--
--   Export.Send( ply, station, kind ) -> ok, why       net nKaiserExport( kind )
Export = Export or {}

Export.IMPORTS = { tools = "scrap_gear", guns = "pistol" }
Export.RANGE = 200
Export.MASS = 120

local stations = setmetatable( {}, { __mode = "k" } )
function Export.Track( ent ) stations[ ent ] = true end

function Export.Nearest( pos )
	local best, bestD
	for s in pairs( stations ) do
		if IsValid( s ) then
			local d = s:GetPos():Distance( pos )
			if not bestD or d < bestD then best, bestD = s, d end
		end
	end
	return best
end

if CLIENT then return end

Net.Pool( "nKaiserExport" )

function Export.Send( ply, station, kind )
	if not IsValid( ply ) or not ply:Alive() or ply:IsGhost() or not ply:FateHas( "RunsEconomy" ) then return false, "Only the Kaiser exports." end
	if not IsValid( station ) or station:GetPos():Distance( ply:GetPos() ) > Export.RANGE then return false, "Go to the train station." end
	if station:GetAway() then return false, "The train is out." end
	if not Export.IMPORTS[ kind ] then return false, "Unknown cargo." end
	local n = Econ.Setting( "export_rations" )
	if Econ.Stock( "ration" ) < n then return false, "Not enough rations in the stockpile." end
	Econ.TakeStock( "ration", n )
	station:SetAway( true )
	station:SetCargo( kind )
	station:SetReturnAt( CurTime() + Econ.Setting( "train_trip" ) )
	return true
end

function Export.Arrive( station )
	local crate = Crates.Spawn( Export.IMPORTS[ station:GetCargo() ], station:GetPos() + station:GetForward() * 60 + Vector( 0, 0, 20 ), nil, nil )
	station:SetAway( false )
	station:SetCargo( "" )
	if not IsValid( crate ) then return end
	crate.GR_Import = true
	station.GR_LastImport = crate
	crate:SetLocked( true )
	local phys = crate:GetPhysicsObject()
	if IsValid( phys ) then phys:SetMass( Export.MASS ) end
	return crate
end

Net.Receive( "nKaiserExport", { rate = 2, alive = true, fate = "RunsEconomy" }, function( ply )
	local kind = net.ReadString()
	local ok, why = Export.Send( ply, Export.Nearest( ply:GetPos() ), kind )
	Notify( ply, ok and "The train leaves with the rations." or why )
end )

Sched.Every( "export", 1, function()
	for s in pairs( stations ) do
		if IsValid( s ) and s:GetAway() and CurTime() >= s:GetReturnAt() then Export.Arrive( s ) end
	end
end )

hook.Add( "GR_RoundStart", "gr_export", function()
	for s in pairs( stations ) do if IsValid( s ) then s:SetAway( false ) s:SetCargo( "" ) end end
end )
