-- HLBG_ZoneDetect.lua
-- Adds improved zone change detection to automatically activate HUD when entering The Hinterlands

local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Function to check if player is in The Hinterlands
local function InHinterlands()
    local z = (type(HLBG) == 'table' and type(HLBG.safeGetRealZoneText) == 'function') and HLBG.safeGetRealZoneText() or (GetRealZoneText and GetRealZoneText() or "")
    return z == "The Hinterlands"
end

-- Zone change detector frame
local zoneFrame = CreateFrame("Frame")

-- Register for all zone change events
zoneFrame:RegisterEvent("ZONE_CHANGED")
zoneFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
zoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Handler for zone change events
zoneFrame:SetScript("OnEvent", function(self, event, ...)
    -- Check if in The Hinterlands
    local inHinterlands = InHinterlands()
    
    -- Debug output (can be removed in production)
    if HLBG._devMode then
        print("|cFF33FF99HLBG Zone:|r Event: " .. event .. ", In Hinterlands: " .. (inHinterlands and "Yes" or "No"))
    end
    
    -- If we're in The Hinterlands
    if inHinterlands then
        -- Ensure the HUD is visible
        if type(HLBG.UpdateHUD) == 'function' then
            HLBG.UpdateHUD()
        end
        
        -- Request updated status from server
        if _G.AIO and _G.AIO.Handle then
            _G.AIO.Handle("HLBG", "Request", "STATUS")
        end
        
        -- Update UI state
        if HLBG.UI and HLBG.UI.Frame then
            -- Show the HLBG UI if configured
            if HinterlandAffixHUDDB and HinterlandAffixHUDDB.showOutside then
                HLBG.UI.Frame:Show()
                -- Select the Live tab
                if type(_G.ShowTab) == 'function' then
                    _G.ShowTab(1)  -- 1 is the Live tab index
                end
            end
        end
    end
end)

-- Also poll for zone changes to catch any missed events
do
    local lastZone = ""
    local checkInterval = 0
    
    zoneFrame:SetScript("OnUpdate", function(self, elapsed)
        checkInterval = checkInterval + elapsed
        
        -- Check every 2 seconds
        if checkInterval >= 2 then
            checkInterval = 0
            
            -- Get current zone
            local currentZone = (type(HLBG) == 'table' and type(HLBG.safeGetRealZoneText) == 'function') and 
                                HLBG.safeGetRealZoneText() or (GetRealZoneText and GetRealZoneText() or "")
            
            -- If zone changed
            if currentZone ~= lastZone then
                lastZone = currentZone
                
                -- If we're in The Hinterlands
                if currentZone == "The Hinterlands" then
                    -- Ensure the HUD is visible
                    if type(HLBG.UpdateHUD) == 'function' then
                        HLBG.UpdateHUD()
                    end
                    
                    -- Request updated status from server
                    if _G.AIO and _G.AIO.Handle then
                        _G.AIO.Handle("HLBG", "Request", "STATUS")
                    end
                    
                    -- Update UI state
                    if HLBG.UI and HLBG.UI.Frame then
                        -- Show the HLBG UI if configured
                        if HinterlandAffixHUDDB and HinterlandAffixHUDDB.showOutside then
                            HLBG.UI.Frame:Show()
                            -- Select the Live tab
                            if type(_G.ShowTab) == 'function' then
                                _G.ShowTab(1)  -- 1 is the Live tab index
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- Add to the TOC (this is just for documentation, not actually executed)
-- ## Title: Hinterland BG - Zone Detection
-- ## Notes: Improved zone detection for Hinterland Battleground
-- ## Dependencies: HinterlandAffixHUD
-- ## LoadOnDemand: 0
-- HLBG_ZoneDetect.lua

print("|cFF33FF99Hinterland BG:|r Zone detection module loaded")