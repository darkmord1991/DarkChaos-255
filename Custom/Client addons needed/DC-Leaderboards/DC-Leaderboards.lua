--[[
    DC-Leaderboards - Unified Leaderboard Addon v1.4.0
    DarkChaos Full-Screen Leaderboard System
    
    Features:
    - Full-screen leaderboard display with category tabs
    - JSON protocol communication via DCAddonProtocol
    - Two settings tabs (General, Communication)
    - 8+ leaderboard categories with multiple subcategories
    - Caching for performance
    - Sorting and filtering options
    - Dungeon filtering for Mythic+ leaderboards
    
    Leaderboard Categories:
    1. Mythic+ (Best Key, Best Time, Most Runs, Best Score) - with dungeon filter
    2. Seasons (Tokens, Essence, Overall Points)
    3. HLBG (Rating, Wins, Win Rate, Total Games)
    4. Prestige (Prestige Level, Total Points)
    5. Item Upgrades (Total Upgrades, Efficiency, Highest Tier)
    6. Duels (Wins, Win Rate, Rating)
    7. AOE Loot (Looted Items, Filtered Items, Gold) - with separate quality columns
    8. Achievements (Points, Completions)
    
    v1.4.0 Changes:
    - Changed AOE Loot quality display from combined "L/E/R/U" to separate columns
    - Each quality (Legendary, Epic, Rare, Uncommon) now has its own dedicated column
    - Quality columns only shown for AOE Loot Items and Filtered Items subcategories
    
    v1.3.0 Changes:
    - Added dungeon filter dropdown for Mythic+ leaderboards
    - Added per-dungeon best run display with dungeon names
    - Fixed gold display to properly show copper value as formatted g/s/c
    - AOE Loot now shows individual quality columns (P/C/U/R/E/L)
    - AOE Loot Filtered shows breakdown of skipped items by quality
    - Wider extra column for quality breakdown display
    
    v1.2.0 Changes:
    - Simplified AOE Loot to 3 clear categories
    - Added FormatMoney() for proper gold display with colors
    - Fixed gold showing as 0 (now sends copper, client formats)
    
    v1.1.0 Changes:
    - Added quality breakdown for AOE Loot
    - Added filtered items tracking
    - Color-coded quality display
    
    Author: DarkChaos Development Team
    Date: November 30, 2025
]]

local ADDON_NAME = "DC-Leaderboards"
local VERSION = "1.4.0"

local addonNameGlobal = ...
if not addonNameGlobal or addonNameGlobal == "" then
    addonNameGlobal = ADDON_NAME
end
local ADDON_PATH = "Interface\\AddOns\\" .. addonNameGlobal .. "\\"
local BG_FELLEATHER = ADDON_PATH .. "Textures\\Backgrounds\\FelLeather_512.tga"
local BG_TINT_ALPHA = 0.60

-- Namespace
DCLeaderboards = DCLeaderboards or {}
local LB = DCLeaderboards

-- DCAddonProtocol reference (checked on PLAYER_LOGIN)
local DC = nil

-- =====================================================================
-- CONSTANTS
-- =====================================================================

-- Module ID for DC Protocol
LB.MODULE = "LBRD"

-- Opcodes
LB.Opcode = {
    -- Client -> Server
    CMSG_GET_LEADERBOARD = 0x01,      -- Request leaderboard data
    CMSG_GET_CATEGORIES = 0x02,       -- Request available categories
    CMSG_GET_MY_RANK = 0x03,          -- Request player's rank
    CMSG_REFRESH = 0x04,              -- Force refresh
    CMSG_TEST_TABLES = 0x05,          -- Test database tables
    CMSG_GET_SEASONS = 0x06,          -- Get available seasons
    CMSG_GET_MPLUS_DUNGEONS = 0x07,   -- v1.3.0: Get M+ dungeons list
    CMSG_GET_ACCOUNT_STATS = 0x08,    -- v1.5.0: Get account-wide statistics
    
    -- Server -> Client
    SMSG_LEADERBOARD_DATA = 0x10,     -- Leaderboard response
    SMSG_CATEGORIES = 0x11,           -- Available categories
    SMSG_MY_RANK = 0x12,              -- Player's rank info
    SMSG_TEST_RESULTS = 0x15,         -- Test results response
    SMSG_SEASONS_LIST = 0x16,         -- Available seasons list
    SMSG_MPLUS_DUNGEONS = 0x17,       -- v1.3.0: M+ dungeon list
    SMSG_ACCOUNT_STATS = 0x18,        -- v1.5.0: Account-wide stats
    SMSG_ERROR = 0x1F,                -- Error response
}

-- Leaderboard categories with subcategories
LB.Categories = {
    {
        id = "mplus",
        name = "Mythic+",
        icon = "Interface\\Icons\\INV_Relics_Hourglass",
        color = "ff8000",
        subcats = {
            { id = "mplus_key", name = "Best Key Level" },
            { id = "mplus_runs", name = "Total Runs" },
            { id = "mplus_score", name = "Overall Score" },
            { id = "mplus_bestruns", name = "Best Runs (w/ Dungeon)" },  -- v1.3.0
        },
        hasDungeonFilter = true,  -- v1.3.0: Enables dungeon selector
    },
    {
        id = "seasons",
        name = "Seasons",
        icon = "Interface\\Icons\\Achievement_General_StayClassy",
        color = "ffd700",
        subcats = {
            { id = "season_tokens", name = "Total Tokens" },
            { id = "season_essence", name = "Total Essence" },
            { id = "season_quests", name = "Quests Completed" },
            { id = "season_bosses", name = "Bosses Killed" },
        }
    },
    {
        id = "hlbg",
        name = "Hinterland BG",
        icon = "Interface\\Icons\\Achievement_BG_WinWSG",
        color = "c41f3b",
        subcats = {
            -- Seasonal stats (from dc_hlbg_player_season_data)
            { id = "hlbg_rating", name = "Season Rating" },
            { id = "hlbg_wins", name = "Season Wins" },
            { id = "hlbg_winrate", name = "Win Rate %" },
            { id = "hlbg_games", name = "Games Played" },
            -- All-time stats (from dc_hlbg_player_stats)
            { id = "hlbg_kills", name = "Total Kills" },
            { id = "hlbg_alltime_wins", name = "All-Time Wins" },
            { id = "hlbg_resources", name = "Resources Captured" },
        }
    },
    {
        id = "prestige",
        name = "Artifact Mastery",
        icon = "Interface\\Icons\\Achievement_Level_80",
        color = "a335ee",
        subcats = {
            { id = "prestige_level", name = "Mastery Level" },
            { id = "prestige_points", name = "Total Points" },
            { id = "prestige_artifacts", name = "Artifacts Unlocked" },
        }
    },
    {
        id = "upgrade",
        name = "Item Upgrades",
        icon = "Interface\\Icons\\INV_Misc_ArmorKit_01",
        color = "1eff00",
        subcats = {
            { id = "upgrade_tokens", name = "Tokens Invested" },
            { id = "upgrade_items", name = "Items Upgraded" },
            { id = "upgrade_essence", name = "Essence Invested" },
            { id = "upgrade_tier", name = "Highest Tier" },
        }
    },
    {
        id = "duel",
        name = "Duels",
        icon = "Interface\\Icons\\Ability_DualWield",
        color = "0070dd",
        subcats = {
            { id = "duel_wins", name = "Duel Wins" },
            { id = "duel_winrate", name = "Win Rate" },
            { id = "duel_total", name = "Total Duels" },
            { id = "duel_damage", name = "Damage Dealt" },
        }
    },
    {
        id = "aoe",
        name = "AOE Loot",
        icon = "Interface\\Icons\\INV_Misc_Bag_10_Green",
        color = "00ff96",
        subcats = {
            { id = "aoe_items", name = "Looted Items" },
            { id = "aoe_filtered", name = "Filtered Items" },
            { id = "aoe_gold", name = "Gold Collected" },
        }
    },
    {
        id = "achieve",
        name = "Achievements",
        icon = "Interface\\Icons\\Achievement_Quests_Completed_08",
        color = "ffff00",
        subcats = {
            { id = "achieve_completed", name = "Achievements Completed" },
            { id = "achieve_progress", name = "Total Progress" },
        }
    },
    {
        id = "statistics",
        name = "Statistics",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        color = "ffffff",
        subcats = {
            { id = "stats_char", name = "Character Overview" },
            { id = "stats_account", name = "Account Overview" },
        }
    },
}

-- Default settings
LB.DefaultSettings = {
    -- General settings
    showOnLogin = false,
    autoRefreshInterval = 60,  -- seconds, 0 to disable
    defaultCategory = "mplus",
    defaultSubCategory = "mplus_key",
    entriesPerPage = 25,
    highlightSelf = true,
    showClassColors = true,
    showFactionIcons = true,
    frameScale = 1.0,
    soundOnRefresh = true,
    
    -- Communication settings
    useJSONProtocol = true,
    cacheLifetime = 30,  -- seconds
    autoRetry = true,
    maxRetries = 3,
    verboseLogging = false,
    
    -- Testing/Debug settings
    selectedSeasonId = 0,  -- 0 = current season
    
    -- UI position (saved when frame is dragged)
    framePosition = nil,
}

-- Available seasons (populated from server)
LB.AvailableSeasons = {
    { id = 0, name = "Current Season (Auto)" },
}

-- v1.3.0: Available M+ dungeons (populated from server)
LB.MythicPlusDungeons = {
    -- { mapId = X, name = "Dungeon Name" }
}
LB.SelectedDungeonMapId = 0  -- 0 = "All Dungeons"

-- =====================================================================
-- DATA CACHE
-- =====================================================================

LB.Cache = {
    data = {},          -- Cached leaderboard data by category_subcat key
    timestamps = {},    -- When each cache was last updated
    myRanks = {},       -- Player's own rank in each category
    playerRank = nil,   -- Player's overall rank info
    accountStats = nil, -- v1.5.0: Account-wide statistics
}

-- =====================================================================
-- CACHE TTL CONSTANTS (seconds)
-- =====================================================================

local CACHE_TTL_SEASONS = 3600       -- 1 hour (seasons rarely change)
local CACHE_TTL_DUNGEONS = 86400     -- 24 hours (dungeons only change on season reset)
local CACHE_TTL_CATEGORIES = 86400   -- 24 hours (categories are static)

-- =====================================================================
-- UI FRAMES
-- =====================================================================

LB.Frames = {}

-- =====================================================================
-- SETTINGS MANAGEMENT
-- =====================================================================

function LB:InitializeSettings()
    DCLeaderboardsDB = DCLeaderboardsDB or {}
    for key, value in pairs(LB.DefaultSettings) do
        if DCLeaderboardsDB[key] == nil then
            DCLeaderboardsDB[key] = value
        end
    end
    
    -- Initialize persistent cache structure
    DCLeaderboardsDB.cache = DCLeaderboardsDB.cache or {}
    DCLeaderboardsDB.cache.seasons = DCLeaderboardsDB.cache.seasons or {}
    DCLeaderboardsDB.cache.seasonsTime = DCLeaderboardsDB.cache.seasonsTime or 0
    DCLeaderboardsDB.cache.dungeons = DCLeaderboardsDB.cache.dungeons or {}
    DCLeaderboardsDB.cache.dungeonsTime = DCLeaderboardsDB.cache.dungeonsTime or 0
    DCLeaderboardsDB.cache.dungeonsSeasonId = DCLeaderboardsDB.cache.dungeonsSeasonId or 0
    
    -- Restore cached seasons if still fresh
    local now = time()
    if #DCLeaderboardsDB.cache.seasons > 0 and (now - DCLeaderboardsDB.cache.seasonsTime) < CACHE_TTL_SEASONS then
        LB.AvailableSeasons = { { id = 0, name = "Current Season (Auto)" } }
        for _, s in ipairs(DCLeaderboardsDB.cache.seasons) do
            table.insert(LB.AvailableSeasons, s)
        end
    end
    
    -- Restore cached dungeons if still fresh
    if #DCLeaderboardsDB.cache.dungeons > 0 and (now - DCLeaderboardsDB.cache.dungeonsTime) < CACHE_TTL_DUNGEONS then
        LB.MythicPlusDungeons = DCLeaderboardsDB.cache.dungeons
    end
end

function LB:GetSetting(key)
    return DCLeaderboardsDB and DCLeaderboardsDB[key]
end

function LB:SetSetting(key, value)
    if not DCLeaderboardsDB then DCLeaderboardsDB = {} end
    DCLeaderboardsDB[key] = value
end

-- =====================================================================
-- UTILITY FUNCTIONS
-- =====================================================================

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff96[DC-Leaderboards]|r " .. tostring(msg or ""))
end

local function FormatNumber(num)
    if not num then return "0" end
    num = tonumber(num) or 0
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    end
    return tostring(num)
end

-- Format copper value to gold/silver/copper string
local function FormatMoney(copper)
    if not copper then return "0g" end
    copper = tonumber(copper) or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    
    if gold >= 1000 then
        return string.format("|cffffd700%.1fK|rg", gold / 1000)
    elseif gold > 0 then
        if silver > 0 then
            return string.format("|cffffd700%d|rg |cffc0c0c0%d|rs", gold, silver)
        else
            return string.format("|cffffd700%d|rg", gold)
        end
    elseif silver > 0 then
        return string.format("|cffc0c0c0%d|rs |cffcd7f32%d|rc", silver, cop)
    else
        return string.format("|cffcd7f32%d|rc", cop)
    end
end

local function FormatTime(seconds)
    if not seconds or seconds <= 0 then return "--:--" end
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%d:%02d", mins, secs)
end

local function FormatPercent(value)
    if not value then return "0%" end
    return string.format("%.1f%%", value)
end

local CLASS_COLORS = {
    WARRIOR = "C79C6E",
    PALADIN = "F58CBA",
    HUNTER = "ABD473",
    ROGUE = "FFF569",
    PRIEST = "FFFFFF",
    DEATHKNIGHT = "C41F3B",
    SHAMAN = "0070DE",
    MAGE = "69CCF0",
    WARLOCK = "9482C9",
    DRUID = "FF7D0A",
}

local function GetClassColor(class)
    return CLASS_COLORS[class] or "FFFFFF"
end

-- =====================================================================
-- COMMUNICATION FUNCTIONS
-- =====================================================================

function LB:RequestLeaderboard(category, subcategory, page, limit)
    if not DC then
        Print("|cffff0000DCAddonProtocol not available|r")
        return false
    end
    
    page = page or 1
    limit = limit or (self:GetSetting("entriesPerPage") or 25)
    local seasonId = self:GetSetting("selectedSeasonId") or 0
    
    local request = {
        category = category,
        subcategory = subcategory,
        page = page,
        limit = limit,
        seasonId = seasonId,
    }
    
    -- For HLBG category, translate subcategory to leaderboard type
    if category == "hlbg" then
        local leaderboardType = self.HLBGLeaderboardTypes[subcategory]
        if leaderboardType then
            request.leaderboardType = leaderboardType
            Print("|cff00ccffRequesting:|r HLBG/" .. subcategory .. " (type " .. leaderboardType .. ", page " .. page .. ")")
        else
            Print("|cffff0000Error:|r Unknown HLBG subcategory: " .. tostring(subcategory))
            return false
        end
    else
        -- Always show request being made for debugging
        local reqStr = "|cff00ccffRequesting:|r " .. category .. "/" .. subcategory .. " (page " .. page .. ", season " .. seasonId .. ")"
        if category == "seasons" then
            reqStr = "|cff00ffffSeasons: " .. reqStr .. "|r"
        end
        Print(reqStr)
    end
    
    DC:Request(self.MODULE, self.Opcode.CMSG_GET_LEADERBOARD, request)
    
    return true
end

function LB:RequestMyRank(category, subcategory)
    if not DC then return false end
    
    DC:Request(self.MODULE, self.Opcode.CMSG_GET_MY_RANK, {
        category = category,
        subcategory = subcategory,
    })
    return true
end

function LB:RequestCategories()
    if not DC then return false end
    DC:Request(self.MODULE, self.Opcode.CMSG_GET_CATEGORIES, {})
    return true
end

-- v1.3.0: Request M+ dungeons for current season
function LB:RequestMythicPlusDungeons()
    local seasonId = self:GetSetting("selectedSeasonId") or 0
    
    -- Check cache first
    local now = time()
    if DCLeaderboardsDB and DCLeaderboardsDB.cache and DCLeaderboardsDB.cache.dungeonsTime then
       local cachedSeasonId = DCLeaderboardsDB.cache.dungeonsSeasonId or 0
       if (now - DCLeaderboardsDB.cache.dungeonsTime) < CACHE_TTL_DUNGEONS and cachedSeasonId == seasonId then
           if #DCLeaderboardsDB.cache.dungeons > 0 then
               LB.MythicPlusDungeons = DCLeaderboardsDB.cache.dungeons
               Print("Using cached M+ dungeons list")
               if LB.Frames.dungeonDropdown and LB.currentCategory == "mplus" then
                    LB:UpdateDungeonDropdownItems()
               end
               return true
           end
       end
    end

    if not DC then return false end
    
    DC:Request(self.MODULE, self.Opcode.CMSG_GET_MPLUS_DUNGEONS, {
        seasonId = seasonId,
    })
    return true
end

-- v1.5.0: Request account-wide statistics
function LB:RequestAccountStats()
    if not DC then 
        Print("|cffff0000DCAddonProtocol not available|r")
        return false
    end
    
    Print("|cff00ccffRequesting account-wide statistics...|r")
    DC:Request(self.MODULE, self.Opcode.CMSG_GET_ACCOUNT_STATS, {})
    return true
end

function LB:ForceRefresh()
    if not DC then return false end
    
    -- Clear cache
    self.Cache.data = {}
    self.Cache.timestamps = {}
    
    DC:Request(self.MODULE, self.Opcode.CMSG_REFRESH, {})
    
    -- Re-request current view
    if self.Frames.main and self.Frames.main:IsShown() then
        local cat = self.currentCategory or "mplus"
        local subcat = self.currentSubCategory or "mplus_key"
        self:RequestLeaderboard(cat, subcat)
    end
    
    if self:GetSetting("soundOnRefresh") then
        PlaySound("INTERFACESOUND_LOSTTARGETUNIT")
    end
    
    Print("Leaderboard data refreshed")
    return true
end

-- =====================================================================
-- HLBG SUBCATEGORY MAPPING
-- =====================================================================

-- Maps DC-Leaderboards HLBG subcategory IDs to server leaderboard type numbers
-- These match the unified HLBG protocol leaderboard types (1-7)
LB.HLBGLeaderboardTypes = {
    hlbg_rating = 1,        -- Season Rating
    hlbg_wins = 2,          -- Season Wins
    hlbg_winrate = 3,       -- Win Rate %
    hlbg_games = 4,         -- Games Played
    hlbg_kills = 5,         -- Total Kills (all-time)
    hlbg_alltime_wins = 6,  -- All-Time Wins
    hlbg_resources = 7,     -- Resources Captured
}

-- =====================================================================
-- PROTOCOL HANDLERS
-- =====================================================================

function LB:RegisterHandlers()
    if not DC then
        Print("|cffff0000DCAddonProtocol not found, handlers not registered|r")
        return false
    end
    
    -- Debug: Show what we're registering
    Print("Registering handlers for module: " .. self.MODULE)
    
    -- Leaderboard data response
    local dataOpcode = self.Opcode.SMSG_LEADERBOARD_DATA
    Print("  SMSG_LEADERBOARD_DATA opcode: " .. tostring(dataOpcode) .. " (key: " .. self.MODULE .. "_" .. dataOpcode .. ")")
    
    DC:RegisterHandler(self.MODULE, dataOpcode, function(...)
        LB:OnLeaderboardData(...)
    end)
    
    -- Categories response
    DC:RegisterHandler(self.MODULE, self.Opcode.SMSG_CATEGORIES, function(...)
        LB:OnCategoriesData(...)
    end)
    
    -- My rank response
    DC:RegisterHandler(self.MODULE, self.Opcode.SMSG_MY_RANK, function(...)
        LB:OnMyRankData(...)
    end)
    
    -- Test results response
    DC:RegisterHandler(self.MODULE, self.Opcode.SMSG_TEST_RESULTS, function(...)
        LB:OnTestResults(...)
    end)
    
    -- Seasons list response
    DC:RegisterHandler(self.MODULE, self.Opcode.SMSG_SEASONS_LIST, function(...)
        LB:OnSeasonsList(...)
    end)
    
    -- v1.3.0: M+ dungeons list response
    DC:RegisterHandler(self.MODULE, self.Opcode.SMSG_MPLUS_DUNGEONS, function(...)
        LB:OnMythicPlusDungeons(...)
    end)
    
    -- v1.5.0: Account stats response
    DC:RegisterHandler(self.MODULE, self.Opcode.SMSG_ACCOUNT_STATS, function(...)
        LB:OnAccountStats(...)
    end)
    
    -- Error response
    DC:RegisterHandler(self.MODULE, self.Opcode.SMSG_ERROR, function(...)
        LB:OnError(...)
    end)
    
    Print("|cff00ff00Protocol handlers registered successfully|r")
    return true
end

-- Handler for test results
function LB:OnTestResults(data)
    if type(data) ~= "table" then
        Print("|cffff0000Test Results: Invalid data received|r")
        return
    end
    
    Print("|cffffd700=== Database Table Test Results ===|r")
    
    if data.tables then
        for _, tbl in ipairs(data.tables) do
            local status = tbl.exists and "|cff00ff00EXISTS|r" or "|cffff0000MISSING|r"
            local countStr = tbl.exists and (" (" .. tostring(tbl.count) .. " rows)") or ""
            Print("  " .. tbl.name .. ": " .. status .. countStr)
        end
    end
    
    if data.currentSeason then
        Print("|cffffd700Current Season:|r " .. tostring(data.currentSeason))
    end
    
    Print("|cffffd700================================|r")
end

-- Handler for seasons list
function LB:OnSeasonsList(data)
    if type(data) ~= "table" then
        Print("|cffff0000Seasons List: Invalid data received|r")
        return
    end
    
    -- Update available seasons
    LB.AvailableSeasons = {
        { id = 0, name = "Current Season (Auto)" },
    }
    
    local seasonsToCache = {}
    if data.seasons then
        for _, season in ipairs(data.seasons) do
            local entry = {
                id = season.id,
                name = "Season " .. season.id .. (season.active and " (Active)" or ""),
            }
            table.insert(LB.AvailableSeasons, entry)
            table.insert(seasonsToCache, entry)
        end
    end
    
    -- Persist to SavedVariables
    if DCLeaderboardsDB and DCLeaderboardsDB.cache then
        DCLeaderboardsDB.cache.seasons = seasonsToCache
        DCLeaderboardsDB.cache.seasonsTime = time()
    end
    
    Print("|cff00ff00Received " .. #LB.AvailableSeasons .. " seasons (cached)|r")

    -- Update any season UI that exists (main selector and/or settings panel)
    LB:UpdateSeasonDropdown()
end

-- v1.3.0: Handler for M+ dungeons list
function LB:OnMythicPlusDungeons(data)
    if type(data) ~= "table" then
        Print("|cffff0000M+ Dungeons: Invalid data received|r")
        return
    end
    
    -- Update available dungeons
    LB.MythicPlusDungeons = {}
    
    if data.dungeons then
        for _, dungeon in ipairs(data.dungeons) do
            table.insert(LB.MythicPlusDungeons, {
                mapId = dungeon.mapId,
                name = dungeon.name,
            })
        end
    end
    
    -- Persist to SavedVariables
    if DCLeaderboardsDB and DCLeaderboardsDB.cache then
        DCLeaderboardsDB.cache.dungeons = LB.MythicPlusDungeons
        DCLeaderboardsDB.cache.dungeonsTime = time()
        DCLeaderboardsDB.cache.dungeonsSeasonId = data.seasonId or 0
    end
    
    Print("|cff00ff00Received " .. #LB.MythicPlusDungeons .. " M+ dungeons for season " .. (data.seasonId or "?") .. " (cached)|r")
    
    -- Update dungeon dropdown if it exists
    if LB.Frames.dungeonDropdown and LB.currentCategory == "mplus" then
        LB:UpdateDungeonDropdownItems()
    end
end

-- v1.5.0: Handler for account statistics
function LB:OnAccountStats(data)
    if type(data) ~= "table" then
        Print("|cffff0000Account Stats: Invalid data received|r")
        return
    end
    
    -- Store in cache
    -- Expected format: { characters = { {name, class, ...}, ... }, totals = { ... }, bestRanks = { ... } }
    self.Cache.accountStats = data
    
    Print("|cff00ff00Received account statistics|r")
    if data.characters then
        Print("  Characters: " .. #data.characters)
    end
    
    -- Update UI if on Account Overview
    if self.Frames.main and self.Frames.main:IsShown() and self.currentSubCategory == "stats_account" then
        self:UpdateStatisticsDisplay()
    end
end

-- Request test of database tables
function LB:TestDatabaseTables()
    if not DC then
        Print("|cffff0000DCAddonProtocol not available|r")
        return
    end
    
    Print("|cff00ccffTesting database tables...|r")
    DC:Request(self.MODULE, self.Opcode.CMSG_TEST_TABLES, {})
end

-- Request available seasons
function LB:RequestSeasons()
    -- Check cache first
    local now = time()
    if DCLeaderboardsDB and DCLeaderboardsDB.cache and DCLeaderboardsDB.cache.seasonsTime then
       if (now - DCLeaderboardsDB.cache.seasonsTime) < CACHE_TTL_SEASONS then
           if #DCLeaderboardsDB.cache.seasons > 0 then
                -- Already have valid seasons, ensure LB.AvailableSeasons is synced
                local found = false
                if #LB.AvailableSeasons > 1 then found = true end
                
                if not found then
                    LB.AvailableSeasons = { { id = 0, name = "Current Season (Auto)" } }
                    for _, s in ipairs(DCLeaderboardsDB.cache.seasons) do
                        table.insert(LB.AvailableSeasons, s)
                    end
                end
                
                LB:UpdateSeasonDropdown()
                Print("Using cached seasons list")
                return
           end
       end
    end

    if not DC then
        Print("|cffff0000DCAddonProtocol not available|r")
        return
    end
    
    DC:Request(self.MODULE, self.Opcode.CMSG_GET_SEASONS, {})
end

function LB:OnLeaderboardData(data)
    -- Debug: Always print what we receive
    if self:GetSetting("verboseLogging") then
        Print("OnLeaderboardData called with type: " .. type(data))
        if type(data) == "table" then
            Print("  category: " .. tostring(data.category))
            Print("  subcategory: " .. tostring(data.subcategory))
            Print("  totalEntries: " .. tostring(data.totalEntries))
            Print("  entries count: " .. tostring(data.entries and #data.entries or "nil"))
        end
    end
    
    if type(data) ~= "table" then 
        Print("|cffff6600Warning: Received non-table leaderboard data|r")
        return 
    end
    
    local category = data.category or "unknown"
    local subcategory = data.subcategory or "unknown"
    local key = category .. "_" .. subcategory
    
    -- Store in cache
    self.Cache.data[key] = data.entries or {}
    self.Cache.timestamps[key] = time()
    
    -- Store pagination info
    self.Cache.totalEntries = data.totalEntries or #(data.entries or {})
    self.Cache.currentPage = data.page or 1
    self.Cache.totalPages = data.totalPages or 1
    
    -- Always print successful receive
    Print("|cff00ff00Received " .. #(data.entries or {}) .. " entries for " .. key .. "|r")
    
    -- Update UI if visible
    if self.Frames.main and self.Frames.main:IsShown() then
        self:UpdateLeaderboardDisplay()
    end
    
    if self:GetSetting("verboseLogging") then
        if category == "hlbg" then
            for i = 1, math.min(3, #(data.entries or {})) do
                local e = data.entries[i]
                if e then
                    Print(string.format("  [%d] name=%s score=%s extra=%s", i, tostring(e.name or e.playerName or "?"), tostring(e.score or e.value or "nil"), tostring(e.extra or "nil")))
                end
            end
        end
    end
end

function LB:OnCategoriesData(data)
    if type(data) ~= "table" then return end
    -- Server might send additional categories or modify existing ones
    -- For now, we use hardcoded categories
    if self:GetSetting("verboseLogging") then
        Print("Categories data received")
    end
end

function LB:OnMyRankData(data)
    if type(data) ~= "table" then return end
    
    local category = data.category or "unknown"
    local subcategory = data.subcategory or "unknown"
    local key = category .. "_" .. subcategory
    
    self.Cache.myRanks[key] = {
        rank = data.rank,
        score = data.score,
        percentile = data.percentile,
    }
    
    -- Update UI
    if self.Frames.main and self.Frames.main:IsShown() then
        self:UpdatePlayerRankDisplay()
    end
end

function LB:OnError(data)
    if type(data) == "table" then
        Print("|cffff0000Error:|r " .. (data.message or "Unknown error"))
    else
        Print("|cffff0000Protocol error|r")
    end
end

-- =====================================================================
-- MAIN FRAME CREATION
-- =====================================================================

function LB:CreateMainFrame()
    if self.Frames.main then return self.Frames.main end
    
    -- Main moveable frame (not full-screen)
    local frame = CreateFrame("Frame", "DCLeaderboardsMainFrame", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetSize(900, 620)
    frame:SetPoint("CENTER")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    
    -- Enable dragging
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relPoint, x, y = self:GetPoint()
        LB:SetSetting("framePosition", {point = point, relPoint = relPoint, x = x, y = y})
    end)
    
    -- Restore saved position
    local savedPos = self:GetSetting("framePosition")
    if savedPos and savedPos.point then
        frame:ClearAllPoints()
        frame:SetPoint(savedPos.point, UIParent, savedPos.relPoint, savedPos.x, savedPos.y)
    end
    
    -- Background
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints()
    bg:SetTexture(BG_FELLEATHER)
    if bg.SetHorizTile then bg:SetHorizTile(false) end
    if bg.SetVertTile then bg:SetVertTile(false) end

    local bgTint = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    bgTint:SetAllPoints()
    bgTint:SetTexture(0, 0, 0, BG_TINT_ALPHA)
    
    -- Border
    local border = CreateFrame("Frame", nil, frame)
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    
    -- Title bar (draggable area indicator)
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetSize(880, 30)
    titleBar:SetPoint("TOP", 0, -5)
    local titleBarBg = titleBar:CreateTexture(nil, "ARTWORK")
    titleBarBg:SetAllPoints()
    titleBarBg:SetTexture(0.15, 0.15, 0.15, 0.5)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("|cff00ff96DC Leaderboards|r")
    frame.title = title
    
    -- Drag hint
    local dragHint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dragHint:SetPoint("TOP", title, "BOTTOM", 0, -2)
    dragHint:SetText("|cff888888(drag to move)|r")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    -- ESC to close
    tinsert(UISpecialFrames, "DCLeaderboardsMainFrame")
    
    -- Create category tabs (left side)
    self:CreateCategoryTabs(frame)
    
    -- Create content area
    self:CreateContentArea(frame)
    
    -- Create bottom bar with page controls and player rank
    self:CreateBottomBar(frame)
    
    -- Create season selector (bottom left)
    self:CreateSeasonSelector(frame)
    
    -- v1.3.0: Create dungeon selector (bottom right, for M+ category)
    self:CreateDungeonSelector(frame)
    
    -- Create settings button
    local settingsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    settingsBtn:SetSize(80, 22)
    settingsBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -5, -6)
    settingsBtn:SetText("Settings")
    settingsBtn:SetScript("OnClick", function()
        self:OpenSettings()
    end)
    
    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(80, 22)
    refreshBtn:SetPoint("RIGHT", settingsBtn, "LEFT", -5, 0)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        self:ForceRefresh()
    end)
    
    self.Frames.main = frame
    frame.container = frame -- For compatibility
    return frame
end

function LB:CreateCategoryTabs(parent)
    local tabFrame = CreateFrame("Frame", nil, parent)
    tabFrame:SetSize(150, 520)
    tabFrame:SetPoint("TOPLEFT", 15, -50)
    self.Frames.categoryTabs = tabFrame
    
    -- Category header
    local header = tabFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOP", 0, 0)
    header:SetText("|cffffd700Categories|r")
    
    -- Create category buttons
    local yOffset = -25
    self.categoryButtons = {}
    
    for i, cat in ipairs(self.Categories) do
        local btn = CreateFrame("Button", nil, tabFrame)
        btn:SetSize(140, 28)
        btn:SetPoint("TOPLEFT", 0, yOffset)
        
        -- Button background
        local btnBg = btn:CreateTexture(nil, "BACKGROUND")
        btnBg:SetAllPoints()
        btnBg:SetTexture(0.2, 0.2, 0.2, 0.8)
        btn.bg = btnBg
        
        -- Icon
        local icon = btn:CreateTexture(nil, "OVERLAY")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", 5, 0)
        icon:SetTexture(cat.icon)
        
        -- Text
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        text:SetText("|cff" .. cat.color .. cat.name .. "|r")
        
        btn:SetScript("OnClick", function()
            self:SelectCategory(cat.id)
        end)
        
        btn:SetScript("OnEnter", function(self)
            self.bg:SetTexture(0.4, 0.4, 0.4, 0.8)
        end)
        
        btn:SetScript("OnLeave", function(self)
            if LB.currentCategory == cat.id then
                self.bg:SetTexture(0.3, 0.5, 0.3, 0.8)
            else
                self.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
            end
        end)
        
        self.categoryButtons[cat.id] = btn
        yOffset = yOffset - 32
    end
end

function LB:CreateContentArea(parent)
    local content = CreateFrame("Frame", nil, parent)
    content:SetSize(700, 520)
    content:SetPoint("TOPRIGHT", -15, -50)
    self.Frames.content = content
    
    -- Statistics Frame (Hidden by default)
    local statsFrame = CreateFrame("Frame", nil, content)
    statsFrame:SetAllPoints()
    statsFrame:Hide()
    self.Frames.statsFrame = statsFrame
    
    self:CreateStatisticsUI(statsFrame)
    
    -- Subcategory tabs (top of content)
    local subTabFrame = CreateFrame("Frame", nil, content)
    subTabFrame:SetSize(700, 30)
    subTabFrame:SetPoint("TOP", 0, 0)
    self.Frames.subTabs = subTabFrame
    
    -- Leaderboard scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "DCLeaderboardsScrollFrame", content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(680, 440)
    scrollFrame:SetPoint("TOP", subTabFrame, "BOTTOM", 0, -10)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(660, 1)  -- Height will grow
    scrollFrame:SetScrollChild(scrollChild)
    self.Frames.scrollChild = scrollChild
    
    -- Column headers
    local headerFrame = CreateFrame("Frame", nil, content)
    headerFrame:SetSize(660, 25)
    headerFrame:SetPoint("TOP", subTabFrame, "BOTTOM", 0, -5)
    self.Frames.headers = headerFrame
    
    local headerBg = headerFrame:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetTexture(0.15, 0.15, 0.15, 0.9)
    
    -- Rank header
    local rankHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankHeader:SetPoint("LEFT", 10, 0)
    rankHeader:SetText("|cffffd700#|r")
    
    -- Name header
    local nameHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameHeader:SetPoint("LEFT", 50, 0)
    nameHeader:SetText("|cffffd700Player|r")
    
    -- Score header (will be updated based on subcategory)
    local scoreHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scoreHeader:SetPoint("LEFT", 300, 0)
    scoreHeader:SetText("|cffffd700Score|r")
    self.Frames.scoreHeader = scoreHeader
    
    -- Class header
    local classHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classHeader:SetPoint("LEFT", 390, 0)
    classHeader:SetText("|cffffd700Class|r")
    
    -- Extra info header
    local extraHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    extraHeader:SetPoint("LEFT", 470, 0)
    extraHeader:SetText("|cffffd700Info|r")
    self.Frames.extraHeader = extraHeader
    
    -- Quality breakdown headers (for AOE Loot category) - hidden by default
    -- L (Legendary)
    local legHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    legHeader:SetPoint("LEFT", 540, 0)
    legHeader:SetText("|cffff8000L|r")
    legHeader:Hide()
    self.Frames.legHeader = legHeader
    
    -- E (Epic)
    local epicHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    epicHeader:SetPoint("LEFT", 570, 0)
    epicHeader:SetText("|cffa335eeE|r")
    epicHeader:Hide()
    self.Frames.epicHeader = epicHeader
    
    -- R (Rare)
    local rareHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rareHeader:SetPoint("LEFT", 600, 0)
    rareHeader:SetText("|cff0070ddR|r")
    rareHeader:Hide()
    self.Frames.rareHeader = rareHeader
    
    -- U (Uncommon)
    local unHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    unHeader:SetPoint("LEFT", 630, 0)
    unHeader:SetText("|cff1eff00U|r")
    unHeader:Hide()
    self.Frames.unHeader = unHeader
    
    -- Adjust scroll frame position to be below headers
    scrollFrame:SetPoint("TOP", headerFrame, "BOTTOM", 0, -5)
    scrollFrame:SetSize(680, 420)
    
    -- Entry pool for recycling
    self.entryPool = {}
end

function LB:CreateBottomBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(700, 40)
    bar:SetPoint("BOTTOM", parent, "BOTTOM", 50, 15)
    self.Frames.bottomBar = bar
    
    -- Page info
    local pageInfo = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pageInfo:SetPoint("CENTER", 0, 0)
    pageInfo:SetText("Page 1 / 1")
    self.Frames.pageInfo = pageInfo
    
    -- Prev button
    local prevBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    prevBtn:SetSize(80, 22)
    prevBtn:SetPoint("RIGHT", pageInfo, "LEFT", -20, 0)
    prevBtn:SetText("< Prev")
    prevBtn:SetScript("OnClick", function()
        self:PreviousPage()
    end)
    self.Frames.prevBtn = prevBtn
    
    -- Next button
    local nextBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    nextBtn:SetSize(80, 22)
    nextBtn:SetPoint("LEFT", pageInfo, "RIGHT", 20, 0)
    nextBtn:SetText("Next >")
    nextBtn:SetScript("OnClick", function()
        self:NextPage()
    end)
    self.Frames.nextBtn = nextBtn
    
    -- Player rank display
    local myRank = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    myRank:SetPoint("LEFT", 10, 0)
    myRank:SetText("Your rank: |cffffffff--")
    self.Frames.myRank = myRank
    
    -- Total players
    local totalPlayers = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalPlayers:SetPoint("RIGHT", -10, 0)
    totalPlayers:SetText("Total: |cffffffff0|r players")
    self.Frames.totalPlayers = totalPlayers
end

-- =====================================================================
-- SEASON SELECTOR (Bottom Left)
-- =====================================================================

function LB:CreateSeasonSelector(parent)
    local seasonFrame = CreateFrame("Frame", nil, parent)
    seasonFrame:SetSize(150, 60)
    seasonFrame:SetPoint("BOTTOMLEFT", 15, 15)
    self.Frames.seasonSelector = seasonFrame
    
    -- Background
    local bg = seasonFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0.1, 0.1, 0.1, 0.7)
    
    -- Label
    local label = seasonFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 5, -5)
    label:SetText("|cffffd700Season:|r")
    
    -- Current season display
    local seasonText = seasonFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    seasonText:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
    seasonText:SetText("|cff00ff00Current (Auto)|r")
    self.Frames.seasonText = seasonText
    
    -- Create dropdown-style button
    local dropBtn = CreateFrame("Button", "DCLeaderboardsSeasonDropdown", seasonFrame, "UIPanelButtonTemplate")
    dropBtn:SetSize(140, 20)
    dropBtn:SetPoint("BOTTOMLEFT", 5, 5)
    dropBtn:SetText("Change Season")
    dropBtn:SetScript("OnClick", function()
        self:ToggleSeasonDropdown()
    end)
    self.Frames.seasonDropBtn = dropBtn
    
    -- Create dropdown menu (hidden by default)
    local dropdown = CreateFrame("Frame", "DCLeaderboardsSeasonMenu", seasonFrame)
    dropdown:SetSize(140, 10) -- Will resize based on content
    dropdown:SetPoint("BOTTOM", dropBtn, "TOP", 0, 2)
    dropdown:SetFrameStrata("DIALOG")
    dropdown:Hide()
    
    local dropBg = dropdown:CreateTexture(nil, "BACKGROUND")
    dropBg:SetAllPoints()
    dropBg:SetTexture(0.1, 0.1, 0.1, 0.95)
    
    local dropBorder = CreateFrame("Frame", nil, dropdown)
    dropBorder:SetAllPoints()
    dropBorder:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    
    self.Frames.seasonDropdown = dropdown
    
    -- Request seasons on load
    if DC then
        self:RequestSeasons()
    end
end

-- =====================================================================
-- v1.3.0: DUNGEON SELECTOR (Bottom Right - for M+ category)
-- =====================================================================

function LB:CreateDungeonSelector(parent)
    local dungeonFrame = CreateFrame("Frame", nil, parent)
    dungeonFrame:SetSize(180, 60)
    dungeonFrame:SetPoint("BOTTOMRIGHT", -15, 15)
    dungeonFrame:Hide()  -- Only shown when M+ category is selected
    self.Frames.dungeonSelector = dungeonFrame
    
    -- Background
    local bg = dungeonFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0.1, 0.1, 0.1, 0.7)
    
    -- Label
    local label = dungeonFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 5, -5)
    label:SetText("|cffff8000M+ Dungeon Filter:|r")
    
    -- Current dungeon display
    local dungeonText = dungeonFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dungeonText:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
    dungeonText:SetText("|cff00ff00All Dungeons|r")
    self.Frames.dungeonText = dungeonText
    
    -- Create dropdown-style button
    local dropBtn = CreateFrame("Button", "DCLeaderboardsDungeonDropdown", dungeonFrame, "UIPanelButtonTemplate")
    dropBtn:SetSize(170, 20)
    dropBtn:SetPoint("BOTTOMLEFT", 5, 5)
    dropBtn:SetText("Filter by Dungeon")
    dropBtn:SetScript("OnClick", function()
        self:ToggleDungeonDropdown()
    end)
    self.Frames.dungeonDropBtn = dropBtn
    
    -- Create dropdown menu (hidden by default)
    local dropdown = CreateFrame("Frame", "DCLeaderboardsDungeonMenu", dungeonFrame)
    dropdown:SetSize(170, 10) -- Will resize based on content
    dropdown:SetPoint("BOTTOM", dropBtn, "TOP", 0, 2)
    dropdown:SetFrameStrata("DIALOG")
    dropdown:Hide()
    
    local dropBg = dropdown:CreateTexture(nil, "BACKGROUND")
    dropBg:SetAllPoints()
    dropBg:SetTexture(0.1, 0.1, 0.1, 0.95)
    
    local dropBorder = CreateFrame("Frame", nil, dropdown)
    dropBorder:SetAllPoints()
    dropBorder:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    
    self.Frames.dungeonDropdown = dropdown
end

function LB:ToggleDungeonDropdown()
    local dropdown = self.Frames.dungeonDropdown
    if not dropdown then return end
    
    if dropdown:IsShown() then
        dropdown:Hide()
    else
        -- Request fresh dungeon list if empty
        if #self.MythicPlusDungeons == 0 then
            self:RequestMythicPlusDungeons()
        end
        self:UpdateDungeonDropdownItems()
        dropdown:Show()
    end
end

function LB:UpdateDungeonDropdownItems()
    local dropdown = self.Frames.dungeonDropdown
    if not dropdown then return end
    
    -- Clear existing items
    for _, child in pairs({dropdown:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Build dungeon list with "All Dungeons" at top
    local dungeons = {
        { mapId = 0, name = "All Dungeons" },
    }
    
    for _, d in ipairs(self.MythicPlusDungeons or {}) do
        table.insert(dungeons, d)
    end
    
    local yOffset = -5
    local itemHeight = 18
    local maxVisible = 12  -- Limit height
    
    for i, dungeon in ipairs(dungeons) do
        if i > maxVisible + 1 then break end  -- +1 for "All Dungeons"
        
        local item = CreateFrame("Button", nil, dropdown)
        item:SetSize(160, itemHeight)
        item:SetPoint("TOPLEFT", 5, yOffset)
        
        local itemText = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        itemText:SetPoint("LEFT", 5, 0)
        
        -- Highlight current selection
        local selectedId = self.SelectedDungeonMapId or 0
        if dungeon.mapId == selectedId then
            itemText:SetText("|cff00ff00> " .. dungeon.name .. "|r")
        else
            itemText:SetText("|cffffffff" .. dungeon.name .. "|r")
        end
        
        item:SetScript("OnClick", function()
            self:SelectDungeon(dungeon.mapId, dungeon.name)
            dropdown:Hide()
        end)
        
        item:SetScript("OnEnter", function(self)
            itemText:SetText("|cffffff00" .. dungeon.name .. "|r")
        end)
        
        item:SetScript("OnLeave", function(self)
            if dungeon.mapId == selectedId then
                itemText:SetText("|cff00ff00> " .. dungeon.name .. "|r")
            else
                itemText:SetText("|cffffffff" .. dungeon.name .. "|r")
            end
        end)
        
        yOffset = yOffset - itemHeight
    end
    
    -- Resize dropdown to fit items
    dropdown:SetHeight(math.abs(yOffset) + 10)
end

function LB:SelectDungeon(mapId, dungeonName)
    self.SelectedDungeonMapId = mapId
    
    -- Update display
    if self.Frames.dungeonText then
        if mapId == 0 then
            self.Frames.dungeonText:SetText("|cff00ff00All Dungeons|r")
        else
            self.Frames.dungeonText:SetText("|cffff8000" .. (dungeonName or ("Map " .. mapId)) .. "|r")
        end
    end
    
    Print("Dungeon filter: " .. (dungeonName or ("Map " .. mapId)))
    
    -- If a specific dungeon is selected, switch to per-dungeon subcategory
    if mapId > 0 then
        -- Change to dungeon-specific subcategory
        self.currentSubCategory = "mplus_dungeon_" .. mapId
    else
        -- Reset to default M+ subcategory
        self.currentSubCategory = "mplus_key"
    end
    
    -- Refresh leaderboard with new filter
    self:ForceRefresh()
end

-- Show/hide dungeon selector based on category
function LB:UpdateDungeonSelectorVisibility()
    if not self.Frames.dungeonSelector then return end
    
    -- Find current category config
    local category = nil
    for _, cat in ipairs(self.Categories) do
        if cat.id == self.currentCategory then
            category = cat
            break
        end
    end
    
    if category and category.hasDungeonFilter then
        self.Frames.dungeonSelector:Show()
        -- Request dungeons if we don't have them yet
        if #self.MythicPlusDungeons == 0 then
            self:RequestMythicPlusDungeons()
        end
    else
        self.Frames.dungeonSelector:Hide()
    end
end

function LB:ToggleSeasonDropdown()
    local dropdown = self.Frames.seasonDropdown
    if not dropdown then return end
    
    if dropdown:IsShown() then
        dropdown:Hide()
    else
        self:UpdateSeasonDropdownItems()
        dropdown:Show()
    end
end

function LB:UpdateSeasonDropdownItems()
    local dropdown = self.Frames.seasonDropdown
    if not dropdown then return end
    
    -- Clear existing items
    for _, child in pairs({dropdown:GetChildren()}) do
        if child ~= dropdown:GetBackdrop() then
            child:Hide()
            child:SetParent(nil)
        end
    end
    
    -- Build season list
    local seasons = self.AvailableSeasons or {
        { id = 0, name = "Current (Auto)" }
    }
    
    local yOffset = -5
    local itemHeight = 20
    
    for _, season in ipairs(seasons) do
        local item = CreateFrame("Button", nil, dropdown)
        item:SetSize(130, itemHeight)
        item:SetPoint("TOPLEFT", 5, yOffset)
        
        local itemText = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        itemText:SetPoint("LEFT", 5, 0)
        
        -- Highlight current selection
        local selectedId = self:GetSetting("selectedSeasonId") or 0
        if season.id == selectedId then
            itemText:SetText("|cff00ff00> " .. season.name .. "|r")
        else
            itemText:SetText("|cffffffff" .. season.name .. "|r")
        end
        
        item:SetScript("OnClick", function()
            self:SelectSeason(season.id, season.name)
            dropdown:Hide()
        end)
        
        item:SetScript("OnEnter", function(self)
            itemText:SetText("|cffffff00" .. season.name .. "|r")
        end)
        
        item:SetScript("OnLeave", function(self)
            if season.id == selectedId then
                itemText:SetText("|cff00ff00> " .. season.name .. "|r")
            else
                itemText:SetText("|cffffffff" .. season.name .. "|r")
            end
        end)
        
        yOffset = yOffset - itemHeight
    end
    
    -- Resize dropdown to fit items
    dropdown:SetHeight(math.abs(yOffset) + 10)
end

function LB:SelectSeason(seasonId, seasonName)
    self:SetSetting("selectedSeasonId", seasonId)
    
    -- Update display
    if self.Frames.seasonText then
        if seasonId == 0 then
            self.Frames.seasonText:SetText("|cff00ff00Current (Auto)|r")
        else
            self.Frames.seasonText:SetText("|cff00ccffSeason " .. seasonId .. "|r")
        end
    end
    
    Print("Season changed to: " .. (seasonName or ("Season " .. seasonId)))
    
    -- Refresh leaderboard with new season
    self:ForceRefresh()
end

-- =====================================================================
-- SUBCATEGORY TABS
-- =====================================================================

function LB:UpdateSubCategoryTabs()
    local subTabFrame = self.Frames.subTabs
    if not subTabFrame then return end
    
    -- Clear existing tabs
    for _, child in pairs({subTabFrame:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Get current category
    local category = nil
    for _, cat in ipairs(self.Categories) do
        if cat.id == self.currentCategory then
            category = cat
            break
        end
    end
    
    if not category then return end
    
    -- Create subcategory buttons
    local xOffset = 0
    self.subCategoryButtons = {}
    
    -- Calculate button width based on number of subcategories to fit in frame
    local frameWidth = 700
    local spacing = 5
    local numSubcats = #category.subcats
    local btnWidth = math.floor((frameWidth - (numSubcats - 1) * spacing) / numSubcats)
    -- Minimum width of 80px, maximum 120px
    btnWidth = math.max(80, math.min(120, btnWidth))
    
    for i, subcat in ipairs(category.subcats) do
        local btn = CreateFrame("Button", nil, subTabFrame)
        btn:SetSize(btnWidth, 25)
        btn:SetPoint("LEFT", xOffset, 0)
        
        -- Button background
        local btnBg = btn:CreateTexture(nil, "BACKGROUND")
        btnBg:SetAllPoints()
        btnBg:SetTexture(0.2, 0.2, 0.2, 0.8)
        btn.bg = btnBg
        
        -- Text
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER")
        text:SetText(subcat.name)
        
        btn:SetScript("OnClick", function()
            self:SelectSubCategory(subcat.id)
        end)
        
        btn:SetScript("OnEnter", function(self)
            self.bg:SetTexture(0.4, 0.4, 0.4, 0.8)
        end)
        
        btn:SetScript("OnLeave", function(self)
            if LB.currentSubCategory == subcat.id then
                self.bg:SetTexture(0.3, 0.5, 0.3, 0.8)
            else
                self.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
            end
        end)
        
        self.subCategoryButtons[subcat.id] = btn
        xOffset = xOffset + btnWidth + 5
    end
    
    -- Select first subcategory by default
    if category.subcats[1] and not self.currentSubCategory then
        self:SelectSubCategory(category.subcats[1].id)
    end
end

-- =====================================================================
-- CATEGORY/SUBCATEGORY SELECTION
-- =====================================================================

function LB:SelectCategory(categoryId)
    self.currentCategory = categoryId
    self.currentSubCategory = nil
    self.currentPage = 1
    
    -- Reset dungeon filter when changing categories
    self.SelectedDungeonMapId = 0
    if self.Frames.dungeonText then
        self.Frames.dungeonText:SetText("|cff00ff00All Dungeons|r")
    end
    
    -- v1.3.0: Update dungeon selector visibility
    self:UpdateDungeonSelectorVisibility()
    
    -- Update button highlights
    for id, btn in pairs(self.categoryButtons or {}) do
        if id == categoryId then
            btn.bg:SetTexture(0.3, 0.5, 0.3, 0.8)
        else
            btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
        end
    end
    
    -- Update subcategory tabs
    self:UpdateSubCategoryTabs()
    
    -- Find first subcategory and select it
    for _, cat in ipairs(self.Categories) do
        if cat.id == categoryId and cat.subcats[1] then
            self:SelectSubCategory(cat.subcats[1].id)
            break
        end
    end
end

function LB:SelectSubCategory(subcategoryId)
    self.currentSubCategory = subcategoryId
    self.currentPage = 1
    
    -- Update button highlights
    for id, btn in pairs(self.subCategoryButtons or {}) do
        if id == subcategoryId then
            btn.bg:SetTexture(0.3, 0.5, 0.3, 0.8)
        else
            btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
        end
    end
    
    -- Check if we're in statistics mode
    if self.currentCategory == "statistics" then
        if self.Frames.scrollChild then self.Frames.scrollChild:GetParent():Hide() end
        if self.Frames.headers then self.Frames.headers:Hide() end
        if self.Frames.bottomBar then self.Frames.bottomBar:Hide() end
        if self.Frames.statsFrame then 
            self.Frames.statsFrame:Show()
            self:UpdateStatisticsDisplay()
        end
        return
    else
        if self.Frames.scrollChild then self.Frames.scrollChild:GetParent():Show() end
        if self.Frames.headers then self.Frames.headers:Show() end
        if self.Frames.bottomBar then self.Frames.bottomBar:Show() end
        if self.Frames.statsFrame then self.Frames.statsFrame:Hide() end
    end

    -- Update header text
    self:UpdateHeaderText()
    
    -- Check cache
    local key = self.currentCategory .. "_" .. subcategoryId
    local cacheTime = self.Cache.timestamps[key]
    local cacheLifetime = self:GetSetting("cacheLifetime") or 30
    
    if cacheTime and (time() - cacheTime) < cacheLifetime then
        -- Use cached data
        self:UpdateLeaderboardDisplay()
    else
        -- Request fresh data
        self:RequestLeaderboard(self.currentCategory, subcategoryId, 1)
    end
    
    -- Also request player's rank
    self:RequestMyRank(self.currentCategory, subcategoryId)
end

function LB:UpdateHeaderText()
    local subcat = self.currentSubCategory or ""
    local header = self.Frames.scoreHeader
    local extra = self.Frames.extraHeader
    
    if not header then return end
    
    -- Update score header based on subcategory
    if subcat:find("_time") then
        header:SetText("|cffffd700Time|r")
        extra:SetText("|cffffd700Dungeon|r")
    elseif subcat == "hlbg_rating" then
        header:SetText("|cffffd700Rating|r")
        extra:SetText("|cffffd700Win/Loss|r")
    elseif subcat == "hlbg_wins" then
        header:SetText("|cffffd700Wins|r")
        extra:SetText("|cffffd700Total Games|r")
    elseif subcat == "hlbg_winrate" then
        header:SetText("|cffffd700Win Rate|r")
        extra:SetText("|cffffd700W/L|r")
    elseif subcat == "hlbg_games" then
        header:SetText("|cffffd700Games|r")
        extra:SetText("|cffffd700W/L|r")
    elseif subcat == "hlbg_kills" then
        header:SetText("|cffffd700Kills|r")
        extra:SetText("|cffffd700K/D Ratio|r")
    elseif subcat == "hlbg_alltime_wins" then
        header:SetText("|cffffd700All-Time Wins|r")
        extra:SetText("|cffffd700K/D Ratio|r")
    elseif subcat == "hlbg_resources" then
        header:SetText("|cffffd700Resources|r")
        extra:SetText("|cffffd700K/D Ratio|r")
    elseif subcat:find("_rating") then
        header:SetText("|cffffd700Rating|r")
        extra:SetText("|cffffd700Win/Loss|r")
    elseif subcat:find("_winrate") then
        header:SetText("|cffffd700Win Rate|r")
        extra:SetText("|cffffd700Games|r")
    elseif subcat == "aoe_gold" then
        header:SetText("|cffffd700Gold|r")
        extra:SetText("|cffffd700Items Looted|r")
    elseif subcat == "aoe_items" then
        header:SetText("|cffffd700Items|r")
        extra:SetText("|cffffd700Quality Breakdown|r")
    elseif subcat == "aoe_filtered" then
        header:SetText("|cffffd700Filtered|r")
        extra:SetText("|cffffd700Quality Breakdown|r")
    elseif subcat == "mplus_bestruns" then
        -- v1.3.0: Best runs with dungeon names
        header:SetText("|cffffd700Key Level|r")
        extra:SetText("|cffffd700Dungeon|r")
    elseif subcat:find("mplus_dungeon_") then
        -- v1.3.0: Per-dungeon view
        header:SetText("|cffffd700Key Level|r")
        extra:SetText("|cffffd700Dungeon (Runs)|r")
    elseif subcat:find("_level") or subcat:find("_key") then
        header:SetText("|cffffd700Level|r")
        extra:SetText("|cffffd700Details|r")
    else
        header:SetText("|cffffd700Score|r")
        extra:SetText("|cffffd700Info|r")
    end
end

-- =====================================================================
-- LEADERBOARD DISPLAY
-- =====================================================================

function LB:GetOrCreateEntry(index)
    if self.entryPool[index] then
        self.entryPool[index]:Show()
        return self.entryPool[index]
    end
    
    local scrollChild = self.Frames.scrollChild
    if not scrollChild then return nil end
    
    local entry = CreateFrame("Frame", nil, scrollChild)
    entry:SetSize(660, 28)
    entry:SetPoint("TOPLEFT", 0, -(index - 1) * 30)
    
    -- Alternating background
    local bg = entry:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0.1, 0.1, 0.1, (index % 2 == 0) and 0.6 or 0.3)
    entry.bg = bg
    
    -- Rank
    entry.rank = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    entry.rank:SetPoint("LEFT", 10, 0)
    entry.rank:SetWidth(30)
    entry.rank:SetJustifyH("CENTER")
    
    -- Player name
    entry.name = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    entry.name:SetPoint("LEFT", 50, 0)
    entry.name:SetWidth(200)
    entry.name:SetJustifyH("LEFT")
    
    -- Score
    entry.score = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    entry.score:SetPoint("LEFT", 300, 0)
    entry.score:SetWidth(80)
    entry.score:SetJustifyH("LEFT")
    
    -- Class
    entry.class = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    entry.class:SetPoint("LEFT", 390, 0)
    entry.class:SetWidth(70)
    entry.class:SetJustifyH("LEFT")
    
    -- Extra info
    entry.extra = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    entry.extra:SetPoint("LEFT", 470, 0)
    entry.extra:SetWidth(60)
    entry.extra:SetJustifyH("LEFT")
    
    -- Quality breakdown columns (for AOE Loot) - separate columns
    -- L (Legendary)
    entry.qLeg = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    entry.qLeg:SetPoint("LEFT", 540, 0)
    entry.qLeg:SetWidth(25)
    entry.qLeg:SetJustifyH("CENTER")
    entry.qLeg:Hide()
    
    -- E (Epic)
    entry.qEpic = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    entry.qEpic:SetPoint("LEFT", 570, 0)
    entry.qEpic:SetWidth(25)
    entry.qEpic:SetJustifyH("CENTER")
    entry.qEpic:Hide()
    
    -- R (Rare)
    entry.qRare = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    entry.qRare:SetPoint("LEFT", 600, 0)
    entry.qRare:SetWidth(25)
    entry.qRare:SetJustifyH("CENTER")
    entry.qRare:Hide()
    
    -- U (Uncommon)
    entry.qUncommon = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    entry.qUncommon:SetPoint("LEFT", 630, 0)
    entry.qUncommon:SetWidth(25)
    entry.qUncommon:SetJustifyH("CENTER")
    entry.qUncommon:Hide()
    
    self.entryPool[index] = entry
    return entry
end

function LB:UpdateLeaderboardDisplay()
    local key = (self.currentCategory or "mplus") .. "_" .. (self.currentSubCategory or "mplus_key")
    local data = self.Cache.data[key] or {}
    
    -- Debug output - always show what we're displaying
    Print("|cff888888Displaying:|r " .. #data .. " entries for " .. key)
    
    -- Debug: List cache contents
    if self:GetSetting("verboseLogging") then
        Print("|cff888888Cache keys:|r")
        for cacheKey, cacheData in pairs(self.Cache.data) do
            Print("  " .. cacheKey .. ": " .. #cacheData .. " entries")
        end
    end
    
    -- Hide all existing entries first
    for i, entry in pairs(self.entryPool) do
        entry:Hide()
    end
    
    -- If no data, show a message
    if #data == 0 then
        local scrollChild = self.Frames.scrollChild
        if scrollChild then
            -- Create or show "no data" message
            if not self.noDataText then
                self.noDataText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                self.noDataText:SetPoint("CENTER", scrollChild, "CENTER", 0, 100)
            end
            self.noDataText:SetText("|cff888888No leaderboard data available.\n\nThis could mean:\n- No players have data for this category yet\n- The server needs to track more activity\n- Try a different category|r")
            self.noDataText:Show()
        end
    else
        if self.noDataText then
            self.noDataText:Hide()
        end
    end
    
    -- Get player name for highlighting
    local playerName = UnitName("player")
    local highlightSelf = self:GetSetting("highlightSelf")
    local showClassColors = self:GetSetting("showClassColors")
    
    -- Populate entries
    for i, entryData in ipairs(data) do
        local entry = self:GetOrCreateEntry(i)
        if entry then
            -- Rank (top 3 get special colors)
            local rankText = tostring(entryData.rank or i)
            if i == 1 then
                rankText = "|cffffd700" .. rankText .. "|r"  -- Gold
            elseif i == 2 then
                rankText = "|cffc0c0c0" .. rankText .. "|r"  -- Silver
            elseif i == 3 then
                rankText = "|cffcd7f32" .. rankText .. "|r"  -- Bronze
            end
            entry.rank:SetText(rankText)
            
            -- Player name with class color
            local name = entryData.name or entryData.playerName or "Unknown"
            local class = entryData.class or ""
            if showClassColors and class ~= "" then
                local color = GetClassColor(class)
                name = "|cff" .. color .. name .. "|r"
            end
            
            -- Highlight self
            if highlightSelf and entryData.name == playerName then
                entry.bg:SetTexture(0.2, 0.4, 0.2, 0.7)
            else
                entry.bg:SetTexture(0.1, 0.1, 0.1, (i % 2 == 0) and 0.6 or 0.3)
            end
            
            entry.name:SetText(name)
            
            -- Score (formatted based on type)
            local subcat = self.currentSubCategory or ""
            local scoreText
            
            if subcat:find("_time") then
                local scoreVal = entryData.score or entryData.value or 0
                scoreText = FormatTime(scoreVal)
            elseif subcat:find("_winrate") or subcat:find("_efficiency") then
                local scoreVal = entryData.score or entryData.value or 0
                -- Server sends winrate scaled by 10 for precision; divide back
                if self.currentCategory == "hlbg" and subcat:find("_winrate") then
                    scoreVal = (tonumber(scoreVal) or 0) / 10
                end
                scoreText = FormatPercent(scoreVal)
            elseif subcat == "aoe_gold" then
                -- v1.3.0: Gold is sent as score_str (string) to avoid uint32 truncation
                -- Fall back to score if score_str not present
                local copperVal
                if entryData.score_str and entryData.score_str ~= "" then
                    copperVal = tonumber(entryData.score_str) or 0
                else
                    copperVal = entryData.score or entryData.value or 0
                end
                scoreText = FormatMoney(copperVal)
            else
                local scoreVal = entryData.score or entryData.value or 0
                scoreText = FormatNumber(scoreVal)
            end
            entry.score:SetText(scoreText)
            
            -- Class
            entry.class:SetText(entryData.class or "")
            
            -- Extra info (formatted based on category)
            local extraText = ""
            if self.currentCategory == "hlbg" then
                -- Format HLBG extra data
                if subcat == "hlbg_winrate" then
                    -- Show W/L for winrate category
                    local wins = entryData.wins or 0
                    local losses = entryData.losses or 0
                    extraText = "|cff00ff00" .. wins .. "|r/|cffff0000" .. losses .. "|r"
                elseif subcat == "hlbg_games" then
                    -- Show W/L for games category
                    local wins = entryData.wins or 0
                    local losses = entryData.losses or 0
                    extraText = "|cff00ff00" .. wins .. "|r/|cffff0000" .. losses .. "|r"
                elseif subcat == "hlbg_kills" or subcat == "hlbg_alltime_wins" or subcat == "hlbg_resources" then
                    -- Show K/D ratio for kill-based categories
                    if entryData.kdRatio then
                        extraText = string.format("K/D: |cffffffff%.2f|r", tonumber(entryData.kdRatio) or 0)
                    elseif entryData.kills and entryData.deaths then
                        local kdRatio = (tonumber(entryData.deaths) or 1) > 0 and (tonumber(entryData.kills) or 0) / (tonumber(entryData.deaths) or 1) or 0
                        extraText = string.format("K/D: |cffffffff%.2f|r", kdRatio)
                    end
                elseif subcat == "hlbg_rating" then
                    -- Show W/L for rating category
                    local wins = entryData.wins or 0
                    local losses = entryData.losses or 0
                    extraText = "|cff00ff00" .. wins .. "|r/|cffff0000" .. losses .. "|r"
                elseif subcat == "hlbg_wins" then
                    -- Show total games
                    local totalGames = (tonumber(entryData.wins) or 0) + (tonumber(entryData.losses) or 0)
                    extraText = "Total: " .. totalGames
                end
            else
                extraText = entryData.extra or entryData.details or ""
            end
            entry.extra:SetText(extraText)
            
            -- Quality breakdown columns (for AOE Loot category)
            local isAOE = (self.currentCategory == "aoe")
            if isAOE and (subcat == "aoe_items" or subcat == "aoe_filtered") then
                -- Show quality columns
                entry.qLeg:Show()
                entry.qEpic:Show()
                entry.qRare:Show()
                entry.qUncommon:Show()
                
                -- Parse quality data from entryData (expected: qLeg, qEpic, qRare, qUncommon)
                local legCount = entryData.qLeg or entryData.legendary or 0
                local epicCount = entryData.qEpic or entryData.epic or 0
                local rareCount = entryData.qRare or entryData.rare or 0
                local unCount = entryData.qUncommon or entryData.uncommon or 0
                
                entry.qLeg:SetText("|cffff8000" .. FormatNumber(legCount) .. "|r")
                entry.qEpic:SetText("|cffa335ee" .. FormatNumber(epicCount) .. "|r")
                entry.qRare:SetText("|cff0070dd" .. FormatNumber(rareCount) .. "|r")
                entry.qUncommon:SetText("|cff1eff00" .. FormatNumber(unCount) .. "|r")
            else
                -- Hide quality columns for non-AOE categories
                entry.qLeg:Hide()
                entry.qEpic:Hide()
                entry.qRare:Hide()
                entry.qUncommon:Hide()
            end
        end
    end
    
    -- Show/hide quality header columns based on category (3.3.5a compatible)
    local isAOEItems = (self.currentCategory == "aoe" and (self.currentSubCategory == "aoe_items" or self.currentSubCategory == "aoe_filtered"))
    
    if self:GetSetting("verboseLogging") and self.currentCategory == "aoe" then
        Print("|cffff8000AOE Loot Debug:|r isAOEItems=" .. tostring(isAOEItems) .. ", subcat=" .. tostring(self.currentSubCategory))
    end
    
    if self.Frames.legHeader then
        if isAOEItems then self.Frames.legHeader:Show() else self.Frames.legHeader:Hide() end
    end
    if self.Frames.epicHeader then
        if isAOEItems then self.Frames.epicHeader:Show() else self.Frames.epicHeader:Hide() end
    end
    if self.Frames.rareHeader then
        if isAOEItems then self.Frames.rareHeader:Show() else self.Frames.rareHeader:Hide() end
    end
    if self.Frames.unHeader then
        if isAOEItems then self.Frames.unHeader:Show() else self.Frames.unHeader:Hide() end
    end
    
    -- Update scroll child height
    local totalHeight = #data * 30
    self.Frames.scrollChild:SetHeight(math.max(totalHeight, 1))
    
    -- Update page info
    self:UpdatePaginationDisplay()
    
    -- Update player rank display
    self:UpdatePlayerRankDisplay()
    
    -- Update total players
    if self.Frames.totalPlayers then
        self.Frames.totalPlayers:SetText("Total: |cffffffff" .. (self.Cache.totalEntries or #data) .. "|r players")
    end
end

function LB:UpdatePaginationDisplay()
    local page = self.Cache.currentPage or 1
    local totalPages = self.Cache.totalPages or 1
    
    if self.Frames.pageInfo then
        self.Frames.pageInfo:SetText("Page " .. page .. " / " .. totalPages)
    end
    
    if self.Frames.prevBtn then
        if page <= 1 then
            self.Frames.prevBtn:Disable()
        else
            self.Frames.prevBtn:Enable()
        end
    end
    
    if self.Frames.nextBtn then
        if page >= totalPages then
            self.Frames.nextBtn:Disable()
        else
            self.Frames.nextBtn:Enable()
        end
    end
end

function LB:UpdatePlayerRankDisplay()
    local key = (self.currentCategory or "mplus") .. "_" .. (self.currentSubCategory or "mplus_key")
    local myRankData = self.Cache.myRanks[key]
    
    if self.Frames.myRank then
        if myRankData and myRankData.rank then
            local rankText = "Your rank: |cff00ff00#" .. myRankData.rank .. "|r"
            if myRankData.percentile then
                rankText = rankText .. " (top " .. myRankData.percentile .. "%)"
            end
            self.Frames.myRank:SetText(rankText)
        else
            self.Frames.myRank:SetText("Your rank: |cffffffff--|r")
        end
    end
end

function LB:NextPage()
    local totalPages = self.Cache.totalPages or 1
    local page = self.Cache.currentPage or 1
    
    if page < totalPages then
        self:RequestLeaderboard(self.currentCategory, self.currentSubCategory, page + 1)
    end
end

function LB:PreviousPage()
    local page = self.Cache.currentPage or 1
    
    if page > 1 then
        self:RequestLeaderboard(self.currentCategory, self.currentSubCategory, page - 1)
    end
end

-- =====================================================================
-- SETTINGS PANEL
-- =====================================================================

function LB:CreateSettingsPanel()
    if self.Frames.settingsPanel then return self.Frames.settingsPanel end
    
    local panel = CreateFrame("Frame", "DCLeaderboardsSettings", UIParent)
    panel.name = ADDON_NAME
    panel:Hide()
    
    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ff96DC-Leaderboards|r Settings")
    
    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetText("Configure the unified leaderboard display and communication settings.")
    
    local yPos = -70
    
    -- Display Settings Header
    local displayHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    displayHeader:SetPoint("TOPLEFT", 16, yPos)
    displayHeader:SetText("|cffffd700Display Settings|r")
    yPos = yPos - 24
    
    -- Helper for checkboxes
    local function MakeCheck(name, label, setting, yOffset)
        local cb = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 20, yOffset)
        _G[name .. "Text"]:SetText(label)
        cb:SetChecked(LB:GetSetting(setting))
        cb:SetScript("OnClick", function(self)
            LB:SetSetting(setting, self:GetChecked())
        end)
        return cb, yOffset - 26
    end
    
    local cb
    cb, yPos = MakeCheck("DCLB_ShowOnLogin", "Show leaderboard on login", "showOnLogin", yPos)
    cb, yPos = MakeCheck("DCLB_HighlightSelf", "Highlight your own entry", "highlightSelf", yPos)
    cb, yPos = MakeCheck("DCLB_ClassColors", "Show class colors", "showClassColors", yPos)
    cb, yPos = MakeCheck("DCLB_SoundOnRefresh", "Play sound on refresh", "soundOnRefresh", yPos)
    
    -- Frame scale slider
    yPos = yPos - 10
    local scaleSlider = CreateFrame("Slider", "DCLB_FrameScale", panel, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", 25, yPos)
    scaleSlider:SetWidth(200)
    scaleSlider:SetMinMaxValues(0.5, 1.5)
    scaleSlider:SetValueStep(0.1)
    scaleSlider:SetValue(LB:GetSetting("frameScale") or 1.0)
    _G[scaleSlider:GetName() .. "Text"]:SetText("Frame Scale")
    _G[scaleSlider:GetName() .. "Low"]:SetText("0.5")
    _G[scaleSlider:GetName() .. "High"]:SetText("1.5")
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 10 + 0.5) / 10
        LB:SetSetting("frameScale", value)
        if LB.Frames.main and LB.Frames.main.container then
            LB.Frames.main.container:SetScale(value)
        end
    end)
    yPos = yPos - 50
    
    -- Entries per page slider
    local entriesSlider = CreateFrame("Slider", "DCLB_EntriesPerPage", panel, "OptionsSliderTemplate")
    entriesSlider:SetPoint("TOPLEFT", 25, yPos)
    entriesSlider:SetWidth(200)
    entriesSlider:SetMinMaxValues(10, 50)
    entriesSlider:SetValueStep(5)
    entriesSlider:SetValue(LB:GetSetting("entriesPerPage") or 25)
    _G[entriesSlider:GetName() .. "Text"]:SetText("Entries per page")
    _G[entriesSlider:GetName() .. "Low"]:SetText("10")
    _G[entriesSlider:GetName() .. "High"]:SetText("50")
    entriesSlider:SetScript("OnValueChanged", function(self, value)
        LB:SetSetting("entriesPerPage", math.floor(value))
    end)
    
    panel:SetScript("OnShow", function()
        -- Refresh checkbox states
    end)
    
    InterfaceOptions_AddCategory(panel)
    self.Frames.settingsPanel = panel
    return panel
end

function LB:CreateCommunicationPanel()
    local parent = self.Frames.settingsPanel
    if not parent then return end
    
    local panel = CreateFrame("Frame", "DCLeaderboardsCommSettings", UIParent)
    panel.name = "Communication & Testing"
    panel.parent = parent.name
    panel:Hide()
    
    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ff96DC-Leaderboards|r - Communication & Testing")
    
    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(560)
    desc:SetJustifyH("LEFT")
    desc:SetText("Configure communication settings, select season, and test database connectivity.")
    
    local yPos = -70
    
    -- Protocol Status
    local statusHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusHeader:SetPoint("TOPLEFT", 16, yPos)
    statusHeader:SetText("|cffffd700Protocol Status|r")
    yPos = yPos - 20
    
    local dcStatus = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dcStatus:SetPoint("TOPLEFT", 24, yPos)
    panel.dcStatus = dcStatus
    yPos = yPos - 18
    
    local connStatus = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    connStatus:SetPoint("TOPLEFT", 24, yPos)
    panel.connStatus = connStatus
    yPos = yPos - 30
    
    -- Season Selection Section
    local seasonHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    seasonHeader:SetPoint("TOPLEFT", 16, yPos)
    seasonHeader:SetText("|cffffd700Season Selection|r")
    yPos = yPos - 22
    
    local seasonLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    seasonLabel:SetPoint("TOPLEFT", 20, yPos)
    seasonLabel:SetText("Select Season:")
    
    -- Season dropdown
    local seasonDropdown = CreateFrame("Frame", "DCLB_SeasonDropdown", panel, "UIDropDownMenuTemplate")
    seasonDropdown:SetPoint("LEFT", seasonLabel, "RIGHT", 0, -2)
    UIDropDownMenu_SetWidth(seasonDropdown, 180)
    
    local function SeasonDropdown_OnClick(self)
        local seasonId = self.value
        LB:SetSetting("selectedSeasonId", seasonId)
        UIDropDownMenu_SetText(seasonDropdown, self:GetText())
        Print("|cff00ff00Season set to:|r " .. self:GetText())
    end
    
    local function SeasonDropdown_Initialize(self, level)
        level = level or 1
        if level ~= 1 then
            return
        end
        for _, season in ipairs(LB.AvailableSeasons) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = season.name
            info.value = season.id
            info.func = SeasonDropdown_OnClick
            info.checked = (LB:GetSetting("selectedSeasonId") == season.id)
            UIDropDownMenu_AddButton(info, level)
        end
    end
    
    UIDropDownMenu_Initialize(seasonDropdown, SeasonDropdown_Initialize)
    UIDropDownMenu_SetText(seasonDropdown, "Current Season (Auto)")
    -- Keep separate from the main-frame custom season dropdown (LB.Frames.seasonDropdown)
    LB.Frames.commSeasonDropdown = seasonDropdown
    
    -- Refresh seasons button
    local refreshSeasonsBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    refreshSeasonsBtn:SetSize(100, 22)
    refreshSeasonsBtn:SetPoint("LEFT", seasonDropdown, "RIGHT", 10, 2)
    refreshSeasonsBtn:SetText("Refresh List")
    refreshSeasonsBtn:SetScript("OnClick", function()
        LB:RequestSeasons()
    end)
    
    yPos = yPos - 40
    
    -- Communication Settings
    local commHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    commHeader:SetPoint("TOPLEFT", 16, yPos)
    commHeader:SetText("|cffffd700Communication Settings|r")
    yPos = yPos - 24
    
    -- Verbose logging
    local verboseCheck = CreateFrame("CheckButton", "DCLB_Verbose", panel, "InterfaceOptionsCheckButtonTemplate")
    verboseCheck:SetPoint("TOPLEFT", 20, yPos)
    _G["DCLB_VerboseText"]:SetText("Verbose logging (debug)")
    verboseCheck:SetChecked(LB:GetSetting("verboseLogging"))
    verboseCheck:SetScript("OnClick", function(self)
        LB:SetSetting("verboseLogging", self:GetChecked())
    end)
    yPos = yPos - 26
    
    -- Cache lifetime slider
    yPos = yPos - 10
    local cacheSlider = CreateFrame("Slider", "DCLB_CacheLifetime", panel, "OptionsSliderTemplate")
    cacheSlider:SetPoint("TOPLEFT", 25, yPos)
    cacheSlider:SetWidth(200)
    cacheSlider:SetMinMaxValues(10, 120)
    cacheSlider:SetValueStep(10)
    cacheSlider:SetValue(LB:GetSetting("cacheLifetime") or 30)
    _G[cacheSlider:GetName() .. "Text"]:SetText("Cache lifetime (seconds)")
    _G[cacheSlider:GetName() .. "Low"]:SetText("10")
    _G[cacheSlider:GetName() .. "High"]:SetText("120")
    cacheSlider:SetScript("OnValueChanged", function(self, value)
        LB:SetSetting("cacheLifetime", math.floor(value))
    end)
    yPos = yPos - 50
    
    -- Database Testing Section
    local dbHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dbHeader:SetPoint("TOPLEFT", 16, yPos)
    dbHeader:SetText("|cffffd700Database Testing|r")
    yPos = yPos - 25
    
    local dbTestBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    dbTestBtn:SetSize(180, 26)
    dbTestBtn:SetPoint("TOPLEFT", 20, yPos)
    dbTestBtn:SetText("Test Database Tables")
    dbTestBtn:SetScript("OnClick", function()
        LB:TestDatabaseTables()
    end)
    
    local dbTestDesc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dbTestDesc:SetPoint("LEFT", dbTestBtn, "RIGHT", 10, 0)
    dbTestDesc:SetText("Checks if all leaderboard tables exist and have data")
    
    yPos = yPos - 35
    
    -- Quick Test Buttons
    local testHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    testHeader:SetPoint("TOPLEFT", 16, yPos)
    testHeader:SetText("|cffffd700Quick Tests|r")
    yPos = yPos - 25
    
    local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testBtn:SetSize(130, 22)
    testBtn:SetPoint("TOPLEFT", 20, yPos)
    testBtn:SetText("Test Connection")
    testBtn:SetScript("OnClick", function()
        LB:TestConnection()
    end)
    
    local mplusBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    mplusBtn:SetSize(130, 22)
    mplusBtn:SetPoint("LEFT", testBtn, "RIGHT", 10, 0)
    mplusBtn:SetText("Test M+ Data")
    mplusBtn:SetScript("OnClick", function()
        LB:RequestLeaderboard("mplus", "mplus_key", 1)
    end)
    
    local hlbgBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    hlbgBtn:SetSize(130, 22)
    hlbgBtn:SetPoint("LEFT", mplusBtn, "RIGHT", 10, 0)
    hlbgBtn:SetText("Test HLBG Data")
    hlbgBtn:SetScript("OnClick", function()
        LB:RequestLeaderboard("hlbg", "hlbg_alltime_wins", 1)
    end)
    
    yPos = yPos - 30
    
    local upgradeBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    upgradeBtn:SetSize(130, 22)
    upgradeBtn:SetPoint("TOPLEFT", 20, yPos)
    upgradeBtn:SetText("Test Upgrades")
    upgradeBtn:SetScript("OnClick", function()
        LB:RequestLeaderboard("upgrade", "upgrade_tokens", 1)
    end)
    
    local aoeBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    aoeBtn:SetSize(130, 22)
    aoeBtn:SetPoint("LEFT", upgradeBtn, "RIGHT", 10, 0)
    aoeBtn:SetText("Test AOE Loot")
    aoeBtn:SetScript("OnClick", function()
        LB:RequestLeaderboard("aoe", "aoe_items", 1)
    end)
    
    local clearBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearBtn:SetSize(130, 22)
    clearBtn:SetPoint("LEFT", aoeBtn, "RIGHT", 10, 0)
    clearBtn:SetText("Clear Cache")
    clearBtn:SetScript("OnClick", function()
        LB.Cache.data = {}
        LB.Cache.timestamps = {}
        Print("Cache cleared")
    end)
    
    -- Update status on show
    local function UpdateStatus()
        local dc = rawget(_G, "DCAddonProtocol")
        panel.dcStatus:SetText("DCAddonProtocol: " .. (dc and "|cff00ff00Available v" .. (dc.VERSION or "?") .. "|r" or "|cffff0000Not Loaded|r"))
        panel.connStatus:SetText("Connected: " .. (dc and dc._connected and "|cff00ff00Yes|r" or "|cffff0000No|r"))
        
        -- Update season dropdown text
        local seasonId = LB:GetSetting("selectedSeasonId") or 0
        local seasonName = "Current Season (Auto)"
        for _, season in ipairs(LB.AvailableSeasons) do
            if season.id == seasonId then
                seasonName = season.name
                break
            end
        end
        UIDropDownMenu_SetText(seasonDropdown, seasonName)
    end
    
    panel:SetScript("OnShow", UpdateStatus)
    
    InterfaceOptions_AddCategory(panel)
    self.Frames.commPanel = panel
    return panel
end

function LB:OpenSettings()
    if not self.Frames.settingsPanel then
        self:CreateSettingsPanel()
        self:CreateCommunicationPanel()
    end
    InterfaceOptionsFrame_OpenToCategory(self.Frames.settingsPanel)
    InterfaceOptionsFrame_OpenToCategory(self.Frames.settingsPanel)
end

function LB:TestConnection()
    if not DC then
        Print("|cffff0000DCAddonProtocol not available|r")
        return
    end
    
    Print("Testing connection...")
    DC:Request("CORE", 0x01, { ping = true, addon = ADDON_NAME })
end

function LB:UpdateSeasonDropdown()
    local seasonId = self:GetSetting("selectedSeasonId") or 0
    local seasonName = "Current Season (Auto)"
    for _, season in ipairs(self.AvailableSeasons) do
        if season.id == seasonId then
            seasonName = season.name
            break
        end
    end

    -- Settings panel (UIDropDownMenuTemplate)
    if self.Frames.commSeasonDropdown then
        UIDropDownMenu_SetText(self.Frames.commSeasonDropdown, seasonName)
    end

    -- Main frame (custom season selector)
    if self.Frames.seasonText then
        if seasonId == 0 then
            self.Frames.seasonText:SetText("|cff00ff00Current (Auto)|r")
        else
            self.Frames.seasonText:SetText("|cff00ccff" .. seasonName .. "|r")
        end
    end
end

-- =====================================================================
-- SHOW/HIDE FUNCTIONS
-- =====================================================================

function LB:Show()
    local frame = self:CreateMainFrame()
    if not frame then return end
    
    -- Apply scale
    local scale = self:GetSetting("frameScale") or 1.0
    frame.container:SetScale(scale)
    
    -- Select default category if none selected
    if not self.currentCategory then
        local defaultCat = self:GetSetting("defaultCategory") or "mplus"
        self:SelectCategory(defaultCat)
    else
        -- Refresh current view
        self:SelectSubCategory(self.currentSubCategory or "mplus_key")
    end
    
    frame:Show()
end

function LB:Hide()
    if self.Frames.main then
        self.Frames.main:Hide()
    end
end

function LB:Toggle()
    if self.Frames.main and self.Frames.main:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- =====================================================================
-- SLASH COMMANDS
-- =====================================================================

SLASH_DCLEADERBOARDS1 = "/leaderboard"
SLASH_DCLEADERBOARDS2 = "/dcleaderboard"
SLASH_DCLEADERBOARDS3 = "/dclb"
SLASH_DCLEADERBOARDS4 = "/lb"

SlashCmdList["DCLEADERBOARDS"] = function(msg)
    local cmd = string.lower(msg or "")
    
    if cmd == "" or cmd == "show" or cmd == "toggle" then
        LB:Toggle()
    elseif cmd == "hide" then
        LB:Hide()
    elseif cmd == "refresh" then
        LB:ForceRefresh()
    elseif cmd == "settings" or cmd == "config" or cmd == "options" then
        LB:OpenSettings()
    elseif cmd == "test" then
        LB:TestConnection()
    elseif cmd == "clear" or cmd == "clearcache" then
        LB.Cache.data = {}
        LB.Cache.timestamps = {}
        Print("Cache cleared")
    elseif cmd == "status" then
        Print("DC-Leaderboards v" .. VERSION)
        Print("  Current category: " .. (LB.currentCategory or "none"))
        Print("  Current subcategory: " .. (LB.currentSubCategory or "none"))
        Print("  Cached entries: " .. #(LB.Cache.data or {}))
        Print("  DC Protocol: " .. (DC and "Available" or "Not loaded"))
    elseif cmd:match("^mplus") then
        LB:Show()
        LB:SelectCategory("mplus")
    elseif cmd:match("^season") then
        LB:Show()
        LB:SelectCategory("seasons")
    elseif cmd:match("^hlbg") or cmd:match("^bg") then
        LB:Show()
        LB:SelectCategory("hlbg")
    elseif cmd:match("^prestige") then
        LB:Show()
        LB:SelectCategory("prestige")
    elseif cmd:match("^upgrade") then
        LB:Show()
        LB:SelectCategory("upgrade")
    elseif cmd:match("^duel") then
        LB:Show()
        LB:SelectCategory("duel")
    elseif cmd:match("^aoe") then
        LB:Show()
        LB:SelectCategory("aoe")
    elseif cmd:match("^achieve") then
        LB:Show()
        LB:SelectCategory("achieve")
    elseif cmd == "testtables" or cmd == "tables" or cmd == "dbtest" then
        -- Quick test of database tables
        LB:TestTables()
    elseif cmd == "seasons" then
        -- Request available seasons
        LB:RequestSeasons()
    elseif cmd:match("^setseason%s+(%d+)") then
        -- Set season for testing: /lb setseason 2
        local seasonId = tonumber(cmd:match("^setseason%s+(%d+)"))
        if seasonId then
            LB.settings.selectedSeasonId = seasonId
            Print("Selected season ID: " .. seasonId .. " (0 = current)")
            Print("Refresh leaderboards to see data for this season")
        end
    elseif cmd == "debug" or cmd == "verbose" then
        -- Toggle verbose logging
        LB.settings.verboseLogging = not LB.settings.verboseLogging
        Print("Verbose logging: " .. (LB.settings.verboseLogging and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
    elseif cmd == "protocol" then
        -- Show protocol info
        Print("=== DC-Leaderboards Protocol Info ===")
        Print("Module: " .. LB.MODULE)
        Print("DC Protocol: " .. (DC and "Available" or "Not loaded"))
        Print("Selected Season: " .. (LB.settings.selectedSeasonId or 0) .. " (0 = current)")
        Print("Opcodes:")
        Print("  CMSG_GET_LEADERBOARD: 0x01")
        Print("  CMSG_GET_MY_RANK: 0x02")
        Print("  CMSG_GET_DETAILS: 0x03")
        Print("  CMSG_REFRESH: 0x04")
        Print("  CMSG_GET_SEASONS: 0x05")
        Print("  CMSG_TEST_TABLES: 0x06")
    else
        Print("Commands:")
        Print("  /lb or /leaderboard - Toggle leaderboard")
        Print("  /lb show|hide - Show or hide")
        Print("  /lb refresh - Force refresh data")
        Print("  /lb settings - Open settings")
        Print("  /lb clear - Clear cache")
        Print("  /lb status - Show addon status")
        Print("  /lb testtables - Test database connectivity")
        Print("  /lb seasons - Get available seasons")
        Print("  /lb setseason <id> - Set season (0=current)")
        Print("  /lb debug - Toggle verbose logging")
        Print("  /lb protocol - Show protocol info")
        Print("  /lb mplus|season|hlbg|prestige|upgrade|duel|aoe|achieve - Jump to category")
    end
end

-- =====================================================================
-- INITIALIZATION
-- =====================================================================

local function Initialize()
    -- Initialize settings
    LB:InitializeSettings()
    
    -- Get DC protocol reference
    DC = rawget(_G, "DCAddonProtocol")
    
    if DC then
        LB:RegisterHandlers()
        
        -- Add module to DC if not exists
        if not DC.Module.LEADERBOARD then
            DC.Module.LEADERBOARD = LB.MODULE
        end
        
        -- Add convenience wrapper
        DC.Leaderboard = {
            Request = function(cat, subcat, page) LB:RequestLeaderboard(cat, subcat, page) end,
            Show = function() LB:Show() end,
            Hide = function() LB:Hide() end,
        }
    else
        Print("|cffff6600Warning: DCAddonProtocol not found. Leaderboard requests will not work.|r")
    end
    
    -- Create settings panels
    LB:CreateSettingsPanel()
    LB:CreateCommunicationPanel()
    
    -- Show on login if enabled
    if LB:GetSetting("showOnLogin") then
        LB:Show()
    end
    
    Print("v" .. VERSION .. " loaded. Type /lb for help.")
end

-- Event handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        Initialize()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- Keybind support (optional)
-- Players can bind a key to: /click DCLeaderboardsToggle
local toggleBtn = CreateFrame("Button", "DCLeaderboardsToggle", UIParent, "SecureActionButtonTemplate")
toggleBtn:SetScript("OnClick", function()
    LB:Toggle()
end)

-- =====================================================================
-- STATISTICS UI
-- =====================================================================

function LB:CreateStatisticsUI(parent)
    -- Scroll frame for statistics
    local scrollFrame = CreateFrame("ScrollFrame", "DCLeaderboardsStatsScroll", parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(660, 440)
    scrollFrame:SetPoint("TOP", 0, -40)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(640, 1) -- Height grows with content
    scrollFrame:SetScrollChild(scrollChild)
    self.Frames.statsScrollChild = scrollChild
    
    -- Sub-header
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 10, -10)
    header:SetText("Statistics Overview")
    self.Frames.statsHeader = header
    
    -- Entry pool
    self.statsEntryPool = {}
end

function LB:GetOrCreateStatsEntry(index)
    if self.statsEntryPool[index] then
        self.statsEntryPool[index]:Show()
        return self.statsEntryPool[index]
    end
    
    local parent = self.Frames.statsScrollChild
    local entry = CreateFrame("Frame", nil, parent)
    entry:SetSize(640, 24)
    entry:SetPoint("TOPLEFT", 5, -(index - 1) * 26)
    
    local bg = entry:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0.1, 0.1, 0.1, (index % 2 == 0) and 0.4 or 0.2)
    entry.bg = bg
    
    -- Category Name
    entry.catName = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    entry.catName:SetPoint("LEFT", 5, 0)
    entry.catName:SetWidth(150)
    entry.catName:SetJustifyH("LEFT")
    entry.catName:SetTextColor(0.7, 0.7, 0.7)
    
    -- Subcategory Name
    entry.subName = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    entry.subName:SetPoint("LEFT", 160, 0)
    entry.subName:SetWidth(180)
    entry.subName:SetJustifyH("LEFT")
    
    -- Rank
    entry.rank = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    entry.rank:SetPoint("LEFT", 350, 0)
    entry.rank:SetWidth(80)
    entry.rank:SetJustifyH("RIGHT")
    
    -- Score/Value
    entry.score = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    entry.score:SetPoint("LEFT", 440, 0)
    entry.score:SetWidth(120)
    entry.score:SetJustifyH("RIGHT")
    
    -- Percentile
    entry.pct = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    entry.pct:SetPoint("LEFT", 570, 0)
    entry.pct:SetWidth(60)
    entry.pct:SetJustifyH("RIGHT")
    entry.pct:SetTextColor(0.5, 0.5, 0.5)
    
    self.statsEntryPool[index] = entry
    return entry
end

function LB:UpdateStatisticsDisplay()
    local container = self.Frames.statsScrollChild
    if not container then return end
    
    -- Hide all existing
    for _, f in pairs(self.statsEntryPool) do f:Hide() end
    
    local subcat = self.currentSubCategory
    
    if subcat == "stats_account" then
        self.Frames.statsHeader:SetText("Account Overview")
        
        local accountData = self.Cache.accountStats
        
        -- If no data yet, request it
        if not accountData then
            local entry = self:GetOrCreateStatsEntry(1)
            entry.catName:SetText("")
            entry.subName:SetText("|cff888888Loading account data...|r")
            entry.rank:SetText("-")
            entry.score:SetText("-")
            entry.pct:SetText("")
            
            -- Request account stats
            self:RequestAccountStats()
            return
        end
        
        local index = 1
        
        -- Display characters
        if accountData.characters and #accountData.characters > 0 then
            -- Header row
            local headerEntry = self:GetOrCreateStatsEntry(index)
            headerEntry.catName:SetText("|cffffd700Character|r")
            headerEntry.subName:SetText("|cffffd700Class|r")
            headerEntry.rank:SetText("|cffffd700Level|r")
            headerEntry.score:SetText("|cffffd700Best Rank|r")
            headerEntry.pct:SetText("")
            index = index + 1
            
            for _, char in ipairs(accountData.characters) do
                local entry = self:GetOrCreateStatsEntry(index)
                
                -- Character name with class color
                local classColor = CLASS_COLORS[char.class] or "FFFFFF"
                entry.catName:SetText("|cff" .. classColor .. (char.name or "Unknown") .. "|r")
                
                -- Class
                entry.subName:SetText(char.class or "Unknown")
                
                -- Level
                entry.rank:SetText(tostring(char.level or 0))
                entry.rank:SetTextColor(1, 1, 1)
                
                -- Best rank (if available)
                if char.bestRank and char.bestRank > 0 then
                    entry.score:SetText("#" .. char.bestRank)
                else
                    entry.score:SetText("-")
                end
                
                -- Best category (if available)
                entry.pct:SetText(char.bestCategory or "")
                
                index = index + 1
            end
        else
            local entry = self:GetOrCreateStatsEntry(index)
            entry.catName:SetText("")
            entry.subName:SetText("|cff888888No characters found|r")
            entry.rank:SetText("-")
            entry.score:SetText("-")
            entry.pct:SetText("")
            index = index + 1
        end
        
        -- Display totals if available
        if accountData.totals then
            index = index + 1 -- Spacer
            local totalsHeader = self:GetOrCreateStatsEntry(index)
            totalsHeader.catName:SetText("|cffffd700Account Totals|r")
            totalsHeader.subName:SetText("")
            totalsHeader.rank:SetText("")
            totalsHeader.score:SetText("")
            totalsHeader.pct:SetText("")
            index = index + 1
            
            for statName, statValue in pairs(accountData.totals) do
                local entry = self:GetOrCreateStatsEntry(index)
                entry.catName:SetText("")
                entry.subName:SetText(statName)
                entry.rank:SetText("")
                entry.score:SetText(FormatNumber(statValue))
                entry.pct:SetText("")
                index = index + 1
            end
        end
        
        container:SetSize(640, index * 26)
        return
    end
    
    self.Frames.statsHeader:SetText("Character Overview")
    
    local index = 1
    
    -- Iterate all known categories
    for _, cat in ipairs(self.Categories) do
        if cat.id ~= "statistics" then
            for _, sub in ipairs(cat.subcats) do
                -- Display row
                local entry = self:GetOrCreateStatsEntry(index)
                
                -- Set labels
                entry.catName:SetText(cat.name)
                entry.subName:SetText(sub.name)
                
                -- Check myRank cache
                local key = cat.id .. "_" .. sub.id
                local myData = self.Cache.myRanks[key]
                
                if myData then
                    -- Rank
                    if myData.rank and myData.rank > 0 then
                        entry.rank:SetText("#" .. myData.rank)
                        entry.rank:SetTextColor(0, 1, 0) -- Green
                    else
                        entry.rank:SetText("-")
                        entry.rank:SetTextColor(0.5, 0.5, 0.5)
                    end
                    
                    -- Score
                    local valStr = "-"
                    if myData.score then
                        if sub.id:find("_time") then
                            valStr = FormatTime(tonumber(myData.score))
                        elseif sub.id:find("_gold") then
                             -- Handle gold formatting if needed
                             local copperVal = tonumber(myData.score) or 0
                             valStr = FormatMoney(copperVal)
                        else
                            valStr = FormatNumber(myData.score)
                        end
                    end
                    entry.score:SetText(valStr)
                    
                    -- Percentile
                    if myData.percentile then
                        entry.pct:SetText(string.format("Top %.1f%%", myData.percentile))
                    else
                        entry.pct:SetText("")
                    end
                else
                    entry.rank:SetText("...")
                    entry.score:SetText("...")
                    entry.pct:SetText("")
                    
                    -- Request it
                    self:RequestMyRank(cat.id, sub.id)
                end
                
                index = index + 1
            end
        end
    end
    
    container:SetSize(640, index * 26)
end

