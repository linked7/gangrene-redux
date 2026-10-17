-- Placeholder: step 11 adds the baton, scope, codename and Teeth.
Fates.Define( "sanitar", {
	Name = "Sanitar",
	Description = "The keeper of all things moral, safe, and clean... hopefully.",
	Color = Color( 0, 200, 0 ),
	Cost = 2,
	DeathCooldown = 120,
	Slots = function( pop ) return math.Clamp( 2 + math.floor( pop / 10 ), 2, 6 ) end,
	Police = true,
	Radio = { "state" },
} )
