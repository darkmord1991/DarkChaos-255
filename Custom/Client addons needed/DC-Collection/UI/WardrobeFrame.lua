--[[
    DC-Collection UI/WardrobeFrame.lua
    ==================================

    Ascension-style Wardrobe UI for transmog system.
    
    Layout:
    - Left: Full character model with paper-doll equipment slots
    - Right: Tab bar (Items, Sets, Outfits), slot filters, search, appearance grid
    - Bottom: Outfit quick slots, pagination
    
    Author: DarkChaos-255
    Version: 2.0.0
]]

local DC = DCCollection
local L = DC and DC.L or {}

local Wardrobe = {}
DC.Wardrobe = Wardrobe

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local FRAME_WIDTH = 1000
local FRAME_HEIGHT = 650
local MODEL_WIDTH = 250
local SLOT_SIZE = 36
local GRID_ICON_SIZE = 46
local GRID_COLS = 8 -- Increased columns
local GRID_ROWS = 4
local ITEMS_PER_PAGE = GRID_COLS * GRID_ROWS

-- Equipment slot definitions with positions relative to model frame
local EQUIPMENT_SLOTS = {
    -- Left column (top to bottom)
    { key = "HeadSlot",      label = "Head",      invType = 1,  side = "left",  row = 1 },
    { key = "ShoulderSlot",  label = "Shoulder",  invType = 3,  side = "left",  row = 2 },
    { key = "BackSlot",      label = "Back",      invType = 16, side = "left",  row = 3 },
    { key = "ChestSlot",     label = "Chest",     invType = 5,  side = "left",  row = 4 },
    { key = "ShirtSlot",     label = "Shirt",     invType = 4,  side = "left",  row = 5 },
    { key = "TabardSlot",    label = "Tabard",    invType = 19, side = "left",  row = 6 },
    { key = "WristSlot",     label = "Wrist",     invType = 9,  side = "left",  row = 7 },
    
    -- Right column (top to bottom)
    { key = "HandsSlot",     label = "Hands",     invType = 10, side = "right", row = 1 },
    { key = "WaistSlot",     label = "Waist",     invType = 6,  side = "right", row = 2 },
    { key = "LegsSlot",      label = "Legs",      invType = 7,  side = "right", row = 3 },
    { key = "FeetSlot",      label = "Feet",      invType = 8,  side = "right", row = 4 },
    
    -- Bottom (weapons)
    { key = "MainHandSlot",      label = "Main Hand", invType = 13, side = "bottom", row = 1 },
    { key = "SecondaryHandSlot", label = "Off Hand",  invType = 14, side = "bottom", row = 2 },
    { key = "RangedSlot",        label = "Ranged",    invType = 15, side = "bottom", row = 3 },
}

-- Slot filter icons (for the filter bar)
local SLOT_FILTERS = {
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Head",     invTypes = { [1] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shoulder", invTypes = { [3] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",    invTypes = { [5] = true, [20] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shirt",    invTypes = { [4] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Tabard",   invTypes = { [19] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Wrists",   invTypes = { [9] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Hands",    invTypes = { [10] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Waist",    invTypes = { [6] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Legs",     invTypes = { [7] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Feet",     invTypes = { [8] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",    invTypes = { [16] = true } }, -- Back uses chest icon
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand", invTypes = { [13] = true, [17] = true, [21] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand", invTypes = { [14] = true, [22] = true, [23] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ranged",   invTypes = { [15] = true, [25] = true, [26] = true } },
}

-- Visual slot mapping for server communication
local VISUAL_SLOTS = {
    HeadSlot = 283,
    ShoulderSlot = 287,
    ShirtSlot = 289,
    ChestSlot = 291,
    WaistSlot = 293,
    LegsSlot = 295,
    FeetSlot = 297,
    WristSlot = 299,
    HandsSlot = 301,
    BackSlot = 311,
    MainHandSlot = 313,
    SecondaryHandSlot = 315,
    RangedSlot = 317,
    TabardSlot = 319,
}

-- ============================================================================
-- STATE
-- ============================================================================

Wardrobe.currentTab = "items"  -- "items", "sets", "outfits"
Wardrobe.selectedSlot = nil
Wardrobe.selectedSlotFilter = nil
Wardrobe.currentPage = 1
Wardrobe.totalPages = 1
Wardrobe.searchText = ""
Wardrobe.appearanceList = {}
Wardrobe.collectedCount = 0
Wardrobe.totalCount = 0
Wardrobe.transmogDisabled = false
Wardrobe.spellVisualsDisabled = false

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function SafeGetText(key, fallback)
    if L and L[key] and L[key] ~= "" then
        return L[key]
    end
    return fallback
end

local function GetSlotIcon(slotKey)
    local invSlotId = GetInventorySlotInfo(slotKey)
    if invSlotId then
        local itemId = GetInventoryItemID("player", invSlotId)
        if itemId then
            local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemId)
            if texture then
                return texture
            end
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function IsAppearanceCollected(itemId)
    if not DC or not DC.collections or not DC.collections.transmog then
        return false
    end
    return DC.collections.transmog[itemId] ~= nil
end

-- ============================================================================
-- TOOLTIP HOOK - "You've collected this appearance"
-- ============================================================================

local function HookItemTooltip()
    if Wardrobe.tooltipHooked then return end
    
    local function AddCollectedLine(tooltip, itemId)
        if not itemId or itemId == 0 then return end
        
        if IsAppearanceCollected(itemId) then
            tooltip:AddLine(" ")
            tooltip:AddLine("You've collected this appearance", 0.1, 1, 0.1)
            tooltip:Show()
        end
    end
    
    -- Hook GameTooltip
    GameTooltip:HookScript("OnTooltipSetItem", function(self)
        local _, itemLink = self:GetItem()
        if itemLink then
            local itemId = tonumber(string.match(itemLink, "item:(%d+)"))
            AddCollectedLine(self, itemId)
        end
    end)
    
    -- Hook ItemRefTooltip
    if ItemRefTooltip then
        ItemRefTooltip:HookScript("OnTooltipSetItem", function(self)
            local _, itemLink = self:GetItem()
            if itemLink then
                local itemId = tonumber(string.match(itemLink, "item:(%d+)"))
                AddCollectedLine(self, itemId)
            end
        end)
    end
    
    Wardrobe.tooltipHooked = true
end

-- ============================================================================
-- FRAME CREATION
-- ============================================================================

function Wardrobe:CreateFrame()
    if self.frame then
        return self.frame
    end
    
    -- Main frame
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
    
    -- Premium Black Background
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    
    -- Inner Black Background (to ensure it's very dark)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    frame.bg:SetPoint("TOPLEFT", 10, -10)
    frame.bg:SetPoint("BOTTOMRIGHT", -10, 10)
    frame.bg:SetTexture(0, 0, 0, 0.95)
    
    -- Portrait
    frame.portrait = frame:CreateTexture(nil, "ARTWORK")
    frame.portrait:SetSize(60, 60)
    frame.portrait:SetPoint("TOPLEFT", -5, 7)
    frame.portrait:SetTexture("Interface\\Icons\\INV_Chest_Cloth_17")
    
    frame.portraitBorder = frame:CreateTexture(nil, "OVERLAY")
    frame.portraitBorder:SetSize(80, 80)
    frame.portraitBorder:SetPoint("TOPLEFT", -14, 14)
    frame.portraitBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    
    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -12)
    frame.title:SetText("Wardrobe")
    
    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
    frame.closeBtn:SetScript("OnClick", function() Wardrobe:Hide() end)
    
    -- Back Button (to Main Collection)
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
    
    -- Create sub-sections
    self:CreateLeftPanel(frame)
    self:CreateRightPanel(frame)
    self:CreateBottomBar(frame)
    
    -- ESC to close
    tinsert(UISpecialFrames, "DCWardrobeFrame")
    
    -- Hook tooltips
    HookItemTooltip()
    
    self.frame = frame
    return frame
end

-- ============================================================================
-- LEFT PANEL - Character Model + Equipment Slots
-- ============================================================================

function Wardrobe:CreateLeftPanel(parent)
    local left = CreateFrame("Frame", nil, parent)
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -50)
    left:SetSize(MODEL_WIDTH + 100, FRAME_HEIGHT - 120)
    
    -- Top buttons: Disable Transmog / Disable Spell Visuals
    local disableTransmogBtn = CreateFrame("Button", nil, left, "UIPanelButtonTemplate")
    disableTransmogBtn:SetSize(130, 22)
    disableTransmogBtn:SetPoint("TOPLEFT", left, "TOPLEFT", 0, 0)
    disableTransmogBtn:SetText("Disable Transmog")
    disableTransmogBtn:SetScript("OnClick", function()
        Wardrobe.transmogDisabled = not Wardrobe.transmogDisabled
        if Wardrobe.transmogDisabled then
            disableTransmogBtn:SetText("Enable Transmog")
            -- Send command to server to hide all transmogs
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
    
    -- Character Model
    local modelFrame = CreateFrame("Frame", nil, left)
    modelFrame:SetPoint("TOPLEFT", left, "TOPLEFT", 50, -30)
    modelFrame:SetSize(MODEL_WIDTH, 400)
    
    modelFrame.bg = modelFrame:CreateTexture(nil, "BACKGROUND")
    modelFrame.bg:SetAllPoints()
    modelFrame.bg:SetTexture(0, 0, 0, 0.5)
    
    local model = CreateFrame("DressUpModel", "DCWardrobeModel", modelFrame)
    model:SetAllPoints()
    model:SetUnit("player")
    
    -- Mouse rotation
    model:EnableMouse(true)
    model.rotating = false
    model.rotation = 0
    
    model:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.rotating = true
            self.prevX = GetCursorPosition()
        end
    end)
    model:SetScript("OnMouseUp", function(self)
        self.rotating = false
    end)
    model:SetScript("OnUpdate", function(self)
        if self.rotating then
            local x = GetCursorPosition()
            local delta = (x - (self.prevX or x)) * 0.01
            self.rotation = (self.rotation or 0) + delta
            self:SetFacing(self.rotation)
            self.prevX = x
        end
    end)
    
    parent.model = model
    parent.modelFrame = modelFrame
    
    -- Equipment Slots (paper-doll style around model)
    parent.slotButtons = {}
    
    for _, slotDef in ipairs(EQUIPMENT_SLOTS) do
        local btn = CreateFrame("Button", nil, left)
        btn:SetSize(SLOT_SIZE, SLOT_SIZE)
        btn.slotDef = slotDef
        
        -- Position based on side
        if slotDef.side == "left" then
            btn:SetPoint("TOPRIGHT", modelFrame, "TOPLEFT", -5, -(slotDef.row - 1) * (SLOT_SIZE + 5) - 10)
        elseif slotDef.side == "right" then
            btn:SetPoint("TOPLEFT", modelFrame, "TOPRIGHT", 5, -(slotDef.row - 1) * (SLOT_SIZE + 5) - 10)
        elseif slotDef.side == "bottom" then
            btn:SetPoint("TOP", modelFrame, "BOTTOM", (slotDef.row - 2) * (SLOT_SIZE + 5), -5)
        end
        
        -- Background
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        
        -- Icon
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetPoint("TOPLEFT", 2, -2)
        btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        btn.icon:SetTexture(GetSlotIcon(slotDef.key))
        
        -- Selection highlight
        btn.highlight = btn:CreateTexture(nil, "OVERLAY")
        btn.highlight:SetAllPoints()
        btn.highlight:SetTexture(1, 0.82, 0, 0.3)
        btn.highlight:Hide()
        
        -- Transmog applied indicator (golden border)
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
        
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
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
-- RIGHT PANEL - Tabs, Search, Filters, Grid
-- ============================================================================

function Wardrobe:CreateRightPanel(parent)
    local right = CreateFrame("Frame", nil, parent)
    right:SetPoint("TOPLEFT", parent, "TOPLEFT", MODEL_WIDTH + 170, -50)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 70)
    
    -- Tab bar: Items, Sets, Outfits
    local tabs = {
        { key = "items",   text = "Items" },
        { key = "sets",    text = "Sets" },
        { key = "outfits", text = "Outfits" },
    }
    
    parent.tabButtons = {}
    local tabWidth = 80
    
    for i, tabDef in ipairs(tabs) do
        local tab = CreateFrame("Button", nil, right)
        tab:SetSize(tabWidth, 24)
        tab:SetPoint("TOPLEFT", right, "TOPLEFT", (i - 1) * (tabWidth + 5), 0)
        tab.key = tabDef.key
        
        tab.bg = tab:CreateTexture(nil, "BACKGROUND")
        tab.bg:SetAllPoints()
        tab.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
        
        tab.selected = tab:CreateTexture(nil, "BACKGROUND")
        tab.selected:SetAllPoints()
        tab.selected:SetTexture(0.4, 0.35, 0.2, 0.9)
        tab.selected:Hide()
        
        tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tab.text:SetPoint("CENTER")
        tab.text:SetText(tabDef.text)
        
        tab:SetScript("OnClick", function()
            Wardrobe:SelectTab(tabDef.key)
        end)
        
        tab:SetScript("OnEnter", function(self)
            self.bg:SetTexture(0.3, 0.3, 0.3, 0.8)
        end)
        tab:SetScript("OnLeave", function(self)
            self.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
        end)
        
        table.insert(parent.tabButtons, tab)
    end
    
    -- Search box
    local searchBox = CreateFrame("EditBox", "DCWardrobeSearchBox", right, "InputBoxTemplate")
    searchBox:SetSize(150, 20)
    searchBox:SetPoint("TOPRIGHT", right, "TOPRIGHT", -10, -35) -- Moved down to avoid tab collision
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)
    
    local searchIcon = searchBox:CreateTexture(nil, "OVERLAY")
    searchIcon:SetSize(14, 14)
    searchIcon:SetPoint("LEFT", searchBox, "LEFT", -16, 0)
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    
    searchBox:SetScript("OnTextChanged", function(self)
        Wardrobe.searchText = self:GetText() or ""
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        Wardrobe:RefreshGrid()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        Wardrobe.searchText = ""
        Wardrobe:RefreshGrid()
    end)
    parent.searchBox = searchBox
    
    -- Filter dropdown
    local filterBtn = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    filterBtn:SetSize(60, 20)
    filterBtn:SetPoint("RIGHT", searchBox, "LEFT", -5, 0)
    filterBtn:SetText("Filter")
    filterBtn:SetScript("OnClick", function()
        -- Toggle filter dropdown (TODO: implement dropdown)
    end)
    parent.filterBtn = filterBtn
    
    -- Order By dropdown
    local orderBtn = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    orderBtn:SetSize(70, 20)
    orderBtn:SetPoint("RIGHT", filterBtn, "LEFT", -5, 0)
    orderBtn:SetText("Order By")
    orderBtn:SetScript("OnClick", function()
        -- Toggle order dropdown (TODO: implement dropdown)
    end)
    parent.orderBtn = orderBtn
    
    -- Slot filter icons row
    local slotFilterFrame = CreateFrame("Frame", nil, right)
    slotFilterFrame:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -65) -- Moved down below search bar
    slotFilterFrame:SetSize(right:GetWidth(), 32)
    
    parent.slotFilterButtons = {}
    local filterIconSize = 28
    
    for i, filter in ipairs(SLOT_FILTERS) do
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
                -- Deselect all
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
    
    -- Collected counter and progress bar
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
    
    -- Appearance grid
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
        
        -- Background
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture(0, 0, 0, 0.6)
        
        -- Icon
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetPoint("TOPLEFT", 3, -3)
        btn.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        
        -- Selection border
        btn.selected = btn:CreateTexture(nil, "OVERLAY")
        btn.selected:SetPoint("TOPLEFT", -2, 2)
        btn.selected:SetPoint("BOTTOMRIGHT", 2, -2)
        btn.selected:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        btn.selected:SetBlendMode("ADD")
        btn.selected:SetVertexColor(1, 0.82, 0)
        btn.selected:Hide()
        
        -- Not collected overlay
        btn.notCollected = btn:CreateTexture(nil, "OVERLAY")
        btn.notCollected:SetAllPoints()
        btn.notCollected:SetTexture(0, 0, 0, 0.6)
        btn.notCollected:Hide()
        
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
        btn:SetScript("OnClick", function(self, button)
            if not self.itemData then return end
            
            if button == "LeftButton" then
                -- Apply transmog
                Wardrobe:ApplyAppearance(self.itemData.itemId)
            else
                -- Preview
                Wardrobe:PreviewAppearance(self.itemData.itemId)
            end
        end)
        
        btn:SetScript("OnEnter", function(self)
            if not self.itemData then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.itemData.itemId then
                GameTooltip:SetHyperlink("item:" .. self.itemData.itemId)
            end
            GameTooltip:AddLine(" ")
            if self.itemData.collected then
                GameTooltip:AddLine("You've collected this appearance", 0.1, 1, 0.1)
            end
            GameTooltip:AddLine("Left-click to apply", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Right-click to preview", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        btn:Hide()
        table.insert(parent.gridButtons, btn)
    end
    
    parent.gridFrame = gridFrame
    
    -- Pagination
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
        if Wardrobe.currentPage > 1 then
            Wardrobe.currentPage = Wardrobe.currentPage - 1
            Wardrobe:RefreshGrid()
        end
    end)
    
    parent.nextBtn = CreateFrame("Button", nil, pageFrame)
    parent.nextBtn:SetSize(24, 24)
    parent.nextBtn:SetPoint("LEFT", parent.pageText, "RIGHT", 20, 0)
    parent.nextBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    parent.nextBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    parent.nextBtn:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    parent.nextBtn:SetScript("OnClick", function()
        if Wardrobe.currentPage < Wardrobe.totalPages then
            Wardrobe.currentPage = Wardrobe.currentPage + 1
            Wardrobe:RefreshGrid()
        end
    end)
    
    parent.rightPanel = right
end

-- ============================================================================
-- BOTTOM BAR - Outfit Quick Slots
-- ============================================================================

function Wardrobe:CreateBottomBar(parent)
    local bottom = CreateFrame("Frame", nil, parent)
    bottom:SetPoint("BOTTOMLEFT", parent.leftPanel, "BOTTOMLEFT", 50, 0)
    bottom:SetSize(MODEL_WIDTH, 50)
    
    -- Save Outfit button
    local saveBtn = CreateFrame("Button", nil, bottom, "UIPanelButtonTemplate")
    saveBtn:SetSize(100, 24)
    saveBtn:SetPoint("TOPLEFT", bottom, "TOPLEFT", 0, 0)
    saveBtn:SetText("Save Outfit")
    saveBtn:SetScript("OnClick", function()
        Wardrobe:ShowSaveOutfitDialog()
    end)
    parent.saveOutfitBtn = saveBtn
    
    -- Outfit quick slots (3 slots like in image)
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
        
        slot:SetScript("OnClick", function(self)
            Wardrobe:LoadOutfit(self.index)
        end)
        
        slot:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            local outfits = DC.db and DC.db.outfits or {}
            local outfit = outfits[self.index]
            if outfit and outfit.name then
                GameTooltip:AddLine(outfit.name)
                GameTooltip:AddLine("Click to apply", 0.7, 0.7, 0.7)
            else
                GameTooltip:AddLine("Empty Slot")
                GameTooltip:AddLine("Save an outfit to use this slot", 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end)
        slot:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        table.insert(parent.outfitSlots, slot)
    end
    
    parent.bottomBar = bottom
end

-- ============================================================================
-- TAB SWITCHING
-- ============================================================================

function Wardrobe:SelectTab(tabKey)
    self.currentTab = tabKey
    self.currentPage = 1
    
    -- Update tab visuals
    if self.frame and self.frame.tabButtons then
        for _, tab in ipairs(self.frame.tabButtons) do
            if tab.key == tabKey then
                tab.selected:Show()
                tab.text:SetTextColor(1, 0.82, 0)
            else
                tab.selected:Hide()
                tab.text:SetTextColor(1, 1, 1)
            end
        end
    end
    
    -- Show/hide appropriate content
    if tabKey == "items" then
        self:ShowItemsContent()
    elseif tabKey == "sets" then
        self:ShowSetsContent()
    elseif tabKey == "outfits" then
        self:ShowOutfitsContent()
    end
end

function Wardrobe:ShowItemsContent()
    -- Show slot filters and grid
    if self.frame then
        for _, btn in ipairs(self.frame.slotFilterButtons or {}) do
            btn:Show()
        end
        if self.frame.collectedFrame then
            self.frame.collectedFrame:Show()
        end
        if self.frame.gridFrame then
            self.frame.gridFrame:Show()
        end
    end
    self:RefreshGrid()
end

function Wardrobe:ShowSetsContent()
    -- Sets view - could show predefined armor sets
    if self.frame then
        for _, btn in ipairs(self.frame.slotFilterButtons or {}) do
            btn:Hide()
        end
    end
    self:RefreshSetsGrid()
end

function Wardrobe:ShowOutfitsContent()
    -- Outfits view - saved player outfits
    if self.frame then
        for _, btn in ipairs(self.frame.slotFilterButtons or {}) do
            btn:Hide()
        end
    end
    self:RefreshOutfitsGrid()
end

-- ============================================================================
-- SLOT SELECTION
-- ============================================================================

function Wardrobe:SelectSlot(slotDef)
    self.selectedSlot = slotDef
    self.currentPage = 1
    
    -- Update slot button visuals
    if self.frame and self.frame.slotButtons then
        for _, btn in ipairs(self.frame.slotButtons) do
            if btn.slotDef == slotDef then
                btn.highlight:Show()
            else
                btn.highlight:Hide()
            end
        end
    end
    
    -- Set corresponding slot filter
    for i, filter in ipairs(SLOT_FILTERS) do
        if filter.invTypes[slotDef.invType] then
            self.selectedSlotFilter = filter
            if self.frame and self.frame.slotFilterButtons then
                for j, btn in ipairs(self.frame.slotFilterButtons) do
                    if j == i then
                        btn.selected:Show()
                    else
                        btn.selected:Hide()
                    end
                end
            end
            break
        end
    end
    
    self:RefreshGrid()
end

-- ============================================================================
-- GRID REFRESH
-- ============================================================================

function Wardrobe:RefreshGrid()
    if not self.frame then return end
    
    -- Build filtered list
    local list = self:BuildAppearanceList()
    self.appearanceList = list
    
    -- Calculate pages
    local total = #list
    self.totalPages = math.max(1, math.ceil(total / ITEMS_PER_PAGE))
    if self.currentPage > self.totalPages then
        self.currentPage = self.totalPages
    end
    
    -- Update collected counter
    local collected = 0
    for _, item in ipairs(list) do
        if item.collected then
            collected = collected + 1
        end
    end
    self.collectedCount = collected
    self.totalCount = total
    
    if self.frame.collectedFrame then
        self.frame.collectedFrame.text:SetText(string.format("Collected %d / %d", collected, total))
        local pct = total > 0 and (collected / total) or 0
        self.frame.collectedFrame.bar:SetValue(pct)
    end
    
    -- Update page text
    if self.frame.pageText then
        self.frame.pageText:SetText(string.format("Page %d / %d", self.currentPage, self.totalPages))
    end
    
    -- Update pagination buttons
    if self.frame.prevBtn then
        if self.currentPage > 1 then
            self.frame.prevBtn:Enable()
        else
            self.frame.prevBtn:Disable()
        end
    end
    if self.frame.nextBtn then
        if self.currentPage < self.totalPages then
            self.frame.nextBtn:Enable()
        else
            self.frame.nextBtn:Disable()
        end
    end
    
    -- Fill grid buttons
    local startIdx = (self.currentPage - 1) * ITEMS_PER_PAGE + 1
    
    for i, btn in ipairs(self.frame.gridButtons) do
        local idx = startIdx + (i - 1)
        local item = list[idx]
        
        if item then
            btn:Show()
            btn.itemData = item
            
            local icon = nil
            -- Try GetItemIcon (custom API) first
            if type(GetItemIcon) == "function" and item.itemId then
                icon = GetItemIcon(item.itemId)
            end
            -- Fallback to GetItemInfo
            if not icon and item.itemId and GetItemInfo then
                icon = select(10, GetItemInfo(item.itemId))
            end
            
            btn.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            
            if item.collected then
                btn.icon:SetVertexColor(1, 1, 1)
                btn.notCollected:Hide()
            else
                btn.icon:SetVertexColor(0.4, 0.4, 0.4)
                btn.notCollected:Show()
            end
        else
            btn:Hide()
            btn.itemData = nil
        end
    end
end
function Wardrobe:BuildAppearanceList()
    local results = {}
    local defs = DC.definitions.wardrobe or {}
    local col = DC.collections.wardrobe or {}
    
    local seenDisplayIds = {} -- Deduplication
    local search = self.searchText
    if search and search ~= "" then
        search = string.lower(search)
    else
        search = nil
    end
    
    for id, def in pairs(defs) do
        local valid = true
        
        -- Filter by slot
        if self.selectedSlotFilter then
            local invType = def.inventoryType or 0
            if not self.selectedSlotFilter.invTypes[invType] then
                valid = false
            end
        end
        
        -- Filter by search
        if valid and search then
            local name = def.name or ""
            if not string.find(string.lower(name), search, 1, true) then
                valid = false
            end
        end
        
        if valid then
            -- Deduplicate by displayId if available, otherwise by name
            local displayId = def.displayId or def.display_id
            local key = displayId or def.name
            
            if not seenDisplayIds[key] then
                seenDisplayIds[key] = true
                
                local collected = col[id] ~= nil
                table.insert(results, {
                    id = id,
                    itemId = def.itemId or id,
                    name = def.name or "",
                    collected = collected,
                    inventoryType = def.inventoryType or 0,
                    displayId = displayId,
                })
            end
        end
    end
    
    -- Sort: collected first, then by name
    table.sort(results, function(a, b)
        if a.collected and not b.collected then return true end
        if b.collected and not a.collected then return false end
        return (a.name or "") < (b.name or "")
    end)
    
    return results
end

function Wardrobe:RefreshSetsGrid()
    if not self.frame then return end
    
    -- Hide item grid buttons
    for _, btn in ipairs(self.frame.gridButtons) do
        btn:Hide()
    end
    
    -- Get sets
    local sets = DC.definitions and DC.definitions.itemSets or {}
    local list = {}
    for id, set in pairs(sets) do
        table.insert(list, set)
    end
    table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
    
    -- Display sets (using grid buttons for now, maybe need different template)
    local startIdx = (self.currentPage - 1) * ITEMS_PER_PAGE + 1
    
    for i, btn in ipairs(self.frame.gridButtons) do
        local idx = startIdx + (i - 1)
        local set = list[idx]
        
        if set then
            btn:Show()
            btn.itemData = set -- Store set data
            
            -- Use first item icon or generic
            local icon = "Interface\\Icons\\INV_Misc_QuestionMark"
            if set.items and set.items[1] then
                local itemId = set.items[1]
                if GetItemIcon then
                    icon = GetItemIcon(itemId) or icon
                end
            end
            
            btn.icon:SetTexture(icon)
            
            -- Check if collected (all items)
            local collectedCount = 0
            local totalCount = 0
            if set.items then
                totalCount = #set.items
                for _, itemId in ipairs(set.items) do
                    if DC.collections.transmog and DC.collections.transmog[itemId] then
                        collectedCount = collectedCount + 1
                    end
                end
            end
            
            if totalCount > 0 and collectedCount == totalCount then
                btn.icon:SetVertexColor(1, 1, 1)
                btn.notCollected:Hide()
            else
                btn.icon:SetVertexColor(0.4, 0.4, 0.4)
                btn.notCollected:Show()
            end
            
            -- Tooltip for set
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(set.name or "Unknown Set")
                GameTooltip:AddLine(" ")
                if set.items then
                    for _, itemId in ipairs(set.items) do
                        local name, link = GetItemInfo(itemId)
                        if link then
                            local isCollected = DC.collections.transmog and DC.collections.transmog[itemId]
                            if isCollected then
                                GameTooltip:AddLine(name, 1, 1, 1)
                            else
                                GameTooltip:AddLine(name, 0.5, 0.5, 0.5)
                            end
                        end
                    end
                end
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
        else
            btn:Hide()
        end
    end
    
    -- Update page text
    local totalPages = math.ceil(#list / ITEMS_PER_PAGE)
    if self.frame.pageText then
        self.frame.pageText:SetText(string.format("Page %d / %d", self.currentPage, math.max(1, totalPages)))
    end
end

function Wardrobe:RefreshOutfitsGrid()
    if not self.frame then return end
    
    local outfits = DC.db and DC.db.outfits or {}
    
    for i, btn in ipairs(self.frame.gridButtons) do
        local outfit = outfits[i]
        
        if outfit then
            btn:Show()
            btn.itemData = { outfit = outfit, index = i }
            btn.icon:SetTexture(outfit.icon or "Interface\\Icons\\INV_Chest_Cloth_17")
            btn.icon:SetVertexColor(1, 1, 1)
            btn.notCollected:Hide()
        else
            btn:Hide()
            btn.itemData = nil
        end
    end
    
    -- Update page info for outfits
    if self.frame.pageText then
        self.frame.pageText:SetText("Saved Outfits")
    end
    if self.frame.collectedFrame then
        local count = 0
        for _ in pairs(outfits) do count = count + 1 end
        self.frame.collectedFrame.text:SetText(string.format("Outfits: %d", count))
        self.frame.collectedFrame.bar:SetValue(0)
    end
end

-- ============================================================================
-- APPEARANCE PREVIEW & APPLY
-- ============================================================================

function Wardrobe:PreviewAppearance(itemId)
    if not itemId or not self.frame or not self.frame.model then return end
    
    local model = self.frame.model
    model:SetUnit("player")
    
    if model.TryOn then
        model:TryOn(itemId)
    end
end

function Wardrobe:ApplyAppearance(itemId)
    if not itemId then return end
    
    local slot = self.selectedSlot
    if not slot then
        DC:Print("Please select an equipment slot first.")
        return
    end
    
    local invSlotId = GetInventorySlotInfo(slot.key)
    if not invSlotId then return end
    
    if not GetInventoryItemID("player", invSlotId) then
        DC:Print("No item equipped in that slot.")
        return
    end
    
    -- Request transmog from server
    if DC and DC.RequestSetTransmog then
        DC:RequestSetTransmog(invSlotId, itemId)
    end
end

-- ============================================================================
-- MODEL UPDATE
-- ============================================================================

function Wardrobe:UpdateModel()
    if not self.frame or not self.frame.model then return end
    
    local model = self.frame.model
    model:SetUnit("player")
    
    if self.transmogDisabled then
        model:Undress()
    end
end

-- ============================================================================
-- OUTFIT SYSTEM
-- ============================================================================

function Wardrobe:ShowSaveOutfitDialog()
    StaticPopupDialogs["DC_SAVE_OUTFIT"] = {
        text = "Enter outfit name:",
        button1 = "Save",
        button2 = "Cancel",
        hasEditBox = true,
        maxLetters = 32,
        OnAccept = function(self)
            local name = self.editBox:GetText()
            if name and name ~= "" then
                Wardrobe:SaveCurrentOutfit(name)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("DC_SAVE_OUTFIT")
end

function Wardrobe:SaveCurrentOutfit(name)
    if not DC.db then DC.db = {} end
    if not DC.db.outfits then DC.db.outfits = {} end
    
    -- Find first empty slot or use next index
    local index = nil
    for i = 1, 20 do
        if not DC.db.outfits[i] then
            index = i
            break
        end
    end
    
    if not index then
        DC:Print("Outfit slots full!")
        return
    end
    
    -- Gather current transmog state
    local outfit = {
        name = name,
        icon = "Interface\\Icons\\INV_Chest_Cloth_17",
        slots = {},
        date = date("%Y-%m-%d"),
        level = UnitLevel("player"),
    }
    
    -- Save current equipped items' transmog appearances
    for _, slotDef in ipairs(EQUIPMENT_SLOTS) do
        local invSlotId = GetInventorySlotInfo(slotDef.key)
        if invSlotId then
            local itemId = GetInventoryItemID("player", invSlotId)
            if itemId then
                -- Get the transmog applied to this slot (if any)
                local transmogId = DC.transmogState and DC.transmogState[tostring(invSlotId)]
                outfit.slots[slotDef.key] = transmogId or itemId
            end
        end
    end
    
    DC.db.outfits[index] = outfit
    DC:Print("Outfit '" .. name .. "' saved!")
    
    self:UpdateOutfitSlots()
end

function Wardrobe:LoadOutfit(index)
    local outfits = DC.db and DC.db.outfits or {}
    local outfit = outfits[index]
    
    if not outfit then
        DC:Print("No outfit saved in this slot.")
        return
    end
    
    -- Apply each slot's transmog
    for slotKey, itemId in pairs(outfit.slots) do
        local invSlotId = GetInventorySlotInfo(slotKey)
        if invSlotId and GetInventoryItemID("player", invSlotId) then
            if DC and DC.RequestSetTransmog then
                DC:RequestSetTransmog(invSlotId, itemId)
            end
        end
    end
    
    DC:Print("Outfit '" .. outfit.name .. "' applied!")
end

function Wardrobe:UpdateOutfitSlots()
    if not self.frame or not self.frame.outfitSlots then return end
    
    local outfits = DC.db and DC.db.outfits or {}
    
    for i, slot in ipairs(self.frame.outfitSlots) do
        local outfit = outfits[i]
        if outfit then
            slot.icon:SetTexture(outfit.icon or "Interface\\Icons\\INV_Chest_Cloth_17")
            slot.icon:Show()
        else
            slot.icon:Hide()
        end
    end
end

-- ============================================================================
-- UPDATE SLOT BUTTONS
-- ============================================================================

function Wardrobe:UpdateSlotButtons()
    if not self.frame or not self.frame.slotButtons then return end
    
    for _, btn in ipairs(self.frame.slotButtons) do
        local slotDef = btn.slotDef
        local invSlotId = GetInventorySlotInfo(slotDef.key)
        
        -- Update icon
        btn.icon:SetTexture(GetSlotIcon(slotDef.key))
        
        -- Check if transmog is applied
        local eqSlot = invSlotId and (invSlotId - 1)
        local state = DC.transmogState or {}
        local applied = eqSlot and state[tostring(eqSlot)] and tonumber(state[tostring(eqSlot)]) ~= 0
        
        if applied then
            btn.transmogApplied:Show()
        else
            btn.transmogApplied:Hide()
        end
    end
end

-- ============================================================================
-- SHOW / HIDE
-- ============================================================================

function Wardrobe:Show()
    local frame = self:CreateFrame()
    if not frame then return end
    
    -- Sync position with MainFrame if it's open
    if DC.MainFrame and DC.MainFrame:IsShown() then
        local point, relativeTo, relativePoint, xOfs, yOfs = DC.MainFrame:GetPoint()
        if point then
            frame:ClearAllPoints()
            frame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
        end
        DC.MainFrame:Hide()
    end
    
    -- Request data from server
    if DC and DC.RequestDefinitions then
        DC:RequestDefinitions("transmog")
    end
    if DC and DC.RequestCollection then
        DC:RequestCollection("transmog")
    end
    
    -- Update model
    if frame.model then
        frame.model:SetUnit("player")
        frame.model:SetFacing(0)
    end
    
    -- Select default tab
    self:SelectTab("items")
    
    -- Update slot buttons
    self:UpdateSlotButtons()
    self:UpdateOutfitSlots()
    
    frame:Show()
end

function Wardrobe:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function Wardrobe:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- ============================================================================
-- SLASH COMMAND
-- ============================================================================

SLASH_DCWARDROBE1 = "/wardrobe"
SLASH_DCWARDROBE2 = "/transmog"
SlashCmdList["DCWARDROBE"] = function()
    Wardrobe:Toggle()
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event)
    if Wardrobe.frame and Wardrobe.frame:IsShown() then
        Wardrobe:UpdateSlotButtons()
        Wardrobe:UpdateModel()
    end
end)
