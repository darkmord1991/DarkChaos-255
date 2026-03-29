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
    [3] = "FINISHED",
    [4] = "WAITING"
}

local function SendHLBGRequest(dc, opcode)
    if not dc then
        return false
    end

    -- Prefer plain transport first for opcode-only requests.
    if type(dc.Send) == "function" then
        dc:Send("HLBG", opcode)
        return true
    end

    if type(dc.Request) == "function" then
        dc:Request("HLBG", opcode, {})
        return true
    end

    return false
end

local function DecodeDCJson(dc, jsonStr)
    if not dc or type(dc.DecodeJSON) ~= "function" or type(jsonStr) ~= "string" then
        return nil
    end

    local ok, decoded = pcall(function()
        return dc:DecodeJSON(jsonStr)
    end)

    if ok and type(decoded) == "table" then
        return decoded
    end

    return nil
end

local function IsDCJsonPayload(args)
    if type(args) ~= "table" then
        return false
    end

    if args[1] == "J" then
        return true
    end

    if args[1] ~= "1" or type(args[2]) ~= "string" then
        return false
    end

    local lead = string.sub(args[2], 1, 1)
    return lead == "{" or lead == "["
end

local function ExtractQueuePayload(payload)
    if type(payload) ~= "table" then
        return nil
    end

    return payload.queueStatus or payload.inQueue or payload.isQueued or payload[1],
           payload.position or payload.queuePosition or payload.pos or payload[2],
           payload.estimatedTime or payload.waitTime or payload.estWait or payload[3],
           payload.totalQueued or payload.total or payload.queueTotal or payload[4],
           payload.allianceQueued or payload.alliance or payload.aQueued or payload[5],
           payload.hordeQueued or payload.horde or payload.hQueued or payload[6],
           payload.minPlayers or payload.minPlayersToStart or payload[7],
           payload.state or payload.bgState or payload.battleState or payload[8]
end

local function SyncQueueFromStatusValue(statusValue)
    local statusNum = tonumber(statusValue)
    if statusNum == nil then
        return
    end

    if statusNum == 1 or statusNum == 2 then
        HLBG.IsInQueue = true
        HLBG._lastQueueSyncAt = GetTime()
    elseif statusNum == 3 or statusNum == 4 then
        HLBG.IsInQueue = false
    end

    if statusNum == 2 then
        HLBG.BattleState = "WARMUP"
    elseif statusNum == 3 then
        HLBG.BattleState = "IN_PROGRESS"
    elseif statusNum == 4 then
        HLBG.BattleState = "FINISHED"
    elseif statusNum == 1 then
        HLBG.BattleState = "WAITING"
    elseif statusNum == 0 and (HLBG.BattleState == nil or HLBG.BattleState == "UNKNOWN") then
        HLBG.BattleState = "WAITING"
    end

    if type(HLBG.UpdateQueueUI) == "function" then
        HLBG.UpdateQueueUI()
    end
end

local function RegisterQueueDCHandlers()
    if HLBG._queueDCHandlersRegistered then
        return true
    end

    local dc = _G.DCAddonProtocol
    if not dc or type(dc.RegisterHandler) ~= "function" then
        return false
    end

    dc:RegisterHandler("HLBG", 0x10, function(...)
        local args = {...}

        if type(args[1]) == "table" then
            local payload = args[1]
            SyncQueueFromStatusValue(payload.status or payload.hlbgStatus or payload.state or payload[1])
            return
        end

        if IsDCJsonPayload(args) then
            local json = DecodeDCJson(dc, args[2])
            if json then
                SyncQueueFromStatusValue(json.status or json.hlbgStatus or json.state or json[1])
            end
            return
        end

        SyncQueueFromStatusValue(args[1])
    end)

    dc:RegisterHandler("HLBG", 0x13, function(...)
        if type(HLBG.HandleQueueStatusRaw) ~= "function" then
            return
        end

        local args = {...}
        local queueStatus, position, estimatedTime, totalQueued, allianceQueued, hordeQueued, minPlayers, state

        if type(args[1]) == "table" then
            queueStatus, position, estimatedTime, totalQueued, allianceQueued, hordeQueued, minPlayers, state = ExtractQueuePayload(args[1])
        elseif IsDCJsonPayload(args) then
            local json = DecodeDCJson(dc, args[2])
            if json then
                queueStatus, position, estimatedTime, totalQueued, allianceQueued, hordeQueued, minPlayers, state = ExtractQueuePayload(json)
            end
        else
            queueStatus, position, estimatedTime, totalQueued, allianceQueued, hordeQueued, minPlayers, state =
                args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]
        end

        HLBG.HandleQueueStatusRaw(
            queueStatus,
            position,
            estimatedTime,
            totalQueued,
            allianceQueued,
            hordeQueued,
            minPlayers,
            state
        )
    end)

    HLBG._queueDCHandlersRegistered = true
    return true
end

if not RegisterQueueDCHandlers() then
    local dcLoadWatcher = CreateFrame("Frame")
    dcLoadWatcher:RegisterEvent("ADDON_LOADED")
    dcLoadWatcher:SetScript("OnEvent", function(_, _, addonName)
        if addonName ~= "DC-AddonProtocol" and addonName ~= "DCAddonProtocol" then
            return
        end

        if RegisterQueueDCHandlers() then
            dcLoadWatcher:UnregisterEvent("ADDON_LOADED")
            dcLoadWatcher:SetScript("OnEvent", nil)
        end
    end)
end

local function NormalizeQueueState(stateValue)
    local asNumber = tonumber(stateValue)
    if asNumber ~= nil then
        return BG_STATE_MAP[asNumber] or "UNKNOWN"
    end

    if type(stateValue) == "string" and stateValue ~= "" then
        return string.upper(stateValue):gsub("%s+", "_")
    end

    return "UNKNOWN"
end

local function IsQueuedFlag(value)
    if type(value) == "boolean" then
        return value
    end

    local asNumber = tonumber(value)
    if asNumber ~= nil then
        return asNumber == 1
    end

    if type(value) == "string" then
        local lowered = string.lower(value)
        return lowered == "true" or lowered == "yes" or lowered == "queued"
    end

    return false
end

local function SendQueueStatusCommandFallback()
    local cmd = ".hlbg queue status"
    local editBox = DEFAULT_CHAT_FRAME and (DEFAULT_CHAT_FRAME.editBox or ChatFrame1EditBox) or ChatFrame1EditBox
    if editBox then
        editBox:SetText(cmd)
        ChatEdit_SendText(editBox, 0)
    end
end

-- Request current queue status from server
function HLBG.RequestQueueStatus()
    local DC = _G.DCAddonProtocol
    if SendHLBGRequest(DC, 1) then
        -- Send via DC Protocol (HLBG module op 0x01 = CMSG_REQUEST_STATUS)
        -- See DCAddonNamespace.h: CMSG_REQUEST_STATUS = 0x01
        if DEFAULT_CHAT_FRAME then
            HLBG.QueueMessage("request_status_dc")
        end

        if C_Timer and C_Timer.After then
            local requestedAt = GetTime()
            C_Timer.After(1.0, function()
                local lastSync = HLBG._lastQueueSyncAt or 0
                local lastFallback = HLBG._lastQueueStatusFallbackAt or 0
                local now = GetTime()

                if lastSync < requestedAt and (now - lastFallback) >= 8 then
                    HLBG._lastQueueStatusFallbackAt = now
                    SendQueueStatusCommandFallback()
                end
            end)
        end
    elseif AIO and AIO.Handle then
        AIO.Handle("HLBG", "RequestQueueStatus", "")
        if DEFAULT_CHAT_FRAME then
            HLBG.QueueMessage("request_status_aio")
        end
    else
        -- Fallback: use chat command
        local cmd = ".hlbg queue status"
        local editBox = DEFAULT_CHAT_FRAME.editBox or ChatFrame1EditBox
        if editBox then
            editBox:SetText(cmd)
            ChatEdit_SendText(editBox, 0)
        end
        if DEFAULT_CHAT_FRAME then
            HLBG.QueueMessage("request_status_cmd")
        end
    end
end

-- Join the battleground queue
function HLBG.JoinQueue()
    local DC = _G.DCAddonProtocol
    if SendHLBGRequest(DC, 4) then
        -- CMSG_QUICK_QUEUE = 0x04
        if DEFAULT_CHAT_FRAME then
            HLBG.QueueMessage("join_dc")
        end
    elseif AIO and AIO.Handle then
        AIO.Handle("HLBG", "JoinQueue", "")
        if DEFAULT_CHAT_FRAME then
            HLBG.QueueMessage("join_aio")
        end
    else
        -- Fallback: use chat command
        if DEFAULT_CHAT_FRAME then
            HLBG.QueueMessage("fallback_no_transport")
            HLBG.QueueMessage("fallback_join_hint")
        end
        
        -- Try to execute command
        local cmd = ".hlbg queue join"
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
    if SendHLBGRequest(DC, 5) then
        -- CMSG_LEAVE_QUEUE = 0x05
        if DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
            HLBG.QueueMessage("leave_dc")
        end
    elseif AIO and AIO.Handle then
        AIO.Handle("HLBG", "LeaveQueue", "")
        if DEFAULT_CHAT_FRAME then
            HLBG.QueueMessage("leave_aio")
        end
    else
        -- Fallback: use chat command
        local cmd = ".hlbg queue leave"
        local editBox = DEFAULT_CHAT_FRAME.editBox or ChatFrame1EditBox
        if editBox then
            editBox:SetText(cmd)
            ChatEdit_SendText(editBox, 0)
        end
        if DEFAULT_CHAT_FRAME then
            HLBG.QueueMessage("leave_cmd")
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
    elseif state == "FINISHED" then
        stateDisplay = "|cFF98FB98Battle finished|r"
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
                        "|cFFAAAAAANot in queue|r\n\n" ..
                        "%d / %d player(s) queued\n" ..
                        "|cFF00AAFFAlliance:|r %d  |cFFFF4444Horde:|r %d\n" ..
                        "%s\n" ..
                        "|cFFFFD700Battle State:|r %s\n\n" ..
                        "Click 'Join Queue' to participate in the next battle.",
                        total, minPlayers, allianceCount, hordeCount, neededStr, stateDisplay))
                else
                    HLBG.UI.Queue.StatusText:SetText(string.format(
                        "|cFFAAAAAANot in queue|r\n\n" ..
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
    local inQueue = IsQueuedFlag(queueStatus)
    local state = NormalizeQueueState(stateInt)
    if state == "CLEANUP" then
        state = "WAITING"
    end
    
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
    HLBG._lastQueueSyncAt = GetTime()
    
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
            HLBG.QueueMessage("unknown_status", statusString)
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
    HLBG._lastQueueSyncAt = GetTime()

    HLBG.UpdateQueueUI()

    -- Debug output
    if DEFAULT_CHAT_FRAME and (HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)) then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cFF33FF99HLBG Queue:|r InQueue=%s Pos=%d/%d A=%d H=%d Est=%ds State=%s",
            tostring(inQueue), position, total, allianceCount, hordeCount, estWaitSeconds, state))
    end
end

-- Backward-compatible alias used by older handlers.
if type(HLBG.QueueStatus) ~= "function" then
    HLBG.QueueStatus = HLBG.HandleQueueStatus
end

local function StripQueueChatMarkup(msg)
    if type(msg) ~= "string" then
        return ""
    end

    local out = msg
    out = out:gsub("|T[^|]-|t", "")
    out = out:gsub("|c%x%x%x%x%x%x%x%x", "")
    out = out:gsub("|r", "")
    return out
end

local function HandleQueueSystemChat(msg)
    local plain = StripQueueChatMarkup(msg)
    if plain == "" then
        return
    end

    local lowered = string.lower(plain)
    if not lowered:find("queue", 1, true) then
        return
    end

    local changed = false

    if lowered:find("joined queue", 1, true) then
        HLBG.IsInQueue = true
        if HLBG.BattleState == "UNKNOWN" then
            HLBG.BattleState = "WAITING"
        end
        local position = tonumber(plain:match("[Pp]osition:%s*(%d+)"))
        if position then
            HLBG.QueuePosition = position
            if (HLBG.QueueTotal or 0) < position then
                HLBG.QueueTotal = position
            end
        end
        changed = true
    elseif lowered:find("left queue", 1, true) or lowered:find("not in queue", 1, true) then
        HLBG.IsInQueue = false
        HLBG.QueuePosition = 0
        changed = true
    elseif lowered:find("already in the queue", 1, true) or lowered:find("already in queue", 1, true) then
        HLBG.IsInQueue = true
        if HLBG.BattleState == "UNKNOWN" then
            HLBG.BattleState = "WAITING"
        end
        changed = true
    end

    local statusPosition = tonumber(plain:match("[Yy]our%s+[Pp]osition:%s*(%d+)"))
    if statusPosition then
        HLBG.IsInQueue = true
        HLBG.QueuePosition = statusPosition
        if (HLBG.QueueTotal or 0) < statusPosition then
            HLBG.QueueTotal = statusPosition
        end
        changed = true
    end

    local totalQueued = tonumber(plain:match("[Tt]otal queued:%s*(%d+)"))
    if totalQueued then
        HLBG.QueueTotal = totalQueued
        changed = true
    end

    local allianceCount, hordeCount = plain:match("[Aa]lliance:?%s*(%d+).-[Hh]orde:?%s*(%d+)")
    if allianceCount and hordeCount then
        HLBG.AllianceQueued = tonumber(allianceCount) or HLBG.AllianceQueued
        HLBG.HordeQueued = tonumber(hordeCount) or HLBG.HordeQueued
        changed = true
    end

    local minPlayers = tonumber(plain:match("[Mm]inimum to start:%s*(%d+)"))
    if minPlayers then
        HLBG.MinPlayersToStart = minPlayers
        changed = true
    end

    local waitSeconds = tonumber(plain:match("[Ww]ait time:%s*(%d+)%s*s"))
    if waitSeconds then
        HLBG.EstimatedWaitSeconds = waitSeconds
        changed = true
    end

    if lowered:find("warmup", 1, true) then
        HLBG.BattleState = "WARMUP"
        changed = true
    elseif lowered:find("battle in progress", 1, true) then
        HLBG.BattleState = "IN_PROGRESS"
        changed = true
    elseif lowered:find("battle paused", 1, true) then
        HLBG.BattleState = "PAUSED"
        changed = true
    elseif lowered:find("battle finished", 1, true) then
        HLBG.BattleState = "FINISHED"
        changed = true
    elseif lowered:find("waiting for players", 1, true) then
        HLBG.BattleState = "WAITING"
        changed = true
    end

    if changed then
        HLBG._lastQueueSyncAt = GetTime()
        HLBG.UpdateQueueUI()
    end
end

HLBG._queueChatFrame = HLBG._queueChatFrame or CreateFrame("Frame")
HLBG._queueChatFrame:UnregisterAllEvents()
HLBG._queueChatFrame:RegisterEvent("CHAT_MSG_SYSTEM")
HLBG._queueChatFrame:RegisterEvent("CHAT_MSG_WHISPER")
HLBG._queueChatFrame:RegisterEvent("CHAT_MSG_SAY")
HLBG._queueChatFrame:RegisterEvent("CHAT_MSG_YELL")
HLBG._queueChatFrame:SetScript("OnEvent", function(_, _, msg)
    pcall(HandleQueueSystemChat, msg)
end)

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
            HLBG.QueueMessage("commands_header")
            HLBG.QueueMessage("commands_status")
            HLBG.QueueMessage("commands_join")
            HLBG.QueueMessage("commands_leave")
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
