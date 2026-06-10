local addonName, addonTable = ...
addonTable = addonTable or {}

local Pins = addonTable.Pins or {}
local UI = addonTable.UI or {}
local Debug = _G.DC_DebugUtils

-- Server communication runs over DCAddonProtocol (native bridge or addon whisper)
local DC = rawget(_G, "DCAddonProtocol")

local Core = {}
addonTable.Core = Core

-- Protocol availability flags
Core.useDCProtocol = (DC ~= nil)
Core.protocolMode = DC and "DCAddonProtocol" or "None"

local function RefreshProtocolMode()
    DC = rawget(_G, "DCAddonProtocol")
    Core.useDCProtocol = (DC ~= nil)
    Core.protocolMode = DC and "DCAddonProtocol" or "None"
end

local state = {
    addonName = addonName,
    hotspots = {},
    config = {
        experienceBonus = 100,
    },
    sessionStart = GetTime(),
    lastPlayerPos = nil,
    suppressAnnouncements = true,  -- Suppress announcements during initial load
}
addonTable.state = state
Core.state = state

local function DebugPrint(...)
    if Debug and Debug.PrintMulti then
        Debug:PrintMulti("DC-Mapupgrades", (state.db and state.db.debug) or false, ...)
    elseif state.db and state.db.debug and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[DC-Mapupgrades]|r " .. table.concat({...}, " "))
    end
end

local function NowEpoch()
    if GetServerTime then
        return GetServerTime()
    end
    return time()
end

local defaults = {
    version = 1,
    showMinimapPins = true,
    showWorldPins = true,
    showWorldLabels = true,
    showPopup = true,
    popupDuration = 4,
    announce = true,
    announceExpire = true,
    showListOnLogin = false,
    spawnSound = nil,
    expireSound = nil,
    debug = false,
    cache = {},
    lockWorldMap = true,
    pinIconStyle = "xp",  -- Default to golden orb (XP themed)
    customIconTexture = "",
    useDCProtocolJSON = true,  -- Use JSON format when available

    -- Reduce chat spam when crossing hotspot boundaries while moving.
    -- Debounce waits before printing; cooldown prevents repeated prints.
    suppressHotspotChatSpam = true,
    hotspotChatDebounceSeconds = 3,
    hotspotChatCooldownSeconds = 15,

    -- Map view id -> server zone id learned at runtime (helps custom maps where clients report odd ids)
    customZoneMapping = {},

    -- Entity pins (world bosses / rares)
    showWorldBossPins = true,
    showMinimapBossPins = false,
    showRarePins = true,
    entityActiveDuration = 900, -- seconds to consider an entity "active" after being seen
    entities = { nextId = 1000000, list = {} },
    entityStatus = {},
    
    -- Blacklist maps from showing boss pins (e.g., custom zones without real bosses)
    -- Keep server map ID here; client map IDs are handled by name-based blacklist.
    bossBlacklistMaps = { [745] = true },
}

local function EnsureEntityTables(db)
    if not db then return end
    if type(db.entities) ~= "table" then
        db.entities = { nextId = 1000000, list = {} }
    end
    if type(db.entities.list) ~= "table" then
        db.entities.list = {}
    end
    if type(db.entities.nextId) ~= "number" then
        db.entities.nextId = 1000000
    end
    if type(db.entityStatus) ~= "table" then
        db.entityStatus = {}
    end
end

local function NormalizeNameForMatch(name)
    if not name then return nil end
    name = tostring(name)
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end
    return name:lower()
end

local function GetDCInfoBar()
    return rawget(_G, "DCInfoBar")
end

local function BossIsActiveFromInfoBarRecord(boss)
    if type(boss) ~= "table" then
        return false
    end
    local now = (GetTime and GetTime()) or 0
    local st = string.lower(tostring(boss.status or boss.state or ""))
    if st == "active" then
        local hpPct = tonumber(boss.hp)
        if hpPct ~= nil and hpPct <= 0 then
            return false
        end
        return true
    end
    if boss.justSpawnedUntil and now < tonumber(boss.justSpawnedUntil) then
        return true
    end
    if boss.active == true then
        return true
    end
    return false
end

local function BossIsInactiveFromInfoBarRecord(boss)
    if type(boss) ~= "table" then
        return false
    end
    local st = string.lower(tostring(boss.status or boss.state or ""))
    if st == "inactive" then
        return true
    end
    if boss.active == false then
        return true
    end
    local hpPct = tonumber(boss.hp)
    if hpPct ~= nil and hpPct <= 0 then
        return true
    end
    return false
end

local function GetPlayerMapPosNormalized(lockWorldMap)
    local worldMapShown = WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown()
    local mapId

    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        mapId = C_Map.GetBestMapForUnit("player")
        if mapId then
            local pos = C_Map.GetPlayerMapPosition(mapId, "player")
            if pos and pos.x and pos.y and pos.x > 0 and pos.y > 0 then
                return pos.x, pos.y, mapId
            end
        end
    end

    if GetPlayerMapPosition then
        if SetMapToCurrentZone and not worldMapShown and lockWorldMap then
            pcall(SetMapToCurrentZone)
        end
        local x, y = GetPlayerMapPosition("player")
        if x and y and x > 0 and y > 0 then
            if GetCurrentMapAreaID then
                mapId = GetCurrentMapAreaID()
            end
            return x, y, mapId
        end
    end
    return nil
end

function Core:FindEntityByName(name)
    local db = state.db
    if not db or not db.entities or not db.entities.list then
        return nil
    end
    local needle = NormalizeNameForMatch(name)
    if not needle then return nil end

    for _, ent in ipairs(db.entities.list) do
        if ent and ent.name and NormalizeNameForMatch(ent.name) == needle then
            return ent
        end
    end
    return nil
end

function Core:GetEntityStatus(entityId)
    local db = state.db
    if not db or not db.entityStatus then return nil end
    return db.entityStatus[tonumber(entityId) or entityId]
end

function Core:SetEntityActive(entityId, active, reason)
    if not state.db then return false end
    EnsureEntityTables(state.db)
    local id = tonumber(entityId)
    if not id then return false end

    local st = state.db.entityStatus[id] or {}
    local now = NowEpoch()
    if active then
        local dur = tonumber(state.db.entityActiveDuration) or 900
        st.activeUntil = now + dur
        st.lastSeen = now
        st.lastSeenReason = reason or "manual"
    else
        st.activeUntil = 0
        st.lastKilled = now
        st.lastKilledReason = reason or "manual"
    end
    state.db.entityStatus[id] = st

    if Pins and Pins.Refresh then
        Pins:Refresh()
    end
    return true
end

function Core:AddEntity(kind, name)
    if not state.db then return nil, "settings_not_loaded" end
    EnsureEntityTables(state.db)
    kind = (kind or ""):lower()
    if kind ~= "boss" and kind ~= "rare" then
        return nil, "invalid_kind"
    end

    local trimmed = tostring(name or "")
    trimmed = trimmed:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then
        return nil, "missing_name"
    end

    local nx, ny, mapId = GetPlayerMapPosNormalized(state.db.lockWorldMap)
    if not nx or not ny or not mapId then
        return nil, "no_player_position"
    end

    local id = state.db.entities.nextId
    state.db.entities.nextId = id + 1

    local ent = {
        id = id,
        kind = kind,
        name = trimmed,
        mapId = mapId,
        nx = nx,
        ny = ny,
        entry = nil,
        spawnId = nil,
        zoneLabel = nil,
        created = NowEpoch(),
    }
    table.insert(state.db.entities.list, ent)

    if Pins and Pins.Refresh then
        Pins:Refresh()
    end
    return ent
end

function Core:SetEntityPosition(entityId)
    if not state.db then return false, "settings_not_loaded" end
    EnsureEntityTables(state.db)
    local id = tonumber(entityId)
    if not id then return false, "invalid_id" end

    local nx, ny, mapId = GetPlayerMapPosNormalized(state.db.lockWorldMap)
    if not nx or not ny or not mapId then
        return false, "no_player_position"
    end

    for _, ent in ipairs(state.db.entities.list) do
        if ent and ent.id == id then
            ent.mapId = mapId
            ent.nx = nx
            ent.ny = ny
            if Pins and Pins.Refresh then
                Pins:Refresh()
            end
            return true
        end
    end
    return false, "not_found"
end

function Core:ImportWorldBossesFromInfoBar()
    if not state.db then return 0, "settings_not_loaded" end
    EnsureEntityTables(state.db)

    local info = GetDCInfoBar()
    if not info or type(info.serverData) ~= "table" then
        return 0, "dcinfobar_not_available"
    end

    local bosses = info.serverData.worldBosses
    if type(bosses) ~= "table" then
        return 0, "no_boss_data"
    end

    local added = 0

    local function findBySpawnOrEntryOrName(spawnId, entry, name)
        for _, ent in ipairs(state.db.entities.list) do
            if ent and ent.kind == "boss" then
                if spawnId and ent.spawnId and tonumber(ent.spawnId) == tonumber(spawnId) then
                    return ent
                end
                if entry and ent.entry and tonumber(ent.entry) == tonumber(entry) then
                    return ent
                end
                if name and ent.name and NormalizeNameForMatch(ent.name) == NormalizeNameForMatch(name) then
                    return ent
                end
            end
        end
        return nil
    end

    for _, b in ipairs(bosses) do
        if type(b) == "table" then
            local spawnId = tonumber(b.spawnId) or nil
            local entry = tonumber(b.entry) or nil
            local name = b.name
            local zoneLabel = b.zone
            -- Use zoneId (server area ID) for map matching, NOT mapId (server map ID like 1405)
            -- EntityMatchesMap expects zoneId to match CUSTOM_ZONE_MAPPING values
            local mapId = tonumber(b.zoneId) or tonumber(b.mapId) or nil
            local nx, ny = NormalizePossibleNormalizedPos(b.nx, b.ny)

            local existing = findBySpawnOrEntryOrName(spawnId, entry, name)
            if existing then
                if name and name ~= "" then existing.name = name end
                if zoneLabel and zoneLabel ~= "" then existing.zoneLabel = zoneLabel end
                if spawnId then existing.spawnId = spawnId end
                if entry then existing.entry = entry end

                -- Only fill position if it's missing. Respect manual user positioning.
                if mapId and nx and ny and (not existing.mapId or not existing.nx or not existing.ny) then
                    existing.mapId = mapId
                    existing.nx = nx
                    existing.ny = ny
                end
            else
                local id = state.db.entities.nextId
                state.db.entities.nextId = id + 1
                table.insert(state.db.entities.list, {
                    id = id,
                    kind = "boss",
                    name = name or (entry and tostring(entry)) or (spawnId and tostring(spawnId)) or "World Boss",
                    mapId = mapId,
                    nx = nx,
                    ny = ny,
                    entry = entry,
                    spawnId = spawnId,
                    zoneLabel = zoneLabel,
                    created = NowEpoch(),
                })
                added = added + 1
            end
        end
    end

    if Pins and Pins.Refresh then
        Pins:Refresh()
    end
    return added
end

function Core:SyncWorldBossStatusFromInfoBar()
    if not state.db then return end
    EnsureEntityTables(state.db)

    local info = GetDCInfoBar()
    if not info or type(info.serverData) ~= "table" then
        return
    end
    local bosses = info.serverData.worldBosses
    if type(bosses) ~= "table" then
        return
    end

    -- If the user has no boss entities yet, seed them automatically from DC-InfoBar.
    -- This makes default world boss pins appear without requiring a manual import command.
    if not state._autoImportedBosses then
        local hasBossEntity = false
        for _, ent in ipairs(state.db.entities.list or {}) do
            if ent and ent.kind == "boss" then
                hasBossEntity = true
                break
            end
        end

        if (not hasBossEntity) and #bosses > 0 and Core.ImportWorldBossesFromInfoBar then
            Core:ImportWorldBossesFromInfoBar()
        end
        state._autoImportedBosses = true
    end

    local changed = false
    for _, boss in ipairs(bosses) do
        if type(boss) == "table" then
            local spawnId = tonumber(boss.spawnId) or nil
            local entry = tonumber(boss.entry) or nil
            local name = boss.name

            local matched
            for _, ent in ipairs(state.db.entities.list) do
                if ent and ent.kind == "boss" then
                    if spawnId and ent.spawnId and tonumber(ent.spawnId) == tonumber(spawnId) then
                        matched = ent
                        break
                    end
                    if entry and ent.entry and tonumber(ent.entry) == tonumber(entry) then
                        matched = ent
                        break
                    end
                    if name and ent.name and NormalizeNameForMatch(ent.name) == NormalizeNameForMatch(name) then
                        matched = ent
                        break
                    end
                end
            end

            if matched then
                if BossIsActiveFromInfoBarRecord(boss) then
                    local ok = self:SetEntityActive(matched.id, true, "dcinfobar")
                    if ok then changed = true end
                elseif BossIsInactiveFromInfoBarRecord(boss) then
                    local ok = self:SetEntityActive(matched.id, false, "dcinfobar")
                    if ok then changed = true end
                end
            end
        end
    end

    if changed and Pins and Pins.Refresh then
        Pins:Refresh()
    end
end

function Core:RemoveEntity(entityId)
    if not state.db then return false end
    EnsureEntityTables(state.db)
    local id = tonumber(entityId)
    if not id then return false end

    local list = state.db.entities.list
    for i = #list, 1, -1 do
        if list[i] and list[i].id == id then
            table.remove(list, i)
            break
        end
    end
    if state.db.entityStatus then
        state.db.entityStatus[id] = nil
    end
    if Pins and Pins.Refresh then
        Pins:Refresh()
    end
    return true
end

function Core:ResolveEntityPosition(entityId)
    if not state.db then return false, "settings_not_loaded" end
    EnsureEntityTables(state.db)

    local id = tonumber(entityId)
    if not id then return false, "invalid_id" end

    local ent
    for _, e in ipairs(state.db.entities.list) do
        if e and tonumber(e.id) == id then
            ent = e
            break
        end
    end
    if not ent then return false, "not_found" end

    local spawnId = tonumber(ent.spawnId)
    local entry = tonumber(ent.entry)
    if not spawnId and not entry then
        return false, "missing_spawn_or_entry"
    end

    DC = rawget(_G, "DCAddonProtocol")
    if not (DC and DC.Request) then
        return false, "dcprotocol_not_available"
    end

    local payload = {
        entityId = id,
        spawnId = spawnId,
        entry = entry,
    }

    DC:Request("WRLD", 0x02, payload)
    return true
end

function Core:HandleWorldResolveResult(data)
    if type(data) ~= "table" or not state.db then return end
    EnsureEntityTables(state.db)

    if data.success ~= true then
        local msg = "Resolve failed: " .. tostring(data.error or "unknown")
        DebugPrint(msg)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[DC-Mapupgrades]|r " .. msg)
        end
        return
    end

    local entityId = tonumber(data.entityId)
    local spawnId = tonumber(data.spawnId)
    local entry = tonumber(data.entry)
    local mapId = tonumber(data.mapId)
    local nx, ny = NormalizePossibleNormalizedPos(data.nx, data.ny)

    if not mapId or not nx or not ny then
        DebugPrint("Resolve result missing coords:", "mapId=", tostring(mapId), "nx=", tostring(data.nx), "ny=", tostring(data.ny), "error=", tostring(data.error))
        return
    end

    local ent
    if entityId then
        for _, e in ipairs(state.db.entities.list) do
            if e and tonumber(e.id) == entityId then
                ent = e
                break
            end
        end
    end

    if not ent then
        for _, e in ipairs(state.db.entities.list) do
            if e and (e.kind == "boss" or e.kind == "rare") then
                if spawnId and e.spawnId and tonumber(e.spawnId) == spawnId then ent = e break end
                if entry and e.entry and tonumber(e.entry) == entry then ent = e break end
            end
        end
    end

    if not ent then
        DebugPrint("Resolve result: no matching entity to update")
        return
    end

    ent.mapId = mapId
    ent.nx = nx
    ent.ny = ny

    if Pins and Pins.Refresh then
        Pins:Refresh()
    end
end

local function NormalizePossibleNormalizedPos(nx, ny)
    nx = tonumber(nx)
    ny = tonumber(ny)
    if not nx or not ny then return nil, nil end

    -- Avoid placing unknown positions at top-left.
    if nx == 0 and ny == 0 then return nil, nil end

    -- Accept percentage coords (0-100) and normalize.
    if (nx > 1 or ny > 1) and nx <= 100 and ny <= 100 then
        nx = nx / 100
        ny = ny / 100
    end

    if nx < 0 or nx > 1 or ny < 0 or ny > 1 then return nil, nil end
    return nx, ny
end

local function CopyInto(src, dest)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = dest[k] or {}
            CopyInto(v, dest[k])
        elseif dest[k] == nil then
            dest[k] = v
        end
    end
end

local function CloneTable(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            copy[k] = CloneTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function ResolveZoneName(zoneId, serverZoneName)
    -- Prefer server-provided zone name (from DBC on server side)
    if serverZoneName and serverZoneName ~= "" and serverZoneName ~= "Unknown" then
        return serverZoneName
    end
    
    if not zoneId or zoneId == 0 then
        return "Unknown Zone"
    end
    
    -- WotLK 3.3.5 doesn't have C_Map.GetAreaInfo, but try anyway for forward compat
    if C_Map and C_Map.GetAreaInfo then
        local name = C_Map.GetAreaInfo(zoneId)
        if name and name ~= "" then
            return name
        end
    end
    
    -- GetMapNameByID is for map IDs, not zone IDs - usually doesn't work here
    if GetMapNameByID then
        local name = GetMapNameByID(zoneId)
        if name and name ~= "" then
            return name
        end
    end
    
    return string.format("Zone %s", tostring(zoneId))
end

local function NormalizeNumber(value)
    if not value then return nil end
    return tonumber(value)
end

local function LooksLikeZoneId(value)
    local n = tonumber(value)
    if not n then
        return false
    end
    -- Zone/Area IDs are integers and typically not huge.
    if n ~= math.floor(n) then
        return false
    end
    return n > 0 and n < 1000000
end

local function BuildHotspotRecord(payload)
    if payload and type(payload) == "table" and type(payload.hotspot) == "table" then
        -- Server may wrap hotspot details in { hotspot = { ... } }
        payload = payload.hotspot
    end

    -- Support short keys (i,m,z,n,h,t,b) and long keys for backward compatibility.
    -- NOTE: Some payloads use `z` for height (world Z), not zoneId; prefer zone/zoneId.
    local id = NormalizeNumber(payload.i or payload.id)
    if not id then return nil end

    local dur = NormalizeNumber(payload.t or payload.dur or payload.timeRemaining) or 0
    local nowSession = GetTime()
    local nowEpoch = NowEpoch()
    local zoneId = NormalizeNumber(payload.zoneId or payload.zone)
    if not zoneId and LooksLikeZoneId(payload.z) then
        zoneId = NormalizeNumber(payload.z)
    end

    local heightZ = NormalizeNumber(payload.h or payload.height)
    if not heightZ then
        local z = NormalizeNumber(payload.z)
        -- Only treat payload.z as height if it wasn't used as zoneId.
        if z and (not zoneId or z ~= zoneId) and (not LooksLikeZoneId(z)) then
            heightZ = z
        end
    end
    local record = {
        id = id,
        map = NormalizeNumber(payload.m or payload.map or payload.mapId),
        zoneId = zoneId,
        zone = ResolveZoneName(zoneId, payload.n or payload.zonename or payload.zoneName),
        x = NormalizeNumber(payload.x),
        y = NormalizeNumber(payload.y),
        z = heightZ,
        nx = NormalizeNumber(payload.nx),
        ny = NormalizeNumber(payload.ny),
        bonus = NormalizeNumber(payload.b or payload.bonus or payload.bonusPercent) or state.config.experienceBonus,
        icon = NormalizeNumber(payload.icon),
        tex = payload.tex,
        texid = NormalizeNumber(payload.texid),
        expire = nowSession + dur,
        expireEpoch = nowEpoch + dur,
        raw = payload.raw,
    }

    -- carry normalized coordinates if server sent percentages instead of 0..1
    if record.nx and record.nx > 1 then
        record.nx = record.nx / 100
    end
    if record.ny and record.ny > 1 then
        record.ny = record.ny / 100
    end

    return record
end

local function SerializeForCache(record)
    if not record or not record.id then return nil end
    return {
        id = record.id,
        map = record.map,
        zoneId = record.zoneId,
        zone = record.zone,
        x = record.x,
        y = record.y,
        z = record.z,
        nx = record.nx,
        ny = record.ny,
        bonus = record.bonus,
        icon = record.icon,
        tex = record.tex,
        texid = record.texid,
        expireEpoch = record.expireEpoch,
    }
end

function Core:PersistHotspot(record)
    if not state.db then return end
    state.db.cache = state.db.cache or {}
    if record.expireEpoch and record.expireEpoch > NowEpoch() then
        state.db.cache[record.id] = SerializeForCache(record)
    else
        state.db.cache[record.id] = nil
    end
end

function Core:UpsertHotspot(record)
    if not record or not record.id then return end
    local existing = state.hotspots[record.id]
    if record.bonus then
        state.config.experienceBonus = record.bonus
    end
    state.hotspots[record.id] = record
    self:PersistHotspot(record)
    if Pins and Pins.Refresh then
        Pins:Refresh()
    end
    if UI and UI.OnHotspotSpawn and not existing then
        -- Only announce if not during initial load and not restored from cache
        local shouldAnnounce = not state.suppressAnnouncements and not record.restoredFromCache
        UI:OnHotspotSpawn(record.id, record, shouldAnnounce)
    elseif UI and UI.OnHotspotsChanged then
        UI:OnHotspotsChanged()
    end
    DebugPrint("Updated hotspot", record.id, existing and "(update)" or "(new)")
end

function Core:RemoveHotspot(id, reason)
    local existing = state.hotspots[id]
    if not existing then return end
    state.hotspots[id] = nil
    if state.db and state.db.cache then
        state.db.cache[id] = nil
    end
    if Pins and Pins.Refresh then
        Pins:Refresh()
    end
    if UI then
        if reason == "expire" and UI.OnHotspotExpire then
            UI:OnHotspotExpire(id, existing)
        elseif UI.OnHotspotsChanged then
            UI:OnHotspotsChanged()
        end
    end
    DebugPrint("Removed hotspot", id, reason or "")
end

function Core:RefreshVisuals()
    if Pins and Pins.Refresh then
        Pins:Refresh()
    end
    if UI and UI.RefreshList then
        UI:RefreshList()
    end
end

function Core:RestoreCachedHotspots()
    if not state.db or not state.db.cache then return end
    local nowEpoch = NowEpoch()
    local revived = 0
    for id, data in pairs(state.db.cache) do
        if data.expireEpoch and data.expireEpoch > nowEpoch then
            local remain = data.expireEpoch - nowEpoch
            local restored = CloneTable(data)
            restored.expire = GetTime() + remain
            restored.restoredFromCache = true  -- Mark as restored, not new
            state.hotspots[id] = restored
            revived = revived + 1
        else
            state.db.cache[id] = nil
        end
    end
    if revived > 0 and Pins and Pins.Refresh then
        Pins:Refresh()
    end
    if revived > 0 and UI and UI.OnHotspotsChanged then
        UI:OnHotspotsChanged()
    end
    DebugPrint("Restored", revived, "cached hotspots")
end

function Core:PruneExpiredHotspots()
    local now = GetTime()
    for id, data in pairs(state.hotspots) do
        if data.expire and data.expire <= now then
            self:RemoveHotspot(id, "expire")
        end
    end
end

function Core:ADDON_LOADED(name)
    if name ~= addonName then return end

    -- SavedVariables migration: prefer new DB but keep old settings if present.
    -- TOC includes both `DCMapupgradesDB` and legacy `DCHotspotDB`.
    if type(DCMapupgradesDB) ~= "table" then
        DCMapupgradesDB = {}
    end
    if type(DCHotspotDB) == "table" then
        CopyInto(DCHotspotDB, DCMapupgradesDB)
    end
    CopyInto(defaults, DCMapupgradesDB)
    state.db = DCMapupgradesDB
    state.db.cache = state.db.cache or {}
    EnsureEntityTables(state.db)
    
    -- Ensure blacklist is initialized (for users upgrading from older versions)
    if type(state.db.bossBlacklistMaps) ~= "table" then
        state.db.bossBlacklistMaps = { [745] = true } -- Jade Forest
    else
        -- Always enforce the Jade Forest server map id
        state.db.bossBlacklistMaps[745] = true
        -- Clear client map ids so Isles of Giants isn't hidden
        state.db.bossBlacklistMaps[1100] = nil
        state.db.bossBlacklistMaps[1101] = nil
        state.db.bossBlacklistMaps[1102] = nil
    end

    -- Re-check protocol availability after all addons loaded
    RefreshProtocolMode()

    if Pins and Pins.Init then
        Pins:Init(state)
    end
    if UI and UI.Init then
        UI:Init(state)
    end
    if addonTable.Options and addonTable.Options.Init then
        addonTable.Options:Init(state)
        -- Create Communication sub-panel
        if addonTable.Options.CreateCommPanel then
            addonTable.Options:CreateCommPanel()
        end
    end

    -- Register DCAddonProtocol handlers if available
    self:RegisterProtocolHandlers()

    self:RestoreCachedHotspots()
    DebugPrint("Addon loaded, protocol mode:", Core.protocolMode)
end

function Core:PLAYER_TARGET_CHANGED()
    if not state.db then return end
    local name = UnitName and UnitName("target")
    if not name or name == "" then return end
    local ent = self:FindEntityByName(name)
    if not ent then return end
    self:SetEntityActive(ent.id, true, "target")
end

function Core:COMBAT_LOG_EVENT_UNFILTERED(...)
    if not state.db then return end
    local eventType
    local destName

    if CombatLogGetCurrentEventInfo then
        local _, subevent, _, _, _, _, _, _, dn = CombatLogGetCurrentEventInfo()
        eventType = subevent
        destName = dn
    else
        -- WotLK signature
        local args = {...}
        eventType = args[2]
        destName = args[9]
    end

    if eventType ~= "UNIT_DIED" and eventType ~= "PARTY_KILL" then
        return
    end
    if not destName or destName == "" then
        return
    end

    local ent = self:FindEntityByName(destName)
    if not ent then return end
    self:SetEntityActive(ent.id, false, "combatlog")
end

function Core:PLAYER_LOGIN()
    -- Re-check DC availability (DC-AddonProtocol may have loaded after us)
    RefreshProtocolMode()

    -- Re-register protocol handlers if DC is now available
    if DC and not Core._handlersRegistered then
        self:RegisterProtocolHandlers()
    end
    
    DebugPrint("PLAYER_LOGIN - Protocol mode:", Core.protocolMode, "DC available:", tostring(DC ~= nil))
    
    if state.db and state.db.showListOnLogin and UI and UI.listFrame then
        UI.listFrame:Show()
        if UI.RefreshList then
            UI:RefreshList()
        end
    end
    
    -- Hook world map for auto-refresh
    self:HookWorldMap()
    
    -- Automatically request hotspot list on login (after a short delay for server connection)
    -- Use a slightly longer delay to ensure connection is established
    local loginFrame = CreateFrame("Frame")
    loginFrame.elapsed = 0
    loginFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 3 then  -- 3 second delay for server connection
            self:SetScript("OnUpdate", nil)
            DebugPrint("Auto-requesting hotspot list...")
            Core:RequestHotspotList("login")
            Core:RequestWorldContent("login")
        end
    end)
end

-- Request world content (bosses/events/hotspots aggregate) from server.
-- This keeps world boss pins in sync even if DC-InfoBar isn't installed.
function Core:RequestWorldContent(reason)
    DebugPrint("Requesting world content from server via", Core.protocolMode, reason and ("reason=" .. tostring(reason)) or "")

    if Core.useDCProtocol and DC and DC.Request then
        DC:Request("WRLD", 0x01, {})
        return true
    end

    -- No reliable fallback for WRLD without DCAddonProtocol.
    return false
end

local function UpsertBossEntityFromServerRecord(b)
    if type(b) ~= "table" or not state.db then return nil end
    EnsureEntityTables(state.db)

    local spawnId = tonumber(b.spawnId) or nil
    local entry = tonumber(b.entry or b.npcEntry or b.creatureEntry) or nil
    local name = b.name
    local zoneLabel = b.zone or b.zoneName

    local mapId = tonumber(b.mapId) or nil
    local nx, ny = NormalizePossibleNormalizedPos(b.nx, b.ny)

    local function findExisting()
        for _, ent in ipairs(state.db.entities.list) do
            if ent and ent.kind == "boss" then
                if spawnId and ent.spawnId and tonumber(ent.spawnId) == spawnId then
                    return ent
                end
                if entry and ent.entry and tonumber(ent.entry) == entry then
                    return ent
                end
                if name and ent.name and NormalizeNameForMatch(ent.name) == NormalizeNameForMatch(name) then
                    return ent
                end
            end
        end
        return nil
    end

    local ent = findExisting()
    if ent then
        if name and name ~= "" then ent.name = name end
        if zoneLabel and zoneLabel ~= "" then ent.zoneLabel = zoneLabel end
        if spawnId then ent.spawnId = spawnId end
        if entry then ent.entry = entry end

        -- Only fill position if it's missing. Respect manual user positioning.
        if mapId and nx and ny and (not ent.mapId or not ent.nx or not ent.ny) then
            ent.mapId = mapId
            ent.nx = nx
            ent.ny = ny
        end
        return ent
    end

    local id = state.db.entities.nextId
    state.db.entities.nextId = id + 1
    ent = {
        id = id,
        kind = "boss",
        name = name or (entry and tostring(entry)) or (spawnId and tostring(spawnId)) or "World Boss",
        mapId = mapId,
        nx = nx,
        ny = ny,
        entry = entry,
        spawnId = spawnId,
        zoneLabel = zoneLabel,
        created = NowEpoch(),
    }
    table.insert(state.db.entities.list, ent)
    return ent
end

local function ApplyBossStatusToEntity(entityId, boss)
    if not state.db or not entityId then return end
    EnsureEntityTables(state.db)

    local now = NowEpoch()
    local st = state.db.entityStatus[entityId] or {}
    st.serverUpdatedAt = now
    st.serverStatus = tostring(boss.status or boss.state or "")
    st.serverActive = (boss.active == true) or (tostring(st.serverStatus):lower() == "active")
    st.serverSpawnIn = tonumber(boss.spawnIn or boss.timeLeft) or nil

    -- Keep activeUntil in sync so existing UI logic (green pin) still works.
    if st.serverActive then
        st.activeUntil = now + 15
        st.lastSeen = now
        st.lastSeenReason = "server"
    end

    state.db.entityStatus[entityId] = st
end

-- Death markers (challenge-mode deaths)
local DEATH_ENTITY_ID_BASE = 3000000

local function PruneExpiredDeathEntities()
    if not state.db then return end
    EnsureEntityTables(state.db)

    local now = NowEpoch()
    local list = state.db.entities.list
    for i = #list, 1, -1 do
        local ent = list[i]
        if ent and ent.kind == "death" then
            local expiresAt = tonumber(ent.expiresAt)
            if expiresAt and expiresAt <= now then
                local id = tonumber(ent.id)
                table.remove(list, i)
                if id and state.db.entityStatus then
                    state.db.entityStatus[id] = nil
                end
            end
        end
    end
end

local function RemoveAllDeathEntities()
    if not state.db then return end
    EnsureEntityTables(state.db)

    local list = state.db.entities.list
    for i = #list, 1, -1 do
        local ent = list[i]
        if ent and ent.kind == "death" then
            local id = tonumber(ent.id)
            table.remove(list, i)
            if id and state.db.entityStatus then
                state.db.entityStatus[id] = nil
            end
        end
    end
end

local function ValidNormalizedPos(nx, ny)
    nx = tonumber(nx)
    ny = tonumber(ny)
    if not nx or not ny then return nil, nil end

    -- Server uses 0.0/0.0 when it cannot normalize; avoid placing at top-left.
    if nx == 0 and ny == 0 then return nil, nil end
    if nx < 0 or nx > 1 or ny < 0 or ny > 1 then return nil, nil end
    return nx, ny
end

local function UpsertDeathEntityFromServerRecord(d)
    if type(d) ~= "table" or not state.db then return nil end
    EnsureEntityTables(state.db)

    local markerId = tonumber(d.markerId)
    if not markerId then return nil end

    local id = DEATH_ENTITY_ID_BASE + markerId
    local ent
    for _, e in ipairs(state.db.entities.list) do
        if e and e.id == id and e.kind == "death" then
            ent = e
            break
        end
    end

    local mapId = tonumber(d.mapId)
    local nx, ny = ValidNormalizedPos(d.nx, d.ny)

    if not ent then
        ent = {
            id = id,
            kind = "death",
            created = NowEpoch(),
        }
        table.insert(state.db.entities.list, ent)
    end

    ent.markerId = markerId
    ent.modeId = d.modeId
    ent.modeLabel = d.modeLabel

    ent.victimGuid = tonumber(d.victimGuid)
    ent.victimName = d.victimName
    ent.victimLevel = tonumber(d.victimLevel)
    ent.victimClass = tonumber(d.victimClass)

    ent.killerType = d.killerType
    ent.killerEntry = tonumber(d.killerEntry)
    ent.killerName = d.killerName

    ent.diedAt = tonumber(d.diedAt)
    ent.expiresAt = tonumber(d.expiresAt)

    -- Entity display fields
    local victim = (ent.victimName and tostring(ent.victimName) ~= "" and tostring(ent.victimName)) or "Unknown"
    ent.name = "Death: " .. victim

    -- Position (only if valid; otherwise do not place a pin)
    ent.mapId = mapId
    ent.nx = nx
    ent.ny = ny

    return ent
end

local function ApplyDeathStatusToEntity(entityId, death)
    if not state.db or not entityId then return end
    EnsureEntityTables(state.db)

    local now = NowEpoch()
    local st = state.db.entityStatus[entityId] or {}
    st.serverUpdatedAt = now
    st.serverStatus = "death"

    local expiresAt = tonumber(death.expiresAt)
    if expiresAt and expiresAt > 0 then
        st.activeUntil = expiresAt
        st.serverActive = expiresAt > now
    else
        st.serverActive = true
    end

    state.db.entityStatus[entityId] = st
end

function Core:HandleWorldContent(data)
    if type(data) ~= "table" or not state.db then return end

    if state.db.debug then
        local bossesN = (type(data.bosses) == "table") and #data.bosses or 0
        local deathsN = (type(data.deaths) == "table") and #data.deaths or 0
        local hotspotsN = (type(data.hotspots) == "table") and #data.hotspots or 0
        DebugPrint("WRLD content:", "bosses=" .. tostring(bossesN), "deaths=" .. tostring(deathsN), "hotspots=" .. tostring(hotspotsN))
    end

    -- Death markers are snapshot-owned: replace on full content.
    if type(data.deaths) == "table" then
        RemoveAllDeathEntities()
        for _, d in ipairs(data.deaths) do
            local ent = UpsertDeathEntityFromServerRecord(d)
            if ent and ent.id then
                ApplyDeathStatusToEntity(ent.id, d)
            end
        end
        PruneExpiredDeathEntities()
        if Pins and Pins.Refresh then
            Pins:Refresh()
        end
    end

    -- Bosses
    if type(data.bosses) == "table" then
        local withPos, missingPos = 0, 0
        for _, b in ipairs(data.bosses) do
            local ent = UpsertBossEntityFromServerRecord(b)
            if ent and ent.id then
                ApplyBossStatusToEntity(ent.id, b)
            end

            local mapId = tonumber(b.mapId)
            local nx, ny = NormalizePossibleNormalizedPos(b.nx, b.ny)
            if mapId and nx and ny then
                withPos = withPos + 1
            else
                missingPos = missingPos + 1
            end
        end
        if state.db.debug then
            DebugPrint("WRLD bosses:", "withPos=" .. tostring(withPos), "missingPos=" .. tostring(missingPos))
        end
        if Pins and Pins.Refresh then
            Pins:Refresh()
        end
    end

    -- Hotspots can also be included in WRLD snapshots; process if present.
    if type(data.hotspots) == "table" then
        for _, hs in ipairs(data.hotspots) do
            Core:ProcessHotspotPayload(hs)
        end
        if Pins and Pins.Refresh then
            Pins:Refresh()
        end
    end
end

function Core:HandleWorldUpdate(data)
    if type(data) ~= "table" or not state.db then return end

    -- Death updates are incremental: only upsert what we got.
    if type(data.deaths) == "table" then
        PruneExpiredDeathEntities()
        for _, d in ipairs(data.deaths) do
            local ent = UpsertDeathEntityFromServerRecord(d)
            if ent and ent.id then
                ApplyDeathStatusToEntity(ent.id, d)
            end
        end
        if Pins and Pins.Refresh then
            Pins:Refresh()
        end
    end

    -- Updates can be partial (e.g., bosses only). Treat them like content.
    self:HandleWorldContent(data)
end

-- Also request on entering world (covers some relog/teleport edge cases)
function Core:PLAYER_ENTERING_WORLD()
    -- Avoid spamming: PLAYER_ENTERING_WORLD can fire multiple times.
    self:MaybeRequestHotspots("enter_world", 60)
end

-- Request hotspot list from server using protocol fallback chain (JSON standard)
function Core:RequestHotspotList(reason)
    RefreshProtocolMode()
    self.lastHotspotRequest = GetTime()
    DebugPrint("Requesting hotspot list from server via", Core.protocolMode, "(JSON)", reason and ("reason=" .. tostring(reason)) or "")

    local payload = {}
    -- Provide optional context; server may ignore.
    payload.zoneText = GetZoneText and (GetZoneText() or "") or ""
    payload.subZoneText = GetSubZoneText and (GetSubZoneText() or "") or ""
    if GetCurrentMapAreaID then
        payload.mapAreaId = GetCurrentMapAreaID() or 0
    end
    -- Version gate: echo the version of the list we hold so the server can
    -- answer with a tiny "unchanged" reply when the active set didn't change.
    payload.v = Core.hotspotListVersion or 0
    
    if Core.useDCProtocol and DC then
        -- DCAddonProtocol (JSON-by-default; routes native bridge or addon whisper)
        DC:Request("SPOT", 0x01, payload)
    else
        DebugPrint("Hotspot list request skipped: DCAddonProtocol not available")
    end
    
    -- Enable announcements after initial list load completes (with delay)
    if state.suppressAnnouncements then
        local enableFrame = CreateFrame("Frame")
        enableFrame.elapsed = 0
        enableFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= 5 then  -- Wait 5 seconds after first request
                self:SetScript("OnUpdate", nil)
                state.suppressAnnouncements = false
                DebugPrint("Announcements enabled")
            end
        end)
    end
end

-- Request teleport to a hotspot using protocol fallback chain (JSON standard)
function Core:RequestTeleport(hotspotId)
    RefreshProtocolMode()
    DebugPrint("Requesting teleport to hotspot", hotspotId, "via", Core.protocolMode, "(JSON)")
    
    if Core.useDCProtocol and DC then
        DC:Request("SPOT", 0x03, { id = hotspotId })
    end
end

-- Request info for a specific hotspot (JSON standard)
function Core:RequestHotspotInfo(hotspotId)
    RefreshProtocolMode()
    DebugPrint("Requesting info for hotspot", hotspotId, "(JSON)")
    
    if Core.useDCProtocol and DC then
        DC:Request("SPOT", 0x02, { id = hotspotId })
    end
end

-- Track zone changes to refresh hotspots
function Core:ZONE_CHANGED_NEW_AREA()
    self:MaybeRequestHotspots("zone_change", 60)
end

-- Request on group roster changes ("join"/"leave"), useful if hotspots are party/raid-scoped
function Core:GROUP_ROSTER_UPDATE()
    self:MaybeRequestHotspots("group_roster", 120)
end

-- WotLK compatibility (some clients fire PARTY_MEMBERS_CHANGED instead)
function Core:PARTY_MEMBERS_CHANGED()
    self:MaybeRequestHotspots("party_members", 120)
end

-- WotLK raid roster updates
function Core:RAID_ROSTER_UPDATE()
    self:MaybeRequestHotspots("raid_roster", 120)
end

function Core:MaybeRequestHotspots(reason, minInterval)
    minInterval = minInterval or 60  -- Default 60 seconds to reduce spam
    local now = GetTime()
    local lastRequest = self.lastHotspotRequest or 0
    if (now - lastRequest) < minInterval then
        return
    end

    if self._pendingAutoRequest then
        return
    end
    self._pendingAutoRequest = true

    local frame = CreateFrame("Frame")
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(selfFrame, elapsed)
        selfFrame.elapsed = selfFrame.elapsed + elapsed
        if selfFrame.elapsed >= 1 then
            selfFrame:SetScript("OnUpdate", nil)
            Core._pendingAutoRequest = nil
            Core:RequestHotspotList(reason)
        end
    end)
end

-- Hook world map to refresh hotspots when opened
function Core:HookWorldMap()
    if self.worldMapHooked then return end
    self.worldMapHooked = true
    
    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function()
            -- Only request if it's been a while since last request (60 sec cooldown)
            local now = GetTime()
            local lastRequest = Core.lastHotspotRequest or 0
            if (now - lastRequest) >= 60 then
                Core:RequestHotspotList()
            end
        end)
        DebugPrint("WorldMap OnShow hook installed")
    end
end

function Core:PLAYER_LOGOUT()
    self:PruneExpiredHotspots()
end

local eventFrame = CreateFrame("Frame")
local function SafeRegister(frame, event)
    pcall(frame.RegisterEvent, frame, event)
end

SafeRegister(eventFrame, "ADDON_LOADED")
SafeRegister(eventFrame, "PLAYER_LOGIN")
SafeRegister(eventFrame, "PLAYER_ENTERING_WORLD")
SafeRegister(eventFrame, "PLAYER_LOGOUT")
SafeRegister(eventFrame, "ZONE_CHANGED_NEW_AREA")
-- Group join/leave events (varies by client version)
SafeRegister(eventFrame, "GROUP_ROSTER_UPDATE")
SafeRegister(eventFrame, "PARTY_MEMBERS_CHANGED")
SafeRegister(eventFrame, "RAID_ROSTER_UPDATE")
SafeRegister(eventFrame, "PLAYER_TARGET_CHANGED")
SafeRegister(eventFrame, "COMBAT_LOG_EVENT_UNFILTERED")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if Core[event] then
        Core[event](Core, ...)
    end
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
    Core.elapsed = (Core.elapsed or 0) + elapsed
    if Core.elapsed < 1 then
        return
    end
    Core.elapsed = 0
    Core:PruneExpiredHotspots()

    -- Sync world boss active/inactive from DC-InfoBar if available.
    Core._bossSyncElapsed = (Core._bossSyncElapsed or 0) + 1
    if Core._bossSyncElapsed >= 2 then
        Core._bossSyncElapsed = 0
        Core:SyncWorldBossStatusFromInfoBar()
    end
    
    -- Periodic refresh: re-request hotspot list every 3 minutes to catch server-side removals
    Core.refreshElapsed = (Core.refreshElapsed or 0) + 1
    if Core.refreshElapsed >= 180 then  -- 180 seconds = 3 minutes
        Core.refreshElapsed = 0
        Core:RequestHotspotList()
    end
end)

-- =====================================================================
-- DC ADDON PROTOCOL HANDLERS
-- =====================================================================

-- Simple JSON parser for WotLK (no native JSON support)
local function ParseJSON(str)
    if not str or str == "" then return nil end
    
    -- Very basic JSON parsing for simple objects
    local result = {}
    
    -- Remove outer braces
    str = str:match("^%s*{(.+)}%s*$")
    if not str then return nil end
    
    -- Parse key-value pairs
    for key, value in str:gmatch('"([^"]+)"%s*:%s*([^,}]+)') do
        -- Remove quotes from string values
        local strVal = value:match('^"(.+)"$')
        if strVal then
            result[key] = strVal
        elseif value == "true" then
            result[key] = true
        elseif value == "false" then
            result[key] = false
        elseif value == "null" then
            result[key] = nil
        else
            result[key] = tonumber(value) or value
        end
    end
    
    return result
end

-- Register protocol handlers (called after ADDON_LOADED)
function Core:RegisterProtocolHandlers()
    -- Re-check DC availability
    DC = rawget(_G, "DCAddonProtocol")
    if not DC then
        DebugPrint("DCAddonProtocol not available, using fallback")
        return
    end
    
    -- Prevent double registration
    if Core._handlersRegistered then
        DebugPrint("Protocol handlers already registered")
        return
    end
    Core._handlersRegistered = true
    
    DebugPrint("Registering DCAddonProtocol handlers...")
    
    local function DebugProtocol(...)
        if state.db and state.db.debug then
            print("|cff33ff99[DC-Mapupgrades Protocol]|r", ...)
        end
    end
    
    -- SMSG_HOTSPOT_LIST (0x10)
    -- JSON: handler receives decoded table
    -- Legacy: count (number) + list (semicolon-separated string)
    DC:RegisterHandler("SPOT", 0x10, function(firstArg, ...)
        -- JSON-by-default path: DCAddonProtocol already decoded JSON and passes a table.
        if type(firstArg) == "table" then
            local data = firstArg
            if data.unchanged then
                DebugProtocol("Hotspot list unchanged (v:", data.v, ")")
                return
            end
            -- Only adopt the version when a full list is applied: an
            -- "unchanged" reply to another addon's request must not bump
            -- our version past the list we actually hold.
            if data.v then
                Core.hotspotListVersion = tonumber(data.v) or 0
            end
            local list = (data and data.hotspots) or data
            if type(list) == "table" then
                -- list may be {hotspots=[...]} or the array directly
                local received = {}
                for _, hs in ipairs(list) do
                    local id = tonumber(hs and hs.i or hs and hs.id)
                    if id then
                        received[id] = true
                    end
                    Core:ProcessHotspotPayload(hs)
                end
                -- A full JSON list is authoritative: drop tracked hotspots the
                -- server no longer reports (early despawns/admin clears).
                if type(data.hotspots) == "table" then
                    local stale = {}
                    for id in pairs(state.hotspots) do
                        if not received[id] then
                            stale[#stale + 1] = id
                        end
                    end
                    for _, id in ipairs(stale) do
                        Core:RemoveHotspot(id, "list_sync")
                    end
                end
                if Pins and Pins.Refresh then
                    Pins:Refresh()
                end
            end
            return
        end

        -- Legacy format: count + semicolon-separated string
        local args = {firstArg, ...}
        local count = tonumber(firstArg) or 0
        local listStr = args[2] or ""
        DebugProtocol("Received hotspot list (legacy), count:", count, "data:", listStr:sub(1, 100))
        
        if count == 0 or listStr == "" then
            DebugProtocol("No hotspots in list")
            return
        end
        
        -- Parse semicolon-separated entries
        for entry in listStr:gmatch("[^;]+") do
            -- Each entry format: id:mapId:zoneId:zoneName:x:y:dur:bonus
            local parts = {}
            for part in entry:gmatch("[^:]+") do
                table.insert(parts, part)
            end
            
            if #parts >= 7 then
                local payload = {
                    id = tonumber(parts[1]),
                    map = tonumber(parts[2]),
                    zone = tonumber(parts[3]),        -- server ZoneID/AreaID
                    zonename = parts[4],              -- zone name from DBC
                    x = tonumber(parts[5]),
                    y = tonumber(parts[6]),
                    dur = tonumber(parts[7]),
                    bonus = tonumber(parts[8]) or 100,
                }
                DebugProtocol("Parsed hotspot:", payload.id, "zone:", payload.zone, "map:", payload.map)
                Core:ProcessHotspotPayload(payload)
            else
                DebugProtocol("Invalid entry format, parts:", #parts, "raw:", entry)
            end
        end
        
        -- Refresh pins after processing all hotspots
        if Pins and Pins.Refresh then
            Pins:Refresh()
        end
    end)
    
    -- SMSG_HOTSPOT_INFO (0x11)
    DC:RegisterHandler("SPOT", 0x11, function(firstArg, ...)
        if type(firstArg) == "table" then
            local data = firstArg
            -- server may send { found=false, id=?, error=? }
            if data.found == false then
                DebugProtocol("Hotspot info: not found", data.id)
                return
            end
            DebugProtocol("Hotspot info (JSON):", data.id)
            Core:ProcessHotspotPayload(data.hotspot or data)
            return
        end

        -- Legacy/non-JSON format (rare): found flag + flattened values
        local found, id, mapId, zoneId, zoneName, x, y, z, dur, bonus = firstArg, ...
        if found and found ~= 0 then
            local payload = {
                id = id,
                map = mapId,
                zone = zoneId,
                zonename = zoneName,
                x = x,
                y = y,
                z = z,
                dur = dur,
                bonus = bonus,
            }
            Core:ProcessHotspotPayload(payload)
        end
    end)

    -- SMSG_HOTSPOT_SPAWN (0x12)
    DC:RegisterHandler("SPOT", 0x12, function(firstArg, ...)
        if type(firstArg) == "table" then
            local data = firstArg
            local hs = (data and (data.hotspot or data))
            DebugProtocol("New hotspot (JSON):", hs and hs.id)
            Core:ProcessHotspotPayload(hs)
            return
        end

        -- Legacy spawn format
        local id, mapId, zoneId, zoneName, x, y, bonus, duration = firstArg, ...
        local payload = {
            id = id,
            map = mapId,
            zone = zoneId,
            zonename = zoneName,
            x = x,
            y = y,
            bonus = bonus,
            dur = duration,
        }
        Core:ProcessHotspotPayload(payload)
    end)

    -- SMSG_HOTSPOT_EXPIRE (0x13)
    DC:RegisterHandler("SPOT", 0x13, function(firstArg, ...)
        local id
        if type(firstArg) == "table" then
            id = tonumber(firstArg.id)
        else
            id = tonumber(firstArg)
        end

        if id then
            DebugProtocol("Hotspot expired:", id)
            local record = state.hotspots[id]
            Core:RemoveHotspot(id, "expire")

            if record and (not state.suppressAnnouncements) and state.db and state.db.announceExpire then
                print("|cffff8800[DC-Hotspot]|r Hotspot expired in " .. (record.zone or "unknown zone"))
            end
        end
    end)

    -- SMSG_TELEPORT_RESULT (0x14)
    DC:RegisterHandler("SPOT", 0x14, function(firstArg, ...)
        if type(firstArg) == "table" then
            local data = firstArg
            if data.success then
                print("|cff00ff00[DC-Hotspot]|r Teleported to hotspot #" .. (data.id or "?"))
            else
                print("|cffff0000[DC-Hotspot]|r Teleport failed: " .. (data.error or "Unknown error"))
            end
            return
        end

        local success, hotspotId, message = firstArg, ...
        if success and tostring(success) ~= "0" then
            print("|cff00ff00[DC-Hotspot]|r Teleported to hotspot #" .. (hotspotId or "?"))
        else
            print("|cffff0000[DC-Hotspot]|r Teleport failed: " .. (message or "Unknown error"))
        end
    end)

    -- =================================================================
    -- WRLD: World content (bosses/hotspots/events)
    -- =================================================================
    if DC.RegisterJSONHandler then
        DC:RegisterJSONHandler("WRLD", 0x10, function(data)
            Core:HandleWorldContent(data)
        end)
        DC:RegisterJSONHandler("WRLD", 0x11, function(data)
            Core:HandleWorldUpdate(data)
        end)
        DC:RegisterJSONHandler("WRLD", 0x12, function(data)
            Core:HandleWorldResolveResult(data)
        end)
    else
        -- Fallback: JSON-by-default still tends to call RegisterHandler with a decoded table.
        DC:RegisterHandler("WRLD", 0x10, function(data)
            Core:HandleWorldContent(data)
        end)
        DC:RegisterHandler("WRLD", 0x11, function(data)
            Core:HandleWorldUpdate(data)
        end)
        DC:RegisterHandler("WRLD", 0x12, function(data)
            Core:HandleWorldResolveResult(data)
        end)
    end
    
    DebugPrint("DCAddonProtocol handlers registered")
end

-- Process a hotspot payload (from any protocol)
function Core:ProcessHotspotPayload(payload)
    -- JSON payloads use the short key "i"; legacy paths use "id".
    if not payload or not (payload.id or payload.i) then return end

    local record = BuildHotspotRecord(payload)
    if record then
        self:UpsertHotspot(record)
    end
end

return Core
