--[[
    DC-InfoBar Location Plugin
    Shows current zone, subzone, coordinates, and hotspot info

    Position sources, best first:
      1. DC-QOS map utils (WotLK-Extensions world position + WorldMapArea
         rectangles): zone coords and world XYZ, never touches the world map.
      2. WotLK-Extensions ResolveEntityPositionByGUID: world XYZ only.
      3. Stock GetPlayerMapPosition. SetMapToCurrentZone() is only called when
         the map state is known to be stale (zone change / world map closed),
         never every tick: it fires WORLD_MAP_UPDATE for every map addon.

    Hotspots: the store lives in Core (serverData.hotspots, fed by WRLD/SPOT).
    "In a hotspot" is read from the server-applied hotspot aura.
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local SPOT_CMSG_TELEPORT = 0x03

-- Hotspots.AuraSpell / Hotspots.BuffSpell default (HotspotMgr.cpp).
local HOTSPOT_AURA_SPELL_ID = 800001

local LocationPlugin = {
    id = "DCInfoBar_Location",
    name = "Location",
    category = "character",
    type = "combo",
    side = "left",
    priority = 60,
    icon = "Interface\\Icons\\INV_Misc_Map01",
    updateInterval = 1.0,

    leftClickHint = "Print position to chat",
    rightClickHint = "Open world map",
    middleClickHint = "Teleport to nearest hotspot (GM)",

    _zone = "",
    _subzone = "",
    _inHotspot = false,
    _blinkState = false,
    _mapDirty = true,
}

-- ============================================================================
-- Position
-- ============================================================================

local function GetQoSMapUtils()
    local qos = rawget(_G, "DCQOS")
    if qos and type(qos.GetMapUtils) == "function" then
        local ok, utils = pcall(qos.GetMapUtils, qos)
        if ok and type(utils) == "table" and type(utils.GetPlayerPosition) == "function" then
            return utils
        end
    end
    return nil
end

local function GetNativeWorldPosition()
    local resolver = rawget(_G, "ResolveEntityPositionByGUID") or rawget(_G, "C_Ping_ResolveEntityPositionByGUID")
    local guid = UnitGUID("player")
    if type(resolver) ~= "function" or not guid then
        return nil
    end
    -- guid, kind, gameMapId, mapX, mapY, worldX, worldY, worldZ
    local ok, _, _, gameMapId, _, _, worldX, worldY, worldZ = pcall(resolver, guid)
    if not ok or type(worldX) ~= "number" or type(worldY) ~= "number" then
        return nil
    end
    return worldX, worldY, tonumber(worldZ), tonumber(gameMapId)
end

function LocationPlugin:ReadStockMapPosition()
    local mapShown = WorldMapFrame and WorldMapFrame:IsShown()
    if self._mapDirty and not mapShown then
        SetMapToCurrentZone()
        self._mapDirty = false
    end
    local x, y = GetPlayerMapPosition("player")
    if (not x or x == 0) and (not y or y == 0) then
        -- Player isn't on the map currently selected: re-sync next time the map is closed.
        self._mapDirty = true
        return nil
    end
    return x, y
end

-- Returns normX, normY (0-1, may be nil), worldX, worldY, worldZ, gameMapId (nil without WXL)
function LocationPlugin:GetPosition()
    local utils = GetQoSMapUtils()
    if utils then
        local ok, nx, ny, _, wx, wy, gameMapId, wz = pcall(utils.GetPlayerPosition)
        if ok and (nx or wx) then
            return nx, ny, wx, wy, wz, gameMapId
        end
    end

    local wx, wy, wz, gameMapId = GetNativeWorldPosition()
    local nx, ny = self:ReadStockMapPosition()
    return nx, ny, wx, wy, wz, gameMapId
end

-- ============================================================================
-- Hotspots
-- ============================================================================

local function PlayerCanGainXP()
    if IsXPUserDisabled and IsXPUserDisabled() then
        return false
    end
    return (UnitXPMax("player") or 0) > 0
end

local function HasHotspotAura()
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if not name then
            return false
        end
        if spellId == HOTSPOT_AURA_SPELL_ID or string.find(name, "Hotspot", 1, true) then
            return true
        end
    end
    return false
end

-- Hotspots in the player's current zone (by name; zoneName comes from the
-- server's AreaTable, same DBC language as the client).
function LocationPlugin:GetZoneHotspots()
    local out = {}
    for _, hotspot in ipairs(DCInfoBar.serverData.hotspots) do
        if hotspot.zoneName == self._zone then
            table.insert(out, hotspot)
        end
    end
    return out
end

function LocationPlugin:GetNearestHotspot()
    local hotspots = DCInfoBar.serverData.hotspots
    if #hotspots == 0 then
        return nil
    end

    local _, _, wx, wy, _, gameMapId = self:GetPosition()
    local best, bestDist
    for _, hotspot in ipairs(hotspots) do
        if wx and gameMapId and hotspot.mapId == gameMapId then
            local dx, dy = hotspot.x - wx, hotspot.y - wy
            local dist = dx * dx + dy * dy
            if not bestDist or dist < bestDist then
                best, bestDist = hotspot, dist
            end
        end
    end
    return best or self:GetZoneHotspots()[1] or hotspots[1]
end

-- ============================================================================
-- Plugin
-- ============================================================================

function LocationPlugin:OnActivate()
    if self._eventFrame then
        return
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("ZONE_CHANGED")
    f:RegisterEvent("ZONE_CHANGED_INDOORS")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("UNIT_AURA")
    f:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_AURA" then
            if unit == "player" then
                LocationPlugin._auraDirty = true
            end
            return
        end
        LocationPlugin._mapDirty = true
        LocationPlugin._elapsed = 999
    end)
    self._eventFrame = f
    self._auraDirty = true

    -- Browsing another zone on the world map leaves the map state there.
    if WorldMapFrame and not self._mapHooked then
        self._mapHooked = true
        WorldMapFrame:HookScript("OnHide", function()
            LocationPlugin._mapDirty = true
        end)
    end
end

function LocationPlugin:OnDeactivate()
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
        self._eventFrame = nil
    end
end

function LocationPlugin:OnUpdate(elapsed)
    self._zone = GetZoneText() or ""
    self._subzone = GetSubZoneText() or ""

    if self._auraDirty then
        self._auraDirty = false
        self._inHotspot = PlayerCanGainXP() and HasHotspotAura()
    end

    local displayZone = self._zone
    if DCInfoBar:GetPluginSetting(self.id, "showSubzone") and self._subzone ~= "" and self._subzone ~= self._zone then
        displayZone = self._subzone
    end
    displayZone = DCInfoBar:TruncateText(displayZone, 18)

    local prefix = ""
    if self._inHotspot then
        self._blinkState = not self._blinkState
        prefix = self._blinkState and "|cffff8000!|r " or "|cffffff00!|r "
    end

    if DCInfoBar:GetPluginSetting(self.id, "showCoordinates") then
        local nx, ny = self:GetPosition()
        local coords = nx and string.format("%.1f, %.1f", nx * 100, ny * 100) or "--, --"
        return "", prefix .. displayZone .. " |cff00ff00" .. coords .. "|r"
    end
    return "", prefix .. displayZone
end

function LocationPlugin:OnTooltip(tooltip)
    tooltip:AddLine("Location", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)

    tooltip:AddDoubleLine("Zone:", self._zone, 0.7, 0.7, 0.7, 1, 1, 1)
    if self._subzone ~= "" and self._subzone ~= self._zone then
        tooltip:AddDoubleLine("Subzone:", self._subzone, 0.7, 0.7, 0.7, 1, 1, 1)
    end

    local nx, ny, wx, wy, wz, gameMapId = self:GetPosition()
    tooltip:AddDoubleLine("Coordinates:", nx and string.format("%.1f, %.1f", nx * 100, ny * 100) or "n/a",
        0.7, 0.7, 0.7, 0.5, 1, 0.5)
    if wx then
        tooltip:AddDoubleLine("World:", string.format("%.1f, %.1f, %.1f", wx, wy, wz or 0), 0.7, 0.7, 0.7, 1, 1, 0)
    end
    if gameMapId then
        tooltip:AddDoubleLine("Map ID:", gameMapId, 0.7, 0.7, 0.7, 1, 1, 1)
    end

    local inInstance, instanceType = IsInInstance()
    if inInstance then
        local typeNames = { party = "Dungeon", raid = "Raid", pvp = "Battleground", arena = "Arena" }
        tooltip:AddDoubleLine("Instance Type:", typeNames[instanceType] or instanceType, 0.7, 0.7, 0.7, 1, 0.82, 0)
    end

    if not PlayerCanGainXP() then
        return
    end

    if self._inHotspot then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cffff8000HOTSPOT ACTIVE|r")
    end

    local hotspots = DCInfoBar.serverData.hotspots
    if #hotspots > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff32c4ffActive Hotspots:|r")
        for _, hotspot in ipairs(hotspots) do
            local here = hotspot.zoneName == self._zone
            local bonusText = (hotspot.bonusPercent or 0) > 0 and (" +" .. hotspot.bonusPercent .. "% XP") or ""
            local timeText = (hotspot.timeRemaining or 0) > 0 and (" (" .. DCInfoBar:FormatTimeShort(hotspot.timeRemaining) .. ")") or ""
            tooltip:AddDoubleLine((here and "|cff00ff00>|r " or "  ") .. (hotspot.zoneName or "Unknown Zone"),
                bonusText .. timeText,
                here and 1 or 0.8, here and 0.5 or 0.8, here and 0 or 0.8,
                0.7, 0.7, 0.7)
        end
    elseif DCInfoBar.serverData._hotspotsLoaded then
        tooltip:AddLine(" ")
        tooltip:AddLine("No active hotspots", 0.5, 0.5, 0.5)
    end
end

function LocationPlugin:OnClick(button)
    if button == "LeftButton" then
        local nx, ny, wx, wy, wz, gameMapId = self:GetPosition()
        local parts = { self._subzone ~= "" and (self._zone .. " / " .. self._subzone) or self._zone }
        if nx then
            table.insert(parts, string.format("%.1f, %.1f", nx * 100, ny * 100))
        end
        if wx then
            table.insert(parts, string.format("world %.2f %.2f %.2f", wx, wy, wz or 0))
        end
        if gameMapId then
            table.insert(parts, "map " .. gameMapId)
        end
        DCInfoBar:Print(table.concat(parts, "  |  "))
    elseif button == "RightButton" then
        if WorldMapFrame then
            if WorldMapFrame:IsShown() then
                HideUIPanel(WorldMapFrame)
            else
                ShowUIPanel(WorldMapFrame)
            end
        end
    elseif button == "MiddleButton" then
        local hotspot = self:GetNearestHotspot()
        local proto = DCInfoBar:GetProtocol()
        if not hotspot then
            DCInfoBar:Print("No active hotspots to teleport to")
        elseif proto then
            -- Server-side GM-only; the result (SPOT 0x14) is printed by DC-Mapupgrades.
            proto:Request("SPOT", SPOT_CMSG_TELEPORT, { id = hotspot.id })
            DCInfoBar:Print("Requested teleport to hotspot in " .. (hotspot.zoneName or "Unknown Zone"))
        end
    end
end

function LocationPlugin:OnCreateOptions(parent, yOffset)
    DCInfoBar:CreateCheckbox(parent, "Show coordinates", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showCoordinates", checked)
        self._elapsed = 999
    end, DCInfoBar:GetPluginSetting(self.id, "showCoordinates"))
    yOffset = yOffset - 30

    DCInfoBar:CreateCheckbox(parent, "Show subzone instead of zone", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showSubzone", checked)
        self._elapsed = 999
    end, DCInfoBar:GetPluginSetting(self.id, "showSubzone"))

    return yOffset - 30
end

DCInfoBar:RegisterPlugin(LocationPlugin)
