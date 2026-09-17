-- DC-DangerZone / Options.lua -------------------------------------------------
-- Interface -> AddOns -> DC DangerZone.  Built once on PLAYER_LOGIN (or on the
-- first /dz config) when the stock options API is present; every control
-- writes through addon:Set() so the renderer picks the value up next tick.
--------------------------------------------------------------------------------

local addon = DCDangerZone
local Options = {}
addon.Options = Options

local PANEL_NAME = "DCDangerZoneOptionsPanel"

local STYLE_CHOICES = {
    { "retail", "Retail decal (textured)" },
    { "classic", "Classic dotted ring" },
    { "both", "Both" },
}
local FILL_CHOICES = {
    { "glow", "Soft glow" },
    { "disc", "Flat disc" },
    { "none", "None" },
}
local EDGE_CHOICES = {
    { "ring", "Thick ring" },
    { "double", "Double ring" },
    { "none", "None" },
}
local SPINNER_CHOICES = {
    { "reticle", "Ground reticle" },
    { "swirl", "Swirl" },
    { "none", "None" },
}
local QUALITY_CHOICES = {
    { 1, "Low (6 strips)" },
    { 2, "Medium (10 strips)" },
    { 3, "High (16 strips)" },
}

local controls = {}

local function LabelFor(choices, value)
    for _, c in ipairs(choices) do
        if c[1] == value then
            return c[2]
        end
    end
    return tostring(value)
end

local function MakeCheck(parent, key, label, tooltip, x, y)
    local name = PANEL_NAME .. "_" .. key
    local cb = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local text = _G[name .. "Text"]
    if text then
        text:SetText(label)
    end
    cb.tooltipText = tooltip
    cb:SetScript("OnClick", function(self)
        addon:Set(key, self:GetChecked() and true or false)
    end)
    controls[key] = { kind = "check", frame = cb }
    return cb
end

local function MakeSlider(parent, key, label, minV, maxV, step, fmt, x, y)
    local name = PANEL_NAME .. "_" .. key
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    title:SetText(label)

    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 16)
    slider:SetWidth(170)
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    local low, high, txt = _G[name .. "Low"], _G[name .. "High"], _G[name .. "Text"]
    if low then low:SetText(string.format(fmt, minV)) end
    if high then high:SetText(string.format(fmt, maxV)) end
    slider:SetScript("OnValueChanged", function(self, value)
        if self._internal then
            return
        end
        value = math.floor(value / step + 0.5) * step
        addon:Set(key, value)
    end)
    controls[key] = { kind = "slider", frame = slider, text = txt, fmt = fmt }
    return slider
end

local function MakeDropdown(parent, key, label, choices, x, y)
    local name = PANEL_NAME .. "_" .. key
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    title:SetText(label)

    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", parent, "TOPLEFT", x - 16, y - 14)
    UIDropDownMenu_SetWidth(dd, 150)
    UIDropDownMenu_Initialize(dd, function()
        local db = addon:InitSettings()
        for _, choice in ipairs(choices) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = choice[2]
            info.value = choice[1]
            info.checked = (db[key] == choice[1])
            info.func = function()
                addon:Set(key, choice[1])
                UIDropDownMenu_SetSelectedValue(dd, choice[1])
                UIDropDownMenu_SetText(dd, choice[2])
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    controls[key] = { kind = "dropdown", frame = dd, choices = choices }
    return dd
end

local function MakeButton(parent, label, x, y, width, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:SetSize(width, 22)
    btn:SetText(label)
    btn:SetScript("OnClick", onClick)
    return btn
end

function Options:Refresh()
    local db = addon:InitSettings()
    for key, c in pairs(controls) do
        local value = db[key]
        if c.kind == "check" then
            c.frame:SetChecked(value and true or false)
        elseif c.kind == "slider" then
            c.frame._internal = true
            c.frame:SetValue(tonumber(value) or 0)
            c.frame._internal = false
            if c.text then
                c.text:SetText(string.format(c.fmt, tonumber(value) or 0))
            end
        elseif c.kind == "dropdown" then
            UIDropDownMenu_SetSelectedValue(c.frame, value)
            UIDropDownMenu_SetText(c.frame, LabelFor(c.choices, value))
        end
    end
end

function Options:Build()
    if self.panel then
        return self.panel
    end
    if type(InterfaceOptions_AddCategory) ~= "function" or type(UIDropDownMenu_Initialize) ~= "function" then
        return nil
    end

    local panel = CreateFrame("Frame", PANEL_NAME, UIParent)
    panel.name = "DC DangerZone"
    panel:Hide()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText("|cffFFCC00DC|r DangerZone " .. addon.version)

    local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetWidth(560)
    sub:SetJustifyH("LEFT")
    sub:SetText("Ground telegraphs for dangerous AoE spells. Zones come from the WotLKExtensions " ..
        "DangerZone profiles; this panel controls how they are drawn. Type /dz test to preview one at your feet.")

    local L, R = 16, 300
    local y = -72

    MakeCheck(panel, "enabled", "Enable danger-zone telegraphs", "Master switch.", L, y)
    MakeCheck(panel, "additive", "Additive (glowing) blend", "Blend the decal additively over the ground.", R, y)
    y = y - 30
    MakeCheck(panel, "showTimer", "Show remaining seconds", "Countdown text at the zone centre.", L, y)
    MakeCheck(panel, "showProgress", "Show fill-in progress", "An inner disc grows as the zone runs out.", R, y)
    y = y - 30
    MakeCheck(panel, "warnInside", "Warn while standing inside", "Pulse the ring and flash the screen edge.", L, y)
    MakeCheck(panel, "warnFlash", "  Screen flash", "Red screen-edge flash while inside a zone.", R, y)
    y = y - 30
    MakeCheck(panel, "warnSound", "  Warning sound", "Play the raid-warning sound when you enter a zone.", R, y)

    y = y - 44
    MakeDropdown(panel, "style", "Style", STYLE_CHOICES, L, y)
    MakeDropdown(panel, "quality", "Decal quality", QUALITY_CHOICES, R, y)
    y = y - 52
    MakeDropdown(panel, "fillTexture", "Fill texture", FILL_CHOICES, L, y)
    MakeDropdown(panel, "edgeTexture", "Edge texture", EDGE_CHOICES, R, y)
    y = y - 52
    MakeDropdown(panel, "spinner", "Animated overlay", SPINNER_CHOICES, L, y)

    y = y - 56
    MakeSlider(panel, "fillOpacity", "Fill opacity", 0, 1, 0.05, "%.2f", L, y)
    MakeSlider(panel, "edgeOpacity", "Edge opacity", 0, 1, 0.05, "%.2f", R, y)
    y = y - 52
    MakeSlider(panel, "spinnerOpacity", "Overlay opacity", 0, 1, 0.05, "%.2f", L, y)
    MakeSlider(panel, "spinSpeed", "Overlay spin speed (rad/s)", 0, 3, 0.1, "%.1f", R, y)
    y = y - 52
    MakeSlider(panel, "maxZones", "Max zones drawn", 1, 12, 1, "%d", L, y)

    y = y - 56
    MakeButton(panel, "Preview at my feet", L, y, 150, function()
        addon:HandleSlash("test 8 8")
    end)
    MakeButton(panel, "Clear previews", L + 160, y, 120, function()
        addon:HandleSlash("clear")
    end)
    MakeButton(panel, "Reset to defaults", R, y, 150, function()
        local db = addon:InitSettings()
        for k, v in pairs(addon.defaults) do
            db[k] = v
        end
        addon:Set("enabled", db.enabled)
    end)

    panel:SetScript("OnShow", function()
        Options:Refresh()
    end)

    InterfaceOptions_AddCategory(panel)
    self.panel = panel
    return panel
end

function Options:Open()
    local panel = self:Build()
    if panel and type(InterfaceOptionsFrame_OpenToCategory) == "function" then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel) -- twice: 3.3.5 scroll quirk
    else
        addon:Print("options panel unavailable")
    end
end
