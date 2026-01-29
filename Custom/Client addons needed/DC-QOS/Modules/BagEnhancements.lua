-- ============================================================
-- DC-QoS: BagEnhancements Module (Hybrid Support)
-- ============================================================
-- Supports both Unified (OneBag) and Default (Blizzard) views.
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local BagEnhancements = {
    displayName = "Bags",
    settingKey = "bags",
    icon = "Interface\\Icons\\INV_Misc_Bag_07",
}

-- ============================================================
-- Default Settings
-- ============================================================
local defaults = {
    bags = {
        enabled = true,
        oneBag = true,          -- Enable unified bag view
        qualityBorders = true,
        junkHighlight = true,
        newItemGlow = true,
        newItemDuration = 30,
        searchHighlight = true,
        fadeNonMatch = true,
        fadeAlpha = 0.2,
        showIlvl = true,
        columns = 10,           -- Number of columns in inventory
        bankColumns = 14,       -- Number of columns in bank
        scale = 1.0,
    },
}

for k, v in pairs(defaults) do addon.defaults[k] = v end

-- Match DC-Leaderboards UI style across DC addons
local BG_FELLEATHER = "Interface\\AddOns\\DC-QOS\\Textures\\Backgrounds\\FelLeather_512.tga"
local BG_TINT_ALPHA = 0.60

local function ApplyLeaderboardsStyle(frame)
    if not frame or frame.__dcLeaderboardsStyle then return end
    frame.__dcLeaderboardsStyle = true

    if frame.SetBackdropColor then
        frame:SetBackdropColor(0, 0, 0, 0)
    end

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints()
    bg:SetTexture(BG_FELLEATHER)
    if bg.SetHorizTile then bg:SetHorizTile(false) end
    if bg.SetVertTile then bg:SetVertTile(false) end

    local tint = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    tint:SetAllPoints()
    tint:SetTexture(0, 0, 0, BG_TINT_ALPHA)

    frame.__dcBg = bg
    frame.__dcTint = tint
end

-- ============================================================
-- Constants & State
-- ============================================================
local FRAMES = {
    inventory = {
        name = "Inventory",
        bags = {0, 1, 2, 3, 4},
        title = "Inventory",
        colsSetting = "columns",
    },
    bank = {
        name = "Bank",
        bags = {-1, 5, 6, 7, 8, 9, 10, 11},
        title = "Bank",
        colsSetting = "bankColumns",
    }
}

local frames = {}       -- [name] = Frame
local bagProxies = {}   -- [bagID] = Frame
local itemButtons = {}  -- [bagID][slot] = Button
local newItems = {}     -- [bag:slot] = time
local searchBoxes = {}  -- [frameName] = EditBox

-- ============================================================
-- Helper Functions
-- ============================================================
local function GetItemKey(bag, slot) return bag .. ":" .. slot end

local function NormalizeSearchText(text)
    if not text then return "" end
    text = text:lower()
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

local function IsItemNew(bag, slot)
    local settings = addon.settings.bags
    if not settings.newItemGlow then return false end
    local key = GetItemKey(bag, slot)
    local acquireTime = newItems[key]
    if not acquireTime then return false end
    if (GetTime() - acquireTime) > settings.newItemDuration then
        newItems[key] = nil
        return false
    end
    return true
end

-- ============================================================
-- Visuals (Shared)
-- ============================================================
local function CreateButtonVisuals(button)
    if button._dcqosVisuals then return button._dcqosVisuals end
    
    local visuals = {}
    
    -- Border
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetAlpha(0.8)
    border:SetWidth(button:GetWidth() * 1.7)
    border:SetHeight(button:GetHeight() * 1.7)
    border:SetPoint("CENTER", button, "CENTER", 0, 0)
    border:Hide()
    visuals.border = border
    
    -- Dim (Junk)
    local dim = button:CreateTexture(nil, "OVERLAY")
    dim:SetAllPoints()
    dim:SetTexture(0, 0, 0, 0.6)
    dim:Hide()
    visuals.dim = dim
    
    -- New Item Glow
    local glow = button:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints()
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(0.2, 1.0, 0.2, 0.6)
    glow:Hide()
    visuals.glow = glow

    -- Search highlight
    local searchGlow = button:CreateTexture(nil, "OVERLAY")
    searchGlow:SetAllPoints()
    searchGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    searchGlow:SetBlendMode("ADD")
    searchGlow:SetVertexColor(1.0, 0.82, 0.2, 0.6)
    searchGlow:Hide()
    visuals.searchGlow = searchGlow
    
    -- ILvl
    local ilvl = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    ilvl:SetPoint("TOPLEFT", 2, -2)
    ilvl:SetTextColor(1, 1, 0)
    ilvl:Hide()
    visuals.ilvl = ilvl
    
    button._dcqosVisuals = visuals
    return visuals
end

local function UpdateButtonVisuals(button, bag, slot, searchText)
    local settings = addon.settings.bags
    if not settings.enabled then return end
    
    local visuals = CreateButtonVisuals(button)
    
    visuals.border:Hide()
    visuals.dim:Hide()
    visuals.glow:Hide()
    visuals.searchGlow:Hide()
    visuals.ilvl:Hide()
    button:SetAlpha(1)
    
    local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
    
    if not texture then return end
    
    -- Quality Fallback
    if (not quality or quality < 0) and link then
        local _, _, q = GetItemInfo(link)
        if q then quality = q end
    end
    
    -- 1. Quality Border
    if settings.qualityBorders and quality and quality >= 1 then
        local r, g, b = GetItemQualityColor(quality)
        visuals.border:SetVertexColor(r, g, b)
        visuals.border:Show()
    end
    
    -- 2. Junk
    if settings.junkHighlight and quality and quality == 0 then
        visuals.dim:Show()
    end
    
    -- 3. New Item
    if IsItemNew(bag, slot) then
        visuals.glow:Show()
    end
    
    -- 4. ILvl
    if settings.showIlvl and link then
        local _, _, _, itemLevel = GetItemInfo(link)
        if itemLevel and itemLevel > 1 then
            visuals.ilvl:SetText(itemLevel)
            visuals.ilvl:Show()
        end
    end
    
    -- 5. Search
    local search = NormalizeSearchText(searchText)
    if settings.searchHighlight and search ~= "" then
        local match = false
        if link then
            local name, _, _, _, _, type, subtype, _, equipLoc = GetItemInfo(link)
            
            if name and name:lower():find(search) then match = true end
            if type and type:lower():find(search) then match = true end
            if subtype and subtype:lower():find(search) then match = true end
            if equipLoc and _G[equipLoc] and _G[equipLoc]:lower():find(search) then match = true end
        end
        
        if match then
            visuals.searchGlow:Show()
            button:SetAlpha(1)
        elseif settings.fadeNonMatch then
            button:SetAlpha(settings.fadeAlpha)
            visuals.border:Hide()
        end
    end
end

-- ============================================================
-- OneBag Implementation
-- ============================================================
local function CreateBagProxy(bagID, parent)
    if bagProxies[bagID] then return bagProxies[bagID] end
    local f = CreateFrame("Frame", "DCQoS_BagProxy_" .. bagID, parent)
    f:SetID(bagID)
    bagProxies[bagID] = f
    return f
end

local function GetOrCreateButton(bag, slot, parentFrame)
    if not itemButtons[bag] then itemButtons[bag] = {} end
    if itemButtons[bag][slot] then return itemButtons[bag][slot] end
    
    local proxy = CreateBagProxy(bag, parentFrame)
    local name = "DCQoS_Item_" .. bag .. "_" .. slot
    
    local button = CreateFrame("Button", name, proxy, "ContainerFrameItemButtonTemplate")
    button:SetID(slot)
    button.bag = bag  -- Store bag ID for tooltip/click handling
    
    -- Setup click handlers (like Bagnon's item.lua)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    
    button:SetScript("OnClick", function(self, mouseButton)
        local bagID = self.bag
        local slotID = self:GetID()
        local link = GetContainerItemLink(bagID, slotID)
        
        -- Handle modified clicks (Shift+Click for link, Ctrl+Click for dressing room)
        if link and HandleModifiedItemClick(link) then
            return
        end
        
        -- Split stack with Shift+Click on stackable items
        if IsShiftKeyDown() and not CursorHasItem() then
            local texture, itemCount = GetContainerItemInfo(bagID, slotID)
            if itemCount and itemCount > 1 then
                OpenStackSplitFrame(itemCount, self, "BOTTOMRIGHT", "TOPRIGHT")
                return
            end
        end
        
        if mouseButton == "RightButton" then
            UseContainerItem(bagID, slotID)
        else
            PickupContainerItem(bagID, slotID)
        end
    end)
    
    button:SetScript("OnDragStart", function(self)
        PickupContainerItem(self.bag, self:GetID())
    end)
    
    button:SetScript("OnReceiveDrag", function(self)
        PickupContainerItem(self.bag, self:GetID())
    end)
    
    -- Stack split callback (called by StackSplitFrame)
    button.SplitStack = function(self, split)
        SplitContainerItem(self.bag, self:GetID(), split)
    end
    
    button:SetScript("OnEnter", function(self)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetBagItem(self.bag, self:GetID())
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    itemButtons[bag][slot] = button
    return button
end

-- Update the item display on a button (texture, count, quality)
local function UpdateButtonItem(button, bag, slot)
    local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
    
    -- Set item texture
    SetItemButtonTexture(button, texture)
    
    -- Set item count
    SetItemButtonCount(button, count)
    
    -- Set locked state (grayed out)
    SetItemButtonDesaturated(button, locked)
    
    -- Update cooldown
    local cooldown = _G[button:GetName() .. "Cooldown"]
    if cooldown then
        local start, duration, enable = GetContainerItemCooldown(bag, slot)
        CooldownFrame_SetTimer(cooldown, start, duration, enable)
    end
    
    -- Update normal texture for empty slots
    local normalTexture = _G[button:GetName() .. "NormalTexture"]
    if normalTexture then
        if texture then
            normalTexture:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        else
            normalTexture:SetTexture("Interface\\Buttons\\UI-Quickslot")
        end
    end
end

local function LayoutFrame(frameDefName)
    local frame = frames[frameDefName]
    if not frame then return end
    
    local def = FRAMES[frameDefName]
    local settings = addon.settings.bags
    local cols = settings[def.colsSetting] or 10
    local size = 37
    local spacing = 2
    local padding = 10
    
    local col, row = 0, 0
    local searchText = NormalizeSearchText(frame.searchBox:GetText())
    
    -- Clear all buttons first to prevent ghost items (e.g. when swapping to smaller bags)
    for _, bag in ipairs(def.bags) do
        if itemButtons[bag] then
            for _, button in pairs(itemButtons[bag]) do
                button:Hide()
            end
        end
    end
    
    for _, bag in ipairs(def.bags) do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local button = GetOrCreateButton(bag, slot, frame)
            -- Note: button parent is already set to proxy (for correct BagID), do not reparent to frame
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", padding + (col * (size + spacing)), -padding - 40 - (row * (size + spacing)))
            button:Show()
            
            -- Update base item display (texture, count, cooldown)
            UpdateButtonItem(button, bag, slot)
            -- Update visual overlays (borders, glows, search)
            UpdateButtonVisuals(button, bag, slot, searchText)
            
            col = col + 1
            if col >= cols then
                col = 0
                row = row + 1
            end
        end
    end
    
    if col == 0 then row = row - 1 end
    local width = (cols * (size + spacing)) + (padding * 2) - spacing
    local baseHeight = ((row + 1) * (size + spacing)) + padding + 40 + 5
    
    -- Add extra height for bank bag slots container
    local height = baseHeight
    if frameDefName == "bank" then
        height = baseHeight + 130  -- Extra space for bag slots + purchase (increased)
    end
    
    frame:SetSize(width, height)
    
    -- Update Info
    if frame.infoText then
        local free, total = 0, 0
        for _, bag in ipairs(def.bags) do
            local f, t = GetContainerNumFreeSlots(bag), GetContainerNumSlots(bag)
            free = free + f
            total = total + t
        end
        frame.infoText:SetText(string.format("Free: %d / %d", free, total))
    end
    
    -- Update Money
    if frameDefName == "inventory" and frame.moneyFrame then
        MoneyFrame_Update(frame.moneyFrame:GetName(), GetMoney())
    end
end

local function CreateBagFrame(frameDefName)
    if frames[frameDefName] then return frames[frameDefName] end
    
    local def = FRAMES[frameDefName]
    local f = CreateFrame("Frame", "DCQoS_" .. frameDefName, UIParent)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    ApplyLeaderboardsStyle(f)
    
    f:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then self:StartMoving() end
    end)
    f:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)
    
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText(def.title)
    
    -- Search
    local search = CreateFrame("EditBox", "DCQoS_"..frameDefName.."_Search", f, "InputBoxTemplate")
    search:SetSize(120, 20)
    search:SetPoint("TOP", f, "TOP", 0, -30) -- Centered horizontally, moved up 2 pixels
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function(self)
        LayoutFrame(frameDefName)
    end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() self:SetText("") end)
    f.searchBox = search

    local sortBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    sortBtn:SetSize(50, 20)
    sortBtn:SetPoint("RIGHT", search, "LEFT", -6, 0)
    sortBtn:SetText("Sort")
    sortBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Sort bags", 1, 1, 1)
        GameTooltip:AddLine("Click to auto-sort your bag items.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    sortBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    sortBtn:SetScript("OnClick", function()
        if frameDefName == "inventory" then
            if SortBags then SortBags() end
        else
            if SortBankBags then SortBankBags() end
        end
        if frames[frameDefName] and frames[frameDefName]:IsShown() then
            LayoutFrame(frameDefName)
        end
    end)
    
    local ph = search:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    ph:SetPoint("LEFT", 5, 0)
    ph:SetText("Search...")
    search:SetScript("OnEditFocusGained", function() ph:Hide() end)
    search:SetScript("OnEditFocusLost", function(self) if self:GetText()=="" then ph:Show() end end)
    
    -- Info (moved to top bar, next to title)
    local info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("LEFT", title, "RIGHT", 10, 0)
    f.infoText = info
    
    -- Money (moved to top bar, anchored after info with fixed width spacing)
    if frameDefName == "inventory" then
        local money = CreateFrame("Frame", "DCQoS_MoneyFrame", f, "SmallMoneyFrameTemplate")
        money:SetPoint("LEFT", info, "RIGHT", 15, 0)  -- Fixed position after info text
        f.moneyFrame = money
    end
    
    -- Position at bottom-right (like Blizzard bags)
    f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 120)
    f:Hide()
    
    -- Register for Escape key closing
    tinsert(UISpecialFrames, f:GetName())
    
    frames[frameDefName] = f
    return f
end

local function StripBankFrameVisuals()
    if not BankFrame then return end

    local regions = {
        BankFramePortrait,
        BankFrameTitleText,
        BankFrameBg,
        BankFrameBackground,
        BankFrameTopLeft,
        BankFrameTopRight,
        BankFrameBottomLeft,
        BankFrameBottomRight,
        BankFrameTexture0,
        BankFrameTexture1,
        BankFrameTexture2,
        BankFrameTexture3,
        BankFrameCloseButton,
        BankFrameMoneyFrame,
    }

    for _, region in ipairs(regions) do
        if region then
            region:Hide()
        end
    end

    if BankFrame.SetBackdrop then
        BankFrame:SetBackdrop(nil)
    end
    if BankFrame.SetBackdropColor then
        BankFrame:SetBackdropColor(0, 0, 0, 0)
    end
    if BankFrame.SetBackdropBorderColor then
        BankFrame:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

-- ============================================================
-- Default Frame Support (Fallback)
-- ============================================================
local function UpdateDefaultContainerFrame(frame)
    local settings = addon.settings.bags
    if settings.oneBag then return end -- Don't touch if OneBag is on
    
    local bag = frame:GetID()
    local name = frame:GetName()
    
    if not bag or not name then return end
    
    local numSlots = GetContainerNumSlots(bag)
    for slot = 1, numSlots do
        local button = _G[name .. "Item" .. slot]
        if button then
            UpdateButtonVisuals(button, bag, slot, "")
        end
    end
end

local function UpdateDefaultBankFrame()
    local settings = addon.settings.bags
    if settings.oneBag then return end
    
    local bag = -1
    for slot = 1, 28 do
        local button = _G["BankFrameItem" .. slot]
        if button then
            UpdateButtonVisuals(button, bag, slot, "")
        end
    end
end

-- ============================================================
-- Event Handlers
-- ============================================================
local function OnBagUpdate(bag)
    local settings = addon.settings.bags
    
    if settings.oneBag then
        -- OneBag Mode
        for name, def in pairs(FRAMES) do
            for _, b in ipairs(def.bags) do
                if b == bag then
                    if frames[name] and frames[name]:IsShown() then
                        LayoutFrame(name)
                    end
                    return
                end
            end
        end
    else
        -- Default Mode
        for i = 1, 13 do
            local frame = _G["ContainerFrame" .. i]
            if frame and frame:IsShown() and frame:GetID() == bag then
                UpdateDefaultContainerFrame(frame)
            end
        end
        if bag == -1 and BankFrame and BankFrame:IsShown() then
            UpdateDefaultBankFrame()
        end
    end
end

local function OpenInventory()
    if not addon.settings.bags.oneBag then return end
    local f = CreateBagFrame("inventory")
    f:Show()
    LayoutFrame("inventory")
    
    -- Hide default bags
    for i = 1, 13 do
        local def = _G["ContainerFrame"..i]
        if def then def:Hide() end
    end
end

local function CloseInventory()
    if frames.inventory then frames.inventory:Hide() end
end

local function EmbedBankBagSlots(bankFrame)
    if not BankFrame then return end
    if bankFrame._bankSlotsEmbedded then return end
    bankFrame._bankSlotsEmbedded = true

    -- Create a container for bank bag slots at the bottom of the DC bank frame
    local bagSlotsContainer = CreateFrame("Frame", nil, bankFrame)
    bagSlotsContainer:SetSize(400, 130)
    bagSlotsContainer:SetPoint("BOTTOM", bankFrame, "BOTTOM", 0, 8)
    bankFrame.bagSlotsContainer = bagSlotsContainer

    -- Title for bag slots
    local bagSlotsTitle = bagSlotsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bagSlotsTitle:SetPoint("TOP", bagSlotsContainer, "TOP", 0, 0)
    bagSlotsTitle:SetText("Bag Slots")

    -- Reparent the bank bag slot buttons (BankSlotsFrame children)
    local slotSize = 37
    local spacing = 4
    local numBankSlots = NUM_BANKBAGSLOTS or 7
    local totalWidth = (numBankSlots * slotSize) + ((numBankSlots - 1) * spacing)
    local startX = -totalWidth / 2 + slotSize / 2

    for i = 1, numBankSlots do
        local bagSlot = _G["BankFrameBag" .. i]
        if bagSlot then
            bagSlot:SetParent(bagSlotsContainer)
            bagSlot:ClearAllPoints()
            bagSlot:SetPoint("CENTER", bagSlotsContainer, "TOP", startX + ((i - 1) * (slotSize + spacing)), -35)
            bagSlot:Show()
        end
    end

    -- Reparent purchase info text (Do you wish to purchase...)
    if BankFramePurchaseInfo then
        BankFramePurchaseInfo:SetParent(bagSlotsContainer)
        BankFramePurchaseInfo:ClearAllPoints()
        BankFramePurchaseInfo:SetPoint("TOP", bagSlotsContainer, "TOP", 0, -60)
        BankFramePurchaseInfo:Show()
    end

    -- Reparent cost text
    if BankFrameSlotCost then
        BankFrameSlotCost:SetParent(bagSlotsContainer)
        BankFrameSlotCost:ClearAllPoints()
        BankFrameSlotCost:SetPoint("BOTTOM", bagSlotsContainer, "BOTTOM", -40, 10)
        BankFrameSlotCost:Show()
    end

    -- Reparent purchase button
    if BankFramePurchaseButton then
        BankFramePurchaseButton:SetParent(bagSlotsContainer)
        BankFramePurchaseButton:ClearAllPoints()
        BankFramePurchaseButton:SetPoint("BOTTOM", bagSlotsContainer, "BOTTOM", 40, 8)
        BankFramePurchaseButton:Show()
    end
end

local function OpenBank()
    if not addon.settings.bags.oneBag then return end
    local f = CreateBagFrame("bank")
    f:ClearAllPoints()
    -- Position at original Blizzard bank frame location (top-right area)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 70, -104)
    f:Show()
    LayoutFrame("bank")

    -- Embed bag slot purchase area into our frame
    EmbedBankBagSlots(f)

    -- Completely hide the Blizzard BankFrame but keep it "open" for server interaction
    if BankFrame then
        StripBankFrameVisuals()

        -- Hide the main item slots (we show them in our frame)
        for slot = 1, 28 do
            local button = _G["BankFrameItem" .. slot]
            if button then button:Hide() end
        end

        -- Move BankFrame off-screen but keep it enabled for purchase functionality
        BankFrame:ClearAllPoints()
        BankFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, 5000)
        BankFrame:SetAlpha(0)
    end
end

local function CloseBank()
    if frames.bank then frames.bank:Hide() end
    if BankFrame then
        BankFrame:SetAlpha(1)
        BankFrame:Hide()
    end
end

-- ============================================================
-- Module Lifecycle
-- ============================================================
function BagEnhancements.OnInitialize()
    addon:Debug("BagEnhancements initialized")
end

function BagEnhancements.OnEnable()
    local settings = addon.settings.bags
    
    -- ============================================================
    -- OneBag Mode: Replace bag functions (like Bagnon)
    -- ============================================================
    if settings.oneBag then
        -- Store original functions
        local oOpenBackpack = OpenBackpack
        local oToggleBackpack = ToggleBackpack
        local oToggleBag = ToggleBag
        local oOpenAllBags = OpenAllBags
        local oOpenBag = OpenBag
        
        -- Hide all default container frames
        local function HideDefaultBags()
            for i = 1, 13 do
                local f = _G["ContainerFrame"..i]
                if f then f:Hide() end
            end
        end
        
        -- Replace OpenBackpack
        OpenBackpack = function()
            if settings.oneBag then
                OpenInventory()
                HideDefaultBags()
            else
                oOpenBackpack()
            end
        end
        
        -- Replace ToggleBackpack
        ToggleBackpack = function()
            if settings.oneBag then
                if frames.inventory and frames.inventory:IsShown() then
                    CloseInventory()
                else
                    OpenInventory()
                    HideDefaultBags()
                end
            else
                oToggleBackpack()
            end
        end
        
        -- Replace ToggleBag
        ToggleBag = function(bagSlot)
            if settings.oneBag then
                -- Check if it's an inventory bag (0-4)
                local isInv = false
                for _, b in ipairs(FRAMES.inventory.bags) do
                    if b == bagSlot then isInv = true break end
                end
                
                if isInv then
                    if frames.inventory and frames.inventory:IsShown() then
                        CloseInventory()
                    else
                        OpenInventory()
                        HideDefaultBags()
                    end
                else
                    -- Bank bag, let it through for now
                    oToggleBag(bagSlot)
                end
            else
                oToggleBag(bagSlot)
            end
        end
        
        -- Replace OpenAllBags
        OpenAllBags = function(force)
            if settings.oneBag then
                if force or not (frames.inventory and frames.inventory:IsShown()) then
                    OpenInventory()
                    HideDefaultBags()
                else
                    CloseInventory()
                end
            else
                oOpenAllBags(force)
            end
        end
        
        -- Replace OpenBag
        OpenBag = function(bagSlot)
            if settings.oneBag then
                -- Check if it's an inventory bag (0-4)
                local isInv = false
                for _, b in ipairs(FRAMES.inventory.bags) do
                    if b == bagSlot then isInv = true break end
                end
                
                if isInv then
                    OpenInventory()
                    HideDefaultBags()
                else
                    -- Bank bag
                    oOpenBag(bagSlot)
                end
            else
                oOpenBag(bagSlot)
            end
        end
        
        -- Hook CloseAllBags (cannot replace, needed for combat/game menu)
        hooksecurefunc("CloseAllBags", function()
            if settings.oneBag then
                CloseInventory()
            end
        end)
        
        -- Hook CloseBackpack
        hooksecurefunc("CloseBackpack", function()
            if settings.oneBag then
                CloseInventory()
            end
        end)
    end
    
    -- Default Frame Hooks (Fallback for non-OneBag mode)
    hooksecurefunc("ContainerFrame_Update", function(frame)
        if not settings.oneBag then
            UpdateDefaultContainerFrame(frame)
        end
    end)
    
    if BankFrame_UpdateItems then
        hooksecurefunc("BankFrame_UpdateItems", function()
            if not settings.oneBag then
                UpdateDefaultBankFrame()
            end
        end)
    end
    
    -- Events
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("BAG_UPDATE")
    ev:RegisterEvent("PLAYER_MONEY")
    ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    ev:RegisterEvent("BANKFRAME_OPENED")
    ev:RegisterEvent("BANKFRAME_CLOSED")
    
    ev:SetScript("OnEvent", function(self, event, ...)
        if event == "BAG_UPDATE" then
            OnBagUpdate(...)
        elseif event == "PLAYER_MONEY" then
            if frames.inventory and frames.inventory:IsShown() then
                MoneyFrame_Update(frames.inventory.moneyFrame:GetName(), GetMoney())
            end
        elseif event == "GET_ITEM_INFO_RECEIVED" then
            if settings.oneBag then
                if frames.inventory and frames.inventory:IsShown() then LayoutFrame("inventory") end
                if frames.bank and frames.bank:IsShown() then LayoutFrame("bank") end
            else
                -- Refresh defaults
                for i = 1, 13 do
                    local f = _G["ContainerFrame"..i]
                    if f and f:IsShown() then UpdateDefaultContainerFrame(f) end
                end
            end
        elseif event == "BANKFRAME_OPENED" then
            if settings.oneBag then
                OpenBank()
                OpenInventory()
            end
        elseif event == "BANKFRAME_CLOSED" then
            if settings.oneBag then
                CloseBank()
                CloseInventory()
            end
        end
    end)
    BagEnhancements.eventFrame = ev

    if addon and addon.Debug then
        addon:Debug("Bag Enhancements Loaded. OneBag Mode: " .. tostring(settings.oneBag))
    end
end

function BagEnhancements.OnDisable()
    if frames.inventory then frames.inventory:Hide() end
    if frames.bank then frames.bank:Hide() end
end

-- ============================================================
-- Settings
-- ============================================================
function BagEnhancements.CreateSettings(parent)
    local settings = addon.settings.bags
    local yOffset = -20
    
    local function CreateCb(text, key)
        local cb = addon:CreateCheckbox(parent)
        cb:SetPoint("TOPLEFT", 16, yOffset)
        cb.Text:SetText(text)
        cb:SetChecked(settings[key])
        cb:SetScript("OnClick", function(self)
            addon:SetSetting("bags." .. key, self:GetChecked())
            -- Force refresh
            if key == "oneBag" then
                ReloadUI() -- Safest way to switch modes
            end
        end)
        yOffset = yOffset - 30
        return cb
    end
    
    CreateCb("Enable OneBag View (Requires Reload)", "oneBag")
    CreateCb("Show Quality Borders", "qualityBorders")
    CreateCb("Dim Junk Items", "junkHighlight")
    CreateCb("Show Item Level", "showIlvl")
    CreateCb("Enable Search", "searchHighlight")
    
    return yOffset
end

addon:RegisterModule("BagEnhancements", BagEnhancements)
