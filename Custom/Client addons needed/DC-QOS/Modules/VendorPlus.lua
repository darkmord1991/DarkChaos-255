-- ============================================================
-- DC-QoS: VendorPlus Module
-- ============================================================
-- Enhanced vendor/merchant interactions
-- Inspired by Leatrix Plus and Auctionator
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local VendorPlus = {
    displayName = "Vendor Plus",
    settingKey = "vendorPlus",
    icon = "Interface\\Icons\\INV_Misc_Coin_01",
    defaults = {
        vendorPlus = {
            enabled = true,
            showSellPrice = true,
            showRepairCost = true,
            autoBuyReagents = false,
            reagentStackSize = 20,
            junkList = {},
            neverSellList = {},
            confirmJunkSale = false,
            showTotalJunkValue = true,
        },
    },
}

-- Merge defaults
for k, v in pairs(VendorPlus.defaults) do
    addon.defaults[k] = v
end

-- ============================================================
-- Junk Management
-- ============================================================
local customJunkItems = {}  -- Items marked as junk by player
local neverSellItems = {}   -- Items to never auto-sell

-- Load custom lists from settings
local function LoadCustomLists()
    local settings = addon.settings.vendorPlus
    if settings.junkList then
        for itemId, _ in pairs(settings.junkList) do
            customJunkItems[itemId] = true
        end
    end
    if settings.neverSellList then
        for itemId, _ in pairs(settings.neverSellList) do
            neverSellItems[itemId] = true
        end
    end
end

local function MarkAsJunk(itemId)
    if not itemId then return end
    customJunkItems[itemId] = true
    neverSellItems[itemId] = nil
    
    local settings = addon.settings.vendorPlus
    if not settings.junkList then settings.junkList = {} end
    settings.junkList[itemId] = true
    settings.neverSellList[itemId] = nil
    addon:SaveSettings()
    
    local itemName = GetItemInfo(itemId)
    addon:Print("Marked " .. (itemName or itemId) .. " as junk.", true)
end

local function MarkAsValuable(itemId)
    if not itemId then return end
    neverSellItems[itemId] = true
    customJunkItems[itemId] = nil
    
    local settings = addon.settings.vendorPlus
    if not settings.neverSellList then settings.neverSellList = {} end
    settings.neverSellList[itemId] = true
    settings.junkList[itemId] = nil
    addon:SaveSettings()
    
    local itemName = GetItemInfo(itemId)
    addon:Print("Marked " .. (itemName or itemId) .. " as valuable (never sell).", true)
end

local function IsCustomJunk(itemId)
    return customJunkItems[itemId] == true
end

local function IsNeverSell(itemId)
    return neverSellItems[itemId] == true
end

-- ============================================================
-- Sell Price in Tooltips
-- ============================================================
local function NormalizeLabel(text)
    if not text then return nil end
    text = tostring(text)
    text = string.gsub(text, "[%s\t\r\n]+", " ")
    text = string.gsub(text, "[:：]", "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return string.lower(text)
end

local function IsTooltipMoneyFrameSellPrice(tooltipName, index)
    if not tooltipName or not index then return false end
    local prefixText = _G[tooltipName .. "MoneyFrame" .. index .. "PrefixText"]
    if not prefixText or not prefixText.GetText then
        return false
    end

    local text = prefixText:GetText()
    if not text or text == "" then
        return false
    end

    local normalized = NormalizeLabel(text)
    local sellPriceLabel = NormalizeLabel(SELL_PRICE) or "sell price"

    return normalized == sellPriceLabel
        or string.find(normalized, sellPriceLabel, 1, true) ~= nil
        or string.find(normalized, "sell price", 1, true) ~= nil
end

local function HideTooltipSellPriceMoneyFrame(tooltip)
    local tooltipName = tooltip and tooltip.GetName and tooltip:GetName()
    if not tooltipName then
        return
    end

    -- The item reference tooltip is the "inside item window" tooltip.
    -- Only hide the external money frame for normal hover tooltips.
    if tooltipName == "ItemRefTooltip" then
        return
    end

    for i = 1, 3 do
        if IsTooltipMoneyFrameSellPrice(tooltipName, i) then
            local moneyFrame = _G[tooltipName .. "MoneyFrame" .. i]
            if moneyFrame and moneyFrame.Hide then
                moneyFrame:Hide()
            end
            local prefixText = _G[tooltipName .. "MoneyFrame" .. i .. "PrefixText"]
            if prefixText and prefixText.SetText then
                prefixText:SetText("")
            end
            return
        end
    end
end

local function AddSellPriceToTooltip(tooltip, itemLink)
    local settings = addon.settings.vendorPlus
    if not settings.enabled or not settings.showSellPrice then return end
    if not itemLink then return end
    
    -- Prevent duplicate lines
    if tooltip._dcVendorPriceShown then return end
    
    local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemLink)
    if sellPrice and sellPrice > 0 then
        -- Prevent duplicate: the default UI renders SELL_PRICE as a money frame
        -- that appears below/outside the tooltip.
        -- Hide that external money frame first, then add the in-tooltip line.
        HideTooltipSellPriceMoneyFrame(tooltip)

        tooltip:AddLine(" ")
        tooltip:AddDoubleLine(SELL_PRICE or "Sell Price:", GetCoinTextureString(sellPrice), 0.8, 0.8, 0.8, 1, 1, 1)
        tooltip._dcVendorPriceShown = true
    end
end

local function SetupTooltipHooks()
    local function OnTooltipSetItem(tooltip)
        local _, itemLink = tooltip:GetItem()
        if itemLink then
            AddSellPriceToTooltip(tooltip, itemLink)
        end
    end
    
    -- Clear flag when tooltip is cleared
    GameTooltip:HookScript("OnTooltipCleared", function(self)
        self._dcVendorPriceShown = nil
    end)

    -- Catch generic item tooltips (not just bag/inventory hooks)
    GameTooltip:HookScript("OnTooltipSetItem", function(self)
        OnTooltipSetItem(self)
    end)

    -- Comparison tooltips (ShoppingTooltip1/2) can also show the external money frame
    if ShoppingTooltip1 and ShoppingTooltip1.HookScript then
        ShoppingTooltip1:HookScript("OnTooltipCleared", function(self)
            self._dcVendorPriceShown = nil
        end)
        ShoppingTooltip1:HookScript("OnTooltipSetItem", function(self)
            OnTooltipSetItem(self)
        end)
    end
    if ShoppingTooltip2 and ShoppingTooltip2.HookScript then
        ShoppingTooltip2:HookScript("OnTooltipCleared", function(self)
            self._dcVendorPriceShown = nil
        end)
        ShoppingTooltip2:HookScript("OnTooltipSetItem", function(self)
            OnTooltipSetItem(self)
        end)
    end
    
    -- Hook the set functions
    hooksecurefunc(GameTooltip, "SetBagItem", function(self, bag, slot)
        local itemLink = GetContainerItemLink(bag, slot)
        if itemLink then
            AddSellPriceToTooltip(self, itemLink)
        end
    end)
    
    hooksecurefunc(GameTooltip, "SetInventoryItem", function(self, unit, slot)
        local itemLink = GetInventoryItemLink(unit, slot)
        if itemLink then
            AddSellPriceToTooltip(self, itemLink)
        end
    end)
    
    hooksecurefunc(GameTooltip, "SetMerchantItem", function(self, slot)
        local itemLink = GetMerchantItemLink(slot)
        if itemLink then
            AddSellPriceToTooltip(self, itemLink)
        end
    end)
end

-- ============================================================
-- Enhanced Junk Selling
-- ============================================================
local function CalculateJunkValue()
    local totalValue = 0
    local itemCount = 0
    
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local _, _, quality = GetItemInfo(itemLink)
                local itemId = tonumber(itemLink:match("item:(%d+)"))
                
                -- Check if it's junk (grey quality or custom marked)
                local isJunk = (quality == 0) or IsCustomJunk(itemId)
                local isProtected = IsNeverSell(itemId)
                
                if isJunk and not isProtected then
                    local _, count = GetContainerItemInfo(bag, slot)
                    local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemLink)
                    if sellPrice and sellPrice > 0 then
                        totalValue = totalValue + (sellPrice * (count or 1))
                        itemCount = itemCount + 1
                    end
                end
            end
        end
    end
    
    return totalValue, itemCount
end

local function SellAllJunk()
    local settings = addon.settings.vendorPlus
    if not settings.enabled then return end
    
    local totalValue = 0
    local itemCount = 0
    
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local _, _, quality = GetItemInfo(itemLink)
                local itemId = tonumber(itemLink:match("item:(%d+)"))
                
                local isJunk = (quality == 0) or IsCustomJunk(itemId)
                local isProtected = IsNeverSell(itemId)
                
                if isJunk and not isProtected then
                    local _, count = GetContainerItemInfo(bag, slot)
                    local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemLink)
                    
                    if sellPrice and sellPrice > 0 then
                        totalValue = totalValue + (sellPrice * (count or 1))
                        itemCount = itemCount + 1
                        UseContainerItem(bag, slot)
                    end
                end
            end
        end
    end
    
    if itemCount > 0 then
        addon:Print("Sold " .. itemCount .. " junk items for " .. GetCoinTextureString(totalValue), true)
    end
end

-- ============================================================
-- Repair Cost Preview
-- ============================================================
local repairCostFrame = nil

local function CreateRepairCostFrame()
    if repairCostFrame then return end
    
    repairCostFrame = CreateFrame("Frame", "DCQoS_RepairCostFrame", MerchantFrame)
    repairCostFrame:SetSize(200, 50)
    repairCostFrame:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 5, -30)
    
    repairCostFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    repairCostFrame:SetBackdropColor(0, 0, 0, 0.8)
    repairCostFrame:SetBackdropBorderColor(0.5, 0.5, 0.5)
    
    local title = repairCostFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -8)
    title:SetText("Repair Cost")
    repairCostFrame.title = title
    
    local costText = repairCostFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    costText:SetPoint("TOP", title, "BOTTOM", 0, -5)
    repairCostFrame.costText = costText
    
    local junkText = repairCostFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    junkText:SetPoint("TOP", costText, "BOTTOM", 0, -5)
    repairCostFrame.junkText = junkText
    
    repairCostFrame:Hide()
end

local function UpdateRepairCostFrame()
    local settings = addon.settings.vendorPlus
    if not settings.enabled or not settings.showRepairCost then
        if repairCostFrame then repairCostFrame:Hide() end
        return
    end
    
    if not repairCostFrame then CreateRepairCostFrame() end
    
    local repairCost, canRepair = GetRepairAllCost()
    local junkValue, junkCount = CalculateJunkValue()
    
    if (repairCost and repairCost > 0) or (junkValue and junkValue > 0) then
        if repairCost and repairCost > 0 then
            repairCostFrame.costText:SetText(GetCoinTextureString(repairCost))
        else
            repairCostFrame.costText:SetText("|cff00ff00Fully Repaired|r")
        end
        
        if settings.showTotalJunkValue and junkValue > 0 then
            repairCostFrame.junkText:SetText("|cff888888Junk: " .. GetCoinTextureString(junkValue) .. " (" .. junkCount .. " items)|r")
            repairCostFrame:SetHeight(65)
        else
            repairCostFrame.junkText:SetText("")
            repairCostFrame:SetHeight(50)
        end
        
        repairCostFrame:Show()
    else
        repairCostFrame:Hide()
    end
end

-- ============================================================
-- Auto-Buy Reagents
-- ============================================================
local COMMON_REAGENTS = {
    -- Mage
    [17020] = true,  -- Arcane Powder
    [17031] = true,  -- Rune of Teleportation
    [17032] = true,  -- Rune of Portals
    
    -- Warlock
    [6265] = true,   -- Soul Shard (can't buy, but for reference)
    
    -- Paladin
    [21177] = true,  -- Symbol of Kings
    [17033] = true,  -- Symbol of Divinity
    
    -- Priest
    [17028] = true,  -- Holy Candle
    [17029] = true,  -- Sacred Candle
    
    -- Shaman
    [17030] = true,  -- Ankh
    
    -- Druid
    [17034] = true,  -- Maple Seed
    [17035] = true,  -- Stranglethorn Seed
    [17036] = true,  -- Ashwood Seed
    [17037] = true,  -- Hornbeam Seed
    [17038] = true,  -- Ironwood Seed
    [22147] = true,  -- Flintweed Seed
    [22148] = true,  -- Wild Quillvine
    [44605] = true,  -- Wild Spineleaf
    [44614] = true,  -- Starleaf Seed
    
    -- Rogue
    [5140] = true,   -- Flash Powder
    [5530] = true,   -- Blinding Powder (deprecated)
    
    -- Death Knight
    [37201] = true,  -- Corpse Dust
}

local function AutoBuyReagents()
    local settings = addon.settings.vendorPlus
    if not settings.enabled or not settings.autoBuyReagents then return end
    
    local numItems = GetMerchantNumItems()
    local stackSize = settings.reagentStackSize or 20
    
    for i = 1, numItems do
        local itemLink = GetMerchantItemLink(i)
        if itemLink then
            local itemId = tonumber(itemLink:match("item:(%d+)"))
            
            if COMMON_REAGENTS[itemId] then
                -- Check current stack in bags
                local currentCount = GetItemCount(itemId)
                
                if currentCount < stackSize then
                    local toBuy = stackSize - currentCount
                    
                    -- Get item info
                    local _, _, price, quantity = GetMerchantItemInfo(i)
                    if quantity and quantity > 0 then
                        local stacks = math.ceil(toBuy / quantity)
                        for _ = 1, stacks do
                            BuyMerchantItem(i, quantity)
                        end
                        
                        local itemName = GetItemInfo(itemId)
                        addon:Debug("Auto-bought " .. toBuy .. "x " .. (itemName or itemId))
                    end
                end
            end
        end
    end
end

-- ============================================================
-- Merchant Event Handler
-- ============================================================
local function OnMerchantShow()
    local settings = addon.settings.vendorPlus
    if not settings.enabled then return end
    
    -- Update repair cost display
    UpdateRepairCostFrame()
    
    -- Auto-buy reagents
    if settings.autoBuyReagents then
        addon:DelayedCall(0.5, AutoBuyReagents)
    end
end

local function OnMerchantClose()
    if repairCostFrame then
        repairCostFrame:Hide()
    end
end

-- ============================================================
-- Item Context Menu Integration
-- ============================================================
local function AddContextMenuOptions()
    -- Hook the item menu to add "Mark as Junk" / "Mark as Valuable" options
    hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self, button)
        if button == "RightButton" and IsControlKeyDown() then
            local bag = self:GetParent():GetID()
            local slot = self:GetID()
            local itemLink = GetContainerItemLink(bag, slot)
            
            if itemLink then
                local itemId = tonumber(itemLink:match("item:(%d+)"))
                if itemId then
                    if IsNeverSell(itemId) then
                        -- Remove from never-sell
                        neverSellItems[itemId] = nil
                        addon.settings.vendorPlus.neverSellList[itemId] = nil
                        addon:SaveSettings()
                        addon:Print("Removed " .. itemLink .. " from protected list.", true)
                    elseif IsCustomJunk(itemId) then
                        MarkAsValuable(itemId)
                    else
                        MarkAsJunk(itemId)
                    end
                end
            end
        end
    end)
end

-- ============================================================
-- Sell Junk Button
-- ============================================================
local sellJunkButton = nil

local function CreateSellJunkButton()
    if sellJunkButton then return end
    
    sellJunkButton = CreateFrame("Button", "DCQoS_SellJunkButton", MerchantFrame, "UIPanelButtonTemplate")
    sellJunkButton:SetSize(80, 22)
    sellJunkButton:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMLEFT", 85, 4)
    sellJunkButton:SetText("Sell Junk")
    
    sellJunkButton:SetScript("OnClick", function()
        SellAllJunk()
    end)
    
    sellJunkButton:SetScript("OnEnter", function(self)
        local junkValue, junkCount = CalculateJunkValue()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Sell All Junk Items")
        if junkCount > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Items:", junkCount, 1, 1, 1, 1, 1, 1)
            GameTooltip:AddDoubleLine("Value:", GetCoinTextureString(junkValue), 1, 1, 1, 1, 1, 1)
        else
            GameTooltip:AddLine("No junk items to sell", 0.5, 0.5, 0.5)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff888888Ctrl+Right-click items to mark as junk|r", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    
    sellJunkButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function VendorPlus.OnInitialize()
    addon:Debug("VendorPlus module initializing")
    LoadCustomLists()
end

function VendorPlus.OnEnable()
    addon:Debug("VendorPlus module enabling")
    
    -- Setup tooltip hooks
    SetupTooltipHooks()
    
    -- Setup merchant hooks
    local merchantFrame = CreateFrame("Frame")
    merchantFrame:RegisterEvent("MERCHANT_SHOW")
    merchantFrame:RegisterEvent("MERCHANT_CLOSED")
    merchantFrame:SetScript("OnEvent", function(self, event)
        if event == "MERCHANT_SHOW" then
            OnMerchantShow()
            CreateSellJunkButton()
        elseif event == "MERCHANT_CLOSED" then
            OnMerchantClose()
        end
    end)
    
    -- Setup context menu
    AddContextMenuOptions()
end

function VendorPlus.OnDisable()
    addon:Debug("VendorPlus module disabling")
    if repairCostFrame then repairCostFrame:Hide() end
    if sellJunkButton then sellJunkButton:Hide() end
end

-- ============================================================
-- Settings Panel Creation
-- ============================================================
function VendorPlus.CreateSettings(parent)
    local settings = addon.settings.vendorPlus
    
    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Vendor Plus Settings")
    
    -- Description
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(450)
    desc:SetJustifyH("LEFT")
    desc:SetText("Enhanced vendor interactions with sell price display, junk management, and auto-buy features.")
    
    local yOffset = -70
    
    -- Show Sell Price
    local sellPriceCb = addon:CreateCheckbox(parent)
    sellPriceCb:SetPoint("TOPLEFT", 16, yOffset)
    sellPriceCb.Text:SetText("Show vendor sell price in tooltips")
    sellPriceCb:SetChecked(settings.showSellPrice)
    sellPriceCb:SetScript("OnClick", function(self)
        addon:SetSetting("vendorPlus.showSellPrice", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Show Repair Cost
    local repairCostCb = addon:CreateCheckbox(parent)
    repairCostCb:SetPoint("TOPLEFT", 16, yOffset)
    repairCostCb.Text:SetText("Show repair cost preview at merchants")
    repairCostCb:SetChecked(settings.showRepairCost)
    repairCostCb:SetScript("OnClick", function(self)
        addon:SetSetting("vendorPlus.showRepairCost", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Show Total Junk Value
    local junkValueCb = addon:CreateCheckbox(parent)
    junkValueCb:SetPoint("TOPLEFT", 16, yOffset)
    junkValueCb.Text:SetText("Show total junk item value")
    junkValueCb:SetChecked(settings.showTotalJunkValue)
    junkValueCb:SetScript("OnClick", function(self)
        addon:SetSetting("vendorPlus.showTotalJunkValue", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- Auto-Buy Section
    local autoBuyHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    autoBuyHeader:SetPoint("TOPLEFT", 16, yOffset)
    autoBuyHeader:SetText("Auto-Buy Reagents")
    yOffset = yOffset - 25
    
    -- Auto-Buy Reagents
    local autoBuyCb = addon:CreateCheckbox(parent)
    autoBuyCb:SetPoint("TOPLEFT", 16, yOffset)
    autoBuyCb.Text:SetText("Automatically buy class reagents")
    autoBuyCb:SetChecked(settings.autoBuyReagents)
    autoBuyCb:SetScript("OnClick", function(self)
        addon:SetSetting("vendorPlus.autoBuyReagents", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Stack Size Slider
    local stackSlider = addon:CreateSlider(parent)
    stackSlider:SetPoint("TOPLEFT", 16, yOffset)
    stackSlider:SetMinMaxValues(5, 100)
    stackSlider:SetValueStep(5)
    stackSlider:SetValue(settings.reagentStackSize or 20)
    stackSlider.Text:SetText("Reagent stack size: " .. (settings.reagentStackSize or 20))
    stackSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 5) * 5
        self.Text:SetText("Reagent stack size: " .. value)
        addon:SetSetting("vendorPlus.reagentStackSize", value)
    end)
    yOffset = yOffset - 50
    
    -- Info text
    local infoText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", 16, yOffset)
    infoText:SetWidth(450)
    infoText:SetJustifyH("LEFT")
    infoText:SetTextColor(0.7, 0.7, 0.7)
    infoText:SetText("Tip: Ctrl+Right-click items in your bags to mark them as junk or valuable.")
    
    return yOffset - 40
end

-- ============================================================
-- Expose Functions
-- ============================================================
VendorPlus.SellAllJunk = SellAllJunk
VendorPlus.MarkAsJunk = MarkAsJunk
VendorPlus.MarkAsValuable = MarkAsValuable
VendorPlus.CalculateJunkValue = CalculateJunkValue

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("VendorPlus", VendorPlus)
