-- DC-MapExtension Debug Test Script
-- Copy/paste this entire script into /wowlua and click "Run"

local function PrintSeparator()
    DEFAULT_CHAT_FRAME:AddMessage("==========================================")
end

local function TestMapState()
    PrintSeparator()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00DC-MapExtension Debug Info|r")
    PrintSeparator()
    
    -- Check addon exists
    if not DCMapExtensionDB then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000ERROR: DCMapExtensionDB not found!|r")
        return
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Addon State:|r")
    DEFAULT_CHAT_FRAME:AddMessage("  Enabled: " .. tostring(DCMapExtensionDB.enabled))
    DEFAULT_CHAT_FRAME:AddMessage("  Debug: " .. tostring(DCMapExtensionDB.debug))
    DEFAULT_CHAT_FRAME:AddMessage("  Show Player Dot: " .. tostring(DCMapExtensionDB.showPlayerDot))
    
    -- Get current map info
    local mapID = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
    local continent = GetCurrentMapContinent and GetCurrentMapContinent() or 0
    local zoneName = GetZoneText and GetZoneText() or "unknown"
    local realZone = GetRealZoneText and GetRealZoneText() or "unknown"
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Map Info:|r")
    DEFAULT_CHAT_FRAME:AddMessage("  Displayed Map ID: " .. mapID)
    DEFAULT_CHAT_FRAME:AddMessage("  Continent: " .. continent)
    DEFAULT_CHAT_FRAME:AddMessage("  Zone Name: " .. zoneName)
    DEFAULT_CHAT_FRAME:AddMessage("  Real Zone: " .. realZone)
    
    -- Check WorldMapFrame
    if WorldMapFrame then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00WorldMapFrame:|r")
        DEFAULT_CHAT_FRAME:AddMessage("  Shown: " .. tostring(WorldMapFrame:IsShown()))
        if WorldMapDetailFrame then
            DEFAULT_CHAT_FRAME:AddMessage("  Detail Frame Alpha: " .. string.format("%.2f", WorldMapDetailFrame:GetAlpha()))
        end
    end
    
    -- Check GPS data (if available)
    if DCMapExtension_GetGPSData then
        local gps = DCMapExtension_GetGPSData()
        if gps and gps.mapId then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00GPS Data:|r")
            DEFAULT_CHAT_FRAME:AddMessage("  Map ID: " .. (gps.mapId or "nil"))
            DEFAULT_CHAT_FRAME:AddMessage("  Zone ID: " .. (gps.zoneId or "nil"))
            if gps.x then
                DEFAULT_CHAT_FRAME:AddMessage("  Position: (" .. string.format("%.1f", gps.x) .. ", " .. string.format("%.1f", gps.y) .. ")")
            end
            if gps.nx then
                DEFAULT_CHAT_FRAME:AddMessage("  Normalized: (" .. string.format("%.3f", gps.nx) .. ", " .. string.format("%.3f", gps.ny) .. ")")
            end
            if gps.lastUpdate then
                local age = GetTime() - gps.lastUpdate
                DEFAULT_CHAT_FRAME:AddMessage("  Data Age: " .. string.format("%.1f", age) .. "s")
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00GPS Data: Not available or no data|r")
        end
    end
    
    PrintSeparator()
end

-- Run the test
TestMapState()

-- Print available functions
PrintSeparator()
DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Quick Test Commands:|r")
DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700Show Maps:|r")
DEFAULT_CHAT_FRAME:AddMessage("  /run DCMapExtension_ShowStitchedMap('azshara')")
DEFAULT_CHAT_FRAME:AddMessage("  /run DCMapExtension_ShowStitchedMap('hyjal')")
DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700Clear Map:|r")
DEFAULT_CHAT_FRAME:AddMessage("  /run DCMapExtension_ClearForcedMap()")
DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700Debug Toggle:|r")
DEFAULT_CHAT_FRAME:AddMessage("  /run DCMapExtensionDB.debug = not DCMapExtensionDB.debug")
DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700Force Blizzard Update:|r")
DEFAULT_CHAT_FRAME:AddMessage("  /run WorldMapFrame_UpdateMap()")
DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700Reload UI:|r")
DEFAULT_CHAT_FRAME:AddMessage("  /run ReloadUI()")
PrintSeparator()
