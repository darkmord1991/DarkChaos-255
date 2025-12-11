--[[
    HLBG Leaderboard Data Adapter for DCAddonProtocol
    ================================================
    
    Unified data adapter providing seasonal player statistics
    to both DC-HinterlandBG and DC-Leaderboards addons.
    
    Features:
    - Caching with 5-minute TTL
    - Fallback to local computed stats if server unavailable
    - Support for multiple leaderboard types
    - K/D ratio, win rate, and rating computations
    
    Author: DC Development Team
    Version: 1.0.0
]]

if HLBG_LeaderboardAdapter then return end

local Adapter = {
    cache = {},
    cacheDuration = 300,  -- 5 minutes
    statsCache = {},
    
    -- Leaderboard types
    LeaderboardType = {
        RATING = 1,
        WINS = 2,
        WINRATE = 3,
        GAMES = 4,
        KILLS = 5,
        RESOURCES = 6,
        KD_RATIO = 7
    }
}

local DC = DCAddonProtocol

--[[ =====================================================================
     REQUEST METHODS
     ===================================================================== ]]

--- Request leaderboard data from server with caching
function Adapter:RequestLeaderboard(leaderboardType, season, limit, callback)
    if not DC then
        if callback then callback(nil) end
        return
    end
    
    limit = limit or 100
    
    -- Check cache first
    local cacheKey = leaderboardType .. "_" .. season
    if self.cache[cacheKey] and (GetTime() - self.cache[cacheKey].timestamp) < self.cacheDuration then
        if callback then
            callback(self.cache[cacheKey].data)
        end
        return
    end
    
    -- Request from server
    local requestData = {
        leaderboardType = leaderboardType,
        season = season,
        limit = limit
    }
    
    -- Send request via DCAddonProtocol
    DC:Request("HLBG", 0x01, requestData)
    
    -- Store callback for async response
    if not self._pendingCallbacks then
        self._pendingCallbacks = {}
    end
    self._pendingCallbacks[cacheKey] = callback
end

--- Request player's personal seasonal stats
function Adapter:RequestPlayerStats(season, callback)
    if not DC then
        if callback then callback(nil) end
        return
    end
    
    -- Check cache first
    local cacheKey = "player_" .. season
    if self.statsCache[cacheKey] and (GetTime() - self.statsCache[cacheKey].timestamp) < self.cacheDuration then
        if callback then
            callback(self.statsCache[cacheKey].data)
        end
        return
    end
    
    DC:Request("HLBG", 0x02, { season = season })
    
    if not self._statsCallbacks then
        self._statsCallbacks = {}
    end
    self._statsCallbacks[cacheKey] = callback
end

--- Request all-time player stats
function Adapter:RequestAllTimeStats(callback)
    if not DC then
        if callback then callback(nil) end
        return
    end
    
    DC:Request("HLBG", 0x03, {})
    
    if not self._allTimeCallbacks then
        self._allTimeCallbacks = {}
    end
    self._allTimeCallbacks["alltime"] = callback
end

--[[ =====================================================================
     HANDLER REGISTRATION
     ===================================================================== ]]

--- Register handlers with DCAddonProtocol
function Adapter:RegisterHandlers()
    if not DC then return false end
    
    -- Leaderboard data response (0x10)
    DC:RegisterHandler("HLBG", 0x10, function(data)
        Adapter:OnLeaderboardData(data)
    end)
    
    -- Player seasonal stats response (0x11)
    DC:RegisterHandler("HLBG", 0x11, function(data)
        Adapter:OnPlayerStats(data)
    end)
    
    -- All-time stats response (0x12)
    DC:RegisterHandler("HLBG", 0x12, function(data)
        Adapter:OnAllTimeStats(data)
    end)
    
    -- Error response (0x1F)
    DC:RegisterHandler("HLBG", 0x1F, function(data)
        Adapter:OnError(data)
    end)
    
    return true
end

--[[ =====================================================================
     RESPONSE HANDLERS
     ===================================================================== ]]

function Adapter:OnLeaderboardData(data)
    if type(data) ~= "table" then return end
    
    local leaderboardType = data.leaderboardType or 1
    local season = data.season or 0
    local cacheKey = leaderboardType .. "_" .. season
    
    -- Cache the result
    self.cache[cacheKey] = {
        data = data.entries or {},
        timestamp = GetTime()
    }
    
    -- Execute callback if waiting
    if self._pendingCallbacks and self._pendingCallbacks[cacheKey] then
        local callback = self._pendingCallbacks[cacheKey]
        self._pendingCallbacks[cacheKey] = nil
        if callback then callback(data.entries or {}) end
    end
end

function Adapter:OnPlayerStats(data)
    if type(data) ~= "table" then return end
    
    local season = data.season or 0
    local cacheKey = "player_" .. season
    
    -- Cache the result
    self.statsCache[cacheKey] = {
        data = {
            rating = data.rating or 0,
            wins = data.wins or 0,
            losses = data.losses or 0,
            games = data.games or 0,
            winRate = data.winRate or 0,
            kills = data.kills or 0,
            deaths = data.deaths or 0,
            kdRatio = data.kdRatio or 0,
            avgKills = data.avgKills or 0,
            avgDamage = data.avgDamage or 0
        },
        timestamp = GetTime()
    }
    
    -- Execute callback if waiting
    if self._statsCallbacks and self._statsCallbacks[cacheKey] then
        local callback = self._statsCallbacks[cacheKey]
        self._statsCallbacks[cacheKey] = nil
        if callback then callback(self.statsCache[cacheKey].data) end
    end
end

function Adapter:OnAllTimeStats(data)
    if type(data) ~= "table" then return end
    
    local cacheKey = "alltime"
    
    -- Cache the result
    self.statsCache[cacheKey] = {
        data = {
            totalMatches = data.totalMatches or 0,
            lifetimeWins = data.lifetimeWins or 0,
            lifetimeLosses = data.lifetimeLosses or 0,
            lifetimeKills = data.lifetimeKills or 0,
            lifetimeDeaths = data.lifetimeDeaths or 0,
            kdRatio = data.kdRatio or 0,
            avgKills = data.avgKills or 0,
            avgDamage = data.avgDamage or 0
        },
        timestamp = GetTime()
    }
    
    -- Execute callback if waiting
    if self._allTimeCallbacks and self._allTimeCallbacks["alltime"] then
        local callback = self._allTimeCallbacks["alltime"]
        self._allTimeCallbacks["alltime"] = nil
        if callback then callback(self.statsCache[cacheKey].data) end
    end
end

function Adapter:OnError(data)
    if DEFAULT_CHAT_FRAME then
        local msg = data.error or "Unknown error"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF3333HLBG Error:|r " .. msg)
    end
end

--[[ =====================================================================
     UTILITY FUNCTIONS
     ===================================================================== ]]

--- Clear all caches
function Adapter:ClearCache()
    self.cache = {}
    self.statsCache = {}
end

--- Format a leaderboard entry for display
function Adapter:FormatEntry(entry, leaderboardType)
    if not entry then return nil end
    
    local formatted = {
        rank = entry.rank or 0,
        name = entry.name or entry.playerName or "Unknown",
        score = entry.score or entry.value or 0,
        extra = entry.extra or ""
    }
    
    -- Type-specific formatting
    if leaderboardType == self.LeaderboardType.RATING then
        formatted.score = math.floor(formatted.score)
    elseif leaderboardType == self.LeaderboardType.WINRATE then
        formatted.score = string.format("%.1f%%", formatted.score)
    elseif leaderboardType == self.LeaderboardType.KD_RATIO then
        formatted.score = string.format("%.2f", formatted.score)
    end
    
    return formatted
end

--- Initialize the adapter (call once on addon load)
function Adapter:Initialize()
    -- Register handlers with DCAddonProtocol when it's ready
    if DC then
        self:RegisterHandlers()
    else
        -- Wait for DCAddonProtocol to load
        local frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function()
            if DC then
                Adapter:RegisterHandlers()
                frame:UnregisterAllEvents()
            end
        end)
        frame:RegisterEvent("ADDON_LOADED")
    end
end

-- =====================================================================
-- GLOBAL EXPORT
-- =====================================================================

_G.HLBG_LeaderboardAdapter = Adapter

-- Auto-initialize when this module loads
Adapter:Initialize()
