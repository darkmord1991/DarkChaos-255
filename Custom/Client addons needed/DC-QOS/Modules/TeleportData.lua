-- ============================================================
-- DC-QoS: Teleport Data Cache
-- ============================================================
-- Client-side cache of the server's game_tele list, delivered over the DC addon
-- protocol (module "TELE", CMSG_REQUEST_LIST 0x01 -> SMSG_SEND_LIST 0x10). The
-- server handler (dc_addon_teleports.cpp) pages the list; this module accumulates
-- the pages into a flat cache keyed by teleport id.
--
-- Consumers (currently QuestMapPins' Teleport pin layer) call EnsureRequested()
-- to lazily sync the list, then GetTeleports() to read it. The response handler
-- is registered at load so the cache also warms from list traffic driven by other
-- addons (e.g. the DC-GM teleport tool) without a duplicate request.
-- ============================================================

local addon = DCQOS
if not addon then
    return
end

local TeleportData = {}

local state = {
    cache = {},            -- id -> { id, name, map, x, y, z }
    list = {},             -- array mirror of cache for fast iteration
    requested = false,     -- we have kicked off a sync
    complete = false,      -- the full list has been received
    total = 0,
    received = 0,
    handlerRegistered = false,
    pageLimit = 200,
}

local function GetDC()
    return rawget(_G, "DCAddonProtocol")
end

local function RebuildList()
    local list = {}
    for _, teleport in pairs(state.cache) do
        list[#list + 1] = teleport
    end
    state.list = list
end

function TeleportData:RequestPage(offset, reset)
    local DC = GetDC()
    if not DC or type(DC.Request) ~= "function" then
        return
    end

    DC:Request("TELE", 0x01, {
        offset = tonumber(offset) or 0,
        limit = state.pageLimit,
        reset = reset and true or false,
    })
end

local function OnTeleportResponse(data)
    if type(data) ~= "table" then
        return
    end

    local list = data.teleports or data.list
    -- The native / generic bridge delivers a decoded table; a raw JSON string is
    -- a legacy transport this module does not attempt to decode.
    if type(list) ~= "table" then
        return
    end

    local offset = tonumber(data.offset or 0) or 0
    local reset = (data.reset == true) or (offset == 0)
    if reset then
        state.cache = {}
        state.received = 0
        state.complete = false
    end

    for i = 1, #list do
        local teleport = list[i]
        local id = teleport and tonumber(teleport.id)
        if id then
            state.cache[id] = {
                id = id,
                name = teleport.name,
                map = tonumber(teleport.map),
                x = tonumber(teleport.x),
                y = tonumber(teleport.y),
                z = tonumber(teleport.z),
            }
        end
    end

    state.total = tonumber(data.total) or state.total
    state.received = offset + #list

    local done = (data.done == true)
        or (state.total > 0 and state.received >= state.total)

    RebuildList()

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
        -- Continue paging only for a sync we initiated (avoids looping on stray
        -- responses driven by other addons); idempotent by id if they overlap.
        TeleportData:RequestPage(state.received, false)
    end
end

function TeleportData:EnsureHandler()
    if state.handlerRegistered then
        return
    end

    local DC = GetDC()
    if not DC or type(DC.RegisterHandler) ~= "function" then
        return
    end

    DC:RegisterHandler("TELE", 0x10, OnTeleportResponse)
    state.handlerRegistered = true
end

-- Kick off a one-time sync of the teleport list. Safe to call repeatedly.
function TeleportData:EnsureRequested()
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

function TeleportData:GetTeleports()
    return state.list
end

function TeleportData:IsComplete()
    return state.complete == true
end

addon.TeleportData = TeleportData

-- Register the response handler at load so the cache warms from any TELE list
-- traffic on the session, even before the map layer first requests it.
TeleportData:EnsureHandler()
