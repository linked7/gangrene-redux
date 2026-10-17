-- Plan 03 step 11.2: the korpsman end to end. First revive: one revive_fee transfer, promotion, lovebox.
-- Lovebox primary/secondary/reload. Bloodletting freezes both, then the server rolls. Forced failure,
-- interrupt, cripplement, and no client-side way to fake a success.
local function bot( name )
	local b = player.CreateNextBot( name )
	b:SetRank( RANK_FRIEND )
	b:SetStemCells( 10 )
	return b
end

local function hit( victim, attacker, amount )
	local d = DamageInfo()
	d:SetDamage( amount )
	d:SetDamageType( DMG_BULLET )
	d:SetAttacker( attacker )
	d:SetInflictor( attacker )
	victim:TakeDamageInfo( d )
end

return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:tkm_%'" )
	local k, p, q = bot( "tkm_medic" ), bot( "tkm_patient" ), bot( "tkm_other" )
	T.Wait( 0.3 )
	Fates.Take( k, "korpsman" ) Fates.Take( p, "prole" ) Fates.Take( q, "prole" )
	local base = k:GetPos()
	local function place()
		for i, b in ipairs( { k, p, q } ) do
			b:SetMoveType( MOVETYPE_NONE )
			b:SetPos( base + Vector( 40 * ( i - 1 ), 0, 0 ) )
		end
	end
	place()
	local regenRate = Medicine.REGEN_RATE
	Medicine.REGEN_RATE = 0
	local notify = Notify
	Notify = function() end

	-- First revive -------------------------------------------------------------------------------
	Econ.ResetRound()
	local revive = Corpse.REVIVE_TIME
	Corpse.REVIVE_TIME = 0.3
	Econ.Transfer( Econ.TREASURY, p, 100, "test" )
	T.Check( not Medicine.UpgradedMedic( k ), "a new korpsman isn't upgraded" )
	local before, fees = k:GetBones(), 0
	hook.Add( "GR_BonesMoved", "tkm", function( _, _, amt, why ) if why == "revive_fee" then fees = fees + 1 end end )
	p:SetMoveType( MOVETYPE_WALK )
	hit( p, q, 500 )
	local rag = Corpse.Of( p )
	T.Check( IsValid( rag ), "the patient is downed" )
	T.Wait( 1.5 )
	k:SetPos( rag:GetPos() + Vector( 30, 0, 0 ) )
	T.Check( Corpse.StartRevive( k, rag ), "the revive starts" )
	T.WaitUntil( function()
		if IsValid( rag ) then k:SetPos( rag:GetPos() + Vector( 30, 0, 0 ) ) end
		return p:Alive()
	end, 3, "the patient is revived" )
	hook.Remove( "GR_BonesMoved", "tkm" )
	T.Equal( fees, 1, "exactly one revive_fee transfer" )
	T.Equal( k:GetBones() - before, 50, "exactly 50 of 100 bones go to the korpsman" )
	T.Equal( p:GetBones(), 50, "the patient keeps the other 50" )
	T.Check( Medicine.UpgradedMedic( k ), "the first revive promotes the korpsman" )
	T.Equal( Inventory.Count( k, "lovebox" ), 1, "and gives them a lovebox" )
	T.Equal( ( Econ.Audit() ), 0, "no drift after the revive" )
	Corpse.REVIVE_TIME = revive
	place() p:SetMoveType( MOVETYPE_NONE )

	-- Lovebox ------------------------------------------------------------------------------------
	local lb = k:GetWeapon( "weapon_gr_lovebox" )
	if not IsValid( lb ) then lb = k:Give( "weapon_gr_lovebox" ) end
	T.Check( IsValid( lb ), "the lovebox weapon exists" )
	k:SetHealth( 100 ) p:SetHealth( 40 )
	T.Check( lb:Love( p ), "primary heals" )
	T.Equal( p:Health(), 42, "a patient gains 2 HP a tick" )
	T.Equal( k:Health(), 99, "and the korpsman pays 1 HP" )
	Needs.Add( p, "Pox", 50, "test" )
	local pox, kpox = Needs.Get( p, "Pox" ), Needs.Get( k, "Pox" )
	T.Check( lb:Soothe( p ), "secondary soothes" )
	T.Equal( Needs.Get( p, "Pox" ), pox - 3, "the patient's Pox drops by 3" )
	T.Equal( k:Health(), 97, "at 2 HP to the korpsman" )
	T.Check( Needs.Get( k, "Pox" ) - kpox <= 1, "the korpsman catches at most 1 Pox" )
	p:SetHealth( 50 )
	T.Check( not lb:Extract( p ), "reload refuses a healthy-ish patient" )
	p:SetHealth( 10 )
	Medicine.SetParasites( p, 2 )
	local function countItems() local n = 0 for _, e in ipairs( ents.GetAll() ) do if e:GetClass() == "gr_item" then n = n + 1 end end return n end
	local items = countItems()
	T.Check( lb:Extract( p ), "reload on a patient under a quarter health" )
	T.Equal( Medicine.Parasites( p ), 1, "removes a parasite" )
	T.Check( countItems() > items, "and drops it as an item" )
	k:SetHealth( 1 )
	T.Check( not lb:Love( p ), "at 1 HP the korpsman is too weak" )
	T.Equal( k:Health(), 1, "and loses nothing" )
	k:StripWeapons()

	-- Surgery ------------------------------------------------------------------------------------
	k:SetHealth( 100 )
	Inventory.Add( k, "knife", 1 )
	local proc = Medicine.Procedure( "bloodletting" )
	T.Equal( proc.duration, 10, "bloodletting takes 10 seconds" )
	local failBefore = proc.fail

	-- interrupt: nothing changes
	Needs.Add( p, "Pox", 50, "test" )
	p:SetHealth( 80 )
	pox = Needs.Get( p, "Pox" )
	local despair = Needs.Get( k, "Despair" )
	T.Check( Medicine.StartSurgery( k, p, "bloodletting" ), "surgery starts" )
	T.Check( k:IsFlagSet( FL_FROZEN ) and p:IsFlagSet( FL_FROZEN ), "both are frozen" )
	Actions.Cancel( k, "test" )
	T.Wait( 0.2 )
	T.Check( not k:IsFlagSet( FL_FROZEN ), "the korpsman is free after an interrupt" )
	T.Equal( Needs.Get( p, "Pox" ), pox, "an interrupt doesn't touch Pox" )
	T.Equal( Needs.Get( k, "Despair" ), despair, "or Despair" )
	T.Check( p:Health() >= 78, "and costs the patient almost nothing" )
	T.Check( p:IsFlagSet( FL_FROZEN ), "the patient is stunned briefly" )
	T.Wait( Medicine.STUN_TIME + 0.5 )
	T.Check( not p:IsFlagSet( FL_FROZEN ), "then released" )

	-- forced failure
	proc.fail = 1
	p:SetHealth( 80 )
	pox = Needs.Get( p, "Pox" )
	despair = Needs.Get( k, "Despair" )
	T.Check( Medicine.StartSurgery( k, p, "bloodletting" ), "surgery starts again" )
	T.Wait( 5 )
	T.Check( k:IsFlagSet( FL_FROZEN ), "still frozen halfway" )
	T.Wait( 5.5 )
	T.Check( not k:IsFlagSet( FL_FROZEN ) and not p:IsFlagSet( FL_FROZEN ), "released after 10 s" )
	T.Check( p:Health() <= 70 and p:Health() >= 50, "a failure costs the patient 10 HP (plus step cuts), hp=" .. p:Health() )
	T.Equal( Needs.Get( k, "Despair" ) - despair, Medicine.FAIL_DESPAIR, "and the korpsman 10 despair" )
	T.Check( Needs.Get( p, "Pox" ) <= pox, "Pox only goes down" )

	-- cripplement clears Injured
	proc.fail = failBefore
	p:SetHealth( 80 )
	Corpse.SetInjured( p, true )
	local c = Medicine.Procedure( "cripplement" )
	local cf = c.fail
	c.fail = 0
	Medicine.FinishSurgery( k, p, c, "knife", 100 )
	T.Check( not p:GetInjured(), "cripplement solution clears Injured" )
	c.fail = cf

	-- No client path to a success.
	local found = false
	for name in pairs( net.Receivers or {} ) do
		if string.find( name, "surgery" ) or string.find( name, "lovebox" ) then found = true end
	end
	T.Check( not found, "no net receiver lets a client report a surgery result" )
	T.Equal( ( Econ.Audit() ), 0, "no drift at the end" )

	Notify = notify
	Medicine.REGEN_RATE = regenRate
end
