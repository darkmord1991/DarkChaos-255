--[[
    DC-InfoBar Events Plugin
    Shows active zone events (invasions, rifts, etc.)

    Data Source: EVNT pushes and WRLD snapshot/updates (Core.lua UpsertEvent).
    Core keeps timeRemaining live and prunes ended events after their linger window.
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local EventsPlugin = {
    id = "DCInfoBar_Events",
    name = "Zone Events",
    category = "server",
    type = "combo",
    side = "right",
    priority = 890,
    icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
    updateInterval = 1.0,

    leftClickHint = "Open world map",
    rightClickHint = "Print event details",
}

-- 6-digit RGB, used as "|cff" .. color
local EVENT_TYPE_COLORS = {
    invasion = "ff5050",
    rift = "a335ee",
    stampede = "ffd100",
}
local DEFAULT_EVENT_COLOR = "9d9d9d"
local CRITICAL_COLOR = "ff3030"

local function GetSetting(key, default)
    local value = DCInfoBar:GetPluginSetting(EventsPlugin.id, key)
    if value == nil then
        return default
    end
    return value
end

local function IsStopped(event)
    return event.active == false or DCInfoBar.EVENT_STOPPED_STATES[event.state or ""]
end

local function GetEventColor(event, flashCritical)
    if flashCritical and event.type == "invasion" and not IsStopped(event) then
        local maxWave = tonumber(event.maxWaves) or 0
        if maxWave > 0 and (tonumber(event.wave) or 0) >= maxWave then
            return CRITICAL_COLOR
        end
    end
    return EVENT_TYPE_COLORS[event.type or ""] or DEFAULT_EVENT_COLOR
end

local function GetStatusText(event)
    if event.type == "invasion" then
        if IsStopped(event) then
            if event.state == "victory" then
                return "Stopped (Victory)"
            elseif event.state == "failed" then
                return "Stopped (Failed)"
            end
            return "Stopped"
        end
        if event.state == "warning" or (tonumber(event.wave) or 0) == 0 then
            return "Incoming"
        end
        local maxWaves = tonumber(event.maxWaves) or 4
        local wave = math.max(1, math.min(maxWaves, tonumber(event.wave) or 1))
        local text = string.format("Wave %d/%d", wave, maxWaves)
        if tonumber(event.enemiesRemaining) then
            text = text .. string.format(" (%d)", event.enemiesRemaining)
        end
        return text
    elseif event.type == "rift" then
        return IsStopped(event) and "Rift closed" or "Rift"
    elseif event.type == "stampede" then
        return IsStopped(event) and "Stampede over" or "Stampede"
    end
    return event.name or "Event"
end

local function GetRemaining(event)
    return tonumber(event.timeRemaining)
end

function EventsPlugin:OnUpdate(elapsed)
    local events = DCInfoBar:GetVisibleEvents(true)

    if #events == 0 then
        if GetSetting("hideWhenNone", true) then
            if self.button and self.button:IsShown() then
                self.button:Hide()
            end
            return "", ""
        end
        return "", "|cffbbbbbbNo active events|r"
    end

    if self.button and not self.button:IsShown() then
        self.button:Show()
    end

    local event = events[1]
    local text = GetStatusText(event)

    local remaining = GetRemaining(event)
    if GetSetting("showTimer", true) and remaining and remaining > 0 then
        text = text .. " " .. DCInfoBar:FormatTime(remaining)
    end
    if GetSetting("showZone", true) and event.zone then
        text = event.zone .. " - " .. text
    end
    if #events > 1 then
        text = text .. string.format(" (+%d)", #events - 1)
    end

    return "", "|cff" .. GetEventColor(event, GetSetting("flashCritical", true)) .. text .. "|r"
end

function EventsPlugin:OnTooltip(tooltip)
    tooltip:AddLine("Zone Events", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)

    local events = DCInfoBar:GetVisibleEvents(true)
    if #events == 0 then
        tooltip:AddLine("No active events", 0.7, 0.7, 0.7)
        return
    end

    local maxEntries = math.max(1, math.min(10, tonumber(GetSetting("maxTooltipEntries", 4)) or 4))
    local flashCritical = GetSetting("flashCritical", true)

    for index, event in ipairs(events) do
        if index > maxEntries then
            break
        end
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff" .. GetEventColor(event, flashCritical) .. (event.name or "Event") .. "|r")

        if event.zone then
            tooltip:AddDoubleLine("  Location:", event.zone, 0.7, 0.7, 0.7, 1, 1, 1)
        end
        tooltip:AddDoubleLine("  Status:", GetStatusText(event), 0.7, 0.7, 0.7, 1, 1, 1)

        -- Giant Isles invasion extras
        if tonumber(event.boatsTotal) and tonumber(event.boatsTotal) > 0 then
            tooltip:AddDoubleLine("  Boats scuttled:", (tonumber(event.boatsScuttled) or 0) .. " / " .. event.boatsTotal,
                0.7, 0.7, 0.7, 1, 1, 1)
        end
        -- ritualTime is only sent while channeling (a merged record keeps the old
        -- value afterwards), so gate on the ritual state.
        if event.ritual == "channeling" then
            local ritualTime = tonumber(event.ritualTime)
            tooltip:AddDoubleLine("  Loa ritual:", ritualTime and DCInfoBar:FormatTime(ritualTime) or "Channeling",
                0.7, 0.7, 0.7, 1, 0.5, 0.5)
        elseif event.ritual == "empowered" then
            tooltip:AddDoubleLine("  Loa ritual:", "Empowered", 0.7, 0.7, 0.7, 1, 0.3, 0.3)
        end

        local remaining = GetRemaining(event)
        if remaining and remaining > 0 then
            tooltip:AddDoubleLine(IsStopped(event) and "  Clears in:" or "  Time:", DCInfoBar:FormatTime(remaining),
                0.7, 0.7, 0.7, 1, 0.82, 0)
        end
    end

    if #events > maxEntries then
        tooltip:AddLine(" ")
        tooltip:AddLine(string.format("+ %d more events", #events - maxEntries), 0.6, 0.6, 0.6)
    end
end

function EventsPlugin:OnClick(button)
    local events = DCInfoBar:GetVisibleEvents(true)

    if button == "LeftButton" then
        if WorldMapFrame then
            if WorldMapFrame:IsShown() then
                HideUIPanel(WorldMapFrame)
            else
                ShowUIPanel(WorldMapFrame)
            end
        end
    elseif button == "RightButton" then
        if #events == 0 then
            DCInfoBar:Print("No active events")
            return
        end
        for _, event in ipairs(events) do
            DCInfoBar:Print(string.format("%s - %s: %s", event.name or "Event", event.zone or "Unknown location",
                GetStatusText(event)))
        end
    end
end

function EventsPlugin:OnCreateOptions(parent, yOffset)
    DCInfoBar:CreateCheckbox(parent, "Hide when no events active", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "hideWhenNone", checked)
        self._elapsed = 999
    end, GetSetting("hideWhenNone", true))
    yOffset = yOffset - 30

    DCInfoBar:CreateCheckbox(parent, "Show zone name in bar", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showZone", checked)
    end, GetSetting("showZone", true))
    yOffset = yOffset - 30

    DCInfoBar:CreateCheckbox(parent, "Show timers/countdowns", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showTimer", checked)
    end, GetSetting("showTimer", true))
    yOffset = yOffset - 30

    DCInfoBar:CreateCheckbox(parent, "Highlight critical invasion waves", 20, yOffset, function(checked)
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

DCInfoBar:RegisterPlugin(EventsPlugin)
