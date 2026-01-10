-- ============================================================
-- DC-QoS: Druid Fix Module
-- ============================================================
-- Ports the standalone "DruidFix" addon into DC-QoS:
-- 1) High-level druid stat panel crash workaround (level >= 100)
-- 2) Question-mark / missing icon fixes (action buttons, bags, inventory)
-- ============================================================

local addon = DCQOS

local DruidFix = {
    displayName = "Druid Fix",
    settingKey = "druidfix",
    icon = "Interface\\Icons\\Ability_Druid_TwilightsWrath",
    defaults = {
        druidfix = {
            enabled = true,
            statFix = true,
            iconFix = true,
        }
    },
}

-- ============================================================
-- Stat Conversion Tables (WotLK 3.3.5a)
-- ============================================================

local CritPerAgi = { 0.0037, 0.0080, 0.0099, 0.0050, 0.0308, 0.0037, 0.0282, 0.0086, 0.0283, 0.0291 }
local SpellCritPerInt = { 0.0000, 0.0025, 0.0025, 0.0000, 0.0025, 0.0000, 0.0025, 0.0025, 0.0025, 0.0025 }
local BaseManaRegenPerSpi = 0.003345
local HealthRegenPerSpi = { 0.5, 0.125, 0.125, 0.333332986, 0.041666999, 0.5, 0.071428999, 0.041666999, 0.045455001, 0.0625 }

local ClassNameToID = {
    WARRIOR = 1,
    PALADIN = 2,
    HUNTER = 3,
    ROGUE = 4,
    PRIEST = 5,
    DEATHKNIGHT = 6,
    SHAMAN = 7,
    MAGE = 8,
    WARLOCK = 9,
    DRUID = 10,
}

local function GetSettings()
    return (addon and addon.settings and addon.settings.druidfix) or {}
end

local function ModuleEnabled()
    local settings = GetSettings()
    return settings.enabled ~= false
end

local function ShouldApplyStatFix(unit)
    local settings = GetSettings()
    if settings.enabled == false or settings.statFix == false then return false end
    if unit ~= "player" then return false end

    local level = UnitLevel("player")
    if not level or level <= 99 then return false end

    local _, classFile = UnitClass("player")
    return classFile == "DRUID"
end

local function ShouldApplyIconFix()
    local settings = GetSettings()
    return settings.enabled ~= false and settings.iconFix ~= false
end

local function GetClassId(class)
    if type(class) == "string" then
        return ClassNameToID[string.upper(class)]
    end
    if type(class) == "number" and class >= 1 and class <= 10 then
        return class
    end
    return nil
end

local function GetCritFromAgi(agi, class)
    local classId = GetClassId(class) or ClassNameToID.DRUID
    return agi * CritPerAgi[classId], "MELEE_CRIT"
end

local function GetSpellCritFromInt(intellect, class)
    local classId = GetClassId(class) or ClassNameToID.DRUID
    return intellect * SpellCritPerInt[classId], "SPELL_CRIT"
end

local function GetNormalManaRegenFromSpi(spi, intellect)
    return (0.001 + spi * BaseManaRegenPerSpi * (intellect ^ 0.5)) * 5, "MANA_REG_NOT_CASTING"
end

local function GetHealthRegenFromSpi(spi, class)
    local classId = GetClassId(class) or ClassNameToID.DRUID
    return spi * HealthRegenPerSpi[classId] * 5, "HEALTH_REG_OUT_OF_COMBAT"
end

-- ============================================================
-- Safe Global Hooking
-- ============================================================

local hooks = {}

local function InstallHook(globalName, wrapperFactory)
    if hooks[globalName] then return end
    local original = _G[globalName]
    if type(original) ~= "function" then return end

    local wrapper = wrapperFactory(original)
    hooks[globalName] = { original = original, wrapper = wrapper }
    _G[globalName] = wrapper
end

local function RestoreHook(globalName)
    local entry = hooks[globalName]
    if not entry then return end

    if _G[globalName] == entry.wrapper then
        _G[globalName] = entry.original
    end

    hooks[globalName] = nil
end

local function InstallAllHooks()
    -- Stat crash workaround: only applies for high-level druids.
    InstallHook("GetCritChanceFromAgility", function(original)
        return function(...)
            local unit = ...
            if ShouldApplyStatFix(unit) then
                local base, effective = UnitStat("player", 2)
                local agility = effective or base or 0
                local _, classFile = UnitClass("player")
                return GetCritFromAgi(agility, classFile)
            end
            return original(...)
        end
    end)

    InstallHook("GetSpellCritChanceFromIntellect", function(original)
        return function(...)
            local unit = ...
            if ShouldApplyStatFix(unit) then
                local base, effective = UnitStat("player", 4)
                local intellect = effective or base or 0
                local _, classFile = UnitClass("player")
                return GetSpellCritFromInt(intellect, classFile)
            end
            return original(...)
        end
    end)

    InstallHook("GetUnitManaRegenRateFromSpirit", function(original)
        return function(...)
            local unit = ...
            if ShouldApplyStatFix(unit) then
                local spiBase, spiEff = UnitStat("player", 5)
                local intBase, intEff = UnitStat("player", 4)
                local spirit = spiEff or spiBase or 0
                local intellect = intEff or intBase or 0
                return GetNormalManaRegenFromSpi(spirit, intellect)
            end
            return original(...)
        end
    end)

    InstallHook("GetUnitHealthRegenRateFromSpirit", function(original)
        return function(...)
            local unit = ...
            if ShouldApplyStatFix(unit) then
                local spiBase, spiEff = UnitStat("player", 5)
                local spirit = spiEff or spiBase or 0
                local _, classFile = UnitClass("player")
                return GetHealthRegenFromSpi(spirit, classFile)
            end
            return original(...)
        end
    end)

    -- Icon fixes: applies for all classes when enabled.
    InstallHook("GetActionTexture", function(original)
        return function(action)
            local texture = original(action)
            if not ShouldApplyIconFix() then
                return texture
            end

            if texture and string.find(texture, "INV_Misc_QuestionMark") then
                local actionType, actionId = GetActionInfo(action)
                if actionType == "item" and actionId then
                    local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(actionId)
                    if itemTexture then
                        texture = itemTexture
                    end
                elseif actionType ~= "macro" then
                    texture = string.gsub(texture, "INV_Misc_QuestionMark", "INV_Misc_Gem_Topaz_02")
                end
            end

            return texture
        end
    end)

    InstallHook("GetContainerItemInfo", function(original)
        return function(bag, slot)
            local texture, itemCount, locked, quality, readable = original(bag, slot)
            if not ShouldApplyIconFix() then
                return texture, itemCount, locked, quality, readable
            end

            if texture and string.find(texture, "INV_Misc_QuestionMark") then
                local itemLink = GetContainerItemLink(bag, slot)
                if itemLink then
                    local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
                    if itemTexture then
                        texture = itemTexture
                    end
                end
            end

            return texture, itemCount, locked, quality, readable
        end
    end)

    InstallHook("GetInventoryItemTexture", function(original)
        return function(...)
            local texture = original(...)
            if not ShouldApplyIconFix() then
                return texture
            end

            local unit, slotId = ...
            if unit == "player" and type(slotId) == "number" and slotId > 19 and slotId < 24 and not texture then
                local itemLink = GetInventoryItemLink(unit, slotId)
                if itemLink then
                    local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
                    if itemTexture then
                        texture = itemTexture
                    end
                end
            end

            return texture
        end
    end)
end

-- ============================================================
-- Module Callbacks
-- ============================================================

function DruidFix.OnInitialize()
    addon:Debug("DruidFix module initializing")
end

function DruidFix.OnEnable()
    addon:Debug("DruidFix module enabling")
    InstallAllHooks()
end

function DruidFix.OnDisable()
    addon:Debug("DruidFix module disabling")

    RestoreHook("GetCritChanceFromAgility")
    RestoreHook("GetSpellCritChanceFromIntellect")
    RestoreHook("GetUnitManaRegenRateFromSpirit")
    RestoreHook("GetUnitHealthRegenRateFromSpirit")

    RestoreHook("GetActionTexture")
    RestoreHook("GetContainerItemInfo")
    RestoreHook("GetInventoryItemTexture")
end

-- ============================================================
-- Settings Panel
-- ============================================================

function DruidFix.CreateSettings(parent)
    local settings = GetSettings()
    local yOffset = -20

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Druid Fix")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("Ports DruidFix into DC-QoS: fixes the high-level druid stats panel crash (level 100+) and replaces missing/question-mark icons.")

    yOffset = yOffset - 55

    local enableCb = addon:CreateCheckbox(parent)
    enableCb:SetPoint("TOPLEFT", 16, yOffset)
    enableCb.Text:SetText("Enable Druid Fix")
    enableCb:SetChecked(settings.enabled ~= false)
    enableCb:SetScript("OnClick", function(self)
        addon:SetSetting("druidfix.enabled", self:GetChecked())
    end)
    yOffset = yOffset - 30

    local statCb = addon:CreateCheckbox(parent)
    statCb:SetPoint("TOPLEFT", 16, yOffset)
    statCb.Text:SetText("Enable druid stat crash workaround (level 100+)")
    statCb:SetChecked(settings.statFix ~= false)
    statCb:SetScript("OnClick", function(self)
        addon:SetSetting("druidfix.statFix", self:GetChecked())
    end)
    yOffset = yOffset - 30

    local iconCb = addon:CreateCheckbox(parent)
    iconCb:SetPoint("TOPLEFT", 16, yOffset)
    iconCb.Text:SetText("Enable missing/question-mark icon fixes")
    iconCb:SetChecked(settings.iconFix ~= false)
    iconCb:SetScript("OnClick", function(self)
        addon:SetSetting("druidfix.iconFix", self:GetChecked())
    end)
    yOffset = yOffset - 40

    local note = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 16, yOffset)
    note:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    note:SetJustifyH("LEFT")
    note:SetText("Note: Enabling/disabling modules may prompt for a UI reload. The stat fix only applies to druids above level 99.")

    return yOffset - 30
end

addon:RegisterModule("DruidFix", DruidFix)
