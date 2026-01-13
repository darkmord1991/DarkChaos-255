-- ============================================================
-- DC-QoS: Extended Character Stats Module
-- ============================================================
-- Provides an ExtendedCharacterStats-style view on the Character window
-- for WoW 3.3.5a.
-- ============================================================

local addon = DCQOS

-- Combat rating IDs fallback (3.3.5a).
-- Some custom clients/UIs may not expose _G.CR_* constants.
local CR = {
    DEFENSE_SKILL = _G.CR_DEFENSE_SKILL or 2,
    DODGE = _G.CR_DODGE or 3,
    PARRY = _G.CR_PARRY or 4,
    BLOCK = _G.CR_BLOCK or 5,
    HIT_MELEE = _G.CR_HIT_MELEE or 6,
    HIT_RANGED = _G.CR_HIT_RANGED or 7,
    HIT_SPELL = _G.CR_HIT_SPELL or 8,
    CRIT_TAKEN_MELEE = _G.CR_CRIT_TAKEN_MELEE or 15,
    HASTE_MELEE = _G.CR_HASTE_MELEE or 20,
    HASTE_RANGED = _G.CR_HASTE_RANGED or 21,
    HASTE_SPELL = _G.CR_HASTE_SPELL or 22,
    EXPERTISE = _G.CR_EXPERTISE or 24,
    ARMOR_PENETRATION = _G.CR_ARMOR_PENETRATION or 25,
 }

local ExtendedStats = {
    displayName = "Extended Stats",
    settingKey = "extendedStats",
    icon = "Interface\\Icons\\INV_Misc_Book_09",
    defaults = {
        extendedStats = {
            enabled = true,
            show = true,
            hideUnavailable = true,
            -- Slight overlap to avoid a visible seam between the two bordered frames.
            anchorOffsetX = -18,
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
    local miss = 5.0 -- Base 5% miss vs same-level (simple display)
    return string.format("%.2f%%", dodge + parry + miss)
end

local function GetMeleeHitChance()
    local hitBonus = GetCombatRatingBonusSafe(CR.HIT_MELEE) or 0
    return hitBonus
end

local function GetMeleeMissChance(bossLevel)
    local hitBonus = GetMeleeHitChance()
    local baseMiss = bossLevel and 8.0 or 5.0 -- 8% vs boss, 5% vs same level
    local missChance = baseMiss - hitBonus
    return math.max(0, missChance)
end

local function GetRangedMissChance(bossLevel)
    local hitBonus = GetCombatRatingBonusSafe(CR.HIT_RANGED) or 0
    local baseMiss = bossLevel and 8.0 or 5.0
    local missChance = baseMiss - hitBonus
    return math.max(0, missChance)
end

local function GetSpellMissChance(bossLevel)
    local hitBonus = GetCombatRatingBonusSafe(CR.HIT_SPELL) or 0
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
    line:SetHeight(14)

    local bg = line:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(1, 1, 1, 0.05) -- Faint highlight
    if bg.SetShown then
        bg:SetShown(isAlt and true or false)
    else
        if isAlt then
            bg:Show()
        else
            bg:Hide()
        end
    end
    line._altBg = bg

    local label = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", line, "LEFT", 4, 0)
    label:SetText(labelText)
    label:SetJustifyH("LEFT")
    label:SetNonSpaceWrap(false)

    local value = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    value:SetPoint("RIGHT", line, "RIGHT", -4, 0)
    value:SetJustifyH("RIGHT")
    value:SetNonSpaceWrap(false)
    value:SetText("-")

    -- Prevent label/value overlap: constrain label to end before the value column.
    label:SetPoint("RIGHT", value, "LEFT", -8, 0)
    -- Ensure the value column has enough width for strings like "207 (22.95%)".
    value:SetWidth(96)

    return line, label, value
end

local function CreateHeader(parent, yOffset, text)
    local headerFrame = CreateFrame("Frame", nil, parent)
    headerFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    headerFrame:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    headerFrame:SetHeight(14)

    local header = headerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 0, 0)
    header:SetText(text)

    local underline = headerFrame:CreateTexture(nil, "ARTWORK")
    underline:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    underline:SetPoint("RIGHT", headerFrame, "RIGHT", 0, 0)
    underline:SetHeight(1)
    underline:SetTexture(1, 1, 1, 0.2)

    headerFrame._headerText = header
    headerFrame._underline = underline
    return headerFrame
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
    
    -- Toggle Button (must not be parented to the panel frame;
    -- otherwise it disappears when the panel is hidden)
    local toggleBtn = CreateFrame("Button", "DCQoSExtendedStatsToggle", CharacterFrame)
    toggleBtn:SetSize(32, 32)
    -- Anchored in UpdateVisibility() depending on panel state.
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
                btn:SetParent(CharacterFrame)
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
            dx = -18
        end
        dx = tonumber(dx) or -18

        -- Never allow a visible gap between the CharacterFrame and this panel.
        -- Any offset that isn't sufficiently negative can leave a seam between borders.
        if dx > -10 then
            dx = -18
            addon:SetSetting("extendedStats.anchorOffsetX", dx)
        end

        -- Avoid huge gaps caused by accidentally saved drag offsets.
        -- Keep the panel snapped close to the Character window by default.
        if dx > 40 or dx < -80 then
            dx = -18
            addon:SetSetting("extendedStats.anchorOffsetX", dx)
        end
        local dy = (addon.settings and addon.settings.extendedStats and addon.settings.extendedStats.anchorOffsetY) or -12
        frame:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", dx, dy)
        frame:SetHeight(CharacterFrame:GetHeight() - 24)

        -- Fixed width: keeps the panel compact and avoids pushing into the world view.
        frame:SetWidth(290)
    end

    frame.UpdateLayout = UpdateLayout

    UpdateLayout()
    
    -- Visibility logic
    local function UpdateVisibility()
        local show = addon.settings.extendedStats.show
        
        -- Check if we're on the Character tab (PaperDoll)
        local isCharacterTab = (PaperDollFrame and PaperDollFrame:IsShown()) or false
        
        if show then
            frame:Show()
            settingsBtn:Show()
            toggleBtn:Show()
            toggleBtn:ClearAllPoints()
            toggleBtn:SetPoint("LEFT", frame, "RIGHT", 4, 20)
            -- Re-anchor 3rd-party buttons after we show
            ReanchorExternalButtons()
            toggleBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
            toggleBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
            
            -- Show/hide external buttons based on tab
            if isCharacterTab then
                if _G.DC_ItemUpgrade_CharFrameButton then _G.DC_ItemUpgrade_CharFrameButton:Show() end
                if _G.DC_ItemUpgrade_HeirloomButton then _G.DC_ItemUpgrade_HeirloomButton:Show() end
                if _G.DC_Collection_CharFrameButton then _G.DC_Collection_CharFrameButton:Show() end
                if _G.DC_Transmog_CharFrameButton then _G.DC_Transmog_CharFrameButton:Show() end
            else
                if _G.DC_ItemUpgrade_CharFrameButton then _G.DC_ItemUpgrade_CharFrameButton:Hide() end
                if _G.DC_ItemUpgrade_HeirloomButton then _G.DC_ItemUpgrade_HeirloomButton:Hide() end
                if _G.DC_Collection_CharFrameButton then _G.DC_Collection_CharFrameButton:Hide() end
                if _G.DC_Transmog_CharFrameButton then _G.DC_Transmog_CharFrameButton:Hide() end
            end
        else
            frame:Hide()
            settingsBtn:Hide()
            toggleBtn:Show()
            toggleBtn:ClearAllPoints()
            toggleBtn:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 4, -40)
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
    content:SetSize(1, 400)
    scroll:SetScrollChild(content)

    frame.scrollFrame = scroll
    frame.content = content

    local function SyncContentWidth()
        if not scroll or not content then return end
        local w = scroll:GetWidth()
        if not w or w <= 1 then return end
        -- Ensure child uses the full scroll width so label/value columns don't truncate.
        content:SetWidth(w)
    end

    if scroll and scroll.HookScript then
        scroll:HookScript("OnSizeChanged", function()
            SyncContentWidth()
        end)
    end

    if frame and frame.HookScript then
        frame:HookScript("OnSizeChanged", function()
            SyncContentWidth()
        end)
    end

    SyncContentWidth()

    -- Layout (dynamic reflow; can hide unavailable stats per class)
    local stats = {}
    local lines = {}
    local headers = {}
    local sections = {}
    local availability = {}
    local settings = addon.settings.extendedStats

    local function AddSection(name)
        local headerFrame = CreateHeader(content, 0, name)
        headers[name] = headerFrame
        local section = { name = name, header = headerFrame, keys = {} }
        table.insert(sections, section)
        return section
    end

    local function AddStat(section, key, label)
        if settings["show" .. key] then
            local line, _, value = CreateLine(content, 0, label, false)
            lines[key] = line
            stats[key] = value
            table.insert(section.keys, key)
        end
    end

    local function IsUnavailableText(text)
        return (text == nil) or (text == "-") or (text == "")
    end

    local function ShouldHideUnavailable()
        return settings.hideUnavailable ~= false
    end

    local function ReflowLayout()
        local y = -5

        for _, section in ipairs(sections) do
            local visibleKeys = {}
            for _, key in ipairs(section.keys) do
                if lines[key] and (not ShouldHideUnavailable() or availability[key]) then
                    table.insert(visibleKeys, key)
                end
            end

            if #visibleKeys == 0 then
                if section.header then section.header:Hide() end
                for _, key in ipairs(section.keys) do
                    if lines[key] then lines[key]:Hide() end
                end
            else
                if section.header then
                    section.header:Show()
                    section.header:ClearAllPoints()
                    section.header:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
                    section.header:SetPoint("RIGHT", content, "RIGHT", -8, 0)
                end
                y = y - 16

                local row = 0
                for _, key in ipairs(visibleKeys) do
                    local line = lines[key]
                    if line then
                        row = row + 1
                        line:Show()
                        line:ClearAllPoints()
                        line:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
                        line:SetPoint("RIGHT", content, "RIGHT", -4, 0)
                        if line._altBg then
                            local showAlt = ((row % 2) == 0)
                            if line._altBg.SetShown then
                                line._altBg:SetShown(showAlt)
                            else
                                if showAlt then
                                    line._altBg:Show()
                                else
                                    line._altBg:Hide()
                                end
                            end
                        end
                        y = y - 14
                    end
                end

                y = y - 6
            end
        end

        content:SetHeight(math.max(1, -y + 20))
    end

    -- Build sections based on enabled toggles
    if settings.showMovementSpeed then
        local s = AddSection("General")
        AddStat(s, "MovementSpeed", "Movement Speed")
    end

    if settings.showMeleeAP or settings.showMeleeHit or settings.showMeleeCrit or settings.showMeleeHaste or
       settings.showMeleeExpertise or settings.showMeleeExpertiseRating or settings.showMeleeArPen or
       settings.showMeleeMiss or settings.showMeleeMissBoss then
        local s = AddSection("Melee")
        AddStat(s, "MeleeAP", "Attack Power")
        AddStat(s, "MeleeHit", "Hit")
        AddStat(s, "MeleeCrit", "Crit")
        AddStat(s, "MeleeHaste", "Haste")
        AddStat(s, "MeleeExpertise", "Expertise")
        AddStat(s, "MeleeExpertiseRating", "Expertise Rating")
        AddStat(s, "MeleeArPen", "Armor Pen")
        AddStat(s, "MeleeMiss", "Miss Chance")
        AddStat(s, "MeleeMissBoss", "Miss (Boss)")
    end

    if settings.showRangedAP or settings.showRangedHit or settings.showRangedCrit or settings.showRangedHaste or
       settings.showRangedArPen or settings.showRangedMiss or settings.showRangedMissBoss then
        local s = AddSection("Ranged")
        AddStat(s, "RangedAP", "Attack Power")
        AddStat(s, "RangedHit", "Hit")
        AddStat(s, "RangedCrit", "Crit")
        AddStat(s, "RangedHaste", "Haste")
        AddStat(s, "RangedArPen", "Armor Pen")
        AddStat(s, "RangedMiss", "Miss Chance")
        AddStat(s, "RangedMissBoss", "Miss (Boss)")
    end

    if settings.showSpellPower or settings.showSpellPenetration or settings.showSpellHit or
       settings.showSpellCrit or settings.showSpellHaste or settings.showSpellMiss or settings.showSpellMissBoss or
       settings.showSpellSchools then
        local s = AddSection("Spell")
        AddStat(s, "SpellPower", "Spell Power (best)")
        AddStat(s, "SpellPenetration", "Penetration")
        AddStat(s, "SpellHit", "Hit")
        AddStat(s, "SpellCrit", "Crit (best)")
        AddStat(s, "SpellHaste", "Haste")
        AddStat(s, "SpellMiss", "Miss Chance")
        AddStat(s, "SpellMissBoss", "Miss (Boss)")

        if settings.showSpellSchools then
            for _, school in ipairs(SPELL_SCHOOLS) do
                local ss = AddSection(school.name)
                AddStat(ss, school.name .. "Dmg", "Damage")
                AddStat(ss, school.name .. "Crit", "Crit")
            end
        end
    end

    if settings.showArmor or settings.showDefense or settings.showDefenseRating or settings.showAvoidance or
       settings.showDodge or settings.showParry or settings.showBlock or settings.showBlockValue or settings.showResilience then
        local s = AddSection("Defense")
        AddStat(s, "Armor", "Armor")
        AddStat(s, "Defense", "Defense")
        AddStat(s, "DefenseRating", "Defense Rating")
        AddStat(s, "Avoidance", "Avoidance")
        AddStat(s, "Dodge", "Dodge")
        AddStat(s, "Parry", "Parry")
        AddStat(s, "Block", "Block")
        AddStat(s, "BlockValue", "Block Value")
        AddStat(s, "Resilience", "Resilience")
    end

    if settings.showMP5Casting or settings.showMP5NotCasting then
        local s = AddSection("Mana Regen")
        AddStat(s, "MP5Casting", "MP5 (Casting)")
        AddStat(s, "MP5NotCasting", "MP5 (Not Casting)")
    end

    local function UpdateStats()
        local function SetStatText(key, text)
            if not stats[key] then
                return
            end
            if IsUnavailableText(text) then
                stats[key]:SetText("-")
                availability[key] = false
            else
                stats[key]:SetText(text)
                availability[key] = true
            end
        end

        -- General
        if stats.MovementSpeed then SetStatText("MovementSpeed", GetMovementSpeed()) end
        
        -- Melee
        if stats.MeleeAP then
            if type(UnitAttackPower) == "function" then
                local base, pos, neg = UnitAttackPower("player")
                SetStatText("MeleeAP", string.format("%d", base + pos + neg))
            else
                SetStatText("MeleeAP", "-")
            end
        end
        
        if stats.MeleeHit then SetStatText("MeleeHit", FormatRatingAndBonus(CR.HIT_MELEE)) end
        
        if stats.MeleeCrit then
            if type(GetCritChance) == "function" then
                SetStatText("MeleeCrit", FmtPercent(GetCritChance()))
            else
                SetStatText("MeleeCrit", "-")
            end
        end
        
        if stats.MeleeHaste then SetStatText("MeleeHaste", FormatRatingAndBonus(CR.HASTE_MELEE)) end
        if stats.MeleeExpertise then SetStatText("MeleeExpertise", FormatRatingAndBonus(CR.EXPERTISE)) end
        
        if stats.MeleeExpertiseRating then
            local expertiseRating = GetCombatRatingSafe(CR.EXPERTISE)
            SetStatText("MeleeExpertiseRating", expertiseRating and string.format("%d", expertiseRating) or "-")
        end
        
        if stats.MeleeArPen then SetStatText("MeleeArPen", FormatRatingAndBonus(CR.ARMOR_PENETRATION)) end
        if stats.MeleeMiss then SetStatText("MeleeMiss", FmtPercent(GetMeleeMissChance(false))) end
        if stats.MeleeMissBoss then SetStatText("MeleeMissBoss", FmtPercent(GetMeleeMissChance(true))) end

        -- Ranged
        if stats.RangedAP then
            if type(UnitRangedAttackPower) == "function" then
                local base, pos, neg = UnitRangedAttackPower("player")
                SetStatText("RangedAP", string.format("%d", base + pos + neg))
            else
                SetStatText("RangedAP", "-")
            end
        end
        
        if stats.RangedHit then SetStatText("RangedHit", FormatRatingAndBonus(CR.HIT_RANGED)) end
        
        if stats.RangedCrit then
            if type(GetRangedCritChance) == "function" then
                SetStatText("RangedCrit", FmtPercent(GetRangedCritChance()))
            else
                SetStatText("RangedCrit", "-")
            end
        end
        
        if stats.RangedHaste then SetStatText("RangedHaste", FormatRatingAndBonus(CR.HASTE_RANGED)) end
        if stats.RangedArPen then SetStatText("RangedArPen", FormatRatingAndBonus(CR.ARMOR_PENETRATION)) end
        if stats.RangedMiss then SetStatText("RangedMiss", FmtPercent(GetRangedMissChance(false))) end
        if stats.RangedMissBoss then SetStatText("RangedMissBoss", FmtPercent(GetRangedMissChance(true))) end

        -- Spell
        if stats.SpellPower then
            local sp = BestSpellPower()
            SetStatText("SpellPower", sp and string.format("%d", sp) or "-")
        end
        
        if stats.SpellPenetration then
            if type(GetSpellPenetration) == "function" then
                local pen = SafeNumber(GetSpellPenetration())
                SetStatText("SpellPenetration", pen and string.format("%d", pen) or "-")
            else
                SetStatText("SpellPenetration", "-")
            end
        end
        
        if stats.SpellHit then SetStatText("SpellHit", FormatRatingAndBonus(CR.HIT_SPELL)) end
        
        if stats.SpellCrit then
            local sc = BestSpellCrit()
            SetStatText("SpellCrit", sc and FmtPercent(sc) or "-")
        end
        
        if stats.SpellHaste then SetStatText("SpellHaste", FormatRatingAndBonus(CR.HASTE_SPELL)) end
        if stats.SpellMiss then SetStatText("SpellMiss", FmtPercent(GetSpellMissChance(false))) end
        if stats.SpellMissBoss then SetStatText("SpellMissBoss", FmtPercent(GetSpellMissChance(true))) end
        
        -- Per-school spell stats
        if settings.showSpellSchools then
            for _, school in ipairs(SPELL_SCHOOLS) do
                if stats[school.name .. "Dmg"] then
                    local dmg = GetSpellDamageForSchool(school.id)
                    SetStatText(school.name .. "Dmg", dmg and string.format("%d", dmg) or "-")
                end
                if stats[school.name .. "Crit"] then
                    local crit = GetSpellCritForSchool(school.id)
                    SetStatText(school.name .. "Crit", crit and FmtPercent(crit) or "-")
                end
            end
        end

        -- Defense
        if stats.Armor then SetStatText("Armor", GetArmorText()) end
        if stats.Defense then SetStatText("Defense", GetDefenseText()) end
        
        if stats.DefenseRating then
            local defRating = GetCombatRatingSafe(CR.DEFENSE_SKILL)
            SetStatText("DefenseRating", defRating and string.format("%d", defRating) or "-")
        end
        
        if stats.Avoidance then SetStatText("Avoidance", GetAvoidance()) end

        if stats.Dodge then
            if type(GetDodgeChance) == "function" then
                SetStatText("Dodge", FmtPercent(GetDodgeChance()))
            else
                SetStatText("Dodge", "-")
            end
        end

        if stats.Parry then
            if type(GetParryChance) == "function" then
                SetStatText("Parry", FmtPercent(GetParryChance()))
            else
                SetStatText("Parry", "-")
            end
        end

        if stats.Block then
            if type(GetBlockChance) == "function" then
                SetStatText("Block", FmtPercent(GetBlockChance()))
            else
                SetStatText("Block", "-")
            end
        end
        
        if stats.BlockValue then
            if type(GetShieldBlock) == "function" then
                SetStatText("BlockValue", string.format("%d", GetShieldBlock()))
            else
                SetStatText("BlockValue", "-")
            end
        end

        if stats.Resilience then SetStatText("Resilience", FormatRatingAndBonus(CR.CRIT_TAKEN_MELEE)) end
        
        -- Mana Regen
        if stats.MP5Casting or stats.MP5NotCasting then
            if type(GetManaRegen) == "function" then
                local base, casting = GetManaRegen()
                if stats.MP5Casting then
                    SetStatText("MP5Casting", casting and string.format("%d", casting * 5) or "-")
                end
                if stats.MP5NotCasting then
                    SetStatText("MP5NotCasting", base and string.format("%d", base * 5) or "-")
                end
            else
                if stats.MP5Casting then SetStatText("MP5Casting", "-") end
                if stats.MP5NotCasting then SetStatText("MP5NotCasting", "-") end
            end
        end

        ReflowLayout()
    end

    frame.UpdateStats = UpdateStats
    frame.ReflowLayout = ReflowLayout

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
        if toggleBtn then
            toggleBtn:Hide()
        end
        -- Hide external buttons when leaving Character tab
        if _G.DC_ItemUpgrade_CharFrameButton then _G.DC_ItemUpgrade_CharFrameButton:Hide() end
        if _G.DC_ItemUpgrade_HeirloomButton then _G.DC_ItemUpgrade_HeirloomButton:Hide() end
        if _G.DC_Collection_CharFrameButton then _G.DC_Collection_CharFrameButton:Hide() end
        if _G.DC_Transmog_CharFrameButton then _G.DC_Transmog_CharFrameButton:Hide() end
    end)
    
    -- Hook other tabs to hide buttons when they're shown
    if PetPaperDollFrame then
        PetPaperDollFrame:HookScript("OnShow", function()
            if _G.DC_ItemUpgrade_CharFrameButton then _G.DC_ItemUpgrade_CharFrameButton:Hide() end
            if _G.DC_ItemUpgrade_HeirloomButton then _G.DC_ItemUpgrade_HeirloomButton:Hide() end
            if _G.DC_Collection_CharFrameButton then _G.DC_Collection_CharFrameButton:Hide() end
            if _G.DC_Transmog_CharFrameButton then _G.DC_Transmog_CharFrameButton:Hide() end
        end)
    end
    
    if ReputationFrame then
        ReputationFrame:HookScript("OnShow", function()
            if _G.DC_ItemUpgrade_CharFrameButton then _G.DC_ItemUpgrade_CharFrameButton:Hide() end
            if _G.DC_ItemUpgrade_HeirloomButton then _G.DC_ItemUpgrade_HeirloomButton:Hide() end
            if _G.DC_Collection_CharFrameButton then _G.DC_Collection_CharFrameButton:Hide() end
            if _G.DC_Transmog_CharFrameButton then _G.DC_Transmog_CharFrameButton:Hide() end
        end)
    end
    
    if SkillFrame then
        SkillFrame:HookScript("OnShow", function()
            if _G.DC_ItemUpgrade_CharFrameButton then _G.DC_ItemUpgrade_CharFrameButton:Hide() end
            if _G.DC_ItemUpgrade_HeirloomButton then _G.DC_ItemUpgrade_HeirloomButton:Hide() end
            if _G.DC_Collection_CharFrameButton then _G.DC_Collection_CharFrameButton:Hide() end
            if _G.DC_Transmog_CharFrameButton then _G.DC_Transmog_CharFrameButton:Hide() end
        end)
    end
    
    if TokenFrame then
        TokenFrame:HookScript("OnShow", function()
            if _G.DC_ItemUpgrade_CharFrameButton then _G.DC_ItemUpgrade_CharFrameButton:Hide() end
            if _G.DC_ItemUpgrade_HeirloomButton then _G.DC_ItemUpgrade_HeirloomButton:Hide() end
            if _G.DC_Collection_CharFrameButton then _G.DC_Collection_CharFrameButton:Hide() end
            if _G.DC_Transmog_CharFrameButton then _G.DC_Transmog_CharFrameButton:Hide() end
        end)
    end

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

    local controls = {}

    local function TrackControl(ctrl, col, y)
        if not ctrl then return end
        ctrl._dcqosCol = col
        ctrl._dcqosY = y
        table.insert(controls, ctrl)
    end

    local function UpdateLayout()
        local w = parent and parent.GetWidth and parent:GetWidth() or 0

        -- In DC-QoS this function receives the scroll child frame.
        -- That frame can be 1px wide until the scroll frame sizes; use the scroll width too.
        if (not w or w < 50) and parent and parent.GetParent then
            local p = parent:GetParent()
            if p and p.GetWidth then
                w = p:GetWidth()
            end
        end

        -- Content is inside a scroll frame; width can be 0/1 during initial build.
        -- Use sane fallbacks, then reflow on size changes.
        if w < 350 then w = 350 end

        local leftX = 16
        local innerW = w - (leftX * 2)
        if innerW < 220 then innerW = 220 end

        -- Always compute column positions from available width.
        -- Avoid hardcoded right-column X (that caused clipping when width was still the fallback).
        local gap = 20
        local colW = math.floor((innerW - gap) / 2)
        if colW < 140 then
            gap = 12
            colW = math.floor((innerW - gap) / 2)
        end
        if colW < 90 then
            gap = 8
            colW = math.floor((innerW - gap) / 2)
        end
        if colW < 60 then colW = 60 end

        local rightX = leftX + colW + gap

        for _, ctrl in ipairs(controls) do
            if ctrl._dcqosCol and ctrl._dcqosY then
                local x = (ctrl._dcqosCol == 2) and rightX or leftX
                ctrl:ClearAllPoints()
                ctrl:SetPoint("TOPLEFT", x, ctrl._dcqosY)

                -- Prevent checkbox text being clipped; make it consume available space.
                if ctrl.Text and ctrl.Text.SetWidth then
                    ctrl:SetWidth(colW)
                    ctrl.Text:SetWidth(math.max(40, colW - 30))
                    if ctrl.Text.SetJustifyH then ctrl.Text:SetJustifyH("LEFT") end
                    if ctrl.Text.SetNonSpaceWrap then ctrl.Text:SetNonSpaceWrap(false) end
                end
            end
        end
    end

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

    yOffset = yOffset - 30
    

    local hideUnavailable = addon:CreateCheckbox(parent)
    hideUnavailable:SetPoint("TOPLEFT", 16, yOffset)
    hideUnavailable.Text:SetText("Hide unavailable/empty stats")
    hideUnavailable:SetChecked(settings.hideUnavailable ~= false)
    hideUnavailable:SetScript("OnClick", function(self)
        settings.hideUnavailable = self:GetChecked()
        if ExtendedStats._frame and ExtendedStats._frame.UpdateStats then
            ExtendedStats._frame:UpdateStats()
        end
    end)
    yOffset = yOffset - 30
    yOffset = yOffset - 40
    
    local function CreateStatToggle(label, settingKey, col)
        local cb = addon:CreateCheckbox(parent)
        cb:SetPoint("TOPLEFT", 16, yOffset)
        cb.Text:SetText(label)
        cb:SetChecked(settings[settingKey] ~= false)
        cb:SetScript("OnClick", function(self)
            addon:SetSetting("extendedStats." .. settingKey, self:GetChecked())
            addon:Print("Requires /reload to take effect", true)
        end)

        TrackControl(cb, col or 1, yOffset)
        return cb
    end
    
    -- General Header
    local generalHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    generalHeader:SetPoint("TOPLEFT", 16, yOffset)
    generalHeader:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    generalHeader:SetText("General Stats")
    yOffset = yOffset - 25
    
    CreateStatToggle("Movement Speed", "showMovementSpeed", 1)
    yOffset = yOffset - 25
    
    -- Melee Header
    yOffset = yOffset - 5
    local meleeHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    meleeHeader:SetPoint("TOPLEFT", 16, yOffset)
    meleeHeader:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    meleeHeader:SetText("Melee Stats")
    yOffset = yOffset - 25
    
    CreateStatToggle("Attack Power", "showMeleeAP", 1)
    CreateStatToggle("Hit", "showMeleeHit", 2)
    yOffset = yOffset - 25
    CreateStatToggle("Crit", "showMeleeCrit", 1)
    CreateStatToggle("Haste", "showMeleeHaste", 2)
    yOffset = yOffset - 25
    CreateStatToggle("Expertise", "showMeleeExpertise", 1)
    CreateStatToggle("Expertise Rating", "showMeleeExpertiseRating", 2)
    yOffset = yOffset - 25
    CreateStatToggle("Armor Pen", "showMeleeArPen", 1)
    CreateStatToggle("Miss Chance", "showMeleeMiss", 2)
    yOffset = yOffset - 25
    CreateStatToggle("Miss (Boss)", "showMeleeMissBoss", 1)
    yOffset = yOffset - 25
    
    -- Ranged Header
    yOffset = yOffset - 5
    local rangedHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rangedHeader:SetPoint("TOPLEFT", 16, yOffset)
    rangedHeader:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    rangedHeader:SetText("Ranged Stats")
    yOffset = yOffset - 25
    
    CreateStatToggle("Attack Power", "showRangedAP", 1)
    CreateStatToggle("Hit", "showRangedHit", 2)
    yOffset = yOffset - 25
    CreateStatToggle("Crit", "showRangedCrit", 1)
    CreateStatToggle("Haste", "showRangedHaste", 2)
    yOffset = yOffset - 25
    CreateStatToggle("Armor Pen", "showRangedArPen", 1)
    CreateStatToggle("Miss Chance", "showRangedMiss", 2)
    yOffset = yOffset - 25
    CreateStatToggle("Miss (Boss)", "showRangedMissBoss", 1)
    yOffset = yOffset - 25
    
    -- Spell Header
    yOffset = yOffset - 5
    local spellHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    spellHeader:SetPoint("TOPLEFT", 16, yOffset)
    spellHeader:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    spellHeader:SetText("Spell Stats")
    yOffset = yOffset - 25
    
    CreateStatToggle("Spell Power", "showSpellPower", 1)
    CreateStatToggle("Penetration", "showSpellPenetration", 2)
    yOffset = yOffset - 25
    CreateStatToggle("Hit", "showSpellHit", 1)
    CreateStatToggle("Crit", "showSpellCrit", 2)
    yOffset = yOffset - 25
    CreateStatToggle("Haste", "showSpellHaste", 1)
    CreateStatToggle("Miss Chance", "showSpellMiss", 2)
    yOffset = yOffset - 25
    CreateStatToggle("Miss (Boss)", "showSpellMissBoss", 1)
    CreateStatToggle("Show Spell Schools", "showSpellSchools", 2)
    yOffset = yOffset - 25
    
    -- Defense Header
    yOffset = yOffset - 5
    local defenseHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    defenseHeader:SetPoint("TOPLEFT", 16, yOffset)
    defenseHeader:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    defenseHeader:SetText("Defense Stats")
    yOffset = yOffset - 25
    
    CreateStatToggle("Armor", "showArmor", 1)
    CreateStatToggle("Defense", "showDefense", 2)
    yOffset = yOffset - 25
    CreateStatToggle("Defense Rating", "showDefenseRating", 1)
    CreateStatToggle("Avoidance", "showAvoidance", 2)
    yOffset = yOffset - 25
    CreateStatToggle("Dodge", "showDodge", 1)
    CreateStatToggle("Parry", "showParry", 2)
    yOffset = yOffset - 25
    CreateStatToggle("Block", "showBlock", 1)
    CreateStatToggle("Block Value", "showBlockValue", 2)
    yOffset = yOffset - 25
    CreateStatToggle("Resilience", "showResilience", 1)
    yOffset = yOffset - 25
    
    -- Mana Regen Header
    yOffset = yOffset - 5
    local regenHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    regenHeader:SetPoint("TOPLEFT", 16, yOffset)
    regenHeader:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    regenHeader:SetText("Mana Regeneration")
    yOffset = yOffset - 25
    
    CreateStatToggle("MP5 (Casting)", "showMP5Casting", 1)
    CreateStatToggle("MP5 (Not Casting)", "showMP5NotCasting", 2)
    yOffset = yOffset - 25

    -- Track the top controls too, so they get wider text/less clipping.
    TrackControl(enabledCb, 1, -70)
    TrackControl(showByDefaultCb, 1, -100)
    TrackControl(hideUnavailable, 1, -130)

    UpdateLayout()
    if parent and parent.HookScript then
        parent:HookScript("OnSizeChanged", function()
            UpdateLayout()
        end)
    end

    return yOffset - 20
end

addon:RegisterModule("ExtendedStats", ExtendedStats)
