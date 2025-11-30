--[[
    DC-Seasons - Client Addon (AIO + DCAddonProtocol)
    DarkChaos Seasonal Reward System UI
    
    Displays reward notifications and seasonal progress tracking
    Supports both AIO and DCAddonProtocol for server communication
    
    Author: DarkChaos Development Team
    Date: November 28, 2025
]]--

local ADDON_NAME = "DC-Seasons"
local DCSeasons = {}

-- DCAddonProtocol integration (will be re-checked on PLAYER_LOGIN)
local DC = rawget(_G, "DCAddonProtocol")
DCSeasons.useDCProtocol = (DC ~= nil)
DCSeasons._handlersRegistered = false

local DEFAULT_SETTINGS = {
    autoShowTracker = true,
    enableSounds = true
}

local function ApplyDefaultSettings()
    DCSeasons_Settings = DCSeasons_Settings or {}
    for key, value in pairs(DEFAULT_SETTINGS) do
        if DCSeasons_Settings[key] == nil then
            DCSeasons_Settings[key] = value
        end
    end
end

ApplyDefaultSettings()

function DCSeasons:GetSetting(key)
    if not key then return nil end
    return DCSeasons_Settings and DCSeasons_Settings[key]
end

function DCSeasons:SetSetting(key, value)
    if not key then return end
    ApplyDefaultSettings()
    DCSeasons_Settings[key] = value and true or false
end

-- Configuration
DCSeasons.Config = {
    FRAME_WIDTH = 300,
    FRAME_HEIGHT = 150,
    FADE_DURATION = 3.0,
    SLIDE_DURATION = 0.5
}

-- Frame references
DCSeasons.Frames = {
    rewardPopup = nil,
    progressTracker = nil
}

-- Data cache (defaults will be overwritten by server data)
DCSeasons.Data = {
    seasonNumber = nil,  -- nil = not yet loaded from server
    seasonName = nil,
    tokens = 0,
    essence = 0,
    weeklyTokens = 0,
    weeklyEssence = 0,
    weeklyTokenCap = 1000,
    weeklyEssenceCap = 1000,
    quests = 0,
    worldBosses = 0,
    dungeonBosses = 0,
    _loaded = false  -- Flag to indicate server data received
}

local function ScheduleAfter(delay, callback)
    if type(callback) ~= "function" or (delay or 0) < 0 then
        return
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, callback)
        return
    end
    local ticker = CreateFrame("Frame")
    ticker.elapsed = 0
    ticker:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            pcall(callback)
        end
    end)
end

-- =====================================================================
-- REWARD POPUP FRAME
-- =====================================================================

function DCSeasons:CreateRewardPopup()
    if self.Frames.rewardPopup then
        return self.Frames.rewardPopup
    end
    
    local frame = CreateFrame("Frame", "SeasonalRewardPopup", UIParent)
    frame:SetSize(self.Config.FRAME_WIDTH, self.Config.FRAME_HEIGHT)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -200)
    frame:SetFrameStrata("HIGH")
    frame:SetAlpha(0)
    frame:Hide()
    
    -- Background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0, 0, 0, 0.8)
    
    -- Border
    local border = frame:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Border")
    border:SetTexCoord(0.3, 0.7, 0.3, 0.7)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -10)
    title:SetText("|cff00ff00Seasonal Reward!|r")
    frame.title = title
    
    -- Token icon and amount
    local tokenIcon = frame:CreateTexture(nil, "OVERLAY")
    tokenIcon:SetSize(32, 32)
    tokenIcon:SetPoint("LEFT", frame, "LEFT", 20, 10)
    tokenIcon:SetTexture("Interface\\Icons\\INV_Misc_Token_ArgentCrusade")  -- Token icon
    frame.tokenIcon = tokenIcon
    
    local tokenText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    tokenText:SetPoint("LEFT", tokenIcon, "RIGHT", 10, 0)
    tokenText:SetText("|cffffd700+0 Tokens|r")
    frame.tokenText = tokenText
    
    -- Essence icon and amount
    local essenceIcon = frame:CreateTexture(nil, "OVERLAY")
    essenceIcon:SetSize(32, 32)
    essenceIcon:SetPoint("LEFT", frame, "LEFT", 20, -25)
    essenceIcon:SetTexture("Interface\\Icons\\INV_Misc_Token_Darkmoon")  -- Essence icon
    frame.essenceIcon = essenceIcon
    
    local essenceText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    essenceText:SetPoint("LEFT", essenceIcon, "RIGHT", 10, 0)
    essenceText:SetText("|cff00ffff+0 Essence|r")
    frame.essenceText = essenceText
    
    -- Source label
    local sourceText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sourceText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 15)
    sourceText:SetText("From: Unknown")
    frame.sourceText = sourceText
    
    self.Frames.rewardPopup = frame
    return frame
end

function DCSeasons:ShowRewardPopup(tokens, essence, source)
    local frame = self:CreateRewardPopup()
    
    -- Update text
    if tokens > 0 then
        frame.tokenText:SetText(string.format("|cffffd700+%d Tokens|r", tokens))
        frame.tokenIcon:Show()
    else
        frame.tokenText:SetText("")
        frame.tokenIcon:Hide()
    end
    
    if essence > 0 then
        frame.essenceText:SetText(string.format("|cff00ffff+%d Essence|r", essence))
        frame.essenceIcon:Show()
    else
        frame.essenceText:SetText("")
        frame.essenceIcon:Hide()
    end
    
    frame.sourceText:SetText("From: " .. (source or "Unknown"))
    
    -- Animate popup
    frame:Show()
    UIFrameFadeIn(frame, self.Config.SLIDE_DURATION, 0, 1)
    
    -- Auto-hide after delay
    ScheduleAfter(self.Config.FADE_DURATION + self.Config.SLIDE_DURATION, function()
        UIFrameFadeOut(frame, self.Config.SLIDE_DURATION, 1, 0)
        ScheduleAfter(self.Config.SLIDE_DURATION, function()
            frame:Hide()
        end)
    end)
    
    if DCSeasons:GetSetting("enableSounds") then
        PlaySound("LOOTWINDOWCOINSOUND")
    end
end

-- =====================================================================
-- PROGRESS TRACKER FRAME
-- =====================================================================

function DCSeasons:CreateProgressTracker()
    if self.Frames.progressTracker then
        return self.Frames.progressTracker
    end
    
    local frame = CreateFrame("Frame", "SeasonalProgressTracker", UIParent)
    frame:SetSize(250, 115)  -- Compact height
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -150)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    -- Background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    bg:SetVertexColor(0, 0, 0, 0.85)
    
    -- Season Title (number and name)
    local seasonTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    seasonTitle:SetPoint("TOP", frame, "TOP", 0, -5)
    seasonTitle:SetText("|cffFFD700Season 1|r")
    frame.seasonTitle = seasonTitle
    
    -- Season Name subtitle
    local seasonName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    seasonName:SetPoint("TOP", seasonTitle, "BOTTOM", 0, -2)
    seasonName:SetText("|cff00ff00Season of Discovery|r")
    frame.seasonName = seasonName
    
    -- Token progress bar
    local tokenBar = CreateFrame("StatusBar", nil, frame)
    tokenBar:SetSize(220, 18)
    tokenBar:SetPoint("TOP", seasonName, "BOTTOM", 0, -8)
    tokenBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    tokenBar:SetStatusBarColor(1, 0.82, 0)  -- Gold
    tokenBar:SetMinMaxValues(0, 1)
    tokenBar:SetValue(0)
    frame.tokenBar = tokenBar
    
    local tokenBarBG = tokenBar:CreateTexture(nil, "BACKGROUND")
    tokenBarBG:SetAllPoints()
    tokenBarBG:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    tokenBarBG:SetVertexColor(0.2, 0.2, 0.2)
    
    local tokenBarText = tokenBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tokenBarText:SetPoint("CENTER", tokenBar, "CENTER")
    tokenBarText:SetText("0 / 5000 Tokens")
    frame.tokenBarText = tokenBarText
    
    -- Essence progress bar
    local essenceBar = CreateFrame("StatusBar", nil, frame)
    essenceBar:SetSize(220, 18)
    essenceBar:SetPoint("TOP", tokenBar, "BOTTOM", 0, -5)
    essenceBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    essenceBar:SetStatusBarColor(0, 1, 1)  -- Cyan
    essenceBar:SetMinMaxValues(0, 1)
    essenceBar:SetValue(0)
    frame.essenceBar = essenceBar
    
    local essenceBarBG = essenceBar:CreateTexture(nil, "BACKGROUND")
    essenceBarBG:SetAllPoints()
    essenceBarBG:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    essenceBarBG:SetVertexColor(0.2, 0.2, 0.2)
    
    local essenceBarText = essenceBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    essenceBarText:SetPoint("CENTER", essenceBar, "CENTER")
    essenceBarText:SetText("0 / 2500 Essence")
    frame.essenceBarText = essenceBarText
    
    -- Stats text
    local statsText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("TOP", essenceBar, "BOTTOM", 0, -5)
    statsText:SetText("Quests: 0 | Bosses: 0")
    frame.statsText = statsText
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    frame:Hide()
    self.Frames.progressTracker = frame
    return frame
end

function DCSeasons:UpdateProgressTracker()
    local frame = self.Frames.progressTracker
    if not frame then return end
    
    -- Check if we have server data yet
    if not self.Data._loaded then
        -- Show loading state
        if frame.seasonTitle then
            frame.seasonTitle:SetText("|cffFFD700Season...|r")
        end
        if frame.seasonName then
            frame.seasonName:SetText("|cff888888Loading...|r")
        end
        frame.tokenBar:SetValue(0)
        frame.tokenBarText:SetText("Loading...")
        frame.essenceBar:SetValue(0)
        frame.essenceBarText:SetText("Loading...")
        frame.statsText:SetText("Waiting for server data...")
        return
    end
    
    -- Update season title and name
    if frame.seasonTitle then
        frame.seasonTitle:SetText(string.format("|cffFFD700Season %d|r", self.Data.seasonNumber or 1))
    end
    if frame.seasonName then
        frame.seasonName:SetText(string.format("|cff00ff00%s|r", self.Data.seasonName or ""))
    end
    
    -- Update token bar
    local tokenPercent = self.Data.weeklyTokens / math.max(self.Data.weeklyTokenCap, 1)
    frame.tokenBar:SetValue(tokenPercent)
    frame.tokenBarText:SetText(string.format("%d / %d Tokens", 
        self.Data.weeklyTokens, self.Data.weeklyTokenCap))
    
    -- Update essence bar
    local essencePercent = self.Data.weeklyEssence / math.max(self.Data.weeklyEssenceCap, 1)
    frame.essenceBar:SetValue(essencePercent)
    frame.essenceBarText:SetText(string.format("%d / %d Essence", 
        self.Data.weeklyEssence, self.Data.weeklyEssenceCap))
    
    -- Update stats
    frame.statsText:SetText(string.format("Quests: %d | Bosses: %d", 
        self.Data.quests, self.Data.worldBosses + self.Data.dungeonBosses))
end

function DCSeasons:ToggleProgressTracker()
    local frame = self:CreateProgressTracker()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        self:UpdateProgressTracker()
    end
end

-- =====================================================================
-- SLASH COMMANDS
-- =====================================================================

SLASH_DCSEASONS1 = "/seasonal"
SLASH_DCSEASONS2 = "/season"
SLASH_DCSEASONS3 = "/dcseasons"

SlashCmdList["DCSEASONS"] = function(msg)
    local cmd = string.lower(msg or "")
    
    if cmd == "show" or cmd == "toggle" or cmd == "" then
        DCSeasons:ToggleProgressTracker()
    elseif cmd == "hide" then
        if DCSeasons.Frames.progressTracker then
            DCSeasons.Frames.progressTracker:Hide()
        end
    elseif cmd == "test" then
        -- Test reward popup
        DCSeasons:ShowRewardPopup(150, 75, "Test Quest")
        DCSeasons.Data.weeklyTokens = DCSeasons.Data.weeklyTokens + 150
        DCSeasons.Data.weeklyEssence = DCSeasons.Data.weeklyEssence + 75
        DCSeasons:UpdateProgressTracker()
    elseif cmd == "refresh" or cmd == "sync" then
        -- Request data from server via DC protocol
        if DCSeasons.RequestSeasonData then
            DCSeasons.RequestSeasonData()
            print("|cff00ff00[DC-Seasons]|r Requesting season data from server...")
        else
            print("|cffff0000[DC-Seasons]|r DC Protocol not available")
        end
    elseif cmd == "rewards" then
        -- Request rewards list
        if DCSeasons.RequestRewards then
            DCSeasons.RequestRewards()
            print("|cff00ff00[DC-Seasons]|r Requesting rewards...")
        else
            print("|cffff0000[DC-Seasons]|r DC Protocol not available")
        end
    elseif cmd == "leaderboard" or cmd == "lb" then
        -- Request leaderboard
        if DCSeasons.RequestLeaderboard then
            DCSeasons.RequestLeaderboard()
            print("|cff00ff00[DC-Seasons]|r Requesting leaderboard...")
        else
            print("|cffff0000[DC-Seasons]|r DC Protocol not available")
        end
    elseif cmd == "challenges" or cmd == "daily" then
        -- Request challenges
        if DCSeasons.RequestChallenges then
            DCSeasons.RequestChallenges()
            print("|cff00ff00[DC-Seasons]|r Requesting challenges...")
        else
            print("|cffff0000[DC-Seasons]|r DC Protocol not available")
        end
    elseif cmd:match("^claim%s+%d+$") then
        -- Claim a specific reward by ID
        local rewardId = tonumber(cmd:match("%d+"))
        if DCSeasons.ClaimReward and rewardId then
            DCSeasons.ClaimReward(rewardId)
            print("|cff00ff00[DC-Seasons]|r Claiming reward " .. rewardId .. "...")
        end
    elseif cmd == "protocol" or cmd == "status" then
        -- Show protocol status
        local dcAvail = rawget(_G, "DCAddonProtocol") and "YES" or "NO"
        local aioAvail = rawget(_G, "AIO") and "YES" or "NO"
        print("|cff00ff00[DC-Seasons]|r Protocol status:")
        print("  DCAddonProtocol: " .. dcAvail)
        print("  AIO: " .. aioAvail)
        print("  Season: " .. (DCSeasons.Data.seasonNumber or "?") .. " - " .. (DCSeasons.Data.seasonName or "Unknown"))
        print("  Tokens: " .. (DCSeasons.Data.weeklyTokens or 0) .. "/" .. (DCSeasons.Data.weeklyTokenCap or 5000))
        print("  Essence: " .. (DCSeasons.Data.weeklyEssence or 0) .. "/" .. (DCSeasons.Data.weeklyEssenceCap or 2500))
    elseif cmd == "testconn" then
        -- Test DC protocol connection
        if DCSeasons.TestConnection then
            DCSeasons.TestConnection()
        else
            print("|cffff0000[DC-Seasons]|r DC Protocol not available")
        end
    elseif cmd == "options" or cmd == "config" or cmd == "settings" then
        if InterfaceOptionsFrame_OpenToCategory and DCSeasons.OptionsPanel then
            InterfaceOptionsFrame_OpenToCategory(DCSeasons.OptionsPanel)
            InterfaceOptionsFrame_OpenToCategory(DCSeasons.OptionsPanel)
        end
    else
        print("|cff00ff00[Seasonal]|r Commands:")
        print("  /seasonal show - Toggle progress tracker")
        print("  /seasonal hide - Hide progress tracker")
        print("  /seasonal refresh - Request data from server")
        print("  /seasonal rewards - Show available rewards")
        print("  /seasonal leaderboard - Show leaderboard")
        print("  /seasonal challenges - Show daily/weekly challenges")
        print("  /seasonal claim <id> - Claim a reward by ID")
        print("  /seasonal status - Show protocol status")
        print("  /seasonal testconn - Test DC protocol connection")
        print("  /seasonal test - Test reward popup")
        print("  /seasonal options - Open the addon settings panel")
    end
end

-- =====================================================================
-- AIO MESSAGE HANDLERS
-- =====================================================================

if AIO and AIO.AddHandlers then
    local SeasonalAIO = AIO.AddHandlers("DC_Seasons", {})
    
    -- Handle reward notification from server
    function SeasonalAIO.OnRewardEarned(player, tokens, essence, source)
        DCSeasons:ShowRewardPopup(tokens, essence, source)
        DCSeasons.Data.weeklyTokens = DCSeasons.Data.weeklyTokens + tokens
        DCSeasons.Data.weeklyEssence = DCSeasons.Data.weeklyEssence + essence
        DCSeasons:UpdateProgressTracker()
    end
    
    -- Handle stats update from server
    function SeasonalAIO.UpdateStats(player, stats)
        DCSeasons.Data.seasonNumber = stats.seasonNumber or 1
        DCSeasons.Data.seasonName = stats.seasonName or "Season of Discovery"
        DCSeasons.Data.weeklyTokens = stats.weeklyTokens or 0
        DCSeasons.Data.weeklyEssence = stats.weeklyEssence or 0
        DCSeasons.Data.weeklyTokenCap = stats.weeklyTokenCap or 5000
        DCSeasons.Data.weeklyEssenceCap = stats.weeklyEssenceCap or 2500
        DCSeasons.Data.quests = stats.quests or 0
        DCSeasons.Data.worldBosses = stats.worldBosses or 0
        DCSeasons.Data.dungeonBosses = stats.dungeonBosses or 0
        DCSeasons:UpdateProgressTracker()
    end

    function SeasonalAIO.OnWeeklyReset(player)
        DCSeasons.Data.weeklyTokens = 0
        DCSeasons.Data.weeklyEssence = 0
        DCSeasons.Data.quests = 0
        DCSeasons.Data.worldBosses = 0
        DCSeasons.Data.dungeonBosses = 0
        DCSeasons:UpdateProgressTracker()
        print("|cff00ff00[DC-Seasons]|r Weekly stats have been reset.")
    end

    function SeasonalAIO.OnWeeklyChest(player, chestData)
        -- TODO: Implement chest UI
        print("|cff00ff00[DC-Seasons]|r Weekly Chest is available!")
    end

    function SeasonalAIO.OnInitialData(player, data)
        -- Initial sync
    end
end

-- =====================================================================
-- DC ADDON PROTOCOL HANDLERS (lightweight alternative to AIO)
-- =====================================================================

-- Function to register DC handlers (called from PLAYER_LOGIN when DC is available)
function DCSeasons:RegisterDCHandlers()
    -- Re-check DC availability
    DC = rawget(_G, "DCAddonProtocol")
    if not DC then
        print("|cffff6600[DC-Seasons]|r DCAddonProtocol not available, using AIO fallback")
        return false
    end
    
    -- Prevent double registration
    if DCSeasons._handlersRegistered then
        return true
    end
    DCSeasons._handlersRegistered = true
    DCSeasons.useDCProtocol = true
    
    print("|cff00ff00[DC-Seasons]|r Registering DCAddonProtocol handlers...")
    
    -- SMSG_CURRENT_SEASON (0x10) - Season info response
    DC:RegisterHandler("SEAS", 0x10, function(...)
        local args = {...}
        
        if type(args[1]) == "table" then
            -- JSON format
            local json = args[1]
            DCSeasons.Data.seasonNumber = json.seasonId or json.id or 1
            DCSeasons.Data.seasonName = json.name or json.seasonName or "Unknown Season"
            DCSeasons.Data.startTime = json.startTime
            DCSeasons.Data.endTime = json.endTime
            DCSeasons.Data.daysRemaining = json.daysRemaining
            if json.tokenCap then DCSeasons.Data.weeklyTokenCap = json.tokenCap end
            if json.essenceCap then DCSeasons.Data.weeklyEssenceCap = json.essenceCap end
        else
            -- Pipe-delimited format
            DCSeasons.Data.seasonNumber = tonumber(args[1]) or 1
            DCSeasons.Data.seasonName = args[2] or "Unknown Season"
            DCSeasons.Data.startTime = tonumber(args[3])
            DCSeasons.Data.endTime = tonumber(args[4])
            DCSeasons.Data.daysRemaining = tonumber(args[5])
        end
        DCSeasons.Data._loaded = true  -- Mark data as received from server
        DCSeasons:UpdateProgressTracker()
        print("|cff00ff00[DC-Seasons]|r Season info received: " .. DCSeasons.Data.seasonName)
    end)
    
    -- SMSG_PROGRESS (0x12) - Progress update
    DC:RegisterHandler("SEAS", 0x12, function(...)
        local args = {...}
        
        if type(args[1]) == "table" then
            -- JSON format
            local json = args[1]
            DCSeasons.Data.seasonLevel = json.level or json.seasonLevel or 1
            DCSeasons.Data.weeklyTokens = json.currentXP or json.tokens or 0
            DCSeasons.Data.weeklyTokenCap = json.xpToNextLevel or json.tokenCap or 1000
            DCSeasons.Data.weeklyEssence = json.essence or 0
            DCSeasons.Data.weeklyEssenceCap = json.essenceCap or 1000
            DCSeasons.Data.totalPoints = json.totalPoints or 0
            DCSeasons.Data.rank = json.rank
            DCSeasons.Data.tier = json.tier
            DCSeasons.Data.quests = json.quests or 0
            DCSeasons.Data.worldBosses = json.worldBosses or 0
            DCSeasons.Data.dungeonBosses = json.dungeonBosses or 0
        else
            -- Pipe-delimited format
            DCSeasons.Data.seasonLevel = tonumber(args[2]) or 1
            DCSeasons.Data.weeklyTokens = tonumber(args[3]) or 0
            DCSeasons.Data.weeklyTokenCap = tonumber(args[4]) or 1000
            DCSeasons.Data.totalPoints = tonumber(args[5]) or 0
            DCSeasons.Data.rank = args[6]
            DCSeasons.Data.tier = args[7]
        end
        DCSeasons.Data._loaded = true  -- Mark data as received from server
        DCSeasons:UpdateProgressTracker()
    end)
    
    -- SMSG_REWARDS (0x11) - Rewards list
    DC:RegisterHandler("SEAS", 0x11, function(...)
        local args = {...}
        
        if type(args[1]) == "table" then
            -- JSON format
            local json = args[1]
            DCSeasons.Data.rewards = json.rewards or {}
            DCSeasons.Data.rewardCount = json.count or (json.rewards and #json.rewards or 0)
            
            -- Display rewards if we have them
            if json.rewards and #json.rewards > 0 then
                print("|cff00ff00[DC-Seasons]|r Available rewards:")
                for i, reward in ipairs(json.rewards) do
                    if type(reward) == "table" then
                        local name = reward.name or ("Reward " .. (reward.id or i))
                        local tier = reward.tier and (" (Tier " .. reward.tier .. ")") or ""
                        local claimed = reward.claimed and " |cff888888[Claimed]|r" or ""
                        print("  " .. i .. ". " .. name .. tier .. claimed)
                    end
                end
            end
        else
            -- Pipe-delimited format
            DCSeasons.Data.rewardCount = tonumber(args[2]) or 0
        end
    end)
    
    -- SMSG_SEASON_END (0x13) - Season ended notification
    DC:RegisterHandler("SEAS", 0x13, function(...)
        local args = {...}
        local seasonId, finalLevel, finalRank, bonusReward
        
        if type(args[1]) == "table" then
            local json = args[1]
            seasonId = json.seasonId
            finalLevel = json.finalLevel
            finalRank = json.finalRank
            bonusReward = json.bonusRewardItemId
        else
            seasonId = tonumber(args[1])
            finalLevel = tonumber(args[2])
            finalRank = args[3]
            bonusReward = tonumber(args[4])
        end
        
        print("|cff00ff00[DC-Seasons]|r Season " .. (seasonId or "?") .. " has ended!")
        print("|cff00ff00[DC-Seasons]|r Final Level: " .. (finalLevel or "?"))
        print("|cff00ff00[DC-Seasons]|r Final Rank: " .. (finalRank or "?"))
        if bonusReward and bonusReward > 0 then
            print("|cff00ff00[DC-Seasons]|r Bonus reward granted!")
        end
    end)
    
    -- SMSG_REWARD_CLAIMED (0x14) - Reward claim result (custom opcode)
    DC:RegisterHandler("SEAS", 0x14, function(...)
        local args = {...}
        
        if type(args[1]) == "table" then
            local json = args[1]
            if json.success then
                print("|cff00ff00[DC-Seasons]|r Reward claimed: " .. (json.rewardName or ""))
                -- Refresh progress
                DCSeasons.RequestSeasonData()
            else
                print("|cffff0000[DC-Seasons]|r Failed to claim reward: " .. (json.error or "Unknown error"))
            end
        else
            local success = (args[1] == "1" or args[1] == 1)
            local rewardId = args[2]
            local error = args[3]
            if success then
                print("|cff00ff00[DC-Seasons]|r Reward " .. (rewardId or "?") .. " claimed!")
            else
                print("|cffff0000[DC-Seasons]|r Failed: " .. (error or "Unknown error"))
            end
        end
    end)
    
    -- SMSG_LEADERBOARD (0x15) - Leaderboard data (custom opcode)
    DC:RegisterHandler("SEAS", 0x15, function(...)
        local args = {...}
        
        if type(args[1]) == "table" then
            local json = args[1]
            local leaderboard = json.entries or json.leaderboard or {}
            print("|cff00ff00[DC-Seasons]|r Leaderboard (Season " .. (json.seasonId or "?") .. "):")
            for i, entry in ipairs(leaderboard) do
                if type(entry) == "table" then
                    local name = entry.name or entry.playerName or "Unknown"
                    local points = entry.points or entry.score or 0
                    local rank = entry.rank or i
                    print(string.format("  %d. %s - %d points", rank, name, points))
                end
            end
            if json.playerRank then
                print("|cff00ff00[DC-Seasons]|r Your rank: " .. json.playerRank)
            end
        end
    end)
    
    -- SMSG_CHALLENGES (0x16) - Weekly/Daily challenges (custom opcode)
    DC:RegisterHandler("SEAS", 0x16, function(...)
        local args = {...}
        
        if type(args[1]) == "table" then
            local json = args[1]
            DCSeasons.Data.challenges = json.challenges or {}
            print("|cff00ff00[DC-Seasons]|r Challenges available:")
            for i, challenge in ipairs(DCSeasons.Data.challenges) do
                if type(challenge) == "table" then
                    local name = challenge.name or ("Challenge " .. i)
                    local progress = challenge.progress or 0
                    local required = challenge.required or 1
                    local reward = challenge.reward or 0
                    local status = (progress >= required) and "|cff00ff00Complete|r" or string.format("%d/%d", progress, required)
                    print(string.format("  %s: %s (+%d tokens)", name, status, reward))
                end
            end
        end
    end)
    
    -- SMSG_REWARD_EARNED (0x17) - Real-time reward notification
    DC:RegisterHandler("SEAS", 0x17, function(...)
        local args = {...}
        local tokens, essence, source
        
        if type(args[1]) == "table" then
            local json = args[1]
            tokens = json.tokens or 0
            essence = json.essence or 0
            source = json.source or json.reason or "Unknown"
        else
            tokens = tonumber(args[1]) or 0
            essence = tonumber(args[2]) or 0
            source = args[3] or "Unknown"
        end
        
        if tokens > 0 or essence > 0 then
            DCSeasons:ShowRewardPopup(tokens, essence, source)
            DCSeasons.Data.weeklyTokens = (DCSeasons.Data.weeklyTokens or 0) + tokens
            DCSeasons.Data.weeklyEssence = (DCSeasons.Data.weeklyEssence or 0) + essence
            DCSeasons:UpdateProgressTracker()
        end
    end)
    
    -- Request functions exposed for external use (JSON format standard)
    DCSeasons.RequestSeasonData = function()
        if DC then
            DC:Request("SEAS", 0x01, {})  -- CMSG_GET_CURRENT
            DC:Request("SEAS", 0x03, {})  -- CMSG_GET_PROGRESS
        end
    end
    
    DCSeasons.RequestRewards = function()
        if DC then
            DC:Request("SEAS", 0x02, {})  -- CMSG_GET_REWARDS
        end
    end
    
    DCSeasons.ClaimReward = function(rewardId)
        if DC then
            DC:Request("SEAS", 0x04, { rewardId = rewardId })  -- CMSG_CLAIM_REWARD
        end
    end
    
    DCSeasons.RequestLeaderboard = function()
        if DC then
            DC:Request("SEAS", 0x05, {})  -- CMSG_GET_LEADERBOARD
        end
    end
    
    DCSeasons.RequestChallenges = function()
        if DC then
            DC:Request("SEAS", 0x06, {})  -- CMSG_GET_CHALLENGES
        end
    end
    
    -- Test all connections
    DCSeasons.TestConnection = function()
        if not DC then
            print("|cffff0000[DC-Seasons]|r DCAddonProtocol not available")
            return
        end
        print("|cff00ff00[DC-Seasons]|r Testing DC Protocol connection (JSON format)...")
        DC:Request("SEAS", 0x01, {})  -- Current season
        DC:Request("SEAS", 0x02, {})  -- Rewards
        DC:Request("SEAS", 0x03, {})  -- Progress
    end
    
    print("|cff00ff00[DC-Seasons]|r DCAddonProtocol v" .. (DC.VERSION or "?") .. " handlers registered")
    return true
end

-- Try to register handlers immediately if DC is available
if DC then
    DCSeasons:RegisterDCHandlers()
end

-- =====================================================================
-- OPTIONS PANEL
-- =====================================================================

local function CreateCheckbox(parent, label, description, anchorTo, offsetY, settingKey)
    local checkbox = CreateFrame("CheckButton", "DCSeasonsOption" .. settingKey, parent, "InterfaceOptionsCheckButtonTemplate")
    local textRegion = checkbox.Text or _G[checkbox:GetName() .. "Text"]
    if not textRegion then
        textRegion = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        textRegion:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    end
    checkbox.Text = textRegion
    checkbox.Text:SetText(label)
    checkbox.tooltipText = description
    checkbox:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, offsetY)
    checkbox:SetScript("OnClick", function(self)
        DCSeasons:SetSetting(settingKey, self:GetChecked())
        if settingKey == "autoShowTracker" and self:GetChecked() then
            DCSeasons:CreateProgressTracker():Show()
            DCSeasons:UpdateProgressTracker()
        end
    end)
    return checkbox
end

local function RefreshOptionsPanel(panel)
    if not panel then return end
    if panel.autoShowCheck then
        panel.autoShowCheck:SetChecked(DCSeasons:GetSetting("autoShowTracker"))
    end
    if panel.soundCheck then
        panel.soundCheck:SetChecked(DCSeasons:GetSetting("enableSounds"))
    end
end

local function BuildOptionsPanel()
    local parentContainer = InterfaceOptionsFramePanelContainer or UIParent
    local panel = CreateFrame("Frame", "DCSeasonsOptionsPanel", parentContainer)
    panel.name = ADDON_NAME
    panel:Hide()
    
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("DC-Seasons")
    panel.title = title
    
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(500)
    desc:SetJustifyH("LEFT")
    desc:SetText("Configure the Seasonal reward UI. All settings are saved per account.")
    panel.desc = desc
    
    panel.autoShowCheck = CreateCheckbox(panel, "Show tracker on login", "Automatically display the progress tracker every time you log in.", desc, -16, "autoShowTracker")
    panel.soundCheck = CreateCheckbox(panel, "Play reward sounds", "Play a coin sound whenever a reward popup is shown.", panel.autoShowCheck, -8, "enableSounds")
    
    panel:SetScript("OnShow", function(self)
        RefreshOptionsPanel(self)
    end)
    panel.default = function()
        for key, value in pairs(DEFAULT_SETTINGS) do
            DCSeasons_Settings[key] = value
        end
        RefreshOptionsPanel(panel)
    end
    panel.refresh = RefreshOptionsPanel
    
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
    return panel
end

local function BuildCommunicationPanel(parentPanel)
    local panel = CreateFrame("Frame", "DCSeasonsCommPanel", InterfaceOptionsFramePanelContainer or UIParent)
    panel.name = "Communication"
    panel.parent = parentPanel.name
    panel:Hide()
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ff00DC-Seasons|r - Communication")
    
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(500)
    desc:SetJustifyH("LEFT")
    desc:SetText("Manage server communication protocols and test connectivity.")
    
    local yPos = -70
    local xPos = 20
    
    -- Protocol Status Section
    local statusHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statusHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    statusHeader:SetText("|cffffd700Protocol Status|r")
    yPos = yPos - 20
    
    -- DCAddonProtocol status
    local dcStatus = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    dcStatus:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos + 10, yPos)
    panel.dcStatus = dcStatus
    yPos = yPos - 18
    
    -- AIO status
    local aioStatus = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    aioStatus:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos + 10, yPos)
    panel.aioStatus = aioStatus
    yPos = yPos - 18
    
    -- Connection status
    local connStatus = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    connStatus:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos + 10, yPos)
    panel.connStatus = connStatus
    yPos = yPos - 18
    
    -- Server version
    local serverVer = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    serverVer:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos + 10, yPos)
    panel.serverVer = serverVer
    yPos = yPos - 30
    
    -- Test Buttons Section
    local testHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    testHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    testHeader:SetText("|cffffd700Test Communication|r")
    yPos = yPos - 25
    
    -- Test Connection button
    local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testBtn:SetWidth(150)
    testBtn:SetHeight(22)
    testBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    testBtn:SetText("Test Connection")
    testBtn:SetScript("OnClick", function()
        if DCSeasons.TestConnection then
            DCSeasons.TestConnection()
        else
            print("|cffff0000[DC-Seasons]|r TestConnection not available")
        end
    end)
    
    -- Request Season Data button
    local reqBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reqBtn:SetWidth(150)
    reqBtn:SetHeight(22)
    reqBtn:SetPoint("LEFT", testBtn, "RIGHT", 10, 0)
    reqBtn:SetText("Request Season")
    reqBtn:SetScript("OnClick", function()
        if DCSeasons.RequestSeasonData then
            DCSeasons.RequestSeasonData()
            print("|cff00ff00[DC-Seasons]|r Season data requested")
        end
    end)
    yPos = yPos - 30
    
    -- Request Rewards button
    local rewardsBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    rewardsBtn:SetWidth(150)
    rewardsBtn:SetHeight(22)
    rewardsBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    rewardsBtn:SetText("Request Rewards")
    rewardsBtn:SetScript("OnClick", function()
        if DCSeasons.RequestRewards then
            DCSeasons.RequestRewards()
            print("|cff00ff00[DC-Seasons]|r Rewards requested")
        end
    end)
    
    -- Request Leaderboard button
    local lbBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    lbBtn:SetWidth(150)
    lbBtn:SetHeight(22)
    lbBtn:SetPoint("LEFT", rewardsBtn, "RIGHT", 10, 0)
    lbBtn:SetText("Leaderboard")
    lbBtn:SetScript("OnClick", function()
        if DCSeasons.RequestLeaderboard then
            DCSeasons.RequestLeaderboard()
            print("|cff00ff00[DC-Seasons]|r Leaderboard requested")
        end
    end)
    yPos = yPos - 30
    
    -- Request Challenges button
    local chalBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    chalBtn:SetWidth(150)
    chalBtn:SetHeight(22)
    chalBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    chalBtn:SetText("Challenges")
    chalBtn:SetScript("OnClick", function()
        if DCSeasons.RequestChallenges then
            DCSeasons.RequestChallenges()
            print("|cff00ff00[DC-Seasons]|r Challenges requested")
        end
    end)
    
    -- Reconnect button
    local reconBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reconBtn:SetWidth(150)
    reconBtn:SetHeight(22)
    reconBtn:SetPoint("LEFT", chalBtn, "RIGHT", 10, 0)
    reconBtn:SetText("Reconnect")
    reconBtn:SetScript("OnClick", function()
        local dcProto = rawget(_G, "DCAddonProtocol")
        if dcProto then
            dcProto._connected = false
            dcProto._handshakeSent = false
            dcProto:Send("CORE", 1, dcProto.VERSION)
            print("|cff00ff00[DC-Seasons]|r Reconnection handshake sent")
        else
            print("|cffff0000[DC-Seasons]|r DC Protocol not available")
        end
    end)
    yPos = yPos - 40
    
    -- Current Data Section
    local dataHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dataHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    dataHeader:SetText("|cffffd700Current Data|r")
    yPos = yPos - 20
    
    local seasonInfo = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    seasonInfo:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos + 10, yPos)
    panel.seasonInfo = seasonInfo
    yPos = yPos - 18
    
    local tokenInfo = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    tokenInfo:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos + 10, yPos)
    panel.tokenInfo = tokenInfo
    yPos = yPos - 18
    
    local essenceInfo = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    essenceInfo:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos + 10, yPos)
    panel.essenceInfo = essenceInfo
    yPos = yPos - 30
    
    -- Info Section
    local infoHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    infoHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    infoHeader:SetText("|cffffd700Information|r")
    yPos = yPos - 20
    
    local infoText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos + 10, yPos)
    infoText:SetWidth(450)
    infoText:SetJustifyH("LEFT")
    infoText:SetText("DC-Seasons uses DCAddonProtocol for efficient server communication.\n" ..
        "AIO is also supported as a fallback for complex data sync.\n\n" ..
        "Slash commands: /seasonal, /season, /dcseasons")
    
    -- Update function
    local function UpdateStatus()
        local dcAvail = rawget(_G, "DCAddonProtocol")
        local aioAvail = rawget(_G, "AIO")
        
        panel.dcStatus:SetText("DCAddonProtocol: " .. (dcAvail and "|cff00ff00Available v" .. (dcAvail.VERSION or "?") .. "|r" or "|cffff0000Not Loaded|r"))
        panel.aioStatus:SetText("AIO: " .. (aioAvail and "|cff00ff00Available|r" or "|cff888888Not Loaded|r"))
        
        if dcAvail then
            panel.connStatus:SetText("Connected: " .. (dcAvail._connected and "|cff00ff00Yes|r" or "|cffff0000No|r"))
            panel.serverVer:SetText("Server Version: " .. (dcAvail._serverVersion or "|cff888888Unknown|r"))
        else
            panel.connStatus:SetText("Connected: |cff888888N/A|r")
            panel.serverVer:SetText("Server Version: |cff888888N/A|r")
        end
        
        panel.seasonInfo:SetText("Season: " .. (DCSeasons.Data.seasonNumber or "?") .. " - " .. (DCSeasons.Data.seasonName or "Unknown"))
        panel.tokenInfo:SetText("Tokens: |cffffd700" .. (DCSeasons.Data.weeklyTokens or 0) .. "|r / " .. (DCSeasons.Data.weeklyTokenCap or 5000))
        panel.essenceInfo:SetText("Essence: |cff00ffff" .. (DCSeasons.Data.weeklyEssence or 0) .. "|r / " .. (DCSeasons.Data.weeklyEssenceCap or 2500))
    end
    
    panel:SetScript("OnShow", UpdateStatus)
    
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
    return panel
end

DCSeasons.OptionsPanel = BuildOptionsPanel()
DCSeasons.CommPanel = BuildCommunicationPanel(DCSeasons.OptionsPanel)

-- =====================================================================
-- INITIALIZATION
-- =====================================================================

local function Initialize()
    print("|cff00ff00[DC-Seasons]|r Loaded! Type /seasonal for commands.")
    
    if DCSeasons:GetSetting("autoShowTracker") then
        DCSeasons:CreateProgressTracker()
        if DCSeasons.Frames.progressTracker then
            DCSeasons.Frames.progressTracker:Show()
            DCSeasons:UpdateProgressTracker()
        end
    end
    
    -- Re-check and register DC handlers if not already registered
    -- (DC-AddonProtocol may have loaded after DC-Seasons)
    if not DCSeasons._handlersRegistered then
        DCSeasons:RegisterDCHandlers()
    end
    
    -- Update DC reference for request functions
    DC = rawget(_G, "DCAddonProtocol")
    DCSeasons.useDCProtocol = (DC ~= nil)
    
    -- Request season data via DCAddonProtocol if available (with delay for connection)
    if DCSeasons.useDCProtocol and DC then
        local delayFrame = CreateFrame("Frame")
        delayFrame.elapsed = 0
        delayFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= 3 then  -- Wait 3 seconds for server connection
                self:SetScript("OnUpdate", nil)
                if DCSeasons.RequestSeasonData then
                    DCSeasons.RequestSeasonData()
                end
            end
        end)
    end
end

-- Initialize after UI loads
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        Initialize()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
