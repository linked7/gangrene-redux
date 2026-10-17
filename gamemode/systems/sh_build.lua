-- Construction (step 11.1). Anyone carrying an item tagged Builds (the permit tool) can hold C
-- while looking at open ground and pick Build: a factory site or a storage crate. The price goes to
-- the treasury through Econ.Transfer, and the server checks the spot is in reach and in sight.
--
--   Build.KINDS[ kind ] = { name, cost, class, max }    max: how many one player may have standing
--   Build.Place( ply, kind, pos ) -> ent, or false and why     (the `gr_build` receiver calls it)
--   Build.IsBuilder( ply, ent )   shared: did `ply` build `ent` (ent:GetBuiltBy() is the DB.Key)
--   Build.Count( ply, kind )      server: how many of `kind` built by `ply` still stand
--   Built things belong to one round: GR_RoundStart removes them (ent.GR_RoundReset is set first,
--   so a storage crate doesn't spill its contents on the floor of a new round).
--   console: gr_build <kind>   builds at the spot you look at
Build = Build or {}

Build.KINDS = {
	factory_site = { name = "Factory site", cost = 25, class = "factory_site", max = 2 },
	storage_crate = { name = "Storage crate", cost = 35, class = "storage_crate" },
}
Build.ORDER = { "factory_site", "storage_crate" }
Build.RANGE = 150 -- from the builder's eyes to the spot

-- Built entities network their builder's key as the "BuiltBy" string. Clients only ever ask about
-- themselves, and a client is never a bot, so its key is its SteamID64 (DB.Key is server-only).
function Build.IsBuilder( ply, ent )
	if not IsValid( ply ) or not IsValid( ent ) or not ent.GetBuiltBy then return false end
	local key = SERVER and DB.Key( ply ) or ply:SteamID64()
	return key ~= nil and key ~= "" and ent:GetBuiltBy() == key
end

function Build.CanBuild( ply )
	for id in pairs( Inventory.Items( ply ) ) do
		local def = Items.Get( id )
		if def and def.Tags and def.Tags.Builds then return true end
	end
	return false
end

if CLIENT then
	local function send( kind, pos )
		net.Start( "gr_build" )
		net.WriteString( kind )
		net.WriteVector( pos )
		net.SendToServer()
	end

	concommand.Add( "gr_build", function( ply, _, args )
		local kind = args[ 1 ] or ""
		if not Build.KINDS[ kind ] then
			print( "gr_build <" .. table.concat( Build.ORDER, "|" ) .. ">" )
			return
		end
		send( kind, ply:GetEyeTrace().HitPos )
	end )

	-- Looking at open ground with a permit tool: the C menu offers Build. Entities get Interact's menu.
	hook.Add( "OnContextMenuOpen", "gr_build", function()
		local ply = LocalPlayer()
		if not ply:Alive() or ply:IsGhost() or not Build.CanBuild( ply ) then return end
		local tr = ply:GetEyeTrace()
		if not tr.HitWorld or tr.HitPos:Distance( ply:EyePos() ) > Build.RANGE then return end
		local menu = DermaMenu()
		local sub = menu:AddSubMenu( "Build" )
		for _, kind in ipairs( Build.ORDER ) do
			local k = Build.KINDS[ kind ]
			sub:AddOption( string.format( "%s (%d bones)", k.name, k.cost ), function() send( kind, tr.HitPos ) end )
		end
		menu:Open( ScrW() / 2, ScrH() / 2 )
	end )
	return
end

-- Registry of everything built this round: ent -> kind (no world searches, P2).
local built = Build.built or setmetatable( {}, { __mode = "k" } )
Build.built = built

function Build.Count( ply, kind )
	local key, n = DB.Key( ply ), 0
	for ent, k in pairs( built ) do
		if k == kind and IsValid( ent ) and ent.GR_BuiltBy == key then n = n + 1 end
	end
	return n
end

hook.Add( "GR_RoundStart", "gr_build", function()
	for ent in pairs( built ) do
		if IsValid( ent ) then
			ent.GR_RoundReset = true
			ent:Remove()
		end
	end
	built = setmetatable( {}, { __mode = "k" } )
	Build.built = built
end )

function Build.Place( ply, kind, pos )
	local function refuse( why ) Notify( ply, why ) return false, why end
	local k = Build.KINDS[ kind ]
	if not k then return false, "unknown kind" end
	if not ply:Alive() or ply:IsGhost() then return false, "not alive" end
	if not Build.CanBuild( ply ) then return refuse( "You need a permit tool to build." ) end
	-- NaN compares false with everything, so a non-finite spot would pass the range check.
	if not Net.Finite( pos ) or ply:EyePos():DistToSqr( pos ) > Build.RANGE * Build.RANGE then
		return refuse( "That is too far away to build on." )
	end
	-- The spot must be in sight: nothing between the builder's eyes and it.
	local tr = util.TraceLine( { start = ply:EyePos(), endpos = pos, filter = ply, mask = MASK_SOLID } )
	if tr.HitPos:DistToSqr( pos ) > 16 * 16 then return refuse( "You can't reach there." ) end
	if k.max and Build.Count( ply, kind ) >= k.max then
		return refuse( string.format( "You already have %d %ss standing.", k.max, string.lower( k.name ) ) )
	end

	if not Econ.Transfer( ply, Econ.TREASURY, k.cost, "construction" ) then
		return refuse( string.format( "A %s costs %d bones.", string.lower( k.name ), k.cost ) )
	end
	local ent = ents.Create( k.class )
	ent:SetPos( pos + Vector( 0, 0, 2 ) )
	ent:SetAngles( Angle( 0, ply:EyeAngles().y + 180, 0 ) )
	ent.GR_BuiltBy = DB.Key( ply )
	ent:Spawn() -- the entity copies GR_BuiltBy into its networked BuiltBy
	built[ ent ] = kind
	Log.Debug( "build", "%s built a %s for %d", ply:Nick(), kind, k.cost )
	return ent
end

Net.Receive( "gr_build", { rate = 1, alive = true }, function( ply )
	local kind = Net.ReadString()
	Build.Place( ply, kind, net.ReadVector() )
end )
