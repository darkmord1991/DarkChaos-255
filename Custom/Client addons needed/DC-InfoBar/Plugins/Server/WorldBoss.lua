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

local function _NormName(s)
    s = tostring(s or "")
    s = string.lower(s)
    s = string.gsub(s, "[^a-z0-9]+", "")
    return s
end

local DEFAULT_GIANT_ISLES_BOSSES = {
    { entry = 400100, spawnId = 9000190, name = "Oondasta, King of Dinosaurs", zone = "Devilsaur Gorge" },
    { entry = 400101, spawnId = 9000189, name = "Thok the Bloodthirsty",     zone = "Raptor Ridge" },
    { entry = 400102, spawnId = 9000191, name = "Nalak the Storm Lord",      zone = "Thundering Peaks" },
}

local function _GetUniqueBosses(rawBosses)
    local result = {}
    local seen = {}
    if type(rawBosses) ~= "table" then
        return result
    end

    -- First: copy and dedupe existing
    for _, b in ipairs(rawBosses) do
        if type(b) == "table" then
            local key = nil
            -- Prefer spawnId as the primary identity. These bosses are keyed by spawnId in DB.
            if b.spawnId then key = "s:" .. tostring(b.spawnId)
            elseif b.entry then key = "e:" .. tostring(b.entry)
            elseif b.name then key = "n:" .. _NormName(b.name)
            elseif b.guid then key = "g:" .. tostring(b.guid) end

            if key and not seen[key] then
                seen[key] = b
                table.insert(result, b)
            end
        end
    end

    -- Second: ensure the three defaults are present (fallback if core list is incomplete)
    local existingBySpawnId = {}
    for _, b in ipairs(result) do
        if b.spawnId then existingBySpawnId[tonumber(b.spawnId)] = true end
    end

    for _, def in ipairs(DEFAULT_GIANT_ISLES_BOSSES) do
        -- Ensure each configured spawnId exists in the list even if entry/name overlap.
        if not existingBySpawnId[def.spawnId] then
            table.insert(result, {
                entry = def.entry,
                spawnId = def.spawnId,
                name = def.name,
                zone = def.zone,
                status = "spawning",
                spawnIn = nil,
            })
        end
    end

    return result
end

function WorldBossPlugin:OnUpdate(elapsed)
    -- Keep countdown timers moving even if the server only sent a snapshot value.
    if DCInfoBar.serverData and type(DCInfoBar.serverData.worldBosses) == "table" then
        for _, b in ipairs(DCInfoBar.serverData.worldBosses) do
            if b and b.status ~= "active" then
                local t = tonumber(b.spawnIn)
                if t and t > 0 then
                    b.spawnIn = math.max(0, t - (elapsed or 0))
                end
            end
        end
    end

    local bosses = _GetUniqueBosses(DCInfoBar.serverData.worldBosses)
    
    if not bosses or #bosses == 0 then
        return "", "No Bosses"
    end

    -- If multiple bosses are active, show an aggregate summary instead of cycling.
    local now = GetTime and GetTime() or 0
    local activeCount = 0
    for _, b in ipairs(bosses) do
        local isJustSpawned = b.justSpawnedUntil and now < b.justSpawnedUntil
        if b.status == "active" or isJustSpawned then
            activeCount = activeCount + 1
        end
    end
    if activeCount > 1 then
        return "", string.format("|cff50ff7a%d bosses active|r", activeCount)
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

    local isJustSpawned = boss.justSpawnedUntil and now < boss.justSpawnedUntil

    local hpPct = tonumber(boss.hp)
    local isDeadHp = (hpPct ~= nil) and (hpPct <= 0)
    local isInactive = boss.status == "inactive"
    
    if (boss.status == "active") and (not isDeadHp) and (not isInactive) then
        -- Boss is up!
        local hpText = boss.hp and (" " .. boss.hp .. "%") or ""
        if isJustSpawned then
            return "", "|cff50ff7a" .. boss.name .. ": Just spawned!" .. hpText .. "|r"
        end
        return "", "|cff50ff7a" .. boss.name .. ": Active!" .. hpText .. "|r"
    elseif ((boss.status == "spawning") or isDeadHp or isInactive) and boss.spawnIn then
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
    
    local bosses = _GetUniqueBosses(DCInfoBar.serverData.worldBosses)
    
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
            local hpPct = tonumber(boss.hp)
            local isDeadHp = (hpPct ~= nil) and (hpPct <= 0)
            local isInactive = boss.status == "inactive"
            
            if (boss.status == "active") and (not isDeadHp) and (not isInactive) then
                statusText = isJustSpawned and "Just spawned!" or "Active!"
                if boss.hp then
                    statusText = statusText .. " (" .. boss.hp .. "% HP)"
                end
                r, g, b = 0.3, 1, 0.5
            elseif ((boss.status == "spawning") or isDeadHp or isInactive) and boss.spawnIn then
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
