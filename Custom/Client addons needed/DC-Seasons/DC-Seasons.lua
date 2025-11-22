--[[
    DC-Seasons - Client Addon (AIO)
    DarkChaos Seasonal Reward System UI
    
    Displays reward notifications and seasonal progress tracking
    
    Author: DarkChaos Development Team
    Date: November 22, 2025
]]--

local DCSeasons = {}

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

-- Data cache
DCSeasons.Data = {
    tokens = 0,
    essence = 0,
    weeklyTokens = 0,
    weeklyEssence = 0,
    weeklyTokenCap = 5000,
    weeklyEssenceCap = 2500,
    quests = 0,
    worldBosses = 0,
    dungeonBosses = 0
}

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
    C_Timer.After(self.Config.FADE_DURATION + self.Config.SLIDE_DURATION, function()
        UIFrameFadeOut(frame, self.Config.SLIDE_DURATION, 1, 0)
        C_Timer.After(self.Config.SLIDE_DURATION, function()
            frame:Hide()
        end)
    end)
    
    -- Play sound
    PlaySound("LOOTWINDOWCOINSOUND")
end

-- =====================================================================
-- PROGRESS TRACKER FRAME
-- =====================================================================

function DCSeasons:CreateProgressTracker()
    if self.Frames.progressTracker then
        return self.Frames.progressTracker
    end
    
    local frame = CreateFrame("Frame", "SeasonalProgressTracker", UIParent)
    frame:SetSize(250, 120)
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
    bg:SetTexture(0, 0, 0, 0.6)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -5)
    title:SetText("|cff00ff00Seasonal Progress|r")
    frame.title = title
    
    -- Token progress bar
    local tokenBar = CreateFrame("StatusBar", nil, frame)
    tokenBar:SetSize(220, 18)
    tokenBar:SetPoint("TOP", title, "BOTTOM", 0, -5)
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
    
    self.Frames.progressTracker = frame
    return frame
end

function DCSeasons:UpdateProgressTracker()
    local frame = self.Frames.progressTracker
    if not frame then return end
    
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
SLASH_DCSEASONS3 = "/dcseasons"ons"

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
    else
        print("|cff00ff00[Seasonal]|r Commands:")
        print("  /seasonal show - Toggle progress tracker")
        print("  /seasonal hide - Hide progress tracker")
        print("  /seasonal test - Test reward popup")
    end
end

-- =====================================================================
-- AIO MESSAGE HANDLERS
-- =====================================================================

-- if AIO then
--     local SeasonalAIO = AIO.AddAddon()
--     
--     -- Handle reward notification from server
--     function SeasonalAIO.OnRewardEarned(player, tokens, essence, source)
--         SeasonalUI:ShowRewardPopup(tokens, essence, source)
--         SeasonalUI.Data.weeklyTokens = SeasonalUI.Data.weeklyTokens + tokens
--         SeasonalUI.Data.weeklyEssence = SeasonalUI.Data.weeklyEssence + essence
--         SeasonalUI:UpdateProgressTracker()
--     end
--     
--     -- Handle stats update from server
--     function SeasonalAIO.UpdateStats(player, stats)
--         SeasonalUI.Data.weeklyTokens = stats.weeklyTokens or 0
--         SeasonalUI.Data.weeklyEssence = stats.weeklyEssence or 0
--         SeasonalUI.Data.weeklyTokenCap = stats.weeklyTokenCap or 5000
--         SeasonalUI.Data.weeklyEssenceCap = stats.weeklyEssenceCap or 2500
--         SeasonalUI.Data.quests = stats.quests or 0
--         SeasonalUI.Data.worldBosses = stats.worldBosses or 0
--         SeasonalUI.Data.dungeonBosses = stats.dungeonBosses or 0
--         SeasonalUI:UpdateProgressTracker()
--     end
-- end

-- =====================================================================
-- INITIALIZATION
-- =====================================================================

local function Initialize()
    print("|cff00ff00[DC-Seasons]|r Loaded! Type /seasonal for commands.")
    
    -- Auto-show progress tracker on login (optional)
    -- DCSeasons:CreateProgressTracker()
    -- DCSeasons.Frames.progressTracker:Show()
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
