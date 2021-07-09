--[[
	Notes - An addon to create notes(/stickies) in game
	@author: aLeX^rS (alexrs@gmail.com)
	
	Looked through the addon !Swatter(Great fucking addon) to familiarize my self
	 with LUA, and some minor Widget API....
	 
	_GetTextHighlight, _ColorSelection from @Saiket: 
	It's GetTextHighlight is simply, but the coloring of a selection that already
	has a color code control character in it proved frustrating...
	http://www.wowinterface.com/forums/showthread.php?t=41521
	
	Used part of WoWWiki's notes on ColorPicker, lol..

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

Notes.Search = {};
local NSearch = Notes.Search;
local FSearch = nil;

local SearchResults = {};
Notes.Search.SearchResults = SearchResults;

local foundinNote = {};
local dummyFontString = nil;

NotesPref["SearchPhrases"] = {}; --persistence


function NSearch.PerformSearch( query )
		--[[local EdFont = Notes.Notes.Box:GetFontObject();
		local LineSpacing = EdFont:GetSpacing();
		local _, LineHeight, _ = EdFont:GetFont();
		local CurScroll, MaxScroll = Notes.Notes.Scroll:GetVerticalScroll(), Notes.Notes.Scroll:GetVerticalScrollRange();
		
		local HiddenLines = floor( MaxScroll / ( LineSpacing + LineHeight ) );
		local LinesAboveView, LinesBelowView = floor( CurScroll / ( LineSpacing + LineHeight ) ), ceil( HiddenLines - ( CurScroll / ( LineSpacing + LineHeight ) ) );
		
		
		print( LineSpacing, LineHeight, CurScroll, MaxScroll );
		print( "Hidden Total: " .. HiddenLines, "Hidden Above: " .. LinesAboveView , "Hidden Below: " .. LinesBelowView );
		]]
		
		local i = 1;
		NSearch.SearchResults = {};
		foundinNote = {};
		
		local noteind, notedata;
		for noteind, notedata in pairs( NotesData ) do
			for k, v in string.gmatch( NotesData[noteind][1]:gsub( "\r", "" ), "([^\n]+)") do
				NSearch.QueryLine( noteind, i, k, query, not FSearch.OptRegExp:GetChecked() );
				i = 1+i;
			end
			i = 1;
		end
		
		
		FSearch.Results:SetText( "<html><body>" .. table.concat( Notes.Search.SearchResults, "\n" ) .. "</body></html>" );
		FSearch.Scroll:UpdateScrollChildRect();
		
end

local function ModifyMatchText( mt, ind, nocomma ) if mt then return ( nocomma and "" or ",") .. " (" .. ind .. "): \""..mt.."\""; else return mt; end end

function NSearch.QueryLine( noteind, lineind, linedata, query, regexp )
	local linedata = linedata:gsub( "|c%x%x%x%x%x%x%x%x", "" ):gsub( "|r", "" ):gsub( "|H(%a+):[^|]+|h", "" ):gsub( "|h", "" );
	local i= 1
	local matchStart, matchEnd, matchText1, matchText2, matchText3, matchText4, matchText5, matchText6, matchText7, matchText8, matchText9;
	local ignorecase = nil;
	
	if not FSearch.OptRegExp:GetChecked() then ignorecase = FSearch.OptIgCase:GetChecked() == 1; end
	if ignorecase then 
		query = query:lower(); 
		linedata = linedata:lower(); 
	end
	
	matchStart, matchEnd, matchText1, matchText2, matchText3, matchText4, matchText5, matchText6, matchText7, matchText8, matchText9 = linedata:find( query, 1, regexp );
	matchText1 = ModifyMatchText( matchText1, 1, true );
	matchText2 = ModifyMatchText( matchText2, 2 );
	matchText3 = ModifyMatchText( matchText3, 3 );
	matchText4 = ModifyMatchText( matchText4, 4 );
	matchText5 = ModifyMatchText( matchText5, 5 );
	matchText6 = ModifyMatchText( matchText6, 6 );
	matchText7 = ModifyMatchText( matchText7, 7 );
	matchText8 = ModifyMatchText( matchText8, 8 );
	matchText9 = ModifyMatchText( matchText9, 9 );
	
	if matchStart then

		--Notes.DEBUG( "<a href=\"\">Found \"" .. query .. "\" in note #" .. noteind .. " on line #", lineind , "Starting at character" , matchStart, "ending at" , matchEnd );
		
		local ResultTxt = "";
		local querydisplay = "";
		if FSearch.OptRegExp:GetChecked() then
			if matchText1 then querydisplay = "match"; else querydisplay = "\"" .. query:gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("&", "&amp;") .. "\""; end
			ResultTxt = string.format( "<p>#%i: |cffffff00[<a href=\"result:%i,%i,%i\">Found %s on line #%i]</a>|r - |cff99cccc%s %s %s %s %s|r</p>", (#NSearch.SearchResults +1)  , noteind, lineind, 
				query:len(),querydisplay, lineind, matchText1 or "no capture(s)", matchText2 or "", matchText3 or "", matchText4 or "", matchText5 or "" )
		else
			ResultTxt = string.format( "<p>#%i: |cffffff00[<a href=\"result:%i,%i,%i\">Found \"%s\" on line #%i]</a>|r</p>", (#NSearch.SearchResults +1)  , noteind, lineind, 
				query:len(),query:gsub("\"", "&quot;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("&", "&amp;"), lineind )
		end
		
		if not foundinNote["fin" .. noteind] then
			foundinNote["fin" .. noteind] = true;
			ResultTxt = "<h2>|cffccccccNote #" .. noteind .. " - " .. (NotesData[noteind][2]) .. "|r</h2>" .. ResultTxt;
		end
		
		table.insert( NSearch.SearchResults, ResultTxt );
		
	end

end



function NSearch.SearchResClicked( self, linkData, link, button )
	
	local _, _, noteInd, lineNum, queryLen = linkData:find( "result:([%d]+),([%d]+),([%d]+)", 1 );
	local abslines, i, curPos, curEndPos = 0, 0, 0, 0;
	
	local realLinesHeight = 0; -- Sum of all Line heights above the line we'll be highlighting
	dummyFontString:SetFont( Notes.Notes.Box:GetFont() );
	dummyFontString:SetPoint( "LEFT", Notes.Notes.Box, "LEFT", 0, 0 )
	dummyFontString:SetPoint( "RIGHT", Notes.Notes.Box, "RIGHT", 0, 0 )
	
	
	if noteInd and lineNum then
		
		noteInd = math.abs(noteInd);
		lineNum = math.abs(lineNum);
		queryLen = math.abs(queryLen);
		
		if noteInd ~= Notes.Notes.pos then 		
			Notes.NoteShow( noteInd ); 
		end
		
		for k, v in string.gmatch( NotesData[noteInd][1]:gsub( "\r", "" ) .. "\n", "([^\n]*)\n") do

			abslines = abslines + 1;
			if k ~= "" then
				i = i+1;
			end
			
			curEndPos = curEndPos + k:len() + 1;
			
			dummyFontString:SetText( k:len() > 0 and k or " " );
			dummyFontString:SetWidth( Notes.Notes.Box:GetWidth() );
			
			realLinesHeight = realLinesHeight + ( dummyFontString:GetHeight()  );
			
			if i == lineNum then
				if curPos > -1 then
					realLinesHeight = realLinesHeight - ( dummyFontString:GetHeight()  );
					Notes.Notes.Box:HighlightText( curPos, curEndPos ) 
				end
				break;
			end
			
			curPos = curEndPos; --+1 for \n?
		end
		dummyFontString:SetText("");

		if Notes.Notes.Scroll:GetVerticalScrollRange() > 0 and realLinesHeight >= 0 then
			if realLinesHeight <= Notes.Notes.Scroll:GetVerticalScrollRange() then
				Notes.DEBUG( "Scrolling to:", realLinesHeight );
				Notes.Notes.Scroll:SetVerticalScroll( realLinesHeight )
			else
				Notes.Notes.Scroll:SetVerticalScroll( Notes.Notes.Scroll:GetVerticalScrollRange() )
			end
		end
		
	end
end


--[[
==================================================================================
================================== FRAMES ========================================
==================================================================================
]]



Notes.Notes.SearchFrame = CreateFrame( "Frame", "NotesSearchFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" )
Notes.Notes.SearchFrame:Hide( )
Notes.Notes.SearchFrame:SetPoint( "CENTER", Notes.Notes, "CENTER" )
Notes.Notes.SearchFrame:SetFrameStrata( "DIALOG" )
Notes.Notes.SearchFrame:EnableMouse( true )
Notes.Notes.SearchFrame:SetHeight( 350 )
Notes.Notes.SearchFrame:SetWidth( 500 )
Notes.Notes.SearchFrame:SetBackdrop({
		bgFile = "Interface/Tooltips/ChatBubble-Background",
		edgeFile = "Interface/Tooltips/ChatBubble-BackDrop",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 32, right = 32, top = 32, bottom = 32 }
	})
Notes.Notes.SearchFrame:SetBackdropColor( 0, 0, 0, 1 )
Notes.Notes.SearchFrame:SetBackdropBorderColor( .25, .25, 0, 1 )
Notes.Notes.SearchFrame:SetScript( "OnMouseDown", function( self, button ) if button == "LeftButton" then Notes.Notes.SearchFrame:StartMoving() end end )
Notes.Notes.SearchFrame:SetScript( "OnMouseUp", function( self, button ) if button == "LeftButton" then Notes.Notes.SearchFrame:StopMovingOrSizing() end end )
Notes.Notes.SearchFrame:SetMovable( true )
Notes.Notes.SearchFrame:SetMinResize( 368, 100 )
Notes.Notes.SearchFrame:SetClampedToScreen( true )
FSearch = Notes.Notes.SearchFrame;


FSearch.TitleBar = CreateFrame( "Button", nil, FSearch, BackdropTemplateMixin and "BackdropTemplate" )
FSearch.TitleBar:SetPoint( "TOPLEFT", FSearch, "TOPLEFT", 10, -5 )
FSearch.TitleBar:SetPoint( "TOPRIGHT", FSearch, "TOPRIGHT", -10, -5 )
FSearch.TitleBar:SetHeight( 13 )
FSearch.TitleBar:SetNormalTexture( Notes.NOTES_ART_PATH.."bar" ) 
FSearch.TitleBar:SetHighlightTexture( "Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar" ) -- -Blue
FSearch.TitleBar:SetAlpha( 0.5 )
FSearch.TitleBar:EnableMouse( false )

FSearch.Title = FSearch:CreateFontString( "", "OVERLAY", "GameFontNormal" )
FSearch.Title:SetFontObject( GameFontNormal )
FSearch.Title:SetJustifyH( "CENTER" )
FSearch.Title:SetAllPoints( FSearch.TitleBar )
--FSearch.Title:SetPoint( "CENTER", FSearch, "CENTER", 0, 0 )
--FSearch.Title:SetPoint( "TOP", FSearch.TitleBar, "TOP", -3, 0 )
FSearch.Title:SetText( "SimplyNotes - Search" )
FSearch.Title:SetShadowColor( 0, 0, 0, .5 )
FSearch.Title:SetShadowOffset( 1, -1 )
FSearch.Title:SetTextColor( 1, 1, 1, 1 );

do
		local fntstr = FSearch:CreateFontString( "", "OVERLAY", "GameFontNormalSmall" );
		fntstr:SetJustifyH( "LEFT" )
		fntstr:SetPoint( "TOP", FSearch.TitleBar, "BOTTOM", -10, -15 )
		fntstr:SetPoint( "LEFT", FSearch, "LEFT", 15, 0 )
		fntstr:SetHeight( 29 )
		fntstr:SetText( "Search phrase: " )
		
		
		FSearch.Box = CreateFrame( "EditBox", "NotesSearchEditBox", FSearch, BackdropTemplateMixin and "BackdropTemplate" )
		FSearch.Box:SetWidth( 277 )
		FSearch.Box:SetHeight( 32 )
		FSearch.Box:SetPoint( "TOP", FSearch.TitleBar, "BOTTOM", -10, -15 )
		FSearch.Box:SetPoint( "LEFT", fntstr, "RIGHT", 15, 0 )
		FSearch.Box:SetMultiLine( false )
		FSearch.Box:SetAutoFocus( false )
		FSearch.Box:SetFontObject( GameFontHighlight )
		FSearch.Box:SetShadowColor( 0, 0, 0, .6 )
		FSearch.Box:SetShadowOffset( 1, -1 )
		FSearch.Box:SetScript( "OnShow", function( self )
				if not NotesPref["lastSearchPhrase"] then NotesPref["lastSearchPhrase"] = ""; end
				self:SetText( NotesPref["lastSearchPhrase"] );
			end );
		FSearch.Box:SetScript( "OnEscapePressed", function(...) FSearch.Box:ClearFocus() end )
		FSearch.Box:SetScript( "OnEnterPressed", function( self, ...) 
				if self:GetText():len() == 0 then return; end
				self:ClearFocus(); 
				NSearch.PerformSearch( self:GetText() );
				self:AddHistoryLine( self:GetText() );
				NotesPref["lastSearchPhrase"] = self:GetText( );
				if not NotesPref["SearchPhrases"] then NotesPref["SearchPhrases"] = {}; end
				local exists = nil;
				for k, v in pairs( NotesPref["SearchPhrases"] ) do
					if v == self:GetText() then exists = true; break; end
				end
				
				if not exists then
					if #NotesPref["SearchPhrases"] >= 15 then
						table.remove( NotesPref["SearchPhrases"], 1 );
					end
					table.insert( NotesPref["SearchPhrases"], self:GetText() )
				end
				
			end )

		FSearch.Box:Show();
		
		FSearch.Box:SetTextInsets( 5, 1, 5, 1 );
		
		FSearch.Box:SetBackdrop({
			bgFile = "Interface/Tooltips/ChatBubble-Background",
			edgeFile = "Interface/Tooltips/ChatBubble-BackDrop",
			tile = true, tileSize = 32, edgeSize = 8,
			insets = { left = 8, right = 5, top = 5, bottom = 5 }
		})
		
		FSearch.PhraseDD = CreateFrame( "Button", "", FSearch, "OptionsButtonTemplate" )
		FSearch.PhraseDD:SetText( "..." )
		FSearch.PhraseDD:SetPoint( "BOTTOMLEFT", FSearch.Box, "BOTTOMRIGHT", 5, 0 )
		FSearch.PhraseDD:SetWidth( 40 );
		FSearch.PhraseDD:SetHeight( FSearch.Box:GetHeight() );
		
		FSearch.PhraseHelp = CreateFrame( "Button", "", FSearch, "OptionsButtonTemplate" )
		FSearch.PhraseHelp:SetText( "?" )
		FSearch.PhraseHelp:SetPoint( "BOTTOMLEFT", FSearch.PhraseDD, "BOTTOMRIGHT", 5, 0 )
		FSearch.PhraseHelp:SetWidth( 30 );
		FSearch.PhraseHelp:SetHeight( FSearch.Box:GetHeight() );
		FSearch.PhraseHelp:SetScript( "OnEnter", function( self )
				GameTooltip:SetOwner( self, "BOTTOMLEFT" )
				GameTooltip:SetText( "Regular Expressions" )
				GameTooltip:AddLine( "%a - letters, %c - control chars, %d - digits", 1, 1, 1, 1)
				GameTooltip:AddLine( "%l - lowercase, %p - punctuation chars, %s - space chars", 1, 1, 1, 1)
				GameTooltip:AddLine( "%u - uppercase, %w - alpha numeric, %x - hexadecimal", 1, 1, 1, 1)
				GameTooltip:AddLine( "% can be used to escape magic chars, ^$()%.[]*+-?", 1, 1, 1, 1)
				GameTooltip:AddLine( "Sets: [0-7%l%-] - octal digits, lowercase, and \"-\"", 1, 1, 1, 1)
				GameTooltip:AddLine( "^Sets: [^a-c%s] - NOT a through c, NOT any space chars", 1, 1, 1, 1)
				GameTooltip:Show()
			end );
		FSearch.PhraseHelp:SetScript( "OnLeave", function() GameTooltip:Hide() end );
		FSearch.PhraseHelp:SetScript( "OnClick", function()
				local strHtml = "<html><body><h1>Regular Expressions</h1>";
				strHtml = strHtml .. "<p>%a - letters, %c - control chars, %d - digits</p>";
				strHtml = strHtml .. "<p>%l - lowercase, %p - punctuation chars, %s - space chars</p>";
				strHtml = strHtml .. "<p>%u - uppercase, %w - alpha numeric, %x - hexadecimal</p>";
				strHtml = strHtml .. "<p>% can be used to escape magic chars, ^$()%.[]*+-?</p>";
				strHtml = strHtml .. "<p>Sets: [0-7%l%-] - octal digits, lowercase, and \"-\"</p>";
				strHtml = strHtml .. "<p>^Sets: [^a-c%s] - NOT a through c, NOT any space chars</p>";
				strHtml = strHtml .. "</body></html>";
				FSearch.Results:SetText( strHtml );
			end );
		
		
		
		
		FSearch.PhraseDD:SetScript( "OnClick", Notes.DropDownMenu.OnClick )

		FSearch.PhraseDD.initMenuFunc = function( self, level )
			if not level then return end
			local info = self.info
			wipe(info)
			if level == 1 then
						
				
				info.disabled     = nil
				info.isTitle      = nil
				
				if not NotesPref["SearchPhrases"] then NotesPref["SearchPhrases"] = {} end
				for k,v in pairs( NotesPref["SearchPhrases"] ) do 
										
					info.text = v
					info.func = function() FSearch.Box:SetText( v ) end
					info.checked = nil
					info.notCheckable = nil
					info.tooltipTitle = nil
					info.tooltipText = nil
					UIDropDownMenu_AddButton(info, level)
					
				end
						
						
				info.isTitle      = 1
				info.text         = "-Regular Expression Examples-"
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)

				info.disabled     = nil
				info.isTitle      = nil
				
					
				info.text = "\"%[([%w%s]+)%]\" -- All links"
				info.func = function() FSearch.Box:SetText("%[([%w%s]+)%]"); FSearch.OptRegExp:SetChecked( true ) end
				info.checked = nil
				info.notCheckable = nil
				info.tooltipTitle = nil
				info.tooltipText = nil
				UIDropDownMenu_AddButton(info, level)
				
				info.text = "\"^(%\[[%w%s]+%])\" -- Lines beginning with link"
				info.func = function() FSearch.Box:SetText("^(%\[[%w%s]+%])"); FSearch.OptRegExp:SetChecked( true ) end
				info.checked = nil
				info.notCheckable = nil
				info.tooltipTitle = nil
				info.tooltipText = nil
				UIDropDownMenu_AddButton(info, level)
				
				info.text = "\"(%[\[%w%s]+%])$\" -- Lines ending with link"
				info.func = function() FSearch.Box:SetText("^(%\[[%w%s]+%])"); FSearch.OptRegExp:SetChecked( true ) end
				info.checked = nil
				info.notCheckable = nil
				info.tooltipTitle = nil
				info.tooltipText = nil
				UIDropDownMenu_AddButton(info, level)
				
				info.text = "\"^[-]+[%s]+([%w%s%p]+)\" -- Beginning with Point \"-- *\""
				info.func = function() FSearch.Box:SetText("^[-]+[%s]+([%w%s%p]+)"); FSearch.OptRegExp:SetChecked( true ) end
				info.checked = nil
				info.notCheckable = nil
				info.tooltipTitle = nil
				info.tooltipText = nil
				UIDropDownMenu_AddButton(info, level)
				
				info.text = "\"(%b[])\" -- In braces"
				info.func = function() FSearch.Box:SetText("(%b[])"); FSearch.OptRegExp:SetChecked( true ) end
				info.checked = nil
				info.notCheckable = nil
				info.tooltipTitle = nil
				info.tooltipText = nil
				UIDropDownMenu_AddButton(info, level)
				
				info.text = "\"(%b())\" -- In brackets"
				info.func = function() FSearch.Box:SetText("(%b())"); FSearch.OptRegExp:SetChecked( true ) end
				info.checked = nil
				info.notCheckable = nil
				info.tooltipTitle = nil
				info.tooltipText = nil
				UIDropDownMenu_AddButton(info, level)
				
				info.text = "\"(%b\"\")\" -- In qoutes"
				info.func = function() FSearch.Box:SetText("(%b\"\")"); FSearch.OptRegExp:SetChecked( true ) end
				info.checked = nil
				info.notCheckable = nil
				info.tooltipTitle = nil
				info.tooltipText = nil
				UIDropDownMenu_AddButton(info, level)
				
				info.text = "\"%[(Lofty [%w%s]+) of the [^%}]+\" -- [Lofy * of the *]"
				info.func = function() FSearch.Box:SetText("%[(Lofty [%w%s]+) of the [^%}]+"); FSearch.OptRegExp:SetChecked( true ) end
				info.checked = nil
				info.notCheckable = nil
				info.tooltipTitle = nil
				info.tooltipText = nil
				UIDropDownMenu_AddButton(info, level)
					
				
				

				info.text         = CLOSE
				info.func         = self.HideMenu
				info.checked      = nil
				info.arg1         = nil
				info.notCheckable = 1
				info.tooltipTitle = CLOSE
				UIDropDownMenu_AddButton(info, level)
			end
		end
		
		
		
		
		FSearch.OptRegExp = CreateFrame( "CheckButton", "NotesSearchOptRegExp", FSearch, "InterfaceOptionsCheckButtonTemplate" )
		--FSearch.Box:SetHeight( 32 )
		FSearch.OptRegExp:SetPoint( "TOP", FSearch.Box, "BOTTOM", -10, -15 )
		FSearch.OptRegExp:SetPoint( "LEFT", fntstr, "LEFT", 0, 0 )
		_G[FSearch.OptRegExp:GetName().."Text"]:SetText( "Regular Expression" );
		FSearch.OptRegExp:SetScript( "OnClick", function ()
				if FSearch.OptRegExp:GetChecked() then
					FSearch.OptIgCase:Disable();
				else
					FSearch.OptIgCase:Enable();
				end
			end )
		
		FSearch.OptIgCase = CreateFrame( "CheckButton", "NotesSearchOptIgCase", FSearch, "InterfaceOptionsCheckButtonTemplate" )
		--FSearch.Box:SetHeight( 32 )
		FSearch.OptIgCase:SetPoint( "TOP", FSearch.Box, "BOTTOM", -10, -15 )
		FSearch.OptIgCase:SetPoint( "LEFT", FSearch.OptRegExp, "RIGHT", 125, 0 )
		_G[FSearch.OptIgCase:GetName().."Text"]:SetText( "Ignore Case" );
		FSearch.OptIgCase:SetChecked( true );
		
		
				
		local fntstr = FSearch:CreateFontString( "", "OVERLAY", "GameFontNormalSmall" );
		fntstr:SetJustifyH( "LEFT" )
		fntstr:SetPoint( "TOP", FSearch.OptRegExp, "BOTTOM", -10, -15 )
		fntstr:SetPoint( "LEFT", FSearch, "LEFT", 15, 0 )
		fntstr:SetHeight( 29 )
		fntstr:SetText( "Search Results: " )
		
		
		
		FSearch.CloseButton = CreateFrame( "Button", "", FSearch, "OptionsButtonTemplate" )
		FSearch.CloseButton:SetText( "Close" )
		FSearch.CloseButton:SetPoint( "BOTTOMRIGHT", FSearch, "BOTTOMRIGHT", -15, 25 )
		FSearch.CloseButton:SetScript( "OnClick", function( self ) self:GetParent():Hide() end )
		
		
		
		FSearch.Scroll = CreateFrame( "ScrollFrame", "FSearchScroll", FSearch, "UIPanelScrollFrameTemplate" );
		FSearch.Scroll:SetPoint( "LEFT", FSearch, "LEFT", 10, 0 );
		FSearch.Scroll:SetPoint( "RIGHT", FSearch, "RIGHT", -35, 0 );
		FSearch.Scroll:SetPoint( "TOP", fntstr, "BOTTOM", 5, 0 );
		FSearch.Scroll:SetPoint( "BOTTOM", FSearch.CloseButton, "TOP", 0, 10 );
		
		
		FSearch.Results = CreateFrame( "SimpleHTML", "FSearchResults", FSearch.Scroll, BackdropTemplateMixin and "BackdropTemplate" );
		FSearch.Scroll:SetScrollChild( FSearch.Results );
		FSearch.Results:Show();
		--FSearch.Results:SetAllPoints( FSearch.Scroll );
		FSearch.Results:SetWidth( FSearch.Scroll:GetWidth() );
		FSearch.Results:SetHeight( 85 );

		FSearch.Results:SetHyperlinksEnabled( true );
		FSearch.Results:SetFontObject( GameFontHighlight );
		FSearch.Results:SetScript( "OnHyperlinkClick", NSearch.SearchResClicked );
		FSearch.Results:SetFontObject( "h1", GameFontHighlightLarge );
		FSearch.Results:SetTextColor( "h1", 1, 1, 0.6, 1 );
		FSearch.Results:SetSpacing( 3 )
		local filename, fh, flags = FSearch.Results:GetFont( )
		FSearch.Results:SetFont( filename, 10, "" )
		
		
		--- Dummy FontString object, we'll be copying the font properties of the Note window to this object
		--- When we are determining the line heights to scroll when we're displaying a search result
		--- We'll be using this dummy fontstring object to determine the TRUE line hight of each line.
		dummyFontString = Notes.Notes:CreateFontString( "", "OVERLAY", "GameFontNormal", Notes.Notes )
		dummyFontString:SetPoint( "TOP", Notes.Notes, "TOP", 0, 0 );
		dummyFontString:SetFont( Notes.Notes.Box:GetFont() )
		dummyFontString:SetShadowColor( 0, 0, 0, .6 ) 
		dummyFontString:SetShadowOffset( 1, -1 ) --this messed up my calculations and caused me CONFUSION AND ANGER for 30 minutes
		dummyFontString:SetJustifyH( "LEFT" )
		dummyFontString:SetText( "Dummy Object" )
		dummyFontString:SetWordWrap( true );
		dummyFontString:SetNonSpaceWrap( true );
		dummyFontString:Hide();
		
		
		
		
		
end






