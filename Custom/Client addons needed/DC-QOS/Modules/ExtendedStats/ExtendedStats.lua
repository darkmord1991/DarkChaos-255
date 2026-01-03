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
            show = true,
            anchorOffsetX = -2,
            anchorOffsetY = -12,
            -- General
            showMovementSpeed = true,
            -- Melee
            showMeleeAP = true,
            showMeleeHit = true,
            showMeleeCrit = true,
            showMeleeHaste = true,
            showMeleeExpertise = true,
            showMeleeExpertiseRating = true,
            showMeleeArPen = true,
            showMeleeMiss = true,
            showMeleeMissBoss = true,
            -- Ranged
            showRangedAP = true,
            showRangedHit = true,
            showRangedCrit = true,
            showRangedHaste = true,
            showRangedArPen = true,
            showRangedMiss = true,
            showRangedMissBoss = true,
            -- Spell
            showSpellPower = true,
            showSpellPenetration = true,
            showSpellHit = true,
            showSpellCrit = true,
            showSpellHaste = true,
            showSpellMiss = true,
            showSpellMissBoss = true,
            showSpellSchools = false,
            -- Defense
            showArmor = true,
            showDefense = true,
            showDefenseRating = true,
            showAvoidance = true,
            showDodge = true,
            showParry = true,
            showBlock = true,
            showBlockValue = true,
            showResilience = true,
            -- Regen
            showMP5Casting = true,
            showMP5NotCasting = true,
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

local function GetMovementSpeed()
    local speed = GetUnitSpeed("player")
    if speed and speed > 0 then
        return string.format("%.1f%%", (speed / 7) * 100)
    end
    return "100.0%"
end

local function GetAvoidance()
    local dodge = SafeNumber(GetDodgeChance()) or 0
    local parry = SafeNumber(GetParryChance()) or 0
    local miss = SafeNumber(GetParryChance()) or 5 -- Base 5% miss
    return string.format("%.2f%%", dodge + parry + miss)
end

local function GetMeleeHitChance()
    local hitBonus = GetCombatRatingBonusSafe(_G.CR_HIT_MELEE) or 0
    return hitBonus
end

local function GetMeleeMissChance(bossLevel)
    local hitBonus = GetMeleeHitChance()
    local baseMiss = bossLevel and 8.0 or 5.0 -- 8% vs boss, 5% vs same level
    local missChance = baseMiss - hitBonus
    return math.max(0, missChance)
end

local function GetRangedMissChance(bossLevel)
    local hitBonus = GetCombatRatingBonusSafe(_G.CR_HIT_RANGED) or 0
    local baseMiss = bossLevel and 8.0 or 5.0
    local missChance = baseMiss - hitBonus
    return math.max(0, missChance)
end

local function GetSpellMissChance(bossLevel)
    local hitBonus = GetCombatRatingBonusSafe(_G.CR_HIT_SPELL) or 0
    local baseMiss = bossLevel and 17.0 or 4.0 -- 17% vs boss, 4% vs same level
    local missChance = baseMiss - hitBonus
    return math.max(0, missChance)
end

local SPELL_SCHOOLS = {
    {name = "Arcane", id = 1},
    {name = "Fire", id = 2},
    {name = "Frost", id = 4},
    {name = "Nature", id = 3},
    {name = "Shadow", id = 5},
    {name = "Holy", id = 6},
}

local function GetSpellDamageForSchool(schoolId)
    if type(GetSpellBonusDamage) ~= "function" then
        return nil
    end
    return SafeNumber(GetSpellBonusDamage(schoolId))
end

local function GetSpellCritForSchool(schoolId)
    if type(GetSpellCritChance) ~= "function" then
        return nil
    end
    return SafeNumber(GetSpellCritChance(schoolId))
end

local function CreateLine(parent, yOffset, labelText, isAlt)
    local line = CreateFrame("Frame", nil, parent)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOffset)
    line:SetPoint("RIGHT", parent, "RIGHT", -4, 0)
    line:SetHeight(12)

    if isAlt then
        local bg = line:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(1, 1, 1, 0.05) -- Faint highlight
    end

    local label = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", line, "LEFT", 4, 0)
    label:SetText(labelText)

    local value = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    value:SetPoint("RIGHT", line, "RIGHT", -4, 0)
    value:SetText("-")

    return label, value
end

local function CreateHeader(parent, yOffset, text)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    header:SetText(text)
    
    local underline = parent:CreateTexture(nil, "ARTWORK")
    underline:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    underline:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    underline:SetHeight(1)
    underline:SetTexture(1, 1, 1, 0.2)
    
    return header
end

local function ApplyStyle(frame)
    if not frame then return end
    
    -- Keep the border from SetBackdrop, but clear the background color
    frame:SetBackdropColor(0, 0, 0, 0)

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
    bg:SetPoint("TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)
    bg:SetTexture("Interface\\AddOns\\DC-QOS\\Textures\\Backgrounds\\FelLeather_512.tga")
    
    -- Enable tiling to prevent stretching
    if bg.SetHorizTile then bg:SetHorizTile(true) end
    if bg.SetVertTile then bg:SetVertTile(true) end
    
    -- Tiling via TexCoord for robustness
    frame:SetScript("OnSizeChanged", function(self, w, h)
        if w and h then
            bg:SetTexCoord(0, w / 512, 0, h / 512)
        end
    end)
    
    frame.bgTexture = bg

    local tint = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    tint:SetAllPoints()
    tint:SetTexture(0, 0, 0, 0.5) -- Adjust alpha as needed
end

local function TryBuildUI()
    if ExtendedStats._built then
        return true
    end

    if not CharacterFrame or (not PaperDollFrame and not PaperDollItemsFrame) then
        return false
    end

    -- Main stats frame (parented to CharacterFrame)
    local frame = CreateFrame("Frame", "DCQoSExtendedStatsFrame", CharacterFrame)
    frame:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    
    ApplyStyle(frame)

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", 0, -8)
    title:SetText("Extended Stats")

    -- Drag handle (title bar)
    local drag = CreateFrame("Button", nil, frame)
    drag:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    drag:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, -6) -- leave space for gear
    drag:SetHeight(20)
    drag:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        if frame:IsShown() then
            frame:StartMoving()
        end
    end)

    local function SaveAnchorOffsets()
        if not CharacterFrame then
            return
        end

        local left = frame:GetLeft()
        local top = frame:GetTop()
        local charRight = CharacterFrame:GetRight()
        local charTop = CharacterFrame:GetTop()

        if left and top and charRight and charTop then
            addon:SetSetting("extendedStats.anchorOffsetX", left - charRight)
            addon:SetSetting("extendedStats.anchorOffsetY", top - charTop)
        end
    end

    drag:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SaveAnchorOffsets()
        if frame.UpdateLayout then
            frame:UpdateLayout()
        end
    end)
    
    -- Settings Button (gear in ES title bar)
    local settingsBtn = CreateFrame("Button", "DCQoSExtendedStatsSettings", frame)
    settingsBtn:SetSize(26, 26)
    settingsBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -6)
    settingsBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    settingsBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    settingsBtn:SetScript("OnClick", function()
        if addon and addon.ToggleSettings then
            addon:ToggleSettings()
            if addon.ShowTab then
                addon:ShowTab("ExtendedStats")
            end
        end
    end)
    settingsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Settings")
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    settingsBtn:SetFrameStrata("HIGH")
    settingsBtn:SetFrameLevel(frame:GetFrameLevel() + 10)
    settingsBtn:Show()
    
    -- Toggle Button (below settings on right edge)
    local toggleBtn = CreateFrame("Button", "DCQoSExtendedStatsToggle", frame)
    toggleBtn:SetSize(32, 32)
    toggleBtn:SetPoint("LEFT", frame, "RIGHT", 4, 20)
    toggleBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    toggleBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    toggleBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    toggleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Toggle Panel")
        GameTooltip:Show()
    end)
    toggleBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    toggleBtn:SetFrameStrata("HIGH")
    toggleBtn:Show()

    local function ReanchorExternalButtons()
        local prev = toggleBtn
        local function Attach(btn)
            if not btn or not btn.ClearAllPoints or not btn.SetPoint then
                return
            end

            if btn.GetName and btn:GetName() == "DCQoSExtendedStatsToggle" then
                return
            end

            if btn.SetParent then
                btn:SetParent(frame)
            end
            btn:ClearAllPoints()
            btn:SetPoint("TOP", prev, "BOTTOM", 0, -5)
            if btn.SetFrameStrata then
                btn:SetFrameStrata("HIGH")
            end
            btn:Show()
            prev = btn
        end

        Attach(_G.DC_ItemUpgrade_CharFrameButton)
        Attach(_G.DC_ItemUpgrade_HeirloomButton)
        Attach(_G.DC_Collection_CharFrameButton)
        -- Optional: if your transmog button exists under a known name, add it here.
        Attach(_G.DC_Transmog_CharFrameButton)
    end

    local function UpdateLayout()
        frame:ClearAllPoints()
        -- Attach to the Character window (right side), with user offsets
        local dx = (addon.settings and addon.settings.extendedStats and addon.settings.extendedStats.anchorOffsetX)
        if dx == nil then
            dx = -2
        elseif dx == 0 then
            -- Treat old default as flush
            dx = -2
        end
        local dy = (addon.settings and addon.settings.extendedStats and addon.settings.extendedStats.anchorOffsetY) or -12
        frame:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", dx, dy)
        frame:SetHeight(CharacterFrame:GetHeight() - 24)
        frame:SetWidth(200)
    end

    frame.UpdateLayout = UpdateLayout

    UpdateLayout()
    
    -- Visibility logic
    local function UpdateVisibility()
        local show = addon.settings.extendedStats.show
        if show then
            frame:Show()
            settingsBtn:Show()
            toggleBtn:Show()
            -- Re-anchor 3rd-party buttons after we show
            ReanchorExternalButtons()
            toggleBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
            toggleBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
        else
            frame:Hide()
            settingsBtn:Hide()
            toggleBtn:Show()
            if _G.DC_ItemUpgrade_CharFrameButton then _G.DC_ItemUpgrade_CharFrameButton:Hide() end
            if _G.DC_ItemUpgrade_HeirloomButton then _G.DC_ItemUpgrade_HeirloomButton:Hide() end
            if _G.DC_Collection_CharFrameButton then _G.DC_Collection_CharFrameButton:Hide() end
            if _G.DC_Transmog_CharFrameButton then _G.DC_Transmog_CharFrameButton:Hide() end
            toggleBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
            toggleBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
        end
    end

    toggleBtn:SetScript("OnClick", function()
        local newState = not addon.settings.extendedStats.show
        addon:SetSetting("extendedStats.show", newState)
        UpdateVisibility()
    end)

    -- Ensure we're not rendered behind the character model.
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(CharacterFrame:GetFrameLevel() + 2)
    
    -- Initial visibility
    UpdateVisibility()

    -- Some buttons load later; re-anchor shortly after.
    if addon.DelayedCall then
        addon:DelayedCall(0.2, function()
            if addon.settings.extendedStats.show then
                ReanchorExternalButtons()
            end
        end)
        addon:DelayedCall(1.0, function()
            if addon.settings.extendedStats.show then
                ReanchorExternalButtons()
            end
        end)
    end

    -- Scrollable area
    local scroll = CreateFrame("ScrollFrame", "DCQoSExtendedStatsScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -28)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(180, 400)
    scroll:SetScrollChild(content)

    frame.scrollFrame = scroll
    frame.content = content

    -- Layout
    local y = -5
    local stats = {}
    local alt = false
    local settings = addon.settings.extendedStats
    
    -- Helper to add stat line
    local function AddStat(key, label)
        if settings["show" .. key] then
            local _, value = CreateLine(content, y, label, alt)
            stats[key] = value
            y = y - 12
            alt = not alt
        end
    end
    
    -- General
    if settings.showMovementSpeed then
        CreateHeader(content, y, "General")
        y = y - 16
        alt = false
        AddStat("MovementSpeed", "Movement Speed")
    end
    
    -- Melee
    if settings.showMeleeAP or settings.showMeleeHit or settings.showMeleeCrit or settings.showMeleeHaste or 
       settings.showMeleeExpertise or settings.showMeleeExpertiseRating or settings.showMeleeArPen or
       settings.showMeleeMiss or settings.showMeleeMissBoss then
        y = y - 6
        CreateHeader(content, y, "Melee")
        y = y - 16
        alt = false
        AddStat("MeleeAP", "Attack Power")
        AddStat("MeleeHit", "Hit")
        AddStat("MeleeCrit", "Crit")
        AddStat("MeleeHaste", "Haste")
        AddStat("MeleeExpertise", "Expertise")
        AddStat("MeleeExpertiseRating", "Expertise Rating")
        AddStat("MeleeArPen", "Armor Pen")
        AddStat("MeleeMiss", "Miss Chance")
        AddStat("MeleeMissBoss", "Miss (Boss)")
    end

    -- Ranged
    if settings.showRangedAP or settings.showRangedHit or settings.showRangedCrit or settings.showRangedHaste or
       settings.showRangedArPen or settings.showRangedMiss or settings.showRangedMissBoss then
        y = y - 6
        CreateHeader(content, y, "Ranged")
        y = y - 16
        alt = false
        AddStat("RangedAP", "Attack Power")
        AddStat("RangedHit", "Hit")
        AddStat("RangedCrit", "Crit")
        AddStat("RangedHaste", "Haste")
        AddStat("RangedArPen", "Armor Pen")
        AddStat("RangedMiss", "Miss Chance")
        AddStat("RangedMissBoss", "Miss (Boss)")
    end

    -- Spell
    if settings.showSpellPower or settings.showSpellPenetration or settings.showSpellHit or 
       settings.showSpellCrit or settings.showSpellHaste or settings.showSpellMiss or settings.showSpellMissBoss or
       settings.showSpellSchools then
        y = y - 6
        CreateHeader(content, y, "Spell")
        y = y - 16
        alt = false
        AddStat("SpellPower", "Spell Power (best)")
        AddStat("SpellPenetration", "Penetration")
        AddStat("SpellHit", "Hit")
        AddStat("SpellCrit", "Crit (best)")
        AddStat("SpellHaste", "Haste")
        AddStat("SpellMiss", "Miss Chance")
        AddStat("SpellMissBoss", "Miss (Boss)")
        
        -- Spell Schools
        if settings.showSpellSchools then
            for _, school in ipairs(SPELL_SCHOOLS) do
                y = y - 6
                CreateHeader(content, y, school.name)
                y = y - 16
                alt = false
                local _, dmg = CreateLine(content, y, "Damage", false)
                stats[school.name .. "Dmg"] = dmg
                y = y - 12
                local _, crit = CreateLine(content, y, "Crit", true)
                stats[school.name .. "Crit"] = crit
                y = y - 12
            end
        end
    end

    -- Defense
    if settings.showArmor or settings.showDefense or settings.showDefenseRating or settings.showAvoidance or
       settings.showDodge or settings.showParry or settings.showBlock or settings.showBlockValue or settings.showResilience then
        y = y - 6
        CreateHeader(content, y, "Defense")
        y = y - 16
        alt = false
        AddStat("Armor", "Armor")
        AddStat("Defense", "Defense")
        AddStat("DefenseRating", "Defense Rating")
        AddStat("Avoidance", "Avoidance")
        AddStat("Dodge", "Dodge")
        AddStat("Parry", "Parry")
        AddStat("Block", "Block")
        AddStat("BlockValue", "Block Value")
        AddStat("Resilience", "Resilience")
    end
    
    -- Mana Regen
    if settings.showMP5Casting or settings.showMP5NotCasting then
        y = y - 6
        CreateHeader(content, y, "Mana Regen")
        y = y - 16
        alt = false
        AddStat("MP5Casting", "MP5 (Casting)")
        AddStat("MP5NotCasting", "MP5 (Not Casting)")
    end

    content:SetHeight(math.max(1, -y + 20))

    local function UpdateStats()
        -- General
        if stats.MovementSpeed then stats.MovementSpeed:SetText(GetMovementSpeed()) end
        
        -- Melee
        if stats.MeleeAP then
            if type(UnitAttackPower) == "function" then
                local base, pos, neg = UnitAttackPower("player")
                stats.MeleeAP:SetText(string.format("%d", base + pos + neg))
            else
                stats.MeleeAP:SetText("-")
            end
        end
        
        if stats.MeleeHit then stats.MeleeHit:SetText(FormatRatingAndBonus(_G.CR_HIT_MELEE)) end
        
        if stats.MeleeCrit then
            if type(GetCritChance) == "function" then
                stats.MeleeCrit:SetText(FmtPercent(GetCritChance()))
            else
                stats.MeleeCrit:SetText("-")
            end
        end
        
        if stats.MeleeHaste then stats.MeleeHaste:SetText(FormatRatingAndBonus(_G.CR_HASTE_MELEE)) end
        if stats.MeleeExpertise then stats.MeleeExpertise:SetText(FormatRatingAndBonus(_G.CR_EXPERTISE)) end
        
        if stats.MeleeExpertiseRating then
            local expertiseRating = GetCombatRatingSafe(_G.CR_EXPERTISE)
            stats.MeleeExpertiseRating:SetText(expertiseRating and string.format("%d", expertiseRating) or "-")
        end
        
        if stats.MeleeArPen then stats.MeleeArPen:SetText(FormatRatingAndBonus(_G.CR_ARMOR_PENETRATION)) end
        if stats.MeleeMiss then stats.MeleeMiss:SetText(FmtPercent(GetMeleeMissChance(false))) end
        if stats.MeleeMissBoss then stats.MeleeMissBoss:SetText(FmtPercent(GetMeleeMissChance(true))) end

        -- Ranged
        if stats.RangedAP then
            if type(UnitRangedAttackPower) == "function" then
                local base, pos, neg = UnitRangedAttackPower("player")
                stats.RangedAP:SetText(string.format("%d", base + pos + neg))
            else
                stats.RangedAP:SetText("-")
            end
        end
        
        if stats.RangedHit then stats.RangedHit:SetText(FormatRatingAndBonus(_G.CR_HIT_RANGED)) end
        
        if stats.RangedCrit then
            if type(GetRangedCritChance) == "function" then
                stats.RangedCrit:SetText(FmtPercent(GetRangedCritChance()))
            else
                stats.RangedCrit:SetText("-")
            end
        end
        
        if stats.RangedHaste then stats.RangedHaste:SetText(FormatRatingAndBonus(_G.CR_HASTE_RANGED)) end
        if stats.RangedArPen then stats.RangedArPen:SetText(FormatRatingAndBonus(_G.CR_ARMOR_PENETRATION)) end
        if stats.RangedMiss then stats.RangedMiss:SetText(FmtPercent(GetRangedMissChance(false))) end
        if stats.RangedMissBoss then stats.RangedMissBoss:SetText(FmtPercent(GetRangedMissChance(true))) end

        -- Spell
        if stats.SpellPower then
            local sp = BestSpellPower()
            stats.SpellPower:SetText(sp and string.format("%d", sp) or "-")
        end
        
        if stats.SpellPenetration then
            if type(GetSpellPenetration) == "function" then
                local pen = SafeNumber(GetSpellPenetration())
                stats.SpellPenetration:SetText(pen and string.format("%d", pen) or "-")
            else
                stats.SpellPenetration:SetText("-")
            end
        end
        
        if stats.SpellHit then stats.SpellHit:SetText(FormatRatingAndBonus(_G.CR_HIT_SPELL)) end
        
        if stats.SpellCrit then
            local sc = BestSpellCrit()
            stats.SpellCrit:SetText(sc and FmtPercent(sc) or "-")
        end
        
        if stats.SpellHaste then stats.SpellHaste:SetText(FormatRatingAndBonus(_G.CR_HASTE_SPELL)) end
        if stats.SpellMiss then stats.SpellMiss:SetText(FmtPercent(GetSpellMissChance(false))) end
        if stats.SpellMissBoss then stats.SpellMissBoss:SetText(FmtPercent(GetSpellMissChance(true))) end
        
        -- Per-school spell stats
        if settings.showSpellSchools then
            for _, school in ipairs(SPELL_SCHOOLS) do
                if stats[school.name .. "Dmg"] then
                    local dmg = GetSpellDamageForSchool(school.id)
                    stats[school.name .. "Dmg"]:SetText(dmg and string.format("%d", dmg) or "-")
                end
                if stats[school.name .. "Crit"] then
                    local crit = GetSpellCritForSchool(school.id)
                    stats[school.name .. "Crit"]:SetText(crit and FmtPercent(crit) or "-")
                end
            end
        end

        -- Defense
        if stats.Armor then stats.Armor:SetText(GetArmorText()) end
        if stats.Defense then stats.Defense:SetText(GetDefenseText()) end
        
        if stats.DefenseRating then
            local defRating = GetCombatRatingSafe(_G.CR_DEFENSE_SKILL)
            stats.DefenseRating:SetText(defRating and string.format("%d", defRating) or "-")
        end
        
        if stats.Avoidance then stats.Avoidance:SetText(GetAvoidance()) end

        if stats.Dodge then
            if type(GetDodgeChance) == "function" then
                stats.Dodge:SetText(FmtPercent(GetDodgeChance()))
            else
                stats.Dodge:SetText("-")
            end
        end

        if stats.Parry then
            if type(GetParryChance) == "function" then
                stats.Parry:SetText(FmtPercent(GetParryChance()))
            else
                stats.Parry:SetText("-")
            end
        end

        if stats.Block then
            if type(GetBlockChance) == "function" then
                stats.Block:SetText(FmtPercent(GetBlockChance()))
            else
                stats.Block:SetText("-")
            end
        end
        
        if stats.BlockValue then
            if type(GetShieldBlock) == "function" then
                stats.BlockValue:SetText(string.format("%d", GetShieldBlock()))
            else
                stats.BlockValue:SetText("-")
            end
        end

        if stats.Resilience then stats.Resilience:SetText(FormatRatingAndBonus(_G.CR_CRIT_TAKEN_MELEE)) end
        
        -- Mana Regen
        if stats.MP5Casting or stats.MP5NotCasting then
            if type(GetManaRegen) == "function" then
                local base, casting = GetManaRegen()
                if stats.MP5Casting then
                    stats.MP5Casting:SetText(casting and string.format("%d", casting * 5) or "-")
                end
                if stats.MP5NotCasting then
                    stats.MP5NotCasting:SetText(base and string.format("%d", base * 5) or "-")
                end
            else
                if stats.MP5Casting then stats.MP5Casting:SetText("-") end
                if stats.MP5NotCasting then stats.MP5NotCasting:SetText("-") end
            end
        end
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
            UpdateVisibility()
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
    desc:SetText("Shows extended combat stats on the Character window. Toggle individual stats below.")
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
    
    yOffset = yOffset - 30
    
    local showByDefaultCb = addon:CreateCheckbox(parent)
    showByDefaultCb:SetPoint("TOPLEFT", 16, yOffset)
    showByDefaultCb.Text:SetText("Show by Default")
    showByDefaultCb:SetChecked(settings.show ~= false)
    showByDefaultCb:SetScript("OnClick", function(self)
        addon:SetSetting("extendedStats.show", self:GetChecked())
    end)
    
    yOffset = yOffset - 40
    
    local function CreateStatToggle(label, settingKey, xOffset)
        local cb = addon:CreateCheckbox(parent)
        cb:SetPoint("TOPLEFT", xOffset or 16, yOffset)
        cb.Text:SetText(label)
        cb:SetChecked(settings[settingKey] ~= false)
        cb:SetScript("OnClick", function(self)
            addon:SetSetting("extendedStats." .. settingKey, self:GetChecked())
            addon:Print("Requires /reload to take effect", true)
        end)
        return cb
    end
    
    -- General Header
    local generalHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    generalHeader:SetPoint("TOPLEFT", 16, yOffset)
    generalHeader:SetText("General Stats")
    yOffset = yOffset - 25
    
    CreateStatToggle("Movement Speed", "showMovementSpeed")
    yOffset = yOffset - 25
    
    -- Melee Header
    yOffset = yOffset - 5
    local meleeHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    meleeHeader:SetPoint("TOPLEFT", 16, yOffset)
    meleeHeader:SetText("Melee Stats")
    yOffset = yOffset - 25
    
    CreateStatToggle("Attack Power", "showMeleeAP", 16)
    CreateStatToggle("Hit", "showMeleeHit", 180)
    yOffset = yOffset - 25
    CreateStatToggle("Crit", "showMeleeCrit", 16)
    CreateStatToggle("Haste", "showMeleeHaste", 180)
    yOffset = yOffset - 25
    CreateStatToggle("Expertise", "showMeleeExpertise", 16)
    CreateStatToggle("Expertise Rating", "showMeleeExpertiseRating", 180)
    yOffset = yOffset - 25
    CreateStatToggle("Armor Pen", "showMeleeArPen", 16)
    CreateStatToggle("Miss Chance", "showMeleeMiss", 180)
    yOffset = yOffset - 25
    CreateStatToggle("Miss (Boss)", "showMeleeMissBoss", 16)
    yOffset = yOffset - 25
    
    -- Ranged Header
    yOffset = yOffset - 5
    local rangedHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rangedHeader:SetPoint("TOPLEFT", 16, yOffset)
    rangedHeader:SetText("Ranged Stats")
    yOffset = yOffset - 25
    
    CreateStatToggle("Attack Power", "showRangedAP", 16)
    CreateStatToggle("Hit", "showRangedHit", 180)
    yOffset = yOffset - 25
    CreateStatToggle("Crit", "showRangedCrit", 16)
    CreateStatToggle("Haste", "showRangedHaste", 180)
    yOffset = yOffset - 25
    CreateStatToggle("Armor Pen", "showRangedArPen", 16)
    CreateStatToggle("Miss Chance", "showRangedMiss", 180)
    yOffset = yOffset - 25
    CreateStatToggle("Miss (Boss)", "showRangedMissBoss", 16)
    yOffset = yOffset - 25
    
    -- Spell Header
    yOffset = yOffset - 5
    local spellHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    spellHeader:SetPoint("TOPLEFT", 16, yOffset)
    spellHeader:SetText("Spell Stats")
    yOffset = yOffset - 25
    
    CreateStatToggle("Spell Power", "showSpellPower", 16)
    CreateStatToggle("Penetration", "showSpellPenetration", 180)
    yOffset = yOffset - 25
    CreateStatToggle("Hit", "showSpellHit", 16)
    CreateStatToggle("Crit", "showSpellCrit", 180)
    yOffset = yOffset - 25
    CreateStatToggle("Haste", "showSpellHaste", 16)
    CreateStatToggle("Miss Chance", "showSpellMiss", 180)
    yOffset = yOffset - 25
    CreateStatToggle("Miss (Boss)", "showSpellMissBoss", 16)
    CreateStatToggle("Show Spell Schools", "showSpellSchools", 180)
    yOffset = yOffset - 25
    
    -- Defense Header
    yOffset = yOffset - 5
    local defenseHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    defenseHeader:SetPoint("TOPLEFT", 16, yOffset)
    defenseHeader:SetText("Defense Stats")
    yOffset = yOffset - 25
    
    CreateStatToggle("Armor", "showArmor", 16)
    CreateStatToggle("Defense", "showDefense", 180)
    yOffset = yOffset - 25
    CreateStatToggle("Defense Rating", "showDefenseRating", 16)
    CreateStatToggle("Avoidance", "showAvoidance", 180)
    yOffset = yOffset - 25
    CreateStatToggle("Dodge", "showDodge", 16)
    CreateStatToggle("Parry", "showParry", 180)
    yOffset = yOffset - 25
    CreateStatToggle("Block", "showBlock", 16)
    CreateStatToggle("Block Value", "showBlockValue", 180)
    yOffset = yOffset - 25
    CreateStatToggle("Resilience", "showResilience", 16)
    yOffset = yOffset - 25
    
    -- Mana Regen Header
    yOffset = yOffset - 5
    local regenHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    regenHeader:SetPoint("TOPLEFT", 16, yOffset)
    regenHeader:SetText("Mana Regeneration")
    yOffset = yOffset - 25
    
    CreateStatToggle("MP5 (Casting)", "showMP5Casting", 16)
    CreateStatToggle("MP5 (Not Casting)", "showMP5NotCasting", 180)
    yOffset = yOffset - 25

    return yOffset - 20
end

addon:RegisterModule("ExtendedStats", ExtendedStats)
