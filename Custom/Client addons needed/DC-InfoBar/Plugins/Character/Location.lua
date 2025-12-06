--[[
    DC-InfoBar Location Plugin
    Shows current zone, subzone, and coordinates
    
    Data Source: WoW API (GetZoneText, GetSubZoneText, GetPlayerMapPosition)
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

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
    
    _zone = "",
    _subzone = "",
    _x = 0,
    _y = 0,
}

function LocationPlugin:OnUpdate(elapsed)
    -- Get zone info
    self._zone = GetZoneText() or "Unknown"
    self._subzone = GetSubZoneText() or ""
    
    -- Get coordinates (3.3.5a method)
    SetMapToCurrentZone()
    local x, y = GetPlayerMapPosition("player")
    self._x = x or 0
    self._y = y or 0
    
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
    
    -- Add coordinates if enabled
    if showCoords and self._x > 0 and self._y > 0 then
        local coords = string.format("(%.0f, %.0f)", self._x * 100, self._y * 100)
        return "", displayZone .. " " .. coords
    else
        return "", displayZone
    end
end

function LocationPlugin:OnTooltip(tooltip)
    tooltip:AddLine("Location", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)
    
    tooltip:AddDoubleLine("Zone:", self._zone, 0.7, 0.7, 0.7, 1, 1, 1)
    
    if self._subzone and self._subzone ~= "" and self._subzone ~= self._zone then
        tooltip:AddDoubleLine("Subzone:", self._subzone, 0.7, 0.7, 0.7, 1, 1, 1)
    end
    
    if self._x > 0 and self._y > 0 then
        local coords = string.format("%.1f, %.1f", self._x * 100, self._y * 100)
        tooltip:AddDoubleLine("Coordinates:", coords, 0.7, 0.7, 0.7, 0.5, 1, 0.5)
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
    }
    
    if customZones[self._zone] or customZones[self._subzone] then
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("Zone Type:", "Custom World Content",
            0.7, 0.7, 0.7, 0.2, 0.8, 1)
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
        -- Open world map
        ToggleWorldMap()
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
