-- Interactions on a looked-at entity: hold C (the context menu) to see what you can do with it.
-- Every system adds its options here instead of building its own menu or receiver.
--
--   Interact.Add( id, {
--       label = "Inspect" | function( ply, ent ) -> string,
--       range = 120,
--       show( ply, ent ) -> bool,   shared; the client uses it to build the menu
--       run( ply, ent, choice ),    server; runs after show() passes again there
--       choices( ply, ent ) -> { { label, value }, ... },   optional, client: the option becomes a
--                                   submenu and run() gets the picked value (a string; validate it)
--   } )
--
-- Server code (and tests) can call Interact.Run( ply, id, ent, choice ) directly; the receiver does the same.
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
	function Interact.Run( ply, id, ent, choice )
		local d = Interact.Get( id )
		if not d or not d.run or not allowed( ply, d, ent ) then return false end
		d.run( ply, ent, choice )
		return true
	end

	Net.Receive( "gr_interact", { rate = 4, alive = true, target = "any", range = 400 }, function( ply, ent )
		local id = Net.ReadString()
		local choice = Net.ReadString() -- "" when the option has no choices
		if not id or not choice then return end
		Interact.Run( ply, id, ent, choice ~= "" and choice or nil )
	end )
	return
end

local menu
hook.Add( "OnContextMenuOpen", "gr_interact", function()
	local ply = LocalPlayer()
	local ent = ply:GetEyeTrace().Entity
	local opts = IsValid( ent ) and Interact.For( ply, ent ) or {}
	if #opts == 0 then return end
	local function send( d, choice )
		net.Start( "gr_interact" )
		net.WriteEntity( ent )
		net.WriteString( d.id )
		net.WriteString( choice or "" )
		net.SendToServer()
	end
	menu = DermaMenu()
	for _, d in ipairs( opts ) do
		local label = isfunction( d.label ) and d.label( ply, ent ) or d.label or d.id
		if d.choices then
			local list = d.choices( ply, ent ) or {}
			if #list > 0 then
				local sub = menu:AddSubMenu( label )
				for _, c in ipairs( list ) do
					sub:AddOption( c[ 1 ], function() send( d, tostring( c[ 2 ] ) ) end )
				end
			end
		else
			menu:AddOption( label, function() send( d ) end )
		end
	end
	-- At the screen centre with the cursor put there too, painted by the CombineControl skin (cl_skin.lua).
	local cx, cy = ScrW() / 2, ScrH() / 2
	input.SetCursorPos( cx, cy )
	menu:Open( cx, cy )
end )

hook.Add( "OnContextMenuClose", "gr_interact", function()
	-- Leave the menu up until a choice is made or it loses focus; just forget the handle.
	menu = nil
end )
