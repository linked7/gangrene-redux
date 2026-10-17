-- The rocket turret (Liver Failure turret_rocket). One at a time, spawned and tracked by
-- sh_rocketturret.lua, which also drives ENT:Tick at 5 Hz. Hunts a visible player within 2500
-- and fires rpg_missiles along its up axis.
AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Rocket Turret"
ENT.Spawnable = false
ENT.Interesting = true

local RANGE = 2500

function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "Integrity" )
	self:NetworkVar( "Entity", 0, "Target" )
	self:NetworkVar( "Bool", 0, "Locked" )
end

function ENT:CanPhysgun() return false end

if CLIENT then
	ENT.LaserMat = Material( "sprites/bluelaser1" )
	ENT.SpriteMat = CreateMaterial( "sentrydot", "UnlitGeneric", {
		[ "$basetexture" ] = "sprites/light_glow03", [ "$additive" ] = 1,
		[ "$translucent" ] = 1, [ "$vertexcolor" ] = 1,
	} )
	local RED = Color( 255, 0, 0, 255 )

	function ENT:Draw()
		-- Smooth the 5 Hz server aim
		local want = self:GetAngles()
		self.smooth = self.smooth and LerpAngle( math.min( 1, FrameTime() * 8 ), self.smooth, want ) or want
		self:SetRenderAngles( self.smooth )
		self:DrawModel()
		if EyePos():DistToSqr( self:GetPos() ) > 3000 * 3000 then return end
		local up = self.smooth:Up()
		local startPos = self:GetPos() + up * 5
		local endPos = self:GetPos() + up * 4000
		if not self.nextTrace or self.nextTrace <= CurTime() then
			self.nextTrace = CurTime() + 0.1
			self.hitPos = util.TraceLine( { start = startPos, endpos = endPos, filter = self } ).HitPos
		end
		local t = CurTime()
		render.SetMaterial( self.LaserMat )
		render.DrawBeam( startPos, self.hitPos or endPos, 10 + 6 * math.sin( t ), 0, 0, RED )
		render.SetMaterial( self.SpriteMat )
		render.DrawSprite( self.hitPos or endPos, 8 + 4 * math.sin( t ), 8 + 4 * math.cos( t ), RED )
	end
	return
end

function ENT:PostEntityPaste() self:Remove() end

function ENT:Initialize()
	self:SetModel( "models/Combine_Helicopter/helicopter_bomb01.mdl" )
	self:PhysicsInit( SOLID_BBOX )
	self:SetMoveType( MOVETYPE_FLY )
	self:SetGravity( 0.1 )
	self.Sleeping = true
	self.NextAct = CurTime()
	self.NextLook = CurTime()
	self.MissedAttacks = 0
	self.RocketSpeedBoost = 0
	self.Fired = 0
	self:SetIntegrity( math.random( 4, 6 ) )
end

function ENT:HorrorSound( snd, reps, pitch, inc )
	for _ = 1, reps do
		self:EmitSound( snd, 150, pitch, 1 )
		pitch = pitch - inc
	end
end

-- Cheap checks only (no trace): alive, in range, not exempt.
function ENT:ValidTarget( trg )
	if not IsValid( trg ) or not trg:IsPlayer() or not trg:Alive() then return false end
	if trg.IsGhost and trg:IsGhost() then return false end
	if Inventory.Count( trg, "permit_turret" ) > 0 then return false end
	if trg:WaterLevel() >= 3 or trg:IsEFlagSet( EFL_NOCLIP_ACTIVE ) then return false end
	if hook.Run( "GR_TurretIgnore", self, trg ) then return false end -- cultists, jammers
	return trg:GetPos():DistToSqr( self:GetPos() ) <= RANGE * RANGE
end

function ENT:CanSee( trg )
	local tr = util.TraceLine( {
		start = self:LocalToWorld( self:OBBCenter() ), endpos = trg:LocalToWorld( trg:OBBCenter() ),
		filter = { self, trg },
	} )
	return not tr.HitWorld
end

function ENT:SearchForTarget()
	local cands = {}
	for _, p in ipairs( player.GetAll() ) do
		if self:ValidTarget( p ) and self:TestPVS( p ) then
			cands[ #cands + 1 ] = { p, p:GetPos():DistToSqr( self:GetPos() ) }
		end
	end
	table.sort( cands, function( a, b ) return a[ 2 ] < b[ 2 ] end )
	local found
	for i = 1, math.min( 3, #cands ) do
		if self:CanSee( cands[ i ][ 1 ] ) then found = cands[ i ][ 1 ] break end
	end
	if found then
		self:SetTarget( found )
		self.Sleeping = false
		self.MissedAttacks = 0
		self:EmitSound( "npc/strider/striderx_pain8.wav", 150, 70, 1 ) -- one acquire sound
		self.NextAct = CurTime() + 2
	else
		self:HorrorSound( "npc/combine_gunship/ping_search.wav", 3, 100, 10 )
		self.NextAct = CurTime() + ( self.Sleeping and 15 or 1 )
		self.RocketSpeedBoost = 0
	end
	return found
end

function ENT:Idle()
	return hook.Run( "GR_TurretIdle", self ) == true
end

function ENT:LookTarget()
	if self.NextLook > CurTime() then return end
	self.NextLook = CurTime() + 0.2
	local ang = ( self:GetTarget():GetPos() + Vector( 0, 0, 50 ) - self:GetPos() ):Angle()
	self:SetAngles( LerpAngle( 0.5, self:GetAngles(), Angle( ang.x + 90, ang.y, 0 ) ) )
end

function ENT:FireRocket()
	local up = self:GetUp()
	local r = ents.Create( "rpg_missile" )
	r:SetPos( self:GetPos() + up * 25 )
	r:SetAngles( up:Angle() )
	r:Spawn()
	r:Activate()
	r:SetOwner( self )
	r:SetVelocity( up * ( 500 + self.RocketSpeedBoost ) )
	r:SetSaveValue( "m_flDamage", 90 )
	self.RocketSpeedBoost = self.RocketSpeedBoost + 10
	self.Fired = self.Fired + 1
	return r
end

function ENT:SetLock( locked )
	self:SetLocked( locked )
	if locked then
		self:HorrorSound( "npc/combine_gunship/attack_stop2.wav", 4, 60, 10 )
		self:SetMaterial( "models/combine_advisor/mask" )
		self.NextAct = CurTime() + math.random( 10, 35 )
		self:SetTarget( NULL )
	else
		self:HorrorSound( "npc/strider/strider_skewer1.wav", 3, 50, 10 )
		self:SetMaterial( "" )
		self.NextAct = CurTime() + 0.5
	end
end

-- Driven by sh_rocketturret.lua at 5 Hz (Sched), not a Think.
function ENT:Tick()
	if self:Idle() then return end
	local trg = self:GetTarget()
	local valid = self:ValidTarget( trg )
	if valid then self:LookTarget() end
	if self.NextAct > CurTime() then return end
	if self:GetLocked() then self:SetLock( false ) return end
	if not valid then
		self:SetTarget( NULL )
		self:SearchForTarget()
		return
	end
	if self:CanSee( trg ) then
		self:FireRocket()
	else
		self:HorrorSound( "npc/strider/striderx_alert6.wav", 3, 125, 10 )
		self.MissedAttacks = self.MissedAttacks + 1
		self.RocketSpeedBoost = 0
		if self.MissedAttacks >= 5 then
			self.MissedAttacks = 0
			self:SetTarget( NULL )
		end
	end
	self.NextAct = CurTime() + 0.5
end

function ENT:Destroy()
	local pos = self:GetPos()
	local e = EffectData()
	e:SetStart( pos ) e:SetOrigin( pos ) e:SetScale( 8 )
	util.Effect( "GlassImpact", e, true, true )
	self:HorrorSound( "npc/strider/striderx_die1.wav", 5, 80, 5 )
	local list = {}
	for _ = 1, math.random( 4, 5 ) do
		list[ #list + 1 ] = math.random( 5 ) == 5 and "scrap_gear" or "scrap"
		list[ #list + 1 ] = "rocket"
	end
	list[ #list + 1 ] = "artifact_ai"
	Items.SpawnMany( list, pos, self:GetAngles() )
	self:Remove()
end

function ENT:OnTakeDamage( dmg )
	if self:GetLocked() then return end
	self.Sleeping = false
	self:SetIntegrity( self:GetIntegrity() - 1 )
	self:SetLock( true )
	local s = EffectData()
	s:SetOrigin( dmg:GetDamagePosition() or self:GetPos() )
	s:SetScale( 1 ) s:SetMagnitude( 5 ) s:SetRadius( 20 )
	util.Effect( "Sparks", s )
	if self:GetIntegrity() <= 0 then self:Destroy() end
end
