--[[
    DC-Seasons - Client Addon (AIO)
    DarkChaos Seasonal Reward System UI
    
    Displays reward notifications and seasonal progress tracking
    
    Author: DarkChaos Development Team
    Date: November 22, 2025
]]--

local ADDON_NAME = "DC-Seasons"
local DCSeasons = {}

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

-- Data cache
DCSeasons.Data = {
    seasonNumber = 1,
    seasonName = "Season of Discovery",
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
    elseif cmd == "options" or cmd == "config" or cmd == "settings" then
        if InterfaceOptionsFrame_OpenToCategory and DCSeasons.OptionsPanel then
            InterfaceOptionsFrame_OpenToCategory(DCSeasons.OptionsPanel)
            InterfaceOptionsFrame_OpenToCategory(DCSeasons.OptionsPanel)
        end
    else
        print("|cff00ff00[Seasonal]|r Commands:")
        print("  /seasonal show - Toggle progress tracker")
        print("  /seasonal hide - Hide progress tracker")
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

DCSeasons.OptionsPanel = BuildOptionsPanel()

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
