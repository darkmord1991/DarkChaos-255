-- HLBG_ErrorFixes.lua - Comprehensive error fixes and compatibility improvements

local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Fix C_Timer compatibility for 3.3.5a
if not C_Timer then
    _G.C_Timer = {
        NewTimer = function(duration, callback)
            local frame = CreateFrame("Frame")
            local elapsed = 0
            frame:SetScript("OnUpdate", function(self, dt)
                elapsed = elapsed + dt
                if elapsed >= duration then
                    self:SetScript("OnUpdate", nil)
                    if callback then callback() end
                end
            end)
            return frame
        end,
        
        After = function(duration, callback)
            return _G.C_Timer.NewTimer(duration, callback)
        end
    }
end

-- Enhanced error catching for UI operations
local function SafeUICall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        print("|cFFFF0000HLBG Error:|r " .. tostring(result))
        return false
    end
    return result
end

-- Safe frame creation
function HLBG.SafeCreateFrame(frameType, name, parent, template)
    return SafeUICall(CreateFrame, frameType, name, parent, template)
end

-- Safe backdrop application
function HLBG.SafeSetBackdrop(frame, backdrop)
    if frame and frame.SetBackdrop then
        return SafeUICall(frame.SetBackdrop, frame, backdrop)
    end
    return false
end

-- Safe event registration
function HLBG.SafeRegisterEvent(frame, event)
    if frame and frame.RegisterEvent then
        return SafeUICall(frame.RegisterEvent, frame, event)
    end
    return false
end

-- Enhanced error handler for AIO operations
local function SafeAIOCall(handler, method, ...)
    if not _G.AIO or not _G.AIO.Handle then
        print("|cFF888888HLBG:|r AIO not available, using fallback")
        return false
    end
    
    local success = pcall(_G.AIO.Handle, handler, method, ...)
    if not success then
        print("|cFFFF0000HLBG:|r AIO call failed: " .. tostring(handler) .. "." .. tostring(method))
    end
    return success
end

-- Replace direct AIO calls with safe versions throughout HLBG
HLBG.SafeAIOHandle = SafeAIOCall

-- Fix worldstate function compatibility
if not GetNumWorldStateUI then
    print("|cFFFF6600HLBG:|r GetNumWorldStateUI not available, creating mock function")
    _G.GetNumWorldStateUI = function() return 0 end
    _G.GetWorldStateUIInfo = function(index) return "", 0, 0, 0, 0, nil end
end

-- Enhanced safe worldstate functions
function HLBG.safeGetNumWorldStateUI()
    if GetNumWorldStateUI then
        local success, result = pcall(GetNumWorldStateUI)
        return success and result or 0
    end
    return 0
end

function HLBG.safeGetWorldStateUIInfo(index)
    if GetWorldStateUIInfo and type(index) == "number" then
        local success, text, value, a, b, c, id = pcall(GetWorldStateUIInfo, index)
        if success then
            return text, value, a, b, c, id
        end
    end
    return "", 0, 0, 0, 0, nil
end

-- Fix font loading issues
local function EnsureFontsLoaded()
    -- Ensure default fonts are available
    local testFont = "Fonts\\FRIZQT__.TTF"
    if not testFont then
        testFont = "GameFontNormal"
    end
    return testFont
end

-- Enhanced tab switching with error handling
function HLBG.SafeShowTab(tabIndex)
    if not HLBG.UI or not HLBG.UI.Tabs then
        print("|cFFFF0000HLBG:|r UI not initialized")
        return false
    end
    
    local success = pcall(function()
        -- Hide all tabs first
        for i, tab in ipairs(HLBG.UI.Tabs) do
            if HLBG.UI[HLBG.TabNames[i]] then
                HLBG.UI[HLBG.TabNames[i]]:Hide()
            end
        end
        
        -- Show selected tab
        if HLBG.TabNames[tabIndex] and HLBG.UI[HLBG.TabNames[tabIndex]] then
            HLBG.UI[HLBG.TabNames[tabIndex]]:Show()
            HLBG.UI.activeTab = tabIndex
            
            -- Update tab styling if modern UI is loaded
            if HLBG.UpdateModernTabStyling then
                HLBG.UpdateModernTabStyling()
            end
            
            return true
        end
        return false
    end)
    
    if not success then
        print("|cFFFF0000HLBG:|r Failed to show tab " .. tostring(tabIndex))
        return false
    end
    return true
end

-- Fix frame strata issues
function HLBG.EnsureFrameStrata(frame, strata)
    if frame and frame.SetFrameStrata then
        SafeUICall(frame.SetFrameStrata, frame, strata or "DIALOG")
    end
end

-- Enhanced debugging for empty tabs
function HLBG.DiagnoseEmptyTabs()
    print("|cFF33FF99HLBG Tab Diagnosis:|r")
    
    if not HLBG.UI then
        print("  UI not initialized")
        return
    end
    
    local tabNames = {"History", "Stats", "Info", "Results"}
    for i, name in ipairs(tabNames) do
        local tab = HLBG.UI[name]
        if tab then
            local visible = tab:IsShown()
            local hasContent = false
            
            if name == "History" then
                hasContent = tab.rows and #tab.rows > 0
            elseif name == "Stats" then
                hasContent = tab.Text and tab.Text:GetText() ~= ""
            end
            
            print(string.format("  %s: exists=%s, visible=%s, hasContent=%s", 
                name, tostring(tab ~= nil), tostring(visible), tostring(hasContent)))
        else
            print("  " .. name .. ": not found")
        end
    end
    
    -- Check for test data
    if HLBG.cachedStats then
        print("  Cached stats available: " .. tostring(type(HLBG.cachedStats)))
    else
        print("  No cached stats - loading test data")
        if HLBG.LoadTestData then
            HLBG.LoadTestData()
        end
    end
end

-- Register diagnosis command
SLASH_HLBGDIAG1 = "/hlbgdiag"
SlashCmdList["HLBGDIAG"] = function()
    HLBG.DiagnoseEmptyTabs()
end

-- Auto-fix initialization
local function AutoInitialize()
    -- Load test data if tabs are empty
    if HLBG.UI then
        local needsTestData = false
        
        if HLBG.UI.Stats and HLBG.UI.Stats.Text then
            local text = HLBG.UI.Stats.Text:GetText() or ""
            if text == "" or text:find("Loading") then
                needsTestData = true
            end
        end
        
        if HLBG.UI.History and (not HLBG.UI.History.rows or #HLBG.UI.History.rows == 0) then
            needsTestData = true
        end
        
        if needsTestData and HLBG.LoadTestData then
            print("|cFF33FF99HLBG:|r Auto-loading test data for empty tabs")
            HLBG.LoadTestData()
        end
        
        -- Apply modern styling
        if HLBG.ApplyModernStyling then
            HLBG.ApplyModernStyling()
        end
    end
end

-- Initialize after a short delay to ensure UI is loaded
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    C_Timer.After(2, function()
        AutoInitialize()
    end)
    self:UnregisterEvent(event)
end)

print("|cFF33FF99HLBG:|r Error fixes and compatibility improvements loaded")