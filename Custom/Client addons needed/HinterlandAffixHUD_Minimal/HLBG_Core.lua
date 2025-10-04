-- HLBG_Core.lua - Minimal core functionality

-- Track that this file was loaded
if _G.HLBG_RecordFileLoad then
    _G.HLBG_RecordFileLoad("HLBG_Core.lua")
end

-- Create or use existing namespace
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Core version
HLBG.version = "1.5.7-min"

-- Initialize main frame
local frame = CreateFrame("Frame", "HLBG_MainFrame")
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetWidth(300)
frame:SetHeight(100)
frame:SetFrameStrata("MEDIUM")
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
frame:Hide()

-- Create title
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("TOP", frame, "TOP", 0, -16)
title:SetText("HLBG Minimal Version")

-- Create status text
local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusText:SetPoint("CENTER", frame, "CENTER")
statusText:SetText("AIO Integration Test")

-- Create close button
local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
closeButton:SetScript("OnClick", function() frame:Hide() end)

-- Create status check button
local statusButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
statusButton:SetWidth(100)
statusButton:SetHeight(25)
statusButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 20)
statusButton:SetText("Request Status")
statusButton:SetScript("OnClick", function()
    if type(HLBG.SendCommand) == "function" then
        HLBG.SendCommand("RequestStatus")
        statusText:SetText("Status requested...")
        
        C_Timer.After(0.5, function()
            statusText:SetText("Status requested... waiting for response")
        end)
    else
        statusText:SetText("SendCommand not available!")
    end
end)

-- Basic functions
function HLBG.ShowUI()
    frame:Show()
end

function HLBG.HideUI()
    frame:Hide()
end

function HLBG.Status(args)
    args = args or {}
    
    local status = "Status received!\n"
    if args.A or args.H then
        status = status .. "Score: Alliance " .. (args.A or "?") .. " - Horde " .. (args.H or "?") .. "\n"
    end
    if args.affix or args.AFF then
        status = status .. "Affix: " .. (args.affix or args.AFF or "Unknown") .. "\n"
    end
    
    statusText:SetText(status)
end

-- Register for PLAYER_ENTERING_WORLD
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Show welcome message
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFFHLBG Minimal:|r Core loaded successfully")
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFFHLBG Minimal:|r Type /hlbg to show the UI")
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFFHLBG Minimal:|r Type /hlbgdiag for diagnostics")
        end
    end
end)

-- Override ShowUI for diagnostics
HLBG.ShowUI_Original = HLBG.ShowUI
function HLBG.ShowUI()
    -- Update the diagnostic test
    if _G.AIO and type(_G.AIO.Handle) == "function" then
        statusText:SetText("AIO is available!\nClick 'Request Status' to test")
    else
        statusText:SetText("AIO is NOT available!")
    end
    
    frame:Show()
end