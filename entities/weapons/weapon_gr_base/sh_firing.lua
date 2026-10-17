-- Firearms for weapon_gr_base (the original's sh_firing.lua). Spread is Primary.Accuracy times
-- Weapons.SpreadMultiplier (sh_weapons.lua); recoil is a view punch and an eye-angle kick scaled by
-- Primary.Recoil and the fate's RecoilMulti. Right-click held zooms to x0.9 FOV. Reloading takes the
-- reload animation's length and blocks jumping (sh_movement.lua). G with a gun out is the melee shove.

function SWEP:CanFire()
	if self:GetReloading() then return false end
	if self:Clip1() <= 0 then
		self:EmitSound( self.EmptySound or "Weapon_Pistol.Empty" )
		self:SetNextPrimaryFire( CurTime() + 0.2 )
		return false
	end
	return true
end

function SWEP:PrimaryFirearm()
	if not self:CanFire() then return end
	self:SetNextPrimaryFire( CurTime() + ( self.Primary.Delay or 0.2 ) )
	self:TakePrimaryAmmo( 1 )
	self:ShootEffects()
	self:PlaySound( self.Primary.Sound, 100, 100 )
	if not IsFirstTimePredicted() then return end
	local owner = self:GetOwner()
	self:ShootBullet( self.Primary.Damage, self.Primary.Force or 1, self.Primary.NumBullets or 1,
		( self.Primary.Accuracy or 0.02 ) * Weapons.SpreadMultiplier( owner, nil, self ) )
end

function SWEP:ShootEffects()
	local owner = self:GetOwner()
	local rec = self.Primary.Recoil or 1
	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
	owner:ViewPunch( Angle( math.Rand( -0.1, -0.5 ) * rec, math.Rand( -0.5, 0.5 ) * rec, 0 ) )
	owner:MuzzleFlash()
	owner:SetAnimation( PLAYER_ATTACK1 )
end

-- How far the shot kicks the view up, in degrees.
function SWEP:RecoilKick()
	local owner = self:GetOwner()
	local rec = self.Primary.Recoil or 1
	if owner:Crouching() and owner:OnGround() then rec = rec * 0.5 end
	if not owner:OnGround() and owner:WaterLevel() < 2 then rec = rec * 5 end
	local mul = owner:FateHas( "RecoilMulti" )
	if isnumber( mul ) then rec = rec * mul end
	return rec
end

function SWEP:ShootBullet( damage, force, n, cone )
	local owner = self:GetOwner()
	owner:FireBullets( {
		Num = n,
		Src = owner:GetShootPos(),
		Dir = owner:GetAimVector(),
		Spread = Vector( cone, cone, 0 ),
		Tracer = 1,
		TracerName = self.Primary.TracerName or "Tracer",
		Force = force,
		Damage = damage,
		AmmoType = self.Primary.Ammo,
	} )
	-- The view climbs with each shot; the client owns its eye angles.
	if CLIENT and IsFirstTimePredicted() then
		local rec = self:RecoilKick()
		local ang = owner:EyeAngles()
		ang.p = ang.p - rec
		ang.y = ang.y + math.Rand( -rec * 0.5, rec * 0.5 )
		owner:SetEyeAngles( ang )
	end
end

function SWEP:Reload()
	if not self.Firearm or self:GetReloading() then return end
	local owner = self:GetOwner()
	if owner:KeyDown( IN_USE ) then return end -- Use + Reload checks ammo instead (sh_weapons.lua)
	local want = math.min( self.Primary.ClipSize - self:Clip1(), owner:GetAmmoCount( self.Primary.Ammo ) )
	if want <= 0 then return end
	self:SendWeaponAnim( ACT_VM_RELOAD )
	local vm = owner:GetViewModel()
	local dur = IsValid( vm ) and vm:SequenceDuration() or 0
	if dur <= 0.1 then dur = self.ReloadTime or 1.5 end
	self:SetReloading( true )
	self:SetReloadEnd( CurTime() + dur )
	self:SetNextPrimaryFire( CurTime() + dur )
	self:SetNextSecondaryFire( CurTime() + dur )
	owner:SetAnimation( PLAYER_RELOAD )
	self:PlaySound( self.Primary.ReloadSound )
end

function SWEP:ThinkReload()
	if not self:GetReloading() or CurTime() < self:GetReloadEnd() then return end
	local owner = self:GetOwner()
	self:SetReloading( false )
	local add = math.min( self.Primary.ClipSize - self:Clip1(), owner:GetAmmoCount( self.Primary.Ammo ) )
	if add <= 0 then return end
	self:SetClip1( self:Clip1() + add )
	owner:RemoveAmmo( add, self.Primary.Ammo )
end

-- Aiming down the sights: a slight zoom while right-click is held with the gun out.
function SWEP:TranslateFOV( fov )
	if self:IsOut() and self:GetOwner():KeyDown( IN_ATTACK2 ) then return fov * 0.9 end
	return fov
end

function SWEP:AdjustMouseSensitivity()
	if self:IsOut() and self:GetOwner():KeyDown( IN_ATTACK2 ) then return 0.9 end
end

-- G with a gun out: shove whoever is in front, 70 units (the original's MeleeShove).
function SWEP:MeleeShove()
	local owner = self:GetOwner()
	local damage, knockback, delay = self.MeleeDamage or 25, self.MeleeKnockback or 50, self.MeleeDelay or 4
	local stun = self.MeleeStun or 2
	local lag = SERVER and not owner:IsBot()
	if lag then owner:LagCompensation( true ) end
	self:PlaySound( "npc/zombie/claw_miss" .. math.random( 1, 2 ) .. ".wav" )
	local start = owner:GetShootPos()
	local filter = { owner }
	for _, p in player.Iterator() do
		if p:IsGhost() then table.insert( filter, p ) end
	end
	local tr = util.TraceHull( {
		start = start, endpos = start + owner:GetAimVector() * Weapons.SHOVE_RANGE,
		filter = filter, mins = Vector( -8, -8, -8 ), maxs = Vector( 8, 8, 8 ), mask = MASK_SHOT_HULL,
	} )
	local ent = tr.Entity
	if SERVER and tr.Hit then
		local flesh = IsValid( ent ) and ( ent:IsPlayer() or ent:IsNPC() or ent:GetClass() == "prop_ragdoll" )
		local snd = flesh and ( "npc/zombie/claw_strike" .. math.random( 1, 3 ) .. ".wav" )
			or ( "physics/body/body_medium_impact_hard" .. math.random( 1, 6 ) .. ".wav" )
		if IsValid( ent ) then
			local e = EffectData()
			e:SetOrigin( tr.HitPos )
			e:SetScale( 0.5 )
			e:SetMagnitude( 0.4 )
			e:SetRadius( 0.2 )
			util.Effect( "Sparks", e )
		end
		local dam = damage
		if IsValid( ent ) and ent:IsPlayer() then
			Weapons.FlashRed( ent )
			delay = delay / 2
			ent:ViewPunch( Angle( math.random( -40, 40 ), math.random( -25, 25 ), 0 ) )
			local resist = ent:FateHas( "MeleeResistScale" )
			if isnumber( resist ) and resist > 0.1 then dam = dam * resist end
			local wep = ent:GetActiveWeapon()
			if IsValid( wep ) and wep.Firearm then wep:SetNextPrimaryFire( CurTime() + stun ) end
		end
		if owner.GetInjured and owner:GetInjured() then dam = dam * 0.7 end
		if IsValid( ent ) then
			local push = owner:GetAimVector()
			push.z = 0
			push:Normalize()
			local d = DamageInfo()
			d:SetAttacker( owner )
			d:SetInflictor( self )
			d:SetDamage( dam )
			d:SetDamagePosition( tr.HitPos )
			d:SetDamageType( DMG_VEHICLE )
			if ent:IsPlayer() then ent:SetVelocity( push * knockback * 2 ) end
			ent:DispatchTraceAttack( d, tr, push )
		end
		self:PlaySound( snd, 75, 100 )
	end
	self:SetNextPrimaryFire( CurTime() + 1 )
	if SERVER then owner.GR_NextSpit = CurTime() + delay end
	if lag then owner:LagCompensation( false ) end
	owner:ViewPunch( Angle( math.random( -25, 25 ), math.random( -25, 25 ), 0 ) )
end
