--[[
	Notes - An addon to create notes(/stickies) in game
	@author: aLeX^rS (alexrs@gmail.com)

]]

Notes.CommOut = {};
local NCommOut = Notes.CommOut;

FCommOut = nil;

local CommunicationReady = nil;
local COMMADDON_PREFIX = "SimplyNotes";



--[[
		Initialization of Communication related features...
]]

CommunicationReady = RegisterAddonMessagePrefix( COMMADDON_PREFIX );
NCommOut.ackPending = {}; --waiting for acknowledgement after sending... [targetName] = nil;
NCommOut.ackPending_timer = 0;


--[[
		Process Comm, in + out
]]
function NCommOut.OnUpdate( )
	NCommOut.ackPending_timer = NCommOut.ackPending_timer + 1;
	
	
	if NCommOut.ackPending_timer < 250 then
		return;
	end
	
	if NCommOut.ackPending_timer >= 250 then NCommOut.ackPending_timer = 0; end


	local sz = "";
	local i, v, k = 0;
	for k, v in pairs( NCommOut.ackPending ) do
		i = i + 1;
		
		NCommOut.ackPending[k]['elapsed'] = NCommOut.ackPending[k]['elapsed'] + 1;
		if not NCommOut.ackPending[k]['success'] then
			sz = sz .. string.format( "Sending [%s] - %d%%; ", v['target'], math.floor( (NCommOut.ackPending[k]['elapsed'] / 8) * 100 ));
		else
			sz = sz .. string.format( "Sending [%s] - %d%%; ", v['target'], math.floor( (8 / 8) * 100 ));
		end
		
		if NCommOut.ackPending[k]['elapsed'] > 7 or NCommOut.ackPending[k]['success'] then

			-- send the player a WHISPER indicating that someone has sent them a note, but they don't have Simply Notes 1.3.10 or greater
			if not NCommOut.ackPending[k]['success'] then
				Notes.ChatMsg( string.format( "%s failed to acknowledge receipt, sent them a whisper indicating they need Simply Notes 1.3.12 or greater!", NCommOut.ackPending[k]['target'] ) );
				SendChatMessage( "I've sent you a note, but you need [Simply Notes 1.3.10]+ to accept it! http://www.curse.com/addons/wow/notes-simple", "WHISPER", nil, NCommOut.ackPending[k]['target'] );
			end
			
			NCommOut.ackPending[k] = nil
			
		end
	end
	
	FCommOut.status:SetText( sz );
	
		
end

function NCommOut.OnEvent( frame, event, ... )
	if event == 'CHAT_MSG_ADDON' then
		if not NotesPref['DisableComm'] then
			Notes.CommOut.ProcessIn( ... );
		end
	end
end

function NCommOut.ProcessIn( ... )
	local prefix, message, channel, sender = ... ;
	if prefix == COMMADDON_PREFIX then
		
		
		if message == "ack" then
			if not NCommOut.ackPending[sender] then return; end
			NCommOut.ackPending[sender]['success'] = true;
			return;
		end
		
		if not NotesPref['Comm']['Ingore'] then NotesPref['Comm']['Ingore'] = {}; end
		local i, v = 0;
		
		for i, v in ipairs( NotesPref['Comm']['Ingore'] ) do
			if v == sender then
				return false;
			end
		end
		
		
		
		local headerLength = string.len( string.gsub( message, '^(Note;+[%d]+/[%d]+;).*', '%1' ) );
		local header = string.sub( message, 0, headerLength );
		local noteText = string.sub( message, headerLength +1, -1 );
		local part, parts, msgid = 	string.gsub( header, '^Note;+([%d]+)/[%d]+;.*', '%1' ),
									string.gsub( header, '^Note;+[%d]+/([%d]+);.*', '%1' ),
									sender;

		
		if not NotesPref['Comm'] then NotesPref['Comm'] = {}; end
		if not NotesPref['Comm']['PendingIn'] then NotesPref['Comm']['PendingIn'] = {}; end
		if not NotesPref['Comm']['PendingIn'][msgid] then NotesPref['Comm']['PendingIn'][msgid] = ''; end
		NotesPref['Comm']['PendingIn'][msgid] = NotesPref['Comm']['PendingIn'][msgid] .. noteText;
		
		
		Notes.DEBUG( 'RECV: Full message: ', message );
		Notes.DEBUG( 'RECV: part/parts: ', part, '/', parts );
		
		
		
		if part == parts then
			-- Show pending message, note is completely received...
			
			--send ack to source..
			SendAddonMessage( COMMADDON_PREFIX, "ack", "WHISPER", sender );
			
			if not Notes.inCombat then
				
				local btnConfirm = { "View Details", function() 
						--Notes.Notes:Hide()
						Notes.ConfirmBox:Hide();
						FCommOut:Show();
					end }
				local btnCancel = { "Later", function() Notes.ConfirmBox:Hide() end } 
				Notes.SetupConfirm( "Simply Notes", "You've received a note from ["..sender.."]. View more details?", btnCancel, btnConfirm )
				
				
				--FCommOut:Show();
			end
			
			Notes.ChatMsg( "Type |cffff5533/notes comm|r to view a note recieved from " .. sender );
			
			if not NotesPref['Comm']['PendingInComplete'] then
				NotesPref['Comm']['PendingInComplete'] = {};
			end
			
			local newNote = {};
			newNote['sender'] = sender;
			newNote['time'] = date();
			newNote['parts'] = parts;
			newNote['message'] = NotesPref['Comm']['PendingIn'][msgid];
			table.insert( NotesPref['Comm']['PendingInComplete'], newNote );
			
			NCommOut.RefreshPendingHTML();
			
			
			NotesPref['Comm']['PendingIn'][msgid] = nil;
			-- find this pendingnote's index and remove it
			local i, v = 0;
			for i,v in ipairs( NotesPref['Comm']['PendingIn'] ) do
				if not v then
					table.remove( NotesPref['Comm']['PendingIn'], i );
					break;
				end
			end
			
			
			
			
		end
			
	end
end

function NCommOut.ProcessOut(  )
	
	local header, headerLength = "Note;",
		string.len( COMMADDON_PREFIX .. "Note;00/00;"); --[[ this creates a limitation of max 99 parts..
															49,500 characters, due to throttling it's actually even less
														]]--
	local noteText = NotesData[Notes.Notes.pos][1];
	local noteLength = string.len(noteText); --514 is the cut-off
	local messageParts = math.floor( noteLength / ( 254  - headerLength ) );
	if noteLength % ( 254  - headerLength ) > 0 then
		messageParts = messageParts + 1;
	end
	
	local i, targetPlayer = 1, FCommOut.Box:GetText();
	FCommOut.Box:ClearFocus();
	FCommOut.SendButton:Disable();
	
	
	NotesPref["lastCommOutFriend"] = targetPlayer;
	--TODO: Check if player is valid? Same if the player is cross-realm???
	for i = 1, messageParts do
		local messagePart = string.sub( noteText, ((i - 1) * ( 254  - headerLength )), (((i - 1) * ( 254  - headerLength )) + 254  - headerLength)-1 );
		Notes.DEBUG( 'SENT: Getting part: string.sub( noteText, ',(i - 1) * ( 254  - headerLength ),',', ((i - 1) * ( 254  - headerLength )) + 254  - headerLength, ')' );
		SendAddonMessage( COMMADDON_PREFIX, string.format( "%s%d/%d;%s", header, i, messageParts, messagePart ), "WHISPER", targetPlayer );
		Notes.DEBUG( 'SENT: Full message: ', string.format( "%s%d/%d;%s", header, i, messageParts, messagePart ) );
	end
	
	FCommOut.SendButton:Enable();
	Notes.ChatMsg( string.format('Sent Note %d of %d to [%s]!', Notes.Notes.pos, #NotesData, targetPlayer) );
	
	local ack = {};
	ack['elapsed'] = 0;
	ack['target'] = targetPlayer;
	ack['sent'] = date();
	ack['success'] = false;
	NCommOut.ackPending[ targetPlayer ] = ack;
	
end


function NCommOut.RefreshPendingHTML()

	--FCommOut.Results:SetText("<html><body><p>Loading..</p></body></html>");
	local resultsHTML = nil;
	
	if not NotesPref['Comm'] then NotesPref['Comm'] = {}; end
	if not NotesPref['Comm']['PendingInComplete'] then NotesPref['Comm']['PendingInComplete'] = {}; end
	if not NotesPref['Comm']['PendingIn'] then NotesPref['Comm']['PendingIn'] = {}; end
	
	local i, v = 0;
	for i, v in ipairs( NotesPref['Comm']['PendingInComplete'] ) do
		resultsHTML = (resultsHTML or "") .. string.format("<p>A %s part note was received at %s from [%s] - " ..
						"|cffffff00<a href=\"note:accept;%d\">Accept</a>|r \| " ..
						"|cffffff00<a href=\"note:reject;%d\">Reject</a>|r \| " ..
						"|cffffff00<a href=\"note:ignore;%d\">Ignore this player</a>|r </p>", v['parts'] or "<?>", v['time'] or "<?>", v['sender'] or "<?>", i , i, i );
	end
	
	if not resultsHTML then
		resultsHTML = "<p>There aren't any notes pending approval!</p>";
	end
	
		
	FCommOutResults:SetText( string.format("<html><body><h1>Notes pending approval</h1><br/>%s</body></html>", resultsHTML ));
	FCommOutResults:GetParent():UpdateScrollChildRect();

end



function NCommOut.PendingNoteClick( self, linkData, link, button )
	
	local _, _, action, noteInd = linkData:find( "note:([%w]+);([%d]+)", 1 );

	if action == "accept" then
	
		Notes.DEBUG( 'Pending Note: ', action, noteInd );
		local newNote = NotesPref['Comm']['PendingInComplete'][ math.abs(noteInd) ];
		Notes.NoteNew( newNote['message'] );
		local deleted = table.remove( NotesPref['Comm']['PendingInComplete'], math.abs(noteInd) );
		FCommOut:Hide();
		
	elseif action == "reject" then
		Notes.DEBUG( 'Pending Note: ', action, noteInd );
		local deleted = table.remove( NotesPref['Comm']['PendingInComplete'], math.abs(noteInd) );
		FCommOut:Hide();
		
	elseif action == "ignore" then
		
		local newNote = NotesPref['Comm']['PendingInComplete'][ math.abs(noteInd) ];
		local ignorePlayer = newNote['sender'];
		
		if not NotesPref['Comm']['Ingore'] then NotesPref['Comm']['Ingore'] = {}; end
		table.insert( NotesPref['Comm']['Ingore'], ignorePlayer );
		
		
		local deleted = table.remove( NotesPref['Comm']['PendingInComplete'], math.abs(noteInd) );
		FCommOut:Hide();
			
	end
	
end


--[[
==================================================================================
================================== FRAMES ========================================
==================================================================================
								OUT ONLY
]]



Notes.Notes.CommOutFrame = CreateFrame( "Frame", "NotesCommOutFrame", UIParent,  BackdropTemplateMixin and "BackdropTemplate" )
Notes.Notes.CommOutFrame:Hide( )
Notes.Notes.CommOutFrame:SetPoint( "CENTER", Notes.Notes, "CENTER" )
Notes.Notes.CommOutFrame:SetFrameStrata( "DIALOG" )
Notes.Notes.CommOutFrame:EnableMouse( true )
Notes.Notes.CommOutFrame:SetHeight( 350 )
Notes.Notes.CommOutFrame:SetWidth( 400 )
Notes.Notes.CommOutFrame:SetBackdrop({
		bgFile = "Interface/Tooltips/ChatBubble-Background",
		edgeFile = "Interface/Tooltips/ChatBubble-BackDrop",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 32, right = 32, top = 32, bottom = 32 }
	})
Notes.Notes.CommOutFrame:SetBackdropColor( 0, 0, 0, 1 )
Notes.Notes.CommOutFrame:SetBackdropBorderColor( .25, .25, 0, 1 )
Notes.Notes.CommOutFrame:SetScript( "OnMouseDown", function( self, button ) if button == "LeftButton" then Notes.Notes.CommOutFrame:StartMoving() end end )
Notes.Notes.CommOutFrame:SetScript( "OnMouseUp", function( self, button ) if button == "LeftButton" then Notes.Notes.CommOutFrame:StopMovingOrSizing() end end )
Notes.Notes.CommOutFrame:SetScript( "OnShow", function(self) NCommOut.RefreshPendingHTML(); end );
Notes.Notes.CommOutFrame:SetScript( "OnUpdate", NCommOut.OnUpdate );

Notes.Notes.CommOutFrame:SetMovable( true )
Notes.Notes.CommOutFrame:SetMinResize( 368, 100 )
Notes.Notes.CommOutFrame:SetClampedToScreen( true )

FCommOut = Notes.Notes.CommOutFrame;


FCommOut:SetScript( "OnEvent", NCommOut.OnEvent );
FCommOut:RegisterEvent( "CHAT_MSG_ADDON" );




FCommOut.TitleBar = CreateFrame( "Button", nil, FCommOut,  BackdropTemplateMixin and "BackdropTemplate" )
FCommOut.TitleBar:SetPoint( "TOPLEFT", FCommOut, "TOPLEFT", 10, -5 )
FCommOut.TitleBar:SetPoint( "TOPRIGHT", FCommOut, "TOPRIGHT", -10, -5 )
FCommOut.TitleBar:SetHeight( 13 )
FCommOut.TitleBar:SetNormalTexture( Notes.NOTES_ART_PATH.."bar" ) 
FCommOut.TitleBar:SetHighlightTexture( "Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar" ) -- -Blue
FCommOut.TitleBar:SetAlpha( 0.5 )
FCommOut.TitleBar:EnableMouse( false )







FCommOut.Title = FCommOut:CreateFontString( "", "OVERLAY", "GameFontNormal" )
FCommOut.Title:SetFontObject( GameFontNormal )
FCommOut.Title:SetJustifyH( "CENTER" )
FCommOut.Title:SetAllPoints( FCommOut.TitleBar )
FCommOut.Title:SetText( "SimplyNotes - Send Note" )
FCommOut.Title:SetShadowColor( 0, 0, 0, .5 )
FCommOut.Title:SetShadowOffset( 1, -1 )
FCommOut.Title:SetTextColor( 1, 1, 1, 1 );

do
		
		
		local fntTarget = FCommOut:CreateFontString( "", "OVERLAY", "GameFontNormalSmall" );
		fntTarget:SetJustifyH( "LEFT" )
		fntTarget:SetPoint( "TOP", FCommOut.TitleBar, "BOTTOM", -10, -15 )
		fntTarget:SetPoint( "LEFT", FCommOut, "LEFT", 15, 0 )
		fntTarget:SetHeight( 29 )
		fntTarget:SetText( "Player Target: " )
		
		
		FCommOut.status = FCommOut:CreateFontString( "", "OVERLAY", "GameFontNormalSmall" );
		FCommOut.status:SetJustifyH( "LEFT" )
		FCommOut.status:SetPoint( "TOP", fntTarget, "BOTTOM", -10, -15 )
		FCommOut.status:SetPoint( "LEFT", FCommOut, "LEFT", 15, 0 )
		FCommOut.status:SetHeight( 29 )
		FCommOut.status:SetText( " " )
		
		
		
		FCommOut.Box = CreateFrame( "EditBox", "NotesFriendEditBox", FCommOut,  BackdropTemplateMixin and "BackdropTemplate" )
		FCommOut.Box:SetWidth( 227 )
		FCommOut.Box:SetHeight( 32 )
		FCommOut.Box:SetPoint( "TOP", FCommOut.TitleBar, "BOTTOM", -10, -15 )
		FCommOut.Box:SetPoint( "LEFT", fntTarget, "RIGHT", 15, 0 )
		FCommOut.Box:SetMultiLine( false )
		FCommOut.Box:SetAutoFocus( false )
		FCommOut.Box:SetFontObject( GameFontHighlight )
		FCommOut.Box:SetShadowColor( 0, 0, 0, .6 )
		FCommOut.Box:SetShadowOffset( 1, -1 )
		FCommOut.Box:SetScript( "OnShow", function( self )
				if not NotesPref["lastCommOutFriend"] then NotesPref["lastCommOutFriend"] = ""; end
				self:SetText( NotesPref["lastCommOutFriend"] );
			end );
		FCommOut.Box:SetScript( "OnEscapePressed", function(...) FCommOut.Box:ClearFocus() end )
		FCommOut.Box:Show();
		
		FCommOut.Box:SetTextInsets( 5, 1, 5, 1 );
		
		FCommOut.Box:SetBackdrop({
			bgFile = "Interface/Tooltips/ChatBubble-Background",
			edgeFile = "Interface/Tooltips/ChatBubble-BackDrop",
			tile = true, tileSize = 32, edgeSize = 8,
			insets = { left = 8, right = 5, top = 5, bottom = 5 }
		})
		
		
		
		FCommOut.FriendsDD = CreateFrame( "Button", "", FCommOut, "OptionsButtonTemplate" )
		FCommOut.FriendsDD:SetText( "..." )
		FCommOut.FriendsDD:SetPoint( "BOTTOMLEFT", FCommOut.Box, "BOTTOMRIGHT", 5, 0 )
		FCommOut.FriendsDD:SetWidth( 40 );
		FCommOut.FriendsDD:SetHeight( FCommOut.Box:GetHeight() );
		
		FCommOut.FriendsDD:SetScript( "OnClick", Notes.DropDownMenu.OnClick )

		FCommOut.FriendsDD.initMenuFunc = function( self, level )
			if not level then return end
			local info = self.info
			wipe(info)
			if level == 1 then
						
				
				info.disabled     = nil
				info.isTitle      = nil
				info.notCheckable = 1
		
				local i, y, z = 1, 0, GetNumFriends();
				if z >= 1 then
					--local name, _, _, _, connected, status, _, _ = nil;
					for i = 1, z do
						local name, _, _, _, connected, status, _, _ = GetFriendInfo( i );
						
						if connected then
							y = y + 1
							info.text = name
							info.func = function() FCommOut.Box:SetText( name ) end
							info.checked = nil
							info.tooltipTitle = nil
							info.tooltipText = nil
							UIDropDownMenu_AddButton(info, level)
						end
						
					end
				end
				
				if y == 0 then
					info.text = "<No online friends>"
					info.func = nil
					info.checked = nil
					info.tooltipTitle = nil
					info.tooltipText = nil
					info.disabled = 1
					UIDropDownMenu_AddButton(info, level)
				end

				
				info.disabled     = nil
				info.text         = CLOSE
				info.func         = self.HideMenu
				info.checked      = nil
				info.arg1         = nil
				info.tooltipTitle = CLOSE
				UIDropDownMenu_AddButton(info, level)
			end
		end
		
		
		FCommOut.SendButton = CreateFrame( "Button", "", FCommOut, "OptionsButtonTemplate" )
		FCommOut.SendButton:SetText( "Send Note" )
		FCommOut.SendButton:SetPoint( "TOPRIGHT", FCommOut.FriendsDD, "BOTTOMRIGHT", 0, -10 )
		FCommOut.SendButton:SetScript( "OnClick", function( self ) NCommOut.ProcessOut() end )
		FCommOut.SendButton:SetWidth(100);
		
		
		
		
				
		local fntstr = FCommOut:CreateFontString( "", "OVERLAY", "GameFontNormalSmall" );
		fntstr:SetJustifyH( "LEFT" )
		fntstr:SetPoint( "TOP", FCommOut.SendButton, "BOTTOM", -10, -15 )
		fntstr:SetPoint( "LEFT", FCommOut, "LEFT", 15, 0 )
		fntstr:SetHeight( 29 )
		fntstr:SetText( " " );
		
		
		
		
		FCommOut.CloseButton = CreateFrame( "Button", "", FCommOut, "OptionsButtonTemplate" )
		FCommOut.CloseButton:SetText( "Close" )
		FCommOut.CloseButton:SetPoint( "BOTTOMRIGHT", FCommOut, "BOTTOMRIGHT", -15, 25 )
		FCommOut.CloseButton:SetScript( "OnClick", function( self ) self:GetParent():Hide() end )
		
		
		FCommOut.IgnoreButton = CreateFrame( "Button", "", FCommOut, "OptionsButtonTemplate" )
		FCommOut.IgnoreButton:SetText( "Blocked Players" )
		FCommOut.IgnoreButton:SetWidth( FCommOut.IgnoreButton:GetWidth() + 30 );
		FCommOut.IgnoreButton:SetPoint( "BOTTOMLEFT", FCommOut, "BOTTOMLEFT", 15, 25 )		
		FCommOut.IgnoreButton:SetScript( "OnClick", Notes.DropDownMenu.OnClick )

		FCommOut.IgnoreButton.initMenuFunc = function( self, level )
			if not level then return end
			local info = self.info
			wipe(info)
			if level == 1 then
						
				
				info.isTitle = 1
				info.text = "-Unblock Player-"
				info.func = nil
				info.notCheckable = 1
				info.checked = nil
				info.tooltipTitle = nil
				info.tooltipText = nil
				info.disabled = nil
				UIDropDownMenu_AddButton(info, level)
				
				
				info.disabled     = nil
				info.isTitle      = nil
				info.notCheckable = 1
		
				local i, v = 0;
				if not NotesPref['Comm']['Ingore'] then NotesPref['Comm']['Ingore'] = {}; end
				for i, v in ipairs( NotesPref['Comm']['Ingore'] ) do
						
					local playerName = v;
					info.text = playerName
					info.func = function()
						local i, v = 0;
						for i, v in ipairs( NotesPref['Comm']['Ingore'] ) do
							if v == playerName then
								table.remove( NotesPref['Comm']['Ingore'], i );
							end
						end
						self:HideMenu();
					end
					info.checked = nil
					info.notCheckable = 1
					info.tooltipTitle = nil
					info.tooltipText = nil
					UIDropDownMenu_AddButton(info, level)
					
				end

				if #NotesPref['Comm']['Ingore'] == 0 then
					info.text = "<No Blocked Players>"
					info.func = nil
					info.checked = nil
					info.notCheckable = 1
					info.tooltipTitle = nil
					info.tooltipText = nil
					info.disabled = 1
					UIDropDownMenu_AddButton(info, level)
				end

				
				info.disabled     = nil
				info.text         = CLOSE
				info.func         = self.HideMenu
				info.checked      = nil
				info.arg1         = nil
				info.tooltipTitle = CLOSE
				UIDropDownMenu_AddButton(info, level)
			end
		end
		
		
		
		
		FCommOut.Scroll = CreateFrame( "ScrollFrame", "FCommOutScroll", FCommOut, "UIPanelScrollFrameTemplate" );
		FCommOut.Scroll:SetPoint( "LEFT", FCommOut, "LEFT", 10, 0 );
		FCommOut.Scroll:SetPoint( "RIGHT", FCommOut, "RIGHT", -35, 0 );
		FCommOut.Scroll:SetPoint( "TOP", fntstr, "BOTTOM", 5, 0 );
		FCommOut.Scroll:SetPoint( "BOTTOM", FCommOut.CloseButton, "TOP", 0, 10 );
		
		
		FCommOut.Results = CreateFrame( "SimpleHTML", "FCommOutResults", FCommOut.Scroll,  BackdropTemplateMixin and "BackdropTemplate" );
		FCommOut.Scroll:SetScrollChild( FCommOut.Results );
		FCommOut.Results:Show();
		--FCommOut.Results:SetAllPoints( FCommOut.Scroll );
		FCommOut.Results:SetWidth( FCommOut.Scroll:GetWidth() );
		FCommOut.Results:SetHeight( 85 );

		FCommOut.Results:SetHyperlinksEnabled( true );
		FCommOut.Results:SetFontObject( GameFontHighlight );
		FCommOut.Results:SetScript( "OnHyperlinkClick", NCommOut.PendingNoteClick );
		FCommOut.Results:SetFontObject( "h1", GameFontHighlightLarge );
		FCommOut.Results:SetTextColor( "h1", 1, 1, 0.6, 1 );
		FCommOut.Results:SetSpacing( 3 )
		local filename, fh, flags = FCommOut.Results:GetFont( )
		FCommOut.Results:SetFont( filename, 10, "" )
		
		
		
		
end






