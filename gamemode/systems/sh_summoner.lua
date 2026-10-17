-- The Sanitar Summon (entities/summoner.lua), ported 1:1 from the original entities/summoner.lua.
-- Anyone uses it to call the Sanitar Squad to its Area; police turn it off by use, others by attacking
-- it (evidence: obstruction of sanitation). Use and damage go through Summoner.Use / Summoner.Damage,
-- which validate the caller server side. Cross-texts and the police through-wall alert are client side.
Summoner = Summoner or {}
Summoner.All = Summoner.All or {}   -- registry of live summoners (both realms)
Summoner.COOLDOWN = 180
Summoner.CALL_TIME = 60
Summoner.FIRST_TIME = 90
Summoner.RANGE = 200

local RED, GREEN = Color( 255, 60, 60 ), Color( 60, 255, 60 )

local function isPolice( ply ) return ply:FateHas( "Police" ) or ply:FateHas( "CanSentence" ) end
Summoner.IsPolice = isPolice

if SERVER then
	local function tellPolice( color, text )
		for _, p in ipairs( player.GetAll() ) do
			if isPolice( p ) then Chat.Tell( p, color, text ) end
		end
	end

	function Summoner.TurnOff( ent )
		ent:SetOn( false )
		ent:SetBlink( false )
	end

	function Summoner.TurnOn( ent )
		ent:SetOn( true )
		ent.NextSound = 0
	end

	function Summoner.Think( ent )
		if not ent:GetOn() then return end
		local now = CurTime()
		if now >= ( ent.NextSound or 0 ) then
			ent.NextSound = now + 6
			ent:EmitSound( "placenta/summoning.wav", 85, math.random( 80, 100 ) )
			ent:SetBlink( true )
		end
		if now >= ( ent.AutoStop or 0 ) then
			ent:EmitSound( "kidneydagger/scramble1.wav", 85, math.random( 80, 120 ) )
			Summoner.TurnOff( ent )
		end
	end

	function Summoner.Use( ent, ply )
		if not ( IsValid( ent ) and ent:GetClass() == "summoner" ) then return end
		if not ( IsValid( ply ) and ply:IsPlayer() and ply:Alive() ) then return end
		if ply:GetPos():DistToSqr( ent:GetPos() ) > Summoner.RANGE ^ 2 then return end
		local area, now = ent:GetArea(), CurTime()
		ent.AutoStop = now + Summoner.CALL_TIME
		if not ent:GetOn() and ent:GetNextToggle() > now then
			Chat.Tell( ply, RED, "Shh. It's sleeping.", 1 )
			return
		end
		if isPolice( ply ) then
			if ent:GetOn() then
				Summoner.TurnOff( ent )
				tellPolice( GREEN, "The " .. area .. " situation was resolved. Gangrene Eternal!" )
				ent:SetNextToggle( now + Summoner.COOLDOWN )
				ent:EmitSound( "buttons/combine_button5.wav" )
			else
				Summoner.TurnOn( ent )
				tellPolice( RED, ply:Nick() .. " requests backup! Sanitar Squad must appear to " .. area .. " immediately!" )
			end
		elseif ent:GetOn() then
			Chat.Tell( ply, RED, "You'll have to hit it if you want to turn it off... but that's a crime!", 1 )
		else
			Summoner.TurnOn( ent )
			Chat.Tell( ply, GREEN, "Sanitar Squad is alerted to your location. Attack the Sanitar Summon to turn it off if the problem is solved or if you realize nobody is coming." )
			tellPolice( RED, "ACHTUNG -- " .. ply:Nick() .. " triggered a Sanitar Summon! Sanitar Squad must appear to " .. area .. " immediately!" )
		end
	end

	function Summoner.Damage( ent, dmg )
		if not ( IsValid( ent ) and ent:GetClass() == "summoner" and ent:GetOn() ) then return end
		if dmg:IsDamageType( DMG_CRUSH ) then return end
		ent:EmitSound( "physics/metal/metal_sheet_impact_bullet" .. math.random( 1, 2 ) .. ".wav", 75, math.random( 80, 110 ) )
		Summoner.TurnOff( ent )
		local att = dmg:GetAttacker()
		if not ( IsValid( att ) and att:IsPlayer() ) then return end
		if isPolice( att ) then
			ent:SetNextToggle( CurTime() + Summoner.COOLDOWN )
		else
			Crime.AddEvidence( att, "obstruction of sanitation", 1, 60 )
		end
	end
	return
end

-- Client: the cross-texts and the police through-wall "CALLING SS" alert.
function Summoner.CrossLine( ent, ply )
	if not ent:GetOn() and ent:GetNextToggle() > CurTime() then return "Don't bother it right now." end
	if isPolice( ply ) then
		return ent:GetOn() and "Resolve the situation that warranted its use.\nUse it to turn it off when appropriate.\nIf this was a prank, ask the Witch Kaiser for a death warrant."
			or "Everything seems to be in order?\nUse to call for backup."
	end
	return ent:GetOn() and "Sanitar Squad is on the way.\nIf you don't want that, attack it... then hide."
		or "Is something the matter?\nUse to cry for help."
end

local function layers()
	HUD.CrossTexts = HUD.CrossTexts or {}
	HUD.CrossTexts.summoner = function( ent, ply, ct )
		ct[ #ct + 1 ] = "Sanitar Summon"
		ct[ #ct + 1 ] = { Summoner.CrossLine( ent, ply ), color_white, HUD.Font( "LabelSmall" ) }
	end
	HUD.Layer( 40, "summoner_alert", function( me )
		if not isPolice( me ) then return end
		local t = CurTime()
		for ent in pairs( Summoner.All ) do
			if not IsValid( ent ) then Summoner.All[ ent ] = nil else
			local tr = util.TraceLine( { start = me:EyePos(), endpos = ent:WorldSpaceCenter(), filter = { me, ent }, mask = MASK_OPAQUE } )
			local want = ( ent:GetOn() and tr.Hit ) and 255 or 0
			ent.AlertAlpha = math.Approach( ent.AlertAlpha or 0, want, FrameTime() * 255 )
			if ent.AlertAlpha > 0 then
				local p = ( ent:GetPos() + Vector( 0, 0, ent:OBBMaxs().z / 1.5 ) ):ToScreen()
				local s = math.abs( 200 * math.sin( 4 * t ) )
				HUD.TextShadow( "CALLING SS - " .. string.upper( ent:GetArea() ), HUD.Font( "PlayerFont" ), p.x, p.y,
					Color( 200, s, s, ent.AlertAlpha ), Color( 0, 0, 0, ent.AlertAlpha ), TEXT_ALIGN_CENTER )
			end
			end
		end
	end )
end
if HUD and HUD.Layer then layers() else hook.Add( "PostGamemodeLoaded", "GR_SummonerHUD", layers ) end
