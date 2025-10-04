-- HLBG_Debug_Helper.lua
-- Enhanced debugging tools for the Hinterland BG addon

-- Ensure HLBG namespace exists
HLBG = HLBG or {}
HLBG.Debug = HLBG.Debug or {}

-- Debug levels
HLBG.Debug.LEVEL_OFF = 0
HLBG.Debug.LEVEL_ERROR = 1
HLBG.Debug.LEVEL_WARNING = 2
HLBG.Debug.LEVEL_INFO = 3
HLBG.Debug.LEVEL_VERBOSE = 4

-- Current debug level (default to errors only)
HLBG.Debug.level = HLBG.Debug.LEVEL_ERROR

-- Color codes for different message types
HLBG.Debug.colors = {
    error = "|cFFFF0000", -- Red
    warning = "|cFFFF9900", -- Orange
    info = "|cFF00CCFF", -- Light Blue
    verbose = "|cFF888888", -- Gray
    highlight = "|cFFFFFF00", -- Yellow
    success = "|cFF00FF00" -- Green
}

-- Frame to display debug messages
HLBG.Debug.CreateDebugFrame = function()
    if HLBG.Debug.Frame then return HLBG.Debug.Frame end
    
    local frame = CreateFrame("Frame", "HLBG_DebugFrame", UIParent)
    frame:SetSize(500, 300)
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 100)
    -- Using standard backdrop to ensure WoW 3.3.5a compatibility
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -10)
    title:SetText("HLBG Debug")
    
    -- Close button
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    
    -- ScrollFrame
    local scroll = CreateFrame("ScrollFrame", "HLBG_DebugScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)
    
    -- Content frame
    local content = CreateFrame("Frame", "HLBG_DebugScrollContent", scroll)
    content:SetSize(frame:GetWidth() - 40, 400)
    scroll:SetScrollChild(content)
    
    -- Messages
    content.messages = {}
    content.messageCount = 0
    
    -- Clear button
    local clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clear:SetSize(60, 20)
    clear:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
    clear:SetText("Clear")
    clear:SetScript("OnClick", function()
        for _, msg in ipairs(content.messages) do
            msg:Hide()
        end
        content.messages = {}
        content.messageCount = 0
        content:SetHeight(1)
    end)
    
    -- Level dropdown
    local dropdown = CreateFrame("Frame", "HLBG_DebugLevelDropDown", frame, "UIDropDownMenuTemplate")
    dropdown:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)
    
    UIDropDownMenu_SetWidth(dropdown, 100)
    UIDropDownMenu_SetText(dropdown, "Debug Level")
    
    UIDropDownMenu_Initialize(dropdown, function(self, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        
        local levels = {
            {text = "Off", value = HLBG.Debug.LEVEL_OFF},
            {text = "Errors", value = HLBG.Debug.LEVEL_ERROR},
            {text = "Warnings", value = HLBG.Debug.LEVEL_WARNING},
            {text = "Info", value = HLBG.Debug.LEVEL_INFO},
            {text = "Verbose", value = HLBG.Debug.LEVEL_VERBOSE}
        }
        
        for _, item in ipairs(levels) do
            info.text = item.text
            info.value = item.value
            info.checked = (HLBG.Debug.level == item.value)
            info.func = function()
                HLBG.Debug.level = item.value
                UIDropDownMenu_SetText(dropdown, item.text)
                HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
                HinterlandAffixHUDDB.debugLevel = item.value
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    -- Initialize with saved level
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    HLBG.Debug.level = HinterlandAffixHUDDB.debugLevel or HLBG.Debug.LEVEL_ERROR
    
    local levelTexts = {"Off", "Errors", "Warnings", "Info", "Verbose"}
    UIDropDownMenu_SetText(dropdown, levelTexts[HLBG.Debug.level + 1] or "Errors")
    
    HLBG.Debug.Frame = frame
    HLBG.Debug.Content = content
    
    return frame
end

-- Add a message to the debug frame
HLBG.Debug.AddMessage = function(text, level, color)
    if not HLBG.Debug.Frame then
        HLBG.Debug.CreateDebugFrame()
    end
    
    local content = HLBG.Debug.Content
    level = level or HLBG.Debug.LEVEL_INFO
    
    -- Only show if our debug level is high enough
    if level > HLBG.Debug.level then return end
    
    -- Determine color
    local colorCode = HLBG.Debug.colors.info
    if color then
        colorCode = HLBG.Debug.colors[color] or color
    elseif level == HLBG.Debug.LEVEL_ERROR then
        colorCode = HLBG.Debug.colors.error
    elseif level == HLBG.Debug.LEVEL_WARNING then
        colorCode = HLBG.Debug.colors.warning
    elseif level == HLBG.Debug.LEVEL_VERBOSE then
        colorCode = HLBG.Debug.colors.verbose
    end
    
    -- Create message
    local message = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local yOffset = -10
    
    if content.messageCount > 0 then
        yOffset = -(content.messageCount * 15 + 10)
    end
    
    message:SetPoint("TOPLEFT", content, "TOPLEFT", 5, yOffset)
    message:SetPoint("RIGHT", content, "RIGHT", -5, 0)
    message:SetJustifyH("LEFT")
    message:SetText(colorCode .. text .. "|r")
    
    -- Update content size
    content.messageCount = content.messageCount + 1
    content:SetHeight(content.messageCount * 15 + 20)
    
    -- Store message
    table.insert(content.messages, message)
    
    -- Trim old messages if there are too many
    if #content.messages > 100 then
        content.messages[1]:Hide()
        table.remove(content.messages, 1)
        content.messageCount = content.messageCount - 1
    end
end

-- Convenience functions for different log levels
HLBG.Debug.Error = function(text)
    HLBG.Debug.AddMessage(text, HLBG.Debug.LEVEL_ERROR, "error")
    print(HLBG.Debug.colors.error .. "HLBG Error: " .. text .. "|r")
end

HLBG.Debug.Warning = function(text)
    HLBG.Debug.AddMessage(text, HLBG.Debug.LEVEL_WARNING, "warning")
    if HLBG.Debug.level >= HLBG.Debug.LEVEL_WARNING then
        print(HLBG.Debug.colors.warning .. "HLBG Warning: " .. text .. "|r")
    end
end

HLBG.Debug.Info = function(text)
    HLBG.Debug.AddMessage(text, HLBG.Debug.LEVEL_INFO, "info")
    if HLBG.Debug.level >= HLBG.Debug.LEVEL_INFO then
        print(HLBG.Debug.colors.info .. "HLBG Info: " .. text .. "|r")
    end
end

HLBG.Debug.Verbose = function(text)
    HLBG.Debug.AddMessage(text, HLBG.Debug.LEVEL_VERBOSE, "verbose")
end

HLBG.Debug.Success = function(text)
    HLBG.Debug.AddMessage(text, HLBG.Debug.LEVEL_INFO, "success")
    if HLBG.Debug.level >= HLBG.Debug.LEVEL_INFO then
        print(HLBG.Debug.colors.success .. "HLBG Success: " .. text .. "|r")
    end
end

-- Toggle the debug frame
HLBG.Debug.Toggle = function()
    if not HLBG.Debug.Frame then
        HLBG.Debug.CreateDebugFrame()
    end
    
    if HLBG.Debug.Frame:IsShown() then
        HLBG.Debug.Frame:Hide()
    else
        HLBG.Debug.Frame:Show()
    end
end

-- Register with slash commands
HLBG.Debug.RegisterSlashCommands = function()
    if SlashCmdList["HLBGDEBUG"] then return end
    
    SLASH_HLBGDEBUG1 = "/hlbgdebug"
    SLASH_HLBGDEBUG2 = "/hlbg debug"
    
    SlashCmdList["HLBGDEBUG"] = function(msg)
        if msg == "clear" then
            if HLBG.Debug.Content then
                for _, msg in ipairs(HLBG.Debug.Content.messages) do
                    msg:Hide()
                end
                HLBG.Debug.Content.messages = {}
                HLBG.Debug.Content.messageCount = 0
                HLBG.Debug.Content:SetHeight(1)
            end
        elseif msg == "off" then
            HLBG.Debug.level = HLBG.Debug.LEVEL_OFF
            print("|cFFFFFF00HLBG Debug:|r Debug level set to OFF")
        elseif msg == "error" or msg == "errors" then
            HLBG.Debug.level = HLBG.Debug.LEVEL_ERROR
            print("|cFFFFFF00HLBG Debug:|r Debug level set to ERROR")
        elseif msg == "warning" or msg == "warnings" then
            HLBG.Debug.level = HLBG.Debug.LEVEL_WARNING
            print("|cFFFFFF00HLBG Debug:|r Debug level set to WARNING")
        elseif msg == "info" then
            HLBG.Debug.level = HLBG.Debug.LEVEL_INFO
            print("|cFFFFFF00HLBG Debug:|r Debug level set to INFO")
        elseif msg == "verbose" then
            HLBG.Debug.level = HLBG.Debug.LEVEL_VERBOSE
            print("|cFFFFFF00HLBG Debug:|r Debug level set to VERBOSE")
        elseif msg == "ui" then
            HLBG.UI.FixUIErrors()
            print("|cFFFFFF00HLBG Debug:|r UI fixes applied")
        else
            HLBG.Debug.Toggle()
        end
    end
    
    HLBG.Debug.Info("Debug slash commands registered")
end

-- Call this once after the UI loads
C_Timer.After(1, function()
    HLBG.Debug.RegisterSlashCommands()
    HLBG.Debug.Info("Debug system initialized")
end)