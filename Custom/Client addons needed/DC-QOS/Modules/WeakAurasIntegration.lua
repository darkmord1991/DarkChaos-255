-- ============================================================
-- DC-QoS: WeakAuras Integration
-- ============================================================
-- WeakAuras is now fully integrated into DC-QoS
-- No external addon folders required
-- ============================================================

local addon = DCQOS

local WeakAurasIntegration = {
    displayName = "WeakAuras",
    settingKey = "weakAuras",
    icon = "Interface\\Icons\\Spell_Nature_WispSplode",
    defaults = {
        weakAuras = {
            enabled = true,
            embedOptions = true,
        },
    },
}

for k, v in pairs(WeakAurasIntegration.defaults) do
    addon.defaults[k] = v
end

local function IsWeakAurasAvailable()
    -- WeakAuras is now built-in, always available after init
    return _G.WeakAuras ~= nil
end

-- WeakAuras is now built-in; no LoadAddOn needed
local function EnsureWeakAurasLoaded()
    return IsWeakAurasAvailable()
end

-- WeakAurasOptions is also built-in now
local function EnsureWeakAurasOptionsLoaded()
    return IsWeakAurasAvailable() and (_G.WeakAurasOptionsLoaded == true or _G.WeakAurasOptions ~= nil)
end

local function GetWeakAurasOptionsFrame()
    if _G.WeakAuras and _G.WeakAuras.OptionsFrame then
        return _G.WeakAuras.OptionsFrame()
    end
    return nil
end

local function EmbedWeakAurasOptions(container)
    if not container then
        return false
    end

    if not EnsureWeakAurasOptionsLoaded() then
        return false
    end

    if _G.WeakAuras and _G.WeakAuras.ShowOptions then
        _G.WeakAuras.ShowOptions()
    end

    local frame = GetWeakAurasOptionsFrame()
    if not frame then
        return false
    end

    frame:SetParent(container)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    frame:SetFrameStrata(container:GetFrameStrata())
    frame:SetFrameLevel((container:GetFrameLevel() or 1) + 1)

    if frame.SetMovable then
        frame:SetMovable(false)
    end

    frame:Show()
    WeakAurasIntegration._embeddedFrame = frame
    WeakAurasIntegration._embedContainer = container
    return true
end

local function UnembedWeakAurasOptions()
    local frame = WeakAurasIntegration._embeddedFrame
    if not frame then
        return
    end
    frame:SetParent(UIParent)
    frame:Hide()
    WeakAurasIntegration._embeddedFrame = nil
    WeakAurasIntegration._embedContainer = nil
end

local function OpenWeakAurasOptions()
    if not EnsureWeakAurasLoaded() then
        addon:Print("WeakAuras is not loaded (or you are in combat).", true)
        return
    end

    if _G.WeakAuras and _G.WeakAuras.OpenOptions then
        _G.WeakAuras.OpenOptions()
    else
        addon:Print("WeakAuras options are not available.", true)
    end
end

local function ToggleWeakAurasOptions()
    if not EnsureWeakAurasLoaded() then
        addon:Print("WeakAuras is not loaded (or you are in combat).", true)
        return
    end

    if _G.WeakAuras and _G.WeakAuras.ToggleOptions then
        _G.WeakAuras.ToggleOptions()
    else
        OpenWeakAurasOptions()
    end
end

function WeakAurasIntegration.OnEnable()
    local settings = addon.settings.weakAuras
    if not settings or not settings.enabled then
        return
    end
    -- WeakAuras is built-in and auto-loads with DC-QOS
end

function WeakAurasIntegration.OnDisable()
    -- Clean up embedded view
    UnembedWeakAurasOptions()
end

function WeakAurasIntegration.CreateSettings(parent)
    local settings = addon.settings.weakAuras

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("WeakAuras (Built-in)")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(450)
    desc:SetJustifyH("LEFT")
    desc:SetText("WeakAuras is fully integrated into DC-QoS. No external addon folders are required. Manage your auras directly from this panel.")

    local yOffset = -70

    local enabledCb = addon:CreateCheckbox(parent)
    enabledCb:SetPoint("TOPLEFT", 16, yOffset)
    enabledCb.Text:SetText("Enable WeakAuras")
    enabledCb:SetChecked(settings.enabled)
    enabledCb:SetScript("OnClick", function(self)
        addon:SetSetting("weakAuras.enabled", self:GetChecked())
    end)
    yOffset = yOffset - 30

    local embedCb = addon:CreateCheckbox(parent)
    embedCb:SetPoint("TOPLEFT", 16, yOffset)
    embedCb.Text:SetText("Embed WeakAuras options in DC-QoS")
    embedCb:SetChecked(settings.embedOptions)
    embedCb:SetScript("OnClick", function(self)
        addon:SetSetting("weakAuras.embedOptions", self:GetChecked())
        if self:GetChecked() then
            if WeakAurasIntegration._embedContainer then
                WeakAurasIntegration._embedContainer:Show()
                EmbedWeakAurasOptions(WeakAurasIntegration._embedContainer)
            end
        else
            UnembedWeakAurasOptions()
            if WeakAurasIntegration._embedContainer then
                WeakAurasIntegration._embedContainer:Hide()
            end
        end
    end)
    yOffset = yOffset - 30

    local openBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    openBtn:SetSize(170, 24)
    openBtn:SetPoint("TOPLEFT", 16, yOffset)
    openBtn:SetText("Open WeakAuras")
    openBtn:SetScript("OnClick", function()
        OpenWeakAurasOptions()
    end)

    local toggleBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    toggleBtn:SetSize(170, 24)
    toggleBtn:SetPoint("LEFT", openBtn, "RIGHT", 8, 0)
    toggleBtn:SetText("Toggle Options")
    toggleBtn:SetScript("OnClick", function()
        ToggleWeakAurasOptions()
    end)

    yOffset = yOffset - 40

    local statusText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", 16, yOffset)
    statusText:SetWidth(450)
    statusText:SetJustifyH("LEFT")
    statusText:SetTextColor(0.5, 1.0, 0.5)
    statusText:SetText("WeakAuras 4.0.0 (Built-in) |cff00ff00Active|r")

    yOffset = yOffset - 22

    local embedContainer = CreateFrame("Frame", nil, parent)
    embedContainer:SetPoint("TOPLEFT", 16, yOffset)
    embedContainer:SetPoint("BOTTOMRIGHT", -16, 16)
    embedContainer:SetFrameStrata("DIALOG")
    embedContainer:Hide()

    embedContainer.bg = embedContainer:CreateTexture(nil, "BACKGROUND")
    embedContainer.bg:SetAllPoints()
    embedContainer.bg:SetTexture(0, 0, 0, 0.15)

    local embedHint = embedContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    embedHint:SetPoint("TOPLEFT", 12, -10)
    embedHint:SetWidth(420)
    embedHint:SetJustifyH("LEFT")
    embedHint:SetTextColor(0.8, 0.8, 0.8)
    embedHint:SetText("WeakAuras options will appear here once loaded.")

    embedContainer:SetScript("OnShow", function()
        if addon.settings.weakAuras.embedOptions then
            EmbedWeakAurasOptions(embedContainer)
        end
    end)

    embedContainer:SetScript("OnHide", function()
        if WeakAurasIntegration._embeddedFrame then
            UnembedWeakAurasOptions()
        end
    end)

    WeakAurasIntegration._embedContainer = embedContainer

    addon:DelayedCall(0, function()
        if addon.settings.weakAuras.embedOptions then
            embedContainer:Show()
        else
            embedContainer:Hide()
        end
    end)

    return -700
end

addon:RegisterModule("WeakAuras", WeakAurasIntegration)
