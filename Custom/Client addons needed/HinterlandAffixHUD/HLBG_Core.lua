-- HLBG_Core.lua - Core functionality for Hinterland Battleground

-- Create or reference global HLBG table
HLBG = HLBG or {}

-- Safe wrapper helpers for API functions that may not be available in all client versions
function HLBG.safeIsInInstance()
    if type(IsInInstance) == 'function' then
        return IsInInstance()
    end
    return false, "none"
end

function HLBG.safeGetRealZoneText()
    if type(GetRealZoneText) == 'function' then
        return GetRealZoneText()
    end
    return ""
end

function HLBG.safeGetNumWorldStateUI()
    if type(GetNumWorldStateUI) == 'function' then
        return GetNumWorldStateUI()
    end
    return 0
end

function HLBG.safeGetWorldStateUIInfo(i)
    if type(GetWorldStateUIInfo) == 'function' then
        return GetWorldStateUIInfo(i)
    end
    return nil
end

function HLBG.safeGetPlayerMapPosition(unit)
    if type(GetPlayerMapPosition) == 'function' then
        return GetPlayerMapPosition(unit)
    end
    return 0, 0
end

function HLBG.safeSetJustify(fs, h, v)
    if not fs then return end
    if type(fs.SetJustifyH) == 'function' and h then fs:SetJustifyH(h) end
    if type(fs.SetJustifyV) == 'function' and v then fs:SetJustifyV(v) end
end

function HLBG.safeExecSlash(text)
    if not text or text == "" then return end
    if type(ChatFrameEditBox) == 'table' and type(ChatFrameEditBox.SetText) == 'function' then
        ChatFrameEditBox:SetText(text)
        ChatFrameEditBox:SendText()
    elseif SlashCmdList then
        -- Try to parse as a slash command
        local cmd, args = text:match("^(/[%w_]+)%s*(.*)$")
        if cmd and SlashCmdList then
            for k, v in pairs(SlashCmdList) do
                for i=1, 10 do
                    local slashCmd = _G["SLASH_"..k..i]
                    if not slashCmd then break end
                    if slashCmd:lower() == cmd:lower() then
                        v(args)
                        return
                    end
                end
            end
        end
    end
end

-- Safe slash command registration with collision avoidance
function HLBG.safeRegisterSlash(tbl_key, cmd, fn)
    if not tbl_key or not cmd or not fn then return false end
    
    -- Store registration in HLBG for posterity, even if it fails
    HLBG._registered_slashes = HLBG._registered_slashes or {}
    HLBG._skipped_slashes = HLBG._skipped_slashes or {}
    
    -- Check if the command is already defined
    local lowerCmd = cmd:lower()
    local slashIndex = nil
    
    for k, v in pairs(SlashCmdList) do
        for i=1, 10 do
            local cmdVar = "SLASH_"..k..i
            local slashCmd = _G[cmdVar]
            if not slashCmd then break end
            if slashCmd:lower() == lowerCmd then
                table.insert(HLBG._skipped_slashes, {cmd = cmd, reason = "already defined as "..cmdVar})
                return false
            end
        end
    end
    
    -- Find a free index for this command group
    for i=1, 10 do
        local cmdVar = "SLASH_"..tbl_key..i
        if not _G[cmdVar] then
            slashIndex = i
            break
        end
    end
    
    -- If no free slot, it's also a collision
    if not slashIndex then
        table.insert(HLBG._skipped_slashes, {cmd = cmd, reason = "no free index for "..tbl_key})
        return false
    end
    
    -- Register the command
    _G["SLASH_"..tbl_key..slashIndex] = cmd
    SlashCmdList[tbl_key] = fn
    table.insert(HLBG._registered_slashes, {cmd = cmd, key = tbl_key, fn = fn})
    
    return true
end

-- Check if player is in Hinterlands zone
function InHinterlands()
    local z = HLBG.safeGetRealZoneText()
    return z == "The Hinterlands"
end

-- Get affix name from its ID (fallback for when server doesn't send name)
function HLBG.GetAffixName(id)
    if not id then return "Unknown" end
    -- Check global table first
    if _G.HLBG_AFFIX_NAMES and _G.HLBG_AFFIX_NAMES[id] then
        return _G.HLBG_AFFIX_NAMES[id]
    end
    -- Fallback to some common ones
    if id == "CHAOS" then return "Chaos" end
    if id == "ZEAL" then return "Zeal" end
    if id == "STORMY" then return "Stormy" end
    if id == "VOLCANIC" then return "Volcanic" end
    return tostring(id)
end

-- Ensure UI component exists (helps with fallback handling)
function HLBG._ensureUI(component)
    if not HLBG.UI then
        if UI then HLBG.UI = UI else HLBG.UI = {} end
    end
    
    if component == 'Live' and not HLBG.UI.Live then
        HLBG.UI.Live = CreateFrame('Frame', nil, UIParent)
        HLBG.UI.Live:SetSize(400, 100)
        HLBG.UI.Live:SetPoint('CENTER')
        HLBG.UI.Live.Text = HLBG.UI.Live:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        HLBG.UI.Live.Text:SetPoint('CENTER')
        HLBG.UI.Live.Text:SetText('Waiting for live data…')
    elseif component == 'Stats' and not HLBG.UI.Stats then
        HLBG.UI.Stats = CreateFrame('Frame', nil, UIParent)
        HLBG.UI.Stats:SetSize(400, 300)
        HLBG.UI.Stats:SetPoint('CENTER')
        HLBG.UI.Stats.Text = HLBG.UI.Stats:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        HLBG.UI.Stats.Text:SetPoint('CENTER')
        HLBG.UI.Stats.Text:SetText('Waiting for stats data…')
    elseif component == 'History' and not HLBG.UI.History then
        HLBG.UI.History = CreateFrame('Frame', nil, UIParent)
        HLBG.UI.History:SetSize(400, 300)
        HLBG.UI.History:SetPoint('CENTER')
        HLBG.UI.History.Content = CreateFrame('Frame', nil, HLBG.UI.History)
        HLBG.UI.History.Content:SetPoint('TOP')
        HLBG.UI.History.Content:SetSize(400, 300)
        HLBG.UI.History.rows = {}
    elseif component == 'Queue' and not HLBG.UI.QueuePane then
        HLBG.UI.QueuePane = CreateFrame('Frame', nil, UIParent)
        HLBG.UI.QueuePane:SetSize(400, 300)
        HLBG.UI.QueuePane:SetPoint('CENTER')
    elseif component == 'Affixes' and not HLBG.UI.AffixPane then
        HLBG.UI.AffixPane = CreateFrame('Frame', nil, UIParent)
        HLBG.UI.AffixPane:SetSize(400, 300)
        HLBG.UI.AffixPane:SetPoint('CENTER')
        HLBG.UI.AffixPane.Content = CreateFrame('Frame', nil, HLBG.UI.AffixPane)
        HLBG.UI.AffixPane.Content:SetPoint('TOP')
        HLBG.UI.AffixPane.Content:SetSize(400, 300)
    end
    
    return HLBG.UI and HLBG.UI[component]
end

-- Helper to send dot commands to server
function HLBG.SendServerDot(cmd)
    if type(cmd) ~= 'string' or cmd == '' then return end
    -- Direct to API if available
    if type(SendChatMessage) == 'function' then
        SendChatMessage(cmd)
    -- Otherwise try via ChatEdit frame
    elseif type(ChatFrameEditBox) == 'table' and type(ChatFrameEditBox.SetText) == 'function' then
        ChatFrameEditBox:SetText(cmd)
        ChatFrameEditBox:SendText()
    end
end

-- Format ETA time in minutes:seconds
function HLBG._fmtETA(sec)
    sec = tonumber(sec or 0) or 0
    local m = math.floor(sec/60); local s = sec%60
    return string.format('%d:%02d', m, s)
end

-- Get season from DB or use 0 as default
function HLBG._getSeason()
    return (HinterlandAffixHUDDB and HinterlandAffixHUDDB.desiredSeason) or 0
end

-- Debug message helper
function HLBG.Debug(msg)
    if not HinterlandAffixHUDDB or not HinterlandAffixHUDDB.devMode then return end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33eeee[HLBG Debug]|r " .. tostring(msg))
    end
end

-- Update Live display from last status payload
function HLBG.UpdateLiveFromStatus()
    -- Save the affix for other functions to use
    if HLBG._lastStatus and HLBG._lastStatus.AFF then
        HLBG._affixText = HLBG._lastStatus.AFF
    end
    
    -- The actual implementation will be provided in the UI module
end

-- Handle which affix filter to use based on user selection
function HLBG.ResolveAffixFilter(af)
    if not af or af == "" then return "" end
    -- Implementation for affix filtering (can be extended later)
    return af
end

-- Initialize HLBG namespace and database
HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}

-- Export HLBG namespace globally
_G.HLBG = HLBG