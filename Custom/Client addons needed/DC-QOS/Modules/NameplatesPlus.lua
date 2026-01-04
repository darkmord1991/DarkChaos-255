-- ============================================================
-- DC-QoS: NameplatesPlus Module
-- ============================================================
-- Enhanced nameplate features for DarkChaos-255
-- Now includes: Threat, Cast Bars, Debuffs
-- For full customization, use NotPlater
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local NameplatesPlus = {
    displayName = "Nameplates Plus",
    settingKey = "nameplatesPlus",
    icon = "Interface\\Icons\\Ability_Creature_Cursed_01",
    defaults = {
        nameplatesPlus = {
            enabled = true,
            -- Profile System
            currentProfile = "Default",
            profiles = {
                ["Default"] = {},  -- Will be populated on first load
            },
            -- Class Colors
            classColors = true,
            friendlyClassColors = true,
            enemyClassColors = true,
            -- Health
            showHealthPercent = true,
            healthPercentPosition = "CENTER",
            healthPercentFormat = "%d%%",
            showHealthRealValues = true,
            -- Target
            targetHighlight = true,
            targetHighlightColor = { r = 1, g = 1, b = 0, a = 0.8 },
            targetScale = 1.0,
            nonTargetAlpha = 0.7,
            -- Threat
            showThreat = true,
            threatColors = true,
            tankMode = false,
            -- Cast Bar
            showCastBar = true,
            castBarHeight = 8,
            castBarColor = { r = 1, g = 0.7, b = 0 },
            castBarInterruptColor = { r = 0.8, g = 0, b = 0 },
            showCastSpellName = true,
            showCastTime = true,
            -- Debuffs
            showDebuffs = true,
            debuffSize = 20,
            maxDebuffs = 4,
            onlyPlayerDebuffs = true,
            -- Aura Filtering
            auraFilter = {
                enabled = true,
                -- Whitelist: Only show these auras (empty = show all)
                whitelist = {},
                -- Blacklist: Never show these auras
                blacklist = {
                    -- Common non-important auras
                    "Mark of the Wild",
                    "Blessing of Kings",
                    "Arcane Intellect",
                    "Power Word: Fortitude",
                    "Prayer of Spirit",
                    "Divine Spirit",
                    "Thorns",
                    "Retribution Aura",
                },
                -- Priority auras (always show first)
                priority = {
                    -- CC effects
                    "Polymorph",
                    "Fear",
                    "Cyclone",
                    "Hex",
                    "Blind",
                    "Sap",
                    "Gouge",
                    "Kidney Shot",
                    "Hammer of Justice",
                },
                -- Minimum duration to show (0 = all)
                minDuration = 0,
                -- Maximum duration to show (0 = all)
                maxDuration = 0,
            },
            -- Range
            nameplateRange = 41,
            fadeOutOfRange = false,
            outOfRangeAlpha = 0.5,
            
            -- Visuals
            textureMode = "Blizzard", -- "Blizzard" or "Flat"
            
            -- Advanced Threat
            threatMode = "Auto", -- "Auto", "Tank", "DPS"
            showThreatValues = true, -- diff
            showThreatPercentage = true,
            
            -- Target Indicators
            targetNeon = true,
            targetArrows = true,
            
            -- NPC Icons
            npcIcons = true,
            npcIconSize = 24,
        },
    },
}

-- Merge defaults
for k, v in pairs(NameplatesPlus.defaults) do
    if addon.defaults[k] == nil then
        addon.defaults[k] = v
    else
        for k2, v2 in pairs(v) do
            if addon.defaults[k][k2] == nil then
                addon.defaults[k][k2] = v2
            end
        end
    end
end

-- ============================================================
-- State Variables
-- ============================================================
local hookedPlates = {}
local updateFrame = nil
local playerGUID = nil
local npcRoleCache = {} -- Name -> Role (Vendor, Innkeeper, etc)

local function SafeGetCVar(name)
    if type(GetCVar) ~= "function" then
        return nil
    end

    local ok, value = pcall(GetCVar, name)
    if ok then
        return value
    end
    return nil
end

local function SafeSetCVar(name, value)
    if type(SetCVar) ~= "function" then
        return false
    end

    local ok = pcall(SetCVar, name, value)
    return ok and true or false
end

-- Tip Scanning for NPC detection
local tipScanner = CreateFrame("GameTooltip", "DCQoS_TipScan", nil, "GameTooltipTemplate")
tipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")

local function GetNPCRole(unit)
    if not unit then return nil end
    local name = UnitName(unit)
    if not name then return nil end
    
    if npcRoleCache[name] then return npcRoleCache[name] end
    
    -- Scan tooltip
    tipScanner:ClearLines()
    tipScanner:SetUnit(unit)
    
    for i = 2, tipScanner:NumLines() do
        local line = _G["DCQoS_TipScanTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                if text:find("Vendor") or text:find("Merchant") then
                    npcRoleCache[name] = "Vendor"
                    return "Vendor"
                elseif text:find("Innkeeper") then
                    npcRoleCache[name] = "Innkeeper"
                    return "Innkeeper"
                elseif text:find("Flight Master") then
                    npcRoleCache[name] = "FlightMaster"
                    return "FlightMaster"
                elseif text:find("Trainer") then
                    npcRoleCache[name] = "Trainer"
                    return "Trainer"
                elseif text:find("Auctioneer") then
                    npcRoleCache[name] = "Auctioneer"
                    return "Auctioneer"
                elseif text:find("Banker") then
                    npcRoleCache[name] = "Banker"
                    return "Banker"
                end
            end
        end
    end
    
    return nil
end

-- Class colors reference
local CLASS_COLORS = RAID_CLASS_COLORS or {
    ["WARRIOR"]     = { r = 0.78, g = 0.61, b = 0.43 },
    ["PALADIN"]     = { r = 0.96, g = 0.55, b = 0.73 },
    ["HUNTER"]      = { r = 0.67, g = 0.83, b = 0.45 },
    ["ROGUE"]       = { r = 1.00, g = 0.96, b = 0.41 },
    ["PRIEST"]      = { r = 1.00, g = 1.00, b = 1.00 },
    ["DEATHKNIGHT"] = { r = 0.77, g = 0.12, b = 0.23 },
    ["SHAMAN"]      = { r = 0.00, g = 0.44, b = 0.87 },
    ["MAGE"]        = { r = 0.41, g = 0.80, b = 0.94 },
    ["WARLOCK"]     = { r = 0.58, g = 0.51, b = 0.79 },
    ["DRUID"]       = { r = 1.00, g = 0.49, b = 0.04 },
}

-- Threat colors
local THREAT_COLORS = {
    -- DPS/Healer mode (don't want aggro)
    dps = {
        safe    = { r = 0.2, g = 0.8, b = 0.2 },  -- Green: safe, low threat
        warning = { r = 1.0, g = 0.8, b = 0.0 },  -- Yellow: watch out
        danger  = { r = 1.0, g = 0.0, b = 0.0 },  -- Red: you have aggro!
    },
    -- Tank mode (want aggro)
    tank = {
        safe    = { r = 0.2, g = 0.8, b = 0.2 },  -- Green: you have aggro
        warning = { r = 1.0, g = 0.8, b = 0.0 },  -- Yellow: losing aggro
        danger  = { r = 1.0, g = 0.0, b = 0.0 },  -- Red: lost aggro!
    },
}

-- Automatic Threat Mode Detection
local function GetAutomaticThreatMode()
    -- Check Stance/Form
    local form = GetShapeshiftForm()
    local _, class = UnitClass("player")
    
    if class == "WARRIOR" and form == 2 then return "tank" end -- Defensive Stance
    if class == "DRUID" and form == 1 then return "tank" end -- Bear Form
    if class == "DEATHKNIGHT" and GetShapeshiftForm() == 1 then return "tank" end -- Blood Presence (simplified check)
    if class == "PALADIN" and GetIcons and GetIcons() == "Righteous Fury" then return "tank" end -- Hard to check RF easily without buff scan
    
    return "dps"
end

-- ============================================================
-- Helper Functions
-- ============================================================
local function GetPlateUnit(frame)
    if frame.unit then return frame.unit end
    
    local nameText = frame.dcNameText or frame.name
    if nameText then
        local name = nameText:GetText()
        if name then
            if UnitName("target") == name then return "target" end
            if UnitName("focus") == name then return "focus" end
            if UnitName("mouseover") == name then return "mouseover" end
            
            for i = 1, 4 do
                if UnitName("party" .. i .. "target") == name then 
                    return "party" .. i .. "target" 
                end
            end
            for i = 1, 40 do
                if UnitName("raid" .. i .. "target") == name then
                    return "raid" .. i .. "target"
                end
            end
        end
    end
    
    return nil
end

local function IsPlateTarget(frame)
    local nameText = frame.dcNameText or frame.name
    if not nameText then return false end
    
    local name = nameText:GetText()
    local targetName = UnitName("target")
    
    return name and targetName and name == targetName and frame:GetAlpha() >= 0.99
end

local function GetUnitClass(unit)
    if not unit or not UnitExists(unit) then return nil end
    if not UnitIsPlayer(unit) then return nil end
    
    local _, classToken = UnitClass(unit)
    return classToken
end

-- ============================================================
-- Component Creation
-- ============================================================
local function CreateHealthPercentText(healthBar)
    if healthBar.dcHealthPercent then return healthBar.dcHealthPercent end
    
    local text = healthBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    text:SetTextColor(1, 1, 1)
    healthBar.dcHealthPercent = text
    
    return text
end

local function CreateTargetHighlight(frame)
    if frame.dcTargetHighlight then return frame.dcTargetHighlight end
    
    local highlight = frame:CreateTexture(nil, "OVERLAY")
    highlight:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Stealthed")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints()
    highlight:Hide()
    frame.dcTargetHighlight = highlight
    
    return highlight
end

local function CreateThreatGlow(frame, healthBar)
    if frame.dcThreatGlow then return frame.dcThreatGlow end
    
    local glow = frame:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Flash")
    glow:SetBlendMode("ADD")
    glow:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -5, 5)
    glow:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 5, -5)
    glow:SetVertexColor(1, 0, 0, 0.5)
    glow:Hide()
    frame.dcThreatGlow = glow
    
    -- Advanced Threat Text
    local diffText = healthBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    diffText:SetPoint("BOTTOMRIGHT", healthBar, "TOPRIGHT", 0, 2)
    diffText:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    diffText:Hide()
    healthBar.dcThreatDiff = diffText
    
    local pctText = healthBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pctText:SetPoint("BOTTOMLEFT", healthBar, "TOPLEFT", 0, 2)
    pctText:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    pctText:Hide()
    healthBar.dcThreatPct = pctText
    
    return glow
end

local function CreateTargetNeon(frame, healthBar)
    if frame.dcTargetNeon then return frame.dcTargetNeon end
    
    local neon = frame:CreateTexture(nil, "OVERLAY")
    neon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Flash")
    neon:SetBlendMode("ADD")
    neon:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -2, 2)
    neon:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 2, -2)
    neon:SetVertexColor(1, 1, 1, 0.5)
    neon:Hide()
    frame.dcTargetNeon = neon
    return neon
end

local function CreateNPCIcons(frame, healthBar)
    if frame.dcNPCIcons then return frame.dcNPCIcons end
    
    local iconFrame = CreateFrame("Frame", nil, frame)
    iconFrame:SetSize(24, 24)
    iconFrame:SetPoint("CENTER", healthBar, "CENTER", 0, 20)
    
    local icon = iconFrame:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints()
    iconFrame.texture = icon
    
    iconFrame:Hide()
    frame.dcNPCIcons = iconFrame
    return iconFrame
end

local function CreateCastBarOverlay(frame, originalCastBar)
    if frame.dcCastBarOverlay then return frame.dcCastBarOverlay end
    if not originalCastBar then return nil end
    
    -- Create our overlay on top of the existing cast bar
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetPoint("TOPLEFT", originalCastBar, "TOPLEFT")
    overlay:SetPoint("BOTTOMRIGHT", originalCastBar, "BOTTOMRIGHT")
    overlay:SetFrameLevel(frame:GetFrameLevel() + 5)
    
    -- Spell name text
    local spellName = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spellName:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    spellName:SetPoint("LEFT", overlay, "LEFT", 2, 0)
    spellName:SetTextColor(1, 1, 1)
    overlay.spellName = spellName
    
    -- Cast time text
    local castTime = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    castTime:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    castTime:SetPoint("RIGHT", overlay, "RIGHT", -2, 0)
    castTime:SetTextColor(1, 1, 1)
    overlay.castTime = castTime
    
    -- Shield icon for non-interruptible casts
    local shield = overlay:CreateTexture(nil, "OVERLAY")
    shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Small-Shield")
    shield:SetSize(16, 16)
    shield:SetPoint("LEFT", overlay, "RIGHT", 2, 0)
    shield:Hide()
    overlay.shield = shield
    
    frame.dcCastBarOverlay = overlay
    return overlay
end

local function CreateDebuffFrame(frame, healthBar)
    if frame.dcDebuffFrame then return frame.dcDebuffFrame end
    
    local settings = addon.settings.nameplatesPlus
    
    local debuffFrame = CreateFrame("Frame", nil, frame)
    debuffFrame:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", 0, -2)
    debuffFrame:SetSize(settings.debuffSize * settings.maxDebuffs, settings.debuffSize)
    debuffFrame.icons = {}
    
    for i = 1, settings.maxDebuffs do
        local icon = CreateFrame("Frame", nil, debuffFrame)
        icon:SetSize(settings.debuffSize, settings.debuffSize)
        icon:SetPoint("LEFT", (i - 1) * settings.debuffSize, 0)
        
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()
        icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        
        icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.cooldown:SetAllPoints()
        icon.cooldown:SetReverse(true)
        
        icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        icon.count:SetPoint("BOTTOMRIGHT", -1, 1)
        
        icon:Hide()
        debuffFrame.icons[i] = icon
    end
    
    frame.dcDebuffFrame = debuffFrame
    return debuffFrame
end

-- ============================================================
-- Update Functions
-- ============================================================
local function FormatNumber(currentValue)
    if currentValue >= 1000 then
        -- Round to nearest k: 14500 -> 15k, 14400 -> 14k
        return string.format("%.0fk", math.floor(currentValue / 1000 + 0.5))
    end
    return tostring(currentValue)
end

local function UpdateHealthPercent(healthBar, settings)
    if not settings.showHealthPercent then
        if healthBar.dcHealthPercent then healthBar.dcHealthPercent:Hide() end
        return
    end
    
    local min, max = healthBar:GetMinMaxValues()
    local cur = healthBar:GetValue()
    
    if max <= 0 then return end
    
    local percent = (cur / max) * 100
    local text = healthBar.dcHealthPercent or CreateHealthPercentText(healthBar)
    
    if settings.showHealthRealValues then
        text:SetText(string.format("%s/%s", FormatNumber(cur), FormatNumber(max)))
    else
        text:SetFormattedText(settings.healthPercentFormat, percent)
    end
    
    local pos = settings.healthPercentPosition
    text:ClearAllPoints()
    if pos == "LEFT" then
        text:SetPoint("LEFT", healthBar, "LEFT", 2, 0)
    elseif pos == "RIGHT" then
        text:SetPoint("RIGHT", healthBar, "RIGHT", -2, 0)
    else
        text:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
    end
    
    text:Show()
end

local function UpdateClassColor(healthBar, unit, settings)
    if not settings.classColors then return end
    
    local classToken = GetUnitClass(unit)
    if not classToken then return end
    
    local color = CLASS_COLORS[classToken]
    if not color then return end
    
    local isEnemy = UnitIsEnemy("player", unit)
    
    -- Ensure clean texture if Flat mode is active
    if settings.textureMode == "Flat" then
        healthBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    end
    
    if isEnemy and settings.enemyClassColors then
        healthBar:SetStatusBarColor(color.r, color.g, color.b)
    elseif not isEnemy and settings.friendlyClassColors then
        healthBar:SetStatusBarColor(color.r, color.g, color.b)
    end
end

local function UpdateThreat(frame, unit, settings)
    if not settings.showThreat then
        if frame.dcThreatGlow then frame.dcThreatGlow:Hide() end
        return
    end
    
    if not unit or not UnitExists(unit) then return end
    if UnitIsFriend("player", unit) then return end
    if not UnitAffectingCombat(unit) then
        if frame.dcThreatGlow then frame.dcThreatGlow:Hide() end
        return
    end
    
    local isTanking, status, scaledPercent = UnitDetailedThreatSituation("player", unit)
    local glow = frame.dcThreatGlow
    local healthBar = frame.dcHealthBar
    
    if not glow then
        glow = CreateThreatGlow(frame, healthBar)
    end
    
    if not status then
        glow:Hide()
        if healthBar.dcThreatDiff then healthBar.dcThreatDiff:Hide() end
        if healthBar.dcThreatPct then healthBar.dcThreatPct:Hide() end
        return
    end
    
    -- Determine Mode
    local mode = settings.tankMode and "tank" or "dps" -- Manual override
    if settings.threatMode == "Auto" then
        mode = GetAutomaticThreatMode()
    end
    
    local colors = (mode == "tank") and THREAT_COLORS.tank or THREAT_COLORS.dps
    local color
    local isTankingActually = (status >= 2) -- 3 is securely tanking, 2 is insecurely tanking
    
    -- Logic
    if mode == "tank" then
        if isTankingActually then
            color = colors.safe
        elseif status == 1 then
            color = colors.warning
        else
            color = colors.danger
        end
    else
        if isTankingActually then
            color = colors.danger
        elseif status == 1 then
            color = colors.warning
        else
            color = colors.safe
        end
    end
    
    if color then
        glow:SetVertexColor(color.r, color.g, color.b, 0.6)
        glow:Show()
        
        -- Advanced Threat Values
        if settings.showThreatValues then
            local _, _, percent, rawPercent, threatValue = UnitDetailedThreatSituation("player", unit)
            if threatValue then
                -- This is a simplification; getting "second highest" without scanning group is hard.
                -- We will show Absolute Threat or simple diff if we can.
                -- For 3.3.5a standalone without a library, we mainly know OUR threat.
                -- We can show threat PERCENT relative to aggro holder.
                
                if healthBar.dcThreatPct then
                    if rawPercent then
                        healthBar.dcThreatPct:SetText(string.format("%.0f%%", rawPercent))
                        healthBar.dcThreatPct:SetTextColor(color.r, color.g, color.b)
                        healthBar.dcThreatPct:Show()
                    else
                         healthBar.dcThreatPct:Hide()
                    end
                end
                
                if healthBar.dcThreatDiff then
                     -- Fake Diff: just show value k
                     healthBar.dcThreatDiff:SetText(FormatNumber(threatValue))
                     healthBar.dcThreatDiff:SetTextColor(color.r, color.g, color.b)
                     healthBar.dcThreatDiff:Show()
                end
            end
        end
        
        -- Also color the health bar if threatColors enabled
        if settings.threatColors and healthBar then
            healthBar:SetStatusBarColor(color.r, color.g, color.b)
        end
    end
end
    
local function UpdateNPCIcons(frame, unit, settings)
    if not settings.npcIcons then 
        if frame.dcNPCIcons then frame.dcNPCIcons:Hide() end
        return 
    end
    
    local role = GetNPCRole(unit)
    if not role then
        if frame.dcNPCIcons then frame.dcNPCIcons:Hide() end
        return
    end
    
    local iconFrame = frame.dcNPCIcons or CreateNPCIcons(frame, frame.dcHealthBar)
    local tex = ""
    
    if role == "Vendor" then tex = "Interface\\Icons\\Inv_Misc_Bag_10"
    elseif role == "Innkeeper" then tex = "Interface\\Icons\\Inv_Misc_Rune_01" -- Hearthstone-ish
    elseif role == "FlightMaster" then tex = "Interface\\Icons\\Taxi_Path"
    elseif role == "Trainer" then tex = "Interface\\Icons\\Inv_Misc_Book_09"
    elseif role == "Auctioneer" then tex = "Interface\\Icons\\Inv_Misc_Coin_02"
    elseif role == "Banker" then tex = "Interface\\Icons\\Inv_Box_02"
    end
    
    if tex ~= "" then
        iconFrame.texture:SetTexture(tex)
        iconFrame:Show()
    else
        iconFrame:Hide()
    end
end

local function UpdateCastBar(frame, castBar, unit, settings)
    if not settings.showCastBar then
        if frame.dcCastBarOverlay then frame.dcCastBarOverlay:Hide() end
        return
    end
    
    if not castBar or not castBar:IsShown() then
        if frame.dcCastBarOverlay then frame.dcCastBarOverlay:Hide() end
        return
    end
    
    local overlay = frame.dcCastBarOverlay or CreateCastBarOverlay(frame, castBar)
    if not overlay then return end
    
    -- Get casting info
    local spellName, _, _, _, startTime, endTime, _, castID, notInterruptible
    
    if unit and UnitExists(unit) then
        spellName, _, _, _, startTime, endTime, _, castID, notInterruptible = UnitCastingInfo(unit)
        if not spellName then
            spellName, _, _, _, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
        end
    end
    
    if spellName then
        if settings.showCastSpellName then
            overlay.spellName:SetText(spellName)
            overlay.spellName:Show()
        else
            overlay.spellName:Hide()
        end
        
        if settings.showCastTime and startTime and endTime then
            local remaining = (endTime - GetTime() * 1000) / 1000
            if remaining > 0 then
                overlay.castTime:SetFormattedText("%.1f", remaining)
                overlay.castTime:Show()
            else
                overlay.castTime:Hide()
            end
        else
            overlay.castTime:Hide()
        end
        
        -- Color based on interruptibility
        if notInterruptible then
            castBar:SetStatusBarColor(settings.castBarInterruptColor.r, settings.castBarInterruptColor.g, settings.castBarInterruptColor.b)
            overlay.shield:Show()
        else
            castBar:SetStatusBarColor(settings.castBarColor.r, settings.castBarColor.g, settings.castBarColor.b)
            overlay.shield:Hide()
        end
        
        overlay:Show()
    else
        overlay:Hide()
    end
end

local function UpdateDebuffs(frame, unit, settings)
    if not settings.showDebuffs then
        if frame.dcDebuffFrame then frame.dcDebuffFrame:Hide() end
        return
    end
    
    if not unit or not UnitExists(unit) then
        if frame.dcDebuffFrame then frame.dcDebuffFrame:Hide() end
        return
    end
    
    local debuffFrame = frame.dcDebuffFrame or CreateDebuffFrame(frame, frame.dcHealthBar)
    if not debuffFrame then return end
    
    local auraFilter = settings.auraFilter or {}
    local filterEnabled = auraFilter.enabled
    
    -- Helper: Check if aura passes filters
    local function ShouldShowAura(auraName, duration, caster)
        -- Check caster filter first
        if settings.onlyPlayerDebuffs and caster ~= "player" then
            return false, 0
        end
        
        if not filterEnabled then
            return true, 0
        end
        
        -- Check blacklist
        if auraFilter.blacklist then
            for _, blacklisted in ipairs(auraFilter.blacklist) do
                if auraName == blacklisted then
                    return false, 0
                end
            end
        end
        
        -- Check whitelist (if not empty, only show whitelisted)
        if auraFilter.whitelist and #auraFilter.whitelist > 0 then
            local found = false
            for _, whitelisted in ipairs(auraFilter.whitelist) do
                if auraName == whitelisted then
                    found = true
                    break
                end
            end
            if not found then
                return false, 0
            end
        end
        
        -- Check duration filters
        if auraFilter.minDuration and auraFilter.minDuration > 0 then
            if duration and duration < auraFilter.minDuration then
                return false, 0
            end
        end
        
        if auraFilter.maxDuration and auraFilter.maxDuration > 0 then
            if duration and duration > auraFilter.maxDuration then
                return false, 0
            end
        end
        
        -- Check priority (return priority value for sorting)
        local priority = 0
        if auraFilter.priority then
            for i, priorityAura in ipairs(auraFilter.priority) do
                if auraName == priorityAura then
                    priority = 100 - i  -- Higher priority = lower index
                    break
                end
            end
        end
        
        return true, priority
    end
    
    -- Collect and sort auras
    local auras = {}
    local index = 1
    
    while true do
        local name, _, icon, count, debuffType, duration, expirationTime, caster = UnitDebuff(unit, index)
        if not name then break end
        
        local shouldShow, priority = ShouldShowAura(name, duration, caster)
        if shouldShow then
            table.insert(auras, {
                name = name,
                icon = icon,
                count = count,
                duration = duration,
                expirationTime = expirationTime,
                priority = priority,
            })
        end
        
        index = index + 1
    end
    
    -- Sort by priority (highest first)
    table.sort(auras, function(a, b) return a.priority > b.priority end)
    
    -- Display auras
    local debuffIndex = 1
    for i, aura in ipairs(auras) do
        if debuffIndex > settings.maxDebuffs then break end
        
        local iconFrame = debuffFrame.icons[debuffIndex]
        if iconFrame then
            iconFrame.texture:SetTexture(aura.icon)
            
            if aura.count and aura.count > 1 then
                iconFrame.count:SetText(aura.count)
                iconFrame.count:Show()
            else
                iconFrame.count:Hide()
            end
            
            if aura.duration and aura.duration > 0 and aura.expirationTime then
                iconFrame.cooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
                iconFrame.cooldown:Show()
            else
                iconFrame.cooldown:Hide()
            end
            
            iconFrame:Show()
            debuffIndex = debuffIndex + 1
        end
    end
    
    -- Hide remaining icons
    -- Hide unused icons
    for i = debuffIndex, settings.maxDebuffs do
        if debuffFrame.icons[i] then
            debuffFrame.icons[i]:Hide()
        end
    end
    
    debuffFrame:Show()
end

local function UpdateTargetHighlight(frame, settings)
    if not settings.targetHighlight then
        if frame.dcTargetHighlight then frame.dcTargetHighlight:Hide() end
        return
    end
    
    local isTarget = IsPlateTarget(frame)
    local highlight = frame.dcTargetHighlight or CreateTargetHighlight(frame)
    local c = settings.targetHighlightColor
    
    -- Neon Glow
    if settings.targetNeon then
        local neon = frame.dcTargetNeon or CreateTargetNeon(frame, frame.dcHealthBar)
        if isTarget then
            neon:SetVertexColor(c.r, c.g, c.b, c.a)
            neon:Show()
        else
            neon:Hide()
        end
    else
        if frame.dcTargetNeon then frame.dcTargetNeon:Hide() end
    end

    if isTarget then
        highlight:SetVertexColor(c.r, c.g, c.b, c.a)
        highlight:Show()
        frame.dcIsTarget = true
    else
        highlight:Hide()
        frame.dcIsTarget = false
    end
    
    -- Alpha handling
    if settings.nonTargetAlpha and settings.nonTargetAlpha < 1.0 and UnitExists("target") and not isTarget then
        frame:SetAlpha(settings.nonTargetAlpha)
    else
        frame:SetAlpha(1.0)
    end
end

-- ============================================================
-- Nameplate Hook
-- ============================================================
local function HookNameplate(frame)
    if hookedPlates[frame] then return end
    hookedPlates[frame] = true
    
    local settings = addon.settings.nameplatesPlus
    if not settings.enabled then return end
    
    local regions = { frame:GetRegions() }
    local children = { frame:GetChildren() }
    
    local healthBar = children[1]
    local castBar = children[2]
    
    -- Apply Texture Mode
    if healthBar and settings.textureMode == "Flat" then
        healthBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    end
    if castBar and settings.textureMode == "Flat" then
        castBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    end
    
    local nameText = nil
    local levelText = nil
    for i, region in ipairs(regions) do
        if region:GetObjectType() == "FontString" then
            local text = region:GetText()
            if text and text ~= "" then
                if not nameText then
                    nameText = region
                else
                    levelText = region
                end
            end
        end
    end
    
    frame.dcHealthBar = healthBar
    frame.dcCastBar = castBar
    frame.dcNameText = nameText
    frame.dcLevelText = levelText
    
    -- Create enhancements
    if healthBar then
        CreateHealthPercentText(healthBar)
        CreateThreatGlow(frame, healthBar)
    end
    
    CreateTargetHighlight(frame)
    
    if castBar then
        CreateCastBarOverlay(frame, castBar)
    end
    
    if healthBar then
        CreateDebuffFrame(frame, healthBar)
    end
    
    if healthBar then
        CreateNPCIcons(frame, healthBar)
    end
    
    -- Hook health bar updates
    if healthBar then
        healthBar:HookScript("OnValueChanged", function(self)
            local settings = addon.settings.nameplatesPlus
            if not settings.enabled then return end
            UpdateHealthPercent(self, settings)
        end)
    end
    
    -- Hook frame show
    frame:HookScript("OnShow", function(self)
        local settings = addon.settings.nameplatesPlus
        if not settings.enabled then return end
        
        -- Reset scale to 1.0 to ensure cleanliness
        self:SetScale(1.0)
        
        if self.dcHealthBar then
            UpdateHealthPercent(self.dcHealthBar, settings)
        end
    end)
end

-- ============================================================
-- WorldFrame Scanner
-- ============================================================
local lastWorldFrameChildren = 0

local function ScanWorldFrame()
    local settings = addon.settings.nameplatesPlus
    if not settings or not settings.enabled then return end
    
    local children = { WorldFrame:GetChildren() }
    
    if #children ~= lastWorldFrameChildren then
        lastWorldFrameChildren = #children
        
        for _, child in ipairs(children) do
            local regions = { child:GetRegions() }
            local childFrames = { child:GetChildren() }
            
            if #childFrames >= 2 and #regions >= 7 then
                local healthBar = childFrames[1]
                if healthBar and healthBar.GetStatusBarTexture then
                    HookNameplate(child)
                end
            end
        end
    end
end

local function OnUpdate(self, elapsed)
    local settings = addon.settings.nameplatesPlus
    if not settings or not settings.enabled then return end
    
    -- Throttle scanning
    self.scanElapsed = (self.scanElapsed or 0) + elapsed
    if self.scanElapsed >= 0.1 then
        self.scanElapsed = 0
        ScanWorldFrame()
    end
    
    -- Update all visible plates
    self.updateElapsed = (self.updateElapsed or 0) + elapsed
    if self.updateElapsed >= 0.05 then
        self.updateElapsed = 0
        
        for frame, _ in pairs(hookedPlates) do
            if frame:IsShown() then
                local unit = GetPlateUnit(frame)
                
                UpdateTargetHighlight(frame, settings)
                
                if unit then
                    UpdateClassColor(frame.dcHealthBar, unit, settings)
                    UpdateThreat(frame, unit, settings)
                    UpdateCastBar(frame, frame.dcCastBar, unit, settings)
                    UpdateDebuffs(frame, unit, settings)
                    UpdateNPCIcons(frame, unit, settings)
                    -- Ensure health text is always correct (fixes "missing values" bug)
                    UpdateHealthPercent(frame.dcHealthBar, settings)
                end
            end
        end
    end
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function NameplatesPlus.OnInitialize()
    addon:Debug("NameplatesPlus module initializing")
    playerGUID = UnitGUID("player")
    
    -- Force nameplate scale CVar to 1 to prevent "jumping"
    if SafeGetCVar("nameplateSelectedScale") ~= nil then
        SafeSetCVar("nameplateSelectedScale", "1")
    end
    
    -- Apply range setting
    if addon.settings.nameplatesPlus.nameplateRange then
        SafeSetCVar("nameplateMaxDistance", tostring(addon.settings.nameplatesPlus.nameplateRange))
    end
end

function NameplatesPlus.OnEnable()
    addon:Debug("NameplatesPlus module enabling")
    
    local settings = addon.settings.nameplatesPlus
    if not settings.enabled then return end
    
    if NotPlater then
        addon:Print("Notice: NotPlater detected. Some features may conflict.", true)
    end
    
    if not updateFrame then
        updateFrame = CreateFrame("Frame", "DCQoS_NameplatesFrame", UIParent)
        updateFrame:SetScript("OnUpdate", OnUpdate)
    end
    updateFrame:Show()
    
    ScanWorldFrame()
    
    -- Slash command
    SLASH_DCNP1 = "/dcnameplate"
    SLASH_DCNP2 = "/dcnp"
    SlashCmdList["DCNP"] = function(msg)
        msg = msg and strlower(strtrim(msg)) or ""
        
        if msg == "tank" then
            addon:SetSetting("nameplatesPlus.tankMode", true)
            addon:Print("Threat mode: TANK (green = you have aggro)", true)
        elseif msg == "dps" or msg == "healer" then
            addon:SetSetting("nameplatesPlus.tankMode", false)
            addon:Print("Threat mode: DPS/HEALER (green = safe)", true)
        elseif msg:match("^blacklist ") then
            local auraName = msg:match("^blacklist (.+)")
            if auraName then
                local filter = settings.auraFilter or {}
                filter.blacklist = filter.blacklist or {}
                table.insert(filter.blacklist, auraName)
                addon:Print("Added to blacklist: " .. auraName, true)
            end
        elseif msg:match("^whitelist ") then
            local auraName = msg:match("^whitelist (.+)")
            if auraName then
                local filter = settings.auraFilter or {}
                filter.whitelist = filter.whitelist or {}
                table.insert(filter.whitelist, auraName)
                addon:Print("Added to whitelist: " .. auraName, true)
            end
        elseif msg == "help" then
            addon:Print("NameplatesPlus Commands:", true)
            print("  |cffffd700/dcnp tank|r - Tank threat mode")
            print("  |cffffd700/dcnp dps|r - DPS/Healer threat mode")
            print("  |cffffd700/dcnp blacklist <aura>|r - Hide aura")
            print("  |cffffd700/dcnp whitelist <aura>|r - Priority aura")
        else
            addon:Print("Usage: /dcnp help", true)
        end
    end
end

function NameplatesPlus.OnDisable()
    addon:Debug("NameplatesPlus module disabling")
    
    if updateFrame then
        updateFrame:Hide()
    end
    
    for frame, _ in pairs(hookedPlates) do
        if frame.dcTargetHighlight then frame.dcTargetHighlight:Hide() end
        if frame.dcThreatGlow then frame.dcThreatGlow:Hide() end
        if frame.dcCastBarOverlay then frame.dcCastBarOverlay:Hide() end
        if frame.dcDebuffFrame then frame.dcDebuffFrame:Hide() end
        if frame.dcHealthBar and frame.dcHealthBar.dcHealthPercent then
            frame.dcHealthBar.dcHealthPercent:Hide()
        end
        frame:SetScale(1.0)
        frame:SetAlpha(1.0)
    end
end

-- ============================================================
-- Settings Panel Creation
-- ============================================================
function NameplatesPlus.CreateSettings(parent)
    local settings = addon.settings.nameplatesPlus
    
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Nameplates Plus Settings")
    
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(450)
    desc:SetJustifyH("LEFT")
    desc:SetText("Enhanced nameplates with threat, cast bars, and debuffs. Use |cffffd700/dcnp tank|r or |cffffd700/dcnp dps|r to switch threat mode.")
    
    local yOffset = -70
    
    if NotPlater then
        local notice = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        notice:SetPoint("TOPLEFT", 16, yOffset)
        notice:SetText("|cffff8800NotPlater detected - some features may conflict.|r")
        yOffset = yOffset - 25
    end
    
    -- Threat Section
    local threatHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    threatHeader:SetPoint("TOPLEFT", 16, yOffset)
    threatHeader:SetText("Threat Display")
    yOffset = yOffset - 25
    
    local threatCb = addon:CreateCheckbox(parent)
    threatCb:SetPoint("TOPLEFT", 16, yOffset)
    threatCb.Text:SetText("Show threat glow on nameplates")
    threatCb:SetChecked(settings.showThreat)
    threatCb:SetScript("OnClick", function(self)
        addon:SetSetting("nameplatesPlus.showThreat", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    local threatColorCb = addon:CreateCheckbox(parent)
    threatColorCb:SetPoint("TOPLEFT", 36, yOffset)
    threatColorCb.Text:SetText("Color health bar by threat status")
    threatColorCb:SetChecked(settings.threatColors)
    threatColorCb:SetScript("OnClick", function(self)
        addon:SetSetting("nameplatesPlus.threatColors", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    local tankModeCb = addon:CreateCheckbox(parent)
    tankModeCb:SetPoint("TOPLEFT", 36, yOffset)
    tankModeCb.Text:SetText("Tank mode (green = have aggro)")
    tankModeCb:SetChecked(settings.tankMode)
    tankModeCb:SetScript("OnClick", function(self)
        addon:SetSetting("nameplatesPlus.tankMode", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- Cast Bar Section
    local castHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    castHeader:SetPoint("TOPLEFT", 16, yOffset)
    castHeader:SetText("Cast Bars")
    yOffset = yOffset - 25
    
    local castCb = addon:CreateCheckbox(parent)
    castCb:SetPoint("TOPLEFT", 16, yOffset)
    castCb.Text:SetText("Enhance cast bars with spell name & time")
    castCb:SetChecked(settings.showCastBar)
    castCb:SetScript("OnClick", function(self)
        addon:SetSetting("nameplatesPlus.showCastBar", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- Debuffs Section
    local debuffHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    debuffHeader:SetPoint("TOPLEFT", 16, yOffset)
    debuffHeader:SetText("Debuff Tracking")
    yOffset = yOffset - 25
    
    local debuffCb = addon:CreateCheckbox(parent)
    debuffCb:SetPoint("TOPLEFT", 16, yOffset)
    debuffCb.Text:SetText("Show debuffs on nameplates")
    debuffCb:SetChecked(settings.showDebuffs)
    debuffCb:SetScript("OnClick", function(self)
        addon:SetSetting("nameplatesPlus.showDebuffs", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    local playerDebuffCb = addon:CreateCheckbox(parent)
    playerDebuffCb:SetPoint("TOPLEFT", 36, yOffset)
    playerDebuffCb.Text:SetText("Only show your debuffs")
    playerDebuffCb:SetChecked(settings.onlyPlayerDebuffs)
    playerDebuffCb:SetScript("OnClick", function(self)
        addon:SetSetting("nameplatesPlus.onlyPlayerDebuffs", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- Class Colors Section
    local classHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    classHeader:SetPoint("TOPLEFT", 16, yOffset)
    classHeader:SetText("Class Colors")
    yOffset = yOffset - 25
    
    local classColorsCb = addon:CreateCheckbox(parent)
    classColorsCb:SetPoint("TOPLEFT", 16, yOffset)
    classColorsCb.Text:SetText("Color health bars by class")
    classColorsCb:SetChecked(settings.classColors)
    classColorsCb:SetScript("OnClick", function(self)
        addon:SetSetting("nameplatesPlus.classColors", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- Health Section
    local healthHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    healthHeader:SetPoint("TOPLEFT", 16, yOffset)
    healthHeader:SetText("Health Display")
    yOffset = yOffset - 25
    
    local healthPctCb = addon:CreateCheckbox(parent)
    healthPctCb:SetPoint("TOPLEFT", 16, yOffset)
    healthPctCb.Text:SetText("Show health percentage")
    healthPctCb:SetChecked(settings.showHealthPercent)
    healthPctCb:SetScript("OnClick", function(self)
        addon:SetSetting("nameplatesPlus.showHealthPercent", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    local healthNumCb = addon:CreateCheckbox(parent)
    healthNumCb:SetPoint("TOPLEFT", 36, yOffset)
    healthNumCb.Text:SetText("Show actual health values (e.g. 15k/30k)")
    healthNumCb:SetChecked(settings.showHealthRealValues)
    healthNumCb:SetScript("OnClick", function(self)
        addon:SetSetting("nameplatesPlus.showHealthRealValues", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- Target Section
    local targetHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    targetHeader:SetPoint("TOPLEFT", 16, yOffset)
    targetHeader:SetText("Target Highlight")
    yOffset = yOffset - 25
    
    local targetCb = addon:CreateCheckbox(parent)
    targetCb:SetPoint("TOPLEFT", 16, yOffset)
    targetCb.Text:SetText("Highlight current target")
    targetCb:SetChecked(settings.targetHighlight)
    targetCb:SetScript("OnClick", function(self)
        addon:SetSetting("nameplatesPlus.targetHighlight", self:GetChecked())
    end)
    yOffset = yOffset - 35

    -- Visuals Section
    local visualHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    visualHeader:SetPoint("TOPLEFT", 16, yOffset)
    visualHeader:SetText("Visuals & Range")
    yOffset = yOffset - 25

    -- Texture Mode
    local textureCb = addon:CreateCheckbox(parent)
    textureCb:SetPoint("TOPLEFT", 16, yOffset)
    textureCb.Text:SetText("Use Flat (Sharp) Textures")
    textureCb:SetChecked(settings.textureMode == "Flat")
    textureCb:SetScript("OnClick", function(self)
        local mode = self:GetChecked() and "Flat" or "Blizzard"
        addon:SetSetting("nameplatesPlus.textureMode", mode)
        addon:Print("Reload UI required for texture changes to fully apply.", true)
    end)
    yOffset = yOffset - 25

    -- Range Slider
    local rangeSlider = CreateFrame("Slider", "DCQoSNameplateRange", parent, "OptionsSliderTemplate")
    rangeSlider:SetPoint("TOPLEFT", 20, yOffset - 10)
    rangeSlider:SetWidth(200)
    rangeSlider:SetHeight(17)
    rangeSlider:SetMinMaxValues(20, 41)
    rangeSlider:SetValueStep(1)
    rangeSlider:SetValue(settings.nameplateRange or 41)
    
    _G[rangeSlider:GetName() .. "Text"]:SetText("View Distance: " .. (settings.nameplateRange or 41) .. " yds")
    _G[rangeSlider:GetName() .. "Low"]:SetText("20")
    _G[rangeSlider:GetName() .. "High"]:SetText("41")
    
    rangeSlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value)
        addon:SetSetting("nameplatesPlus.nameplateRange", val)
        _G[self:GetName() .. "Text"]:SetText("View Distance: " .. val .. " yds")
        SafeSetCVar("nameplateMaxDistance", tostring(val))
    end)
    yOffset = yOffset - 50
    
    return yOffset - 50
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("NameplatesPlus", NameplatesPlus)
