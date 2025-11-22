-- DCMythicPlusHUD.lua
-- Bridges Mythic+ HUD cache rows to Rochet2 AIO so the DC-MythicPlus addon receives live data

if _G.DCMythicPlusHudBridgeLoaded then
    return
end
_G.DCMythicPlusHudBridgeLoaded = true

local MODULE_PREFIX = "[DCMythicPlusHUD]"
local ADDON_NAME = "DCMythicPlusHUD"
local MESSAGE_KEY = "HUD"
local HUD_TABLE = "dc_mythicplus_hud_cache"
local POLL_INTERVAL_MS = 1000
local INSTANCE_KEY_FACTOR = 4294967296 -- 2^32

local okAIO, AIO = pcall(function()
    return AIO or require("AIO")
end)

if not okAIO or not AIO then
    local fallbackPaths = {
        "AIO.lua",
        "Custom/Eluna scripts/AIO.lua",
        "Custom/RochetAio/AIO-master/AIO.lua",
        "AIO/AIO.lua",
    }
    for _, path in ipairs(fallbackPaths) do
        local ok = pcall(dofile, path)
        if ok and _G.AIO then
            AIO = _G.AIO
            break
        end
    end
end

if not AIO or type(AIO.AddHandlers) ~= "function" then
    print(string.format("%s AIO not available; Mythic+ HUD bridge inactive", MODULE_PREFIX))
    return
end

local Handlers = AIO.AddHandlers(ADDON_NAME, {}) or {}

local hudCache = {}
local playerSnapshots = {}
local missingKeys = {}
local lastSeenUpdate = 0
local tableEnsured = false

local function safeNumber(value)
    if type(value) == "userdata" then
        local s = tostring(value)
        local n = tonumber(s)
        if n then
            return n
        end
        return 0
    end
    return tonumber(value) or 0
end

local function safeQuery(sql)
    local ok, res = pcall(CharDBQuery, sql)
    if not ok then
        print(string.format("%s CharDBQuery failed: %s", MODULE_PREFIX, tostring(res)))
        return nil
    end
    return res
end

local function safeExecute(sql)
    local ok, err = pcall(CharDBExecute, sql)
    if not ok then
        print(string.format("%s CharDBExecute failed: %s", MODULE_PREFIX, tostring(err)))
    end
end

local function ensureTable()
    if tableEnsured then
        return
    end
    safeExecute(string.format([[CREATE TABLE IF NOT EXISTS `%s` (
        `instance_key` BIGINT UNSIGNED NOT NULL,
        `map_id` INT UNSIGNED NOT NULL,
        `instance_id` INT UNSIGNED NOT NULL,
        `owner_guid` INT UNSIGNED NOT NULL,
        `keystone_level` TINYINT UNSIGNED NOT NULL,
        `season_id` INT UNSIGNED NOT NULL,
        `payload` LONGTEXT NOT NULL,
        `updated_at` BIGINT UNSIGNED NOT NULL,
        PRIMARY KEY (`instance_key`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]], HUD_TABLE))
    tableEnsured = true
end

local function jsonEscape(text)
    text = tostring(text or "")
    text = text:gsub("\\", "\\\\"):gsub('"', '\\"')
    return text
end

local function makeInstanceKey(player)
    if not player or not player.IsInWorld or not player:IsInWorld() then
        return nil
    end
    local mapId = player:GetMapId()
    if not mapId then
        return nil
    end
    local instanceId = player:GetInstanceId()
    if not instanceId or instanceId == 0 then
        return nil
    end
    local map = player:GetMap()
    if not map then
        return nil
    end
    local isDungeon = false
    local okDungeon, result = pcall(function()
        return map:IsDungeon()
    end)
    if okDungeon and result then
        isDungeon = true
    else
        local okRaid, raidResult = pcall(function()
            return map:IsRaid()
        end)
        if okRaid and raidResult then
            isDungeon = true
        end
    end
    if not isDungeon then
        return nil
    end
    return mapId * INSTANCE_KEY_FACTOR + instanceId
end

local function sendIdle(player, reason)
    if not player or not AIO or not AIO.Handle then
        return
    end
    local guid = player:GetGUIDLow()
    local prev = guid and playerSnapshots[guid]
    if prev and prev.idleReason == reason then
        return
    end
    local payload = string.format('{"op":"idle","reason":"%s"}', jsonEscape(reason or "idle"))
    local ok, err = pcall(function()
        AIO.Handle(player, ADDON_NAME, MESSAGE_KEY, payload)
    end)
    if not ok then
        print(string.format("%s idle send failed: %s", MODULE_PREFIX, tostring(err)))
        return
    end
    if guid then
        playerSnapshots[guid] = { idleReason = reason }
    end
end

local function storeSnapshot(player, instanceKey, updatedAt)
    local guid = player and player:GetGUIDLow()
    if not guid then
        return
    end
    playerSnapshots[guid] = { key = instanceKey, updated = updatedAt }
end

local function sendPayload(player, record)
    if not player or not record or record.payload == "" then
        return false
    end
    local ok, err = pcall(function()
        AIO.Handle(player, ADDON_NAME, MESSAGE_KEY, record.payload)
    end)
    if not ok then
        print(string.format("%s payload send failed (%s)", MODULE_PREFIX, tostring(err)))
        return false
    end
    storeSnapshot(player, record.key, record.updated)
    return true
end

local function cacheMissBackoff(instanceKey)
    local now = os.time()
    local stamp = missingKeys[instanceKey]
    if stamp and (now - stamp) < 2 then
        return true
    end
    missingKeys[instanceKey] = now
    return false
end

local function fetchSnapshot(instanceKey)
    if not instanceKey or instanceKey == 0 then
        return nil
    end
    if hudCache[instanceKey] then
        return hudCache[instanceKey]
    end
    if cacheMissBackoff(instanceKey) then
        return nil
    end
    ensureTable()
    local sql = string.format("SELECT payload, updated_at FROM `%s` WHERE instance_key = %.0f LIMIT 1", HUD_TABLE, instanceKey)
    local res = safeQuery(sql)
    if res and res:NextRow() then
        local payload = res:GetString(0) or ""
        local updated = safeNumber(res:GetUInt64(1) or res:GetUInt32(1) or res:GetInt64(1))
        if payload ~= "" then
            hudCache[instanceKey] = { payload = payload, updated = updated, key = instanceKey }
            if updated > lastSeenUpdate then
                lastSeenUpdate = updated
            end
            missingKeys[instanceKey] = nil
            return hudCache[instanceKey]
        end
    end
    return nil
end

local function pullCacheUpdates()
    ensureTable()
    local sql = string.format("SELECT instance_key, payload, updated_at FROM `%s` WHERE updated_at > %d ORDER BY updated_at", HUD_TABLE, lastSeenUpdate)
    local res = safeQuery(sql)
    if not res then
        return
    end
    while res:NextRow() do
        local key = safeNumber(res:GetUInt64(0) or res:GetUInt32(0) or res:GetInt64(0))
        local payload = res:GetString(1) or ""
        local updated = safeNumber(res:GetUInt64(2) or res:GetUInt32(2) or res:GetInt64(2))
        if key > 0 and payload ~= "" then
            hudCache[key] = { payload = payload, updated = updated, key = key }
            if updated > lastSeenUpdate then
                lastSeenUpdate = updated
            end
            missingKeys[key] = nil
        end
    end
end

local function deliverSnapshot(player, opts)
    opts = opts or {}
    local instanceKey = makeInstanceKey(player)
    if not instanceKey then
        sendIdle(player, opts.reason or "not_in_mythic")
        return false
    end
    local record = hudCache[instanceKey]
    if not record then
        record = fetchSnapshot(instanceKey)
    end
    if not record then
        sendIdle(player, "no_snapshot")
        return false
    end
    local guid = player:GetGUIDLow()
    local previous = guid and playerSnapshots[guid]
    if not opts.force and previous and previous.key == instanceKey and previous.updated == record.updated then
        return true
    end
    return sendPayload(player, record)
end

local function tick()
    if not AIO or not AIO.Handle then
        return
    end
    pullCacheUpdates()
    local players = GetPlayersInWorld() or {}
    for _, player in ipairs(players) do
        deliverSnapshot(player)
    end
end

CreateLuaEvent(tick, POLL_INTERVAL_MS, 0)
print(string.format("%s bridge active (poll %dms)", MODULE_PREFIX, POLL_INTERVAL_MS))

if Handlers then
    function Handlers.RequestHud(player, reason)
        deliverSnapshot(player, { force = true, reason = reason or "client" })
    end
    function Handlers.Ping(player)
        if AIO and AIO.Handle then
            AIO.Handle(player, ADDON_NAME, "PONG")
        end
    end
end
