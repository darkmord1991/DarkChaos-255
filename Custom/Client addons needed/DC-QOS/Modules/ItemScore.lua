-- ============================================================
-- DC-QoS: ItemScore Module (Pawn-style)
-- ============================================================
-- Shows upgrade arrows and item scores in tooltips
-- Integrates with DC-ItemUpgrade for tier information
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local ItemScore = {
    displayName = "Item Score",
    settingKey = "itemScore",
    icon = "Interface\\Icons\\INV_Misc_Gem_Variety_02",
}

-- ============================================================
-- Default Settings
-- ============================================================
local defaults = {
    itemScore = {
        enabled = true,
        showUpgradeArrows = true,
        showScore = true,
        showStatWeights = false,
        showComparison = true,
        -- Draw an upgrade-aware "If you replace this item..." block on compare
        -- tooltips in place of the client's (needs WotLK-Extensions).
        replaceCompareDelta = true,
        currentSpec = nil,  -- Auto-detect if nil
        arrowColor = { r = 0.0, g = 1.0, b = 0.0 },
        downgradeColor = { r = 1.0, g = 0.0, b = 0.0 },
        sideGradeColor = { r = 1.0, g = 1.0, b = 0.0 },
        equippedColor = { r = 0.6, g = 0.8, b = 1.0 },
    },
}

-- Merge defaults
for k, v in pairs(defaults) do
    addon.defaults[k] = v
end

local itemScoreTooltipHooksInstalled = false
local itemScoreEventRegistered = false

-- ============================================================
-- Stat Weights by Class/Spec (Based on Wowhead/Pawn)
-- ============================================================
local StatWeights = {
    WARRIOR = {
        Arms = { STRENGTH=1.07, HIT=1.56, EXPERTISE=0.63, CRIT=0.93, AGILITY=0.78, ARMOR_PENETRATION=0.83, HASTE=0.34, ATTACKPOWER=0.49, DPS=6.05 },
        Fury = { EXPERTISE=2.5, STRENGTH=3.25, CRIT=1.88, AGILITY=1.25, ARMOR_PENETRATION=3.13, HIT=2.5, HASTE=1.88, ATTACKPOWER=1.25, DPS=27.5 },
        Tank = { STAMINA=2.0, DODGE=1.4, DEFENSE=1.6, BLOCK_VALUE=1.18, AGILITY=1.2, PARRY=1.16, BLOCK=0.7, STRENGTH=0.66, EXPERTISE=1.34, HIT=0.4, ARMOR_PENETRATION=0.4, CRIT=0.4, ARMOR=0.1, DPS=20.0 },
    },
    PALADIN = {
        Holy = { INTELLECT=3.26, MANA_PER_5=2.37, SPELLPOWER=2.37, CRIT=2.67, HASTE=1.78, STAMINA=0.1 },
        Tank = { STAMINA=2.5, AGILITY=1.9, EXPERTISE=1.98, DODGE=2.35, DEFENSE=2.15, PARRY=2.15, ARMOR=0.15, BLOCK=1.3, BLOCK_VALUE=2.15, SPELLPOWER=0.15, HIT=1.45, DPS=12.5 },
        Retribution = { DPS=5.99, HIT=2.7, STRENGTH=2.99, EXPERTISE=4.49, CRIT=2.16, ATTACKPOWER=1.23, AGILITY=2.1, HASTE=2.04, ARMOR_PENETRATION=1.89, SPELLPOWER=1.2 },
    },
    HUNTER = {
        BeastMastery = { DPS=12.5, HIT=3.25, AGILITY=2.5, CRIT=1.75, INTELLECT=0.1, ATTACKPOWER=1.0, ARMOR_PENETRATION=1.75, HASTE=2.75, STAMINA=0.1 },
        Marksman = { DPS=12.5, HIT=3.25, AGILITY=2.5, CRIT=1.75, INTELLECT=0.1, ARMOR_PENETRATION=1.75, HASTE=2.75, STAMINA=0.1 },
        Survival = { DPS=12.5, HIT=3.25, AGILITY=2.5, CRIT=1.75, INTELLECT=0.1, ATTACKPOWER=1.0, ARMOR_PENETRATION=1.75, HASTE=2.75, STAMINA=0.1 },
    },
    ROGUE = {
        Assassination = { DPS=8.0, AGILITY=2.3, EXPERTISE=2.0, HIT=2.0, CRIT=1.5, ATTACKPOWER=1.0, ARMOR_PENETRATION=1.5, HASTE=1.8, STRENGTH=1.1 },
        Combat = { DPS=8.0, AGILITY=2.3, EXPERTISE=2.0, HIT=2.0, CRIT=1.5, ATTACKPOWER=1.0, ARMOR_PENETRATION=1.5, HASTE=1.8, STRENGTH=1.1 },
        Subtlety = { DPS=8.0, AGILITY=2.3, EXPERTISE=2.0, HIT=2.0, CRIT=1.5, ATTACKPOWER=1.0, ARMOR_PENETRATION=1.5, HASTE=1.8, STRENGTH=1.1 },
    },
    PRIEST = {
        Discipline = { SPELLPOWER=2.67, MANA_PER_5=3.33, INTELLECT=2.33, HASTE=4.0, CRIT=1.33, SPIRIT=2.33 },
        Holy = { SPELLPOWER=2.67, MANA_PER_5=3.33, INTELLECT=2.33, HASTE=4.0, CRIT=1.33, SPIRIT=2.33 },
        Shadow = { HIT=3.33, SPELLPOWER=3.33, CRIT=3.33, HASTE=3.33, SPIRIT=0.33, INTELLECT=0.17 },
    },
    DEATHKNIGHT = {
        BloodTank = { DPS=20.0, STAMINA=2.0, DEFENSE=1.6, AGILITY=1.2, DODGE=1.4, PARRY=1.16, EXPERTISE=1.34, STRENGTH=0.66, ARMOR_PENETRATION=0.4, CRIT=0.4, ARMOR=0.1, HIT=1.34 },
        FrostDPS = { DPS=62.5, HIT=1.25, STRENGTH=2.6, EXPERTISE=1.25, ARMOR_PENETRATION=1.25, CRIT=1.25, ATTACKPOWER=1.25, HASTE=1.25, ARMOR=1.0 },
        UnholyDPS = { DPS=62.5, HIT=1.25, STRENGTH=2.6, EXPERTISE=1.25, ARMOR_PENETRATION=1.25, CRIT=1.25, ATTACKPOWER=1.25, HASTE=1.25, ARMOR=1.0 },
    },
    SHAMAN = {
        Elemental = { HIT=3.33, SPELLPOWER=3.33, HASTE=3.33, CRIT=3.33, INTELLECT=0.57 },
        Enhancement = { DPS=16.67, HIT=1.34, EXPERTISE=4.51, AGILITY=2.23, INTELLECT=0.55, CRIT=0.32, HASTE=3.08, STRENGTH=2.0, ATTACKPOWER=1.67, SPELLPOWER=0.76, ARMOR_PENETRATION=3.0 },
        Restoration = { MANA_PER_5=4.62, INTELLECT=3.85, SPELLPOWER=3.85, CRIT=3.85, HASTE=4.62 },
    },
    MAGE = {
        Arcane = { HIT=2.73, HASTE=3.03, SPELLPOWER=3.33, CRIT=2.42, INTELLECT=2.12, SPIRIT=0.61, MANA_PER_5=1.52 },
        Fire = { HIT=4.17, HASTE=3.06, SPELLPOWER=3.33, CRIT=2.5, INTELLECT=1.39, MANA_PER_5=1.39, SPIRIT=0.56 },
        Frost = { HIT=5.15, HASTE=4.39, SPELLPOWER=3.33, CRIT=2.14, INTELLECT=0.62, MANA_PER_5=1.46, SPIRIT=0.56 },
    },
    WARLOCK = {
        Affliction = { HIT=4.67, SPELLPOWER=3.33, HASTE=3.67, CRIT=2.0, INTELLECT=0.67 },
        Demonology = { HIT=5.33, HASTE=4.0, SPELLPOWER=3.33, CRIT=2.67, INTELLECT=1.33 },
        Destruction = { HIT=5.33, HASTE=4.0, SPELLPOWER=3.33, CRIT=2.67, INTELLECT=1.33 },
    },
    DRUID = {
        Balance = { HIT=4.0, SPELLPOWER=3.33, HASTE=2.67, CRIT=2.0, SPIRIT=1.0, INTELLECT=1.33, MANA_PER_5=2.0 },
        FeralDPS = { AGILITY=2.76, ARMOR_PENETRATION=2.59, STRENGTH=2.27, CRIT=1.62, EXPERTISE=2.41, HIT=2.41, ATTACKPOWER=1.0, HASTE=0.93 },
        FeralTank = { AGILITY=1.48, STAMINA=1.56, DODGE=0.24, DEFENSE=0.23, EXPERTISE=2.28, STRENGTH=1.13, ARMOR=0.29, HIT=1.12, HASTE=0.83, ATTACKPOWER=0.5, CRIT=1.01, ARMOR_PENETRATION=0.88 },
        Restoration = { SPELLPOWER=3.13, MANA_PER_5=1.56, HASTE=3.13, INTELLECT=0.89, SPIRIT=1.24, CRIT=0.31 },
    },
}

-- ============================================================
-- Slot Mapping
-- ============================================================
local INVTYPE_TO_SLOT = {
    INVTYPE_HEAD = 1,
    INVTYPE_NECK = 2,
    INVTYPE_SHOULDER = 3,
    INVTYPE_CHEST = 5,
    INVTYPE_ROBE = 5,
    INVTYPE_WAIST = 6,
    INVTYPE_LEGS = 7,
    INVTYPE_FEET = 8,
    INVTYPE_WRIST = 9,
    INVTYPE_HAND = 10,
    INVTYPE_FINGER = 11,  -- or 12
    INVTYPE_TRINKET = 13, -- or 14
    INVTYPE_CLOAK = 15,
    INVTYPE_WEAPON = 16,  -- or 17 for offhand
    INVTYPE_2HWEAPON = 16,
    INVTYPE_WEAPONMAINHAND = 16,
    INVTYPE_WEAPONOFFHAND = 17,
    INVTYPE_HOLDABLE = 17,
    INVTYPE_SHIELD = 17,
    INVTYPE_RANGED = 18,
    INVTYPE_THROWN = 18,
    INVTYPE_RANGEDRIGHT = 18,
    INVTYPE_RELIC = 18,
}

-- ============================================================
-- Stat Extraction from Tooltip
-- ============================================================
local STAT_PATTERNS = {
    -- English patterns for 3.3.5a
    { pattern = "%+(%d+) Strength", stat = "STRENGTH" },
    { pattern = "%+(%d+) Agility", stat = "AGILITY" },
    { pattern = "%+(%d+) Stamina", stat = "STAMINA" },
    { pattern = "%+(%d+) Intellect", stat = "INTELLECT" },
    { pattern = "%+(%d+) Spirit", stat = "SPIRIT" },
    { pattern = "%+(%d+) Attack Power", stat = "ATTACKPOWER" },
    { pattern = "%+(%d+) Spell Power", stat = "SPELLPOWER" },
    { pattern = "%+(%d+) Critical Strike", stat = "CRIT" },
    { pattern = "%+(%d+) Hit Rating", stat = "HIT" },
    { pattern = "%+(%d+) Expertise Rating", stat = "EXPERTISE" },
    { pattern = "%+(%d+) Haste Rating", stat = "HASTE" },
    { pattern = "%+(%d+) Armor Penetration", stat = "ARMOR_PENETRATION" },
    { pattern = "%+(%d+) Resilience", stat = "RESILIENCE" },
    { pattern = "%+(%d+) Defense Rating", stat = "DEFENSE" },
    { pattern = "%+(%d+) Dodge Rating", stat = "DODGE" },
    { pattern = "%+(%d+) Parry Rating", stat = "PARRY" },
    { pattern = "%+(%d+) Block Rating", stat = "BLOCK" },
    { pattern = "(%d+) Block Value", stat = "BLOCK_VALUE" },
    -- Anchored: unanchored, "+20 Armor Penetration Rating" (a gem, or a random
    -- enchant row) was read as 20 Armor on anything without an armor line.
    { pattern = "^(%d+) Armor$", stat = "ARMOR", onlyFirst = true },
    -- A shield's own block value is printed as "174 Block".
    { pattern = "^(%d+) Block$", stat = "BLOCK_VALUE", onlyFirst = true },
    -- Labels the server uses for random-enchant and heirloom-package rows in the
    -- native tooltip ("+20 Crit Rating", "+8 Mana per 5 sec"); the rest of its
    -- labels ("Hit Rating", "Spell Power", ...) are already covered above.
    { pattern = "%+(%d+) Crit Rating", stat = "CRIT" },
    { pattern = "%+(%d+) Mana per 5", stat = "MANA_PER_5" },
    { pattern = "Restores (%d+) mana per 5", stat = "MANA_PER_5" },
    { pattern = "(%d+%.?%d*) Damage Per Second", stat = "DPS" },
}

-- The patterns above only see "+N Stat" lines. The 3.3.5 client writes every
-- rating, attack power and spell power as an "Equip: Improves ... by N." sentence
-- instead, so none of those were ever counted: a rogue's score for a ring with
-- +26 Strength and 20 expertise rating was 26 x 1.1 = 28.6, the expertise (weight
-- 2.0) simply missing. Same for weapon DPS -- the client prints it lowercase,
-- "(62.5 damage per second)", which the capitalised pattern never matched.
--
-- Built from the client's own ITEM_MOD_* strings so the wording always matches
-- what the tooltip prints; the English text is only a fallback for a client that
-- lacks the global. Mana regeneration is left out on purpose: the "Restores N
-- mana per 5" pattern above already matches that sentence.
local EQUIP_STAT_STRINGS = {
    { global = "ITEM_MOD_DEFENSE_SKILL_RATING", fallback = "Increases defense rating by %d.", stat = "DEFENSE" },
    { global = "ITEM_MOD_DODGE_RATING", fallback = "Increases your dodge rating by %d.", stat = "DODGE" },
    { global = "ITEM_MOD_PARRY_RATING", fallback = "Increases your parry rating by %d.", stat = "PARRY" },
    { global = "ITEM_MOD_BLOCK_RATING", fallback = "Increases your shield block rating by %d.", stat = "BLOCK" },
    { global = "ITEM_MOD_BLOCK_VALUE", fallback = "Increases the block value of your shield by %d.", stat = "BLOCK_VALUE" },
    { global = "ITEM_MOD_HIT_RATING", fallback = "Improves hit rating by %d.", stat = "HIT" },
    { global = "ITEM_MOD_HIT_MELEE_RATING", fallback = "Improves melee hit rating by %d.", stat = "HIT" },
    { global = "ITEM_MOD_HIT_RANGED_RATING", fallback = "Improves ranged hit rating by %d.", stat = "HIT" },
    { global = "ITEM_MOD_HIT_SPELL_RATING", fallback = "Improves spell hit rating by %d.", stat = "HIT" },
    { global = "ITEM_MOD_CRIT_RATING", fallback = "Improves critical strike rating by %d.", stat = "CRIT" },
    { global = "ITEM_MOD_CRIT_MELEE_RATING", fallback = "Improves melee critical strike rating by %d.", stat = "CRIT" },
    { global = "ITEM_MOD_CRIT_RANGED_RATING", fallback = "Improves ranged critical strike rating by %d.", stat = "CRIT" },
    { global = "ITEM_MOD_CRIT_SPELL_RATING", fallback = "Improves spell critical strike rating by %d.", stat = "CRIT" },
    { global = "ITEM_MOD_HASTE_RATING", fallback = "Improves haste rating by %d.", stat = "HASTE" },
    { global = "ITEM_MOD_HASTE_MELEE_RATING", fallback = "Improves melee haste rating by %d.", stat = "HASTE" },
    { global = "ITEM_MOD_HASTE_RANGED_RATING", fallback = "Improves ranged haste rating by %d.", stat = "HASTE" },
    { global = "ITEM_MOD_HASTE_SPELL_RATING", fallback = "Improves spell haste rating by %d.", stat = "HASTE" },
    { global = "ITEM_MOD_EXPERTISE_RATING", fallback = "Increases your expertise rating by %d.", stat = "EXPERTISE" },
    { global = "ITEM_MOD_RESILIENCE_RATING", fallback = "Improves your resilience rating by %d.", stat = "RESILIENCE" },
    { global = "ITEM_MOD_ATTACK_POWER", fallback = "Increases attack power by %d.", stat = "ATTACKPOWER" },
    { global = "ITEM_MOD_RANGED_ATTACK_POWER", fallback = "Increases ranged attack power by %d.", stat = "ATTACKPOWER" },
    { global = "ITEM_MOD_SPELL_POWER", fallback = "Increases spell power by %d.", stat = "SPELLPOWER" },
    { global = "ITEM_MOD_ARMOR_PENETRATION_RATING", fallback = "Increases your armor penetration rating by %d.", stat = "ARMOR_PENETRATION" },
}

-- "Improves hit rating by %d." -> "Improves hit rating by (%d+)%."  The trailing
-- period stays in the pattern on purpose: it keeps "Increases attack power by
-- 150 in Cat, Bear..." (feral AP) from being read as plain attack power.
local function BuildStatPatternFromTemplate(template)
    if type(template) ~= "string" or template == "" then
        return nil
    end

    local escaped = template:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    local pattern, replaced = escaped:gsub("%%%%d", "(%%d+)")
    if replaced ~= 1 then
        return nil
    end

    return pattern
end

do
    local seen = {}
    for _, entry in ipairs(EQUIP_STAT_STRINGS) do
        local pattern = BuildStatPatternFromTemplate(_G[entry.global])
            or BuildStatPatternFromTemplate(entry.fallback)
        -- Melee/ranged/spell variants can share one template on some clients;
        -- adding it twice would count the same line twice.
        if pattern and not seen[pattern] then
            seen[pattern] = true
            table.insert(STAT_PATTERNS, { pattern = pattern, stat = entry.stat })
        end
    end

    table.insert(STAT_PATTERNS, {
        pattern = "%(([%d%.]+) damage per second%)",
        stat = "DPS",
        onlyFirst = true,
    })
end

-- Reads every stat line of a tooltip into { STAT = value }. Both columns: the
-- native item tooltip puts a socketed gem's text in the RIGHT column
-- ("Red Socket ........ +16 Agility"). Line 1 is the item name.
-- "Socket Bonus: " (ITEM_SOCKET_BONUS is "Socket Bonus: %s").
local SOCKET_BONUS_PREFIX = (type(_G.ITEM_SOCKET_BONUS) == "string"
    and _G.ITEM_SOCKET_BONUS:match("^(.-)%%s")) or "Socket Bonus: "

-- Both the stock and the server-rendered tooltip draw an unmet socket bonus grey
-- and a met one green. Unmet, it grants nothing and must not be scored: an empty
-- Blue Socket's "+4 Agility" bonus was worth 9.2 points on a rogue.
-- No colour to read (GetTextColor missing) -> counted, the old behaviour.
local function IsInactiveSocketBonus(fontString, text)
    if not text or text:sub(1, #SOCKET_BONUS_PREFIX) ~= SOCKET_BONUS_PREFIX then
        return false
    end

    if not fontString.GetTextColor then
        return false
    end

    local r, g = fontString:GetTextColor()
    if not r or not g then
        return false
    end

    return not (g >= 0.8 and r <= 0.5)
end

-- Set bonuses are not the item's own stats. "Set: Increases attack power by 40."
-- (active) and "(4) Set: ..." (inactive) matched the Equip: patterns, so every set
-- piece scored its set's bonuses on top of its own stats -- whether or not the set
-- would survive the swap. Pawn leaves them out as well.
-- ITEM_SET_BONUS is "Set: %s", ITEM_SET_BONUS_GRAY "(%d) Set: %s".
local SET_BONUS_PREFIX = (type(_G.ITEM_SET_BONUS) == "string"
    and _G.ITEM_SET_BONUS:match("^(.-)%%s")) or "Set: "
local SET_BONUS_GRAY_PATTERN
do
    local gray = (type(_G.ITEM_SET_BONUS_GRAY) == "string"
        and _G.ITEM_SET_BONUS_GRAY:match("^(.-)%%s")) or "(%d) Set: "
    local escaped = gray:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    SET_BONUS_GRAY_PATTERN = "^" .. escaped:gsub("%%%%d", "%%d+")
end

local function IsSetBonusLine(text)
    return text:sub(1, #SET_BONUS_PREFIX) == SET_BONUS_PREFIX
        or text:find(SET_BONUS_GRAY_PATTERN) ~= nil
end

local function ParseTooltipStatLines(tooltip)
    local stats = {}
    local name = tooltip and tooltip.GetName and tooltip:GetName()
    if not name then
        return stats
    end

    local function parse(text)
        for _, patternInfo in ipairs(STAT_PATTERNS) do
            local value = tonumber(text:match(patternInfo.pattern))
            if value then
                if patternInfo.onlyFirst and stats[patternInfo.stat] then
                    -- Skip if already found (e.g., base armor)
                else
                    stats[patternInfo.stat] = (stats[patternInfo.stat] or 0) + value
                end
            end
        end
    end

    for i = 2, tooltip:NumLines() do
        local left = _G[name .. "TextLeft" .. i]
        local right = _G[name .. "TextRight" .. i]
        local leftText = left and left:GetText()
        if leftText and not IsInactiveSocketBonus(left, leftText)
            and not IsSetBonusLine(leftText) then
            parse(leftText)
        end
        -- A hidden right column can still hold text from an earlier render.
        local rightText = right and right:IsShown() and right:GetText()
        if rightText then
            parse(rightText)
        end
    end

    return stats
end

-- Scan hidden tooltip for stats
local scanTooltip = nil

local function CreateScanTooltip()
    if scanTooltip then return scanTooltip end
    
    scanTooltip = CreateFrame("GameTooltip", "DCQoSItemScoreScanTooltip", nil, "GameTooltipTemplate")
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    
    return scanTooltip
end

-- Memoization: every hover used to re-run 2-3 hidden SetHyperlink line-scans
-- (the hovered item plus each equipped comparison item). Raw stats are
-- weight-independent, so they cache per itemLink; equipped scores depend on
-- the active stat weights, so that cache also keys on the chosen spec and
-- clears whenever equipment changes.
local statsCache = {}
local statsCacheCount = 0
local STATS_CACHE_MAX = 150

local equippedScoreCache = { spec = nil, scores = {} }

local cacheInvalidator = CreateFrame("Frame")
cacheInvalidator:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
cacheInvalidator:SetScript("OnEvent", function()
    -- Equipped items changed; their per-link stats stay valid, only the
    -- slot->score mapping is stale.
    equippedScoreCache.scores = {}
end)

local function GetItemStats(itemLink)
    if not itemLink then return nil end

    local cached = statsCache[itemLink]
    if cached then return cached end

    local tooltip = CreateScanTooltip()
    tooltip:ClearLines()
    tooltip:SetHyperlink(itemLink)

    local stats = ParseTooltipStatLines(tooltip)

    if statsCacheCount >= STATS_CACHE_MAX then
        statsCache = {}
        statsCacheCount = 0
    end
    statsCache[itemLink] = stats
    statsCacheCount = statsCacheCount + 1

    return stats
end

-- ============================================================
-- Item Upgrade awareness
-- ============================================================
-- An item link only identifies the item TEMPLATE; the upgrade multiplier belongs
-- to the item INSTANCE (dc_item_upgrades, keyed by item guid). A hidden
-- SetHyperlink scan therefore always reads base stats, which made a +42% ring
-- score like a fresh drop and let "vs Equipped" recommend an un-upgraded
-- replacement that is actually worse.
--
-- What the server scales, so what gets scaled here: the item's own template stats
-- (stats, armor, weapon damage) and its random suffix. Enchants, gems and the
-- socket bonus the player adds stay flat -- the same line the server draws.
local EQUIPPED_BAG = 255 -- INVENTORY_SLOT_BAG_0: equipped slots on the server
local slotRequestAt = {}
local SLOT_REQUEST_MIN_INTERVAL = 0.5

-- The link with enchant and gems zeroed but the random suffix kept:
-- item:id:enchant:gem1:gem2:gem3:gem4:suffix:unique:level
local function GetScalableItemLink(itemLink)
    local fields = itemLink and itemLink:match("item:([%-%d:]+)")
    if not fields then
        return nil
    end

    local parts = {}
    for value in string.gmatch(fields, "([%-%d]+)") do
        parts[#parts + 1] = value
    end

    if not parts[1] then
        return nil
    end

    return string.format("item:%s:0:0:0:0:0:%s:%s:%s",
        parts[1], parts[7] or "0", parts[8] or "0", parts[9] or "0")
end

-- Stats of `itemLink` with the scalable part multiplied: base x multiplier plus
-- whatever the link carries on top of that (enchant, gems) unchanged. Returns a
-- fresh table; the per-link cache keeps the raw scan.
local function GetScaledItemStats(itemLink, multiplier)
    local full = GetItemStats(itemLink)
    if not full or not multiplier or multiplier <= 1.0 then
        return full
    end

    local scalableLink = GetScalableItemLink(itemLink)
    local base = scalableLink and GetItemStats(scalableLink)
    if not base then
        return full
    end

    -- Rounded the way the server rounds each line (lround of value x multiplier;
    -- DPS to one decimal), so this matches the numbers the tooltip prints.
    local function scale(stat, value)
        if stat == "DPS" then
            return math.floor(value * multiplier * 10 + 0.5) / 10
        end
        return math.floor(value * multiplier + 0.5)
    end

    local scaled = {}
    for stat, value in pairs(full) do
        local baseValue = math.min(base[stat] or 0, value)
        scaled[stat] = scale(stat, baseValue) + (value - baseValue)
    end
    for stat, value in pairs(base) do
        if scaled[stat] == nil then
            scaled[stat] = scale(stat, value)
        end
    end

    return scaled
end

local function IsHeirloomItem(itemId)
    local iu = rawget(_G, "DarkChaos_ItemUpgrade")
    return iu and type(iu.IsHeirloomItemId) == "function" and iu.IsHeirloomItemId(itemId) or false
end

-- Multiplier the server applies to the item equipped in `slot` (1..19).
--
-- Primary source is the WotLK-Extensions per-slot bridge: it answers from the
-- server's tooltip snapshot, so it is the same number the stat hooks use and it
-- is available for every slot, not just items once opened in the upgrade window.
-- DC-ItemUpgrade's own cache is the fallback for clients without the DLL; it only
-- holds items that window has queried.
-- ItemModType -> the stat keys the weights use.
local ITEM_MOD_TO_STAT = {
    [3] = "AGILITY", [4] = "STRENGTH", [5] = "INTELLECT", [6] = "SPIRIT", [7] = "STAMINA",
    [12] = "DEFENSE", [13] = "DODGE", [14] = "PARRY", [15] = "BLOCK",
    [16] = "HIT", [17] = "HIT", [18] = "HIT", [31] = "HIT",
    [19] = "CRIT", [20] = "CRIT", [21] = "CRIT", [32] = "CRIT",
    [28] = "HASTE", [29] = "HASTE", [30] = "HASTE", [36] = "HASTE",
    [35] = "RESILIENCE", [37] = "EXPERTISE",
    [38] = "ATTACKPOWER", [39] = "ATTACKPOWER",
    [43] = "MANA_PER_5", [44] = "ARMOR_PENETRATION", [45] = "SPELLPOWER",
    [48] = "BLOCK_VALUE",
}

-- "7:31,38:56" (9th value of GetNativeItemUpgradeTooltipData) -> { STAMINA = 31, ... }
local function DecodeBonusStats(encoded)
    if type(encoded) ~= "string" or encoded == "" then
        return nil
    end

    local stats = {}
    for statType, value in string.gmatch(encoded, "(%d+):(%-?%d+)") do
        local key = ITEM_MOD_TO_STAT[tonumber(statType)]
        if key then
            stats[key] = (stats[key] or 0) + tonumber(value)
        end
    end

    return next(stats) and stats or nil
end

-- The server's per-slot answer for an equipped item: its upgrade multiplier and
-- the stats its link cannot carry (DC RandomEnchants rolls, heirloom package),
-- already scaled server-side. nil when the DLL has no answer for this item.
local function GetNativeSlotData(slot, itemId)
    local getNative = rawget(_G, "GetNativeItemUpgradeTooltipData")
    if type(getNative) ~= "function" then
        return nil
    end

    local ok, nativeItemId, _, _, _, multiplier, _, _, errorText, bonusEncoded =
        pcall(getNative, EQUIPPED_BAG, slot - 1)
    -- The DLL caches per (bag, slot); the item id check drops a stale answer left
    -- over from whatever was in the slot before.
    if not ok or nativeItemId ~= itemId or errorText then
        return nil
    end

    multiplier = tonumber(multiplier) or 1.0
    return {
        multiplier = (multiplier > 1.0) and multiplier or 1.0,
        bonusEncoded = bonusEncoded or "",
        bonus = DecodeBonusStats(bonusEncoded),
    }
end

local function GetEquippedSlotMultiplier(slot)
    local itemId = GetInventoryItemID("player", slot)
    if not itemId then
        return 1.0
    end

    local native = GetNativeSlotData(slot, itemId)
    if native then
        return native.multiplier
    end

    if IsHeirloomItem(itemId) then
        return 1.0
    end

    local getCached = rawget(_G, "DarkChaos_ItemUpgrade_GetCachedDataForLocation")
    local iu = rawget(_G, "DarkChaos_ItemUpgrade")
    if type(getCached) == "function" then
        local data = getCached(EQUIPPED_BAG, slot - 1)
        local cachedEntry = data and (tonumber(data.itemEntry) or 0)
        if cachedEntry == 0 and data then
            cachedEntry = tonumber(data.guid) or 0 -- entry-keyed despite the name
        end
        if data and cachedEntry == itemId then
            -- Level + tier rather than the stored multiplier: an upgrade updates
            -- the cached level immediately, the stored multiplier only on the next
            -- full item-info response.
            local level = tonumber(data.currentUpgrade) or 0
            if level > 0 and iu and type(iu.GetStatMultiplierForLevel) == "function" then
                return iu.GetStatMultiplierForLevel(level, tonumber(data.tier) or 1) or 1.0
            end
            local stored = tonumber(data.statMultiplier) or 1.0
            return (stored > 1.0) and stored or 1.0
        end
    end

    return 1.0
end

-- Ask the server for a slot's upgrade state (all equipped slots when nil). The
-- answer lands in the DLL's per-slot cache; GetEquippedScore re-reads it on every
-- hover and recomputes when it moved, so nothing has to wait for it here.
local function RequestEquippedMultipliers(onlySlot)
    local request = rawget(_G, "RequestNativeItemUpgradeTooltip")
    if type(request) ~= "function" then
        return
    end

    local now = GetTime()
    local first, last = onlySlot or 1, onlySlot or 19
    for slot = first, last do
        if GetInventoryItemID("player", slot)
            and (now - (slotRequestAt[slot] or 0)) >= SLOT_REQUEST_MIN_INTERVAL then
            slotRequestAt[slot] = now
            pcall(request, EQUIPPED_BAG, slot - 1)
        end
    end
end

-- Multiplier of the item a visible tooltip is showing. When the DLL renders an
-- item from the server snapshot it appends "Upgrade  x/y" and, for upgraded
-- items, "Bonus  +N%" rows -- and OnTooltipSetItem fires after those rows exist,
-- so they identify THIS instance, bag or equipped, with no location guessing.
-- Returns nil when the tooltip carries no upgrade rows (link tooltips, no DLL, or
-- the first render before the snapshot arrived -- the DLL re-renders and fires
-- OnTooltipSetItem again once it lands).
local function GetTooltipUpgradeMultiplier(tooltip)
    local name = tooltip and tooltip.GetName and tooltip:GetName()
    if not name then
        return nil
    end

    local hasUpgradeRow = false
    local multiplier = nil
    for i = 1, tooltip:NumLines() do
        local left = _G[name .. "TextLeft" .. i]
        local right = _G[name .. "TextRight" .. i]
        local leftText = left and left:GetText()
        local rightText = right and right:IsShown() and right:GetText()
        if leftText == "Upgrade" and rightText and rightText:match("^%d+/%d+$") then
            hasUpgradeRow = true
        elseif leftText == "Bonus" and rightText then
            local percent = tonumber(rightText:match("^%+([%d%.]+)%%$"))
            if percent then
                multiplier = 1.0 + percent / 100.0
            end
        end
    end

    if not hasUpgradeRow then
        return nil
    end

    return multiplier or 1.0
end

-- Full stats of the item equipped in `slot`: its link scaled by the upgrade
-- multiplier, plus what the link cannot carry. Returns the stats and a key that
-- changes whenever any input does, for the score cache.
local function GetEquippedSlotStats(slot)
    local itemLink = GetInventoryItemLink("player", slot)
    if not itemLink then
        return nil, nil
    end

    local itemId = GetInventoryItemID("player", slot)
    local native = GetNativeSlotData(slot, itemId)
    local multiplier = native and native.multiplier or GetEquippedSlotMultiplier(slot)

    local stats = GetScaledItemStats(itemLink, multiplier) or {}
    if native and native.bonus then
        local combined = {}
        for stat, value in pairs(stats) do
            combined[stat] = value
        end
        for stat, value in pairs(native.bonus) do
            combined[stat] = (combined[stat] or 0) + value
        end
        stats = combined
    end

    local key = itemLink .. "|" .. multiplier .. "|" .. (native and native.bonusEncoded or "")
    return stats, key
end

-- Same stats, allowing for per-line rounding (and DPS printed to one decimal).
local function StatsEquivalent(a, b)
    if not a or not b then
        return false
    end

    for _, pair in ipairs({ { a, b }, { b, a } }) do
        for stat, value in pairs(pair[1]) do
            local tolerance = (stat == "DPS") and 0.15 or 1
            if math.abs(value - (pair[2][stat] or 0)) > tolerance then
                return false
            end
        end
    end

    return true
end

-- Stats of the item a visible tooltip is showing.
--
-- The tooltip on screen is the only thing that identifies the INSTANCE: two
-- copies of one ring with different random rolls have identical links. For an
-- item the player owns it lists exactly what the server applies -- scaled
-- template stats, random-enchant rolls, heirloom package, enchant, gems -- so it
-- is read directly.
--
-- Exception: an item that is the one equipped (same link) scores as that slot.
-- Before the DLL's snapshot arrives the tooltip still shows base values, and
-- scoring those against the upgraded equipped copy made your own ring flash
-- "Downgrade". Once the snapshot is on screen the slot is used only when it
-- matches what is shown, so a bag copy with other rolls is still read as itself.
-- Second value: the equipped slot when the hovered item IS the worn copy, else nil.
local function GetHoveredItemStats(tooltip, itemLink, candidateSlots)
    local visible = tooltip and ParseTooltipStatLines(tooltip) or nil

    for _, slot in ipairs(candidateSlots or {}) do
        if GetInventoryItemLink("player", slot) == itemLink then
            local equippedStats = GetEquippedSlotStats(slot)
            if GetTooltipUpgradeMultiplier(tooltip) == nil
                or StatsEquivalent(visible, equippedStats) then
                return equippedStats, slot
            end
        end
    end

    if visible and next(visible) then
        return visible
    end

    return GetItemStats(itemLink)
end

-- ============================================================
-- Score Calculation
-- ============================================================
local function GetPlayerWeights()
    local _, class = UnitClass("player")
    local classWeights = StatWeights[class]
    if not classWeights then return StatWeights.WARRIOR.Arms end
    
    -- Default to first spec found or a specific one if we could detect it
    -- For now, we'll just pick the first one or "Arms"/"Holy"/etc if available
    -- A real implementation would let the user choose via settings
    
    -- Simple heuristic: Check if we have a saved spec preference
    local spec = addon.settings.itemScore.currentSpec
    if spec and classWeights[spec] then
        return classWeights[spec]
    end
    
    -- Fallback: Return the first table found
    for _, weights in pairs(classWeights) do
        return weights
    end
    
    return classWeights -- Should be nil if we got here
end

local function CalculateScore(itemStats)
    if not itemStats then return 0 end
    
    local weights = GetPlayerWeights()
    local score = 0
    
    for stat, value in pairs(itemStats) do
        local weight = weights[stat] or 0
        score = score + (value * weight)
    end
    
    -- Nearest, not down: 264 x 2.3 is 607.1999... in floating point, so flooring
    -- showed 1482.1 for a 1482.2 item.
    return math.floor(score * 10 + 0.5) / 10
end

local function GetEquippedScore(slot)
    local spec = (addon.settings and addon.settings.itemScore and addon.settings.itemScore.currentSpec) or "auto"
    if equippedScoreCache.spec ~= spec then
        equippedScoreCache.spec = spec
        equippedScoreCache.scores = {}
    end

    local itemLink = GetInventoryItemLink("player", slot)
    if not itemLink then
        equippedScoreCache.scores[slot] = nil
        return 0
    end

    -- Keyed on link, multiplier AND the server's bonus stats: either can move
    -- without the link changing (an upgrade purchase, or the server's answer
    -- arriving after the first hover), and that has to invalidate by itself.
    local stats, key = GetEquippedSlotStats(slot)
    local cached = equippedScoreCache.scores[slot]
    if type(cached) == "table" and cached.key == key then
        return cached.score
    end

    local score = CalculateScore(stats)
    equippedScoreCache.scores[slot] = { key = key, score = score }
    return score
end

-- ============================================================
-- Upgrade Detection
-- ============================================================
-- 3.3.5 has no CanDualWield(). The Dual Wield passive (674; Enhancement's talent
-- is 30798) is in the spellbook of anyone who has it, and IsSpellKnown exists.
-- A weapon already sitting in the off hand proves it too, and covers any client
-- where the spell check misses.
local DUAL_WIELD_SPELLS = { 674, 30798 }
local OFFHAND_WEAPON_LOCS = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true }

local function CanPlayerDualWield()
    local isKnown = rawget(_G, "IsSpellKnown")
    if type(isKnown) == "function" then
        for _, spellId in ipairs(DUAL_WIELD_SPELLS) do
            local ok, known = pcall(isKnown, spellId)
            if ok and known then
                return true
            end
        end
    end

    local offhand = GetInventoryItemLink("player", 17)
    if offhand then
        local equipLoc = select(9, GetItemInfo(offhand))
        if equipLoc and OFFHAND_WEAPON_LOCS[equipLoc] then
            return true
        end
    end

    return false
end

-- The equipped slots an item of this equip location competes with, or nil.
local function GetCandidateSlots(itemEquipLoc)
    local slot = itemEquipLoc and INVTYPE_TO_SLOT[itemEquipLoc]
    if not slot then
        return nil
    end

    -- Rings and trinkets (two slots)
    if itemEquipLoc == "INVTYPE_FINGER" then
        return { 11, 12 }
    elseif itemEquipLoc == "INVTYPE_TRINKET" then
        return { 13, 14 }
    elseif itemEquipLoc == "INVTYPE_WEAPON" and CanPlayerDualWield() then
        -- A one-hander can go in either hand; it is measured against the weaker
        -- of the two, like rings and trinkets. Main-hand-only and off-hand-only
        -- items keep their single slot.
        return { 16, 17 }
    end

    return { slot }
end

local function GetUpgradeStatus(itemLink, tooltip)
    -- Returns: "upgrade", "downgrade", "sidegrade", "equipped", or nil, plus the
    -- score, the difference, the percentage and the stats it was scored with.
    if not itemLink then return nil end
    
    -- Get item info
    local itemName, _, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, 
          itemStackCount, itemEquipLoc = GetItemInfo(itemLink)
    
    if not itemEquipLoc or itemEquipLoc == "" then
        return nil  -- Not equippable
    end
    
    local slots = GetCandidateSlots(itemEquipLoc)
    if not slots then return nil end
    
    -- Calculate new item score, for the instance the tooltip is showing
    local newStats, equippedSlot = GetHoveredItemStats(tooltip, itemLink, slots)
    local newScore = CalculateScore(newStats)

    -- The item IS one you are wearing: there is nothing to decide. Comparing it
    -- against the weaker slot made a worn trinket read "Sidegrade" or "Upgrade"
    -- only because it beat your other trinket.
    if equippedSlot then
        if newScore == 0 then
            return nil
        end
        return "equipped", newScore, nil, nil, newStats
    end
    
    -- Compare with equipped items
    local bestEquippedScore = 0
    local worstEquippedScore = 999999
    local hasEmptySlot = false
    
    for _, s in ipairs(slots) do
        local equippedLink = GetInventoryItemLink("player", s)
        local equippedScore = 0
        if equippedLink then
            equippedScore = GetEquippedScore(s)
        else
            hasEmptySlot = true
        end
        if equippedScore > bestEquippedScore then
            bestEquippedScore = equippedScore
        end
        if equippedScore < worstEquippedScore then
            worstEquippedScore = equippedScore
        end
    end

    if newScore == 0 then
        if hasEmptySlot then
            return "upgrade", nil, nil, nil, newStats
        end
        return nil  -- No meaningful stats and no empty slot
    end
    
    -- Compare
    local scoreDiff = newScore - worstEquippedScore
    local percentDiff = 0
    if worstEquippedScore > 0 then
        percentDiff = (scoreDiff / worstEquippedScore) * 100
    elseif newScore > 0 then
        percentDiff = 100  -- Upgrading from nothing
    end
    
    if percentDiff > 5 then
        return "upgrade", newScore, scoreDiff, percentDiff, newStats
    elseif percentDiff < -5 then
        return "downgrade", newScore, scoreDiff, percentDiff, newStats
    else
        return "sidegrade", newScore, scoreDiff, percentDiff, newStats
    end
end

-- ============================================================
-- Tooltip Enhancement
-- ============================================================
local function AddItemScore(tooltip, itemLink)
    local settings = addon.settings.itemScore
    if not settings.enabled then return end
    if not itemLink then return end
    
    local status, score, scoreDiff, percentDiff, scoredStats = GetUpgradeStatus(itemLink, tooltip)
    if not status then return end
    
    tooltip:AddLine(" ")
    
    -- Show upgrade arrow
    if settings.showUpgradeArrows then
        local arrow, color
        if status == "upgrade" then
            arrow = "|TInterface\\Buttons\\UI-MicroStream-Green:0|t"
            color = settings.arrowColor
        elseif status == "downgrade" then
            arrow = "|TInterface\\Buttons\\UI-MicroStream-Red:0|t"
            color = settings.downgradeColor
        elseif status == "equipped" then
            arrow = "|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0|t"
            color = settings.equippedColor or defaults.itemScore.equippedColor
        else
            arrow = "|TInterface\\Buttons\\UI-MicroStream-Yellow:0|t"
            color = settings.sideGradeColor
        end
        
        local statusText = status:sub(1, 1):upper() .. status:sub(2)
        local colorCode = string.format("|cff%02x%02x%02x", 
            math.floor(color.r * 255), 
            math.floor(color.g * 255), 
            math.floor(color.b * 255))
        
        if percentDiff then
            local sign = percentDiff >= 0 and "+" or ""
            tooltip:AddDoubleLine(
                arrow .. " " .. colorCode .. statusText .. "|r",
                colorCode .. sign .. string.format("%.1f%%", percentDiff) .. "|r",
                1, 1, 1, 1, 1, 1
            )
        else
            tooltip:AddLine(arrow .. " " .. colorCode .. statusText .. "|r")
        end
    end
    
    -- Show score
    if settings.showScore and score then
        tooltip:AddDoubleLine(
            "Score:",
            "|cffffffff" .. string.format("%.1f", score) .. "|r",
            0.5, 0.5, 0.5
        )
        
        if settings.showComparison and scoreDiff then
            local sign = scoreDiff >= 0 and "+" or ""
            local diffColor = scoreDiff >= 0 and "|cff00ff00" or "|cffff0000"
            tooltip:AddDoubleLine(
                "vs Equipped:",
                diffColor .. sign .. string.format("%.1f", scoreDiff) .. "|r",
                0.5, 0.5, 0.5
            )
        end
    end
    
    -- Show stat weights breakdown (if enabled)
    if settings.showStatWeights then
        local stats = scoredStats or GetItemStats(itemLink)
        if stats then
            tooltip:AddLine(" ")
            tooltip:AddLine("|cff888888Stat Weights:|r")
            local weights = GetPlayerWeights()
            for stat, value in pairs(stats) do
                local weight = weights[stat] or 0
                if weight > 0 then
                    local contribution = value * weight
                    -- Scaled values are fractional; show them the way the
                    -- tooltip rounds them.
                    local shownValue = (math.floor(value) == value) and value
                        or string.format("%.0f", value)
                    tooltip:AddDoubleLine(
                        "|cffaaaaaa" .. stat .. ":|r",
                        "|cffffffff" .. shownValue .. " x " .. weight .. " = " .. string.format("%.1f", contribution) .. "|r",
                        1, 1, 1, 1, 1, 1
                    )
                end
            end
        end
    end
end

-- ============================================================
-- Compare tooltips: "If you replace this item..." block
-- ============================================================
-- The client draws that block under the equipped item from the two items'
-- TEMPLATE stats, so an upgraded item was compared at its base values and DC
-- RandomEnchants rolls were missing: a worn ring at +42% read as losing to a
-- fresh drop that is actually worse. With WotLK-Extensions the client's block is
-- switched off (SetNativeItemCompareDeltaSuppressed) and this one is drawn from
-- the stats the score uses: the hovered tooltip as shown, the equipped slot with
-- its multiplier and server-side bonus stats. Without the DLL the client's block
-- stays and nothing is drawn here, so it never shows twice.
local compareDeltaActive = false
local itemScoreModuleEnabled = false

local DELTA_UP_COLOR = "|cff00ff00"   -- the client's own two colours
local DELTA_DOWN_COLOR = "|cffff2020"

-- ItemModType order, which is the order the client lists them in.
local DELTA_STATS = {
    { stat = "DPS", label = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", fallback = "Damage Per Second", decimals = true },
    { stat = "ARMOR", label = "RESISTANCE0_NAME", fallback = "Armor" },
    { stat = "AGILITY", label = "ITEM_MOD_AGILITY_SHORT", fallback = "Agility" },
    { stat = "STRENGTH", label = "ITEM_MOD_STRENGTH_SHORT", fallback = "Strength" },
    { stat = "INTELLECT", label = "ITEM_MOD_INTELLECT_SHORT", fallback = "Intellect" },
    { stat = "SPIRIT", label = "ITEM_MOD_SPIRIT_SHORT", fallback = "Spirit" },
    { stat = "STAMINA", label = "ITEM_MOD_STAMINA_SHORT", fallback = "Stamina" },
    { stat = "DEFENSE", label = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", fallback = "Defense Rating" },
    { stat = "DODGE", label = "ITEM_MOD_DODGE_RATING_SHORT", fallback = "Dodge Rating" },
    { stat = "PARRY", label = "ITEM_MOD_PARRY_RATING_SHORT", fallback = "Parry Rating" },
    { stat = "BLOCK", label = "ITEM_MOD_BLOCK_RATING_SHORT", fallback = "Block Rating" },
    { stat = "HIT", label = "ITEM_MOD_HIT_RATING_SHORT", fallback = "Hit Rating" },
    { stat = "CRIT", label = "ITEM_MOD_CRIT_RATING_SHORT", fallback = "Critical Strike Rating" },
    { stat = "RESILIENCE", label = "ITEM_MOD_RESILIENCE_RATING_SHORT", fallback = "Resilience Rating" },
    { stat = "HASTE", label = "ITEM_MOD_HASTE_RATING_SHORT", fallback = "Haste Rating" },
    { stat = "EXPERTISE", label = "ITEM_MOD_EXPERTISE_RATING_SHORT", fallback = "Expertise Rating" },
    { stat = "ATTACKPOWER", label = "ITEM_MOD_ATTACK_POWER_SHORT", fallback = "Attack Power" },
    { stat = "MANA_PER_5", label = "ITEM_MOD_MANA_REGENERATION_SHORT", fallback = "Mana Regeneration" },
    { stat = "ARMOR_PENETRATION", label = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT", fallback = "Armor Penetration Rating" },
    { stat = "SPELLPOWER", label = "ITEM_MOD_SPELL_POWER_SHORT", fallback = "Spell Power" },
    { stat = "BLOCK_VALUE", label = "ITEM_MOD_BLOCK_VALUE_SHORT", fallback = "Block Value" },
}

-- Stats the score does not read, taken from the client's GetItemStats(link),
-- which lists the template. The server scales these by the upgrade multiplier
-- like every other template stat; sockets it leaves alone.
local DELTA_TEMPLATE_STATS = {
    { key = "ITEM_MOD_HEALTH_SHORT", fallback = "Health" },
    { key = "ITEM_MOD_MANA_SHORT", fallback = "Mana" },
    { key = "ITEM_MOD_HEALTH_REGEN_SHORT", fallback = "Health Per 5 Sec." },
    { key = "ITEM_MOD_SPELL_PENETRATION_SHORT", fallback = "Spell Penetration" },
    { key = "RESISTANCE1_NAME", fallback = "Holy Resistance" },
    { key = "RESISTANCE2_NAME", fallback = "Fire Resistance" },
    { key = "RESISTANCE3_NAME", fallback = "Nature Resistance" },
    { key = "RESISTANCE4_NAME", fallback = "Frost Resistance" },
    { key = "RESISTANCE5_NAME", fallback = "Shadow Resistance" },
    { key = "RESISTANCE6_NAME", fallback = "Arcane Resistance" },
}
local DELTA_SOCKET_COLORS = { "Meta", "Red", "Yellow", "Blue" }

local COMPARE_TOOLTIPS = {
    "ShoppingTooltip1", "ShoppingTooltip2",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2",
    "WorldMapCompareTooltip1", "WorldMapCompareTooltip2",
}

-- "+15 Stamina" / "-2.5 Damage Per Second", number coloured, like the client.
local function FormatDeltaLine(delta, label, decimals)
    local amount = decimals and string.format("%.1f", math.abs(delta))
        or string.format("%d", math.abs(delta))
    return (delta > 0 and DELTA_UP_COLOR or DELTA_DOWN_COLOR)
        .. (delta > 0 and "+" or "-") .. amount .. "|r " .. label
end

-- The module's own GetItemStats (a tooltip scan) shadows the client API.
local function GetTemplateStats(itemLink)
    local getStats = rawget(_G, "GetItemStats")
    if type(getStats) ~= "function" or not itemLink then
        return {}
    end

    local ok, stats = pcall(getStats, itemLink)
    return (ok and type(stats) == "table") and stats or {}
end

-- The equipped slot a compare tooltip is showing. Its link says which item; the
-- index only matters when both slots hold the same link. The client then puts
-- the OFF hand in the first tooltip when both hands are filled, and otherwise
-- the lower slot first.
local function FindCompareSlot(equippedLink, index)
    local matches = {}
    for slot = 1, 19 do
        if GetInventoryItemLink("player", slot) == equippedLink then
            matches[#matches + 1] = slot
        end
    end

    if #matches <= 1 then
        return matches[1]
    end

    if matches[1] == 16 and matches[2] == 17 then
        return (index == 1) and 17 or 16
    end

    return matches[index] or matches[1]
end

-- Lines for hovered-minus-equipped, empty when nothing changes.
local function BuildCompareDeltaLines(hoveredLink, sourceTooltip, equippedLink, slot)
    local equipLoc = select(9, GetItemInfo(hoveredLink))
    local newStats = GetHoveredItemStats(sourceTooltip, hoveredLink, GetCandidateSlots(equipLoc)) or {}
    local oldStats = GetEquippedSlotStats(slot) or {}

    local lines = {}
    for _, entry in ipairs(DELTA_STATS) do
        local delta = (newStats[entry.stat] or 0) - (oldStats[entry.stat] or 0)
        if entry.decimals then
            delta = math.floor(delta * 10 + 0.5) / 10
        else
            delta = math.floor(delta + 0.5)
        end
        if delta ~= 0 then
            lines[#lines + 1] = FormatDeltaLine(delta, _G[entry.label] or entry.fallback, entry.decimals)
        end
    end

    local newTemplate = GetTemplateStats(hoveredLink)
    local oldTemplate = GetTemplateStats(equippedLink)
    local newMultiplier = GetTooltipUpgradeMultiplier(sourceTooltip) or 1.0
    local oldMultiplier = GetEquippedSlotMultiplier(slot)
    for _, entry in ipairs(DELTA_TEMPLATE_STATS) do
        local delta = math.floor((newTemplate[entry.key] or 0) * newMultiplier + 0.5)
            - math.floor((oldTemplate[entry.key] or 0) * oldMultiplier + 0.5)
        if delta ~= 0 then
            lines[#lines + 1] = FormatDeltaLine(delta, _G[entry.key] or entry.fallback)
        end
    end

    for _, color in ipairs(DELTA_SOCKET_COLORS) do
        local key = "EMPTY_SOCKET_" .. color:upper()
        local delta = (newTemplate[key] or 0) - (oldTemplate[key] or 0)
        if delta ~= 0 then
            local label = string.format("|TInterface\\ItemSocketingFrame\\UI-EmptySocket-%s.blp:12|t  %s",
                color, _G[key] or (color .. " Socket"))
            lines[#lines + 1] = FormatDeltaLine(delta, label)
        end
    end

    return lines
end

-- Runs after SetHyperlinkCompareItem(link, index, shift, sourceTooltip) has
-- filled a compare tooltip with the equipped item.
local function AddCompareDelta(compareTooltip, hoveredLink, index, sourceTooltip)
    if not compareDeltaActive or not hoveredLink or not sourceTooltip then
        return
    end

    local _, equippedLink = compareTooltip:GetItem()
    local slot = equippedLink and FindCompareSlot(equippedLink, index)
    if not slot then
        return
    end

    local lines = BuildCompareDeltaLines(hoveredLink, sourceTooltip, equippedLink, slot)
    if #lines == 0 then
        return
    end

    local gold = NORMAL_FONT_COLOR or { r = 1.0, g = 0.82, b = 0.0 }
    compareTooltip:AddLine(" ")
    compareTooltip:AddLine(ITEM_DELTA_DESCRIPTION
        or "If you replace this item, the following stat changes will occur:",
        gold.r, gold.g, gold.b, true)
    for _, text in ipairs(lines) do
        compareTooltip:AddLine(text, 1, 1, 1)
    end
    compareTooltip:Show()
end

local compareDeltaHooksInstalled = false

local function InstallCompareDeltaHooks()
    if compareDeltaHooksInstalled then return end
    compareDeltaHooksInstalled = true

    for _, name in ipairs(COMPARE_TOOLTIPS) do
        local tooltip = _G[name]
        if tooltip and tooltip.SetHyperlinkCompareItem then
            hooksecurefunc(tooltip, "SetHyperlinkCompareItem", function(self, link, index, _, sourceTooltip)
                AddCompareDelta(self, link, index, sourceTooltip)
            end)
        end
    end
end

-- The client's block is switched off only while this one is drawn instead.
local function ApplyCompareDeltaSetting()
    local settings = addon.settings and addon.settings.itemScore or {}
    local wanted = itemScoreModuleEnabled and settings.enabled
        and settings.replaceCompareDelta ~= false

    local setSuppressed = rawget(_G, "SetNativeItemCompareDeltaSuppressed")
    if type(setSuppressed) ~= "function" then
        compareDeltaActive = false
        return
    end

    local ok, suppressed = pcall(setSuppressed, wanted and true or false)
    compareDeltaActive = ok and suppressed == true
end

-- ============================================================
-- Hook into Tooltips module
-- ============================================================
local function HookTooltips()
    if itemScoreTooltipHooksInstalled then return end
    itemScoreTooltipHooksInstalled = true

    -- Hook into item tooltip methods
    local tooltipsToHook = {
        GameTooltip,
        ItemRefTooltip,
        ShoppingTooltip1,
        ShoppingTooltip2,
    }
    
    for _, tooltip in ipairs(tooltipsToHook) do
        if tooltip then
            tooltip:HookScript("OnTooltipSetItem", function(self)
                local _, itemLink = self:GetItem()
                if itemLink then
                    AddItemScore(self, itemLink)
                    self:Show()
                end
            end)
        end
    end
    
    addon:Debug("ItemScore tooltip hooks installed")
end

-- ============================================================
-- Server Integration
-- ============================================================
-- Server can send custom stat weights per character
function ItemScore:SetCustomWeights(class, weights)
    if class and weights then
        StatWeights[class] = weights
    end
end

local function OnStatWeightsReceived(data)
    if data and data.class and data.weights then
        ItemScore:SetCustomWeights(data.class, data.weights)
    end
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function ItemScore.OnInitialize()
    addon:Debug("ItemScore module initializing")
    CreateScanTooltip()
end

local upgradeAwarenessInstalled = false

local function InstallUpgradeAwareness()
    if upgradeAwarenessInstalled then return end
    upgradeAwarenessInstalled = true

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    frame:SetScript("OnEvent", function(_, event, slot)
        if event == "PLAYER_EQUIPMENT_CHANGED" then
            RequestEquippedMultipliers(tonumber(slot))
        else
            RequestEquippedMultipliers(nil)
        end
    end)

    -- A purchase changes the multiplier without any equipment event; re-ask for
    -- every slot holding that item (normally one, two for a non-unique pair).
    local notify = rawget(_G, "DarkChaos_ItemUpgrade_OnUpgradeCacheChanged")
    if type(notify) == "function" then
        hooksecurefunc("DarkChaos_ItemUpgrade_OnUpgradeCacheChanged", function(itemId)
            itemId = tonumber(itemId)
            for slot = 1, 19 do
                if not itemId or GetInventoryItemID("player", slot) == itemId then
                    slotRequestAt[slot] = nil -- a purchase must never be throttled away
                    RequestEquippedMultipliers(slot)
                end
            end
            equippedScoreCache.scores = {}
        end)
    end

    -- Enabled after login (module toggled on): nothing else will ask.
    if IsLoggedIn and IsLoggedIn() then
        RequestEquippedMultipliers(nil)
    end
end

function ItemScore.OnEnable()
    addon:Debug("ItemScore module enabling")
    HookTooltips()
    InstallUpgradeAwareness()
    InstallCompareDeltaHooks()
    itemScoreModuleEnabled = true
    ApplyCompareDeltaSetting()
    
    -- Listen for server-sent weights
    if not itemScoreEventRegistered then
        itemScoreEventRegistered = true
        addon:RegisterEvent("STAT_WEIGHTS_RECEIVED", OnStatWeightsReceived)
        addon:RegisterEvent("SETTING_CHANGED", function(path)
            if type(path) == "string" and path:sub(1, 10) == "itemScore." then
                ApplyCompareDeltaSetting()
            end
        end)
    end
end

function ItemScore.OnDisable()
    addon:Debug("ItemScore module disabling")
    itemScoreModuleEnabled = false
    ApplyCompareDeltaSetting()
end

-- ============================================================
-- Settings Panel Creation
-- ============================================================
function ItemScore.CreateSettings(parent)
    local settings = addon.settings.itemScore
    
    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Item Score Settings")
    
    -- Description
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Pawn-style item upgrade detection and scoring based on stat weights for your class.")
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    
    local yOffset = -70
    
    -- ============================================================
    -- Enable Section
    -- ============================================================
    local enableCb = addon:CreateCheckbox(parent)
    enableCb:SetPoint("TOPLEFT", 16, yOffset)
    enableCb.Text:SetText("Enable Item Scoring")
    enableCb:SetChecked(settings.enabled)
    enableCb:SetScript("OnClick", function(self)
        addon:SetSetting("itemScore.enabled", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Display Options
    -- ============================================================
    local displayHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    displayHeader:SetPoint("TOPLEFT", 16, yOffset)
    displayHeader:SetText("Display Options")
    yOffset = yOffset - 25
    
    -- Show Upgrade Arrows
    local arrowsCb = addon:CreateCheckbox(parent)
    arrowsCb:SetPoint("TOPLEFT", 16, yOffset)
    arrowsCb.Text:SetText("Show Upgrade/Downgrade Arrows")
    arrowsCb:SetChecked(settings.showUpgradeArrows)
    arrowsCb:SetScript("OnClick", function(self)
        addon:SetSetting("itemScore.showUpgradeArrows", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Show Score
    local scoreCb = addon:CreateCheckbox(parent)
    scoreCb:SetPoint("TOPLEFT", 16, yOffset)
    scoreCb.Text:SetText("Show Item Score")
    scoreCb:SetChecked(settings.showScore)
    scoreCb:SetScript("OnClick", function(self)
        addon:SetSetting("itemScore.showScore", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Show Comparison
    local compCb = addon:CreateCheckbox(parent)
    compCb:SetPoint("TOPLEFT", 16, yOffset)
    compCb.Text:SetText("Show Comparison with Equipped")
    compCb:SetChecked(settings.showComparison)
    compCb:SetScript("OnClick", function(self)
        addon:SetSetting("itemScore.showComparison", self:GetChecked())
    end)
    yOffset = yOffset - 25

    -- Replace the client's "If you replace this item..." block
    local deltaCb = addon:CreateCheckbox(parent)
    deltaCb:SetPoint("TOPLEFT", 16, yOffset)
    deltaCb.Text:SetText("Upgrade-aware \"If you replace this item\" stat changes")
    deltaCb:SetChecked(settings.replaceCompareDelta ~= false)
    deltaCb:SetScript("OnClick", function(self)
        addon:SetSetting("itemScore.replaceCompareDelta", self:GetChecked() and true or false)
    end)
    yOffset = yOffset - 25
    
    -- Show Stat Weights
    local weightsCb = addon:CreateCheckbox(parent)
    weightsCb:SetPoint("TOPLEFT", 16, yOffset)
    weightsCb.Text:SetText("Show Stat Weight Breakdown (verbose)")
    weightsCb:SetChecked(settings.showStatWeights)
    weightsCb:SetScript("OnClick", function(self)
        addon:SetSetting("itemScore.showStatWeights", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Current Class Info
    -- ============================================================
    local classHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    classHeader:SetPoint("TOPLEFT", 16, yOffset)
    classHeader:SetText("Current Class Weights")
    yOffset = yOffset - 20
    
    local _, playerClass = UnitClass("player")
    local weights = GetPlayerWeights()
    
    local classInfo = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    classInfo:SetPoint("TOPLEFT", 16, yOffset)
    
    local weightText = "Class: " .. (playerClass or "Unknown") .. "\nPrimary Stats: "
    local primaryStats = {}
    for stat, weight in pairs(weights) do
        if weight >= 2.0 then
            table.insert(primaryStats, stat)
        end
    end
    weightText = weightText .. table.concat(primaryStats, ", ")
    
    classInfo:SetText(weightText)
    classInfo:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    classInfo:SetJustifyH("LEFT")
    yOffset = yOffset - 40

    -- Spec Selection Dropdown (Simple implementation)
    local specHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    specHeader:SetPoint("TOPLEFT", 16, yOffset)
    specHeader:SetText("Select Spec")
    yOffset = yOffset - 25

    local specDropdown = CreateFrame("Frame", "DCQoSItemScoreSpecDropdown", parent, "UIDropDownMenuTemplate")
    specDropdown:SetPoint("TOPLEFT", 0, yOffset)
    UIDropDownMenu_SetWidth(specDropdown, 150)
    UIDropDownMenu_SetText(specDropdown, settings.currentSpec or "Auto")

    UIDropDownMenu_Initialize(specDropdown, function(self, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        local classWeights = StatWeights[playerClass]
        if classWeights then
            for specName, _ in pairs(classWeights) do
                info.text = specName
                info.func = function()
                    addon:SetSetting("itemScore.currentSpec", specName)
                    UIDropDownMenu_SetText(specDropdown, specName)
                    -- Refresh weights display
                    local newWeights = GetPlayerWeights()
                    local newPrimaryStats = {}
                    for stat, weight in pairs(newWeights) do
                        if weight >= 2.0 then
                            table.insert(newPrimaryStats, stat)
                        end
                    end
                    classInfo:SetText("Class: " .. playerClass .. "\nPrimary Stats: " .. table.concat(newPrimaryStats, ", "))
                end
                info.checked = (settings.currentSpec == specName)
                UIDropDownMenu_AddButton(info)
            end
        end
    end)
    
    return yOffset - 60
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("ItemScore", ItemScore)
