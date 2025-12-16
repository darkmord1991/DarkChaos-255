--[[
    DC-InfoBar Core
    Main framework and plugin system
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}
_G.DCInfoBar = DCInfoBar

-- ============================================================================
-- Core Variables
-- ============================================================================

DCInfoBar.VERSION = "1.0.0"
DCInfoBar.plugins = {}              -- Registered plugins
DCInfoBar.activePlugins = { left = {}, right = {} }
DCInfoBar.serverData = {}           -- Cached server data

-- DCAddonProtocol reference
local DC = nil

-- Token info (from DCAddonProtocol if available)
DCInfoBar.TokenInfo = nil

-- ============================================================================
-- Timers (WotLK-safe)
-- ============================================================================

-- WotLK 3.3.5a does not provide C_Timer; some clients/backports do.
-- Use C_Timer.After when available, otherwise fallback to a lightweight OnUpdate timer.
function DCInfoBar:After(seconds, fn)
    if type(fn) ~= "function" then
        return
    end

    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(seconds or 0, fn)
        return
    end

    local delay = tonumber(seconds) or 0
    if delay <= 0 then
        pcall(fn)
        return
    end

    local f = CreateFrame("Frame")
    f._remaining = delay
    f:SetScript("OnUpdate", function(self, elapsed)
        self._remaining = self._remaining - (elapsed or 0)
        if self._remaining <= 0 then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            pcall(fn)
        end
    end)
end

-- ============================================================================
-- Token Information Integration (DCAddonProtocol)
-- ============================================================================

function DCInfoBar:InitializeTokenInfo()
    local DCProtocol = rawget(_G, "DCAddonProtocol")
    if DCProtocol then
        self.TokenInfo = DCProtocol
    end
end

function DCInfoBar:GetTokenIcon(itemID)
    if self.TokenInfo and self.TokenInfo.GetTokenIcon then
        return self.TokenInfo:GetTokenIcon(itemID)
    end
    return "Interface\\Icons\\INV_Misc_Token_ArgentCrusade"  -- Fallback
end

function DCInfoBar:GetTokenInfo(itemID)
    if self.TokenInfo and self.TokenInfo.GetTokenInfo then
        return self.TokenInfo:GetTokenInfo(itemID)
    end
    return nil
end

function DCInfoBar:FormatTokenDisplay(itemID, count, colorCode)
    if self.TokenInfo and self.TokenInfo.FormatTokenDisplay then
        return self.TokenInfo:FormatTokenDisplay(itemID, count, colorCode)
    end
    return tostring(count or 0)
end

-- ============================================================================
-- Server Data Cache (populated by DCAddonProtocol)
-- ============================================================================

DCInfoBar.serverData = {
    -- Seasonal data
    season = {
        id = 0,
        name = "Unknown",
        weeklyTokens = 0,
        weeklyCap = 500,
        weeklyEssence = 0,
        essenceCap = 200,
        totalTokens = 0,
        endsIn = 0,           -- Seconds until season ends
        weeklyReset = 0,      -- Seconds until weekly reset
    },
    
    -- Keystone data
    keystone = {
        hasKey = false,
        dungeonId = 0,
        dungeonName = "None",
        dungeonAbbrev = "",
        level = 0,
        depleted = false,
        weeklyBest = 0,
        seasonBest = 0,
    },
    
    -- Affixes data
    affixes = {
        ids = {},             -- Array of spell IDs
        names = {},           -- Array of names
        descriptions = {},    -- Array of descriptions
        resetIn = 0,          -- Seconds until reset
    },
    
    -- World boss timers
    worldBosses = {
        -- { name = "Oondasta", zone = "Giant Isles", status = "spawning", spawnIn = 3600, hp = nil }
    },
    
    -- Zone events
    events = {
        -- { name = "Zandalari Invasion", zone = "Giant Isles", type = "invasion", wave = 2, maxWaves = 4, timeRemaining = 300 }
    },
}

-- ============================================================================
-- Plugin Registration
-- ============================================================================

function DCInfoBar:RegisterPlugin(plugin)
    if not plugin.id then
        self:Print("Error: Plugin must have an id")
        return
    end
    
    -- Set defaults
    plugin.side = plugin.side or "left"
    plugin.priority = plugin.priority or 500
    plugin.type = plugin.type or "text"
    plugin.updateInterval = plugin.updateInterval or 1.0
    plugin._elapsed = 0
    
    -- Store in registry
    self.plugins[plugin.id] = plugin
    
    self:Debug("Registered plugin: " .. plugin.id)
end

function DCInfoBar:ActivatePlugin(pluginId)
    if self._activatingPluginId == pluginId then
        -- Prevent recursive activation loops caused by plugin callbacks.
        return
    end

    local plugin = self.plugins[pluginId]
    if not plugin then return end
    
    -- Check if enabled in settings
    if not self:IsPluginEnabled(pluginId) then
        return
    end
    
    -- Get side from settings or plugin default
    local side = self:GetPluginSetting(pluginId, "side") or plugin.side
    plugin.side = side
    
    -- Get priority from settings or plugin default
    local priority = self:GetPluginSetting(pluginId, "priority") or plugin.priority
    plugin.priority = priority
    
    -- Add to active list
    table.insert(self.activePlugins[side], plugin)
    
    -- Sort by priority
    table.sort(self.activePlugins[side], function(a, b)
        return a.priority < b.priority
    end)
    
    -- Create button for plugin
    if self.bar then
        self.bar:CreatePluginButton(plugin)
    end
    
    -- Call plugin's OnActivate if exists
    if plugin.OnActivate then
        self._activatingPluginId = pluginId
        plugin:OnActivate()
        self._activatingPluginId = nil
    end
    
    self:Debug("Activated plugin: " .. pluginId)
end

function DCInfoBar:DeactivatePlugin(pluginId)
    local plugin = self.plugins[pluginId]
    if not plugin then return end
    
    -- Remove from active list
    for side, list in pairs(self.activePlugins) do
        for i, p in ipairs(list) do
            if p.id == pluginId then
                table.remove(list, i)
                break
            end
        end
    end
    
    -- Hide button
    if plugin.button then
        plugin.button:Hide()
    end
    
    -- Call plugin's OnDeactivate if exists
    if plugin.OnDeactivate then
        plugin:OnDeactivate()
    end
end

function DCInfoBar:RefreshAllPlugins()
    -- Never rebuild while a plugin is mid-activation (can cause recursion / empty bar).
    if self._activatingPluginId then
        return
    end

    if self._refreshingPlugins then
        return
    end

    self._refreshingPlugins = true

    -- Clear active lists
    self.activePlugins = { left = {}, right = {} }
    
    -- Re-activate all enabled plugins
    for id, plugin in pairs(self.plugins) do
        self:ActivatePlugin(id)
    end
    
    -- Refresh bar layout
    if self.bar then
        self.bar:RefreshLayout()
    end

    self._refreshingPlugins = false
end

-- ============================================================================
-- Server Communication (DCAddonProtocol)
-- ============================================================================

-- Season Opcodes (matches server-side dc_addon_season.cpp)
local SEAS_CMSG_GET_CURRENT = 0x01
local SEAS_SMSG_CURRENT     = 0x10
local SEAS_SMSG_PROGRESS    = 0x12

-- M+ Opcodes (if DC.Opcode.MPlus doesn't exist)
local MPLUS_CMSG_GET_KEY_INFO = 0x01
local MPLUS_SMSG_KEY_INFO     = 0x10

function DCInfoBar:SetupServerCommunication()
    DC = rawget(_G, "DCAddonProtocol")
    
    if not DC then
        self:Debug("DCAddonProtocol not found - server features disabled")
        return false
    end
    
    self:Debug("DCAddonProtocol found - registering handlers")
    
    -- Register handlers for server data
    
    -- Season info (using direct opcodes - not DC.Opcode.Season which doesn't exist)
    DC:RegisterHandler("SEAS", SEAS_SMSG_CURRENT, function(data)
        DCInfoBar:HandleSeasonData(data)
    end)
    
    -- Also handle progress data for more detailed season info
    DC:RegisterHandler("SEAS", SEAS_SMSG_PROGRESS, function(data)
        DCInfoBar:HandleSeasonProgressData(data)
    end)
    
    -- Keystone info (from Group Finder)
    if DC.GroupFinderOpcodes and DC.GroupFinderOpcodes.SMSG_KEYSTONE_INFO then
        DC:RegisterHandler("GRPF", DC.GroupFinderOpcodes.SMSG_KEYSTONE_INFO, function(data)
            DCInfoBar:HandleKeystoneData(data)
        end)
    end
    
    -- Keystone info (from MythicPlus module)
    DC:RegisterHandler("MPLUS", MPLUS_SMSG_KEY_INFO, function(data)
        DCInfoBar:HandleKeystoneData(data)
    end)
    
    -- We'll also hook into DCMythicPlusHUD if available for affix data
    -- Event updates (legacy path via GRPF module)
    if DC.RegisterJSONHandler then
        DC:RegisterJSONHandler("GRPF", 0x70, function(data)
            DCInfoBar:HandleEventData(data)
        end)

        -- Dedicated EVENTS module feed (preferred)
        DC:RegisterJSONHandler("EVNT", 0x10, function(data) -- SMSG_EVENT_UPDATE
            DCInfoBar:HandleEventData(data)
        end)

        DC:RegisterJSONHandler("EVNT", 0x11, function(data) -- SMSG_EVENT_SPAWN
            DCInfoBar:HandleEventData(data)
        end)

        DC:RegisterJSONHandler("EVNT", 0x12, function(data) -- SMSG_EVENT_REMOVE
            DCInfoBar:HandleEventRemove(data)
        end)

        -- Fallback: also register non-JSON handlers for legacy server payloads
        DC:RegisterHandler("EVNT", 0x10, function(data)
            DCInfoBar:Debug("Received legacy EVNT handler payload")
            DCInfoBar:HandleEventData(data)
        end)
        DC:RegisterHandler("EVNT", 0x11, function(data)
            DCInfoBar:Debug("Received legacy EVNT spawn payload")
            DCInfoBar:HandleEventData(data)
        end)
        DC:RegisterHandler("EVNT", 0x12, function(data)
            DCInfoBar:Debug("Received legacy EVNT remove payload")
            DCInfoBar:HandleEventRemove(data)
        end)

        -- Also fallback for GRPF events if plain handler used
        DC:RegisterHandler("GRPF", 0x70, function(data)
            DCInfoBar:Debug("Received legacy GRPF event payload")
            DCInfoBar:HandleEventData(data)
        end)

        self:Debug("Registered JSON handlers for events (and legacy fallbacks)")
    else
        self:Debug("Warning: RegisterJSONHandler not available in DCAddonProtocol")
    end

    -- Fallback: register non-JSON handlers if available (ensure events are handled as well)
    if DC.RegisterHandler then
        DC:RegisterHandler("EVNT", 0x10, function(data)
            DCInfoBar:Debug("Received legacy EVNT handler payload (fallback)")
            DCInfoBar:HandleEventData(data)
        end)
        DC:RegisterHandler("EVNT", 0x11, function(data)
            DCInfoBar:Debug("Received legacy EVNT spawn payload (fallback)")
            DCInfoBar:HandleEventData(data)
        end)
        DC:RegisterHandler("EVNT", 0x12, function(data)
            DCInfoBar:Debug("Received legacy EVNT remove payload (fallback)")
            DCInfoBar:HandleEventRemove(data)
        end)
        DC:RegisterHandler("GRPF", 0x70, function(data)
            DCInfoBar:Debug("Received legacy GRPF event payload (fallback)")
            DCInfoBar:HandleEventData(data)
        end)
    end

    -- Register world content handlers (WRLD module)
    if DC.RegisterJSONHandler then
        DC:RegisterJSONHandler("WRLD", 0x10, function(data) -- SMSG_CONTENT
            DCInfoBar:HandleWorldContent(data)
        end)
        DC:RegisterJSONHandler("WRLD", 0x11, function(data) -- SMSG_UPDATE
            DCInfoBar:HandleWorldUpdate(data)
        end)
    elseif DC.RegisterHandler then
        -- Fallback to legacy handlers if JSON not supported
        DC:RegisterHandler("WRLD", 0x10, function(data)
            DCInfoBar:Debug("Received legacy WRLD content payload (fallback)")
            DCInfoBar:HandleWorldContent(data)
        end)
        DC:RegisterHandler("WRLD", 0x11, function(data)
            DCInfoBar:Debug("Received legacy WRLD update payload (fallback)")
            DCInfoBar:HandleWorldUpdate(data)
        end)
    end

    return true
end

-- Handle event JSON payload from server and update serverData.events
function DCInfoBar:HandleEventData(data)
    if not data then return end

    self.serverData.events = self.serverData.events or {}
    local events = self.serverData.events

    local eventId = data["eventId"] or data["id"] or 0
    local record = {
        id = eventId,
        name = data["name"] or "Event",
        zone = data["zone"] or data["zoneName"] or (data["mapId"] and ("Map " .. tostring(data["mapId"]))) or "Unknown",
        type = data["type"] or "event",
        state = data["state"] or data["status"] or "active",
        active = data["active"] ~= false,
        wave = data["wave"] or 0,
        maxWaves = data["maxWaves"] or 4,
        enemiesRemaining = data["enemiesRemaining"] or nil,
        timeRemaining = data["timeRemaining"] or nil,
        lane = data["lane"] or nil,
        reason = data["reason"],
    }

    -- If an event ends, keep it visible briefly with a countdown, then prune.
    do
        local state = record.state
        local ended = (record.active == false) or (state == "victory" or state == "failed" or state == "stopped" or state == "cancelled" or state == "ended")
        if ended then
            local now = GetTime and GetTime() or 0
            record.hideAt = now + 30
            -- If the server doesn't provide a timer, show the remaining time until hide.
            if not record.timeRemaining or record.timeRemaining <= 0 then
                record.timeRemaining = 30
            end
        end
    end

    local updated = false
    for index, existing in ipairs(events) do
        if existing.id == record.id and record.id ~= 0 then
            -- If the event became active again, clear any prior hideAt.
            if record.active ~= false then
                record.hideAt = nil
            elseif existing and existing.hideAt and record.hideAt then
                -- Preserve the later hideAt if multiple end messages arrive.
                record.hideAt = math.max(existing.hideAt, record.hideAt)
            end

            events[index] = record
            updated = true
            break
        end
    end

    if not updated then
        table.insert(events, record)
    end

    -- Debug: announce event data arrival and refresh UI immediately
    DCInfoBar:Debug(string.format("HandleEventData: id=%s name=%s type=%s state=%s active=%s", tostring(record.id or "0"), tostring(record.name), tostring(record.type), tostring(record.state), tostring(record.active)))

    -- Force plugin refresh so UI updates immediately
    DCInfoBar:RefreshAllPlugins()
end

function DCInfoBar:HandleEventRemove(data)
    self.serverData.events = self.serverData.events or {}
    local events = self.serverData.events

    if not data then
        wipe(events)
        DCInfoBar:Debug("HandleEventRemove: wiped all events")
        DCInfoBar:RefreshAllPlugins()
        return
    end

    local targetId = data["eventId"] or data["id"]
    if not targetId then
        wipe(events)
        DCInfoBar:Debug("HandleEventRemove: no target id, wiped all events")
        DCInfoBar:RefreshAllPlugins()
        return
    end

    for index = #events, 1, -1 do
        if events[index].id == targetId then
            table.remove(events, index)
            DCInfoBar:Debug("HandleEventRemove: removed event id=" .. tostring(targetId))
            break
        end
    end

    DCInfoBar:RefreshAllPlugins()
end

-- Handle world content payload: hotspots, bosses, events
local function NormalizeHotspotItem(h)
    if not h or type(h) ~= "table" then return nil end
    local id = tonumber(h.id or h.hotspotId)
    if not id then return nil end
    return {
        id = id,
        name = h.name or "Hotspot",
        mapId = tonumber(h.mapId or h.map) or 0,
        zoneId = tonumber(h.zoneId or h.zone) or 0,
        zoneName = h.zoneName or h.zone or "Unknown Zone",
        x = tonumber(h.x) or 0,
        y = tonumber(h.y) or 0,
        z = tonumber(h.z) or 0,
        bonusPercent = tonumber(h.bonusPercent or h.xpBonus or h.bonus) or 0,
        timeRemaining = tonumber(h.timeRemaining or h.timeLeft or h.dur) or 0,
        action = h.action,
    }
end

-- Fallback boss definitions (used if the server only sends partial boss lists)
local DEFAULT_GIANT_ISLES_BOSSES = {
    { entry = 400100, spawnId = 9000190, id = "oondasta", name = "Oondasta, King of Dinosaurs", zone = "Devilsaur Gorge" },
    { entry = 400101, spawnId = 9000189, id = "thok",     name = "Thok the Bloodthirsty",     zone = "Raptor Ridge" },
    { entry = 400102, spawnId = 9000191, id = "nalak",    name = "Nalak the Storm Lord",      zone = "Thundering Peaks" },
}

local function GetCurrentWDay0()
    if date then
        local t = date("*t")
        if t and t.wday then
            return (tonumber(t.wday) - 1) % 7
        end
    end
    return 0
end

local function SecondsUntilNextMidnight()
    if not date or not time then
        return 0
    end

    local t = date("*t")
    if not t then
        return 0
    end

    local nextMid = {
        year = t.year,
        month = t.month,
        day = t.day + 1,
        hour = 0,
        min = 0,
        sec = 0,
    }

    local now = time()
    local nextTime = time(nextMid)
    local diff = (nextTime and now) and (nextTime - now) or 0
    if diff < 0 then diff = 0 end
    return diff
end

local function BossEntryForDay(d0)
    -- Mon/Thu = Oondasta; Tue/Fri = Thok; Wed/Sat/Sun = Nalak
    if d0 == 0 or d0 == 3 or d0 == 6 then return 400102 end
    if d0 == 1 or d0 == 4 then return 400100 end
    if d0 == 2 or d0 == 5 then return 400101 end
    return 400100
end

local function SecondsUntilBossRotation(currentDay0, bossEntry)
    local secondsUntilNextMidnight = SecondsUntilNextMidnight()
    for offset = 0, 6 do
        local d0 = (currentDay0 + offset) % 7
        if BossEntryForDay(d0) == bossEntry then
            if offset == 0 then
                return 0
            end
            return secondsUntilNextMidnight + ((offset - 1) * 24 * 60 * 60)
        end
    end
    return secondsUntilNextMidnight
end

function DCInfoBar:EnsureDefaultWorldBosses()
    self.serverData.worldBosses = self.serverData.worldBosses or {}
    local bosses = self.serverData.worldBosses

    local function NormName(s)
        s = tostring(s or "")
        s = string.lower(s)
        s = string.gsub(s, "[^a-z0-9]+", "")
        return s
    end

    local existingBySpawnId = {}
    local existingByEntry = {}
    local existingByName = {}
    for _, b in ipairs(bosses) do
        if b then
            if b.spawnId then
                existingBySpawnId[tonumber(b.spawnId)] = b
            end
            if b.entry then
                existingByEntry[tonumber(b.entry)] = b
            end
            if b.name then
                existingByName[NormName(b.name)] = b
            end
        end
    end

    local day0 = GetCurrentWDay0()
    local activeEntry = BossEntryForDay(day0)

    for _, def in ipairs(DEFAULT_GIANT_ISLES_BOSSES) do
        -- Ensure each configured spawnId exists. spawnId is the authoritative identity.
        local existing = existingBySpawnId[def.spawnId]
        if existing then
            -- Patch missing identifiers/fields so future merges can match reliably.
            if not existing.spawnId then existing.spawnId = def.spawnId end
            if not existing.entry then existing.entry = def.entry end
            if not existing.zone or existing.zone == "Unknown" or existing.zone == "Unknown Zone" then
                existing.zone = def.zone
            end
            if (not existing.name) or existing.name == "Unknown" or tostring(existing.name) == tostring(def.entry) then
                existing.name = def.name
            end

            -- If we only have fallback timing and the server hasn't provided better info,
            -- fill in a rotation-based spawnIn.
            if (existing.status ~= "active") and (existing.spawnIn == nil or tonumber(existing.spawnIn) == nil) then
                if def.entry == activeEntry then
                    existing.status = existing.status or "active"
                    existing.spawnIn = existing.spawnIn or 0
                else
                    existing.status = existing.status or "spawning"
                    existing.spawnIn = existing.spawnIn or SecondsUntilBossRotation(day0, def.entry)
                end
            end
        else
            local rec = {
                entry = def.entry,
                name = def.name,
                zone = def.zone,
                spawnId = def.spawnId,
            }

            if def.entry == activeEntry then
                rec.status = "active"
                rec.spawnIn = 0
            else
                rec.status = "spawning"
                rec.spawnIn = SecondsUntilBossRotation(day0, def.entry)
            end

            table.insert(bosses, rec)
            existingBySpawnId[def.spawnId] = rec
            existingByEntry[def.entry] = rec
            existingByName[NormName(def.name)] = rec
        end
    end

    -- Final pass: remove any duplicates that still slipped in (prefer spawnId, then active).
    do
        local seen = {}
        local i = 1
        while i <= #bosses do
            local b = bosses[i]
            local key = nil
            -- Prefer spawnId as primary identity.
            if b and b.spawnId then
                key = "s:" .. tostring(b.spawnId)
            elseif b and b.entry then
                key = "e:" .. tostring(b.entry)
            elseif b and b.name then
                key = "n:" .. NormName(b.name)
            elseif b and b.guid then
                key = "g:" .. tostring(b.guid)
            end

            if key and seen[key] then
                local kept = seen[key]
                local drop = b

                local function score(x)
                    local s = 0
                    if x and x.spawnId then s = s + 10 end
                    if x and x.status == "active" then s = s + 3 end
                    if x and x.hp ~= nil then s = s + 1 end
                    if x and x.spawnIn ~= nil then s = s + 1 end
                    return s
                end

                if score(drop) > score(kept) then
                    -- Replace kept values with better data
                    for k, v in pairs(drop) do
                        kept[k] = v
                    end
                end
                table.remove(bosses, i)
            else
                if key then
                    seen[key] = b
                end
                i = i + 1
            end
        end
    end
end

function DCInfoBar:HandleWorldContent(data)
    if not data then return end
    -- Hotspots (not currently shown in DC-InfoBar but store for completeness)
    if data.hotspots then
        local hotspots = {}
        for _, h in ipairs(data.hotspots) do
            local rec = NormalizeHotspotItem(h)
            if rec then table.insert(hotspots, rec) end
        end
        self.serverData.hotspots = hotspots
    end

    -- Bosses
    if data.bosses then
        self.serverData.worldBosses = self.serverData.worldBosses or {}
        local bosses = self.serverData.worldBosses
        local now = GetTime and GetTime() or 0

        if self.Debug and type(data.bosses) == "table" then
            self:Debug("HandleWorldContent: bosses received=" .. tostring(#data.bosses))
        end

        for _, b in ipairs(data.bosses) do
            local record = {}
            record.name = b.name or b.displayName or b.entry or b.guid or "Unknown"
            record.zone = b.zone or b.zoneName or (b.mapId and ("Map " .. tostring(b.mapId))) or "Unknown"
            record.spawnId = tonumber(b.spawnId) or nil
            record.entry = tonumber(b.entry or b.npcEntry or b.creatureEntry) or nil
            -- Map status: prefer explicit status field, otherwise derive from active/action
            if b.status or b.state then
                record.status = b.status or b.state
            elseif b.active ~= nil then
                record.status = b.active and "active" or "inactive"
            elseif b.action then
                if b.action == "engage" then record.status = "active"
                elseif b.action == "death" or b.action == "despawn" then record.status = "inactive"
                else record.status = "spawning" end
            else
                record.status = (b.active == false) and "inactive" or "spawning"
            end

            -- Support explicit spawn action -> show "just spawned" for a short window.
            if b.action == "spawn" then
                record.status = "active"
                record.justSpawnedUntil = now + 60
            end

            -- spawnIn/timeLeft
            record.spawnIn = b.spawnIn or b.timeLeft or nil
            -- hp percent
            if b.hpPct then record.hp = b.hpPct end
            if b.hp then record.hp = b.hp end
            record.guid = b.guid

            -- Upsert by spawnId, guid, or name
            local replaced = false
            if record.spawnId then
                for i, ex in ipairs(bosses) do
                    if ex.spawnId == record.spawnId then
                        bosses[i] = record; replaced = true; break
                    end
                end
            end
            if (not replaced) and record.entry then
                for i, ex in ipairs(bosses) do
                    if ex.entry == record.entry then
                        bosses[i] = record; replaced = true; break
                    end
                end
            end
            if record.guid then
                for i, ex in ipairs(bosses) do
                    if ex.guid == record.guid then
                        bosses[i] = record; replaced = true; break
                    end
                end
            end
            if not replaced then
                for i, ex in ipairs(bosses) do
                    if ex.name == record.name then
                        bosses[i] = record; replaced = true; break
                    end
                end
            end
            if not replaced then
                table.insert(bosses, record)
            end
        end

        -- If the server only sends a partial list, ensure the defaults exist so the UI shows all bosses.
        self:EnsureDefaultWorldBosses()
    end

    -- Events
    if data.events then
        self.serverData.events = self.serverData.events or {}
        local events = self.serverData.events
        for _, e in ipairs(data.events) do
            local eventId = e.id or e.eventId or 0
            local state = e.state or e.status or e.action or "active"
            if state == "spawn" then state = "spawning" end
            local record = {
                id = eventId,
                name = e.name or e.displayName or "Event",
                zone = e.zone or e.zoneName or (e.mapId and ("Map " .. tostring(e.mapId))) or "Unknown",
                type = e.type or "event",
                state = state,
                active = (e.active == nil) and true or (e.active ~= false),
                wave = e.wave,
                maxWaves = e.maxWaves,
                enemiesRemaining = e.enemiesRemaining,
                timeRemaining = e.timeRemaining or e.timeLeft,
            }

            -- Upsert
            local updated = false
            for i, ex in ipairs(events) do
                if ex.id ~= 0 and ex.id == record.id and record.id ~= 0 then
                    events[i] = record; updated = true; break
                end
            end
            if not updated then table.insert(events, record) end
        end
    end

    -- Trigger UI refresh
    self:Debug("HandleWorldContent: world content updated (bosses/events/hotspots)")
    DCInfoBar:RefreshAllPlugins()
end

-- Handle world content updates (partial updates - merge with existing state)
function DCInfoBar:HandleWorldUpdate(data)
    if not data then return end

    -- Hotspot updates
    if data.hotspots then
        self.serverData.hotspots = self.serverData.hotspots or {}
        local hotspots = self.serverData.hotspots

        for _, h in ipairs(data.hotspots) do
            local rec = NormalizeHotspotItem(h)
            if rec then
                if rec.action == "expire" or rec.action == "remove" then
                    for i = #hotspots, 1, -1 do
                        if hotspots[i].id == rec.id then
                            table.remove(hotspots, i)
                            break
                        end
                    end
                else
                    local replaced = false
                    for i, ex in ipairs(hotspots) do
                        if ex.id == rec.id then
                            hotspots[i] = rec
                            replaced = true
                            break
                        end
                    end
                    if not replaced then
                        table.insert(hotspots, rec)
                    end
                end
            end
        end
    end

    -- Boss updates
    if data.bosses then
        self.serverData.worldBosses = self.serverData.worldBosses or {}
        local bosses = self.serverData.worldBosses
        local now = GetTime and GetTime() or 0
        for _, b in ipairs(data.bosses) do
            local spawnId = tonumber(b.spawnId) or nil
            local guid = b.guid
            local name = b.name
            local entry = tonumber(b.entry or b.npcEntry or b.creatureEntry) or nil
            local up = {}
            if spawnId then up.spawnId = spawnId end
            if entry then up.entry = entry end

            -- Some servers send full status payloads without an explicit action.
            if b.status or b.state then
                up.status = b.status or b.state
            end
            if b.zone or b.zoneName then
                up.zone = b.zone or b.zoneName
            end
            if b.name then
                up.name = b.name
            end

            if b.action == "engage" then
                up.status = "active"
                up.hp = b.hpPct or b.hp
            end
            if b.action == "spawn" then
                up.status = "active"
                up.hp = b.hpPct or b.hp
                up.justSpawnedUntil = now + 60
            end
            if b.action == "death" or b.action == "remove" or b.action == "despawn" then
                up.status = "inactive"
                up.justSpawnedUntil = nil
            end
            if b.hpPct then up.hp = b.hpPct end
            if b.timeLeft then up.spawnIn = b.timeLeft end
            if b.spawnIn then up.spawnIn = b.spawnIn end
            if b.threshold then up.lastThreshold = b.threshold end

            local matched = false
            for i, ex in ipairs(bosses) do
                if (spawnId and ex.spawnId == spawnId) or (entry and ex.entry == entry) or (guid and ex.guid == guid) or (name and ex.name == name) then
                    for k, v in pairs(up) do ex[k] = v end
                    matched = true; break
                end
            end
            if not matched then
                local record = { name = name or entry or "Unknown", guid = guid, zone = b.zone or b.zoneName, spawnId = spawnId, entry = entry }
                for k,v in pairs(up) do record[k] = v end
                table.insert(bosses, record)
            end
        end

        -- Keep defaults present even if updates only mention one boss.
        self:EnsureDefaultWorldBosses()
    end

    -- Event updates
    if data.events then
        self.serverData.events = self.serverData.events or {}
        local events = self.serverData.events
        for _, e in ipairs(data.events) do
            local id = e.id or e.eventId or 0
            local state = e.state or e.status or e.action
            if state == "spawn" then state = "spawning" end
            local record = {
                id = id,
                name = e.name,
                zone = e.zone or e.zoneName,
                type = e.type or "event",
                state = state,
                active = (e.active == nil) and true or (e.active ~= false),
                wave = e.wave,
                maxWaves = e.maxWaves,
                enemiesRemaining = e.enemiesRemaining,
                timeRemaining = e.timeRemaining or e.timeLeft,
            }
            -- Upsert by id
            local matched = false
            if id ~= 0 then
                for i, ex in ipairs(events) do
                    if ex.id == id then events[i] = record; matched = true; break end
                end
            end
            if not matched then table.insert(events, record) end
        end
    end

    self:Debug("HandleWorldUpdate: world updates merged")
    DCInfoBar:RefreshAllPlugins()
end

function DCInfoBar:RequestServerData(opts)
    opts = (type(opts) == "table") and opts or {}
    local retries = tonumber(opts.retries) or 0

    if not DC then 
        DC = rawget(_G, "DCAddonProtocol")
    end
    
    if not DC then
        self:Debug("DCAddonProtocol not available for RequestServerData")
        return
    end

    -- Wait until the protocol reports connected (otherwise early requests can be dropped)
    if DC.IsConnected and not DC:IsConnected() then
        if retries > 0 then
            self:Debug("RequestServerData: waiting for DCAddonProtocol connection...")
            self:After(2, function()
                DCInfoBar:RequestServerData({ retries = retries - 1 })
            end)
        else
            self:Debug("RequestServerData: DCAddonProtocol not connected (giving up)")
        end
        return
    end

    local now = GetTime and GetTime() or 0
    if self._lastServerDataRequestAt and (now - self._lastServerDataRequestAt) < 1 then
        return
    end
    self._lastServerDataRequestAt = now
    
    self:Debug("Requesting server data...")
    
    -- Request seasonal info (using direct opcode)
    DC:Request("SEAS", SEAS_CMSG_GET_CURRENT, {})
    DC:Request("SEAS", 0x03, {})  -- Also try CMSG_GET_PROGRESS
    
    -- Request keystone info from both modules for redundancy
    if DC.GroupFinderOpcodes and DC.GroupFinderOpcodes.CMSG_GET_MY_KEYSTONE then
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_MY_KEYSTONE, {})
    end
    
    DC:Request("MPLUS", MPLUS_CMSG_GET_KEY_INFO, {})
    
    -- Request hotspot list
    DC:Request("SPOT", 0x01, {})
    if DC.Hotspot and DC.Hotspot.GetList then
        DC.Hotspot.GetList()
    end

    -- Request aggregated world content snapshot (includes hotspots, bosses, events)
    DC:Request("WRLD", 0x01, {})
    
    -- Request prestige info
    DC:Request("PRES", 0x01, {})
end

-- Convenience getters for other addons/scripts to query current season token values
function DCInfoBar:GetWeeklyTokens()
    if self.serverData and self.serverData.season then
        return self.serverData.season.weeklyTokens or 0
    end
    return 0
end

function DCInfoBar:GetInventoryTokens()
    if self.serverData and self.serverData.season then
        return self.serverData.season.totalTokens or 0
    end
    return 0
end

-- Handle season progress data (SMSG 0x12)
function DCInfoBar:HandleSeasonProgressData(data)
    if not data then return end
    
    -- Update season data with progress info
    local season = self.serverData.season
    
    if data.seasonId or data.id then
        season.id = data.seasonId or data.id
    end
    -- Prefer explicit weeklyTokens when provided
    if data.weeklyTokens then
        season.weeklyTokens = data.weeklyTokens
    end
    if data.weeklyEssence then
        season.weeklyEssence = data.weeklyEssence
    end
    if data.tokenCap then
        season.weeklyCap = data.tokenCap
    end
    if data.essenceCap then
        season.essenceCap = data.essenceCap
    end
    -- Use `tokens`/`totalTokens` as the player's inventory total
    if data.tokens then
        season.totalTokens = data.tokens
    elseif data.totalTokens then
        season.totalTokens = data.totalTokens
    end
    if data.essence then
        season.totalEssence = data.essence
    end

    
    -- If name is still Unknown, check DCWelcome
    if (not season.name or season.name == "Unknown" or season.name == "Unknown Season") then
        if DCWelcome and DCWelcome.Seasons and DCWelcome.Seasons.Data then
            local D = DCWelcome.Seasons.Data
            if D.seasonName and D.seasonName ~= "Unknown Season" then
                season.name = D.seasonName
            end
        end
    end
    
    -- Notify season plugin
    if self.plugins["DCInfoBar_Season"] and self.plugins["DCInfoBar_Season"].OnServerData then
        self.plugins["DCInfoBar_Season"]:OnServerData(season)
    end
    
    -- Print debug values for quick verification in the chat (when debug mode enabled)
    self:Debug(string.format("HandleSeasonProgressData: seasonId=%d weeklyTokens=%d totalTokens=%d weeklyCap=%d", 
        season.id or 0, season.weeklyTokens or 0, season.totalTokens or 0, season.weeklyCap or 0))
    self:Debug('Full payload: ' .. (type(data) == "table" and (data.weeklyTokens or data.tokens or 0) or "(no-data)"))
end

-- Handle incoming season data
function DCInfoBar:HandleSeasonData(data)
    if not data then return end
    
    self.serverData.season = {
        id = data.seasonId or data.id or 0,
        name = data.seasonName or data.name or "Unknown",
        weeklyTokens = data.weeklyTokens or 0,
        weeklyCap = data.weeklyCap or data.tokenCap or 1000,
        weeklyEssence = data.weeklyEssence or 0,
        essenceCap = data.essenceCap or 1000,
        totalTokens = data.tokens or data.totalTokens or 0,
        endsIn = data.endsIn or 0,
        weeklyReset = data.weeklyReset or 0,
    }
    
    -- If name is still Unknown, check DCWelcome
    if (self.serverData.season.name == "Unknown" or self.serverData.season.name == "Unknown Season") then
        if DCWelcome and DCWelcome.Seasons and DCWelcome.Seasons.Data then
            local D = DCWelcome.Seasons.Data
            if D.seasonName and D.seasonName ~= "Unknown Season" then
                self.serverData.season.name = D.seasonName
            end
        end
    end
    
    -- Notify season plugin
    if self.plugins["DCInfoBar_Season"] and self.plugins["DCInfoBar_Season"].OnServerData then
        self.plugins["DCInfoBar_Season"]:OnServerData(self.serverData.season)
    end
    
    self:Debug("Season data received: " .. self.serverData.season.name)
end

-- Handle incoming keystone data
function DCInfoBar:HandleKeystoneData(data)
    if not data then return end
    
    self.serverData.keystone = {
        hasKey = (data.level and data.level > 0) or false,
        dungeonId = data.dungeonId or data.mapId or 0,
        dungeonName = data.dungeonName or data.name or "None",
        dungeonAbbrev = data.abbreviation or data.abbrev or "",
        level = data.level or data.keyLevel or 0,
        depleted = data.depleted or false,
        weeklyBest = data.weeklyBest or 0,
        seasonBest = data.seasonBest or 0,
    }
    
    -- Generate abbreviation if not provided
    if self.serverData.keystone.dungeonName and self.serverData.keystone.dungeonAbbrev == "" then
        self.serverData.keystone.dungeonAbbrev = self:GenerateDungeonAbbrev(self.serverData.keystone.dungeonName)
    end
    
    -- Notify keystone plugin
    if self.plugins["DCInfoBar_Keystone"] and self.plugins["DCInfoBar_Keystone"].OnServerData then
        self.plugins["DCInfoBar_Keystone"]:OnServerData(self.serverData.keystone)
    end
    
    self:Debug("Keystone data received: +" .. self.serverData.keystone.level .. " " .. self.serverData.keystone.dungeonAbbrev)
end

-- Handle incoming affix data
function DCInfoBar:HandleAffixData(data)
    if not data then return end
    
    self.serverData.affixes = {
        ids = data.affixIds or data.ids or {},
        names = data.affixNames or data.names or {},
        descriptions = data.descriptions or {},
        resetIn = data.resetIn or 0,
    }
    
    -- Notify affixes plugin
    if self.plugins["DCInfoBar_Affixes"] and self.plugins["DCInfoBar_Affixes"].OnServerData then
        self.plugins["DCInfoBar_Affixes"]:OnServerData(self.serverData.affixes)
    end
end

-- Generate dungeon abbreviation from name
function DCInfoBar:GenerateDungeonAbbrev(name)
    if not name or name == "" then return "" end
    
    -- Known abbreviations
    local known = {
        ["Utgarde Keep"] = "UK",
        ["Utgarde Pinnacle"] = "UP",
        ["The Nexus"] = "Nex",
        ["The Oculus"] = "Occ",
        ["Halls of Stone"] = "HoS",
        ["Halls of Lightning"] = "HoL",
        ["The Culling of Stratholme"] = "CoS",
        ["Azjol-Nerub"] = "AN",
        ["Ahn'kahet"] = "AK",
        ["Drak'Tharon Keep"] = "DTK",
        ["Gundrak"] = "GD",
        ["The Violet Hold"] = "VH",
        ["Trial of the Champion"] = "ToC",
        ["Forge of Souls"] = "FoS",
        ["Pit of Saron"] = "PoS",
        ["Halls of Reflection"] = "HoR",
    }
    
    if known[name] then
        return known[name]
    end
    
    -- Generate from first letters of words
    local abbrev = ""
    for word in string.gmatch(name, "%S+") do
        -- Skip common words
        if word ~= "The" and word ~= "of" and word ~= "the" then
            abbrev = abbrev .. string.sub(word, 1, 1)
        end
    end
    
    return string.upper(abbrev)
end

-- ============================================================================
-- Update System
-- ============================================================================

function DCInfoBar:OnUpdate(elapsed)
    if not self.db or not self.db.global or not self.db.global.enabled then
        return
    end
    
    -- Hide in combat if configured
    if self.db.global.hideInCombat and UnitAffectingCombat("player") then
        if self.bar and self.bar:IsShown() then
            self.bar:Hide()
        end
        return
    elseif self.bar and not self.bar:IsShown() and self.db.global.enabled then
        self.bar:Show()
    end
    
    -- Update each active plugin (always, regardless of button visibility, so plugins can control their own visibility)
    for _, side in ipairs({"left", "right"}) do
        for _, plugin in ipairs(self.activePlugins[side]) do
            if plugin.button then
                plugin._elapsed = (plugin._elapsed or 0) + elapsed
                
                if plugin._elapsed >= (plugin.updateInterval or 1.0) then
                    plugin._elapsed = 0
                    
                    if plugin.OnUpdate then
                        local success, label, value, color = pcall(plugin.OnUpdate, plugin, elapsed)
                        if success then
                            self.bar:UpdatePluginText(plugin, label, value, color)
                        end
                    end
                end
            end
        end
    end
end

function DCInfoBar:ForceUpdateAllPlugins()
    if not self.bar then
        return
    end

    for _, side in ipairs({"left", "right"}) do
        for _, plugin in ipairs(self.activePlugins[side] or {}) do
            if plugin and plugin.button and plugin.OnUpdate then
                local ok, label, value, color = pcall(plugin.OnUpdate, plugin, 0)
                if ok then
                    self.bar:UpdatePluginText(plugin, label, value, color)
                end
            end
        end
    end
end

-- ============================================================================
-- Initialization
-- ============================================================================

function DCInfoBar:Initialize()
    -- Initialize token info from DC-Central
    local function SafeStep(label, fn)
        local ok, err = xpcall(fn, function(e)
            local trace = ""
            if debugstack then
                trace = debugstack(2, 8, 8)
            end
            return tostring(e) .. (trace ~= "" and (" | " .. trace) or "")
        end)
        if not ok then
            self:Print("Init ERROR in " .. label .. ": " .. tostring(err))
        end
        return ok
    end

    SafeStep("InitializeTokenInfo", function()
        self:InitializeTokenInfo()
    end)
    
    -- Initialize saved variables
    SafeStep("InitializeDB", function()
        self:InitializeDB()
    end)

    -- Lightweight runtime diagnostics (gated by debug)
    do
        local enabled = (self.db and self.db.global and self.db.global.enabled) and "true" or "false"
        self:Debug("Init: global.enabled=" .. enabled)
    end
    
    -- Setup server communication
    SafeStep("SetupServerCommunication", function()
        local ok = self:SetupServerCommunication()
        self:Debug("Init: DCAddonProtocol=" .. (ok and "found" or "missing"))
        local DCProtocol = rawget(_G, "DCAddonProtocol")
        if DCProtocol then
            self:Debug("Init: DC.RegisterJSONHandler=" .. (DCProtocol.RegisterJSONHandler and "yes" or "no"))
            self:Debug("Init: DC.PREFIX=" .. tostring(DCProtocol.PREFIX))
        end
    end)
    
    -- Create the bar
    SafeStep("CreateBar", function()
        if self.CreateBar then
            self.bar = self:CreateBar()
        else
            self:Print("Init: CreateBar() missing - UI/Bar.lua not loaded?")
        end

        if self.bar then
            self:Debug("Init: bar created, shown=" .. (self.bar:IsShown() and "true" or "false") .. ", h=" .. tostring(self.bar:GetHeight()) .. ", strata=" .. tostring(self.bar:GetFrameStrata()))
        else
            self:Debug("Init: bar NOT created")
        end
    end)

    -- Ensure Interface Options panel is registered (so it shows under Interface -> AddOns)
    SafeStep("CreateOptionsPanel", function()
        if self.CreateOptionsPanel and not self.optionsPanel then
            self:CreateOptionsPanel()
        end
    end)
    
    SafeStep("ActivatePlugins", function()
        -- Count registered plugins before activation
        local registeredCount = 0
        for _ in pairs(self.plugins or {}) do
            registeredCount = registeredCount + 1
        end
        self:Debug("Init: registered plugins=" .. tostring(registeredCount))

        -- Activate all enabled plugins
        for id, plugin in pairs(self.plugins or {}) do
            if self:IsPluginEnabled(id) then
                self:ActivatePlugin(id)
            end
        end

        local leftCount = (self.activePlugins and self.activePlugins.left and #self.activePlugins.left) or 0
        local rightCount = (self.activePlugins and self.activePlugins.right and #self.activePlugins.right) or 0
        self:Debug("Init: active plugins left=" .. tostring(leftCount) .. " right=" .. tostring(rightCount))
    end)

    -- If nothing is active, tell the user how to recover.
    do
        local leftCount = (self.activePlugins and self.activePlugins.left and #self.activePlugins.left) or 0
        local rightCount = (self.activePlugins and self.activePlugins.right and #self.activePlugins.right) or 0
        local activeCount = leftCount + rightCount

        local registeredCount = 0
        for _ in pairs(self.plugins or {}) do
            registeredCount = registeredCount + 1
        end

        if activeCount == 0 then
            self:Debug("Init: no active plugins (registered=" .. tostring(registeredCount) .. "). Try /infobar reset.")
        end
    end
    
    SafeStep("RefreshLayout", function()
        if self.bar then
            self.bar:RefreshLayout()
        end
    end)
    
    SafeStep("UpdateFrame", function()
        -- Create update frame
        local updateFrame = CreateFrame("Frame")
        self._updateFrame = updateFrame
        local updateElapsed = 0
        updateFrame:SetScript("OnUpdate", function(_, elapsed)
            updateElapsed = updateElapsed + elapsed
            if updateElapsed >= 0.1 then  -- Update at 10 FPS max
                DCInfoBar:OnUpdate(updateElapsed)
                updateElapsed = 0
            end
        end)

        -- Ensure all plugins have initial text immediately (before the first OnUpdate tick)
        self:ForceUpdateAllPlugins()
        self:Debug("Init: ForceUpdateAllPlugins done")
    end)
    
    -- Request server data after a short delay (wait for connection)
    self:After(2, function()
        DCInfoBar:RequestServerData({ retries = 10 })
    end)
    
    -- Setup slash commands
    self:SetupSlashCommands()
    
    self:Print("DC-InfoBar v" .. self.VERSION .. " loaded. Type /infobar for options.")
end

-- ============================================================================
-- Slash Commands
-- ============================================================================

function DCInfoBar:SetupSlashCommands()
    SLASH_DCINFOBAR1 = "/infobar"
    SLASH_DCINFOBAR2 = "/dcinfo"
    SLASH_DCINFOBAR3 = "/dcib"
    
    SlashCmdList["DCINFOBAR"] = function(msg)
        local cmd = string.lower(msg or "")
        
        if cmd == "" or cmd == "options" or cmd == "config" then
            self:OpenOptions()
        elseif cmd == "toggle" then
            self.db.global.enabled = not self.db.global.enabled
            if self.bar then
                if self.db.global.enabled then self.bar:Show() else self.bar:Hide() end
            end
            self:Print("InfoBar " .. (self.db.global.enabled and "enabled" or "disabled"))
        elseif cmd == "reset" then
            self:ResetToDefaults()
        elseif cmd == "debug" then
            self.db.debug = not self.db.debug
            self:Print("Debug mode " .. (self.db.debug and "enabled" or "disabled"))
        elseif cmd == "refresh" then
            self:RequestServerData()
            self:Print("Refreshing server data...")
        elseif cmd == "testevent" then
            -- Test event display
            self:Print("Injecting test event...")
            self:HandleEventData({
                id = 999,
                eventId = 999,
                name = "Test Invasion",
                zone = "Giant Isles",
                type = "invasion",
                state = "active",
                active = true,
                wave = 2,
                maxWaves = 4,
                enemiesRemaining = 15,
                timeRemaining = 300
            })
            self:Print("Event count: " .. #(self.serverData.events or {}))
        elseif cmd == "events" then
            local events = self.serverData.events or {}
            self:Print("Active events: " .. #events)
            for i, event in ipairs(events) do
                self:Print(string.format("  %d: %s (%s) - %s", i, event.name, event.zone, event.state))
            end
        elseif cmd == "showevent" then
            -- Temporarily disable hideWhenNone to force show events
            self:SetPluginSetting("DCInfoBar_Events", "hideWhenNone", false)
            self:Print("Event display forced ON (hideWhenNone disabled)")
            self:RefreshAllPlugins()
        elseif cmd == "hideevent" then
            -- Re-enable hideWhenNone
            self:SetPluginSetting("DCInfoBar_Events", "hideWhenNone", true)
            self:Print("Event display restored to normal (hideWhenNone enabled)")
            self:RefreshAllPlugins()
        elseif cmd == "testseason" then
            -- Inject a season progress payload to test UI updates
            local a, b, c = string.match(msg, "testseason%s+(%d+)%s*(%d*)%s*(%d*)")
            local weekly = tonumber(a) or tonumber(b) or 0
            local totalT = tonumber(b) or tonumber(c) or 0
            local id = tonumber(c) or 1
            if not weekly then weekly = 0 end
            local payload = {
                seasonId = id,
                tokens = totalT,
                weeklyTokens = weekly,
                tokenCap = 1000,
                essence = 0,
                weeklyEssence = 0,
                essenceCap = 1000
            }
            self:HandleSeasonProgressData(payload)
            self:Print("Injected test season payload: weeklyTokens=" .. tostring(payload.weeklyTokens) .. ", totalTokens=" .. tostring(payload.tokens))
        elseif cmd == "showseason" then
            local s = self.serverData.season or {}
            self:Print(string.format("Season ID: %s, Name: %s, weeklyTokens: %s, tokens: %s, weeklyCap: %s, essence: %s", tostring(s.id or 0), tostring(s.name or "Unknown"), tostring(s.weeklyTokens or 0), tostring(s.totalTokens or 0), tostring(s.weeklyCap or 0), tostring(s.weeklyEssence or 0)))
        else
            self:Print("Commands:")
            self:Print("  /infobar - Open options")
            self:Print("  /infobar toggle - Show/hide bar")
            self:Print("  /infobar reset - Reset to defaults")
            self:Print("  /infobar debug - Toggle debug mode")
            self:Print("  /infobar refresh - Refresh server data")
            self:Print("  /infobar testevent - Inject test invasion event")
            self:Print("  /infobar events - Show current events")
            self:Print("  /infobar showevent - Force show event display")
            self:Print("  /infobar hideevent - Hide event display")
            self:Print("  /infobar testseason [weekly] [total] [id] - Test season data")
            self:Print("  /infobar showseason - Show current season data")
            self:Print("  /infobar testevent - Inject test event")
            self:Print("  /infobar events - List current events")
        end
    end
end

function DCInfoBar:OpenOptions()
    if not self.optionsPanel and self.CreateOptionsPanel then
        pcall(function() self:CreateOptionsPanel() end)
    end

    if (not InterfaceOptionsFrame_OpenToCategory or not InterfaceOptionsFrame) and UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, "Blizzard_InterfaceOptions")
    end

    if InterfaceOptionsFrame and InterfaceOptionsFrame_OpenToCategory and self.optionsPanel then
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)  -- Called twice due to WoW bug
    elseif self.optionsPanel then
        self.optionsPanel:Show()
    else
        self:Print("Options panel not yet initialized.")
    end
end

-- ============================================================================
-- Event Handler
-- ============================================================================

local eventFrame = CreateFrame("Frame")
DCInfoBar._eventFrame = eventFrame
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        DCInfoBar:Print("PLAYER_LOGIN")
        DCInfoBar:After(0.5, function()
            xpcall(function()
                DCInfoBar:Initialize()
            end, function(e)
                local trace = ""
                if debugstack then
                    trace = debugstack(2, 8, 8)
                end
                DCInfoBar:Print("Init ERROR (top-level): " .. tostring(e) .. (trace ~= "" and (" | " .. trace) or ""))
            end)
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Refresh location data
        if DCInfoBar.plugins["DCInfoBar_Location"] then
            DCInfoBar.plugins["DCInfoBar_Location"]._elapsed = 999  -- Force update
        end
    end
end)
