--[[
    DC-InfoBar Tooltip
    Enhanced tooltip functionality
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

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
    if not max or max == 0 then max = 1 end
    local percent = math.floor((current / max) * 100)
    local barWidth = 20
    local filled = math.floor((current / max) * barWidth)
    -- Use pipe characters instead of Unicode block characters
    local bar = string.rep("|", filled) .. string.rep(".", barWidth - filled)
    
    tooltip:AddDoubleLine(
        label or "",
        string.format("[%s] %d/%d (%d%%)", bar, current, max, percent),
        1, 1, 1,
        0.8, 0.8, 0.8
    )
end
