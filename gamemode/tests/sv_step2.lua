-- Step 2: state registry semantics, visibility per recipient, reset, persistence.
local function has( entries, idx, fieldName )
	local id = State.FieldByName( fieldName ).id
	for _, e in ipairs( entries ) do
		if e[ 1 ] == idx then
			for _, fid in ipairs( e[ 2 ] ) do
				if fid == id then return true end
			end
		end
	end
	return false
end

return function( T )
	-- Test-only fields; declared on the server only, which is fine with no real clients.
	State.Field( "T2Owner", "UInt", 8, State.OWNER, 7 )
	State.Field( "T2Public", "Int", 8, State.PUBLIC, -1 )
	State.Field( "T2Secret", "String", 0, State.SERVER, "s" )
	State.Field( "T2Flag", "Bool", 1, State.PUBLIC, false )

	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t2_%'" )
	local a = player.CreateNextBot( "t2_a" )
	local b = player.CreateNextBot( "t2_b" )
	T.Wait( 0.3 ) -- let the join tick flush

	T.Equal( a:GetT2Owner(), 7, "getter returns default" )
	T.Equal( a:GetT2Public(), -1, "signed default" )
	T.Equal( a:GetBones(), 0, "persisted field loads from a new row" )

	b:SetT2Owner( 9 )
	b:SetT2Public( 5 )
	b:SetT2Secret( "hidden" )
	b:SetBones( 300 )
	local forA = State.Collect( a )
	local forB = State.Collect( b )
	T.Check( not has( forA, b:EntIndex(), "T2Owner" ), "A does not get B's OWNER field" )
	T.Check( has( forB, b:EntIndex(), "T2Owner" ), "B gets its own OWNER field" )
	T.Check( has( forA, b:EntIndex(), "T2Public" ), "A gets B's PUBLIC field" )
	T.Check( not has( forA, b:EntIndex(), "Bones" ), "A does not get B's bones" )
	T.Check( not has( forA, b:EntIndex(), "T2Secret" ) and not has( forB, b:EntIndex(), "T2Secret" ), "SERVER field goes to nobody" )
	T.Equal( DB.Get( b, "bones" ), 300, "persist setter updates the DB row" )

	local snapA = State.Collect( a, true )
	T.Check( has( snapA, b:EntIndex(), "Rank" ) and not has( snapA, b:EntIndex(), "StemCells" ), "snapshot respects scopes" )

	State.NetTick()
	T.Equal( #State.Collect( b ), 0, "tick clears dirty fields" )
	b:SetT2Public( 5 )
	T.Equal( #State.Collect( b ), 0, "setting the same value marks nothing" )

	b:SetT2Flag( 1 )
	T.Equal( b:GetT2Flag(), true, "bool coerces" )
	b:SetT2Owner( 999 )
	T.Equal( b:GetT2Owner(), 255, "uint clamps to its bits" )
	b:SetT2Public( -500 )
	T.Equal( b:GetT2Public(), -128, "int clamps to its bits" )

	State.Reset( b )
	T.Equal( b:GetT2Owner(), 7, "reset restores defaults" )
	T.Equal( b:GetT2Secret(), "s", "reset covers SERVER fields" )
	T.Equal( b:GetBones(), 300, "reset keeps persistent fields" )

	b:Kick( "test" )
	T.WaitUntil( function() return not IsValid( b ) end, 5, "b left" )
	T.Wait( 0.3 )
	b = player.CreateNextBot( "t2_b" )
	T.Equal( b:GetBones(), 300, "bones survive reconnect through the registry" )
	T.Equal( b:GetT2Owner(), 7, "non-persistent field is fresh after reconnect" )
end
