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

    -- The shared item pager (created in WardrobeUI) is only for Items/Sets.
    -- Outfits/Community have their own paging controls.
    if self.frame and self.frame.pageFrame then
        if tabKey == "outfits" or tabKey == "community" then
            self.frame.pageFrame:Hide()
        else
            self.frame.pageFrame:Show()
        end
    end

    if type(self.UpdateRefreshButtonForTab) == "function" then
        self:UpdateRefreshButtonForTab()
    end

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
        if self.ShowOutfitsContent then
            self:ShowOutfitsContent()
        end
    elseif tabKey == "community" then
        self:ShowCommunityContent()
    end

    if self.frame then
        if self.isEmbedded and type(self._ApplyEmbeddedLayout) == "function" then
            self:_ApplyEmbeddedLayout()
        elseif not self.isEmbedded and type(self._ApplyStandaloneLayout) == "function" then
            self:_ApplyStandaloneLayout()
        end

        if tabKey == "outfits" and type(self.frame.LayoutOutfitButtons) == "function" then
            self.frame.LayoutOutfitButtons()
        end
    end
end

function Wardrobe:ShowItemsContent()
    if self.frame then
        if self.frame.modelTitle then self.frame.modelTitle:SetText("") end
        if self.frame.communityHost then self.frame.communityHost:Hide() end
        if DC and DC.CommunityUI and DC.CommunityUI.frame then
            DC.CommunityUI.frame:Hide()
        end
        if self.frame.outfitGridContainer then self.frame.outfitGridContainer:Hide() end
        if self.frame.communityGridContainer then self.frame.communityGridContainer:Hide() end
        if self.frame.communityMineCheck then self.frame.communityMineCheck:Hide() end

        -- Show Save button in Items tab so users can save their current look
        if self.frame.newOutfitBtn then self.frame.newOutfitBtn:Show() end
        if self.frame.randomOutfitBtn then self.frame.randomOutfitBtn:Hide() end

        if self.frame.orderBtn then self.frame.orderBtn:Show() end
        if self.frame.filterBtn then self.frame.filterBtn:Show() end
        if self.frame.qualityDropdown then self.frame.qualityDropdown:Show() end
        if self.frame.searchBox then self.frame.searchBox:Show() end
        if self.frame.gridContainer then self.frame.gridContainer:Show() end

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
        -- Preview Mode Frame is now handled globally in WardrobeUI
        if self.frame.previewModeFrame then
             self.frame.previewModeFrame:Show()
        end
    end
    self:RefreshGrid()
end

function Wardrobe:ShowSetsContent()
    if self.frame then
        if self.frame.modelTitle then self.frame.modelTitle:SetText("") end
        if self.frame.communityHost then self.frame.communityHost:Hide() end
        if DC and DC.CommunityUI and DC.CommunityUI.frame then
            DC.CommunityUI.frame:Hide()
        end
        if self.frame.outfitGridContainer then self.frame.outfitGridContainer:Hide() end
        if self.frame.communityGridContainer then self.frame.communityGridContainer:Hide() end
        if self.frame.communityMineCheck then self.frame.communityMineCheck:Hide() end
        
        -- Hide Outfit Controls
        if self.frame.newOutfitBtn then self.frame.newOutfitBtn:Hide() end
        if self.frame.randomOutfitBtn then self.frame.randomOutfitBtn:Hide() end

        if self.frame.orderBtn then self.frame.orderBtn:Show() end
        if self.frame.filterBtn then self.frame.filterBtn:Show() end
        if self.frame.qualityDropdown then self.frame.qualityDropdown:Show() end
        if self.frame.searchBox then self.frame.searchBox:Show() end
        if self.frame.gridContainer then self.frame.gridContainer:Show() end
        if self.frame.gridFrame then self.frame.gridFrame:Show() end

        for _, btn in ipairs(self.frame.slotFilterButtons or {}) do
            btn:Hide()
        end

        -- Outfits/Community hide the collected bar; Sets uses it for progress.
        if self.frame.collectedFrame then
            self.frame.collectedFrame:Show()
        end
        -- "Show uncollected" is an Items-only filter.
        if self.frame.showUncollectedCheck then
            self.frame.showUncollectedCheck:Hide()
        end

        if self.frame.modelPanel then
            self.frame.modelPanel:Show()
        end
        -- Preview Mode Frame is now handled globally in WardrobeUI
        if self.frame.previewModeFrame then
             self.frame.previewModeFrame:Show()
        end
    end
    if DC and DC.RequestItemSets then
        DC:RequestItemSets()
    end
    self:RefreshSetsGrid()
end

-- Legacy ShowCommunityContent removed - see WardrobeCommunity.lua

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

    -- Frame the model on the selected slot (absolute reset of zoom/pan/rotation).
    if self.frame and self.frame.model and slotDef then
        self:SetModelCameraFromSlot(self.frame.model, slotDef.label)
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

    -- Under the native source-paged path RefreshGrid queries the page itself;
    -- skip the redundant full-list build (which would defeat source-paging).
    if not (type(DC.HasNativeTransmogCatalog) == "function" and
            DC:HasNativeTransmogCatalog()) then
        self:BuildAppearanceList()
    end
    self:RefreshGrid()
end

-- ============================================================================
-- GRID REFRESH
-- ============================================================================

-- ============================================================================
-- 3D GRID PREVIEW (live model per cell, mirrors AppearanceBuddy's PreviewList)
-- ============================================================================

-- How far to push the camera back for a tiny grid cell vs the big left-panel
-- model. CameraDB x values are tuned for the 250px model; cells are ~46px, so
-- we zoom out. Tunable; raise to make cell models smaller.
Wardrobe.GRID_CELL_ZOOMOUT_X = Wardrobe.GRID_CELL_ZOOMOUT_X or 1.3

-- Map a server inventoryType to a CameraDB slot key.
local _INVTYPE_TO_CAMSLOT = {
    [1] = "Head", [3] = "Shoulder", [4] = "Shirt", [5] = "Chest", [20] = "Chest",
    [19] = "Tabard", [6] = "Waist", [7] = "Legs", [8] = "Feet", [9] = "Wrist",
    [10] = "Hands", [16] = "Back",
    [13] = "MainHand", [21] = "MainHand", [17] = "MainHand",
    [14] = "OffHand", [22] = "OffHand", [23] = "OffHand",
    [15] = "Ranged", [26] = "Ranged", [25] = "Ranged", [28] = "Ranged",
}

function Wardrobe:_InvTypeToCamSlot(invType)
    return _INVTYPE_TO_CAMSLOT[tonumber(invType) or -1]
end

-- Best-effort weapon subclass key (for WeaponSubclassCamera framing offsets).
function Wardrobe:_GuessWeaponSubclass(itemId, invType)
    if tonumber(invType) == 17 then
        return "2H"  -- any two-hander
    end
    if itemId and type(GetItemInfo) == "function" then
        local _, _, _, _, _, _, subType = GetItemInfo(itemId)
        if type(subType) == "string" then
            local s = subType:lower()
            if s:find("stave") or s:find("staff") then return "Staff" end
            if s:find("polearm") then return "Polearm" end
            if s:find("crossbow") then return "Crossbow" end
            if s:find("bow") then return "Bow" end
            if s:find("gun") then return "Gun" end
            if s:find("dagger") then return "Dagger" end
            if s:find("wand") then return "Wand" end
            if s:find("fist") then return "Fist" end
            if s:find("shield") then return "Shield" end
            if s:find("two%-handed") then return "2H" end
        end
    end
    return nil
end

-- Lazily create the per-cell DressUpModel + a selection border that draws above
-- it (button textures render behind child frames, so the border must be a frame).
function Wardrobe:_EnsureGridPreviewModel(btn)
    if btn.previewModel then
        return btn.previewModel
    end

    local model = CreateFrame("DressUpModel", nil, btn)
    model:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
    model:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    model:EnableMouse(false)       -- let the underlying button get hover/click
    model:EnableMouseWheel(false)
    model:SetUnit("player")
    model._dcPreviewSequence = self.PREVIEW_IDLE_SEQUENCE or 0
    model:Hide()
    btn.previewModel = model

    local sel = CreateFrame("Frame", nil, btn)
    sel:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
    sel:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
    sel:SetFrameLevel(model:GetFrameLevel() + 1)
    sel:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
    })
    sel:SetBackdropBorderColor(1, 0.82, 0)
    sel:Hide()
    btn.previewSelect = sel

    return model
end

-- Dress one grid cell's model with `item`'s appearance and frame it.
function Wardrobe:_UpdateGridPreviewCell(btn, item)
    local model = btn.previewModel
    if not model then return end

    local previewUnit = Wardrobe.previewUnit or "player"
    if previewUnit == "target" and not UnitExists("target") then
        previewUnit = "player"
    end

    -- Framing slot: an explicitly selected slot wins; otherwise infer from item.
    local camLabel = (self.selectedSlot and self.selectedSlot.label)
        or self:_InvTypeToCamSlot(item.inventoryType)
        or "Chest"

    local isWeapon = (camLabel == "Main Hand" or camLabel == "MainHand"
        or camLabel == "Off Hand" or camLabel == "OffHand"
        or camLabel == "Ranged")

    -- Reset to the unit (restores body + gear), then strip for armor so we show
    -- just the piece. Weapons stay dressed so a 1H doesn't ghost into both hands.
    model:SetUnit(previewUnit)
    if not isWeapon and model.Undress then
        model:Undress()
    end

    local itemId = item.itemId
    if itemId then
        pcall(function()
            model:TryOn("item:" .. tostring(itemId) .. ":0:0:0:0:0:0:0")
        end)
    end

    local subclass = isWeapon and self:_GuessWeaponSubclass(itemId, item.inventoryType) or nil
    local pos = self:GetCameraPosition(camLabel, subclass)
    if model.SetPosition then
        model:SetPosition((pos.x or 1.0) + (self.GRID_CELL_ZOOMOUT_X or 1.3), pos.y or 0, pos.z or 0)
    end
    if model.SetFacing then
        model:SetFacing(pos.facing or 0)
    end
    if pos.sequence then
        model._dcPreviewSequence = pos.sequence
    end
    if type(self.StabilizePreviewModel) == "function" then
        self:StabilizePreviewModel(model, model._dcPreviewSequence)
    end

    -- Texture overlays sit behind the model; convey "uncollected" by dimming.
    if model.SetAlpha then
        model:SetAlpha(item.collected and 1.0 or 0.45)
    end
end

function Wardrobe:RefreshGrid()
    if not self.frame then return end

    -- The Sets/Outfits tabs repurpose the shared grid and overwrite button handlers.
    -- Always restore the Items handlers when rendering the items grid.
    local function ConfigureGridButtonForItems(btn)
        if not btn then
            return
        end

        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        btn:SetScript("OnClick", function(selfBtn, button)
            if not selfBtn.itemData then return end

            if IsShiftKeyDown and IsShiftKeyDown() then
                local itemId = selfBtn.itemData.itemId
                if not itemId then return end
                if DC and DC.RequestAddWishlist and DC.RequestRemoveWishlist then
                    if Wardrobe:IsWishlistedTransmog(itemId) then
                        DC:RequestRemoveWishlist("transmog", itemId)
                    else
                        DC:RequestAddWishlist("transmog", itemId)
                    end
                end
                return
            end

            if button == "LeftButton" then
                if selfBtn.itemData.itemId then
                    selfBtn.keepPreviewOnClick = true
                    Wardrobe:PreviewAppearance(selfBtn.itemData.itemId)
                    Wardrobe:ShowTooltipPreview(selfBtn.itemData.itemId)
                end
            else
                selfBtn.keepPreviewOnClick = false
                Wardrobe:HideTooltipPreview()
                Wardrobe:ShowAppearanceContextMenu(selfBtn.itemData)
            end
        end)

        btn:SetScript("OnEnter", function(selfBtn)
            if not selfBtn.itemData then return end

            if selfBtn.itemData.itemId then
                Wardrobe:ShowTooltipPreview(selfBtn.itemData.itemId)
            end

            Wardrobe:ShowFixedItemTooltip(selfBtn, selfBtn.itemData.itemId, function(tip)
                tip:AddLine(" ")

                if selfBtn.itemData.isHideOption then
                    tip:AddLine("|cffff6600Hide this equipment slot|r", 1, 1, 1)
                    tip:AddLine("The slot will appear empty", 0.7, 0.7, 0.7)
                elseif selfBtn.itemData.displayId then
                    tip:AddLine("DisplayId: " .. tostring(selfBtn.itemData.displayId), 0.85, 0.85, 0.85)
                end

                local ids = selfBtn.itemData.itemIds
                local idsTotal = selfBtn.itemData.itemIdsTotal
                if type(idsTotal) == "string" then idsTotal = tonumber(idsTotal) end
                if type(ids) == "table" and (#ids > 0 or idsTotal) then
                    local shown = {}
                    local maxShow = 10
                    local n = 0
                    for _, v in ipairs(ids) do
                        if n >= maxShow then break end
                        local iv = type(v) == "string" and tonumber(v) or v
                        if iv and not shown[iv] then
                            shown[iv] = true
                            n = n + 1
                        end
                    end

                    local list = {}
                    for iv in pairs(shown) do
                        table.insert(list, iv)
                    end
                    table.sort(list)

                    local line = "Variants: "
                    if #list > 0 then
                        for i = 1, #list do
                            if i > 1 then line = line .. ", " end
                            line = line .. tostring(list[i])
                        end
                    end

                    if idsTotal and idsTotal > #ids then
                        line = line .. string.format(" (+%d more)", (idsTotal - #ids))
                    end
                    tip:AddLine(line, 0.85, 0.85, 0.85)
                end

                if selfBtn.itemData.collected then
                    tip:AddLine("Appearance collected", 0.1, 1, 0.1)
                else
                    if Wardrobe:IsWishlistedTransmog(selfBtn.itemData.itemId) then
                        tip:AddLine("Wishlisted", 1, 0.82, 0)
                    end
                end
                tip:AddLine("Left-click to preview", 0.7, 0.7, 0.7)
                tip:AddLine("Right-click to apply or add to wishlist", 0.7, 0.7, 0.7)
                tip:AddLine("Shift-click to toggle wishlist", 0.7, 0.7, 0.7)
            end)
        end)

        btn:SetScript("OnLeave", function(selfBtn)
            GameTooltip:Hide()
            if Wardrobe.HideTooltipPreview then
                if not selfBtn.keepPreviewOnClick then
                    Wardrobe:HideTooltipPreview()
                end
            end
        end)
    end

    -- "Hide Slot" pseudo-entry for hideable slots (Head/Shoulder/Back/Chest).
    -- It occupies the first cell of page 1.
    local hideableSlots = {
        [1] = true,   -- Head
        [3] = true,   -- Shoulder
        [16] = true,  -- Back/Cloak
        [4] = true,   -- Chest
    }
    local hideOption = nil
    if self.selectedSlotFilter and type(self.selectedSlotFilter.invTypes) == "table" then
        for invType in pairs(self.selectedSlotFilter.invTypes) do
            if hideableSlots[invType] then
                hideOption = {
                    id = "hide",
                    itemId = 0,
                    name = "Hide Slot",
                    displayId = 0,
                    collected = true,
                    isHideOption = true,
                }
                break
            end
        end
    end
    local hideCount = hideOption and 1 or 0

    local list
    local startIdx
    local totalShown

    if type(DC.HasNativeTransmogCatalog) == "function" and
       DC:HasNativeTransmogCatalog() and
       type(QueryDCCollectionTransmog) == "function" then
        -- Source-paged: ask the DLL for only the current page of appearances so
        -- the full (~54k) catalog never materialises as Lua tables. The DLL
        -- returns the page plus the full matched/collected totals for paging.
        if type(DC._SyncNativeTransmogCollected) == "function" then
            DC:_SyncNativeTransmogCollected(false)
        end
        local invCsv, quality, searchStr, showUncollected, sortMode =
            self:_NativeTransmogQueryArgs()
        local perPage = self.ITEMS_PER_PAGE

        local function queryPage(pageIdx)
            local globalStart0 = (pageIdx - 1) * perPage
            local hideHere = (globalStart0 < hideCount)
            local matchedOffset = globalStart0 - hideCount
            if matchedOffset < 0 then matchedOffset = 0 end
            local need = perPage - (hideHere and 1 or 0)
            local ok, items, total, collected = pcall(QueryDCCollectionTransmog,
                invCsv, quality, searchStr, showUncollected, sortMode,
                matchedOffset, need)
            if not ok or type(items) ~= "table" then items = {} end
            return items, tonumber(total) or 0, tonumber(collected) or 0, hideHere
        end

        local items, totalMatched, collectedMatched, hideHere =
            queryPage(self.currentPage)
        totalShown = totalMatched + hideCount
        self.totalCount = totalMatched
        self.collectedCount = collectedMatched
        self.totalPages = math.max(1, math.ceil(totalShown / perPage))
        if self.currentPage > self.totalPages then
            self.currentPage = self.totalPages
            items, totalMatched, collectedMatched, hideHere =
                queryPage(self.currentPage)
            totalShown = totalMatched + hideCount
            self.totalCount = totalMatched
            self.collectedCount = collectedMatched
        end

        if hideHere and hideOption then
            list = { hideOption }
            for k = 1, #items do
                list[#list + 1] = items[k]
            end
        else
            list = items
        end
        self.appearanceList = list
        startIdx = 1
    else
        list = self:BuildAppearanceList()
        if hideOption then
            table.insert(list, 1, hideOption)
        end
        self.appearanceList = list
        totalShown = #list
        startIdx = (self.currentPage - 1) * self.ITEMS_PER_PAGE + 1
    end

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

    -- startIdx is set above: 1 for the source-paged native path (list is already
    -- the page), or the global slice offset for the legacy full-list path.

    for i, btn in ipairs(self.frame.gridButtons) do
        ConfigureGridButtonForItems(btn)
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

            local icon = item.icon
            if (not icon or icon == "") and type(GetItemIcon) == "function" and item.itemId then
                icon = GetItemIcon(item.itemId)
            end
            if (not icon or icon == "") and item.itemId and GetItemInfo then
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

            -- 3D preview mode: render the appearance on a live model in the cell.
            if Wardrobe.gridPreviewMode and item.itemId and not item.isHideOption then
                self:_EnsureGridPreviewModel(btn)
                if btn.icon and btn.icon.Hide then btn.icon:Hide() end
                if btn.notCollected then btn.notCollected:Hide() end
                if btn.wishOverlay then btn.wishOverlay:Hide() end
                btn.previewModel:Show()
                self:_UpdateGridPreviewCell(btn, item)
                if btn.previewSelect then
                    if self.selectedAppearanceItemId and item.itemId == self.selectedAppearanceItemId then
                        btn.previewSelect:Show()
                    else
                        btn.previewSelect:Hide()
                    end
                end
            else
                -- Icon mode (or hide-slot cell): hide any 3D leftovers. The icon
                -- block above already set the icon's correct shown/hidden state.
                if btn.previewModel then btn.previewModel:Hide() end
                if btn.previewSelect then btn.previewSelect:Hide() end
            end
        else
            btn:Hide()
            btn.itemData = nil
            if btn.previewModel then btn.previewModel:Hide() end
            if btn.previewSelect then btn.previewSelect:Hide() end
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

-- Build positional args for QueryDCCollectionTransmog from current filter UI
-- state. Shared by the full-list and source-paged native render paths.
function Wardrobe:_NativeTransmogQueryArgs()
    local invCsv = ""
    if type(self.selectedSlotFilter) == "table" and
       type(self.selectedSlotFilter.invTypes) == "table" then
        local invList = {}
        for invType in pairs(self.selectedSlotFilter.invTypes) do
            invList[#invList + 1] = tonumber(invType) or invType
        end
        table.sort(invList)
        invCsv = table.concat(invList, ",")
    end

    local quality = tonumber(self.selectedQualityFilter)
    if not quality then quality = -1 end

    return invCsv, quality, (self.searchText or ""),
        (self.showUncollected and 1 or 0), (self.sortMode or "default")
end

function Wardrobe:BuildAppearanceList()
    local defsRev = (type(DC.GetDefinitionsRevision) == "function") and
        (DC:GetDefinitionsRevision("transmog") or 0) or 0
    local collRev = (type(DC.GetCollectionsRevision) == "function") and
        (DC:GetCollectionsRevision("transmog") or 0) or 0

    local slotFilterKey = ""
    if type(self.selectedSlotFilter) == "table" then
        slotFilterKey = tostring(self.selectedSlotFilter.key
            or self.selectedSlotFilter.label
            or self.selectedSlotFilter.text
            or "")
        if slotFilterKey == "" and type(self.selectedSlotFilter.invTypes) == "table" then
            local invTypes = {}
            for invType in pairs(self.selectedSlotFilter.invTypes) do
                table.insert(invTypes, tonumber(invType) or tostring(invType))
            end
            table.sort(invTypes)
            slotFilterKey = table.concat(invTypes, ",")
        end
    end

    local search = self.searchText
    if search and search ~= "" then
        search = string.lower(search)
    else
        search = ""
    end

    local cacheKey = table.concat({
        tostring(defsRev),
        tostring(collRev),
        slotFilterKey,
        tostring(tonumber(self.selectedQualityFilter) or 0),
        tostring(self.showUncollected and 1 or 0),
        search,
        tostring(self.sortMode or "default"),
    }, "|")

    self._appearanceListCache = self._appearanceListCache or {}
    local cacheEntry = self._appearanceListCache.transmog
    if cacheEntry and cacheEntry.key == cacheKey and
       type(cacheEntry.results) == "table" then
        self.totalCount = tonumber(cacheEntry.totalCount) or 0
        self.collectedCount = tonumber(cacheEntry.collectedCount) or 0
        return cacheEntry.results
    end

    -- Native catalog: the DLL does the filter/dedup/sort and returns just the
    -- matched appearances, so the whole catalog never lives in Lua tables.
    if type(DC.HasNativeTransmogCatalog) == "function" and
       DC:HasNativeTransmogCatalog() then
        if type(DC._SyncNativeTransmogCollected) == "function" then
            DC:_SyncNativeTransmogCollected(false)
        end

        local invCsv, quality, searchStr, showUncollected, sortMode =
            self:_NativeTransmogQueryArgs()

        local ok, qResults, qTotal, qCollected = pcall(QueryDCCollectionTransmog,
            invCsv, quality, searchStr, showUncollected, sortMode)

        if ok and type(qResults) == "table" then
            self.totalCount = tonumber(qTotal) or 0
            self.collectedCount = tonumber(qCollected) or 0
            self._appearanceListCache.transmog = {
                key = cacheKey,
                results = qResults,
                totalCount = self.totalCount,
                collectedCount = self.collectedCount,
            }
            return qResults
        end
        -- On any failure fall through to the legacy Lua path below.
    end

    local results = {}
    local defs = (DC.definitions and (DC.definitions.transmog or DC.definitions.wardrobe)) or {}
    local col = (DC.collections and (DC.collections.transmog or DC.collections.wardrobe)) or {}
    local hasPendingItemInfo = false

    -- For transmog we want to show unique appearances, not one entry per item.
    -- Servers can send multiple items sharing the same appearance (displayId) and
    -- Lua's pairs() iteration order is arbitrary. Track the "best" representative
    -- per appearance so we don't end up showing only low-level/low-quality items.
    local byKey = {}

    local searchNum = nil
    if search ~= "" then
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
        if quality == nil and itemLevel == nil then
            hasPendingItemInfo = true
        end
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

        -- Definitions can be either full tables or packed strings.
        local name
        local displayId
        local itemId
        local invType
        local iconTexture
        local itemIds
        local itemIdsTotal
        local packedQuality

        if type(def) == "string" and type(DC.ParsePackedTransmogDefinition) == "function" then
            local pName, pIcon, pQuality, pDisplayId, pInvType, _, _, _, pItemId, _, pItemIdsTotal, pItemIdsStr = DC:ParsePackedTransmogDefinition(def)
            name = pName or ""
            iconTexture = pIcon or nil
            packedQuality = tonumber(pQuality) or 0
            displayId = tonumber(pDisplayId)
            invType = tonumber(pInvType) or 0
            itemId = tonumber(pItemId)
            itemIdsTotal = (pItemIdsTotal ~= "" and tonumber(pItemIdsTotal)) or nil
            itemIds = (pItemIdsStr and pItemIdsStr ~= "" and pItemIdsStr) or nil

            if not itemId and type(id) == "number" then
                itemId = id
            elseif not itemId and type(id) == "string" then
                itemId = tonumber(id)
            end
        else
            name = (def and def.name) or ""
            iconTexture = def and (def.icon or def.Icon or def.texture or def.Texture) or nil

            displayId = def.displayId or def.displayID or def.display_id or def.appearanceId or def.appearance_id
            if type(displayId) == "string" then
                displayId = tonumber(displayId)
            end

            -- Prefer explicit itemId if present; fall back to the definition key only if it looks numeric.
            itemId = def.itemId or def.item_id or def.item
            if type(itemId) == "string" then
                itemId = tonumber(itemId)
            end
            if not itemId and type(id) == "number" then
                itemId = id
            elseif not itemId and type(id) == "string" then
                itemId = tonumber(id)
            end

            invType = def.inventoryType or def.inventory_type or def.invType or def.inv_type
            if type(invType) == "string" then
                invType = tonumber(invType)
            end
            invType = invType or 0

            itemIds = def.itemIds or def.item_ids
            itemIdsTotal = def.itemIdsTotal or def.item_ids_total or def.itemIdsTotal or def.itemIds_count or def.itemIdsCount
            packedQuality = def.quality or def.Quality or def.rarity or def.Rarity or def.itemQuality or def.item_quality
            if type(packedQuality) == "string" then
                packedQuality = tonumber(packedQuality)
            end
            packedQuality = tonumber(packedQuality) or 0
        end

        -- Fallback: if server didn't send inventoryType, infer it from the item.
        if invType == 0 and itemId then
            if type(GetItemInfo) == "function" then
                local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemId)
                if not equipLoc or equipLoc == "" then
                    hasPendingItemInfo = true
                end
            end
            invType = self:InferInventoryTypeFromItemId(itemId) or invType
        end

        if self.selectedSlotFilter then
            -- Only include items that have a known inventory type matching the filter.
            -- Items with unknown invType (0) are excluded to prevent wrong-slot randomization.
            if invType == 0 or not self.selectedSlotFilter.invTypes[invType] then
                valid = false
            end
        end

        -- Quality filtering: exact match per quality (-1 = all qualities).
        if valid and self.selectedQualityFilter and self.selectedQualityFilter >= 0 then
            -- Server definitions commonly use "rarity" (and some use "quality").
            -- Fall back to the client item cache (GetItemInfo) if the definition is missing it.
            local quality = packedQuality or 0

            if quality <= 0 and itemId and GetItemInfo then
                local _, _, itemQuality = GetItemInfo(itemId)
                if itemQuality then
                    quality = tonumber(itemQuality) or quality
                else
                    hasPendingItemInfo = true
                end
            end
            if quality ~= self.selectedQualityFilter then
                valid = false
            end
        end

        if valid and search then
            local matchFound = false
            
            -- Check name match
            if string.find(string.lower(name or ""), search, 1, true) then
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
                byKey[key] = {
                    id = id,
                    itemId = itemId,
                    name = name or "",
                    icon = iconTexture,
                    collected = collected,
                    inventoryType = invType,
                    displayId = displayId,
                    itemIds = itemIds,
                    itemIdsTotal = itemIdsTotal,
                    quality = packedQuality or 0,
                }
            else
                -- If any variant is collected, mark collected.
                if collected then
                    existing.collected = true
                end

                if not existing.itemIds and itemIds then
                    existing.itemIds = itemIds
                end
                if not existing.itemIdsTotal and itemIdsTotal then
                    existing.itemIdsTotal = itemIdsTotal
                end
                if (not existing.icon or existing.icon == "") and iconTexture and iconTexture ~= "" then
                    existing.icon = iconTexture
                end
                -- Prefer a better representative itemId for the tooltip/model preview.
                if IsBetterRepresentative(itemId, existing.itemId) then
                    existing.id = id
                    existing.itemId = itemId
                    existing.name = (name or existing.name or "")
                    existing.icon = iconTexture or existing.icon
                    existing.inventoryType = invType
                    existing.displayId = displayId
                    existing.quality = packedQuality or existing.quality or 0
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

    local sortMode = self.sortMode or "default"
    local function byName(a, b)
        local an, bn = a.name or "", b.name or ""
        if an ~= bn then return an < bn end
        return (tonumber(a.itemId) or 0) < (tonumber(b.itemId) or 0)
    end
    table.sort(results, function(a, b)
        if sortMode == "name" then
            return byName(a, b)
        elseif sortMode == "itemId" then
            local ai, bi = tonumber(a.itemId) or 0, tonumber(b.itemId) or 0
            if ai ~= bi then return ai < bi end
            return byName(a, b)
        elseif sortMode == "quality" then
            local aq, bq = tonumber(a.quality) or 0, tonumber(b.quality) or 0
            if aq ~= bq then return aq > bq end
            return byName(a, b)
        elseif sortMode == "collected" then
            if a.collected ~= b.collected then return a.collected end
            return byName(a, b)
        elseif sortMode == "uncollected" then
            if a.collected ~= b.collected then return b.collected end
            return byName(a, b)
        end
        -- "default": collected first, then name (legacy behavior).
        if a.collected and not b.collected then return true end
        if b.collected and not a.collected then return false end
        return byName(a, b)
    end)

    if not hasPendingItemInfo then
        self._appearanceListCache.transmog = {
            key = cacheKey,
            results = results,
            totalCount = totalMatched,
            collectedCount = collectedMatched,
        }
    elseif cacheEntry and cacheEntry.key ~= cacheKey then
        self._appearanceListCache.transmog = nil
    end

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
    local previewUnit = Wardrobe.previewUnit or "player"

    -- Reset model to current preview unit with all current equipment
    model:SetUnit(previewUnit)

    -- Only preview the specific slot if one is selected
    if self.selectedSlot and model.Undress and model.TryOn then
        -- Undress only the selected slot, keep everything else
        model:Undress()

        -- Re-apply all equipped items (with error protection).
        -- Read from the unit actually being previewed so "Target" previews use
        -- the target's gear rather than the player's.
        for slot = 1, 19 do
            local itemID = GetInventoryItemID(previewUnit, slot)
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
    
    -- SetUnit above reset the model transform; restore the camera the user is
    -- currently looking through (preserves any manual zoom/pan/rotation).
    if type(self._ApplyModelCamera) == "function" then
        self:_ApplyModelCamera(model)
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

    -- Link Item
    table.insert(menu, {
        text = "Link to Chat",
        notCheckable = true,
        func = function()
            local id = appearance.itemId
            if id then
                local _, link = GetItemInfo(id)
                if not link then
                    link = "\124cffff8000\124Hitem:" .. id .. ":0:0:0:0:0:0:0:0\124h[Item " .. id .. "]\124h\124r"
                end
                if ChatEdit_InsertLink then
                     if not ChatEdit_GetActiveWindow() then
                         DEFAULT_CHAT_FRAME.editBox:Show()
                         DEFAULT_CHAT_FRAME.editBox:SetText("")
                     end
                     ChatEdit_InsertLink(link)
                end
            end
        end,
    })

    -- Wishlist Logic
    local itemId = appearance.itemId
    if not appearance.collected and itemId then
        local isWishlisted = Wardrobe.IsWishlistedTransmog and Wardrobe:IsWishlistedTransmog(itemId)
        
        table.insert(menu, {
            text = isWishlisted and ((DC.L and DC.L["REMOVE_FROM_WISHLIST"]) or "Remove from wishlist") or ((DC.L and (DC.L["ADD_TO_WISHLIST"] or DC.L["WISHLIST"])) or "Add to wishlist"),
            notCheckable = true,
            func = function()
                if DC and DC.RequestAddWishlist and DC.RequestRemoveWishlist then
                    if isWishlisted then
                        DC:RequestRemoveWishlist("transmog", itemId)
                    else
                        DC:RequestAddWishlist("transmog", itemId)
                    end
                end
            end,
        })
    end
        table.insert(menu, {
            text = "Apply",
            notCheckable = true,
            func = function()
                Wardrobe:ApplyAppearance(appearance)
            end,
        })


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

    -- Special handling for "Hide Slot" option
    if appearance.isHideOption then
        if DC and DC.RequestSetTransmog then
            DC:RequestSetTransmog(invSlotId, 0)  -- Send 0 to hide the slot
            
            if type(self.MarkUnsavedChanges) == "function" then
                self:MarkUnsavedChanges()
            end
        end
        return
    end
    
    local appearanceId = appearance.displayId or appearance.appearanceId or appearance.appearance_id
    if type(appearanceId) == "string" then
        appearanceId = tonumber(appearanceId)
    end

    -- Most reliable: server expects displayId.
    if not appearanceId or tonumber(appearanceId) <= 0 then
        if DC and DC.Print then
            DC:Print("Unable to apply: missing appearance displayId for this entry.")
        end
        return
    end

    if DC and DC.RequestSetTransmog then
        DC:RequestSetTransmog(invSlotId, appearanceId)

        if type(self.MarkUnsavedChanges) == "function" then
            self:MarkUnsavedChanges()
        end
    end
end

-- ============================================================================
-- MODEL UPDATE
-- ============================================================================

function Wardrobe:UpdateModel()
    if not self.frame or not self.frame.model then return end

    local model = self.frame.model
    model:SetUnit(Wardrobe.previewUnit or "player")

    if self.transmogDisabled then
        model:Undress()
        if type(self.StabilizePreviewModel) == "function" then
            self:StabilizePreviewModel(model, model._dcPreviewSequence)
        end
        return
    end

    -- Apply transmog items to the model using TryOn
    -- This shows the transmogged appearance instead of the equipped item appearance
    local transmogItemIds = DC.transmogItemIds or {}
    local state = DC.transmogState or {}
    
    for _, slotDef in ipairs(self.EQUIPMENT_SLOTS or {}) do
        local invSlotId = GetInventorySlotInfo(slotDef.key)
        if invSlotId then
            local eqSlot = invSlotId - 1
            local eqSlotStr = tostring(eqSlot)
            local hasTransmog = state[eqSlotStr] and tonumber(state[eqSlotStr]) ~= 0
            
            if hasTransmog then
                local transmogItemId = transmogItemIds[eqSlot] or transmogItemIds[eqSlotStr]
                if transmogItemId then
                    transmogItemId = tonumber(transmogItemId)
                    if transmogItemId and transmogItemId > 0 then
                        pcall(function() model:TryOn(transmogItemId) end)
                    end
                end
            end
        end
    end

    if type(self.StabilizePreviewModel) == "function" then
        self:StabilizePreviewModel(model, model._dcPreviewSequence)
    end
end

-- ============================================================================
-- UPDATE SLOT BUTTONS
-- ============================================================================

function Wardrobe:UpdateSlotButtons()
    if not self.frame or not self.frame.slotButtons then return end

    local needsDelayedRefresh = false

    for _, btn in ipairs(self.frame.slotButtons) do
        local slotDef = btn.slotDef
        local invSlotId = GetInventorySlotInfo(slotDef.key)

        local eqSlot = invSlotId and (invSlotId - 1)
        local state = DC.transmogState or {}
        local transmogItemIds = DC.transmogItemIds or {}
        local applied = eqSlot and state[tostring(eqSlot)] and tonumber(state[tostring(eqSlot)]) ~= 0

        local iconTexture = nil
        if applied and eqSlot ~= nil then
            local transmogItemId = transmogItemIds[eqSlot] or transmogItemIds[tostring(eqSlot)]
            if transmogItemId then
                transmogItemId = tonumber(transmogItemId)
                if transmogItemId and transmogItemId > 0 then
                    iconTexture = select(10, GetItemInfo(transmogItemId))
                    if not iconTexture then
                        -- Item not cached yet, trigger cache and mark for delayed refresh
                        needsDelayedRefresh = true
                    end
                end
            end
        end

        btn.icon:SetTexture(iconTexture or self:GetSlotIcon(slotDef.key))

        if applied then
            btn.transmogApplied:Show()
        else
            btn.transmogApplied:Hide()
        end
    end

    -- Schedule delayed refresh if some transmog items weren't cached
    if needsDelayedRefresh and DC and type(DC._ScheduleTransmogIconRefresh) == "function" then
        DC:_ScheduleTransmogIconRefresh()
    end
end
