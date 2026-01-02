-- ============================================================
-- DC-QoS: Extended Character Stats Module
-- ============================================================
-- Provides an ExtendedCharacterStats-style view on the Character window
-- for WoW 3.3.5a.
-- ============================================================

local addon = DCQOS

local ExtendedStats = {
    displayName = "Extended Stats",
    settingKey = "extendedStats",
    icon = "Interface\\Icons\\INV_Misc_Book_09",
    defaults = {
        extendedStats = {
            enabled = true,
        },
    },
}

local function SafeNumber(n)
    if type(n) ~= "number" then
        return nil
    end
    if n ~= n or n == math.huge or n == -math.huge then
        return nil
    end
    return n
end

local function FmtPercent(p)
    p = SafeNumber(p)
    if not p then
        return "-"
    end
    return string.format("%.2f%%", p)
end

local function GetCombatRatingSafe(cr)
    if not cr or type(GetCombatRating) ~= "function" then
        return nil
    end
    return SafeNumber(GetCombatRating(cr))
end

local function GetCombatRatingBonusSafe(cr)
    if not cr or type(GetCombatRatingBonus) ~= "function" then
        return nil
    end
    return SafeNumber(GetCombatRatingBonus(cr))
end

local function FormatRatingAndBonus(cr)
    local rating = GetCombatRatingSafe(cr)
    local bonus = GetCombatRatingBonusSafe(cr)

    if not rating and not bonus then
        return "-"
    end

    rating = rating or 0
    bonus = bonus or 0
    return string.format("%d (%s)", rating, FmtPercent(bonus))
end

local function BestSpellCrit()
    if type(GetSpellCritChance) ~= "function" then
        return nil
    end

    local best
    for school = 1, 7 do
        local v = SafeNumber(GetSpellCritChance(school))
        if v and (not best or v > best) then
            best = v
        end
    end
    return best
end

local function BestSpellPower()
    if type(GetSpellBonusDamage) ~= "function" then
        return nil
    end

    local best
    for school = 1, 7 do
        local v = SafeNumber(GetSpellBonusDamage(school))
        if v and (not best or v > best) then
            best = v
        end
    end
    return best
end

local function GetArmorText()
    if type(UnitArmor) ~= "function" then
        return "-"
    end

    local base, effective = UnitArmor("player")
    effective = SafeNumber(effective)
    base = SafeNumber(base)

    if effective then
        return string.format("%d", effective)
    end
    if base then
        return string.format("%d", base)
    end
    return "-"
end

local function GetDefenseText()
    if type(UnitDefense) ~= "function" then
        return "-"
    end

    local base, mod = UnitDefense("player")
    base = SafeNumber(base) or 0
    mod = SafeNumber(mod) or 0
    return string.format("%d", base + mod)
end

local function CreateLine(parent, yOffset, labelText)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)

    local value = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    value:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    value:SetJustifyH("RIGHT")
    value:SetText("-")

    return label, value
end

local function CreateHeader(parent, yOffset, text)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    header:SetJustifyH("LEFT")
    header:SetText(text)
    return header
end

local function TryBuildUI()
    if ExtendedStats._built then
        return true
    end

    if not CharacterFrame or (not PaperDollFrame and not PaperDollItemsFrame) then
        return false
    end

    -- ExtendedCharacterStats anchors its window to PaperDollItemsFrame.
    -- We'll do the same and also force a high strata/level so the character model
    -- can't draw above this panel.
    local anchor = PaperDollItemsFrame or PaperDollFrame
    local rightInset = CharacterFrameInsetRight or anchor or CharacterFrame

    -- Parent to the PaperDoll tab when possible so the panel moves with it.
    -- In 3.3.5a, PaperDollItemsFrame may not exist; PaperDollFrame does.
    local parentForPanel = anchor or rightInset

    -- Main stats frame
    local frame = CreateFrame("Frame", "DCQoSExtendedStatsFrame", parentForPanel)

    local function UpdateLayout()
        local a = anchor or rightInset
        if not a then
            return
        end

        frame:ClearAllPoints()
        -- ECS-style: attached to the right side of the character page.
        frame:SetPoint("TOPLEFT", a, "TOPRIGHT", 10, 0)
        frame:SetPoint("BOTTOMLEFT", a, "BOTTOMRIGHT", 10, 0)
        frame:SetWidth(190)
    end

    UpdateLayout()
    frame:Hide()

    -- Ensure we're not rendered behind the character model.
    frame:SetFrameStrata("DIALOG")
    local baseLevel = (CharacterFrame and CharacterFrame.GetFrameLevel and CharacterFrame:GetFrameLevel()) or 0
    frame:SetFrameLevel(baseLevel + 100)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetTexture(0, 0, 0, 0.25)

    -- Scrollable area
    local scroll = CreateFrame("ScrollFrame", "DCQoSExtendedStatsScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -6)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 6)

    scroll:SetFrameLevel(frame:GetFrameLevel() + 1)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    content:SetFrameLevel(scroll:GetFrameLevel() + 1)

    frame.scrollFrame = scroll
    frame.content = content

    -- Layout
    local y = -10
    CreateHeader(content, y, "Melee")
    y = y - 18
    local _, meleeHit = CreateLine(content, y, "Hit")
    y = y - 14
    local _, meleeCrit = CreateLine(content, y, "Crit")
    y = y - 14
    local _, meleeHaste = CreateLine(content, y, "Haste")
    y = y - 14
    local _, meleeExpertise = CreateLine(content, y, "Expertise")
    y = y - 14
    local _, meleeArPen = CreateLine(content, y, "Armor Pen")

    y = y - 22
    CreateHeader(content, y, "Ranged")
    y = y - 18
    local _, rangedHit = CreateLine(content, y, "Hit")
    y = y - 14
    local _, rangedCrit = CreateLine(content, y, "Crit")
    y = y - 14
    local _, rangedHaste = CreateLine(content, y, "Haste")

    y = y - 22
    CreateHeader(content, y, "Spell")
    y = y - 18
    local _, spellHit = CreateLine(content, y, "Hit")
    y = y - 14
    local _, spellCrit = CreateLine(content, y, "Crit (best)")
    y = y - 14
    local _, spellHaste = CreateLine(content, y, "Haste")
    y = y - 14
    local _, spellPower = CreateLine(content, y, "Spell Power (best)")

    y = y - 22
    CreateHeader(content, y, "Defense")
    y = y - 18
    local _, armor = CreateLine(content, y, "Armor")
    y = y - 14
    local _, defense = CreateLine(content, y, "Defense")
    y = y - 14
    local _, dodge = CreateLine(content, y, "Dodge")
    y = y - 14
    local _, parry = CreateLine(content, y, "Parry")
    y = y - 14
    local _, block = CreateLine(content, y, "Block")
    y = y - 14
    local _, resilience = CreateLine(content, y, "Resilience")

    content:SetHeight(math.max(1, -y + 30))

    local function UpdateStats()
        -- Combat ratings constants exist in 3.3.5a; fall back safely if not.
        meleeHit:SetText(FormatRatingAndBonus(_G.CR_HIT_MELEE))
        meleeHaste:SetText(FormatRatingAndBonus(_G.CR_HASTE_MELEE))
        meleeExpertise:SetText(FormatRatingAndBonus(_G.CR_EXPERTISE))
        meleeArPen:SetText(FormatRatingAndBonus(_G.CR_ARMOR_PENETRATION))

        if type(GetCritChance) == "function" then
            meleeCrit:SetText(FmtPercent(GetCritChance()))
        else
            meleeCrit:SetText("-")
        end

        rangedHit:SetText(FormatRatingAndBonus(_G.CR_HIT_RANGED))
        rangedHaste:SetText(FormatRatingAndBonus(_G.CR_HASTE_RANGED))
        if type(GetRangedCritChance) == "function" then
            rangedCrit:SetText(FmtPercent(GetRangedCritChance()))
        else
            rangedCrit:SetText("-")
        end

        spellHit:SetText(FormatRatingAndBonus(_G.CR_HIT_SPELL))
        spellHaste:SetText(FormatRatingAndBonus(_G.CR_HASTE_SPELL))

        local sc = BestSpellCrit()
        if sc then
            spellCrit:SetText(FmtPercent(sc))
        else
            spellCrit:SetText("-")
        end

        local sp = BestSpellPower()
        if sp then
            spellPower:SetText(string.format("%d", sp))
        else
            spellPower:SetText("-")
        end

        armor:SetText(GetArmorText())
        defense:SetText(GetDefenseText())

        if type(GetDodgeChance) == "function" then
            dodge:SetText(FmtPercent(GetDodgeChance()))
        else
            dodge:SetText("-")
        end

        if type(GetParryChance) == "function" then
            parry:SetText(FmtPercent(GetParryChance()))
        else
            parry:SetText("-")
        end

        if type(GetBlockChance) == "function" then
            block:SetText(FmtPercent(GetBlockChance()))
        else
            block:SetText("-")
        end

        -- Resilience in WotLK is represented as crit-taken reduction ratings.
        resilience:SetText(FormatRatingAndBonus(_G.CR_CRIT_TAKEN_MELEE))
    end

    -- Update events while frame is visible
    frame:SetScript("OnShow", function()
        UpdateStats()
    end)

    frame:SetScript("OnEvent", function()
        if frame:IsShown() then
            UpdateStats()
        end
    end)

    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    frame:RegisterEvent("UNIT_STATS")
    frame:RegisterEvent("UNIT_DAMAGE")
    frame:RegisterEvent("UNIT_ATTACK_POWER")
    frame:RegisterEvent("UNIT_RANGED_ATTACK_POWER")
    frame:RegisterEvent("UNIT_ATTACK_SPEED")
    frame:RegisterEvent("UNIT_AURA")
    frame:RegisterEvent("COMBAT_RATING_UPDATE")

    -- Always show on the Character (PaperDoll) tab
    local showHook = PaperDollItemsFrame or PaperDollFrame
    showHook:HookScript("OnShow", function()
        -- Next frame: anchors/sizes are reliable once the panel is visible.
        addon:DelayedCall(0, function()
            UpdateLayout()
            frame:Show()
        end)
    end)
    showHook:HookScript("OnHide", function()
        frame:Hide()
    end)

    ExtendedStats._frame = frame
    ExtendedStats._built = true

    return true
end

function ExtendedStats.OnInitialize()
    addon:Debug("ExtendedStats module initializing")
end

function ExtendedStats.OnEnable()
    addon:Debug("ExtendedStats module enabling")

    addon:DelayedCall(0, function()
        if TryBuildUI() then
            -- Initialize visibility state based on current UI
            if PaperDollFrame and PaperDollFrame:IsShown() then
                ExtendedStats._frame:Show()
            else
                ExtendedStats._frame:Hide()
            end
        end
    end)
end

function ExtendedStats.OnDisable()
    addon:Debug("ExtendedStats module disabling")
    if ExtendedStats._frame then
        ExtendedStats._frame:Hide()
    end
end

function ExtendedStats.CreateSettings(parent)
    local settings = addon.settings.extendedStats

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Extended Stats")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Shows extended combat stats on the Character window.")
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")

    local yOffset = -70

    local enabledCb = addon:CreateCheckbox(parent)
    enabledCb:SetPoint("TOPLEFT", 16, yOffset)
    enabledCb.Text:SetText("Enable Extended Stats")
    enabledCb:SetChecked(settings.enabled ~= false)
    enabledCb:SetScript("OnClick", function(self)
        addon:SetSetting("extendedStats.enabled", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)

    return yOffset - 40
end

addon:RegisterModule("ExtendedStats", ExtendedStats)
