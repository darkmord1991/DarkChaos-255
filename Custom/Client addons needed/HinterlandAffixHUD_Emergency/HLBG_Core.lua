-- HLBG_Core.lua - Emergency Core File
-- This is a simplified version of the core file for testing

-- Track that this file was loaded
if _G.HLBG_RecordFileLoad then
    _G.HLBG_RecordFileLoad("HLBG_Core.lua")
end

-- Create or use existing namespace
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Core functionality
HLBG.version = "Emergency-1.0"
HLBG._devMode = true

-- Initialize main frame
local frame = CreateFrame("Frame", "HLBG_MainFrame")
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetWidth(300)
frame:SetHeight(100)
frame:SetFrameStrata("MEDIUM")
frame:Hide()

-- Create status text
local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusText:SetPoint("CENTER", frame, "CENTER")
statusText:SetText("HLBG Emergency Mode")

-- Create basic UI functions
function HLBG.ShowUI()
    frame:Show()
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG Emergency:|r UI displayed")
    end
end

function HLBG.HideUI()
    frame:Hide()
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF6600HLBG Emergency:|r UI hidden")
    end
end

-- Register for ADDON_LOADED to display info when ready
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "HinterlandAffixHUD_Emergency" then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEEAHLBG Emergency:|r Core module loaded")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Register for chat command
        SLASH_HLBGEM1 = "/hlbgem"
        SlashCmdList["HLBGEM"] = function(msg)
            if msg == "show" then
                HLBG.ShowUI()
            elseif msg == "hide" then
                HLBG.HideUI()
            elseif msg == "status" then
                -- Display AIO status
                if _G.AIO and type(_G.AIO) == "table" and type(_G.AIO.Handle) == "function" then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG Emergency:|r AIO is available")
                    
                    -- Try to send a test command
                    _G.AIO.Handle("HLBG", "Ping", { emergency = true, time = time() })
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG Emergency:|r Test command sent to server")
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000HLBG Emergency:|r AIO is NOT available")
                end
                
                -- Show load state
                if _G.HLBG_LoadState then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF88EEEEHLBG Emergency:|r Load state information:")
                    for k, v in pairs(_G.HLBG_LoadState) do
                        if type(v) ~= "table" then
                            DEFAULT_CHAT_FRAME:AddMessage("  - " .. tostring(k) .. ": " .. tostring(v))
                        else
                            DEFAULT_CHAT_FRAME:AddMessage("  - " .. tostring(k) .. ": [Table with " .. #v .. " entries]")
                        end
                    end
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF6600HLBG Emergency:|r No load state information available")
                end
                
                -- Show loaded files
                if _G.HLBG_LoadedFiles and #_G.HLBG_LoadedFiles > 0 then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF88EEEEHLBG Emergency:|r Loaded files (" .. #_G.HLBG_LoadedFiles .. "):")
                    for i, file in ipairs(_G.HLBG_LoadedFiles) do
                        DEFAULT_CHAT_FRAME:AddMessage("  " .. i .. ". " .. file)
                        -- Only show first 10 files to avoid flooding
                        if i >= 10 then 
                            DEFAULT_CHAT_FRAME:AddMessage("  ... and " .. (#_G.HLBG_LoadedFiles - 10) .. " more files")
                            break
                        end
                    end
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF6600HLBG Emergency:|r No file load tracking available")
                end
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFF88EEEEHLBG Emergency:|r Commands: show, hide, status")
            end
        end
        
        -- Show welcome message
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEEAHLBG Emergency Mode:|r Type /hlbgem for commands")
    end
end)

-- Register with AIO if it becomes available later
if _G.HLBG_CheckAIO and type(_G.HLBG_CheckAIO) == "function" then
    -- This will try to set up AIO event handling if available
    _G.HLBG_CheckAIO()
    
    -- Set a callback for when AIO becomes available
    HLBG.InitializeAfterAIO = function()
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG Emergency:|r AIO is now available, setting up handlers")
        end
        
        -- Try to send a test command
        HLBG.SendCommand("Ping", { emergency = true, time = time() })
    end
else
    -- No AIO check function available
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF6600HLBG Emergency:|r AIO check function not available")
    end
end