--[[
    DC-InfoBar Gold Plugin
    Shows current gold and session changes
    
    Data Source: WoW API (GetMoney)
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

-- DC Currency Item IDs (from DarkChaos.Seasonal.TokenItemID/EssenceItemID)
local SEASONAL_TOKEN_ID = 300311
local SEASONAL_ESSENCE_ID = 300312

-- Additional currency item IDs (common custom currencies)
local CURRENCY_ITEMS = {
    { id = 300311, name = "Upgrade Tokens", icon = "Interface\\Icons\\INV_Misc_Token_ScarletCrusade", color = {1, 0.82, 0} },
    { id = 300312, name = "Seasonal Essence", icon = "Interface\\Icons\\Spell_Arcane_Arcane04", color = {0.64, 0.21, 0.93} },
    { id = 300313, name = "Prestige Points", icon = "Interface\\Icons\\Achievement_Level_80", color = {0.5, 1, 0.5} },
    { id = 300314, name = "PvP Tokens", icon = "Interface\\Icons\\INV_Jewelry_FrostwolfTrinket_05", color = {1, 0.3, 0.3} },
    { id = 300315, name = "Dungeon Tokens", icon = "Interface\\Icons\\INV_Misc_Token_ArgentDawn", color = {0.3, 0.7, 1} },
}

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
    rightClickHint = "Show session summary",
    
    _sessionStart = 0,
    _currentGold = 0,
    _lastGold = 0,
    _recentChange = 0,
    _recentChangeTimer = 0,
    _currencyCache = {},
}

-- Helper: Count items in bags, bank, and reagent bank
local function GetItemCount(itemId)
    local count = 0
    -- Check player bags (0-4)
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local id = tonumber(link:match("item:(%d+)"))
                if id == itemId then
                    local _, itemCount = GetContainerItemInfo(bag, slot)
                    count = count + (itemCount or 0)
                end
            end
        end
    end
    -- Check bank bags (5-11) - these exist if player has opened bank
    pcall(function()
        for bag = 5, 11 do
            local numSlots = GetContainerNumSlots(bag)
            if numSlots and numSlots > 0 then
                for slot = 1, numSlots do
                    local link = GetContainerItemLink(bag, slot)
                    if link then
                        local id = tonumber(link:match("item:(%d+)"))
                        if id == itemId then
                            local _, itemCount = GetContainerItemInfo(bag, slot)
                            count = count + (itemCount or 0)
                        end
                    end
                end
            end
        end
    end)
    -- Check reagent bank (bag 98) if available
    pcall(function()
        local numSlots = GetContainerNumSlots(98)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local link = GetContainerItemLink(98, slot)
                if link then
                    local id = tonumber(link:match("item:(%d+)"))
                    if id == itemId then
                        local _, itemCount = GetContainerItemInfo(98, slot)
                        count = count + (itemCount or 0)
                    end
                end
            end
        end
    end)
    return count
end

function GoldPlugin:OnActivate()
    -- Record starting gold for session tracking
    self._sessionStart = GetMoney()
    self._currentGold = self._sessionStart
    self._lastGold = self._sessionStart
end

function GoldPlugin:OnUpdate(elapsed)
    self._currentGold = GetMoney()
    
    -- Track recent changes for color feedback
    if self._currentGold ~= self._lastGold then
        self._recentChange = self._currentGold - self._lastGold
        self._recentChangeTimer = 3  -- Show change for 3 seconds
        self._lastGold = self._currentGold
    end
    
    if self._recentChangeTimer > 0 then
        self._recentChangeTimer = self._recentChangeTimer - elapsed
    end
    
    -- Format display
    local showSessionChange = DCInfoBar:GetPluginSetting(self.id, "showSessionChange")
    local goldText = DCInfoBar:FormatGold(self._currentGold)
    
    -- Color based on recent change
    local color = "white"
    if self._recentChangeTimer > 0 then
        if self._recentChange > 0 then
            color = "green"
        elseif self._recentChange < 0 then
            color = "red"
        end
    end
    
    return "", goldText, color
end

function GoldPlugin:OnTooltip(tooltip)
    tooltip:AddLine("Gold", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)
    
    -- Current gold breakdown
    local gold = math.floor(self._currentGold / 10000)
    local silver = math.floor((self._currentGold % 10000) / 100)
    local copper = self._currentGold % 100
    
    tooltip:AddDoubleLine("Current:", 
        string.format("%dg %ds %dc", gold, silver, copper),
        0.7, 0.7, 0.7, 1, 0.82, 0)
    
    -- Session stats
    tooltip:AddLine(" ")
    tooltip:AddLine("|cff32c4ffSession|r")
    
    local sessionChange = self._currentGold - self._sessionStart
    local sessionGold = math.floor(math.abs(sessionChange) / 10000)
    
    tooltip:AddDoubleLine("Started With:", 
        DCInfoBar:FormatGold(self._sessionStart),
        0.7, 0.7, 0.7, 1, 1, 1)
    
    if sessionChange >= 0 then
        tooltip:AddDoubleLine("Gained:", 
            "+" .. DCInfoBar:FormatGold(sessionChange),
            0.7, 0.7, 0.7, 0.3, 1, 0.5)
    else
        tooltip:AddDoubleLine("Lost:", 
            "-" .. DCInfoBar:FormatGold(math.abs(sessionChange)),
            0.7, 0.7, 0.7, 1, 0.3, 0.3)
    end
    
    -- Character total (this char only, no alts tracking in 3.3.5a without SavedVars)
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("This Character:", 
        DCInfoBar:FormatGold(self._currentGold),
        0.7, 0.7, 0.7, 1, 1, 1)
    
    -- Currencies section - scan inventory for all currency items
    tooltip:AddLine(" ")
    tooltip:AddLine("|cff32c4ffCurrencies|r")
    
    local foundAny = false
    for _, currency in ipairs(CURRENCY_ITEMS) do
        local count = GetItemCount(currency.id)
        if count > 0 then
            foundAny = true
            tooltip:AddDoubleLine(currency.name .. ":", 
                DCInfoBar:FormatNumber(count) .. " |T" .. currency.icon .. ":12|t",
                0.7, 0.7, 0.7, currency.color[1], currency.color[2], currency.color[3])
        end
    end
    
    -- Get currency from server (single source of truth via DCAddonProtocol)
    local tokenCount = 0
    local essenceCount = 0
    local central = rawget(_G, "DCAddonProtocol")
    if central and type(central.GetServerCurrencyBalance) == "function" then
        local balance = central:GetServerCurrencyBalance()
        if balance then
            tokenCount = balance.tokens or 0
            essenceCount = balance.emblems or 0
        end
    end
    
    -- Fallback to season data if central not available
    local seasonData = DCInfoBar.serverData and DCInfoBar.serverData.season
    local serverTokens = tokenCount > 0 and tokenCount or (seasonData and seasonData.totalTokens)
    local serverEssence = essenceCount > 0 and essenceCount or (seasonData and seasonData.totalEssence)
    
    if not foundAny or tokenCount == 0 then
        local displayTokens = tokenCount
        if (displayTokens or 0) == 0 and serverTokens and serverTokens > 0 then
            displayTokens = serverTokens
        end
        local tokenColor = (displayTokens and displayTokens > 0) and {1, 0.82, 0} or {0.5, 0.5, 0.5}
        tooltip:AddDoubleLine("Upgrade Tokens:", 
            DCInfoBar:FormatNumber(displayTokens or 0) .. " |TInterface\\Icons\\INV_Misc_Token_ScarletCrusade:12|t",
            0.7, 0.7, 0.7, tokenColor[1], tokenColor[2], tokenColor[3])
    end
    
    if not foundAny or essenceCount == 0 then
        local displayEssence = essenceCount
        if (displayEssence or 0) == 0 and serverEssence and serverEssence > 0 then
            displayEssence = serverEssence
        end
        local essenceColor = (displayEssence and displayEssence > 0) and {0.64, 0.21, 0.93} or {0.5, 0.5, 0.5}
        tooltip:AddDoubleLine("Seasonal Essence:", 
            DCInfoBar:FormatNumber(displayEssence or 0) .. " |TInterface\\Icons\\Spell_Arcane_Arcane04:12|t",
            0.7, 0.7, 0.7, essenceColor[1], essenceColor[2], essenceColor[3])
    end
    
    -- Weekly caps from season data (if available)
    local seasonData = DCInfoBar.serverData and DCInfoBar.serverData.season
    if seasonData and seasonData.id > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff888888Weekly Progress (Server)|r", 0.5, 0.5, 0.5)
        tooltip:AddDoubleLine("  Tokens:", 
            (seasonData.weeklyTokens or 0) .. "/" .. (seasonData.weeklyCap or 500),
            0.5, 0.5, 0.5, 1, 0.82, 0)
        tooltip:AddDoubleLine("  Essence:", 
            (seasonData.weeklyEssence or 0) .. "/" .. (seasonData.essenceCap or 200),
            0.5, 0.5, 0.5, 0.64, 0.21, 0.93)

        -- Show inventory counts reported by server if available (fallback to client found counts)
        if seasonData.totalTokens and seasonData.totalTokens > 0 then
            tooltip:AddDoubleLine("  Inventory Tokens (Server):", 
                DCInfoBar:FormatNumber(seasonData.totalTokens), 0.5, 0.5, 0.5, 1, 0.82, 0)
        end
        if seasonData.totalEssence and seasonData.totalEssence > 0 then
            tooltip:AddDoubleLine("  Inventory Essence (Server):", 
                DCInfoBar:FormatNumber(seasonData.totalEssence), 0.5, 0.5, 0.5, 0.64, 0.21, 0.93)
        end
    end
    
    -- Prestige XP Bonus section
    local prestigePlugin = DCInfoBar.plugins and DCInfoBar.plugins["DCInfoBar_Prestige"]
    if prestigePlugin and prestigePlugin._dataReceived then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cffaa00ffPrestige Bonuses|r")
        
        if prestigePlugin._prestigeLevel > 0 then
            tooltip:AddDoubleLine("  Prestige Level:", 
                prestigePlugin._prestigeLevel .. "/" .. prestigePlugin._maxPrestigeLevel,
                0.7, 0.7, 0.7, 0.8, 0.5, 1)
        end
        
        if prestigePlugin._totalBonus > 0 then
            tooltip:AddDoubleLine("  XP Bonus:", 
                "+" .. prestigePlugin._totalBonus .. "%",
                0.7, 0.7, 0.7, 0.5, 1, 0.5)
            tooltip:AddDoubleLine("  Stat Bonus:", 
                "+" .. prestigePlugin._totalBonus .. "%",
                0.7, 0.7, 0.7, 0.5, 1, 0.5)
        end
        
        if prestigePlugin._canPrestige then
            tooltip:AddLine(" ")
            tooltip:AddLine("|cff00ff00Ready to Prestige!|r")
        end
    end
end

function GoldPlugin:OnClick(button)
    if button == "LeftButton" then
        -- Toggle silver/copper display
        local current = DCInfoBar:GetPluginSetting(self.id, "showSilverCopper")
        DCInfoBar:SetPluginSetting(self.id, "showSilverCopper", not current)
        DCInfoBar:Print("Silver/copper display: " .. (not current and "ON" or "OFF"))
    elseif button == "RightButton" then
        -- Show session summary
        local sessionChange = self._currentGold - self._sessionStart
        local prefix = sessionChange >= 0 and "+" or ""
        DCInfoBar:Print("Session gold: " .. prefix .. DCInfoBar:FormatGold(sessionChange))
    end
end

function GoldPlugin:OnCreateOptions(parent, yOffset)
    local silverCB = DCInfoBar:CreateCheckbox(parent, "Show silver and copper", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showSilverCopper", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "showSilverCopper"))
    yOffset = yOffset - 30
    
    local sessionCB = DCInfoBar:CreateCheckbox(parent, "Color based on recent change", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showSessionChange", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "showSessionChange") ~= false)
    
    return yOffset - 30
end

-- Register plugin
DCInfoBar:RegisterPlugin(GoldPlugin)
