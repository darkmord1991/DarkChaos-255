-- ============================================================
-- DC-QoS: NameplatesPlus Module
-- ============================================================
-- Enhanced nameplate features for DarkChaos-255
-- Now includes: Threat, Cast Bars, Debuffs
-- For full customization, use NotPlater
-- ============================================================

local addon = DCQOS
local LibRangeCheck = LibStub and LibStub("LibRangeCheck-2.0", true)

local NAMEPLATE_STYLE_VERSION = 4
local FLAT_BAR_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local BLIZZARD_BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local LEGACY_TARGET_HIGHLIGHT_COLOR = { r = 1.00, g = 1.00, b = 0.00, a = 0.80 }
local LEGACY_TARGET_HIGHLIGHT_COLOR_V2 = { r = 0.98, g = 0.82, b = 0.30, a = 0.92 }
local DEFAULT_TARGET_HIGHLIGHT_COLOR = { r = 0.00, g = 0.52, b = 1.00, a = 0.75 }
local LEGACY_CAST_BAR_HEIGHT = 7
local DEFAULT_CAST_BAR_HEIGHT = 6
local LEGACY_CAST_BAR_COLOR = { r = 1.00, g = 0.70, b = 0.00 }
local LEGACY_CAST_BAR_COLOR_V2 = { r = 0.93, g = 0.68, b = 0.24 }
local DEFAULT_CAST_BAR_COLOR = { r = 0.765, g = 0.525, b = 0.00 }
local LEGACY_CAST_BAR_INTERRUPT_COLOR = { r = 0.80, g = 0.00, b = 0.00 }
local LEGACY_CAST_BAR_INTERRUPT_COLOR_V2 = { r = 0.74, g = 0.24, b = 0.20 }
local DEFAULT_CAST_BAR_INTERRUPT_COLOR = { r = 0.85, g = 0.20, b = 0.12 }
local DEFAULT_HEALTH_BAR_HEIGHT = 14
local HEALTH_BAR_BACKDROP_COLOR = { r = 0.10, g = 0.10, b = 0.10, a = 0.80 }
local HEALTH_BAR_BORDER_COLOR = { r = 0.00, g = 0.00, b = 0.00, a = 0.80 }
local CAST_BAR_BACKDROP_COLOR = { r = 0.10, g = 0.10, b = 0.10, a = 0.80 }
local CAST_BAR_BORDER_COLOR = { r = 0.00, g = 0.00, b = 0.00, a = 0.00 }

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
            styleVersion = NAMEPLATE_STYLE_VERSION,
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
            targetHighlightColor = DEFAULT_TARGET_HIGHLIGHT_COLOR,
            targetScale = 1.11,
            nonTargetAlpha = 0.95,
            -- Threat
            showThreat = true,
            threatColors = true,
            tankMode = false,
            -- Cast Bar
            showCastBar = true,
            castBarHeight = DEFAULT_CAST_BAR_HEIGHT,
            castBarColor = DEFAULT_CAST_BAR_COLOR,
            castBarInterruptColor = DEFAULT_CAST_BAR_INTERRUPT_COLOR,
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
            rangeFadeDistance = 30,
            
            -- Visuals
            textureMode = "Flat", -- "Blizzard" or "Flat"
            
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
            
            -- Elite/Rare Icons
            eliteIcons = true,
            
            -- Faction Icons
            factionIcons = true,
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
local groupGUIDCache = {} -- GUID -> unitID for group members (threat tracking)
local unitMatchToFrame = {}
local guidMatchToFrame = {}
local auraCache = {} -- GUID -> {auras table, timestamp} for aura throttling
local AURA_CACHE_DURATION = 0.2 -- Cache auras for 200ms to reduce scanning
local DEBUFF_REFRESH_INTERVAL = 0.25
local RANGE_REFRESH_INTERVAL = 0.20
local CUSTOM_HEALTH_INSET_X = 0
local CUSTOM_HEALTH_INSET_Y = 0
local DEFAULT_HEALTH_COLOR = { r = 0.50, g = 0.50, b = 1.00 }
local FRIENDLY_HEALTH_COLOR = { r = 0.38, g = 0.68, b = 1.00 }
local NEUTRAL_HEALTH_COLOR = { r = 0.92, g = 0.74, b = 0.16 }
local TARGET_ARROW_LEFT_OFFSET = -6
local TARGET_ARROW_RIGHT_OFFSET = 6
local NAME_TEXT_Y_OFFSET = -1
local LEVEL_TEXT_X_OFFSET = -3
local LEVEL_TEXT_Y_OFFSET = 1
local CASTBAR_Y_GAP = -3
local CASTBAR_BASE_HEIGHT = DEFAULT_CAST_BAR_HEIGHT
local NAMEPLATE_CASTBAR_CVAR = "ShowVKeyCastbar"
local originalNameplateCastBarCVar = nil
local TARGET_BORDER_PADDING = 0
local MOUSEOVER_BORDER_PADDING = 1
local MOUSEOVER_BORDER_COLOR = { r = 1.00, g = 1.00, b = 1.00, a = 0.32 }
local TARGET_BORDER_ALPHA_MULTIPLIER = 0.82
local ELITE_ICON_X_OFFSET = 4
local ELITE_ICON_Y_OFFSET = 0
local FACTION_ICON_X_OFFSET = -5
local FACTION_ICON_Y_OFFSET = 3
local NPC_ICON_X_OFFSET = -6
local NPC_ICON_Y_OFFSET = 14

local function GetConfiguredCastbarHeight(settings)
    local configured = tonumber(settings and settings.castBarHeight) or CASTBAR_BASE_HEIGHT
    if configured < 4 then
        return 4
    end
    return configured
end

local function GetConfiguredHealthBarHeight(settings, fallbackHeight)
    local height = tonumber(fallbackHeight) or DEFAULT_HEALTH_BAR_HEIGHT
    if settings and settings.textureMode == "Flat" then
        height = DEFAULT_HEALTH_BAR_HEIGHT
    end
    if height < 8 then
        return 8
    end
    return height
end

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

local function CopyColor(color)
    if type(color) ~= "table" then
        return nil
    end

    return {
        r = color.r,
        g = color.g,
        b = color.b,
        a = color.a,
    }
end

local function ColorMatches(color, reference)
    if type(color) ~= "table" or type(reference) ~= "table" then
        return false
    end

    local function NearlyEqual(lhs, rhs)
        if lhs == nil or rhs == nil then
            return lhs == rhs
        end

        return math.abs(lhs - rhs) < 0.001
    end

    return NearlyEqual(color.r, reference.r)
        and NearlyEqual(color.g, reference.g)
        and NearlyEqual(color.b, reference.b)
        and NearlyEqual(color.a, reference.a)
end

local function GetConfiguredBarTexture(settings)
    if settings and settings.textureMode == "Blizzard" then
        return BLIZZARD_BAR_TEXTURE
    end

    return FLAT_BAR_TEXTURE
end

local function MigrateNameplateStyleSettings(settings)
    if not settings then
        return
    end

    if (settings.styleVersion or 0) >= NAMEPLATE_STYLE_VERSION then
        return
    end

    if settings.textureMode == nil or settings.textureMode == "Blizzard" then
        settings.textureMode = "Flat"
    end

    if settings.targetHighlightColor == nil
        or ColorMatches(settings.targetHighlightColor, LEGACY_TARGET_HIGHLIGHT_COLOR)
        or ColorMatches(settings.targetHighlightColor, LEGACY_TARGET_HIGHLIGHT_COLOR_V2)
    then
        settings.targetHighlightColor = CopyColor(DEFAULT_TARGET_HIGHLIGHT_COLOR)
    end

    if settings.castBarColor == nil
        or ColorMatches(settings.castBarColor, LEGACY_CAST_BAR_COLOR)
        or ColorMatches(settings.castBarColor, LEGACY_CAST_BAR_COLOR_V2)
    then
        settings.castBarColor = CopyColor(DEFAULT_CAST_BAR_COLOR)
    end

    if settings.castBarInterruptColor == nil
        or ColorMatches(settings.castBarInterruptColor, LEGACY_CAST_BAR_INTERRUPT_COLOR)
        or ColorMatches(settings.castBarInterruptColor, LEGACY_CAST_BAR_INTERRUPT_COLOR_V2)
    then
        settings.castBarInterruptColor = CopyColor(DEFAULT_CAST_BAR_INTERRUPT_COLOR)
    end

    if settings.castBarHeight == nil or settings.castBarHeight == LEGACY_CAST_BAR_HEIGHT then
        settings.castBarHeight = DEFAULT_CAST_BAR_HEIGHT
    end

    if settings.targetScale == nil or math.abs((settings.targetScale or 1) - 1.0) < 0.001 then
        settings.targetScale = 1.11
    end

    if settings.nonTargetAlpha == nil or math.abs((settings.nonTargetAlpha or 1) - 0.7) < 0.001 then
        settings.nonTargetAlpha = 0.95
    end

    settings.styleVersion = NAMEPLATE_STYLE_VERSION
end

local function UpdateDefaultNameplateCastBarCVar(settings)
    if SafeGetCVar(NAMEPLATE_CASTBAR_CVAR) == nil then
        return
    end

    local current = SafeGetCVar(NAMEPLATE_CASTBAR_CVAR)
    if originalNameplateCastBarCVar == nil then
        originalNameplateCastBarCVar = current
    end

    if settings and settings.showCastBar then
        if current ~= "0" then
            SafeSetCVar(NAMEPLATE_CASTBAR_CVAR, "0")
        end
    elseif originalNameplateCastBarCVar ~= nil and current ~= originalNameplateCastBarCVar then
        SafeSetCVar(NAMEPLATE_CASTBAR_CVAR, originalNameplateCastBarCVar)
    end
end

local function HasExtendedNameplateDistanceApi()
    return type(SetNameplateDistance) == "function"
end

local function GetNameplateRangeBounds()
    if HasExtendedNameplateDistanceApi() then
        return 20, 100
    end

    return 20, 41
end

local function GetConfiguredNameplateRange(settings)
    local configured = tonumber(settings and settings.nameplateRange) or 41

    if configured < 20 then
        configured = 20
    end

    return math.floor(configured + 0.5)
end

local function ApplyNameplateRange(settings)
    local configured = GetConfiguredNameplateRange(settings)
    local _, maxRange = GetNameplateRangeBounds()
    local appliedRange = math.min(configured, maxRange)
    local stockRange = math.min(appliedRange, 41)

    SafeSetCVar("nameplateMaxDistance", tostring(stockRange))

    if HasExtendedNameplateDistanceApi() then
        pcall(SetNameplateDistance, appliedRange)
    end

    return appliedRange
end

local function ApplyNameplateCVars(settings)
    settings = settings or addon.settings.nameplatesPlus
    if not settings then
        return
    end

    ApplyNameplateRange(settings)
    SafeSetCVar("nameplateShowEnemies", "1")
    UpdateDefaultNameplateCastBarCVar(settings)

    if SafeGetCVar("nameplateShowEnemyMinions") ~= nil then
        SafeSetCVar("nameplateShowEnemyMinions", "1")
    end
end

local function IsPlaterActive()
    return rawget(_G, "Plater") ~= nil or rawget(_G, "PlaterDB") ~= nil
end

local UpdateDebuffFrameAnchor
local SyncCustomHealthBarLayout

local function StoreRegionLayout(region)
    if not region or region.dcOriginalLayout then
        return
    end

    local layout = { points = {} }
    local numPoints = region.GetNumPoints and region:GetNumPoints() or 0
    for index = 1, numPoints do
        local point, relativeTo, relativePoint, offsetX, offsetY = region:GetPoint(index)
        layout.points[index] = {
            point,
            relativeTo,
            relativePoint,
            offsetX,
            offsetY,
        }
    end

    if region.GetWidth then
        local width = region:GetWidth()
        if width and width > 0 then
            layout.width = width
        end
    end

    if region.GetHeight then
        local height = region:GetHeight()
        if height and height > 0 then
            layout.height = height
        end
    end

    region.dcOriginalLayout = layout
end

local function RestoreRegionLayout(region)
    local layout = region and region.dcOriginalLayout
    if not layout then
        return
    end

    region:ClearAllPoints()
    for _, point in ipairs(layout.points) do
        region:SetPoint(point[1], point[2], point[3], point[4], point[5])
    end

    if layout.width and region.SetWidth then
        region:SetWidth(layout.width)
    end

    if layout.height and region.SetHeight then
        region:SetHeight(layout.height)
    end
end

local function UpdateCastBarLayout(frame)
    if not frame then
        return
    end

    local castBar = frame.dcCastBar
    if not castBar then
        return
    end

    local castLayout = castBar.dcOriginalLayout or {}
    if castLayout.width and castBar.SetWidth then
        castBar:SetWidth(castLayout.width)
    end
    if castLayout.height and castBar.SetHeight then
        castBar:SetHeight(castLayout.height)
    end

    RestoreRegionLayout(castBar)

    if castBar:IsShown() then
        castBar:Hide()
    end
    if castBar:GetAlpha() ~= 0 then
        castBar:SetAlpha(0)
    end
end

local function NormalizeNameplateLayout(frame)
    if not frame or IsPlaterActive() then
        return
    end

    local healthBar = frame.dcHealthBar
    if not healthBar then
        return
    end

    local castBar = frame.dcCastBar
    local nameText = frame.dcNameText
    local levelText = frame.dcLevelText

    StoreRegionLayout(healthBar)
    StoreRegionLayout(castBar)
    StoreRegionLayout(nameText)
    StoreRegionLayout(levelText)

    local healthLayout = healthBar.dcOriginalLayout or {}
    if frame.dcSourceHealthBar then
        SyncCustomHealthBarLayout(healthBar, frame.dcSourceHealthBar,
            addon.settings.nameplatesPlus)
    else
        if healthLayout.width and healthBar.SetWidth then
            healthBar:SetWidth(healthLayout.width)
        end
        if healthBar.SetHeight then
            healthBar:SetHeight(GetConfiguredHealthBarHeight(
                addon.settings.nameplatesPlus,
                healthLayout.height
            ))
        end
        healthBar:ClearAllPoints()
        healthBar:SetPoint("TOP", frame, "TOP", 0, -6)
    end

    if castBar then
        UpdateCastBarLayout(frame)
    end

    if nameText then
        nameText:ClearAllPoints()
        nameText:SetPoint("TOP", healthBar, "BOTTOM", 0, NAME_TEXT_Y_OFFSET)
        nameText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        nameText:SetJustifyH("CENTER")
        nameText:SetAlpha(1)
    end

    if levelText then
        levelText:ClearAllPoints()
        levelText:SetPoint("BOTTOMRIGHT", healthBar, "TOPLEFT", LEVEL_TEXT_X_OFFSET, LEVEL_TEXT_Y_OFFSET)
        levelText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        levelText:SetTextColor(0.2, 1, 0.2)
        levelText:SetAlpha(1)
    end

    if frame.dcEliteIcon then
        frame.dcEliteIcon:ClearAllPoints()
        frame.dcEliteIcon:SetPoint("LEFT", healthBar, "RIGHT", ELITE_ICON_X_OFFSET, ELITE_ICON_Y_OFFSET)
    end

    if frame.dcFactionIcon then
        frame.dcFactionIcon:ClearAllPoints()
        frame.dcFactionIcon:SetPoint("BOTTOMRIGHT", healthBar, "TOPLEFT", FACTION_ICON_X_OFFSET, FACTION_ICON_Y_OFFSET)
    end

    if frame.dcNPCIcons then
        frame.dcNPCIcons:ClearAllPoints()
        frame.dcNPCIcons:SetPoint("BOTTOMRIGHT", healthBar, "TOPLEFT", NPC_ICON_X_OFFSET, NPC_ICON_Y_OFFSET)
    end

    UpdateDebuffFrameAnchor(frame)
end

local function RestoreNameplateLayout(frame)
    if not frame then
        return
    end

    RestoreRegionLayout(frame.dcHealthBar)
    RestoreRegionLayout(frame.dcCastBar)
    RestoreRegionLayout(frame.dcNameText)
    RestoreRegionLayout(frame.dcLevelText)
end

UpdateDebuffFrameAnchor = function(frame)
    if not frame or not frame.dcDebuffFrame or not frame.dcHealthBar then
        return
    end

    local anchor = frame.dcHealthBar
    if frame.dcCastBarOverlay and frame.dcCastBarOverlay:IsShown() then
        anchor = frame.dcCastBarOverlay
    end

    frame.dcDebuffFrame:ClearAllPoints()
    frame.dcDebuffFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
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

-- Elite/Rare Icon Textures
local ELITE_TEXTURE = "Interface\\TargetingFrame\\UI-TargetingFrame-Elite"
local RARE_TEXTURE = "Interface\\TargetingFrame\\UI-TargetingFrame-Rare"
local RARE_ELITE_TEXTURE = "Interface\\TargetingFrame\\UI-TargetingFrame-Rare-Elite"
local NOTPLATER_ELITE_ICON_TCOORDS = { 0.75, 1, 0, 1 }

local function GetNotPlaterEliteIconTexture()
    local addonToken = (NotPlater and NotPlater.addonName) or "NotPlater-3.3.5"
    return "Interface\\AddOns\\" .. addonToken .. "\\images\\glues-addon-icons.blp"
end

-- Faction Icon Textures
local FACTION_ALLIANCE = "Interface\\TargetingFrame\\UI-PVP-Alliance"
local FACTION_HORDE = "Interface\\TargetingFrame\\UI-PVP-Horde"

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
        safe    = { r = 0.50, g = 0.50, b = 1.00 },  -- Blue: safe, low threat
        warning = { r = 1.00, g = 0.80, b = 0.00 },  -- Amber: watch out
        danger  = { r = 1.00, g = 0.109, b = 0.00 }, -- Red: you have aggro!
    },
    -- Tank mode (want aggro)
    tank = {
        safe    = { r = 0.50, g = 0.50, b = 1.00 },  -- Blue: you have aggro
        warning = { r = 1.00, g = 0.80, b = 0.00 },  -- Amber: losing aggro
        danger  = { r = 1.00, g = 0.109, b = 0.00 }, -- Red: lost aggro!
    },
}

-- GROUP MEMBER GUID CACHING FIX: Cache group member GUIDs for threat tracking
local function UpdateGroupGUIDs()
    -- Clear old cache
    for k in pairs(groupGUIDCache) do
        groupGUIDCache[k] = nil
    end
    
    -- Cache player
    local pGUID = UnitGUID("player")
    if pGUID then
        groupGUIDCache[pGUID] = "player"
    end
    
    -- Cache party
    for i = 1, 4 do
        local unitId = "party" .. i
        local guid = UnitGUID(unitId)
        if guid then
            groupGUIDCache[guid] = unitId
        end
    end
    
    -- Cache raid
    for i = 1, 40 do
        local unitId = "raid" .. i
        local guid = UnitGUID(unitId)
        if guid then
            groupGUIDCache[guid] = unitId
        end
    end
end

-- Automatic Threat Mode Detection
local function GetAutomaticThreatMode()
    -- Check Stance/Form
    local form = GetShapeshiftForm()
    local _, class = UnitClass("player")
    
    if class == "WARRIOR" and form == 2 then return "tank" end -- Defensive Stance
    if class == "DRUID" and form == 1 then return "tank" end -- Bear Form
    if class == "DEATHKNIGHT" and GetShapeshiftForm() == 1 then return "tank" end -- Blood Presence (simplified check)
    if class == "PALADIN" then
        local buffIndex = 1
        while true do
            local buffName = UnitBuff("player", buffIndex)
            if not buffName then break end
            if buffName == "Righteous Fury" then
                return "tank"
            end
            buffIndex = buffIndex + 1
        end
    end
    
    return "dps"
end

-- ============================================================
-- Helper Functions
-- ============================================================
local function IsPlateTarget(frame)
    local nameText = frame.dcNameText or frame.name
    if not nameText then return false end
    
    local name = nameText:GetText()
    local targetName = UnitName("target")
    
    return name and targetName and name == targetName and frame:GetAlpha() >= 0.99
end

local function IsPlateMouseOver(frame)
    if not frame then
        return false
    end

    if frame.IsMouseOver then
        return frame:IsMouseOver()
    end

    if type(MouseIsOver) == "function" then
        return MouseIsOver(frame)
    end

    return false
end

local function GetNumericTextValue(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end

    local numericText = text:match("(%d+)")
    if not numericText then
        return nil
    end

    return tonumber(numericText)
end

local function GetPlateDisplaySignature(frame)
    if not frame then
        return ""
    end

    local nameText = frame.dcNameText and frame.dcNameText:GetText() or ""
    local levelText = frame.dcLevelText and frame.dcLevelText:GetText() or ""
    return tostring(nameText) .. "|" .. tostring(levelText)
end

local function InferClassificationFromPlate(frame)
    if not frame or not frame.dcLevelText then
        return nil
    end

    local levelText = frame.dcLevelText:GetText()
    if type(levelText) ~= "string" or levelText == "" then
        return nil
    end

    -- 3.3.5 plates typically expose elite/boss as + or ?? in level text.
    if levelText:find("%?%?") then
        return "worldboss"
    end

    if levelText:find("%+") then
        return "elite"
    end

    return nil
end

local function InferClassificationFromTexturePath(texturePath)
    if type(texturePath) ~= "string" then
        return nil
    end

    local path = string.lower(texturePath)

    if string.find(path, "nameplate-boss", 1, true) or string.find(path, "worldboss", 1, true) then
        return "worldboss"
    end

    if string.find(path, "rare-elite", 1, true) or string.find(path, "rareelite", 1, true) then
        return "rareelite"
    end

    if string.find(path, "nameplate-rare", 1, true) or string.find(path, "-rare", 1, true) then
        return "rare"
    end

    if string.find(path, "nameplate-elite", 1, true) or string.find(path, "-elite", 1, true) then
        return "elite"
    end

    return nil
end

local function InferClassificationFromSuppressedRegions(frame)
    local regions = frame and frame.dcSuppressedRegions
    if not regions then
        return nil
    end

    local fallback = nil
    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" and region.GetTexture then
            local texture = region:GetTexture()
            local classification = InferClassificationFromTexturePath(texture)
            if classification == "worldboss" or classification == "rareelite" then
                return classification
            end
            if classification and not fallback then
                fallback = classification
            end
        end
    end

    return fallback
end

local function GetEstimatedRange(unit)
    if not LibRangeCheck or not unit or not UnitExists(unit) then
        return nil
    end

    local _, maxRange = LibRangeCheck:GetRange(unit, true)
    if not maxRange then
        return nil
    end

    return maxRange
end

local function PlateMatchesUnit(frame, unit, matchContext)
    if not frame or not unit or not UnitExists(unit) or not frame.dcHealthBar then
        return false
    end

    local nameText = frame.dcNameText or frame.name
    if not nameText then
        return false
    end

    local plateName = nameText:GetText()
    if not plateName or plateName ~= UnitName(unit) then
        return false
    end

    local plateLevel = frame.dcLevelText and GetNumericTextValue(frame.dcLevelText:GetText()) or nil
    local unitLevel = type(UnitLevel) == "function" and UnitLevel(unit) or nil
    if plateLevel and unitLevel and plateLevel ~= unitLevel then
        return false
    end

    local healthValue = frame.dcHealthBar:GetValue()
    local unitHealth = type(UnitHealth) == "function" and UnitHealth(unit) or nil
    if unitHealth and healthValue ~= unitHealth then
        return false
    end

    if matchContext == "target" and not IsPlateTarget(frame) then
        return false
    end

    if matchContext == "mouseover" and not IsPlateMouseOver(frame) then
        return false
    end

    return true
end

local function IsGroupTargetUnit(unit)
    return type(unit) == "string" and (unit:match("^party%d+target$") or unit:match("^raid%d+target$"))
end

local function ReleaseFrameUnitMatch(frame)
    if not frame then
        return
    end

    local unit = frame.lastUnitMatch
    local guid = frame.lastGuidMatch
    if unit and unitMatchToFrame[unit] == frame then
        unitMatchToFrame[unit] = nil
    end
    if guid and guidMatchToFrame[guid] == frame then
        guidMatchToFrame[guid] = nil
    end
end

local function MarkFrameDirty(frame)
    if not frame then
        return
    end

    frame.dcUnitMatchDirty = true
    frame.dcDebuffDirty = true
    frame.dcRangeDirty = true
end

local function MarkAllFramesDirty()
    for frame in pairs(hookedPlates) do
        MarkFrameDirty(frame)
    end
end

local function InvalidateAuraCacheForUnit(unit)
    if not unit or not UnitExists(unit) then
        return
    end

    local guid = UnitGUID(unit)
    if guid then
        auraCache[guid] = nil
    end
end

local function MarkMatchedUnitDebuffsDirty(unit)
    if not unit then
        return
    end

    for frame in pairs(hookedPlates) do
        if frame.lastUnitMatch == unit then
            frame.dcDebuffDirty = true
        end
    end
end

local function ClearFrameUnitMatch(frame)
    if not frame then
        return
    end

    ReleaseFrameUnitMatch(frame)
    frame.lastUnitMatch = nil
    frame.lastGuidMatch = nil
    frame.dcDebuffDirty = true
end

local function SetFrameUnitMatch(frame, unit)
    if not frame then
        return false
    end

    local guid = unit and UnitGUID(unit) or nil
    if frame.lastUnitMatch == unit and frame.lastGuidMatch == guid then
        return true
    end

    if unit then
        local claimedFrame = unitMatchToFrame[unit]
        if claimedFrame and claimedFrame ~= frame and claimedFrame:IsShown() and PlateMatchesUnit(claimedFrame, unit, unit) then
            return false
        end

        if guid then
            local claimedGuidFrame = guidMatchToFrame[guid]
            if claimedGuidFrame and claimedGuidFrame ~= frame and claimedGuidFrame:IsShown() and PlateMatchesUnit(claimedGuidFrame, unit, unit) then
                return false
            end
        end
    end

    ReleaseFrameUnitMatch(frame)
    frame.lastUnitMatch = unit
    frame.lastGuidMatch = guid
    if unit then
        unitMatchToFrame[unit] = frame
    end
    if guid then
        guidMatchToFrame[guid] = frame
    end
    frame.dcDebuffDirty = true
    return true
end

local function FindUniqueFrameForUnit(unit, matchContext)
    if not unit or not UnitExists(unit) then
        return nil
    end

    local matchedFrame = nil
    for frame in pairs(hookedPlates) do
        if frame:IsShown() and PlateMatchesUnit(frame, unit, matchContext) then
            if matchedFrame then
                return nil
            end
            matchedFrame = frame
        end
    end

    return matchedFrame
end

local function RefreshTrackedUnitMatch(unit)
    local existing = unit and unitMatchToFrame[unit]
    if existing and existing.lastUnitMatch == unit then
        ClearFrameUnitMatch(existing)
    end

    if not unit or not UnitExists(unit) then
        return
    end

    local frame = FindUniqueFrameForUnit(unit, unit)
    if frame then
        SetFrameUnitMatch(frame, unit)
    end
end

local function HideTargetIndicators(frame)
    if not frame then
        return
    end

    if frame.dcTargetHighlight then
        frame.dcTargetHighlight:Hide()
    end
    if frame.dcMouseoverBorder then
        frame.dcMouseoverBorder:Hide()
    end
    if frame.dcTargetNeon then
        frame.dcTargetNeon:Hide()
    end
    if frame.dcTargetArrowLeft then
        frame.dcTargetArrowLeft:Hide()
    end
    if frame.dcTargetArrowRight then
        frame.dcTargetArrowRight:Hide()
    end
    -- Reset scale so plates don't stay zoomed after losing their unit match.
    if not IsPlaterActive() and frame.dcLastScale and frame.dcLastScale ~= 1.0 then
        frame:SetScale(1.0)
        frame.dcLastScale = 1.0
    end
    frame.dcIsTarget = nil
end

local function RestoreMouseoverNameText(frame)
    if not frame or not frame.dcNameText or not frame.dcNameTextOriginalColor then
        return
    end

    frame.dcNameText:SetTextColor(unpack(frame.dcNameTextOriginalColor))
    frame.dcNameTextOriginalColor = nil
end

local function ClearGroupTargetMatches()
    local unitsToClear = {}
    for unit in pairs(unitMatchToFrame) do
        if IsGroupTargetUnit(unit) then
            unitsToClear[#unitsToClear + 1] = unit
        end
    end

    for _, unit in ipairs(unitsToClear) do
        local frame = unitMatchToFrame[unit]
        if frame and frame.lastUnitMatch == unit then
            ClearFrameUnitMatch(frame)
        end
    end
end

local function RefreshGroupTargetMatch(unit)
    local existing = unit and unitMatchToFrame[unit]
    if existing and existing.lastUnitMatch == unit then
        ClearFrameUnitMatch(existing)
    end

    if not unit or not UnitExists(unit) then
        return
    end

    local frame = FindUniqueFrameForUnit(unit, "group-target")
    if frame and frame.lastUnitMatch ~= "target" and frame.lastUnitMatch ~= "focus" and frame.lastUnitMatch ~= "mouseover" then
        SetFrameUnitMatch(frame, unit)
    end
end

local function RefreshAllGroupTargetMatches()
    ClearGroupTargetMatches()

    for i = 1, 4 do
        RefreshGroupTargetMatch("party" .. i .. "target")
    end

    for i = 1, 40 do
        RefreshGroupTargetMatch("raid" .. i .. "target")
    end
end

local function RefreshAllTrackedUnitMatches()
    RefreshTrackedUnitMatch("target")
    RefreshTrackedUnitMatch("focus")
    RefreshTrackedUnitMatch("mouseover")
    RefreshAllGroupTargetMatches()
end

local function GetPlateUnit(frame)
    if not frame then
        return nil
    end

    if frame.unit and UnitExists(frame.unit) then
        return frame.unit
    end

    local matchedUnit = frame.lastUnitMatch
    if matchedUnit then
        if PlateMatchesUnit(frame, matchedUnit, matchedUnit) then
            frame.dcUnitMatchDirty = nil
            return matchedUnit
        end
        ClearFrameUnitMatch(frame)
    end

    frame.dcUnitMatchDirty = nil

    if PlateMatchesUnit(frame, "target", "target") and SetFrameUnitMatch(frame, "target") then
        return "target"
    end

    if PlateMatchesUnit(frame, "mouseover", "mouseover") and SetFrameUnitMatch(frame, "mouseover") then
        return "mouseover"
    end

    if UnitExists("focus") and PlateMatchesUnit(frame, "focus", "focus") and SetFrameUnitMatch(frame, "focus") then
        return "focus"
    end

    return frame.lastUnitMatch
end

local function GetUnitClass(unit)
    if not unit or not UnitExists(unit) then return nil end
    if not UnitIsPlayer(unit) then return nil end
    
    local _, classToken = UnitClass(unit)
    return classToken
end

local VALID_FRAME_STRATA = {
    BACKGROUND = true,
    LOW = true,
    MEDIUM = true,
    HIGH = true,
    DIALOG = true,
    FULLSCREEN = true,
    FULLSCREEN_DIALOG = true,
    TOOLTIP = true,
}

local function GetSafeFrameStrata(frame)
    if not frame or not frame.GetFrameStrata then
        return "MEDIUM"
    end

    local strata = frame:GetFrameStrata()
    if type(strata) ~= "string" then
        return "MEDIUM"
    end

    if VALID_FRAME_STRATA[strata] then
        return strata
    end

    return "MEDIUM"
end

-- ============================================================
-- Component Creation
-- ============================================================
local function CreateFullEdgeBorder(parent)
    if parent.dcFullEdgeBorder then
        return parent.dcFullEdgeBorder
    end

    local border = {}
    border.left = parent:CreateTexture(nil, "BORDER")
    border.right = parent:CreateTexture(nil, "BORDER")
    border.top = parent:CreateTexture(nil, "BORDER")
    border.bottom = parent:CreateTexture(nil, "BORDER")

    parent.dcFullEdgeBorder = border
    return border
end

local function ConfigureFullEdgeBorder(parent, thickness, r, g, b, a)
    local border = CreateFullEdgeBorder(parent)

    border.left:ClearAllPoints()
    border.left:SetTexture(r, g, b, a)
    border.left:SetWidth(thickness)
    border.left:SetPoint("TOPRIGHT", parent, "TOPLEFT", 0, thickness)
    border.left:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", 0, -thickness)

    border.right:ClearAllPoints()
    border.right:SetTexture(r, g, b, a)
    border.right:SetWidth(thickness)
    border.right:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, thickness)
    border.right:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 0, -thickness)

    border.top:ClearAllPoints()
    border.top:SetTexture(r, g, b, a)
    border.top:SetHeight(thickness)
    border.top:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, 0)
    border.top:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", 0, 0)

    border.bottom:ClearAllPoints()
    border.bottom:SetTexture(r, g, b, a)
    border.bottom:SetHeight(thickness)
    border.bottom:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    border.left:Show()
    border.right:Show()
    border.top:Show()
    border.bottom:Show()
end

local function EnsureBarBackdrop(statusBar)
    if not statusBar then
        return nil
    end

    local background = statusBar.background
    if not background then
        background = statusBar:CreateTexture(nil, "BACKGROUND")
        background:SetTexture(FLAT_BAR_TEXTURE)
        statusBar.background = background
    end

    background:ClearAllPoints()
    background:SetAllPoints(statusBar)
    return background
end

local function ApplyCustomBarStyle(statusBar, settings, backdropColor, borderColor)
    if not statusBar then
        return
    end

    local desiredTexture = GetConfiguredBarTexture(settings)
    local textureObject = statusBar.GetStatusBarTexture and statusBar:GetStatusBarTexture() or nil
    local currentTexture = textureObject and textureObject.GetTexture and textureObject:GetTexture() or nil
    if currentTexture ~= desiredTexture then
        statusBar:SetStatusBarTexture(desiredTexture)
    end

    local background = EnsureBarBackdrop(statusBar)
    local bgColor = backdropColor or HEALTH_BAR_BACKDROP_COLOR
    background:SetVertexColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)

    local edgeColor = borderColor or HEALTH_BAR_BORDER_COLOR
    if edgeColor.a and edgeColor.a > 0 then
        ConfigureFullEdgeBorder(statusBar, 1, edgeColor.r, edgeColor.g, edgeColor.b, edgeColor.a)
    elseif statusBar.border then
        statusBar.border.left:Hide()
        statusBar.border.right:Hide()
        statusBar.border.top:Hide()
        statusBar.border.bottom:Hide()
    end
end

SyncCustomHealthBarLayout = function(displayBar, sourceHealthBar, settings)
    if not displayBar or not sourceHealthBar then
        return
    end

    local width = sourceHealthBar.GetWidth and sourceHealthBar:GetWidth() or 110
    local height = GetConfiguredHealthBarHeight(
        settings,
        sourceHealthBar.GetHeight and sourceHealthBar:GetHeight()
            or DEFAULT_HEALTH_BAR_HEIGHT
    )

    if not width or width <= 0 then
        width = 110
    end

    displayBar:ClearAllPoints()
    displayBar:SetSize(width, height)
    displayBar:SetPoint("TOPLEFT", sourceHealthBar, "TOPLEFT",
        CUSTOM_HEALTH_INSET_X, -CUSTOM_HEALTH_INSET_Y)
end

local function CreateHealthPercentText(healthBar)
    if healthBar.dcHealthPercent then return healthBar.dcHealthPercent end
    
    local text = healthBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
    text:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    text:SetTextColor(1, 1, 1)
    healthBar.dcHealthPercent = text
    
    return text
end

local function CreateCustomHealthBar(frame, sourceHealthBar)
    if frame.dcCustomHealthBar then
        return frame.dcCustomHealthBar
    end

    if not sourceHealthBar then
        return nil
    end

    local displayBar = CreateFrame("StatusBar", nil, frame)
    displayBar.dcManagedByNameplatesPlus = true
    displayBar:SetFrameStrata(GetSafeFrameStrata(frame))
    displayBar:SetFrameLevel(frame:GetFrameLevel() + 4)
    displayBar:SetStatusBarTexture(GetConfiguredBarTexture(addon.settings.nameplatesPlus))
    displayBar:SetMinMaxValues(0, 1)
    displayBar:SetValue(1)

    SyncCustomHealthBarLayout(displayBar, sourceHealthBar,
        addon.settings.nameplatesPlus)
    displayBar:SetStatusBarColor(DEFAULT_HEALTH_COLOR.r, DEFAULT_HEALTH_COLOR.g, DEFAULT_HEALTH_COLOR.b)
    ApplyCustomBarStyle(displayBar, addon.settings.nameplatesPlus, HEALTH_BAR_BACKDROP_COLOR, HEALTH_BAR_BORDER_COLOR)

    displayBar.dcSourceBar = sourceHealthBar
    frame.dcCustomHealthBar = displayBar
    return displayBar
end

local SyncCustomHealthBar
local UpdateHealthPercent

local function CollectNativeStatusBars(frame)
    local statusBars = {}
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.GetStatusBarTexture and not child.dcManagedByNameplatesPlus then
            statusBars[#statusBars + 1] = child
        end
    end

    table.sort(statusBars, function(a, b)
        local aTop = a:GetTop() or 0
        local bTop = b:GetTop() or 0
        if aTop == bTop then
            return (a:GetWidth() or 0) > (b:GetWidth() or 0)
        end
        return aTop > bTop
    end)

    return statusBars
end

local function EnsureSourceHealthHook(frame, sourceHealthBar)
    if not frame or not sourceHealthBar then
        return
    end

    if sourceHealthBar.dcHealthHookedByNameplatesPlus then
        return
    end

    sourceHealthBar.dcHealthHookedByNameplatesPlus = true
    sourceHealthBar:HookScript("OnValueChanged", function()
        local settings = addon.settings.nameplatesPlus
        if not settings.enabled then return end
        SyncCustomHealthBar(frame)
        if frame.dcHealthBar then
            UpdateHealthPercent(frame.dcHealthBar, settings)
        end
    end)
end

local function SuppressFrameOnShow(target)
    if not target or target.dcSuppressionHookedByNameplatesPlus then
        return
    end

    target.dcSuppressionHookedByNameplatesPlus = true
    target:HookScript("OnShow", function(self)
        self:Hide()
        self:SetAlpha(0)
    end)
end

local function SuppressTextureRegions(target)
    if not target or not target.GetRegions then
        return
    end

    for _, region in ipairs({ target:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            region:SetAlpha(0)
            region:Hide()
        end
    end
end

local function SuppressNestedChildren(target)
    if not target or not target.GetChildren then
        return
    end

    for _, child in ipairs({ target:GetChildren() }) do
        if child and not child.dcManagedByNameplatesPlus then
            SuppressTextureRegions(child)
            SuppressNestedChildren(child)
            child:Hide()
            child:SetAlpha(0)
            SuppressFrameOnShow(child)
        end
    end
end

local function MaskSourceHealthBar(sourceBar)
    if not sourceBar then
        return
    end

    sourceBar:SetAlpha(0)
    local texture = sourceBar.GetStatusBarTexture and sourceBar:GetStatusBarTexture() or nil
    if texture then
        texture:SetAlpha(0)
    end

    if sourceBar.bg then
        sourceBar.bg:SetAlpha(0)
    end

    if sourceBar.background then
        sourceBar.background:SetAlpha(0)
    end

    if sourceBar.border then
        sourceBar.border:SetAlpha(0)
    end

    -- Some 3.3.5 plate templates draw the frame/backdrop as texture regions on
    -- the native status bar. Hide them too so no boxed frame leaks behind the
    -- custom bar.
    SuppressTextureRegions(sourceBar)
    SuppressNestedChildren(sourceBar)
end

local function SuppressNativeNameplateChildren(frame, statusBars)
    if not frame then
        return
    end

    if statusBars then
        for _, bar in ipairs(statusBars) do
            if bar == frame.dcSourceHealthBar then
                MaskSourceHealthBar(bar)
                if not bar.dcSuppressionHookedByNameplatesPlus then
                    bar.dcSuppressionHookedByNameplatesPlus = true
                    bar:HookScript("OnShow", function(self)
                        MaskSourceHealthBar(self)
                    end)
                end
            else
                bar:Hide()
                bar:SetAlpha(0)
                SuppressFrameOnShow(bar)
            end

            local parent = bar:GetParent()
            if bar ~= frame.dcSourceHealthBar and parent and parent ~= frame and not parent.dcManagedByNameplatesPlus then
                parent:Hide()
                parent:SetAlpha(0)
                SuppressFrameOnShow(parent)
            end
        end
    end

    -- Some plates expose non-StatusBar child containers that still render the
    -- fallback second bar. Hide every unmanaged child as a final guard.
    for _, child in ipairs({ frame:GetChildren() }) do
        if child ~= frame.dcSourceHealthBar and not child.dcManagedByNameplatesPlus then
            child:Hide()
            child:SetAlpha(0)
            SuppressFrameOnShow(child)
        end
    end
end

local function CollectSuppressibleRegions(regions, keepNameText, keepLevelText)
    local suppressible = {}
    for _, region in ipairs(regions or {}) do
        if region ~= keepNameText and region ~= keepLevelText and not region.dcManagedByNameplatesPlus then
            local objectType = region.GetObjectType and region:GetObjectType() or nil
            if objectType == "Texture" then
                local texture = region.GetTexture and region:GetTexture() or nil
                local classification = InferClassificationFromTexturePath(texture)
                -- Preserve native elite/rare/boss markers so classification cues
                -- are visible even when no unit token is currently resolved.
                if not classification then
                    suppressible[#suppressible + 1] = region
                end
            end
        end
    end
    return suppressible
end

local function SuppressNativeNameplateRegions(frame)
    local regions = frame and frame.dcSuppressedRegions
    if not regions then
        return
    end

    for _, region in ipairs(regions) do
        if region then
            region:Hide()
            region:SetAlpha(0)
        end
    end
end

SyncCustomHealthBar = function(frame)
    if not frame then
        return
    end

    local displayBar = frame.dcCustomHealthBar
    local sourceBar = frame.dcSourceHealthBar
    if not displayBar or not sourceBar or not sourceBar.GetMinMaxValues then
        return
    end

    local minValue, maxValue = sourceBar:GetMinMaxValues()
    local currentValue = sourceBar:GetValue()

    SyncCustomHealthBarLayout(displayBar, sourceBar,
        addon.settings.nameplatesPlus)

    displayBar:SetMinMaxValues(minValue or 0, maxValue or 1)
    displayBar:SetValue(currentValue or 0)

    if sourceBar.GetStatusBarColor and not frame.dcResolvedUnit then
        local r, g, b = sourceBar:GetStatusBarColor()
        if r and g and b then
            displayBar:SetStatusBarColor(r, g, b)
        end
    end

    if displayBar:GetWidth() <= 0 and sourceBar.GetWidth then
        local width = sourceBar:GetWidth() or 110
        if width > 0 then
            displayBar:SetWidth(width)
        end
    end

    if displayBar:GetHeight() <= 0 and sourceBar.GetHeight then
        local height = sourceBar:GetHeight() or 10
        if height > 0 then
            displayBar:SetHeight(height)
        end
    end
end

local function CreateTargetHighlight(frame)
    if frame.dcTargetHighlight then return frame.dcTargetHighlight end
    
    local highlight = CreateFrame("Frame", nil, frame)
    highlight:SetFrameStrata(GetSafeFrameStrata(frame))
    highlight:SetFrameLevel(frame:GetFrameLevel() + 6)

    local border = CreateFullEdgeBorder(highlight)
    border.left:SetDrawLayer("OVERLAY", 7)
    border.right:SetDrawLayer("OVERLAY", 7)
    border.top:SetDrawLayer("OVERLAY", 7)
    border.bottom:SetDrawLayer("OVERLAY", 7)
    highlight.border = border
    highlight:Hide()
    frame.dcTargetHighlight = highlight
    
    return highlight
end

local function CreateMouseoverBorder(frame)
    if frame.dcMouseoverBorder then return frame.dcMouseoverBorder end

    local borderFrame = CreateFrame("Frame", nil, frame)
    borderFrame:SetFrameStrata(GetSafeFrameStrata(frame))
    borderFrame:SetFrameLevel(frame:GetFrameLevel() + 5)

    local border = CreateFullEdgeBorder(borderFrame)
    border.left:SetDrawLayer("OVERLAY", 6)
    border.right:SetDrawLayer("OVERLAY", 6)
    border.top:SetDrawLayer("OVERLAY", 6)
    border.bottom:SetDrawLayer("OVERLAY", 6)
    borderFrame.border = border
    borderFrame:Hide()
    frame.dcMouseoverBorder = borderFrame

    return borderFrame
end

local function CreateTargetArrows(frame, healthBar)
    if frame.dcTargetArrowLeft and frame.dcTargetArrowRight then
        return frame.dcTargetArrowLeft, frame.dcTargetArrowRight
    end

    local left = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    left:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    -- Keep extra left offset so the arrows clear level text.
    left:SetPoint("RIGHT", healthBar, "LEFT", TARGET_ARROW_LEFT_OFFSET, 0)
    left:SetText("<<")
    left:Hide()

    local right = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    right:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    right:SetPoint("LEFT", healthBar, "RIGHT", TARGET_ARROW_RIGHT_OFFSET, 0)
    right:SetText(">>")
    right:Hide()

    frame.dcTargetArrowLeft = left
    frame.dcTargetArrowRight = right
    return left, right
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
    
    local neon = frame:CreateTexture(nil, "ARTWORK")
    neon:SetTexture(FLAT_BAR_TEXTURE)
    neon:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 0, 0)
    neon:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
    neon:SetVertexColor(1, 1, 1, 0.05)
    neon:Hide()
    frame.dcTargetNeon = neon
    return neon
end

local function CreateEliteIcon(frame, healthBar)
    if frame.dcEliteIcon then return frame.dcEliteIcon end
    
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon.dcManagedByNameplatesPlus = true
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", healthBar, "RIGHT", ELITE_ICON_X_OFFSET, ELITE_ICON_Y_OFFSET)
    icon:Hide()
    
    frame.dcEliteIcon = icon
    return icon
end

local function CreateFactionIcon(frame, healthBar)
    if frame.dcFactionIcon then return frame.dcFactionIcon end
    
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon.dcManagedByNameplatesPlus = true
    icon:SetSize(16, 16)
    icon:SetPoint("BOTTOMRIGHT", healthBar, "TOPLEFT", FACTION_ICON_X_OFFSET, FACTION_ICON_Y_OFFSET)
    icon:Hide()
    
    frame.dcFactionIcon = icon
    return icon
end

local function CreateNPCIcons(frame, healthBar)
    if frame.dcNPCIcons then return frame.dcNPCIcons end

    local settings = addon.settings.nameplatesPlus or {}
    local size = settings.npcIconSize or 24
    
    local iconFrame = CreateFrame("Frame", nil, frame)
    iconFrame.dcManagedByNameplatesPlus = true
    iconFrame:SetSize(size, size)
    iconFrame:SetPoint("BOTTOMRIGHT", healthBar, "TOPLEFT", NPC_ICON_X_OFFSET, NPC_ICON_Y_OFFSET)
    
    local icon = iconFrame:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints()
    iconFrame.texture = icon
    
    iconFrame:Hide()
    frame.dcNPCIcons = iconFrame
    return iconFrame
end

local function CreateCastBarOverlay(frame, originalCastBar)
    if frame.dcCastBarOverlay then return frame.dcCastBarOverlay end
    if not frame.dcHealthBar then return nil end

    local overlay = CreateFrame("StatusBar", nil, frame)
    overlay.dcManagedByNameplatesPlus = true
    overlay:SetPoint("TOPLEFT", frame.dcHealthBar, "BOTTOMLEFT", 0, CASTBAR_Y_GAP)
    overlay:SetPoint("TOPRIGHT", frame.dcHealthBar, "BOTTOMRIGHT", 0, CASTBAR_Y_GAP)
    overlay:SetHeight(GetConfiguredCastbarHeight(addon.settings.nameplatesPlus))
    overlay:SetStatusBarTexture(GetConfiguredBarTexture(addon.settings.nameplatesPlus))
    overlay:SetFrameStrata(GetSafeFrameStrata(frame))
    overlay:SetFrameLevel(frame:GetFrameLevel() + 5)
    ApplyCustomBarStyle(overlay, addon.settings.nameplatesPlus, CAST_BAR_BACKDROP_COLOR, CAST_BAR_BORDER_COLOR)

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

    overlay:Hide()
    
    frame.dcCastBarOverlay = overlay
    return overlay
end

local function SetCastBarVisualState(frame, castBar, isActive)
    local overlay = frame and frame.dcCastBarOverlay

    if castBar then
        if castBar.dcOriginalAlpha == nil then
            castBar.dcOriginalAlpha = castBar:GetAlpha() or 1
        end
        UpdateCastBarLayout(frame)
    end

    frame.dcCastBarActive = isActive and true or false

    if overlay then
        if frame.dcCastBarActive then
            overlay:Show()
        else
            overlay:Hide()
        end
    end
end

local function CreateDebuffFrame(frame, healthBar)
    if frame.dcDebuffFrame then return frame.dcDebuffFrame end
    
    local settings = addon.settings.nameplatesPlus
    
    local debuffFrame = CreateFrame("Frame", nil, frame)
    debuffFrame.dcManagedByNameplatesPlus = true
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
    UpdateDebuffFrameAnchor(frame)
    return debuffFrame
end

local function BuildAuraListLookup(list)
    local lookup = {}
    if not list then
        return lookup
    end

    for index, auraName in ipairs(list) do
        if auraName and auraName ~= "" then
            lookup[auraName] = index
        end
    end

    return lookup
end

local function InvalidateAuraFilterCache(settings)
    if settings then
        settings._dcAuraFilterCache = nil
    end
end

local function GetAuraFilterCache(settings)
    local cache = settings and settings._dcAuraFilterCache
    if cache then
        return cache
    end

    local auraFilter = settings and settings.auraFilter or {}
    cache = {
        enabled = auraFilter.enabled,
        minDuration = auraFilter.minDuration or 0,
        maxDuration = auraFilter.maxDuration or 0,
        blacklistLookup = BuildAuraListLookup(auraFilter.blacklist),
        whitelistLookup = BuildAuraListLookup(auraFilter.whitelist),
        priorityLookup = BuildAuraListLookup(auraFilter.priority),
    }
    cache.hasWhitelist = next(cache.whitelistLookup) ~= nil

    if settings then
        settings._dcAuraFilterCache = cache
    end

    return cache
end

-- ============================================================
-- Update Functions
-- ============================================================
local function FormatNumber(currentValue)
    if currentValue >= 100000 then
        -- Round to nearest k: 145000 -> 145k, 144400 -> 144k
        return string.format("%.0fk", math.floor(currentValue / 1000 + 0.5))
    end
    return tostring(currentValue)
end

UpdateHealthPercent = function(healthBar, settings, forceUpdate)
    if not healthBar then
        return
    end

    local text = healthBar.dcHealthPercent or CreateHealthPercentText(healthBar)

    if not settings.showHealthPercent then
        if text then text:Hide() end
        return
    end
    
    if not healthBar.GetMinMaxValues then return end
    
    local sourceBar = healthBar.dcSourceBar
    local valueSource = (sourceBar and sourceBar.GetMinMaxValues) and sourceBar or healthBar
    local min, max = valueSource:GetMinMaxValues()
    local cur = valueSource:GetValue()

    if max <= 0 and forceUpdate then
        local ownerFrame = healthBar:GetParent()
        local unit = ownerFrame and GetPlateUnit(ownerFrame)
        if unit and UnitExists(unit) then
            local fallbackMax = UnitHealthMax(unit)
            if fallbackMax and fallbackMax > 0 then
                max = fallbackMax
                min = 0
                cur = UnitHealth(unit)
            end
        end
    end
    
    -- If max is 0, the unit data isn't available yet - mark for delayed update.
    if max <= 0 then
        healthBar.dcHealthPending = true
        if text and text.dcLastValue and text.dcLastValue ~= "" then
            text:SetText(text.dcLastValue)
            text:Show()
        end
        return
    end
    
    healthBar.dcHealthPending = nil
    
    local percent = (cur / max) * 100
    
    local displayText
    if settings.showHealthRealValues then
        displayText = string.format("%s (%.0f%%)", FormatNumber(cur), percent)
    else
        displayText = string.format(settings.healthPercentFormat, percent)
    end

    if text.dcLastValue ~= displayText then
        text:SetText(displayText)
        text.dcLastValue = displayText
    end
    
    local pos = settings.healthPercentPosition
    if text.dcLastPosition ~= pos then
        text:ClearAllPoints()
        if pos == "LEFT" then
            text:SetPoint("LEFT", healthBar, "LEFT", 2, 0)
        elseif pos == "RIGHT" then
            text:SetPoint("RIGHT", healthBar, "RIGHT", -2, 0)
        else
            text:SetPoint("CENTER", healthBar, "CENTER", 0, 1)
        end
        text.dcLastPosition = pos
    end
    
    text:Show()
end

local function UpdateHealthBarColor(frame, healthBar, unit, settings)
    local r, g, b
    local setColor = false
    
    -- 1. Check Threat Color (highest priority if enabled)
    if settings.showThreat and settings.threatColors and UnitAffectingCombat(unit) and not UnitIsFriend("player", unit) then
        local _, status = UnitDetailedThreatSituation("player", unit)
        if status then
            local mode = settings.tankMode and "tank" or "dps" -- Manual override
            if settings.threatMode == "Auto" then
                mode = GetAutomaticThreatMode()
            end
            
            local colors = (mode == "tank") and THREAT_COLORS.tank or THREAT_COLORS.dps
            local color
            local isTankingActually = (status >= 2)
            
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
                r, g, b = color.r, color.g, color.b
                setColor = true
            end
        end
    end
    
    -- 2. Check Class Color (if no threat color determined)
    if not setColor and settings.classColors then
        local classToken = GetUnitClass(unit)
        if classToken then
            local color = CLASS_COLORS[classToken]
            if color then
                local isEnemy = UnitIsEnemy("player", unit)
                if (isEnemy and settings.enemyClassColors) or (not isEnemy and settings.friendlyClassColors) then
                    r, g, b = color.r, color.g, color.b
                    setColor = true
                end
            end
        end
    end
    
    -- Apply Color (avoid redundant sets to reduce flicker)
    if not setColor then
        if UnitIsFriend("player", unit) then
            r, g, b = FRIENDLY_HEALTH_COLOR.r, FRIENDLY_HEALTH_COLOR.g, FRIENDLY_HEALTH_COLOR.b
        else
            local reaction = UnitReaction(unit, "player")
            if reaction and reaction == 4 then
                r, g, b = NEUTRAL_HEALTH_COLOR.r, NEUTRAL_HEALTH_COLOR.g, NEUTRAL_HEALTH_COLOR.b
            elseif reaction and reaction >= 5 and not UnitCanAttack("player", unit) then
                r, g, b = FRIENDLY_HEALTH_COLOR.r, FRIENDLY_HEALTH_COLOR.g, FRIENDLY_HEALTH_COLOR.b
            else
                r, g, b = DEFAULT_HEALTH_COLOR.r, DEFAULT_HEALTH_COLOR.g, DEFAULT_HEALTH_COLOR.b
            end
        end
        setColor = true
    end

    if setColor and r and g and b then
        if healthBar.dcLastColorR ~= r or healthBar.dcLastColorG ~= g or healthBar.dcLastColorB ~= b then
            healthBar:SetStatusBarColor(r, g, b)
            healthBar.dcLastColorR = r
            healthBar.dcLastColorG = g
            healthBar.dcLastColorB = b
        end
    end

    ApplyCustomBarStyle(healthBar, settings, HEALTH_BAR_BACKDROP_COLOR, HEALTH_BAR_BORDER_COLOR)
end

local function HideThreatIndicators(frame)
    if not frame then
        return
    end

    local healthBar = frame.dcHealthBar
    if frame.dcThreatGlow then
        frame.dcThreatGlow:Hide()
    end
    if healthBar and healthBar.dcThreatDiff then
        healthBar.dcThreatDiff:Hide()
    end
    if healthBar and healthBar.dcThreatPct then
        healthBar.dcThreatPct:Hide()
    end
end

local function UpdateThreat(frame, unit, settings)
    if not settings.showThreat then
        HideThreatIndicators(frame)
        return
    end
    
    if not unit or not UnitExists(unit) then
        HideThreatIndicators(frame)
        return
    end
    if UnitIsFriend("player", unit) then
        HideThreatIndicators(frame)
        return
    end
    if not UnitAffectingCombat(unit) then
        HideThreatIndicators(frame)
        return
    end
    
    local _, status = UnitDetailedThreatSituation("player", unit)
    local glow = frame.dcThreatGlow
    local healthBar = frame.dcHealthBar
    
    if not glow then
        glow = CreateThreatGlow(frame, healthBar)
    end
    
    if not status then
        HideThreatIndicators(frame)
        return
    end
    
    -- Determine Color for GLOW only (Bar color is handled in UpdateHealthBarColor)
    local mode = settings.tankMode and "tank" or "dps"
    if settings.threatMode == "Auto" then
        mode = GetAutomaticThreatMode()
    end
    
    local colors = (mode == "tank") and THREAT_COLORS.tank or THREAT_COLORS.dps
    local color
    local isTankingActually = (status >= 2)
    
    if mode == "tank" then
        if isTankingActually then color = colors.safe
        elseif status == 1 then color = colors.warning
        else color = colors.danger end
    else
        if isTankingActually then color = colors.danger
        elseif status == 1 then color = colors.warning
        else color = colors.safe end
    end
    
    if color then
        glow:SetVertexColor(color.r, color.g, color.b, 0.6)
        glow:Show()
        
        -- Advanced Threat Values
        if settings.showThreatValues then
            local _, _, _, rawPercent, threatValue = UnitDetailedThreatSituation("player", unit)
            if threatValue then
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
                     healthBar.dcThreatDiff:SetText(FormatNumber(threatValue))
                     healthBar.dcThreatDiff:SetTextColor(color.r, color.g, color.b)
                     healthBar.dcThreatDiff:Show()
                end
            else
                if healthBar.dcThreatPct then
                    healthBar.dcThreatPct:Hide()
                end
                if healthBar.dcThreatDiff then
                    healthBar.dcThreatDiff:Hide()
                end
            end
        else
            if healthBar.dcThreatPct then
                healthBar.dcThreatPct:Hide()
            end
            if healthBar.dcThreatDiff then
                healthBar.dcThreatDiff:Hide()
            end
        end
    end
end

local function HideUnitDependentPlateVisuals(frame)
    if not frame then
        return
    end

    HideThreatIndicators(frame)
    HideTargetIndicators(frame)
    RestoreMouseoverNameText(frame)

    if frame.dcCastBarOverlay then
        frame.dcCastBarOverlay.shield:Hide()
        frame.dcCastBarOverlay:Hide()
    end
    SetCastBarVisualState(frame, frame.dcCastBar, false)

    if frame.dcDebuffFrame and frame.dcDebuffFrame:IsShown() then
        frame.dcDebuffFrame:Hide()
    end
    frame.dcNextDebuffRefresh = nil

    if frame.dcEliteIcon then
        frame.dcEliteIcon:Hide()
    end
    if frame.dcFactionIcon then
        frame.dcFactionIcon:Hide()
    end
    if frame.dcNPCIcons then
        frame.dcNPCIcons:Hide()
    end
end
    
local function UpdateEliteIcon(frame, unit, settings)
    if not settings.eliteIcons then
        if frame.dcEliteIcon then frame.dcEliteIcon:Hide() end
        return
    end

    local icon = frame.dcEliteIcon or CreateEliteIcon(frame, frame.dcHealthBar)
    local classification = nil

    if unit and UnitExists(unit) then
        -- Don't show elite icon on players.
        if UnitIsPlayer(unit) then
            frame.dcLastClassification = nil
            frame.dcLastClassificationSignature = nil
            icon:Hide()
            return
        end

        classification = UnitClassification(unit)
        if classification and classification ~= "" then
            frame.dcLastClassification = classification
            frame.dcLastClassificationSignature = GetPlateDisplaySignature(frame)
        end
    else
        classification = InferClassificationFromPlate(frame)

        if not classification then
            classification = InferClassificationFromSuppressedRegions(frame)
        end

        if not classification then
            local signature = GetPlateDisplaySignature(frame)
            if frame.dcLastClassification and frame.dcLastClassificationSignature == signature then
                classification = frame.dcLastClassification
            end
        end
    end

    if not classification or classification == "" then
        icon:Hide()
        return
    end

    local notPlaterTexture = GetNotPlaterEliteIconTexture()
    local canUseNotPlaterTexture = NotPlater and notPlaterTexture
    
    if classification == "worldboss" or classification == "elite" then
        if canUseNotPlaterTexture then
            icon:SetTexture(notPlaterTexture)
            icon:SetTexCoord(
                NOTPLATER_ELITE_ICON_TCOORDS[1],
                NOTPLATER_ELITE_ICON_TCOORDS[2],
                NOTPLATER_ELITE_ICON_TCOORDS[3],
                NOTPLATER_ELITE_ICON_TCOORDS[4]
            )
            icon:SetVertexColor(1, 0.8, 0, 1)
            icon:SetDesaturated(false)
        else
            icon:SetTexture(ELITE_TEXTURE)
            icon:SetTexCoord(0, 1, 0, 1)
            icon:SetVertexColor(1, 1, 1, 1)
            icon:SetDesaturated(false)
        end
        icon:Show()
    elseif classification == "rare" or classification == "rareelite" then
        if canUseNotPlaterTexture then
            icon:SetTexture(notPlaterTexture)
            icon:SetTexCoord(
                NOTPLATER_ELITE_ICON_TCOORDS[1],
                NOTPLATER_ELITE_ICON_TCOORDS[2],
                NOTPLATER_ELITE_ICON_TCOORDS[3],
                NOTPLATER_ELITE_ICON_TCOORDS[4]
            )
            icon:SetVertexColor(1, 1, 1, 1)
            icon:SetDesaturated(true)
        elseif classification == "rareelite" then
            icon:SetTexture(RARE_ELITE_TEXTURE)
            icon:SetTexCoord(0, 1, 0, 1)
            icon:SetVertexColor(1, 1, 1, 1)
            icon:SetDesaturated(false)
        else
            icon:SetTexture(RARE_TEXTURE)
            icon:SetTexCoord(0, 1, 0, 1)
            icon:SetVertexColor(1, 1, 1, 1)
            icon:SetDesaturated(false)
        end
        icon:Show()
    else
        icon:SetTexCoord(0, 1, 0, 1)
        icon:SetVertexColor(1, 1, 1, 1)
        icon:SetDesaturated(false)
        icon:Hide()
    end
end

local function UpdateFactionIcon(frame, unit, settings)
    if not settings.factionIcons then
        if frame.dcFactionIcon then frame.dcFactionIcon:Hide() end
        return
    end
    
    if not unit or not UnitExists(unit) then
        if frame.dcFactionIcon then frame.dcFactionIcon:Hide() end
        return
    end
    
    -- Only show faction icons on players
    if not UnitIsPlayer(unit) then
        if frame.dcFactionIcon then frame.dcFactionIcon:Hide() end
        return
    end
    
    local faction = UnitFactionGroup(unit)
    local icon = frame.dcFactionIcon or CreateFactionIcon(frame, frame.dcHealthBar)
    
    if faction == "Alliance" then
        icon:SetTexture(FACTION_ALLIANCE)
        icon:SetTexCoord(0, 1, 0, 1)
        icon:Show()
    elseif faction == "Horde" then
        icon:SetTexture(FACTION_HORDE)
        icon:SetTexCoord(0, 1, 0, 1)
        icon:Show()
    else
        icon:Hide()
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
    local size = settings.npcIconSize or 24
    if iconFrame.dcLastSize ~= size then
        iconFrame:SetSize(size, size)
        iconFrame.dcLastSize = size
    end
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
        SetCastBarVisualState(frame, castBar, false)
        if frame.dcCastBarOverlay then frame.dcCastBarOverlay:Hide() end
        UpdateDebuffFrameAnchor(frame)
        return
    end
    
    local overlay = frame.dcCastBarOverlay or CreateCastBarOverlay(frame, castBar)
    if not overlay then
        SetCastBarVisualState(frame, castBar, false)
        UpdateDebuffFrameAnchor(frame)
        return
    end

    local tunedCastBarHeight = GetConfiguredCastbarHeight(settings)
    if overlay.dcLastHeight ~= tunedCastBarHeight then
        overlay:SetHeight(tunedCastBarHeight)
        overlay.dcLastHeight = tunedCastBarHeight
    end

    ApplyCustomBarStyle(overlay, settings, CAST_BAR_BACKDROP_COLOR, CAST_BAR_BORDER_COLOR)
    
    -- Get casting info
    local spellName, _, _, _, startTime, endTime, _, castID, notInterruptible
    local spellTexture
    local isChannel = false
    
    if unit and UnitExists(unit) then
        spellName, _, _, spellTexture, startTime, endTime, _, castID, notInterruptible = UnitCastingInfo(unit)
        if not spellName then
            spellName, _, _, spellTexture, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
            isChannel = spellName and true or false
        end
    end
    
    if spellName then
        SetCastBarVisualState(frame, castBar, true)

        local duration = (endTime and startTime) and ((endTime - startTime) / 1000) or 0
        local currentValue = 0
        if duration > 0 then
            if isChannel then
                currentValue = math.max(0, (endTime / 1000) - GetTime())
            else
                currentValue = math.max(0, math.min(duration, GetTime() - (startTime / 1000)))
            end
            overlay:SetMinMaxValues(0, duration)
            overlay:SetValue(currentValue)
        else
            overlay:SetMinMaxValues(0, 1)
            overlay:SetValue(0)
        end

        if settings.showCastSpellName then
            overlay.spellName:SetText(spellName)
            overlay.spellName:Show()
        else
            overlay.spellName:Hide()
        end
        
        if settings.showCastTime and startTime and endTime then
            local displayTime = isChannel and currentValue or ((endTime - GetTime() * 1000) / 1000)
            if displayTime > 0 then
                overlay.castTime:SetFormattedText("%.1f", displayTime)
                overlay.castTime:Show()
            else
                overlay.castTime:Hide()
            end
        else
            overlay.castTime:Hide()
        end
        
        -- Color based on interruptibility
        if notInterruptible then
            overlay:SetStatusBarColor(settings.castBarInterruptColor.r, settings.castBarInterruptColor.g, settings.castBarInterruptColor.b)
            overlay.shield:Show()
        else
            overlay:SetStatusBarColor(settings.castBarColor.r, settings.castBarColor.g, settings.castBarColor.b)
            overlay.shield:Hide()
        end
        
        overlay:Show()
    else
        SetCastBarVisualState(frame, castBar, false)
        overlay.shield:Hide()
        overlay:Hide()
    end

    UpdateDebuffFrameAnchor(frame)
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
    
    -- AURA CACHING OPTIMIZATION: Check cache first to reduce UnitDebuff calls
    local guid = UnitGUID(unit)
    local currentTime = GetTime()
    local cachedData = guid and auraCache[guid]
    
    if cachedData and (currentTime - cachedData.timestamp) < AURA_CACHE_DURATION then
        -- Use cached aura data
        local auras = cachedData.auras
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
        
        -- Hide unused icons
        for i = debuffIndex, settings.maxDebuffs do
            if debuffFrame.icons[i] then
                debuffFrame.icons[i]:Hide()
            end
        end
        
        debuffFrame:Show()
        return
    end
    
    -- Cache miss or expired - scan auras
    local filterCache = GetAuraFilterCache(settings)
    local filterEnabled = filterCache.enabled
    
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
        if filterCache.blacklistLookup[auraName] then
            return false, 0
        end
        
        -- Check whitelist (if not empty, only show whitelisted)
        if filterCache.hasWhitelist and not filterCache.whitelistLookup[auraName] then
            return false, 0
        end

        -- Check duration filters
        if filterCache.minDuration > 0 then
            if duration and duration < filterCache.minDuration then
                return false, 0
            end
        end
        
        if filterCache.maxDuration > 0 then
            if duration and duration > filterCache.maxDuration then
                return false, 0
            end
        end
        
        -- ENHANCED PRIORITY SYSTEM: CC effects get highest priority
        local priority = 0
        
        -- Check user-defined priority list first
        local priorityIndex = filterCache.priorityLookup[auraName]
        if priorityIndex then
            priority = 1000 - priorityIndex  -- User priority gets very high value
        end
        
        -- If not in user priority, check CC/important debuff types
        if priority == 0 then
            -- Stuns, Fears, Polymorphs = highest priority
            if auraName:match("Stun") or auraName:match("Fear") or auraName:match("Polymorph") or
               auraName:match("Cyclone") or auraName:match("Hex") or auraName:match("Sap") or
               auraName:match("Blind") or auraName:match("Banish") or auraName:match("Shackle") then
                priority = 500
            -- Roots, Slows = medium priority
            elseif auraName:match("Root") or auraName:match("Freeze") or auraName:match("Slow") then
                priority = 300
            -- Silences, Interrupts = medium-high priority
            elseif auraName:match("Silence") or auraName:match("Interrupt") then
                priority = 400
            -- DoTs = low priority
            elseif duration and duration > 10 then
                priority = 100
            else
                priority = 50
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
    
    -- AURA CACHING: Store sorted results for performance
    if guid then
        auraCache[guid] = {
            auras = auras,
            timestamp = currentTime
        }
    end
    
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
    
    -- Hide unused icons
    for i = debuffIndex, settings.maxDebuffs do
        if debuffFrame.icons[i] then
            debuffFrame.icons[i]:Hide()
        end
    end
    
    debuffFrame:Show()
end

local function UpdateTargetHighlight(frame, unit, settings)
    local isPlater = IsPlaterActive()
    local isTarget = false
    local isMouseover = IsPlateMouseOver(frame)
    local c = settings.targetHighlightColor

    if unit and UnitExists(unit) and UnitExists("target") and type(UnitIsUnit) == "function" then
        isTarget = UnitIsUnit(unit, "target") and true or false
    else
        isTarget = IsPlateTarget(frame)
    end

    if not isPlater then
        local targetScale = settings.targetScale or 1.0
        if targetScale < 0.5 then
            targetScale = 0.5
        end

        local desiredScale = isTarget and targetScale or 1.0
        if frame.dcLastScale ~= desiredScale then
            frame:SetScale(desiredScale)
            frame.dcLastScale = desiredScale
        end
    end

    if settings.targetArrows and frame.dcHealthBar then
        local leftArrow, rightArrow = CreateTargetArrows(frame, frame.dcHealthBar)
        leftArrow:ClearAllPoints()
        leftArrow:SetPoint("RIGHT", frame.dcHealthBar, "LEFT", TARGET_ARROW_LEFT_OFFSET, 0)
        rightArrow:ClearAllPoints()
        rightArrow:SetPoint("LEFT", frame.dcHealthBar, "RIGHT", TARGET_ARROW_RIGHT_OFFSET, 0)
        if isTarget then
            leftArrow:SetTextColor(c.r, c.g, c.b, c.a * 0.7)
            rightArrow:SetTextColor(c.r, c.g, c.b, c.a * 0.7)
            leftArrow:Show()
            rightArrow:Show()
        else
            leftArrow:Hide()
            rightArrow:Hide()
        end
    else
        if frame.dcTargetArrowLeft then frame.dcTargetArrowLeft:Hide() end
        if frame.dcTargetArrowRight then frame.dcTargetArrowRight:Hide() end
    end

    if not settings.targetHighlight then
        if frame.dcTargetHighlight then frame.dcTargetHighlight:Hide() end
        if frame.dcTargetNeon then frame.dcTargetNeon:Hide() end
        frame.dcIsTarget = isTarget and true or false
    else
        local highlight = frame.dcTargetHighlight or CreateTargetHighlight(frame)
    
        -- Neon Glow
        if settings.targetNeon then
            local neon = frame.dcTargetNeon or CreateTargetNeon(frame, frame.dcHealthBar)
            if isTarget then
                neon:SetVertexColor(1, 1, 1, 0.05)
                neon:Show()
            else
                neon:Hide()
            end
        else
            if frame.dcTargetNeon then frame.dcTargetNeon:Hide() end
        end

        if isTarget and frame.dcHealthBar then
            highlight:ClearAllPoints()
            highlight:SetPoint("TOPLEFT", frame.dcHealthBar, "TOPLEFT", -TARGET_BORDER_PADDING, TARGET_BORDER_PADDING)
            highlight:SetPoint("BOTTOMRIGHT", frame.dcHealthBar, "BOTTOMRIGHT", TARGET_BORDER_PADDING, -TARGET_BORDER_PADDING)
            ConfigureFullEdgeBorder(highlight, 1, c.r, c.g, c.b,
                math.min(c.a * TARGET_BORDER_ALPHA_MULTIPLIER, 1))
            highlight:Show()
        else
            highlight:Hide()
        end
        frame.dcIsTarget = isTarget and true or false
    end

    local mouseoverBorder = frame.dcMouseoverBorder or CreateMouseoverBorder(frame)
    if isMouseover and not isTarget and frame.dcHealthBar then
        mouseoverBorder:ClearAllPoints()
        mouseoverBorder:SetPoint("TOPLEFT", frame.dcHealthBar, "TOPLEFT", -MOUSEOVER_BORDER_PADDING, MOUSEOVER_BORDER_PADDING)
        mouseoverBorder:SetPoint("BOTTOMRIGHT", frame.dcHealthBar, "BOTTOMRIGHT", MOUSEOVER_BORDER_PADDING, -MOUSEOVER_BORDER_PADDING)
        ConfigureFullEdgeBorder(
            mouseoverBorder,
            1,
            MOUSEOVER_BORDER_COLOR.r,
            MOUSEOVER_BORDER_COLOR.g,
            MOUSEOVER_BORDER_COLOR.b,
            MOUSEOVER_BORDER_COLOR.a
        )
        mouseoverBorder:Show()
    else
        mouseoverBorder:Hide()
    end
    
    -- Alpha handling
    if not isPlater then
        local desiredAlpha = 1.0
        if settings.nonTargetAlpha and settings.nonTargetAlpha < 1.0 and UnitExists("target") and not isTarget then
            desiredAlpha = settings.nonTargetAlpha
        end

        if settings.fadeOutOfRange and unit and not isTarget then
            local rangeFadeDistance = settings.rangeFadeDistance or 30
            if rangeFadeDistance < 5 then
                rangeFadeDistance = 5
            end

            local estimatedRange = frame.dcEstimatedRange
            if estimatedRange and estimatedRange > rangeFadeDistance then
                local fadeAlpha = settings.outOfRangeAlpha or 0.5
                if fadeAlpha < 0.1 then fadeAlpha = 0.1 end
                if fadeAlpha > 1.0 then fadeAlpha = 1.0 end
                if fadeAlpha < desiredAlpha then
                    desiredAlpha = fadeAlpha
                end
            end
        end

        if frame.dcLastAlpha ~= desiredAlpha then
            frame:SetAlpha(desiredAlpha)
            frame.dcLastAlpha = desiredAlpha
        end
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
    -- Collect native (Blizzard) statusbars only.
    local statusBars = CollectNativeStatusBars(frame)
    local sourceHealthBar = statusBars[1]
    local castBar = (#statusBars >= 2) and statusBars[#statusBars] or nil
    if castBar == sourceHealthBar then castBar = nil end

    local healthBar = CreateCustomHealthBar(frame, sourceHealthBar)
    if healthBar then
        SyncCustomHealthBar(frame)
        ApplyCustomBarStyle(healthBar, settings, HEALTH_BAR_BACKDROP_COLOR, HEALTH_BAR_BORDER_COLOR)
    end
    
    local nameText = nil
    local levelText = nil
    for i, region in ipairs(regions) do
        if region:GetObjectType() == "FontString" then
            if not nameText then
                nameText = region
            elseif not levelText then
                levelText = region
                break
            end
        end
    end
    
    frame.dcSourceHealthBar = sourceHealthBar
    frame.dcHealthBar  = healthBar
    frame.dcStatusBars = statusBars  -- all bars; [1]=health
    frame.dcCastBar    = castBar
    frame.dcNameText   = nameText
    frame.dcLevelText  = levelText
    frame.dcSuppressedRegions = CollectSuppressibleRegions(regions, nameText, levelText)

    NormalizeNameplateLayout(frame)
    
    -- Create enhancements
    if healthBar then
        CreateHealthPercentText(healthBar)
        CreateThreatGlow(frame, healthBar)
    end
    
    CreateTargetHighlight(frame)

    SuppressNativeNameplateChildren(frame, statusBars)
    SuppressNativeNameplateRegions(frame)

    if castBar then
        SetCastBarVisualState(frame, castBar, false)
        CreateCastBarOverlay(frame, castBar)
    end
    
    if healthBar then
        CreateDebuffFrame(frame, healthBar)
    end
    
    if healthBar then
        CreateEliteIcon(frame, healthBar)
        CreateFactionIcon(frame, healthBar)
        CreateNPCIcons(frame, healthBar)
    end
    
    -- Hook health bar updates
    EnsureSourceHealthHook(frame, sourceHealthBar)
    
    -- Hook frame show
    frame:HookScript("OnShow", function(self)
        local settings = addon.settings.nameplatesPlus
        if not settings.enabled then return end

        -- Re-resolve bars on every show because recycled nameplate internals can
        -- shift around after hooks were first attached.
        local refreshedBars = CollectNativeStatusBars(self)
        if #refreshedBars > 0 then
            self.dcStatusBars = refreshedBars
            self.dcSourceHealthBar = refreshedBars[1]
            self.dcHealthBar = CreateCustomHealthBar(self, self.dcSourceHealthBar)
            SyncCustomHealthBar(self)
            ApplyCustomBarStyle(self.dcHealthBar, settings, HEALTH_BAR_BACKDROP_COLOR, HEALTH_BAR_BORDER_COLOR)
            EnsureSourceHealthHook(self, self.dcSourceHealthBar)
            local refreshedCast = (#refreshedBars >= 2) and refreshedBars[#refreshedBars] or nil
            if refreshedCast == self.dcSourceHealthBar then refreshedCast = nil end
            self.dcCastBar = refreshedCast

            SuppressNativeNameplateChildren(self, refreshedBars)
        end

        self.dcSuppressedRegions = CollectSuppressibleRegions({ self:GetRegions() }, self.dcNameText, self.dcLevelText)
        SuppressNativeNameplateRegions(self)
        
        -- Reset scale to 1.0 to ensure cleanliness (skip if Plater is active)
        if not IsPlaterActive() then
            if self:GetScale() ~= 1.0 then
                self:SetScale(1.0)
            end
        end

        NormalizeNameplateLayout(self)
        SyncCustomHealthBar(self)
        
        if self.dcHealthBar then
            -- forceUpdate=true bypasses the max<=0 early-return so health
            -- text retries are triggered immediately on every plate show.
            UpdateHealthPercent(self.dcHealthBar, settings, true)
        end
    end)
end

-- ============================================================
-- WorldFrame Scanner
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

        RefreshAllTrackedUnitMatches()
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
        local currentTime = GetTime()
        
        for frame, _ in pairs(hookedPlates) do
            if frame:IsShown() then
                SyncCustomHealthBar(frame)
                SuppressNativeNameplateRegions(frame)
                local unit = GetPlateUnit(frame)
                if frame.dcResolvedUnit ~= unit then
                    frame.dcResolvedUnit = unit
                    frame.dcDebuffDirty = true
                    frame.dcNextDebuffRefresh = 0
                end

                if unit and (frame.dcRangeDirty or currentTime >= (frame.dcNextRangeRefresh or 0)) then
                    frame.dcEstimatedRange = GetEstimatedRange(unit)
                    frame.dcRangeDirty = nil
                    frame.dcNextRangeRefresh = currentTime + RANGE_REFRESH_INTERVAL
                elseif not unit then
                    frame.dcEstimatedRange = nil
                    frame.dcNextRangeRefresh = nil
                end
                
                -- Refresh health text every frame so freshly shown plates do
                -- not wait for hover or click before drawing their values.
                local healthBar = frame.dcHealthBar
                if healthBar then
                    UpdateHealthPercent(healthBar, settings, true)
                end
                
                -- MOUSEOVER NAMETEXT HIGHLIGHT FIX: Brighten nametext on mouseover
                if frame.dcNameText then
                    local isMouseOver = frame:IsMouseOver()
                    if isMouseOver and not frame.dcNameTextOriginalColor then
                        local r, g, b, a = frame.dcNameText:GetTextColor()
                        frame.dcNameTextOriginalColor = {r, g, b, a}
                        frame.dcNameText:SetTextColor(1, 1, 0.6, 1)  -- Bright yellow on hover
                    elseif not isMouseOver and frame.dcNameTextOriginalColor then
                        frame.dcNameText:SetTextColor(unpack(frame.dcNameTextOriginalColor))
                        frame.dcNameTextOriginalColor = nil
                    end
                end

                if unit then
                    -- Only run unit-dependent updates (including target highlight) when we
                    -- have a resolved unit. Without a unit, name-based IsPlateTarget would
                    -- falsely light up every same-name mob as target on every 50ms tick.
                    UpdateTargetHighlight(frame, unit, settings)
                    UpdateHealthBarColor(frame, frame.dcHealthBar, unit, settings)
                    UpdateThreat(frame, unit, settings)
                    UpdateCastBar(frame, frame.dcCastBar, unit, settings)
                    if frame.dcDebuffDirty or currentTime >= (frame.dcNextDebuffRefresh or 0) then
                        UpdateDebuffs(frame, unit, settings)
                        frame.dcDebuffDirty = nil
                        frame.dcNextDebuffRefresh = currentTime + DEBUFF_REFRESH_INTERVAL
                    end
                    UpdateEliteIcon(frame, unit, settings)
                    UpdateFactionIcon(frame, unit, settings)
                    UpdateNPCIcons(frame, unit, settings)
                else
                    HideUnitDependentPlateVisuals(frame)
                    UpdateEliteIcon(frame, nil, settings)
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
    MigrateNameplateStyleSettings(addon.settings.nameplatesPlus)
    -- NIL-SAFETY FIX: Prevent errors if UnitGUID returns nil early
    if UnitGUID("player") then
        playerGUID = UnitGUID("player")
    end
    
    -- Force nameplate scale CVar to 1 to prevent "jumping"
    if SafeGetCVar("nameplateSelectedScale") ~= nil then
        SafeSetCVar("nameplateSelectedScale", "1")
    end

    ApplyNameplateCVars(addon.settings.nameplatesPlus)
end

function NameplatesPlus.OnEnable()
    addon:Debug("NameplatesPlus module enabling")
    
    local settings = addon.settings.nameplatesPlus
    MigrateNameplateStyleSettings(settings)
    if not settings.enabled then return end

    ApplyNameplateCVars(settings)
    
    if NotPlater then
        addon:Print("Notice: NotPlater detected. Some features may conflict.", true)
    end
    
    if not updateFrame then
        updateFrame = CreateFrame("Frame", "DCQoS_NameplatesFrame", UIParent)
        updateFrame:SetScript("OnUpdate", OnUpdate)
        
        -- GROUP MEMBER GUID TRACKING: Register for roster and tracked-unit updates
        updateFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
        updateFrame:RegisterEvent("RAID_ROSTER_UPDATE")
        updateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        updateFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        updateFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        updateFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
        updateFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        updateFrame:RegisterEvent("UNIT_TARGET")
        updateFrame:RegisterEvent("UNIT_AURA")
        updateFrame:SetScript("OnEvent", function(self, event, arg1)
            if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
                ApplyNameplateCVars(settings)
                UpdateGroupGUIDs()
                RefreshAllTrackedUnitMatches()
                MarkAllFramesDirty()
            elseif event == "PLAYER_TARGET_CHANGED" then
                InvalidateAuraCacheForUnit("target")
                RefreshTrackedUnitMatch("target")
                MarkAllFramesDirty()
            elseif event == "PLAYER_FOCUS_CHANGED" then
                InvalidateAuraCacheForUnit("focus")
                RefreshTrackedUnitMatch("focus")
                MarkAllFramesDirty()
            elseif event == "UPDATE_MOUSEOVER_UNIT" then
                InvalidateAuraCacheForUnit("mouseover")
                RefreshTrackedUnitMatch("mouseover")
                MarkAllFramesDirty()
            elseif event == "UNIT_TARGET" then
                local unit = arg1
                if unit and (unit:match("^party%d+$") or unit:match("^raid%d+$")) then
                    InvalidateAuraCacheForUnit(unit .. "target")
                    RefreshGroupTargetMatch(unit .. "target")
                    MarkAllFramesDirty()
                end
            elseif event == "UNIT_AURA" then
                local unit = arg1
                if unit then
                    InvalidateAuraCacheForUnit(unit)
                    MarkMatchedUnitDebuffsDirty(unit)
                end
            end
        end)
    end
    updateFrame:Show()
    
    -- Initial group GUID cache
    UpdateGroupGUIDs()
    
    ScanWorldFrame()
    RefreshAllTrackedUnitMatches()
    
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
                InvalidateAuraFilterCache(settings)
                addon:Print("Added to blacklist: " .. auraName, true)
            end
        elseif msg:match("^whitelist ") then
            local auraName = msg:match("^whitelist (.+)")
            if auraName then
                local filter = settings.auraFilter or {}
                filter.whitelist = filter.whitelist or {}
                table.insert(filter.whitelist, auraName)
                InvalidateAuraFilterCache(settings)
                addon:Print("Added to whitelist: " .. auraName, true)
            end
        elseif msg == "debug" then
            -- Full tree dump for every visible nameplate.
            local wfChildren = { WorldFrame:GetChildren() }
            local found = 0
            for _, child in ipairs(wfChildren) do
                if child:IsShown() then
                    local cfList = { child:GetChildren() }
                    local isPlate = false
                    for _, cf in ipairs(cfList) do
                        if cf.GetStatusBarTexture then isPlate = true; break end
                    end
                    if isPlate then
                        found = found + 1
                        local hooked = hookedPlates[child] and "HOOKED" or "unhooked"
                        print(string.format("|cffffff00[NPD] plate#%d %s children=%d|r", found, hooked, #cfList))
                        for ci, cf in ipairs(cfList) do
                            local sb = cf.GetStatusBarTexture and "SB" or "  "
                            local sh = cf:IsShown() and "SHOWN" or "hidn"
                            local a  = string.format("%.2f", cf:GetAlpha() or 0)
                            local tp = string.format("%.0f", cf:GetTop() or 0)
                            local bt = string.format("%.0f", cf:GetBottom() or 0)
                            print(string.format("|cffffff00  [%d] %s %s %s a=%s top=%s bot=%s|r", ci, cf:GetObjectType() or "?", sb, sh, a, tp, bt))
                            for _, gcf in ipairs({ cf:GetChildren() }) do
                                local gsb = gcf.GetStatusBarTexture and "SB" or "  "
                                local gsh = gcf:IsShown() and "SH" or "hd"
                                print(string.format("|cffaaaaaa    sub: %s %s %s|r", gcf:GetObjectType() or "?", gsb, gsh))
                            end
                        end
                    end
                end
            end
            if found == 0 then print("|cffff4444[NPD] No visible nameplates|r") end
            local n=0; for _ in pairs(hookedPlates) do n=n+1 end
            print("|cffffff00[NPD] hooked: " .. n .. "|r")
        elseif msg == "help" then
            addon:Print("NameplatesPlus Commands:", true)
            print("  |cffffd700/dcnp tank|r - Tank threat mode")
            print("  |cffffd700/dcnp dps|r - DPS/Healer threat mode")
            print("  |cffffd700/dcnp blacklist <aura>|r - Hide aura")
            print("  |cffffd700/dcnp whitelist <aura>|r - Priority aura")
            print("  |cffffd700/dcnp debug|r - Dump nameplate frame structure")
        else
            addon:Print("Usage: /dcnp help", true)
        end
    end
end

function NameplatesPlus.OnDisable()
    addon:Debug("NameplatesPlus module disabling")

    UpdateDefaultNameplateCastBarCVar(nil)
    
    -- Clear aura cache
    for k in pairs(auraCache) do
        auraCache[k] = nil
    end

    for k in pairs(unitMatchToFrame) do
        unitMatchToFrame[k] = nil
    end

    for k in pairs(guidMatchToFrame) do
        guidMatchToFrame[k] = nil
    end
    
    if updateFrame then
        updateFrame:Hide()
    end
    
    for frame, _ in pairs(hookedPlates) do
        HideTargetIndicators(frame)
        RestoreMouseoverNameText(frame)
        if frame.dcCustomHealthBar then
            frame.dcCustomHealthBar:Hide()
        end

        if frame.dcStatusBars then
            for _, bar in ipairs(frame.dcStatusBars) do
                bar:SetAlpha(1)
                if not bar:IsShown() then
                    bar:Show()
                end
            end
        end

        for _, child in ipairs({ frame:GetChildren() }) do
            child:SetAlpha(1)
            if not child:IsShown() then
                child:Show()
            end
        end

        if frame.dcSuppressedRegions then
            for _, region in ipairs(frame.dcSuppressedRegions) do
                if region then
                    region:SetAlpha(1)
                    region:Show()
                end
            end
        end

        if frame.dcThreatGlow then frame.dcThreatGlow:Hide() end
        if frame.dcCastBarOverlay then frame.dcCastBarOverlay:Hide() end
        if frame.dcDebuffFrame then frame.dcDebuffFrame:Hide() end
        if frame.dcEliteIcon then frame.dcEliteIcon:Hide() end
        if frame.dcFactionIcon then frame.dcFactionIcon:Hide() end
        if frame.dcNPCIcons then frame.dcNPCIcons:Hide() end
        if frame.dcHealthBar and frame.dcHealthBar.dcHealthPercent then
            frame.dcHealthBar.dcHealthPercent:Hide()
        end
        frame.lastUnitMatch = nil
        frame.lastGuidMatch = nil
        frame.dcResolvedUnit = nil
        frame.dcDebuffDirty = nil
        frame.dcNextDebuffRefresh = nil
        frame.dcRangeDirty = nil
        frame.dcEstimatedRange = nil
        frame.dcNextRangeRefresh = nil
        frame.dcCastBarActive = nil
        if frame.dcCastBar and frame.dcCastBar.dcOriginalAlpha ~= nil then
            frame.dcCastBar:SetAlpha(frame.dcCastBar.dcOriginalAlpha)
        end
        if frame.dcCastBar and not frame.dcCastBar:IsShown() then
            frame.dcCastBar:Show()
        end
        frame.dcLastScale = nil
        RestoreNameplateLayout(frame)
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
    yOffset = yOffset - 25

    local targetArrowsCb = addon:CreateCheckbox(parent)
    targetArrowsCb:SetPoint("TOPLEFT", 36, yOffset)
    targetArrowsCb.Text:SetText("Show target arrows")
    targetArrowsCb:SetChecked(settings.targetArrows)
    targetArrowsCb:SetScript("OnClick", function(self)
        addon:SetSetting("nameplatesPlus.targetArrows", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local targetScaleSlider = addon:CreateSlider(parent)
    targetScaleSlider:SetPoint("TOPLEFT", 36, yOffset)
    targetScaleSlider:SetMinMaxValues(1.0, 1.5)
    targetScaleSlider:SetValueStep(0.05)
    targetScaleSlider:SetValue(settings.targetScale or 1.0)
    targetScaleSlider.Text:SetText(string.format("Target scale: %.2fx", settings.targetScale or 1.0))
    targetScaleSlider:SetScript("OnValueChanged", function(self, value)
        local stepped = math.floor(value * 20 + 0.5) / 20
        self.Text:SetText(string.format("Target scale: %.2fx", stepped))
        addon:SetSetting("nameplatesPlus.targetScale", stepped)
    end)
    yOffset = yOffset - 50

    local rangeFadeCb = addon:CreateCheckbox(parent)
    rangeFadeCb:SetPoint("TOPLEFT", 16, yOffset)
    rangeFadeCb.Text:SetText("Fade non-target matched plates when out of range")
    rangeFadeCb:SetChecked(settings.fadeOutOfRange)
    rangeFadeCb:SetScript("OnClick", function(self)
        addon:SetSetting("nameplatesPlus.fadeOutOfRange", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local rangeFadeDistanceSlider = addon:CreateSlider(parent)
    rangeFadeDistanceSlider:SetPoint("TOPLEFT", 36, yOffset)
    rangeFadeDistanceSlider:SetMinMaxValues(10, 40)
    rangeFadeDistanceSlider:SetValueStep(1)
    rangeFadeDistanceSlider:SetValue(settings.rangeFadeDistance or 30)
    rangeFadeDistanceSlider.Text:SetText("Fade beyond: " .. (settings.rangeFadeDistance or 30) .. " yds")
    rangeFadeDistanceSlider:SetScript("OnValueChanged", function(self, value)
        local distance = math.floor(value + 0.5)
        self.Text:SetText("Fade beyond: " .. distance .. " yds")
        addon:SetSetting("nameplatesPlus.rangeFadeDistance", distance)
    end)
    yOffset = yOffset - 50

    local outOfRangeAlphaSlider = addon:CreateSlider(parent)
    outOfRangeAlphaSlider:SetPoint("TOPLEFT", 36, yOffset)
    outOfRangeAlphaSlider:SetMinMaxValues(0.1, 1.0)
    outOfRangeAlphaSlider:SetValueStep(0.05)
    outOfRangeAlphaSlider:SetValue(settings.outOfRangeAlpha or 0.5)
    outOfRangeAlphaSlider.Text:SetText(string.format("Out-of-range alpha: %.2f", settings.outOfRangeAlpha or 0.5))
    outOfRangeAlphaSlider:SetScript("OnValueChanged", function(self, value)
        local alpha = math.floor(value * 20 + 0.5) / 20
        self.Text:SetText(string.format("Out-of-range alpha: %.2f", alpha))
        addon:SetSetting("nameplatesPlus.outOfRangeAlpha", alpha)
    end)
    yOffset = yOffset - 50

    -- Icons Section
    local iconsHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    iconsHeader:SetPoint("TOPLEFT", 16, yOffset)
    iconsHeader:SetText("Icons")
    yOffset = yOffset - 25
    
    local eliteCb = addon:CreateCheckbox(parent)
    eliteCb:SetPoint("TOPLEFT", 16, yOffset)
    eliteCb.Text:SetText("Show elite/rare dragon icons")
    eliteCb:SetChecked(settings.eliteIcons)
    eliteCb:SetScript("OnClick", function(self)
        addon:SetSetting("nameplatesPlus.eliteIcons", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    local factionCb = addon:CreateCheckbox(parent)
    factionCb:SetPoint("TOPLEFT", 16, yOffset)
    factionCb.Text:SetText("Show faction icons (Alliance/Horde)")
    factionCb:SetChecked(settings.factionIcons)
    factionCb:SetScript("OnClick", function(self)
        addon:SetSetting("nameplatesPlus.factionIcons", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local npcIconCb = addon:CreateCheckbox(parent)
    npcIconCb:SetPoint("TOPLEFT", 16, yOffset)
    npcIconCb.Text:SetText("Show NPC role icons")
    npcIconCb:SetChecked(settings.npcIcons)
    npcIconCb:SetScript("OnClick", function(self)
        addon:SetSetting("nameplatesPlus.npcIcons", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local npcIconSizeSlider = addon:CreateSlider(parent)
    npcIconSizeSlider:SetPoint("TOPLEFT", 36, yOffset)
    npcIconSizeSlider:SetMinMaxValues(16, 36)
    npcIconSizeSlider:SetValueStep(1)
    npcIconSizeSlider:SetValue(settings.npcIconSize or 24)
    npcIconSizeSlider.Text:SetText("NPC icon size: " .. (settings.npcIconSize or 24))
    npcIconSizeSlider:SetScript("OnValueChanged", function(self, value)
        local size = math.floor(value + 0.5)
        self.Text:SetText("NPC icon size: " .. size)
        addon:SetSetting("nameplatesPlus.npcIconSize", size)
    end)
    yOffset = yOffset - 50
    
    -- Visuals Section
    local visualHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    visualHeader:SetPoint("TOPLEFT", 16, yOffset)
    visualHeader:SetText("Visuals & Range")
    yOffset = yOffset - 25

    -- Texture Mode
    local textureCb = addon:CreateCheckbox(parent)
    textureCb:SetPoint("TOPLEFT", 16, yOffset)
    textureCb.Text:SetText("Use Flat (NotPlater-style) bar textures")
    textureCb:SetChecked(settings.textureMode == "Flat")
    textureCb:SetScript("OnClick", function(self)
        local mode = self:GetChecked() and "Flat" or "Blizzard"
        addon:SetSetting("nameplatesPlus.textureMode", mode)
        MarkAllFramesDirty()
    end)
    yOffset = yOffset - 25

    -- Range Slider
    local rangeMin, rangeMax = GetNameplateRangeBounds()
    local rangeValue = math.min(GetConfiguredNameplateRange(settings), rangeMax)

    local rangeSlider = CreateFrame("Slider", "DCQoSNameplateRange", parent, "OptionsSliderTemplate")
    rangeSlider:SetPoint("TOPLEFT", 20, yOffset - 10)
    rangeSlider:SetWidth(200)
    rangeSlider:SetHeight(17)
    rangeSlider:SetMinMaxValues(rangeMin, rangeMax)
    rangeSlider:SetValueStep(1)
    rangeSlider:SetValue(rangeValue)
    
    _G[rangeSlider:GetName() .. "Text"]:SetText("View Distance: " .. rangeValue .. " yds")
    _G[rangeSlider:GetName() .. "Low"]:SetText(tostring(rangeMin))
    _G[rangeSlider:GetName() .. "High"]:SetText(tostring(rangeMax))
    
    rangeSlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value + 0.5)
        addon:SetSetting("nameplatesPlus.nameplateRange", val)
        _G[self:GetName() .. "Text"]:SetText("View Distance: " .. val .. " yds")
        if HasExtendedNameplateDistanceApi() then
            ApplyNameplateRange(addon.settings.nameplatesPlus)
        else
            SafeSetCVar("nameplateMaxDistance", tostring(math.min(val, 41)))
        end
    end)
    yOffset = yOffset - 50

    local rangeInfo = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    rangeInfo:SetPoint("TOPLEFT", 20, yOffset + 8)
    rangeInfo:SetWidth(420)
    rangeInfo:SetJustifyH("LEFT")
    if HasExtendedNameplateDistanceApi() then
        rangeInfo:SetText("Extended native nameplate range is available in this client build. Values above 41 use the Graphics+ native patch path.")
    else
        rangeInfo:SetText("Stock client nameplate range is capped at 41 yards. Build the native Graphics+ patch to unlock the extended range path.")
    end
    yOffset = yOffset - 26
    
    return yOffset - 50
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("NameplatesPlus", NameplatesPlus)
