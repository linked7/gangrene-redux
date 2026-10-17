-- Interactions on a looked-at entity: hold C (the context menu) to see what you can do with it.
-- Every system adds its options here instead of building its own menu or receiver.
--
--   Interact.Add( id, {
--       label = "Inspect" | function( ply, ent ) -> string,
--       range = 120,
--       show( ply, ent ) -> bool,   shared; the client uses it to build the menu
--       run( ply, ent ),            server; runs after show() passes again there
--   } )
--
-- Server code (and tests) can call Interact.Run( ply, id, ent ) directly; the receiver does the same.
Interact = Interact or {}
local list = Interact.list or {}
Interact.list = list

function Interact.Add( id, def )
	def.id = id
	def.range = def.range or 120
	for i, d in ipairs( list ) do
		if d.id == id then list[ i ] = def return end
	end
	table.insert( list, def )
end

function Interact.Get( id )
	for _, d in ipairs( list ) do
		if d.id == id then return d end
	end
end

local function allowed( ply, d, ent )
	if not IsValid( ent ) or not ply:Alive() then return false end
	if ply:GetPos():DistToSqr( ent:GetPos() ) > d.range * d.range then return false end
	return not d.show or d.show( ply, ent ) == true
end

-- The options `ply` has on `ent` right now.
function Interact.For( ply, ent )
	local out = {}
	for _, d in ipairs( list ) do
		if allowed( ply, d, ent ) then table.insert( out, d ) end
	end
	return out
end

if SERVER then
	function Interact.Run( ply, id, ent )
		local d = Interact.Get( id )
		if not d or not d.run or not allowed( ply, d, ent ) then return false end
		d.run( ply, ent )
		return true
	end

	Net.Receive( "gr_interact", { rate = 4, alive = true, target = "any", range = 400 }, function( ply, ent )
		Interact.Run( ply, net.ReadString(), ent )
	end )
	return
end

local menu
hook.Add( "OnContextMenuOpen", "gr_interact", function()
	local ply = LocalPlayer()
	local ent = ply:GetEyeTrace().Entity
	if not IsValid( ent ) then return end
	local opts = Interact.For( ply, ent )
	if #opts == 0 then return end
	menu = DermaMenu()
	for _, d in ipairs( opts ) do
		local label = isfunction( d.label ) and d.label( ply, ent ) or d.label or d.id
		menu:AddOption( label, function()
			net.Start( "gr_interact" )
			net.WriteEntity( ent )
			net.WriteString( d.id )
			net.SendToServer()
		end )
	end
	menu:Open( ScrW() / 2, ScrH() / 2 )
end )

hook.Add( "OnContextMenuClose", "gr_interact", function()
	-- Leave the menu up until a choice is made or it loses focus; just forget the handle.
	menu = nil
end )
