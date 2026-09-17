--[[
    DC-InfoBar Keystone Plugin
    Shows current Mythic+ keystone level and dungeon

    Data Sources:
    1. Bag scan: keystone items 300313-300331 are M+2..M+20, so the item id
       alone gives the level (no tooltip parsing).
    2. MPLUS SMSG_KEY_INFO (handled in Core.lua): dungeon, depleted flag,
       weekly/season best. Requested by Core.lua RequestServerData.
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

-- Mirrors MythicPlusConstants::KEYSTONE_ITEM_IDS (dc_mythicplus_constants.h).
local KEYSTONE_FIRST_ITEM = 300313
local KEYSTONE_FIRST_LEVEL = 2
local KEYSTONE_LAST_ITEM = 300331

local MPLUS_CMSG_GET_KEY_INFO = 0x01

local KeystonePlugin = {
    id = "DCInfoBar_Keystone",
    name = "Keystone",
    category = "server",
    type = "combo",
    side = "left",
    priority = 20,
    icon = "Interface\\Icons\\INV_Relics_IdolofHealth",
    updateInterval = 5.0,

    leftClickHint = "Open Group Finder",
    rightClickHint = "Link keystone in chat",

    _inventoryKeystone = nil,
}

local function KeystoneLevelForItem(itemId)
    if itemId >= KEYSTONE_FIRST_ITEM and itemId <= KEYSTONE_LAST_ITEM then
        return KEYSTONE_FIRST_LEVEL + (itemId - KEYSTONE_FIRST_ITEM)
    end
    return nil
end

function KeystonePlugin:ScanInventoryForKeystone()
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemId = GetContainerItemID(bag, slot)
            local level = itemId and KeystoneLevelForItem(itemId)
            if level then
                self._inventoryKeystone = {
                    level = level,
                    itemLink = GetContainerItemLink(bag, slot),
                }
                return self._inventoryKeystone
            end
        end
    end

    self._inventoryKeystone = nil
    return nil
end

-- Merged view: bag scan is authoritative for "do I hold a key / which level"
-- (instant, no round-trip); the server adds dungeon and best runs.
function KeystonePlugin:GetKeyInfo()
    local inv = self._inventoryKeystone
    local server = DCInfoBar.serverData.keystone

    local info = {
        hasKey = (inv ~= nil) or server.hasKey,
        level = (inv and inv.level) or server.level or 0,
        dungeonName = server.hasKey and server.dungeonName or nil,
        dungeonAbbrev = server.hasKey and server.dungeonAbbrev or "",
        depleted = server.hasKey and server.depleted,
        itemLink = inv and inv.itemLink,
        weeklyBest = server.weeklyBest or 0,
        seasonBest = server.seasonBest or 0,
    }

    -- Server info describes a different key (e.g. just upgraded): don't mix them.
    if inv and server.hasKey and server.level ~= inv.level then
        info.dungeonName = nil
        info.dungeonAbbrev = ""
        info.depleted = false
    end
    return info
end

function KeystonePlugin:OnActivate()
    if self._bagFrame then
        return
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("BAG_UPDATE")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- BAG_UPDATE fires in bursts; debounce to one scan per burst.
    local scanQueued = false
    frame:SetScript("OnEvent", function()
        if scanQueued then return end
        scanQueued = true
        DCInfoBar:After(0.3, function()
            scanQueued = false
            local before = KeystonePlugin._inventoryKeystone and KeystonePlugin._inventoryKeystone.level
            local after = KeystonePlugin:ScanInventoryForKeystone()
            local afterLevel = after and after.level
            KeystonePlugin._elapsed = 999
            -- The key changed (new, upgraded, used): refresh dungeon/best from the server.
            if before ~= afterLevel then
                local proto = DCInfoBar:GetProtocol()
                if proto and DCInfoBar.serverData.keystone.received then
                    proto:Request("MPLUS", MPLUS_CMSG_GET_KEY_INFO, {})
                end
            end
        end)
    end)
    self._bagFrame = frame

    self:ScanInventoryForKeystone()
end

function KeystonePlugin:OnDeactivate()
    if self._bagFrame then
        self._bagFrame:UnregisterAllEvents()
        self._bagFrame = nil
    end
end

function KeystonePlugin:OnUpdate(elapsed)
    local info = self:GetKeyInfo()
    if not info.hasKey or info.level <= 0 then
        return "", "No Key"
    end

    local text = "+" .. info.level
    if info.dungeonAbbrev ~= "" then
        text = text .. " " .. info.dungeonAbbrev
    end
    if info.depleted and DCInfoBar:GetPluginSetting(self.id, "showDepleted") ~= false then
        text = text .. " |cffff5050(D)|r"
    end
    return "", text
end

function KeystonePlugin:OnServerData(data)
    self._elapsed = 999
end

function KeystonePlugin:OnTooltip(tooltip)
    local info = self:GetKeyInfo()

    tooltip:AddLine("Mythic+ Keystone", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)

    if info.hasKey and info.level > 0 then
        tooltip:AddDoubleLine("Current:", (info.dungeonName or "Keystone") .. " +" .. info.level,
            0.7, 0.7, 0.7, 1, 1, 1)
        if info.depleted then
            tooltip:AddLine("|cffff5050Keystone is depleted|r")
        end

        local names = DCInfoBar.serverData.affixes.names
        if names and #names > 0 then
            tooltip:AddLine(" ")
            tooltip:AddLine("|cff32c4ffAffixes:|r")
            for _, name in ipairs(names) do
                tooltip:AddLine("  - " .. name, 1, 1, 1)
            end
        end
    else
        tooltip:AddLine("No keystone found", 0.7, 0.7, 0.7)
        tooltip:AddLine(" ")
        tooltip:AddLine("Complete a Mythic+ dungeon to receive a keystone.", 0.5, 0.5, 0.5, true)
    end

    if info.weeklyBest > 0 or info.seasonBest > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff32c4ffBest Runs:|r")
        tooltip:AddDoubleLine("  Weekly Best:", info.weeklyBest > 0 and ("+" .. info.weeklyBest) or "-",
            0.7, 0.7, 0.7, 0.5, 1, 0.5)
        tooltip:AddDoubleLine("  Season Best:", info.seasonBest > 0 and ("+" .. info.seasonBest) or "-",
            0.7, 0.7, 0.7, 1, 0.82, 0)
    end
end

function KeystonePlugin:OnClick(button)
    if button == "LeftButton" then
        local hud = rawget(_G, "DCMythicPlusHUD")
        if hud and hud.GroupFinder and hud.GroupFinder.Toggle then
            hud.GroupFinder:Toggle()
        elseif ToggleLFDParentFrame then
            ToggleLFDParentFrame()
        else
            DCInfoBar:Print("Group Finder not available")
        end
    elseif button == "RightButton" then
        local info = self:GetKeyInfo()
        if not info.hasKey or info.level <= 0 then
            return
        end
        local text = info.itemLink or string.format("[Keystone: %s +%d]", info.dungeonName or "Unknown", info.level)
        -- Insert into the open edit box (or open one) without wiping typed text.
        if not ChatEdit_InsertLink(text) then
            ChatFrame_OpenChat(text)
        end
    end
end

function KeystonePlugin:OnCreateOptions(parent, yOffset)
    DCInfoBar:CreateCheckbox(parent, "Show depleted indicator", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showDepleted", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "showDepleted") ~= false)

    return yOffset - 30
end

DCInfoBar:RegisterPlugin(KeystonePlugin)
