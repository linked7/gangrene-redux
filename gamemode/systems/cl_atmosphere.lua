-- Presentation only: close fog. No gameplay state lives here. The colour grade is the
-- original's map colour filter, in cl_effects.lua (it replaced the grey grade that was here).
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
