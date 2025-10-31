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
    
    -- AZSHARA CRATER (Map ID 37, Zone ID 268)
    -- World coordinates: X from -1000 to 500, Y from -500 to 1500
    -- Map dimensions: 1500 x 2000 yards
    mapData[37] = {
        ['floors'] = 0,
        ['name'] = "AzsharaCrater",
        ['area_id'] = 268,
        ['rzti'] = 0,  -- Not an instance
        ['map_type'] = 0,  -- Normal zone
        ['continent'] = 0,  -- Custom continent
        ['link'] = 0,
        ['transform'] = 0,
        [1] = {
            1500.0,  -- width (maxX - minX = 500 - (-1000) = 1500)
            2000.0,  -- height (maxY - minY = 1500 - (-500) = 2000)
            500.0,   -- ulX (upper-left X - this is MAX X in WoW coords)
            1500.0,  -- ulY (upper-left Y - this is MAX Y in WoW coords)
            -1000.0, -- lrX (lower-right X - this is MIN X in WoW coords)
            -500.0   -- lrY (lower-right Y - this is MIN Y in WoW coords)
        }
    }
    
    -- HYJAL - Use zone 616 for Hyjal, NOT map 1
    -- For proper integration, we register it as a separate map
    -- World coordinates: X from 3600 to 5600, Y from -4800 to -2800
    -- Map dimensions: 2000 x 2000 yards
    mapData[616] = {
        ['floors'] = 0,
        ['name'] = "Hyjal",
        ['area_id'] = 616,
        ['rzti'] = 1,  -- Kalimdor
        ['map_type'] = 0,  -- Normal zone
        ['continent'] = 1,  -- Kalimdor
        ['link'] = 0,
        ['transform'] = 0,
        [1] = {
            2000.0,  -- width (maxX - minX = 5600 - 3600 = 2000)
            2000.0,  -- height (maxY - minY = -2800 - (-4800) = 2000)
            5600.0,  -- ulX (upper-left X - this is MAX X)
            -2800.0, -- ulY (upper-left Y - this is MAX Y, LESS negative)
            3600.0,  -- lrX (lower-right X - this is MIN X)
            -4800.0  -- lrY (lower-right Y - this is MIN Y, MORE negative)
        }
    }
    
    -- Register area ID to map name mapping
    if lib.idToMap then
        lib.idToMap[268] = "AzsharaCrater"  -- Azshara Crater
        lib.idToMap[616] = "Hyjal"          -- Hyjal
    end
    
    -- Register map name to localized name mapping (if needed)
    if lib.mapToLocal then
        lib.mapToLocal["AzsharaCrater"] = "Azshara Crater"
        lib.mapToLocal["Hyjal"] = "Hyjal"
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[DC-MapExtension] Registered custom zones in LibMapData-1.0|r")
end

-- Execute on load
RegisterCustomZones()
