-- HLBG_FileLoader.lua
-- This file helps test loading individual Lua files in the addon
-- Use /hlbgloadfile filename to load a specific file

-- Record this file being loaded
if _G.HLBG_RecordFileLoad then
    _G.HLBG_RecordFileLoad("HLBG_FileLoader.lua")
end

-- Create a namespace for the file loader
local FileLoader = {}
_G.HLBG_FileLoader = FileLoader

-- List of files in loading order from TOC
FileLoader.files = {
    "HLBG_LoadDebug.lua",
    "HLBG_TimerCompat.lua",
    "HLBG_DebugBootstrap.lua",
    "HLBG_Compatibility.lua",
    "HLBG_Debug_Helper.lua",
    "HinterlandAffixHUD.lua",
    "HLBG_Core.lua",
    "HLBG_JSON.lua",
    "HLBG_Utils.lua",
    "HLBG_HUD.lua",
    "HLBG_Debug.lua",
    "HLBG_UI.lua",
    "HLBG_Info.lua",
    "HLBG_Settings.lua",
    "HLBG_Help.lua",
    "HLBG_AFK.lua",
    "HLBG_SlashCommands.lua",
    "HLBG_AIO.lua",
    "HLBG_Handlers.lua",
    "HLBG_Status.lua",
    "HLBG_StatsHandler.lua",
    "HLBG_HistoryHandler.lua",
    "HLBG_UI_Helpers.lua",
    "HLBG_UI_Stats_Enhanced.lua",
    "HLBG_UI_History_Fixed.lua",
    "HLBG_UI_Info.lua",
    "HLBG_UI_Settings.lua",
    "HLBG_UI_Integrator.lua",
    "HLBG_AntiFlicker.lua",
    "HLBG_ZoneDetect.lua",
    "HLBG_Stability.lua",
    "HLBG_DedupeHUD.lua",
    "HLBG_RequestManager.lua",
    "HLBG_TabStability.lua",
    "HLBG_AIO_Client.lua",
    "HLBG_Troubleshooter.lua"
}

-- Function to attempt loading a file by name
function FileLoader.LoadFile(filename)
    -- Make sure filename has .lua extension
    if not filename:match("%.lua$") then
        filename = filename .. ".lua"
    end
    
    -- Check if file exists in our list
    local found = false
    for _, file in ipairs(FileLoader.files) do
        if file:lower() == filename:lower() then
            found = true
            filename = file -- Use correct case from list
            break
        end
    end
    
    if not found then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG]|r File not found in addon: " .. filename)
        end
        return false
    end
    
    -- Try to load the file
    local path = "Interface\\AddOns\\HinterlandAffixHUD\\" .. filename
    local loaded, errorMsg = pcall(dofile, path)
    
    if not loaded then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG]|r Failed to load " .. filename .. ": " .. tostring(errorMsg))
        end
        return false
    else
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[HLBG]|r Successfully loaded " .. filename)
        end
        return true
    end
end

-- Function to list all available files
function FileLoader.ListFiles()
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00AAFF[HLBG]|r Available files:")
        for i, file in ipairs(FileLoader.files) do
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %d. %s", i, file))
        end
    end
end

-- Create slash command to load files
SLASH_HLBGLOADFILE1 = "/hlbgloadfile"
SlashCmdList["HLBGLOADFILE"] = function(msg)
    if not msg or msg == "" or msg:lower() == "help" then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00AAFF[HLBG File Loader]|r")
            DEFAULT_CHAT_FRAME:AddMessage("Usage: /hlbgloadfile filename")
            DEFAULT_CHAT_FRAME:AddMessage("Use /hlbgloadfile list to see all available files")
        end
        return
    end
    
    if msg:lower() == "list" then
        FileLoader.ListFiles()
        return
    end
    
    FileLoader.LoadFile(msg)
end

-- Notify that the file loader is available
if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00AAFF[HLBG]|r File loader loaded. Use /hlbgloadfile help for instructions.")
end