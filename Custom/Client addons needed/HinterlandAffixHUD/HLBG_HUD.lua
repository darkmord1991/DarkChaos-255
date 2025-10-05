-- HLBG_HUD.lua
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Full HUD implementation: Alliance/Horde resources and match timer
HLBG.UI = HLBG.UI or {}
-- If a modern HUD is present (or the user prefers it), disable the legacy HUD entirely
local modernPresent = (_G['HLBG_ModernHUD'] ~= nil) or (HinterlandAffixHUDDB and HinterlandAffixHUDDB.modernScoreboard)
if modernPresent then
    -- Hide any leftover legacy HUD frames to prevent duplicates/flicker
    pcall(function()
        if HLBG.UI and HLBG.UI.HUD and type(HLBG.UI.HUD.Hide) == 'function' then HLBG.UI.HUD:Hide() end
        if _G['HLBG_HUD'] and type(_G['HLBG_HUD'].Hide) == 'function' then _G['HLBG_HUD']:Hide() end
        if HLBG.UI and HLBG.UI.Affix and type(HLBG.UI.Affix.Hide) == 'function' then HLBG.UI.Affix:Hide() end
        if _G['HLBG_AffixChip'] and type(_G['HLBG_AffixChip'].Hide) == 'function' then _G['HLBG_AffixChip']:Hide() end
    end)
    -- Stop executing this legacy HUD file so only modern HUD remains active
    return
end

-- Only create the legacy HUD if a modern HUD isn't already present
if not HLBG.UI.HUD and not _G['HLBG_ModernHUD'] then
    HLBG.UI.HUD = CreateFrame("Frame", "HLBG_HUD", UIParent)
elseif HLBG.UI.HUD and HLBG.UI.HUD:GetName() == 'HLBG_ModernHUD' then
    -- avoid name clash
    HLBG.UI.HUD = nil
end
HLBG.UI.HUD = HLBG.UI.HUD or _G['HLBG_HUD']
local HUD = HLBG.UI.HUD
HUD:SetSize(340, 84)
HUD:SetPoint("TOP", UIParent, "TOP", 0, -80)
HUD:Hide()
HUD:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left=4, right=4, top=4, bottom=4 } })
HUD:SetBackdropColor(0,0,0,0.5)
if HUD.SetFrameStrata then HUD:SetFrameStrata("DIALOG") end

-- Labels
-- Alliance icon + label
HUD.AllianceIcon = HUD:CreateTexture(nil, "OVERLAY")
HUD.AllianceIcon:SetSize(36, 36)
HUD.AllianceIcon:SetPoint("TOPLEFT", HUD, "TOPLEFT", 8, -8)
HUD.AllianceIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")

HUD.Alliance = HUD:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
HUD.Alliance:SetPoint("LEFT", HUD.AllianceIcon, "RIGHT", 0, 0)

-- Horde icon + label
HUD.HordeIcon = HUD:CreateTexture(nil, "OVERLAY")
HUD.HordeIcon:SetSize(36, 36)
HUD.HordeIcon:SetPoint("TOPRIGHT", HUD, "TOPRIGHT", -8, -8)
HUD.HordeIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")

HUD.Horde = HUD:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
HUD.Horde:SetPoint("RIGHT", HUD.HordeIcon, "LEFT", -4, 0)
HUD.Timer = HUD:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
HUD.Timer:SetPoint("BOTTOM", HUD, "BOTTOM", 0, 10)
HLBG.safeSetJustify(HUD.Alliance, "LEFT")
HLBG.safeSetJustify(HUD.Horde, "RIGHT")
HLBG.safeSetJustify(HUD.Timer, "CENTER")

-- Affix label inside HUD (shown above the timer)
HUD.Affix = HUD:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HUD.Affix:SetPoint("BOTTOM", HUD.Timer, "TOP", 0, 6)
HLBG.safeSetJustify(HUD.Affix, "CENTER")

-- (Legacy) Floating affix chip is now deprecated in favor of in-HUD affix label
HLBG.UI.Affix = HLBG.UI.Affix or CreateFrame('Frame', 'HLBG_AffixChip', HUD)
HLBG.UI.Affix:SetPoint('TOP', HUD, 'BOTTOM', 0, -4)
HLBG.UI.Affix:SetSize(180, 24)
HLBG.UI.Affix:Hide()
HLBG.UI.Affix.Text = HLBG.UI.Affix:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
HLBG.UI.Affix.Text:SetPoint('CENTER')

local function fmtTimer(sec)
    sec = tonumber(sec) or 0
    if sec < 0 then sec = 0 end
    
    -- Format differently based on time length
    if sec >= 3600 then -- More than an hour
        local h = math.floor(sec/3600)
        local m = math.floor((sec%3600)/60)
        local s = sec%60
        return string.format("%d:%02d:%02d", h, m, s)
    else -- Less than an hour
        local m = math.floor(sec/60)
        local s = sec%60
        return string.format("%d:%02d", m, s)
    end
end

-- UpdateHUD reads RES (set by handlers) and refreshes labels
function HLBG.UpdateHUD()
    if not HLBG.UI or not HLBG.UI.HUD then return end
    -- Ensure sensible defaults
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    if HinterlandAffixHUDDB.useAddonHud == nil then HinterlandAffixHUDDB.useAddonHud = true end
    -- Default: show HUD everywhere (changed from false to true to fix outside-zone visibility)
    if HinterlandAffixHUDDB.showHudEverywhere == nil then HinterlandAffixHUDDB.showHudEverywhere = true end

    -- If modern scoreboard is enabled, hide the legacy HUD entirely and make sure
    -- the modern Live scoreboard UI is created and visible instead. This prevents
    -- duplicate HUDs (legacy + modern) from showing at the same time.
    if HinterlandAffixHUDDB.modernScoreboard then
        -- Hide legacy HUD
        pcall(function() HUD:Hide() end)
        -- Create / show modern scoreboard if possible
        pcall(function()
            if type(HLBG._ensureUI) == 'function' then
                HLBG._ensureUI('Live')
            end
            if HLBG.CreateModernScoreboardUI and type(HLBG.CreateModernScoreboardUI) == 'function' then
                HLBG.CreateModernScoreboardUI()
            end
            if HLBG.UI and HLBG.UI.Live and HinterlandAffixHUDDB.useAddonHud then
                pcall(function() HLBG.UI.Live:Show() end)
            end
        end)
        return
    end
    
    -- Use the latest resource data from server
    local res = _G.RES or {A=0,H=0,END=0}
    
    -- Try to get affix info from server data first
    local status = HLBG._lastStatus or {}
    local affixID = status.affix or status.affixID or status.affixId or nil
    if affixID then
        -- If we have an affix ID from server, get its name
        if HLBG.GetAffixName and type(HLBG.GetAffixName) == 'function' then
            HLBG._affixText = HLBG.GetAffixName(affixID)
        else
            HLBG._affixText = tostring(affixID)
        end
        
        if HLBG._devMode then
            print("HLBG UpdateHUD: Got affix ID from server:", affixID, "->", HLBG._affixText)
        end
    else
        -- Default to "None" if no affix is active
        HLBG._affixText = HLBG._affixText or "None"
    end
    
    -- Update alliance/horde resources
    local a = tonumber(res.A or 0) or 0
    local h = tonumber(res.H or 0) or 0
    
    -- Update time left
    local rawEnd = tonumber(res.END or 0) or 0
    -- Server may send END as an absolute epoch timestamp. Convert to seconds left when it looks like an epoch (> 3 days).
    local tleft
    if rawEnd > 3*24*60*60 then
        -- normalize possible millisecond epoch
        if rawEnd > 1000000000000 then -- > 10^12: almost certainly ms
            rawEnd = math.floor(rawEnd / 1000)
        end
        local now = (type(time) == 'function') and time() or 0
        tleft = math.max(0, rawEnd - now)
        HLBG._hudEndEpoch = rawEnd
    else
        tleft = math.max(0, rawEnd)
        HLBG._hudEndEpoch = nil
    end
    HLBG._timeLeft = tleft
    
    -- Update HUD elements
    HUD.Alliance:SetText("|cff1e90ffAlliance|r: "..tostring(a))
    HUD.Horde:SetText("|cffff0000Horde|r: "..tostring(h))
    HUD.Timer:SetText("Time: "..fmtTimer(tleft))
    
    -- Always show the Affix line with current affix
    HUD.Affix:SetText("|cffffd100Affix|r: "..tostring(HLBG._affixText or "None"))
    HUD.Affix:Show()
    -- Honor user toggle: only show if enabled
    local use = HinterlandAffixHUDDB.useAddonHud
    -- Optional gating: keep HUD hidden outside PvP instances unless user explicitly sets showHudEverywhere
    local inInstance, instanceType = false, nil
    pcall(function()
        inInstance = (type(IsInInstance) == 'function') and IsInInstance() or false
        local ok,it = pcall(function() return (type(GetInstanceType) == 'function') and GetInstanceType() or nil end)
        if ok then instanceType = it end
    end)
    -- Always allow showing in The Hinterlands open world (zone 47) even if not in an instance
    -- Also check for zone ID 47 which is The Hinterlands
    local inHinterlands = false
    pcall(function()
        if type(HLBG) == 'table' and type(HLBG.safeGetRealZoneText) == 'function' then
            local z = HLBG.safeGetRealZoneText() or ''
            inHinterlands = (z == 'The Hinterlands')
        else
            local z = (type(GetRealZoneText) == 'function' and (GetRealZoneText() or '')) or ''
            local zoneID = (type(GetCurrentMapAreaID) == 'function' and GetCurrentMapAreaID()) or 0
            inHinterlands = (z == 'The Hinterlands' or zoneID == 47)
        end
    end)
    -- Changed to default to showing HUD everywhere
    local allowHere = true
    if use and allowHere then
        HUD:Show()
        -- Hide legacy external affix frame if present to avoid duplicate text in background
        local ext = _G["HinterlandAffixHUD"]
        if ext then
            pcall(function() ext:Hide() end)
            if not ext._hlbgHooked then
                ext._hlbgHooked = true
                ext:HookScript("OnShow", function(self)
                    if HinterlandAffixHUDDB and HinterlandAffixHUDDB.useAddonHud then self:Hide() end
                end)
            end
        end
    else
        HUD:Hide()
    end
end

-- Mirror HUD totals into the Live tab as two summary rows (Alliance/Horde)
function HLBG.UpdateLiveFromStatus()
    -- Always refresh HUD first
    pcall(function() HLBG.UpdateHUD() end)
    
    -- If Live pane exists, render two rows based on RES
    if not HLBG.UI or not HLBG.UI.Live then return end
    
    -- Get current resources
    local res = _G.RES or {A=0,H=0}
    local nowts = (type(date)=="function" and date("%Y-%m-%d %H:%M:%S")) or ""
    
    -- Get status data
    local status = HLBG._lastStatus or {}
    local playerCounts = {
        Alliance = tonumber(status.APlayers or status.APC or 0) or 0,
        Horde = tonumber(status.HPlayers or status.HPC or 0) or 0
    }
    
    -- Create rows with additional information
    local rows = {
        { 
            id = "A", 
            ts = nowts, 
            name = "Alliance", 
            team = "Alliance", 
            score = tonumber(res.A or 0) or 0,
            players = playerCounts.Alliance
        },
        { 
            id = "H", 
            ts = nowts, 
            name = "Horde", 
            team = "Horde", 
            score = tonumber(res.H or 0) or 0,
            players = playerCounts.Horde
        },
    }
    
    -- Update the Live UI
    if type(HLBG.Live) == 'function' then 
        pcall(HLBG.Live, rows) 
    end
    
    -- Update header totals if helper is available
    pcall(function()
        if HLBG.UI and HLBG.UI.Live and HLBG.UI.Live.Header then
            -- Update scores
            if HLBG.UI.Live.Header.Totals then
                HLBG.UI.Live.Header.Totals:SetText(string.format("Alliance: %d   Horde: %d", rows[1].score, rows[2].score))
            end
            
            -- Update player counts
            if HLBG.UI.Live.Header.Players then
                HLBG.UI.Live.Header.Players:SetText(string.format("Players: Alliance %d / Horde %d", 
                    rows[1].players, rows[2].players))
            end
            
            -- Update timer if available
            if HLBG.UI.Live.Header.Timer then
                local timeLeft = HLBG._timeLeft or 0
                if timeLeft > 0 then
                    HLBG.UI.Live.Header.Timer:SetText("Time: " .. fmtTimer(timeLeft))
                    HLBG.UI.Live.Header.Timer:Show()
                else
                    HLBG.UI.Live.Header.Timer:SetText("No active battle")
                end
            end
            
            -- Update affix if available
            if HLBG.UI.Live.Header.Affix then
                local affixText = HLBG._affixText or "None"
                local affixName = HLBG.GetAffixName and HLBG.GetAffixName(affixText) or affixText
                HLBG.UI.Live.Header.Affix:SetText("Affix: " .. affixName)
            end
        end
    end)
    
    -- Also update Live UI even when outside BG zone if configured
    if (HinterlandAffixHUDDB and HinterlandAffixHUDDB.showOutside) then
        -- Make sure Live tab is visible
        if HLBG.UI and HLBG.UI.Live then
            HLBG.UI.Live:Show()
        end
    end
end

-- Smooth countdown: decrement RES.END locally between STATUS updates
do
    local acc = 0
    local frame = CreateFrame('Frame')
    frame:SetScript('OnUpdate', function(_, elapsed)
        if not HinterlandAffixHUDDB or not HinterlandAffixHUDDB.useAddonHud then return end
        acc = acc + (elapsed or 0)
        if acc < 1.0 then return end
        acc = 0
        if HLBG._timeLeft and HLBG._timeLeft > 0 then
            HLBG._timeLeft = HLBG._timeLeft - 1
            -- If we were tracking an epoch, recompute remaining from epoch to avoid drift
            if HLBG._hudEndEpoch then
                local now = (type(time) == 'function') and time() or 0
                HLBG._timeLeft = math.max(0, HLBG._hudEndEpoch - now)
            end
            HUD.Timer:SetText("Time: "..fmtTimer(HLBG._timeLeft))
        end
    end)
end

-- Initial draw to reflect any early RES values
pcall(function() HLBG.UpdateHUD() end)

function HLBG.HideBlizzHUDDeep()
    local w = _G["WorldStateAlwaysUpFrame"]
    if not w then return end
    w:Hide()
    if not w._hlbgHooked then
        w._hlbgHooked = true
        w:HookScript("OnShow", function(self)
            if HinterlandAffixHUDDB and HinterlandAffixHUDDB.useAddonHud then self:Hide() end
        end)
    end
end

function HLBG.UnhideBlizzHUDDeep()
    local w = _G["WorldStateAlwaysUpFrame"]
    if w then w:Show() end
    -- If addon HUD is off, allow the legacy affix frame to operate normally
    if HinterlandAffixHUDDB and not HinterlandAffixHUDDB.useAddonHud then
        local ext = _G["HinterlandAffixHUD"]
        if ext and ext.Show then pcall(function() ext:Show() end) end
    end
end

_G.HLBG = HLBG
