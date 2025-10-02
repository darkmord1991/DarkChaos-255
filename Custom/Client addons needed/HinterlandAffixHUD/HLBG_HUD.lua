-- HLBG_HUD.lua
local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Full HUD implementation: Alliance/Horde resources and match timer
HLBG.UI = HLBG.UI or {}
HLBG.UI.HUD = HLBG.UI.HUD or CreateFrame("Frame", "HLBG_HUD", UIParent)
local HUD = HLBG.UI.HUD
HUD:SetSize(260, 64)
HUD:SetPoint("TOP", UIParent, "TOP", 0, -80)
HUD:Hide()
HUD:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left=4, right=4, top=4, bottom=4 } })
HUD:SetBackdropColor(0,0,0,0.5)
if HUD.SetFrameStrata then HUD:SetFrameStrata("DIALOG") end

-- Labels
-- Alliance icon + label
HUD.AllianceIcon = HUD:CreateTexture(nil, "OVERLAY")
HUD.AllianceIcon:SetSize(18, 18)
HUD.AllianceIcon:SetPoint("TOPLEFT", HUD, "TOPLEFT", 8, -8)
HUD.AllianceIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")

HUD.Alliance = HUD:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
HUD.Alliance:SetPoint("LEFT", HUD.AllianceIcon, "RIGHT", 4, 0)

-- Horde icon + label
HUD.HordeIcon = HUD:CreateTexture(nil, "OVERLAY")
HUD.HordeIcon:SetSize(18, 18)
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
    local m = math.floor(sec/60)
    local s = sec%60
    return string.format("%d:%02d", m, s)
end

-- UpdateHUD reads RES (set by handlers) and refreshes labels
function HLBG.UpdateHUD()
    if not HLBG.UI or not HLBG.UI.HUD then return end
    local res = _G.RES or {A=0,H=0,END=0}
    local a = tonumber(res.A or 0) or 0
    local h = tonumber(res.H or 0) or 0
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
    HUD.Alliance:SetText("|cff1e90ffAlliance|r: "..tostring(a))
    HUD.Horde:SetText("|cffff0000Horde|r: "..tostring(h))
    HUD.Timer:SetText("Time: "..fmtTimer(tleft))
    if HLBG._affixText and tostring(HLBG._affixText) ~= "" then
        HUD.Affix:SetText("|cffffd100Affix|r: "..tostring(HLBG._affixText))
        HUD.Affix:Show()
    else
        HUD.Affix:SetText("")
        HUD.Affix:Hide()
    end
    -- Honor user toggle: only show if enabled
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    if HinterlandAffixHUDDB.useAddonHud == nil then HinterlandAffixHUDDB.useAddonHud = true end
    local use = HinterlandAffixHUDDB.useAddonHud
    if use then HUD:Show() else HUD:Hide() end
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
end

_G.HLBG = HLBG
