--[[
    DC-InfoBar World Boss Plugin
    Shows world boss spawn timers and status
    
    Data Source: DCAddonProtocol (custom message)
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local WorldBossPlugin = {
    id = "DCInfoBar_WorldBoss",
    name = "World Boss",
    category = "server",
    type = "combo",
    side = "left",
    priority = 40,
    icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
    updateInterval = 1.0,  -- Update every second for countdown
    
    leftClickHint = "Open Group Finder",
    rightClickHint = "Show all boss timers",
    
    _currentBossIndex = 1,
    _cycleTimer = 0,
}

function WorldBossPlugin:OnUpdate(elapsed)
    local bosses = DCInfoBar.serverData.worldBosses
    
    if not bosses or #bosses == 0 then
        return "", "No Bosses"
    end
    
    -- Cycle through bosses every 5 seconds
    self._cycleTimer = (self._cycleTimer or 0) + elapsed
    if self._cycleTimer >= 5 then
        self._cycleTimer = 0
        self._currentBossIndex = (self._currentBossIndex % #bosses) + 1
    end
    
    local boss = bosses[self._currentBossIndex]
    if not boss then return "", "No Bosses" end
    
    local showOnlyActive = DCInfoBar:GetPluginSetting(self.id, "showOnlyActive")

    local now = GetTime and GetTime() or 0
    local isJustSpawned = boss.justSpawnedUntil and now < boss.justSpawnedUntil
    
    if boss.status == "active" then
        -- Boss is up!
        local hpText = boss.hp and (" " .. boss.hp .. "%") or ""
        if isJustSpawned then
            return "", "|cff50ff7a" .. boss.name .. ": Just spawned!" .. hpText .. "|r"
        end
        return "", "|cff50ff7a" .. boss.name .. ": Active!" .. hpText .. "|r"
    elseif boss.status == "spawning" and boss.spawnIn then
        if showOnlyActive then
            return "", "No Active Boss"
        end
        return "", boss.name .. ": " .. DCInfoBar:FormatTimeShort(boss.spawnIn)
    else
        return "", boss.name .. ": Unknown"
    end
end

function WorldBossPlugin:OnTooltip(tooltip)
    tooltip:AddLine("World Boss Timers", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)
    
    local bosses = DCInfoBar.serverData.worldBosses
    
    if not bosses or #bosses == 0 then
        tooltip:AddLine("No world boss data", 0.7, 0.7, 0.7)
        tooltip:AddLine(" ")
        tooltip:AddLine("World boss timers will appear", 0.5, 0.5, 0.5)
        tooltip:AddLine("when data is received from server.", 0.5, 0.5, 0.5)
        return
    end
    
    -- Group by zone
    local byZone = {}
    for _, boss in ipairs(bosses) do
        local zone = boss.zone or "Unknown"
        if not byZone[zone] then
            byZone[zone] = {}
        end
        table.insert(byZone[zone], boss)
    end
    
    for zone, zoneBosses in pairs(byZone) do
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff32c4ff" .. zone .. "|r")
        
        for _, boss in ipairs(zoneBosses) do
            local statusText
            local r, g, b = 1, 1, 1

            local now = GetTime and GetTime() or 0
            local isJustSpawned = boss.justSpawnedUntil and now < boss.justSpawnedUntil
            
            if boss.status == "active" then
                statusText = isJustSpawned and "Just spawned!" or "Active!"
                if boss.hp then
                    statusText = statusText .. " (" .. boss.hp .. "% HP)"
                end
                r, g, b = 0.3, 1, 0.5
            elseif boss.status == "spawning" and boss.spawnIn then
                statusText = "Spawns in " .. DCInfoBar:FormatTimeShort(boss.spawnIn)
                r, g, b = 1, 0.82, 0
            else
                statusText = "Unknown"
                r, g, b = 0.5, 0.5, 0.5
            end
            
            tooltip:AddDoubleLine("  • " .. boss.name, statusText,
                0.8, 0.8, 0.8, r, g, b)
        end
    end
end

function WorldBossPlugin:OnClick(button)
    if button == "LeftButton" then
        -- Open Group Finder to World Content tab
        if DCMythicPlusHUD and DCMythicPlusHUD.GroupFinder and DCMythicPlusHUD.GroupFinder.Toggle then
            DCMythicPlusHUD.GroupFinder:Toggle()
        elseif DCMythicPlusHUD and DCMythicPlusHUD.ShowGroupFinder then
            DCMythicPlusHUD:ShowGroupFinder("world")
        elseif DCGroupFinder and DCGroupFinder.Toggle then
            DCGroupFinder:Toggle()
        elseif LFDParentFrame then
            -- Fallback to default LFD frame
            ToggleLFDParentFrame()
        else
            DCInfoBar:Print("Group Finder not available")
        end
    elseif button == "RightButton" then
        -- Print all boss timers to chat
        local bosses = DCInfoBar.serverData.worldBosses
        if bosses and #bosses > 0 then
            DCInfoBar:Print("World Boss Timers:")
            for _, boss in ipairs(bosses) do
                local now = GetTime and GetTime() or 0
                local isJustSpawned = boss.justSpawnedUntil and now < boss.justSpawnedUntil
                local status
                if boss.status == "active" then
                    status = isJustSpawned and "JUST SPAWNED" or "ACTIVE"
                else
                    status = DCInfoBar:FormatTimeShort(boss.spawnIn or 0)
                end
                DCInfoBar:Print("  " .. boss.name .. ": " .. status)
            end
        else
            DCInfoBar:Print("No world boss data available")
        end
    end
end

function WorldBossPlugin:OnCreateOptions(parent, yOffset)
    local activeCB = DCInfoBar:CreateCheckbox(parent, "Only show when boss is active", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showOnlyActive", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "showOnlyActive"))
    
    return yOffset - 30
end

-- Register plugin
DCInfoBar:RegisterPlugin(WorldBossPlugin)
