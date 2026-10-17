-- The Kaiser's economy panel: `gr_kaiser` in the console, /kaiser in chat, or using the strategy
-- book. Four tabs: Economy (every Econ.Schema setting), Citizens (Grant, Fine, Sentence, Forgive),
-- Upgrades and Ledger. It only reads public state and sends requests; the server checks them all.
-- A CombineControl frame (HUD.Frame); the controls take the skin from cl_skin.lua.
local frame
local ledger = { rows = {}, inflow = {}, outflow = {} }

local function sendTarget( name, target, write )
	net.Start( name )
	net.WriteEntity( target )
	if write then write() end
	net.SendToServer()
end

local function requestLedger()
	net.Start( "nKaiserLedger" )
	net.SendToServer()
end

-- Economy ---------------------------------------------------------------------------------

local function economyTab( parent )
	local panel = vgui.Create( "DScrollPanel", parent )
	for _, def in ipairs( Econ.Schema ) do
		local row = vgui.Create( "DPanel", panel )
		row:Dock( TOP )
		row:DockMargin( 0, 0, 0, 2 )
		row:SetTall( 24 )
		row:SetPaintBackground( false )

		local name = vgui.Create( "DLabel", row )
		name:SetText( def.key )
		name:SetTextColor( HUD.COLORS.text )
		name:Dock( LEFT )
		name:SetWide( 160 )

		local set = vgui.Create( "DButton", row )
		set:SetText( "Set" )
		set:Dock( RIGHT )
		set:SetWide( 50 )

		local value = vgui.Create( "DNumberWang", row )
		value:Dock( FILL )
		value:SetMin( def.min )
		value:SetMax( def.max or Econ.Supply() )
		value:SetDecimals( 0 )
		value:SetValue( Econ.Setting( def.key ) )
		set.DoClick = function()
			net.Start( "nKaiserEcon" )
			net.WriteString( def.key )
			net.WriteDouble( math.floor( value:GetValue() ) )
			net.SendToServer()
		end
	end
	return panel
end

-- Citizens --------------------------------------------------------------------------------

local function citizensTab( parent )
	local panel = vgui.Create( "DPanel", parent )
	panel:SetPaintBackground( false )

	local controls = vgui.Create( "DPanel", panel )
	controls:Dock( BOTTOM )
	controls:SetTall( 56 )
	controls:SetPaintBackground( false )

	local list = vgui.Create( "DListView", panel )
	list:Dock( FILL )
	list:SetMultiSelect( false )
	list:AddColumn( "Name" )
	list:AddColumn( "Fate" )
	list:AddColumn( "Wanted" ):SetFixedWidth( 160 )
	for _, p in player.Iterator() do
		if p ~= LocalPlayer() and p:Alive() and not p:IsGhost() then
			local f = p:GetFateDef()
			local line = list:AddLine( p:Nick(), f and f.Name or "?", p:IsWanted() and p:GetWantedReason() or "" )
			line.Player = p
		end
	end
	local function target()
		local i = list:GetSelectedLine()
		local p = i and list:GetLine( i ).Player
		return IsValid( p ) and p or nil
	end

	local amount = vgui.Create( "DNumberWang", controls )
	amount:SetPos( 0, 2 )
	amount:SetSize( 90, 24 )
	amount:SetMin( 1 )
	amount:SetMax( 2 ^ 24 - 1 )
	amount:SetDecimals( 0 )
	amount:SetValue( 50 )

	local function button( text, x, y, fn )
		local b = vgui.Create( "DButton", controls )
		b:SetText( text )
		b:SetPos( x, y )
		b:SetSize( 90, 24 )
		b.DoClick = function()
			local p = target()
			if p then fn( p ) end
		end
		return b
	end
	local function bones() return math.Clamp( math.floor( amount:GetValue() ), 1, 2 ^ 24 - 1 ) end
	button( "Grant", 95, 2, function( p ) sendTarget( "nKaiserGrant", p, function() net.WriteUInt( bones(), 24 ) end ) end )
	button( "Fine", 190, 2, function( p ) sendTarget( "nKaiserFine", p, function() net.WriteUInt( bones(), 24 ) end ) end )
	button( "Forgive", 285, 2, function( p ) sendTarget( "nKaiserForgive", p ) end )

	local level = vgui.Create( "DComboBox", controls )
	level:SetPos( 0, 30 )
	level:SetSize( 185, 24 )
	for lvl, name in SortedPairs( Kaiser.SENTENCE_NAMES ) do level:AddChoice( "Sentence to " .. name, lvl, lvl == WANTED_TORMENT ) end
	button( "Sentence", 190, 30, function( p )
		local _, lvl = level:GetSelected()
		if lvl then sendTarget( "nKaiserSentence", p, function() net.WriteUInt( lvl, 2 ) end ) end
	end )
	-- Issues a gun permit, or revokes the one they hold (sh_gunpermit.lua).
	button( "Gun permit", 285, 30, function( p )
		sendTarget( "nKaiserPermit", p, function() net.WriteBool( p:GetGunPermit() == "" ) end )
	end )
	return panel
end

-- Upgrades --------------------------------------------------------------------------------

local function upgradesTab( parent )
	local panel = vgui.Create( "DScrollPanel", parent )
	local prices = LocalPlayer():FateHas( "Upgrades" )
	if not istable( prices ) then return panel end
	local fund = vgui.Create( "DLabel", panel )
	fund:Dock( TOP )
	fund:SetTextColor( HUD.COLORS.text )
	fund:SetText( string.format( "Treasury %d, upgrade fund %d", Econ.Treasury(), Econ.UpgradeFund() ) )
	for fateId, price in SortedPairs( prices ) do
		local f = Fates.Get( fateId )
		if f then
			local b = vgui.Create( "DButton", panel )
			b:Dock( TOP )
			b:DockMargin( 0, 4, 0, 0 )
			b:SetTall( 28 )
			local bought = Kaiser.Upgraded( fateId )
			b:SetText( bought and ( f.Name .. ": bought this round" ) or string.format( "Upgrade the %s (%d bones)", f.Name, price ) )
			b:SetEnabled( not bought )
			b.DoClick = function()
				net.Start( "nKaiserUpgrade" )
				net.WriteString( fateId )
				net.SendToServer()
			end
		end
	end
	return panel
end

-- Ledger ----------------------------------------------------------------------------------

local function flowText( flow )
	local parts = {}
	for source, n in SortedPairs( flow ) do table.insert( parts, source .. " " .. n ) end
	return #parts > 0 and table.concat( parts, ", " ) or "nothing"
end

local function fillLedger( panel )
	if not IsValid( panel ) then return end
	panel.Flows:SetText( string.format( "Treasury, last 5 min. In: %s\nOut: %s", flowText( ledger.inflow ), flowText( ledger.outflow ) ) )
	panel.List:Clear()
	for _, e in ipairs( ledger.rows ) do
		panel.List:AddLine( string.format( "%.0f", e.t ), e.from, e.to, e.amount, e.source )
	end
end

local function ledgerTab( parent )
	local panel = vgui.Create( "DPanel", parent )
	panel:SetPaintBackground( false )

	local refresh = vgui.Create( "DButton", panel )
	refresh:Dock( BOTTOM )
	refresh:SetText( "Refresh" )
	refresh.DoClick = requestLedger

	panel.Flows = vgui.Create( "DLabel", panel )
	panel.Flows:Dock( TOP )
	panel.Flows:SetTextColor( HUD.COLORS.text )
	panel.Flows:SetTall( 34 )
	panel.Flows:SetWrap( true )

	local list = vgui.Create( "DListView", panel )
	list:Dock( FILL )
	list:AddColumn( "Time" ):SetFixedWidth( 50 )
	list:AddColumn( "From" )
	list:AddColumn( "To" )
	list:AddColumn( "Bones" ):SetFixedWidth( 50 )
	list:AddColumn( "Why" )
	panel.List = list
	fillLedger( panel )
	return panel
end

-- Window ----------------------------------------------------------------------------------

local function open()
	if IsValid( frame ) then
		frame:Remove()
		return
	end
	if not LocalPlayer():FateHas( "RunsEconomy" ) then return end
	frame = HUD.Frame( math.min( 620, ScrW() - 20 ), math.min( 480, ScrH() - 20 ), "The Kaiser's Office" )

	local sheet = vgui.Create( "DPropertySheet", frame )
	sheet:Dock( FILL )
	sheet:AddSheet( "Economy", economyTab( sheet ) )
	sheet:AddSheet( "Citizens", citizensTab( sheet ) )
	sheet:AddSheet( "Upgrades", upgradesTab( sheet ) )
	frame.Ledger = ledgerTab( sheet )
	sheet:AddSheet( "Ledger", frame.Ledger )
	requestLedger()
end

concommand.Add( "gr_kaiser", open )

Net.Receive( "gr_kaiser_ledger", nil, function()
	local rows = {}
	for _ = 1, net.ReadUInt( 8 ) do
		table.insert( rows, { t = net.ReadFloat(), from = net.ReadString(), to = net.ReadString(),
			amount = net.ReadUInt( 24 ), source = net.ReadString() } )
	end
	local flows = {}
	for i = 1, 2 do
		flows[ i ] = {}
		for _ = 1, net.ReadUInt( 8 ) do flows[ i ][ net.ReadString() ] = net.ReadUInt( 24 ) end
	end
	ledger = { rows = rows, inflow = flows[ 1 ], outflow = flows[ 2 ] }
	if IsValid( frame ) then fillLedger( frame.Ledger ) end
end )

-- A dead Kaiser's office closes.
hook.Add( "Think", "gr_kaiser_panel", function()
	if IsValid( frame ) and not LocalPlayer():FateHas( "RunsEconomy" ) then frame:Remove() end
end )
