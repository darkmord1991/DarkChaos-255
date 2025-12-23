--[[
    DC-Collection UI/Wardrobe/WardrobeItems.lua
    ==========================================

    Items tab: tab switching, slot selection, appearance list building,
    grid refresh, preview/apply, and model/slot-button updates.
]]

local DC = DCCollection
if not DC then return end

DC.Wardrobe = DC.Wardrobe or {}
local Wardrobe = DC.Wardrobe

-- ============================================================================
-- TAB SWITCHING
-- ============================================================================

function Wardrobe:SelectTab(tabKey)
    self.currentTab = tabKey
    self.currentPage = 1

    if self.frame and self.frame.tabButtons then
        for _, tab in ipairs(self.frame.tabButtons) do
            if tab.key == tabKey then
                tab.selected:Show()
                tab.text:SetTextColor(1, 0.82, 0)
            else
                tab.selected:Hide()
                tab.text:SetTextColor(1, 1, 1)
            end
        end
    end

    if tabKey == "items" then
        self:ShowItemsContent()
    elseif tabKey == "sets" then
        self:ShowSetsContent()
    elseif tabKey == "outfits" then
        self:ShowOutfitsContent()
    end
end

function Wardrobe:ShowItemsContent()
    if self.frame then
        for _, btn in ipairs(self.frame.slotFilterButtons or {}) do
            btn:Show()
        end
        if self.frame.collectedFrame then
            self.frame.collectedFrame:Show()
        end
        if self.frame.gridFrame then
            self.frame.gridFrame:Show()
        end
    end
    self:RefreshGrid()
end

function Wardrobe:ShowSetsContent()
    if self.frame then
        for _, btn in ipairs(self.frame.slotFilterButtons or {}) do
            btn:Hide()
        end
    end
    self:RefreshSetsGrid()
end

function Wardrobe:ShowOutfitsContent()
    if self.frame then
        for _, btn in ipairs(self.frame.slotFilterButtons or {}) do
            btn:Hide()
        end
    end
    self:RefreshOutfitsGrid()
end

-- ============================================================================
-- SLOT SELECTION
-- ============================================================================

function Wardrobe:SelectSlot(slotDef)
    self.selectedSlot = slotDef
    self.currentPage = 1

    if self.frame and self.frame.slotButtons then
        for _, btn in ipairs(self.frame.slotButtons) do
            if btn.slotDef == slotDef then
                btn.highlight:Show()
            else
                btn.highlight:Hide()
            end
        end
    end

    for i, filter in ipairs(self.SLOT_FILTERS or {}) do
        if filter.invTypes[slotDef.invType] then
            self.selectedSlotFilter = filter
            if self.frame and self.frame.slotFilterButtons then
                for j, btn in ipairs(self.frame.slotFilterButtons) do
                    if j == i then
                        btn.selected:Show()
                    else
                        btn.selected:Hide()
                    end
                end
            end
            break
        end
    end

    self:RefreshGrid()
end

-- ============================================================================
-- GRID REFRESH
-- ============================================================================

function Wardrobe:RefreshGrid()
    if not self.frame then return end

    local list = self:BuildAppearanceList()
    self.appearanceList = list

    local total = #list
    self.totalPages = math.max(1, math.ceil(total / self.ITEMS_PER_PAGE))
    if self.currentPage > self.totalPages then
        self.currentPage = self.totalPages
    end

    local collected = 0
    for _, item in ipairs(list) do
        if item.collected then
            collected = collected + 1
        end
    end
    self.collectedCount = collected
    self.totalCount = total

    if self.frame.collectedFrame then
        self.frame.collectedFrame.text:SetText(string.format("Collected %d / %d", collected, total))
        local pct = total > 0 and (collected / total) or 0
        self.frame.collectedFrame.bar:SetValue(pct)
    end

    if self.frame.pageText then
        self.frame.pageText:SetText(string.format("Page %d / %d", self.currentPage, self.totalPages))
    end

    if self.frame.prevBtn then
        if self.currentPage > 1 then
            self.frame.prevBtn:Enable()
        else
            self.frame.prevBtn:Disable()
        end
    end
    if self.frame.nextBtn then
        if self.currentPage < self.totalPages then
            self.frame.nextBtn:Enable()
        else
            self.frame.nextBtn:Disable()
        end
    end

    local startIdx = (self.currentPage - 1) * self.ITEMS_PER_PAGE + 1

    for i, btn in ipairs(self.frame.gridButtons) do
        local idx = startIdx + (i - 1)
        local item = list[idx]

        if item then
            btn:Show()
            btn.itemData = item

            local icon = nil
            if type(GetItemIcon) == "function" and item.itemId then
                icon = GetItemIcon(item.itemId)
            end
            if not icon and item.itemId and GetItemInfo then
                icon = select(10, GetItemInfo(item.itemId))
            end

            btn.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")

            if item.collected then
                btn.icon:SetVertexColor(1, 1, 1)
                btn.notCollected:Hide()
            else
                btn.icon:SetVertexColor(0.4, 0.4, 0.4)
                btn.notCollected:Show()
            end

            if btn.wishOverlay then
                if (not item.collected) and self:IsWishlistedTransmog(item.itemId) then
                    btn.wishOverlay:Show()
                else
                    btn.wishOverlay:Hide()
                end
            end
        else
            btn:Hide()
            btn.itemData = nil
        end
    end
end

function Wardrobe:BuildAppearanceList()
    local results = {}
    local defs = (DC.definitions and (DC.definitions.transmog or DC.definitions.wardrobe)) or {}
    local col = (DC.collections and (DC.collections.transmog or DC.collections.wardrobe)) or {}

    local seenDisplayIds = {}

    local search = self.searchText
    if search and search ~= "" then
        search = string.lower(search)
    else
        search = nil
    end

    for id, def in pairs(defs) do
        local valid = true

        if self.selectedSlotFilter then
            local invType = def.inventoryType or 0
            if not self.selectedSlotFilter.invTypes[invType] then
                valid = false
            end
        end

        if valid and search then
            local name = def.name or ""
            if not string.find(string.lower(name), search, 1, true) then
                valid = false
            end
        end

        if valid then
            local displayId = def.displayId or def.display_id
            local key = displayId or def.name

            if not seenDisplayIds[key] then
                seenDisplayIds[key] = true

                local collected = col[id] ~= nil
                if self.showUncollected or collected then
                    table.insert(results, {
                        id = id,
                        itemId = def.itemId or id,
                        name = def.name or "",
                        collected = collected,
                        inventoryType = def.inventoryType or 0,
                        displayId = displayId,
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

-- ============================================================================
-- PREVIEW & APPLY
-- ============================================================================

function Wardrobe:PreviewAppearance(itemId)
    if not itemId or not self.frame or not self.frame.model then return end

    local model = self.frame.model
    model:SetUnit("player")

    if model.TryOn then
        model:TryOn(itemId)
    end
end

function Wardrobe:ApplyAppearance(itemId)
    if not itemId then return end

    local slot = self.selectedSlot
    if not slot then
        if DC and DC.Print then
            DC:Print("Please select an equipment slot first.")
        end
        return
    end

    local invSlotId = GetInventorySlotInfo(slot.key)
    if not invSlotId then return end

    if not GetInventoryItemID("player", invSlotId) then
        if DC and DC.Print then
            DC:Print("No item equipped in that slot.")
        end
        return
    end

    if DC and DC.RequestSetTransmog then
        DC:RequestSetTransmog(invSlotId, itemId)
    end
end

-- ============================================================================
-- MODEL UPDATE
-- ============================================================================

function Wardrobe:UpdateModel()
    if not self.frame or not self.frame.model then return end

    local model = self.frame.model
    model:SetUnit("player")

    if self.transmogDisabled then
        model:Undress()
    end
end

-- ============================================================================
-- UPDATE SLOT BUTTONS
-- ============================================================================

function Wardrobe:UpdateSlotButtons()
    if not self.frame or not self.frame.slotButtons then return end

    for _, btn in ipairs(self.frame.slotButtons) do
        local slotDef = btn.slotDef
        local invSlotId = GetInventorySlotInfo(slotDef.key)

        btn.icon:SetTexture(self:GetSlotIcon(slotDef.key))

        local eqSlot = invSlotId and (invSlotId - 1)
        local state = DC.transmogState or {}
        local applied = eqSlot and state[tostring(eqSlot)] and tonumber(state[tostring(eqSlot)]) ~= 0

        if applied then
            btn.transmogApplied:Show()
        else
            btn.transmogApplied:Hide()
        end
    end
end
