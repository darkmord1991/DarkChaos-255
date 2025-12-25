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
        if self.frame.showUncollectedCheck then
            self.frame.showUncollectedCheck:Show()
        end
        if self.frame.gridFrame then
            self.frame.gridFrame:Show()
        end
        if self.frame.modelPanel then
            self.frame.modelPanel:Show()
        end
    end
    self:RefreshGrid()
end

function Wardrobe:ShowSetsContent()
    if self.frame then
        for _, btn in ipairs(self.frame.slotFilterButtons or {}) do
            btn:Hide()
        end
        if self.frame.modelPanel then
            self.frame.modelPanel:Show()
        end
    end
    self:RefreshSetsGrid()
end

function Wardrobe:ShowOutfitsContent()
    if self.frame then
        for _, btn in ipairs(self.frame.slotFilterButtons or {}) do
            btn:Hide()
        end
        if self.frame.collectedFrame then
            self.frame.collectedFrame:Hide()
        end
        if self.frame.showUncollectedCheck then
            self.frame.showUncollectedCheck:Hide()
        end
        if self.frame.modelPanel then
            self.frame.modelPanel:Show()
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
    self.selectedAppearanceItemId = nil

    if self.frame and self.frame.slotButtons then
        for _, btn in ipairs(self.frame.slotButtons) do
            if btn.slotDef == slotDef then
                btn.highlight:Show()
            else
                btn.highlight:Hide()
            end
        end
    end

    -- Apply per-slot camera positioning for optimal preview
    if self.frame and self.frame.model and slotDef then
        -- Cache camera position per slot to avoid repeated lookups
        if not self.cachedCameraPositions then
            self.cachedCameraPositions = {}
        end
        
        local cameraPos = self.cachedCameraPositions[slotDef.label]
        if not cameraPos then
            cameraPos = self:GetCameraPosition(slotDef.label)
            self.cachedCameraPositions[slotDef.label] = cameraPos
        end
        
        if cameraPos then
            local model = self.frame.model
            
            -- Store camera position in model for zoom functionality
            model.cameraX = cameraPos.x
            model.cameraY = cameraPos.y
            model.cameraZ = cameraPos.z
            model.cameraDistance = 1.0 -- Reset zoom on slot change
            
            -- Apply position
            self:ApplyCameraPosition(model, cameraPos)
            
            -- Reset rotation to facing angle for this slot
            if model.SetFacing then
                model:SetFacing(cameraPos.facing)
                model.rotation = cameraPos.facing
            end
        end
    end

    -- Update slot filter based on selected slot
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

    self:BuildAppearanceList()
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

            if btn.selected then
                if self.selectedAppearanceItemId and item.itemId == self.selectedAppearanceItemId then
                    btn.selected:Show()
                else
                    btn.selected:Hide()
                end
            end

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
    
    -- Preload items from adjacent pages to cache them in advance
    self:PreloadAdjacentPages(list)
end

-- Preload item data for previous and next pages
function Wardrobe:PreloadAdjacentPages(list)
    if not list or not GetItemInfo then return end
    
    local startIdxPrev = (self.currentPage - 2) * self.ITEMS_PER_PAGE + 1
    local endIdxPrev = startIdxPrev + self.ITEMS_PER_PAGE - 1
    
    local startIdxNext = self.currentPage * self.ITEMS_PER_PAGE + 1
    local endIdxNext = startIdxNext + self.ITEMS_PER_PAGE - 1
    
    -- Preload previous page
    if self.currentPage > 1 then
        for i = startIdxPrev, endIdxPrev do
            local item = list[i]
            if item and item.itemId then
                -- Just calling GetItemInfo triggers the cache
                GetItemInfo(item.itemId)
            end
        end
    end
    
    -- Preload next page
    if self.currentPage < self.totalPages then
        for i = startIdxNext, endIdxNext do
            local item = list[i]
            if item and item.itemId then
                -- Just calling GetItemInfo triggers the cache
                GetItemInfo(item.itemId)
            end
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
    INVTYPE_THROWN = 25,
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

    -- For transmog we want to show unique appearances, not one entry per item.
    -- Servers can send multiple items sharing the same appearance (displayId) and
    -- Lua's pairs() iteration order is arbitrary. Track the "best" representative
    -- per appearance so we don't end up showing only low-level/low-quality items.
    local byKey = {}

    local search = self.searchText
    local searchNum = nil
    if search and search ~= "" then
        search = string.lower(search)
        searchNum = tonumber(search)
    else
        search = nil
        searchNum = nil
    end

    local function GetItemScore(itemId)
        -- Higher score is "better". Prefer quality, then item level.
        if not itemId or type(GetItemInfo) ~= "function" then
            return 0, 0
        end
        local _, _, quality, itemLevel = GetItemInfo(itemId)
        return tonumber(quality) or 0, tonumber(itemLevel) or 0
    end

    local function IsBetterRepresentative(newItemId, oldItemId)
        if not oldItemId then
            return true
        end
        if not newItemId then
            return false
        end
        local nq, nl = GetItemScore(newItemId)
        local oq, ol = GetItemScore(oldItemId)
        if nq ~= oq then
            return nq > oq
        end
        if nl ~= ol then
            return nl > ol
        end
        return (tonumber(newItemId) or 0) > (tonumber(oldItemId) or 0)
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

        -- Quality filtering
        if valid and self.selectedQualityFilter and self.selectedQualityFilter > 0 then
            -- Server definitions commonly use "rarity" (and some use "quality").
            -- Fall back to the client item cache (GetItemInfo) if the definition is missing it.
            local quality = def.quality
                or def.Quality
                or def.rarity
                or def.Rarity
                or def.itemQuality
                or def.item_quality
                or 0
            if type(quality) == "string" then quality = tonumber(quality) end
            quality = tonumber(quality) or 0

            if quality <= 0 and itemId and GetItemInfo then
                local _, _, itemQuality = GetItemInfo(itemId)
                if itemQuality then
                    quality = tonumber(itemQuality) or quality
                end
            end
            if quality < self.selectedQualityFilter then
                valid = false
            end
        end

        if valid and search then
            local matchFound = false
            
            -- Check name match
            local name = def.name or ""
            if string.find(string.lower(name), search, 1, true) then
                matchFound = true
            end
            
            -- Check itemID match (if search is numeric)
            if not matchFound and searchNum and itemId then
                if tostring(itemId):find(tostring(searchNum), 1, true) then
                    matchFound = true
                end
            end
            
            -- Check displayID match (if search is numeric)
            if not matchFound and searchNum and displayId then
                if tostring(displayId):find(tostring(searchNum), 1, true) then
                    matchFound = true
                end
            end
            
            if not matchFound then
                valid = false
            end
        end

        if valid then
            -- Avoid collisions across slots: some datasets reuse displayId across different invTypes.
            local key
            if displayId then
                key = tostring(invType or 0) .. ":" .. tostring(displayId)
            else
                key = tostring(invType or 0) .. ":" .. tostring((type(itemId) == "number" and itemId) or (type(id) == "number" and id) or tostring(id))
            end

            -- Collections and definitions don't always use the same key (some servers key by displayId).
            local collected = col[id] ~= nil
            if not collected and displayId then
                collected = col[displayId] ~= nil
            end

            local existing = byKey[key]
            if not existing then
                local itemIds = def.itemIds or def.item_ids
                local itemIdsTotal = def.itemIdsTotal or def.item_ids_total or def.itemIds_count or def.itemIdsCount

                byKey[key] = {
                    id = id,
                    itemId = itemId,
                    name = def.name or "",
                    collected = collected,
                    inventoryType = invType,
                    displayId = displayId,
                    itemIds = itemIds,
                    itemIdsTotal = itemIdsTotal,
                }
            else
                -- If any variant is collected, mark collected.
                if collected then
                    existing.collected = true
                end

                if not existing.itemIds and (def.itemIds or def.item_ids) then
                    existing.itemIds = def.itemIds or def.item_ids
                end
                if not existing.itemIdsTotal and (def.itemIdsTotal or def.item_ids_total or def.itemIdsCount or def.itemIds_count) then
                    existing.itemIdsTotal = def.itemIdsTotal or def.item_ids_total or def.itemIdsCount or def.itemIds_count
                end
                -- Prefer a better representative itemId for the tooltip/model preview.
                if IsBetterRepresentative(itemId, existing.itemId) then
                    existing.id = id
                    existing.itemId = itemId
                    existing.name = (def.name or existing.name or "")
                    existing.inventoryType = invType
                    existing.displayId = displayId
                end
            end
        end
    end

    local totalMatched = 0
    local collectedMatched = 0
    for _, entry in pairs(byKey) do
        totalMatched = totalMatched + 1
        if entry.collected then
            collectedMatched = collectedMatched + 1
        end
        if self.showUncollected or entry.collected then
            table.insert(results, entry)
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
    
    -- Validate item exists and has data cached
    local itemName, itemLink = GetItemInfo(itemId)
    if not itemName then
        -- Item not cached yet, queue for later
        if not self.pendingPreviews then
            self.pendingPreviews = {}
        end
        self.pendingPreviews[itemId] = true
        return
    end

    self.selectedAppearanceItemId = itemId

    local model = self.frame.model
    
    -- Reset model to player with all current equipment
    model:SetUnit("player")
    
    -- Only preview the specific slot if one is selected
    if self.selectedSlot and model.Undress and model.TryOn then
        -- Undress only the selected slot, keep everything else
        model:Undress()
        
        -- Re-apply all equipped items (with error protection)
        for slot = 1, 19 do
            local itemID = GetInventoryItemID("player", slot)
            if itemID then
                pcall(function()
                    local link = "item:" .. tostring(itemID) .. ":0:0:0:0:0:0:0"
                    model:TryOn(link)
                end)
            end
        end
        
        -- Now try on ONLY the selected slot's new appearance (with error protection)
        pcall(function()
            local link = "item:" .. tostring(itemId) .. ":0:0:0:0:0:0:0"
            model:TryOn(link)
        end)
    else
        -- Fallback: full character preview (with error protection)
        if model.TryOn then
            pcall(function()
                local link = "item:" .. tostring(itemId) .. ":0:0:0:0:0:0:0"
                model:TryOn(link)
            end)
        end
    end
    
    -- Apply slot-specific camera positioning if a slot is selected
    if self.selectedSlot then
        -- Use cached position if available
        if not self.cachedCameraPositions then
            self.cachedCameraPositions = {}
        end
        
        local cameraPos = self.cachedCameraPositions[self.selectedSlot.label]
        if not cameraPos then
            cameraPos = self:GetCameraPosition(self.selectedSlot.label)
            self.cachedCameraPositions[self.selectedSlot.label] = cameraPos
        end
        
        if cameraPos then
            -- Store camera position for zoom
            model.cameraX = cameraPos.x
            model.cameraY = cameraPos.y
            model.cameraZ = cameraPos.z
            
            -- Apply with current zoom level
            local zoomedPos = {
                x = cameraPos.x * (model.cameraDistance or 1.0),
                y = cameraPos.y,
                z = cameraPos.z,
                facing = cameraPos.facing
            }
            self:ApplyCameraPosition(model, zoomedPos)
        end
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
                Wardrobe:ApplyAppearance(appearance)
            end,
        })
    end

    table.insert(menu, { text = (DC.L and DC.L["CANCEL"]) or "Cancel", notCheckable = true })

    local dropdown = CreateFrame("Frame", "DCWardrobeContextMenu", UIParent, "UIDropDownMenuTemplate")
    EasyMenu(menu, dropdown, "cursor", 0, 0, "MENU")
end

function Wardrobe:ApplyAppearance(appearance)
    if not appearance then return end

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

    local appearanceId = appearance.displayId or appearance.appearanceId or appearance.appearance_id
    if type(appearanceId) == "string" then
        appearanceId = tonumber(appearanceId)
    end

    -- Fallback for older servers that expect itemId.
    if not appearanceId then
        appearanceId = appearance.itemId
    end

    if DC and DC.RequestSetTransmog then
        DC:RequestSetTransmog(invSlotId, appearanceId)
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
