-- The original's guns: every gun a sanitar or the Kaiser carried (weapon_gr_<name>, ported from
-- weapon_cc_<name> with the same stats, sounds and models), the original's ammo types, an item for
-- each gun and the Bullets ammo item, and what the sanitation station sells (Police.Buy, sh_police.lua).
--
--   Guns.GUNS            item id -> item fields, in station order then the rest
--   Guns.GiveAmmo        reserve ammo in clips of a weapon class (the station and kits give clips)
--   Police.OFFERS        the original Armory["sanitator"] tiers: 1, 2 and 4 teeth
--
-- A fate's KitAmmo = n gives n clips of reserve for every gun in its Kit (sh_kit.lua); StartTeeth = n
-- sets its teeth when a life starts.
Guns = Guns or {}

-- The original's ammo types (sh_weapons.lua there): name, damage type, player and NPC damage, force.
Guns.AMMO = {
	{ "cc_none", DMG_GENERIC, 0, 0, 0 },
	{ "cc_pistol", DMG_BULLET, 3, 5, 66 },
	{ "cc_smg", DMG_BULLET, 3, 5, 66 },
	{ "cc_rifle", DMG_BULLET, 4, 5, 100 },
	{ "cc_357", DMG_BULLET, 30, 40, 1088.2 },
	{ "cc_sniper", DMG_BULLET, 30, 40, 1088.2 },
	{ "cc_ar2", DMG_BULLET, 3, 8, 66 },
	{ "cc_shotgun", DMG_BULLET, 3, 8, 130.6 },
}
for _, a in ipairs( Guns.AMMO ) do
	game.AddAmmoType( {
		name = a[ 1 ], dmgtype = a[ 2 ], plydmg = a[ 3 ], npcdmg = a[ 4 ], force = a[ 5 ],
		tracer = a[ 1 ] == "cc_rifle" and TRACER_LINE_AND_WHIZ or TRACER_LINE, minsplash = 10, maxsplash = 5,
	} )
end

Guns.GUNS = {
	{ "pacifier", "Pacifier", 4, "A favorite of muggers everywhere." },
	{ "obrez", "Obrez", 6, "A sawed-off bolt-action rifle. A miserable idea for taking down miserable people." },
	{ "brutality", "Brutality", 4, "A handheld mostly-plastic firearm. Popular sidearm among Sanitators everywhere; they originally came from Sepsis Town." },
	{ "coach", "Coach", 12, "Two pipes glued together with a trigger and a heavy, useless piece of wood." },
	{ "bastard", "Bastard", 6, "A very simple blowback submachine gun.\nOne of the oldest weapons still produced in Gangrene." },
	{ "livermann", "Livermann 98", 10, "Gangrene's standard bolt-action rifle. Good for poaching people." },
	{ "candlewood", "Candlewood", 9, "A simple pump-action shotgun." },
	{ "brainpaster", "Brainpaster", 6, "A big pistol for taking down big jerks." },
	{ "trista", "Trista", 7, "A strange submachine gun with a high-capacity cylindrical magazine. It also likes to jam." },
	{ "einhesna", "Einhesna", 6, "A dangerous automatic pistol carbine.\n Despite its shoddy construction, it remains remarkably dangerous, though provides quite a kick." },
	{ "kaptivist", "Kaptivist", 10, "A ridiculously large bore shotgun. It fires a goddamn STORM of pellets towards the enemy, but it also spreads hard. Anything close will die, and anything far away will laugh at you." },
	{ "bodyguard", "Bodyguard", 3, "A small, yet stylish revolver." },
	{ "rattler", "Rattler", 6.5, "A very simple blowback submachine gun. Its barrel is longer which somehow makes it do more damage." },
	{ "painkiller", "Painkiller", 6, "The dead don't feel pain." },
	{ "vengeance", "Vengeance", 12, "Burning vengeance for all who have wrong you." },
	{ "trooper", "Trooper", 10, "A slow firing, but accurate battle rifle with damp recoil." },
	{ "novoluger", "Novoluger", 4, "Stupid expensive but a good pistol" },
}

-- Item models are the guns' world models (weapons aren't registered yet when this loads).
Guns.WORLD_MODEL = {
	kaptivist = "models/tnb/weapons/w_ks23.mdl",
	rattler = "models/tnb/weapons/w_sten.mdl",
	vengeance = "models/tnb/weapons/w_mg3.mdl",
}

-- Guns that can't leave your hands once picked up (the original's SWEP.Droppable = false).
Guns.UNDROPPABLE = { vengeance = true }

for _, g in ipairs( Guns.GUNS ) do
	local class = "weapon_gr_" .. g[ 1 ]
	local stuck = Guns.UNDROPPABLE[ g[ 1 ] ]
	Items.Define( g[ 1 ], {
		Name = g[ 2 ],
		Description = stuck and g[ 4 ] .. "\n It is stuck with you forever." or g[ 4 ],
		Droppable = not stuck,
		Weight = g[ 3 ],
		Model = Guns.WORLD_MODEL[ g[ 1 ] ] or "models/weapons/w_" .. g[ 1 ] .. ".mdl",
		Weapon = class,
		Tags = { Gun = true },
	} )
end

-- Reserve ammo: `clips` clips of the weapon class's ammo.
function Guns.GiveAmmo( ply, class, clips )
	local swep = weapons.GetStored( class )
	if not swep or not swep.Firearm or swep.Primary.ClipSize <= 0 then return 0 end
	local n = swep.Primary.ClipSize * clips
	ply:GiveAmmo( n, swep.Primary.Ammo, true )
	return n
end

-- The original's Bullets: three clips for the gun in hand, never more than three clips held.
-- Picked up while holding a gun with room for them, they load straight in instead of being carried.
Guns.BULLET_CLIPS = 3

local function loadable( ply )
	local wep = ply:GetActiveWeapon()
	if not IsValid( wep ) or not wep.Firearm or wep.Primary.ClipSize <= 0 then return end
	return wep, wep.Primary.ClipSize * Guns.BULLET_CLIPS, ply:GetAmmoCount( wep.Primary.Ammo )
end

local function load( ply, wep, max, have )
	ply:EmitSound( "buttons/weapon_confirm.wav" )
	ply:GiveAmmo( math.min( max, max - have ), wep.Primary.Ammo, true )
end

Items.Define( "pickup_ammo", {
	Name = "Bullets",
	Description = "These were made for you and only you.",
	Weight = 1,
	Model = "models/Items/357ammo.mdl",
	Consumable = true,
	OnUse = function( ply )
		local wep, max, have = loadable( ply )
		if not wep then
			if SERVER then Notify( ply, "Hold a gun to load it." ) end
			return false
		end
		if CLIENT then return end
		if have >= max then
			Chat.Area( ply, Color( 200, 200, 200 ), ply:Nick() .. " scatters bullets on the ground like a moron." )
			return
		end
		load( ply, wep, max, have )
	end,
	OnPickup = function( ply )
		local wep, max, have = loadable( ply )
		if not wep or wep.NoMunitionizer or have >= max then return false end
		load( ply, wep, max, have )
		return true
	end,
} )

-- The station's stock (the original's Armory["sanitator"], guns only). A purchase comes with two clips.
Police.OFFERS = {
	{ item = "pacifier", teeth = 1 },
	{ item = "obrez", teeth = 1 },
	{ item = "brutality", teeth = 1 },
	{ item = "coach", teeth = 1 },
	{ item = "bastard", teeth = 2 },
	{ item = "livermann", teeth = 2 },
	{ item = "candlewood", teeth = 2 },
	{ item = "brainpaster", teeth = 4 },
	{ item = "trista", teeth = 4 },
	{ item = "einhesna", teeth = 4 },
	{ item = "kaptivist", teeth = 4 },
}
Police.OFFER_CLIPS = 2

for _, offer in ipairs( Police.OFFERS ) do
	local def = Items.Get( offer.item )
	Interact.Add( "station_" .. offer.item, {
		label = string.format( "Buy %s (%d teeth)", def.Name, offer.teeth ),
		range = Police.STATION_RANGE,
		show = function( ply, ent )
			return IsValid( ply ) and ply:Alive() and ply:FateHas( "Police" ) and ent:GetClass() == "sanitation_station"
		end,
		run = function( ply ) Police.Buy( ply, offer.item ) end,
	} )
end

-- Drawing a gun: the original's unholster click, pitched per gun.
hook.Add( "GR_Unholstered", "gr_guns_unholster", function( ply, wep )
	if wep.Firearm then ply:EmitSound( "placenta/unholster.wav", 75, wep.UnholsterPitch or 100 ) end
end )

-- A new life as a fate with StartTeeth starts with that many teeth.
hook.Add( "GR_FateEnter", "gr_guns_teeth", function( ply, f, reason )
	if SERVER and f.StartTeeth and not Fates.SameLife( reason ) then ply:SetTeeth( f.StartTeeth ) end
end )
