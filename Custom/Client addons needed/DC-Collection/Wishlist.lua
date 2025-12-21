--[[
    DC-Collection Wishlist.lua
    ===========================
    
    Wishlist functionality for tracking desired collectibles.
    
    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC.L

-- ============================================================================
-- WISHLIST UI
-- ============================================================================

function DC:CreateWishlistUI()
    if self.WishlistUI then
        return self.WishlistUI
    end
    
    local frame = CreateFrame("Frame", "DCCollectionWishlistFrame", UIParent, "UIPanelDialogTemplate")
    frame:SetSize(400, 350)
    frame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
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
    frame.title:SetText(L["WISHLIST"] or "Wishlist")
    
    -- Close button
    local closeBtn = _G[frame:GetName() .. "Close"]
    if closeBtn then
        closeBtn:SetScript("OnClick", function()
            frame:Hide()
        end)
    end
    
    -- Content area
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -40)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 40)
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "DCWishlistScrollFrame", content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -25, 5)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    frame.scrollFrame = scrollFrame
    frame.scrollChild = scrollChild
    
    -- Empty state text
    frame.emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.emptyText:SetPoint("CENTER", content, "CENTER", 0, 0)
    frame.emptyText:SetText(L["WISHLIST_EMPTY"] or "Your wishlist is empty.\nRight-click items to add them!")
    frame.emptyText:SetTextColor(0.5, 0.5, 0.5)
    
    -- Footer
    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
    footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    footer:SetHeight(25)
    
    local clearBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 22)
    clearBtn:SetPoint("LEFT", footer, "LEFT", 5, 0)
    clearBtn:SetText(L["CLEAR_ALL"] or "Clear All")
    clearBtn:SetScript("OnClick", function()
        DC:ClearWishlist()
    end)
    
    local refreshBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    refreshBtn:SetSize(80, 22)
    refreshBtn:SetPoint("RIGHT", footer, "RIGHT", -5, 0)
    refreshBtn:SetText(L["REFRESH"] or "Refresh")
    refreshBtn:SetScript("OnClick", function()
        DC:RequestWishlist()
    end)
    
    -- ESC to close
    tinsert(UISpecialFrames, frame:GetName())
    
    self.WishlistUI = frame
    return frame
end

-- ============================================================================
-- WISHLIST DISPLAY
-- ============================================================================

function DC:ShowWishlist()
    if not self.WishlistUI then
        self:CreateWishlistUI()
    end
    
    self.WishlistUI:Show()
    self:RefreshWishlistUI()
end

function DC:RefreshWishlistUI()
    if not self.WishlistUI or not self.WishlistUI:IsShown() then
        return
    end
    
    local scrollChild = self.WishlistUI.scrollChild
    
    -- Clear existing items
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    local wishlist = self.wishlist or {}
    
    if #wishlist == 0 then
        self.WishlistUI.emptyText:Show()
        self.WishlistUI.scrollFrame:Hide()
        return
    end
    
    self.WishlistUI.emptyText:Hide()
    self.WishlistUI.scrollFrame:Show()
    
    -- Create wishlist items
    local yOffset = 0
    local itemHeight = 50
    
    for i, wish in ipairs(wishlist) do
        local itemFrame = self:CreateWishlistItemFrame(scrollChild, wish, yOffset)
        yOffset = yOffset + itemHeight + 5
    end
    
    scrollChild:SetHeight(yOffset)
end

function DC:CreateWishlistItemFrame(parent, wish, yOffset)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(parent:GetWidth() - 10, 50)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -yOffset)
    
    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    
    -- Get definition
    local def = self:GetDefinition(wish.type, wish.itemId)
    
    -- Icon
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(40, 40)
    frame.icon:SetPoint("LEFT", frame, "LEFT", 5, 0)
    frame.icon:SetTexture(def and def.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    
    -- Name
    local rarity = def and def.rarity or 1
    local r, g, b = unpack(self.RARITY_COLORS[rarity] or {1, 1, 1})
    
    frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.name:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, -5)
    frame.name:SetText(def and def.name or "Unknown")
    frame.name:SetTextColor(r, g, b)
    
    -- Type and source
    frame.info = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.info:SetPoint("TOPLEFT", frame.name, "BOTTOMLEFT", 0, -3)
    
    local typeStr = L["TAB_" .. string.upper(wish.type)] or wish.type
    local sourceStr = def and def.source or "Unknown"
    frame.info:SetText(typeStr .. " - " .. sourceStr)
    frame.info:SetTextColor(0.5, 0.5, 0.5)
    
    -- Remove button
    local removeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    removeBtn:SetSize(24, 24)
    removeBtn:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
    removeBtn:SetScript("OnClick", function()
        DC:RequestRemoveWishlist(wish.type, wish.itemId)
    end)
    
    return frame
end

-- ============================================================================
-- WISHLIST MANAGEMENT
-- ============================================================================

function DC:AddToWishlist(collectionType, itemId)
    -- Check if already in wishlist
    for _, wish in ipairs(self.wishlist) do
        if wish.type == collectionType and wish.itemId == itemId then
            self:Print(L["ALREADY_IN_WISHLIST"] or "Item is already in wishlist")
            return
        end
    end
    
    self:RequestAddWishlist(collectionType, itemId)
end

function DC:RemoveFromWishlist(collectionType, itemId)
    self:RequestRemoveWishlist(collectionType, itemId)
end

function DC:ClearWishlist()
    -- Confirm with user
    StaticPopupDialogs["DC_CLEAR_WISHLIST"] = {
        text = L["CONFIRM_CLEAR_WISHLIST"] or "Are you sure you want to clear your entire wishlist?",
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            -- Remove all items
            for _, wish in ipairs(DC.wishlist) do
                DC:RequestRemoveWishlist(wish.type, wish.itemId)
            end
            DC.wishlist = {}
            DC:RefreshWishlistUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("DC_CLEAR_WISHLIST")
end

function DC:IsInWishlist(collectionType, itemId)
    for _, wish in ipairs(self.wishlist) do
        if wish.type == collectionType and wish.itemId == itemId then
            return true
        end
    end
    return false
end
