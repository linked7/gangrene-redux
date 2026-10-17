-- Firearms for weapon_gr_base (the original's sh_firing.lua). Spread is Primary.Accuracy times
-- Weapons.SpreadMultiplier (sh_weapons.lua); recoil is a view punch and an eye-angle kick scaled by
-- Primary.Recoil and the fate's RecoilMulti. Right-click held zooms to x0.9 FOV (or AimFOV). G with a
-- gun out is the melee shove.
--
-- Reloads take ReloadTime: the length of the gun's reload sequence, read from its .mdl and written
-- into each gun (the server has no workshop content, so it can't ask the model). Afterwards
-- ChamberAnim plays if the clip was empty, else IdleAnim. ShellReload guns (the pump shotguns) load
-- a shell at a time (ShellTimes = { start, insert, finish }) and pump between shots (PumpTimes: the
-- shoot sequences' lengths; the next shot waits length - 0.7, then the pump takes length again).
-- Bullets that hit the world or a prop carry on through it (32 units, 16 into a concrete or metal
-- prop, 12 into concrete or metal world) at 0.6 damage, as in the original.

function SWEP:CanFire()
	if self:GetReloading() or self:GetNeedPump() then return false end
	if self:Clip1() <= 0 then
		self:EmitSound( self.EmptySound or "Weapon_Pistol.Empty" )
		self:SetNextPrimaryFire( CurTime() + 0.2 )
		return false
	end
	return true
end

function SWEP:PrimaryFirearm()
	if not self:CanFire() then return end
	if self.ShellReload then
		-- Primary.Delay is unused: the next shot waits on the shoot sequence, then the pump.
		local d = self.PumpTimes[ math.floor( util.SharedRandom( "gr_pump", 1, #self.PumpTimes + 1 - 1e-6 ) ) ]
		self:SetPumpTime( d )
		self:SetNeedPump( true )
		self:SetNextPrimaryFire( CurTime() + d - 0.7 )
	else
		self:SetNextPrimaryFire( CurTime() + ( self.Primary.Delay or 0.2 ) )
	end
	self:ShootEffects()
	self:TakePrimaryAmmo( 1 )
	self:PlayFireSound( self.Primary.Sound )
	if not IsFirstTimePredicted() then return end
	local owner = self:GetOwner()
	self:ShootBullet( self.Primary.Damage, self.Primary.Force or 1, self.Primary.NumBullets or 1,
		( self.Primary.Accuracy or 0.02 ) * Weapons.SpreadMultiplier( owner, nil, self ) )
end

-- The original's fire sound: a table plays every entry, not one of them.
function SWEP:PlayFireSound( snd )
	if not istable( snd ) then return self:PlaySound( snd, 100, 100 ) end
	for _, s in ipairs( snd ) do self:PlaySound( s, 100, 100 ) end
end

-- The pump after a shotgun shot, once the shot's sequence has run.
function SWEP:ThinkPump()
	if not self:GetNeedPump() or CurTime() < self:GetNextPrimaryFire() then return end
	self:SetNeedPump( false )
	self:PlaySound( "Weapon_Shotgun.Special1" )
	self:SendWeaponAnim( ACT_SHOTGUN_PUMP )
	self:SetNextPrimaryFire( CurTime() + self:GetPumpTime() )
end

function SWEP:ShootEffects()
	local owner = self:GetOwner()
	local rec = self.Primary.Recoil or 1
	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
	owner:ViewPunch( Angle( math.Rand( -0.1, -0.5 ) * rec, math.Rand( -0.5, 0.5 ) * rec, 0 ) )
	owner:MuzzleFlash()
	owner:SetAnimation( PLAYER_ATTACK1 )
	if CLIENT then self.RecoilZ = -rec * 6 end
end

-- CS-style muzzle flash for the CS-rigged models (the original's FireAnimationEvent).
function SWEP:FireAnimationEvent( pos, ang, event )
	if event == 5001 or event == 5011 or event == 5021 or event == 5031 then
		local e = EffectData()
		e:SetFlags( 0 )
		e:SetEntity( self:GetOwner():GetViewModel() )
		e:SetAttachment( math.floor( ( event - 4991 ) / 10 ) )
		e:SetScale( 1 )
		util.Effect( self.CSMuzzleX and "CS_MuzzleFlash_X" or "CS_MuzzleFlash", e )
		return true
	end
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

local IMPACT = {
	[ MAT_CONCRETE ] = { "Impact.Concrete", "MetalSpark" },
	[ MAT_METAL ] = { "Impact.Metal", "MetalSpark" },
	[ MAT_GLASS ] = { "Impact.Glass", "GlassImpact" },
	[ MAT_WOOD ] = { "Impact.Wood", "MetalSpark" },
}
local NO_DECAL = { [ 72 ] = true, [ 70 ] = true, [ 66 ] = true, [ 65 ] = true }

local function decal( tr )
	if NO_DECAL[ tr.MatType ] then return end
	local m = IMPACT[ tr.MatType ]
	util.Decal( m and m[ 1 ] or "Impact.Concrete", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal )
end

-- The original's pass-through: the bullet comes out the far side of world and props (never people).
function SWEP:Penetrate( tr, damage, force, n )
	local ent = tr.Entity
	if IsValid( ent ) and ( ent:IsPlayer() or ent:IsNPC() or ent:IsVehicle() ) then return end
	local owner = self:GetOwner()
	local aim = owner:GetAimVector()
	local dist = 32
	if tr.MatType == MAT_CONCRETE or tr.MatType == MAT_METAL then dist = IsValid( ent ) and 16 or 12 end
	local out = util.TraceLine( { start = tr.HitPos + aim * dist, endpos = tr.HitPos } )
	decal( tr )
	decal( out )
	owner:FireBullets( {
		Num = n, Src = out.HitPos, Dir = aim, Spread = vector_origin,
		Force = force, Damage = damage * 0.6, Tracer = 1, TracerName = self.Primary.TracerName or "Tracer",
		AmmoType = self.Primary.Ammo,
	} )
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
		Callback = function( _, tr )
			if CLIENT then
				-- Green on things, red on the world, as in the original.
				local d = DynamicLight( self:EntIndex() )
				if d then
					d.pos = tr.HitPos
					d.r, d.g, d.b = tr.HitNonWorld and 0 or 200, tr.HitNonWorld and 200 or 0, 0
					d.brightness = 5
					d.size = damage * 2
					d.decay = damage * 2 / 5
					d.dietime = CurTime() + 5
				end
			elseif IsValid( self ) and IsValid( self:GetOwner() ) then
				self:Penetrate( tr, damage, force, n )
			end
		end,
	} )
	-- The view climbs with each shot; the client owns its eye angles.
	if CLIENT and IsFirstTimePredicted() then
		local rec = self:RecoilKick()
		local ang = owner:EyeAngles()
		ang.p = ang.p - rec
		ang.y = ang.y + math.random( -rec * 0.5, rec * 0.5 )
		owner:SetEyeAngles( ang )
	end
end

function SWEP:Reload()
	if not self.Firearm or self:GetReloading() or self:GetNeedPump() then return end
	local owner = self:GetOwner()
	if owner:KeyDown( IN_USE ) then return end -- Use + Reload checks ammo instead (sh_weapons.lua)
	local want = math.min( self.Primary.ClipSize - self:Clip1(), owner:GetAmmoCount( self.Primary.Ammo ) )
	if want <= 0 then return end
	local dur
	if self.ShellReload then
		self:SendWeaponAnim( ACT_SHOTGUN_RELOAD_START )
		dur = self.ShellTimes[ 1 ]
	else
		self:SendWeaponAnim( self.ReloadAnim or ACT_VM_RELOAD )
		dur = self.ReloadTime
		if not dur then
			local vm = owner:GetViewModel()
			dur = IsValid( vm ) and vm:SequenceDuration() or 0
			if dur <= 0.1 then dur = 1.5 end
		end
		self:SetChamber( self:Clip1() <= 0 )
		self:SetNextPrimaryFire( CurTime() + dur )
		self:SetNextSecondaryFire( CurTime() + dur )
	end
	self:SetReloading( true )
	self:SetReloadEnd( CurTime() + dur )
	owner:SetAnimation( PLAYER_RELOAD )
	if not self.ShellReload then self:PlaySound( self.Primary.ReloadSound ) end
end

function SWEP:ThinkReload()
	if not self:GetReloading() then return end
	if self.ShellReload and not self:IsOut() then self:SetReloading( false ) return end -- holstering stops it
	if CurTime() < self:GetReloadEnd() then return end
	local owner = self:GetOwner()
	if self.ShellReload then
		if self:Clip1() < self.Primary.ClipSize and owner:GetAmmoCount( self.Primary.Ammo ) > 0 then
			self:SendWeaponAnim( ACT_VM_RELOAD )
			self:SetClip1( self:Clip1() + 1 )
			owner:RemoveAmmo( 1, self.Primary.Ammo )
			self:PlaySound( self.Primary.ReloadSound )
			self:SetReloadEnd( CurTime() + self.ShellTimes[ 2 ] )
		else
			self:SendWeaponAnim( ACT_SHOTGUN_RELOAD_FINISH )
			self:SetReloading( false )
			self:SetNextPrimaryFire( CurTime() + self.ShellTimes[ 3 ] )
		end
		return
	end
	self:SetReloading( false )
	self:SendWeaponAnim( self:GetChamber() and self.ChamberAnim or self.IdleAnim or ACT_VM_IDLE )
	local add = math.min( self.Primary.ClipSize - self:Clip1(), owner:GetAmmoCount( self.Primary.Ammo ) )
	if add <= 0 then return end
	self:SetClip1( self:Clip1() + add )
	owner:RemoveAmmo( add, self.Primary.Ammo )
end

-- Aiming down the sights: a slight zoom while right-click is held with the gun out (AimFOV for the
-- rifles that set one).
function SWEP:TranslateFOV( fov )
	if self:IsOut() and self:GetOwner():KeyDown( IN_ATTACK2 ) then return self.AimFOV or fov * 0.9 end
	return fov
end

function SWEP:AdjustMouseSensitivity()
	return 1
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
