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
}

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
    
    return yOffset - 30
end

-- Register plugin
DCInfoBar:RegisterPlugin(PerformancePlugin)
