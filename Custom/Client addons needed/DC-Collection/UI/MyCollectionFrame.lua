--[[
    DC-Collection UI/MyCollectionFrame.lua
    ======================================

    "My Collection" Overview Tab
    Shows statistics per collectable type and recent additions.

    Features:
    - Collection statistics cards (mounts, pets, appearances, titles, etc.)
    - Recent additions carousel with mixed icons
    - Progress bars per category
    - Quick access to each collection type

    Author: DarkChaos-255
    Version: 1.0.0
    
    3.3.5a Compatibility Notes:
    - Uses standard WoW 3.3.5a API
    - GetItemInfo returns: name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture
    - GetSpellInfo returns: name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange
    - No C_* APIs available in 3.3.5a
]]

local DC = DCCollection
local L = DC and DC.L or {}

local MyCollection = {}
DC.MyCollection = MyCollection

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local STAT_CARD_WIDTH = 150
local STAT_CARD_HEIGHT = 80
local RECENT_ICON_SIZE = 48
local MAX_RECENT_ITEMS = 12

-- Collection type definitions with icons and display info
local COLLECTION_TYPES = {
    { key = "mounts",    name = "Mounts",      icon = "Interface\\Icons\\Ability_Mount_RidingHorse",       color = {0.4, 0.8, 1.0} },
    { key = "pets",      name = "Companions",  icon = "Interface\\Icons\\INV_Box_PetCarrier_01",           color = {0.2, 0.9, 0.4} },
    { key = "transmog",  name = "Appearances", icon = "Interface\\Icons\\INV_Chest_Cloth_17",              color = {0.9, 0.6, 0.2} },
    { key = "titles",    name = "Titles",      icon = "Interface\\Icons\\INV_Scroll_11",                   color = {0.8, 0.8, 0.2} },
    { key = "heirlooms", name = "Heirlooms",   icon = "Interface\\Icons\\INV_Sword_43",                    color = {0.9, 0.8, 0.5} },
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function SafeGetText(key, fallback)
    if L and L[key] and L[key] ~= "" then
        return L[key]
    end
    return fallback
end

local function FormatNumber(num)
    if not num or num == 0 then return "0" end
    if num >= 1000 then
        return string.format("%.1fk", num / 1000)
    end
    return tostring(num)
end

local function GetCollectionStats(collType)
    -- Returns { collected = X, total = Y } from server data
    local stats = DC.collectionStats or {}
    local typeStats = stats[collType] or {}
    
    return {
        collected = typeStats.collected or 0,
        total = typeStats.total or 0,
    }
end

local function GetRecentAdditions()
    -- Returns array of { type, id, name, icon, timestamp } sorted by most recent
    local recent = DC.recentAdditions or {}
    
    -- Sort by timestamp descending
    table.sort(recent, function(a, b)
        return (a.timestamp or 0) > (b.timestamp or 0)
    end)
    
    return recent
end

-- ============================================================================
-- FRAME CREATION
-- ============================================================================

function MyCollection:Create(parent)
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "DCMyCollectionFrame", parent)
    frame:SetAllPoints(parent)
    frame:Hide()

    -- Header
    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    header:SetText("My Collection")
    frame.header = header

    -- Refresh button (fallback when initial sync hasn't populated yet)
    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(90, 22)
    refreshBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -10)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        if DC and type(DC.RequestInitialDataWithRetry) == "function" then
            DC:RequestInitialDataWithRetry(8, 1)
        elseif DC and type(DC.RequestInitialData) == "function" then
            DC:RequestInitialData(false)
        elseif DC and type(DC.RequestStats) == "function" then
            DC:RequestStats()
        end
    end)
    frame.refreshBtn = refreshBtn

    local loadingText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    loadingText:SetPoint("TOPRIGHT", refreshBtn, "BOTTOMRIGHT", 0, -6)
    loadingText:SetJustifyH("RIGHT")
    loadingText:SetTextColor(0.8, 0.8, 0.8)
    loadingText:SetText("Loading...")
    loadingText:Hide()
    frame.loadingText = loadingText

    -- Stats container
    local statsContainer = CreateFrame("Frame", nil, frame)
    statsContainer:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -15)
    statsContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, 0)
    statsContainer:SetHeight(STAT_CARD_HEIGHT * 2 + 20)
    frame.statsContainer = statsContainer

    -- Create stat cards
    frame.statCards = {}
    self:CreateStatCards(frame)

    -- Recent Additions section
    local recentHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    recentHeader:SetPoint("TOPLEFT", statsContainer, "BOTTOMLEFT", 0, -20)
    recentHeader:SetText("Recent Additions")
    frame.recentHeader = recentHeader

    -- Recent additions container
    local recentContainer = CreateFrame("Frame", nil, frame)
    recentContainer:SetPoint("TOPLEFT", recentHeader, "BOTTOMLEFT", 0, -10)
    recentContainer:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    recentContainer:SetHeight(RECENT_ICON_SIZE + 30)
    
    recentContainer.bg = recentContainer:CreateTexture(nil, "BACKGROUND")
    recentContainer.bg:SetAllPoints()
    recentContainer.bg:SetTexture(0, 0, 0, 0.3)
    
    frame.recentContainer = recentContainer
    frame.recentIcons = {}
    self:CreateRecentIcons(frame)

    self.frame = frame
    return frame
end

-- ============================================================================
-- STAT CARDS
-- ============================================================================

function MyCollection:CreateStatCards(parent)
    local container = parent.statsContainer
    local cols = 3
    local padding = 10
    local cardWidth = STAT_CARD_WIDTH
    local cardHeight = STAT_CARD_HEIGHT

    local total = #COLLECTION_TYPES

    for i, typeDef in ipairs(COLLECTION_TYPES) do
        local row = math.floor((i - 1) / cols)
        local col = (i - 1) % cols

        -- Center the last row if it has fewer than 'cols' items
        local rowFirstIndex = row * cols + 1
        local remaining = total - rowFirstIndex + 1
        local itemsInRow = math.min(cols, remaining)
        local offsetX = 0
        if itemsInRow < cols then
            offsetX = ((cols - itemsInRow) * (cardWidth + padding)) / 2
        end

        local card = CreateFrame("Button", nil, container)
        card:SetSize(cardWidth, cardHeight)
        card:SetPoint("TOPLEFT", container, "TOPLEFT", offsetX + col * (cardWidth + padding), -row * (cardHeight + padding))
        card.typeDef = typeDef

        -- Background
        card.bg = card:CreateTexture(nil, "BACKGROUND")
        card.bg:SetAllPoints()
        card.bg:SetTexture(0.1, 0.1, 0.1, 0.8)

        -- Border highlight
        card.border = card:CreateTexture(nil, "BORDER")
        card.border:SetPoint("TOPLEFT", -1, 1)
        card.border:SetPoint("BOTTOMRIGHT", 1, -1)
        card.border:SetTexture(typeDef.color[1], typeDef.color[2], typeDef.color[3], 0.3)

        -- Icon
        card.icon = card:CreateTexture(nil, "ARTWORK")
        card.icon:SetSize(32, 32)
        card.icon:SetPoint("LEFT", card, "LEFT", 10, 0)
        card.icon:SetTexture(typeDef.icon)

        -- Name
        card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, 0)
        card.name:SetText(typeDef.name)
        card.name:SetTextColor(typeDef.color[1], typeDef.color[2], typeDef.color[3])

        -- Count text
        card.count = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        card.count:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -5)
        card.count:SetText("0 / 0")

        -- Mini progress bar
        card.bar = CreateFrame("StatusBar", nil, card)
        card.bar:SetSize(cardWidth - 54, 6)
        card.bar:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 44, 10)
        card.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        card.bar:SetStatusBarColor(typeDef.color[1], typeDef.color[2], typeDef.color[3])
        card.bar:SetMinMaxValues(0, 1)
        card.bar:SetValue(0)

        card.bar.bg = card.bar:CreateTexture(nil, "BACKGROUND")
        card.bar.bg:SetAllPoints()
        card.bar.bg:SetTexture(0, 0, 0, 0.5)

        -- Click to open that collection tab
        card:SetScript("OnClick", function()
            if typeDef.key == "transmog" then
                if DC.Wardrobe then
                    DC.Wardrobe:Show()
                end
            elseif DC.SelectTab then
                DC:SelectTab(typeDef.key)
            end
        end)

        card:SetScript("OnEnter", function(self)
            self.bg:SetTexture(0.2, 0.2, 0.2, 0.9)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(typeDef.name)
            local stats = GetCollectionStats(typeDef.key)
            GameTooltip:AddLine(string.format("Collected: %d / %d", stats.collected, stats.total), 1, 1, 1)
            if stats.total > 0 then
                local pct = math.floor((stats.collected / stats.total) * 100)
                GameTooltip:AddLine(string.format("Progress: %d%%", pct), 0.7, 0.7, 0.7)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to view", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)

        card:SetScript("OnLeave", function(self)
            self.bg:SetTexture(0.1, 0.1, 0.1, 0.8)
            GameTooltip:Hide()
        end)

        parent.statCards[typeDef.key] = card
    end
end

-- ============================================================================
-- RECENT ADDITIONS ICONS
-- ============================================================================

function MyCollection:CreateRecentIcons(parent)
    local container = parent.recentContainer
    local padding = 8

    for i = 1, MAX_RECENT_ITEMS do
        local btn = CreateFrame("Button", nil, container)
        btn:SetSize(RECENT_ICON_SIZE, RECENT_ICON_SIZE)
        btn:SetPoint("LEFT", container, "LEFT", (i - 1) * (RECENT_ICON_SIZE + padding) + 10, 0)
        btn.index = i

        -- Background
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture(0, 0, 0, 0.5)

        -- Icon
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetPoint("TOPLEFT", 2, -2)
        btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

        -- Type indicator (small colored dot)
        btn.typeIndicator = btn:CreateTexture(nil, "OVERLAY")
        btn.typeIndicator:SetSize(8, 8)
        btn.typeIndicator:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
        btn.typeIndicator:SetTexture("Interface\\BUTTONS\\WHITE8x8")
        btn.typeIndicator:SetVertexColor(1, 1, 1)

        -- Border for rarity
        btn.rarityBorder = btn:CreateTexture(nil, "BORDER")
        btn.rarityBorder:SetPoint("TOPLEFT", -1, 1)
        btn.rarityBorder:SetPoint("BOTTOMRIGHT", 1, -1)
        btn.rarityBorder:SetTexture(1, 1, 1, 0.3)

        -- "NEW" badge
        btn.newBadge = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.newBadge:SetPoint("TOP", btn, "TOP", 0, -2)
        btn.newBadge:SetText("NEW")
        btn.newBadge:SetTextColor(0.1, 1, 0.1)
        btn.newBadge:Hide()

        btn:SetScript("OnEnter", function(self)
            if not self.itemData then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            
            local data = self.itemData
            GameTooltip:AddLine(data.name or "Unknown", 1, 1, 1)
            
            -- Show type
            local typeColor = {1, 1, 1}
            for _, typeDef in ipairs(COLLECTION_TYPES) do
                if typeDef.key == data.type then
                    typeColor = typeDef.color
                    GameTooltip:AddLine(typeDef.name, typeColor[1], typeColor[2], typeColor[3])
                    break
                end
            end

            -- If item, show item tooltip
            if data.itemId then
                GameTooltip:AddLine(" ")
                GameTooltip:SetHyperlink("item:" .. data.itemId)
            elseif data.spellId then
                GameTooltip:AddLine(" ")
                local spellName = GetSpellInfo(data.spellId)
                if spellName then
                    GameTooltip:AddLine("Spell: " .. spellName, 0.7, 0.7, 0.7)
                end
            end

            -- Timestamp
            if data.timestamp then
                local ago = time() - data.timestamp
                local agoText = "just now"
                if ago > 86400 then
                    agoText = math.floor(ago / 86400) .. " days ago"
                elseif ago > 3600 then
                    agoText = math.floor(ago / 3600) .. " hours ago"
                elseif ago > 60 then
                    agoText = math.floor(ago / 60) .. " minutes ago"
                end
                GameTooltip:AddLine("Added: " .. agoText, 0.5, 0.5, 0.5)
            end

            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        btn:SetScript("OnClick", function(self)
            if not self.itemData then return end
            local data = self.itemData
            
            -- Navigate to that collection type
            if data.type == "transmog" then
                if DC.Wardrobe then
                    DC.Wardrobe:Show()
                end
            elseif DC.SelectTab then
                DC:SelectTab(data.type)
            end
        end)

        btn:Hide()
        table.insert(parent.recentIcons, btn)
    end
end

-- ============================================================================
-- PROGRESS BARS
-- ============================================================================

function MyCollection:CreateProgressBars(parent)
    local container = parent.progressContainer
    local barHeight = 20
    local padding = 5

    for i, typeDef in ipairs(COLLECTION_TYPES) do
        local barFrame = CreateFrame("Frame", nil, container)
        barFrame:SetSize(container:GetWidth() or 400, barHeight)
        barFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(i - 1) * (barHeight + padding))
        barFrame.typeDef = typeDef

        -- Label
        barFrame.label = barFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        barFrame.label:SetPoint("LEFT", barFrame, "LEFT", 0, 0)
        barFrame.label:SetWidth(80)
        barFrame.label:SetJustifyH("LEFT")
        barFrame.label:SetText(typeDef.name)
        barFrame.label:SetTextColor(typeDef.color[1], typeDef.color[2], typeDef.color[3])

        -- Progress bar
        barFrame.bar = CreateFrame("StatusBar", nil, barFrame)
        barFrame.bar:SetPoint("LEFT", barFrame.label, "RIGHT", 10, 0)
        barFrame.bar:SetSize(200, barHeight - 4)
        barFrame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        barFrame.bar:SetStatusBarColor(typeDef.color[1], typeDef.color[2], typeDef.color[3])
        barFrame.bar:SetMinMaxValues(0, 1)
        barFrame.bar:SetValue(0)

        barFrame.bar.bg = barFrame.bar:CreateTexture(nil, "BACKGROUND")
        barFrame.bar.bg:SetAllPoints()
        barFrame.bar.bg:SetTexture(0.1, 0.1, 0.1, 0.8)

        -- Percentage text
        barFrame.pct = barFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        barFrame.pct:SetPoint("LEFT", barFrame.bar, "RIGHT", 10, 0)
        barFrame.pct:SetText("0%")

        -- Count text
        barFrame.countText = barFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        barFrame.countText:SetPoint("LEFT", barFrame.pct, "RIGHT", 10, 0)
        barFrame.countText:SetText("(0/0)")
        barFrame.countText:SetTextColor(0.7, 0.7, 0.7)

        parent.progressBars[typeDef.key] = barFrame
    end
end

-- ============================================================================
-- UPDATE FUNCTIONS
-- ============================================================================

function MyCollection:Update()
    if not self.frame or not self.frame:IsShown() then return end

    -- If stats haven't arrived yet, show a small loading hint.
    local hasAnyTotals = false
    if DC and DC.collectionStats then
        for _, typeDef in ipairs(COLLECTION_TYPES) do
            local s = DC.collectionStats[typeDef.key]
            if s and type(s) == "table" and (s.total or 0) > 0 then
                hasAnyTotals = true
                break
            end
        end
    end

    if self.frame.loadingText then
        local shouldShow = not hasAnyTotals
        if type(self.frame.loadingText.SetShown) == "function" then
            self.frame.loadingText:SetShown(shouldShow)
        else
            if shouldShow then
                self.frame.loadingText:Show()
            else
                self.frame.loadingText:Hide()
            end
        end
    end

    self:UpdateStatCards()
    self:UpdateRecentIcons()
    self:UpdateProgressBars()
end

function MyCollection:UpdateStatCards()
    if not self.frame or not self.frame.statCards then return end

    for key, card in pairs(self.frame.statCards) do
        local stats = GetCollectionStats(key)
        card.count:SetText(string.format("%d / %d", stats.collected, stats.total))

        local pct = 0
        if stats.total > 0 then
            pct = stats.collected / stats.total
        end
        card.bar:SetValue(pct)
    end
end

function MyCollection:UpdateRecentIcons()
    if not self.frame or not self.frame.recentIcons then return end

    local recent = GetRecentAdditions()

    for i, btn in ipairs(self.frame.recentIcons) do
        local data = recent[i]

        if data then
            btn:Show()
            btn.itemData = data

            -- Set icon
            local icon = data.icon
            if not icon and data.itemId then
                icon = select(10, GetItemInfo(data.itemId))
            end
            if not icon and data.spellId then
                icon = select(3, GetSpellInfo(data.spellId))
            end
            btn.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")

            -- Set type indicator color
            local typeColor = {0.5, 0.5, 0.5}
            for _, typeDef in ipairs(COLLECTION_TYPES) do
                if typeDef.key == data.type then
                    typeColor = typeDef.color
                    break
                end
            end
            btn.typeIndicator:SetVertexColor(typeColor[1], typeColor[2], typeColor[3])

            -- Show NEW badge for items added in last 24 hours
            if data.timestamp and (time() - data.timestamp) < 86400 then
                btn.newBadge:Show()
            else
                btn.newBadge:Hide()
            end

            -- Rarity border
            if data.rarity and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[data.rarity] then
                local c = ITEM_QUALITY_COLORS[data.rarity]
                btn.rarityBorder:SetVertexColor(c.r, c.g, c.b, 0.6)
            else
                btn.rarityBorder:SetVertexColor(1, 1, 1, 0.2)
            end
        else
            btn:Hide()
            btn.itemData = nil
        end
    end
end

function MyCollection:UpdateProgressBars()
    if not self.frame or not self.frame.progressBars then return end

    for key, barFrame in pairs(self.frame.progressBars) do
        local stats = GetCollectionStats(key)

        local pct = 0
        if stats.total > 0 then
            pct = stats.collected / stats.total
        end

        barFrame.bar:SetValue(pct)
        barFrame.pct:SetText(string.format("%d%%", math.floor(pct * 100)))
        barFrame.countText:SetText(string.format("(%d/%d)", stats.collected, stats.total))
    end
end

-- ============================================================================
-- SHOW / HIDE
-- ============================================================================

function MyCollection:Show()
    if not self.frame then
        return
    end

    -- Request fresh stats from server
    if DC and type(DC.RequestInitialDataWithRetry) == "function" then
        DC:RequestInitialDataWithRetry(8, 1)
    elseif DC and DC.RequestStats then
        DC:RequestStats()
    end
    if DC and DC.RequestRecentAdditions then
        DC:RequestRecentAdditions()
    end

    self.frame:Show()
    self:Update()
end

function MyCollection:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

-- ============================================================================
-- REQUEST FUNCTIONS (Protocol integration)
-- ============================================================================

function DC:RequestStats()
    if self.SendMessage then
        self:SendMessage(self.Opcodes.CMSG_GET_STATS, {})
    end
end

function DC:RequestRecentAdditions()
    -- This could be a new opcode or part of stats response
    -- For now, we'll use local cache or request via stats
    if self.SendMessage then
        self:SendMessage(self.Opcodes.CMSG_GET_STATS, { includeRecent = true })
    end
end

-- ============================================================================
-- HANDLER FOR STATS RESPONSE
-- ============================================================================

-- This should be called when SMSG_STATS is received
function DC:HandleStatsResponse(data)
    if not data then return end

    -- Store stats
    self.collectionStats = self.collectionStats or {}
    
    if data.mounts then
        self.collectionStats.mounts = { collected = data.mounts.collected or 0, total = data.mounts.total or 0 }
    end
    if data.pets then
        local collected = data.pets.collected or 0
        local total = data.pets.total or 0

        -- Prefer local companion ownership if the server stats aren't synced yet.
        if self.PetModule and type(self.PetModule.GetStats) == "function" then
            if type(self.PetModule.RefreshKnownPetsCache) == "function" then
                pcall(self.PetModule.RefreshKnownPetsCache, self.PetModule)
            end
            local ok, stats = pcall(self.PetModule.GetStats, self.PetModule)
            if ok and type(stats) == "table" then
                if type(stats.owned) == "number" and stats.owned > collected then
                    collected = stats.owned
                end
                if (not total or total == 0) and type(stats.total) == "number" and stats.total > 0 then
                    total = stats.total
                end
            end
        end

        self.collectionStats.pets = { collected = collected, total = total }
    end
    if data.transmog then
        self.collectionStats.transmog = { collected = data.transmog.collected or 0, total = data.transmog.total or 0 }
    end
    if data.titles then
        self.collectionStats.titles = { collected = data.titles.collected or 0, total = data.titles.total or 0 }
    end
    if data.heirlooms then
        local collected = data.heirlooms.collected or 0
        local total = data.heirlooms.total or 0

        if self.HeirloomModule and type(self.HeirloomModule.GetStats) == "function" then
            local ok, stats = pcall(self.HeirloomModule.GetStats, self.HeirloomModule)
            if ok and type(stats) == "table" then
                if type(stats.owned) == "number" and stats.owned > collected then
                    collected = stats.owned
                end
                if (not total or total == 0) and type(stats.total) == "number" and stats.total > 0 then
                    total = stats.total
                end
            end
        end

        self.collectionStats.heirlooms = { collected = collected, total = total }
    end
    if data.toys then
        self.collectionStats.toys = { collected = data.toys.collected or 0, total = data.toys.total or 0 }
    end

    -- Store recent additions
    if data.recent then
        self.recentAdditions = data.recent
    end

    -- Update UI
    if self.MyCollection then
        self.MyCollection:Update()
    end
end
