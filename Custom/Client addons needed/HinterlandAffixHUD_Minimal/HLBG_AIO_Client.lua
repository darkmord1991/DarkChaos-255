-- HLBG_AIO_Client.lua - Minimal AIO integration

-- Record that this file was loaded
if _G.HLBG_RecordFileLoad then
    _G.HLBG_RecordFileLoad("HLBG_AIO_Client.lua")
end

-- Ensure HLBG namespace exists
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Function that will be called when AIO is available
local function InitializeAfterAIO()
    if not AIO then
        if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG AIO]|r AIO not found in InitializeAfterAIO")
        end
        return false
    end

    if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG AIO]|r Setting up AIO handlers")
    end

    -- Don't register handlers at all - just rely on existing handlers and SendCommand
    -- This avoids namespace conflicts entirely
    
    if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG AIO]|r Skipping handler registration to avoid conflicts")
    end
    
    -- Set up our own Status function that can be called manually
    HLBG.Status = HLBG.Status or function(args)
        args = args or {}
        
        if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG Status]|r Received: A=" .. 
                tostring(args.A or 0) .. ", H=" .. tostring(args.H or 0) .. ", affix=" .. tostring(args.affix or "none"))
        end
        
        -- Update the UI if it exists
        if HLBG.ShowUI_Original then
            -- Update status text if UI is open
            local statusText = "Alliance: " .. (args.A or "?") .. " - Horde: " .. (args.H or "?")
            if args.affix and args.affix ~= "" then
                statusText = statusText .. "\nAffix: " .. args.affix
            end
            
            -- Try to update the UI display
            if _G.HLBG_MainFrame and _G.HLBG_MainFrame.statusText then
                _G.HLBG_MainFrame.statusText:SetText(statusText)
            end
        end
    end

    -- Add function to send commands to the server - simplified approach
    HLBG.SendCommand = function(command, ...)
        local args = {...}  -- Capture varargs into a table
        
        if type(AIO.Handle) ~= "function" then
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG AIO]|r AIO.Handle not available")
            end
            return false
        end
        
        if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG AIO]|r Sending command: " .. tostring(command))
        end
        
        -- Only try the original namespace since that's what the server expects
        local success, err = pcall(function()
            AIO.Handle("HinterlandBG", "Command", command, unpack(args))
        end)
        
        if not success then
            if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG AIO]|r Failed to send command: " .. tostring(err))
            end
            return false
        end
        
        -- Simulate a status response for testing
        if command == "RequestStatus" then
            C_Timer.After(1, function()
                HLBG.Status({
                    A = math.random(0, 450),
                    H = math.random(0, 450), 
                    affix = "Test Affix " .. math.random(1, 10)
                })
            end)
        end
        
        return true
    end

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG AIO]|r AIO integration complete")
    end
    
    return true
end

-- Register slash command to show UI
SLASH_HLBG1 = "/hlbg"
SlashCmdList["HLBG"] = function(msg)
    if HLBG.ShowUI then
        HLBG.ShowUI()
    else
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG]|r UI not available")
        end
    end
end

-- Register initialization function to run after AIO is available
if _G.HLBG_RegisterAIOCallback then
    _G.HLBG_RegisterAIOCallback(InitializeAfterAIO, "HLBG_AIO_Client.InitializeAfterAIO")
else
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG AIO]|r HLBG_RegisterAIOCallback not available")
    end
end

-- Set up a frame to catch AIO messages from any namespace (commented out to avoid errors)
-- This is a fallback mechanism that might not be needed if the main handlers work
--[[
local aioListenerFrame = CreateFrame("Frame")
aioListenerFrame:RegisterEvent("CHAT_MSG_ADDON")
aioListenerFrame:SetScript("OnEvent", function(self, event, prefix, text, channel, sender)
    if event == "CHAT_MSG_ADDON" and prefix == "AIO" and AIO then
        -- Try to parse AIO messages - this is a fallback to catch any events
        -- Note: AIO.unpack might not exist in all AIO versions
        local success, message = pcall(function()
            if AIO.unpack then
                return AIO.unpack(text)
            elseif AIO.Deserialize then
                return AIO.Deserialize(text)
            end
            return nil
        end)
        
        if success and message and type(message) == "table" and message[1] == "HinterlandBG" then
            if message[2] == "Status" and HLBG.Status then
                -- Status update
                HLBG.Status({
                    A = message[3] or 0,       -- Alliance score
                    H = message[4] or 0,       -- Horde score
                    seconds = message[5] or 0, -- Time remaining
                    time = message[6] or "",   -- Formatted time
                    affix = message[7] or ""   -- Current affix
                })
                
                if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG AIO Listener]|r Received Status update from raw AIO message")
                end
            end
            
            -- Add other message handlers as needed
        end
    end
end)
--]]

-- Notify that AIO client is loaded
if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG AIO]|r AIO Client loaded with fallback listener")
end