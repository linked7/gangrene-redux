-- Placeholder: step 11 adds reviving for a fee, faster regeneration and surgery.
Fates.Define( "korpsman", {
	Name = "Korpsman",
	Description = "The healer of all maladies physical and pathological. Only Gangrene's finest should be treated for free.",
	Color = Color( 200, 200, 200 ),
	Cost = 1,
	DeathCooldown = 60,
	Slots = function( pop ) return math.Clamp( 2 + math.floor( pop / 10 ), 2, 5 ) end,
	Citizen = true,
	Radio = { "medic" },
} )
