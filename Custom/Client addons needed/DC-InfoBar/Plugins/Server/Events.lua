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

local EVENT_TYPE_COLORS = {
    invasion = "ffff5050",
    rift = "ffa335ee",
    stampede = "ffffd100",
}

local DEFAULT_EVENT_COLOR = "ff9d9d9d"

local function Now()
    if GetTime then
        return GetTime()
    end
    return 0
end

local function IsStoppedState(state)
    return state == "victory" or state == "failed" or state == "stopped" or state == "cancelled" or state == "ended"
end

function EventsPlugin:OnActivate()
    DCInfoBar:Debug("Events plugin activated - waiting for server data")
    -- Ensure serverData.events exists
    DCInfoBar.serverData.events = DCInfoBar.serverData.events or {}
    
    -- Force an initial UI update in case events are already present
    -- IMPORTANT: do NOT call RefreshAllPlugins() here (it causes re-entrant activation recursion)
    if DCInfoBar.ForceUpdateAllPlugins then
        DCInfoBar:ForceUpdateAllPlugins()
    end

    -- Register handler for test data injection
    DCInfoBar._eventPluginActive = true
end

local function GetSetting(key, default)
    local value = DCInfoBar:GetPluginSetting(EventsPlugin.id, key)
    if value == nil then
        return default
    end
    return value
end

local function GetEventColor(event, flashCritical)
    if flashCritical and event.type == "invasion" then
        local wave = event.wave or 0
        local maxWave = event.maxWaves or 0
        if maxWave > 0 and wave >= maxWave then
            return "ffff3030"
        end
    end
    return EVENT_TYPE_COLORS[event.type or ""] or DEFAULT_EVENT_COLOR
end

local function BuildEventLine(event, showZone, showTimer)
    if not event then
        return ""
    end

    local state = event.state or event.status

    local text
    if event.type == "invasion" then
        if state == "warning" or (event.wave or 0) == 0 then
            text = "Incoming"
        elseif IsStoppedState(state) then
            if state == "victory" then
                text = "Stopped (Victory)"
            elseif state == "failed" then
                text = "Stopped (Failed)"
            else
                text = "Stopped"
            end
        else
            local wave = tonumber(event.wave) or 1
            local maxWaves = tonumber(event.maxWaves) or 4
            wave = math.max(1, math.min(maxWaves, wave))
            text = string.format("Wave %d/%d", wave, maxWaves)
            if event.enemiesRemaining then
                text = text .. string.format(" (%d)", event.enemiesRemaining)
            end
        end
    elseif event.type == "rift" then
        text = "Rift"
    elseif event.type == "stampede" then
        text = "Stampede"
    else
        text = event.name or "Event"
    end

    if showTimer then
        local remaining = tonumber(event.timeRemaining)
        if (not remaining or remaining <= 0) and event.hideAt then
            remaining = math.floor((tonumber(event.hideAt) or 0) - Now())
        end
        if remaining and remaining > 0 then
            text = text .. " " .. DCInfoBar:FormatTime(remaining)
        end
    end

    if showZone and event.zone then
        text = string.format("%s - %s", event.zone, text)
    end

    return text
end

function EventsPlugin:OnUpdate(elapsed)
    -- Ensure events table exists
    DCInfoBar.serverData.events = DCInfoBar.serverData.events or {}
    local events = DCInfoBar.serverData.events
    local hideWhenNone = GetSetting("hideWhenNone", true)
    local showZone = GetSetting("showZone", true)
    local showTimer = GetSetting("showTimer", true)
    local flashCritical = GetSetting("flashCritical", true)
    
    -- Debug: log if no events exist
    if #events == 0 then
        DCInfoBar:Debug("Events plugin: No events in serverData.events")
    else
        DCInfoBar:Debug("Events plugin: " .. #events .. " event(s) in serverData.events")
    end
    
    -- Prune expired stopped events
    do
        local t = Now()
        for i = #events, 1, -1 do
            local e = events[i]
            if e and e.hideAt and t >= (tonumber(e.hideAt) or 0) then
                table.remove(events, i)
            end
        end
    end

    -- Filter to active events (plus recently stopped events)
    local activeEvents = {}
    if events and type(events) == "table" then
        for _, event in ipairs(events) do
            if event then
                -- Normalize state field (could be "state" or "status")
                local state = event.state or event.status or "active"
                local isActive = event.active ~= false  -- Default to true if not explicitly false
                
                DCInfoBar:Debug(string.format("Event check: %s, active=%s, state=%s", 
                    event.name or "Unknown", tostring(event.active), tostring(state)))
                
                local isActiveState = (state == "active" or state == "warning" or state == "spawning" or state == "ongoing" or state == "progress" or state == nil)
                local isStoppedButVisible = (not isActive) and IsStoppedState(state) and event.hideAt and (Now() < (tonumber(event.hideAt) or 0))

                if (isActive and isActiveState) or isStoppedButVisible then
                    table.insert(activeEvents, event)
                    DCInfoBar:Debug("  -> Included in active events")
                else
                    DCInfoBar:Debug("  -> Filtered out (active=" .. tostring(isActive) .. ", state=" .. tostring(state) .. ")")
                end
            end
        end
    end
    
    DCInfoBar:Debug("Events plugin: " .. #activeEvents .. " active event(s)")
    
    if #activeEvents == 0 then
        if hideWhenNone and self.button then
            self.button:Hide()
        end
        if hideWhenNone then
            return "", ""
        end
        return "", "|cffbbbbbbNo active events|r"
    else
        if self.button and not self.button:IsShown() then
            DCInfoBar:Debug("Showing Events button")
            self.button:Show()
        end
    end
    
    -- Show first/most important event
    local event = activeEvents[1]
    local color = GetEventColor(event, flashCritical)
    local text = BuildEventLine(event, showZone, showTimer)
    
    return "", "|c" .. color .. text .. "|r"
end

function EventsPlugin:OnTooltip(tooltip)
    tooltip:AddLine("Zone Events", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)
    
    DCInfoBar.serverData.events = DCInfoBar.serverData.events or {}
    local events = DCInfoBar.serverData.events
    local showZone = GetSetting("showZone", true)
    local showTimer = GetSetting("showTimer", true)
    local maxEntries = tonumber(GetSetting("maxTooltipEntries", 4)) or 4
    maxEntries = math.max(1, math.min(10, maxEntries))
    
    -- Filter to active events (plus recently stopped events)
    local activeEvents = {}
    for _, event in ipairs(events) do
        local state = (event and (event.state or event.status)) or nil
        local isActive = event and (event.active ~= false)
        local isActiveState = (state == "active" or state == "warning" or state == "spawning" or not state)
        local isStoppedButVisible = (event and (not isActive) and IsStoppedState(state) and event.hideAt and (Now() < (tonumber(event.hideAt) or 0)))
        if (isActive and isActiveState) or isStoppedButVisible then
            table.insert(activeEvents, event)
        end
    end
    
    if #activeEvents == 0 then
        tooltip:AddLine("No active events", 0.7, 0.7, 0.7)
        return
    end
    
    for index, event in ipairs(activeEvents) do
        if index > maxEntries then
            break
        end
        tooltip:AddLine(" ")
        local nameColor = GetEventColor(event, GetSetting("flashCritical", true))
        tooltip:AddLine("|cff" .. nameColor .. (event.name or "Event") .. "|r")
        
        if showZone and event.zone then
            tooltip:AddDoubleLine("  Location:", event.zone, 0.7, 0.7, 0.7, 1, 1, 1)
        end
        
        if event.type == "invasion" then
            local state = event.state or event.status
            if state == "warning" or (tonumber(event.wave) or 0) == 0 then
                tooltip:AddDoubleLine("  Status:", "Incoming", 0.7, 0.7, 0.7, 1, 1, 1)
            elseif IsStoppedState(state) then
                tooltip:AddDoubleLine("  Status:", "Stopped", 0.7, 0.7, 0.7, 1, 1, 1)
            else
                tooltip:AddDoubleLine("  Wave:", (tonumber(event.wave) or 1) .. " of " .. (tonumber(event.maxWaves) or 4),
                    0.7, 0.7, 0.7, 1, 1, 1)
            end
            if event.enemiesRemaining then
                tooltip:AddDoubleLine("  Enemies:", event.enemiesRemaining,
                    0.7, 0.7, 0.7, 1, 1, 1)
            end
        end
        
        if showTimer and event.timeRemaining and event.timeRemaining > 0 then
            tooltip:AddDoubleLine("  Time:", DCInfoBar:FormatTime(event.timeRemaining),
                0.7, 0.7, 0.7, 1, 0.82, 0)
        end
    end

    if #activeEvents > maxEntries then
        tooltip:AddLine(" ")
        tooltip:AddLine(string.format("+ %d more events", #activeEvents - maxEntries), 0.6, 0.6, 0.6)
    end
end

function EventsPlugin:OnClick(button)
    DCInfoBar.serverData.events = DCInfoBar.serverData.events or {}
    local events = DCInfoBar.serverData.events
    
    -- Filter to active events (ignore stopped)
    local activeEvents = {}
    for _, event in ipairs(events) do
        if event.active ~= false and (event.state == "active" or event.state == "warning" or event.state == "spawning" or not event.state) then
            table.insert(activeEvents, event)
        end
    end
    
    if button == "LeftButton" then
        -- Quick join event group
        if #activeEvents > 0 then
            DCInfoBar:Print("Joining event: " .. activeEvents[1].name)
            -- Would send join request to server
        end
    elseif button == "RightButton" then
        -- Show event details
        if #activeEvents > 0 then
            for _, event in ipairs(activeEvents) do
                DCInfoBar:Print(event.name .. " - " .. (event.zone or "Unknown location"))
            end
        end
    end
end

function EventsPlugin:OnCreateOptions(parent, yOffset)
    local hideCB = DCInfoBar:CreateCheckbox(parent, "Hide when no events active", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "hideWhenNone", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "hideWhenNone") ~= false)
    yOffset = yOffset - 30

    local showZoneCB = DCInfoBar:CreateCheckbox(parent, "Show zone name in bar", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showZone", checked)
    end, GetSetting("showZone", true))
    yOffset = yOffset - 30

    local showTimerCB = DCInfoBar:CreateCheckbox(parent, "Show timers/countdowns", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showTimer", checked)
    end, GetSetting("showTimer", true))
    yOffset = yOffset - 30

    local flashCB = DCInfoBar:CreateCheckbox(parent, "Highlight critical invasion waves", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "flashCritical", checked)
    end, GetSetting("flashCritical", true))
    yOffset = yOffset - 40

    local sliderLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sliderLabel:SetPoint("TOPLEFT", 20, yOffset)
    sliderLabel:SetText("Max tooltip events:")
    
    local slider = DCInfoBar:CreateSlider(parent, 200, yOffset - 10, 1, 6, GetSetting("maxTooltipEntries", 4), function(value)
        DCInfoBar:SetPluginSetting(self.id, "maxTooltipEntries", value)
    end)
    slider:SetPoint("LEFT", sliderLabel, "RIGHT", 20, 0)
    
    return yOffset - 40
end

-- Register plugin
DCInfoBar:RegisterPlugin(EventsPlugin)
