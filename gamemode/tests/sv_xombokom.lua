-- XOMBOKOM (sh_xombokom.lua): /xombokom and /xk, Kaiser only, upper case, broadcast sound,
-- 120 characters, 30 s cooldown, never in chat.
return function( T )
	DB.Query( "DELETE FROM players WHERE steamid LIKE 'bot:txk_%'" )
	local function bot( name, fate )
		local b = player.CreateNextBot( "txk_" .. name )
		b:SetRank( RANK_FRIEND )
		b:SetStemCells( 10 )
		T.Check( Fates.Take( b, fate ), name .. " takes " .. fate )
		return b
	end
	T.Wait( 0.2 )
	local k = bot( "kaiser", "kaiser" )
	local p = bot( "prole", "prole" )
	T.Wait( 0.5 )

	local casts, chats = {}, 0
	hook.Add( "GR_Xombokom", "txk", function( ply, text, snd, pitch ) table.insert( casts, { ply, text, snd, pitch } ) end )
	hook.Add( "GR_Chat", "txk", function() chats = chats + 1 end )

	T.Check( Chat.Parse( "/xk hi" ).id == "xombokom", "/xk parses" )
	T.Check( Chat.Parse( "/xombokom hi" ).id == "xombokom", "/xombokom parses" )

	Chat.Handle( p, "/xk hello" )
	T.Check( #casts == 0, "a prole is refused" )

	Chat.Handle( k, "/xk " .. string.rep( "a", 121 ) )
	T.Check( #casts == 0, "121 characters is refused" )

	Chat.Handle( k, "/xombokom work harder" )
	local c = casts[ 1 ]
	T.Check( c and c[ 2 ] == "WORK HARDER", "the Kaiser broadcasts upper case" )
	T.Check( c and string.match( c[ 3 ], "^kidneydagger/broadcast[1-7]%.wav$" ) ~= nil, "a broadcast sound" )
	T.Check( c and c[ 4 ] >= 80 and c[ 4 ] <= 120, "pitch 80-120" )

	Chat.Handle( k, "/xk again" )
	T.Check( #casts == 1, "the cooldown refuses a second one" )
	k.GR_LastXombokom = CurTime() - 31
	Chat.Handle( k, "/xk " .. string.rep( "b", 120 ) )
	T.Check( #casts == 2, "after 30 s, 120 characters goes through via /xk" )
	T.Check( chats == 0, "nothing goes to chat" )

	hook.Remove( "GR_Xombokom", "txk" )
	hook.Remove( "GR_Chat", "txk" )
	for _, b in ipairs( { k, p } ) do b:Kick() end
end
