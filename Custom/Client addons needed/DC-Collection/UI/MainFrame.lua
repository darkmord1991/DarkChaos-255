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

    -- Helper to try getting item icon
    local function TryGetItemIcon(itemId)
        if not itemId then return nil end
        -- Try GetItemIcon if available (custom/retail)
        if type(GetItemIcon) == "function" then
            local icon = GetItemIcon(itemId)
            if icon then return icon end
        end
        -- Try GetItemInfo
        if type(GetItemInfo) == "function" then
            local texture = select(10, GetItemInfo(itemId))
            if texture then return texture end
        end
        return nil
    end

    if collType == "mounts" then
        -- Mounts use spell ID - GetSpellTexture is the most reliable in WotLK
        if type(GetSpellTexture) == "function" and numericId then
            local texture = GetSpellTexture(numericId)
            if texture and texture ~= "" then
                return texture
            end
        end
        if type(GetSpellInfo) == "function" and numericId then
            local _, _, icon = GetSpellInfo(numericId)
            if icon and icon ~= "" then
                return icon
            end
        end

        -- Some mount definitions include itemId for the mount item
        if def then
            local itemId = def.itemId or def.item_id or def.itemID
            if itemId then
                itemId = tonumber(itemId) or itemId
                local icon = TryGetItemIcon(itemId)
                if icon then return icon end
            end
        end
    elseif collType == "pets" then
        -- Companion pets: try item info first, then spell
        local itemId = def and (def.itemId or def.item_id or def.itemID)
        local spellId = def and (def.spellId or def.spell_id or def.spellID)
        
        -- If no explicit IDs, assume numericId is Item ID
        if not itemId and not spellId then
             itemId = numericId
        end

        -- Try Item Info
        local icon = TryGetItemIcon(itemId)
        if icon then return icon end

        -- Try Spell Info (fallback or if explicit spellId)
        local sId = spellId or numericId
        if sId then
            if type(GetSpellTexture) == "function" then
                local texture = GetSpellTexture(sId)
                if texture and texture ~= "" then
                    return texture
                end
            end
            if type(GetSpellInfo) == "function" then
                local _, _, icon = GetSpellInfo(sId)
                if icon and icon ~= "" then
                    return icon
                end
            end
        end
        
        -- Fallback default
        return "Interface\\Icons\\INV_Box_PetCarrier_01"
    elseif collType == "heirlooms" then
        -- Heirlooms: item ID -> GetItemInfo (10th return = texture)
        local itemId = numericId
        if def then
            itemId = def.itemId or def.item_id or def.itemID or numericId
        end
        itemId = tonumber(itemId) or itemId

        local icon = TryGetItemIcon(itemId)
        if icon then return icon end

        -- Fallback: default heirloom icon
        return "Interface\\Icons\\INV_Misc_Rune_01"
    elseif collType == "achievements" then
        -- Achievements: use GetAchievementInfo if available (WotLK 3.3.5+)
        if numericId and type(GetAchievementInfo) == "function" then
            local _, _, _, _, _, _, _, _, _, icon = GetAchievementInfo(numericId)
            if icon and icon ~= "" then
                return icon
            end
        end

        -- Fallback: default achievement icon
        return "Interface\\Icons\\Achievement_General"
    elseif collType == "titles" then
        -- Titles don't have icons in WoW, use a scroll icon
        return "Interface\\Icons\\INV_Scroll_11"
    elseif collType == "transmog" and def then
        local itemId = def.itemId or def.item_id or def.itemID or numericId
        if itemId then
            itemId = tonumber(itemId) or itemId
            -- In WotLK 3.3.5a, use GetItemInfo for texture
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

local FRAME_WIDTH = 1000 -- Increased width
local FRAME_HEIGHT = 650 -- Increased height
local TAB_HEIGHT = 28
local HEADER_HEIGHT = 60
local FILTER_HEIGHT = 32
local FOOTER_HEIGHT = 40

-- Pagination settings - can be adjusted for "more items per page" effect
local GRID_ITEMS_PER_PAGE = 48  -- 8 columns x 6 rows (increased from 24)
local MOUNT_ITEMS_PER_PAGE = 20 -- Increased from 12

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

    -- Premium Black Background Overlay
    frame.bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    frame.bg:SetPoint("TOPLEFT", 10, -10)
    frame.bg:SetPoint("BOTTOMRIGHT", -10, 10)
    frame.bg:SetTexture(0, 0, 0, 0.95)

    -- Portrait (Retail style)
    local portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(60, 60)
    portrait:SetPoint("TOPLEFT", -5, 7)
    portrait:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    
    -- Circular mask/border for portrait
    local portraitFrame = frame:CreateTexture(nil, "OVERLAY")
    portraitFrame:SetSize(80, 80)
    portraitFrame:SetPoint("TOPLEFT", -14, 14)
    portraitFrame:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    
    frame.portrait = portrait

    -- Event handling for item info
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "GET_ITEM_INFO_RECEIVED" then
            if DC.MainFrame and DC.MainFrame:IsShown() then
                DC:RefreshCurrentTab()
            end
        end
    end)
    
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
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -20)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -20)
    header:SetHeight(HEADER_HEIGHT)
    
    -- Stats display
    header.statsText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.statsText:SetPoint("TOPLEFT", header, "TOPLEFT", 5, -2)
    header.statsText:SetJustifyH("LEFT")

    header.totalStatsText = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header.totalStatsText:SetPoint("TOPLEFT", header.statsText, "BOTTOMLEFT", 0, -2)
    header.totalStatsText:SetJustifyH("LEFT")
    
    -- Currency display
    header.emblemsText = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header.emblemsText:SetPoint("TOPRIGHT", header, "TOPRIGHT", -10, -5)
    header.emblemsText:SetJustifyH("RIGHT")
    
    header.tokensText = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header.tokensText:SetPoint("TOPRIGHT", header.emblemsText, "TOPLEFT", -10, 0)
    header.tokensText:SetJustifyH("RIGHT")

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
    tabBar:SetPoint("TOPLEFT", parent.Header, "BOTTOMLEFT", 0, 0)
    tabBar:SetPoint("TOPRIGHT", parent.Header, "BOTTOMRIGHT", 0, 0)
    tabBar:SetHeight(TAB_HEIGHT)
    
    -- Tab background
    local tabBg = tabBar:CreateTexture(nil, "BACKGROUND")
    tabBg:SetAllPoints()
    tabBg:SetTexture(0, 0, 0, 0.3)
    
    -- Create tabs (ordered: My Collection, Wardrobe, Mounts, Pets, then rest)
    local tabs = {
        { key = "overview",     text = "My Collection",       icon = "Interface\\Icons\\INV_Misc_Book_09" },
        { key = "wardrobe",     text = "Wardrobe",            icon = "Interface\\Icons\\INV_Chest_Cloth_17" },
        { key = "mounts",       text = L["TAB_MOUNTS"] or "Mounts",       icon = "Interface\\Icons\\Ability_Mount_RidingHorse" },
        { key = "pets",         text = L["TAB_PETS"] or "Companions",   icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },
        { key = "heirlooms",    text = L["TAB_HEIRLOOMS"] or "Heirlooms",    icon = "Interface\\Icons\\INV_Sword_43" },
        { key = "titles",       text = L["TAB_TITLES"] or "Titles",       icon = "Interface\\Icons\\INV_Scroll_11" },
        { key = "achievements", text = L["TAB_ACHIEVEMENTS"] or "Achievements", icon = "Interface\\Icons\\Achievement_General" },
        { key = "shop",         text = L["TAB_SHOP"] or "Shop",         icon = "Interface\\Icons\\INV_Misc_Bag_10_Green" },
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
    tab.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
    
    -- Highlight
    tab.highlight = tab:CreateTexture(nil, "HIGHLIGHT")
    tab.highlight:SetAllPoints()
    tab.highlight:SetTexture(0.4, 0.4, 0.4, 0.5)
    
    -- Checked texture
    tab.checked = tab:CreateTexture(nil, "BACKGROUND")
    tab.checked:SetAllPoints()
    tab.checked:SetTexture(0.3, 0.3, 0.6, 0.8)
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
    filterBar:SetPoint("TOPLEFT", parent.TabBar, "BOTTOMLEFT", 0, 0)
    filterBar:SetPoint("TOPRIGHT", parent.TabBar, "BOTTOMRIGHT", 0, 0)
    filterBar:SetHeight(FILTER_HEIGHT)
    
    -- Background
    local filterBg = filterBar:CreateTexture(nil, "BACKGROUND")
    filterBg:SetAllPoints()
    filterBg:SetTexture(0, 0, 0, 0.2)
    
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
    local isOverview = (tabKey == "overview")
    local isAchievements = (tabKey == "achievements")
    local isWardrobe = (tabKey == "wardrobe")
    
    -- Hide filter bar for overview/achievements/wardrobe (wardrobe has its own filtering UI)
    if isOverview or isAchievements or isWardrobe then
        fb:Hide()
    else
        fb:Show()
    end

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
    contentBg:SetTexture(0, 0, 0, 0.3)

    -- Details bar: left info + right visuals (shared across tabs)
    local details = CreateFrame("Frame", nil, content)
    details:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -5)
    details:SetPoint("TOPRIGHT", content, "TOPRIGHT", -5, -5)
    details:SetHeight(80)

    details.bg = details:CreateTexture(nil, "BACKGROUND")
    details.bg:SetAllPoints()
    details.bg:SetTexture(0, 0, 0, 0.25)

    details.iconBorder = details:CreateTexture(nil, "BORDER")
    details.iconBorder:SetSize(70, 70)
    details.iconBorder:SetPoint("RIGHT", details, "RIGHT", -8, 0)
    details.iconBorder:SetTexture(0.25, 0.25, 0.25, 0.8)

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

    -- Use/Summon button for mounts/pets/titles
    details.useBtn = CreateFrame("Button", nil, details, "UIPanelButtonTemplate")
    details.useBtn:SetSize(80, 22)
    details.useBtn:SetPoint("BOTTOMLEFT", details, "BOTTOMLEFT", 10, 8)
    details.useBtn:SetText(L["SUMMON"] or "Summon")
    details.useBtn:SetScript("OnClick", function()
        if DC.selectedItem then
            DC:OnItemLeftClick(DC.selectedItem)
        end
    end)
    details.useBtn:Hide()

    content.details = details

    -- ========================================================================
    -- RETAIL STYLE MOUNT FRAMES
    -- ========================================================================
    
    -- Mount List (Left Side)
    local mountList = CreateFrame("ScrollFrame", "DCCollectionMountList", content, "UIPanelScrollFrameTemplate")
    mountList:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -5)
    mountList:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 5, 5)
    mountList:SetWidth(260) -- Retail width
    mountList:Hide()
    
    -- List Background (Inset style)
    mountList.bg = mountList:CreateTexture(nil, "BACKGROUND")
    mountList.bg:SetAllPoints()
    mountList.bg:SetTexture(0, 0, 0, 0.4)
    
    local mountListChild = CreateFrame("Frame", nil, mountList)
    mountListChild:SetSize(mountList:GetWidth(), 1)
    mountList:SetScrollChild(mountListChild)
    
    content.mountList = mountList
    content.mountListChild = mountListChild
    
    -- Mount Model Preview (Right Side)
    local mountPreview = CreateFrame("Frame", nil, content)
    mountPreview:SetPoint("TOPLEFT", mountList, "TOPRIGHT", 5, 0)
    mountPreview:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -5, 5)
    mountPreview:Hide()
    
    mountPreview.bg = mountPreview:CreateTexture(nil, "BACKGROUND")
    mountPreview.bg:SetAllPoints()
    mountPreview.bg:SetTexture(0, 0, 0, 0.3)
    
    -- Model
    mountPreview.model = CreateFrame("DressUpModel", "DCCollectionMountModel", mountPreview)
    mountPreview.model:SetAllPoints() -- Fill the preview area
    mountPreview.model:EnableMouse(true)
    mountPreview.model:EnableMouseWheel(true)
    
    -- Info Overlay (Retail style: Icon, Name, Source inside the model frame)
    local infoFrame = CreateFrame("Frame", nil, mountPreview)
    infoFrame:SetPoint("TOPLEFT", mountPreview, "TOPLEFT", 10, -10)
    infoFrame:SetSize(300, 60)
    
    infoFrame.icon = infoFrame:CreateTexture(nil, "ARTWORK")
    infoFrame.icon:SetSize(46, 46)
    infoFrame.icon:SetPoint("LEFT", infoFrame, "LEFT", 0, 0)
    infoFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    
    infoFrame.name = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    infoFrame.name:SetPoint("TOPLEFT", infoFrame.icon, "TOPRIGHT", 10, 0)
    infoFrame.name:SetJustifyH("LEFT")
    infoFrame.name:SetText("")
    
    infoFrame.source = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    infoFrame.source:SetPoint("TOPLEFT", infoFrame.name, "BOTTOMLEFT", 0, -5)
    infoFrame.source:SetJustifyH("LEFT")
    infoFrame.source:SetText("")
    
    mountPreview.info = infoFrame
    
    mountPreview.model:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.rotating = true
            self.prevX = GetCursorPosition()
        end
    end)
    mountPreview.model:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.rotating = false
        end
    end)
    mountPreview.model:SetScript("OnUpdate", function(self)
        if self.rotating then
            local x = GetCursorPosition()
            local delta = (x - (self.prevX or x)) * 0.01
            self.rotation = (self.rotation or 0) + delta
            self:SetFacing(self.rotation)
            self.prevX = x
        end
    end)
    mountPreview.model:SetScript("OnMouseWheel", function(self, delta)
        local zoom = self.zoom or 0
        zoom = zoom + delta * 0.1
        zoom = math.max(-1, math.min(1, zoom))
        self.zoom = zoom
        self:SetCamera(0)
        self:SetPosition(zoom, 0, 0)
    end)
    
    -- Summon Button
    mountPreview.summonBtn = CreateFrame("Button", nil, mountPreview, "UIPanelButtonTemplate")
    mountPreview.summonBtn:SetSize(140, 22)
    mountPreview.summonBtn:SetPoint("BOTTOM", mountPreview, "BOTTOM", 0, 10)
    mountPreview.summonBtn:SetText(L["SUMMON"] or "Summon")
    mountPreview.summonBtn:SetScript("OnClick", function()
        if DC.selectedItem then
            DC:OnItemLeftClick(DC.selectedItem)
        end
    end)
    
    -- Favorite Button
    mountPreview.favBtn = CreateFrame("Button", nil, mountPreview)
    mountPreview.favBtn:SetSize(30, 30)
    mountPreview.favBtn:SetPoint("LEFT", mountPreview.summonBtn, "RIGHT", 10, 0)
    mountPreview.favBtn:SetNormalTexture("Interface\\Icons\\Achievement_GuildPerk_HappyHour")
    mountPreview.favBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    mountPreview.favBtn:SetScript("OnClick", function()
        if DC.selectedItem then
            DC:OnItemRightClick(DC.selectedItem)
            -- Refresh UI
            DC:UpdateMountPreview(DC.selectedItem)
        end
    end)
    
    -- Toggle Player Checkbox
    local togglePlayer = CreateFrame("CheckButton", nil, mountPreview, "UICheckButtonTemplate")
    togglePlayer:SetSize(24, 24)
    togglePlayer:SetPoint("BOTTOMRIGHT", mountPreview, "BOTTOMRIGHT", -10, 10)
    
    togglePlayer.text = togglePlayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    togglePlayer.text:SetPoint("RIGHT", togglePlayer, "LEFT", -2, 0)
    togglePlayer.text:SetText("Show Player")
    
    togglePlayer:SetScript("OnClick", function(self)
        DC.showPlayerInMountPreview = self:GetChecked()
        if DC.selectedItem then
            DC:UpdateMountPreview(DC.selectedItem)
        end
    end)
    
    mountPreview.togglePlayer = togglePlayer
    
    content.mountPreview = mountPreview

    -- 3D Model Preview Panel (for mounts/pets)
    local modelPanel = CreateFrame("Frame", nil, content)
    modelPanel:SetPoint("TOPRIGHT", content, "TOPRIGHT", -5, -90)
    modelPanel:SetSize(200, 200)
    modelPanel:Hide()

    modelPanel.bg = modelPanel:CreateTexture(nil, "BACKGROUND")
    modelPanel.bg:SetAllPoints()
    modelPanel.bg:SetTexture(0.05, 0.05, 0.1, 0.9)

    modelPanel.border = modelPanel:CreateTexture(nil, "BORDER")
    modelPanel.border:SetPoint("TOPLEFT", -2, 2)
    modelPanel.border:SetPoint("BOTTOMRIGHT", 2, -2)
    modelPanel.border:SetTexture(0.3, 0.3, 0.3, 1)

    -- 3D Model
    modelPanel.model = CreateFrame("DressUpModel", "DCCollectionModelPreview", modelPanel)
    modelPanel.model:SetPoint("TOPLEFT", 5, -5)
    modelPanel.model:SetPoint("BOTTOMRIGHT", -5, 5)
    modelPanel.model:EnableMouse(true)
    modelPanel.model:EnableMouseWheel(true)
    modelPanel.model.rotation = 0
    modelPanel.model.zoom = 0

    modelPanel.model:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.rotating = true
            self.prevX = GetCursorPosition()
        end
    end)

    modelPanel.model:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.rotating = false
        end
    end)

    modelPanel.model:SetScript("OnUpdate", function(self)
        if self.rotating then
            local x = GetCursorPosition()
            local delta = (x - (self.prevX or x)) * 0.01
            self.rotation = (self.rotation or 0) + delta
            self:SetFacing(self.rotation)
            self.prevX = x
        end
    end)

    modelPanel.model:SetScript("OnMouseWheel", function(self, delta)
        local zoom = self.zoom or 0
        zoom = zoom + delta * 0.1
        zoom = math.max(-1, math.min(1, zoom))
        self.zoom = zoom
        self:SetCamera(0)
        self:SetPosition(zoom, 0, 0)
    end)

    content.modelPanel = modelPanel

    -- Stats panel shown under the model preview (used by Heirlooms)
    local statsPanel = CreateFrame("Frame", nil, content)
    statsPanel:SetPoint("TOPLEFT", modelPanel, "BOTTOMLEFT", 0, -5)
    statsPanel:SetPoint("TOPRIGHT", modelPanel, "BOTTOMRIGHT", 0, -5)
    statsPanel:SetHeight(110)
    statsPanel:Hide()

    statsPanel.bg = statsPanel:CreateTexture(nil, "BACKGROUND")
    statsPanel.bg:SetAllPoints()
    statsPanel.bg:SetTexture(0, 0, 0, 0.25)

    statsPanel.text = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsPanel.text:SetPoint("TOPLEFT", statsPanel, "TOPLEFT", 6, -6)
    statsPanel.text:SetPoint("BOTTOMRIGHT", statsPanel, "BOTTOMRIGHT", -6, 6)
    statsPanel.text:SetJustifyH("LEFT")
    statsPanel.text:SetJustifyV("TOP")
    statsPanel.text:SetText("")

    content.modelStatsPanel = statsPanel
    
    -- Scroll frame (adjusted width when model panel is shown)
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
    if d.useBtn then d.useBtn:Hide() end

    -- Hide model panel
    local modelPanel = self.MainFrame.Content.modelPanel
    if modelPanel then
        modelPanel:Hide()
        modelPanel.model:ClearModel()
    end

    local statsPanel = self.MainFrame.Content.modelStatsPanel
    if statsPanel then
        statsPanel:Hide()
        if statsPanel.text then
            statsPanel.text:SetText("")
        end
    end

    self.selectedItem = nil
end

function DC:UpdateMountPreview(item)
    if not self.MainFrame or not self.MainFrame.Content or not self.MainFrame.Content.mountPreview then return end
    local p = self.MainFrame.Content.mountPreview
    
    if not item then
        p.info.name:SetText("Select a Mount")
        p.info.source:SetText("")
        p.info.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        p.model:ClearModel()
        p.summonBtn:Disable()
        p.favBtn:Hide()
        return
    end
    
    local r, g, b = GetRarityColor(self, item.rarity or 1)
    p.info.name:SetText(item.name or "Unknown")
    p.info.name:SetTextColor(r, g, b)
    
    local sourceText = item.sourceText or self:FormatSource(item.source)
    p.info.source:SetText(sourceText or "")
    
    p.info.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    
    -- Model
    p.model:ClearModel()
    local displayId = item.definition and (item.definition.displayId or item.definition.display_id or item.definition.creatureId)
    
    -- Fallback: check if item itself has displayId
    if not displayId and item.displayId then
        displayId = item.displayId
    end

    if displayId and displayId > 0 then
        if p.model.SetCreature then
            p.model:SetCreature(displayId)
        elseif p.model.SetDisplayInfo then
            p.model:SetDisplayInfo(displayId)
        end
        p.model:SetCamera(0) -- Reset camera
    else
        -- If no display ID, maybe show a generic model or nothing?
        -- For now, just ensure it's cleared.
    end
    p.model:SetPosition(0, 0, 0)
    p.model:SetFacing(0)
    
    -- Buttons
    if item.collected then
        p.summonBtn:Enable()
        p.summonBtn:SetText(L["SUMMON"] or "Summon")
    else
        p.summonBtn:Disable()
        p.summonBtn:SetText(L["NOT_COLLECTED"] or "Not Collected")
    end
    
    p.favBtn:Show()
    if item.is_favorite then
        p.favBtn:SetNormalTexture("Interface\\Icons\\Achievement_GuildPerk_HappyHour")
        if p.favBtn:GetNormalTexture() then
            p.favBtn:GetNormalTexture():SetDesaturated(false)
        end
    else
        p.favBtn:SetNormalTexture("Interface\\Icons\\INV_Misc_Star_01") -- Or empty star
        if p.favBtn:GetNormalTexture() then
            p.favBtn:GetNormalTexture():SetDesaturated(true)
        end
    end
end

function DC:UpdateDetailsPanel(item)
    -- If we are in mount mode, update the mount preview instead
    if self.activeTab == "mounts" then
        self:UpdateMountPreview(item)
        return
    end

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

    -- Store selected item for use button
    self.selectedItem = item

    -- Show use button for collected mounts/pets/titles
    local collType = item.type
    if collType == "shop" then
        collType = item.collectionTypeName
    end

    if (collType == "mounts" or collType == "pets" or collType == "titles" or collType == "heirlooms") and item.collected then
        if collType == "mounts" then
            d.useBtn:SetText(L["SUMMON"] or "Summon")
        elseif collType == "pets" then
            d.useBtn:SetText(L["SUMMON"] or "Summon")
        elseif collType == "heirlooms" then
            d.useBtn:SetText("Add to bags")
        elseif collType == "titles" then
            d.useBtn:SetText(L["SET_TITLE"] or "Set Title")
        end
        d.useBtn:Show()
    else
        d.useBtn:Hide()
    end

    -- Heirlooms: show tooltip summary in line2.
    if collType == "heirlooms" then
        local itemId = (item.definition and (item.definition.itemId or item.definition.item_id or item.definition.itemID)) or item.id
        itemId = tonumber(itemId) or itemId
        local link = (type(itemId) == "number" and itemId > 0) and ("item:" .. itemId) or nil
        if link then
            self._scanTooltip = self._scanTooltip or CreateFrame("GameTooltip", "DCCollectionScanTooltip", UIParent, "GameTooltipTemplate")
            local tip = self._scanTooltip
            tip:SetOwner(UIParent, "ANCHOR_NONE")
            tip:ClearLines()
            pcall(function() tip:SetHyperlink(link) end)

            local picked = {}
            for i = 2, 10 do
                local fs = _G["DCCollectionScanTooltipTextLeft" .. i]
                local txt = fs and fs.GetText and fs:GetText() or nil
                if txt and txt ~= "" then
                    if string.find(txt, "Item Level", 1, true)
                        or string.find(txt, "Requires Level", 1, true)
                        or string.find(txt, "Level", 1, true)
                        or string.find(txt, "Armor", 1, true)
                        or string.find(txt, "Damage", 1, true)
                        or string.find(txt, "+", 1, true) then
                        picked[#picked + 1] = txt
                    end
                end
                if #picked >= 2 then
                    break
                end
            end

            if #picked > 0 then
                d.line2:SetText(table.concat(picked, "  "))
            else
                d.line2:SetText("Loading item data...")
                if DC and type(DC.After) == "function" then
                    DC.After(0.3, function()
                        if self.selectedItem and self.selectedItem.id == item.id then
                            self:UpdateDetailsPanel(item)
                        end
                    end)
                end
            end
        else
            d.line2:SetText("Loading item data...")
        end
    end

    -- Show 3D model for mounts/pets/transmog/heirlooms
    local modelPanel = self.MainFrame.Content.modelPanel
    local statsPanel = self.MainFrame.Content.modelStatsPanel
    if modelPanel and (collType == "mounts" or collType == "pets" or collType == "transmog" or collType == "heirlooms") then
        local displayId = item.definition and (item.definition.displayId or item.definition.display_id or item.definition.creatureId)

        -- Heirlooms: use the framed Wardrobe-style preview panel and hide the standard modelPanel.
        if collType == "heirlooms" then
            modelPanel:Hide()
            if modelPanel.model then
                modelPanel.model:ClearModel()
            end

            local itemId = item.definition and (item.definition.itemId or item.definition.item_id or item.definition.itemID) or item.id
            itemId = tonumber(itemId) or itemId

            -- Avoid spamming "cannot be equipped" for non-equippable heirloom tokens.
            local canTryOn = true
            if type(GetItemInfo) == "function" and type(itemId) == "number" then
                local equipLoc = select(9, GetItemInfo(itemId))
                if equipLoc == nil or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP" then
                    canTryOn = false
                end
            end

            self:ShowHeirloomPreview(itemId, { canTryOn = canTryOn, undress = canTryOn })
        else
            -- Any non-heirloom type: ensure heirloom preview is hidden.
            self:HideHeirloomPreview()

            modelPanel:Show()
            local model = modelPanel.model
            model:ClearModel()
            model.rotation = 0
            model.zoom = 0

            if collType == "transmog" then
                -- Transmog: Show player and try on item
                model:SetUnit("player")
                if model.Undress then
                    model:Undress()
                end
                if model.SetPortraitZoom then
                    model:SetPortraitZoom(0)
                end
                if model.SetCamDistanceScale then
                    model:SetCamDistanceScale(1.6)
                end

                -- Add interactive camera controls (zoom/rotation)
                if not model.cameraDistance then
                    model.cameraDistance = 1.0
                end

                -- Mouse wheel zoom
                model:EnableMouseWheel(true)
                model:SetScript("OnMouseWheel", function(self, delta)
                    self.cameraDistance = math.max(0.3, math.min(3.0, (self.cameraDistance or 1.0) - delta * 0.1))
                    if self.SetCamDistanceScale then
                        self:SetCamDistanceScale(1.6 * self.cameraDistance)
                    end
                end)

                -- Mouse drag rotation
                model:SetScript("OnUpdate", function(self, elapsed)
                    if self.isRotating then
                        local cursorX = GetCursorPosition()
                        local dx = cursorX - (self.lastCursorX or cursorX)
                        self.lastCursorX = cursorX
                        self.rotation = (self.rotation or 0) + dx * 0.01
                        if self.SetRotation then
                            self:SetRotation(self.rotation)
                        end
                    end
                end)

                model:SetScript("OnMouseDown", function(self, button)
                    if button == "LeftButton" then
                        self.isRotating = true
                        self.lastCursorX = GetCursorPosition()
                    end
                end)

                model:SetScript("OnMouseUp", function(self, button)
                    if button == "LeftButton" then
                        self.isRotating = false
                    end
                end)

                local itemId = item.definition and (item.definition.itemId or item.definition.item_id or item.definition.itemID) or item.id
                itemId = tonumber(itemId) or itemId
                if itemId and model.TryOn then
                    model:TryOn(itemId)
                end
                model:SetCamera(0)
            elseif (collType == "mounts" or collType == "pets") and displayId and displayId > 0 then
                if model.SetCreature then
                    model:SetCreature(displayId)
                elseif model.SetDisplayInfo then
                    model:SetDisplayInfo(displayId)
                end
                model:SetCamera(0)
            elseif displayId and displayId > 0 and model.SetDisplayInfo then
                model:SetDisplayInfo(displayId)
                model:SetCamera(0)
            elseif collType == "mounts" then
                -- If we don't have a display ID, we can't show the mount.
                modelPanel:Hide()
                return
            elseif collType == "pets" then
                -- For pets, if displayId missing, hide model
                modelPanel:Hide()
                return
            end

            model:SetFacing(0)
            model:SetPosition(0, 0, 0)
        end

        -- Heirlooms: show tooltip stats under the preview panel
        if statsPanel then
            if collType == "heirlooms" then
                local itemId = (item.definition and (item.definition.itemId or item.definition.item_id or item.definition.itemID)) or item.id
            itemId = tonumber(itemId) or itemId
            local link = (type(itemId) == "number" and itemId > 0) and ("item:" .. itemId) or nil

                statsPanel:Show()
                if link then
                    self._scanTooltip = self._scanTooltip or CreateFrame("GameTooltip", "DCCollectionScanTooltip", UIParent, "GameTooltipTemplate")
                    local tip = self._scanTooltip
                    tip:SetOwner(UIParent, "ANCHOR_NONE")
                    tip:ClearLines()
                    pcall(function() tip:SetHyperlink(link) end)

                    local lines = {}
                    for i = 2, 20 do
                        local fs = _G["DCCollectionScanTooltipTextLeft" .. i]
                        local txt = fs and fs.GetText and fs:GetText() or nil
                        if txt and txt ~= "" then
                            -- Skip common noise lines.
                            if not string.find(txt, "Binds", 1, true)
                                and not string.find(txt, "Unique", 1, true)
                                and not string.find(txt, "Sell Price", 1, true) then
                                lines[#lines + 1] = txt
                            end
                        end
                        if #lines >= 10 then
                            break
                        end
                    end

                    if #lines > 0 then
                        statsPanel.text:SetText(table.concat(lines, "\n"))
                    else
                        statsPanel.text:SetText("Loading item data...")
                        if DC and type(DC.After) == "function" then
                            DC.After(0.3, function()
                                if self.selectedItem and self.selectedItem.id == item.id then
                                    self:UpdateDetailsPanel(item)
                                end
                            end)
                        end
                    end
                else
                    statsPanel.text:SetText("Loading item data...")
                end
            else
                statsPanel:Hide()
                if statsPanel.text then
                    statsPanel.text:SetText("")
                end
            end
        end
    elseif modelPanel then
        modelPanel:Hide()
        self:HideHeirloomPreview()
        if statsPanel then
            statsPanel:Hide()
            if statsPanel.text then
                statsPanel.text:SetText("")
            end
        end
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
    syncBtn:SetText(L["SYNC"] or "Sync")
    syncBtn:SetScript("OnClick", function()
        DC:DeltaSync()
    end)
    
    -- Wishlist button
    local wishlistBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    wishlistBtn:SetSize(80, 22)
    wishlistBtn:SetPoint("LEFT", syncBtn, "RIGHT", 5, 0)
    wishlistBtn:SetText(L["WISHLIST"] or "Wishlist")
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
    
    -- Sync position with Wardrobe if it's open
    if DC.Wardrobe and DC.Wardrobe.frame and DC.Wardrobe.frame:IsShown() then
        local point, relativeTo, relativePoint, xOfs, yOfs = DC.Wardrobe.frame:GetPoint()
        if point then
            self.MainFrame:ClearAllPoints()
            self.MainFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
        end
        DC.Wardrobe:Hide()
    end
    
    self.MainFrame:Show()

    -- If we open very early on login, the protocol may not be ready yet.
    -- Kick a short retry loop so data appears without requiring re-open.
    if type(self.RequestInitialDataWithRetry) == "function" then
        self:RequestInitialDataWithRetry(8, 1)
    elseif type(self.RequestInitialData) == "function" then
        self:RequestInitialData(false)
    end
    
    -- Load all data on open (not just when clicking tabs)
    self:RequestStats()
    self:RequestCurrencies()
    
    -- Request definitions for all collection types
    local collTypes = {"mounts", "pets", "heirlooms", "transmog", "titles"}
    for _, collType in ipairs(collTypes) do
        if not self.definitions[collType] or not next(self.definitions[collType]) then
            self:RequestDefinitions(collType)
        end
        if not self.collections[collType] or not next(self.collections[collType]) then
            self:RequestCollection(collType)
        end
    end
    
    -- Request shop items
    if not self.shopItems or #self.shopItems == 0 then
        self:RequestShopItems()
    end
    
    -- Select the active tab to ensure correct layout (List vs Grid)
    -- First open should default to the Overview (My Collection) tab.
    self:SelectTab(self.activeTab or "overview")
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

-- Compatibility aliases (some UI entry points call these names)
DC.ShowMainUI = DC.ShowMainUI or DC.ShowMainFrame
DC.ToggleMainUI = DC.ToggleMainUI or DC.ToggleMainFrame

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
    
    -- Toggle Frames based on tab
    local content = self.MainFrame.Content

    -- Adjust content height when the footer is hidden (wardrobe embeds and uses the extra space).
    local footer = self.MainFrame.Footer
    if tabKey == "wardrobe" then
        if footer then footer:Hide() end
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", self.MainFrame.FilterBar, "BOTTOMLEFT", 0, 0)
        content:SetPoint("BOTTOMRIGHT", self.MainFrame, "BOTTOMRIGHT", -10, 10)
    else
        if footer then footer:Show() end
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", self.MainFrame.FilterBar, "BOTTOMLEFT", 0, -5)
        content:SetPoint("BOTTOMRIGHT", self.MainFrame, "BOTTOMRIGHT", -10, FOOTER_HEIGHT + 5)
    end
    
    -- Hide everything first
    content.details:Hide()
    content.scrollFrame:Hide()
    if content.modelPanel then content.modelPanel:Hide() end
    content.mountList:Hide()
    content.mountPreview:Hide()
    if content.wardrobeHost then content.wardrobeHost:Hide() end
    
    if DC.AchievementsUI then DC.AchievementsUI:Hide() end
    if DC.MyCollection then DC.MyCollection:Hide() end
    if DC.PetJournal and DC.PetJournal.frame then DC.PetJournal.frame:Hide() end
    if self.ShopUI then self.ShopUI:Hide() end

    if tabKey == "overview" then
        -- Show My Collection overview
        if DC.MyCollection then
            if not DC.MyCollection.frame then
                DC.MyCollection:Create(content)
            end
            DC.MyCollection:Show()
        end
    elseif tabKey == "mounts" then
        content.mountList:Show()
        content.mountPreview:Show()
    elseif tabKey == "shop" then
        -- Shop uses its own UI; avoid stacking with the generic details + scroll grid.
        content.details:Hide()
        content.scrollFrame:Hide()
        if content.modelPanel then content.modelPanel:Hide() end
        if content.modelStatsPanel then content.modelStatsPanel:Hide() end

        self:ShowShopContent()
    elseif tabKey == "pets" then
        -- Show Pet Journal
        if DC.PetJournal then
            if not DC.PetJournal.frame then
                DC.PetJournal:Create(content)
            end
            -- Use the PetJournal's Show() so it can request data, seed fallbacks,
            -- and auto-select the first pet for preview.
            DC.PetJournal:Show()
        end
    elseif tabKey == "achievements" then
        -- Show Achievements UI
        if DC.AchievementsUI then
            if not DC.AchievementsUI.frame then
                DC.AchievementsUI:Create(content)
            end
            DC.AchievementsUI:Show()
        end
    else
        content.details:Show()
        content.scrollFrame:Show()
    end

    if tabKey == "wardrobe" then
        content.details:Hide()
        content.scrollFrame:Hide()
        if content.modelPanel then content.modelPanel:Hide() end
        if content.modelStatsPanel then content.modelStatsPanel:Hide() end

        if not content.wardrobeHost then
            local host = CreateFrame("Frame", nil, content)
            host:SetAllPoints(content)
            host:Hide()
            content.wardrobeHost = host
        end
        content.wardrobeHost:Show()

        if DC.Wardrobe and type(DC.Wardrobe.ShowEmbedded) == "function" then
            DC.Wardrobe:ShowEmbedded(content.wardrobeHost)
        elseif DC.Wardrobe and type(DC.Wardrobe.Show) == "function" then
            -- Fallback to existing behavior if embedded support is unavailable.
            DC.Wardrobe:Show()
        end
    else
        if DC.Wardrobe and DC.Wardrobe.frame then
            DC.Wardrobe:Hide()
        end
    end

    -- Clear current page
    self.currentPage = 1

    self:ClearDetailsPanel()
    
    -- Show appropriate content
    if tabKey == "overview" then
        -- My Collection handles its own update
        self:UpdateHeader()
    elseif tabKey == "achievements" then
        self:UpdateHeader()
    elseif tabKey == "wardrobe" then
        self:UpdateHeader()
    else
        self:RefreshCurrentTab()
    end
end

function DC:RefreshCurrentTab()
    if not self.MainFrame or not self.MainFrame:IsShown() then
        return
    end
    
    self:UpdateHeader()
    
    if self.activeTab == "mounts" then
        self:PopulateMountList()
    elseif self.activeTab == "pets" then
        if DC.PetJournal then
            DC.PetJournal:RefreshList()
        end
    else
        self:PopulateGrid()
    end
end

function DC:RequestRefreshCurrentTab(delay)
    if not self.MainFrame or not self.MainFrame:IsShown() then
        return
    end

    delay = delay or 0.10

    -- Avoid relying on After() for UI refresh scheduling; use a dedicated OnUpdate timer.
    self._refreshCurrentTabDelayFrame = self._refreshCurrentTabDelayFrame or CreateFrame("Frame")
    local f = self._refreshCurrentTabDelayFrame

    -- If a refresh is already pending, just mark dirty and push the debounce window.
    if self._refreshCurrentTabPending then
        self._refreshCurrentTabDirty = true
        self._refreshCurrentTabDelayRemaining = delay
        return
    end

    self._refreshCurrentTabPending = true
    self._refreshCurrentTabDirty = false
    self._refreshCurrentTabDelayRemaining = delay

    if f._dcRefreshHooked then
        return
    end

    f._dcRefreshHooked = true
    f:SetScript("OnUpdate", function(_, elapsed)
        if not DC.MainFrame or not DC.MainFrame:IsShown() then
            DC._refreshCurrentTabPending = nil
            DC._refreshCurrentTabDirty = nil
            DC._refreshCurrentTabDelayRemaining = nil
            return
        end

        if not DC._refreshCurrentTabPending then
            return
        end

        DC._refreshCurrentTabDelayRemaining = (DC._refreshCurrentTabDelayRemaining or 0) - (elapsed or 0)
        if DC._refreshCurrentTabDelayRemaining > 0 then
            return
        end

        local runAgain = DC._refreshCurrentTabDirty
        DC._refreshCurrentTabPending = nil
        DC._refreshCurrentTabDirty = nil
        DC._refreshCurrentTabDelayRemaining = nil

        DC:RefreshCurrentTab()

        if runAgain then
            DC:RequestRefreshCurrentTab(delay)
        end
    end)
end

-- ============================================================================
-- HEADER UPDATE
-- ============================================================================

function DC:UpdateHeader()
    if not self.MainFrame then return end
    
    local header = self.MainFrame.Header

    -- Currency is displayed inside the Shop tab UI. Hide the header currency to avoid duplicates.
    if header.tokensText then header.tokensText:Hide() end
    if header.emblemsText then header.emblemsText:Hide() end
    
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
-- MOUNT LIST POPULATION (RETAIL STYLE)
-- ============================================================================

function DC:PopulateMountList()
    if not self.MainFrame then return end
    
    local scrollChild = self.MainFrame.Content.mountListChild
    
    -- Clear existing items
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Hide loading text if it exists
    if scrollChild.loadingText then
        scrollChild.loadingText:Hide()
    end
    
    local items = self:GetFilteredItems()
    
    -- Check if we're still loading data
    if #items == 0 then
        local defs = self.definitions["mounts"] or {}
        local defCount = 0
        for _ in pairs(defs) do defCount = defCount + 1 end
        
        -- If definitions are empty, show loading message
        if defCount == 0 then
            if not scrollChild.loadingText then
                scrollChild.loadingText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                scrollChild.loadingText:SetPoint("CENTER", scrollChild, "CENTER", 0, 50)
            end
            
            scrollChild.loadingText:SetText("Loading mounts data...")
            scrollChild.loadingText:Show()
            
            -- Request definitions again if needed
            if not self.definitions["mounts"] or not next(self.definitions["mounts"]) then
                self:RequestDefinitions("mounts")
            end
            
            self.MainFrame.Footer.pageInfo:SetText("Loading...")
            return
        end
    end
    
    -- Pagination - use configurable items per page for better browsing
    local itemsPerPage = MOUNT_ITEMS_PER_PAGE
    local totalPages = math.max(1, math.ceil(#items / itemsPerPage))
    self.currentPage = math.min(self.currentPage or 1, totalPages)
    
    if self.MainFrame and self.MainFrame.Footer and self.MainFrame.Footer.pageInfo then
        self.MainFrame.Footer.pageInfo:SetText(string.format("Page %d of %d", self.currentPage, totalPages))
    end
    
    local startIdx = (self.currentPage - 1) * itemsPerPage + 1
    local endIdx = math.min(startIdx + itemsPerPage - 1, #items)
    
    local btnHeight = 46
    local btnWidth = scrollChild:GetWidth() - 5
    
    local btnIndex = 0
    for i = startIdx, endIdx do
        local item = items[i]
        local btn = CreateFrame("Button", nil, scrollChild)
        btn:SetSize(btnWidth, btnHeight)
        btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -btnIndex * (btnHeight + 2))
        
        -- Background
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        if item.collected then
            btn.bg:SetTexture(0.15, 0.25, 0.15, 0.8)
        else
            btn.bg:SetTexture(0.1, 0.1, 0.1, 0.8)
        end
        
        -- Icon
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetSize(40, 40)
        btn.icon:SetPoint("LEFT", btn, "LEFT", 5, 0)
        btn.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        if not item.collected then
            btn.icon:SetDesaturated(true)
            btn.icon:SetAlpha(0.5)
        end
        
        -- Name
        btn.name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.name:SetPoint("TOPLEFT", btn.icon, "TOPRIGHT", 10, -5)
        btn.name:SetText(item.name or "Unknown")
        local r, g, b = GetRarityColor(self, item.rarity or 1)
        btn.name:SetTextColor(r, g, b)
        
        -- Source
        btn.source = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.source:SetPoint("TOPLEFT", btn.name, "BOTTOMLEFT", 0, -2)
        btn.source:SetText(item.sourceText or self:FormatSource(item.source))
        btn.source:SetTextColor(0.6, 0.6, 0.6)
        
        -- Favorite
        if item.is_favorite then
            btn.fav = btn:CreateTexture(nil, "OVERLAY")
            btn.fav:SetSize(16, 16)
            btn.fav:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -5, -5)
            btn.fav:SetTexture("Interface\\Icons\\Achievement_GuildPerk_HappyHour")
        end
        
        -- Highlight
        btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        btn.highlight:SetAllPoints()
        btn.highlight:SetTexture(0.3, 0.3, 0.5, 0.3)
        
        -- Selected
        if self.selectedItem and self.selectedItem.id == item.id then
            btn.selected = btn:CreateTexture(nil, "BORDER")
            btn.selected:SetAllPoints()
            btn.selected:SetTexture(0.4, 0.4, 0.8, 0.5)
        end
        
        -- Click
        btn:SetScript("OnClick", function(selfBtn, button)
            if button == "LeftButton" then
                DC.selectedItem = item
                DC:UpdateMountPreview(item)
                DC:PopulateMountList() -- Refresh to show selection
            elseif button == "RightButton" then
                DC:OnItemRightClick(item)
                DC:UpdateMountPreview(item)
                DC:PopulateMountList()
            end
        end)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
        btnIndex = btnIndex + 1
    end
    
    scrollChild:SetHeight(btnIndex * (btnHeight + 2))
    
    -- Update page info
    self.MainFrame.Footer.pageInfo:SetText(string.format("Page %d of %d", self.currentPage, totalPages))
    SetWidgetEnabled(self.MainFrame.Footer.prevBtn, self.currentPage > 1)
    SetWidgetEnabled(self.MainFrame.Footer.nextBtn, self.currentPage < totalPages)
    
    -- Update preview if nothing selected
    if not self.selectedItem and items[1] then
        self.selectedItem = items[1]
        DC:UpdateMountPreview(items[1])
    elseif self.selectedItem then
        DC:UpdateMountPreview(self.selectedItem)
    end
end

-- ============================================================================
-- GRID POPULATION
-- ============================================================================

function DC:PopulateGrid()
    if not self.MainFrame then return end
    
    local scrollChild = self.MainFrame.Content.scrollChild
    
    -- Clear existing items and loading text
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Hide loading text if it exists
    if scrollChild.loadingText then
        scrollChild.loadingText:Hide()
    end
    
    -- Get filtered items
    local items = self:GetFilteredItems()
    
    -- Check if we're still loading data
    local collType = self.activeTab
    if collType ~= "shop" and #items == 0 then
        local defs = self.definitions[collType] or {}
        local defCount = 0
        for _ in pairs(defs) do defCount = defCount + 1 end
        
        -- If definitions are empty, show loading message
        if defCount == 0 then
            if not scrollChild.loadingText then
                scrollChild.loadingText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                scrollChild.loadingText:SetPoint("CENTER", scrollChild, "CENTER", 0, 50)
            end
            
            if self._transmogDefLoading and collType == "transmog" then
                scrollChild.loadingText:SetText("Loading transmog definitions...")
            else
                scrollChild.loadingText:SetText("Loading " .. collType .. " data...")
            end
            scrollChild.loadingText:Show()
            
            -- Request definitions again if needed
            if not self.definitions[collType] or not next(self.definitions[collType]) then
                self:RequestDefinitions(collType)
            end
            
            self.MainFrame.Footer.pageInfo:SetText("Loading...")
            return
        end
    end
    
    -- Paginate - use configurable items per page for better browsing
    local itemsPerPage = GRID_ITEMS_PER_PAGE
    local totalPages = math.max(1, math.ceil(#items / itemsPerPage))
    self.currentPage = math.min(self.currentPage or 1, totalPages)
    
    local startIdx = (self.currentPage - 1) * itemsPerPage + 1
    local endIdx = math.min(startIdx + itemsPerPage - 1, #items)
    
    -- Create item cards with responsive columns
    local cols = 8  -- Increased from 6 for more items
    local cardSize = 75  -- Slightly smaller to fit more
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
        card.bg:SetTexture(0.2, 0.4, 0.2, 0.8)
    else
        card.bg:SetTexture(0.3, 0.3, 0.3, 0.5)
    end
    
    -- Rarity border
    local rarity = item.rarity or 1
    local r, g, b = GetRarityColor(self, rarity)
    card.border = card:CreateTexture(nil, "BORDER")
    card.border:SetPoint("TOPLEFT", -2, 2)
    card.border:SetPoint("BOTTOMRIGHT", 2, -2)
    card.border:SetTexture(r, g, b, 0.8)
    
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
    card.highlight:SetTexture(1, 1, 1, 0.2)
    
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
        -- For heirlooms we preview on click (not hover) to match the requested UX.
        if not (item and item.type == "heirlooms") then
            DC:UpdateDetailsPanel(item)
        end
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

    -- Cache filtered/sorted results to avoid re-scanning & sorting on every UI refresh.
    -- Keyed by filter inputs + current sort + cache revisions.
    local defsRev = (type(self.GetDefinitionsRevision) == "function") and (self:GetDefinitionsRevision(collType) or 0) or 0
    local collRev = (type(self.GetCollectionsRevision) == "function") and (self:GetCollectionsRevision(collType) or 0) or 0

    local searchText = string.lower(self.MainFrame.FilterBar.searchBox:GetText() or "")
    local showCollected = self.MainFrame.FilterBar.collectedCheck:GetChecked()
    local showNotCollected = self.MainFrame.FilterBar.notCollectedCheck:GetChecked()
    local sortKey = self.currentSort or "name"
    local slotName = (collType == "transmog") and (DC.transmogSelectedSlotName or "") or ""

    local cacheKey = table.concat({
        tostring(defsRev),
        tostring(collRev),
        tostring(sortKey),
        tostring(showCollected and 1 or 0),
        tostring(showNotCollected and 1 or 0),
        tostring(slotName),
        searchText,
    }, "|")

    self._filteredItemsCache = self._filteredItemsCache or {}
    local cacheEntry = self._filteredItemsCache[collType]
    if cacheEntry and cacheEntry.key == cacheKey and type(cacheEntry.items) == "table" then
        return cacheEntry.items
    end
    
    local definitions = self.definitions[collType] or {}
    local collection = self.collections[collType] or {}
    
    -- Deduplication for appearance-based collections (transmog)
    local seenAppearances = {}
    local shouldDedupe = (collType == "transmog")
    
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
                -- Deduplication check for appearance-based collections
                local shouldAdd = true
                if shouldDedupe then
                    local displayId = def.displayId or def.display_id or def.itemDisplayId
                    -- Use displayId as key if available, otherwise fall back to name to group variants
                    local dedupeKey = displayId or def.name
                    if dedupeKey and seenAppearances[dedupeKey] then
                        -- Already have this appearance, but update if this one is collected and previous wasn't
                        local existing = seenAppearances[dedupeKey]
                        if isCollected and not existing.collected then
                            -- Replace with collected version
                            for i, item in ipairs(items) do
                                if item.dedupeKey == dedupeKey then
                                    items[i] = {
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
                                        dedupeKey = dedupeKey,
                                    }
                                    seenAppearances[dedupeKey] = { collected = isCollected }
                                    break
                                end
                            end
                        end
                        shouldAdd = false
                    else
                        seenAppearances[dedupeKey] = { collected = isCollected }
                    end
                end
                
                if shouldAdd then
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
                        dedupeKey = shouldDedupe and (def.displayId or def.display_id or def.itemDisplayId or def.name) or nil,
                    })
                end
            end
        end

        end
    end
    
    -- Sort
    self:SortItems(items)

    self._filteredItemsCache[collType] = { key = cacheKey, items = items }
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
    if self.activeTab == "mounts" then
        self:PopulateMountList()
    else
        self:PopulateGrid()
    end
end

function DC:PrevPage()
    self.currentPage = math.max(1, (self.currentPage or 1) - 1)
    if self.activeTab == "mounts" then
        self:PopulateMountList()
    else
        self:PopulateGrid()
    end
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

    -- Heirlooms: click-to-preview even if not collected.
    if item.type == "heirlooms" then
        self:UpdateDetailsPanel(item)
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

    -- Heirlooms: allow adding the collected heirloom to bags via context menu.
    if item.type == "heirlooms" and item.collected then
        table.insert(menu, {
            text = (L and (L["ADD_TO_BAGS"] or L["ADD_TO_BAG"])) or "Add to bags",
            notCheckable = true,
            func = function() DC:RequestSummonHeirloom(item.id) end,
        })
        table.insert(menu, { text = " ", isTitle = true, notCheckable = true })
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
            GameTooltip:AddLine("Click to preview", 0.5, 0.5, 0.5)
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
-- HEIRLOOM GRID HOVER PREVIEW (Wardrobe-style)
-- ============================================================================

function DC:ShowHeirloomPreview(itemId, options)
    if not itemId then return end

    options = options or {}
    local parent = self.MainFrame and self.MainFrame.Content
    if not parent then
        return
    end

    -- Create the preview frame if it doesn't exist.
    -- This is intentionally styled like the Wardrobe grid preview.
    if not parent.heirloomPreviewFrame then
        local frame = CreateFrame("Frame", "DCHeirloomPreview", parent)
        frame:SetSize(200, 200)
        -- Keep the preview away from the scroll bar so it doesn't look like the bar controls the model.
        frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -40, -90)
        frame:SetFrameStrata("DIALOG")
        frame:SetFrameLevel((parent:GetFrameLevel() or 0) + 20)
        frame:EnableMouse(true)
        frame:EnableMouseWheel(true)
        frame:Hide()

        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        frame:SetBackdropColor(0, 0, 0, 0.95)

        frame.innerBg = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        frame.innerBg:SetPoint("TOPLEFT", 12, -12)
        frame.innerBg:SetPoint("BOTTOMRIGHT", -12, 12)
        frame.innerBg:SetTexture(0.05, 0.05, 0.05, 0.85)

        local model = CreateFrame("DressUpModel", nil, frame)
        model:SetPoint("TOPLEFT", 18, -20)
        model:SetPoint("BOTTOMRIGHT", -18, 18)
        model:SetUnit("player")
        model:SetLight(1, 0, 0, 0, -1, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)

        model:EnableMouse(true)
        model:EnableMouseWheel(true)
        model.rotation = 0
        -- For DressUpModel (player/unit), SetCamDistanceScale is the most reliable zoom control.
        -- Default a bit zoomed-out so the item is visible.
        model.cameraDistance = 1.25

        model:SetScript("OnMouseDown", function(selfModel, button)
            if button == "LeftButton" then
                selfModel.isRotating = true
                selfModel.lastCursorX = GetCursorPosition()
            end
        end)

        model:SetScript("OnMouseUp", function(selfModel, button)
            if button == "LeftButton" then
                selfModel.isRotating = false
            end
        end)

        model:SetScript("OnUpdate", function(selfModel)
            if selfModel.isRotating then
                local cursorX = GetCursorPosition()
                local dx = cursorX - (selfModel.lastCursorX or cursorX)
                selfModel.lastCursorX = cursorX
                selfModel.rotation = (selfModel.rotation or 0) + dx * 0.01
                if selfModel.SetRotation then
                    selfModel:SetRotation(selfModel.rotation)
                elseif selfModel.SetFacing then
                    selfModel:SetFacing(selfModel.rotation)
                end
            end
        end)

        model:SetScript("OnMouseWheel", function(selfModel, delta)
            selfModel.cameraDistance = math.max(0.6, math.min(2.0, (selfModel.cameraDistance or 1.25) - delta * 0.08))
            if selfModel.SetCamDistanceScale then
                selfModel:SetCamDistanceScale(2.8 * selfModel.cameraDistance)
            end
        end)

        -- Some UI layers (the list scrollframe) can eat wheel events; forward wheel events from the frame to the model.
        frame:SetScript("OnMouseWheel", function(_, delta)
            local handler = model:GetScript("OnMouseWheel")
            if handler then
                handler(model, delta)
            end
        end)

        frame.model = model
        parent.heirloomPreviewFrame = frame
    end

    local frame = parent.heirloomPreviewFrame
    frame:Show()

    -- Render
    local model = frame.model
    model:ClearModel()
    model:SetUnit("player")
    if (options.undress ~= false) and model.Undress then
        model:Undress()
    end

    model.rotation = 0
    model.cameraDistance = model.cameraDistance or 1.25
    if model.SetCamDistanceScale then
        model:SetCamDistanceScale(2.8 * model.cameraDistance)
    end
    if model.SetCamera then
        model:SetCamera(0)
    end

    if options.canTryOn and model.TryOn then
        model:TryOn(itemId)
    end

    if model.SetCamera then
        model:SetCamera(0)
    end
    if model.SetFacing then
        model:SetFacing(0)
    end
end

function DC:HideHeirloomPreview()
    if self.MainFrame and self.MainFrame.Content and self.MainFrame.Content.heirloomPreviewFrame then
        self.MainFrame.Content.heirloomPreviewFrame:Hide()
    end
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
