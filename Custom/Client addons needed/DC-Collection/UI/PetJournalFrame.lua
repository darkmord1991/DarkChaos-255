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
    
    -- Check if we're still loading data
    if #pets == 0 then
        local defs = DC.definitions["pets"] or {}
        local defCount = 0
        for _ in pairs(defs) do defCount = defCount + 1 end
        
        -- If definitions are empty, try a client-side fallback first (known companion spells).
        if defCount == 0 then
            if DC.PetModule and type(DC.PetModule.SeedFromClientKnownPets) == "function" then
                if DC.PetModule:SeedFromClientKnownPets() then
                    self:UpdatePetList()
                    return
                end
            end

            -- Still empty: show loading message and keep asking the server.
            if not scrollChild.loadingText then
                scrollChild.loadingText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                scrollChild.loadingText:SetPoint("CENTER", scrollChild, "CENTER", 0, 50)
            end
            
            scrollChild.loadingText:SetText("Loading pets data...")
            scrollChild.loadingText:Show()
            
            -- Request definitions again if needed
            if type(DC.RequestDefinitions) == "function" then
                DC:RequestDefinitions("pets")
            end
            
            self.frame.listFrame.pageFrame.pageText:SetText("Loading...")
            return
        end
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
    infoFrame.icon:SetTexture(GetPetIcon(def.spellId or def.spell_id, def))
    infoFrame.name:SetText(petData.name or "Unknown")

    local r, g, b = GetRarityColor(petData.rarity)
    infoFrame.name:SetTextColor(r, g, b)

    local sourceText = DC:FormatSource(petData.source)
    infoFrame.source:SetText(sourceText or "")

    local favTex = infoFrame.favBtn:GetNormalTexture()
    if favTex then
        if petData.is_favorite then
            favTex:SetVertexColor(1, 0.8, 0)
        else
            favTex:SetVertexColor(0.5, 0.5, 0.5)
        end
    end

    -- Display 3D model
    -- IMPORTANT (WotLK 3.3.5a): PlayerModel does NOT have SetDisplayInfo.
    -- Prefer creatureId/spellId-based preview; only call SetDisplayInfo if the API exists.
    local function ResetModelPose()
        if model.SetFacing then model:SetFacing(0) end
        model.rotation = 0
        model.zoom = 0
        if model.SetPosition then model:SetPosition(0, 0, 0) end
    end

    local creatureId = def.creatureId or def.creature_id or def.creatureEntry
    if type(creatureId) == "string" then
        creatureId = tonumber(creatureId)
    end

    if creatureId and creatureId > 0 then
        model:ClearModel()
        model:SetCreature(creatureId)
        ResetModelPose()
    else
        -- Fallback: try to infer creature id from the player's companion list by spellId.
        local spellId = def.spellId or def.spell_id
        if type(spellId) == "string" then
            spellId = tonumber(spellId)
        end

        local inferredCreatureId = nil
        if spellId and GetNumCompanions and GetCompanionInfo then
            for i = 1, GetNumCompanions("CRITTER") do
                local cID, _, sID = GetCompanionInfo("CRITTER", i)
                if sID == spellId then
                    inferredCreatureId = cID
                    break
                end
            end
        end

        if inferredCreatureId and inferredCreatureId > 0 then
            model:ClearModel()
            model:SetCreature(inferredCreatureId)
            ResetModelPose()
        else
            -- Last resort: only use displayId if the model supports it (some custom clients do).
            local displayId = def.displayId or def.displayID or def.display_id
                           or def.creatureDisplayId or def.creature_display_id
                           or def.modelId or def.model_id
            if type(displayId) == "string" then
                displayId = tonumber(displayId)
            end

            model:ClearModel()
            if displayId and displayId > 0 and model.SetDisplayInfo then
                model:SetDisplayInfo(displayId)
                ResetModelPose()
            end
        end
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
    self:UpdatePetList()
end

-- ============================================================================
-- SHOW/HIDE
-- ============================================================================

function PetJournal:Show()
    if not self.frame then
        self:Create()
    end

    -- If server-side pet definitions are not configured, seed from client-known companions.
    if (not DC.definitions or not DC.definitions.pets or next(DC.definitions.pets) == nil) and DC.PetModule and type(DC.PetModule.SeedFromClientKnownPets) == "function" then
        DC.PetModule:SeedFromClientKnownPets()
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
