-- ============================================================
-- DC-QoS: Return to Graveyard Module
-- ============================================================
-- Faithful downport of retail's on-screen "Return to Graveyard"
-- button (GhostFrame) to WoW 3.3.5a.
--
-- Retail reference (extracted 11.2.7 FrameXML):
--   * Blizzard_FrameXML/GhostFrame.xml
--       - inherits UIPanelLargeSilverButton
--       - icon  : Interface\Icons\spell_holy_guardianspirit (36x36, left of text)
--       - text  : RETURN_TO_GRAVEYARD = "Return to Graveyard"
--       - OnClick: PlaySound(IG_MAINMENU_OPEN); PortGraveyard()
--   * Blizzard_UIParent/Mainline/UIParent.lua
--       - shown only while UnitIsGhost("player"); re-checked on
--         PLAYER_ALIVE / PLAYER_UNGHOST / PLAYER_ENTERING_WORLD
--   * Blizzard_UIPanelTemplates/UIPanelTemplates.xml (UIPanelLargeSilverButton)
--       - 3-slice chrome: Interface\Buttons\UI-SilverButtonLG-{Left,Mid,Right}-{Up,Down,Hi}
--
-- 3.3.5a has no PortGraveyard() and the core refuses a second spirit
-- release once you are a ghost, so the click asks the server (DC addon
-- protocol, module GRVY) to run Player::RepopAtGraveyard() for us.
-- ============================================================

local addon = DCQOS

-- Server module/opcode -- must match dc_addon_namespace.h
--   Module::GRAVEYARD = "GRVY"
--   Opcode::Graveyard::CMSG_RETURN = 0x01
local GRVY_MODULE      = "GRVY"
local GRVY_CMSG_RETURN = 0x01

-- Faithful retail geometry / art (see header).
local TEX_BUTTON   = "Interface\\Buttons\\UI-SilverButtonLG-"
local TEX_ICON     = "Interface\\Icons\\spell_holy_guardianspirit"
local BUTTON_W     = 150
local BUTTON_H     = 46
local SLICE_W      = 32
local SLICE_H      = 64
local DEFAULT_POINT = "TOP"
local DEFAULT_X     = 0
local DEFAULT_Y     = -20  -- top-center fallback when no popup is showing
local POPUP_GAP     = 6    -- space above a death/resurrect popup
local CLICK_THROTTLE = 0.5

local Graveyard = {
    displayName = "Return to Graveyard",
    settingKey  = "graveyard",
    icon        = TEX_ICON,
    defaults = {
        graveyard = {
            enabled = true,
            pos     = nil, -- { point, relPoint, x, y }; nil = auto (above popup / top-center)
        },
    },
}

local button      -- the GhostFrame-equivalent button (created once)
local eventFrame
local popupHooksInstalled = false

-- ============================================================
-- Helpers
-- ============================================================

local function GetSettings()
    return (addon and addon.settings and addon.settings.graveyard) or {}
end

local function ModuleEnabled()
    return GetSettings().enabled ~= false
end

-- Ask the server to teleport our released ghost to the nearest graveyard.
local function RequestReturnToGraveyard()
    local DC = rawget(_G, "DCAddonProtocol")
    if not DC then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[DC]|r Return to Graveyard is unavailable (protocol not loaded).")
        end
        return
    end

    if type(DC.EnsureConnected) == "function" then
        pcall(DC.EnsureConnected, DC)
    end

    -- No payload needed; the opcode alone tells the server to repop us.
    if type(DC.Send) == "function" then
        pcall(DC.Send, DC, GRVY_MODULE, GRVY_CMSG_RETURN)
    elseif type(DC.Request) == "function" then
        pcall(DC.Request, DC, GRVY_MODULE, GRVY_CMSG_RETURN, {})
    end
end

local function SavePosition(self)
    local point, _, relPoint, x, y = self:GetPoint()
    local s = GetSettings()
    s.pos = { point = point, relPoint = relPoint or point, x = x, y = y }
end

-- Find the topmost currently-visible static popup (the death / resurrect
-- dialog while you are a ghost), so the button can sit just above it.
local function GetTopVisiblePopup()
    for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
        local f = _G["StaticPopup" .. i]
        if f and f:IsShown() then
            return f
        end
    end
end

-- Position the button: a manual (shift-dragged) spot wins; otherwise sit just
-- above the death/resurrect popup if one is up; otherwise top-center.
local function AnchorButton()
    if not button then
        return
    end
    button:ClearAllPoints()

    local saved = GetSettings().pos
    if saved and saved.point then
        button:SetPoint(saved.point, UIParent, saved.relPoint or saved.point, saved.x or 0, saved.y or 0)
        return
    end

    local popup = GetTopVisiblePopup()
    if popup then
        button:SetPoint("BOTTOM", popup, "TOP", 0, POPUP_GAP)
    else
        button:SetPoint(DEFAULT_POINT, UIParent, DEFAULT_POINT, DEFAULT_X, DEFAULT_Y)
    end
end

-- Retail shows the button iff the player is a released ghost.
local function UpdateVisibility()
    if not button then
        return
    end
    if ModuleEnabled() and UnitIsGhost and UnitIsGhost("player") then
        AnchorButton()
        button:Show()
    else
        button:Hide()
    end
end

-- ============================================================
-- Button construction (faithful UIPanelLargeSilverButton 3-slice)
-- ============================================================

local function BuildButton()
    if button then
        return button
    end

    local b = CreateFrame("Button", "DCQOS_ReturnToGraveyardButton", UIParent)
    b:SetSize(BUTTON_W, BUTTON_H)
    b:SetFrameStrata("HIGH")
    b:Hide()

    -- Create one 3-slice (Left/Mid/Right) on a draw layer for a given state suffix.
    local function buildSlice(layer, suffix)
        local left = b:CreateTexture(nil, layer)
        left:SetTexture(TEX_BUTTON .. "Left-" .. suffix)
        left:SetSize(SLICE_W, SLICE_H)
        left:SetPoint("TOPLEFT", 0, 0)

        local right = b:CreateTexture(nil, layer)
        right:SetTexture(TEX_BUTTON .. "Right-" .. suffix)
        right:SetSize(SLICE_W, SLICE_H)
        right:SetPoint("TOPRIGHT", 0, 0)

        local mid = b:CreateTexture(nil, layer)
        mid:SetTexture(TEX_BUTTON .. "Mid-" .. suffix)
        mid:SetHeight(SLICE_H)
        mid:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
        mid:SetPoint("TOPRIGHT", right, "TOPLEFT", 0, 0)

        return { left = left, right = right, mid = mid }
    end

    -- Normal ("Up") chrome in BACKGROUND, swapped to "Down" while pressed.
    local bg = buildSlice("BACKGROUND", "Up")
    local function setBg(suffix)
        bg.left:SetTexture(TEX_BUTTON .. "Left-" .. suffix)
        bg.right:SetTexture(TEX_BUTTON .. "Right-" .. suffix)
        bg.mid:SetTexture(TEX_BUTTON .. "Mid-" .. suffix)
    end

    -- Mouse-over highlight ("Hi") -- HIGHLIGHT-layer textures auto-show on hover.
    buildSlice("HIGHLIGHT", "Hi")

    -- Contents: guardian-spirit icon at the left, label filling the rest
    -- (mirrors GhostFrame's $parentIcon + $parentText).
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(TEX_ICON)
    icon:SetSize(34, 34)
    icon:SetPoint("LEFT", b, "LEFT", 8, 0)

    local text = b:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetJustifyH("LEFT")
    text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    text:SetText(RETURN_TO_GRAVEYARD or "Return to Graveyard")
    b:SetFontString(text)

    -- Fit the button to the full label. 3.3.5a's GameFontNormal is wider than
    -- retail's, so a fixed width clipped the text to "Return to Gra...".
    -- (left pad 8 + icon 34 + gap 6 + text + right pad 14)
    local fitWidth = 8 + 34 + 6 + (text:GetStringWidth() or 0) + 14
    b:SetWidth(math.max(fitWidth, BUTTON_W))

    -- Pressed-state feedback: swap to "Down" art and nudge the contents.
    b:SetScript("OnMouseDown", function()
        setBg("Down")
        icon:SetPoint("LEFT", b, "LEFT", 9, -1)
    end)
    b:SetScript("OnMouseUp", function()
        setBg("Up")
        icon:SetPoint("LEFT", b, "LEFT", 8, 0)
    end)

    b:SetScript("OnClick", function(self)
        local now = GetTime()
        if (now - (self._lastClick or 0)) < CLICK_THROTTLE then
            return
        end
        self._lastClick = now
        pcall(PlaySound, "igMainMenuOpen") -- retail: SOUNDKIT.IG_MAINMENU_OPEN
        RequestReturnToGraveyard()
    end)

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(RETURN_TO_GRAVEYARD or "Return to Graveyard", 1, 1, 1)
        GameTooltip:AddLine("Teleport to the nearest graveyard.", nil, nil, nil, true)
        GameTooltip:AddLine("Shift-drag to move.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Shift-drag to reposition (retail's is fixed; this is a QoL extra).
    b:SetMovable(true)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)

    button = b
    AnchorButton()

    -- Keep clear of death/resurrect popups: re-anchor whenever a popup is
    -- shown or hidden (the resurrect dialog appears after we reach a graveyard).
    if not popupHooksInstalled then
        popupHooksInstalled = true
        if type(hooksecurefunc) == "function" then
            if type(StaticPopup_Show) == "function" then
                hooksecurefunc("StaticPopup_Show", function()
                    if button and button:IsShown() then AnchorButton() end
                end)
            end
            if type(StaticPopup_Hide) == "function" then
                hooksecurefunc("StaticPopup_Hide", function()
                    if button and button:IsShown() then AnchorButton() end
                end)
            end
        end
    end

    return b
end

-- ============================================================
-- Module Callbacks
-- ============================================================

function Graveyard.OnInitialize()
    addon:Debug("Graveyard module initializing")
end

function Graveyard.OnEnable()
    addon:Debug("Graveyard module enabling")

    BuildButton()

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", function()
            UpdateVisibility()
        end)
    end
    eventFrame:RegisterEvent("PLAYER_ALIVE")          -- released spirit / resurrected
    eventFrame:RegisterEvent("PLAYER_UNGHOST")        -- no longer a ghost
    eventFrame:RegisterEvent("PLAYER_DEAD")           -- died
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD") -- /reload, zone-in while dead

    UpdateVisibility()
end

function Graveyard.OnDisable()
    addon:Debug("Graveyard module disabling")
    if eventFrame then
        eventFrame:UnregisterAllEvents()
    end
    if button then
        button:Hide()
    end
end

-- ============================================================
-- Settings Panel
-- ============================================================

function Graveyard.CreateSettings(parent)
    local settings = GetSettings()
    local yOffset = -16

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, yOffset)
    title:SetText("Return to Graveyard")

    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("Faithful downport of retail's on-screen \"Return to Graveyard\" button. " ..
        "While you are a ghost, click it to teleport to the nearest graveyard (spirit healer).")
    yOffset = yOffset - 70

    local enableCb = addon:CreateCheckbox(parent)
    enableCb:SetPoint("TOPLEFT", 16, yOffset)
    enableCb.Text:SetText("Enable Return to Graveyard button")
    enableCb:SetChecked(settings.enabled ~= false)
    enableCb:SetScript("OnClick", function(self)
        addon:SetSetting("graveyard.enabled", self:GetChecked())
        UpdateVisibility()
    end)
    yOffset = yOffset - 34

    local resetBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    resetBtn:SetSize(160, 22)
    resetBtn:SetPoint("TOPLEFT", 16, yOffset)
    resetBtn:SetText("Reset button position")
    resetBtn:SetScript("OnClick", function()
        local s = GetSettings()
        s.pos = nil
        if button then
            AnchorButton()
        end
    end)
    yOffset = yOffset - 36

    local note = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 16, yOffset)
    note:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    note:SetJustifyH("LEFT")
    note:SetText("Tip: shift-drag the button to move it. By default it sits above the resurrect " ..
        "popup, or top-center. The silver skin uses the Interface\\Buttons\\UI-SilverButtonLG-* " ..
        "textures shipped with the DarkChaos client patch.")

    return yOffset - 40
end

addon:RegisterModule("Graveyard", Graveyard)
