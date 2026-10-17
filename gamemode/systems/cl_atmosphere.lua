-- Presentation only: a drained, grey picture and close fog. No gameplay state lives here.
local grade = {
	[ "$pp_colour_addr" ] = 0,
	[ "$pp_colour_addg" ] = 0.01,
	[ "$pp_colour_addb" ] = 0,
	[ "$pp_colour_brightness" ] = -0.04,
	[ "$pp_colour_contrast" ] = 1.1,
	[ "$pp_colour_colour" ] = 0.45,
	[ "$pp_colour_mulr" ] = 0,
	[ "$pp_colour_mulg" ] = 0,
	[ "$pp_colour_mulb" ] = 0,
}

hook.Add( "RenderScreenspaceEffects", "gr_atmosphere", function()
	DrawColorModify( grade )
end )

local FOG_START, FOG_END, FOG_DENSITY = 200, 2500, 0.85
local FOG_COLOR = { 70, 72, 66 }

local function fog( scale )
	scale = scale or 1
	render.FogMode( MATERIAL_FOG_LINEAR )
	render.FogStart( FOG_START * scale )
	render.FogEnd( FOG_END * scale )
	render.FogMaxDensity( FOG_DENSITY )
	render.FogColor( FOG_COLOR[ 1 ], FOG_COLOR[ 2 ], FOG_COLOR[ 3 ] )
	return true
end

hook.Add( "SetupWorldFog", "gr_atmosphere", function() return fog() end )
hook.Add( "SetupSkyboxFog", "gr_atmosphere", function( scale ) return fog( scale ) end )
