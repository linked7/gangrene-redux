-- Autostitchers, ported from the original's autostitcher.lua (plan step 11, the Korpsman). Wall
-- chargers placed by the map layout. A trip costs PRICE bones plus sales tax (Econ "sales_tax"), or
-- one permit_medical; the patient is hooked up and healed HEAL hp, Pox -3, every TICK s while they can
-- see it and are hurt. Parasites come out for PARASITE_PRICE each. Korpsmen recharge it with their
-- Lovebox out (or by smacking it) and get COMPASSION bones from the treasury; anyone else smacking an
-- empty one may force a charge, and always leaves evidence of illegal tinkering.
--
--   Autostitcher.Price()             shared: the trip's price, tax included
--   Autostitcher.Use( ply, ent )     server: returns true, or false and why
--   Autostitcher.Damaged( ent, dmg ) server
Autostitcher = Autostitcher or {}
Autostitcher.MAX_CHARGES = 3
Autostitcher.PRICE = 50
Autostitcher.PARASITE_PRICE = 30
Autostitcher.COMPASSION = 35
Autostitcher.TICK = 5
Autostitcher.HEAL = 6

function Autostitcher.Price()
	local tax = Econ and Econ.Setting and Econ.Setting( "sales_tax" ) or 0
	return math.floor( Autostitcher.PRICE + Autostitcher.PRICE * tax / 100 )
end

if CLIENT then return end

-- Registry: ent -> true (no world searches).
local all = Autostitcher.all or setmetatable( {}, { __mode = "k" } )
Autostitcher.all = all
function Autostitcher.Track( ent ) all[ ent ] = true end

local RED, GREEN = Color( 255, 0, 0 ), Color( 0, 255, 0 )

local function no( ply, ent, text )
	if text then Chat.Tell( ply, RED, text, 1 ) end
	ent:EmitSound( "items/medshotno1.wav" )
	return false, text
end

local function payParasite( ply )
	return ply:GetBones() >= Autostitcher.PARASITE_PRICE
		and Econ.Transfer( ply, Econ.TREASURY, Autostitcher.PARASITE_PRICE, "autostitcher" )
end

local function slash( ply, ent, n )
	local d = DamageInfo()
	d:SetDamage( n )
	d:SetDamageType( DMG_SLASH )
	d:SetAttacker( ent )
	d:SetInflictor( ent )
	ply:TakeDamageInfo( d )
end

-- Tears one parasite out; `hurt` (the hooked-up patient) also takes 15, never past half health.
function Autostitcher.RemoveParasite( ply, ent, hurt )
	Medicine.SetParasites( ply, Medicine.Parasites( ply ) - 1 )
	Chat.Area( ply, RED, "A surgical " .. ( hurt and "hand" or "claw" ) .. " tears the parasite out of " .. ply:Nick() .. "!" )
	local pos = ent:GetPos() + ent:GetUp() * 32
	Items.Spawn( "parasite", 1, pos, Angle() )
	ent:EmitSound( "ambient/machines/slicer" .. math.random( 2, 3 ) .. ".wav", 75, math.random( 80, 90 ) )
	if hurt then ply:SetHealth( math.max( math.floor( ply:Health() / 2 ), ply:Health() - 15 ) ) end
	for _ = 1, 3 do
		local g = ents.Create( "prop_physics" )
		if IsValid( g ) then
			g:SetModel( "models/gibs/hgibs_" .. ( { "rib", "scapula", "spine" } )[ math.random( 3 ) ] .. ".mdl" )
			g:SetPos( pos + VectorRand() * 4 )
			g:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
			g:Spawn()
			SafeRemoveEntityDelayed( g, math.random( 55, 65 ) )
		end
	end
end

function Autostitcher.Unhook( ent )
	local p = ent:GetPatient()
	ent:SetPatient( NULL )
	ent:EmitSound( "npc/turret_floor/die.wav", 75, 70 )
	local fx = EffectData()
	fx:SetOrigin( ent:GetPos() + ent:GetForward() * 6 + ent:GetRight() * 2.4 )
	util.Effect( "StunstickImpact", fx )
	if IsValid( p ) and p:IsPlayer() then Chat.Tell( p, GREEN, "I feel better but not much." ) end
end

local function korpsmanCharge( ply, ent, dmg )
	ent:EmitSound( "items/gift_drop.wav", 75, math.random( 70, 90 ) )
	slash( ply, ent, dmg )
	ent:SetCharges( ent:GetCharges() + 1 )
	Econ.Transfer( Econ.TREASURY, ply, Autostitcher.COMPASSION, "compassion" )
end

function Autostitcher.Use( ply, ent )
	if not IsValid( ply ) or not ply:Alive() or ply:IsGhost() then return false, "not alive" end
	local wep = ply:GetActiveWeapon()
	if ply:FateHas( "Surgeon" ) and IsValid( wep ) and wep:GetClass() == "weapon_gr_lovebox" then
		if ent:GetCharges() >= Autostitcher.MAX_CHARGES then return no( ply, ent, "It can't hold any more charges." ) end
		if ent:GetPatient() == ply then
			slash( ply, ent, 15 )
			return no( ply, ent, "Don't be silly." )
		end
		korpsmanCharge( ply, ent, 20 )
		return true
	end

	local cost = Autostitcher.Price()
	local permit = Inventory.Count( ply, "permit_medical" ) > 0
	local parasites = Medicine.Parasites( ply )
	if ent:GetCharges() <= 0 then return no( ply, ent, "It has no more charges." ) end
	if ply:GetBones() < cost and not permit and not IsValid( ent:GetPatient() ) then
		return no( ply, ent, "It sucks to be poor! A healing trip costs " .. cost .. " Bones." )
	end
	if ply:Health() >= Medicine.MaxHealth( ply ) then
		if parasites > 0 then
			if permit then
				Inventory.Remove( ply, "permit_medical", 1 )
				Autostitcher.RemoveParasite( ply, ent )
				return true
			end
			if payParasite( ply ) then Autostitcher.RemoveParasite( ply, ent ) return true end
			return no( ply, ent, "It SUCKS to be poor!" )
		end
		return no( ply, ent, "I don't need treatment." )
	end
	if ply:FateHas( "NoInventory" ) then return no( ply, ent, "My body won't accept treatment." ) end
	local p = ent:GetPatient()
	if IsValid( p ) then
		if p == ply then
			if parasites > 0 then
				if payParasite( ply ) then Autostitcher.RemoveParasite( ply, ent, true ) return true end
				return no( ply, ent, "It SUCKS to be poor!" )
			end
			Chat.Tell( ply, GREEN, "Thankfully, my body is free of creatures!" )
			return no( ply, ent )
		end
		return no( ply, ent, "I need to wait my turn." )
	end

	if permit then
		Inventory.Remove( ply, "permit_medical", 1 )
	elseif not Econ.Transfer( ply, Econ.TREASURY, cost, "autostitcher" ) then
		return no( ply, ent, "It sucks to be poor! A healing trip costs " .. cost .. " Bones." )
	end
	ent:SetCharges( ent:GetCharges() - 1 )
	ent:SetPatient( ply )
	ent.GR_NextHeal = CurTime() + Autostitcher.TICK
	ent:EmitSound( "items/medshot4.wav" )
	hook.Run( "GR_Objective", ply, 1, "use_autostitcher" )
	return true
end

-- The patient heals while hooked up and in sight of it.
Sched.Every( "autostitcher_heal", 0.5, function()
	local now = CurTime()
	for ent in pairs( all ) do
		local p = IsValid( ent ) and ent:GetPatient()
		if IsValid( p ) then
			if not p:Alive() or p:IsGhost() or not p:Visible( ent ) or p:Health() >= Medicine.MaxHealth( p ) then
				Autostitcher.Unhook( ent )
			elseif now >= ( ent.GR_NextHeal or 0 ) then
				ent.GR_NextHeal = now + Autostitcher.TICK
				ent:EmitSound( "items/medshot4.wav", 50, 50 + 50 * p:Health() / 100 )
				local fx = EffectData()
				fx:SetOrigin( p:GetPos() + Vector( 0, 0, 40 ) )
				util.Effect( "GunshipImpact", fx )
				Medicine.Heal( p, Autostitcher.HEAL )
				Needs.Add( p, "Pox", -3, "autostitcher" )
			end
		end
	end
end )

function Autostitcher.Damaged( ent, dmg )
	if bit.band( dmg:GetDamageType(), DMG_CLUB ) == 0 then return end
	local fx = EffectData()
	fx:SetOrigin( dmg:GetDamagePosition() )
	fx:SetStart( dmg:GetDamagePosition() )
	util.Effect( "Sparks", fx )
	if ent:GetCharges() >= Autostitcher.MAX_CHARGES then return end
	local ply = dmg:GetAttacker()
	if not IsValid( ply ) or not ply:IsPlayer() then return end
	if ply:FateHas( "Surgeon" ) and ply:Alive() then korpsmanCharge( ply, ent, 25 ) return end
	if math.random( 1, 420 ) < 25 and not ply:FateHas( "Police" ) and not ply:FateHas( "RunsEconomy" ) and ent:GetCharges() == 0 then
		Chat.Big( ply, Color( 212, 0, 148 ), "Tough Love." )
		ent:SetCharges( 1 )
		ent:EmitSound( "items/battery_pickup.wav", 85, 50, 0.75 )
	end
	Crime.AddEvidence( ply, "illegal tinkering", 1, 120 )
end
