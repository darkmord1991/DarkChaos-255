--[[
    DC-Collection UI/TransmogFrame.lua
    =================================

    CharacterFrame-style transmog UI:
    - Adds a new CharacterFrame tab
    - Shows embedded model preview
    - Slot buttons (retail-ish)
    - Appearance grid with search + paging

    NOTE:
    This is an original implementation for DC-Collection.
    Enhanced to use server-side slot-based API for appearance fetching.
]]

local DC = DCCollection
local L = DC and DC.L or nil

local UI = {}
DC.TransmogUI = UI

local function SafeGetText(key, fallback)
    if L and L[key] and L[key] ~= "" then
        return L[key]
    end
    return fallback
end

-- Visual slot IDs (matching PLAYER_VISIBLE_ITEM_*_ENTRYID constants from Transmogrification addon and C++ handlers)
local VISUAL_SLOT_HEAD       = 283
local VISUAL_SLOT_SHOULDER   = 287
local VISUAL_SLOT_SHIRT      = 289
local VISUAL_SLOT_CHEST      = 291
local VISUAL_SLOT_WAIST      = 293
local VISUAL_SLOT_LEGS       = 295
local VISUAL_SLOT_FEET       = 297
local VISUAL_SLOT_WRIST      = 299
local VISUAL_SLOT_HANDS      = 301
local VISUAL_SLOT_BACK       = 311
local VISUAL_SLOT_MAIN_HAND  = 313
local VISUAL_SLOT_OFF_HAND   = 315
local VISUAL_SLOT_RANGED     = 317
local VISUAL_SLOT_TABARD     = 319

local SLOT_ORDER = {
    { key = "HeadSlot",          label = "Head",      visualSlot = VISUAL_SLOT_HEAD,      invTypes = { [1] = true } },
    { key = "ShoulderSlot",      label = "Shoulder",  visualSlot = VISUAL_SLOT_SHOULDER,  invTypes = { [3] = true } },
    { key = "BackSlot",          label = "Back",      visualSlot = VISUAL_SLOT_BACK,      invTypes = { [16] = true } },
    { key = "ChestSlot",         label = "Chest",     visualSlot = VISUAL_SLOT_CHEST,     invTypes = { [5] = true, [20] = true } },
    { key = "ShirtSlot",         label = "Shirt",     visualSlot = VISUAL_SLOT_SHIRT,     invTypes = { [4] = true } },
    { key = "TabardSlot",        label = "Tabard",    visualSlot = VISUAL_SLOT_TABARD,    invTypes = { [19] = true } },
    { key = "WristSlot",         label = "Wrist",     visualSlot = VISUAL_SLOT_WRIST,     invTypes = { [9] = true } },
    { key = "HandsSlot",         label = "Hands",     visualSlot = VISUAL_SLOT_HANDS,     invTypes = { [10] = true } },
    { key = "WaistSlot",         label = "Waist",     visualSlot = VISUAL_SLOT_WAIST,     invTypes = { [6] = true } },
    { key = "LegsSlot",          label = "Legs",      visualSlot = VISUAL_SLOT_LEGS,      invTypes = { [7] = true } },
    { key = "FeetSlot",          label = "Feet",      visualSlot = VISUAL_SLOT_FEET,      invTypes = { [8] = true } },
    { key = "MainHandSlot",      label = "Main Hand", visualSlot = VISUAL_SLOT_MAIN_HAND, invTypes = { [13] = true, [17] = true, [21] = true } },
    { key = "SecondaryHandSlot", label = "Off Hand",  visualSlot = VISUAL_SLOT_OFF_HAND,  invTypes = { [13] = true, [14] = true, [17] = true, [22] = true, [23] = true } },
    { key = "RangedSlot",        label = "Ranged",    visualSlot = VISUAL_SLOT_RANGED,    invTypes = { [14] = true, [15] = true, [25] = true, [28] = true } },
}

local function GetSelectedSlotDef()
    if not UI.selectedSlotKey then
        return SLOT_ORDER[1]
    end
    for _, s in ipairs(SLOT_ORDER) do
        if s.key == UI.selectedSlotKey then
            return s
        end
    end
    return SLOT_ORDER[1]
end

local function GetSlotDefByVisualSlot(visualSlot)
    for _, s in ipairs(SLOT_ORDER) do
        if s.visualSlot == visualSlot then
            return s
        end
    end
    return nil
end

local function GetEquipmentSlotIndex(invSlotId)
    -- Protocol expects EQUIPMENT_SLOT (0-based in visible item fields)
    -- GetInventorySlotInfo returns 1-based inventory slot IDs.
    return (invSlotId == 1 and 0) or (invSlotId and (invSlotId - 1))
end

-- State for server-fetched slot items
UI.slotItems = {}      -- { [visualSlot] = { items = {}, page = 1, hasMore = false } }
UI.currentPage = 1
UI.hasMorePages = false
UI.useServerItems = true  -- Use server-fetched items instead of local definitions

local function EnsureDataLoaded()
    if not DC or not DC.RequestDefinitions or not DC.RequestCollection then
        return
    end

    DC:RequestDefinitions("transmog")
    DC:RequestCollection("transmog")
end

local function ModelTryOnItem(model, itemId)
    if not model or not itemId or itemId == 0 then
        return
    end

    -- Use the raw item ID for TryOn - WoW 3.3.5a TryOn accepts item IDs directly
    if model.TryOn then
        model:TryOn(itemId)
        return
    end

    -- Fallback: open dressing room
    if DressUpItemLink then
        local link = "item:" .. tostring(itemId) .. ":0:0:0:0:0:0:0"
        DressUpItemLink(link)
    end
end

local function ModelResetToPlayer(model)
    if not model then
        return
    end

    if model.SetUnit then
        model:SetUnit("player")
    end

    if model.Undress then
        model:Undress()
    end
end

local function UpdateSlotButtonVisual(btn)
    if not btn or not btn.slotKey then
        return
    end

    local invSlotId = GetInventorySlotInfo(btn.slotKey)
    local itemId = invSlotId and GetInventoryItemID("player", invSlotId)

    local texture = nil
    if itemId and GetItemInfo then
        texture = select(10, GetItemInfo(itemId))
    end

    if texture then
        btn.icon:SetTexture(texture)
    else
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    -- Highlight if transmog applied to that equipment slot.
    local eqSlot = invSlotId and GetEquipmentSlotIndex(invSlotId)
    local state = DC.transmogState or {}
    local applied = eqSlot ~= nil and state[tostring(eqSlot)] and tonumber(state[tostring(eqSlot)]) and tonumber(state[tostring(eqSlot)]) ~= 0

    if applied then
        btn.appliedGlow:Show()
    else
        btn.appliedGlow:Hide()
    end

    if UI.selectedSlotKey == btn.slotKey then
        btn.selectedGlow:Show()
    else
        btn.selectedGlow:Hide()
    end
end

local function IsAppearanceForSelectedSlot(def)
    if not def then
        return false
    end
    local slotDef = GetSelectedSlotDef()

    local invType = def.inventoryType or def.inventory_type or def.invType or def.inv_type
    if type(invType) == "string" then
        invType = tonumber(invType)
    end
    invType = invType or 0

    -- If inventoryType is missing (common on some servers/caches), infer from the canonical itemId.
    if invType == 0 then
        local itemId = def.itemId or def.item_id or def.item
        if type(itemId) == "string" then
            itemId = tonumber(itemId)
        end

        if itemId and GetItemInfo then
            local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemId)
            local equipMap = {
                INVTYPE_HEAD = 1,
                INVTYPE_SHOULDER = 3,
                INVTYPE_CLOAK = 16,
                INVTYPE_CHEST = 5,
                INVTYPE_ROBE = 20,
                INVTYPE_BODY = 4,
                INVTYPE_TABARD = 19,
                INVTYPE_WRIST = 9,
                INVTYPE_HAND = 10,
                INVTYPE_WAIST = 6,
                INVTYPE_LEGS = 7,
                INVTYPE_FEET = 8,
                INVTYPE_WEAPON = 13,
                INVTYPE_2HWEAPON = 17,
                INVTYPE_WEAPONMAINHAND = 21,
                INVTYPE_WEAPONOFFHAND = 22,
                INVTYPE_HOLDABLE = 23,
                INVTYPE_SHIELD = 14,
                INVTYPE_RANGED = 15,
                INVTYPE_RANGEDRIGHT = 26,
                INVTYPE_RELIC = 28,
            }
            if equipLoc and equipMap[equipLoc] then
                invType = equipMap[equipLoc]
            end
        end
    end

    return slotDef.invTypes[invType] == true
end

local function BuildAppearanceList()
    local defs = (DC and DC.definitions and DC.definitions.transmog) or {}
    local col = (DC and DC.collections and DC.collections.transmog) or {}

    local wantCollected = (UI.filterCollected ~= false)
    local wantNotCollected = (UI.filterNotCollected ~= false)

    local results = {}
    local search = UI.searchText
    if search and search ~= "" then
        search = string.lower(search)
    else
        search = nil
    end

    for id, def in pairs(defs) do
        if IsAppearanceForSelectedSlot(def) then
            local name = def.name or ""
            if (not search) or (string.find(string.lower(name), search, 1, true) ~= nil) then
                local collected = col[id] ~= nil

                if (collected and not wantCollected) or ((not collected) and not wantNotCollected) then
                    -- filtered out
                else
                table.insert(results, {
                    id = id,
                    def = def,
                    name = name,
                    collected = collected,
                })
                end
            end
        end
    end

    table.sort(results, function(a, b)
        if a.collected and not b.collected then return true end
        if b.collected and not a.collected then return false end
        return (a.name or "") < (b.name or "")
    end)

    return results
end

local function UpdateEquippedHeader()
    if not UI.frame or not UI.frame.equippedHeader then
        return
    end

    local header = UI.frame.equippedHeader
    local slotDef = GetSelectedSlotDef()
    local invSlotId = slotDef and GetInventorySlotInfo(slotDef.key)
    local itemId = invSlotId and GetInventoryItemID("player", invSlotId)

    header.slotText:SetText((slotDef and slotDef.label) or "")

    if itemId and GetItemInfo then
        local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemId)
        header.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        header.name:SetText(name or "")

        if quality and quality > 0 then
            local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
            if c then
                header.name:SetTextColor(c.r, c.g, c.b)
            else
                header.name:SetTextColor(1, 1, 1)
            end
        else
            header.name:SetTextColor(1, 1, 1)
        end

        header.empty:SetText("")
    else
        header.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        header.name:SetText("")
        header.name:SetTextColor(1, 1, 1)
        header.empty:SetText("No item equipped")
    end
end

local function UpdateGrid()
    if not UI.frame or not UI.frame:IsShown() then
        return
    end

    local list = BuildAppearanceList()
    UI.appearanceList = list

    local itemsPerPage = UI.itemsPerPage or 40
    UI.page = UI.page or 1

    local totalPages = math.max(1, math.ceil(#list / itemsPerPage))
    if UI.page > totalPages then
        UI.page = totalPages
    end

    local startIndex = (UI.page - 1) * itemsPerPage + 1
    local endIndex = math.min(#list, startIndex + itemsPerPage - 1)

    UI.frame.pageText:SetText(string.format("%d / %d", UI.page, totalPages))

    -- Fill buttons
    for i, btn in ipairs(UI.frame.gridButtons) do
        local idx = startIndex + (i - 1)
        local entry = list[idx]

        if entry then
            btn:Show()
            btn.entry = entry

            local itemId = entry.def and entry.def.itemId
            local icon = nil
            if itemId and GetItemInfo then
                icon = select(10, GetItemInfo(itemId))
            end
            btn.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")

            if entry.collected then
                btn.icon:SetVertexColor(1, 1, 1, 1)
                btn.lockOverlay:Hide()
            else
                btn.icon:SetVertexColor(0.35, 0.35, 0.35, 1)
                btn.lockOverlay:Show()
            end

            if UI.selectedAppearanceId and UI.selectedAppearanceId == entry.id then
                btn.selectedBorder:Show()
            else
                btn.selectedBorder:Hide()
            end
        else
            btn:Hide()
            btn.entry = nil
        end
    end
end

local function SelectSlot(slotKey)
    UI.selectedSlotKey = slotKey
    UI.page = 1
    UI.currentPage = 1
    UI.hasMorePages = false
    UI.selectedAppearanceId = nil

    if UI.frame and UI.frame.slotButtons then
        for _, b in ipairs(UI.frame.slotButtons) do
            UpdateSlotButtonVisual(b)
        end
    end

    UpdateEquippedHeader()

    -- Request items from server using the new slot-based API
    local slotDef = GetSelectedSlotDef()
    if slotDef and slotDef.visualSlot then
        local searchText = UI.searchText
        if searchText and searchText ~= "" then
            -- Use search API
            if DC and DC.SearchTransmogItems then
                DC:SearchTransmogItems(slotDef.visualSlot, searchText, 1)
            end
        else
            -- Use standard slot items API
            if DC and DC.RequestTransmogSlotItems then
                DC:RequestTransmogSlotItems(slotDef.visualSlot, 1)
            end
        end
    end

    -- Also show local results while waiting for server
    UpdateGrid()
end

-- Callback handler for server-fetched slot items
function UI:OnSlotItemsReceived(visualSlot, items, page, hasMore)
    local slotDef = GetSelectedSlotDef()
    if not slotDef or slotDef.visualSlot ~= visualSlot then
        return -- Response is for a different slot
    end

    UI.slotItems[visualSlot] = {
        items = items or {},
        page = page or 1,
        hasMore = hasMore or false,
    }
    UI.currentPage = page or 1
    UI.hasMorePages = hasMore or false

    -- Update the grid with server-fetched items
    UpdateGridWithServerItems(items, page, hasMore)
end

-- Update grid using server-fetched item list (itemIds)
local function UpdateGridWithServerItems(items, page, hasMore)
    if not UI.frame or not UI.frame:IsShown() then
        return
    end

    items = items or {}
    page = page or 1

    UI.frame.pageText:SetText(string.format("Page %d", page))

    -- Update pagination button states
    if UI.frame.prevBtn then
        if page > 1 then
            UI.frame.prevBtn:Enable()
        else
            UI.frame.prevBtn:Disable()
        end
    end

    if UI.frame.nextBtn then
        if hasMore then
            UI.frame.nextBtn:Enable()
        else
            UI.frame.nextBtn:Disable()
        end
    end

    -- Fill grid buttons with server items
    for i, btn in ipairs(UI.frame.gridButtons) do
        local itemId = items[i]

        if itemId then
            btn:Show()
            btn.itemId = itemId
            btn.entry = { id = itemId, itemId = itemId, collected = true }

            local icon = nil
            if GetItemInfo then
                icon = select(10, GetItemInfo(itemId))
            end
            btn.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            btn.icon:SetVertexColor(1, 1, 1, 1)
            btn.lockOverlay:Hide()

            if UI.selectedAppearanceId and UI.selectedAppearanceId == itemId then
                btn.selectedBorder:Show()
            else
                btn.selectedBorder:Hide()
            end
        else
            btn:Hide()
            btn.itemId = nil
            btn.entry = nil
        end
    end
end

local function PreviewAppearance(itemIdOrAppearanceId)
    if not itemIdOrAppearanceId or not UI.frame or not UI.frame.model then
        return
    end

    -- Try to get itemId from definitions first (legacy path)
    local def = DC and DC.definitions and DC.definitions.transmog and DC.definitions.transmog[itemIdOrAppearanceId]
    local itemId = def and def.itemId or itemIdOrAppearanceId

    UI.selectedAppearanceId = itemIdOrAppearanceId
    UI.selectedItemId = itemId

    -- Reset model to player, then try-on the item.
    ModelResetToPlayer(UI.frame.model)
    ModelTryOnItem(UI.frame.model, itemId)

    -- Refresh grid to show selection
    if UI.slotItems and next(UI.slotItems) then
        local slotDef = GetSelectedSlotDef()
        local data = slotDef and UI.slotItems[slotDef.visualSlot]
        if data then
            UpdateGridWithServerItems(data.items, data.page, data.hasMore)
        end
    else
        UpdateGrid()
    end
end

local function ApplySelectedAppearance()
    if not UI.selectedAppearanceId and not UI.selectedItemId then
        return
    end

    local slotDef = GetSelectedSlotDef()
    local invSlotId = GetInventorySlotInfo(slotDef.key)

    if not invSlotId then
        return
    end

    if not GetInventoryItemID("player", invSlotId) then
        if DC and DC.Print then
            DC:Print("No item equipped in that slot.")
        end
        return
    end

    -- Use itemId for the server request (server will resolve to displayId)
    local itemId = UI.selectedItemId or UI.selectedAppearanceId

    if DC and DC.RequestSetTransmogByEquipmentSlot then
        local eqSlot = GetEquipmentSlotIndex(invSlotId)
        DC:RequestSetTransmogByEquipmentSlot(eqSlot, itemId)
    elseif DC and DC.RequestSetTransmog then
        DC:RequestSetTransmog(invSlotId, itemId)
    end
end

local function ClearSelectedSlot()
    local slotDef = GetSelectedSlotDef()
    local invSlotId = GetInventorySlotInfo(slotDef.key)
    if not invSlotId then
        return
    end

    if not GetInventoryItemID("player", invSlotId) then
        if DC and DC.Print then
            DC:Print("No item equipped in that slot.")
        end
        return
    end

    if DC and DC.RequestClearTransmog then
        DC:RequestClearTransmog(invSlotId)
    end
end

local function CreateTransmogPanel()
    if UI.frame then
        return UI.frame
    end

    if not CharacterFrame then
        return nil
    end

    local frame = CreateFrame("Frame", "DCCollectionCharacterTransmogFrame", CharacterFrame)
    frame:SetAllPoints(true)
    frame:Hide()

    -- Background inset similar to default panels
    local inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", 18, -84)
    inset:SetPoint("BOTTOMRIGHT", -30, 36)

    -- Left panel: model + slot buttons
    local left = CreateFrame("Frame", nil, inset)
    left:SetPoint("TOPLEFT", inset, "TOPLEFT", 6, -6)
    left:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 6, 6)
    left:SetWidth(185)

    local model = CreateFrame("DressUpModel", nil, left)
    model:SetPoint("TOPLEFT", left, "TOPLEFT", 0, 0)
    model:SetPoint("TOPRIGHT", left, "TOPRIGHT", 0, 0)
    model:SetHeight(260)

    ModelResetToPlayer(model)

    -- Enable mouse rotation on the model (similar to Transmogrification addon)
    model:EnableMouse(true)
    model.isMouseRotating = false
    model.lastCursorX = 0
    
    model:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.isMouseRotating = true
            self.lastCursorX = GetCursorPosition()
        end
    end)
    
    model:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.isMouseRotating = false
        end
    end)
    
    model:SetScript("OnUpdate", function(self)
        if self.isMouseRotating then
            local currentX = GetCursorPosition()
            local diff = (currentX - self.lastCursorX) * 0.02
            self:SetFacing(self:GetFacing() + diff)
            self.lastCursorX = currentX
        end
    end)

    frame.model = model

    local slots = CreateFrame("Frame", nil, left)
    slots:SetPoint("TOPLEFT", model, "BOTTOMLEFT", 0, -6)
    slots:SetPoint("TOPRIGHT", model, "BOTTOMRIGHT", 0, -6)
    slots:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 0, 0)

    frame.slotButtons = {}

    local btnSize = 26
    local cols = 6
    for i, slot in ipairs(SLOT_ORDER) do
        local btn = CreateFrame("Button", nil, slots)
        btn:SetSize(btnSize, btnSize)
        local row = math.floor((i - 1) / cols)
        local col = (i - 1) % cols
        btn:SetPoint("TOPLEFT", slots, "TOPLEFT", col * (btnSize + 4), -row * (btnSize + 4))

        btn.slotKey = slot.key

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture(0, 0, 0, 0.4)

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.icon:SetSize(btnSize - 4, btnSize - 4)
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

        btn.appliedGlow = btn:CreateTexture(nil, "BORDER")
        btn.appliedGlow:SetAllPoints()
        btn.appliedGlow:SetTexture(0, 1, 0, 0.15)
        btn.appliedGlow:Hide()

        btn.selectedGlow = btn:CreateTexture(nil, "BORDER")
        btn.selectedGlow:SetAllPoints()
        btn.selectedGlow:SetTexture(0.3, 0.5, 1, 0.25)
        btn.selectedGlow:Hide()

        btn:SetScript("OnClick", function()
            SelectSlot(slot.key)
        end)

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(slot.label)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        table.insert(frame.slotButtons, btn)
    end

    -- Right panel: search + grid + paging + actions
    local right = CreateFrame("Frame", nil, inset)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
    right:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -6, 6)

    local title = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", right, "TOPLEFT", 0, 0)
    title:SetText(SafeGetText("TAB_TRANSMOG", "Transmog"))

    local searchBox = CreateFrame("EditBox", nil, right, "InputBoxTemplate")
    searchBox:SetSize(160, 20)
    searchBox:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, 2)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)
    searchBox:SetScript("OnTextChanged", function(self)
        UI.searchText = self:GetText() or ""
        -- Don't auto-search on each keystroke; user presses Enter
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        UI.currentPage = 1
        -- Trigger server search
        local slotDef = GetSelectedSlotDef()
        if slotDef and slotDef.visualSlot then
            local searchText = UI.searchText
            if searchText and searchText ~= "" then
                if DC and DC.SearchTransmogItems then
                    DC:SearchTransmogItems(slotDef.visualSlot, searchText, 1)
                end
            else
                if DC and DC.RequestTransmogSlotItems then
                    DC:RequestTransmogSlotItems(slotDef.visualSlot, 1)
                end
            end
        end
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        UI.searchText = ""
        UI.currentPage = 1
        -- Clear search, fetch default items
        local slotDef = GetSelectedSlotDef()
        if slotDef and slotDef.visualSlot then
            if DC and DC.RequestTransmogSlotItems then
                DC:RequestTransmogSlotItems(slotDef.visualSlot, 1)
            end
        end
    end)
    frame.searchBox = searchBox

    -- Collected / Not collected toggles (only affect local filtering, not server results)
    UI.filterCollected = true
    UI.filterNotCollected = true

    local collectedCheck = CreateFrame("CheckButton", nil, right, "UICheckButtonTemplate")
    collectedCheck:SetSize(24, 24)
    collectedCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, 2)
    collectedCheck:SetChecked(true)
    collectedCheck:SetScript("OnClick", function(self)
        UI.filterCollected = self:GetChecked() and true or false
        UI.page = 1
        UpdateGrid()
    end)

    local collectedLabel = right:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collectedLabel:SetPoint("LEFT", collectedCheck, "RIGHT", 2, 0)
    collectedLabel:SetText(SafeGetText("FILTER_COLLECTED", "Collected"))

    local notCollectedCheck = CreateFrame("CheckButton", nil, right, "UICheckButtonTemplate")
    notCollectedCheck:SetSize(24, 24)
    notCollectedCheck:SetPoint("LEFT", collectedLabel, "RIGHT", 10, 0)
    notCollectedCheck:SetChecked(true)
    notCollectedCheck:SetScript("OnClick", function(self)
        UI.filterNotCollected = self:GetChecked() and true or false
        UI.page = 1
        UpdateGrid()
    end)

    local notCollectedLabel = right:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    notCollectedLabel:SetPoint("LEFT", notCollectedCheck, "RIGHT", 2, 0)
    notCollectedLabel:SetText(SafeGetText("FILTER_NOT_COLLECTED", "Not collected"))

    -- Equipped item header (selected slot)
    local equippedHeader = CreateFrame("Frame", nil, right)
    equippedHeader:SetPoint("TOPLEFT", collectedCheck, "BOTTOMLEFT", 0, -4)
    equippedHeader:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -28)
    equippedHeader:SetHeight(24)

    equippedHeader.icon = equippedHeader:CreateTexture(nil, "ARTWORK")
    equippedHeader.icon:SetSize(20, 20)
    equippedHeader.icon:SetPoint("LEFT", equippedHeader, "LEFT", 0, 0)
    equippedHeader.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    equippedHeader.slotText = equippedHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    equippedHeader.slotText:SetPoint("LEFT", equippedHeader.icon, "RIGHT", 6, 0)
    equippedHeader.slotText:SetText("")

    equippedHeader.name = equippedHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    equippedHeader.name:SetPoint("LEFT", equippedHeader.slotText, "RIGHT", 10, 0)
    equippedHeader.name:SetPoint("RIGHT", equippedHeader, "RIGHT", 0, 0)
    equippedHeader.name:SetJustifyH("LEFT")
    equippedHeader.name:SetText("")

    equippedHeader.empty = equippedHeader:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    equippedHeader.empty:SetPoint("LEFT", equippedHeader.slotText, "RIGHT", 10, 0)
    equippedHeader.empty:SetPoint("RIGHT", equippedHeader, "RIGHT", 0, 0)
    equippedHeader.empty:SetJustifyH("LEFT")
    equippedHeader.empty:SetText("")

    frame.equippedHeader = equippedHeader

    local grid = CreateFrame("Frame", nil, right)
    grid:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -72)
    grid:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 38)

    frame.gridButtons = {}

    local iconSize = 36
    local gridCols = 5
    local gridRows = 8
    UI.itemsPerPage = gridCols * gridRows

    for i = 1, UI.itemsPerPage do
        local b = CreateFrame("Button", nil, grid)
        b:SetSize(iconSize, iconSize)

        local row = math.floor((i - 1) / gridCols)
        local col = (i - 1) % gridCols
        b:SetPoint("TOPLEFT", grid, "TOPLEFT", col * (iconSize + 6), -row * (iconSize + 6))

        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetTexture(0, 0, 0, 0.3)

        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.icon:SetSize(iconSize - 4, iconSize - 4)
        b.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

        b.lockOverlay = b:CreateTexture(nil, "OVERLAY")
        b.lockOverlay:SetAllPoints()
        b.lockOverlay:SetTexture(0, 0, 0, 0.35)
        b.lockOverlay:Hide()

        b.selectedBorder = b:CreateTexture(nil, "BORDER")
        b.selectedBorder:SetAllPoints()
        b.selectedBorder:SetTexture(0.3, 0.5, 1, 0.35)
        b.selectedBorder:Hide()

        b:SetScript("OnClick", function(self, button)
            local itemId = self.itemId or (self.entry and self.entry.id)
            if not itemId then
                return
            end

            PreviewAppearance(itemId)

            if button == "LeftButton" then
                -- Apply on left click (server items are always collected)
                ApplySelectedAppearance()
            end
        end)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        b:SetScript("OnEnter", function(self)
            local itemId = self.itemId or (self.entry and self.entry.itemId)
            if not itemId then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            -- Try to show item tooltip
            if itemId > 0 then
                GameTooltip:SetHyperlink("item:" .. itemId .. ":0:0:0:0:0:0:0")
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(SafeGetText("COLLECTED", "Collected"), 0, 1, 0)
            GameTooltip:AddLine("Left-click to apply", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Right-click to preview", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)

        table.insert(frame.gridButtons, b)
    end

    local prevBtn = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    prevBtn:SetSize(60, 20)
    prevBtn:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 10)
    prevBtn:SetText("Prev")
    prevBtn:SetScript("OnClick", function()
        local newPage = math.max(1, (UI.currentPage or 1) - 1)
        if newPage < (UI.currentPage or 1) then
            UI.currentPage = newPage
            -- Request previous page from server
            local slotDef = GetSelectedSlotDef()
            if slotDef and slotDef.visualSlot then
                local searchText = UI.searchText
                if searchText and searchText ~= "" then
                    if DC and DC.SearchTransmogItems then
                        DC:SearchTransmogItems(slotDef.visualSlot, searchText, newPage)
                    end
                else
                    if DC and DC.RequestTransmogSlotItems then
                        DC:RequestTransmogSlotItems(slotDef.visualSlot, newPage)
                    end
                end
            end
        end
    end)
    frame.prevBtn = prevBtn

    local nextBtn = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    nextBtn:SetSize(60, 20)
    nextBtn:SetPoint("BOTTOMLEFT", prevBtn, "BOTTOMRIGHT", 6, 0)
    nextBtn:SetText("Next")
    nextBtn:SetScript("OnClick", function()
        if not UI.hasMorePages then
            return
        end
        local newPage = (UI.currentPage or 1) + 1
        UI.currentPage = newPage
        -- Request next page from server
        local slotDef = GetSelectedSlotDef()
        if slotDef and slotDef.visualSlot then
            local searchText = UI.searchText
            if searchText and searchText ~= "" then
                if DC and DC.SearchTransmogItems then
                    DC:SearchTransmogItems(slotDef.visualSlot, searchText, newPage)
                end
            else
                if DC and DC.RequestTransmogSlotItems then
                    DC:RequestTransmogSlotItems(slotDef.visualSlot, newPage)
                end
            end
        end
    end)
    frame.nextBtn = nextBtn

    local pageText = right:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pageText:SetPoint("LEFT", nextBtn, "RIGHT", 8, 0)
    pageText:SetText("Page 1")
    frame.pageText = pageText

    local applyBtn = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    applyBtn:SetSize(60, 20)
    applyBtn:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 10)
    applyBtn:SetText("Apply")
    applyBtn:SetScript("OnClick", function() ApplySelectedAppearance() end)

    local clearBtn = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    clearBtn:SetSize(60, 20)
    clearBtn:SetPoint("RIGHT", applyBtn, "LEFT", -6, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function() ClearSelectedSlot() end)

    local outfitsBtn = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    outfitsBtn:SetSize(60, 20)
    outfitsBtn:SetPoint("RIGHT", clearBtn, "LEFT", -6, 0)
    outfitsBtn:SetText("Outfits")
    outfitsBtn:SetScript("OnClick", function()
        if not DC.ShowOutfitMenu then
            return
        end
        local menu = {}
        DC:ShowOutfitMenu(menu)
        table.insert(menu, { text = SafeGetText("CANCEL", "Cancel"), notCheckable = true })
        local dropdown = CreateFrame("Frame", "DCCollectionCharacterTransmogOutfitsMenu", UIParent, "UIDropDownMenuTemplate")
        EasyMenu(menu, dropdown, "cursor", 0, 0, "MENU")
    end)

    UI.frame = frame

    -- Default slot
    UI.selectedSlotKey = SLOT_ORDER[1].key
    UI.searchText = ""
    UI.page = 1

    SelectSlot(UI.selectedSlotKey)
    UpdateEquippedHeader()
    UpdateGrid()

    return frame
end

local function HideDefaultCharacterFrames()
    local frames = {
        "PaperDollFrame",
        "PetPaperDollFrame",
        "HonorFrame",
        "ReputationFrame",
        "SkillFrame",
        "TokenFrame",
    }

    for _, name in ipairs(frames) do
        local f = _G[name]
        if f and f.Hide then
            f:Hide()
        end
    end
end

local function ShowTransmogPanel()
    EnsureDataLoaded()

    local panel = CreateTransmogPanel()
    if not panel then
        return
    end

    HideDefaultCharacterFrames()

    panel:Show()

    ModelResetToPlayer(panel.model)

    -- Refresh button visuals (equipped icons + applied glow)
    if panel.slotButtons then
        for _, b in ipairs(panel.slotButtons) do
            UpdateSlotButtonVisual(b)
        end
    end

    UpdateEquippedHeader()

    UpdateGrid()
end

local function CreateCharacterFrameTab()
    if not CharacterFrame then
        return
    end

    if UI.characterTab then
        return
    end

    local numTabs = CharacterFrame.numTabs or 5
    local tabIndex = numTabs + 1
    while _G["CharacterFrameTab" .. tabIndex] do
        tabIndex = tabIndex + 1
    end

    local tabName = "CharacterFrameTab" .. tabIndex
    local tab = CreateFrame("Button", tabName, CharacterFrame, "CharacterFrameTabButtonTemplate")
    tab:SetID(tabIndex)
    tab:SetText(SafeGetText("TAB_TRANSMOG", "Transmog"))

    local prev = _G["CharacterFrameTab" .. (tabIndex - 1)]
    if prev then
        tab:SetPoint("LEFT", prev, "RIGHT", -16, 0)
    else
        tab:SetPoint("TOPLEFT", CharacterFrame, "BOTTOMLEFT", 0, 2)
    end

    PanelTemplates_SetNumTabs(CharacterFrame, tabIndex)
    PanelTemplates_EnableTab(CharacterFrame, tabIndex)

    CharacterFrame.numTabs = tabIndex

    tab:SetScript("OnClick", function(self)
        PanelTemplates_SetTab(CharacterFrame, self:GetID())
        ShowTransmogPanel()
    end)

    -- When any other tab is clicked, hide our panel.
    hooksecurefunc("CharacterFrameTab_OnClick", function(clicked)
        if clicked and clicked:GetName() == tab:GetName() then
            return
        end
        if UI.frame then
            UI.frame:Hide()
        end
    end)

    UI.characterTab = tab
end

local function OnEvent(self, event)
    if event == "PLAYER_LOGIN" then
        CreateCharacterFrameTab()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
        if UI.frame and UI.frame:IsShown() and UI.frame.slotButtons then
            for _, b in ipairs(UI.frame.slotButtons) do
                UpdateSlotButtonVisual(b)
            end
        end

        if UI.frame and UI.frame:IsShown() then
            UpdateEquippedHeader()
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:SetScript("OnEvent", OnEvent)
