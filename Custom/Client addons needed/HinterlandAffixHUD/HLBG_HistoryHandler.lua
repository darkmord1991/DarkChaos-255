-- HLBG_HistoryHandler.lua - Special handlers for History data in TSV format

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Only install chat filter if not already installed
if not HLBG._chatFilterInstalled then
    HLBG._chatFilterInstalled = true
    HLBG._originalChatFilter = DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage
    
    if DEFAULT_CHAT_FRAME and HLBG._originalChatFilter then
        DEFAULT_CHAT_FRAME.AddMessage = function(self, text, ...)
            if type(text) == "string" then
                -- Store history TSV for later processing
                if text:match("^%[HLBG_HISTORY_TSV%]") then
                    -- Store the raw message for later parsing
                    HLBG._lastHistoryTSV = text
                    
                    if HLBG._devMode then
                        print("HLBG HistoryHandler: Stored history TSV message:", string.sub(text, 1, 50))
                    end
                    
                    -- Process it directly with our specialized handler
                    local success = ProcessHistoryTSVMessage(text)
                    
                    -- Mark any pending history requests as complete
                    if HLBG.CompleteRequest then
                        HLBG.CompleteRequest("HISTORY")
                    end
                    
                    if success then
                        return -- Don't show the raw TSV in chat
                    end
                end
                
                -- Also check if this looks like a piped history entry: ID|timestamp|winner|affix|reason
                if text:match("^%d+|%d%d%d%d%-%d%d%-%d%d") then
                    -- This looks like a history row
                    if HLBG._devMode then
                        print("HLBG HistoryHandler: Found what appears to be a history row in chat")
                    end
                    
                    local id, ts, win, aff, rea = text:match("(%d+)|(.-)|(.-)|(.-)|(.+)")
                    if id then
                        local row = {
                            id = id,
                            ts = ts,
                            winner = win,
                            affix = aff,
                            reason = rea
                        }
                        
                        if HLBG._devMode then
                            print("HLBG HistoryHandler: Parsed history row:", id, ts, win, aff, rea)
                        end
                        
                        -- Display this single row
                        if HLBG.History and type(HLBG.History) == 'function' then
                            HLBG.History({row}, 1, 1, 1, "id", "DESC")
                            
                            -- Mark any pending history requests as complete
                            if HLBG.CompleteRequest then
                                HLBG.CompleteRequest("HISTORY")
                            end
                            
                            return -- Don't show the raw row in chat
                        end
                    end
                end
            end
            return HLBG._originalChatFilter(self, text, ...)
        end
    end
end

-- Process a history TSV message directly
function ProcessHistoryTSVMessage(text)
    if type(text) ~= 'string' then return false end
    
    print("HLBG HistoryHandler: Processing history TSV message:", text)
    
    -- Extract the TOTAL value if present
    local total = tonumber(text:match("TOTAL=(%d+)")) or 0
    
    -- Remove the prefix
    local dataText = text:gsub("^%[HLBG_HISTORY_TSV%]%s*TOTAL=%d+", "")
    
    -- Remove leading separators if any
    dataText = dataText:gsub("^%|+", "")
    
    -- Parse the data into rows
    local rows = {}
    
    -- From screenshot format: TOTAL=26|2|2025-10-03 09:16:42|DRAW|0|manual
    -- Try to parse fields separated by pipes
    local id, ts, win, aff, rea = dataText:match("(%d+)|(.-)|(.-)|(.-)|(.+)")
    if id then
        table.insert(rows, {
            id = id,
            ts = ts,
            winner = win,
            affix = aff,
            reason = rea
        })
        print("HLBG HistoryHandler: Parsed row:", id, ts, win, aff, rea)
    end
    
    -- If we have a total but no rows, create at least one row
    if #rows == 0 and total > 0 then
        -- Create a placeholder row
        table.insert(rows, {
            id = "?",
            ts = "Unable to parse data format",
            winner = "Please check", 
            affix = "0",
            reason = "server log"
        })
    end
    
    -- Call the history display function
    if HLBG.History and type(HLBG.History) == 'function' then
        HLBG.History(rows, 1, 10, total, "id", "DESC")
        return true
    end
    
    return false
end

-- Function to manually trigger history update from TSV
function HLBG.ProcessHistoryTSV(tsv, page, per, total, col, dir)
    page = page or 1
    per = per or 10
    col = col or "id"
    dir = dir or "DESC"
    
    print("HLBG HistoryHandler: Manual process of history TSV")
    
    -- First try to process as a specialized format from the screenshot
    if tsv:match("^%[HLBG_HISTORY_TSV%]") then
        if ProcessHistoryTSVMessage(tsv) then
            return
        end
    end
    
    -- If that didn't work, extract data directly
    local rows = {}
    
    -- Look for pipe-separated format as in screenshot
    for entry in tsv:gmatch("(%d+|.-|.-|.-|[^\n]+)") do
        local id, ts, win, aff, rea = entry:match("(%d+)|(.-)|(.-)|(.-)|(.+)")
        if id then
            table.insert(rows, {
                id = id,
                ts = ts,
                winner = win,
                affix = aff,
                reason = rea
            })
            print("HLBG HistoryHandler: Parsed pipe entry:", id, ts, win, aff, rea)
        end
    end
    
    -- If we found rows, display them
    if #rows > 0 then
        HLBG.History(rows, page, per, total or #rows, col, dir)
        return
    end
    
    -- Otherwise, fall back to the standard HistoryStr function
    if HLBG.HistoryStr and type(HLBG.HistoryStr) == 'function' then
        HLBG.HistoryStr(tsv, page, per, total, col, dir)
    end
end

-- Expose history handlers on HLBG table for central AIO registration
HLBG.HistoryTSV = HLBG.ProcessHistoryTSV