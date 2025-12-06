--[[
    DC-InfoBar Events Plugin
    Shows active zone events (invasions, rifts, etc.)
    
    Data Source: DCAddonProtocol (custom message)
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local EventsPlugin = {
    id = "DCInfoBar_Events",
    name = "Zone Events",
    category = "server",
    type = "combo",
    side = "left",
    priority = 50,
    icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
    updateInterval = 1.0,
    
    leftClickHint = "Quick-join event",
    rightClickHint = "Show event details",
}

function EventsPlugin:OnUpdate(elapsed)
    local events = DCInfoBar.serverData.events
    local hideWhenNone = DCInfoBar:GetPluginSetting(self.id, "hideWhenNone")
    
    if not events or #events == 0 then
        if hideWhenNone and self.button then
            self.button:Hide()
        end
        return "", ""
    else
        if self.button and not self.button:IsShown() then
            self.button:Show()
        end
    end
    
    -- Show first/most important event
    local event = events[1]
    
    if event.type == "invasion" then
        local text = "Invasion: Wave " .. (event.wave or 1) .. "/" .. (event.maxWaves or 4)
        return "", "|cffff5050" .. text .. "|r"
    elseif event.type == "rift" then
        local text = "Rift: " .. DCInfoBar:FormatTime(event.timeRemaining or 0)
        return "", "|cffa335ee" .. text .. "|r"
    elseif event.type == "stampede" then
        local text = "Stampede: " .. DCInfoBar:FormatTime(event.timeRemaining or 0)
        return "", "|cffffd100" .. text .. "|r"
    else
        return "", event.name or "Event"
    end
end

function EventsPlugin:OnTooltip(tooltip)
    tooltip:AddLine("Zone Events", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)
    
    local events = DCInfoBar.serverData.events
    
    if not events or #events == 0 then
        tooltip:AddLine("No active events", 0.7, 0.7, 0.7)
        return
    end
    
    for _, event in ipairs(events) do
        tooltip:AddLine(" ")
        
        -- Event name with color
        local nameColor = "ffffff"
        if event.type == "invasion" then nameColor = "ff5050"
        elseif event.type == "rift" then nameColor = "a335ee"
        elseif event.type == "stampede" then nameColor = "ffd100"
        end
        
        tooltip:AddLine("|cff" .. nameColor .. event.name .. "|r")
        
        if event.zone then
            tooltip:AddDoubleLine("  Location:", event.zone, 0.7, 0.7, 0.7, 1, 1, 1)
        end
        
        if event.type == "invasion" then
            tooltip:AddDoubleLine("  Wave:", event.wave .. " of " .. event.maxWaves,
                0.7, 0.7, 0.7, 1, 1, 1)
            if event.enemiesRemaining then
                tooltip:AddDoubleLine("  Enemies:", event.enemiesRemaining,
                    0.7, 0.7, 0.7, 1, 1, 1)
            end
        end
        
        if event.timeRemaining and event.timeRemaining > 0 then
            tooltip:AddDoubleLine("  Time:", DCInfoBar:FormatTime(event.timeRemaining),
                0.7, 0.7, 0.7, 1, 0.82, 0)
        end
    end
end

function EventsPlugin:OnClick(button)
    if button == "LeftButton" then
        -- Quick join event group
        local events = DCInfoBar.serverData.events
        if events and #events > 0 then
            DCInfoBar:Print("Joining event: " .. events[1].name)
            -- Would send join request to server
        end
    elseif button == "RightButton" then
        -- Show event details
        local events = DCInfoBar.serverData.events
        if events and #events > 0 then
            for _, event in ipairs(events) do
                DCInfoBar:Print(event.name .. " - " .. (event.zone or "Unknown location"))
            end
        end
    end
end

function EventsPlugin:OnCreateOptions(parent, yOffset)
    local hideCB = DCInfoBar:CreateCheckbox(parent, "Hide when no events active", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "hideWhenNone", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "hideWhenNone") ~= false)
    
    return yOffset - 30
end

-- Register plugin
DCInfoBar:RegisterPlugin(EventsPlugin)
