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
GF.TAB_NAMES = { "Mythic+", "Raids", "World", "Live Runs", "Scheduled", "My Queues" }
GF.TABS = {}
GF.currentTab = 1

-- Match DC-Leaderboards UI style across DC addons
local BG_FELLEATHER = "Interface\\AddOns\\DC-MythicPlus\\Textures\\Backgrounds\\FelLeather_512.tga"
local BG_TINT_ALPHA = 0.60

local function ApplyLeaderboardsStyle(frame)
    if not frame or frame.__dcLeaderboardsStyle then return end
    frame.__dcLeaderboardsStyle = true

    if frame.SetBackdropColor then
        frame:SetBackdropColor(0, 0, 0, 0)
    end

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints()
    bg:SetTexture(BG_FELLEATHER)
    if bg.SetHorizTile then bg:SetHorizTile(false) end
    if bg.SetVertTile then bg:SetVertTile(false) end

    local tint = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    tint:SetAllPoints()
    tint:SetTexture(0, 0, 0, BG_TINT_ALPHA)

    frame.__dcBg = bg
    frame.__dcTint = tint
end

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
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    ApplyLeaderboardsStyle(frame)

    -- Title Header Background
    local titleBg = frame:CreateTexture(nil, "ARTWORK")
    titleBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleBg:SetWidth(350)
    titleBg:SetHeight(64)
    titleBg:SetPoint("TOP", 0, 12)

    -- Title text
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", titleBg, "TOP", 0, -14)
    title:SetText("Dungeon Finder")
    title:SetTextColor(1, 0.82, 0) -- Gold
    frame.TitleText = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    frame.CloseButton = closeBtn

    -- Legacy Dungeon Finder button (opens Blizzard's LFG frame)
    local legacyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    legacyBtn:SetSize(100, 20)
    legacyBtn:SetPoint("TOPRIGHT", -40, -28)
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
    tabBar:SetPoint("TOPLEFT", 12, -52)
    tabBar:SetPoint("TOPRIGHT", -12, -52)
    tabBar:SetHeight(32)
    -- Removed background texture for cleaner look
    frame.tabContainer = tabBar
    
    -- Content container
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 8, -8)
    contentFrame:SetPoint("BOTTOMRIGHT", -15, 15)
    frame.contentFrame = contentFrame
    
    -- Content background (slightly lighter)
    local contentBg = contentFrame:CreateTexture(nil, "BACKGROUND")
    contentBg:SetAllPoints()
    contentBg:SetColorTexture(0.15, 0.15, 0.15, 0.5)
    
    self.mainFrame = frame
    self:CreateTabButtons()
    self:CreateRewardFrame()
    
    -- ESC to close
    tinsert(UISpecialFrames, "DCMythicPlusGroupFinderFrame")
    
    return frame
end

-- =====================================================================
-- Tab System
-- =====================================================================

function GF:CreateTabButtons()
    local tabWidth = (self.FRAME_WIDTH - 40) / #self.TAB_NAMES
    
    for i, tabName in ipairs(self.TAB_NAMES) do
        local btn = CreateFrame("Button", "DCGroupFinderTab" .. i, self.mainFrame.tabContainer)
        btn:SetSize(tabWidth - 2, 28)
        btn:SetPoint("LEFT", (i - 1) * tabWidth + 10, 0)
        
        -- Background (darker inactive)
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
        
        -- Bottom accent line (shows when selected)
        btn.accent = btn:CreateTexture(nil, "ARTWORK")
        btn.accent:SetPoint("BOTTOMLEFT", 0, 0)
        btn.accent:SetPoint("BOTTOMRIGHT", 0, 0)
        btn.accent:SetHeight(3)
        btn.accent:SetColorTexture(1, 0.82, 0, 1) -- Gold
        btn.accent:Hide()
        
        -- Text
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("CENTER", 0, 1)
        btn.text:SetText(tabName)
        btn.text:SetTextColor(0.7, 0.7, 0.7)
        
        -- Highlight on hover
        btn:SetScript("OnEnter", function(self)
            if GF.currentTab ~= self.tabIndex then
                self.bg:SetColorTexture(0.25, 0.25, 0.25, 0.9)
                self.text:SetTextColor(1, 1, 1)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if GF.currentTab ~= self.tabIndex then
                self.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
                self.text:SetTextColor(0.7, 0.7, 0.7)
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
            btn.bg:SetColorTexture(0.25, 0.25, 0.25, 1)
            btn.text:SetTextColor(1, 1, 1)
            btn.accent:Show()
        else
            btn.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
            btn.text:SetTextColor(0.7, 0.7, 0.7)
            btn.accent:Hide()
        end
    end
    
    -- Hide all content frames
    if self.MythicTabContent then self.MythicTabContent:Hide() end
    if self.RaidTabContent then self.RaidTabContent:Hide() end
    if self.WorldTabContent then self.WorldTabContent:Hide() end
    if self.LiveRunsTabContent then self.LiveRunsTabContent:Hide() end
    if self.ScheduledTabContent then self.ScheduledTabContent:Hide() end
    if self.MyQueuesTabContent then self.MyQueuesTabContent:Hide() end
    
    -- Show selected tab content
    if index == 1 then
        self:ShowMythicTab()
    elseif index == 2 then
        self:ShowRaidTab()
    elseif index == 3 then
        self:ShowWorldTab()
    elseif index == 4 then
        self:ShowLiveRunsTab()
    elseif index == 5 then
        self:ShowScheduledTab()
    elseif index == 6 then
        self:ShowMyQueuesTab()
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
        
        local DC = rawget(_G, "DCAddonProtocol")
        if DC and DC.GroupFinder and DC.GroupFinder.GetSystemInfo then
            DC.GroupFinder.GetSystemInfo()
        end
    end
end

function GF:Show()
    if not self.mainFrame then
        self:CreateMainFrame()
    end
    self.mainFrame:Show()
    self:SelectTab(1)
    
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder and DC.GroupFinder.GetSystemInfo then
        DC.GroupFinder.GetSystemInfo()
    end
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

function GF:ShowWorldTab()
    if not self.WorldTabContent and self.CreateWorldTab then
        self:CreateWorldTab()
    end
    if self.WorldTabContent then
        self.WorldTabContent:Show()
        -- Refresh world content when tab is shown
        if self.RefreshWorldContent then
            self:RefreshWorldContent()
        end
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

function GF:ShowMyQueuesTab()
    if not self.MyQueuesTabContent then
        self:CreateMyQueuesTab()
    end
    if self.MyQueuesTabContent then
        self.MyQueuesTabContent:Show()
        self:RefreshMyQueues()
    end
end

function GF:CreateMyQueuesTab()
    local frame = CreateFrame("Frame", nil, self.mainFrame.contentFrame)
    frame:SetAllPoints()
    frame:Hide()
    
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("My Active Applications")
    
    -- Scroll frame for applications
    local scrollFrame = CreateFrame("ScrollFrame", "DCGroupFinderMyQueuesScroll", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    frame.scrollChild = scrollChild
    
    self.MyQueuesTabContent = frame
end

function GF:RefreshMyQueues()
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder and DC.GroupFinder.GetMyApplications then
        DC.GroupFinder.GetMyApplications()
    end
end

-- Application Dialog
function GF:ShowApplicationDialog(listingId, dungeonName)
    if not self.appDialog then
        local frame = CreateFrame("Frame", "DCGroupFinderAppDialog", UIParent)
        frame:SetSize(300, 250)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        
        -- Background
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        ApplyLeaderboardsStyle(frame)
        
        -- Title
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -15)
        title:SetText("Apply to Group")
        title:SetTextColor(1, 0.82, 0) -- Gold
        frame.title = title
        
        -- Role Checkboxes
        local tankCb = CreateFrame("CheckButton", "DCGroupFinderAppDialogRoleTank", frame, "UICheckButtonTemplate")
        tankCb:SetPoint("TOPLEFT", 40, -50)
        _G[tankCb:GetName().."Text"]:SetText("|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:0:19:22:41|t Tank")
        frame.tankCb = tankCb
        
        local healerCb = CreateFrame("CheckButton", "DCGroupFinderAppDialogRoleHealer", frame, "UICheckButtonTemplate")
        healerCb:SetPoint("TOPLEFT", 120, -50)
        _G[healerCb:GetName().."Text"]:SetText("|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:1:20|t Healer")
        frame.healerCb = healerCb
        
        local dpsCb = CreateFrame("CheckButton", "DCGroupFinderAppDialogRoleDPS", frame, "UICheckButtonTemplate")
        dpsCb:SetPoint("TOPLEFT", 200, -50)
        _G[dpsCb:GetName().."Text"]:SetText("|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:22:41|t Damage")
        frame.dpsCb = dpsCb
        
        -- Note EditBox
        local noteLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noteLabel:SetPoint("TOPLEFT", 20, -90)
        noteLabel:SetText("Note (optional):")
        noteLabel:SetTextColor(1, 0.82, 0) -- Gold
        
        local noteBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        noteBox:SetSize(260, 20)
        noteBox:SetPoint("TOPLEFT", 25, -110)
        noteBox:SetAutoFocus(false)
        frame.noteBox = noteBox
        
        -- Buttons
        local applyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        applyBtn:SetSize(100, 25)
        applyBtn:SetPoint("BOTTOMLEFT", 40, 20)
        applyBtn:SetText("Apply")
        applyBtn:SetScript("OnClick", function()
            local roleMask = 0
            if frame.tankCb:GetChecked() then roleMask = roleMask + 1 end
            if frame.healerCb:GetChecked() then roleMask = roleMask + 2 end
            if frame.dpsCb:GetChecked() then roleMask = roleMask + 4 end
            
            if roleMask == 0 then
                GF.Print("Please select at least one role.")
                return
            end
            
            local note = frame.noteBox:GetText()
            local DC = rawget(_G, "DCAddonProtocol")
            if DC and DC.GroupFinder then
                DC.GroupFinder.Apply(frame.listingId, roleMask, note)
            end
            frame:Hide()
        end)
        
        local cancelBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        cancelBtn:SetSize(100, 25)
        cancelBtn:SetPoint("BOTTOMRIGHT", -40, 20)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function() frame:Hide() end)
        
        self.appDialog = frame
    end
    
    -- Update role checkboxes based on class
    local _, classFilename = UnitClass("player")
    local canTank = false
    local canHeal = false
    local canDPS = true -- Everyone can DPS
    
    if classFilename == "WARRIOR" or classFilename == "DEATHKNIGHT" or classFilename == "PALADIN" or classFilename == "DRUID" then
        canTank = true
    end
    
    if classFilename == "PRIEST" or classFilename == "SHAMAN" or classFilename == "PALADIN" or classFilename == "DRUID" then
        canHeal = true
    end
    
    -- Configure checkboxes
    if canTank then
        self.appDialog.tankCb:Enable()
        self.appDialog.tankCb:SetAlpha(1)
    else
        self.appDialog.tankCb:Disable()
        self.appDialog.tankCb:SetChecked(false)
        self.appDialog.tankCb:SetAlpha(0.5)
    end
    
    if canHeal then
        self.appDialog.healerCb:Enable()
        self.appDialog.healerCb:SetAlpha(1)
    else
        self.appDialog.healerCb:Disable()
        self.appDialog.healerCb:SetChecked(false)
        self.appDialog.healerCb:SetAlpha(0.5)
    end
    
    -- Auto-select primary role if nothing selected
    if not self.appDialog.tankCb:GetChecked() and not self.appDialog.healerCb:GetChecked() and not self.appDialog.dpsCb:GetChecked() then
        if canTank then self.appDialog.tankCb:SetChecked(true)
        elseif canHeal then self.appDialog.healerCb:SetChecked(true)
        else self.appDialog.dpsCb:SetChecked(true) end
    end
    
    self.appDialog.listingId = listingId
    self.appDialog.title:SetText("Apply to " .. (dungeonName or "Group"))
    self.appDialog.noteBox:SetText("")
    self.appDialog:Show()
end

-- =====================================================================
-- Reward Display
-- =====================================================================

function GF:CreateRewardFrame()
    if self.rewardFrame then return end
    
    local frame = CreateFrame("Frame", nil, self.mainFrame)
    frame:SetSize(300, 30)
    frame:SetPoint("BOTTOMLEFT", 10, 5)
    
    -- Label
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetText("Daily Reward:")
    label:SetTextColor(1, 0.82, 0) -- Gold
    frame.label = label
    
    -- Icon
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", label, "RIGHT", 5, 0)
    frame.icon = icon
    
    -- Count
    local count = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    frame.count = count
    
    self.rewardFrame = frame
    self.rewardFrame:Hide() -- Hide until data received
end

function GF:UpdateSystemInfo(data)
    if not self.mainFrame then return end
    if not self.rewardFrame then self:CreateRewardFrame() end
    
    if data.rewardEnabled then
        self.rewardFrame:Show()
        
        local text = ""
        local iconTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
        
        local rewardItemId = tonumber(data.rewardItemId) or 0
        local rewardItemCount = tonumber(data.rewardItemCount) or 1

        -- Prefer central Upgrade Token if server is still sending a placeholder (commonly 49426 = Emblem of Frost)
        local centralTokenId = (rawget(_G, "DCAddonProtocol") and rawget(_G, "DCAddonProtocol").TOKEN_ITEM_ID) or 0
        if centralTokenId > 0 and (rewardItemId == 0 or rewardItemId == 49426) then
            rewardItemId = centralTokenId
            rewardItemCount = 1
        end

        if rewardItemId > 0 then
            local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(rewardItemId)
            if itemIcon then
                iconTexture = itemIcon
            end
            text = (rewardItemCount or 1) .. "x " .. (itemName or "Item")
            
            -- If item info not cached, query it
            if not itemName then
                -- WotLK doesn't have Item:CreateFromItemID mixin usually, just rely on GetItemInfo returning nil first time
                -- We can try to query it again later or just show ID
                text = (rewardItemCount or 1) .. "x Item " .. rewardItemId
            end
        elseif data.rewardCurrencyId > 0 then
            -- Currency handling
            local name, _, icon = GetCurrencyInfo(data.rewardCurrencyId)
            if icon then
                iconTexture = icon
            end
            text = (data.rewardCurrencyCount or 1) .. "x " .. (name or "Currency")
        end
        
        self.rewardFrame.icon:SetTexture(iconTexture)
        self.rewardFrame.count:SetText(text)
    else
        self.rewardFrame:Hide()
    end
end

Print("Group Finder UI module loaded")
