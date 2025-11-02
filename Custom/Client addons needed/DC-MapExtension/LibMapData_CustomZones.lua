--[[
    LibMapData-1.0 Custom Zone Registration
    Registers Azshara Crater (Map 37) and Hyjal (Map 616) with LibMapData
    This allows proper coordinate transformation for POIs and player position
]]

-- Wait for LibMapData to load
local function RegisterCustomZones()
    local lib = LibStub:GetLibrary("LibMapData-1.0", true)
    if not lib then
        -- Schedule retry if library not loaded yet
        C_Timer.After(1, RegisterCustomZones)
        return
    end
    
    -- Access internal mapData table
    local mapData = lib.mapData or {}
    if not lib.mapData then
        lib.mapData = mapData
    end
    
    -- AZSHARA CRATER (UiMapID 613, Zone ID 268)
    -- Bounds sourced from WorldMapArea.csv (entry 613) for native map tiles
    mapData[613] = {
        ['floors'] = 0,
        ['name'] = "AzsharaCrater",
        ['area_id'] = 268,
        ['rzti'] = 1,  -- Kalimdor
        ['map_type'] = 0,  -- Normal zone
        ['continent'] = 2,  -- Kalimdor
        ['link'] = 0,
        ['transform'] = 0,
        [1] = {
            4311.0,    -- width (locLeft - locRight)
            2872.0,    -- height (locTop - locBottom)
            2427.0,    -- locLeft (upper-left X)
            1756.0,    -- locTop (upper-left Y)
            -1884.0,   -- locRight (lower-right X)
            -1116.0    -- locBottom (lower-right Y)
        }
    }
    
    -- HYJAL SUMMIT - custom world map entry (UiMapID 614)
    -- Bounds sourced from WorldMapArea.csv (entry 614)
    mapData[614] = {
        ['floors'] = 0,
        ['name'] = "Hyjal",
        ['area_id'] = 616,
        ['rzti'] = 1,  -- Kalimdor
        ['map_type'] = 0,  -- Normal zone
        ['continent'] = 2,  -- Kalimdor
        ['link'] = 0,
        ['transform'] = 0,
        [1] = {
            4245.833, -- width (locLeft - locRight)
            2831.25,  -- height (locTop - locBottom)
            -929.1666, -- locLeft (upper-left X)
            6195.833, -- locTop (upper-left Y)
            -5175.0,  -- locRight (lower-right X)
            3364.583  -- locBottom (lower-right Y)
        }
    }
    
    -- Register area ID to map name mapping
    if lib.idToMap then
        lib.idToMap["AzsharaCrater"] = 613
        lib.idToMap[268] = "AzsharaCrater"  -- Azshara Crater
        lib.idToMap["Hyjal"] = 614
        lib.idToMap[616] = "Hyjal"          -- Hyjal
    end
    
    -- Register map name to localized name mapping (if needed)
    if lib.mapToLocal then
        lib.mapToLocal["AzsharaCrater"] = "Azshara Crater"
        lib.mapToLocal["Hyjal"] = "Hyjal Summit"
    end

    if lib.localToMap then
        lib.localToMap["Azshara Crater"] = "AzsharaCrater"
        lib.localToMap["Hyjal Summit"] = "Hyjal"
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[DC-MapExtension] Registered custom zones in LibMapData-1.0|r")
end

-- Execute on load
RegisterCustomZones()
