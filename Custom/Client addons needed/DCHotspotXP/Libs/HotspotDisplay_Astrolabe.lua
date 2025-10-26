-- Small Astrolabe-like helper for HotspotDisplay
-- Purpose: provide basic coordinate conversions for WotLK-style clients
-- Not a full Astrolabe implementation; provides two helpers:
--  - NormalizeCoords(x,y): ensure coords are 0..1
--  - WorldToMapPixels(mapFrame, nx, ny): returns pixel X,Y relative to mapFrame TOPLEFT
--  - WorldToMinimapOffset(minimapFrame, playerNx, playerNy, targetNx, targetNy): returns x,y offset relative to minimap center

local Ast = {}

-- Normalize coords that can be in 0..1 or 0..100 space
function Ast.NormalizeCoords(x, y)
    local nx = tonumber(x) or 0
    local ny = tonumber(y) or 0
    if nx > 1 then nx = nx / 100 end
    if ny > 1 then ny = ny / 100 end
    return nx, ny
end

-- Minimal map metadata table for common maps. Coordinates are world-space bounds used to normalize world coords.
-- These bounds are approximate and can be refined later using DBC data or a more complete table.
-- mapId => { minX, maxX, minY, maxY, continent }
Ast.MapBounds = {
    [0] = { minX = -12000, maxX = 12000, minY = -12000, maxY = 12000, continent = 0 }, -- Eastern Kingdoms rough
    [1] = { minX = -12000, maxX = 12000, minY = -12000, maxY = 12000, continent = 1 }, -- Kalimdor rough
    [530] = { minX = -5000, maxX = 5000, minY = -5000, maxY = 5000, continent = 530 }, -- Outland rough
    [571] = { minX = -8000, maxX = 8000, minY = -8000, maxY = 8000, continent = 571 }, -- Northrend rough
    [37] = { minX = -500, maxX = 500, minY = 700, maxY = 1400, continent = 0 }, -- Azshara crater rough bounds used by server presets
}

-- Convert absolute world-space coordinates (mapId,x,y) into normalized 0..1 coords using MapBounds when available.
-- Falls back to caller normalization (if x,y already normalized) when metadata missing.
function Ast.WorldCoordsToNormalized(mapId, x, y)
    local bounds = Ast.MapBounds[mapId]
    if bounds and type(x) == "number" and type(y) == "number" then
        local nx = (x - bounds.minX) / (bounds.maxX - bounds.minX)
        local ny = (y - bounds.minY) / (bounds.maxY - bounds.minY)
        -- clamp
        if nx < 0 then nx = 0 end
        if nx > 1 then nx = 1 end
        if ny < 0 then ny = 0 end
        if ny > 1 then ny = 1 end
        return nx, ny
    end
    -- fallback: treat inputs as already normalized
    return Ast.NormalizeCoords(x, y)
end

-- Convert normalized coords to pixel offsets relative to mapFrame top-left
-- Convert normalized coords to pixel offsets relative to mapFrame top-left
-- If mapId is provided along with raw world coords, it will convert them using bounds
function Ast.WorldToMapPixels(mapFrame, nx_or_mapId, ny_or_x, maybe_y)
    if not mapFrame then return 0, 0 end
    local nx, ny
    if type(nx_or_mapId) == "number" and type(ny_or_x) == "number" and type(maybe_y) == "number" then
        -- signature: (mapFrame, mapId, x, y)
        local mapId = nx_or_mapId
        local x = ny_or_x
        local y = maybe_y
        nx, ny = Ast.WorldCoordsToNormalized(mapId, x, y)
    else
        -- signature: (mapFrame, nx, ny)
        nx = nx_or_mapId
        ny = ny_or_x
        nx, ny = Ast.NormalizeCoords(nx, ny)
    end

    local w = mapFrame:GetWidth() or 0
    local h = mapFrame:GetHeight() or 0
    -- mapFrame coordinate origin for our overlay is TOPLEFT; we use nx,ny in 0..1 where 0,0 = top-left
    local px = nx * w
    local py = ny * h
    return px, py
end

-- Approximate minimap offset: produces x,y in pixels relative to minimap center.
-- playerNx/playerNy and targetNx/targetNy are normalized coords (0..1)
-- This is not perfect but provides stable results in WotLK where Minimap is a circle and maps are local.
-- Compute minimap offset. Accepts either normalized coords or (mapId, worldX, worldY) signatures.
function Ast.WorldToMinimapOffset(minimapFrame, playerNx_or_mapId, playerNy_or_x, targetNx_or_y, maybe_y)
    if not minimapFrame then return 0, 0 end
    local pnx, pny, tnx, tny
    if type(playerNx_or_mapId) == "number" and type(playerNy_or_x) == "number" and type(targetNx_or_y) == "number" and type(maybe_y) == "number" then
        -- signature: (minimapFrame, mapId, playerX, playerY, targetX, targetY) is ambiguous; support (minimapFrame, mapId, playerX, playerY) + (targetX,targetY) not supported here
        -- Fallback: treat as normalized coords
        pnx = playerNx_or_mapId
        pny = playerNy_or_x
        tnx = targetNx_or_y
        tny = maybe_y
    else
        -- signature: (minimapFrame, playerNx, playerNy, targetNx, targetNy)
        pnx = playerNx_or_mapId
        pny = playerNy_or_x
        tnx = targetNx_or_y
        tny = maybe_y
    end

    pnx, pny = Ast.NormalizeCoords(pnx, pny)
    tnx, tny = Ast.NormalizeCoords(tnx, tny)

    local dx = (tnx - pnx)
    local dy = (tny - pny)
    -- compute angle and distance, scale to minimap radius
    local angle = math.atan2(dy, dx)
    local dist = math.sqrt(dx*dx + dy*dy)
    local radius = (minimapFrame:GetWidth() or 140) / 2 - 6
    local r = math.min(radius, dist * radius * 1.6)
    local ox = r * math.cos(angle)
    local oy = r * math.sin(angle)
    return ox, oy
end

-- Expose globally for WoW addon loading (if file is included via TOC)
_G.HotspotDisplay_Astrolabe = Ast
return Ast
