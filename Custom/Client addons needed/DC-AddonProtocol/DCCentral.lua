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

    -- Token and Essence Information (Seasonal Currency)
    DC.TOKEN_ITEM_ID = 300311
    DC.ESSENCE_ITEM_ID = 300312

    DC.TokenInfo = {
        [300311] = {
            id = 300311,
            name = "Upgrade Token",
            icon = "Interface\\Icons\\INV_Misc_Token_ArgentCrusade",
            rarity = 2,
            type = "upgrade_token",
            description = "Used to upgrade regular items",
        },
        [300312] = {
            id = 300312,
            name = "Upgrade Essence",
            icon = "Interface\\Icons\\INV_Misc_Herb_Draenethisle",
            rarity = 3,
            type = "upgrade_essence",
            description = "Used to upgrade heirloom items",
        },
    }

    -- Keystone item IDs (M+2 through M+20): mirror server constants
    DC.KEYSTONE_ITEM_IDS = {
        [300313] = true, [300314] = true, [300315] = true, [300316] = true, [300317] = true,
        [300318] = true, [300319] = true, [300320] = true, [300321] = true, [300322] = true,
        [300323] = true, [300324] = true, [300325] = true, [300326] = true, [300327] = true,
        [300328] = true, [300329] = true, [300330] = true, [300331] = true,
    }

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

        self.ServerCurrencyBalance.tokens = tokens
        self.ServerCurrencyBalance.emblems = emblems
        self.ServerCurrencyBalance.byItemId[self.TOKEN_ITEM_ID] = tokens
        self.ServerCurrencyBalance.byItemId[self.ESSENCE_ITEM_ID] = emblems
        self.ServerCurrencyBalance.updatedAt = time and time() or nil
    end

    function DC:GetServerCurrencyBalance()
        return self.ServerCurrencyBalance
    end

    function DC:GetTokenInfo(itemID)
        return self.TokenInfo[itemID] or nil
    end

    function DC:IsTokenItem(itemID)
        return self.TokenInfo[itemID] ~= nil
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
            local bal = self.ServerCurrencyBalance
            if bal and bal.byItemId and bal.byItemId[itemID] ~= nil then
                return bal.byItemId[itemID] or 0
            end
            return GetItemCount(itemID) or 0
        end

        local total = 0
        for id in pairs(self.TokenInfo) do
            total = total + (self:GetPlayerTokenCount(id) or 0)
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
