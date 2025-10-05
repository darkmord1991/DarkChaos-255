-- HLBG_Debug.lua - Debug utilities for Hinterland Battleground AddOn
-- This file adds utilities for debug logging and testing

-- Initialize our addon namespace if needed
if not HLBG then HLBG = {} end

-- Debug function that only outputs when in dev mode
function HLBG.Debug(msg)
    -- Only output if devMode is enabled
    if not HLBG._devMode and not (HinterlandAffixHUDDB and HinterlandAffixHUDDB.devMode) then
        return
    end
    
    -- Format a nice debug message with timestamp
    local timestamp = date("%H:%M:%S")
    local formatted = string.format("|cff00FFFF[HLBG %s]|r %s", timestamp, tostring(msg or "nil"))
    
    -- Output to chat frame if available
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(formatted)
    end
    
    -- Also store in debug log
    if not HinterlandAffixHUD_DebugLog then
        HinterlandAffixHUD_DebugLog = {}
    end
    
    table.insert(HinterlandAffixHUD_DebugLog, 1, string.format("[%s] %s", date("%Y-%m-%d %H:%M:%S"), tostring(msg or "nil")))
    
    -- Keep log size reasonable
    while #HinterlandAffixHUD_DebugLog > 200 do
        table.remove(HinterlandAffixHUD_DebugLog)
    end
    
    -- Also try to send to server if we have the function
    local okSend = pcall(function() return _G.HLBG_SendClientLog end)
    local send = (okSend and type(_G.HLBG_SendClientLog) == "function") and _G.HLBG_SendClientLog or
                ((type(HLBG) == "table" and type(HLBG.SendClientLog) == "function") and HLBG.SendClientLog or nil)
                
    if send then
        pcall(function() send(string.format("DEBUG: %s", tostring(msg or "nil"))) end)
    end
end

-- More specific debug functions for different systems
function HLBG.DebugHUD(msg)
    HLBG.Debug("HUD: " .. tostring(msg or "nil"))
end

function HLBG.DebugAIO(msg)
    HLBG.Debug("AIO: " .. tostring(msg or "nil"))
end

function HLBG.DebugHistory(msg)
    HLBG.Debug("History: " .. tostring(msg or "nil"))
end

function HLBG.DebugStats(msg)
    HLBG.Debug("Stats: " .. tostring(msg or "nil"))
end

function HLBG.DebugQueue(msg)
    HLBG.Debug("Queue: " .. tostring(msg or "nil"))
end

-- Helper to dump table contents (limited depth)
function HLBG.Dump(tbl, depth)
    if not HLBG._devMode and not (HinterlandAffixHUDDB and HinterlandAffixHUDDB.devMode) then
        return
    end
    
    depth = depth or 1
    if depth > 3 then return "[max depth]" end
    
    if type(tbl) ~= "table" then
        return tostring(tbl or "nil")
    end
    
    local result = {}
    local indent = string.rep("  ", depth)
    
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            table.insert(result, indent .. tostring(k) .. " = {")
            table.insert(result, HLBG.Dump(v, depth + 1))
            table.insert(result, indent .. "}")
        else
            table.insert(result, indent .. tostring(k) .. " = " .. tostring(v))
        end
    end
    
    return table.concat(result, "\n")
end

-- Dump a table to chat
function HLBG.DumpToChat(tbl, name)
    if not HLBG._devMode and not (HinterlandAffixHUDDB and HinterlandAffixHUDDB.devMode) then
        return
    end
    
    name = name or "Table"
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[HLBG Dump]|r " .. name .. ":")
        DEFAULT_CHAT_FRAME:AddMessage(HLBG.Dump(tbl))
    end
end

-- Add slash command for debug
SLASH_HLBGDEBUG1 = "/hlbgdebug"
SlashCmdList["HLBGDEBUG"] = function(msg)
    -- Enable dev mode
    HLBG._devMode = true
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    HinterlandAffixHUDDB.devMode = true
    
    -- Show debug help
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[HLBG Debug]|r Debug mode enabled.")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[HLBG Debug]|r Available commands:")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[HLBG Debug]|r /hlbgdebug - Show this help")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[HLBG Debug]|r /hlbg devmode on|off - Enable/disable debug mode")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[HLBG Debug]|r /hlbg season <n> - Set season filter (0 = all)")
    end
    
    -- Try to dump some useful info
    HLBG.Debug("UI status: " .. (HLBG.UI and "initialized" or "not initialized"))
    HLBG.Debug("AIO status: " .. (_G.AIO and "available" or "not available"))
    
    -- Show active hooks and event handlers
    if _G.HLBG_EVENT_HOOKS then
        HLBG.Debug("Event hooks: " .. table.concat(_G.HLBG_EVENT_HOOKS, ", "))
    end
end

-- Debug timer refresh function
function HLBG.RefreshDebug()
    if not HLBG._devMode and not (HinterlandAffixHUDDB and HinterlandAffixHUDDB.devMode) then
        return
    end
    
    -- Create debug frame if needed
    if not HLBG.DebugFrame then
        HLBG.DebugFrame = CreateFrame("Frame", "HLBG_DebugFrame", UIParent)
        HLBG.DebugFrame:SetSize(400, 300)
        HLBG.DebugFrame:SetPoint("CENTER", 0, 0)
        HLBG.DebugFrame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        HLBG.DebugFrame:SetBackdropColor(0, 0, 0, 0.8)
        HLBG.DebugFrame:SetMovable(true)
        HLBG.DebugFrame:EnableMouse(true)
        HLBG.DebugFrame:SetClampedToScreen(true)
        HLBG.DebugFrame:RegisterForDrag("LeftButton")
        HLBG.DebugFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        HLBG.DebugFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        
        -- Title
        HLBG.DebugFrame.Title = HLBG.DebugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        HLBG.DebugFrame.Title:SetPoint("TOP", 0, -10)
        HLBG.DebugFrame.Title:SetText("HLBG Debug")
        
        -- Close button
        HLBG.DebugFrame.CloseButton = CreateFrame("Button", nil, HLBG.DebugFrame, "UIPanelCloseButton")
        HLBG.DebugFrame.CloseButton:SetPoint("TOPRIGHT", -3, -3)
        HLBG.DebugFrame.CloseButton:SetScript("OnClick", function() HLBG.DebugFrame:Hide() end)
        
        -- Debug text
    HLBG.DebugFrame.Scroll = CreateFrame("ScrollFrame", "HLBG_DebugScrollFrame", HLBG.DebugFrame, "UIPanelScrollFrameTemplate")
        HLBG.DebugFrame.Scroll:SetPoint("TOPLEFT", 10, -30)
        HLBG.DebugFrame.Scroll:SetPoint("BOTTOMRIGHT", -28, 10)
        
        HLBG.DebugFrame.Text = CreateFrame("EditBox", nil, HLBG.DebugFrame.Scroll)
        HLBG.DebugFrame.Text:SetMultiLine(true)
        HLBG.DebugFrame.Text:SetFontObject(ChatFontNormal)
        HLBG.DebugFrame.Text:SetWidth(370)
        HLBG.DebugFrame.Text:SetAutoFocus(false)
        HLBG.DebugFrame.Text:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        
        HLBG.DebugFrame.Scroll:SetScrollChild(HLBG.DebugFrame.Text)
        
        -- Refresh button
        HLBG.DebugFrame.RefreshButton = CreateFrame("Button", nil, HLBG.DebugFrame, "UIPanelButtonTemplate")
        HLBG.DebugFrame.RefreshButton:SetSize(80, 22)
        HLBG.DebugFrame.RefreshButton:SetPoint("BOTTOMLEFT", 10, 10)
        HLBG.DebugFrame.RefreshButton:SetText("Refresh")
        HLBG.DebugFrame.RefreshButton:SetScript("OnClick", function() HLBG.RefreshDebug() end)
        
        -- Initially hidden
        HLBG.DebugFrame:Hide()
    end
    
    -- Gather debug information
    local info = {
        "HLBG Debug Information",
        "=====================",
        "Version: " .. (HLBG.version or "unknown"),
        "DevMode: " .. (HLBG._devMode and "ON" or "OFF"),
        "AIO: " .. (_G.AIO and "Available" or "Not available"),
        "",
        "UI Status:",
        "UI loaded: " .. (HLBG.UI and "yes" or "no"),
        "UI shown: " .. (HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame:IsShown() and "yes" or "no"),
        "",
        "HUD Status:",
        "HUD enabled: " .. ((HinterlandAffixHUDDB and HinterlandAffixHUDDB.showHUD ~= false) and "yes" or "no"),
        "Resources: " .. ((HLBG and HLBG._lastStatus) and 
                          ("A: " .. (HLBG._lastStatus.A or "?") .. " H: " .. (HLBG._lastStatus.H or "?")) or "unknown"),
        "Current affix: " .. (HLBG._affixText or "unknown"),
        "",
        "Last events:",
    }
    
    -- Add recent debug logs
    if HinterlandAffixHUD_DebugLog then
        for i = 1, math.min(10, #HinterlandAffixHUD_DebugLog) do
            table.insert(info, HinterlandAffixHUD_DebugLog[i])
        end
    end
    
    -- Update text
    HLBG.DebugFrame.Text:SetText(table.concat(info, "\n"))
    HLBG.DebugFrame.Text:SetCursorPosition(0)
    
    -- Show the frame
    HLBG.DebugFrame:Show()
end

-- Register slash command for the debug frame
SLASH_HLBGDEBUGFRAME1 = "/hlbgdebugframe"
SlashCmdList["HLBGDEBUGFRAME"] = function(msg)
    HLBG.RefreshDebug()
end

-- Print a message when this file loads
if DEFAULT_CHAT_FRAME and (HLBG._devMode or (HinterlandAffixHUDDB and HinterlandAffixHUDDB.devMode)) then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFF[HLBG]|r Debug utilities loaded. Use /hlbgdebug for help.")
end