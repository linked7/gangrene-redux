-- The crosshair, the cross-texts and weapon select, ported from the original's GM:HUDPaint tail
-- (gui/cl_hud.lua ~3095-3285), its DrawEntities / DrawDoors cross-texts and
-- framework/cl_weaponselect.lua (docs/05 §2). HUD layer 130.
--
--   Three squares orbit the aim point. Hovering something worth reading within 384 units speeds
--   them up and fades in the cross-texts under it: lines of text (and bars) through HUD.Stutter.
--   Weapon select has no panel of its own: scrolling or a slot key lists the weapons in the
--   cross-texts, and the pick is equipped when they fade out (or on a click).
--
--   HUD.CrossTexts[ class ] = function( ent, ply, ct )   adds lines for an entity class; an
--                             entity can define ENT:CrossTexts( ply, ct ) instead. A line is a
--                             string or { text, color, font, bar = 0..1 }.
--   GR_CrossTexts( ent, ply, ct )  hook: systems add lines to any entity's cross-texts (locks do)
--   HUD.Corpse( ent )         the gr_corpse record of a body, or nil
--   HUD.OwnCorpse()           the local player's body, or nil
--
-- cc_nocrosshair 1 hides the squares (the cross-texts stay), as the original's cookie did.
local noCrosshair = CreateClientConVar( "cc_nocrosshair", "0", true, false, "Hide the orbiting crosshair." )

local CT = CurTime
local RANGE2 = 384 * 384
local F_MEDIUM, F_SMALL, F_PLAYER = HUD.Font( "LabelMedium" ), HUD.Font( "LabelSmall" ), HUD.Font( "PlayerFont" )

-- Bodies ----------------------------------------------------------------------------------------
-- The server tells every client who each body is (sh_corpse.lua Corpse.Sync); keyed by entindex
-- so a body that arrives before its entity still resolves once the entity exists.

local bodies = {}

Net.Receive( "gr_corpse", nil, function()
	local idx = net.ReadUInt( 16 )
	bodies[ idx ] = {
		owner = net.ReadUInt( 8 ),
		name = net.ReadString(),
		look = net.ReadString(),
		untilTime = net.ReadFloat(),
	}
end )

hook.Add( "EntityRemoved", "gr_crosshair", function( ent, fullUpdate )
	if fullUpdate then return end
	local idx = ent:EntIndex()
	if idx > 0 and bodies[ idx ] and ent:GetClass() == "prop_ragdoll" then bodies[ idx ] = nil end
end )

function HUD.Corpse( ent )
	if not IsValid( ent ) or ent:GetClass() ~= "prop_ragdoll" then return nil end
	return bodies[ ent:EntIndex() ]
end

function HUD.OwnCorpse()
	local me = LocalPlayer():EntIndex()
	for idx, b in pairs( bodies ) do
		if b.owner == me and b.look ~= "dead" then
			local ent = Entity( idx )
			if IsValid( ent ) then return ent end
		end
	end
end

-- Cross-text builders ---------------------------------------------------------------------------

local function pulse() return Color( math.max( 0, 200 * math.sin( CT() * 3 ) ), 0, math.max( 0, 200 * -math.sin( CT() * 3 ) ) ) end
local function rcol() return HSVToColor( ( CT() * 23 ) % 360, 0.5, 1 ) end
local SENTENCE = { "TORMENT", "IMPRISONMENT", "DEATH" }
local FACTION_NAMES = { state = "Gangrene" }

local function playerTexts( v, ply, ct )
	if v:IsGhost() and not ply:IsGhost() then return false end
	local name, rc = v:Nick(), rcol()
	if not ply:KeyDown( IN_ATTACK2 ) then
		if v:IsWanted() then
			local reason = v:GetWantedReason()
			table.insert( ct, { text = name .. ", SENTENCED TO " .. ( SENTENCE[ v:GetWanted() ] or "DEATH" ) ..
				( reason ~= "" and ( " for " .. reason ) or "" ), color = pulse() } )
			table.insert( ct, { text = ply:FateHas( "Police" ) and "Teach him the meaning of pain. You will be rewarded."
				or "You can hurt this one and suffer no consequences.", color = rc } )
		else
			table.insert( ct, { text = name, color = HSVToColor( ( CT() * 66 ) % 360, 0.5, 1 ) } )
		end

		-- Factions: brothers, superiors and the leader (step 10's Faction / Authority).
		local fac, mine = v:FateHas( "Faction" ), ply:FateHas( "Faction" )
		local auth, myAuth = v:FateHas( "Authority" ) or 0, ply:FateHas( "Authority" ) or 0
		local leader = v:FateHas( "Sovereign" )
		if fac and fac == mine and not leader and v ~= ply then
			local t = auth == myAuth and "We are brothers in duty." or auth < myAuth and "I am their superior." or "They are my superior."
			table.insert( ct, { text = t, color = rc } )
		elseif fac and leader then
			table.insert( ct, { text = "The leader of this great state.", color = rc } )
		elseif fac then
			table.insert( ct, { text = "They are loyal to " .. ( FACTION_NAMES[ fac ] or fac ) .. ".", color = rc } )
		end

		if not v:IsGhost() then
			local race, myRace = v:GetRaceDef(), ply:GetRaceDef()
			if race and race.Name then
				table.insert( ct, { text = "Looks " .. race.Name .. ". " .. ( race == myRace and "Brother in blood." or "Not like me." ), color = rc } )
			end
			if not v:FateHas( "Citizen" ) and not fac then
				table.insert( ct, { text = "Not a citizen.", color = rc } )
			end
		end
	end
	if not v:IsGhost() and v:GetInjured() then
		table.insert( ct, { text = "Looks like they're about to keel over.", color = rc } )
	end
	return true
end

local LOOK = { unconscious = "Wriggling Body", wounded = "Wriggling Body", dying = "Wriggling Body", dead = "Fresh Cadaver" }
local function corpseTexts( b, ply, ct )
	local now, bar = CT(), nil
	local span = b.look == "wounded" and Config.WakeTime or b.look == "dying" and Config.BleedoutTime
		or b.look == "dead" and Corpse.DECAY or nil
	if span and b.untilTime > 0 then bar = math.Clamp( 1 - ( b.untilTime - now ) / span, 0, 1 ) end
	table.insert( ct, { text = LOOK[ b.look ] or "Fresh Cadaver", bar = bar or 0, color = Color( 0, 128, 0 ) } )

	local owner = Entity( b.owner )
	if b.look ~= "dead" and IsValid( owner ) and owner:IsPlayer() and owner:IsWanted() then
		table.insert( ct, { color = pulse(), text = ply:FateHas( "Police" ) and "Their sentence is DEATH. Do what you must."
			or "The state wants their head. Better leave them alone." } )
	end
	local medic = ply:FateHas( "CanRevive" )
	if b.look == "wounded" then
		table.insert( ct, { color = Color( 0, 128 + 50 * math.sin( now * 4 ), 0 ),
			text = medic and "They're still alive! Press E to help them up." or "They're still alive!" } )
	elseif b.look == "dying" then
		table.insert( ct, { color = Color( 128 + 50 * math.sin( now * 4 ), 0, 0 ),
			text = medic and "They're dying!\nPress E to save them!" or "They're dying!" } )
	end
	return true
end

-- Entities: a line under the name saying what to do with it, in the original's LabelSmall.
local function small( ct, text, col ) table.insert( ct, { text = text, font = F_SMALL, color = col } ) end

local optionsAt, optionsEnt, optionsHas = 0, nil, false
local function hasOptions( ply, ent )
	if ent ~= optionsEnt or CT() > optionsAt then
		optionsEnt, optionsAt = ent, CT() + 0.25
		optionsHas = Interact ~= nil and #Interact.For( ply, ent ) > 0
	end
	return optionsHas
end

HUD.CrossTexts = HUD.CrossTexts or {}
local P = HUD.CrossTexts

P.gr_item = function( ent, ply, ct )
	local def = Items.Get( ent:GetItemId() )
	if not def then return false end
	local n = ent:GetCount()
	table.insert( ct, { text = def.Name .. ( n > 1 and ( " x" .. n ) or "" ), font = F_PLAYER } )
	if def.Description then small( ct, def.Description ) end
	small( ct, "Weight - " .. tostring( def.Weight or 0 ) )
end
P.ent_crate = function( ent, ply, ct )
	local def = Items.Get( ent:GetKind() )
	table.insert( ct, { text = def and ( "Crate of " .. def.Name ) or "Crate" } )
	small( ct, "A shipment of goods from the press." )
	small( ct, "Deliver it to the stockpile for a reward." )
end
P.storage_crate = function( ent, ply, ct )
	table.insert( ct, { text = "Storage Crate" } )
	small( ct, "You can store your junk in it." )
	if ent:GetLocked() then small( ct, "It is locked.", Color( 200, 0, 0 ) ) end
end
P.ration_press = function( ent, ply, ct )
	local def = Items.Get( ent:GetGood() )
	table.insert( ct, { text = "Ration Press" } )
	small( ct, "Use it to work. It makes " .. ( def and def.Name or "rations" ) .. "." )
end
P.state_stockpile = function( ent, ply, ct )
	table.insert( ct, { text = "State Stockpile" } )
	small( ct, "The city's food is kept here. Deliver crates to it." )
end
P.water_pump = function( ent, ply, ct )
	table.insert( ct, { text = "Water Pump" } )
	small( ct, "Use to collect water. It isn't for drinking." )
end
P.sanitation_station = function( ent, ply, ct )
	table.insert( ct, { text = "Sanitation Station" } )
	if ply:FateHas( "Police" ) then small( ct, "Spend your Teeth on the tools of the trade." ) end
end
P.fate_station = function( ent, ply, ct )
	if not ply:IsGhost() then return false end
	local f = Fates.Get( ent:GetFateId() )
	table.insert( ct, { text = f and f.Name or "Purpose in Life" } )
	small( ct, "Use it to take this purpose in life." )
end

local DOORS = { func_door = true, func_door_rotating = true, prop_door_rotating = true }

-- Fills `ct` for what the player is looking at; false when there is nothing to read.
local function build( ply, ent, ct )
	if ent:IsPlayer() then return playerTexts( ent, ply, ct ) end
	local b = HUD.Corpse( ent )
	if b then return corpseTexts( b, ply, ct ) end
	local class = ent:GetClass()
	local fn = ent.CrossTexts or P[ class ]
	local near = ply:GetPos():DistToSqr( ent:GetPos() ) < 128 * 128
	if fn then
		if fn( ent, ply, ct ) == false then return false end
		hook.Run( "GR_CrossTexts", ent, ply, ct )
		if near and hasOptions( ply, ent ) then small( ct, "Open the context menu for options." ) end
		return true
	end
	if DOORS[ class ] then
		if near and hasOptions( ply, ent ) then small( ct, "Open the context menu for options." ) end
		return true
	end
	return false
end

-- Weapon select ---------------------------------------------------------------------------------

local OPEN_TIME = 1.5
local ws = { ref = -OPEN_TIME, pos = 1, selected = false }
local ENGINE_NAMES = { weapon_physgun = "Telegland", weapon_physcannon = "Gravity Gun", gmod_tool = "Hexengland" }
local OVERRIDE = { weapon_physgun = { 3, 3 }, weapon_physcannon = { 3, 4 }, gmod_tool = { 3, 5 } }

local function wsOpen() return CT() - ws.ref < OPEN_TIME end
local function slotOf( w )
	local o = OVERRIDE[ w:GetClass() ]
	if o then return o[ 1 ], o[ 2 ] end
	return math.Clamp( w.Slot or 3, 1, 3 ), w.SlotPos or 1
end
local function printName( w )
	if w.PrintName then return w.PrintName end
	return ENGINE_NAMES[ w:GetClass() ] or w:GetClass()
end

-- The weapons in order, slot 1 to 3: { weapon, slot } each.
local function ordered( ply )
	local t = {}
	for _, w in ipairs( ply:GetWeapons() ) do
		if IsValid( w ) then
			local s, sp = slotOf( w )
			table.insert( t, { w = w, slot = s, pos = sp, class = w:GetClass() } )
		end
	end
	table.sort( t, function( a, b )
		if a.slot ~= b.slot then return a.slot < b.slot end
		if a.pos ~= b.pos then return a.pos < b.pos end
		return a.class < b.class
	end )
	return t
end

local function selSound() HUD.Play( "weapon_select", math.random( 80, 90 ) ) end

local function scroll( ply, dir )
	local w = ordered( ply )
	if #w == 0 then return end
	if wsOpen() then
		local op = ws.pos
		ws.pos = ws.pos + dir
		if ws.pos > #w then ws.pos = 1 elseif ws.pos < 1 then ws.pos = #w end
		if op ~= ws.pos then selSound() end
	else
		-- Opening: start on the weapon in hand (the original's WeaponSelectGetFirstPos).
		ws.pos = 1
		for i, e in ipairs( w ) do
			if e.w == ply:GetActiveWeapon() then ws.pos = i end
		end
	end
	ws.ref = CT()
end

local function number( ply, n )
	local w = ordered( ply )
	local sp, ep
	for i, e in ipairs( w ) do
		if e.slot == n then
			sp = sp or i
			ep = i
		end
	end
	if not sp then return end
	selSound()
	if ws.pos < sp or ws.pos > ep then
		ws.pos = sp
	else
		ws.pos = ws.pos + 1
		if ws.pos > ep then ws.pos = sp end
	end
	ws.ref = CT()
end

local function choose( ply )
	local e = ordered( ply )[ ws.pos ]
	if e and IsValid( e.w ) and e.w ~= ply:GetActiveWeapon() then input.SelectWeapon( e.w ) end
end

local function click( ply )
	HUD.Play( "weapon_choose", math.random( 80, 90 ) )
	ws.ref, ws.selected = 0, true
	choose( ply )
end

hook.Add( "PlayerBindPress", "gr_weaponselect", function( ply, bind, pressed )
	if not pressed or not ply:Alive() or ply:InVehicle() then return end
	local busy = ply:KeyDown( IN_ATTACK ) or ply:KeyDown( IN_ATTACK2 )
	if string.find( bind, "invnext", 1, true ) and not busy then scroll( ply, 1 ) return true end
	if string.find( bind, "invprev", 1, true ) and not busy then scroll( ply, -1 ) return true end
	if string.find( bind, "attack", 1, true ) and wsOpen() and not busy then click( ply ) return true end
	local n = string.match( bind, "^slot(%d+)" )
	if n then
		n = tonumber( n )
		if n >= 1 and n <= 3 then
			if not wsOpen() then ws.pos = 0 end
			number( ply, n )
		end
		return true
	end
end )

-- The layer -------------------------------------------------------------------------------------

local crossTexts, alpha, radius, prog = {}, 0, 10, 0
local hoverNoise, unhoverNoise = false, true
local WS_COLS = { Color( 84, 0, 0 ), Color( 168, 0, 0 ) }

local function weaponTexts( ply )
	local ct = {}
	for i, e in ipairs( ordered( ply ) ) do
		local c = WS_COLS[ e.slot ] or HSVToColor( ( CT() * 13 ) % 360, 1, 1 )
		local name = printName( e.w )
		if ws.pos == i then
			c = Color( 200 + 55 * math.sin( CT() * 1.5 ), 0, 200 + 55 * math.cos( CT() * 1.5 ) )
			if name ~= "#GMOD_ToolGun" then name = "-" .. name .. "-" end
		end
		table.insert( ct, { text = name, color = c } )
	end
	return ct
end

local function line( v, x, y, rgb, a )
	local shadow = Color( 0, 0, 0, a )
	if type( v ) == "string" then v = { text = v } end
	if v.bar then
		local col = v.color or HSVToColor( ( CT() * 6.66 ) % 360, 1, 1 )
		col.a = a
		draw.RoundedBox( 0, x - 120, y + 2, 240, 28, Color( 30, 30, 30, a ) )
		draw.RoundedBox( 0, x - 118, y + 4, v.bar * prog * 236, 24, col )
		HUD.TextShadow( HUD.Stutter( v.text ), F_MEDIUM, x, y + 4, Color( 200, 200, 200, a ), shadow, 1 )
		return y + 32 * prog
	end
	local font = v.font or F_MEDIUM
	local col = v.color or rgb
	col.a = a
	surface.SetFont( font )
	for _, part in ipairs( string.Explode( "\n", v.text or "" ) ) do
		local _, tH = surface.GetTextSize( part )
		HUD.TextShadow( HUD.Stutter( part ), font, x, y, col, shadow, 1, 2, true )
		y = y + tH * prog
	end
	return y
end

HUD.Layer( 130, "crosshair", function( ply )
	if not ply:Alive() or HUD.MenuOpen() or ply.NoHealthBar then return end
	local tr = ply:GetEyeTraceNoCursor()
	if not tr.HitPos then return end
	local now, ft = CT(), FrameTime()
	local p = tr.HitPos:ToScreen()
	local x, y = p.x + math.cos( now * 0.75 ), p.y + math.sin( now * 0.95 )
	local wep = ply:GetActiveWeapon()
	local hasWep = IsValid( wep )

	if hasWep and ply:KeyDown( IN_ATTACK2 ) and not wep.Melee then
		radius = Lerp( 0.05, radius, 5 )
	elseif hasWep and wep.Melee and ply:KeyDown( IN_ATTACK ) and now >= wep:GetNextPrimaryFire()
		and wep.GetHeavyAttack and wep:GetHeavyAttack() then
		radius = Lerp( 0.1, radius, 15 )
	else
		radius = Lerp( 0.05, radius, 10 )
	end

	local speed, col, growth = 0.3, HSVToColor( ( now * 23 ) % 360, 0.5, 1 ), math.sin( now )
	local ent = tr.Entity
	local hovered = false
	if ( not hasWep or not ply:KeyDown( IN_ATTACK2 ) ) and IsValid( ent ) and ent:GetPos():DistToSqr( ply:GetPos() ) < RANGE2 then
		local ct = {}
		if build( ply, ent, ct ) then
			hovered = true
			crossTexts = ct
		end
	end

	if hovered then
		speed, col, growth = 1, HSVToColor( ( now * 23 ) % 360, 1, 1 ), math.max( 3, growth * 1.5 )
		alpha = math.Clamp( alpha + ft, 0, 0.7 )
		prog = Lerp( 0.05, prog, 1 )
		ws.selected = false
	elseif wsOpen() then
		prog = Lerp( 0.05, prog, 1 )
		alpha = math.Clamp( alpha + ft, 0, 0.7 )
		crossTexts = weaponTexts( ply )
	else
		alpha = math.Clamp( alpha - ft, 0, 0.7 )
		prog = Lerp( 0.05, prog, 0 )
	end

	if not noCrosshair:GetBool() and not ( hasWep and wep.Zoom_InZoom ) then
		local angle = ( now * speed ) % ( 2 * math.pi )
		local size = 3 + growth
		surface.SetDrawColor( col )
		for i = 1, 3 do
			local a = angle + ( 2 * math.pi / 3 ) * ( i - 1 )
			surface.DrawRect( x + math.cos( a ) * radius, y + math.sin( a ) * radius, size, size )
		end
	end

	if not ply:KeyDown( IN_WALK ) and alpha > 0.02 then
		local rgb = HSVToColor( ( now * 13 ) % 360, 1, 1 )
		y = y + 20 * prog
		x = x + 12 * math.sin( now )
		if hoverNoise then
			hoverNoise, unhoverNoise = false, true
			if ws.ref > 0 then
				HUD.Play( "weapon_hover", math.random( 80, 90 ) )
			elseif #crossTexts > 0 then
				HUD.Play( "cross_hover", math.random( 80, 90 ), 0.3 )
			end
		end
		local a = alpha * 255
		for _, v in ipairs( crossTexts ) do y = line( v, x, y, rgb, a ) end
	elseif alpha < 0.1 then
		if unhoverNoise then
			unhoverNoise, hoverNoise = false, true
			if ws.ref > 0 then
				-- Weapon select faded out without a click: take the highlighted weapon.
				local e = ordered( ply )[ ws.pos ]
				if e and IsValid( e.w ) and e.w ~= wep then
					choose( ply )
					HUD.Play( "weapon_choose", math.random( 80, 90 ), 0.3 )
				end
				ws.ref = -OPEN_TIME
			elseif not ws.selected and #crossTexts > 0 then
				HUD.Play( "cross_unhover", math.random( 80, 90 ), 0.3 )
			end
			ws.selected = false
		end
		crossTexts = {}
		prog = 0
	end
end )
