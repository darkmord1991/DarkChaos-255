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
-- CONSTANTS / DATA TABLES
-- ============================================================================

Wardrobe.FRAME_WIDTH = 1000
Wardrobe.FRAME_HEIGHT = 650
Wardrobe.MODEL_WIDTH = 250
Wardrobe.SLOT_SIZE = 36
Wardrobe.GRID_ICON_SIZE = 46
Wardrobe.GRID_COLS = 6
Wardrobe.GRID_ROWS = 3
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
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Head",     invTypes = { [1] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shoulder", invTypes = { [3] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",    invTypes = { [5] = true, [20] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shirt",    invTypes = { [4] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Tabard",   invTypes = { [19] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Wrists",   invTypes = { [9] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Hands",    invTypes = { [10] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Waist",    invTypes = { [6] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Legs",     invTypes = { [7] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Feet",     invTypes = { [8] = true } },
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",    invTypes = { [16] = true } }, -- Back uses chest icon
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand", invTypes = { [13] = true, [17] = true, [21] = true } }, -- Weapon, 2H, MainHand
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand", invTypes = { [13] = true, [14] = true, [17] = true, [22] = true, [23] = true } }, -- Weapon, Shield, 2H, OffHand, Holdable
    { icon = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ranged",   invTypes = { [15] = true, [25] = true, [26] = true, [28] = true } }, -- Ranged, Thrown, RangedRight, Relic
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

Wardrobe.currentTab = Wardrobe.currentTab or "items" -- "items", "sets", "outfits"
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

function Wardrobe:IsAppearanceCollected(itemId)
    if not DC or not DC.collections or not DC.collections.transmog then
        return false
    end
    return DC.collections.transmog[itemId] ~= nil
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

    local function AddCollectedLine(tooltip, itemId)
        if not itemId or itemId == 0 then return end

        if self:IsAppearanceCollected(itemId) then
            tooltip:AddLine(" ")
            tooltip:AddLine("You've collected this appearance", 0.1, 1, 0.1)
            tooltip:Show()
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

function Wardrobe:Hide()
    if self.frame then
        self.frame:Hide()
    end
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
    
    -- Clear transmog definitions cache
    if DC._transmogDefinitions then
        DC._transmogDefinitions = {}
    end
    
    if DC.definitions and DC.definitions.transmog then
        DC.definitions.transmog = {}
    end
    
    -- Reset paging state
    DC._transmogDefOffset = 0
    DC._transmogDefLimit = 2000
    DC._transmogDefLoading = nil
    DC._transmogDefLastRequestedOffset = nil
    DC._transmogDefLastRequestedLimit = nil
    DC._transmogDefPagesFetched = 0
    
    -- Clear delay frame if exists
    if DC._transmogPagingDelayFrame then
        DC._transmogPagingDelayFrame:Hide()
        DC._transmogPagingDelayFrame.pendingRequest = nil
    end
    
    -- Request fresh data from server
    DC:Print("[Wardrobe] Refreshing transmog definitions from server (this may take ~5 seconds)...")
    DC:RequestDefinitions("transmog")
    
    -- Set up completion handler
    local checkFrame = CreateFrame("Frame")
    checkFrame.elapsed = 0
    checkFrame.lastCount = 0
    checkFrame.stableChecks = 0
    checkFrame.totalTime = 0
    checkFrame.maxWaitTime = 15 -- Timeout after 15 seconds
    
    checkFrame:SetScript("OnUpdate", function(frame, elapsed)
        if not Wardrobe.isRefreshing then
            frame:Hide()
            return
        end
        
        frame.elapsed = frame.elapsed + elapsed
        frame.totalTime = frame.totalTime + elapsed
        
        -- Timeout check
        if frame.totalTime >= frame.maxWaitTime then
            DC:Print("[Wardrobe] Refresh timed out after 15 seconds")
            Wardrobe:CancelRefresh()
            frame:Hide()
            return
        end
        
        -- Check every 0.5 seconds
        if frame.elapsed >= 0.5 then
            frame.elapsed = 0
            
            local currentCount = DC:TableCount(DC._transmogDefinitions or {})
            
            -- Update status
            if Wardrobe.frame and Wardrobe.frame.refreshStatus then
                local progress = math.floor((currentCount / 19085) * 100)
                Wardrobe.frame.refreshStatus:SetText(string.format("Loading: %d/%d (%d%%)", currentCount, 19085, progress))
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

function Wardrobe:RefreshTransmogDefinitions()
    if not DC then return end
    
    -- Set refreshing flag
    self.isRefreshing = true
    
    -- Update UI
    if self.frame and self.frame.refreshBtn then
        self.frame.refreshBtn:SetText("Refreshing...")
        self.frame.refreshBtn:Disable()
    end
    
    if self.frame and self.frame.refreshStatus then
        self.frame.refreshStatus:SetText("Loading definitions...")
        self.frame.refreshStatus:Show()
    end
    
    -- Clear transmog definitions cache
    if DC._transmogDefinitions then
        DC._transmogDefinitions = {}
    end
    
    if DC.definitions and DC.definitions.transmog then
        DC.definitions.transmog = {}
    end
    
    -- Reset paging state
    DC._transmogDefOffset = 0
    DC._transmogDefLimit = 2000
    DC._transmogDefLoading = nil
    DC._transmogDefLastRequestedOffset = nil
    DC._transmogDefLastRequestedLimit = nil
    DC._transmogDefPagesFetched = 0
    
    -- Clear delay frame if exists
    if DC._transmogPagingDelayFrame then
        DC._transmogPagingDelayFrame:Hide()
        DC._transmogPagingDelayFrame.pendingRequest = nil
    end
    
    -- Request fresh data from server
    DC:Print("[Wardrobe] Refreshing transmog definitions from server...")
    DC:RequestDefinitions("transmog")
    
    -- Set up completion handler
    local checkFrame = CreateFrame("Frame")
    checkFrame.elapsed = 0
    checkFrame.lastCount = 0
    checkFrame.stableChecks = 0
    
    checkFrame:SetScript("OnUpdate", function(frame, elapsed)
        frame.elapsed = frame.elapsed + elapsed
        
        -- Check every 0.5 seconds
        if frame.elapsed >= 0.5 then
            frame.elapsed = 0
            
            local currentCount = DC:TableCount(DC._transmogDefinitions or {})
            
            -- Update status
            if Wardrobe.frame and Wardrobe.frame.refreshStatus then
                Wardrobe.frame.refreshStatus:SetText(string.format("Loaded %d definitions...", currentCount))
            end
            
            -- Check if loading is complete (count hasn't changed)
            if currentCount == frame.lastCount and currentCount > 0 then
                frame.stableChecks = frame.stableChecks + 1
                
                -- If stable for 2 checks (1 second), we're done
                if frame.stableChecks >= 2 then
                    Wardrobe.isRefreshing = false
                    
                    if Wardrobe.frame and Wardrobe.frame.refreshBtn then
                        Wardrobe.frame.refreshBtn:SetText("Refresh Data")
                        Wardrobe.frame.refreshBtn:Enable()
                    end
                    
                    if Wardrobe.frame and Wardrobe.frame.refreshStatus then
                        Wardrobe.frame.refreshStatus:SetText(string.format("Complete! %d definitions loaded", currentCount))
                        C_Timer.After(3, function()
                            if Wardrobe.frame and Wardrobe.frame.refreshStatus then
                                Wardrobe.frame.refreshStatus:Hide()
                            end
                        end)
                    end
                    
                    DC:Print(string.format("[Wardrobe] Refresh complete - %d transmog definitions loaded", currentCount))
                    
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
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:SetScript("OnEvent", function()
    if Wardrobe.frame and Wardrobe.frame:IsShown() then
        Wardrobe:UpdateSlotButtons()
        Wardrobe:UpdateModel()
    end
end)
