-- HLBG_TabStability.lua - Fix issues with tab switching

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Track tab switches to prevent rapid flipping
HLBG._lastTabSwitch = HLBG._lastTabSwitch or 0
HLBG._currentTab = HLBG._currentTab or nil
HLBG._tabSwitchCooldown = 1.0  -- minimum time between tab switches in seconds

-- Create a throttled version of ShowTab if it doesn't exist already
if not HLBG._stableShowTab and type(_G.ShowTab) == 'function' then
    HLBG._originalShowTabFunc = _G.ShowTab
    
    HLBG._stableShowTab = function(tabId)
        -- Get current time
        local now = GetTime()
        
        -- Check if this is the same tab we're already on
        if HLBG._currentTab == tabId then
            return
        end
        
        -- Check if we're still on cooldown
        if (now - HLBG._lastTabSwitch) < HLBG._tabSwitchCooldown then
            if HLBG._devMode then
                HLBG.DebugPrint("Tab switch blocked - too soon (cooldown: " .. HLBG._tabSwitchCooldown .. "s)")
            end
            return
        end
        
        -- Update tracking variables
        HLBG._lastTabSwitch = now
        HLBG._currentTab = tabId
        
        -- Actually switch the tab
        HLBG._originalShowTabFunc(tabId)
    end
    
    -- Override the global ShowTab function with our stable version
    _G.ShowTab = HLBG._stableShowTab
    
    -- If the user previously saved a tab, wait a moment then set that tab
    local function restoreTab()
        if HinterlandAffixHUDDB and HinterlandAffixHUDDB.lastInnerTab then
            HLBG._stableShowTab(HinterlandAffixHUDDB.lastInnerTab)
        end
    end
    
    -- Use our safe DelayedExecution function if available
    if HLBG.DelayedExecution then
        HLBG.DelayedExecution(0.5, restoreTab)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(0.5, restoreTab)
    else
        -- If no timer is available, try to restore immediately
        restoreTab()
    end
end

-- Fix for clicking tabs too quickly
local function StabilizeTabClicks()
    -- Find all tab buttons and add cooldown to their click handlers
    if HLBG.UI and HLBG.UI.Tabs then
        for i, tab in ipairs(HLBG.UI.Tabs) do
            if tab and tab:GetScript("OnClick") then
                local originalOnClick = tab:GetScript("OnClick")
                tab:SetScript("OnClick", function(self, ...)
                    -- Get current time
                    local now = GetTime()
                    
                    -- Check if we're still on cooldown
                    if (now - HLBG._lastTabSwitch) < HLBG._tabSwitchCooldown then
                        if HLBG._devMode then
                            HLBG.DebugPrint("Tab click blocked - too soon")
                        end
                        return
                    end
                    
                    -- Update tracking variable
                    HLBG._lastTabSwitch = now
                    
                    -- Call original handler
                    originalOnClick(self, ...)
                end)
            end
        end
    end
end

-- Run our tab click stabilizer after a short delay
if HLBG.DelayedExecution then
    HLBG.DelayedExecution(1.0, StabilizeTabClicks)
elseif C_Timer and C_Timer.After then
    C_Timer.After(1.0, StabilizeTabClicks)
else
    -- If no timer is available, try to stabilize immediately
    StabilizeTabClicks()
end