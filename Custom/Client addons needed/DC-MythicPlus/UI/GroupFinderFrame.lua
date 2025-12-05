-- DC-MythicPlus/UI/GroupFinderFrame.lua
-- Main Group Finder window with tabbed interface (Mythic+, Raids, Live Runs, Scheduled)

local addonName = "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

namespace.GroupFinder = namespace.GroupFinder or {}
local GF = namespace.GroupFinder

-- =====================================================================
-- Constants
-- =====================================================================

GF.FRAME_WIDTH = 700
GF.FRAME_HEIGHT = 520
GF.TAB_NAMES = { "Mythic+", "Raids", "Live Runs", "Scheduled" }
GF.TABS = {}
GF.currentTab = 1

-- =====================================================================
-- Print Helper
-- =====================================================================

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff32c4ffGroup Finder:|r " .. (msg or ""))
    end
end
GF.Print = Print

-- =====================================================================
-- Main Frame Creation
-- =====================================================================

function GF:CreateMainFrame()
    if self.mainFrame then return self.mainFrame end
    
    local frame = CreateFrame("Frame", "DCMythicPlusGroupFinderFrame", UIParent)
    frame:SetSize(self.FRAME_WIDTH, self.FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:Hide()
    
    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0.05, 0.05, 0.1, 0.95)
    
    -- Border
    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate" or nil)
    border:SetAllPoints()
    if border.SetBackdrop then
        border:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        border:SetBackdropBorderColor(0.3, 0.6, 0.9, 0.8)
    end
    
    -- Header bar
    local headerBar = frame:CreateTexture(nil, "ARTWORK")
    headerBar:SetPoint("TOPLEFT", 3, -3)
    headerBar:SetPoint("TOPRIGHT", -3, -3)
    headerBar:SetHeight(28)
    headerBar:SetColorTexture(0.1, 0.2, 0.3, 0.8)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", headerBar, "TOP", 0, -5)
    title:SetText("|cff32c4ffDC|r Group Finder")
    frame.title = title
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Create tab buttons container
    local tabContainer = CreateFrame("Frame", nil, frame)
    tabContainer:SetPoint("TOPLEFT", 10, -34)
    tabContainer:SetPoint("TOPRIGHT", -10, -34)
    tabContainer:SetHeight(28)
    frame.tabContainer = tabContainer
    
    -- Create content container
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", 10, -66)
    contentFrame:SetPoint("BOTTOMRIGHT", -10, 10)
    frame.contentFrame = contentFrame
    
    -- Content background
    local contentBg = contentFrame:CreateTexture(nil, "BACKGROUND")
    contentBg:SetAllPoints()
    contentBg:SetColorTexture(0.03, 0.03, 0.06, 0.9)
    
    self.mainFrame = frame
    self:CreateTabButtons()
    
    -- ESC to close
    tinsert(UISpecialFrames, "DCMythicPlusGroupFinderFrame")
    
    return frame
end

-- =====================================================================
-- Tab System
-- =====================================================================

function GF:CreateTabButtons()
    local tabWidth = (self.FRAME_WIDTH - 30) / #self.TAB_NAMES
    
    for i, tabName in ipairs(self.TAB_NAMES) do
        local btn = CreateFrame("Button", "DCGroupFinderTab" .. i, self.mainFrame.tabContainer)
        btn:SetSize(tabWidth - 4, 24)
        btn:SetPoint("LEFT", (i - 1) * tabWidth + 2, 0)
        
        -- Normal state
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.1, 0.15, 0.2, 0.8)
        
        -- Text
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(tabName)
        
        -- Highlight
        btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        btn:GetHighlightTexture():SetBlendMode("ADD")
        
        btn.tabIndex = i
        btn:SetScript("OnClick", function(self)
            GF:SelectTab(self.tabIndex)
        end)
        
        self.TABS[i] = btn
    end
end

function GF:SelectTab(index)
    self.currentTab = index
    
    -- Update tab visuals
    for i, btn in ipairs(self.TABS) do
        if i == index then
            btn.bg:SetColorTexture(0.2, 0.4, 0.6, 0.9)
            btn.text:SetTextColor(1, 1, 1)
        else
            btn.bg:SetColorTexture(0.1, 0.15, 0.2, 0.8)
            btn.text:SetTextColor(0.7, 0.7, 0.7)
        end
    end
    
    -- Hide all content frames
    if self.MythicTabContent then self.MythicTabContent:Hide() end
    if self.RaidTabContent then self.RaidTabContent:Hide() end
    if self.LiveRunsTabContent then self.LiveRunsTabContent:Hide() end
    if self.ScheduledTabContent then self.ScheduledTabContent:Hide() end
    
    -- Show selected tab content
    if index == 1 then
        self:ShowMythicTab()
    elseif index == 2 then
        self:ShowRaidTab()
    elseif index == 3 then
        self:ShowLiveRunsTab()
    elseif index == 4 then
        self:ShowScheduledTab()
    end
end

-- =====================================================================
-- Toggle & Visibility
-- =====================================================================

function GF:Toggle()
    if not self.mainFrame then
        self:CreateMainFrame()
    end
    
    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    else
        self.mainFrame:Show()
        self:SelectTab(1) -- Default to Mythic+ tab
    end
end

function GF:Show()
    if not self.mainFrame then
        self:CreateMainFrame()
    end
    self.mainFrame:Show()
    self:SelectTab(1)
end

function GF:Hide()
    if self.mainFrame then
        self.mainFrame:Hide()
    end
end

-- =====================================================================
-- Placeholder Tab Content (populated by tab-specific files)
-- =====================================================================

function GF:ShowMythicTab()
    if not self.MythicTabContent and self.CreateMythicTab then
        self:CreateMythicTab()
    end
    if self.MythicTabContent then
        self.MythicTabContent:Show()
    end
end

function GF:ShowRaidTab()
    if not self.RaidTabContent and self.CreateRaidTab then
        self:CreateRaidTab()
    end
    if self.RaidTabContent then
        self.RaidTabContent:Show()
    end
end

function GF:ShowLiveRunsTab()
    if not self.LiveRunsTabContent and self.CreateLiveRunsTab then
        self:CreateLiveRunsTab()
    end
    if self.LiveRunsTabContent then
        self.LiveRunsTabContent:Show()
    end
end

function GF:ShowScheduledTab()
    if not self.ScheduledTabContent and self.CreateScheduledTab then
        self:CreateScheduledTab()
    end
    if self.ScheduledTabContent then
        self.ScheduledTabContent:Show()
    end
end

Print("Group Finder UI module loaded")
