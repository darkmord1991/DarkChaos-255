--[[
    HotspotDisplay - Simple and Clean
    Shows "XP+" text on map when player is in a hotspot
    Author: DarkChaos Team
    Version: 1.0
]]--
local ADDON_NAME = "HotspotDisplay"
local ADDON_VERSION = "1.0"
-- Configuration (must match server settings)
local CONFIG = {
    HOTSPOT_BUFF_SPELL_ID = 23768,  -- Sayge's Dark Fortune of Strength
    HOTSPOT_BUFF_NAME = "Sayge's Dark Fortune of Strength",
    XP_BONUS_PERCENT = 100,  -- Default bonus percentage
    TEXT_COLOR = {1, 0.84, 0},  -- Gold color (RGB)
    PULSE_ENABLED = true,
    CHECK_INTERVAL = 1.0,  -- Check every 1 second
}
-- Saved variables (default settings)
HotspotDisplayDB = HotspotDisplayDB or {
    enabled = true,
    showText = true,
    showMinimap = true,
    textSize = 16,
    xpBonus = 100,
}
-- Local variables
local overlayFrame = nil
local overlayText = nil
local lastCheckTime = 0
local playerInHotspot = false
local pulseDirection = 1
local pulseAlpha = 1.0
local minimapPin = nil
-- Active hotspots table keyed by id
local activeHotspots = {} -- { [id] = {map,zone,x,y,z,expire,icon} }
local hotspotWorldPins = {} -- [id] = frame
local hotspotMinimapPins = {} -- [id] = frame
-- try to load mapping helper
local Astrolabe = nil
local success, ast = pcall(require, "Libs.HotspotDisplay_Astrolabe")
if success and ast then Astrolabe = ast end
-- If the environment doesn't support require(), check for the global the helper exposes
if not Astrolabe and _G and _G.HotspotDisplay_Astrolabe then Astrolabe = _G.HotspotDisplay_Astrolabe end
-- Helper: Print messages to chat
-- Helper: Print messages to chat (gated by debug flag)
HotspotDisplayDB = HotspotDisplayDB or {}
local function Print(msg)
    if not HotspotDisplayDB.debug then return end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, "|cFFFFD700[Hotspot Display]|r " .. tostring(msg))
    end
end
-- Helper: Check if player has hotspot buff
local function PlayerHasHotspotBuff()
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if spellId == CONFIG.HOTSPOT_BUFF_SPELL_ID then
            return true
        end
    end
    return false
end
-- Create overlay text on WorldMapFrame
local function CreateOverlay()
    if not WorldMapFrame then return end
    -- Create overlay frame if it doesn't exist
    if not overlayFrame then
        overlayFrame = CreateFrame("Frame", "HotspotDisplayOverlay", WorldMapFrame)
        overlayFrame:SetFrameStrata("TOOLTIP")
        overlayFrame:SetAllPoints(WorldMapFrame)
        overlayFrame:Hide()
    end
    -- Create text if it doesn't exist
    if not overlayText then
        overlayText = overlayFrame:CreateFontString(nil, "OVERLAY")
        overlayText:SetFont("Fonts\\FRIZQT__.TTF", HotspotDisplayDB.textSize, "OUTLINE")
        overlayText:SetTextColor(unpack(CONFIG.TEXT_COLOR))
    end
    -- hotspot list container
    if not overlayFrame.hotspotList then
        overlayFrame.hotspotList = CreateFrame("Frame", "HotspotDisplay_List", overlayFrame)
        overlayFrame.hotspotList:SetPoint("TOPLEFT", overlayFrame, "TOPLEFT", 10, -30)
        overlayFrame.hotspotList:SetSize(350, 300)
        overlayFrame.hotspotList.texts = {}
    end
end
-- Create a simple minimap pin (not a true world-accurate pin, but indicates presence)
local function CreateMinimapPin()
    -- Legacy single minimap pin kept for backwards compat; create a simple anchored indicator
    if minimapPin and minimapPin.texture then return minimapPin end
    if not Minimap then return nil end
    local mp = CreateFrame("Button", "HotspotDisplay_LegacyMinimapPin", Minimap)
    mp:SetSize(16,16)
    mp.texture = mp:CreateTexture(nil, "OVERLAY")
    mp.texture:SetAllPoints()
    mp.texture:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    mp:SetFrameStrata("MEDIUM")
    mp:Hide()
    mp:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Hotspot nearby")
        GameTooltip:Show()
    end)
    mp:SetScript("OnLeave", function() GameTooltip:Hide() end)
    mp:SetScript("OnClick", function()
        if not WorldMapFrame or not WorldMapFrame:IsShown() then ToggleWorldMap() end
    end)
    minimapPin = mp
    return minimapPin
end
-- Create a clickable worldmap pin for a hotspot
local function CreateWorldMapPin(id, h)
    if hotspotWorldPins[id] then return end
    if not WorldMapFrame then return end
    local pin = CreateFrame("Button", "HotspotDisplay_WorldPin_"..id, WorldMapFrame)
    pin:SetSize(24,24)
    pin.texture = pin:CreateTexture(nil, "OVERLAY")
    pin.texture:SetAllPoints()
    pin.texture:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    if h.icon and GetSpellTexture then
        local tex = GetSpellTexture(h.icon)
        if tex then pin.texture:SetTexture(tex) end
    end
    pin:SetFrameStrata("HIGH")
    pin:Show()
    pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local remaining = math.max(0, math.floor(h.expire - GetTime()))
        GameTooltip:SetText(string.format("Hotspot #%d - %s", id, tostring(h.zone or "?")))
        GameTooltip:AddLine(string.format("Coords: %.1f, %.1f", h.x, h.y))
        GameTooltip:AddLine(string.format("Expires in %ds", remaining))
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pin:SetScript("OnClick", function()
        -- Try to open and center the world map on this hotspot
        if not WorldMapFrame:IsShown() then ToggleWorldMap() end
        -- Try to set map by ID if function exists (older clients provide this)
        if type(SetMapByID) == "function" then
            pcall(SetMapByID, h.map or 0)
        end
        -- Provide a chat link / print coords for convenience
        local msg = string.format("Hotspot #%d: %.1f, %.1f (zone=%s)", id, h.x, h.y, tostring(h.zone or "?"))
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[Hotspot]|r "..msg)
    end)
    hotspotWorldPins[id] = pin
    -- initial positioning
    -- will be positioned by UpdateWorldMapPins when map is shown
    return pin
end
local function RemoveWorldMapPin(id)
    local p = hotspotWorldPins[id]
    if p then p:Hide(); p:SetParent(nil); p = nil; hotspotWorldPins[id] = nil end
end
-- Create per-hotspot minimap pin when player is in same zone
local function CreateHotspotMinimapPin(id, h)
    if hotspotMinimapPins[id] or not Minimap then return end
    local pin = CreateFrame("Button", "HotspotDisplay_MinimapPin_"..id, Minimap)
    pin:SetSize(18,18)
    pin.texture = pin:CreateTexture(nil, "OVERLAY")
    pin.texture:SetAllPoints()
    pin.texture:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    if h.icon and GetSpellTexture then
        local tex = GetSpellTexture(h.icon)
        if tex then pin.texture:SetTexture(tex) end
    end
    pin:SetFrameStrata("MEDIUM")
    pin:Show()
    pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local remaining = math.max(0, math.floor(h.expire - GetTime()))
        GameTooltip:SetText(string.format("Hotspot #%d - %s", id, tostring(h.zone or "?")))
        GameTooltip:AddLine(string.format("Coords: %.1f, %.1f", h.x, h.y))
        GameTooltip:AddLine(string.format("Expires in %ds", remaining))
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pin:SetScript("OnClick", function()
        local msg = string.format("Hotspot #%d: %.1f, %.1f (zone=%s)", id, h.x, h.y, tostring(h.zone or "?"))
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[Hotspot]|r "..msg)
        if not WorldMapFrame:IsShown() then ToggleWorldMap() end
        if type(SetMapByID) == "function" then pcall(SetMapByID, h.map or 0) end
    end)
    hotspotMinimapPins[id] = pin
    return pin
end
local function RemoveHotspotMinimapPin(id)
    local p = hotspotMinimapPins[id]
    if p then p:Hide(); p:SetParent(nil); p = nil; hotspotMinimapPins[id] = nil end
end
-- Position world map pins according to current map canvas size
local function UpdateWorldMapPins()
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
    local frameWidth = WorldMapFrame:GetWidth()
    local frameHeight = WorldMapFrame:GetHeight()
    for id,h in pairs(activeHotspots) do
        local pin = hotspotWorldPins[id]
        if pin then
            -- compute pixel offsets using Astrolabe when available
            if Astrolabe then
                -- Prefer server-provided normalized coords (nx,ny) for maximum accuracy
                if h.nx and h.ny then
                    -- Try Astrolabe and fall back to simple normalization if it errors or returns nil
                    local ok, px, py = pcall(function() return Astrolabe.WorldToMapPixels(WorldMapFrame, h.nx, h.ny) end)
                    px = tonumber(px); py = tonumber(py)
                    if ok and px and py then
                        pin:ClearAllPoints()
                        pin:SetPoint("CENTER", WorldMapFrame, "TOPLEFT", px, py)
                    else
                        local nx = tonumber(h.nx) or 0
                        local ny = tonumber(h.ny) or 0
                        local pixelX = nx * frameWidth
                        local pixelY = -ny * frameHeight
                        pin:ClearAllPoints()
                        pin:SetPoint("CENTER", WorldMapFrame, "TOPLEFT", pixelX, pixelY)
                    end
                else
                    local ok, px, py = pcall(function() return Astrolabe.WorldToMapPixels(WorldMapFrame, h.map or 0, tonumber(h.x) or 0, tonumber(h.y) or 0) end)
                    px = tonumber(px); py = tonumber(py)
                    if ok and px and py then
                        pin:ClearAllPoints()
                        pin:SetPoint("CENTER", WorldMapFrame, "TOPLEFT", px, py)
                    else
                        local nx = tonumber(h.x) or 0
                        local ny = tonumber(h.y) or 0
                        if nx > 1 then nx = nx / 100 end
                        if ny > 1 then ny = ny / 100 end
                        local pixelX = nx * frameWidth
                        local pixelY = -ny * frameHeight
                        pin:ClearAllPoints()
                        pin:SetPoint("CENTER", WorldMapFrame, "TOPLEFT", pixelX, pixelY)
                    end
                end
            else
                -- fallback: normalize coords roughly and position
                local nx = tonumber(h.x) or 0
                local ny = tonumber(h.y) or 0
                if nx > 1 then nx = nx / 100 end
                if ny > 1 then ny = ny / 100 end
                local pixelX = nx * frameWidth
                local pixelY = -ny * frameHeight
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", WorldMapFrame, "TOPLEFT", pixelX, pixelY)
            end
            pin:Show()
        end
    end
end
-- Update minimap pins: show pins for hotspots in the same zone as player's current map
local function UpdateMinimapPins()
    if not Minimap then return end
    local playerMap = GetCurrentMapAreaID and GetCurrentMapAreaID() or nil
    local px, py = GetPlayerMapPosition("player")
    for id,h in pairs(activeHotspots) do
        -- create or remove depending on zone
        if h.map and playerMap and tonumber(h.map) == tonumber(playerMap) then
            -- ensure pin exists
            local pin = hotspotMinimapPins[id] or CreateHotspotMinimapPin(id,h)
            if pin and px and py and (px ~= 0 or py ~= 0) then
                -- compute normalized coordinates
                local hx, hy
                if Astrolabe then
                        -- Prefer server-provided normalized coords when available, but guard Astrolabe calls
                        local hx, hy
                        if h.nx and h.ny then
                            hx, hy = tonumber(h.nx) or 0, tonumber(h.ny) or 0
                        else
                            local ok, nhx, nhy = pcall(function() return Astrolabe.WorldCoordsToNormalized(h.map or 0, tonumber(h.x) or 0, tonumber(h.y) or 0) end)
                            nhx = tonumber(nhx); nhy = tonumber(nhy)
                            if ok and nhx and nhy then
                                hx, hy = nhx, nhy
                            else
                                hx, hy = tonumber(h.x) or 0, tonumber(h.y) or 0
                            end
                        end
                        local ok, ox, oy = pcall(function() return Astrolabe.WorldToMinimapOffset(Minimap, px, py, hx, hy) end)
                        ox = tonumber(ox); oy = tonumber(oy)
                        if ok and ox and oy then
                            pin:ClearAllPoints()
                            pin:SetPoint("CENTER", Minimap, "CENTER", ox, oy)
                            pin:Show()
                        else
                            -- fallback: approximate offset relative to player/minimap center
                            local hx_n = tonumber(h.x) or 0
                            local hy_n = tonumber(h.y) or 0
                            if hx_n > 1 then hx_n = hx_n / 100 end
                            if hy_n > 1 then hy_n = hy_n / 100 end
                            local dx = (hx_n - px)
                            local dy = (hy_n - py)
                            local dist = math.sqrt(dx*dx + dy*dy)
                            local radius = (Minimap:GetWidth() / 2) - 6
                            local angle = math.atan2(dy, dx)
                            local r = math.min(radius, dist * radius * 1.6)
                            pin:ClearAllPoints()
                            pin:SetPoint("CENTER", Minimap, "CENTER", r * math.cos(angle), r * math.sin(angle))
                            pin:Show()
                        end
                else
                    -- fallback to previous approximate positioning
                    local hx_n = tonumber(h.x) or 0
                    local hy_n = tonumber(h.y) or 0
                    if hx_n > 1 then hx_n = hx_n / 100 end
                    if hy_n > 1 then hy_n = hy_n / 100 end
                    local dx = (hx_n - px)
                    local dy = (hy_n - py)
                    local dist = math.sqrt(dx*dx + dy*dy)
                    local radius = (Minimap:GetWidth() / 2) - 6
                    local angle = math.atan2(dy, dx)
                    local r = math.min(radius, dist * radius * 1.6)
                    pin:ClearAllPoints()
                    pin:SetPoint("CENTER", Minimap, "CENTER", r * math.cos(angle), r * math.sin(angle))
                    pin:Show()
                end
            end
        else
            -- not same zone: remove minimap pin if exists
            RemoveHotspotMinimapPin(id)
        end
    end
end
-- Update overlay position (center of player on map)
local function UpdateOverlayPosition()
    if not overlayFrame or not overlayText then return end
    if not HotspotDisplayDB.enabled or not HotspotDisplayDB.showText then
        overlayFrame:Hide()
        return
    end
    -- Only show if player is in hotspot
    if not playerInHotspot then
        overlayFrame:Hide()
        return
    end
    -- Get player position on map (0-1 coordinates)
    local x, y = GetPlayerMapPosition("player")
    if not x or not y or (x == 0 and y == 0) then
        overlayFrame:Hide()
        return
    end
    -- Convert to pixel coordinates
    local frameWidth = WorldMapFrame:GetWidth()
    local frameHeight = WorldMapFrame:GetHeight()
    local pixelX = x * frameWidth
    local pixelY = -y * frameHeight
    -- Position text
    overlayText:ClearAllPoints()
    overlayText:SetPoint("CENTER", WorldMapFrame, "TOPLEFT", pixelX, pixelY)
    -- Set text with XP bonus
    local bonusText = string.format("XP+%d%%", HotspotDisplayDB.xpBonus)
    overlayText:SetText("|cFFFFD700" .. bonusText .. "|r")
    -- Apply pulse effect
    if CONFIG.PULSE_ENABLED then
        overlayText:SetAlpha(pulseAlpha)
    else
        overlayText:SetAlpha(1.0)
    end
    overlayFrame:Show()
end
local function UpdateHotspotList()
    if not overlayFrame or not overlayFrame.hotspotList then return end
    local list = overlayFrame.hotspotList
    -- hide previous
    for i,t in ipairs(list.texts) do t:Hide() end
    local i = 0
    for id,h in pairs(activeHotspots) do
        i = i + 1
        local tf = list.texts[i]
        if not tf then
            tf = list:CreateFontString(nil, "OVERLAY")
            tf:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
            list.texts[i] = tf
        end
        tf:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -((i-1)*16))
        local remaining = math.max(0, math.floor(h.expire - GetTime()))
        tf:SetText(string.format("Hotspot #%d: zone %s (%.1f, %.1f) - %ds", id, tostring(h.zone or "?"), h.x, h.y, remaining))
        tf:Show()
    end
end
local function ShowMinimapIfNeeded()
    if not HotspotDisplayDB.showMinimap then
        if minimapPin then minimapPin:Hide() end
        return
    end
    if next(activeHotspots) == nil then
        if minimapPin then minimapPin:Hide() end
        return
    end
    CreateMinimapPin()
    -- choose latest hotspot icon
    local latest
    for id,h in pairs(activeHotspots) do
        if not latest or h.expire > latest.expire then latest = h end
    end
    if latest and minimapPin then
        if latest.icon and GetSpellTexture then
            local tex = GetSpellTexture(latest.icon)
            if tex then minimapPin.texture:SetTexture(tex) end
        end
        minimapPin:Show()
    end
end
-- Pulse animation
local function UpdatePulse(elapsed)
    if not CONFIG.PULSE_ENABLED or not playerInHotspot then return end
    pulseAlpha = pulseAlpha + (pulseDirection * elapsed * 0.5)
    if pulseAlpha >= 1.0 then
        pulseAlpha = 1.0
        pulseDirection = -1
    elseif pulseAlpha <= 0.6 then
        pulseAlpha = 0.6
        pulseDirection = 1
    end
end
-- Main update function
local function OnUpdate(self, elapsed)
    lastCheckTime = lastCheckTime + elapsed
    -- Check hotspot status periodically
    if lastCheckTime >= CONFIG.CHECK_INTERVAL then
        lastCheckTime = 0
        local wasInHotspot = playerInHotspot
        playerInHotspot = PlayerHasHotspotBuff()
        -- Notify player when entering/leaving hotspot
        if playerInHotspot and not wasInHotspot then
            Print("You are in an XP Hotspot! Check your map.")
            PlaySound("AuctionWindowOpen")
        elseif not playerInHotspot and wasInHotspot then
            if overlayFrame then
                overlayFrame:Hide()
            end
        end
    end
    -- Update pulse animation
    UpdatePulse(elapsed)
    -- Update overlay if map is open
    if WorldMapFrame:IsShown() then
        UpdateOverlayPosition()
        UpdateHotspotList()
        UpdateWorldMapPins()
    end
    -- minimap
    ShowMinimapIfNeeded()
    UpdateMinimapPins()
end
-- Event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        Print("Loaded v" .. ADDON_VERSION)
        Print("Type |cFFFFD700/hotspot|r for options")
        CreateOverlay()
        -- ensure any pre-existing hotspots get pins
        for id,h in pairs(activeHotspots) do
            CreateWorldMapPin(id,h)
            CreateHotspotMinimapPin(id,h)
        end
        UpdateWorldMapPins()
        UpdateMinimapPins()
    elseif event == "PLAYER_ENTERING_WORLD" then
        CreateOverlay()
        playerInHotspot = PlayerHasHotspotBuff()
    elseif event == "CHAT_MSG_SYSTEM" then
        local message = ...
        -- Parse world announcements about hotspots
        if string.match(message, "%[Hotspot%]") then
            if string.match(message, "appeared") then
                -- Parse XP bonus if mentioned
                local bonus = string.match(message, "%+(%d+)%%%% XP")
                if bonus then
                    HotspotDisplayDB.xpBonus = tonumber(bonus) or 100
                end
                Print("Hotspot spawned! Look for the buff icon.")
            elseif string.match(message, "expired") then
                playerInHotspot = false
                if overlayFrame then
                    overlayFrame:Hide()
                end
            end
        end
        -- Parse structured HOTSPOT_ADDON message the server may send (legacy system message fallback)
        if string.sub(message,1,12) == "HOTSPOT_ADDON" then
            -- split by '|'
            local parts = {}
            for token in string.gmatch(message, "[^|]+") do table.insert(parts, token) end
            local data = {}
            for i=2,#parts do
                local k,v = string.match(parts[i], "([^:]+):(.+)")
                if k and v then data[k]=v end
            end
            local id = tonumber(data.id)
            if id then
                local dur = tonumber(data.dur) or 0
                local nx = data.nx and tonumber(data.nx) or nil
                local ny = data.ny and tonumber(data.ny) or nil
                activeHotspots[id] = {
                    map = tonumber(data.map),
                    zone = data.zone,
                    x = tonumber(data.x) or 0,
                    y = tonumber(data.y) or 0,
                    z = tonumber(data.z) or 0,
                    nx = nx,
                    ny = ny,
                    expire = GetTime() + (dur or 0),
                    icon = tonumber(data.icon) or nil,
                }
                Print(string.format("Hotspot #%d in zone %s at %.1f, %.1f (dur %ds)", id, tostring(activeHotspots[id].zone or "?"), activeHotspots[id].x, activeHotspots[id].y, dur))
                CreateOverlay()
                CreateWorldMapPin(id, activeHotspots[id])
                CreateHotspotMinimapPin(id, activeHotspots[id])
                UpdateHotspotList()
                UpdateWorldMapPins()
                UpdateMinimapPins()
            end
        end
    elseif event == "CHAT_MSG_ADDON" then
        -- CHAT_MSG_ADDON: args are (prefix, message, channel, sender)
        local prefix, msg, channel, sender = ...
        -- We're interested in server-sent addon messages with prefix "HOTSPOT"
        if prefix == "HOTSPOT" and msg then
            -- msg is addon.str() built on server (starts with HOTSPOT_ADDON|...)
            local payload = msg
            -- Accept both formats: either "HOTSPOT_ADDON|..." or already compact payload
            if string.sub(payload,1,12) == "HOTSPOT_ADDON" then
                -- parse same as system fallback
                local parts = {}
                for token in string.gmatch(payload, "[^|]+") do table.insert(parts, token) end
                local data = {}
                for i=2,#parts do
                    local k,v = string.match(parts[i], "([^:]+):(.+)")
                    if k and v then data[k]=v end
                end
                local id = tonumber(data.id)
                if id then
                    local dur = tonumber(data.dur) or 0
                    local nx = data.nx and tonumber(data.nx) or nil
                    local ny = data.ny and tonumber(data.ny) or nil
                    activeHotspots[id] = {
                        map = tonumber(data.map),
                        zone = data.zone,
                        x = tonumber(data.x) or 0,
                        y = tonumber(data.y) or 0,
                        z = tonumber(data.z) or 0,
                        nx = nx,
                        ny = ny,
                        expire = GetTime() + (dur or 0),
                        icon = tonumber(data.icon) or nil,
                    }
                    Print(string.format("Hotspot #%d in zone %s at %.1f, %.1f (dur %ds)", id, tostring(activeHotspots[id].zone or "?"), activeHotspots[id].x, activeHotspots[id].y, dur))
                    CreateOverlay()
                    CreateWorldMapPin(id, activeHotspots[id])
                    CreateHotspotMinimapPin(id, activeHotspots[id])
                    UpdateHotspotList()
                    UpdateWorldMapPins()
                    UpdateMinimapPins()
                end
            end
        end
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            -- Recheck hotspot status when buffs change
            playerInHotspot = PlayerHasHotspotBuff()
        end
    end
end)
-- Hook WorldMapFrame resize/show to update pin positions
if WorldMapFrame then
    WorldMapFrame:HookScript("OnShow", function() UpdateWorldMapPins() end)
    WorldMapFrame:HookScript("OnSizeChanged", function() UpdateWorldMapPins() end)
end
-- Hook WorldMapFrame to update overlay
-- NOTE: OnUpdate handler is set below along with cleanup to avoid duplicate handlers
-- Slash command
SLASH_HOTSPOT1 = "/hotspot"
SLASH_HOTSPOT2 = "/hotspots"
SlashCmdList["HOTSPOT"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "" or msg == "help" then
        Print("Commands:")
        Print("  |cFFFFD700/hotspot toggle|r - Enable/disable addon")
        Print("  |cFFFFD700/hotspot text|r - Toggle map text display")
        Print("  |cFFFFD700/hotspot size <number>|r - Set text size (10-30)")
        Print("  |cFFFFD700/hotspot status|r - Show current status")
        Print("  |cFFFFD700/hotspot reset|r - Reset to defaults")
    elseif msg == "toggle" then
        HotspotDisplayDB.enabled = not HotspotDisplayDB.enabled
        Print("Addon " .. (HotspotDisplayDB.enabled and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
        UpdateOverlayPosition()
    elseif msg == "text" then
        HotspotDisplayDB.showText = not HotspotDisplayDB.showText
        Print("Map text " .. (HotspotDisplayDB.showText and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
        UpdateOverlayPosition()
    elseif string.match(msg, "^size%s+(%d+)") then
        local size = tonumber(string.match(msg, "^size%s+(%d+)"))
        if size and size >= 10 and size <= 30 then
            HotspotDisplayDB.textSize = size
            if overlayText then
                overlayText:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
            end
            Print("Text size set to " .. size)
            UpdateOverlayPosition()
        else
            Print("Invalid size. Use a number between 10 and 30.")
        end
    elseif msg == "status" then
        Print("Status:")
        Print("  Enabled: " .. (HotspotDisplayDB.enabled and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        Print("  Show Text: " .. (HotspotDisplayDB.showText and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        Print("  Text Size: " .. HotspotDisplayDB.textSize)
        Print("  XP Bonus: +" .. HotspotDisplayDB.xpBonus .. "%")
        Print("  In Hotspot: " .. (playerInHotspot and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    elseif msg == "reset" then
        HotspotDisplayDB = {
            enabled = true,
            showText = true,
            showMinimap = true,
            textSize = 16,
            xpBonus = 100,
        }
        if overlayText then
            overlayText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        end
        Print("Settings reset to defaults")
        UpdateOverlayPosition()
    else
        Print("Unknown command. Type |cFFFFD700/hotspot help|r for commands.")
    end
end
-- Initialize
Print("Initializing...")
-- Create a native Interface -> AddOns options panel
if type(InterfaceOptions_AddCategory) == 'function' then
    local panel = CreateFrame('Frame', 'HotspotDisplay_InterfaceOptions', UIParent)
    panel.name = 'Hotspot Display'
    panel:Hide()
    panel:SetScript('OnShow', function(self)
        -- nothing heavy here; we rely on saved vars
    end)
    local title = panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    title:SetPoint('TOPLEFT', 16, -16)
    title:SetText('Hotspot Display')
    -- checkbox helper
    local function makeCheck(name, text, setting, y)
        local cb = CreateFrame('CheckButton', name, panel, 'InterfaceOptionsCheckButtonTemplate')
        cb:SetPoint('TOPLEFT', 16, y)
        _G[name .. 'Text']:SetText(text)
        cb:SetChecked(HotspotDisplayDB[setting])
        cb:SetScript('OnClick', function(self) HotspotDisplayDB[setting] = self:GetChecked() end)
        return cb
    end
    local y = -48
    makeCheck('HotspotOpt_Enable', 'Enable Hotspot Display', 'enabled', y); y = y - 28
    makeCheck('HotspotOpt_ShowText', 'Show Map Text', 'showText', y); y = y - 28
    makeCheck('HotspotOpt_ShowMinimap', 'Show Minimap Pins', 'showMinimap', y); y = y - 28
    makeCheck('HotspotOpt_Debug', 'Enable Debug Chat Output', 'debug', y); y = y - 36
    -- text size slider
    local sizeSlider = CreateFrame('Slider', 'HotspotOpt_TextSize', panel, 'OptionsSliderTemplate')
    sizeSlider:SetPoint('TOPLEFT', 24, y)
    sizeSlider:SetWidth(200)
    sizeSlider:SetMinMaxValues(10, 30)
    sizeSlider:SetValueStep(1)
    sizeSlider:SetValue(HotspotDisplayDB.textSize or 16)
    sizeSlider.Text:SetText('Text Size')
    sizeSlider.Low:SetText('10')
    sizeSlider.High:SetText('30')
    sizeSlider:SetScript('OnValueChanged', function(self, val)
        HotspotDisplayDB.textSize = math.floor(val + 0.5)
        if overlayText then overlayText:SetFont('Fonts\\FRIZQT__.TTF', HotspotDisplayDB.textSize, 'OUTLINE') end
    end)
    -- Prefer the dedicated options container when present
    if type(InterfaceOptions_AddCategory) == 'function' and InterfaceOptionsFramePanelContainer then
        panel:SetParent(InterfaceOptionsFramePanelContainer)
        InterfaceOptions_AddCategory(panel)
    else
        InterfaceOptions_AddCategory(panel)
    end
end
-- Periodic cleanup and update
eventFrame:SetScript("OnUpdate", function(self, elapsed)
    OnUpdate(self, elapsed)
    local now = GetTime()
    local removed = false
    for id,h in pairs(activeHotspots) do
        if h.expire and h.expire <= now then
            -- remove associated pins
            RemoveWorldMapPin(id)
            RemoveHotspotMinimapPin(id)
            activeHotspots[id] = nil
            removed = true
        end
    end
    if removed then
        UpdateHotspotList()
        ShowMinimapIfNeeded()
        UpdateWorldMapPins()
        UpdateMinimapPins()
    end
end)

