-- DC-MythicPlus/UI/MythicTab.lua
-- Mythic+ tab for Group Finder - Browse/Create M+ groups, keystone management

local addonName = "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

local GF = namespace.GroupFinder
if not GF then return end

-- =====================================================================
-- Mythic+ Data
-- =====================================================================

local DUNGEON_LIST = {
    { id = 1, name = "Utgarde Keep", minLevel = 70 },
    { id = 2, name = "The Nexus", minLevel = 70 },
    { id = 3, name = "Azjol-Nerub", minLevel = 70 },
    { id = 4, name = "Ahn'kahet", minLevel = 70 },
    { id = 5, name = "Drak'Tharon Keep", minLevel = 74 },
    { id = 6, name = "Violet Hold", minLevel = 75 },
    { id = 7, name = "Gundrak", minLevel = 76 },
    { id = 8, name = "Halls of Stone", minLevel = 77 },
    { id = 9, name = "Halls of Lightning", minLevel = 80 },
    { id = 10, name = "The Oculus", minLevel = 80 },
    { id = 11, name = "Utgarde Pinnacle", minLevel = 80 },
    { id = 12, name = "Culling of Stratholme", minLevel = 80 },
    { id = 13, name = "Trial of the Champion", minLevel = 80 },
    { id = 14, name = "Forge of Souls", minLevel = 80 },
    { id = 15, name = "Pit of Saron", minLevel = 80 },
    { id = 16, name = "Halls of Reflection", minLevel = 80 },
}

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
        btn.bg:SetColorTexture(0.15, 0.2, 0.25, 0.8)
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(tabText)
        
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
            btn.bg:SetColorTexture(0.2, 0.4, 0.6, 0.9)
            btn.text:SetTextColor(1, 1, 1)
        else
            btn.bg:SetColorTexture(0.15, 0.2, 0.25, 0.8)
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
    
    -- Filters section
    local filterFrame = CreateFrame("Frame", nil, panel)
    filterFrame:SetPoint("TOPLEFT", 5, -5)
    filterFrame:SetPoint("TOPRIGHT", -5, -5)
    filterFrame:SetHeight(30)
    
    local filterLabel = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterLabel:SetPoint("LEFT", 5, 0)
    filterLabel:SetText("Filter by Dungeon:")
    
    -- Dropdown placeholder (simplified)
    local filterDropdown = CreateFrame("Button", nil, filterFrame)
    filterDropdown:SetSize(180, 24)
    filterDropdown:SetPoint("LEFT", filterLabel, "RIGHT", 10, 0)
    filterDropdown.bg = filterDropdown:CreateTexture(nil, "BACKGROUND")
    filterDropdown.bg:SetAllPoints()
    filterDropdown.bg:SetColorTexture(0.2, 0.2, 0.25, 0.9)
    filterDropdown.text = filterDropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    filterDropdown.text:SetPoint("CENTER")
    filterDropdown.text:SetText("All Dungeons")
    
    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(80, 22)
    refreshBtn:SetPoint("RIGHT", -5, 0)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        GF:RefreshMythicGroups()
    end)
    
    -- Group list scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "DCMythicBrowseScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 30)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    panel.scrollChild = scrollChild
    
    -- Populate with mock data
    self.MythicBrowsePanel = panel
    self:PopulateMythicGroups(mockGroups)
end

function GF:PopulateMythicGroups(groups)
    local scrollChild = self.MythicBrowsePanel.scrollChild
    if not scrollChild then return end
    
    -- Clear existing
    for _, child in ipairs({ scrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    
    local yOffset = 0
    local rowHeight = 60
    
    for i, group in ipairs(groups) do
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(scrollChild:GetWidth() - 10, rowHeight - 4)
        row:SetPoint("TOPLEFT", 5, -yOffset)
        
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0.1, 0.12, 0.15, 0.9)
        
        -- Dungeon name + level
        local dungeonText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        dungeonText:SetPoint("TOPLEFT", 10, -8)
        dungeonText:SetText(string.format("|cff32c4ff+%d|r %s", group.level, group.dungeon))
        
        -- Leader
        local leaderText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        leaderText:SetPoint("TOPLEFT", 10, -28)
        leaderText:SetText("Leader: " .. group.leader)
        
        -- Roles needed
        local rolesText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rolesText:SetPoint("TOPRIGHT", -90, -8)
        local rolesStr = ""
        if not group.tank then rolesStr = rolesStr .. ROLE_ICONS.tank .. " " end
        if not group.healer then rolesStr = rolesStr .. ROLE_ICONS.healer .. " " end
        if group.dps < 3 then
            for j = 1, (3 - group.dps) do
                rolesStr = rolesStr .. ROLE_ICONS.dps .. " "
            end
        end
        rolesText:SetText("Need: " .. (rolesStr ~= "" and rolesStr or "Full"))
        
        -- Note
        if group.note and group.note ~= "" then
            local noteText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            noteText:SetPoint("BOTTOMLEFT", 10, 6)
            noteText:SetText("|cff888888" .. group.note .. "|r")
        end
        
        -- Apply button
        local applyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        applyBtn:SetSize(70, 22)
        applyBtn:SetPoint("RIGHT", -10, 0)
        applyBtn:SetText("Apply")
        applyBtn:SetScript("OnClick", function()
            GF:ApplyToGroup(group.id)
        end)
        
        yOffset = yOffset + rowHeight
    end
    
    scrollChild:SetHeight(yOffset)
end

function GF:RefreshMythicGroups()
    GF.Print("Refreshing group list...")
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder then
        DC.GroupFinder.Search({})
    end
end

function GF:ApplyToGroup(groupId)
    GF.Print("Applying to group #" .. groupId .. "...")
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder then
        DC.GroupFinder.Apply(groupId, nil, "")  -- role auto-detected, no message
    end
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
    
    local y = -50
    
    -- Dungeon selection (simplified dropdown placeholder)
    local dungeonLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dungeonLabel:SetPoint("TOPLEFT", 20, y)
    dungeonLabel:SetText("Select Dungeon:")
    
    local dungeonBtn = CreateFrame("Button", nil, panel)
    dungeonBtn:SetSize(200, 24)
    dungeonBtn:SetPoint("TOPLEFT", 140, y + 3)
    dungeonBtn.bg = dungeonBtn:CreateTexture(nil, "BACKGROUND")
    dungeonBtn.bg:SetAllPoints()
    dungeonBtn.bg:SetColorTexture(0.2, 0.2, 0.25, 0.9)
    dungeonBtn.text = dungeonBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dungeonBtn.text:SetPoint("CENTER")
    dungeonBtn.text:SetText("Choose Dungeon...")
    panel.dungeonBtn = dungeonBtn
    panel.selectedDungeon = nil
    y = y - 35
    
    -- Keystone level
    local levelLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    levelLabel:SetPoint("TOPLEFT", 20, y)
    levelLabel:SetText("Keystone Level:")
    
    local levelEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    levelEdit:SetSize(60, 22)
    levelEdit:SetPoint("TOPLEFT", 140, y + 5)
    levelEdit:SetAutoFocus(false)
    levelEdit:SetNumeric(true)
    levelEdit:SetMaxLetters(3)
    levelEdit:SetText("10")
    panel.levelEdit = levelEdit
    y = y - 35
    
    -- Note
    local noteLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noteLabel:SetPoint("TOPLEFT", 20, y)
    noteLabel:SetText("Group Note:")
    
    local noteEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    noteEdit:SetSize(350, 22)
    noteEdit:SetPoint("TOPLEFT", 140, y + 5)
    noteEdit:SetAutoFocus(false)
    noteEdit:SetMaxLetters(100)
    panel.noteEdit = noteEdit
    y = y - 60
    
    -- Create button
    local createBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    createBtn:SetSize(150, 30)
    createBtn:SetPoint("TOP", 0, y)
    createBtn:SetText("Create Group")
    createBtn:SetScript("OnClick", function()
        local dungeon = panel.selectedDungeon or "Unknown"
        local level = tonumber(panel.levelEdit:GetText()) or 10
        local note = panel.noteEdit:GetText() or ""
        GF:CreateMythicGroup(dungeon, level, note)
    end)
    
    self.MythicCreatePanel = panel
end

function GF:CreateMythicGroup(dungeon, level, note)
    GF.Print(string.format("Creating group: +%d %s", level, dungeon))
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder then
        DC.GroupFinder.CreateListing({
            dungeonId = dungeon,  -- Will need to map name to ID
            keyLevel = level,
            note = note,
            roles = { tank = false, healer = false, dps1 = true, dps2 = false, dps3 = false }
        })
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
    
    -- =====================================================
    -- Keystone Display Section
    -- =====================================================
    local keystoneFrame = CreateFrame("Frame", nil, panel)
    keystoneFrame:SetSize(300, 100)
    keystoneFrame:SetPoint("TOP", 0, -40)
    
    keystoneFrame.bg = keystoneFrame:CreateTexture(nil, "BACKGROUND")
    keystoneFrame.bg:SetAllPoints()
    keystoneFrame.bg:SetColorTexture(0.08, 0.1, 0.15, 0.95)
    
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
    panel.keystoneLevel = keystoneLevel
    
    local keystoneDungeon = keystoneFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    keystoneDungeon:SetPoint("TOPLEFT", keystoneLevel, "BOTTOMLEFT", 0, -4)
    keystoneDungeon:SetText("Dungeon: Unknown")
    panel.keystoneDungeon = keystoneDungeon
    
    -- Refresh keystone button
    local refreshBtn = CreateFrame("Button", nil, keystoneFrame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(90, 22)
    refreshBtn:SetPoint("RIGHT", -10, 0)
    refreshBtn:SetText("Refresh")
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
    
    local diffDesc = diffSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    diffDesc:SetPoint("TOP", diffTitle, "BOTTOM", 0, -3)
    diffDesc:SetText("|cff888888Change difficulty before entering a dungeon. Group leader only in groups.|r")
    
    -- Current difficulty display
    local currentDiffLabel = diffSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentDiffLabel:SetPoint("TOPLEFT", 20, -45)
    currentDiffLabel:SetText("Current:")
    
    panel.currentDiffText = diffSection:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.currentDiffText:SetPoint("LEFT", currentDiffLabel, "RIGHT", 10, 0)
    panel.currentDiffText:SetText("|cffffffffUnknown|r")
    
    -- Difficulty buttons
    local btnY = -75
    local btnWidth = 120
    local btnSpacing = 130
    local startX = (450 - (btnWidth * 3 + 20)) / 2
    
    panel.diffButtons = {}
    for i, diff in ipairs(DIFFICULTY_OPTIONS) do
        local btn = CreateFrame("Button", nil, diffSection, "UIPanelButtonTemplate")
        btn:SetSize(btnWidth, 30)
        btn:SetPoint("TOPLEFT", startX + ((i - 1) * btnSpacing), btnY)
        btn:SetText(diff.name)
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
    
    -- Use DC.GroupFinder protocol to request difficulty info
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
end

function GF:UpdateKeystoneDisplay(data)
    if not self.MythicKeystonePanel then return end
    
    local panel = self.MythicKeystonePanel
    if data.dungeon then
        panel.keystoneDungeon:SetText("Dungeon: " .. data.dungeon)
    end
    if data.level then
        panel.keystoneLevel:SetText(string.format("Level: |cff32c4ff+%d|r", data.level))
    end
end

GF.Print("Mythic+ tab module loaded")
