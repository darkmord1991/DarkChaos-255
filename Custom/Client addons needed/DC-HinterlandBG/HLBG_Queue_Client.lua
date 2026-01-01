-- HLBG_Queue_Client.lua
-- Client-side queue system integration for Hinterland BG
local HLBG = _G.HLBG or {}; _G.HLBG = HLBG

-- Queue state tracking
HLBG.IsInQueue = false
HLBG.QueuePosition = 0
HLBG.QueueTotal = 0
HLBG.AllianceQueued = 0
HLBG.HordeQueued = 0
HLBG.MinPlayersToStart = 10
HLBG.EstimatedWaitSeconds = 0
HLBG.BattleState = "UNKNOWN"

local BG_STATE_MAP = {
    [0] = "WARMUP",
    [1] = "IN_PROGRESS",
    [2] = "PAUSED",
    [3] = "ENDING",
    [4] = "WAITING"
}

-- Request current queue status from server
function HLBG.RequestQueueStatus()
    local DC = _G.DCAddonProtocol
    if DC and DC.Send then
        -- Send via DC Protocol (HLBG module op 0x01 = CMSG_REQUEST_STATUS)
        -- See DCAddonNamespace.h: CMSG_REQUEST_STATUS = 0x01
        DC:Send("HLBG", 1)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Requesting queue status via DCAddonProtocol (opcode 1)...")
        end
    elseif AIO and AIO.Handle then
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
    local DC = _G.DCAddonProtocol
    if DC and DC.Send then
        -- CMSG_QUICK_QUEUE = 0x04
        DC:Send("HLBG", 4)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Joining queue via DCAddonProtocol (opcode 4)...")
        end
    elseif AIO and AIO.Handle then
        AIO.Handle("HLBG", "JoinQueue", "")
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Joining queue via AIO...")
        end
    else
        -- Fallback: use chat command
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00HLBG:|r No DC Protocol or AIO found. Using command fallback...")
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00HLBG:|r Please type: |cFFFFFFFF.hlbgq join|r or talk to the Battlemaster NPC.")
        end
        
        -- Try to execute command
        local cmd = ".hlbgq join"
        local editBox = DEFAULT_CHAT_FRAME.editBox or ChatFrame1EditBox
        if editBox then
            editBox:SetText(cmd)
            ChatEdit_SendText(editBox, 0)
        end
    end
end

-- Leave the battleground queue
function HLBG.LeaveQueue()
    local DC = _G.DCAddonProtocol
    if DC and DC.Send then
        -- CMSG_LEAVE_QUEUE = 0x05
        DC:Send("HLBG", 5)
        if DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99HLBG:|r Leaving queue via DC...")
        end
    elseif AIO and AIO.Handle then
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

-- Update UI elements based on current state
function HLBG.UpdateQueueUI()
    local inQueue = HLBG.IsInQueue
    local position = HLBG.QueuePosition
    local total = HLBG.QueueTotal
    local allianceCount = HLBG.AllianceQueued or 0
    local hordeCount = HLBG.HordeQueued or 0
    local minPlayers = HLBG.MinPlayersToStart or 10
    local estWaitSeconds = HLBG.EstimatedWaitSeconds or 0
    local state = HLBG.BattleState or "UNKNOWN"
    
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
    
    -- Format estimated wait time
    local estWaitDisplay = ""
    if estWaitSeconds > 0 then
        if estWaitSeconds >= 60 then
            estWaitDisplay = string.format("%d min %d sec", math.floor(estWaitSeconds / 60), estWaitSeconds % 60)
        else
            estWaitDisplay = string.format("%d sec", estWaitSeconds)
        end
    else
        estWaitDisplay = "Starting soon!"
    end

    -- Update UI if Queue tab exists
    if HLBG.UI and HLBG.UI.Queue then
        if HLBG.UI.Queue.StatusText then
            if inQueue then
                HLBG.UI.Queue.StatusText:SetText(string.format(
                    "|cFF00FF00You are in the queue!|r\n\n" ..
                    "|cFFFFD700Position:|r %d / %d\n" ..
                    "|cFF00AAFFAlliance:|r %d  |cFFFF4444Horde:|r %d\n" ..
                    "|cFFFFD700Est. Wait:|r %s\n" ..
                    "|cFFFFD700Battle State:|r %s\n\n" ..
                    "You will be teleported when the battle starts.",
                    position, total, allianceCount, hordeCount, estWaitDisplay, stateDisplay))
            else
                local playersNeeded = math.max(0, minPlayers - total)
                local neededStr = playersNeeded > 0
                    and string.format("|cFFFF4444Need %d more players|r", playersNeeded)
                    or "|cFF00FF00Ready to start!|r"

                if total > 0 then
                    HLBG.UI.Queue.StatusText:SetText(string.format(
                        "|cFFAAAAANot in queue|r\n\n" ..
                        "%d / %d player(s) queued\n" ..
                        "|cFF00AAFFAlliance:|r %d  |cFFFF4444Horde:|r %d\n" ..
                        "%s\n" ..
                        "|cFFFFD700Battle State:|r %s\n\n" ..
                        "Click 'Join Queue' to participate in the next battle.",
                        total, minPlayers, allianceCount, hordeCount, neededStr, stateDisplay))
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
end

-- Handle structured update from DC Protocol
function HLBG.HandleQueueStatusRaw(queueStatus, position, estimatedTime, totalQueued, allianceQueued, hordeQueued, minPlayers, stateInt)
    local inQueue = (tonumber(queueStatus) == 1)
    local state = BG_STATE_MAP[tonumber(stateInt)] or "UNKNOWN"
    
    -- Update global state
    HLBG.IsInQueue = inQueue
    HLBG.QueuePosition = tonumber(position) or 0
    HLBG.QueueTotal = tonumber(totalQueued) or 0
    HLBG.AllianceQueued = tonumber(allianceQueued) or 0
    HLBG.HordeQueued = tonumber(hordeQueued) or 0
    HLBG.MinPlayersToStart = tonumber(minPlayers) or 10
    HLBG.EstimatedWaitSeconds = tonumber(estimatedTime) or 0
    -- Map old unknown states if needed, but for now trust the stateInt
    HLBG.BattleState = state
    
    HLBG.UpdateQueueUI()
    
    -- Debug output
    if DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cFF33FF99HLBG Queue(DC):|r InQueue=%s Pos=%d/%d A=%d H=%d Est=%ds State=%s",
            tostring(inQueue), HLBG.QueuePosition, HLBG.QueueTotal, HLBG.AllianceQueued, HLBG.HordeQueued, HLBG.EstimatedWaitSeconds, HLBG.BattleState))
    end
end

-- Handle QUEUE_STATUS response from server (Legacy AIO/String)
function HLBG.HandleQueueStatus(statusString)
    if type(statusString) ~= 'string' then return end
    -- Debug: Show what we received
    if DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF33FF99HLBG Queue Debug:|r Received status: %s", statusString))
    end
    -- Parse status packet - support multiple formats:
    -- Format 1: "QUEUE_STATUS|IN_QUEUE=1|POSITION=5|WAIT_TIME=30|TOTAL=12|ALLIANCE=6|HORDE=6|MIN_PLAYERS=10|EST_WAIT=120|STATE=WAITING"
    -- Format 2: Legacy simple text
    local inQueue = false
    local position = 0
    local total = 0
    local allianceCount = 0
    local hordeCount = 0
    local minPlayers = 10
    local estWaitSeconds = 0
    local waitTime = 0
    local state = "UNKNOWN"

    -- Try structured format first
    if statusString:match("IN_QUEUE=") then
        inQueue = statusString:match("IN_QUEUE=(%d)") == "1"
        position = tonumber(statusString:match("POSITION=(%d+)")) or 0
        total = tonumber(statusString:match("TOTAL=(%d+)")) or 0
        allianceCount = tonumber(statusString:match("ALLIANCE=(%d+)")) or 0
        hordeCount = tonumber(statusString:match("HORDE=(%d+)")) or 0
        minPlayers = tonumber(statusString:match("MIN_PLAYERS=(%d+)")) or 10
        estWaitSeconds = tonumber(statusString:match("EST_WAIT=(%d+)")) or 0
        waitTime = tonumber(statusString:match("WAIT_TIME=(%d+)")) or 0
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
    HLBG.AllianceQueued = allianceCount
    HLBG.HordeQueued = hordeCount
    HLBG.MinPlayersToStart = minPlayers
    HLBG.EstimatedWaitSeconds = estWaitSeconds
    HLBG.BattleState = state

    HLBG.UpdateQueueUI()

    -- Debug output
    if DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cFF33FF99HLBG Queue:|r InQueue=%s Pos=%d/%d A=%d H=%d Est=%ds State=%s",
            tostring(inQueue), position, total, allianceCount, hordeCount, estWaitSeconds, state))
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
