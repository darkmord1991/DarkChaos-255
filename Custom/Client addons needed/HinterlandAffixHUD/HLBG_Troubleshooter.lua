-- HLBG_Troubleshooter.lua
-- Standalone troubleshooter for HinterlandAffixHUD addon

-- Record file load
if _G.HLBG_RecordFileLoad then
    _G.HLBG_RecordFileLoad("HLBG_Troubleshooter.lua")
end

-- Create the addon troubleshooter namespace
local Troubleshooter = {}
_G.HLBG_Troubleshooter = Troubleshooter

-- Function to scan for addons that might conflict
function Troubleshooter.ScanForConflicts()
    -- List of addons that might cause conflicts
    local potentialConflicts = {
        "AIO",          -- Make sure AIO is present
        "LibStub",      -- Common dependency
        "Blizzard_CombatLog", -- Core Blizzard addon that sometimes causes issues
    }
    
    local results = {}
    for _, addon in ipairs(potentialConflicts) do
        local loaded, finished = IsAddOnLoaded(addon)
        table.insert(results, string.format("%s: %s", addon, loaded and "Loaded" or "Not loaded"))
    end
    
    return results
end

-- Check if critical functions are available
function Troubleshooter.CheckCriticalFunctions()
    local results = {}
    
    -- Critical functions to check
    local functions = {
        "C_Timer",
        "HLBG",
        "HLBG.Debug",
        "HLBG.SendCommand",
        "HLBG.RunJsonDecodeTests",
        "AIO",
        "AIO.Handle",
        "json_decode",
    }
    
    for _, funcPath in ipairs(functions) do
        -- Split the path into parts
        local parts = {}
        for part in funcPath:gmatch("[^.]+") do
            table.insert(parts, part)
        end
        
        -- Traverse the path
        local obj = _G
        local available = true
        for i, part in ipairs(parts) do
            if type(obj) ~= "table" then
                available = false
                break
            end
            obj = obj[part]
            if obj == nil then
                available = false
                break
            end
        end
        
        -- Check if the final object is the correct type
        local objType = type(obj)
        local expectedType = "function"
        if parts[1] == "C_Timer" or parts[1] == "HLBG" or parts[1] == "AIO" then
            if #parts == 1 then expectedType = "table" end
        end
        
        if available and objType ~= expectedType then
            available = false
        end
        
        table.insert(results, string.format("%s: %s (is %s, expected %s)", 
            funcPath, available and "Available" or "Missing", objType, expectedType))
    end
    
    return results
end

-- Check for common issues
function Troubleshooter.CheckCommonIssues()
    local results = {}
    
    -- Check load order
    if _G.HLBG_LoadState and _G.HLBG_LoadState.files and #_G.HLBG_LoadState.files >= 2 then
        local firstFile = _G.HLBG_LoadState.files[1]
        local secondFile = _G.HLBG_LoadState.files[2]
        
        if firstFile ~= "HLBG_LoadDebug.lua" then
            table.insert(results, "Incorrect load order: first file should be HLBG_LoadDebug.lua, got " .. firstFile)
        end
        
        if secondFile ~= "HLBG_TimerCompat.lua" then
            table.insert(results, "Incorrect load order: second file should be HLBG_TimerCompat.lua, got " .. secondFile)
        end
    else
        table.insert(results, "Unable to check load order - no load state information available")
    end
    
    -- Check for errors
    if _G.HLBG_LoadState and _G.HLBG_LoadState.errors and #_G.HLBG_LoadState.errors > 0 then
        table.insert(results, string.format("Found %d errors during loading", #_G.HLBG_LoadState.errors))
        for i = 1, math.min(3, #_G.HLBG_LoadState.errors) do
            table.insert(results, "  - " .. _G.HLBG_LoadState.errors[i])
        end
    else
        table.insert(results, "No loading errors recorded")
    end
    
    -- Check if AIO is properly loaded
    if not _G.AIO then
        table.insert(results, "AIO is not loaded - make sure the AIO_Client addon is enabled")
    elseif not _G.AIO.Handle then
        table.insert(results, "AIO is loaded but AIO.Handle function is missing")
    elseif not _G.AIO.RegisterEvent then
        table.insert(results, "AIO is loaded but AIO.RegisterEvent function is missing")
    else
        table.insert(results, "AIO appears to be properly loaded")
    end
    
    -- Check HLBG namespace
    if not _G.HLBG then
        table.insert(results, "HLBG namespace is missing entirely")
    elseif type(_G.HLBG) ~= "table" then
        table.insert(results, "HLBG is defined but is not a table")
    else
        local count = 0
        for _ in pairs(_G.HLBG) do count = count + 1 end
        table.insert(results, string.format("HLBG namespace contains %d entries", count))
    end
    
    return results
end

-- Run all diagnostic checks
function Troubleshooter.RunAll()
    local results = {
        title = "HinterlandAffixHUD Troubleshooter Results",
        timestamp = date("%Y-%m-%d %H:%M:%S"),
        conflicts = Troubleshooter.ScanForConflicts(),
        functions = Troubleshooter.CheckCriticalFunctions(),
        issues = Troubleshooter.CheckCommonIssues(),
    }
    
    -- Print results to chat
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF00AAFF%s|r", results.title))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF00AAFFTime:|r %s", results.timestamp))
        
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00AAFF=== Addon Conflicts ===|r")
        for _, line in ipairs(results.conflicts) do
            DEFAULT_CHAT_FRAME:AddMessage("  " .. line)
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00AAFF=== Critical Functions ===|r")
        for _, line in ipairs(results.functions) do
            DEFAULT_CHAT_FRAME:AddMessage("  " .. line)
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00AAFF=== Common Issues ===|r")
        for _, line in ipairs(results.issues) do
            DEFAULT_CHAT_FRAME:AddMessage("  " .. line)
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00AAFFTroubleshooting complete.|r")
    end
    
    return results
end

-- Create slash command to run the troubleshooter
SLASH_HLBGTROUBLE1 = "/hlbgtrouble"
SlashCmdList["HLBGTROUBLE"] = function(msg)
    Troubleshooter.RunAll()
end

-- Notify that the troubleshooter is available
if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00AAFF[HLBG]|r Troubleshooter loaded. Use /hlbgtrouble to diagnose issues.")
end