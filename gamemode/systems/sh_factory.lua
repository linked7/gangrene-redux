-- Factory sites (design default, beyond the plan): a prole-built work station. It joins the
-- ration press in Crates' work loop (sh_crates.lua): anyone may work it, the crate is stamped with
-- the worker's key, and at most Crates.PER_STATION of its crates wait in the world. Its builder
-- picks what it makes from Factory.Kinds through the C menu ("Make..."). Each player may have
-- Build.KINDS.factory_site.max sites standing (sh_build.lua refuses more); they go at round reset.
--
--   Factory.Kinds[ good ] = { name }     goods a site can make (each must be an Econ good)
--   Factory.SetKind( ply, site, good ) -> ok     builder only
Factory = Factory or {}

Factory.Kinds = {
	ration = { name = "Rations" },
	clean_water = { name = "Clean water" },
}
Factory.ORDER = { "ration", "clean_water" }
Factory.DEFAULT = "ration"

Crates.STATIONS.factory_site = true

local function isSite( ent ) return IsValid( ent ) and ent:GetClass() == "factory_site" end

Interact.Add( "factory_work", {
	label = function( ply, ent )
		local k = Factory.Kinds[ ent:GetGood() ]
		return "Work the factory" .. ( k and " (" .. string.lower( k.name ) .. ")" or "" )
	end,
	show = function( ply, ent ) return isSite( ent ) and not ply:IsGhost() end,
	run = function( ply, ent ) Crates.Work( ply, ent ) end,
} )

Interact.Add( "factory_kind", {
	label = "Make...",
	show = function( ply, ent ) return isSite( ent ) and not ply:IsGhost() and Build.IsBuilder( ply, ent ) end,
	choices = function( ply, ent )
		local out = {}
		for _, good in ipairs( Factory.ORDER ) do
			local mark = ent:GetGood() == good and " (now)" or ""
			table.insert( out, { Factory.Kinds[ good ].name .. mark, good } )
		end
		return out
	end,
	run = function( ply, ent, good ) Factory.SetKind( ply, ent, good ) end,
} )

if CLIENT then return end

function Factory.SetKind( ply, site, good )
	if not isSite( site ) then return false end
	if not Build.IsBuilder( ply, site ) then
		Notify( ply, "Only whoever built this site can change what it makes." )
		return false
	end
	local k = Factory.Kinds[ good or "" ]
	if not k or not Econ.GOOD_DEFAULTS[ good ] then
		Notify( ply, "This site can't make that." )
		return false
	end
	site:SetGood( good )
	Notify( ply, "The site now makes " .. string.lower( k.name ) .. "." )
	return true
end
