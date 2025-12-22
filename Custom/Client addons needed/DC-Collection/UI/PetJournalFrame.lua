--[[
    DC-Collection UI/PetJournalFrame.lua
    =====================================

    Retail-style Companion Pet Journal with 3D model preview.
    Similar to Blizzard's Pet Collection tab.

    Features:
    - Left side: Scrollable pet list with icons
    - Right side: 3D model preview with rotation
    - Bottom: Summon button, dismiss button, random pet button

    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC and DC.L or {}

local PetJournal = {}
DC.PetJournal = PetJournal

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local FRAME_WIDTH = 750
local FRAME_HEIGHT = 500
local LIST_WIDTH = 280
local BUTTON_HEIGHT = 48
local ITEMS_PER_PAGE = 12

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function GetRarityColor(rarity)
    local colors = {
        [0] = { r = 0.62, g = 0.62, b = 0.62 },
        [1] = { r = 1.00, g = 1.00, b = 1.00 },
        [2] = { r = 0.12, g = 1.00, b = 0.00 },
        [3] = { r = 0.00, g = 0.44, b = 0.87 },
        [4] = { r = 0.64, g = 0.21, b = 0.93 },
        [5] = { r = 1.00, g = 0.50, b = 0.00 },
    }
    local c = colors[rarity or 1] or colors[1]
    return c.r, c.g, c.b
end

local function GetPetIcon(spellId, def)
    -- Try definition icon first
    if def and def.icon and def.icon ~= "" then
        return def.icon
    end

    -- Try spell texture
    if spellId and GetSpellTexture then
        local tex = GetSpellTexture(spellId)
        if tex and tex ~= "" then
            return tex
        end
    end

    -- Try item icon if pet has associated item
    if def and def.itemId and GetItemIcon then
        local tex = GetItemIcon(def.itemId)
        if tex and tex ~= "" then
            return tex
        end
    end

    return "Interface\\Icons\\INV_Box_PetCarrier_01"
end

-- ============================================================================
-- FRAME CREATION
-- ============================================================================

function PetJournal:Create()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "DCPetJournalFrame", UIParent, "UIPanelDialogTemplate")
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
    frame.title:SetText(L["PET_JOURNAL"] or "Companion Pets")

    -- Close button
    local closeBtn = _G[frame:GetName() .. "Close"]
    if closeBtn then
        closeBtn:SetScript("OnClick", function() PetJournal:Hide() end)
    end

    -- Create sections
    self:CreateFilterBar(frame)
    self:CreatePetList(frame)
    self:CreateModelPreview(frame)
    self:CreateActionBar(frame)

    tinsert(UISpecialFrames, frame:GetName())

    self.frame = frame
    self.currentPage = 1
    self.selectedPet = nil
    self.filteredPets = {}

    return frame
end

-- ============================================================================
-- FILTER BAR
-- ============================================================================

function PetJournal:CreateFilterBar(parent)
    local filterBar = CreateFrame("Frame", nil, parent)
    filterBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -35)
    filterBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -35)
    filterBar:SetHeight(30)

    local searchBox = CreateFrame("EditBox", "DCPetJournalSearch", filterBar, "InputBoxTemplate")
    searchBox:SetSize(150, 20)
    searchBox:SetPoint("LEFT", filterBar, "LEFT", 5, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)
    searchBox:SetScript("OnTextChanged", function(self)
        PetJournal:OnSearchChanged(self:GetText())
    end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
    filterBar.searchBox = searchBox

    local collectedCheck = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
    collectedCheck:SetSize(24, 24)
    collectedCheck:SetPoint("LEFT", searchBox, "RIGHT", 15, 0)
    collectedCheck:SetChecked(true)
    collectedCheck:SetScript("OnClick", function() PetJournal:RefreshList() end)
    filterBar.collectedCheck = collectedCheck

    local collectedLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collectedLabel:SetPoint("LEFT", collectedCheck, "RIGHT", 2, 0)
    collectedLabel:SetText(L["FILTER_COLLECTED"] or "Collected")

    local notCollectedCheck = CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate")
    notCollectedCheck:SetSize(24, 24)
    notCollectedCheck:SetPoint("LEFT", collectedLabel, "RIGHT", 10, 0)
    notCollectedCheck:SetChecked(true)
    notCollectedCheck:SetScript("OnClick", function() PetJournal:RefreshList() end)
    filterBar.notCollectedCheck = notCollectedCheck

    local notCollectedLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    notCollectedLabel:SetPoint("LEFT", notCollectedCheck, "RIGHT", 2, 0)
    notCollectedLabel:SetText(L["FILTER_NOT_COLLECTED"] or "Not Collected")

    filterBar.statsText = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterBar.statsText:SetPoint("RIGHT", filterBar, "RIGHT", -10, 0)
    filterBar.statsText:SetText("0/0")

    parent.filterBar = filterBar
end

-- ============================================================================
-- PET LIST (Left Side)
-- ============================================================================

function PetJournal:CreatePetList(parent)
    local listFrame = CreateFrame("Frame", nil, parent)
    listFrame:SetPoint("TOPLEFT", parent.filterBar, "BOTTOMLEFT", 0, -5)
    listFrame:SetSize(LIST_WIDTH, FRAME_HEIGHT - 120)

    local bg = listFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.4)

    local scrollFrame = CreateFrame("ScrollFrame", "DCPetJournalScrollFrame", listFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -25, 35)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)

    listFrame.scrollFrame = scrollFrame
    listFrame.scrollChild = scrollChild

    local pageFrame = CreateFrame("Frame", nil, listFrame)
    pageFrame:SetPoint("BOTTOMLEFT", listFrame, "BOTTOMLEFT", 0, 5)
    pageFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -25, 5)
    pageFrame:SetHeight(25)

    local prevBtn = CreateFrame("Button", nil, pageFrame, "UIPanelButtonTemplate")
    prevBtn:SetSize(30, 20)
    prevBtn:SetPoint("LEFT", pageFrame, "LEFT", 5, 0)
    prevBtn:SetText("<")
    prevBtn:SetScript("OnClick", function() PetJournal:PrevPage() end)
    pageFrame.prevBtn = prevBtn

    pageFrame.pageText = pageFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pageFrame.pageText:SetPoint("CENTER", pageFrame, "CENTER", 0, 0)
    pageFrame.pageText:SetText("1/1")

    local nextBtn = CreateFrame("Button", nil, pageFrame, "UIPanelButtonTemplate")
    nextBtn:SetSize(30, 20)
    nextBtn:SetPoint("RIGHT", pageFrame, "RIGHT", -5, 0)
    nextBtn:SetText(">")
    nextBtn:SetScript("OnClick", function() PetJournal:NextPage() end)
    pageFrame.nextBtn = nextBtn

    listFrame.pageFrame = pageFrame
    parent.listFrame = listFrame
end

-- ============================================================================
-- 3D MODEL PREVIEW (Right Side)
-- ============================================================================

function PetJournal:CreateModelPreview(parent)
    local modelFrame = CreateFrame("Frame", nil, parent)
    modelFrame:SetPoint("TOPLEFT", parent.listFrame, "TOPRIGHT", 10, 0)
    modelFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 50)

    local bg = modelFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.1, 0.8)

    -- 3D Model
    local model = CreateFrame("PlayerModel", "DCPetJournalModel", modelFrame)
    model:SetPoint("TOPLEFT", modelFrame, "TOPLEFT", 10, -60)
    model:SetPoint("BOTTOMRIGHT", modelFrame, "BOTTOMRIGHT", -10, 10)

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

    -- Pet info header
    local infoFrame = CreateFrame("Frame", nil, modelFrame)
    infoFrame:SetPoint("TOPLEFT", modelFrame, "TOPLEFT", 10, -5)
    infoFrame:SetPoint("TOPRIGHT", modelFrame, "TOPRIGHT", -10, -5)
    infoFrame:SetHeight(50)

    infoFrame.icon = infoFrame:CreateTexture(nil, "ARTWORK")
    infoFrame.icon:SetSize(40, 40)
    infoFrame.icon:SetPoint("LEFT", infoFrame, "LEFT", 5, 0)
    infoFrame.icon:SetTexture("Interface\\Icons\\INV_Box_PetCarrier_01")

    infoFrame.name = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    infoFrame.name:SetPoint("TOPLEFT", infoFrame.icon, "TOPRIGHT", 10, -5)
    infoFrame.name:SetText(L["SELECT_PET"] or "Select a pet")

    infoFrame.source = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoFrame.source:SetPoint("TOPLEFT", infoFrame.name, "BOTTOMLEFT", 0, -3)
    infoFrame.source:SetTextColor(0.7, 0.7, 0.7)

    -- Favorite button
    local favBtn = CreateFrame("Button", nil, infoFrame)
    favBtn:SetSize(24, 24)
    favBtn:SetPoint("RIGHT", infoFrame, "RIGHT", -10, 0)
    favBtn:SetNormalTexture("Interface\\Icons\\Achievement_GuildPerk_HappyHour")
    favBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    favBtn:SetScript("OnClick", function()
        if PetJournal.selectedPet then
            DC:RequestToggleFavorite("pets", PetJournal.selectedPet.id)
            PetJournal:RefreshList()
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

function PetJournal:CreateActionBar(parent)
    local actionBar = CreateFrame("Frame", nil, parent)
    actionBar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 10)
    actionBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)
    actionBar:SetHeight(35)

    local summonBtn = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
    summonBtn:SetSize(120, 28)
    summonBtn:SetPoint("LEFT", actionBar, "LEFT", 5, 0)
    summonBtn:SetText(L["SUMMON"] or "Summon")
    summonBtn:SetScript("OnClick", function()
        if PetJournal.selectedPet and PetJournal.selectedPet.collected then
            DC.PetModule:SummonPet(PetJournal.selectedPet.id)
        end
    end)
    actionBar.summonBtn = summonBtn

    local dismissBtn = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
    dismissBtn:SetSize(100, 28)
    dismissBtn:SetPoint("LEFT", summonBtn, "RIGHT", 10, 0)
    dismissBtn:SetText(L["DISMISS"] or "Dismiss")
    dismissBtn:SetScript("OnClick", function()
        DC.PetModule:DismissPet()
    end)
    actionBar.dismissBtn = dismissBtn

    local randomBtn = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
    randomBtn:SetSize(140, 28)
    randomBtn:SetPoint("LEFT", dismissBtn, "RIGHT", 10, 0)
    randomBtn:SetText(L["RANDOM_PET"] or "Summon Random")
    randomBtn:SetScript("OnClick", function()
        DC.PetModule:SummonRandomPet()
    end)
    actionBar.randomBtn = randomBtn

    local randomFavBtn = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
    randomFavBtn:SetSize(160, 28)
    randomFavBtn:SetPoint("LEFT", randomBtn, "RIGHT", 10, 0)
    randomFavBtn:SetText(L["RANDOM_FAVORITE"] or "Random Favorite")
    randomFavBtn:SetScript("OnClick", function()
        DC.PetModule:SummonRandomFavoritePet()
    end)
    actionBar.randomFavBtn = randomFavBtn

    parent.actionBar = actionBar
end

-- ============================================================================
-- PET LIST POPULATION
-- ============================================================================

function PetJournal:CreatePetButton(parent, index)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(parent:GetWidth() - 10, BUTTON_HEIGHT)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -(index - 1) * (BUTTON_HEIGHT + 2))

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(40, 40)
    btn.icon:SetPoint("LEFT", btn, "LEFT", 5, 0)

    btn.favStar = btn:CreateTexture(nil, "OVERLAY")
    btn.favStar:SetSize(16, 16)
    btn.favStar:SetPoint("TOPLEFT", btn.icon, "TOPLEFT", -4, 4)
    btn.favStar:SetTexture("Interface\\Icons\\Achievement_GuildPerk_HappyHour")
    btn.favStar:Hide()

    btn.name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.name:SetPoint("TOPLEFT", btn.icon, "TOPRIGHT", 8, -5)
    btn.name:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -5, -5)
    btn.name:SetJustifyH("LEFT")

    btn.source = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.source:SetPoint("TOPLEFT", btn.name, "BOTTOMLEFT", 0, -2)
    btn.source:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -5, 0)
    btn.source:SetJustifyH("LEFT")
    btn.source:SetTextColor(0.6, 0.6, 0.6)

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetAllPoints()
    btn.highlight:SetColorTexture(0.3, 0.3, 0.5, 0.3)

    btn.selected = btn:CreateTexture(nil, "BORDER")
    btn.selected:SetPoint("TOPLEFT", -1, 1)
    btn.selected:SetPoint("BOTTOMRIGHT", 1, -1)
    btn.selected:SetColorTexture(0.4, 0.4, 0.8, 0.5)
    btn.selected:Hide()

    btn:SetScript("OnClick", function()
        PetJournal:SelectPet(btn.petData)
    end)

    btn:SetScript("OnDoubleClick", function()
        if btn.petData and btn.petData.collected then
            DC.PetModule:SummonPet(btn.petData.id)
        end
    end)

    return btn
end

function PetJournal:RefreshList()
    if not self.frame or not self.frame:IsShown() then
        return
    end

    local searchText = self.frame.filterBar.searchBox:GetText() or ""
    local showCollected = self.frame.filterBar.collectedCheck:GetChecked()
    local showNotCollected = self.frame.filterBar.notCollectedCheck:GetChecked()

    local pets = DC.PetModule:GetFilteredPets({
        search = searchText,
    })

    if not showCollected or not showNotCollected then
        local filtered = {}
        for _, p in ipairs(pets) do
            if (showCollected and p.collected) or (showNotCollected and not p.collected) then
                table.insert(filtered, p)
            end
        end
        pets = filtered
    end

    table.sort(pets, function(a, b)
        if a.is_favorite and not b.is_favorite then return true end
        if b.is_favorite and not a.is_favorite then return false end
        if a.collected and not b.collected then return true end
        if b.collected and not a.collected then return false end
        return (a.name or "") < (b.name or "")
    end)

    self.filteredPets = pets

    local stats = DC.PetModule:GetStats()
    self.frame.filterBar.statsText:SetText(string.format("%d / %d", stats.owned, stats.total))

    local totalPages = math.max(1, math.ceil(#pets / ITEMS_PER_PAGE))
    self.currentPage = math.min(self.currentPage or 1, totalPages)

    local startIdx = (self.currentPage - 1) * ITEMS_PER_PAGE + 1
    local endIdx = math.min(startIdx + ITEMS_PER_PAGE - 1, #pets)

    local scrollChild = self.frame.listFrame.scrollChild
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local btnIndex = 1
    for i = startIdx, endIdx do
        local pet = pets[i]
        local btn = self:CreatePetButton(scrollChild, btnIndex)

        btn.petData = pet
        btn.icon:SetTexture(GetPetIcon(pet.id, pet.definition))
        btn.name:SetText(pet.name or "Unknown")

        local r, g, b = GetRarityColor(pet.rarity)
        btn.name:SetTextColor(r, g, b)

        local sourceText = DC:FormatSource(pet.source)
        btn.source:SetText(sourceText or "")

        if pet.is_favorite then
            btn.favStar:Show()
        else
            btn.favStar:Hide()
        end

        if not pet.collected then
            btn.icon:SetDesaturated(true)
            btn.icon:SetAlpha(0.5)
            btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
        else
            btn.icon:SetDesaturated(false)
            btn.icon:SetAlpha(1)
            btn.bg:SetColorTexture(0.15, 0.25, 0.15, 0.8)
        end

        if self.selectedPet and self.selectedPet.id == pet.id then
            btn.selected:Show()
        else
            btn.selected:Hide()
        end

        btnIndex = btnIndex + 1
    end

    scrollChild:SetHeight(btnIndex * (BUTTON_HEIGHT + 2))
    self.frame.listFrame.pageFrame.pageText:SetText(string.format("%d / %d", self.currentPage, totalPages))
end

-- ============================================================================
-- PET SELECTION & MODEL DISPLAY
-- ============================================================================

function PetJournal:SelectPet(petData)
    if not petData then return end

    self.selectedPet = petData

    local infoFrame = self.frame.modelFrame.infoFrame
    local model = self.frame.modelFrame.model

    infoFrame.icon:SetTexture(GetPetIcon(petData.id, petData.definition))
    infoFrame.name:SetText(petData.name or "Unknown")

    local r, g, b = GetRarityColor(petData.rarity)
    infoFrame.name:SetTextColor(r, g, b)

    local sourceText = DC:FormatSource(petData.source)
    infoFrame.source:SetText(sourceText or "")

    if petData.is_favorite then
        infoFrame.favBtn:GetNormalTexture():SetVertexColor(1, 0.8, 0)
    else
        infoFrame.favBtn:GetNormalTexture():SetVertexColor(0.5, 0.5, 0.5)
    end

    -- Display 3D model
    local displayId = petData.definition and petData.definition.displayId
    if displayId and displayId > 0 then
        model:SetDisplayInfo(displayId)
        model:SetFacing(0)
        model.rotation = 0
        model.zoom = 0
        model:SetPosition(0, 0, 0)
    else
        model:ClearModel()
    end

    local summonBtn = self.frame.actionBar.summonBtn
    if petData.collected then
        summonBtn:Enable()
        summonBtn:SetText(L["SUMMON"] or "Summon")
    else
        summonBtn:Disable()
        summonBtn:SetText(L["NOT_COLLECTED"] or "Not Collected")
    end

    self:RefreshList()
end

-- ============================================================================
-- PAGINATION
-- ============================================================================

function PetJournal:PrevPage()
    if self.currentPage > 1 then
        self.currentPage = self.currentPage - 1
        self:RefreshList()
    end
end

function PetJournal:NextPage()
    local totalPages = math.max(1, math.ceil(#self.filteredPets / ITEMS_PER_PAGE))
    if self.currentPage < totalPages then
        self.currentPage = self.currentPage + 1
        self:RefreshList()
    end
end

function PetJournal:OnSearchChanged(text)
    self.currentPage = 1
    self:RefreshList()
end

-- ============================================================================
-- SHOW/HIDE
-- ============================================================================

function PetJournal:Show()
    if not self.frame then
        self:Create()
    end

    if DC.RequestDefinitions then
        DC:RequestDefinitions("pets")
    end
    if DC.RequestCollection then
        DC:RequestCollection("pets")
    end

    self.frame:Show()
    self:RefreshList()

    if not self.selectedPet and #self.filteredPets > 0 then
        self:SelectPet(self.filteredPets[1])
    end
end

function PetJournal:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function PetJournal:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- ============================================================================
-- SLASH COMMAND
-- ============================================================================

SLASH_DCPETS1 = "/dcpets"
SLASH_DCPETS2 = "/petjournal"
SlashCmdList["DCPETS"] = function()
    PetJournal:Toggle()
end
