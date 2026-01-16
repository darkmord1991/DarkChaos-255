--[[
    DC-Welcome: RestoreXP Module
    ============================
    
    Blizzard-like XP bar replacement for servers with max level > 80 (up to 255)
    Mimics MainMenuExpBar behavior exactly for WoW 3.3.5a
    
    Previously: Stand-alone DC-RestoreXP addon
    Now integrated into: DC-Welcome
    
    Author: DarkChaos-255
    Date: December 2025
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
        debug = false,
        enabled = true,
        shortNumbers = false,
        fontSize = 11,
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
    local msg = table.concat(parts, " ")
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFFDC-RestoreXP:|r " .. msg)
    end
end

-------------------------------------------------------------------------------
-- Find Blizzard's XP Bar
-------------------------------------------------------------------------------

local function FindBlizzardXPBar()
    local names = { "MainMenuExpBar", "MainMenuXPBar", "MainMenuBarExpBar" }
    for _, n in ipairs(names) do
        local f = _G[n]
        if f and type(f) == "table" and type(f.SetMinMaxValues) == "function" then
            return f
        end
    end
    return nil
end

local BlizzardXPBar = FindBlizzardXPBar()

-------------------------------------------------------------------------------
-- XP Bar State
-------------------------------------------------------------------------------

local addonXPBar = nil
local currentLevel = UnitLevel("player") or 1

-------------------------------------------------------------------------------
-- Check if player is at max level
-------------------------------------------------------------------------------

local function IsAtMaxLevel()
    local level = UnitLevel("player") or 1
    local maxLevel = GetSetting("maxLevel") or 255
    return level >= maxLevel
end

-------------------------------------------------------------------------------
-- Get XP color based on rested state
-------------------------------------------------------------------------------

local function GetXPBarColor()
    local restState = GetRestState()
    local exhaustionThreshold = GetXPExhaustion()
    
    -- Rested (blue)
    if restState == 1 and exhaustionThreshold and exhaustionThreshold > 0 then
        return 0.0, 0.39, 0.88, 1.0
    end
    
    -- Normal (purple)
    return 0.58, 0.0, 0.55, 1.0
end

local function FormatNumber(num)
    num = tonumber(num) or 0
    if num >= 1000000 then
        return string.format("%.1fm", num / 1000000)
    end
    if num >= 1000 then
        return string.format("%.1fk", num / 1000)
    end
    return tostring(num)
end

local function FormatFullNumber(num)
    num = tonumber(num) or 0
    local s = tostring(math.floor(num + 0.5))
    local negative = false
    if s:sub(1, 1) == "-" then
        negative = true
        s = s:sub(2)
    end

    local formatted = s
    while true do
        local newStr, n = formatted:gsub("^(%d+)(%d%d%d)", "%1,%2")
        formatted = newStr
        if n == 0 then break end
    end

    if negative then
        formatted = "-" .. formatted
    end
    return formatted
end

-------------------------------------------------------------------------------
-- Create Custom XP Bar
-------------------------------------------------------------------------------

local function CreateXPBar()
    if addonXPBar then return addonXPBar end
    
    local parent = UIParent
    local width = 1024
    local height = 14
    local point, relativeTo, relativePoint, xOfs, yOfs
    
    if BlizzardXPBar then
        parent = BlizzardXPBar:GetParent() or parent
        width = BlizzardXPBar:GetWidth() or width
        height = BlizzardXPBar:GetHeight() or height
        point, relativeTo, relativePoint, xOfs, yOfs = BlizzardXPBar:GetPoint(1)
    end

    local bar = CreateFrame("StatusBar", "DCWelcome_XPBar", parent)
    bar:SetSize(width, height)
    if point then
        bar:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
    else
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
    end
    
    if BlizzardXPBar then
        bar:SetFrameStrata(BlizzardXPBar:GetFrameStrata() or "MEDIUM")
        bar:SetFrameLevel((BlizzardXPBar:GetFrameLevel() or 0) + 2)
    else
        bar:SetFrameStrata("MEDIUM")
        bar:SetFrameLevel(10)
    end
    
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    local r, g, b, a = GetXPBarColor()
    bar:SetStatusBarColor(r, g, b, a)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    
    -- Background
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 0.5)
    bar.bg = bg

    -- Border/backdrop for readability
    if bar.SetBackdrop then
        bar:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        bar:SetBackdropColor(0, 0, 0, 0.6)
        bar:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.9)
    end
    
    -- XP Text
    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    if text.SetFont then
        text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", GetSetting("fontSize") or 11, "OUTLINE")
        text:SetShadowColor(0, 0, 0, 0.8)
        text:SetShadowOffset(1, -1)
    end
    text:SetText("")
    bar.text = text
    
    -- Rested overlay
    local rested = bar:CreateTexture(nil, "OVERLAY")
    rested:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    rested:SetPoint("LEFT", bar, "LEFT")
    rested:SetHeight(height)
    rested:SetWidth(0)
    rested:SetVertexColor(0.0, 0.39, 0.88, 0.25)
    rested:Hide()
    bar.rested = rested
    
    -- Exhaustion tick
    local tick = CreateFrame("Frame", "DCWelcome_XP_ExhaustionTick", bar)
    tick:SetSize(28, 28)
    tick:SetPoint("CENTER", bar, "LEFT", 0, 0)
    local tickTex = tick:CreateTexture(nil, "OVERLAY")
    tickTex:SetTexture("Interface\\MainMenuBar\\UI-ExhaustionTickNormal")
    tickTex:SetAllPoints(tick)
    tick:Hide()
    bar.exhaustionTick = tick
    
    -- Decorative slices
    local sliceFile = "Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf"
    local slices = {
        { offset = -384, texCoords = { 0, 1.0, 0.79296875, 0.83203125 } },
        { offset = -128, texCoords = { 0, 1.0, 0.54296875, 0.58203125 } },
        { offset = 128,  texCoords = { 0, 1.0, 0.29296875, 0.33203125 } },
        { offset = 384,  texCoords = { 0, 1.0, 0.04296875, 0.08203125 } },
    }
    for _, slice in ipairs(slices) do
        local tex = bar:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(sliceFile)
        tex:SetSize(256, 10)
        tex:SetPoint("BOTTOM", bar, "BOTTOM", slice.offset, 3)
        tex:SetTexCoord(unpack(slice.texCoords))
    end
    
    bar:Hide()
    addonXPBar = bar
    Debug("Created custom XP bar")
    return bar
end

-------------------------------------------------------------------------------
-- Update XP Bar
-------------------------------------------------------------------------------

local function UpdateXPBar()
    if not GetSetting("enabled") then
        if addonXPBar then addonXPBar:Hide() end
        if BlizzardXPBar then BlizzardXPBar:Show() end
        return
    end
    
    local level = UnitLevel("player") or 1
    currentLevel = level
    
    -- At max level: hide both bars
    if IsAtMaxLevel() then
        Debug("Player at max level " .. level .. ", hiding XP bar")
        if addonXPBar then addonXPBar:Hide() end
        if BlizzardXPBar then BlizzardXPBar:Hide() end
        return
    end
    
    local currentXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 1
    local exhaustion = GetXPExhaustion() or 0
    
    Debug(string.format("Level %d: %d/%d XP, Rested: %d", level, currentXP, maxXP, exhaustion))
    
    -- Levels 1-79: Use Blizzard bar if it exists
    if level <= 79 and BlizzardXPBar then
        Debug("Level <= 79: using Blizzard XP bar")
        if addonXPBar then addonXPBar:Hide() end
        BlizzardXPBar:Show()
        return
    end
    
    -- Levels 80+: Use custom bar
    Debug("Level >= 80: using custom XP bar")
    if not addonXPBar then CreateXPBar() end
    if not addonXPBar then
        Debug("ERROR: Failed to create addon XP bar")
        return
    end
    
    if BlizzardXPBar then BlizzardXPBar:Hide() end
    
    -- Update bar values
    addonXPBar:SetMinMaxValues(0, maxXP)
    addonXPBar:SetValue(currentXP)
    
    -- Update colors
    local r, g, b, a = GetXPBarColor()
    addonXPBar:SetStatusBarColor(r, g, b, a)
    if addonXPBar.bg then
        addonXPBar.bg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 0.5)
    end
    
    -- Update text
    local percent = (maxXP > 0) and ((currentXP / maxXP) * 100) or 0
    local useShort = GetSetting("shortNumbers") == true
    local curText = useShort and FormatNumber(currentXP) or FormatFullNumber(currentXP)
    local maxText = useShort and FormatNumber(maxXP) or FormatFullNumber(maxXP)
    local textStr = string.format("Level %d: %s / %s XP (%.1f%%)", level, curText, maxText, percent)
    if exhaustion > 0 then
        textStr = textStr .. string.format(" |cFF4080FF+%s rested|r", FormatFullNumber(exhaustion))
    end
    if addonXPBar.text then
        addonXPBar.text:SetText(textStr)
        if exhaustion > 0 then
            addonXPBar.text:SetTextColor(1, 0.82, 0, 1)
        else
            addonXPBar.text:SetTextColor(1, 1, 1, 1)
        end
    end
    
    -- Update rested overlay
    if exhaustion and exhaustion > 0 and maxXP > 0 then
        local restedEnd = currentXP + exhaustion
        if restedEnd > maxXP then restedEnd = maxXP end
        local restedWidth = ((restedEnd - currentXP) / maxXP) * (addonXPBar:GetWidth() or 1024)
        
        if addonXPBar.rested then
            addonXPBar.rested:SetWidth(restedWidth)
            addonXPBar.rested:SetPoint("LEFT", addonXPBar, "LEFT", (currentXP / maxXP) * (addonXPBar:GetWidth() or 1024), 0)
            addonXPBar.rested:Show()
        end
        
        if addonXPBar.exhaustionTick then
            local tickPos = (restedEnd / maxXP) * (addonXPBar:GetWidth() or 1024)
            addonXPBar.exhaustionTick:ClearAllPoints()
            addonXPBar.exhaustionTick:SetPoint("CENTER", addonXPBar, "LEFT", tickPos, 0)
            addonXPBar.exhaustionTick:Show()
        end
    else
        if addonXPBar.rested then addonXPBar.rested:Hide() end
        if addonXPBar.exhaustionTick then addonXPBar.exhaustionTick:Hide() end
    end
    
    addonXPBar:Show()
    Debug("Updated addon XP bar: " .. textStr)
end

-- Export update function
DCWelcome.RestoreXP.UpdateXPBar = UpdateXPBar
DCWelcome.RestoreXP.GetSetting = GetSetting
DCWelcome.RestoreXP.SetSetting = SetSetting

-------------------------------------------------------------------------------
-- Event Handler
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("UPDATE_EXHAUSTION")
eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    Debug("Event: " .. tostring(event))
    
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        -- Delayed update
        local delayFrame = CreateFrame("Frame")
        local elapsed = 0
        delayFrame:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed >= 0.5 then
                self:SetScript("OnUpdate", nil)
                UpdateXPBar()
            end
        end)
    else
        UpdateXPBar()
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
        print("  /dcxp enable - Enable XP bar")
        print("  /dcxp disable - Disable XP bar")
        print("  /dcxp debug on|off - Toggle debug")
        print("  /dcxp status - Show current status")
    elseif msg == "enable" then
        SetSetting("enabled", true)
        UpdateXPBar()
        print("|cFF00FFFFDC-RestoreXP:|r Enabled")
    elseif msg == "disable" then
        SetSetting("enabled", false)
        if addonXPBar then addonXPBar:Hide() end
        if BlizzardXPBar then BlizzardXPBar:Show() end
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
        print("  Max Level: " .. (GetSetting("maxLevel") or 255))
        print("  Current Level: " .. (UnitLevel("player") or 0))
        print("  Debug: " .. tostring(GetSetting("debug")))
        print("  Blizzard Bar Found: " .. tostring(BlizzardXPBar ~= nil))
        print("  Custom Bar Created: " .. tostring(addonXPBar ~= nil))
    else
        print("|cFF00FFFFDC-RestoreXP:|r Unknown command. Use '/dcxp help'")
    end
end

-- Mark as loaded
DCWelcome.RestoreXP.loaded = true
Debug("DC-RestoreXP module loaded")
