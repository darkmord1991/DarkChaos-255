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

DCInfoBar.VERSION = "1.1.0"
DCInfoBar.plugins = {}              -- Registered plugins
DCInfoBar.activePlugins = { left = {}, right = {} }

-- DCAddonProtocol reference
local DC = nil

-- Hoisted: the 10 Hz update loop iterates both sides every tick; building a
-- fresh {"left", "right"} table there churned the GC.
local SIDES = { "left", "right" }

-- Token info (from DCAddonProtocol if available)
DCInfoBar.TokenInfo = nil

-- ============================================================================
-- Timers (WotLK-safe)
-- ============================================================================

-- WotLK 3.3.5a does not provide C_Timer natively, but Utils.lua provides a polyfill.
-- This wrapper ensures safe callback scheduling.
function DCInfoBar:After(seconds, fn)
    if type(fn) ~= "function" then
        return
    end
    
    local delay = tonumber(seconds) or 0
    if delay <= 0 then
        pcall(fn)
        return
    end
    
    -- Use C_Timer.After (provided by Utils.lua polyfill or native)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, fn)
    else
        -- Emergency fallback (should never happen since Utils.lua loads first)
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

-- Shape is read by other addons (DC-MythicPlus WorldTab, DC-Mapupgrades,
-- DC-Welcome): keep field names stable.
DCInfoBar.serverData = {
    -- Seasonal data (SEAS). endsIn/weeklyReset are live seconds maintained by
    -- TickServerTimers from the _endsAt/_weeklyResetAt local-clock anchors.
    season = {
        id = 0,
        name = "Unknown",
        tokenId = 0,
        essenceId = 0,
        weeklyTokens = 0,
        weeklyCap = 0,
        weeklyEssence = 0,
        essenceCap = 0,
        totalTokens = 0,
        totalEssence = 0,
        endsIn = 0,
        weeklyReset = 0,
    },

    -- Keystone data (MPLUS SMSG_KEY_INFO)
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

    -- Weekly affixes (MPLUS SMSG_AFFIXES)
    affixes = {
        ids = {},
        names = {},
        descriptions = {},
        icons = {},
        resetIn = 0,
    },

    -- Prestige (PRES SMSG_INFO / SMSG_BONUSES), filled by Plugins/Server/Prestige.lua
    prestige = {},

    -- World bosses (WRLD): { name, zone, spawnId, entry, status, spawnIn, spawnAt, hp, ... }
    worldBosses = {},

    -- Zone events (EVNT + WRLD): { id, name, zone, type, state, active, wave, maxWaves, ... }
    events = {},

    -- Active hotspots (WRLD snapshot/updates, SPOT list replies)
    hotspots = {},

    -- Server restart/shutdown countdown
    restartStatus = {
        active = false,
        mode = nil,       -- "restart" or "shutdown"
        remaining = 0,    -- seconds remaining
        total = 0,        -- seconds at start
        reason = nil,
        lastUpdateAt = 0,
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

    if not self:IsPluginEnabled(pluginId) then
        return
    end

    plugin.side = self:GetPluginSetting(pluginId, "side") or plugin.side
    plugin.priority = self:GetPluginSetting(pluginId, "priority") or plugin.priority

    local list = self.activePlugins[plugin.side]
    for _, p in ipairs(list) do
        if p == plugin then
            return
        end
    end
    table.insert(list, plugin)
    table.sort(list, function(a, b)
        return a.priority < b.priority
    end)

    if self.bar then
        self.bar:CreatePluginButton(plugin)
    end

    -- OnActivate is not idempotent (it registers events/frames), so only fire
    -- it on a real inactive -> active transition. RefreshAllPlugins() rebuilds
    -- the active lists without clearing _activePluginIds for that reason.
    self._activePluginIds = self._activePluginIds or {}
    if not self._activePluginIds[pluginId] then
        self._activePluginIds[pluginId] = true
        if plugin.OnActivate then
            self._activatingPluginId = pluginId
            local ok, err = pcall(plugin.OnActivate, plugin)
            self._activatingPluginId = nil
            if not ok then
                self:Print("Plugin " .. pluginId .. " failed to activate: " .. tostring(err))
            end
        end
    end

    self:Debug("Activated plugin: " .. pluginId)
end

function DCInfoBar:DeactivatePlugin(pluginId)
    local plugin = self.plugins[pluginId]
    if not plugin then return end

    for _, list in pairs(self.activePlugins) do
        for i, p in ipairs(list) do
            if p.id == pluginId then
                table.remove(list, i)
                break
            end
        end
    end

    if plugin.button then
        plugin.button:Hide()
    end

    -- Clear the active-tracking flag so re-enabling fires OnActivate() again.
    local wasActive = self._activePluginIds and self._activePluginIds[pluginId]
    if self._activePluginIds then
        self._activePluginIds[pluginId] = nil
    end

    if wasActive and plugin.OnDeactivate then
        plugin:OnDeactivate()
    end

    if self.bar then
        self.bar:RefreshLayout()
    end
end

function DCInfoBar:RefreshAllPlugins()
    -- Never rebuild while a plugin is mid-activation (can cause recursion / empty bar).
    if self._activatingPluginId or self._refreshingPlugins then
        return
    end
    self._refreshingPlugins = true

    self.activePlugins = { left = {}, right = {} }

    for id, plugin in pairs(self.plugins) do
        if self:IsPluginEnabled(id) then
            self:ActivatePlugin(id)
        elseif self._activePluginIds and self._activePluginIds[id] then
            self:DeactivatePlugin(id)
        elseif plugin.button then
            plugin.button:Hide()
        end
    end

    if self.bar then
        -- Re-apply per-button style (icon/label toggles, side changes) and
        -- redraw every text, then lay out once.
        for _, plugin in pairs(self.plugins) do
            if plugin.button and self.ApplyPluginButtonStyle then
                self:ApplyPluginButtonStyle(plugin)
            end
        end
        self:ForceUpdateAllPlugins()
        self.bar:RefreshLayout()
    end

    self._refreshingPlugins = false
end

-- ============================================================================
-- Server Communication (DCAddonProtocol)
-- ============================================================================
-- Every protocol handler DC-InfoBar needs is registered here, once, at file
-- load (see the bottom of this file). Registering at load instead of at
-- PLAYER_LOGIN means pushes that arrive right after the addon handshake (the
-- WRLD snapshot, invasion updates) are never missed while the bar initializes.
--
-- Plain RegisterHandler on purpose: DCAddonProtocol's dispatcher skips every
-- plain handler for a module/opcode as soon as a JSON handler exists for it,
-- so a JSON handler here would silently starve DC-MythicPlus / DC-Mapupgrades.
-- Plain handlers still receive the decoded JSON table.

local SEAS_CMSG_GET_CURRENT  = 0x01
local SEAS_CMSG_GET_PROGRESS = 0x03
local SEAS_SMSG_CURRENT      = 0x10
local SEAS_SMSG_PROGRESS     = 0x12

local MPLUS_CMSG_GET_KEY_INFO = 0x01
local MPLUS_CMSG_GET_AFFIXES  = 0x02
local MPLUS_SMSG_KEY_INFO     = 0x10
local MPLUS_SMSG_AFFIXES      = 0x11

local PRES_CMSG_GET_INFO = 0x01

local SPOT_SMSG_HOTSPOT_LIST = 0x10
local SPOT_SMSG_HOTSPOT_INFO = 0x11

local WRLD_CMSG_GET_CONTENT = 0x01
local WRLD_SMSG_CONTENT     = 0x10
local WRLD_SMSG_UPDATE      = 0x11

local EVNT_SMSG_UPDATE = 0x10
local EVNT_SMSG_SPAWN  = 0x11
local EVNT_SMSG_REMOVE = 0x12

-- How long an ended event stays on the bar ("Stopped (Victory)").
local EVENT_LINGER_SECONDS = 30

local EVENT_STOPPED_STATES = {
    victory = true,
    failed = true,
    stopped = true,
    cancelled = true,
    ended = true,
}
DCInfoBar.EVENT_STOPPED_STATES = EVENT_STOPPED_STATES

local function Now()
    return GetTime and GetTime() or 0
end

-- Server countdowns are relative seconds; anchor them to the local clock so
-- they tick smoothly between pushes and never depend on update cadence.
local function Deadline(seconds)
    seconds = tonumber(seconds)
    if seconds and seconds > 0 then
        return Now() + seconds
    end
    return nil
end

function DCInfoBar:GetProtocol()
    DC = DC or rawget(_G, "DCAddonProtocol")
    return DC
end

function DCInfoBar:NotifyPlugin(pluginId, data)
    local plugin = self.plugins[pluginId]
    if plugin and plugin.OnServerData then
        plugin:OnServerData(data)
    end
end

-- A pipe-delimited message arrives as several string args. Re-join them so a
-- '|' inside a field (affix descriptions) doesn't truncate the payload.
local function CollapseHandlerArgs(...)
    local first = ...
    if type(first) == "table" or select("#", ...) <= 1 then
        return first
    end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    return table.concat(parts, "|")
end

function DCInfoBar:SetupServerCommunication()
    if self._serverHandlersRegistered then
        return true
    end

    local proto = self:GetProtocol()
    if not proto or not proto.RegisterHandler then
        self:Debug("DCAddonProtocol not found - server features disabled")
        return false
    end
    self._serverHandlersRegistered = true

    proto:RegisterHandler("SEAS", SEAS_SMSG_CURRENT, function(data)
        DCInfoBar:HandleSeasonData(data)
    end)
    proto:RegisterHandler("SEAS", SEAS_SMSG_PROGRESS, function(data)
        DCInfoBar:HandleSeasonProgressData(data)
    end)

    proto:RegisterHandler("MPLUS", MPLUS_SMSG_KEY_INFO, function(...)
        DCInfoBar:HandleKeystoneData(...)
    end)
    proto:RegisterHandler("MPLUS", MPLUS_SMSG_AFFIXES, function(...)
        DCInfoBar:HandleAffixData(CollapseHandlerArgs(...))
    end)

    proto:RegisterHandler("EVNT", EVNT_SMSG_UPDATE, function(data)
        DCInfoBar:HandleEventData(data)
    end)
    proto:RegisterHandler("EVNT", EVNT_SMSG_SPAWN, function(data)
        DCInfoBar:HandleEventData(data)
    end)
    proto:RegisterHandler("EVNT", EVNT_SMSG_REMOVE, function(data)
        DCInfoBar:HandleEventRemove(data)
    end)

    proto:RegisterHandler("WRLD", WRLD_SMSG_CONTENT, function(data)
        DCInfoBar:HandleWorldContent(data)
    end)
    proto:RegisterHandler("WRLD", WRLD_SMSG_UPDATE, function(data)
        DCInfoBar:HandleWorldUpdate(data)
    end)

    -- Hotspot list replies. InfoBar itself relies on the WRLD snapshot, but
    -- other addons (DC-Mapupgrades) poll SPOT, and their replies are free data.
    proto:RegisterHandler("SPOT", SPOT_SMSG_HOTSPOT_LIST, function(data)
        DCInfoBar:HandleHotspotList(data)
    end)
    proto:RegisterHandler("SPOT", SPOT_SMSG_HOTSPOT_INFO, function(data)
        DCInfoBar:UpsertHotspot(data)
        DCInfoBar:ForceUpdateAllPlugins()
    end)

    return true
end

-- ============================================================================
-- Zone events
-- ============================================================================

-- Upsert one event record. Updates are partial: only the fields present in the
-- payload overwrite the stored record, so an update that omits name/zone does
-- not blank them. Unknown keys (ritual, boatsScuttled, ...) are kept verbatim.
function DCInfoBar:UpsertEvent(e)
    if type(e) ~= "table" then
        return nil
    end

    local events = self.serverData.events
    local id = e.eventId or e.id
    local existing = nil
    if id ~= nil and id ~= 0 then
        for _, ex in ipairs(events) do
            if ex.id == id then
                existing = ex
                break
            end
        end
    end

    local rec = existing or {}
    for k, v in pairs(e) do
        rec[k] = v
    end

    rec.id = id or 0
    rec.name = e.name or e.displayName or rec.name or "Event"
    rec.zone = e.zone or e.zoneName or (e.mapId and ("Map " .. tostring(e.mapId))) or rec.zone or "Unknown"
    rec.type = e.type or rec.type or "event"

    local state = e.state or e.status or e.action
    if state == "spawn" then
        state = "spawning"
    end
    rec.state = state or rec.state or "active"

    if e.active ~= nil then
        rec.active = (e.active ~= false)
    elseif rec.active == nil then
        rec.active = true
    end

    local remaining = tonumber(e.timeRemaining or e.timeLeft)
    if remaining then
        rec.timeRemaining = remaining
        rec.endsAt = Deadline(remaining)
    end

    local ended = (rec.active == false) or EVENT_STOPPED_STATES[rec.state]
    if ended then
        rec.hideAt = rec.hideAt or (Now() + EVENT_LINGER_SECONDS)
        if not remaining then
            -- No server timer on the end message: count down the linger window.
            rec.endsAt = rec.hideAt
        end
    else
        rec.hideAt = nil
    end

    if not existing then
        table.insert(events, rec)
    end
    return rec
end

function DCInfoBar:HandleEventData(data)
    if type(data) ~= "table" then
        return
    end

    local rec = self:UpsertEvent(data)
    if rec then
        self:Debug(string.format("Event: id=%s name=%s state=%s active=%s",
            tostring(rec.id), tostring(rec.name), tostring(rec.state), tostring(rec.active)))
    end
    self:ForceUpdateAllPlugins()
end

function DCInfoBar:HandleEventRemove(data)
    local events = self.serverData.events
    local targetId = type(data) == "table" and (data.eventId or data.id) or nil

    if not targetId then
        wipe(events)
    elseif EVENT_STOPPED_STATES[data.state or data.status or ""] then
        -- A remove that carries an outcome (water monster "victory") should
        -- linger like any other ended event instead of vanishing instantly.
        data.active = false
        self:UpsertEvent(data)
    else
        for index = #events, 1, -1 do
            if events[index].id == targetId then
                table.remove(events, index)
                break
            end
        end
    end

    self:ForceUpdateAllPlugins()
end

-- Shared "is this event worth showing" filter for the plugin, tooltip and click.
function DCInfoBar:GetVisibleEvents(includeStopped)
    local out = {}
    local now = Now()
    for _, event in ipairs(self.serverData.events) do
        local stopped = (event.active == false) or EVENT_STOPPED_STATES[event.state]
        if not stopped then
            table.insert(out, event)
        elseif includeStopped and event.hideAt and now < event.hideAt then
            table.insert(out, event)
        end
    end
    return out
end

-- ============================================================================
-- Hotspots (single store, shared with DC-MythicPlus WorldTab)
-- ============================================================================

-- Accepts both the verbose WRLD keys and the compact SPOT keys
-- (i=id, m=mapId, z=zoneId, n=zoneName, x/y, h=height, t=seconds, b=bonus).
-- Compact records are detected by 'i', because 'z' means zoneId there but the
-- Z coordinate in the verbose form.
function DCInfoBar:NormalizeHotspot(h)
    if type(h) ~= "table" then
        return nil
    end

    local rec
    if h.i ~= nil then
        rec = {
            id = tonumber(h.i),
            mapId = tonumber(h.m) or 0,
            zoneId = tonumber(h.z) or 0,
            zoneName = h.n or "Unknown Zone",
            x = tonumber(h.x) or 0,
            y = tonumber(h.y) or 0,
            z = tonumber(h.h) or 0,
            timeRemaining = tonumber(h.t) or 0,
            bonusPercent = tonumber(h.b) or 0,
        }
    else
        rec = {
            id = tonumber(h.id or h.hotspotId),
            mapId = tonumber(h.mapId or h.map) or 0,
            zoneId = tonumber(h.zoneId) or 0,
            zoneName = h.zoneName or "Unknown Zone",
            x = tonumber(h.x) or 0,
            y = tonumber(h.y) or 0,
            z = tonumber(h.z) or 0,
            timeRemaining = tonumber(h.timeRemaining or h.timeLeft or h.dur) or 0,
            bonusPercent = tonumber(h.bonusPercent or h.xpBonus or h.bonus) or 0,
        }
    end

    if not rec.id then
        return nil
    end

    rec.name = h.name or "Hotspot"
    rec.bonus = rec.bonusPercent
    rec.action = h.action
    rec.expiresAt = Deadline(rec.timeRemaining)
    return rec
end

function DCInfoBar:SetHotspots(rawList)
    local list = {}
    if type(rawList) == "table" then
        for _, h in ipairs(rawList) do
            local rec = self:NormalizeHotspot(h)
            if rec then
                table.insert(list, rec)
            end
        end
    end
    self.serverData.hotspots = list
    self.serverData._hotspotsLoaded = true
end

function DCInfoBar:RemoveHotspot(id)
    id = tonumber(id)
    local hotspots = self.serverData.hotspots
    for i = #hotspots, 1, -1 do
        if hotspots[i].id == id then
            table.remove(hotspots, i)
        end
    end
end

function DCInfoBar:UpsertHotspot(raw)
    local rec = self:NormalizeHotspot(raw)
    if not rec then
        return nil
    end

    if rec.action == "expire" or rec.action == "remove" then
        self:RemoveHotspot(rec.id)
        return nil
    end

    local hotspots = self.serverData.hotspots
    for i, ex in ipairs(hotspots) do
        if ex.id == rec.id then
            hotspots[i] = rec
            return rec
        end
    end
    table.insert(hotspots, rec)
    return rec
end

function DCInfoBar:HandleHotspotList(data)
    if type(data) ~= "table" then
        return
    end
    -- Version-gated "unchanged" reply to another addon's poll: keep our set.
    if data.unchanged then
        return
    end

    if data.hotspots then
        self:SetHotspots(data.hotspots)
    elseif #data > 0 then
        self:SetHotspots(data)
    else
        self:SetHotspots({})
    end
    self:ForceUpdateAllPlugins()
end

-- ============================================================================
-- World bosses
-- ============================================================================

-- Fallback boss definitions (used if the server only sends partial boss lists)
-- Single source of truth for client-side boss identity/metadata.
-- mapId is the server zone ID (5006 = Giant Isles), nx/ny are normalized (0-1) coordinates for map pins.
-- Coordinates calculated from spawn data: Oondasta (6054,1109), Thok (6095,1336), Nalak (6243,789)
-- against WorldMapArea 1100 (MoP Isle of Giants art): Left 2004.17 Right 216.666 Top 6697.92 Bottom 5506.25
DCInfoBar.DEFAULT_WORLD_BOSSES = DCInfoBar.DEFAULT_WORLD_BOSSES or {
    { entry = 400100, spawnId = 9000190, id = "oondasta", name = "Oondasta, King of Dinosaurs", zone = "Devilsaur Gorge",    mapId = 5006, nx = 0.501, ny = 0.540 },
    { entry = 400101, spawnId = 9000189, id = "thok",     name = "Thok the Bloodthirsty",     zone = "Raptor Ridge",        mapId = 5006, nx = 0.374, ny = 0.506 },
    { entry = 400102, spawnId = 9000191, id = "nalak",    name = "Nalak the Storm Lord",      zone = "Thundering Peaks",    mapId = 5006, nx = 0.680, ny = 0.382 },
}

-- Centralized name normalization for boss/entity matching
-- Strips WoW formatting codes (colors/textures) and normalizes to lowercase alphanumeric
function DCInfoBar:NormName(s)
    s = tostring(s or "")
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    s = string.gsub(s, "|T.-|t", "")
    s = string.lower(s)
    s = string.gsub(s, "[^a-z0-9]+", "")
    return s
end

-- spawnIn is kept for consumers (DC-MythicPlus WorldTab, DC-Mapupgrades);
-- spawnAt is the local-clock anchor TickServerTimers derives it from.
local function StampBossSpawn(rec, spawnIn)
    spawnIn = tonumber(spawnIn)
    if spawnIn then
        rec.spawnIn = spawnIn
        rec.spawnAt = Now() + spawnIn
    end
end

function DCInfoBar:EnsureDefaultWorldBosses()
    local bosses = self.serverData.worldBosses

    local defaultBySpawnId = {}
    local defaultByEntry = {}
    local defaultByName = {}
    for _, def in ipairs(self.DEFAULT_WORLD_BOSSES) do
        defaultBySpawnId[def.spawnId] = def
        defaultByEntry[def.entry] = def
        defaultByName[self:NormName(def.name)] = def
    end

    -- Patch identity/metadata of the scripted bosses so later merges match.
    for _, b in ipairs(bosses) do
        b.spawnId = tonumber(b.spawnId) or b.spawnId
        b.entry = tonumber(b.entry) or b.entry

        local def = (b.spawnId and defaultBySpawnId[b.spawnId])
            or (b.entry and defaultByEntry[b.entry])
            or (b.name and defaultByName[self:NormName(b.name)])
        if def then
            b.spawnId = def.spawnId
            b.entry = def.entry
            b.zone = def.zone
            b.name = def.name
        end
    end

    -- Collapse duplicates (keyed by spawnId, then entry, name, guid), keeping
    -- the richer record.
    local function Score(x)
        local s = 0
        if x.spawnId then s = s + 10 end
        if x.status == "active" then s = s + 3 end
        if x.hp ~= nil then s = s + 1 end
        if x.spawnIn ~= nil then s = s + 1 end
        return s
    end

    local seen = {}
    local i = 1
    while i <= #bosses do
        local b = bosses[i]
        local key
        if b.spawnId then
            key = "s:" .. tostring(b.spawnId)
        elseif b.entry then
            key = "e:" .. tostring(b.entry)
        elseif b.name then
            key = "n:" .. self:NormName(b.name)
        elseif b.guid then
            key = "g:" .. tostring(b.guid)
        end

        local kept = key and seen[key]
        if kept then
            if Score(b) > Score(kept) then
                for k, v in pairs(b) do
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

    -- Make sure every configured boss is listed. Timers stay server-authoritative.
    for _, def in ipairs(self.DEFAULT_WORLD_BOSSES) do
        if not seen["s:" .. tostring(def.spawnId)] then
            table.insert(bosses, {
                entry = def.entry,
                name = def.name,
                zone = def.zone,
                spawnId = def.spawnId,
                status = "spawning",
            })
        end
    end
end

-- Find the stored boss a payload refers to (spawnId, then entry, guid, name).
local function FindBoss(bosses, spawnId, entry, guid, name)
    for _, key in ipairs({ "spawnId", "entry", "guid", "name" }) do
        local want = (key == "spawnId" and spawnId) or (key == "entry" and entry)
            or (key == "guid" and guid) or (key == "name" and name)
        if want ~= nil then
            for i, ex in ipairs(bosses) do
                if ex[key] == want then
                    return i, ex
                end
            end
        end
    end
    return nil, nil
end

local function SummarizeBosses(list)
    local out = {}
    for _, b in ipairs(list) do
        if type(b) == "table" then
            table.insert(out, string.format("spawnId=%s entry=%s status=%s active=%s spawnIn=%s action=%s",
                tostring(b.spawnId), tostring(b.entry or b.npcEntry or b.creatureEntry),
                tostring(b.status or b.state), tostring(b.active), tostring(b.spawnIn or b.timeLeft),
                tostring(b.action)))
        end
    end
    return out
end

function DCInfoBar:HandleWorldContent(data)
    if type(data) ~= "table" then
        return
    end
    self.serverData._lastWRLDContentAt = Now()

    if data.hotspots then
        self:SetHotspots(data.hotspots)
    end

    if type(data.bosses) == "table" then
        if self.db and self.db.debug then
            self.serverData._lastWRLDBossContentSummary = SummarizeBosses(data.bosses)
        end

        local bosses = self.serverData.worldBosses
        local now = Now()

        for _, b in ipairs(data.bosses) do
            local record = {
                name = b.name or b.displayName or b.entry or b.guid or "Unknown",
                zone = b.zone or b.zoneName or (b.mapId and ("Map " .. tostring(b.mapId))) or "Unknown",
                spawnId = tonumber(b.spawnId),
                entry = tonumber(b.entry or b.npcEntry or b.creatureEntry),
                mapId = tonumber(b.mapId),
                nx = tonumber(b.nx),
                ny = tonumber(b.ny),
                guid = b.guid,
                hp = b.hp or b.hpPct,
            }

            if b.status or b.state then
                record.status = b.status or b.state
            elseif b.active ~= nil then
                record.status = b.active and "active" or "inactive"
            elseif b.action == "engage" then
                record.status = "active"
            elseif b.action == "death" or b.action == "despawn" then
                record.status = "inactive"
            else
                record.status = "spawning"
            end

            if b.action == "spawn" then
                record.status = "active"
                record.justSpawnedUntil = now + 60
            end

            StampBossSpawn(record, b.spawnIn or b.timeLeft)

            local index = FindBoss(bosses, record.spawnId, record.entry, record.guid, record.name)
            if index then
                bosses[index] = record
            else
                table.insert(bosses, record)
            end
        end

        self:EnsureDefaultWorldBosses()
    end

    if type(data.events) == "table" then
        for _, e in ipairs(data.events) do
            self:UpsertEvent(e)
        end
    end

    self:ForceUpdateAllPlugins()
end

-- Partial updates: merge into existing state.
function DCInfoBar:HandleWorldUpdate(data)
    if type(data) ~= "table" then
        return
    end
    self.serverData._lastWRLDUpdateAt = Now()

    if type(data.hotspots) == "table" then
        for _, h in ipairs(data.hotspots) do
            self:UpsertHotspot(h)
        end
    end

    if type(data.bosses) == "table" then
        if self.db and self.db.debug then
            self.serverData._lastWRLDBossUpdateSummary = SummarizeBosses(data.bosses)
        end

        local bosses = self.serverData.worldBosses
        local now = Now()

        for _, b in ipairs(data.bosses) do
            local spawnId = tonumber(b.spawnId)
            local entry = tonumber(b.entry or b.npcEntry or b.creatureEntry)
            local up = {
                spawnId = spawnId,
                entry = entry,
                status = b.status or b.state,
                zone = b.zone or b.zoneName,
                name = b.name,
                lastThreshold = b.threshold,
                hp = b.hpPct or b.hp,
            }

            if b.action == "engage" then
                up.status = "active"
            elseif b.action == "spawn" then
                up.status = "active"
                up.justSpawnedUntil = now + 60
            elseif b.action == "death" or b.action == "remove" or b.action == "despawn" then
                up.status = "inactive"
            end

            local _, ex = FindBoss(bosses, spawnId, entry, b.guid, b.name)
            if not ex then
                ex = { name = b.name or entry or "Unknown", guid = b.guid }
                table.insert(bosses, ex)
            end
            for k, v in pairs(up) do
                ex[k] = v
            end
            if up.status == "inactive" then
                ex.justSpawnedUntil = nil
            end
            StampBossSpawn(ex, b.spawnIn or b.timeLeft)
        end

        self:EnsureDefaultWorldBosses()
    end

    if type(data.events) == "table" then
        for _, e in ipairs(data.events) do
            self:UpsertEvent(e)
        end
    end

    self:ForceUpdateAllPlugins()
end

-- ============================================================================
-- Periodic timers (1 Hz, driven from OnUpdate)
-- ============================================================================

-- Derives every legacy "seconds remaining" field from its local-clock anchor so
-- countdowns stay correct for DC-InfoBar and for addons that read serverData.
function DCInfoBar:TickServerTimers()
    local now = Now()
    local sd = self.serverData

    local season = sd.season
    if season._endsAt then
        season.endsIn = math.max(0, season._endsAt - now)
    end
    if season._weeklyResetAt then
        season.weeklyReset = math.max(0, season._weeklyResetAt - now)
    end

    local affixes = sd.affixes
    if affixes._resetAt then
        affixes.resetIn = math.max(0, affixes._resetAt - now)
    end

    for _, b in ipairs(sd.worldBosses) do
        if b.spawnAt then
            b.spawnIn = math.max(0, b.spawnAt - now)
        end
    end

    local events = sd.events
    for i = #events, 1, -1 do
        local e = events[i]
        if e.hideAt and now >= e.hideAt then
            table.remove(events, i)
        elseif e.endsAt then
            e.timeRemaining = math.max(0, math.floor(e.endsAt - now + 0.5))
        end
    end

    local hotspots = sd.hotspots
    for i = #hotspots, 1, -1 do
        local h = hotspots[i]
        if h.expiresAt then
            local left = h.expiresAt - now
            if left <= 0 then
                table.remove(hotspots, i)
            else
                h.timeRemaining = math.floor(left)
            end
        end
    end
end

-- ============================================================================
-- Requests
-- ============================================================================

-- opts.retries     : how often to retry while the protocol isn't connected yet
-- opts.missingOnly : only ask for categories that haven't answered yet
-- opts.force       : bypass the 1 s throttle
function DCInfoBar:RequestServerData(opts)
    opts = (type(opts) == "table") and opts or {}
    local retries = tonumber(opts.retries) or 0

    local proto = self:GetProtocol()
    if not proto then
        self:Debug("DCAddonProtocol not available for RequestServerData")
        return
    end
    self:SetupServerCommunication()

    -- Early requests before the handshake completes can be dropped.
    if proto.IsConnected and not proto:IsConnected() then
        if retries > 0 then
            self:After(2, function()
                DCInfoBar:RequestServerData({ retries = retries - 1, missingOnly = opts.missingOnly })
            end)
        else
            self:Debug("RequestServerData: DCAddonProtocol not connected (giving up)")
        end
        return
    end

    local now = Now()
    if not opts.force and self._lastServerDataRequestAt and (now - self._lastServerDataRequestAt) < 1 then
        return
    end
    self._lastServerDataRequestAt = now

    local sd = self.serverData
    local missingOnly = opts.missingOnly

    if not missingOnly or not sd.season._infoReceived then
        proto:Request("SEAS", SEAS_CMSG_GET_CURRENT, {})
    end
    if not missingOnly or not sd.season._progressReceived then
        proto:Request("SEAS", SEAS_CMSG_GET_PROGRESS, {})
    end
    if not missingOnly or not sd.keystone.received then
        proto:Request("MPLUS", MPLUS_CMSG_GET_KEY_INFO, {})
    end
    if not missingOnly or not sd.affixes.received then
        proto:Request("MPLUS", MPLUS_CMSG_GET_AFFIXES, {})
    end
    if not missingOnly or not sd.prestige.received then
        proto:Request("PRES", PRES_CMSG_GET_INFO, {})
    end
    -- The server pushes the WRLD snapshot after the handshake; only ask when
    -- it hasn't arrived (e.g. /reload, where no new handshake happens).
    if not sd._lastWRLDContentAt then
        proto:Request("WRLD", WRLD_CMSG_GET_CONTENT, {})
    end

    -- One follow-up pass for anything that didn't answer (dropped early packet).
    if not missingOnly then
        self:After(10, function()
            DCInfoBar:RequestServerData({ missingOnly = true, force = true })
        end)
    end
end

-- Ask the server for weekly season progress again (e.g. after tokens changed).
function DCInfoBar:RequestSeasonProgress()
    local proto = self:GetProtocol()
    if proto then
        proto:Request("SEAS", SEAS_CMSG_GET_PROGRESS, {})
    end
end

-- ============================================================================
-- Mythic+ affixes
-- ============================================================================

-- Client-side affix descriptors from WotLK-Extensions (custom DBC), keyed by id.
-- Gives names/descriptions/icons without a server round-trip or GetSpellInfo
-- guessing. nil when the DLL doesn't expose the table.
function DCInfoBar:GetNativeAffix(id)
    id = tonumber(id)
    if not id then
        return nil
    end

    if self._nativeAffixes == nil then
        self._nativeAffixes = false
        local fn = rawget(_G, "GetDCMythicPlusAffixes")
        if type(fn) == "function" then
            local ok, rows = pcall(fn)
            if ok and type(rows) == "table" then
                local byId = {}
                for _, row in ipairs(rows) do
                    if type(row) == "table" and tonumber(row.id) then
                        byId[tonumber(row.id)] = row
                    end
                end
                self._nativeAffixes = byId
            end
        end
    end

    return self._nativeAffixes and self._nativeAffixes[id] or nil
end

-- Best display name for an affix id: server name > native DBC > spell name > id.
function DCInfoBar:ResolveAffixName(id, serverName)
    if serverName and serverName ~= "" then
        return serverName
    end
    local native = self:GetNativeAffix(id)
    if native and native.name and native.name ~= "" then
        return native.name
    end
    id = tonumber(id)
    if id and id > 0 and GetSpellInfo then
        local spellName = GetSpellInfo(id)
        if spellName then
            return spellName
        end
    end
    return tostring(id or "Unknown")
end

local function NormalizeAffixPayload(data)
    local out = { ids = {}, names = {}, descriptions = {}, icons = {}, resetIn = 0 }

    local function Add(id, name, desc)
        id = tonumber(id) or 0
        local native = DCInfoBar:GetNativeAffix(id)
        local n = #out.ids + 1
        out.ids[n] = id
        out.names[n] = DCInfoBar:ResolveAffixName(id, name)
        out.descriptions[n] = (desc and desc ~= "") and desc or (native and native.description) or nil
        out.icons[n] = native and native.icon or nil
    end

    if type(data) == "table" then
        if type(data.affixes) == "table" then
            for _, affix in ipairs(data.affixes) do
                if type(affix) == "table" then
                    Add(affix.id or affix.spellId or affix.spellID or affix.affixId,
                        affix.name or affix.affixName or affix.spellName,
                        affix.description or affix.affixDesc or affix.desc)
                elseif tonumber(affix) then
                    Add(affix)
                elseif type(affix) == "string" then
                    Add(0, affix)
                end
            end
        elseif data.affixIds or data.ids then
            local ids = data.affixIds or data.ids
            local names = data.affixNames or data.names or {}
            local descs = data.descriptions or data.descs or {}
            for i, id in ipairs(ids) do
                Add(id, names[i], descs[i])
            end
        elseif type(data.affixData) == "string" then
            return NormalizeAffixPayload(data.affixData)
        end
        out.resetIn = tonumber(data.resetIn or data.reset) or 0
    elseif type(data) == "string" then
        -- "id:name:desc;id:name:desc"
        for entry in data:gmatch("[^;]+") do
            local idStr, name, desc = entry:match("^(%d+):([^:]*):?(.*)$")
            if idStr then
                Add(idStr, name, desc)
            elseif entry ~= "" then
                Add(0, entry)
            end
        end
    end

    return out
end

function DCInfoBar:HandleAffixData(data)
    if not data then
        return
    end

    local affixes = NormalizeAffixPayload(data)
    affixes.received = true
    affixes._resetAt = Deadline(affixes.resetIn)
    self.serverData.affixes = affixes
    self:NotifyPlugin("DCInfoBar_Affixes", affixes)
end

function DCInfoBar:ImportMythicPlusAffixCache()
    local hudDb = rawget(_G, "DCMythicPlusHUDDB")
    local cache = hudDb and hudDb.cache or nil
    if cache and type(cache.affixes) == "table" and #cache.affixes > 0 then
        self:HandleAffixData({ affixes = cache.affixes })
        -- A cache import is not a server answer; still ask the server.
        self.serverData.affixes.received = nil
    end
end

-- ============================================================================
-- Season
-- ============================================================================

-- Convenience getters for other addons/scripts to query current season token values
function DCInfoBar:GetWeeklyTokens()
    return self.serverData.season.weeklyTokens or 0
end

function DCInfoBar:GetInventoryTokens()
    return self.serverData.season.totalTokens or 0
end

-- Push currency ids/balance to DCAddonProtocol's shared cache. The balance is
-- only pushed once a progress reply (the only message that carries it) arrived,
-- so a late season-info reply can never zero it.
function DCInfoBar:SyncSeasonCurrency()
    local central = self:GetProtocol()
    local season = self.serverData.season
    if not central then
        return
    end
    if (season.tokenId or 0) > 0 then
        central.TOKEN_ITEM_ID = season.tokenId
    end
    if (season.essenceId or 0) > 0 then
        central.ESSENCE_ITEM_ID = season.essenceId
    end
    if season._progressReceived and type(central.SetServerCurrencyBalance) == "function" then
        central:SetServerCurrencyBalance(season.totalTokens or 0, season.totalEssence or 0)
    end
end

local function ApplySeasonFields(season, data)
    local id = tonumber(data.seasonId or data.id)
    if id then season.id = id end

    local name = data.seasonName or data.name
    if name and name ~= "" then season.name = name end

    season.tokenId = tonumber(data.tokenId or data.tokenID) or season.tokenId
    season.essenceId = tonumber(data.essenceId or data.essenceID) or season.essenceId
    season.weeklyCap = tonumber(data.tokenCap or data.weeklyCap) or season.weeklyCap
    season.essenceCap = tonumber(data.essenceCap) or season.essenceCap

    if data.endsIn ~= nil then
        season.endsIn = tonumber(data.endsIn) or 0
        season._endsAt = Deadline(season.endsIn)
    end
    if data.weeklyReset ~= nil then
        season.weeklyReset = tonumber(data.weeklyReset) or 0
        season._weeklyResetAt = Deadline(season.weeklyReset)
    end
end

-- SMSG_CURRENT (0x10): season metadata. Carries no balances.
function DCInfoBar:HandleSeasonData(data)
    if type(data) ~= "table" then
        return
    end

    local season = self.serverData.season
    ApplySeasonFields(season, data)
    season._infoReceived = true

    self:SyncSeasonCurrency()
    self:NotifyPlugin("DCInfoBar_Season", season)
    self:Debug("Season data received: " .. tostring(season.name))
end

-- SMSG_PROGRESS (0x12): weekly progress and inventory balances.
function DCInfoBar:HandleSeasonProgressData(data)
    if type(data) ~= "table" then
        return
    end

    local season = self.serverData.season
    ApplySeasonFields(season, data)

    season.weeklyTokens = tonumber(data.weeklyTokens) or season.weeklyTokens
    season.weeklyEssence = tonumber(data.weeklyEssence) or season.weeklyEssence
    -- 'tokens'/'essence' are the current inventory counts.
    season.totalTokens = tonumber(data.tokens or data.totalTokens) or season.totalTokens
    season.totalEssence = tonumber(data.essence or data.totalEssence) or season.totalEssence
    season._progressReceived = true

    self:SyncSeasonCurrency()
    self:NotifyPlugin("DCInfoBar_Season", season)
    self:Debug(string.format("Season progress: weeklyTokens=%s totalTokens=%s cap=%s",
        tostring(season.weeklyTokens), tostring(season.totalTokens), tostring(season.weeklyCap)))
end

-- ============================================================================
-- Keystone
-- ============================================================================

-- MPLUS SMSG_KEY_INFO. Current servers send JSON (hasKey, dungeonId, dungeonName,
-- level, depleted, weeklyBest, seasonBest); older ones sent the pipe form
-- "hasKey|dungeonId|dungeonName|level|depleted", which is still accepted.
function DCInfoBar:HandleKeystoneData(first, ...)
    local data = first
    if type(first) ~= "table" then
        local dungeonId, dungeonName, level, depleted = ...
        data = {
            hasKey = (first == "1" or first == 1),
            dungeonId = dungeonId,
            dungeonName = dungeonName,
            level = level,
            depleted = (depleted == "1" or depleted == 1 or depleted == "true"),
        }
    end

    local ks = self.serverData.keystone
    local level = tonumber(data.level or data.keyLevel or data.keystoneLevel) or 0
    local hasKey = data.hasKey
    if hasKey == nil then
        hasKey = data.hasKeystone
    end
    if hasKey == nil then
        hasKey = level > 0
    end
    hasKey = (hasKey and level > 0) and true or false

    ks.received = true
    ks.hasKey = hasKey
    ks.level = hasKey and level or 0
    ks.dungeonId = hasKey and (tonumber(data.dungeonId or data.keystoneDungeonId or data.mapId) or 0) or 0
    ks.dungeonName = hasKey and (data.dungeonName or data.keystoneDungeonName or data.name or "Unknown") or "None"
    ks.dungeonAbbrev = hasKey and (data.abbreviation or data.abbrev or self:GenerateDungeonAbbrev(ks.dungeonName)) or ""
    ks.depleted = hasKey and (data.depleted == true) or false
    ks.weeklyBest = tonumber(data.weeklyBest) or ks.weeklyBest or 0
    ks.seasonBest = tonumber(data.seasonBest) or ks.seasonBest or 0

    self:NotifyPlugin("DCInfoBar_Keystone", ks)
    self:Debug("Keystone data received: +" .. tostring(ks.level) .. " " .. tostring(ks.dungeonAbbrev))
end

-- Centralized dungeon abbreviation lookup (single source of truth)
DCInfoBar.DUNGEON_ABBREVS = DCInfoBar.DUNGEON_ABBREVS or {
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

-- Generate dungeon abbreviation from name
function DCInfoBar:GenerateDungeonAbbrev(name)
    if not name or name == "" then return "" end
    
    -- Use centralized lookup
    if self.DUNGEON_ABBREVS[name] then
        return self.DUNGEON_ABBREVS[name]
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

-- =========================================================================
-- Server Restart/Shutdown Tracking
-- =========================================================================

local function _EscapePattern(s)
    return (s or ""):gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
end

local function _BuildMessagePattern(template)
    if not template or template == "" then
        return nil
    end
    local tokenS = "__DCINFOBAR_TOKEN_S__"
    local tokenD = "__DCINFOBAR_TOKEN_D__"

    local pattern = template
    pattern = pattern:gsub("%%s", tokenS)
    pattern = pattern:gsub("%%d", tokenD)
    pattern = _EscapePattern(pattern)
    pattern = pattern:gsub(tokenS, "(.+)")
    pattern = pattern:gsub(tokenD, "(%%d+)")
    return "^" .. pattern .. "$"
end

function DCInfoBar:BuildServerMessagePatterns()
    if self._serverMsgPatterns then return end

    local shutdownTemplate = SERVER_SHUTDOWN_TIMELEFT or "Server shutdown in %s"
    local restartTemplate = SERVER_RESTART_TIMELEFT or "Server restart in %s"
    local shutdownCancel = SERVER_SHUTDOWN_CANCELLED or "Server shutdown cancelled."
    local restartCancel = SERVER_RESTART_CANCELLED or "Server restart cancelled."

    self._serverMsgPatterns = {
        shutdown = _BuildMessagePattern(shutdownTemplate),
        restart = _BuildMessagePattern(restartTemplate),
        shutdownCancel = _BuildMessagePattern(shutdownCancel),
        restartCancel = _BuildMessagePattern(restartCancel),
    }
end

function DCInfoBar:ParseTimeStringToSeconds(timeStr)
    if not timeStr or timeStr == "" then return nil end
    timeStr = tostring(timeStr)

    local h, m, s = timeStr:match("^(%d+):(%d%d):(%d%d)$")
    if h and m and s then
        return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
    end

    local m2, s2 = timeStr:match("^(%d+):(%d%d)$")
    if m2 and s2 then
        return tonumber(m2) * 60 + tonumber(s2)
    end

    local total = 0
    local found = false
    for num, unit in timeStr:gmatch("(%d+)%s*([%a]+)") do
        found = true
        local n = tonumber(num) or 0
        unit = string.lower(unit or "")
        if unit:find("day") then
            total = total + n * 86400
        elseif unit:find("hour") then
            total = total + n * 3600
        elseif unit:find("min") then
            total = total + n * 60
        elseif unit:find("sec") then
            total = total + n
        end
    end

    if found then
        return total
    end
    return nil
end

function DCInfoBar:HandleSystemMessage(msg)
    if not msg or msg == "" then return end

    self:BuildServerMessagePatterns()
    local patterns = self._serverMsgPatterns or {}

    if patterns.shutdownCancel and msg:match(patterns.shutdownCancel) then
        self:CancelServerCountdown("shutdown")
        return
    end
    if patterns.restartCancel and msg:match(patterns.restartCancel) then
        self:CancelServerCountdown("restart")
        return
    end

    local lowerMsg = string.lower(msg)
    if lowerMsg:find("cancel") then
        if lowerMsg:find("restart") then
            self:CancelServerCountdown("restart")
            return
        elseif lowerMsg:find("shutdown") then
            self:CancelServerCountdown("shutdown")
            return
        end
    end

    local baseMsg = msg
    local reason = nil
    local left, right = msg:match("^(.-)%s%-%s(.+)$")
    if left and right then
        baseMsg = left
        reason = right
    end

    local timeStr = nil
    local mode = nil

    if patterns.restart then
        timeStr = baseMsg:match(patterns.restart)
        if timeStr then
            mode = "restart"
        end
    end

    if not timeStr and patterns.shutdown then
        timeStr = baseMsg:match(patterns.shutdown)
        if timeStr then
            mode = "shutdown"
        end
    end

    if not timeStr then
        local lower = string.lower(baseMsg)
        if lower:find("restart") then
            mode = "restart"
        elseif lower:find("shutdown") then
            mode = "shutdown"
        end
        if mode then
            timeStr = baseMsg:match("in%s+(.+)")
        end
    end

    if not timeStr or not mode then
        return
    end

    local seconds = self:ParseTimeStringToSeconds(timeStr)
    if not seconds then
        return
    end

    self:UpdateServerCountdown(mode, seconds, reason)
end

function DCInfoBar:UpdateServerCountdown(mode, seconds, reason)
    if not self.serverData or not self.serverData.restartStatus then return end

    local status = self.serverData.restartStatus
    local now = GetTime and GetTime() or 0
    local prevMode = status.mode

    status.active = true
    status.mode = mode
    status.remaining = seconds
    status.reason = reason
    status.lastUpdateAt = now

    if not status.total or status.total <= 0 or seconds > status.total or prevMode ~= mode then
        status.total = seconds
    end
end

function DCInfoBar:CancelServerCountdown(mode)
    if not self.serverData or not self.serverData.restartStatus then return end

    local status = self.serverData.restartStatus
    status.active = false
    status.mode = mode or status.mode
    status.remaining = 0
    status.total = 0
    status.reason = nil
    status.lastUpdateAt = 0

    if self.bar and self.bar.restartGauge then
        self.bar.restartGauge:Hide()
    end
end

function DCInfoBar:UpdateRestartGauge(elapsed)
    if not self.bar or not self.bar.restartGauge or not self.serverData or not self.serverData.restartStatus then
        return
    end

    local status = self.serverData.restartStatus
    if not status.active or not status.remaining or status.remaining <= 0 then
        self.bar.restartGauge:Hide()
        return
    end

    status.remaining = math.max(0, (status.remaining or 0) - (elapsed or 0))
    if status.remaining <= 0 then
        status.active = false
        self.bar.restartGauge:Hide()
        return
    end

    local total = tonumber(status.total) or 0
    if total <= 0 then total = status.remaining end

    local perc = 0
    if total > 0 then
        perc = status.remaining / total
    end

    local r, g, b = self:ColorGradient(perc, 1, 0.2, 0.2, 1, 0.8, 0.2, 0.2, 1, 0.2)

    local gauge = self.bar.restartGauge
    gauge:SetMinMaxValues(0, total)
    gauge:SetValue(status.remaining)
    gauge:SetStatusBarColor(r, g, b, 0.9)

    -- The gauge ticks at 10 Hz; only re-render the text when the second changes.
    local wholeSeconds = math.floor(status.remaining)
    if gauge._shownSeconds ~= wholeSeconds or gauge._shownMode ~= status.mode then
        gauge._shownSeconds = wholeSeconds
        gauge._shownMode = status.mode
        local label = (status.mode == "restart") and "Server Restart" or "Server Shutdown"
        gauge.text:SetText(label .. " - " .. self:FormatTime(status.remaining))
    end
    gauge:Show()
end

function DCInfoBar:ShowRestartGaugeTooltip(frame)
    if not frame or not self.serverData or not self.serverData.restartStatus then return end
    local status = self.serverData.restartStatus
    if not status.active then return end

    GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
    local title = (status.mode == "restart") and "Server Restart" or "Server Shutdown"
    GameTooltip:AddLine(title, 1, 1, 1)
    GameTooltip:AddDoubleLine("Time Remaining", self:FormatTime(status.remaining), 0.8, 0.8, 0.8, 1, 1, 1)
    if time and date then
        local now = time()
        local rebootAt = date("%H:%M:%S", now + math.floor(status.remaining or 0))
        GameTooltip:AddDoubleLine("Reboot At (Local)", rebootAt, 0.8, 0.8, 0.8, 1, 1, 1)
    end
    if status.reason and status.reason ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Reason: " .. status.reason, 1, 0.82, 0)
    end
    GameTooltip:Show()
end

-- ============================================================================
-- Visibility
-- ============================================================================

function DCInfoBar:ShouldShowBar()
    local g = self.db and self.db.global
    if not g or not g.enabled then
        return false
    end
    if g.hideInCombat and self._inCombat then
        return false
    end
    if g.hideInInstance and IsInInstance and IsInInstance() then
        return false
    end
    return true
end

-- Applies the enabled/combat/instance rules. Only acts when the wanted state
-- changes (or force is set), so a hide requested by another addon (e.g. the
-- DC-Welcome addon panel) is not undone on the next frame.
function DCInfoBar:UpdateVisibility(force)
    if not self.bar then
        return
    end

    local show = self:ShouldShowBar()
    if not force and show == self._barWantedShown then
        return
    end
    self._barWantedShown = show

    if show then
        self.bar:Show()
        self:ForceUpdateAllPlugins()
    else
        self.bar:Hide()
    end
end

-- ============================================================================
-- Update System
-- ============================================================================

function DCInfoBar:RunPluginUpdate(plugin, now)
    -- Real time since this plugin last updated. Plugins force an early redraw by
    -- setting _elapsed = 999, so the accumulator can't be used as a delta.
    local dt = now - (plugin._lastUpdateAt or now)
    plugin._lastUpdateAt = now

    local ok, label, value, color = pcall(plugin.OnUpdate, plugin, dt)
    if ok then
        self.bar:UpdatePluginText(plugin, label, value, color)
    elseif self.db and self.db.debug then
        self:Debug("Plugin " .. tostring(plugin.id) .. " OnUpdate error: " .. tostring(label))
    end
end

function DCInfoBar:OnUpdate(elapsed)
    if not self.db or not self.bar then
        return
    end

    -- Server countdowns keep running while the bar is hidden: other addons read them.
    self._timerElapsed = (self._timerElapsed or 0) + elapsed
    if self._timerElapsed >= 1 then
        self._timerElapsed = 0
        self:TickServerTimers()
    end

    self:UpdateRestartGauge(elapsed)

    if not self.bar:IsShown() then
        return
    end

    local now = GetTime()
    for _, side in ipairs(SIDES) do
        for _, plugin in ipairs(self.activePlugins[side]) do
            if plugin.button and plugin.OnUpdate then
                plugin._elapsed = (plugin._elapsed or 0) + elapsed
                if plugin._elapsed >= (plugin.updateInterval or 1.0) then
                    plugin._elapsed = 0
                    self:RunPluginUpdate(plugin, now)
                end
            end
        end
    end
end

function DCInfoBar:ForceUpdateAllPlugins()
    if not self.bar then
        return
    end

    local now = GetTime()
    for _, side in ipairs(SIDES) do
        for _, plugin in ipairs(self.activePlugins[side]) do
            if plugin.button and plugin.OnUpdate then
                plugin._elapsed = 0
                self:RunPluginUpdate(plugin, now)
            end
        end
    end
end

-- ============================================================================
-- Initialization
-- ============================================================================

function DCInfoBar:Initialize()
    local function SafeStep(label, fn)
        local ok, err = xpcall(fn, function(e)
            local trace = debugstack and debugstack(2, 8, 8) or ""
            return tostring(e) .. (trace ~= "" and (" | " .. trace) or "")
        end)
        if not ok then
            self:Print("Init ERROR in " .. label .. ": " .. tostring(err))
        end
        return ok
    end

    SafeStep("InitializeTokenInfo", function() self:InitializeTokenInfo() end)
    SafeStep("InitializeDB", function() self:InitializeDB() end)
    SafeStep("SetupServerCommunication", function() self:SetupServerCommunication() end)
    SafeStep("ImportMythicPlusAffixCache", function() self:ImportMythicPlusAffixCache() end)

    SafeStep("CreateBar", function()
        if self.CreateBar then
            self.bar = self:CreateBar()
        else
            self:Print("Init: CreateBar() missing - UI/Bar.lua not loaded?")
        end
    end)

    SafeStep("CreateOptionsPanel", function()
        if self.CreateOptionsPanel and not self.optionsPanel then
            self:CreateOptionsPanel()
        end
    end)

    SafeStep("ActivatePlugins", function()
        for id in pairs(self.plugins) do
            if self:IsPluginEnabled(id) then
                self:ActivatePlugin(id)
            end
        end
        self:Debug(string.format("Init: active plugins left=%d right=%d",
            #self.activePlugins.left, #self.activePlugins.right))
    end)

    SafeStep("UpdateFrame", function()
        local updateFrame = CreateFrame("Frame")
        self._updateFrame = updateFrame
        local updateElapsed = 0
        updateFrame:SetScript("OnUpdate", function(_, elapsed)
            updateElapsed = updateElapsed + elapsed
            if updateElapsed >= 0.1 then  -- 10 Hz max
                DCInfoBar:OnUpdate(updateElapsed)
                updateElapsed = 0
            end
        end)

        self._inCombat = UnitAffectingCombat("player") and true or false
        self:UpdateVisibility(true)
        if self.bar then
            self.bar:RefreshLayout()
        end
    end)

    -- Short delay so the protocol handshake has a chance to complete.
    self:After(2, function()
        DCInfoBar:RequestServerData({ retries = 10 })
    end)

    self:SetupSlashCommands()

    -- Debug-only: PrintToDcDebug would open a new chat tab on clients without DC-QOS.
    self:Debug("DC-InfoBar v" .. self.VERSION .. " loaded. Type /infobar for options.")
end

-- ============================================================================
-- Slash Commands
-- ============================================================================

function DCInfoBar:SetupSlashCommands()
    SLASH_DCINFOBAR1 = "/infobar"
    SLASH_DCINFOBAR2 = "/dcinfo"
    SLASH_DCINFOBAR3 = "/dcib"

    SlashCmdList["DCINFOBAR"] = function(msg)
        msg = msg or ""
        local cmd = string.lower(msg:match("^(%S*)") or "")

        if cmd == "" or cmd == "options" or cmd == "config" then
            self:OpenOptions()
        elseif cmd == "toggle" then
            self.db.global.enabled = not self.db.global.enabled
            self:UpdateVisibility(true)
            self:Print("InfoBar " .. (self.db.global.enabled and "enabled" or "disabled"))
        elseif cmd == "reset" then
            self:ResetToDefaults()
        elseif cmd == "debug" then
            self.db.debug = not self.db.debug
            self.db.communication.showDebugMessages = self.db.debug
            self:Print("Debug mode " .. (self.db.debug and "enabled" or "disabled"))
        elseif cmd == "refresh" then
            self:RequestServerData({ force = true })
            self:Print("Refreshing server data...")
        elseif cmd == "testevent" then
            self:Print("Injecting test event...")
            self:HandleEventData({
                id = 999,
                name = "Test Invasion",
                zone = "Giant Isles",
                type = "invasion",
                state = "active",
                active = true,
                wave = 2,
                maxWaves = 4,
                enemiesRemaining = 15,
                timeRemaining = 300,
            })
            self:Print("Event count: " .. #self.serverData.events)
        elseif cmd == "events" then
            local events = self.serverData.events
            self:Print("Active events: " .. #events)
            for i, event in ipairs(events) do
                self:Print(string.format("  %d: %s (%s) - %s", i, tostring(event.name), tostring(event.zone), tostring(event.state)))
            end
        elseif cmd == "showevent" then
            self:SetPluginSetting("DCInfoBar_Events", "hideWhenNone", false)
            self:Print("Event display forced ON (hideWhenNone disabled)")
            self:RefreshAllPlugins()
        elseif cmd == "hideevent" then
            self:SetPluginSetting("DCInfoBar_Events", "hideWhenNone", true)
            self:Print("Event display restored to normal (hideWhenNone enabled)")
            self:RefreshAllPlugins()
        elseif cmd == "testseason" then
            local weekly, total, id = msg:match("^%S+%s+(%d+)%s*(%d*)%s*(%d*)")
            local payload = {
                seasonId = tonumber(id) or 1,
                tokens = tonumber(total) or 0,
                weeklyTokens = tonumber(weekly) or 0,
                tokenCap = 1000,
                essence = 0,
                weeklyEssence = 0,
                essenceCap = 1000,
            }
            self:HandleSeasonProgressData(payload)
            self:Print("Injected test season payload: weeklyTokens=" .. payload.weeklyTokens .. ", totalTokens=" .. payload.tokens)
        elseif cmd == "showseason" then
            local s = self.serverData.season
            self:Print(string.format("Season ID: %s, Name: %s, weeklyTokens: %s, tokens: %s, weeklyCap: %s, essence: %s",
                tostring(s.id), tostring(s.name), tostring(s.weeklyTokens), tostring(s.totalTokens),
                tostring(s.weeklyCap), tostring(s.weeklyEssence)))
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
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        DCInfoBar:After(0.5, function()
            xpcall(function()
                DCInfoBar:Initialize()
            end, function(e)
                local trace = debugstack and debugstack(2, 8, 8) or ""
                DCInfoBar:Print("Init ERROR (top-level): " .. tostring(e) .. (trace ~= "" and (" | " .. trace) or ""))
            end)
        end)
    elseif event == "PLAYER_REGEN_DISABLED" then
        DCInfoBar._inCombat = true
        DCInfoBar:UpdateVisibility()
    elseif event == "PLAYER_REGEN_ENABLED" then
        DCInfoBar._inCombat = false
        DCInfoBar:UpdateVisibility()
    elseif event == "PLAYER_ENTERING_WORLD" then
        DCInfoBar._inCombat = UnitAffectingCombat("player") and true or false
        DCInfoBar:UpdateVisibility()
        local location = DCInfoBar.plugins["DCInfoBar_Location"]
        if location then
            location._elapsed = 999  -- Force update
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        DCInfoBar:HandleSystemMessage((...))
    end
end)

-- Register protocol handlers now (DC-AddonProtocol is a hard dependency and is
-- already loaded) so no push that arrives before PLAYER_LOGIN is lost.
DCInfoBar:SetupServerCommunication()
