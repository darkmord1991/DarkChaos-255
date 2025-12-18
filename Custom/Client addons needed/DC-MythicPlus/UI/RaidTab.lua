-- DC-MythicPlus/UI/RaidTab.lua
-- Raid Finder tab for Group Finder - Browse/Create raid groups

local addonName = "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

local GF = namespace.GroupFinder
if not GF then return end

-- =====================================================================
-- Raid Data
-- =====================================================================

-- Raid list - populated from server or fallback to defaults
local RAID_LIST = {}
local raidListLoaded = false
local raidListRequested = false

-- Era constants
local ERA_CLASSIC = 0
local ERA_TBC = 1
local ERA_WOTLK = 2

-- Era names for display
local ERA_NAMES = {
    [ERA_CLASSIC] = "|cffFFD100Classic|r",
    [ERA_TBC] = "|cff1eff00TBC|r",
    [ERA_WOTLK] = "|cff0070ddWotLK|r",
}

-- Default raid data with proper era and difficulty info
-- Difficulty ranges: minDiff to maxDiff
--   Classic: 0 = 40-man (or 20-man for ZG/AQ20)
--   TBC: 0 = 10-man, 1 = 25-man
--   WotLK: 0 = 10N, 1 = 25N, 2 = 10H, 3 = 25H
local DEFAULT_RAIDS = {
    -- Classic Raids
    { id = 101, name = "Molten Core", mapId = 409, era = ERA_CLASSIC, bosses = 10, minDiff = 0, maxDiff = 0 },
    { id = 102, name = "Blackwing Lair", mapId = 469, era = ERA_CLASSIC, bosses = 8, minDiff = 0, maxDiff = 0 },
    { id = 103, name = "Temple of Ahn'Qiraj", mapId = 531, era = ERA_CLASSIC, bosses = 9, minDiff = 0, maxDiff = 0 },
    { id = 104, name = "Ruins of Ahn'Qiraj", mapId = 509, era = ERA_CLASSIC, bosses = 6, minDiff = 0, maxDiff = 0 },
    { id = 105, name = "Zul'Gurub", mapId = 309, era = ERA_CLASSIC, bosses = 10, minDiff = 0, maxDiff = 0 },
    
    -- TBC Raids
    { id = 201, name = "Karazhan", mapId = 532, era = ERA_TBC, bosses = 12, minDiff = 0, maxDiff = 0 },
    { id = 202, name = "Gruul's Lair", mapId = 565, era = ERA_TBC, bosses = 2, minDiff = 1, maxDiff = 1 },
    { id = 203, name = "Magtheridon's Lair", mapId = 544, era = ERA_TBC, bosses = 1, minDiff = 1, maxDiff = 1 },
    { id = 204, name = "Serpentshrine Cavern", mapId = 548, era = ERA_TBC, bosses = 6, minDiff = 1, maxDiff = 1 },
    { id = 205, name = "Tempest Keep", mapId = 550, era = ERA_TBC, bosses = 4, minDiff = 1, maxDiff = 1 },
    { id = 206, name = "Mount Hyjal", mapId = 534, era = ERA_TBC, bosses = 5, minDiff = 1, maxDiff = 1 },
    { id = 207, name = "Black Temple", mapId = 564, era = ERA_TBC, bosses = 9, minDiff = 1, maxDiff = 1 },
    { id = 208, name = "Zul'Aman", mapId = 568, era = ERA_TBC, bosses = 6, minDiff = 0, maxDiff = 0 },
    { id = 209, name = "Sunwell Plateau", mapId = 580, era = ERA_TBC, bosses = 6, minDiff = 1, maxDiff = 1 },
    
    -- WotLK Raids
    { id = 301, name = "Naxxramas", mapId = 533, era = ERA_WOTLK, bosses = 15, minDiff = 0, maxDiff = 1 },
    { id = 302, name = "Obsidian Sanctum", mapId = 615, era = ERA_WOTLK, bosses = 1, minDiff = 0, maxDiff = 1 },
    { id = 303, name = "Eye of Eternity", mapId = 616, era = ERA_WOTLK, bosses = 1, minDiff = 0, maxDiff = 1 },
    { id = 304, name = "Vault of Archavon", mapId = 624, era = ERA_WOTLK, bosses = 4, minDiff = 0, maxDiff = 1 },
    { id = 305, name = "Ulduar", mapId = 603, era = ERA_WOTLK, bosses = 14, minDiff = 0, maxDiff = 1 },
    { id = 306, name = "Trial of the Crusader", mapId = 649, era = ERA_WOTLK, bosses = 5, minDiff = 0, maxDiff = 3 },
    { id = 307, name = "Onyxia's Lair", mapId = 249, era = ERA_WOTLK, bosses = 1, minDiff = 0, maxDiff = 1 },
    { id = 308, name = "Icecrown Citadel", mapId = 631, era = ERA_WOTLK, bosses = 12, minDiff = 0, maxDiff = 3 },
    { id = 309, name = "Ruby Sanctum", mapId = 724, era = ERA_WOTLK, bosses = 1, minDiff = 0, maxDiff = 3 },
}

-- Difficulty options based on era
local DIFFICULTY_BY_ERA = {
    [ERA_CLASSIC] = {
        { id = 0, name = "40 Man" },
    },
    [ERA_TBC] = {
        { id = 0, name = "10 Man" },
        { id = 1, name = "25 Man" },
    },
    [ERA_WOTLK] = {
        { id = 0, name = "10 Normal" },
        { id = 1, name = "25 Normal" },
        { id = 2, name = "10 Heroic" },
        { id = 3, name = "25 Heroic" },
    },
}

-- Current selected era filter
local selectedEra = nil  -- nil = all eras

-- Initialize raid list
local function InitializeRaidList()
    if raidListLoaded then return end
    for _, r in ipairs(DEFAULT_RAIDS) do
        table.insert(RAID_LIST, r)
    end
    raidListLoaded = true
end

-- Request raid list from server
local function RequestRaidList()
    if raidListRequested then return end
    raidListRequested = true
    
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder and DC.GroupFinder.GetRaidList then
        DC.GroupFinder.GetRaidList()
        GF.Print("Requesting raid list from server...")
    else
        InitializeRaidList()
    end
end

-- Update raid list from server data
function GF:UpdateRaidList(raidData)
    if not raidData or type(raidData) ~= "table" then
        InitializeRaidList()
        return
    end
    
    wipe(RAID_LIST)
    for _, r in ipairs(raidData) do
        table.insert(RAID_LIST, {
            id = r.id or 0,
            name = r.name or "Unknown",
            mapId = r.mapId or r.map_id or 0,
            era = r.era or ERA_WOTLK,
            bosses = r.bosses or 0,
            minDiff = r.minDiff or r.min_diff or 0,
            maxDiff = r.maxDiff or r.max_diff or 0,
        })
    end
    
    raidListLoaded = true
    GF.Print("Raid list updated: " .. #RAID_LIST .. " raids from server")
end

-- Get available difficulties for a specific raid
local function GetDifficultiesForRaid(raid)
    if not raid then return {} end
    
    local era = raid.era or ERA_WOTLK
    local eraDiffs = DIFFICULTY_BY_ERA[era] or DIFFICULTY_BY_ERA[ERA_WOTLK]
    local available = {}
    
    for _, diff in ipairs(eraDiffs) do
        if diff.id >= (raid.minDiff or 0) and diff.id <= (raid.maxDiff or 0) then
            table.insert(available, diff)
        end
    end
    
    -- If no difficulties available, return at least the minimum
    if #available == 0 and eraDiffs[1] then
        table.insert(available, eraDiffs[1])
    end
    
    return available
end

-- Filter raids by era
local function GetFilteredRaids()
    if selectedEra == nil then
        return RAID_LIST
    end
    
    local filtered = {}
    for _, r in ipairs(RAID_LIST) do
        if r.era == selectedEra then
            table.insert(filtered, r)
        end
    end
    return filtered
end

-- Initialize
InitializeRaidList()

-- Sample data
local mockRaidGroups = {
    { id = 1, raid = "Icecrown Citadel", difficulty = "25 Heroic", progress = "11/12", leader = "RaidLeader", spots = 3, note = "LFM, guild run need 3 DPS" },
    { id = 2, raid = "Ulduar", difficulty = "10 Normal", progress = "Fresh", leader = "Explorer", spots = 6, note = "Achievement run, know fights" },
    { id = 3, raid = "Trial of the Crusader", difficulty = "25 Normal", progress = "Fresh", leader = "QuickRun", spots = 8, note = "Fast clear, 5.5k GS min" },
}

-- =====================================================================
-- Create Raid Tab
-- =====================================================================

function GF:CreateRaidTab()
    local parent = self.mainFrame.contentFrame
    
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()
    
    -- Sub-tabs: Browse | Create
    local subTabFrame = CreateFrame("Frame", nil, frame)
    subTabFrame:SetPoint("TOPLEFT", 0, 0)
    subTabFrame:SetPoint("TOPRIGHT", 0, 0)
    subTabFrame:SetHeight(26)
    
    local subTabs = { "Browse Raids", "Create Raid Group" }
    local subTabBtns = {}
    local subTabWidth = 140
    
    for i, tabText in ipairs(subTabs) do
        local btn = CreateFrame("Button", nil, subTabFrame)
        btn:SetSize(subTabWidth, 22)
        btn:SetPoint("LEFT", (i - 1) * (subTabWidth + 4) + 10, 0)
        
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
        
        btn.border = CreateFrame("Frame", nil, btn)
        btn.border:SetPoint("BOTTOMLEFT", 0, 0)
        btn.border:SetPoint("BOTTOMRIGHT", 0, 0)
        btn.border:SetHeight(2)
        local borderTex = btn.border:CreateTexture(nil, "BACKGROUND")
        borderTex:SetAllPoints()
        borderTex:SetColorTexture(0.3, 0.3, 0.3, 1)
        btn.borderTex = borderTex
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(tabText)
        btn.text:SetTextColor(0.7, 0.7, 0.7)
        
        btn.tabIndex = i
        btn:SetScript("OnClick", function(self)
            GF:SelectRaidSubTab(self.tabIndex)
        end)
        
        btn:SetScript("OnEnter", function(self)
            if self.tabIndex ~= GF.selectedRaidSubTab then
                self.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
            end
        end)
        
        btn:SetScript("OnLeave", function(self)
            if self.tabIndex ~= GF.selectedRaidSubTab then
                self.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
            end
        end)
        
        subTabBtns[i] = btn
    end
    frame.subTabBtns = subTabBtns
    
    -- Content area
    local contentArea = CreateFrame("Frame", nil, frame)
    contentArea:SetPoint("TOPLEFT", 0, -30)
    contentArea:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.contentArea = contentArea
    
    self.RaidTabContent = frame
    
    self:CreateRaidBrowsePanel(contentArea)
    self:CreateRaidCreatePanel(contentArea)
    
    self:SelectRaidSubTab(1)
end

function GF:SelectRaidSubTab(index)
    if not self.RaidTabContent then return end
    
    GF.selectedRaidSubTab = index
    
    local subTabs = self.RaidTabContent.subTabBtns
    for i, btn in ipairs(subTabs) do
        if i == index then
            btn.bg:SetColorTexture(0.25, 0.25, 0.25, 1)
            btn.text:SetTextColor(1, 0.82, 0) -- Gold
            btn.borderTex:SetColorTexture(1, 0.82, 0, 1) -- Gold underline
        else
            btn.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
            btn.text:SetTextColor(0.7, 0.7, 0.7)
            btn.borderTex:SetColorTexture(0.3, 0.3, 0.3, 1)
        end
    end
    
    if self.RaidBrowsePanel then self.RaidBrowsePanel:SetShown(index == 1) end
    if self.RaidCreatePanel then self.RaidCreatePanel:SetShown(index == 2) end
end

-- =====================================================================
-- Browse Raids Panel
-- =====================================================================

function GF:CreateRaidBrowsePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()
    
    -- Filters section
    local filterFrame = CreateFrame("Frame", nil, panel)
    filterFrame:SetPoint("TOPLEFT", 5, -5)
    filterFrame:SetPoint("TOPRIGHT", -5, -5)
    filterFrame:SetHeight(30)
    
    local filterLabel = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterLabel:SetPoint("LEFT", 5, 0)
    filterLabel:SetText("Filter by Raid:")
    filterLabel:SetTextColor(1, 0.82, 0) -- Gold
    
    local filterDropdown = CreateFrame("Button", nil, filterFrame)
    filterDropdown:SetSize(180, 24)
    filterDropdown:SetPoint("LEFT", filterLabel, "RIGHT", 10, 0)
    
    filterDropdown.bg = filterDropdown:CreateTexture(nil, "BACKGROUND")
    filterDropdown.bg:SetAllPoints()
    filterDropdown.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    
    filterDropdown.border = CreateFrame("Frame", nil, filterDropdown)
    filterDropdown.border:SetPoint("TOPLEFT", -1, 1)
    filterDropdown.border:SetPoint("BOTTOMRIGHT", 1, -1)
    filterDropdown.border:SetFrameLevel(filterDropdown:GetFrameLevel() - 1)
    local fBorder = filterDropdown.border:CreateTexture(nil, "BACKGROUND")
    fBorder:SetAllPoints()
    fBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    filterDropdown.text = filterDropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    filterDropdown.text:SetPoint("CENTER")
    filterDropdown.text:SetText("All Raids")
    
    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, filterFrame)
    refreshBtn:SetSize(80, 22)
    refreshBtn:SetPoint("RIGHT", -5, 0)
    
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
        GF:RefreshRaidGroups()
    end)
    
    -- Group list scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "DCRaidBrowseScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 30)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    panel.scrollChild = scrollChild
    
    -- Bottom action bar (similar to Mythic tab)
    local actionBar = CreateFrame("Frame", nil, panel)
    actionBar:SetPoint("BOTTOMLEFT", 0, 0)
    actionBar:SetPoint("BOTTOMRIGHT", 0, 0)
    actionBar:SetHeight(28)
    actionBar.bg = actionBar:CreateTexture(nil, "BACKGROUND")
    actionBar.bg:SetAllPoints()
    actionBar.bg:SetColorTexture(0.10, 0.10, 0.10, 1)
    
    -- Results count
    local resultsText = actionBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resultsText:SetPoint("LEFT", 12, 0)
    resultsText:SetText("|cff888888Results: " .. #mockRaidGroups .. "|r")
    panel.resultsText = resultsText
    
    -- View Applicants button (only visible when you have a listing)
    local applicantBtn = CreateFrame("Button", nil, actionBar)
    applicantBtn:SetSize(120, 22)
    applicantBtn:SetPoint("RIGHT", -12, 0)
    
    applicantBtn.bg = applicantBtn:CreateTexture(nil, "BACKGROUND")
    applicantBtn.bg:SetAllPoints()
    applicantBtn.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
    
    applicantBtn.border = CreateFrame("Frame", nil, applicantBtn)
    applicantBtn.border:SetPoint("TOPLEFT", -1, 1)
    applicantBtn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    applicantBtn.border:SetFrameLevel(applicantBtn:GetFrameLevel() - 1)
    local aBorder = applicantBtn.border:CreateTexture(nil, "BACKGROUND")
    aBorder:SetAllPoints()
    aBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    applicantBtn.text = applicantBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    applicantBtn.text:SetPoint("CENTER")
    applicantBtn.text:SetText("View Applicants")
    applicantBtn.text:SetTextColor(1, 0.82, 0) -- Gold
    
    applicantBtn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.3, 0.3, 0.3, 1) end)
    applicantBtn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.2, 0.2, 0.2, 1) end)
    
    applicantBtn:SetScript("OnClick", function()
        GF:ShowApplicantPanel()
    end)
    applicantBtn:Hide()  -- Hidden by default
    panel.applicantBtn = applicantBtn
    
    self.RaidBrowsePanel = panel
    self:PopulateRaidGroups(mockRaidGroups)
end

function GF:PopulateRaidGroups(groups)
    local panel = self.RaidBrowsePanel
    if not panel or not panel.scrollChild then return end
    
    local scrollChild = panel.scrollChild
    
    -- Update results count
    if panel.resultsText then
        panel.resultsText:SetText("|cff888888Results: " .. #(groups or {}) .. "|r")
    end
    
    -- Clear existing
    for _, child in ipairs({ scrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    
    local yOffset = 0
    local rowHeight = 65
    local playerName = UnitName("player")
    
    for i, group in ipairs(groups) do
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(scrollChild:GetWidth() - 10, rowHeight - 4)
        row:SetPoint("TOPLEFT", 5, -yOffset)
        
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        
        -- Highlight own/friend/guild groups with different background
        local leaderName = group.leader or "Unknown"
        local isOwn = group.isOwn or leaderName == playerName
        local isFriend = GF:IsPlayerFriend(leaderName)
        local isGuild = GF:IsPlayerInGuild(leaderName)
        
        if isOwn then
            row.bg:SetColorTexture(0.1, 0.2, 0.1, 0.95)  -- Green tint for own
        elseif isFriend then
            row.bg:SetColorTexture(0.1, 0.15, 0.2, 0.95)  -- Blue tint for friend
        elseif isGuild then
            row.bg:SetColorTexture(0.12, 0.18, 0.12, 0.95)  -- Light green for guild
        else
            row.bg:SetColorTexture(0.1, 0.12, 0.15, 0.9)
        end
        
        -- Raid name + difficulty
        local raidText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        raidText:SetPoint("TOPLEFT", 10, -8)
        raidText:SetText(string.format("%s |cffaaaaaa(%s)|r", group.raid, group.difficulty))
        
        -- Progress + Leader with markers
        local markerText = ""
        local leaderColor = "ffffff"
        if isOwn then
            markerText = " |cff00ff00[Your Group]|r"
            leaderColor = "00ff00"
        elseif isFriend then
            markerText = " |cff00ccff[Friend]|r"
            leaderColor = "00ccff"
        elseif isGuild then
            markerText = " |cff44ff44[Guild]|r"
            leaderColor = "44ff44"
        end
        
        local infoText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        infoText:SetPoint("TOPLEFT", 10, -28)
        infoText:SetText(string.format("Progress: |cff32c4ff%s|r  |  Leader: |cff%s%s|r%s", 
            group.progress, leaderColor, leaderName, markerText))
        
        -- Spots available
        local spotsText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        spotsText:SetPoint("TOPRIGHT", -90, -8)
        spotsText:SetText(string.format("|cff00ff00%d spots|r", group.spots))
        
        -- Note
        if group.note and group.note ~= "" then
            local noteText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            noteText:SetPoint("BOTTOMLEFT", 10, 6)
            noteText:SetText("|cff888888" .. group.note .. "|r")
        end
        
        -- Action button - different for own groups vs others
        local actionBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        actionBtn:SetSize(70, 22)
        actionBtn:SetPoint("RIGHT", -10, 0)
        
        if isOwn then
            -- Own group - show Cancel button
            actionBtn:SetText("Cancel")
            actionBtn:GetFontString():SetTextColor(1, 0.3, 0.3)
            actionBtn:SetScript("OnClick", function()
                GF:CancelRaidGroup(group.id)
            end)
            
            -- Add special overlay for own groups
            local ownOverlay = row:CreateTexture(nil, "OVERLAY")
            ownOverlay:SetAllPoints()
            ownOverlay:SetColorTexture(0, 1, 0, 0.05)
        else
            -- Other groups - show Apply button
            actionBtn:SetText("Apply")
            actionBtn:SetScript("OnClick", function()
                GF:ApplyToRaid(group.id)
            end)
        end
        
        yOffset = yOffset + rowHeight
    end
    
    scrollChild:SetHeight(yOffset)
end

function GF:RefreshRaidGroups()
    GF.Print("Refreshing raid list...")
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("RAID", 0x10, { action = "list_raids" })
    end
end

function GF:ApplyToRaid(raidId)
    GF.Print("Applying to raid #" .. raidId .. "...")
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("RAID", 0x11, { raid_id = raidId })
    end
end

function GF:CancelRaidGroup(raidId)
    GF.Print("Cancelling raid group #" .. raidId .. "...")
    
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("RAID", 0x13, { raid_id = raidId, action = "cancel" })
    end
    
    -- Remove from local mock list
    for i, group in ipairs(mockRaidGroups) do
        if group.id == raidId then
            table.remove(mockRaidGroups, i)
            break
        end
    end
    
    -- Refresh the list
    C_Timer.After(0.3, function()
        GF:PopulateRaidGroups(mockRaidGroups)
    end)
end

-- =====================================================================
-- Create Raid Group Panel
-- =====================================================================

-- Dropdown frames (module-level)
local raidDropdownFrame = nil
local difficultyDropdownFrame = nil

function GF:CreateRaidCreatePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()
    
    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Create a Raid Group")
    title:SetTextColor(1, 0.82, 0) -- Gold
    
    local y = -50
    
    -- Raid selection
    local raidLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidLabel:SetPoint("TOPLEFT", 20, y)
    raidLabel:SetText("Select Raid:")
    raidLabel:SetTextColor(1, 0.82, 0) -- Gold
    
    local raidBtn = CreateFrame("Button", nil, panel)
    raidBtn:SetSize(250, 28)
    raidBtn:SetPoint("TOPLEFT", 140, y + 3)
    
    raidBtn.bg = raidBtn:CreateTexture(nil, "BACKGROUND")
    raidBtn.bg:SetAllPoints()
    raidBtn.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    
    raidBtn.border = CreateFrame("Frame", nil, raidBtn)
    raidBtn.border:SetPoint("TOPLEFT", -1, 1)
    raidBtn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    raidBtn.border:SetFrameLevel(raidBtn:GetFrameLevel() - 1)
    local rBorder = raidBtn.border:CreateTexture(nil, "BACKGROUND")
    rBorder:SetAllPoints()
    rBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    raidBtn.text = raidBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    raidBtn.text:SetPoint("LEFT", 10, 0)
    raidBtn.text:SetText("Choose Raid...")
    
    -- Arrow indicator
    local raidArrow = raidBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    raidArrow:SetPoint("RIGHT", -10, 0)
    raidArrow:SetText("▼")
    raidArrow:SetTextColor(1, 0.82, 0) -- Gold
    
    raidBtn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.25, 0.25, 0.25, 1) end)
    raidBtn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.15, 0.15, 0.15, 1) end)
    raidBtn:SetScript("OnClick", function(self)
        GF:ShowRaidDropdown(self, panel)
    end)
    panel.raidBtn = raidBtn
    panel.selectedRaid = nil
    panel.selectedRaidId = nil
    y = y - 40
    
    -- Difficulty
    local diffLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    diffLabel:SetPoint("TOPLEFT", 20, y)
    diffLabel:SetText("Difficulty:")
    diffLabel:SetTextColor(1, 0.82, 0) -- Gold
    
    local diffBtn = CreateFrame("Button", nil, panel)
    diffBtn:SetSize(160, 28)
    diffBtn:SetPoint("TOPLEFT", 140, y + 3)
    
    diffBtn.bg = diffBtn:CreateTexture(nil, "BACKGROUND")
    diffBtn.bg:SetAllPoints()
    diffBtn.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    
    diffBtn.border = CreateFrame("Frame", nil, diffBtn)
    diffBtn.border:SetPoint("TOPLEFT", -1, 1)
    diffBtn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    diffBtn.border:SetFrameLevel(diffBtn:GetFrameLevel() - 1)
    local dBorder = diffBtn.border:CreateTexture(nil, "BACKGROUND")
    dBorder:SetAllPoints()
    dBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    diffBtn.text = diffBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    diffBtn.text:SetPoint("LEFT", 10, 0)
    diffBtn.text:SetText("25 Normal")
    
    -- Arrow indicator
    local diffArrow = diffBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    diffArrow:SetPoint("RIGHT", -10, 0)
    diffArrow:SetText("▼")
    diffArrow:SetTextColor(1, 0.82, 0) -- Gold
    
    diffBtn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.25, 0.25, 0.25, 1) end)
    diffBtn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.15, 0.15, 0.15, 1) end)
    diffBtn:SetScript("OnClick", function(self)
        GF:ShowDifficultyDropdown(self, panel)
    end)
    panel.diffBtn = diffBtn
    panel.selectedDifficulty = "25 Normal"
    panel.selectedDifficultyId = 2
    y = y - 40
    
    -- Progress
    local progressLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    progressLabel:SetPoint("TOPLEFT", 20, y)
    progressLabel:SetText("Progress:")
    progressLabel:SetTextColor(1, 0.82, 0) -- Gold
    
    -- Styled progress input
    local progressFrame = CreateFrame("Frame", nil, panel)
    progressFrame:SetSize(130, 28)
    progressFrame:SetPoint("TOPLEFT", 140, y + 3)
    
    progressFrame.bg = progressFrame:CreateTexture(nil, "BACKGROUND")
    progressFrame.bg:SetAllPoints()
    progressFrame.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    
    progressFrame.border = CreateFrame("Frame", nil, progressFrame)
    progressFrame.border:SetPoint("TOPLEFT", -1, 1)
    progressFrame.border:SetPoint("BOTTOMRIGHT", 1, -1)
    progressFrame.border:SetFrameLevel(progressFrame:GetFrameLevel() - 1)
    local pBorder = progressFrame.border:CreateTexture(nil, "BACKGROUND")
    pBorder:SetAllPoints()
    pBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    local progressEdit = CreateFrame("EditBox", nil, progressFrame)
    progressEdit:SetPoint("TOPLEFT", 8, -6)
    progressEdit:SetPoint("BOTTOMRIGHT", -8, 6)
    progressEdit:SetFontObject("GameFontHighlight")
    progressEdit:SetAutoFocus(false)
    progressEdit:SetMaxLetters(20)
    progressEdit:SetText("Fresh")
    progressEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    progressEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    panel.progressEdit = progressEdit
    y = y - 40
    
    -- Note
    local noteLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noteLabel:SetPoint("TOPLEFT", 20, y)
    noteLabel:SetText("Group Note:")
    noteLabel:SetTextColor(1, 0.82, 0) -- Gold
    
    -- Styled note input
    local noteFrame = CreateFrame("Frame", nil, panel)
    noteFrame:SetSize(350, 28)
    noteFrame:SetPoint("TOPLEFT", 140, y + 3)
    
    noteFrame.bg = noteFrame:CreateTexture(nil, "BACKGROUND")
    noteFrame.bg:SetAllPoints()
    noteFrame.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    
    noteFrame.border = CreateFrame("Frame", nil, noteFrame)
    noteFrame.border:SetPoint("TOPLEFT", -1, 1)
    noteFrame.border:SetPoint("BOTTOMRIGHT", 1, -1)
    noteFrame.border:SetFrameLevel(noteFrame:GetFrameLevel() - 1)
    local nBorder = noteFrame.border:CreateTexture(nil, "BACKGROUND")
    nBorder:SetAllPoints()
    nBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    local noteEdit = CreateFrame("EditBox", nil, noteFrame)
    noteEdit:SetPoint("TOPLEFT", 8, -6)
    noteEdit:SetPoint("BOTTOMRIGHT", -8, 6)
    noteEdit:SetFontObject("GameFontHighlight")
    noteEdit:SetAutoFocus(false)
    noteEdit:SetMaxLetters(100)
    noteEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    noteEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    panel.noteEdit = noteEdit
    y = y - 60
    
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
    local cBorder = createBtn.border:CreateTexture(nil, "BACKGROUND")
    cBorder:SetAllPoints()
    cBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    createBtn.text = createBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    createBtn.text:SetPoint("CENTER")
    createBtn.text:SetText("Create Raid Group")
    createBtn.text:SetTextColor(1, 0.82, 0) -- Gold
    
    createBtn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.3, 0.3, 0.3, 1) end)
    createBtn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.2, 0.2, 0.2, 1) end)
    
    createBtn:SetScript("OnClick", function()
        local raid = panel.selectedRaid or "Unknown"
        local difficulty = panel.selectedDifficulty or "25 Normal"
        local progress = panel.progressEdit:GetText() or "Fresh"
        local note = panel.noteEdit:GetText() or ""
        GF:CreateRaidGroup(raid, difficulty, progress, note)
    end)
    
    self.RaidCreatePanel = panel
end

function GF:CreateRaidGroup(raid, difficulty, progress, note)
    GF.Print(string.format("Creating raid group: %s (%s) - %s", raid, difficulty, progress))
    
    local playerName = UnitName("player") or "You"
    
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("RAID", 0x12, {
            raid = raid,
            difficulty = difficulty,
            progress = progress,
            note = note
        })
    end
    
    -- Add to local mock list for immediate visibility
    local newGroup = {
        id = #mockRaidGroups + 100,
        raid = raid,
        difficulty = difficulty,
        progress = progress,
        leader = playerName,
        spots = 20,
        note = note,
        isOwn = true
    }
    table.insert(mockRaidGroups, 1, newGroup)
    
    -- Show the View Applicants button
    if self.RaidBrowsePanel and self.RaidBrowsePanel.applicantBtn then
        self.RaidBrowsePanel.applicantBtn:Show()
    end
    
    -- Switch to browse tab after short delay
    C_Timer.After(0.5, function()
        GF:SelectRaidSubTab(1)
        GF:PopulateRaidGroups(mockRaidGroups)
    end)
end

-- =====================================================================
-- Raid Selection Dropdown
-- =====================================================================

local raidButtons = {}  -- Reusable button pool

function GF:ShowRaidDropdown(anchorBtn, panel)
    local mainFrame = self.mainFrame
    local DROPDOWN_WIDTH = 260
    local CONTENT_WIDTH = 230
    local ITEM_HEIGHT = 28
    local HEADER_HEIGHT = 22
    
    if not raidDropdownFrame then
        raidDropdownFrame = CreateFrame("Frame", "DCRaidDropdownMenu", mainFrame or UIParent)
        raidDropdownFrame:SetFrameStrata("DIALOG")
        raidDropdownFrame:SetFrameLevel(100)
        raidDropdownFrame:SetSize(DROPDOWN_WIDTH, 350)
        
        raidDropdownFrame.bg = raidDropdownFrame:CreateTexture(nil, "BACKGROUND")
        raidDropdownFrame.bg:SetAllPoints()
        raidDropdownFrame.bg:SetColorTexture(0.1, 0.1, 0.12, 0.98)
        
        -- Border
        local border = CreateFrame("Frame", nil, raidDropdownFrame)
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        local borderTex = border:CreateTexture(nil, "BACKGROUND")
        borderTex:SetAllPoints()
        borderTex:SetColorTexture(0.4, 0.4, 0.45, 1)
        border:SetFrameLevel(raidDropdownFrame:GetFrameLevel() - 1)
        
        -- Close button
        local closeBtn = CreateFrame("Button", nil, raidDropdownFrame)
        closeBtn:SetSize(18, 18)
        closeBtn:SetPoint("TOPRIGHT", -2, -2)
        closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
        closeBtn:SetScript("OnClick", function() raidDropdownFrame:Hide() end)
        
        -- Scroll frame
        local scrollFrame = CreateFrame("ScrollFrame", "DCRaidDropdownScroll", raidDropdownFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 4, -24)
        scrollFrame:SetPoint("BOTTOMRIGHT", -26, 4)
        raidDropdownFrame.scrollFrame = scrollFrame
        
        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetSize(CONTENT_WIDTH, 1)
        scrollFrame:SetScrollChild(scrollChild)
        raidDropdownFrame.scrollChild = scrollChild
        
        -- Auto-close when main frame hides
        if mainFrame then
            mainFrame:HookScript("OnHide", function()
                raidDropdownFrame:Hide()
            end)
        end
    end
    
    -- Create click-catcher for auto-close
    if not raidDropdownFrame.clickCatcher then
        raidDropdownFrame.clickCatcher = CreateFrame("Button", nil, raidDropdownFrame:GetParent())
        raidDropdownFrame.clickCatcher:SetAllPoints(raidDropdownFrame:GetParent())
        raidDropdownFrame.clickCatcher:SetFrameLevel(raidDropdownFrame:GetFrameLevel() - 1)
        raidDropdownFrame.clickCatcher:SetScript("OnClick", function()
            raidDropdownFrame:Hide()
        end)
        raidDropdownFrame.clickCatcher:Hide()
    end
    
    raidDropdownFrame:SetScript("OnShow", function(self)
        if self.clickCatcher then self.clickCatcher:Show() end
    end)
    raidDropdownFrame:SetScript("OnHide", function(self)
        if self.clickCatcher then self.clickCatcher:Hide() end
    end)
    
    raidDropdownFrame:ClearAllPoints()
    raidDropdownFrame:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
    
    -- Hide all existing buttons
    for _, btn in ipairs(raidButtons) do
        btn:Hide()
    end
    
    local scrollChild = raidDropdownFrame.scrollChild
    local yOffset = 0
    local btnIndex = 1
    
    -- Get filtered raids
    local filteredRaids = GetFilteredRaids()
    
    -- Group by era for display
    local currentEra = nil
    
    for _, raid in ipairs(filteredRaids) do
        -- Add era header if era changed
        if currentEra ~= raid.era then
            currentEra = raid.era
            
            -- Get or create header
            local header = raidButtons[btnIndex]
            if not header or not header.isHeader then
                header = CreateFrame("Frame", nil, scrollChild)
                header:SetSize(CONTENT_WIDTH, HEADER_HEIGHT)
                header.isHeader = true
                
                header.bg = header:CreateTexture(nil, "BACKGROUND")
                header.bg:SetAllPoints()
                header.bg:SetColorTexture(0.08, 0.08, 0.1, 1)
                
                header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                header.text:SetPoint("LEFT", 8, 0)
                
                raidButtons[btnIndex] = header
            end
            
            header:SetParent(scrollChild)
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", 0, -yOffset)
            header.text:SetText(ERA_NAMES[raid.era] or "Unknown Era")
            header:Show()
            
            btnIndex = btnIndex + 1
            yOffset = yOffset + HEADER_HEIGHT
        end
        
        -- Get or create raid button
        local btn = raidButtons[btnIndex]
        if not btn or btn.isHeader then
            btn = CreateFrame("Button", nil, scrollChild)
            btn:SetSize(CONTENT_WIDTH, ITEM_HEIGHT)
            
            btn.bg = btn:CreateTexture(nil, "BACKGROUND")
            btn.bg:SetAllPoints()
            btn.bg:SetColorTexture(0.15, 0.15, 0.18, 1)
            
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            btn.text:SetPoint("LEFT", 14, 0)
            
            btn.bossText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btn.bossText:SetPoint("RIGHT", -10, 0)
            
            btn:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(0.25, 0.4, 0.6, 1)
            end)
            btn:SetScript("OnLeave", function(self)
                self.bg:SetColorTexture(0.15, 0.15, 0.18, 1)
            end)
            
            raidButtons[btnIndex] = btn
        end
        
        btn:SetParent(scrollChild)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", 0, -yOffset)
        btn.text:SetText(raid.name)
        btn.bossText:SetText("|cff888888" .. raid.bosses .. " bosses|r")
        btn.raidData = raid
        
        btn:SetScript("OnClick", function(self)
            local r = self.raidData
            panel.selectedRaid = r.name
            panel.selectedRaidId = r.id
            panel.selectedRaidData = r
            panel.raidBtn.text:SetText(r.name)
            
            -- Update difficulty dropdown to match this raid's era
            local availableDiffs = GetDifficultiesForRaid(r)
            if availableDiffs[1] then
                panel.selectedDifficulty = availableDiffs[1].name
                panel.selectedDifficultyId = availableDiffs[1].id
                panel.diffBtn.text:SetText(availableDiffs[1].name)
            end
            
            raidDropdownFrame:Hide()
        end)
        
        btn:Show()
        btnIndex = btnIndex + 1
        yOffset = yOffset + ITEM_HEIGHT
    end
    
    -- Set scroll child height and show dropdown
    local totalHeight = math.max(yOffset, 1)
    scrollChild:SetHeight(totalHeight)
    raidDropdownFrame:SetHeight(math.min(totalHeight + 32, 400))
    raidDropdownFrame:Show()
end

-- =====================================================================
-- Difficulty Selection Dropdown
-- =====================================================================

local difficultyButtons = {}  -- Reusable button pool

function GF:ShowDifficultyDropdown(anchorBtn, panel)
    local mainFrame = self.mainFrame
    local DROPDOWN_WIDTH = 160
    local CONTENT_WIDTH = 150
    local ITEM_HEIGHT = 28
    
    if not difficultyDropdownFrame then
        difficultyDropdownFrame = CreateFrame("Frame", "DCDifficultyDropdownMenu", mainFrame or UIParent)
        difficultyDropdownFrame:SetFrameStrata("DIALOG")
        difficultyDropdownFrame:SetFrameLevel(100)
        difficultyDropdownFrame:SetSize(DROPDOWN_WIDTH, 150)
        
        difficultyDropdownFrame.bg = difficultyDropdownFrame:CreateTexture(nil, "BACKGROUND")
        difficultyDropdownFrame.bg:SetAllPoints()
        difficultyDropdownFrame.bg:SetColorTexture(0.1, 0.1, 0.12, 0.98)
        
        -- Border
        local border = CreateFrame("Frame", nil, difficultyDropdownFrame)
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        local borderTex = border:CreateTexture(nil, "BACKGROUND")
        borderTex:SetAllPoints()
        borderTex:SetColorTexture(0.4, 0.4, 0.45, 1)
        border:SetFrameLevel(difficultyDropdownFrame:GetFrameLevel() - 1)
        
        -- Close button
        local closeBtn = CreateFrame("Button", nil, difficultyDropdownFrame)
        closeBtn:SetSize(18, 18)
        closeBtn:SetPoint("TOPRIGHT", -2, -2)
        closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
        closeBtn:SetScript("OnClick", function() difficultyDropdownFrame:Hide() end)
        
        -- Auto-close when main frame hides
        if mainFrame then
            mainFrame:HookScript("OnHide", function()
                difficultyDropdownFrame:Hide()
            end)
        end
    end
    
    -- Create click-catcher for auto-close
    if not difficultyDropdownFrame.clickCatcher then
        difficultyDropdownFrame.clickCatcher = CreateFrame("Button", nil, difficultyDropdownFrame:GetParent())
        difficultyDropdownFrame.clickCatcher:SetAllPoints(difficultyDropdownFrame:GetParent())
        difficultyDropdownFrame.clickCatcher:SetFrameLevel(difficultyDropdownFrame:GetFrameLevel() - 1)
        difficultyDropdownFrame.clickCatcher:SetScript("OnClick", function()
            difficultyDropdownFrame:Hide()
        end)
        difficultyDropdownFrame.clickCatcher:Hide()
    end
    
    difficultyDropdownFrame:SetScript("OnShow", function(self)
        if self.clickCatcher then self.clickCatcher:Show() end
    end)
    difficultyDropdownFrame:SetScript("OnHide", function(self)
        if self.clickCatcher then self.clickCatcher:Hide() end
    end)
    
    difficultyDropdownFrame:ClearAllPoints()
    difficultyDropdownFrame:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
    
    -- Hide all existing buttons
    for _, btn in ipairs(difficultyButtons) do
        btn:Hide()
    end
    
    -- Get available difficulties based on selected raid
    local availableDiffs
    if panel.selectedRaidData then
        availableDiffs = GetDifficultiesForRaid(panel.selectedRaidData)
    else
        -- Default to WotLK difficulties if no raid selected
        availableDiffs = DIFFICULTY_BY_ERA[ERA_WOTLK]
    end
    
    local yOffset = 24
    
    for i, diff in ipairs(availableDiffs) do
        local btn = difficultyButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, difficultyDropdownFrame)
            btn:SetSize(CONTENT_WIDTH, ITEM_HEIGHT)
            
            btn.bg = btn:CreateTexture(nil, "BACKGROUND")
            btn.bg:SetAllPoints()
            btn.bg:SetColorTexture(0.15, 0.15, 0.18, 1)
            
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            btn.text:SetPoint("LEFT", 10, 0)
            btn.text:SetPoint("RIGHT", -10, 0)
            btn.text:SetJustifyH("LEFT")
            
            btn:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(0.25, 0.4, 0.6, 1)
            end)
            btn:SetScript("OnLeave", function(self)
                self.bg:SetColorTexture(0.15, 0.15, 0.18, 1)
            end)
            
            difficultyButtons[i] = btn
        end
        
        btn:SetParent(difficultyDropdownFrame)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", 4, -yOffset)
        btn.text:SetText(diff.name)
        btn.diffData = diff
        
        -- Color heroic/25-man differently
        if diff.id >= 2 then
            btn.text:SetTextColor(1, 0.5, 0)  -- Orange for heroic
        elseif diff.id == 1 then
            btn.text:SetTextColor(0.3, 0.7, 1)  -- Blue for 25-man
        else
            btn.text:SetTextColor(1, 1, 1)  -- White for normal
        end
        
        btn:SetScript("OnClick", function(self)
            panel.selectedDifficulty = self.diffData.name
            panel.selectedDifficultyId = self.diffData.id
            panel.diffBtn.text:SetText(self.diffData.name)
            difficultyDropdownFrame:Hide()
        end)
        
        btn:Show()
        yOffset = yOffset + ITEM_HEIGHT
    end
    
    difficultyDropdownFrame:SetHeight(yOffset + 8)
    difficultyDropdownFrame:Show()
end

GF.Print("Raid tab module loaded")
