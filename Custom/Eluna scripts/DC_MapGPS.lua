--[[
    DC-MapExtension GPS Broadcaster
    Sends player position data to DC-MapExtension client addon via AIO
    Updates every 2 seconds for players in custom zones
]]

local AIO = AIO or require("AIO")

-- Don't run on client
if not AIO.IsServer() then
    return
end

-- Custom zone definitions
local CUSTOM_ZONES = {
    [37] = { -- Azshara Crater
        name = "Azshara Crater",
        zoneId = 268,
        minX = -1000.0,
        maxX = 500.0,
        minY = -500.0,
        maxY = 1500.0
    },
    [1] = { -- Hyjal (requires zone check)
        name = "Hyjal",
        zoneId = 616,
        minX = -5000.0,
        maxX = -3000.0,
        minY = -2000.0,
        maxY = 0.0
    }
}

-- Normalize coordinates to 0-1 range
local function NormalizeCoords(mapId, zoneId, x, y)
    local zone = CUSTOM_ZONES[mapId]
    if not zone then
        return nil, nil
    end
    
    -- For map 1 (Kalimdor), verify zone ID
    if mapId == 1 and zoneId ~= zone.zoneId then
        return nil, nil
    end
    
    local nx = (x - zone.minX) / (zone.maxX - zone.minX)
    local ny = (y - zone.minY) / (zone.maxY - zone.minY)
    
    -- Clamp to 0-1
    nx = math.max(0, math.min(1, nx))
    ny = math.max(0, math.min(1, ny))
    
    return nx, ny
end

-- Send GPS data to a player
local function SendGPS(player)
    if not player or not player:IsInWorld() then
        return
    end
    
    local mapId = player:GetMapId()
    local zoneId = player:GetZoneId()
    
    -- Check if player is in a custom zone
    if not CUSTOM_ZONES[mapId] then
        return
    end
    
    -- For map 1 (Kalimdor), verify it's actually Hyjal zone
    if mapId == 1 and zoneId ~= 616 then
        return
    end
    
    -- Get position
    local x, y, z = player:GetLocation()
    
    -- Normalize coordinates
    local nx, ny = NormalizeCoords(mapId, zoneId, x, y)
    if not nx or not ny then
        return
    end
    
    -- Build JSON string
    local json = string.format(
        '{"mapId":%d,"zoneId":%d,"x":%.3f,"y":%.3f,"z":%.3f,"nx":%.3f,"ny":%.3f}',
        mapId, zoneId, x, y, z, nx, ny
    )
    
    -- Send via AIO
    AIO.Handle(player, "DCMapGPS", "Update", json)
end

-- Broadcast GPS to all players in custom zones
local function BroadcastGPS()
    local players = GetPlayersInWorld()
    for _, player in ipairs(players) do
        SendGPS(player)
    end
end

-- Register timed event (every 2 seconds)
local GPS_UPDATE_INTERVAL = 2000 -- milliseconds
CreateLuaEvent(BroadcastGPS, GPS_UPDATE_INTERVAL, 0)

print("[DC-MapGPS] Eluna GPS broadcaster loaded - updating every 2 seconds")
