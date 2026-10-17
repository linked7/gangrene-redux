-- Step 11.1: the prole. Kit and aim as fate data, the work loop (press -> crate -> carry ->
-- stockpile, paid the buy price), theft of someone else's crate, opening, the 3-crate cap,
-- and construction paid into the treasury. (The stockpile's lock is step16d.)
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t11a_%'" )

	local told = {}
	local realNotify = Notify
	Notify = function( ply, text )
		table.insert( told, { ply = ply, text = text } )
		realNotify( ply, text )
	end
	local function wasTold( ply, substr )
		for _, n in ipairs( told ) do
			if n.ply == ply and string.find( n.text, substr, 1, true ) then return true end
		end
		return false
	end

	local made = {}
	hook.Add( "GR_CrateMade", "t11a", function( ply, crate ) table.insert( made, crate ) end )
	local delivered = {}
	hook.Add( "GR_CrateDelivered", "t11a", function( ply, crate )
		table.insert( delivered, { ply = ply, crate = crate, kind = crate.GR_Kind } )
	end )

	local saved = { press = Crates.PRESS_TIME }
	Crates.PRESS_TIME = 0.5

	local function bot( name, fate, rank )
		local b = player.CreateNextBot( "t11a_" .. name )
		b:SetRank( rank )
		b:SetStemCells( 10 )
		T.Check( Fates.Take( b, fate ), name .. " takes " .. fate )
		return b
	end

	T.Wait( 0.2 )
	local p1 = bot( "prole1", "prole", RANK_FRIEND )
	local p2 = bot( "prole2", "prole", RANK_FRIEND )
	local sl = bot( "slave", "slave", RANK_FOOLISH )
	local san = bot( "san", "sanitar", RANK_FRIEND )

	-- Kit and aim ---------------------------------------------------------------------------------

	local function scrapCount( b )
		return Inventory.Count( b, "scrap" ) + Inventory.Count( b, "scrap_pipe" ) + Inventory.Count( b, "scrap_gear" )
	end
	T.Equal( Inventory.Count( p1, "permit_tool" ), 1, "a prole starts with a permit tool" )
	T.Equal( scrapCount( p1 ), 1, "and one random scrap item" )
	T.Equal( Inventory.Count( sl, "permit_tool" ), 1, "a slave gets the same kit" )
	T.Equal( scrapCount( sl ), 1, "including the scrap" )
	T.Equal( Inventory.Count( san, "permit_tool" ), 0, "a sanitar gets no prole kit" )

	local data = { Spread = Vector( 0.1, 0.1, 0 ) }
	T.Check( Kit.ModifyBullets( p1, data ), "a prole's bullets are modified" )
	T.Check( math.abs( data.Spread.x - 0.125 ) < 1e-6, "spread x1.25: " .. data.Spread.x )
	data = { Spread = Vector( 0.1, 0.1, 0 ) }
	Kit.ModifyBullets( sl, data )
	T.Check( math.abs( data.Spread.x - 0.125 ) < 1e-6, "a slave aims like a prole" )
	data = { Spread = Vector( 0.1, 0.1, 0 ) }
	T.Check( not Kit.ModifyBullets( san, data ) and math.abs( data.Spread.x - 0.1 ) < 1e-6, "a sanitar's aim is untouched" )
	T.Equal( p1:FateHas( "RecoilMulti" ), 1.3, "prole recoil multiplier is data" )

	-- The scene: everyone on the ground near p1, pinned; the sanitar far out of sight.
	Econ.ResetRound()
	local supply = Econ.Supply()
	local base = p1:GetPos()
	for _, b in ipairs( { p1, p2, sl, san } ) do b:SetMoveType( MOVETYPE_NONE ) end
	p2:SetPos( base + Vector( 0, -60, 0 ) )
	sl:SetPos( base + Vector( 0, 60, 0 ) )
	san:SetPos( base + Vector( 4000, 0, 0 ) )

	local press = ents.Create( "ration_press" )
	press:SetPos( base + Vector( 90, 0, 0 ) )
	press:SetAngles( Angle( 0, 180, 0 ) ) -- facing the bots: crates appear between
	press:Spawn()
	T.Check( IsValid( press ) and press:GetGood() == "ration", "a ration press spawns and makes rations" )

	local stockpile = ents.Create( "state_stockpile" )
	stockpile:SetPos( base + Vector( -110, 0, 0 ) )
	stockpile:Spawn()

	-- Make a crate ---------------------------------------------------------------------------------

	T.Check( Interact.Get( "press_work" ).show( p1, press ), "the C menu offers Work the press" )
	T.Check( Interact.Run( p1, "press_work", press ), "working the press through Interact" )
	T.Equal( Actions.Get( p1 ) and Actions.Get( p1 ).kind, "press", "working is a timed action" )
	T.Equal( Crates.Waiting( press ), 0, "no crate before the work is done" )
	T.WaitUntil( function() return #made >= 1 end, 3, "the press makes a crate" )
	local crate = made[ 1 ]
	T.Check( IsValid( crate ) and crate:GetClass() == "ent_crate", "it is an ent_crate" )
	T.Equal( crate.GR_Kind, "ration", "a ration crate" )
	T.Equal( crate.GR_MadeBy, DB.Key( p1 ), "stamped with the maker's key" )
	T.Check( crate:GetPos():Distance( press:GetPos() ) < 120, "beside the press" )
	T.Equal( Crates.Waiting( press ), 1, "one crate waiting" )

	-- Carrying: walk only, hands full, drops on a hit or a jump ------------------------------------------

	local walk, run = p1:GetWalkSpeed(), p1:GetRunSpeed()
	T.Equal( Crates.HeldBy( p1 ), nil, "not carrying yet" )
	Crates.Hold( p1, crate )
	T.Equal( Crates.HeldBy( p1 ), crate, "HeldBy names the carried crate" )
	T.Equal( p1:GetWalkSpeed(), walk, "carrying doesn't slow walking" )
	T.Equal( p1:GetRunSpeed(), walk, "but the carrier can't run" )
	T.Check( not IsValid( p1:GetActiveWeapon() ), "the weapon is holstered" )
	T.Check( hook.Run( "PlayerSwitchWeapon", p1, NULL, NULL ) == true, "and can't be drawn while carrying" )
	Crates.Release( p1 )
	T.Equal( Crates.HeldBy( p1 ), nil, "let go" )
	T.Check( p1:GetWalkSpeed() == walk and p1:GetRunSpeed() == run, "full speed again" )
	T.Check( hook.Run( "PlayerSwitchWeapon", p1, NULL, NULL ) ~= true, "hands free again" )

	Crates.Hold( p1, crate )
	local d = DamageInfo() d:SetDamage( 1 ) d:SetDamageType( DMG_CLUB ) d:SetAttacker( p2 ) d:SetInflictor( p2 )
	p1:TakeDamageInfo( d )
	T.Equal( Crates.HeldBy( p1 ), nil, "a hit makes the carrier drop it" )
	Crates.Hold( p1, crate )
	hook.Run( "KeyPress", p1, IN_JUMP )
	T.Equal( Crates.HeldBy( p1 ), nil, "so does jumping" )
	p1:SetHealth( p1:GetMaxHealth() )

	-- Deliver -----------------------------------------------------------------------------------------

	local before, treasury = p1:GetBones(), Econ.Treasury()
	Crates.Hold( p1, crate )
	T.Equal( Crates.Deliver( p1, crate, stockpile ), 20, "delivering pays the buy price" )
	T.Equal( p1:GetBones(), before + 20, "the deliverer has the bones" )
	T.Equal( Econ.Treasury(), treasury - 20, "out of the treasury" )
	T.Equal( Econ.Stock( "ration" ), 1, "the stock count went up" )
	T.Check( delivered[ 1 ] and delivered[ 1 ].ply == p1 and delivered[ 1 ].kind == "ration", "GR_CrateDelivered fired" )
	T.Check( not Crime.Evidence( p1 ).theft and not p1:IsWanted(), "delivering your own crate is no theft" )
	T.Check( p1:GetWalkSpeed() == walk, "delivering frees the carrier" )
	T.Wait( 0.1 )
	T.Check( not IsValid( crate ), "the delivered crate is gone" )
	T.Equal( Crates.Waiting( press ), 0, "and no longer counts against the press" )

	-- The touch itself: p1 lets go above the stockpile and it falls on it.
	crate = Crates.FinishWork( p1, press )
	Crates.Hold( p1, crate )
	Crates.Release( p1 )
	crate:SetPos( stockpile:LocalToWorld( Vector( 0, 0, stockpile:OBBMaxs().z + 15 ) ) )
	local phys = crate:GetPhysicsObject()
	if IsValid( phys ) then phys:Wake() phys:SetVelocity( Vector( 0, 0, -200 ) ) end
	before = p1:GetBones()
	T.WaitUntil( function() return not IsValid( crate ) end, 2.5, "a crate touching the stockpile is delivered" )
	T.Equal( p1:GetBones(), before + 20, "and the one who let go of it is paid" )

	-- Theft ---------------------------------------------------------------------------------------------

	crate = Crates.FinishWork( p1, press )
	before = p2:GetBones()
	T.Equal( Crates.Deliver( p2, crate, stockpile ), 20, "delivering someone else's crate still pays" )
	T.Equal( p2:GetBones(), before + 20, "the thief is paid, not the maker" )
	T.Check( Crime.Evidence( p2 ).theft ~= nil, "delivering someone else's crate is reported as theft" )
	T.Check( not p2:IsWanted(), "unseen: evidence, not wanted" )
	Crime.TakeEvidence( p2, "theft" )

	crate = Crates.FinishWork( p1, press )
	T.Check( Interact.Get( "crate_open" ).show( sl, crate ), "the C menu offers Open the crate" )
	T.Check( Crates.Open( sl, crate ), "a slave opens p1's crate" )
	T.Equal( Inventory.Count( sl, "ration" ), Crates.CONTENTS, "the contents go to the opener" )
	T.Check( Crime.Evidence( sl ).theft ~= nil, "opening someone else's crate is theft" )
	T.Check( not Crates.Open( p1, crate ), "a crate can only be opened once" )

	crate = Crates.FinishWork( p1, press )
	T.Check( Crates.Open( p1, crate ), "the maker opens their own crate" )
	T.Check( not Crime.Evidence( p1 ).theft, "no theft" )

	-- Caught in the act: the sanitar right beside the thief.
	san:SetPos( base + Vector( 0, -160, 0 ) )
	if Crime.SeenByPolice( p2 ) then
		crate = Crates.FinishWork( p1, press )
		Crates.Deliver( p2, crate, stockpile )
		T.Equal( p2:GetWanted(), WANTED_TORMENT, "theft in sight of the sanitar: wanted" )
		Crime.ClearWanted( p2 )
	else
		T.Note( "no clear line between sanitar and p2 here; caught-theft is covered by step10" )
	end
	san:SetPos( base + Vector( 4000, 0, 0 ) )

	-- Cap of 3 -------------------------------------------------------------------------------------------

	T.Wait( 0.1 )
	T.Equal( Crates.Waiting( press ), 0, "nothing waiting" )
	local three = {}
	for i = 1, 3 do three[ i ] = Crates.FinishWork( sl, press ) end
	T.Equal( Crates.Waiting( press ), 3, "three crates waiting" )
	T.Equal( Crates.FinishWork( sl, press ), nil, "a fourth is not made" )
	T.Check( not Crates.Work( p2, press ), "and the press refuses work" )
	T.Check( wasTold( p2, "piling up" ), "the worker is told why" )
	T.Equal( Crates.Waiting( press ), 3, "still three" )
	three[ 1 ]:Remove()
	T.Wait( 0.1 )
	T.Equal( Crates.Waiting( press ), 2, "hauling one away frees a slot" )
	T.Check( Crates.Work( p2, press ), "and the press takes work again" )
	T.WaitUntil( function() return Crates.Waiting( press ) == 3 end, 3, "the new crate fills the slot" )
	for _, c in ipairs( made ) do if IsValid( c ) then c:Remove() end end

	-- The stockpile pry is gone: its lock is beaten open instead (step16d).
	T.Check( Interact.Get( "stockpile_pry" ) == nil and Crates.StartPry == nil, "there is no timed pry" )

	-- Build ------------------------------------------------------------------------------------------------

	local tr = util.TraceLine( { start = p1:EyePos(), endpos = p1:EyePos() + Vector( 0, 60, -100 ), filter = p1 } )
	local spot = tr.HitPos
	local function setBones( b, n )
		Econ.Transfer( b, Econ.TREASURY, b:GetBones(), "test" )
		Econ.Transfer( Econ.TREASURY, b, n, "test" )
	end
	setBones( p1, 100 )
	treasury = Econ.Treasury()
	local box = Build.Place( p1, "storage_crate", spot )
	T.Check( IsValid( box ) and box:GetClass() == "storage_crate", "a storage crate is built" )
	T.Equal( p1:GetBones(), 65, "it cost 35" )
	T.Equal( Econ.Treasury(), treasury + 35, "paid into the treasury" )
	T.Equal( Econ.Ledger( 1 )[ 1 ].source, "construction", "the ledger shows construction" )
	T.Check( not Build.KINDS.factory_site and not Build.Place( p1, "factory_site", spot ), "production can't be built" )
	T.Equal( p1:GetBones(), 65, "and nothing was taken" )

	T.Check( not Build.Place( p1, "storage_crate", p1:EyePos() + Vector( 0, 0, -2000 ) ), "too far is refused" )
	T.Check( not Build.Place( p1, "palace", spot ), "unknown kinds are refused" )
	setBones( p1, 10 )
	T.Check( not Build.Place( p1, "storage_crate", spot ), "can't build without the bones" )
	T.Equal( p1:GetBones(), 10, "and nothing was taken" )
	Inventory.Remove( p1, "permit_tool", 1 )
	setBones( p1, 40 )
	T.Check( not Build.Place( p1, "storage_crate", spot ), "can't build without a permit tool" )
	T.Equal( p1:GetBones(), 40, "nothing taken" )
	T.Equal( ( Econ.Audit() ), 0, "no drift after the work loop and construction" )

	-- Cleanup
	for _, e in ipairs( { box, press, stockpile } ) do if IsValid( e ) then e:Remove() end end
	Crates.PRESS_TIME = saved.press
	hook.Remove( "GR_CrateMade", "t11a" )
	hook.Remove( "GR_CrateDelivered", "t11a" )
	Notify = realNotify
end
