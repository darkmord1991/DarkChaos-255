-- DC-MythicPlus/UI/LiveRunsTab.lua
-- Live Runs (Spectator) tab for Group Finder - Watch ongoing M+ runs

local addonName = "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

local GF = namespace.GroupFinder
if not GF then return end

-- =====================================================================
-- Spectator Data
-- =====================================================================

local SPECTATOR_PRIVACY = {
    PUBLIC = 1,      -- Anyone can request to watch
    FRIENDS = 2,     -- Friends only
    GUILD = 3,       -- Guild members only
    PRIVATE = 4,     -- No spectators allowed
}

-- Sample live runs
local mockLiveRuns = {
    {
        id = 1,
        dungeon = "Halls of Lightning",
        level = 22,
        timer = "12:45",
        timerRemaining = "3:15",
        progress = "68%",
        deaths = 2,
        leader = "SpeedRunner",
        privacy = SPECTATOR_PRIVACY.PUBLIC,
        spectators = 3,
        maxSpectators = 10,
    },
    {
        id = 2,
        dungeon = "The Oculus",
        level = 18,
        timer = "08:30",
        timerRemaining = "11:30",
        progress = "45%",
        deaths = 0,
        leader = "PerfectRun",
        privacy = SPECTATOR_PRIVACY.FRIENDS,
        spectators = 1,
        maxSpectators = 5,
    },
    {
        id = 3,
        dungeon = "Utgarde Pinnacle",
        level = 25,
        timer = "14:00",
        timerRemaining = "1:00",
        progress = "92%",
        deaths = 4,
        leader = "ClutchMaster",
        privacy = SPECTATOR_PRIVACY.PUBLIC,
        spectators = 8,
        maxSpectators = 10,
    },
}

-- =====================================================================
-- Create Live Runs Tab
-- =====================================================================

function GF:CreateLiveRunsTab()
    local parent = self.mainFrame.contentFrame
    
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()
    
    -- Header with description
    local headerFrame = CreateFrame("Frame", nil, frame)
    headerFrame:SetPoint("TOPLEFT", 0, 0)
    headerFrame:SetPoint("TOPRIGHT", 0, 0)
    headerFrame:SetHeight(50)
    
    local title = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("Live Mythic+ Runs")
    title:SetTextColor(1, 0.82, 0) -- Gold
    
    local desc = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    desc:SetText("Watch ongoing Mythic+ runs in real-time. Request to spectate public or friend runs.")
    desc:SetTextColor(0.7, 0.7, 0.7)
    
    -- Filters
    local filterFrame = CreateFrame("Frame", nil, frame)
    filterFrame:SetPoint("TOPLEFT", 5, -50)
    filterFrame:SetPoint("TOPRIGHT", -5, -50)
    filterFrame:SetHeight(30)
    
    local filterLabel = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterLabel:SetPoint("LEFT", 5, 0)
    filterLabel:SetText("Show:")
    filterLabel:SetTextColor(1, 0.82, 0) -- Gold
    
    -- Filter checkboxes
    local showPublic = CreateFrame("CheckButton", nil, filterFrame, "UICheckButtonTemplate")
    showPublic:SetPoint("LEFT", filterLabel, "RIGHT", 10, 0)
    showPublic:SetSize(24, 24)
    showPublic:SetChecked(true)
    local showPublicText = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showPublicText:SetPoint("LEFT", showPublic, "RIGHT", 2, 0)
    showPublicText:SetText("Public")
    showPublicText:SetTextColor(0.9, 0.9, 0.9)
    
    local showFriends = CreateFrame("CheckButton", nil, filterFrame, "UICheckButtonTemplate")
    showFriends:SetPoint("LEFT", showPublicText, "RIGHT", 15, 0)
    showFriends:SetSize(24, 24)
    showFriends:SetChecked(true)
    local showFriendsText = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showFriendsText:SetPoint("LEFT", showFriends, "RIGHT", 2, 0)
    showFriendsText:SetText("Friends")
    showFriendsText:SetTextColor(0.9, 0.9, 0.9)
    
    local showGuild = CreateFrame("CheckButton", nil, filterFrame, "UICheckButtonTemplate")
    showGuild:SetPoint("LEFT", showFriendsText, "RIGHT", 15, 0)
    showGuild:SetSize(24, 24)
    showGuild:SetChecked(true)
    local showGuildText = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showGuildText:SetPoint("LEFT", showGuild, "RIGHT", 2, 0)
    showGuildText:SetText("Guild")
    showGuildText:SetTextColor(0.9, 0.9, 0.9)
    
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
        GF:RefreshLiveRuns()
    end)
    
    -- Run list scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "DCLiveRunsScroll", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -85)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 60)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    frame.scrollChild = scrollChild
    
    -- Join by Code section (above settings)
    local joinFrame = CreateFrame("Frame", nil, frame)
    joinFrame:SetPoint("BOTTOMLEFT", 5, 60)
    joinFrame:SetPoint("BOTTOMRIGHT", -5, 60)
    joinFrame:SetHeight(45)
    
    joinFrame.bg = joinFrame:CreateTexture(nil, "BACKGROUND")
    joinFrame.bg:SetAllPoints()
    joinFrame.bg:SetColorTexture(0.1, 0.1, 0.1, 1)
    
    local joinLabel = joinFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    joinLabel:SetPoint("LEFT", 10, 0)
    joinLabel:SetText("Join by Spectator Code:")
    joinLabel:SetTextColor(1, 0.82, 0) -- Gold
    
    -- Styled code input
    local codeFrame = CreateFrame("Frame", nil, joinFrame)
    codeFrame:SetSize(130, 22)
    codeFrame:SetPoint("LEFT", joinLabel, "RIGHT", 10, 0)
    
    codeFrame.bg = codeFrame:CreateTexture(nil, "BACKGROUND")
    codeFrame.bg:SetAllPoints()
    codeFrame.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    
    codeFrame.border = CreateFrame("Frame", nil, codeFrame)
    codeFrame.border:SetPoint("TOPLEFT", -1, 1)
    codeFrame.border:SetPoint("BOTTOMRIGHT", 1, -1)
    codeFrame.border:SetFrameLevel(codeFrame:GetFrameLevel() - 1)
    local cBorder = codeFrame.border:CreateTexture(nil, "BACKGROUND")
    cBorder:SetAllPoints()
    cBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    local codeEdit = CreateFrame("EditBox", nil, codeFrame)
    codeEdit:SetPoint("TOPLEFT", 5, 0)
    codeEdit:SetPoint("BOTTOMRIGHT", -5, 0)
    codeEdit:SetAutoFocus(false)
    codeEdit:SetMaxLetters(16)
    codeEdit:SetText("")
    codeEdit:SetFontObject("GameFontHighlight")
    frame.codeEdit = codeEdit
    
    -- Placeholder text
    codeEdit:SetScript("OnEditFocusGained", function(self)
        if self:GetText() == "" then
            self.placeholder:Hide()
        end
    end)
    codeEdit:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            self.placeholder:Show()
        end
    end)
    codeEdit.placeholder = codeEdit:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    codeEdit.placeholder:SetPoint("LEFT", 5, 0)
    codeEdit.placeholder:SetText("Enter code...")
    
    local joinBtn = CreateFrame("Button", nil, joinFrame)
    joinBtn:SetSize(80, 22)
    joinBtn:SetPoint("LEFT", codeFrame, "RIGHT", 10, 0)
    
    joinBtn.bg = joinBtn:CreateTexture(nil, "BACKGROUND")
    joinBtn.bg:SetAllPoints()
    joinBtn.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
    
    joinBtn.border = CreateFrame("Frame", nil, joinBtn)
    joinBtn.border:SetPoint("TOPLEFT", -1, 1)
    joinBtn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    joinBtn.border:SetFrameLevel(joinBtn:GetFrameLevel() - 1)
    local jBorder = joinBtn.border:CreateTexture(nil, "BACKGROUND")
    jBorder:SetAllPoints()
    jBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    joinBtn.text = joinBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    joinBtn.text:SetPoint("CENTER")
    joinBtn.text:SetText("Join")
    joinBtn.text:SetTextColor(1, 0.82, 0) -- Gold
    
    joinBtn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.3, 0.3, 0.3, 1) end)
    joinBtn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.2, 0.2, 0.2, 1) end)
    
    joinBtn:SetScript("OnClick", function()
        local code = codeEdit:GetText()
        if code and code ~= "" then
            GF:JoinBySpectatorCode(code)
        else
            GF.Print("Please enter a spectator code!")
        end
    end)
    
    local joinHelp = joinFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    joinHelp:SetPoint("LEFT", joinBtn, "RIGHT", 10, 0)
    joinHelp:SetText("|cff888888Ask your friend for their code|r")
    
    -- My Run Settings section
    local settingsFrame = CreateFrame("Frame", nil, frame)
    settingsFrame:SetPoint("BOTTOMLEFT", 5, 5)
    settingsFrame:SetPoint("BOTTOMRIGHT", -5, 5)
    settingsFrame:SetHeight(50)
    
    settingsFrame.bg = settingsFrame:CreateTexture(nil, "BACKGROUND")
    settingsFrame.bg:SetAllPoints()
    settingsFrame.bg:SetColorTexture(0.08, 0.08, 0.08, 1)
    
    local myRunLabel = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    myRunLabel:SetPoint("LEFT", 10, 10)
    myRunLabel:SetText("Your Run Privacy:")
    myRunLabel:SetTextColor(1, 0.82, 0) -- Gold
    
    -- Privacy dropdown placeholder
    local privacyBtn = CreateFrame("Button", nil, settingsFrame)
    privacyBtn:SetSize(120, 24)
    privacyBtn:SetPoint("LEFT", myRunLabel, "RIGHT", 10, 0)
    
    privacyBtn.bg = privacyBtn:CreateTexture(nil, "BACKGROUND")
    privacyBtn.bg:SetAllPoints()
    privacyBtn.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    
    privacyBtn.border = CreateFrame("Frame", nil, privacyBtn)
    privacyBtn.border:SetPoint("TOPLEFT", -1, 1)
    privacyBtn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    privacyBtn.border:SetFrameLevel(privacyBtn:GetFrameLevel() - 1)
    local pBorder = privacyBtn.border:CreateTexture(nil, "BACKGROUND")
    pBorder:SetAllPoints()
    pBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    privacyBtn.text = privacyBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    privacyBtn.text:SetPoint("CENTER")
    privacyBtn.text:SetText("Public")
    frame.privacyBtn = privacyBtn
    
    local maxSpecLabel = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    maxSpecLabel:SetPoint("LEFT", privacyBtn, "RIGHT", 20, 0)
    maxSpecLabel:SetText("Max Spectators:")
    maxSpecLabel:SetTextColor(1, 0.82, 0) -- Gold
    
    -- Styled max spec input
    local maxSpecFrame = CreateFrame("Frame", nil, settingsFrame)
    maxSpecFrame:SetSize(50, 22)
    maxSpecFrame:SetPoint("LEFT", maxSpecLabel, "RIGHT", 10, 0)
    
    maxSpecFrame.bg = maxSpecFrame:CreateTexture(nil, "BACKGROUND")
    maxSpecFrame.bg:SetAllPoints()
    maxSpecFrame.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
    
    maxSpecFrame.border = CreateFrame("Frame", nil, maxSpecFrame)
    maxSpecFrame.border:SetPoint("TOPLEFT", -1, 1)
    maxSpecFrame.border:SetPoint("BOTTOMRIGHT", 1, -1)
    maxSpecFrame.border:SetFrameLevel(maxSpecFrame:GetFrameLevel() - 1)
    local mBorder = maxSpecFrame.border:CreateTexture(nil, "BACKGROUND")
    mBorder:SetAllPoints()
    mBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    local maxSpecEdit = CreateFrame("EditBox", nil, maxSpecFrame)
    maxSpecEdit:SetPoint("TOPLEFT", 5, 0)
    maxSpecEdit:SetPoint("BOTTOMRIGHT", -5, 0)
    maxSpecEdit:SetAutoFocus(false)
    maxSpecEdit:SetNumeric(true)
    maxSpecEdit:SetMaxLetters(2)
    maxSpecEdit:SetText("10")
    maxSpecEdit:SetFontObject("GameFontHighlight")
    frame.maxSpecEdit = maxSpecEdit
    
    local saveBtn = CreateFrame("Button", nil, settingsFrame)
    saveBtn:SetSize(100, 22)
    saveBtn:SetPoint("RIGHT", -10, 10)
    
    saveBtn.bg = saveBtn:CreateTexture(nil, "BACKGROUND")
    saveBtn.bg:SetAllPoints()
    saveBtn.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
    
    saveBtn.border = CreateFrame("Frame", nil, saveBtn)
    saveBtn.border:SetPoint("TOPLEFT", -1, 1)
    saveBtn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    saveBtn.border:SetFrameLevel(saveBtn:GetFrameLevel() - 1)
    local sBorder = saveBtn.border:CreateTexture(nil, "BACKGROUND")
    sBorder:SetAllPoints()
    sBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    saveBtn.text = saveBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    saveBtn.text:SetPoint("CENTER")
    saveBtn.text:SetText("Save Settings")
    saveBtn.text:SetTextColor(1, 0.82, 0) -- Gold
    
    saveBtn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.3, 0.3, 0.3, 1) end)
    saveBtn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.2, 0.2, 0.2, 1) end)
    
    saveBtn:SetScript("OnClick", function()
        GF:SaveSpectatorSettings()
    end)
    
    self.LiveRunsTabContent = frame
    self:PopulateLiveRuns(mockLiveRuns)
end

function GF:PopulateLiveRuns(runs)
    local scrollChild = self.LiveRunsTabContent.scrollChild
    if not scrollChild then return end
    
    -- Clear existing
    for _, child in ipairs({ scrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    
    local yOffset = 0
    local rowHeight = 80
    
    for i, run in ipairs(runs) do
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(scrollChild:GetWidth() - 10, rowHeight - 4)
        row:SetPoint("TOPLEFT", 5, -yOffset)
        
        -- Background with timer-based color
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        
        -- Color based on timer status (mock logic)
        local timerColor = { 0.1, 0.15, 0.1, 0.9 } -- Green (on time)
        if run.deaths > 3 then
            timerColor = { 0.2, 0.1, 0.1, 0.9 } -- Red (depleted/behind)
        end
        row.bg:SetColorTexture(unpack(timerColor))
        
        -- Dungeon + Level
        local dungeonText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        dungeonText:SetPoint("TOPLEFT", 10, -8)
        dungeonText:SetText(string.format("|cff32c4ff+%d|r %s", run.level, run.dungeon))
        
        -- Timer info
        local timerText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        timerText:SetPoint("TOPLEFT", 10, -28)
        timerText:SetText(string.format("Timer: %s  |  Remaining: |cff%s%s|r",
            run.timer,
            run.timerRemaining:match("^%-") and "ff4444" or "44ff44",
            run.timerRemaining))
        
        -- Progress + Deaths
        local progressText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        progressText:SetPoint("TOPLEFT", 10, -44)
        progressText:SetText(string.format("Progress: |cff32c4ff%s|r  |  Deaths: |cff%s%d|r",
            run.progress,
            run.deaths > 0 and "ffaa44" or "44ff44",
            run.deaths))
        
        -- Leader + Privacy
        local leaderText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        leaderText:SetPoint("BOTTOMLEFT", 10, 6)
        local privacyStr = "Public"
        if run.privacy == SPECTATOR_PRIVACY.FRIENDS then privacyStr = "|cff44aaff(Friends Only)|r" end
        if run.privacy == SPECTATOR_PRIVACY.GUILD then privacyStr = "|cff44ff44(Guild Only)|r" end
        leaderText:SetText(string.format("|cff888888Leader: %s  %s|r", run.leader, privacyStr))
        
        -- Spectator count
        local specText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        specText:SetPoint("TOPRIGHT", -90, -8)
        specText:SetText(string.format("|cffaaaaaa%d/%d|r watchers", run.spectators, run.maxSpectators))
        
        -- Watch button
        local watchBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        watchBtn:SetSize(70, 26)
        watchBtn:SetPoint("RIGHT", -10, 0)
        
        if run.spectators >= run.maxSpectators then
            watchBtn:SetText("Full")
            watchBtn:Disable()
        else
            watchBtn:SetText("Watch")
            watchBtn:SetScript("OnClick", function()
                GF:RequestSpectate(run.id, run.leader)
            end)
        end
        
        yOffset = yOffset + rowHeight
    end
    
    scrollChild:SetHeight(yOffset)
end

function GF:RefreshLiveRuns()
    GF.Print("Refreshing live runs...")
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("MPLUS", 0x20, { action = "list_live_runs" })
    end
end

function GF:RequestSpectate(runId, leader)
    GF.Print(string.format("Requesting to spectate %s's run...", leader))
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("MPLUS", 0x21, { run_id = runId, leader = leader })
    end
end

function GF:SaveSpectatorSettings()
    local maxSpec = tonumber(self.LiveRunsTabContent.maxSpecEdit:GetText()) or 10
    local privacy = 1 -- Default public
    
    GF.Print(string.format("Saving spectator settings: Max=%d, Privacy=%d", maxSpec, privacy))
    
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("MPLUS", 0x22, {
            max_spectators = maxSpec,
            privacy = privacy
        })
    end
    
    -- Save locally
    DCMythicPlusHUDDB = DCMythicPlusHUDDB or {}
    DCMythicPlusHUDDB.spectatorMaxViewers = maxSpec
    DCMythicPlusHUDDB.spectatorPrivacy = privacy
end

-- =====================================================================
-- Spectator HUD (when watching a run)
-- =====================================================================

function GF:CreateSpectatorHUD()
    if self.spectatorHUD then return self.spectatorHUD end
    
    local hud = CreateFrame("Frame", "DCMythicPlusSpectatorHUD", UIParent)
    hud:SetSize(300, 120)
    hud:SetPoint("TOP", 0, -100)
    hud:SetMovable(true)
    hud:EnableMouse(true)
    hud:RegisterForDrag("LeftButton")
    hud:SetScript("OnDragStart", hud.StartMoving)
    hud:SetScript("OnDragStop", hud.StopMovingOrSizing)
    hud:Hide()
    
    hud.bg = hud:CreateTexture(nil, "BACKGROUND")
    hud.bg:SetAllPoints()
    hud.bg:SetColorTexture(0.05, 0.05, 0.1, 0.9)
    
    -- Spectator badge
    local badge = hud:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    badge:SetPoint("TOP", 0, -5)
    badge:SetText("|cffff9900[SPECTATING]|r")
    
    -- Run info
    hud.dungeonText = hud:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hud.dungeonText:SetPoint("TOP", badge, "BOTTOM", 0, -5)
    hud.dungeonText:SetText("Dungeon +0")
    
    hud.timerText = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hud.timerText:SetPoint("TOP", hud.dungeonText, "BOTTOM", 0, -4)
    hud.timerText:SetText("Timer: 00:00")
    
    hud.progressText = hud:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hud.progressText:SetPoint("TOP", hud.timerText, "BOTTOM", 0, -4)
    hud.progressText:SetText("Progress: 0%  |  Deaths: 0")
    
    -- Leave button
    local leaveBtn = CreateFrame("Button", nil, hud, "UIPanelButtonTemplate")
    leaveBtn:SetSize(80, 20)
    leaveBtn:SetPoint("BOTTOM", 0, 8)
    leaveBtn:SetText("Leave")
    leaveBtn:SetScript("OnClick", function()
        GF:LeaveSpectate()
    end)
    
    self.spectatorHUD = hud
    return hud
end

function GF:ShowSpectatorHUD(runData)
    local hud = self:CreateSpectatorHUD()
    
    if runData then
        hud.dungeonText:SetText(string.format("%s |cff32c4ff+%d|r", runData.dungeon or "Unknown", runData.level or 0))
        hud.timerText:SetText("Timer: " .. (runData.timer or "00:00"))
        hud.progressText:SetText(string.format("Progress: %s  |  Deaths: %d", runData.progress or "0%", runData.deaths or 0))
    end
    
    hud:Show()
end

function GF:UpdateSpectatorHUD(runData)
    if not self.spectatorHUD or not self.spectatorHUD:IsShown() then return end
    
    if runData.timer then
        self.spectatorHUD.timerText:SetText("Timer: " .. runData.timer)
    end
    if runData.progress then
        self.spectatorHUD.progressText:SetText(string.format("Progress: %s  |  Deaths: %d", runData.progress, runData.deaths or 0))
    end
end

function GF:LeaveSpectate()
    GF.Print("Leaving spectator mode...")
    
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("MPLUS", 0x23, { action = "leave_spectate" })
    end
    
    if self.spectatorHUD then
        self.spectatorHUD:Hide()
    end
end

-- =====================================================================
-- Join by Spectator Code
-- =====================================================================

function GF:JoinBySpectatorCode(code)
    if not code or code == "" then
        GF.Print("|cffff4444Error:|r Please enter a valid spectator code!")
        return
    end
    
    -- Clean up the code (remove spaces, convert to uppercase)
    code = code:gsub("%s+", ""):upper()
    
    GF.Print("Attempting to join run with code: |cff32c4ff" .. code .. "|r")
    
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("MPLUS", 0x24, { 
            action = "join_by_code",
            code = code
        })
    else
        -- Demo mode - simulate joining
        GF.Print("|cff44ff44Demo mode:|r Would join spectate session with code " .. code)
        
        -- Show a fake spectator HUD for demo
        C_Timer.After(1, function()
            GF:ShowSpectatorHUD({
                dungeon = "Halls of Lightning",
                level = 20,
                timer = "10:30",
                progress = "55%",
                deaths = 1
            })
        end)
    end
    
    -- Clear the input
    if self.LiveRunsTabContent and self.LiveRunsTabContent.codeEdit then
        self.LiveRunsTabContent.codeEdit:SetText("")
        self.LiveRunsTabContent.codeEdit.placeholder:Show()
    end
end

-- Function to get your own spectator code (for sharing with friends)
function GF:GetMySpectatorCode()
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("MPLUS", 0x25, { action = "get_my_code" })
    else
        -- Demo mode - generate a fake code
        local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        local code = ""
        for i = 1, 8 do
            local idx = math.random(1, #chars)
            code = code .. chars:sub(idx, idx)
        end
        GF.Print("Your spectator code: |cff32c4ff" .. code .. "|r (Demo mode)")
        return code
    end
end

GF.Print("Live Runs (Spectator) tab module loaded")
