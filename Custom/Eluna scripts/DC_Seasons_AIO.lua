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

local okAIO, AIO = pcall(function()
    return AIO or require("AIO")
end)

if not okAIO or not AIO then
    local candidates = {
        "AIO.lua",
        "Custom/Eluna scripts/AIO.lua",
        "Custom/RochetAio/AIO-master/AIO.lua",
        "../AIO.lua"
    }
    for _, path in ipairs(candidates) do
        local ok = pcall(dofile, path)
        if ok and _G.AIO then
            AIO = _G.AIO
            break
        end
    end
end

if not AIO or type(AIO.AddHandlers) ~= "function" then
    print("[DC-Seasons AIO] ERROR: Rochet2 AIO not available; bridge disabled")
    return
end

local IS_SERVER = AIO.IsServer and AIO.IsServer()
if not IS_SERVER or type(RegisterPlayerEvent) ~= "function" then
    print("[DC-Seasons AIO] INFO: Client context detected; skipping server bridge load")
    return
end

local function NormalizePath(path)
    return path and path:gsub("\\", "/") or nil
end

local function ResolveAddonPath()
    local info = debug.getinfo(1, "S")
    local src = info and info.source or ""
    if src:sub(1, 1) == "@" then
        src = src:sub(2)
    end
    src = NormalizePath(src)
    local baseDir = src and src:match("(.*/)") or ""
    local candidateRoots = {
        baseDir,
        baseDir .. "../",
        baseDir .. "../../",
        "",
        "lua_scripts/",
        "./",
    }
    local relativeTargets = {
        "DC-Seasons.lua",
        "DC-Seasons/DC-Seasons.lua",
        "Client addons needed/DC-Seasons/DC-Seasons.lua",
        "Custom/Client addons needed/DC-Seasons/DC-Seasons.lua",
        "Interface/AddOns/DC-Seasons/DC-Seasons.lua",
        "addons/DC-Seasons/DC-Seasons.lua"
    }
    local checked = {}
    for _, root in ipairs(candidateRoots) do
        for _, target in ipairs(relativeTargets) do
            local candidate = NormalizePath(root .. target)
            if candidate and not checked[candidate] then
                checked[candidate] = true
                local file = io.open(candidate, "r")
                if file then
                    file:close()
                    return candidate
                end
            end
        end
    end
    return nil
end

local ADDON_NAME = "DC-Seasons"
local HANDLER_NAME = "DC_Seasons"
local ADDON_PATH = ResolveAddonPath()

-- Register this file as an addon payload so clients receive the code (server only)
if AIO.AddAddon then
    if ADDON_PATH then
        AIO.AddAddon(ADDON_PATH, ADDON_NAME)
        print(string.format("[DC-Seasons AIO] Addon payload registered from '%s'", ADDON_PATH))
    else
        print("[DC-Seasons AIO] WARNING: Unable to locate DC-Seasons addon payload; AIO clients will not receive UI code")
    end
end

local DC_Seasons = AIO.AddHandlers(HANDLER_NAME, {}) or {}

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

local function SafeSendToClient(player, handler, ...)
    if not player or type(AIO.Handle) ~= "function" then
        return
    end
    local ok, err = pcall(AIO.Handle, player, HANDLER_NAME, handler, ...)
    if not ok then
        print(string.format("[DC-Seasons AIO] ERROR sending '%s' to %s: %s", handler, player and player:GetName() or "<nil>", err))
    end
end

local function ClampStats(stats)
    stats = stats or {}
    return {
        weeklyTokens = stats.weeklyTokens or 0,
        weeklyEssence = stats.weeklyEssence or 0,
        weeklyTokenCap = stats.weeklyTokenCap or 0,
        weeklyEssenceCap = stats.weeklyEssenceCap or 0,
        quests = stats.quests or 0,
        worldBosses = stats.worldBosses or 0,
        dungeonBosses = stats.dungeonBosses or 0,
    }
end

-- =====================================================================
-- Outbound Client Messaging Helpers
-- =====================================================================

function DC_Seasons.SendRewardNotification(player, tokens, essence, source)
    SafeSendToClient(player, "OnRewardEarned", tokens or 0, essence or 0, source or "Unknown")
end

function DC_Seasons.SendStatsUpdate(player, stats)
    SafeSendToClient(player, "UpdateStats", ClampStats(stats))
end

function DC_Seasons.SendWeeklyReset(player)
    SafeSendToClient(player, "OnWeeklyReset")
end

function DC_Seasons.SendChestAvailable(player, chestData)
    SafeSendToClient(player, "OnWeeklyChest", chestData or {})
end

function DC_Seasons.SendInitialData(player)
    local payload = {
        version = AIO.GetVersion() or "unknown",
        serverTime = os.time(),
    }
    SafeSendToClient(player, "OnInitialData", payload)
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
