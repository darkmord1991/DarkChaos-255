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
    
    leftClickHint = "Open Seasons panel",
    rightClickHint = "View season leaderboard",
    
    -- Cached display data
    _displayText = "Season",
    _seasonName = "Unknown",
    _seasonId = 0,
}

function SeasonPlugin:OnActivate()
    -- Request initial data
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("SEAS", DC.Opcode.Season.CMSG_GET_CURRENT, {})
    end
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
            return "", "S" .. seasonData.id .. ": " .. seasonData.name
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
    
    tooltip:AddLine("Season " .. seasonData.id .. ": " .. seasonData.name, 1, 0.82, 0)
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
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("Total Tokens:", DCInfoBar:FormatNumber(seasonData.totalTokens), 
        0.7, 0.7, 0.7, 1, 1, 1)
    
    -- Time info
    if seasonData.endsIn > 0 then
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("Season Ends:", DCInfoBar:FormatTimeShort(seasonData.endsIn),
            0.7, 0.7, 0.7, 1, 0.82, 0)
    end
    
    if seasonData.weeklyReset > 0 then
        tooltip:AddDoubleLine("Weekly Reset:", DCInfoBar:FormatTimeShort(seasonData.weeklyReset),
            0.7, 0.7, 0.7, 0.5, 1, 0.5)
    end
end

function SeasonPlugin:OnClick(button)
    if button == "LeftButton" then
        -- Open DC-Seasons panel if available
        if DCSeasons and DCSeasons.Toggle then
            DCSeasons:Toggle()
        else
            DCInfoBar:Print("DC-Seasons addon not loaded")
        end
    elseif button == "RightButton" then
        -- Open leaderboard
        if DCLeaderboards and DCLeaderboards.Show then
            DCLeaderboards:Show("seasonal")
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
