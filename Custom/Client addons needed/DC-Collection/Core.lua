--[[
    DC-Collection Core.lua
    ======================
    
    Main addon initialization, settings, and slash commands.
    Handles DCAddonProtocol integration and event management.
    
    Author: DarkChaos-255
    Version: 1.0.0
]]

-- Global namespace
DCCollection = DCCollection or {}
local DC = DCCollection
local L = DC.L

-- ============================================================================
-- VERSION & CONSTANTS
-- ============================================================================

DC.VERSION = "1.0.0"
DC.MODULE_ID = "COLL"  -- DCAddonProtocol module identifier

-- Collection types
DC.CollectionType = {
    MOUNT = "mount",
    PET = "pet",
    HEIRLOOM = "heirloom",
    TRANSMOG = "transmog",
    TITLE = "title",
}

-- Rarity colors
DC.RarityColors = {
    [0] = { r = 0.62, g = 0.62, b = 0.62, hex = "|cff9d9d9d" },  -- Poor/Common
    [1] = { r = 1.00, g = 1.00, b = 1.00, hex = "|cffffffff" },  -- Common
    [2] = { r = 0.12, g = 1.00, b = 0.00, hex = "|cff1eff00" },  -- Uncommon
    [3] = { r = 0.00, g = 0.44, b = 0.87, hex = "|cff0070dd" },  -- Rare
    [4] = { r = 0.64, g = 0.21, b = 0.93, hex = "|cffa335ee" },  -- Epic
    [5] = { r = 1.00, g = 0.50, b = 0.00, hex = "|cffff8000" },  -- Legendary
}

-- Mount types
DC.MountType = {
    GROUND = 0,
    FLYING = 1,
    AQUATIC = 2,
    ALL = 3,
}

-- ============================================================================
-- SAVED VARIABLES DEFAULTS
-- ============================================================================

local defaults = {
    -- Display settings
    showMinimapButton = true,
    minimapButtonAngle = 180,
    showCollectionNotifications = true,
    showWishlistAlerts = true,
    playSounds = true,
    
    -- Filter settings
    defaultFilter = "all",
    rememberFilters = true,
    
    -- Grid settings
    gridColumns = 5,
    gridIconSize = 48,
    showTooltips = true,
    
    -- Communication
    enableServerSync = true,
    autoSyncOnLogin = true,
    debugMode = false,

    -- Wardrobe/transmog background sync
    -- When enabled, the addon will periodically check for transmog updates and allow paging
    -- to continue even if the UI is not open.
    backgroundWardrobeSync = true,

    -- Network error/timeout log (SavedVariables ring buffer)
    -- Stores only recent events to help diagnose refresh failures.
    netEventLogMaxEntries = 200,
    
    -- Cache
    lastSyncTime = 0,
    syncVersion = 0,

    -- Transmog outfits storage scope: "char" (per-character) or "account" (account-wide)
    outfitsScope = "char",
}

local charDefaults = {
    -- Last viewed tab per character
    lastTab = "mounts",
    
    -- Filter states (if rememberFilters)
    filters = {},
    
    -- UI state
    framePosition = nil,
}

-- ============================================================================
-- COLLECTION DATA
-- ============================================================================

-- Cached collection data
DC.collections = {
    mounts = {},
    pets = {},
    heirlooms = {},
    transmog = {},
    titles = {},
}

-- Definition data (from server)
DC.definitions = {
    mounts = {},
    pets = {},
    heirlooms = {},
    transmog = {},
    titles = {},
    itemSets = {},
    sets = {},
}

-- Statistics
DC.stats = {
    mounts = { owned = 0, total = 0 },
    pets = { owned = 0, total = 0 },
    heirlooms = { owned = 0, total = 0 },
    transmog = { owned = 0, total = 0 },
    titles = { owned = 0, total = 0 },
}

-- Collection stats for My Collection overview (dynamic from server)
DC.collectionStats = {}

-- Recent additions for My Collection overview
DC.recentAdditions = {}

function DC:SetRecentAdditions(recent)
    if type(recent) ~= "table" then
        return
    end

    self.recentAdditions = recent

    if DCCollectionDB then
        DCCollectionDB.recentAdditions = recent
        DCCollectionDB.recentAdditionsUpdatedAt = time()
    end
end

-- Currency
DC.currency = {
    tokens = 0,
    emblems = 0,
}

-- Wishlist
DC.wishlist = {}

-- Mount speed bonus
DC.mountSpeedBonus = 0

-- Per-character applied transmog (slot -> appearanceId/displayId)
DC.transmogState = {}

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

DC.isLoaded = false
DC.isDataReady = false
DC.pendingRequests = {}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

function DC:Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC-Collection]|r " .. tostring(msg or ""))
    end
end

function DC:Debug(msg)
    if DCCollectionDB and DCCollectionDB.debugMode then
        self:Print("|cff888888[Debug]|r " .. tostring(msg or ""))
    end
end

function DC:GetRarityColor(rarity)
    return self.RarityColors[rarity] or self.RarityColors[0]
end

function DC:FormatNumber(num)
    if not num then return "0" end
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    end
    return tostring(num)
end

function DC:FormatCurrency(tokens, emblems)
    local parts = {}
    if tokens and tokens > 0 then
        table.insert(parts, "|cffffd700" .. self:FormatNumber(tokens) .. "|r " .. L.CURRENCY_TOKENS)
    end
    if emblems and emblems > 0 then
        table.insert(parts, "|cffa335ee" .. self:FormatNumber(emblems) .. "|r " .. L.CURRENCY_EMBLEMS)
    end
    return table.concat(parts, " + ")
end

-- Centralized currency getter.
-- Prefers DCAddonProtocol's shared balance (when present), falls back to DC.currency.
function DC:GetCurrencyBalances()
    local tokens, essence

    local central = rawget(_G, "DCAddonProtocol")
    if central then
        -- Common patterns used across DC addons.
        local getters = {
            central.GetServerCurrencyBalance,
            central.GetCurrencyBalance,
            central.GetCurrencyBalances,
        }

        for _, getter in ipairs(getters) do
            if type(getter) == "function" then
                local ok, a, b = pcall(getter, central)
                if ok then
                    tokens = a
                    essence = b
                    break
                end
            end
        end

        -- Some builds expose the helpers under central.DCCentral.
        if (tokens == nil or essence == nil) and type(central.DCCentral) == "table" then
            local c = central.DCCentral
            local getter = c.GetServerCurrencyBalance or c.GetCurrencyBalance or c.GetCurrencyBalances
            if type(getter) == "function" then
                local ok, a, b = pcall(getter, c)
                if ok then
                    tokens = tokens or a
                    essence = essence or b
                end
            end
        end
    end

    tokens = tonumber(tokens) or (self.currency and self.currency.tokens) or 0
    essence = tonumber(essence) or (self.currency and self.currency.emblems) or 0
    return tokens, essence
end

-- Normalize texture paths across 3.3.5a APIs.
-- Some servers/helpers provide icon names like "INV_Misc_QuestionMark" instead of full paths.
function DC:NormalizeTexturePath(texture, fallback)
    if type(texture) ~= "string" then
        return fallback
    end

    local tex = texture
    if tex == "" then
        return fallback
    end

    -- Already a full path (Interface\\Icons\\...) or any other path.
    if string.find(tex, "\\", 1, true) or string.find(tex, "/", 1, true) then
        return tex
    end

    -- Common icon name -> full path
    return "Interface\\Icons\\" .. tex
end

-- ============================================================================
-- SOURCE FORMATTING
-- ============================================================================

function DC:FormatSource(source)
    if not source then
        return ""
    end

    local t = type(source)
    if t == "string" then
        return source
    end

    if t ~= "table" then
        return tostring(source)
    end

    local sourceType = source.type or source.Type
    if type(sourceType) ~= "string" then
        sourceType = "unknown"
    end

    if sourceType == "vendor" then
        local npc = source.npc or source.vendor or source.name
        if type(npc) == "string" and npc ~= "" then
            return "Vendor: " .. npc
        end
        local npcEntry = source.npcEntry or source.npc_entry or source.creatureEntry
        if npcEntry then
            return "Vendor (NPC " .. tostring(npcEntry) .. ")"
        end
        return "Vendor"
    end

    if sourceType == "drop" then
        local boss = source.boss or source.creature
        local dropRate = source.dropRate or source.chance
        local text = "Drop"
        if type(boss) == "string" and boss ~= "" then
            text = text .. ": " .. boss
        end
        if type(dropRate) == "number" then
            text = text .. string.format(" (%.1f%%)", dropRate)
        end
        return text
    end

    if sourceType == "quest" then
        local questId = source.questId or source.quest_id or source.id
        if questId then
            return "Quest: #" .. tostring(questId)
        end
        return "Quest"
    end

    if sourceType == "unknown" then
        local itemId = source.itemId or source.item_id or source.itemID
        if itemId then
            local itemName, itemLink = GetItemInfo(itemId)
            if itemLink then
                return "Item: " .. itemLink
            elseif itemName then
                return "Item: " .. itemName
            else
                -- If item info is not cached, return a placeholder that doesn't look like an error
                return "Item ID: " .. tostring(itemId)
            end
        end
        return "Unknown Source"
    end

    -- Fallback: display the type string.
    return tostring(sourceType)
end

function DC:GetSourceSortKey(source)
    local s = self:FormatSource(source) or ""
    return string.lower(s)
end

-- ============================================================================
-- SETTINGS MANAGEMENT
-- ============================================================================

function DC:LoadSettings()
    -- Account-wide settings
    DCCollectionDB = DCCollectionDB or {}
    for key, value in pairs(defaults) do
        if DCCollectionDB[key] == nil then
            DCCollectionDB[key] = value
        end
    end

    -- Restore cached recent additions (My Collection overview)
    if type(DCCollectionDB.recentAdditions) == "table" then
        self.recentAdditions = DCCollectionDB.recentAdditions
    end
    
    -- Character-specific settings
    DCCollectionCharDB = DCCollectionCharDB or {}
    for key, value in pairs(charDefaults) do
        if DCCollectionCharDB[key] == nil then
            DCCollectionCharDB[key] = value
        end
    end
end

function DC:SaveSetting(key, value, isCharacter)
    if isCharacter then
        DCCollectionCharDB = DCCollectionCharDB or {}
        DCCollectionCharDB[key] = value
    else
        DCCollectionDB = DCCollectionDB or {}
        DCCollectionDB[key] = value
    end
end

function DC:GetSetting(key, isCharacter)
    if isCharacter then
        return DCCollectionCharDB and DCCollectionCharDB[key]
    else
        return DCCollectionDB and DCCollectionDB[key]
    end
end

-- ============================================================================
-- COLLECTION DATA ACCESS
-- ============================================================================

function DC:GetCollectionCount(collectionType)
    local stats = self.stats[collectionType]
    if stats then
        return stats.owned, stats.total
    end
    return 0, 0
end

function DC:GetTotalCount()
    local owned, total = 0, 0
    for _, stats in pairs(self.stats) do
        owned = owned + stats.owned
        total = total + stats.total
    end
    return owned, total
end

function DC:IsCollected(collectionType, id)
    local collection = self.collections[collectionType]
    return collection and collection[id] ~= nil
end

function DC:IsFavorite(collectionType, id)
    local collection = self.collections[collectionType]
    local item = collection and collection[id]
    return item and item.is_favorite
end

function DC:IsOnWishlist(collectionType, id)
    for _, item in ipairs(self.wishlist) do
        if item.collection_type == collectionType and item.item_id == id then
            return true
        end
    end
    return false
end

-- ============================================================================
-- MAIN FRAME TOGGLE
-- ============================================================================

function DC:Toggle()
    -- Always go through the MainFrame show/hide helpers so the UI
    -- performs initial data requests and tab/layout selection.
    if type(self.ToggleMainFrame) == "function" then
        self:ToggleMainFrame()
        return
    end

    -- Fallback (shouldn't happen): keep previous behavior.
    if self.MainFrame then
        if self.MainFrame:IsShown() then
            self.MainFrame:Hide()
        else
            self.MainFrame:Show()
        end
    else
        self:CreateMainFrame()
        if self.MainFrame then
            self.MainFrame:Show()
        end
    end
end

function DC:Show()
    -- Prefer the managed show path so the frame isn't displayed "half-initialized".
    if type(self.ShowMainFrame) == "function" then
        self:ShowMainFrame()
        return
    end

    -- Fallback
    if not self.MainFrame then
        self:CreateMainFrame()
    end
    if self.MainFrame then
        self.MainFrame:Show()
    end
end

function DC:Hide()
    if type(self.HideMainFrame) == "function" then
        self:HideMainFrame()
        return
    end

    if self.MainFrame then
        self.MainFrame:Hide()
    end
end

function DC:OpenTab(tabName)
    self:Show()
    if self.MainFrame and self.MainFrame.SelectTab then
        self.MainFrame:SelectTab(tabName)
    end
end

function DC:OpenSettings()
    -- Open Interface Options panel
    if self.optionsPanel then
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)  -- WoW bug workaround
    else
        self:CreateOptionsPanel()
        if self.optionsPanel then
            InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
            InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        else
            self:Print("Settings panel could not be created.")
        end
    end
end

function DC:CreateOptionsPanel()
    if self.optionsPanel then
        return self.optionsPanel
    end

    if not InterfaceOptions_AddCategory then
        return nil
    end

    local panel = CreateFrame("Frame", "DCCollectionOptionsPanel", InterfaceOptionsFramePanelContainer)
    panel.name = "DC-Collection"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("DC-Collection")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Account-wide collection UI settings")

    local optionIndex = 0
    local function NextOptionName(prefix)
        optionIndex = optionIndex + 1
        return panel:GetName() .. prefix .. tostring(optionIndex)
    end

    local function CreateCheckbox(text, tooltip, offsetY, getValue, setValue)
        local cb = CreateFrame("CheckButton", NextOptionName("Check"), panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, offsetY)

        local label = cb.Text or _G[cb:GetName() .. "Text"]
        if label then
            label:SetText(text)
        end
        cb.tooltipText = tooltip
        cb:SetScript("OnShow", function(self)
            self:SetChecked(getValue() and true or false)
        end)
        cb:SetScript("OnClick", function(self)
            setValue(self:GetChecked() and true or false)
        end)
        return cb
    end

    local function CreateSlider(text, tooltip, offsetY, minVal, maxVal, step, getValue, setValue, formatFunc)
        local s = CreateFrame("Slider", NextOptionName("Slider"), panel, "OptionsSliderTemplate")
        s:SetPoint("TOPLEFT", 16, offsetY)
        s:SetMinMaxValues(minVal, maxVal)
        s:SetValueStep(step)
        if type(s.SetObeyStepOnDrag) == "function" then
            s:SetObeyStepOnDrag(true)
        end
        s.tooltipText = tooltip

        local textFS = s.Text or _G[s:GetName() .. "Text"]
        local lowFS = s.Low or _G[s:GetName() .. "Low"]
        local highFS = s.High or _G[s:GetName() .. "High"]

        if textFS then textFS:SetText(text) end
        if lowFS then lowFS:SetText(tostring(minVal)) end
        if highFS then highFS:SetText(tostring(maxVal)) end

        local valueText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        valueText:SetPoint("TOPLEFT", s, "TOPRIGHT", 12, -2)

        local function UpdateLabel(val)
            if formatFunc then
                valueText:SetText(formatFunc(val))
            else
                valueText:SetText(tostring(val))
            end
        end

        s:SetScript("OnShow", function(self)
            local v = getValue()
            if type(v) ~= "number" then v = minVal end
            self:SetValue(v)
            UpdateLabel(v)
        end)
        s:SetScript("OnValueChanged", function(self, value)
            value = math.floor((value / step) + 0.5) * step
            setValue(value)
            UpdateLabel(value)
        end)

        return s
    end

    local function CreateButton(text, tooltip, offsetY, onClick)
        local b = CreateFrame("Button", NextOptionName("Button"), panel, "UIPanelButtonTemplate")
        b:SetPoint("TOPLEFT", 16, offsetY)
        b:SetSize(160, 22)
        b:SetText(text)
        b.tooltipText = tooltip
        b:SetScript("OnClick", function()
            if type(onClick) == "function" then
                onClick()
            end
        end)
        return b
    end

    -- Checkboxes
    CreateCheckbox(
        "Enable server sync",
        "When enabled, the addon requests updates from the server.",
        -60,
        function() return self:GetSetting("enableServerSync") end,
        function(v) self:SaveSetting("enableServerSync", v) end
    )

    CreateCheckbox(
        "Show collection notifications",
        "Show chat notifications when new items are learned.",
        -90,
        function() return self:GetSetting("showCollectionNotifications") end,
        function(v) self:SaveSetting("showCollectionNotifications", v) end
    )

    CreateCheckbox(
        "Show wishlist alerts",
        "Show alerts when an item on your wishlist becomes available.",
        -120,
        function() return self:GetSetting("showWishlistAlerts") end,
        function(v) self:SaveSetting("showWishlistAlerts", v) end
    )

    CreateCheckbox(
        "Play sounds",
        "Play UI sounds for certain collection events.",
        -150,
        function() return self:GetSetting("playSounds") end,
        function(v) self:SaveSetting("playSounds", v) end
    )

    CreateCheckbox(
        "Show tooltips",
        "Show tooltips when hovering collection items.",
        -180,
        function() return self:GetSetting("showTooltips") end,
        function(v) self:SaveSetting("showTooltips", v) end
    )

    CreateCheckbox(
        "Remember filters",
        "Remember your last used filters per character.",
        -210,
        function() return self:GetSetting("rememberFilters") end,
        function(v) self:SaveSetting("rememberFilters", v) end
    )

    CreateCheckbox(
        "Debug mode",
        "Enables verbose debug output in chat.",
        -240,
        function() return self:GetSetting("debugMode") end,
        function(v) self:SaveSetting("debugMode", v) end
    )

    CreateButton(
        "Refresh cache",
        "Clears local cache and requests fresh data from the server.",
        -270,
        function() self:RefreshCacheNow() end
    )

    CreateButton(
        "Test server collections",
        "Requests definitions + collection per type and prints counts in chat.",
        -295,
        function() self:RunServerCollectionsTest() end
    )

    -- Sliders
    CreateSlider(
        "Grid columns",
        "How many columns are shown in the collection grid.",
        -325,
        3, 10, 1,
        function() return self:GetSetting("gridColumns") end,
        function(v)
            self:SaveSetting("gridColumns", v)
            if self.MainFrame and self.MainFrame:IsShown() and self.RefreshGrid then
                self:RefreshGrid()
            end
        end
    )

    CreateSlider(
        "Grid icon size",
        "Icon size (in pixels) for items in the grid.",
        -375,
        32, 64, 1,
        function() return self:GetSetting("gridIconSize") end,
        function(v)
            self:SaveSetting("gridIconSize", v)
            if self.MainFrame and self.MainFrame:IsShown() and self.RefreshGrid then
                self:RefreshGrid()
            end
        end
    )

    InterfaceOptions_AddCategory(panel)
    self.optionsPanel = panel

    -- Communication sub-panel (looks like other DC addons: separate category)
    local comm = CreateFrame("Frame", "DCCollectionOptionsPanelComm", InterfaceOptionsFramePanelContainer)
    comm.name = "Communication"
    comm.parent = panel.name

    local commTitle = comm:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    commTitle:SetPoint("TOPLEFT", 16, -16)
    commTitle:SetText("DC-Collection")

    local commSubtitle = comm:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    commSubtitle:SetPoint("TOPLEFT", commTitle, "BOTTOMLEFT", 0, -8)
    commSubtitle:SetText("Communication settings")

    local commIndex = 0
    local function NextCommName(prefix)
        commIndex = commIndex + 1
        return comm:GetName() .. prefix .. tostring(commIndex)
    end

    local function CommCheckbox(text, tooltip, offsetY, getValue, setValue)
        local cb = CreateFrame("CheckButton", NextCommName("Check"), comm, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, offsetY)

        local label = cb.Text or _G[cb:GetName() .. "Text"]
        if label then
            label:SetText(text)
        end
        cb.tooltipText = tooltip
        cb:SetScript("OnShow", function(self)
            self:SetChecked(getValue() and true or false)
        end)
        cb:SetScript("OnClick", function(self)
            setValue(self:GetChecked() and true or false)
        end)
        return cb
    end

    CommCheckbox(
        "Enable server sync",
        "When disabled, the addon will not request data from the server.",
        -60,
        function() return self:GetSetting("enableServerSync") end,
        function(v) self:SaveSetting("enableServerSync", v) end
    )

    CommCheckbox(
        "Auto sync on login",
        "When enabled, the addon automatically requests data shortly after login.",
        -90,
        function() return self:GetSetting("autoSyncOnLogin") end,
        function(v) self:SaveSetting("autoSyncOnLogin", v) end
    )

    CommCheckbox(
        "Background wardrobe sync",
        "When enabled, transmog (wardrobe) data can sync in the background (even if the UI is closed).",
        -120,
        function() return self:GetSetting("backgroundWardrobeSync") end,
        function(v)
            self:SaveSetting("backgroundWardrobeSync", v)
            if v then
                self:StartBackgroundWardrobeSync()
            end
        end
    )

    CommCheckbox(
        "Debug mode",
        "Enables verbose debug output in chat.",
        -150,
        function() return self:GetSetting("debugMode") end,
        function(v) self:SaveSetting("debugMode", v) end
    )

    InterfaceOptions_AddCategory(comm)
    self.optionsPanelComm = comm
    return panel
end

-- ============================================================================
-- SERVER TEST / DIAGNOSTICS
-- ============================================================================

local function CountMap(t)
    if type(t) ~= "table" then
        return 0
    end
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

function DC:RunServerCollectionsTest()
    if type(self.IsProtocolReady) == "function" and not self:IsProtocolReady() then
        self:Print("Server protocol not ready.")
        return
    end

    self._serverCollectionsTestActive = true
    self._serverCollectionsTestStarted = time()

    self:Print("[DC-Collection] Running server collections test...")

    if type(self.RequestStats) == "function" then
        self:RequestStats()
    end

    local types = { "mounts", "pets", "heirlooms", "titles" }
    for _, t in ipairs(types) do
        if type(self.RequestDefinitions) == "function" then
            self:RequestDefinitions(t)
        end
        if type(self.RequestCollection) == "function" then
            self:RequestCollection(t)
        end
    end

    -- Transmog definitions can be huge; fetch a single page only.
    self._serverTestNoTransmogPaging = true
    if type(self.SendMessage) == "function" and self.Opcodes and self.Opcodes.CMSG_GET_DEFINITIONS then
        self:SendMessage(self.Opcodes.CMSG_GET_DEFINITIONS, { type = "transmog", offset = 0, limit = 200 })
    elseif type(self.RequestDefinitions) == "function" then
        self:RequestDefinitions("transmog")
    end
    if type(self.RequestCollection) == "function" then
        self:RequestCollection("transmog")
    end

    -- Also test the slot-based transmog endpoint for the reported problem slots.
    if type(self.SendMessage) == "function" and self.Opcodes and self.Opcodes.CMSG_GET_TRANSMOG_SLOT_ITEMS then
        self:SendMessage(self.Opcodes.CMSG_GET_TRANSMOG_SLOT_ITEMS, { slot = 283, page = 1 }) -- Head
        self:SendMessage(self.Opcodes.CMSG_GET_TRANSMOG_SLOT_ITEMS, { slot = 287, page = 1 }) -- Shoulder
        self:SendMessage(self.Opcodes.CMSG_GET_TRANSMOG_SLOT_ITEMS, { slot = 311, page = 1 }) -- Back
    end

    if type(self.After) == "function" then
        self.After(3, function()
            local reportTypes = { "mounts", "pets", "heirlooms", "titles", "transmog" }
            self:Print("[DC-Collection] Server test results (client cache snapshot):")
            for _, t in ipairs(reportTypes) do
                local defs = self.definitions and self.definitions[t]
                local coll = self.collections and self.collections[t]
                local stats = self.stats and self.stats[t]

                local defsCount = CountMap(defs)
                local collCount = CountMap(coll)

                local statsOwned = stats and (stats.owned or stats.collected) or nil
                local statsTotal = stats and stats.total or nil

                if statsOwned ~= nil and statsTotal ~= nil then
                    self:Print(string.format("  %s: defs=%d, coll=%d, stats=%d/%d", t, defsCount, collCount, statsOwned or 0, statsTotal or 0))
                else
                    self:Print(string.format("  %s: defs=%d, coll=%d", t, defsCount, collCount))
                end
            end

            self._serverCollectionsTestActive = nil
        end)
    else
        self._serverCollectionsTestActive = nil
    end
end

function DC:RefreshCacheNow()
    DCCollectionDB = DCCollectionDB or {}

    if type(self.ClearCache) == "function" then
        self:ClearCache()
    end

    if not self:IsProtocolReady() then
        self:Print("Server sync is disabled or not ready.")
        return
    end

    self:Print("Refreshing cache from server...")
    self:RequestFullSync()

    if self.MainFrame and self.MainFrame:IsShown() and type(self.RefreshCurrentTab) == "function" then
        self:RefreshCurrentTab()
    end
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

SLASH_DCCOLLECTION1 = "/dccollection"
SLASH_DCCOLLECTION2 = "/dcc"
SLASH_DCCOLLECTION3 = "/collection"

SlashCmdList["DCCOLLECTION"] = function(msg)
    local cmd = string.lower(msg or "")
    
    if cmd == "" or cmd == "show" then
        DC:Toggle()
    elseif cmd == "mounts" then
        DC:OpenTab("mounts")
    elseif cmd == "pets" then
        DC:OpenTab("pets")
    elseif cmd == "heirlooms" then
        DC:OpenTab("heirlooms")
    elseif cmd == "transmog" then
        DC:OpenTab("transmog")
    elseif cmd == "titles" then
        DC:OpenTab("titles")
    elseif cmd == "shop" then
        DC:OpenTab("shop")
    elseif cmd == "wishlist" then
        DC:OpenTab("wishlist")
    elseif cmd == "settings" or cmd == "options" then
        DC:OpenSettings()
    elseif cmd == "sync" then
        DC:Print("Requesting full sync from server...")
        DC:RequestFullSync()
    elseif cmd == "debug" then
        DCCollectionDB.debugMode = not DCCollectionDB.debugMode
        DC:Print("Debug mode: " .. (DCCollectionDB.debugMode and "ON" or "OFF"))
    elseif cmd:match("^netlog") then
        local n = cmd:match("^netlog%s+(%d+)")
        if type(DC.DumpNetEventLog) == "function" then
            DC:DumpNetEventLog(tonumber(n) or 30)
        else
            DC:Print("Net log is not available in this build.")
        end
    elseif cmd == "netclear" then
        if type(DC.ClearNetEventLog) == "function" then
            DC:ClearNetEventLog()
            DC:Print("[NetLog] Cleared")
        end
    elseif cmd == "stats" then
        local owned, total = DC:GetTotalCount()
        DC:Print("Collection Statistics:")
        DC:Print(string.format("  Mounts: %d / %d", DC.stats.mounts.owned, DC.stats.mounts.total))
        DC:Print(string.format("  Pets: %d / %d", DC.stats.pets.owned, DC.stats.pets.total))
        DC:Print(string.format("  Heirlooms: %d / %d", DC.stats.heirlooms.owned, DC.stats.heirlooms.total))
        DC:Print(string.format("  Total: %d / %d (%.1f%%)", owned, total, total > 0 and (owned/total*100) or 0))
        DC:Print(string.format("  Mount Speed Bonus: +%d%%", DC.mountSpeedBonus))
    elseif cmd == "currency" then
        DC:Print("Currency: " .. DC:FormatCurrency(DC.currency.tokens, DC.currency.emblems))
    elseif cmd == "help" then
        DC:Print("Available commands:")
        DC:Print("  /dcc - Toggle collection window")
        DC:Print("  /dcc mounts|pets|heirlooms|transmog|titles - Open specific tab")
        DC:Print("  /dcc shop - Open collection shop")
        DC:Print("  /dcc wishlist - Open wishlist")
        DC:Print("  /dcc settings - Open settings panel")
        DC:Print("  /dcc sync - Request full data sync")
        DC:Print("  /dcc stats - Show collection statistics")
        DC:Print("  /dcc currency - Show current currency")
        DC:Print("  /dcc debug - Toggle debug mode")
        DC:Print("  /dcc netlog [N] - Show last N net events")
        DC:Print("  /dcc netclear - Clear net event log")
    else
        DC:Print("Unknown command. Type /dcc help for a list of commands.")
    end
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

local eventFrame = CreateFrame("Frame", "DCCollectionEventFrame", UIParent)
local events = {}

-- WoW 3.3.5a compatibility: C_Timer does not exist.
local function After(seconds, callback)
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        return C_Timer.After(seconds, callback)
    end

    local f = CreateFrame("Frame")
    local elapsed = 0
    f:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + (delta or 0)
        if elapsed >= (seconds or 0) then
            self:SetScript("OnUpdate", nil)
            local ok, err = pcall(callback)
            if not ok and DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[DC-Collection] Timer error:|r " .. tostring(err))
            end
        end
    end)
end

-- Expose After function for other modules (e.g., Protocol.lua)
DC.After = After

-- ============================================================================
-- BACKGROUND WARDROBE SYNC
-- ============================================================================

function DC:IsBackgroundWardrobeSyncEnabled()
    -- Treat nil as enabled (default-on) to keep wardrobe data warm in the background.
    -- Explicitly setting it to false in SavedVariables still disables the loop.
    if not DCCollectionDB then
        return true
    end
    if DCCollectionDB.backgroundWardrobeSync == nil then
        return true
    end
    return DCCollectionDB.backgroundWardrobeSync and true or false
end

function DC:StartBackgroundWardrobeSync()
    if self._bgWardrobeSyncLoopActive then
        return
    end

    self._bgWardrobeSyncLoopActive = true

    local function Tick()
        -- Stop the loop if the setting was disabled.
        if not self:IsBackgroundWardrobeSyncEnabled() then
            self._bgWardrobeSyncLoopActive = nil
            return
        end

        -- Default cadence when fully idle: keep it conservative.
        -- When there is pending wardrobe work, we run short out-of-combat ticks.
        local delaySeconds = 30 * 60

        local function IsInCombat()
            if type(InCombatLockdown) == "function" then
                return InCombatLockdown() and true or false
            end
            if type(UnitAffectingCombat) == "function" then
                return UnitAffectingCombat("player") and true or false
            end
            return false
        end

        if not self:IsProtocolReady() then
            -- Retry sooner while waiting for protocol readiness.
            delaySeconds = 30
        else
            -- Never do background sync work in combat.
            if IsInCombat() then
                delaySeconds = 20
                After(delaySeconds, Tick)
                return
            end

            -- Avoid stacking requests while a paged transmog download is already running.
            local pagingBusy = (self._transmogDefLoading ~= nil)
                or (self._transmogPagingDelayFrame and self._transmogPagingDelayFrame.pendingRequest ~= nil)

            -- Do one small unit of work per tick (keeps spikes down).
            local didWork = false

            -- 1) Resume / start transmog definitions paging
            if not pagingBusy then
                DCCollectionDB = DCCollectionDB or {}
                if DCCollectionDB.transmogDefsIncomplete and type(self.ResumeTransmogDefinitions) == "function" then
                    self:Debug("Background wardrobe sync: resume transmog defs")
                    self:ResumeTransmogDefinitions("bg_sync")
                    didWork = true
                elseif (not self.definitionsLoaded) and type(self.RequestDefinitions) == "function" then
                    self:Debug("Background wardrobe sync: request transmog defs")
                    self:RequestDefinitions("transmog", 0)
                    didWork = true
                end
            else
                -- If we're already paging, poll more frequently so we can continue once the run finishes.
                delaySeconds = 10
            end

            -- 2) Saved outfits (small page)
            if not didWork and DC and DC.Protocol and type(DC.Protocol.RequestSavedOutfitsPage) == "function" then
                DC.db = DC.db or {}
                if type(DC.db.outfits) ~= "table" then
                    self:Debug("Background wardrobe sync: request saved outfits")
                    DC.Protocol:RequestSavedOutfitsPage(0, 6)
                    didWork = true
                end
            end

            -- 3) Light collection refresh (cheap)
            if not didWork and type(self.RequestCollection) == "function" then
                self:RequestCollection("transmog")
                didWork = true
            end

            -- While there is work to do, keep a short cadence.
            if didWork then
                delaySeconds = 12
            end
        end

        -- Add small jitter so multiple clients don't sync at exactly the same time.
        if type(self.Rand) == "function" then
            local jitter = (self:Rand(21) - 11) -- [-10..+10]
            delaySeconds = delaySeconds + jitter
        end
        if delaySeconds < 10 then
            delaySeconds = 10
        end

        After(delaySeconds, Tick)
    end

    -- Start shortly after enabling/login.
    After(5, Tick)
end

function DC:MaybeResumeTransmogDefinitionsOnLogin()
    DCCollectionDB = DCCollectionDB or {}
    if not DCCollectionDB.transmogDefsIncomplete then
        return
    end

    if not self:IsProtocolReady() then
        return
    end

    -- Don't interrupt an already-running paging run.
    if self._transmogDefLoading then
        return
    end

    if type(self.ResumeTransmogDefinitions) == "function" then
        self:ResumeTransmogDefinitions("login_resume")
    elseif type(self.RequestDefinitions) == "function" then
        -- Fallback: restart from scratch (forced) if the resume helper isn't available.
        self:RequestDefinitions("transmog", 0)
    end
end

-- ============================================================================
-- RNG (DEFENSIVE)
-- ============================================================================

-- WoW 3.3.5a normally exposes math.randomseed, but some UIs/sandboxes/addons can
-- clobber it. Provide an addon-local PRNG so random features still work.
local function SeedFallbackRNG()
    if DC._prngSeed and DC._prngSeed > 0 then
        return
    end

    local t = 0
    if type(time) == "function" then
        t = time() or 0
    end
    local gt = 0
    if type(GetTime) == "function" then
        gt = GetTime() or 0
    end

    local seed = math.floor((t * 1000) + (gt * 1000))
    seed = seed % 2147483647
    if seed <= 0 then
        seed = 1234567
    end
    DC._prngSeed = seed
end

-- Park–Miller minimal standard PRNG step (mod 2^31-1).
local function NextFallbackRand()
    SeedFallbackRNG()

    local seed = DC._prngSeed or 1
    local hi = math.floor(seed / 127773)
    local lo = seed - hi * 127773
    local test = 16807 * lo - 2836 * hi
    if test <= 0 then
        test = test + 2147483647
    end
    DC._prngSeed = test
    return test
end

-- Returns integer in [1, max].
function DC:Rand(max)
    max = tonumber(max)
    if not max or max < 1 then
        return 1
    end

    -- Prefer WoW/Lua's RNG when available.
    if type(math) == "table" and type(math.random) == "function" then
        return math.random(1, max)
    end

    local r = NextFallbackRand()
    return (r % max) + 1
end

function events:ADDON_LOADED(addonName)
    if addonName == "DC-Collection" then
        -- Ensure math.random is not deterministic across sessions.
        -- Some client environments may not expose math.randomseed; guard it.
        if not DC._rngSeeded then
            DC._rngSeeded = true
            if type(math) == "table" and type(math.randomseed) == "function" then
                math.randomseed(time())
                -- Warm-up calls improve distribution in some Lua implementations.
                if type(math.random) == "function" then
                    math.random(); math.random(); math.random()
                end
            end
        end

        DC:LoadSettings()
        DC:CreateOptionsPanel()
        DC:InitializeCache()
        DC:InitializeProtocol()

        if type(DC.InitializeModules) == "function" then
            DC:InitializeModules()
        end
        
        DC.isLoaded = true
        DC:Print(string.format(L.ADDON_LOADED, DC.VERSION))

        -- Background wardrobe sync can be enabled independently of autoSyncOnLogin.
        -- Start its loop here; it will no-op until protocol becomes ready.
        After(2, function()
            if DC:IsBackgroundWardrobeSyncEnabled() then
                DC:StartBackgroundWardrobeSync()
            end
        end)
        
        -- If cache is fresh (recent reload), skip the heavy server requests entirely.
        local cacheFresh = (type(DC.IsCacheFresh) == "function") and DC:IsCacheFresh()
        local hasDefs = (type(DC.HasCachedDefinitions) == "function") and DC:HasCachedDefinitions()
        
        if cacheFresh and hasDefs then
            DC:Debug("Cache is fresh on ADDON_LOADED; using cached data")
            DC._initialDataRequested = true
            -- Still fetch lightweight currency/stats after a short delay
            After(0.5, function()
                if DC:IsProtocolReady() then
                    DC:RequestCurrency()
                    DC:RequestStats()
                end
            end)
            return
        end
        
        -- Request initial data after a short delay (reduced from 2s to 1s)
        After(1, function()
            if not DC:GetSetting("autoSyncOnLogin") then
                return
            end
            if type(DC.RequestInitialDataWithRetry) == "function" then
                DC._initialDataRequested = true
                DC:RequestInitialDataWithRetry(8, 1)
            elseif DC:IsProtocolReady() then
                DC._initialDataRequested = true
                DC:RequestInitialData()
            end
        end)
    end
end

function events:PLAYER_LOGIN()
    -- Apply mount speed bonus on login
    DC:ApplyMountSpeedBonus()

    -- Fallback: some clients/protocols only become ready after PLAYER_LOGIN.
    -- Reduced delay from 2s to 1s.
    After(1, function()
        if not DC:GetSetting("autoSyncOnLogin") then
            return
        end
        if DC._initialDataRequested or DC._initialDataRetryInProgress then
            return
        end
        if type(DC.RequestInitialDataWithRetry) == "function" then
            DC._initialDataRequested = true
            DC:RequestInitialDataWithRetry(8, 1)
        elseif DC:IsProtocolReady() then
            DC._initialDataRequested = true
            DC:RequestInitialData(false)
        end
    end)

    -- Fallback: ensure background wardrobe sync loop starts even if ADDON_LOADED path early-returned.
    After(3, function()
        if DC:IsBackgroundWardrobeSyncEnabled() then
            DC:StartBackgroundWardrobeSync()
        end
    end)

    -- Automatic resume for interrupted transmog paging runs.
    After(6, function()
        if DC:IsProtocolReady() then
            DC:MaybeResumeTransmogDefinitionsOnLogin()
        end
    end)

    -- Fallback: ensure protocol registration actually happened.
    After(0.5, function()
        if not DC.isConnected and type(DC.InitializeProtocol) == "function" then
            DC:InitializeProtocol()
        end
    end)
end

function events:PLAYER_LOGOUT()
    -- Ensure cache is marked for save and saved on logout
    DC.cacheNeedsSave = true
    DC:SaveCache()
end

function events:COMPANION_LEARNED()
    -- A mount or pet was learned
    DC:Debug("COMPANION_LEARNED event")
    DC:RequestCollectionUpdate(DC.CollectionType.MOUNT)
    DC:RequestCollectionUpdate(DC.CollectionType.PET)
end

function events:COMPANION_UPDATE(companionType)
    DC:Debug("COMPANION_UPDATE: " .. tostring(companionType))
end

function events:KNOWN_TITLES_UPDATE()
    DC:Debug("KNOWN_TITLES_UPDATE event")
    -- Titles changed, refresh if needed
end

-- Register events
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if events[event] then
        events[event](self, ...)
    end
end)

for event in pairs(events) do
    eventFrame:RegisterEvent(event)
end

-- ============================================================================
-- INITIALIZATION HELPERS
-- ============================================================================

function DC:InitializeCache()
    -- Load cached data from SavedVariables
    if self.LoadCache then
        self:LoadCache()
    end
end

function DC:InitializeModules()
    -- Initialize collection modules after all addon files are loaded.
    local modules = {
        self.MountModule,
        self.PetModule,
        self.HeirloomModule,
        self.TitleModule,
        self.ToyModule,
        self.TransmogModule,
    }

    for _, module in ipairs(modules) do
        if module and type(module.Init) == "function" then
            local ok, err = pcall(module.Init, module)
            if not ok then
                self:Debug("Module init error: " .. tostring(err))
            end
        end
    end
end

function DC:IsProtocolReady()
    -- Check if we can communicate with server
    if not DCAddonProtocol then
        return false
    end

    if not self:GetSetting("enableServerSync") then
        return false
    end

    -- DCAddonProtocol in 3.3.5a does not expose IsReady(); assume ready if Request/SendJSON exists
    if self.isConnected then
        return true
    end

    return type(DCAddonProtocol.Request) == "function" or type(DCAddonProtocol.SendJSON) == "function" or type(DCAddonProtocol.Send) == "function"
end

function DC:RequestInitialData(skipHandshake, forceRefresh)
    DC:Debug("Requesting initial collection data...")

    self._initialDataRequested = true

    if not self:IsProtocolReady() then
        self:Debug("Protocol not ready (or server sync disabled)")
        return
    end

    -- If cache is fresh and we have definitions, skip heavy requests on reload/relog.
    -- This dramatically speeds up /reload scenarios.
    local cacheFresh = (type(self.IsCacheFresh) == "function") and self:IsCacheFresh()
    local hasDefs = (type(self.HasCachedDefinitions) == "function") and self:HasCachedDefinitions()

    if cacheFresh and hasDefs and not forceRefresh then
        self:Debug("Cache is fresh; skipping heavy server requests (definitions/collections)")
        -- Only request lightweight data: currency + stats (for live balance updates).
        self:RequestCurrency()
        self:RequestStats()
        return
    end

    -- Ensure handshake happens first when supported.
    if not skipHandshake and type(self.RequestHandshake) == "function" then
        if not self._handshakeRequested and not self._handshakeAcked then
            self._handshakeRequested = true
            self:Debug("Sending handshake...")
            self:RequestHandshake()
            return
        end
    end
    
    -- Request currency first
    self:RequestCurrency()
    
    -- Request collection counts
    self:RequestStats()
    
    -- Request definitions (for uncollected items)
    self:RequestDefinitions()
    
    -- Request player collections
    self:RequestCollections()
    
    -- Request shop data
    self:RequestShopData()
end

-- Request initial data, retrying briefly if protocol isn't ready yet.
-- This helps cases where the UI is opened very early on login.
function DC:RequestInitialDataWithRetry(maxAttempts, delaySeconds)
    maxAttempts = maxAttempts or 8
    delaySeconds = delaySeconds or 1

    if self._initialDataRetryInProgress then
        return
    end
    self._initialDataRetryInProgress = true

    local attempt = 0
    local function tryRequest()
        attempt = attempt + 1

        if self:IsProtocolReady() then
            self._initialDataRetryInProgress = nil
            self:RequestInitialData(false)
            return
        end

        if attempt >= maxAttempts then
            self._initialDataRetryInProgress = nil
            self:Debug("Initial data request retry exhausted")
            return
        end

        After(delaySeconds, tryRequest)
    end

    tryRequest()
end

function DC:RequestFullSync()
    -- Force a complete resync
    DCCollectionDB.lastSyncTime = 0
    DCCollectionDB.syncVersion = 0
    DCCollectionDB.syncVersions = nil
    self._handshakeRequested = nil
    self._handshakeAcked = nil
    self:RequestInitialData(false, true)  -- forceRefresh = true
end

-- Placeholder functions (implemented in Protocol.lua)
if type(DC.RequestCurrency) ~= "function" then
    function DC:RequestCurrency() end
end
if type(DC.RequestStats) ~= "function" then
    function DC:RequestStats() end
end
if type(DC.RequestDefinitions) ~= "function" then
    function DC:RequestDefinitions() end
end
if type(DC.RequestCollections) ~= "function" then
    function DC:RequestCollections() end
end
if type(DC.RequestShopData) ~= "function" then
    function DC:RequestShopData() end
end
if type(DC.RequestCollectionUpdate) ~= "function" then
    function DC:RequestCollectionUpdate(collectionType) end
end

-- Placeholder for mount speed bonus (implemented in Bonuses.lua)
if type(DC.ApplyMountSpeedBonus) ~= "function" then
    function DC:ApplyMountSpeedBonus() end
end

-- Placeholder for main frame creation (implemented in UI/MainFrame.lua)
if type(DC.CreateMainFrame) ~= "function" then
    function DC:CreateMainFrame() end
end

-- Placeholder for cache functions (implemented in Cache.lua)
if type(DC.LoadCache) ~= "function" then
    function DC:LoadCache() end
end
if type(DC.SaveCache) ~= "function" then
    function DC:SaveCache() end
end

-- ============================================================================
-- LINK HANDLING
-- ============================================================================

local orig_SetItemRef = SetItemRef
function SetItemRef(link, text, button, chatFrame)
    if type(link) == "string" then
        if string.sub(link, 1, 9) == "dc:outfit" then
            if DC.PreviewOutfitFromLink then
                DC:PreviewOutfitFromLink(link)
            end
            return
        elseif string.sub(link, 1, 11) == "dc:wishlist" then
            if DC.RequestAddWishlist then
                local _, _, itemID = string.find(link, "dc:wishlist:(%d+)")
                if itemID then
                    -- Assume Transmog (Type 6) for now, or encode type in link
                    DC:RequestAddWishlist(6, tonumber(itemID))
                end
            end
            return
        end
    end
    
    if orig_SetItemRef then
        return orig_SetItemRef(link, text, button, chatFrame)
    end
end

-- ============================================================================
-- UNIT POPUP HOOK (Inspection)
-- ============================================================================

local function HookUnitPopup()
    -- Add button definition
    UnitPopupButtons["INSPECT_TRANSMOG"] = { text = "Inspect Transmog", dist = 0 }

    -- Add to menus
    -- Insert after "INSPECT" if possible, otherwise at end of safe buttons
    for _, menu in pairs(UnitPopupMenus) do
        local inserted = false
        for i, button in ipairs(menu) do
            if button == "INSPECT" then
                table.insert(menu, i + 1, "INSPECT_TRANSMOG")
                inserted = true
                break
            end
        end
        -- If INSPECT not found, maybe add to specific menus like PLAYER
        if not inserted and (menu == UnitPopupMenus["PLAYER"] or menu == UnitPopupMenus["FRIEND"] or menu == UnitPopupMenus["PARTY"] or menu == UnitPopupMenus["RAID"]) then
             -- Add before CANCEL or at end
             table.insert(menu, #menu, "INSPECT_TRANSMOG")
        end
    end

    -- Hook OnClick
    hooksecurefunc("UnitPopup_OnClick", function(self)
        local dropdownFrame = UIDROPDOWNMENU_INIT_MENU
        local button = self.value
        local unit = dropdownFrame.unit
        local name = dropdownFrame.name
        local server = dropdownFrame.server
        
        if button == "INSPECT_TRANSMOG" then
            if unit and UnitExists(unit) and UnitIsPlayer(unit) then
                if DC.RequestInspectTarget then
                    DC:RequestInspectTarget(unit)
                else
                    DC:Print("Inspection not ready.")
                end
            else
                DC:Print("Cannot inspect that target.")
            end
        end
    end)
end

-- Initialize hooks on load
local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("PLAYER_LOGIN")
hookFrame:SetScript("OnEvent", function()
    HookUnitPopup()
end)
