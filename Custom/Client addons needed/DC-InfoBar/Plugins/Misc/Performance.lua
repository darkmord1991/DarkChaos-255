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
    _latencyHome = 0,
    _latencyWorld = 0,
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
    -- Get FPS
    self._fps = math.floor(GetFramerate() or 0)
    
    -- Get latency (returns bandwidthIn, bandwidthOut, latencyHome, latencyWorld)
    local _, _, latencyHome, latencyWorld = GetNetStats()
    self._latencyHome = latencyHome or 0
    self._latencyWorld = latencyWorld or 0
    
    -- Get memory usage
    UpdateAddOnMemoryUsage()
    local totalMem = 0
    local numAddons = GetNumAddOns()
    for i = 1, numAddons do
        totalMem = totalMem + (GetAddOnMemoryUsage(i) or 0)
    end
    self._memory = totalMem / 1024  -- Convert to MB
    
    -- Build display string
    local showFPS = DCInfoBar:GetPluginSetting(self.id, "showFPS")
    local showLatency = DCInfoBar:GetPluginSetting(self.id, "showLatency")
    local showMemory = DCInfoBar:GetPluginSetting(self.id, "showMemory")
    
    local parts = {}
    
    if showFPS ~= false then
        local fpsColor = "green"
        if self._fps < 20 then
            fpsColor = "red"
        elseif self._fps < 40 then
            fpsColor = "yellow"
        end
        table.insert(parts, DCInfoBar:WrapColor(self._fps .. " fps", fpsColor))
    end
    
    if showLatency ~= false then
        local latency = math.max(self._latencyHome, self._latencyWorld)
        local latColor = "green"
        if latency > 300 then
            latColor = "red"
        elseif latency > 150 then
            latColor = "yellow"
        end
        table.insert(parts, DCInfoBar:WrapColor(latency .. "ms", latColor))
    end
    
    if showMemory then
        table.insert(parts, string.format("%.0fMB", self._memory))
    end
    
    return "", table.concat(parts, " ")
end

function PerformancePlugin:OnTooltip(tooltip)
    tooltip:AddLine("Performance", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)
    
    -- FPS
    local fpsR, fpsG, fpsB = 0.3, 1, 0.5
    if self._fps < 20 then
        fpsR, fpsG, fpsB = 1, 0.3, 0.3
    elseif self._fps < 40 then
        fpsR, fpsG, fpsB = 1, 0.82, 0
    end
    tooltip:AddDoubleLine("Framerate:", self._fps .. " fps", 0.7, 0.7, 0.7, fpsR, fpsG, fpsB)
    
    -- Latency
    local latHome = self._latencyHome
    local latWorld = self._latencyWorld
    
    local homeR, homeG, homeB = 0.3, 1, 0.5
    if latHome > 300 then homeR, homeG, homeB = 1, 0.3, 0.3
    elseif latHome > 150 then homeR, homeG, homeB = 1, 0.82, 0 end
    
    local worldR, worldG, worldB = 0.3, 1, 0.5
    if latWorld > 300 then worldR, worldG, worldB = 1, 0.3, 0.3
    elseif latWorld > 150 then worldR, worldG, worldB = 1, 0.82, 0 end
    
    tooltip:AddDoubleLine("Latency (Home):", latHome .. " ms", 0.7, 0.7, 0.7, homeR, homeG, homeB)
    tooltip:AddDoubleLine("Latency (World):", latWorld .. " ms", 0.7, 0.7, 0.7, worldR, worldG, worldB)
    
    -- Memory
    tooltip:AddLine(" ")
    tooltip:AddLine("|cff32c4ffMemory Usage|r")
    tooltip:AddDoubleLine("Total:", string.format("%.1f MB", self._memory), 0.7, 0.7, 0.7, 1, 1, 1)
    
    -- Top addons by memory
    UpdateAddOnMemoryUsage()
    local addonMem = {}
    for i = 1, GetNumAddOns() do
        local name = GetAddOnInfo(i)
        local mem = GetAddOnMemoryUsage(i) or 0
        if mem > 100 then  -- Only show addons using >100KB
            table.insert(addonMem, { name = name, mem = mem })
        end
    end
    
    table.sort(addonMem, function(a, b) return a.mem > b.mem end)
    
    tooltip:AddLine(" ")
    tooltip:AddLine("Top Addons:")
    for i = 1, math.min(5, #addonMem) do
        local addon = addonMem[i]
        local memStr
        if addon.mem >= 1024 then
            memStr = string.format("%.1f MB", addon.mem / 1024)
        else
            memStr = string.format("%.0f KB", addon.mem)
        end
        tooltip:AddDoubleLine("  " .. addon.name, memStr, 0.5, 0.5, 0.5, 0.7, 0.7, 0.7)
    end

    local showServerInfo = DCInfoBar:GetPluginSetting(self.id, "showServerInfo")
    if showServerInfo ~= false then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff32c4ffServer|r")

        local info, infoTime = GetServerInfoSnapshot()
        local hasInfo = (type(info) == "table") and next(info) ~= nil
        if hasInfo then
            local uptime = info.uptime or info.uptimeSeconds or info.uptimeSec or info.uptimeMinutes
            if type(uptime) == "number" and info.uptimeMinutes and not info.uptimeSeconds and not info.uptimeSec then
                uptime = uptime * 60
            end
            local players = info.playersOnline or info.onlinePlayers or info.playerCount or info.players or info.online

            if uptime then
                tooltip:AddDoubleLine("Uptime:", FormatDuration(uptime), 0.7, 0.7, 0.7, 1, 1, 1)
            end
            if players then
                tooltip:AddDoubleLine("Players:", tostring(players), 0.7, 0.7, 0.7, 1, 1, 1)
            end
            if infoTime then
                local age = time() - infoTime
                tooltip:AddDoubleLine("Last update:", FormatDuration(age) .. " ago", 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
            end
        else
            tooltip:AddLine("Server info: loading...", 0.7, 0.7, 0.7)
            local DCWelcome = rawget(_G, "DCWelcome")
            if DCWelcome and DCWelcome.RequestServerInfo then
                local now = time()
                if (now - (self._lastServerInfoRequestAt or 0)) > 60 then
                    self._lastServerInfoRequestAt = now
                    DCWelcome:RequestServerInfo()
                end
            end
        end
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
