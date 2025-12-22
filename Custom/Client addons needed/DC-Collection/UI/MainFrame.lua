--[[
    DC-Collection UI/MainFrame.lua
    ==============================
    
    Main collection window frame with tabs and content areas.
    
    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC.L

local function SetWidgetEnabled(widget, enabled)
    if not widget then
        return
    end
    if type(widget.SetEnabled) == "function" then
        widget:SetEnabled(enabled and true or false)
        return
    end
    if enabled then
        if type(widget.Enable) == "function" then
            widget:Enable()
        end
    else
        if type(widget.Disable) == "function" then
            widget:Disable()
        end
    end
end

local function GetRarityColor(self, rarity)
    local r = rarity or 1
    local rarityColors = self.RARITY_COLORS or self.RarityColors

    if not rarityColors or not next(rarityColors) then
        rarityColors = {
            [0] = {0.62, 0.62, 0.62}, -- poor
            [1] = {1.00, 1.00, 1.00}, -- common
            [2] = {0.12, 1.00, 0.00}, -- uncommon
            [3] = {0.00, 0.44, 0.87}, -- rare
            [4] = {0.64, 0.21, 0.93}, -- epic
            [5] = {1.00, 0.50, 0.00}, -- legendary
            [6] = {0.90, 0.80, 0.50}, -- artifact
            [7] = {0.90, 0.80, 0.50}, -- heirloom
        }
        self.RARITY_COLORS = rarityColors
    end

    local c = rarityColors[r] or { 1, 1, 1 }
    return c[1], c[2], c[3]
end

function DC:ResolveDefinitionIcon(collType, id, def)
    if def and def.icon and def.icon ~= "" then
        return def.icon
    end

    local numericId = tonumber(id) or id

    if collType == "mounts" then
        if type(GetSpellInfo) == "function" and numericId then
            local _, _, icon = GetSpellInfo(numericId)
            if icon and icon ~= "" then
                return icon
            end
        end
        if type(GetSpellTexture) == "function" and numericId then
            local texture = GetSpellTexture(numericId)
            if texture and texture ~= "" then
                return texture
            end
        end

        if def then
            local itemId = def.itemId or def.item_id or def.itemID
            if itemId then
                itemId = tonumber(itemId) or itemId
                if type(GetItemIcon) == "function" then
                    local texture = GetItemIcon(itemId)
                    if texture and texture ~= "" then
                        return texture
                    end
                end
                if type(GetItemInfo) == "function" then
                    local texture = select(10, GetItemInfo(itemId))
                    if texture and texture ~= "" then
                        return texture
                    end
                end
            end
        end
    elseif collType == "pets" or collType == "heirlooms" then
        if type(GetItemIcon) == "function" and numericId then
            local texture = GetItemIcon(numericId)
            if texture and texture ~= "" then
                return texture
            end
        end

        if type(GetItemInfo) == "function" and numericId then
            local texture = select(10, GetItemInfo(numericId))
            if texture and texture ~= "" then
                return texture
            end
        end

        -- Some datasets identify pets by spellId rather than itemId.
        if type(GetSpellInfo) == "function" and numericId then
            local _, _, icon = GetSpellInfo(numericId)
            if icon and icon ~= "" then
                return icon
            end
        end
        if type(GetSpellTexture) == "function" and numericId then
            local texture = GetSpellTexture(numericId)
            if texture and texture ~= "" then
                return texture
            end
        end
    elseif collType == "transmog" and def then
        local itemId = def.itemId or def.item_id or def.itemID
        if itemId then
            itemId = tonumber(itemId) or itemId
            if type(GetItemIcon) == "function" then
                local texture = GetItemIcon(itemId)
                if texture and texture ~= "" then
                    return texture
                end
            end
            if type(GetItemInfo) == "function" then
                local texture = select(10, GetItemInfo(itemId))
                if texture and texture ~= "" then
                    return texture
                end
            end
        end
    end

    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local FRAME_WIDTH = 700
local FRAME_HEIGHT = 500
local TAB_HEIGHT = 28
local HEADER_HEIGHT = 60
local FILTER_HEIGHT = 32
local FOOTER_HEIGHT = 40

-- ============================================================================
-- MAIN FRAME CREATION
-- ============================================================================

function DC:CreateMainFrame()
    if self.MainFrame then
        return self.MainFrame
    end
    
    -- Create main frame
    local frame = CreateFrame("Frame", "DCCollectionFrame", UIParent, "UIPanelDialogTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    
    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -12)
    frame.title:SetText(L["ADDON_NAME"] or "DC Collection")
    
    -- Close button hook
    frame.Close = _G[frame:GetName() .. "Close"]
    if frame.Close then
        frame.Close:SetScript("OnClick", function() DC:HideMainFrame() end)
    end
    
    -- Create header section
    self:CreateHeader(frame)
    
    -- Create tab bar
    self:CreateTabBar(frame)
    
    -- Create filter bar
    self:CreateFilterBar(frame)
    
    -- Create content area
    self:CreateContentArea(frame)
    
    -- Create footer
    self:CreateFooter(frame)
    
    -- Store reference
    self.MainFrame = frame
    
    -- ESC to close
    tinsert(UISpecialFrames, frame:GetName())
    
    return frame
end

-- ============================================================================
-- HEADER
-- ============================================================================

function DC:CreateHeader(parent)
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -30)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -30)
    header:SetHeight(HEADER_HEIGHT)
    
    -- Stats display
    header.statsText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.statsText:SetPoint("TOPLEFT", header, "TOPLEFT", 5, -2)
    header.statsText:SetJustifyH("LEFT")

    header.totalStatsText = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header.totalStatsText:SetPoint("TOPLEFT", header.statsText, "BOTTOMLEFT", 0, -2)
    header.totalStatsText:SetJustifyH("LEFT")
    
    -- Currency display
    header.currencyFrame = CreateFrame("Frame", nil, header)
    header.currencyFrame:SetPoint("RIGHT", header, "RIGHT", -5, 0)
    header.currencyFrame:SetSize(200, 24)
    
    -- Tokens
    header.tokensIcon = header.currencyFrame:CreateTexture(nil, "ARTWORK")
    header.tokensIcon:SetSize(16, 16)
    header.tokensIcon:SetPoint("RIGHT", header.currencyFrame, "RIGHT", 0, 0)
    header.tokensIcon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
    
    header.tokensText = header.currencyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.tokensText:SetPoint("RIGHT", header.tokensIcon, "LEFT", -3, 0)
    header.tokensText:SetText("0")
    
    -- Emblems
    header.emblemsIcon = header.currencyFrame:CreateTexture(nil, "ARTWORK")
    header.emblemsIcon:SetSize(16, 16)
    header.emblemsIcon:SetPoint("RIGHT", header.tokensText, "LEFT", -15, 0)
    header.emblemsIcon:SetTexture("Interface\\Icons\\Spell_Holy_SummonChampion")
    
    header.emblemsText = header.currencyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.emblemsText:SetPoint("RIGHT", header.emblemsIcon, "LEFT", -3, 0)
    header.emblemsText:SetText("0")
    
    -- Mount speed bonus display
    header.speedBonus = header:CreateFontString(nil, "OVERLAY", "GameFontGreen")
    header.speedBonus:SetPoint("TOP", header, "TOP", 0, -5)
    
    parent.Header = header
end

-- ============================================================================
-- TAB BAR
-- ============================================================================

function DC:CreateTabBar(parent)
    local tabBar = CreateFrame("Frame", nil, parent)
    tabBar:SetPoint("TOPLEFT", parent.Header, "BOTTOMLEFT", 0, -5)
    tabBar:SetPoint("TOPRIGHT", parent.Header, "BOTTOMRIGHT", 0, -5)
    tabBar:SetHeight(TAB_HEIGHT)
    
    -- Tab background
    local tabBg = tabBar:CreateTexture(nil, "BACKGROUND")
    tabBg:SetAllPoints()
    tabBg:SetColorTexture(0, 0, 0, 0.3)
    
    -- Create tabs
    local tabs = {
        { key = "mounts",    text = L["TAB_MOUNTS"],    icon = "Interface\\Icons\\Ability_Mount_RidingHorse" },
        { key = "pets",      text = L["TAB_PETS"],      icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },
        { key = "heirlooms", text = L["TAB_HEIRLOOMS"], icon = "Interface\\Icons\\INV_Sword_43" },
        { key = "transmog",  text = L["TAB_TRANSMOG"],  icon = "Interface\\Icons\\INV_Misc_Desecrated_ClothHelm" },
        { key = "titles",    text = L["TAB_TITLES"],    icon = "Interface\\Icons\\INV_Scroll_11" },
        { key = "shop",      text = L["TAB_SHOP"],      icon = "Interface\\Icons\\INV_Misc_Bag_10_Green" },
    }
    
    tabBar.tabs = {}
    local tabWidth = (FRAME_WIDTH - 20) / #tabs
    
    for i, tabInfo in ipairs(tabs) do
        local tab = self:CreateTabButton(tabBar, tabInfo, tabWidth, i)
        tabBar.tabs[tabInfo.key] = tab
        
        if i == 1 then
            self.activeTab = tabInfo.key
            tab:SetChecked(true)
        end
    end
    
    parent.TabBar = tabBar
end

function DC:CreateTabButton(parent, tabInfo, width, index)
    local tab = CreateFrame("CheckButton", nil, parent)
    tab:SetSize(width - 2, TAB_HEIGHT - 4)
    tab:SetPoint("LEFT", parent, "LEFT", (index - 1) * width + 2, 0)
    tab.key = tabInfo.key
    
    -- Background
    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetAllPoints()
    tab.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    -- Highlight
    tab.highlight = tab:CreateTexture(nil, "HIGHLIGHT")
    tab.highlight:SetAllPoints()
    tab.highlight:SetColorTexture(0.4, 0.4, 0.4, 0.5)
    
    -- Checked texture
    tab.checked = tab:CreateTexture(nil, "BACKGROUND")
    tab.checked:SetAllPoints()
    tab.checked:SetColorTexture(0.3, 0.3, 0.6, 0.8)
    tab:SetCheckedTexture(tab.checked)
    
    -- Icon
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetSize(16, 16)
    tab.icon:SetPoint("LEFT", tab, "LEFT", 5, 0)
    tab.icon:SetTexture(tabInfo.icon)
    
    -- Text
    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.text:SetPoint("LEFT", tab.icon, "RIGHT", 5, 0)
    tab.text:SetText(tabInfo.text)
    
    -- Click handler
    tab:SetScript("OnClick", function()
        DC:SelectTab(tabInfo.key)
    end)
    
    return tab
end

-- ============================================================================
-- FILTER BAR
-- ============================================================================

function DC:CreateFilterBar(parent)
    local filterBar = CreateFrame("Frame", nil, parent)
    filterBar:SetPoint("TOPLEFT", parent.TabBar, "BOTTOMLEFT", 0, -5)
    filterBar:SetPoint("TOPRIGHT", parent.TabBar, "BOTTOMRIGHT", 0, -5)
    filterBar:SetHeight(FILTER_HEIGHT)
    
    -- Background
    local filterBg = filterBar:CreateTexture(nil, "BACKGROUND")
    filterBg:SetAllPoints()
    filterBg:SetColorTexture(0, 0, 0, 0.2)
    
    -- Search box
    local searchBox = CreateFrame("EditBox", "DCCollectionSearchBox", filterBar, "InputBoxTemplate")
    searchBox:SetSize(150, 20)
    searchBox:SetPoint("LEFT", filterBar, "LEFT", 10, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)
    
    local searchLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("RIGHT", searchBox, "LEFT", -5, 0)
    searchLabel:SetText(L["FILTER_SEARCH"])
    
    searchBox:SetScript("OnTextChanged", function(self)
        DC:OnSearchChanged(self:GetText())
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    
    filterBar.searchBox = searchBox
    
    -- Filter: Show collected
    local collectedCheck = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
    collectedCheck:SetSize(24, 24)
    collectedCheck:SetPoint("LEFT", searchBox, "RIGHT", 20, 0)
    collectedCheck:SetChecked(true)
    collectedCheck:SetScript("OnClick", function(self)
        DC:OnFilterChanged()
    end)
    
    local collectedLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collectedLabel:SetPoint("LEFT", collectedCheck, "RIGHT", 2, 0)
    collectedLabel:SetText(L["FILTER_COLLECTED"])
    
    filterBar.collectedCheck = collectedCheck
    
    -- Filter: Show not collected
    local notCollectedCheck = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
    notCollectedCheck:SetSize(24, 24)
    notCollectedCheck:SetPoint("LEFT", collectedLabel, "RIGHT", 15, 0)
    notCollectedCheck:SetChecked(true)
    notCollectedCheck:SetScript("OnClick", function(self)
        DC:OnFilterChanged()
    end)
    
    local notCollectedLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    notCollectedLabel:SetPoint("LEFT", notCollectedCheck, "RIGHT", 2, 0)
    notCollectedLabel:SetText(L["FILTER_NOT_COLLECTED"])
    
    filterBar.notCollectedCheck = notCollectedCheck

    -- Transmog-specific controls (slot picker + quick actions)
    -- Shown only when the Transmog tab is active.
    local transmogSlotDropdown = CreateFrame("Frame", "DCCollectionTransmogSlotDropdown", filterBar, "UIDropDownMenuTemplate")
    transmogSlotDropdown:SetPoint("RIGHT", filterBar, "RIGHT", -120, 0)
    UIDropDownMenu_SetWidth(transmogSlotDropdown, 110)
    UIDropDownMenu_SetText(transmogSlotDropdown, "Slot: All")

    UIDropDownMenu_Initialize(transmogSlotDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()

        local options = {
            { text = "All", slotName = nil },
            { text = "Head", slotName = "HeadSlot" },
            { text = "Shoulder", slotName = "ShoulderSlot" },
            { text = "Back", slotName = "BackSlot" },
            { text = "Chest", slotName = "ChestSlot" },
            { text = "Wrist", slotName = "WristSlot" },
            { text = "Hands", slotName = "HandsSlot" },
            { text = "Waist", slotName = "WaistSlot" },
            { text = "Legs", slotName = "LegsSlot" },
            { text = "Feet", slotName = "FeetSlot" },
            { text = "Main Hand", slotName = "MainHandSlot" },
            { text = "Off Hand", slotName = "SecondaryHandSlot" },
            { text = "Ranged", slotName = "RangedSlot" },
        }

        for _, opt in ipairs(options) do
            info.text = opt.text
            info.notCheckable = true
            info.func = function()
                DC.transmogSelectedSlotName = opt.slotName
                DC.transmogSelectedInvSlotId = opt.slotName and GetInventorySlotInfo(opt.slotName) or nil
                UIDropDownMenu_SetText(transmogSlotDropdown, "Slot: " .. opt.text)
                DC:OnFilterChanged()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    filterBar.transmogSlotDropdown = transmogSlotDropdown

    local transmogClearBtn = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    transmogClearBtn:SetSize(70, 20)
    transmogClearBtn:SetPoint("RIGHT", transmogSlotDropdown, "LEFT", -10, 0)
    transmogClearBtn:SetText("Clear")
    transmogClearBtn:SetScript("OnClick", function()
        local invSlotId = DC.transmogSelectedInvSlotId
        if not invSlotId then
            if DC.Print then DC:Print("Select a slot first.") end
            return
        end
        if not GetInventoryItemID("player", invSlotId) then
            if DC.Print then DC:Print("No item equipped in that slot.") end
            return
        end
        DC:RequestClearTransmog(invSlotId)
    end)
    filterBar.transmogClearBtn = transmogClearBtn

    local transmogOutfitsBtn = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    transmogOutfitsBtn:SetSize(70, 20)
    transmogOutfitsBtn:SetPoint("RIGHT", transmogClearBtn, "LEFT", -8, 0)
    transmogOutfitsBtn:SetText("Outfits")
    transmogOutfitsBtn:SetScript("OnClick", function()
        if not DC.ShowOutfitMenu then
            return
        end
        local menu = {}
        DC:ShowOutfitMenu(menu)
        table.insert(menu, { text = L["CANCEL"] or "Cancel", notCheckable = true })
        local dropdown = CreateFrame("Frame", "DCCollectionOutfitsMenu", UIParent, "UIDropDownMenuTemplate")
        EasyMenu(menu, dropdown, "cursor", 0, 0, "MENU")
    end)
    filterBar.transmogOutfitsBtn = transmogOutfitsBtn
    
    -- Sort dropdown
    local sortDropdown = CreateFrame("Frame", "DCCollectionSortDropdown", filterBar, "UIDropDownMenuTemplate")
    sortDropdown:SetPoint("RIGHT", filterBar, "RIGHT", 0, 0)
    UIDropDownMenu_SetWidth(sortDropdown, 100)
    UIDropDownMenu_SetText(sortDropdown, L["SORT_NAME"])
    
    UIDropDownMenu_Initialize(sortDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        
        local sortOptions = {
            { text = L["SORT_NAME"],   value = "name" },
            { text = L["SORT_RARITY"], value = "rarity" },
            { text = L["SORT_TYPE"],   value = "type" },
            { text = L["SORT_SOURCE"], value = "source" },
        }
        
        for _, option in ipairs(sortOptions) do
            info.text = option.text
            info.value = option.value
            info.func = function(self)
                UIDropDownMenu_SetText(sortDropdown, option.text)
                DC.currentSort = option.value
                DC:OnFilterChanged()
            end
            info.checked = (DC.currentSort == option.value)
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    filterBar.sortDropdown = sortDropdown

    -- Start hidden until Transmog tab is opened.
    transmogSlotDropdown:Hide()
    transmogClearBtn:Hide()
    transmogOutfitsBtn:Hide()
    
    parent.FilterBar = filterBar
end

function DC:UpdateFilterBarForTab(tabKey)
    if not self.MainFrame or not self.MainFrame.FilterBar then
        return
    end

    local fb = self.MainFrame.FilterBar
    local isTransmog = (tabKey == "transmog")

    if fb.transmogSlotDropdown then
        if isTransmog then fb.transmogSlotDropdown:Show() else fb.transmogSlotDropdown:Hide() end
    end
    if fb.transmogClearBtn then
        if isTransmog then fb.transmogClearBtn:Show() else fb.transmogClearBtn:Hide() end
    end
    if fb.transmogOutfitsBtn then
        if isTransmog then fb.transmogOutfitsBtn:Show() else fb.transmogOutfitsBtn:Hide() end
    end
end

-- ============================================================================
-- CONTENT AREA
-- ============================================================================

function DC:CreateContentArea(parent)
    local content = CreateFrame("Frame", nil, parent)
    content:SetPoint("TOPLEFT", parent.FilterBar, "BOTTOMLEFT", 0, -5)
    content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, FOOTER_HEIGHT + 5)
    
    -- Background
    local contentBg = content:CreateTexture(nil, "BACKGROUND")
    contentBg:SetAllPoints()
    contentBg:SetColorTexture(0, 0, 0, 0.3)

    -- Details bar: left info + right visuals (shared across tabs)
    local details = CreateFrame("Frame", nil, content)
    details:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -5)
    details:SetPoint("TOPRIGHT", content, "TOPRIGHT", -5, -5)
    details:SetHeight(80)

    details.bg = details:CreateTexture(nil, "BACKGROUND")
    details.bg:SetAllPoints()
    details.bg:SetColorTexture(0, 0, 0, 0.25)

    details.iconBorder = details:CreateTexture(nil, "BORDER")
    details.iconBorder:SetSize(70, 70)
    details.iconBorder:SetPoint("RIGHT", details, "RIGHT", -8, 0)
    details.iconBorder:SetColorTexture(0.25, 0.25, 0.25, 0.8)

    details.icon = details:CreateTexture(nil, "ARTWORK")
    details.icon:SetSize(64, 64)
    details.icon:SetPoint("CENTER", details.iconBorder, "CENTER", 0, 0)
    details.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    details.name = details:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    details.name:SetPoint("TOPLEFT", details, "TOPLEFT", 10, -10)
    details.name:SetPoint("TOPRIGHT", details.iconBorder, "TOPLEFT", -10, -10)
    details.name:SetJustifyH("LEFT")
    details.name:SetText(L["HOVER_FOR_DETAILS"] or "Hover an item to see details")

    details.line1 = details:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    details.line1:SetPoint("TOPLEFT", details.name, "BOTTOMLEFT", 0, -6)
    details.line1:SetPoint("TOPRIGHT", details.iconBorder, "TOPLEFT", -10, -6)
    details.line1:SetJustifyH("LEFT")

    details.line2 = details:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    details.line2:SetPoint("TOPLEFT", details.line1, "BOTTOMLEFT", 0, -4)
    details.line2:SetPoint("TOPRIGHT", details.iconBorder, "TOPLEFT", -10, -4)
    details.line2:SetJustifyH("LEFT")

    content.details = details
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "DCCollectionScrollFrame", content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", details, "BOTTOMLEFT", 0, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -25, 5)
    
    -- Scroll child (content container)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)  -- Height will be set dynamically
    scrollFrame:SetScrollChild(scrollChild)
    
    content.scrollFrame = scrollFrame
    content.scrollChild = scrollChild
    
    parent.Content = content
end

function DC:ClearDetailsPanel()
    if not self.MainFrame or not self.MainFrame.Content or not self.MainFrame.Content.details then
        return
    end

    local d = self.MainFrame.Content.details
    d.name:SetText(L["HOVER_FOR_DETAILS"] or "Hover an item to see details")
    d.name:SetTextColor(1, 1, 1)
    d.line1:SetText("")
    d.line2:SetText("")
    d.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    d.icon:SetDesaturated(false)
    d.icon:SetAlpha(1)
end

function DC:UpdateDetailsPanel(item)
    if not item or not self.MainFrame or not self.MainFrame.Content or not self.MainFrame.Content.details then
        return
    end

    local d = self.MainFrame.Content.details
    local r, g, b = GetRarityColor(self, item.rarity or 1)

    d.name:SetText(item.name or "Unknown")
    d.name:SetTextColor(r, g, b)

    local sourceText = item.sourceText
    if not sourceText then
        sourceText = self:FormatSource(item.source)
    end

    if sourceText and sourceText ~= "" then
        d.line1:SetText((L["SOURCE"] or "Source") .. ": " .. tostring(sourceText))
    else
        d.line1:SetText("")
    end

    if item.type == "shop" then
        local priceTokens = item.priceTokens or 0
        local priceEmblems = item.priceEmblems or 0
        d.line2:SetText(string.format("Price: %d tokens, %d emblems", priceTokens, priceEmblems))
    else
        d.line2:SetText(item.collected and (L["COLLECTED"] or "Collected") or (L["NOT_COLLECTED"] or "Not collected"))
    end

    d.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    if item.collected == false then
        d.icon:SetDesaturated(true)
        d.icon:SetAlpha(0.5)
    else
        d.icon:SetDesaturated(false)
        d.icon:SetAlpha(1)
    end
end

-- ============================================================================
-- FOOTER
-- ============================================================================

function DC:CreateFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 5)
    footer:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 5)
    footer:SetHeight(FOOTER_HEIGHT)
    
    -- Sync button
    local syncBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    syncBtn:SetSize(80, 22)
    syncBtn:SetPoint("LEFT", footer, "LEFT", 5, 0)
    syncBtn:SetText(L["SYNC"])
    syncBtn:SetScript("OnClick", function()
        DC:DeltaSync()
    end)
    
    -- Wishlist button
    local wishlistBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    wishlistBtn:SetSize(80, 22)
    wishlistBtn:SetPoint("LEFT", syncBtn, "RIGHT", 5, 0)
    wishlistBtn:SetText(L["WISHLIST"])
    wishlistBtn:SetScript("OnClick", function()
        DC:ShowWishlist()
    end)
    
    -- Page info
    footer.pageInfo = footer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    footer.pageInfo:SetPoint("CENTER", footer, "CENTER", 0, 0)
    footer.pageInfo:SetText("Page 1 of 1")
    
    -- Navigation buttons
    local prevBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    prevBtn:SetSize(60, 22)
    prevBtn:SetPoint("RIGHT", footer.pageInfo, "LEFT", -10, 0)
    prevBtn:SetText("<")
    prevBtn:SetScript("OnClick", function()
        DC:PrevPage()
    end)
    
    local nextBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    nextBtn:SetSize(60, 22)
    nextBtn:SetPoint("LEFT", footer.pageInfo, "RIGHT", 10, 0)
    nextBtn:SetText(">")
    nextBtn:SetScript("OnClick", function()
        DC:NextPage()
    end)
    
    footer.prevBtn = prevBtn
    footer.nextBtn = nextBtn
    
    parent.Footer = footer
end

-- ============================================================================
-- FRAME MANAGEMENT
-- ============================================================================

function DC:ShowMainFrame()
    if not self.MainFrame then
        self:CreateMainFrame()
    end
    
    self.MainFrame:Show()
    
    -- Refresh current tab
    self:RefreshCurrentTab()
    self:UpdateHeader()
end

function DC:HideMainFrame()
    if self.MainFrame then
        self.MainFrame:Hide()
    end
end

function DC:ToggleMainFrame()
    if self.MainFrame and self.MainFrame:IsShown() then
        self:HideMainFrame()
    else
        self:ShowMainFrame()
    end
end

-- ============================================================================
-- TAB SELECTION
-- ============================================================================

function DC:SelectTab(tabKey)
    self.activeTab = tabKey

    self:UpdateFilterBarForTab(tabKey)
    
    -- Update tab visuals
    for key, tab in pairs(self.MainFrame.TabBar.tabs) do
        tab:SetChecked(key == tabKey)
    end
    
    -- Clear current page
    self.currentPage = 1

    self:ClearDetailsPanel()
    
    -- Show appropriate content
    if tabKey == "shop" then
        self:ShowShopContent()
    else
        self:RefreshCurrentTab()
    end
end

function DC:RefreshCurrentTab()
    if not self.MainFrame or not self.MainFrame:IsShown() then
        return
    end
    
    self:UpdateHeader()
    self:PopulateGrid()
end

-- ============================================================================
-- HEADER UPDATE
-- ============================================================================

function DC:UpdateHeader()
    if not self.MainFrame then return end
    
    local header = self.MainFrame.Header
    
    -- Update currency
    header.tokensText:SetText(self.currency.tokens or 0)
    header.emblemsText:SetText(self.currency.emblems or 0)
    
    -- Update stats for current tab
    local stats = self.stats[self.activeTab]
    if stats then
        local owned = stats.owned or 0
        local total = stats.total or 0
        local pct = (total > 0) and math.floor((owned / total) * 1000 + 0.5) / 10 or 0
        header.statsText:SetText(string.format("%s  Collected: %d / %d (%.1f%%)",
            L["TAB_" .. string.upper(self.activeTab)] or self.activeTab,
            owned,
            total,
            pct))
    else
        header.statsText:SetText("")
    end

    -- Overall totals across all categories
    if type(self.GetTotalCount) == "function" then
        local o, t = self:GetTotalCount()
        local pct = (t > 0) and math.floor((o / t) * 1000 + 0.5) / 10 or 0
        header.totalStatsText:SetText(string.format("Total  Collected: %d / %d (%.1f%%)", o or 0, t or 0, pct))
    else
        header.totalStatsText:SetText("")
    end
    
    -- Update mount speed bonus
    if self.mountSpeedBonus and self.mountSpeedBonus > 0 then
        header.speedBonus:SetText(string.format("+%d%% Mount Speed", self.mountSpeedBonus))
        header.speedBonus:Show()
    else
        header.speedBonus:Hide()
    end
end

-- ============================================================================
-- GRID POPULATION
-- ============================================================================

function DC:PopulateGrid()
    if not self.MainFrame then return end
    
    local scrollChild = self.MainFrame.Content.scrollChild
    
    -- Clear existing items
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Get filtered items
    local items = self:GetFilteredItems()
    
    -- Paginate
    local itemsPerPage = 24  -- 6 columns x 4 rows
    local totalPages = math.max(1, math.ceil(#items / itemsPerPage))
    self.currentPage = math.min(self.currentPage or 1, totalPages)
    
    local startIdx = (self.currentPage - 1) * itemsPerPage + 1
    local endIdx = math.min(startIdx + itemsPerPage - 1, #items)
    
    -- Create item cards
    local cols = 6
    local cardSize = 85
    local spacing = 5
    local row = 0
    local col = 0
    
    for i = startIdx, endIdx do
        local item = items[i]
        local card = self:CreateItemCard(scrollChild, item, col, row, cardSize, spacing)
        
        col = col + 1
        if col >= cols then
            col = 0
            row = row + 1
        end
    end
    
    -- Update scroll child height
    local rows = math.ceil((endIdx - startIdx + 1) / cols)
    scrollChild:SetHeight(rows * (cardSize + spacing))
    
    -- Update page info
    self.MainFrame.Footer.pageInfo:SetText(string.format("Page %d of %d", self.currentPage, totalPages))
    SetWidgetEnabled(self.MainFrame.Footer.prevBtn, self.currentPage > 1)
    SetWidgetEnabled(self.MainFrame.Footer.nextBtn, self.currentPage < totalPages)
end

function DC:CreateItemCard(parent, item, col, row, size, spacing)
    local card = CreateFrame("Button", nil, parent)
    card:SetSize(size, size)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", col * (size + spacing), -row * (size + spacing))
    
    -- Background based on collected state
    card.bg = card:CreateTexture(nil, "BACKGROUND")
    card.bg:SetAllPoints()
    if item.collected then
        card.bg:SetColorTexture(0.2, 0.4, 0.2, 0.8)
    else
        card.bg:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    end
    
    -- Rarity border
    local rarity = item.rarity or 1
    local r, g, b = GetRarityColor(self, rarity)
    card.border = card:CreateTexture(nil, "BORDER")
    card.border:SetPoint("TOPLEFT", -2, 2)
    card.border:SetPoint("BOTTOMRIGHT", 2, -2)
    card.border:SetColorTexture(r, g, b, 0.8)
    
    -- Icon
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(size - 20, size - 20)
    card.icon:SetPoint("TOP", card, "TOP", 0, -5)
    card.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    
    if not item.collected then
        card.icon:SetDesaturated(true)
        card.icon:SetAlpha(0.5)
    end
    
    -- Name
    card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.name:SetPoint("BOTTOM", card, "BOTTOM", 0, 3)
    card.name:SetWidth(size - 4)
    card.name:SetText(item.name or "Unknown")
    card.name:SetWordWrap(false)
    
    -- Favorite indicator
    if item.is_favorite then
        card.favIcon = card:CreateTexture(nil, "OVERLAY")
        card.favIcon:SetSize(16, 16)
        card.favIcon:SetPoint("TOPRIGHT", card, "TOPRIGHT", -2, -2)
        card.favIcon:SetTexture("Interface\\Icons\\Achievement_GuildPerk_HappyHour")
    end
    
    -- Highlight
    card.highlight = card:CreateTexture(nil, "HIGHLIGHT")
    card.highlight:SetAllPoints()
    card.highlight:SetColorTexture(1, 1, 1, 0.2)
    
    -- Click handlers
    card:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            DC:OnItemLeftClick(item)
        elseif button == "RightButton" then
            DC:OnItemRightClick(item)
        end
    end)
    card:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    -- Tooltip
    card:SetScript("OnEnter", function(self)
        DC:UpdateDetailsPanel(item)
        DC:ShowItemTooltip(self, item)
    end)
    card:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    return card
end

-- ============================================================================
-- FILTERING
-- ============================================================================

function DC:GetFilteredItems()
    local items = {}
    local collType = self.activeTab
    
    if collType == "shop" then
        return self.shopItems or {}
    end
    
    local definitions = self.definitions[collType] or {}
    local collection = self.collections[collType] or {}
    
    local searchText = string.lower(self.MainFrame.FilterBar.searchBox:GetText() or "")
    local showCollected = self.MainFrame.FilterBar.collectedCheck:GetChecked()
    local showNotCollected = self.MainFrame.FilterBar.notCollectedCheck:GetChecked()
    
    local function InvTypeMatchesSelectedTransmogSlot(invType)
        local slotName = DC.transmogSelectedSlotName
        if collType ~= "transmog" or not slotName then
            return true
        end

        local allowed = {
            HeadSlot = { [1] = true },
            ShoulderSlot = { [3] = true },
            BackSlot = { [16] = true },
            ChestSlot = { [5] = true, [20] = true },
            WristSlot = { [9] = true },
            HandsSlot = { [10] = true },
            WaistSlot = { [6] = true },
            LegsSlot = { [7] = true },
            FeetSlot = { [8] = true },
            MainHandSlot = { [13] = true, [17] = true, [21] = true },
            SecondaryHandSlot = { [13] = true, [17] = true, [22] = true, [14] = true, [23] = true },
            RangedSlot = { [14] = true, [15] = true, [25] = true, [28] = true },
        }

        local set = allowed[slotName]
        if not set then
            -- Safety: if slotName is unknown, treat as "All".
            return true
        end
        return set[invType] or false
    end

    for id, def in pairs(definitions) do
        local collData = collection[id]
        local isCollected = collData ~= nil

        -- Transmog: filter by selected slot (retail-like slot browsing)
        if collType == "transmog" and not InvTypeMatchesSelectedTransmogSlot(def.inventoryType or 0) then
            -- skip
        else
        
        -- Filter by collected state
        if (isCollected and showCollected) or (not isCollected and showNotCollected) then
            -- Filter by search
            local name = string.lower(def.name or "")
            if searchText == "" or string.find(name, searchText, 1, true) then
                table.insert(items, {
                    id = id,
                    name = def.name,
                    icon = self:ResolveDefinitionIcon(collType, id, def),
                    rarity = def.rarity,
                    source = def.source,
                    sourceText = self:FormatSource(def.source),
                    sourceSort = self:GetSourceSortKey(def.source),
                    type = collType,
                    collected = isCollected,
                    is_favorite = collData and collData.is_favorite,
                    collectionData = collData,
                    definition = def,
                })
            end
        end

        end
    end
    
    -- Sort
    self:SortItems(items)
    
    return items
end

function DC:SortItems(items)
    local sortKey = self.currentSort or "name"
    
    table.sort(items, function(a, b)
        -- Favorites first
        if a.is_favorite and not b.is_favorite then return true end
        if b.is_favorite and not a.is_favorite then return false end
        
        -- Collected first
        if a.collected and not b.collected then return true end
        if b.collected and not a.collected then return false end
        
        -- Then by sort key
        if sortKey == "name" then
            return (a.name or "") < (b.name or "")
        elseif sortKey == "rarity" then
            return (a.rarity or 0) > (b.rarity or 0)
        elseif sortKey == "type" then
            return (a.definition and a.definition.mountType or 0) < (b.definition and b.definition.mountType or 0)
        elseif sortKey == "source" then
            return (a.sourceSort or "") < (b.sourceSort or "")
        end
        return false
    end)
end

function DC:OnSearchChanged(text)
    self.currentPage = 1
    self:PopulateGrid()
end

function DC:OnFilterChanged()
    self.currentPage = 1
    self:PopulateGrid()
end

-- ============================================================================
-- PAGINATION
-- ============================================================================

function DC:NextPage()
    self.currentPage = (self.currentPage or 1) + 1
    self:PopulateGrid()
end

function DC:PrevPage()
    self.currentPage = math.max(1, (self.currentPage or 1) - 1)
    self:PopulateGrid()
end

-- ============================================================================
-- ITEM INTERACTION
-- ============================================================================

function DC:OnItemLeftClick(item)
    if item.type == "shop" then
        -- Default action in shop: preview if supported
        if item.collectionTypeName == "transmog" then
            self:PreviewShopTransmogItem(item)
        end
        return
    end

    if not item.collected then
        -- Not collected - show where to get it
        return
    end
    
    if item.type == "mounts" then
        self:RequestSummonMount(item.id)
    elseif item.type == "pets" then
        self:RequestSummonPet(item.id)
    elseif item.type == "heirlooms" then
        self:RequestSummonHeirloom(item.id)
    elseif item.type == "titles" then
        self:RequestSetTitle(item.id)
    elseif item.type == "transmog" then
        -- Retail-ish workflow: click to apply to selected slot; fallback to preview.
        local invSlotId = self.transmogSelectedInvSlotId
        if invSlotId and GetInventoryItemID("player", invSlotId) then
            self:RequestSetTransmog(invSlotId, item.id)
        else
            self:PreviewTransmogAppearance(item.id)
        end
    end
end

function DC:OnItemRightClick(item)
    -- Show context menu
    local menu = {
        { text = item.name, isTitle = true, notCheckable = true },
    }

    -- Shop: Preview + Buy
    if item.type == "shop" then
        if item.collectionTypeName == "transmog" then
            table.insert(menu, {
                text = "Preview",
                notCheckable = true,
                func = function() DC:PreviewShopTransmogItem(item) end,
            })
        end

        if not item.owned then
            table.insert(menu, {
                text = "Buy",
                notCheckable = true,
                func = function() if item.shopId then DC:RequestBuyItem(item.shopId) end end,
            })
        end

        table.insert(menu, { text = L["CANCEL"], notCheckable = true })
        local dropdown = CreateFrame("Frame", "DCCollectionContextMenu", UIParent, "UIDropDownMenuTemplate")
        EasyMenu(menu, dropdown, "cursor", 0, 0, "MENU")
        return
    end

    -- Transmog: add apply/clear actions (retail-like)
    if item.type == "transmog" then
        -- Preview (dressing room)
        table.insert(menu, {
            text = "Preview",
            notCheckable = true,
            func = function() DC:PreviewTransmogAppearance(item.id) end,
        })

        local invType = item.definition and item.definition.inventoryType
        local appearanceId = item.id

        local slotLabels = {
            ["HeadSlot"] = "Head",
            ["ShoulderSlot"] = "Shoulder",
            ["BackSlot"] = "Back",
            ["ChestSlot"] = "Chest",
            ["WristSlot"] = "Wrist",
            ["HandsSlot"] = "Hands",
            ["WaistSlot"] = "Waist",
            ["LegsSlot"] = "Legs",
            ["FeetSlot"] = "Feet",
            ["MainHandSlot"] = "Main Hand",
            ["SecondaryHandSlot"] = "Off Hand",
            ["RangedSlot"] = "Ranged",
        }

        local invTypeToSlots = {
            [1] = { "HeadSlot" },
            [3] = { "ShoulderSlot" },
            [16] = { "BackSlot" },
            [5] = { "ChestSlot" },
            [20] = { "ChestSlot" }, -- robe
            [9] = { "WristSlot" },
            [10] = { "HandsSlot" },
            [6] = { "WaistSlot" },
            [7] = { "LegsSlot" },
            [8] = { "FeetSlot" },

            -- weapons
            [13] = { "MainHandSlot" },
            [21] = { "MainHandSlot" },
            [17] = { "SecondaryHandSlot" },
            [22] = { "SecondaryHandSlot" },
            [14] = { "RangedSlot" },
            [15] = { "RangedSlot" },
            [25] = { "RangedSlot" },
            [28] = { "RangedSlot" },
        }

        local slots = invType and invTypeToSlots[invType] or nil
        if slots and item.collected then
            table.insert(menu, { text = "Apply", isTitle = true, notCheckable = true })

            for _, slotName in ipairs(slots) do
                local invSlotId = GetInventorySlotInfo(slotName)
                local equippedItemId = GetInventoryItemID("player", invSlotId)
                if equippedItemId then
                    table.insert(menu, {
                        text = "Apply to " .. (slotLabels[slotName] or slotName),
                        notCheckable = true,
                        func = function() DC:RequestSetTransmog(invSlotId, appearanceId) end,
                    })
                end
            end
        end

        -- Clear options for slots that currently have transmog
        local state = DC.transmogState or {}
        local anyClear = false
        if slots and next(state) ~= nil then
            for _, slotName in ipairs(slots) do
                local invSlotId = GetInventorySlotInfo(slotName)
                local equipmentSlot = (invSlotId == 1 and 0) or (invSlotId and (invSlotId - 1))
                if state[tostring(equipmentSlot)] and tonumber(state[tostring(equipmentSlot)]) and tonumber(state[tostring(equipmentSlot)]) ~= 0 then
                    anyClear = true
                end
            end
        end

        if anyClear then
            table.insert(menu, { text = "Clear", isTitle = true, notCheckable = true })
            for _, slotName in ipairs(slots) do
                local invSlotId = GetInventorySlotInfo(slotName)
                local equipmentSlot = (invSlotId == 1 and 0) or (invSlotId and (invSlotId - 1))
                local v = state[tostring(equipmentSlot)]
                if v and tonumber(v) and tonumber(v) ~= 0 then
                    table.insert(menu, {
                        text = "Clear " .. (slotLabels[slotName] or slotName),
                        notCheckable = true,
                        func = function() DC:RequestClearTransmog(invSlotId) end,
                    })
                end
            end
        end

        -- Outfits (sets)
        if DC.ShowOutfitMenu then
            table.insert(menu, { text = " ", isTitle = true, notCheckable = true })
            DC:ShowOutfitMenu(menu)
        end
    end
    
    if item.collected then
        if item.is_favorite then
            table.insert(menu, {
                text = L["UNFAVORITE"],
                notCheckable = true,
                func = function() DC:RequestToggleFavorite(item.type, item.id) end,
            })
        else
            table.insert(menu, {
                text = L["FAVORITE"],
                notCheckable = true,
                func = function() DC:RequestToggleFavorite(item.type, item.id) end,
            })
        end
    else
        table.insert(menu, {
            text = L["ADD_TO_WISHLIST"],
            notCheckable = true,
            func = function() DC:RequestAddWishlist(item.type, item.id) end,
        })
    end
    
    table.insert(menu, {
        text = L["CANCEL"],
        notCheckable = true,
    })
    
    -- Create and show dropdown
    local dropdown = CreateFrame("Frame", "DCCollectionContextMenu", UIParent, "UIDropDownMenuTemplate")
    EasyMenu(menu, dropdown, "cursor", 0, 0, "MENU")
end

-- ============================================================================
-- TOOLTIP
-- ============================================================================

function DC:ShowItemTooltip(anchor, item)
    if type(self.GetSetting) == "function" and not self:GetSetting("showTooltips") then
        return
    end

    local function LT(key, fallback)
        local v = nil
        if L then
            v = L[key] or L[string.upper(key)]
        end
        if type(v) ~= "string" or v == "" then
            v = fallback
        end
        return v
    end

    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
    
    -- Name with rarity color
    local r, g, b = GetRarityColor(self, item.rarity or 1)
    GameTooltip:AddLine(item.name or "Unknown", r, g, b)
    
    -- Type
    if item.definition and item.definition.mountType then
        local mountTypes = { [1] = "Ground", [2] = "Flying", [3] = "Aquatic" }
        GameTooltip:AddLine(mountTypes[item.definition.mountType] or "Mount", 1, 1, 1)
    end
    
    -- Source
    local sourceText = item.sourceText
    if not sourceText then
        sourceText = self:FormatSource(item.source)
    end

    if sourceText and sourceText ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(LT("SOURCE", "Source") .. ": " .. tostring(sourceText), 0.7, 0.7, 0.7)
    end
    
    -- Collection status
    GameTooltip:AddLine(" ")
    if item.collected then
        GameTooltip:AddLine(LT("COLLECTED", "Collected"), 0, 1, 0)
        
        -- Usage instructions
        if item.type == "mounts" then
            GameTooltip:AddLine(LT("CLICK_SUMMON", "Click to summon"), 0.5, 0.5, 0.5)
        elseif item.type == "pets" then
            GameTooltip:AddLine(LT("CLICK_SUMMON", "Click to summon"), 0.5, 0.5, 0.5)
        elseif item.type == "heirlooms" then
            GameTooltip:AddLine("Click to summon to bags", 0.5, 0.5, 0.5)
        elseif item.type == "titles" then
            GameTooltip:AddLine("Click to set as active title", 0.5, 0.5, 0.5)
        elseif item.type == "transmog" then
            if self.transmogSelectedInvSlotId then
                GameTooltip:AddLine("Click to apply to selected slot", 0.5, 0.5, 0.5)
            else
                GameTooltip:AddLine("Select a slot to apply (or right-click)", 0.5, 0.5, 0.5)
            end
        end
    else
        GameTooltip:AddLine(LT("NOT_COLLECTED", "Not collected"), 1, 0, 0)
    end
    
    -- Favorite status
    if item.is_favorite then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("★ " .. LT("FAVORITE", "Favorite"), 1, 0.82, 0)
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(LT("RIGHT_CLICK_MENU", "Right-click for options"), 0.5, 0.5, 0.5)
    
    GameTooltip:Show()
end

-- ============================================================================
-- SHOP CONTENT
-- ============================================================================

function DC:ShowShopContent()
    -- Request shop items if not loaded
    if not self.shopItems or #self.shopItems == 0 then
        self:RequestShopItems()
    end
    
    self:RefreshCurrentTab()
end
