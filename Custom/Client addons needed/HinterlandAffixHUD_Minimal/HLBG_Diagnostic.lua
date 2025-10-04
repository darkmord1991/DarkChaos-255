-- HLBG_Diagnostic.lua - Diagnostic tools for troubleshooting

-- Create or use existing namespace for tracking
_G.HLBG_Debug = true
_G.HLBG_LoadedFiles = _G.HLBG_LoadedFiles or {}

-- Function to record file loads
function _G.HLBG_RecordFileLoad(filename)
    if not _G.HLBG_LoadedFiles then
        _G.HLBG_LoadedFiles = {}
    end
    _G.HLBG_LoadedFiles[filename] = true
    
    if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG Diag]|r Loaded: " .. filename)
    end
end

-- Record that this file was loaded
_G.HLBG_RecordFileLoad("HLBG_Diagnostic.lua")

-- Create diagnostics frame
local diagFrame = CreateFrame("Frame", "HLBG_DiagnosticFrame")
diagFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
diagFrame:SetWidth(500)
diagFrame:SetHeight(400)
diagFrame:SetFrameStrata("FULLSCREEN")
diagFrame:EnableMouse(true)
diagFrame:SetMovable(true)
diagFrame:RegisterForDrag("LeftButton")
diagFrame:SetScript("OnDragStart", diagFrame.StartMoving)
diagFrame:SetScript("OnDragStop", diagFrame.StopMovingOrSizing)
diagFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
diagFrame:Hide()

-- Create title
local title = diagFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("TOP", diagFrame, "TOP", 0, -16)
title:SetText("HinterlandAffixHUD Diagnostics")

-- Create close button
local closeButton = CreateFrame("Button", nil, diagFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", diagFrame, "TOPRIGHT", -3, -3)
closeButton:SetScript("OnClick", function() diagFrame:Hide() end)

-- Create scrollframe for content
local scrollFrame = CreateFrame("ScrollFrame", "HLBG_DiagnosticScrollFrame", diagFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", diagFrame, "TOPLEFT", 20, -40)
scrollFrame:SetPoint("BOTTOMRIGHT", diagFrame, "BOTTOMRIGHT", -40, 20)

-- Create content frame
local content = CreateFrame("Frame", "HLBG_DiagnosticContent", scrollFrame)
content:SetWidth(scrollFrame:GetWidth())
content:SetHeight(600) -- Make it taller than scrollFrame
scrollFrame:SetScrollChild(content)

-- Create refresh button
local refreshButton = CreateFrame("Button", nil, diagFrame, "UIPanelButtonTemplate")
refreshButton:SetWidth(100)
refreshButton:SetHeight(25)
refreshButton:SetPoint("BOTTOM", diagFrame, "BOTTOM", 0, 10)
refreshButton:SetText("Refresh")

-- Text areas for different sections
local sections = {
    {
        title = "AIO Status",
        text = nil
    },
    {
        title = "Loaded Files",
        text = nil
    },
    {
        title = "Addon Status",
        text = nil
    },
    {
        title = "Error Log",
        text = nil
    }
}

-- Create section titles and text areas
local yOffset = 10
for i, section in ipairs(sections) do
    -- Create section title
    local sectionTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sectionTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -yOffset)
    sectionTitle:SetText(section.title)
    yOffset = yOffset + 25
    
    -- Create text for this section
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 20, -yOffset)
    text:SetWidth(content:GetWidth() - 40)
    text:SetJustifyH("LEFT")
    text:SetText("Loading...")
    section.text = text
    
    yOffset = yOffset + 100
end

-- Function to update the diagnostic information
local function UpdateDiagnostics()
    -- AIO Status section
    local aioStatus = "AIO Global: "
    if _G.AIO then
        aioStatus = aioStatus .. "Available\n"
        
        if type(_G.AIO.Handle) == "function" then
            aioStatus = aioStatus .. "AIO.Handle: Available\n"
        else
            aioStatus = aioStatus .. "AIO.Handle: Not available\n"
        end
        
        if type(_G.AIO.AddHandlers) == "function" then
            aioStatus = aioStatus .. "AIO.AddHandlers: Available\n"
        else
            aioStatus = aioStatus .. "AIO.AddHandlers: Not available\n"
        end
    else
        aioStatus = aioStatus .. "Not available\n"
    end
    
    -- Check for HLBG_AIO_Check functionality
    if _G.HLBG_AIO_Available ~= nil then
        aioStatus = aioStatus .. "\nHLBG AIO Check: " .. 
            (type(_G.HLBG_AIO_Available) == "function" and "Function exists" or "Variable exists") .. "\n"
        
        if type(_G.HLBG_AIO_Available) == "function" then
            local isAvailable = _G.HLBG_AIO_Available()
            aioStatus = aioStatus .. "HLBG_AIO_Available(): " .. (isAvailable and "true" or "false") .. "\n"
        else
            aioStatus = aioStatus .. "HLBG_AIO_Available: " .. tostring(_G.HLBG_AIO_Available) .. "\n"
        end
    else
        aioStatus = aioStatus .. "\nHLBG AIO Check: Not available\n"
    end
    
    -- Check for HLBG.SendCommand
    if _G.HLBG and type(_G.HLBG.SendCommand) == "function" then
        aioStatus = aioStatus .. "\nHLBG.SendCommand: Available"
    else
        aioStatus = aioStatus .. "\nHLBG.SendCommand: Not available"
    end
    
    sections[1].text:SetText(aioStatus)
    
    -- Loaded Files section
    local loadedFiles = ""
    if _G.HLBG_LoadedFiles then
        for filename, loaded in pairs(_G.HLBG_LoadedFiles) do
            loadedFiles = loadedFiles .. filename .. ": " .. (loaded and "Loaded" or "Not loaded") .. "\n"
        end
    else
        loadedFiles = "No files tracked"
    end
    sections[2].text:SetText(loadedFiles)
    
    -- Addon Status section
    local addonStatus = ""
    if _G.HLBG then
        addonStatus = addonStatus .. "HLBG Global: Available\n"
        addonStatus = addonStatus .. "Version: " .. (type(_G.HLBG.version) == "string" and _G.HLBG.version or "Unknown") .. "\n"
        
        -- Check important functions
        local functions = {"ShowUI", "HideUI", "Status"}
        for _, funcName in ipairs(functions) do
            addonStatus = addonStatus .. funcName .. ": " .. 
                (type(_G.HLBG[funcName]) == "function" and "Available" or "Not available") .. "\n"
        end
    else
        addonStatus = "HLBG Global: Not available"
    end
    sections[3].text:SetText(addonStatus)
    
    -- Error Log
    local errorLog = ""
    -- Add any errors that might have been captured
    errorLog = errorLog .. "No errors logged"
    sections[4].text:SetText(errorLog)
end

-- Set refresh button script
refreshButton:SetScript("OnClick", UpdateDiagnostics)

-- Show the diagnostic frame
local function ShowDiagnostics()
    UpdateDiagnostics()
    diagFrame:Show()
end

-- Register slash command for diagnostics
SLASH_HLBGDIAG1 = "/hlbgdiag"
SlashCmdList["HLBGDIAG"] = ShowDiagnostics

-- Add a menu button to main UI if it exists
if _G.HLBG and _G.HLBG.LoadUI then
    local oldLoadUI = _G.HLBG.LoadUI
    _G.HLBG.LoadUI = function(...)
        oldLoadUI(...)
        
        -- Try to add a diagnostic button to the main UI
        if _G.HinterlandAffixHUD_MainFrame then
            local diagButton = CreateFrame("Button", nil, _G.HinterlandAffixHUD_MainFrame, "UIPanelButtonTemplate")
            diagButton:SetWidth(100)
            diagButton:SetHeight(25)
            diagButton:SetPoint("BOTTOMLEFT", _G.HinterlandAffixHUD_MainFrame, "BOTTOMLEFT", 10, 10)
            diagButton:SetText("Diagnostics")
            diagButton:SetScript("OnClick", ShowDiagnostics)
        end
    end
end

-- Notify that diagnostics are available
if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG Diag]|r Diagnostic tools loaded. Type /hlbgdiag to show diagnostics.")
end