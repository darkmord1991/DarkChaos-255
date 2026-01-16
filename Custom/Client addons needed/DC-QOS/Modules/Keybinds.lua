-- ============================================================
-- DC-QoS: Keybinds Module (Hover-to-bind)
-- ============================================================

local addon = DCQOS

local Keybinds = {
    displayName = "Keybinds",
    settingKey = "keybinds",
    icon = "Interface\\Icons\\INV_Misc_Key_14",
}

local binderFrame
local currentButton

local function NormalizeKey(key)
    if not key or key == "" then return nil end
    if key == "ESCAPE" then return "ESCAPE" end
    if key == "BUTTON1" or key == "BUTTON2" then return nil end
    if key == "UNKNOWN" then return nil end

    local mod = ""
    if IsControlKeyDown() then mod = mod .. "CTRL-" end
    if IsAltKeyDown() then mod = mod .. "ALT-" end
    if IsShiftKeyDown() then mod = mod .. "SHIFT-" end

    return mod .. key
end

local function BindKeyToButton(key, button)
    if not button or not button.GetName then return end
    local name = button:GetName()
    if not name then return end

    if key == "ESCAPE" or key == "BACKSPACE" then
        local binding = "CLICK " .. name .. ":LeftButton"
        local key1, key2 = GetBindingKey(binding)
        if key1 then SetBinding(key1) end
        if key2 then SetBinding(key2) end
    else
        SetBindingClick(key, name)
    end

    if SaveBindings then
        SaveBindings(GetCurrentBindingSet())
    end

    addon:Print("Bound " .. (key == "ESCAPE" and "(cleared)" or key) .. " to " .. name, true)
end

local function EnsureBinderFrame()
    if binderFrame then return end
    binderFrame = CreateFrame("Frame", "DCQOS_KeybindBinder", UIParent)
    binderFrame:EnableKeyboard(true)
    binderFrame:SetPropagateKeyboardInput(false)
    binderFrame:SetFrameStrata("TOOLTIP")
    binderFrame:SetAllPoints(UIParent)

    binderFrame:SetScript("OnKeyDown", function(self, key)
        if not currentButton then return end
        local normalized = NormalizeKey(key)
        if not normalized then return end
        BindKeyToButton(normalized, currentButton)
    end)
end

local function HookButton(btn)
    if not btn or btn.__dcqos_keybind_hooked then return end
    btn.__dcqos_keybind_hooked = true

    btn:HookScript("OnEnter", function(self)
        local s = addon.settings.keybinds
        if not s.enabled then return end
        if s.onlyWhenBindingMode and not addon.keybindMode then return end

        currentButton = self
        EnsureBinderFrame()
        binderFrame:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Press a key to bind. ESC/BACKSPACE clears.")
        GameTooltip:Show()
    end)

    btn:HookScript("OnLeave", function()
        currentButton = nil
        if binderFrame then binderFrame:Hide() end
        GameTooltip:Hide()
    end)
end

local function HookActionButtons()
    local prefixes = {
        "ActionButton",
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarRightButton",
        "MultiBarLeftButton",
    }

    for _, prefix in ipairs(prefixes) do
        for i = 1, 12 do
            local btn = _G[prefix .. i]
            if btn then
                HookButton(btn)
            end
        end
    end
end

function Keybinds.OnInitialize()
    addon:Debug("Keybinds module initializing")
end

function Keybinds.OnEnable()
    addon:Debug("Keybinds module enabling")
    HookActionButtons()
end

function Keybinds.OnDisable()
    addon:Debug("Keybinds module disabling")
end

function Keybinds.CreateSettings(parent)
    local settings = addon.settings.keybinds

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Keybinds")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Hover over action buttons and press a key to bind.")
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")

    local yOffset = -70

    local enabledCb = addon:CreateCheckbox(parent)
    enabledCb:SetPoint("TOPLEFT", 16, yOffset)
    enabledCb.Text:SetText("Enable hover-to-bind")
    enabledCb:SetChecked(settings.enabled)
    enabledCb:SetScript("OnClick", function(self)
        addon:SetSetting("keybinds.enabled", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local onlyModeCb = addon:CreateCheckbox(parent)
    onlyModeCb:SetPoint("TOPLEFT", 16, yOffset)
    onlyModeCb.Text:SetText("Only when keybind mode is enabled")
    onlyModeCb:SetChecked(settings.onlyWhenBindingMode)
    onlyModeCb:SetScript("OnClick", function(self)
        addon:SetSetting("keybinds.onlyWhenBindingMode", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local hint = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, yOffset)
    hint:SetText("Toggle keybind mode with /dcqos bind")
end

addon:RegisterModule("Keybinds", Keybinds)
