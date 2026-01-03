-- ============================================================
-- DC-QoS: CombatLog Module
-- ============================================================
-- Combat statistics with party/raid tracking
-- Now includes: DPS bars, segment history, threat meter
-- For full raid analysis, use Skada: github.com/bkader/Skada-WoTLK
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local CombatLog = {
    displayName = "Combat Log",
    settingKey = "combatLog",
    icon = "Interface\\Icons\\Ability_DualWield",
    defaults = {
        combatLog = {
            enabled = true,
            -- Display Mode
            showMeter = true,
            meterMode = "damage", -- damage, healing, damageTaken, threat, dispels
            showBars = true,
            maxBars = 10,
            barHeight = 18,
            -- Personal Stats
            showPersonalDPS = true,
            showPersonalHPS = false,
            -- Group Tracking
            trackGroup = true,
            -- Spell Breakdown
            showSpellBreakdown = true,
            maxSpells = 5,
            -- Death Recap
            deathRecap = true,
            deathRecapCount = 5,
            -- Interrupts
            trackInterrupts = true,
            announceInterrupts = false,
            interruptChannel = "SAY",
            -- Advanced Metrics
            trackDispels = true,
            trackAbsorbs = true,
            -- Segments
            keepSegments = 5,
            -- Position
            frameX = nil,
            frameY = nil,
            frameWidth = 200,
            frameHeight = 250,
            frameScale = 1.0,
            frameAlpha = 0.9,
            -- Combat Timer
            showCombatTimer = true,
        },
    },
}

-- Merge defaults
for k, v in pairs(CombatLog.defaults) do
    if addon.defaults[k] == nil then
        addon.defaults[k] = v
    else
        for k2, v2 in pairs(v) do
            if addon.defaults[k][k2] == nil then
                addon.defaults[k][k2] = v2
            end
        end
    end
end

-- ============================================================
-- State Variables
-- ============================================================
local combatFrame = nil
local inCombat = false
local combatStartTime = 0
local combatEndTime = 0

-- Player data storage: playerData[guid] = { name, class, damage, healing, damageTaken }
local playerData = {}
local playerGUID = nil
local playerName = nil

-- Segments (fight history)
local segments = {}
local currentSegment = nil

-- Death recap
local deathLog = {}
local MAX_DEATH_LOG = 10

-- Class colors
local CLASS_COLORS = RAID_CLASS_COLORS or {
    ["WARRIOR"]     = { r = 0.78, g = 0.61, b = 0.43 },
    ["PALADIN"]     = { r = 0.96, g = 0.55, b = 0.73 },
    ["HUNTER"]      = { r = 0.67, g = 0.83, b = 0.45 },
    ["ROGUE"]       = { r = 1.00, g = 0.96, b = 0.41 },
    ["PRIEST"]      = { r = 1.00, g = 1.00, b = 1.00 },
    ["DEATHKNIGHT"] = { r = 0.77, g = 0.12, b = 0.23 },
    ["SHAMAN"]      = { r = 0.00, g = 0.44, b = 0.87 },
    ["MAGE"]        = { r = 0.41, g = 0.80, b = 0.94 },
    ["WARLOCK"]     = { r = 0.58, g = 0.51, b = 0.79 },
    ["DRUID"]       = { r = 1.00, g = 0.49, b = 0.04 },
}

-- ============================================================
-- Utility Functions
-- ============================================================
local function FormatNumber(num)
    if not num then return "0" end
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(math.floor(num))
    end
end

local function FormatTime(seconds)
    if not seconds or seconds <= 0 then return "0:00" end
    if seconds >= 3600 then
        return string.format("%d:%02d:%02d", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60), math.floor(seconds % 60))
    elseif seconds >= 60 then
        return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
    else
        return string.format("%ds", math.floor(seconds))
    end
end

local function GetCombatTime()
    if inCombat then
        return GetTime() - combatStartTime
    elseif combatEndTime > 0 and combatStartTime > 0 then
        return combatEndTime - combatStartTime
    end
    return 0
end

local function GetClassColor(classToken)
    local color = CLASS_COLORS[classToken]
    if color then
        return color.r, color.g, color.b
    end
    return 0.5, 0.5, 0.5
end

-- ============================================================
-- Player Data Management
-- ============================================================
local function GetPlayerData(guid, name, flags)
    if not guid then return nil end
    
    if not playerData[guid] then
        -- Determine class from flags or unit lookup
        local classToken = nil
        
        -- Try to find unit and get class
        if name then
            if UnitName("player") == name then
                _, classToken = UnitClass("player")
            else
                for i = 1, 4 do
                    if UnitName("party" .. i) == name then
                        _, classToken = UnitClass("party" .. i)
                        break
                    end
                end
                if not classToken then
                    for i = 1, 40 do
                        if UnitName("raid" .. i) == name then
                            _, classToken = UnitClass("raid" .. i)
                            break
                        end
                    end
                end
            end
        end
        
        playerData[guid] = {
            name = name or "Unknown",
            class = classToken,
            damage = 0,
            healing = 0,
            damageTaken = 0,
            overhealing = 0,
            absorbs = 0,
            deaths = 0,
            interrupts = 0,
            dispels = 0,
            -- Spell breakdown: spells[spellId] = { name, damage, healing, hits, crits }
            spells = {},
        }
    end
    
    return playerData[guid]
end

local function ResetPlayerData()
    wipe(playerData)
    wipe(deathLog)
end

local function SaveSegment()
    local settings = addon.settings.combatLog
    
    if GetCombatTime() < 5 then return end  -- Don't save short fights
    
    local segment = {
        startTime = combatStartTime,
        endTime = combatEndTime or GetTime(),
        duration = GetCombatTime(),
        data = {},
    }
    
    -- Copy player data
    for guid, data in pairs(playerData) do
        segment.data[guid] = {
            name = data.name,
            class = data.class,
            damage = data.damage,
            healing = data.healing,
            damageTaken = data.damageTaken,
        }
    end
    
    table.insert(segments, 1, segment)
    
    -- Trim old segments
    while #segments > settings.keepSegments do
        table.remove(segments)
    end
end

-- ============================================================
-- Sorted Data for Display
-- ============================================================
local function GetSortedData(mode)
    local sorted = {}
    local valueKey = mode == "damage" and "damage" or (mode == "healing" and "healing" or "damageTaken")
    
    for guid, data in pairs(playerData) do
        if data[valueKey] > 0 then
            table.insert(sorted, {
                guid = guid,
                name = data.name,
                class = data.class,
                value = data[valueKey],
            })
        end
    end
    
    table.sort(sorted, function(a, b) return a.value > b.value end)
    
    return sorted
end

-- ============================================================
-- Combat Frame with Bars
-- ============================================================
local barFrames = {}

local function CreateBar(parent, index)
    local settings = addon.settings.combatLog
    local barHeight = settings.barHeight or 18
    
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(parent:GetWidth() - 10, barHeight)
    bar:SetPoint("TOPLEFT", 5, -30 - ((index - 1) * (barHeight + 2)))
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(100)
    
    -- Background
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    bar.bg = bg
    
    -- Rank number
    local rank = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rank:SetPoint("LEFT", 2, 0)
    rank:SetText(index .. ".")
    rank:SetWidth(16)
    bar.rank = rank
    
    -- Name text
    local name = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("LEFT", 20, 0)
    name:SetJustifyH("LEFT")
    name:SetWidth(bar:GetWidth() - 80)
    bar.nameText = name
    
    -- Value text
    local value = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    value:SetPoint("RIGHT", -2, 0)
    value:SetJustifyH("RIGHT")
    bar.valueText = value
    
    bar:Hide()
    return bar
end

local function CreateCombatFrame()
    if combatFrame then return combatFrame end
    
    local settings = addon.settings.combatLog
    local width = settings.frameWidth or 200
    local height = settings.frameHeight or 250
    
    combatFrame = CreateFrame("Frame", "DCQoS_CombatLogFrame", UIParent)
    combatFrame:SetSize(width, height)
    combatFrame:SetPoint("CENTER", UIParent, "CENTER", settings.frameX or 300, settings.frameY or 150)
    combatFrame:SetScale(settings.frameScale or 1.0)
    combatFrame:SetAlpha(settings.frameAlpha or 0.9)
    combatFrame:SetMovable(true)
    combatFrame:EnableMouse(true)
    combatFrame:SetClampedToScreen(true)
    combatFrame:RegisterForDrag("LeftButton")
    combatFrame:SetResizable(true)
    combatFrame:SetMinResize(150, 100)
    combatFrame:SetMaxResize(400, 500)
    
    -- Background
    combatFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    combatFrame:SetBackdropColor(0, 0, 0, 0.8)
    combatFrame:SetBackdropBorderColor(0.3, 0.3, 0.3)
    
    -- Title bar
    local titleBar = CreateFrame("Frame", nil, combatFrame)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(24)
    titleBar:EnableMouse(true)
    
    -- Title
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("LEFT", 8, 0)
    title:SetText("|cffFFCC00DC|r Combat")
    combatFrame.title = title
    
    -- Mode buttons
    local dmgBtn = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
    dmgBtn:SetSize(25, 16)
    dmgBtn:SetPoint("LEFT", title, "RIGHT", 10, 0)
    dmgBtn:SetText("D")
    dmgBtn:SetScript("OnClick", function()
        addon:SetSetting("combatLog.meterMode", "damage")
        CombatLog.UpdateFrame()
    end)
    dmgBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Damage Done")
        GameTooltip:Show()
    end)
    dmgBtn:SetScript("OnLeave", GameTooltip_Hide)
    
    local healBtn = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
    healBtn:SetSize(25, 16)
    healBtn:SetPoint("LEFT", dmgBtn, "RIGHT", 2, 0)
    healBtn:SetText("H")
    healBtn:SetScript("OnClick", function()
        addon:SetSetting("combatLog.meterMode", "healing")
        CombatLog.UpdateFrame()
    end)
    healBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Healing Done")
        GameTooltip:Show()
    end)
    healBtn:SetScript("OnLeave", GameTooltip_Hide)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function()
        combatFrame:Hide()
    end)
    
    -- Timer text
    local timerText = combatFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timerText:SetPoint("TOPRIGHT", -25, -5)
    timerText:SetText("0:00")
    combatFrame.timerText = timerText
    
    -- Create bar frames
    for i = 1, 15 do
        barFrames[i] = CreateBar(combatFrame, i)
    end
    
    -- Bottom bar with stats
    local bottomBar = CreateFrame("Frame", nil, combatFrame)
    bottomBar:SetPoint("BOTTOMLEFT", 0, 0)
    bottomBar:SetPoint("BOTTOMRIGHT", 0, 0)
    bottomBar:SetHeight(20)
    
    local resetBtn = CreateFrame("Button", nil, bottomBar, "UIPanelButtonTemplate")
    resetBtn:SetSize(50, 18)
    resetBtn:SetPoint("BOTTOMLEFT", 5, 2)
    resetBtn:SetText("Reset")
    resetBtn:SetScript("OnClick", function()
        ResetPlayerData()
        CombatLog.UpdateFrame()
    end)
    
    -- Resize grip
    local resizeGrip = CreateFrame("Button", nil, combatFrame)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetScript("OnMouseDown", function()
        combatFrame:StartSizing("BOTTOMRIGHT")
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        combatFrame:StopMovingOrSizing()
        addon:SetSetting("combatLog.frameWidth", combatFrame:GetWidth())
        addon:SetSetting("combatLog.frameHeight", combatFrame:GetHeight())
        CombatLog.UpdateFrame()
    end)
    
    -- Dragging
    titleBar:SetScript("OnMouseDown", function()
        combatFrame:StartMoving()
    end)
    titleBar:SetScript("OnMouseUp", function()
        combatFrame:StopMovingOrSizing()
        local _, _, _, x, y = combatFrame:GetPoint()
        addon:SetSetting("combatLog.frameX", x)
        addon:SetSetting("combatLog.frameY", y)
    end)
    
    -- Update timer
    combatFrame:SetScript("OnUpdate", function(self, elapsed)
        self.updateElapsed = (self.updateElapsed or 0) + elapsed
        if self.updateElapsed >= 0.5 then
            self.updateElapsed = 0
            CombatLog.UpdateFrame()
        end
    end)
    
    combatFrame:Hide()
    return combatFrame
end

function CombatLog.UpdateFrame()
    if not combatFrame then return end
    
    local settings = addon.settings.combatLog
    local combatTime = GetCombatTime()
    
    -- Update timer
    combatFrame.timerText:SetText(FormatTime(combatTime))
    
    -- Get sorted data
    local mode = settings.meterMode or "damage"
    local sorted = GetSortedData(mode)
    
    -- Find max value for bar scaling
    local maxValue = 0
    for _, data in ipairs(sorted) do
        if data.value > maxValue then maxValue = data.value end
    end
    
    -- Update bars
    local maxBars = math.min(settings.maxBars or 10, #barFrames)
    local barHeight = settings.barHeight or 18
    local visibleHeight = combatFrame:GetHeight() - 50  -- Title + bottom bar
    local barsToShow = math.min(math.floor(visibleHeight / (barHeight + 2)), maxBars)
    
    for i = 1, #barFrames do
        local bar = barFrames[i]
        
        if i <= barsToShow and sorted[i] then
            local data = sorted[i]
            local percent = maxValue > 0 and (data.value / maxValue * 100) or 0
            local dps = combatTime > 0 and (data.value / combatTime) or 0
            
            -- Size and position
            bar:SetSize(combatFrame:GetWidth() - 10, barHeight)
            bar:SetPoint("TOPLEFT", 5, -28 - ((i - 1) * (barHeight + 2)))
            
            -- Color
            local r, g, b = GetClassColor(data.class)
            bar:SetStatusBarColor(r, g, b, 0.8)
            
            -- Values
            bar:SetValue(percent)
            bar.rank:SetText(i .. ".")
            bar.nameText:SetText(data.name)
            
            if mode == "damage" or mode == "healing" then
                bar.valueText:SetText(string.format("%s (%s)", FormatNumber(data.value), FormatNumber(dps)))
            else
                bar.valueText:SetText(FormatNumber(data.value))
            end
            
            bar:Show()
        else
            bar:Hide()
        end
    end
end

function CombatLog.ShowFrame()
    if not combatFrame then
        CreateCombatFrame()
    end
    combatFrame:Show()
end

function CombatLog.HideFrame()
    if combatFrame then
        combatFrame:Hide()
    end
end

-- ============================================================
-- Death Recap
-- ============================================================
local function RecordDamageForDeathRecap(timestamp, source, spellName, amount, school)
    if #deathLog >= MAX_DEATH_LOG then
        table.remove(deathLog, 1)
    end
    
    table.insert(deathLog, {
        time = timestamp,
        source = source or "Unknown",
        spell = spellName or "Melee",
        amount = amount or 0,
        school = school or 1,
    })
end

local function ShowDeathRecap()
    local settings = addon.settings.combatLog
    if not settings.deathRecap then return end
    
    if #deathLog == 0 then
        addon:Print("No damage recorded before death.", true)
        return
    end
    
    addon:Print("=== Death Recap ===", true)
    
    local count = math.min(settings.deathRecapCount, #deathLog)
    for i = #deathLog - count + 1, #deathLog do
        local entry = deathLog[i]
        if entry then
            print(string.format("  |cffff6600%s|r from %s (%s)", 
                FormatNumber(entry.amount), 
                entry.source, 
                entry.spell))
        end
    end
end

-- ============================================================
-- Spell Breakdown Display
-- ============================================================
local function ShowSpellBreakdown(playerNameOrGuid)
    local settings = addon.settings.combatLog
    local targetData = nil
    local targetName = nil
    
    -- Find player data
    if not playerNameOrGuid or playerNameOrGuid == "" then
        -- Default to current player
        targetData = playerData[playerGUID]
        targetName = playerName
    else
        for guid, data in pairs(playerData) do
            if data.name == playerNameOrGuid or guid == playerNameOrGuid then
                targetData = data
                targetName = data.name
                break
            end
        end
    end
    
    if not targetData or not targetData.spells then
        addon:Print("No spell data available.", true)
        return
    end
    
    -- Sort spells by damage/healing
    local mode = settings.meterMode or "damage"
    local sorted = {}
    
    for spellId, spell in pairs(targetData.spells) do
        local value = mode == "healing" and spell.healing or spell.damage
        if value > 0 then
            table.insert(sorted, {
                id = spellId,
                name = spell.name,
                value = value,
                hits = spell.hits,
                crits = spell.crits,
            })
        end
    end
    
    table.sort(sorted, function(a, b) return a.value > b.value end)
    
    local combatTime = GetCombatTime()
    local totalValue = mode == "healing" and targetData.healing or targetData.damage
    
    addon:Print(string.format("=== Spell Breakdown: %s ===", targetName), true)
    
    local maxSpells = settings.maxSpells or 5
    for i = 1, math.min(maxSpells, #sorted) do
        local spell = sorted[i]
        local pct = totalValue > 0 and (spell.value / totalValue * 100) or 0
        local critPct = spell.hits > 0 and (spell.crits / spell.hits * 100) or 0
        local perSec = combatTime > 0 and (spell.value / combatTime) or 0
        
        print(string.format("  %d. |cffffd700%s|r - %s (%.1f%%) | %s/s | %d hits (%.0f%% crit)",
            i,
            spell.name,
            FormatNumber(spell.value),
            pct,
            FormatNumber(perSec),
            spell.hits,
            critPct
        ))
    end
end

-- Show dispels summary
local function ShowDispels()
    addon:Print("=== Dispel Summary ===", true)
    
    local sorted = {}
    for guid, data in pairs(playerData) do
        if data.dispels and data.dispels > 0 then
            table.insert(sorted, { name = data.name, dispels = data.dispels })
        end
    end
    
    table.sort(sorted, function(a, b) return a.dispels > b.dispels end)
    
    if #sorted == 0 then
        print("  No dispels recorded.")
        return
    end
    
    for i, entry in ipairs(sorted) do
        print(string.format("  %d. %s - %d dispels", i, entry.name, entry.dispels))
    end
end

-- Show absorbs summary
local function ShowAbsorbs()
    addon:Print("=== Absorb Summary ===", true)
    
    local combatTime = GetCombatTime()
    local sorted = {}
    
    for guid, data in pairs(playerData) do
        if data.absorbs and data.absorbs > 0 then
            table.insert(sorted, { 
                name = data.name, 
                absorbs = data.absorbs,
                aps = combatTime > 0 and (data.absorbs / combatTime) or 0
            })
        end
    end
    
    table.sort(sorted, function(a, b) return a.absorbs > b.absorbs end)
    
    if #sorted == 0 then
        print("  No absorbs recorded.")
        return
    end
    
    for i, entry in ipairs(sorted) do
        print(string.format("  %d. %s - %s (%s/s)", 
            i, entry.name, FormatNumber(entry.absorbs), FormatNumber(entry.aps)))
    end
end

-- ============================================================
-- Combat Log Event Handler (3.3.5a compatible)
-- ============================================================
local eventFrame = CreateFrame("Frame")

local function OnCombatLogEvent(...)
    local settings = addon.settings.combatLog
    if not settings.enabled then return end
    
    local timestamp, event, sourceGUID, sourceName, sourceFlags, 
          destGUID, destName, destFlags = select(1, ...)
    
    local arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17 = select(9, ...)
    
    -- Check if source is in our group
    local isGroupSource = sourceGUID == playerGUID
    if settings.trackGroup and not isGroupSource then
        if bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0 or
           bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) > 0 or
           bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) > 0 then
            isGroupSource = true
        end
    end
    
    -- Helper to track spell breakdown
    local function TrackSpell(data, spellId, spellName, amount, isCrit, isHealing)
        if not data.spells then data.spells = {} end
        if not spellId then spellId = 0 end
        
        if not data.spells[spellId] then
            data.spells[spellId] = {
                name = spellName or "Unknown",
                damage = 0,
                healing = 0,
                hits = 0,
                crits = 0,
            }
        end
        
        local spell = data.spells[spellId]
        spell.hits = spell.hits + 1
        if isCrit then spell.crits = spell.crits + 1 end
        
        if isHealing then
            spell.healing = spell.healing + (amount or 0)
        else
            spell.damage = spell.damage + (amount or 0)
        end
    end
    
    -- Track damage/healing dealt
    if isGroupSource then
        local data = GetPlayerData(sourceGUID, sourceName, sourceFlags)
        if data then
            if event == "SWING_DAMAGE" then
                local amount = arg9 or 0
                local critical = arg14
                data.damage = data.damage + amount
                TrackSpell(data, 0, "Melee", amount, critical, false)
                
            elseif event == "SPELL_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or event == "RANGE_DAMAGE" then
                local spellId = arg9
                local spellName = arg10
                local amount = arg12 or 0
                local critical = arg17
                data.damage = data.damage + amount
                TrackSpell(data, spellId, spellName, amount, critical, false)
                
            elseif event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then
                local spellId = arg9
                local spellName = arg10
                local amount = arg12 or 0
                local overheal = arg13 or 0
                local critical = arg14
                local effectiveHeal = amount - overheal
                data.healing = data.healing + effectiveHeal
                data.overhealing = (data.overhealing or 0) + overheal
                TrackSpell(data, spellId, spellName, effectiveHeal, critical, true)
                
            elseif event == "SPELL_INTERRUPT" then
                data.interrupts = (data.interrupts or 0) + 1
                
                if sourceGUID == playerGUID and settings.announceInterrupts then
                    local interruptedSpell = arg13 or "Unknown"
                    local msg = string.format("Interrupted %s's %s!", destName or "Unknown", interruptedSpell)
                    if settings.interruptChannel == "SAY" then
                        SendChatMessage(msg, "SAY")
                    elseif settings.interruptChannel == "PARTY" then
                        SendChatMessage(msg, "PARTY")
                    elseif settings.interruptChannel == "RAID" then
                        SendChatMessage(msg, "RAID")
                    end
                end
                
            elseif event == "SPELL_DISPEL" or event == "SPELL_STOLEN" then
                if settings.trackDispels then
                    data.dispels = (data.dispels or 0) + 1
                end
                
            elseif event == "SPELL_AURA_APPLIED" then
                -- Track absorb shields applied (approximate)
                -- Absorbs in 3.3.5a don't have specific events, this is limited
                
            end
        end
    end
    
    -- Track absorbs on group members (destination)
    if settings.trackAbsorbs then
        local isGroupDest = destGUID == playerGUID
        if settings.trackGroup and not isGroupDest then
            if bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) > 0 or
               bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) > 0 then
                isGroupDest = true
            end
        end
        
        if isGroupDest and event == "SPELL_ABSORBED" then
            -- Track absorb shields that absorbed damage
            local absorbSourceGUID = arg12
            local absorbSourceName = arg13
            local absorbAmount = arg17 or arg14 or 0
            
            if absorbSourceGUID then
                local data = GetPlayerData(absorbSourceGUID, absorbSourceName)
                if data then
                    data.absorbs = (data.absorbs or 0) + absorbAmount
                end
            end
        end
    end
    
    -- Track damage taken by player
    if destGUID == playerGUID then
        local data = GetPlayerData(playerGUID, playerName)
        if data then
            local amount = 0
            local spellName = nil
            
            if event == "SWING_DAMAGE" then
                amount = arg9 or 0
                spellName = "Melee"
            elseif event == "SPELL_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or event == "RANGE_DAMAGE" then
                spellName = arg10
                amount = arg12 or 0
            elseif event == "ENVIRONMENTAL_DAMAGE" then
                spellName = arg9 or "Environment"
                amount = arg10 or 0
            end
            
            if amount > 0 then
                data.damageTaken = data.damageTaken + amount
                RecordDamageForDeathRecap(timestamp, sourceName, spellName, amount)
            end
            
            if event == "UNIT_DIED" then
                data.deaths = (data.deaths or 0) + 1
                ShowDeathRecap()
            end
        end
    end
end

local function OnCombatEvent(self, event, ...)
    local settings = addon.settings.combatLog
    if not settings.enabled then return end
    
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        combatStartTime = GetTime()
        ResetPlayerData()
        
        if settings.showMeter then
            CombatLog.ShowFrame()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        combatEndTime = GetTime()
        SaveSegment()
        CombatLog.UpdateFrame()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent(...)
    elseif event == "PLAYER_DEAD" then
        local data = GetPlayerData(playerGUID, playerName)
        if data then
            data.deaths = (data.deaths or 0) + 1
        end
        ShowDeathRecap()
    end
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function CombatLog.OnInitialize()
    addon:Debug("CombatLog module initializing")
    playerGUID = UnitGUID("player")
    playerName = UnitName("player")
end

function CombatLog.OnEnable()
    addon:Debug("CombatLog module enabling")
    
    local settings = addon.settings.combatLog
    if not settings.enabled then return end
    
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_DEAD")
    eventFrame:SetScript("OnEvent", OnCombatEvent)
    
    -- Slash commands
    SLASH_DCCOMBAT1 = "/dccombat"
    SLASH_DCCOMBAT2 = "/dcc"
    SlashCmdList["DCCOMBAT"] = function(msg)
        msg = msg and strlower(strtrim(msg)) or ""
        
        if msg == "" or msg == "toggle" then
            if combatFrame and combatFrame:IsShown() then
                CombatLog.HideFrame()
            else
                CombatLog.ShowFrame()
            end
        elseif msg == "show" then
            CombatLog.ShowFrame()
        elseif msg == "hide" then
            CombatLog.HideFrame()
        elseif msg == "reset" then
            ResetPlayerData()
            addon:Print("Combat stats reset.", true)
        elseif msg == "death" then
            ShowDeathRecap()
        elseif msg == "damage" or msg == "d" then
            addon:SetSetting("combatLog.meterMode", "damage")
            CombatLog.UpdateFrame()
            addon:Print("Mode: Damage Done", true)
        elseif msg == "healing" or msg == "h" then
            addon:SetSetting("combatLog.meterMode", "healing")
            CombatLog.UpdateFrame()
            addon:Print("Mode: Healing Done", true)
        elseif msg == "spells" or msg == "s" then
            ShowSpellBreakdown()
        elseif msg:match("^spells ") then
            local target = msg:match("^spells (.+)")
            ShowSpellBreakdown(target)
        elseif msg == "dispels" then
            ShowDispels()
        elseif msg == "absorbs" then
            ShowAbsorbs()
        elseif msg == "help" then
            addon:Print("Combat Log Commands:", true)
            print("  |cffffd700/dcc|r - Toggle display")
            print("  |cffffd700/dcc d|r - Damage mode")
            print("  |cffffd700/dcc h|r - Healing mode")
            print("  |cffffd700/dcc s|r - Spell breakdown (your spells)")
            print("  |cffffd700/dcc spells <name>|r - Spell breakdown for player")
            print("  |cffffd700/dcc dispels|r - Show dispel summary")
            print("  |cffffd700/dcc absorbs|r - Show absorb summary")
            print("  |cffffd700/dcc reset|r - Reset stats")
            print("  |cffffd700/dcc death|r - Show death recap")
        end
    end
    
    CreateCombatFrame()
end

function CombatLog.OnDisable()
    addon:Debug("CombatLog module disabling")
    eventFrame:UnregisterAllEvents()
    if combatFrame then
        combatFrame:Hide()
    end
end

-- ============================================================
-- Settings Panel
-- ============================================================
function CombatLog.CreateSettings(parent)
    local settings = addon.settings.combatLog
    
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Combat Log Settings")
    
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(450)
    desc:SetJustifyH("LEFT")
    desc:SetText("DPS/HPS meter with group tracking. Use |cffffd700/dcc|r to toggle, |cffffd700/dcc d|r for damage, |cffffd700/dcc h|r for healing.")
    
    local yOffset = -70
    
    -- Display Section
    local displayHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    displayHeader:SetPoint("TOPLEFT", 16, yOffset)
    displayHeader:SetText("Display")
    yOffset = yOffset - 25
    
    local meterCb = addon:CreateCheckbox(parent)
    meterCb:SetPoint("TOPLEFT", 16, yOffset)
    meterCb.Text:SetText("Show damage meter during combat")
    meterCb:SetChecked(settings.showMeter)
    meterCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.showMeter", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    local groupCb = addon:CreateCheckbox(parent)
    groupCb:SetPoint("TOPLEFT", 16, yOffset)
    groupCb.Text:SetText("Track party/raid members")
    groupCb:SetChecked(settings.trackGroup)
    groupCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackGroup", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- Death Recap Section
    local deathHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    deathHeader:SetPoint("TOPLEFT", 16, yOffset)
    deathHeader:SetText("Death Recap")
    yOffset = yOffset - 25
    
    local deathCb = addon:CreateCheckbox(parent)
    deathCb:SetPoint("TOPLEFT", 16, yOffset)
    deathCb.Text:SetText("Show death recap when you die")
    deathCb:SetChecked(settings.deathRecap)
    deathCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.deathRecap", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- Interrupts Section
    local intHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    intHeader:SetPoint("TOPLEFT", 16, yOffset)
    intHeader:SetText("Interrupts")
    yOffset = yOffset - 25
    
    local intCb = addon:CreateCheckbox(parent)
    intCb:SetPoint("TOPLEFT", 16, yOffset)
    intCb.Text:SetText("Announce interrupts to chat")
    intCb:SetChecked(settings.announceInterrupts)
    intCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.announceInterrupts", self:GetChecked())
    end)
    
    return yOffset - 50
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("CombatLog", CombatLog)
