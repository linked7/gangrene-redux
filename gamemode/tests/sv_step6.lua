-- Step 6: needs rise on their own, one mutator lowers them, despair at 100 is a heart attack.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:t6_%'" )

	local b = player.CreateNextBot( "t6_a" )
	T.Wait( 0.2 )
	T.Equal( Needs.Get( b, "Emptiness" ), 0, "ghosts have no needs" )
	Needs.Add( b, "Emptiness", 50, "test" )
	T.Equal( Needs.Get( b, "Emptiness" ), 0, "Needs.Add does nothing to a ghost" )

	b:SetRank( RANK_FRIEND ) b:SetStemCells( 5 )
	Fates.Take( b, "prole" )
	T.Equal( Needs.Get( b, "Emptiness" ), 0, "a new life starts empty" )
	T.Wait( 3.5 )
	T.Check( Needs.Get( b, "Emptiness" ) > 0, "emptiness rises on its own: " .. Needs.Get( b, "Emptiness" ) )
	T.Check( Needs.Get( b, "Dryness" ) > Needs.Get( b, "Emptiness" ), "dryness rises faster" )
	T.Equal( Needs.Get( b, "Despair" ), 0, "despair never rises on its own" )

	Needs.Add( b, "Emptiness", 70.6, "test" )
	T.Equal( b:GetNeed_Emptiness(), math.floor( Needs.Get( b, "Emptiness" ) ), "the networked field is the whole number" )
	Needs.Add( b, "Emptiness", -40, "food" ) -- eating, until items arrive in Step 8
	T.Check( Needs.Get( b, "Emptiness" ) < 40, "eating lowers emptiness" )
	Needs.Add( b, "Emptiness", -500, "food" )
	T.Equal( Needs.Get( b, "Emptiness" ), 0, "needs clamp at 0" )

	-- Pox lowers max HP, down to half at 100.
	Needs.Add( b, "Pox", 100, "dirty water" )
	T.Equal( b:GetMaxHealth(), 50, "full pox halves max HP" )
	T.Check( b:Health() <= 50, "health is clamped to the new max" )
	Needs.Add( b, "Pox", -100, "cure" )
	T.Equal( b:GetMaxHealth(), 100, "curing pox restores max HP" )

	-- Modifiers see every change and can scale it.
	local function halve( _, name, amount ) if name == "Despair" and amount > 0 then return amount / 2 end end
	table.insert( Needs.Modifiers, halve )
	Needs.Add( b, "Despair", 20, "test" )
	table.RemoveByValue( Needs.Modifiers, halve )
	T.Equal( Needs.Get( b, "Despair" ), 10, "modifiers apply" )

	local cells = b:GetStemCells()
	Needs.Add( b, "Despair", 200, "test" )
	T.Equal( b:GetStemCells(), cells - 1, "a heart attack costs a stem cell" )
	T.Equal( Needs.Get( b, "Despair" ), 60, "despair drops to 60 after the attack" )
	T.Check( b:Alive(), "the death is not instant" )
	T.WaitUntil( function() return not b:Alive() end, 5, "the heart attack kills" )
	T.WaitUntil( function() return b:Alive() end, 6, "respawned" )
	T.Check( b:IsGhost(), "back as a ghost" )
	T.Equal( Needs.Get( b, "Despair" ), 0, "ghosts carry no despair" )
	T.Equal( b:GetNeed_Despair(), 0, "the networked field is reset too" )
end
