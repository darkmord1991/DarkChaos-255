FrameUtil = {};

function FrameUtil.RegisterFrameForEvents(frame, events)
	for i, event in ipairs(events) do
		frame:RegisterEvent(event);
	end
end

function FrameUtil.UnregisterFrameForEvents(frame, events)
	for i, event in ipairs(events) do
		frame:UnregisterEvent(event);
	end
end

function FrameUtil.RegisterFrameForCustomEvents(frame, events)
	for i, event in ipairs(events) do
		frame:RegisterCustomEvent(event);
	end
end

function FrameUtil.UnregisterFrameForCustomEvents(frame, events)
	for i, event in ipairs(events) do
		frame:UnregisterCustomEvent(event);
	end
end

function DoesAncestryInclude(ancestry, frame)
	if ancestry then
		local currentFrame = frame;
		while currentFrame do
			if currentFrame == ancestry then
				return true;
			end
			currentFrame = currentFrame:GetParent();
		end
	end
	return false;
end

function GetUnscaledFrameRect(frame, scale)
	local frameLeft, frameBottom, frameWidth, frameHeight = frame:GetScaledRect();
	if frameLeft == nil then
		return 1, 1, 1, 1;
	end

	return frameLeft / scale, frameBottom / scale, frameWidth / scale, frameHeight / scale;
end

function ApplyDefaultScale(frame, minScale, maxScale)
	local scale = GetDefaultScale();

	if minScale then
		scale = math.max(scale, minScale);
	end

	if maxScale then
		scale = math.min(scale, maxScale);
	end

	frame:SetScale(scale);
end

function UpdateScaleForFit(frame)
	local horizRatio = UIParent:GetWidth() / GetUIPanelWidth(frame);
	local vertRatio = UIParent:GetHeight() / GetUIPanelHeight(frame);

	if ( horizRatio < 1 or vertRatio < 1 ) then
		frame:SetScale(min(horizRatio, vertRatio));
	else
		frame:SetScale(1);
	end
end 