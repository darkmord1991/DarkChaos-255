--[[
    DC-InfoBar Affixes Plugin
    Shows current weekly Mythic+ affixes
    
    Data Source: DCAddonProtocol or DCMythicPlusHUD
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local AffixesPlugin = {
    id = "DCInfoBar_Affixes",
    name = "Weekly Affixes",
    category = "server",
    type = "text",
    side = "left",
    priority = 30,
    icon = "Interface\\Icons\\Spell_Nature_WispSplode",
    updateInterval = 30.0,  -- Affixes don't change often
    
    leftClickHint = "Show affix details",
    rightClickHint = "Link affixes in chat",
}

function AffixesPlugin:OnUpdate(elapsed)
    local affixData = DCInfoBar.serverData.affixes

    local names = affixData.names or {}
    if (#names == 0) and affixData.ids and #affixData.ids > 0 then
        names = {}
        for _, id in ipairs(affixData.ids) do
            local name = nil
            if id and id > 0 and type(GetSpellInfo) == "function" then
                name = GetSpellInfo(id)
            end
            names[#names + 1] = name or tostring(id or "Unknown")
        end
    end

    if #names > 0 then
        local textMode = DCInfoBar:GetPluginSetting(self.id, "textMode")
        
        if textMode then
            -- Abbreviated text: "Fort/Burst/Storm"
            local abbrevs = {}
            for i, name in ipairs(names) do
                -- Get first 4-5 chars as abbreviation
                local abbrev = string.sub(name, 1, 4)
                if #name > 5 then
                    abbrev = string.sub(name, 1, 4)
                end
                table.insert(abbrevs, abbrev)
            end
            return "", table.concat(abbrevs, "/")
        else
            -- Full names separated
            return "", table.concat(names, ", ")
        end
    else
        return "", "No Affixes"
    end
end

function AffixesPlugin:OnTooltip(tooltip)
    local affixData = DCInfoBar.serverData.affixes
    
    tooltip:AddLine("Weekly Affixes", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)

    local names = affixData.names or {}
    if (#names == 0) and affixData.ids and #affixData.ids > 0 then
        names = {}
        for _, id in ipairs(affixData.ids) do
            local name = nil
            if id and id > 0 and type(GetSpellInfo) == "function" then
                name = GetSpellInfo(id)
            end
            names[#names + 1] = name or tostring(id or "Unknown")
        end
    end

    if #names > 0 then
        for i, name in ipairs(names) do
            tooltip:AddLine(" ")
            tooltip:AddLine("|cff32c4ff" .. name .. "|r")
            
            if affixData.descriptions and affixData.descriptions[i] then
                -- Word wrap description
                local desc = affixData.descriptions[i]
                local wrapped = DCInfoBar:WrapText(desc, 40)
                for _, line in ipairs(wrapped) do
                    tooltip:AddLine("  " .. line, 0.7, 0.7, 0.7)
                end
            end
        end
        
        -- Reset timer
        if affixData.resetIn and affixData.resetIn > 0 then
            tooltip:AddLine(" ")
            tooltip:AddDoubleLine("Resets in:", DCInfoBar:FormatTimeShort(affixData.resetIn),
                0.5, 0.5, 0.5, 0.5, 1, 0.5)
        end
    else
        tooltip:AddLine("No affix data available", 0.7, 0.7, 0.7)
        tooltip:AddLine(" ")
        tooltip:AddLine("Affix data will be received from", 0.5, 0.5, 0.5)
        tooltip:AddLine("the server when available.", 0.5, 0.5, 0.5)
    end
end

function AffixesPlugin:OnClick(button)
    if button == "LeftButton" then
        -- Show detailed affix popup
        local names = DCInfoBar.serverData.affixes.names or {}
        if (#names == 0) and DCInfoBar.serverData.affixes.ids and #DCInfoBar.serverData.affixes.ids > 0 then
            names = {}
            for _, id in ipairs(DCInfoBar.serverData.affixes.ids) do
                local name = nil
                if id and id > 0 and type(GetSpellInfo) == "function" then
                    name = GetSpellInfo(id)
                end
                names[#names + 1] = name or tostring(id or "Unknown")
            end
        end
        DCInfoBar:Print("Affixes: " .. table.concat(names, ", "))
    elseif button == "RightButton" then
        -- Link in chat
        local affixData = DCInfoBar.serverData.affixes
        local names = affixData.names or {}
        if (#names == 0) and affixData.ids and #affixData.ids > 0 then
            names = {}
            for _, id in ipairs(affixData.ids) do
                local name = nil
                if id and id > 0 and type(GetSpellInfo) == "function" then
                    name = GetSpellInfo(id)
                end
                names[#names + 1] = name or tostring(id or "Unknown")
            end
        end
        if #names > 0 then
            local msg = "[This Week's Affixes: " .. table.concat(names, ", ") .. "]"
            ChatFrame1EditBox:SetText(msg)
            ChatFrame1EditBox:SetFocus()
        end
    end
end

function AffixesPlugin:OnCreateOptions(parent, yOffset)
    local textModeCB = DCInfoBar:CreateCheckbox(parent, "Use abbreviated text (Fort/Burst/Storm)", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "textMode", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "textMode"))
    
    return yOffset - 30
end

-- Text wrapping helper
function DCInfoBar:WrapText(text, maxLen)
    if not text then return {} end
    
    local lines = {}
    local currentLine = ""
    
    for word in string.gmatch(text, "%S+") do
        if #currentLine + #word + 1 <= maxLen then
            if currentLine == "" then
                currentLine = word
            else
                currentLine = currentLine .. " " .. word
            end
        else
            if currentLine ~= "" then
                table.insert(lines, currentLine)
            end
            currentLine = word
        end
    end
    
    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end
    
    return lines
end

-- Register plugin
DCInfoBar:RegisterPlugin(AffixesPlugin)
