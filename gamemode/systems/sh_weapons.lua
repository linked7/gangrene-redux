-- Weapon feel (§9 of docs/05-ui-effects-parity.md), around weapon_gr_base (entities/weapons/):
--
--   Holstered   PUBLIC field, true at the start of every life and on every weapon switch. B (or the
--               rp_toggleholster bind) toggles it; Use + Reload holsters and checks your ammo.
--   Speed       a drawn weapon multiplies speed by its MovementMult (x0.5 by default) and stops
--               sprinting unless SprintUnholstered: the "weapon" entry in Fates.SpeedMods.
--   Spread      Weapons.SpreadMultiplier( ply ): the original's BulletAccuracyModifier, with its bug.
--               Weapons.Spread( ply ) is the current cone of the gun in hand, for the HUD's crosshair.
--   Spit        G spits on whoever is in front of you; with a gun out G is the melee shove instead.
--   Pickup      holstered right-click lifts props up to 115 kg within 84 units (Weapons.CanCarry).
--   Head burst  a melee hit near a body's head has a 10% chance to burst it (Weapons.TryHeadBurst).
--
-- Everyone alive gets weapon_gr_hands. Other systems can listen to
--   GR_MeleeHit( attacker, ent, dmginfo, trace, weapon )   after a melee swing lands (server)
-- F3 (gm_showspare1) opens the player menu (gr_inventory); ghosts are told their stem cells.
Weapons = Weapons or {}

State.Field( "Holstered", "Bool", 0, State.PUBLIC, true )

Weapons.HANDS = "weapon_gr_hands"
Weapons.SHOVE_RANGE = 70
Weapons.SPIT_RANGE = 200
Weapons.SPIT_COOLDOWN = 1
Weapons.SPIT_DESPAIR_CAP = 80 -- spit alone stops adding despair here, short of a heart attack
Weapons.HEAD_BURST_CHANCE = 0.1
Weapons.HEAD_BURST_DIST_SQR = 40 -- the original compares DistToSqr with 40 (about 6 units), kept as is

-- The active weapon if it is one of ours.
function Weapons.Active( ply )
	local wep = ply:GetActiveWeapon()
	if IsValid( wep ) and wep.GR_Base then return wep end
end

-- The original's BulletAccuracyModifier. `s` may stand in for the player's movement in tests:
-- { onGround = bool, speed = number, crouched = bool }.
function Weapons.SpreadMultiplier( ply, s, wep )
	local onGround, speed, crouched
	if s then
		onGround, speed, crouched = s.onGround ~= false, s.speed or 0, s.crouched == true
	else
		onGround, speed, crouched = ply:OnGround(), ply:GetVelocity():Length(), ply:Crouching()
	end
	local m = 0.7
	local acc = ply:FateHas( "AccuracyMulti" )
	if isnumber( acc ) and not ( wep and wep.IgnoreFateInacc ) then m = m * acc end
	if not onGround then m = m * 5 end
	-- The original's "recovering" injury (x1.3). The remake has one injury, Injured (sh_corpse.lua);
	-- injury 1 (x1.1) and injury 2 (x1.7) come back if those injuries do.
	if ply.GetInjured and ply:GetInjured() then m = m * 1.3 end
	if not ( wep and wep.IgnoreMovementInacc ) then
		-- Deliberate: the original checks > 10 before > 80, so the x2.5 "moving fast" branch never
		-- runs and any movement is x1.5 (docs/05 §9). Parity keeps the bug; don't swap the order.
		if speed > 10 then
			m = m * 1.5
		elseif speed > 80 then
			m = m * 2.5
		end
	end
	if crouched and onGround then m = m * 0.65 end
	return m
end

-- The cone the gun in hand would fire with right now (0 with no gun out). For the HUD crosshair.
function Weapons.Spread( ply )
	local wep = Weapons.Active( ply )
	if not wep or not wep.Firearm or not wep:IsOut() then return 0 end
	return ( wep.Primary.Accuracy or 0 ) * Weapons.SpreadMultiplier( ply, nil, wep )
end

-- Whether a holstered hand can lift `ent`: a loose, moveable prop no heavier than maxMass.
function Weapons.CanCarry( ent, maxMass )
	if not IsValid( ent ) or ent:IsPlayer() or ent:IsNPC() or ent:IsWorld() then return false end
	if ent.GR_Holder or ent:IsPlayerHolding() then return false end
	local phys = ent:GetPhysicsObject()
	if not IsValid( phys ) or not phys:IsMoveable() then return false end
	return phys:GetMass() <= ( maxMass or 115 )
end

if CLIENT then
	-- Use + Reload shows your ammo for two seconds; the HUD reads Weapons.AmmoCheck().
	Weapons.ammoCheckUntil = 0
	function Weapons.AmmoCheck() return CurTime() < Weapons.ammoCheckUntil end

	local function holster( mode )
		local ply = LocalPlayer()
		if not IsValid( ply ) or ply:GetPassedOut() then return end
		net.Start( "gr_holster" )
		net.WriteUInt( mode, 2 )
		net.SendToServer()
	end
	concommand.Add( "rp_toggleholster", function() holster( 0 ) end )

	local bHeld, gHeld = false, false
	hook.Add( "Think", "gr_weapons_keys", function()
		if vgui.CursorVisible() or gui.IsGameUIVisible() then
			bHeld, gHeld = false, false
			return
		end
		local b, g = input.IsKeyDown( KEY_B ), input.IsKeyDown( KEY_G )
		if b and not bHeld then holster( 0 ) end
		if g and not gHeld and IsValid( LocalPlayer() ) and LocalPlayer():Alive() then
			net.Start( "gr_spit" )
			net.SendToServer()
		end
		bHeld, gHeld = b, g
	end )

	hook.Add( "PlayerBindPress", "gr_weapons", function( ply, bind, pressed )
		if not pressed then return end
		if string.find( bind, "+reload", 1, true ) and ply:KeyDown( IN_USE ) then
			Weapons.ammoCheckUntil = CurTime() + 2
			holster( 1 )
			return true
		end
		if string.find( bind, "gm_showspare1", 1, true ) then
			if ply:IsGhost() or not ply:Alive() then
				chat.AddText( Color( 200, 0, 0 ), "You have " .. ply:GetStemCells() .. " stem cells." )
			else
				RunConsoleCommand( "gr_inventory" )
			end
			return true
		end
	end )

	-- A spit: a few droplets along the arc.
	Net.Receive( "gr_spit", nil, function()
		local from, to = net.ReadVector(), net.ReadVector()
		local em = ParticleEmitter( from )
		if not em then return end
		for i = 1, 6 do
			local p = em:Add( "effects/blood_core", from )
			if p then
				p:SetVelocity( ( to - from ):GetNormalized() * math.Rand( 250, 350 ) + VectorRand() * 10 )
				p:SetDieTime( 0.6 )
				p:SetStartAlpha( 180 )
				p:SetEndAlpha( 0 )
				p:SetStartSize( math.Rand( 0.6, 1.2 ) )
				p:SetEndSize( 0.2 )
				p:SetColor( 220, 220, 200 )
				p:SetGravity( Vector( 0, 0, -400 ) )
			end
		end
		em:Finish()
	end )
	return
end

Net.Pool( "gr_spit" )

-- A drawn weapon slows you (MovementMult) and stops you sprinting (SprintUnholstered).
Fates.SpeedMods.weapon = function( ply )
	if ply:GetHolstered() then return 1 end
	local wep = Weapons.Active( ply )
	if not wep then return 1 end
	return wep.MovementMult or 1, not wep.SprintUnholstered
end

function Weapons.SetHolstered( ply, holstered )
	local wep = ply:GetActiveWeapon()
	if IsValid( wep ) and wep.Holsterable == false then holstered = false end
	if ply:GetHolstered() == holstered then return end
	ply:SetHolstered( holstered )
	if IsValid( wep ) then wep:SetNextPrimaryFire( CurTime() + 0.6 ) end
	Fates.ApplySpeed( ply )
	if not holstered and IsValid( wep ) then hook.Run( "GR_Unholstered", ply, wep ) end
end

function Weapons.ToggleHolster( ply )
	if ply:GetPassedOut() or ply:IsGhost() or not ply:Alive() then return end
	Weapons.SetHolstered( ply, not ply:GetHolstered() )
end

-- mode 0 toggles, 1 holsters (Use + Reload).
Net.Receive( "gr_holster", { rate = 6, alive = true }, function( ply )
	local mode = net.ReadUInt( 2 )
	if ply:GetPassedOut() then return end
	if mode == 1 then Weapons.SetHolstered( ply, true ) else Weapons.ToggleHolster( ply ) end
end )

-- Switching weapons puts the new one away.
-- Returns nothing, so it never decides whether the switch happens (sh_crates.lua does that).
hook.Add( "PlayerSwitchWeapon", "gr_weapons", function( ply )
	if not IsValid( ply ) or ply:GetHolstered() then return end
	ply:SetHolstered( true )
	if ply:Alive() then Fates.ApplySpeed( ply ) end
end )

-- A weapon taken away, or dropped, while drawn: the speed follows within a tick.
Sched.EachPlayer( "weapon_speed", 0.25, function( ply )
	local wep = ply:GetActiveWeapon()
	local key = ( IsValid( wep ) and wep:GetClass() or "" ) .. ( ply:GetHolstered() and "h" or "d" )
	if ply.GR_WeaponKey ~= key then
		ply.GR_WeaponKey = key
		if ply:Alive() then Fates.ApplySpeed( ply ) end
	end
end )

hook.Add( "GR_FateEnter", "gr_weapons", function( ply )
	ply.GR_NextSpit = 0
	if ply:IsGhost() then return end
	if not ply:HasWeapon( Weapons.HANDS ) then ply:Give( Weapons.HANDS ) end
	ply:SelectWeapon( Weapons.HANDS )
	ply:SetHolstered( true )
end )

function Weapons.FlashRed( ply )
	if IsValid( ply ) and ply:IsPlayer() then ply:ScreenFade( SCREENFADE.IN, Color( 200, 0, 0, 80 ), 0.3, 0 ) end
end

-- G: spit, or the shove with a gun out. Returns what happened ("shove", "spit") or nil.
function Weapons.Spit( ply )
	if not ply:Alive() or ply:IsGhost() or ply:GetPassedOut() then return end
	if CurTime() < ( ply.GR_NextSpit or 0 ) then return end
	ply.GR_NextSpit = CurTime() + Weapons.SPIT_COOLDOWN
	local wep = Weapons.Active( ply )
	if wep and wep.Firearm and not wep.CantMelee and wep:IsOut() then
		wep:MeleeShove()
		return "shove"
	end
	ply:EmitSound( "placenta/spit.wav", 70 )
	ply:ViewPunch( Angle( 3, 0, 0 ) )
	Needs.Add( ply, "Dryness", 2, "spit" )
	local start = ply:GetShootPos()
	local tr = util.TraceLine( { start = start, endpos = start + ply:GetAimVector() * Weapons.SPIT_RANGE, filter = ply } )
	net.Start( "gr_spit" )
	net.WriteVector( start - Vector( 0, 0, 4 ) )
	net.WriteVector( tr.HitPos )
	net.SendPVS( start )
	local victim = tr.Entity
	if IsValid( victim ) and victim:IsPlayer() and victim:Alive() and not victim:IsGhost() then
		Notify( ply, "Haha." )
		Notify( victim, ply:FateHas( "SpitLine" ) or "Ugh! Someone spat on me!" )
		-- Spit alone never pushes despair past SPIT_DESPAIR_CAP, so it can't stop a heart.
		local add = math.min( ply:FateHas( "SpitDespair" ) or 4, Weapons.SPIT_DESPAIR_CAP - Needs.Get( victim, "Despair" ) )
		if add > 0 then Needs.Add( victim, "Despair", add, "spit" ) end
		if victim:IsOnFire() and math.random() < 0.05 then
			victim:Extinguish()
			Notify( victim, "Someone's spit extinguished me. Thank Sotla." )
		end
		Crime.Report( ply, "spit", { victim = victim } )
	end
	return "spit"
end

Net.Receive( "gr_spit", { rate = 4, alive = true }, function( ply ) Weapons.Spit( ply ) end )

-- A melee hit at `pos` near a body's head: 10% to burst it, which finishes the body off.
function Weapons.TryHeadBurst( rag, pos, attacker )
	if rag.GR_Headless then return false end
	local bone = rag:LookupBone( "ValveBiped.Bip01_Head1" )
	if not bone then return false end
	local head = rag:GetBonePosition( bone )
	if not head or pos:DistToSqr( head ) >= Weapons.HEAD_BURST_DIST_SQR then return false end
	if math.random() > Weapons.HEAD_BURST_CHANCE then return false end
	Weapons.ExplodeHead( rag, bone, attacker )
	return true
end

function Weapons.ExplodeHead( rag, bone, attacker )
	if rag.GR_Headless then return end
	rag.GR_Headless = true
	local rec = Corpse.Get( rag )
	if rec and rec.state == "unconscious" and IsValid( rec.owner ) and rec.owner:Alive() then
		rec.owner:Kill() -- the hidden body dies; the corpse goes down (sh_corpse.lua)
	end
	rec = Corpse.Get( rag )
	if rec and rec.state == "downed" then Corpse.FinishOff( rag, attacker ) end
	local at = rag:GetBonePosition( bone )
	rag:ManipulateBoneScale( bone, Vector( 0, 0, 0 ) )
	rag:EmitSound( "placenta/head_explodie_0" .. math.random( 1, 4 ) .. ".ogg", 100, 100, 1 )
	rag:EmitSound( "physics/flesh/flesh_squishy_impact_hard" .. math.random( 1, 4 ) .. ".wav", 100, 100, 1 )
	local e = EffectData()
	e:SetOrigin( at )
	e:SetScale( 2 )
	util.Effect( "BloodImpact", e )
	util.Decal( "Blood", at, at - Vector( 0, 0, 64 ), rag )
	Log.Debug( "weapons", "%s's head burst", rec and rec.name or "a body" )
end
