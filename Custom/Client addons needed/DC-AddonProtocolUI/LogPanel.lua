-- LogPanel.lua - Request/response log viewer for DC-AddonProtocol.
--
-- Lifted verbatim out of DCAddonProtocol.lua, where it sat inline in a
-- 5,838-line file that every DC addon hard-depends on. The panel is opened by
-- `/dc log`; before this split, every player paid for its ~620 lines at every
-- login in order to never open it.
--
-- Stats *collection* deliberately stayed in the core (DC:UpdateStats is called
-- from the logging path on every request). Only the rendering lives here.

local DC = DCAddonProtocol
if not DC then
    return
end

-- Get module statistics as leaderboard-style sorted list
function DC:GetModuleLeaderboard()
    local list = {}
    for mod, stats in pairs(self._stats.moduleStats) do
        table.insert(list, {
            module = mod,
            moduleName = self.ModuleNames[mod] or mod,
            requests = stats.requests,
            "  Request Log: " .. DC:GetRequestLogCount(),
            "  Response Log: " .. DC:GetResponseLogCount(),
            successRate = stats.requests > 0 and math.min(100, math.floor((stats.responses / stats.requests) * 100)) or 0,
            avgResponseTime = stats.avgResponseTime,
        })
    end
    
    -- Sort by requests (most active first)
    table.sort(list, function(a, b) return a.requests > b.requests end)
    
    return list
end

function DC:ShowLogPanel()
    if self.LogPanel then
        self.LogPanel:Show()
        self:RefreshLogPanel()
        return
    end
    
    -- Create the log panel (wider for leaderboard style)
    local frame = CreateFrame("Frame", "DCProtocolLogPanel", UIParent)
    frame:SetSize(850, 550)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- Background (match DC-Leaderboards)
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints()
    bg:SetTexture("Interface\\DC\\Shared\\FelLeather_512.tga")
    if bg.SetHorizTile then bg:SetHorizTile(false) end
    if bg.SetVertTile then bg:SetVertTile(false) end

    local bgTint = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    bgTint:SetAllPoints()
    bgTint:SetTexture(0, 0, 0, 0.60)
    frame.__dcTint = bgTint
    
    -- Border
    local border = CreateFrame("Frame", nil, frame)
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    
    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetSize(830, 28)
    titleBar:SetPoint("TOP", 0, -8)
    local titleBarBg = titleBar:CreateTexture(nil, "ARTWORK")
    titleBarBg:SetAllPoints()
    titleBarBg:SetTexture(0.15, 0.15, 0.15, 0.6)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("|cff00ff00DC Protocol Monitor|r")
    
    -- Subtitle with session info
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    subtitle:SetText("|cff888888Request/Response Tracking & Statistics|r")
    frame.subtitle = subtitle
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    tinsert(UISpecialFrames, "DCProtocolLogPanel")
    
    -- Left panel: Statistics summary
    local statsPanel = CreateFrame("Frame", nil, frame)
    statsPanel:SetSize(200, 460)
    statsPanel:SetPoint("TOPLEFT", 15, -50)
    frame.statsPanel = statsPanel
    
    local statsBg = statsPanel:CreateTexture(nil, "BACKGROUND")
    statsBg:SetAllPoints()
    statsBg:SetTexture(0.12, 0.12, 0.12, 0.8)
    
    local statsTitle = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsTitle:SetPoint("TOP", 0, -10)
    statsTitle:SetText("|cffffd700Session Statistics|r")
    
    -- Stats will be populated in RefreshLogPanel
    frame.statsLabels = {}
    
    -- Right panel: Tab content area
    local contentPanel = CreateFrame("Frame", nil, frame)
    contentPanel:SetSize(610, 460)
    contentPanel:SetPoint("TOPRIGHT", -15, -50)
    frame.contentPanel = contentPanel
    
    -- Tab buttons (inside content panel)
    local tabFrame = CreateFrame("Frame", nil, contentPanel)
    tabFrame:SetSize(610, 28)
    tabFrame:SetPoint("TOP", 0, 0)
    
    local tabs = {
        { id = "requests", label = "Requests", icon = "Interface\\Icons\\INV_Letter_15" },
        { id = "responses", label = "Responses", icon = "Interface\\Icons\\INV_Letter_16" },
        { id = "pending", label = "Pending", icon = "Interface\\Icons\\Spell_Holy_BorrowedTime" },
        { id = "modules", label = "By Module", icon = "Interface\\Icons\\Trade_Engineering" },
    }
    
    frame.tabButtons = {}
    local tabX = 0
    for _, tab in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, tabFrame)
        btn:SetSize(145, 26)
        btn:SetPoint("LEFT", tabX, 0)
        
        local btnBg = btn:CreateTexture(nil, "BACKGROUND")
        btnBg:SetAllPoints()
        btnBg:SetTexture(0.2, 0.2, 0.2, 0.8)
        btn.bg = btnBg
        
        local btnIcon = btn:CreateTexture(nil, "ARTWORK")
        btnIcon:SetSize(18, 18)
        btnIcon:SetPoint("LEFT", 5, 0)
        btnIcon:SetTexture(tab.icon)
        
        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btnText:SetPoint("LEFT", btnIcon, "RIGHT", 5, 0)
        btnText:SetText(tab.label)
        btn.text = btnText
        
        btn:SetScript("OnClick", function()
            frame.currentTab = tab.id
            DC:RefreshLogPanel()
        end)
        
        btn:SetScript("OnEnter", function(self)
            if frame.currentTab ~= tab.id then
                self.bg:SetTexture(0.3, 0.3, 0.3, 0.8)
            end
        end)
        
        btn:SetScript("OnLeave", function(self)
            if frame.currentTab ~= tab.id then
                self.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
            end
        end)
        
        frame.tabButtons[tab.id] = btn
        tabX = tabX + 150
    end
    
    -- Action buttons
    local clearBtn = CreateFrame("Button", nil, contentPanel, "UIPanelButtonTemplate")
    clearBtn:SetSize(70, 20)
    clearBtn:SetPoint("TOPRIGHT", 0, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        DC:ClearLogs()
        DC._stats = {
            totalRequests = 0,
            totalResponses = 0,
            totalTimeouts = 0,
            avgResponseTime = 0,
            moduleStats = {},
            sessionStart = time(),
        }
        DC:RefreshLogPanel()
    end)
    
    -- Column headers (dynamic based on tab)
    local headerFrame = CreateFrame("Frame", nil, contentPanel)
    headerFrame:SetSize(590, 22)
    headerFrame:SetPoint("TOP", tabFrame, "BOTTOM", 0, -5)
    frame.headerFrame = headerFrame
    
    local headerBg = headerFrame:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetTexture(0.18, 0.18, 0.18, 0.9)
    
    frame.headerLabels = {}
    
    -- Scroll frame for entries
    local scrollFrame = CreateFrame("ScrollFrame", "DCLogScrollFrame", contentPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(590, 380)
    scrollFrame:SetPoint("TOP", headerFrame, "BOTTOM", 0, -2)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(570, 1)
    scrollFrame:SetScrollChild(scrollChild)
    frame.scrollChild = scrollChild
    
    -- Bottom status bar
    local statusBar = CreateFrame("Frame", nil, frame)
    statusBar:SetSize(820, 20)
    statusBar:SetPoint("BOTTOM", 0, 10)
    
    local statusText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("LEFT", 20, 0)
    statusText:SetText("|cff888888Session started: " .. date("%H:%M:%S") .. "|r")
    frame.statusText = statusText
    
    frame.currentTab = "requests"
    frame.entryFrames = {}
    
    self.LogPanel = frame
    self:RefreshLogPanel()
end

function DC:RefreshLogPanel()
    if not self.LogPanel then return end
    
    local frame = self.LogPanel
    local scrollChild = frame.scrollChild
    local headerFrame = frame.headerFrame
    
    -- Update statistics panel
    self:UpdateStatsPanel()
    
    -- Clear existing entries
    for _, entryFrame in ipairs(frame.entryFrames) do
        entryFrame:Hide()
        entryFrame:SetParent(nil)
    end
    frame.entryFrames = {}
    
    -- Clear header labels
    for _, label in ipairs(frame.headerLabels) do
        label:SetText("")
    end
    
    -- Update tab highlighting
    for id, btn in pairs(frame.tabButtons) do
        if frame.currentTab == id then
            btn.bg:SetTexture(0.2, 0.4, 0.2, 0.9)
            btn.text:SetText("|cff00ff00" .. btn.text:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "|r")
        else
            btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
            btn.text:SetText(btn.text:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
        end
    end
    
    -- Setup columns and get data based on current tab
    local columns, entries
    
    if frame.currentTab == "requests" then
        columns = {
            { x = 5, width = 55, label = "#" },
            { x = 40, width = 65, label = "Time" },
            { x = 110, width = 100, label = "Module" },
            { x = 210, width = 60, label = "Opcode" },
            { x = 280, width = 80, label = "Status" },
            { x = 370, width = 200, label = "Data Preview" },
        }
        entries = self:GetRequestLog(50)
        
    elseif frame.currentTab == "responses" then
        columns = {
            { x = 5, width = 55, label = "#" },
            { x = 40, width = 65, label = "Time" },
            { x = 110, width = 100, label = "Module" },
            { x = 210, width = 60, label = "Opcode" },
            { x = 280, width = 70, label = "Size" },
            { x = 360, width = 210, label = "Data Preview" },
        }
        entries = self:GetResponseLog(50)
        
    elseif frame.currentTab == "pending" then
        columns = {
            { x = 5, width = 55, label = "#" },
            { x = 40, width = 65, label = "Time" },
            { x = 110, width = 100, label = "Module" },
            { x = 210, width = 60, label = "Opcode" },
            { x = 280, width = 70, label = "Age" },
            { x = 360, width = 80, label = "Status" },
            { x = 450, width = 120, label = "Data" },
        }
        entries = self:GetPendingRequests()
        
    elseif frame.currentTab == "modules" then
        columns = {
            { x = 5, width = 40, label = "Rank" },
            { x = 50, width = 120, label = "Module" },
            { x = 180, width = 70, label = "Requests" },
            { x = 260, width = 70, label = "Responses" },
            { x = 340, width = 60, label = "Timeouts" },
            { x = 410, width = 80, label = "Success %" },
            { x = 500, width = 70, label = "Avg Time" },
        }
        entries = self:GetModuleLeaderboard()
    end
    
    -- Create header labels
    for i, col in ipairs(columns) do
        local label = frame.headerLabels[i]
        if not label then
            label = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            frame.headerLabels[i] = label
        end
        label:ClearAllPoints()
        label:SetPoint("LEFT", col.x, 0)
        label:SetText("|cffffd700" .. col.label .. "|r")
    end
    
    -- Create entry rows
    local yOffset = 0
    local rowHeight = 24
    
    for i, entry in ipairs(entries) do
        local row = CreateFrame("Button", nil, scrollChild)
        row:SetSize(570, rowHeight)
        row:SetPoint("TOPLEFT", 0, yOffset)
        
        -- Alternating background with hover
        local rowBg = row:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints()
        local bgColor = i % 2 == 0 and 0.14 or 0.10
        rowBg:SetTexture(bgColor, bgColor, bgColor, 0.7)
        row.bg = rowBg
        row.bgColor = bgColor
        
        row:SetScript("OnEnter", function(self)
            self.bg:SetTexture(0.25, 0.25, 0.3, 0.8)
        end)
        row:SetScript("OnLeave", function(self)
            self.bg:SetTexture(self.bgColor, self.bgColor, self.bgColor, 0.7)
        end)
        
        -- Populate based on tab
        if frame.currentTab == "modules" then
            -- Module leaderboard row
            self:CreateModuleRow(row, entry, i, columns)
        else
            -- Log entry row
            self:CreateLogRow(row, entry, i, columns, frame.currentTab)
        end
        
        table.insert(frame.entryFrames, row)
        yOffset = yOffset - rowHeight
    end
    
    -- Update scroll child height
    scrollChild:SetHeight(math.max(1, math.abs(yOffset)))
    
    -- Show empty message if no entries
    if #entries == 0 then
        local emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyText:SetPoint("CENTER", 0, 50)
        emptyText:SetText("|cff666666No " .. frame.currentTab .. " to display|r")
        local emptyFrame = CreateFrame("Frame", nil, scrollChild)
        emptyFrame:SetAllPoints()
        table.insert(frame.entryFrames, emptyFrame)
    end
    
    -- Update status bar
    local sessionTime = time() - self._stats.sessionStart
    local hours = math.floor(sessionTime / 3600)
    local mins = math.floor((sessionTime % 3600) / 60)
    local secs = sessionTime % 60
    frame.statusText:SetText(string.format(
        "|cff888888Session: %02d:%02d:%02d | Requests: %d | Responses: %d | Timeouts: %d|r",
        hours, mins, secs,
        self._stats.totalRequests,
        self._stats.totalResponses,
        self._stats.totalTimeouts
    ))
end

function DC:CreateLogRow(row, entry, index, columns, tabType)
    -- Row number
    local numText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    numText:SetPoint("LEFT", columns[1].x, 0)
    numText:SetText("|cff888888" .. index .. "|r")
    
    -- Time
    local timeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeText:SetPoint("LEFT", columns[2].x, 0)
    timeText:SetText("|cffffffff" .. (entry.timeStr or "--:--:--") .. "|r")
    
    -- Module with color
    local modText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modText:SetPoint("LEFT", columns[3].x, 0)
    local modColor = self:GetModuleColor(entry.module)
    modText:SetText(modColor .. (entry.moduleName or entry.module or "?") .. "|r")
    
    -- Opcode
    local opText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    opText:SetPoint("LEFT", columns[4].x, 0)
    opText:SetText("|cffffff00" .. string.format("0x%02X", entry.opcode or 0) .. "|r")
    
    if tabType == "requests" then
        -- Status
        local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusText:SetPoint("LEFT", columns[5].x, 0)
        local statusColor = entry.status == "completed" and "|cff00ff00" or 
                           (entry.status == "timeout" and "|cffff0000" or "|cffffff00")
        statusText:SetText(statusColor .. (entry.status or "?") .. "|r")
        
        -- Data preview
        local dataText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dataText:SetPoint("LEFT", columns[6].x, 0)
        dataText:SetWidth(190)
        dataText:SetJustifyH("LEFT")
        dataText:SetText("|cff888888" .. self:FormatDataPreview(entry.data, 40) .. "|r")
        
    elseif tabType == "responses" then
        -- Size
        local sizeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sizeText:SetPoint("LEFT", columns[5].x, 0)
        local size = entry.jsonLength or 0
        local sizeColor = size > 1000 and "|cffff8800" or "|cff00ff00"
        sizeText:SetText(sizeColor .. size .. " B|r")
        
        -- Data preview
        local dataText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dataText:SetPoint("LEFT", columns[6].x, 0)
        dataText:SetWidth(200)
        dataText:SetJustifyH("LEFT")
        dataText:SetText("|cff888888" .. self:FormatDataPreview(entry.data, 45) .. "|r")
        
    elseif tabType == "pending" then
        -- Age
        local ageText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ageText:SetPoint("LEFT", columns[5].x, 0)
        local age = time() - (entry.timestamp or time())
        local ageColor = age > 10 and "|cffff0000" or (age > 5 and "|cffffff00" or "|cff00ff00")
        ageText:SetText(ageColor .. age .. "s|r")
        
        -- Status
        local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusText:SetPoint("LEFT", columns[6].x, 0)
        local statusColor = age > 30 and "|cffff0000" or "|cffffff00"
        statusText:SetText(statusColor .. (age > 30 and "TIMEOUT" or "waiting...") .. "|r")
        
        -- Data
        local dataText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        dataText:SetPoint("LEFT", columns[7].x, 0)
        dataText:SetWidth(110)
        dataText:SetJustifyH("LEFT")
        dataText:SetText("|cff888888" .. self:FormatDataPreview(entry.data, 25) .. "|r")
    end
end

function DC:CreateModuleRow(row, entry, index, columns)
    -- Rank with medal colors
    local rankText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankText:SetPoint("LEFT", columns[1].x, 0)
    local rankColor = index == 1 and "|cffffff00" or (index == 2 and "|cffc0c0c0" or (index == 3 and "|cffcd7f32" or "|cffffffff"))
    rankText:SetText(rankColor .. "#" .. index .. "|r")
    
    -- Module name
    local modText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modText:SetPoint("LEFT", columns[2].x, 0)
    local modColor = self:GetModuleColor(entry.module)
    modText:SetText(modColor .. entry.moduleName .. "|r")
    
    -- Requests count
    local reqText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reqText:SetPoint("LEFT", columns[3].x, 0)
    reqText:SetText("|cff00ccff" .. entry.requests .. "|r")
    
    -- Responses count
    local respText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    respText:SetPoint("LEFT", columns[4].x, 0)
    respText:SetText("|cff00ff00" .. entry.responses .. "|r")
    
    -- Timeouts count
    local timeoutText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeoutText:SetPoint("LEFT", columns[5].x, 0)
    local toColor = entry.timeouts > 0 and "|cffff0000" or "|cff888888"
    timeoutText:SetText(toColor .. entry.timeouts .. "|r")
    
    -- Success rate with color gradient
    local successText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    successText:SetPoint("LEFT", columns[6].x, 0)
    local successColor = entry.successRate >= 90 and "|cff00ff00" or 
                        (entry.successRate >= 70 and "|cffffff00" or "|cffff0000")
    successText:SetText(successColor .. entry.successRate .. "%|r")
    
    -- Average response time
    local avgText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    avgText:SetPoint("LEFT", columns[7].x, 0)
    avgText:SetText("|cff888888" .. string.format("%.1fs", entry.avgResponseTime or 0) .. "|r")
end

function DC:UpdateStatsPanel()
    if not self.LogPanel or not self.LogPanel.statsPanel then return end
    
    local panel = self.LogPanel.statsPanel
    
    -- Clear existing stat labels
    for _, child in pairs({panel:GetChildren()}) do
        child:Hide()
    end
    
    local yOffset = -35
    local stats = {
        { label = "Total Requests", value = self._stats.totalRequests, color = "|cff00ccff" },
        { label = "Total Responses", value = self._stats.totalResponses, color = "|cff00ff00" },
        { label = "Total Timeouts", value = self._stats.totalTimeouts, color = self._stats.totalTimeouts > 0 and "|cffff0000" or "|cff888888" },
        { label = "", value = "", color = "" }, -- Spacer
        { label = "Pending Requests", value = #self:GetPendingRequests(), color = "|cffffff00" },
        { label = "Active Modules", value = self:CountTable(self._stats.moduleStats), color = "|cff00ff00" },
    }
    
    for _, stat in ipairs(stats) do
        if stat.label ~= "" then
            local labelText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            labelText:SetPoint("TOPLEFT", 10, yOffset)
            labelText:SetText("|cff888888" .. stat.label .. ":|r")
            
            local valueText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            valueText:SetPoint("TOPRIGHT", -10, yOffset)
            valueText:SetText(stat.color .. tostring(stat.value) .. "|r")
        end
        yOffset = yOffset - 20
    end
    
    -- Response rate (capped at 100% since server can push messages without requests)
    local responseRate = self._stats.totalRequests > 0 and 
        math.min(100, math.floor((self._stats.totalResponses / self._stats.totalRequests) * 100)) or 0
    
    yOffset = yOffset - 10
    local rateLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rateLabel:SetPoint("TOPLEFT", 10, yOffset)
    rateLabel:SetText("|cffffd700Response Rate:|r")
    
    yOffset = yOffset - 25
    local rateValue = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rateValue:SetPoint("TOP", 0, yOffset)
    local rateColor = responseRate >= 90 and "|cff00ff00" or 
                     (responseRate >= 70 and "|cffffff00" or "|cffff0000")
    rateValue:SetText(rateColor .. responseRate .. "%|r")
    
    -- Session time
    yOffset = yOffset - 40
    local sessionLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sessionLabel:SetPoint("TOPLEFT", 10, yOffset)
    sessionLabel:SetText("|cff888888Session Time:|r")
    
    local sessionTime = time() - self._stats.sessionStart
    local hours = math.floor(sessionTime / 3600)
    local mins = math.floor((sessionTime % 3600) / 60)
    local secs = sessionTime % 60
    
    yOffset = yOffset - 18
    local sessionValue = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sessionValue:SetPoint("TOP", 0, yOffset)
    sessionValue:SetText(string.format("|cffffffff%02d:%02d:%02d|r", hours, mins, secs))
    
    -- Most active module
    local moduleList = self:GetModuleLeaderboard()
    if #moduleList > 0 then
        yOffset = yOffset - 30
        local topLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        topLabel:SetPoint("TOPLEFT", 10, yOffset)
        topLabel:SetText("|cffffd700Most Active:|r")
        
        yOffset = yOffset - 18
        local topValue = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        topValue:SetPoint("TOP", 0, yOffset)
        local modColor = self:GetModuleColor(moduleList[1].module)
        topValue:SetText(modColor .. moduleList[1].moduleName .. "|r")
        
        yOffset = yOffset - 15
        local topCount = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        topCount:SetPoint("TOP", 0, yOffset)
        topCount:SetText("|cff888888(" .. moduleList[1].requests .. " requests)|r")
    end
end

function DC:GetModuleColor(module)
    local colors = {
        CORE = "|cff00ff00",
        AOE = "|cffff8800",
        SPOT = "|cff00ccff",
        UPG = "|cffa335ee",
        SPEC = "|cff0070dd",
        DUEL = "|cffff0000",
        MPLUS = "|cffff8000",
        SEAS = "|cffffff00",
        PRES = "|cffff00ff",
        HLBG = "|cff00ff00",
        LBRD = "|cff00ff96",
        WELC = "|cff00ccff",
        GRPF = "|cff0070dd",
        GOMV = "|cffff8800",
        TELE = "|cffa335ee",
        EVNT = "|cffffff00",
        WRLD = "|cff00ff00",
        COLL = "|cffff00ff",
    }
    return colors[module] or "|cffffffff"
end

function DC:FormatDataPreview(data, maxLen)
    if not data then return "-" end
    
    local preview = ""
    if type(data) == "table" then
        preview = self:EncodeJSON(data)
    else
        preview = tostring(data)
    end
    
    if string.len(preview) > maxLen then
        preview = string.sub(preview, 1, maxLen - 3) .. "..."
    end
    
    return preview
end
