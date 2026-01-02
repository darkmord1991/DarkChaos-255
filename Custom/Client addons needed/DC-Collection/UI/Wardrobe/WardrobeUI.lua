--[[
    DC-Collection UI/Wardrobe/WardrobeUI.lua
    =======================================

    Frame creation and static UI layout for Wardrobe.
]]

local DC = DCCollection
if not DC then return end

DC.Wardrobe = DC.Wardrobe or {}
local Wardrobe = DC.Wardrobe

local BG_FELLEATHER = "Interface\\AddOns\\DC-Collection\\Textures\\Backgrounds\\FelLeather_512.tga"
local BG_TINT_ALPHA = 0.60

local function ApplyLeaderboardsStyle(frame)
    if not frame or frame.__dcLeaderboardsStyled then
        return
    end
    frame.__dcLeaderboardsStyled = true

    if frame.SetBackdropColor then
        frame:SetBackdropColor(0, 0, 0, 0)
    end

    frame.bg = frame.bg or frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.bg:SetAllPoints()
    frame.bg:SetTexture(BG_FELLEATHER)

    frame.bgTint = frame.bgTint or frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    frame.bgTint:SetAllPoints(frame.bg)
    frame.bgTint:SetTexture(0, 0, 0, BG_TINT_ALPHA)
end

local INVTYPE_LABELS = {
    [0]  = "Unknown",
    [1]  = "Head",
    [3]  = "Shoulder",
    [4]  = "Shirt",
    [5]  = "Chest",
    [6]  = "Waist",
    [7]  = "Legs",
    [8]  = "Feet",
    [9]  = "Wrist",
    [10] = "Hands",
    [13] = "One-Hand",
    [14] = "Off-Hand",
    [15] = "Ranged",
    [16] = "Back",
    [17] = "Two-Hand",
    [19] = "Tabard",
    [20] = "Robe",
    [21] = "Main Hand",
    [22] = "Off Hand",
    [23] = "Held In Off-hand",
    [25] = "Thrown",
    [26] = "Ranged",
    [28] = "Relic",
}

local function GetInvTypeLabel(invType)
    return INVTYPE_LABELS[invType] or ("InvType " .. tostring(invType))
end

local function SetSpecialFrameRegistered(frameName, shouldRegister)
    if type(frameName) ~= "string" or frameName == "" or not UISpecialFrames then
        return
    end

    local foundIndex = nil
    for i = 1, #UISpecialFrames do
        if UISpecialFrames[i] == frameName then
            foundIndex = i
            break
        end
    end

    if shouldRegister then
        if not foundIndex then
            tinsert(UISpecialFrames, frameName)
        end
    else
        if foundIndex then
            table.remove(UISpecialFrames, foundIndex)
        end
    end
end

-- ============================================================================
-- FRAME CREATION
-- ============================================================================

function Wardrobe:CreateFrame()
    if self.frame then
        return self.frame
    end

    local FRAME_WIDTH = self.FRAME_WIDTH
    local FRAME_HEIGHT = self.FRAME_HEIGHT

    local frame = CreateFrame("Frame", "DCWardrobeFrame", UIParent)
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    local BG_FELLEATHER = "Interface\\AddOns\\DC-Leaderboards\\Textures\\Backgrounds\\FelLeather_512.tga"
    local BG_TINT_ALPHA = 0.60

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.bg:SetAllPoints()
    frame.bg:SetTexture(BG_FELLEATHER)

    frame.bgTint = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    frame.bgTint:SetAllPoints(frame.bg)
    frame.bgTint:SetTexture(0, 0, 0, BG_TINT_ALPHA)

    frame.portrait = frame:CreateTexture(nil, "ARTWORK")
    frame.portrait:SetSize(60, 60)
    frame.portrait:SetPoint("TOPLEFT", -5, 7)
    frame.portrait:SetTexture("Interface\\Icons\\INV_Chest_Cloth_17")

    frame.portraitBorder = frame:CreateTexture(nil, "OVERLAY")
    frame.portraitBorder:SetSize(80, 80)
    frame.portraitBorder:SetPoint("TOPLEFT", -14, 14)
    frame.portraitBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -12)
    frame.title:SetText("Wardrobe")

    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
    frame.closeBtn:SetScript("OnClick", function() Wardrobe:Hide() end)

    frame.backBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.backBtn:SetSize(80, 22)
    frame.backBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    frame.backBtn:SetText("Back")
    frame.backBtn:SetScript("OnClick", function()
        Wardrobe:Hide()
        if DC.ShowMainFrame then
            DC:ShowMainFrame()
        end
    end)

    self:CreateLeftPanel(frame)
    self:CreateRightPanel(frame)
    self:CreateBottomBar(frame)

    SetSpecialFrameRegistered("DCWardrobeFrame", true)

    self:HookItemTooltip()

    self.frame = frame
    return frame
end

function Wardrobe:SetEmbeddedMode(isEmbedded, host)
    local frame = self.frame
    if not frame then
        return
    end

    self.isEmbedded = isEmbedded and true or false

    if self.isEmbedded then
        if host then
            frame:SetParent(host)
            frame:ClearAllPoints()
            frame:SetAllPoints(host)
        end

        frame:SetMovable(false)
        frame:RegisterForDrag(nil)
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)

        -- Hide standalone window chrome when embedded.
        if frame.closeBtn then frame.closeBtn:Hide() end
        if frame.backBtn then frame.backBtn:Hide() end
        if frame.title then frame.title:Hide() end
        if frame.portrait then frame.portrait:Hide() end
        if frame.portraitBorder then frame.portraitBorder:Hide() end
        if frame.bg then frame.bg:Hide() end
        if frame.bgTint then frame.bgTint:Hide() end

        frame:SetBackdrop(nil)

        -- Embedded: don't treat as a special frame (ESC should close main frame, not just the embedded sub-frame).
        SetSpecialFrameRegistered("DCWardrobeFrame", false)

        if self._ApplyEmbeddedLayout then
            self:_ApplyEmbeddedLayout()
        end
    else
        frame:SetParent(UIParent)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER")
        frame:SetSize(self.FRAME_WIDTH, self.FRAME_HEIGHT)

        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

        if frame.closeBtn then frame.closeBtn:Show() end
        if frame.backBtn then frame.backBtn:Show() end
        if frame.title then frame.title:Show() end
        if frame.portrait then frame.portrait:Show() end
        if frame.portraitBorder then frame.portraitBorder:Show() end
        if frame.bg then frame.bg:Show() end

        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        frame:SetBackdropColor(0, 0, 0, 0)

        ApplyLeaderboardsStyle(frame)

        SetSpecialFrameRegistered("DCWardrobeFrame", true)

        if self._ApplyStandaloneLayout then
            self:_ApplyStandaloneLayout()
        end
    end
end

function Wardrobe:_EnsurePreviewHost()
    if not self.frame then return end
    if self.frame.previewHost then return end

    local host = CreateFrame("Frame", nil, self.frame)
    host:SetFrameStrata("HIGH")
    host:Hide()

    self.frame.previewHost = host
end

function Wardrobe:_ApplyEmbeddedLayout()
    local frame = self.frame
    if not frame then return end

    self:_EnsurePreviewHost()

    local left = frame.leftPanel
    local right = frame.rightPanel
    local bottom = frame.bottomBar
    local previewHost = frame.previewHost
    local previewModeFrame = frame.previewModeFrame

    if not left or not right or not bottom or not previewHost then
        return
    end

    local insetX = 15
    local topInset = 0      -- Move content UP to the top edge
    local bottomInset = 40  -- Move bottom bar UP from the bottom edge
    local gap = 15
    local bottomBarHeight = 50
    local previewWidth = 280  -- Larger preview area to match bigger tooltip preview
    local leftPanelWidth = self.MODEL_WIDTH + 130  -- Width for slots + model + slots

    -- Right-side reserved area for tooltip/model preview.
    previewHost:ClearAllPoints()
    previewHost:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -insetX, -topInset)
    previewHost:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -insetX, bottomInset)
    previewHost:SetWidth(previewWidth)
    previewHost:Show()

    -- Left panel: slots + model + slots arrangement
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", insetX, -topInset)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", insetX, bottomInset + bottomBarHeight + gap)
    left:SetWidth(leftPanelWidth)

    -- Bottom bar: keep fully inside the frame, aligned to the left panel width.
    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", insetX, bottomInset)
    bottom:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", 0, bottomInset)
    bottom:SetHeight(bottomBarHeight)

    -- Right panel: fill the space between left panel and preview host.
    right:ClearAllPoints()
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", gap, 0)
    right:SetPoint("BOTTOMRIGHT", previewHost, "BOTTOMLEFT", -gap, 0)

    -- Move Preview Toggle to Bottom Right (near page controls)
    if previewModeFrame then
        previewModeFrame:ClearAllPoints()
        previewModeFrame:SetParent(frame)
        previewModeFrame:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 5)
        previewModeFrame:SetFrameStrata("HIGH")
    end

    -- If the tooltip preview already exists, re-parent + re-anchor it.
    if self.tooltipPreview and self.tooltipPreview.SetParent then
        self.tooltipPreview:SetParent(previewHost)
        self.tooltipPreview:ClearAllPoints()
        -- Bottom of preview host for embedded mode
        self.tooltipPreview:SetPoint("BOTTOM", previewHost, "BOTTOM", 0, 10)
    end
end

function Wardrobe:_ApplyStandaloneLayout()
    local frame = self.frame
    if not frame then return end

    self:_EnsurePreviewHost()
    if frame.previewHost then
        frame.previewHost:Hide()
    end

    local left = frame.leftPanel
    local right = frame.rightPanel
    local bottom = frame.bottomBar
    local previewModeFrame = frame.previewModeFrame

    if not left or not right or not bottom then
        return
    end

    -- Restore original standalone anchors/sizes.
    local panelWidth = self.MODEL_WIDTH + 120  -- Slots on both sides of model
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -20)
    left:SetSize(panelWidth, self.FRAME_HEIGHT - 100)

    right:ClearAllPoints()
    right:SetPoint("TOPLEFT", frame, "TOPLEFT", 380, -20)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 70)

    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 45, 10)
    bottom:SetSize(self.MODEL_WIDTH + 50, 50)

    if previewModeFrame then
        previewModeFrame:SetParent(bottom)
        previewModeFrame:ClearAllPoints()
        previewModeFrame:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT", -10, 0)
    end

    if self.tooltipPreview and self.tooltipPreview.SetParent then
        self.tooltipPreview:SetParent(frame)
        self.tooltipPreview:ClearAllPoints()
        -- Bottom-right position to avoid overlapping with slot icons
        self.tooltipPreview:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 80)
    end
end

-- ============================================================================
-- TOOLTIP HELPERS (Wardrobe)
-- ============================================================================

function Wardrobe:_GetFixedTooltipAnchor()
    -- Prefer anchoring to the Wardrobe frame so tooltip stays near the UI.
    return (self.frame and self.frame.IsShown and self.frame:IsShown() and self.frame) or UIParent
end

function Wardrobe:ShowFixedItemTooltip(owner, itemId, extraLineFn)
    if not itemId then
        return
    end

    local anchor = self:_GetFixedTooltipAnchor()

    GameTooltip:Hide()
    GameTooltip:SetOwner(anchor, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    -- Position tooltip in the lower-center area to avoid overlapping with slot icons
    GameTooltip:SetPoint("BOTTOM", anchor, "BOTTOM", 0, 80)
    GameTooltip:SetClampedToScreen(true)

    GameTooltip:SetHyperlink("item:" .. tostring(itemId))
    if type(extraLineFn) == "function" then
        extraLineFn(GameTooltip)
    end
    GameTooltip:Show()
end

function Wardrobe:ShowSlotFilterMenu(anchorButton)
    if not anchorButton then
        return
    end

    local dropdown = CreateFrame("Frame", "DCWardrobeSlotFilterMenu", UIParent, "UIDropDownMenuTemplate")
    local menu = {}

    local function GetSlotFilterMenuLabel(filter)
        if type(filter) == "table" and type(filter.label) == "string" and filter.label ~= "" then
            return filter.label
        end

        local invTypes = {}
        for invType in pairs((filter and filter.invTypes) or {}) do
            table.insert(invTypes, invType)
        end
        table.sort(invTypes)

        if #invTypes == 0 then
            return "Misc / Cosmetic"
        end

        if #invTypes == 1 then
            return GetInvTypeLabel(invTypes[1])
        end

        -- If multiple invTypes map to the same slot category, prefer a concise label.
        return GetInvTypeLabel(invTypes[1])
    end

    table.insert(menu, {
        text = "All Slots",
        notCheckable = true,
        func = function()
            self.selectedSlotFilter = nil
            if self.frame and self.frame.slotFilterButtons then
                for _, b in ipairs(self.frame.slotFilterButtons) do
                    if b.selected then b.selected:Hide() end
                end
            end
            self:RefreshGrid()
        end,
    })

    for i, filter in ipairs(self.SLOT_FILTERS or {}) do
        table.insert(menu, {
            text = GetSlotFilterMenuLabel(filter),
            notCheckable = true,
            func = function()
                self.selectedSlotFilter = filter
                if self.frame and self.frame.slotFilterButtons then
                    for j, b in ipairs(self.frame.slotFilterButtons) do
                        if b.selected then
                            if j == i then b.selected:Show() else b.selected:Hide() end
                        end
                    end
                end
                self:RefreshGrid()
            end,
        })
    end

    EasyMenu(menu, dropdown, anchorButton, 0, 0, "MENU")
end

-- ============================================================================
-- LEFT PANEL
-- ============================================================================

function Wardrobe:CreateLeftPanel(parent)
    local MODEL_WIDTH = self.MODEL_WIDTH
    local SLOT_SIZE = self.SLOT_SIZE
    local SLOT_GAP = 6  -- Gap between slots
    local LEFT_SLOTS = 7  -- HeadSlot through WristSlot
    local RIGHT_SLOTS = 4 -- HandsSlot through FeetSlot
    local SLOT_COLUMN_WIDTH = SLOT_SIZE + 10
    local PANEL_WIDTH = SLOT_COLUMN_WIDTH + MODEL_WIDTH + SLOT_COLUMN_WIDTH + 40

    local left = CreateFrame("Frame", nil, parent)
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -35)
    left:SetSize(PANEL_WIDTH, self.FRAME_HEIGHT - 80)

    -- Button bar at very top of left panel
    local disableTransmogBtn = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
    disableTransmogBtn:SetSize(110, 20)
    disableTransmogBtn:SetPoint("TOPLEFT", left, "TOPLEFT", 0, 0)
    disableTransmogBtn:SetText("Disable Transmog")
    disableTransmogBtn:SetScript("OnClick", function()
        Wardrobe.transmogDisabled = not Wardrobe.transmogDisabled
        if Wardrobe.transmogDisabled then
            disableTransmogBtn:SetText("Enable Transmog")
            if DC and DC.SendTransmogCommand then
                DC:SendTransmogCommand("DISABLE_ALL")
            end
        else
            disableTransmogBtn:SetText("Disable Transmog")
            if DC and DC.SendTransmogCommand then
                DC:SendTransmogCommand("ENABLE_ALL")
            end
        end
        Wardrobe:UpdateModel()
    end)
    parent.disableTransmogBtn = disableTransmogBtn

    local disableVisualsBtn = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
    disableVisualsBtn:SetSize(120, 20)
    disableVisualsBtn:SetPoint("LEFT", disableTransmogBtn, "RIGHT", 3, 0)
    disableVisualsBtn:SetText("Disable Spell Visuals")
    disableVisualsBtn:SetScript("OnClick", function()
        Wardrobe.spellVisualsDisabled = not Wardrobe.spellVisualsDisabled
        if Wardrobe.spellVisualsDisabled then
            disableVisualsBtn:SetText("Enable Spell Visuals")
        else
            disableVisualsBtn:SetText("Disable Spell Visuals")
        end
        Wardrobe:UpdateModel()
    end)
    parent.disableVisualsBtn = disableVisualsBtn

    local refreshBtn = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
    refreshBtn:SetSize(85, 20)
    refreshBtn:SetPoint("LEFT", disableVisualsBtn, "RIGHT", 3, 0)
    refreshBtn:SetText("Refresh Data")
    refreshBtn:SetScript("OnClick", function(self)
        if Wardrobe.isRefreshing then
            -- Cancel refresh
            Wardrobe:CancelRefresh()
        else
            Wardrobe:RefreshTransmogDefinitions()
        end
    end)
    parent.refreshBtn = refreshBtn
    
    -- Add loading text below buttons
    local refreshStatus = left:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    refreshStatus:SetPoint("TOPLEFT", disableTransmogBtn, "BOTTOMLEFT", 0, -5)
    refreshStatus:SetTextColor(1, 0.82, 0)
    refreshStatus:Hide()
    parent.refreshStatus = refreshStatus

    -- Transmog definitions loading progress bar
    local loadBar = CreateFrame("StatusBar", nil, left)
    loadBar:SetSize(PANEL_WIDTH - 10, 12)
    loadBar:SetPoint("TOPLEFT", refreshStatus, "BOTTOMLEFT", 0, -4)
    loadBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    loadBar:SetMinMaxValues(0, 1)
    loadBar:SetValue(0)
    loadBar:Hide()
    loadBar:SetFrameLevel((left:GetFrameLevel() or 1) + 20)
    parent.loadBar = loadBar

    local loadBarBg = loadBar:CreateTexture(nil, "BACKGROUND")
    loadBarBg:SetAllPoints(loadBar)
    loadBarBg:SetTexture(0, 0, 0, 0.45)
    loadBar.bg = loadBarBg

    local loadText = loadBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    loadText:SetPoint("CENTER", loadBar, "CENTER", 0, 0)
    loadText:SetTextColor(1, 0.82, 0)
    loadText:SetText("")
    parent.loadText = loadText

    -- Center the model between left and right slot columns
    local modelX = SLOT_COLUMN_WIDTH + 10  -- After left slot column
    local modelHeight = 320  -- Slightly smaller model height
    local modelFrame = CreateFrame("Frame", nil, left)
    modelFrame:SetPoint("TOPLEFT", left, "TOPLEFT", modelX, -28)
    modelFrame:SetSize(MODEL_WIDTH, modelHeight)

    local modelTitle = left:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modelTitle:SetPoint("BOTTOM", modelFrame, "TOP", 0, 6)
    modelTitle:SetText("")
    parent.modelTitle = modelTitle

    modelFrame.bg = modelFrame:CreateTexture(nil, "BACKGROUND")
    modelFrame.bg:SetAllPoints()
    modelFrame.bg:SetTexture(0, 0, 0, 0.5)

    local model = CreateFrame("DressUpModel", "DCWardrobeModel", modelFrame)
    model:SetAllPoints()
    model:SetUnit("player")

    model:EnableMouse(true)
    model.rotating = false
    model.rotation = 0
    model.cameraDistance = 1.0
    model.cameraX = 0
    model.cameraY = 0
    model.cameraZ = 0

    -- Mouse rotation (drag)
    model:SetScript("OnMouseDown", function(selfModel, button)
        if button == "LeftButton" then
            selfModel.rotating = true
            selfModel.prevX = GetCursorPosition()
        end
    end)
    model:SetScript("OnMouseUp", function(selfModel)
        selfModel.rotating = false
    end)
    model:SetScript("OnUpdate", function(selfModel)
        if selfModel.rotating then
            local x = GetCursorPosition()
            local rotSpeed = Wardrobe.CAMERA_ROTATION_SPEED or 0.01
            local delta = (x - (selfModel.prevX or x)) * rotSpeed
            selfModel.rotation = (selfModel.rotation or 0) + delta
            selfModel:SetFacing(selfModel.rotation)
            selfModel.prevX = x
        end
    end)

    -- Mouse wheel zoom
    model:SetScript("OnMouseWheel", function(selfModel, delta)
        local step = Wardrobe.CAMERA_ZOOM_STEP or 0.1
        local minZoom = Wardrobe.CAMERA_ZOOM_MIN or 0.3
        local maxZoom = Wardrobe.CAMERA_ZOOM_MAX or 3.0
        selfModel.cameraDistance = math.max(minZoom, math.min(maxZoom, selfModel.cameraDistance - (delta * step)))
        
        if selfModel.SetPosition then
            local x = selfModel.cameraX * selfModel.cameraDistance
            local y = selfModel.cameraY
            local z = selfModel.cameraZ
            selfModel:SetPosition(x, y, z)
        end
    end)

    parent.model = model
    parent.modelFrame = modelFrame

    parent.slotButtons = {}

    -- Calculate vertical positions for slots distributed along model height
    -- Left slots: 7 slots evenly spaced from top to bottom of model
    -- Right slots: 4 slots evenly spaced in the upper portion
    local slotStartY = 0  -- Start at top of model

    for _, slotDef in ipairs(self.EQUIPMENT_SLOTS or {}) do
        local btn = CreateFrame("Button", nil, left)
        btn:SetSize(SLOT_SIZE, SLOT_SIZE)
        btn.slotDef = slotDef

        if slotDef.side == "left" then
            -- Left column: 7 slots distributed vertically along model left edge
            -- Spacing: (modelHeight - SLOT_SIZE) / (7-1) = even distribution
            local spacing = (modelHeight - SLOT_SIZE - 20) / 6
            local yPos = -(slotDef.row - 1) * spacing - 10
            btn:SetPoint("TOPRIGHT", modelFrame, "TOPLEFT", -5, yPos)
        elseif slotDef.side == "right" then
            -- Right column: 4 slots distributed in upper portion of model
            local spacing = (modelHeight - SLOT_SIZE - 20) / 4
            local yPos = -(slotDef.row - 1) * spacing - 10
            btn:SetPoint("TOPLEFT", modelFrame, "TOPRIGHT", 5, yPos)
        elseif slotDef.side == "bottom" then
            -- Weapons: packed together horizontally centered under the model
            local weaponGap = 4  -- Gap between weapon slots
            local totalWidth = (SLOT_SIZE * 3) + (weaponGap * 2)  -- 3 slots + 2 gaps
            local startX = -(totalWidth / 2) + (SLOT_SIZE / 2)  -- Center offset
            if slotDef.key == "MainHandSlot" then
                btn:SetPoint("TOP", modelFrame, "BOTTOM", startX, -8)
            elseif slotDef.key == "SecondaryHandSlot" then
                btn:SetPoint("TOP", modelFrame, "BOTTOM", 0, -8)
            else
                -- Ranged slot
                btn:SetPoint("TOP", modelFrame, "BOTTOM", -startX, -8)
            end
        end

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetPoint("TOPLEFT", 2, -2)
        btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        btn.icon:SetTexture(Wardrobe:GetSlotIcon(slotDef.key))

        btn.highlight = btn:CreateTexture(nil, "OVERLAY")
        btn.highlight:SetAllPoints()
        btn.highlight:SetTexture(1, 0.82, 0, 0.3)
        btn.highlight:Hide()
        
        btn.hoverGlow = btn:CreateTexture(nil, "HIGHLIGHT")
        btn.hoverGlow:SetAllPoints()
        btn.hoverGlow:SetTexture(1, 1, 1, 0.2)
        btn.hoverGlow:SetBlendMode("ADD")

        btn.transmogApplied = btn:CreateTexture(nil, "BORDER")
        btn.transmogApplied:SetPoint("TOPLEFT", -2, 2)
        btn.transmogApplied:SetPoint("BOTTOMRIGHT", 2, -2)
        btn.transmogApplied:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        btn.transmogApplied:SetBlendMode("ADD")
        btn.transmogApplied:SetVertexColor(1, 0.6, 0)
        btn.transmogApplied:Hide()

        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        btn:SetScript("OnClick", function(selfBtn, button)
            if button == "LeftButton" then
                -- Ctrl+Click: Show Wowhead link
                if IsControlKeyDown and IsControlKeyDown() then
                    local invSlotId = GetInventorySlotInfo(slotDef.key)
                    if invSlotId then
                        local itemId = GetInventoryItemID("player", invSlotId)
                        if itemId then
                            local _, itemLink = GetItemInfo(itemId)
                            if itemLink then
                                if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
                                    ChatEdit_InsertLink(itemLink)
                                else
                                    DEFAULT_CHAT_FRAME.editBox:Show()
                                    ChatEdit_InsertLink(itemLink)
                                end
                            end
                        end
                    end
                else
                    -- Regular click: Select slot and update camera
                    Wardrobe:SelectSlot(slotDef)
                end
            elseif button == "RightButton" then
                -- Right-click: Reset transmog for this slot
                Wardrobe:ShowSlotContextMenu(slotDef)
            end
        end)

        btn:SetScript("OnEnter", function(selfBtn)
            GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
            GameTooltip:AddLine(slotDef.label, 1, 1, 1)
            local invSlotId = GetInventorySlotInfo(slotDef.key)
            if invSlotId then
                local itemId = GetInventoryItemID("player", invSlotId)
                if itemId then
                    GameTooltip:SetHyperlink("item:" .. itemId)
                    GameTooltip:AddLine(" ")
                    
                    -- Show transmog status
                    local eqSlot = invSlotId - 1
                    local state = DC.transmogState or {}
                    local applied = state[tostring(eqSlot)] and tonumber(state[tostring(eqSlot)]) ~= 0
                    if applied then
                        GameTooltip:AddLine("Transmogrified", 1, 0.82, 0)
                    end
                else
                    GameTooltip:AddLine("No item equipped", 0.8, 0.8, 0.8)
                end
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to select and preview", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Ctrl+Click to link item", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Right-click for options", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        table.insert(parent.slotButtons, btn)
    end

    parent.leftPanel = left
end

-- ============================================================================
-- RIGHT PANEL
-- ============================================================================

function Wardrobe:CreateRightPanel(parent)
    local GRID_ICON_SIZE = self.GRID_ICON_SIZE
    local GRID_COLS = self.GRID_COLS
    local GRID_ROWS = self.GRID_ROWS
    local ITEMS_PER_PAGE = self.ITEMS_PER_PAGE

    local right = CreateFrame("Frame", nil, parent)
    -- Position right panel after the wider left panel (slots + model + slots)
    right:SetPoint("TOPLEFT", parent, "TOPLEFT", 380, -50)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 70)

    local tabs = {
        { key = "items", label = "Items" },
        { key = "sets", label = "Sets" },
        { key = "community", label = "Community" },
    }

    parent.tabButtons = {}

    for i, tabDef in ipairs(tabs) do
        local tab = CreateFrame("Button", nil, right)
        tab:SetSize(80, 25)
        tab:SetPoint("TOPLEFT", right, "TOPLEFT", (i - 1) * 90, 0)
        tab.key = tabDef.key

        tab.bg = tab:CreateTexture(nil, "BACKGROUND")
        tab.bg:SetAllPoints()
        tab.bg:SetTexture(0.2, 0.2, 0.2, 0.8)

        tab.selected = tab:CreateTexture(nil, "BORDER")
        tab.selected:SetAllPoints()
        tab.selected:SetTexture(1, 0.82, 0, 0.2)
        tab.selected:Hide()

        tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tab.text:SetPoint("CENTER")
        tab.text:SetText(tabDef.label)

        tab:SetScript("OnClick", function()
            Wardrobe:SelectTab(tabDef.key)
        end)

        tab:SetScript("OnEnter", function(selfTab)
            selfTab.bg:SetTexture(0.3, 0.3, 0.3, 0.8)
        end)
        tab:SetScript("OnLeave", function(selfTab)
            selfTab.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
        end)

        table.insert(parent.tabButtons, tab)
    end

    -- Filter controls row (Order By, Filter, Quality dropdown, Search box)
    local filterControlsY = -30  -- Position below tabs
    
    local orderBtn = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    orderBtn:SetSize(70, 22)
    orderBtn:SetPoint("TOPLEFT", right, "TOPLEFT", 0, filterControlsY)
    orderBtn:SetText("Order By")
    orderBtn:SetScript("OnClick", function() end)
    parent.orderBtn = orderBtn

    local filterBtn = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    filterBtn:SetSize(55, 22)
    filterBtn:SetPoint("LEFT", orderBtn, "RIGHT", 5, 0)
    filterBtn:SetText("Filter")
    filterBtn:SetScript("OnClick", function()
        Wardrobe:ShowSlotFilterMenu(filterBtn)
    end)
    parent.filterBtn = filterBtn

    -- Quality filter dropdown
    local qualityDropdown = CreateFrame("Frame", "DCWardrobeQualityDropdown", right, "UIDropDownMenuTemplate")
    qualityDropdown:SetPoint("LEFT", filterBtn, "RIGHT", -5, -2)
    UIDropDownMenu_SetWidth(qualityDropdown, 90)
    
    UIDropDownMenu_Initialize(qualityDropdown, function(self, level)
        for _, qualInfo in ipairs(Wardrobe.QUALITY_FILTERS or {}) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = qualInfo.text
            info.value = qualInfo.id
            info.func = function(btn)
                Wardrobe.selectedQualityFilter = btn.value
                UIDropDownMenu_SetText(qualityDropdown, btn:GetText())
                CloseDropDownMenus()
                Wardrobe:RefreshGrid()
            end
            info.checked = (Wardrobe.selectedQualityFilter == qualInfo.id)
            if qualInfo.color then
                info.colorCode = string.format("|cff%02x%02x%02x", 
                    (qualInfo.color.r or 1) * 255, 
                    (qualInfo.color.g or 1) * 255, 
                    (qualInfo.color.b or 1) * 255)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    Wardrobe.selectedQualityFilter = Wardrobe.selectedQualityFilter or 0
    UIDropDownMenu_SetText(qualityDropdown, "All Qualities")
    parent.qualityDropdown = qualityDropdown

    -- Universal search box (searches name, itemID, and displayID simultaneously)
    local searchBox = CreateFrame("EditBox", "DCWardrobeSearchBox", right, "InputBoxTemplate")
    searchBox:SetSize(130, 20)
    searchBox:SetPoint("LEFT", qualityDropdown, "RIGHT", 10, 2)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)

    local searchIcon = searchBox:CreateTexture(nil, "OVERLAY")
    searchIcon:SetSize(14, 14)
    searchIcon:SetPoint("LEFT", searchBox, "LEFT", -16, 0)
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")

    searchBox:SetScript("OnTextChanged", function(selfBox)
        Wardrobe.searchText = selfBox:GetText() or ""
    end)
    searchBox:SetScript("OnEnterPressed", function(selfBox)
        selfBox:ClearFocus()
        Wardrobe:RefreshGrid()
    end)
    searchBox:SetScript("OnEscapePressed", function(selfBox)
        selfBox:SetText("")
        selfBox:ClearFocus()
        Wardrobe.searchText = ""
        Wardrobe:RefreshGrid()
    end)
    searchBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Universal Search:", 1, 0.82, 0)
        GameTooltip:AddLine("Searches across all fields:", 1, 1, 1)
        GameTooltip:AddLine("• Item Name", 1, 1, 1)
        GameTooltip:AddLine("• Item ID", 1, 1, 1)
        GameTooltip:AddLine("• Display ID", 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Press Enter to search", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    searchBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    parent.searchBox = searchBox

    -- Host for the Community Outfits UI (separate grid + paging)
    local communityHost = CreateFrame("Frame", nil, right)
    communityHost:SetPoint("TOPLEFT", right, "TOPLEFT", 0, filterControlsY)
    communityHost:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 0)
    communityHost:Hide()
    parent.communityHost = communityHost

    -- For the desired Community layout, we use the full right panel for the outfits grid/list.
    parent.communityListHost = communityHost

    -- Slot filter icons (below the filter controls row)
    local slotFilterFrame = CreateFrame("Frame", nil, right)
    slotFilterFrame:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -60)
    slotFilterFrame:SetSize(right:GetWidth(), 32)

    parent.slotFilterButtons = {}
    local filterIconSize = 28

    for i, filter in ipairs(self.SLOT_FILTERS or {}) do
        local btn = CreateFrame("Button", nil, slotFilterFrame)
        btn:SetSize(filterIconSize, filterIconSize)
        btn:SetPoint("LEFT", slotFilterFrame, "LEFT", (i - 1) * (filterIconSize + 4), 0)
        btn.filterDef = filter

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetAllPoints()
        btn.icon:SetTexture(filter.icon)
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        btn.selected = btn:CreateTexture(nil, "OVERLAY")
        btn.selected:SetAllPoints()
        btn.selected:SetTexture(1, 0.82, 0, 0.4)
        btn.selected:Hide()

        btn:SetScript("OnClick", function()
            if Wardrobe.selectedSlotFilter == filter then
                Wardrobe.selectedSlotFilter = nil
                btn.selected:Hide()
            else
                for _, b in ipairs(parent.slotFilterButtons) do
                    b.selected:Hide()
                end
                Wardrobe.selectedSlotFilter = filter
                btn.selected:Show()
            end
            Wardrobe:RefreshGrid()
        end)

        btn:SetScript("OnEnter", function(selfBtn)
            GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Slot Filter", 1, 0.82, 0)

            local invTypes = {}
            for invType in pairs(filter.invTypes or {}) do
                table.insert(invTypes, invType)
            end
            table.sort(invTypes)

            if #invTypes == 0 then
                GameTooltip:AddLine("Misc / Cosmetic", 1, 1, 1)
            else
                for _, invType in ipairs(invTypes) do
                    local label = GetInvTypeLabel(invType)
                    if invType == 0 then label = "Misc / Cosmetic" end
                    GameTooltip:AddLine(string.format("%s", label), 1, 1, 1)
                end
            end

            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        table.insert(parent.slotFilterButtons, btn)
    end

    local collectedFrame = CreateFrame("Frame", nil, right)
    collectedFrame:SetPoint("TOPLEFT", slotFilterFrame, "BOTTOMLEFT", 0, -10)
    collectedFrame:SetSize(right:GetWidth(), 20)

    collectedFrame.bar = CreateFrame("StatusBar", nil, collectedFrame)
    collectedFrame.bar:SetSize(200, 12)
    collectedFrame.bar:SetPoint("LEFT", collectedFrame, "LEFT", 0, 0)
    collectedFrame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    collectedFrame.bar:SetStatusBarColor(0.1, 0.8, 0.1)
    collectedFrame.bar:SetMinMaxValues(0, 1)
    collectedFrame.bar:SetValue(0)

    collectedFrame.bar.bg = collectedFrame.bar:CreateTexture(nil, "BACKGROUND")
    collectedFrame.bar.bg:SetAllPoints()
    collectedFrame.bar.bg:SetTexture(0, 0, 0, 0.5)

    collectedFrame.text = collectedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    collectedFrame.text:SetPoint("LEFT", collectedFrame.bar, "RIGHT", 10, 0)
    collectedFrame.text:SetText("Collected 0 / 0")

    parent.collectedFrame = collectedFrame

    local showUncollectedCheck = CreateFrame("CheckButton", "DCWardrobeShowUncollectedCheck", right, "UICheckButtonTemplate")
    showUncollectedCheck:SetPoint("LEFT", collectedFrame.text, "RIGHT", 18, 0)
    showUncollectedCheck:SetChecked(Wardrobe.showUncollected and true or false)
    if _G["DCWardrobeShowUncollectedCheckText"] then
        _G["DCWardrobeShowUncollectedCheckText"]:SetText("Show uncollected")
    end
    showUncollectedCheck:SetScript("OnClick", function(btn)
        Wardrobe.showUncollected = btn:GetChecked() and true or false
        Wardrobe.currentPage = 1
        Wardrobe:RefreshGrid()
    end)
    parent.showUncollectedCheck = showUncollectedCheck

    -- Create a decorative frame around the grid area (snug fit around the icon grid)
    local gridContainer = CreateFrame("Frame", nil, right)
    gridContainer:SetPoint("TOPLEFT", collectedFrame, "BOTTOMLEFT", 0, -5)

    local gridGap = 8
    local gridPad = 16
    local gridWidth = (GRID_COLS * GRID_ICON_SIZE) + ((GRID_COLS - 1) * gridGap)
    local gridHeight = (GRID_ROWS * GRID_ICON_SIZE) + ((GRID_ROWS - 1) * gridGap)
    gridContainer:SetSize(gridWidth + (gridPad * 2), gridHeight + (gridPad * 2))
    
    -- Add backdrop for visual separation
    gridContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    gridContainer:SetBackdropColor(0, 0, 0, 0)

    ApplyLeaderboardsStyle(gridContainer)
    parent.gridContainer = gridContainer

    local gridFrame = CreateFrame("Frame", nil, gridContainer)
    gridFrame:SetPoint("TOPLEFT", gridContainer, "TOPLEFT", gridPad, -gridPad)
    gridFrame:SetPoint("BOTTOMRIGHT", gridContainer, "BOTTOMRIGHT", -gridPad, gridPad)

    parent.gridButtons = {}

    for i = 1, ITEMS_PER_PAGE do
        local btn = CreateFrame("Button", nil, gridFrame)
        btn:SetSize(GRID_ICON_SIZE, GRID_ICON_SIZE)

        local row = math.floor((i - 1) / GRID_COLS)
        local col = (i - 1) % GRID_COLS
        btn:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", col * (GRID_ICON_SIZE + gridGap), -row * (GRID_ICON_SIZE + gridGap))

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture(0, 0, 0, 0.6)

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetPoint("TOPLEFT", 3, -3)
        btn.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        
        btn.hoverHighlight = btn:CreateTexture(nil, "HIGHLIGHT")
        btn.hoverHighlight:SetAllPoints()
        btn.hoverHighlight:SetTexture(1, 1, 1, 0.3)
        btn.hoverHighlight:SetBlendMode("ADD")

        btn.selected = btn:CreateTexture(nil, "OVERLAY")
        btn.selected:SetPoint("TOPLEFT", -2, 2)
        btn.selected:SetPoint("BOTTOMRIGHT", 2, -2)
        btn.selected:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        btn.selected:SetBlendMode("ADD")
        btn.selected:SetVertexColor(1, 0.82, 0)
        btn.selected:Hide()

        btn.notCollected = btn:CreateTexture(nil, "OVERLAY")
        btn.notCollected:SetAllPoints()
        btn.notCollected:SetTexture(0, 0, 0, 0.6)
        btn.notCollected:Hide()

        btn.wishOverlay = btn:CreateTexture(nil, "OVERLAY")
        btn.wishOverlay:SetAllPoints()
        btn.wishOverlay:SetTexture(1, 0.82, 0, 0.18)
        btn.wishOverlay:Hide()

        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        btn:SetScript("OnClick", function(selfBtn, button)
            if not selfBtn.itemData then return end

            if IsShiftKeyDown and IsShiftKeyDown() then
                local itemId = selfBtn.itemData.itemId
                if not itemId then return end
                if DC and DC.RequestAddWishlist and DC.RequestRemoveWishlist then
                    if Wardrobe:IsWishlistedTransmog(itemId) then
                        DC:RequestRemoveWishlist("transmog", itemId)
                    else
                        DC:RequestAddWishlist("transmog", itemId)
                    end
                end
                return
            end

            if button == "LeftButton" then
                -- Preview on left-click and keep tooltip visible
                if selfBtn.itemData.itemId then
                    selfBtn.keepPreviewOnClick = true
                    Wardrobe:PreviewAppearance(selfBtn.itemData.itemId)
                    -- Keep showing the tooltip preview
                    Wardrobe:ShowTooltipPreview(selfBtn.itemData.itemId)
                end
                -- Note: Don't auto-apply, let user apply manually to avoid confusion
            else
                -- Hide preview on right-click for context menu
                selfBtn.keepPreviewOnClick = false
                Wardrobe:HideTooltipPreview()
                Wardrobe:ShowAppearanceContextMenu(selfBtn.itemData)
            end
        end)

        btn:SetScript("OnEnter", function(selfBtn)
            if not selfBtn.itemData then return end
            
            -- Show tooltip preview
            if selfBtn.itemData.itemId then
                Wardrobe:ShowTooltipPreview(selfBtn.itemData.itemId)
            end
            
            Wardrobe:ShowFixedItemTooltip(selfBtn, selfBtn.itemData.itemId, function(tip)
                tip:AddLine(" ")

                if selfBtn.itemData.displayId then
                    tip:AddLine("DisplayId: " .. tostring(selfBtn.itemData.displayId), 0.85, 0.85, 0.85)
                end

                local ids = selfBtn.itemData.itemIds
                local idsTotal = selfBtn.itemData.itemIdsTotal
                if type(idsTotal) == "string" then idsTotal = tonumber(idsTotal) end
                if type(ids) == "table" and (#ids > 0 or idsTotal) then
                    local shown = {}
                    local maxShow = 10
                    local n = 0
                    for _, v in ipairs(ids) do
                        if n >= maxShow then break end
                        local iv = type(v) == "string" and tonumber(v) or v
                        if iv and not shown[iv] then
                            shown[iv] = true
                            n = n + 1
                        end
                    end

                    local list = {}
                    for iv in pairs(shown) do
                        table.insert(list, iv)
                    end
                    table.sort(list)

                    local line = "Variants: "
                    if #list > 0 then
                        for i = 1, #list do
                            if i > 1 then line = line .. ", " end
                            line = line .. tostring(list[i])
                        end
                    end

                    if idsTotal and idsTotal > #ids then
                        line = line .. string.format(" (+%d more)", (idsTotal - #ids))
                    end
                    tip:AddLine(line, 0.85, 0.85, 0.85)
                end

                if selfBtn.itemData.collected then
                    tip:AddLine("Appearance collected", 0.1, 1, 0.1)
                else
                    if Wardrobe:IsWishlistedTransmog(selfBtn.itemData.itemId) then
                        tip:AddLine("Wishlisted", 1, 0.82, 0)
                    end
                end
                tip:AddLine("Left-click to preview", 0.7, 0.7, 0.7)
                tip:AddLine("Right-click to apply or add to wishlist", 0.7, 0.7, 0.7)
                tip:AddLine("Shift-click to toggle wishlist", 0.7, 0.7, 0.7)
            end)
        end)
        btn:SetScript("OnLeave", function(selfBtn) 
            GameTooltip:Hide() 
            if Wardrobe.HideTooltipPreview then
                -- Don't hide preview if it was clicked (keepPreviewOnClick flag)
                if not selfBtn.keepPreviewOnClick then
                    Wardrobe:HideTooltipPreview()
                end
            end
        end)

        btn:Hide()
        table.insert(parent.gridButtons, btn)
    end

    parent.gridFrame = gridFrame

    local pageFrame = CreateFrame("Frame", nil, right)
    pageFrame:ClearAllPoints()
    pageFrame:SetPoint("TOPLEFT", gridContainer, "BOTTOMLEFT", 0, -8)
    pageFrame:SetSize(260, 25)
    -- Ensure controls draw above the grid background
    pageFrame:SetFrameStrata("HIGH")
    pageFrame:SetFrameLevel(gridContainer:GetFrameLevel() + 10)
    parent.pageFrame = pageFrame

    parent.pageText = pageFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    parent.pageText:SetPoint("CENTER", pageFrame, "CENTER", 0, 0)
    parent.pageText:SetText("Page 1 / 1")

    parent.prevBtn = CreateFrame("Button", nil, pageFrame)
    parent.prevBtn:SetSize(24, 24)
    parent.prevBtn:SetPoint("RIGHT", parent.pageText, "LEFT", -5, 0)
    parent.prevBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    parent.prevBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    parent.prevBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    parent.prevBtn:SetScript("OnClick", function()
        if Wardrobe.currentPage > 1 then
            Wardrobe.currentPage = Wardrobe.currentPage - 1
            if Wardrobe.currentTab == "sets" then
                Wardrobe:RefreshSetsGrid()
            else
                Wardrobe:RefreshGrid()
            end
        end
    end)

    parent.nextBtn = CreateFrame("Button", nil, pageFrame)
    parent.nextBtn:SetSize(24, 24)
    parent.nextBtn:SetPoint("LEFT", parent.pageText, "RIGHT", 5, 0)
    parent.nextBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    parent.nextBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    parent.nextBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    parent.nextBtn:SetScript("OnClick", function()
        if Wardrobe.currentPage < Wardrobe.totalPages then
            Wardrobe.currentPage = Wardrobe.currentPage + 1
            if Wardrobe.currentTab == "sets" then
                Wardrobe:RefreshSetsGrid()
            else
                Wardrobe:RefreshGrid()
            end
        end
    end)

    parent.rightPanel = right
end

-- ============================================================================
-- BOTTOM BAR
-- ============================================================================

function Wardrobe:CreateBottomBar(parent)
    local bottom = CreateFrame("Frame", nil, parent)
    bottom:SetPoint("BOTTOMLEFT", parent.leftPanel, "BOTTOMLEFT", 50, 0)
    bottom:SetSize(self.MODEL_WIDTH, 50)
    
    -- Preview mode slider (Grid vs Full 3D Model)
    local previewModeFrame = CreateFrame("Frame", nil, parent.rightPanel or bottom)
    previewModeFrame:SetSize(150, 20)
    previewModeFrame:ClearAllPoints()
    if parent.gridContainer then
        -- Keep it just below the grid background
        previewModeFrame:SetPoint("TOPRIGHT", parent.gridContainer, "BOTTOMRIGHT", 0, -8)
        previewModeFrame:SetFrameStrata("HIGH")
        previewModeFrame:SetFrameLevel(parent.gridContainer:GetFrameLevel() + 10)
    else
        previewModeFrame:SetPoint("BOTTOM", parent.rightPanel or bottom, "BOTTOM", 0, 5)
    end
    
    previewModeFrame.label = previewModeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewModeFrame.label:SetPoint("LEFT", previewModeFrame, "LEFT", 0, 0)
    previewModeFrame.label:SetText("Preview:")
    
    local slider = CreateFrame("Slider", nil, previewModeFrame)
    slider:SetSize(80, 12)
    slider:SetPoint("LEFT", previewModeFrame.label, "RIGHT", 8, 0)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(0, 1)
    slider:SetValueStep(1)
    slider:SetValue(Wardrobe.previewMode == "grid" and 0 or 1)
    
    slider.bg = slider:CreateTexture(nil, "BACKGROUND")
    slider.bg:SetAllPoints()
    slider.bg:SetTexture(0, 0, 0, 0.5)
    
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    thumb:SetSize(18, 18)
    slider:SetThumbTexture(thumb)
    
    slider.lowText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slider.lowText:SetPoint("LEFT", slider, "LEFT", 0, 0)
    slider.lowText:SetText("Grid")
    slider.lowText:SetTextColor(0.7, 0.7, 0.7)
    
    slider.highText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slider.highText:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    slider.highText:SetText("Full 3D")
    slider.highText:SetTextColor(0.7, 0.7, 0.7)
    
    slider:SetScript("OnValueChanged", function(self, value)
        if value == 0 then
            Wardrobe.previewMode = "grid"
            slider.lowText:SetTextColor(1, 0.82, 0)
            slider.highText:SetTextColor(0.7, 0.7, 0.7)
        else
            Wardrobe.previewMode = "full"
            slider.lowText:SetTextColor(0.7, 0.7, 0.7)
            slider.highText:SetTextColor(1, 0.82, 0)
        end
    end)
    
    slider:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Item Preview Mode", 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click on an item in the grid to preview it.", 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Grid: Zoomed camera on the equipment slot", 0.7, 1, 0.7)
        GameTooltip:AddLine("Full 3D: Full character view with item", 0.7, 1, 0.7)
        GameTooltip:Show()
    end)
    slider:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    parent.previewModeSlider = slider
    parent.previewModeFrame = previewModeFrame
    Wardrobe.previewMode = Wardrobe.previewMode or "full"

    parent.bottomBar = bottom
end

-- ============================================================================
-- TOOLTIP PREVIEW
-- ============================================================================

function Wardrobe:ShowTooltipPreview(itemId)
    if not itemId then return end
    
    -- Create the preview frame if it doesn't exist
    if not self.tooltipPreview then
        local parent = (self.isEmbedded and self.frame and self.frame.previewHost) or self.frame or UIParent
        local frame = CreateFrame("Frame", "DCWardrobeTooltipPreview", parent)
        frame:SetSize(200, 240)  -- Smaller preview
        frame:SetFrameStrata("TOOLTIP")

        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        frame:SetBackdropColor(0, 0, 0, 0)

        ApplyLeaderboardsStyle(frame)

        -- Preview model
        local model = CreateFrame("DressUpModel", nil, frame)
        model:SetPoint("TOPLEFT", 12, -12)
        model:SetPoint("BOTTOMRIGHT", -12, 12)
        model:SetUnit("player")
        model:SetLight(1, 0, 0, 0, -1, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
        
        frame.model = model
        
        self.tooltipPreview = frame
    end
    
    local frame = self.tooltipPreview
    frame:Show()
    
    -- Position near pagination (bottom row)
    frame:ClearAllPoints()
    if self.isEmbedded and self.frame and self.frame.previewHost then
        frame:SetParent(self.frame.previewHost)
        frame:SetPoint("BOTTOMRIGHT", self.frame.previewHost, "BOTTOMRIGHT", -5, 10)
    else
        frame:SetParent(self.frame or UIParent)
        if self.frame and self.frame.pageFrame then
            frame:SetPoint("BOTTOMLEFT", self.frame.pageFrame, "BOTTOMRIGHT", 10, -6)
        else
            frame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -10, 70)
        end
    end
    
    -- Show item on model
    frame.model:Show()
    frame.model:SetUnit("player")
    frame.model:Undress()
    
    -- Try on item with error protection
    pcall(function()
        local link = "item:" .. tostring(itemId) .. ":0:0:0:0:0:0:0"
        frame.model:TryOn(link)
    end)
    
    -- Apply camera based on preview mode
    if self.previewMode == "grid" then
        -- Grid mode: Zoomed view of slot area using CameraDB
        local selectedSlot = self.selectedSlot
        if selectedSlot and selectedSlot.label and type(self.GetCameraPosition) == "function" and type(self.ApplyCameraPosition) == "function" then
            local cameraPos = self:GetCameraPosition(selectedSlot.label)
            if cameraPos then
                self:ApplyCameraPosition(frame.model, cameraPos)
            else
                -- Fallback: zoomed in close-up
                if frame.model.SetPosition then
                    frame.model:SetPosition(0.5, 0, 0)
                end
                frame.model:SetFacing(0)
            end
        else
            -- Fallback to close-up view if no slot selected
            if frame.model.SetPosition then
                frame.model:SetPosition(0.5, 0, 0)
            end
            frame.model:SetFacing(0)
        end
    else
        -- Full 3D mode: Show complete character from distance
        if frame.model.SetPosition then
            frame.model:SetPosition(1.5, 0, 0)
        end
        frame.model:SetFacing(0)
    end
end

function Wardrobe:HideTooltipPreview()
    if self.tooltipPreview then
        self.tooltipPreview:Hide()
    end
end
-- ============================================================================
-- SLOT CONTEXT MENU
-- ============================================================================

function Wardrobe:ShowSlotContextMenu(slotDef)
    if not slotDef then return end
    
    local invSlotId = GetInventorySlotInfo(slotDef.key)
    if not invSlotId then return end
    
    local itemId = GetInventoryItemID("player", invSlotId)
    local eqSlot = invSlotId - 1
    local state = DC.transmogState or {}
    local hasTransmog = state[tostring(eqSlot)] and tonumber(state[tostring(eqSlot)]) ~= 0
    
    local menu = {
        { text = slotDef.label, isTitle = true, notCheckable = true },
    }
    
    if hasTransmog then
        table.insert(menu, {
            text = "Reset Transmog",
            notCheckable = true,
            func = function()
                -- Send reset command to server
                if DC and DC.Protocol and DC.Protocol.RequestTransmogSlotReset then
                    DC.Protocol:RequestTransmogSlotReset(eqSlot)
                end
            end,
        })
    end
    
    if itemId then
        table.insert(menu, {
            text = "Link Item",
            notCheckable = true,
            func = function()
                local _, itemLink = GetItemInfo(itemId)
                if itemLink then
                    if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
                        ChatEdit_InsertLink(itemLink)
                    else
                        DEFAULT_CHAT_FRAME.editBox:Show()
                        ChatEdit_InsertLink(itemLink)
                    end
                end
            end,
        })
    end
    
    table.insert(menu, {
        text = "Reset Camera",
        notCheckable = true,
        func = function()
            if self.frame and self.frame.model then
                self:ResetCameraPosition(self.frame.model)
            end
        end,
    })
    
    table.insert(menu, { text = "Cancel", notCheckable = true })
    
    local dropdown = CreateFrame("Frame", "DCWardrobeSlotContextMenu", UIParent, "UIDropDownMenuTemplate")
    EasyMenu(menu, dropdown, "cursor", 0, 0, "MENU")
end