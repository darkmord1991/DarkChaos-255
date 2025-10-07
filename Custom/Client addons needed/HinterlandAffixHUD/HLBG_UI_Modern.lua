-- HLBG_UI_Modern.lua - Modern UI styling and enhancements for main addon window

local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Modern UI color scheme
local MODERN_COLORS = {
    -- Main colors (darker, more modern)
    background = {0.05, 0.05, 0.08, 0.95},
    border = {0.3, 0.4, 0.5, 1.0},
    
    -- Header/Title bar
    titleBar = {0.08, 0.12, 0.18, 0.98},
    titleText = {0.9, 0.95, 1.0, 1.0},
    
    -- Tabs
    tabActive = {0.15, 0.25, 0.35, 0.9},
    tabInactive = {0.08, 0.12, 0.16, 0.8},
    tabText = {0.85, 0.9, 0.95, 1.0},
    tabTextInactive = {0.6, 0.65, 0.7, 0.8},
    
    -- Content areas
    contentBg = {0.02, 0.02, 0.04, 0.85},
    
    -- Row highlighting
    rowHover = {0.2, 0.3, 0.4, 0.4},
    rowSelected = {0.1, 0.2, 0.35, 0.6},
    rowAlt = {0.08, 0.1, 0.12, 0.3},
    
    -- Accent colors
    alliance = {0.2, 0.4, 0.8, 0.8},
    horde = {0.8, 0.2, 0.2, 0.8},
    success = {0.2, 0.8, 0.3, 0.8},
    warning = {0.9, 0.7, 0.1, 0.8},
    error = {0.9, 0.2, 0.2, 0.8}
}

-- Function to apply modern backdrop with rounded corners effect
local function ApplyModernBackdrop(frame, bgColor, borderColor, edgeSize)
    edgeSize = edgeSize or 2
    
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
        tile = true,
        tileSize = 16,
        edgeSize = edgeSize,
        insets = { left = edgeSize, right = edgeSize, top = edgeSize, bottom = edgeSize }
    })
    
    if bgColor then
        frame:SetBackdropColor(unpack(bgColor))
    end
    if borderColor then
        frame:SetBackdropBorderColor(unpack(borderColor))
    end
end

-- Function to create modern button styling
local function StyleModernButton(button, bgColor, textColor)
    if not button then return end
    
    bgColor = bgColor or MODERN_COLORS.tabInactive
    textColor = textColor or MODERN_COLORS.tabText
    
    ApplyModernBackdrop(button, bgColor, MODERN_COLORS.border, 1)
    
    -- Text color
    local fontString = button:GetFontString() or button.Text
    if fontString then
        fontString:SetTextColor(unpack(textColor))
    end
    
    -- Hover effects
    button:SetScript("OnEnter", function(self)
        ApplyModernBackdrop(self, MODERN_COLORS.rowHover, MODERN_COLORS.border, 1)
        if fontString then
            fontString:SetTextColor(unpack(MODERN_COLORS.titleText))
        end
    end)
    
    button:SetScript("OnLeave", function(self)
        ApplyModernBackdrop(self, bgColor, MODERN_COLORS.border, 1)
        if fontString then
            fontString:SetTextColor(unpack(textColor))
        end
    end)
end

-- Function to modernize the main UI frame
function HLBG.ApplyModernStyling()
    if not HLBG.UI or not HLBG.UI.Frame then
        return
    end
    
    local frame = HLBG.UI.Frame
    
    -- Modern main frame backdrop
    ApplyModernBackdrop(frame, MODERN_COLORS.background, MODERN_COLORS.border, 2)
    
    -- Create modern title bar
    if not frame.modernTitleBar then
        frame.modernTitleBar = CreateFrame("Frame", nil, frame)
        frame.modernTitleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
        frame.modernTitleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
        frame.modernTitleBar:SetHeight(28)
        
        ApplyModernBackdrop(frame.modernTitleBar, MODERN_COLORS.titleBar, nil, 1)
        
        -- Move existing title to title bar
        if frame.Title then
            frame.Title:ClearAllPoints()
            frame.Title:SetParent(frame.modernTitleBar)
            frame.Title:SetPoint("LEFT", frame.modernTitleBar, "LEFT", 12, 0)
            frame.Title:SetTextColor(unpack(MODERN_COLORS.titleText))
            frame.Title:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        end
        
        -- Add version/status indicator
        frame.modernStatus = frame.modernTitleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.modernStatus:SetPoint("RIGHT", frame.modernTitleBar, "RIGHT", -12, 0)
        frame.modernStatus:SetText("v" .. (HLAFFIXHUD_VERSION or "1.3.0"))
        frame.modernStatus:SetTextColor(0.7, 0.8, 0.9, 0.8)
    end
    
    -- Modernize tabs
    if HLBG.UI.Tabs then
        for i, tab in ipairs(HLBG.UI.Tabs) do
            if tab then
                -- Remove default template styling
                tab:SetNormalTexture("")
                tab:SetHighlightTexture("")
                tab:SetPushedTexture("")
                
                -- Apply modern styling
                local isActive = (HLBG.UI.activeTab == i)
                local bgColor = isActive and MODERN_COLORS.tabActive or MODERN_COLORS.tabInactive
                local textColor = isActive and MODERN_COLORS.titleText or MODERN_COLORS.tabTextInactive
                
                StyleModernButton(tab, bgColor, textColor)
                
                -- Custom click handler to update styling
                local originalOnClick = tab:GetScript("OnClick")
                tab:SetScript("OnClick", function(self, ...)
                    if originalOnClick then
                        originalOnClick(self, ...)
                    end
                    -- Update all tab styling after click
                    HLBG.UpdateModernTabStyling()
                end)
            end
        end
    end
    
    -- Modernize content areas
    HLBG.ModernizeContentAreas()
    
    print("|cFF33FF99HLBG:|r Modern UI styling applied")
end

-- Function to update tab styling based on active tab
function HLBG.UpdateModernTabStyling()
    if not HLBG.UI.Tabs then return end
    
    for i, tab in ipairs(HLBG.UI.Tabs) do
        if tab then
            local isActive = (HLBG.UI.activeTab == i)
            local bgColor = isActive and MODERN_COLORS.tabActive or MODERN_COLORS.tabInactive
            local textColor = isActive and MODERN_COLORS.titleText or MODERN_COLORS.tabTextInactive
            
            ApplyModernBackdrop(tab, bgColor, MODERN_COLORS.border, 1)
            
            local fontString = tab:GetFontString() or tab.Text
            if fontString then
                fontString:SetTextColor(unpack(textColor))
            end
        end
    end
end

-- Function to modernize content areas (History, Stats, etc.)
function HLBG.ModernizeContentAreas()
    -- History tab content
    if HLBG.UI.History and HLBG.UI.History.Content then
        ApplyModernBackdrop(HLBG.UI.History.Content, MODERN_COLORS.contentBg, nil, 1)
        
        -- Modernize history rows
        if HLBG.UI.History.rows then
            for i, row in ipairs(HLBG.UI.History.rows) do
                if row then
                    -- Alternating row colors
                    local bgColor = (i % 2 == 0) and MODERN_COLORS.rowAlt or {0, 0, 0, 0}
                    ApplyModernBackdrop(row, bgColor, nil, 0)
                    
                    -- Modern row hover effects
                    row:SetScript("OnEnter", function(self)
                        ApplyModernBackdrop(self, MODERN_COLORS.rowHover, MODERN_COLORS.border, 1)
                    end)
                    
                    row:SetScript("OnLeave", function(self)
                        ApplyModernBackdrop(self, bgColor, nil, 0)
                    end)
                end
            end
        end
    end
    
    -- Stats tab - apply modern card-like layout
    if HLBG.UI.Stats then
        -- Create modern stats cards if they don't exist
        HLBG.CreateModernStatsCards()
    end
    
    -- Info tab modernization
    if HLBG.UI.Info then
        ApplyModernBackdrop(HLBG.UI.Info, MODERN_COLORS.contentBg, MODERN_COLORS.border, 1)
    end
end

-- Function to create modern stats cards
function HLBG.CreateModernStatsCards()
    if not HLBG.UI.Stats then return end
    
    -- Create stats container if it doesn't exist
    if not HLBG.UI.Stats.modernContainer then
        HLBG.UI.Stats.modernContainer = CreateFrame("Frame", nil, HLBG.UI.Stats)
        HLBG.UI.Stats.modernContainer:SetAllPoints()
        ApplyModernBackdrop(HLBG.UI.Stats.modernContainer, MODERN_COLORS.contentBg, nil, 1)
    end
    
    local container = HLBG.UI.Stats.modernContainer
    
    -- Sample stats data structure
    local statsData = {
        {title = "Total Battles", value = "0", subtitle = "Participated"},
        {title = "Win Rate", value = "0%", subtitle = "Success Rate"},
        {title = "Best Score", value = "0", subtitle = "Personal Best"},
        {title = "Total Honor", value = "0", subtitle = "Honor Points"},
        {title = "Kills/Deaths", value = "0/0", subtitle = "K/D Ratio"},
        {title = "Avg Duration", value = "0:00", subtitle = "Battle Length"}
    }
    
    -- Create stat cards in 2x3 grid
    local cardWidth, cardHeight = 140, 80
    local padding = 10
    local startX, startY = 20, -20
    
    for i, stat in ipairs(statsData) do
        local col = ((i - 1) % 2) + 1
        local row = math.ceil(i / 2)
        
        local card = CreateFrame("Frame", nil, container)
        card:SetSize(cardWidth, cardHeight)
        card:SetPoint("TOPLEFT", container, "TOPLEFT", 
            startX + (col - 1) * (cardWidth + padding), 
            startY - (row - 1) * (cardHeight + padding))
        
        ApplyModernBackdrop(card, MODERN_COLORS.tabInactive, MODERN_COLORS.border, 1)
        
        -- Card title
        local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetPoint("TOP", card, "TOP", 0, -8)
        title:SetText(stat.title)
        title:SetTextColor(unpack(MODERN_COLORS.tabText))
        
        -- Card value (large)
        local value = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        value:SetPoint("CENTER", card, "CENTER", 0, 0)
        value:SetText(stat.value)
        value:SetTextColor(unpack(MODERN_COLORS.titleText))
        
        -- Card subtitle
        local subtitle = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        subtitle:SetPoint("BOTTOM", card, "BOTTOM", 0, 8)
        subtitle:SetText(stat.subtitle)
        subtitle:SetTextColor(0.6, 0.7, 0.8, 0.8)
        
        -- Hover effects
        card:EnableMouse(true)
        card:SetScript("OnEnter", function(self)
            ApplyModernBackdrop(self, MODERN_COLORS.rowHover, MODERN_COLORS.success, 1)
        end)
        
        card:SetScript("OnLeave", function(self)
            ApplyModernBackdrop(self, MODERN_COLORS.tabInactive, MODERN_COLORS.border, 1)
        end)
        
        -- Store references for updates
        card.titleText = title
        card.valueText = value
        card.subtitleText = subtitle
        
        container["card" .. i] = card
    end
    
    -- Add refresh button
    if not container.refreshBtn then
        container.refreshBtn = CreateFrame("Button", nil, container)
        container.refreshBtn:SetSize(100, 25)
        container.refreshBtn:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -20, 20)
        container.refreshBtn:SetText("Refresh Stats")
        
        StyleModernButton(container.refreshBtn, MODERN_COLORS.success, MODERN_COLORS.titleText)
        
        container.refreshBtn:SetScript("OnClick", function()
            HLBG.RefreshStatsCards()
        end)
    end
end

-- Function to refresh stats cards with actual data
function HLBG.RefreshStatsCards()
    if not HLBG.UI.Stats or not HLBG.UI.Stats.modernContainer then return end
    
    local container = HLBG.UI.Stats.modernContainer
    
    -- Try to get real data from saved variables or fallback to test data
    local statsData = HinterlandAffixHUDDB and HinterlandAffixHUDDB.playerStats or {}
    
    -- Update each card with available data
    local updates = {
        {card = "card1", value = tostring(statsData.totalBattles or 0)},
        {card = "card2", value = string.format("%.1f%%", (statsData.winRate or 0) * 100)},
        {card = "card3", value = tostring(statsData.bestScore or 0)},
        {card = "card4", value = tostring(statsData.totalHonor or 0)},
        {card = "card5", value = string.format("%d/%d", statsData.kills or 0, statsData.deaths or 0)},
        {card = "card6", value = string.format("%d:%02d", 
            math.floor((statsData.avgDuration or 0) / 60), 
            (statsData.avgDuration or 0) % 60)}
    }
    
    for _, update in ipairs(updates) do
        local card = container[update.card]
        if card and card.valueText then
            card.valueText:SetText(update.value)
        end
    end
    
    print("|cFF33FF99HLBG:|r Stats refreshed")
end

-- Enhanced empty tab handling with modern styling
function HLBG.ShowModernEmptyMessage(tabName, message)
    if not HLBG.UI[tabName] then return end
    
    local parent = HLBG.UI[tabName]
    
    -- Create modern empty state container
    if not parent.modernEmptyState then
        parent.modernEmptyState = CreateFrame("Frame", nil, parent)
        parent.modernEmptyState:SetAllPoints()
        
        -- Background
        ApplyModernBackdrop(parent.modernEmptyState, MODERN_COLORS.contentBg, nil, 1)
        
        -- Icon (uses a built-in WoW icon)
        parent.modernEmptyState.icon = parent.modernEmptyState:CreateTexture(nil, "ARTWORK")
        parent.modernEmptyState.icon:SetSize(48, 48)
        parent.modernEmptyState.icon:SetPoint("CENTER", parent.modernEmptyState, "CENTER", 0, 20)
        parent.modernEmptyState.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        parent.modernEmptyState.icon:SetVertexColor(0.6, 0.7, 0.8, 0.8)
        
        -- Title
        parent.modernEmptyState.title = parent.modernEmptyState:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        parent.modernEmptyState.title:SetPoint("TOP", parent.modernEmptyState.icon, "BOTTOM", 0, -10)
        parent.modernEmptyState.title:SetTextColor(unpack(MODERN_COLORS.titleText))
        
        -- Message
        parent.modernEmptyState.message = parent.modernEmptyState:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        parent.modernEmptyState.message:SetPoint("TOP", parent.modernEmptyState.title, "BOTTOM", 0, -10)
        parent.modernEmptyState.message:SetWidth(300)
        parent.modernEmptyState.message:SetTextColor(unpack(MODERN_COLORS.tabText))
        
        -- Action button
        parent.modernEmptyState.actionBtn = CreateFrame("Button", nil, parent.modernEmptyState)
        parent.modernEmptyState.actionBtn:SetSize(120, 30)
        parent.modernEmptyState.actionBtn:SetPoint("TOP", parent.modernEmptyState.message, "BOTTOM", 0, -20)
        parent.modernEmptyState.actionBtn:SetText("Load Test Data")
        
        StyleModernButton(parent.modernEmptyState.actionBtn, MODERN_COLORS.success, MODERN_COLORS.titleText)
        
        parent.modernEmptyState.actionBtn:SetScript("OnClick", function()
            if HLBG.LoadTestData then
                HLBG.LoadTestData()
                print("|cFF33FF99HLBG:|r Test data loaded")
            end
        end)
    end
    
    -- Update content
    parent.modernEmptyState.title:SetText("No " .. tabName .. " Data")
    parent.modernEmptyState.message:SetText(message or "No data available yet. Try loading test data or participating in battlegrounds.")
    parent.modernEmptyState:Show()
end

-- Initialize modern styling when addon loads
local modernFrame = CreateFrame("Frame")
modernFrame:RegisterEvent("ADDON_LOADED")
modernFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "HinterlandAffixHUD" or event == "PLAYER_ENTERING_WORLD" then
        -- Delay application to ensure UI is fully loaded
        local timer = C_Timer.NewTimer(1, function()
            HLBG.ApplyModernStyling()
        end)
    end
end)

-- Also apply on UI creation
if HLBG.UI and HLBG.UI.Frame then
    HLBG.ApplyModernStyling()
end

print("|cFF33FF99HLBG:|r Modern UI styling module loaded")