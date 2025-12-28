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
-- Module Callbacks
-- ============================================================
function Cooldowns.OnInitialize()
    -- Hook CooldownFrame_SetTimer
    if not _G.CooldownFrame_SetTimer_Original then
        _G.CooldownFrame_SetTimer_Original = CooldownFrame_SetTimer
        hooksecurefunc("CooldownFrame_SetTimer", OnSetCooldown)
    end
end

function Cooldowns.OnEnable()
    -- Nothing specific needed, hooks carry logic
    addon.settings.cooldowns.enabled = true
end

function Cooldowns.OnDisable()
    addon.settings.cooldowns.enabled = false
    -- Hide existing timers
    for _, timer in pairs(activeTimers) do
        timer:Hide()
    end
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
    
    return yOffset - 50
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("Cooldowns", Cooldowns)
