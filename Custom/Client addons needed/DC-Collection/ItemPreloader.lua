--[[
    DC-Collection ItemPreloader.lua
    ===============================
    
    Preloads item information into the game cache to enable instant
    item name lookups for search functionality.
    
    Uses batch processing with hidden tooltips to avoid lag.
    Inspired by Thiesant's transmog system preloader.
]]

local DC = DCCollection
if not DC then return end

DC.ItemPreloader = DC.ItemPreloader or {}
local ItemPreloader = DC.ItemPreloader

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

ItemPreloader.Settings = {
    batchSize = 50,           -- Items to process per batch
    batchDelay = 0.05,        -- Delay between batches (seconds)
    enablePreload = true,     -- Enable/disable preloading
    showProgress = false,     -- Show progress messages (disabled by default to reduce spam)
}

-- ============================================================================
-- STATE
-- ============================================================================

ItemPreloader.queue = {}
ItemPreloader.currentIndex = 0
ItemPreloader.totalItems = 0
ItemPreloader.isRunning = false
ItemPreloader.scanTooltip = nil

-- ============================================================================
-- TOOLTIP CREATION
-- ============================================================================

function ItemPreloader:GetPreloadScanTooltip()
    if self.scanTooltip then
        return self.scanTooltip
    end
    
    -- Create hidden tooltip for scanning
    local tooltip = CreateFrame("GameTooltip", "DC_ItemPreloaderTooltip", UIParent, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:Hide()
    
    self.scanTooltip = tooltip
    return tooltip
end

-- ============================================================================
-- BATCH PROCESSING
-- ============================================================================

function ItemPreloader:ProcessPreloadBatch()
    if not self.isRunning or self.currentIndex >= self.totalItems then
        self.isRunning = false
        if self.Settings.showProgress and self.totalItems > 0 then
            print("|cff00ff00DC-Collection:|r Item preload complete! (" .. self.totalItems .. " items)")
        end
        return
    end
    
    local tooltip = self:GetPreloadScanTooltip()
    local batchEnd = math.min(self.currentIndex + self.Settings.batchSize, self.totalItems)
    
    for i = self.currentIndex + 1, batchEnd do
        local itemId = self.queue[i]
        if itemId and tonumber(itemId) then
            -- Use SetHyperlink to trigger item cache loading
            local itemLink = "item:" .. itemId
            tooltip:SetHyperlink(itemLink)
            tooltip:Hide()
        end
    end
    
    self.currentIndex = batchEnd
    
    -- Show progress every 500 items
    if self.Settings.showProgress and self.currentIndex % 500 == 0 then
        local percent = math.floor((self.currentIndex / self.totalItems) * 100)
        print(string.format("|cff00ff00DC-Collection:|r Preloading items... %d/%d (%d%%)", 
            self.currentIndex, self.totalItems, percent))
    end
    
    -- Schedule next batch
    C_Timer.After(self.Settings.batchDelay, function()
        self:ProcessPreloadBatch()
    end)
end

-- ============================================================================
-- PRELOAD INITIATION
-- ============================================================================

function ItemPreloader:PreloadCachedItemInfo()
    if not self.Settings.enablePreload then
        return
    end
    
    if self.isRunning then
        return
    end
    
    -- Build queue from TransmogModule cache
    self.queue = {}
    
    if DC.TransmogModule and DC.TransmogModule.cache then
        local cache = DC.TransmogModule.cache
        
        -- Collect all item IDs from appearances
        if cache.appearances then
            for _, appearance in pairs(cache.appearances) do
                if appearance.itemId and tonumber(appearance.itemId) then
                    table.insert(self.queue, appearance.itemId)
                end
            end
        end
        
        -- Collect from sets
        if cache.sets then
            for _, set in pairs(cache.sets) do
                if set.items then
                    for _, item in pairs(set.items) do
                        if item.itemId and tonumber(item.itemId) then
                            table.insert(self.queue, item.itemId)
                        end
                    end
                end
            end
        end
    end
    
    -- Remove duplicates by converting to set and back
    local seen = {}
    local uniqueQueue = {}
    for _, itemId in ipairs(self.queue) do
        if not seen[itemId] then
            seen[itemId] = true
            table.insert(uniqueQueue, itemId)
        end
    end
    
    self.queue = uniqueQueue
    self.totalItems = #self.queue
    self.currentIndex = 0
    
    if self.totalItems == 0 then
        return
    end
    
    if self.Settings.showProgress then
        print("|cff00ff00DC-Collection:|r Starting item preload (" .. self.totalItems .. " items)")
    end
    
    self.isRunning = true
    self:ProcessPreloadBatch()
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function ItemPreloader:Initialize()
    -- Wait for player to login and cache to be available
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    
    frame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_LOGIN" then
            -- Delay preload to let other addons initialize first
            C_Timer.After(2, function()
                ItemPreloader:PreloadCachedItemInfo()
            end)
            
            self:UnregisterAllEvents()
        end
    end)
end

-- Initialize on load
ItemPreloader:Initialize()
