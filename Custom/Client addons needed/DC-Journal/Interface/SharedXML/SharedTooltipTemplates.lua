function GameTooltip_AddBlankLinesToTooltip(tooltip, numLines)
	if numLines ~= nil then
		for i = 1, numLines do
			tooltip:AddLine(" ");
		end
	end
end

function GameTooltip_AddBlankLineToTooltip(tooltip)
	GameTooltip_AddBlankLinesToTooltip(tooltip, 1);
end

function GameTooltip_SetTitle(tooltip, text, overrideColor, wrap)
	local titleColor = overrideColor or HIGHLIGHT_FONT_COLOR;
	local r, g, b, a = titleColor:GetRGBA();
	if wrap == nil then
		wrap = 1;
	end
	tooltip:SetText(text, r, g, b, a, wrap);
end

function GameTooltip_AddNormalLine(tooltip, text, wrap, leftOffset)
	GameTooltip_AddColoredLine(tooltip, text, NORMAL_FONT_COLOR, wrap, leftOffset);
end

function GameTooltip_AddHighlightLine(tooltip, text, wrap, leftOffset)
	GameTooltip_AddColoredLine(tooltip, text, HIGHLIGHT_FONT_COLOR, wrap, leftOffset);
end

function GameTooltip_AddInstructionLine(tooltip, text, wrap, leftOffset)
	GameTooltip_AddColoredLine(tooltip, text, GREEN_FONT_COLOR, wrap, leftOffset);
end

function GameTooltip_AddErrorLine(tooltip, text, wrap, leftOffset)
	GameTooltip_AddColoredLine(tooltip, text, RED_FONT_COLOR, wrap, leftOffset);
end

function GameTooltip_AddDisabledLine(tooltip, text, wrap, leftOffset)
	GameTooltip_AddColoredLine(tooltip, text, DISABLED_FONT_COLOR, wrap, leftOffset);
end

function GameTooltip_AddColoredLine(tooltip, text, color, wrap, leftOffset)
	local r, g, b = color:GetRGB();
	if wrap == nil then
		wrap = 1;
	end
	tooltip:AddLine(text, r, g, b, wrap, leftOffset);
end

function GameTooltip_AddColoredDoubleLine(tooltip, leftText, rightText, leftColor, rightColor, wrap)
	local leftR, leftG, leftB = leftColor:GetRGB();
	local rightR, rightG, rightB = rightColor:GetRGB();
	if wrap == nil then
		wrap = 1;
	end
	tooltip:AddDoubleLine(leftText, rightText, leftR, leftG, leftB, rightR, rightG, rightB, wrap);
end