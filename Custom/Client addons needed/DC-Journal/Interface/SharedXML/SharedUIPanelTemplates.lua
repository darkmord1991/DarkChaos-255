--	Filename:	SharedUIPanelTemplates.lua
--	Project:	Sirus Game Interface
--	Author:		Nyll
--	E-mail:		nyll@sirus.su
--	Web:		https://sirus.su/

PANEL_INSET_LEFT_OFFSET = 4
PANEL_INSET_RIGHT_OFFSET = -6
PANEL_INSET_BOTTOM_OFFSET = 4
PANEL_INSET_BOTTOM_BUTTON_OFFSET = 26
PANEL_INSET_TOP_OFFSET = -24
PANEL_INSET_ATTIC_OFFSET = -60

-- ButtonFrameTemplate code
function ButtonFrameTemplate_HideButtonBar(self)
	if self.bottomInset then
		self.bottomInset:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_OFFSET)
	else
		_G[self:GetName() .. "Inset"]:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_OFFSET)
	end
	_G[self:GetName() .. "BtnCornerLeft"]:Hide()
	_G[self:GetName() .. "BtnCornerRight"]:Hide()
	_G[self:GetName() .. "ButtonBottomBorder"]:Hide()
end

function ButtonFrameTemplate_ShowButtonBar(self)
	if self.topInset then
		self.topInset:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_BUTTON_OFFSET)
	else
		_G[self:GetName() .. "Inset"]:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_BUTTON_OFFSET)
	end
	_G[self:GetName() .. "BtnCornerLeft"]:Show()
	_G[self:GetName() .. "BtnCornerRight"]:Show()
	_G[self:GetName() .. "ButtonBottomBorder"]:Show()
end

function ButtonFrameTemplate_HideAttic(self)
	if self.topInset then
		self.topInset:SetPoint("TOPLEFT", self, "TOPLEFT", PANEL_INSET_LEFT_OFFSET, PANEL_INSET_TOP_OFFSET)
	else
		self.Inset:SetPoint("TOPLEFT", self, "TOPLEFT", PANEL_INSET_LEFT_OFFSET, PANEL_INSET_TOP_OFFSET)
	end
	self.TopTileStreaks:Hide()
end

function ButtonFrameTemplate_ShowAttic(self)
	if self.topInset then
		self.topInset:SetPoint("TOPLEFT", self, "TOPLEFT", PANEL_INSET_LEFT_OFFSET, PANEL_INSET_ATTIC_OFFSET)
	else
		self.Inset:SetPoint("TOPLEFT", self, "TOPLEFT", PANEL_INSET_LEFT_OFFSET, PANEL_INSET_ATTIC_OFFSET)
	end
	self.TopTileStreaks:Show()
end


function ButtonFrameTemplate_HidePortrait(self)
	self.portrait:Hide()
	self.portraitFrame:Hide()
	self.topLeftCorner:Show()
	self.topBorderBar:SetPoint("TOPLEFT", self.topLeftCorner, "TOPRIGHT",  0, 0)
	self.leftBorderBar:SetPoint("TOPLEFT", self.topLeftCorner, "BOTTOMLEFT",  0, 0)

	self.TopTileStreaks:ClearAllPoints()
	self.TopTileStreaks:SetPoint("TOPLEFT", 0, -21)
	self.TopTileStreaks:SetPoint("TOPRIGHT", -2, -21)
end


function ButtonFrameTemplate_ShowPortrait(self)
	self.portrait:Show()
	self.portraitFrame:Show()
	self.topLeftCorner:Hide()
	self.topBorderBar:SetPoint("TOPLEFT", self.portraitFrame, "TOPRIGHT",  0, -10)
	self.leftBorderBar:SetPoint("TOPLEFT", self.portraitFrame, "BOTTOMLEFT",  8, 0)

	self.TopTileStreaks:ClearAllPoints()
	self.TopTileStreaks:SetPoint("TOPLEFT", 50, -21)
	self.TopTileStreaks:SetPoint("TOPRIGHT", -2, -21)
end

function ButtonFrameTemplateMinimizable_HidePortrait(self)
	local layout = AnchorUtil.GetNineSliceLayout("ButtonFrameTemplateNoPortraitMinimizable");
	AnchorUtil.ApplyNineSliceLayout(self.NineSlice, layout);
	PortraitFrameTemplate_SetPortraitShown(self, false);
end

function ButtonFrameTemplateMinimizable_ShowPortrait(self)
	local layout = AnchorUtil.GetNineSliceLayout("PortraitFrameTemplateMinimizable");
	AnchorUtil.ApplyNineSliceLayout(self.NineSlice, layout);
	PortraitFrameTemplate_SetPortraitShown(self, true);
end

function PortraitFrameTemplate_SetBorder(self, layoutName)
	local layout = AnchorUtil.GetNineSliceLayout(layoutName);
	AnchorUtil.ApplyNineSliceLayout(self.NineSlice, layout);
end

function PortraitFrameTemplate_SetPortraitToAsset(self, texture)
	SetPortraitToTexture(self.portrait, texture);
end

function PortraitFrameTemplate_SetPortraitToUnit(self, unit)
	SetPortraitTexture(self.portrait, unit);
end

function PortraitFrameTemplate_SetPortraitTextureRaw(self, texture)
	self.portrait:SetTexture(texture);
end

function PortraitFrameTemplate_SetPortraitAtlasRaw(self, atlas, ...)
	self.portrait:SetAtlas(atlas, ...);
end

function PortraitFrameTemplate_SetPortraitTexCoord(self, ...)
	self.portrait:SetTexCoord(...);
end

function PortraitFrameTemplate_SetPortraitShown(self, shown)
	self.portrait:SetShown(shown);
end

function PortraitFrameTemplate_SetTitleColor(self, color)
	self.TitleText:SetTextColor(color:GetRGBA());
end

function PortraitFrameTemplate_SetTitle(self, title)
	self.TitleText:SetText(title);
end

function PortraitFrameTemplate_SetTitleFormatted(self, fmt, ...)
	self.TitleText:SetFormattedText(fmt, ...);
end

function PortraitFrameTemplate_SetTitleMaxLinesAndHeight(self, maxLines, height)
	self.TitleText:SetMaxLines(maxLines);
	self.TitleText:SetHeight(height);
end


-- Magic Button code
function MagicButton_OnLoad(self)
	local leftHandled = false
	local rightHandled = false

	-- Find out where this button is anchored and adjust positions/separators as necessary
	for i=1, self:GetNumPoints() do
		local point, relativeTo, relativePoint, offsetX, offsetY = self:GetPoint(i)

		if (relativeTo:GetObjectType() == "Button" and (point == "TOPLEFT" or point == "LEFT")) then

			if (offsetX == 0 and offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, 1, 0)
			end

			if (relativeTo.RightSeparator) then
				-- Modify separator to make it a Middle
				self.LeftSeparator = relativeTo.RightSeparator
			else
				-- Add a Middle separator
				self.LeftSeparator = self:CreateTexture(self:GetName() and self:GetName().."_LeftSeparator" or nil, "BORDER")
				relativeTo.RightSeparator = self.LeftSeparator
			end

			self.LeftSeparator:SetTexture("Interface\\FrameGeneral\\UI-Frame")
			self.LeftSeparator:SetTexCoord(0.00781250, 0.10937500, 0.75781250, 0.95312500)
			self.LeftSeparator:SetWidth(13)
			self.LeftSeparator:SetHeight(25)
			self.LeftSeparator:SetPoint("TOPRIGHT", self, "TOPLEFT", 5, 1)

			leftHandled = true

		elseif (relativeTo:GetObjectType() == "Button" and (point == "TOPRIGHT" or point == "RIGHT")) then

			if (offsetX == 0 and offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, -1, 0)
			end

			if (relativeTo.LeftSeparator) then
				-- Modify separator to make it a Middle
				self.RightSeparator = relativeTo.LeftSeparator
			else
				-- Add a Middle separator
				self.RightSeparator = self:CreateTexture(self:GetName() and self:GetName().."_RightSeparator" or nil, "BORDER")
				relativeTo.LeftSeparator = self.RightSeparator
			end

			self.RightSeparator:SetTexture("Interface\\FrameGeneral\\UI-Frame")
			self.RightSeparator:SetTexCoord(0.00781250, 0.10937500, 0.75781250, 0.95312500)
			self.RightSeparator:SetWidth(13)
			self.RightSeparator:SetHeight(25)
			self.RightSeparator:SetPoint("TOPLEFT", self, "TOPRIGHT", -5, 1)

			rightHandled = true

		elseif (point == "BOTTOMLEFT") then
			if (offsetX == 0 and offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, 4, 4)
			end
			leftHandled = true
		elseif (point == "BOTTOMRIGHT") then
			if (offsetX == 0 and offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, -6, 4)
			end
			rightHandled = true
		elseif (point == "BOTTOM") then
			if (offsetY == 0) then
				self:SetPoint(point, relativeTo, relativePoint, 0, 4)
			end
		end
	end

	-- If this button didn't have a left anchor, add the left border texture
	if (not leftHandled) then
		if (not self.LeftSeparator) then
			-- Add a Left border
			self.LeftSeparator = self:CreateTexture(self:GetName() and self:GetName().."_LeftSeparator" or nil, "BORDER")
			self.LeftSeparator:SetTexture("Interface\\FrameGeneral\\UI-Frame")
			self.LeftSeparator:SetTexCoord(0.24218750, 0.32812500, 0.63281250, 0.82812500)
			self.LeftSeparator:SetWidth(11)
			self.LeftSeparator:SetHeight(25)
			self.LeftSeparator:SetPoint("TOPRIGHT", self, "TOPLEFT", 6, 1)
		end
	end

	-- If this button didn't have a right anchor, add the right border texture
	if (not rightHandled) then
		if (not self.RightSeparator) then
			-- Add a Right border
			self.RightSeparator = self:CreateTexture(self:GetName() and self:GetName().."_RightSeparator" or nil, "BORDER")
			self.RightSeparator:SetTexture("Interface\\FrameGeneral\\UI-Frame")
			self.RightSeparator:SetTexCoord(0.90625000, 0.99218750, 0.00781250, 0.20312500)
			self.RightSeparator:SetWidth(11)
			self.RightSeparator:SetHeight(25)
			self.RightSeparator:SetPoint("TOPLEFT", self, "TOPRIGHT", -6, 1)
		end
	end
end

function DynamicResizeButton_Resize(self)
	local padding = 40;
	local width = self:GetWidth();
	local textWidth = self:GetTextWidth() + padding;
	self:SetWidth(math.max(width, textWidth));
end

function InputScrollFrame_OnLoad(self)
	local scrollBar = self.ScrollBar
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOPLEFT", self, "TOPRIGHT", -13, -11)
	scrollBar:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT", -13, 9)
	-- -- reposition the up and down buttons
	self.ScrollBar.ScrollDownButton:SetPoint("TOP", scrollBar, "BOTTOM", 0, 4)
	self.ScrollBar.ScrollUpButton:SetPoint("BOTTOM", scrollBar, "TOP", 0, -4)
	-- make the scroll bar hideable and force it to start off hidden so positioning calculations can be done
	-- as soon as it needs to be shown
	self.scrollBarHideable = 1
	scrollBar:Hide()
	self.EditBox:SetWidth(self:GetWidth() - 18)
	self.EditBox:SetMaxLetters(self.maxLetters)
	self.EditBox.Instructions:SetText(self.instructions)
	self.EditBox.Instructions:SetWidth(self:GetWidth())
	self.EditBox.HasStickyFocus = function()
		return DoesAncestryInclude(self, GetMouseFocus());
	end
	self.CharCount:SetShown(not self.hideCharCount)
end

function InputScrollFrame_OnTextChanged(self)
	local scrollFrame = self:GetParent()
	ScrollingEdit_OnTextChanged(self, scrollFrame)
	if ( self:GetText() ~= "" ) then
		self.Instructions:Hide()
	else
		self.Instructions:Show()
	end

	scrollFrame.CharCount:SetText(self:GetMaxLetters() - self:GetNumLetters())
	if ( scrollFrame.ScrollBar:IsShown() ) then
		scrollFrame.CharCount:SetPoint("BOTTOMRIGHT", -17, 0)
	else
		scrollFrame.CharCount:SetPoint("BOTTOMRIGHT", 0, 0)
	end
end

function ScrollBar_AdjustAnchors(scrollBar, topAdj, bottomAdj, xAdj)
	-- assumes default anchoring of topleft-topright, bottomleft-bottomright
	local topY = 0
	local bottomY = 0
	local point, parent, refPoint, x, y
	for i = 1, 2 do
		point, parent, refPoint, x, y = scrollBar:GetPoint(i)
		if ( point == "TOPLEFT" ) then
			topY = y
		elseif ( point == "BOTTOMLEFT" ) then
			bottomY = y
		end
	end
	xAdj = xAdj or 0
	topAdj = topAdj or 0
	bottomAdj = bottomAdj or 0
	scrollBar:SetPoint("TOPLEFT", parent, "TOPRIGHT", x + xAdj, topY + topAdj)
	scrollBar:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", x + xAdj, bottomY + bottomAdj)
end

-- InputBoxInstructionsTemplate

function InputBoxInstructions_UpdateColorForEnabledState(self, color)
	if color then
		self:SetTextColor(color:GetRGBA())
	end
end

function InputBoxInstructions_OnTextChanged(self)
	self.Instructions:SetShown(self:GetText() == "")
end

function InputBoxInstructions_OnDisable(self)
	InputBoxInstructions_UpdateColorForEnabledState(self, self.disabledColor)
end

function InputBoxInstructions_OnEnable(self)
	InputBoxInstructions_UpdateColorForEnabledState(self, self.enabledColor)
end

-- SearchBoxTemplate

function SearchBoxTemplateClearButton_OnClick(self)
	PlaySound("igMainMenuOptionCheckBoxOn")
	local editBox = self:GetParent()
	editBox:SetText("")
	editBox:ClearFocus()
end

function SearchBoxTemplate_OnLoad(self)
	local Instructions = _G[self:GetAttribute("Instructions")] or self:GetAttribute("Instructions")

	self.searchIcon:SetVertexColor(0.6, 0.6, 0.6)
	self:SetTextInsets(16, 20, 0, 0)
	self.Instructions:SetText(Instructions or SEARCH)
	self.Instructions:ClearAllPoints()
	self.Instructions:SetPoint("TOPLEFT", self, "TOPLEFT", 16, 0)
	self.Instructions:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -20, 0)
end

function SearchBoxTemplate_OnEditFocusLost(self)
	if ( self:GetText() == "" ) then
		self.searchIcon:SetVertexColor(0.6, 0.6, 0.6)
		self.clearButton:Hide()
	end
end

function SearchBoxTemplate_OnEditFocusGained(self)
	self.searchIcon:SetVertexColor(1.0, 1.0, 1.0)
	self.clearButton:Show()
end

function SearchBoxTemplate_OnTextChanged(self)
	if ( not self:HasFocus() and self:GetText() == "" ) then
		self.searchIcon:SetVertexColor(0.6, 0.6, 0.6)
		self.clearButton:Hide()
	else
		self.searchIcon:SetVertexColor(1.0, 1.0, 1.0)
		self.clearButton:Show()
	end
	InputBoxInstructions_OnTextChanged(self)
end

--Inline hyperlinks
function InlineHyperlinkFrame_OnEnter( self, _, link )
	GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
	GameTooltip:SetHyperlink(link)
end

function InlineHyperlinkFrame_OnLeave(self)
	GameTooltip:Hide()
end

function InlineHyperlinkFrame_OnClick(self, link, text, button)
	if ( self.hasIconHyperlinks ) then
		local fixedLink
		local _, _, linkType, linkID = string.find(link, "([%a]+):([%d]+)")
		if ( linkType == "currency" ) then
			fixedLink = GetCurrencyLink(linkID)
		end

		if ( fixedLink ) then
			HandleModifiedItemClick(fixedLink)
			return
		end
	end
	SetItemRef(link, text, button)
end


-- *************************************************************************************
HELP_BUTTON_NORMAL_SIZE = 46;
HELP_BUTTON_LARGE_SIZE = 55;

HELP_PLATE_BUTTONS = {};
function HelpPlate_GetButton()
	local frame;
	local i = 1;
	for i=1, #HELP_PLATE_BUTTONS do
		local button = HELP_PLATE_BUTTONS[i];
		if ( not button:IsShown() ) then
			frame = button;
			break;
		end
	end

	if ( not frame ) then
		frame = CreateFrame( "Button", nil, HelpPlate, "HelpPlateButton" );
		frame.box = CreateFrame( "Frame", nil, HelpPlate, "HelpPlateBox" );
		frame.box.button = frame;
		frame.boxHighlight = CreateFrame( "Frame", nil, HelpPlate, "HelpPlateBoxHighlight" );
		table.insert( HELP_PLATE_BUTTONS, frame );
	end
	frame.tooltipDir = "RIGHT";
	frame:SetSize(HELP_BUTTON_NORMAL_SIZE, HELP_BUTTON_NORMAL_SIZE);

	return frame;
end

function HelpPlateBox_OnLoad(self)
	self.Textures = {
		self.TopLeft,
		self.TopRight,
		self.BottomLeft,
		self.BottomRight,
		self.Top,
		self.Bottom,
		self.Left,
		self.Right
	}

	for i=1, #self.Textures do
		self.Textures[i]:SetVertexColor( 1, 0.82, 0 );
	end
end

function HelpPlateBox_OnEnter(self)
	HelpPlate_Button_OnEnter(self.button);
end

function HelpPlateBox_OnLeave(self)
	HelpPlate_Button_OnLeave(self.button);
end

function HelpPlate_ShowTutorialPrompt( self, mainHelpButton )
	mainHelpButton.initialTutorial = true;
	Main_HelpPlate_Button_ShowTooltip(mainHelpButton);
	HelpPlateTooltip.LingerAndFade:Play();

end

local HELP_PLATE_CURRENT_PLATE = nil;
function HelpPlate_Show( self, parent, mainHelpButton )
	if ( HELP_PLATE_CURRENT_PLATE ) then
		HelpPlate_Hide();
	end

	HELP_PLATE_CURRENT_PLATE = self;
	HELP_PLATE_CURRENT_PLATE.mainHelpButton = mainHelpButton;
	for i = 1, #self do
		if ( not self[i].MinLevel or (UnitLevel("player") >= self[i].MinLevel) ) then
			local button = HelpPlate_GetButton();
			button:ClearAllPoints();
			button:SetPoint( "TOPLEFT", HelpPlate, "TOPLEFT", self[i].ButtonPos.x, self[i].ButtonPos.y );
			button.tooltipDir = self[i].ToolTipDir;
			button.toolTipText = self[i].ToolTipText;
			button.viewed = false;
			button:Show();
			if ( mainHelpButton.initialTutorial ) then
				button.HelpIGlow:Show();
				button.BgGlow:Show();
				-- button.Pulse:Play();
			else
				button.HelpIGlow:Hide();
				button.BgGlow:Hide();
				-- button.Pulse:Stop();
			end

			button.box:ClearAllPoints();
			button.box:SetSize( self[i].HighLightBox.width, self[i].HighLightBox.height );
			button.box:SetPoint( "TOPLEFT", HelpPlate, "TOPLEFT", self[i].HighLightBox.x, self[i].HighLightBox.y );
			button.box:Show();

			button.boxHighlight:ClearAllPoints();
			button.boxHighlight:SetSize( self[i].HighLightBox.width, self[i].HighLightBox.height );
			button.boxHighlight:SetPoint( "TOPLEFT", HelpPlate, "TOPLEFT", self[i].HighLightBox.x, self[i].HighLightBox.y );
			button.boxHighlight:Hide();
		end
	end

	HelpPlate:SetParent(parent)
	HelpPlate:SetPoint( "TOPLEFT", parent, "TOPLEFT", self.FramePos.x, self.FramePos.y );
	HelpPlate:SetSize( self.FrameSize.width, self.FrameSize.height );
	HelpPlate:Show();
end

function HelpPlate_Hide(userToggled)
	if ( not HELP_PLATE_CURRENT_PLATE ) then
		return;
	end

	HELP_PLATE_CURRENT_PLATE.mainHelpButton.initialTutorial = false;

	if (not userToggled) then
		for i = 1, #HELP_PLATE_BUTTONS do
			local button = HELP_PLATE_BUTTONS[i];
			button.tooltipDir = "RIGHT";
			button.box:Hide();
			button:Hide();
		end
		HELP_PLATE_CURRENT_PLATE = nil;
		HelpPlate:Hide();
		return
	end

	-- else animate out
	-- look in HelpPlate_Button_AnimGroup_Show_OnFinished for final cleanup code
	if ( HELP_PLATE_CURRENT_PLATE ) then
		for i = 1, #HELP_PLATE_BUTTONS do
			local button = HELP_PLATE_BUTTONS[i];
			button.tooltipDir = "RIGHT";
			if ( button:IsShown() ) then
				if ( button.animGroup_Show:IsPlaying() or button.animGroup_Hide:IsPlaying() ) then
					button.animGroup_Show:Stop();
					button.animGroup_Hide:Stop()
				end

				local scale = button:GetEffectiveScale()
				local point, relative, relPoint, xOff, yOff = button:GetPoint()
				button.animGroup_Hide.Translation:SetOffset( (-1*xOff) * scale, (-1*yOff) * scale )
				button.animGroup_Hide:SetScript("OnFinished", HelpPlate_Button_AnimGroup_Show_OnFinished)
				button.animGroup_Hide:Play()
			end
		end
	end
end

function HelpPlate_IsShowing(plate)
	return (HELP_PLATE_CURRENT_PLATE == plate);
end

function Main_HelpPlate_Button_OnEnter(self)
	Main_HelpPlate_Button_ShowTooltip(self);
end

function Main_HelpPlate_Button_ShowTooltip(self)
	HelpPlateTooltip.ArrowRIGHT:Show();
	HelpPlateTooltip.ArrowGlowRIGHT:Show();
	HelpPlateTooltip:SetPoint("LEFT", self, "RIGHT", 10, 0);
	HelpPlateTooltip.Text:SetText(MAIN_HELP_BUTTON_TOOLTIP);
	HelpPlateTooltip:Show();
end

function Main_HelpPlate_Button_OnLeave(self)
	HelpPlateTooltip.ArrowRIGHT:Hide();
	HelpPlateTooltip.ArrowGlowRIGHT:Hide();
	HelpPlateTooltip:ClearAllPoints();
	HelpPlateTooltip:Hide();
end

function HelpPlate_Button_OnLoad(self)
	self.animGroup_Hide.parent = self;
end

function HelpPlate_Button_AnimGroup_Show_OnFinished(self)
	-- hide the parent button
	self.parent:Hide();
	self:SetScript("OnFinished", nil);

	-- lets see if we can cleanup the help plate now.
	for i = 1, #HELP_PLATE_BUTTONS do
		local button = HELP_PLATE_BUTTONS[i];
		if ( button:IsShown() ) then
			return;
		end
	end

	-- we are done animating. lets hide everything
	for i = 1, #HELP_PLATE_BUTTONS do
		local button = HELP_PLATE_BUTTONS[i];
		button.box:Hide();
		button.boxHighlight:Hide();
	end

	HELP_PLATE_CURRENT_PLATE = nil;
	HelpPlate:Hide();
end

function HelpPlate_Button_OnShow(self)
	local scale = self:GetEffectiveScale()
	local point, relative, relPoint, xOff, yOff = self:GetPoint()
	self.animGroup_Show.TranslationInit:SetOffset( (-1*xOff) * scale, (-1*yOff) * scale )
	self.animGroup_Show.Translation:SetOffset( (1*xOff) * scale, (1*yOff) * scale )
	self.animGroup_Show:Play()
end

function HelpPlate_Button_OnEnter(self)
	HelpPlate_TooltipHide();

	if ( self.tooltipDir == "UP" ) then
		HelpPlateTooltip.ArrowUP:Show();
		HelpPlateTooltip.ArrowGlowUP:Show();
		HelpPlateTooltip:SetPoint("BOTTOM", self, "TOP", 0, 10);
	elseif ( self.tooltipDir == "DOWN" ) then
		HelpPlateTooltip.ArrowDOWN:Show();
		HelpPlateTooltip.ArrowGlowDOWN:Show();
		HelpPlateTooltip:SetPoint("TOP", self, "BOTTOM", 0, -10);
	elseif ( self.tooltipDir == "LEFT" ) then
		HelpPlateTooltip.ArrowLEFT:Show();
		HelpPlateTooltip.ArrowGlowLEFT:Show();
		HelpPlateTooltip:SetPoint("RIGHT", self, "LEFT", -10, 0);
	elseif ( self.tooltipDir == "RIGHT" ) then
		HelpPlateTooltip.ArrowRIGHT:Show();
		HelpPlateTooltip.ArrowGlowRIGHT:Show();
		HelpPlateTooltip:SetPoint("LEFT", self, "RIGHT", 10, 0);
	end
	HelpPlateTooltip.Text:SetText(self.toolTipText)
	HelpPlateTooltip:Show();
	self.box.BG:Hide();
	self.boxHighlight:Show();
	-- self.Pulse:Stop();
	self.HelpIGlow:Hide();
	self.BgGlow:Hide();
end

function HelpPlate_Button_OnLeave(self)
	HelpPlate_TooltipHide();
	self.box.BG:Show();
	self.boxHighlight:Hide();
	self.viewed = true;

	-- remind the player to use the main button to toggle the help plate
	-- but only if this is the first time they have opened the UI and are
	-- going through the initial tutorial
	if ( HELP_PLATE_CURRENT_PLATE.mainHelpButton.initialTutorial ) then
		for i = 1, #HELP_PLATE_BUTTONS do
			local button = HELP_PLATE_BUTTONS[i];
			if ( button:IsShown() and not button.viewed ) then
				return;
			end
		end
		Main_HelpPlate_Button_OnEnter(HELP_PLATE_CURRENT_PLATE.mainHelpButton);
	end
end

function HelpPlate_TooltipHide()
	HelpPlateTooltip.ArrowUP:Hide();
	HelpPlateTooltip.ArrowGlowUP:Hide();
	HelpPlateTooltip.ArrowDOWN:Hide();
	HelpPlateTooltip.ArrowGlowDOWN:Hide();
	HelpPlateTooltip.ArrowLEFT:Hide();
	HelpPlateTooltip.ArrowGlowLEFT:Hide();
	HelpPlateTooltip.ArrowRIGHT:Hide();
	HelpPlateTooltip.ArrowGlowRIGHT:Hide();
	HelpPlateTooltip:ClearAllPoints();
	HelpPlateTooltip:Hide();
end

function TutorialHelpBoxAlertTemplate_OnShow( self, ... )
	if self.Parent then
		self:SetParent(self.Parent)
	end

	if self.Anchors then
		self:ClearAllPoints()
		self:SetPoint(self.Anchors[1], self.Anchors[2], self.Anchors[3], self.Anchors[4], self.Anchors[5])
	end

	self.Text:SetSpacing(4)
	self.Text:SetText(self.text or "")
	self:SetHeight(self.Text:GetHeight() + 42)

	if self.AnchorsArray then
		self.Arrow:ClearAllPoints()
		self.Arrow:SetPoint(self.AnchorsArray[1], self, self.AnchorsArray[2], self.AnchorsArray[3], self.AnchorsArray[4])

		SetClampedTextureRotation(self.Arrow.Arrow, self.AnchorsArray[5])
	end
end


local MAX_TIME_BETWEEN_CHANGES_SEC = .5;
local MIN_TIME_BETWEEN_CHANGES_SEC = .075;
local TIME_TO_REACH_MAX_SEC = 3;

function NumericInputSpinner_StartIncrement( self )
	self.incrementing = true;
	self.startTime = GetTime();
	self.nextUpdate = MAX_TIME_BETWEEN_CHANGES_SEC;
	self:SetScript("OnUpdate", NumericInputSpinner_OnUpdate);
	NumericInputSpinner_Increment(self)
	self:ClearFocus();
end

function NumericInputSpinner_OnUpdate( self, elapsed )
	self.nextUpdate = self.nextUpdate - elapsed;
	if self.nextUpdate <= 0 then
		if self.incrementing then
			NumericInputSpinner_Increment(self)
		else
			NumericInputSpinner_Decrement(self)
		end

		local totalElapsed = GetTime() - self.startTime;

		local nextUpdateDelta = Lerp(MAX_TIME_BETWEEN_CHANGES_SEC, MIN_TIME_BETWEEN_CHANGES_SEC, Saturate(totalElapsed / TIME_TO_REACH_MAX_SEC));
		self.nextUpdate = self.nextUpdate + nextUpdateDelta;
	end
end

function NumericInputSpinner_EndIncrement( self )
	self:SetScript("OnUpdate", nil)
end

function NumericInputSpinner_StartDecrement( self )
	self.incrementing = false;
	self.startTime = GetTime();
	self.nextUpdate = MAX_TIME_BETWEEN_CHANGES_SEC;
	self:SetScript("OnUpdate", NumericInputSpinner_OnUpdate);
	NumericInputSpinner_Decrement(self)
	self:ClearFocus();
end

function NumericInputSpinner_EndDecrement( self )
	self:SetScript("OnUpdate", nil);
end

function NumericInputSpinner_Increment( self, value )
	local boxValue = tonumber(self:GetText()) or 0
	self:SetText(boxValue + (value or 1))
end

function NumericInputSpinner_Decrement( self, value )
	local boxValue = tonumber(self:GetText()) or 0
	self:SetText(boxValue - (value or 1))
end

function NumericInputSpinner_OnTextChanged( self, ... )
	-- body
end

function UIPanelButton_OnLoad(self)
	self:GetParent().Middle:ClearAllPoints()
	self:GetParent().Middle:SetPoint("TOPLEFT", self:GetParent().Left, "TOPRIGHT")
	self:GetParent().Middle:SetPoint("BOTTOMRIGHT", self:GetParent().Right, "BOTTOMLEFT")

	if ( not self:GetParent():IsEnabled() == 1 ) then
		self:GetParent().Left:SetTexture("Interface\\Buttons\\UI-Panel-Button-Disabled")
		self:GetParent().Middle:SetTexture("Interface\\Buttons\\UI-Panel-Button-Disabled")
		self:GetParent().Right:SetTexture("Interface\\Buttons\\UI-Panel-Button-Disabled")
	end
end

function UIPanelButton_OnMouseDown(self)
	if ( self:IsEnabled() == 1 ) then
		self.Left:SetTexture("Interface\\Buttons\\UI-Panel-Button-Down")
		self.Middle:SetTexture("Interface\\Buttons\\UI-Panel-Button-Down")
		self.Right:SetTexture("Interface\\Buttons\\UI-Panel-Button-Down")
	end
end

function UIPanelButton_OnMouseUp(self)
	if ( self:IsEnabled() == 1 ) then
		self.Left:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
		self.Middle:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
		self.Right:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
	end
end

function UIPanelButton_OnShow(self)
	if ( self:IsEnabled() == 1 ) then
		self.Left:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
		self.Middle:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
		self.Right:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
	end
end

function UIPanelButton_OnDisable(self)
	self.Left:SetTexture("Interface\\Buttons\\UI-Panel-Button-Disabled")
	self.Middle:SetTexture("Interface\\Buttons\\UI-Panel-Button-Disabled")
	self.Right:SetTexture("Interface\\Buttons\\UI-Panel-Button-Disabled")
end

function UIPanelButton_OnEnable(self)
	self.Left:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
	self.Middle:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
	self.Right:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
end


MaximizeMinimizeButtonFrameMixin = {}

function MaximizeMinimizeButtonFrame_OnLoad( self )
	Mixin(self, MaximizeMinimizeButtonFrameMixin)
end

function MaximizeMinimizeButtonFrame_OnShow( self )
	if self.cvar then
		local minimized = GetCVarBool(self.cvar)
		if minimized then
			self:Minimize()
		else
			self:Maximize()
		end
	end
end

function MaximizeMinimizeButtonFrameMixin:SetMinimizedCVar( cvar )
	self.cvar = cvar
end

function MaximizeMinimizeButtonFrameMixin:SetOnMaximizedCallback( maximizedCallback )
	self.maximizedCallback = maximizedCallback
end

function MaximizeMinimizeButtonFrameMixin:Maximize()
	if self.maximizedCallback then
		self.maximizedCallback(self)
	end

	if self.cvar then
		SetCVar(self.cvar, 0)
	end

	self.MaximizeButton:Hide()
	self.MinimizeButton:Show()
end

function MaximizeMinimizeButtonFrameMixin:SetOnMinimizedCallback( minimizedCallback )
	self.minimizedCallback = minimizedCallback
end

function MaximizeMinimizeButtonFrameMixin:Minimize()
	if self.minimizedCallback then
		self.minimizedCallback(self)
	end

	if self.cvar then
		SetCVar(self.cvar, 1)
	end

	self.MaximizeButton:Show()
	self.MinimizeButton:Hide()
end

function ScrollFrameTemplate_OnMouseWheel(self, value, scrollBar)
	scrollBar = scrollBar or _G[self:GetName() .. "ScrollBar"];
	if ( value > 0 ) then
		scrollBar:SetValue(scrollBar:GetValue() - (scrollBar:GetHeight() / 2));
	else
		scrollBar:SetValue(scrollBar:GetValue() + (scrollBar:GetHeight() / 2));
	end
end

-- Function to handle the update of manually calculated scrollframes.  Used mostly for listings with an indeterminate number of items
function FauxScrollFrame_Update(frame, numItems, numToDisplay, valueStep, button, smallWidth, bigWidth, highlightFrame, smallHighlightWidth, bigHighlightWidth, alwaysShowScrollBar, heightOnDisplay )
	-- If more than one screen full of skills then show the scrollbar
	local frameName = frame:GetName();
	local scrollBar = _G[ frameName.."ScrollBar" ]
	local showScrollBar;
	if ( numItems > numToDisplay or alwaysShowScrollBar ) then
		frame:Show();
		showScrollBar = 1;
	else
		scrollBar:SetValue(0);
		frame:Hide();
	end
	if ( frame:IsShown() ) then
		local scrollChildFrame = _G[ frameName.."ScrollChildFrame" ];
		local scrollUpButton = _G[ frameName.."ScrollBarScrollUpButton" ];
		local scrollDownButton = _G[ frameName.."ScrollBarScrollDownButton" ];
		local scrollFrameHeight = 0;
		local scrollChildHeight = 0;

		if ( numItems > 0 ) then
			scrollFrameHeight = (numItems - numToDisplay) * valueStep;
			if heightOnDisplay then
				scrollChildHeight = numToDisplay * valueStep;
			else
				scrollChildHeight = numItems * valueStep;
			end
			if ( scrollFrameHeight < 0 ) then
				scrollFrameHeight = 0;
			end
			scrollChildFrame:Show();
		else
			scrollChildFrame:Hide();
		end
		scrollBar:SetMinMaxValues(0, scrollFrameHeight);
		scrollBar:SetValueStep(valueStep);
		scrollChildFrame:SetHeight(scrollChildHeight);

		-- Arrow button handling
		if ( scrollBar:GetValue() == 0 ) then
			scrollUpButton:Disable();
		else
			scrollUpButton:Enable();
		end
		if ((scrollBar:GetValue() - scrollFrameHeight) == 0) then
			scrollDownButton:Disable();
		else
			scrollDownButton:Enable();
		end

		-- Shrink because scrollbar is shown
		if ( highlightFrame ) then
			highlightFrame:SetWidth(smallHighlightWidth);
		end
		if ( button ) then
			for i=1, numToDisplay do
				_G[button..i]:SetWidth(smallWidth);
			end
		end
	else
		-- Widen because scrollbar is hidden
		if ( highlightFrame ) then
			highlightFrame:SetWidth(bigHighlightWidth);
		end
		if ( button ) then
			for i=1, numToDisplay do
				_G[button..i]:SetWidth(bigWidth);
			end
		end
	end
	return showScrollBar;
end

function FauxScrollFrame_OnVerticalScroll(self, value, itemHeight, updateFunction)
	local scrollbar = _G[self:GetName().."ScrollBar"];
	scrollbar:SetValue(value);
	self.offset = floor((value / itemHeight) + 0.5);
	if ( updateFunction ) then
		updateFunction(self);
	end
end

function FauxScrollFrame_GetOffset(frame)
	return frame.offset;
end

function FauxScrollFrame_SetOffset(frame, offset)
	frame.offset = offset;
end

-- Scrollframe functions
function ScrollFrame_OnLoad(self)
	_G[self:GetName().."ScrollBarScrollDownButton"]:Disable();
	_G[self:GetName().."ScrollBarScrollUpButton"]:Disable();

	local scrollbar = _G[self:GetName().."ScrollBar"];
	scrollbar:SetMinMaxValues(0, 0);
	scrollbar:SetValue(0);
	self.offset = 0;

	if ( self.scrollBarHideable ) then
		_G[self:GetName().."ScrollBar"]:Hide();
		_G[scrollbar:GetName().."ScrollDownButton"]:Hide();
		_G[scrollbar:GetName().."ScrollUpButton"]:Hide();
	else
		_G[scrollbar:GetName().."ScrollDownButton"]:Disable();
		_G[scrollbar:GetName().."ScrollUpButton"]:Disable();
		_G[scrollbar:GetName().."ScrollDownButton"]:Show();
		_G[scrollbar:GetName().."ScrollUpButton"]:Show();
	end
end

function ScrollFrame_OnScrollRangeChanged(self, xrange, yrange)
	local scrollbar = _G[self:GetName().."ScrollBar"];
	if ( not yrange ) then
		yrange = self:GetVerticalScrollRange();
	end
	local value = scrollbar:GetValue();
	if ( value > yrange ) then
		value = yrange;
	end
	scrollbar:SetMinMaxValues(0, yrange);
	scrollbar:SetValue(value);
	if ( floor(yrange) == 0 ) then
		if ( self.scrollBarHideable ) then
			_G[self:GetName().."ScrollBar"]:Hide();
			_G[scrollbar:GetName().."ScrollDownButton"]:Hide();
			_G[scrollbar:GetName().."ScrollUpButton"]:Hide();
			if ( self.haveTrack ) then
				_G[self:GetName().."Track"]:Hide();
			end
		else
			_G[scrollbar:GetName().."ScrollDownButton"]:Disable();
			_G[scrollbar:GetName().."ScrollUpButton"]:Disable();
			_G[scrollbar:GetName().."ScrollDownButton"]:Show();
			_G[scrollbar:GetName().."ScrollUpButton"]:Show();
		end
		_G[scrollbar:GetName().."ThumbTexture"]:Hide();
	else
		_G[scrollbar:GetName().."ScrollDownButton"]:Show();
		_G[scrollbar:GetName().."ScrollUpButton"]:Show();
		_G[self:GetName().."ScrollBar"]:Show();
		_G[scrollbar:GetName().."ThumbTexture"]:Show();
		if ( self.haveTrack ) then
			_G[self:GetName().."Track"]:Show();
		end
		-- The 0.005 is to account for precision errors
		if ( yrange - value > 0.005 ) then
			_G[scrollbar:GetName().."ScrollDownButton"]:Enable();
		else
			_G[scrollbar:GetName().."ScrollDownButton"]:Disable();
		end
	end

	-- Hide/show scrollframe borders
	local top = _G[self:GetName().."Top"];
	local bottom = _G[self:GetName().."Bottom"];
	local middle = _G[self:GetName().."Middle"];
	if ( top and bottom and self.scrollBarHideable ) then
		if ( self:GetVerticalScrollRange() == 0 ) then
			top:Hide();
			bottom:Hide();
		else
			top:Show();
			bottom:Show();
		end
	end
	if ( middle and self.scrollBarHideable ) then
		if ( self:GetVerticalScrollRange() == 0 ) then
			middle:Hide();
		else
			middle:Show();
		end
	end
end

function ScrollingEdit_OnTextChanged(self, scrollFrame)
	-- force an update when the text changes
	self.handleCursorChange = true;
	ScrollingEdit_OnUpdate(self, 0, scrollFrame);
end

function ScrollingEdit_OnCursorChanged(self, x, y, w, h)
	self.cursorOffset = y;
	self.cursorHeight = h;
	self.handleCursorChange = true;
end

-- NOTE: If your edit box never shows partial lines of text, then this function will not work when you use
-- your mouse to move the edit cursor. You need the edit box to cut lines of text so that you can use your
-- mouse to highlight those partially-seen lines; otherwise you won't be able to use the mouse to move the
-- cursor above or below the current scroll area of the edit box.
function ScrollingEdit_OnUpdate(self, elapsed, scrollFrame)
local height, range, scroll, size, cursorOffset;
	if ( self.handleCursorChange ) then
		if ( not scrollFrame ) then
			scrollFrame = self:GetParent();
		end
		height = scrollFrame:GetHeight();
		range = scrollFrame:GetVerticalScrollRange();
		scroll = scrollFrame:GetVerticalScroll();
		size = height + range;
		cursorOffset = -self.cursorOffset;

		if ( math.floor(height) <= 0 or math.floor(range) <= 0 ) then
			--Frame has no area, nothing to calculate.
			return;
		end

		while ( cursorOffset < scroll ) do
			scroll = (scroll - (height / 2));
			if ( scroll < 0 ) then
				scroll = 0;
			end
			scrollFrame:SetVerticalScroll(scroll);
		end

		while ( (cursorOffset + self.cursorHeight) > (scroll + height) and scroll < range ) do
			scroll = (scroll + (height / 2));
			if ( scroll > range ) then
				scroll = range;
			end
			scrollFrame:SetVerticalScroll(scroll);
		end

		self.handleCursorChange = false;
	end
end

------------------------------------
-- Loading Spinner
------------------------------------

local TIME_BETWEEN_DOTS_SEC = .5;
function LoadingSpinnerRetrieving_OnUpdate( self, elapsed, ... )
	if self.timeUntilNextDotSecs then
		self.timeUntilNextDotSecs = self.timeUntilNextDotSecs - elapsed;
	else
		self.timeUntilNextDotSecs = TIME_BETWEEN_DOTS_SEC;
	end

	if self.timeUntilNextDotSecs <= 0 then
		local dotCount = ((self.dotCount or 0) + 1) % 4;

		self.Dots:SetText(("."):rep(dotCount));
		self.dotCount = dotCount;
		self.timeUntilNextDotSecs = self.timeUntilNextDotSecs + TIME_BETWEEN_DOTS_SEC;
	end
end


SquareIconButtonMixin = {};

function SquareIconButtonMixin:OnLoad()
	self.icon = self:GetAttribute("icon");
	self.iconAtlas = self:GetAttribute("iconAtlas");
	self.tooltipTitle = self:GetAttribute("tooltipTitle");
	self.tooltipText = self:GetAttribute("tooltipText");
	self.onClickHandler = _G[self:GetAttribute("onClickHandler")];

	if self.icon then
		self:SetIcon(self.icon);
	elseif self.iconAtlas then
		self:SetAtlas(self.iconAtlas);
	end
end

function SquareIconButtonMixin:SetIcon(icon)
	self.Icon:SetTexture(icon);
end

function SquareIconButtonMixin:SetAtlas(atlas)
	self.Icon:SetAtlas(atlas);
end

function SquareIconButtonMixin:SetOnClickHandler(onClickHandler)
	self.onClickHandler = onClickHandler;
end

function SquareIconButtonMixin:SetTooltipInfo(tooltipTitle, tooltipText)
	self.tooltipTitle = tooltipTitle;
	self.tooltipText = tooltipText;
end

function SquareIconButtonMixin:OnMouseDown()
	if self:IsEnabled() then
		self.Icon:SetPoint("CENTER", self, "CENTER", -2, -1);
	end
end

function SquareIconButtonMixin:OnMouseUp()
	self.Icon:SetPoint("CENTER", self, "CENTER", -1, 0);
end

function SquareIconButtonMixin:OnEnter()
	if self.tooltipTitle then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -8, -8);
		GameTooltip_SetTitle(GameTooltip, self.tooltipTitle);

		if self.tooltipText then
			local wrap = true;
			GameTooltip_AddNormalLine(GameTooltip, self.tooltipText, wrap);
		end

		GameTooltip:Show();
	end
end

function SquareIconButtonMixin:OnLeave()
	GameTooltip_Hide();
end

function SquareIconButtonMixin:OnClick(...)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	if self.onClickHandler then
		self.onClickHandler(self, ...);
	end
end

function SquareIconButtonMixin:SetEnabledState(enabled)
	self:SetEnabled(enabled);
	self.Icon:SetDesaturated(not enabled);
end