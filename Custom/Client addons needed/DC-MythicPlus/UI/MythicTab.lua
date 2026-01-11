-- DC-MythicPlus/UI/MythicTab.lua
-- Mythic+ tab for Group Finder - Browse/Create M+ groups, keystone management

local addonName = "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

local GF = namespace.GroupFinder
if not GF then return end

-- Match DC-Leaderboards UI style across DC addons
local BG_FELLEATHER = "Interface\\AddOns\\DC-MythicPlus\\Textures\\Backgrounds\\FelLeather_512.tga"
local BG_TINT_ALPHA = 0.60

local function ApplyLeaderboardsStyle(frame)
    if not frame or frame.__dcLeaderboardsStyle then return end
    frame.__dcLeaderboardsStyle = true

    if frame.SetBackdropColor then
        frame:SetBackdropColor(0, 0, 0, 0)
    end

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints()
    bg:SetTexture(BG_FELLEATHER)
    if bg.SetHorizTile then bg:SetHorizTile(false) end
    if bg.SetVertTile then bg:SetVertTile(false) end

    local tint = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    tint:SetAllPoints()
    tint:SetTexture(0, 0, 0, BG_TINT_ALPHA)

    frame.__dcBg = bg
    frame.__dcTint = tint
end

-- =====================================================================
-- Helper Functions for Friend/Guild checking
-- =====================================================================

-- Check if a player is on the friend list
function GF:IsPlayerFriend(name)
    if not name then return false end
    local numFriends = GetNumFriends()
    for i = 1, numFriends do
        local friendName = GetFriendInfo(i)
        if friendName and friendName:lower() == name:lower() then
            return true
        end
    end
    return false
end

-- Check if a player is in the same guild
function GF:IsPlayerInGuild(name)
    if not name then return false end
    if not IsInGuild() then return false end
    
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local guildMemberName = GetGuildRosterInfo(i)
        if guildMemberName then
            -- Remove realm name if present
            local shortName = guildMemberName:match("([^-]+)")
            if shortName and shortName:lower() == name:lower() then
                return true
            end
        end
    end
    return false
end

-- =====================================================================
-- Mythic+ Data
-- =====================================================================

-- Dungeon list - populated from server or fallback to defaults
local DUNGEON_LIST = {}
local dungeonListLoaded = false
local dungeonListRequested = false

-- Default dungeon data (fallback if server doesn't respond)
local DEFAULT_DUNGEONS = {
    { id = 574, name = "Utgarde Keep", short = "UK", mapId = 574 },
    { id = 576, name = "The Nexus", short = "NEX", mapId = 576 },
    { id = 601, name = "Azjol-Nerub", short = "AN", mapId = 601 },
    { id = 619, name = "Ahn'kahet", short = "OK", mapId = 619 },
    { id = 600, name = "Drak'Tharon Keep", short = "DTK", mapId = 600 },
    { id = 608, name = "Violet Hold", short = "VH", mapId = 608 },
    { id = 604, name = "Gundrak", short = "GD", mapId = 604 },
    { id = 599, name = "Halls of Stone", short = "HOS", mapId = 599 },
    { id = 602, name = "Halls of Lightning", short = "HOL", mapId = 602 },
    { id = 578, name = "The Oculus", short = "OCC", mapId = 578 },
    { id = 575, name = "Utgarde Pinnacle", short = "UP", mapId = 575 },
    { id = 595, name = "Culling of Stratholme", short = "COS", mapId = 595 },
    { id = 650, name = "Trial of the Champion", short = "TOC", mapId = 650 },
    { id = 632, name = "Forge of Souls", short = "FOS", mapId = 632 },
    { id = 658, name = "Pit of Saron", short = "POS", mapId = 658 },
    { id = 668, name = "Halls of Reflection", short = "HOR", mapId = 668 },
}

-- Initialize dungeon list with defaults
local function InitializeDungeonList()
    if dungeonListLoaded then return end
    -- Copy defaults
    for _, d in ipairs(DEFAULT_DUNGEONS) do
        table.insert(DUNGEON_LIST, d)
    end
    dungeonListLoaded = true
end

-- Request dungeon list from server
local function RequestDungeonList()
    if dungeonListRequested then return end
    dungeonListRequested = true
    
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder and DC.GroupFinder.GetDungeonList then
        DC.GroupFinder.GetDungeonList()
        GF.Print("Requesting dungeon list from server...")
    else
        -- Fallback to defaults
        InitializeDungeonList()
    end
end

-- Function to update dungeon list from server data
function GF:UpdateDungeonList(dungeonData)
    if not dungeonData or type(dungeonData) ~= "table" then 
        -- Use defaults if no data
        InitializeDungeonList()
        return 
    end
    
    wipe(DUNGEON_LIST)
    for _, d in ipairs(dungeonData) do
        table.insert(DUNGEON_LIST, {
            id = d.id or d.dungeon_id or 0,
            name = d.name or d.dungeon_name or "Unknown",
            short = d.short or d.short_name or "",
            timer = d.timer or d.base_timer or 1800,
            bosses = d.bosses or d.boss_count or 0,
            difficulty = d.difficulty or d.difficulty_rating or 5,
            mapId = d.mapId or d.map_id or 0,
        })
    end
    
    dungeonListLoaded = true
    GF.Print("Dungeon list updated: " .. #DUNGEON_LIST .. " dungeons from server")
end

-- Ensure list is initialized or requested
InitializeDungeonList()

local ROLE_ICONS = {
    tank = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:0:19:22:41|t",
    healer = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:1:20|t",
    dps = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:22:41|t",
}

-- Sample data (will be replaced by server data)
local mockGroups = {
    { id = 1, dungeon = "Utgarde Keep", level = 15, leader = "TankMaster", tank = true, healer = true, dps = 1, note = "Weekly key, fast run" },
    { id = 2, dungeon = "The Nexus", level = 12, leader = "HealBot", tank = false, healer = true, dps = 2, note = "LF tank and 1 DPS" },
    { id = 3, dungeon = "Halls of Lightning", level = 18, leader = "ProDPS", tank = true, healer = false, dps = 2, note = "Need healer, know fights" },
    { id = 4, dungeon = "Azjol-Nerub", level = 8, leader = "Newbie", tank = false, healer = false, dps = 1, note = "Chill run, learning" },
}

-- =====================================================================
-- Create Mythic Tab
-- =====================================================================

function GF:CreateMythicTab()
    local parent = self.mainFrame.contentFrame
    
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()
    
    -- Sub-tabs: Browse | Create | My Keystone
    local subTabFrame = CreateFrame("Frame", nil, frame)
    subTabFrame:SetPoint("TOPLEFT", 0, 0)
    subTabFrame:SetPoint("TOPRIGHT", 0, 0)
    subTabFrame:SetHeight(26)
    
    local subTabs = { "Browse Groups", "Create Group", "My Keystone" }
    local subTabBtns = {}
    local subTabWidth = 140
    
    for i, tabText in ipairs(subTabs) do
        local btn = CreateFrame("Button", nil, subTabFrame)
        btn:SetSize(subTabWidth, 22)
        btn:SetPoint("LEFT", (i - 1) * (subTabWidth + 4) + 10, 0)
        
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(tabText)
        btn.text:SetTextColor(0.7, 0.7, 0.7)
        
        btn.tabIndex = i
        btn:SetScript("OnClick", function(self)
            GF:SelectMythicSubTab(self.tabIndex)
        end)
        btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        
        subTabBtns[i] = btn
    end
    frame.subTabBtns = subTabBtns
    
    -- Content area
    local contentArea = CreateFrame("Frame", nil, frame)
    contentArea:SetPoint("TOPLEFT", 0, -30)
    contentArea:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.contentArea = contentArea
    
    self.MythicTabContent = frame
    self.MythicSubTabs = {}
    
    self:CreateMythicBrowsePanel(contentArea)
    self:CreateMythicCreatePanel(contentArea)
    self:CreateMythicKeystonePanel(contentArea)
    
    self:SelectMythicSubTab(1)
end

function GF:SelectMythicSubTab(index)
    if not self.MythicTabContent then return end
    
    local subTabs = self.MythicTabContent.subTabBtns
    for i, btn in ipairs(subTabs) do
        if i == index then
            btn.bg:SetColorTexture(0.25, 0.25, 0.25, 1)
            btn.text:SetTextColor(1, 0.82, 0) -- Gold
        else
            btn.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
            btn.text:SetTextColor(0.7, 0.7, 0.7)
        end
    end
    
    -- Show/hide sub-panels
    if self.MythicBrowsePanel then self.MythicBrowsePanel:SetShown(index == 1) end
    if self.MythicCreatePanel then self.MythicCreatePanel:SetShown(index == 2) end
    if self.MythicKeystonePanel then self.MythicKeystonePanel:SetShown(index == 3) end
end

-- =====================================================================
-- Browse Groups Panel
-- =====================================================================

function GF:CreateMythicBrowsePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()
    
    -- Header bar with title
    local headerBar = CreateFrame("Frame", nil, panel)
    headerBar:SetPoint("TOPLEFT", 0, 0)
    headerBar:SetPoint("TOPRIGHT", 0, 0)
    headerBar:SetHeight(32)
    headerBar.bg = headerBar:CreateTexture(nil, "BACKGROUND")
    headerBar.bg:SetAllPoints()
    headerBar.bg:SetColorTexture(0.1, 0.1, 0.1, 0.95)
    
    local headerTitle = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerTitle:SetPoint("LEFT", 12, 0)
    headerTitle:SetText("Find a Group")
    headerTitle:SetTextColor(1, 0.82, 0) -- Gold
    
    -- Refresh button (right side of header)
    local refreshBtn = CreateFrame("Button", nil, headerBar)
    refreshBtn:SetSize(24, 24)
    refreshBtn:SetPoint("RIGHT", -8, 0)
    refreshBtn:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
    refreshBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    refreshBtn:SetScript("OnClick", function()
        GF:RefreshMythicGroups()
    end)
    refreshBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Refresh List")
        GameTooltip:Show()
    end)
    refreshBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Filter bar
    local filterBar = CreateFrame("Frame", nil, panel)
    filterBar:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -1)
    filterBar:SetPoint("TOPRIGHT", headerBar, "BOTTOMRIGHT", 0, -1)
    filterBar:SetHeight(28)
    filterBar.bg = filterBar:CreateTexture(nil, "BACKGROUND")
    filterBar.bg:SetAllPoints()
    filterBar.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
    
    local filterLabel = filterBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterLabel:SetPoint("LEFT", 12, 0)
    filterLabel:SetText("Dungeon:")
    filterLabel:SetTextColor(1, 0.82, 0) -- Gold
    
    -- Dropdown button (styled like retail)
    local filterDropdown = CreateFrame("Button", nil, filterBar)
    filterDropdown:SetSize(160, 20)
    filterDropdown:SetPoint("LEFT", filterLabel, "RIGHT", 8, 0)
    filterDropdown.bg = filterDropdown:CreateTexture(nil, "BACKGROUND")
    filterDropdown.bg:SetAllPoints()
    filterDropdown.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
    filterDropdown.text = filterDropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    filterDropdown.text:SetPoint("LEFT", 8, 0)
    filterDropdown.text:SetText("All Dungeons")
    
    -- Arrow indicator
    local filterArrow = filterDropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    filterArrow:SetPoint("RIGHT", -6, 0)
    filterArrow:SetText("▼")
    
    -- Border
    filterDropdown.border = filterDropdown:CreateTexture(nil, "BORDER")
    filterDropdown.border:SetPoint("TOPLEFT", -1, 1)
    filterDropdown.border:SetPoint("BOTTOMRIGHT", 1, -1)
    filterDropdown.border:SetColorTexture(0.3, 0.3, 0.35, 1)
    
    -- Click handler
    filterDropdown:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.25, 0.25, 0.25, 1) end)
    filterDropdown:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.2, 0.2, 0.2, 1) end)
    filterDropdown:SetScript("OnClick", function(self)
        GF:ShowBrowseFilterDropdown(self, panel)
    end)
    panel.filterDropdown = filterDropdown
    panel.selectedFilter = nil
    
    -- Column headers
    local columnBar = CreateFrame("Frame", nil, panel)
    columnBar:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -1)
    columnBar:SetPoint("TOPRIGHT", filterBar, "BOTTOMRIGHT", 0, -1)
    columnBar:SetHeight(22)
    columnBar.bg = columnBar:CreateTexture(nil, "BACKGROUND")
    columnBar.bg:SetAllPoints()
    columnBar.bg:SetColorTexture(0.06, 0.06, 0.08, 1)
    
    local col1 = columnBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    col1:SetPoint("LEFT", 12, 0)
    col1:SetText("|cff666666DUNGEON|r")
    
    local col2 = columnBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    col2:SetPoint("LEFT", 200, 0)
    col2:SetText("|cff666666LEADER|r")
    
    local col3 = columnBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    col3:SetPoint("LEFT", 350, 0)
    col3:SetText("|cff666666ROLES NEEDED|r")
    
    -- Group list scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "DCMythicBrowseScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", columnBar, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 35)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    panel.scrollChild = scrollChild
    panel.scrollFrame = scrollFrame
    
    -- Empty state message
    local emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    emptyText:SetPoint("CENTER", scrollFrame, "CENTER", 0, 20)
    emptyText:SetText("|cff666666No groups found|r")
    panel.emptyText = emptyText
    
    local emptySubtext = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptySubtext:SetPoint("TOP", emptyText, "BOTTOM", 0, -8)
    emptySubtext:SetText("|cff555555Click Refresh or create your own group|r")
    panel.emptySubtext = emptySubtext
    
    -- Loading indicator
    local loadingText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    loadingText:SetPoint("CENTER", scrollFrame, "CENTER", 0, 0)
    loadingText:SetText("|cffaaaaaa" .. SEARCH .. "...|r")
    loadingText:Hide()
    panel.loadingText = loadingText
    
    -- Bottom action bar
    local actionBar = CreateFrame("Frame", nil, panel)
    actionBar:SetPoint("BOTTOMLEFT", 0, 0)
    actionBar:SetPoint("BOTTOMRIGHT", 0, 0)
    actionBar:SetHeight(32)
    actionBar.bg = actionBar:CreateTexture(nil, "BACKGROUND")
    actionBar.bg:SetAllPoints()
    actionBar.bg:SetColorTexture(0.10, 0.10, 0.12, 1)
    
    -- Results count
    local resultsText = actionBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resultsText:SetPoint("LEFT", 12, 0)
    resultsText:SetText("|cff888888Results: 0|r")
    panel.resultsText = resultsText
    
    -- View Applicants button (only visible when you have a listing)
    local applicantBtn = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
    applicantBtn:SetSize(120, 22)
    applicantBtn:SetPoint("RIGHT", -12, 0)
    applicantBtn:SetText("View Applicants")
    applicantBtn:GetFontString():SetTextColor(1, 0.82, 0)
    applicantBtn:SetScript("OnClick", function()
        GF:ShowApplicantPanel()
    end)
    applicantBtn:Hide()  -- Hidden by default, shown when you create a group
    panel.applicantBtn = applicantBtn
    
    -- Applicant count badge (on the button)
    local applicantBadge = applicantBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    applicantBadge:SetPoint("RIGHT", applicantBtn, "LEFT", -5, 0)
    applicantBadge:SetText("")
    panel.applicantBadge = applicantBadge
    
    self.MythicBrowsePanel = panel
    self:PopulateMythicGroups(mockGroups)
end

function GF:PopulateMythicGroups(groups)
    local panel = self.MythicBrowsePanel
    if not panel or not panel.scrollChild then return end
    
    -- Hide loading indicator
    if panel.loadingText then panel.loadingText:Hide() end
    
    local scrollChild = panel.scrollChild
    
    -- Clear existing rows
    for _, child in ipairs({ scrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Handle empty state
    if not groups or #groups == 0 then
        if panel.emptyText then panel.emptyText:Show() end
        if panel.emptySubtext then panel.emptySubtext:Show() end
        if panel.resultsText then panel.resultsText:SetText("|cff888888Results: 0|r") end
        scrollChild:SetHeight(1)
        return
    end
    
    -- Hide empty state
    if panel.emptyText then panel.emptyText:Hide() end
    if panel.emptySubtext then panel.emptySubtext:Hide() end
    if panel.resultsText then panel.resultsText:SetText("|cff888888Results: " .. #groups .. "|r") end
    
    local yOffset = 0
    local rowHeight = 52
    local altColor = false
    
    for i, group in ipairs(groups) do
        local row = CreateFrame("Button", nil, scrollChild)
        row:SetSize(scrollChild:GetWidth() - 4, rowHeight - 2)
        row:SetPoint("TOPLEFT", 2, -yOffset)
        
        -- Alternating row colors (subtle)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        if altColor then
            row.bg:SetColorTexture(0.08, 0.08, 0.10, 1)
        else
            row.bg:SetColorTexture(0.06, 0.06, 0.08, 1)
        end
        altColor = not altColor
        
        -- Hover highlight
        row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(0.2, 0.4, 0.6, 0.3)
        
        -- Left accent bar (key level color)
        local accent = row:CreateTexture(nil, "ARTWORK")
        accent:SetPoint("TOPLEFT", 0, 0)
        accent:SetPoint("BOTTOMLEFT", 0, 0)
        accent:SetWidth(4)
        -- Color based on key level
        local level = group.level or 2
        if level >= 20 then
            accent:SetColorTexture(1.0, 0.5, 0.0, 1) -- Orange for high keys
        elseif level >= 15 then
            accent:SetColorTexture(0.64, 0.21, 0.93, 1) -- Purple
        elseif level >= 10 then
            accent:SetColorTexture(0.0, 0.44, 0.87, 1) -- Blue
        else
            accent:SetColorTexture(0.12, 0.75, 0.12, 1) -- Green
        end
        
        -- Key level badge
        local levelBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        levelBadge:SetPoint("LEFT", 12, 4)
        levelBadge:SetText("|cffffffff+" .. level .. "|r")
        
        -- Dungeon name
        local dungeonText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        dungeonText:SetPoint("TOPLEFT", 50, -8)
        dungeonText:SetText(group.dungeon or "Unknown Dungeon")
        
        -- Leader name with markers
        local leaderText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        leaderText:SetPoint("TOPLEFT", 50, -24)
        
        local leaderName = group.leader or "Unknown"
        local markerText = ""
        local leaderColor = "888888"
        
        -- Check if this is player's own group
        local playerName = UnitName("player")
        if group.isOwn or leaderName == playerName then
            markerText = " |cff00ff00[Your Group]|r"
            leaderColor = "00ff00"
        -- Check if leader is a friend
        elseif GF:IsPlayerFriend(leaderName) then
            markerText = " |cff00ccff[Friend]|r"
            leaderColor = "00ccff"
        -- Check if leader is in same guild
        elseif GF:IsPlayerInGuild(leaderName) then
            markerText = " |cff44ff44[Guild]|r"
            leaderColor = "44ff44"
        end
        
        leaderText:SetText("|cff" .. leaderColor .. leaderName .. "|r" .. markerText)
        
        -- Roles needed (icons)
        local rolesFrame = CreateFrame("Frame", nil, row)
        rolesFrame:SetPoint("LEFT", 350, 0)
        rolesFrame:SetSize(100, 24)
        
        local roleX = 0
        if not group.tank then
            local tankIcon = rolesFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            tankIcon:SetPoint("LEFT", roleX, 0)
            tankIcon:SetText(ROLE_ICONS.tank)
            roleX = roleX + 18
        end
        if not group.healer then
            local healIcon = rolesFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            healIcon:SetPoint("LEFT", roleX, 0)
            healIcon:SetText(ROLE_ICONS.healer)
            roleX = roleX + 18
        end
        local dpsNeeded = 3 - (group.dps or 0)
        for j = 1, dpsNeeded do
            local dpsIcon = rolesFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            dpsIcon:SetPoint("LEFT", roleX, 0)
            dpsIcon:SetText(ROLE_ICONS.dps)
            roleX = roleX + 18
        end
        
        -- Note (if any)
        if group.note and group.note ~= "" then
            local noteText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            noteText:SetPoint("BOTTOMLEFT", 50, 6)
            noteText:SetWidth(280)
            noteText:SetJustifyH("LEFT")
            noteText:SetText("|cff666666" .. group.note .. "|r")
        end
        
        -- Check if this is player's own group for button logic
        local isOwnGroup = group.isOwn or (group.leader == playerName)
        
        -- Action button (right side) - different for own groups vs others
        local actionBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        actionBtn:SetSize(70, 22)
        actionBtn:SetPoint("RIGHT", -10, 0)
        
        if isOwnGroup then
            -- Own group - show Cancel button
            actionBtn:SetText("Cancel")
            actionBtn:GetFontString():SetTextColor(1, 0.3, 0.3)
            actionBtn:SetScript("OnClick", function()
                GF:CancelGroup(group.id)
            end)
            
            -- Add special border/glow for own groups
            local ownBorder = row:CreateTexture(nil, "OVERLAY")
            ownBorder:SetPoint("TOPLEFT", 0, 0)
            ownBorder:SetPoint("BOTTOMRIGHT", 0, 0)
            ownBorder:SetColorTexture(0, 1, 0, 0.1)
        else
            -- Other groups - show Sign Up button
            actionBtn:SetText("Sign Up")
            actionBtn:SetScript("OnClick", function()
                GF:ApplyToGroup(group.id)
            end)
        end
        
        -- Row click to select
        row:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                -- Could show details panel
            end
        end)
        
        yOffset = yOffset + rowHeight
    end
    
    scrollChild:SetHeight(math.max(yOffset, 1))
end

function GF:RefreshMythicGroups()
    GF.Print("Refreshing group list...")
    
    -- Show loading indicator (but don't clear existing data yet)
    local panel = self.MythicBrowsePanel
    if panel and panel.loadingText then
        panel.loadingText:Show()
    end
    
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder then
        DC.GroupFinder.Search({})
        -- Hide loading after timeout if no response
        C_Timer.After(5, function()
            if panel and panel.loadingText and panel.loadingText:IsShown() then
                panel.loadingText:Hide()
                GF.Print("Server didn't respond. Showing cached data.")
            end
        end)
    else
        -- No protocol available - use demo data with optional filter
        if panel and panel.loadingText then
            panel.loadingText:Hide()
        end
        
        -- Apply filter to mock data
        local filteredGroups = {}
        local filterDungeon = panel and panel.selectedFilter
        for _, group in ipairs(mockGroups) do
            if not filterDungeon or group.dungeon == filterDungeon then
                table.insert(filteredGroups, group)
            end
        end
        
        self:PopulateMythicGroups(filteredGroups)
        GF.Print("Protocol not connected. Using demo data.")
    end
end

function GF:ApplyToGroup(groupId)
    GF.Print("Applying to group #" .. groupId .. "...")
    -- Show dialog to select roles
    GF:ShowApplicationDialog(groupId)
end

function GF:CancelGroup(groupId)
    GF.Print("Cancelling group #" .. groupId .. "...")
    
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder and DC.GroupFinder.Delist then
        DC.GroupFinder.Delist(groupId)
    elseif DC and DC.Request then
        -- Fallback: send cancel request via protocol  
        DC:Request("GRPF", 0x16, { listingId = groupId })  -- CMSG_DELIST_GROUP
    end
    
    -- Remove from local mock list
    for i, group in ipairs(mockGroups) do
        if group.id == groupId then
            table.remove(mockGroups, i)
            break
        end
    end
    
    -- Refresh the list
    C_Timer.After(0.3, function()
        GF:PopulateMythicGroups(mockGroups)
    end)
end

-- =====================================================================
-- Dungeon Dropdown Menu (3.3.5a compatible)
-- =====================================================================

local dungeonDropdownFrame = nil
local dungeonButtons = {}  -- Reusable button pool

function GF:ShowDungeonDropdown(anchorBtn, panel)
    local mainFrame = self.mainFrame
    local DROPDOWN_WIDTH = 220
    local CONTENT_WIDTH = 190
    local ITEM_HEIGHT = 26
    
    -- Create or reuse dropdown frame - parent to main frame so it stays within the addon
    if not dungeonDropdownFrame then
        dungeonDropdownFrame = CreateFrame("Frame", "DCDungeonDropdownMenu", mainFrame or UIParent)
        dungeonDropdownFrame:SetFrameStrata("DIALOG")
        dungeonDropdownFrame:SetFrameLevel(100)
        dungeonDropdownFrame:SetSize(DROPDOWN_WIDTH, 300)
        
        dungeonDropdownFrame.bg = dungeonDropdownFrame:CreateTexture(nil, "BACKGROUND")
        dungeonDropdownFrame.bg:SetAllPoints()
        dungeonDropdownFrame.bg:SetColorTexture(0.1, 0.1, 0.1, 0.98)
        
        -- Border
        dungeonDropdownFrame.border = CreateFrame("Frame", nil, dungeonDropdownFrame)
        dungeonDropdownFrame.border:SetPoint("TOPLEFT", -1, 1)
        dungeonDropdownFrame.border:SetPoint("BOTTOMRIGHT", 1, -1)
        local borderTex = dungeonDropdownFrame.border:CreateTexture(nil, "BACKGROUND")
        borderTex:SetAllPoints()
        borderTex:SetColorTexture(0.3, 0.3, 0.3, 1)
        dungeonDropdownFrame.border:SetFrameLevel(dungeonDropdownFrame:GetFrameLevel() - 1)
        
        -- Close button at top
        local closeBtn = CreateFrame("Button", nil, dungeonDropdownFrame)
        closeBtn:SetSize(18, 18)
        closeBtn:SetPoint("TOPRIGHT", -2, -2)
        closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
        closeBtn:SetScript("OnClick", function() dungeonDropdownFrame:Hide() end)
        
        -- Scroll frame for dungeons
        local scrollFrame = CreateFrame("ScrollFrame", "DCDungeonDropdownScroll", dungeonDropdownFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 4, -24)
        scrollFrame:SetPoint("BOTTOMRIGHT", -26, 4)
        dungeonDropdownFrame.scrollFrame = scrollFrame
        
        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetSize(CONTENT_WIDTH, 1)
        scrollFrame:SetScrollChild(scrollChild)
        dungeonDropdownFrame.scrollChild = scrollChild
        
        -- Auto-close when main frame hides
        if mainFrame then
            mainFrame:HookScript("OnHide", function()
                dungeonDropdownFrame:Hide()
            end)
        end
    end
    
    -- Create click-catcher that closes dropdown when clicking outside
    if not dungeonDropdownFrame.clickCatcher then
        dungeonDropdownFrame.clickCatcher = CreateFrame("Button", nil, dungeonDropdownFrame:GetParent())
        dungeonDropdownFrame.clickCatcher:SetAllPoints(dungeonDropdownFrame:GetParent())
        dungeonDropdownFrame.clickCatcher:SetFrameLevel(dungeonDropdownFrame:GetFrameLevel() - 1)
        dungeonDropdownFrame.clickCatcher:SetScript("OnClick", function()
            dungeonDropdownFrame:Hide()
        end)
        dungeonDropdownFrame.clickCatcher:Hide()
    end
    
    dungeonDropdownFrame:SetScript("OnShow", function(self)
        if self.clickCatcher then
            self.clickCatcher:Show()
        end
    end)
    dungeonDropdownFrame:SetScript("OnHide", function(self)
        if self.clickCatcher then
            self.clickCatcher:Hide()
        end
    end)
    
    -- Position dropdown below button
    dungeonDropdownFrame:ClearAllPoints()
    dungeonDropdownFrame:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
    
    -- Ensure dungeon list is populated
    if #DUNGEON_LIST == 0 then
        InitializeDungeonList()
    end
    
    -- Hide all existing buttons first
    for _, btn in ipairs(dungeonButtons) do
        btn:Hide()
    end
    
    local scrollChild = dungeonDropdownFrame.scrollChild
    local yOffset = 0
    
    -- Create/reuse buttons for each dungeon
    for i, dungeon in ipairs(DUNGEON_LIST) do
        local btn = dungeonButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, scrollChild)
            btn:SetSize(CONTENT_WIDTH, ITEM_HEIGHT)
            
            btn.bg = btn:CreateTexture(nil, "BACKGROUND")
            btn.bg:SetAllPoints()
            btn.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
            
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            btn.text:SetPoint("LEFT", 10, 0)
            btn.text:SetPoint("RIGHT", -10, 0)
            btn.text:SetJustifyH("LEFT")
            
            btn:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(0.25, 0.25, 0.25, 1)
            end)
            btn:SetScript("OnLeave", function(self)
                self.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
            end)
            
            dungeonButtons[i] = btn
        end
        
        -- Update button data
        btn:SetParent(scrollChild)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", 0, -yOffset)
        btn.text:SetText(dungeon.name)
        btn.dungeonData = dungeon
        
        btn:SetScript("OnClick", function(self)
            panel.selectedDungeon = self.dungeonData.name
            panel.selectedDungeonId = self.dungeonData.id
            panel.dungeonBtn.text:SetText(self.dungeonData.name)
            dungeonDropdownFrame:Hide()
        end)
        
        btn:Show()
        yOffset = yOffset + ITEM_HEIGHT
    end
    
    -- Set scroll child height and show dropdown
    local totalHeight = math.max(yOffset, 1)
    scrollChild:SetHeight(totalHeight)
    dungeonDropdownFrame:SetHeight(math.min(totalHeight + 32, 400))
    dungeonDropdownFrame:Show()
end

-- =====================================================================
-- Browse Filter Dropdown (for filtering groups by dungeon)
-- =====================================================================

local browseFilterFrame = nil
local browseFilterButtons = {}  -- Reusable button pool

function GF:ShowBrowseFilterDropdown(anchorBtn, panel)
    local mainFrame = self.mainFrame
    local DROPDOWN_WIDTH = 200
    local CONTENT_WIDTH = 170
    local ITEM_HEIGHT = 24
    
    if not browseFilterFrame then
        browseFilterFrame = CreateFrame("Frame", "DCBrowseFilterDropdown", mainFrame or UIParent)
        browseFilterFrame:SetFrameStrata("DIALOG")
        browseFilterFrame:SetFrameLevel(100)
        browseFilterFrame:SetSize(DROPDOWN_WIDTH, 300)
        
        browseFilterFrame.bg = browseFilterFrame:CreateTexture(nil, "BACKGROUND")
        browseFilterFrame.bg:SetAllPoints()
        browseFilterFrame.bg:SetColorTexture(0.1, 0.1, 0.1, 0.98)
        
        -- Border
        browseFilterFrame.border = CreateFrame("Frame", nil, browseFilterFrame)
        browseFilterFrame.border:SetPoint("TOPLEFT", -1, 1)
        browseFilterFrame.border:SetPoint("BOTTOMRIGHT", 1, -1)
        local borderTex = browseFilterFrame.border:CreateTexture(nil, "BACKGROUND")
        borderTex:SetAllPoints()
        borderTex:SetColorTexture(0.3, 0.3, 0.3, 1)
        browseFilterFrame.border:SetFrameLevel(browseFilterFrame:GetFrameLevel() - 1)
        
        -- Close button
        local closeBtn = CreateFrame("Button", nil, browseFilterFrame)
        closeBtn:SetSize(18, 18)
        closeBtn:SetPoint("TOPRIGHT", -2, -2)
        closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
        closeBtn:SetScript("OnClick", function() browseFilterFrame:Hide() end)
        
        -- Scroll frame
        local scrollFrame = CreateFrame("ScrollFrame", "DCBrowseFilterScroll", browseFilterFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 4, -24)
        scrollFrame:SetPoint("BOTTOMRIGHT", -26, 4)
        browseFilterFrame.scrollFrame = scrollFrame
        
        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetSize(CONTENT_WIDTH, 1)
        scrollFrame:SetScrollChild(scrollChild)
        browseFilterFrame.scrollChild = scrollChild
        
        -- Auto-close when main frame hides
        if mainFrame then
            mainFrame:HookScript("OnHide", function()
                browseFilterFrame:Hide()
            end)
        end
    end
    
    -- Create click-catcher for auto-close
    if not browseFilterFrame.clickCatcher then
        browseFilterFrame.clickCatcher = CreateFrame("Button", nil, browseFilterFrame:GetParent())
        browseFilterFrame.clickCatcher:SetAllPoints(browseFilterFrame:GetParent())
        browseFilterFrame.clickCatcher:SetFrameLevel(browseFilterFrame:GetFrameLevel() - 1)
        browseFilterFrame.clickCatcher:SetScript("OnClick", function()
            browseFilterFrame:Hide()
        end)
        browseFilterFrame.clickCatcher:Hide()
    end
    
    browseFilterFrame:SetScript("OnShow", function(self)
        if self.clickCatcher then self.clickCatcher:Show() end
    end)
    browseFilterFrame:SetScript("OnHide", function(self)
        if self.clickCatcher then self.clickCatcher:Hide() end
    end)
    
    browseFilterFrame:ClearAllPoints()
    browseFilterFrame:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
    
    -- Ensure dungeon list is populated
    if #DUNGEON_LIST == 0 then
        InitializeDungeonList()
    end
    
    -- Hide all existing buttons first
    for _, btn in ipairs(browseFilterButtons) do
        btn:Hide()
    end
    
    local scrollChild = browseFilterFrame.scrollChild
    local yOffset = 0
    local btnIndex = 1
    
    -- Helper to create/reuse a button
    local function GetButton()
        local btn = browseFilterButtons[btnIndex]
        if not btn then
            btn = CreateFrame("Button", nil, scrollChild)
            btn:SetSize(CONTENT_WIDTH, ITEM_HEIGHT)
            
            btn.bg = btn:CreateTexture(nil, "BACKGROUND")
            btn.bg:SetAllPoints()
            btn.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
            
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            btn.text:SetPoint("LEFT", 10, 0)
            btn.text:SetPoint("RIGHT", -10, 0)
            btn.text:SetJustifyH("LEFT")
            
            btn:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(0.25, 0.25, 0.25, 1)
            end)
            btn:SetScript("OnLeave", function(self)
                self.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
            end)
            
            browseFilterButtons[btnIndex] = btn
        end
        btnIndex = btnIndex + 1
        return btn
    end
    
    -- "All Dungeons" option
    local allBtn = GetButton()
    allBtn:SetParent(scrollChild)
    allBtn:ClearAllPoints()
    allBtn:SetPoint("TOPLEFT", 0, -yOffset)
    allBtn.text:SetText("|cff44ff44All Dungeons|r")
    allBtn:SetScript("OnClick", function()
        panel.selectedFilter = nil
        panel.filterDropdown.text:SetText("All Dungeons")
        browseFilterFrame:Hide()
        GF:RefreshMythicGroups()
    end)
    allBtn:Show()
    yOffset = yOffset + ITEM_HEIGHT
    
    -- Dungeon options
    for _, dungeon in ipairs(DUNGEON_LIST) do
        local btn = GetButton()
        btn:SetParent(scrollChild)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", 0, -yOffset)
        btn.text:SetText(dungeon.name)
        btn.dungeonData = dungeon
        
        btn:SetScript("OnClick", function(self)
            panel.selectedFilter = self.dungeonData.name
            panel.filterDropdown.text:SetText(self.dungeonData.name)
            browseFilterFrame:Hide()
            GF:RefreshMythicGroups()
        end)
        btn:Show()
        yOffset = yOffset + ITEM_HEIGHT
    end
    
    -- Set scroll child height and show dropdown
    local totalHeight = math.max(yOffset, 1)
    scrollChild:SetHeight(totalHeight)
    browseFilterFrame:SetHeight(math.min(totalHeight + 32, 400))
    browseFilterFrame:Show()
end

-- =====================================================================
-- Create Group Panel
-- =====================================================================

function GF:CreateMythicCreatePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()
    
    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Create a Mythic+ Group")
    title:SetTextColor(1, 0.82, 0) -- Gold
    
    local y = -50
    
    -- Dungeon selection (simplified dropdown placeholder)
    local dungeonLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dungeonLabel:SetPoint("TOPLEFT", 20, y)
    dungeonLabel:SetText("Select Dungeon:")
    dungeonLabel:SetTextColor(1, 0.82, 0) -- Gold
    
    local dungeonBtn = CreateFrame("Button", nil, panel)
    dungeonBtn:SetSize(250, 28)
    dungeonBtn:SetPoint("TOPLEFT", 150, y + 3)
    
    -- Styled background
    dungeonBtn.bg = dungeonBtn:CreateTexture(nil, "BACKGROUND")
    dungeonBtn.bg:SetAllPoints()
    dungeonBtn.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    
    -- Border
    dungeonBtn.border = CreateFrame("Frame", nil, dungeonBtn)
    dungeonBtn.border:SetPoint("TOPLEFT", -1, 1)
    dungeonBtn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    dungeonBtn.border:SetFrameLevel(dungeonBtn:GetFrameLevel() - 1)
    local borderTex = dungeonBtn.border:CreateTexture(nil, "BACKGROUND")
    borderTex:SetAllPoints()
    borderTex:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    dungeonBtn.text = dungeonBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dungeonBtn.text:SetPoint("LEFT", 12, 0)
    dungeonBtn.text:SetText("Choose Dungeon...")
    
    -- Arrow indicator
    local arrow = dungeonBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    arrow:SetPoint("RIGHT", -10, 0)
    arrow:SetText("▼")
    arrow:SetTextColor(1, 0.82, 0) -- Gold
    
    -- Highlight on hover
    dungeonBtn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.25, 0.25, 0.25, 1)
    end)
    dungeonBtn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    end)
    
    -- Click to show dropdown menu
    dungeonBtn:SetScript("OnClick", function(self)
        GF:ShowDungeonDropdown(self, panel)
    end)
    
    panel.dungeonBtn = dungeonBtn
    panel.selectedDungeon = nil
    panel.selectedDungeonId = nil
    y = y - 40
    
    -- Keystone level
    local levelLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    levelLabel:SetPoint("TOPLEFT", 20, y)
    levelLabel:SetText("Keystone Level:")
    levelLabel:SetTextColor(1, 0.82, 0) -- Gold
    
    -- Styled level input
    local levelFrame = CreateFrame("Frame", nil, panel)
    levelFrame:SetSize(80, 28)
    levelFrame:SetPoint("TOPLEFT", 150, y + 3)
    levelFrame.bg = levelFrame:CreateTexture(nil, "BACKGROUND")
    levelFrame.bg:SetAllPoints()
    levelFrame.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    levelFrame.border = levelFrame:CreateTexture(nil, "BORDER")
    levelFrame.border:SetPoint("TOPLEFT", -1, 1)
    levelFrame.border:SetPoint("BOTTOMRIGHT", 1, -1)
    levelFrame.border:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    local levelEdit = CreateFrame("EditBox", nil, levelFrame)
    levelEdit:SetSize(70, 22)
    levelEdit:SetPoint("CENTER")
    levelEdit:SetAutoFocus(false)
    levelEdit:SetNumeric(true)
    levelEdit:SetMaxLetters(3)
    levelEdit:SetText("10")
    levelEdit:SetFontObject(GameFontHighlight)
    levelEdit:SetJustifyH("CENTER")
    levelEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    levelEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    panel.levelEdit = levelEdit
    
    -- Plus/minus hint
    local levelHint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    levelHint:SetPoint("LEFT", levelFrame, "RIGHT", 10, 0)
    levelHint:SetText("|cff888888(2-30)|r")
    
    y = y - 40
    
    -- Note
    local noteLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noteLabel:SetPoint("TOPLEFT", 20, y)
    noteLabel:SetText("Group Note:")
    noteLabel:SetTextColor(1, 0.82, 0) -- Gold
    
    -- Styled note input
    local noteFrame = CreateFrame("Frame", nil, panel)
    noteFrame:SetSize(350, 28)
    noteFrame:SetPoint("TOPLEFT", 150, y + 3)
    noteFrame.bg = noteFrame:CreateTexture(nil, "BACKGROUND")
    noteFrame.bg:SetAllPoints()
    noteFrame.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    noteFrame.border = noteFrame:CreateTexture(nil, "BORDER")
    noteFrame.border:SetPoint("TOPLEFT", -1, 1)
    noteFrame.border:SetPoint("BOTTOMRIGHT", 1, -1)
    noteFrame.border:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    local noteEdit = CreateFrame("EditBox", nil, noteFrame)
    noteEdit:SetSize(340, 22)
    noteEdit:SetPoint("CENTER")
    noteEdit:SetAutoFocus(false)
    noteEdit:SetMaxLetters(100)
    noteEdit:SetFontObject(GameFontHighlight)
    noteEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    noteEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    panel.noteEdit = noteEdit
    
    y = y - 70
    
    -- Status message
    local statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("TOP", 0, y + 35)
    statusText:SetText("")
    panel.statusText = statusText
    
    -- Create button
    local createBtn = CreateFrame("Button", nil, panel)
    createBtn:SetSize(150, 30)
    createBtn:SetPoint("TOP", 0, y)
    
    createBtn.bg = createBtn:CreateTexture(nil, "BACKGROUND")
    createBtn.bg:SetAllPoints()
    createBtn.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
    
    createBtn.border = CreateFrame("Frame", nil, createBtn)
    createBtn.border:SetPoint("TOPLEFT", -1, 1)
    createBtn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    createBtn.border:SetFrameLevel(createBtn:GetFrameLevel() - 1)
    local btnBorder = createBtn.border:CreateTexture(nil, "BACKGROUND")
    btnBorder:SetAllPoints()
    btnBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    createBtn.text = createBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    createBtn.text:SetPoint("CENTER")
    createBtn.text:SetText("Create Group")
    createBtn.text:SetTextColor(1, 0.82, 0) -- Gold
    
    createBtn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.3, 0.3, 0.3, 1) end)
    createBtn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.2, 0.2, 0.2, 1) end)
    
    createBtn:SetScript("OnClick", function()
        if not panel.selectedDungeon then
            panel.statusText:SetText("|cffff4444Please select a dungeon first!|r")
            return
        end
        local dungeon = panel.selectedDungeon
        local dungeonId = panel.selectedDungeonId
        local level = tonumber(panel.levelEdit:GetText()) or 10
        local note = panel.noteEdit:GetText() or ""
        
        panel.statusText:SetText("|cff44ff44Creating group...|r")
        GF:CreateMythicGroup(dungeonId, dungeon, level, note)
    end)
    panel.createBtn = createBtn
    
    self.MythicCreatePanel = panel
end

function GF:CreateMythicGroup(dungeonId, dungeonName, level, note)
    GF.Print(string.format("Creating group: +%d %s", level, dungeonName))
    
    local playerName = UnitName("player") or "You"
    
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder then
        DC.GroupFinder.CreateListing({
            dungeonId = dungeonId,
            dungeonName = dungeonName,
            keyLevel = level,
            note = note,
            roles = { tank = false, healer = false, dps1 = true, dps2 = false, dps3 = false }
        })
        
        -- Show success feedback
        if self.MythicCreatePanel and self.MythicCreatePanel.statusText then
            self.MythicCreatePanel.statusText:SetText("|cff44ff44Group created!|r")
        end
        
        -- Add to local mock list for immediate visibility
        local newGroup = {
            id = #mockGroups + 100,
            dungeon = dungeonName,
            level = level,
            leader = playerName,
            tank = true,
            healer = false,
            dps = 1,
            note = note,
            isOwn = true
        }
        table.insert(mockGroups, 1, newGroup)
        
        -- Show the View Applicants button
        if self.MythicBrowsePanel and self.MythicBrowsePanel.applicantBtn then
            self.MythicBrowsePanel.applicantBtn:Show()
        end
        
        -- Switch to browse tab after short delay
        C_Timer.After(0.5, function()
            GF:SelectMythicSubTab(1)
            GF:PopulateMythicGroups(mockGroups)
        end)
    else
        -- Demo mode - add to mock list
        local newGroup = {
            id = #mockGroups + 1,
            dungeon = dungeonName,
            level = level,
            leader = playerName,
            tank = true,
            healer = false,
            dps = 1,
            note = note,
            isOwn = true
        }
        table.insert(mockGroups, 1, newGroup)
        
        if self.MythicCreatePanel and self.MythicCreatePanel.statusText then
            self.MythicCreatePanel.statusText:SetText("|cff44ff44Group created!|r")
        end
        
        -- Show the View Applicants button
        if self.MythicBrowsePanel and self.MythicBrowsePanel.applicantBtn then
            self.MythicBrowsePanel.applicantBtn:Show()
        end
        
        -- Switch to browse tab to show the new group
        C_Timer.After(0.5, function()
            GF:SelectMythicSubTab(1)
            GF:PopulateMythicGroups(mockGroups)
        end)
    end
end

-- =====================================================================
-- My Keystone Panel (includes Difficulty Switcher)
-- =====================================================================

local DIFFICULTY_OPTIONS = {
    { id = 0, name = "Normal", color = {1.0, 1.0, 1.0}, cmd = "normal" },
    { id = 1, name = "Heroic", color = {0.0, 0.44, 0.87}, cmd = "heroic" },
    { id = 2, name = "Mythic", color = {1.0, 0.5, 0.0}, cmd = "mythic" },
}

function GF:CreateMythicKeystonePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()
    
    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Your Mythic Keystone & Difficulty")
    title:SetTextColor(1, 0.82, 0) -- Gold
    
    -- =====================================================
    -- Keystone Display Section
    -- =====================================================
    local keystoneFrame = CreateFrame("Frame", nil, panel)
    keystoneFrame:SetSize(300, 100)
    keystoneFrame:SetPoint("TOP", 0, -40)
    
    keystoneFrame.bg = keystoneFrame:CreateTexture(nil, "BACKGROUND")
    keystoneFrame.bg:SetAllPoints()
    keystoneFrame.bg:SetColorTexture(0.15, 0.15, 0.15, 0.95)
    
    -- Border
    keystoneFrame.border = CreateFrame("Frame", nil, keystoneFrame)
    keystoneFrame.border:SetPoint("TOPLEFT", -1, 1)
    keystoneFrame.border:SetPoint("BOTTOMRIGHT", 1, -1)
    keystoneFrame.border:SetFrameLevel(keystoneFrame:GetFrameLevel() - 1)
    local kBorder = keystoneFrame.border:CreateTexture(nil, "BACKGROUND")
    kBorder:SetAllPoints()
    kBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    local keystoneIcon = keystoneFrame:CreateTexture(nil, "ARTWORK")
    keystoneIcon:SetSize(54, 54)
    keystoneIcon:SetPoint("LEFT", 15, 0)
    keystoneIcon:SetTexture("Interface\\Icons\\INV_Relics_Hourglass")
    panel.keystoneIcon = keystoneIcon
    
    local keystoneName = keystoneFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    keystoneName:SetPoint("TOPLEFT", keystoneIcon, "TOPRIGHT", 12, -5)
    keystoneName:SetText("|cff32c4ffMythic Keystone|r")
    panel.keystoneName = keystoneName
    
    local keystoneLevel = keystoneFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    keystoneLevel:SetPoint("TOPLEFT", keystoneName, "BOTTOMLEFT", 0, -4)
    keystoneLevel:SetText("Level: +?")
    keystoneLevel:SetTextColor(1, 0.82, 0) -- Gold
    panel.keystoneLevel = keystoneLevel
    
    local keystoneDungeon = keystoneFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    keystoneDungeon:SetPoint("TOPLEFT", keystoneLevel, "BOTTOMLEFT", 0, -4)
    keystoneDungeon:SetText("Dungeon: Unknown")
    panel.keystoneDungeon = keystoneDungeon
    
    -- Refresh keystone button
    local refreshBtn = CreateFrame("Button", nil, keystoneFrame)
    refreshBtn:SetSize(90, 22)
    refreshBtn:SetPoint("RIGHT", -10, 0)
    
    refreshBtn.bg = refreshBtn:CreateTexture(nil, "BACKGROUND")
    refreshBtn.bg:SetAllPoints()
    refreshBtn.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
    
    refreshBtn.border = CreateFrame("Frame", nil, refreshBtn)
    refreshBtn.border:SetPoint("TOPLEFT", -1, 1)
    refreshBtn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    refreshBtn.border:SetFrameLevel(refreshBtn:GetFrameLevel() - 1)
    local rBorder = refreshBtn.border:CreateTexture(nil, "BACKGROUND")
    rBorder:SetAllPoints()
    rBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    refreshBtn.text = refreshBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    refreshBtn.text:SetPoint("CENTER")
    refreshBtn.text:SetText("Refresh")
    refreshBtn.text:SetTextColor(1, 0.82, 0) -- Gold
    
    refreshBtn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.3, 0.3, 0.3, 1) end)
    refreshBtn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.2, 0.2, 0.2, 1) end)
    
    refreshBtn:SetScript("OnClick", function()
        GF:RequestKeystoneInfo()
    end)
    
    -- =====================================================
    -- Difficulty Switcher Section
    -- =====================================================
    local diffSection = CreateFrame("Frame", nil, panel)
    diffSection:SetSize(450, 140)
    diffSection:SetPoint("TOP", keystoneFrame, "BOTTOM", 0, -15)
    
    local diffTitle = diffSection:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    diffTitle:SetPoint("TOP", 0, -5)
    diffTitle:SetText("Dungeon Difficulty")
    diffTitle:SetTextColor(1, 0.82, 0) -- Gold
    
    local diffDesc = diffSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    diffDesc:SetPoint("TOP", diffTitle, "BOTTOM", 0, -3)
    diffDesc:SetText("|cff888888Change difficulty before entering a dungeon. Group leader only in groups.|r")
    
    -- Current difficulty display
    local currentDiffLabel = diffSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentDiffLabel:SetPoint("TOPLEFT", 20, -45)
    currentDiffLabel:SetText("Current:")
    currentDiffLabel:SetTextColor(1, 0.82, 0) -- Gold
    
    panel.currentDiffText = diffSection:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.currentDiffText:SetPoint("LEFT", currentDiffLabel, "RIGHT", 10, 0)
    panel.currentDiffText:SetText("|cff888888Checking...|r")
    
    -- Difficulty buttons
    local btnY = -75
    local btnWidth = 120
    local btnSpacing = 130
    local startX = (450 - (btnWidth * 3 + 20)) / 2
    
    panel.diffButtons = {}
    for i, diff in ipairs(DIFFICULTY_OPTIONS) do
        local btn = CreateFrame("Button", nil, diffSection)
        btn:SetSize(btnWidth, 30)
        btn:SetPoint("TOPLEFT", startX + ((i - 1) * btnSpacing), btnY)
        
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
        
        btn.border = CreateFrame("Frame", nil, btn)
        btn.border:SetPoint("TOPLEFT", -1, 1)
        btn.border:SetPoint("BOTTOMRIGHT", 1, -1)
        btn.border:SetFrameLevel(btn:GetFrameLevel() - 1)
        local bBorder = btn.border:CreateTexture(nil, "BACKGROUND")
        bBorder:SetAllPoints()
        bBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(diff.name)
        btn.text:SetTextColor(1, 0.82, 0) -- Gold
        
        btn.diffInfo = diff
        
        -- Color the button text
        local r, g, b = unpack(diff.color)
        btn:SetScript("OnShow", function(self)
            local fontString = self:GetFontString()
            if fontString then
                fontString:SetTextColor(r, g, b)
            end
        end)
        
        btn:SetScript("OnClick", function(self)
            GF:SetDifficulty(self.diffInfo)
        end)
        
        panel.diffButtons[i] = btn
    end
    
    -- Status text
    panel.diffStatusText = diffSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.diffStatusText:SetPoint("TOP", diffSection, "BOTTOM", 0, -5)
    panel.diffStatusText:SetText("")
    
    -- Request difficulty info button
    local infoBtn = CreateFrame("Button", nil, diffSection, "UIPanelButtonTemplate")
    infoBtn:SetSize(100, 22)
    infoBtn:SetPoint("TOPRIGHT", -10, -45)
    infoBtn:SetText("Check Info")
    infoBtn:SetScript("OnClick", function()
        GF:RequestDifficultyInfo()
    end)
    
    self.MythicKeystonePanel = panel
    
    -- Request info when panel is shown
    panel:SetScript("OnShow", function()
        C_Timer.After(0.2, function()
            GF:RequestDifficultyInfo()
        end)
    end)
    
    -- Request initial info
    C_Timer.After(0.5, function()
        GF:RequestDifficultyInfo()
    end)
end

function GF:SetDifficulty(diffInfo)
    if not diffInfo then return end
    
    GF.Print("Setting difficulty to " .. diffInfo.name .. "...")
    
    -- Use the DC.GroupFinder API for difficulty
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder then
        DC.GroupFinder.SetDifficulty("dungeon", diffInfo.cmd)
    end
    
    -- Update status
    if self.MythicKeystonePanel and self.MythicKeystonePanel.diffStatusText then
        self.MythicKeystonePanel.diffStatusText:SetText("|cff00ff00Difficulty change requested...|r")
    end
    
    -- Refresh after a short delay
    C_Timer.After(0.5, function()
        GF:RequestDifficultyInfo()
    end)
end

function GF:RequestDifficultyInfo()
    GF.Print("Checking difficulty...")
    
    -- First try to get from WoW API directly
    local diffId = GetDungeonDifficulty()
    local diffName = "Unknown"
    
    if diffId == 1 then
        diffName = "Normal"
    elseif diffId == 2 then
        diffName = "Heroic"
    elseif diffId == 3 then
        diffName = "Mythic"
    end
    
    -- Update display immediately with local info
    self:UpdateDifficultyDisplay(diffId, diffName)
    
    -- Also try DC.GroupFinder protocol for additional info
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder then
        DC.GroupFinder.GetKeystoneInfo()
    end
end

function GF:UpdateDifficultyDisplay(diffId, diffName)
    if not self.MythicKeystonePanel then return end
    
    local panel = self.MythicKeystonePanel
    local colorStr = "|cffffffff"
    
    for _, diff in ipairs(DIFFICULTY_OPTIONS) do
        if diff.id == diffId or diff.name:lower() == diffName:lower() then
            local r, g, b = unpack(diff.color)
            colorStr = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
            diffName = diff.name
            break
        end
    end
    
    panel.currentDiffText:SetText(colorStr .. diffName .. "|r")
    panel.diffStatusText:SetText("")
end

function GF:RequestKeystoneInfo()
    GF.Print("Requesting keystone info...")
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder then
        DC.GroupFinder.GetKeystoneInfo()
    end
    -- Also scan our local inventory for keystone immediately
    local namespace = rawget(_G, "DCMythicPlusHUD")
    if namespace and type(namespace) == "table" and type(namespace.ScanInventoryForKeystone) == "function" then
        namespace.ScanInventoryForKeystone()
    else
        if ScanInventoryForKeystone then ScanInventoryForKeystone() end
    end
end

function GF:UpdateKeystoneDisplay(data)
    if not self.MythicKeystonePanel then return end
    
    local panel = self.MythicKeystonePanel
    
    -- Handle keystone info (server sends keystoneDungeonName, keystoneLevel, hasKeystone)
    local namespace = rawget(_G, "DCMythicPlusHUD") or {}
    data = data or (namespace and namespace.serverKeystone) or nil
    local invKey = (namespace and namespace.inventoryKeystone) or nil
    local hasKey = false
    local keystoneDungeon = nil
    local keystoneLevel = 0
    if type(data) == "table" and data.hasKeystone then
        hasKey = true
        keystoneDungeon = data.keystoneDungeonName or data.dungeon
        keystoneLevel = data.keystoneLevel or data.level or 0
    end
    -- If server doesn't indicate a key but we find one in inventory, use that
    if (not hasKey) and invKey and invKey.hasKey then
        hasKey = true
        if not keystoneDungeon or keystoneDungeon == "" then
            keystoneDungeon = invKey.dungeonName
        end
        -- NOTE: in Lua, 0 is truthy; don't use `keystoneLevel = keystoneLevel or ...` here.
        if (not keystoneLevel) or keystoneLevel == 0 then
            keystoneLevel = invKey.level or 0
        end

        -- Avoid chat spam: only announce when the fallback key actually changes.
        -- DC currently uses generic keystones per level; dungeon may be nil/unknown.
        local sig = tostring(keystoneLevel)
        if GF._lastInvKeySig ~= sig then
            GF._lastInvKeySig = sig
            GF.Print("Using inventory keystone fallback: +" .. tostring(keystoneLevel))
        end
    end
    if hasKey then
        local dungeonName = keystoneDungeon
        if dungeonName and dungeonName ~= "" and dungeonName ~= "Unknown" then
            panel.keystoneDungeon:SetText("Dungeon: |cff32c4ff" .. dungeonName .. "|r")
        else
            panel.keystoneDungeon:SetText("Dungeon: |cff32c4ffAny|r")
        end
        panel.keystoneLevel:SetText(string.format("Level: |cff32c4ff+%d|r", keystoneLevel))
        panel.keystoneName:SetText("|cff32c4ffMythic Keystone|r")
    else
        -- No keystone
        panel.keystoneDungeon:SetText("|cff666666No keystone|r")
        panel.keystoneLevel:SetText("|cff666666Level: -|r")
        panel.keystoneName:SetText("|cff666666No Keystone|r")
    end
    
    -- Handle difficulty info (server sends dungeonDifficulty, dungeonDifficultyName)
    if data.dungeonDifficulty or data.dungeonDifficultyName then
        local diffId = data.dungeonDifficulty
        local diffName = data.dungeonDifficultyName or "Unknown"
        self:UpdateDifficultyDisplay(diffId, diffName)
    end
end

-- =====================================================================
-- Applicant Management System (Leader View)
-- =====================================================================
-- This section handles viewing and managing applicants when you're a group leader.
-- Retail-like behavior: See applicant's Name, Class, Role, Item Level, Rating

-- Store for pending applicants (keyed by listingId)
local pendingApplicants = {}
local myActiveListingId = nil

-- Class colors for display
local CLASS_COLORS = {
    ["WARRIOR"] = "C79C6E",
    ["PALADIN"] = "F58CBA",
    ["HUNTER"] = "ABD473",
    ["ROGUE"] = "FFF569",
    ["PRIEST"] = "FFFFFF",
    ["DEATHKNIGHT"] = "C41F3B",
    ["SHAMAN"] = "0070DE",
    ["MAGE"] = "69CCF0",
    ["WARLOCK"] = "9482C9",
    ["DRUID"] = "FF7D0A",
}

-- Class ID to class name mapping (server sends class as number)
local CLASS_ID_TO_NAME = {
    [1] = "WARRIOR",
    [2] = "PALADIN",
    [3] = "HUNTER",
    [4] = "ROGUE",
    [5] = "PRIEST",
    [6] = "DEATHKNIGHT",
    [7] = "SHAMAN",
    [8] = "MAGE",
    [9] = "WARLOCK",
    [11] = "DRUID",
}

-- Role text display
local ROLE_DISPLAY = {
    tank = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:0:19:22:41|t Tank",
    healer = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:1:20|t Healer",
    dps = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:22:41|t DPS",
}

-- Called when the server sends a new application notification
function GF:OnNewApplication(data)
    if not data then return end
    
    local listingId = data.listingId or myActiveListingId
    if not listingId then 
        GF.Print("Received application but no active listing found")
        return 
    end
    
    -- Initialize applicant list for this listing
    if not pendingApplicants[listingId] then
        pendingApplicants[listingId] = {}
    end
    
    -- Add applicant to pending list
    -- Convert class ID to name if server sends a number
    local className = data.playerClass or data.class or "WARRIOR"
    if type(className) == "number" then
        className = CLASS_ID_TO_NAME[className] or "WARRIOR"
    end
    
    local applicant = {
        guid = data.playerGuid or data.guid or "",
        name = data.playerName or data.name or "Unknown",
        class = className,
        role = data.role or "dps",
        itemLevel = data.itemLevel or data.ilvl or 0,
        rating = data.rating or data.mplusRating or 0,
        message = data.message or "",
        timestamp = time(),
        isFriend = data.isFriend or GF:IsPlayerFriend(data.playerName or data.name),
        isGuild = data.isGuild or GF:IsPlayerInGuild(data.playerName or data.name),
    }
    
    table.insert(pendingApplicants[listingId], applicant)
    
    -- Play sound to alert leader
    PlaySound(8459)  -- SOUNDKIT.RAID_WARNING (alert sound)
    
    -- Show notification
    local colorCode = CLASS_COLORS[applicant.class:upper()] or "FFFFFF"
    local roleDisplay = ROLE_DISPLAY[applicant.role] or applicant.role
    local extras = ""
    if applicant.isFriend then extras = extras .. " |cff00ccff[Friend]|r" end
    if applicant.isGuild then extras = extras .. " |cff44ff44[Guild]|r" end
    
    GF.Print(string.format(
        "|cffffff00New Applicant:|r |cff%s%s|r - %s (iLvl: %d, Rating: %d)%s",
        colorCode, applicant.name, roleDisplay, applicant.itemLevel, applicant.rating, extras
    ))
    
    -- Update applicant panel if visible
    self:RefreshApplicantPanel()
    
    -- Show the applicant panel if we have pending applicants
    if self.ApplicantFrame then
        self:ShowApplicantPanel()
    end
end

-- Store listing ID when we create a group
function GF:OnListingCreated(data)
    if data and data.listingId then
        myActiveListingId = data.listingId
        pendingApplicants[data.listingId] = {}
        GF.Print("Your group listing is now active. Listing ID: " .. data.listingId)
    end
end

-- Called when application status changes (applicant's perspective)
function GF:OnApplicationStatusChanged(data)
    -- This is called when YOUR application is accepted/declined
    -- Handled by chat message already in Core.lua
end

-- Called when group composition changes
function GF:OnGroupUpdated(data)
    -- Could refresh group display, update slots, etc.
    GF.Print("Group updated")
end

-- Create the applicant management panel (floating frame for leaders)
function GF:CreateApplicantPanel()
    if self.ApplicantFrame then return end
    
    local frame = CreateFrame("Frame", "DCGroupFinderApplicants", UIParent)
    frame:SetSize(420, 300)
    frame:SetPoint("CENTER", UIParent, "CENTER", 250, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(50)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()
    
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    ApplyLeaderboardsStyle(frame)
    
    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(26)
    titleBar.bg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBar.bg:SetAllPoints()
    titleBar.bg:SetTexture(0.15, 0.12, 0.08, 1)
    
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 12, 0)
    title:SetText("|cffffd700Applicants|r")
    frame.title = title
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Applicant count
    local countText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
    countText:SetText("0 pending")
    frame.countText = countText
    
    -- Column headers
    local headerBar = CreateFrame("Frame", nil, frame)
    headerBar:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -1)
    headerBar:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -1)
    headerBar:SetHeight(20)
    headerBar.bg = headerBar:CreateTexture(nil, "BACKGROUND")
    headerBar.bg:SetAllPoints()
    headerBar.bg:SetTexture(0.1, 0.1, 0.12, 1)
    
    local headers = {
        { text = "NAME", x = 12 },
        { text = "ROLE", x = 120 },
        { text = "ILVL", x = 190 },
        { text = "RATING", x = 240 },
        { text = "ACTIONS", x = 310 },
    }
    for _, h in ipairs(headers) do
        local txt = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("LEFT", h.x, 0)
        txt:SetText("|cff666666" .. h.text .. "|r")
    end
    
    -- Scroll frame for applicants
    local scrollFrame = CreateFrame("ScrollFrame", "DCApplicantScroll", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 40)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(380, 1)
    scrollFrame:SetScrollChild(scrollChild)
    frame.scrollChild = scrollChild
    
    -- Empty state
    local emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyText:SetPoint("CENTER", scrollFrame, "CENTER", 0, 10)
    emptyText:SetText("|cff666666No pending applicants|r")
    frame.emptyText = emptyText
    
    -- Bottom bar with actions
    local bottomBar = CreateFrame("Frame", nil, frame)
    bottomBar:SetPoint("BOTTOMLEFT", 0, 0)
    bottomBar:SetPoint("BOTTOMRIGHT", 0, 0)
    bottomBar:SetHeight(36)
    bottomBar.bg = bottomBar:CreateTexture(nil, "BACKGROUND")
    bottomBar.bg:SetAllPoints()
    bottomBar.bg:SetColorTexture(0.1, 0.1, 0.12, 1)
    
    -- Decline All button
    local declineAllBtn = CreateFrame("Button", nil, bottomBar, "UIPanelButtonTemplate")
    declineAllBtn:SetSize(100, 24)
    declineAllBtn:SetPoint("LEFT", 12, 0)
    declineAllBtn:SetText("Decline All")
    declineAllBtn:GetFontString():SetTextColor(1, 0.4, 0.4)
    declineAllBtn:SetScript("OnClick", function()
        GF:DeclineAllApplicants()
    end)
    
    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, bottomBar, "UIPanelButtonTemplate")
    refreshBtn:SetSize(80, 24)
    refreshBtn:SetPoint("RIGHT", -12, 0)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        GF:RefreshApplicantPanel()
    end)
    
    self.ApplicantFrame = frame
end

-- Populate the applicant panel with current applicants
function GF:RefreshApplicantPanel()
    if not self.ApplicantFrame then
        self:CreateApplicantPanel()
    end
    
    local frame = self.ApplicantFrame
    local scrollChild = frame.scrollChild
    
    -- Clear existing rows
    for _, child in ipairs({ scrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Get applicants for current listing
    local listingId = myActiveListingId
    local applicants = listingId and pendingApplicants[listingId] or {}
    
    -- Update count
    frame.countText:SetText(#applicants .. " pending")
    
    -- Show/hide empty state
    if #applicants == 0 then
        frame.emptyText:Show()
        scrollChild:SetHeight(1)
        return
    end
    frame.emptyText:Hide()
    
    local yOffset = 0
    local rowHeight = 44
    
    for i, applicant in ipairs(applicants) do
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(scrollChild:GetWidth() - 4, rowHeight - 2)
        row:SetPoint("TOPLEFT", 2, -yOffset)
        
        -- Alternating background
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        if i % 2 == 0 then
            row.bg:SetColorTexture(0.08, 0.08, 0.10, 1)
        else
            row.bg:SetColorTexture(0.06, 0.06, 0.08, 1)
        end
        
        -- Friend/Guild highlight
        if applicant.isGuild then
            row.bg:SetColorTexture(0.05, 0.12, 0.05, 1)
        elseif applicant.isFriend then
            row.bg:SetColorTexture(0.05, 0.08, 0.12, 1)
        end
        
        -- Name with class color and markers
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("TOPLEFT", 10, -6)
        local colorCode = CLASS_COLORS[applicant.class:upper()] or "FFFFFF"
        local markerStr = ""
        if applicant.isFriend then markerStr = markerStr .. " |cff00ccff★|r" end
        if applicant.isGuild then markerStr = markerStr .. " |cff44ff44♦|r" end
        nameText:SetText("|cff" .. colorCode .. applicant.name .. "|r" .. markerStr)
        
        -- Class text (smaller, below name)
        local classText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        classText:SetPoint("TOPLEFT", 10, -20)
        local className = applicant.class:sub(1,1):upper() .. applicant.class:sub(2):lower()
        classText:SetText("|cff888888" .. className .. "|r")
        
        -- Role
        local roleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        roleText:SetPoint("LEFT", 120, 0)
        roleText:SetText(ROLE_DISPLAY[applicant.role] or applicant.role)
        
        -- Item Level (color coded)
        local ilvlText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ilvlText:SetPoint("LEFT", 190, 0)
        local ilvl = applicant.itemLevel or 0
        local ilvlColor = "ffffff"
        if ilvl >= 264 then ilvlColor = "a335ee" -- Epic (ICC level)
        elseif ilvl >= 245 then ilvlColor = "0070dd" -- Rare+
        elseif ilvl >= 219 then ilvlColor = "1eff00" -- Uncommon
        else ilvlColor = "888888" end
        ilvlText:SetText("|cff" .. ilvlColor .. ilvl .. "|r")
        
        -- M+ Rating (color coded)
        local ratingText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ratingText:SetPoint("LEFT", 240, 0)
        local rating = applicant.rating or 0
        local ratingColor = "ffffff"
        if rating >= 3000 then ratingColor = "ff8000" -- Orange (very high)
        elseif rating >= 2500 then ratingColor = "a335ee" -- Purple
        elseif rating >= 2000 then ratingColor = "0070dd" -- Blue
        elseif rating >= 1500 then ratingColor = "1eff00" -- Green
        elseif rating >= 1000 then ratingColor = "ffff00" -- Yellow
        else ratingColor = "888888" end
        ratingText:SetText("|cff" .. ratingColor .. rating .. "|r")
        
        -- Accept button
        local acceptBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        acceptBtn:SetSize(50, 20)
        acceptBtn:SetPoint("LEFT", 310, 5)
        acceptBtn:SetText("Invite")
        acceptBtn:GetFontString():SetTextColor(0.4, 1, 0.4)
        acceptBtn.applicantIndex = i
        acceptBtn:SetScript("OnClick", function(self)
            GF:AcceptApplicant(listingId, applicant.guid, applicant.name)
        end)
        
        -- Decline button
        local declineBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        declineBtn:SetSize(50, 20)
        declineBtn:SetPoint("LEFT", 310, -15)
        declineBtn:SetText("Decline")
        declineBtn:GetFontString():SetTextColor(1, 0.4, 0.4)
        declineBtn.applicantIndex = i
        declineBtn:SetScript("OnClick", function(self)
            GF:DeclineApplicant(listingId, applicant.guid, applicant.name, i)
        end)
        
        -- Message tooltip on hover
        if applicant.message and applicant.message ~= "" then
            row:EnableMouse(true)
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Applicant Message:", 1, 0.82, 0)
                GameTooltip:AddLine(applicant.message, 1, 1, 1, true)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Applied: " .. date("%H:%M:%S", applicant.timestamp), 0.6, 0.6, 0.6)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            -- Message indicator
            local msgIcon = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            msgIcon:SetPoint("LEFT", 95, 0)
            msgIcon:SetText("|cff888888✉|r")
        end
        
        yOffset = yOffset + rowHeight
    end
    
    scrollChild:SetHeight(math.max(yOffset, 1))
end

-- Show the applicant panel
function GF:ShowApplicantPanel()
    if not self.ApplicantFrame then
        self:CreateApplicantPanel()
    end
    self:RefreshApplicantPanel()
    self.ApplicantFrame:Show()
end

-- Hide the applicant panel
function GF:HideApplicantPanel()
    if self.ApplicantFrame then
        self.ApplicantFrame:Hide()
    end
end

-- Accept an applicant (invite to group)
function GF:AcceptApplicant(listingId, applicantGuid, applicantName)
    GF.Print("Inviting " .. applicantName .. "...")
    
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder then
        DC.GroupFinder.AcceptApplicant(listingId, applicantGuid)
    end
    
    -- Also send direct invite (backup)
    if applicantName then
        InviteUnit(applicantName)
    end
    
    -- Remove from local list
    if pendingApplicants[listingId] then
        for i, app in ipairs(pendingApplicants[listingId]) do
            if app.guid == applicantGuid or app.name == applicantName then
                table.remove(pendingApplicants[listingId], i)
                break
            end
        end
    end
    
    self:RefreshApplicantPanel()
end

-- Decline an applicant
function GF:DeclineApplicant(listingId, applicantGuid, applicantName, index)
    GF.Print("Declining " .. applicantName .. "...")
    
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder then
        DC.GroupFinder.DeclineApplicant(listingId, applicantGuid)
    end
    
    -- Remove from local list
    if pendingApplicants[listingId] and index then
        table.remove(pendingApplicants[listingId], index)
    elseif pendingApplicants[listingId] then
        for i, app in ipairs(pendingApplicants[listingId]) do
            if app.guid == applicantGuid or app.name == applicantName then
                table.remove(pendingApplicants[listingId], i)
                break
            end
        end
    end
    
    self:RefreshApplicantPanel()
end

-- Decline all applicants
function GF:DeclineAllApplicants()
    local listingId = myActiveListingId
    if not listingId or not pendingApplicants[listingId] then return end
    
    local DC = rawget(_G, "DCAddonProtocol")
    for _, app in ipairs(pendingApplicants[listingId]) do
        GF.Print("Declining " .. app.name .. "...")
        if DC and DC.GroupFinder then
            DC.GroupFinder.DeclineApplicant(listingId, app.guid)
        end
    end
    
    -- Clear local list
    pendingApplicants[listingId] = {}
    self:RefreshApplicantPanel()
end

-- Add mock applicants for testing (demo mode)
function GF:AddMockApplicants()
    if not myActiveListingId then
        myActiveListingId = 999
    end
    pendingApplicants[myActiveListingId] = {
        { guid = "mock1", name = "DemoTank", class = "WARRIOR", role = "tank", itemLevel = 251, rating = 2150, message = "Experienced tank, know all routes", timestamp = time(), isFriend = false, isGuild = false },
        { guid = "mock2", name = "HealerPro", class = "PRIEST", role = "healer", itemLevel = 264, rating = 2800, message = "", timestamp = time() - 60, isFriend = true, isGuild = false },
        { guid = "mock3", name = "MageDPS", class = "MAGE", role = "dps", itemLevel = 245, rating = 1850, message = "Can do big AoE", timestamp = time() - 120, isFriend = false, isGuild = true },
        { guid = "mock4", name = "RogueLFG", class = "ROGUE", role = "dps", itemLevel = 232, rating = 1200, message = "", timestamp = time() - 180, isFriend = false, isGuild = false },
    }
    GF.Print("Added 4 mock applicants for testing")
    self:ShowApplicantPanel()
end

-- Slash command to test applicant panel
SLASH_DCAPPLICANTS1 = "/dcapplicants"
SlashCmdList["DCAPPLICANTS"] = function(msg)
    if msg == "test" then
        GF:AddMockApplicants()
    elseif msg == "hide" then
        GF:HideApplicantPanel()
    else
        GF:ShowApplicantPanel()
    end
end

GF.Print("Mythic+ tab module loaded")
