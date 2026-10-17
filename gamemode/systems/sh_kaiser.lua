-- The Kaiser's tools (step 11.4). Everything is asked of the fate as data, never by name:
--
--   CanSentence      Kaiser.Sentence( ply, target, level ), Kaiser.Forgive( ply, target )
--   Upgrades         { fateId = price }: Kaiser.Upgrade( ply, fateId ) moves the price from the
--                    treasury into Econ.UPGRADE_FUND and sets WorldState "upgrade_<fateId>" = true
--   RunsEconomy      the economy panel (cl_kaiser.lua): Set, Grant, Fine (sv_econ.lua) and the ledger
--
-- Receivers: nKaiserSentence( target, level ), nKaiserForgive( target ), nKaiserUpgrade( fateId ),
-- nKaiserLedger() -> gr_kaiser_ledger. Each one only reads the message; the functions above
-- re-check everything, so tests call them directly.
--
-- Upgrades last one round: GR_EconReset (fired by Econ.ResetRound, which Round.Start calls) sets
-- every upgrade_<fateId> key back to false. Other systems read Kaiser.Upgraded( fateId ).
-- The Kaiser's final death resets the Economy table (sv_econ.lua, GR_FinalDeath).
Kaiser = Kaiser or {}

Kaiser.RANGE = 600        -- sentence and forgive reach this far, or further if the Kaiser can see them
Kaiser.LEDGER_ROWS = 60   -- rows sent to the panel
Kaiser.SENTENCE_REASON = "the Kaiser's sentence"
-- Wanted level -> seconds a sentence lasts.
Kaiser.SENTENCES = {
	[ WANTED_TORMENT ] = 180,
	[ WANTED_JUDGMENT ] = 300,
	[ WANTED_DEATH ] = 300,
}
Kaiser.SENTENCE_NAMES = {
	[ WANTED_TORMENT ] = "torment",
	[ WANTED_JUDGMENT ] = "judgment",
	[ WANTED_DEATH ] = "death",
}
-- Crime name (a wanted reason or an evidence entry, see sh_crime.lua) -> bones the forgiven player
-- pays the treasury. Crimes not listed are forgiven for free.
Kaiser.FORGIVE_COST = {
	[ "theft" ] = 300,
	[ "theft from the People" ] = 300,
}

function Kaiser.Upgraded( fateId ) return WorldState.Get( "upgrade_" .. fateId, false ) == true end

-- The kit. Placeholders: the novoluger is the stock pistol, the book opens the economy panel.
Items.Define( "novoluger", {
	Name = "Novoluger",
	Description = "The Kaiser's own pistol. Polished, loaded, rarely needed.",
	Weight = 2,
	Model = "models/weapons/w_pistol.mdl",
	Weapon = "weapon_pistol",
} )

Items.Define( "strategy_book", {
	Name = "Strategy Book",
	Description = "Ledgers, prices and plans for the city. Only the Kaiser can make sense of it.",
	Weight = 1,
	Model = "models/props_lab/binderblue.mdl",
	OnUse = function( ply )
		if not ply:FateHas( "RunsEconomy" ) then
			Notify( ply, "The figures mean nothing to you." )
			return false
		end
		ply:ConCommand( "gr_kaiser" )
	end,
} )

if CLIENT then return end

-- Server ------------------------------------------------------------------------------------

Net.Pool( "gr_kaiser_ledger" )

local function announce( text )
	for _, p in player.Iterator() do Notify( p, text ) end
	Log.Info( "kaiser", "%s", text )
end

local function living( p ) return IsValid( p ) and p:IsPlayer() and p:Alive() and not p:IsGhost() end

-- Returns true if `ply` may judge `target` now, or false and why (nil why = nothing to tell).
local function canJudge( ply, target )
	if not living( ply ) or not ply:FateHas( "CanSentence" ) then return false end
	if not IsValid( target ) or not target:IsPlayer() or target == ply then return false end
	if not living( target ) then return false, "They are beyond your judgment." end
	local near = ply:GetPos():DistToSqr( target:GetPos() ) <= Kaiser.RANGE * Kaiser.RANGE
	if not near and not Crime.CanSee( ply, target ) then return false, "You can't see them from here." end
	return true
end

local function refuse( ply, why )
	if why and IsValid( ply ) then Notify( ply, why ) end
	return false, why
end

-- Makes `target` wanted at `level` (a WANTED_* constant) for that level's sentence time.
function Kaiser.Sentence( ply, target, level )
	local ok, why = canJudge( ply, target )
	if not ok then return refuse( ply, why ) end
	local duration = Kaiser.SENTENCES[ level ]
	if not duration then return refuse( ply, "There is no such sentence." ) end
	Crime.MakeWanted( target, level, duration, Kaiser.SENTENCE_REASON )
	Notify( ply, string.format( "You sentenced %s to %s.", target:Nick(), Kaiser.SENTENCE_NAMES[ level ] ) )
	Log.Info( "kaiser", "%s sentenced %s to %s", ply:Nick(), target:Nick(), Kaiser.SENTENCE_NAMES[ level ] )
	return true
end

-- Clears `target`'s wanted status and evidence. The dearest crime among them sets the price,
-- which the forgiven player pays to the treasury; if they can't, nothing is forgiven.
-- Returns true and the price paid, or false and why.
function Kaiser.Forgive( ply, target )
	local ok, why = canJudge( ply, target )
	if not ok then return refuse( ply, why ) end

	local crimes = {}
	if target:IsWanted() then table.insert( crimes, target:GetWantedReason() ) end
	for crime in pairs( Crime.Evidence( target ) ) do table.insert( crimes, crime ) end
	if #crimes == 0 then return refuse( ply, "They have done nothing to forgive." ) end

	local cost = 0
	for _, crime in ipairs( crimes ) do cost = math.max( cost, Kaiser.FORGIVE_COST[ crime ] or 0 ) end
	if cost > 0 and not Econ.Transfer( target, Econ.TREASURY, cost, "forgiveness" ) then
		Notify( target, string.format( "Forgiveness costs %d bones, and you can't pay it.", cost ) )
		return refuse( ply, string.format( "%s can't pay the %d bones forgiveness costs.", target:Nick(), cost ) )
	end

	Crime.ClearWanted( target )
	for _, crime in ipairs( crimes ) do Crime.TakeEvidence( target, crime ) end
	Notify( target, cost > 0 and string.format( "The Kaiser forgives you, for %d bones.", cost ) or "The Kaiser forgives you." )
	Notify( ply, string.format( "You forgave %s.", target:Nick() ) )
	Log.Info( "kaiser", "%s forgave %s (%s) for %d", ply:Nick(), target:Nick(), table.concat( crimes, ", " ), cost )
	return true, cost
end

-- Buys the upgrade for `fateId` at the price in the buyer's Upgrades table. Returns ok, why.
function Kaiser.Upgrade( ply, fateId )
	local prices = living( ply ) and ply:FateHas( "Upgrades" )
	if not istable( prices ) then return false end
	local price = isstring( fateId ) and prices[ fateId ]
	if not isnumber( price ) or not Fates.Get( fateId ) then return refuse( ply, "There is no such upgrade." ) end
	if Kaiser.Upgraded( fateId ) then return refuse( ply, "That upgrade is already bought this round." ) end

	if not Econ.Transfer( Econ.TREASURY, Econ.UPGRADE_FUND, price, "upgrade " .. fateId ) then
		return refuse( ply, string.format( "The treasury can't cover the %d bones this upgrade costs.", price ) )
	end
	WorldState.Set( "upgrade_" .. fateId, true )
	hook.Run( "GR_FateUpgraded", fateId, ply )
	announce( string.format( "The Kaiser has invested in the %s.", Fates.Get( fateId ).Name ) )
	return true
end

-- Every upgrade_<fateId> key goes back to false for the new round. The fund itself is emptied
-- by Econ.ResetRound, which refills the treasury with the whole supply.
function Kaiser.ResetUpgrades()
	for _, f in ipairs( Fates.All() ) do
		if WorldState.Get( "upgrade_" .. f.id ) ~= nil then WorldState.Set( "upgrade_" .. f.id, false ) end
	end
end
hook.Add( "GR_EconReset", "gr_kaiser", Kaiser.ResetUpgrades )

-- The panel's ledger view: the newest rows and the treasury's flows.
function Kaiser.SendLedger( ply )
	local rows = Econ.Ledger( Kaiser.LEDGER_ROWS )
	local inflow, outflow = Econ.Flows()
	net.Start( "gr_kaiser_ledger" )
	net.WriteUInt( #rows, 8 )
	for _, e in ipairs( rows ) do
		net.WriteFloat( e.t )
		net.WriteString( e.from )
		net.WriteString( e.to )
		net.WriteUInt( e.amount, 24 )
		net.WriteString( e.source )
	end
	for _, flow in ipairs( { inflow, outflow } ) do
		net.WriteUInt( table.Count( flow ), 8 )
		for source, n in pairs( flow ) do
			net.WriteString( source )
			net.WriteUInt( n, 24 )
		end
	end
	net.Send( ply )
	return #rows
end

Net.Receive( "nKaiserSentence", { rate = 2, alive = true, fate = "CanSentence", target = "player" }, function( ply, target )
	Kaiser.Sentence( ply, target, net.ReadUInt( 2 ) )
end )

Net.Receive( "nKaiserForgive", { rate = 2, alive = true, fate = "CanSentence", target = "player" }, function( ply, target )
	Kaiser.Forgive( ply, target )
end )

Net.Receive( "nKaiserUpgrade", { rate = 2, alive = true, fate = "Upgrades" }, function( ply )
	Kaiser.Upgrade( ply, Net.ReadString() )
end )

Net.Receive( "nKaiserLedger", { rate = 1, alive = true, fate = "RunsEconomy" }, function( ply )
	Kaiser.SendLedger( ply )
end )

hook.Add( "PlayerSay", "gr_kaiser", function( ply, text )
	local cmd = string.lower( string.Trim( text ) )
	if cmd == "/kaiser" or cmd == "!kaiser" then
		ply:ConCommand( "gr_kaiser" )
		return ""
	end
end )
