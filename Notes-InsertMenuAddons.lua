--[[
	Notes - An addon to create notes(/stickies) in game
	@author: aLeX^rS (alexrs@gmail.com)
	
	This is a temporary* script to register a few "Addons" for Simply Notes....
	THIS IS NOT A PERMANENT FILE
]]

Notes.temp_PLAYER_LOGIN = function()
	-- The PLAYER_LOGIN event has occured, this is being called from Notes.lua 
	
	
	-- Below is an example of how to register a Simply Notes insert menu item:
	
	if Notes and Notes.RegisterInsertMenuItem then
		-- print( "|cff00ff00Simply Notes is present and new enough!|r" );
		-- Simply Notes is installed, and is not too old a version
		
		
		
		
		-----------------------------------------------------
		------------------------ POSTAL ---------------------
		-----------------------------------------------------
		local MenuItem = {
				disabled = not Postal and 1 or nil, -- 1 if postal doesn't exist, or nil if it does
				title = Postal and "Scan chat for All messages" or "All messages <Postal not loaded>",
				insertFunc = function() 
					
						local numlines = SELECTED_CHAT_FRAME:GetNumMessages()
						local i, found = 1, false;
						local postalphrase = "|cff33ff99Postal|r:";
						local sz = "";
						for i = 1, numlines do
							local text, _, _, _ = SELECTED_CHAT_FRAME:GetMessageInfo( i )
							if string.match( text, postalphrase ) then
								sz = sz .. text .. "\n";
								found = true;
							end
						end
						Notes.NoteInsertText( sz );
						if not found then Notes.ChatMsg( "Didn't find any Postal chat messages to copy..." ); end
						
					end
				
			};
		Notes.RegisterInsertMenuItem( "Postal", MenuItem )
			
		local MenuItem = {
				disabled = not Postal and 1 or nil, -- 1 if postal doesn't exist, or nil if it does
				title = Postal and "Scan for Auction Successful" or "Successful auctions <Postal not loaded>",
				insertFunc = function() 
					
						local numlines = SELECTED_CHAT_FRAME:GetNumMessages()
						local i, found = 1, false;
						local postalphrase = "|cff33ff99Postal|r: Processing Message [%d]+: Auction successful";
						local postalphrase2 = "|cff33ff99Postal|r: Collected";
						local sz = "";
						for i = 1, numlines do
							local text, _, _, _ = SELECTED_CHAT_FRAME:GetMessageInfo( i )
							if string.match( text, postalphrase ) or string.match( text, postalphrase2 ) then
								sz = sz .. text .. "\n";
								found = true;
							end
						end
						Notes.NoteInsertText( sz );
						if not found then Notes.ChatMsg( "Didn't find any Postal chat messages to copy..." ); end
						
					end
				
			};
		Notes.RegisterInsertMenuItem( "Postal", MenuItem )
		-----------------------------------------------------
		------------------------ // -------------------------
		-----------------------------------------------------
		


		-----------------------------------------------------
		------------------------ AUCTION HOUSE---------------
		-----------------------------------------------------
		local MenuItem = {
				disabled = nil,
				title = "Scan chat for Auctions Created",
				insertFunc = function() 
					
					local numlines = SELECTED_CHAT_FRAME:GetNumMessages()
					local i, found = 1, false;
					local sz = "";
					local linephrase = "Auction created for[%s]+|c[%x]+";
					for i = 1, numlines do
						local text, _, _, _ = SELECTED_CHAT_FRAME:GetMessageInfo( i )
						if string.match( text, linephrase ) then
							sz = sz .. text .. "\n";
							found = true;
						end
					end
					Notes.NoteInsertText( sz );
					if not found then Notes.ChatMsg( "Didn't find any 'Auction created for...' messages..." ); end
					
				end
				
			};
		Notes.RegisterInsertMenuItem( "Auction House", MenuItem )
		
			
		-----------------------------------------------------
		------------------------ // -------------------------
		-----------------------------------------------------


		
		
		
		MenuItem = {
				disabled = not Recount and 1 or nil, --disabled if no recount...
				insertFunc = function() 
						local k, v, sz = nil;
						for k,v in pairs( Recount.MainWindow.Rows ) do
							if v.clickFunc then 
								sz = string.format( "%s|cffccff99%s|r - %s\n", sz or "", v.LeftText:GetText(), v.RightText:GetText() )
							end
						end
						if sz then sz = "\n|cffffffccRecount: " .. Recount.MainWindow.Title:GetText() .. "|r\n" .. sz; end
						Notes.NoteInsertText( sz or "<No recount data in main recount window>" );
					end,
				title = function() return Recount and "View: " .. Recount.MainWindow.Title:GetText() or "<Recount not found>" end
			};
		Notes.RegisterInsertMenuItem( "Recount", MenuItem )		
		--Notes.UnRegisterInsertMenuItem( "Recount", 1 ) -- This would unregister the first menu item we registered...
		
		
		
	else
		-- Can't register, Simply Notes is obviously not installed, or too old a version....
		-- print( "|cffff0000Simply Notes is too old or not installed|r" );
	end
	
	
	
end
