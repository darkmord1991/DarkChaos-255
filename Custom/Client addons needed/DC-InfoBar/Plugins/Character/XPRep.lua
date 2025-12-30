--[[
    DC-InfoBar XP/Rep Plugin
    Shows XP/hour and reputation session gains

    Data Sources: WoW API (UnitXP/UnitXPMax, GetWatchedFactionInfo)

    UX:
    - Bar shows XP/hour
    - Tooltip shows session XP stats and reputation gain summary
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

    _sessionStartTime = 0,
    _lastXP = 0,
    _totalXPGained = 0,

    _watchedFaction = nil,
    _watchedStartValue = nil,
    _watchedStartStanding = nil,
    _repGains = {},

    _eventFrame = nil,
}

local function SafeGetWatchedFactionInfo()
    if type(GetWatchedFactionInfo) ~= "function" then
        return nil
    end

    local name, standingId, minValue, maxValue, value = GetWatchedFactionInfo()
    if not name then
        return nil
    end

    return {
        name = name,
        standingId = standingId,
        minValue = minValue,
        maxValue = maxValue,
        value = value,
    }
end

local function EnsureEventFrame(self)
    if self._eventFrame then
        return
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_XP_UPDATE")
    f:RegisterEvent("PLAYER_LEVEL_UP")
    f:RegisterEvent("UPDATE_FACTION")

    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Reset baselines on load / reload.
            self._sessionStartTime = GetTime() or 0
            self._lastXP = UnitXP("player") or 0
            self._totalXPGained = 0

            local rep = SafeGetWatchedFactionInfo()
            if rep then
                self._watchedFaction = rep.name
                self._watchedStartValue = rep.value
                self._watchedStartStanding = rep.standingId
                self._repGains[self._watchedFaction] = 0
            end
            return
        end

        if event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
            local currentXP = UnitXP("player") or 0
            local delta = currentXP - (self._lastXP or 0)

            -- Handle level-up XP rollover (XP drops after ding).
            if delta < 0 then
                delta = currentXP
            end

            if delta > 0 then
                self._totalXPGained = (self._totalXPGained or 0) + delta
            end

            self._lastXP = currentXP
            return
        end

        if event == "UPDATE_FACTION" then
            local rep = SafeGetWatchedFactionInfo()
            if not rep then
                self._watchedFaction = nil
                self._watchedStartValue = nil
                self._watchedStartStanding = nil
                return
            end

            -- If watched faction changed, reset the baseline for that faction.
            if self._watchedFaction ~= rep.name then
                self._watchedFaction = rep.name
                self._watchedStartValue = rep.value
                self._watchedStartStanding = rep.standingId
                self._repGains[self._watchedFaction] = 0
                return
            end

            if self._watchedStartValue == nil then
                self._watchedStartValue = rep.value
                self._watchedStartStanding = rep.standingId
                self._repGains[self._watchedFaction] = 0
                return
            end

            local gained = (rep.value or 0) - (self._watchedStartValue or 0)
            self._repGains[self._watchedFaction] = gained
        end
    end)

    self._eventFrame = f
end

function XPRepPlugin:OnActivate()
    self._sessionStartTime = GetTime() or 0
    self._lastXP = UnitXP("player") or 0
    self._totalXPGained = 0
    self._repGains = self._repGains or {}

    local rep = SafeGetWatchedFactionInfo()
    if rep then
        self._watchedFaction = rep.name
        self._watchedStartValue = rep.value
        self._watchedStartStanding = rep.standingId
        self._repGains[self._watchedFaction] = 0
    else
        self._watchedFaction = nil
        self._watchedStartValue = nil
        self._watchedStartStanding = nil
    end

    EnsureEventFrame(self)
end

function XPRepPlugin:OnUpdate(_elapsed)
    local now = GetTime() or 0
    local sessionSeconds = math.max(1, now - (self._sessionStartTime or now))
    local xpPerHour = math.floor(((self._totalXPGained or 0) / sessionSeconds) * 3600)

    -- At max level, UnitXPMax can be 0 on some servers.
    local xpMax = UnitXPMax and UnitXPMax("player") or 0
    local atMax = (xpMax == 0)

    local color = "white"
    if atMax then
        color = "gray"
    elseif (self._totalXPGained or 0) > 0 then
        color = "green"
    end

    return "XP/h", DCInfoBar:FormatNumber(xpPerHour), color
end

function XPRepPlugin:OnTooltip(tooltip)
    DCInfoBar:AddTooltipHeader(tooltip, "XP & Reputation")
    DCInfoBar:AddTooltipSeparator(tooltip)

    local now = GetTime() or 0
    local sessionSeconds = math.max(1, now - (self._sessionStartTime or now))
    local xpPerHour = math.floor(((self._totalXPGained or 0) / sessionSeconds) * 3600)

    tooltip:AddDoubleLine("Session Time:", DCInfoBar:FormatTimeShort(sessionSeconds), 0.7, 0.7, 0.7, 1, 1, 1)
    tooltip:AddDoubleLine("XP Gained:", DCInfoBar:FormatNumber(self._totalXPGained or 0), 0.7, 0.7, 0.7, 1, 1, 1)
    tooltip:AddDoubleLine("XP per Hour:", DCInfoBar:FormatNumber(xpPerHour), 0.7, 0.7, 0.7, 0.5, 1, 0.5)

    tooltip:AddLine(" ")
    tooltip:AddLine("|cff32c4ffReputation|r")

    local rep = SafeGetWatchedFactionInfo()
    if not rep then
        tooltip:AddLine("No watched faction", 0.7, 0.7, 0.7)
        return
    end

    local gained = 0
    if self._repGains and self._repGains[rep.name] then
        gained = self._repGains[rep.name]
    elseif self._watchedStartValue ~= nil then
        gained = (rep.value or 0) - (self._watchedStartValue or 0)
    end

    local gainText = (gained >= 0) and ("+" .. tostring(gained)) or tostring(gained)
    tooltip:AddDoubleLine("Watched:", rep.name, 0.7, 0.7, 0.7, 1, 0.82, 0)
    tooltip:AddDoubleLine("Session Gain:", gainText, 0.7, 0.7, 0.7, 0.5, 1, 0.5)

    if rep.minValue and rep.maxValue and rep.value then
        local cur = rep.value - rep.minValue
        local max = rep.maxValue - rep.minValue
        DCInfoBar:AddTooltipProgressBar(tooltip, cur, max, "Progress:")
    end
end

DCInfoBar:RegisterPlugin(XPRepPlugin)
