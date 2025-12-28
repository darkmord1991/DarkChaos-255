-- ============================================================
-- DC-QoS: BagEnhancements Module (Bagnon-inspired)
-- ============================================================
-- Bag quality of life improvements
-- - Item quality borders
-- - Search/filter functionality  
-- - Item count totals
-- - Junk highlighting
-- - New item highlighting
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
        qualityBorders = true,
        borderSize = 2,
        junkHighlight = true,
        junkColor = { r = 0.5, g = 0.5, b = 0.5, a = 0.7 },
        newItemGlow = true,
        newItemDuration = 30,  -- seconds to show "new" glow
        itemCount = true,
        searchHighlight = true,
        fadeNonMatch = true,
        fadeAlpha = 0.3,
        showIlvl = true,
        showBindStatus = false,
        sortByQuality = false,
    },
}

-- Merge defaults
for k, v in pairs(defaults) do
    addon.defaults[k] = v
end

-- ============================================================
-- Quality Colors
-- ============================================================
local QualityColors = {
    [0] = { r = 0.62, g = 0.62, b = 0.62 },  -- Poor (gray)
    [1] = { r = 1.00, g = 1.00, b = 1.00 },  -- Common (white)
    [2] = { r = 0.12, g = 1.00, b = 0.00 },  -- Uncommon (green)
    [3] = { r = 0.00, g = 0.44, b = 0.87 },  -- Rare (blue)
    [4] = { r = 0.64, g = 0.21, b = 0.93 },  -- Epic (purple)
    [5] = { r = 1.00, g = 0.50, b = 0.00 },  -- Legendary (orange)
    [6] = { r = 0.90, g = 0.80, b = 0.50 },  -- Artifact (gold)
    [7] = { r = 0.00, g = 0.80, b = 1.00 },  -- Heirloom (cyan)
}

-- ============================================================
-- State Variables
-- ============================================================
local newItems = {}           -- Track newly acquired items
local searchText = ""         -- Current search filter
local itemBorders = {}        -- Created border frames
local itemOverlays = {}       -- Created overlay frames

-- ============================================================
-- Item Tracking
-- ============================================================
local function GetItemKey(bag, slot)
    return bag .. ":" .. slot
end

local function MarkItemAsNew(bag, slot)
    local key = GetItemKey(bag, slot)
    newItems[key] = GetTime()
end

local function IsItemNew(bag, slot)
    local settings = addon.settings.bags
    if not settings.newItemGlow then return false end
    
    local key = GetItemKey(bag, slot)
    local acquireTime = newItems[key]
    if not acquireTime then return false end
    
    local elapsed = GetTime() - acquireTime
    if elapsed > settings.newItemDuration then
        newItems[key] = nil
        return false
    end
    
    return true
end

local function ClearNewItem(bag, slot)
    local key = GetItemKey(bag, slot)
    newItems[key] = nil
end

-- ============================================================
-- Quality Border Creation
-- ============================================================
local function CreateQualityBorder(button)
    if button._dcqosBorder then return button._dcqosBorder end
    
    local border = CreateFrame("Frame", nil, button)
    border:SetAllPoints()
    border:SetFrameLevel(button:GetFrameLevel() + 1)
    
    -- Create border textures
    border.top = border:CreateTexture(nil, "OVERLAY")
    border.top:SetHeight(2)
    border.top:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 0)
    
    border.bottom = border:CreateTexture(nil, "OVERLAY")
    border.bottom:SetHeight(2)
    border.bottom:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
    
    border.left = border:CreateTexture(nil, "OVERLAY")
    border.left:SetWidth(2)
    border.left:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0)
    
    border.right = border:CreateTexture(nil, "OVERLAY")
    border.right:SetWidth(2)
    border.right:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
    
    border:Hide()
    button._dcqosBorder = border
    
    return border
end

local function SetBorderColor(border, r, g, b, a)
    border.top:SetTexture(r, g, b, a or 1)
    border.bottom:SetTexture(r, g, b, a or 1)
    border.left:SetTexture(r, g, b, a or 1)
    border.right:SetTexture(r, g, b, a or 1)
end

local function UpdateBorderSize(border, size)
    border.top:SetHeight(size)
    border.bottom:SetHeight(size)
    border.left:SetWidth(size)
    border.right:SetWidth(size)
end

-- ============================================================
-- Overlay Creation (for junk/new highlighting)
-- ============================================================
local function CreateItemOverlay(button)
    if button._dcqosOverlay then return button._dcqosOverlay end
    
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(button:GetFrameLevel() + 2)
    
    -- Junk/dim overlay
    overlay.dim = overlay:CreateTexture(nil, "OVERLAY")
    overlay.dim:SetAllPoints()
    overlay.dim:SetTexture(0.5, 0.5, 0.5, 0.7)
    overlay.dim:SetBlendMode("MOD")
    overlay.dim:Hide()
    
    -- New item glow
    overlay.glow = overlay:CreateTexture(nil, "OVERLAY")
    overlay.glow:SetAllPoints()
    overlay.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    overlay.glow:SetBlendMode("ADD")
    overlay.glow:SetVertexColor(0.3, 1, 0.3, 0.5)
    overlay.glow:Hide()
    
    -- Item level text
    overlay.ilvl = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    overlay.ilvl:SetPoint("TOPLEFT", 2, -2)
    overlay.ilvl:SetTextColor(1, 1, 0)
    overlay.ilvl:Hide()
    
    -- Bind status text
    overlay.bind = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    overlay.bind:SetPoint("BOTTOMLEFT", 2, 2)
    overlay.bind:SetTextColor(1, 0.5, 0)
    overlay.bind:Hide()
    
    button._dcqosOverlay = overlay
    
    return overlay
end

-- ============================================================
-- Button Update Handler
-- ============================================================
local function UpdateBagButton(button, bag, slot)
    local settings = addon.settings.bags
    if not settings.enabled then return end
    
    local itemLink = GetContainerItemLink(bag, slot)
    local border = CreateQualityBorder(button)
    local overlay = CreateItemOverlay(button)
    
    -- Reset state
    border:Hide()
    overlay.dim:Hide()
    overlay.glow:Hide()
    overlay.ilvl:Hide()
    overlay.bind:Hide()
    
    if not itemLink then
        return
    end
    
    -- Get item info
    local itemName, _, itemQuality, itemLevel, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
    if not itemName then return end
    
    -- Quality border
    if settings.qualityBorders and itemQuality and itemQuality >= 2 then
        local color = QualityColors[itemQuality]
        if color then
            SetBorderColor(border, color.r, color.g, color.b, 1)
            UpdateBorderSize(border, settings.borderSize)
            border:Show()
        end
    end
    
    -- Junk highlighting
    if settings.junkHighlight and itemQuality == 0 then
        local c = settings.junkColor
        overlay.dim:SetTexture(c.r, c.g, c.b, c.a)
        overlay.dim:Show()
    end
    
    -- New item glow
    if IsItemNew(bag, slot) then
        overlay.glow:Show()
    end
    
    -- Item level display
    if settings.showIlvl and itemLevel and itemLevel > 1 then
        overlay.ilvl:SetText(itemLevel)
        overlay.ilvl:Show()
    end
    
    -- Search highlighting
    if settings.searchHighlight and searchText ~= "" then
        local nameLower = itemName:lower()
        local searchLower = searchText:lower()
        
        if not nameLower:find(searchLower) then
            -- Item doesn't match search
            if settings.fadeNonMatch then
                button:SetAlpha(settings.fadeAlpha)
            end
        else
            button:SetAlpha(1)
        end
    else
        button:SetAlpha(1)
    end
end

-- ============================================================
-- Bag Frame Hooks
-- ============================================================
local function HookContainerFrame(frame)
    if frame._dcqosHooked then return end
    frame._dcqosHooked = true
    
    -- Hook item button updates
    local origUpdate = frame.Update
    if origUpdate then
        frame.Update = function(self, ...)
            local result = origUpdate(self, ...)
            
            -- Update all item buttons in this bag
            local bag = self:GetID()
            local numSlots = GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local buttonName = "ContainerFrame" .. self:GetID() .. "Item" .. slot
                local button = _G[buttonName]
                if button then
                    UpdateBagButton(button, bag, slot)
                end
            end
            
            return result
        end
    end
end

local function HookAllContainerFrames()
    for i = 1, NUM_CONTAINER_FRAMES or 5 do
        local frame = _G["ContainerFrame" .. i]
        if frame then
            HookContainerFrame(frame)
        end
    end
end

-- ============================================================
-- Search Box
-- ============================================================
local searchBox = nil

local function CreateSearchBox()
    if searchBox then return searchBox end
    
    -- Create search box that appears above the backpack
    searchBox = CreateFrame("EditBox", "DCQoSBagSearchBox", UIParent, "InputBoxTemplate")
    searchBox:SetSize(120, 20)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)
    searchBox:Hide()
    
    -- Position above backpack when it opens
    searchBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText() or ""
        -- Refresh all bag buttons
        for i = 1, NUM_CONTAINER_FRAMES or 5 do
            local frame = _G["ContainerFrame" .. i]
            if frame and frame:IsShown() then
                local bag = frame:GetID()
                local numSlots = GetContainerNumSlots(bag)
                for slot = 1, numSlots do
                    local buttonName = "ContainerFrame" .. i .. "Item" .. slot
                    local button = _G[buttonName]
                    if button then
                        UpdateBagButton(button, bag, slot)
                    end
                end
            end
        end
    end)
    
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    
    -- Add placeholder text
    local placeholder = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 5, 0)
    placeholder:SetText("Search...")
    searchBox.placeholder = placeholder
    
    searchBox:SetScript("OnEditFocusGained", function(self)
        self.placeholder:Hide()
    end)
    
    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            self.placeholder:Show()
        end
    end)
    
    return searchBox
end

local function PositionSearchBox()
    if not searchBox then return end
    
    -- Find the backpack frame
    local backpack = ContainerFrame1
    if backpack and backpack:IsShown() then
        searchBox:ClearAllPoints()
        searchBox:SetPoint("BOTTOMLEFT", backpack, "TOPLEFT", 10, 2)
        searchBox:Show()
    else
        searchBox:Hide()
    end
end

-- ============================================================
-- Item Tracking Events
-- ============================================================
local function OnBagUpdate(bag)
    -- Track new items
    local numSlots = GetContainerNumSlots(bag)
    for slot = 1, numSlots do
        local itemLink = GetContainerItemLink(bag, slot)
        local key = GetItemKey(bag, slot)
        
        -- Check if this is a new item (link changed and wasn't empty before)
        -- This is simplified; a full implementation would track item IDs
        if itemLink and not newItems[key] then
            -- Could mark as new here, but need to distinguish from existing items
            -- For now, mark items acquired during session as "new"
        end
    end
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function BagEnhancements.OnInitialize()
    addon:Debug("BagEnhancements module initializing")
    CreateSearchBox()
end

function BagEnhancements.OnEnable()
    addon:Debug("BagEnhancements module enabling")
    
    -- Hook container frames
    HookAllContainerFrames()
    
    -- Create event handler
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_OPEN")
    eventFrame:RegisterEvent("BAG_CLOSED")
    eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "BAG_UPDATE" then
            local bag = ...
            OnBagUpdate(bag)
            
            -- Update bag buttons
            for i = 1, NUM_CONTAINER_FRAMES or 5 do
                local frame = _G["ContainerFrame" .. i]
                if frame and frame:IsShown() and frame:GetID() == bag then
                    local numSlots = GetContainerNumSlots(bag)
                    for slot = 1, numSlots do
                        local buttonName = "ContainerFrame" .. i .. "Item" .. slot
                        local button = _G[buttonName]
                        if button then
                            UpdateBagButton(button, bag, slot)
                        end
                    end
                end
            end
        elseif event == "BAG_OPEN" then
            PositionSearchBox()
        elseif event == "BAG_CLOSED" then
            -- Hide search if no bags are open
            local anyOpen = false
            for i = 1, NUM_CONTAINER_FRAMES or 5 do
                local frame = _G["ContainerFrame" .. i]
                if frame and frame:IsShown() then
                    anyOpen = true
                    break
                end
            end
            if not anyOpen then
                searchBox:Hide()
                searchBox:SetText("")
                searchText = ""
            end
        end
    end)
    
    BagEnhancements.eventFrame = eventFrame
    
    -- Hook bag opening
    hooksecurefunc("OpenBag", function()
        PositionSearchBox()
    end)
    
    hooksecurefunc("OpenAllBags", function()
        PositionSearchBox()
    end)
end

function BagEnhancements.OnDisable()
    addon:Debug("BagEnhancements module disabling")
    
    if BagEnhancements.eventFrame then
        BagEnhancements.eventFrame:UnregisterAllEvents()
    end
    
    if searchBox then
        searchBox:Hide()
    end
end

-- ============================================================
-- Settings Panel Creation
-- ============================================================
function BagEnhancements.CreateSettings(parent)
    local settings = addon.settings.bags
    
    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Bag Enhancement Settings")
    
    -- Description
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Bagnon-inspired bag improvements including quality borders, search, and item highlighting.")
    desc:SetWidth(parent:GetWidth() - 32)
    desc:SetJustifyH("LEFT")
    
    local yOffset = -70
    
    -- ============================================================
    -- Enable Section
    -- ============================================================
    local enableCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    enableCb:SetPoint("TOPLEFT", 16, yOffset)
    enableCb.Text:SetText("Enable Bag Enhancements")
    enableCb:SetChecked(settings.enabled)
    enableCb:SetScript("OnClick", function(self)
        addon:SetSetting("bags.enabled", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Quality Borders Section
    -- ============================================================
    local borderHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    borderHeader:SetPoint("TOPLEFT", 16, yOffset)
    borderHeader:SetText("Item Quality")
    yOffset = yOffset - 25
    
    -- Quality Borders
    local qualityCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    qualityCb:SetPoint("TOPLEFT", 16, yOffset)
    qualityCb.Text:SetText("Show Quality Borders (green+)")
    qualityCb:SetChecked(settings.qualityBorders)
    qualityCb:SetScript("OnClick", function(self)
        addon:SetSetting("bags.qualityBorders", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Junk Highlighting
    local junkCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    junkCb:SetPoint("TOPLEFT", 16, yOffset)
    junkCb.Text:SetText("Dim Junk Items (gray)")
    junkCb:SetChecked(settings.junkHighlight)
    junkCb:SetScript("OnClick", function(self)
        addon:SetSetting("bags.junkHighlight", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Show Item Level
    local ilvlCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    ilvlCb:SetPoint("TOPLEFT", 16, yOffset)
    ilvlCb.Text:SetText("Show Item Level on Items")
    ilvlCb:SetChecked(settings.showIlvl)
    ilvlCb:SetScript("OnClick", function(self)
        addon:SetSetting("bags.showIlvl", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- New Items Section
    -- ============================================================
    local newHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    newHeader:SetPoint("TOPLEFT", 16, yOffset)
    newHeader:SetText("New Items")
    yOffset = yOffset - 25
    
    -- New Item Glow
    local glowCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    glowCb:SetPoint("TOPLEFT", 16, yOffset)
    glowCb.Text:SetText("Glow on New Items")
    glowCb:SetChecked(settings.newItemGlow)
    glowCb:SetScript("OnClick", function(self)
        addon:SetSetting("bags.newItemGlow", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Search Section
    -- ============================================================
    local searchHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    searchHeader:SetPoint("TOPLEFT", 16, yOffset)
    searchHeader:SetText("Search & Filter")
    yOffset = yOffset - 25
    
    -- Search Highlight
    local searchCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    searchCb:SetPoint("TOPLEFT", 16, yOffset)
    searchCb.Text:SetText("Enable Search Box")
    searchCb:SetChecked(settings.searchHighlight)
    searchCb:SetScript("OnClick", function(self)
        addon:SetSetting("bags.searchHighlight", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    -- Fade Non-Match
    local fadeCb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    fadeCb:SetPoint("TOPLEFT", 16, yOffset)
    fadeCb.Text:SetText("Fade Non-Matching Items")
    fadeCb:SetChecked(settings.fadeNonMatch)
    fadeCb:SetScript("OnClick", function(self)
        addon:SetSetting("bags.fadeNonMatch", self:GetChecked())
    end)
    
    return yOffset - 50
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("BagEnhancements", BagEnhancements)
