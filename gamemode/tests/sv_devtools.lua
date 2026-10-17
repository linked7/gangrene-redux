-- Dev shortcuts: gr_die kills on the spot (no downed state), gr_respawn brings the caller straight
-- back as their last fate (or a named one). Slave gating is off (Config.SlaveGating).
return function( T )
	local a = player.CreateNextBot( "tdv_a" )
	local realStaff = Admin.IsStaff
	Admin.IsStaff = function( p ) return p == a end
	T.WaitUntil( function() return a:Alive() end, 3, "a spawns" )
	Fates.Apply( a, "prole", { reason = "admin" } )
	local fate = a:GetFateDef().id
	T.Check( Admin.Die( a ), "gr_die works" )
	T.WaitUntil( function() return not a:Alive() or a:IsGhost() end, 3, "a is dead" )
	T.Check( Corpse.Of( a ) == nil or not IsValid( Corpse.Of( a ) ) or select( 2, Corpse.Of( a ) ).state ~= "downed", "not left downed" )
	T.Check( Admin.Respawn( a ), "gr_respawn works" )
	T.Check( a:Alive() and not a:IsGhost(), "a is alive again" )
	T.Equal( a:GetFateDef().id, fate, "as the same fate" )
	Admin.Die( a )
	T.Check( Admin.Respawn( a, "prole" ) and a:GetFateDef().id == "prole", "or a named fate" )
	T.Check( not Admin.Respawn( a, "nope" ), "an unknown fate is refused" )

	a:SetRank( RANK_FOOLISH )
	Fates.Apply( a, FATE_GHOST, { reason = "admin" } )
	local _, why = Fates.CanTake( a, "prole" )
	T.Check( why ~= "You are not yet trusted with this purpose. Prove yourself first.", "slave gating is off: a Foolish player isn't refused for rank" )
	Admin.IsStaff = realStaff
	a:Kick()
end
