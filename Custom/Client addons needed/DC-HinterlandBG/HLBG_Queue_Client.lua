-- HLBG_Queue_Client.lua
-- Client-side queue system integration for Hinterland BG
-- Part of the DC HLBG Addon (merge into HLBG_Handlers.lua if you prefer a single file)
local HLBG = _G.HLBG or {}; _G.HLBG = HLBG
-- Queue state tracking
HLBG.IsInQueue = false
HLBG.QueuePosition = 0
HLBG.QueueTotal = 0
HLBG.BattleState = "UNKNOWN"
-- Request current queue status from server
function HLBG.RequestQueueStatus()
    if AIO and AIO.Handle then
        AIO.Handle("HLBG", "RequestQueueStatus", "")
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Requesting queue status via AIO...")
        end
    else
        -- Fallback: use chat command
        local cmd = ".hlbgq status"
        local editBox = DEFAULT_CHAT_FRAME.editBox or ChatFrame1EditBox
        if editBox then
            editBox:SetText(cmd)
            ChatEdit_SendText(editBox, 0)
        end
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Requesting queue status via command...")
        end
    end
end
-- Join the battleground queue
function HLBG.JoinQueue()
    if AIO and AIO.Handle then
        AIO.Handle("HLBG", "JoinQueue", "")
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Joining queue via AIO...")
        end
    else
        -- Fallback: use chat command
        local cmd = ".hlbgq join"
        local editBox = DEFAULT_CHAT_FRAME.editBox or ChatFrame1EditBox
        if editBox then
            editBox:SetText(cmd)
            ChatEdit_SendText(editBox, 0)
        end
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Joining queue via command...")
        end
    end
end
-- Leave the battleground queue
function HLBG.LeaveQueue()
    if AIO and AIO.Handle then
        AIO.Handle("HLBG", "LeaveQueue", "")
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Leaving queue via AIO...")
        end
    else
        -- Fallback: use chat command
        local cmd = ".hlbgq leave"
        local editBox = DEFAULT_CHAT_FRAME.editBox or ChatFrame1EditBox
        if editBox then
            editBox:SetText(cmd)
            ChatEdit_SendText(editBox, 0)
        end
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Leaving queue via command...")
        end
    end
end
-- Handle QUEUE_STATUS response from server
function HLBG.HandleQueueStatus(statusString)
    if type(statusString) ~= 'string' then return end
    -- Debug: Show what we received
    if DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF33FF99HLBG Queue Debug:|r Received status: %s", statusString))
    end
    -- Parse status packet - support multiple formats:
    -- Format 1: "QUEUE_STATUS|IN_QUEUE=1|POSITION=5|TOTAL=12|STATE=WAITING"
    -- Format 2: "IN_QUEUE=1 POSITION=5 TOTAL=12 STATE=WAITING"
    -- Format 3: Simple text like "Not in queue" or "Position: 1/5"
    local inQueue = false
    local position = 0
    local total = 0
    local state = "UNKNOWN"
    -- Try structured format first
    if statusString:match("IN_QUEUE=") then
        inQueue = statusString:match("IN_QUEUE=(%d)") == "1"
        position = tonumber(statusString:match("POSITION=(%d+)")) or 0
        total = tonumber(statusString:match("TOTAL=(%d+)")) or 0
        state = statusString:match("STATE=(%w+)") or "UNKNOWN"
    -- Try simple text format
    elseif statusString:lower():match("not in queue") or statusString:lower():match("not queued") then
        inQueue = false
        position = 0
        total = 0
        state = "NOT_QUEUED"
    elseif statusString:match("(%d+)%s*/") or statusString:match("position[:%s]+(%d+)") then
        inQueue = true
        position = tonumber(statusString:match("(%d+)%s*/") or statusString:match("position[:%s]+(%d+)")) or 1
        total = tonumber(statusString:match("/%s*(%d+)") or statusString:match("total[:%s]+(%d+)")) or position
        state = "WAITING"
    else
        -- Unknown format - show as-is
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFAA00HLBG Queue:|r %s", statusString))
        end
        return
    end
    -- Update global state
    HLBG.IsInQueue = inQueue
    HLBG.QueuePosition = position
    HLBG.QueueTotal = total
    HLBG.BattleState = state
    -- Map state to friendly string
    local stateDisplay = state
    if state == "WAITING" then
        stateDisplay = "|cFFAAAA00Waiting for players|r"
    elseif state == "WARMUP" then
        stateDisplay = "|cFF00FF00Warmup - Battle starting soon!|r"
    elseif state == "IN_PROGRESS" then
        stateDisplay = "|cFFFF0000Battle in progress|r"
    elseif state == "ENDING" then
        stateDisplay = "|cFFFFAA00Battle ending|r"
    end
    -- Update UI if Queue tab exists
    if HLBG.UI and HLBG.UI.Queue then
        if HLBG.UI.Queue.StatusText then
            if inQueue then
                HLBG.UI.Queue.StatusText:SetText(string.format(
                    "|cFF00FF00You are in the queue!|r\n\n" ..
                    "|cFFFFD700Position:|r %d / %d\n" ..
                    "|cFFFFD700Battle State:|r %s\n\n" ..
                    "You will be teleported when the battle starts.",
                    position, total, stateDisplay))
            else
                if total > 0 then
                    HLBG.UI.Queue.StatusText:SetText(string.format(
                        "|cFFAAAAANot in queue|r\n\n" ..
                        "%d player(s) currently queued\n" ..
                        "|cFFFFD700Battle State:|r %s\n\n" ..
                        "Click 'Join Queue' to participate in the next battle.",
                        total, stateDisplay))
                else
                    HLBG.UI.Queue.StatusText:SetText(string.format(
                        "|cFFAAAAANot in queue|r\n\n" ..
                        "No players queued\n" ..
                        "|cFFFFD700Battle State:|r %s\n\n" ..
                        "Be the first to join!",
                        stateDisplay))
                end
            end
        end
        -- Update button text and color based on queue state
        if HLBG.UI.Queue.JoinButton then
            if inQueue then
                HLBG.UI.Queue.JoinButton:SetText("Leave Queue")
                -- Set red color for Leave
                if HLBG.UI.Queue.JoinButton.GetFontString and HLBG.UI.Queue.JoinButton:GetFontString() then
                    HLBG.UI.Queue.JoinButton:GetFontString():SetTextColor(1, 0.2, 0.2, 1)  -- Red
                end
            else
                HLBG.UI.Queue.JoinButton:SetText("Join Queue")
                -- Set green color for Join
                if HLBG.UI.Queue.JoinButton.GetFontString and HLBG.UI.Queue.JoinButton:GetFontString() then
                    HLBG.UI.Queue.JoinButton:GetFontString():SetTextColor(0.2, 1, 0.2, 1)  -- Green
                end
            end
        end
    end
    -- Debug output
    if DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cFF33FF99HLBG Queue:|r InQueue=%s Pos=%d/%d State=%s",
            tostring(inQueue), position, total, state))
    end
end
-- Auto-refresh queue status every 10 seconds if Queue tab is visible
local lastQueueRefresh = 0
local QUEUE_REFRESH_INTERVAL = 10  -- seconds
local function AutoRefreshQueue()
    local now = GetTime()
    if now - lastQueueRefresh >= QUEUE_REFRESH_INTERVAL then
        -- Only refresh if Queue tab is active
        if HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame:IsShown() and HLBG.UI.Queue and HLBG.UI.Queue:IsShown() then
            HLBG.RequestQueueStatus()
            lastQueueRefresh = now
        end
    end
end
-- Hook into OnUpdate for auto-refresh (or use a C_Timer)
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(QUEUE_REFRESH_INTERVAL, function()
        pcall(AutoRefreshQueue)
    end)
end
-- Slash command for quick queue access
SLASH_HLBGQ1 = '/hlbgqueue'
SLASH_HLBGQ2 = '/hlbgq'
SlashCmdList['HLBGQ'] = function(msg)
    msg = strlower(msg or "")
    if msg == "join" or msg == "j" then
        HLBG.JoinQueue()
    elseif msg == "leave" or msg == "l" then
        HLBG.LeaveQueue()
    elseif msg == "status" or msg == "s" or msg == "" then
        HLBG.RequestQueueStatus()
    else
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700HLBG Queue Commands:|r")
            DEFAULT_CHAT_FRAME:AddMessage("  /hlbgq status (or /hlbgq) - Check queue status")
            DEFAULT_CHAT_FRAME:AddMessage("  /hlbgq join - Join the queue")
            DEFAULT_CHAT_FRAME:AddMessage("  /hlbgq leave - Leave the queue")
        end
    end
end
-- Integration with existing AIO message handler
-- Add this to your CHAT_MSG_ADDON handler in HLBG_Handlers.lua:
--
-- if prefix == "HLBG" and msg:match("^QUEUE_STATUS") then
--     HLBG.HandleQueueStatus(msg)
--     return
-- end
-- Debug announce
if DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG Debug:|r Queue client functions loaded. Type /hlbgq for commands.")
end

