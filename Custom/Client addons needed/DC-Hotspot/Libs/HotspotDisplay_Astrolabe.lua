-- Lightweight Astrolabe helper for DC Hotspot add-on
-- Provides minimal conversions from world/normalized coordinates to UI space
print("|cff00ff00[DC-Hotspot] Loading HotspotDisplay_Astrolabe.lua|r")
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

-- Approximate world bounds for key maps. These values get overridden by server supplied normalized coords when available
Ast.MapBounds = {
    [0] = { minX = -12000, maxX = 12000, minY = -12000, maxY = 12000 }, -- Eastern Kingdoms
    [1] = { minX = -12000, maxX = 12000, minY = -12000, maxY = 12000 }, -- Kalimdor
    [530] = { minX = -5000, maxX = 5000, minY = -5000, maxY = 5000 },   -- Outland
    [571] = { minX = -8000, maxX = 8000, minY = -8000, maxY = 8000 },   -- Northrend
    [37] = { minX = -500, maxX = 500, minY = 700, maxY = 1400 },        -- Azshara Crater
}

-- Convert absolute world-space coordinates into normalized 0..1 range when bounds available
function Ast.WorldCoordsToNormalized(mapId, x, y)
    -- Debug: log what we receive
    if not _G.DC_HOTSPOT_ASTRO_LOGGED then
        print("|cff00ffff[Astrolabe] WorldCoordsToNormalized called: mapId=" .. tostring(mapId) .. " x=" .. tostring(x) .. " y=" .. tostring(y) .. "|r")
        _G.DC_HOTSPOT_ASTRO_LOGGED = true
    end
    
    local bounds = Ast.MapBounds[mapId]
    if not bounds then
        if not _G.DC_HOTSPOT_NO_BOUNDS_LOGGED then
            print("|cffff0000[Astrolabe] No bounds for mapId " .. tostring(mapId) .. "|r")
            _G.DC_HOTSPOT_NO_BOUNDS_LOGGED = true
        end
        return nil, nil
    end
    
    if type(x) ~= "number" or type(y) ~= "number" then
        print("|cffff0000[Astrolabe] Invalid x/y types: " .. type(x) .. "/" .. type(y) .. "|r")
        return nil, nil
    end
    
    local nx = (x - bounds.minX) / (bounds.maxX - bounds.minX)
    local ny = (y - bounds.minY) / (bounds.maxY - bounds.minY)
    
    if not _G.DC_HOTSPOT_CONVERSION_LOGGED then
        print(string.format("|cff00ff00[Astrolabe] Converted: (%d, %.1f, %.1f) -> (%.4f, %.4f)|r", mapId, x, y, nx, ny))
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
print("|cff00ff00[DC-Hotspot] HotspotDisplay_Astrolabe registered in _G|r")
return Ast
