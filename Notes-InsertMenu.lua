--[[
	Notes - An addon to create notes(/stickies) in game
	@author: aLeX^rS (alexrs@gmail.com)
	
	Context Menu for Note text...
		
]]

local _grpcomp = function( el1, el2 )
	if type( el1 ) ~= "table" or type(el2) ~= "table" then return el1 < el2; end
	if el1[1] < el2[1] then
		return true;
	else
		return false;
	end
end

local _grpnamecomp = function( el1, el2 )
	if type( el1 ) ~= "table" or type(el2) ~= "table" then return el1 < el2; end
	if el1[2] < el2[2] then
		return true;
	else
		return false;
	end
end



local function GetClassNumber( classFilename )
	local ClassIndex = {};
	ClassIndex["HUNTER"] = 1;
	ClassIndex["WARRIOR"] = 2;
	ClassIndex["PALADIN"] = 3;
	ClassIndex["MAGE"] = 4;
	ClassIndex["PRIEST"] = 5;
	ClassIndex["WARLOCK"] = 6;
	ClassIndex["DEATHKNIGHT"] = 7;
	ClassIndex["DRUID"] = 8;
	ClassIndex["SHAMAN"] = 9;
	ClassIndex["ROGUE"] = 10;
	return ClassIndex[classFilename] or 0;
end

-- sortByGroup - sorts by group OR class
local function InsertRaidRoster( sortByGroup, lessDetails ) 
	local i, z = 1, GetNumGroupMembers();
	if z <= 0 then return; end
	local sz = "";
	local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, color, race = nil;
	
	local groups = {};
	
	for i = 1, z do
		name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo( i );
		if not zone then zone = "<twisting nether>"; end
		race = UnitRace( name );
		color = RAID_CLASS_COLORS[ fileName ];
		local r, g, b = color.r, color.g, color.b;
		r = r * 255
		g = g * 255
		b = b * 255
		r = r <= 255 and r >= 0 and r or 0
		g = g <= 255 and g >= 0 and g or 0
		b = b <= 255 and b >= 0 and b or 0
		local clrhex = string.format("%02x%02x%02x", r, g, b)
		
		if lessDetails then
			-- Addondev(Ldr/Assist)[ML] - Human Paladin (Group 1)<dc>
			sz = string.format("|cffffffcc[%s]|r|cff%s%s|r%s%s - |cffffcccc%s %s|r|cff99ffff[G%s]|r%s\n", level == 0 and "??" or level, clrhex, name, rank == 0 and "" or rank == 1 and " |cff99ffff(Assist)|r " or rank == 2 and " |cff99ffff(Ldr)|r ", 
				isML and " |cffccff99[ML]|r " or "", race or "", class, subgroup, online and "" or "|cffff64ab<DC>|r" );
		else
			-- Addondev(Ldr/Assist)[Maintank][Master Looter] - Human Paladin in Firelands(Group 1)<dc>
			sz = string.format("|cffffffcc[%s]|r|cff%s%s|r%s%s%s - |cffffcccc%s %s %s|r|cff99ffff[G%s]|r%s\n", level == 0 and "??" or level, clrhex, name, rank == 0 and "" or rank == 1 and " |cff99ffff(Assist)|r " or rank == 2 and " |cff99ffff(Ldr)|r ", 
				role == "MAINTANK" and " |cffcccccc[MT]|r " or "", isML and " |cffccff99[ML]|r " or "", race or "", class, online and "in " .. zone or "", subgroup, online and "" or "|cffff64ab<DC>|r" );
		end
		
		table.insert( groups, { sortByGroup and tonumber(subgroup) or GetClassNumber(fileName), name, sz } );
		
	end
		
	table.sort( groups, _grpnamecomp );
	table.sort( groups, _grpcomp );
	
	sz = "";
	for k,v in ipairs( groups ) do
		sz = sz .. v[3];
	end
	wipe( groups );
	groups = nil;
	
	Notes.NoteInsertText( sz );
	
end


local function GetCharName( plain )
	local class, classFileName = UnitClassBase("player");
	local color = RAID_CLASS_COLORS[ classFileName ];
	local r, g, b = color.r, color.g, color.b;
	r = r * 255
	g = g * 255
	b = b * 255
	r = r <= 255 and r >= 0 and r or 0
	g = g <= 255 and g >= 0 and g or 0
	b = b <= 255 and b >= 0 and b or 0
	local clrhex = string.format("%02x%02x%02x", r, g, b)
	if plain then
		return GetUnitName( "player" );
	else
		return "|cff" .. clrhex .. GetUnitName( "player" ) .. "|r";
	end
end




local function OnMouseUp( frame, button )
	Notes.Notes.Box.mouseisdown = nil; 
	if button == "RightButton" then 
		if Notes.DropDownMenu.initialize ~= Notes.Notes.Box.initMenuFunc then
			CloseDropDownMenus()
			Notes.DropDownMenu.initialize = Notes.Notes.Box.initMenuFunc
		end
		ToggleDropDownMenu(1, nil, Notes.DropDownMenu, "cursor", 0, 0)
	end 
end

Notes.Notes.Box.initMenuFunc = function( self, level )
	if not level then return end
	local info = self.info
	wipe(info)
	if level == 1 then
				
				
		wipe(info)
		info.text = "Undo |cffffffcc[Ctrl+Z]|r"
		info.hasArrow = nil
		info.notCheckable = 1
		info.func = function() Notes.URHist_Undo( true ) end
		info.tooltipText = nil
		info.disabled = #Notes.NotesDataHistory == 0 or nil
		UIDropDownMenu_AddButton(info, level)
		info.hasArrow = nil		
		info.disabled = nil
		
		wipe(info)
		info.text = "Redo |cffffffcc[Ctrl+Y]|r"
		info.hasArrow = nil
		info.notCheckable = 1
		info.func = function() Notes.URHist_Undo( false ) end
		info.tooltipText = nil
		info.disabled = #Notes.NotesDataHistoryReverse == 0 or nil
		UIDropDownMenu_AddButton(info, level)
		info.hasArrow = nil	
		info.disabled = nil		
				
		wipe(info)
		info.isTitle      = 1
		info.text         = "Insert"
		info.notCheckable = 1
		info.disabled     = 1
		UIDropDownMenu_AddButton(info, level)
		info.notCheckable = nil
		info.tooltipText  = nil
		info.disabled     = nil
		info.isTitle      = nil
			
		
		wipe(info)
		info.text = "Date/Time"
		info.hasArrow = 1
		info.notCheckable = 1
		info.func = nil
		info.tooltipText = nil
		UIDropDownMenu_AddButton(info, level)
		info.hasArrow = nil
		
		
		wipe(info)
		info.text = "Character Info"
		info.hasArrow = 1
		info.notCheckable = 1
		info.func = nil
		info.tooltipText = nil
		UIDropDownMenu_AddButton(info, level)
		info.hasArrow = nil

		
		wipe(info)
		info.text = "Zone/Instance"
		info.hasArrow = nil
		info.notCheckable = 1
		info.func = function() Notes.NoteInsertText( GetSubZoneText() .. " - " .. GetRealZoneText() ); end
		info.tooltipText = nil
		UIDropDownMenu_AddButton(info, level)
		info.hasArrow = nil
		
		wipe(info)
		info.text = "Party/Raid"
		info.hasArrow = 1
		info.notCheckable = 1
		info.func = nil
		info.tooltipText = nil
		UIDropDownMenu_AddButton(info, level)
		info.hasArrow = nil
		
		wipe(info)
		info.text = "Social Info"
		info.hasArrow = 1
		info.notCheckable = 1
		info.func = nil
		info.tooltipText = nil
		UIDropDownMenu_AddButton(info, level)
		info.hasArrow = nil
		
		
		wipe(info)
		info.disabled     = 1
		info.isTitle      = 1
		info.text         = "-------------"
		info.notCheckable = 1
		info.disabled     = nil
		UIDropDownMenu_AddButton(info, level)
		info.notCheckable = nil
		info.tooltipText  = nil
		info.disabled     = nil
		info.isTitle      = nil
		--Notes.AddonInsertMenuItems[ AddonTitle ]
		
		wipe(info)
		info.text = "Addons"
		info.hasArrow = 1;
		info.notCheckable = 1
		info.func = nil
		info.tooltipText = nil
		UIDropDownMenu_AddButton(info, level)
		info.hasArrow = nil
		
		
		wipe(info)
		info.disabled     = 1
		info.isTitle      = 1
		info.text         = "-------------"
		info.notCheckable = 1
		info.disabled     = nil
		UIDropDownMenu_AddButton(info, level)
		info.notCheckable = nil
		info.tooltipText  = nil
		info.disabled     = nil
		info.isTitle      = nil
		
		wipe(info)
		info.text = "Run note as Lua code..."
		info.hasArrow = nil
		info.notCheckable = 1
		info.func = function( ) 
				--We'll strip all colors, and links if any exist...
				local szCode = "--Compiled\n" .. Notes.Notes.Box:GetText():gsub( "||", "_SIMPLYNOTES,DOUBLE_PIPE_" );
				szCode = string.trim( szCode:gsub( "([^|]+)|c%x%x%x%x%x%x%x%x", "%1" ):gsub( "([^|]+)|r", "%1" ));
				szCode = szCode:gsub( "([^|]+)|H(%a+):[^|]+|h", "%1" ):gsub( "([^|]+)|h", "%1" ); --replace links with just the text...
				szCode = szCode:gsub( "_SIMPLYNOTES,DOUBLE_PIPE_", "||" )
				szCode = szCode:gsub( "||", "|" );
				
				local chunk, errormsg = loadstring( szCode , "NoteCode" );
				if not chunk then
					print( szCode:sub(1, szCode:len() > 50 and 50 or szCode:len() ) );
					Notes.ChatMsg( Notes.NOTES_ERRORCOLOR .. "Error: Can't compile note as Lua code!|r" );
					Notes.ChatMsg( Notes.NOTES_ERRORCOLOR .. errormsg .. "|r" );
					--
				else
					--print( szCode );
					Notes.ChatMsg( "Compiled note as Lua code, executing chunk..." );
					chunk();
				end
			end
		info.tooltipText = nil
		info.disabled = nil
		UIDropDownMenu_AddButton(info, level)
		info.hasArrow = nil	
		info.disabled = nil
		
		
		wipe(info)
		info.disabled     = 1
		info.isTitle      = 1
		info.text         = "-------------"
		info.notCheckable = 1
		info.disabled     = nil
		UIDropDownMenu_AddButton(info, level)
		info.notCheckable = nil
		info.tooltipText  = nil
		info.disabled     = nil
		info.isTitle      = nil
		


		info.text         = CLOSE
		info.func         = self.HideMenu
		info.checked      = nil
		info.arg1         = nil
		info.notCheckable = 1
		info.tooltipTitle = CLOSE
		UIDropDownMenu_AddButton(info, level)
	
	elseif level == 3 then --addons
	
		local parent = UIDROPDOWNMENU_MENU_VALUE;
		local menuitems = Notes.AddonInsertMenuItems[ parent ] or {};
		local k,v = nil;
			for k,v in ipairs( menuitems ) do
				wipe(info)
				info.text = type(v["title"]) == "function" and v["title"]() or v["title"];
				info.hasArrow = nil
				info.func = v["insertFunc"]
				info.disabled = type(v["disabled"]) == "function" and v["disabled"]() or v["disabled"];
				info.checked = nil
				info.notCheckable = 1
				info.tooltipTitle = nil
				info.tooltipText = nil
				UIDropDownMenu_AddButton(info, level)
			end
			info.disabled = nil;
	
	elseif level == 2 then
	
		local parent = UIDROPDOWNMENU_MENU_VALUE;
	
		if parent == "Addons" then

			local k,v = nil;
			local i = 0;
			for k,v in pairs( Notes.AddonInsertMenuItems ) do
				wipe(info)
				info.text = k -- the addon title
				info.hasArrow = 1
				info.func = nil
				info.checked = nil
				info.notCheckable = 1
				info.tooltipTitle = nil
				info.tooltipText = nil
				UIDropDownMenu_AddButton(info, level)
				i = i + 1;
			end
			info.hasArrow = nil;
			if i == 0 then
				wipe(info)
				info.text = "No Addons registered" -- the addon title
				info.hasArrow = nil
				info.func = nil
				info.checked = nil
				info.notCheckable = 1
				info.tooltipTitle = nil
				info.tooltipText = nil
				info.disabled = 1;
				UIDropDownMenu_AddButton(info, level)
				info.disabled = nil;
			end 
	
		elseif parent == "Date/Time" then
			
			wipe(info)
			info.text = "Local date and time"
			info.func = function() 
					Notes.NoteInsertText( date() );
				end
			info.checked = nil
			info.notCheckable = 1
			info.tooltipTitle = nil
			info.tooltipText = nil
			UIDropDownMenu_AddButton(info, level)
			
			wipe(info)
			info.text = "Realm time |cffffffcc[Ctrl+D]|r"
			info.func = function() 
					local hour, minute = GetGameTime()
					local suffix = hour > 12 and "PM" or "AM";
					if hour > 12 then hour = hour - 12; end
					local weekday, month, day, year = CalendarGetDate()
					local weekdays = {}
					weekdays[1] = "Sun";
					weekdays[2] = "Mon";
					weekdays[3] = "Tue";
					weekdays[4] = "Wed";
					weekdays[5] = "Thur";
					weekdays[6] = "Fri";
					weekdays[7] = "Sat";
					local months = {}
					months[1] = "Jan";
					months[2] = "Feb";
					months[3] = "Mar";
					months[4] = "Apr";
					months[5] = "May";
					months[6] = "Jun";
					months[7] = "Jul";
					months[8] = "Aug";
					months[9] = "Sep";
					months[10] = "Oct";
					months[11] = "Nov";
					months[12] = "Dec";
					--Sun Jun 14 01:31:41 2009
					Notes.NoteInsertText( string.format( "%s %s %d %d:%d%s %d", weekdays[weekday], months[month], day, hour, minute, suffix, year ) );
					months = nil;
					weekdays = nil;
				end
			info.checked = nil
			info.notCheckable = 1
			info.tooltipTitle = nil
			info.tooltipText = nil
			UIDropDownMenu_AddButton(info, level)
			
			
		elseif parent == "Character Info" then
		
			wipe(info)
			info.text = "Character Name"
			info.hasArrow = nil
			info.notCheckable = 1
			info.func = function() 
					Notes.NoteInsertText( GetCharName() .. " - " .. GetRealmName() ); 
				end
			info.tooltipText = nil
			UIDropDownMenu_AddButton(info, level)
			info.hasArrow = nil
			
			
			
			wipe(info)
			info.text = "Equipped Gear"
			info.hasArrow = nil
			info.notCheckable = 1
			info.func = function() 
					
					local slots = {
						--"AmmoSlot" - Ranged ammunition slot
						{"HeadSlot", "Helm"},
						{"NeckSlot", "Necklace"},
						{"ShoulderSlot", "Shoulders"},
						{"BackSlot", "Cloak"},
						{"ShirtSlot", "Shirt"},
						{"TabardSlot", "Tabard"},
						{"ChestSlot", "Chest"},
						{"WristSlot", "Wrist"},
						{"HandsSlot", "Gloves"},
						{"WaistSlot", "Belt"},
						{"LegsSlot", "Legs"},
						{"FeetSlot", "Foots"},
						{"Finger0Slot", "Ring1"},
						{"Finger1Slot", "Ring2"},				
						{"MainHandSlot", "Main Weapon"},
						--{"RangedSlot", "Ranged Weapon"},
						{"SecondaryHandSlot", "Offhand"},
						{"Trinket0Slot", "Trinket1"},
						{"Trinket1Slot", "Trinket2"},
						--[[Bag0Slot = "Backpack",
						Bag1Slot = "Bag1",
						Bag2Slot = "Bag2",
						Bag3Slot = "Bag3",]]
					};
					
					Notes.NoteInsertText( GetCharName() .. "-" .. GetRealmName() .. ": Equipped Gear\n" ); 
					local i,slottitle, slotname = nil;
					for i, slottitle in pairs( slots ) do
						slotname = slottitle[1];
						local slotId, texture, checkRelic = GetInventorySlotInfo( slotname );
						local itemLink = GetInventoryItemLink( "player", slotId );
						if itemLink then
							Notes.NoteInsertText( string.format( "%s: %s\n", slottitle[2], itemLink or "<nothing" ) ); 
						end
					end
					
					
				end
			info.tooltipText = nil
			UIDropDownMenu_AddButton(info, level)
			info.hasArrow = nil
			
			wipe(info)
			info.text = "Gear Inventory"
			info.hasArrow = nil
			info.notCheckable = 1
			info.func = function() 
					
					local slots = {
						--"AmmoSlot" - Ranged ammunition slot
						{"HeadSlot", "Helm"},
						{"NeckSlot", "Necklace"},
						{"ShoulderSlot", "Shoulders"},
						{"BackSlot", "Cloak"},
						{"ShirtSlot", "Shirt"},
						{"TabardSlot", "Tabard"},
						{"ChestSlot", "Chest"},
						{"WristSlot", "Wrist"},
						{"HandsSlot", "Gloves"},
						{"WaistSlot", "Belt"},
						{"LegsSlot", "Legs"},
						{"FeetSlot", "Foots"},
						{"Finger0Slot", "Ring1"},
						{"Finger1Slot", "Ring2"},				
						{"MainHandSlot", "Main Weapon"},
						--{"RangedSlot", "Ranged Weapon"},
						{"SecondaryHandSlot", "Offhand"},
						{"Trinket0Slot", "Trinket1"},
						{"Trinket1Slot", "Trinket2"},
						--[[Bag0Slot = "Backpack",
						Bag1Slot = "Bag1",
						Bag2Slot = "Bag2",
						Bag3Slot = "Bag3",]]
					};
					
					Notes.NoteInsertText( GetCharName() .. "-" .. GetRealmName() .. ": Gear Inventory\n" ); 
					Notes.NoteInsertText( "|cffffffccNote: To include items in your bank, your bank must be open|r\n" ); 
					local i,slotname,slottitle = nil;
					for i, slottitle in pairs( slots ) do
						slotname = slottitle[1]
						local slotId, texture, checkRelic = GetInventorySlotInfo( slotname );
						local availableItems, sortedByName = {}, {};
						GetInventoryItemsForSlot( slotId, availableItems );
						local bitlocation, itemID, sz = nil;

						for bitlocation, itemID in pairs( availableItems ) do
							local player, bank, bags, slot, bag = EquipmentManager_UnpackLocation( bitlocation );
							local name, link, _, iLevel, _, _, _, _, _, texture, vendorPrice = GetItemInfo( itemID );
							sortedByName[ string.format( "    %s|cffffffcc(iLvl:%s%s%s%s)|r\n", link, iLevel, not bank and not bags and ", |cff99ffffEquipped|r" or "", not bank and bags and ", |cffccff99Bags|r" or "", bank and ", |cff99ffffBank|r" or "" ) ] = name .. (slot or "");
						end
						
						table.sort( sortedByName );
						local szout = "";
						for szout, _ in pairs( sortedByName ) do
							sz = ( sz and sz or "" ) .. szout;
						end

						if sz then
							Notes.NoteInsertText( string.format( "  |cffffff00%s:|r\n%s", slottitle[2], sz ) ); 
						end
						
					end
					
					
				end
			info.tooltipText = nil
			UIDropDownMenu_AddButton(info, level)
			info.hasArrow = nil
			
			
			wipe(info)
			info.text = "Character Gold(No icons)"
			info.hasArrow = nil
			info.notCheckable = 1
			info.func = function() 
					local sz = GetCoinText( GetMoney() );
					
					Notes.NoteInsertText( string.format( "%s (%s)", sz, GetCharName() ) ); 
				end
			info.tooltipText = nil
			UIDropDownMenu_AddButton(info, level)
			info.hasArrow = nil
			
			wipe(info)
			info.text = "Character Gold(Coin Icons)"
			info.hasArrow = nil
			info.notCheckable = 1
			info.func = function() 
					local sz = GetCoinTextureString( GetMoney(), NotesPref["FontSize"] );
					Notes.NoteInsertText( string.format( "%s (%s)", sz, GetCharName() ) ); 
				end
			info.tooltipText = nil
			UIDropDownMenu_AddButton(info, level)
			info.hasArrow = nil
			
		
			
		elseif parent == "Social Info" then
			
			wipe(info)
			info.text = "All Friends"
			info.func = function() 
				
					-- b.net friends...
					local i, z, _ = 1, BNGetNumFriends();
					local sz = "";
					if z >= 1 then
						local _, givenName, surname, toonName, toonID, client, isOnline, messageText, noteText, isFriend = nil;
						for i = 1, z do
							_, givenName, surname, toonName, toonID, client, isOnline, _, _, _, messageText, noteText, isFriend, _ = BNGetFriendInfo( i );
							--print( BNGetFriendToonInfo( i, 1 ) )
							if not toonName then toonName = ""; else toonName = " on " .. toonName; end
							if not client then client = " [BNet] "; else client = "[" .. client .. "] " end
							if messageText and messageText:len() > 0 then messageText = "\n  - |cffffffcc" .. messageText .. "|r"; end
							if noteText and noteText:len() > 0 then noteText = "\n  - |cffffffcc" .. noteText .. "|r"; end
							--|Kg29|kant|k |Ks29|kr|k
							--givenName = givenName:gsub( "|K[^|]+|k([^|]+)|k", "%1");
							--surname = surname:gsub( "|K[^|]+|k([^|]+)|k", "%1");
							sz = sz .. string.format( "|cff99ffff%s%s|r%s%s%s%s\n", givenName or "", surname and " " .. surname or "", toonName or "", client or "", messageText or "", noteText or "" );
						end
					end
				
					i, z = 1, GetNumFriends();
					if z >= 1 then
						local name, level, class, area, connected, status, note, RAF = nil;
						for i = 1, z do
							name, level, class, area, connected, status, note, RAF = GetFriendInfo( i );
							sz = sz .. string.format("%s%s%s\n", name, level == 0 and "" or "["..level.."]", class == UNKNOWN and "" or " - "..class );
							if note and note ~= "" then
								sz = sz .. "  - |cffffffcc" .. note .. "|r\n";
							end
						end
					end

					if sz ~= "" then
						Notes.NoteInsertText( sz );
					end
				end
			info.checked = nil
			info.notCheckable = 1
			info.tooltipTitle = nil
			info.tooltipText = nil
			UIDropDownMenu_AddButton(info, level)
			
			
			
			wipe(info)
			info.text = "BNet Friends"
			info.func = function() 

					local i, z, _ = 1, BNGetNumFriends();
					local sz = "";
					if z >= 1 then
						local _, givenName, surname, toonName, client, isOnline, messageText, noteText, isFriend = nil;
						for i = 1, z do
							_, givenName, surname, toonName, _, client, isOnline, _, _, _, messageText, noteText, isFriend, _ = BNGetFriendInfo( i );
							if not toonName then toonName = ""; else toonName = " on " .. toonName; end
							if not client then client = " [BNet] "; else client = "[" .. client .. "] " end
							if messageText and messageText:len() > 0 then messageText = "\n  - |cffffffcc" .. messageText .. "|r"; end
							if noteText and noteText:len() > 0 then noteText = "\n  - |cffffffcc" .. noteText .. "|r"; end
							--|Kg29|kant|k |Ks29|kr|k
							--givenName = givenName:gsub( "|K[^|]+|k([^|]+)|k", "%1");
							--surname = surname:gsub( "|K[^|]+|k([^|]+)|k", "%1");
							sz = sz .. string.format( "|cff99ffff%s%s|r%s%s%s%s\n", givenName or "", surname and " " .. surname or "", toonName or "", client or "", messageText or "", noteText or "" );
						end
						
						Notes.NoteInsertText( sz );
					end
					

				end
			info.checked = nil
			info.notCheckable = 1
			info.tooltipTitle = nil
			info.tooltipText = nil
			UIDropDownMenu_AddButton(info, level)
			
			
			wipe(info)
			info.text = "WoW Friends"
			info.func = function() 
					local i, z = 1, GetNumFriends();
					if z <= 0 then return; end
					local sz = "";
					local name, level, class, area, connected, status, note, RAF = nil;
					for i = 1, z do
						name, level, class, area, connected, status, note, RAF = GetFriendInfo( i );

						sz = sz .. string.format("%s%s%s\n", name, not connected and "" or "["..level.."]", class == UNKNOWN and "" or " - "..class );
						if note and note ~= "" then
							sz = sz .. "   - |cffffffcc" .. note .. "|r\n";
						end

					end
					Notes.NoteInsertText( sz );
				end
			info.checked = nil
			info.notCheckable = 1
			info.tooltipTitle = nil
			info.tooltipText = nil
			UIDropDownMenu_AddButton(info, level)
			
			
			wipe(info)
			info.text = "WoW Friends(Online)"
			info.func = function() 
					local i, z = 1, GetNumFriends();
					if z <= 0 then return; end
					local sz = "";
					local name, level, class, area, connected, status, note, RAF = nil;
					for i = 1, z do
						name, level, class, area, connected, status, note, RAF = GetFriendInfo( i );
						if connected then
							sz = sz .. string.format("%s%s%s\n", name, not connected and "" or "["..level.."]", class == UNKNOWN and "" or " - "..class );
							if note and note ~= "" then
								sz = sz .. "   - |cffffffcc" .. note .. "|r\n";
							end
						end
					end
					Notes.NoteInsertText( sz );
				end
			info.checked = nil
			info.notCheckable = 1
			info.tooltipTitle = nil
			info.tooltipText = nil
			UIDropDownMenu_AddButton(info, level)
			
			wipe(info)
			info.text = "Ignore List"
			info.func = function() 
					local i, z = 1, GetNumIgnores();
					if z <= 0 then return; end
					local sz = "";
					local name = nil;
					for i = 1, z do
						name = GetIgnoreName( i );
						sz = sz .. string.format( "%s\n", name );
					end
					Notes.NoteInsertText( sz );
				end
			info.checked = nil
			info.notCheckable = 1
			info.tooltipTitle = nil
			info.tooltipText = nil
			UIDropDownMenu_AddButton(info, level)
			
		elseif parent == "Party/Raid" then
		
			wipe(info)
			info.text = "Raid Roster by Group"
			info.func = function() InsertRaidRoster( true, false ) end
			info.checked = nil
			info.notCheckable = 1
			info.tooltipTitle = nil
			info.tooltipText = nil
			info.disabled = GetNumGroupMembers() == 0 and 1 or nil
			UIDropDownMenu_AddButton(info, level)
			info.disabled = nil
			
			wipe(info)
			info.text = "Raid Roster by Group(Less Details)"
			info.func = function() InsertRaidRoster( true, true ) end
			info.checked = nil
			info.notCheckable = 1
			info.tooltipTitle = nil
			info.tooltipText = nil
			info.disabled = GetNumGroupMembers() == 0 and 1 or nil
			UIDropDownMenu_AddButton(info, level)
			info.disabled = nil
			
			info.text = "Raid Roster by Class"
			info.func = function() InsertRaidRoster( false, false ) end
			info.checked = nil
			info.notCheckable = 1
			info.tooltipTitle = nil
			info.tooltipText = nil
			info.disabled = GetNumGroupMembers() == 0 and 1 or nil
			UIDropDownMenu_AddButton(info, level)
			info.disabled = nil
			
			wipe(info)
			info.text = "Raid Roster by Class(Less Details)"
			info.func = function() InsertRaidRoster( false, true ) end
			info.checked = nil
			info.notCheckable = 1
			info.tooltipTitle = nil
			info.tooltipText = nil
			info.disabled = GetNumGroupMembers() == 0 and 1 or nil
			UIDropDownMenu_AddButton(info, level)
			info.disabled = nil
			
			
			wipe(info)
			info.text = "Party Roster"
			info.func = function() 

					local i, z = 1, GetNumGroupMembers();
					if z <= 0 then return; end
					local sz = "";
					local unitref, name, level, class, classFileName, color, race, partyleader = nil;
					for i = 0, z do
						if i == 0 then
							unitref = "player";
						else
							unitref = "party" .. i;
						end
						
						name = UnitName( unitref );
						class, classFileName = UnitClassBase( unitref );
						level = UnitLevel( unitref );
						race = UnitRace( unitref );
						partyleader = UnitIsPartyLeader( unitref ) and " |cff99ffff(Leader)|r " or "";
						
						color = RAID_CLASS_COLORS[ classFileName ];
						local r, g, b = color.r, color.g, color.b;
						r = r * 255
						g = g * 255
						b = b * 255
						r = r <= 255 and r >= 0 and r or 0
						g = g <= 255 and g >= 0 and g or 0
						b = b <= 255 and b >= 0 and b or 0
						local clrhex = string.format("%02x%02x%02x", r, g, b)
						sz = sz .. string.format("|cffffffcc[%s]|r|cff%s%s|r%s - |cffffcccc%s %s|r\n", level == 0 and "??" or level, clrhex, name, partyleader, race, class);
						
					end
					Notes.NoteInsertText( sz );
					
				end
			info.checked = nil
			info.notCheckable = 1
			info.tooltipTitle = nil
			info.tooltipText = nil
			info.disabled = GetNumGroupMembers() == 0 and 1 or nil
			UIDropDownMenu_AddButton(info, level)
			info.disabled = nil
			
			
		--elseif parent == "Zone/Instance" then
			
		end
	
	end
end
	
	
Notes.Notes.Box:SetScript( "OnMouseUp", function( frame, button ) 
		Notes.Notes.Box.mouseisdown = nil; 
		OnMouseUp( frame, button )
	end );
Notes.Notes.Scroll:SetScript( "OnMouseUp", OnMouseUp );