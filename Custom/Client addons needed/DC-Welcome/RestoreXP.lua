--[[
    DC-Welcome: RestoreXP Module
    ============================

    Keeps the *native* Blizzard experience bar (MainMenuExpBar) visible and
    fully functional past level 80 on servers with a raised level cap (up to
    255). 100% blizzlike: it reuses Blizzard's own bar -- native textures,
    rested overlay, exhaustion tick and hover text all come for free.

    How the client decides to hide the XP bar (verified against 3.3.5a FrameXML)
    --------------------------------------------------------------------------
    The hide is pure Lua, NOT the C++ engine:

      ReputationFrame.lua:
        MAX_PLAYER_LEVEL_TABLE = { [0]=60, [1]=70, [2]=80 }
        MAX_PLAYER_LEVEL = MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()]  -- 80 on WotLK

        function ReputationWatchBar_Update(newLevel)
            ...
            if ( newLevel < MAX_PLAYER_LEVEL and not IsXPUserDisabled() ) then
                MainMenuExpBar:Show();          -- XP bar
            else
                MainMenuExpBar:Hide();          -- gold "max level" bar
                MainMenuBarMaxLevelBar:Show();
            end
        end

    MAX_PLAYER_LEVEL is a plain, writable global. ReputationWatchBar_Update is
    re-run by FrameXML on PLAYER_LEVEL_UP / UPDATE_FACTION / login. So the entire
    fix is: raise MAX_PLAYER_LEVEL to the real cap, then refresh once. Across the
    whole default FrameXML, MAX_PLAYER_LEVEL is read in only three XP-bar related
    spots (this function x2 + the rested-tick hide in MainMenuBar.lua), so there
    are no quest/talent/PvP side effects -- raising it is the canonical, minimal,
    DLL-free fix for high-cap servers.

    Previously this module hand-built a custom StatusBar to mimic the bar; that
    is no longer needed.

    Author: DarkChaos-255
    Date: June 2026
]]

DCWelcome = DCWelcome or {}
DCWelcome.RestoreXP = DCWelcome.RestoreXP or {}

-------------------------------------------------------------------------------
-- Settings (stored in DC-Welcome's saved variables)
-------------------------------------------------------------------------------

local function GetSettings()
    DCWelcomeDB = DCWelcomeDB or {}

    local defaults = {
        maxLevel = 255,
        enabled = true,
        debug = false,
    }

    DCWelcomeDB.restoreXP = DCWelcomeDB.restoreXP or {}
    for k, v in pairs(defaults) do
        if DCWelcomeDB.restoreXP[k] == nil then
            DCWelcomeDB.restoreXP[k] = v
        end
    end
    return DCWelcomeDB.restoreXP
end

local function GetSetting(key)
    return GetSettings()[key]
end

local function SetSetting(key, value)
    GetSettings()[key] = value
end

-------------------------------------------------------------------------------
-- Debug Helper
-------------------------------------------------------------------------------

local function Debug(...)
    if not GetSetting("debug") then return end

    local parts = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        parts[#parts + 1] = (v == nil) and "nil" or tostring(v)
    end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFFDC-RestoreXP:|r " .. table.concat(parts, " "))
    end
end

-------------------------------------------------------------------------------
-- Core: raise the level cap so FrameXML keeps the native XP bar visible
-------------------------------------------------------------------------------

-- The client's default cap for this account's expansion (80 on WotLK). Captured
-- so /dcxp disable can cleanly restore vanilla behavior.
local function GetClientDefaultMaxLevel()
    if MAX_PLAYER_LEVEL_TABLE and type(GetAccountExpansionLevel) == "function" then
        local v = MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()]
        if v then return v end
    end
    return 80
end

local clientDefaultMaxLevel = GetClientDefaultMaxLevel()

local function GetConfiguredCap()
    local cap = tonumber(GetSetting("maxLevel")) or 255
    if cap < clientDefaultMaxLevel then
        cap = clientDefaultMaxLevel
    end
    return cap
end

-- Ask FrameXML to re-evaluate XP-bar visibility against the current cap.
local function RefreshNativeBar()
    if type(ReputationWatchBar_Update) == "function" then
        ReputationWatchBar_Update()
    end
    -- Refresh values / rested tick too (harmless if the bar is hidden).
    if type(MainMenuExpBar_Update) == "function" then
        MainMenuExpBar_Update()
    end
end

local function ApplyXPBar()
    if GetSetting("enabled") then
        MAX_PLAYER_LEVEL = GetConfiguredCap()
        Debug("MAX_PLAYER_LEVEL set to", MAX_PLAYER_LEVEL)
    else
        MAX_PLAYER_LEVEL = clientDefaultMaxLevel
        Debug("MAX_PLAYER_LEVEL restored to client default", clientDefaultMaxLevel)
    end

    RefreshNativeBar()
end

-- Exported API (kept for compatibility with the previous module surface).
DCWelcome.RestoreXP.UpdateXPBar = ApplyXPBar
DCWelcome.RestoreXP.GetSetting = GetSetting
DCWelcome.RestoreXP.SetSetting = SetSetting

-------------------------------------------------------------------------------
-- Event Handler
-------------------------------------------------------------------------------
-- We only need to (re)assert MAX_PLAYER_LEVEL and refresh once. FrameXML itself
-- re-runs ReputationWatchBar_Update on level-ups / faction changes thereafter,
-- and it reads the now-raised global, so the native bar stays correct.

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")

eventFrame:SetScript("OnEvent", function(self, event)
    Debug("Event:", event)

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        -- Let FrameXML finish its own login pass (which sets MAX_PLAYER_LEVEL
        -- to the client default) before we raise it.
        local delayFrame = CreateFrame("Frame")
        local elapsed = 0
        delayFrame:SetScript("OnUpdate", function(df, dt)
            elapsed = elapsed + dt
            if elapsed >= 0.5 then
                df:SetScript("OnUpdate", nil)
                ApplyXPBar()
            end
        end)
    else
        ApplyXPBar()
    end
end)

-------------------------------------------------------------------------------
-- Slash Commands (extend /welcome)
-------------------------------------------------------------------------------

SLASH_DCXP1 = "/dcxp"
SLASH_DCXP2 = "/xpbar"
SlashCmdList["DCXP"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$") or ""

    if msg == "" or msg == "help" then
        print("|cFF00FFFFDC-RestoreXP Commands:|r")
        print("  /dcxp enable - Keep the native XP bar visible past 80")
        print("  /dcxp disable - Restore default client behavior (hide at 80)")
        print("  /dcxp debug on|off - Toggle debug")
        print("  /dcxp status - Show current status")
    elseif msg == "enable" then
        SetSetting("enabled", true)
        ApplyXPBar()
        print("|cFF00FFFFDC-RestoreXP:|r Enabled")
    elseif msg == "disable" then
        SetSetting("enabled", false)
        ApplyXPBar()
        print("|cFF00FFFFDC-RestoreXP:|r Disabled")
    elseif msg == "debug on" then
        SetSetting("debug", true)
        print("|cFF00FFFFDC-RestoreXP:|r Debug enabled")
    elseif msg == "debug off" then
        SetSetting("debug", false)
        print("|cFF00FFFFDC-RestoreXP:|r Debug disabled")
    elseif msg == "status" then
        print("|cFF00FFFFDC-RestoreXP Status:|r")
        print("  Enabled: " .. tostring(GetSetting("enabled")))
        print("  Configured Cap: " .. tostring(GetConfiguredCap()))
        print("  Active MAX_PLAYER_LEVEL: " .. tostring(MAX_PLAYER_LEVEL))
        print("  Client Default Cap: " .. tostring(clientDefaultMaxLevel))
        print("  Current Level: " .. tostring(UnitLevel("player") or 0))
        print("  Debug: " .. tostring(GetSetting("debug")))
    else
        print("|cFF00FFFFDC-RestoreXP:|r Unknown command. Use '/dcxp help'")
    end
end

-- Mark as loaded
DCWelcome.RestoreXP.loaded = true
Debug("DC-RestoreXP module loaded (native-bar mode)")
