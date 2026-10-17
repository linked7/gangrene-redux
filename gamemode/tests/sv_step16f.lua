-- Step 16f: weapon feel, movement and controls (docs/05 §9, §12, §14). A drawn weapon halves speed
-- and stops sprinting; holstered hands lift up to 115 kg; a heavy swing and a block don't change
-- damage (parity ruling); fists hurt on walls; the spread multiplier keeps the original's x1.5-for-any-movement bug; a
-- leg shot never stops jumping; reloading blocks jumping; a jump press
-- cancels surgery; a dragged body snaps free past 128 units.
local function bot( name )
	local b = player.CreateNextBot( name )
	b:SetRank( RANK_FRIEND )
	b:SetStemCells( 10 )
	return b
end

local function hit( victim, attacker, amount, kind )
	local d = DamageInfo()
	d:SetDamage( amount )
	d:SetDamageType( kind or DMG_BULLET )
	d:SetAttacker( attacker )
	d:SetInflictor( attacker )
	victim:TakeDamageInfo( d )
end

local function near( a, b, eps ) return math.abs( a - b ) <= ( eps or 0.01 ) end

return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t16f_%'" )
	local a, v, k = bot( "t16f_a" ), bot( "t16f_v" ), bot( "t16f_k" )
	T.Wait( 0.3 )
	Fates.Take( a, "prole" ) Fates.Take( v, "prole" ) Fates.Take( k, "korpsman" )
	local base = a:GetPos()
	for i, b in ipairs( { a, v, k } ) do
		b:SetMoveType( MOVETYPE_NONE )
		b:SetPos( base + Vector( 40 * ( i - 1 ), 0, 0 ) )
	end
	local regen = Medicine.REGEN_RATE
	Medicine.REGEN_RATE = 0

	T.Check( a:HasWeapon( "weapon_gr_hands" ), "a new life has hands" )
	T.Check( a:GetHolstered(), "and starts holstered" )

	-- Holstering and speed ------------------------------------------------------------------------
	Inventory.Add( a, "pistol", 1, true )
	T.Check( a:HasWeapon( "weapon_gr_pistol" ), "the pistol item gives the gr pistol" )
	a:SelectWeapon( "weapon_gr_pistol" )
	T.Wait( 0.1 )
	local pistol = a:GetActiveWeapon()
	T.Check( IsValid( pistol ) and pistol:GetClass() == "weapon_gr_pistol", "the pistol is in hand" )
	T.Check( a:GetHolstered(), "a weapon switch holsters" )
	local walk, run = a:GetWalkSpeed(), a:GetRunSpeed()
	T.Check( run > walk, "holstered, a prole can sprint" )
	Weapons.SetHolstered( a, false )
	T.Check( near( a:GetWalkSpeed(), walk * 0.5 ), string.format( "pistol out: walk x0.5 (%.1f -> %.1f)", walk, a:GetWalkSpeed() ) )
	T.Check( near( a:GetRunSpeed(), a:GetWalkSpeed() ), "pistol out: no sprinting" )
	Weapons.SetHolstered( a, true )
	T.Check( near( a:GetWalkSpeed(), walk ) and near( a:GetRunSpeed(), run ), "holstered again: speeds are back" )
	Weapons.SetHolstered( a, false )
	a:SelectWeapon( "weapon_gr_hands" )
	T.Wait( 0.1 )
	T.Check( a:GetHolstered() and near( a:GetRunSpeed(), run ), "switching weapons holsters and gives the speed back" )
	Weapons.SetHolstered( a, false )
	T.Check( near( a:GetWalkSpeed(), walk ) and near( a:GetRunSpeed(), run ), "fists out don't slow you" )
	Weapons.SetHolstered( a, true )
	a:SetPassedOut( true )
	Weapons.ToggleHolster( a )
	T.Check( a:GetHolstered(), "no toggling while passed out" )
	a:SetPassedOut( false )
	Weapons.ToggleHolster( a )
	T.Check( not a:GetHolstered(), "B toggles" )
	Weapons.SetHolstered( a, true )

	-- Pickup mass -----------------------------------------------------------------------------------
	local prop = ents.Create( "prop_physics" )
	prop:SetModel( "models/props_junk/wood_crate001a.mdl" )
	prop:SetPos( base + Vector( 0, 80, 40 ) )
	prop:Spawn()
	local phys = prop:GetPhysicsObject()
	phys:SetMass( 115 )
	T.Check( Weapons.CanCarry( prop ), "a 115 kg prop can be picked up" )
	phys:SetMass( 116 )
	T.Check( not Weapons.CanCarry( prop ), "a 116 kg prop can't" )
	phys:SetMass( 20 )
	phys:EnableMotion( false )
	T.Check( not Weapons.CanCarry( prop ), "a frozen prop can't" )
	T.Check( not Weapons.CanCarry( v ), "a player can't" )
	prop:Remove()
	T.Equal( weapons.Get( "weapon_gr_hands" ).PickupRange, 84, "pickup reaches 84 units" )

	-- Melee: heavy, block, fists --------------------------------------------------------------------
	Inventory.Add( a, "baton", 1, true )
	Inventory.Add( v, "baton", 1, true )
	a:SelectWeapon( "weapon_gr_baton" )
	v:SelectWeapon( "weapon_gr_baton" )
	T.Wait( 0.1 )
	local baton = a:GetActiveWeapon()
	T.Check( IsValid( baton ) and baton:GetClass() == "weapon_gr_baton", "the baton is in hand" )
	Weapons.SetHolstered( a, false )
	local start = a:GetPos() + Vector( 0, 0, 40 )
	local dir = ( v:GetPos() + Vector( 0, 0, 40 ) - start ):GetNormalized()
	local function swing( heavy )
		v:SetHealth( 100 )
		v.GR_Consciousness = 100
		local tr = baton:MeleeSwing( heavy, start, dir )
		if tr.Entity ~= v then T.Note( "swing hit %s", tostring( tr.Entity ) ) end
		return 100 - v:Health()
	end
	local normal = swing( false )
	T.Equal( normal, 20, "a baton hit does its damage" )
	T.Equal( swing( true ), normal, "a heavy hit does no extra damage (the original never applied it)" )

	local function holdBlock( ply, cmd )
		if ply == v then cmd:SetButtons( bit.bor( cmd:GetButtons(), IN_ATTACK2 ) ) end
	end
	hook.Add( "StartCommand", "t16f_block", holdBlock )
	T.Wait( 0.2 )
	T.Check( not v:GetActiveWeapon():IsBlocking(), "a holstered baton doesn't block" )
	Weapons.SetHolstered( v, false )
	T.WaitUntil( function() return v:GetActiveWeapon():IsBlocking() end, 2, "right-click held with the baton out blocks" )
	T.Equal( swing( false ), normal, "a block doesn't reduce damage (the original never applied it)" )
	hook.Remove( "StartCommand", "t16f_block" )
	Weapons.SetHolstered( v, true )
	T.Wait( 0.2 )

	a:SelectWeapon( "weapon_gr_hands" )
	T.Wait( 0.1 )
	local hands = a:GetActiveWeapon()
	Weapons.SetHolstered( a, false )
	a:SetHealth( 100 )
	a.GR_Consciousness = 100
	local tr = hands:MeleeSwing( false, a:GetPos() + Vector( 0, 0, 20 ), Vector( 0, 0, -1 ) )
	T.Check( tr.HitWorld, "a punch at the floor hits the world" )
	T.Equal( 100 - a:Health(), hands.Damage, "fists on a wall hurt the one punching" )
	a:SetHealth( 100 )
	v:SetHealth( 100 )
	v.GR_Consciousness = 100
	hands:MeleeSwing( false, start, dir )
	T.Check( a:Health() == 100 and v:Health() < 100, "fists on flesh hurt the other one" )
	Weapons.SetHolstered( a, true )

	-- Spread ----------------------------------------------------------------------------------------
	local acc = a:FateHas( "AccuracyMulti" ) or 1
	local still = Weapons.SpreadMultiplier( a, { speed = 0 } )
	T.Check( near( still, 0.7 * acc, 1e-6 ), "standing: base x0.7 x the fate's AccuracyMulti" )
	T.Check( near( Weapons.SpreadMultiplier( a, { speed = 50 } ), still * 1.5, 1e-6 ), "walking: x1.5" )
	T.Check( near( Weapons.SpreadMultiplier( a, { speed = 200 } ), still * 1.5, 1e-6 ), "running is x1.5 too (the original's unreachable x2.5, kept)" )
	T.Check( near( Weapons.SpreadMultiplier( a, { speed = 0, onGround = false } ), still * 5, 1e-6 ), "in the air: x5" )
	T.Check( near( Weapons.SpreadMultiplier( a, { speed = 0, crouched = true } ), still * 0.65, 1e-6 ), "crouched: x0.65" )
	a:SetInjured( true )
	T.Check( near( Weapons.SpreadMultiplier( a, { speed = 0 } ), still * 1.3, 1e-6 ), "injured: x1.3" )
	a:SetInjured( false )
	a:SelectWeapon( "weapon_gr_pistol" )
	T.Wait( 0.1 )
	pistol = a:GetActiveWeapon()
	T.Equal( Weapons.Spread( a ), 0, "holstered: no crosshair spread" )
	Weapons.SetHolstered( a, false )
	T.Check( Weapons.Spread( a ) > 0, "drawn: Weapons.Spread gives the cone for the HUD" )

	-- Reloading blocks jumping ----------------------------------------------------------------------
	T.Check( Movement.CanJump( a ), "a free body can jump" )
	pistol:SetClip1( 0 )
	a:SetAmmo( 16, "Pistol" )
	pistol:Reload()
	T.Check( pistol:GetReloading(), "reloading" )
	T.Check( not Movement.CanJump( a ), "no jumping while reloading" )
	T.WaitUntil( function() return not pistol:GetReloading() end, 5, "the reload finishes" )
	T.Equal( pistol:Clip1(), 8, "the clip is full" )
	T.Check( Movement.CanJump( a ), "jumping again after the reload" )
	Weapons.SetHolstered( a, true )

	-- Leg shot: never stops jumping (parity ruling) ----------------------------------------------
	v:SetHealth( 100 )
	v.GR_LastHitGroup = HITGROUP_RIGHTLEG
	hit( v, a, 4 )
	T.Check( Movement.CanJump( v ), "a bullet in the leg doesn't stop jumping" )
	T.Check( Movement.JumpLockLeft == nil, "there is no leg-shot jump lock" )

	-- Jumping interrupts surgery --------------------------------------------------------------------
	v:SetHealth( 50 )
	k:SetPos( v:GetPos() + Vector( 40, 0, 0 ) )
	T.Check( Medicine.StartSurgery( k, v, "laparotomy" ), "surgery starts" )
	Movement.JumpPressed( k )
	T.Check( Actions.Get( k ) == nil, "jumping interrupts the surgery" )
	Actions.Start( k, "t16f_other", v, 5 )
	Movement.JumpPressed( k )
	T.Check( Actions.Get( k ) ~= nil, "other actions don't care" )
	Actions.Cancel( k )

	-- Spit ------------------------------------------------------------------------------------------
	a.GR_NextSpit = 0
	Weapons.SetHolstered( a, false )
	T.Equal( Weapons.Spit( a ), "shove", "G with a gun out is the melee shove" )
	Weapons.SetHolstered( a, true )
	T.Equal( Weapons.Spit( a ), nil, "spitting has a cooldown" )
	a.GR_NextSpit = 0
	T.Equal( Weapons.Spit( a ), "spit", "G holstered spits" )

	-- Dragging --------------------------------------------------------------------------------------
	hit( v, a, 500 )
	T.WaitUntil( function() return Corpse.Of( v ) ~= nil end, 3, "the victim is down" )
	local rag = Corpse.Of( v )
	if not IsValid( rag ) then return end
	T.Equal( Corpse.Get( rag ).state, "downed", "a downed body" )
	a:SetPos( rag:GetPos() + Vector( 30, 0, 0 ) )
	T.Check( Interact.Run( a, "drag", rag ), "drag is offered on a downed body" )
	T.Check( Drag.Of( a ) == rag and a:GetDragging() == rag:EntIndex(), "dragging it" )
	T.Check( not Interact.Run( k, "drag", rag ), "someone else can't take it while it's dragged" )
	a:SetPos( rag:GetPos() + Vector( 60, 0, 0 ) )
	Drag.Tick()
	T.Check( Drag.Of( a ) == rag, "within reach it follows" )
	a:SetPos( rag:GetPos() + Vector( 300, 0, 0 ) )
	Drag.Tick()
	T.Check( Drag.Of( a ) == nil and a:GetDragging() == 0, "past 128 units it snaps free" )
	a:SetPos( rag:GetPos() + Vector( 30, 0, 0 ) )
	T.Check( Interact.Run( a, "drag", rag ), "drag again" )
	T.Check( Interact.Run( a, "drag_stop", rag ) and Drag.Of( a ) == nil, "let go" )
	T.Equal( Drag.SNAP, 128, "the snap distance is 128" )

	Medicine.REGEN_RATE = regen
end
