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

local function FormatNumber(value)
    if addon.FormatNumber then
        return addon.FormatNumber(value or 0)
    end
    return tostring(value or 0)
end

function CombatLog.ShowEnhancedTooltip(self)
    local data = self.playerData or self.data
    if not data then return false end

    local settings = addon.settings and addon.settings.combatLog or {}
    local mode = settings.meterMode or "damage"
    
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    
    -- Header
    local classColor = (data.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[data.class]) or {r=0.7, g=0.7, b=0.7}
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
    
    -- HEALING / ABSORB MODES - per-spell breakdown with overheal.
    -- Read from data.spells: healing and absorbs are tracked there.
    elseif mode == "healing" or mode == "absorbsHealing" or mode == "absorbs" then
        local sortedSpells = {}
        for _, spell in pairs(data.spells or {}) do
            local amount = 0
            if mode ~= "absorbs" then amount = amount + (spell.healing or 0) end
            if mode ~= "healing" then amount = amount + (spell.absorbAmount or 0) end
            if amount > 0 then
                table.insert(sortedSpells, {
                    name = spell.name,
                    amount = amount,
                    overheal = spell.overheal or 0,
                    hits = spell.hits or 0,
                    crits = spell.crits or 0,
                    isAbsorb = (spell.absorbAmount or 0) > 0 and (spell.healing or 0) == 0,
                })
            end
        end
        table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)

        if #sortedSpells == 0 then
            GameTooltip:AddLine("No healing data", 0.7, 0.7, 0.7)
        end
        for i = 1, math.min(10, #sortedSpells) do
            local spell = sortedSpells[i]
            local right
            if spell.isAbsorb then
                right = string.format("%s (absorb)", FormatNumber(spell.amount))
            else
                local overhealPct = (spell.amount + spell.overheal) > 0
                    and (spell.overheal / (spell.amount + spell.overheal) * 100) or 0
                right = string.format("%s (%.0f%% OH)", FormatNumber(spell.amount), overhealPct)
            end
            GameTooltip:AddDoubleLine(spell.name, right, spell.isAbsorb and 0.7 or 0.2, spell.isAbsorb and 0.7 or 1, spell.isAbsorb and 1 or 0.2, 1, 1, 1)
        end
        if (data.overhealing or 0) > 0 and (data.totalHealing or 0) > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Overhealing:", string.format("%s (%.0f%%)", FormatNumber(data.overhealing),
                data.overhealing / data.totalHealing * 100), 0.7, 0.7, 0.7, 1, 1, 1)
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

        if data.damageTakenFrom then
            local sources = {}
            for guid, amount in pairs(data.damageTakenFrom) do
                if amount > 0 then
                    sources[#sources + 1] = {
                        name = (CombatLog.GetNameForGUID and CombatLog.GetNameForGUID(guid)) or "Unknown",
                        amount = amount,
                    }
                end
            end
            table.sort(sources, function(a, b) return a.amount > b.amount end)
            if #sources > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Top sources", 1, 0.82, 0)
                for i = 1, math.min(5, #sources) do
                    GameTooltip:AddDoubleLine(sources[i].name, FormatNumber(sources[i].amount), 1, 1, 1, 0.8, 0.8, 0.8)
                end
            end
        end
    end
    
    -- Add summary stats
    GameTooltip:AddLine(" ")
    local combatTime = (CombatLog.GetActiveDuration and CombatLog.GetActiveDuration())
        or (CombatLog.GetCombatTime and CombatLog.GetCombatTime()) or 0
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
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: breakdown  |  Right-click: menu", 0.5, 0.5, 0.5)
    GameTooltip:Show()
    return true
end

-- ============================================================
-- ENHANCED DEATH RECAP
-- ============================================================
-- Layout: header (title + killing blow) / column labels / scrolling event
-- list (newest first) / footer totals. Rows keep one line of name and one
-- line of source + tags; the full numbers live in the row tooltip.

local FLAT_TEXTURE = "Interface\\Buttons\\WHITE8x8"

local RECAP_PAD = 10
local RECAP_HEADER_HEIGHT = 44
local RECAP_COLUMNS_HEIGHT = 18
local RECAP_FOOTER_HEIGHT = 28
local RECAP_ROW_HEIGHT = 34
local RECAP_ROW_GAP = 2
local RECAP_ROW_STEP = RECAP_ROW_HEIGHT + RECAP_ROW_GAP
local RECAP_VISIBLE_ROWS = 9
local RECAP_SCROLLBAR_WIDTH = 6
local RECAP_WIDTH = 500
local RECAP_LIST_WIDTH = RECAP_WIDTH - 2 * RECAP_PAD - RECAP_SCROLLBAR_WIDTH - 6
local RECAP_LIST_HEIGHT = RECAP_VISIBLE_ROWS * RECAP_ROW_STEP - RECAP_ROW_GAP
local RECAP_LIST_TOP = RECAP_PAD + RECAP_HEADER_HEIGHT + RECAP_COLUMNS_HEIGHT
local RECAP_HEIGHT = RECAP_LIST_TOP + RECAP_LIST_HEIGHT + 4 + RECAP_FOOTER_HEIGHT + RECAP_PAD

-- Row columns, in pixels from the row's left / right edge.
local COL_TIME_RIGHT = 44
local COL_ICON_LEFT = 54
local COL_TEXT_LEFT = 86
local COL_HEALTH_RIGHT = 8
local COL_HEALTH_WIDTH = 84
local COL_AMOUNT_WIDTH = 64
local COL_AMOUNT_RIGHT = COL_HEALTH_RIGHT + COL_HEALTH_WIDTH + 12
local COL_TEXT_WIDTH = RECAP_LIST_WIDTH - COL_TEXT_LEFT - COL_AMOUNT_RIGHT - COL_AMOUNT_WIDTH - 8

local RECAP_EVENT_STYLE = {
    damage = {
        tint = {0.60, 0.10, 0.10},
        accent = {0.95, 0.30, 0.30},
        name = {1.00, 0.88, 0.88},
        amount = {1.00, 0.40, 0.40},
        icon = "Interface\\Icons\\Ability_Creature_Cursed_05",
    },
    heal = {
        tint = {0.10, 0.50, 0.10},
        accent = {0.35, 0.90, 0.35},
        name = {0.75, 1.00, 0.75},
        amount = {0.40, 1.00, 0.40},
        icon = "Interface\\Icons\\Spell_Holy_HolyBolt",
    },
    buff = {
        tint = {0.12, 0.22, 0.55},
        accent = {0.45, 0.62, 1.00},
        name = {0.75, 0.84, 1.00},
        amount = {0.50, 0.62, 0.90},
        icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
        label = "Buff",
    },
    debuff = {
        tint = {0.45, 0.12, 0.50},
        accent = {0.85, 0.45, 1.00},
        name = {0.92, 0.78, 1.00},
        amount = {0.78, 0.55, 0.90},
        icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges",
        label = "Debuff",
    },
    default = {
        tint = {0.30, 0.30, 0.30},
        accent = {0.70, 0.70, 0.70},
        name = {0.90, 0.90, 0.90},
        amount = {0.80, 0.80, 0.80},
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
    },
}

local ENVIRONMENT_ICONS = {
    FALLING = "Interface\\Icons\\Spell_Magic_FeatherFall",
    DROWNING = "Interface\\Icons\\Spell_Shadow_DemonBreath",
    FATIGUE = "Interface\\Icons\\Spell_Nature_Sleep",
    FIRE = "Interface\\Icons\\Spell_Fire_Fire",
    LAVA = "Interface\\Icons\\Spell_Fire_Volcano",
    SLIME = "Interface\\Icons\\Spell_Nature_Acid_01",
}

local deathRecapFrame = nil

local function GetRecapEventStyle(eventType)
    return RECAP_EVENT_STYLE[eventType] or RECAP_EVENT_STYLE.default
end

-- The recorder stores melee swings with spellId 0 and environmental damage
-- with spellId -1, where the environment type ("FALLING") is the spell name.
local function IsEnvironmental(entry)
    return entry.spellId == -1
end

local function GetRecapSpellName(entry)
    if IsEnvironmental(entry) then
        local env = tostring(entry.spellName or "Environment")
        return env:sub(1, 1):upper() .. env:sub(2):lower()
    end
    if entry.spellName and entry.spellName ~= "" then
        return entry.spellName
    end
    if entry.spellId == 0 then
        return "Melee"
    end
    if entry.spellId and entry.spellId > 0 then
        local name = GetSpellInfo(entry.spellId)
        if name then
            return name
        end
    end
    return "Unknown"
end

local function GetRecapSourceName(entry)
    if IsEnvironmental(entry) then
        return "Environment"
    end
    return entry.sourceName or "Unknown"
end

-- GetSpellTexture() on 3.3.5 resolves spellbook slots and known spell names
-- only, so NPC abilities fell through to the generic icon. GetSpellInfo()
-- returns the icon for any spell id the client knows.
local function GetRecapEventIcon(entry)
    if entry.spellId == 0 then
        return "Interface\\Icons\\INV_Sword_04"
    end
    if IsEnvironmental(entry) then
        local icon = ENVIRONMENT_ICONS[tostring(entry.spellName or ""):upper()]
        if icon then
            return icon
        end
    elseif entry.spellId and entry.spellId > 0 then
        local _, _, texture = GetSpellInfo(entry.spellId)
        if texture then
            return texture
        end
    end
    return GetRecapEventStyle(entry.eventType).icon
end

local function GetHealthColor(pct)
    if pct > 50 then
        return 0.25, 0.78, 0.25
    elseif pct > 20 then
        return 0.90, 0.72, 0.10
    end
    return 0.85, 0.18, 0.18
end

-- `time` is absolute GetTime(); `timestamp` (combat-relative) is the fallback.
local function GetEntryTime(entry)
    return entry.time or entry.timestamp or 0
end

local function FormatRecapTime(seconds)
    if seconds > -0.05 then
        return "0.0s"
    elseif seconds > -10 then
        return string.format("%.1fs", seconds)
    end
    return string.format("%.0fs", seconds)
end

local function FormatExact(value)
    return tostring(math.floor((value or 0) + 0.5))
end

local function SetSingleLine(fontString)
    if fontString.SetWordWrap then fontString:SetWordWrap(false) end
    if fontString.SetNonSpaceWrap then fontString:SetNonSpaceWrap(false) end
end

local function CreateLabel(parent, template, r, g, b)
    local label = parent:CreateFontString(nil, "OVERLAY", template)
    if r then
        label:SetTextColor(r, g, b)
    end
    return label
end

local function CreateDivider(parent)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture(FLAT_TEXTURE)
    line:SetVertexColor(1, 1, 1, 0.10)
    line:SetHeight(1)
    return line
end

local function ScrollRecap(_, delta)
    local bar = deathRecapFrame and deathRecapFrame.scrollBar
    if not bar then return end
    local _, maxValue = bar:GetMinMaxValues()
    local value = (bar:GetValue() or 0) - delta * RECAP_ROW_STEP
    bar:SetValue(math.max(0, math.min(maxValue or 0, value)))
end

local function UpdateRecapScroll(resetToTop)
    local frame = deathRecapFrame
    local childHeight = frame.scrollChild:GetHeight() or 0
    local maxScroll = math.max(0, childHeight - RECAP_LIST_HEIGHT)
    local bar = frame.scrollBar

    bar:SetMinMaxValues(0, maxScroll)
    if maxScroll > 0 then
        bar.thumb:SetHeight(math.max(24, RECAP_LIST_HEIGHT * RECAP_LIST_HEIGHT / childHeight))
        bar:Show()
    else
        bar:Hide()
    end

    local value = resetToTop and 0 or math.min(bar:GetValue() or 0, maxScroll)
    bar:SetValue(value)
    frame.scrollFrame:SetVerticalScroll(value)
end

local function ShowRecapRowTooltip(row)
    row.highlight:Show()
    local entry = row.entry
    if not entry then return end

    local style = GetRecapEventStyle(entry.eventType)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if entry.spellId and entry.spellId > 0 and GetSpellInfo(entry.spellId) then
        GameTooltip:SetHyperlink("spell:" .. entry.spellId)
        GameTooltip:AddLine(" ")
    else
        GameTooltip:SetText(GetRecapSpellName(entry), style.name[1], style.name[2], style.name[3])
    end

    local lr, lg, lb = 0.65, 0.65, 0.65
    GameTooltip:AddDoubleLine("Source", GetRecapSourceName(entry), lr, lg, lb, 1, 1, 1)

    if entry.eventType == "damage" then
        local hitType = entry.critical and " (critical)" or (entry.glancing and " (glancing)" or "")
        GameTooltip:AddDoubleLine("Damage", FormatExact(math.abs(entry.amount or 0)) .. hitType,
            lr, lg, lb, style.amount[1], style.amount[2], style.amount[3])
        if (entry.overkill or 0) > 0 then
            GameTooltip:AddDoubleLine("Overkill", FormatExact(entry.overkill), lr, lg, lb, 1, 0.38, 0.38)
        end
        if (entry.absorbed or 0) > 0 then
            GameTooltip:AddDoubleLine("Absorbed", FormatExact(entry.absorbed), lr, lg, lb, 0.62, 0.77, 1)
        end
        if (entry.resisted or 0) > 0 then
            GameTooltip:AddDoubleLine("Resisted", FormatExact(entry.resisted), lr, lg, lb, 1, 1, 1)
        end
        if (entry.blocked or 0) > 0 then
            GameTooltip:AddDoubleLine("Blocked", FormatExact(entry.blocked), lr, lg, lb, 1, 1, 1)
        end
    elseif entry.eventType == "heal" then
        GameTooltip:AddDoubleLine("Healing", FormatExact(entry.amount),
            lr, lg, lb, style.amount[1], style.amount[2], style.amount[3])
    elseif style.label then
        GameTooltip:AddDoubleLine("Event", style.label .. " applied", lr, lg, lb, 1, 1, 1)
    end

    if (entry.healthMax or 0) > 0 then
        local pct = entry.healthPct or ((entry.health or 0) / entry.healthMax * 100)
        GameTooltip:AddDoubleLine("Health", string.format("%s / %s (%.0f%%)",
            FormatExact(entry.health), FormatExact(entry.healthMax), pct), lr, lg, lb, GetHealthColor(pct))
    end

    local before = -(row.relativeTime or 0)
    GameTooltip:AddDoubleLine("Time", before >= 0.05 and string.format("%.1f sec before death", before)
        or "At time of death", lr, lg, lb, 1, 1, 1)
    GameTooltip:Show()
end

local function HideRecapRowTooltip(row)
    row.highlight:Hide()
    GameTooltip:Hide()
end

local function CreateRecapRow(index)
    local frame = deathRecapFrame
    local row = CreateFrame("Frame", nil, frame.scrollChild)
    local y = -(index - 1) * RECAP_ROW_STEP
    row:SetSize(RECAP_LIST_WIDTH, RECAP_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 0, y)
    row:EnableMouse(true)
    row:EnableMouseWheel(true)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function() frame:StartMoving() end)
    row:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    row:SetScript("OnMouseWheel", ScrollRecap)
    row:SetScript("OnEnter", ShowRecapRowTooltip)
    row:SetScript("OnLeave", HideRecapRowTooltip)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetTexture(FLAT_TEXTURE)

    row.highlight = row:CreateTexture(nil, "BORDER")
    row.highlight:SetAllPoints()
    row.highlight:SetTexture(FLAT_TEXTURE)
    row.highlight:SetVertexColor(1, 1, 1, 0.06)
    row.highlight:Hide()

    row.accent = row:CreateTexture(nil, "ARTWORK")
    row.accent:SetTexture(FLAT_TEXTURE)
    row.accent:SetPoint("TOPLEFT")
    row.accent:SetPoint("BOTTOMLEFT")
    row.accent:SetWidth(2)

    row.timeText = CreateLabel(row, "GameFontHighlightSmall", 0.60, 0.60, 0.60)
    row.timeText:SetPoint("RIGHT", row, "LEFT", COL_TIME_RIGHT, 0)
    row.timeText:SetJustifyH("RIGHT")

    row.iconBorder = row:CreateTexture(nil, "ARTWORK")
    row.iconBorder:SetTexture(FLAT_TEXTURE)
    row.iconBorder:SetVertexColor(0, 0, 0, 0.9)
    row.iconBorder:SetSize(26, 26)
    row.iconBorder:SetPoint("LEFT", row, "LEFT", COL_ICON_LEFT, 0)

    row.icon = row:CreateTexture(nil, "OVERLAY")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("CENTER", row.iconBorder)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.nameText = CreateLabel(row, "GameFontHighlight")
    row.nameText:SetPoint("TOPLEFT", row, "TOPLEFT", COL_TEXT_LEFT, -4)
    row.nameText:SetSize(COL_TEXT_WIDTH, 14)
    row.nameText:SetJustifyH("LEFT")
    SetSingleLine(row.nameText)

    row.detailText = CreateLabel(row, "GameFontHighlightSmall", 0.62, 0.62, 0.62)
    row.detailText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", COL_TEXT_LEFT, 5)
    row.detailText:SetSize(COL_TEXT_WIDTH, 12)
    row.detailText:SetJustifyH("LEFT")
    SetSingleLine(row.detailText)

    row.amountText = CreateLabel(row, "GameFontHighlight")
    row.amountText:SetPoint("RIGHT", row, "RIGHT", -COL_AMOUNT_RIGHT, 0)
    row.amountText:SetWidth(COL_AMOUNT_WIDTH)
    row.amountText:SetJustifyH("RIGHT")

    row.healthBar = CreateFrame("StatusBar", nil, row)
    row.healthBar:SetSize(COL_HEALTH_WIDTH, 14)
    row.healthBar:SetPoint("RIGHT", row, "RIGHT", -COL_HEALTH_RIGHT, 0)
    row.healthBar:SetStatusBarTexture(FLAT_TEXTURE)

    local healthBg = row.healthBar:CreateTexture(nil, "BACKGROUND")
    healthBg:SetAllPoints()
    healthBg:SetTexture(FLAT_TEXTURE)
    healthBg:SetVertexColor(0, 0, 0, 0.55)

    row.healthText = CreateLabel(row.healthBar, "GameFontHighlightSmall")
    row.healthText:SetPoint("CENTER", row.healthBar, "CENTER", 0, 0)

    return row
end

local function FillRecapRow(row, entry, deathTime, isKillingBlow)
    local style = GetRecapEventStyle(entry.eventType)
    row.entry = entry
    row.relativeTime = GetEntryTime(entry) - deathTime

    row.bg:SetVertexColor(style.tint[1], style.tint[2], style.tint[3], isKillingBlow and 0.34 or 0.14)
    row.accent:SetVertexColor(style.accent[1], style.accent[2], style.accent[3], 1)
    row.icon:SetTexture(GetRecapEventIcon(entry))
    row.timeText:SetText(FormatRecapTime(row.relativeTime))
    row.nameText:SetText(GetRecapSpellName(entry))
    row.nameText:SetTextColor(style.name[1], style.name[2], style.name[3])
    row.amountText:SetTextColor(style.amount[1], style.amount[2], style.amount[3])

    local tags = {}
    if entry.eventType == "damage" then
        row.amountText:SetText("-" .. FormatNumber(math.abs(entry.amount or 0)))
        if entry.critical then
            tags[#tags + 1] = "|cffffb040Critical|r"
        elseif entry.glancing then
            tags[#tags + 1] = "Glancing"
        end
        if (entry.overkill or 0) > 0 then
            tags[#tags + 1] = "|cffff6060" .. FormatNumber(entry.overkill) .. " overkill|r"
        end
        if (entry.absorbed or 0) > 0 then
            tags[#tags + 1] = "|cff9fc5ff" .. FormatNumber(entry.absorbed) .. " absorbed|r"
        end
        if (entry.resisted or 0) > 0 then
            tags[#tags + 1] = FormatNumber(entry.resisted) .. " resisted"
        end
        if (entry.blocked or 0) > 0 then
            tags[#tags + 1] = FormatNumber(entry.blocked) .. " blocked"
        end
    elseif entry.eventType == "heal" then
        row.amountText:SetText("+" .. FormatNumber(entry.amount or 0))
    else
        row.amountText:SetText(style.label or "")
    end

    local detail = GetRecapSourceName(entry)
    if #tags > 0 then
        detail = detail .. "  |cff606060-|r  " .. table.concat(tags, ", ")
    end
    row.detailText:SetText(detail)

    local healthMax = entry.healthMax or 0
    if healthMax > 0 then
        local pct = entry.healthPct or ((entry.health or 0) / healthMax * 100)
        row.healthBar:SetMinMaxValues(0, healthMax)
        row.healthBar:SetValue(entry.health or 0)
        row.healthBar:SetStatusBarColor(GetHealthColor(pct))
        row.healthText:SetText(string.format("%.0f%%", pct))
        row.healthText:SetTextColor(1, 1, 1)
    else
        row.healthBar:SetMinMaxValues(0, 1)
        row.healthBar:SetValue(0)
        row.healthText:SetText("--")
        row.healthText:SetTextColor(0.5, 0.5, 0.5)
    end

    row:Show()
end

local function CreateDeathRecapFrame()
    local frame = CreateFrame("Frame", "DCQoS_DeathRecapFrame", UIParent)
    deathRecapFrame = frame
    frame:SetSize(RECAP_WIDTH, RECAP_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnMouseWheel", ScrollRecap)
    frame:SetScript("OnHide", function() GameTooltip:Hide() end)
    tinsert(UISpecialFrames, frame:GetName())

    -- Same flat panel as the meter window, over the shared DC leather.
    frame:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropBorderColor(0.45, 0.45, 0.45, 0.95)

    local leather = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    leather:SetPoint("TOPLEFT", 3, -3)
    leather:SetPoint("BOTTOMRIGHT", -3, 3)
    leather:SetTexture(BG_FELLEATHER)

    local tint = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    tint:SetAllPoints(leather)
    tint:SetTexture(FLAT_TEXTURE)
    tint:SetVertexColor(0.03, 0.03, 0.04, 0.86)

    -- Header: faint red glow, accent strip, title, killing blow line.
    local glow = frame:CreateTexture(nil, "BORDER")
    glow:SetPoint("TOPLEFT", 3, -3)
    glow:SetPoint("TOPRIGHT", -3, -3)
    glow:SetHeight(RECAP_PAD + RECAP_HEADER_HEIGHT - 3)
    glow:SetTexture(FLAT_TEXTURE)
    glow:SetGradientAlpha("VERTICAL", 0.6, 0.08, 0.08, 0, 0.6, 0.08, 0.08, 0.28)

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetTexture(FLAT_TEXTURE)
    accent:SetVertexColor(0.95, 0.30, 0.30, 1)
    accent:SetPoint("TOPLEFT", RECAP_PAD, -(RECAP_PAD + 4))
    accent:SetSize(3, 32)

    frame.title = CreateLabel(frame, "GameFontNormalLarge", 1, 0.32, 0.32)
    frame.title:SetPoint("TOPLEFT", RECAP_PAD + 10, -(RECAP_PAD + 4))
    frame.title:SetText("Death Recap")

    frame.subtitle = CreateLabel(frame, "GameFontHighlightSmall", 0.72, 0.72, 0.72)
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
    frame.subtitle:SetSize(RECAP_WIDTH - 2 * RECAP_PAD - 40, 12)
    frame.subtitle:SetJustifyH("LEFT")
    SetSingleLine(frame.subtitle)

    local closeBtn = CreateFrame("Button", frame:GetName() .. "CloseButton", frame, "UIPanelCloseButton")
    closeBtn:SetSize(26, 26)
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local headerLine = CreateDivider(frame)
    headerLine:SetPoint("TOPLEFT", RECAP_PAD, -(RECAP_PAD + RECAP_HEADER_HEIGHT))
    headerLine:SetPoint("TOPRIGHT", -RECAP_PAD, -(RECAP_PAD + RECAP_HEADER_HEIGHT))

    -- Column labels, aligned to the row columns below.
    local labelY = -(RECAP_PAD + RECAP_HEADER_HEIGHT + RECAP_COLUMNS_HEIGHT / 2)
    local function ColumnLabel(text, point, x)
        local label = CreateLabel(frame, "GameFontDisableSmall", 0.50, 0.50, 0.50)
        label:SetPoint(point, frame, "TOPLEFT", RECAP_PAD + x, labelY)
        label:SetText(text)
    end
    ColumnLabel("TIME", "RIGHT", COL_TIME_RIGHT)
    ColumnLabel("EVENT", "LEFT", COL_ICON_LEFT)
    ColumnLabel("AMOUNT", "RIGHT", RECAP_LIST_WIDTH - COL_AMOUNT_RIGHT)
    ColumnLabel("HEALTH", "CENTER", RECAP_LIST_WIDTH - COL_HEALTH_RIGHT - COL_HEALTH_WIDTH / 2)

    -- Plain ScrollFrame: the UIPanelScrollFrame templates need named
    -- children laid out their way, and a thin custom bar reads cleaner here.
    local scrollFrame = CreateFrame("ScrollFrame", frame:GetName() .. "ScrollFrame", frame)
    scrollFrame:SetPoint("TOPLEFT", RECAP_PAD, -RECAP_LIST_TOP)
    scrollFrame:SetSize(RECAP_LIST_WIDTH, RECAP_LIST_HEIGHT)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", ScrollRecap)
    frame.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(RECAP_LIST_WIDTH, 1)
    scrollFrame:SetScrollChild(scrollChild)
    frame.scrollChild = scrollChild

    local scrollBar = CreateFrame("Slider", nil, frame)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetSize(RECAP_SCROLLBAR_WIDTH, RECAP_LIST_HEIGHT)
    scrollBar:SetPoint("TOPRIGHT", -RECAP_PAD, -RECAP_LIST_TOP)
    scrollBar:EnableMouseWheel(true)
    scrollBar:SetScript("OnMouseWheel", ScrollRecap)
    scrollBar:SetValueStep(1)
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValue(0)

    local track = scrollBar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetTexture(FLAT_TEXTURE)
    track:SetVertexColor(1, 1, 1, 0.05)

    local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(FLAT_TEXTURE)
    thumb:SetVertexColor(1, 1, 1, 0.30)
    thumb:SetSize(RECAP_SCROLLBAR_WIDTH, 40)
    scrollBar:SetThumbTexture(thumb)
    scrollBar.thumb = thumb
    scrollBar:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetVerticalScroll(value)
    end)
    frame.scrollBar = scrollBar

    -- Footer: totals on the left, rating on the right.
    local footerLine = CreateDivider(frame)
    footerLine:SetPoint("BOTTOMLEFT", RECAP_PAD, RECAP_PAD + RECAP_FOOTER_HEIGHT)
    footerLine:SetPoint("BOTTOMRIGHT", -RECAP_PAD, RECAP_PAD + RECAP_FOOTER_HEIGHT)

    local footerY = RECAP_PAD + RECAP_FOOTER_HEIGHT / 2
    frame.summaryText = CreateLabel(frame, "GameFontHighlightSmall")
    frame.summaryText:SetPoint("LEFT", frame, "BOTTOMLEFT", RECAP_PAD + 2, footerY)
    frame.summaryText:SetJustifyH("LEFT")

    frame.survText = CreateLabel(frame, "GameFontHighlightSmall")
    frame.survText:SetPoint("RIGHT", frame, "BOTTOMRIGHT", -(RECAP_PAD + 2), footerY)
    frame.survText:SetJustifyH("RIGHT")

    frame.rows = {}
    return frame
end

function CombatLog.ShowDeathRecap(playerData)
    local entries = CombatLog.GetDeathLogEntries and CombatLog.GetDeathLogEntries(playerData, true) or (playerData and playerData.deathLog) or {}
    if not entries or #entries == 0 then
        return false
    end

    local settings = addon.settings and addon.settings.combatLog or {}
    local maxEntries = math.max(5, settings.deathRecapCount or 15)
    local showBuffs = settings.deathRecapShowBuffs ~= false

    local frame = deathRecapFrame or CreateDeathRecapFrame()

    -- Totals. The recorder stores 0 (not nil) for unmitigated hits, so a
    -- truthiness test here would count every hit as mitigated.
    local totalDamage, totalHealing, mitigated = 0, 0, 0
    local killer = nil
    for _, entry in ipairs(entries) do
        if entry.eventType == "damage" then
            totalDamage = totalDamage + math.abs(entry.amount or 0)
            if (entry.absorbed or 0) > 0 or (entry.resisted or 0) > 0 or (entry.blocked or 0) > 0 then
                mitigated = mitigated + 1
            end
            killer = killer or entry
        elseif entry.eventType == "heal" then
            totalHealing = totalHealing + (entry.amount or 0)
        end
    end

    -- Only an overkill hit is provably the killing blow; instakills and other
    -- unlogged deaths leave the newest hit as merely the last one taken.
    local killedBy = killer and (killer.overkill or 0) > 0
    local verb = killedBy and "Killed by" or "Last hit by"
    if killer and IsEnvironmental(killer) then
        frame.subtitle:SetText(string.format("%s |cffffffff%s|r damage", verb, GetRecapSpellName(killer)))
    elseif killer then
        local extra = GetRecapSpellName(killer)
        if killedBy then
            extra = extra .. ", |cffff6060" .. FormatNumber(killer.overkill) .. " overkill|r"
        end
        frame.subtitle:SetText(string.format("%s |cffffffff%s|r  (%s)", verb, GetRecapSourceName(killer), extra))
    else
        frame.subtitle:SetText("Recent events leading to your death")
    end

    local survivability, survColor = "Poor", "ff4040"
    if totalHealing > totalDamage * 0.8 then
        survivability, survColor = "Good", "40ff40"
    elseif mitigated >= 3 then
        survivability, survColor = "Fair", "ffd040"
    end
    frame.survText:SetText(string.format("|cff8a8a8aSurvivability|r  |cff%s%s|r", survColor, survivability))
    frame.summaryText:SetText(string.format(
        "|cff8a8a8aDamage taken|r  |cffff6666%s|r     |cff8a8a8aHealing|r  |cff66ff66%s|r     |cff8a8a8aMitigated hits|r  %d",
        FormatNumber(totalDamage), FormatNumber(totalHealing), mitigated))

    -- Rows are pooled and re-filled so a recap does not leak a frame tree per
    -- entry per death. Entries arrive newest first; times are shown relative to
    -- the newest one.
    local rows = frame.rows
    local deathTime = GetEntryTime(entries[1])
    local shown = 0
    for _, entry in ipairs(entries) do
        if shown >= maxEntries then
            break
        end
        if showBuffs or (entry.eventType ~= "buff" and entry.eventType ~= "debuff") then
            shown = shown + 1
            rows[shown] = rows[shown] or CreateRecapRow(shown)
            FillRecapRow(rows[shown], entry, deathTime, killedBy and entry == killer)
        end
    end
    for i = shown + 1, #rows do
        rows[i].entry = nil
        rows[i]:Hide()
    end

    frame.scrollChild:SetHeight(math.max(1, shown * RECAP_ROW_STEP - RECAP_ROW_GAP))
    frame:Show()
    UpdateRecapScroll(true)
    return true
end

-- ============================================================
-- REGISTER ENHANCED FEATURES
-- ============================================================

if addon and addon.Debug then
    addon:Debug("Enhanced CombatLog features loaded")
end
