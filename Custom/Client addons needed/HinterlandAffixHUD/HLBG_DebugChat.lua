-- HLBG Chat Debug Helper
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Flag to enable chat monitoring
HLBG._debugChat = false

-- Store original chat handler if we need to monitor
local originalChatHandler = ChatFrame_OnEvent

-- Command to enable/disable chat monitoring
SLASH_HLBGCHAT1 = '/hlbgchat'
function SlashCmdList.HLBGCHAT(msg)
    if msg == "on" then
        HLBG._debugChat = true
        -- Hook the chat frame when enabling
        if ChatFrame1 and ChatFrame1.SetScript and MonitorChatFrame then
            ChatFrame1:SetScript("OnEvent", MonitorChatFrame)
        end
        DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r Chat monitoring enabled - will show all incoming chat messages')
    elseif msg == "off" then
        HLBG._debugChat = false
        -- Restore original handler when disabling
        if ChatFrame1 and ChatFrame1.SetScript and originalChatHandler then
            ChatFrame1:SetScript("OnEvent", originalChatHandler)
        end
        DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r Chat monitoring disabled')
    else
        DEFAULT_CHAT_FRAME:AddMessage('Usage: /hlbgchat on|off')
        DEFAULT_CHAT_FRAME:AddMessage('Current state: ' .. (HLBG._debugChat and 'ON' or 'OFF'))
    end
end

-- Hook into chat system to monitor messages (safer version)
local function MonitorChatFrame(self, event, ...)
    -- Only monitor when explicitly enabled and avoid interfering with other systems
    if HLBG._debugChat and event == "CHAT_MSG_SAY" then
        local message, sender = ...
        if message and sender then
            DEFAULT_CHAT_FRAME:AddMessage('|cFFFFFF00[CHAT DEBUG]|r SAY from ' .. sender .. ': ' .. message)
            
            -- Check if this looks like HLBG data
            if message:match("HLBG") or message:match("Hinterland") or message:match("Draw") or message:match("Alliance") or message:match("Horde") then
                DEFAULT_CHAT_FRAME:AddMessage('|cFF00FFFF[HLBG MATCH]|r This message might be HLBG data!')
            end
        end
    end
    
    -- Call original handler safely
    if originalChatHandler then
        pcall(originalChatHandler, self, event, ...)
    end
end

-- Only hook if chat monitoring is requested and frame exists
-- Don't override by default to avoid conflicts
if ChatFrame1 and ChatFrame1.SetScript then
    -- Store original but don't override until requested
    originalChatHandler = ChatFrame1:GetScript("OnEvent")
end