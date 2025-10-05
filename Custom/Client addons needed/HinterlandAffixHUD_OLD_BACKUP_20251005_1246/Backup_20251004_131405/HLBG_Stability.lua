-- HLBG_Stability.lua
-- Enhanced stability fixes for Hinterland Battleground AddOn

local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Table to track last request times to prevent spam
local lastRequestTimes = {}
local REQUEST_COOLDOWN = 5.0 -- Very high cooldown period for identical requests (increased from 3.0)
local GLOBAL_COOLDOWN = 1.0 -- Global cooldown for all requests to prevent bursting (increased from 0.5)
local STATUS_COOLDOWN = 3.0 -- Special cooldown for status requests

-- Flag to indicate whether HistoryStr has been patched
local historyStrPatched = false

-- Helper function to replace the original AIO Handle function with a throttled version
function HLBG.InitializeRequestThrottling()
    -- Only modify if not already done
    if HLBG._requestThrottlingInitialized then
        return
    end
    
    -- Check if AIO exists
    if not (_G.AIO and _G.AIO.Handle) then
        return
    end
    
    -- Store the original Handle function
    local originalHandle = _G.AIO.Handle
    
    -- Track the last time any request was made for global throttling
    local lastGlobalRequestTime = 0
    
    -- Replace with our throttled version
    _G.AIO.Handle = function(namespace, command, ...)
        -- Only throttle HLBG requests
        if namespace == "HLBG" then
            local args = {...}
            local now = GetTime()
            
            -- Apply global cooldown for all requests to prevent bursting
            if (now - lastGlobalRequestTime) < GLOBAL_COOLDOWN then
                -- Skip if within global cooldown
                if HLBG._devMode then
                    print("|cFFFFAA00HLBG Debug:|r Global throttled request: " .. namespace .. "_" .. command)
                end
                return
            end
            
            -- Create a unique key for this request type
            local key = namespace .. "_" .. command
            
            -- Add the first argument to the key for more specific throttling
            if #args > 0 then
                key = key .. "_" .. tostring(args[1])
            end
            
            -- Check if this specific request is on cooldown
            local lastTime = lastRequestTimes[key] or 0
            
            if (now - lastTime) < REQUEST_COOLDOWN then
                -- Skip if request is on cooldown
                if HLBG._devMode then
                    print("|cFFFFAA00HLBG Debug:|r Throttled request: " .. key)
                end
                return
            end
            
            -- Update last request times
            lastRequestTimes[key] = now
            lastGlobalRequestTime = now
            
            -- If this is a STATUS request, add special handling
            if command == "Request" and args[1] == "STATUS" then
                -- Update again in 1 second to ensure we have fresh data
                -- We need to store the args since ... can't be used in nested functions
                local storedArgs = {...}
                C_Timer.After(1.0, function()
                    originalHandle(namespace, command, unpack(storedArgs))
                end)
            end
        end
        
        -- Forward to original handler
        return originalHandle(namespace, command, ...)
    end
    
    HLBG._requestThrottlingInitialized = true
    print("|cFF33FF99HLBG:|r Request throttling initialized")
end

-- Function to ensure Stats displays properly
function HLBG.EnsureStatsDisplay()
    -- Patch the Stats function to handle various formats
    if type(HLBG.Stats) == 'function' then
        local originalStats = HLBG.Stats
        
        HLBG.Stats = function(stats)
            -- Validate stats data
            if not stats or type(stats) ~= 'table' then
                stats = {
                    counts = {Alliance = 0, Horde = 0},
                    draws = 0,
                    avgDuration = 0
                }
            end
            
            -- Ensure required fields exist
            stats.counts = stats.counts or {Alliance = 0, Horde = 0}
            stats.draws = stats.draws or 0
            stats.avgDuration = stats.avgDuration or 0
            
            -- Call original function
            local result = originalStats(stats)
            
            -- Ensure text is visible in the UI
            if HLBG.UI and HLBG.UI.Stats and HLBG.UI.Stats.Text then
                local text = HLBG.UI.Stats.Text:GetText() or ""
                if text == "" then
                    HLBG.UI.Stats.Text:SetText("Alliance: " .. (stats.counts.Alliance or 0) .. 
                                              "  Horde: " .. (stats.counts.Horde or 0) .. 
                                              "  Draws: " .. (stats.draws or 0) .. 
                                              "  Avg: " .. math.floor((stats.avgDuration or 0)/60) .. " min")
                end
            end
            
            return result
        end
        
        print("|cFF33FF99HLBG:|r Stats function patched")
    end
end

-- Function to fix History string handling to prevent errors
function HLBG.PatchHistoryFunctions()
    if historyStrPatched then
        return
    end
    
    -- Also ensure Stats display
    HLBG.EnsureStatsDisplay()
    
    -- Fix HistoryStr to handle invalid input gracefully
    if type(HLBG.HistoryStr) == 'function' then
        local originalHistoryStr = HLBG.HistoryStr
        
        HLBG.HistoryStr = function(tsv, page, per, total, col, dir)
            -- Convert tsv to string if needed
            if type(tsv) ~= 'string' then
                if type(tsv) == 'table' then
                    -- Try to convert table to TSV format
                    local lines = {}
                    for _, row in ipairs(tsv) do
                        if type(row) == 'table' then
                            local id = row.id or row[1] or ""
                            local ts = row.ts or row[2] or ""
                            local win = row.winner or row[3] or ""
                            local aff = row.affix or row[4] or ""
                            local reason = row.reason or row[5] or ""
                            table.insert(lines, id .. "\t" .. ts .. "\t" .. win .. "\t" .. aff .. "\t" .. reason)
                        end
                    end
                    tsv = table.concat(lines, "\n")
                else
                    -- Not a string or table, use empty string
                    print("|cFFFF0000HLBG Error:|r Invalid history data type: " .. type(tsv))
                    tsv = ""
                end
            end
            
            -- Safety check - avoid processing very long strings
            if #tsv > 50000 then
                tsv = tsv:sub(1, 50000)
                print("|cFFFF0000HLBG Warning:|r History data truncated (too large)")
            end
            
            -- Now call the original function with validated input
            return originalHistoryStr(tsv, page, per, total, col, dir)
        end
        
        historyStrPatched = true
        print("|cFF33FF99HLBG:|r HistoryStr function patched")
    end
    
    -- Fix History function to handle string inputs
    if type(HLBG.History) == 'function' then
        local originalHistory = HLBG.History
        
        HLBG.History = function(rows, page, per, total, col, dir)
            -- Handle string inputs gracefully
            if type(rows) == 'string' then
                print("|cFFFF0000HLBG Error:|r History received string instead of rows array")
                
                -- Try to parse it
                local parsed = {}
                for line in string.gmatch(rows, '[^\n]+') do
                    local parts = {}
                    for part in string.gmatch(line, '[^\t]+') do
                        table.insert(parts, part)
                    end
                    
                    if #parts >= 4 then
                        table.insert(parsed, {
                            id = parts[1],
                            ts = parts[2],
                            winner = parts[3],
                            affix = parts[4],
                            reason = parts[5] or ""
                        })
                    end
                end
                
                if #parsed > 0 then
                    rows = parsed
                else
                    rows = {}
                end
            end
            
            -- Ensure rows is a table before passing to original function
            if type(rows) ~= 'table' then
                print("|cFFFF0000HLBG Error:|r History received invalid rows type: " .. type(rows))
                rows = {}
            end
            
            -- Check if we already have a history pane with navigation buttons
            if HLBG.UI and HLBG.UI.History then
                local h = HLBG.UI.History
                
                -- Clean up any duplicate Next/Prev buttons
                local function cleanupButtons()
                    local nextButtons = {}
                    local prevButtons = {}
                    
                    -- Collect all buttons in the history frame
                    for _, child in pairs({h:GetChildren()}) do
                        if child:GetObjectType() == "Button" then
                            local text = child:GetText() or ""
                            if text == "Next" or text == "Next>" then
                                table.insert(nextButtons, child)
                            elseif text == "Previous" or text == "<Previous" then
                                table.insert(prevButtons, child)
                            end
                        end
                    end
                    
                    -- Hide duplicate buttons
                    if #nextButtons > 1 then
                        for i = 2, #nextButtons do
                            nextButtons[i]:Hide()
                        end
                    end
                    
                    if #prevButtons > 1 then
                        for i = 2, #prevButtons do
                            prevButtons[i]:Hide()
                        end
                    end
                end
                
                -- Clean up buttons after calling the original function
                local result = originalHistory(rows, page, per, total, col, dir)
                C_Timer.After(0.1, cleanupButtons)
                return result
            else
                -- Just call original function
                return originalHistory(rows, page, per, total, col, dir)
            end
        end
        
        print("|cFF33FF99HLBG:|r History function patched with duplicate button cleanup")
    end
end

-- Function to enhance zone detection for HUD activation
function HLBG.EnhanceZoneDetection()
    -- Ensure the UpdateLiveFromStatus doesn't spam
    if type(HLBG.UpdateLiveFromStatus) == 'function' then
        local originalUpdateLive = HLBG.UpdateLiveFromStatus
        local lastUpdate = 0
        
        HLBG.UpdateLiveFromStatus = function()
            local now = GetTime()
            if now - lastUpdate < 1.0 then
                return
            end
            
            lastUpdate = now
            return originalUpdateLive()
        end
        
        print("|cFF33FF99HLBG:|r UpdateLiveFromStatus patched with throttling")
    end
    
    -- Add anti-flicker protection for the HUD if it exists
    if HLBG.UI and HLBG.UI.HUD then
        -- Save the original Show function
        local originalShow = HLBG.UI.HUD.Show
        local lastShowTime = 0
        
        -- Replace with our throttled version
        HLBG.UI.HUD.Show = function(self)
            local now = GetTime()
            -- Only allow showing once every 2 seconds to prevent flickering
            if now - lastShowTime < 2.0 then
                return
            end
            
            lastShowTime = now
            return originalShow(self)
        end
        
        -- Track visibility changes
        local lastVisibilityChange = 0
        local frame = CreateFrame("Frame")
        frame:SetScript("OnUpdate", function(self, elapsed)
            if not HLBG.UI or not HLBG.UI.HUD then return end
            
            local now = GetTime()
            -- If the HUD is showing but was recently hidden, force it to stay visible
            if HLBG.UI.HUD:IsShown() then
                lastVisibilityChange = now
            elseif now - lastVisibilityChange < 3.0 then
                -- If it was recently shown but is now hidden, force show it again
                local z = (type(HLBG.safeGetRealZoneText) == 'function') and 
                         HLBG.safeGetRealZoneText() or (GetRealZoneText and GetRealZoneText() or "")
                
                if z == "The Hinterlands" then
                    HLBG.UI.HUD:Show()
                end
            end
        end)
        
        print("|cFF33FF99HLBG:|r HUD visibility stabilization added")
    end
    
    -- Create a frame to handle zone checking
    local zoneFrame = CreateFrame("Frame")
    local lastZoneCheck = 0
    
    -- Function to check zone and update UI
    local function checkZone()
        -- Get current zone
        local z = (type(HLBG.safeGetRealZoneText) == 'function') and 
                  HLBG.safeGetRealZoneText() or (GetRealZoneText and GetRealZoneText() or "")
        
        -- Check if in The Hinterlands
        if z == "The Hinterlands" then
            -- Show HUD if not shown
            if HLBG.UI and HLBG.UI.HUD and not HLBG.UI.HUD:IsShown() then
                HLBG.UI.HUD:Show()
                print("|cFF33FF99HLBG:|r Showing HUD in The Hinterlands")
                
                -- Request status update
                if _G.AIO and _G.AIO.Handle then
                    _G.AIO.Handle("HLBG", "Request", "STATUS")
                end
            end
        else
            -- Hide HUD when not in The Hinterlands
            if HLBG.UI and HLBG.UI.HUD and HLBG.UI.HUD:IsShown() then
                HLBG.UI.HUD:Hide()
                print("|cFF33FF99HLBG:|r Hiding HUD outside The Hinterlands")
            end
        end
    end
    
    -- Register for zone change events
    zoneFrame:RegisterEvent("ZONE_CHANGED")
    zoneFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    zoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    zoneFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    zoneFrame:SetScript("OnEvent", function(self, event)
        C_Timer.After(0.5, checkZone)
    end)
    
    -- Also periodically check zone
    zoneFrame:SetScript("OnUpdate", function(self, elapsed)
        lastZoneCheck = lastZoneCheck + elapsed
        
        if lastZoneCheck >= 3.0 then  -- Check every 3 seconds
            lastZoneCheck = 0
            checkZone()
        end
    end)
    
    -- Initial check
    C_Timer.After(1.0, checkZone)
    
    print("|cFF33FF99HLBG:|r Enhanced zone detection initialized")
end

-- Patch the startup code without modifying the file
function HLBG.PatchStartupDiagnostic()
    -- Create a registration frame for events that we need to handle for stability
    local patchFrame = CreateFrame("Frame")
    
    -- Register for all relevant events
    patchFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    patchFrame:RegisterEvent("ZONE_CHANGED")
    patchFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    patchFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    patchFrame:RegisterEvent("ADDON_LOADED")
    
    -- Event handler
    patchFrame:SetScript("OnEvent", function(self, event, arg1)
        if event == "ADDON_LOADED" then
            local addonName = arg1
            if addonName == "HinterlandAffixHUD" or addonName == "AIO_Client" then
                -- Wait a moment then initialize
                C_Timer.After(1.0, function()
                    HLBG.InitializeStabilityFixes()
                end)
            end
        elseif event:find("ZONE") or event == "PLAYER_ENTERING_WORLD" then
            -- Wait a short moment then check the zone
            C_Timer.After(0.5, function()
                local z = (type(HLBG.safeGetRealZoneText) == 'function') and 
                         HLBG.safeGetRealZoneText() or (GetRealZoneText and GetRealZoneText() or "")
                
                if z == "The Hinterlands" then
                    print("|cFF33FF99HLBG:|r Zone detected: The Hinterlands")
                    -- Show HUD if not shown
                    if HLBG.UI and HLBG.UI.HUD and not HLBG.UI.HUD:IsShown() then
                        HLBG.UI.HUD:Show()
                        print("|cFF33FF99HLBG:|r Showing HUD")
                        
                        -- Request status update
                        if _G.AIO and _G.AIO.Handle then
                            _G.AIO.Handle("HLBG", "Request", "STATUS")
                        end
                    end
                end
            end)
        end
    end)
    
    print("|cFF33FF99HLBG:|r Startup diagnostic patched")
end

-- Main initialization function
function HLBG.InitializeStabilityFixes()
    -- Fix request throttling
    HLBG.InitializeRequestThrottling()
    
    -- Patch history functions
    HLBG.PatchHistoryFunctions()
    
    -- Enhance zone detection
    HLBG.EnhanceZoneDetection()
    
    -- Patch the startup diagnostic
    HLBG.PatchStartupDiagnostic()
    
    -- Run UI fixes if available (from HLBG_DedupeHUD.lua)
    if type(HLBG.FixAllUIIssues) == 'function' then
        C_Timer.After(1.0, HLBG.FixAllUIIssues)
        C_Timer.After(3.0, HLBG.FixAllUIIssues) -- Run again after a delay to catch any late-loaded issues
    end
    
    -- Register a slash command to manually reinitialize stability fixes if needed
    if type(HLBG.safeRegisterSlash) == 'function' then
        HLBG.safeRegisterSlash('HLBGSTABILIZE', '/hlbgstabilize', function()
            print("|cFF33FF99HLBG:|r Reinitializing stability fixes")
            HLBG.InitializeStabilityFixes()
        end)
    else
        -- Fallback registration
        _G["SLASH_HLBGSTABILIZE1"] = "/hlbgstabilize"
        SlashCmdList["HLBGSTABILIZE"] = function()
            print("|cFF33FF99HLBG:|r Reinitializing stability fixes")
            HLBG.InitializeStabilityFixes()
        end
    end
    
    print("|cFF33FF99HLBG:|r Stability fixes initialized. Type /hlbgstabilize to reinitialize if needed.")
end

-- Emergency UI refresh function
function HLBG.EmergencyUiRefresh()
    print("|cFF33FF99HLBG:|r Emergency UI refresh started...")
    
    -- Hide any existing HUD to prevent duplicates
    if HLBG.UI and HLBG.UI.HUD then
        HLBG.UI.HUD:Hide()
    end
    
    -- Re-initialize stability fixes
    HLBG.InitializeStabilityFixes()
    
    -- Check zone and update UI
    local z = (type(HLBG.safeGetRealZoneText) == 'function') and 
             HLBG.safeGetRealZoneText() or (GetRealZoneText and GetRealZoneText() or "")
    
    if z == "The Hinterlands" then
        print("|cFF33FF99HLBG:|r In The Hinterlands, showing HUD")
        
        -- Delayed show of HUD to ensure it's properly initialized
        C_Timer.After(0.5, function()
            if HLBG.UI and HLBG.UI.HUD then
                HLBG.UI.HUD:Show()
            end
            
            -- Request fresh data with a delay
            C_Timer.After(1.0, function()
                if _G.AIO and _G.AIO.Handle then
                    _G.AIO.Handle("HLBG", "Request", "STATUS")
                end
            end)
        end)
    else
        print("|cFF33FF99HLBG:|r Not in The Hinterlands, HUD will remain hidden")
    end
    
    print("|cFF33FF99HLBG:|r Emergency UI refresh complete!")
end

-- Register emergency reload command
if type(HLBG.safeRegisterSlash) == 'function' then
    HLBG.safeRegisterSlash('HLBGRELOAD', '/hlbgreload', function()
        HLBG.EmergencyUiRefresh()
    end)
else
    -- Fallback registration
    _G["SLASH_HLBGRELOAD1"] = "/hlbgreload"
    SlashCmdList["HLBGRELOAD"] = function()
        HLBG.EmergencyUiRefresh()
    end
end

-- Initialize when the file loads
C_Timer.After(0.5, function()
    HLBG.InitializeStabilityFixes()
end)