-- Minimal defensive HotspotDisplay replacement
-- Listens for HOTSPOT addon messages and system fallback HOTSPOT_ADDON|...

local ADDON_NAME = "HotspotDisplaySafe"
local ADDON_VERSION = "1.0"

local hotspots = {} -- [id] = {map, zone, x, y, expire, icon}

local function parsePayload(payload)
    -- payload expected like: HOTSPOT_ADDON|map:1|zone:141|x:123.45|y:67.89|z:..|id:3|dur:3600|icon:23768|nx:0.5|ny:0.5
    local data = {}
    if not payload then return data end
    -- if message starts with HOTSPOT_ADDON|, drop the prefix
    local s = tostring(payload)
    if s:sub(1,12) == "HOTSPOT_ADDON" then
        -- remove optional leading prefix
        local rest = s:sub(13)
        -- split by '|'
        for token in string.gmatch(rest, "[^|]+") do
            local k,v = string.match(token, "([^:]+):(.+)")
            if k and v then data[k]=v end
        end
    else
        -- maybe already compact payload without prefix
        for token in string.gmatch(s, "[^|]+") do
            local k,v = string.match(token, "([^:]+):(.+)")
            if k and v then data[k]=v end
        end
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
    hotspots[id] = {
        map = map, zone = zone, x = x, y = y,
        expire = time() + dur,
        icon = icon,
    }
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Hotspot #"..id.." registered at "..tostring(x)..","..tostring(y))
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
    for id,h in pairs(hotspots) do
        if h.expire and h.expire <= time() then hotspots[id]=nil else bestId=id; best=h; break end
    end
    if best then
        minimapPin:Show()
    else
        minimapPin:Hide()
    end
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

DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Loaded v"..ADDON_VERSION)
