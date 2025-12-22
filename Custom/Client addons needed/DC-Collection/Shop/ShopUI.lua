--[[
    DC-Collection Shop/ShopUI.lua
    ==============================
    
    Collection Shop UI - browse and purchase items.
    
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

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local SHOP_FRAME_WIDTH = 680
local SHOP_FRAME_HEIGHT = 450
local ITEM_HEIGHT = 70
local ITEMS_PER_PAGE = 5

-- ============================================================================
-- SHOP UI CREATION
-- ============================================================================

function DC:CreateShopUI()
    if self.ShopUI then
        return self.ShopUI
    end
    
    local frame = CreateFrame("Frame", "DCCollectionShopFrame", self.MainFrame)
    frame:SetAllPoints(self.MainFrame.Content)
    frame:Hide()
    
    -- Header with currency
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    header:SetHeight(40)
    
    -- Currency display
    local currencyFrame = CreateFrame("Frame", nil, header)
    currencyFrame:SetPoint("RIGHT", header, "RIGHT", -10, 0)
    currencyFrame:SetSize(250, 30)
    
    -- Get icons from DCCentral if available, else use fallback
    local central = rawget(_G, "DCAddonProtocol")
    local tokenIcon = (central and central.GetTokenIcon and central:GetTokenIcon(central.TOKEN_ITEM_ID or 300311))
                      or "Interface\\Icons\\INV_Misc_Token_ArgentCrusade"
    local emblemIcon = (central and central.GetTokenIcon and central:GetTokenIcon(central.ESSENCE_ITEM_ID or 300312))
                       or "Interface\\Icons\\INV_Misc_Herb_Draenethisle"
    
    -- Tokens
    local tokensIcon = currencyFrame:CreateTexture(nil, "ARTWORK")
    tokensIcon:SetSize(20, 20)
    tokensIcon:SetPoint("LEFT", currencyFrame, "LEFT", 0, 0)
    tokensIcon:SetTexture(tokenIcon)
    
    local tokensLabel = currencyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tokensLabel:SetPoint("LEFT", tokensIcon, "RIGHT", 5, 0)
    tokensLabel:SetText(L["TOKENS"] or "Tokens:")
    
    local tokensValue = currencyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tokensValue:SetPoint("LEFT", tokensLabel, "RIGHT", 5, 0)
    tokensValue:SetText("0")
    frame.tokensValue = tokensValue
    
    -- Emblems
    local emblemsIcon = currencyFrame:CreateTexture(nil, "ARTWORK")
    emblemsIcon:SetSize(20, 20)
    emblemsIcon:SetPoint("LEFT", tokensValue, "RIGHT", 20, 0)
    emblemsIcon:SetTexture(emblemIcon)
    
    local emblemsLabel = currencyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emblemsLabel:SetPoint("LEFT", emblemsIcon, "RIGHT", 5, 0)
    emblemsLabel:SetText(L["EMBLEMS"] or "Emblems:")
    
    local emblemsValue = currencyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emblemsValue:SetPoint("LEFT", emblemsLabel, "RIGHT", 5, 0)
    emblemsValue:SetText("0")
    frame.emblemsValue = emblemsValue
    
    -- Filter buttons
    local filterFrame = CreateFrame("Frame", nil, header)
    filterFrame:SetPoint("LEFT", header, "LEFT", 5, 0)
    filterFrame:SetSize(300, 30)
    
    local filterButtons = {
        { key = "all",    text = L["FILTER_ALL"] or "All" },
        { key = "bonus",  text = L["SHOP_TYPE_BONUS"] or "Bonuses" },
        { key = "mount",  text = L["SHOP_TYPE_MOUNT"] or "Mounts" },
        { key = "pet",    text = L["SHOP_TYPE_PET"] or "Pets" },
    }
    
    frame.filterButtons = {}
    local xOffset = 0
    for _, filterInfo in ipairs(filterButtons) do
        local btn = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
        btn:SetSize(65, 22)
        btn:SetPoint("LEFT", filterFrame, "LEFT", xOffset, 0)
        btn:SetText(filterInfo.text)
        btn.key = filterInfo.key
        
        btn:SetScript("OnClick", function(self)
            DC:SetShopFilter(filterInfo.key)
        end)
        
        frame.filterButtons[filterInfo.key] = btn
        xOffset = xOffset + 70
    end
    
    frame.currentFilter = "all"
    
    -- Item list scroll frame
    local listFrame = CreateFrame("Frame", nil, frame)
    listFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -5)
    listFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 35)
    
    local scrollFrame = CreateFrame("ScrollFrame", "DCShopScrollFrame", listFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -25, 5)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    frame.scrollFrame = scrollFrame
    frame.scrollChild = scrollChild
    frame.itemFrames = {}
    
    -- Pre-create item frames
    for i = 1, 10 do
        frame.itemFrames[i] = self:CreateShopItemFrame(scrollChild, i)
    end
    
    -- Page navigation
    local navFrame = CreateFrame("Frame", nil, frame)
    navFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 5, 5)
    navFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
    navFrame:SetHeight(25)
    
    local prevBtn = CreateFrame("Button", nil, navFrame, "UIPanelButtonTemplate")
    prevBtn:SetSize(60, 22)
    prevBtn:SetPoint("LEFT", navFrame, "LEFT", 0, 0)
    prevBtn:SetText("<")
    prevBtn:SetScript("OnClick", function()
        DC:ShopPrevPage()
    end)
    frame.prevBtn = prevBtn
    
    local pageText = navFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pageText:SetPoint("CENTER", navFrame, "CENTER", 0, 0)
    pageText:SetText("Page 1 of 1")
    frame.pageText = pageText
    
    local nextBtn = CreateFrame("Button", nil, navFrame, "UIPanelButtonTemplate")
    nextBtn:SetSize(60, 22)
    nextBtn:SetPoint("RIGHT", navFrame, "RIGHT", 0, 0)
    nextBtn:SetText(">")
    nextBtn:SetScript("OnClick", function()
        DC:ShopNextPage()
    end)
    frame.nextBtn = nextBtn
    
    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, navFrame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(80, 22)
    refreshBtn:SetPoint("RIGHT", nextBtn, "LEFT", -10, 0)
    refreshBtn:SetText(L["REFRESH"] or "Refresh")
    refreshBtn:SetScript("OnClick", function()
        DC.ShopModule:RefreshShopItems()
        DC.ShopModule:RefreshCurrency()
    end)
    
    self.ShopUI = frame
    frame.currentPage = 1
    
    return frame
end

-- ============================================================================
-- SHOP ITEM FRAME
-- ============================================================================

function DC:CreateShopItemFrame(parent, index)
    local frame = CreateFrame("Button", nil, parent)
    frame:SetSize(parent:GetWidth() - 10, ITEM_HEIGHT)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -((index - 1) * (ITEM_HEIGHT + 5)))
    
    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetTexture(0.1, 0.1, 0.1, 0.8)
    
    -- Highlight
    frame.highlight = frame:CreateTexture(nil, "HIGHLIGHT")
    frame.highlight:SetAllPoints()
    frame.highlight:SetTexture(0.3, 0.3, 0.3, 0.5)
    
    -- Icon
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(50, 50)
    frame.icon:SetPoint("LEFT", frame, "LEFT", 10, 0)
    frame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    
    -- Name
    frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.name:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, -5)
    frame.name:SetWidth(300)
    frame.name:SetJustifyH("LEFT")
    frame.name:SetText("Item Name")
    
    -- Description
    frame.desc = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.desc:SetPoint("TOPLEFT", frame.name, "BOTTOMLEFT", 0, -3)
    frame.desc:SetWidth(300)
    frame.desc:SetJustifyH("LEFT")
    frame.desc:SetTextColor(0.7, 0.7, 0.7)
    frame.desc:SetText("Item description")
    
    -- Type badge
    frame.typeBadge = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.typeBadge:SetPoint("TOPLEFT", frame.desc, "BOTTOMLEFT", 0, -3)
    frame.typeBadge:SetTextColor(0.5, 0.8, 1)
    frame.typeBadge:SetText("[Bonus]")
    
    -- Cost (get icons from DCCentral if available)
    local central = rawget(_G, "DCAddonProtocol")
    local itemTokenIcon = (central and central.GetTokenIcon and central:GetTokenIcon(central.TOKEN_ITEM_ID or 300311))
                          or "Interface\\Icons\\INV_Misc_Token_ArgentCrusade"
    local itemEmblemIcon = (central and central.GetTokenIcon and central:GetTokenIcon(central.ESSENCE_ITEM_ID or 300312))
                           or "Interface\\Icons\\INV_Misc_Herb_Draenethisle"
    
    frame.costFrame = CreateFrame("Frame", nil, frame)
    frame.costFrame:SetSize(120, 40)
    frame.costFrame:SetPoint("RIGHT", frame, "RIGHT", -90, 0)
    
    frame.costTokensIcon = frame.costFrame:CreateTexture(nil, "ARTWORK")
    frame.costTokensIcon:SetSize(16, 16)
    frame.costTokensIcon:SetPoint("TOPLEFT", frame.costFrame, "TOPLEFT", 0, 0)
    frame.costTokensIcon:SetTexture(itemTokenIcon)
    
    frame.costTokensText = frame.costFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.costTokensText:SetPoint("LEFT", frame.costTokensIcon, "RIGHT", 3, 0)
    frame.costTokensText:SetText("0")
    
    frame.costEmblemsIcon = frame.costFrame:CreateTexture(nil, "ARTWORK")
    frame.costEmblemsIcon:SetSize(16, 16)
    frame.costEmblemsIcon:SetPoint("TOPLEFT", frame.costTokensIcon, "BOTTOMLEFT", 0, -5)
    frame.costEmblemsIcon:SetTexture(itemEmblemIcon)
    
    frame.costEmblemsText = frame.costFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.costEmblemsText:SetPoint("LEFT", frame.costEmblemsIcon, "RIGHT", 3, 0)
    frame.costEmblemsText:SetText("0")
    
    -- Buy button
    frame.buyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.buyBtn:SetSize(70, 24)
    frame.buyBtn:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    frame.buyBtn:SetText(L["BUY"] or "Buy")
    frame.buyBtn:SetScript("OnClick", function()
        if frame.itemData then
            DC.ShopModule:Purchase(frame.itemData.id)
        end
    end)
    
    -- Purchased indicator
    frame.purchasedText = frame:CreateFontString(nil, "OVERLAY", "GameFontGreen")
    frame.purchasedText:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    frame.purchasedText:SetText(L["PURCHASED"] or "Purchased")
    frame.purchasedText:Hide()
    
    frame:Hide()
    return frame
end

-- ============================================================================
-- UI UPDATES
-- ============================================================================

function DC:UpdateShopUI()
    if not self.ShopUI or not self.ShopUI:IsShown() then
        return
    end
    
    self:UpdateShopCurrencyDisplay()
    self:PopulateShopItems()
end

function DC:UpdateShopCurrencyDisplay()
    if not self.ShopUI then return end
    
    self.ShopUI.tokensValue:SetText(self.currency.tokens or 0)
    self.ShopUI.emblemsValue:SetText(self.currency.emblems or 0)
end

function DC:PopulateShopItems()
    if not self.ShopUI then return end
    
    local frame = self.ShopUI
    local filter = frame.currentFilter
    
    -- Get filtered items
    local filters = {}
    if filter ~= "all" then
        local typeMap = {
            bonus = 1,
            mount = 2,
            pet = 3,
        }
        filters.itemType = typeMap[filter]
    end
    
    local items = self.ShopModule:GetFilteredShopItems(filters)
    
    -- Pagination
    local totalPages = math.max(1, math.ceil(#items / ITEMS_PER_PAGE))
    frame.currentPage = math.min(frame.currentPage, totalPages)
    
    local startIdx = (frame.currentPage - 1) * ITEMS_PER_PAGE + 1
    local endIdx = math.min(startIdx + ITEMS_PER_PAGE - 1, #items)
    
    -- Hide all frames first
    for i, itemFrame in ipairs(frame.itemFrames) do
        itemFrame:Hide()
    end
    
    -- Populate visible items
    local frameIdx = 1
    for i = startIdx, endIdx do
        local item = items[i]
        local itemFrame = frame.itemFrames[frameIdx]
        
        if itemFrame and item then
            self:UpdateShopItemFrame(itemFrame, item)
            itemFrame:Show()
            frameIdx = frameIdx + 1
        end
    end
    
    -- Update scroll child height
    frame.scrollChild:SetHeight((endIdx - startIdx + 1) * (ITEM_HEIGHT + 5))
    
    -- Update page navigation
    frame.pageText:SetText(string.format("Page %d of %d", frame.currentPage, totalPages))
    SetWidgetEnabled(frame.prevBtn, frame.currentPage > 1)
    SetWidgetEnabled(frame.nextBtn, frame.currentPage < totalPages)
    
    -- Update filter button states
    for key, btn in pairs(frame.filterButtons) do
        if key == filter then
            btn:SetButtonState("PUSHED", true)
        else
            btn:SetButtonState("NORMAL", false)
        end
    end
end

function DC:UpdateShopItemFrame(frame, item)
    frame.itemData = item
    
    -- Icon
    frame.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    
    -- Name with rarity color
    local r, g, b = unpack(self.RARITY_COLORS[item.rarity or 2] or {1, 1, 1})
    frame.name:SetText(item.name or "Unknown")
    frame.name:SetTextColor(r, g, b)
    
    -- Description
    frame.desc:SetText(item.description or "")
    
    -- Type badge
    local typeStr = self.ShopModule:GetItemTypeString(item.itemType)
    frame.typeBadge:SetText("[" .. typeStr .. "]")
    
    -- Cost
    if item.costTokens and item.costTokens > 0 then
        frame.costTokensIcon:Show()
        frame.costTokensText:Show()
        frame.costTokensText:SetText(item.costTokens)
    else
        frame.costTokensIcon:Hide()
        frame.costTokensText:Hide()
    end
    
    if item.costEmblems and item.costEmblems > 0 then
        frame.costEmblemsIcon:Show()
        frame.costEmblemsText:Show()
        frame.costEmblemsText:SetText(item.costEmblems)
    else
        frame.costEmblemsIcon:Hide()
        frame.costEmblemsText:Hide()
    end
    
    -- Buy button / Purchased state
    local alreadyPurchased = item.purchased or 
        (item.maxPurchases and item.purchaseCount and item.purchaseCount >= item.maxPurchases)
    
    if alreadyPurchased then
        frame.buyBtn:Hide()
        frame.purchasedText:Show()
    else
        frame.purchasedText:Hide()
        frame.buyBtn:Show()
        
        -- Enable/disable based on affordability
        local canAfford = self.ShopModule:CanAfford(item)
        frame.buyBtn:SetEnabled(canAfford)
        
        if canAfford then
            frame.costTokensText:SetTextColor(1, 1, 1)
            frame.costEmblemsText:SetTextColor(1, 1, 1)
        else
            frame.costTokensText:SetTextColor(1, 0.3, 0.3)
            frame.costEmblemsText:SetTextColor(1, 0.3, 0.3)
        end
    end
end

-- ============================================================================
-- SHOP NAVIGATION
-- ============================================================================

function DC:SetShopFilter(filter)
    if not self.ShopUI then return end
    
    self.ShopUI.currentFilter = filter
    self.ShopUI.currentPage = 1
    self:PopulateShopItems()
end

function DC:ShopNextPage()
    if not self.ShopUI then return end
    
    self.ShopUI.currentPage = self.ShopUI.currentPage + 1
    self:PopulateShopItems()
end

function DC:ShopPrevPage()
    if not self.ShopUI then return end
    
    self.ShopUI.currentPage = math.max(1, self.ShopUI.currentPage - 1)
    self:PopulateShopItems()
end

-- ============================================================================
-- SHOW/HIDE
-- ============================================================================

function DC:ShowShop()
    if not self.MainFrame then
        self:CreateMainFrame()
    end
    
    if not self.ShopUI then
        self:CreateShopUI()
    end
    
    -- Select shop tab
    self:SelectTab("shop")
    
    -- Show shop UI in content area
    self.ShopUI:Show()
    
    -- Request fresh data
    self.ShopModule:RefreshShopItems()
    self.ShopModule:RefreshCurrency()
    
    self:UpdateShopUI()
end

function DC:HideShop()
    if self.ShopUI then
        self.ShopUI:Hide()
    end
end

-- Override content display for shop tab
function DC:ShowShopContent()
    if not self.ShopUI then
        self:CreateShopUI()
    end
    
    self.ShopUI:Show()
    self:UpdateShopUI()
end
