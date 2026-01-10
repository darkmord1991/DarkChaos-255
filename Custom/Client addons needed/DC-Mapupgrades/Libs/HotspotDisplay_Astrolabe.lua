-- Lightweight Astrolabe helper for DC Hotspot add-on
-- Provides minimal conversions from world/normalized coordinates to UI space
local Debug = _G.DC_DebugUtils

local function IsDebugEnabled()
    local db = rawget(_G, "DCMapupgradesDB")
    if type(db) ~= "table" then
        db = rawget(_G, "DCHotspotDB")
    end
    return type(db) == "table" and db.debug == true
end

local function DebugPrint(...)
    if Debug and Debug.PrintMulti then
        Debug:PrintMulti("Astrolabe", IsDebugEnabled(), ...)
    elseif IsDebugEnabled() then
        print("[Astrolabe] " .. table.concat({ ... }, " "))
    end
end

DebugPrint("Loading HotspotDisplay_Astrolabe.lua")
local Ast = {}

-- Normalize coordinates that can be expressed in 0..1 or 0..100 space
function Ast.NormalizeCoords(x, y)
    local nx = tonumber(x) or 0
    local ny = tonumber(y) or 0
    if nx > 1 then nx = nx / 100 end
    if ny > 1 then ny = ny / 100 end
    if nx < 0 then nx = 0 end
    if nx > 1 then nx = 1 end
    if ny < 0 then ny = 0 end
    if ny > 1 then ny = 1 end
    return nx, ny
end

-- Approximate world bounds for key maps. 
-- Values extracted from Custom/CSV DBC/WorldMapArea.csv (columns: LocLeft, LocRight, LocTop, LocBottom)
Ast.MapBounds = {
    [0] = { minX = -15973.34, maxX = 11176.34, minY = -22569.21, maxY = 18171.97 },  -- Eastern Kingdoms (Map 0, Area 0 "Azeroth")
    [1] = { minX = -11733.3, maxX = 12799.9, minY = -19733.21, maxY = 17066.6 },    -- Kalimdor (Map 1, Area 0 "Kalimdor")
    [530] = { minX = -5821.359, maxX = 5821.359, minY = -4468.039, maxY = 12996.04 }, -- Outland (Map 530, Area 0 "Expansion01")
    [571] = { minX = -1240.89, maxX = 10593.38, minY = -8534.246, maxY = 9217.152 },  -- Northrend (Map 571, Area 0 "Northrend")
    [37] = { minX = -1116, maxX = 1756, minY = -1884, maxY = 2427 },                -- Azshara Crater (Map 37, Area 268)
}

-- Convert absolute world-space coordinates into normalized 0..1 range when bounds available
function Ast.WorldCoordsToNormalized(mapId, x, y)
    -- Debug: log what we receive
    if not _G.DC_HOTSPOT_ASTRO_LOGGED then
        DebugPrint("WorldCoordsToNormalized called:", "mapId=" .. tostring(mapId), "x=" .. tostring(x), "y=" .. tostring(y))
        _G.DC_HOTSPOT_ASTRO_LOGGED = true
    end
    
    local bounds = Ast.MapBounds[mapId]
    if not bounds then
        if not _G.DC_HOTSPOT_NO_BOUNDS_LOGGED then
            DebugPrint("No bounds for mapId", tostring(mapId))
            _G.DC_HOTSPOT_NO_BOUNDS_LOGGED = true
        end
        return nil, nil
    end
    
    if type(x) ~= "number" or type(y) ~= "number" then
        DebugPrint("Invalid x/y types:", type(x) .. "/" .. type(y))
        return nil, nil
    end
    
    -- WoW World Coordinates to UI Map Coordinates Transformation
    -- World X = North(+)/South(-). Vertical axis.
    -- World Y = West(+)/East(-). Horizontal axis.
    
    -- Bounds: MinX/MaxX defines Vertical Range (South -> North)
    -- Bounds: MinY/MaxY defines Horizontal Range (East -> West)
    
    -- 1. Normalize World X (Vertical) to 0..1 (South -> North)
    local normX = (x - bounds.minX) / (bounds.maxX - bounds.minX)
    
    -- 2. Normalize World Y (Horizontal) to 0..1 (East -> West)
    local normY = (y - bounds.minY) / (bounds.maxY - bounds.minY)
    
    -- 3. Map to UI Coordinates
    -- UI X (Horizontal): Left (0) -> Right (1)
    -- World Y: West (High, 1) should be Left (0). East (Low, 0) should be Right (1).
    local nx = 1 - normY
    
    -- UI Y (Vertical): Top (0) -> Bottom (1)
    -- World X: North (High, 1) should be Top (0). South (Low, 0) should be Bottom (1).
    local ny = 1 - normX
    
    if not _G.DC_HOTSPOT_CONVERSION_LOGGED then
        DebugPrint(string.format("Converted: (%d, %.1f, %.1f) -> (%.4f, %.4f)", mapId, x, y, nx, ny))
        _G.DC_HOTSPOT_CONVERSION_LOGGED = true
    end
    
    -- Clamp to 0-1 range
    if nx < 0 then nx = 0 end
    if nx > 1 then nx = 1 end
    if ny < 0 then ny = 0 end
    if ny > 1 then ny = 1 end
    
    return nx, ny
end

-- Convert normalized coords (or raw coords with mapId) to pixel offsets relative to TOPLEFT of a map frame
function Ast.WorldToMapPixels(mapFrame, nx_or_mapId, ny_or_x, maybe_y)
    if not mapFrame then return 0, 0 end
    local nx, ny
    if type(nx_or_mapId) == "number" and type(ny_or_x) == "number" and type(maybe_y) == "number" then
        nx, ny = Ast.WorldCoordsToNormalized(nx_or_mapId, ny_or_x, maybe_y)
    else
        nx, ny = Ast.NormalizeCoords(nx_or_mapId, ny_or_x)
    end
    local w = mapFrame:GetWidth() or 0
    local h = mapFrame:GetHeight() or 0
    return nx * w, ny * h
end

-- Compute minimap offsets for a target relative to player normalized coords
function Ast.WorldToMinimapOffset(minimapFrame, playerNx, playerNy, targetNx, targetNy)
    if not minimapFrame then return 0, 0 end
    local px, py = Ast.NormalizeCoords(playerNx, playerNy)
    local tx, ty = Ast.NormalizeCoords(targetNx, targetNy)
    local dx = (tx - px)
    local dy = (ty - py)
    local angle = math.atan(dy, dx)
    local dist = math.sqrt(dx * dx + dy * dy)
    local radius = (minimapFrame:GetWidth() or 140) / 2 - 6
    local r = math.min(radius, dist * radius * 1.6)
    return r * math.cos(angle), r * math.sin(angle)
end

_G.HotspotDisplay_Astrolabe = Ast
DebugPrint("HotspotDisplay_Astrolabe registered in _G")
return Ast
