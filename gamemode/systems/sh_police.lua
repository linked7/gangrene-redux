-- Police work (step 11.3), for every fate with Police = true. Built on Crime (sh_crime.lua):
--
--   Inspect   context menu on a living player within 100 units: shows whether they carry a crate
--             someone else made and their evidence; theft evidence becomes torment-wanted 180 s
--   Arrest    context menu on the body of a wanted player who is unconscious or downed: clears
--             their wanted status
--   Bounty    beating (a blunt hit) or arresting a theft-wanted player pays Teeth, once per wanted
--             episode (Crime keeps the episode), so it can't be farmed
--   Station   a sanitation_station sells weapons for Teeth (Police.OFFERS)
--
-- Police see wanted players and evidence summaries over their heads (client half below); their
-- teeth are shown in the main HUD (cl_hud.lua).
Police = Police or {}

Police.INSPECT_RANGE = 100
Police.ARREST_RANGE = 120
Police.STATION_RANGE = 120
Police.BOUNTY_TEETH = 1
-- Crimes that put a bounty on the wanted player. Inspect makes the same crime.
Police.THEFT_CRIME = "theft from the People"
Police.BOUNTY_CRIMES = { [ Police.THEFT_CRIME ] = true }

-- What the sanitation station sells (Police.OFFERS) and its interactions are in sh_guns.lua.

-- Items -------------------------------------------------------------------------------------

Items.Define( "scope", {
	Name = "Scope",
	Description = "A sanitar's spyglass. Use it to look far, and again to lower it.",
	Weight = 1,
	Model = "models/props_c17/trappropeller_lever.mdl",
	OnUse = function( ply )
		ply.GR_Scoped = not ply.GR_Scoped
		ply:SetFOV( ply.GR_Scoped and 25 or 0, 0.2 )
	end,
} )

local function isPolice( ply ) return IsValid( ply ) and ply:IsPlayer() and ply:Alive() and ply:FateHas( "Police" ) end

local function livingPlayer( ent )
	return IsValid( ent ) and ent:IsPlayer() and ent:Alive() and not ent:IsGhost()
end

-- Interactions (shared: the client builds the menu from show) --------------------------------

Interact.Add( "inspect", {
	label = "Inspect",
	range = Police.INSPECT_RANGE,
	show = function( ply, ent ) return isPolice( ply ) and ent ~= ply and livingPlayer( ent ) end,
	run = function( ply, ent ) Police.Inspect( ply, ent ) end,
} )

-- The server knows whose body it is; the client only knows it is a ragdoll.
local function arrestable( ent )
	if CLIENT then return ent:GetClass() == "prop_ragdoll" end
	local rec = Corpse.Get( ent )
	return rec ~= nil and IsValid( rec.owner ) and ( rec.state == "unconscious" or rec.state == "downed" )
end

Interact.Add( "arrest", {
	label = "Arrest",
	range = Police.ARREST_RANGE,
	show = function( ply, ent ) return isPolice( ply ) and arrestable( ent ) end,
	run = function( ply, ent ) Police.Arrest( ply, Corpse.Get( ent ).owner ) end,
} )

if CLIENT then
	-- Over the heads of players in sight: wanted level, reason and time left, then any evidence.
	local LEVEL_COLOR = {
		[ WANTED_TORMENT ] = Color( 230, 200, 60 ),
		[ WANTED_JUDGMENT ] = Color( 230, 130, 40 ),
		[ WANTED_DEATH ] = Color( 220, 40, 40 ),
	}
	local EVIDENCE_COLOR = Color( 180, 180, 180 )
	local RANGE = 1500

	local function inSight( me, p )
		return not util.TraceLine( { start = me:EyePos(), endpos = p:EyePos(), filter = { me, p }, mask = MASK_OPAQUE_AND_NPCS } ).Hit
	end

	hook.Add( "HUDPaint", "gr_police", function()
		local me = LocalPlayer()
		if not isPolice( me ) then return end

		local eye = me:EyePos()
		for _, p in player.Iterator() do
			local summary = Crime.Summaries[ p:EntIndex() ]
			if p ~= me and livingPlayer( p ) and ( p:IsWanted() or summary )
				and p:GetPos():DistToSqr( eye ) < RANGE * RANGE and inSight( me, p ) then
				local pos = ( p:EyePos() + Vector( 0, 0, 14 ) ):ToScreen()
				if pos.visible then
					local y = pos.y
					if p:IsWanted() then
						-- The original's overhead style: PlayerFont, shadowed, through Stutter (cl_hud.lua).
						local text = string.format( "WANTED: %s (%d s)", p:GetWantedReason(), math.ceil( Crime.WantedLeft( p ) ) )
						HUD.TextShadow( HUD.Stutter( text ), HUD.Font( "PlayerFont" ), pos.x, y - 20, LEVEL_COLOR[ p:GetWanted() ] or color_white, color_black, 1 )
						y = y - 20
					end
					if summary then
						HUD.TextShadow( HUD.Stutter( "Evidence: " .. summary ), HUD.Font( "LabelTiny" ), pos.x, y - 18, EVIDENCE_COLOR, color_black, 1 )
					end
				end
			end
		end
	end )
	return
end

-- Server ------------------------------------------------------------------------------------

-- Inspect turns theft evidence into wanted through the same rules table as every other report.
local INSPECT_RULE = { name = "inspected_theft", crime = Police.THEFT_CRIME, wanted = WANTED_TORMENT, duration = 180,
	when = function( _, act, ctx ) return act == "inspected" and ctx.theft ~= nil end }
for i, rule in ipairs( Crime.ReportRules ) do
	if rule.name == INSPECT_RULE.name then table.remove( Crime.ReportRules, i ) break end
end
table.insert( Crime.ReportRules, INSPECT_RULE )

-- The crate `ply` is carrying, if someone else made it. Crates (step 11.1) may not be loaded.
function Police.StolenCrate( ply )
	local crate = Crates and Crates.HeldBy and Crates.HeldBy( ply )
	if crate and Crates.Stolen( crate, ply ) then return crate end
end

-- Returns { stolenCrate, evidence, wanted } and tells the inspector. Interact has already
-- checked the inspector is living police and the target a living player in range.
function Police.Inspect( ply, target )
	local result = {
		stolenCrate = Police.StolenCrate( target ) ~= nil,
		evidence = Crime.Summary( target ),
	}
	local theft = Crime.TakeEvidence( target, "theft" )
	if theft then Crime.Report( target, "inspected", { theft = theft } ) end
	result.wanted = target:IsWanted()

	local lines = { "You inspect " .. target:Nick() .. "." }
	table.insert( lines, result.stolenCrate and "They carry a crate made by someone else." or "They carry nothing stolen." )
	table.insert( lines, result.evidence ~= "" and "Evidence: " .. result.evidence .. "." or "No evidence." )
	if target:IsWanted() then
		table.insert( lines, string.format( "Wanted for %s.", target:GetWantedReason() ) )
	end
	Notify( ply, table.concat( lines, " " ) )
	hook.Run( "GR_Inspected", ply, target ) -- gun permits add a line (sh_gunpermit.lua)
	Notify( target, ply:Nick() .. " inspects you." )
	Log.Debug( "police", "%s inspected %s: crate %s, evidence '%s'", ply:Nick(), target:Nick(),
		tostring( result.stolenCrate ), result.evidence )
	return result
end

-- Wanted right now, in an episode that includes a bounty crime.
function Police.TheftWanted( ply )
	local ep = ply.GR_WantedEpisode
	if not ply:IsWanted() or not ep then return false end
	for crime in pairs( ep.crimes ) do
		if Police.BOUNTY_CRIMES[ crime ] then return true end
	end
	return false
end

-- Pays `police` for dealing with a theft-wanted `target`, once per wanted episode.
function Police.Bounty( police, target, how )
	if not isPolice( police ) or police == target or not Police.TheftWanted( target ) then return false end
	local ep = target.GR_WantedEpisode
	if ep.bountyPaid then return false end
	ep.bountyPaid = true
	police:SetTeeth( police:GetTeeth() + Police.BOUNTY_TEETH )
	Notify( police, string.format( "TEETH: %d (%s %s)", police:GetTeeth(), how, target:Nick() ) )
	Log.Debug( "police", "%s earned a bounty on %s (%s)", police:Nick(), target:Nick(), how )
	return true
end

-- A beating is any blunt hit; the consciousness stage is where blunt hits are handled.
Damage.Add( "Consciousness", "police_bounty", function( ply, dmg )
	if bit.band( dmg:GetDamageType(), DMG_CLUB ) == 0 then return end
	Police.Bounty( dmg:GetAttacker(), ply, "beating" )
end )

-- An arrest settles the wanted episode. There is no jail yet; the body stays where it lies.
function Police.Arrest( ply, target )
	if not IsValid( target ) or not target:IsWanted() then
		Notify( ply, "They are not wanted." )
		return false
	end
	Police.Bounty( ply, target, "arresting" )
	local reason = target:GetWantedReason()
	Crime.ClearWanted( target )
	Notify( target, "You have been arrested. Your debt to the People is paid." )
	for _, p in player.Iterator() do
		if p ~= ply and isPolice( p ) then Notify( p, string.format( "%s arrested %s for %s.", ply:Nick(), target:Nick(), reason ) ) end
	end
	Notify( ply, string.format( "You arrest %s for %s.", target:Nick(), reason ) )
	return true
end

-- Spends Teeth on one offer. Returns ok, and why not (already told to the player).
function Police.Buy( ply, item )
	local function refuse( why ) Notify( ply, why ) return false, why end
	local offer
	for _, o in ipairs( Police.OFFERS ) do
		if o.item == item then offer = o break end
	end
	if not offer then return refuse( "The station doesn't stock that." ) end
	if ply:GetTeeth() < offer.teeth then
		return refuse( string.format( "That costs %d teeth. You have %d.", offer.teeth, ply:GetTeeth() ) )
	end
	local ok, why = Inventory.Add( ply, item, 1 )
	if not ok then return refuse( why ) end
	Guns.GiveAmmo( ply, Items.Get( item ).Weapon, Police.OFFER_CLIPS )
	ply:SetTeeth( ply:GetTeeth() - offer.teeth )
	Notify( ply, string.format( "You take a %s. Teeth left: %d.", string.lower( Items.Get( item ).Name ), ply:GetTeeth() ) )
	return true
end

-- A new life lowers the scope.
hook.Add( "GR_FateEnter", "gr_police", function( ply )
	if ply.GR_Scoped then
		ply.GR_Scoped = nil
		ply:SetFOV( 0, 0 )
	end
end )
