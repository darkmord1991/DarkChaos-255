-- DC-MythicPlus/UI/ScheduledTab.lua
-- Scheduled Runs tab for Group Finder - Plan future M+ or Raid events

local addonName = "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

local GF = namespace.GroupFinder
if not GF then return end

-- =====================================================================
-- Scheduled Events Data
-- =====================================================================

local EVENT_TYPES = {
    MYTHIC_PLUS = 1,
    RAID = 2,
    PVP = 3,
    OTHER = 4,
}

-- Sample scheduled events
local mockScheduledEvents = {
    {
        id = 1,
        type = EVENT_TYPES.RAID,
        title = "ICC 25 Heroic - Guild Run",
        description = "Weekly guild clear, all bosses including LK. Be prepared!",
        organizer = "GuildMaster",
        dateTime = "Sat 20:00",
        signups = 22,
        maxSignups = 25,
        confirmed = 18,
    },
    {
        id = 2,
        type = EVENT_TYPES.MYTHIC_PLUS,
        title = "+20 Key Push Night",
        description = "Looking to push high keys. 2k+ IO preferred.",
        organizer = "KeyPusher",
        dateTime = "Fri 21:00",
        signups = 5,
        maxSignups = 5,
        confirmed = 4,
    },
    {
        id = 3,
        type = EVENT_TYPES.RAID,
        title = "Ulduar Achievement Run",
        description = "Glory of the Ulduar Raider achievements. Know the fights!",
        organizer = "AchievementHunter",
        dateTime = "Sun 19:00",
        signups = 12,
        maxSignups = 10,
        confirmed = 8,
    },
}

-- =====================================================================
-- Create Scheduled Tab
-- =====================================================================

function GF:CreateScheduledTab()
    local parent = self.mainFrame.contentFrame
    
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()
    
    -- Header
    local headerFrame = CreateFrame("Frame", nil, frame)
    headerFrame:SetPoint("TOPLEFT", 0, 0)
    headerFrame:SetPoint("TOPRIGHT", 0, 0)
    headerFrame:SetHeight(50)
    
    local title = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("Scheduled Events")
    title:SetTextColor(1, 0.82, 0) -- Gold
    
    local desc = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    desc:SetText("Browse upcoming events or schedule your own runs.")
    desc:SetTextColor(0.7, 0.7, 0.7)
    
    -- Create Event button
    local createBtn = CreateFrame("Button", nil, headerFrame)
    createBtn:SetSize(120, 24)
    createBtn:SetPoint("TOPRIGHT", -10, -8)
    
    createBtn.bg = createBtn:CreateTexture(nil, "BACKGROUND")
    createBtn.bg:SetAllPoints()
    createBtn.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
    
    createBtn.border = CreateFrame("Frame", nil, createBtn)
    createBtn.border:SetPoint("TOPLEFT", -1, 1)
    createBtn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    createBtn.border:SetFrameLevel(createBtn:GetFrameLevel() - 1)
    local cBorder = createBtn.border:CreateTexture(nil, "BACKGROUND")
    cBorder:SetAllPoints()
    cBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    createBtn.text = createBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    createBtn.text:SetPoint("CENTER")
    createBtn.text:SetText("Create Event")
    createBtn.text:SetTextColor(1, 0.82, 0) -- Gold
    
    createBtn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.3, 0.3, 0.3, 1) end)
    createBtn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.2, 0.2, 0.2, 1) end)
    
    createBtn:SetScript("OnClick", function()
        GF:ShowCreateEventDialog()
    end)
    
    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, headerFrame)
    refreshBtn:SetSize(80, 24)
    refreshBtn:SetPoint("RIGHT", createBtn, "LEFT", -10, 0)
    
    refreshBtn.bg = refreshBtn:CreateTexture(nil, "BACKGROUND")
    refreshBtn.bg:SetAllPoints()
    refreshBtn.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
    
    refreshBtn.border = CreateFrame("Frame", nil, refreshBtn)
    refreshBtn.border:SetPoint("TOPLEFT", -1, 1)
    refreshBtn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    refreshBtn.border:SetFrameLevel(refreshBtn:GetFrameLevel() - 1)
    local rBorder = refreshBtn.border:CreateTexture(nil, "BACKGROUND")
    rBorder:SetAllPoints()
    rBorder:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    refreshBtn.text = refreshBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    refreshBtn.text:SetPoint("CENTER")
    refreshBtn.text:SetText("Refresh")
    refreshBtn.text:SetTextColor(1, 0.82, 0) -- Gold
    
    refreshBtn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.3, 0.3, 0.3, 1) end)
    refreshBtn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.2, 0.2, 0.2, 1) end)
    
    refreshBtn:SetScript("OnClick", function()
        GF:RefreshScheduledEvents()
    end)
    
    -- Event list scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "DCScheduledScroll", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -55)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 10)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(500, 1)  -- Initial size, will be updated
    scrollFrame:SetScrollChild(scrollChild)
    frame.scrollChild = scrollChild
    frame.scrollFrame = scrollFrame
    
    self.ScheduledTabContent = frame
    
    -- Delay population slightly to allow layout
    C_Timer.After(0.1, function()
        self:PopulateScheduledEvents(mockScheduledEvents)
    end)
end

function GF:PopulateScheduledEvents(events)
    if not self.ScheduledTabContent then return end
    local scrollChild = self.ScheduledTabContent.scrollChild
    if not scrollChild then return end
    
    -- Clear existing
    for _, child in ipairs({ scrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Get width from scroll frame or default
    local scrollFrame = scrollChild:GetParent()
    local contentWidth = scrollFrame and scrollFrame:GetWidth() or 500
    if contentWidth < 100 then contentWidth = 500 end  -- Fallback if not yet laid out
    scrollChild:SetWidth(contentWidth)
    
    local yOffset = 0
    local rowHeight = 90
    
    GF.Print("Populating " .. #events .. " scheduled events")
    
    for i, event in ipairs(events) do
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(contentWidth - 40, rowHeight - 4)
        row:SetPoint("TOPLEFT", 5, -yOffset)
        
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0.1, 0.12, 0.15, 0.9)
        
        -- Event type icon/badge
        local typeBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        typeBadge:SetPoint("TOPLEFT", 10, -8)
        if event.type == EVENT_TYPES.MYTHIC_PLUS then
            typeBadge:SetText("|cff32c4ff[M+]|r")
        elseif event.type == EVENT_TYPES.RAID then
            typeBadge:SetText("|cffff9900[RAID]|r")
        elseif event.type == EVENT_TYPES.PVP then
            typeBadge:SetText("|cffff4444[PVP]|r")
        else
            typeBadge:SetText("|cff888888[EVENT]|r")
        end
        
        -- Title
        local titleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        titleText:SetPoint("LEFT", typeBadge, "RIGHT", 10, 0)
        titleText:SetText(event.title)
        
        -- Date/Time
        local dateText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        dateText:SetPoint("TOPRIGHT", -90, -8)
        dateText:SetText("|cff44ff44" .. event.dateTime .. "|r")
        
        -- Description
        local descText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        descText:SetPoint("TOPLEFT", 10, -28)
        descText:SetPoint("RIGHT", -100, 0)
        descText:SetJustifyH("LEFT")
        descText:SetText(event.description)
        descText:SetTextColor(0.7, 0.7, 0.7)
        
        -- Organizer
        local orgText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        orgText:SetPoint("BOTTOMLEFT", 10, 20)
        orgText:SetText("Organizer: |cffffffff" .. event.organizer .. "|r")
        
        -- Signups
        local signupText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        signupText:SetPoint("BOTTOMLEFT", 10, 6)
        local signupColor = event.signups >= event.maxSignups and "ffaa44" or "44ff44"
        signupText:SetText(string.format("Signups: |cff%s%d/%d|r  (Confirmed: %d)",
            signupColor, event.signups, event.maxSignups, event.confirmed))
        
        -- Sign Up button
        local signupBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        signupBtn:SetSize(80, 26)
        signupBtn:SetPoint("RIGHT", -10, 0)
        
        if event.signups >= event.maxSignups then
            signupBtn:SetText("Full")
            signupBtn:Disable()
        else
            signupBtn:SetText("Sign Up")
            signupBtn:SetScript("OnClick", function()
                GF:SignUpForEvent(event.id, event.title)
            end)
        end
        
        yOffset = yOffset + rowHeight
    end
    
    scrollChild:SetHeight(yOffset)
    
    -- Show or hide empty state
    if #events == 0 then
        if not self.ScheduledTabContent.emptyText then
            local emptyText = self.ScheduledTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            emptyText:SetPoint("CENTER", 0, 20)
            emptyText:SetText("|cff666666No scheduled events|r")
            self.ScheduledTabContent.emptyText = emptyText
            
            local emptySubtext = self.ScheduledTabContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            emptySubtext:SetPoint("TOP", emptyText, "BOTTOM", 0, -8)
            emptySubtext:SetText("|cff555555Click 'Create Event' to schedule a new run|r")
            self.ScheduledTabContent.emptySubtext = emptySubtext
        end
        if self.ScheduledTabContent.emptyText then self.ScheduledTabContent.emptyText:Show() end
        if self.ScheduledTabContent.emptySubtext then self.ScheduledTabContent.emptySubtext:Show() end
    else
        if self.ScheduledTabContent.emptyText then self.ScheduledTabContent.emptyText:Hide() end
        if self.ScheduledTabContent.emptySubtext then self.ScheduledTabContent.emptySubtext:Hide() end
    end
end

function GF:RefreshScheduledEvents()
    GF.Print("Refreshing scheduled events...")
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("MPLUS", 0x30, { action = "list_scheduled" })
    else
        -- Demo mode - use mock data
        self:PopulateScheduledEvents(mockScheduledEvents)
    end
end

function GF:SignUpForEvent(eventId, eventTitle)
    GF.Print("Signing up for: " .. eventTitle)
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("MPLUS", 0x31, { event_id = eventId })
    end
end

-- =====================================================================
-- Create Event Dialog
-- =====================================================================

function GF:ShowCreateEventDialog()
    if self.createEventDialog then
        self.createEventDialog:Show()
        return
    end
    
    local dialog = CreateFrame("Frame", "DCCreateEventDialog", UIParent)
    dialog:SetSize(400, 350)
    dialog:SetPoint("CENTER")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetToplevel(true)
    
    dialog.bg = dialog:CreateTexture(nil, "BACKGROUND")
    dialog.bg:SetAllPoints()
    dialog.bg:SetColorTexture(0.05, 0.05, 0.1, 0.98)
    
    -- Border (3.3.5a compatible)
    local border = CreateFrame("Frame", nil, dialog)
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    border:SetBackdropBorderColor(0.4, 0.7, 1.0, 0.9)
    
    -- Title
    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Create Scheduled Event")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() dialog:Hide() end)
    
    local y = -50
    
    -- Event Title
    local titleLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("TOPLEFT", 20, y)
    titleLabel:SetText("Event Title:")
    
    local titleEdit = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    titleEdit:SetSize(250, 22)
    titleEdit:SetPoint("TOPLEFT", 120, y + 5)
    titleEdit:SetAutoFocus(false)
    titleEdit:SetMaxLetters(60)
    dialog.titleEdit = titleEdit
    y = y - 30
    
    -- Event Type
    local typeLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeLabel:SetPoint("TOPLEFT", 20, y)
    typeLabel:SetText("Type:")
    
    local typeBtn = CreateFrame("Button", nil, dialog)
    typeBtn:SetSize(120, 24)
    typeBtn:SetPoint("TOPLEFT", 120, y + 3)
    typeBtn.bg = typeBtn:CreateTexture(nil, "BACKGROUND")
    typeBtn.bg:SetAllPoints()
    typeBtn.bg:SetColorTexture(0.2, 0.2, 0.25, 0.9)
    typeBtn.text = typeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    typeBtn.text:SetPoint("CENTER")
    typeBtn.text:SetText("Mythic+")
    dialog.typeBtn = typeBtn
    dialog.selectedType = EVENT_TYPES.MYTHIC_PLUS
    y = y - 30
    
    -- Date/Time
    local dateLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dateLabel:SetPoint("TOPLEFT", 20, y)
    dateLabel:SetText("Date/Time:")
    
    local dateEdit = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    dateEdit:SetSize(150, 22)
    dateEdit:SetPoint("TOPLEFT", 120, y + 5)
    dateEdit:SetAutoFocus(false)
    dateEdit:SetMaxLetters(30)
    dateEdit:SetText("Sat 20:00")
    dialog.dateEdit = dateEdit
    y = y - 30
    
    -- Max Signups
    local maxLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    maxLabel:SetPoint("TOPLEFT", 20, y)
    maxLabel:SetText("Max Signups:")
    
    local maxEdit = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    maxEdit:SetSize(50, 22)
    maxEdit:SetPoint("TOPLEFT", 120, y + 5)
    maxEdit:SetAutoFocus(false)
    maxEdit:SetNumeric(true)
    maxEdit:SetMaxLetters(2)
    maxEdit:SetText("10")
    dialog.maxEdit = maxEdit
    y = y - 30
    
    -- Description
    local descLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", 20, y)
    descLabel:SetText("Description:")
    y = y - 20
    
    local descFrame = CreateFrame("Frame", nil, dialog)
    descFrame:SetSize(360, 80)
    descFrame:SetPoint("TOPLEFT", 20, y)
    descFrame.bg = descFrame:CreateTexture(nil, "BACKGROUND")
    descFrame.bg:SetAllPoints()
    descFrame.bg:SetColorTexture(0.1, 0.1, 0.15, 0.9)
    
    local descEdit = CreateFrame("EditBox", nil, descFrame)
    descEdit:SetSize(350, 70)
    descEdit:SetPoint("TOPLEFT", 5, -5)
    descEdit:SetMultiLine(true)
    descEdit:SetAutoFocus(false)
    descEdit:SetMaxLetters(200)
    descEdit:SetFontObject(GameFontHighlight)
    dialog.descEdit = descEdit
    y = y - 95
    
    -- Create button
    local createBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    createBtn:SetSize(120, 30)
    createBtn:SetPoint("BOTTOM", 0, 15)
    createBtn:SetText("Create Event")
    createBtn:SetScript("OnClick", function()
        local eventData = {
            title = dialog.titleEdit:GetText(),
            type = dialog.selectedType,
            dateTime = dialog.dateEdit:GetText(),
            maxSignups = tonumber(dialog.maxEdit:GetText()) or 10,
            description = dialog.descEdit:GetText(),
        }
        GF:CreateScheduledEvent(eventData)
        dialog:Hide()
    end)
    
    self.createEventDialog = dialog
    tinsert(UISpecialFrames, "DCCreateEventDialog")
end

function GF:CreateScheduledEvent(eventData)
    GF.Print("Creating event: " .. eventData.title)
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        DC:Request("MPLUS", 0x32, eventData)
    end
end

GF.Print("Scheduled Events tab module loaded")
