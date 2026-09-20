--[[
    DC-InfoBar Season Plugin
    Shows current season, tokens earned, and progress

    Data Source: DCAddonProtocol SEAS module. Handlers and the initial requests
    live in Core.lua (SetupServerCommunication / RequestServerData).
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local function GetItemCountSafe(itemId)
    itemId = tonumber(itemId) or 0
    if itemId <= 0 or type(GetItemCount) ~= "function" then
        return 0
    end
    local ok, count = pcall(GetItemCount, itemId, true)
    return (ok and tonumber(count)) or 0
end

local SeasonPlugin = {
    id = "DCInfoBar_Season",
    name = "Season",
    category = "server",
    type = "combo",
    side = "left",
    priority = 10,
    icon = "Interface\\Icons\\Achievement_Arena_2v2_1",
    updateInterval = 5.0,

    leftClickHint = "Open Progress panel",
    rightClickHint = "View season leaderboard",
}

-- Weekly progress lives in the server DB, so it needs a round-trip. Only ask
-- when the season currency in the bags actually changed (a token or essence
-- was gained/spent), not on every bag or loot event.
function SeasonPlugin:CheckCurrencyChanged()
    local season = DCInfoBar.serverData.season
    local tokens = GetItemCountSafe(season.tokenId)
    local essence = GetItemCountSafe(season.essenceId)

    if tokens == self._lastTokenCount and essence == self._lastEssenceCount then
        return
    end

    local firstSample = (self._lastTokenCount == nil)
    self._lastTokenCount = tokens
    self._lastEssenceCount = essence
    if firstSample or not season._progressReceived then
        return
    end

    local now = GetTime()
    if self._lastProgressRequestAt and (now - self._lastProgressRequestAt) < 2 then
        -- Throttled: re-check once the window has passed so the last change isn't lost.
        if not self._recheckQueued then
            self._recheckQueued = true
            DCInfoBar:After(2, function()
                SeasonPlugin._recheckQueued = false
                SeasonPlugin._lastTokenCount = nil
                SeasonPlugin:CheckCurrencyChanged()
                DCInfoBar:RequestSeasonProgress()
            end)
        end
        return
    end
    self._lastProgressRequestAt = now
    DCInfoBar:RequestSeasonProgress()
end

function SeasonPlugin:OnActivate()
    if self._bagWatchFrame then
        return
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("BAG_UPDATE")
    f:SetScript("OnEvent", function()
        -- BAG_UPDATE fires once per bag in bursts; batch into one check.
        if SeasonPlugin._checkQueued then
            return
        end
        SeasonPlugin._checkQueued = true
        DCInfoBar:After(0.5, function()
            SeasonPlugin._checkQueued = false
            SeasonPlugin:CheckCurrencyChanged()
        end)
    end)
    self._bagWatchFrame = f
end

function SeasonPlugin:OnDeactivate()
    if self._bagWatchFrame then
        self._bagWatchFrame:UnregisterAllEvents()
        self._bagWatchFrame = nil
    end
end

local function GetDisplaySeason()
    local season = DCInfoBar.serverData.season
    if (season.id or 0) > 0 then
        return season
    end

    -- Fallback: DC-Welcome may already know the season before our reply lands.
    local welcome = rawget(_G, "DCWelcome")
    local D = welcome and welcome.Seasons and welcome.Seasons.Data
    if D and D._loaded and tonumber(D.seasonNumber) and tonumber(D.seasonNumber) > 0 then
        return {
            id = tonumber(D.seasonNumber),
            name = D.seasonName or "Unknown",
            weeklyTokens = D.weeklyTokens or 0,
            weeklyCap = D.weeklyTokenCap or 0,
            weeklyEssence = D.weeklyEssence or 0,
            essenceCap = D.weeklyEssenceCap or 0,
            totalTokens = D.tokens or 0,
            endsIn = 0,
            weeklyReset = 0,
        }
    end
    return nil
end

local function DisplayName(season)
    local name = season.name
    if not name or name == "Unknown" or name == "Unknown Season" then
        return "Season " .. tostring(season.id)
    end
    return name
end

function SeasonPlugin:OnUpdate(elapsed)
    local season = GetDisplaySeason()
    if not season then
        return "", "Season"
    end

    if DCInfoBar:GetPluginSetting(self.id, "showTokens") ~= false then
        local cap = tonumber(season.weeklyCap) or 0
        local tokenText = tostring(season.weeklyTokens or 0)
        if cap > 0 then
            tokenText = tokenText .. "/" .. cap
        end
        return "S" .. season.id .. ":", tokenText
    end

    return "", "S" .. season.id .. ": " .. DisplayName(season)
end

function SeasonPlugin:OnServerData(data)
    self._elapsed = 999  -- Force immediate update
end

function SeasonPlugin:OnTooltip(tooltip)
    local season = GetDisplaySeason()
    if not season then
        tooltip:AddLine("Waiting for season data...", 0.7, 0.7, 0.7)
        return
    end

    tooltip:AddLine(DisplayName(season), 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)

    tooltip:AddLine(" ")
    tooltip:AddLine("|cff32c4ffWeekly Progress|r")
    DCInfoBar:AddTooltipProgressBar(tooltip, season.weeklyTokens, season.weeklyCap, "Tokens")
    DCInfoBar:AddTooltipProgressBar(tooltip, season.weeklyEssence, season.essenceCap, "Essence")

    if (season.totalTokens or 0) > 0 then
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("Tokens in bags:", DCInfoBar:FormatNumber(season.totalTokens),
            0.7, 0.7, 0.7, 1, 1, 1)
    end

    if (season.endsIn or 0) > 0 or (season.weeklyReset or 0) > 0 then
        tooltip:AddLine(" ")
    end
    if (season.endsIn or 0) > 0 then
        tooltip:AddDoubleLine("Season Ends:", DCInfoBar:FormatTimeShort(season.endsIn),
            0.7, 0.7, 0.7, 1, 0.82, 0)
    end
    if (season.weeklyReset or 0) > 0 then
        tooltip:AddDoubleLine("Weekly Reset:", DCInfoBar:FormatTimeShort(season.weeklyReset),
            0.7, 0.7, 0.7, 0.5, 1, 0.5)
    end
end

function SeasonPlugin:OnClick(button)
    if button == "LeftButton" then
        local welcome = rawget(_G, "DCWelcome")
        if welcome and welcome.ShowWelcomeTab then
            welcome:ShowWelcomeTab("progress")
        else
            local proto = DCInfoBar:GetProtocol()
            if proto then
                proto:Request("WELC", 0x06, {})  -- CMSG_GET_PROGRESS
                DCInfoBar:Print("Requested progress data from server...")
            else
                DCInfoBar:Print("Progress panel not available")
            end
        end
    elseif button == "RightButton" then
        local leaderboards = rawget(_G, "DCLeaderboards")
        if leaderboards and leaderboards.Show then
            leaderboards:Show("seasons")
        else
            DCInfoBar:Print("Leaderboards addon not loaded")
        end
    end
end

function SeasonPlugin:OnCreateOptions(parent, yOffset)
    DCInfoBar:CreateCheckbox(parent, "Show tokens in bar", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showTokens", checked)
        self._elapsed = 999
    end, DCInfoBar:GetPluginSetting(self.id, "showTokens") ~= false)

    return yOffset - 30
end

DCInfoBar:RegisterPlugin(SeasonPlugin)
