--[[
    DC-Collection UI/MountJournalFrame.lua
    ======================================

    Retail-style Mount Journal with 3D model preview.
    Similar to Blizzard's Mount Collection tab.

    Features:
    - Left side: Scrollable mount list with icons
    - Right side: 3D model preview with rotation
    - Bottom: Summon button, random mount button
    - Filter bar: Search, collected/not collected, mount type

    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC and DC.L or {}

local MountJournal = {}
DC.MountJournal = MountJournal

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local FRAME_WIDTH = 980
local FRAME_HEIGHT = 500
local LIST_WIDTH = 280
local MODEL_WIDTH = 450
local BUTTON_HEIGHT = 48
local ITEMS_PER_PAGE = 12

-- Mount type icons
local MOUNT_TYPE_ICONS = {
    [0] = "Interface\\Icons\\Ability_Mount_RidingHorse",   -- Ground
    [1] = "Interface\\Icons\\Ability_Mount_GriffonRider",  -- Flying
    [2] = "Interface\\Icons\\Achievement_Boss_Neptulon",   -- Aquatic
    [3] = "Interface\\Icons\\Ability_Mount_BlackPanther",  -- All
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function GetRarityColor(rarity)
    local colors = {
        [0] = { r = 0.62, g = 0.62, b = 0.62 },  -- Poor
        [1] = { r = 1.00, g = 1.00, b = 1.00 },  -- Common
        [2] = { r = 0.12, g = 1.00, b = 0.00 },  -- Uncommon
        [3] = { r = 0.00, g = 0.44, b = 0.87 },  -- Rare
        [4] = { r = 0.64, g = 0.21, b = 0.93 },  -- Epic
        [5] = { r = 1.00, g = 0.50, b = 0.00 },  -- Legendary
    }
    local c = colors[rarity or 1] or colors[1]
    return c.r, c.g, c.b
end

local function GetMountIcon(spellId, def)
    -- Try spell texture first
    if spellId and GetSpellTexture then
        local tex = GetSpellTexture(spellId)
        if tex and tex ~= "" then
            return tex
        end
    end

    -- Try definition icon
    if def and def.icon and def.icon ~= "" then
        return def.icon
    end

    -- Try item icon if mount has associated item
    if def and def.itemId and GetItemIcon then
        local tex = GetItemIcon(def.itemId)
        if tex and tex ~= "" then
            return tex
        end
    end

    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- ============================================================================
-- FRAME CREATION
-- ============================================================================

function MountJournal:Create()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "DCMountJournalFrame", UIParent, "UIPanelDialogTemplate")
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
    frame.title:SetText(L["MOUNT_JOURNAL"] or "Mount Journal")

    -- Close button
    local closeBtn = _G[frame:GetName() .. "Close"]
    if closeBtn then
        closeBtn:SetScript("OnClick", function() MountJournal:Hide() end)
    end

    -- Create sections
    self:CreateFilterBar(frame)
    self:CreateMountList(frame)
    self:CreateModelPreview(frame)
    self:CreateActionBar(frame)

    -- ESC to close
    tinsert(UISpecialFrames, frame:GetName())

    self.frame = frame
    self.currentPage = 1
    self.selectedMount = nil
    self.filteredMounts = {}

    return frame
end

-- ============================================================================
-- FILTER BAR
-- ============================================================================

function MountJournal:CreateFilterBar(parent)
    local filterBar = CreateFrame("Frame", nil, parent)
    filterBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -35)
    filterBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -35)
    filterBar:SetHeight(30)

    -- Search box
    local searchBox = CreateFrame("EditBox", "DCMountJournalSearch", filterBar, "InputBoxTemplate")
    searchBox:SetSize(150, 20)
    searchBox:SetPoint("LEFT", filterBar, "LEFT", 5, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)
    searchBox:SetScript("OnTextChanged", function(self)
        MountJournal:OnSearchChanged(self:GetText())
    end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)

    filterBar.searchBox = searchBox

    -- Collected checkbox
    local collectedCheck = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
    collectedCheck:SetSize(24, 24)
    collectedCheck:SetPoint("LEFT", searchBox, "RIGHT", 15, 0)
    collectedCheck:SetChecked(true)
    collectedCheck:SetScript("OnClick", function() MountJournal:UpdateMountList() end)
    filterBar.collectedCheck = collectedCheck

    local collectedLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collectedLabel:SetPoint("LEFT", collectedCheck, "RIGHT", 2, 0)
    collectedLabel:SetText(L["FILTER_COLLECTED"] or "Collected")

    -- Not collected checkbox
    local notCollectedCheck = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
    notCollectedCheck:SetSize(24, 24)
    notCollectedCheck:SetPoint("LEFT", collectedLabel, "RIGHT", 10, 0)
    notCollectedCheck:SetChecked(true)
    notCollectedCheck:SetScript("OnClick", function() MountJournal:UpdateMountList() end)
    filterBar.notCollectedCheck = notCollectedCheck

    local notCollectedLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    notCollectedLabel:SetPoint("LEFT", notCollectedCheck, "RIGHT", 2, 0)
    notCollectedLabel:SetText(L["FILTER_NOT_COLLECTED"] or "Not Collected")

    -- Stats
    filterBar.statsText = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterBar.statsText:SetPoint("RIGHT", filterBar, "RIGHT", -10, 0)
    filterBar.statsText:SetText("0/0")

    parent.filterBar = filterBar
end

-- ============================================================================
-- MOUNT LIST (Left Side)
-- ============================================================================

function MountJournal:CreateMountList(parent)
    local listFrame = CreateFrame("Frame", nil, parent)
    listFrame:SetPoint("TOPLEFT", parent.filterBar, "BOTTOMLEFT", 0, -5)
    listFrame:SetSize(LIST_WIDTH, FRAME_HEIGHT - 120)

    -- Background
    local bg = listFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0, 0, 0, 0.4)

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "DCMountJournalScrollFrame", listFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -25, 35)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)

    listFrame.scrollFrame = scrollFrame
    listFrame.scrollChild = scrollChild

    -- Page navigation
    local pageFrame = CreateFrame("Frame", nil, listFrame)
    pageFrame:SetPoint("BOTTOMLEFT", listFrame, "BOTTOMLEFT", 0, 5)
    pageFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -25, 5)
    pageFrame:SetHeight(25)

    local prevBtn = CreateFrame("Button", nil, pageFrame, "UIPanelButtonTemplate")
    prevBtn:SetSize(30, 20)
    prevBtn:SetPoint("LEFT", pageFrame, "LEFT", 5, 0)
    prevBtn:SetText("<")
    prevBtn:SetScript("OnClick", function() MountJournal:PrevPage() end)
    pageFrame.prevBtn = prevBtn

    pageFrame.pageText = pageFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pageFrame.pageText:SetPoint("CENTER", pageFrame, "CENTER", 0, 0)
    pageFrame.pageText:SetText("1/1")

    local nextBtn = CreateFrame("Button", nil, pageFrame, "UIPanelButtonTemplate")
    nextBtn:SetSize(30, 20)
    nextBtn:SetPoint("RIGHT", pageFrame, "RIGHT", -5, 0)
    nextBtn:SetText(">")
    nextBtn:SetScript("OnClick", function() MountJournal:NextPage() end)
    pageFrame.nextBtn = nextBtn

    listFrame.pageFrame = pageFrame
    parent.listFrame = listFrame
end

-- ============================================================================
-- 3D MODEL PREVIEW (Right Side)
-- ============================================================================

function MountJournal:CreateModelPreview(parent)
    local modelFrame = CreateFrame("Frame", nil, parent)
    modelFrame:SetPoint("TOPLEFT", parent.listFrame, "TOPRIGHT", 10, 0)
    modelFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 50)

    -- Background
    local bg = modelFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0.05, 0.05, 0.1, 0.8)

    -- 3D Model
    local model = CreateFrame("DressUpModel", "DCMountJournalModel", modelFrame)
    model:SetPoint("TOPLEFT", modelFrame, "TOPLEFT", 10, -60)
    model:SetPoint("BOTTOMRIGHT", modelFrame, "BOTTOMRIGHT", -10, 10)

    -- Enable mouse rotation
    model:EnableMouse(true)
    model:EnableMouseWheel(true)
    model.rotation = 0
    model.zoom = 0

    model:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.rotating = true
            self.prevX = GetCursorPosition()
        end
    end)

    model:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.rotating = false
        end
    end)

    model:SetScript("OnUpdate", function(self)
        if self.rotating then
            local x = GetCursorPosition()
            local delta = (x - (self.prevX or x)) * 0.01
            self.rotation = (self.rotation or 0) + delta
            self:SetFacing(self.rotation)
            self.prevX = x
        end
    end)

    model:SetScript("OnMouseWheel", function(self, delta)
        local zoom = self.zoom or 0
        zoom = zoom + delta * 0.1
        zoom = math.max(-1, math.min(1, zoom))
        self.zoom = zoom
        self:SetCamera(0)
        self:SetPosition(zoom, 0, 0)
    end)

    modelFrame.model = model

    -- Mount info header
    local infoFrame = CreateFrame("Frame", nil, modelFrame)
    infoFrame:SetPoint("TOPLEFT", modelFrame, "TOPLEFT", 10, -5)
    infoFrame:SetPoint("TOPRIGHT", modelFrame, "TOPRIGHT", -10, -5)
    infoFrame:SetHeight(50)

    infoFrame.icon = infoFrame:CreateTexture(nil, "ARTWORK")
    infoFrame.icon:SetSize(40, 40)
    infoFrame.icon:SetPoint("LEFT", infoFrame, "LEFT", 5, 0)
    infoFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    infoFrame.name = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    infoFrame.name:SetPoint("TOPLEFT", infoFrame.icon, "TOPRIGHT", 10, -5)
    infoFrame.name:SetText(L["SELECT_MOUNT"] or "Select a mount")

    infoFrame.source = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoFrame.source:SetPoint("TOPLEFT", infoFrame.name, "BOTTOMLEFT", 0, -3)
    infoFrame.source:SetTextColor(0.7, 0.7, 0.7)

    infoFrame.typeIcon = infoFrame:CreateTexture(nil, "OVERLAY")
    infoFrame.typeIcon:SetSize(20, 20)
    infoFrame.typeIcon:SetPoint("RIGHT", infoFrame, "RIGHT", -10, 0)

    -- Favorite button
    local favBtn = CreateFrame("Button", nil, infoFrame)
    favBtn:SetSize(24, 24)
    favBtn:SetPoint("RIGHT", infoFrame.typeIcon, "LEFT", -10, 0)
    favBtn:SetNormalTexture("Interface\\Icons\\Achievement_GuildPerk_HappyHour")
    favBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    favBtn:SetScript("OnClick", function()
        if MountJournal.selectedMount then
            DC:RequestToggleFavorite("mounts", MountJournal.selectedMount.id)
            MountJournal:RefreshList()
        end
    end)
    favBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TOGGLE_FAVORITE"] or "Toggle Favorite")
        GameTooltip:Show()
    end)
    favBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    infoFrame.favBtn = favBtn

    modelFrame.infoFrame = infoFrame
    parent.modelFrame = modelFrame
end

-- ============================================================================
-- ACTION BAR (Bottom)
-- ============================================================================

function MountJournal:CreateActionBar(parent)
    local actionBar = CreateFrame("Frame", nil, parent)
    actionBar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 10)
    actionBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)
    actionBar:SetHeight(35)

    -- Summon button
    local summonBtn = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
    summonBtn:SetSize(120, 28)
    summonBtn:SetPoint("LEFT", actionBar, "LEFT", 5, 0)
    summonBtn:SetText(L["SUMMON"] or "Summon")
    summonBtn:SetScript("OnClick", function()
        if MountJournal.selectedMount and MountJournal.selectedMount.collected then
            DC.MountModule:SummonMount(MountJournal.selectedMount.id)
        end
    end)
    actionBar.summonBtn = summonBtn

    -- Random mount button
    local randomBtn = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
    randomBtn:SetSize(140, 28)
    randomBtn:SetPoint("LEFT", summonBtn, "RIGHT", 10, 0)
    randomBtn:SetText(L["RANDOM_MOUNT"] or "Summon Random")
    randomBtn:SetScript("OnClick", function()
        DC.MountModule:SummonRandomMount()
    end)
    actionBar.randomBtn = randomBtn

    -- Random favorite button
    local randomFavBtn = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
    randomFavBtn:SetSize(160, 28)
    randomFavBtn:SetPoint("LEFT", randomBtn, "RIGHT", 10, 0)
    randomFavBtn:SetText(L["RANDOM_FAVORITE"] or "Random Favorite")
    randomFavBtn:SetScript("OnClick", function()
        DC.MountModule:SummonRandomFavoriteMount()
    end)
    actionBar.randomFavBtn = randomFavBtn

    parent.actionBar = actionBar
end

-- ============================================================================
-- MOUNT LIST POPULATION
-- ============================================================================

function MountJournal:CreateMountButton(parent, index)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(parent:GetWidth() - 10, BUTTON_HEIGHT)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -(index - 1) * (BUTTON_HEIGHT + 2))

    -- Background
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetTexture(0.1, 0.1, 0.1, 0.8)

    -- Icon
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(40, 40)
    btn.icon:SetPoint("LEFT", btn, "LEFT", 5, 0)

    -- Favorite star
    btn.favStar = btn:CreateTexture(nil, "OVERLAY")
    btn.favStar:SetSize(16, 16)
    btn.favStar:SetPoint("TOPLEFT", btn.icon, "TOPLEFT", -4, 4)
    btn.favStar:SetTexture("Interface\\Icons\\Achievement_GuildPerk_HappyHour")
    btn.favStar:Hide()

    -- Name
    btn.name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.name:SetPoint("TOPLEFT", btn.icon, "TOPRIGHT", 8, -5)
    btn.name:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -5, -5)
    btn.name:SetJustifyH("LEFT")

    -- Source
    btn.source = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.source:SetPoint("TOPLEFT", btn.name, "BOTTOMLEFT", 0, -2)
    btn.source:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -5, 0)
    btn.source:SetJustifyH("LEFT")
    btn.source:SetTextColor(0.6, 0.6, 0.6)

    -- Highlight
    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetAllPoints()
    btn.highlight:SetTexture(0.3, 0.3, 0.5, 0.3)

    -- Selected indicator
    btn.selected = btn:CreateTexture(nil, "BORDER")
    btn.selected:SetPoint("TOPLEFT", -1, 1)
    btn.selected:SetPoint("BOTTOMRIGHT", 1, -1)
    btn.selected:SetTexture(0.4, 0.4, 0.8, 0.5)
    btn.selected:Hide()

    local function ShowMountContextMenu(mountData)
        if not mountData then
            return
        end

        local id = mountData.id
        local menu = {
            { text = mountData.name or "Mount", isTitle = true, notCheckable = true },
        }

        if mountData.collected then
            if mountData.is_favorite then
                table.insert(menu, {
                    text = (L and L["UNFAVORITE"]) or "Unfavorite",
                    notCheckable = true,
                    func = function()
                        DC:RequestToggleFavorite("mounts", id)
                        MountJournal:UpdateMountList()
                    end,
                })
            else
                table.insert(menu, {
                    text = (L and L["FAVORITE"]) or "Favorite",
                    notCheckable = true,
                    func = function()
                        DC:RequestToggleFavorite("mounts", id)
                        MountJournal:UpdateMountList()
                    end,
                })
            end
        else
            local inWishlist = DC.IsInWishlist and DC:IsInWishlist("mounts", id) or false
            if inWishlist then
                table.insert(menu, {
                    text = (L and (L["REMOVE_FROM_WISHLIST"] or L["REMOVE_WISHLIST"])) or "Remove from wishlist",
                    notCheckable = true,
                    func = function()
                        DC:RequestRemoveWishlist("mounts", id)
                    end,
                })
            else
                table.insert(menu, {
                    text = (L and (L["ADD_TO_WISHLIST"] or L["WISHLIST"])) or "Add to wishlist",
                    notCheckable = true,
                    func = function()
                        DC:RequestAddWishlist("mounts", id)
                    end,
                })
            end
        end

        table.insert(menu, { text = (L and L["CANCEL"]) or "Cancel", notCheckable = true })

        local dropdown = CreateFrame("Frame", "DCMountContextMenu", UIParent, "UIDropDownMenuTemplate")
        EasyMenu(menu, dropdown, "cursor", 0, 0, "MENU")
    end

    -- Click handler
    btn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ShowMountContextMenu(btn.mountData)
            return
        end
        MountJournal:SelectMount(btn.mountData)
    end)

    btn:SetScript("OnDoubleClick", function()
        if btn.mountData and btn.mountData.collected then
            DC.MountModule:SummonMount(btn.mountData.id)
        end
    end)

    return btn
end

function MountJournal:UpdateMountList()
    -- Build filtered list
    local searchText = self.frame.filterBar.searchBox:GetText() or ""
    local showCollected = self.frame.filterBar.collectedCheck:GetChecked()
    local showNotCollected = self.frame.filterBar.notCollectedCheck:GetChecked()

    local mounts = DC.MountModule:GetFilteredMounts({
        search = searchText,
        collected = showCollected and showNotCollected and nil or (showCollected and true or false),
    })

    -- Filter by collected state
    if not showCollected or not showNotCollected then
        local filtered = {}
        for _, m in ipairs(mounts) do
            if (showCollected and m.collected) or (showNotCollected and not m.collected) then
                table.insert(filtered, m)
            end
        end
        mounts = filtered
    end

    -- Sort: collected first, then by name
    table.sort(mounts, function(a, b)
        if a.is_favorite and not b.is_favorite then return true end
        if b.is_favorite and not a.is_favorite then return false end
        if a.collected and not b.collected then return true end
        if b.collected and not a.collected then return false end
        return (a.name or "") < (b.name or "")
    end)

    self.filteredMounts = mounts

    -- Update stats
    local stats = DC.MountModule:GetStats()
    self.frame.filterBar.statsText:SetText(string.format("%d / %d", stats.owned, stats.total))
    
    self.currentPage = 1
    self:RefreshList()
end

function MountJournal:RefreshList()
    if not self.frame or not self.frame:IsShown() then
        return
    end
    
    if not self.filteredMounts then
        self:UpdateMountList()
        return
    end

    local mounts = self.filteredMounts

    -- Paginate
    local totalPages = math.max(1, math.ceil(#mounts / ITEMS_PER_PAGE))
    self.currentPage = math.min(self.currentPage or 1, totalPages)

    local startIdx = (self.currentPage - 1) * ITEMS_PER_PAGE + 1
    local endIdx = math.min(startIdx + ITEMS_PER_PAGE - 1, #mounts)

    -- Clear existing buttons
    local scrollChild = self.frame.listFrame.scrollChild
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    -- Create buttons
    local btnIndex = 1
    for i = startIdx, endIdx do
        local mount = mounts[i]
        local btn = self:CreateMountButton(scrollChild, btnIndex)

        btn.mountData = mount
        btn.icon:SetTexture(GetMountIcon(mount.id, mount.definition))
        btn.name:SetText(mount.name or "Unknown")

        local r, g, b = GetRarityColor(mount.rarity)
        btn.name:SetTextColor(r, g, b)

        local sourceText = DC:FormatSource(mount.source)
        btn.source:SetText(sourceText or "")

        if mount.is_favorite then
            btn.favStar:Show()
        else
            btn.favStar:Hide()
        end

        if not mount.collected then
            btn.icon:SetDesaturated(true)
            btn.icon:SetAlpha(0.5)
            btn.bg:SetTexture(0.1, 0.1, 0.1, 0.5)
        else
            btn.icon:SetDesaturated(false)
            btn.icon:SetAlpha(1)
            btn.bg:SetTexture(0.15, 0.25, 0.15, 0.8)
        end

        if self.selectedMount and self.selectedMount.id == mount.id then
            btn.selected:Show()
        else
            btn.selected:Hide()
        end

        btnIndex = btnIndex + 1
    end

    scrollChild:SetHeight(btnIndex * (BUTTON_HEIGHT + 2))

    -- Update page text
    self.frame.listFrame.pageFrame.pageText:SetText(string.format("%d / %d", self.currentPage, totalPages))

    -- Update button states
    local prevBtn = self.frame.listFrame.pageFrame.prevBtn
    local nextBtn = self.frame.listFrame.pageFrame.nextBtn
    if prevBtn.SetEnabled then prevBtn:SetEnabled(self.currentPage > 1) end
    if nextBtn.SetEnabled then nextBtn:SetEnabled(self.currentPage < totalPages) end
end

-- ============================================================================
-- MOUNT SELECTION & MODEL DISPLAY
-- ============================================================================

function MountJournal:SelectMount(mountData)
    if not mountData then return end

    self.selectedMount = mountData

    local infoFrame = self.frame.modelFrame.infoFrame
    local model = self.frame.modelFrame.model

    -- Update info
    infoFrame.icon:SetTexture(GetMountIcon(mountData.id, mountData.definition))
    infoFrame.name:SetText(mountData.name or "Unknown")

    local r, g, b = GetRarityColor(mountData.rarity)
    infoFrame.name:SetTextColor(r, g, b)

    local sourceText = DC:FormatSource(mountData.source)
    infoFrame.source:SetText(sourceText or "")

    local mountType = mountData.definition and mountData.definition.mountType or 0
    infoFrame.typeIcon:SetTexture(MOUNT_TYPE_ICONS[mountType] or MOUNT_TYPE_ICONS[0])

    -- Update favorite button
    if mountData.is_favorite then
        infoFrame.favBtn:GetNormalTexture():SetVertexColor(1, 0.8, 0)
    else
        infoFrame.favBtn:GetNormalTexture():SetVertexColor(0.5, 0.5, 0.5)
    end

    -- Display 3D model
    local displayId = mountData.definition and mountData.definition.displayId
    if displayId and displayId > 0 then
        model:SetDisplayInfo(displayId)
        model:SetFacing(0)
        model.rotation = 0
        model.zoom = 0
        model:SetPosition(0, 0, 0)
    else
        -- Fallback: try to show mount via spell
        model:SetUnit("player")
        -- Can't directly set mount model without displayId in 3.3.5a
        -- So we'll just show a placeholder or the player
    end

    -- Update summon button
    local summonBtn = self.frame.actionBar.summonBtn
    if mountData.collected then
        summonBtn:Enable()
        summonBtn:SetText(L["SUMMON"] or "Summon")
    else
        summonBtn:Disable()
        summonBtn:SetText(L["NOT_COLLECTED"] or "Not Collected")
    end

    -- Refresh list to update selection highlight
    self:RefreshList()
end

-- ============================================================================
-- PAGINATION
-- ============================================================================

function MountJournal:PrevPage()
    if self.currentPage > 1 then
        self.currentPage = self.currentPage - 1
        self:RefreshList()
    end
end

function MountJournal:NextPage()
    local totalPages = math.max(1, math.ceil(#self.filteredMounts / ITEMS_PER_PAGE))
    if self.currentPage < totalPages then
        self.currentPage = self.currentPage + 1
        self:RefreshList()
    end
end

function MountJournal:OnSearchChanged(text)
    self:UpdateMountList()
end

-- ============================================================================
-- SHOW/HIDE
-- ============================================================================

function MountJournal:Show()
    if not self.frame then
        self:Create()
    end

    -- Request latest data
    if DC.RequestDefinitions then
        DC:RequestDefinitions("mounts")
    end
    if DC.RequestCollection then
        DC:RequestCollection("mounts")
    end

    self.frame:Show()
    self:UpdateMountList()

    -- Auto-select first mount if none selected
    if not self.selectedMount and #self.filteredMounts > 0 then
        self:SelectMount(self.filteredMounts[1])
    end
end

function MountJournal:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function MountJournal:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Register slash command
SLASH_DCMOUNTS1 = "/dcmounts"
SLASH_DCMOUNTS2 = "/mountjournal"
SlashCmdList["DCMOUNTS"] = function()
    MountJournal:Toggle()
end
