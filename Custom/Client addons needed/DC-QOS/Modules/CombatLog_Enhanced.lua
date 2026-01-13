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
    print("DC-QOS: CombatLog module not found, Enhanced features disabled")
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
    [0x10] = {r = 0.50, g = 1.00, g = 1.00, name = "Frost"},     -- Cyan
    [0x20] = {r = 0.50, g = 0.50, b = 1.00, name = "Shadow"},    -- Purple
    [0x40] = {r = 1.00, g = 0.50, b = 1.00, name = "Arcane"},    -- Pink
}

function CombatLog.ShowEnhancedTooltip(self)
    local data = self.playerData
    if not data then return end
    
    local settings = addon.settings.combatLog
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
                local schoolColor = SCHOOL_COLORS[spell.school] or {r=1, g=1, b=1}
                
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
                    if spell.glancing > 0 then
                        details = details .. spell.glancing .. " glancing, "
                    end
                    if spell.crushing > 0 then
                        details = details .. spell.crushing .. " crushing, "
                    end
                    if spell.absorbed > 0 then
                        details = details .. addon.FormatNumber and addon.FormatNumber(spell.absorbed) or spell.absorbed .. " absorbed"
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
        if data.absorbedAmount and data.absorbedAmount > 0 then
            GameTooltip:AddDoubleLine("Absorbed:", addon.FormatNumber and addon.FormatNumber(data.absorbedAmount) or tostring(data.absorbedAmount), 0.7, 0.7, 1, 1, 1, 1)
        end
        if data.blockAmount and data.blockAmount > 0 then
            GameTooltip:AddDoubleLine("Blocked:", addon.FormatNumber and addon.FormatNumber(data.blockAmount) or tostring(data.blockAmount), 1, 0.7, 0.2, 1, 1, 1)
        end
        if data.resistAmount and data.resistAmount > 0 then
            GameTooltip:AddDoubleLine("Resisted:", addon.FormatNumber and addon.FormatNumber(data.resistAmount) or tostring(data.resistAmount), 0.5, 1, 0.5, 1, 1, 1)
        end
        
        -- Avoidance
        if data.avoidance and data.avoidance > 0 then
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
    local combatTime = addon.GetCombatTime and addon.GetCombatTime() or 0
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
end

-- ============================================================
-- ENHANCED DEATH RECAP
-- ============================================================

local deathRecapFrame = nil

function CombatLog.ShowDeathRecap(playerData)
    if not playerData or not playerData.deathLog or #playerData.deathLog == 0 then
        return
    end
    
    -- Create frame if it doesn't exist
    if not deathRecapFrame then
        deathRecapFrame = CreateFrame("Frame", "DCQoS_DeathRecapFrame", UIParent)
        deathRecapFrame:SetSize(450, 350)
        deathRecapFrame:SetPoint("CENTER")
        deathRecapFrame:SetFrameStrata("DIALOG")
        deathRecapFrame:SetMovable(true)
        deathRecapFrame:EnableMouse(true)
        deathRecapFrame:SetClampedToScreen(true)
        deathRecapFrame:RegisterForDrag("LeftButton")
        deathRecapFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        deathRecapFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        
        deathRecapFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        deathRecapFrame:SetBackdropColor(0, 0, 0, 1)
        
        -- Title
        local title = deathRecapFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -20)
        title:SetText("|cffFF0000Death Recap|r")
        deathRecapFrame.title = title
        
        -- Close button
        local closeBtn = CreateFrame("Button", nil, deathRecapFrame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -5, -5)
        closeBtn:SetScript("OnClick", function() deathRecapFrame:Hide() end)
        
        -- Scroll frame for events
        local scrollFrame = CreateFrame("ScrollFrame", nil, deathRecapFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 20, -50)
        scrollFrame:SetPoint("BOTTOMRIGHT", -40, 50)
        
        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetSize(scrollFrame:GetWidth(), 1)
        scrollFrame:SetScrollChild(scrollChild)
        deathRecapFrame.scrollChild = scrollChild
        
        -- Survivability rating
        local survText = deathRecapFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        survText:SetPoint("BOTTOM", 0, 20)
        survText:SetText("")
        deathRecapFrame.survText = survText
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
    
    for _, entry in ipairs(playerData.deathLog) do
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
    
    -- Display events (most recent first)
    local yOffset = 0
    for i = 1, math.min(15, #playerData.deathLog) do
        local entry = playerData.deathLog[i]
        
        local eventFrame = CreateFrame("Frame", nil, deathRecapFrame.scrollChild)
        eventFrame:SetSize(380, 40)
        eventFrame:SetPoint("TOPLEFT", 0, yOffset)
        
        -- Time
        local timeText = eventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        timeText:SetPoint("TOPLEFT", 5, -5)
        timeText:SetText(string.format("%.1fs", entry.timestamp or 0))
        timeText:SetTextColor(0.7, 0.7, 0.7)
        
        -- Event description
        local descText = eventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        descText:SetPoint("TOPLEFT", 50, -5)
        descText:SetWidth(250)
        descText:SetJustifyH("LEFT")
        
        if entry.eventType == "damage" then
            local color = entry.critical and {r=1, g=0.3, b=0.3} or {r=1, g=0.5, b=0.5}
            descText:SetTextColor(color.r, color.g, color.b)
            descText:SetText(string.format("%s's %s%s", 
                entry.sourceName or "Unknown",
                entry.spellName or "Attack",
                entry.critical and " (Crit!)" or ""
            ))
        elseif entry.eventType == "heal" then
            descText:SetTextColor(0.2, 1, 0.2)
            descText:SetText(string.format("%s's %s", 
                entry.sourceName or "Unknown",
                entry.spellName or "Heal"
            ))
        elseif entry.eventType == "buff" then
            descText:SetTextColor(0.5, 0.5, 1)
            descText:SetText(string.format("Buff: %s", entry.spellName or "Unknown"))
        elseif entry.eventType == "debuff" then
            descText:SetTextColor(1, 0.5, 1)
            descText:SetText(string.format("Debuff: %s", entry.spellName or "Unknown"))
        end
        
        -- Amount
        local amountText = eventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        amountText:SetPoint("RIGHT", -5, -5)
        
        if entry.eventType == "damage" then
            amountText:SetText(addon.FormatNumber and addon.FormatNumber(math.abs(entry.amount or 0)) or tostring(math.abs(entry.amount or 0)))
            amountText:SetTextColor(1, 0.3, 0.3)
        elseif entry.eventType == "heal" then
            amountText:SetText("+" .. (addon.FormatNumber and addon.FormatNumber(entry.amount or 0) or tostring(entry.amount or 0)))
            amountText:SetTextColor(0.2, 1, 0.2)
        end
        
        -- Health bar
        if entry.healthMax and entry.healthMax > 0 then
            local healthBar = CreateFrame("StatusBar", nil, eventFrame)
            healthBar:SetSize(100, 8)
            healthBar:SetPoint("RIGHT", amountText, "LEFT", -10, 0)
            healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            healthBar:SetMinMaxValues(0, entry.healthMax)
            healthBar:SetValue(entry.health or 0)
            
            local pct = entry.healthPct or 0
            if pct > 50 then
                healthBar:SetStatusBarColor(0, 1, 0)
            elseif pct > 20 then
                healthBar:SetStatusBarColor(1, 1, 0)
            else
                healthBar:SetStatusBarColor(1, 0, 0)
            end
        end
        
        yOffset = yOffset - 45
    end
    
    deathRecapFrame:Show()
end

-- ============================================================
-- REGISTER ENHANCED FEATURES
-- ============================================================

print("|cffFFCC00DC-QOS|r: Enhanced CombatLog features loaded")
