--[[
    DC-InfoBar Affixes Plugin
    Shows current weekly Mythic+ affixes

    Data Source: MPLUS SMSG_AFFIXES (Core.lua HandleAffixData). Names,
    descriptions and icons are completed from the WotLK-Extensions affix DBC
    (GetDCMythicPlusAffixes) when the server omits them.
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
    updateInterval = 30.0,  -- Affixes don't change often; OnServerData forces redraws

    leftClickHint = "Print affix details",
    rightClickHint = "Link affixes in chat",
}

local function GetNames()
    return DCInfoBar.serverData.affixes.names or {}
end

function AffixesPlugin:OnUpdate(elapsed)
    local names = GetNames()
    if #names == 0 then
        return "", "No Affixes"
    end

    if DCInfoBar:GetPluginSetting(self.id, "textMode") then
        local abbrevs = {}
        for i, name in ipairs(names) do
            abbrevs[i] = string.sub(name, 1, 4)
        end
        return "", table.concat(abbrevs, "/")
    end
    return "", table.concat(names, ", ")
end

function AffixesPlugin:OnServerData(data)
    self._elapsed = 999
end

function AffixesPlugin:OnTooltip(tooltip)
    local affixes = DCInfoBar.serverData.affixes
    local names = GetNames()

    tooltip:AddLine("Weekly Affixes", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)

    if #names == 0 then
        tooltip:AddLine("No affix data available", 0.7, 0.7, 0.7)
        return
    end

    for i, name in ipairs(names) do
        tooltip:AddLine(" ")
        local icon = affixes.icons and affixes.icons[i]
        local iconText = icon and ("|T" .. icon .. ":14|t ") or ""
        tooltip:AddLine(iconText .. "|cff32c4ff" .. name .. "|r")

        local desc = affixes.descriptions and affixes.descriptions[i]
        if desc then
            tooltip:AddLine(desc, 0.7, 0.7, 0.7, true)
        end
    end

    if (affixes.resetIn or 0) > 0 then
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("Resets in:", DCInfoBar:FormatTimeShort(affixes.resetIn),
            0.5, 0.5, 0.5, 0.5, 1, 0.5)
    end
end

function AffixesPlugin:OnClick(button)
    local names = GetNames()
    if #names == 0 then
        return
    end

    if button == "LeftButton" then
        local affixes = DCInfoBar.serverData.affixes
        DCInfoBar:Print("This week's affixes:")
        for i, name in ipairs(names) do
            local desc = affixes.descriptions and affixes.descriptions[i]
            DCInfoBar:Print("  " .. name .. (desc and (" - " .. desc) or ""))
        end
    elseif button == "RightButton" then
        local text = "[This Week's Affixes: " .. table.concat(names, ", ") .. "]"
        if not ChatEdit_InsertLink(text) then
            ChatFrame_OpenChat(text)
        end
    end
end

function AffixesPlugin:OnCreateOptions(parent, yOffset)
    DCInfoBar:CreateCheckbox(parent, "Use abbreviated text (Fort/Burs/Stor)", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "textMode", checked)
        self._elapsed = 999
    end, DCInfoBar:GetPluginSetting(self.id, "textMode"))

    return yOffset - 30
end

DCInfoBar:RegisterPlugin(AffixesPlugin)
