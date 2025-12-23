--[[
    DC-Collection UI/Wardrobe/WardrobeUI.lua
    =======================================

    Frame creation and static UI layout for Wardrobe.
]]

local DC = DCCollection
if not DC then return end

DC.Wardrobe = DC.Wardrobe or {}
local Wardrobe = DC.Wardrobe

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

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    frame.bg:SetPoint("TOPLEFT", 10, -10)
    frame.bg:SetPoint("BOTTOMRIGHT", -10, 10)
    frame.bg:SetTexture(0, 0, 0, 0.95)

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

    tinsert(UISpecialFrames, "DCWardrobeFrame")

    self:HookItemTooltip()

    self.frame = frame
    return frame
end

-- ============================================================================
-- LEFT PANEL
-- ============================================================================

function Wardrobe:CreateLeftPanel(parent)
    local MODEL_WIDTH = self.MODEL_WIDTH
    local SLOT_SIZE = self.SLOT_SIZE

    local left = CreateFrame("Frame", nil, parent)
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -50)
    left:SetSize(MODEL_WIDTH + 100, self.FRAME_HEIGHT - 120)

    local disableTransmogBtn = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
    disableTransmogBtn:SetSize(130, 22)
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
    disableVisualsBtn:SetSize(140, 22)
    disableVisualsBtn:SetPoint("LEFT", disableTransmogBtn, "RIGHT", 5, 0)
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

    local modelFrame = CreateFrame("Frame", nil, left)
    modelFrame:SetPoint("TOPLEFT", left, "TOPLEFT", 50, -30)
    modelFrame:SetSize(MODEL_WIDTH, 400)

    modelFrame.bg = modelFrame:CreateTexture(nil, "BACKGROUND")
    modelFrame.bg:SetAllPoints()
    modelFrame.bg:SetTexture(0, 0, 0, 0.5)

    local model = CreateFrame("DressUpModel", "DCWardrobeModel", modelFrame)
    model:SetAllPoints()
    model:SetUnit("player")

    model:EnableMouse(true)
    model.rotating = false
    model.rotation = 0

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
            local delta = (x - (selfModel.prevX or x)) * 0.01
            selfModel.rotation = (selfModel.rotation or 0) + delta
            selfModel:SetFacing(selfModel.rotation)
            selfModel.prevX = x
        end
    end)

    parent.model = model
    parent.modelFrame = modelFrame

    parent.slotButtons = {}

    for _, slotDef in ipairs(self.EQUIPMENT_SLOTS or {}) do
        local btn = CreateFrame("Button", nil, left)
        btn:SetSize(SLOT_SIZE, SLOT_SIZE)
        btn.slotDef = slotDef

        if slotDef.side == "left" then
            btn:SetPoint("TOPRIGHT", modelFrame, "TOPLEFT", -5, -(slotDef.row - 1) * (SLOT_SIZE + 5) - 10)
        elseif slotDef.side == "right" then
            btn:SetPoint("TOPLEFT", modelFrame, "TOPRIGHT", 5, -(slotDef.row - 1) * (SLOT_SIZE + 5) - 10)
        elseif slotDef.side == "bottom" then
            btn:SetPoint("TOP", modelFrame, "BOTTOM", (slotDef.row - 2) * (SLOT_SIZE + 5), -5)
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

        btn.transmogApplied = btn:CreateTexture(nil, "BORDER")
        btn.transmogApplied:SetPoint("TOPLEFT", -2, 2)
        btn.transmogApplied:SetPoint("BOTTOMRIGHT", 2, -2)
        btn.transmogApplied:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        btn.transmogApplied:SetBlendMode("ADD")
        btn.transmogApplied:SetVertexColor(1, 0.6, 0)
        btn.transmogApplied:Hide()

        btn:SetScript("OnClick", function()
            Wardrobe:SelectSlot(slotDef)
        end)

        btn:SetScript("OnEnter", function(selfBtn)
            GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
            GameTooltip:AddLine(slotDef.label)
            local invSlotId = GetInventorySlotInfo(slotDef.key)
            if invSlotId then
                local itemId = GetInventoryItemID("player", invSlotId)
                if itemId then
                    GameTooltip:SetHyperlink("item:" .. itemId)
                end
            end
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
    right:SetPoint("TOPLEFT", parent, "TOPLEFT", self.MODEL_WIDTH + 170, -50)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 70)

    local tabs = {
        { key = "items", label = "Items" },
        { key = "sets", label = "Sets" },
        { key = "outfits", label = "Outfits" },
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

    local searchBox = CreateFrame("EditBox", "DCWardrobeSearchBox", right, "InputBoxTemplate")
    searchBox:SetSize(150, 20)
    searchBox:SetPoint("TOPRIGHT", right, "TOPRIGHT", -10, -35)
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
    parent.searchBox = searchBox

    local filterBtn = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    filterBtn:SetSize(60, 20)
    filterBtn:SetPoint("RIGHT", searchBox, "LEFT", -5, 0)
    filterBtn:SetText("Filter")
    filterBtn:SetScript("OnClick", function() end)
    parent.filterBtn = filterBtn

    local orderBtn = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    orderBtn:SetSize(70, 20)
    orderBtn:SetPoint("RIGHT", filterBtn, "LEFT", -5, 0)
    orderBtn:SetText("Order By")
    orderBtn:SetScript("OnClick", function() end)
    parent.orderBtn = orderBtn

    local slotFilterFrame = CreateFrame("Frame", nil, right)
    slotFilterFrame:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -65)
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

    local gridFrame = CreateFrame("Frame", nil, right)
    gridFrame:SetPoint("TOPLEFT", collectedFrame, "BOTTOMLEFT", 0, -10)
    gridFrame:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 40)

    parent.gridButtons = {}

    for i = 1, ITEMS_PER_PAGE do
        local btn = CreateFrame("Button", nil, gridFrame)
        btn:SetSize(GRID_ICON_SIZE, GRID_ICON_SIZE)

        local row = math.floor((i - 1) / GRID_COLS)
        local col = (i - 1) % GRID_COLS
        btn:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", col * (GRID_ICON_SIZE + 8), -row * (GRID_ICON_SIZE + 8))

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture(0, 0, 0, 0.6)

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetPoint("TOPLEFT", 3, -3)
        btn.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

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
                if selfBtn.itemData.collected then
                    Wardrobe:ApplyAppearance(selfBtn.itemData.itemId)
                else
                    if DC and DC.Print then
                        DC:Print("This appearance is not collected. Shift-click to wishlist it.")
                    end
                end
            else
                Wardrobe:PreviewAppearance(selfBtn.itemData.itemId)
            end
        end)

        btn:SetScript("OnEnter", function(selfBtn)
            if not selfBtn.itemData then return end
            GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
            if selfBtn.itemData.itemId then
                GameTooltip:SetHyperlink("item:" .. selfBtn.itemData.itemId)
            end
            GameTooltip:AddLine(" ")
            if selfBtn.itemData.collected then
                GameTooltip:AddLine("You've collected this appearance", 0.1, 1, 0.1)
            else
                if Wardrobe:IsWishlistedTransmog(selfBtn.itemData.itemId) then
                    GameTooltip:AddLine("Wishlisted", 1, 0.82, 0)
                end
            end
            GameTooltip:AddLine("Left-click to apply", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Right-click to preview", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Shift-click to toggle wishlist", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        btn:Hide()
        table.insert(parent.gridButtons, btn)
    end

    parent.gridFrame = gridFrame

    local pageFrame = CreateFrame("Frame", nil, right)
    pageFrame:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 0)
    pageFrame:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 0)
    pageFrame:SetHeight(30)

    parent.pageText = pageFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    parent.pageText:SetPoint("CENTER", pageFrame, "CENTER", 0, 0)
    parent.pageText:SetText("Page 1 / 1")

    parent.prevBtn = CreateFrame("Button", nil, pageFrame)
    parent.prevBtn:SetSize(24, 24)
    parent.prevBtn:SetPoint("RIGHT", parent.pageText, "LEFT", -20, 0)
    parent.prevBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    parent.prevBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    parent.prevBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    parent.prevBtn:SetScript("OnClick", function()
        if Wardrobe.currentTab == "outfits" then
            return
        end
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
    parent.nextBtn:SetPoint("LEFT", parent.pageText, "RIGHT", 20, 0)
    parent.nextBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    parent.nextBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    parent.nextBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    parent.nextBtn:SetScript("OnClick", function()
        if Wardrobe.currentTab == "outfits" then
            return
        end
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

    local saveBtn = CreateFrame("Button", nil, bottom, "UIPanelButtonTemplate")
    saveBtn:SetSize(100, 24)
    saveBtn:SetPoint("TOPLEFT", bottom, "TOPLEFT", 0, 0)
    saveBtn:SetText("Save Outfit")
    saveBtn:SetScript("OnClick", function()
        Wardrobe:ShowSaveOutfitDialog()
    end)
    parent.saveOutfitBtn = saveBtn

    parent.outfitSlots = {}

    for i = 1, 3 do
        local slot = CreateFrame("Button", nil, bottom)
        slot:SetSize(40, 40)
        slot:SetPoint("LEFT", saveBtn, "RIGHT", 10 + (i - 1) * 45, 0)
        slot.index = i

        slot.bg = slot:CreateTexture(nil, "BACKGROUND")
        slot.bg:SetAllPoints()
        slot.bg:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")

        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetPoint("TOPLEFT", 2, -2)
        slot.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        slot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        slot.icon:Hide()

        slot:SetScript("OnClick", function(selfSlot)
            Wardrobe:LoadOutfit(selfSlot.index)
        end)

        slot:SetScript("OnEnter", function(selfSlot)
            GameTooltip:SetOwner(selfSlot, "ANCHOR_TOP")
            local outfits = DC.db and DC.db.outfits or {}
            local outfit = outfits[selfSlot.index]
            if outfit and outfit.name then
                GameTooltip:AddLine(outfit.name)
                GameTooltip:AddLine("Click to apply", 0.7, 0.7, 0.7)
            else
                GameTooltip:AddLine("Empty Slot")
                GameTooltip:AddLine("Save an outfit to use this slot", 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end)
        slot:SetScript("OnLeave", function() GameTooltip:Hide() end)

        table.insert(parent.outfitSlots, slot)
    end

    parent.bottomBar = bottom
end
