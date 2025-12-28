-- ============================================================
-- DC-QoS: GTFO Module
-- ============================================================
-- "Get The F* Out" - Alerts when standing in damaging areas
-- Provides audio/visual warnings for avoidable damage
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local GTFO = {
    displayName = "GTFO Alerts",
    settingKey = "gtfo",
    icon = "Interface\\Icons\\Spell_Fire_Fire",
}

-- ============================================================
-- Default Settings
-- ============================================================
local defaults = {
    gtfo = {
        enabled = true,
        volume = 0.8,
        highDamageAlert = true,
        lowDamageAlert = true,
        failAlert = true,
        friendlyFireAlert = false,
        visualFlash = true,
        flashColor = { r = 1.0, g = 0.0, b = 0.0, a = 0.3 },
        cooldown = 1.0,  -- Minimum seconds between alerts
        ignoreTrivial = true,
        trivialPercent = 1,  -- Ignore damage < 1% of max health
    },
}

-- Merge defaults
for k, v in pairs(defaults) do
    addon.defaults[k] = v
end

-- ============================================================
-- Sound Files
-- ============================================================
-- Using built-in WoW sounds for reliability
local SOUNDS = {
    HIGH = "Sound\\Interface\\RaidWarning.wav",
    LOW = "Sound\\Spells\\SimonGame_Visual_GameTick.wav",
    FAIL = "Sound\\Interface\\Error.wav",
    FRIENDLY = "Sound\\Interface\\AuctionWindowOpen.wav",
}

-- Alternative sound IDs (more reliable in 3.3.5a)
local SOUND_IDS = {
    HIGH = 8046,     -- RaidWarning
    LOW = 6595,      -- Tick sound
    FAIL = 847,      -- Error
    FRIENDLY = 5274, -- Auction open
}

-- ============================================================
-- Alert Types
-- ============================================================
local ALERT_TYPE = {
    HIGH = 1,      -- High damage (> 30% health)
    LOW = 2,       -- Low damage (< 30% health)
    FAIL = 3,      -- Mechanics fail (didn't move)
    FRIENDLY = 4,  -- Friendly fire (player AoE, etc.)
}

-- ============================================================
-- Known Bad Spells Database
-- ============================================================
-- Spell IDs that are known ground effects to avoid
-- Can be extended by server via protocol
local KnownBadSpells = {
    -- Generic hazards
    [57491] = ALERT_TYPE.HIGH,  -- Flame Patch
    [57795] = ALERT_TYPE.HIGH,  -- Shadow Crash
    [59973] = ALERT_TYPE.HIGH,  -- Blizzard (Syndragosa)
    [61087] = ALERT_TYPE.HIGH,  -- Defile (Lich King)
    [68981] = ALERT_TYPE.HIGH,  -- Remorseless Winter
    [69075] = ALERT_TYPE.HIGH,  -- Bone Storm
    [69057] = ALERT_TYPE.HIGH,  -- Bone Spike Graveyard
    [69242] = ALERT_TYPE.HIGH,  -- Soul Shriek
    [70541] = ALERT_TYPE.HIGH,  -- Infest
    [72754] = ALERT_TYPE.HIGH,  -- Defile (heroic)
    
    -- Ulduar
    [62548] = ALERT_TYPE.HIGH,  -- Scorch
    [63476] = ALERT_TYPE.HIGH,  -- Shockwave
    [64234] = ALERT_TYPE.HIGH,  -- Tantrum
    
    -- Naxxramas
    [28542] = ALERT_TYPE.HIGH,  -- Frost Aura (Sapphiron)
    [28796] = ALERT_TYPE.HIGH,  -- Poison Cloud
    [29213] = ALERT_TYPE.HIGH,  -- Frost Blast
    
    -- ToC
    [66331] = ALERT_TYPE.HIGH,  -- Legion Flame
    [67049] = ALERT_TYPE.HIGH,  -- Infernal Volcano
    [67050] = ALERT_TYPE.HIGH,  -- Fel Inferno
    
    -- Lower damage/avoidable
    [69633] = ALERT_TYPE.LOW,   -- Ice Pulse
    [65775] = ALERT_TYPE.LOW,   -- Acidic Wound
    [55826] = ALERT_TYPE.LOW,   -- Venom Spit
    [55836] = ALERT_TYPE.LOW,   -- Poison Splash
    
    -- Player-caused (friendly fire)
    [2120] = ALERT_TYPE.FRIENDLY,  -- Flamestrike (standing in own)
    [10] = ALERT_TYPE.FRIENDLY,    -- Blizzard (own)
}

-- ============================================================
-- State Variables
-- ============================================================
local lastAlertTime = 0
local alertFrame = nil
local flashTexture = nil

-- ============================================================
-- Visual Flash Effect
-- ============================================================
local function CreateFlashFrame()
    if alertFrame then return end
    
    alertFrame = CreateFrame("Frame", "DCQoSGTFOFlash", UIParent)
    alertFrame:SetAllPoints(UIParent)
    alertFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    alertFrame:SetFrameLevel(100)
    alertFrame:Hide()
    
    flashTexture = alertFrame:CreateTexture(nil, "BACKGROUND")
    flashTexture:SetAllPoints()
    flashTexture:SetTexture(1, 0, 0, 0.3)
    flashTexture:SetBlendMode("ADD")
    
    -- Animation
    local elapsed = 0
    local duration = 0.5
    alertFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= duration then
            self:Hide()
            elapsed = 0
        else
            local alpha = (1 - (elapsed / duration)) * 0.3
            flashTexture:SetAlpha(alpha)
        end
    end)
    
    alertFrame:SetScript("OnShow", function(self)
        elapsed = 0
        local settings = addon.settings.gtfo
        local c = settings.flashColor
        flashTexture:SetTexture(c.r, c.g, c.b, c.a)
        flashTexture:SetAlpha(c.a)
    end)
end

local function TriggerFlash(alertType)
    if not addon.settings.gtfo.visualFlash then return end
    if not alertFrame then CreateFlashFrame() end
    
    local settings = addon.settings.gtfo
    local c = settings.flashColor
    
    -- Different colors for different alert types
    if alertType == ALERT_TYPE.HIGH then
        flashTexture:SetTexture(1, 0, 0, c.a)  -- Red
    elseif alertType == ALERT_TYPE.LOW then
        flashTexture:SetTexture(1, 0.5, 0, c.a)  -- Orange
    elseif alertType == ALERT_TYPE.FAIL then
        flashTexture:SetTexture(0.5, 0, 1, c.a)  -- Purple
    elseif alertType == ALERT_TYPE.FRIENDLY then
        flashTexture:SetTexture(1, 1, 0, c.a)  -- Yellow
    end
    
    alertFrame:Show()
end

-- ============================================================
-- Sound Playback
-- ============================================================
local function PlayAlertSound(alertType)
    local settings = addon.settings.gtfo
    
    -- Check if this alert type is enabled
    if alertType == ALERT_TYPE.HIGH and not settings.highDamageAlert then return end
    if alertType == ALERT_TYPE.LOW and not settings.lowDamageAlert then return end
    if alertType == ALERT_TYPE.FAIL and not settings.failAlert then return end
    if alertType == ALERT_TYPE.FRIENDLY and not settings.friendlyFireAlert then return end
    
    -- Get sound file
    local soundKey = "HIGH"
    if alertType == ALERT_TYPE.LOW then soundKey = "LOW"
    elseif alertType == ALERT_TYPE.FAIL then soundKey = "FAIL"
    elseif alertType == ALERT_TYPE.FRIENDLY then soundKey = "FRIENDLY"
    end
    
    local soundFile = SOUNDS[soundKey]
    local soundId = SOUND_IDS[soundKey]
    
    -- Try file first, then sound ID
    local success = PlaySoundFile(soundFile, "Master")
    if not success and soundId then
        PlaySound(soundId, "Master")
    end
end

-- ============================================================
-- Alert Trigger
-- ============================================================
local function TriggerAlert(alertType, spellId, damage)
    local settings = addon.settings.gtfo
    if not settings.enabled then return end
    
    -- Cooldown check
    local now = GetTime()
    if (now - lastAlertTime) < settings.cooldown then
        return
    end
    lastAlertTime = now
    
    -- Play sound
    PlayAlertSound(alertType)
    
    -- Visual flash
    TriggerFlash(alertType)
    
    -- Debug output
    if addon.settings.communication and addon.settings.communication.debugMode then
        local spellName = GetSpellInfo(spellId) or "Unknown"
        addon:Debug("GTFO Alert: " .. spellName .. " (" .. spellId .. ") - Type: " .. alertType .. " - Damage: " .. (damage or 0))
    end
end

-- ============================================================
-- Damage Detection (3.3.5a Compatible)
-- ============================================================
-- In WotLK 3.3.5a, combat log events pass data via varargs (...) not CombatLogGetCurrentEventInfo()
-- Event signature: timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...
-- SPELL_DAMAGE extra args: spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical
-- SPELL_PERIODIC_DAMAGE: same as SPELL_DAMAGE
-- SWING_DAMAGE extra args: amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing

local function OnCombatLogEvent(...)
    local settings = addon.settings.gtfo
    if not settings.enabled then return end
    
    -- 3.3.5a varargs parsing
    local timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags = ...
    
    -- Only process damage to player
    local playerGUID = UnitGUID("player")
    if dstGUID ~= playerGUID then return end
    
    -- Get spell info based on event type
    local spellId, spellName, spellSchool, amount
    
    if eventtype == "SPELL_DAMAGE" or eventtype == "SPELL_PERIODIC_DAMAGE" then
        -- SPELL_DAMAGE: arg9=spellId, arg10=spellName, arg11=spellSchool, arg12=amount
        spellId, spellName, spellSchool, amount = select(9, ...)
    elseif eventtype == "SWING_DAMAGE" then
        -- Ignore melee damage
        return
    elseif eventtype == "RANGE_DAMAGE" then
        -- RANGE_DAMAGE: arg9=spellId, arg10=spellName, arg11=spellSchool, arg12=amount
        -- Ignore ranged damage
        return
    elseif eventtype == "ENVIRONMENTAL_DAMAGE" then
        -- ENVIRONMENTAL_DAMAGE: arg9=environmentalType, arg10=amount
        local envType = select(9, ...)
        amount = select(10, ...)
        spellId = 0  -- No spell ID for environmental
        spellName = envType or "Environmental"
        -- Always alert for environmental damage (lava, falling, etc.)
        if amount and amount > 0 then
            TriggerAlert(ALERT_TYPE.HIGH, spellId, amount)
        end
        return
    else
        return
    end
    
    if not spellId or not amount then return end
    
    -- Ignore trivial damage
    if settings.ignoreTrivial then
        local maxHealth = UnitHealthMax("player")
        if maxHealth > 0 then
            local trivialThreshold = maxHealth * (settings.trivialPercent / 100)
            if amount < trivialThreshold then return end
        end
    end
    
    -- Check known bad spells
    local alertType = KnownBadSpells[spellId]
    
    if not alertType then
        -- Unknown spell - determine by damage percentage
        local maxHealth = UnitHealthMax("player")
        if maxHealth <= 0 then return end
        local damagePercent = (amount / maxHealth) * 100
        
        if damagePercent >= 30 then
            alertType = ALERT_TYPE.HIGH
        elseif damagePercent >= 10 then
            alertType = ALERT_TYPE.LOW
        else
            return  -- Ignore low damage from unknown sources
        end
        
        -- Check if it's from player (friendly fire)
        if srcGUID == playerGUID then
            alertType = ALERT_TYPE.FRIENDLY
        end
    end
    
    TriggerAlert(alertType, spellId, amount)
end

-- ============================================================
-- Spell Database Extension (from server)
-- ============================================================
function GTFO:AddBadSpell(spellId, alertType)
    KnownBadSpells[spellId] = alertType or ALERT_TYPE.HIGH
end

function GTFO:RemoveBadSpell(spellId)
    KnownBadSpells[spellId] = nil
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function GTFO.OnInitialize()
    addon:Debug("GTFO module initializing")
    CreateFlashFrame()
end

function GTFO.OnEnable()
    addon:Debug("GTFO module enabling")
    
    -- Create event frame for combat log (3.3.5a style with varargs)
    local eventFrame = CreateFrame("Frame", "DCQoSGTFOEvents")
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            OnCombatLogEvent(...)
        end
    end)
    
    GTFO.eventFrame = eventFrame
end

function GTFO.OnDisable()
    addon:Debug("GTFO module disabling")
    
    if GTFO.eventFrame then
        GTFO.eventFrame:UnregisterAllEvents()
    end
end

-- ============================================================
-- Settings Panel Creation
-- ============================================================
function GTFO.CreateSettings(parent)
    local settings = addon.settings.gtfo
    
    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("GTFO Alert Settings")
    
    -- Description
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Get The F* Out - Warns you when standing in damaging areas.")
    desc:SetWidth(parent:GetWidth() - 32)
    desc:SetJustifyH("LEFT")
    
    local yOffset = -70
    
    -- ============================================================
    -- Enable Section
    -- ============================================================
    local enableCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    enableCb:SetPoint("TOPLEFT", 16, yOffset)
    enableCb.Text:SetText("Enable GTFO Alerts")
    enableCb:SetChecked(settings.enabled)
    enableCb:SetScript("OnClick", function(self)
        addon:SetSetting("gtfo.enabled", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Alert Types Section
    -- ============================================================
    local alertHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    alertHeader:SetPoint("TOPLEFT", 16, yOffset)
    alertHeader:SetText("Alert Types")
    yOffset = yOffset - 25
    
    -- High Damage Alert
    local highCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    highCb:SetPoint("TOPLEFT", 16, yOffset)
    highCb.Text:SetText("High Damage Alerts (> 30% health)")
    highCb:SetChecked(settings.highDamageAlert)
    highCb:SetScript("OnClick", function(self)
        addon:SetSetting("gtfo.highDamageAlert", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Low Damage Alert
    local lowCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    lowCb:SetPoint("TOPLEFT", 16, yOffset)
    lowCb.Text:SetText("Low Damage Alerts (10-30% health)")
    lowCb:SetChecked(settings.lowDamageAlert)
    lowCb:SetScript("OnClick", function(self)
        addon:SetSetting("gtfo.lowDamageAlert", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Fail Alert
    local failCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    failCb:SetPoint("TOPLEFT", 16, yOffset)
    failCb.Text:SetText("Mechanic Fail Alerts")
    failCb:SetChecked(settings.failAlert)
    failCb:SetScript("OnClick", function(self)
        addon:SetSetting("gtfo.failAlert", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Friendly Fire Alert
    local friendlyCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    friendlyCb:SetPoint("TOPLEFT", 16, yOffset)
    friendlyCb.Text:SetText("Friendly Fire Alerts (standing in your own AoE)")
    friendlyCb:SetChecked(settings.friendlyFireAlert)
    friendlyCb:SetScript("OnClick", function(self)
        addon:SetSetting("gtfo.friendlyFireAlert", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Visual Section
    -- ============================================================
    local visualHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    visualHeader:SetPoint("TOPLEFT", 16, yOffset)
    visualHeader:SetText("Visual Effects")
    yOffset = yOffset - 25
    
    -- Visual Flash
    local flashCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    flashCb:SetPoint("TOPLEFT", 16, yOffset)
    flashCb.Text:SetText("Screen Flash on Alert")
    flashCb:SetChecked(settings.visualFlash)
    flashCb:SetScript("OnClick", function(self)
        addon:SetSetting("gtfo.visualFlash", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Volume Slider
    -- ============================================================
    local volumeHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    volumeHeader:SetPoint("TOPLEFT", 16, yOffset)
    volumeHeader:SetText("Alert Volume")
    yOffset = yOffset - 25
    
    local volumeSlider = CreateFrame("Slider", "DCQoSGTFOVolumeSlider", parent, "OptionsSliderTemplate")
    volumeSlider:SetPoint("TOPLEFT", 20, yOffset)
    volumeSlider:SetWidth(200)
    volumeSlider:SetMinMaxValues(0, 1.0)
    volumeSlider:SetValueStep(0.1)
    volumeSlider:SetObeyStepOnDrag(true)
    volumeSlider:SetValue(settings.volume)
    volumeSlider.Low:SetText("0%")
    volumeSlider.High:SetText("100%")
    volumeSlider.Text:SetText(string.format("%.0f%%", settings.volume * 100))
    volumeSlider:SetScript("OnValueChanged", function(self, value)
        self.Text:SetText(string.format("%.0f%%", value * 100))
        addon:SetSetting("gtfo.volume", value)
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Cooldown Slider
    -- ============================================================
    local cooldownHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cooldownHeader:SetPoint("TOPLEFT", 16, yOffset)
    cooldownHeader:SetText("Alert Cooldown")
    yOffset = yOffset - 25
    
    local cooldownSlider = CreateFrame("Slider", "DCQoSGTFOCooldownSlider", parent, "OptionsSliderTemplate")
    cooldownSlider:SetPoint("TOPLEFT", 20, yOffset)
    cooldownSlider:SetWidth(200)
    cooldownSlider:SetMinMaxValues(0.25, 3.0)
    cooldownSlider:SetValueStep(0.25)
    cooldownSlider:SetObeyStepOnDrag(true)
    cooldownSlider:SetValue(settings.cooldown)
    cooldownSlider.Low:SetText("0.25s")
    cooldownSlider.High:SetText("3.0s")
    cooldownSlider.Text:SetText(string.format("%.2fs", settings.cooldown))
    cooldownSlider:SetScript("OnValueChanged", function(self, value)
        self.Text:SetText(string.format("%.2fs", value))
        addon:SetSetting("gtfo.cooldown", value)
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Test Button
    -- ============================================================
    local testBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    testBtn:SetPoint("TOPLEFT", 16, yOffset)
    testBtn:SetSize(120, 22)
    testBtn:SetText("Test Alert")
    testBtn:SetScript("OnClick", function()
        TriggerAlert(ALERT_TYPE.HIGH, 0, 0)
    end)
    
    return yOffset - 50
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("GTFO", GTFO)
