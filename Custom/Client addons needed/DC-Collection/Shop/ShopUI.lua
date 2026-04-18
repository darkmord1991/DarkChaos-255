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
local HISTORY_ROW_HEIGHT = 42
local HISTORY_ITEMS_PER_PAGE = 8

local function IsNumericIconPath(texturePath)
    if type(texturePath) ~= "string" then
        return false
    end

    local normalized = string.gsub(texturePath, "/", "\\")
    local lowerPath = string.lower(normalized)
    return string.match(lowerPath, "^interface\\icons\\%d+$") ~= nil
end

local function FormatShopHistoryDate(ts)
    local n = tonumber(ts)
    if not n or n <= 0 then
        return "-"
    end

    return date("%Y-%m-%d %H:%M", n)
end

local function NormalizeShopPreviewType(item)
    if type(item) ~= "table" then
        return nil
    end

    local typeName = item.collectionTypeName or item.collectionType or item.typeName
    if type(typeName) == "string" then
        local t = string.lower(typeName)
        if t == "mount" or t == "mounts" then return "mount" end
        if t == "pet" or t == "pets" then return "pet" end
        if t == "heirloom" or t == "heirlooms" then return "heirloom" end
        if t == "transmog" or t == "appearance" or t == "appearances" then return "transmog" end
        if t == "title" or t == "titles" then return "title" end
        if t == "bonus" then return "bonus" end
    end

    local collectionTypeId = tonumber(item.collectionTypeId or item.type)
    if collectionTypeId == 1 then return "mount" end
    if collectionTypeId == 2 then return "pet" end
    if collectionTypeId == 3 then return "bonus" end
    if collectionTypeId == 4 then return "heirloom" end
    if collectionTypeId == 5 then return "title" end
    if collectionTypeId == 6 then return "transmog" end

    local itemType = tonumber(item.itemType)
    local types = DC.SHOP_ITEM_TYPES or {}
    if itemType == tonumber(types.MOUNT or 2) then return "mount" end
    if itemType == tonumber(types.PET or 3) then return "pet" end
    if itemType == tonumber(types.HEIRLOOM or 5) then return "heirloom" end
    if itemType == tonumber(types.BONUS or 1) then return "bonus" end

    return nil
end

local function ResolveShopItemIcon(item, rawIcon)
    if type(item) ~= "table" then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    local icon = DC:NormalizeTexturePath(rawIcon, nil)
    if IsNumericIconPath(icon) then
        icon = nil
    end

    local previewType = NormalizeShopPreviewType(item)
    local definition = item.definition

    if (not definition) and type(DC.GetDefinition) == "function" then
        local entryId = tonumber(item.entryId or item.entry or item.spellId or item.spell)
        if entryId then
            if previewType == "mount" then
                definition = DC:GetDefinition("mounts", entryId)
            elseif previewType == "pet" then
                definition = DC:GetDefinition("pets", entryId)
            elseif previewType == "heirloom" then
                definition = DC:GetDefinition("heirlooms", entryId)
            elseif previewType == "transmog" then
                definition = DC:GetDefinition("transmog", entryId)
            end

            if definition then
                item.definition = definition
            end
        end
    end

    local spellId = tonumber(item.spellId or item.spellID or item.spell_id)
    local itemId = tonumber(item.itemId or item.itemID or item.item_id)

    if definition then
        if not spellId then
            spellId = tonumber(definition.spellId or definition.spellID or definition.spell_id)
        end
        if not itemId then
            itemId = tonumber(definition.itemId or definition.itemID or definition.item_id)
        end

        if (not icon or icon == "") and definition.icon then
            icon = DC:NormalizeTexturePath(definition.icon, nil)
            if IsNumericIconPath(icon) then
                icon = nil
            end
        end
    end

    if (not spellId) then
        spellId = tonumber(item.entryId or item.entry_id or item.entry)
    end
    if (not itemId) then
        itemId = tonumber(item.entryId or item.entry_id or item.entry)
    end

    if (previewType == "mount" or previewType == "pet") and (not icon or icon == "") then
        if spellId and type(GetSpellTexture) == "function" then
            icon = GetSpellTexture(spellId)
        end
    end

    if (not icon or icon == "") and itemId then
        if type(GetItemIcon) == "function" then
            icon = GetItemIcon(itemId)
        end
        if (not icon or icon == "") and type(GetItemInfo) == "function" then
            icon = select(10, GetItemInfo(itemId))
        end
    end

    if (not icon or icon == "") and previewType == "title" then
        icon = "Interface\\Icons\\INV_Scroll_11"
    end

    local finalIcon = DC:NormalizeTexturePath(icon, nil)
    if IsNumericIconPath(finalIcon) then
        finalIcon = nil
    end

    return finalIcon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function TryDressUpItemId(itemId)
    local resolvedId = tonumber(itemId)
    if not resolvedId or resolvedId <= 0 then
        return false
    end

    local link = "item:" .. tostring(resolvedId)

    if DressUpModel and DressUpModel.TryOn then
        if DressUpFrame and DressUpFrame.Show then
            DressUpFrame:Show()
        end
        if DressUpModel.Undress then
            pcall(DressUpModel.Undress, DressUpModel)
        end
        local ok = pcall(DressUpModel.TryOn, DressUpModel, link)
        if ok then
            return true
        end
    end

    if DressUpItemLink then
        local ok = pcall(DressUpItemLink, link)
        if ok then
            return true
        end
    end

    return false
end

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
        tokenIcon = DC:NormalizeTexturePath(tokenIcon, "Interface\\Icons\\INV_Misc_Token_ArgentCrusade")

        local essenceIcon = (central and central.GetTokenIcon and central:GetTokenIcon(central.ESSENCE_ITEM_ID or 300312))
        essenceIcon = DC:NormalizeTexturePath(essenceIcon, "Interface\\Icons\\INV_Misc_Herb_Draenethisle")
    
    -- Tokens
    local tokensIcon = currencyFrame:CreateTexture(nil, "ARTWORK")
    tokensIcon:SetSize(20, 20)
    tokensIcon:SetPoint("LEFT", currencyFrame, "LEFT", 0, 0)
    tokensIcon:SetTexture(tokenIcon)
    
    local tokensLabel = currencyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tokensLabel:SetPoint("LEFT", tokensIcon, "RIGHT", 5, 0)
        tokensLabel:SetText((L and L.CURRENCY_TOKENS) and (L.CURRENCY_TOKENS .. ":") or "Tokens:")
    
    local tokensValue = currencyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tokensValue:SetPoint("LEFT", tokensLabel, "RIGHT", 5, 0)
    tokensValue:SetText("0")
    frame.tokensValue = tokensValue
    
    -- Emblems
    local emblemsIcon = currencyFrame:CreateTexture(nil, "ARTWORK")
    emblemsIcon:SetSize(20, 20)
    emblemsIcon:SetPoint("LEFT", tokensValue, "RIGHT", 20, 0)
        emblemsIcon:SetTexture(essenceIcon)
    
    local emblemsLabel = currencyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emblemsLabel:SetPoint("LEFT", emblemsIcon, "RIGHT", 5, 0)
        emblemsLabel:SetText((L and L.CURRENCY_EMBLEMS) and (L.CURRENCY_EMBLEMS .. ":") or "Essence:")
    
    local emblemsValue = currencyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emblemsValue:SetPoint("LEFT", emblemsLabel, "RIGHT", 5, 0)
    emblemsValue:SetText("0")
    frame.emblemsValue = emblemsValue
    
    -- View buttons
    local viewFrame = CreateFrame("Frame", nil, header)
    viewFrame:SetPoint("LEFT", header, "LEFT", 5, 0)
    viewFrame:SetSize(80, 30)

    local storeBtn = CreateFrame("Button", nil, viewFrame, "UIPanelButtonTemplate")
    storeBtn:SetSize(72, 22)
    storeBtn:SetPoint("LEFT", viewFrame, "LEFT", 0, 0)
    storeBtn:SetText(L["SHOP_TAB_STORE"] or "Store")
    storeBtn:SetScript("OnClick", function()
        DC:SetShopView("shop")
    end)

    -- Filter buttons (shop view)
    local filterFrame = CreateFrame("Frame", nil, header)
    filterFrame:SetPoint("LEFT", viewFrame, "RIGHT", 8, 0)
    filterFrame:SetSize(300, 30)
    frame.filterFrame = filterFrame
    
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

    -- Keep history to the right so it doesn't look like a normal item filter.
    local historyBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    historyBtn:SetSize(72, 22)
    historyBtn:SetPoint("LEFT", filterFrame, "LEFT", xOffset + 6, 0)
    historyBtn:SetText(L["SHOP_TAB_HISTORY"] or "History")
    historyBtn:SetNormalFontObject("GameFontHighlight")
    historyBtn:SetHighlightFontObject("GameFontHighlight")
    historyBtn:SetDisabledFontObject("GameFontDisable")
    if historyBtn.GetFontString then
        local fs = historyBtn:GetFontString()
        if fs then
            fs:SetTextColor(0.95, 0.72, 0.25)
        end
    end
    historyBtn:SetScript("OnClick", function()
        DC:SetShopView("history")
    end)

    frame.viewButtons = {
        shop = storeBtn,
        history = historyBtn,
    }
    frame.activeView = "shop"
    
    frame.currentFilter = "all"
    
    -- Item list scroll frame (store view)
    local listFrame = CreateFrame("Frame", nil, frame)
    listFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -5)
    listFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 35)
    frame.listFrame = listFrame
    
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

    -- History list scroll frame (history view)
    local historyListFrame = CreateFrame("Frame", nil, frame)
    historyListFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -5)
    historyListFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 35)
    historyListFrame:Hide()
    frame.historyListFrame = historyListFrame

    local historyScrollFrame = CreateFrame(
        "ScrollFrame",
        "DCShopHistoryScrollFrame",
        historyListFrame,
        "UIPanelScrollFrameTemplate"
    )
    historyScrollFrame:SetPoint("TOPLEFT", historyListFrame, "TOPLEFT", 5, -5)
    historyScrollFrame:SetPoint("BOTTOMRIGHT", historyListFrame, "BOTTOMRIGHT", -25, 5)

    local historyScrollChild = CreateFrame("Frame", nil, historyScrollFrame)
    historyScrollChild:SetSize(historyScrollFrame:GetWidth(), 1)
    historyScrollFrame:SetScrollChild(historyScrollChild)

    frame.historyScrollFrame = historyScrollFrame
    frame.historyScrollChild = historyScrollChild
    frame.historyRows = {}

    for i = 1, HISTORY_ITEMS_PER_PAGE do
        frame.historyRows[i] = self:CreateShopHistoryRow(historyScrollChild, i)
    end

    local historyEmptyText = historyListFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    historyEmptyText:SetPoint("CENTER", historyListFrame, "CENTER", 0, 0)
    historyEmptyText:SetText(L["SHOP_HISTORY_EMPTY"] or "No purchases yet.")
    historyEmptyText:SetTextColor(0.75, 0.75, 0.75)
    historyEmptyText:Hide()
    frame.historyEmptyText = historyEmptyText
    
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
        if frame.activeView == "history" then
            if DC.ShopModule and type(DC.ShopModule.RefreshPurchaseHistory) == "function" then
                DC.ShopModule:RefreshPurchaseHistory()
            elseif type(DC.RequestShopHistory) == "function" then
                DC:RequestShopHistory()
            end
        else
            DC.ShopModule:RefreshShopItems()
        end

        DC.ShopModule:RefreshCurrency()
    end)
    frame.refreshBtn = refreshBtn
    
    self.ShopUI = frame
    frame.currentPage = 1
    frame.historyPage = 1

    -- Compatibility: Protocol may call ShopUI:UpdateCurrencyDisplay()
    function frame:UpdateCurrencyDisplay()
        DC:UpdateShopCurrencyDisplay()
    end

    self:UpdateShopViewState()
    
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
    itemTokenIcon = DC:NormalizeTexturePath(itemTokenIcon, "Interface\\Icons\\INV_Misc_Token_ArgentCrusade")

    local itemEssenceIcon = (central and central.GetTokenIcon and central:GetTokenIcon(central.ESSENCE_ITEM_ID or 300312))
    itemEssenceIcon = DC:NormalizeTexturePath(itemEssenceIcon, "Interface\\Icons\\INV_Misc_Herb_Draenethisle")
    
    frame.costFrame = CreateFrame("Frame", nil, frame)
    frame.costFrame:SetSize(120, 40)
    frame.costFrame:SetPoint("RIGHT", frame, "RIGHT", -170, 0)
    
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
    frame.costEmblemsIcon:SetTexture(itemEssenceIcon)
    
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

    -- Preview button
    frame.previewBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.previewBtn:SetSize(70, 24)
    frame.previewBtn:SetPoint("RIGHT", frame.buyBtn, "LEFT", -6, 0)
    frame.previewBtn:SetText(L["PREVIEW"] or "Preview")
    frame.previewBtn:SetScript("OnClick", function()
        if frame.itemData then
            DC:PreviewShopItem(frame.itemData)
        end
    end)

    frame.costFrame:ClearAllPoints()
    frame.costFrame:SetPoint("RIGHT", frame.previewBtn, "LEFT", -10, 0)
    
    -- Purchased indicator
    frame.purchasedText = frame:CreateFontString(nil, "OVERLAY", "GameFontGreen")
    frame.purchasedText:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    frame.purchasedText:SetText(L["PURCHASED"] or "Purchased")
    frame.purchasedText:Hide()
    
    frame:Hide()
    return frame
end

function DC:CreateShopHistoryRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(parent:GetWidth() - 10, HISTORY_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -((index - 1) * (HISTORY_ROW_HEIGHT + 4)))

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    if (index % 2) == 0 then
        row.bg:SetTexture(0.12, 0.12, 0.12, 0.70)
    else
        row.bg:SetTexture(0.09, 0.09, 0.09, 0.70)
    end

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -5)
    row.name:SetWidth(330)
    row.name:SetJustifyH("LEFT")
    row.name:SetText("-")

    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.meta:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.meta:SetWidth(360)
    row.meta:SetJustifyH("LEFT")
    row.meta:SetTextColor(0.75, 0.75, 0.75)
    row.meta:SetText("-")

    row.date = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.date:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.date:SetJustifyH("RIGHT")
    row.date:SetTextColor(0.85, 0.85, 0.85)
    row.date:SetText("-")

    row:Hide()
    return row
end

-- ============================================================================
-- UI UPDATES
-- ============================================================================

function DC:UpdateShopUI()
    if not self.ShopUI or not self.ShopUI:IsShown() then
        return
    end

    self:UpdateShopCurrencyDisplay()
    self:UpdateShopViewState()

    if self.ShopUI.activeView == "history" then
        self:PopulateShopHistory()
    else
        self:PopulateShopItems()
    end
end

function DC:UpdateShopViewState()
    if not self.ShopUI then
        return
    end

    local frame = self.ShopUI
    local showHistory = frame.activeView == "history"

    if frame.listFrame then
        if showHistory then
            frame.listFrame:Hide()
        else
            frame.listFrame:Show()
        end
    end

    if frame.historyListFrame then
        if showHistory then
            frame.historyListFrame:Show()
        else
            frame.historyListFrame:Hide()
        end
    end

    if frame.filterFrame then
        if showHistory then
            frame.filterFrame:Hide()
        else
            frame.filterFrame:Show()
        end
    end

    if frame.viewButtons then
        for key, btn in pairs(frame.viewButtons) do
            if key == frame.activeView then
                btn:SetButtonState("PUSHED", true)
            else
                btn:SetButtonState("NORMAL", false)
            end
        end

        local shopBtn = frame.viewButtons.shop
        if shopBtn and shopBtn.GetFontString then
            local shopFs = shopBtn:GetFontString()
            if shopFs then
                if frame.activeView == "shop" then
                    shopFs:SetTextColor(1.0, 1.0, 1.0)
                else
                    shopFs:SetTextColor(0.82, 0.82, 0.82)
                end
            end
        end

        local historyBtn = frame.viewButtons.history
        if historyBtn and historyBtn.GetFontString then
            local historyFs = historyBtn:GetFontString()
            if historyFs then
                if frame.activeView == "history" then
                    historyFs:SetTextColor(1.0, 0.90, 0.35)
                else
                    historyFs:SetTextColor(0.95, 0.72, 0.25)
                end
            end
        end
    end
end

function DC:UpdateShopCurrencyDisplay()
    if not self.ShopUI then return end

    local tokens, essence = (type(self.GetCurrencyBalances) == "function") and self:GetCurrencyBalances() or nil
    tokens = tonumber(tokens) or (self.currency and self.currency.tokens) or 0
    essence = tonumber(essence) or (self.currency and self.currency.emblems) or 0
    
        self.ShopUI.tokensValue:SetText(tokens)
        self.ShopUI.emblemsValue:SetText(essence)
end

function DC:CanPreviewShopItem(item)
    if type(item) ~= "table" then
        return false
    end

    local previewType = NormalizeShopPreviewType(item)
    local definition = item.definition

    if (not definition) and type(self.GetDefinition) == "function" then
        local entryId = tonumber(item.entryId or item.entry or item.spellId or item.spell)
        if entryId then
            if previewType == "mount" then
                definition = self:GetDefinition("mounts", entryId)
            elseif previewType == "pet" then
                definition = self:GetDefinition("pets", entryId)
            elseif previewType == "heirloom" then
                definition = self:GetDefinition("heirlooms", entryId)
            elseif previewType == "transmog" then
                definition = self:GetDefinition("transmog", entryId)
            end
        end
    end

    if previewType == "mount" then
        local spellId = tonumber(item.spellId or item.entryId or item.entry or (definition and (definition.spellId or definition.spell_id)))
        local displayId = definition and (definition.displayId or definition.display_id or definition.creatureDisplayId)
        local creatureId = definition and (definition.creatureId or definition.creature_id)
        return (spellId and spellId > 0) or (tonumber(displayId) or 0) > 0 or (tonumber(creatureId) or 0) > 0
    elseif previewType == "pet" then
        local petId = tonumber(item.entryId or item.spellId or item.itemId or (definition and (definition.spellId or definition.spell_id)))
        local displayId = definition and (definition.displayId or definition.display_id or definition.creatureDisplayId)
        return (petId and petId > 0) or (tonumber(displayId) or 0) > 0
    elseif previewType == "transmog" then
        local appearanceId = tonumber(item.appearanceId or item.appearance_id)
        local itemId = tonumber(item.itemId or item.itemID or item.item_id)
        return (appearanceId and appearanceId > 0) or (itemId and itemId > 0)
    elseif previewType == "heirloom" then
        local itemId = tonumber(item.itemId or item.itemID or item.item_id or item.entryId)
        return (itemId and itemId > 0) and true or false
    end

    local fallbackItemId = tonumber(item.itemId or item.itemID or item.item_id)
    return (fallbackItemId and fallbackItemId > 0) and true or false
end

function DC:PreviewShopItem(item)
    if type(item) ~= "table" then
        return
    end

    local previewType = NormalizeShopPreviewType(item)
    local definition = item.definition

    if (not definition) and type(self.GetDefinition) == "function" then
        local entryId = tonumber(item.entryId or item.entry or item.spellId or item.spell)
        if entryId then
            if previewType == "mount" then
                definition = self:GetDefinition("mounts", entryId)
            elseif previewType == "pet" then
                definition = self:GetDefinition("pets", entryId)
            elseif previewType == "heirloom" then
                definition = self:GetDefinition("heirlooms", entryId)
            elseif previewType == "transmog" then
                definition = self:GetDefinition("transmog", entryId)
            end
        end
        if definition then
            item.definition = definition
        end
    end

    if previewType == "mount" then
        local spellId = tonumber(item.spellId or item.entryId or item.entry or (definition and (definition.spellId or definition.spell_id)))
        if self.MountJournal and type(self.MountJournal.Show) == "function" and type(self.MountJournal.SelectMount) == "function" and spellId and spellId > 0 then
            local mountData = {
                id = spellId,
                spellId = spellId,
                entryId = spellId,
                name = item.name,
                icon = item.icon,
                rarity = item.rarity,
                source = item.source or "Shop",
                collected = item.collected and true or false,
                definition = definition,
            }
            self.MountJournal:Show()
            self.MountJournal:SelectMount(mountData)
            return
        end

        if TryDressUpItemId(item.itemId or (definition and definition.itemId)) then
            return
        end
    elseif previewType == "pet" then
        local petId = tonumber(item.entryId or item.spellId or item.itemId or (definition and (definition.spellId or definition.spell_id)))
        if self.PetJournal and type(self.PetJournal.Show) == "function" and type(self.PetJournal.SelectPet) == "function" and petId and petId > 0 then
            local petData = {
                id = petId,
                entryId = petId,
                spellId = tonumber(item.spellId) or (definition and tonumber(definition.spellId or definition.spell_id)),
                name = item.name,
                icon = item.icon,
                rarity = item.rarity,
                source = item.source or "Shop",
                collected = item.collected and true or false,
                definition = definition,
            }
            self.PetJournal:Show()
            self.PetJournal:SelectPet(petData)
            return
        end

        if TryDressUpItemId(item.itemId or (definition and definition.itemId)) then
            return
        end
    elseif previewType == "transmog" then
        if type(self.PreviewShopTransmogItem) == "function" then
            self:PreviewShopTransmogItem(item)
            return
        end

        if TryDressUpItemId(item.itemId or (definition and definition.itemId)) then
            return
        end
    elseif previewType == "heirloom" then
        if TryDressUpItemId(item.itemId or (definition and definition.itemId) or item.entryId) then
            return
        end
    else
        if TryDressUpItemId(item.itemId) then
            return
        end
    end

    self:Print(L["PREVIEW_NOT_AVAILABLE"] or "Preview is not available for this item.")
end

-- Compatibility: Protocol.lua may call ShopUI:UpdateCurrencyDisplay()
-- when currency updates arrive.
function DC:PopulateShopItems()
    if not self.ShopUI then return end
    
    local frame = self.ShopUI
    if frame.activeView == "history" then
        return
    end

    if frame.historyEmptyText then
        frame.historyEmptyText:Hide()
    end

    local filter = frame.currentFilter
    
    -- Get filtered items
    local filters = {}
    if filter ~= "all" then
        local typeMap = {
            bonus = (DC.SHOP_ITEM_TYPES and DC.SHOP_ITEM_TYPES.BONUS) or 1,
            mount = (DC.SHOP_ITEM_TYPES and DC.SHOP_ITEM_TYPES.MOUNT) or 2,
            pet = (DC.SHOP_ITEM_TYPES and DC.SHOP_ITEM_TYPES.PET) or 3,
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

function DC:PopulateShopHistory()
    if not self.ShopUI then return end

    local frame = self.ShopUI
    if frame.activeView ~= "history" then
        return
    end

    local history = (self.ShopModule and self.ShopModule.GetPurchaseHistory and self.ShopModule:GetPurchaseHistory()) or {}
    if type(history) ~= "table" then
        history = {}
    end

    local totalPages = math.max(1, math.ceil(#history / HISTORY_ITEMS_PER_PAGE))
    frame.historyPage = math.min(frame.historyPage or 1, totalPages)

    local startIdx = (frame.historyPage - 1) * HISTORY_ITEMS_PER_PAGE + 1
    local endIdx = math.min(startIdx + HISTORY_ITEMS_PER_PAGE - 1, #history)

    for _, row in ipairs(frame.historyRows or {}) do
        row:Hide()
    end

    local rowIndex = 1
    for i = startIdx, endIdx do
        local entry = history[i]
        local row = frame.historyRows and frame.historyRows[rowIndex]
        if row and entry then
            self:UpdateShopHistoryRow(row, entry)
            row:Show()
            rowIndex = rowIndex + 1
        end
    end

    if frame.historyScrollChild then
        local visibleRows = endIdx >= startIdx and (endIdx - startIdx + 1) or 0
        frame.historyScrollChild:SetHeight(math.max(1, visibleRows * (HISTORY_ROW_HEIGHT + 4)))
    end

    local totalKnown = tonumber(self.purchaseHistoryMeta and self.purchaseHistoryMeta.total) or #history
    if #history == 0 then
        frame.pageText:SetText(L["SHOP_HISTORY_EMPTY"] or "No purchases yet.")
        if frame.historyEmptyText then
            frame.historyEmptyText:Show()
        end
    else
        frame.pageText:SetText(string.format("Page %d of %d (%d total)", frame.historyPage, totalPages, totalKnown))
        if frame.historyEmptyText then
            frame.historyEmptyText:Hide()
        end
    end

    SetWidgetEnabled(frame.prevBtn, frame.historyPage > 1)
    SetWidgetEnabled(frame.nextBtn, frame.historyPage < totalPages)
end

function DC:UpdateShopHistoryRow(row, entry)
    if not row or type(entry) ~= "table" then
        return
    end

    row.icon:SetTexture(ResolveShopItemIcon(entry, entry.icon) or "Interface\\Icons\\INV_Misc_Note_01")

    local rarityColors = DC.RarityColors or {}
    local rarity = tonumber(entry.rarity) or 2
    local rarityData = rarityColors[rarity] or { r = 1, g = 1, b = 1 }
    row.name:SetText(entry.name or ("Shop Item #" .. tostring(entry.shopId or "?")))
    row.name:SetTextColor(rarityData.r or 1, rarityData.g or 1, rarityData.b or 1)

    local typeText = (self.ShopModule and self.ShopModule.GetItemTypeString and self.ShopModule:GetItemTypeString(entry)) or "Unknown"
    local costParts = {}
    local costTokens = tonumber(entry.costTokens or entry.priceTokens) or 0
    local costEmblems = tonumber(entry.costEmblems or entry.priceEmblems) or 0
    if costTokens > 0 then
        table.insert(costParts, tostring(costTokens) .. " " .. (L["TOKENS"] or "Tokens"))
    end
    if costEmblems > 0 then
        table.insert(costParts, tostring(costEmblems) .. " " .. (L["EMBLEMS"] or "Emblems"))
    end
    if #costParts == 0 then
        table.insert(costParts, L["FREE"] or "Free")
    end

    local who = entry.characterName
    if type(who) ~= "string" then
        who = ""
    end
    if who ~= "" then
        who = " - " .. who
    end

    row.meta:SetText("[" .. typeText .. "] " .. table.concat(costParts, " + ") .. who)
    row.date:SetText(FormatShopHistoryDate(entry.purchaseDate or entry.purchaseTs))
end

function DC:UpdateShopItemFrame(frame, item)
    frame.itemData = item

    frame.icon:SetTexture(ResolveShopItemIcon(item, item.icon))
    
    -- Name with rarity color
    local rarityColors = DC.RarityColors or {}
    local rarityData = rarityColors[item.rarity or 2] or { r = 1, g = 1, b = 1 }
    local r, g, b = rarityData.r or 1, rarityData.g or 1, rarityData.b or 1
    frame.name:SetText(item.name or "Unknown")
    frame.name:SetTextColor(r, g, b)
    
    -- Description
    frame.desc:SetText(item.description or "")
    
    -- Type badge
    local typeStr = self.ShopModule:GetItemTypeString(item)
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
        if frame.buyBtn.SetEnabled then
            frame.buyBtn:SetEnabled(canAfford)
        elseif canAfford then
            frame.buyBtn:Enable()
        else
            frame.buyBtn:Disable()
        end
        
        if canAfford then
            frame.costTokensText:SetTextColor(1, 1, 1)
            frame.costEmblemsText:SetTextColor(1, 1, 1)
        else
            frame.costTokensText:SetTextColor(1, 0.3, 0.3)
            frame.costEmblemsText:SetTextColor(1, 0.3, 0.3)
        end
    end

    if frame.previewBtn then
        local canPreview = self:CanPreviewShopItem(item)
        if canPreview then
            frame.previewBtn:Show()
            if frame.previewBtn.SetEnabled then
                frame.previewBtn:SetEnabled(true)
            else
                frame.previewBtn:Enable()
            end
        else
            frame.previewBtn:Hide()
        end
    end
end

-- ============================================================================
-- SHOP NAVIGATION
-- ============================================================================

function DC:SetShopView(view)
    if not self.ShopUI then return end

    local frame = self.ShopUI
    local normalized = (view == "history") and "history" or "shop"
    frame.activeView = normalized

    if normalized == "history" then
        frame.historyPage = frame.historyPage or 1

        local history = (self.ShopModule and self.ShopModule.GetPurchaseHistory and self.ShopModule:GetPurchaseHistory()) or {}
        if (#history == 0) and self.ShopModule and type(self.ShopModule.RefreshPurchaseHistory) == "function" then
            self.ShopModule:RefreshPurchaseHistory()
        elseif (#history == 0) and type(self.RequestShopHistory) == "function" then
            self:RequestShopHistory()
        end
    else
        frame.currentPage = frame.currentPage or 1
    end

    if frame:IsShown() then
        self:UpdateShopUI()
    else
        self:UpdateShopViewState()
    end
end

function DC:SetShopFilter(filter)
    if not self.ShopUI then return end

    self.ShopUI.activeView = "shop"
    self.ShopUI.currentFilter = filter
    self.ShopUI.currentPage = 1
    self:UpdateShopUI()
end

function DC:ShopNextPage()
    if not self.ShopUI then return end

    if self.ShopUI.activeView == "history" then
        self.ShopUI.historyPage = (self.ShopUI.historyPage or 1) + 1
        self:PopulateShopHistory()
    else
        self.ShopUI.currentPage = (self.ShopUI.currentPage or 1) + 1
        self:PopulateShopItems()
    end
end

function DC:ShopPrevPage()
    if not self.ShopUI then return end

    if self.ShopUI.activeView == "history" then
        self.ShopUI.historyPage = math.max(1, (self.ShopUI.historyPage or 1) - 1)
        self:PopulateShopHistory()
    else
        self.ShopUI.currentPage = math.max(1, (self.ShopUI.currentPage or 1) - 1)
        self:PopulateShopItems()
    end
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

    -- Ensure data is requested when arriving via the MainFrame tab switch.
    if self.ShopModule then
        local activeView = self.ShopUI and self.ShopUI.activeView or "shop"

        if activeView == "history" then
            local history = self.ShopModule:GetPurchaseHistory()
            if (not history) or (#history == 0) then
                if type(self.ShopModule.RefreshPurchaseHistory) == "function" then
                    self.ShopModule:RefreshPurchaseHistory()
                elseif type(self.RequestShopHistory) == "function" then
                    self:RequestShopHistory()
                end
            end
        end

        -- Shop items
        if (not self.shopItems) or (#self.shopItems == 0) then
            if type(self.ShopModule.RefreshShopItems) == "function" then
                self.ShopModule:RefreshShopItems()
            elseif type(self.RequestShopItems) == "function" then
                self:RequestShopItems()
            end
        end

        -- Currency
        local tokens, essence = (type(self.GetCurrencyBalances) == "function") and self:GetCurrencyBalances() or nil
        tokens = tonumber(tokens) or (self.currency and self.currency.tokens) or 0
        essence = tonumber(essence) or (self.currency and self.currency.emblems) or 0
        if tokens == 0 and essence == 0 then
            if type(self.ShopModule.RefreshCurrency) == "function" then
                self.ShopModule:RefreshCurrency()
            elseif type(self.RequestCurrency) == "function" then
                self:RequestCurrency()
            end
        end
    end

    self:UpdateShopUI()
end
