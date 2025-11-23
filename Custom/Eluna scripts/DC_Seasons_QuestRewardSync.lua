--[[
    DC-Seasons Quest Reward Sync (Eluna)
    
    Listens to quest completion events and sends AIO updates to client addon
    Works in parallel with C++ ItemUpgradeTokenHooks.cpp
    
    C++ handles: Database updates, token calculation, chat messages
    Lua handles: AIO communication to client addon UI
    
    Author: DarkChaos Development Team (Copilot Fix)
    Date: January 2025
]]--

-- Check if AIO is available
local AIO = AIO
if not AIO or type(AIO.Handle) ~= "function" then
    print("[DC-Seasons Sync] ERROR: AIO not available; client UI updates disabled")
    return
end

-- Check if DC_Seasons handler exists
if not AIO.GetHandlers or not AIO.GetHandlers()["DC_Seasons"] then
    print("[DC-Seasons Sync] ERROR: DC_Seasons AIO handler not loaded; skipping quest reward sync")
    return
end

-- Configuration
local CONFIG = {
    ENABLED = true,
    DEBUG = false,
    HANDLER_NAME = "DC_Seasons",
    SEASON = 1, -- Current season ID
}

-- Quest reward tiers (matching C++ ItemUpgradeTokenHooks.cpp logic)
local QUEST_REWARD_TRIVIAL = 0
local QUEST_REWARD_GREEN = 10
local QUEST_REWARD_YELLOW = 15
local QUEST_REWARD_ORANGE = 20
local QUEST_REWARD_RED = 25
local QUEST_REWARD_SKULL = 35

-- Helper: Calculate quest difficulty color
local function GetQuestDifficultyColor(questLevel, playerLevel)
    local diff = questLevel - playerLevel
    if diff <= -6 then return "gray" -- Trivial
    elseif diff <= -3 then return "green" -- Easy
    elseif diff <= 2 then return "yellow" -- Average
    elseif diff <= 5 then return "orange" -- Hard
    else return "red" -- Very Hard / Skull
    end
end

-- Helper: Calculate token reward (matching C++ logic)
local function CalculateQuestReward(questLevel, playerLevel)
    local diff = questLevel - playerLevel
    
    if diff <= -6 then return QUEST_REWARD_TRIVIAL end -- Trivial quests give 0
    if diff <= -3 then return QUEST_REWARD_GREEN end
    if diff <= 2 then return QUEST_REWARD_YELLOW end
    if diff <= 5 then return QUEST_REWARD_ORANGE end
    if diff <= 9 then return QUEST_REWARD_RED end
    return QUEST_REWARD_SKULL
end

-- Helper: Query player's current token balance
local function GetPlayerTokens(playerGuid, season)
    season = season or CONFIG.SEASON
    local query = CharacterDatabaseQuery(string.format(
        "SELECT amount FROM dc_player_upgrade_tokens WHERE player_guid = %d AND currency_type = 'upgrade_token' AND season = %d",
        playerGuid, season
    ))
    
    if query then
        local amount = query:GetUInt32(0)
        return amount
    end
    return 0
end

-- Helper: Query player's weekly token earning
local function GetPlayerWeeklyTokens(playerGuid, season)
    season = season or CONFIG.SEASON
    -- This would need weekly tracking table - simplified for now
    return 0
end

-- Helper: Send AIO stats update to client
local function SendStatsUpdate(player, tokens, essence)
    tokens = tokens or 0
    essence = essence or 0
    
    local stats = {
        weeklyTokens = tokens,
        weeklyEssence = essence,
        weeklyTokenCap = 5000,
        weeklyEssenceCap = 1000,
        quests = 0,
        worldBosses = 0,
        dungeonBosses = 0,
    }
    
    AIO.Handle(player, CONFIG.HANDLER_NAME, "UpdateStats", stats)
end

-- Helper: Send reward notification to client
local function SendRewardNotification(player, tokens, essence, source)
    tokens = tokens or 0
    essence = essence or 0
    source = source or "Unknown"
    
    AIO.Handle(player, CONFIG.HANDLER_NAME, "OnRewardEarned", tokens, essence, source)
end

-- Event Handler: PLAYER_EVENT_ON_QUEST_COMPLETE (event ID 19)
local function OnQuestComplete(event, player, quest)
    if not CONFIG.ENABLED or not player or not quest then
        return
    end
    
    local playerName = player:GetName()
    local playerLevel = player:GetLevel()
    local playerGuid = player:GetGUIDLow()
    local questId = quest:GetId()
    local questLevel = quest:GetLevel()
    local questTitle = quest:GetTitle() or "Unknown Quest"
    
    -- Calculate reward (matching C++ logic)
    local tokenReward = CalculateQuestReward(questLevel, playerLevel)
    
    if CONFIG.DEBUG then
        print(string.format("[DC-Seasons Sync] %s completed quest %d (%s) - Level %d vs %d = %d tokens",
            playerName, questId, questTitle, questLevel, playerLevel, tokenReward))
    end
    
    -- If trivial quest, don't send update (C++ already handled this)
    if tokenReward <= 0 then
        return
    end
    
    -- Query current token balance
    local currentTokens = GetPlayerTokens(playerGuid, CONFIG.SEASON)
    
    -- Send reward notification popup
    SendRewardNotification(player, tokenReward, 0, "Quest Complete: " .. questTitle)
    
    -- Send stats update
    SendStatsUpdate(player, currentTokens, 0)
    
    if CONFIG.DEBUG then
        print(string.format("[DC-Seasons Sync] Sent AIO update to %s: %d tokens, total: %d",
            playerName, tokenReward, currentTokens))
    end
end

-- Event Handler: PLAYER_EVENT_ON_LOGIN (event ID 3)
local function OnLogin(event, player)
    if not CONFIG.ENABLED or not player then
        return
    end
    
    local playerGuid = player:GetGUIDLow()
    local currentTokens = GetPlayerTokens(playerGuid, CONFIG.SEASON)
    
    -- Send initial stats to client on login
    SendStatsUpdate(player, currentTokens, 0)
    
    if CONFIG.DEBUG then
        print(string.format("[DC-Seasons Sync] %s logged in with %d tokens",
            player:GetName(), currentTokens))
    end
end

-- Register events
RegisterPlayerEvent(19, OnQuestComplete) -- PLAYER_EVENT_ON_QUEST_COMPLETE = 19
RegisterPlayerEvent(3, OnLogin) -- PLAYER_EVENT_ON_LOGIN = 3

print("[DC-Seasons Sync] Loaded successfully!")
print("[DC-Seasons Sync] Listening for quest completions to sync client UI")
