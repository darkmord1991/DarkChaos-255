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

    local totalShown = #list
    self.totalPages = math.max(1, math.ceil(totalShown / self.ITEMS_PER_PAGE))
    if self.currentPage > self.totalPages then
        self.currentPage = self.totalPages
    end

    -- Counts should reflect the full matched set (slot/search), not just displayed rows.
    local collected = self.collectedCount or 0
    local total = self.totalCount or 0

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

            -- If we can't resolve an icon (often because itemId is not a real item),
            -- show an empty slot rather than a question mark.
            if icon and icon ~= "" then
                btn.icon:SetTexture(icon)
                if btn.icon.Show then btn.icon:Show() end
            else
                btn.icon:SetTexture(nil)
                if btn.icon.Hide then btn.icon:Hide() end
            end

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

local _EQUIPLOC_TO_INVTYPE = {
    INVTYPE_HEAD = 1,
    INVTYPE_NECK = 2,
    INVTYPE_SHOULDER = 3,
    INVTYPE_BODY = 4,
    INVTYPE_CHEST = 5,
    INVTYPE_ROBE = 20,
    INVTYPE_WAIST = 6,
    INVTYPE_LEGS = 7,
    INVTYPE_FEET = 8,
    INVTYPE_WRIST = 9,
    INVTYPE_HAND = 10,
    INVTYPE_FINGER = 11,
    INVTYPE_TRINKET = 12,
    INVTYPE_CLOAK = 16,
    INVTYPE_TABARD = 19,
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

function Wardrobe:InferInventoryTypeFromItemId(itemId)
    if not itemId or not GetItemInfo then
        return nil
    end

    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemId)
    if not equipLoc or equipLoc == "" then
        return nil
    end

    return _EQUIPLOC_TO_INVTYPE[equipLoc]
end

function Wardrobe:BuildAppearanceList()
    local results = {}
    local defs = (DC.definitions and (DC.definitions.transmog or DC.definitions.wardrobe)) or {}
    local col = (DC.collections and (DC.collections.transmog or DC.collections.wardrobe)) or {}

    local seenKeys = {}
    local totalMatched = 0
    local collectedMatched = 0

    local search = self.searchText
    if search and search ~= "" then
        search = string.lower(search)
    else
        search = nil
    end

    for id, def in pairs(defs) do
        local valid = true

        local displayId = def.displayId or def.displayID or def.display_id or def.appearanceId or def.appearance_id
        if type(displayId) == "string" then
            displayId = tonumber(displayId)
        end

        -- Prefer explicit itemId if present; fall back to the definition key only if it looks numeric.
        local itemId = def.itemId or def.item_id or def.item
        if type(itemId) == "string" then
            itemId = tonumber(itemId)
        end
        if not itemId and type(id) == "number" then
            itemId = id
        elseif not itemId and type(id) == "string" then
            itemId = tonumber(id)
        end

        local invType = def.inventoryType or def.inventory_type or def.invType or def.inv_type
        if type(invType) == "string" then
            invType = tonumber(invType)
        end
        invType = invType or 0

        -- Fallback: if server didn't send inventoryType, infer it from the item.
        if invType == 0 and itemId then
            invType = self:InferInventoryTypeFromItemId(itemId) or invType
        end

        if self.selectedSlotFilter then
            -- If inventoryType is unknown (0), keep it visible instead of silently filtering it out.
            if invType ~= 0 and not self.selectedSlotFilter.invTypes[invType] then
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
            local key = displayId
            if not key then
                key = (type(itemId) == "number" and itemId) or (type(id) == "number" and id) or tostring(id)
            end

            if not seenKeys[key] then
                seenKeys[key] = true

                -- Collections and definitions don't always use the same key (some servers key by displayId).
                local collected = col[id] ~= nil
                if not collected and displayId then
                    collected = col[displayId] ~= nil
                end

                totalMatched = totalMatched + 1
                if collected then
                    collectedMatched = collectedMatched + 1
                end

                if self.showUncollected or collected then
                    table.insert(results, {
                        id = id,
                        itemId = itemId,
                        name = def.name or "",
                        collected = collected,
                        inventoryType = invType,
                        displayId = displayId,
                    })
                end
            end
        end
    end

    -- Store counts for UI even when uncollected are hidden.
    self.totalCount = totalMatched
    self.collectedCount = collectedMatched

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
        -- Prefer a link form; it tends to be more reliable for cached/uncached items.
        local link = "item:" .. tostring(itemId) .. ":0:0:0:0:0:0:0"
        model:TryOn(link)
    end
end

function Wardrobe:ShowAppearanceContextMenu(appearance)
    if not appearance then
        return
    end

    local menu = {
        { text = appearance.name or "Appearance", isTitle = true, notCheckable = true },
        {
            text = "Preview",
            notCheckable = true,
            func = function()
                if appearance.itemId then
                    Wardrobe:PreviewAppearance(appearance.itemId)
                end
            end,
        },
    }

    if not appearance.collected then
        table.insert(menu, {
            text = (DC.L and (DC.L["ADD_TO_WISHLIST"] or DC.L["WISHLIST"])) or "Add to wishlist",
            notCheckable = true,
            func = function()
                if DC and DC.RequestAddWishlist and appearance.itemId then
                    DC:RequestAddWishlist("transmog", appearance.itemId)
                end
            end,
        })
    else
        table.insert(menu, {
            text = "Apply",
            notCheckable = true,
            func = function()
                if appearance.itemId then
                    Wardrobe:ApplyAppearance(appearance.itemId)
                end
            end,
        })
    end

    table.insert(menu, { text = (DC.L and DC.L["CANCEL"]) or "Cancel", notCheckable = true })

    local dropdown = CreateFrame("Frame", "DCWardrobeContextMenu", UIParent, "UIDropDownMenuTemplate")
    EasyMenu(menu, dropdown, "cursor", 0, 0, "MENU")
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
