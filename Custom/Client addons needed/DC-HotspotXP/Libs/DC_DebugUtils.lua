-- DC_DebugUtils.lua
-- Centralized debug logging utility for all DC addons
-- Embedded copy for DC-HotspotXP to avoid external dependency lookups

if not _G.DC_DebugUtils then
    _G.DC_DebugUtils = {}
end

local DC_Debug = _G.DC_DebugUtils

-- Message deduplication cache: [hash] = {msg=string, count=number, lastTime=number}
DC_Debug.messageCache = DC_Debug.messageCache or {}
DC_Debug.cacheMaxSize = 200
DC_Debug.dedupWindowSeconds = 2.0  -- Don't repeat same message within this window

-- Generate a simple hash for a message
local function MessageHash(addonName, msg)
    return tostring(addonName) .. ":" .. tostring(msg)
end

-- Clean old entries from cache
local function CleanCache()
    local now = GetTime()
    local toRemove = {}
    
    for hash, entry in pairs(DC_Debug.messageCache) do
        if now - entry.lastTime > DC_Debug.dedupWindowSeconds then
            table.insert(toRemove, hash)
        end
    end
    
    for _, hash in ipairs(toRemove) do
        DC_Debug.messageCache[hash] = nil
    end
    
    -- If cache is still too large, remove oldest entries
    if DC_Debug:GetCacheSize() > DC_Debug.cacheMaxSize then
        local entries = {}
        for hash, entry in pairs(DC_Debug.messageCache) do
            table.insert(entries, {hash = hash, time = entry.lastTime})
        end
        table.sort(entries, function(a, b) return a.time < b.time end)
        
        local removeCount = DC_Debug:GetCacheSize() - DC_Debug.cacheMaxSize
        for i = 1, removeCount do
            if entries[i] then
                DC_Debug.messageCache[entries[i].hash] = nil
            end
        end
    end
end

function DC_Debug:GetCacheSize()
    local count = 0
    for _ in pairs(self.messageCache) do
        count = count + 1
    end
    return count
end

-- Main debug print function with deduplication
-- Usage: DC_DebugUtils:Print("AddonName", "Debug message", isEnabled)
function DC_Debug:Print(addonName, msg, isEnabled)
    -- Skip if debug is disabled
    if not isEnabled then return end
    
    -- Skip if no chat frame
    if not DEFAULT_CHAT_FRAME or not DEFAULT_CHAT_FRAME.AddMessage then return end
    
    -- Convert message to string
    local msgStr = tostring(msg)
    local hash = MessageHash(addonName, msgStr)
    local now = GetTime()
    
    -- Clean cache periodically
    if math.random() < 0.1 then  -- 10% chance on each call
        CleanCache()
    end
    
    local entry = self.messageCache[hash]
    
    if entry then
        -- Message exists in cache
        if now - entry.lastTime < self.dedupWindowSeconds then
            -- Within dedup window - increment counter but don't print
            entry.count = entry.count + 1
            entry.lastTime = now
            return
        else
            -- Outside window - print with repeat count if > 1
            if entry.count > 1 then
                local repeatMsg = string.format("|cff33ff99[%s]|r %s |cffaaaaaa(repeated %dx)|r", 
                    addonName, msgStr, entry.count)
                pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, repeatMsg)
            end
            -- Reset entry
            entry.count = 1
            entry.lastTime = now
        end
    else
        -- New message
        self.messageCache[hash] = {msg = msgStr, count = 1, lastTime = now}
    end
    
    -- Print the message
    local formattedMsg = string.format("|cff33ff99[%s]|r %s", addonName, msgStr)
    pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, formattedMsg)
end

-- Convenience function for multiple arguments (like original print)
function DC_Debug:PrintMulti(addonName, isEnabled, ...)
    if not isEnabled then return end
    
    local args = {...}
    local parts = {}
    for i = 1, select('#', ...) do
        table.insert(parts, tostring(args[i]))
    end
    local msg = table.concat(parts, " ")
    
    self:Print(addonName, msg, true)
end

-- Clear all cached messages
function DC_Debug:ClearCache()
    self.messageCache = {}
end

-- Get statistics
function DC_Debug:GetStats()
    local total = 0
    local repeated = 0
    local totalRepeats = 0
    
    for _, entry in pairs(self.messageCache) do
        total = total + 1
        if entry.count > 1 then
            repeated = repeated + 1
            totalRepeats = totalRepeats + entry.count
        end
    end
    
    return {
        total = total,
        repeated = repeated,
        totalRepeats = totalRepeats,
        savedMessages = totalRepeats - repeated
    }
end

-- Slash command for statistics
SLASH_DCDEBUGSTATS1 = '/dcdebugstats'
SlashCmdList['DCDEBUGSTATS'] = function()
    local stats = DC_Debug:GetStats()
    print("|cff33ff99DC Debug Stats:|r")
    print(string.format("  Cached messages: %d", stats.total))
    print(string.format("  Repeated messages: %d", stats.repeated))
    print(string.format("  Total repeats prevented: %d", stats.savedMessages))
    print(string.format("  Cache size: %d/%d", DC_Debug:GetCacheSize(), DC_Debug.cacheMaxSize))
end

SLASH_DCDEBUGCLEAR1 = '/dcdebugclear'
SlashCmdList['DCDEBUGCLEAR'] = function()
    DC_Debug:ClearCache()
    print("|cff33ff99DC Debug:|r Message cache cleared")
end

print("|cff00ff00DC Debug Utils loaded|r - Use /dcdebugstats to see statistics")
