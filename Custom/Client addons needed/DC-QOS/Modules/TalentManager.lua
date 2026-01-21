-- ============================================================
-- DC-QoS: Talent Manager Module
-- ============================================================
-- Full-featured talent build manager with templates, save/load,
-- glyph support, inspect hook, and import/export
-- Inspired by Talented addon for WoW 3.3.5a
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local TalentManager = {
    displayName = "Talent Manager",
    settingKey = "talentManager",
    icon = "Interface\\Icons\\Ability_Marksmanship",
    defaults = {
        talentManager = {
            enabled = true,
            showGlyphs = true,
            confirmLearning = true,
            frameScale = 1.0,
            lockFrame = false,
            autoBackup = true,
            showLevelReq = false,
            alwaysEdit = false,
            hookInspect = true,
            framePos = {},
            glyphFramePos = {},
        },
    },
}

addon:MergeModuleDefaults(TalentManager.defaults)

-- ============================================================
-- Local Data Storage
-- ============================================================
local templates = {}        -- Saved talent templates
local inspections = {}      -- Inspected player templates
local mainFrame = nil       -- Main UI frame
local glyphFrame = nil      -- Glyph management frame
local isInitialized = false
local currentMode = "view"  -- view | edit | apply
local targetTemplate = nil  -- Template to compare against

-- Class-specific talent tree names and icons
local TALENT_TREE_DATA = {
    WARRIOR = {
        names = { "Arms", "Fury", "Protection" },
        icons = { "Ability_Rogue_Eviscerate", "Ability_Warrior_InnerRage", "INV_Shield_06" },
        backgrounds = { "WarriorArms", "WarriorFury", "WarriorProtection" },
    },
    PALADIN = {
        names = { "Holy", "Protection", "Retribution" },
        icons = { "Spell_Holy_HolyBolt", "Spell_Holy_DevotionAura", "Spell_Holy_AuraOfLight" },
        backgrounds = { "PaladinHoly", "PaladinProtection", "PaladinCombat" },
    },
    HUNTER = {
        names = { "Beast Mastery", "Marksmanship", "Survival" },
        icons = { "Ability_Hunter_BeastTaming", "Ability_Marksmanship", "Ability_Hunter_SwiftStrike" },
        backgrounds = { "HunterBeastMastery", "HunterMarksmanship", "HunterSurvival" },
    },
    ROGUE = {
        names = { "Assassination", "Combat", "Subtlety" },
        icons = { "Ability_Rogue_Eviscerate", "Ability_BackStab", "Ability_Stealth" },
        backgrounds = { "RogueAssassination", "RogueCombat", "RogueSubtlety" },
    },
    PRIEST = {
        names = { "Discipline", "Holy", "Shadow" },
        icons = { "Spell_Holy_WordFortitude", "Spell_Holy_HolyBolt", "Spell_Shadow_ShadowWordPain" },
        backgrounds = { "PriestDiscipline", "PriestHoly", "PriestShadow" },
    },
    DEATHKNIGHT = {
        names = { "Blood", "Frost", "Unholy" },
        icons = { "Spell_Deathknight_BloodPresence", "Spell_Deathknight_FrostPresence", "Spell_Deathknight_UnholyPresence" },
        backgrounds = { "DeathKnightBlood", "DeathKnightFrost", "DeathKnightUnholy" },
    },
    SHAMAN = {
        names = { "Elemental", "Enhancement", "Restoration" },
        icons = { "Spell_Nature_Lightning", "Spell_Nature_LightningShield", "Spell_Nature_MagicImmunity" },
        backgrounds = { "ShamanElementalCombat", "ShamanEnhancement", "ShamanRestoration" },
    },
    MAGE = {
        names = { "Arcane", "Fire", "Frost" },
        icons = { "Spell_Holy_MagicalSentry", "Spell_Fire_FireBolt02", "Spell_Frost_FrostBolt02" },
        backgrounds = { "MageArcane", "MageFire", "MageFrost" },
    },
    WARLOCK = {
        names = { "Affliction", "Demonology", "Destruction" },
        icons = { "Spell_Shadow_DeathCoil", "Spell_Shadow_Metamorphosis", "Spell_Shadow_RainOfFire" },
        backgrounds = { "WarlockAffliction", "WarlockDemonology", "WarlockDestruction" },
    },
    DRUID = {
        names = { "Balance", "Feral Combat", "Restoration" },
        icons = { "Spell_Nature_StarFall", "Ability_Racial_BearForm", "Spell_Nature_HealingTouch" },
        backgrounds = { "DruidBalance", "DruidFeralCombat", "DruidRestoration" },
    },
}

-- Pet talent families
local PET_TALENT_DATA = {
    Ferocity = { names = { "Ferocity" }, icons = { "Ability_Druid_PrimalTenacity" } },
    Cunning = { names = { "Cunning" }, icons = { "Ability_Eyeoftheowl" } },
    Tenacity = { names = { "Tenacity" }, icons = { "Ability_Druid_DemoralizingRoar" } },
}

-- Talent prerequisite data cache
local talentPrereqs = {}

-- Encode maps for various sites
local TALENTED_MAP = "012345abcdefABCDEFmnopqrMNOPQRtuvwxy*"
local WOWHEAD_MAP = "0zMcmVokRsaqbdrfwihuGINALpTjnyxtgevE"
local BG_FELLEATHER = "Interface\\AddOns\\DC-QOS\\Textures\\Backgrounds\\FelLeather_512.tga"
local DCQOS_ICON = "Interface\\AddOns\\Icons\\DC-QOS\\Icon_64.tga"

-- Class to code mapping
local CLASS_CODES = {
    DRUID = 1, HUNTER = 2, MAGE = 3, PALADIN = 4, PRIEST = 5,
    ROGUE = 6, SHAMAN = 7, WARLOCK = 8, WARRIOR = 9, DEATHKNIGHT = 10,
}

local CODE_CLASSES = {}
for class, code in pairs(CLASS_CODES) do
    CODE_CLASSES[code] = class
end

-- ============================================================
-- 3.3.5a Compatibility Helpers
-- ============================================================

local function SafeGetActiveTalentGroup(isInspect, isPet)
    if GetActiveTalentGroup then
        local group = GetActiveTalentGroup(isInspect, isPet)
        return group or 1
    end
    return 1
end

local function SafeGetNumTalentGroups()
    if GetNumTalentGroups then
        return GetNumTalentGroups() or 1
    end
    return 1
end

local function SafeSetActiveTalentGroup(index)
    if SetActiveTalentGroup then
        SetActiveTalentGroup(index)
        return true
    end
    return false
end

local function SafeGetNumTalentTabs(inspect, pet)
    if GetNumTalentTabs then
        return GetNumTalentTabs(inspect, pet) or 0
    end
    return 0
end

local function SafeGetNumTalents(tab, inspect, pet)
    if GetNumTalents then
        return GetNumTalents(tab, inspect, pet) or 0
    end
    return 0
end

local function SafeGetTalentInfo(tab, index, inspect, pet, talentGroup)
    if GetTalentInfo then
        return GetTalentInfo(tab, index, inspect, pet, talentGroup)
    end
end

local function SafeGetTalentPrereqs(tab, index, inspect, pet, talentGroup)
    if GetTalentPrereqs then
        return GetTalentPrereqs(tab, index, inspect, pet, talentGroup)
    end
    return nil
end

local function NormalizeTalentIconPath(iconPath)
    if not iconPath then return nil end
    if type(iconPath) == "number" then
        return iconPath
    end
    if type(iconPath) ~= "string" then
        return nil
    end
    local path = iconPath
    path = path:gsub("/", "\\")
    if not path:find("\\") then
        path = "Interface\\Icons\\" .. path
    end
    return path
end

-- Simple vertex color approach for talent icons (no shader dependency)
local function SetTalentButtonDesaturated(button, desaturated, r, g, b)
    if not button or not button.icon then return end
    local icon = button.icon
    
    -- Try shader desaturation first
    if desaturated then
        local shaderOk = pcall(function() icon:SetDesaturated(true) end)
        if not shaderOk then
            icon:SetDesaturated(nil)  -- Fallback: clear any bad state
        end
        -- Apply color tint as fallback/overlay
        r = r or 0.5
        g = g or 0.5
        b = b or 0.5
    else
        pcall(function() icon:SetDesaturated(false) end)
        r = 1.0
        g = 1.0
        b = 1.0
    end
    
    icon:SetVertexColor(r, g, b)
end

local function SafeGetNumGlyphSockets()
    if GetNumGlyphSockets then
        return GetNumGlyphSockets() or 0
    end
    return 0
end

local function SafeGetGlyphSocketInfo(index, talentGroup)
    if GetGlyphSocketInfo then
        return GetGlyphSocketInfo(index, talentGroup)
    end
end

local function SafeGetUnspentTalentPoints(talentGroup, isPet)
    if GetUnspentTalentPoints then
        return GetUnspentTalentPoints(talentGroup, isPet) or 0
    end
    return 0
end

-- ============================================================
-- Utility Functions
-- ============================================================

local function GetPlayerClass()
    local _, class = UnitClass("player")
    return class
end

local function GetTreeData(class)
    class = class or GetPlayerClass()
    return TALENT_TREE_DATA[class] or PET_TALENT_DATA[class]
end

local function GetTreeNames(class)
    local data = GetTreeData(class)
    return data and data.names or { "Tree 1", "Tree 2", "Tree 3" }
end

local function GetTreeIcons(class)
    local data = GetTreeData(class)
    return data and data.icons or {}
end

-- Get current player talents
local function GetCurrentTalents(pet, talentGroup)
    local talents = {}
    local totalPoints = 0
    talentGroup = talentGroup or SafeGetActiveTalentGroup(nil, pet)
    
    for tab = 1, SafeGetNumTalentTabs(nil, pet) do
        talents[tab] = {}
        local numTalents = SafeGetNumTalents(tab, nil, pet)
        for i = 1, numTalents do
            local _, _, _, _, rank = SafeGetTalentInfo(tab, i, nil, pet, talentGroup)
            talents[tab][i] = rank or 0
            totalPoints = totalPoints + (rank or 0)
        end
    end
    
    talents.totalPoints = totalPoints
    talents.class = GetPlayerClass()
    talents.pet = pet
    talents.talentGroup = talentGroup
    return talents
end

-- Count points in a talent tree
local function GetTreePoints(talents, tab)
    local count = 0
    if talents and talents[tab] then
        for _, rank in ipairs(talents[tab]) do
            count = count + (rank or 0)
        end
    end
    return count
end

-- Get total points in a template
local function GetTotalPoints(talents)
    local total = 0
    for tab = 1, 3 do
        total = total + GetTreePoints(talents, tab)
    end
    return total
end

-- Get point summary string (e.g., "51/20/0")
local function GetPointSummary(talents)
    local parts = {}
    for tab = 1, 3 do
        table.insert(parts, tostring(GetTreePoints(talents, tab)))
    end
    return table.concat(parts, "/")
end

-- Get primary tree (most points)
local function GetPrimaryTree(talents)
    local maxPoints = 0
    local primary = 1
    for tab = 1, 3 do
        local points = GetTreePoints(talents, tab)
        if points > maxPoints then
            maxPoints = points
            primary = tab
        end
    end
    return primary
end

-- Get required level for point count
local function GetRequiredLevel(points, pet)
    if pet then
        if points == 0 then return 10 end
        if points > 16 then
            return 60 + (points - 15) * 4 -- Beast Mastery required
        end
        return 16 + points * 4
    end
    return points == 0 and 1 or (points + 9)
end

-- Build prerequisite cache for a class
local function BuildPrereqCache(class, pet)
    local key = (class or GetPlayerClass()) .. (pet and "_pet" or "")
    if talentPrereqs[key] then return talentPrereqs[key] end
    
    talentPrereqs[key] = {}
    for tab = 1, SafeGetNumTalentTabs(nil, pet) do
        talentPrereqs[key][tab] = {}
        local numTalents = SafeGetNumTalents(tab, nil, pet)
        for i = 1, numTalents do
            local _, _, tier, column, _, maxRank, _, prereqTab, prereqTalent = SafeGetTalentInfo(tab, i, nil, pet)
            talentPrereqs[key][tab][i] = {
                tier = tier,
                column = column,
                maxRank = maxRank,
                prereqTab = prereqTab,
                prereqTalent = prereqTalent,
            }
        end
    end
    return talentPrereqs[key]
end

-- Check if talent is available (tier unlocked, prereqs met)
local function IsTalentAvailable(talents, tab, index, pet)
    local class = talents.class or GetPlayerClass()
    local prereqs = BuildPrereqCache(class, pet)
    local info = prereqs[tab] and prereqs[tab][index]
    if not info then return false end
    
    -- Check tier requirement (5 points per tier for players, 3 for pets)
    local pointsPerTier = pet and 3 or 5
    local tierReq = (info.tier - 1) * pointsPerTier
    local treePoints = GetTreePoints(talents, tab)
    if treePoints < tierReq then return false end
    
    -- Check prerequisite talent
    if info.prereqTab and info.prereqTalent and info.prereqTab > 0 and info.prereqTalent > 0 then
        local prereqInfo = prereqs[info.prereqTab] and prereqs[info.prereqTab][info.prereqTalent]
        local prereqRank = talents[info.prereqTab] and talents[info.prereqTab][info.prereqTalent] or 0
        if prereqRank < (prereqInfo and prereqInfo.maxRank or 0) then
            return false
        end
    end
    
    return true
end

-- Get talent state: "available", "maxed", "locked", "partial"
local function GetTalentState(talents, tab, index, pet)
    local currentRank = talents[tab] and talents[tab][index] or 0
    local class = talents.class or GetPlayerClass()
    local prereqs = BuildPrereqCache(class, pet)
    local info = prereqs[tab] and prereqs[tab][index]
    local maxRank = info and info.maxRank or 0
    
    if currentRank >= maxRank then
        return "maxed"
    elseif not IsTalentAvailable(talents, tab, index, pet) then
        return "locked"
    elseif currentRank > 0 then
        return "partial"
    else
        return "available"
    end
end

-- ============================================================
-- Encoding/Decoding for Templates
-- ============================================================

-- Simple encode: just concatenate ranks with - separator
local function EncodeTalentsSimple(talents)
    local encoded = ""
    for tab = 1, 3 do
        local tree = talents[tab] or {}
        for i = 1, #tree do
            encoded = encoded .. tostring(tree[i] or 0)
        end
        if tab < 3 then
            encoded = encoded .. "-"
        end
    end
    return encoded
end

-- Simple decode
local function DecodeTalentsSimple(encoded)
    local talents = {}
    local trees = { strsplit("-", encoded) }
    for tab = 1, 3 do
        talents[tab] = {}
        local treeStr = trees[tab] or ""
        for i = 1, #treeStr do
            talents[tab][i] = tonumber(treeStr:sub(i, i)) or 0
        end
    end
    return talents
end

-- Talented-style encoding (compact)
local function EncodeTalented(talents, class)
    class = class or talents.class or GetPlayerClass()
    local classCode = CLASS_CODES[class]
    if not classCode then return nil end
    
    local code = TALENTED_MAP:sub((classCode - 1) * 3 + 1, (classCode - 1) * 3 + 1)
    
    for tab = 1, 3 do
        local tree = talents[tab] or {}
        local i = 1
        while i <= #tree do
            local r1 = tree[i] or 0
            local r2 = tree[i + 1] or 0
            local v = r1 * 6 + r2 + 1
            code = code .. TALENTED_MAP:sub(v, v)
            i = i + 2
        end
    end
    
    -- Trim trailing zeros (represented as '0' or 'Z')
    code = code:gsub("0+$", ""):gsub("Z+$", "")
    
    return code
end

-- Talented-style decoding
local function DecodeTalented(code)
    if not code or code == "" then return nil end
    
    local classIdx = math.floor((TALENTED_MAP:find(code:sub(1, 1), nil, true) - 1) / 3) + 1
    local class = CODE_CLASSES[classIdx]
    if not class then return nil end
    
    local talents = { class = class }
    local pos = 2
    
    for tab = 1, 3 do
        talents[tab] = {}
        local numTalents = SafeGetNumTalents(tab) > 0 and SafeGetNumTalents(tab) or 30 -- Fallback
        local i = 1
        while i <= numTalents and pos <= #code do
            local charIdx = TALENTED_MAP:find(code:sub(pos, pos), nil, true)
            if not charIdx then break end
            local v = charIdx - 1
            talents[tab][i] = math.floor(v / 6)
            talents[tab][i + 1] = v % 6
            i = i + 2
            pos = pos + 1
        end
    end
    
    return talents
end

-- WoWhead URL encode
local function EncodeWowhead(talents, class)
    class = class or talents.class or GetPlayerClass()
    local classNames = {
        WARRIOR = "warrior", PALADIN = "paladin", HUNTER = "hunter",
        ROGUE = "rogue", PRIEST = "priest", DEATHKNIGHT = "death-knight",
        SHAMAN = "shaman", MAGE = "mage", WARLOCK = "warlock", DRUID = "druid",
    }
    
    local talentStr = ""
    for tab = 1, 3 do
        for _, rank in ipairs(talents[tab] or {}) do
            talentStr = talentStr .. tostring(rank or 0)
        end
    end
    talentStr = talentStr:gsub("0+$", "")
    
    return "https://www.wowhead.com/wotlk/talent-calc/" .. (classNames[class] or "warrior") .. "/" .. talentStr
end

-- WoTLKDB URL encode
local function EncodeWotlkdb(talents, class)
    class = class or talents.class or GetPlayerClass()
    return "https://wotlk.evowow.com/?talent#" .. EncodeTalented(talents, class)
end

-- Parse various URL formats
local function ParseURL(url)
    local talents = nil
    local class = nil
    
    -- WoWhead format: /talent-calc/CLASS/TALENTS
    local wowheadClass, wowheadTalents = url:match("talent%-calc/([^/]+)/([0-9]+)")
    if wowheadClass and wowheadTalents then
        local classMap = {
            warrior = "WARRIOR", paladin = "PALADIN", hunter = "HUNTER",
            rogue = "ROGUE", priest = "PRIEST", ["death-knight"] = "DEATHKNIGHT",
            shaman = "SHAMAN", mage = "MAGE", warlock = "WARLOCK", druid = "DRUID",
        }
        class = classMap[wowheadClass:lower()]
        if class then
            talents = { class = class }
            local pos = 1
            for tab = 1, 3 do
                talents[tab] = {}
                local numTalents = SafeGetNumTalents(tab) > 0 and SafeGetNumTalents(tab) or 30
                for i = 1, numTalents do
                    if pos <= #wowheadTalents then
                        talents[tab][i] = tonumber(wowheadTalents:sub(pos, pos)) or 0
                        pos = pos + 1
                    else
                        talents[tab][i] = 0
                    end
                end
            end
        end
    end
    
    -- Talented format: ?talent#CODE
    if not talents then
        local talentedCode = url:match("[%?#]talent#([%w%*]+)")
        if talentedCode then
            talents = DecodeTalented(talentedCode)
        end
    end
    
    -- Simple format: CLASS/TALENTS (e.g., WARRIOR/3050300130000000000000000000000325000103000000000000000000000000000)
    if not talents then
        local simpleClass, simpleTalents = url:match("([A-Z]+)/([0-9%-]+)")
        if simpleClass and simpleTalents then
            talents = DecodeTalentsSimple(simpleTalents)
            talents.class = simpleClass
        end
    end
    
    return talents
end

-- ============================================================
-- Template Management
-- ============================================================

function TalentManager:LoadTemplates()
    if not addon.db then return end
    
    addon.db.talentTemplates = addon.db.talentTemplates or {}
    templates = addon.db.talentTemplates
    
    local class = GetPlayerClass()
    templates[class] = templates[class] or {}
    
    return templates[class]
end

function TalentManager:SaveTemplates()
    if not addon.db then return end
    addon.db.talentTemplates = templates
end

function TalentManager:CreateTemplate(name, talents, class)
    class = class or GetPlayerClass()
    templates[class] = templates[class] or {}
    
    if templates[class][name] then
        return false, "Template already exists"
    end
    
    talents = talents or GetCurrentTalents()
    
    templates[class][name] = {
        name = name,
        class = class,
        talents = talents,
        encoded = EncodeTalentsSimple(talents),
        talentedCode = EncodeTalented(talents, class),
        summary = GetPointSummary(talents),
        totalPoints = GetTotalPoints(talents),
        primaryTree = GetPrimaryTree(talents),
        created = time(),
        modified = time(),
    }
    
    self:SaveTemplates()
    addon:Print("Template saved: " .. name .. " (" .. GetPointSummary(talents) .. ")")
    return true
end

function TalentManager:UpdateTemplate(name, talents, class)
    class = class or GetPlayerClass()
    if not templates[class] or not templates[class][name] then
        return self:CreateTemplate(name, talents, class)
    end
    
    talents = talents or GetCurrentTalents()
    
    templates[class][name].talents = talents
    templates[class][name].encoded = EncodeTalentsSimple(talents)
    templates[class][name].talentedCode = EncodeTalented(talents, class)
    templates[class][name].summary = GetPointSummary(talents)
    templates[class][name].totalPoints = GetTotalPoints(talents)
    templates[class][name].primaryTree = GetPrimaryTree(talents)
    templates[class][name].modified = time()
    
    self:SaveTemplates()
    addon:Print("Template updated: " .. name)
    return true
end

function TalentManager:DeleteTemplate(name, class)
    class = class or GetPlayerClass()
    if templates[class] and templates[class][name] then
        templates[class][name] = nil
        self:SaveTemplates()
        addon:Print("Template deleted: " .. name)
        return true
    end
    return false, "Template not found"
end

function TalentManager:RenameTemplate(oldName, newName, class)
    class = class or GetPlayerClass()
    if not templates[class] or not templates[class][oldName] then
        return false, "Template not found"
    end
    if templates[class][newName] then
        return false, "New name already exists"
    end
    
    templates[class][newName] = templates[class][oldName]
    templates[class][newName].name = newName
    templates[class][newName].modified = time()
    templates[class][oldName] = nil
    
    self:SaveTemplates()
    addon:Print("Template renamed: " .. oldName .. " -> " .. newName)
    return true
end

function TalentManager:CopyTemplate(name, class)
    class = class or GetPlayerClass()
    if not templates[class] or not templates[class][name] then
        return false, "Template not found"
    end
    
    local count = 1
    local newName = "Copy of " .. name
    while templates[class][newName] do
        count = count + 1
        newName = "Copy of " .. name .. " (" .. count .. ")"
    end
    
    local src = templates[class][name]
    local copyTalents = {}
    for tab = 1, 3 do
        copyTalents[tab] = {}
        for i, rank in ipairs(src.talents[tab] or {}) do
            copyTalents[tab][i] = rank
        end
    end
    copyTalents.class = src.class
    
    return self:CreateTemplate(newName, copyTalents, class)
end

function TalentManager:GetTemplate(name, class)
    class = class or GetPlayerClass()
    return templates[class] and templates[class][name]
end

function TalentManager:GetTemplateList(class)
    class = class or GetPlayerClass()
    local list = {}
    if templates[class] then
        for name, data in pairs(templates[class]) do
            table.insert(list, {
                name = name,
                summary = data.summary,
                totalPoints = data.totalPoints,
                primaryTree = data.primaryTree,
                modified = data.modified,
            })
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- ============================================================
-- Template Application
-- ============================================================

function TalentManager:CanApplyTemplate(template, pet)
    if not template then return false, "No template" end
    
    local current = GetCurrentTalents(pet)
    local available = SafeGetUnspentTalentPoints(nil, pet)
    local needed = 0
    
    for tab = 1, 3 do
        for i = 1, #(template.talents[tab] or {}) do
            local targetRank = template.talents[tab][i] or 0
            local currentRank = current[tab] and current[tab][i] or 0
            if targetRank > currentRank then
                needed = needed + (targetRank - currentRank)
            end
        end
    end
    
    if needed > available then
        return false, "Need " .. needed .. " points, have " .. available
    end
    
    if needed == 0 then
        return false, "Nothing to apply"
    end
    
    return true, needed
end

function TalentManager:ApplyTemplate(templateName, pet)
    local template = self:GetTemplate(templateName)
    if not template then
        addon:Print("Template not found: " .. templateName)
        return false
    end
    
    local canApply, info = self:CanApplyTemplate(template, pet)
    if not canApply then
        addon:Print("Cannot apply template: " .. info)
        return false
    end
    
    local settings = addon.settings.talentManager
    
    if settings.confirmLearning then
        StaticPopupDialogs["DCQOS_APPLY_TALENTS"] = StaticPopupDialogs["DCQOS_APPLY_TALENTS"] or {
            text = "Apply talent template '%s'?\n%d points will be spent.",
            button1 = ACCEPT,
            button2 = CANCEL,
            OnAccept = function(self, data)
                TalentManager:DoApplyTemplate(data.template, data.pet)
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            preferredIndex = 3,
        }
        
        StaticPopupDialogs["DCQOS_APPLY_TALENTS"].text = 
            "Apply talent template '" .. templateName .. "'?\n" .. info .. " points will be spent."
        
        local dialog = StaticPopup_Show("DCQOS_APPLY_TALENTS")
        if dialog then
            dialog.data = { template = template, pet = pet }
        end
    else
        self:DoApplyTemplate(template, pet)
    end
    
    return true
end

function TalentManager:DoApplyTemplate(template, pet)
    local current = GetCurrentTalents(pet)
    local learned = 0
    local class = template.class or template.talents.class or GetPlayerClass()
    local prereqs = BuildPrereqCache(class, pet)
    
    -- Apply talents in tier order
    for tier = 1, 11 do
        for tab = 1, 3 do
            for i = 1, #(template.talents[tab] or {}) do
                local info = prereqs[tab] and prereqs[tab][i]
                if info and info.tier == tier then
                    local targetRank = template.talents[tab][i] or 0
                    local currentRank = current[tab] and current[tab][i] or 0
                    
                    while currentRank < targetRank do
                        LearnTalent(tab, i, pet)
                        currentRank = currentRank + 1
                        current[tab][i] = currentRank
                        learned = learned + 1
                    end
                end
            end
        end
    end
    
    addon:Print("Applied template: " .. template.name .. " (" .. learned .. " points spent)")
    
    -- Update display
    self:UpdateTalentDisplay()
end

-- ============================================================
-- Import/Export
-- ============================================================

function TalentManager:ExportToURL(templateName, site)
    local template = templateName and self:GetTemplate(templateName) or { talents = GetCurrentTalents() }
    local class = template.class or template.talents.class or GetPlayerClass()
    
    site = site or "wowhead"
    
    if site == "wowhead" then
        return EncodeWowhead(template.talents, class)
    elseif site == "wotlkdb" or site == "evowow" then
        return EncodeWotlkdb(template.talents, class)
    elseif site == "talented" then
        return EncodeTalented(template.talents, class)
    end
    
    return EncodeWowhead(template.talents, class)
end

function TalentManager:ExportToString(templateName)
    local template = templateName and self:GetTemplate(templateName) or { 
        talents = GetCurrentTalents(),
        name = "Current"
    }
    local class = template.class or template.talents.class or GetPlayerClass()
    
    return class .. ":" .. (template.name or "Unnamed") .. ":" .. EncodeTalentsSimple(template.talents)
end

function TalentManager:ImportFromString(importStr)
    -- Try DC format: CLASS:NAME:TALENTS
    local parts = { strsplit(":", importStr) }
    if #parts >= 3 then
        local class = parts[1]
        local name = parts[2]
        local encoded = parts[3]
        
        if class ~= GetPlayerClass() then
            return false, "Wrong class (expected " .. GetPlayerClass() .. ", got " .. class .. ")"
        end
        
        local talents = DecodeTalentsSimple(encoded)
        talents.class = class
        
        return self:CreateTemplate(name, talents)
    end
    
    -- Try URL format
    local talents = ParseURL(importStr)
    if talents then
        if talents.class ~= GetPlayerClass() then
            return false, "Wrong class"
        end
        return self:CreateTemplate("Imported " .. date("%H:%M:%S"), talents)
    end
    
    -- Try Talented code
    local decoded = DecodeTalented(importStr)
    if decoded then
        if decoded.class ~= GetPlayerClass() then
            return false, "Wrong class"
        end
        return self:CreateTemplate("Imported " .. date("%H:%M:%S"), decoded)
    end
    
    return false, "Could not parse import string"
end

-- ============================================================
-- Inspect Hook
-- ============================================================

function TalentManager:SaveInspection(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
    
    local name = UnitName(unit)
    local _, class = UnitClass(unit)
    if not name or not class then return end
    
    local talents = { class = class }
    
    for tab = 1, SafeGetNumTalentTabs(true) do
        talents[tab] = {}
        local numTalents = SafeGetNumTalents(tab, true)
        for i = 1, numTalents do
            local _, _, _, _, rank = SafeGetTalentInfo(tab, i, true)
            talents[tab][i] = rank or 0
        end
    end
    
    talents.totalPoints = GetTotalPoints(talents)
    
    inspections[name] = {
        name = name,
        class = class,
        talents = talents,
        summary = GetPointSummary(talents),
        time = time(),
    }
    
    addon:Print("Saved inspection: " .. name .. " (" .. class .. " " .. GetPointSummary(talents) .. ")")
    
    return inspections[name]
end

function TalentManager:GetInspection(name)
    return inspections[name]
end

function TalentManager:GetInspectionList()
    local list = {}
    for name, data in pairs(inspections) do
        table.insert(list, {
            name = name,
            class = data.class,
            summary = data.summary,
            time = data.time,
        })
    end
    table.sort(list, function(a, b) return (a.time or 0) > (b.time or 0) end)
    return list
end

function TalentManager:SaveInspectionAsTemplate(inspectName)
    local inspection = inspections[inspectName]
    if not inspection then
        return false, "Inspection not found"
    end
    
    if inspection.class ~= GetPlayerClass() then
        return false, "Wrong class (this is a " .. inspection.class .. " build)"
    end
    
    return self:CreateTemplate(inspectName .. "'s build", inspection.talents)
end

-- ============================================================
-- Whisper Send/Receive
-- ============================================================

local COMM_PREFIX = "DCQOS_TM"

function TalentManager:SendTemplateToPlayer(templateName, targetPlayer)
    if not targetPlayer or targetPlayer == "" then return false end
    
    local template = self:GetTemplate(templateName)
    if not template then
        template = { talents = GetCurrentTalents(), name = "Current" }
    end
    
    local msg = COMM_PREFIX .. ":" .. self:ExportToString(templateName)
    
    -- Use addon channel if available, otherwise whisper
    if ChatThrottleLib and ChatThrottleLib.SendAddonMessage then
        ChatThrottleLib:SendAddonMessage("NORMAL", COMM_PREFIX, msg, "WHISPER", targetPlayer)
    else
        SendAddonMessage(COMM_PREFIX, msg, "WHISPER", targetPlayer)
    end
    
    addon:Print("Sent template to " .. targetPlayer)
    return true
end

function TalentManager:OnAddonMessage(prefix, msg, channel, sender)
    if prefix ~= COMM_PREFIX then return end
    if sender == UnitName("player") then return end
    
    -- Parse: DCQOS_TM:CLASS:NAME:TALENTS
    local data = msg:gsub("^" .. COMM_PREFIX .. ":", "")
    local parts = { strsplit(":", data) }
    
    if #parts >= 3 then
        local class = parts[1]
        local name = parts[2]
        local encoded = parts[3]
        
        -- Show confirmation dialog
        StaticPopupDialogs["DCQOS_RECEIVE_TEMPLATE"] = StaticPopupDialogs["DCQOS_RECEIVE_TEMPLATE"] or {
            text = "%s sent you a %s talent template: %s\n\nSave it?",
            button1 = ACCEPT,
            button2 = CANCEL,
            OnAccept = function(self, data)
                if data.class == GetPlayerClass() then
                    local talents = DecodeTalentsSimple(data.encoded)
                    talents.class = data.class
                    TalentManager:CreateTemplate(data.name .. " (from " .. data.sender .. ")", talents)
                else
                    addon:Print("Cannot save: wrong class (" .. data.class .. ")")
                end
            end,
            timeout = 60,
            whileDead = 1,
            hideOnEscape = 1,
        }
        
        local dialog = StaticPopup_Show("DCQOS_RECEIVE_TEMPLATE", sender, class, name)
        if dialog then
            dialog.data = {
                sender = sender,
                class = class,
                name = name,
                encoded = encoded,
            }
        end
    end
end

-- ============================================================
-- Glyph Management
-- ============================================================

function TalentManager:EnsureGlyphUI()
    -- WotLK may not have glyph APIs available until the Blizzard UI is loaded.
    if GetNumGlyphSockets and GetGlyphSocketInfo then
        return true
    end

    local loader = UIParentLoadAddOn or LoadAddOn
    if loader then
        pcall(loader, "Blizzard_TalentUI")
        pcall(loader, "Blizzard_GlyphUI")
    end

    return GetNumGlyphSockets ~= nil and GetGlyphSocketInfo ~= nil
end

function TalentManager:GetCurrentGlyphs(talentGroup)
    local glyphs = { major = {}, minor = {} }
    talentGroup = talentGroup or SafeGetActiveTalentGroup()

    -- We keep a stable 1..3 index per type so the UI can always render 3 slots
    -- even if some are empty/locked.
    local majorIndex, minorIndex = 0, 0

    for i = 1, SafeGetNumGlyphSockets() do
        local enabled, glyphType, glyphSpellId, socketIcon = SafeGetGlyphSocketInfo(i, talentGroup)
        local name, _, spellIcon
        if glyphSpellId then
            name, _, spellIcon = GetSpellInfo(glyphSpellId)
        end

        local glyphData = {
            socket = i,
            enabled = enabled and true or false,
            glyphType = glyphType,
            spellId = glyphSpellId,
            name = name,
            icon = socketIcon or spellIcon,
        }

        if glyphType == 1 then
            majorIndex = majorIndex + 1
            if majorIndex <= 3 then
                glyphs.major[majorIndex] = glyphData
            end
        elseif glyphType == 2 then
            minorIndex = minorIndex + 1
            if minorIndex <= 3 then
                glyphs.minor[minorIndex] = glyphData
            end
        end
    end
    
    return glyphs
end

function TalentManager:GetAvailableGlyphs()
    local available = { major = {}, minor = {} }
    
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local itemId = tonumber(itemLink:match("item:(%d+)"))
                if itemId then
                    local name, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
                    if itemType == "Glyph" or (itemSubType and itemSubType:find("Glyph")) then
                        local glyphData = {
                            itemId = itemId,
                            itemLink = itemLink,
                            name = name,
                            bag = bag,
                            slot = slot,
                        }
                        if itemLink:find("Major") or (itemSubType and itemSubType:find("Major")) then
                            table.insert(available.major, glyphData)
                        else
                            table.insert(available.minor, glyphData)
                        end
                    end
                end
            end
        end
    end
    
    return available
end

-- ============================================================
-- Dual Spec Support
-- ============================================================

function TalentManager:GetActiveSpec()
    return SafeGetActiveTalentGroup()
end

function TalentManager:GetNumSpecs()
    return SafeGetNumTalentGroups()
end

function TalentManager:SwitchSpec(specIndex)
    if specIndex <= self:GetNumSpecs() then
        if not SafeSetActiveTalentGroup(specIndex) then return false end
        addon:Print("Switched to spec " .. specIndex)
        return true
    end
    return false
end

function TalentManager:BackupCurrentSpec()
    local settings = addon.settings.talentManager
    if not settings.autoBackup then return end
    
    local specIndex = self:GetActiveSpec()
    local backupName = "_Backup_Spec" .. specIndex .. "_" .. date("%Y%m%d_%H%M%S")
    
    self:CreateTemplate(backupName, GetCurrentTalents())
end

-- ============================================================
-- UI: Drawing Lines (Prerequisites)
-- ============================================================

local linePool = {}

local function GetLine(parent)
    local line = table.remove(linePool)
    if not line then
        line = parent:CreateTexture(nil, "ARTWORK")
        line:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    line:SetParent(parent)
    line:Show()
    return line
end

local function ReleaseLine(line)
    line:Hide()
    line:ClearAllPoints()
    table.insert(linePool, line)
end

local function DrawPrereqLine(parent, fromButton, toButton, color)
    if not fromButton or not toButton then return nil end
    if not parent:IsVisible() then return nil end
    
    local lines = {}
    
    -- Get button centers
    local fromX = fromButton:GetLeft() and (fromButton:GetLeft() + TALENT_BUTTON_SIZE / 2) or nil
    local fromY = fromButton:GetTop() and (fromButton:GetTop() - TALENT_BUTTON_SIZE / 2) or nil
    local toX = toButton:GetLeft() and (toButton:GetLeft() + TALENT_BUTTON_SIZE / 2) or nil
    local toY = toButton:GetTop() and (toButton:GetTop() - TALENT_BUTTON_SIZE / 2) or nil
    
    if not fromX or not fromY or not toX or not toY then return nil end
    
    local parentLeft = parent:GetLeft() or 0
    local parentTop = parent:GetTop() or 0
    
    -- Convert to parent-relative coords
    local x1 = fromX - parentLeft
    local y1 = parentTop - fromY - TALENT_BUTTON_SIZE / 2  -- Bottom of prereq button
    local x2 = toX - parentLeft
    local y2 = parentTop - toY + TALENT_BUTTON_SIZE / 2  -- Top of target button
    
    -- Draw vertical line from bottom of prereq down
    local vLine1 = GetLine(parent)
    local midY = (y1 + y2) / 2
    vLine1:SetSize(4, math.abs(midY - y1))
    vLine1:SetPoint("TOPLEFT", parent, "TOPLEFT", x1 - 2, -y1)
    vLine1:SetVertexColor(color.r, color.g, color.b, color.a or 1)
    table.insert(lines, vLine1)
    
    -- If columns differ, draw horizontal connector
    if math.abs(x1 - x2) > 4 then
        local hLine = GetLine(parent)
        hLine:SetSize(math.abs(x2 - x1) + 4, 4)
        hLine:SetPoint("TOPLEFT", parent, "TOPLEFT", math.min(x1, x2) - 2, -midY)
        hLine:SetVertexColor(color.r, color.g, color.b, color.a or 1)
        table.insert(lines, hLine)
    end
    
    -- Draw vertical line to top of target
    local vLine2 = GetLine(parent)
    vLine2:SetSize(4, math.abs(y2 - midY))
    vLine2:SetPoint("TOPLEFT", parent, "TOPLEFT", x2 - 2, -midY)
    vLine2:SetVertexColor(color.r, color.g, color.b, color.a or 1)
    table.insert(lines, vLine2)
    
    return lines
end

-- ============================================================
-- UI Constants
-- ============================================================

local TALENT_BUTTON_SIZE = 40
local TALENT_SPACING_X = 52
local TALENT_SPACING_Y = 52
local TREE_WIDTH = 250
local TREE_HEIGHT = 560
local TREE_TOP_OFFSET = 35

-- ============================================================
-- UI: Talent Button Visual Update
-- ============================================================

local function UpdateTalentButtonVisual(button, state, currentRank, maxRank, targetRank)
    if not button then return end
    
    -- Blizzard's exact logic from TalentFrameBase.lua
    local prereqsSet = (state ~= "locked")
    local displayRank = currentRank or 0
    
    -- Update rank display (Blizzard shows rank in the corner border)
    if displayRank > 0 then
        if button.rankText then
            button.rankText:SetText(displayRank)
            button.rankText:Show()
        end
        if button.rankBorder then
            button.rankBorder:Show()
        end
    else
        if button.rankText then
            button.rankText:Hide()
        end
        if button.rankBorder then
            button.rankBorder:Hide()
        end
    end
    
    -- Always show the slot border (Blizzard style)
    if button.slot then
        button.slot:Show()
    end
    
    if prereqsSet then
        -- Prerequisites met: NOT desaturated, full color icon
        SetTalentButtonDesaturated(button, false)
        
        if displayRank > 0 and displayRank >= maxRank then
            -- Maxed out: GOLD border
            if button.slot then
                button.slot:SetVertexColor(1, 0.82, 0)
            end
            if button.rankText then
                button.rankText:SetTextColor(1, 0.82, 0)
            end
            if button.rankBorder then
                button.rankBorder:SetVertexColor(1, 0.82, 0)
            end
        else
            -- Available (with or without points): GREEN border
            if button.slot then
                button.slot:SetVertexColor(0.1, 1, 0.1)
            end
            if button.rankText then
                button.rankText:SetTextColor(0.1, 1, 0.1)
            end
            if button.rankBorder then
                button.rankBorder:SetVertexColor(0.1, 1, 0.1)
            end
        end
    else
        -- Prerequisites NOT met: desaturated with no colored border
        SetTalentButtonDesaturated(button, true, 0.65, 0.65, 0.65)
        
        if button.slot then
            button.slot:SetVertexColor(0.3, 0.3, 0.3)
        end
        
        if displayRank > 0 then
            if button.rankText then
                button.rankText:SetTextColor(0.5, 0.5, 0.5)
            end
            if button.rankBorder then
                button.rankBorder:SetVertexColor(0.5, 0.5, 0.5)
            end
        end
    end
    
    -- Show target indicator if different from current
    if button.targetIndicator then
        if targetRank and targetRank ~= currentRank then
            button.targetIndicator:Show()
            local diff = targetRank - currentRank
            if diff > 0 then
                button.targetIndicator:SetVertexColor(0, 1, 0)
                if button.targetText then
                    button.targetText:SetText("+" .. diff)
                    button.targetText:SetTextColor(0, 1, 0)
                end
            else
                button.targetIndicator:SetVertexColor(1, 0, 0)
                if button.targetText then
                    button.targetText:SetText(tostring(diff))
                    button.targetText:SetTextColor(1, 0, 0)
                end
            end
        else
            button.targetIndicator:Hide()
            if button.targetText then
                button.targetText:SetText("")
            end
        end
    end
end

-- ============================================================
-- UI: Create Talent Button
-- ============================================================

local function CreateTalentButton(parent, tab, index, pet)
    local name, iconPath, tier, column, currentRank, maxRank, _, prereqTab, prereqTalent = SafeGetTalentInfo(tab, index, nil, pet)
    if not name then return nil end
    
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(TALENT_BUTTON_SIZE, TALENT_BUTTON_SIZE)
    
    -- Icon texture (main artwork)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(TALENT_BUTTON_SIZE, TALENT_BUTTON_SIZE)
    icon:SetPoint("CENTER")
    local normalizedPath = NormalizeTalentIconPath(iconPath)
    if normalizedPath then
        icon:SetTexture(normalizedPath)
    else
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetVertexColor(1, 1, 1)
    button.icon = icon
    
    -- Slot border (colored frame around the icon - at the edges)
    local slot = button:CreateTexture(nil, "OVERLAY")
    slot:SetSize(TALENT_BUTTON_SIZE + 8, TALENT_BUTTON_SIZE + 8)
    slot:SetPoint("CENTER")
    slot:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    slot:SetVertexColor(0.4, 0.4, 0.4)  -- Gray by default
    button.slot = slot
    
    -- Rank border (small circle behind rank text)
    local rankBorder = button:CreateTexture(nil, "OVERLAY")
    rankBorder:SetSize(18, 18)
    rankBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
    rankBorder:SetTexture("Interface\\TalentFrame\\TalentFrame-RankBorder")
    rankBorder:Hide()
    button.rankBorder = rankBorder
    
    -- Rank text
    local rankText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rankText:SetPoint("CENTER", rankBorder, "CENTER", 0, 0)
    button.rankText = rankText
    
    -- Highlight texture (on mouseover)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(TALENT_BUTTON_SIZE, TALENT_BUTTON_SIZE)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    button.highlight = highlight
    
    -- Pushed texture (when clicking)
    local pushed = button:CreateTexture(nil, "OVERLAY")
    pushed:SetSize(TALENT_BUTTON_SIZE, TALENT_BUTTON_SIZE)
    pushed:SetPoint("CENTER")
    pushed:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    pushed:Hide()
    button.pushed = pushed
    
    -- Target indicator (for diff view)
    local targetIndicator = button:CreateTexture(nil, "OVERLAY")
    targetIndicator:SetSize(14, 14)
    targetIndicator:SetPoint("TOPRIGHT", 3, 3)
    targetIndicator:SetTexture("Interface\\BUTTONS\\UI-GroupLoot-Coin-Up")
    targetIndicator:Hide()
    button.targetIndicator = targetIndicator
    
    local targetText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    targetText:SetPoint("TOP", button, "TOP", 0, 12)
    targetText:SetText("")
    button.targetText = targetText
    
    -- Store data
    button.tab = tab
    button.index = index
    button.name = name
    button.maxRank = maxRank
    button.currentRank = currentRank
    button.tier = tier
    button.column = column
    button.prereqTab = prereqTab
    button.prereqTalent = prereqTalent
    button.pet = pet
    
    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetTalent(self.tab, self.index, nil, self.pet)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Push/release visual effects
    button:SetScript("OnMouseDown", function(self)
        if self.icon then
            self.icon:SetPoint("CENTER", 1, -1)
        end
        if self.pushed then
            self.pushed:Show()
        end
    end)
    
    button:SetScript("OnMouseUp", function(self)
        if self.icon then
            self.icon:SetPoint("CENTER", 0, 0)
        end
        if self.pushed then
            self.pushed:Hide()
        end
    end)
    
    -- Click handling
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, mouseButton)
        if IsShiftKeyDown() then
            -- Link to chat
            local link = GetTalentLink(self.tab, self.index, nil, self.pet)
            if link then
                ChatEdit_InsertLink(link)
            end
        elseif currentMode == "apply" or mouseButton == "LeftButton" then
            -- Learn talent
            LearnTalent(self.tab, self.index, self.pet)
            TalentManager:UpdateTalentDisplay()
        end
    end)
    
    return button
end

-- ============================================================
-- UI: Create Tree Frame
-- ============================================================

local function CreateTalentTreeFrame(parent, tab, pet)
    local treeNames = GetTreeNames()
    local treeIcons = GetTreeIcons()
    local treeData = GetTreeData()
    
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(TREE_WIDTH, TREE_HEIGHT + TREE_TOP_OFFSET)
    
    -- Tree background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 0, -TREE_TOP_OFFSET)
    bg:SetPoint("BOTTOMRIGHT")
    if treeData and treeData.backgrounds and treeData.backgrounds[tab] then
        bg:SetTexture("Interface\\TalentFrame\\" .. treeData.backgrounds[tab])
        bg:SetAlpha(0.25)
    else
        bg:SetTexture(BG_FELLEATHER)
        bg:SetAlpha(0.20)
    end
    frame.bg = bg
    
    -- Tree icon
    local treeIcon = frame:CreateTexture(nil, "ARTWORK")
    treeIcon:SetSize(22, 22)
    treeIcon:SetPoint("TOPLEFT", 4, -4)
    if treeIcons[tab] then
        treeIcon:SetTexture("Interface\\Icons\\" .. treeIcons[tab])
    end
    frame.treeIcon = treeIcon
    
    -- Tree title
    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("LEFT", treeIcon, "RIGHT", 4, 0)
    title:SetText(treeNames[tab] or "Tree " .. tab)
    frame.title = title
    
    -- Point counter
    local points = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    points:SetPoint("TOPRIGHT", -4, -8)
    points:SetText("0 pts")
    frame.pointsText = points
    
    -- Talent buttons container - starts below header
    local container = CreateFrame("Frame", nil, frame)
    container:SetPoint("TOPLEFT", 8, -(TREE_TOP_OFFSET + 2))
    container:SetPoint("BOTTOMRIGHT", -8, 5)
    frame.container = container
    
    frame.talentButtons = {}
    frame.prereqLines = {}
    frame.tab = tab
    frame.pet = pet
    
    return frame
end

-- ============================================================
-- UI: Main Frame
-- ============================================================

function TalentManager:CreateMainFrame()
    if mainFrame then return mainFrame end
    
    local settings = addon.settings.talentManager
    
    local frame = CreateFrame("Frame", "DCQoSTalentManagerFrame", UIParent)
    frame:SetSize(820, 720)
    frame:SetPoint("CENTER", 50, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not settings.lockFrame then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        settings.framePos = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    frame:Hide()
    
    -- Background
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    local bgTex = frame:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints(frame)
    bgTex:SetTexture(BG_FELLEATHER)
    bgTex:SetAlpha(0.35)
    frame.bgTex = bgTex
    
    -- Title
    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("DC-QoS Talent Manager")
    frame.title = title
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    
    -- Spec tabs
    local specTabs = CreateFrame("Frame", nil, frame)
    specTabs:SetPoint("TOPLEFT", 15, -40)
    specTabs:SetSize(200, 25)
    frame.specTabs = specTabs
    
    for i = 1, 2 do
        local specBtn = CreateFrame("Button", nil, specTabs, "UIPanelButtonTemplate")
        specBtn:SetSize(80, 22)
        specBtn:SetPoint("LEFT", (i-1) * 85, 0)
        specBtn:SetText("Spec " .. i)
        specBtn:SetScript("OnClick", function()
            TalentManager:SwitchSpec(i)
        end)
        frame["specBtn" .. i] = specBtn
    end
    
    -- Active spec indicator
    local specLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    specLabel:SetPoint("LEFT", specTabs, "RIGHT", 10, 0)
    specLabel:SetText("Active: Spec 1")
    frame.specLabel = specLabel
    
    -- Point summary
    local pointSummary = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    pointSummary:SetPoint("TOPRIGHT", -20, -15)
    pointSummary:SetText("0/0/0")
    frame.pointSummary = pointSummary
    
    local unspentText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    unspentText:SetPoint("TOP", pointSummary, "BOTTOM", 0, -2)
    unspentText:SetText("0 unspent")
    frame.unspentText = unspentText
    
    -- Talent trees container
    local treesFrame = CreateFrame("Frame", nil, frame)
    treesFrame:SetPoint("TOPLEFT", 8, -65)
    treesFrame:SetPoint("RIGHT", -8, 0)
    treesFrame:SetHeight(TREE_HEIGHT + TREE_TOP_OFFSET)
    frame.treesFrame = treesFrame
    
    -- Create 3 tree frames
    frame.trees = {}
    local treeGap = 4
    local totalTreesWidth = (TREE_WIDTH * 3) + (treeGap * 2)
    local availableWidth = frame:GetWidth() - 16 -- left+right padding
    local startX = 0
    if availableWidth and totalTreesWidth and availableWidth > totalTreesWidth then
        startX = math.floor(((availableWidth - totalTreesWidth) / 2) + 0.5)
    end
    for tab = 1, 3 do
        local tree = CreateTalentTreeFrame(treesFrame, tab)
        tree:SetPoint("TOPLEFT", treesFrame, "TOPLEFT", startX + (tab - 1) * (TREE_WIDTH + treeGap), 0)
        frame.trees[tab] = tree
    end
    
    -- Bottom panel
    local bottomPanel = CreateFrame("Frame", nil, frame)
    bottomPanel:SetPoint("BOTTOMLEFT", 10, 12)
    bottomPanel:SetPoint("BOTTOMRIGHT", -10, 12)
    bottomPanel:SetHeight(85)
    frame.bottomPanel = bottomPanel
    
    -- Template dropdown
    local templateLabel = bottomPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    templateLabel:SetPoint("TOPLEFT", 0, -5)
    templateLabel:SetText("Templates:")
    
    local templateDropdown = CreateFrame("Frame", "DCQoSTalentTemplateDropdown", bottomPanel, "UIDropDownMenuTemplate")
    templateDropdown:SetPoint("TOPLEFT", templateLabel, "BOTTOMLEFT", -15, 0)
    UIDropDownMenu_SetWidth(templateDropdown, 140)
    frame.templateDropdown = templateDropdown
    
    -- Buttons row 1
    local saveBtn = CreateFrame("Button", nil, bottomPanel, "UIPanelButtonTemplate")
    saveBtn:SetSize(50, 22)
    saveBtn:SetPoint("LEFT", templateDropdown, "RIGHT", -5, 2)
    saveBtn:SetText("Save")
    saveBtn:SetScript("OnClick", function()
        StaticPopupDialogs["DCQOS_SAVE_TEMPLATE"] = {
            text = "Enter template name:",
            hasEditBox = 1,
            button1 = ACCEPT,
            button2 = CANCEL,
            OnAccept = function(self)
                local name = self.editBox:GetText()
                if name and name ~= "" then
                    TalentManager:CreateTemplate(name)
                    TalentManager:UpdateTemplateDropdown()
                end
            end,
            EditBoxOnEnterPressed = function(self)
                local parent = self:GetParent()
                StaticPopupDialogs["DCQOS_SAVE_TEMPLATE"].OnAccept(parent)
                parent:Hide()
            end,
            EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
            timeout = 0, whileDead = 1, hideOnEscape = 1,
        }
        StaticPopup_Show("DCQOS_SAVE_TEMPLATE")
    end)
    
    local loadBtn = CreateFrame("Button", nil, bottomPanel, "UIPanelButtonTemplate")
    loadBtn:SetSize(50, 22)
    loadBtn:SetPoint("LEFT", saveBtn, "RIGHT", 2, 0)
    loadBtn:SetText("Apply")
    loadBtn:SetScript("OnClick", function()
        local selected = UIDropDownMenu_GetSelectedValue(templateDropdown)
        if selected then TalentManager:ApplyTemplate(selected) end
    end)
    
    local copyBtn = CreateFrame("Button", nil, bottomPanel, "UIPanelButtonTemplate")
    copyBtn:SetSize(50, 22)
    copyBtn:SetPoint("LEFT", loadBtn, "RIGHT", 2, 0)
    copyBtn:SetText("Copy")
    copyBtn:SetScript("OnClick", function()
        local selected = UIDropDownMenu_GetSelectedValue(templateDropdown)
        if selected then
            TalentManager:CopyTemplate(selected)
            TalentManager:UpdateTemplateDropdown()
        end
    end)
    
    local deleteBtn = CreateFrame("Button", nil, bottomPanel, "UIPanelButtonTemplate")
    deleteBtn:SetSize(50, 22)
    deleteBtn:SetPoint("LEFT", copyBtn, "RIGHT", 2, 0)
    deleteBtn:SetText("Delete")
    deleteBtn:SetScript("OnClick", function()
        local selected = UIDropDownMenu_GetSelectedValue(templateDropdown)
        if selected then
            TalentManager:DeleteTemplate(selected)
            TalentManager:UpdateTemplateDropdown()
        end
    end)
    
    local targetBtn = CreateFrame("Button", nil, bottomPanel, "UIPanelButtonTemplate")
    targetBtn:SetSize(50, 22)
    targetBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 2, 0)
    targetBtn:SetText("Target")
    targetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Set as comparison target")
        GameTooltip:AddLine("Shows difference between current and template", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    targetBtn:SetScript("OnLeave", GameTooltip_Hide)
    targetBtn:SetScript("OnClick", function()
        local selected = UIDropDownMenu_GetSelectedValue(templateDropdown)
        if selected then
            local template = TalentManager:GetTemplate(selected)
            if template then
                targetTemplate = template
                TalentManager:UpdateTalentDisplay()
                addon:Print("Target set: " .. selected)
            end
        else
            targetTemplate = nil
            TalentManager:UpdateTalentDisplay()
        end
    end)
    
    -- Row 2
    local exportBtn = CreateFrame("Button", nil, bottomPanel, "UIPanelButtonTemplate")
    exportBtn:SetSize(50, 22)
    exportBtn:SetPoint("TOPLEFT", templateDropdown, "BOTTOMLEFT", 15, -2)
    exportBtn:SetText("Export")
    exportBtn:SetScript("OnClick", function()
        local selected = UIDropDownMenu_GetSelectedValue(templateDropdown)
        local str = TalentManager:ExportToString(selected)
        TalentManager:ShowExportDialog(str, "Template String")
    end)
    
    local importBtn = CreateFrame("Button", nil, bottomPanel, "UIPanelButtonTemplate")
    importBtn:SetSize(50, 22)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 2, 0)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function() TalentManager:ShowImportDialog() end)
    
    local urlBtn = CreateFrame("Button", nil, bottomPanel, "UIPanelButtonTemplate")
    urlBtn:SetSize(60, 22)
    urlBtn:SetPoint("LEFT", importBtn, "RIGHT", 2, 0)
    urlBtn:SetText("WoWHead")
    urlBtn:SetScript("OnClick", function()
        local selected = UIDropDownMenu_GetSelectedValue(templateDropdown)
        local url = TalentManager:ExportToURL(selected, "wowhead")
        TalentManager:ShowExportDialog(url, "WoWHead URL")
    end)
    
    local sendBtn = CreateFrame("Button", nil, bottomPanel, "UIPanelButtonTemplate")
    sendBtn:SetSize(50, 22)
    sendBtn:SetPoint("LEFT", urlBtn, "RIGHT", 2, 0)
    sendBtn:SetText("Send")
    sendBtn:SetScript("OnClick", function()
        StaticPopupDialogs["DCQOS_SEND_TEMPLATE"] = {
            text = "Enter player name:",
            hasEditBox = 1, button1 = ACCEPT, button2 = CANCEL,
            OnAccept = function(self)
                local target = self.editBox:GetText()
                if target and target ~= "" then
                    local selected = UIDropDownMenu_GetSelectedValue(mainFrame.templateDropdown)
                    TalentManager:SendTemplateToPlayer(selected, target)
                end
            end,
            EditBoxOnEnterPressed = function(self)
                local parent = self:GetParent()
                StaticPopupDialogs["DCQOS_SEND_TEMPLATE"].OnAccept(parent)
                parent:Hide()
            end,
            EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
            timeout = 0, whileDead = 1, hideOnEscape = 1,
        }
        StaticPopup_Show("DCQOS_SEND_TEMPLATE")
    end)
    
    -- Inspect dropdown
    local inspectDropdown = CreateFrame("Frame", "DCQoSInspectDropdown", bottomPanel, "UIDropDownMenuTemplate")
    inspectDropdown:SetPoint("LEFT", sendBtn, "RIGHT", -10, 0)
    UIDropDownMenu_SetWidth(inspectDropdown, 80)
    UIDropDownMenu_SetText(inspectDropdown, "Inspects")
    frame.inspectDropdown = inspectDropdown
    
    -- Glyph button
    local glyphBtn = CreateFrame("Button", nil, bottomPanel, "UIPanelButtonTemplate")
    glyphBtn:SetSize(55, 22)
    glyphBtn:SetPoint("LEFT", inspectDropdown, "RIGHT", -5, 2)
    glyphBtn:SetText("Glyphs")
    glyphBtn:SetScript("OnClick", function() TalentManager:ToggleGlyphFrame() end)
    
    mainFrame = frame
    tinsert(UISpecialFrames, "DCQoSTalentManagerFrame")
    
    -- Restore position
    if settings.framePos and settings.framePos.point then
        frame:ClearAllPoints()
        frame:SetPoint(settings.framePos.point, UIParent, settings.framePos.relPoint,
                       settings.framePos.x, settings.framePos.y)
    end
    
    frame:SetScale(settings.frameScale or 1)
    
    return frame
end

function TalentManager:AnchorToTalentFrame()
    if not mainFrame then return end
    if PlayerTalentFrame and PlayerTalentFrame:IsShown() then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("TOPLEFT", PlayerTalentFrame, "TOPRIGHT", 10, -30)
    elseif addon.settings.talentManager.framePos and addon.settings.talentManager.framePos.point then
        local pos = addon.settings.talentManager.framePos
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER")
    end
end

function TalentManager:FindTalentFrameRightAnchor(excludeButton)
    if not PlayerTalentFrame or not PlayerTalentFrame.GetChildren then return nil end

    local parentRight = PlayerTalentFrame:GetRight()
    if not parentRight then return nil end

    local bestFrame = nil
    local bestBottom = nil

    local function Consider(frame)
        if not frame or frame == excludeButton then return end
        if not frame.IsShown or not frame:IsShown() then return end
        if frame.GetObjectType and frame:GetObjectType() ~= "Button" then return end

        local w = frame.GetWidth and frame:GetWidth() or 0
        local h = frame.GetHeight and frame:GetHeight() or 0
        if w < 20 or w > 48 or h < 20 or h > 48 then return end

        local right = frame.GetRight and frame:GetRight()
        local bottom = frame.GetBottom and frame:GetBottom()
        if not right or not bottom then return end
        if math.abs(right - parentRight) > 45 then return end

        if not bestBottom or bottom < bestBottom then
            bestBottom = bottom
            bestFrame = frame
        end
    end

    local children = { PlayerTalentFrame:GetChildren() }
    for _, child in ipairs(children) do
        Consider(child)
    end

    return bestFrame
end

function TalentManager:PositionTalentFrameButton(button)
    if not button or not PlayerTalentFrame then return end
    button:ClearAllPoints()
    -- Position below the spec tabs on the right side
    local specTab2 = _G["PlayerSpecTab2"]
    if specTab2 and specTab2:IsShown() then
        button:SetPoint("TOP", specTab2, "BOTTOM", 0, -15)
        return
    end
    local specTab1 = _G["PlayerSpecTab1"] 
    if specTab1 and specTab1:IsShown() then
        button:SetPoint("TOP", specTab1, "BOTTOM", 0, -55)
        return
    end
    -- Fallback: position on right side below close button
    button:SetPoint("TOPRIGHT", PlayerTalentFrame, "TOPRIGHT", -8, -90)
end

function TalentManager:ShowExportDialog(text, title)
    StaticPopupDialogs["DCQOS_EXPORT_TEMPLATE"] = {
        text = (title or "Export") .. ":",
        hasEditBox = 1,
        button1 = OKAY,
        OnShow = function(self)
            self.editBox:SetText(self.data or "")
            self.editBox:HighlightText()
            self.editBox:SetFocus()
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0, whileDead = 1, hideOnEscape = 1,
    }
    
    local dialog = StaticPopup_Show("DCQOS_EXPORT_TEMPLATE")
    if dialog then
        dialog.data = text
        dialog.editBox:SetText(text)
        dialog.editBox:HighlightText()
    end
end

function TalentManager:ShowImportDialog()
    StaticPopupDialogs["DCQOS_IMPORT_TEMPLATE"] = {
        text = "Paste template string or URL:",
        hasEditBox = 1,
        button1 = ACCEPT, button2 = CANCEL,
        OnAccept = function(self)
            local str = self.editBox:GetText()
            if str and str ~= "" then
                local success, msg = TalentManager:ImportFromString(str)
                if success then
                    TalentManager:UpdateTemplateDropdown()
                else
                    addon:Print("Import failed: " .. (msg or "unknown"))
                end
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            StaticPopupDialogs["DCQOS_IMPORT_TEMPLATE"].OnAccept(parent)
            parent:Hide()
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0, whileDead = 1, hideOnEscape = 1,
    }
    StaticPopup_Show("DCQOS_IMPORT_TEMPLATE")
end

function TalentManager:UpdateTemplateDropdown()
    local dropdown = mainFrame and mainFrame.templateDropdown
    if not dropdown then return end
    
    local templateList = self:GetTemplateList()
    
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        
        info.text = "-- Current --"
        info.value = nil
        info.func = function()
            UIDropDownMenu_SetSelectedValue(dropdown, nil)
            UIDropDownMenu_SetText(dropdown, "Current")
            targetTemplate = nil
            TalentManager:UpdateTalentDisplay()
        end
        UIDropDownMenu_AddButton(info)
        
        for _, template in ipairs(templateList) do
            info.text = template.name .. " (" .. template.summary .. ")"
            info.value = template.name
            info.func = function()
                UIDropDownMenu_SetSelectedValue(dropdown, template.name)
                UIDropDownMenu_SetText(dropdown, template.name)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    UIDropDownMenu_SetText(dropdown, "Select Template")
end

function TalentManager:UpdateInspectDropdown()
    local dropdown = mainFrame and mainFrame.inspectDropdown
    if not dropdown then return end
    
    local inspectList = self:GetInspectionList()
    
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        
        if #inspectList == 0 then
            info.text = "No inspections"
            info.disabled = true
            UIDropDownMenu_AddButton(info)
            return
        end
        
        for _, insp in ipairs(inspectList) do
            info.text = insp.name .. " (" .. insp.class .. ")"
            info.value = insp.name
            info.func = function()
                TalentManager:SaveInspectionAsTemplate(insp.name)
                TalentManager:UpdateTemplateDropdown()
            end
            info.tooltipTitle = insp.name
            info.tooltipText = insp.class .. " " .. insp.summary .. "\nClick to save as template"
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    UIDropDownMenu_SetText(dropdown, "Inspects")
end

function TalentManager:UpdateTalentDisplay()
    if not mainFrame or not mainFrame:IsShown() then return end
    
    local current = GetCurrentTalents()
    local talentGroup = SafeGetActiveTalentGroup(nil, nil)
    
    for tab = 1, 3 do
        local tree = mainFrame.trees[tab]
        if tree then
            local points = GetTreePoints(current, tab)
            tree.pointsText:SetText(points .. " pts")
            
            -- Clear old lines
            for _, lines in pairs(tree.prereqLines or {}) do
                for _, line in ipairs(lines) do
                    ReleaseLine(line)
                end
            end
            tree.prereqLines = {}
            
            -- Update buttons and draw lines
            for i, button in pairs(tree.talentButtons) do
                if button then
                    local currentRank = current[tab] and current[tab][i] or 0
                    local targetRank = targetTemplate and targetTemplate.talents and 
                                       targetTemplate.talents[tab] and targetTemplate.talents[tab][i]
                    local state = GetTalentState(current, tab, i)

                    -- Refresh icon display
                    if button.icon then
                        local _, iconPath = SafeGetTalentInfo(tab, i, nil, button.pet, talentGroup)
                        local normalized = NormalizeTalentIconPath(iconPath)
                        if normalized then
                            button.icon:SetTexture(normalized)
                        else
                            button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                        end
                        button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                    end
                    
                    button.currentRank = currentRank
                    UpdateTalentButtonVisual(button, state, currentRank, button.maxRank, targetRank)
                    
                    -- Draw prereq lines using GetTalentPrereqs API
                    local prereqTier, prereqColumn = SafeGetTalentPrereqs(tab, i, nil, button.pet, talentGroup)
                    if prereqTier and prereqColumn then
                        -- Find the prereq button by tier/column
                        for prereqIdx, prereqBtn in pairs(tree.talentButtons) do
                            if prereqBtn.tier == prereqTier and prereqBtn.column == prereqColumn then
                                local color = state ~= "locked" and { r = 1, g = 0.82, b = 0 } or { r = 0.4, g = 0.4, b = 0.4 }
                                local lines = DrawPrereqLine(tree.container, prereqBtn, button, color)
                                if lines then
                                    tree.prereqLines[i] = lines
                                end
                                break
                            end
                        end
                    elseif button.prereqTalent and button.prereqTalent > 0 then
                        -- Fallback to stored prereq index
                        local prereqBtn = tree.talentButtons[button.prereqTalent]
                        if prereqBtn then
                            local color = state ~= "locked" and { r = 1, g = 0.82, b = 0 } or { r = 0.4, g = 0.4, b = 0.4 }
                            local lines = DrawPrereqLine(tree.container, prereqBtn, button, color)
                            if lines then
                                tree.prereqLines[i] = lines
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Update summary
    mainFrame.pointSummary:SetText(GetPointSummary(current))
    local total = GetTotalPoints(current)
    local unspent = SafeGetUnspentTalentPoints()
    mainFrame.unspentText:SetText(unspent .. " unspent (Lvl " .. GetRequiredLevel(total) .. "+)")
    mainFrame.specLabel:SetText("Active: Spec " .. self:GetActiveSpec())
    
    if targetTemplate then
        mainFrame.title:SetText("DC Talent Manager - Target: " .. (targetTemplate.name or "?"))
    else
        mainFrame.title:SetText("DC-QoS Talent Manager")
    end
end

function TalentManager:PopulateTalentTrees(pet)
    if not mainFrame then return end
    
    for tab = 1, 3 do
        local tree = mainFrame.trees[tab]
        if tree then
            for _, button in pairs(tree.talentButtons) do
                button:Hide()
            end
            tree.talentButtons = {}
            
            for _, lines in pairs(tree.prereqLines or {}) do
                for _, line in ipairs(lines) do ReleaseLine(line) end
            end
            tree.prereqLines = {}
            
            local numTalents = SafeGetNumTalents(tab, nil, pet)
            for i = 1, numTalents do
                local button = CreateTalentButton(tree.container, tab, i, pet)
                if button then
                    local x = (button.column - 1) * TALENT_SPACING_X
                    local y = -(button.tier - 1) * TALENT_SPACING_Y
                    button:SetPoint("TOPLEFT", x, y)
                    tree.talentButtons[i] = button
                end
            end
        end
    end
end

-- ============================================================
-- UI: Glyph Frame
-- ============================================================

function TalentManager:CreateGlyphFrame()
    if glyphFrame then return glyphFrame end
    
    local settings = addon.settings.talentManager
    
    local frame = CreateFrame("Frame", "DCQoSGlyphFrame", UIParent)
    frame:SetSize(340, 420)
    frame:SetPoint("CENTER", 360, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not settings.lockFrame then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        settings.glyphFramePos = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    frame:Hide()
    
    -- DC addon standard background (matching talent frame)
    frame:SetBackdrop({
        bgFile = BG_FELLEATHER,
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 256, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
    frame:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Glyphs")
    
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", 2, 2)
    
    -- Spec toggle row
    local specRow = CreateFrame("Frame", nil, frame)
    specRow:SetPoint("TOPLEFT", 15, -30)
    specRow:SetSize(310, 22)
    
    local specToggle = CreateFrame("CheckButton", nil, specRow, "UICheckButtonTemplate")
    specToggle:SetSize(20, 20)
    specToggle:SetPoint("LEFT", 0, 0)
    specToggle.text = specToggle:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    specToggle.text:SetPoint("LEFT", specToggle, "RIGHT", 2, 0)
    specToggle.text:SetText("Alt Spec")
    specToggle:SetScript("OnClick", function(self)
        local group = self:GetChecked() and (3 - TalentManager:GetActiveSpec()) or TalentManager:GetActiveSpec()
        frame.viewingGroup = group
        TalentManager:UpdateGlyphDisplay()
    end)
    frame.viewingGroup = self:GetActiveSpec()
    if TalentManager:GetNumSpecs() < 2 then
        specToggle:Disable()
        specToggle:SetChecked(false)
        specToggle.text:SetText("Single Spec")
    end

    local viewText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    viewText:SetPoint("LEFT", specToggle.text, "RIGHT", 8, 0)
    viewText:SetText("")
    frame.viewText = viewText

    local openBlizz = CreateFrame("Button", nil, specRow, "UIPanelButtonTemplate")
    openBlizz:SetSize(100, 18)
    openBlizz:SetPoint("RIGHT", specRow, "RIGHT", 0, 0)
    openBlizz:SetText("Blizzard UI")
    openBlizz:SetScript("OnClick", function()
        local loader = UIParentLoadAddOn or LoadAddOn
        if loader then
            pcall(loader, "Blizzard_TalentUI")
            pcall(loader, "Blizzard_GlyphUI")
        end
        if ToggleTalentFrame then
            ToggleTalentFrame()
        elseif PlayerTalentFrame and ShowUIPanel then
            ShowUIPanel(PlayerTalentFrame)
        end
        if PlayerTalentFrameTab3 and PlayerTalentFrameTab3.Click then
            PlayerTalentFrameTab3:Click()
        elseif PlayerTalentFrame_OnTabClicked then
            pcall(PlayerTalentFrame_OnTabClicked, PlayerTalentFrame, 3)
        end
    end)

    -- Helper to create a glyph socket (DC addon style)
    local function CreateGlyphSocket(parent, x, y, glyphType, index)
        local slot = CreateFrame("Button", nil, parent)
        slot:SetSize(64, 64)
        slot:SetPoint("CENTER", parent, "CENTER", x, y)
        slot.slotIndex = index
        slot.slotKind = glyphType
        
        -- Background ring (simple circle)
        local background = slot:CreateTexture(nil, "BACKGROUND")
        background:SetSize(70, 70)
        background:SetPoint("CENTER")
        background:SetTexture("Interface\\Minimap\\UI-Minimap-Border")
        background:SetTexCoord(0, 1, 0, 1)
        if glyphType == "major" then
            background:SetVertexColor(1, 0.82, 0, 0.8)  -- Gold for major
        else
            background:SetVertexColor(0.5, 0.7, 1, 0.8)  -- Blue for minor
        end
        slot.background = background
        
        -- Inner socket backdrop
        local socketBg = slot:CreateTexture(nil, "BORDER")
        socketBg:SetSize(58, 58)
        socketBg:SetPoint("CENTER")
        socketBg:SetTexture("Interface\\Buttons\\UI-Quickslot")
        socketBg:SetVertexColor(0.1, 0.1, 0.1, 0.9)
        slot.socketBg = socketBg
        
        -- Glyph icon
        local glyph = slot:CreateTexture(nil, "ARTWORK")
        glyph:SetSize(52, 52)
        glyph:SetPoint("CENTER")
        glyph:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slot.glyph = glyph
        
        -- Border highlight
        local ring = slot:CreateTexture(nil, "OVERLAY")
        ring:SetSize(66, 66)
        ring:SetPoint("CENTER")
        ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        ring:SetBlendMode("ADD")
        if glyphType == "major" then
            ring:SetVertexColor(1, 0.82, 0, 1)
        else
            ring:SetVertexColor(0.5, 0.7, 1, 1)
        end
        slot.ring = ring
        
        -- Shine overlay (for filled sockets)
        local shine = slot:CreateTexture(nil, "OVERLAY")
        shine:SetSize(64, 64)
        shine:SetPoint("CENTER")
        shine:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        shine:SetBlendMode("ADD")
        shine:SetAlpha(0)
        slot.shine = shine
        
        -- Setting/decoration frame
        slot.setting = socketBg  -- Reuse socket background
        
        -- Icon alias for compatibility
        slot.icon = glyph
        
        -- Name label below the socket
        local nameLabel = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameLabel:SetPoint("TOP", slot, "BOTTOM", 0, -2)
        nameLabel:SetWidth(80)
        nameLabel:SetJustifyH("CENTER")
        nameLabel:SetText("")
        slot.nameLabel = nameLabel

        -- Highlight on mouseover
        local highlight = slot:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetSize(64, 64)
        highlight:SetPoint("CENTER")
        highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0.5)
        slot.highlight = highlight
        
        slot:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.glyphData and self.glyphData.spellId then
                if GameTooltip.SetSpellByID then
                    GameTooltip:SetSpellByID(self.glyphData.spellId)
                else
                    GameTooltip:SetHyperlink("spell:" .. tostring(self.glyphData.spellId))
                end
            else
                local typeStr = glyphType == "major" and "|cFFFFD100Major|r" or "|cFF8888FFMinor|r"
                GameTooltip:SetText(typeStr .. " Glyph Slot " .. index)
                GameTooltip:AddLine(self.lockedText or "Empty", 0.7, 0.7, 0.7, true)
            end
            GameTooltip:Show()
        end)
        slot:SetScript("OnLeave", GameTooltip_Hide)
        
        return slot
    end
    
    -- Glyph socket container with Blizzard-like circular layout
    local socketContainer = CreateFrame("Frame", nil, frame)
    socketContainer:SetPoint("TOP", frame, "TOP", 0, -60)
    socketContainer:SetSize(300, 240)
    frame.socketContainer = socketContainer
    
    -- Section labels
    local majorLabel = socketContainer:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    majorLabel:SetPoint("TOP", socketContainer, "TOP", 0, 0)
    majorLabel:SetText("|cFFFFD100Major Glyphs|r")
    
    -- Major glyphs - arranged in a row with wider spacing
    frame.majorSlots = {}
    local majorY = -35
    for i = 1, 3 do
        local xOffset = (i - 2) * 100  -- -100, 0, 100 (wider spacing)
        local slot = CreateGlyphSocket(socketContainer, xOffset, majorY, "major", i)
        frame.majorSlots[i] = slot
    end
    
    local minorLabel = socketContainer:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    minorLabel:SetPoint("TOP", socketContainer, "TOP", 0, -120)
    minorLabel:SetText("|cFF8888FFMinor Glyphs|r")
    
    -- Minor glyphs - arranged in a row below with wider spacing
    frame.minorSlots = {}
    local minorY = -155
    for i = 1, 3 do
        local xOffset = (i - 2) * 100  -- -100, 0, 100 (wider spacing)
        local slot = CreateGlyphSocket(socketContainer, xOffset, minorY, "minor", i)
        frame.minorSlots[i] = slot
    end
    
    -- Divider line
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
    divider:SetSize(280, 16)
    divider:SetPoint("TOP", socketContainer, "BOTTOM", 0, 5)
    
    -- Available in bags section
    local availLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    availLabel:SetPoint("TOP", divider, "BOTTOM", 0, -5)
    availLabel:SetText("|cFF00FF00Glyphs in Bags:|r")
    
    frame.availText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.availText:SetPoint("TOP", availLabel, "BOTTOM", 0, -5)
    frame.availText:SetWidth(300)
    frame.availText:SetJustifyH("CENTER")
    
    glyphFrame = frame
    tinsert(UISpecialFrames, "DCQoSGlyphFrame")
    
    if settings.glyphFramePos and settings.glyphFramePos.point then
        frame:ClearAllPoints()
        frame:SetPoint(settings.glyphFramePos.point, UIParent, settings.glyphFramePos.relPoint,
                       settings.glyphFramePos.x, settings.glyphFramePos.y)
    end
    
    return frame
end

function TalentManager:UpdateGlyphDisplay()
    if not glyphFrame or not glyphFrame:IsShown() then return end

    self:EnsureGlyphUI()

    local group = glyphFrame.viewingGroup or self:GetActiveSpec()
    local current = self:GetCurrentGlyphs(group)

    if glyphFrame.viewText then
        glyphFrame.viewText:SetText("Viewing: Spec " .. tostring(group))
    end

    local function ApplySlot(slot, glyph, kind)
        slot.glyphData = nil
        slot.lockedText = nil
        
        if not glyph then
            -- No glyph data at all
            slot.glyph:Hide()
            slot.shine:SetAlpha(0)
            slot.ring:SetAlpha(0.3)
            slot.lockedText = "Empty"
            if slot.nameLabel then slot.nameLabel:SetText("|cFF666666Empty|r") end
            return
        end

        if not glyph.enabled then
            -- Socket exists but is locked (level requirement)
            slot.glyph:Hide()
            slot.shine:SetAlpha(0)
            slot.ring:SetAlpha(0.2)
            slot.socketBg:SetVertexColor(0.3, 0.3, 0.3, 0.9)
            slot.lockedText = "Locked (level)"
            if slot.nameLabel then slot.nameLabel:SetText("|cFF888888Locked|r") end
            return
        end

        if glyph.spellId then
            -- Has a glyph inscribed
            slot.glyph:Show()
            if glyph.icon then
                slot.glyph:SetTexture(glyph.icon)
            else
                slot.glyph:SetTexture("Interface\\Icons\\INV_Inscription_Tradeskill01")
            end
            slot.shine:SetAlpha(0.3)
            slot.ring:SetAlpha(1)
            slot.socketBg:SetVertexColor(0.1, 0.1, 0.1, 0.9)
            slot.glyphData = glyph
            slot.lockedText = "Inscribed"
            
            -- Show glyph name
            local displayName = glyph.name or "Unknown"
            if #displayName > 14 then
                displayName = displayName:sub(1, 12) .. ".."
            end
            if slot.nameLabel then 
                local color = kind == "major" and "|cFFFFD100" or "|cFF8888FF"
                slot.nameLabel:SetText(color .. displayName .. "|r") 
            end
        else
            -- Socket is open but no glyph
            slot.glyph:Hide()
            slot.shine:SetAlpha(0)
            slot.ring:SetAlpha(0.6)
            slot.socketBg:SetVertexColor(0.1, 0.1, 0.1, 0.9)
            slot.lockedText = "Empty"
            if slot.nameLabel then slot.nameLabel:SetText("|cFF888888Empty|r") end
        end
    end

    for i, slot in ipairs(glyphFrame.majorSlots) do
        ApplySlot(slot, current.major[i], "major")
    end

    for i, slot in ipairs(glyphFrame.minorSlots) do
        ApplySlot(slot, current.minor[i], "minor")
    end
    
    local available = self:GetAvailableGlyphs()
    local lines = {}
    if #available.major > 0 then
        local names = {}
        for _, g in ipairs(available.major) do table.insert(names, g.name or "?") end
        table.insert(lines, "|cFFFFD100Major:|r " .. table.concat(names, ", "))
    end
    if #available.minor > 0 then
        local names = {}
        for _, g in ipairs(available.minor) do table.insert(names, g.name or "?") end
        table.insert(lines, "|cFF8888FFMinor:|r " .. table.concat(names, ", "))
    end
    glyphFrame.availText:SetText(#lines > 0 and table.concat(lines, "\n") or "|cFF666666None|r")
end

function TalentManager:ToggleGlyphFrame()
    self:EnsureGlyphUI()
    local frame = self:CreateGlyphFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        self:UpdateGlyphDisplay()
    end
end

-- ============================================================
-- Toggle & Initialize
-- ============================================================

function TalentManager:Toggle()
    local frame = self:CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        self:AnchorToTalentFrame()
        self:LoadTemplates()
        self:PopulateTalentTrees()
        self:UpdateTalentDisplay()
        self:UpdateTemplateDropdown()
        self:UpdateInspectDropdown()
    end
end

function TalentManager:Initialize()
    if isInitialized then return end
    
    self:LoadTemplates()
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
    eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    eventFrame:RegisterEvent("GLYPH_ADDED")
    eventFrame:RegisterEvent("GLYPH_REMOVED")
    eventFrame:RegisterEvent("GLYPH_UPDATED")
    eventFrame:RegisterEvent("INSPECT_TALENT_READY")
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "CHARACTER_POINTS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
            TalentManager:UpdateTalentDisplay()
        elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
            TalentManager:UpdateTalentDisplay()
            TalentManager:PopulateTalentTrees()
        elseif event:find("GLYPH") then
            TalentManager:UpdateGlyphDisplay()
        elseif event == "INSPECT_TALENT_READY" then
            if addon.settings.talentManager.hookInspect then
                TalentManager:SaveInspection("target")
                TalentManager:UpdateInspectDropdown()
            end
        elseif event == "CHAT_MSG_ADDON" then
            TalentManager:OnAddonMessage(...)
        end
    end)
    
    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(COMM_PREFIX)
    end
    
    isInitialized = true
end

-- ============================================================
-- Settings UI
-- ============================================================

function TalentManager.CreateSettings(parent)
    local settings = addon.settings.talentManager
    
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Talent Manager")
    
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Save, load, and share talent builds. Inspect players to copy their builds.")
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    
    local yOffset = -70
    
    local openBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    openBtn:SetPoint("TOPLEFT", 16, yOffset)
    openBtn:SetSize(180, 26)
    openBtn:SetText("Open Talent Manager")
    openBtn:SetScript("OnClick", function() TalentManager:Toggle() end)
    yOffset = yOffset - 35
    
    local enableCb = addon:CreateCheckbox(parent, "Enabled", "talentManager", "enabled")
    enableCb:SetPoint("TOPLEFT", 16, yOffset)
    yOffset = yOffset - 26
    
    local confirmCb = addon:CreateCheckbox(parent, "Confirm before learning", "talentManager", "confirmLearning")
    confirmCb:SetPoint("TOPLEFT", 16, yOffset)
    yOffset = yOffset - 26
    
    local backupCb = addon:CreateCheckbox(parent, "Auto-backup before respec", "talentManager", "autoBackup")
    backupCb:SetPoint("TOPLEFT", 16, yOffset)
    yOffset = yOffset - 26
    
    local inspectCb = addon:CreateCheckbox(parent, "Save inspected talents", "talentManager", "hookInspect")
    inspectCb:SetPoint("TOPLEFT", 16, yOffset)
    yOffset = yOffset - 26
    
    local lockCb = addon:CreateCheckbox(parent, "Lock frame position", "talentManager", "lockFrame")
    lockCb:SetPoint("TOPLEFT", 16, yOffset)
    yOffset = yOffset - 35
    
    -- Scale slider
    local scaleLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", 16, yOffset)
    scaleLabel:SetText("Scale: " .. string.format("%.1f", settings.frameScale or 1))
    
    local scaleSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", 16, yOffset - 18)
    scaleSlider:SetSize(180, 16)
    scaleSlider:SetMinMaxValues(0.6, 1.4)
    scaleSlider:SetValueStep(0.1)
    scaleSlider:SetValue(settings.frameScale or 1)
    local sliderName = scaleSlider:GetName()
    if sliderName then
        local scaleLow = _G[sliderName .. "Low"]
        local scaleHigh = _G[sliderName .. "High"]
        if scaleLow then scaleLow:SetText("0.6") end
        if scaleHigh then scaleHigh:SetText("1.4") end
    end
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        settings.frameScale = value
        scaleLabel:SetText("Scale: " .. string.format("%.1f", value))
        if mainFrame then mainFrame:SetScale(value) end
    end)
    yOffset = yOffset - 50
    
    -- Template list
    local listLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    listLabel:SetPoint("TOPLEFT", 16, yOffset)
    listLabel:SetText("Saved Templates:")
    yOffset = yOffset - 18
    
    local listText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    listText:SetPoint("TOPLEFT", 16, yOffset)
    listText:SetWidth(380)
    listText:SetJustifyH("LEFT")
    
    local function UpdateList()
        local list = TalentManager:GetTemplateList()
        if #list == 0 then
            listText:SetText("None saved yet")
        else
            local lines = {}
            for _, t in ipairs(list) do
                table.insert(lines, "• " .. t.name .. " (" .. t.summary .. ")")
            end
            listText:SetText(table.concat(lines, "\n"))
        end
    end
    
    parent:SetScript("OnShow", function()
        TalentManager:Initialize()
        UpdateList()
    end)
    
    return parent
end

-- ============================================================
-- Slash Commands
-- ============================================================

function TalentManager:RegisterSlashCommand()
    if addon.RegisterSubCommand then
        addon:RegisterSubCommand("talents", function(args)
            if args == "inspect" then
                self:SaveInspection("target")
            else
                self:Toggle()
            end
        end, "Open Talent Manager")
        addon:RegisterSubCommand("talent", function() self:Toggle() end)
    end
end

-- ============================================================
-- Module Registration
-- ============================================================

addon:RegisterModule("TalentManager", TalentManager)
TalentManager:RegisterSlashCommand()

-- Hook Blizzard talent frame
local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("ADDON_LOADED")
hookFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "Blizzard_TalentUI" and PlayerTalentFrame then
        if _G.DCQoS_TalentFrameButton then return end

        local dcBtn = CreateFrame("Button", "DCQoS_TalentFrameButton", PlayerTalentFrame)
        dcBtn:SetSize(36, 36)
        dcBtn:EnableMouse(true)
        dcBtn:SetFrameStrata("HIGH")
        if PlayerTalentFrame.GetFrameLevel then
            dcBtn:SetFrameLevel((PlayerTalentFrame:GetFrameLevel() or 0) + 25)
        end

        -- Background slot
        local slotBg = dcBtn:CreateTexture(nil, "BACKGROUND")
        slotBg:SetSize(50, 50)
        slotBg:SetPoint("CENTER")
        slotBg:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        dcBtn.slotBg = slotBg
        
        -- DC-QoS Icon - use a gear icon that's always available
        local icon = dcBtn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(32, 32)
        icon:SetPoint("CENTER")
        icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetVertexColor(1, 1, 1)  -- Ensure full color
        dcBtn.icon = icon

        -- Border glow
        local border = dcBtn:CreateTexture(nil, "OVERLAY")
        border:SetSize(52, 52)
        border:SetPoint("CENTER")
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetBlendMode("ADD")
        border:SetVertexColor(0.3, 0.7, 1.0)  -- Blue tint for DC-QoS
        dcBtn.border = border

        local highlight = dcBtn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        highlight:SetBlendMode("ADD")

        dcBtn:SetScript("OnClick", function() TalentManager:Toggle() end)
        dcBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("DC-QoS Talent Manager")
            GameTooltip:Show()
        end)
        dcBtn:SetScript("OnLeave", GameTooltip_Hide)

        TalentManager:PositionTalentFrameButton(dcBtn)
        dcBtn:Show()
        if PlayerTalentFrame.HookScript then
            PlayerTalentFrame:HookScript("OnShow", function()
                TalentManager:PositionTalentFrameButton(dcBtn)
            end)
        end
        if addon.DelayedCall then
            addon:DelayedCall(0.5, function()
                TalentManager:PositionTalentFrameButton(dcBtn)
            end)
        end
    end
end)
