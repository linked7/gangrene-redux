-- The help panel: F1 or `gr_help`. A short how-to-play; the purposes are listed from fate data.
local C = HUD.COLORS
local frame

local SECTIONS = {
	{ "Life and death", "You arrive dead. As a ghost, press F2 and take a purpose; most cost stem cells. New players can only be Slaves until they survive a day or a citizen commends them. When you die you return as a ghost and must wait before taking the same purpose again. The living can't see or hear ghosts." },
	{ "Needs", "Hunger (Emptiness) and thirst (Dryness) rise all day. They don't kill you outright; they make you slow, weak and easy to knock out. Full thirst brings Pox, which lowers your health. Despair rises from crimes, death and starving, and at its peak your heart gives out. Eat and drink what the stockpile and the bread line hand out." },
	{ "Work", "The city only eats what workers make. Work a ration press to make a crate, carry it (use key, walking only) to the state stockpile and you are paid in bones. Carrying or opening someone else's crate is theft." },
	{ "Wounds", "A beating knocks you out; a bad wound puts you down. If you get up on your own you are Injured, with less health, until a korpsman stitches you. Korpsmen revive the dying (use key on the body) and dig out lodged bullets, which stop you healing." },
	{ "Law", "Sanitars hunt the wanted. Theft, violence and beating open the stockpile's lock make you wanted; hide until it runs out, or be beaten, arrested or killed. The Kaiser sets prices, pays and fines, and sentences." },
	{ "Hold C", "Look at a person, a body or a machine and hold C to see what you can do: operate, inspect, arrest, commend, build, work." },
	{ "Keys and chat", "F1 help    F2 purposes    TAB who is here\n/inv belongings    /kaiser the Kaiser's desk\n/r radio    /me action    /y yell    /w whisper    // or /ooc out of character" },
}

local function heading( parent, text, col )
	local l = vgui.Create( "DLabel", parent )
	l:Dock( TOP )
	l:DockMargin( 0, HUD.S( 10 ), 0, HUD.S( 2 ) )
	l:SetFont( "gr_hud" )
	l:SetTextColor( col or C.warn )
	l:SetText( text )
	l:SizeToContentsY()
end

local function body( parent, text )
	local l = vgui.Create( "DLabel", parent )
	l:Dock( TOP )
	l:SetFont( "gr_hud_small" )
	l:SetTextColor( C.text )
	l:SetWrap( true )
	l:SetAutoStretchVertical( true )
	l:SetText( text )
end

local function open()
	frame = vgui.Create( "DFrame" )
	frame:SetTitle( "" )
	frame:SetSize( math.min( HUD.S( 760 ), ScrW() - 40 ), math.min( HUD.S( 820 ), ScrH() - 40 ) )
	frame:Center()
	frame:MakePopup()
	frame:SetKeyboardInputEnabled( false )
	frame:DockPadding( HUD.S( 18 ), HUD.S( 34 ), HUD.S( 18 ), HUD.S( 14 ) )
	frame.Paint = function( self, w, h )
		draw.RoundedBox( 6, 0, 0, w, h, C.back )
		draw.SimpleText( "How to live in Gangrene", "gr_hud", HUD.S( 18 ), HUD.S( 8 ), C.text )
	end

	local scroll = vgui.Create( "DScrollPanel", frame )
	scroll:Dock( FILL )
	local canvas = scroll:GetCanvas()
	canvas:DockPadding( 0, 0, HUD.S( 8 ), 0 )
	for _, s in ipairs( SECTIONS ) do
		heading( canvas, s[ 1 ] )
		body( canvas, s[ 2 ] )
	end
	heading( canvas, "Purposes" )
	for _, f in ipairs( Fates.All() ) do
		if f.index ~= FATE_GHOST then
			heading( canvas, f.Name, f.Color )
			body( canvas, f.Description )
		end
	end
end

local function toggle()
	if IsValid( frame ) then frame:Remove() else open() end
end

concommand.Add( "gr_help", toggle )

hook.Add( "PlayerBindPress", "gr_help", function( _, bind, pressed )
	if pressed and string.find( bind, "gm_showhelp", 1, true ) then
		toggle()
		return true
	end
end )
