--[[
    DC-InfoBar World Boss Plugin
    Shows world boss spawn timers and status

    Data Source: WRLD content snapshot/updates (Core.lua). Core keeps the boss
    list de-duplicated and TickServerTimers keeps spawnIn live.
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local WRLD_CMSG_GET_CONTENT = 0x01
-- Re-ask for the snapshot at most this many times when bosses lack state
-- (a boss with no respawn timer would otherwise trigger requests forever).
local MAX_SNAPSHOT_RETRIES = 3
local SNAPSHOT_RETRY_INTERVAL = 30
local CYCLE_SECONDS = 5

local WorldBossPlugin = {
    id = "DCInfoBar_WorldBoss",
    name = "World Boss",
    category = "server",
    type = "combo",
    side = "left",
    priority = 40,
    icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
    updateInterval = 1.0,

    leftClickHint = "Open Group Finder",
    rightClickHint = "Print all boss timers",

    _currentBossIndex = 1,
    _cycleTimer = 0,
    _snapshotRetries = 0,
    _lastSnapshotRequestAt = 0,
}

local function GetBosses()
    return DCInfoBar.serverData.worldBosses
end

-- Classify a boss record: "active", "spawning" (with a timer) or "unknown".
local function GetBossState(boss, now)
    local status = string.lower(tostring(boss.status or ""))
    local hp = tonumber(boss.hp)
    local dead = hp ~= nil and hp <= 0

    if status == "active" and not dead then
        return "active", boss.justSpawnedUntil and now < boss.justSpawnedUntil
    end
    if tonumber(boss.spawnIn) then
        return "spawning"
    end
    return "unknown"
end

function WorldBossPlugin:MaybeRequestSnapshot(bosses, now)
    if self._snapshotRetries >= MAX_SNAPSHOT_RETRIES then
        return
    end
    if (now - self._lastSnapshotRequestAt) < SNAPSHOT_RETRY_INTERVAL then
        return
    end
    -- A snapshot that just arrived without a timer won't change on an immediate re-ask.
    local lastSnapshot = DCInfoBar.serverData._lastWRLDContentAt
    if lastSnapshot and (now - lastSnapshot) < SNAPSHOT_RETRY_INTERVAL then
        return
    end

    for _, boss in ipairs(bosses) do
        if GetBossState(boss, now) == "unknown" then
            local proto = DCInfoBar:GetProtocol()
            if proto then
                self._snapshotRetries = self._snapshotRetries + 1
                self._lastSnapshotRequestAt = now
                proto:Request("WRLD", WRLD_CMSG_GET_CONTENT, {})
            end
            return
        end
    end

    -- Everything has state: a later gap deserves fresh retries.
    self._snapshotRetries = 0
end

function WorldBossPlugin:OnUpdate(elapsed)
    local bosses = GetBosses()
    if #bosses == 0 then
        return "", "No Bosses"
    end

    local now = GetTime()
    self:MaybeRequestSnapshot(bosses, now)

    local activeCount = 0
    for _, boss in ipairs(bosses) do
        if GetBossState(boss, now) == "active" then
            activeCount = activeCount + 1
        end
    end
    if activeCount > 1 then
        return "", string.format("|cff50ff7a%d bosses active|r", activeCount)
    end

    local showOnlyActive = DCInfoBar:GetPluginSetting(self.id, "showOnlyActive")
    if showOnlyActive and activeCount == 0 then
        return "", "No Active Boss"
    end

    -- Cycle through bosses
    self._cycleTimer = self._cycleTimer + (elapsed or 0)
    if self._cycleTimer >= CYCLE_SECONDS then
        self._cycleTimer = 0
        self._currentBossIndex = self._currentBossIndex + 1
    end
    if self._currentBossIndex > #bosses then
        self._currentBossIndex = 1
    end

    local boss = bosses[self._currentBossIndex]
    if showOnlyActive or activeCount == 1 then
        for _, b in ipairs(bosses) do
            if GetBossState(b, now) == "active" then
                boss = b
                break
            end
        end
    end

    local state, justSpawned = GetBossState(boss, now)
    local name = tostring(boss.name)
    if state == "active" then
        local hpText = boss.hp and (" " .. boss.hp .. "%") or ""
        return "", "|cff50ff7a" .. name .. ": " .. (justSpawned and "Just spawned!" or "Active!") .. hpText .. "|r"
    elseif state == "spawning" then
        return "", name .. ": " .. DCInfoBar:FormatTimeShort(boss.spawnIn)
    end
    return "", name .. ": Unknown"
end

function WorldBossPlugin:OnTooltip(tooltip)
    tooltip:AddLine("World Boss Timers", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)

    local bosses = GetBosses()
    if #bosses == 0 then
        tooltip:AddLine("No world boss data", 0.7, 0.7, 0.7)
        return
    end

    -- Group by zone, zones in first-seen order so the tooltip doesn't reshuffle.
    local zones, byZone = {}, {}
    for _, boss in ipairs(bosses) do
        local zone = boss.zone or "Unknown"
        if not byZone[zone] then
            byZone[zone] = {}
            table.insert(zones, zone)
        end
        table.insert(byZone[zone], boss)
    end

    local now = GetTime()
    for _, zone in ipairs(zones) do
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff32c4ff" .. zone .. "|r")

        for _, boss in ipairs(byZone[zone]) do
            local state, justSpawned = GetBossState(boss, now)
            local statusText, r, g, b
            if state == "active" then
                statusText = justSpawned and "Just spawned!" or "Active!"
                if boss.hp then
                    statusText = statusText .. " (" .. boss.hp .. "% HP)"
                end
                r, g, b = 0.3, 1, 0.5
            elseif state == "spawning" then
                statusText = "Spawns in " .. DCInfoBar:FormatTimeShort(boss.spawnIn)
                r, g, b = 1, 0.82, 0
            else
                statusText = "Unknown"
                r, g, b = 0.5, 0.5, 0.5
            end

            tooltip:AddDoubleLine("  " .. tostring(boss.name), statusText, 0.8, 0.8, 0.8, r, g, b)
        end
    end
end

function WorldBossPlugin:OnClick(button)
    if button == "LeftButton" then
        local hud = rawget(_G, "DCMythicPlusHUD")
        if hud and hud.GroupFinder and hud.GroupFinder.Toggle then
            hud.GroupFinder:Toggle()
        else
            DCInfoBar:Print("Group Finder not available")
        end
        return
    end

    if button ~= "RightButton" then
        return
    end

    local bosses = GetBosses()
    if #bosses == 0 then
        DCInfoBar:Print("No world boss data available")
        return
    end

    local now = GetTime()
    DCInfoBar:Print("World Boss Timers:")
    for _, boss in ipairs(bosses) do
        local state, justSpawned = GetBossState(boss, now)
        local status = (state == "active" and (justSpawned and "JUST SPAWNED" or "ACTIVE"))
            or (state == "spawning" and DCInfoBar:FormatTimeShort(boss.spawnIn))
            or "unknown"
        DCInfoBar:Print(string.format("  %s (%s): %s", tostring(boss.name), tostring(boss.zone), status))
    end

    -- Raw protocol state for diagnosing snapshot problems.
    if DCInfoBar.db and DCInfoBar.db.debug then
        local sd = DCInfoBar.serverData
        DCInfoBar:Debug(string.format("WRLD snapshot age: %ss | update age: %ss",
            sd._lastWRLDContentAt and math.floor(now - sd._lastWRLDContentAt) or "?",
            sd._lastWRLDUpdateAt and math.floor(now - sd._lastWRLDUpdateAt) or "?"))
        for _, list in ipairs({ sd._lastWRLDBossContentSummary or {}, sd._lastWRLDBossUpdateSummary or {} }) do
            for _, line in ipairs(list) do
                DCInfoBar:Debug("  " .. line)
            end
        end
    end
end

function WorldBossPlugin:OnCreateOptions(parent, yOffset)
    DCInfoBar:CreateCheckbox(parent, "Only show when boss is active", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showOnlyActive", checked)
        self._elapsed = 999
    end, DCInfoBar:GetPluginSetting(self.id, "showOnlyActive"))

    return yOffset - 30
end

DCInfoBar:RegisterPlugin(WorldBossPlugin)
