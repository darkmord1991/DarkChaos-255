--[[
DC_DebugUtils.lua (addon-scoped copy)
Lightweight wrapper around the shared debug utility so the addon can operate even
if the global helper is not loaded separately.
]]

local DebugEnv = {}
DebugEnv.cacheMaxSize = 200
DebugEnv.dedupWindowSeconds = 2.0
DebugEnv.messageCache = {}

local function Hash(addonName, msg)
    return tostring(addonName) .. ":" .. tostring(msg)
end

local function CleanCache(self)
    local now = GetTime and GetTime() or 0
    local toRemove = {}
    for hash, entry in pairs(self.messageCache) do
        if now - entry.lastTime > self.dedupWindowSeconds then
            table.insert(toRemove, hash)
        end
    end
    for _, hash in ipairs(toRemove) do
        self.messageCache[hash] = nil
    end
    if self:GetCacheSize() > self.cacheMaxSize then
        local entries = {}
        for hash, entry in pairs(self.messageCache) do
            table.insert(entries, {hash = hash, time = entry.lastTime})
        end
        table.sort(entries, function(a, b) return a.time < b.time end)
        local removeCount = self:GetCacheSize() - self.cacheMaxSize
        for i = 1, removeCount do
            if entries[i] then
                self.messageCache[entries[i].hash] = nil
            end
        end
    end
end

function DebugEnv:GetCacheSize()
    local count = 0
    for _ in pairs(self.messageCache) do
        count = count + 1
    end
    return count
end

function DebugEnv:Print(addonName, msg, enabled)
    if not enabled then return end
    if not DEFAULT_CHAT_FRAME or not DEFAULT_CHAT_FRAME.AddMessage then return end

    local now = GetTime and GetTime() or 0
    local msgStr = tostring(msg)
    local hash = Hash(addonName, msgStr)

    if math.random() < 0.1 then
        CleanCache(self)
    end

    local entry = self.messageCache[hash]
    if entry then
        if now - entry.lastTime < self.dedupWindowSeconds then
            entry.count = entry.count + 1
            entry.lastTime = now
            return
        elseif entry.count > 1 then
            local repeatMsg = string.format("|cff33ff99[%s]|r %s |cffaaaaaa(repeated %dx)|r", addonName, msgStr, entry.count)
            pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, repeatMsg)
            entry.count = 1
            entry.lastTime = now
        end
    else
        self.messageCache[hash] = {msg = msgStr, count = 1, lastTime = now}
    end

    local formatted = string.format("|cff33ff99[%s]|r %s", addonName, msgStr)
    pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, formatted)
end

function DebugEnv:PrintMulti(addonName, enabled, ...)
    if not enabled then return end
    local args = {...}
    for i = 1, select('#', ...) do
        args[i] = tostring(args[i])
    end
    self:Print(addonName, table.concat(args, " "), true)
end

function DebugEnv:ClearCache()
    wipe(self.messageCache)
end

function DebugEnv:GetStats()
    local stats = {total = 0, repeated = 0, savedMessages = 0}
    for _, entry in pairs(self.messageCache) do
        stats.total = stats.total + 1
        if entry.count > 1 then
            stats.repeated = stats.repeated + 1
            stats.savedMessages = stats.savedMessages + (entry.count - 1)
        end
    end
    return stats
end

local DC_DebugUtils = _G.DC_DebugUtils or DebugEnv
_G.DC_DebugUtils = DC_DebugUtils

return DC_DebugUtils
