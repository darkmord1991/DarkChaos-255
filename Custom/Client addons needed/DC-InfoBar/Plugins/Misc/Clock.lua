--[[
    DC-InfoBar Clock Plugin
    Shows current time (server or local)
    
    Data Source: WoW API (GetGameTime, date)
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local ClockPlugin = {
    id = "DCInfoBar_Clock",
    name = "Clock",
    category = "misc",
    type = "text",
    side = "right",
    priority = 999,  -- Always rightmost
    icon = nil,  -- No icon for clock
    updateInterval = 1.0,
    
    leftClickHint = "Toggle 12h/24h format",
    rightClickHint = "Toggle server/local time",
}

function ClockPlugin:OnUpdate(elapsed)
    local use24Hour = DCInfoBar:GetPluginSetting(self.id, "use24Hour")
    local showSeconds = DCInfoBar:GetPluginSetting(self.id, "showSeconds")
    local useServerTime = DCInfoBar:GetPluginSetting(self.id, "useServerTime")
    local showDate = DCInfoBar:GetPluginSetting(self.id, "showDate")
    
    local hour, minute
    
    if useServerTime then
        hour, minute = GetGameTime()
    else
        hour = tonumber(date("%H"))
        minute = tonumber(date("%M"))
    end
    
    local second = tonumber(date("%S"))
    
    local timeStr
    if use24Hour ~= false then
        -- 24-hour format
        if showSeconds then
            timeStr = string.format("%02d:%02d:%02d", hour, minute, second)
        else
            timeStr = string.format("%02d:%02d", hour, minute)
        end
    else
        -- 12-hour format
        local ampm = hour >= 12 and "PM" or "AM"
        local hour12 = hour % 12
        if hour12 == 0 then hour12 = 12 end
        
        if showSeconds then
            timeStr = string.format("%d:%02d:%02d %s", hour12, minute, second, ampm)
        else
            timeStr = string.format("%d:%02d %s", hour12, minute, ampm)
        end
    end
    
    if showDate then
        local dateStr = date("%a %b %d")
        return "", dateStr .. " " .. timeStr
    end
    
    return "", timeStr
end

function ClockPlugin:OnTooltip(tooltip)
    tooltip:AddLine("Time", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)
    
    -- Server time
    local serverHour, serverMin = GetGameTime()
    tooltip:AddDoubleLine("Server Time:", 
        string.format("%02d:%02d", serverHour, serverMin),
        0.7, 0.7, 0.7, 1, 1, 1)
    
    -- Local time
    local localTime = date("%H:%M:%S")
    tooltip:AddDoubleLine("Local Time:", localTime, 0.7, 0.7, 0.7, 1, 1, 1)
    
    -- UTC time
    local utcTime = date("!%H:%M:%S")
    tooltip:AddDoubleLine("UTC:", utcTime, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
    
    -- Date
    tooltip:AddLine(" ")
    local dateStr = date("%A, %B %d, %Y")
    tooltip:AddDoubleLine("Date:", dateStr, 0.7, 0.7, 0.7, 1, 0.82, 0)
    
    -- Reset timers
    tooltip:AddLine(" ")
    tooltip:AddLine("|cff32c4ffReset Timers|r")
    
    -- Calculate time until daily reset (usually 3:00 AM server time)
    local resetHour = 3  -- Typical daily reset
    local hoursUntilReset = (resetHour - serverHour - 1) % 24
    local minsUntilReset = 60 - serverMin
    if minsUntilReset == 60 then
        minsUntilReset = 0
        hoursUntilReset = hoursUntilReset + 1
    end
    
    tooltip:AddDoubleLine("Daily Reset:", 
        string.format("%d hours, %d minutes", hoursUntilReset, minsUntilReset),
        0.7, 0.7, 0.7, 0.5, 1, 0.5)
    
    -- Weekly reset (Tuesday 3:00 AM typically)
    local weekday = tonumber(date("%w"))  -- 0 = Sunday
    local tuesday = 2
    local daysUntilTuesday = (tuesday - weekday) % 7
    if daysUntilTuesday == 0 and serverHour >= resetHour then
        daysUntilTuesday = 7
    end
    
    if daysUntilTuesday == 0 then
        tooltip:AddDoubleLine("Weekly Reset:", 
            string.format("%d hours", hoursUntilReset),
            0.7, 0.7, 0.7, 1, 0.82, 0)
    else
        tooltip:AddDoubleLine("Weekly Reset:", 
            string.format("%d days, %d hours", daysUntilTuesday, hoursUntilReset),
            0.7, 0.7, 0.7, 1, 0.82, 0)
    end
end

function ClockPlugin:OnClick(button)
    if button == "LeftButton" then
        -- Toggle 12h/24h format
        local current = DCInfoBar:GetPluginSetting(self.id, "use24Hour")
        DCInfoBar:SetPluginSetting(self.id, "use24Hour", not current)
        DCInfoBar:Print("Clock format: " .. (not current and "24-hour" or "12-hour"))
    elseif button == "RightButton" then
        -- Toggle server/local time
        local current = DCInfoBar:GetPluginSetting(self.id, "useServerTime")
        DCInfoBar:SetPluginSetting(self.id, "useServerTime", not current)
        DCInfoBar:Print("Clock: " .. (not current and "Server time" or "Local time"))
    end
end

function ClockPlugin:OnCreateOptions(parent, yOffset)
    local hourCB = DCInfoBar:CreateCheckbox(parent, "Use 24-hour format", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "use24Hour", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "use24Hour") ~= false)
    yOffset = yOffset - 30
    
    local secCB = DCInfoBar:CreateCheckbox(parent, "Show seconds", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showSeconds", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "showSeconds"))
    yOffset = yOffset - 30
    
    local serverCB = DCInfoBar:CreateCheckbox(parent, "Use server time", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "useServerTime", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "useServerTime"))
    yOffset = yOffset - 30
    
    local dateCB = DCInfoBar:CreateCheckbox(parent, "Show date", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showDate", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "showDate"))
    
    return yOffset - 30
end

-- Register plugin
DCInfoBar:RegisterPlugin(ClockPlugin)
