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

local state = {
    list = {},             -- array of { type, name, map, x, y, z }
    byType = {},           -- type -> array of POIs (same tables as list)
    requested = false,     -- we have kicked off a sync
    complete = false,      -- the full list has been received
    total = 0,
    received = 0,
    handlerRegistered = false,
    pageLimit = 100,
}

local function GetDC()
    return rawget(_G, "DCAddonProtocol")
end

function MapPOIData:RequestPage(offset, reset)
    local DC = GetDC()
    if not DC or type(DC.Request) ~= "function" then
        return
    end

    DC:Request("MPOI", 0x01, {
        offset = tonumber(offset) or 0,
        limit = state.pageLimit,
        reset = reset and true or false,
    })
end

local function OnPOIResponse(data)
    if type(data) ~= "table" then
        return
    end

    local list = data.pois
    if type(list) ~= "table" then
        return
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
        -- Refresh the map pins once, now that the full set is available.
        local qmp = type(addon.GetModule) == "function" and addon:GetModule("QuestMapPins") or nil
        if qmp and type(qmp.Refresh) == "function" then
            if type(addon.DelayedCall) == "function" then
                addon:DelayedCall(0, function()
                    qmp:Refresh()
                end)
            else
                qmp:Refresh()
            end
        end
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
