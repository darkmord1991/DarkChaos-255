--[[
    DC-InfoBar XP/Rep Plugin
    Shows XP/hour and reputation session gains

    Data Sources: WoW API (UnitXP/UnitXPMax, GetWatchedFactionInfo)

    UX:
    - Bar shows XP/hour (hidden at max level when hideAtMaxLevel is set)
    - Tooltip shows level progress, session XP stats and reputation gain
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local XPRepPlugin = {
    id = "DCInfoBar_XPRep",
    name = "XP/Rep",
    category = "character",
    type = "text",
    side = "left",
    priority = 320,
    icon = "Interface\\Icons\\INV_Misc_Book_09",
    updateInterval = 1.0,

    rightClickHint = "Reset session",

    _sessionStartTime = nil,
    _lastXP = 0,
    _lastXPMax = 0,
    _totalXPGained = 0,
    _repStart = {},     -- [factionName] = value when first seen this session
}

local function GetWatchedFaction()
    local name, standingId, minValue, maxValue, value = GetWatchedFactionInfo()
    if not name then
        return nil
    end
    return { name = name, standingId = standingId, minValue = minValue, maxValue = maxValue, value = value }
end

function XPRepPlugin:ResetSession()
    self._sessionStartTime = GetTime()
    self._lastXP = UnitXP("player") or 0
    self._lastXPMax = UnitXPMax("player") or 0
    self._totalXPGained = 0
    wipe(self._repStart)

    local rep = GetWatchedFaction()
    if rep then
        self._repStart[rep.name] = rep.value
    end
end

function XPRepPlugin:OnXPUpdate()
    local xp = UnitXP("player") or 0
    local xpMax = UnitXPMax("player") or 0

    local delta = xp - self._lastXP
    if delta < 0 then
        -- Level-up rollover: the rest of the old level plus the new level's progress.
        delta = math.max(0, self._lastXPMax - self._lastXP) + xp
    end
    if delta > 0 then
        self._totalXPGained = self._totalXPGained + delta
    end

    self._lastXP = xp
    self._lastXPMax = xpMax
end

function XPRepPlugin:OnActivate()
    -- The session survives loading screens; it only starts on first activation
    -- (or an explicit reset), not on every PLAYER_ENTERING_WORLD.
    if not self._sessionStartTime then
        self:ResetSession()
    end

    if self._eventFrame then
        return
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_XP_UPDATE")
    f:RegisterEvent("UPDATE_FACTION")
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_XP_UPDATE" then
            XPRepPlugin:OnXPUpdate()
        else
            local rep = GetWatchedFaction()
            if rep and XPRepPlugin._repStart[rep.name] == nil then
                XPRepPlugin._repStart[rep.name] = rep.value
            end
        end
    end)
    self._eventFrame = f
end

function XPRepPlugin:OnDeactivate()
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
        self._eventFrame = nil
    end
end

local function IsAtMaxLevel()
    return (UnitXPMax("player") or 0) == 0
end

function XPRepPlugin:GetXPPerHour()
    local sessionSeconds = math.max(1, GetTime() - (self._sessionStartTime or GetTime()))
    return math.floor(self._totalXPGained / sessionSeconds * 3600), sessionSeconds
end

function XPRepPlugin:OnUpdate(elapsed)
    local atMax = IsAtMaxLevel()
    local hide = atMax and DCInfoBar:GetPluginSetting(self.id, "hideAtMaxLevel") ~= false

    if self.button then
        if hide and self.button:IsShown() then
            self.button:Hide()
        elseif not hide and not self.button:IsShown() then
            self.button:Show()
        end
    end
    if hide then
        return "", ""
    end

    local xpPerHour = self:GetXPPerHour()
    local color = atMax and "gray" or (self._totalXPGained > 0 and "green" or "white")
    return "XP/h", DCInfoBar:FormatNumber(xpPerHour), color
end

function XPRepPlugin:OnTooltip(tooltip)
    DCInfoBar:AddTooltipHeader(tooltip, "XP & Reputation")
    DCInfoBar:AddTooltipSeparator(tooltip)

    local xpPerHour, sessionSeconds = self:GetXPPerHour()
    local xp, xpMax = UnitXP("player") or 0, UnitXPMax("player") or 0

    if xpMax > 0 then
        DCInfoBar:AddTooltipProgressBar(tooltip, xp, xpMax, "Level " .. UnitLevel("player") .. ":")
        local rested = GetXPExhaustion()
        if rested and rested > 0 then
            tooltip:AddDoubleLine("Rested:", DCInfoBar:FormatNumber(rested), 0.7, 0.7, 0.7, 0.4, 0.6, 1)
        end
        if xpPerHour > 0 then
            tooltip:AddDoubleLine("Time to level:", DCInfoBar:FormatTimeShort((xpMax - xp) / xpPerHour * 3600),
                0.7, 0.7, 0.7, 1, 1, 1)
        end
        tooltip:AddLine(" ")
    end

    tooltip:AddDoubleLine("Session Time:", DCInfoBar:FormatTimeShort(sessionSeconds), 0.7, 0.7, 0.7, 1, 1, 1)
    tooltip:AddDoubleLine("XP Gained:", DCInfoBar:FormatNumber(self._totalXPGained), 0.7, 0.7, 0.7, 1, 1, 1)
    tooltip:AddDoubleLine("XP per Hour:", DCInfoBar:FormatNumber(xpPerHour), 0.7, 0.7, 0.7, 0.5, 1, 0.5)

    tooltip:AddLine(" ")
    tooltip:AddLine("|cff32c4ffReputation|r")

    local rep = GetWatchedFaction()
    if not rep then
        tooltip:AddLine("No watched faction", 0.7, 0.7, 0.7)
        return
    end

    local start = self._repStart[rep.name]
    local gained = start and (rep.value - start) or 0
    tooltip:AddDoubleLine("Watched:", rep.name, 0.7, 0.7, 0.7, 1, 0.82, 0)
    tooltip:AddDoubleLine("Standing:", _G["FACTION_STANDING_LABEL" .. rep.standingId] or rep.standingId,
        0.7, 0.7, 0.7, 1, 1, 1)
    tooltip:AddDoubleLine("Session Gain:", (gained >= 0 and "+" or "") .. gained, 0.7, 0.7, 0.7, 0.5, 1, 0.5)
    DCInfoBar:AddTooltipProgressBar(tooltip, rep.value - rep.minValue, rep.maxValue - rep.minValue, "Progress:")
end

function XPRepPlugin:OnClick(button)
    if button == "RightButton" then
        self:ResetSession()
        self._elapsed = 999
        DCInfoBar:Print("XP/Rep session reset.")
    end
end

function XPRepPlugin:OnCreateOptions(parent, yOffset)
    DCInfoBar:CreateCheckbox(parent, "Hide at max level", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "hideAtMaxLevel", checked)
        self._elapsed = 999
    end, DCInfoBar:GetPluginSetting(self.id, "hideAtMaxLevel") ~= false)

    return yOffset - 30
end

DCInfoBar:RegisterPlugin(XPRepPlugin)
