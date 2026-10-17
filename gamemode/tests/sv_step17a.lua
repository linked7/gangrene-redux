-- Step 17a: parity gaps (docs/05 §7-§14, server side). Ghosts are spectators; intro texts on taking
-- a fate; "Got/Lost N Bones" notices; the big red wanted line with its alarm, despair and hide time;
-- spit (the despair cap, the Kaiser's harder spit, evidence for spitting on the law); the poor
-- shot's unholster warning; Call Korpsman (refusals, the 50-bone fee, payment on a full heal); the
-- get-up line; pain grunts and death screams.
local function bot( name )
	local b = player.CreateNextBot( "t17a_" .. name )
	b:SetRank( RANK_FRIEND )
	b:SetStemCells( 10 )
	return b
end

local function hit( victim, attacker, amount, group )
	victim.GR_LastHitGroup = group
	local d = DamageInfo()
	d:SetDamage( amount )
	d:SetDamageType( DMG_BULLET )
	d:SetAttacker( attacker )
	d:SetInflictor( attacker )
	victim:TakeDamageInfo( d )
end

local function setBones( b, n )
	Econ.Transfer( b, Econ.TREASURY, b:GetBones(), "test" )
	Econ.Transfer( Econ.TREASURY, b, n, "test" )
end

local function despair( b, n )
	Needs.Add( b, "Despair", -1000, "test" )
	if n > 0 then Needs.Add( b, "Despair", n, "test" ) end
end

return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t17a_%'" )

	local tells, bigs, notices, sounds = {}, {}, {}, {}
	hook.Add( "GR_ChatTell", "t17a", function( ply, col, text ) table.insert( tells, { ply = ply, col = col, text = text } ) end )
	hook.Add( "GR_ChatBig", "t17a", function( to, col, text ) table.insert( bigs, { to = to, col = col, text = text } ) end )
	hook.Add( "GR_NoticeSent", "t17a", function( ply, col, text ) table.insert( notices, { ply = ply, col = col, text = text } ) end )
	hook.Add( "EntityEmitSound", "t17a", function( data ) table.insert( sounds, { ent = data.Entity, snd = data.SoundName } ) end )
	local function told( ply, pattern )
		for _, t in ipairs( tells ) do
			if t.ply == ply and string.find( t.text, pattern, 1, true ) then return t end
		end
	end
	local function heard( ent, list )
		for _, s in ipairs( sounds ) do
			if s.ent == ent and ( list == nil or table.HasValue( list, s.snd ) ) then return s.snd end
		end
	end
	local function clear() tells, bigs, notices, sounds = {}, {}, {}, {} end

	local a, v, k, s = bot( "a" ), bot( "v" ), bot( "k" ), bot( "s" )
	local all = { a, v, k, s }
	T.Wait( 0.3 )
	local regen, wake = Medicine.REGEN_RATE, Config.WakeTime
	Medicine.REGEN_RATE = 0

	-- Teams -----------------------------------------------------------------------------------------
	T.Check( a:IsGhost(), "a new player is a ghost" )
	T.Equal( a:Team(), TEAM_SPECTATOR, "ghosts are on the spectator team" )

	-- Intro texts ------------------------------------------------------------------------------------
	clear()
	T.Check( Fates.Take( a, "prole" ), "a takes prole" )
	T.Equal( a:Team(), TEAM_CITIZEN, "the living are on the citizen team" )
	T.Check( told( a, "You are an unpatriotic resident of Gangrene." ), "the prole's intro is told" )
	local named = told( a, "You were always known as the " .. a:Nick() .. " to the People." )
	T.Check( named and named.col.r == 100, "with the name filled in, in grey" )
	Fates.Take( v, "prole" ) Fates.Take( k, "korpsman" )
	clear()
	Fates.Apply( s, "sanitar", { reason = "admin" } )
	T.Check( not told( s, "codename" ), "an admin fate change tells no intro" )
	T.Check( Fates.Get( "slave" ).IntroTexts and Fates.Get( "korpsman" ).IntroTexts and Fates.Get( "kaiser" ).IntroTexts,
		"slave, korpsman and kaiser have intros" )

	local base = a:GetPos()
	for i, b in ipairs( all ) do
		b:SetMoveType( MOVETYPE_NONE )
		b:SetPos( base + Vector( 60 * ( i - 1 ), 0, 0 ) )
	end
	-- A bot's eye angles only change on its next command, so targets are moved into its aim instead.
	local function inFront( from, to )
		local dir = from:GetAimVector()
		dir.z = 0
		dir:Normalize()
		to:SetPos( from:GetPos() + dir * 60 )
	end
	local function lineUp( from, to )
		inFront( from, to )
		T.WaitUntil( function()
			local start = from:GetShootPos()
			return util.TraceLine( { start = start, endpos = start + from:GetAimVector() * Weapons.SPIT_RANGE, filter = from } ).Entity == to
		end, 3, from:Nick() .. " has " .. to:Nick() .. " in their sights" )
	end
	local function aside( b, i ) b:SetPos( base + Vector( -200, 80 * i, 0 ) ) end

	-- Bones notices ----------------------------------------------------------------------------------
	setBones( a, 0 )
	clear()
	Econ.Transfer( Econ.TREASURY, a, 5, "wage" )
	T.Check( notices[ 1 ] and notices[ 1 ].ply == a and notices[ 1 ].text == "Got 5 Bones" and notices[ 1 ].col.g == 200,
		"getting bones: \"Got 5 Bones\" in green" )
	clear()
	Econ.Transfer( a, k, 3, "revive fee" )
	T.Check( notices[ 1 ] and notices[ 1 ].ply == a and notices[ 1 ].text == "Revival Fee: Lost 3 Bones" and notices[ 1 ].col.r == 200,
		"losing bones: \"Revival Fee: Lost 3 Bones\" in red" )
	T.Check( notices[ 2 ] and notices[ 2 ].ply == k and notices[ 2 ].text == "Revival Fee: Got 3 Bones", "and the korpsman is told too" )
	clear()
	Econ.Transfer( k, Econ.TREASURY, 3, "downed" )
	T.Equal( #notices, 0, "bones riding on a body are silent" )

	-- Wanted line ------------------------------------------------------------------------------------
	despair( a, 0 )
	clear()
	Crime.MakeWanted( a, WANTED_DEATH, 60, "murder" )
	T.Check( bigs[ 1 ] and bigs[ 1 ].to == nil and bigs[ 1 ].text == "DEATH to " .. a:Nick() .. " for murder!" and bigs[ 1 ].col.r == 200,
		"everyone gets the big red line" )
	T.Check( told( a, "You should hide for 1 minute." ), "the criminal is told how long to hide" )
	T.Equal( Needs.Get( a, "Despair" ), 1, "and despairs a little" )
	local alarms = 0
	for _, x in ipairs( sounds ) do if x.ent == a and x.snd == "ambient/alarms/manhack_alert_pass1.wav" then alarms = alarms + 1 end end
	T.Equal( alarms, 3, "three alarms" )
	clear()
	Crime.MakeWanted( a, WANTED_TORMENT, 30, "theft" )
	T.Equal( #bigs, 0, "a lesser, shorter crime on top isn't shouted again" )
	Crime.MakeWanted( a, WANTED_DEATH, 600, "policide" )
	T.Check( bigs[ 1 ] and string.find( bigs[ 1 ].text, "for policide!", 1, true ), "a longer one is" )
	Crime.ClearWanted( a )

	-- Spit -------------------------------------------------------------------------------------------
	Weapons.SetHolstered( a, true )
	aside( s, 1 ) aside( k, 2 )
	lineUp( a, v )
	despair( v, 79 )
	a.GR_NextSpit = 0
	T.Equal( Weapons.Spit( a ), "spit", "a spits at v" )
	T.Equal( Needs.Get( v, "Despair" ), 80, "spit can't push despair past 80" )
	a.GR_NextSpit = 0
	Weapons.Spit( a )
	T.Equal( Needs.Get( v, "Despair" ), 80, "not even twice" )
	T.Check( next( Crime.Evidence( a ) ) == nil, "spitting on a prole is no crime" )
	despair( v, 0 )
	a.GR_NextSpit = 0
	Weapons.Spit( a )
	T.Equal( Needs.Get( v, "Despair" ), 4, "a spit is 4 despair" )

	aside( v, 3 )
	lineUp( a, s )
	a.GR_NextSpit = 0
	Weapons.Spit( a )
	T.Check( Crime.Evidence( a )[ "disrespecting Sanitar Squad" ], "spitting on a sanitar is evidence of disrespect" )
	T.Equal( Crime.Evidence( a )[ "disrespecting Sanitar Squad" ].duration, 180, "for 180 s" )
	aside( s, 1 )

	Fates.Apply( k, "kaiser", { reason = "admin" } )
	lineUp( a, k )
	a.GR_NextSpit = 0
	Weapons.Spit( a )
	T.Check( Crime.Evidence( a )[ "disrespecting the Witch Kaiser" ], "spitting on the Kaiser is evidence too" )
	T.Equal( Crime.Evidence( a )[ "disrespecting the Witch Kaiser" ].duration, 300, "for 300 s" )
	aside( k, 2 )
	lineUp( k, a )
	despair( a, 0 )
	k.GR_NextSpit = 0
	T.Equal( Weapons.Spit( k ), "spit", "the Kaiser spits" )
	T.Equal( Needs.Get( a, "Despair" ), 8, "the Kaiser's spit is 8 despair" )
	T.Check( next( Crime.Evidence( k ) ) == nil, "and no crime" )
	Fates.Apply( k, "korpsman", { reason = "admin" } )
	for i, b in ipairs( all ) do b:SetPos( base + Vector( 60 * ( i - 1 ), 0, 0 ) ) end
	T.Wait( 0.1 )
	Crime.TakeEvidence( a, "disrespecting Sanitar Squad" )
	Crime.TakeEvidence( a, "disrespecting the Witch Kaiser" )

	-- Unholster warning ------------------------------------------------------------------------------
	Inventory.Add( a, "pistol", 1, true )
	a:SelectWeapon( "weapon_gr_pistol" )
	T.Wait( 0.1 )
	local pistol = a:GetActiveWeapon()
	T.Check( IsValid( pistol ) and pistol.Firearm, "a has a pistol" )
	clear()
	Weapons.SetHolstered( a, false )
	T.Check( told( v, a:Nick() .. " prepares to fire!" ), "a prole drawing a gun warns those near" )
	T.Check( told( a, "prepares to fire!" ).col.r == 220, "in yellow" )
	T.Check( pistol:GetNextPrimaryFire() >= CurTime() + 1.4, "and can't fire for 1.5 s" )
	T.Check( heard( a, { "placenta/unholster.wav" } ), "with the unholster sound" )
	clear()
	Weapons.SetHolstered( a, true )
	Weapons.SetHolstered( a, false )
	T.Equal( #tells, 0, "not again within 3 s" )
	Weapons.SetHolstered( a, true )
	Inventory.Add( k, "pistol", 1, true )
	k:SelectWeapon( "weapon_gr_pistol" )
	T.Wait( 0.1 )
	clear()
	Weapons.SetHolstered( k, false )
	T.Equal( #tells, 0, "a good shot draws quietly" )
	Weapons.SetHolstered( k, true )

	-- Call Korpsman ----------------------------------------------------------------------------------
	v:SetHealth( v:GetMaxHealth() )
	setBones( v, 60 )
	T.Check( not Parity.CallKorpsman( v ), "not at full health" )
	v:SetHealth( 50 )
	setBones( v, 40 )
	local ok, why = Parity.CallKorpsman( v )
	T.Check( not ok and why == "An emergency call requires 50 Bones. It sucks to be poor!", "not without 50 bones" )
	s:SetHealth( 50 )
	setBones( s, 60 )
	ok, why = Parity.CallKorpsman( s )
	T.Check( not ok and why == "This action is only available to citizens.", "only citizens may call" )
	setBones( v, 60 )
	clear()
	T.Check( Parity.CallKorpsman( v ), "a hurt citizen calls the korpsmen" )
	T.Equal( v:GetBones(), 10, "for 50 bones" )
	T.Check( v:GetEmergency(), "and is marked an emergency" )
	T.Check( told( v, "Korpsmen have been alerted to your location." ), "told help is coming" )
	T.Check( bigs[ 1 ] and istable( bigs[ 1 ].to ) and table.HasValue( bigs[ 1 ].to, k )
		and bigs[ 1 ].text == "Someone is requesting assistance! You will get paid 50 bones after fully healing them.",
		"the korpsmen get the big line" )
	T.Check( heard( k, { "npc/turret_floor/active.wav" } ), "and the alert sound" )

	setBones( k, 0 )
	local half = { id = "t17a_half", fail = 0, done = function( _, t ) t:SetHealth( 75 ) end }
	local full = { id = "t17a_full", fail = 0, done = function( _, t ) t:SetHealth( Medicine.MaxHealth( t ) ) end }
	Medicine.FinishSurgery( k, v, half )
	T.Check( v:GetEmergency() and k:GetBones() == 0, "a partial heal pays nothing" )
	Medicine.FinishSurgery( k, v, full )
	T.Equal( k:GetBones(), 50, "healing to full pays the korpsman 50" )
	T.Check( not v:GetEmergency(), "and the emergency is over" )
	v:SetHealth( 40 )
	setBones( v, 50 )
	Parity.CallKorpsman( v )
	v:SetHealth( v:GetMaxHealth() )
	T.WaitUntil( function() return not v:GetEmergency() end, 3, "healed some other way, the emergency clears" )

	-- Pain and death sounds --------------------------------------------------------------------------
	T.Equal( Parity.PainSound( s, HITGROUP_GENERIC ):sub( 1, 15 ), "placenta/pain/s", "a sanitar grunts its own" )
	T.Check( table.HasValue( Parity.PAIN_SOUNDS.leg, Parity.PainSound( k, HITGROUP_LEFTLEG ) ),
		"a korpsman hit in the leg says so" )
	v:SetHealth( 100 )
	v.GR_NextGrunt = 0
	clear()
	hit( v, a, 10, HITGROUP_CHEST )
	T.Check( heard( v, Fates.Get( "prole" ).PainSounds ), "a hurt prole grunts" )
	clear()
	hit( v, a, 10, HITGROUP_CHEST )
	T.Check( not heard( v ), "not again so soon" )

	-- Get-up line and the scream on going down -------------------------------------------------------
	Config.WakeTime = 1
	v:SetHealth( 100 )
	clear()
	hit( v, a, 100 + Config.LethalOverkill - 1, HITGROUP_CHEST )
	local rag = Corpse.Of( v )
	T.Check( IsValid( rag ), "v goes down" )
	T.Check( heard( rag, Fates.Get( "prole" ).DeathSounds ), "screaming" )
	T.WaitUntil( function() return v:Alive() end, 4, "v gets up" )
	local line = told( a, v:Nick() )
	T.Check( line and line.col.g == 125, "those near see it in green" )
	T.Check( line and ( line.text == v:Nick() .. " gets up." or table.HasValue( Parity.STANDUP_LINES, string.sub( line.text, #v:Nick() + 1 ) ) ),
		"\"<name> gets up.\" or one of the special lines" )

	v:SetHealth( 100 )
	clear()
	hit( v, a, 100 + Config.LethalOverkill - 1, HITGROUP_HEAD )
	rag = Corpse.Of( v )
	T.Check( IsValid( rag ) and not heard( rag ), "no scream after a head hit" )
	clear()
	Corpse.Die( rag, "test" )
	T.Check( heard( rag, Fates.Get( "prole" ).DeathSounds ), "final death screams" )
	T.Check( Fates.Get( "kaiser" ).NoFinalDeathSound, "except for the Kaiser" )

	T.Equal( ( Econ.Audit() ), 0, "no bone drift" )

	-- Cleanup
	Medicine.REGEN_RATE = regen
	Config.WakeTime = wake
	for _, n in ipairs( { "GR_ChatTell", "GR_ChatBig", "GR_NoticeSent", "EntityEmitSound" } ) do hook.Remove( n, "t17a" ) end
	for _, b in ipairs( all ) do b:Kick( "test" ) end
	T.Wait( 0.3 )
end
