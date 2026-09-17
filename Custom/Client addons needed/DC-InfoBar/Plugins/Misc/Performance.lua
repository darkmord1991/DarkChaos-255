--[[
    DC-InfoBar Performance Plugin
    Shows FPS, latency, and memory usage
    
    Data Source: WoW API (GetFramerate, GetNetStats, collectgarbage)
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local PerformancePlugin = {
    id = "DCInfoBar_Performance",
    name = "Performance",
    category = "misc",
    type = "text",
    side = "right",
    priority = 930,
    icon = "Interface\\Icons\\Spell_Nature_TimeStop",
    updateInterval = 1.0,
    
    leftClickHint = "Force garbage collection",
    rightClickHint = "Show memory breakdown",
    
    _fps = 0,
    _latency = 0,
    _memory = 0,
    _lastServerInfoRequestAt = 0,
}

local function FormatDuration(seconds)
    if type(seconds) == "string" then
        return seconds
    end
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then
        return "0s"
    end
    local days = math.floor(seconds / 86400)
    seconds = seconds - (days * 86400)
    local hours = math.floor(seconds / 3600)
    seconds = seconds - (hours * 3600)
    local minutes = math.floor(seconds / 60)
    seconds = seconds - (minutes * 60)

    local parts = {}
    if days > 0 then table.insert(parts, days .. "d") end
    if hours > 0 then table.insert(parts, hours .. "h") end
    if minutes > 0 then table.insert(parts, minutes .. "m") end
    if #parts == 0 and seconds > 0 then table.insert(parts, seconds .. "s") end
    return table.concat(parts, " ")
end

local function GetServerInfoSnapshot()
    local DCWelcome = rawget(_G, "DCWelcome")
    local info = nil
    if DCWelcome and DCWelcome.GetServerInfo then
        info = DCWelcome:GetServerInfo()
    end
    local infoTime = nil
    if DCWelcomeDB and DCWelcomeDB.cache and DCWelcomeDB.cache.serverInfoTime then
        infoTime = DCWelcomeDB.cache.serverInfoTime
    end
    return info, infoTime
end

function PerformancePlugin:OnUpdate(elapsed)
    self._fps = math.floor(GetFramerate() or 0)

    -- 3.3.5a returns bandwidthIn, bandwidthOut, latency (no home/world split).
    local _, _, latency = GetNetStats()
    self._latency = latency or 0

    -- Whole-UI Lua heap in KB: free to read, unlike UpdateAddOnMemoryUsage().
    self._memory = collectgarbage("count") / 1024

    local parts = {}

    if DCInfoBar:GetPluginSetting(self.id, "showFPS") ~= false then
        local fpsColor = (self._fps < 20 and "red") or (self._fps < 40 and "yellow") or "green"
        table.insert(parts, DCInfoBar:WrapColor(self._fps .. " fps", fpsColor))
    end

    if DCInfoBar:GetPluginSetting(self.id, "showLatency") ~= false then
        local latColor = (self._latency > 300 and "red") or (self._latency > 150 and "yellow") or "green"
        table.insert(parts, DCInfoBar:WrapColor(self._latency .. "ms", latColor))
    end

    if DCInfoBar:GetPluginSetting(self.id, "showMemory") then
        table.insert(parts, string.format("%.0fMB", self._memory))
    end

    return "", table.concat(parts, " ")
end

function PerformancePlugin:OnTooltip(tooltip)
    tooltip:AddLine("Performance", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)

    local fpsR, fpsG, fpsB = 0.3, 1, 0.5
    if self._fps < 20 then
        fpsR, fpsG, fpsB = 1, 0.3, 0.3
    elseif self._fps < 40 then
        fpsR, fpsG, fpsB = 1, 0.82, 0
    end
    tooltip:AddDoubleLine("Framerate:", self._fps .. " fps", 0.7, 0.7, 0.7, fpsR, fpsG, fpsB)

    local latR, latG, latB = 0.3, 1, 0.5
    if self._latency > 300 then
        latR, latG, latB = 1, 0.3, 0.3
    elseif self._latency > 150 then
        latR, latG, latB = 1, 0.82, 0
    end
    tooltip:AddDoubleLine("Latency:", self._latency .. " ms", 0.7, 0.7, 0.7, latR, latG, latB)

    -- Per-addon accounting is expensive, so it only runs while the tooltip is
    -- being built (once per hover), never from the bar update.
    UpdateAddOnMemoryUsage()
    local addonMem = {}
    local addonTotal = 0
    for i = 1, GetNumAddOns() do
        local name = GetAddOnInfo(i)
        local mem = GetAddOnMemoryUsage(i) or 0
        addonTotal = addonTotal + mem
        if mem > 100 then  -- Only list addons using >100KB
            table.insert(addonMem, { name = name, mem = mem })
        end
    end
    table.sort(addonMem, function(a, b) return a.mem > b.mem end)

    tooltip:AddLine(" ")
    tooltip:AddLine("|cff32c4ffMemory Usage|r")
    tooltip:AddDoubleLine("UI Lua heap:", string.format("%.1f MB", collectgarbage("count") / 1024), 0.7, 0.7, 0.7, 1, 1, 1)
    tooltip:AddDoubleLine("Addons:", string.format("%.1f MB", addonTotal / 1024), 0.7, 0.7, 0.7, 1, 1, 1)
    for i = 1, math.min(5, #addonMem) do
        local addon = addonMem[i]
        local memStr = addon.mem >= 1024 and string.format("%.1f MB", addon.mem / 1024) or string.format("%.0f KB", addon.mem)
        tooltip:AddDoubleLine("  " .. addon.name, memStr, 0.5, 0.5, 0.5, 0.7, 0.7, 0.7)
    end

    if DCInfoBar:GetPluginSetting(self.id, "showServerInfo") == false then
        return
    end

    tooltip:AddLine(" ")
    tooltip:AddLine("|cff32c4ffServer|r")

    local info, infoTime = GetServerInfoSnapshot()
    if type(info) == "table" and next(info) ~= nil then
        local serverName = info.serverName or info.name
        local seasonName = info.seasonName or (info.season and info.season.name)
        local uptime = info.uptime or info.uptimeSeconds or info.uptimeSec
        if not uptime and info.uptimeMinutes then
            uptime = info.uptimeMinutes * 60
        end
        local players = info.playersOnline or info.onlinePlayers or info.playerCount or info.players or info.online

        if serverName then
            tooltip:AddDoubleLine("Server:", tostring(serverName), 0.7, 0.7, 0.7, 1, 1, 1)
        end
        if seasonName then
            tooltip:AddDoubleLine("Season:", tostring(seasonName), 0.7, 0.7, 0.7, 1, 1, 1)
        end
        if info.maxLevel then
            tooltip:AddDoubleLine("Max level:", tostring(info.maxLevel), 0.7, 0.7, 0.7, 1, 1, 1)
        end
        if uptime then
            tooltip:AddDoubleLine("Uptime:", FormatDuration(uptime), 0.7, 0.7, 0.7, 1, 1, 1)
        end
        if players then
            tooltip:AddDoubleLine("Players:", tostring(players), 0.7, 0.7, 0.7, 1, 1, 1)
        end
        if infoTime then
            tooltip:AddDoubleLine("Last update:", FormatDuration(time() - infoTime) .. " ago", 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
        end
    else
        tooltip:AddLine("Server info: loading...", 0.7, 0.7, 0.7)
    end

    -- Refresh on hover when the cached info is older than 2 minutes.
    local welcome = rawget(_G, "DCWelcome")
    local now = time()
    if welcome and welcome.RequestServerInfo
        and (now - (tonumber(infoTime) or 0)) >= 120
        and (now - (self._lastServerInfoRequestAt or 0)) >= 60 then
        self._lastServerInfoRequestAt = now
        welcome:RequestServerInfo()
    end
end

function PerformancePlugin:OnClick(button)
    if button == "LeftButton" then
        -- Force garbage collection
        local before = collectgarbage("count")
        collectgarbage("collect")
        local after = collectgarbage("count")
        local freed = (before - after) / 1024
        DCInfoBar:Print(string.format("Garbage collection: freed %.2f MB", freed))
    elseif button == "RightButton" then
        -- Print top memory users
        UpdateAddOnMemoryUsage()
        DCInfoBar:Print("Memory usage by addon:")
        
        local addonMem = {}
        for i = 1, GetNumAddOns() do
            local name = GetAddOnInfo(i)
            local mem = GetAddOnMemoryUsage(i) or 0
            if mem > 500 then
                table.insert(addonMem, { name = name, mem = mem })
            end
        end
        
        table.sort(addonMem, function(a, b) return a.mem > b.mem end)
        
        for i = 1, math.min(10, #addonMem) do
            local addon = addonMem[i]
            DCInfoBar:Print(string.format("  %s: %.1f MB", addon.name, addon.mem / 1024))
        end
    end
end

function PerformancePlugin:OnCreateOptions(parent, yOffset)
    local fpsCB = DCInfoBar:CreateCheckbox(parent, "Show FPS", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showFPS", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "showFPS") ~= false)
    yOffset = yOffset - 30
    
    local latCB = DCInfoBar:CreateCheckbox(parent, "Show Latency", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showLatency", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "showLatency") ~= false)
    yOffset = yOffset - 30
    
    local memCB = DCInfoBar:CreateCheckbox(parent, "Show Memory Usage", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showMemory", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "showMemory"))
    yOffset = yOffset - 30

    local serverCB = DCInfoBar:CreateCheckbox(parent, "Show Server Info", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showServerInfo", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "showServerInfo") ~= false)

    return yOffset - 30
end

-- Register plugin
DCInfoBar:RegisterPlugin(PerformancePlugin)
