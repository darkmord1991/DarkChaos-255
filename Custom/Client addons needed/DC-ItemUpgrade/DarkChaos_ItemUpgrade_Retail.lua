--[[
	DC-ItemUpgrade - Retail 11.2.7 Backport for WoW 3.3.5a
	Based on: Blizzard_ItemUpgradeUI (11.2.7.64169)
	Adapted for: AzerothCore 3.3.5a with Eluna server communication
--]]

-- Global namespace
DarkChaos_ItemUpgrade = {};
local DC = DarkChaos_ItemUpgrade;

-- 3.3.5a Compatibility Helper
local function SetButtonEnabled(button, enabled)
	if enabled then
		button:Enable();
	else
		button:Disable();
	end
end

-- 3.3.5a: SetItemButtonQuality replacement
local function SetItemButtonQuality_335(button, quality)
	local color = DC.ITEM_QUALITY_COLORS[quality] or DC.ITEM_QUALITY_COLORS[1];
	if color then
		-- Try to get the border texture by name
		local borderTexture = _G[button:GetName().."NormalTexture"];
		if borderTexture then
			borderTexture:SetVertexColor(color.r, color.g, color.b);
		end
	end
end

-- Constants
DC.MAX_UPGRADE_LEVEL = 15;
DC.ITEM_QUALITY_COLORS = {
	[0] = {r=0.55, g=0.55, b=0.55}, -- Poor (gray)
	[1] = {r=1.00, g=1.00, b=1.00}, -- Common (white)
	[2] = {r=0.12, g=1.00, b=0.00}, -- Uncommon (green)
	[3] = {r=0.00, g=0.44, b=0.87}, -- Rare (blue)
	[4] = {r=0.64, g=0.21, b=0.93}, -- Epic (purple)
	[5] = {r=1.00, g=0.50, b=0.00}, -- Legendary (orange)
};

-- State
DC.currentItem = nil; -- {bag, slot, link, itemID, quality, name, level, tier, currentUpgrade, maxUpgrade}
DC.targetUpgradeLevel = 1;
DC.playerTokens = 0;
DC.playerEssence = 0;
DC.upgradeAnimationTime = 0;
DC.arrowAnimationTime = 0;
DC.glowAnimationTime = 0;

-- Upgrade costs (from database, cached client-side)
DC.upgradeCosts = {}; -- [tier][level] = {tokens, essence}

--[[=====================================================
	INITIALIZATION
=======================================================]]

function DarkChaos_ItemUpgrade_OnLoad(self)
	self:RegisterEvent("CHAT_MSG_SAY");
	self:RegisterEvent("CHAT_MSG_WHISPER");
	self:RegisterEvent("CHAT_MSG_SYSTEM");
	self:RegisterEvent("BAG_UPDATE");
	self:RegisterEvent("PLAYER_LOGIN");

	-- Slash command: /dcupgrade [debug]
	SLASH_DCUPGRADE1 = "/dcupgrade";
	SlashCmdList["DCUPGRADE"] = function(msg)
		msg = (msg or ""):lower();
		if msg == "debug" or msg == "dbg" then
			DC_ItemUpgrade_Settings = DC_ItemUpgrade_Settings or {};
			DC_ItemUpgrade_Settings.debug = not DC_ItemUpgrade_Settings.debug;
			print("|cffffd700DC-ItemUpgrade debug " .. (DC_ItemUpgrade_Settings.debug and "ON" or "OFF") .. "|r");
			return;
		end
		if not DarkChaos_ItemUpgradeFrame:IsShown() then
			DarkChaos_ItemUpgradeFrame:Show();
		else
			DarkChaos_ItemUpgradeFrame:Hide();
		end
	end
	
	-- Set title
	self.title:SetText("Item Upgrade");
	
	-- Set portrait (use item upgrade icon)
	SetPortraitToTexture(self.portrait, "Interface\\Icons\\INV_Misc_Coin_01");
	
	-- Initialize dropdown
	UIDropDownMenu_Initialize(self.ItemInfo.Dropdown, DarkChaos_ItemUpgrade_Dropdown_Initialize);
	UIDropDownMenu_SetWidth(self.ItemInfo.Dropdown, 95);
	UIDropDownMenu_SetButtonWidth(self.ItemInfo.Dropdown, 110);
	
	-- Make frame movable
	self:SetMovable(true);
	self:EnableMouse(true);
	self:RegisterForDrag("LeftButton");
	self:SetScript("OnDragStart", function(frame) frame:StartMoving() end);
	self:SetScript("OnDragStop", function(frame) frame:StopMovingOrSizing() end);
	
	-- Hide tooltips initially
	self.LeftTooltip:Hide();
	self.RightTooltip:Hide();
	
	print("|cff00ff00DC-ItemUpgrade|r loaded. Type |cffffcc00/dcupgrade|r to open.");
end

function DarkChaos_ItemUpgrade_OnShow(self)
	PlaySound("igCharacterInfoOpen");
	
	-- Request currency update from server
	SendChatMessage(".dcupgrade init", "SAY");
	
	-- Update UI
	DarkChaos_ItemUpgrade_UpdateUI();
end

function DarkChaos_ItemUpgrade_OnHide(self)
	PlaySound("igCharacterInfoClose");
	
	-- Close item browser if open
	if DarkChaos_ItemBrowserFrame:IsShown() then
		DarkChaos_ItemBrowserFrame:Hide();
	end
end

function DarkChaos_ItemUpgrade_OnEvent(self, event, ...)
	if event == "PLAYER_LOGIN" then
		-- Initialize upgrade costs cache
		DarkChaos_ItemUpgrade_InitializeCosts();

		-- Install chat filters to hide DCUPGRADE_* unless debug enabled
		if ChatFrame_AddMessageEventFilter and not _G.__DC_ItemUpgrade_RetailFilterInstalled then
			local function DC_ItemUpgrade_Filter(frame, ev, msg, ...)
				if type(msg) == "string" and string.find(msg, "^DCUPGRADE_") then
					local dbg = DC_ItemUpgrade_Settings and DC_ItemUpgrade_Settings.debug;
					if not dbg then return true end
				end
				return false
			end
			ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", DC_ItemUpgrade_Filter);
			ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", DC_ItemUpgrade_Filter);
			_G.__DC_ItemUpgrade_RetailFilterInstalled = true;
		end
		
	elseif event == "CHAT_MSG_SAY" or event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_SYSTEM" then
		local message, sender = ...;
		DarkChaos_ItemUpgrade_OnChatMessage(message, sender);
		
	elseif event == "BAG_UPDATE" then
		-- Update item browser if open
		if DarkChaos_ItemBrowserFrame:IsShown() then
			DarkChaos_ItemBrowser_Update();
		end
	end
end

function DarkChaos_ItemUpgrade_OnUpdate(self, elapsed)
	-- Arrow animation (bounce left-right)
	if self.Arrow:IsShown() then
		DC.arrowAnimationTime = DC.arrowAnimationTime + elapsed;
		local cycle = DC.arrowAnimationTime % 2.0; -- 2 second cycle
		
		if cycle < 1.0 then
			-- Move right, fade in
			local progress = cycle;
			local offset = progress * 25;
			local alpha = math.min(1.0, progress * 2);
			self.Arrow:SetPoint("CENTER", self.LeftTooltip, "RIGHT", 8 + offset, 0);
			self.Arrow.Texture:SetAlpha(alpha);
		else
			-- Fade out
			local progress = cycle - 1.0;
			local alpha = math.max(0, 1.0 - progress * 2);
			self.Arrow.Texture:SetAlpha(alpha);
		end
	end
	
	-- Button glow pulse
	if self.UpgradeButton:IsEnabled() and self.UpgradeButton.Glow:IsShown() then
		DC.glowAnimationTime = DC.glowAnimationTime + elapsed;
		local alpha = 0.5 + math.sin(DC.glowAnimationTime * 2) * 0.3;
		self.UpgradeButton.Glow:SetAlpha(alpha);
	end
	
	-- Upgrade celebration animation
	if DC.upgradeAnimationTime > 0 then
		DC.upgradeAnimationTime = DC.upgradeAnimationTime - elapsed;
		
		if DC.upgradeAnimationTime <= 0 then
			-- Animation complete, update UI
			DarkChaos_ItemUpgrade_UpdateUI();
		end
	end
end

--[[=====================================================
	ITEM SLOT HANDLERS
=======================================================]]

function DarkChaos_ItemUpgrade_ItemSlot_OnEnter(self)
	if DC.currentItem then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetHyperlink(DC.currentItem.link);
		GameTooltip:Show();
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText("Item Upgrade Slot", 1, 1, 1);
		GameTooltip:AddLine("Click to select an item from your bags.", 0.8, 0.8, 0.8, true);
		GameTooltip:AddLine("Right-click to clear.", 0.8, 0.8, 0.8, true);
		GameTooltip:Show();
	end
end

function DarkChaos_ItemUpgrade_ItemSlot_OnClick(self, button)
	if button == "RightButton" then
		-- Clear item
		DarkChaos_ItemUpgrade_ClearItem();
		return;
	end
	
	-- Open item browser
	DarkChaos_ItemUpgrade_BrowseButton_OnClick();
end

function DarkChaos_ItemUpgrade_ItemSlot_OnDrag(self)
	if CursorHasItem() then
		-- Item from cursor
		local itemType, itemID, itemLink = GetCursorInfo();
		if itemType == "item" then
			DarkChaos_ItemUpgrade_SelectItemFromLink(itemLink);
			ClearCursor();
		end
	end
end

--[[=====================================================
	BUTTON HANDLERS
=======================================================]]

function DarkChaos_ItemUpgrade_UpgradeButton_OnClick(self)
	if not DC.currentItem then
		return;
	end
	
	-- Get cost for target level
	local cost = DarkChaos_ItemUpgrade_GetCost(DC.currentItem.tier, DC.targetUpgradeLevel);
	if not cost then
		print("|cffff0000Error:|r Could not determine upgrade cost.");
		return;
	end
	
	-- Check if player has enough currency
	if DC.playerTokens < cost.tokens then
		print("|cffff0000Not enough Upgrade Tokens!|r You need " .. cost.tokens .. " but have " .. DC.playerTokens .. ".");
		return;
	end
	
	if DC.playerEssence < cost.essence then
		print("|cffff0000Not enough Artifact Essence!|r You need " .. cost.essence .. " but have " .. DC.playerEssence .. ".");
		return;
	end
	
	-- Disable button during upgrade
	SetButtonEnabled(self, false);
	self.Glow:Hide();
	
	-- Send upgrade command to server
	local command = string.format(".dcupgrade perform %d %d %d", 
		DC.currentItem.bag, 
		DC.currentItem.slot, 
		DC.targetUpgradeLevel
	);
	SendChatMessage(command, "SAY");
	
	print("|cff00ff00Upgrading item...|r");
end

function DarkChaos_ItemUpgrade_CancelButton_OnClick(self)
	-- Close item browser
	DarkChaos_ItemBrowserFrame:Hide();
end

function DarkChaos_ItemUpgrade_BrowseButton_OnClick(self)
	-- Toggle item browser
	if DarkChaos_ItemBrowserFrame:IsShown() then
		DarkChaos_ItemBrowserFrame:Hide();
	else
		DarkChaos_ItemBrowserFrame:Show();
	end
end

--[[=====================================================
	DROPDOWN (LEVEL SELECTOR)
=======================================================]]

function DarkChaos_ItemUpgrade_Dropdown_Initialize()
	if not DC.currentItem then
		return;
	end
	
	local info = UIDropDownMenu_CreateInfo();
	
	for level = 1, DC.MAX_UPGRADE_LEVEL do
		-- Skip levels already reached
		if level > DC.currentItem.currentUpgrade then
			info.text = "Level " .. level .. " / " .. DC.MAX_UPGRADE_LEVEL;
			info.value = level;
			info.func = DarkChaos_ItemUpgrade_Dropdown_OnClick;
			info.checked = (level == DC.targetUpgradeLevel);
			
			-- Color red if can't afford
			local cost = DarkChaos_ItemUpgrade_GetCost(DC.currentItem.tier, level);
			if cost and (DC.playerTokens < cost.tokens or DC.playerEssence < cost.essence) then
				info.colorCode = "|cffff3333";
			else
				info.colorCode = "|cffffffff";
			end
			
			UIDropDownMenu_AddButton(info);
		end
	end
end

function DarkChaos_ItemUpgrade_Dropdown_OnClick(self)
	DC.targetUpgradeLevel = self.value;
	UIDropDownMenu_SetSelectedValue(DarkChaos_ItemUpgradeFrame.ItemInfo.Dropdown, self.value);
	
	-- Update tooltips and costs
	DarkChaos_ItemUpgrade_UpdateUI();
end

--[[=====================================================
	ITEM SELECTION
=======================================================]]

function DarkChaos_ItemUpgrade_SelectItemFromLink(itemLink)
	-- Parse item link (format: |cffXXXXXX|Hitem:itemID:...|h[Name]|h|r)
	local _, _, itemID = string.find(itemLink, "item:(%d+)");
	itemID = tonumber(itemID);
	
	if not itemID then
		print("|cffff0000Invalid item link.|r");
		return;
	end
	
	-- Find item in bags
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot);
			if link and link == itemLink then
				DarkChaos_ItemUpgrade_SelectItemBySlot(bag, slot);
				return;
			end
		end
	end
	
	print("|cffff0000Item not found in bags.|r");
end

function DarkChaos_ItemUpgrade_SelectItemBySlot(bag, slot)
	local link = GetContainerItemLink(bag, slot);
	if not link then
		return;
	end
	
	-- Parse item info
	local name, _, quality, level = GetItemInfo(link);
	local _, _, _, _, itemID = string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?");
	itemID = tonumber(itemID);
	
	-- Store item data
	DC.currentItem = {
		bag = bag,
		slot = slot,
		link = link,
		itemID = itemID,
		quality = quality,
		name = name,
		level = level,
		tier = 1, -- Default tier (will be updated by server)
		currentUpgrade = 0, -- Will be updated by server
		maxUpgrade = DC.MAX_UPGRADE_LEVEL,
	};
	
	-- Set initial target upgrade level
	DC.targetUpgradeLevel = 1;
	
	-- Request item info from server
	local command = string.format(".dcupgrade query %d %d", bag, slot);
	SendChatMessage(command, "SAY");
	
	-- Update UI (will show loading state)
	DarkChaos_ItemUpgrade_UpdateUI();
	
	-- Close item browser
	if DarkChaos_ItemBrowserFrame:IsShown() then
		DarkChaos_ItemBrowserFrame:Hide();
	end
end

function DarkChaos_ItemUpgrade_ClearItem()
	DC.currentItem = nil;
	DC.targetUpgradeLevel = 1;
	DarkChaos_ItemUpgrade_UpdateUI();
end

--[[=====================================================
	UI UPDATE
=======================================================]]

function DarkChaos_ItemUpgrade_UpdateUI()
	local frame = DarkChaos_ItemUpgradeFrame;
	
	if not DC.currentItem then
		-- No item selected
		frame.ItemSlot.EmptyGlow:Show();
		SetItemButtonTexture(frame.ItemSlot, nil);
		-- 3.3.5a: Set normal texture directly instead of using SetItemButtonNormalTexture
		_G[frame.ItemSlot:GetName().."NormalTexture"]:SetTexture("Interface\\Buttons\\UI-Quickslot2");
		
		-- Hide all item-specific UI
		frame.ItemInfo.MissingItemText:Show();
		frame.ItemInfo.ItemName:Hide();
		frame.ItemInfo.UpgradeProgress:Hide();
		frame.ItemInfo.UpgradeToLabel:Hide();
		frame.ItemInfo.Dropdown:Hide();
		frame.LeftTooltip:Hide();
		frame.RightTooltip:Hide();
		frame.Arrow:Hide();
		frame.CostFrame:Hide();
		frame.PlayerCurrencies:Show();
		SetButtonEnabled(frame.UpgradeButton, false);
		frame.UpgradeButton.Glow:Hide();
		frame.MissingDescription:Show();
		frame.ErrorText:Hide();
		
		-- Update player currencies
		DarkChaos_ItemUpgrade_UpdatePlayerCurrencies();
		
		return;
	end
	
	-- Item is selected
	frame.ItemSlot.EmptyGlow:Hide();
	frame.MissingDescription:Hide();
	
	-- Set item icon and quality border
	local texture = GetContainerItemInfo(DC.currentItem.bag, DC.currentItem.slot);
	SetItemButtonTexture(frame.ItemSlot, texture);
	
	local color = DC.ITEM_QUALITY_COLORS[DC.currentItem.quality] or DC.ITEM_QUALITY_COLORS[1];
	frame.ItemSlot:GetNormalTexture():SetVertexColor(color.r, color.g, color.b);
	
	-- Update item info
	frame.ItemInfo.MissingItemText:Hide();
	frame.ItemInfo.ItemName:Show();
	frame.ItemInfo.ItemName:SetText(DC.currentItem.name);
	frame.ItemInfo.ItemName:SetTextColor(color.r, color.g, color.b);
	
	frame.ItemInfo.UpgradeProgress:Show();
	frame.ItemInfo.UpgradeProgress:SetText(string.format("Upgrade %d/%d | Item Level %d",
		DC.currentItem.currentUpgrade,
		DC.currentItem.maxUpgrade,
		DC.currentItem.level
	));
	
	-- Show dropdown if item can be upgraded
	if DC.currentItem.currentUpgrade < DC.currentItem.maxUpgrade then
		frame.ItemInfo.UpgradeToLabel:Show();
		frame.ItemInfo.Dropdown:Show();
		
		-- Set dropdown text
		UIDropDownMenu_SetText(frame.ItemInfo.Dropdown, "Level " .. DC.targetUpgradeLevel);
		
		-- Generate tooltips
		DarkChaos_ItemUpgrade_GenerateTooltips();
		
		-- Show cost
		DarkChaos_ItemUpgrade_UpdateCost();
		
		-- Show arrow animation
		frame.Arrow:Show();
		
		-- Enable/disable upgrade button
		local cost = DarkChaos_ItemUpgrade_GetCost(DC.currentItem.tier, DC.targetUpgradeLevel);
		if cost and DC.playerTokens >= cost.tokens and DC.playerEssence >= cost.essence then
			SetButtonEnabled(frame.UpgradeButton, true);
			frame.UpgradeButton.Glow:Show();
			frame.UpgradeButton.disabledTooltip = nil;
		else
			SetButtonEnabled(frame.UpgradeButton, false);
			frame.UpgradeButton.Glow:Hide();
			if cost then
				frame.UpgradeButton.disabledTooltip = "Not enough currency.";
			else
				frame.UpgradeButton.disabledTooltip = "Cannot determine cost.";
			end
		end
		
		frame.ErrorText:Hide();
	else
		-- Item is maxed out
		frame.ItemInfo.UpgradeToLabel:Hide();
		frame.ItemInfo.Dropdown:Hide();
		frame.LeftTooltip:Show();
		frame.RightTooltip:Hide();
		frame.Arrow:Hide();
		frame.CostFrame:Hide();
		SetButtonEnabled(frame.UpgradeButton, false);
		frame.UpgradeButton.Glow:Hide();
		frame.UpgradeButton.disabledTooltip = "Item is fully upgraded.";
		
		frame.ErrorText:SetText("This item is already at maximum upgrade level.");
		frame.ErrorText:Show();
		
		-- Show current item tooltip
		DarkChaos_ItemUpgrade_GenerateCurrentTooltip();
	end
	
	-- Update player currencies
	DarkChaos_ItemUpgrade_UpdatePlayerCurrencies();
end

function DarkChaos_ItemUpgrade_UpdatePlayerCurrencies()
	local frame = DarkChaos_ItemUpgradeFrame.PlayerCurrencies;
	frame.TokenCount:SetText(DC.playerTokens);
	frame.EssenceCount:SetText(DC.playerEssence);
end

function DarkChaos_ItemUpgrade_UpdateCost()
	local frame = DarkChaos_ItemUpgradeFrame.CostFrame;
	local cost = DarkChaos_ItemUpgrade_GetCost(DC.currentItem.tier, DC.targetUpgradeLevel);
	
	if not cost then
		frame:Hide();
		return;
	end
	
	frame:Show();
	
	-- Set token cost
	if DC.playerTokens >= cost.tokens then
		frame.TokenCost:SetText(cost.tokens);
		frame.TokenCost:SetTextColor(1, 1, 1);
	else
		frame.TokenCost:SetText(cost.tokens);
		frame.TokenCost:SetTextColor(1, 0.1, 0.1);
	end
	
	-- Set essence cost (only show for Tier 5)
	if cost.essence > 0 then
		frame.EssenceIcon:Show();
		frame.EssenceCost:Show();
		
		if DC.playerEssence >= cost.essence then
			frame.EssenceCost:SetText(cost.essence);
			frame.EssenceCost:SetTextColor(1, 1, 1);
		else
			frame.EssenceCost:SetText(cost.essence);
			frame.EssenceCost:SetTextColor(1, 0.1, 0.1);
		end
	else
		frame.EssenceIcon:Hide();
		frame.EssenceCost:Hide();
	end
end

--[[=====================================================
	TOOLTIP GENERATION
=======================================================]]

function DarkChaos_ItemUpgrade_GenerateCurrentTooltip()
	local tooltip = DarkChaos_ItemUpgradeFrame.LeftTooltip;
	tooltip:SetOwner(DarkChaos_ItemUpgradeFrame, "ANCHOR_NONE");
	tooltip:ClearLines();
	tooltip:SetHyperlink(DC.currentItem.link);
	
	-- Add upgrade level info
	tooltip:AddLine(" ");
	tooltip:AddLine(string.format("Current Upgrade: %d/%d", DC.currentItem.currentUpgrade, DC.currentItem.maxUpgrade), 0.8, 0.8, 0.8);
	
	-- Set border color
	local color = DC.ITEM_QUALITY_COLORS[DC.currentItem.quality] or DC.ITEM_QUALITY_COLORS[1];
	tooltip.BorderTop:SetVertexColor(color.r, color.g, color.b);
	tooltip.BorderBottom:SetVertexColor(color.r, color.g, color.b);
	
	tooltip:Show();
end

function DarkChaos_ItemUpgrade_GenerateTooltips()
	-- Left tooltip: Current item
	DarkChaos_ItemUpgrade_GenerateCurrentTooltip();
	
	-- Right tooltip: Upgraded item (simulated)
	local tooltip = DarkChaos_ItemUpgradeFrame.RightTooltip;
	tooltip:SetOwner(DarkChaos_ItemUpgradeFrame, "ANCHOR_NONE");
	tooltip:ClearLines();
	tooltip:SetHyperlink(DC.currentItem.link);
	
	-- Calculate stat increases
	local levels = DC.targetUpgradeLevel - DC.currentItem.currentUpgrade;
	local statIncrease = levels * 2; -- 2% per level (from database schema)
	local iLevelIncrease = levels * 3; -- 3 iLevels per upgrade (from database schema)
	
	-- Add upgrade preview info
	tooltip:AddLine(" ");
	tooltip:AddLine("After Upgrade:", 0.2, 1.0, 0.2);
	tooltip:AddLine(string.format("Upgrade Level: %d/%d |cff00ff00(+%d)|r", 
		DC.targetUpgradeLevel, 
		DC.currentItem.maxUpgrade,
		levels
	), 1, 1, 1);
	tooltip:AddLine(string.format("Item Level: %d |cff00ff00(+%d)|r", 
		DC.currentItem.level + iLevelIncrease,
		iLevelIncrease
	), 1, 1, 1);
	tooltip:AddLine(string.format("Stats: +%d%%", statIncrease), 0.2, 1.0, 0.2);
	
	-- Set border color (use next quality if available)
	local nextQuality = math.min(DC.currentItem.quality + math.floor(levels / 3), 5);
	local color = DC.ITEM_QUALITY_COLORS[nextQuality] or DC.ITEM_QUALITY_COLORS[DC.currentItem.quality];
	tooltip.BorderTop:SetVertexColor(color.r, color.g, color.b);
	tooltip.BorderBottom:SetVertexColor(color.r, color.g, color.b);
	
	tooltip:Show();
end

--[[=====================================================
	UPGRADE COSTS
=======================================================]]

function DarkChaos_ItemUpgrade_InitializeCosts()
	-- Initialize cost table from database schema
	-- Tier 1: 5-30 tokens
	DC.upgradeCosts[1] = {
		[1]={tokens=5,essence=0}, [2]={tokens=5,essence=0}, [3]={tokens=5,essence=0},
		[4]={tokens=10,essence=0}, [5]={tokens=10,essence=0}, [6]={tokens=10,essence=0},
		[7]={tokens=15,essence=0}, [8]={tokens=15,essence=0}, [9]={tokens=15,essence=0},
		[10]={tokens=20,essence=0}, [11]={tokens=20,essence=0}, [12]={tokens=20,essence=0},
		[13]={tokens=25,essence=0}, [14]={tokens=25,essence=0}, [15]={tokens=30,essence=0},
	};
	
	-- Tier 2: 10-35 tokens
	DC.upgradeCosts[2] = {
		[1]={tokens=10,essence=0}, [2]={tokens=10,essence=0}, [3]={tokens=10,essence=0},
		[4]={tokens=15,essence=0}, [5]={tokens=15,essence=0}, [6]={tokens=15,essence=0},
		[7]={tokens=20,essence=0}, [8]={tokens=20,essence=0}, [9]={tokens=20,essence=0},
		[10]={tokens=25,essence=0}, [11]={tokens=25,essence=0}, [12]={tokens=25,essence=0},
		[13]={tokens=30,essence=0}, [14]={tokens=30,essence=0}, [15]={tokens=35,essence=0},
	};
	
	-- Tier 3: 15-40 tokens
	DC.upgradeCosts[3] = {
		[1]={tokens=15,essence=0}, [2]={tokens=15,essence=0}, [3]={tokens=15,essence=0},
		[4]={tokens=20,essence=0}, [5]={tokens=20,essence=0}, [6]={tokens=20,essence=0},
		[7]={tokens=25,essence=0}, [8]={tokens=25,essence=0}, [9]={tokens=25,essence=0},
		[10]={tokens=30,essence=0}, [11]={tokens=30,essence=0}, [12]={tokens=30,essence=0},
		[13]={tokens=35,essence=0}, [14]={tokens=35,essence=0}, [15]={tokens=40,essence=0},
	};
	
	-- Tier 4: 20-50 tokens
	DC.upgradeCosts[4] = {
		[1]={tokens=20,essence=0}, [2]={tokens=20,essence=0}, [3]={tokens=20,essence=0},
		[4]={tokens=25,essence=0}, [5]={tokens=25,essence=0}, [6]={tokens=25,essence=0},
		[7]={tokens=30,essence=0}, [8]={tokens=30,essence=0}, [9]={tokens=30,essence=0},
		[10]={tokens=35,essence=0}, [11]={tokens=35,essence=0}, [12]={tokens=35,essence=0},
		[13]={tokens=40,essence=0}, [14]={tokens=40,essence=0}, [15]={tokens=50,essence=0},
	};
	
	-- Tier 5: 30-60 tokens + 10-40 essence
	DC.upgradeCosts[5] = {
		[1]={tokens=30,essence=10}, [2]={tokens=30,essence=10}, [3]={tokens=30,essence=10},
		[4]={tokens=35,essence=15}, [5]={tokens=35,essence=15}, [6]={tokens=35,essence=15},
		[7]={tokens=40,essence=20}, [8]={tokens=40,essence=20}, [9]={tokens=40,essence=20},
		[10]={tokens=45,essence=25}, [11]={tokens=45,essence=25}, [12]={tokens=45,essence=25},
		[13]={tokens=50,essence=30}, [14]={tokens=50,essence=30}, [15]={tokens=60,essence=40},
	};
end

function DarkChaos_ItemUpgrade_GetCost(tier, level)
	if not DC.upgradeCosts[tier] or not DC.upgradeCosts[tier][level] then
		return nil;
	end
	return DC.upgradeCosts[tier][level];
end

--[[=====================================================
	SERVER COMMUNICATION
=======================================================]]

function DarkChaos_ItemUpgrade_OnChatMessage(message, sender)
	-- Only process messages from self (server responses)
	if sender ~= UnitName("player") then
		return;
	end
	
	-- DCUPGRADE_INIT response (player currencies)
	-- Format from server: "DCUPGRADE_INIT:<tokens>:<essence>"
	if string.find(message, "^DCUPGRADE_INIT") then
		local _, _, tokens, essence = string.find(message, "DCUPGRADE_INIT:(%d+):(%d+)");
		DC.playerTokens = tonumber(tokens) or 0;
		DC.playerEssence = tonumber(essence) or 0;
		DarkChaos_ItemUpgrade_UpdatePlayerCurrencies();
		print(string.format("|cff00ff00You have %d Upgrade Tokens and %d Artifact Essence.|r", DC.playerTokens, DC.playerEssence));
		return;
	end
	
	-- DCUPGRADE_QUERY response (item upgrade info)
	-- Format from server: "DCUPGRADE_QUERY:<item_guid>:<upgrade_level>:<tier>:<base_ilvl>"
	if string.find(message, "^DCUPGRADE_QUERY") then
		local _, _, itemGUID, currentLevel, tier, baseIlvl = string.find(message, "DCUPGRADE_QUERY:(%d+):(%d+):(%d+):(%d+)");
		if DC.currentItem then
			DC.currentItem.tier = tonumber(tier) or 1;
			DC.currentItem.currentUpgrade = tonumber(currentLevel) or 0;
			DC.currentItem.maxUpgrade = DC.MAX_UPGRADE_LEVEL;
			DC.currentItem.baseLevel = tonumber(baseIlvl) or DC.currentItem.level;
			
			-- Set initial target to next level
			DC.targetUpgradeLevel = DC.currentItem.currentUpgrade + 1;
			if DC.targetUpgradeLevel > DC.currentItem.maxUpgrade then
				DC.targetUpgradeLevel = DC.currentItem.maxUpgrade;
			end
			
			DarkChaos_ItemUpgrade_UpdateUI();
		end
		return;
	end
	
	-- DCUPGRADE_SUCCESS response (upgrade complete)
	-- Format from server: "DCUPGRADE_SUCCESS:<item_guid>:<new_level>"
	if string.find(message, "^DCUPGRADE_SUCCESS") then
		local _, _, itemGUID, newLevel = string.find(message, "DCUPGRADE_SUCCESS:(%d+):(%d+)");
		
		-- Update item level (recalculate currencies from cost)
		if DC.currentItem then
			local oldLevel = DC.currentItem.currentUpgrade;
			DC.currentItem.currentUpgrade = tonumber(newLevel) or DC.currentItem.currentUpgrade;
			
			-- Deduct cost (calculate from levels upgraded)
			local levelsUpgraded = DC.currentItem.currentUpgrade - oldLevel;
			local cost = DarkChaos_ItemUpgrade_GetCost(DC.currentItem.tier, DC.targetUpgradeLevel);
			if cost then
				DC.playerTokens = DC.playerTokens - cost.tokens;
				DC.playerEssence = DC.playerEssence - cost.essence;
			end
			
			-- Play celebration
			DarkChaos_ItemUpgrade_PlayCelebration();
		end
		
		PlaySound("AuctionWindowClose");
		print("|cff00ff00Item upgraded successfully!|r");
		return;
	end
	
	-- DCUPGRADE_ERROR response
	-- Format from server: "DCUPGRADE_ERROR:<error_message>"
	if string.find(message, "^DCUPGRADE_ERROR") then
		local _, _, errorMsg = string.find(message, "DCUPGRADE_ERROR:(.+)");
		print("|cffff0000Upgrade failed:|r " .. (errorMsg or "Unknown error"));
		SetButtonEnabled(DarkChaos_ItemUpgradeFrame.UpgradeButton, true);
		return;
	end
end

--[[=====================================================
	UPGRADE CELEBRATION
=======================================================]]

function DarkChaos_ItemUpgrade_PlayCelebration()
	local frame = DarkChaos_ItemUpgradeFrame;
	
	-- Flash effect on right tooltip
	local tooltip = frame.RightTooltip;
	if tooltip.UpgradeGlow then
		tooltip.UpgradeGlow:Show();
		tooltip.UpgradeGlow:SetAlpha(1.0);
		
		-- Fade out animation (manual)
		DC.upgradeAnimationTime = 2.0; -- 2 second animation
	end
	
	-- Update to next level
	DC.targetUpgradeLevel = DC.currentItem.currentUpgrade + 1;
	if DC.targetUpgradeLevel > DC.currentItem.maxUpgrade then
		DC.targetUpgradeLevel = DC.currentItem.maxUpgrade;
	end
end

--[[=====================================================
	ITEM BROWSER
=======================================================]]

local ITEM_BROWSER_ITEMS_PER_PAGE = 10;
local itemBrowserList = {};

function DarkChaos_ItemBrowser_OnLoad(self)
	-- Create item buttons
	for i = 1, ITEM_BROWSER_ITEMS_PER_PAGE do
		local button = CreateFrame("Button", self:GetName() .. "Item" .. i, self, "ItemButtonTemplate");
		button:SetID(i);
		button:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -40 - (i-1) * 32);
		button:SetScript("OnClick", DarkChaos_ItemBrowser_Item_OnClick);
		button:SetScript("OnEnter", DarkChaos_ItemBrowser_Item_OnEnter);
		button:SetScript("OnLeave", function() GameTooltip:Hide() end);
		
		-- Add item name text
		button.name = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		button.name:SetPoint("LEFT", button, "RIGHT", 5, 0);
		button.name:SetWidth(200);
		button.name:SetJustifyH("LEFT");
	end
end

function DarkChaos_ItemBrowser_OnShow(self)
	DarkChaos_ItemBrowser_Update();
end

function DarkChaos_ItemBrowser_Update()
	-- Scan bags for upgradeable items
	itemBrowserList = {};
	
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot);
			if link then
				local name, _, quality = GetItemInfo(link);
				-- Only show quality 2+ (uncommon and above)
				if quality and quality >= 2 then
					table.insert(itemBrowserList, {
						bag = bag,
						slot = slot,
						link = link,
						name = name,
						quality = quality,
					});
				end
			end
		end
	end
	
	-- Sort by quality (descending)
	table.sort(itemBrowserList, function(a, b)
		if a.quality == b.quality then
			return a.name < b.name;
		end
		return a.quality > b.quality;
	end);
	
	-- Update scroll frame
	local scrollFrame = DarkChaos_ItemBrowserFrame.ScrollFrame;
	FauxScrollFrame_Update(scrollFrame, #itemBrowserList, ITEM_BROWSER_ITEMS_PER_PAGE, 32);
	
	local offset = FauxScrollFrame_GetOffset(scrollFrame);
	for i = 1, ITEM_BROWSER_ITEMS_PER_PAGE do
		local index = offset + i;
		local button = _G[DarkChaos_ItemBrowserFrame:GetName() .. "Item" .. i];
		
		if index <= #itemBrowserList then
			local item = itemBrowserList[index];
			local texture = GetContainerItemInfo(item.bag, item.slot);
			
			SetItemButtonTexture(button, texture);
			SetItemButtonQuality_335(button, item.quality);
			button.name:SetText(item.name);
			
			local color = DC.ITEM_QUALITY_COLORS[item.quality] or DC.ITEM_QUALITY_COLORS[1];
			button.name:SetTextColor(color.r, color.g, color.b);
			
			button.itemData = item;
			button:Show();
		else
			button:Hide();
		end
	end
end

function DarkChaos_ItemBrowser_Item_OnClick(self)
	if self.itemData then
		DarkChaos_ItemUpgrade_SelectItemBySlot(self.itemData.bag, self.itemData.slot);
	end
end

function DarkChaos_ItemBrowser_Item_OnEnter(self)
	if self.itemData then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetHyperlink(self.itemData.link);
		GameTooltip:Show();
	end
end

--[[=====================================================
	SLASH COMMANDS
=======================================================]]

SLASH_DCUPGRADE1 = "/dcupgrade";
SlashCmdList["DCUPGRADE"] = function(msg)
	if DarkChaos_ItemUpgradeFrame:IsShown() then
		DarkChaos_ItemUpgradeFrame:Hide();
	else
		DarkChaos_ItemUpgradeFrame:Show();
	end
end
