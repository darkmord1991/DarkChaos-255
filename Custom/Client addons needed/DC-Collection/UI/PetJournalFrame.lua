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

local FRAME_WIDTH = 980
local FRAME_HEIGHT = 500
local LIST_WIDTH = 280
local BUTTON_HEIGHT = 48
local ITEMS_PER_PAGE = 12

local PET_PREVIEW_VISUAL_FALLBACKS = {
    -- Visual-only fallback for the last unresolved uncollected pet row.
    -- Keep this out of authoritative source metadata until a verified summon
    -- path exists.
    [39148] = {
        creatureId = 24594,
        displayId = 7046,
    },
}

local function GetWishlistButtonText(isWishlisted)
    if isWishlisted then
        return (L and (L["REMOVE_FROM_WISHLIST"] or L["REMOVE_WISHLIST"] or
            L["ACTION_REMOVE_WISHLIST"])) or "Remove from wishlist"
    end

    return (L and (L["ADD_TO_WISHLIST"] or L["ACTION_ADD_WISHLIST"] or
        L["WISHLIST"])) or "Add to wishlist"
end

local function ToPositiveNumber(value)
    local num = tonumber(value)
    if num and num > 0 then
        return num
    end

    return nil
end

local function GetPetPreviewFields(def)
    if type(def) ~= "table" then
        return nil, nil
    end

    local creatureId = ToPositiveNumber(
        def.previewCreatureId or def.preview_creature_id or
        def.creatureId or def.creature_id or def.creatureID or
        def.creatureEntry or def.creature_entry or
        def.petEntry or def.pet_entry or
        def.npcId or def.npc_id or
        def.entryId or def.entry_id or def.entry)

    local displayId = ToPositiveNumber(
        def.previewDisplayId or def.previewDisplayID or
        def.preview_display_id or
        def.creatureDisplayId or def.creatureDisplayID or
        def.creature_display_id or
        def.displayId or def.displayID or def.display_id or
        def.modelId or def.modelID or def.model_id or
        def.modelDisplayId or def.modelDisplayID or
        def.model_display_id)

    return creatureId, displayId
end

local function NormalizePetPreviewName(name)
    if type(name) ~= "string" then
        return nil
    end

    local trimmed = string.gsub(name, "^%s*(.-)%s*$", "%1")
    if trimmed == "" then
        return nil
    end

    return string.lower(trimmed)
end

local function FindDefinitionPreviewFallbackByName(petId, petName)
    local defs = DC and DC.definitions and DC.definitions.pets
    local wantedName = NormalizePetPreviewName(petName)
    if type(defs) ~= "table" or not wantedName then
        return nil
    end

    local targetId = ToPositiveNumber(petId)
    local bestFallback = nil
    local bestScore = -1

    for otherId, otherDef in pairs(defs) do
        local otherName = NormalizePetPreviewName(otherDef and otherDef.name)
        local otherNumericId = ToPositiveNumber(otherId)
        if otherName == wantedName and otherNumericId ~= targetId then
            local creatureId, displayId = GetPetPreviewFields(otherDef)
            local score = 0
            if creatureId then
                score = score + 2
            end
            if displayId then
                score = score + 1
            end

            if score > bestScore then
                bestFallback = {
                    creatureId = creatureId,
                    displayId = displayId,
                }
                bestScore = score
            end
        end
    end

    if bestScore <= 0 then
        return nil
    end

    return bestFallback
end

local function ReportPetPreviewIssue(petData, def, reason, displayId, creatureId)
    if not DC or type(petData) ~= "table" then
        return
    end

    local key = string.format(
        "%s:%s",
        tostring(ToPositiveNumber(petData.id) or "?"),
        tostring(reason or "unknown"))
    DC._petPreviewIssueSeen = DC._petPreviewIssueSeen or {}
    if DC._petPreviewIssueSeen[key] then
        return
    end
    DC._petPreviewIssueSeen[key] = true

    if type(DC.Debug) == "function" then
        DC:Debug(string.format(
            "Pet preview issue (%s): id=%s name=%s displayId=%s creatureId=%s spellId=%s",
            tostring(reason or "unknown"),
            tostring(ToPositiveNumber(petData.id) or "?"),
            tostring((petData.name and petData.name ~= "" and petData.name) or
                (def and def.name) or "?"),
            tostring(ToPositiveNumber(displayId) or "0"),
            tostring(ToPositiveNumber(creatureId) or "0"),
            tostring(ToPositiveNumber(def and (def.spellId or def.spell_id)) or "0")
        ))
    end
end

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
    local sid = nil
    if def then
        sid = def.spellId or def.spell_id
    end
    sid = sid or spellId

    if sid and GetSpellTexture then
        local tex = GetSpellTexture(sid)
        if tex and tex ~= "" then
            return tex
        end
    end

    -- Try item icon if pet has associated item
    if def and def.itemId then
        if type(GetItemIcon) == "function" then
            local tex = GetItemIcon(def.itemId)
            if tex and tex ~= "" then return tex end
        end
        if type(GetItemInfo) == "function" then
            local tex = select(10, GetItemInfo(def.itemId))
            if tex and tex ~= "" then return tex end
        end
    end

    return "Interface\\Icons\\INV_Box_PetCarrier_01"
end

-- ============================================================================
-- FRAME CREATION
-- ============================================================================

function PetJournal:Create(parent)
    if self.frame then
        return self.frame
    end

    -- Create container frame embedded in MainFrame content (not standalone)
    local frame = CreateFrame("Frame", "DCPetJournalFrame", parent or UIParent)
    frame:SetAllPoints(parent)
    frame:Hide()

    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetTexture(0, 0, 0, 0.3)

    -- Create sections (no title/close since we're embedded in MainFrame)
    self:CreatePetList(frame)
    self:CreateModelPreview(frame)
    self:CreateActionBar(frame)

    self.frame = frame
    self.currentPage = 1
    self.selectedPet = nil
    self.filteredPets = nil -- Initialize as nil to force first update

    return frame
end

-- ============================================================================
-- PET LIST (Left Side)
-- ============================================================================

function PetJournal:CreatePetList(parent)
    local listFrame = CreateFrame("Frame", nil, parent)
    listFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
    listFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 5, 50)
    listFrame:SetWidth(LIST_WIDTH)

    local bg = listFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0, 0, 0, 0.4)

    local scrollFrame = CreateFrame("ScrollFrame", "DCPetJournalScrollFrame", listFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -25, 35)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)

    listFrame.scrollFrame = scrollFrame
    listFrame.scrollChild = scrollChild

    local pageFrame = DC:CreateCenteredPagerFrame(listFrame, {
        leftInset = 0,
        rightInset = 25,
        bottomInset = 5,
        height = 25,
        pagerWidth = 110,
        pagerHeight = 20,
        buttonTemplate = "UIPanelButtonTemplate",
        buttonWidth = 30,
        buttonHeight = 20,
        pageText = "1/1",
        onPrev = function() PetJournal:PrevPage() end,
        onNext = function() PetJournal:NextPage() end,
    })

    -- Stats text (moved here from removed filter bar)
    listFrame.statsText = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listFrame.statsText:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -30, 10)
    listFrame.statsText:SetText("0 / 0")

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
    bg:SetTexture(0.05, 0.05, 0.1, 0.8)

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
            if DC and DC.PetModule and type(DC.PetModule.ToggleFavorite) == "function" then
                DC.PetModule:ToggleFavorite(PetJournal.selectedPet.id)
            else
                DC:RequestToggleFavorite("pets", PetJournal.selectedPet.id)
            end
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

    local wishlistBtn = CreateFrame("Button", nil, infoFrame, "UIPanelButtonTemplate")
    wishlistBtn:SetSize(120, 22)
    wishlistBtn:SetPoint("RIGHT", favBtn, "LEFT", -10, 0)
    wishlistBtn:SetText(GetWishlistButtonText(false))
    wishlistBtn:SetScript("OnClick", function()
        local selectedPet = PetJournal.selectedPet
        if not selectedPet or selectedPet.collected then
            return
        end

        local isWishlisted = DC.IsInWishlist and DC:IsInWishlist("pets", selectedPet.id) or false
        if isWishlisted then
            DC:RequestRemoveWishlist("pets", selectedPet.id)
        else
            DC:RequestAddWishlist("pets", selectedPet.id)
        end
    end)
    wishlistBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self:GetText())
        GameTooltip:Show()
    end)
    wishlistBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    wishlistBtn:Hide()
    infoFrame.wishlistBtn = wishlistBtn

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
    summonBtn:SetSize(140, 28)
    summonBtn:SetPoint("LEFT", actionBar, "LEFT", 5, 0)
    summonBtn:SetText(L["SUMMON"] or "Summon")
    summonBtn:SetScript("OnClick", function()
        local selectedPet = PetJournal.selectedPet
        if not selectedPet then
            return
        end

        if selectedPet.collected then
            DC.PetModule:SummonPet(selectedPet.id)
            return
        end

        local isWishlisted = DC.IsInWishlist and DC:IsInWishlist("pets", selectedPet.id) or false
        if isWishlisted then
            DC:RequestRemoveWishlist("pets", selectedPet.id)
        else
            DC:RequestAddWishlist("pets", selectedPet.id)
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
    btn.bg:SetTexture(0.1, 0.1, 0.1, 0.8)

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
    btn.highlight:SetTexture(0.3, 0.3, 0.5, 0.3)

    btn.selected = btn:CreateTexture(nil, "BORDER")
    btn.selected:SetPoint("TOPLEFT", -1, 1)
    btn.selected:SetPoint("BOTTOMRIGHT", 1, -1)
    btn.selected:SetTexture(0.4, 0.4, 0.8, 0.5)
    btn.selected:Hide()

    local function ShowPetContextMenu(petData)
        if not petData then
            return
        end

        local id = petData.id
        local menu = {
            { text = petData.name or "Pet", isTitle = true, notCheckable = true },
        }

        if petData.collected then
            if petData.is_favorite then
                table.insert(menu, {
                    text = (L and L["UNFAVORITE"]) or "Unfavorite",
                    notCheckable = true,
                    func = function()
                        DC:RequestToggleFavorite("pets", id)
                        PetJournal:UpdatePetList()
                    end,
                })
            else
                table.insert(menu, {
                    text = (L and L["FAVORITE"]) or "Favorite",
                    notCheckable = true,
                    func = function()
                        DC:RequestToggleFavorite("pets", id)
                        PetJournal:UpdatePetList()
                    end,
                })
            end
        else
            local inWishlist = DC.IsInWishlist and DC:IsInWishlist("pets", id) or false
            if inWishlist then
                table.insert(menu, {
                    text = (L and (L["REMOVE_FROM_WISHLIST"] or L["REMOVE_WISHLIST"])) or "Remove from wishlist",
                    notCheckable = true,
                    func = function()
                        DC:RequestRemoveWishlist("pets", id)
                    end,
                })
            else
                table.insert(menu, {
                    text = (L and (L["ADD_TO_WISHLIST"] or L["WISHLIST"])) or "Add to wishlist",
                    notCheckable = true,
                    func = function()
                        DC:RequestAddWishlist("pets", id)
                    end,
                })
            end
        end

        table.insert(menu, { text = (L and L["CANCEL"]) or "Cancel", notCheckable = true })

        local dropdown = CreateFrame("Frame", "DCPetContextMenu", UIParent, "UIDropDownMenuTemplate")
        EasyMenu(menu, dropdown, "cursor", 0, 0, "MENU")
    end

    btn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ShowPetContextMenu(btn.petData)
            return
        end
        PetJournal:SelectPet(btn.petData)
    end)

    btn:SetScript("OnDoubleClick", function()
        if btn.petData and btn.petData.collected then
            DC.PetModule:SummonPet(btn.petData.id)
        end
    end)

    return btn
end

function PetJournal:UpdatePetList()
    -- Get filter values from MainFrame's filter bar
    local searchText = ""
    local showCollected = true
    local showNotCollected = true
    
    if DC.MainFrame and DC.MainFrame.FilterBar then
        local fb = DC.MainFrame.FilterBar
        if fb.searchBox then
            searchText = fb.searchBox:GetText() or ""
        end
        if fb.collectedCheck then
            showCollected = fb.collectedCheck:GetChecked() and true or false
        end
        if fb.notCollectedCheck then
            showNotCollected = fb.notCollectedCheck:GetChecked() and true or false
        end
    end

    -- If both are unchecked, treat it as "show all" (avoids empty list)
    if showCollected == false and showNotCollected == false then
        showCollected = true
        showNotCollected = true
    end

    if not DC.PetModule or type(DC.PetModule.GetFilteredPets) ~= "function" then
        self.filteredPets = {}
        self.currentPage = 1
        self:RefreshList()
        return
    end

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
    if self.frame and self.frame.listFrame and self.frame.listFrame.statsText then
        self.frame.listFrame.statsText:SetText(string.format("%d / %d", stats.owned, stats.total))
    end
    
    self.currentPage = 1
    self:RefreshList()
end

function PetJournal:RefreshList()
    if not self.frame or not self.frame:IsShown() then
        return
    end
    
    if not self.filteredPets then
        self:UpdatePetList()
        return
    end
    
    local pets = self.filteredPets

    local scrollChild = self.frame.listFrame.scrollChild
    
    -- Clear existing items
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Hide loading text if it exists
    if scrollChild.loadingText then
        scrollChild.loadingText:Hide()
    end
    
    -- Check if we're still loading data / no results
    if #pets == 0 then
        local defs = DC.definitions["pets"] or {}
        local defCount = 0
        for _ in pairs(defs) do defCount = defCount + 1 end

        if not scrollChild.loadingText then
            scrollChild.loadingText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            scrollChild.loadingText:SetPoint("CENTER", scrollChild, "CENTER", 0, 50)
        end

        -- If definitions are empty, try a client-side fallback first (known companion spells).
        if defCount == 0 then
            local seeded = false
            if DC.PetModule and type(DC.PetModule.SeedFromClientKnownPets) == "function" then
                seeded = DC.PetModule:SeedFromClientKnownPets() and true or false
            end

            if seeded then
                self:UpdatePetList()
                return
            end

            -- Still empty: show an actionable message and keep asking the server.
            scrollChild.loadingText:SetText("No companion data yet.\nLearn a pet or wait for server definitions.")
            scrollChild.loadingText:Show()

            if type(DC.RequestDefinitions) == "function" then
                DC:RequestDefinitions("pets")
            end

            self.frame.listFrame.pageFrame.pageText:SetText("...")
            return
        end

        -- Definitions exist but filtering yielded 0.
        scrollChild.loadingText:SetText("No companions match your filters.")
        scrollChild.loadingText:Show()
        self.frame.listFrame.pageFrame.pageText:SetText("0/0")
        return
    end

    local totalPages = math.max(1, math.ceil(#pets / ITEMS_PER_PAGE))
    self.currentPage = math.min(self.currentPage or 1, totalPages)

    local startIdx = (self.currentPage - 1) * ITEMS_PER_PAGE + 1
    local endIdx = math.min(startIdx + ITEMS_PER_PAGE - 1, #pets)

    local btnIndex = 1
    for i = startIdx, endIdx do
        local pet = pets[i]
        local btn = self:CreatePetButton(scrollChild, btnIndex)

        btn.petData = pet
        
        -- Use definition name if available, otherwise fallback to "Unknown"
        local name = pet.name
        if (not name or name == "") and pet.definition then
            name = pet.definition.name
        end
        btn.name:SetText(name or "Unknown")

        btn.icon:SetTexture(GetPetIcon(pet.id, pet.definition))

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
            btn.bg:SetTexture(0.1, 0.1, 0.1, 0.5)
        else
            btn.icon:SetDesaturated(false)
            btn.icon:SetAlpha(1)
            btn.bg:SetTexture(0.15, 0.25, 0.15, 0.8)
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

    local def = petData.definition or {}
    if DC and DC.PetModule and type(DC.PetModule.GetPetDefinition) == "function" then
        local canonicalDef = DC.PetModule:GetPetDefinition(petData.id)
        if not canonicalDef and type(def) == "table" then
            canonicalDef = DC.PetModule:GetPetDefinition(def.itemId or def.item_id)
        end
        if type(canonicalDef) == "table" then
            def = canonicalDef
            petData.definition = canonicalDef
        end
    end
    infoFrame.icon:SetTexture(GetPetIcon(def.spellId or def.spell_id, def))
    infoFrame.name:SetText((petData.name and petData.name ~= "" and petData.name) or def.name or "Unknown")

    local r, g, b = GetRarityColor(petData.rarity)
    infoFrame.name:SetTextColor(r, g, b)

    local sourceText = DC:FormatSource(petData.source)
    infoFrame.source:SetText(sourceText or "")

    if infoFrame.favBtn then
        local favTex = infoFrame.favBtn:GetNormalTexture()
        if favTex then
            if petData.is_favorite then
                favTex:SetVertexColor(1, 0.8, 0)
            else
                favTex:SetVertexColor(0.5, 0.5, 0.5)
            end
        end
    end

    if infoFrame.wishlistBtn then
        if petData.collected then
            infoFrame.wishlistBtn:Hide()
            if infoFrame.favBtn then
                infoFrame.favBtn:Show()
            end
        else
            infoFrame.wishlistBtn:SetText(GetWishlistButtonText(
                DC.IsInWishlist and DC:IsInWishlist("pets", petData.id) or false))
            infoFrame.wishlistBtn:Show()
            if infoFrame.favBtn then
                infoFrame.favBtn:Hide()
            end
        end
    end

    if type(DC.Debug) == "function" then
        DC:Debug(string.format(
            "Pet preview select: id=%s name=%s collected=%s displayId=%s creatureId=%s",
            tostring(ToPositiveNumber(petData.id) or "?"),
            tostring((petData.name and petData.name ~= "" and petData.name) or
                (def and def.name) or "?"),
            tostring(petData.collected and true or false),
            tostring(ToPositiveNumber(select(2, GetPetPreviewFields(def))) or 0),
            tostring(ToPositiveNumber(select(1, GetPetPreviewFields(def))) or 0)))
    end

    -- Display 3D model.
    -- Collected companions are best resolved via Blizzard's companion list (SetCreature).
    -- Not-collected entries often need displayId from server definitions (SetDisplayInfo).
    local function ResetModelPose()
        if model.SetFacing then model:SetFacing(0) end
        model.rotation = 0
        model.zoom = 0
        if model.SetPortraitZoom then model:SetPortraitZoom(0) end
        if model.SetCamDistanceScale then model:SetCamDistanceScale(1.0) end
        if model.SetCamera then model:SetCamera(0) end
        if model.SetModelScale then model:SetModelScale(1.0) end
        if model.SetPosition then model:SetPosition(0, 0, 0) end
    end

    local function HasLoadedModel()
        if type(model.GetModel) ~= "function" then
            return true
        end

        local currentModel = model:GetModel()
        return currentModel ~= nil and currentModel ~= ""
    end

    local creatureId = select(1, GetPetPreviewFields(def))

    -- Many datasets store only a CreatureDisplayInfoID (displayId).
    -- Prefer SetDisplayInfo when available and keep SetCreature as compatibility fallback.
    local displayId = select(2, GetPetPreviewFields(def))

    local spellId = def.spellId or def.spell_id
    if type(spellId) == "string" then
        spellId = tonumber(spellId)
    end

    local fallbackKey = ToPositiveNumber(petData.id) or
        ToPositiveNumber(def.itemId or def.item_id)
    local explicitFallback = PET_PREVIEW_VISUAL_FALLBACKS[fallbackKey]
    local donorFallback = FindDefinitionPreviewFallbackByName(
        petData.id,
        petData.name or def.name)
    local previewFallback = nil
    if explicitFallback or donorFallback then
        previewFallback = {
            creatureId = ToPositiveNumber(explicitFallback and explicitFallback.creatureId) or
                ToPositiveNumber(donorFallback and donorFallback.creatureId),
            displayId = ToPositiveNumber(explicitFallback and explicitFallback.displayId) or
                ToPositiveNumber(donorFallback and donorFallback.displayId),
        }
    end
    local resolvedDisplayId = displayId
    if (not resolvedDisplayId or resolvedDisplayId <= 0) and
       type(previewFallback) == "table" then
        resolvedDisplayId = tonumber(previewFallback.displayId)
    end

    local resolvedDefinitionCreatureId = creatureId
    if (not resolvedDefinitionCreatureId or resolvedDefinitionCreatureId <= 0) and
       type(previewFallback) == "table" then
        resolvedDefinitionCreatureId = tonumber(previewFallback.creatureId)
    end

    local function FindCollectedCompanionCreatureIdBySpellId(sId)
        if not sId or not GetNumCompanions or not GetCompanionInfo then
            return nil
        end

        for i = 1, GetNumCompanions("CRITTER") do
            local cID, _, sID = GetCompanionInfo("CRITTER", i)
            if sID == sId then
                return cID
            end
        end

        return nil
    end

    local function FindCollectedCompanionCreatureIdByName(petName)
        if not petName or petName == "" or not GetNumCompanions or not GetCompanionInfo then
            return nil
        end

        local want = string.lower(tostring(petName))
        for i = 1, GetNumCompanions("CRITTER") do
            local cID, cName = GetCompanionInfo("CRITTER", i)
            if cName and string.lower(cName) == want then
                return cID
            end
        end

        return nil
    end

    -- Priority rules:
    -- 1) Not-collected pets should prefer displayId first. On 3.3.5a,
    --    SetCreature can "succeed" for some ids yet still render blank.
    -- 2) Collected pets can still prefer companion creature ids first, then
    --    fall back through display and definition creature ids.
    local resolvedCompanionCreatureId = nil
    if petData.collected then
        resolvedCompanionCreatureId = FindCollectedCompanionCreatureIdBySpellId(spellId)

        -- If spellId in definitions is a "teaching" spell (LEARN_*), it won't match the companion list.
        -- Fall back to a name match so collected pets still get a model.
        if (not resolvedCompanionCreatureId or resolvedCompanionCreatureId <= 0) then
            resolvedCompanionCreatureId = FindCollectedCompanionCreatureIdByName(petData.name or def.name)
        end
    end
    local fallbackCreatureId = nil
    if resolvedCompanionCreatureId and resolvedCompanionCreatureId > 0 then
        fallbackCreatureId = resolvedCompanionCreatureId
    elseif resolvedDefinitionCreatureId and resolvedDefinitionCreatureId > 0 then
        fallbackCreatureId = resolvedDefinitionCreatureId
    end

    local function TrySetCreature(modelId)
        if not modelId or modelId <= 0 or type(model.SetCreature) ~= "function" then
            return false
        end

        local ok = pcall(model.SetCreature, model, modelId)
        if ok then
            if type(model.Show) == "function" then
                model:Show()
            end
            if type(model.SetAlpha) == "function" then
                model:SetAlpha(1)
            end
            ResetModelPose()
            return true
        end

        return false
    end

    local function TrySetDisplay(displayInfoId)
        if not displayInfoId or displayInfoId <= 0 or type(model.SetDisplayInfo) ~= "function" then
            return false
        end

        local ok = pcall(model.SetDisplayInfo, model, displayInfoId)
        if ok then
            if type(model.Show) == "function" then
                model:Show()
            end
            if type(model.SetAlpha) == "function" then
                model:SetAlpha(1)
            end
            ResetModelPose()
            return true
        end

        return false
    end

    if type(model.ClearModel) == "function" then
        model:ClearModel()
    end

    local function TryApplyModelPath(kind, value)
        if kind == "display" then
            if not TrySetDisplay(value) then
                return false
            end
        else
            if not TrySetCreature(value) then
                return false
            end
        end

        -- Accept API-level success and let async verification handle delayed loads.
        return true
    end

    local attempts = {}
    local function PushAttempt(kind, value, allowDuplicate)
        value = ToPositiveNumber(value)
        if not value then
            return
        end

        local key = kind .. ":" .. tostring(value)
        if not allowDuplicate and attempts[key] then
            return
        end

        if not allowDuplicate then
            attempts[key] = true
        end
        attempts[#attempts + 1] = { kind = kind, value = value }
    end

    if petData.collected then
        PushAttempt("creature", resolvedCompanionCreatureId)
        PushAttempt("display", resolvedDisplayId)
        PushAttempt("creature", resolvedDefinitionCreatureId)
        -- End on collected companion creature where possible.
        PushAttempt("creature", resolvedCompanionCreatureId, true)
    else
        PushAttempt("display", resolvedDisplayId)
        PushAttempt("creature", resolvedDefinitionCreatureId)
        -- End on display for uncollected pets; this path is usually most stable.
        PushAttempt("display", resolvedDisplayId, true)
    end

    -- Some clients accept SetCreature with display-like ids as a fallback.
    PushAttempt("creature", resolvedDisplayId)

    local attemptIndex = 1
    local function ApplyNextAttempt()
        while attemptIndex <= #attempts do
            local attempt = attempts[attemptIndex]
            attemptIndex = attemptIndex + 1
            if TryApplyModelPath(attempt.kind, attempt.value) then
                return true
            end
        end

        return false
    end

    local modelShown = ApplyNextAttempt()

    if not modelShown then
        ReportPetPreviewIssue(
            petData,
            def,
            "model_apply_failed",
            resolvedDisplayId,
            fallbackCreatureId or resolvedDefinitionCreatureId)
    end

    local verifyToken = (self._modelVerifyToken or 0) + 1
    self._modelVerifyToken = verifyToken

    local function VerifyModelLoaded(retriesLeft)
        if self._modelVerifyToken ~= verifyToken then
            return
        end

        if self.selectedPet ~= petData then
            return
        end

        -- Keep walking fallbacks first; API-level success can still result in
        -- a blank frame on some clients.
        if retriesLeft and retriesLeft > 0 then
            ApplyNextAttempt()
            if DC and type(DC.After) == "function" then
                DC.After(0.12, function()
                    VerifyModelLoaded(retriesLeft - 1)
                end)
                return
            end
        end

        if HasLoadedModel() then
            if type(DC.Debug) == "function" then
                local loadedKey = tostring(ToPositiveNumber(petData.id) or "?")
                DC._petPreviewLoadedSeen = DC._petPreviewLoadedSeen or {}
                if not DC._petPreviewLoadedSeen[loadedKey] then
                    DC._petPreviewLoadedSeen[loadedKey] = true
                    local modelPath = "n/a"
                    if type(model.GetModel) == "function" then
                        local raw = model:GetModel()
                        modelPath = (raw and raw ~= "" and tostring(raw)) or "<empty>"
                    end
                    DC:Debug(string.format(
                        "Pet preview model loaded: id=%s path=%s attempts=%d/%d",
                        loadedKey,
                        modelPath,
                        math.max(0, math.min((attemptIndex - 1), #attempts)),
                        #attempts))
                end
            end
            return
        end

        local recovered = false

        while attemptIndex <= #attempts do
            if ApplyNextAttempt() then
                recovered = true
                break
            end
        end

        if not recovered and type(model.SetUnit) == "function" then
            ReportPetPreviewIssue(
                petData,
                def,
                "model_async_load_failed",
                resolvedDisplayId,
                fallbackCreatureId or resolvedDefinitionCreatureId)

            model:SetUnit("player")
            if type(model.Show) == "function" then
                model:Show()
            end
            if type(model.SetAlpha) == "function" then
                model:SetAlpha(1)
            end
            ResetModelPose()
        end
    end

    if DC and type(DC.After) == "function" then
        DC.After(0.12, function()
            VerifyModelLoaded(2)
        end)
    else
        VerifyModelLoaded(0)
    end

    local summonBtn = self.frame.actionBar.summonBtn
    if petData.collected then
        summonBtn:Enable()
        summonBtn:SetText(L["SUMMON"] or "Summon")
    else
        summonBtn:Enable()
        summonBtn:SetText(GetWishlistButtonText(
            DC.IsInWishlist and DC:IsInWishlist("pets", petData.id) or false))
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
    self:UpdatePetList()
end

-- ============================================================================
-- SHOW/HIDE
-- ============================================================================

function PetJournal:Show()
    if not self.frame then
        self:Create()
    end

    -- Ensure the PetModule is initialized (load-order / error safe).
    if DC.PetModule and not DC.PetModule._initialized and type(DC.PetModule.Init) == "function" then
        pcall(DC.PetModule.Init, DC.PetModule)
    end

    -- If server-side pet definitions are not configured, seed from client-known companions.
    if (not DC.definitions or not DC.definitions.pets or next(DC.definitions.pets) == nil) and DC.PetModule and type(DC.PetModule.SeedFromClientKnownPets) == "function" then
        DC.PetModule:SeedFromClientKnownPets()
    end

    do
        local now = (type(GetTime) == "function" and GetTime()) or
            (type(time) == "function" and time()) or 0
        local last = tonumber(self._lastPetsRefreshAt or 0) or 0
        local hasLocalPets = DC and DC.collections and
            type(DC.collections.pets) == "table" and
            next(DC.collections.pets) ~= nil

        if (not hasLocalPets) or now <= 0 or (now - last) >= 20 then
            self._lastPetsRefreshAt = now
            if DC.RequestDefinitions then
                DC:RequestDefinitions("pets")
            end
            if DC.RequestCollection then
                DC:RequestCollection("pets")
            end
        end
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
