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
    
    leftClickHint = "Copy coordinates",
    rightClickHint = "Open world map",
    middleClickHint = "Teleport to hotspot",
    
    _zone = "",
    _subzone = "",
    _x = 0,
    _y = 0,
    _mapId = 0,
    _zoneId = 0,
    _areaId = 0,
    
    -- Hotspot tracking
    _hotspots = {},           -- All active hotspots
    _inHotspot = false,       -- Currently in a hotspot zone
    _currentHotspot = nil,    -- Current hotspot data if in one
    _hotspotBonus = 0,        -- Current bonus percentage
    _hotspotsLoaded = false,
    _blinkTimer = 0,
    _blinkState = false,
}

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
    self._hotspotBonus = 0
    
    for _, hotspot in ipairs(self._hotspots) do
        if IsInHotspotZone(hotspot, self._zone, self._subzone, self._mapId, self._areaId) then
            self._inHotspot = true
            self._currentHotspot = hotspot
            self._hotspotBonus = hotspot.bonusPercent or hotspot.bonus or 0
            break
        end
    end
    
    -- Blink timer for hotspot indicator
    if self._inHotspot then
        self._blinkTimer = self._blinkTimer + elapsed
        if self._blinkTimer >= 0.7 then
            self._blinkTimer = 0
            self._blinkState = not self._blinkState
        end
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
            prefix = "|cffff8000★|r "  -- Orange star
        else
            prefix = "|cffffff00★|r "  -- Yellow star
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
    
    -- Current Hotspot section (if in one)
    if self._inHotspot and self._currentHotspot then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cffff8000★ HOTSPOT ACTIVE ★|r")
        
        if self._currentHotspot.name then
            tooltip:AddDoubleLine("  Name:", self._currentHotspot.name,
                0.7, 0.7, 0.7, 1, 0.5, 0)
        end
        
        if self._hotspotBonus > 0 then
            tooltip:AddDoubleLine("  Bonus:", "+" .. self._hotspotBonus .. "% XP/Loot",
                0.7, 0.7, 0.7, 0.3, 1, 0.3)
        end
        
        if self._currentHotspot.timeRemaining then
            tooltip:AddDoubleLine("  Time Left:", DCInfoBar:FormatTimeShort(self._currentHotspot.timeRemaining),
                0.7, 0.7, 0.7, 1, 0.82, 0)
        end
        
        if self._currentHotspot.mobsRemaining then
            tooltip:AddDoubleLine("  Mobs Left:", self._currentHotspot.mobsRemaining,
                0.7, 0.7, 0.7, 1, 0.82, 0)
        end
    end
    
    -- All Active Hotspots section
    if #self._hotspots > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff32c4ffActive Hotspots:|r")
        
        for _, hotspot in ipairs(self._hotspots) do
            local isCurrentZone = (hotspot == self._currentHotspot)
            local nameColor = isCurrentZone and {1, 0.5, 0} or {0.8, 0.8, 0.8}
            local zoneColor = isCurrentZone and {1, 0.82, 0} or {0.6, 0.6, 0.6}
            
            local displayName = hotspot.name or "Unknown Hotspot"
            local displayZone = hotspot.zoneName or "Unknown Zone"
            local bonusText = hotspot.bonusPercent and (" +" .. hotspot.bonusPercent .. "%") or ""
            
            -- Show indicator if this is current zone
            local indicator = isCurrentZone and "|cff00ff00►|r " or "  "
            
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
    if #self._hotspots > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff888888Middle-Click: Teleport to nearest hotspot|r", 0.5, 0.5, 0.5)
    end
end

function LocationPlugin:OnClick(button)
    if button == "LeftButton" then
        -- Copy coordinates to clipboard (via chat input)
        if self._x > 0 and self._y > 0 then
            local coords = string.format("%.1f, %.1f", self._x * 100, self._y * 100)
            local text = self._zone .. " " .. coords
            
            ChatFrame1EditBox:SetText(text)
            ChatFrame1EditBox:SetFocus()
            ChatFrame1EditBox:HighlightText()
            
            DCInfoBar:Print("Coordinates copied: " .. text)
        end
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
        if #self._hotspots > 0 then
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
