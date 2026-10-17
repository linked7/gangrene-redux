-- Ghost: the dead. The look and feel are the original's fates/list/ghost.lua (docs/05 §13): the
-- skeleton with the glowing eye material and the hologram render effect, muffled hearing (DSP 4,
-- cl_effects.lua's HUD.BaseDSP), the breathing high-contrast colour grade in place of the usual
-- one, motion blur, and the "Suffering Eternal" radio with no radio sound. Suffering itself is
-- deferred, so the grade reads it as 0 (grey, red tint) until it exists.
local EYE = "effects/tp_eyefx/tpeye"
local FX_HOLOGRAM = 16

Fates.Define( "ghost", {
	Name = "Ghost",
	Description = "A dead, useless thing.",
	Color = Color( 150, 150, 150 ),
	ChatSounds = { "placenta/ghost1.ogg", "placenta/ghost2.ogg", "placenta/ghost3.ogg", "placenta/ghost4.ogg" },
	Radio = { "ghost" },
	CustomRadio = "Suffering Eternal",
	NoRadioSound = true,
	Appearance = { model = "models/player/skeleton.mdl" },
	DSP = 4,
	ColorModOverride = true,
	ColorMod = function( ply )
		local t = CurTime()
		local suffering = ( ply.GetSuffering and ply:GetSuffering() or 0 ) / 100
		return {
			[ "$pp_colour_addr" ] = 0,
			[ "$pp_colour_addg" ] = 0,
			[ "$pp_colour_addb" ] = 0,
			[ "$pp_colour_brightness" ] = -0.01 * math.cos( t ),
			[ "$pp_colour_contrast" ] = 2 + math.sin( t * 1.25 ),
			[ "$pp_colour_colour" ] = 5 * suffering,
			[ "$pp_colour_mulr" ] = 5 * ( 1 - suffering ),
			[ "$pp_colour_mulg" ] = 0,
			[ "$pp_colour_mulb" ] = 0,
		}
	end,
	MotionBlur = { 0.08, 0.8, 0.05 },
	OnEnter = function( ply )
		ply:SetSubMaterial()
		ply:SetSubMaterial( 0, EYE )
		ply:SetRenderFX( FX_HOLOGRAM )
	end,
	OnLeave = function( ply )
		ply:SetSubMaterial()
		ply:SetRenderFX( kRenderFxNone )
	end,
} )
