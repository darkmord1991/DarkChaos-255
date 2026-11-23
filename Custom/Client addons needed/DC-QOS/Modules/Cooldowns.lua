-- ============================================================
-- DC-QoS: Cooldowns Module
-- ============================================================
-- OmniCC-style cooldown text on action buttons
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local Cooldowns = {
    displayName = "Cooldowns",
    settingKey = "cooldowns",
    icon = "Interface\\Icons\\Spell_Holy_BorrowedTime",
    defaults = {
        cooldowns = {
            chargeSweep = true, -- recharge sweep for spell charges (native client)
        },
    },
}

-- ============================================================
-- Constants & Variables
-- ============================================================
local DAY, HOUR, MINUTE = 86400, 3600, 60
local ICON_SIZE = 36 -- standard action button size

-- Formats for time display
local function FormatTime(s)
    if s >= DAY then
        return string.format("%dd", math.floor(s/DAY + 0.5)), s % DAY
    elseif s >= HOUR then
        return string.format("%dh", math.floor(s/HOUR + 0.5)), s % HOUR
    elseif s >= MINUTE then
        return string.format("%dm", math.floor(s/MINUTE + 0.5)), s % MINUTE
    elseif s >= 10 then
        return math.floor(s + 0.5), s - math.floor(s)
    end
    return string.format("%.1f", s), s - math.floor(s)
end

-- ============================================================
-- Timer Management
-- ============================================================
local activeTimers = {}

local function Timer_OnUpdate(self, elapsed)
    if self.nextUpdate > 0 then
        self.nextUpdate = self.nextUpdate - elapsed
        return
    end

    local remain = self.duration - (GetTime() - self.start)
    if remain > 0.1 then
        if (self.fontScale * self:GetEffectiveScale() / UIParent:GetScale()) < addon.settings.cooldowns.fontSize then
            self.text:SetText("")
            self.nextUpdate = 1
        else
            local timeText, nextUpdate = FormatTime(remain)
            self.text:SetText(timeText)
            self.nextUpdate = nextUpdate
            
            -- Color coding
            if remain < 5 then
                self.text:SetTextColor(1, 0.1, 0.1) -- Red
            elseif remain < 60 then
                self.text:SetTextColor(1, 0.8, 0.1) -- Yellow
            else
                self.text:SetTextColor(0.9, 0.9, 0.9) -- White
            end
        end
    else
        self:Hide()
    end
end

-- ============================================================
-- Cooldown Hook
-- ============================================================
local function CreateTimer(parent)
    local timer = CreateFrame("Frame", nil, parent)
    timer:Hide()
    timer:SetAllPoints(parent)
    timer:SetScript("OnUpdate", Timer_OnUpdate)
    
    timer.text = timer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timer.text:SetPoint("CENTER", 0, 0)
    timer.text:SetFont("Fonts\\FRIZQT__.TTF", addon.settings.cooldowns.fontSize, "OUTLINE")
    
    return timer
end

local function OnSetCooldown(self, start, duration)
    local settings = addon.settings.cooldowns
    if not settings.enabled then return end
    
    -- Ignore global cooldown or very short cooldowns
    if duration > 1.5 and duration >= settings.minDuration then
        local timer = self.timer or CreateTimer(self)
        timer.start = start
        timer.duration = duration
        timer.nextUpdate = 0
        
        -- Adjust font size relative to parent
        local parent = self:GetParent()
        if parent then
            local w, h = parent:GetWidth(), parent:GetHeight()
            if w and h then 
                timer.fontScale = math.min(w, h) / ICON_SIZE
                timer.text:SetFont("Fonts\\FRIZQT__.TTF", settings.fontSize * timer.fontScale, "OUTLINE")
            end
        end
        
        self.timer = timer
        timer:Show()
    elseif self.timer then
        self.timer:Hide()
    end
end

-- ============================================================
-- Spell Charges (native client)
-- ============================================================
-- The native client's GetActionCharges(slot) answers current, max, start and duration for a spell
-- with charges. The stock button already shows the count (GetActionCount answers it natively); this
-- adds the recharge of the next charge as an edge sweep in a second cooldown under the button's own,
-- which keeps showing the spell's cooldown and the global cooldown on top. The old client has no
-- GetActionCharges, and nothing here is hooked or registered there.
local CHARGE_SWEEP_ALPHA = 0.6 -- a lighter swipe: the spell is usable while a charge recharges
local chargeButtons = {}       -- every action button seen, for SPELL_UPDATE_CHARGES
local chargeEventFrame

local function HasChargeApi()
    return type(GetActionCharges) == "function"
end

local function IsChargeSweepEnabled()
    local settings = addon.settings.cooldowns
    return settings ~= nil and settings.enabled ~= false and settings.chargeSweep ~= false
end

local function GetChargeCooldown(button)
    if button.dcChargeCooldown then
        return button.dcChargeCooldown
    end

    local name = button:GetName()
    local main = button.cooldown or (name and _G[name .. "Cooldown"])
    -- Not CooldownFrame_SetTimer's: the timer text above hooks that, and the count is the text here
    local cooldown = CreateFrame("Cooldown", nil, button)
    cooldown:SetAllPoints(main or button)
    if type(cooldown.SetDrawEdge) == "function" then
        cooldown:SetDrawEdge(true)
    end
    cooldown:SetAlpha(CHARGE_SWEEP_ALPHA)
    if main then
        local level = main:GetFrameLevel()
        cooldown:SetFrameLevel(level)
        main:SetFrameLevel(level + 1)
    end
    cooldown:Hide()
    button.dcChargeCooldown = cooldown
    return cooldown
end

local function UpdateChargeCooldown(button)
    if type(button) ~= "table" then
        return
    end
    chargeButtons[button] = true

    local current, maximum, start, duration
    if IsChargeSweepEnabled() and button.action then
        current, maximum, start, duration = GetActionCharges(button.action)
    end

    if current and maximum and current > 0 and current < maximum
        and start and duration and start > 0 and duration > 0 then
        local cooldown = GetChargeCooldown(button)
        cooldown:SetCooldown(start, duration)
        cooldown:Show()
    elseif button.dcChargeCooldown then
        button.dcChargeCooldown:Hide()
    end
end

local function RefreshChargeCooldowns(includeHidden)
    for button in pairs(chargeButtons) do
        if includeHidden or button:IsVisible() then
            UpdateChargeCooldown(button)
        end
    end
end

local function InstallChargeSweep()
    if chargeEventFrame or not HasChargeApi() then
        return
    end

    if type(ActionButton_UpdateCooldown) == "function" then
        hooksecurefunc("ActionButton_UpdateCooldown", UpdateChargeCooldown)
    end
    -- Emptying a slot runs ActionButton_Update without ActionButton_UpdateCooldown
    if type(ActionButton_Update) == "function" then
        hooksecurefunc("ActionButton_Update", UpdateChargeCooldown)
    end

    chargeEventFrame = CreateFrame("Frame")
    chargeEventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
    chargeEventFrame:SetScript("OnEvent", function()
        RefreshChargeCooldowns(false)
    end)
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function Cooldowns.OnInitialize()
    -- Hook CooldownFrame_SetTimer
    if not _G.CooldownFrame_SetTimer_Original then
        _G.CooldownFrame_SetTimer_Original = CooldownFrame_SetTimer
        hooksecurefunc("CooldownFrame_SetTimer", OnSetCooldown)
    end
    InstallChargeSweep()
end

function Cooldowns.OnEnable()
    -- Nothing specific needed, hooks carry logic
    addon.settings.cooldowns.enabled = true
    RefreshChargeCooldowns(true)
end

function Cooldowns.OnDisable()
    addon.settings.cooldowns.enabled = false
    -- Hide existing timers
    for _, timer in pairs(activeTimers) do
        timer:Hide()
    end
    RefreshChargeCooldowns(true)
end

-- ============================================================
-- Settings Panel Creation
-- ============================================================
function Cooldowns.CreateSettings(parent)
    local settings = addon.settings.cooldowns
    
    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Cooldown Settings")
    
    local yOffset = -50
    
    -- Enable Checkbox
    local enableCb = addon:CreateCheckbox(parent)
    enableCb:SetPoint("TOPLEFT", 16, yOffset)
    enableCb.Text:SetText("Enable Cooldown Text")
    enableCb:SetChecked(settings.enabled)
    enableCb:SetScript("OnClick", function(self)
        addon:SetSetting("cooldowns.enabled", self:GetChecked())
    end)
    yOffset = yOffset - 30
    
    -- Min Duration Slider
    local minDurSlider = addon:CreateSlider(parent)
    minDurSlider:SetPoint("TOPLEFT", 16, yOffset)
    minDurSlider:SetMinMaxValues(0, 30)
    minDurSlider:SetValueStep(1)
    minDurSlider:SetValue(settings.minDuration)
    minDurSlider.Text:SetText("Minimum Duration: " .. settings.minDuration .. "s")
    minDurSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        self.Text:SetText("Minimum Duration: " .. value .. "s")
        addon:SetSetting("cooldowns.minDuration", value)
    end)
    yOffset = yOffset - 50
    
    -- Font Size Slider
    local sizeSlider = addon:CreateSlider(parent)
    sizeSlider:SetPoint("TOPLEFT", 16, yOffset)
    sizeSlider:SetMinMaxValues(10, 30)
    sizeSlider:SetValueStep(1)
    sizeSlider:SetValue(settings.fontSize)
    sizeSlider.Text:SetText("Font Size: " .. settings.fontSize)
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        self.Text:SetText("Font Size: " .. value)
        addon:SetSetting("cooldowns.fontSize", value)
    end)

    if HasChargeApi() then
        yOffset = yOffset - 50
        local chargeCb = addon:CreateCheckbox(parent)
        chargeCb:SetPoint("TOPLEFT", 16, yOffset)
        chargeCb.Text:SetText("Show the recharge of spell charges on action buttons")
        chargeCb:SetChecked(settings.chargeSweep ~= false)
        chargeCb:SetScript("OnClick", function(self)
            addon:SetSetting("cooldowns.chargeSweep", self:GetChecked() and true or false)
            RefreshChargeCooldowns(true)
        end)
    end

    return yOffset - 50
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("Cooldowns", Cooldowns)
