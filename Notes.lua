--[[
	Notes - An addon to create notes(/stickies) in game
	@author: aLeX^rS (alexrs@gmail.com) - Truii, Whisperwind(US)
	
	
	Notes:
	Referenced !Swatter to familiarize my self with LUA
	Referenced WoWWiki's notes on ColorPicker, _GetTextHighlight, _ColorSelection from @Saiket: 
	http://www.wowinterface.com/forums/showthread.php?t=41521
	

	@License:
	This library is free software; you can redistribute it and/or
	modify it under the terms of the GNU Lesser General Public
	License as published by the Free Software Foundation; either
	version 2.1 of the License, or (at your option) any later version.

	This library is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	Lesser General Public License for more details.

	You should have received a copy of the GNU Lesser General Public
	License along with this library; if not, write to the Free Software
	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
	
	@TODO: Add localization...
]]


--[[
	
	==================================================================================
	================================== API ===========================================
	==================================================================================	
	void Notes.Toggle( )
	void Notes.NoteShow( int Index ) - Navigates to note
	void Notes.NotePrev( )
	void Notes.NoteNext( )
	void Notes.NoteNew( str text, str title[, int position] ) - Creates a new note; To get count of notes: #NotesData
	void Notes.NoteInsertText( str text[, bool append] ) - Inserts a string INTO the current note at the cursor position OR, at the end
	void Notes.NoteDelete( ) - Requests user confirmation for deleting current note
	void Notes.NoteLock( NIL, NIL, bool lock ) - Locks notes - triggered by clicking lock button, in addition to entering combat
	
	############
	#### Internal Use: ####
	void NoteSave( manuallycalled ) ; Saves note data to database, in addition creates UNDO steps; If manual saving is turned on, the note won't be saved unless manuallycalled = true
	############

	
]]


Notes = {}
NotesData = {}
NotesPref = {}
NotesPrefCS = {} -- Character Specific...
local NotesLDB, LDBIcon = nil; --Still using LDB, but not LDBIcon, I FUCKING HATE THOSE MINIMAP ICONS/v1.2.12
Notes.AddonInsertMenuItems = {};


--[[
==================================================================================
================================== CONSTANTS =====================================
==================================================================================
]]

local NOTES_DEBUG = nil;

local NOTES_VERSION = GetAddOnMetadata( "Notes", "Version" )
local NOTES_STRATA = "MEDIUM"
local NOTES_DEFAULT_NOTE = "Empty Note!" 
local NOTES_DEFAULT_NOADDONDATA = "Thanks for using |cffffdc6eSimply Notes!|r\n\n\nUse the |cff99ffffArrow Icons|r below to |cffccff99navigate|r through your notes...\nTo |cffccff99create|r a new note, click the |cff99ffffPlus icon|r.\n\nThere are quite a few |cffccff99options|r available by typing \"|cffffffcc/notes|r\" into your chat window, and pressing enter.\n"
local NOTES_LOADMSG = "Loaded |cffffcc00Simply Notes "..NOTES_VERSION.."|r - |cff00ccffTruii-Whisperwind(US)|r"
local NOTES_LOGINMSG = "Type |cffffcc00/notes|r for help...";-- changing |cff00cc00Font|r, |cff00cc00Fontsize|r, |cff00cc00Window Scale|r, and |cff00cc00Background Alpha|r"
local NOTES_DELETENOTE = "Are you sure you'd like to delete"
local NOTES_FONT_PATH = "Interface\\AddOns\\Notes\\Fonts\\"
local NOTES_ART_PATH = "Interface\\AddOns\\Notes\\Textures\\"
Notes.NOTES_ART_PATH = NOTES_ART_PATH;
local NOTES_RECENTCOLORS_MAX = 8
local NOTES_DATIND_TITLE = 2
local NOTES_DATIND_TEXT = 1
local NOTES_TITLELEN_MAX = 22
local NOTES_BUTTON_SPACING = 10

local NOTES_ERRORCOLOR = "|cffff0000"
Notes.NOTES_ERRORCOLOR = NOTES_ERRORCOLOR;

--[[
==================================================================================
================================== SV DEFS =======================================
==================================================================================
]]

tinsert( NotesData, { NOTES_DEFAULT_NOADDONDATA, "Sample Note" } )

NotesPref["lastShown"] = 1  
NotesPrefCS["lastShown"] = nil
NotesPref["Scale"] = 0.9
NotesPref["BackAlpha"] = 0.88
NotesPref["Font"] = 1
NotesPref["FontSize"] = 13
NotesPref["Shown"] = 1
NotesPref["isLocked"] = 0
NotesPref["RecentColors"] = {}
NotesPref["MiniMapIcon"] = {}
NotesPref["MiniMapIcon"]["hide"] = false
NotesPref["ManualSave"] = nil; -- 1(on) or nil(off)



local function PrefSetupFonts()
	NotesPref["Fonts"] = { 
		"yahei.ttf", 
		"cour.ttf", 
		"yellowjacket.ttf",
		"porky.ttf",
		"heroic.ttf",
		"cooline.ttf",
		"Fonts\\FRIZQT__.TTF",
		"Fonts\\ARIALN.TTF",
		"Fonts\\skurri.ttf",
		"Fonts\\MORPHEUS.ttf" 
	}
end
PrefSetupFonts()

--[[
==================================================================================
================================== HELPERS =======================================
==================================================================================
]]

local tinsert, tremove = table.insert, table.remove

function Notes.ChatMsg( msg, prefix )
	if ( not prefix ) then msg = "|cffff5533Notes:|r "..msg end
	DEFAULT_CHAT_FRAME:AddMessage( msg )
end

local chat = Notes.ChatMsg

local function DEBUG( msg, ... )
	if type(msg) == "string" or type(msg) == "number" then msg = "|cffff5533Notes DEBUG:|r "..( msg or "nil" ) end
	if NOTES_DEBUG then print( msg, ... ) end
end

Notes.DEBUG = DEBUG;

local function toggle()
	if Notes.Notes:IsVisible() then
		Notes.FadeFrame( Notes.Notes )
		--Notes.Notes:Hide()
	else
		Notes.NoteShow( Notes.Notes.pos or 1 )
	end
end

local function Faded( self )
	self:Hide( )
	NotesPref["Shown"] = 0
	self:SetAlpha( 1 )
end

function Notes.FadeFrame( self )
	local fadeInfo = {}
	fadeInfo.mode = "OUT"
	fadeInfo.timeToFade = 0.2
	fadeInfo.finishedFunc = Faded
	fadeInfo.finishedArg1 = self
	UIFrameFade( self, fadeInfo );
end

function Notes.GeneralContextMenu( self, level )
	-- Ref Line: 1739
	if not level then return end
	local info = self.info
	wipe(info)
	if level == 1 then
						
		info.text = "Show Simply Notes"
		info.func = toggle
		info.checked = Notes.Notes:IsVisible()
		info.notCheckable = nil
		info.tooltipText = nil
		UIDropDownMenu_AddButton(info, level)
		
		
		info.text = "Reset Position"
		info.func = function() 
				if SlashCmdList["NOTES"] then
				   local fnc = SlashCmdList["NOTES"]
				   fnc( "resetpos" )
				end
			end
		info.notCheckable = nil
		info.checked = nil
		UIDropDownMenu_AddButton(info, level)
		
		
		info.text = "About Simply Notes"
		info.func = function() 
				if SlashCmdList["NOTES"] then
				   local fnc = SlashCmdList["NOTES"]
				   fnc( "about" )
				end
			end
		info.notCheckable = nil
		info.checked = nil
		UIDropDownMenu_AddButton(info, level)
		

				
		wipe(info)
		info.isTitle      = 1
		info.text         = "-General Options-"
		info.notCheckable = 1
		info.disabled     = nil
		UIDropDownMenu_AddButton(info, level)
		info.notCheckable = nil
		info.tooltipText = nil
		info.disabled     = nil
		info.isTitle      = nil
		
		
		wipe(info)
		info.text = "Show MiniMap Icon"
		info.func = function() 
				if SlashCmdList["NOTES"] then
				   local fnc = SlashCmdList["NOTES"]
				   fnc( "minimap" )
				end
			end
		info.checked = NotesPref["MiniMapIcon"]["hide"] == false or nil
		info.notCheckable = nil
		info.tooltipText = nil
		UIDropDownMenu_AddButton(info, level)
		
		
		wipe(info)
		info.text = "Simply Notes Strata"
		info.hasArrow = 1
		info.notCheckable = 1
		info.func = nil
		info.tooltipText = nil
		UIDropDownMenu_AddButton(info, level)
		info.hasArrow = nil
		

		wipe(info)
		info.text = "Note Font"
		info.hasArrow = 1
		info.notCheckable = 1
		info.func = nil
		info.tooltipText = nil
		UIDropDownMenu_AddButton(info, level)
		info.hasArrow = nil
		
		wipe(info)
		info.text = "Note Font Size"
		info.hasArrow = 1
		info.notCheckable = 1
		info.func = nil
		info.tooltipText = nil
		UIDropDownMenu_AddButton(info, level)
		info.hasArrow = nil
		
		wipe(info)
		info.text = "Simply Notes Scale"
		info.hasArrow = 1
		info.notCheckable = 1
		info.func = nil
		info.tooltipText = nil
		UIDropDownMenu_AddButton(info, level)
		info.hasArrow = nil
		
		wipe(info)
		info.text = "Simply Notes Back Alpha"
		info.hasArrow = 1
		info.notCheckable = 1
		info.func = nil
		info.tooltipText = nil
		UIDropDownMenu_AddButton(info, level)
		info.hasArrow = nil
					
		
		wipe(info)
		info.text         = CLOSE
		info.func         = self.HideMenu
		info.checked      = nil
		info.arg1         = nil
		info.notCheckable = 1
		info.tooltipTitle = CLOSE
		UIDropDownMenu_AddButton(info, level)
		
	elseif level == 2 then
	
		local parent = UIDROPDOWNMENU_MENU_VALUE;
		
		
		if parent == "Simply Notes Strata" then
			
			wipe(info)
			local stratas = {};
			stratas[1] = "Medium";
			stratas[2] = "High";
			stratas[3] = "Dialog";
			--stratas[4] = "Tooltip";
			
			for k,v in pairs( stratas ) do 
				info.text = v
				info.func = function() 
						Notes.UpdateFrameStratas( v:upper() );
					end
				info.checked = Notes.Notes:GetFrameStrata() == v:upper() or nil
				info.notCheckable = nil
				info.tooltipTitle = nil
				info.tooltipText = nil
				UIDropDownMenu_AddButton(info, level)
			end
			
		
		elseif parent == "Note Font" then
			wipe(info)
			for k,v in pairs( NotesPref["Fonts"] ) do 
				info.text = v
				info.func = function() 
						if SlashCmdList["NOTES"] then
						   local fnc = SlashCmdList["NOTES"]
						   fnc( "font "..k )
						end
					end
				info.checked = NotesPref["Font"] == k or nil
				info.notCheckable = nil
				info.tooltipTitle = nil
				info.tooltipText = nil
				UIDropDownMenu_AddButton(info, level)
			end
			
		elseif parent == "Note Font Size" then
		
			wipe(info)
			local i = 0;
			for i = 7, 40, 3 do 
				info.text = i
				info.func = function() 
						if SlashCmdList["NOTES"] then
						   local fnc = SlashCmdList["NOTES"]
						   fnc( "fontsize "..i )
						end
					end
				info.checked = NotesPref["FontSize"] == i or nil
				info.notCheckable = nil
				info.tooltipTitle = nil
				info.tooltipText = nil
				UIDropDownMenu_AddButton(info, level)
			end
			
		elseif parent == "Simply Notes Scale" then
		
			wipe(info)
			local i = 0;
			for i = 30, 120, 10 do 
				info.text = i.."%"
				info.func = function() 
						if SlashCmdList["NOTES"] then
						   local fnc = SlashCmdList["NOTES"]
						   fnc( "scale "..i )
						end
					end
				info.checked = NotesPref["Scale"] == ( i / 100 ) or nil
				info.notCheckable = nil
				info.tooltipTitle = nil
				info.tooltipText = nil
				UIDropDownMenu_AddButton(info, level)
			end
			
		elseif parent == "Simply Notes Back Alpha" then
		
			wipe(info)
			local i = 0;
			for i = 0, 100, 10 do 
				info.text = i.."%"
				info.func = function() 
						if SlashCmdList["NOTES"] then
						   local fnc = SlashCmdList["NOTES"]
						   fnc( "alpha "..i )
						end
					end
				info.checked = NotesPref["BackAlpha"] == ( i / 100 ) or nil
				info.notCheckable = nil
				info.tooltipTitle = nil
				info.tooltipText = nil
				UIDropDownMenu_AddButton(info, level)
			end
			
		end
		
	end
end

function Notes.UpdateFrameStratas( strata )
	
	if not strata or type( strata ) ~= "string" then
		strata = "High";
	end
	
	local stratas = {};
	stratas[1] = "Medium";
	stratas[2] = "High";
	stratas[3] = "Dialog";
	--stratas[4] = "Tooltip";
	

	Notes.Notes:SetFrameStrata( strata:upper() );
	Notes.Notes:SetFrameLevel( 10 );
	NotesPref["Strata"] = strata:upper();
	Notes.Notes.SearchFrame:SetFrameStrata( strata:upper() );
	Notes.Notes.SearchFrame:SetFrameLevel( 30 );
	
	for k, v in pairs( stratas ) do
		if v:upper() == strata:upper() then
			Notes.ConfirmBox:SetFrameStrata( stratas[k+1] and stratas[k+1]:upper() or stratas[k]:upper() );
			Notes.ConfirmBox:SetFrameLevel( stratas[k+1] and 10 or 50 ); -- if in same strata, then 50, otherwise 10
			break;
		end
	end
end

function Notes.CreateLDBLauncher()
	local LDB = LibStub("LibDataBroker-1.1"); --LibStub:GetLibrary('LibDataBroker-1.1', true)
	--LDBIcon = LibStub("LibDBIcon-1.0");
	if not LDB then 
		return;
	else
		--NotesMapIcon:Hide( );
	end

	NotesLDB = LDB:NewDataObject( 'Simply Notes', 
		{
			type = 'launcher',
			icon = NOTES_ART_PATH..'icon',

			OnClick = function(frame, button)
				if button == 'LeftButton' then
					Notes.Toggle( );
				elseif button == 'RightButton' then
					
					frame.initMenuFunc = Notes.GeneralContextMenu
					Notes.DropDownMenu.OnClick(frame, frame, frame)
					--if SlashCmdList["NOTES"] then
					--   local fnc = SlashCmdList["NOTES"]
					--   fnc( "about" )
					--end
				end
			end,

			OnTooltipShow = function( tooltip )
				tooltip:AddLine( 'Simply Notes '..NOTES_VERSION )
				tooltip:AddLine( 'Left click to toggle Notes...', 1, 1, 1 )
				tooltip:AddLine( 'Right click for options...', 1, 1, 1 )
				tooltip:AddLine( '/notes minimap to hide MiniMap Icon', .7, .7, 1 )
			end,
		}
	)
	--[[LDBIcon = LibStub("LibDBIcon-1.0")
	if LDBIcon then
		LDBIcon:Register( "Simply Notes", NotesLDB, NotesPref["MiniMapIcon"] )
	end]]
end



--[[
==================================================================================
================================== NOTES DATA -+>< ===============================
==================================================================================
]]

function Notes.Toggle( )        
	-- In the case: toggle, from MiniMapIcon
	if Notes.ConfirmBox.isShown then return end
	toggle()
end

-- @ void :NoteShow( int noteindex )
function Notes.NoteShow( pos )

	local maxNote = #NotesData
	
	if (not NotesData or maxNote < 1) then 
		NotesData = {} 
		tinsert( NotesData, { NOTES_DEFAULT_NOTE, "New Note" } )
		Notes.Notes.pos = 1
		NotesPref["lastShown"] = 1    
		NotesPrefCS["lastShown"] = 1
		maxNote = #NotesData
	end
	
	if not pos then
		if Notes.Notes.pos < 1 then Notes.Notes.pos = 1 end 
	end
	
	local curNote = tonumber( pos or Notes.Notes.pos )
	if not curNote or curNote < 1 then
		curNote = NotesPrefCS["lastShown"] or NotesPref["lastShown"] or 1

	end

	Notes.Notes.pos = curNote or -1
	if ( Notes.Notes.pos == 0 ) then
		Notes.Notes.pos = -1
	end
	
	
	Notes.NoteDisplay()
	maxNote = nil
end

-- @ str GetDefaultTitle( str text ) ; finds first line of alphanumerical text, strips colors/links
local function GetDefaultTitle( body )
	if not body or not type(body) == "string" then 
		body = ""; 
	end

	if body:match("^\n") then 
		if not body:match( "\n[%w%[%]%p ]+" ) then 
			body = ""
		else
			body = body:match( "\n[%w%[%]%p ]+" ):gsub("\n", "") or body:gsub( "\n" )
		end
	end
	if body:match( "\n" ) then body = body:sub( 0, body:find( "\n" ) ); end
	local body = string.trim( body:gsub( "\n", " " ):gsub( "|c%x%x%x%x%x%x%x%x", "" ):gsub( "|r", "" ):gsub( "[%[%]]", "" ):gsub( "  ", " " ) );
	body = body:gsub( "|H(%a+):[^|]+|h", "" ):gsub( "|h", "" ):gsub( "[%[%]]", "" ); --replace links with just the text...
	body = string.trim( body )

	if body:len() > NOTES_TITLELEN_MAX then
		body = body:sub( 1, NOTES_TITLELEN_MAX - 3 ) .. "...";
	elseif body:len() < 2 then
		body = "<No Title>";
	end
	
	return body;
end

-- @ void :NoteDisplay( int index ) ; Updates window to display note
function Notes.NoteDisplay( id )    
	if id then Notes.Notes.pos = id else id = Notes.Notes.pos end
	
	if ( id == -1 ) then
		Notes.Notes.curNote = NOTES_DEFAULT_NOTE
		Notes.NoteUpdate()
		return
	end

	local note = NotesData[ id ]
	if type(note) ~= "table" then 
		NotesData[ id ] = { note, GetDefaultTitle( note ) }
		note = NotesData[ id ]
	end
	
	if ( not note ) then
		Notes.Notes.curNote = "Unknown note at index "..id
		Notes.NoteUpdate()
		return
	end
                        
	Notes.Notes.curNote = note[ NOTES_DATIND_TEXT ]
	Notes.Notes.selected = false
	Notes.NoteUpdate()
	Notes.Notes:Show()
	NotesPref["Shown"] = 1
	NotesPref["lastShown"] = id;
	NotesPrefCS["lastShown"] = id;
	if Notes.URHist_Reset then
		Notes.URHist_Reset( )
	end
	
	Notes.Title:SetText( "Simply Notes ["..( note[ NOTES_DATIND_TITLE ] or GetDefaultTitle( note[ NOTES_DATIND_TEXT ] ) ).."]" )
	if not note[ NOTES_DATIND_TITLE ] then note[ NOTES_DATIND_TITLE ] = GetDefaultTitle( note[ NOTES_DATIND_TEXT ] ); end
end

-- @ void :NoteDone( void ) ; Used by close button, hides...
function Notes.NoteDone()
	Notes:Toggle( )
end

-- @ void :NotePrev( void ) ; Previous note...
function Notes.NotePrev()
	local cur = Notes.Notes.pos or 1
	if ( cur > 1 ) then
		Notes.NoteDisplay( cur - 1 )
	else
		--Notes.NoteUpdate()
		Notes.NoteDisplay( #NotesData )
	end
	PlaySound( "igAbiliityPageTurn" );
	cur = nil
	Notes.Notes.Box:ClearFocus()
end

-- @ void :NoteNext( void ) ; Next note...
function Notes.NoteNext()
	local cur = Notes.Notes.pos or 1
	local max = table.getn( NotesData ) or 0
	if (cur < max) then
		Notes.NoteDisplay(cur + 1)
	else
		Notes.NoteDisplay( 1 ); -- toggle to beginning
	end
	
	PlaySound( "igAbiliityPageTurn" );
	
	cur = nil
	max = nil
	Notes.Notes.Box:ClearFocus()
end

-- @ void :UpdateNextPrev( void ) ; Updates window based on position of note, enables/disables/shows/hides buttons
function Notes.UpdateNextPrev()
	local cur = Notes.Notes.pos or 1
	local max = #NotesData or 0
	
	--[[
	if ((max > cur) and (cur ~= -1)) then
		-- Set next button to "Next"
		--Notes.Notes.Next:SetText( "Next >" ) 
		Notes.Notes.Next:SetNormalTexture( NOTES_ART_PATH.."icon-next")
	else 
		-- Set next button to "New"
		--Notes.Notes.Next:SetText( "+ New" )
		Notes.Notes.Next:SetNormalTexture( NOTES_ART_PATH.."icon-add")
	end

	if cur > 1 then 
		Notes.Notes.Prev:Enable();
		Notes.Notes.Prev:SetAlpha(1);
	else 
		Notes.Notes.Prev:Disable()
		Notes.Notes.Prev:SetAlpha(.6)
	end
	]]
	
	if cur == 1 and max == 1 then 
		Notes.Notes.Delete:Disable() 
		Notes.Notes.Delete:SetAlpha(.7)
		Notes.Notes.Next:Disable() 
		Notes.Notes.Next:SetAlpha(.7)
	else 
		Notes.Notes.Delete:Enable() 
		Notes.Notes.Delete:SetAlpha(1)
		Notes.Notes.Next:Enable() 
		Notes.Notes.Next:SetAlpha(1)
	end
	
	Notes.Notes.Mesg:SetText( "Note |cffffffff"..cur.."|r of |cffffffff"..max.."|r" )
	cur = nil
	max = nil
	
end

-- @ void :NoteUpdate( void ) ; REDUNDANT BUT IN-USE, FIX LATER
function Notes.NoteUpdate()
	if (not Notes.Notes.curNote ) then Notes.Notes.curNote = NOTES_DEFAULT_NOTE end
	Notes.Notes.Box:SetText( Notes.Notes.curNote )
	Notes.Notes.Scroll:UpdateScrollChildRect()
	Notes.UpdateNextPrev()
	Notes.Notes:Show()
end

-- @ void :CreateNote( table frame, str button ) ; Appends or Inserts a New Note based on arg button
function Notes.CreateNote( self, button )
	if button == "LeftButton" then
		Notes.NoteNew( );
	elseif button == "RightButton" then
		local newpos = Notes.Notes.pos + 1;
		if #NotesData + 1 < newpos then newpos = #NotesData + 1; end
		Notes.NoteNew( nil, nil, newpos );
	end
end

-- @ void :NoteNew( str text, str title[, int position] ) ; Creates a new note - used by Mail Frame/Player contexual menu
function Notes.NoteNew( text, title, pos )
	if (not NotesData ) then NotesData = { } end
	if not pos then pos = #NotesData + 1; end
	tinsert( NotesData, pos, { type(text) == "string" and text or NOTES_DEFAULT_NOTE, title or GetDefaultTitle( type(text) == "string" and text or NOTES_DEFAULT_NOTE ) } )
	Notes.NoteShow( pos )
	PlaySound( "igAbiliityPageTurn" );
end

-- @ void :NoteInsertText( str text, bool append ) ; Inserts a string INTO the current note at the cursor position OR, at the end
function Notes.NoteInsertText( text, append )
	if not text or type(text) ~= "string" then return; end
	if append then
		Notes.Notes.Box:SetText( Notes.Notes.Box:GetText().."\n"..text );
	else
		Notes.Notes.Box:Insert( text )
	end
end

-- @ void :NoteDelete( void ) ; Requests user confirmation for deleting current note
local del_iPos = nil
function Notes.NoteDelete( )
	del_iPos = Notes.Notes.pos	
	DEBUG( "del_iPos="..del_iPos )
		
	local btnConfirm = { "Yes", Notes.ConfirmBox_Confirm }
	local btnCancel = { "No", Notes.ConfirmBox_Cancel } 
	Notes.SetupConfirm( "Simply Notes "..NOTES_VERSION, NOTES_DELETENOTE .. " |cffffff00Note "..del_iPos.."|r?", btnCancel, btnConfirm )
	
	btnConfirm = nil
	btnCancel = nil
end

-- @ void :NoteLock( table frame, str button, bool lock, bool dontsave ) ; Locks notes - triggered by clicking lock button, in addition to entering combat
function Notes.NoteLock( self, button, lock, dontsave )
	
	local locked = 0
	if not lock then
		if NotesPref["isLocked"] == 0 then locked = 1 else locked = 0 end
	else
		locked = lock
	end

	if not dontsave then	
		-- Normal lock
		NotesPref["isLocked"] = locked
	end

	local texture = "icon-unlocked"
	if locked == 1 then texture = "icon-locked" end

	Notes.Notes.Lock:SetNormalTexture( NOTES_ART_PATH..texture )
	if locked == 1 then
		Notes.Notes.Box:Disable()
		Notes.Notes.Color:Disable()
	else
		Notes.Notes.Box:Enable()
		Notes.Notes.Color:Enable()
	end

	GameTooltip:Hide()
	locked = nil
	texture = nil
   
end

-- @ void :NoteSave( manuallycalled ) ; Saves note data to database, in addition creates UNDO steps; If manual saving is turned on, the note won't be saved unless manuallycalled = true
function Notes.NoteSave( manuallycalled )
	
	local cur = Notes.Notes.pos or 1
	
	
	
	if #NotesData == 0 or not NotesPref["ManualSave"] or manuallycalled and NotesPref["ManualSave"] then
		-- Save to DB
		NotesData[ cur ][ NOTES_DATIND_TEXT ] = Notes.Notes.Box:GetText() or ""
		NotesData[ cur ][ NOTES_DATIND_TITLE ] = GetDefaultTitle( NotesData[ cur ][ NOTES_DATIND_TEXT ] );
		Notes.Title:SetText( "Simply Notes ["..( NotesData[ cur ][ NOTES_DATIND_TITLE ] ).."]" )
		
		if Notes.URHist_Add then
			Notes.URHist_Add( NotesData[ cur ][ NOTES_DATIND_TEXT ] , Notes.Notes.Box:GetCursorPosition() ) --add previous text to history
		end
		
	else
		--Manual save is on, just update title...
		Notes.Title:SetText( "Simply Notes ["..( GetDefaultTitle(Notes.Notes.Box:GetText()) ).."]" )
		if Notes.URHist_Add then
			Notes.URHist_Add( Notes.Notes.Box:GetText() , Notes.Notes.Box:GetCursorPosition() ) --add previous text to history
		end
	end
		
	if NotesPref["ManualSave"] and not manuallycalled then
		-- Enable the save button, note changed...
		Notes.Notes.SaveIcon:Enable();
		
	elseif NotesPref["ManualSave"] and manuallycalled then
		-- Disable the save button, no changes to save
		Notes.Notes.SaveIcon:Disable();
	end
		
		
	if Notes.Notes.pos ~= cur then
		Notes.NoteShow( 1 )
	end
	cur = nil
	
end

-- @ - Used to Capture CTRL+Z/Y keystrokes
function Notes.OnKeyDown( self, text )
	if not IsControlKeyDown() then return self, text; end
	
	if string.lower( text ) == "z" or string.lower( text ) == "y" then
		if Notes.URHist_Undo then
			Notes.URHist_Undo( string.lower( text ) == "z" or nil )
		end
	end
	
	if string.lower( text ) == "f" then
		Notes.Notes.SearchFrame:Show();
		
	elseif string.lower( text ) == "s" and NotesPref["ManualSave"] then
		Notes.NoteSave( true );
	
	elseif string.lower( text ) == "d" then
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
	
	return self, text;
end





--[[
==================================================================================
================================== EDITOR RELATED ================================
==================================================================================
]]

-- @ void :UseRecentColor( str colorhex ) ; Used by ColorPicked dialog / Menu
function Notes.UseRecentColor( clrhex )
	DEBUG( "UseRecentColor:", clrhex )
	Notes.ColorSelection ( Notes.Notes.Box, "|cff"..clrhex );	
end

-- @ void ColorCallback( bool CANCELLED ) ; Parses color info from color picker, performs color coding
local function myColorCallback(restore)
	local newR, newG, newB, newA;
	if restore then
		newR, newG, newB, newA = unpack(restore);
	else
		newA, newR, newG, newB = OpacitySliderFrame:GetValue(), ColorPickerFrame:GetColorRGB();
	end

	local r, g, b, a = newR, newG, newB, newA;
	r = r * 255
	g = g * 255
	b = b * 255
	r = r <= 255 and r >= 0 and r or 0
	g = g <= 255 and g >= 0 and g or 0
	b = b <= 255 and b >= 0 and b or 0
	local clrhex = string.format("%02x%02x%02x", r, g, b)
	
	if not restore then
		NotesPref["RecentColors"][ #NotesPref["RecentColors"] ] = clrhex --Add to history...
	else
		tremove( NotesPref["RecentColors"], #NotesPref["RecentColors"] ) -- Color pick cancelled, remove last element
		if Notes.UNDOColorRemove then --Removed element 1 in recent colors to afford this new element, we cancelled so lets return it
			tinsert( NotesPref["RecentColors"], 1, Notes.UNDOColorRemove )
			Notes.UNDOColorRemove = nil
		end
	end
	
	
--	DEBUG( "clrhex:", clrhex )
	Notes.URHist_Undoing = true -- DO NOT ADD TO HISTORY, the color picker spams! 
	Notes.ColorSelection ( Notes.Notes.Box, "|cff"..clrhex );
	
-- Apparently this is complicated....  fuck sakes
--[[	
	if true then return end
	local StartPos, EndPos = Notes.GetTextHighlight( );
	if ( StartPos +1 ) > EndPos then return end
	local subText = string.sub( Notes.Notes.Box:GetText(), StartPos +1, EndPos );
	--@Todo: add logic to prevent fucking other Control Code...
	subText = "|cffffff00"..subText.."|r"
	Notes.Notes.Box:Insert( subText );
	Notes.Notes.Box:HighlightText( StartPos, EndPos );
	DEBUG( "HighlightText:", StartPos, EndPos )
]]

end

-- @ void :ColorClicked( void ) ; -User clicked the COLOR button
function Notes.ColorClicked(  )

	local StartPos, EndPos = Notes.GetTextHighlight( );
	if StartPos == EndPos then
		local text = Notes.Notes.Box:GetText( )
		if #text == 0 then
		   Notes.Notes.Box:Insert( NOTES_DEFAULT_NOTE )
		   text = NOTES_DEFAULT_NOTE
		end
		Notes.Notes.Box:SetCursorPosition( 0 )
	end

	-- Opening color picker, add a new element to NotesPref["RecentColors"], delete it if CANCELLED
	Notes.UNDOColorRemove = nil
	if #NotesPref["RecentColors"] > NOTES_RECENTCOLORS_MAX then
		Notes.UNDOColorRemove = tremove( NotesPref["RecentColors"], 1 )
	end
	tinsert( NotesPref["RecentColors"], "ffffff" )

	ColorPickerFrame:SetColorRGB( 1, 1, 1);
	ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = false, 1;
	ColorPickerFrame.previousValues = { 1, 1, 1, 1};
	ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = 
	myColorCallback, myColorCallback, myColorCallback;
	ColorPickerFrame:Hide();
	ColorPickerFrame:Show();	
end

-- @ void :GetTextHighligh( void ) ; Removes the selected text to determine what's selected, then restores it
-- ! GetTextHighlight, ColorSelection from @Saiket: http://www.wowinterface.com/forums/showthread.php?t=41521
function Notes.GetTextHighlight( )
	local self = Notes.Notes.Box
	local Text, Cursor = self:GetText(), self:GetCursorPosition();
	self:Insert( "" ); -- Delete selected text
	local TextNew, CursorNew = self:GetText(), self:GetCursorPosition();
	-- Restore previous text
	self:SetText( Text );
	self:SetCursorPosition( Cursor );
	local Start, End = CursorNew, #Text - ( #TextNew - CursorNew );
	self:HighlightText( Start, End );
	return Start, End;
end


local StripColors;
do
	local CursorPosition, CursorDelta;
	--- Callback for gsub to remove unescaped codes.
	local function StripCodeGsub ( Escapes, Code, End )
		if ( #Escapes % 2 == 0 ) then -- Doesn't escape Code
			if ( CursorPosition and CursorPosition >= End - 1 ) then
				CursorDelta = CursorDelta - #Code;
			end
			return Escapes;
		end
	end
	--- Removes a single escape sequence.
	local function StripCode ( Pattern, Text, OldCursor )
		CursorPosition, CursorDelta = OldCursor, 0;
		return Text:gsub( Pattern, StripCodeGsub ), OldCursor and CursorPosition + CursorDelta;
	end
	
	--- Strips Text of all color escape sequences.
	-- @param Cursor  Optional cursor position to keep track of.
	-- @return Stripped text, and the updated cursor position if Cursor was given.
	function StripColors ( Text, Cursor )
		Text, Cursor = StripCode( "(|*)(|c%x%x%x%x%x%x%x%x)()", Text, Cursor );
		return StripCode( "(|*)(|r)()", Text, Cursor );
	end
	
end

local COLOR_END = "|r";
--- Wraps this editbox's selected text with the given color.
function Notes.ColorSelection ( self, ColorCode )
	local Start, End = Notes.GetTextHighlight( self );
	local Text, Cursor = self:GetText(), self:GetCursorPosition();
	if ( Start == End ) then -- Nothing selected
		--Start, End = Cursor, Cursor; -- Wrap around cursor
		return; -- Wrapping the cursor in a color code and hitting backspace crashes the client!
	end
	
	-- Find active color code at the end of the selection
	local ActiveColor;
	if ( End < #Text ) then -- There is text to color after the selection
		local ActiveEnd;
		local CodeEnd, _, Escapes, Color = 0;
		while ( true ) do
			_, CodeEnd, Escapes, Color = Text:find( "(|*)(|c%x%x%x%x%x%x%x%x)", CodeEnd + 1 );
			if ( not CodeEnd or CodeEnd > End ) then
				break;
			end
			if ( #Escapes % 2 == 0 ) then -- Doesn't escape Code
				ActiveColor, ActiveEnd = Color, CodeEnd;
			end
		end
	
		if ( ActiveColor ) then
			-- Check if color gets terminated before selection ends
			CodeEnd = 0;
			while ( true ) do
				_, CodeEnd, Escapes = Text:find( "(|*)|r", CodeEnd + 1 );
				if ( not CodeEnd or CodeEnd > End ) then
					break;
				end
				if ( CodeEnd > ActiveEnd and #Escapes % 2 == 0 ) then -- Terminates ActiveColor
					ActiveColor = nil;
					break;
				end
			end
		end
	end
	
	local Selection = Text:sub( Start + 1, End );
	-- Remove color codes from the selection
	local Replacement, CursorReplacement = StripColors( Selection, Cursor - Start );
	
	self:SetText( ( "" ):join(
		Text:sub( 1, Start ),
		ColorCode, Replacement, COLOR_END,
		ActiveColor or "", Text:sub( End + 1 )
		) );
	
	-- Restore cursor and highlight, adjusting for wrapper text
	Cursor = Start + CursorReplacement;
	if ( CursorReplacement > 0 ) then -- Cursor beyond start of color code
		Cursor = Cursor + #ColorCode;
	end
	if ( CursorReplacement >= #Replacement ) then -- Cursor beyond end of color
		Cursor = Cursor + #COLOR_END;
	end
	self:SetCursorPosition( Cursor );
	-- Highlight selection and wrapper
	self:HighlightText( Start, #ColorCode + ( #Replacement - #Selection ) + #COLOR_END + End );
end



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function Notes.ConfirmBox_Cancel()
	Notes.ConfirmBox:Hide()
end

function Notes.ConfirmBox_Confirm()
	Notes.ConfirmBox:Hide()
	
	if not del_iPos then return end
	DEBUG( "DELETE CONFIRMED; del_iPos="..del_iPos )
	if( del_iPos > 0 and ( #NotesData > 1 ) ) then
		local removednote = table.remove( NotesData, del_iPos )
		removednote = removednote[2]
		
		if string.len( removednote ) > 40 then
			removednote = string.sub( removednote, 1, 40 ) .. "..."
		end
		
		Notes.Notes.pos = Notes.Notes.pos - 1
		Notes.NoteShow( )
		chat( "|cffff0000Deleted|r: '|cff00ffcc"..removednote.."|r'" )
		removednote = nil
	else
		chat( NOTES_ERRORCOLOR.."Couldn't delete note index "..tostring(del_iPos) )
	end
	
	del_iPos = nil
	
end



-- btnConfirm = { string "Text", func "onClick" }  // nil = disabled/hidden
function Notes.SetupConfirm( title, message, btnCancel, btnConfirm )
	Notes.ConfirmBox.Title:SetText( title or "Simply Notes "..NOTES_VERSION )
	Notes.ConfirmBox.Mesg:SetText( message or "..." )	
	
	if btnConfirm then
		Notes.ConfirmBox.Confirm:Show()
		Notes.ConfirmBox.Confirm:SetText( btnConfirm[ 1 ] or "Yes" )
		Notes.ConfirmBox.Confirm:SetScript( "OnClick", btnConfirm[ 2 ] or Notes.ConfirmBox_Confirm )
		Notes.ConfirmBox.Icon:SetTexture( "Interface/DialogFrame/UI-Dialog-Icon-AlertNew" )
	else
	   Notes.ConfirmBox.Confirm:Hide()
	   Notes.ConfirmBox.Icon:SetTexture( "Interface/DialogFrame/UI-Dialog-Icon-AlertOther" )
	end
	
	if not btnCancel then btnCancel = {} end
	Notes.ConfirmBox.Cancel:SetText( btnCancel[ 1 ] or "Close" )
	Notes.ConfirmBox.Cancel:SetScript( "OnClick", btnCancel[ 2 ] or function() Notes.ConfirmBox:Hide() end )

	
	Notes.ConfirmBox:Show()

end

--@ LINKS
local origSetItemRef = SetItemRef;
local origInsertLink = ChatEdit_InsertLink;
local origChatEdit_GetActiveWindow = ChatEdit_GetActiveWindow; --Yeah.. Blizzard Achievement window checks this before calling ChatEdit_InsertLinks......
--@ //LINKS

-- @ void :NoteClicked( void ) ; Edit Focus has begun, override chat functions
function Notes.NoteClicked()
	Notes.Notes.BoxProxy:Show()
	Notes.Notes:SetBackdropBorderColor( 1, 1, 0, NotesPref["BackAlpha"] or 0.88 ) --yellow
	Notes.OverlayLeft:Show()
	Notes.OverlayRight:Show()
	
	--@ LINKS
	if not origInsertLink then origInsertLink = ChatEdit_InsertLink; end	
	ChatEdit_InsertLink = function( link ) 
		Notes.Notes.Box:Insert(" "..link.." ")
	end
	
	if not origSetItemRef then origSetItemRef = SetItemRef; end
	SetItemRef = function( link, text, button )
		if IsShiftKeyDown() or IsControlKeyDown() then 
			Notes.Notes.Box:Insert(" "..text.." ")			
		else
			origSetItemRef( link, text, button )
		end
	end				
	
	if not origChatEdit_GetActiveWindow then origChatEdit_GetActiveWindow = ChatEdit_GetActiveWindow; end
	ChatEdit_GetActiveWindow = function(...) return Notes.Notes.Box; end --might just want to return anthing not nil, dunno..
	--@ //LINKS
	
	if (Notes.Notes.selected) then return end
	--Notes.Notes.Box:HighlightText()
	--Notes.Notes.selected = true
end

-- @ void :NoteUnclicked( void ) ; Edit Focus has ended, restore chat functions
function Notes.NoteUnclicked()
	
	if origSetItemRef then SetItemRef = origSetItemRef; end
	if origInsertLink then ChatEdit_InsertLink = origInsertLink; end
	if origChatEdit_GetActiveWindow then ChatEdit_GetActiveWindow = origChatEdit_GetActiveWindow; end
	Notes.Notes.BoxProxy:Hide()
	Notes.OverlayLeft:Hide()
	Notes.OverlayRight:Hide()
	Notes.Notes:SetBackdropBorderColor( .25, .25, 0, NotesPref["BackAlpha"] or 0.88 )	
end


function Notes.OnEvent( frame, event, ... )
	if (event == "ADDON_LOADED") then
		local addon = ...
		if ( addon:lower() == "notes") then

			if (not NotesData) then 
				NotesData = {} 
				tinsert( NotesData, { NOTES_DEFAULT_NOTE, "New Note" } )
				Notes.Notes.pos = 1
				NotesPref["lastShown"] = 1  
				NotesPrefCS["lastShown"] = 1
			end
			if (not NotesPref) then 
				NotesPref = {}
				NotesPref["Scale"] = 0.9
				PrefSetupFonts() 
				NotesPref["Font"] = 1
				NotesPref["FontSize"] = 13
				NotesPref["Shown"] = 1
				NotesPref["BackAlpha"] = 0.88
				NotesPref["isLocked"] = 0
				NotesPref["RecentColors"] = {}
			end
			
			if not NotesPref["RecentColors"] then NotesPref["RecentColors"] = {} end
			if #NotesPref["RecentColors"] == 0 then
				NotesPref["RecentColors"] = {
					"ffffcc",
					"ffcccc",
					"ccff99",
					"99ffff"
				}
			end
			
			if not NotesPref["lastShown"] then NotesPref["lastShown"] = 1; end
			if not NotesPrefCS["lastShown"] then NotesPrefCS["lastShown"] = NotesPref["lastShown"]; end
			if NotesPref["lastShown"] < 1 or NotesPref["lastShown"] > #NotesData then NotesPref["lastShown"] = 1; end
			if NotesPrefCS["lastShown"] < 1 or NotesPrefCS["lastShown"] > #NotesData then NotesPrefCS["lastShown"] = NotesPref["lastShown"]; end
			
			-- ALWAYS!!!!!, update fonts list... 
			PrefSetupFonts();
			
			if not NotesPref["MiniMapIcon"] then 
				NotesPref["MiniMapIcon"] = {}; 
				NotesPref["MiniMapIcon"]["hide"] = false;
			end
			if NotesPref["MiniMapIcon"]["hide"] == nil then 
				NotesPref["MiniMapIcon"]["hide"] = false; 
			end
			
			
			Notes:CreateLDBLauncher();
						
			return
		end
		addon = nil
		
		Notes.RegisterInsertMenuItem = function( AddonTitle, MenuItem )
				if type(MenuItem) ~= "table" then return false; end
				if not MenuItem["insertFunc"] or not MenuItem["title"] then
					chat( "|cffff1111An insert menuitem for " .. AddonTitle .. " is malformed, refusing to register...|r" )
					return false;
				end
				if not Notes.AddonInsertMenuItems[ AddonTitle ] then
					Notes.AddonInsertMenuItems[ AddonTitle ] = {};
				end
				table.insert( Notes.AddonInsertMenuItems[ AddonTitle ], MenuItem );
				table.sort( Notes.AddonInsertMenuItems );
				
			end
			
		Notes.UnRegisterInsertMenuItem = function( AddonTitle, MenuItemIndex )
				if type(MenuItemIndex) ~= "number" then return false; end
				if not Notes.AddonInsertMenuItems[ AddonTitle ] then
					return true;
				end

				if Notes.AddonInsertMenuItems[AddonTitle][MenuItemIndex] then
					return table.remove( Notes.AddonInsertMenuItems[AddonTitle], MenuItemIndex ) and true or false;
				else
					return false;
				end

			end
		
		
	elseif (event == "PLAYER_LOGIN") then


		Notes.UpdateFrameStratas( NotesPref["Strata"] or "High" );

		local cache_NotesPrefShown = NotesPref["Shown"] or 1
		Notes.NoteShow( NotesPrefCS["lastShown"] or NotesPref["lastShown"] or 1 )
		Notes.Notes:SetScale( NotesPref["Scale"] or 0.9 )
		
		chat( NOTES_LOADMSG )
		chat( NOTES_LOGINMSG )
				
		
		local fonts = NotesPref["Fonts"]
		local fontsize = tonumber( NotesPref["FontSize"] )
		local fontchoice = tonumber( NotesPref["Font"] )
		if ( not fonts or #fonts == 0 ) then PrefSetupFonts() NotesPref["Font"] = 1 fontchoice = 1 end
		if not fonts[ fontchoice ] then NotesPref["Font"] = 1 fontchoice = 1 end
		if not fontsize or fontsize < 7 or fontsize > 40 then fontsize = 13 NotesPref["FontSize"] = 13 end
		
		if not Notes.Notes.Box:SetFont( NOTES_FONT_PATH..fonts[ fontchoice ], fontsize ) then
			--try with out addon path
			Notes.Notes.Box:SetFont( fonts[ fontchoice ], fontsize )
		end
		
		--chat( "Font: |cff00ccff"..fonts[ fontchoice ].."|r (font "..fontchoice.."), size: |cff00ccff"..fontsize.."|r" )
		fonts = nil
		fontsize = nil
		fontchoice = nil
		
		Notes.Notes.Box:SetWidth( Notes.Notes.Scroll:GetWidth() )
		
		-- Added later to pref, if NotesPref["Shown"] = 0 || nil, hide
		
		if cache_NotesPrefShown == 0 or not cache_NotesPrefShown then Notes.Notes:Hide() end
		NotesPref["Shown"] = cache_NotesPrefShown
		cache_NotesPrefShown = nil
		
		
		NotesPref["BackAlpha"] = NotesPref["BackAlpha"] or 0.88
		--Notes.Notes:SetAlpha( NotesPref["BackAlpha"] or 1 ) --instead, change backdrop and border..
		local red, green, blue, alpha = Notes.Notes:GetBackdropColor()
		Notes.Notes:SetBackdropColor( red, green, blue, NotesPref["BackAlpha"] )
		red, green, blue, alpha = Notes.Notes:GetBackdropBorderColor()
		Notes.Notes:SetBackdropBorderColor( red, green, blue, NotesPref["BackAlpha"] )
		
		
		local chatmsg = ""
		
		alpha = NotesPref["BackAlpha"] * 100
		if alpha ~= 100 then
			chatmsg = "Background Alpha: |cff00ccff"..alpha.."%|r"
		end
		alpha = nil
		
		local scale = NotesPref["Scale"] * 100
		if scale ~= 100 then
			if string.len( chatmsg ) > 1 then chatmsg = chatmsg.." - " end
			chatmsg = chatmsg.."Window Scale: |cff00ccff"..scale.."%|r"
		end
		scale = nil
		
		--chat( chatmsg )
		chatmsg = nil
		
		if not NotesPref["Shown"] or NotesPref["Shown"] == 0 then
			chat( "Notes is hidden, type |cffffcc00'/notes show'|r to show notes!" )   
		end
		
		
		if not NotesPref["isLocked"] then NotesPref["isLocked"] = 0 end
		Notes.NoteLock( nil, nil, NotesPref["isLocked"] ) -- lock or unlock
		
		if NotesPref["MiniMapIcon"] and NotesPref["MiniMapIcon"]["hide"] and NotesPref["MiniMapIcon"]["hide"] == true then
		--	if LDBIcon then
		--		LDBIcon:Hide( 'Simply Notes' );
		--	else
				NotesMapIcon:Hide( );
		--	end
		end
		
		if NotesPref["ManualSave"] then
			Notes.Notes.SaveIcon:Show();
		else
			Notes.Notes.SaveIcon:Hide();
		end
		
		
		
		if Notes.temp_PLAYER_LOGIN then Notes.temp_PLAYER_LOGIN(); end
		-- The following message will likely not always be accurate, since
		-- registering addons would be registering their menu items in the same event,
		-- if their event function is called after this one in Simply Notes, the following message
		-- wouldn't include that Addon name... It's just a message though, not a big dead...
		local k, v = nil;
		local szAddons, cnt = "", 0;
		for k, v in pairs(Notes.AddonInsertMenuItems) do
			szAddons = szAddons .. ( szAddons ~= "" and ", " or "" ) .. k;
			cnt = cnt + 1;
		end
		if cnt > 0 then
			--chat( "|cff00ff00Registered:|r |cffffff00" .. szAddons .. "|r as" .. ( cnt > 1 and "" or " an" ) .. " Insert Menuitem addon" .. ( cnt > 1 and "s" or "" ) .. "..."  )
		end
		
		
		
		
	elseif (event == "PLAYER_ENTERING_WORLD") then
		
		Notes.Frame:UnregisterEvent( "PLAYER_ENTERING_WORLD" )
	
	
	elseif( event == "PLAYER_REGEN_DISABLED" ) then -- Entered Combat
		Notes.NoteLock( nil, nil, 1, true )
		Notes.inCombat = 1;
	
	elseif( event == "PLAYER_REGEN_ENABLED" ) then -- Left Combat
		Notes.NoteLock( nil, nil, NotesPref["isLocked"] or 0, true )
		Notes.inCombat = nill;
	--
	elseif event == "MAIL_SHOW" then -- We'll use this to assume the player wants to remove focus from notes
		if Notes.Notes.Box:HasFocus() then Notes.Notes.Box:ClearFocus() end
		

	end
	
end


--[[
==================================================================================
================================== FRAMES ========================================
==================================================================================
]]
Notes.Notes = CreateFrame( "Frame", "NotesFrame", UIParent )
Notes.Notes:Hide( )
Notes.Notes:SetPoint( "CENTER", "UIParent", "CENTER" )
Notes.Notes:SetFrameStrata( NOTES_STRATA )
Notes.Notes:SetHeight( 350 )
Notes.Notes:SetWidth( 500 )
Notes.Notes:SetBackdrop({
		bgFile = "Interface/Tooltips/ChatBubble-Background",
		edgeFile = "Interface/Tooltips/ChatBubble-BackDrop",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 32, right = 32, top = 32, bottom = 32 }
	})
Notes.Notes:SetBackdropColor( 0, 0, 0, 1 )
Notes.Notes:SetBackdropBorderColor( .25, .25, 0, 1 )
Notes.Notes:SetScript( "OnShow", Notes.NoteShow )
Notes.Notes:SetScript( "OnMouseDown", function() Notes.Notes.Box:SetFocus() end )
Notes.Notes:SetMovable( true )
Notes.Notes:SetResizable( true )
Notes.Notes:SetMinResize( 368, 100 )
Notes.Notes:SetClampedToScreen( true )
Notes.Notes.RealShow = Notes.Notes.Show
Notes.Notes.RealHide = Notes.Notes.Hide
Notes.Notes.pos = 1
function Notes.Notes:Show(...)
	Notes.Notes.isShown = true
	Notes.Notes:RealShow(...)
end
function Notes.Notes:Hide(...)
	Notes.Notes.isShown = nil
	NotesPref["lastShown"] = Notes.Notes.pos
	NotesPrefCS["lastShown"] = Notes.Notes.pos
	Notes.Notes:RealHide(...)
end


Notes.Notes:SetScript( "OnUpdate", function()
		if not Notes.Notes.Box:HasFocus() or not Notes.Notes.Box.mouseisdown or Notes.Notes.Scroll:IsMouseOver() then return; end
		local _, cursorY = GetCursorPosition();
		local directiondown = cursorY < Notes.Notes.Box.mouseisdownY; --sigh, fucking 0,0 starts at bottom left...
		--print( "cy"..cursorY, "mousedowny: " .. Notes.Notes.Box.mouseisdownY );
		local scroll, maxScroll = floor(Notes.Notes.Scroll:GetVerticalScroll()), floor(Notes.Notes.Scroll:GetVerticalScrollRange());
		if directiondown then
			Notes.Notes.Scroll:SetVerticalScroll( ( scroll + 10 <= maxScroll ) and ( scroll + 10 ) or maxScroll )
		else
			Notes.Notes.Scroll:SetVerticalScroll( ( scroll - 10 > 0 ) and ( scroll - 10 ) or 0 )
		end
	end);


Notes.OverlayLeft = Notes.Notes:CreateTexture( "NotesOverlayLeft", "ARTWORK" )
Notes.OverlayLeft:SetWidth( 64 )
Notes.OverlayLeft:SetHeight( 128 )
Notes.OverlayLeft:SetAlpha( 0.3 )
Notes.OverlayLeft:SetTexture( NOTES_ART_PATH.."overlay-left" )
Notes.OverlayLeft:SetPoint( "LEFT", Notes.Notes, "LEFT", -64, 0 )
Notes.OverlayLeft:SetPoint( "TOP", Notes.Notes, "TOP" )
Notes.OverlayLeft:SetPoint( "BOTTOM", Notes.Notes, "BOTTOM" )
Notes.OverlayLeft:Hide()


Notes.OverlayRight = Notes.Notes:CreateTexture( "NotesOverlayRight", "ARTWORK" )
Notes.OverlayRight:SetWidth( 64 )
Notes.OverlayRight:SetHeight( 128 )
Notes.OverlayRight:SetAlpha( 0.3 )
Notes.OverlayRight:SetTexture( NOTES_ART_PATH.."overlay-right" )
Notes.OverlayRight:SetPoint( "RIGHT", Notes.Notes, "RIGHT", 64, 0 )
Notes.OverlayRight:SetPoint( "TOP", Notes.Notes, "TOP" )
Notes.OverlayRight:SetPoint( "BOTTOM", Notes.Notes, "BOTTOM" )
Notes.OverlayRight:Hide()




Notes.Drag = CreateFrame( "Button", nil, Notes.Notes )
Notes.Drag:SetPoint( "TOPLEFT", Notes.Notes, "TOPLEFT", 10, -5 )
Notes.Drag:SetPoint( "TOPRIGHT", Notes.Notes, "TOPRIGHT", -10, -5 )
Notes.Drag:SetHeight( 24 )
Notes.Drag:SetNormalTexture( NOTES_ART_PATH.."bar" ) 
Notes.Drag:SetHighlightTexture( "Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar" ) -- -Blue
--Notes.Drag:SetAlpha( 0.5 )
Notes.Drag:RegisterForClicks( "LeftButtonUp", "RightButtonUp" )
Notes.Drag:SetScript( "OnMouseDown", function( self, button ) if button == "LeftButton" then Notes.Notes:StartMoving() end end )
Notes.Drag:SetScript( "OnMouseUp", function( self, button ) if button == "LeftButton" then Notes.Notes:StopMovingOrSizing() end end )
Notes.Drag.initMenuFunc = Notes.GeneralContextMenu;
Notes.Drag:SetScript( "OnClick", function( frame, button, down ) 
		if button == "RightButton" then	
			--Notes.DropDownMenu.OnClick( self, button, down )
			if Notes.DropDownMenu.initialize ~= frame.initMenuFunc then
				CloseDropDownMenus()
				Notes.DropDownMenu.initialize = frame.initMenuFunc
			end
			ToggleDropDownMenu(1, nil, Notes.DropDownMenu, "cursor", 0, 0)
		end
	end )


Notes.Title = Notes.Drag:CreateFontString( "", "OVERLAY" )
Notes.Title:SetFont( NOTES_FONT_PATH..NotesPref["Fonts"][ 1 ], 15 )
Notes.Title:SetJustifyH( "CENTER" )
--Notes.Title:SetAllPoints( Notes.Drag )
Notes.Title:SetPoint( "TOPLEFT", Notes.Drag, "TOPLEFT", 0, 1 )
Notes.Title:SetPoint( "TOPRIGHT", Notes.Drag, "TOPRIGHT", 0, -1 )
Notes.Title:SetPoint( "BOTTOM", Notes.Drag, "BOTTOM", 0, 0 )
Notes.Title:SetShadowColor( .2, .2, .2, 0.9)
Notes.Title:SetShadowOffset( -1, -1 )
Notes.Title:SetTextColor( 1, 1, 1, 1) 
Notes.Title:SetText( "Simply Notes" )



Notes.Notes.Done = CreateFrame( "Button", "", Notes.Notes )
--Notes.Notes.Done:SetText( "Close" )
Notes.Notes.Done:SetNormalTexture( NOTES_ART_PATH.."icon-hide")
Notes.Notes.Done:SetHighlightTexture( NOTES_ART_PATH.."icon-overlay" )
Notes.Notes.Done:SetPoint( "BOTTOMRIGHT", Notes.Notes, "BOTTOMRIGHT", -18, 10 )
Notes.Notes.Done:SetWidth( 25 )
Notes.Notes.Done:SetHeight( 25 )
Notes.Notes.Done:SetScript( "OnClick", Notes.NoteDone )
Notes.Notes.Done:SetScript( "OnEnter", function( self ) 
	GameTooltip:SetOwner( self, "BOTTOMRIGHT")
	GameTooltip:SetText( "Close" )
	GameTooltip:Show()
end )
Notes.Notes.Done:SetScript( "OnLeave", function( self ) GameTooltip:Hide()  end )


Notes.Notes.Delete = CreateFrame( "Button", "", Notes.Notes )
--Notes.Notes.Delete:SetText( "Del" )
Notes.Notes.Delete:SetNormalTexture( NOTES_ART_PATH.."icon-delete")
Notes.Notes.Delete:SetHighlightTexture( NOTES_ART_PATH.."icon-overlay" )
Notes.Notes.Delete:SetDisabledTexture( NOTES_ART_PATH.."icon-delete-disabled" )                                                                      
Notes.Notes.Delete:SetPoint( "BOTTOMRIGHT", Notes.Notes.Done, "BOTTOMLEFT", -NOTES_BUTTON_SPACING, 0 )
Notes.Notes.Delete:SetWidth( 25 )
Notes.Notes.Delete:SetHeight( 25 )
Notes.Notes.Delete:SetScript( "OnClick", Notes.NoteDelete )
Notes.Notes.Delete:SetScript( "OnEnter", function( self ) 
	GameTooltip:SetOwner( self, "BOTTOMRIGHT")
	GameTooltip:SetText( "Delete Note" )
	GameTooltip:Show()
end )
Notes.Notes.Delete:SetScript( "OnLeave", function( self ) GameTooltip:Hide()  end )


Notes.Notes.NewNote = CreateFrame( "Button", "", Notes.Notes )
Notes.Notes.NewNote:SetNormalTexture( NOTES_ART_PATH.."icon-add")
Notes.Notes.NewNote:SetHighlightTexture( NOTES_ART_PATH.."icon-overlay" )
Notes.Notes.NewNote:SetPoint( "BOTTOMRIGHT", Notes.Notes.Delete, "BOTTOMLEFT", -NOTES_BUTTON_SPACING, 0 )
Notes.Notes.NewNote:SetWidth( 25 )
Notes.Notes.NewNote:SetHeight( 25 )
Notes.Notes.NewNote:RegisterForClicks( "LeftButtonUp", "RightButtonUp" )
Notes.Notes.NewNote:SetScript( "OnClick", Notes.CreateNote )
Notes.Notes.NewNote:SetScript( "OnEnter", function( self ) 
	GameTooltip:SetOwner( self, "BOTTOMRIGHT")
	GameTooltip:SetText( "New Note" )
	GameTooltip:AddLine( "Left Click: Add Note (#".. (#NotesData + 1)..")" )
	if Notes.Notes.pos < #NotesData then
		GameTooltip:AddLine( "Right Click: Insert Note here (#".. (Notes.Notes.pos + 1) ..")" )
	end
	GameTooltip:Show()
end )
Notes.Notes.NewNote:SetScript( "OnLeave", function( self ) GameTooltip:Hide()  end )


Notes.Notes.Next = CreateFrame( "Button", "", Notes.Notes )
--Notes.Notes.Next:SetText( "Next >" )
Notes.Notes.Next:SetNormalTexture( NOTES_ART_PATH.."icon-next")
Notes.Notes.Next:SetHighlightTexture( NOTES_ART_PATH.."icon-overlay" )
Notes.Notes.Next:SetPoint( "BOTTOMRIGHT", Notes.Notes.NewNote, "BOTTOMLEFT", -4, 0 )
Notes.Notes.Next:SetWidth( 25 )
Notes.Notes.Next:SetHeight( 25 )
Notes.Notes.Next:SetScript( "OnClick", Notes.NoteNext)
Notes.Notes.Next:SetScript( "OnEnter", function( self ) 
	GameTooltip:SetOwner( self, "BOTTOMRIGHT")
	GameTooltip:SetText( "Next Note" )
	GameTooltip:Show()
end )
Notes.Notes.Next:SetScript( "OnLeave", function( self ) GameTooltip:Hide()  end )

Notes.Notes.Prev = CreateFrame( "Button", "", Notes.Notes )
--Notes.Notes.Prev:SetText("< Prev")
Notes.Notes.Prev:SetNormalTexture( NOTES_ART_PATH.."icon-prev")
Notes.Notes.Prev:SetHighlightTexture( NOTES_ART_PATH.."icon-overlay" )
Notes.Notes.Prev:SetDisabledTexture( NOTES_ART_PATH.."icon-prev-disabled" ) 
Notes.Notes.Prev:SetPoint( "BOTTOMRIGHT", Notes.Notes.Next, "BOTTOMLEFT", -4, 0 )
Notes.Notes.Prev:SetWidth( 25 )
Notes.Notes.Prev:SetHeight( 25 )
Notes.Notes.Prev:SetScript( "OnClick", Notes.NotePrev )
Notes.Notes.Prev:SetScript( "OnEnter", function( self ) 
	GameTooltip:SetOwner( self, "BOTTOMRIGHT")
	GameTooltip:SetText( "Previous Note" )
	GameTooltip:Show()
end )
Notes.Notes.Prev:SetScript( "OnLeave", function( self ) GameTooltip:Hide()  end )


Notes.Notes.Color = CreateFrame( "Button", "", Notes.Notes )
Notes.Notes.Color:SetNormalTexture( NOTES_ART_PATH.."icon-swatch")
Notes.Notes.Color:SetHighlightTexture( NOTES_ART_PATH.."icon-overlay" )
Notes.Notes.Color:SetDisabledTexture( NOTES_ART_PATH.."icon-swatch-disabled" ) 
Notes.Notes.Color:SetPoint( "BOTTOMRIGHT", Notes.Notes.Prev, "BOTTOMLEFT", -NOTES_BUTTON_SPACING, 0 )
Notes.Notes.Color:SetWidth( 25 )
Notes.Notes.Color:SetHeight( 25 )
Notes.Notes.Color:SetScript( "OnClick", Notes.ColorClicked )
Notes.Notes.Color:SetScript( "OnEnter", function( self ) 
	GameTooltip:SetOwner( self, "BOTTOMRIGHT")
	GameTooltip:SetText( "Colorize" )
	GameTooltip:Show()
end )
Notes.Notes.Color:SetScript( "OnLeave", function( self ) GameTooltip:Hide()  end )




Notes.Notes.Lock = CreateFrame( "Button", "", Notes.Notes )
--Notes.Notes.Lock:SetText("Lock")
Notes.Notes.Lock:SetNormalTexture( NOTES_ART_PATH.."icon-unlocked")
Notes.Notes.Lock:SetHighlightTexture( NOTES_ART_PATH.."icon-overlay" )
Notes.Notes.Lock:SetPoint( "BOTTOMRIGHT", Notes.Notes.Color, "BOTTOMLEFT", -NOTES_BUTTON_SPACING, 0 )
Notes.Notes.Lock:SetWidth( 25 )
Notes.Notes.Lock:SetHeight( 25 )
Notes.Notes.Lock:SetScript( "OnClick", Notes.NoteLock )
Notes.Notes.Lock:SetScript( "OnEnter", function( self ) 
	GameTooltip:SetOwner( self, "BOTTOMRIGHT")
	
	if NotesPref["isLocked"] == 1 then
		GameTooltip:SetText( "Lock" )
		GameTooltip:AddLine( "Read Only mode: |cffff0000On|r", 1.0, 1.0, 1.0, 1.0)
	else
	   GameTooltip:SetText( "UnLock" )
		GameTooltip:AddLine( "Read Only mode: Off", 1.0, 1.0, 1.0, 1.0)
	end
	GameTooltip:Show()
end )
Notes.Notes.Lock:SetScript( "OnLeave", function( self ) GameTooltip:Hide()  end )





Notes.Notes.SearchIcon = CreateFrame( "Button", "", Notes.Notes )
Notes.Notes.SearchIcon:SetNormalTexture( NOTES_ART_PATH.."icon-search")
Notes.Notes.SearchIcon:SetHighlightTexture( NOTES_ART_PATH.."icon-overlay" )
Notes.Notes.SearchIcon:SetPoint( "BOTTOMRIGHT", Notes.Notes.Lock, "BOTTOMLEFT", -NOTES_BUTTON_SPACING, 0 )
Notes.Notes.SearchIcon:SetWidth( 25 )
Notes.Notes.SearchIcon:SetHeight( 25 )
Notes.Notes.SearchIcon:SetScript( "OnClick", function()
	
		Notes.Notes.SearchFrame:Show();

	end)
Notes.Notes.SearchIcon:SetScript( "OnEnter", function( self ) 
	GameTooltip:SetOwner( self, "BOTTOMRIGHT")
	GameTooltip:SetText( "Search (Ctrl+F)" )
	GameTooltip:Show()
end )
Notes.Notes.SearchIcon:SetScript( "OnLeave", function( self ) GameTooltip:Hide()  end )






Notes.Notes.CommIcon = CreateFrame( "Button", "", Notes.Notes )
Notes.Notes.CommIcon:SetNormalTexture( NOTES_ART_PATH.."icon-communicate")
Notes.Notes.CommIcon:SetHighlightTexture( NOTES_ART_PATH.."icon-overlay" )
Notes.Notes.CommIcon:SetPoint( "BOTTOMRIGHT", Notes.Notes.SearchIcon, "BOTTOMLEFT", -NOTES_BUTTON_SPACING, 0 )
Notes.Notes.CommIcon:SetWidth( 25 )
Notes.Notes.CommIcon:SetHeight( 25 )
Notes.Notes.CommIcon:SetScript( "OnClick", function()
	
		Notes.Notes.CommOutFrame:Show();

	end)
Notes.Notes.CommIcon:SetScript( "OnEnter", function( self ) 
	GameTooltip:SetOwner( self, "BOTTOMRIGHT")
	GameTooltip:SetText( "Send note to a friend" )
	GameTooltip:Show()
end )
Notes.Notes.CommIcon:SetScript( "OnLeave", function( self ) GameTooltip:Hide()  end )





Notes.Notes.SaveIcon = CreateFrame( "Button", "", Notes.Notes )
Notes.Notes.SaveIcon:SetNormalTexture( NOTES_ART_PATH.."icon-save")
Notes.Notes.SaveIcon:SetDisabledTexture( NOTES_ART_PATH.."icon-save-disabled" ) 
Notes.Notes.SaveIcon:SetHighlightTexture( NOTES_ART_PATH.."icon-overlay" )
Notes.Notes.SaveIcon:SetPoint( "BOTTOMRIGHT", Notes.Notes.CommIcon, "BOTTOMLEFT", -NOTES_BUTTON_SPACING, 0 )
Notes.Notes.SaveIcon:SetWidth( 25 )
Notes.Notes.SaveIcon:SetHeight( 25 )
Notes.Notes.SaveIcon:SetScript( "OnClick", function() Notes.NoteSave( true );	end)
Notes.Notes.SaveIcon:SetScript( "OnEnter", function( self ) 
	GameTooltip:SetOwner( self, "BOTTOMRIGHT")
	GameTooltip:SetText( "Save note (Ctrl+S)" )
	GameTooltip:Show()
end )
Notes.Notes.SaveIcon:SetScript( "OnLeave", function( self ) GameTooltip:Hide()  end )







Notes.Notes.DragBottomLeft = CreateFrame("Button", "NotesResizeGripLeft", Notes.Notes ) -- Grip Buttons from Omen2/Recount
Notes.Notes.DragBottomLeft:Show()
Notes.Notes.DragBottomLeft:SetFrameLevel( Notes.Notes:GetFrameLevel() + 10)
Notes.Notes.DragBottomLeft:SetNormalTexture( NOTES_ART_PATH.."ResizeGripLeft" )
Notes.Notes.DragBottomLeft:SetHighlightTexture( NOTES_ART_PATH.."ResizeGripLeft" )
Notes.Notes.DragBottomLeft:SetWidth(16)
Notes.Notes.DragBottomLeft:SetHeight(16)
Notes.Notes.DragBottomLeft:SetPoint("BOTTOMLEFT", Notes.Notes, "BOTTOMLEFT", 0, 0)
Notes.Notes.DragBottomLeft:EnableMouse(true)
Notes.Notes.DragBottomLeft:SetScript("OnMouseDown", function(self,button) 
	if button == "LeftButton" then 
		Notes.Notes.isResizing = true; 
		Notes.Notes:StartSizing("BOTTOMLEFT") 
	end 
end )
Notes.Notes.DragBottomLeft:SetScript("OnMouseUp", function(self,button) 
	if Notes.Notes.isResizing == true then 
		Notes.Notes:StopMovingOrSizing(); 
		Notes.Notes.isResizing = false; 
		Notes.Notes.Box:SetWidth( Notes.Notes.Scroll:GetWidth() )
	end 
end )


Notes.Notes.DragBottomRight = CreateFrame("Button", "NotesResizeGripRight", Notes.Notes ) -- Grip Buttons from Omen2/Recount
Notes.Notes.DragBottomRight:Show()
Notes.Notes.DragBottomRight:SetFrameLevel( Notes.Notes:GetFrameLevel() + 10)
Notes.Notes.DragBottomRight:SetNormalTexture( NOTES_ART_PATH.."ResizeGripRight" )
Notes.Notes.DragBottomRight:SetHighlightTexture( NOTES_ART_PATH.."ResizeGripRight" )
Notes.Notes.DragBottomRight:SetWidth(16)
Notes.Notes.DragBottomRight:SetHeight(16)
Notes.Notes.DragBottomRight:SetPoint("BOTTOMRIGHT", Notes.Notes, "BOTTOMRIGHT", 0, 0)
Notes.Notes.DragBottomRight:EnableMouse(true)
Notes.Notes.DragBottomRight:SetScript("OnMouseDown", function(self,button) 
	if button == "LeftButton" then 
		Notes.Notes.isResizing = true; 
		Notes.Notes:StartSizing("BOTTOMRIGHT") 
	end 
end )
Notes.Notes.DragBottomRight:SetScript("OnMouseUp", function(self,button) 
	if Notes.Notes.isResizing == true then 
		Notes.Notes:StopMovingOrSizing(); 
		Notes.Notes.isResizing = false; 
		Notes.Notes.Box:SetWidth( Notes.Notes.Scroll:GetWidth() )
	end 
end )






Notes.Notes.Mesg = Notes.Notes:CreateFontString( "", "OVERLAY", "GameFontNormalSmall" )
Notes.Notes.Mesg:SetJustifyH( "LEFT" )
Notes.Notes.Mesg:SetPoint( "TOPRIGHT", Notes.Notes.Prev, "TOPLEFT", -10, -3 )
Notes.Notes.Mesg:SetPoint( "LEFT", Notes.Notes, "LEFT", 45, 0 )
Notes.Notes.Mesg:SetHeight( 29 )
Notes.Notes.Mesg:SetText( " " )

Notes.Notes.NoteNavigation = CreateFrame( "Button", "", Notes.Notes )
Notes.Notes.NoteNavigation:SetNormalTexture( "Interface/FriendsFrame/UI-FriendsList-Large-Up" )
Notes.Notes.NoteNavigation:SetPushedTexture( "Interface/FriendsFrame/UI-FriendsList-Large-Down" )
Notes.Notes.NoteNavigation:SetHighlightTexture( "Interface/FriendsFrame/UI-FriendsList-Highlight" )
Notes.Notes.NoteNavigation:SetPoint( "TOPRIGHT", Notes.Notes.Mesg, "TOPLEFT", -2, -2 )
Notes.Notes.NoteNavigation:SetWidth( 25 )
Notes.Notes.NoteNavigation:SetHeight( 25 )
--Notes.Notes.NoteNavigation:SetScript( "OnClick", Notes.NoteNavDropDown )


Notes.Notes.Scroll = CreateFrame( "ScrollFrame", "NotesInputScroll", Notes.Notes, "UIPanelScrollFrameTemplate" )
Notes.Notes.Scroll:SetPoint( "TOPLEFT", Notes.Drag, "BOTTOMLEFT", 6, -8 )
Notes.Notes.Scroll:SetPoint( "RIGHT", Notes.Notes, "RIGHT", -30, 0 )
Notes.Notes.Scroll:SetPoint( "BOTTOM", Notes.Notes.Done, "TOP", 0, 10 )
Notes.Notes.Scroll:EnableMouse( true );
Notes.Notes.Scroll:SetScript( "OnMouseDown", function() Notes.Notes.Box:SetFocus() end )

Notes.Notes.Box = CreateFrame( "EditBox", "NotesEditBox", Notes.Notes.Scroll )
Notes.Notes.Box:SetWidth( Notes.Notes.Scroll:GetWidth() )
Notes.Notes.Box:SetHeight( 85 )
Notes.Notes.Box:SetMultiLine( true )
Notes.Notes.Box:SetAutoFocus( false )
Notes.Notes.Box:SetFontObject( GameFontHighlight )
Notes.Notes.Box:SetShadowColor( 0, 0, 0, .6 )
Notes.Notes.Box:SetShadowOffset( 1, -1 )
Notes.Notes.Box:SetScript( "OnEscapePressed", function(...) Notes.Notes.Box:ClearFocus() end ) --Notes.NoteDone )
Notes.Notes.Box:SetScript( "OnTextChanged", function(...) Notes.NoteSave() end )
Notes.Notes.Box:SetScript( "OnEditFocusGained", Notes.NoteClicked )
Notes.Notes.Box:SetScript( "OnEditFocusLost", Notes.NoteUnclicked )
Notes.Notes.Box:SetScript( "OnMouseDown", function() 
		Notes.Notes.Box.mouseisdown = true; 
		local _ = nil;
		_, Notes.Notes.Box.mouseisdownY = GetCursorPosition(); 
	end );
Notes.Notes.Box:SetScript( "OnMouseUp", function( frame, button ) 
		Notes.Notes.Box.mouseisdown = nil; 
	end );

Notes.Notes.Box:SetHyperlinksEnabled( true )
Notes.Notes.Box:SetScript( "OnHyperlinkClick", function( self, linkData, link, button ) 
		--chat(linkData);	
		--chat(link);	
			
		if( IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() ) then
			--attempt to insert link into chat edit box...
			ChatEdit_InsertLink( link )
		else
			-- Show a tooltip, I guess?
			-- apparently this doesn't work for player links..??
			if not linkData.match( linkData, "player:" ) then
				SetItemRef( linkData, link, button, self );
			end
		end
	
	end)



if not Notes.Notes.Box:SetFont( NOTES_FONT_PATH..NotesPref["Fonts"][ NotesPref["Font"] ], NotesPref["FontSize"] )  then
	--try with out addon path
	Notes.Notes.Box:SetFont( NotesPref["Fonts"][ NotesPref["Font"] ], NotesPref["FontSize"] ) 
end

Notes.Notes.Scroll:SetScrollChild( Notes.Notes.Box )


--[[
==================================================================================
================================== HOOKS =========================================
==================================================================================
]]

--[[
--@ I'm just hooking the Chat Edit box Focus/LostFocus so that I can make Notes EditBox not edible when it has focus, so a user can select text with out
--  causing focus to be lost to the Chat Editbox
local function hook_ChatEdit_OnEditFocusGained(...)
	
end
local function hook_ChatEdit_OnEditFocusLost(...)
  
end
hooksecurefunc( "ChatEdit_OnEditFocusGained", hook_ChatEdit_OnEditFocusGained )
hooksecurefunc( "ChatEdit_OnEditFocusLost", hook_ChatEdit_OnEditFocusLost )
]]


-- Proxy frame is to intercept "Ctrl+Z/Y" - probably a better way of doing this...
-- This is somewhat experimental, but seems to be working.. With EnableKeyboard(true) and Propagation to the next frame(the edit box)
-- i can detect the "Ctrl" key pressed at the same time as z, the frame is hidden when the edit box loses focus - the onKeyDown event no longer fires
Notes.Notes.BoxProxy = CreateFrame( "Frame", "NotesBoxProxy", UIParent )
Notes.Notes.BoxProxy:Hide( )
Notes.Notes.BoxProxy:SetFrameStrata( "TOOLTIP" )
Notes.Notes.BoxProxy:EnableKeyboard( true )
Notes.Notes.BoxProxy:SetPropagateKeyboardInput( true )
Notes.Notes.BoxProxy:SetScript( "OnKeyDown", Notes.OnKeyDown )


--	@OpenMailFrame
----------------------------------------------------------------------
Notes.InsertMailNote = CreateFrame( "Button", "InsertNoteFromMail", OpenMailFrame ); --, "OptionsButtonTemplate")
Notes.InsertMailNote:SetWidth( 20 )
Notes.InsertMailNote:SetHeight( 20 )
Notes.InsertMailNote:SetAlpha(0.7)
Notes.InsertMailNote:SetNormalTexture( NOTES_ART_PATH.."icons" )
Notes.InsertMailNote:SetHighlightTexture( NOTES_ART_PATH.."icons" )
Notes.InsertMailNote:Show()
Notes.InsertMailNote:RegisterForClicks( "LeftButtonUp", "RightButtonUp" )
do
	local texture = Notes.InsertMailNote:GetNormalTexture( )
	texture:SetTexCoord( 0, 1, 0, 0.25 ) 
		
	texture = Notes.InsertMailNote:GetHighlightTexture( )
	texture:SetTexCoord( 0, 1, 0.5, 0.75 ) 
end

Notes.InsertMailNote:SetPoint( "TOP", OpenMailFrame, "TOP", 0, -95 ) --
Notes.InsertMailNote:SetPoint( "RIGHT", OpenMailFrame, "RIGHT", -78, 0 )
Notes.InsertMailNote:SetScript( "OnClick", function( self, button ) 
		if( InboxFrame.openMailID > 0 ) then
			local bodyText, texture, isTakeable, isInvoice = GetInboxText( InboxFrame.openMailID );
			local packageIcon, stationeryIcon, sender, subject, money, CODAmount, 
				daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity = GetInboxHeaderInfo( InboxFrame.openMailID );
								
			local msg = "";
			if( not isInvoice ) then
				--if button == "RightButton" then
					msg = string.format( "|cffffcc99From:|r %s\n|cffffcc99Subject:|r %s\n|cffffcc99Message:|r\n\n%s", sender, subject, bodyText or "" )
				--[[elseif( button == "LeftButton" ) then
					msg = string.format( "\n|cffffcc99%s|r: %s\n", sender, bodyText or ""  );
				end]]
			else
				
				-- This is formatting mostly from @Source: WoW AddOn: Postal, it looks OKAY
				if isInvoice then
					local invoiceType, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo( InboxFrame.openMailID )
					if playerName then
						if invoiceType == "buyer" then
							msg = subject.."\r\n|cffffcc99Item:|r "..itemName
							if bid == buyout then
								msg = msg.." (Buyout)\r\n"
							else
								msg = msg.." (High Bidder)\r\n"
							end
							msg = msg.."|cffffcc99Seller:|r "..playerName.."\r\n"
								.."----------------------------------------\r\n"
								.."Amount paid: "..self:GetMoneyStringPlain(bid)
						elseif invoiceType == "seller" then
							msg = subject.."\r\n|cffffcc99Item sold:|r "..itemName.."\r\n"
							.."|cffffcc99Purchased by:|r "..playerName
							if bid == buyout then
								msg = msg.." (Buyout)\r\n\r\n"
							else
								msg = msg.." (High Bidder)\r\n\r\n"
							end
							msg = msg.."|cffffcc99Sale price:|r "..self:GetMoneyStringPlain(bid).."\r\n"
								.."|cffffcc99Deposit:|r "..self:GetMoneyStringPlain(deposit).."\r\n"
								.."|cffffcc99Auction House cut:|r "..self:GetMoneyStringPlain(consignment).."\r\n"
								.."----------------------------------------\r\n"
								.."Amount Recieved: "..self:GetMoneyStringPlain(bid+deposit-consignment)
						end
					end
				end
				
				
			end

			if button == "RightButton" then
				Notes.Notes:Show();
				Notes.NoteNew( msg );
			elseif( button == "LeftButton" ) then
				Notes.Notes:Show();
				Notes.NoteInsertText( msg, true ); --"Name: Body"
				chat( "Inserted the mail text at the end of your current note...." );
				Notes.Notes.Scroll:UpdateScrollChildRect()
				Notes.Notes.Scroll:SetVerticalScroll( Notes.Notes.Scroll:GetVerticalScrollRange() );				
			end

		end
			
	end)
	
-- @ void :getMoneyStringPlain( int money ) ; Returns a user readable formatted string indicating gold, silver, and copper
-- @# mostly courtesy of "POSTAL" or MAILFRAME ? NOT SURE WHY I'M NOT USING STANDARD WOW API FOR THIS????
function Notes.InsertMailNote:GetMoneyStringPlain(money)
	local gold = floor(money / 10000)
	local silver = floor((money - gold * 10000) / 100)
	local copper = mod(money, 100)
		
	local gc, sc, cc = "|cffffdd00", "|cffcacaca", "|cffff9900"
	
	if gold > 0 then
		return gc..gold.."g|r "..sc..silver.."s|r "..cc..copper.."c|r"
	elseif silver > 0 then
		return sc..silver.."s|r "..cc..copper.."c|r"
	else
		return cc..copper.."c|r"
	end
end	
	
	
Notes.InsertMailNote:SetScript( "OnEnter", function( self ) 
	GameTooltip:SetOwner( self, "BOTTOMRIGHT" )
	GameTooltip:SetText( "Simply Notes" )
	GameTooltip:AddLine( "Left Click: |cffffcc99Append|r onto Note " .. Notes.Notes.pos, 1.0, 1.0, 1.0, 1.0 )
	GameTooltip:AddLine( "Right Click: |cffffcc99New|r Note", 1.0, 1.0, 1.0, 1.0 )
	GameTooltip:Show( )
	Notes.InsertMailNote:SetAlpha(1);
	Notes.InsertMailNote:SetWidth( 32 )
	Notes.InsertMailNote:SetHeight( 32 )
end )
Notes.InsertMailNote:SetScript( "OnLeave", function( self ) 
		Notes.InsertMailNote:SetWidth( 20 )
		Notes.InsertMailNote:SetHeight( 20 ) 
		Notes.InsertMailNote:SetAlpha(0.7); 
		GameTooltip:Hide()  
	end )


-- @WorldFrame
----------------------------------------------------------------------
WorldFrame:HookScript( "OnMouseDown", function( self, button ) if Notes.Notes.Box:HasFocus() then Notes.Notes.Box:ClearFocus() end end );


-- @General Frame, for events
----------------------------------------------------------------------
Notes.Frame = CreateFrame( "Frame" );
Notes.Frame:Show( );
Notes.Frame:SetScript( "OnEvent", Notes.OnEvent );
Notes.Frame:RegisterEvent( "ADDON_LOADED" );
Notes.Frame:RegisterEvent( "PLAYER_ENTERING_WORLD" );
Notes.Frame:RegisterEvent( "PLAYER_LOGIN" );
Notes.Frame:RegisterEvent( "PLAYER_REGEN_DISABLED" );
Notes.Frame:RegisterEvent( "PLAYER_REGEN_ENABLED" );
Notes.Frame:RegisterEvent( "MAIL_SHOW" ); -- Just to clear focus...


-- @Chat frame...
----------------------------------------------------------------------
-- @ void :FindChatMessageFromLink( any [...] ) ; When the context menu is shown for a player, the link data is stored, when
--		user performs the "Insert into Simply Notes" we'll just find lines that have that link data in it(this should be unique
--		due to the linkdata having the LINEID embedded into it...
function Notes:FindChatMessageFromLink( ... )
	local data = Notes.linkused[1]; --player:Addondev:926:WHISPER:ADDONDEV
	if not data then
		-- probably a right click from Friends Frame, or the like...
		chat( "Not sure what to copy... Try right clicking a player's name in the chat frame..." );
		return false;
	end
	
	--local index = string.gsub( data, "CHANNEL:%d+", ""):gsub( "%D", "" ):gsub( ":", "" );
	local numlines = SELECTED_CHAT_FRAME:GetNumMessages()
	
	local i, found = 1, false;
	local xrealmdatasafe = data:gsub("player:([%a]+)-[^:]+", "player:%1([^:]*)");
	for i = 1, numlines do
		local text, accessID, lineID, extraData = SELECTED_CHAT_FRAME:GetMessageInfo( i )
		if string.match( text, xrealmdatasafe ) then
			Notes.NoteInsertText( text, true )
			found = true;
		end
	end
	
	if not found then chat( "Was unable to locate the message to copy from the chat frame: '"..data.."'" ); end
	
end

UnitPopupButtons["COPYCHATNOTES"] = { text = "Insert into SimplyNotes", dist = 0 , func = Notes.FindChatMessageFromLink, arg1 = "", arg2 = ""};
if not Notes.menusAdded then
	tinsert(UnitPopupMenus["FRIEND"],#UnitPopupMenus["FRIEND"]-1,"COPYCHATNOTES");    
	tinsert(UnitPopupMenus["BN_FRIEND"],#UnitPopupMenus["BN_FRIEND"]-1,"COPYCHATNOTES");    
	Notes.menusAdded = true
end


-- @source: prat
local registry = { }
function Notes:RegisterDropdownButton(name, callback)
    registry[name] = callback or true
end
function notesShowMenu(dropdownMenu, which, unit, name, userData, ...)
	--print( ropdownMenu, which, unit, name, userData, ... )
    local f
	for i=1, UIDROPDOWNMENU_MAXBUTTONS do
		button = getglobal("DropDownList"..UIDROPDOWNMENU_MENU_LEVEL.."Button"..i);
		
        f = registry[button.value]
		-- Patch our handler function back in
		if f then
		    button.func = UnitPopupButtons[button.value].func
            if type(f) == "function" then
                f(dropdownMenu, button)
            end
		end
	end
end

hooksecurefunc("UnitPopup_ShowMenu", notesShowMenu)
Notes:RegisterDropdownButton("COPYCHATNOTES", function(menu, button) button.arg1 = Notes.clickedFrame end )
-- @end of mostly from prat


Notes.linkused = {}
-- @ -- Hooked ChatFrame onHyperlinkShow -- when user right clicks a player name in the chat frame
--		We'll copy the LINK data, so we can do a search for it if the user clicks "Insert into Simply Notes"
--		with :FindChatMessageFromLink()
function Notes:ChatFrame_OnHyperlinkShow(...)
--[[
		1 = [player:PLAYERNAME] : [ CHAT INDEX? ] : [WHISPER:NAME|CHANEL:(index)]
			
		1=player:Addondev:926:WHISPER:ADDONDEV
		2=1:Addondev       < actual link
		3=LeftButton

		1=player:Bloodydemize:927:CHANNEL:2
		2=Bloodydemize		< actual link
		3=LeftButton	
]]
		Notes.linkused = {}
		for i = 1, select("#", ...) do
			Notes.linkused[i] = select(i, ...)
		end
end
hooksecurefunc( "ChatFrame_OnHyperlinkShow", Notes.ChatFrame_OnHyperlinkShow );


--[[
==================================================================================
================================= /HOOKS =========================================
==================================================================================
]]



--[[
==================================================================================
================================== DROP DOWN =====================================
==================================================================================
]]


Notes.DropDownMenu = CreateFrame("Frame", "Notes_DropDownMenu")
Notes.DropDownMenu.displayMode = "MENU"
Notes.DropDownMenu.info = {}
Notes.DropDownMenu.HideMenu = function()
	if UIDROPDOWNMENU_OPEN_MENU == Notes.DropDownMenu then
		CloseDropDownMenus()
	end
end

Notes.DropDownMenu.OnClick = function(frame, button, down)
	
	if Notes.DropDownMenu.initialize ~= frame.initMenuFunc then
		CloseDropDownMenus()
		Notes.DropDownMenu.initialize = frame.initMenuFunc
	end
	ToggleDropDownMenu(1, nil, Notes.DropDownMenu, frame, 0, 0)

end




Notes.Notes.Color:SetScript("OnClick", Notes.DropDownMenu.OnClick)
Notes.Notes.Color.initMenuFunc = function( self, level )
		if not level then return end
		local info = self.info
		wipe(info)
		if level == 1 then
			
			info.isTitle      = 1
			info.text         = "-Custom Color-"
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)

			info.disabled     = nil
			info.isTitle      = nil
			
			info.text = "   Use Color Picker"
			info.func = Notes.ColorClicked
			info.checked = nil
			info.notCheckable = 1
			info.tooltipTitle = "Custom Color"
			info.tooltipText = "Open Color Picker to choose a new color"
			UIDropDownMenu_AddButton(info, level)
			
			info.isTitle      = 1
			info.text         = "-Recent Colors-"
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)

			info.disabled     = nil
			info.isTitle      = nil
			
			for k,v in pairs( NotesPref["RecentColors"] ) do 
				
				info.text = "   |cff"..v.."#"..v.."|r"
				info.func = function() Notes.UseRecentColor(v) end
				info.checked = nil
				info.notCheckable = 1
				info.tooltipTitle = "Recent Color #"..k
				info.tooltipText = nil
				UIDropDownMenu_AddButton(info, level)
				
			end

			info.text         = CLOSE
			info.func         = self.HideMenu
			info.checked      = nil
			info.arg1         = nil
			info.notCheckable = 1
			info.tooltipTitle = CLOSE
			UIDropDownMenu_AddButton(info, level)
		end
	end
	
	
	Notes.Notes.NoteNavigation:SetScript("OnClick", Notes.DropDownMenu.OnClick)
	Notes.Notes.NoteNavigation.initMenuFunc = function( self, level )
		if not level then return end
		local info = self.info
		wipe(info)
		if level == 1 then
					
			
			info.text = "Create New Note"
			info.func = function() Notes.NoteNew( ) end
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)
					
					
			info.isTitle      = 1
			info.text         = "-Notes-"
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)

			info.disabled     = nil
			info.isTitle      = nil
			
			for k,v in pairs( NotesData ) do 
				
				if type( NotesData[ k ] ) ~= "table" then
					NotesData[ k ] = { v , "" };
					v = NotesData[ k ]; -- no clue if this is byref(*), or bval; im new to lua... hehe
				end
				if not v[ NOTES_DATIND_TITLE ] then 
					NotesData[ k ][ NOTES_DATIND_TITLE ] = ""; 
					v = NotesData[ k ]; 
				end
				if v[ NOTES_DATIND_TITLE ]:len() < 3 then
					NotesData[ k ][ NOTES_DATIND_TITLE ] = GetDefaultTitle( v[ NOTES_DATIND_TEXT ] );
					v = NotesData[ k ];
				end
				
				info.text = v[ NOTES_DATIND_TITLE ]
				info.func = function() Notes.NoteShow( k ) end
				info.checked = Notes.Notes.pos == k or nil
				info.notCheckable = nil
				info.tooltipTitle = "Note #"..k
				info.tooltipText = nil
				UIDropDownMenu_AddButton(info, level)
				
			end

			info.text         = CLOSE
			info.func         = self.HideMenu
			info.checked      = nil
			info.arg1         = nil
			info.notCheckable = 1
			info.tooltipTitle = CLOSE
			UIDropDownMenu_AddButton(info, level)
		end
	end
	
	

--Notes.Notes.Box:SetScript("OnClick", Notes.DropDownMenu.OnClick)





--[[
==================================================================================
================================== CONFIRM BOX ===================================
==================================================================================
	I made my own before I learned there is already a default ui box that can
	interact with a user for confirmation, or input... sigh...
]]

Notes.ConfirmBox = CreateFrame( "Frame", "NotesConfirmFrame", UIParent )
Notes.ConfirmBox:Hide( )
Notes.ConfirmBox:SetPoint( "CENTER", "UIParent", "CENTER" )
Notes.ConfirmBox:SetFrameStrata( "DIALOG" )
Notes.ConfirmBox:Raise( ) --SetFrameLevel( Notes.Notes:GetFrameLevel() + 1 )
Notes.ConfirmBox:SetHeight( 200 )
Notes.ConfirmBox:SetWidth( 340 )
Notes.ConfirmBox:SetBackdrop({
		bgFile = "Interface/Tooltips/ChatBubble-Background", 
		edgeFile = "Interface/Tooltips/ChatBubble-BackDrop", 
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 32, right = 32, top = 32, bottom = 32 }
	})
Notes.ConfirmBox:SetBackdropColor( 0, 0, 0, 1 )
Notes.ConfirmBox:SetBackdropBorderColor( 1, 1, 0, 1 )
Notes.ConfirmBox:SetScript( "OnShow", Notes.ConfirmBox_OnShow )
Notes.ConfirmBox:SetMovable( false )
Notes.ConfirmBox:SetResizable( false )
Notes.ConfirmBox:SetClampedToScreen( true )
Notes.ConfirmBox.RealShow = Notes.ConfirmBox.Show
Notes.ConfirmBox.RealHide = Notes.ConfirmBox.Hide

function Notes.ConfirmBox:Show(...)
	Notes.ConfirmBox.isShown = true
	Notes.ConfirmBox:RealShow(...)
	
	--Notes.Notes:SetFrameStrata( "LOW" )
	
	Notes.Notes.Box:ClearFocus()
	--Notes.Notes.Box:SetAlpha(.24)
	
	if Notes.ConfirmBox.Confirm:IsVisible() then
	
		Notes.Notes.Box:Disable()
		Notes.Notes.Box:EnableMouse( false )
		
		--Notes.Drag:Hide()
		Notes.Notes.SearchIcon:Hide()
		--Notes.Notes.SaveIcon:Hide()
		Notes.Notes.NewNote:Hide()
		Notes.Notes.Done:Hide()
		Notes.Notes.Delete:Hide()
		Notes.Notes.Next:Hide()
		Notes.Notes.Prev:Hide()
		Notes.Notes.Lock:Hide()
		Notes.Notes.Color:Hide()
		Notes.Notes.NoteNavigation:Disable()
		
	end
	
	
	Notes.ConfirmBox:Raise()
end         
  
function Notes.ConfirmBox:Hide(...)
	Notes.ConfirmBox.isShown = nil
	Notes.ConfirmBox:RealHide(...)
	Notes.ConfirmBox:SetHeight( 200 )
	Notes.ConfirmBox:SetWidth( 340 )
	
	--Notes.Notes:SetFrameStrata( NOTES_STRATA )

	if NotesPref["isLocked"] == 0 then
		Notes.Notes.Box:Enable()
		--Notes.Notes.Box:SetAlpha(1)
	end
	Notes.Notes.Box:EnableMouse( true )
	Notes.Notes.NoteNavigation:Enable()
	--Notes.Drag:Show()
	Notes.Notes.SearchIcon:Show()
	--Notes.Notes.SaveIcon:Show()
	Notes.Notes.NewNote:Show()
	Notes.Notes.Done:Show()
	Notes.Notes.Delete:Show()
	Notes.Notes.Next:Show()
	Notes.Notes.Prev:Show()
	Notes.Notes.Lock:Show()
	Notes.Notes.Color:Show()

end


function Notes.ConfirmBox_OnShow()
	
end



Notes.ConfirmBox.TitleBar = CreateFrame( "Button", nil, Notes.ConfirmBox )
Notes.ConfirmBox.TitleBar:SetPoint( "TOPLEFT", Notes.ConfirmBox, "TOPLEFT", 10, -5 )
Notes.ConfirmBox.TitleBar:SetPoint( "TOPRIGHT", Notes.ConfirmBox, "TOPRIGHT", -10, -5 )
Notes.ConfirmBox.TitleBar:SetHeight( 13 )
Notes.ConfirmBox.TitleBar:SetNormalTexture( "Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar" ) --NOTES_ART_PATH.."bar")
Notes.ConfirmBox.TitleBar:SetAlpha( 0.5 )

Notes.ConfirmBox.Cancel = CreateFrame( "Button", "", Notes.ConfirmBox, "OptionsButtonTemplate" )
Notes.ConfirmBox.Cancel:SetText( "No" )
Notes.ConfirmBox.Cancel:SetPoint( "BOTTOMRIGHT", Notes.ConfirmBox, "BOTTOMRIGHT", -15, 25 )
Notes.ConfirmBox.Cancel:SetScript( "OnClick", Notes.ConfirmBox_Cancel )


Notes.ConfirmBox.Confirm = CreateFrame( "Button", "", Notes.ConfirmBox, "OptionsButtonTemplate" )
Notes.ConfirmBox.Confirm:SetText( "Yes" )                                                                    
Notes.ConfirmBox.Confirm:SetPoint( "BOTTOMRIGHT", Notes.ConfirmBox.Cancel, "BOTTOMLEFT", 0, 0 )
Notes.ConfirmBox.Confirm:SetScript( "OnClick", Notes.ConfirmBox_Confirm)



Notes.ConfirmBox.Icon = Notes.ConfirmBox:CreateTexture( "Interface/DialogFrame/UI-Dialog-Icon-AlertNew" )
Notes.ConfirmBox.Icon:SetTexture( "Interface/DialogFrame/UI-Dialog-Icon-AlertNew" ) --UI-Dialog-Icon-AlertOther
Notes.ConfirmBox.Icon:SetPoint( "CENTER", Notes.ConfirmBox, "CENTER" )
Notes.ConfirmBox.Icon:SetPoint( "LEFT", Notes.ConfirmBox, "LEFT", 25, 0 )
Notes.ConfirmBox.Icon:Show()

Notes.ConfirmBox.Title = Notes.ConfirmBox:CreateFontString( "", "OVERLAY", "GameFontNormal" )
Notes.ConfirmBox.Title:SetFontObject( GameFontNormal )
Notes.ConfirmBox.Title:SetJustifyH( "LEFT" )
Notes.ConfirmBox.Title:SetPoint( "CENTER", Notes.ConfirmBox, "CENTER", 0, 0 )
Notes.ConfirmBox.Title:SetPoint( "TOP", Notes.ConfirmBox.TitleBar, "TOP", -3, 0 )
Notes.ConfirmBox.Title:SetText( " " )
Notes.ConfirmBox.Title:SetShadowColor( 0, 0, 0, .5 )
Notes.ConfirmBox.Title:SetShadowOffset( 1, -1 )

Notes.ConfirmBox.Mesg = Notes.ConfirmBox:CreateFontString( "", "OVERLAY", "GameFontNormal" )
Notes.ConfirmBox.Mesg:SetFontObject( GameFontHighlight )
Notes.ConfirmBox.Mesg:SetJustifyH( "LEFT" )
Notes.ConfirmBox.Mesg:SetPoint( "CENTER", Notes.ConfirmBox, "CENTER" )
Notes.ConfirmBox.Mesg:SetPoint( "LEFT", Notes.ConfirmBox.Icon, "RIGHT", 20, 0 )
Notes.ConfirmBox.Mesg:SetPoint( "RIGHT", Notes.ConfirmBox, "RIGHT", -30, 0 )
Notes.ConfirmBox.Mesg:SetHeight( 170 )
Notes.ConfirmBox.Mesg:SetText( " " )
Notes.ConfirmBox.Mesg:SetShadowColor( 0, 0, 0, .8 )
Notes.ConfirmBox.Mesg:SetShadowOffset( 2, -2 )






--[[
==================================================================================
================================== SLASH =========================================
==================================================================================
]]



SLASH_NOTES1 = "/notes"
SLASH_NOTES2 = "/note"
SlashCmdList["NOTES"] = function( msg )
	if (not msg or msg == "" or msg == "help") then
		-- Yes, I know you can't expect the same indentation on all machines, no one uses fixed width fonts, space width guesses for standard font :P
		chat("Notes help:", true)
		chat("    |cffffcc00/notes|r |cff99ffccshow|r               - Toggles Notes", true)		
		chat("    |cffffcc00/notes|r |cff99ffccminimap|r          - Toggles MiniMap Icon", true)
		chat("    |cffffcc00/notes|r |cff99ffccfont [1-"..tostring(#NotesPref["Fonts"]).."]|r        - Changes font, example: |cffffcc00/notes|r |cff99ffccfont "..tostring(NotesPref["Font"]).."", true)
		chat("    |cffffcc00/notes|r |cff99ffccfontsize [5-40]|r - Changes font size, example: |cffffcc00/notes|r |cff99ffccfontsize "..tostring(NotesPref["FontSize"]).."", true)
		chat("    |cffffcc00/notes|r |cff99ffccscale [1-100]|r   - Window Scale, example: |cffffcc00/notes|r |cff99ffccscale "..tostring((NotesPref["Scale"] or 1) * 100 ).." ", true)
		chat("    |cffffcc00/notes|r |cff99ffccalpha [1-100]|r   - Background Alpha, example: |cffffcc00/notes|r |cff99ffccalpha "..tostring((NotesPref["BackAlpha"] or 0.88) * 100 ).." ", true)
		chat("    |cffffcc00/notes|r |cff99ffccsize [w x h]|r     - Example: |cffffcc00/notes|r |cff99ffccsize "..tostring( math.floor(Notes.Notes:GetWidth()) ).." x "..tostring( math.floor(Notes.Notes:GetHeight()) ) ..
		"|r or |cff99ffcc150% x "..tostring( math.floor(Notes.Notes:GetHeight()) ) .. "|r or |cff99ffcc150% x 89%|r", true)
		chat("    |cffffcc00/notes|r |cff99ffccresetpos|r          - Reset Window Position to Center of Screen", true)
		chat("    |cffffcc00/notes|r |cff99ffccclear|r                - Deletes ALL Notes, |cffff0000CAREFUL|r", true)
		chat("    |cffffcc00/notes|r |cff99ffcccomm|r                - Send/Receive Notes", true)
		chat("    |cffffcc00/notes|r |cff99ffccmanualsave [On | Off]|r", true)
		chat("    |cffffcc00/notes|r |cff99ffccabout|r", true)
	elseif (msg == "show") then
		toggle()--Notes.NoteShow( ) --if not then -1
	elseif msg == "minimap" then
	
		if NotesPref["MiniMapIcon"] then
			NotesPref["MiniMapIcon"]["hide"] = not NotesPref["MiniMapIcon"]["hide"];
			--if LDBIcon then
			--	if NotesPref["MiniMapIcon"]["hide"] == true then LDBIcon:Hide( 'Simply Notes' ); else LDBIcon:Show( 'Simply Notes' ); end
			--else
				if NotesPref["MiniMapIcon"]["hide"] == true then NotesMapIcon:Hide( ); else NotesMapIcon:Show( ); end
			--end
		end
	
	elseif (msg == "clear") then
	
		local btnConfirm = { "Yes", function() 
				--Notes.Notes:Hide()
				Notes.ConfirmBox:Hide()
				NotesData = {}
				tinsert( NotesData, { NOTES_DEFAULT_NOTE, "New Note" } )
				Notes.Notes.pos = 1
				NotesPref["lastShown"] = 1
				NotesPrefCS["lastShown"] = 1
				Notes.NoteDisplay( 1 )
				chat("Notes have been cleared")
			end }
		local btnCancel = { "No", function() Notes.ConfirmBox:Hide() end } 
		Notes.SetupConfirm( "Simply Notes "..NOTES_VERSION, "Do you really want to delete all of your notes?", btnCancel, btnConfirm )
	
	elseif( msg == "comm" ) then
		Notes.Notes.CommOutFrame:Show();
		
	elseif (msg == "resetpos") then
	
		Notes.Notes:ClearAllPoints()
		Notes.Notes:SetPoint( "CENTER", "UIParent", "CENTER" )
		
		chat("Notes position have been reset")
		
	elseif ( strsub( msg, 1, 5 ):lower() == "about") then
	
		UpdateAddOnMemoryUsage();
        local mem = GetAddOnMemoryUsage("Notes");
        if mem > 1024 then
            mem = string.format( "%s%s", floor(mem / 1024), " MB" );
        else
            mem = string.format( "%s%s", floor(mem), " KB" );
        end

		Notes.SetupConfirm( "About Simply Notes "..NOTES_VERSION, "A simple |cffffff00Note|rpad AddOn|nVersion: |cffffff00"..NOTES_VERSION.."|r|nMemory: " .. mem .. "|n|n|cff00ccffTruii|r - Whisperwind(US)|r|n|cff00ccffalexrs|r@gmail.com" )
		
	
	elseif ( strsub( msg, 1, 4 ):lower() == "size"  ) then
		local cmdline = strsub( msg, 5 );
		local _, _, width, wp, height, hp = cmdline:find( "([%d]+)([%%]?)[%a%s]+([%d]+)([%%]?)" );
		
		
		if width and wp and wp == "%" then
			width = floor( Notes.Notes:GetWidth() * ( width / 100 ) );
		end
		
		if height and hp and hp == "%" then
			height = floor( Notes.Notes:GetHeight() * ( height / 100 ) );
		end
		
		
		if not width or not height then
			chat( NOTES_ERRORCOLOR .. "Error parsing width and/or height numbers from: \"" .. cmdline .. "\"|r" );
			chat( "|cffffff00Please use the format of /notes size 500 x 200|r" );
			return;
		end
		
		width = tonumber( width );
		height = tonumber( height );
		if width >= 368 and width < UIParent:GetWidth() then
			Notes.Notes:SetWidth( width );
		else
			chat( string.format("The %s you entered (%d) is too small, or too big and is not being used. It must be less then %d and more than or equal to %d.", "width", width, UIParent:GetWidth(), 368 ) );
		end
		
		if height >= 100 and height < UIParent:GetHeight() then
			Notes.Notes:SetHeight( height );
		else
			chat( string.format("The %s you entered (%d) is too small, or too big and is not being used. It must be less then %d and more than or equal to %d.", "height", height, UIParent:GetHeight(), 100 ) );
		end

	
	elseif ( strsub( msg, 1, 5 ):lower() == "scale"  ) then
		local scale = tonumber( strsub( msg, 6) )
		if( not scale ) then scale = 100 end
		if scale < 10 then scale = 10 end
		if scale > 200 then scale = 200 end
		NotesPref["Scale"] = scale / 100
		Notes.Notes:SetScale( NotesPref["Scale"] )
		scale = nil
		
	elseif ( strsub( msg, 1, 5 ):lower() == "alpha"  ) then
		if string.len( msg ) == 5 then return end
		local alpha = tonumber( strsub( msg, 6) )
		if( not alpha ) then alpha = 100 end
		if alpha < 0 then alpha = 0 end
		if alpha > 100 then alpha = 100 end
		NotesPref["BackAlpha"] = alpha / 100
		--Notes.Notes:SetAlpha( NotesPref["BackAlpha"] )
		local red, green, blue, _ = Notes.Notes:GetBackdropColor()
		Notes.Notes:SetBackdropColor( red, green, blue, NotesPref["BackAlpha"] )
		red, green, blue, _ = Notes.Notes:GetBackdropBorderColor()
		Notes.Notes:SetBackdropBorderColor( red, green, blue, NotesPref["BackAlpha"] )
		alpha = nil
		
	elseif ( strsub( msg, 1, 8 ):lower() == "fontsize"  ) then
		if string.len( msg ) == 8 then return end
		local fontsize = tonumber( strsub( msg, 9) )
		DEBUG("Setting FontSize, Got "..fontsize.." from "..msg)
		if( not fontsize ) then fontsize = 12 end
		if fontsize < 7 or fontsize > 40 then fontsize = 12 end
		NotesPref["FontSize"] = fontsize
		DEBUG("Setting FontSize, USING "..fontsize)
		local fonts = NotesPref["Fonts"]
		local fontchoice = tonumber( NotesPref["Font"] )
		if ( not fonts or not #fonts ) then PrefSetupFonts() NotesPref["Font"] = 1 fontchoice = 1 end
		if not fonts[ fontchoice ] then NotesPref["Font"] = 1 fontchoice = 1 end
		if not fontsize or fontsize < 7 or fontsize > 40 then fontsize = 13 NotesPref["FontSize"] = 13 end
		
		if not Notes.Notes.Box:SetFont( NOTES_FONT_PATH..fonts[ fontchoice ], fontsize )  then
			--try with out addon path
			Notes.Notes.Box:SetFont( fonts[ fontchoice ], fontsize ) 
		end
		
		
		
		DEBUG("UPDATING Font, USING "..NOTES_FONT_PATH..fonts[ fontchoice ]..", "..fontsize)
		chat( "Setting fontsize to "..fontsize )
		
		fonts = nil
		fontchoice = nil
		fontsize = nil
	
	elseif ( strsub( msg, 1, 4 ):lower() == "font"  ) then
		if string.len( msg ) == 4 then return end
		local fontindex = tonumber( strsub( msg, 5) )
		DEBUG("Setting Font, Got "..fontindex.." from "..msg)
		if( not fontindex ) then fontindex = 1 end
		if fontindex < 1 or fontindex > #NotesPref["Fonts"] then fontindex = 1 end
		NotesPref["Font"] = fontindex
		DEBUG("Setting Font, USING "..fontindex)
		local fonts = NotesPref["Fonts"]
		local fontsize = tonumber( NotesPref["FontSize"] )
		local fontchoice = fontindex
		if ( not fonts or not #fonts ) then PrefSetupFonts() NotesPref["Font"] = 1 fontchoice = 1 end
		if not fonts[ fontchoice ] then NotesPref["Font"] = 1 fontchoice = 1 end
		if not fontsize or fontsize < 7 or fontsize > 30 then fontsize = 12 NotesPref["FontSize"] = 12 end
		
		
		if not Notes.Notes.Box:SetFont( NOTES_FONT_PATH..fonts[ fontchoice ], fontsize )  then
			--try with out addon path
			Notes.Notes.Box:SetFont( fonts[ fontchoice ], fontsize ) 
		end
		
		
		--DEBUG("UPDATING Font, USING "..NOTES_FONT_PATH..fonts[ fontchoice ]..", "..fontsize)
		chat( "Setting font to "..fonts[ fontchoice ].." ("..fontchoice..")" )
		
		fonts = nil
		fontchoice = nil
		fontsize = nil
		fontindex = nil
		
	elseif ( strsub( msg, 1, 10 ):lower() == "manualsave"  ) then
		--NotesPref["ManualSave"]
		local cmdline = strsub( msg, 11 ):trim():lower();
		local _, _, cmdenabled = cmdline:find( "([onf]+)" );
		
		
		if cmdenabled then
			NotesPref["ManualSave"]	= cmdenabled == "on" and 1 or nil;
			chat( "Manual saving has been turned " .. ( cmdenabled == "on" and "On" or "Off" ) );
			if NotesPref["ManualSave"] then
				chat( "Your note will |cffff0000never|r be saved unless you click the Save button in the main Notes window." );
				chat( "If you close Simply Notes window, navigate to another note, log out, or even Reload your UI your |cffff0000unsaved changes will be lost!|r" );
				Notes.Notes.SaveIcon:Show();
			else
				Notes.Notes.SaveIcon:Hide();
			end
		end
		
		if not cmdenabled then
			chat( NOTES_ERRORCOLOR .. "Error parsing \"On or Off\": \"" .. cmdline .. "\"|r" );
			chat( "|cffffff00Please use the format of /notes manualsave Off|r" );
			return;
		end
		
	
	end
end

