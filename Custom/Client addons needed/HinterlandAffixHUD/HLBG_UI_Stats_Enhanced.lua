-- HLBG_UI_Stats_Enhanced.lua - Enhanced statistics display for Hinterland Battleground

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Stats page handler
function HLBG.Stats(stats)
    HLBG._ensureUI('Stats')
    stats = stats or {}
    
    -- Store last stats for reference
    HLBG._lastStats = stats
    
    local s = HLBG.UI and HLBG.UI.Stats
    if not s then return end
    
    -- Initialize UI components if needed
    if not s.initialized then
        -- Create scrollable frame for content
        s.ScrollFrame = CreateFrame("ScrollFrame", "HLBG_StatsScrollFrame", s, "UIPanelScrollFrameTemplate")
        s.ScrollFrame:SetPoint("TOPLEFT", s, "TOPLEFT", 10, -10)
        s.ScrollFrame:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -30, 10)
        
        s.Content = CreateFrame("Frame", "HLBG_StatsScrollContent", s.ScrollFrame)
        s.Content:SetSize(s:GetWidth() - 40, 600)  -- Will adjust based on content
        s.ScrollFrame:SetScrollChild(s.Content)
        
        -- Summary box
        s.SummaryBox = CreateFrame("Frame", nil, s.Content)
        s.SummaryBox:SetPoint("TOPLEFT", s.Content, "TOPLEFT", 5, -5)
        s.SummaryBox:SetPoint("RIGHT", s.Content, "RIGHT", -5, 0)
        s.SummaryBox:SetHeight(120)
        s.SummaryBox:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        s.SummaryBox:SetBackdropColor(0, 0, 0, 0.5)
        
        -- Summary title
        s.SummaryTitle = s.SummaryBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        s.SummaryTitle:SetPoint("TOPLEFT", s.SummaryBox, "TOPLEFT", 10, -10)
        s.SummaryTitle:SetText("Overall Statistics")
        s.SummaryTitle:SetTextColor(1, 0.82, 0)
        
        -- Summary text
        s.SummaryText = s.SummaryBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        s.SummaryText:SetPoint("TOPLEFT", s.SummaryTitle, "BOTTOMLEFT", 0, -5)
        s.SummaryText:SetPoint("BOTTOMRIGHT", s.SummaryBox, "BOTTOMRIGHT", -10, 10)
        s.SummaryText:SetJustifyH("LEFT")
        
        -- Faction win rates box
        s.FactionBox = CreateFrame("Frame", nil, s.Content)
        s.FactionBox:SetPoint("TOPLEFT", s.SummaryBox, "BOTTOMLEFT", 0, -20)
        s.FactionBox:SetPoint("RIGHT", s.Content, "RIGHT", -5, 0)
        s.FactionBox:SetHeight(120)
        s.FactionBox:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        s.FactionBox:SetBackdropColor(0, 0, 0, 0.5)
        
        -- Faction title
        s.FactionTitle = s.FactionBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        s.FactionTitle:SetPoint("TOPLEFT", s.FactionBox, "TOPLEFT", 10, -10)
        s.FactionTitle:SetText("Win Rates by Faction")
        s.FactionTitle:SetTextColor(1, 0.82, 0)
        
        -- Alliance bar
        s.AllianceBar = CreateFrame("StatusBar", nil, s.FactionBox)
        s.AllianceBar:SetPoint("TOPLEFT", s.FactionTitle, "BOTTOMLEFT", 5, -15)
        s.AllianceBar:SetSize(s.FactionBox:GetWidth() - 30, 20)
        s.AllianceBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        s.AllianceBar:SetStatusBarColor(0.2, 0.2, 0.8, 0.8) -- Alliance blue
        s.AllianceBar:SetMinMaxValues(0, 100)
        s.AllianceBar:SetValue(0)
        
        -- Alliance text
        s.AllianceText = s.FactionBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        s.AllianceText:SetPoint("LEFT", s.AllianceBar, "LEFT", 5, 0)
        s.AllianceText:SetText("Alliance: 0%")
        
        -- Horde bar
        s.HordeBar = CreateFrame("StatusBar", nil, s.FactionBox)
        s.HordeBar:SetPoint("TOPLEFT", s.AllianceBar, "BOTTOMLEFT", 0, -15)
        s.HordeBar:SetSize(s.FactionBox:GetWidth() - 30, 20)
        s.HordeBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        s.HordeBar:SetStatusBarColor(0.8, 0.2, 0.2, 0.8) -- Horde red
        s.HordeBar:SetMinMaxValues(0, 100)
        s.HordeBar:SetValue(0)
        
        -- Horde text
        s.HordeText = s.FactionBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        s.HordeText:SetPoint("LEFT", s.HordeBar, "LEFT", 5, 0)
        s.HordeText:SetText("Horde: 0%")
        
        -- Affix statistics box
        s.AffixBox = CreateFrame("Frame", nil, s.Content)
        s.AffixBox:SetPoint("TOPLEFT", s.FactionBox, "BOTTOMLEFT", 0, -20)
        s.AffixBox:SetPoint("RIGHT", s.Content, "RIGHT", -5, 0)
        s.AffixBox:SetHeight(300) -- Will be adjusted based on content
        s.AffixBox:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        s.AffixBox:SetBackdropColor(0, 0, 0, 0.5)
        
        -- Affix title
        s.AffixTitle = s.AffixBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        s.AffixTitle:SetPoint("TOPLEFT", s.AffixBox, "TOPLEFT", 10, -10)
        s.AffixTitle:SetText("Win Rates by Affix")
        s.AffixTitle:SetTextColor(1, 0.82, 0)
        
        -- Table headers
        local headers = {
            { text = "Affix", width = 120 },
            { text = "Total", width = 60 },
            { text = "Alliance", width = 60 },
            { text = "Horde", width = 60 },
            { text = "A Win %", width = 60 },
            { text = "H Win %", width = 60 }
        }
        
        s.Headers = {}
        local x = 15
        for i, header in ipairs(headers) do
            local headerText = s.AffixBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            headerText:SetPoint("TOPLEFT", s.AffixTitle, "BOTTOMLEFT", x, -15)
            headerText:SetText(header.text)
            s.Headers[i] = headerText
            x = x + header.width
        end
        
        -- Container for affix rows
        s.AffixRows = CreateFrame("Frame", nil, s.AffixBox)
        s.AffixRows:SetPoint("TOPLEFT", s.Headers[1], "BOTTOMLEFT", 0, -10)
        s.AffixRows:SetPoint("RIGHT", s.AffixBox, "RIGHT", -15, 0)
        s.AffixRows:SetPoint("BOTTOM", s.AffixBox, "BOTTOM", 0, 10)
        
        s.AffixData = {} -- Store affix rows for reuse
        
        s.initialized = true
    end
    
    -- Get basic counts from stats
    local counts = stats.counts or {}
    local alliance = tonumber(counts.Alliance or counts.ALLIANCE or 0) or 0
    local horde = tonumber(counts.Horde or counts.HORDE or 0) or 0
    local draws = tonumber(stats.draws or 0) or 0
    local total = alliance + horde + draws
    
    -- Calculate average duration
    local avgDuration = tonumber(stats.avgDuration or 0) or 0
    local minutes = math.floor(avgDuration / 60)
    local seconds = math.floor(avgDuration % 60)
    
    -- Update summary text
    local summaryLines = {}
    table.insert(summaryLines, string.format("Total Matches: %d", total))
    table.insert(summaryLines, string.format("Alliance Wins: %d", alliance))
    table.insert(summaryLines, string.format("Horde Wins: %d", horde))
    table.insert(summaryLines, string.format("Draws: %d", draws))
    table.insert(summaryLines, string.format("Average Duration: %d:%02d", minutes, seconds))
    
    -- Add win streaks if available
    if stats.winstreakA and tonumber(stats.winstreakA) > 0 then
        table.insert(summaryLines, string.format("Current Alliance Win Streak: %d", stats.winstreakA))
    end
    
    if stats.winstreakH and tonumber(stats.winstreakH) > 0 then
        table.insert(summaryLines, string.format("Current Horde Win Streak: %d", stats.winstreakH))
    end
    
    -- Add manual vs auto games if available
    if stats.manual or stats.auto then
        local manual = tonumber(stats.manual or 0) or 0
        local auto = tonumber(stats.auto or 0) or 0
        table.insert(summaryLines, string.format("Manual Starts: %d, Auto Starts: %d", manual, auto))
    end
    
    s.SummaryText:SetText(table.concat(summaryLines, "\n"))
    
    -- Update faction win rates
    local alliancePct = 0
    local hordePct = 0
    
    if total > 0 then
        alliancePct = math.floor((alliance / total) * 100)
        hordePct = math.floor((horde / total) * 100)
    end
    
    s.AllianceBar:SetValue(alliancePct)
    s.AllianceText:SetText(string.format("Alliance: %d%%", alliancePct))
    s.HordeBar:SetValue(hordePct)
    s.HordeText:SetText(string.format("Horde: %d%%", hordePct))
    
    -- Update affix statistics
    local affixWins = stats.affixWins or {}
    
    -- Clear previous rows
    for _, row in pairs(s.AffixData) do
        row.frame:Hide()
    end
    
    -- Create a sorted list of affixes
    local affixes = {}
    for affixId, _ in pairs(affixWins) do
        table.insert(affixes, affixId)
    end
    table.sort(affixes, function(a, b) 
        local aName = HLBG.GetAffixName and HLBG.GetAffixName(a) or tostring(a)
        local bName = HLBG.GetAffixName and HLBG.GetAffixName(b) or tostring(b)
        return aName < bName
    end)
    
    -- Update or create rows for each affix
    local y = -10
    for i, affixId in ipairs(affixes) do
        -- Get or create row
        if not s.AffixData[affixId] then
            local row = {}
            row.frame = CreateFrame("Frame", nil, s.AffixRows)
            row.frame:SetHeight(20)
            
            -- Create cells
            row.cells = {}
            local x = 0
            local cellWidths = {120, 60, 60, 60, 60, 60}
            
            for j = 1, 6 do
                row.cells[j] = row.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.cells[j]:SetPoint("LEFT", row.frame, "LEFT", x, 0)
                row.cells[j]:SetWidth(cellWidths[j])
                row.cells[j]:SetJustifyH("LEFT")
                x = x + cellWidths[j]
            end
            
            -- Add background for even rows
            if i % 2 == 0 then
                local bg = row.frame:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0.2, 0.2, 0.2, 0.3)
            end
            
            s.AffixData[affixId] = row
        end
        
        -- Update row data
        local row = s.AffixData[affixId]
        local data = affixWins[affixId]
        local count = tonumber(data.count or 0) or 0
        local alliance = tonumber(data.alliance or 0) or 0
        local horde = tonumber(data.horde or 0) or 0
        local draws = count - alliance - horde
        
        local aPct = count > 0 and math.floor((alliance / count) * 100) or 0
        local hPct = count > 0 and math.floor((horde / count) * 100) or 0
        
        -- Update cells
        row.cells[1]:SetText(HLBG.GetAffixName and HLBG.GetAffixName(affixId) or tostring(affixId))
        row.cells[2]:SetText(tostring(count))
        row.cells[3]:SetText(tostring(alliance))
        row.cells[4]:SetText(tostring(horde))
        row.cells[5]:SetText(string.format("%d%%", aPct))
        row.cells[6]:SetText(string.format("%d%%", hPct))
        
        -- Position row
        row.frame:SetPoint("TOPLEFT", s.AffixRows, "TOPLEFT", 0, y)
        row.frame:SetPoint("RIGHT", s.AffixRows, "RIGHT", 0, 0)
        row.frame:Show()
        
        y = y - 20
    end
    
    -- Adjust affix box height based on content
    local affixRowsHeight = #affixes * 20 + 50 -- 20px per row + header space
    s.AffixBox:SetHeight(math.max(100, affixRowsHeight))
    
    -- Adjust total content height
    local totalContentHeight = s.SummaryBox:GetHeight() + s.FactionBox:GetHeight() + s.AffixBox:GetHeight() + 40 -- Add padding
    s.Content:SetHeight(totalContentHeight)
    
    -- Show the UI
    if HLBG.UI and HLBG.UI.Frame and type(ShowTab) == "function" then
        HLBG.UI.Frame:Show()
        ShowTab(2)  -- Show Stats tab
    end
end

-- Function to handle stats string data (fallback method)
function HLBG.StatsStr(jsonStr)
    -- Try to parse JSON
    local success, stats
    if HLBG.ParseJSON then
        success, stats = pcall(HLBG.ParseJSON, jsonStr)
    end
    
    -- If JSON parsing fails, try simple parsing
    if not success or not stats then
        stats = {}
        
        -- Simple parser for key=value format
        for line in string.gmatch(jsonStr, "[^\n]+") do
            local key, value = string.match(line, "^([^=]+)=(.+)$")
            if key and value then
                stats[key] = value
            end
        end
    end
    
    -- Pass to main stats handler
    HLBG.Stats(stats)
end