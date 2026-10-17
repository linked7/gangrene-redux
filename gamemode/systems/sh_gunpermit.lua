-- Gun permits: a Redux invention, not the original's weapon sales permit. The Kaiser issues one to a
-- player from the Kaiser menu; it lets them own and hold guns legally.
--
--   GunPermit (PUBLIC String)   the name it was issued to; "" = none. Cleared with each new life.
--   GunPermit.Legal( ply )      may hold a firearm: police, the sovereign, or a permit issued to
--                               them that they still carry (a found permit is someone else's paper)
--   GunPermit.Issue / Revoke    the Kaiser issues and revokes; police can revoke (Interact)
--
-- Holding a firearm without one is a crime (Crime.Report "armed"): evidence, or wanted when police see it.
GunPermit = GunPermit or {}

GunPermit.ITEM = "gun_permit"
GunPermit.CRIME = "being armed without a permit"
GunPermit.SOUND = "physics/cardboard/cardboard_box_impact_soft2.wav"

State.Field( "GunPermit", "String", 0, State.PUBLIC, "" )

Items.Define( GunPermit.ITEM, {
	Name = "Gun Permit",
	Description = "By order of the Witch Kaiser, the named citizen may own and carry firearms. Worthless in anyone else's hands.",
	Weight = 0.1,
	Model = "models/props_c17/paper01.mdl",
	Tags = { Permit = true },
} )

local function living( p ) return IsValid( p ) and p:IsPlayer() and p:Alive() and not p:IsGhost() end

function GunPermit.Exempt( ply ) return ply:FateHas( "Police" ) or ply:FateHas( "Sovereign" ) end

function GunPermit.Has( ply )
	return ply:GetGunPermit() ~= "" and Inventory.Count( ply, GunPermit.ITEM ) > 0
end

function GunPermit.Legal( ply ) return GunPermit.Exempt( ply ) or GunPermit.Has( ply ) end

-- The firearm `ply` holds, if any.
function GunPermit.Firearm( ply )
	if CLIENT then -- the client only knows other players' active weapons
		local w = ply:GetActiveWeapon()
		return IsValid( w ) and w.Firearm and w or nil
	end
	for _, w in ipairs( ply:GetWeapons() ) do
		if w.Firearm then return w end
	end
end

-- The law: seen armed by police is wanted at once; otherwise it is evidence for an inspection.
if SERVER then
	table.insert( Crime.ReportRules, 2, { name = "armed_caught", crime = GunPermit.CRIME, wanted = WANTED_TORMENT, duration = 180,
		when = function( ply, act ) return act == "armed" and not ply:IsWanted() and Crime.SeenByPolice( ply ) end } )
	table.insert( Crime.ReportRules, 3, { name = "armed", crime = GunPermit.CRIME, evidence = WANTED_TORMENT, duration = 120,
		when = function( _, act ) return act == "armed" end } )
end

local function refuse( ply, why )
	if why and IsValid( ply ) then Notify( ply, why ) end
	return false, why
end

-- The Kaiser hands `target` a permit in their name. Free. Returns ok, why.
function GunPermit.Issue( ply, target )
	if not living( ply ) or not ply:FateHas( "CanSentence" ) then return refuse( ply ) end
	if not living( target ) or target == ply then return refuse( ply, "They can't take a permit." ) end
	if GunPermit.Exempt( target ) then return refuse( ply, "They need no permit." ) end
	if GunPermit.Has( target ) then return refuse( ply, "They already hold a permit." ) end
	local ok, why = Inventory.Add( target, GunPermit.ITEM, 1, true )
	if not ok then return refuse( ply, why ) end
	target:SetGunPermit( target:Nick() )
	target:EmitSound( GunPermit.SOUND )
	Notify( target, "The Kaiser grants you a gun permit. Carry it." )
	Notify( ply, string.format( "You issued %s a gun permit.", target:Nick() ) )
	Log.Info( "gunpermit", "%s issued %s a gun permit", ply:Nick(), target:Nick() )
	return true
end

-- The Kaiser or police take it back: the paper is torn up wherever it is in their pockets.
function GunPermit.Revoke( ply, target )
	if not living( ply ) or not ( ply:FateHas( "CanSentence" ) or ply:FateHas( "Police" ) ) then return refuse( ply ) end
	if not IsValid( target ) or not target:IsPlayer() then return refuse( ply ) end
	if target:GetGunPermit() == "" then return refuse( ply, "They hold no permit." ) end
	target:SetGunPermit( "" )
	local n = Inventory.Count( target, GunPermit.ITEM )
	if n > 0 then Inventory.Remove( target, GunPermit.ITEM, n ) end
	target:EmitSound( GunPermit.SOUND )
	Notify( target, ply:Nick() .. " revokes your gun permit." )
	Notify( ply, string.format( "You revoked %s's gun permit.", target:Nick() ) )
	Log.Info( "gunpermit", "%s revoked %s's gun permit", ply:Nick(), target:Nick() )
	return true
end

Interact.Add( "revoke_permit", {
	label = "Revoke gun permit",
	range = 120,
	show = function( ply, ent )
		return ply:FateHas( "Police" ) and ent ~= ply and living( ent ) and ent:GetGunPermit() ~= ""
	end,
	run = function( ply, ent ) GunPermit.Revoke( ply, ent ) end,
} )

if SERVER then
	-- Kaiser menu: issue (true) or revoke (false), in person.
	Net.Receive( "nKaiserPermit", { rate = 2, alive = true, fate = "CanSentence", target = "player", range = Kaiser.RANGE },
		function( ply, target )
			if net.ReadBool() then GunPermit.Issue( ply, target ) else GunPermit.Revoke( ply, target ) end
		end )

	function GunPermit.Tick( ply )
		if not living( ply ) or GunPermit.Legal( ply ) or not GunPermit.Firearm( ply ) then return end
		Crime.Report( ply, "armed" )
	end
	Sched.EachPlayer( "gunpermit", 1, function( ply ) GunPermit.Tick( ply ) end )

	-- Police inspections read the permit.
	hook.Add( "GR_Inspected", "gr_gunpermit", function( ply, target )
		local name = target:GetGunPermit()
		if name ~= "" then Notify( ply, "They carry a gun permit made out to " .. name .. "." ) end
	end )
	return
end

-- Cross-text over an armed player: their permit, or the lack of one.
hook.Add( "GR_CrossTexts", "gr_gunpermit", function( ent, me, ct )
	if not ent:IsPlayer() or ent:IsGhost() then return end
	local name = ent:GetGunPermit()
	local armed = GunPermit.Firearm( ent ) ~= nil
	if name ~= "" and ( armed or me:FateHas( "Police" ) or me:FateHas( "CanSentence" ) ) then
		table.insert( ct, { text = "Gun permit: " .. name, color = Color( 200, 200, 200 ) } )
	elseif armed and not GunPermit.Exempt( ent ) then
		table.insert( ct, { text = "Armed without a permit", color = Color( 220, 40, 40 ) } )
	end
end )
