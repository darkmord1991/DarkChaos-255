--[[
    DC-InfoBar Keystone Plugin
    Shows current Mythic+ keystone level and dungeon
    
    Data Source: DCAddonProtocol GRPF or MPLUS module
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local KeystonePlugin = {
    id = "DCInfoBar_Keystone",
    name = "Keystone",
    category = "server",
    type = "combo",
    side = "left",
    priority = 20,
    icon = "Interface\\Icons\\INV_Relics_IdolofHealth",
    updateInterval = 10.0,
    
    leftClickHint = "Open Group Finder",
    rightClickHint = "Link keystone in chat",
}

function KeystonePlugin:OnActivate()
    local DC = rawget(_G, "DCAddonProtocol")
    if DC then
        -- Try both Group Finder and MythicPlus modules for keystone info
        if DC.GroupFinderOpcodes then
            DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_MY_KEYSTONE, {})
        end
        if DC.Opcode and DC.Opcode.MPlus then
            DC:Request("MPLUS", DC.Opcode.MPlus.CMSG_GET_KEY_INFO, {})
        end
    end
end

function KeystonePlugin:OnUpdate(elapsed)
    local keyData = DCInfoBar.serverData.keystone
    
    if keyData.hasKey and keyData.level > 0 then
        local text = "+" .. keyData.level .. " " .. keyData.dungeonAbbrev
        
        -- Add depleted indicator
        local showDepleted = DCInfoBar:GetPluginSetting(self.id, "showDepleted")
        if showDepleted ~= false and keyData.depleted then
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
    local keyData = DCInfoBar.serverData.keystone
    
    tooltip:AddLine("Mythic+ Keystone", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)
    
    if keyData.hasKey then
        tooltip:AddDoubleLine("Current:", keyData.dungeonName .. " +" .. keyData.level,
            0.7, 0.7, 0.7, 1, 1, 1)
        
        if keyData.depleted then
            tooltip:AddLine("|cffff5050Keystone is depleted|r")
        end
        
        -- Affixes
        local affixData = DCInfoBar.serverData.affixes
        if affixData.names and #affixData.names > 0 then
            tooltip:AddLine(" ")
            tooltip:AddLine("|cff32c4ffAffixes:|r")
            for i, name in ipairs(affixData.names) do
                tooltip:AddLine("  • " .. name, 1, 1, 1)
            end
        end
        
        -- Best runs
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff32c4ffBest Runs:|r")
        tooltip:AddDoubleLine("  Weekly Best:", "+" .. keyData.weeklyBest,
            0.7, 0.7, 0.7, 0.5, 1, 0.5)
        tooltip:AddDoubleLine("  Season Best:", "+" .. keyData.seasonBest,
            0.7, 0.7, 0.7, 1, 0.82, 0)
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
        else
            DCInfoBar:Print("Group Finder not available - DC-MythicPlus addon required")
        end
    elseif button == "RightButton" then
        -- Link keystone in chat
        local keyData = DCInfoBar.serverData.keystone
        if keyData.hasKey then
            local msg = string.format("[Keystone: %s +%d]", keyData.dungeonName, keyData.level)
            ChatFrame1EditBox:SetText(msg)
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
