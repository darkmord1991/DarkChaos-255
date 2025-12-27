--[[
    DC-InfoBar Location Plugin
    Shows current zone, subzone, coordinates, and hotspot info
    
    Data Source: WoW API (GetZoneText, GetSubZoneText, GetPlayerMapPosition)
                 DCAddonProtocol SPOT module for hotspots
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

-- Hotspot opcodes
local SPOT_CMSG_GET_LIST = 0x01
local SPOT_SMSG_HOTSPOT_LIST = 0x10
local SPOT_SMSG_HOTSPOT_INFO = 0x11
local SPOT_SMSG_HOTSPOT_SPAWN = 0x12
local SPOT_SMSG_HOTSPOT_EXPIRE = 0x13

local LocationPlugin = {
    id = "DCInfoBar_Location",
    name = "Location",
    category = "character",
    type = "combo",
    side = "left",
    priority = 60,
    icon = "Interface\\Icons\\INV_Misc_Map01",
    updateInterval = 1.0,
    
    leftClickHint = "Get server GPS coordinates",
    rightClickHint = "Open world map",
    middleClickHint = "Teleport to hotspot",
    
    _zone = "",
    _subzone = "",
    _x = 0,
    _y = 0,
    _mapId = 0,
    _zoneId = 0,
    _areaId = 0,
    
    -- Server coordinates (XYZ from .gps command)
    _serverX = 0,
    _serverY = 0,
    _serverZ = 0,
    _orientation = 0,
    _hasServerCoords = false,
    
    -- Hotspot tracking
    _hotspots = {},           -- All active hotspots
    _inHotspot = false,       -- Currently in a hotspot zone
    _currentHotspot = nil,    -- Current hotspot data if in one
    _currentHotspots = nil,   -- All hotspots matching current zone/area
    _hotspotBonus = 0,        -- Current bonus percentage
    _hotspotsLoaded = false,
    _blinkTimer = 0,
    _blinkState = false,
}

local function PlayerCanGainXP()
    if IsXPUserDisabled and IsXPUserDisabled() then
        return false
    end
    if not UnitXPMax then
        return true
    end
    local xpMax = UnitXPMax("player")
    return xpMax and xpMax > 0
end

-- Check if player is in a hotspot zone
local function IsInHotspotZone(hotspot, zone, subzone, mapId, areaId)
    if not hotspot then return false end
    
    -- Check zone name match
    if hotspot.zoneName then
        if zone == hotspot.zoneName or subzone == hotspot.zoneName then
            return true
        end
    end
    
    -- Check map ID match
    if hotspot.mapId and mapId == hotspot.mapId then
        return true
    end
    
    -- Check area ID match
    if hotspot.areaId and areaId == hotspot.areaId then
        return true
    end
    
    return false
end

function LocationPlugin:OnActivate()
    -- Initialize serverData.hotspots if not exists
    DCInfoBar.serverData = DCInfoBar.serverData or {}
    DCInfoBar.serverData.hotspots = DCInfoBar.serverData.hotspots or {}
    
    -- Monitor chat for .gps command output to get server coordinates
    local originalAddMessage = ChatFrame1.AddMessage
    ChatFrame1.AddMessage = function(self, msg, ...)
        if msg and type(msg) == "string" then
            -- Parse .gps output: "X: 5752.5776 Y: 1325.3961 Z: 24.627499 Orientation: 5.4110045"
            local x, y, z, o = string.match(msg, "X:%s*([%d%.%-]+)%s*Y:%s*([%d%.%-]+)%s*Z:%s*([%d%.%-]+)%s*Orientation:%s*([%d%.%-]+)")
            if x and y and z and o then
                LocationPlugin._serverX = tonumber(x) or 0
                LocationPlugin._serverY = tonumber(y) or 0
                LocationPlugin._serverZ = tonumber(z) or 0
                LocationPlugin._orientation = tonumber(o) or 0
                LocationPlugin._hasServerCoords = true
            end
            
            -- Also parse ZoneX/ZoneY from .gps output
            local zoneX, zoneY = string.match(msg, "ZoneX:%s*([%d%.%-]+)%s*ZoneY:%s*([%d%.%-]+)")
            if zoneX and zoneY then
                -- These match our calculated coordinates
                -- Just validate they're consistent
            end
        end
        return originalAddMessage(self, msg, ...)
    end
    
    -- Register handlers for hotspot data
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        -- SMSG_HOTSPOT_LIST (0x10) - List of active hotspots
        DC:RegisterHandler("SPOT", SPOT_SMSG_HOTSPOT_LIST, function(data)
            if data and data.hotspots then
                LocationPlugin._hotspots = data.hotspots
                LocationPlugin._hotspotsLoaded = true
                DCInfoBar.serverData.hotspots = data.hotspots
            elseif data and type(data) == "table" and #data > 0 then
                -- Data might be the array directly
                LocationPlugin._hotspots = data
                LocationPlugin._hotspotsLoaded = true
                DCInfoBar.serverData.hotspots = data
            end
        end)
        
        -- SMSG_HOTSPOT_INFO (0x11) - Single hotspot info
        DC:RegisterHandler("SPOT", SPOT_SMSG_HOTSPOT_INFO, function(data)
            if data then
                -- Update or add hotspot
                local found = false
                for i, hs in ipairs(LocationPlugin._hotspots) do
                    if hs.id == data.id then
                        LocationPlugin._hotspots[i] = data
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(LocationPlugin._hotspots, data)
                end
            end
        end)
        
        -- SMSG_HOTSPOT_SPAWN (0x12) - New hotspot spawned
        DC:RegisterHandler("SPOT", SPOT_SMSG_HOTSPOT_SPAWN, function(data)
            if data then
                table.insert(LocationPlugin._hotspots, data)
                -- Notify player
                DCInfoBar:Print("|cff00ff00New Hotspot:|r " .. (data.name or "Unknown") .. " in " .. (data.zoneName or "Unknown Zone"))
            end
        end)
        
        -- SMSG_HOTSPOT_EXPIRE (0x13) - Hotspot expired
        DC:RegisterHandler("SPOT", SPOT_SMSG_HOTSPOT_EXPIRE, function(data)
            if data and data.id then
                for i, hs in ipairs(LocationPlugin._hotspots) do
                    if hs.id == data.id then
                        table.remove(LocationPlugin._hotspots, i)
                        break
                    end
                end
            end
        end)
        
        -- Request initial hotspot list
        DC:Request("SPOT", SPOT_CMSG_GET_LIST, {})
        
        -- Also use helper if available
        if DC.Hotspot and DC.Hotspot.GetList then
            DC.Hotspot.GetList()
        end
    else
        -- Fallback: Try to request hotspots after a delay when DC loads
        local frame = CreateFrame("Frame")
        frame.elapsed = 0
        frame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= 2 then
                self:SetScript("OnUpdate", nil)
                local DC = rawget(_G, "DCAddonProtocol")
                if DC then
                    DC:Request("SPOT", 0x01, {})
                    if DC.Hotspot and DC.Hotspot.GetList then
                        DC.Hotspot.GetList()
                    end
                end
            end
        end)
    end
end

function LocationPlugin:OnUpdate(elapsed)
    -- Get zone info
    self._zone = GetZoneText() or "Unknown"
    self._subzone = GetSubZoneText() or ""
    
    -- Get coordinates (3.3.5a method)
    -- First set map to current zone for accurate coordinates
    SetMapToCurrentZone()
    local x, y = GetPlayerMapPosition("player")
    
    -- Fallback: if coordinates are 0,0, try world map coordinates
    if (not x or x == 0) and (not y or y == 0) then
        -- Try using WorldMapFrame if available
        if WorldMapFrame and WorldMapFrame:IsShown() then
            x, y = GetPlayerMapPosition("player")
        end
    end
    
    self._x = x or 0
    self._y = y or 0
    
    -- Get map and zone IDs
    self._mapId = GetCurrentMapContinent() or 0
    self._zoneId = GetCurrentMapZone() or 0
    self._areaId = GetCurrentMapAreaID and GetCurrentMapAreaID() or 0
    
    -- Get real instance map ID for custom zones
    local _, _, _, _, _, _, _, instanceMapId = GetInstanceInfo()
    if instanceMapId then
        self._instanceMapId = instanceMapId
    end
    
    -- Check if in a hotspot zone
    self._inHotspot = false
    self._currentHotspot = nil
    self._currentHotspots = nil
    self._hotspotBonus = 0

    if PlayerCanGainXP() then
        for _, hotspot in ipairs(self._hotspots) do
            if IsInHotspotZone(hotspot, self._zone, self._subzone, self._mapId, self._areaId) then
                self._inHotspot = true
                if not self._currentHotspots then
                    self._currentHotspots = {}
                end
                table.insert(self._currentHotspots, hotspot)

                -- Keep first match as the "current" hotspot for backward compatibility
                if not self._currentHotspot then
                    self._currentHotspot = hotspot
                end

                -- Track the highest bonus among matches (safe default)
                local bonus = hotspot.bonusPercent or hotspot.bonus or 0
                if bonus > self._hotspotBonus then
                    self._hotspotBonus = bonus
                end
            end
        end
    end
    
    -- Blink timer for hotspot indicator
    if self._inHotspot then
        self._blinkTimer = self._blinkTimer + elapsed
        if self._blinkTimer >= 0.7 then
            self._blinkTimer = 0
            self._blinkState = not self._blinkState
        end
    else
        self._blinkTimer = 0
        self._blinkState = false
    end
    
    -- Build display text
    local showCoords = DCInfoBar:GetPluginSetting(self.id, "showCoordinates")
    local showSubzone = DCInfoBar:GetPluginSetting(self.id, "showSubzone")
    
    local displayZone = self._zone
    
    -- Abbreviate long zone names
    if #displayZone > 15 then
        displayZone = string.sub(displayZone, 1, 12) .. "..."
    end
    
    -- Add subzone if enabled and different from zone
    if showSubzone and self._subzone ~= "" and self._subzone ~= self._zone then
        displayZone = self._subzone
        if #displayZone > 15 then
            displayZone = string.sub(displayZone, 1, 12) .. "..."
        end
    end
    
    -- Add hotspot indicator if in hotspot zone
    local prefix = ""
    if self._inHotspot then
        if self._blinkState then
            prefix = "|cffff8000!|r "  -- Orange indicator (ASCII)
        else
            prefix = "|cffffff00!|r "  -- Yellow indicator (ASCII)
        end
    end
    
    -- Add coordinates if enabled (show even if 0 for custom zones)
    if showCoords then
        local coords = string.format("%.1f, %.1f", self._x * 100, self._y * 100)
        return "", prefix .. displayZone .. " |cff00ff00" .. coords .. "|r"
    else
        return "", prefix .. displayZone
    end
end

function LocationPlugin:OnTooltip(tooltip)
    tooltip:AddLine("Location", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)
    
    tooltip:AddDoubleLine("Zone:", self._zone, 0.7, 0.7, 0.7, 1, 1, 1)
    
    if self._subzone and self._subzone ~= "" and self._subzone ~= self._zone then
        tooltip:AddDoubleLine("Subzone:", self._subzone, 0.7, 0.7, 0.7, 1, 1, 1)
    end
    
    -- Always show coordinates (even if 0,0 for custom zones)
    local coords = string.format("%.1f, %.1f", self._x * 100, self._y * 100)
    tooltip:AddDoubleLine("Coordinates:", coords, 0.7, 0.7, 0.7, 0.5, 1, 0.5)
    
    -- Show server XYZ coordinates if available (for debugging)
    if self._hasServerCoords then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff32c4ffServer Coordinates:|r")
        tooltip:AddDoubleLine("  X:", string.format("%.2f", self._serverX), 0.7, 0.7, 0.7, 1, 1, 0)
        tooltip:AddDoubleLine("  Y:", string.format("%.2f", self._serverY), 0.7, 0.7, 0.7, 1, 1, 0)
        tooltip:AddDoubleLine("  Z:", string.format("%.2f", self._serverZ), 0.7, 0.7, 0.7, 1, 1, 0)
        tooltip:AddDoubleLine("  Orientation:", string.format("%.2f", self._orientation), 0.7, 0.7, 0.7, 0.8, 0.8, 1)
        tooltip:AddLine("|cff888888(Use .gps to update)|r", 0.5, 0.5, 0.5)
    end
    

    if PlayerCanGainXP() then
        -- Current Hotspot section (if in one)
        if self._inHotspot and self._currentHotspot then
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffff8000HOTSPOT ACTIVE|r")

            local activeList = self._currentHotspots
            if not activeList or #activeList == 0 then
                activeList = { self._currentHotspot }
            end

            for index, hotspot in ipairs(activeList) do
                local name = hotspot.name or ("Hotspot " .. index)
                local bonus = hotspot.bonusPercent or hotspot.bonus or 0

                tooltip:AddDoubleLine("  Name:", name,
                    0.7, 0.7, 0.7, 1, 0.5, 0)

                if bonus > 0 then
                    tooltip:AddDoubleLine("  Bonus:", "+" .. bonus .. "% XP/Loot",
                        0.7, 0.7, 0.7, 0.3, 1, 0.3)
                end

                if hotspot.timeRemaining then
                    tooltip:AddDoubleLine("  Time Left:", DCInfoBar:FormatTimeShort(hotspot.timeRemaining),
                        0.7, 0.7, 0.7, 1, 0.82, 0)
                end

                if hotspot.mobsRemaining then
                    tooltip:AddDoubleLine("  Mobs Left:", hotspot.mobsRemaining,
                        0.7, 0.7, 0.7, 1, 0.82, 0)
                end

                if index < #activeList then
                    tooltip:AddLine(" ")
                end
            end
        end

        -- All Active Hotspots section
        if #self._hotspots > 0 then
            tooltip:AddLine(" ")
            tooltip:AddLine("|cff32c4ffActive Hotspots:|r")

            for _, hotspot in ipairs(self._hotspots) do
                local isInPlayerZone = IsInHotspotZone(hotspot, self._zone, self._subzone, self._mapId, self._areaId)
                local nameColor = isInPlayerZone and {1, 0.5, 0} or {0.8, 0.8, 0.8}
                local zoneColor = isInPlayerZone and {1, 0.82, 0} or {0.6, 0.6, 0.6}

                local displayName = hotspot.name or "Unknown Hotspot"
                local displayZone = hotspot.zoneName or "Unknown Zone"
                local bonusText = hotspot.bonusPercent and (" +" .. hotspot.bonusPercent .. "%") or ""

                -- Show indicator if this hotspot matches the player's current zone/area
                local indicator = isInPlayerZone and "|cff00ff00>|r " or "  "

                tooltip:AddDoubleLine(indicator .. displayName, displayZone .. bonusText,
                    nameColor[1], nameColor[2], nameColor[3],
                    zoneColor[1], zoneColor[2], zoneColor[3])

                -- Show time remaining if available
                if hotspot.timeRemaining and hotspot.timeRemaining > 0 then
                    tooltip:AddDoubleLine("    Time:", DCInfoBar:FormatTimeShort(hotspot.timeRemaining),
                        0.5, 0.5, 0.5, 0.7, 0.7, 0.7)
                end
            end
        elseif self._hotspotsLoaded then
            tooltip:AddLine(" ")
            tooltip:AddLine("|cff888888No active hotspots|r", 0.5, 0.5, 0.5)
        end
    end
    
    -- Zone/Map IDs section
    tooltip:AddLine(" ")
    tooltip:AddLine("|cff32c4ffMap Information:|r")
    
    -- Get real map ID from instance info
    local _, _, _, _, _, _, _, instanceMapId = GetInstanceInfo()
    if instanceMapId then
        tooltip:AddDoubleLine("  Map ID:", instanceMapId, 0.7, 0.7, 0.7, 1, 0.82, 0)
    end
    
    -- Continent/Zone IDs from map system
    if self._mapId and self._mapId > 0 then
        tooltip:AddDoubleLine("  Continent:", self._mapId, 0.7, 0.7, 0.7, 1, 1, 1)
    end
    if self._zoneId and self._zoneId > 0 then
        tooltip:AddDoubleLine("  Zone Index:", self._zoneId, 0.7, 0.7, 0.7, 1, 1, 1)
    end
    if self._areaId and self._areaId > 0 then
        tooltip:AddDoubleLine("  Area ID:", self._areaId, 0.7, 0.7, 0.7, 1, 1, 1)
    end
    
    -- Zone type (instance check)
    local inInstance, instanceType = IsInInstance()
    if inInstance then
        local typeNames = {
            party = "Dungeon",
            raid = "Raid",
            pvp = "Battleground",
            arena = "Arena",
        }
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("Instance Type:", typeNames[instanceType] or instanceType,
            0.7, 0.7, 0.7, 1, 0.82, 0)
    end
    
    -- Check for custom zones (like Giant Isles)
    local customZones = {
        ["Giant Isles"] = "Custom World Content",
        ["Warden's Landing"] = "Custom World Content",
        ["Isles of Giants"] = "Custom World Content",
    }
    
    if customZones[self._zone] or customZones[self._subzone] then
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("Zone Type:", "Custom World Content",
            0.7, 0.7, 0.7, 0.2, 0.8, 1)
    end
    
    -- Hint for hotspot teleport
    if PlayerCanGainXP() and #self._hotspots > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff888888Middle-Click: Teleport to nearest hotspot|r", 0.5, 0.5, 0.5)
    end
end

function LocationPlugin:OnClick(button)
    if button == "LeftButton" then
        -- Run .gps command to get server coordinates
        SendChatMessage(".gps", "GUILD")
        DCInfoBar:Print("Requesting GPS data from server...")
    elseif button == "RightButton" then
        -- Open world map (3.3.5a compatible)
        if WorldMapFrame then
            if WorldMapFrame:IsShown() then
                HideUIPanel(WorldMapFrame)
            else
                ShowUIPanel(WorldMapFrame)
            end
        end
    elseif button == "MiddleButton" then
        -- Teleport to first hotspot
        if PlayerCanGainXP() and #self._hotspots > 0 then
            local hotspot = self._hotspots[1]
            local DC = rawget(_G, "DCAddonProtocol")
            if DC and hotspot.id then
                DC:Request("SPOT", 0x03, { id = hotspot.id })  -- Teleport request
                DCInfoBar:Print("Teleporting to hotspot: " .. (hotspot.name or "Unknown"))
            elseif DC.Hotspot and DC.Hotspot.Teleport then
                DC.Hotspot.Teleport(hotspot.id)
                DCInfoBar:Print("Teleporting to hotspot: " .. (hotspot.name or "Unknown"))
            else
                DCInfoBar:Print("Hotspot teleport not available")
            end
        else
            DCInfoBar:Print("No active hotspots to teleport to")
        end
    end
end

function LocationPlugin:OnCreateOptions(parent, yOffset)
    local coordsCB = DCInfoBar:CreateCheckbox(parent, "Show coordinates", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showCoordinates", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "showCoordinates"))
    yOffset = yOffset - 30
    
    local subzoneCB = DCInfoBar:CreateCheckbox(parent, "Show subzone instead of zone", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showSubzone", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "showSubzone"))
    
    return yOffset - 30
end

-- Register plugin
DCInfoBar:RegisterPlugin(LocationPlugin)
