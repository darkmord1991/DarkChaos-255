--[[
    DC-InfoBar Gold Plugin
    Shows current gold, session change, realm total across characters and
    season currencies.

    Data Source: WoW API (GetMoney), DCAddonProtocol currency cache.
    Per-character gold is stored in DCInfoBarDB.goldByCharacter[realm][name].
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local GoldPlugin = {
    id = "DCInfoBar_Gold",
    name = "Gold",
    category = "character",
    type = "combo",
    side = "right",
    priority = 900,
    icon = "Interface\\Icons\\INV_Misc_Coin_01",
    updateInterval = 1.0,

    leftClickHint = "Toggle silver/copper display",
    rightClickHint = "Print session summary",

    _sessionStart = nil,
    _currentGold = 0,
    _lastGold = nil,
    _recentChange = 0,
    _recentChangeTimer = 0,
}

-- ============================================================================
-- Cross-character storage
-- ============================================================================

local function GetRealmStore()
    local db = DCInfoBar.db
    if not db then
        return nil
    end
    db.goldByCharacter = db.goldByCharacter or {}
    local realm = GetRealmName() or "Unknown"
    db.goldByCharacter[realm] = db.goldByCharacter[realm] or {}
    return db.goldByCharacter[realm]
end

local function SaveCurrentCharacter(money)
    local store = GetRealmStore()
    local name = UnitName("player")
    if not store or not name then
        return
    end
    local _, classFile = UnitClass("player")
    local entry = store[name] or {}
    entry.money = money
    entry.class = classFile
    entry.updatedAt = time()
    store[name] = entry
end

-- ============================================================================
-- Currencies (season token / essence via DCAddonProtocol)
-- ============================================================================

local function GetCurrencyRows()
    local rows = {}
    local central = DCInfoBar:GetProtocol()
    local balance = central and type(central.GetServerCurrencyBalance) == "function"
        and central:GetServerCurrencyBalance() or nil
    local byItemId = balance and balance.byItemId or {}

    local ids = central and type(central.GetTokenItemIDs) == "function" and central:GetTokenItemIDs() or {}
    table.sort(ids, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)

    for _, rawId in ipairs(ids) do
        local itemId = tonumber(rawId) or 0
        if itemId > 0 then
            local count = tonumber(byItemId[itemId]) or GetItemCount(itemId, true) or 0
            if count > 0 then
                local info = type(central.GetTokenInfo) == "function" and central:GetTokenInfo(itemId) or nil
                local q = info and info.rarity and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[info.rarity]
                table.insert(rows, {
                    name = (info and info.name) or ("Currency " .. itemId),
                    icon = (info and info.icon) or "Interface\\Icons\\INV_Misc_Coin_01",
                    count = count,
                    r = q and q.r or 1, g = q and q.g or 1, b = q and q.b or 1,
                })
            end
        end
    end
    return rows
end

-- ============================================================================
-- Plugin
-- ============================================================================

function GoldPlugin:OnActivate()
    local money = GetMoney()
    -- Session survives disable/enable of the plugin.
    if not self._sessionStart then
        self._sessionStart = money
    end
    self._currentGold = money
    self._lastGold = money
    SaveCurrentCharacter(money)
end

function GoldPlugin:OnUpdate(elapsed)
    self._currentGold = GetMoney()

    if self._currentGold ~= self._lastGold then
        self._recentChange = self._currentGold - (self._lastGold or self._currentGold)
        self._recentChangeTimer = 3
        self._lastGold = self._currentGold
        SaveCurrentCharacter(self._currentGold)
    elseif self._recentChangeTimer > 0 then
        self._recentChangeTimer = self._recentChangeTimer - (elapsed or 0)
    end

    local color = "white"
    if self._recentChangeTimer > 0 and DCInfoBar:GetPluginSetting(self.id, "showSessionChange") ~= false then
        color = (self._recentChange > 0) and "green" or "red"
    end

    return "", DCInfoBar:FormatGold(self._currentGold), color
end

local function CopperString(copper)
    copper = tonumber(copper) or 0
    return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100)
end

function GoldPlugin:OnTooltip(tooltip)
    tooltip:AddLine("Gold", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)

    tooltip:AddDoubleLine("Current:", CopperString(self._currentGold), 0.7, 0.7, 0.7, 1, 0.82, 0)

    -- Session
    tooltip:AddLine(" ")
    tooltip:AddLine("|cff32c4ffSession|r")
    local sessionChange = self._currentGold - (self._sessionStart or self._currentGold)
    tooltip:AddDoubleLine("Started With:", DCInfoBar:FormatGold(self._sessionStart), 0.7, 0.7, 0.7, 1, 1, 1)
    if sessionChange >= 0 then
        tooltip:AddDoubleLine("Gained:", "+" .. DCInfoBar:FormatGold(sessionChange), 0.7, 0.7, 0.7, 0.3, 1, 0.5)
    else
        tooltip:AddDoubleLine("Lost:", DCInfoBar:FormatGold(sessionChange), 0.7, 0.7, 0.7, 1, 0.3, 0.3)
    end

    -- Realm total across characters
    local store = GetRealmStore()
    if store then
        local chars, total = {}, 0
        for name, entry in pairs(store) do
            local money = tonumber(entry.money) or 0
            total = total + money
            table.insert(chars, { name = name, money = money, class = entry.class })
        end
        if #chars > 1 then
            table.sort(chars, function(a, b) return a.money > b.money end)
            tooltip:AddLine(" ")
            tooltip:AddLine("|cff32c4ffCharacters (" .. (GetRealmName() or "") .. ")|r")
            for i, c in ipairs(chars) do
                if i > 10 then
                    break
                end
                local cc = c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
                tooltip:AddDoubleLine("  " .. c.name, DCInfoBar:FormatGold(c.money),
                    cc and cc.r or 0.8, cc and cc.g or 0.8, cc and cc.b or 0.8, 1, 1, 1)
            end
            tooltip:AddDoubleLine("Total:", DCInfoBar:FormatGold(total), 0.7, 0.7, 0.7, 1, 0.82, 0)
        end
    end

    -- Currencies
    local rows = GetCurrencyRows()
    if #rows > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff32c4ffCurrencies|r")
        for _, row in ipairs(rows) do
            tooltip:AddDoubleLine("  " .. row.name, DCInfoBar:FormatNumber(row.count) .. " |T" .. row.icon .. ":12|t",
                0.7, 0.7, 0.7, row.r, row.g, row.b)
        end
    end

    local season = DCInfoBar.serverData.season
    if (season.id or 0) > 0 and season._progressReceived then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff888888Weekly Progress|r")
        tooltip:AddDoubleLine("  Tokens:", (season.weeklyTokens or 0) .. "/" .. (season.weeklyCap or 0),
            0.5, 0.5, 0.5, 1, 0.82, 0)
        tooltip:AddDoubleLine("  Essence:", (season.weeklyEssence or 0) .. "/" .. (season.essenceCap or 0),
            0.5, 0.5, 0.5, 0.64, 0.21, 0.93)
    end

    local prestige = DCInfoBar.serverData.prestige
    if prestige.received and ((prestige.level or 0) > 0 or prestige.canPrestige) then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cffaa00ffPrestige|r")
        tooltip:AddDoubleLine("  Level:", prestige.level .. "/" .. prestige.maxLevel, 0.7, 0.7, 0.7, 0.8, 0.5, 1)
        if (prestige.totalBonus or 0) > 0 then
            tooltip:AddDoubleLine("  All Stats:", "+" .. prestige.totalBonus .. "%", 0.7, 0.7, 0.7, 0.5, 1, 0.5)
        end
        if prestige.canPrestige then
            tooltip:AddLine("  |cff00ff00Ready to Prestige!|r")
        end
    end
end

function GoldPlugin:OnClick(button)
    if button == "LeftButton" then
        local current = DCInfoBar:GetPluginSetting(self.id, "showSilverCopper")
        DCInfoBar:SetPluginSetting(self.id, "showSilverCopper", not current)
        self._elapsed = 999
        DCInfoBar:Print("Silver/copper display: " .. (not current and "ON" or "OFF"))
    elseif button == "RightButton" then
        local sessionChange = self._currentGold - (self._sessionStart or self._currentGold)
        DCInfoBar:Print("Session gold: " .. (sessionChange >= 0 and "+" or "") .. DCInfoBar:FormatGold(sessionChange))
    end
end

function GoldPlugin:OnCreateOptions(parent, yOffset)
    DCInfoBar:CreateCheckbox(parent, "Show silver and copper", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showSilverCopper", checked)
        self._elapsed = 999
    end, DCInfoBar:GetPluginSetting(self.id, "showSilverCopper"))
    yOffset = yOffset - 30

    DCInfoBar:CreateCheckbox(parent, "Color based on recent change", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showSessionChange", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "showSessionChange") ~= false)

    return yOffset - 30
end

DCInfoBar:RegisterPlugin(GoldPlugin)
