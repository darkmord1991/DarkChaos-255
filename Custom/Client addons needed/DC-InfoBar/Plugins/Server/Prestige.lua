--[[
    DC-InfoBar Prestige Plugin
    Shows prestige level and status, blinks when ready to prestige

    Data Source: DCAddonProtocol PRES module
      SMSG_INFO     (0x10): prestigeLevel, maxPrestigeLevel, requiredLevel, currentLevel,
                            canPrestige, statBonusPercent, totalBonusPercent, totalPrestiges
      SMSG_BONUSES  (0x11): bonusPerLevel, totalBonus, nextLevelBonus, atMaxPrestige,
                            bonuses[] { level, bonus, cumulative, unlocked }
      SMSG_LEVEL_UP (0x12): newLevel, maxLevel, totalBonus, bonusPerLevel, atMaxPrestige
    The initial SMSG_INFO request is sent by Core.lua (RequestServerData).
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local PRES_CMSG_GET_INFO    = 0x01
local PRES_CMSG_GET_BONUSES = 0x02
local PRES_SMSG_INFO        = 0x10
local PRES_SMSG_BONUSES     = 0x11
local PRES_SMSG_LEVEL_UP    = 0x12

local PrestigePlugin = {
    id = "DCInfoBar_Prestige",
    name = "Prestige",
    category = "server",
    type = "combo",
    side = "left",
    priority = 15,  -- After Season
    icon = "Interface\\Icons\\Achievement_Level_80",
    updateInterval = 0.5,  -- blink cadence when prestige is ready

    leftClickHint = "Show prestige summary",
    rightClickHint = "Refresh prestige data",
}

local function GetData()
    return DCInfoBar.serverData.prestige
end

local function RequestInfo()
    local proto = DCInfoBar:GetProtocol()
    if proto then
        proto:Request("PRES", PRES_CMSG_GET_INFO, {})
    end
end

local function RequestBonuses()
    local proto = DCInfoBar:GetProtocol()
    if proto then
        proto:Request("PRES", PRES_CMSG_GET_BONUSES, {})
    end
end

local function OnInfo(data)
    if type(data) ~= "table" then
        return
    end

    local p = GetData()
    p.received = true
    p.enabled = data.enabled ~= false
    p.level = tonumber(data.prestigeLevel or data.level) or 0
    p.maxLevel = tonumber(data.maxPrestigeLevel or data.maxLevel) or p.maxLevel or 0
    p.requiredLevel = tonumber(data.requiredLevel) or p.requiredLevel or 255
    p.canPrestige = data.canPrestige == true
    p.bonusPerLevel = tonumber(data.statBonusPercent) or p.bonusPerLevel or 0
    p.totalBonus = tonumber(data.totalBonusPercent) or (p.level * p.bonusPerLevel)
    p.totalPrestiges = tonumber(data.totalPrestiges) or p.totalPrestiges or 0

    PrestigePlugin._elapsed = 999
    DCInfoBar:Debug("Prestige data received: P" .. p.level)
end

local function OnBonuses(data)
    if type(data) ~= "table" then
        return
    end

    local p = GetData()
    p.bonusPerLevel = tonumber(data.bonusPerLevel) or p.bonusPerLevel
    p.totalBonus = tonumber(data.totalBonus) or p.totalBonus
    p.nextLevelBonus = tonumber(data.nextLevelBonus)
    p.atMaxPrestige = data.atMaxPrestige == true

    local bonuses = data.bonuses
    if type(bonuses) == "string" and DCInfoBar:GetProtocol() and DCInfoBar:GetProtocol().DecodeJSON then
        -- Older servers sent the array pre-encoded as a string.
        local ok, decoded = pcall(DCInfoBar:GetProtocol().DecodeJSON, DCInfoBar:GetProtocol(), bonuses)
        bonuses = ok and decoded or nil
    end
    if type(bonuses) == "table" then
        p.bonuses = bonuses
    end
end

-- A prestige resets the character level, so the cached info is stale: re-ask.
local function OnLevelUp(data)
    if type(data) == "table" then
        local p = GetData()
        p.level = tonumber(data.newLevel) or p.level
        p.totalBonus = tonumber(data.totalBonus) or p.totalBonus
        p.bonusPerLevel = tonumber(data.bonusPerLevel) or p.bonusPerLevel
        p.canPrestige = false
        PrestigePlugin._elapsed = 999
    end
    RequestInfo()
end

-- Registered at load (not in OnActivate) so the data stays current for other
-- consumers (Gold tooltip, DC-Welcome) even while the plugin is disabled.
do
    local proto = DCInfoBar.GetProtocol and DCInfoBar:GetProtocol()
    if proto and proto.RegisterHandler then
        proto:RegisterHandler("PRES", PRES_SMSG_INFO, OnInfo)
        proto:RegisterHandler("PRES", PRES_SMSG_BONUSES, OnBonuses)
        proto:RegisterHandler("PRES", PRES_SMSG_LEVEL_UP, OnLevelUp)
    end
end

function PrestigePlugin:OnActivate()
    if self._levelFrame then
        return
    end

    -- canPrestige flips when the character reaches the required level.
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LEVEL_UP")
    f:SetScript("OnEvent", function(_, _, newLevel)
        local p = GetData()
        if p.received and (tonumber(newLevel) or 0) >= (p.requiredLevel or 255) then
            RequestInfo()
        end
    end)
    self._levelFrame = f
end

function PrestigePlugin:OnDeactivate()
    if self._levelFrame then
        self._levelFrame:UnregisterAllEvents()
        self._levelFrame = nil
    end
end

function PrestigePlugin:OnUpdate(elapsed)
    local p = GetData()
    if not p.received then
        return "", "P?"
    end

    if p.canPrestige then
        if DCInfoBar:GetPluginSetting(self.id, "blinkWhenReady") ~= false then
            self._blinkState = not self._blinkState
        else
            self._blinkState = true
        end
        local color = self._blinkState and "|cff00ff00" or "|cffffff00"
        return "", color .. "PRESTIGE READY!|r"
    end

    if p.level > 0 then
        return "", "P" .. p.level .. " (+" .. p.totalBonus .. "%)"
    end

    local required = math.max(1, p.requiredLevel or 255)
    local progress = math.floor(math.min(1, UnitLevel("player") / required) * 100)
    return "", "P0 (" .. progress .. "%)"
end

function PrestigePlugin:OnTooltip(tooltip)
    local p = GetData()

    tooltip:AddLine("Prestige System", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)

    if not p.received then
        tooltip:AddLine("Waiting for server data...", 0.7, 0.7, 0.7)
        return
    end
    if not p.enabled then
        tooltip:AddLine("Prestige is disabled on this realm.", 0.7, 0.7, 0.7)
        return
    end

    if p.canPrestige then
        tooltip:AddLine("|cff00ff00PRESTIGE READY!|r")
        tooltip:AddLine("Reset to level 1 for a permanent stat bonus.", 0.7, 0.7, 0.7, true)
        tooltip:AddLine(" ")
    end

    tooltip:AddDoubleLine("Prestige Level:", p.level .. " / " .. p.maxLevel, 0.7, 0.7, 0.7, 1, 0.82, 0)
    tooltip:AddDoubleLine("Character Level:", UnitLevel("player") .. " / " .. p.requiredLevel, 0.7, 0.7, 0.7, 1, 1, 1)
    if (p.totalPrestiges or 0) > 0 then
        tooltip:AddDoubleLine("Total Prestiges:", p.totalPrestiges, 0.7, 0.7, 0.7, 1, 1, 1)
    end

    if (p.totalBonus or 0) > 0 then
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("All Stats:", "+" .. p.totalBonus .. "%", 0.7, 0.7, 0.7, 0.5, 1, 0.5)
    end

    if p.level >= p.maxLevel and p.maxLevel > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff00ff00Maximum Prestige Achieved!|r")
    else
        local nextBonus = p.nextLevelBonus or ((p.level + 1) * (p.bonusPerLevel or 0))
        if nextBonus > 0 then
            tooltip:AddLine(" ")
            tooltip:AddLine("Next prestige: +" .. nextBonus .. "% total bonus", 0.5, 0.5, 0.5)
        end
        if not p.canPrestige then
            local levelsNeeded = math.max(0, p.requiredLevel - UnitLevel("player"))
            tooltip:AddDoubleLine("Levels to Prestige:", levelsNeeded, 0.7, 0.7, 0.7, 1, 0.82, 0)
        end
    end
end

function PrestigePlugin:OnClick(button)
    local p = GetData()
    if button == "LeftButton" then
        if not p.received then
            DCInfoBar:Print("Prestige data not received yet.")
        elseif p.canPrestige then
            DCInfoBar:Print("|cff00ff00Ready to prestige!|r Visit a Prestige NPC to reset.")
        else
            DCInfoBar:Print(string.format("Prestige %d/%d, +%s%% all stats. %d more levels to prestige.",
                p.level, p.maxLevel, tostring(p.totalBonus or 0),
                math.max(0, (p.requiredLevel or 255) - UnitLevel("player"))))
        end
    elseif button == "RightButton" then
        RequestInfo()
        RequestBonuses()
        DCInfoBar:Print("Refreshing prestige data...")
    end
end

function PrestigePlugin:OnCreateOptions(parent, yOffset)
    DCInfoBar:CreateCheckbox(parent, "Blink when prestige ready", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "blinkWhenReady", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "blinkWhenReady") ~= false)

    return yOffset - 30
end

DCInfoBar:RegisterPlugin(PrestigePlugin)
