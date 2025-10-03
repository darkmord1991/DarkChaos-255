-- HLBG_UI_Helpers.lua - Helper functions for UI components
-- Provides utility functions to avoid common errors and share code

-- Ensure HLBG namespace exists
HLBG = HLBG or {}
HLBG.UI = HLBG.UI or {}
HLBG.UI.Helpers = {}

-- Helper function to create scroll frames safely
-- This avoids the "attempt to concatenate a nil value" error
function HLBG.UI.Helpers.CreateScrollFrame(parent, name, offsetX, offsetY, bottomPadding)
    offsetX = offsetX or 10
    offsetY = offsetY or -10
    bottomPadding = bottomPadding or 10
    
    -- Generate a unique name if one is not provided
    if not name then
        name = "HLBG_ScrollFrame_" .. tostring(math.floor(GetTime() * 1000))
    end
    
    -- Create the scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", offsetX, offsetY)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -30, bottomPadding)
    
    -- Create the content frame
    local content = CreateFrame("Frame", name.."Content", scrollFrame)
    content:SetSize(parent:GetWidth() - 40, 600) -- Default height, will be adjusted
    scrollFrame:SetScrollChild(content)
    
    -- Return both frames for use
    return scrollFrame, content
end

-- Helper function to create backdrop frames
function HLBG.UI.Helpers.CreateBackdropFrame(parent, anchorFrame, yOffset)
    local frame = CreateFrame("Frame", nil, parent)
    
    if anchorFrame then
        frame:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, yOffset or -20)
    else
        frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -5)
    end
    
    frame:SetPoint("RIGHT", parent, "RIGHT", -5, 0)
    
    -- Set backdrop
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.5)
    
    return frame
end

-- Helper function to create section headers
function HLBG.UI.Helpers.CreateHeader(parent, text, anchorFrame, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if anchorFrame then
        header:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, yOffset or -20)
    else
        header:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
    end
    
    header:SetText(text)
    header:SetTextColor(1, 0.82, 0) -- Gold color
    return header
end

-- Helper function to create checkboxes
function HLBG.UI.Helpers.CreateCheckbox(parent, text, anchorFrame, yOffset, savedVarName, defaultValue, callback)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    
    if anchorFrame then
        checkbox:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 5, yOffset or -10)
    else
        checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -10)
    end
    
    checkbox.text:SetText(text)
    
    -- Set initial state from saved variable
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    checkbox:SetChecked(HinterlandAffixHUDDB[savedVarName] ~= nil and HinterlandAffixHUDDB[savedVarName] or defaultValue)
    
    -- OnClick handler
    checkbox:SetScript("OnClick", function(self)
        HinterlandAffixHUDDB[savedVarName] = self:GetChecked()
        if type(callback) == "function" then
            callback(self:GetChecked())
        end
    end)
    
    return checkbox
end

-- Helper function to ensure the UI container exists
function HLBG._ensureUI(tabName)
    if not HLBG.UI then
        HLBG.UI = {}
    end
    
    if not HLBG.UI.Frame then
        -- Try to find main frame
        local mainFrame = _G["HLBG_UI_Frame"] or _G["HinterlandBGFrame"]
        if not mainFrame then
            -- Create a basic UI frame if needed
            mainFrame = CreateFrame("Frame", "HLBG_UI_Frame", UIParent)
            mainFrame:SetSize(500, 400)
            mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            mainFrame:SetMovable(true)
            mainFrame:EnableMouse(true)
            mainFrame:RegisterForDrag("LeftButton")
            mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
            mainFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
            mainFrame:SetBackdrop({
                bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
                edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 8, right = 8, top = 8, bottom = 8 }
            })
            
            -- Close button
            local closeButton = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
            closeButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -3, -3)
            
            -- Title
            local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            title:SetPoint("TOP", mainFrame, "TOP", 0, -10)
            title:SetText("Hinterland Battleground")
        end
        
        HLBG.UI.Frame = mainFrame
    end
    
    if not HLBG.UI[tabName] then
        HLBG.UI[tabName] = CreateFrame("Frame", "HLBG_"..tabName.."Tab", HLBG.UI.Frame)
        HLBG.UI[tabName]:SetPoint("TOPLEFT", HLBG.UI.Frame, "TOPLEFT", 10, -30)
        HLBG.UI[tabName]:SetPoint("BOTTOMRIGHT", HLBG.UI.Frame, "BOTTOMRIGHT", -10, 10)
        HLBG.UI[tabName]:Hide()
    end
    
    return true
end

-- Function to fix missing elements in UI
function HLBG.UI.FixUIErrors()
    -- Fix for missing scroll frames
    if HLBG.UI and HLBG.UI.Stats and HLBG.UI.Stats.ScrollFrame and not _G["HLBG_StatsScrollFrame"] then
        HLBG.UI.Stats.ScrollFrame:SetName("HLBG_StatsScrollFrame")
    end
    
    if HLBG.UI and HLBG.UI.History and HLBG.UI.History.ScrollFrame and not _G["HLBG_HistoryScrollFrame"] then
        HLBG.UI.History.ScrollFrame:SetName("HLBG_HistoryScrollFrame")
    end
    
    if HLBG.UI and HLBG.UI.InfoPane and HLBG.UI.InfoPane.ScrollFrame and not _G["HLBG_InfoScrollFrame"] then
        HLBG.UI.InfoPane.ScrollFrame:SetName("HLBG_InfoScrollFrame")
    end
    
    if HLBG.UI and HLBG.UI.SettingsPane and HLBG.UI.SettingsPane.ScrollFrame and not _G["HLBG_SettingsScrollFrame"] then
        HLBG.UI.SettingsPane.ScrollFrame:SetName("HLBG_SettingsScrollFrame")
    end
    
    print("|cFF33FF99Hinterland Affix HUD:|r UI fixes applied.")
end

-- Run the fixes when this file loads
C_Timer.After(2, HLBG.UI.FixUIErrors)