-- Minimal defensive HotspotDisplay replacement
-- Listens for HOTSPOT addon messages and system fallback HOTSPOT_ADDON|...

local ADDON_NAME = "HotspotDisplaySafe"
local ADDON_VERSION = "1.0"

local hotspots = {} -- [id] = {map, zone, x, y, expire, icon}

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
    }
    local posStr = tostring(x)..","..tostring(y)
    if nx and ny then posStr = string.format("nx=%.3f,ny=%.3f", nx, ny) end
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Hotspot #"..id.." registered at "..posStr)
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

DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplaySafe]|r Loaded v"..ADDON_VERSION)
-- One-time server-visible debug message so operators can see the client addon is active
-- Note: this sends a normal SAY chat message which will be visible in server logs.
local function AnnounceAddonToServer()
    local msg = string.format("[HOTSPOT_CLIENT_LOADED] %s v%s", ADDON_NAME, ADDON_VERSION)
    -- Safe guard: pcall in case the API is unavailable in some clients
    pcall(function() SendChatMessage(msg, "SAY") end)
end

-- Announce once after a short delay to allow player login to complete
C_Timer.After(1.5, AnnounceAddonToServer)
