-- HLBG_UI_Scoreboard_Modern.lua - Modern scoreboard implementation for Hinterland Battleground

local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Initialize scoreboard settings
HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
if HinterlandAffixHUDDB.modernScoreboard == nil then HinterlandAffixHUDDB.modernScoreboard = true end
if HinterlandAffixHUDDB.compactScoreboard == nil then HinterlandAffixHUDDB.compactScoreboard = false end
if HinterlandAffixHUDDB.useClassColors == nil then HinterlandAffixHUDDB.useClassColors = true end
if HinterlandAffixHUDDB.autoSortScoreboard == nil then HinterlandAffixHUDDB.autoSortScoreboard = true end

-- Class color table
local CLASS_COLORS = {
    ["WARRIOR"] = {0.78, 0.61, 0.43},
    ["PALADIN"] = {0.96, 0.55, 0.73},
    ["HUNTER"] = {0.67, 0.83, 0.45},
    ["ROGUE"] = {1.0, 0.96, 0.41},
    ["PRIEST"] = {1.0, 1.0, 1.0},
    ["DEATHKNIGHT"] = {0.77, 0.12, 0.23},
    ["SHAMAN"] = {0.0, 0.44, 0.87},
    ["MAGE"] = {0.25, 0.78, 0.92},
    ["WARLOCK"] = {0.53, 0.53, 0.93},
    ["DRUID"] = {1.0, 0.49, 0.04},
}

-- Modern Live scoreboard implementation
function HLBG.ModernLive(rows)
    if not HinterlandAffixHUDDB.modernScoreboard then
        -- Fall back to original implementation
        if HLBG.OriginalLive then
            return HLBG.OriginalLive(rows)
        end
        return
    end
    
    if not HLBG._ensureUI('Live') then return end
    
    rows = rows or {}
    
    -- Store last rows for refresh
    HLBG.UI.Live.lastRows = rows
    HLBG.UI.Live.lastUpdate = time()
    
    -- Create modern scoreboard UI if not exists
    if not HLBG.UI.Live.modernInitialized then
        HLBG.CreateModernScoreboardUI()
    end
    
    -- Update team summary
    HLBG.UpdateTeamSummary()
    
    -- Process and display player data
    HLBG.ProcessPlayerData(rows)
    
    -- Visual feedback for updates
    HLBG.FlashScoreboardUpdate()
end

-- Create modern scoreboard UI
function HLBG.CreateModernScoreboardUI()
    local live = HLBG.UI.Live
    
    -- Clear existing content
    for i = 1, #(live.rows or {}) do
        if live.rows[i] and live.rows[i].Hide then
            live.rows[i]:Hide()
        end
    end
    
    -- Create header section
    if not live.ModernHeader then
        live.ModernHeader = CreateFrame("Frame", nil, live)
        live.ModernHeader:SetPoint("TOPLEFT", live, "TOPLEFT", 10, -10)
        live.ModernHeader:SetSize(480, 60)
        
        -- Header background
        live.ModernHeader:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        live.ModernHeader:SetBackdropColor(0.1, 0.1, 0.2, 0.8)
        live.ModernHeader:SetBackdropBorderColor(0.3, 0.3, 0.5, 1)
        
        -- Battle status text
        live.BattleStatus = live.ModernHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        live.BattleStatus:SetPoint("TOP", live.ModernHeader, "TOP", 0, -8)
        live.BattleStatus:SetText("Hinterland Battleground - Live")
        live.BattleStatus:SetTextColor(1, 1, 0, 1)
        
        -- Team scores section
        live.TeamScores = live.ModernHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        live.TeamScores:SetPoint("TOP", live.BattleStatus, "BOTTOM", 0, -5)
        live.TeamScores:SetText("Alliance: 0  |  Horde: 0")
        
        -- Battle timer and affix
        live.BattleInfo = live.ModernHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        live.BattleInfo:SetPoint("TOP", live.TeamScores, "BOTTOM", 0, -3)
        live.BattleInfo:SetText("Time: 0:00 | Affix: None")
        live.BattleInfo:SetTextColor(0.8, 0.8, 0.8, 1)
    end
    
    -- Create tabbed view for Alliance/Horde
    if not live.TabFrame then
        live.TabFrame = CreateFrame("Frame", nil, live)
        live.TabFrame:SetPoint("TOPLEFT", live.ModernHeader, "BOTTOMLEFT", 0, -5)
        live.TabFrame:SetPoint("BOTTOMRIGHT", live, "BOTTOMRIGHT", -10, 10)
        
        -- Tab buttons
        live.AllianceTab = CreateFrame("Button", nil, live.TabFrame, "OptionsFrameTabButtonTemplate")
        live.AllianceTab:SetPoint("TOPLEFT", live.TabFrame, "TOPLEFT", 5, 0)
        live.AllianceTab:SetText("Alliance")
        live.AllianceTab:SetScript("OnClick", function() HLBG.ShowScoreboardTab("Alliance") end)
        
        live.HordeTab = CreateFrame("Button", nil, live.TabFrame, "OptionsFrameTabButtonTemplate")
        live.HordeTab:SetPoint("LEFT", live.AllianceTab, "RIGHT", -15, 0)
        live.HordeTab:SetText("Horde")
        live.HordeTab:SetScript("OnClick", function() HLBG.ShowScoreboardTab("Horde") end)
        
        live.AllTab = CreateFrame("Button", nil, live.TabFrame, "OptionsFrameTabButtonTemplate")
        live.AllTab:SetPoint("LEFT", live.HordeTab, "RIGHT", -15, 0)
        live.AllTab:SetText("All Players")
        live.AllTab:SetScript("OnClick", function() HLBG.ShowScoreboardTab("All") end)
        
        -- Set default tab
        live.activeTab = "All"
        
        -- Scroll frame for player list
        live.PlayerScroll = CreateFrame("ScrollFrame", nil, live.TabFrame, "UIPanelScrollFrameTemplate")
        live.PlayerScroll:SetPoint("TOPLEFT", live.TabFrame, "TOPLEFT", 8, -30)
        live.PlayerScroll:SetPoint("BOTTOMRIGHT", live.TabFrame, "BOTTOMRIGHT", -28, 8)
        
        live.PlayerContent = CreateFrame("Frame", nil, live.PlayerScroll)
        live.PlayerContent:SetSize(440, 300)
        live.PlayerScroll:SetScrollChild(live.PlayerContent)
        
        -- Column headers
        live.ColumnHeaders = CreateFrame("Frame", nil, live.PlayerScroll)
        live.ColumnHeaders:SetPoint("BOTTOMLEFT", live.PlayerScroll, "TOPLEFT", 0, 2)
        live.ColumnHeaders:SetSize(440, 20)
        
        local headerBg = live.ColumnHeaders:CreateTexture(nil, "BACKGROUND")
        headerBg:SetAllPoints()
        headerBg:SetTexture("Interface/Tooltips/UI-Tooltip-Background")
        headerBg:SetVertexColor(0.2, 0.2, 0.3, 0.8)
        
        -- Header columns with sorting
        live.NameHeader = HLBG.CreateSortableHeader(live.ColumnHeaders, "Player", "LEFT", 0, 0, 180, "name")
        live.ScoreHeader = HLBG.CreateSortableHeader(live.ColumnHeaders, "Score", "LEFT", 180, 0, 60, "score")
        live.HKHeader = HLBG.CreateSortableHeader(live.ColumnHeaders, "HKs", "LEFT", 240, 0, 50, "hk")
        live.DeathsHeader = HLBG.CreateSortableHeader(live.ColumnHeaders, "Deaths", "LEFT", 290, 0, 50, "deaths")
        live.StatusHeader = HLBG.CreateSortableHeader(live.ColumnHeaders, "Status", "LEFT", 340, 0, 80, "status")
        
        -- Initialize player rows
        live.PlayerRows = {}
        live.sortField = "score"
        live.sortDirection = "DESC"
    end
    
    live.modernInitialized = true
end

-- Create sortable column header
function HLBG.CreateSortableHeader(parent, text, justify, x, y, width, field)
    local header = CreateFrame("Button", nil, parent)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    header:SetSize(width, 20)
    
    local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerText:SetPoint(justify, header, justify, 2, 0)
    headerText:SetText(text)
    headerText:SetTextColor(1, 1, 1, 1)
    
    local arrow = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", header, "RIGHT", -2, 0)
    arrow:SetText("")
    
    header:SetScript("OnClick", function()
        if HLBG.UI.Live.sortField == field then
            -- Toggle direction
            HLBG.UI.Live.sortDirection = (HLBG.UI.Live.sortDirection == "ASC") and "DESC" or "ASC"
        else
            -- New field
            HLBG.UI.Live.sortField = field
            HLBG.UI.Live.sortDirection = "DESC"
        end
        
        -- Update arrow indicators
        HLBG.UpdateSortIndicators()
        
        -- Re-process data with new sort
        if HLBG.UI.Live.lastRows then
            HLBG.ProcessPlayerData(HLBG.UI.Live.lastRows)
        end
    end)
    
    header.text = headerText
    header.arrow = arrow
    header.field = field
    
    return header
end

-- Update sort indicator arrows
function HLBG.UpdateSortIndicators()
    local live = HLBG.UI.Live
    local headers = {live.NameHeader, live.ScoreHeader, live.HKHeader, live.DeathsHeader, live.StatusHeader}
    
    for _, header in ipairs(headers) do
        if header and header.arrow then
            if header.field == live.sortField then
                header.arrow:SetText(live.sortDirection == "ASC" and "↑" or "↓")
                header.text:SetTextColor(1, 1, 0, 1) -- Yellow for active sort
            else
                header.arrow:SetText("")
                header.text:SetTextColor(1, 1, 1, 1) -- White for inactive
            end
        end
    end
end

-- Show specific scoreboard tab
function HLBG.ShowScoreboardTab(tab)
    local live = HLBG.UI.Live
    live.activeTab = tab
    
    -- Update tab appearance
    PanelTemplates_SetTab(live.TabFrame, tab == "Alliance" and 1 or (tab == "Horde" and 2 or 3))
    
    -- Re-process current data
    if live.lastRows then
        HLBG.ProcessPlayerData(live.lastRows)
    end
end

-- Update team summary information
function HLBG.UpdateTeamSummary()
    local live = HLBG.UI.Live
    if not live.ModernHeader then return end
    
    -- Get current battle data
    local res = _G.RES or {A = 0, H = 0}
    local status = HLBG._lastStatus or {}
    
    -- Update team scores
    local allianceScore = tonumber(res.A or 0) or 0
    local hordeScore = tonumber(res.H or 0) or 0
    live.TeamScores:SetText(string.format("Alliance: %d  |  Horde: %d", allianceScore, hordeScore))
    
    -- Color code based on leading team
    if allianceScore > hordeScore then
        live.TeamScores:SetTextColor(0.12, 0.56, 1, 1) -- Alliance blue
    elseif hordeScore > allianceScore then
        live.TeamScores:SetTextColor(1, 0.2, 0.2, 1) -- Horde red
    else
        live.TeamScores:SetTextColor(1, 1, 1, 1) -- White for tie
    end
    
    -- Update battle info
    local timeLeft = tonumber(HLBG._timeLeft or 0) or 0
    local minutes = math.floor(timeLeft / 60)
    local seconds = timeLeft % 60
    local affixName = HLBG._affixText or "None"
    
    live.BattleInfo:SetText(string.format("Time: %d:%02d | Affix: %s", minutes, seconds, affixName))
    
    -- Update battle status based on phase
    local phase = status.phase or "UNKNOWN"
    if phase == "WARMUP" then
        live.BattleStatus:SetText("Hinterland Battleground - Warmup")
        live.BattleStatus:SetTextColor(1, 1, 0, 1)
    elseif phase == "BATTLE" or phase == "LIVE" then
        live.BattleStatus:SetText("Hinterland Battleground - Live")
        live.BattleStatus:SetTextColor(1, 0.2, 0.2, 1)
    elseif phase == "ENDED" then
        live.BattleStatus:SetText("Hinterland Battleground - Ended")
        live.BattleStatus:SetTextColor(0.6, 0.6, 0.6, 1)
    else
        live.BattleStatus:SetText("Hinterland Battleground")
        live.BattleStatus:SetTextColor(1, 1, 1, 1)
    end
end

-- Process and display player data
function HLBG.ProcessPlayerData(rows)
    local live = HLBG.UI.Live
    if not live.PlayerRows then return end
    
    -- Filter data based on active tab
    local filteredRows = {}
    for _, row in ipairs(rows) do
        local team = row.team or row[3] or "Unknown"
        
        if live.activeTab == "All" or 
           (live.activeTab == "Alliance" and team == "Alliance") or
           (live.activeTab == "Horde" and team == "Horde") then
            table.insert(filteredRows, row)
        end
    end
    
    -- Sort data
    if HinterlandAffixHUDDB.autoSortScoreboard then
        HLBG.SortPlayerData(filteredRows)
    end
    
    -- Hide existing rows
    for _, rowFrame in ipairs(live.PlayerRows) do
        rowFrame:Hide()
    end
    
    -- Display player rows
    for i, rowData in ipairs(filteredRows) do
        local rowFrame = HLBG.GetOrCreatePlayerRow(i)
        HLBG.UpdatePlayerRow(rowFrame, rowData, i)
        rowFrame:Show()
    end
    
    -- Update scroll area height
    local totalHeight = math.max(300, #filteredRows * (HinterlandAffixHUDDB.compactScoreboard and 20 or 25) + 20)
    live.PlayerContent:SetHeight(totalHeight)
end

-- Sort player data based on current settings
function HLBG.SortPlayerData(rows)
    local live = HLBG.UI.Live
    local field = live.sortField or "score"
    local direction = live.sortDirection or "DESC"
    
    table.sort(rows, function(a, b)
        local aValue, bValue
        
        if field == "name" then
            aValue = tostring(a.name or a[3] or a[1] or "")
            bValue = tostring(b.name or b[3] or b[1] or "")
        elseif field == "score" then
            aValue = tonumber(a.score or a[5] or a[2] or 0) or 0
            bValue = tonumber(b.score or b[5] or b[2] or 0) or 0
        elseif field == "hk" then
            aValue = tonumber(a.hk or a.HK or a[6] or 0) or 0
            bValue = tonumber(b.hk or b.HK or b[6] or 0) or 0
        elseif field == "deaths" then
            aValue = tonumber(a.deaths or a[7] or 0) or 0
            bValue = tonumber(b.deaths or b[7] or 0) or 0
        else
            aValue = tostring(a[field] or "")
            bValue = tostring(b[field] or "")
        end
        
        if direction == "ASC" then
            if type(aValue) == "number" and type(bValue) == "number" then
                return aValue < bValue
            else
                return tostring(aValue) < tostring(bValue)
            end
        else
            if type(aValue) == "number" and type(bValue) == "number" then
                return aValue > bValue
            else
                return tostring(aValue) > tostring(bValue)
            end
        end
    end)
end

-- Get or create player row frame
function HLBG.GetOrCreatePlayerRow(index)
    local live = HLBG.UI.Live
    
    if live.PlayerRows[index] then
        return live.PlayerRows[index]
    end
    
    -- Create new row
    local rowHeight = HinterlandAffixHUDDB.compactScoreboard and 20 or 25
    local row = CreateFrame("Frame", nil, live.PlayerContent)
    row:SetSize(440, rowHeight)
    row:SetPoint("TOPLEFT", live.PlayerContent, "TOPLEFT", 0, -(index - 1) * rowHeight)
    
    -- Row background for hover effect
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetTexture("Interface/Tooltips/UI-Tooltip-Background")
    row.bg:SetVertexColor(0, 0, 0, 0) -- Transparent by default
    
    -- Player name
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameText:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.nameText:SetSize(175, rowHeight)
    row.nameText:SetJustifyH("LEFT")
    
    -- Score
    row.scoreText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.scoreText:SetPoint("LEFT", row, "LEFT", 182, 0)
    row.scoreText:SetSize(55, rowHeight)
    row.scoreText:SetJustifyH("CENTER")
    
    -- Honor kills
    row.hkText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.hkText:SetPoint("LEFT", row, "LEFT", 242, 0)
    row.hkText:SetSize(45, rowHeight)
    row.hkText:SetJustifyH("CENTER")
    
    -- Deaths
    row.deathsText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.deathsText:SetPoint("LEFT", row, "LEFT", 292, 0)
    row.deathsText:SetSize(45, rowHeight)
    row.deathsText:SetJustifyH("CENTER")
    
    -- Status/Class
    row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.statusText:SetPoint("LEFT", row, "LEFT", 342, 0)
    row.statusText:SetSize(75, rowHeight)
    row.statusText:SetJustifyH("CENTER")
    
    -- Hover effects
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        self.bg:SetVertexColor(1, 1, 1, 0.1)
    end)
    row:SetScript("OnLeave", function(self)
        self.bg:SetVertexColor(0, 0, 0, 0)
    end)
    
    live.PlayerRows[index] = row
    return row
end

-- Update player row with data
function HLBG.UpdatePlayerRow(rowFrame, rowData, index)
    -- Extract data
    local name = tostring(rowData.name or rowData[3] or rowData[1] or "Unknown")
    local score = tonumber(rowData.score or rowData[5] or rowData[2] or 0) or 0
    local hk = tonumber(rowData.hk or rowData.HK or rowData[6] or 0) or 0
    local deaths = tonumber(rowData.deaths or rowData[7] or 0) or 0
    local team = tostring(rowData.team or rowData[4] or "Unknown")
    local class = tostring(rowData.class or rowData[8] or ""):upper()
    
    -- Update name with class colors if enabled
    if HinterlandAffixHUDDB.useClassColors and CLASS_COLORS[class] then
        local color = CLASS_COLORS[class]
        rowFrame.nameText:SetTextColor(color[1], color[2], color[3], 1)
    else
        -- Team colors
        if team == "Alliance" then
            rowFrame.nameText:SetTextColor(0.12, 0.56, 1, 1)
        elseif team == "Horde" then
            rowFrame.nameText:SetTextColor(1, 0.2, 0.2, 1)
        else
            rowFrame.nameText:SetTextColor(1, 1, 1, 1)
        end
    end
    
    rowFrame.nameText:SetText(name)
    rowFrame.scoreText:SetText(tostring(score))
    rowFrame.hkText:SetText(tostring(hk))
    rowFrame.deathsText:SetText(tostring(deaths))
    rowFrame.statusText:SetText(class ~= "" and class or team)
    
    -- Alternate row backgrounds
    if index % 2 == 0 then
        rowFrame.bg:SetVertexColor(0.1, 0.1, 0.1, 0.3)
    else
        rowFrame.bg:SetVertexColor(0, 0, 0, 0)
    end
end

-- Flash effect for scoreboard updates
function HLBG.FlashScoreboardUpdate()
    local live = HLBG.UI.Live
    if not live.ModernHeader then return end
    
    -- Create flash effect
    if not live.flashTexture then
        live.flashTexture = live.ModernHeader:CreateTexture(nil, "OVERLAY")
        live.flashTexture:SetAllPoints(live.ModernHeader)
        live.flashTexture:SetTexture("Interface/Tooltips/UI-Tooltip-Background")
        live.flashTexture:SetVertexColor(1, 1, 0, 0)
    end
    
    -- Animate flash
    local alpha = 0.3
    local fadeTime = 0.5
    local elapsed = 0
    
    local flashFrame = CreateFrame("Frame")
    flashFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        alpha = 0.3 * (1 - (elapsed / fadeTime))
        
        if alpha <= 0 then
            live.flashTexture:SetVertexColor(1, 1, 0, 0)
            self:SetScript("OnUpdate", nil)
        else
            live.flashTexture:SetVertexColor(1, 1, 0, alpha)
        end
    end)
end

-- Hook into original Live function for compatibility
if HLBG.Live and not HLBG.OriginalLive then
    HLBG.OriginalLive = HLBG.Live
end

HLBG.Live = HLBG.ModernLive

-- Refresh function for settings changes
function HLBG.RefreshScoreboard()
    local live = HLBG.UI.Live
    if live and live.lastRows then
        live.modernInitialized = false
        HLBG.ModernLive(live.lastRows)
    end
end

_G.HLBG = HLBG