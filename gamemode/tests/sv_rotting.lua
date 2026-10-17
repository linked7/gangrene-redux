-- Rotting and corpse recycling: the four stages on the original's timings, 3/4 of the bones kept
-- per stage, bleedout never rotting, a slave rotting fast, and the corpse washer's payout.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:trot_%'" )
	local b = player.CreateNextBot( "trot_body" )
	local cop = player.CreateNextBot( "trot_cop" )
	T.Wait( 0.3 )
	b:SetRank( RANK_FRIEND ); cop:SetRank( RANK_FRIEND )
	b:SetStemCells( 10 ); cop:SetStemCells( 10 )
	T.Check( Fates.Take( b, "sanitar" ), "the body's owner takes a fate" )
	T.Check( Fates.Take( cop, "korpsman" ), "the cop takes a fate" )
	T.Check( Rotting.FIRST == 60 and Rotting.LATER == 120, "stage lengths match the original" )

	b:Kill()
	local rag = Corpse.Of( b )
	T.Check( IsValid( rag ), "the dead player leaves a body" )
	local rec = Corpse.Get( rag )
	T.Check( rec.rotStage == nil, "a body in bleedout does not rot" )
	Corpse.Die( rag, "test" )
	T.Equal( rec.rotStage, 1, "a dead body starts at stage 1" )
	T.Check( math.abs( ( rec.rotFinish - rec.rotStart ) - 60 ) < 0.1, "stage 1 lasts 60 s" )

	Econ.Transfer( Econ.TREASURY, rag, 400, "test" )
	local before = rec.bones
	rec.rotFinish = CurTime() - 1
	T.WaitUntil( function() return rec.rotStage == 2 end, 4, "stage 2 reached" )
	local r2 = rec.rag
	T.Check( IsValid( r2 ) and r2 ~= rag and r2:GetModel() == "models/zombie/fast.mdl", "stage 2 swaps to the fast zombie" )
	T.Equal( rec.bones, math.floor( before * 0.75 ), "a stage keeps 3/4 of the bones" )
	T.Check( Corpse.Get( r2 ) == rec and Corpse.Get( rag ) == nil, "the record follows the new ragdoll" )
	T.Equal( r2:GetCollisionGroup(), COLLISION_GROUP_WEAPON, "the new body is weapon-collision" )
	T.Check( math.abs( ( rec.rotFinish - rec.rotStart ) - 120 ) < 0.1, "stage 2 lasts 120 s" )
	T.Equal( Econ.Audit(), 0, "the bones still balance after a swap" )

	rec.rotFinish = CurTime() - 1
	T.WaitUntil( function() return rec.rotStage == 3 end, 4, "stage 3 reached" )
	T.Check( rec.rag:GetModel() == "models/player/charple.mdl", "stage 3 is charred" )
	rec.rotFinish = CurTime() - 1
	T.WaitUntil( function() return rec.rotStage == 4 end, 4, "stage 4 reached" )
	T.Check( rec.rag:GetModel() == "models/player/skeleton.mdl", "stage 4 is a skeleton" )
	rec.rotFinish = CurTime() - 1
	T.Wait( 1.5 )
	T.Equal( rec.rotStage, 4, "the skeleton is terminal" )
	T.Check( rec.decayAt > CurTime() + 100, "the despawn waits for the last stage" )

	-- Recycling.
	local reward = Rotting.Reward( rec.bones )
	T.Equal( Rotting.Reward( 3 ), 30, "the reward is at least 30" )
	T.Equal( Rotting.Reward( 9999 ), 500, "and at most 500" )
	T.Equal( Rotting.CopCut( 500 ), 150, "the cop's cut is capped at 150" )
	T.Equal( Rotting.CopCut( 40 ), 40, "otherwise a quarter plus 30" )
	local tre = Econ.Treasury()
	local held = Econ.Balance and Econ.Balance( cop ) or 0
	local final = rec.rag
	T.Check( Rotting.Recycle( final, cop, nil ), "a body can be recycled" )
	T.Wait( 0.2 )
	T.Check( not IsValid( final ), "the body is gone after washing" )
	T.Equal( Econ.Audit(), 0, "recycling keeps the ledger balanced" )

	-- A slave rots fast.
	T.Equal( Fates.Get( "slave" ).DecayOverride, 30, "a slave's first stage is 30 s" )
	b:Spawn()

	-- The miasma sickens everyone but a sanitar.
	T.Wait( 0.2 )
	local fake = { rotStage = 2, state = "dead" }
	cop:SetPos( Vector( 0, 0, 0 ) ); b:SetPos( Vector( 20, 0, 0 ) )
	local copPox, bPox, copHp, bHp = Needs.Get( cop, "Pox" ), Needs.Get( b, "Pox" ), cop:Health(), b:Health()
	Rotting.Miasma( cop, fake )
	T.Check( Needs.Get( cop, "Pox" ) > copPox, "the miasma gives a cop the pox" )
	T.Check( cop:Health() < copHp, "and poisons them" )
	T.Equal( Needs.Get( b, "Pox" ), bPox, "a sanitar is not sickened" )
	T.Equal( b:Health(), bHp, "or poisoned" )
	cop:SetPos( Vector( 5000, 0, 0 ) )
	copPox = Needs.Get( cop, "Pox" )
	Rotting.Miasma( b, fake )
	T.Equal( Needs.Get( cop, "Pox" ), copPox, "far away it does nothing" )
end
