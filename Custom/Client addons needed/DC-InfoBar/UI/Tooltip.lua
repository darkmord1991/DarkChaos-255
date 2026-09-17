--[[
    DC-InfoBar Tooltip
    Enhanced tooltip functionality
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}
_G.DCInfoBar = DCInfoBar

-- Extended tooltip with better formatting
function DCInfoBar:CreateTooltipLine(text, r, g, b)
    return { text = text, r = r or 1, g = g or 1, b = b or 1 }
end

function DCInfoBar:AddTooltipHeader(tooltip, text)
    tooltip:AddLine(text, 1, 0.82, 0)  -- Gold color for headers
end

function DCInfoBar:AddTooltipSeparator(tooltip)
    -- Use simple dashes that render properly in all WoW fonts
    tooltip:AddLine("------------------------", 0.3, 0.3, 0.3)
end

function DCInfoBar:AddTooltipDoubleLine(tooltip, left, right, lr, lg, lb, rr, rg, rb)
    tooltip:AddDoubleLine(left, right, lr or 1, lg or 1, lb or 1, rr or 1, rg or 1, rb or 1)
end

function DCInfoBar:AddTooltipProgressBar(tooltip, current, max, label)
    current = tonumber(current) or 0
    max = tonumber(max) or 0
    if max <= 0 then
        tooltip:AddDoubleLine(label or "", tostring(current), 1, 1, 1, 0.8, 0.8, 0.8)
        return
    end

    local ratio = math.max(0, math.min(1, current / max))
    local barWidth = 20
    local filled = math.floor(ratio * barWidth)
    -- '|' starts an escape sequence in WoW strings; use '=' for the fill.
    local bar = "|cff50ff7a" .. string.rep("=", filled) .. "|r|cff555555" .. string.rep("-", barWidth - filled) .. "|r"

    tooltip:AddDoubleLine(
        label or "",
        string.format("%s %d/%d (%d%%)", bar, current, max, math.floor(ratio * 100)),
        1, 1, 1,
        0.8, 0.8, 0.8
    )
end
