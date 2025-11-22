--[[
    DC-Seasons AIO Communication Bridge (Eluna)
    
    Minimal Eluna script for Rochet2's AIO communication
    All core logic is in C++ (src/server/scripts/DC/Seasons/)
    
    This script only handles:
    - AIO message routing between server and client
    - Client UI updates via AIO
    
    Author: DarkChaos Development Team
    Date: November 22, 2025
]]--

local AIO = AIO or require("AIO")
local DC_Seasons = AIO.AddAddon()

-- =====================================================================
-- Configuration
-- =====================================================================

local CONFIG = {
    ENABLED = true,
    DEBUG = false
}

-- =====================================================================
-- Helper Functions
-- =====================================================================

local function DebugLog(msg)
    if CONFIG.DEBUG then
        print("[DC-Seasons AIO] " .. msg)
    end
end

-- =====================================================================
-- Server-Side AIO Handlers (called from C++)
-- =====================================================================

-- Notify client of reward earned
function DC_Seasons.NotifyRewardEarned(player, tokens, essence, source)
    if not CONFIG.ENABLED then return end
    
    DebugLog(string.format("NotifyRewardEarned: %s received %d tokens, %d essence from %s", 
        player:GetName(), tokens, essence, source))
    
    -- Send to client addon
    DC_Seasons.SendRewardNotification(player, tokens, essence, source)
end

-- Send player stats update to client
function DC_Seasons.UpdateClientStats(player, stats)
    if not CONFIG.ENABLED then return end
    
    DebugLog(string.format("UpdateClientStats for %s", player:GetName()))
    
    -- stats table contains: weeklyTokens, weeklyEssence, weeklyTokenCap, weeklyEssenceCap,
    -- quests, worldBosses, dungeonBosses
    DC_Seasons.SendStatsUpdate(player, stats)
end

-- Notify client of weekly reset
function DC_Seasons.NotifyWeeklyReset(player)
    if not CONFIG.ENABLED then return end
    
    DebugLog(string.format("NotifyWeeklyReset for %s", player:GetName()))
    
    DC_Seasons.SendWeeklyReset(player)
end

-- Notify client of weekly chest available
function DC_Seasons.NotifyWeeklyChest(player, chestData)
    if not CONFIG.ENABLED then return end
    
    DebugLog(string.format("NotifyWeeklyChest for %s", player:GetName()))
    
    -- chestData contains: slotsUnlocked, slot1Tokens, slot1Essence, etc.
    DC_Seasons.SendChestAvailable(player, chestData)
end

-- =====================================================================
-- Client-Side AIO Handlers (called from addon)
-- =====================================================================

-- Client requests stats update
function DC_Seasons.RequestStats(player)
    if not CONFIG.ENABLED then return end
    
    DebugLog(string.format("RequestStats from %s", player:GetName()))
    
    -- Query C++ for player stats
    -- This would call into C++ via Eluna API if needed
    -- For now, C++ will push stats automatically on login
end

-- Client requests chest collection
function DC_Seasons.RequestChestCollection(player)
    if not CONFIG.ENABLED then return end
    
    DebugLog(string.format("RequestChestCollection from %s", player:GetName()))
    
    -- Call C++ function to collect chest
    -- player:CollectSeasonalChest() -- This would be implemented in C++ Eluna bindings
end

-- =====================================================================
-- Events (Optional - mostly handled by C++)
-- =====================================================================

-- On player login, send initial data
local function OnLogin(event, player)
    if not CONFIG.ENABLED then return end
    
    DebugLog(string.format("OnLogin: %s", player:GetName()))
    
    -- C++ PlayerScript already handles login logic
    -- This is just for AIO initialization
    DC_Seasons.SendInitialData(player)
end

-- Register events
RegisterPlayerEvent(3, OnLogin) -- PLAYER_EVENT_ON_LOGIN = 3

-- =====================================================================
-- Module Load
-- =====================================================================

print("[DC-Seasons AIO] Loaded successfully! Communication bridge active.")
print("[DC-Seasons AIO] Core logic handled by C++ (src/server/scripts/DC/Seasons/)")
print("[DC-Seasons AIO] AIO version: " .. (AIO.GetVersion() or "Unknown"))

AIO.AddOnInit(function()
    print("[DC-Seasons AIO] AIO initialized, ready for client communication")
end)
