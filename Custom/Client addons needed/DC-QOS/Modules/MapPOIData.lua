-- ============================================================
-- DC-QoS: Map POI Data Cache
-- ============================================================
-- Client-side cache of the server's world-map POI list (currently flight
-- masters), delivered over the DC addon protocol (module "MPOI",
-- CMSG_REQUEST_LIST 0x01 -> SMSG_SEND_LIST 0x10). The server handler
-- (dc_addon_mappois.cpp) pages the list; this module accumulates the pages
-- into a flat cache.
--
-- The main use is custom maps (Azshara Crater, DC Hyjal, DC Plaguelands,
-- Hyjal Frontier) that have no client taxi map: QuestMapPins renders these
-- POIs on the world map with a name tooltip. Consumers call EnsureRequested()
-- to lazily sync, then GetPOIs() / GetPOIsByType(t) to read.
-- ============================================================

local addon = DCQOS
if not addon then
    return
end

local MapPOIData = {}

-- Shared POI type registry, keyed by the `t` value the server sends. Both
-- renderers read their icon and label from here -- the world map (QuestMapPins)
-- and the minimap (MapPOIMinimap) -- so a new POI kind needs only a new `t`
-- value server-side plus one entry below to show up in both places.
--
-- Icon paths MUST exist in the 3.3.5 asset set. The client silently draws
-- nothing for an unknown path -- a wrong one is an invisible pin, not an
-- error -- and absence from FrameXML proves nothing, because the engine
-- references these service icons itself. Every path below was verified to be
-- present in the client's locale-enGB.MPQ before use.
--
-- `texCoord` (optional) trims the border off Interface\Icons art so it sits
-- flush next to the borderless Minimap\Tracking icons.
--
-- `minimap = false` keeps a type on the world map only, for POIs the client
-- already blips on the minimap itself.
MapPOIData.TYPES = {
    flight = {
        order = 1,
        label = "Flight Master",
        worldIcon = "Interface\\Minimap\\Tracking\\FlightMaster",
        -- The engine already draws a green taxi boot on the minimap for every
        -- flight master in range, on custom maps too, so a second pin there is
        -- just noise. The world-map layer still earns its keep: it also shows
        -- the flight masters the player has not discovered yet.
        minimap = false,
        borderColor = { 0.24, 0.62, 0.28, 0.62 },
        iconColor = { 1.0, 1.0, 1.0, 1.0 },
    },
    inn = {
        order = 2,
        label = "Innkeeper",
        worldIcon = "Interface\\Minimap\\Tracking\\Innkeeper",
        minimapIcon = "Interface\\Minimap\\Tracking\\Innkeeper",
        borderColor = { 0.72, 0.52, 0.22, 0.62 },
        iconColor = { 1.0, 1.0, 1.0, 1.0 },
    },
    mail = {
        order = 3,
        label = "Mailbox",
        worldIcon = "Interface\\Minimap\\Tracking\\Mailbox",
        minimapIcon = "Interface\\Minimap\\Tracking\\Mailbox",
        borderColor = { 0.58, 0.58, 0.64, 0.62 },
        iconColor = { 1.0, 1.0, 1.0, 1.0 },
    },
    teleporter = {
        order = 4,
        label = "Teleporter",
        -- No Minimap\Tracking equivalent exists for portals; this is a spell
        -- icon, so its border is trimmed to match the others.
        worldIcon = "Interface\\Icons\\Spell_Arcane_PortalStormwind",
        minimapIcon = "Interface\\Icons\\Spell_Arcane_PortalStormwind",
        texCoord = { 0.08, 0.92, 0.08, 0.92 },
        borderColor = { 0.55, 0.35, 0.85, 0.62 },
        iconColor = { 1.0, 1.0, 1.0, 1.0 },
    },
}

-- Per-type visibility is shared by both renderers, so toggling a marker type
-- affects the world map and the minimap together.
function MapPOIData:IsTypeEnabled(poiType)
    local info = self:GetTypeInfo(poiType)
    if not info then
        return false
    end

    local settings = addon.settings and addon.settings.mapPoiTypes
    local value = settings and settings[poiType]
    if value == nil then
        return info.defaultEnabled ~= false
    end
    return value ~= false
end

-- Whether a type is drawn on the minimap at all. Types the client already
-- blips itself (flight masters) opt out here and stay world-map only.
function MapPOIData:IsTypeOnMinimap(poiType)
    local info = self:GetTypeInfo(poiType)
    return info ~= nil and info.minimap ~= false
end

function MapPOIData:GetTypeInfo(poiType)
    if type(poiType) ~= "string" then
        return nil
    end
    return self.TYPES[poiType]
end

-- Registered type keys in a stable draw order.
function MapPOIData:GetTypeKeys()
    local keys = {}
    for key in pairs(self.TYPES) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(left, right)
        local leftOrder = self.TYPES[left].order or 100
        local rightOrder = self.TYPES[right].order or 100
        if leftOrder ~= rightOrder then
            return leftOrder < rightOrder
        end
        return left < right
    end)
    return keys
end

local state = {
    list = {},             -- array of { type, name, map, x, y, z }
    byType = {},           -- type -> array of POIs (same tables as list)
    requested = false,     -- we have kicked off a sync
    complete = false,      -- the full list has been received
    total = 0,
    received = 0,
    handlerRegistered = false,
    pageLimit = 100,
    version = 0,           -- server content version of the cached list
}

local function GetDC()
    return rawget(_G, "DCAddonProtocol")
end

-- The POI list is static world data (~60 KB per full sync), so it is cached
-- in SavedVariables per faction and re-validated with the server's content
-- version instead of being re-downloaded every session. Old servers ignore
-- the `v` field and send the full list; old caches simply miss and refill.
local function GetFactionCacheKey()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return (faction == "Horde") and "Horde" or "Alliance"
end

local function GetSavedCache()
    local db = rawget(_G, "DCQoSDB")
    if type(db) ~= "table" then
        return nil
    end
    local cache = db.mapPoiCache
    if type(cache) ~= "table" then
        return nil
    end
    local entry = cache[GetFactionCacheKey()]
    if type(entry) ~= "table" or type(entry.list) ~= "table" or
        not tonumber(entry.v) then
        return nil
    end
    return entry
end

local function StoreSavedCache(version, list)
    local db = rawget(_G, "DCQoSDB")
    if type(db) ~= "table" then
        return
    end
    db.mapPoiCache = db.mapPoiCache or {}
    db.mapPoiCache[GetFactionCacheKey()] = { v = version, list = list }
end

local function RebuildByType()
    state.byType = {}
    for i = 1, #state.list do
        local poi = state.list[i]
        local bucket = state.byType[poi.type]
        if not bucket then
            bucket = {}
            state.byType[poi.type] = bucket
        end
        bucket[#bucket + 1] = poi
    end
end

local function RefreshRenderers()
    for _, moduleName in ipairs({ "QuestMapPins", "MapPOIMinimap" }) do
        local renderer = type(addon.GetModule) == "function" and addon:GetModule(moduleName) or nil
        if renderer and type(renderer.Refresh) == "function" then
            if type(addon.DelayedCall) == "function" then
                addon:DelayedCall(0, function()
                    renderer:Refresh()
                end)
            else
                renderer:Refresh()
            end
        end
    end
end

function MapPOIData:RequestPage(offset, reset)
    local DC = GetDC()
    if not DC or type(DC.Request) ~= "function" then
        return
    end

    local request = {
        offset = tonumber(offset) or 0,
        limit = state.pageLimit,
        reset = reset and true or false,
    }

    -- On the first page, offer our cached version so an unchanged server
    -- list is answered with a tiny upToDate ack instead of the full pages.
    if request.offset == 0 then
        local cached = GetSavedCache()
        if cached then
            request.v = tonumber(cached.v)
        end
    end

    DC:Request("MPOI", 0x01, request)
end

local function OnPOIResponse(data)
    if type(data) ~= "table" then
        return
    end

    -- Server confirmed our SavedVariables cache is current: promote it to the
    -- live state without any page traffic.
    if data.upToDate == true then
        local cached = GetSavedCache()
        if cached then
            state.list = cached.list
            state.version = tonumber(cached.v) or 0
            state.total = #state.list
            state.received = #state.list
            state.complete = true
            RebuildByType()
            RefreshRenderers()
        else
            -- We sent a version but lost the cache in the meantime; refetch.
            state.requested = true
            MapPOIData:RequestPage(0, true)
        end
        return
    end

    local list = data.pois
    if type(list) ~= "table" then
        return
    end

    if tonumber(data.v) then
        state.version = tonumber(data.v)
    end

    local offset = tonumber(data.offset or 0) or 0
    local reset = (data.reset == true) or (offset == 0)
    if reset then
        state.list = {}
        state.byType = {}
        state.received = 0
        state.complete = false
    end

    for i = 1, #list do
        local raw = list[i]
        local map = raw and tonumber(raw.m)
        local x = raw and tonumber(raw.x)
        local y = raw and tonumber(raw.y)
        if map and x and y then
            local poi = {
                type = tostring(raw.t or "poi"),
                name = raw.n,
                map = map,
                x = x,
                y = y,
                z = tonumber(raw.z),
            }
            state.list[#state.list + 1] = poi

            local bucket = state.byType[poi.type]
            if not bucket then
                bucket = {}
                state.byType[poi.type] = bucket
            end
            bucket[#bucket + 1] = poi
        end
    end

    state.total = tonumber(data.total) or state.total
    state.received = offset + #list

    local done = (data.done == true)
        or (state.total > 0 and state.received >= state.total)

    if done then
        state.complete = true
        -- Persist the full list so the next session can version-check
        -- instead of re-downloading.
        if state.version and state.version > 0 then
            StoreSavedCache(state.version, state.list)
        end
        -- Refresh every renderer once, now that the full set is available.
        RefreshRenderers()
    elseif state.requested and #list > 0 then
        -- Continue paging only for a sync we initiated (avoids looping on
        -- stray responses driven by other addons).
        MapPOIData:RequestPage(state.received, false)
    end
end

function MapPOIData:EnsureHandler()
    if state.handlerRegistered then
        return
    end

    local DC = GetDC()
    if not DC or type(DC.RegisterHandler) ~= "function" then
        return
    end

    DC:RegisterHandler("MPOI", 0x10, OnPOIResponse)
    state.handlerRegistered = true
end

-- Kick off a one-time sync of the POI list. Safe to call repeatedly.
function MapPOIData:EnsureRequested()
    self:EnsureHandler()
    if state.requested or state.complete then
        return
    end

    local DC = GetDC()
    if not DC or type(DC.Request) ~= "function" then
        return
    end

    -- Serve the cached list immediately so pins render without waiting for
    -- the server round-trip; the version check then confirms it (tiny ack)
    -- or replaces it (full page sync overwrites via reset).
    if #state.list == 0 then
        local cached = GetSavedCache()
        if cached then
            state.list = cached.list
            state.version = tonumber(cached.v) or 0
            state.total = #state.list
            state.received = #state.list
            RebuildByType()
            RefreshRenderers()
        end
    end

    state.requested = true
    self:RequestPage(0, true)
end

function MapPOIData:GetPOIs()
    return state.list
end

function MapPOIData:GetPOIsByType(poiType)
    return state.byType[poiType]
end

function MapPOIData:IsComplete()
    return state.complete == true
end

addon.MapPOIData = MapPOIData

-- Register the response handler at load so the cache warms from any MPOI
-- traffic on the session, even before the map layer first requests it.
MapPOIData:EnsureHandler()
