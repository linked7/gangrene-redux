-- Munitionizers, ported from the original's munitionizer.lua. Proles build them (Build, sh_build.lua).
-- It holds up to MAX_KITS kits, one more every REPLENISH s (the first 5 s after it is built). Use it
-- holding a gun: one kit is one clip of the gun's reserve ammo (Guns.AMMO types), never more than
-- three clips held. It costs PRICE bones, DEPLOYER_PRICE for its builder and POLICE_PRICE for police;
-- the bones go to the builder (the original's "The Violence"), or to the treasury when the builder
-- uses it, or is dead or gone. Shot down (INTEGRITY), it breaks into scrap.
--
--   Munitionizer.Price( ply, ent )   shared: what `ply` pays at `ent`
--   Munitionizer.Use( ply, ent )     server: buy a clip; returns true, or false and why
Munitionizer = Munitionizer or {}
Munitionizer.MAX_KITS = 15
Munitionizer.REPLENISH = 45
Munitionizer.FIRST_REPLENISH = 5
Munitionizer.INTEGRITY = 200
Munitionizer.PRICE = 25
Munitionizer.DEPLOYER_PRICE = 10
Munitionizer.POLICE_PRICE = 15
Munitionizer.SHELL_GAP = 0.075 -- spent shells fly out one at a time

function Munitionizer.Price( ply, ent )
	local d = ent:GetDeployer()
	if IsValid( d ) and d:Alive() and d == ply then return Munitionizer.DEPLOYER_PRICE end
	if ply:FateHas( "Police" ) then return Munitionizer.POLICE_PRICE end
	return Munitionizer.PRICE
end

if CLIENT then return end

-- Registry: ent -> true (no world searches, P2).
local all = Munitionizer.all or setmetatable( {}, { __mode = "k" } )
Munitionizer.all = all
function Munitionizer.Track( ent ) all[ ent ] = true end

local SHELLS = { cc_smg = "ShellEject", cc_pistol = "ShellEject", cc_shotgun = "ShotgunShellEject" }

local function refuse( ply, ent, why )
	Notify( ply, why )
	ent:EmitSound( "buttons/weapon_cant_buy.wav" )
	return false, why
end

function Munitionizer.Use( ply, ent )
	if not IsValid( ply ) or not ply:Alive() or ply:IsGhost() then return false, "not alive" end
	local wep = ply:GetActiveWeapon()
	if not IsValid( wep ) or not wep.Firearm or not wep.Primary or wep.Primary.ClipSize <= 0 then
		return refuse( ply, ent, "You must be wielding a firearm to interface with this." )
	end
	if wep.NoMunitionizer then return refuse( ply, ent, "This weapon does not interface with Munitionizers." ) end
	if ent:GetKits() <= 0 then return refuse( ply, ent, "The screen clearly says it's empty!" ) end
	local clip, ammo = wep.Primary.ClipSize, wep.Primary.Ammo
	local have, max = ply:GetAmmoCount( ammo ), wep.Primary.ClipSize * 3
	if have >= max then return refuse( ply, ent, "You're full." ) end

	local cost = Munitionizer.Price( ply, ent )
	local d = ent:GetDeployer()
	local payee = ( IsValid( d ) and d:Alive() and not d:IsGhost() and d ~= ply ) and d or Econ.TREASURY
	if ply:GetBones() < cost or not Econ.Transfer( ply, payee, cost, "munitionizer" ) then
		return refuse( ply, ent, "You're poor." )
	end

	ent:EmitSound( "buttons/weapon_confirm.wav" )
	ply:GiveAmmo( math.min( clip, max - have ), ammo, true )
	ent:SetKits( ent:GetKits() - 1 )
	if ply:GetAmmoCount( ammo ) >= max then Notify( ply, "Fully loaded." ) end
	ent.GR_Shells = clip
	ent.GR_ShellKind = SHELLS[ ammo ] or "RifleShellEject"
	ent.GR_ShellAng = Angle( 45, math.random( 0, 360 ), -15 )
	return true
end

-- Kits come back over time.
Sched.Every( "munitionizer_restock", 1, function()
	local now = CurTime()
	for ent in pairs( all ) do
		if IsValid( ent ) then
			ent.GR_NextKit = ent.GR_NextKit or now + Munitionizer.FIRST_REPLENISH
			if now >= ent.GR_NextKit then
				ent.GR_NextKit = now + Munitionizer.REPLENISH
				if ent:GetKits() < Munitionizer.MAX_KITS then
					ent:EmitSound( "items/ammopickup.wav" )
					ent:SetKits( ent:GetKits() + 1 )
				end
			end
		end
	end
end )

-- Spent shells, one per round loaded, out of the top.
Sched.Every( "munitionizer_shells", Munitionizer.SHELL_GAP, function()
	for ent in pairs( all ) do
		if IsValid( ent ) and ( ent.GR_Shells or 0 ) > 0 then
			ent.GR_Shells = ent.GR_Shells - 1
			local fx = EffectData()
			fx:SetOrigin( ent:GetPos() + ent:GetUp() * 48 )
			fx:SetAngles( ent.GR_ShellAng )
			fx:SetFlags( 0 )
			util.Effect( ent.GR_ShellKind, fx )
		end
	end
end )

function Munitionizer.Damaged( ent, dmg )
	local fx = EffectData()
	fx:SetStart( dmg:GetDamagePosition() )
	fx:SetOrigin( dmg:GetDamagePosition() )
	fx:SetScale( 1 )
	util.Effect( "Sparks", fx )
	util.Effect( "GlassImpact", fx, true, true )
	if dmg:GetDamageType() == DMG_CRUSH or ent.GR_Broken then return end
	ent:SetIntegrity( ent:GetIntegrity() - dmg:GetDamage() )
	if ent:GetIntegrity() > 0 then return end
	ent.GR_Broken = true
	local pos = ent:GetPos()
	fx = EffectData()
	fx:SetStart( pos )
	fx:SetOrigin( pos )
	fx:SetScale( 8 )
	util.Effect( "GlassImpact", fx, true, true )
	ent:EmitSound( "physics/metal/metal_box_break" .. math.random( 1, 2 ) .. ".wav", 75, math.random( 80, 110 ), 0.6 )
	Items.SpawnMany( { "scrap" }, pos + Vector( 0, 0, 20 ) ) -- the original's metal slag
	ent:Remove()
end
