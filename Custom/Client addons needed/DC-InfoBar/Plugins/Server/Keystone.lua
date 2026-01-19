--[[
    DC-InfoBar Keystone Plugin
    Shows current Mythic+ keystone level and dungeon
    
    Data Source: 
    1. Player inventory scan for keystone items
    2. DCAddonProtocol GRPF or MPLUS module (for additional data)
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

-- Keystone item IDs (custom DC keystone items)
-- Keystone item IDs: prefer central DC.KEYSTONE_ITEM_IDS, fallback to plugin-local mapping
local DCproto = rawget(_G, "DCAddonProtocol")
local DCCentral = rawget(_G, "DCCentral")
local KEYSTONE_ITEM_IDS = (DCCentral and DCCentral.KEYSTONE_ITEM_IDS) or (DCproto and DCproto.KEYSTONE_ITEM_IDS) or {
    [60000] = true,
    [60001] = true,
    [60002] = true,
}

-- Use centralized dungeon abbreviations from Core.lua (single source of truth)
local DUNGEON_ABBREVS = DCInfoBar.DUNGEON_ABBREVS or {}

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
    
    _inventoryKeystone = nil,  -- Cached keystone from inventory
}

-- Scan inventory for keystone items
function KeystonePlugin:ScanInventoryForKeystone()
    -- Check all bag slots for keystone items
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemId = GetContainerItemID(bag, slot)
            if itemId then
                -- Fast path: check known keystone item IDs
                if KEYSTONE_ITEM_IDS[itemId] then
                    local itemName, itemLink = GetItemInfo(itemId)
                    -- Extract level and dungeon and continue below
                    local level = string.match(itemName, "%+(%d+)") or string.match(itemName, "Level (%d+)")
                    local dungeonName = string.match(itemName, ":%s*(.+)%s*%+") or string.match(itemName, "Keystone:%s*(.+)")
                    -- Also check item tooltip for additional info
                    local tooltipData = self:GetItemTooltipData(bag, slot)
                    if tooltipData then
                        level = level or tooltipData.level
                        dungeonName = dungeonName or tooltipData.dungeon
                    end
                    if level then
                        self._inventoryKeystone = {
                            hasKey = true,
                            level = tonumber(level) or 0,
                            dungeonName = dungeonName or "Unknown",
                            dungeonAbbrev = DUNGEON_ABBREVS[dungeonName] or self:GenerateAbbrev(dungeonName),
                            itemLink = itemLink,
                            bag = bag,
                            slot = slot,
                        }
                        return self._inventoryKeystone
                    end
                else
                    -- Check item name for "Keystone" text
                    local itemName, itemLink = GetItemInfo(itemId)
                    if itemName and string.find(itemName, "Keystone") then
                    -- Parse keystone level from item name or tooltip
                    local level = string.match(itemName, "%+(%d+)") or string.match(itemName, "Level (%d+)")
                    local dungeonName = string.match(itemName, ":%s*(.+)%s*%+") or string.match(itemName, "Keystone:%s*(.+)")
                    
                    -- Also check item tooltip for additional info
                    local tooltipData = self:GetItemTooltipData(bag, slot)
                    if tooltipData then
                        level = level or tooltipData.level
                        dungeonName = dungeonName or tooltipData.dungeon
                    end
                    
                    if level then
                        self._inventoryKeystone = {
                            hasKey = true,
                            level = tonumber(level) or 0,
                            dungeonName = dungeonName or "Unknown",
                            dungeonAbbrev = DUNGEON_ABBREVS[dungeonName] or self:GenerateAbbrev(dungeonName),
                            itemLink = itemLink,
                            bag = bag,
                            slot = slot,
                        }
                        return self._inventoryKeystone
                    end
                    end
                end
            end
        end
    end
    
    self._inventoryKeystone = nil
    return nil
end

function KeystonePlugin:GetItemTooltipData(bag, slot)
    -- Prefer shared scan tooltip provided by DC or DCCentral
    local tooltip
    if DCproto and type(DCproto.GetScanTooltip) == 'function' then
        tooltip = DCproto:GetScanTooltip()
    elseif DCCentral and DCCentral.scanTooltip then
        tooltip = DCCentral.scanTooltip
    else
        tooltip = _G["DCInfoBarKeystoneScanTooltip"]
        if not tooltip then
            tooltip = CreateFrame("GameTooltip", "DCInfoBarKeystoneScanTooltip", nil, "GameTooltipTemplate")
            tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
        end
    end
    
    tooltip:ClearLines()
    tooltip:SetBagItem(bag, slot)
    
    -- Get the tooltip's actual name for looking up text regions
    local tooltipName = tooltip:GetName() or "DCInfoBarKeystoneScanTooltip"
    
    local level, dungeon
    for i = 1, tooltip:NumLines() do
        local line = _G[tooltipName .. "TextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                -- Look for level pattern
                local lvl = string.match(text, "Level:?%s*(%d+)") or string.match(text, "%+(%d+)")
                if lvl then level = tonumber(lvl) end
                
                -- Look for dungeon pattern
                local dng = string.match(text, "Dungeon:?%s*(.+)") or string.match(text, "Instance:?%s*(.+)")
                if dng then dungeon = dng end
            end
        end
    end
    
    if level then
        return { level = level, dungeon = dungeon }
    end
    return nil
end

function KeystonePlugin:GenerateAbbrev(name)
    if not name or name == "" then return "" end
    local abbrev = ""
    for word in string.gmatch(name, "%S+") do
        if word ~= "The" and word ~= "of" and word ~= "the" then
            abbrev = abbrev .. string.sub(word, 1, 1)
        end
    end
    return string.upper(abbrev)
end

function KeystonePlugin:OnActivate()
    -- Register for bag updates
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("BAG_UPDATE")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function()
        self:ScanInventoryForKeystone()
        self._elapsed = 999  -- Force update
    end)
    
    -- Initial scan
    self:ScanInventoryForKeystone()
    
    -- Also request from server for additional data (weekly/season best)
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        if DC.GroupFinderOpcodes then
            DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_MY_KEYSTONE, {})
        end
        if DC.Opcode and DC.Opcode.MPlus then
            DC:Request("MPLUS", DC.Opcode.MPlus.CMSG_GET_KEY_INFO, {})
        end
    end
end

function KeystonePlugin:OnUpdate(elapsed)
    -- First check inventory keystone
    local invKey = self._inventoryKeystone
    
    -- Then check server data
    local keyData = DCInfoBar.serverData.keystone
    
    -- Prefer inventory data if available, fall back to server data
    local hasKey = (invKey and invKey.hasKey) or (keyData and keyData.hasKey)
    local level = (invKey and invKey.level) or (keyData and keyData.level) or 0
    local abbrev = (invKey and invKey.dungeonAbbrev) or (keyData and keyData.dungeonAbbrev) or ""
    local depleted = keyData and keyData.depleted
    
    if hasKey and level > 0 then
        local text = "+" .. level
        if abbrev and abbrev ~= "" then
            text = text .. " " .. abbrev
        end
        
        -- Add depleted indicator
        local showDepleted = DCInfoBar:GetPluginSetting(self.id, "showDepleted")
        if showDepleted ~= false and depleted then
            text = text .. " |cffff5050⚠|r"
        end
        
        return "", text
    else
        return "", "No Key"
    end
end

function KeystonePlugin:OnServerData(data)
    self._elapsed = 999  -- Force immediate update
end

function KeystonePlugin:OnTooltip(tooltip)
    -- Get data from both sources
    local invKey = self._inventoryKeystone
    local keyData = DCInfoBar.serverData.keystone
    
    local hasKey = (invKey and invKey.hasKey) or (keyData and keyData.hasKey)
    local level = (invKey and invKey.level) or (keyData and keyData.level) or 0
    local dungeonName = (invKey and invKey.dungeonName) or (keyData and keyData.dungeonName) or "Unknown"
    local depleted = keyData and keyData.depleted
    
    tooltip:AddLine("Mythic+ Keystone", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)
    
    if hasKey and level > 0 then
        tooltip:AddDoubleLine("Current:", dungeonName .. " +" .. level,
            0.7, 0.7, 0.7, 1, 1, 1)
        
        if depleted then
            tooltip:AddLine("|cffff5050Keystone is depleted|r")
        end
        
        -- Affixes
        local affixData = DCInfoBar.serverData.affixes
        if affixData and affixData.names and #affixData.names > 0 then
            tooltip:AddLine(" ")
            tooltip:AddLine("|cff32c4ffAffixes:|r")
            for i, name in ipairs(affixData.names) do
                tooltip:AddLine("  • " .. name, 1, 1, 1)
            end
        end
        
        -- Best runs (from server data)
        if keyData and (keyData.weeklyBest > 0 or keyData.seasonBest > 0) then
            tooltip:AddLine(" ")
            tooltip:AddLine("|cff32c4ffBest Runs:|r")
            tooltip:AddDoubleLine("  Weekly Best:", "+" .. (keyData.weeklyBest or 0),
                0.7, 0.7, 0.7, 0.5, 1, 0.5)
            tooltip:AddDoubleLine("  Season Best:", "+" .. (keyData.seasonBest or 0),
                0.7, 0.7, 0.7, 1, 0.82, 0)
        end
    else
        tooltip:AddLine("No keystone found", 0.7, 0.7, 0.7)
        tooltip:AddLine(" ")
        tooltip:AddLine("Complete a Mythic+ dungeon to", 0.5, 0.5, 0.5)
        tooltip:AddLine("receive a keystone.", 0.5, 0.5, 0.5)
    end
end

function KeystonePlugin:OnClick(button)
    if button == "LeftButton" then
        -- Open DC-MythicPlus Group Finder
        if DCMythicPlusHUD and DCMythicPlusHUD.GroupFinder and DCMythicPlusHUD.GroupFinder.Toggle then
            DCMythicPlusHUD.GroupFinder:Toggle()
        elseif DCGroupFinder and DCGroupFinder.Toggle then
            DCGroupFinder:Toggle()
        elseif LFDParentFrame then
            -- Fallback to default LFD frame
            ToggleLFDParentFrame()
        else
            DCInfoBar:Print("Group Finder not available")
        end
    elseif button == "RightButton" then
        -- Link keystone in chat
        local invKey = self._inventoryKeystone
        local keyData = DCInfoBar.serverData.keystone
        
        local hasKey = (invKey and invKey.hasKey) or (keyData and keyData.hasKey)
        local level = (invKey and invKey.level) or (keyData and keyData.level) or 0
        local dungeonName = (invKey and invKey.dungeonName) or (keyData and keyData.dungeonName) or "Unknown"
        
        if hasKey and level > 0 then
            -- If we have an item link, use it
            if invKey and invKey.itemLink then
                ChatFrame1EditBox:SetText(invKey.itemLink)
            else
                local msg = string.format("[Keystone: %s +%d]", dungeonName, level)
                ChatFrame1EditBox:SetText(msg)
            end
            ChatFrame1EditBox:SetFocus()
        end
    end
end

function KeystonePlugin:OnCreateOptions(parent, yOffset)
    local depletedCB = DCInfoBar:CreateCheckbox(parent, "Show depleted indicator", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "showDepleted", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "showDepleted") ~= false)
    
    return yOffset - 30
end

-- Register plugin
DCInfoBar:RegisterPlugin(KeystonePlugin)
