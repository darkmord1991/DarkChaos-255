-- ============================================================
-- DC-QoS: CombatLog Enhanced Features Module
-- ============================================================
-- This module adds Skada-level features to the base CombatLog:
-- - Advanced tooltips with school damage breakdown
-- - Enhanced death recap with survivability analysis
-- - Buff/debuff tracking
-- - Enemy tracking
-- - Pet damage tracking
-- - Avoidance & mitigation stats
-- - Healing taken breakdown
-- ============================================================

local addon = DCQOS
local CombatLog = addon.modules and addon.modules.CombatLog

if not CombatLog then
    if addon and addon.Debug then
        addon:Debug("CombatLog module not found, Enhanced features disabled")
    end
    return
end

-- ============================================================
-- ENHANCED TOOLTIPS (Skada-style)
-- ============================================================

-- School colors for damage breakdown
local SCHOOL_COLORS = {
    [0x01] = {r = 1.00, g = 1.00, b = 0.00, name = "Physical"},  -- Yellow
    [0x02] = {r = 1.00, g = 0.90, b = 0.50, name = "Holy"},      -- Light Yellow
    [0x04] = {r = 1.00, g = 0.50, b = 0.00, name = "Fire"},      -- Orange
    [0x08] = {r = 0.30, g = 1.00, b = 0.30, name = "Nature"},    -- Green
    [0x10] = {r = 0.50, g = 1.00, b = 1.00, name = "Frost"},     -- Cyan
    [0x20] = {r = 0.50, g = 0.50, b = 1.00, name = "Shadow"},    -- Purple
    [0x40] = {r = 1.00, g = 0.50, b = 1.00, name = "Arcane"},    -- Pink
}

local BG_FELLEATHER = "Interface\\DC\\Shared\\FelLeather_512.tga"

local RECAP_EVENT_STYLE = {
    damage = {
        bg = {0.12, 0.04, 0.04, 0.78},
        border = {0.48, 0.16, 0.16, 0.95},
        accent = {1.0, 0.25, 0.25, 1.0},
        icon = "Interface\\Icons\\Ability_Creature_Cursed_05",
    },
    heal = {
        bg = {0.04, 0.12, 0.04, 0.78},
        border = {0.16, 0.45, 0.16, 0.95},
        accent = {0.25, 1.0, 0.25, 1.0},
        icon = "Interface\\Icons\\Spell_Holy_HolyBolt",
    },
    buff = {
        bg = {0.05, 0.07, 0.14, 0.78},
        border = {0.20, 0.30, 0.56, 0.95},
        accent = {0.45, 0.60, 1.0, 1.0},
        icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    },
    debuff = {
        bg = {0.12, 0.05, 0.12, 0.78},
        border = {0.45, 0.18, 0.45, 0.95},
        accent = {1.0, 0.45, 1.0, 1.0},
        icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges",
    },
    default = {
        bg = {0.07, 0.07, 0.07, 0.78},
        border = {0.34, 0.34, 0.34, 0.95},
        accent = {0.75, 0.75, 0.75, 1.0},
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
    },
}

local function GetRecapEventStyle(eventType)
    return RECAP_EVENT_STYLE[eventType] or RECAP_EVENT_STYLE.default
end

local function GetRecapEventIcon(entry)
    if type(GetSpellTexture) == "function" then
        if entry and entry.spellId then
            local spellTexture = GetSpellTexture(entry.spellId)
            if spellTexture then
                return spellTexture
            end
        end

        if entry and entry.spellName then
            local spellTexture = GetSpellTexture(entry.spellName)
            if spellTexture then
                return spellTexture
            end
        end
    end

    return GetRecapEventStyle(entry and entry.eventType).icon
end

function CombatLog.ShowEnhancedTooltip(self)
    local data = self.playerData or self.data
    if not data then return false end

    local settings = addon.settings and addon.settings.combatLog or {}
    local mode = settings.meterMode or "damage"
    
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    
    -- Header
    local classColor = RAID_CLASS_COLORS[data.class or "WARRIOR"] or {r=0.5, g=0.5, b=0.5}
    GameTooltip:AddLine(data.name, classColor.r, classColor.g, classColor.b)
    GameTooltip:AddLine(" ")
    
    -- DAMAGE MODE - Show spell breakdown with school colors
    if mode == "damage" then
        if data.spells then
            local sortedSpells = {}
            for id, spell in pairs(data.spells) do
                if spell.damage and spell.damage > 0 then
                    table.insert(sortedSpells, {
                        id = id,
                        name = spell.name,
                        damage = spell.damage,
                        hits = spell.hits or 0,
                        crits = spell.crits or 0,
                        school = spell.school or 0x01,
                        absorbed = spell.absorbed or 0,
                        overkill = spell.overkill or 0,
                        glancing = spell.glancing or 0,
                        crushing = spell.crushing or 0,
                    })
                end
            end
            table.sort(sortedSpells, function(a, b) return a.damage > b.damage end)
            
            for i = 1, math.min(10, #sortedSpells) do
                local spell = sortedSpells[i]
                local critRate = spell.hits > 0 and (spell.crits / spell.hits * 100) or 0
                
                -- Get school color
                local schoolColor = (settings.showSchoolColors == false) and {r=1, g=1, b=1}
                    or SCHOOL_COLORS[spell.school] or {r=1, g=1, b=1}
                
                -- Format damage with school icon
                local dmgText = string.format("%s (%.0f%%)", 
                    addon.FormatNumber and addon.FormatNumber(spell.damage) or tostring(spell.damage),
                    critRate)
                
                GameTooltip:AddDoubleLine(
                    spell.name,
                    dmgText,
                    schoolColor.r, schoolColor.g, schoolColor.b,
                    1, 1, 1
                )
                
                -- Add details line for significant spells
                if i <= 5 then
                    local details = ""
                    if settings.showGlancingCrushing ~= false then
                        if spell.glancing > 0 then
                            details = details .. spell.glancing .. " glancing, "
                        end
                        if spell.crushing > 0 then
                            details = details .. spell.crushing .. " crushing, "
                        end
                    end
                    if settings.showMitigationInTooltip ~= false and spell.absorbed > 0 then
                        details = details .. (((addon.FormatNumber and addon.FormatNumber(spell.absorbed)) or tostring(spell.absorbed)) .. " absorbed")
                    end
                    if details ~= "" then
                        GameTooltip:AddLine("  " .. details, 0.7, 0.7, 0.7, true)
                    end
                end
            end
        else
            GameTooltip:AddLine("No spell data", 0.7, 0.7, 0.7)
        end
    
    -- HEALING MODE - Show healing breakdown with overheal
    elseif mode == "healing" then
        if data.healingBySpell then
            local sortedSpells = {}
            for id, spell in pairs(data.healingBySpell) do
                if spell.amount and spell.amount > 0 then
                    table.insert(sortedSpells, {
                        name = spell.name,
                        amount = spell.amount,
                        overheal = spell.overheal or 0,
                        hits = spell.hits or 0,
                        crits = spell.crits or 0,
                    })
                end
            end
            table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)
            
            for i = 1, math.min(10, #sortedSpells) do
                local spell = sortedSpells[i]
                local overhealPct = (spell.amount + spell.overheal) > 0 and 
                    (spell.overheal / (spell.amount + spell.overheal) * 100) or 0
                local critRate = spell.hits > 0 and (spell.crits / spell.hits * 100) or 0
                
                GameTooltip:AddDoubleLine(
                    spell.name,
                    string.format("%s (%.0f%% OH)", 
                        addon.FormatNumber and addon.FormatNumber(spell.amount) or tostring(spell.amount),
                        overhealPct),
                    0.2, 1, 0.2,
                    1, 1, 1
                )
            end
        else
            GameTooltip:AddLine("No healing data", 0.7, 0.7, 0.7)
        end
    
    -- DAMAGE TAKEN - Show sources and mitigation
    elseif mode == "damageTaken" then
        GameTooltip:AddDoubleLine("Total Damage Taken:", addon.FormatNumber and addon.FormatNumber(data.damageTaken) or tostring(data.damageTaken), 1, 0.5, 0.5, 1, 1, 1)
        GameTooltip:AddLine(" ")
        
        -- Mitigation stats
        if settings.showMitigationInTooltip ~= false then
            if data.absorbedAmount and data.absorbedAmount > 0 then
                GameTooltip:AddDoubleLine("Absorbed:", addon.FormatNumber and addon.FormatNumber(data.absorbedAmount) or tostring(data.absorbedAmount), 0.7, 0.7, 1, 1, 1, 1)
            end
            if data.blockAmount and data.blockAmount > 0 then
                GameTooltip:AddDoubleLine("Blocked:", addon.FormatNumber and addon.FormatNumber(data.blockAmount) or tostring(data.blockAmount), 1, 0.7, 0.2, 1, 1, 1)
            end
            if data.resistAmount and data.resistAmount > 0 then
                GameTooltip:AddDoubleLine("Resisted:", addon.FormatNumber and addon.FormatNumber(data.resistAmount) or tostring(data.resistAmount), 0.5, 1, 0.5, 1, 1, 1)
            end
        end
        
        -- Avoidance
        if settings.trackAvoidance ~= false and data.avoidance and data.avoidance > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Avoided:", data.avoidance .. " attacks", 1, 1, 0.5, 1, 1, 1)
            if data.dodges > 0 then
                GameTooltip:AddDoubleLine("  Dodges:", data.dodges, 0.7, 0.7, 0.7, 1, 1, 1)
            end
            if data.parries > 0 then
                GameTooltip:AddDoubleLine("  Parries:", data.parries, 0.7, 0.7, 0.7, 1, 1, 1)
            end
            if data.misses > 0 then
                GameTooltip:AddDoubleLine("  Misses:", data.misses, 0.7, 0.7, 0.7, 1, 1, 1)
            end
        end
    end
    
    -- Add summary stats
    GameTooltip:AddLine(" ")
    local combatTime = CombatLog.GetCombatTime and CombatLog.GetCombatTime() or 0
    if combatTime > 0 then
        if data.damage > 0 then
            local dps = data.damage / combatTime
            GameTooltip:AddDoubleLine("DPS:", string.format("%.0f", dps), 0.7, 0.7, 1, 1, 1, 1)
        end
        if data.healing > 0 then
            local hps = data.healing / combatTime
            GameTooltip:AddDoubleLine("HPS:", string.format("%.0f", hps), 0.2, 1, 0.2, 1, 1, 1)
        end
    end
    
    GameTooltip:Show()
    return true
end

-- ============================================================
-- ENHANCED DEATH RECAP
-- ============================================================

local deathRecapFrame = nil

function CombatLog.ShowDeathRecap(playerData)
    local entries = CombatLog.GetDeathLogEntries and CombatLog.GetDeathLogEntries(playerData, true) or (playerData and playerData.deathLog) or {}
    if not entries or #entries == 0 then
        return false
    end

    local settings = addon.settings and addon.settings.combatLog or {}
    local maxEntries = math.max(5, settings.deathRecapCount or 15)
    local showBuffs = settings.deathRecapShowBuffs ~= false

    local function FormatAmount(value)
        if addon.FormatNumber then
            return addon.FormatNumber(value or 0)
        end
        return tostring(value or 0)
    end
    
    -- Create frame if it doesn't exist
    if not deathRecapFrame then
        deathRecapFrame = CreateFrame("Frame", "DCQoS_DeathRecapFrame", UIParent)
        deathRecapFrame:SetSize(520, 410)
        deathRecapFrame:SetPoint("CENTER")
        deathRecapFrame:SetFrameStrata("DIALOG")
        deathRecapFrame:SetMovable(true)
        deathRecapFrame:EnableMouse(true)
        deathRecapFrame:SetClampedToScreen(true)
        deathRecapFrame:RegisterForDrag("LeftButton")
        deathRecapFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        deathRecapFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        
        deathRecapFrame:SetBackdrop({
            bgFile = BG_FELLEATHER,
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 256,
            edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        deathRecapFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
        deathRecapFrame:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)

        local headerBg = deathRecapFrame:CreateTexture(nil, "BACKGROUND")
        headerBg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        headerBg:SetPoint("TOPLEFT", 14, -14)
        headerBg:SetPoint("TOPRIGHT", -14, -14)
        headerBg:SetHeight(28)
        headerBg:SetVertexColor(0.08, 0.08, 0.12, 0.72)
        deathRecapFrame.headerBg = headerBg

        local headerLine = deathRecapFrame:CreateTexture(nil, "BORDER")
        headerLine:SetTexture("Interface\\Buttons\\WHITE8x8")
        headerLine:SetPoint("TOPLEFT", headerBg, "BOTTOMLEFT", 0, -1)
        headerLine:SetPoint("TOPRIGHT", headerBg, "BOTTOMRIGHT", 0, -1)
        headerLine:SetHeight(1)
        headerLine:SetVertexColor(0.95, 0.78, 0.22, 0.8)
        deathRecapFrame.headerLine = headerLine
        
        -- Title
        local title = deathRecapFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -22)
        title:SetText("|cffff4040Death Recap|r")
        deathRecapFrame.title = title

        local subtitle = deathRecapFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
        subtitle:SetText("|cffb8b8b8Recent events leading to your death|r")
        deathRecapFrame.subtitle = subtitle
        
        -- Template-backed panels in 3.3.5 expect named frames.
        local recapFrameName = deathRecapFrame:GetName() or "DCQoS_DeathRecapFrame"

        -- Close button
        local closeBtn = CreateFrame("Button", recapFrameName .. "CloseButton", deathRecapFrame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -5, -5)
        closeBtn:SetScript("OnClick", function() deathRecapFrame:Hide() end)
        
        -- Use a plain ScrollFrame here to avoid template handlers that require
        -- strict named-frame conventions in older clients.
        local scrollFrame = CreateFrame("ScrollFrame", recapFrameName .. "ScrollFrame", deathRecapFrame)
        scrollFrame:SetPoint("TOPLEFT", 22, -68)
        scrollFrame:SetPoint("BOTTOMRIGHT", -42, 58)
        scrollFrame:EnableMouseWheel(true)
        
        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetSize(440, 1)
        scrollFrame:SetScrollChild(scrollChild)
        scrollFrame:SetScript("OnMouseWheel", function(self, delta)
            local child = self:GetScrollChild()
            if not child then return end

            local childHeight = child:GetHeight() or 0
            local viewHeight = self:GetHeight() or 0
            local maxScroll = math.max(0, childHeight - viewHeight)
            local current = self:GetVerticalScroll() or 0
            local nextValue = current - (delta * 24)
            if nextValue < 0 then
                nextValue = 0
            elseif nextValue > maxScroll then
                nextValue = maxScroll
            end
            self:SetVerticalScroll(nextValue)
        end)
        deathRecapFrame.scrollFrame = scrollFrame
        deathRecapFrame.scrollChild = scrollChild

        local summaryText = deathRecapFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        summaryText:SetPoint("BOTTOMLEFT", 24, 26)
        summaryText:SetWidth(300)
        summaryText:SetJustifyH("LEFT")
        summaryText:SetText("")
        deathRecapFrame.summaryText = summaryText
        
        -- Survivability rating
        local survText = deathRecapFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        survText:SetPoint("BOTTOMRIGHT", -24, 26)
        survText:SetJustifyH("RIGHT")
        survText:SetText("")
        deathRecapFrame.survText = survText

        local hintText = deathRecapFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hintText:SetPoint("BOTTOM", 0, 10)
        hintText:SetText("Mouse Wheel: Scroll  -  Drag: Move")
        deathRecapFrame.hintText = hintText
    end
    
    -- Clear old entries
    for _, child in ipairs({deathRecapFrame.scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Calculate survivability
    local totalDamage = 0
    local totalHealing = 0
    local mitigationEvents = 0
    
    for _, entry in ipairs(entries) do
        if entry.eventType == "damage" and entry.amount then
            totalDamage = totalDamage + math.abs(entry.amount)
        elseif entry.eventType == "heal" and entry.amount then
            totalHealing = totalHealing + entry.amount
        end
        if entry.absorbed or entry.resisted or entry.blocked then
            mitigationEvents = mitigationEvents + 1
        end
    end
    
    local survivability = "Poor"
    local survColor = {r=1, g=0, b=0}
    if totalHealing > totalDamage * 0.8 then
        survivability = "Good"
        survColor = {r=0, g=1, b=0}
    elseif mitigationEvents >= 3 then
        survivability = "Fair"
        survColor = {r=1, g=1, b=0}
    end
    
    deathRecapFrame.survText:SetText(string.format("Survivability: |cff%02x%02x%02x%s|r", 
        survColor.r * 255, survColor.g * 255, survColor.b * 255, survivability))

    if deathRecapFrame.summaryText then
        deathRecapFrame.summaryText:SetText(string.format(
            "|cffd0d0d0Damage:|r %s   |cffd0d0d0Healing:|r %s   |cffd0d0d0Mitigations:|r %d",
            FormatAmount(totalDamage),
            FormatAmount(totalHealing),
            mitigationEvents
        ))
    end
    
    -- Display events (most recent first)
    local yOffset = 0
    local shown = 0
    for i = 1, #entries do
        if shown >= maxEntries then
            break
        end
        local entry = entries[i]
        if not showBuffs and (entry.eventType == "buff" or entry.eventType == "debuff") then
            -- Skip buff/debuff rows when disabled
        else
            shown = shown + 1
        
            local eventFrame = CreateFrame("Frame", nil, deathRecapFrame.scrollChild)
            eventFrame:SetSize(430, 46)
            eventFrame:SetPoint("TOPLEFT", 0, yOffset)

            local style = GetRecapEventStyle(entry.eventType)
            eventFrame:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            eventFrame:SetBackdropColor(style.bg[1], style.bg[2], style.bg[3], style.bg[4])
            eventFrame:SetBackdropBorderColor(style.border[1], style.border[2], style.border[3], style.border[4])

            local accent = eventFrame:CreateTexture(nil, "ARTWORK")
            accent:SetTexture("Interface\\Buttons\\WHITE8x8")
            accent:SetPoint("TOPLEFT", 3, -3)
            accent:SetPoint("BOTTOMLEFT", 3, 3)
            accent:SetWidth(4)
            accent:SetVertexColor(style.accent[1], style.accent[2], style.accent[3], style.accent[4])

            local icon = eventFrame:CreateTexture(nil, "ARTWORK")
            icon:SetSize(18, 18)
            icon:SetPoint("TOPLEFT", 12, -11)
            icon:SetTexture(GetRecapEventIcon(entry))
        
            -- Time
            local timeText = eventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            timeText:SetPoint("TOPLEFT", 35, -7)
            timeText:SetText(string.format("%.1fs", entry.timestamp or 0))
            timeText:SetTextColor(0.75, 0.75, 0.75)
        
            -- Event description
            local descText = eventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            descText:SetPoint("TOPLEFT", 35, -20)
            descText:SetWidth(245)
            descText:SetJustifyH("LEFT")

            local detailText = eventFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            detailText:SetPoint("TOPLEFT", descText, "BOTTOMLEFT", 0, -1)
            detailText:SetWidth(245)
            detailText:SetJustifyH("LEFT")
            detailText:SetTextColor(0.75, 0.75, 0.75)
        
        if entry.eventType == "damage" then
            local color = entry.critical and {r=1, g=0.3, b=0.3} or {r=1, g=0.5, b=0.5}
            descText:SetTextColor(color.r, color.g, color.b)
            descText:SetText(string.format("%s's %s%s", 
                entry.sourceName or "Unknown",
                entry.spellName or "Attack",
                entry.critical and " (Crit!)" or ""
            ))
            local detail = string.format("HP: %.0f%%", entry.healthPct or 0)
            if entry.absorbed and entry.absorbed > 0 then
                detail = detail .. "  Abs: " .. FormatAmount(entry.absorbed)
            end
            if entry.resisted and entry.resisted > 0 then
                detail = detail .. "  Res: " .. FormatAmount(entry.resisted)
            end
            if entry.blocked and entry.blocked > 0 then
                detail = detail .. "  Block: " .. FormatAmount(entry.blocked)
            end
            detailText:SetText(detail)
        elseif entry.eventType == "heal" then
            descText:SetTextColor(0.2, 1, 0.2)
            descText:SetText(string.format("%s's %s", 
                entry.sourceName or "Unknown",
                entry.spellName or "Heal"
            ))
            detailText:SetText(string.format("HP: %.0f%%", entry.healthPct or 0))
        elseif entry.eventType == "buff" then
            descText:SetTextColor(0.5, 0.5, 1)
            descText:SetText(string.format("Buff: %s", entry.spellName or "Unknown"))
            detailText:SetText(string.format("HP: %.0f%%", entry.healthPct or 0))
        elseif entry.eventType == "debuff" then
            descText:SetTextColor(1, 0.5, 1)
            descText:SetText(string.format("Debuff: %s", entry.spellName or "Unknown"))
            detailText:SetText(string.format("HP: %.0f%%", entry.healthPct or 0))
        else
            descText:SetTextColor(0.85, 0.85, 0.85)
            descText:SetText(string.format("%s", entry.spellName or entry.eventType or "Event"))
            detailText:SetText(string.format("HP: %.0f%%", entry.healthPct or 0))
        end
        
            -- Amount
            local amountText = eventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            amountText:SetPoint("TOPRIGHT", -10, -10)
        
        if entry.eventType == "damage" then
            amountText:SetText(FormatAmount(math.abs(entry.amount or 0)))
            amountText:SetTextColor(1, 0.3, 0.3)
        elseif entry.eventType == "heal" then
            amountText:SetText("+" .. FormatAmount(entry.amount or 0))
            amountText:SetTextColor(0.2, 1, 0.2)
        else
            amountText:SetText("")
        end
        
            -- Health bar
            if entry.healthMax and entry.healthMax > 0 then
                local healthBar = CreateFrame("StatusBar", nil, eventFrame)
                healthBar:SetSize(125, 8)
                healthBar:SetPoint("BOTTOMRIGHT", -10, 8)
                healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
                healthBar:SetMinMaxValues(0, entry.healthMax)
                healthBar:SetValue(entry.health or 0)

                local healthBg = eventFrame:CreateTexture(nil, "BACKGROUND")
                healthBg:SetTexture("Interface\\Buttons\\WHITE8x8")
                healthBg:SetAllPoints(healthBar)
                healthBg:SetVertexColor(0, 0, 0, 0.45)
                
                local pct = entry.healthPct or 0
                if pct > 50 then
                    healthBar:SetStatusBarColor(0, 1, 0)
                elseif pct > 20 then
                    healthBar:SetStatusBarColor(1, 1, 0)
                else
                    healthBar:SetStatusBarColor(1, 0, 0)
                end
            end
            
            yOffset = yOffset - 50
        end
    end
    
    deathRecapFrame.scrollChild:SetHeight(math.max(1, shown * 50))
    if deathRecapFrame.scrollFrame then
        local childHeight = deathRecapFrame.scrollChild:GetHeight() or 0
        local viewHeight = deathRecapFrame.scrollFrame:GetHeight() or 0
        local maxScroll = math.max(0, childHeight - viewHeight)
        local current = deathRecapFrame.scrollFrame:GetVerticalScroll() or 0
        if current > maxScroll then
            deathRecapFrame.scrollFrame:SetVerticalScroll(maxScroll)
        end
    end
    deathRecapFrame:Show()
    return true
end

-- ============================================================
-- REGISTER ENHANCED FEATURES
-- ============================================================

if addon and addon.Debug then
    addon:Debug("Enhanced CombatLog features loaded")
end
