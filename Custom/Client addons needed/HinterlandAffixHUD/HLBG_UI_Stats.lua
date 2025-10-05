-- HLBG_UI_Stats.lua - Enhanced Stats display for Hinterland Battleground

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Override the existing Stats handler with an enhanced version
function HLBG.Stats(stats)
    HLBG._ensureUI('Stats')
    stats = stats or {}
    
    -- Store stats for reference
    HLBG._lastStats = stats
    
    local s = HLBG.UI and HLBG.UI.Stats
    if not s then return end
    
    -- Initialize UI components if needed
    if not s.initialized then
    -- Create scrollable frame for content
    s.ScrollFrame = CreateFrame("ScrollFrame", "HLBG_StatsScrollFrame", s, "UIPanelScrollFrameTemplate")
        s.ScrollFrame:SetPoint("TOPLEFT", s, "TOPLEFT", 10, -10)
        s.ScrollFrame:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -30, 10)
        
        s.Content = CreateFrame("Frame", nil, s.ScrollFrame)
        s.Content:SetSize(s:GetWidth() - 40, 600)  -- Make it tall enough for all content
        s.ScrollFrame:SetScrollChild(s.Content)
        
        -- Main title
        s.Title = s.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        s.Title:SetPoint("TOPLEFT", s.Content, "TOPLEFT", 5, -5)
        s.Title:SetPoint("RIGHT", s.Content, "RIGHT", -5, 0)
        s.Title:SetJustifyH("CENTER")
        s.Title:SetText("Hinterland Battleground Statistics")
        
        -- Summary section
        s.SummaryTitle = s.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        s.SummaryTitle:SetPoint("TOPLEFT", s.Title, "BOTTOMLEFT", 0, -20)
        s.SummaryTitle:SetText("Summary")
        s.SummaryTitle:SetTextColor(1, 0.82, 0)
        
        s.Summary = CreateFrame("Frame", nil, s.Content)
        s.Summary:SetPoint("TOPLEFT", s.SummaryTitle, "BOTTOMLEFT", 0, -5)
        s.Summary:SetPoint("RIGHT", s.Content, "RIGHT", -5, 0)
        s.Summary:SetHeight(80)
        
        -- Victory counts section
        s.WinsTitle = s.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        s.WinsTitle:SetPoint("TOPLEFT", s.Summary, "BOTTOMLEFT", 0, -15)
        s.WinsTitle:SetText("Victory Counts")
        s.WinsTitle:SetTextColor(1, 0.82, 0)
        
        s.Wins = CreateFrame("Frame", nil, s.Content)
        s.Wins:SetPoint("TOPLEFT", s.WinsTitle, "BOTTOMLEFT", 0, -5)
        s.Wins:SetPoint("RIGHT", s.Content, "RIGHT", -5, 0)
        s.Wins:SetHeight(80)
        
        -- Affix statistics section
        s.AffixTitle = s.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        s.AffixTitle:SetPoint("TOPLEFT", s.Wins, "BOTTOMLEFT", 0, -15)
        s.AffixTitle:SetText("Affix Statistics")
        s.AffixTitle:SetTextColor(1, 0.82, 0)
        
        s.Affixes = CreateFrame("Frame", nil, s.Content)
        s.Affixes:SetPoint("TOPLEFT", s.AffixTitle, "BOTTOMLEFT", 0, -5)
        s.Affixes:SetPoint("RIGHT", s.Content, "RIGHT", -5, 0)
        s.Affixes:SetHeight(200)  -- Will adjust based on content
        
        -- Streaks section
        s.StreaksTitle = s.Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        s.StreaksTitle:SetPoint("TOPLEFT", s.Affixes, "BOTTOMLEFT", 0, -15)
        s.StreaksTitle:SetText("Winning Streaks")
        s.StreaksTitle:SetTextColor(1, 0.82, 0)
        
        s.Streaks = CreateFrame("Frame", nil, s.Content)
        s.Streaks:SetPoint("TOPLEFT", s.StreaksTitle, "BOTTOMLEFT", 0, -5)
        s.Streaks:SetPoint("RIGHT", s.Content, "RIGHT", -5, 0)
        s.Streaks:SetHeight(80)
        
        -- Season selector
        s.SeasonFrame = CreateFrame("Frame", nil, s)
        s.SeasonFrame:SetPoint("TOPRIGHT", s, "TOPRIGHT", -15, -10)
        s.SeasonFrame:SetSize(120, 30)
        
        s.SeasonLabel = s.SeasonFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        s.SeasonLabel:SetPoint("LEFT", s.SeasonFrame, "LEFT", 0, 0)
        s.SeasonLabel:SetText("Season:")
        
        s.SeasonDropdown = CreateFrame("Button", "HLBG_StatsSeasonDropDown", s.SeasonFrame, "UIDropDownMenuTemplate")
        s.SeasonDropdown:SetPoint("LEFT", s.SeasonLabel, "RIGHT", 5, -3)
        
        UIDropDownMenu_Initialize(s.SeasonDropdown, function(self, level)
            local info = UIDropDownMenu_CreateInfo()
            info.text = "Current"
            info.value = 0
            info.func = function() 
                UIDropDownMenu_SetText(s.SeasonDropdown, "Current")
                HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
                HinterlandAffixHUDDB.desiredSeason = 0
                if _G.AIO and _G.AIO.Handle then
                    _G.AIO.Handle("HLBG", "Request", "STATS", 0)
                end
            end
            info.checked = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.desiredSeason or 0) == 0
            UIDropDownMenu_AddButton(info)
            
            -- Add seasons 1 through 5 (can be extended)
            for i = 1, 5 do
                local info = UIDropDownMenu_CreateInfo()
                info.text = "Season " .. i
                info.value = i
                info.func = function() 
                    UIDropDownMenu_SetText(s.SeasonDropdown, "Season " .. i)
                    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
                    HinterlandAffixHUDDB.desiredSeason = i
                    if _G.AIO and _G.AIO.Handle then
                        _G.AIO.Handle("HLBG", "Request", "STATS", i)
                    end
                end
                info.checked = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.desiredSeason or 0) == i
                UIDropDownMenu_AddButton(info)
            end
        end)
        
        -- Set initial text
        local season = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.desiredSeason) or 0
        if season == 0 then
            UIDropDownMenu_SetText(s.SeasonDropdown, "Current")
        else
            UIDropDownMenu_SetText(s.SeasonDropdown, "Season " .. season)
        end
        
        -- Refresh button
        s.RefreshButton = CreateFrame("Button", nil, s, "UIPanelButtonTemplate")
        s.RefreshButton:SetSize(80, 22)
        s.RefreshButton:SetPoint("TOPRIGHT", s.SeasonFrame, "BOTTOMRIGHT", 0, -5)
        s.RefreshButton:SetText("Refresh")
        s.RefreshButton:SetScript("OnClick", function()
            local season = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.desiredSeason) or 0
            if _G.AIO and _G.AIO.Handle then
                _G.AIO.Handle("HLBG", "Request", "STATS", season)
            end
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("HLBG: Requesting fresh statistics...")
            end
        end)
        
        -- Set as initialized
        s.initialized = true
    end
    
    -- Update summary section
    local totalMatches = tonumber(stats.total or 0) or 0
    local avgDuration = tonumber(stats.avgDuration or 0) or 0
    local draws = tonumber(stats.draws or 0) or 0
    
    -- Get team totals
    local counts = stats.counts or {}
    local alliance = tonumber(counts.Alliance or counts.ALLIANCE or 0) or 0
    local horde = tonumber(counts.Horde or counts.HORDE or 0) or 0
    
    -- Create formatted strings for the summary section
    local summaryText = string.format("Total Matches: %d\nAverage Duration: %d minutes %d seconds\n",
        totalMatches,
        math.floor(avgDuration / 60),
        math.floor(avgDuration % 60))
    
    if not s.SummaryText then
        s.SummaryText = s.Summary:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        s.SummaryText:SetPoint("TOPLEFT", s.Summary, "TOPLEFT", 10, -5)
        s.SummaryText:SetPoint("RIGHT", s.Summary, "RIGHT", -10, 0)
        s.SummaryText:SetJustifyH("LEFT")
    end
    s.SummaryText:SetText(summaryText)
    
    -- Update wins section
    local alliancePct = totalMatches > 0 and math.floor((alliance / totalMatches) * 100) or 0
    local hordePct = totalMatches > 0 and math.floor((horde / totalMatches) * 100) or 0
    local drawsPct = totalMatches > 0 and math.floor((draws / totalMatches) * 100) or 0
    
    local winsText = string.format(
        "Alliance Victories: %d (%d%%)\nHorde Victories: %d (%d%%)\nDraws: %d (%d%%)",
        alliance, alliancePct,
        horde, hordePct,
        draws, drawsPct)
    
    if not s.WinsText then
        s.WinsText = s.Wins:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        s.WinsText:SetPoint("TOPLEFT", s.Wins, "TOPLEFT", 10, -5)
        s.WinsText:SetPoint("RIGHT", s.Wins, "RIGHT", -10, 0)
        s.WinsText:SetJustifyH("LEFT")
    end
    s.WinsText:SetText(winsText)
    
    -- Update affixes section - create a table of affixes with their win rates
    if s.AffixesText then
        s.AffixesText:SetText("")
    else
        s.AffixesText = s.Affixes:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        s.AffixesText:SetPoint("TOPLEFT", s.Affixes, "TOPLEFT", 10, -5)
        s.AffixesText:SetPoint("RIGHT", s.Affixes, "RIGHT", -10, 0)
        s.AffixesText:SetJustifyH("LEFT")
    end
    
    local affixText = ""
    local byAffix = stats.byAffix or {}
    local affixList = {}
    
    for affix, data in pairs(byAffix) do
        table.insert(affixList, {
            id = affix,
            name = _G.HLBG_AFFIX_NAMES and _G.HLBG_AFFIX_NAMES[affix] or affix,
            count = tonumber(data.count or 0) or 0,
            alliance = tonumber(data.alliance or 0) or 0,
            horde = tonumber(data.horde or 0) or 0,
            draws = tonumber(data.draws or 0) or 0
        })
    end
    
    -- Sort by count
    table.sort(affixList, function(a, b) return a.count > b.count end)
    
    -- Format affix data
    for _, data in ipairs(affixList) do
        if data.count > 0 then
            local aPct = math.floor((data.alliance / data.count) * 100)
            local hPct = math.floor((data.horde / data.count) * 100)
            local dPct = math.floor((data.draws / data.count) * 100)
            
            affixText = affixText .. string.format(
                "%s: %d matches - Alliance: %d (%d%%), Horde: %d (%d%%), Draws: %d (%d%%)\n",
                data.name, data.count,
                data.alliance, aPct,
                data.horde, hPct,
                data.draws, dPct
            )
        end
    end
    
    if affixText == "" then
        affixText = "No affix statistics available."
    end
    
    s.AffixesText:SetText(affixText)
    
    -- Update streaks section
    local longestStreak = tonumber(stats.longestStreakLen or 0) or 0
    local longestStreakTeam = stats.longestStreakTeam or "None"
    local currentStreak = tonumber(stats.currentStreakLen or 0) or 0
    local currentStreakTeam = stats.currentStreakTeam or "None"
    
    local streaksText = string.format(
        "Longest Winning Streak: %d (%s)\nCurrent Winning Streak: %d (%s)",
        longestStreak, longestStreakTeam,
        currentStreak, currentStreakTeam)
    
    if not s.StreaksText then
        s.StreaksText = s.Streaks:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        s.StreaksText:SetPoint("TOPLEFT", s.Streaks, "TOPLEFT", 10, -5)
        s.StreaksText:SetPoint("RIGHT", s.Streaks, "RIGHT", -10, 0)
        s.StreaksText:SetJustifyH("LEFT")
    end
    s.StreaksText:SetText(streaksText)
    
    -- Update the overall content height
    local totalHeight = s.Title:GetHeight() + 20 +                          -- Title + padding
                       s.SummaryTitle:GetHeight() + 5 +                     -- Summary title + padding
                       s.SummaryText:GetStringHeight() + 15 +               -- Summary text + padding
                       s.WinsTitle:GetHeight() + 5 +                        -- Wins title + padding
                       s.WinsText:GetStringHeight() + 15 +                  -- Wins text + padding
                       s.AffixTitle:GetHeight() + 5 +                       -- Affix title + padding
                       s.AffixesText:GetStringHeight() + 15 +               -- Affix text + padding
                       s.StreaksTitle:GetHeight() + 5 +                     -- Streaks title + padding
                       s.StreaksText:GetStringHeight() + 20                 -- Streaks text + bottom padding
    
    s.Content:SetHeight(math.max(300, totalHeight))
    
    -- Show the UI frame
    if HLBG.UI and HLBG.UI.Frame and type(ShowTab) == "function" then
        HLBG.UI.Frame:Show()
        ShowTab(3)  -- Show Stats tab
    end
end