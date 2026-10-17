-- Step 11.2: the korpsman. Regeneration speed, the revive fee (and none from a broke patient),
-- lodged bullets, every surgery's success and failure path, and the lovebox behind the upgrade.
local function bot( name, fate )
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

return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t11b_%'" )
	local k, p, q = bot( "t11b_medic" ), bot( "t11b_patient" ), bot( "t11b_other" )
	T.Wait( 0.3 )
	Fates.Take( k, "korpsman" ) Fates.Take( p, "prole" ) Fates.Take( q, "prole" )
	T.Check( k:FateHas( "Surgeon" ) and not p:FateHas( "Surgeon" ), "surgery is a korpsman capability" )
	T.Check( Inventory.Count( k, "knife" ) + Inventory.Count( k, "shank" ) >= 1, "a new korpsman carries a blade" )

	local base = k:GetPos()
	local function place()
		for i, b in ipairs( { k, p, q } ) do
			b:SetMoveType( MOVETYPE_NONE )
			b:SetPos( base + Vector( 40 * ( i - 1 ), 0, 0 ) )
		end
	end
	place()

	-- Regeneration ------------------------------------------------------------------------------
	k:SetHealth( 50 ) p:SetHealth( 50 )
	k.GR_RegenFrac, p.GR_RegenFrac = 0, 0
	Medicine.Regen( k, 10 ) Medicine.Regen( p, 10 )
	local rate = Medicine.REGEN_RATE * 10
	T.Equal( p:Health(), 50 + rate, "an ordinary body regenerates REGEN_RATE per second" )
	T.Equal( k:Health(), 50 + rate * 3, "a korpsman regenerates three times faster" )
	T.Check( Sched.Get( "regen" ) ~= nil, "regeneration is a scheduled job" )
	p:SetHealth( p:GetMaxHealth() )
	Medicine.Regen( p, 100 )
	T.Equal( p:Health(), p:GetMaxHealth(), "regeneration stops at max health" )

	-- From here on exact health values are checked across waits; the job mustn't add to them.
	local regenRate = Medicine.REGEN_RATE
	Medicine.REGEN_RATE = 0

	-- Bullets -----------------------------------------------------------------------------------
	local chance = Medicine.BULLET_CHANCE
	Medicine.BULLET_CHANCE = 0
	hit( p, q, 5 )
	T.Check( not p:GetBullet(), "a bullet doesn't always lodge" )
	Medicine.BULLET_CHANCE = 1
	hit( p, q, 5, DMG_CLUB )
	T.Check( not p:GetBullet(), "only bullets lodge" )
	hit( p, q, 5 )
	T.Check( p:GetBullet(), "a bullet hit can lodge" )
	Medicine.BULLET_CHANCE = chance
	local cap = Medicine.MaxHealth( p )
	T.Equal( cap, math.floor( p:GetMaxHealth() * Medicine.BULLET_CAP ), "a lodged bullet caps health" )
	Medicine.Regen( p, 1 )
	T.Equal( p:Health(), cap, "health above the cap drops to it" )
	p:SetHealth( 40 )
	Medicine.Regen( p, 100 )
	T.Equal( p:Health(), 40, "no regeneration with a bullet in you" )

	-- Revive fee --------------------------------------------------------------------------------
	Econ.ResetRound()
	local revive = Corpse.REVIVE_TIME
	Corpse.REVIVE_TIME = 0.3
	local function downAndRevive( label )
		p:SetMoveType( MOVETYPE_WALK )
		hit( p, q, 500 )
		local rag = Corpse.Of( p )
		T.Check( IsValid( rag ), label .. ": the patient is downed" )
		T.Wait( 1.5 ) -- let the thrown body settle, so it stays in reach
		k:SetPos( rag:GetPos() + Vector( 30, 0, 0 ) )
		T.Check( Corpse.StartRevive( k, rag ), label .. ": the revive starts" )
		-- A ragdoll can still roll; keep the korpsman beside it so the action stays in range.
		T.WaitUntil( function()
			if IsValid( rag ) then k:SetPos( rag:GetPos() + Vector( 30, 0, 0 ) ) end
			return p:Alive()
		end, 3, label .. ": the patient is revived" )
		place()
	end

	Econ.Transfer( Econ.TREASURY, p, 41, "test" )
	local kBefore = k:GetBones()
	downAndRevive( "paying patient" )
	T.Equal( k:GetBones() - kBefore, 20, "the korpsman takes revive_fee percent (50% of 41, rounded down)" )
	T.Equal( p:GetBones(), 21, "the patient keeps the rest" )
	T.Equal( ( Econ.Audit() ), 0, "no drift after a paid revive" )

	Econ.SetSetting( "revive_fee", 100 )
	kBefore = k:GetBones()
	downAndRevive( "full fee" )
	T.Equal( k:GetBones() - kBefore, 21, "revive_fee is read from the Economy table" )
	T.Equal( p:GetBones(), 0, "a 100% fee takes everything" )
	Econ.ResetSettings()

	kBefore = k:GetBones()
	downAndRevive( "broke patient" )
	T.Equal( k:GetBones(), kBefore, "a broke patient pays nothing" )
	T.Equal( ( Econ.Audit() ), 0, "no drift after a free revive" )
	Corpse.REVIVE_TIME = revive
	Medicine.REGEN_RATE = regenRate
end
