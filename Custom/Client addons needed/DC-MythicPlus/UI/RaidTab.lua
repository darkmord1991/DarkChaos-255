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

local RAID_LIST = {
    { id = 1, name = "Naxxramas", size = "10/25", bosses = 15 },
    { id = 2, name = "Obsidian Sanctum", size = "10/25", bosses = 1 },
    { id = 3, name = "Eye of Eternity", size = "10/25", bosses = 1 },
    { id = 4, name = "Vault of Archavon", size = "10/25", bosses = 4 },
    { id = 5, name = "Ulduar", size = "10/25", bosses = 14 },
    { id = 6, name = "Trial of the Crusader", size = "10/25", bosses = 5 },
    { id = 7, name = "Onyxia's Lair", size = "10/25", bosses = 1 },
    { id = 8, name = "Icecrown Citadel", size = "10/25", bosses = 12 },
    { id = 9, name = "Ruby Sanctum", size = "10/25", bosses = 1 },
}

local DIFFICULTY_OPTIONS = {
    { id = 1, name = "10 Normal" },
    { id = 2, name = "25 Normal" },
    { id = 3, name = "10 Heroic" },
    { id = 4, name = "25 Heroic" },
}

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
        btn.bg:SetColorTexture(0.15, 0.2, 0.25, 0.8)
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(tabText)
        
        btn.tabIndex = i
        btn:SetScript("OnClick", function(self)
            GF:SelectRaidSubTab(self.tabIndex)
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
    
    self.RaidTabContent = frame
    
    self:CreateRaidBrowsePanel(contentArea)
    self:CreateRaidCreatePanel(contentArea)
    
    self:SelectRaidSubTab(1)
end

function GF:SelectRaidSubTab(index)
    if not self.RaidTabContent then return end
    
    local subTabs = self.RaidTabContent.subTabBtns
    for i, btn in ipairs(subTabs) do
        if i == index then
            btn.bg:SetColorTexture(0.2, 0.4, 0.6, 0.9)
            btn.text:SetTextColor(1, 1, 1)
        else
            btn.bg:SetColorTexture(0.15, 0.2, 0.25, 0.8)
            btn.text:SetTextColor(0.7, 0.7, 0.7)
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
    
    local filterDropdown = CreateFrame("Button", nil, filterFrame)
    filterDropdown:SetSize(180, 24)
    filterDropdown:SetPoint("LEFT", filterLabel, "RIGHT", 10, 0)
    filterDropdown.bg = filterDropdown:CreateTexture(nil, "BACKGROUND")
    filterDropdown.bg:SetAllPoints()
    filterDropdown.bg:SetColorTexture(0.2, 0.2, 0.25, 0.9)
    filterDropdown.text = filterDropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    filterDropdown.text:SetPoint("CENTER")
    filterDropdown.text:SetText("All Raids")
    
    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(80, 22)
    refreshBtn:SetPoint("RIGHT", -5, 0)
    refreshBtn:SetText("Refresh")
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
    
    self.RaidBrowsePanel = panel
    self:PopulateRaidGroups(mockRaidGroups)
end

function GF:PopulateRaidGroups(groups)
    local scrollChild = self.RaidBrowsePanel.scrollChild
    if not scrollChild then return end
    
    -- Clear existing
    for _, child in ipairs({ scrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    
    local yOffset = 0
    local rowHeight = 65
    
    for i, group in ipairs(groups) do
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(scrollChild:GetWidth() - 10, rowHeight - 4)
        row:SetPoint("TOPLEFT", 5, -yOffset)
        
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0.1, 0.12, 0.15, 0.9)
        
        -- Raid name + difficulty
        local raidText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        raidText:SetPoint("TOPLEFT", 10, -8)
        raidText:SetText(string.format("%s |cffaaaaaa(%s)|r", group.raid, group.difficulty))
        
        -- Progress + Leader
        local infoText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        infoText:SetPoint("TOPLEFT", 10, -28)
        infoText:SetText(string.format("Progress: |cff32c4ff%s|r  |  Leader: %s", group.progress, group.leader))
        
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
        
        -- Apply button
        local applyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        applyBtn:SetSize(70, 22)
        applyBtn:SetPoint("RIGHT", -10, 0)
        applyBtn:SetText("Apply")
        applyBtn:SetScript("OnClick", function()
            GF:ApplyToRaid(group.id)
        end)
        
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

-- =====================================================================
-- Create Raid Group Panel
-- =====================================================================

function GF:CreateRaidCreatePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()
    
    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Create a Raid Group")
    
    local y = -50
    
    -- Raid selection
    local raidLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidLabel:SetPoint("TOPLEFT", 20, y)
    raidLabel:SetText("Select Raid:")
    
    local raidBtn = CreateFrame("Button", nil, panel)
    raidBtn:SetSize(200, 24)
    raidBtn:SetPoint("TOPLEFT", 140, y + 3)
    raidBtn.bg = raidBtn:CreateTexture(nil, "BACKGROUND")
    raidBtn.bg:SetAllPoints()
    raidBtn.bg:SetColorTexture(0.2, 0.2, 0.25, 0.9)
    raidBtn.text = raidBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    raidBtn.text:SetPoint("CENTER")
    raidBtn.text:SetText("Choose Raid...")
    panel.raidBtn = raidBtn
    panel.selectedRaid = nil
    y = y - 35
    
    -- Difficulty
    local diffLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    diffLabel:SetPoint("TOPLEFT", 20, y)
    diffLabel:SetText("Difficulty:")
    
    local diffBtn = CreateFrame("Button", nil, panel)
    diffBtn:SetSize(150, 24)
    diffBtn:SetPoint("TOPLEFT", 140, y + 3)
    diffBtn.bg = diffBtn:CreateTexture(nil, "BACKGROUND")
    diffBtn.bg:SetAllPoints()
    diffBtn.bg:SetColorTexture(0.2, 0.2, 0.25, 0.9)
    diffBtn.text = diffBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    diffBtn.text:SetPoint("CENTER")
    diffBtn.text:SetText("25 Normal")
    panel.diffBtn = diffBtn
    panel.selectedDifficulty = "25 Normal"
    y = y - 35
    
    -- Progress
    local progressLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    progressLabel:SetPoint("TOPLEFT", 20, y)
    progressLabel:SetText("Progress:")
    
    local progressEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    progressEdit:SetSize(100, 22)
    progressEdit:SetPoint("TOPLEFT", 140, y + 5)
    progressEdit:SetAutoFocus(false)
    progressEdit:SetMaxLetters(20)
    progressEdit:SetText("Fresh")
    panel.progressEdit = progressEdit
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
    createBtn:SetText("Create Raid Group")
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
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("RAID", 0x12, {
            raid = raid,
            difficulty = difficulty,
            progress = progress,
            note = note
        })
    end
end

GF.Print("Raid tab module loaded")
