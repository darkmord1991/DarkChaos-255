-- ============================================================
-- DC-QoS: VendorPlus Module
-- ============================================================
-- Enhanced vendor/merchant interactions
-- Inspired by Leatrix Plus and Auctionator
-- ============================================================

local addon = DCQOS

local function NotifyVendor(message, level, opts)
    if addon.Notify then
        addon:Notify(message, level or "info", opts or { title = "Vendor" })
    else
        addon:Print(message, true)
    end
end

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

local tooltipHooksInstalled = false
local contextMenuHookInstalled = false
local merchantEventFrame = nil

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
    NotifyVendor("Marked " .. (itemName or itemId) .. " as junk.", "info", { title = "Vendor" })
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
    NotifyVendor("Marked " .. (itemName or itemId) .. " as valuable.", "success", { title = "Vendor" })
end

local function IsCustomJunk(itemId)
    if not itemId then return false end
    return customJunkItems[itemId] == true or customJunkItems[tostring(itemId)] == true
end

local function IsNeverSell(itemId)
    if not itemId then return false end
    return neverSellItems[itemId] == true or neverSellItems[tostring(itemId)] == true
end

local function GetItemIdFromLink(itemLink)
    if not itemLink then return nil end
    return tonumber(itemLink:match("item:(%d+)"))
end

local function GetBagSlotJunkInfo(bag, slot, itemLink)
    if not itemLink then
        return nil
    end

    local _, count, _, quality = GetContainerItemInfo(bag, slot)
    local itemId = tonumber(itemLink:match("item:(%d+)"))

    -- Some clients/slots can return nil quality from GetContainerItemInfo.
    -- Fall back to GetItemInfo rarity to avoid false "No junk items" states.
    if quality == nil then
        local _, _, rarity = GetItemInfo(itemLink)
        quality = rarity
    end

    local isJunk = (quality == 0) or IsCustomJunk(itemId)
    local isProtected = IsNeverSell(itemId)

    return {
        count = count or 1,
        itemId = itemId,
        quality = quality,
        isJunk = isJunk,
        isProtected = isProtected,
    }
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

local function GetTooltipItemQuality(itemLink, bag, slot)
    local quality

    if bag ~= nil and slot ~= nil then
        local _, _, _, bagQuality = GetContainerItemInfo(bag, slot)
        quality = bagQuality
    end

    if quality == nil and itemLink then
        local _, _, rarity = GetItemInfo(itemLink)
        quality = rarity
    end

    return quality
end

local function AddJunkStatusToTooltip(tooltip, itemLink, bag, slot)
    local settings = addon.settings.vendorPlus
    if not settings or settings.enabled == false then return end
    if not itemLink then return end
    if tooltip._dcVendorJunkShown then return end

    local itemId = GetItemIdFromLink(itemLink)
    if not itemId then return end

    local quality = GetTooltipItemQuality(itemLink, bag, slot)
    local isPoorQuality = (quality == 0)
    local isCustomJunk = IsCustomJunk(itemId)
    local isProtected = IsNeverSell(itemId)
    local isJunk = (isPoorQuality or isCustomJunk) and not isProtected

    if isProtected then
        tooltip:AddLine("|cff66ccffProtected: Marked as valuable|r")
        tooltip._dcVendorJunkShown = true
        return
    end

    if isJunk then
        if isCustomJunk then
            tooltip:AddLine("|cffff6666Junk: Marked for auto-sell|r")
        else
            tooltip:AddLine("|cff9d9d9dJunk: Poor quality auto-sell|r")
        end
        tooltip._dcVendorJunkShown = true
    end
end

local function SetupTooltipHooks()
    if tooltipHooksInstalled then return end
    tooltipHooksInstalled = true

    local function OnTooltipSetItem(tooltip)
        local _, itemLink = tooltip:GetItem()
        if itemLink then
            AddSellPriceToTooltip(tooltip, itemLink)
            AddJunkStatusToTooltip(tooltip, itemLink)
        end
    end
    
    -- Clear flag when tooltip is cleared
    GameTooltip:HookScript("OnTooltipCleared", function(self)
        self._dcVendorPriceShown = nil
        self._dcVendorJunkShown = nil
    end)

    -- Catch generic item tooltips (not just bag/inventory hooks)
    GameTooltip:HookScript("OnTooltipSetItem", function(self)
        OnTooltipSetItem(self)
    end)

    -- Comparison tooltips (ShoppingTooltip1/2) can also show the external money frame
    if ShoppingTooltip1 and ShoppingTooltip1.HookScript then
        ShoppingTooltip1:HookScript("OnTooltipCleared", function(self)
            self._dcVendorPriceShown = nil
            self._dcVendorJunkShown = nil
        end)
        ShoppingTooltip1:HookScript("OnTooltipSetItem", function(self)
            OnTooltipSetItem(self)
        end)
    end
    if ShoppingTooltip2 and ShoppingTooltip2.HookScript then
        ShoppingTooltip2:HookScript("OnTooltipCleared", function(self)
            self._dcVendorPriceShown = nil
            self._dcVendorJunkShown = nil
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
            AddJunkStatusToTooltip(self, itemLink, bag, slot)
        end
    end)
    
    hooksecurefunc(GameTooltip, "SetInventoryItem", function(self, unit, slot)
        local itemLink = GetInventoryItemLink(unit, slot)
        if itemLink then
            AddSellPriceToTooltip(self, itemLink)
            AddJunkStatusToTooltip(self, itemLink)
        end
    end)
    
    hooksecurefunc(GameTooltip, "SetMerchantItem", function(self, slot)
        local itemLink = GetMerchantItemLink(slot)
        if itemLink then
            AddSellPriceToTooltip(self, itemLink)
            AddJunkStatusToTooltip(self, itemLink)
        end
    end)
end

-- ============================================================
-- Enhanced Junk Selling
-- ============================================================
local function CalculateJunkValue()
    local settings = addon.settings.vendorPlus
    if not settings or settings.enabled == false then
        return 0, 0
    end

    local totalValue = 0
    local itemCount = 0
    
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local slotInfo = GetBagSlotJunkInfo(bag, slot, itemLink)

                if slotInfo and slotInfo.isJunk and not slotInfo.isProtected then
                    itemCount = itemCount + slotInfo.count
                    local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemLink)
                    if sellPrice and sellPrice > 0 then
                        totalValue = totalValue + (sellPrice * slotInfo.count)
                    end
                end
            end
        end
    end
    
    return totalValue, itemCount
end

local function SellAllJunk()
    local settings = addon.settings.vendorPlus
    if not settings or settings.enabled == false then return end
    
    local totalValue = 0
    local itemCount = 0
    
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local slotInfo = GetBagSlotJunkInfo(bag, slot, itemLink)

                if slotInfo and slotInfo.isJunk and not slotInfo.isProtected then
                    local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemLink)
                    if sellPrice and sellPrice > 0 then
                        totalValue = totalValue + (sellPrice * slotInfo.count)
                    end

                    itemCount = itemCount + slotInfo.count
                    UseContainerItem(bag, slot)
                end
            end
        end
    end
    
    if itemCount > 0 then
        NotifyVendor(
            "Sold " .. itemCount .. " junk items for " .. GetCoinTextureString(totalValue),
            "success",
            { title = "Vendor", chatFallback = false, forceChat = true }
        )
    else
        NotifyVendor(
            "No junk found. Ctrl+Right-click an item to mark it as junk.",
            "info",
            { title = "Vendor", chatFallback = false, forceChat = true }
        )
    end
end

-- ============================================================
-- Repair Cost Preview
-- ============================================================
-- One or two text lines in the stone band under the merchant title bar: x 76..338 and
-- 35..71 px below MerchantFrame's TOPLEFT, between the portrait ring and the right border.
-- Stock 3.3.5 anchors nothing there (the item grid starts 80 px down), so the preview stays
-- inside the vendor window on both tabs. It used to hang off the frame's right edge.
local REPAIR_BAND_LEFT = 76
local REPAIR_BAND_TOP = -35
local REPAIR_BAND_WIDTH = 262
local REPAIR_BAND_HEIGHT = 36
local LABEL_COLOR = "|cffffd100"

local repairCostFrame = nil

local function CreateRepairCostFrame()
    if repairCostFrame then return end

    repairCostFrame = CreateFrame("Frame", "DCQoS_RepairCostFrame", MerchantFrame)
    repairCostFrame:SetWidth(REPAIR_BAND_WIDTH)
    repairCostFrame:SetHeight(REPAIR_BAND_HEIGHT)
    repairCostFrame:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", REPAIR_BAND_LEFT, REPAIR_BAND_TOP)

    -- A fixed width makes a long line truncate instead of running past the border.
    local costText = repairCostFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    costText:SetWidth(REPAIR_BAND_WIDTH)
    costText:SetJustifyH("LEFT")
    repairCostFrame.costText = costText

    local junkText = repairCostFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    junkText:SetWidth(REPAIR_BAND_WIDTH)
    junkText:SetJustifyH("LEFT")
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

    local repairCost = GetRepairAllCost() or 0
    local junkValue, junkCount = CalculateJunkValue()
    local showJunk = settings.showTotalJunkValue and junkValue > 0

    if repairCost <= 0 and not showJunk then
        repairCostFrame:Hide()
        return
    end

    local costText, junkText = repairCostFrame.costText, repairCostFrame.junkText
    if repairCost > 0 then
        local coins = GetCoinTextureString(repairCost)
        if GetMoney() < repairCost then
            coins = "|cffff2020" .. coins .. "|r"
        end
        costText:SetText(LABEL_COLOR .. "Repair cost:|r " .. coins)
    else
        costText:SetText(LABEL_COLOR .. "Repair cost:|r |cff00ff00Fully repaired|r")
    end

    costText:ClearAllPoints()
    junkText:ClearAllPoints()
    if showJunk then
        junkText:SetText(LABEL_COLOR .. "Junk:|r " .. GetCoinTextureString(junkValue)
            .. " |cff9d9d9d(" .. junkCount .. " items)|r")
        costText:SetPoint("LEFT", repairCostFrame, "TOPLEFT", 0, -11)
        junkText:SetPoint("LEFT", repairCostFrame, "TOPLEFT", 0, -25)
        junkText:Show()
    else
        junkText:SetText("")
        junkText:Hide()
        costText:SetPoint("LEFT", repairCostFrame, "LEFT", 0, 0)
    end

    repairCostFrame:Show()
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
    if contextMenuHookInstalled then return end
    contextMenuHookInstalled = true

    -- Hook the item menu to add "Mark as Junk" / "Mark as Valuable" options
    hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self, button)
        local settings = addon.settings and addon.settings.vendorPlus
        if not settings or settings.enabled == false then
            return
        end

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
                        NotifyVendor("Removed " .. itemLink .. " from the protected list.", "info", { title = "Vendor" })
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
-- Placed the way retail places MerchantSellAllJunkButton: an icon button in the repair
-- box at the bottom of the merchant page, right of the repair buttons, or on its own
-- when the vendor cannot repair. It is hidden on the Buyback tab.
--
-- The 3.3.5 repair box is x 20..174, y 86..134 from MerchantFrame's BOTTOMLEFT (the
-- buyback box starts right of the divider at x 175). That is too narrow for the stock
-- 36 px repair row plus one more button, so while the junk button shows, the row uses
-- the compact 32 px layout that stock 3.3.5 already uses for the guild bank repair
-- button, with the "Repair Items" label centred above it. Each row is centred in the box.
local SELL_JUNK_TEXTURE = "Interface\\AddOns\\DC-QOS\\Textures\\Merchant\\merchant"
-- "SpellIcon-256x256-SellJunk" in the retail Interface/MerchantFrame/Merchant atlas.
local SELL_JUNK_TEXCOORD = { 0.00195312, 0.142578, 0.25, 0.53125 }

local sellJunkButton = nil
local sellJunkLayoutActive = false
local merchantLayoutHooksInstalled = false

local function IsAutomationAutoSellActive()
    local automation = addon.settings and addon.settings.automation
    if not automation then
        return false
    end

    return automation.enabled ~= false and automation.autoSellJunk == true
end

local function LayoutMerchantBottomRow()
    if not sellJunkButton or not sellJunkLayoutActive then return end

    if MerchantFrame.selectedTab ~= 1 then
        sellJunkButton:Hide()
        return
    end

    sellJunkButton:ClearAllPoints()
    if CanMerchantRepair() then
        local guildRepair = CanGuildBankRepair()
        -- Same anchor points MerchantFrame_UpdateRepairButtons sets, so its next call
        -- replaces these offsets instead of stacking a second anchor on the buttons.
        MerchantRepairAllButton:SetWidth(32)
        MerchantRepairAllButton:SetHeight(32)
        MerchantRepairItemButton:SetWidth(32)
        MerchantRepairItemButton:SetHeight(32)
        MerchantRepairAllButton:SetPoint("BOTTOMRIGHT", MerchantFrame, "BOTTOMLEFT", guildRepair and 94 or 112, 89)
        MerchantRepairItemButton:SetPoint("RIGHT", MerchantRepairAllButton, "LEFT", -4, 0)
        MerchantRepairText:ClearAllPoints()
        MerchantRepairText:SetPoint("CENTER", MerchantFrame, "BOTTOMLEFT", 78, 129)

        -- The guild bank button keeps its stock anchor, 4 px right of Repair All.
        local lastRepairButton = guildRepair and MerchantGuildBankRepairButton or MerchantRepairAllButton
        sellJunkButton:SetWidth(32)
        sellJunkButton:SetHeight(32)
        sellJunkButton:SetPoint("LEFT", lastRepairButton, "RIGHT", 6, 0)
    else
        sellJunkButton:SetWidth(36)
        sellJunkButton:SetHeight(36)
        sellJunkButton:SetPoint("CENTER", MerchantFrame, "BOTTOMLEFT", 97, 110)
    end
    sellJunkButton:Show()
end

local function InstallMerchantLayoutHooks()
    if merchantLayoutHooksInstalled then return end
    merchantLayoutHooksInstalled = true

    -- Runs on every merchant page refresh and on the money/guild-bank events that
    -- re-anchor the stock repair buttons.
    hooksecurefunc("MerchantFrame_UpdateRepairButtons", LayoutMerchantBottomRow)
    hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function()
        if sellJunkButton then
            sellJunkButton:Hide()
        end
    end)
end

local function UpdateSellJunkPreview()
    if not sellJunkButton then return end

    local settings = addon.settings.vendorPlus
    if not settings or settings.enabled == false then
        sellJunkButton:Disable()
        SetDesaturation(sellJunkButton.icon, 1)
        return
    end

    local _, junkCount = CalculateJunkValue()
    -- Grey icon when there is nothing to sell, as on retail. The button stays clickable
    -- so a click without junk still explains how to mark items.
    sellJunkButton:Enable()
    SetDesaturation(sellJunkButton.icon, junkCount == 0 and 1 or nil)
end

local function CreateSellJunkButton()
    if sellJunkButton then
        LayoutMerchantBottomRow()
        UpdateSellJunkPreview()
        return
    end

    sellJunkButton = CreateFrame("Button", "DCQoS_SellJunkButton", MerchantFrame)
    sellJunkButton:SetWidth(32)
    sellJunkButton:SetHeight(32)
    sellJunkButton:Hide()

    local icon = sellJunkButton:CreateTexture(nil, "BORDER")
    icon:SetAllPoints(sellJunkButton)
    icon:SetTexture(SELL_JUNK_TEXTURE)
    icon:SetTexCoord(unpack(SELL_JUNK_TEXCOORD))
    sellJunkButton.icon = icon

    -- Same press and hover art as the stock repair buttons next to it.
    sellJunkButton:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    sellJunkButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    sellJunkButton:SetScript("OnClick", function()
        GameTooltip:Hide()
        SellAllJunk()
        addon:DelayedCall(0.2, UpdateSellJunkPreview)
    end)

    sellJunkButton:SetScript("OnEnter", function(self)
        local junkValue, junkCount = CalculateJunkValue()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sell All Junk Items")
        if junkCount > 0 then
            GameTooltip:AddDoubleLine("Items:", junkCount, 1, 1, 1, 1, 1, 1)
            GameTooltip:AddDoubleLine("Value:", GetCoinTextureString(junkValue), 1, 1, 1, 1, 1, 1)
        elseif IsAutomationAutoSellActive() then
            GameTooltip:AddLine("No junk left (auto-sold on open)", 0.5, 0.5, 0.5)
        else
            GameTooltip:AddLine("No junk items to sell", 0.5, 0.5, 0.5)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Ctrl+Right-click items in your bags to mark them as junk", 0.5, 0.5, 0.5, true)
        GameTooltip:Show()
    end)

    sellJunkButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    LayoutMerchantBottomRow()
    UpdateSellJunkPreview()
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
    if not merchantEventFrame then
        merchantEventFrame = CreateFrame("Frame")
    end

    sellJunkLayoutActive = true
    InstallMerchantLayoutHooks()

    merchantEventFrame:UnregisterAllEvents()
    local merchantFrame = merchantEventFrame
    merchantFrame:RegisterEvent("MERCHANT_SHOW")
    merchantFrame:RegisterEvent("MERCHANT_CLOSED")
    merchantFrame:RegisterEvent("BAG_UPDATE")
    merchantFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    merchantFrame:RegisterEvent("PLAYER_MONEY")
    merchantFrame:SetScript("OnEvent", function(self, event)
        if event == "MERCHANT_SHOW" then
            OnMerchantShow()
            CreateSellJunkButton()
        elseif event == "BAG_UPDATE" then
            if MerchantFrame and MerchantFrame:IsShown() then
                UpdateRepairCostFrame()
                UpdateSellJunkPreview()
            end
        elseif event == "UPDATE_INVENTORY_DURABILITY" or event == "PLAYER_MONEY" then
            -- After a repair, or when money changes whether the repair is affordable.
            if MerchantFrame and MerchantFrame:IsShown() then
                UpdateRepairCostFrame()
            end
        elseif event == "MERCHANT_CLOSED" then
            OnMerchantClose()
        end
    end)
    
    -- Setup context menu
    AddContextMenuOptions()
end

function VendorPlus.OnDisable()
    addon:Debug("VendorPlus module disabling")
    if merchantEventFrame then
        merchantEventFrame:UnregisterAllEvents()
        merchantEventFrame:SetScript("OnEvent", nil)
    end
    if repairCostFrame then repairCostFrame:Hide() end
    sellJunkLayoutActive = false
    if sellJunkButton then
        sellJunkButton:Hide()
        -- Hand the repair row back to its stock layout if the vendor is open right now.
        if MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1 then
            MerchantFrame_UpdateRepairButtons()
        end
    end
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
