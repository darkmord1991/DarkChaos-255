--[[
    DC-Collection UI/Wardrobe/WardrobeCore.lua
    ==========================================

    Wardrobe core: constants, state, shared helpers, slash commands, and events.
    
    Advanced Features:
    - Per-slot camera positioning (race/gender specific)
    - Mouse drag rotation
    - Mouse wheel zoom (0.3x - 3.0x)
    - Ctrl+Click slot to link item
    - Right-click slot for options
    - Enhanced visual feedback and highlighting

    This file is loaded after UI/WardrobeFrame.lua (entrypoint).
]]

local DC = DCCollection
if not DC then return end

local L = DC.L or {}

DC.Wardrobe = DC.Wardrobe or {}
local Wardrobe = DC.Wardrobe

-- ============================================================================
-- UNSAVED CHANGES (WARDROBE LOOK)
-- ============================================================================

function Wardrobe:MarkUnsavedChanges()
    self._unsavedChanges = true
end

function Wardrobe:ClearUnsavedChanges()
    self._unsavedChanges = nil
end

function Wardrobe:_HideImmediate()
    if self.frame then
        self._suppressUnsavedOnHide = true
        self.frame:Hide()
    end
end

function Wardrobe:_EnsureUnsavedChangesPopup()
    if not StaticPopupDialogs or StaticPopupDialogs["DC_WARDROBE_UNSAVED_CHANGES"] then
        return
    end

    StaticPopupDialogs["DC_WARDROBE_UNSAVED_CHANGES"] = {
        text = "You have unsaved changes. Save this look as an outfit?",
        button1 = "Save",
        button2 = "Discard",
        button3 = "Cancel",
        OnAccept = function()
            local action = Wardrobe._pendingUnsavedAction
            Wardrobe._pendingUnsavedAction = nil
            Wardrobe._afterSaveAction = action
            if type(Wardrobe.ShowSaveOutfitDialog) == "function" then
                Wardrobe:ShowSaveOutfitDialog()
            end
        end,
        OnCancel = function()
            local action = Wardrobe._pendingUnsavedAction
            Wardrobe._pendingUnsavedAction = nil
            Wardrobe:ClearUnsavedChanges()
            if action then
                pcall(action)
            end
        end,
        OnAlt = function()
            Wardrobe._pendingUnsavedAction = nil
            Wardrobe._afterSaveAction = nil
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

function Wardrobe:ConfirmUnsavedChanges(nextAction)
    if not self._unsavedChanges then
        if nextAction then
            nextAction()
        end
        return
    end

    self:_EnsureUnsavedChangesPopup()
    self._pendingUnsavedAction = nextAction
    StaticPopup_Show("DC_WARDROBE_UNSAVED_CHANGES")
end

-- ============================================================================
-- CONSTANTS / DATA TABLES
-- ============================================================================

Wardrobe.FRAME_WIDTH = 1120
Wardrobe.FRAME_HEIGHT = 720
Wardrobe.MODEL_WIDTH = 250
Wardrobe.SLOT_SIZE = 36
Wardrobe.GRID_ICON_SIZE = 46
Wardrobe.GRID_COLS = 6
Wardrobe.GRID_ROWS = 6
Wardrobe.ITEMS_PER_PAGE = Wardrobe.GRID_COLS * Wardrobe.GRID_ROWS

-- Camera control constants
Wardrobe.CAMERA_ZOOM_MIN = 0.3
Wardrobe.CAMERA_ZOOM_MAX = 3.0
Wardrobe.CAMERA_ZOOM_STEP = 0.1
Wardrobe.CAMERA_ROTATION_SPEED = 0.01

Wardrobe.EQUIPMENT_SLOTS = {
    -- Left column (top to bottom)
    { key = "HeadSlot",      label = "Head",      invType = 1,  side = "left",  row = 1 },
    { key = "ShoulderSlot",  label = "Shoulder",  invType = 3,  side = "left",  row = 2 },
    { key = "BackSlot",      label = "Back",      invType = 16, side = "left",  row = 3 },
    { key = "ChestSlot",     label = "Chest",     invType = 5,  side = "left",  row = 4 },
    { key = "ShirtSlot",     label = "Shirt",     invType = 4,  side = "left",  row = 5 },
    { key = "TabardSlot",    label = "Tabard",    invType = 19, side = "left",  row = 6 },
    { key = "WristSlot",     label = "Wrist",     invType = 9,  side = "left",  row = 7 },

    -- Right column (top to bottom)
    { key = "HandsSlot",     label = "Hands",     invType = 10, side = "right", row = 1 },
    { key = "WaistSlot",     label = "Waist",     invType = 6,  side = "right", row = 2 },
    { key = "LegsSlot",      label = "Legs",      invType = 7,  side = "right", row = 3 },
    { key = "FeetSlot",      label = "Feet",      invType = 8,  side = "right", row = 4 },

    -- Bottom (weapons)
    { key = "MainHandSlot",      label = "Main Hand", invType = 13, side = "bottom", row = 1 },
    { key = "SecondaryHandSlot", label = "Off Hand",  invType = 14, side = "bottom", row = 2 },
    { key = "RangedSlot",        label = "Ranged",    invType = 15, side = "bottom", row = 3 },
}

Wardrobe.SLOT_FILTERS = {
    { label = "Head",      icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Head",     invTypes = { [1] = true } },
    { label = "Shoulder",  icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shoulder", invTypes = { [3] = true } },
    { label = "Chest",     icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",    invTypes = { [5] = true, [20] = true } },
    { label = "Shirt",     icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shirt",    invTypes = { [4] = true } },
    { label = "Tabard",    icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Tabard",   invTypes = { [19] = true } },
    { label = "Wrist",     icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Wrists",   invTypes = { [9] = true } },
    { label = "Hands",     icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Hands",    invTypes = { [10] = true } },
    { label = "Waist",     icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Waist",    invTypes = { [6] = true } },
    { label = "Legs",      icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Legs",     invTypes = { [7] = true } },
    { label = "Feet",      icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Feet",     invTypes = { [8] = true } },
    { label = "Back",      icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",    invTypes = { [16] = true } }, -- Back uses chest icon
    { label = "Main Hand", icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand", invTypes = { [13] = true, [17] = true, [21] = true } }, -- Weapon, 2H, MainHand
    { label = "Off Hand",  icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand", invTypes = { [13] = true, [14] = true, [17] = true, [22] = true, [23] = true } }, -- Weapon, Shield, 2H, OffHand, Holdable
    { label = "Ranged",    icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ranged",   invTypes = { [15] = true, [25] = true, [26] = true, [28] = true } }, -- Ranged, Thrown, RangedRight, Relic
}

Wardrobe.VISUAL_SLOTS = {
    HeadSlot = 283,
    ShoulderSlot = 287,
    ShirtSlot = 289,
    ChestSlot = 291,
    WaistSlot = 293,
    LegsSlot = 295,
    FeetSlot = 297,
    WristSlot = 299,
    HandsSlot = 301,
    BackSlot = 311,
    MainHandSlot = 313,
    SecondaryHandSlot = 315,
    RangedSlot = 317,
    TabardSlot = 319,
}

-- ============================================================================
-- STATE DEFAULTS
-- ============================================================================

Wardrobe.currentTab = Wardrobe.currentTab or "items" -- "items", "sets", "community"
Wardrobe.selectedSlot = Wardrobe.selectedSlot or nil
Wardrobe.selectedSlotFilter = Wardrobe.selectedSlotFilter or nil
Wardrobe.selectedQualityFilter = Wardrobe.selectedQualityFilter or 0  -- 0 = all qualities
Wardrobe.currentPage = Wardrobe.currentPage or 1
Wardrobe.totalPages = Wardrobe.totalPages or 1
Wardrobe.searchText = Wardrobe.searchText or ""
Wardrobe.appearanceList = Wardrobe.appearanceList or {}
Wardrobe.collectedCount = Wardrobe.collectedCount or 0
Wardrobe.totalCount = Wardrobe.totalCount or 0
Wardrobe.transmogDisabled = Wardrobe.transmogDisabled or false
Wardrobe.spellVisualsDisabled = Wardrobe.spellVisualsDisabled or false
Wardrobe.showUncollected = (Wardrobe.showUncollected ~= nil) and Wardrobe.showUncollected or true

-- Outfits feature has been removed from the Wardrobe UI.
-- Keep no-op stubs to avoid nil-call errors if some legacy code path still calls these.
if type(Wardrobe.UpdateOutfitSlots) ~= "function" then
    function Wardrobe:UpdateOutfitSlots() end
end
if type(Wardrobe.ShowSaveOutfitDialog) ~= "function" then
    function Wardrobe:ShowSaveOutfitDialog() end
end
if type(Wardrobe.LoadOutfit) ~= "function" then
    function Wardrobe:LoadOutfit() end
end

-- Quality filter constants (matches server-side ITEM_QUALITY)
Wardrobe.QUALITY_FILTERS = {
    { id = 0, text = "All Qualities", color = { r = 1, g = 1, b = 1 } },
    { id = 1, text = "Common+", color = { r = 1, g = 1, b = 1 } },           -- Poor (0) excluded
    { id = 2, text = "Uncommon+", color = { r = 0.12, g = 1, b = 0 } },      -- Green+
    { id = 3, text = "Rare+", color = { r = 0, g = 0.44, b = 0.87 } },       -- Blue+
    { id = 4, text = "Epic+", color = { r = 0.64, g = 0.21, b = 0.93 } },    -- Purple+
    { id = 5, text = "Legendary", color = { r = 1, g = 0.5, b = 0 } },       -- Orange
}

-- ============================================================================
-- SHARED HELPERS
-- ============================================================================

function Wardrobe:SafeGetText(key, fallback)
    if L and L[key] and L[key] ~= "" then
        return L[key]
    end
    return fallback
end

function Wardrobe:GetSlotIcon(slotKey)
    local invSlotId, textureName = GetInventorySlotInfo(slotKey)
    if invSlotId then
        local itemId = GetInventoryItemID("player", invSlotId)
        if itemId then
            local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemId)
            if texture then
                return texture
            end
        end
        -- Return the default slot texture if no item is equipped
        if textureName then
            return textureName
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function Wardrobe:GetTransmogDefinitionsLoadedCount()
    if not DC then
        return 0
    end

    local defs = DC._transmogDefinitions
    if type(defs) ~= "table" then
        defs = (DC.definitions and DC.definitions.transmog) or nil
    end

    if type(DC.TableCount) == "function" and type(defs) == "table" then
        return DC:TableCount(defs)
    end

    if type(defs) == "table" then
        local c = 0
        for _ in pairs(defs) do c = c + 1 end
        return c
    end

    return 0
end

function Wardrobe:GetTransmogDefinitionsTotalCount()
    if not DC then
        return nil
    end

    local total = tonumber(DC._transmogDefTotal)
    if total and total > 0 then
        return total
    end

    local statsTotal = DC.stats and DC.stats.transmog and (DC.stats.transmog.total or DC.stats.transmog.count)
    statsTotal = tonumber(statsTotal)
    if statsTotal and statsTotal > 0 then
        return statsTotal
    end

    return nil
end

function Wardrobe:UpdateTransmogLoadingProgressUI(forceShow)
    local bar, text
    if DC and DC.MainFrame and DC.MainFrame.topLoadBar and DC.MainFrame.topLoadText then
        bar, text = DC.MainFrame.topLoadBar, DC.MainFrame.topLoadText
    elseif self.frame and self.frame.loadBar and self.frame.loadText then
        bar, text = self.frame.loadBar, self.frame.loadText
    else
        return
    end

    if not DC then
        bar:Hide()
        return
    end

    local pending = DC._transmogPagingDelayFrame and DC._transmogPagingDelayFrame.pendingRequest
    local isLoading = (DC._transmogDefLoading and true or false) or (pending and true or false)
    if not isLoading and not forceShow then
        bar:Hide()
        return
    end

    local loaded = self:GetTransmogDefinitionsLoadedCount()
    local total = self:GetTransmogDefinitionsTotalCount()

    bar:Show()

    if total and total > 0 then
        if loaded > total then
            total = loaded
        end
        bar:SetMinMaxValues(0, total)
        bar:SetValue(math.min(loaded, total))
        local pct = math.floor((loaded / total) * 100)
        text:SetText(string.format("Loading: %d/%d (%d%%)", loaded, total, pct))
    else
        bar:SetMinMaxValues(0, math.max(loaded, 1))
        bar:SetValue(math.max(loaded, 1))
        text:SetText(string.format("Loading: %d (total unknown)", loaded))
    end
end

function Wardrobe:IsAppearanceCollected(itemId)
    if not DC or not DC.collections or not DC.collections.transmog then
        return false
    end
    return DC.collections.transmog[itemId] ~= nil
end

function Wardrobe:GetAppearanceDisplayIdForItemId(itemId)
    if not itemId or itemId == 0 or not DC then
        return nil
    end

    self.itemIdToDisplayId = self.itemIdToDisplayId or {}
    if self.itemIdToDisplayId[itemId] ~= nil then
        return self.itemIdToDisplayId[itemId]
    end

    local function ExtractDisplayId(def)
        if type(def) ~= "table" then
            return nil
        end
        local displayId = def.displayId or def.displayID or def.display_id or def.itemDisplayId
            or def.appearanceId or def.appearance_id
        if type(displayId) == "string" then
            displayId = tonumber(displayId)
        end
        return displayId
    end

    -- Fast path: some servers key definitions by itemId.
    local defs = DC.definitions and DC.definitions.transmog
    if type(defs) == "table" then
        local direct = ExtractDisplayId(defs[itemId])
        if direct and direct > 0 then
            self.itemIdToDisplayId[itemId] = direct
            return direct
        end

        -- Build a reverse map once from defs (itemId -> displayId)
        if not self.itemIdToDisplayIdBuilt then
            for _, def in pairs(defs) do
                if type(def) == "table" then
                    local sourceItemId = def.itemId or def.item_id or def.entryId or def.entry_id
                    if type(sourceItemId) == "string" then
                        sourceItemId = tonumber(sourceItemId)
                    end
                    local displayId = ExtractDisplayId(def)
                    if sourceItemId and displayId and displayId > 0 then
                        self.itemIdToDisplayId[sourceItemId] = displayId
                    end
                end
            end
            self.itemIdToDisplayIdBuilt = true
        end
    end

    return self.itemIdToDisplayId[itemId]
end

function Wardrobe:IsWishlistedTransmog(itemId)
    if not itemId or not DC or type(DC.wishlist) ~= "table" then
        return false
    end

    local transmogTypeId = nil
    if type(DC.GetTypeIdFromName) == "function" then
        transmogTypeId = DC:GetTypeIdFromName("transmog")
    end

    for _, wish in ipairs(DC.wishlist) do
        if type(wish) == "table" then
            local wishEntry = tonumber(wish.entryId or wish.entry_id or wish.itemId or wish.item_id) or (wish.entryId or wish.entry_id or wish.itemId or wish.item_id)
            if wishEntry == itemId then
                if transmogTypeId == nil then
                    return true
                end
                local wishType = wish.type or wish.typeId or wish.type_id
                if wishType == nil or tonumber(wishType) == tonumber(transmogTypeId) then
                    return true
                end
            end
        end
    end

    return false
end

function Wardrobe:HookItemTooltip()
    if self.tooltipHooked then return end

    if DC and DC.RequestCollectedAppearances then
        DC:RequestCollectedAppearances()
    end

    local function TooltipHasLine(tooltip, text)
        local name = tooltip and tooltip.GetName and tooltip:GetName()
        if not name then return false end

        for i = 1, 30 do
            local left = _G[name .. "TextLeft" .. i]
            if left then
                local t = left:GetText()
                if t == text then
                    return true
                end
            end
        end

        return false
    end

    local function AddCollectedLine(tooltip, itemId)
        if not itemId or itemId == 0 then return end

        local displayId = self:GetAppearanceDisplayIdForItemId(itemId)

        local collected = false
        
        -- Method 1: Check server-provided collected appearances (keyed by displayId)
        if displayId and displayId > 0 and DC and DC.IsAppearanceCollected then
            collected = DC:IsAppearanceCollected(displayId) and true or false
        end

        -- Method 2: Check local transmog collection cache (keyed by displayId)
        if not collected and DC and DC.collections and DC.collections.transmog and displayId then
            collected = DC.collections.transmog[displayId] ~= nil
        end

        -- Method 3: Check local transmog collection cache (keyed by itemId - legacy)
        if not collected and DC and DC.collections and DC.collections.transmog then
            collected = DC.collections.transmog[itemId] ~= nil
        end

        -- Method 4: Check via Wardrobe helper (also keyed by itemId)
        if not collected then
            collected = self:IsAppearanceCollected(itemId)
        end

        if collected then
            local text = "Appearance collected"
            if not TooltipHasLine(tooltip, text) then
                tooltip:AddLine(" ")
                tooltip:AddLine(text, 0.1, 1, 0.1)
                tooltip:Show()
            end
        end
    end

    GameTooltip:HookScript("OnTooltipSetItem", function(tip)
        local _, itemLink = tip:GetItem()
        if itemLink then
            local itemId = tonumber(string.match(itemLink, "item:(%d+)"))
            AddCollectedLine(tip, itemId)
        end
    end)

    if ItemRefTooltip then
        ItemRefTooltip:HookScript("OnTooltipSetItem", function(tip)
            local _, itemLink = tip:GetItem()
            if itemLink then
                local itemId = tonumber(string.match(itemLink, "item:(%d+)"))
                AddCollectedLine(tip, itemId)
            end
        end)
    end

    self.tooltipHooked = true
end

-- ============================================================================
-- SHOW / HIDE
-- ============================================================================

function Wardrobe:Show()
    local frame = self:CreateFrame()
    if not frame then return end

    if self.isEmbedded then
        frame:Show()
        return
    end

    if DC.MainFrame and DC.MainFrame:IsShown() then
        local point, relativeTo, relativePoint, xOfs, yOfs = DC.MainFrame:GetPoint()
        if point then
            frame:ClearAllPoints()
            frame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
        end
        DC.MainFrame:Hide()
    end

    -- Only request definitions on first open or if explicitly refreshing
    if not Wardrobe.definitionsLoaded and DC and DC.RequestDefinitions then
        Wardrobe.definitionsLoaded = true
        DC:RequestDefinitions("transmog")
        DC:RequestDefinitions("itemSets")
    end
    if DC and DC.RequestCollection then
        DC:RequestCollection("transmog")
    end
    if DC and DC.RequestWishlist then
        DC:RequestWishlist()
    end

    if frame.model then
        frame.model:SetUnit("player")
        frame.model:SetFacing(0)
    end

    self:SelectTab("items")

    self:UpdateSlotButtons()
    self:UpdateOutfitSlots()

    frame:Show()
end

function Wardrobe:ShowEmbedded(host)
    local frame = self:CreateFrame()
    if not frame then return end

    if type(self.SetEmbeddedMode) == "function" then
        self:SetEmbeddedMode(true, host)
    else
        if host then
            frame:SetParent(host)
            frame:ClearAllPoints()
            frame:SetAllPoints(host)
        end
    end

    -- Only request definitions on first open or if explicitly refreshing
    if not Wardrobe.definitionsLoaded and DC and DC.RequestDefinitions then
        Wardrobe.definitionsLoaded = true
        DC:RequestDefinitions("transmog")
        DC:RequestDefinitions("itemSets")
    end
    if DC and DC.RequestCollection then
        DC:RequestCollection("transmog")
    end
    if DC and DC.RequestWishlist then
        DC:RequestWishlist()
    end

    if frame.model then
        frame.model:SetUnit("player")
        frame.model:SetFacing(0)
    end

    self:SelectTab("items")
    self:UpdateSlotButtons()
    self:UpdateOutfitSlots()

    frame:Show()
end

function Wardrobe:Hide()
    if not self.frame then
        return
    end

    if self._unsavedChanges then
        self:ConfirmUnsavedChanges(function()
            Wardrobe:_HideImmediate()
        end)
        return
    end

    self:_HideImmediate()
end

function Wardrobe:CancelRefresh()
    if not self.isRefreshing then return end
    
    self.isRefreshing = false
    
    -- Stop paging
    if DC and DC._transmogPagingDelayFrame then
        DC._transmogPagingDelayFrame:Hide()
        DC._transmogPagingDelayFrame.pendingRequest = nil
    end
    
    DC._transmogDefLoading = nil
    
    -- Update UI
    if self.frame and self.frame.refreshBtn then
        self.frame.refreshBtn:SetText("Refresh Data")
        self.frame.refreshBtn:Enable()
    end
    
    if self.frame and self.frame.refreshStatus then
        self.frame.refreshStatus:SetText("Cancelled")
        C_Timer.After(2, function()
            if self.frame and self.frame.refreshStatus then
                self.frame.refreshStatus:Hide()
            end
        end)
    end

    if type(self.UpdateTransmogLoadingProgressUI) == "function" then
        self:UpdateTransmogLoadingProgressUI(false)
    end

    -- Ensure the protocol isn't left in an "inflight" stuck state if the server never replied.
    if DC and type(DC.AbortTransmogDefinitionsPaging) == "function" then
        -- If we cancel, do not allow a later offset=0 response to wipe cached defs.
        DC._transmogClearOnFirstPage = nil
        DC:AbortTransmogDefinitionsPaging("wardrobe_cancel")
    end
    
    DC:Print("[Wardrobe] Refresh cancelled")
    
    -- Refresh grid with whatever we have
    self:RefreshGrid()
end

function Wardrobe:RefreshTransmogDefinitions()
    if not DC then return end
    
    -- Set refreshing flag
    self.isRefreshing = true
    
    -- Mark that we're doing a manual refresh
    self.definitionsLoaded = true  -- Keep this true to prevent auto-reload on open
    
    -- Update UI
    if self.frame and self.frame.refreshBtn then
        self.frame.refreshBtn:SetText("Cancel")
        self.frame.refreshBtn:Enable()
    end
    
    if self.frame and self.frame.refreshStatus then
        self.frame.refreshStatus:SetText("Starting refresh...")
        self.frame.refreshStatus:Show()
    end

    if type(self.UpdateTransmogLoadingProgressUI) == "function" then
        self:UpdateTransmogLoadingProgressUI(true)
    end
    
    -- IMPORTANT: do NOT wipe local transmog definitions immediately.
    -- If the server doesn't reply, wiping here leaves the user with an empty wardrobe and
    -- can make refresh look "broken".
    -- Instead, request a forced re-download and wipe in-place only when the first page arrives.
    DC._transmogClearOnFirstPage = true
    
    -- Reset any stuck paging/inflight state before requesting.
    if type(DC.AbortTransmogDefinitionsPaging) == "function" then
        DC:AbortTransmogDefinitionsPaging("wardrobe_refresh")
    else
        -- Best-effort fallback.
        DC._transmogDefLoading = nil
        if DC._transmogPagingDelayFrame then
            DC._transmogPagingDelayFrame:Hide()
            DC._transmogPagingDelayFrame.pendingRequest = nil
        end
    end
    
    -- Request fresh data from server.
    -- Force: do NOT send syncVersion here; otherwise server may reply upToDate=true and send nothing,
    -- which looks like a stuck refresh after we just cleared the local cache.
    DC:Print("[Wardrobe] Refreshing transmog definitions from server...")
    local sent = DC:RequestDefinitions("transmog", 0)
    
    -- Set up completion handler
    local checkFrame = CreateFrame("Frame")
    checkFrame.elapsed = 0
    checkFrame.lastCount = 0
    checkFrame.stableChecks = 0
    checkFrame.totalTime = 0
    checkFrame.maxWaitNoData = 45    -- seconds until we retry if NOTHING arrives
    checkFrame.maxWaitAfterData = 120 -- seconds before we stop waiting but keep background paging
    checkFrame.gotAny = false
    checkFrame.retryCount = 0
    checkFrame.maxRetries = 3
    checkFrame.nextRetryAt = 12
    
    checkFrame:SetScript("OnUpdate", function(frame, elapsed)
        if not Wardrobe.isRefreshing then
            frame:Hide()
            return
        end
        
        frame.elapsed = frame.elapsed + elapsed
        frame.totalTime = frame.totalTime + elapsed

        -- If the initial request couldn't be sent (e.g., protocol not ready), retry periodically.
        if sent == false and frame.totalTime >= frame.nextRetryAt and not frame.gotAny then
            frame.retryCount = frame.retryCount + 1
            frame.nextRetryAt = frame.nextRetryAt + 12
            if type(DC.AbortTransmogDefinitionsPaging) == "function" then
                DC:AbortTransmogDefinitionsPaging("wardrobe_retry_no_send")
            end
            sent = DC:RequestDefinitions("transmog", 0)
        end
        
        -- No-data retry: if nothing arrives for a while, the request may have been dropped.
        -- Abort any stuck inflight state and resend (limited retries).
        if not frame.gotAny and frame.totalTime >= (frame.maxWaitNoData or 45) then
            frame.retryCount = (frame.retryCount or 0) + 1

            if frame.retryCount <= (frame.maxRetries or 3) then
                DC:Print(string.format("[Wardrobe] No data yet; retrying request (%d/%d)", frame.retryCount, frame.maxRetries or 3))
                if type(DC.AbortTransmogDefinitionsPaging) == "function" then
                    DC:AbortTransmogDefinitionsPaging("wardrobe_retry_no_data")
                end
                sent = DC:RequestDefinitions("transmog", 0)
                frame.totalTime = 0
                frame.elapsed = 0
                frame.lastCount = 0
                frame.stableChecks = 0
            else
                if DC and type(DC.LogNetEvent) == "function" then
                    DC:LogNetEvent("timeout", "wardrobe", "Refresh failed (no data received)", {
                        retries = frame.retryCount,
                        maxRetries = frame.maxRetries,
                    })
                end
                DC:Print("[Wardrobe] Refresh failed (no data received)")
                Wardrobe:CancelRefresh()
                frame:Hide()
                return
            end
        end

        -- If we have started receiving data, don't auto-cancel. If it's still paging for a long time,
        -- stop the active 'refresh' UI state but allow paging/progress to continue in the background.
        if frame.gotAny and frame.totalTime >= (frame.maxWaitAfterData or 120) then
            Wardrobe.isRefreshing = false

            if Wardrobe.frame and Wardrobe.frame.refreshBtn then
                Wardrobe.frame.refreshBtn:SetText("Refresh Data")
                Wardrobe.frame.refreshBtn:Enable()
            end
            if Wardrobe.frame and Wardrobe.frame.refreshStatus then
                Wardrobe.frame.refreshStatus:SetText("Continuing in background...")
                C_Timer.After(4, function()
                    if Wardrobe.frame and Wardrobe.frame.refreshStatus then
                        Wardrobe.frame.refreshStatus:Hide()
                    end
                end)
            end

            -- Keep the protocol progress bar behavior (it will hide when loading completes).
            Wardrobe:RefreshGrid()
            frame:Hide()
            return
        end
        
        -- Check every 0.5 seconds
        if frame.elapsed >= 0.5 then
            frame.elapsed = 0
            
            local currentCount = Wardrobe:GetTransmogDefinitionsLoadedCount()
            if currentCount > 0 then
                frame.gotAny = true
            end
            
            -- Update status
            if Wardrobe.frame and Wardrobe.frame.refreshStatus then
                local total = Wardrobe.GetTransmogDefinitionsTotalCount and Wardrobe:GetTransmogDefinitionsTotalCount() or nil
                if total and total > 0 then
                    local progress = math.floor((currentCount / total) * 100)
                    Wardrobe.frame.refreshStatus:SetText(string.format("Loading: %d/%d (%d%%)", currentCount, total, progress))
                else
                    Wardrobe.frame.refreshStatus:SetText(string.format("Loading: %d...", currentCount))
                end
            end

            if type(Wardrobe.UpdateTransmogLoadingProgressUI) == "function" then
                Wardrobe:UpdateTransmogLoadingProgressUI(true)
            end
            
            -- Check if loading is complete (count hasn't changed and not currently loading)
            if currentCount == frame.lastCount and currentCount > 0 and not DC._transmogDefLoading then
                frame.stableChecks = frame.stableChecks + 1
                
                -- If stable for 3 checks (1.5 seconds), we're done
                if frame.stableChecks >= 3 then
                    Wardrobe.isRefreshing = false
                    
                    if Wardrobe.frame and Wardrobe.frame.refreshBtn then
                        Wardrobe.frame.refreshBtn:SetText("Refresh Data")
                        Wardrobe.frame.refreshBtn:Enable()
                    end
                    
                    if Wardrobe.frame and Wardrobe.frame.refreshStatus then
                        Wardrobe.frame.refreshStatus:SetText(string.format("✓ Complete! %d definitions loaded", currentCount))
                        C_Timer.After(4, function()
                            if Wardrobe.frame and Wardrobe.frame.refreshStatus then
                                Wardrobe.frame.refreshStatus:Hide()
                            end
                        end)
                    end
                    
                    DC:Print(string.format("[Wardrobe] Refresh complete - %d transmog definitions loaded", currentCount))

                    if type(Wardrobe.UpdateTransmogLoadingProgressUI) == "function" then
                        Wardrobe:UpdateTransmogLoadingProgressUI(false)
                    end
                    
                    -- Refresh the grid
                    Wardrobe:RefreshGrid()
                    
                    frame:Hide()
                end
            else
                frame.stableChecks = 0
            end
            
            frame.lastCount = currentCount
        end
    end)
    
    checkFrame:Show()
end

function Wardrobe:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- ============================================================================
-- SLASH COMMAND
-- ============================================================================

SLASH_DCWARDROBE1 = "/wardrobe"
SLASH_DCWARDROBE2 = "/transmog"
SlashCmdList["DCWARDROBE"] = function()
    Wardrobe:Toggle()
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        -- Hook item tooltip early so "Appearance collected" shows without needing to open wardrobe first
        -- Try both events in case one fires before the other
        Wardrobe:HookItemTooltip()
    elseif Wardrobe.frame and Wardrobe.frame:IsShown() then
        Wardrobe:UpdateSlotButtons()
        Wardrobe:UpdateModel()
    end
end)
