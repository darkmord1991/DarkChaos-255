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
    
    -- Dark background (retail-like)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0.04, 0.04, 0.05, 0.98)
    
    -- Border frame with backdrop
    local border = CreateFrame("Frame", nil, frame)
    border:SetPoint("TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", 2, -2)
    border:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 }
    })
    border:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
    
    -- Top header bar (darker gradient feel)
    local headerBar = CreateFrame("Frame", nil, frame)
    headerBar:SetPoint("TOPLEFT", 0, 0)
    headerBar:SetPoint("TOPRIGHT", 0, 0)
    headerBar:SetHeight(40)
    headerBar.bg = headerBar:CreateTexture(nil, "BACKGROUND", nil, 1)
    headerBar.bg:SetAllPoints()
    headerBar.bg:SetColorTexture(0.08, 0.08, 0.10, 1)
    
    -- Header bottom line
    local headerLine = frame:CreateTexture(nil, "ARTWORK")
    headerLine:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, 0)
    headerLine:SetPoint("TOPRIGHT", headerBar, "BOTTOMRIGHT", 0, 0)
    headerLine:SetHeight(2)
    headerLine:SetColorTexture(0.2, 0.5, 0.8, 0.6)
    
    -- Icon (left of title)
    local icon = headerBar:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", 12, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    
    -- Title
    local title = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    title:SetText("|cffffffffGroup Finder|r")
    frame.title = title
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Legacy Dungeon Finder button (opens Blizzard's LFG frame)
    local legacyBtn = CreateFrame("Button", nil, headerBar, "UIPanelButtonTemplate")
    legacyBtn:SetSize(100, 20)
    legacyBtn:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
    legacyBtn:SetText("LFG Tool")
    legacyBtn:SetScript("OnClick", function()
        -- Toggle the native Dungeon Finder (LFG) frame
        if LFDParentFrame then
            if LFDParentFrame:IsShown() then
                HideUIPanel(LFDParentFrame)
            else
                ShowUIPanel(LFDParentFrame)
            end
        elseif LFGParentFrame then
            ToggleLFGParentFrame()
        else
            -- Fallback: try to toggle via the PVE frame
            ToggleLFDParentFrame()
        end
    end)
    legacyBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Open Legacy Dungeon Finder")
        GameTooltip:AddLine("The original Blizzard LFG tool", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    legacyBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.legacyBtn = legacyBtn
    
    -- Tab bar (below header)
    local tabBar = CreateFrame("Frame", nil, frame)
    tabBar:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -2)
    tabBar:SetPoint("TOPRIGHT", headerBar, "BOTTOMRIGHT", 0, -2)
    tabBar:SetHeight(32)
    tabBar.bg = tabBar:CreateTexture(nil, "BACKGROUND")
    tabBar.bg:SetAllPoints()
    tabBar.bg:SetColorTexture(0.06, 0.06, 0.07, 1)
    frame.tabContainer = tabBar
    
    -- Content container
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 8, -8)
    contentFrame:SetPoint("BOTTOMRIGHT", -8, 8)
    frame.contentFrame = contentFrame
    
    -- Content background (slightly lighter)
    local contentBg = contentFrame:CreateTexture(nil, "BACKGROUND")
    contentBg:SetAllPoints()
    contentBg:SetColorTexture(0.05, 0.05, 0.06, 1)
    
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
    local tabWidth = (self.FRAME_WIDTH - 20) / #self.TAB_NAMES
    
    for i, tabName in ipairs(self.TAB_NAMES) do
        local btn = CreateFrame("Button", "DCGroupFinderTab" .. i, self.mainFrame.tabContainer)
        btn:SetSize(tabWidth - 2, 28)
        btn:SetPoint("LEFT", (i - 1) * tabWidth + 10, 0)
        
        -- Background (darker inactive)
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.04, 0.04, 0.05, 1)
        
        -- Bottom accent line (shows when selected)
        btn.accent = btn:CreateTexture(nil, "ARTWORK")
        btn.accent:SetPoint("BOTTOMLEFT", 0, 0)
        btn.accent:SetPoint("BOTTOMRIGHT", 0, 0)
        btn.accent:SetHeight(3)
        btn.accent:SetColorTexture(0.2, 0.5, 0.8, 1)
        btn.accent:Hide()
        
        -- Text
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("CENTER", 0, 1)
        btn.text:SetText(tabName)
        btn.text:SetTextColor(0.6, 0.6, 0.6)
        
        -- Highlight on hover
        btn:SetScript("OnEnter", function(self)
            if GF.currentTab ~= self.tabIndex then
                self.bg:SetColorTexture(0.08, 0.08, 0.10, 1)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if GF.currentTab ~= self.tabIndex then
                self.bg:SetColorTexture(0.04, 0.04, 0.05, 1)
            end
        end)
        
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
            btn.bg:SetColorTexture(0.08, 0.08, 0.10, 1)
            btn.text:SetTextColor(1, 1, 1)
            btn.accent:Show()
        else
            btn.bg:SetColorTexture(0.04, 0.04, 0.05, 1)
            btn.text:SetTextColor(0.6, 0.6, 0.6)
            btn.accent:Hide()
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
        -- Select browse sub-tab and refresh groups if this is first show
        if self.MythicBrowsePanel and not self.MythicBrowsePanel.hasInitialized then
            self.MythicBrowsePanel.hasInitialized = true
            self:SelectMythicSubTab(1)
            self:RefreshMythicGroups()
        end
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
        -- Refresh events when tab is shown
        if self.RefreshScheduledEvents then
            self:RefreshScheduledEvents()
        end
    end
end

Print("Group Finder UI module loaded")
