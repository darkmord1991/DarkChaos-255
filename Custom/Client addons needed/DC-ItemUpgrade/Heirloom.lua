--[[
	DC-ItemUpgrade - Heirloom Module
	Stat package system for Heirloom Adventurer's Shirt (item 300365)
--]]

local DC = DarkChaos_ItemUpgrade;

--[[=====================================================
	STAT PACKAGES DEFINITION
	12 packages covering all secondary stat combinations
=======================================================]]

DC.STAT_PACKAGES = {
	[1] = {
		name = "Fury",
		stats = { "Crit Rating", "Haste Rating" },
		icon = "Interface\\Icons\\Ability_Warrior_InnerRage",
		description = "Critical Strike and Haste for burst damage.",
		color = { r = 1.0, g = 0.4, b = 0.4 },
	},
	[2] = {
		name = "Precision",
		stats = { "Hit Rating", "Expertise Rating" },
		icon = "Interface\\Icons\\Ability_Hunter_SniperShot",
		description = "Hit and Expertise to never miss your target.",
		color = { r = 0.8, g = 0.8, b = 0.3 },
	},
	[3] = {
		name = "Devastation",
		stats = { "Crit Rating", "Armor Pen" },
		icon = "Interface\\Icons\\Ability_Warrior_Devastate",
		description = "Critical Strike and Armor Penetration for physical DPS.",
		color = { r = 0.9, g = 0.3, b = 0.1 },
	},
	[4] = {
		name = "Swiftblade",
		stats = { "Haste Rating", "Armor Pen" },
		icon = "Interface\\Icons\\Ability_Rogue_CuttingToTheChase",
		description = "Haste and Armor Penetration for sustained damage.",
		color = { r = 0.5, g = 0.8, b = 0.5 },
	},
	[5] = {
		name = "Spellfire",
		stats = { "Spell Crit", "Spell Haste", "Spell Power" },
		icon = "Interface\\Icons\\Spell_Fire_Fireball02",
		description = "Crit, Haste and Spell Power for caster DPS.",
		color = { r = 1.0, g = 0.5, b = 0.0 },
	},
	[6] = {
		name = "Arcane",
		stats = { "Spell Hit", "Spell Haste", "Spell Power" },
		icon = "Interface\\Icons\\Spell_Arcane_Blast",
		description = "Hit, Haste and Spell Power for consistent casting.",
		color = { r = 0.5, g = 0.5, b = 1.0 },
	},
	[7] = {
		name = "Bulwark",
		stats = { "Dodge Rating", "Parry Rating", "Block Rating" },
		icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
		description = "Avoidance and Block for active mitigation tanks.",
		color = { r = 0.6, g = 0.6, b = 0.6 },
	},
	[8] = {
		name = "Fortress",
		stats = { "Defense Rating", "Block Rating", "Stamina" },
		icon = "Interface\\Icons\\Ability_Warrior_ShieldWall",
		description = "Defense, Block and Stamina for raid tanking.",
		color = { r = 0.3, g = 0.5, b = 0.8 },
	},
	[9] = {
		name = "Survivor",
		stats = { "Dodge Rating", "Stamina" },
		icon = "Interface\\Icons\\Ability_Druid_Cower",
		description = "Dodge and Stamina for evasion tanks.",
		color = { r = 0.4, g = 0.7, b = 0.4 },
	},
	[10] = {
		name = "Gladiator",
		stats = { "Resilience", "Crit Rating" },
		icon = "Interface\\Icons\\Achievement_Arena_2v2_1",
		description = "Resilience and Crit for aggressive PvP.",
		color = { r = 0.8, g = 0.2, b = 0.8 },
	},
	[11] = {
		name = "Warlord",
		stats = { "Resilience", "Stamina" },
		icon = "Interface\\Icons\\Achievement_Arena_5v5_7",
		description = "Resilience and Stamina for survivability in PvP.",
		color = { r = 0.6, g = 0.2, b = 0.2 },
	},
	[12] = {
		name = "Balanced",
		stats = { "Crit Rating", "Hit Rating", "Haste Rating" },
		icon = "Interface\\Icons\\Spell_Nature_EnchantArmor",
		description = "A balanced mix of Crit, Hit and Haste.",
		color = { r = 0.7, g = 0.7, b = 0.7 },
	},
};

--[[=====================================================
	STAT VALUE SCALING BY LEVEL
	Total secondary stats budget at each upgrade level
=======================================================]]

DC.STAT_PACKAGE_LEVEL_VALUES = {
	[1] = 6,     -- Level 1: 6 total secondary stats
	[2] = 14,    -- Level 2: 14 total
	[3] = 22,    -- Level 3: 22 total
	[4] = 32,    -- Level 4: 32 total
	[5] = 43,    -- Level 5: 43 total
	[6] = 55,    -- Level 6: 55 total
	[7] = 67,    -- Level 7: 67 total
	[8] = 80,    -- Level 8: 80 total
	[9] = 95,    -- Level 9: 95 total
	[10] = 110,  -- Level 10: 110 total
	[11] = 126,  -- Level 11: 126 total
	[12] = 142,  -- Level 12: 142 total
	[13] = 157,  -- Level 13: 157 total
	[14] = 168,  -- Level 14: 168 total
	[15] = 168,  -- Level 15: 168 total (max, same as 14)
};

-- Currently selected stat package
DC.selectedStatPackage = DC.selectedStatPackage or nil;

-- Pending package selection (before confirmation)
DC.pendingStatPackage = nil;

-- Track if we're in package selection mode
DC.inPackageSelectionMode = false;

--[[=====================================================
	VERTICAL TABLE STAT PACKAGE SELECTOR UI
	Shows packages in a vertical list with stat details
=======================================================]]

function DarkChaos_ItemUpgrade_CreateStatPackageSelector(parent)
	-- Create full-size container frame that covers the parent completely
	local selector = CreateFrame("Frame", "DarkChaos_StatPackageSelector", parent);
	selector:SetAllPoints(parent);
	selector:SetFrameStrata("DIALOG");
	selector:SetFrameLevel(parent:GetFrameLevel() + 50);  -- Much higher level to cover everything
	selector:EnableMouse(true);  -- Make it intercept mouse clicks
	selector:SetMovable(true);  -- Allow dragging
	selector:RegisterForDrag("LeftButton");
	selector:SetScript("OnDragStart", function(self)
		self:GetParent():StartMoving();
	end);
	selector:SetScript("OnDragStop", function(self)
		self:GetParent():StopMovingOrSizing();
	end);
	selector:Hide();
	
	-- Solid dark background to completely hide parent content
	local overlay = selector:CreateTexture(nil, "BACKGROUND", nil, -8);
	overlay:SetAllPoints();
	overlay:SetTexture("Interface\\Buttons\\WHITE8X8");
	overlay:SetVertexColor(0.05, 0.05, 0.08, 1);  -- Nearly black, fully opaque
	
	-- Title
	local title = selector:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
	title:SetPoint("TOP", selector, "TOP", 0, -15);
	title:SetText("|cffFFD700Change Stat Package|r");
	selector.Title = title;
	
	-- Subtitle with warning
	local subtitle = selector:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
	subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4);
	subtitle:SetWidth(560);
	subtitle:SetText("|cffff6600Warning: Changing your package will reset your upgrade level to 1!|r");
	selector.Subtitle = subtitle;
	
	-- Column headers
	local headerFrame = CreateFrame("Frame", nil, selector);
	headerFrame:SetHeight(18);
	headerFrame:SetPoint("TOPLEFT", selector, "TOPLEFT", 25, -42);
	headerFrame:SetPoint("TOPRIGHT", selector, "TOPRIGHT", -50, -42);
	
	local headerBg = headerFrame:CreateTexture(nil, "BACKGROUND");
	headerBg:SetAllPoints();
	headerBg:SetTexture("Interface\\Buttons\\WHITE8X8");
	headerBg:SetVertexColor(0.15, 0.15, 0.2, 0.8);
	
	local headerName = headerFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
	headerName:SetPoint("LEFT", headerFrame, "LEFT", 45, 0);
	headerName:SetText("|cffaaaaaaPackage|r");
	
	local headerStats = headerFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
	headerStats:SetPoint("LEFT", headerFrame, "LEFT", 155, 0);
	headerStats:SetText("|cffaaaaaa+Stats at Max Level (15)|r");
	
	local headerDesc = headerFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
	headerDesc:SetPoint("LEFT", headerFrame, "LEFT", 445, 0);
	headerDesc:SetText("|cffaaaaaaDescription|r");
	
	selector.HeaderFrame = headerFrame;
	
	-- Create scroll frame for package list
	local scrollFrame = CreateFrame("ScrollFrame", "DarkChaos_PackageScrollFrame", selector, "FauxScrollFrameTemplate");
	scrollFrame:SetPoint("TOPLEFT", selector, "TOPLEFT", 25, -60);
	scrollFrame:SetPoint("BOTTOMRIGHT", selector, "BOTTOMRIGHT", -50, 60);
	selector.ScrollFrame = scrollFrame;
	
	-- Scroll frame background
	local scrollBg = selector:CreateTexture(nil, "ARTWORK");
	scrollBg:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", -5, 5);
	scrollBg:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 25, -5);
	scrollBg:SetTexture("Interface\\Buttons\\WHITE8X8");
	scrollBg:SetVertexColor(0.05, 0.05, 0.08, 0.9);
	
	-- Package row buttons (visible rows)
	selector.rows = {};
	local rowHeight = 36;
	local numVisibleRows = 12;
	
	for i = 1, numVisibleRows do
		local row = CreateFrame("Button", "DarkChaos_PackageRow" .. i, selector);
		row:SetHeight(rowHeight);
		row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -((i-1) * rowHeight));
		row:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 0, -((i-1) * rowHeight));
		
		-- Row background
		local rowBg = row:CreateTexture(nil, "BACKGROUND");
		rowBg:SetAllPoints();
		rowBg:SetTexture("Interface\\Buttons\\WHITE8X8");
		rowBg:SetVertexColor(0.12, 0.12, 0.15, 0.95);
		row.Background = rowBg;
		
		-- Alternating row color
		if i % 2 == 0 then
			rowBg:SetVertexColor(0.08, 0.08, 0.12, 0.95);
		end
		
		-- Selected highlight
		local selectedHighlight = row:CreateTexture(nil, "BORDER");
		selectedHighlight:SetAllPoints();
		selectedHighlight:SetTexture("Interface\\Buttons\\WHITE8X8");
		selectedHighlight:SetVertexColor(1, 0.82, 0, 0.3);
		selectedHighlight:Hide();
		row.SelectedHighlight = selectedHighlight;
		
		-- Hover highlight
		local hoverHighlight = row:CreateTexture(nil, "HIGHLIGHT");
		hoverHighlight:SetAllPoints();
		hoverHighlight:SetTexture("Interface\\Buttons\\WHITE8X8");
		hoverHighlight:SetVertexColor(1, 1, 1, 0.1);
		hoverHighlight:SetBlendMode("ADD");
		
		-- Icon
		local icon = row:CreateTexture(nil, "ARTWORK");
		icon:SetWidth(28);
		icon:SetHeight(28);
		icon:SetPoint("LEFT", row, "LEFT", 8, 0);
		row.Icon = icon;
		
		-- Package name
		local name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal");
		name:SetPoint("LEFT", icon, "RIGHT", 8, 0);
		name:SetWidth(100);
		name:SetJustifyH("LEFT");
		row.NameText = name;
		
		-- Stats column
		local stats = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
		stats:SetPoint("LEFT", name, "RIGHT", 10, 0);
		stats:SetWidth(280);
		stats:SetJustifyH("LEFT");
		row.StatsText = stats;
		
		-- Description column (truncated)
		local desc = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
		desc:SetPoint("LEFT", stats, "RIGHT", 10, 0);
		desc:SetPoint("RIGHT", row, "RIGHT", -10, 0);
		desc:SetJustifyH("LEFT");
		desc:SetTextColor(0.6, 0.6, 0.6);
		row.DescText = desc;
		
		row:SetScript("OnClick", function(self)
			if self.packageId then
				DarkChaos_ItemUpgrade_PreviewStatPackage(self.packageId);
			end
		end);
		
		selector.rows[i] = row;
	end
	
	-- Scroll frame script
	scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, rowHeight, DarkChaos_ItemUpgrade_UpdatePackageList);
	end);
	
	-- Bottom buttons frame
	local btnFrame = CreateFrame("Frame", nil, selector);
	btnFrame:SetHeight(40);
	btnFrame:SetPoint("BOTTOMLEFT", selector, "BOTTOMLEFT", 20, 15);
	btnFrame:SetPoint("BOTTOMRIGHT", selector, "BOTTOMRIGHT", -20, 15);
	
	-- Cancel Button
	local cancelBtn = CreateFrame("Button", "DarkChaos_PackageCancelBtn", selector, "UIPanelButtonTemplate");
	cancelBtn:SetWidth(120);
	cancelBtn:SetHeight(24);
	cancelBtn:SetPoint("BOTTOMLEFT", selector, "BOTTOMLEFT", 30, 18);
	cancelBtn:SetText("Cancel");
	cancelBtn:SetScript("OnClick", function(self)
		-- If we have an existing package, go back to upgrade screen
		if DC.selectedStatPackage then
			DarkChaos_ItemUpgrade_ExitPackageSelectionMode();
		else
			-- No package selected, close the whole frame
			DarkChaos_ItemUpgradeFrame:Hide();
		end
	end);
	selector.CancelButton = cancelBtn;
	
	-- Confirm Button
	local confirmBtn = CreateFrame("Button", "DarkChaos_PackageConfirmBtn", selector, "UIPanelButtonTemplate");
	confirmBtn:SetWidth(140);
	confirmBtn:SetHeight(24);
	confirmBtn:SetPoint("BOTTOMRIGHT", selector, "BOTTOMRIGHT", -30, 18);
	confirmBtn:SetText("Confirm Selection");
	confirmBtn:Disable();
	confirmBtn:SetScript("OnClick", function(self)
		DarkChaos_ItemUpgrade_ConfirmPackageSelection();
	end);
	selector.ConfirmButton = confirmBtn;
	
	-- Selected package preview text (between list and buttons)
	local previewText = selector:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	previewText:SetPoint("BOTTOMLEFT", selector, "BOTTOMLEFT", 160, 22);
	previewText:SetPoint("BOTTOMRIGHT", selector, "BOTTOMRIGHT", -180, 22);
	previewText:SetJustifyH("CENTER");
	previewText:SetText("");
	selector.PreviewText = previewText;
	
	-- Store reference
	parent.StatPackageSelector = selector;
	DC.StatPackageSelector = selector;
	
	-- Initial update
	DarkChaos_ItemUpgrade_UpdatePackageList();
end

--[[=====================================================
	PACKAGE LIST UPDATE
=======================================================]]

function DarkChaos_ItemUpgrade_UpdatePackageList()
	local selector = DC.StatPackageSelector;
	if not selector or not selector.rows then return; end
	
	local scrollFrame = selector.ScrollFrame;
	local numPackages = 12;
	local rowHeight = 36;
	local numVisibleRows = #selector.rows;
	
	FauxScrollFrame_Update(scrollFrame, numPackages, numVisibleRows, rowHeight);
	
	local offset = FauxScrollFrame_GetOffset(scrollFrame);
	
	for i = 1, numVisibleRows do
		local row = selector.rows[i];
		local packageIndex = i + offset;
		
		if packageIndex <= numPackages then
			local pkg = DC.STAT_PACKAGES[packageIndex];
			row.packageId = packageIndex;
			
			-- Set icon
			row.Icon:SetTexture(pkg.icon);
			
			-- Set name with color
			local colorHex = string.format("%.2x%.2x%.2x", pkg.color.r*255, pkg.color.g*255, pkg.color.b*255);
			row.NameText:SetText(string.format("|cff%s%s|r", colorHex, pkg.name));
			
			-- Set stats with values at level 15 (max)
			local statsStr = "";
			local lvl15Stats = DarkChaos_ItemUpgrade_GetPackageStatsAtLevel(packageIndex, 15);
			if lvl15Stats then
				local statParts = {};
				for _, stat in ipairs(lvl15Stats) do
					table.insert(statParts, string.format("|cff00ff00+%d|r %s", stat.value, stat.name));
				end
				statsStr = table.concat(statParts, ", ");
			end
			row.StatsText:SetText(statsStr);
			
			-- Set description
			row.DescText:SetText(pkg.description);
			
			-- Highlight if selected/pending
			if packageIndex == DC.pendingStatPackage then
				row.SelectedHighlight:Show();
				row.SelectedHighlight:SetVertexColor(1, 0.82, 0, 0.4);
			elseif packageIndex == DC.selectedStatPackage and not DC.pendingStatPackage then
				row.SelectedHighlight:Show();
				row.SelectedHighlight:SetVertexColor(0.2, 0.8, 0.2, 0.3);
			else
				row.SelectedHighlight:Hide();
			end
			
			-- Restore alternating row colors
			if i % 2 == 0 then
				row.Background:SetVertexColor(0.08, 0.08, 0.12, 0.95);
			else
				row.Background:SetVertexColor(0.12, 0.12, 0.15, 0.95);
			end
			
			row:Show();
		else
			row:Hide();
		end
	end
end

--[[=====================================================
	CHANGE PACKAGE BUTTON (for upgrade screen)
=======================================================]]

function DarkChaos_ItemUpgrade_CreateChangePackageButton(parent)
	if parent.ChangePackageButton then return; end
	
	local btn = CreateFrame("Button", "DarkChaos_ChangePackageBtn", parent, "UIPanelButtonTemplate");
	btn:SetWidth(130);
	btn:SetHeight(22);
	btn:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 20);
	btn:SetText("Change Package");
	btn:Hide();
	
	btn:SetScript("OnClick", function(self)
		DarkChaos_ItemUpgrade_EnterPackageSelectionMode(true);
	end);
	
	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText("Change Stat Package", 1, 0.82, 0);
		GameTooltip:AddLine("Select a different stat package.", 1, 1, 1, true);
		GameTooltip:AddLine("|cffff8800Warning: This will reset your upgrade level!|r", 1, 1, 1, true);
		GameTooltip:Show();
	end);
	
	btn:SetScript("OnLeave", function(self)
		GameTooltip:Hide();
	end);
	
	parent.ChangePackageButton = btn;
end

--[[=====================================================
	PACKAGE SELECTION MODE CONTROL
=======================================================]]

function DarkChaos_ItemUpgrade_EnterPackageSelectionMode(isChanging)
	DC.inPackageSelectionMode = true;
	DC.isChangingPackage = isChanging or false;
	DC.pendingStatPackage = nil;  -- Reset pending selection
	
	local frame = DarkChaos_ItemUpgradeFrame;
	local selector = DC.StatPackageSelector;
	
	if not frame or not selector then
		return;
	end
	
	-- Hide ALL background UI elements to prevent visibility issues
	if frame.ItemSlot then frame.ItemSlot:Hide(); end
	if frame.ItemInfo then frame.ItemInfo:Hide(); end
	if frame.CurrentPanel then frame.CurrentPanel:Hide(); end
	if frame.UpgradePanel then frame.UpgradePanel:Hide(); end
	if frame.CostFrame then frame.CostFrame:Hide(); end
	if frame.UpgradeButton then frame.UpgradeButton:Hide(); end
	if frame.LeftTooltip then frame.LeftTooltip:Hide(); end
	if frame.RightTooltip then frame.RightTooltip:Hide(); end
	if frame.Arrow then frame.Arrow:Hide(); end
	if frame.DropdownContainer then frame.DropdownContainer:Hide(); end
	if frame.ErrorText then frame.ErrorText:Hide(); end
	if frame.MissingDescription then frame.MissingDescription:Hide(); end
	if frame.PlayerCurrencies then frame.PlayerCurrencies:Hide(); end
	if frame.PackageIndicator then frame.PackageIndicator:Hide(); end
	if frame.ChangePackageButton then frame.ChangePackageButton:Hide(); end
	if frame.UpgradeSelector then frame.UpgradeSelector:Hide(); end
	local dropdown = _G["DarkChaos_ItemUpgradeFrameDropdown"];
	if dropdown then dropdown:Hide(); end
	
	-- Update title based on mode
	if selector.Title then
		if isChanging then
			selector.Title:SetText("|cffFFD700Change Stat Package|r");
		else
			selector.Title:SetText("|cffFFD700Select Stat Package|r");
		end
	end
	
	-- Update subtitle
	if selector.Subtitle then
		if isChanging then
			selector.Subtitle:SetText("|cffff8800Warning: Changing your package will reset your upgrade level to 1!|r");
		else
			selector.Subtitle:SetText("|cff888888Choose a secondary stat package for your heirloom. Stats scale with upgrade level.|r");
		end
	end
	
	-- Show the package selector (it covers everything)
	selector:Show();
	
	-- Update the list
	DarkChaos_ItemUpgrade_UpdatePackageList();
	
	-- Reset confirm button
	if selector.ConfirmButton then
		selector.ConfirmButton:Disable();
	end
	
	-- Clear preview text
	if selector.PreviewText then
		selector.PreviewText:SetText("|cff888888Click a package to preview it|r");
	end
	
	-- Update cancel button text
	if selector.CancelButton then
		if DC.selectedStatPackage then
			selector.CancelButton:SetText("Cancel");
		else
			selector.CancelButton:SetText("Close");
		end
	end
end

function DarkChaos_ItemUpgrade_ExitPackageSelectionMode()
	DC.Debug("ExitPackageSelectionMode: Starting");
	DC.inPackageSelectionMode = false;
	DC.pendingStatPackage = nil;
	
	local frame = DarkChaos_ItemUpgradeFrame;
	local selector = DC.StatPackageSelector;
	
	if not frame then 
		DC.Debug("ExitPackageSelectionMode: No frame found!");
		return; 
	end
	
	-- Hide the package selector
	if selector then
		DC.Debug("ExitPackageSelectionMode: Hiding selector");
		selector:Hide();
	else
		DC.Debug("ExitPackageSelectionMode: No selector found!");
	end
	
	-- Restore title
	if frame.TitleText then
		frame.TitleText:SetText("Heirloom Upgrade");
	end
	
	-- Show background UI elements again
	DC.Debug("ExitPackageSelectionMode: Showing UI elements");
	if frame.ItemSlot then frame.ItemSlot:Show(); end
	if frame.ItemInfo then frame.ItemInfo:Show(); end
	if frame.CostFrame then frame.CostFrame:Show(); end
	if frame.UpgradeButton then frame.UpgradeButton:Show(); end
	if frame.PlayerCurrencies then frame.PlayerCurrencies:Show(); end
	-- Note: CurrentPanel, UpgradePanel, tooltips, etc. will be shown/hidden by UpdateUI based on state
	
	-- Refresh the full UI (this will properly show/hide elements based on current item state)
	DC.isChangingPackage = false;
	DC.Debug("ExitPackageSelectionMode: Calling UpdateUI");
	DarkChaos_ItemUpgrade_UpdateUI();
	DC.Debug("ExitPackageSelectionMode: Done");
end

--[[=====================================================
	PACKAGE PREVIEW & CONFIRMATION
=======================================================]]

function DarkChaos_ItemUpgrade_PreviewStatPackage(packageId)
	if not packageId or not DC.STAT_PACKAGES[packageId] then
		return;
	end
	
	DC.pendingStatPackage = packageId;
	
	local selector = DC.StatPackageSelector;
	if not selector then return; end
	
	-- Update row highlights
	DarkChaos_ItemUpgrade_UpdatePackageList();
	
	-- Update preview text
	local pkg = DC.STAT_PACKAGES[packageId];
	local colorHex = string.format("%.2x%.2x%.2x", pkg.color.r*255, pkg.color.g*255, pkg.color.b*255);
	
	local statsPreview = "";
	local lvl1Stats = DarkChaos_ItemUpgrade_GetPackageStatsAtLevel(packageId, 1);
	local lvl15Stats = DarkChaos_ItemUpgrade_GetPackageStatsAtLevel(packageId, 15);
	if lvl1Stats and lvl15Stats then
		local parts = {};
		for i, stat in ipairs(lvl1Stats) do
			local maxVal = lvl15Stats[i] and lvl15Stats[i].value or stat.value;
			table.insert(parts, string.format("%s: %d to %d", stat.name, stat.value, maxVal));
		end
		statsPreview = table.concat(parts, "  |  ");
	end
	
	if selector.PreviewText then
		selector.PreviewText:SetText(string.format("|cff%s%s|r  -  %s", colorHex, pkg.name, statsPreview));
	end
	
	-- Enable confirm button
	if selector.ConfirmButton then
		selector.ConfirmButton:Enable();
	end
	
	-- Play sound
	DC.PlaySound("igMainMenuOptionCheckBoxOn");
end

function DarkChaos_ItemUpgrade_ConfirmPackageSelection()
	local packageId = DC.pendingStatPackage;
	DC.Debug("ConfirmPackageSelection called, pendingStatPackage=" .. tostring(packageId));
	
	if not packageId or not DC.STAT_PACKAGES[packageId] then
		DC.Debug("ConfirmPackageSelection: Invalid packageId, aborting");
		return;
	end
	
	local previousPackage = DC.selectedStatPackage;
	local pkg = DC.STAT_PACKAGES[packageId];
	DC.Debug("ConfirmPackageSelection: Applying package " .. pkg.name);
	
	-- Check if changing package (reset upgrade level)
	if DC.isChangingPackage and previousPackage and previousPackage ~= packageId then
		DC.targetUpgradeLevel = 1;
		-- Reset current item's upgrade level since server will reset it
		if DC.currentItem then
			DC.currentItem.currentUpgrade = 0;
			DC.currentItem.heirloomPackageLevel = 0;
		end
		DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff8800[DC-ItemUpgrade]|r Package changed from %s to |cff%.2x%.2x%.2x%s|r - upgrade level reset to 1.",
			DC.STAT_PACKAGES[previousPackage].name,
			pkg.color.r*255, pkg.color.g*255, pkg.color.b*255, pkg.name));
	else
		DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ccff[DC-ItemUpgrade]|r Selected |cff%.2x%.2x%.2x%s|r package.", 
			pkg.color.r*255, pkg.color.g*255, pkg.color.b*255, pkg.name));
	end
	
	-- Apply the selection
	DC.selectedStatPackage = packageId;
	DC.pendingStatPackage = nil;
	
	-- Save the selection to per-character settings
	if DarkChaos_ItemUpgrade_SaveCharSettings then
		DarkChaos_ItemUpgrade_SaveCharSettings();
	end
	
	-- Send to server
	DarkChaos_ItemUpgrade_SendPackageSelection(packageId);
	
	-- Play confirmation sound
	DC.PlaySound("GAMEGENERICBUTTONPRESS");
	
	-- Exit package selection mode and show upgrade UI
	DC.Debug("ConfirmPackageSelection: Calling ExitPackageSelectionMode");
	DarkChaos_ItemUpgrade_ExitPackageSelectionMode();
	DC.Debug("ConfirmPackageSelection: Done, inPackageSelectionMode=" .. tostring(DC.inPackageSelectionMode));
end

function DarkChaos_ItemUpgrade_SendPackageSelection(packageId)
	if not packageId then return end
	
	-- Try DCAddonProtocol first (new C++ backend)
	if DCProtocol and DCProtocol.Upgrade and DCProtocol.Upgrade.SelectPackage then
		DCProtocol.Upgrade.SelectPackage(packageId)
		DC.Debug("Sent package selection via DCAddonProtocol: " .. packageId)
		return
	end
	
	-- Fallback to old addon message format (for compatibility)
	local message = string.format("DCUPGRADE:PACKAGE:%d", packageId);
	
	if ChatThrottleLib then
		ChatThrottleLib:SendAddonMessage("NORMAL", "DCUPGRADE", message, "WHISPER", UnitName("player"));
	else
		SendAddonMessage("DCUPGRADE", message, "WHISPER", UnitName("player"));
	end
	
	DC.Debug("Sent package selection (fallback): " .. message);
end

function DarkChaos_ItemUpgrade_UpdateStatPackageSelector()
	local frame = DarkChaos_ItemUpgradeFrame;
	if not frame then return end
	
	-- Create Change Package button if not exists
	DarkChaos_ItemUpgrade_CreateChangePackageButton(frame);
	
	-- Check if we're in heirloom mode with item 300365
	local isHeirloomShirt = false;
	local detectedItemID = nil;
	if DC.uiMode == "HEIRLOOM" and DC.currentItem and DC.currentItem.link then
		detectedItemID = tonumber(DC.currentItem.link:match("item:(%d+)"));
		isHeirloomShirt = (detectedItemID == 300365);
	end
	
	-- Only process if we actually have the heirloom shirt selected
	-- Skip this function entirely if no item is selected yet
	if DC.uiMode == "HEIRLOOM" and not DC.currentItem then
		-- No item selected yet, just hide everything and wait
		if DC.StatPackageSelector then DC.StatPackageSelector:Hide(); end
		if frame.ChangePackageButton then frame.ChangePackageButton:Hide(); end
		return;
	end
	
	-- If in package selection mode, keep the selector visible
	if DC.inPackageSelectionMode then
		if DC.StatPackageSelector then
			DC.StatPackageSelector:Show();
		end
		if frame.ChangePackageButton then
			frame.ChangePackageButton:Hide();
		end
		return;
	end
	
	-- If heirloom shirt but no package selected, enter package selection mode
	if isHeirloomShirt and not DC.selectedStatPackage then
		DarkChaos_ItemUpgrade_EnterPackageSelectionMode(false);
		return;
	end
	
	-- Normal upgrade screen - hide selector, show change package button
	if DC.StatPackageSelector then
		DC.StatPackageSelector:Hide();
	end
	
	if isHeirloomShirt and frame.ChangePackageButton then
		frame.ChangePackageButton:Show();
	elseif frame.ChangePackageButton then
		frame.ChangePackageButton:Hide();
	end
end

--[[=====================================================
	STAT CALCULATION
=======================================================]]

function DarkChaos_ItemUpgrade_GetPackageStatsAtLevel(packageId, level)
	local pkg = DC.STAT_PACKAGES[packageId];
	if not pkg then return nil end
	
	local totalBudget = DC.STAT_PACKAGE_LEVEL_VALUES[level] or 0;
	local numStats = #pkg.stats;
	if numStats == 0 then return {} end
	
	local perStat = math.floor(totalBudget / numStats);
	local remainder = totalBudget - (perStat * numStats);
	
	local result = {};
	for i, statName in ipairs(pkg.stats) do
		local value = perStat;
		if i <= remainder then
			value = value + 1;
		end
		table.insert(result, { name = statName, value = value });
	end
	
	return result;
end

--[[=====================================================
	HEIRLOOM UPGRADE COMMAND
=======================================================]]

function DarkChaos_ItemUpgrade_PerformHeirloomUpgrade(item, targetLevel)
	if not item then return end
	
	local currentUpgrade = item.currentUpgrade or 0;
	local maxUpgrade = item.maxUpgrade or 15;
	
	if currentUpgrade >= maxUpgrade then
		print("|cffff0000Item is already at maximum level.|r");
		return;
	end
	
	if not DC.selectedStatPackage then
		print("|cffff0000Please select a stat package first!|r");
		return;
	end
	
	local serverBag = item.serverBag or item.bag;
	local serverSlot = item.serverSlot or math.max(0, (item.slot or 1) - 1);
	
	local command = string.format(".dcheirloom upgrade %d %d %d %d", 
		serverBag, serverSlot, targetLevel, DC.selectedStatPackage);
	
	DC.pendingUpgrade = {
		target = targetLevel,
		startLevel = currentUpgrade,
		bag = serverBag,
		slot = item.slot,
		serverSlot = serverSlot,
		packageId = DC.selectedStatPackage,
		isHeirloom = true,
	};
	
	DC.Debug("Sending heirloom upgrade: " .. command);
	SendChatMessage(command, "SAY");
end
