--[[
	Notes - An addon to create notes(/stickies) in game
	@author: aLeX^rS (alexrs@gmail.com)
	
	Undo feature:
		Will store, 38 operations in memory
		Once 38 operations have been stored, instead of truncate the data(limiting it) 
		the operations which are most related to each other will be compressed
]]


local NOTES_UNDO_MAX = 35

Notes.NotesDataHistory = {}; 
Notes.NotesDataHistoryReverse = {}; 


-- @ void :URHist_Undo( bool undo ) ; Performs an undo OR redo operation on the current note text
function Notes.URHist_Undo( undo )
	local cLen = #Notes.NotesDataHistory;
	Notes.URHist_Undoing = true -- FLAG, so when TextChange event occurs, it won't result in a save to history...
	
	local edBox = Notes.Notes.Box
	if undo then
		if cLen == 0 then return; end
		--Notes.DEBUG( "UNDO: Going to UNDO, Ctrl+z" )
		local oldText, revText, cpos = Notes.NotesDataHistory[ cLen ], table.remove( Notes.NotesDataHistory, cLen ), Notes.Notes.Box:GetCursorPosition()
		tinsert( Notes.NotesDataHistoryReverse, revText )
		--tinsert( Notes.NotesDataHistoryReverse, { edBox:GetText(), cpos } )
		edBox:SetText( oldText[1] )
		edBox:SetCursorPosition( oldText[2] or 0 )
	else
		--redo
		--Notes.DEBUG( "UNDO: Going to REDO, Ctrl+y" )
		if #Notes.NotesDataHistoryReverse > 0 then
			local sz = table.remove( Notes.NotesDataHistoryReverse, #Notes.NotesDataHistoryReverse )
			edBox:SetText( sz[1] )
			tinsert( Notes.NotesDataHistory, sz )
			edBox:SetCursorPosition( sz[2] )
		end
	end
	
end

-- @ void :URHist_Reset( void ) ; Resets UNDO/REDO data, called when a new note is shown
function Notes.URHist_Reset( )
	Notes.DEBUG( "UNDO: Resetting..." )
	Notes.NotesDataHistory = {}
	Notes.NotesDataHistoryReverse = {}
end

-- @ void :URHist_Add( str text, int index ) ; Addes an UNDO step
function Notes.URHist_Add( text, cpos )


	if Notes.URHist_Undoing then 
		Notes.URHist_Undoing = nil
		return 
	end;
	
	--lets see if this is a duplicate
	if #Notes.NotesDataHistory > 0 and Notes.NotesDataHistory[ #Notes.NotesDataHistory ][1]:trim() == text:trim() then
		return;
	end
	
	local cLen = #Notes.NotesDataHistory;
	if (cLen + 1) >= NOTES_UNDO_MAX then
		Notes.URHist_Remove( )		
	end

	local tblHistory = { text, cpos or 0, GetTime() }
	tinsert( Notes.NotesDataHistory, tblHistory )

end

-- @ void :URHist_Remove( void ) ; POPs off the oldes(index 1) undo step
function Notes.URHist_Remove( )
	
	-- New compression technique... Let's find the three most suquential similar undos
	local seriesOfTwo = {};
	local shortestDurationIndex, shortestDurationVal = nil;
	for k, v in ipairs( Notes.NotesDataHistory ) do
		if k <= 2 then
			--shortestDurationIndex = v[3];
		else
			if not shortestDurationIndex or Notes.NotesDataHistory[k][3] - Notes.NotesDataHistory[k - 1][3] < shortestDurationVal then
				shortestDurationIndex = k;
				shortestDurationVal = Notes.NotesDataHistory[k][3] - Notes.NotesDataHistory[k - 1][3];
			end
		end
	end
	
	-- shortest duration found so far is index shortestDurationIndex, and the item to it's left
	table.insert( seriesOfTwo, { shortestDurationIndex - 1, nil } );
	table.insert( seriesOfTwo, { shortestDurationIndex, shortestDurationVal } );
	
	local tempElapsed = Notes.NotesDataHistory[shortestDurationIndex - 1][3] - Notes.NotesDataHistory[shortestDurationIndex - 2][3];
	if shortestDurationIndex == #Notes.NotesDataHistory or tempElapsed < Notes.NotesDataHistory[shortestDurationIndex + 1][3] - Notes.NotesDataHistory[shortestDurationIndex][3] then
		-- The item to left of shortestDurationIndex is more related, or is the NEWEST undo
		table.insert( seriesOfTwo, 1, { shortestDurationIndex - 2, nil });
	else
		-- The item to the right of shortestDurationIndex is more related
		table.insert( seriesOfTwo, { shortestDurationIndex + 1, nil } );
	end
	
	--Notes.DEBUG( "Series of three: ", seriesOfTwo[1][1], seriesOfTwo[2][1], seriesOfTwo[3][1] );
	--Notes.DEBUG( "Interested in deleting: ", seriesOfTwo[2][1] );
	
	if seriesOfTwo[2][1] >= 1 and seriesOfTwo[2][1] <= #Notes.NotesDataHistory then
		return table.remove( Notes.NotesDataHistory, seriesOfTwo[2][1] );
	end
	
end