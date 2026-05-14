--[[
    DC-Central: Token/Essence Information and Shared Utilities
    
    Contains centralized functions for token/essence currency management,
    shared tooltip frame, and keystone item registry.
    
    This module extends DCAddonProtocol with token information functions.
    It is automatically loaded as part of the DC-AddonProtocol addon.
    
    Version: 1.0.0
    Date: December 2025
]]

local function InstallDCCentral(DC)
    if not DC or DC._dccentralInstalled then
        return true
    end
    DC._dccentralInstalled = true
    rawset(_G, "DCCentral", DC)

    -- Token and Essence Information (Seasonal Currency)
    DC.TOKEN_ITEM_ID = tonumber(DC.TOKEN_ITEM_ID) or 0
    DC.ESSENCE_ITEM_ID = tonumber(DC.ESSENCE_ITEM_ID) or 0

    local DEFAULT_TOKEN_INFO = {
        name = "Upgrade Token",
        icon = "Interface\\Icons\\INV_Misc_Token_ArgentCrusade",
        rarity = 2,
        type = "upgrade_token",
        description = "Used to upgrade regular items",
    }

    local DEFAULT_ESSENCE_INFO = {
        name = "Upgrade Essence",
        icon = "Interface\\Icons\\INV_Misc_Herb_Draenethisle",
        rarity = 3,
        type = "upgrade_essence",
        description = "Used to upgrade heirloom items",
    }

    DC.TokenInfo = DC.TokenInfo or {}

    local function CloneInfoTemplate(template, itemId)
        local info = { id = itemId }
        for key, value in pairs(template) do
            info[key] = value
        end
        return info
    end

    local function EnsureCurrencyInfoEntry(self, itemId, template)
        if not itemId or itemId <= 0 then
            return
        end

        if not self.TokenInfo[itemId] then
            self.TokenInfo[itemId] = CloneInfoTemplate(template, itemId)
        end
    end

    local function GetSafeItemCount(itemId)
        if not itemId or itemId <= 0 then
            return 0
        end

        if type(_G.GetItemCount) == "function" then
            local ok, count = pcall(_G.GetItemCount, itemId, true)
            if ok and type(count) == "number" then
                return count
            end
        end

        return 0
    end

    EnsureCurrencyInfoEntry(DC, DC.TOKEN_ITEM_ID, DEFAULT_TOKEN_INFO)
    EnsureCurrencyInfoEntry(DC, DC.ESSENCE_ITEM_ID, DEFAULT_ESSENCE_INFO)

    -- Keystone item IDs (M+2 through M+20): use the protocol core's shared map.
    if type(DC.SetKeystoneItemIds) == "function" then
        DC:SetKeystoneItemIds()
    elseif type(DC.KEYSTONE_ITEM_IDS) ~= "table" then
        DC.KEYSTONE_ITEM_IDS = {}
    end

    -- Optional server-reported currency balance
    DC.ServerCurrencyBalance = DC.ServerCurrencyBalance or {
        tokens = 0,
        emblems = 0,
        byItemId = {},
        updatedAt = nil,
    }

    function DC:SetServerCurrencyBalance(tokens, emblems)
        tokens = tonumber(tokens) or 0
        emblems = tonumber(emblems) or 0

        EnsureCurrencyInfoEntry(self, self.TOKEN_ITEM_ID, DEFAULT_TOKEN_INFO)
        EnsureCurrencyInfoEntry(self, self.ESSENCE_ITEM_ID, DEFAULT_ESSENCE_INFO)

        self.ServerCurrencyBalance.byItemId = self.ServerCurrencyBalance.byItemId or {}

        self.ServerCurrencyBalance.tokens = tokens
        self.ServerCurrencyBalance.emblems = emblems
        self.ServerCurrencyBalance.byItemId[self.TOKEN_ITEM_ID] = tokens
        self.ServerCurrencyBalance.byItemId[self.ESSENCE_ITEM_ID] = emblems
        self.ServerCurrencyBalance.updatedAt = time and time() or nil
    end

    function DC:GetServerCurrencyBalance()
        local cache = self.ServerCurrencyBalance or {}
        local byItemId = cache.byItemId or {}
        local hasServerSnapshot = cache.updatedAt ~= nil

        local tokens = hasServerSnapshot and (tonumber(cache.tokens) or 0) or GetSafeItemCount(self.TOKEN_ITEM_ID)
        local emblems = hasServerSnapshot and (tonumber(cache.emblems) or 0) or GetSafeItemCount(self.ESSENCE_ITEM_ID)

        if not hasServerSnapshot then
            self:SetServerCurrencyBalance(tokens, emblems)
            cache = self.ServerCurrencyBalance
            byItemId = cache.byItemId or {}
        else
            byItemId[self.TOKEN_ITEM_ID] = tokens
            byItemId[self.ESSENCE_ITEM_ID] = emblems
        end

        return {
            tokens = tokens,
            emblems = emblems,
            byItemId = byItemId,
            updatedAt = cache.updatedAt,
        }
    end

    function DC:GetTokenInfo(itemID)
        if not itemID then
            return nil
        end

        if itemID == self.TOKEN_ITEM_ID then
            EnsureCurrencyInfoEntry(self, itemID, DEFAULT_TOKEN_INFO)
        elseif itemID == self.ESSENCE_ITEM_ID then
            EnsureCurrencyInfoEntry(self, itemID, DEFAULT_ESSENCE_INFO)
        end

        return self.TokenInfo[itemID] or nil
    end

    function DC:IsTokenItem(itemID)
        return self:GetTokenInfo(itemID) ~= nil
    end

    function DC:GetTokenName(itemID)
        local info = self:GetTokenInfo(itemID)
        return info and info.name or nil
    end

    function DC:GetTokenIcon(itemID)
        local info = self:GetTokenInfo(itemID)
        return info and info.icon or nil
    end

    function DC:GetTokenItemIDs()
        local ids = {}
        for id in pairs(self.TokenInfo) do
            table.insert(ids, id)
        end
        return ids
    end

    function DC:GetPlayerTokenCount(itemID)
        if itemID then
            return GetSafeItemCount(itemID)
        end

        local total = 0
        for id in pairs(self.TokenInfo) do
            total = total + GetSafeItemCount(id)
        end
        return total
    end

    function DC:FormatTokenDisplay(itemID, count, colorCode)
        local info = self:GetTokenInfo(itemID)
        if not info then return "" end

        colorCode = colorCode or "|cffffffff"
        local endColor = "|r"
        return colorCode .. (count or 0) .. " " .. info.name .. endColor
    end

    function DC:FormatTokenWithIcon(itemID, count)
        local info = self:GetTokenInfo(itemID)
        if not info then return "" end

        local iconStr = "\124T" .. info.icon .. ":16:16:0:0:64:64:4:60:4:60\124t"
        if count then
            return iconStr .. " " .. count
        end
        return iconStr
    end

    function DC:GetCurrencyInfo()
        return {
            token = {
                id = self.TOKEN_ITEM_ID,
                info = self:GetTokenInfo(self.TOKEN_ITEM_ID),
                count = self:GetPlayerTokenCount(self.TOKEN_ITEM_ID),
            },
            essence = {
                id = self.ESSENCE_ITEM_ID,
                info = self:GetTokenInfo(self.ESSENCE_ITEM_ID),
                count = self:GetPlayerTokenCount(self.ESSENCE_ITEM_ID),
            },
        }
    end

    -- Shared Tooltip Support
    if not DC._dccentralTooltipFrame then
        local tooltipFrame = CreateFrame("Frame")
        DC._dccentralTooltipFrame = tooltipFrame
        tooltipFrame:RegisterEvent("PLAYER_LOGIN")
        tooltipFrame:SetScript("OnEvent", function()
            if not DC.scanTooltip then
                DC.scanTooltip = CreateFrame("GameTooltip", "DCScanTooltip", nil, "GameTooltipTemplate")
                DC.scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
            end
            rawset(_G, "DCScanTooltip", DC.scanTooltip)
        end)
    end

    return true
end

local function TryInit()
    local DC = rawget(_G, "DCAddonProtocol")
    if not DC then
        return false
    end
    return InstallDCCentral(DC)
end

if not TryInit() then
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self)
        if TryInit() then
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
        end
    end)
end
