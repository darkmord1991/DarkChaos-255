--[[
    DC-Collection UI/MainFrame.lua
    ==============================
    
    Main collection window frame with tabs and content areas.
    
    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC.L

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
    header.statsText:SetPoint("LEFT", header, "LEFT", 5, 0)
    header.statsText:SetJustifyH("LEFT")
    
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
        { key = "toys",      text = L["TAB_TOYS"],      icon = "Interface\\Icons\\INV_Misc_Toy_10" },
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
    
    parent.FilterBar = filterBar
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
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "DCCollectionScrollFrame", content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -25, 5)
    
    -- Scroll child (content container)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)  -- Height will be set dynamically
    scrollFrame:SetScrollChild(scrollChild)
    
    content.scrollFrame = scrollFrame
    content.scrollChild = scrollChild
    
    parent.Content = content
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
    
    -- Update tab visuals
    for key, tab in pairs(self.MainFrame.TabBar.tabs) do
        tab:SetChecked(key == tabKey)
    end
    
    -- Clear current page
    self.currentPage = 1
    
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
        header.statsText:SetText(string.format("%s: %d / %d", 
            L["TAB_" .. string.upper(self.activeTab)] or self.activeTab,
            stats.owned or 0, 
            stats.total or 0))
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
    self.MainFrame.Footer.prevBtn:SetEnabled(self.currentPage > 1)
    self.MainFrame.Footer.nextBtn:SetEnabled(self.currentPage < totalPages)
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
    local r, g, b = unpack(self.RARITY_COLORS[rarity] or {1, 1, 1})
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
    
    for id, def in pairs(definitions) do
        local collData = collection[id]
        local isCollected = collData ~= nil
        
        -- Filter by collected state
        if (isCollected and showCollected) or (not isCollected and showNotCollected) then
            -- Filter by search
            local name = string.lower(def.name or "")
            if searchText == "" or string.find(name, searchText, 1, true) then
                table.insert(items, {
                    id = id,
                    name = def.name,
                    icon = def.icon,
                    rarity = def.rarity,
                    source = def.source,
                    type = collType,
                    collected = isCollected,
                    is_favorite = collData and collData.is_favorite,
                    collectionData = collData,
                    definition = def,
                })
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
            return (a.source or "") < (b.source or "")
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
    if not item.collected then
        -- Not collected - show where to get it
        return
    end
    
    if item.type == "mounts" then
        self:RequestSummonMount(item.id)
    elseif item.type == "pets" then
        self:RequestSummonPet(item.id)
    elseif item.type == "toys" then
        self:RequestUseToy(item.id)
    elseif item.type == "heirlooms" then
        self:RequestSummonHeirloom(item.id)
    elseif item.type == "titles" then
        self:RequestSetTitle(item.id)
    end
end

function DC:OnItemRightClick(item)
    -- Show context menu
    local menu = {
        { text = item.name, isTitle = true, notCheckable = true },
    }
    
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
    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
    
    -- Name with rarity color
    local r, g, b = unpack(self.RARITY_COLORS[item.rarity or 1] or {1, 1, 1})
    GameTooltip:AddLine(item.name or "Unknown", r, g, b)
    
    -- Type
    if item.definition and item.definition.mountType then
        local mountTypes = { [1] = "Ground", [2] = "Flying", [3] = "Aquatic" }
        GameTooltip:AddLine(mountTypes[item.definition.mountType] or "Mount", 1, 1, 1)
    end
    
    -- Source
    if item.source then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["SOURCE"] .. ": " .. item.source, 0.7, 0.7, 0.7)
    end
    
    -- Collection status
    GameTooltip:AddLine(" ")
    if item.collected then
        GameTooltip:AddLine(L["COLLECTED"], 0, 1, 0)
        
        -- Usage instructions
        if item.type == "mounts" then
            GameTooltip:AddLine(L["CLICK_SUMMON"], 0.5, 0.5, 0.5)
        elseif item.type == "pets" then
            GameTooltip:AddLine(L["CLICK_SUMMON"], 0.5, 0.5, 0.5)
        elseif item.type == "toys" then
            GameTooltip:AddLine("Click to use", 0.5, 0.5, 0.5)
        elseif item.type == "heirlooms" then
            GameTooltip:AddLine("Click to summon to bags", 0.5, 0.5, 0.5)
        elseif item.type == "titles" then
            GameTooltip:AddLine("Click to set as active title", 0.5, 0.5, 0.5)
        end
    else
        GameTooltip:AddLine(L["NOT_COLLECTED"], 1, 0, 0)
    end
    
    -- Favorite status
    if item.is_favorite then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("★ " .. L["FAVORITE"], 1, 0.82, 0)
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["RIGHT_CLICK_MENU"], 0.5, 0.5, 0.5)
    
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
