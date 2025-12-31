--[[
    DC-Welcome: Seasons Module
    ===========================
    
    Seasonal reward tracking, progress display, and reward notifications.
    
    Previously: Stand-alone DC-Seasons addon
    Now integrated into: DC-Welcome
    
    Features:
    - Reward popup notifications (tokens, essence)
    - Progress tracker (compact HUD widget)
    - Weekly stats tracking
    - DCAddonProtocol integration for server communication
    
    Author: DarkChaos-255
    Date: December 2025
]]

DCWelcome = DCWelcome or {}
DCWelcome.Seasons = DCWelcome.Seasons or {}

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------

local function GetSettings()
    DCWelcomeDB = DCWelcomeDB or {}
    DCWelcomeDB.seasons = DCWelcomeDB.seasons or {
        autoShowTracker = false,
        enableSounds = true
    }
    return DCWelcomeDB.seasons
end

local function GetSetting(key)
    return GetSettings()[key]
end

local function SetSetting(key, value)
    GetSettings()[key] = value
end

-- Configuration
local Config = {
    FRAME_WIDTH = 300,
    FRAME_HEIGHT = 150,
    FADE_DURATION = 3.0,
    SLIDE_DURATION = 0.5
}

-- Frame references
local Frames = {
    rewardPopup = nil,
    progressTracker = nil
}

-- Data cache
local Data = {
    seasonNumber = nil,
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
    _loaded = false,
    _showWeeklyView = true,  -- Toggle between weekly and total view
}

-- Export data
DCWelcome.Seasons.Data = Data
DCWelcome.Seasons.GetSetting = GetSetting
DCWelcome.Seasons.SetSetting = SetSetting

-- Get token and essence info from DCAddonProtocol if available
local function GetTokenInfo()
    local DCProtocol = rawget(_G, "DCAddonProtocol")
    if DCProtocol then
        return {
            tokenID = DCProtocol.TOKEN_ITEM_ID,
            essenceID = DCProtocol.ESSENCE_ITEM_ID,
            getTokenIcon = function() return DCProtocol:GetTokenIcon(DCProtocol.TOKEN_ITEM_ID) end,
            getEssenceIcon = function() return DCProtocol:GetTokenIcon(DCProtocol.ESSENCE_ITEM_ID) end,
            formatToken = function(count) return DCProtocol:FormatTokenDisplay(DCProtocol.TOKEN_ITEM_ID, count) end,
            formatEssence = function(count) return DCProtocol:FormatTokenDisplay(DCProtocol.ESSENCE_ITEM_ID, count) end,
        }
    else
        return {
            tokenID = 300311,
            essenceID = 300312,
            getTokenIcon = function() return "Interface\\Icons\\INV_Misc_Token_ArgentCrusade" end,
            getEssenceIcon = function() return "Interface\\Icons\\INV_Misc_Herb_Draenethisle" end,
            formatToken = function(count) return "|cffffd700" .. count .. " Tokens|r" end,
            formatEssence = function(count) return "|cff0070dd" .. count .. " Essence|r" end,
        }
    end
end

-- Convenience getter for other addons/scripts
function DCWelcome.Seasons:GetWeeklyTokens()
    return Data.weeklyTokens or 0
end

function DCWelcome.Seasons:GetInventoryTokens()
    return Data.tokens or 0
end

function DCWelcome.Seasons:GetTokenInfo()
    return GetTokenInfo()
end

-------------------------------------------------------------------------------
-- Utility
-------------------------------------------------------------------------------

local function ScheduleAfter(delay, callback)
    if type(callback) ~= "function" or (delay or 0) < 0 then return end
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

-------------------------------------------------------------------------------
-- Reward Popup Frame
-------------------------------------------------------------------------------

function DCWelcome.Seasons:CreateRewardPopup()
    if Frames.rewardPopup then
        return Frames.rewardPopup
    end
    
    local tokenInfo = GetTokenInfo()
    
    local frame = CreateFrame("Frame", "DCWelcome_SeasonRewardPopup", UIParent)
    frame:SetSize(Config.FRAME_WIDTH, Config.FRAME_HEIGHT)
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
    tokenIcon:SetTexture(tokenInfo.getTokenIcon())
    frame.tokenIcon = tokenIcon
    
    local tokenText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    tokenText:SetPoint("LEFT", tokenIcon, "RIGHT", 10, 0)
    tokenText:SetText("|cffffd700+0 Tokens|r")
    frame.tokenText = tokenText
    
    -- Essence icon and amount
    local essenceIcon = frame:CreateTexture(nil, "OVERLAY")
    essenceIcon:SetSize(32, 32)
    essenceIcon:SetPoint("LEFT", frame, "LEFT", 20, -25)
    essenceIcon:SetTexture(tokenInfo.getEssenceIcon())
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
    
    Frames.rewardPopup = frame
    return frame
end

function DCWelcome.Seasons:ShowRewardPopup(tokens, essence, source)
    local frame = self:CreateRewardPopup()
    
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
    
    frame:Show()
    UIFrameFadeIn(frame, Config.SLIDE_DURATION, 0, 1)
    
    ScheduleAfter(Config.FADE_DURATION + Config.SLIDE_DURATION, function()
        UIFrameFadeOut(frame, Config.SLIDE_DURATION, 1, 0)
        ScheduleAfter(Config.SLIDE_DURATION, function()
            frame:Hide()
        end)
    end)
    
    if GetSetting("enableSounds") then
        PlaySound("LOOTWINDOWCOINSOUND")
    end
end

-------------------------------------------------------------------------------
-- Progress Tracker Frame
-------------------------------------------------------------------------------

function DCWelcome.Seasons:CreateProgressTracker()
    if Frames.progressTracker then
        return Frames.progressTracker
    end
    
    local frame = CreateFrame("Frame", "DCWelcome_SeasonTracker", UIParent)
    frame:SetSize(250, 115)
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
    
    -- Season Title
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
    tokenBar:SetStatusBarColor(1, 0.82, 0)
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
    
    -- Make token bar clickable to toggle between weekly and total view
    tokenBar:EnableMouse(true)
    tokenBar:SetScript("OnMouseDown", function(self)
        Data._showWeeklyView = not Data._showWeeklyView
        DCWelcome.Seasons:UpdateProgressTracker()
        if Data._showWeeklyView then
            print("|cffFFD700[Seasons]|r Switched to |cffFFD700Weekly|r view")
        else
            print("|cffFFD700[Seasons]|r Switched to |cffffd700Total|r view - Total Tokens: " .. (Data.tokens or 0))
        end
    end)
    tokenBar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Token Progress", 1, 0.82, 0)
        if Data._showWeeklyView then
            GameTooltip:AddLine("Weekly: " .. (Data.weeklyTokens or 0) .. " / " .. (Data.weeklyTokenCap or 1000), 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Total Collected: " .. (Data.tokens or 0), 0.5, 0.5, 0.5)
        else
            GameTooltip:AddLine("Total Collected: " .. (Data.tokens or 0), 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Weekly: " .. (Data.weeklyTokens or 0) .. " / " .. (Data.weeklyTokenCap or 1000), 0.5, 0.5, 0.5)
        end
        GameTooltip:AddLine("Click to toggle view", 0.5, 1, 0.5)
        GameTooltip:Show()
    end)
    tokenBar:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    
    -- Essence progress bar
    local essenceBar = CreateFrame("StatusBar", nil, frame)
    essenceBar:SetSize(220, 18)
    essenceBar:SetPoint("TOP", tokenBar, "BOTTOM", 0, -5)
    essenceBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    essenceBar:SetStatusBarColor(0, 1, 1)
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
    
    -- Make essence bar clickable to toggle between weekly and total view
    essenceBar:EnableMouse(true)
    essenceBar:SetScript("OnMouseDown", function(self)
        Data._showWeeklyView = not Data._showWeeklyView
        DCWelcome.Seasons:UpdateProgressTracker()
        if Data._showWeeklyView then
            print("|cffFFD700[Seasons]|r Switched to |cffFFD700Weekly|r view")
        else
            print("|cffFFD700[Seasons]|r Switched to |cff00ffff|cff00ffffTotal|r view - Total Essence: " .. (Data.essence or 0))
        end
    end)
    essenceBar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Essence Progress", 0, 1, 1)
        if Data._showWeeklyView then
            GameTooltip:AddLine("Weekly: " .. (Data.weeklyEssence or 0) .. " / " .. (Data.weeklyEssenceCap or 1000), 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Total Collected: " .. (Data.essence or 0), 0.5, 0.5, 0.5)
        else
            GameTooltip:AddLine("Total Collected: " .. (Data.essence or 0), 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Weekly: " .. (Data.weeklyEssence or 0) .. " / " .. (Data.weeklyEssenceCap or 1000), 0.5, 0.5, 0.5)
        end
        GameTooltip:AddLine("Click to toggle view", 0.5, 1, 0.5)
        GameTooltip:Show()
    end)
    essenceBar:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    
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
    Frames.progressTracker = frame
    return frame
end

function DCWelcome.Seasons:UpdateProgressTracker()
    local frame = Frames.progressTracker
    if not frame then return end
    
    if not Data._loaded then
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
    
    if frame.seasonTitle then
        frame.seasonTitle:SetText(string.format("|cffFFD700Season %d|r", Data.seasonNumber or 1))
    end
    if frame.seasonName then
        frame.seasonName:SetText(string.format("|cff00ff00%s|r", Data.seasonName or ""))
    end
    
    -- Display bars in toggled view (weekly or total)
    if Data._showWeeklyView then
        -- Weekly view
        local tokenPercent = Data.weeklyTokens / math.max(Data.weeklyTokenCap, 1)
        frame.tokenBar:SetValue(math.min(tokenPercent, 1))
        frame.tokenBarText:SetText(string.format("%d / %d Tokens (Weekly)", Data.weeklyTokens, Data.weeklyTokenCap))
        
        local essencePercent = Data.weeklyEssence / math.max(Data.weeklyEssenceCap, 1)
        frame.essenceBar:SetValue(math.min(essencePercent, 1))
        frame.essenceBarText:SetText(string.format("%d / %d Essence (Weekly)", Data.weeklyEssence, Data.weeklyEssenceCap))
    else
        -- Total collected view (use totalCap as reference, typically much higher)
        local totalCap = math.max(Data.weeklyTokenCap * 10, 10000)  -- Assume total cap is 10x weekly cap
        local tokenPercent = Data.tokens / totalCap
        frame.tokenBar:SetValue(math.min(tokenPercent, 1))
        frame.tokenBarText:SetText(string.format("%d Total Tokens Collected", Data.tokens or 0))
        
        local totalEssenceCap = math.max(Data.weeklyEssenceCap * 10, 10000)
        local essencePercent = Data.essence / totalEssenceCap
        frame.essenceBar:SetValue(math.min(essencePercent, 1))
        frame.essenceBarText:SetText(string.format("%d Total Essence Collected", Data.essence or 0))
    end
    
    frame.statsText:SetText(string.format("Quests: %d | Bosses: %d", Data.quests, Data.worldBosses + Data.dungeonBosses))
end

function DCWelcome.Seasons:ToggleProgressTracker()
    local frame = self:CreateProgressTracker()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        self:UpdateProgressTracker()
    end
end

-------------------------------------------------------------------------------
-- DCAddonProtocol Handlers
-------------------------------------------------------------------------------

local function RegisterHandlers()
    if DCWelcome and type(DCWelcome.IsCommunicationEnabled) == "function" then
        if not DCWelcome:IsCommunicationEnabled() then
            -- Communication disabled in DC-Welcome settings.
            return
        end
    elseif type(DCWelcomeDB) == "table" and DCWelcomeDB.enableCommunication == false then
        return
    end

    local DC = rawget(_G, "DCAddonProtocol")
    if not DC then
        ScheduleAfter(1, RegisterHandlers)
        return
    end
    
    -- SMSG_CURRENT_SEASON (0x10)
    DC:RegisterHandler("SEAS", 0x10, function(data)
        if type(data) == "table" then
            Data.seasonNumber = data.seasonId or data.id or 1
            Data.seasonName = data.name or data.seasonName or "Unknown Season"
            Data.startTime = data.startTime
            Data.endTime = data.endTime
            Data.daysRemaining = data.daysRemaining
            if data.tokenCap then Data.weeklyTokenCap = data.tokenCap end
            if data.essenceCap then Data.weeklyEssenceCap = data.essenceCap end
        end
        Data._loaded = true
        DCWelcome.Seasons:UpdateProgressTracker()
    end)
    
    -- SMSG_PROGRESS (0x12)
    DC:RegisterHandler("SEAS", 0x12, function(data)
        if type(data) == "table" then
            Data.seasonNumber = data.seasonId or Data.seasonNumber or 1
            Data.seasonLevel = data.level or data.seasonLevel or 1
            
            -- Current token/essence counts (actual inventory items)
            Data.tokens = data.tokens or 0
            Data.essence = data.essence or 0
            
            -- Weekly progress tracking
            Data.weeklyTokens = data.weeklyTokens or data.tokens or 0
            Data.weeklyEssence = data.weeklyEssence or data.essence or 0
            Data.weeklyTokenCap = data.tokenCap or data.xpToNextLevel or 1000
            Data.weeklyEssenceCap = data.essenceCap or 1000
            
            -- Activity tracking
            Data.totalPoints = data.totalPoints or 0
            Data.rank = data.rank
            Data.tier = data.tier
            Data.quests = data.quests or 0
            Data.worldBosses = data.worldBosses or 0
            Data.dungeonBosses = data.dungeonBosses or data.bosses or 0
        end
        Data._loaded = true
        DCWelcome.Seasons:UpdateProgressTracker()
    end)
    
    -- SMSG_REWARD_EARNED (0x17)
    DC:RegisterHandler("SEAS", 0x17, function(data)
        local tokens, essence, source
        
        if type(data) == "table" then
            tokens = data.tokens or 0
            essence = data.essence or 0
            source = data.source or data.reason or "Unknown"
        end
        
        if tokens > 0 or essence > 0 then
            DCWelcome.Seasons:ShowRewardPopup(tokens, essence, source)
            Data.weeklyTokens = (Data.weeklyTokens or 0) + tokens
            Data.weeklyEssence = (Data.weeklyEssence or 0) + essence
            DCWelcome.Seasons:UpdateProgressTracker()
        end
    end)
    
    -- Request functions
    DCWelcome.Seasons.RequestSeasonData = function()
        if DC and (not (type(DCWelcomeDB) == "table" and DCWelcomeDB.enableCommunication == false)) then
            DC:Request("SEAS", 0x01, {})
            DC:Request("SEAS", 0x03, {})
        end
    end
    
    DCWelcome.Seasons.RequestRewards = function()
        if DC and (not (type(DCWelcomeDB) == "table" and DCWelcomeDB.enableCommunication == false)) then
            DC:Request("SEAS", 0x02, {})
        end
    end
    
    DCWelcome.Seasons.ClaimReward = function(rewardId)
        if DC and (not (type(DCWelcomeDB) == "table" and DCWelcomeDB.enableCommunication == false)) then
            DC:Request("SEAS", 0x04, { rewardId = rewardId })
        end
    end
end

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------

SLASH_DCSEASONS1 = "/seasonal"
SLASH_DCSEASONS2 = "/season"
SLASH_DCSEASONS3 = "/dcseasons"

SlashCmdList["DCSEASONS"] = function(msg)
    local cmd = string.lower(msg or "")
    
    if cmd == "show" or cmd == "toggle" or cmd == "" then
        DCWelcome.Seasons:ToggleProgressTracker()
    elseif cmd == "hide" then
        if Frames.progressTracker then
            Frames.progressTracker:Hide()
        end
    elseif cmd == "test" then
        DCWelcome.Seasons:ShowRewardPopup(150, 75, "Test Quest")
        Data.weeklyTokens = Data.weeklyTokens + 150
        Data.weeklyEssence = Data.weeklyEssence + 75
        DCWelcome.Seasons:UpdateProgressTracker()
    elseif cmd == "refresh" or cmd == "sync" then
        if DCWelcome.Seasons.RequestSeasonData then
            DCWelcome.Seasons.RequestSeasonData()
            print("|cff00ff00[DC-Seasons]|r Requesting season data...")
        end
    elseif cmd == "status" then
        local dcAvail = rawget(_G, "DCAddonProtocol") and "YES" or "NO"
        print("|cff00ff00[DC-Seasons]|r Status:")
        print("  DCAddonProtocol: " .. dcAvail)
        print("  Season: " .. (Data.seasonNumber or "?") .. " - " .. (Data.seasonName or "Unknown"))
        print("  Tokens: " .. (Data.weeklyTokens or 0) .. "/" .. (Data.weeklyTokenCap or 5000))
        print("  Essence: " .. (Data.weeklyEssence or 0) .. "/" .. (Data.weeklyEssenceCap or 2500))
    else
        print("|cff00ff00[Seasonal]|r Commands:")
        print("  /seasonal show - Toggle progress tracker")
        print("  /seasonal hide - Hide progress tracker")
        print("  /seasonal refresh - Request data from server")
        print("  /seasonal status - Show protocol status")
        print("  /seasonal test - Test reward popup")
    end
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

local function Initialize()
    RegisterHandlers()
    
    if GetSetting("autoShowTracker") then
        DCWelcome.Seasons:CreateProgressTracker()
        if Frames.progressTracker then
            Frames.progressTracker:Show()
            DCWelcome.Seasons:UpdateProgressTracker()
        end
    end
    
    -- Request season data after delay
    ScheduleAfter(3, function()
        if DCWelcome.Seasons.RequestSeasonData then
            DCWelcome.Seasons.RequestSeasonData()
        end
    end)
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        Initialize()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- Mark as loaded
DCWelcome.Seasons.loaded = true
