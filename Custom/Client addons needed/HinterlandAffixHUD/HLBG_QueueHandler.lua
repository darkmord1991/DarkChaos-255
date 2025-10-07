-- HLBG_QueueHandler.lua - Queue status parsing and display

local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Parse queue status from server broadcast messages
function HLBG.ParseQueueMessage(text)
    if not text or type(text) ~= "string" then return end
    
    -- Look for [HLBG_QUEUE] messages
    local queueData = text:match("%[HLBG_QUEUE%] (.*)")
    if not queueData then return end
    
    -- Parse key=value pairs separated by |
    local data = {}
    for pair in queueData:gmatch("[^|]+") do
        local key, value = pair:match("([^=]+)=([^=]*)")
        if key and value then
            data[key] = value
        end
    end
    
    return data
end

-- Update queue status display with parsed data
function HLBG.UpdateQueueStatus(data)
    if not data then return end
    
    -- Extract queue information
    local action = data.action or "unknown"
    local total = tonumber(data.countA or 0) + tonumber(data.countH or 0)
    local alliance = tonumber(data.countA or 0)
    local horde = tonumber(data.countH or 0) 
    local position = tonumber(data.pos or 0)
    local eta = tonumber(data.eta or 0)
    local team = data.team or "Unknown"
    local minPlayers = tonumber(data.size or 10)
    
    -- Format the queue status message
    local statusLines = {
        "|cFFFFAA33=== Hinterland BG Queue Status ===|r",
        string.format("Total players in queue: |cFF33FF99%d|r", total),
        string.format("Alliance: |cFF0080FF%d|r | Horde: |cFFFF4040%d|r", alliance, horde),
        string.format("Minimum players to start: |cFFFFAA33%d|r", minPlayers)
    }
    
    if action == "joined" then
        table.insert(statusLines, string.format("Status: |cFF00FF00Joined queue as %s|r", team))
        if position > 0 then
            table.insert(statusLines, string.format("Position in queue: |cFF33FF99%d|r", position))
        end
    elseif action == "left" then
        table.insert(statusLines, "Status: |cFFFF8040Left the queue|r")
    else
        if total > 0 then
            table.insert(statusLines, "Status: |cFFAAAAAAWaiting for players|r")
        else
            table.insert(statusLines, "Status: |cFF888888No players in queue|r")  
        end
    end
    
    if eta > 0 then
        local mins = math.floor(eta / 60)
        local secs = eta % 60
        table.insert(statusLines, string.format("Estimated time: |cFFFFAA33%d:%02d|r", mins, secs))
    end
    
    -- Display in chat
    for _, line in ipairs(statusLines) do
        DEFAULT_CHAT_FRAME:AddMessage(line)
    end
    
    -- Update UI if queue tab is open
    if HLBG.UI and HLBG.UI.Queue then
        -- Update queue count display
        if HLBG.UI.Queue.CountValue then
            HLBG.UI.Queue.CountValue:SetText("|cFFFFAA33" .. total .. "|r")
        end
        
        -- Update status text
        if HLBG.UI.Queue.Status then
            local statusText = table.concat(statusLines, "\n"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            HLBG.UI.Queue.Status:SetText(statusText)
        end
        
        -- Update button states based on queue status
        if HLBG.UI.Queue.Join and HLBG.UI.Queue.Leave then
            if action == "joined" or position > 0 then
                HLBG.UI.Queue.Join:SetEnabled(false)
                HLBG.UI.Queue.Leave:SetEnabled(true)
                HLBG.UI.Queue.Join:SetText("In Queue")
            else
                HLBG.UI.Queue.Join:SetEnabled(true)
                HLBG.UI.Queue.Leave:SetEnabled(false)
                HLBG.UI.Queue.Join:SetText("Join Queue")
            end
        end
    end
end

-- Hook into chat message events to catch queue broadcasts
local queueFrame = CreateFrame("Frame")
queueFrame:RegisterEvent("CHAT_MSG_SYSTEM")
queueFrame:SetScript("OnEvent", function(self, event, text)
    if event == "CHAT_MSG_SYSTEM" and text then
        local queueData = HLBG.ParseQueueMessage(text)
        if queueData then
            HLBG.UpdateQueueStatus(queueData)
        end
    end
end)

-- Hook queue buttons to the proper functions when UI is created
if HLBG.UI and HLBG.UI.Queue then
    C_Timer.After(1, function()
        if HLBG.UI.Queue.Join and HLBG.UI.Queue.Leave then
            HLBG.UI.Queue.Join:SetScript("OnClick", function()
                if _G.AIO and _G.AIO.Handle then
                    _G.AIO.Handle("HLBG", "Request", "QUEUE", "join")
                end
                local sendDot = HLBG.SendServerDot or _G.HLBG_SendServerDot
                if sendDot then
                    sendDot(".hlbg queue join")
                end
                print("|cFF33FF99HLBG:|r Requesting to join queue...")
            end)
            
            HLBG.UI.Queue.Leave:SetScript("OnClick", function()
                if _G.AIO and _G.AIO.Handle then
                    _G.AIO.Handle("HLBG", "Request", "QUEUE", "leave")
                end
                local sendDot = HLBG.SendServerDot or _G.HLBG_SendServerDot
                if sendDot then
                    sendDot(".hlbg queue leave")
                end  
                print("|cFF33FF99HLBG:|r Requesting to leave queue...")
            end)
        end
    end)
end

-- Add a slash command for manual queue status check
if type(HLBG.safeRegisterSlash) == 'function' then
    HLBG.safeRegisterSlash('HLBGQUEUE', '/hlbgqueue', function()
        if _G.AIO and _G.AIO.Handle then
            _G.AIO.Handle("HLBG", "Request", "QUEUE", "status")
        end
        local sendDot = HLBG.SendServerDot or _G.HLBG_SendServerDot
        if sendDot then
            sendDot(".hlbg queue status")
        end
        print("|cFF33FF99HLBG:|r Requesting queue status...")
    end)
else
    SLASH_HLBGQUEUE1 = "/hlbgqueue"
    SlashCmdList["HLBGQUEUE"] = function()
        if _G.AIO and _G.AIO.Handle then
            _G.AIO.Handle("HLBG", "Request", "QUEUE", "status")
        end
        local sendDot = HLBG.SendServerDot or _G.HLBG_SendServerDot
        if sendDot then
            sendDot(".hlbg queue status")  
        end
        print("|cFF33FF99HLBG:|r Requesting queue status...")
    end
end

_G.HLBG = HLBG