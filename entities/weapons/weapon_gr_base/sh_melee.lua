-- Melee for weapon_gr_base (the original's sh_melee.lua). Hold attack to charge, let go to swing;
-- held for HeavyCharge seconds it is a heavy swing (the swing sound at pitch 20). Weapons with
-- SecondaryBlock block while right-click is held out. As in the original's real behaviour (parity
-- ruling, plan step 15), neither changes the damage: the original never applied either multiplier.
-- Also the holstered right-click: pick up a prop up to PickupMass kg within PickupRange units.

local HULL = Vector( 8, 8, 8 )

function SWEP:PrimaryMelee()
	local owner = self:GetOwner()
	if self:GetMeleeAttack() or owner:KeyDown( IN_ATTACK2 ) then return end
	self:SetMeleeAttack( true )
	self:SetChargeStart( CurTime() )
	self:SetHeavyAttack( false )
end

-- Charging: becomes heavy once held long enough; letting go swings.
function SWEP:ThinkMelee()
	if not self:GetMeleeAttack() then return end
	local owner = self:GetOwner()
	if not self:IsOut() then
		self:SetMeleeAttack( false )
		self:SetHeavyAttack( false )
		return
	end
	if owner:KeyDown( IN_ATTACK ) then
		if not self:GetHeavyAttack() and CurTime() - self:GetChargeStart() >= self.HeavyCharge then
			self:SetHeavyAttack( true )
		end
		return
	end
	local heavy = self:GetHeavyAttack()
	self:SetMeleeAttack( false )
	self:SetHeavyAttack( false )
	if not IsFirstTimePredicted() then return end
	self:MeleeSwing( heavy )
end

function SWEP:IsBlocking()
	if not self.SecondaryBlock or not self:IsOut() then return false end
	return self:GetOwner():KeyDown( IN_ATTACK2 )
end

-- The swing's hull trace: Length units along `dir` (default: where the owner aims), ghosts skipped.
function SWEP:MeleeTrace( start, dir )
	local owner = self:GetOwner()
	start = start or owner:GetShootPos()
	dir = dir or owner:GetAimVector()
	local filter = { owner }
	if not self.HitGhosts then
		for _, p in player.Iterator() do
			if p:IsGhost() then table.insert( filter, p ) end
		end
	end
	return util.TraceHull( {
		start = start, endpos = start + dir * self.Length,
		filter = filter, mins = -HULL, maxs = HULL, mask = MASK_SHOT_HULL,
	} )
end

function SWEP:MeleeSwing( heavy, start, dir )
	local owner = self:GetOwner()
	local lag = SERVER and not owner:IsBot()
	if lag then owner:LagCompensation( true ) end

	owner:SetAnimation( PLAYER_ATTACK1 )
	self:PlaySound( self.SwingSound, 75, heavy and 20 or 100 )
	self:SetNextPrimaryFire( CurTime() + ( self.HitDelay or 1 ) )
	self:SetNextSecondaryFire( CurTime() + ( self.HitDelay or 1 ) )

	local tr = self:MeleeTrace( start, dir )
	if tr.Hit then
		self:SendWeaponAnim( self.HitAnim or ACT_VM_HITCENTER )
		if SERVER then self:MeleeHit( tr, heavy ) end
	else
		self:SendWeaponAnim( self.MissAnim or ACT_VM_MISSCENTER )
		local md = self.MissDelay or self.HitDelay or 1
		self:SetNextPrimaryFire( CurTime() + md )
		self:SetNextSecondaryFire( CurTime() + md )
	end

	if lag then owner:LagCompensation( false ) end
	if self.ViewPunch then owner:ViewPunch( self.ViewPunch ) end
	return tr
end

if CLIENT then return end

local function isFlesh( ent )
	return IsValid( ent ) and ( ent:IsPlayer() or ent:IsNPC() or ent:GetClass() == "prop_ragdoll" )
end

-- The damage this swing does to `ent` before the damage pipeline: resist, injury. A heavy swing and
-- a block don't change it (parity ruling).
function SWEP:MeleeDamage( ent, heavy )
	local owner = self:GetOwner()
	local dam = self.Damage or 10
	if IsValid( ent ) and ent:IsPlayer() then
		local resist = ent:FateHas( "MeleeResistScale" )
		if isnumber( resist ) and resist > 0.1 and not self.IgnoreMeleeResist then dam = dam * resist end
	end
	-- The original's "recovering" injury; the remake's one injury is Injured (sh_corpse.lua).
	if owner.GetInjured and owner:GetInjured() then dam = dam * 0.7 end
	return dam
end

function SWEP:MeleeHit( tr, heavy )
	local owner = self:GetOwner()
	local ent = tr.Entity
	local snd
	if isFlesh( ent ) then
		snd = self.HitFleshSound
		if ent:GetClass() == "prop_ragdoll" then Weapons.TryHeadBurst( ent, tr.HitPos, owner ) end
	else
		snd = self.HitWallSound
		-- Bare fists on anything that isn't flesh hurt the one punching.
		if self.HoldType == "fist" and not self.FistNoHurt then
			local d = DamageInfo()
			d:SetAttacker( owner )
			d:SetInflictor( self )
			d:SetDamage( self.Damage or 10 )
			d:SetDamagePosition( tr.HitPos )
			d:SetDamageType( self.DamageType or DMG_CLUB )
			owner:TakeDamageInfo( d )
			Weapons.FlashRed( owner )
		end
	end

	if IsValid( ent ) then
		local e = EffectData()
		e:SetOrigin( tr.HitPos )
		e:SetScale( 0.5 )
		e:SetMagnitude( 0.4 )
		e:SetRadius( 0.2 )
		util.Effect( "Sparks", e )
	end
	if IsValid( ent ) and ent:IsPlayer() then Weapons.FlashRed( ent ) end

	local d = DamageInfo()
	d:SetAttacker( owner )
	d:SetInflictor( self )
	d:SetDamage( self:MeleeDamage( ent, heavy ) )
	d:SetDamagePosition( tr.HitPos )
	d:SetDamageType( self.DamageType or DMG_SLASH )

	-- Knockback along the aim, flattened to the ground.
	if IsValid( ent ) then
		local push = ( tr.HitPos - tr.StartPos )
		push.z = 0
		push:Normalize()
		local phys = ent:GetPhysicsObject()
		if ent:IsPlayer() then
			ent:SetVelocity( push * ( self.Knockback or 200 ) )
		elseif IsValid( phys ) then
			phys:SetVelocity( push * ( self.Knockback or 200 ) )
		end
		d:SetDamageForce( push * ( self.Knockback or 200 ) * 10 )
		ent:DispatchTraceAttack( d, tr, push )
	end
	self:PlaySound( snd, 75, 100 )
	hook.Run( "GR_MeleeHit", owner, ent, d, tr, self )
end

-- Holstered right-click: pick up what is in front of you.
function SWEP:SecondaryHolstered()
	local owner = self:GetOwner()
	local start = owner:GetShootPos()
	local tr = util.TraceLine( { start = start, endpos = start + owner:GetAimVector() * self.PickupRange, filter = { self, owner } } )
	local ent = tr.Entity
	if not Weapons.CanCarry( ent, self.PickupMass ) then return end
	ent:GetPhysicsObject():Wake()
	owner:PickupObject( ent )
	owner:EmitSound( "physics/body/body_medium_impact_soft" .. math.random( 1, 3 ) .. ".wav", 75 )
	self:SetNextSecondaryFire( CurTime() + 1 )
end
