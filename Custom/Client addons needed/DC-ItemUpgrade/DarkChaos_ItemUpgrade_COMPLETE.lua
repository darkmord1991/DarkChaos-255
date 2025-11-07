--[[
	DC-ItemUpgrade - Complete Retail-inspired Item Upgrade Interface
	Port from: Blizzard_ItemUpgradeUI (Retail 11.2.7)
	Adapted for: AzerothCore 3.3.5a with custom server communication
	
	Features:
	- Retail-like visual interface with side-by-side stat comparison
	- Item browsing and selection
	- Current vs Upgraded stats display
	- Cost breakdown with currency icons
	- Tier-based coloring and item level calculation
	- Chat-based server communication protocol
]]

-- Global namespace
DarkChaos_ItemUpgrade = {};
local DC = DarkChaos_ItemUpgrade;

--[[=====================================================
	CONSTANTS & CONFIGURATION
=======================================================]]

DC.MAX_UPGRADE_LEVEL = 15;
DC.CURRENCY_TOKEN_ID = 100999;  -- Upgrade Token
DC.CURRENCY_ESSENCE_ID = 100998; -- Artifact Essence

-- Item quality colors
DC.QUALITY_COLORS = {
	[0] = {r=0.62, g=0.62, b=0.62, hex="9D9D9D"}, -- Poor
	[1] = {r=1.00, g=1.00, b=1.00, hex="FFFFFF"}, -- Common
	[2] = {r=0.12, g=1.00, b=0.00, hex="1EFF00"}, -- Uncommon
	[3] = {r=0.00, g=0.44, b=0.87, hex="0070DD"}, -- Rare
	[4] = {r=0.64, g=0.21, b=0.93, hex="A335EE"}, -- Epic
	[5] = {r=1.00, g=0.50, b=0.00, hex="FF8000"}, -- Legendary
};

-- Tier descriptions
DC.TIER_NAMES = {
	[1] = "Veteran",
	[2] = "Adventurer",
	[3] = "Champion",
	[4] = "Hero",
	[5] = "Legendary",
};

--[[=====================================================
	STATE VARIABLES
=======================================================]]

DC.selectedItem = nil; -- Current selected item {bag, slot, link, id, quality, name, level, tier, currentUpgrade}
DC.targetUpgradeLevel = 1;
DC.playerTokens = 0;
DC.playerEssence = 0;
DC.upgradeCosts = {}; -- Cached from database
DC.animatingFrame = nil;
DC.animationAlpha = 0;

--[[=====================================================
	FRAME REFERENCES
=======================================================]]

local function GetMainFrame()
	return _G["DarkChaos_ItemUpgradeFrame"];
end

local function GetHeaderItemButton()
	return GetMainFrame()._Header._ItemButton;
end

local function GetHeaderItemInfo()
	return GetMainFrame()._Header._ItemInfo;
end

local function GetCurrentPanel()
	return GetMainFrame()._ComparisonContainer._CurrentPanel;
end

local function GetUpgradedPanel()
	return GetMainFrame()._ComparisonContainer._UpgradedPanel;
end

local function GetControlPanel()
	return GetMainFrame()._ControlPanel;
end

local function GetCurrencyPanel()
	return GetMainFrame()._CurrencyPanel;
end

local function GetUpgradeButton()
	return GetMainFrame()._UpgradeButton;
end

--[[=====================================================
	INITIALIZATION & FRAME SETUP
=======================================================]]

function DarkChaos_ItemUpgrade_OnLoad(self)
	-- Register events
	self:RegisterEvent("CHAT_MSG_SAY");
	self:RegisterEvent("BAG_UPDATE");
	self:RegisterEvent("PLAYER_LOGIN");
	
	-- Setup title
	self:SetTitle("Item Upgrade");
	
	-- Make movable
	self:SetMovable(true);
	self:EnableMouse(true);
	self:RegisterForDrag("LeftButton");
	self:SetScript("OnDragStart", function(frame)
		if frame:IsMovable() then
			frame:StartMoving();
		end
	end);
	self:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing();
	end);
	
	-- Setup close button
	_G[self:GetName() .. "_CloseButton"]:SetScript("OnClick", function()
		self:Hide();
	end);
	
	-- Setup upgrade button
	GetUpgradeButton():SetScript("OnClick", function()
		DarkChaos_ItemUpgrade_PerformUpgrade();
	end);
	
	-- Setup browse button
	GetHeaderItemInfo()._BrowseButton:SetScript("OnClick", function()
		DarkChaos_ItemUpgrade_ShowItemBrowser();
	end);
	
	-- Initialize dropdown
	GetControlPanel()._LevelSelector._Dropdown:Initialize(DarkChaos_ItemUpgrade_InitializeDropdown);
	
	print("|cff00ff00[DC-ItemUpgrade]|r Loaded. Type |cffffcc00/dcupgrade|r to open.");
end

function DarkChaos_ItemUpgrade_OnShow(self)
	-- Request currency update
	SendChatMessage(".dcupgrade init", "SAY");
	
	-- Update UI
	DarkChaos_ItemUpgrade_UpdateUI();
end

function DarkChaos_ItemUpgrade_OnHide(self)
	-- Nothing special needed
end

function DarkChaos_ItemUpgrade_OnEvent(self, event, ...)
	if event == "CHAT_MSG_SAY" then
		local message, sender = ...;
		-- Only process messages from self (server responses)
		if sender == UnitName("player") then
			DarkChaos_ItemUpgrade_ParseServerMessage(message);
		end
	elseif event == "BAG_UPDATE" then
		-- Refresh UI when bag updates
		DarkChaos_ItemUpgrade_UpdateUI();
	end
end

--[[=====================================================
	SERVER COMMUNICATION
=======================================================]]

function DarkChaos_ItemUpgrade_ParseServerMessage(message)
	-- DCUPGRADE_INIT response (player currencies)
	-- Format: "DCUPGRADE_INIT:tokens:essence"
	if string.find(message, "^DCUPGRADE_INIT:") then
		local tokens, essence = string.match(message, "DCUPGRADE_INIT:(%d+):(%d+)");
		if tokens and essence then
			DC.playerTokens = tonumber(tokens) or 0;
			DC.playerEssence = tonumber(essence) or 0;
			DarkChaos_ItemUpgrade_UpdatePlayerCurrencies();
			print(string.format("|cff00ff00[DC-ItemUpgrade]|r Tokens: %d | Essence: %d", DC.playerTokens, DC.playerEssence));
		end
		return;
	end
	
	-- DCUPGRADE_QUERY response (item upgrade info)
	-- Format: "DCUPGRADE_QUERY:itemGUID:currentLevel:tier:baseIlvl"
	if string.find(message, "^DCUPGRADE_QUERY:") then
		local itemGUID, currentLevel, tier, baseIlvl = string.match(message, "DCUPGRADE_QUERY:(%d+):(%d+):(%d+):(%d+)");
		if itemGUID and currentLevel and tier and baseIlvl then
			if DC.selectedItem then
				DC.selectedItem.tier = tonumber(tier) or 1;
				DC.selectedItem.currentUpgrade = tonumber(currentLevel) or 0;
				DC.selectedItem.maxUpgrade = DC.MAX_UPGRADE_LEVEL;
				DC.selectedItem.baseLevel = tonumber(baseIlvl) or DC.selectedItem.level;
				
				-- Set target to next level
				DC.targetUpgradeLevel = DC.selectedItem.currentUpgrade + 1;
				if DC.targetUpgradeLevel > DC.MAX_UPGRADE_LEVEL then
					DC.targetUpgradeLevel = DC.MAX_UPGRADE_LEVEL;
				end
				
				DarkChaos_ItemUpgrade_UpdateUI();
			end
		end
		return;
	end
	
	-- DCUPGRADE_SUCCESS response
	-- Format: "DCUPGRADE_SUCCESS:itemGUID:newLevel"
	if string.find(message, "^DCUPGRADE_SUCCESS:") then
		local itemGUID, newLevel = string.match(message, "DCUPGRADE_SUCCESS:(%d+):(%d+)");
		if itemGUID and newLevel then
			if DC.selectedItem then
				DC.selectedItem.currentUpgrade = tonumber(newLevel) or DC.selectedItem.currentUpgrade;
				DC.targetUpgradeLevel = DC.selectedItem.currentUpgrade + 1;
				if DC.targetUpgradeLevel > DC.MAX_UPGRADE_LEVEL then
					DC.targetUpgradeLevel = DC.MAX_UPGRADE_LEVEL;
				end
				
				-- Refresh currencies and UI
				SendChatMessage(".dcupgrade init", "SAY");
				DarkChaos_ItemUpgrade_UpdateUI();
				DarkChaos_ItemUpgrade_PlaySuccessAnimation();
			end
		end
		print("|cff00ff00[DC-ItemUpgrade]|r Upgrade successful!");
		return;
	end
	
	-- DCUPGRADE_ERROR response
	-- Format: "DCUPGRADE_ERROR:error_message"
	if string.find(message, "^DCUPGRADE_ERROR:") then
		local errorMsg = string.match(message, "DCUPGRADE_ERROR:(.+)");
		print("|cffff0000[DC-ItemUpgrade] ERROR:|r " .. (errorMsg or "Unknown error"));
		GetUpgradeButton():Enable();
		return;
	end
end

--[[=====================================================
	UI UPDATES
=======================================================]]

function DarkChaos_ItemUpgrade_UpdateUI()
	if not DC.selectedItem then
		DarkChaos_ItemUpgrade_ClearUI();
		return;
	end
	
	-- Update header with item info
	DarkChaos_ItemUpgrade_UpdateItemHeader();
	
	-- Update comparison panels
	DarkChaos_ItemUpgrade_UpdateComparisonPanels();
	
	-- Update controls
	DarkChaos_ItemUpgrade_UpdateControls();
	
	-- Update upgrade button state
	DarkChaos_ItemUpgrade_UpdateUpgradeButton();
end

function DarkChaos_ItemUpgrade_UpdateItemHeader()
	local item = DC.selectedItem;
	local itemButton = GetHeaderItemButton();
	local itemInfo = GetHeaderItemInfo();
	
	-- Set item icon
	local texture = GetItemIcon(item.link);
	itemButton:SetNormalTexture(texture);
	
	-- Set quality color border
	local color = DC.QUALITY_COLORS[item.quality] or DC.QUALITY_COLORS[1];
	itemButton:GetNormalTexture():SetVertexColor(color.r, color.g, color.b);
	
	-- Update text fields
	itemInfo._ItemName:SetText(item.name);
	itemInfo._ItemLevel:SetText(string.format("|cffCCCCCCItem Level: %d|r", item.level));
	
	local tierName = DC.TIER_NAMES[item.tier] or "Unknown";
	local upgradeText = string.format("|cff00ff00%s %d/%d|r", tierName, item.currentUpgrade, DC.MAX_UPGRADE_LEVEL);
	itemInfo._UpgradeStatus:SetText(upgradeText);
end

function DarkChaos_ItemUpgrade_UpdateComparisonPanels()
	local item = DC.selectedItem;
	local currentPanel = GetCurrentPanel();
	local upgradedPanel = GetUpgradedPanel();
	
	-- Current stats
	currentPanel._Level:SetText(string.format("Level %d - %d%%", item.currentUpgrade, DarkChaos_ItemUpgrade_CalculateBonusPercent(item.currentUpgrade)));
	currentPanel._StatsText:SetText(DarkChaos_ItemUpgrade_GetItemStatsText(item.link, item.currentUpgrade, false));
	
	-- Upgraded stats
	upgradedPanel._Level:SetText(string.format("Level %d - %d%%", DC.targetUpgradeLevel, DarkChaos_ItemUpgrade_CalculateBonusPercent(DC.targetUpgradeLevel)));
	upgradedPanel._StatsText:SetText(DarkChaos_ItemUpgrade_GetItemStatsText(item.link, DC.targetUpgradeLevel, true));
end

function DarkChaos_ItemUpgrade_UpdateControls()
	local item = DC.selectedItem;
	local controlPanel = GetControlPanel();
	
	-- Update upgrade target selector
	DarkChaos_ItemUpgrade_RefreshDropdown();
	
	-- Update cost display
	local cost = DarkChaos_ItemUpgrade_GetUpgradeCost(item.tier, DC.targetUpgradeLevel);
	if cost then
		controlPanel._CostDisplay._TokenAmount:SetText(string.format("|cffFFD100%d|r", cost.tokens));
		controlPanel._CostDisplay._EssenceAmount:SetText(string.format("|cffFF00FF%d|r", cost.essence));
	end
end

function DarkChaos_ItemUpgrade_UpdatePlayerCurrencies()
	local currencyPanel = GetCurrencyPanel();
	currencyPanel._TokenAmount:SetText(string.format("|cffFFD100%d|r", DC.playerTokens));
	currencyPanel._EssenceAmount:SetText(string.format("|cffFF00FF%d|r", DC.playerEssence));
end

function DarkChaos_ItemUpgrade_UpdateUpgradeButton()
	local item = DC.selectedItem;
	local button = GetUpgradeButton();
	
	if not item or DC.targetUpgradeLevel <= item.currentUpgrade then
		button:Disable();
		button:SetText("UPGRADE");
		return;
	end
	
	-- Check if we have enough currency
	local cost = DarkChaos_ItemUpgrade_GetUpgradeCost(item.tier, DC.targetUpgradeLevel);
	if not cost or DC.playerTokens < cost.tokens or DC.playerEssence < cost.essence then
		button:Disable();
		button:SetText("INSUFFICIENT CURRENCY");
		return;
	end
	
	button:Enable();
	button:SetText("UPGRADE");
end

function DarkChaos_ItemUpgrade_ClearUI()
	GetHeaderItemButton():SetNormalTexture("");
	GetHeaderItemInfo()._ItemName:SetText("No item selected");
	GetHeaderItemInfo()._ItemLevel:SetText("");
	GetHeaderItemInfo()._UpgradeStatus:SetText("");
	
	GetCurrentPanel()._StatsText:SetText("Select an item to begin");
	GetUpgradedPanel()._StatsText:SetText("Select an item to begin");
	
	GetUpgradeButton():Disable();
end

--[[=====================================================
	ITEM STATS CALCULATION
=======================================================]]

function DarkChaos_ItemUpgrade_CalculateBonusPercent(level)
	if not level or level <= 0 then
		return 0;
	end
	return math.floor((level / 5) * 25 + 0.5);
end

function DarkChaos_ItemUpgrade_GetUpgradeCost(tier, level)
	-- This would normally be looked up from database
	-- For now, return placeholder
	-- Format would be: {tokens = X, essence = Y}
	return {tokens = level * 10, essence = level * 5};
end

function DarkChaos_ItemUpgrade_GetItemStatsText(itemLink, upgradeLevel, isPreview)
	if not itemLink then
		return "No item";
	end
	
	-- Create tooltip to scan stats
	local tooltip = CreateFrame("GameTooltip", "DC_ScanTooltip", UIParent, "GameTooltipTemplate");
	tooltip:SetOwner(UIParent, "ANCHOR_NONE");
	tooltip:SetHyperlink(itemLink);
	
	local lines = {};
	for i = 2, tooltip:NumLines() do
		local text = _G["DC_ScanTooltipTextLeft" .. i]:GetText();
		if text then
			table.insert(lines, text);
		end
	end
	tooltip:Hide();
	
	local result = "";
	if #lines > 0 then
		result = table.concat(lines, "\n");
	else
		result = "No stats available";
	end
	
	if isPreview and upgradeLevel > 0 then
		local bonusPercent = DarkChaos_ItemUpgrade_CalculateBonusPercent(upgradeLevel);
		result = result .. string.format("\n|cff00ff00+%d%% from upgrade|r", bonusPercent);
	end
	
	return result;
end

--[[=====================================================
	DROPDOWN & SELECTION
=======================================================]]

function DarkChaos_ItemUpgrade_InitializeDropdown(self, level)
	if level ~= 1 then
		return;
	end
	
	local item = DC.selectedItem;
	if not item then
		return;
	end
	
	for upgradeLevel = item.currentUpgrade + 1, DC.MAX_UPGRADE_LEVEL do
		local info = UIDropDownMenu_CreateInfo();
		info.text = string.format("Level %d/%d", upgradeLevel, DC.MAX_UPGRADE_LEVEL);
		info.value = upgradeLevel;
		info.func = function(self, arg)
			DC.targetUpgradeLevel = arg;
			DarkChaos_ItemUpgrade_UpdateUI();
		end;
		info.checked = (upgradeLevel == DC.targetUpgradeLevel);
		UIDropDownMenu_AddButton(info, level);
	end
end

function DarkChaos_ItemUpgrade_RefreshDropdown()
	local item = DC.selectedItem;
	if not item then
		return;
	end
	
	local dropdown = GetControlPanel()._LevelSelector._Dropdown;
	UIDropDownMenu_SetSelectedValue(dropdown, DC.targetUpgradeLevel);
	UIDropDownMenu_SetText(dropdown, string.format("Level %d/%d", DC.targetUpgradeLevel, DC.MAX_UPGRADE_LEVEL));
end

function DarkChaos_ItemUpgrade_ShowItemBrowser()
	print("|cffff0000[DC-ItemUpgrade]|r Item browser not yet implemented. Manually select items from your bags.");
end

--[[=====================================================
	UPGRADE EXECUTION
=======================================================]]

function DarkChaos_ItemUpgrade_PerformUpgrade()
	local item = DC.selectedItem;
	if not item then
		print("|cffff0000[DC-ItemUpgrade]|r No item selected.");
		return;
	end
	
	-- Validate
	if DC.targetUpgradeLevel <= item.currentUpgrade then
		print("|cffff0000[DC-ItemUpgrade]|r Target level not higher than current.");
		return;
	end
	
	local cost = DarkChaos_ItemUpgrade_GetUpgradeCost(item.tier, DC.targetUpgradeLevel);
	if not cost or DC.playerTokens < cost.tokens or DC.playerEssence < cost.essence then
		print("|cffff0000[DC-ItemUpgrade]|r Insufficient currency.");
		return;
	end
	
	-- Send upgrade request to server
	local command = string.format(".dcupgrade perform %d %d %d", item.bag, item.slot, DC.targetUpgradeLevel);
	SendChatMessage(command, "SAY");
	
	-- Disable button during processing
	GetUpgradeButton():Disable();
end

--[[=====================================================
	ANIMATIONS
=======================================================]]

function DarkChaos_ItemUpgrade_PlaySuccessAnimation()
	-- Flash the upgraded panel
	local upgradedPanel = GetUpgradedPanel();
	upgradedPanel:SetAlpha(1);
	
	-- Animate alpha (fade in/out)
	DC.animatingFrame = upgradedPanel;
	DC.animationAlpha = 1;
end

--[[=====================================================
	ITEM SELECTION (FROM BAGS)
=======================================================]]

function DarkChaos_ItemUpgrade_SelectItem(bag, slot)
	local item = GetContainerItemLink(bag, slot);
	if not item then
		print("|cffff0000[DC-ItemUpgrade]|r No item in that slot.");
		return;
	end
	
	local name, link, quality, level = GetItemInfo(item);
	if not name then
		print("|cffff0000[DC-ItemUpgrade]|r Item data not available yet.");
		return;
	end
	
	DC.selectedItem = {
		bag = bag,
		slot = slot,
		link = link,
		id = string.match(link, "item:(%d+):"),
		quality = quality,
		name = name,
		level = level,
		tier = 1,
		currentUpgrade = 0,
		maxUpgrade = DC.MAX_UPGRADE_LEVEL,
	};
	
	-- Query server for upgrade info
	SendChatMessage(string.format(".dcupgrade query %d %d", bag, slot), "SAY");
end

--[[=====================================================
	SLASH COMMAND
=======================================================]]

SLASH_DCUPGRADE1 = "/dcupgrade";

function SlashCmdList.DCUPGRADE(msg, editbox)
	local frame = GetMainFrame();
	if frame:IsShown() then
		frame:Hide();
	else
		frame:Show();
	end
end

--[[=====================================================
	UTILITY FUNCTIONS
=======================================================]]

function DarkChaos_ItemUpgrade_OnUpdate(self, elapsed)
	-- Animation updates can go here
end

print("|cff00ff00[DC-ItemUpgrade]|r Addon loaded successfully!");
