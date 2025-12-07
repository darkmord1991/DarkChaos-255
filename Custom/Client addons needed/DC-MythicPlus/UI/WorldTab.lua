-- DC-MythicPlus/UI/WorldTab.lua
-- World Content tab for Group Finder (World Bosses, Hotspots, Open World Events)

local addonName = "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

local GF = namespace.GroupFinder
if not GF then return end

-- =====================================================================
-- Constants
-- =====================================================================

local WORLD_CONTENT_TYPES = {
    { id = "boss", name = "World Bosses", icon = "Interface\\Icons\\Achievement_Boss_Archimonde" },
    { id = "hotspot", name = "Hotspots", icon = "Interface\\Icons\\Spell_Fire_Burnout" },
    { id = "event", name = "World Events", icon = "Interface\\Icons\\Achievement_Zone_Outland_01" },
    { id = "rare", name = "Rare Hunting", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01" },
    { id = "farming", name = "Farming Groups", icon = "Interface\\Icons\\INV_Misc_Herb_Goldclover" },
    { id = "pvp", name = "World PvP", icon = "Interface\\Icons\\Ability_DualWield" },
}

-- Sample world content data (populated from server)
local worldContent = {
    bosses = {},
    hotspots = {},
    events = {},
    rares = {},
    farming = {},
    pvp = {},
    groups = {},
}

-- =====================================================================
-- Print Helper
-- =====================================================================

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff32c4ffWorld Content:|r " .. (msg or ""))
    end
end

-- =====================================================================
-- World Tab Content Creation
-- =====================================================================

function GF:CreateWorldTab()
    if self.WorldTabContent then return end
    
    local parent = self.mainFrame.contentFrame
    local content = CreateFrame("Frame", nil, parent)
    content:SetAllPoints()
    content:Hide()
    
    self.WorldTabContent = content
    
    -- Left side: Content type filter (like a category list)
    local filterPanel = CreateFrame("Frame", nil, content)
    filterPanel:SetPoint("TOPLEFT", 0, 0)
    filterPanel:SetPoint("BOTTOMLEFT", 0, 0)
    filterPanel:SetWidth(150)
    
    local filterBg = filterPanel:CreateTexture(nil, "BACKGROUND")
    filterBg:SetAllPoints()
    filterBg:SetColorTexture(0.03, 0.03, 0.04, 1)
    
    -- Filter header
    local filterHeader = filterPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterHeader:SetPoint("TOP", 0, -8)
    filterHeader:SetText("|cffaaaaaaContent Type|r")
    
    -- Filter buttons
    local yOffset = -30
    self.worldFilterButtons = {}
    
    for i, contentType in ipairs(WORLD_CONTENT_TYPES) do
        local btn = CreateFrame("Button", nil, filterPanel)
        btn:SetSize(140, 28)
        btn:SetPoint("TOP", 0, yOffset)
        
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.05, 0.05, 0.06, 1)
        
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetSize(20, 20)
        btn.icon:SetPoint("LEFT", 6, 0)
        btn.icon:SetTexture(contentType.icon)
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 6, 0)
        btn.text:SetText(contentType.name)
        btn.text:SetTextColor(0.7, 0.7, 0.7)
        
        btn.contentId = contentType.id
        btn:SetScript("OnClick", function(self)
            GF:SelectWorldFilter(self.contentId)
        end)
        
        btn:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(0.1, 0.1, 0.12, 1)
        end)
        btn:SetScript("OnLeave", function(self)
            if GF.selectedWorldFilter ~= self.contentId then
                self.bg:SetColorTexture(0.05, 0.05, 0.06, 1)
            end
        end)
        
        self.worldFilterButtons[contentType.id] = btn
        yOffset = yOffset - 30
    end
    
    -- Right side: Content list
    local listPanel = CreateFrame("Frame", nil, content)
    listPanel:SetPoint("TOPLEFT", filterPanel, "TOPRIGHT", 4, 0)
    listPanel:SetPoint("BOTTOMRIGHT", 0, 40)
    
    local listBg = listPanel:CreateTexture(nil, "BACKGROUND")
    listBg:SetAllPoints()
    listBg:SetColorTexture(0.03, 0.03, 0.04, 1)
    
    -- List header
    local listHeader = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listHeader:SetPoint("TOPLEFT", 10, -10)
    listHeader:SetText("|cffffffffWorld Content|r")
    self.worldListHeader = listHeader
    
    -- Scroll frame for content
    local scrollFrame = CreateFrame("ScrollFrame", "DCWorldContentScroll", listPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -35)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    self.worldScrollChild = scrollChild
    
    -- Bottom action bar
    local actionBar = CreateFrame("Frame", nil, content)
    actionBar:SetPoint("BOTTOMLEFT", 154, 0)
    actionBar:SetPoint("BOTTOMRIGHT", 0, 0)
    actionBar:SetHeight(36)
    
    local actionBg = actionBar:CreateTexture(nil, "BACKGROUND")
    actionBg:SetAllPoints()
    actionBg:SetColorTexture(0.06, 0.06, 0.07, 1)
    
    -- Create Group button
    local createBtn = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
    createBtn:SetSize(120, 24)
    createBtn:SetPoint("LEFT", 10, 0)
    createBtn:SetText("Create Group")
    createBtn:SetScript("OnClick", function()
        GF:ShowWorldGroupCreateDialog()
    end)
    self.worldCreateBtn = createBtn
    
    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
    refreshBtn:SetSize(80, 24)
    refreshBtn:SetPoint("LEFT", createBtn, "RIGHT", 10, 0)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        GF:RefreshWorldContent()
    end)
    
    -- Teleport to Hotspot button
    local teleportBtn = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
    teleportBtn:SetSize(120, 24)
    teleportBtn:SetPoint("RIGHT", -10, 0)
    teleportBtn:SetText("Teleport")
    teleportBtn:SetScript("OnClick", function()
        GF:TeleportToSelectedWorld()
    end)
    teleportBtn:Disable()
    self.worldTeleportBtn = teleportBtn
    
    -- Select first filter by default
    self:SelectWorldFilter("boss")
end

-- =====================================================================
-- Filter Selection
-- =====================================================================

function GF:SelectWorldFilter(contentId)
    self.selectedWorldFilter = contentId
    
    -- Update button visuals
    for id, btn in pairs(self.worldFilterButtons) do
        if id == contentId then
            btn.bg:SetColorTexture(0.15, 0.3, 0.5, 1)
            btn.text:SetTextColor(1, 1, 1)
        else
            btn.bg:SetColorTexture(0.05, 0.05, 0.06, 1)
            btn.text:SetTextColor(0.7, 0.7, 0.7)
        end
    end
    
    -- Update header
    for _, ct in ipairs(WORLD_CONTENT_TYPES) do
        if ct.id == contentId then
            self.worldListHeader:SetText("|cffffffff" .. ct.name .. "|r")
            break
        end
    end
    
    -- Refresh content list
    self:RefreshWorldContentList()
end

-- =====================================================================
-- Content List Population
-- =====================================================================

function GF:RefreshWorldContent()
    local DC = rawget(_G, "DCAddonProtocol")
    if not DC then
        Print("DCAddonProtocol not available")
        return
    end
    
    -- Request world content data
    DC:Request("SPOT", 0x01, {})  -- Hotspots
    DC:Request("WRLD", 0x01, {})  -- World bosses (if module exists)
    DC:Request("GRPF", 0x11, { category = "world" })  -- World groups
    
    Print("Refreshing world content...")
    
    -- Also check InfoBar for cached data
    if DCInfoBar and DCInfoBar.serverData then
        if DCInfoBar.serverData.hotspots then
            worldContent.hotspots = DCInfoBar.serverData.hotspots
        end
        if DCInfoBar.serverData.worldBosses then
            worldContent.bosses = DCInfoBar.serverData.worldBosses
        end
    end
    
    -- Update list after delay
    local frame = CreateFrame("Frame")
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 0.5 then
            self:SetScript("OnUpdate", nil)
            GF:RefreshWorldContentList()
        end
    end)
end

function GF:RefreshWorldContentList()
    if not self.worldScrollChild then return end
    
    -- Clear existing entries
    for _, child in pairs({ self.worldScrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Clear any existing no-data text
    if self.worldNoDataText then
        self.worldNoDataText:Hide()
        self.worldNoDataText:SetText("")
    end
    
    local yOffset = 0
    local filter = self.selectedWorldFilter
    local items = {}
    
    -- Get items based on filter
    if filter == "boss" then
        items = worldContent.bosses or {}
    elseif filter == "hotspot" then
        items = worldContent.hotspots or {}
    elseif filter == "event" then
        items = worldContent.events or {}
    elseif filter == "rare" then
        items = worldContent.rares or {}
    elseif filter == "farming" then
        items = worldContent.farming or {}
    elseif filter == "pvp" then
        items = worldContent.pvp or {}
    else
        items = worldContent.groups or {}
    end
    
    if #items == 0 then
        -- Reuse or create the no-data text
        if not self.worldNoDataText then
            self.worldNoDataText = self.worldScrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        end
        self.worldNoDataText:SetPoint("CENTER", self.worldScrollChild:GetParent(), "CENTER", 0, 0)
        self.worldNoDataText:SetText("No " .. filter .. " data available.\nTry clicking Refresh.")
        self.worldNoDataText:Show()
        return
    end
    
    -- Create entry for each item
    for i, item in ipairs(items) do
        local entry = self:CreateWorldContentEntry(self.worldScrollChild, item, filter)
        entry:SetPoint("TOPLEFT", 0, yOffset)
        entry:SetPoint("TOPRIGHT", 0, yOffset)
        yOffset = yOffset - 50
    end
    
    self.worldScrollChild:SetHeight(math.abs(yOffset) + 20)
end

function GF:CreateWorldContentEntry(parent, item, contentType)
    local entry = CreateFrame("Button", nil, parent)
    entry:SetHeight(46)
    
    entry.bg = entry:CreateTexture(nil, "BACKGROUND")
    entry.bg:SetAllPoints()
    entry.bg:SetColorTexture(0.06, 0.06, 0.08, 1)
    
    -- Icon
    local icon = entry:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("LEFT", 8, 0)
    
    if contentType == "boss" then
        icon:SetTexture("Interface\\Icons\\Achievement_Boss_Archimonde")
    elseif contentType == "hotspot" then
        icon:SetTexture("Interface\\Icons\\Spell_Fire_Burnout")
    else
        icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    end
    entry.icon = icon
    
    -- Name
    local name = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -4)
    name:SetText(item.name or "Unknown")
    entry.nameText = name
    
    -- Info line
    local info = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    
    if contentType == "boss" then
        local status = item.status == "active" and "|cff00ff00ACTIVE|r" or "|cffff8800Spawns in " .. (item.spawnIn or "?") .. "|r"
        info:SetText((item.zoneName or item.zone or "Unknown Zone") .. " - " .. status)
    elseif contentType == "hotspot" then
        local bonus = item.bonusPercent or item.bonus or 0
        info:SetText((item.zoneName or "Unknown Zone") .. " - |cff00ff00+" .. bonus .. "% Bonus|r")
    else
        info:SetText(item.description or "No description")
    end
    entry.infoText = info
    
    -- Time remaining (if applicable)
    if item.timeRemaining and item.timeRemaining > 0 then
        local time = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        time:SetPoint("RIGHT", -10, 0)
        local mins = math.floor(item.timeRemaining / 60)
        local secs = item.timeRemaining % 60
        time:SetText(string.format("|cffffff00%d:%02d|r", mins, secs))
        entry.timeText = time
    end
    
    -- Store data
    entry.data = item
    entry.contentType = contentType
    
    -- Click handling
    entry:SetScript("OnClick", function(self)
        GF:SelectWorldEntry(self)
    end)
    
    entry:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.1, 0.1, 0.15, 1)
    end)
    entry:SetScript("OnLeave", function(self)
        if GF.selectedWorldEntry ~= self then
            self.bg:SetColorTexture(0.06, 0.06, 0.08, 1)
        end
    end)
    
    return entry
end

function GF:SelectWorldEntry(entry)
    -- Deselect previous
    if self.selectedWorldEntry then
        self.selectedWorldEntry.bg:SetColorTexture(0.06, 0.06, 0.08, 1)
    end
    
    -- Select new
    self.selectedWorldEntry = entry
    entry.bg:SetColorTexture(0.15, 0.25, 0.4, 1)
    
    -- Enable teleport for hotspots
    if entry.contentType == "hotspot" and entry.data.id then
        self.worldTeleportBtn:Enable()
    else
        self.worldTeleportBtn:Disable()
    end
end

function GF:TeleportToSelectedWorld()
    if not self.selectedWorldEntry then return end
    
    local entry = self.selectedWorldEntry
    if entry.contentType == "hotspot" and entry.data.id then
        local DC = rawget(_G, "DCAddonProtocol")
        if DC then
            DC:Request("SPOT", 0x03, { id = entry.data.id })
            Print("Teleporting to hotspot: " .. (entry.data.name or "Unknown"))
        end
    end
end

function GF:ShowWorldGroupCreateDialog()
    -- TODO: Implement group creation dialog for world content
    Print("Create World Group dialog coming soon!")
end

-- =====================================================================
-- DCAddonProtocol Handlers
-- =====================================================================

local function RegisterWorldHandlers()
    local DC = rawget(_G, "DCAddonProtocol")
    if not DC then
        local frame = CreateFrame("Frame")
        frame.elapsed = 0
        frame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= 2 then
                self:SetScript("OnUpdate", nil)
                RegisterWorldHandlers()
            end
        end)
        return
    end
    
    -- Handle hotspot list
    DC:RegisterHandler("SPOT", 0x10, function(data)
        if data and data.hotspots then
            worldContent.hotspots = data.hotspots
        elseif data and type(data) == "table" then
            worldContent.hotspots = data
        end
        
        if GF.selectedWorldFilter == "hotspot" then
            GF:RefreshWorldContentList()
        end
    end)
    
    -- Handle world boss list (if WRLD module exists)
    DC:RegisterHandler("WRLD", 0x10, function(data)
        if data and data.bosses then
            worldContent.bosses = data.bosses
        elseif data and type(data) == "table" then
            worldContent.bosses = data
        end
        
        if GF.selectedWorldFilter == "boss" then
            GF:RefreshWorldContentList()
        end
    end)
    
    -- Handle group search results for world category
    if DC.GroupFinderOpcodes then
        DC:RegisterHandler("GRPF", DC.GroupFinderOpcodes.SMSG_SEARCH_RESULTS, function(data)
            if data and data.category == "world" then
                worldContent.groups = data.groups or {}
                GF:RefreshWorldContentList()
            end
        end)
    end
end

RegisterWorldHandlers()

Print("World Content tab loaded")
