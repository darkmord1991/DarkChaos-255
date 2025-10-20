-- Minimal defensive HotspotDisplay replacement
-- Listens for HOTSPOT addon messages and system fallback HOTSPOT_ADDON|...

local ADDON_NAME = "HotspotDisplaySafe"
local ADDON_VERSION = "1.0"

local hotspots = {} -- [id] = {map, zone, x, y, expire, icon}
-- Saved settings (SavedVariables compatibility)
HotspotDisplaySafeDB = HotspotDisplaySafeDB or {
    userIcon = "Interface\\Icons\\INV_Misc_Map_01",
    userSize = 20,
    keepAcrossZones = false,
}

local db = HotspotDisplaySafeDB

local function parsePayload(payload)
    -- payload expected like: HOTSPOT_ADDON|map:1|zone:141|x:123.45|y:67.89|z:..|id:3|dur:3600|icon:23768|nx:0.5|ny:0.5
    local data = {}
    if not payload then return data end
    local s = tostring(payload)

    -- Normalize known prefixes
    if s:sub(1,12) == "HOTSPOT_ADDON" then
        s = s:sub(13)
    elseif s:sub(1,7) == "HOTSPOT" and s:sub(8,8) == "\t" then
        s = s:sub(9)
    end

    -- split by '|'
    for token in string.gmatch(s, "[^|]+") do
        local k,v = string.match(token, "([^:]+):(.+)")
        if k and v then data[k]=v end
    end

    return data
end

local function AddHotspotFromData(data)
    if not data or not data.id then return end
    local id = tonumber(data.id) or nil
    if not id then return end
    local dur = tonumber(data.dur) or 0
    local map = tonumber(data.map) or nil
    local zone = data.zone or nil
    local x = tonumber(data.x) or 0
    local y = tonumber(data.y) or 0
    local icon = tonumber(data.icon) or nil
    local nx = tonumber(data.nx) or nil
    local ny = tonumber(data.ny) or nil
    local tex = data.tex or nil
    local texid = tonumber(data.texid) or nil
    local now = time()
    local cappedDur = math.max(0, math.min(dur or 0, 60*24*7)) -- cap to a week to avoid absurd values
    hotspots[id] = {
        map = map, zone = zone, x = x, y = y,
        nx = nx, ny = ny,
        tex = tex, texid = texid,
        expire = now + cappedDur,
        icon = icon,
        bonus = tonumber(data.bonus) or nil,
    }
    local posStr = tostring(x)..","..tostring(y)
    if nx and ny then posStr = string.format("nx=%.3f,ny=%.3f", nx, ny) end
    if hotspots[id].bonus then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Hotspot #%d registered at %s - XP Bonus: +%d%%", id, posStr, hotspots[id].bonus))
    else
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Hotspot #%d registered at %s", id, posStr))
    end
    -- Update minimap immediately when a new hotspot arrives
    UpdateMinimap()
end

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("CHAT_MSG_SYSTEM")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, msg, channel, sender = ...
        if prefix == "HOTSPOT" and msg then
            -- msg likely 'HOTSPOT_ADDON|...'
            local data = parsePayload(msg)
            AddHotspotFromData(data)
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        local msg = ...
        if type(msg) == "string" and msg:sub(1,12) == "HOTSPOT_ADDON" then
            local data = parsePayload(msg)
            AddHotspotFromData(data)
        end
    end
end)

-- Simple minimap dot implementation (non-Astrolabe): shows a single icon for latest hotspot near player
local minimapPin = nil
local function EnsureMinimapPin()
    if minimapPin then return end
    minimapPin = CreateFrame("Frame", "HotspotDisplaySafe_MinimapPin", Minimap)
    minimapPin:SetSize(16,16)
    minimapPin.texture = minimapPin:CreateTexture(nil, "OVERLAY")
    minimapPin.texture:SetAllPoints()
    minimapPin.texture:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    minimapPin:SetFrameStrata("MEDIUM")
    minimapPin:Hide()
end

local function UpdateMinimap()
    EnsureMinimapPin()
    -- choose nearest hotspot in same map (best-effort using zone id)
    local bestId, best = nil, nil
    local now = time()
    local playerMap = GetCurrentMapAreaID and GetCurrentMapAreaID() or nil
    -- prefer normalized coords if available (nx, ny)
    for id,h in pairs(hotspots) do
        if h.expire and h.expire <= now then
            hotspots[id]=nil
        else
            -- prefer a hotspot that has normalized coords
            if h.nx and h.ny then
                bestId = id; best = h; break
            end
            -- otherwise pick the first available as fallback
            if not best then
                bestId = id; best = h
            end
        end
    end

    if not best then
        minimapPin:Hide()
        return
    end

    -- If nx/ny present, position pin relative to minimap using Minimap:GetHitRect and SetPoint.
    if best.nx and best.ny then
        local nx = tonumber(best.nx)
        local ny = tonumber(best.ny)
        if nx and ny then
            minimapPin.texture:Show()
            -- convert normalized 0..1 to minimap offset (approx). Note: this is best-effort and
            -- will not be pixel-perfect across different map scales.
            local offsetX = (nx - 0.5) * (Minimap:GetWidth())
            local offsetY = (ny - 0.5) * (Minimap:GetHeight())
            minimapPin:ClearAllPoints()
            minimapPin:SetPoint("CENTER", Minimap, "CENTER", offsetX, offsetY)
            minimapPin:Show()
            return
        end
    end

    -- Fallback: just show a generic pin
    minimapPin.texture:Show()
    minimapPin:Show()
end

-- Periodic cleanup
C_Timer.NewTicker(5, function()
    local now = time()
    local removed = false
    for id,h in pairs(hotspots) do
        if h.expire and h.expire <= now then hotspots[id]=nil; removed = true end
    end
    if removed then UpdateMinimap() end
end)

DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Loaded v%s", ADDON_VERSION))
-- One-time server-visible debug message so operators can see the client addon is active
-- Note: this sends a normal SAY chat message which will be visible in server logs.
local function AnnounceAddonToServer()
    local msg = string.format("[HOTSPOT_CLIENT_LOADED] %s v%s", ADDON_NAME, ADDON_VERSION)
    -- Safe guard: pcall in case the API is unavailable in some clients
    pcall(function() SendChatMessage(msg, "SAY") end)
end

-- Announce once after a short delay to allow player login to complete
C_Timer.After(1.5, AnnounceAddonToServer)

-- Personal hotspot icon (toggle) placed at player's current location
local userMinimapPin = nil
local userWorldmapPin = nil

local function RemoveUserPins()
    if userMinimapPin then
        userMinimapPin:Hide()
        userMinimapPin:SetScript("OnUpdate", nil)
        userMinimapPin = nil
    end
    if userWorldmapPin then
        userWorldmapPin:Hide()
        userWorldmapPin:SetScript("OnUpdate", nil)
        userWorldmapPin = nil
    end
end

local function CreateUserMinimapPin(nx, ny, tex)
    EnsureMinimapPin()
    -- create or reuse a dedicated pin frame for the user
    if userMinimapPin then userMinimapPin:Hide(); userMinimapPin:SetScript("OnUpdate", nil) end
    userMinimapPin = CreateFrame("Frame", "HotspotDisplaySafe_UserMinimapPin", Minimap)
    userMinimapPin:SetSize(db.userSize or 20, db.userSize or 20)
    userMinimapPin.texture = userMinimapPin:CreateTexture(nil, "OVERLAY")
    userMinimapPin.texture:SetAllPoints()
    userMinimapPin.texture:SetTexture(tex or db.userIcon or "Interface\\Icons\\INV_Misc_Map_01")
    userMinimapPin:SetFrameStrata("HIGH")

    local function UpdatePin()
        if not nx or not ny then return end
        local offsetX = (nx - 0.5) * (Minimap:GetWidth())
        local offsetY = (ny - 0.5) * (Minimap:GetHeight())
        userMinimapPin:ClearAllPoints()
        userMinimapPin:SetPoint("CENTER", Minimap, "CENTER", offsetX, offsetY)
        userMinimapPin:Show()
    end

    userMinimapPin:SetScript("OnUpdate", UpdatePin)
    UpdatePin()
end

local function CreateUserWorldmapPin(nx, ny, tex)
    -- Only create if we can anchor to WorldMapFrame; otherwise create and wait for map to open
    if not WorldMapFrame then return end
    if userWorldmapPin then userWorldmapPin:Hide(); userWorldmapPin:SetScript("OnUpdate", nil) end
    userWorldmapPin = CreateFrame("Frame", "HotspotDisplaySafe_UserWorldmapPin", WorldMapFrame)
    userWorldmapPin:SetSize((db.userSize or 20) + 4, (db.userSize or 20) + 4)
    userWorldmapPin.texture = userWorldmapPin:CreateTexture(nil, "OVERLAY")
    userWorldmapPin.texture:SetAllPoints()
    userWorldmapPin.texture:SetTexture(tex or db.userIcon or "Interface\\Icons\\INV_Misc_Map_01")
    userWorldmapPin:SetFrameStrata("HIGH")

    local function UpdatePin()
        if not nx or not ny then return end
        local container = WorldMapFrame.ScrollContainer or WorldMapFrame
        local w = container:GetWidth()
        local h = container:GetHeight()
        local offsetX = (nx - 0.5) * w
        local offsetY = (ny - 0.5) * h
        userWorldmapPin:ClearAllPoints()
        userWorldmapPin:SetPoint("CENTER", container, "CENTER", offsetX, offsetY)
        userWorldmapPin:Show()
    end

    userWorldmapPin:SetScript("OnUpdate", UpdatePin)
    UpdatePin()

    -- ensure the pin updates when the world map is opened or changed
    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function() if userWorldmapPin then userWorldmapPin:SetScript("OnUpdate", UpdatePin) end end)
    end
end

-- Helper: try multiple APIs to get player's normalized position on current map
local function GetPlayerNormalizedPosition()
    -- Try C_Map API first
    local ok, mapID = pcall(function()
        if C_Map and C_Map.GetBestMapForUnit then return C_Map.GetBestMapForUnit("player") end
        return nil
    end)
    if not ok then mapID = nil end

    local nx, ny = nil, nil
    if mapID and C_Map and C_Map.GetPlayerMapPosition then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then nx, ny = pos.x, pos.y end
    end

    -- Fallback to legacy API
    if (not nx or not ny) and GetPlayerMapPosition then
        local x,y = GetPlayerMapPosition("player")
        if x and y and (x > 0 or y > 0) then nx, ny = x, y end
    end

    return nx, ny
end

-- Remove personal pins on zone change unless user asked to keep them
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("ZONE_CHANGED")
f:RegisterEvent("ZONE_CHANGED_INDOORS")

f:HookScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event:find("ZONE_CHANGED") then
        if not db.keepAcrossZones then
            RemoveUserPins()
        end
    end
end)

-- Slash command to toggle a personal hotspot icon at player's current location
SLASH_HOTSPOTICON1 = "/hotspoticon"
SLASH_HOTSPOTICON2 = "/hsicon"
SlashCmdList["HOTSPOTICON"] = function(msg)
    -- toggle: remove if exists
    if userMinimapPin or userWorldmapPin then
        RemoveUserPins()
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Personal hotspot icon removed.")
        return
    end

    -- Determine normalized position
    local nx, ny = GetPlayerNormalizedPosition()
    if not nx or not ny then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Could not determine your map position. Open your map or try again.")
        return
    end

    -- create minimap and worldmap pins
    CreateUserMinimapPin(nx, ny)
    CreateUserWorldmapPin(nx, ny)

    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Placed personal hotspot icon at (%.2f, %.2f) on your map.", nx, ny))
end

-- Slash command to configure user icon and size
SLASH_HOTSPOTICONSET1 = "/hotspoticonset"
SlashCmdList["HOTSPOTICONSET"] = function(msg)
    if not msg or msg == "" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Current icon=%s size=%d keepAcrossZones=%s", db.userIcon, db.userSize, tostring(db.keepAcrossZones)))
        DEFAULT_CHAT_FRAME:AddMessage("Usage: /hotspoticonset <texturePath|iconId> [size] [keep]")
        DEFAULT_CHAT_FRAME:AddMessage("Example: /hotspoticonset Interface\\Icons\\INV_Misc_Map_01 22 true")
        return
    end

    local parts = {}
    for token in string.gmatch(msg, "%S+") do table.insert(parts, token) end
    if #parts >= 1 then
        local icon = parts[1]
        -- allow numeric icon id to be formatted into a texture if desired; leave as-is otherwise
        db.userIcon = icon
    end
    if #parts >= 2 then
        local s = tonumber(parts[2])
        if s and s > 6 then db.userSize = s end
    end
    if #parts >= 3 then
        local keep = parts[3]
        for c in keep:gmatch(".") do keep = string.lower(keep) end
        db.keepAcrossZones = (keep == "true" or keep == "1" or keep == "yes")
    end

    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[HotspotDisplaySafe]|r Settings saved: icon=%s size=%d keepAcrossZones=%s", db.userIcon, db.userSize, tostring(db.keepAcrossZones)))
end

-- Automatically remove personal pin when a hotspot that matches location expires
local function CleanupExpiredHotspotPins()
    local now = time()
    local removed = false
    for id,h in pairs(hotspots) do
        if h.expire and h.expire <= now then
            hotspots[id] = nil
            removed = true
            -- if user pins were pointing to this hotspot coords, remove them
            -- compare by normalized coords if available
            local nx = tonumber(h.nx)
            local ny = tonumber(h.ny)
            if nx and ny and userMinimapPin then
                -- if distance small, remove
                local px, py = GetPlayerNormalizedPosition()
                if px and py then
                    local dx = px - nx
                    local dy = py - ny
                    if (dx*dx + dy*dy) < 0.0004 then -- ~0.02 distance
                        RemoveUserPins()
                    end
                end
            end
        end
    end
    if removed then UpdateMinimap() end
end

-- Run expiration cleanup frequently
C_Timer.NewTicker(5, CleanupExpiredHotspotPins)
