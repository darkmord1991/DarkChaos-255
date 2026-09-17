--[[
    DC-CharacterFrame / Stats.lua
    =============================
    Sidebar pane 1: retail-style character stats. An "Item Level" block at
    the top, then collapsible categories (Attributes, Melee, Ranged, Spell,
    Defenses, Resistances). The rows are StatFrameTemplate frames so every
    value and tooltip comes straight from the stock PaperDollFrame_Set*
    functions - nothing is recomputed here except the item level.
]]

local DCCF = DCCharacterFrame
local Tex = DCCF.Tex

local CONTENT_W = 191   -- pane width (213) minus the scrollbar
local ROW_H = 15
local HDR_H = 36
local ILVL_H = 29

local CR = {
    HIT_MELEE = _G.CR_HIT_MELEE or 6,
    HIT_RANGED = _G.CR_HIT_RANGED or 7,
    HIT_SPELL = _G.CR_HIT_SPELL or 8,
    HASTE_MELEE = _G.CR_HASTE_MELEE or 18,
    HASTE_RANGED = _G.CR_HASTE_RANGED or 19,
    ARMOR_PENETRATION = _G.CR_ARMOR_PENETRATION or 25,
}

-- Covers everything the retired DC-QOS ExtendedStats panel showed: hit / haste /
-- armor penetration as percentages (rating + miss chances in the tooltip),
-- avoidance, block value, movement speed and mana regen while casting.
local CATEGORIES = {
    { key = "attributes", title = "Attributes",
      stats = { { "stat", 1 }, { "stat", 2 }, { "stat", 3 }, { "stat", 4 }, { "stat", 5 }, { "armor" },
                { "movespeed" } } },
    { key = "melee", title = PLAYERSTAT_MELEE_COMBAT or "Melee",
      stats = { { "damage" }, { "attackspeed" }, { "attackpower" }, { "hit", "MELEE" }, { "meleecrit" },
                { "expertise" }, { "hastepct", CR.HASTE_MELEE }, { "arp" } } },
    { key = "ranged", title = PLAYERSTAT_RANGED_COMBAT or "Ranged",
      stats = { { "rangeddamage" }, { "rangedattackspeed" }, { "rangedattackpower" }, { "hit", "RANGED" },
                { "rangedcrit" }, { "hastepct", CR.HASTE_RANGED }, { "arp" } } },
    { key = "spell", title = PLAYERSTAT_SPELL_COMBAT or "Spell",
      stats = { { "spellbonusdamage" }, { "spellbonushealing" }, { "hit", "SPELL" }, { "spellcrit" },
                { "spellhaste" }, { "spellpen" }, { "manaregen" }, { "manaregencasting" } } },
    { key = "defense", title = PLAYERSTAT_DEFENSES or "Defenses",
      stats = { { "armor" }, { "defense" }, { "dodge" }, { "parry" }, { "block" }, { "blockvalue" },
                { "avoidance" }, { "resilience" } } },
    { key = "resist", title = RESISTANCES or "Resistances",
      stats = { { "resist", 2 }, { "resist", 3 }, { "resist", 4 }, { "resist", 5 }, { "resist", 6 } } },
}

-- ---------------------------------------------------------------------------
-- Rows the stock PaperDollFrame has no setter for
-- ---------------------------------------------------------------------------

local function SetRow(row, label, text, tooltip, tooltip2)
    _G[row:GetName() .. "Label"]:SetText(string.format(STAT_FORMAT or "%s:", label))
    _G[row:GetName() .. "StatText"]:SetText(text)
    row.tooltip = tooltip and (HIGHLIGHT_FONT_COLOR_CODE .. tooltip .. FONT_COLOR_CODE_CLOSE) or nil
    row.tooltip2 = tooltip2
end

local function Pct(v)
    return string.format("%.2f%%", v or 0)
end

-- Base miss chance vs. same level / vs. a boss (+3 levels) per attack type.
local HIT_INFO = {
    MELEE  = { same = 5,  boss = 8,  rating = CR.HIT_MELEE,  label = "Hit Chance" },
    RANGED = { same = 5,  boss = 8,  rating = CR.HIT_RANGED, label = "Hit Chance" },
    SPELL  = { same = 4,  boss = 17, rating = CR.HIT_SPELL,  label = "Spell Hit" },
}

local function SetHitRow(row, kind)
    local info = HIT_INFO[kind]
    local rating = GetCombatRating(info.rating) or 0
    local bonus = GetCombatRatingBonus(info.rating) or 0
    SetRow(row, info.label, Pct(bonus), info.label .. " " .. Pct(bonus),
        string.format("Hit Rating: %d\nMiss chance vs. same level: %s\nMiss chance vs. boss (+3): %s",
            rating, Pct(math.max(0, info.same - bonus)), Pct(math.max(0, info.boss - bonus))))
end

local function SetHastePctRow(row, ratingIndex)
    local rating = GetCombatRating(ratingIndex) or 0
    local bonus = GetCombatRatingBonus(ratingIndex) or 0
    SetRow(row, "Haste", Pct(bonus), "Haste " .. Pct(bonus),
        string.format("Haste Rating: %d\nIncreases attack and casting speed.", rating))
end

local function SetArmorPenRow(row)
    local rating = GetCombatRating(CR.ARMOR_PENETRATION) or 0
    local bonus = GetCombatRatingBonus(CR.ARMOR_PENETRATION) or 0
    SetRow(row, "Armor Penetration", Pct(bonus), "Armor Penetration " .. Pct(bonus),
        string.format("Armor Penetration Rating: %d\nYour physical attacks ignore this much of the target's armor.", rating))
end

local function SetAvoidanceRow(row)
    local dodge = GetDodgeChance() or 0
    local parry = GetParryChance() or 0
    local miss = 5
    local total = dodge + parry + miss
    SetRow(row, "Avoidance", Pct(total), "Avoidance " .. Pct(total),
        string.format("Dodge: %s\nParry: %s\nBase miss vs. same level: %s", Pct(dodge), Pct(parry), Pct(miss)))
end

local function SetBlockValueRow(row)
    local value = GetShieldBlock() or 0
    SetRow(row, "Block Value", value, "Block Value " .. value,
        "Damage absorbed by a successful block.")
end

local function SetMoveSpeedRow(row)
    local speed = GetUnitSpeed("player") or 0
    local pct = speed > 0 and (speed / 7) * 100 or 100
    SetRow(row, "Movement Speed", string.format("%d%%", math.floor(pct + 0.5)),
        string.format("Movement Speed %d%%", math.floor(pct + 0.5)), "Base run speed is 100%.")
end

local function SetManaRegenCastingRow(row)
    if not UnitHasMana("player") then
        SetRow(row, "Regen While Casting", NOT_APPLICABLE or "N/A")
        return
    end
    local base, casting = GetManaRegen()
    base = math.floor((base or 0) * 5)
    casting = math.floor((casting or 0) * 5)
    SetRow(row, "Regen While Casting", casting, "Mana Regeneration While Casting",
        string.format("%d mana per 5 seconds while casting\n%d mana per 5 seconds while not casting", casting, base))
end

local function DefaultTooltip(row)
    PaperDollStatTooltip(row, "player")
end

-- Own resistance row: the stock version writes into the fixed MagicResFrame
-- widgets that the retail layout no longer shows.
local function SetResistanceRow(row, school)
    local base, resistance, positive, negative = UnitResistance("player", school)
    local label = _G["SPELL_SCHOOL" .. school .. "_CAP"] or ("School " .. school)
    _G[row:GetName() .. "Label"]:SetText(string.format(STAT_FORMAT or "%s:", label))
    local text = _G[row:GetName() .. "StatText"]
    if math.abs(negative) > positive then
        text:SetText(RED_FONT_COLOR_CODE .. resistance .. FONT_COLOR_CODE_CLOSE)
    elseif math.abs(negative) == positive then
        text:SetText(resistance)
    else
        text:SetText(GREEN_FONT_COLOR_CODE .. resistance .. FONT_COLOR_CODE_CLOSE)
    end

    local name = _G["RESISTANCE" .. school .. "_NAME"] or label
    local tooltip = string.format(PAPERDOLLFRAME_TOOLTIP_FORMAT or "%s", name) .. " " .. resistance
    if positive ~= 0 or negative ~= 0 then
        tooltip = tooltip .. " ( " .. HIGHLIGHT_FONT_COLOR_CODE .. base
        if positive > 0 then
            tooltip = tooltip .. GREEN_FONT_COLOR_CODE .. " +" .. positive
        end
        if negative < 0 then
            tooltip = tooltip .. " " .. RED_FONT_COLOR_CODE .. negative
        end
        tooltip = tooltip .. FONT_COLOR_CODE_CLOSE .. " )"
    end
    row.tooltip = HIGHLIGHT_FONT_COLOR_CODE .. tooltip .. FONT_COLOR_CODE_CLOSE

    local unitLevel = math.max(UnitLevel("player"), 20)
    local ratio = resistance / unitLevel
    local quality
    if ratio > 5 then
        quality = RESISTANCE_EXCELLENT
    elseif ratio > 3.75 then
        quality = RESISTANCE_VERYGOOD
    elseif ratio > 2.5 then
        quality = RESISTANCE_GOOD
    elseif ratio > 1.25 then
        quality = RESISTANCE_FAIR
    elseif ratio > 0 then
        quality = RESISTANCE_POOR
    else
        quality = RESISTANCE_NONE
    end
    row.tooltip2 = string.format(RESISTANCE_TOOLTIP_SUBTEXT or "%s %d %s",
        _G["RESISTANCE_TYPE" .. school] or label, unitLevel, quality or "")
end

local SETTERS = {
    stat = function(row, index) PaperDollFrame_SetStat(row, index) end,
    armor = function(row) PaperDollFrame_SetArmor(row, "player") end,
    damage = function(row)
        PaperDollFrame_SetDamage(row, "player")
        row:SetScript("OnEnter", CharacterDamageFrame_OnEnter)
    end,
    attackspeed = function(row) PaperDollFrame_SetAttackSpeed(row, "player") end,
    attackpower = function(row) PaperDollFrame_SetAttackPower(row, "player") end,
    rating = function(row, index) PaperDollFrame_SetRating(row, index) end,
    meleecrit = function(row) PaperDollFrame_SetMeleeCritChance(row) end,
    expertise = function(row) PaperDollFrame_SetExpertise(row, "player") end,
    rangeddamage = function(row)
        PaperDollFrame_SetRangedDamage(row, "player")
        row:SetScript("OnEnter", CharacterRangedDamageFrame_OnEnter)
    end,
    rangedattackspeed = function(row) PaperDollFrame_SetRangedAttackSpeed(row, "player") end,
    rangedattackpower = function(row) PaperDollFrame_SetRangedAttackPower(row, "player") end,
    rangedcrit = function(row) PaperDollFrame_SetRangedCritChance(row) end,
    spellbonusdamage = function(row)
        PaperDollFrame_SetSpellBonusDamage(row)
        row:SetScript("OnEnter", CharacterSpellBonusDamage_OnEnter)
    end,
    spellbonushealing = function(row) PaperDollFrame_SetSpellBonusHealing(row) end,
    spellcrit = function(row)
        PaperDollFrame_SetSpellCritChance(row)
        row:SetScript("OnEnter", CharacterSpellCritChance_OnEnter)
    end,
    spellhaste = function(row) PaperDollFrame_SetSpellHaste(row) end,
    manaregen = function(row) PaperDollFrame_SetManaRegen(row) end,
    spellpen = function(row) PaperDollFrame_SetSpellPenetration(row) end,
    defense = function(row) PaperDollFrame_SetDefense(row, "player") end,
    dodge = function(row) PaperDollFrame_SetDodge(row) end,
    parry = function(row) PaperDollFrame_SetParry(row) end,
    block = function(row) PaperDollFrame_SetBlock(row) end,
    resilience = function(row) PaperDollFrame_SetResilience(row) end,
    resist = SetResistanceRow,
    hit = SetHitRow,
    hastepct = SetHastePctRow,
    arp = SetArmorPenRow,
    avoidance = SetAvoidanceRow,
    blockvalue = SetBlockValueRow,
    movespeed = SetMoveSpeedRow,
    manaregencasting = SetManaRegenCastingRow,
}

-- ---------------------------------------------------------------------------
-- Collapsed state. Everything starts expanded like retail; a category only
-- collapses when the player clicks its header, and that choice is saved.
-- Layout version 2 dropped the old per-class defaults (which collapsed e.g.
-- Ranged/Spell/Resistances for rogues and looked like empty categories).
-- ---------------------------------------------------------------------------

local STATS_LAYOUT_VERSION = 2

local function Collapsed()
    local db = DCCF.db
    if db.statsLayoutVersion ~= STATS_LAYOUT_VERSION then
        db.collapsedStats = {}
        db.statsLayoutVersion = STATS_LAYOUT_VERSION
    end
    if not db.collapsedStats then
        db.collapsedStats = {}
    end
    return db.collapsedStats
end

-- ---------------------------------------------------------------------------
-- Item level
-- ---------------------------------------------------------------------------

local ILVL_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

function DCCF:GetAverageItemLevel()
    local total, count = 0, 0
    local mainHandLoc, mainHandLevel
    for _, slotId in ipairs(ILVL_SLOTS) do
        local link = GetInventoryItemLink("player", slotId)
        if link then
            local _, _, _, level, _, _, _, _, equipLoc = GetItemInfo(link)
            -- Upgraded items: prefer the server-side item level from DC-ItemUpgrade.
            if self.GetSlotUpgradeInfo then
                local info = self:GetSlotUpgradeInfo(slotId)
                if info and info.itemLevel and info.itemLevel > 0 then
                    level = info.itemLevel
                end
            end
            if slotId == 16 then
                mainHandLoc, mainHandLevel = equipLoc, level
            end
            if level and level > 0 then
                total = total + level
                count = count + 1
            end
        end
    end
    -- A two-hander with an empty off hand fills both weapon slots.
    if mainHandLevel and mainHandLoc == "INVTYPE_2HWEAPON" and not GetInventoryItemLink("player", 17) then
        total = total + mainHandLevel
        count = count + 1
    end
    if count == 0 then
        return 0, 0
    end
    return total / count, count
end

function DCCF:UpdateItemLevelDisplay()
    local pane = self.statsPane
    if not pane then
        return
    end
    local avg, count = self:GetAverageItemLevel()
    pane.ilvlValue:SetText(math.floor(avg + 0.5))
    pane.ilvlFrame.average = avg
    pane.ilvlFrame.count = count
end

-- ---------------------------------------------------------------------------
-- Pane construction
-- ---------------------------------------------------------------------------

local function CreateHeader(content, title, key)
    local hdr = CreateFrame("Button", nil, content)
    hdr:SetWidth(CONTENT_W)
    hdr:SetHeight(HDR_H)
    local bg = Tex(hdr, "BACKGROUND", DCCF.TEX_INFO1, DCCF.INFO.Title)
    bg:SetAllPoints(hdr)
    local text = hdr:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("CENTER", 0, 1)
    text:SetText(title)
    hdr.Text = text
    if key then
        local toggle = Tex(hdr, "OVERLAY", DCCF.TEX_PARTS, DCCF.PARTS.StatMinus)
        toggle:SetPoint("LEFT", 12, 1)
        hdr.Toggle = toggle
        hdr.key = key
        local hl = hdr:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hl:SetBlendMode("ADD")
        hl:SetPoint("TOPLEFT", 8, -6)
        hl:SetPoint("BOTTOMRIGHT", -8, 6)
        hl:SetAlpha(0.35)
        hdr:SetScript("OnClick", function(self)
            local collapsed = Collapsed()
            collapsed[self.key] = not collapsed[self.key] or nil
            PlaySound("igMainMenuOptionCheckBoxOn")
            DCCF:LayoutStats()
            DCCF:UpdateStats()
        end)
        hdr:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.Text:GetText(), 1, 1, 1)
            if Collapsed()[self.key] then
                GameTooltip:AddLine("Collapsed. Click to show these stats.", 0.8, 0.8, 0.8, true)
            else
                GameTooltip:AddLine("Click to collapse this category.", 0.8, 0.8, 0.8, true)
            end
            GameTooltip:Show()
        end)
        hdr:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    return hdr
end

local function CreateRow(content, index)
    local row = CreateFrame("Frame", "DCCharacterStatRow" .. index, content, "StatFrameTemplate")
    row:SetWidth(CONTENT_W)
    row:SetHeight(ROW_H)
    local name = row:GetName()
    local label = _G[name .. "Label"]
    label:ClearAllPoints()
    label:SetPoint("LEFT", row, "LEFT", 8, 0)
    local statFrame = _G[name .. "Stat"]
    statFrame:ClearAllPoints()
    statFrame:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    statFrame:SetWidth(70)
    statFrame:SetHeight(ROW_H)

    local bg = Tex(row, "BACKGROUND", DCCF.TEX_INFO1, DCCF.INFO.LineBounce)
    bg:SetPoint("CENTER")
    bg:SetAlpha(0.3)
    row.Background = bg

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetAllPoints(row)
    hl:SetAlpha(0.3)
    return row
end

function DCCF:BuildStatsPane(parent)
    local pane = CreateFrame("Frame", "DCCharacterStatsPane", parent)
    pane:SetPoint("TOPLEFT", parent, "TOPLEFT", 3, -3)
    pane:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -3, 2)
    pane:SetFrameLevel(parent:GetFrameLevel() + 1)
    self.statsPane = pane

    local _, class = UnitClass("player")
    local classDef = class and self.CLASS_BG[class]
    if classDef then
        local bg = pane:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(classDef[1] == 1 and self.TEX_INFO1 or self.TEX_INFO2)
        bg:SetTexCoord(classDef[2], classDef[3], classDef[4], classDef[5])
        bg:SetPoint("TOPLEFT")
        bg:SetPoint("BOTTOMRIGHT")
    end

    local scroll = CreateFrame("ScrollFrame", "DCCharacterStatsScrollFrame", pane, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -22, 0)
    local content = CreateFrame("Frame", "DCCharacterStatsScrollChild", scroll)
    content:SetWidth(CONTENT_W)
    content:SetHeight(400)
    scroll:SetScrollChild(content)
    pane.scroll = scroll
    pane.content = content

    -- Item level block.
    pane.ilvlHeader = CreateHeader(content, "Item Level")
    local ilvlFrame = CreateFrame("Frame", nil, content)
    ilvlFrame:SetWidth(CONTENT_W)
    ilvlFrame:SetHeight(ILVL_H)
    local bounce = Tex(ilvlFrame, "BORDER", self.TEX_INFO1, self.INFO.ItemLevelBounce)
    bounce:SetPoint("CENTER")
    bounce:SetAlpha(0.3)
    local value = ilvlFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    local fontPath, fontSize = GameFontNormalLarge:GetFont()
    value:SetFont(fontPath, (fontSize or 16), "OUTLINE")
    value:SetPoint("CENTER", 0, -1)
    value:SetTextColor(1, 1, 1)
    value:SetText("0")
    ilvlFrame:EnableMouse(true)
    ilvlFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(string.format("Item Level %d", math.floor((self.average or 0) + 0.5)), 1, 1, 1)
        GameTooltip:AddLine(string.format("Average item level of your %d equipped items.", self.count or 0), 1, 0.82, 0, true)
        GameTooltip:AddLine("Upgraded items count with their upgraded item level.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    ilvlFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    pane.ilvlFrame = ilvlFrame
    pane.ilvlValue = value

    -- Category headers and their rows.
    local rowIndex = 0
    pane.categories = {}
    for _, cat in ipairs(CATEGORIES) do
        local entry = { def = cat, header = CreateHeader(content, cat.title, cat.key), rows = {} }
        for _, stat in ipairs(cat.stats) do
            rowIndex = rowIndex + 1
            local row = CreateRow(content, rowIndex)
            row.statKind = stat[1]
            row.statArg = stat[2]
            table.insert(entry.rows, row)
        end
        table.insert(pane.categories, entry)
    end

    self:LayoutStats()
    return pane
end

function DCCF:LayoutStats()
    local pane = self.statsPane
    if not pane then
        return
    end
    local content = pane.content
    local collapsed = Collapsed()
    local y = -2

    pane.ilvlHeader:ClearAllPoints()
    pane.ilvlHeader:SetPoint("TOP", content, "TOP", 0, y)
    y = y - HDR_H
    pane.ilvlFrame:ClearAllPoints()
    pane.ilvlFrame:SetPoint("TOP", content, "TOP", 0, y)
    y = y - ILVL_H

    for _, entry in ipairs(pane.categories) do
        local hdr = entry.header
        hdr:ClearAllPoints()
        hdr:SetPoint("TOP", content, "TOP", 0, y)
        y = y - HDR_H
        local isCollapsed = collapsed[entry.def.key]
        local piece = isCollapsed and self.PARTS.StatPlus or self.PARTS.StatMinus
        hdr.Toggle:SetWidth(piece[1])
        hdr.Toggle:SetHeight(piece[2])
        hdr.Toggle:SetTexCoord(piece[3], piece[4], piece[5], piece[6])
        for i, row in ipairs(entry.rows) do
            row:ClearAllPoints()
            if isCollapsed then
                row:Hide()
            else
                row:SetPoint("TOP", content, "TOP", 0, y - (i == 1 and 2 or 0))
                y = y - ROW_H - (i == 1 and 2 or 0)
                if i % 2 == 0 then
                    row.Background:Show()
                else
                    row.Background:Hide()
                end
                row:Show()
            end
        end
    end
    content:SetHeight(math.max(1, -y + 4))
    pane.scroll:UpdateScrollChildRect()
    -- Collapsing can shrink the content below the current scroll offset.
    local maxScroll = math.max(0, (content:GetHeight() or 0) - (pane.scroll:GetHeight() or 0))
    if (pane.scroll:GetVerticalScroll() or 0) > maxScroll then
        pane.scroll:SetVerticalScroll(maxScroll)
    end
end

function DCCF:UpdateStats()
    local pane = self.statsPane
    if not pane or not pane:IsVisible() then
        return
    end
    self:UpdateItemLevelDisplay()
    local collapsed = Collapsed()
    for _, entry in ipairs(pane.categories) do
        if not collapsed[entry.def.key] then
            for _, row in ipairs(entry.rows) do
                row:SetScript("OnEnter", DefaultTooltip)
                local setter = SETTERS[row.statKind]
                if setter then
                    setter(row, row.statArg)
                end
            end
        end
    end
end

function DCCF:OnEquipmentChanged()
    self:UpdateItemLevelDisplay()
    if self.RefreshUpgradesPane then
        self:RefreshUpgradesPane()
    end
end

-- The stock frame already recomputes on every relevant event; ride along.
hooksecurefunc("PaperDollFrame_UpdateStats", function()
    DCCF:UpdateStats()
end)

DCCF:RegisterSidebar({
    key = "stats",
    name = PAPERDOLL_SIDEBAR_STATS or "Character Stats",
    portrait = true,
    build = function(parent) return DCCF:BuildStatsPane(parent) end,
    IsActive = function() return true end,
    onShow = function() DCCF:UpdateStats() end,
})
