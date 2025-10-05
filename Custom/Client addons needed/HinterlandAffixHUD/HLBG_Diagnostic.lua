-- HLBG_Diagnostic.lua - Provides a diagnostic window for HLBG

-- Track that this file was loaded
if _G.HLBG_RecordFileLoad then
    _G.HLBG_RecordFileLoad("HLBG_Diagnostic.lua")
end

-- Create diagnostic frame
local frame = CreateFrame("Frame", "HLBG_DiagnosticWindow", UIParent)
frame:SetWidth(500)
frame:SetHeight(400)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
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
title:SetText("HLBG Diagnostic Information")

-- Create close button
local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
closeButton:SetScript("OnClick", function() frame:Hide() end)

-- Create scroll frame
local scrollFrame = CreateFrame("ScrollFrame", "HLBG_DiagnosticScrollFrame", frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -40)
scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 20)

-- Create content frame
local content = CreateFrame("Frame", "HLBG_DiagnosticContent", scrollFrame)
content:SetWidth(scrollFrame:GetWidth())
content:SetHeight(500)
scrollFrame:SetScrollChild(content)

-- Create refresh button
local refreshButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
refreshButton:SetWidth(100)
refreshButton:SetHeight(25)
refreshButton:SetText("Refresh")
refreshButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)

-- Function to update diagnostic data
local function UpdateDiagnostic()
    -- Clear existing content
    for i = 1, content:GetNumChildren() do
        local child = select(i, content:GetChildren())
        child:Hide()
        child:SetParent(nil)
        child:ClearAllPoints()
    end
    
    local y = 0
    local lineHeight = 16
    
    -- Helper function to add a text line
    local function AddLine(text, color)
        local line = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -y)
        line:SetPoint("TOPRIGHT", content, "TOPRIGHT", -5, -y)
        line:SetJustifyH("LEFT")
        line:SetText(text)
        if color then
            line:SetTextColor(color.r, color.g, color.b)
        end
        y = y + lineHeight
        return line
    end
    
    -- Helper function to add a section header
    local function AddHeader(text)
        y = y + 5
        local header = AddLine(text, {r=1, g=1, b=0})
        header:SetFontObject("GameFontHighlight")
        y = y + 5
        return header
    end
    
    -- Current time
    AddLine("Generated: " .. date("%Y-%m-%d %H:%M:%S"))
    
    -- Basic addon info
    AddHeader("Basic Information")
    AddLine("HLBG Version: " .. (HLBG and HLBG.version or "unknown"))
    AddLine("WoW Build: " .. (select(2, GetBuildInfo()) or "unknown"))
    
    -- AIO status
    AddHeader("AIO Status")
    local aioAvailable = _G.AIO and type(_G.AIO) == "table" and type(_G.AIO.Handle) == "function"
    AddLine("AIO Available: " .. (aioAvailable and "YES" or "NO"), 
        aioAvailable and {r=0, g=1, b=0} or {r=1, g=0, b=0})
    
    if aioAvailable then
        AddLine("AIO Version: " .. (AIO.VERSION or "unknown"))
        
        -- Test AIO
        local testResult = "Not tested"
        local testColor = {r=1, g=1, b=0}
        local testLine = AddLine("AIO Test: " .. testResult, testColor)
        
        -- Try to send a test command
        _G.AIO.Handle("HLBG", "Ping", { diagnostic = true, time = time() })
        testResult = "Command sent, waiting for response..."
        testLine:SetText("AIO Test: " .. testResult)
    end
    
    -- Load state
    if _G.HLBG_LoadState then
        AddHeader("Load State")
        AddLine("Start Time: " .. date("%H:%M:%S", _G.HLBG_LoadState.startTime or 0))
        
        local loadTime = (_G.HLBG_LoadState.addonLoaded or 0) - (_G.HLBG_LoadState.startTime or 0)
        AddLine("Load Time: " .. loadTime .. " seconds")
        
        AddLine("AIO Loaded: " .. tostring(_G.HLBG_LoadState.aioLoaded))
        AddLine("AIO Available: " .. tostring(_G.HLBG_LoadState.aioAvailable))
        AddLine("AIO Available at Login: " .. tostring(_G.HLBG_LoadState.aioAvailableAtLogin))
        
        -- Errors
        if _G.HLBG_LoadState.errors and #_G.HLBG_LoadState.errors > 0 then
            AddHeader("Errors (" .. #_G.HLBG_LoadState.errors .. ")")
            for i, err in ipairs(_G.HLBG_LoadState.errors) do
                AddLine(i .. ": " .. tostring(err), {r=1, g=0.5, b=0})
            end
        else
            AddLine("No errors reported", {r=0, g=1, b=0})
        end
    end
    
    -- Loaded files
    if _G.HLBG_LoadedFiles and #_G.HLBG_LoadedFiles > 0 then
        AddHeader("Loaded Files (" .. #_G.HLBG_LoadedFiles .. ")")
        for i, file in ipairs(_G.HLBG_LoadedFiles) do
            AddLine(i .. ": " .. file)
        end
    end
    
    -- Loaded addons
    if _G.HLBG_LoadState and _G.HLBG_LoadState.loadedAddons then
        local addonList = {}
        local count = 0
        for addon, _ in pairs(_G.HLBG_LoadState.loadedAddons) do
            table.insert(addonList, addon)
            count = count + 1
        end
        
        if count > 0 then
            AddHeader("Loaded Addons (" .. count .. ")")
            table.sort(addonList)
            for _, addon in ipairs(addonList) do
                AddLine("- " .. addon)
            end
        end
    end
    
    -- Update content height
    content:SetHeight(math.max(y, scrollFrame:GetHeight()))
end

-- Refresh button handler
refreshButton:SetScript("OnClick", UpdateDiagnostic)

-- Register slash command
SLASH_HLBGDIAG1 = "/hlbgdiag"
SlashCmdList["HLBGDIAG"] = function()
    UpdateDiagnostic()
    frame:Show()
end

-- Register with AIO if it's available
if _G.AIO and type(_G.AIO.RegisterEvent) == "function" then
    _G.AIO.RegisterEvent("HLBG_DIAG", function(command, args)
        if command == "Pong" then
            -- Update the test result line if it exists
            for i = 1, content:GetNumChildren() do
                local child = select(i, content:GetChildren())
                if child:GetObjectType() == "FontString" and child:GetText() and child:GetText():match("AIO Test:") then
                    child:SetText("AIO Test: Response received! " .. (args.time and "Round trip: " .. (time() - args.time) .. "ms" or ""))
                    child:SetTextColor(0, 1, 0)
                    break
                end
            end
        end
    end)
end

-- Notify that diagnostic tool is ready
if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF88EEFFHLBG:|r Diagnostic tool loaded. Type /hlbgdiag to open.")
end