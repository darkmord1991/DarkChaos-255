-- HLBG_LoadDebug.lua - Track addon loading sequence

-- Global variable to enable debug output
_G.HLBG_Debug = true

-- Global table to track loaded files
_G.HLBG_LoadedFiles = {}

-- Function to record file loads
function _G.HLBG_RecordFileLoad(filename)
    if not _G.HLBG_LoadedFiles then
        _G.HLBG_LoadedFiles = {}
    end
    _G.HLBG_LoadedFiles[filename] = true
    
    if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG Debug]|r Loaded: " .. filename)
    end
end

-- Record that this file was loaded
_G.HLBG_RecordFileLoad("HLBG_LoadDebug.lua")

-- Print debug message that load debug is active
if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG Debug]|r Load debugging is active")
end