--[[
    DC-Collection UI/BeastmasterFrame.lua
    =====================================

    Hunter "Beastmaster" pet catalog with a live 3D model preview.

    A browsable, server-driven catalog of tameable pets (BEAST module). The list
    and the model-preview resolver are lifted from PetJournalFrame.lua (the
    DressUpModel attempt-list + async VerifyModelLoaded pattern), but the data
    source is the server catalog (SMSG_CATALOG) instead of the companion-pet
    system, and the action is "Adopt" -> Player::CreatePet() server-side.

    Only hunters see this tab; exotic-family pets require the Beast Mastery
    talent (enforced server-side, surfaced here as an error toast).

    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC and DC.L or {}
local Proto = DCAddonProtocol

local Beastmaster = {}
DC.Beastmaster = Beastmaster

-- ============================================================================
-- PROTOCOL (mirror of DCAddon::Opcode::Beastmaster in dc_addon_namespace.h)
-- ============================================================================

local MODULE            = "BEAST"
local CMSG_GET_CATALOG  = 0x01
local CMSG_ADOPT        = 0x02
local SMSG_CATALOG      = 0x10
local SMSG_ADOPT_RESULT = 0x11

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local LIST_WIDTH     = 280
local BUTTON_HEIGHT  = 48
local ITEMS_PER_PAGE = 12
local CATALOG_REFRESH_THROTTLE = 20 -- seconds

-- Downported/custom creature displays live above this id (see SelectPet's
-- isCustomDisplay check and Data/PetModelPaths.lua's own convention). Shared here
-- so the "WotLK+ (Downports)" expansion filter uses the exact same boundary as
-- model resolution.
local CUSTOM_DISPLAY_FLOOR = 100000
-- Custom-added pets (downports, Molten Front, etc.) use creature_template entries far
-- above stock WotLK creatures (which cap well under 100000). Used by the WotLK+ filter.
local CUSTOM_ENTRY_FLOOR = 100000

local FILTER_FAMILY_ALL = "__ALL__"

-- Mirrors UI/Wardrobe/WardrobeCore.lua's EXPANSION_FILTERS (Wardrobe.WOTLK_MAX_ITEM_ID)
-- so the two tabs read the same, matching Beastmaster's own displayId-based boundary.
local EXPANSION_FILTERS = {
    { id = "all",       text = "All Expansions" },
    { id = "classic",   text = "Classic - WotLK" },
    { id = "wotlkplus", text = "WotLK+ (Downports)" },
}

local ADOPT_ERRORS = {
    not_a_hunter           = "Only hunters can adopt pets.",
    not_in_catalog         = "That pet is not available.",
    invalid_pet            = "That pet cannot be adopted.",
    requires_beast_mastery = "Requires the Beast Mastery talent (exotic pet).",
    already_have_pet       = "Dismiss your current pet first.",
    in_combat              = "You cannot adopt a pet while in combat.",
    create_failed          = "Failed to create the pet. Try again.",
    bad_request            = "Invalid request.",
}

-- ============================================================================
-- HELPERS
-- ============================================================================

local function ToPositiveNumber(value)
    local num = tonumber(value)
    if num and num > 0 then
        return num
    end

    return nil
end

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

local function Notify(msg, isError)
    if not msg or msg == "" then
        return
    end

    if isError and type(UIErrorsFrame) == "table" and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(msg, 1.0, 0.2, 0.2, 1.0)
        return
    end

    if DC and type(DC.Print) == "function" then
        DC:Print(msg)
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66cc33[Beastmaster]|r " .. msg)
    end
end

-- ============================================================================
-- FRAME CREATION
-- ============================================================================

function Beastmaster:Create(parent)
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "DCBeastmasterFrame", parent or UIParent)
    frame:SetAllPoints(parent)
    frame:Hide()

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetTexture(0, 0, 0, 0.3)

    self:CreatePetList(frame)
    self:CreateModelPreview(frame)
    self:CreateActionBar(frame)

    self.frame = frame
    self.currentPage = 1
    self.selectedPet = nil
    self.filtered = self.filtered or {}

    self:RegisterProtocol()

    return frame
end

-- ============================================================================
-- PET LIST (Left Side)
-- ============================================================================

function Beastmaster:CreatePetList(parent)
    local listFrame = CreateFrame("Frame", nil, parent)
    listFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
    listFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 5, 50)
    listFrame:SetWidth(LIST_WIDTH)

    local bg = listFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0, 0, 0, 0.4)

    self:CreateFilterRow(listFrame)

    local scrollFrame = CreateFrame("ScrollFrame", "DCBeastmasterScrollFrame", listFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listFrame.filterRow, "BOTTOMLEFT", 5, -3)
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
        pagerWidth = 150,
        pagerHeight = 20,
        buttonTemplate = "UIPanelButtonTemplate",
        buttonWidth = 30,
        buttonHeight = 20,
        buttonLayout = "adjacent",
        buttonGap = 8,
        pageText = "1/1",
        onPrev = function() Beastmaster:PrevPage() end,
        onNext = function() Beastmaster:NextPage() end,
    })

    listFrame.statsText = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listFrame.statsText:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -30, 10)
    listFrame.statsText:SetText("0")

    listFrame.pageFrame = pageFrame
    parent.listFrame = listFrame
end

-- ============================================================================
-- FAMILY / EXPANSION FILTER ROW
-- ============================================================================

function Beastmaster:CreateFilterRow(listFrame)
    -- Stacked (not side-by-side): the list panel is only LIST_WIDTH (280px) wide, and
    -- Blizzard's UIDropDownMenuTemplate chrome is significantly wider than the value
    -- passed to UIDropDownMenu_SetWidth, so two dropdowns side by side would overlap
    -- or clip in a panel this narrow.
    local row = CreateFrame("Frame", nil, listFrame)
    row:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 5, -26)
    row:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -5, -26)
    row:SetHeight(70) -- two stock UIDropDownMenuTemplate frames (~32px tall each) stacked, + gap

    local familyDropdown = CreateFrame("Frame", "DCBeastmasterFamilyDropdown", row, "UIDropDownMenuTemplate")
    familyDropdown:SetPoint("TOPLEFT", row, "TOPLEFT", -16, 0)
    UIDropDownMenu_SetWidth(familyDropdown, LIST_WIDTH - 60)
    UIDropDownMenu_SetText(familyDropdown, "Family: All")

    -- ~32 pet families overflow a single flat dropdown off the top of the screen
    -- (WoW 3.3.5 dropdowns don't scroll and auto-flip upward when placed high), so
    -- the families are chunked into alphabetical submenus. Top level stays short
    -- ("All" + a handful of range entries); each range opens a side submenu.
    local FAMILY_CHUNK = 10
    local function PickFamily(familyName)
        Beastmaster.selectedFamilyFilter = familyName
        UIDropDownMenu_SetText(familyDropdown,
            familyName == FILTER_FAMILY_ALL and "Family: All" or ("Family: " .. familyName))
        CloseDropDownMenus()
        Beastmaster:UpdateList()
    end

    UIDropDownMenu_Initialize(familyDropdown, function(self, level, menuList)
        local families = Beastmaster:GetAvailableFamilies()

        if level == 1 then
            local allInfo = UIDropDownMenu_CreateInfo()
            allInfo.text = "All"
            allInfo.notCheckable = true
            allInfo.func = function() PickFamily(FILTER_FAMILY_ALL) end
            UIDropDownMenu_AddButton(allInfo, level)

            -- Short list: no need to chunk.
            if #families <= FAMILY_CHUNK + 2 then
                for _, familyName in ipairs(families) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = familyName
                    info.notCheckable = true
                    info.func = function() PickFamily(familyName) end
                    UIDropDownMenu_AddButton(info, level)
                end
                return
            end

            for i = 1, #families, FAMILY_CHUNK do
                local last = math.min(i + FAMILY_CHUNK - 1, #families)
                local info = UIDropDownMenu_CreateInfo()
                info.text = families[i] .. "  -  " .. families[last]
                info.notCheckable = true
                info.hasArrow = true
                info.menuList = tostring(i)
                UIDropDownMenu_AddButton(info, level)
            end
        elseif level == 2 and menuList then
            local startIdx = tonumber(menuList) or 1
            for j = startIdx, math.min(startIdx + FAMILY_CHUNK - 1, #families) do
                local familyName = families[j]
                local info = UIDropDownMenu_CreateInfo()
                info.text = familyName
                info.notCheckable = true
                info.func = function() PickFamily(familyName) end
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end)

    row.familyDropdown = familyDropdown
    self.selectedFamilyFilter = self.selectedFamilyFilter or FILTER_FAMILY_ALL

    local expansionDropdown = CreateFrame("Frame", "DCBeastmasterExpansionDropdown", row, "UIDropDownMenuTemplate")
    expansionDropdown:SetPoint("TOPLEFT", familyDropdown, "BOTTOMLEFT", 0, 3)
    UIDropDownMenu_SetWidth(expansionDropdown, LIST_WIDTH - 60)
    UIDropDownMenu_SetText(expansionDropdown, "All Expansions")

    UIDropDownMenu_Initialize(expansionDropdown, function(self, level)
        for _, expInfo in ipairs(EXPANSION_FILTERS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = expInfo.text
            info.value = expInfo.id
            info.func = function(btn)
                Beastmaster.selectedExpansionFilter = btn.value
                UIDropDownMenu_SetText(expansionDropdown, btn:GetText())
                CloseDropDownMenus()
                Beastmaster:UpdateList()
            end
            info.checked = ((Beastmaster.selectedExpansionFilter or "all") == expInfo.id)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    row.expansionDropdown = expansionDropdown
    self.selectedExpansionFilter = self.selectedExpansionFilter or "all"

    listFrame.filterRow = row
end

-- Distinct family names present in the current catalog, alphabetically sorted.
-- Recomputed on demand (not cached) so a fresh catalog fetch is reflected
-- immediately the next time the dropdown is opened.
function Beastmaster:GetAvailableFamilies()
    local seen = {}
    local families = {}
    for _, p in ipairs(self.catalog or {}) do
        local name = p.familyName
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            families[#families + 1] = name
        end
    end
    table.sort(families)
    return families
end

-- True when `pet` passes the currently selected family + expansion filters.
function Beastmaster:PetPassesFilters(pet)
    local familyFilter = self.selectedFamilyFilter
    if familyFilter and familyFilter ~= FILTER_FAMILY_ALL then
        if (pet.familyName or "") ~= familyFilter then
            return false
        end
    end

    local expansionFilter = self.selectedExpansionFilter
    if expansionFilter and expansionFilter ~= "all" then
        -- A "WotLK+ downport" is a custom-added pet. The downports REUSE retail
        -- CreatureDisplayInfo ids (all < CUSTOM_DISPLAY_FLOOR, e.g. Fenryr 64466), so
        -- displayId alone can't classify them - key on the custom creature ENTRY range
        -- instead (DC custom pets: Thok 400101, Molten Front 365xxxx, downports 99xxxx;
        -- stock WotLK creatures are all well below 100000).
        local displayId = ToPositiveNumber(pet.displayId) or 0
        local creatureId = ToPositiveNumber(pet.creatureId) or 0
        local isCustom = creatureId >= CUSTOM_ENTRY_FLOOR or displayId >= CUSTOM_DISPLAY_FLOOR
        if expansionFilter == "wotlkplus" and not isCustom then
            return false
        elseif expansionFilter == "classic" and isCustom then
            return false
        end
    end

    return true
end

-- ============================================================================
-- 3D MODEL PREVIEW (Right Side) -- lifted from PetJournalFrame:CreateModelPreview
-- ============================================================================

function Beastmaster:CreateModelPreview(parent)
    local modelFrame = CreateFrame("Frame", nil, parent)
    modelFrame:SetPoint("TOPLEFT", parent.listFrame, "TOPRIGHT", 10, 0)
    modelFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 50)

    local bg = modelFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0.05, 0.05, 0.1, 0.8)

    -- DressUpModel (not PlayerModel): it self-lights and reliably loads a
    -- creature via SetDisplayInfo()/SetCreature(). A bare PlayerModel loads
    -- the model unlit (renders black/blank).
    local model = CreateFrame("DressUpModel", "DCBeastmasterModel", modelFrame)
    model:SetPoint("TOPLEFT", modelFrame, "TOPLEFT", 10, -60)
    model:SetPoint("BOTTOMRIGHT", modelFrame, "BOTTOMRIGHT", -10, 10)

    model:EnableMouse(true)
    model:EnableMouseWheel(true)
    model.rotation = 0
    model.zoom = 0

    model:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.rotating = true
            self.prevX, self.prevY = GetCursorPosition()
        end
    end)

    model:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.rotating = false
        end
    end)

    model:SetScript("OnUpdate", function(self)
        if self.rotating then
            local x, y = GetCursorPosition()
            local delta = (x - (self.prevX or x)) * 0.01
            self.rotation = (self.rotation or 0) + delta
            -- No pitch API on 3.3.5 models; vertical drag pans view height.
            self.panZ = math.max(-1.5, math.min(1.5,
                (self.panZ or 0) + (y - (self.prevY or y)) * 0.004))
            -- Position first, facing LAST -- position calls can stomp facing.
            if self.SetPosition then
                self:SetPosition(0, 0, self.panZ)
            end
            self:SetFacing(self.rotation)
            self.prevX, self.prevY = x, y
        end
    end)

    model:SetScript("OnMouseWheel", function(self, delta)
        local s = (self.modelZoom or 1.0) + delta * 0.1
        s = math.max(0.5, math.min(2.5, s))
        self.modelZoom = s
        if self.SetModelScale then
            self:SetModelScale(s)
        end
    end)

    modelFrame.model = model

    -- Info header
    local infoFrame = CreateFrame("Frame", nil, modelFrame)
    infoFrame:SetPoint("TOPLEFT", modelFrame, "TOPLEFT", 10, -5)
    infoFrame:SetPoint("TOPRIGHT", modelFrame, "TOPRIGHT", -10, -5)
    infoFrame:SetHeight(50)

    infoFrame.icon = infoFrame:CreateTexture(nil, "ARTWORK")
    infoFrame.icon:SetSize(40, 40)
    infoFrame.icon:SetPoint("LEFT", infoFrame, "LEFT", 5, 0)
    infoFrame.icon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastCall")

    infoFrame.name = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    infoFrame.name:SetPoint("TOPLEFT", infoFrame.icon, "TOPRIGHT", 10, -5)
    infoFrame.name:SetText("Select a pet")

    infoFrame.source = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoFrame.source:SetPoint("TOPLEFT", infoFrame.name, "BOTTOMLEFT", 0, -3)
    infoFrame.source:SetTextColor(0.7, 0.7, 0.7)

    modelFrame.infoFrame = infoFrame
    parent.modelFrame = modelFrame
end

-- ============================================================================
-- ACTION BAR (Bottom)
-- ============================================================================

function Beastmaster:CreateActionBar(parent)
    local actionBar = CreateFrame("Frame", nil, parent)
    actionBar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 10)
    actionBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)
    actionBar:SetHeight(35)

    local adoptBtn = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
    adoptBtn:SetSize(160, 28)
    adoptBtn:SetPoint("LEFT", actionBar, "LEFT", 5, 0)
    adoptBtn:SetText("Adopt")
    adoptBtn:Disable()
    adoptBtn:SetScript("OnClick", function()
        Beastmaster:AdoptSelected()
    end)
    actionBar.adoptBtn = adoptBtn

    local hint = actionBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("LEFT", adoptBtn, "RIGHT", 12, 0)
    hint:SetTextColor(0.7, 0.7, 0.7)
    hint:SetText("Adopting gives you the pet instantly. Dismiss your current pet first.")
    actionBar.hint = hint

    parent.actionBar = actionBar
end

-- ============================================================================
-- LIST POPULATION
-- ============================================================================

function Beastmaster:CreatePetButton(parent, index)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(parent:GetWidth() - 10, BUTTON_HEIGHT)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -(index - 1) * (BUTTON_HEIGHT + 2))

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetTexture(0.1, 0.1, 0.1, 0.8)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(40, 40)
    btn.icon:SetPoint("LEFT", btn, "LEFT", 5, 0)
    btn.icon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastCall")

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

    btn:SetScript("OnClick", function()
        Beastmaster:SelectPet(btn.petData)
    end)

    btn:SetScript("OnDoubleClick", function()
        if btn.petData then
            Beastmaster:SelectPet(btn.petData)
            Beastmaster:AdoptSelected()
        end
    end)

    return btn
end

function Beastmaster:UpdateList()
    local searchText = ""
    if DC.MainFrame and DC.MainFrame.FilterBar and DC.MainFrame.FilterBar.searchBox then
        searchText = string.lower(DC.MainFrame.FilterBar.searchBox:GetText() or "")
    end

    local pets = {}
    for _, p in ipairs(self.catalog or {}) do
        local hay = string.lower((p.name or "") .. " " .. (p.familyName or "") .. " " .. (p.category or ""))
        if (searchText == "" or string.find(hay, searchText, 1, true)) and self:PetPassesFilters(p) then
            table.insert(pets, p)
        end
    end

    -- Server already returns sort_order; keep that, but group exotic pets after
    -- normal ones when searching so the list stays readable.
    self.filtered = pets

    if self.frame and self.frame.listFrame and self.frame.listFrame.statsText then
        self.frame.listFrame.statsText:SetText(tostring(#(self.catalog or {})))
    end

    self.currentPage = 1
    self:RefreshList()
end

function Beastmaster:RefreshList()
    if not self.frame or not self.frame:IsShown() then
        return
    end

    local pets = self.filtered or {}
    local scrollChild = self.frame.listFrame.scrollChild

    scrollChild.rowPool = scrollChild.rowPool or {}
    local rowPool = scrollChild.rowPool

    for _, row in ipairs(rowPool) do
        row:Hide()
    end

    if scrollChild.loadingText then
        scrollChild.loadingText:Hide()
    end

    if #pets == 0 then
        if not scrollChild.loadingText then
            scrollChild.loadingText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            scrollChild.loadingText:SetPoint("CENTER", scrollChild, "CENTER", 0, 50)
        end
        if self._catalogLoaded then
            scrollChild.loadingText:SetText("No pets match your filters.")
        else
            scrollChild.loadingText:SetText("Loading pets...")
        end
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
        local btn = rowPool[btnIndex]
        if not btn then
            btn = self:CreatePetButton(scrollChild, btnIndex)
            rowPool[btnIndex] = btn
        end
        btn:Show()

        btn.petData = pet
        btn.name:SetText(pet.name or "Unknown")

        local r, g, b = GetRarityColor(pet.rarity)
        btn.name:SetTextColor(r, g, b)

        local famText = pet.familyName or pet.category or ""
        if pet.exotic then
            famText = famText .. " |cffff8000(Exotic)|r"
        end
        btn.source:SetText(famText)

        if self.selectedPet and self.selectedPet.creatureId == pet.creatureId then
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
-- SELECTION & MODEL DISPLAY (resolver lifted from PetJournalFrame:SelectPet)
-- ============================================================================

function Beastmaster:SelectPet(petData)
    if not petData then return end

    self.selectedPet = petData

    local infoFrame = self.frame.modelFrame.infoFrame
    local model = self.frame.modelFrame.model

    infoFrame.name:SetText(petData.name or "Unknown")
    local r, g, b = GetRarityColor(petData.rarity)
    infoFrame.name:SetTextColor(r, g, b)

    local srcText = petData.source or ""
    if petData.familyName and petData.familyName ~= "" then
        srcText = srcText ~= "" and (srcText .. " -- " .. petData.familyName) or petData.familyName
    end
    if petData.exotic then
        srcText = srcText .. " |cffff8000(Exotic)|r"
    end
    infoFrame.source:SetText(srcText)

    -- Enable/label the adopt button.
    local adoptBtn = self.frame.actionBar.adoptBtn
    adoptBtn:Enable()
    adoptBtn:SetText("Adopt " .. (petData.name or ""))

    local function ResetModelPose()
        if model.SetFacing then model:SetFacing(0) end
        model.rotation = 0
        model.zoom = 0
        model.modelZoom = 1.0
        if model.SetPortraitZoom then model:SetPortraitZoom(0) end
        if model.SetCamDistanceScale then model:SetCamDistanceScale(2.5) end
        if model.SetModelScale then model:SetModelScale(1.0) end
        if model.SetPosition then model:SetPosition(0, 0, 0) end
    end

    local function HasLoadedModel()
        if type(model.GetModel) ~= "function" then
            return true
        end
        local currentModel = model:GetModel()
        return type(currentModel) == "string" and currentModel ~= ""
    end

    local displayId = ToPositiveNumber(petData.displayId)
    -- The real creature_template ENTRY. Unlike companion pets (which only have a
    -- display id), Beastmaster catalogs genuine creatures, so SetCreature(entry) -- the
    -- SAME textured path mounts/in-world creatures use -- is available. On this client
    -- it binds the CreatureDisplayInfo skin (SetModel(path) can't); it only needs the
    -- creature cached, which SetCreature itself triggers via a creature-query round-trip
    -- (the async re-check below waits for that before falling back to the white SetModel).
    local creatureId = ToPositiveNumber(petData.creatureId)
    local resolvedDisplayKey = displayId
    local modelPath = (DC and DC.BeastmasterModelPaths and resolvedDisplayKey and
        DC.BeastmasterModelPaths[resolvedDisplayKey]) or nil

    -- Preferred textured renderer: the SetCreatureDisplay DLL native (WotLKExtensions)
    -- binds the CreatureDisplayInfo skin from a display id directly -- the same native
    -- the Shapeshift/Forms preview relies on (UI/FormFrame.lua). SetModel(path) loads
    -- only geometry (renders WHITE for stock creatures) and SetDisplayInfo/SetCreature
    -- are unreliable on this client, so this native is what actually textures an
    -- un-owned creature. It is a global; gated so the tab still works (falling back to
    -- the white SetModel) if the DLL build without it is running.
    local function TrySetCreatureDisplay(displayInfoId)
        if not displayInfoId or displayInfoId <= 0 or type(SetCreatureDisplay) ~= "function" then
            return false
        end
        local ok, res = pcall(SetCreatureDisplay, model, displayInfoId)
        if ok and (res == true or res == 1) then
            if type(model.Show) == "function" then model:Show() end
            if type(model.SetAlpha) == "function" then model:SetAlpha(1) end
            ResetModelPose()
            return true
        end
        return false
    end

    local function TrySetCreature(modelId)
        if not modelId or modelId <= 0 or type(model.SetCreature) ~= "function" then
            return false
        end
        local ok = pcall(model.SetCreature, model, modelId)
        if ok then
            if type(model.Show) == "function" then model:Show() end
            if type(model.SetAlpha) == "function" then model:SetAlpha(1) end
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
            if type(model.Show) == "function" then model:Show() end
            if type(model.SetAlpha) == "function" then model:SetAlpha(1) end
            ResetModelPose()
            return true
        end
        return false
    end

    local function TrySetModelPath(path)
        if type(path) ~= "string" or path == "" or type(model.SetModel) ~= "function" then
            return false
        end
        local ok = pcall(model.SetModel, model, path)
        if ok then
            -- A raw SetModel'd creature M2 renders unlit/black without a light.
            if type(model.SetLight) == "function" then
                pcall(model.SetLight, model, 1, 0, 0, -0.707, -0.707,
                    0.7, 1.0, 1.0, 1.0, 0.8, 1.0, 1.0, 0.8)
            end
            if type(model.Show) == "function" then model:Show() end
            if type(model.SetAlpha) == "function" then model:SetAlpha(1) end
            ResetModelPose()
            return true
        end
        return false
    end

    if type(model.ClearModel) == "function" then
        model:ClearModel()
    end

    local function TryApply(kind, value)
        if kind == "model" then
            return TrySetModelPath(value)
        elseif kind == "creaturedisplay" then
            return TrySetCreatureDisplay(value)
        elseif kind == "display" then
            return TrySetDisplay(value)
        else
            return TrySetCreature(value)
        end
    end

    local attempts = {}
    local seen = {}
    local function PushAttempt(kind, value)
        if kind == "model" then
            if type(value) ~= "string" or value == "" then return end
        else
            value = ToPositiveNumber(value)
            if not value then return end
        end
        local key = kind .. ":" .. tostring(value)
        if seen[key] then return end
        seen[key] = true
        attempts[#attempts + 1] = { kind = kind, value = value }
    end

    -- Textured-preview strategy (see Custom/Documentation/Pet_Form_Preview_Texture_Native.md):
    -- on 3.3.5 SetModel(path) shows geometry only (WHITE for stock creatures),
    -- SetDisplayInfo is a no-op, and only the creature-display load path binds the
    -- CreatureDisplayInfo skin. Two ways to reach it, cheapest first:
    --   1. SetCreatureDisplay native  -- ideal, but currently a no-op stub (DLL native
    --      not built yet); harmless to try, wins automatically once the DLL ships.
    --   2. SetCreature(creatureId)    -- the ENTRY id. This is the mount path: it
    --      textures once the creature is cached, and triggers the caching query itself.
    --      The async re-check waits out the round-trip before giving up. (SetCreature
    --      with the displayId is also tried, since this client build's SetCreature has
    --      been observed to accept a display id too.)
    --   3. SetModel(path)             -- correct SHAPE, white for stock; but for
    --      downported (>= 100000) displays the .m2 has the skin BAKED IN, so it is fully
    --      textured there and therefore leads for custom displays.
    --   4. SetDisplayInfo(displayId)  -- no-op on 3.3.5, last-ditch only.
    local isCustomDisplay = resolvedDisplayKey ~= nil and resolvedDisplayKey >= CUSTOM_DISPLAY_FLOOR

    if isCustomDisplay then
        PushAttempt("model", modelPath)
        PushAttempt("creaturedisplay", displayId)
        PushAttempt("creature", creatureId)
        PushAttempt("creature", displayId)
        PushAttempt("display", displayId)
    else
        PushAttempt("creaturedisplay", displayId)
        PushAttempt("creature", creatureId)
        PushAttempt("creature", displayId)
        PushAttempt("model", modelPath)
        PushAttempt("display", displayId)
    end

    local attemptIndex = 1
    local function ApplyNextAttempt()
        while attemptIndex <= #attempts do
            local attempt = attempts[attemptIndex]
            attemptIndex = attemptIndex + 1
            if TryApply(attempt.kind, attempt.value) then
                return true
            end
        end
        return false
    end

    ApplyNextAttempt()

    local verifyToken = (self._modelVerifyToken or 0) + 1
    self._modelVerifyToken = verifyToken

    local function VerifyModelLoaded(checksLeft)
        if self._modelVerifyToken ~= verifyToken then
            return
        end
        if self.selectedPet ~= petData then
            return
        end
        if HasLoadedModel() then
            return
        end

        -- The current attempt may still be loading (SetCreature can need a
        -- creature-query round-trip). Give it a few delayed checks before
        -- advancing to the next, less faithful, attempt.
        if checksLeft and checksLeft > 0 and DC and type(DC.After) == "function" then
            DC.After(0.3, function()
                VerifyModelLoaded(checksLeft - 1)
            end)
            return
        end

        if attemptIndex <= #attempts then
            ApplyNextAttempt()
            if DC and type(DC.After) == "function" then
                DC.After(0.2, function()
                    VerifyModelLoaded(1)
                end)
                return
            end
            VerifyModelLoaded(0)
            return
        end

        -- Nothing rendered; leave the frame cleared rather than showing the
        -- dressed player model.
        if type(model.ClearModel) == "function" then
            model:ClearModel()
        end
    end

    if DC and type(DC.After) == "function" then
        DC.After(0.2, function()
            VerifyModelLoaded(4)
        end)
    else
        VerifyModelLoaded(0)
    end

    self:RefreshList()
end

-- ============================================================================
-- ADOPT
-- ============================================================================

function Beastmaster:AdoptSelected()
    local pet = self.selectedPet
    if not pet or not pet.creatureId then
        return
    end

    if not Proto or type(Proto.Request) ~= "function" then
        Notify("Addon protocol unavailable.", true)
        return
    end

    local adoptBtn = self.frame and self.frame.actionBar and self.frame.actionBar.adoptBtn
    if adoptBtn then
        adoptBtn:Disable()
        adoptBtn:SetText("Adopting...")
    end
    self._pendingAdopt = pet.creatureId

    Proto:Request(MODULE, CMSG_ADOPT, { creatureId = pet.creatureId })
end

-- ============================================================================
-- PROTOCOL HANDLERS
-- ============================================================================

function Beastmaster:RegisterProtocol()
    if self._protocolRegistered or not Proto then
        return
    end
    self._protocolRegistered = true

    Proto:RegisterJSONHandler(MODULE, SMSG_CATALOG, function(data)
        Beastmaster:OnCatalog(data)
    end)

    Proto:RegisterJSONHandler(MODULE, SMSG_ADOPT_RESULT, function(data)
        Beastmaster:OnAdoptResult(data)
    end)
end

function Beastmaster:OnCatalog(data)
    local pets = data and data.pets
    if type(pets) ~= "table" then
        pets = {}
    end

    -- Normalize numeric fields (JSON decode may hand back strings).
    local catalog = {}
    for _, p in ipairs(pets) do
        table.insert(catalog, {
            creatureId = ToPositiveNumber(p.creatureId),
            displayId  = ToPositiveNumber(p.displayId),
            name       = p.name or "Unknown",
            family     = ToPositiveNumber(p.family),
            familyName = p.familyName or "",
            rarity     = tonumber(p.rarity) or 1,
            category   = p.category or "Beast",
            source     = p.source or "",
            exotic     = p.exotic and true or false,
        })
    end

    self.catalog = catalog
    self._catalogLoaded = true
    self:UpdateList()

    if not self.selectedPet and self.filtered and #self.filtered > 0 then
        self:SelectPet(self.filtered[1])
    end
end

function Beastmaster:OnAdoptResult(data)
    local adoptBtn = self.frame and self.frame.actionBar and self.frame.actionBar.adoptBtn
    if adoptBtn then
        adoptBtn:Enable()
        if self.selectedPet then
            adoptBtn:SetText("Adopt " .. (self.selectedPet.name or ""))
        else
            adoptBtn:SetText("Adopt")
        end
    end
    self._pendingAdopt = nil

    if data and data.success then
        Notify("You adopted " .. (data.petName or "your new pet") .. "!")
    else
        local reason = data and data.error or "create_failed"
        Notify(ADOPT_ERRORS[reason] or ("Adopt failed: " .. tostring(reason)), true)
    end
end

-- ============================================================================
-- PAGINATION
-- ============================================================================

function Beastmaster:PrevPage()
    if self.currentPage > 1 then
        self.currentPage = self.currentPage - 1
        self:RefreshList()
    end
end

function Beastmaster:NextPage()
    local totalPages = math.max(1, math.ceil(#(self.filtered or {}) / ITEMS_PER_PAGE))
    if self.currentPage < totalPages then
        self.currentPage = self.currentPage + 1
        self:RefreshList()
    end
end

function Beastmaster:OnSearchChanged()
    self:UpdateList()
end

-- ============================================================================
-- SHOW/HIDE
-- ============================================================================

function Beastmaster:Show()
    if not self.frame then
        self:Create()
    end

    -- Throttled catalog fetch.
    local now = (type(GetTime) == "function" and GetTime()) or 0
    local last = tonumber(self._lastCatalogRequestAt or 0) or 0
    if (not self._catalogLoaded) or now <= 0 or (now - last) >= CATALOG_REFRESH_THROTTLE then
        self._lastCatalogRequestAt = now
        if Proto and type(Proto.Request) == "function" then
            Proto:Request(MODULE, CMSG_GET_CATALOG)
        end
    end

    self.frame:Show()
    self:UpdateList()

    if not self.selectedPet and self.filtered and #self.filtered > 0 then
        self:SelectPet(self.filtered[1])
    end
end

function Beastmaster:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function Beastmaster:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end
