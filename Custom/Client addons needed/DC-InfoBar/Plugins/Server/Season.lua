--[[
    DC-InfoBar Season Plugin
    Shows current season, tokens earned, and progress
    
    Data Source: DCAddonProtocol SEAS module
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local SeasonPlugin = {
    id = "DCInfoBar_Season",
    name = "Season",
    category = "server",
    type = "combo",
    side = "left",
    priority = 10,
    icon = "Interface\\Icons\\Achievement_Arena_2v2_1",
    updateInterval = 5.0,  -- Update every 5 seconds
    
    leftClickHint = "Open Progress panel",
    rightClickHint = "View season leaderboard",
    
    -- Cached display data
    _displayText = "Season",
    _seasonName = "Unknown",
    _seasonId = 0,
    _dataReceived = false,
}

function SeasonPlugin:OnActivate()
    local function RequestSeasonData()
        local DC = rawget(_G, "DCAddonProtocol")
        if DC then
            DC:Request("SEAS", 0x01, {})  -- CMSG_GET_CURRENT
            DC:Request("SEAS", 0x03, {})  -- CMSG_GET_PROGRESS
        end
    end
    
    local function RegisterHandlers()
        local DC = rawget(_G, "DCAddonProtocol")
        if not DC then
            -- Retry after delay
            local retryFrame = CreateFrame("Frame")
            retryFrame.elapsed = 0
            retryFrame:SetScript("OnUpdate", function(self, elapsed)
                self.elapsed = self.elapsed + elapsed
                if self.elapsed >= 2 then
                    self:SetScript("OnUpdate", nil)
                    RegisterHandlers()
                end
            end)
            return
        end
        
        -- Register handler for season response (SMSG_CURRENT = 0x10)
        DC:RegisterHandler("SEAS", 0x10, function(data)
            if data then
                DCInfoBar:HandleSeasonData(data)
                SeasonPlugin._dataReceived = true
                SeasonPlugin._elapsed = 999  -- Force update
                
                -- Also update DC-Welcome Seasons if loaded
                if DCWelcome and DCWelcome.Seasons and DCWelcome.Seasons.Data then
                    DCWelcome.Seasons.Data.seasonNumber = data.seasonId or data.id
                    DCWelcome.Seasons.Data.seasonName = data.seasonName or data.name
                    DCWelcome.Seasons.Data._loaded = true
                    if DCWelcome.Seasons.UpdateProgressTracker then
                        DCWelcome.Seasons:UpdateProgressTracker()
                    end
                end
            end
        end)
        
        -- Also register for progress response (SMSG_PROGRESS = 0x12)
        DC:RegisterHandler("SEAS", 0x12, function(data)
            if data then
                DCInfoBar:HandleSeasonProgressData(data)
                SeasonPlugin._dataReceived = true
                SeasonPlugin._elapsed = 999  -- Force update
                
                -- Also update DC-Welcome Seasons if loaded
                if DCWelcome and DCWelcome.Seasons and DCWelcome.Seasons.Data then
                    local D = DCWelcome.Seasons.Data
                    
                    -- Weekly tokens/essence are the current week's progress
                    D.weeklyTokens = data.weeklyTokens or D.weeklyTokens
                    D.weeklyEssence = data.weeklyEssence or D.weeklyEssence
                    
                    -- Total tokens/essence are inventory counts (sent as 'tokens' and 'essence')
                    D.tokens = data.tokens or D.tokens
                    D.essence = data.essence or D.essence
                    
                    -- Weekly caps
                    D.weeklyTokenCap = data.tokenCap or D.weeklyTokenCap
                    D.weeklyEssenceCap = data.essenceCap or D.weeklyEssenceCap
                    
                    D._loaded = true
                    if DCWelcome.Seasons.UpdateProgressTracker then
                        DCWelcome.Seasons:UpdateProgressTracker()
                    end
                end
                    -- Debug print
                    DCInfoBar:Debug(string.format("Season plugin received progress: weeklyTokens=%s tokens=%s weeklyCap=%s", tostring(data.weeklyTokens or "nil"), tostring(data.tokens or "nil"), tostring(data.tokenCap or "nil")))
            end
        end)
        
        -- Request initial data
        RequestSeasonData()
        
        -- Retry after delay if no data (increased retries)
        local retryFrame = CreateFrame("Frame")
        retryFrame.elapsed = 0
        retryFrame.retries = 0
        retryFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= 3 then
                self.elapsed = 0
                self.retries = self.retries + 1
                
                if self.retries >= 5 then
                    self:SetScript("OnUpdate", nil)
                    return
                end
                
                if not SeasonPlugin._dataReceived then
                    RequestSeasonData()
                else
                    self:SetScript("OnUpdate", nil)
                end
            end
        end)
    end
    
    RegisterHandlers()
end

function SeasonPlugin:OnUpdate(elapsed)
    local seasonData = DCInfoBar.serverData.season
    
    if seasonData.id > 0 then
        self._seasonId = seasonData.id
        self._seasonName = seasonData.name
        
        -- Display format: "S3: Primal" or "Season 3"
        local showTokens = DCInfoBar:GetPluginSetting(self.id, "showTokens")
        
        if showTokens then
            -- Show season + tokens
            local tokenText = seasonData.weeklyTokens .. "/" .. seasonData.weeklyCap
            return "S" .. seasonData.id .. ": ", tokenText
        else
            -- Just show season name
            local displayName = seasonData.name
            if displayName == "Unknown" or displayName == "Unknown Season" then
                displayName = "Season " .. seasonData.id
            end
            return "", "S" .. seasonData.id .. ": " .. displayName
        end
    else
        return "", "Season"
    end
end

function SeasonPlugin:OnServerData(data)
    -- Called when new season data arrives from server
    self._seasonId = data.id or 0
    self._seasonName = data.name or "Unknown"
    self._elapsed = 999  -- Force immediate update
end

function SeasonPlugin:OnTooltip(tooltip)
    local seasonData = DCInfoBar.serverData.season
    
    -- Fallback: Check DCWelcome.Seasons.Data if our data isn't populated
    if (not seasonData.id or seasonData.id == 0 or seasonData.name == "Unknown") and DCWelcome and DCWelcome.Seasons and DCWelcome.Seasons.Data then
        local D = DCWelcome.Seasons.Data
        if D._loaded and D.seasonNumber and D.seasonNumber > 0 then
            seasonData = {
                id = D.seasonNumber,
                name = D.seasonName or "Unknown Season",
                weeklyTokens = D.weeklyTokens or D.tokens or 0,
                weeklyCap = D.weeklyTokenCap or 1000,
                weeklyEssence = D.weeklyEssence or D.essence or 0,
                essenceCap = D.weeklyEssenceCap or 1000,
                totalTokens = D.tokens or 0,
                endsIn = 0,
                weeklyReset = 0,
            }
        end
    end
    
    local displayName = seasonData.name
    if displayName == "Unknown" or displayName == "Unknown Season" then
        displayName = "Season " .. (seasonData.id or 1)
    end
    
    tooltip:AddLine(displayName, 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)
    
    -- Weekly progress
    tooltip:AddLine(" ")
    tooltip:AddLine("|cff32c4ffWeekly Progress|r")
    
    -- Tokens bar
    DCInfoBar:AddTooltipProgressBar(tooltip, 
        seasonData.weeklyTokens, 
        seasonData.weeklyCap, 
        "Tokens")
    
    -- Essence bar
    DCInfoBar:AddTooltipProgressBar(tooltip,
        seasonData.weeklyEssence,
        seasonData.essenceCap,
        "Essence")
    
    -- Total this season
    if seasonData.totalTokens and seasonData.totalTokens > 0 then
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("Total Tokens:", DCInfoBar:FormatNumber(seasonData.totalTokens), 
            0.7, 0.7, 0.7, 1, 1, 1)
    end
    
    -- Time info
    if seasonData.endsIn and seasonData.endsIn > 0 then
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("Season Ends:", DCInfoBar:FormatTimeShort(seasonData.endsIn),
            0.7, 0.7, 0.7, 1, 0.82, 0)
    end
    
    if seasonData.weeklyReset and seasonData.weeklyReset > 0 then
        tooltip:AddDoubleLine("Weekly Reset:", DCInfoBar:FormatTimeShort(seasonData.weeklyReset),
            0.7, 0.7, 0.7, 0.5, 1, 0.5)
    end
end

function SeasonPlugin:OnClick(button)
    if button == "LeftButton" then
        -- Open DC-Welcome progress panel if available
        if DCWelcome and DCWelcome.ShowProgress then
            DCWelcome:ShowProgress()
        elseif DCWelcome and DCWelcome.Toggle then
            DCWelcome:Toggle()
        elseif DC_Welcome_Frame and DC_Welcome_Frame.Show then
            DC_Welcome_Frame:Show()
        elseif DCSeasons and DCSeasons.Toggle then
            -- Fallback to seasons panel
            DCSeasons:Toggle()
        else
            -- Request progress data and show in chat
            local DC = rawget(_G, "DCAddonProtocol")
            if DC then
                DC:Request("WELC", 0x06, {})  -- CMSG_GET_PROGRESS
                DCInfoBar:Print("Requested progress data from server...")
            else
                DCInfoBar:Print("Progress panel not available")
            end
        end
    elseif button == "RightButton" then
        -- Open leaderboard
        if DCLeaderboards and DCLeaderboards.Show then
            DCLeaderboards:Show("seasonal")
        else
            DCInfoBar:Print("Leaderboards addon not loaded")
        end
    end
end

function SeasonPlugin:OnCreateOptions(parent, yOffset)
    local showTokensCB = DCInfoBar:CreateCheckbox(parent, "Show tokens in bar", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showTokens", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "showTokens") ~= false)
    
    return yOffset - 30
end

-- Register plugin
DCInfoBar:RegisterPlugin(SeasonPlugin)
