-- HotspotDisplay (Wrath 3.3.5a polished)
-- Defensive, uses Astrolabe when available for accurate pin placement
-- Minimal dependencies, robust parsing of server HOTSPOT messages

local ADDON_NAME = "HotspotDisplayWrath"
local ADDON_VERSION = "1.0"

-- Saved variables
HotspotDisplayDB = HotspotDisplayDB or { enabled = true, showMapList = true, textSize = 16 }

local activeHotspots = {} -- [id] = {map, zone, x, y, expire, icon}
local worldPins = {} -- [id] = frame
local minimapPins = {} -- [id] = frame

-- Try to use Astrolabe library if present (common on Wrath clients)
local Astrolabe = nil
if IsAddOnLoaded and IsAddOnLoaded("Astrolabe") then
    Astrolabe = Astrolabe or _G.Astrolabe
end

local function DefensiveToNumber(s)
    if not s then return nil end
    local n = tonumber(s)
    return n
end

local function ParsePayload(msg)
    local data = {}
    if not msg or type(msg) ~= "string" then return data end
    -- If the message starts with prefix, strip it
    if msg:sub(1,12) == "HOTSPOT_ADDON" then
        msg = msg:sub(13)
    end
    for token in string.gmatch(msg, "[^|]+") do
        local k,v = string.match(token, "([^:]+):(.+)")
        if k and v then data[k] = v end
    end
    return data
end

local function CreateWorldPin(id, info)
    if worldPins[id] then return worldPins[id] end
    if not WorldMapFrame then return end
    local pin = CreateFrame("Button", "HotspotWorldPin"..id, WorldMapFrame)
    pin:SetSize(20,20)
    pin.texture = pin:CreateTexture(nil, "OVERLAY")
    pin.texture:SetAllPoints()
    pin.texture:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Hotspot #"..tostring(id))
        if info.zone then GameTooltip:AddLine("Zone: "..tostring(info.zone)) end
        if info.x and info.y then GameTooltip:AddLine(string.format("Coords: %.1f, %.1f", info.x, info.y)) end
        if info.expire then GameTooltip:AddLine("Expires in "..tostring(math.max(0, math.floor(info.expire - GetTime()))).."s") end
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pin:SetScript("OnClick", function()
        if not WorldMapFrame:IsShown() then ToggleWorldMap() end
    end)
    worldPins[id] = pin
    return pin
end

local function CreateMinimapPin(id, info)
    if minimapPins[id] then return minimapPins[id] end
    if not Minimap then return end
    local pin = CreateFrame("Frame", "HotspotMinimapPin"..id, Minimap)
    pin:SetSize(14,14)
    pin.texture = pin:CreateTexture(nil, "OVERLAY")
    pin.texture:SetAllPoints()
    pin.texture:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    pin:Hide()
    minimapPins[id] = pin
    return pin
end

local function PositionWorldPin(pin, info)
    if not pin or not info then return end
    if Astrolabe and info.nx and info.ny then
        local x = info.nx -- normalized
        local y = info.ny
        -- Astrolabe.WorldToMapPixels is used in other addons; we try to emulate a safe placement if available
        local success, px, py = pcall(function()
            return Astrolabe.WorldToMapPixels(WorldMapFrame, x, y)
        end)
        if success and px and py then
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", WorldMapFrame, "TOPLEFT", px, py)
            pin:Show()
            return
        end
    end
    -- fallback: crude normalization
    if info.x and info.y and WorldMapFrame then
        local nx = info.x
        local ny = info.y
        if nx > 1 then nx = nx / 100 end
        if ny > 1 then ny = ny / 100 end
        local w = WorldMapFrame:GetWidth()
        local h = WorldMapFrame:GetHeight()
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", WorldMapFrame, "TOPLEFT", nx * w, -ny * h)
        pin:Show()
    end
end

local function PositionMinimapPin(pin, info)
    if not pin or not info then return end
    -- Very simple: show if in same zone
    -- (We cannot compute accurate minimap offsets without Astrolabe here)
    pin:Show()
end

local function RegisterHotspotFromData(data)
    local id = DefensiveToNumber(data.id) or nil
    if not id then return end
    local dur = DefensiveToNumber(data.dur) or 0
    local map = DefensiveToNumber(data.map)
    local zone = data.zone
    local x = DefensiveToNumber(data.x) or 0
    local y = DefensiveToNumber(data.y) or 0
    local nx = DefensiveToNumber(data.nx)
    local ny = DefensiveToNumber(data.ny)
    local icon = DefensiveToNumber(data.icon)
    activeHotspots[id] = { map = map, zone = zone, x = x, y = y, nx = nx, ny = ny, expire = GetTime() + dur, icon = icon }
    -- Create/position pins
    local wpin = CreateWorldPin(id, activeHotspots[id])
    PositionWorldPin(wpin, activeHotspots[id])
    local mpin = CreateMinimapPin(id, activeHotspots[id])
    PositionMinimapPin(mpin, activeHotspots[id])
    -- Announce to chat
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[Hotspot]|r Hotspot #"..id.." registered")
end

-- Event frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, msg = ...
        if prefix == "HOTSPOT" and msg then
            local data = ParsePayload(msg)
            RegisterHotspotFromData(data)
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        local msg = ...
        if type(msg) == "string" and msg:sub(1,12) == "HOTSPOT_ADDON" then
            local data = ParsePayload(msg)
            RegisterHotspotFromData(data)
        end
    end
end)

-- Cleanup expired hotspots periodically
C_Timer.NewTicker(5, function()
    local now = GetTime()
    for id,info in pairs(activeHotspots) do
        if info.expire and info.expire <= now then
            activeHotspots[id] = nil
            if worldPins[id] then worldPins[id]:Hide() end
            if minimapPins[id] then minimapPins[id]:Hide() end
        else
            if worldPins[id] then PositionWorldPin(worldPins[id], info) end
            if minimapPins[id] then PositionMinimapPin(minimapPins[id], info) end
        end
    end
end)

DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[HotspotDisplayWrath]|r loaded v"..ADDON_VERSION)
