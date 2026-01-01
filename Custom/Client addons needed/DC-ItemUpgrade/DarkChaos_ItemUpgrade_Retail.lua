--[[
	DC-ItemUpgrade - Retail 11.2.7 Backport for WoW 3.3.5a
	Based on: Blizzard_ItemUpgradeUI (11.2.7.64169)
	Adapted for: AzerothCore 3.3.5a with Eluna server communication
--]]

-- Global namespace - use existing table from Core.lua, don't overwrite it!
DarkChaos_ItemUpgrade = DarkChaos_ItemUpgrade or {};
local DC = DarkChaos_ItemUpgrade;

--[[=====================================================
	QUALITY COLOR FIX & ITEM ID TOOLTIPS
	Fixes "attempt to index local 'color' (a nil value)" for quality 7+ items
	Also adds Item ID display to all item tooltips
=======================================================]]

-- Add missing ITEM_QUALITY_COLORS entries for quality 7+ (Heirloom, Artifact, etc.)
-- This fixes the LootFrame.lua error when looting quality 7 items
if ITEM_QUALITY_COLORS then
	-- Quality 7 = Heirloom (cyan/light blue - same as Blizzard uses in later expansions)
	if not ITEM_QUALITY_COLORS[7] then
		ITEM_QUALITY_COLORS[7] = { r = 0.0, g = 0.8, b = 1.0, hex = "|cff00ccff" };
	end
	-- Quality 8 = Artifact (orange, same as legendary for future compatibility)
	if not ITEM_QUALITY_COLORS[8] then
		ITEM_QUALITY_COLORS[8] = { r = 1.0, g = 0.5, b = 0.0, hex = "|cffff8000" };
	end
	-- Quality 9+ fallback (white)
	for i = 9, 15 do
		if not ITEM_QUALITY_COLORS[i] then
			ITEM_QUALITY_COLORS[i] = { r = 1.0, g = 1.0, b = 1.0, hex = "|cffffffff" };
		end
	end
end

-- Setting for showing Item IDs in tooltips 
-- DISABLED: Now handled by DC-QoS addon (Tooltips.lua)
-- DC.showItemIDsInTooltips = true;
DC.showItemIDsInTooltips = false; -- DC-QoS handles this

--[[=====================================================
	ITEM ID TOOLTIP HELPER (DEPRECATED)
	Item ID display is now handled by DC-QoS addon.
	This code remains for backwards compatibility but is disabled.
=======================================================]]

-- Helper function to add item ID line to any tooltip
-- DEPRECATED: DC-QoS Tooltips.lua now handles this - keeping for API compatibility
local function DC_AddItemIDToTooltip(tooltip, itemId, itemLink)
	-- Skip if DC-QoS is handling tooltips (preferred)
	if DCQOS and DCQOS.settings and DCQOS.settings.tooltips and DCQOS.settings.tooltips.showItemId then
		return false; -- DC-QoS will handle it
	end
	if not tooltip or not DC.showItemIDsInTooltips then
		return false;
	end
	
	-- If no itemId provided, try to get it from the tooltip's item
	if not itemId and not itemLink then
		local _, link = tooltip:GetItem();
		if link then
			itemLink = link;
			itemId = tonumber(string.match(link, "item:(%d+)"));
		end
	elseif itemLink and not itemId then
		itemId = tonumber(string.match(itemLink, "item:(%d+)"));
	end
	
	if not itemId then
		return false;
	end
	
	-- Mark that we've added item ID to this tooltip to prevent duplicates
	if tooltip.__dcItemIDAdded == itemId then
		return false;
	end
	tooltip.__dcItemIDAdded = itemId;
	
	-- Add item ID line (gray, subtle)
	tooltip:AddLine(string.format("|cff888888Item ID: %d|r", itemId));
	tooltip:Show();
	return true;
end

-- Make it accessible globally
DC.AddItemIDToTooltip = DC_AddItemIDToTooltip;

-- Item IDs for currency icons (set these to your actual item IDs)
DC.TOKEN_ITEM_ID = nil; -- Set to your Token Item ID (e.g. 49426)
DC.ESSENCE_ITEM_ID = nil; -- Set to your Essence Item ID (e.g. 43102)

-- Debug function
function DC.Debug(msg)
	if DC_ItemUpgrade_Settings and DC_ItemUpgrade_Settings.debug then
		if DarkChaos_ItemUpgrade_DebugFrame and DarkChaos_ItemUpgrade_DebugFrame:IsShown() then
			local scroll = DarkChaos_ItemUpgrade_DebugFrame.Scroll;
			if scroll then
				scroll:AddMessage(msg);
			end
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC-Upgrade Debug]|r " .. tostring(msg));
		end
	end
end

-- Tier icon textures
DC.TIER_ICONS = {
	[1] = "Interface\\Icons\\INV_Misc_Coin_01",        -- Leveling (Copper coin)
	[2] = "Interface\\Icons\\INV_Misc_Coin_02",        -- Heroic (Silver coin)
	[3] = "Interface\\Icons\\INV_Misc_Coin_03",        -- Raid (Gold coin)
	[4] = "Interface\\Icons\\INV_Misc_Coin_04",        -- Mythic (Platinum coin)
	[5] = "Interface\\Icons\\INV_Misc_Gem_Amethyst_01", -- Artifact (Gem)
};

-- Tier colors for progress bars and indicators
DC.TIER_COLORS = {
	[1] = { r = 0.6, g = 0.6, b = 0.6 },    -- Leveling (Gray)
	[2] = { r = 0.2, g = 0.8, b = 0.2 },    -- Heroic (Green)
	[3] = { r = 0.2, g = 0.2, b = 1.0 },    -- Raid (Blue)
	[4] = { r = 0.8, g = 0.2, b = 0.8 },    -- Mythic (Purple)
	[5] = { r = 1.0, g = 0.5, b = 0.0 },    -- Artifact (Orange)
};

-- Cost colors for indicators
DC.COST_COLORS = {
	cheap = { r = 0.2, g = 0.8, b = 0.2 },      -- Green (affordable)
	moderate = { r = 0.8, g = 0.8, b = 0.2 },   -- Yellow (somewhat affordable)
	expensive = { r = 0.8, g = 0.2, b = 0.2 },  -- Red (expensive)
};

--[[=====================================================
	HEIRLOOM STAT PACKAGES
	For item 300365 (Heirloom Adventurer's Shirt) only.
	Players select a stat package to determine secondary stats.
	Package stats scale with upgrade levels (1-15).
	
	NOTE: DC.STAT_PACKAGES and DC.STAT_PACKAGE_LEVEL_VALUES are defined in Heirloom.lua
	      which loads first. Do not redefine them here!
=======================================================]]

-- Currently selected stat package (saved per character)
DC.selectedStatPackage = nil;

-- Use value from Heirloom.lua or default
DC.STAT_PERCENT_PER_LEVEL = DC.STAT_PERCENT_PER_LEVEL or 2.5;

local BASE_STAT_INCREMENT = 0.025; -- 2.5% per level baseline
local TIER_STAT_MULTIPLIERS = { 0.9, 0.95, 1.0, 1.15, 1.25 };
local TIER_ILVL_PER_LEVEL = { 1.0, 1.0, 1.5, 2.0, 2.5 };

local function ClampTier(tier)
	tier = math.floor(tonumber(tier) or 1);
	if tier < 1 then return 1; end
	if tier > #TIER_STAT_MULTIPLIERS then return #TIER_STAT_MULTIPLIERS; end
	return tier;
end

local function GetStatMultiplierForLevel(level, tier)
	level = math.max(tonumber(level) or 0, 0);
	local base = 1.0 + (BASE_STAT_INCREMENT * level);
	local tierMult = TIER_STAT_MULTIPLIERS[ClampTier(tier)] or 1.0;
	return ((base - 1.0) * tierMult) + 1.0;
end

local function GetStatBonusPercent(level, tier)
	return (GetStatMultiplierForLevel(level, tier) - 1.0) * 100.0;
end

local function GetItemLevelBonus(level, tier)
	level = math.max(tonumber(level) or 0, 0);
	local perLevel = TIER_ILVL_PER_LEVEL[ClampTier(tier)] or 1.0;
	return math.ceil(level * perLevel);
end

local function GetUpgradedItemLevel(baseLevel, level, tier)
	baseLevel = tonumber(baseLevel) or 0;
	return baseLevel + GetItemLevelBonus(level, tier);
end

local function CopyCloneEntries(source)
	if not source then
		return nil;
	end
	local copy = {};
	for level, entry in pairs(source) do
		copy[level] = entry;
	end
	return copy;
end

local function ParseCloneMap(mapString)
	if not mapString or mapString == "" then
		return nil;
	end
	local entries = {};
	for pair in string.gmatch(mapString, "[^,;]+") do
		local levelStr, entryStr = string.match(pair, "%s*(%d+)%-(%d+)%s*");
		if levelStr and entryStr then
			entries[tonumber(levelStr)] = tonumber(entryStr);
		end
	end
	if next(entries) then
		return entries;
	end
	return nil;
end

local function GetCloneEntryForLevel(item, level)
	if not item then
		return nil;
	end
	level = math.floor(math.max(tonumber(level) or 0, 0));
	if item.cloneEntries and item.cloneEntries[level] then
		return item.cloneEntries[level];
	end
	local currentUpgrade = item.currentUpgrade or 0;
	if level == currentUpgrade then
		return item.currentEntry or item.itemID;
	end
	if level == 0 then
		return item.baseEntry or item.itemID;
	end
	return nil;
end

local function ResolveItemLevelFromClone(item, level, fallback)
	local entry = GetCloneEntryForLevel(item, level);
	if entry then
		local infoLevel = select(4, GetItemInfo(entry));
		if infoLevel then
			return infoLevel;
		end
	end
	return fallback;
end

local function ResolveBaseItemLevel(item)
	if not item then
		return 0;
	end

	local baseGuess = item.baseLevel or item.level or 0;
	return ResolveItemLevelFromClone(item, 0, baseGuess);
end

local function ResolveUpgradeItemLevel(item, upgradeLevel, baseLevel)
	if not item then
		return 0;
	end

	baseLevel = baseLevel or ResolveBaseItemLevel(item);
	local computed = GetUpgradedItemLevel(baseLevel, upgradeLevel, item.tier);
	return ResolveItemLevelFromClone(item, upgradeLevel, computed);
end

--[[=====================================================
	VISUAL PROGRESS INDICATORS
=======================================================]]

function DarkChaos_ItemUpgrade_UpdateProgressBar(currentLevel, maxLevel, tier)
	local frame = DarkChaos_ItemUpgradeFrame;
	if not frame or not frame.ItemInfo or not frame.ItemInfo.ProgressBar then return end

	local progressBar = frame.ItemInfo.ProgressBar;
	local fill = progressBar.Fill;
	local text = progressBar.Text;
	local inset = 6;
	local fullWidth = math.max(0, (progressBar:GetWidth() or 0) - inset);
	local cappedLevel = math.max(0, math.min(currentLevel or 0, maxLevel or 0));
	local maxValue = math.max(maxLevel or 0, 1);
	local fraction = cappedLevel / maxValue;
	local barWidth = math.max(1, math.floor(fullWidth * fraction + 0.5));
	fill:SetWidth(barWidth);

	local tierColor = DC.TIER_COLORS[tier] or DC.TIER_COLORS[1];
	if type(fill.SetColorTexture) == "function" then
		fill:SetColorTexture(tierColor.r, tierColor.g, tierColor.b, 1);
	else
		fill:SetVertexColor(tierColor.r, tierColor.g, tierColor.b, 1);
	end

	local percent = math.floor(fraction * 100 + 0.5);
	if cappedLevel >= maxValue then
		text:SetText(string.format("%d / %d (MAX)", cappedLevel, maxValue));
		text:SetTextColor(1, 0.82, 0);
	else
		text:SetText(string.format("%d / %d (%d%%)", cappedLevel, maxValue, percent));
		text:SetTextColor(0.95, 0.95, 0.95);
	end

	progressBar:Show();
end

function DarkChaos_ItemUpgrade_UpdateTierIndicator(tier)
	-- Removed as per request
end

function DarkChaos_ItemUpgrade_UpdateCost()
	local frame = DarkChaos_ItemUpgradeFrame;
	if not frame then 
		DC.Debug("UpdateCost: frame is nil!");
		return 
	end
	
	-- Determine which currency to display based on UI mode
	local isHeirloomMode = (DC.uiMode == "HEIRLOOM");
	
	-- Always update owned currency display (even without an item selected)
	local playerTokens = DC.playerTokens or 0;
	local playerEssence = DC.playerEssence or 0;
	
	-- For heirloom mode, show essence; for standard mode, show tokens
	local displayCurrency = isHeirloomMode and playerEssence or playerTokens;
	local displayCurrencyItemID = isHeirloomMode and DC.ESSENCE_ITEM_ID or DC.TOKEN_ITEM_ID;
	
	DC.Debug("UpdateCost: playerTokens=" .. tostring(playerTokens) .. ", playerEssence=" .. tostring(playerEssence) .. ", mode=" .. tostring(DC.uiMode));
	
	if frame.CostFrame then
		DC.Debug("UpdateCost: CostFrame exists");
		-- Update Owned currency display
		if frame.CostFrame.OwnedValue then
			DC.Debug("UpdateCost: Setting OwnedValue to " .. tostring(displayCurrency));
			frame.CostFrame.OwnedValue:SetText(tostring(displayCurrency));
			frame.CostFrame.OwnedValue:Show();
		else
			DC.Debug("UpdateCost: OwnedValue is nil!");
		end
		if frame.CostFrame.OwnedIcon then
			frame.CostFrame.OwnedIcon:Show();
			if displayCurrencyItemID then
				local icon = GetItemIcon(displayCurrencyItemID);
				if icon then
					frame.CostFrame.OwnedIcon:SetTexture(icon);
				end
			end
		end
		if frame.CostFrame.OwnedLabel then
			frame.CostFrame.OwnedLabel:Show();
		end
	end
	
	-- Early return if no item selected - but owned currency is already updated above
	if not DC.currentItem then 
		DC.Debug("UpdateCost: No item selected, early return after setting owned values");
		return 
	end

	local currentLevel = DC.currentItem.currentUpgrade or 0;
	local targetLevel = DC.targetUpgradeLevel or currentLevel;
	local tier = DC.currentItem.tier or 1;
	
	DC.Debug("UpdateCost: item selected, currentLevel=" .. tostring(currentLevel) .. ", targetLevel=" .. tostring(targetLevel) .. ", tier=" .. tostring(tier));

	if targetLevel <= currentLevel then 
		DC.Debug("UpdateCost: target <= current, hiding CostFrame");
		if frame.CostFrame then frame.CostFrame:Hide() end
		return 
	end
	DC.Debug("UpdateCost: showing CostFrame");
	if frame.CostFrame then frame.CostFrame:Show() end

	-- Calculate total cost for the upgrade
	local totals, missingLevel = DarkChaos_ItemUpgrade_ComputeCostTotals(tier, currentLevel, targetLevel);
	if missingLevel then
		return;
	end

	local totalTokens = (totals and totals.tokens) or 0;
	local totalEssence = (totals and totals.essence) or 0;
	local playerTokens = DC.playerTokens or 0;
	local playerEssence = DC.playerEssence or 0;
	
	-- For heirloom mode, use essence cost; for standard mode, use token cost
	local totalCost = isHeirloomMode and totalEssence or totalTokens;
	local playerCurrency = isHeirloomMode and playerEssence or playerTokens;
	local costCurrencyItemID = isHeirloomMode and DC.ESSENCE_ITEM_ID or DC.TOKEN_ITEM_ID;

	-- Determine cost color based on affordability
	local costColor;
	if totalCost <= playerCurrency then
		costColor = DC.COST_COLORS.cheap; -- Can afford
	elseif totalCost <= playerCurrency * 2 then
		costColor = DC.COST_COLORS.moderate; -- Can afford with some effort
	else
		costColor = DC.COST_COLORS.expensive; -- Expensive
	end

	-- Update Required Cost
	if frame.CostFrame and frame.CostFrame.RequiredValue then
		frame.CostFrame.RequiredValue:SetText(tostring(totalCost));
		frame.CostFrame.RequiredValue:SetTextColor(costColor.r, costColor.g, costColor.b);
		frame.CostFrame.RequiredValue:Show();
		DC.Debug("Set RequiredValue (Cost) to: " .. tostring(totalCost));
	end
	if frame.CostFrame and frame.CostFrame.RequiredLabel then
		frame.CostFrame.RequiredLabel:Show();
	end
	if frame.CostFrame and frame.CostFrame.RequiredIcon then
		frame.CostFrame.RequiredIcon:Show();
		if costCurrencyItemID then
			local icon = GetItemIcon(costCurrencyItemID);
			if icon then
				frame.CostFrame.RequiredIcon:SetTexture(icon);
			end
		end
	end

	-- Update Required Essence (hide for now since we're using single currency display)
	if frame.CostFrame and frame.CostFrame.RequiredEssenceValue then
		frame.CostFrame.RequiredEssenceValue:Hide();
		if frame.CostFrame.RequiredEssenceIcon then 
			frame.CostFrame.RequiredEssenceIcon:Hide();
		end
	end
	
	-- Hide the second currency row (OwnedEssence) since we're using single currency display
	if frame.CostFrame and frame.CostFrame.OwnedEssenceValue then
		frame.CostFrame.OwnedEssenceValue:Hide();
		if frame.CostFrame.OwnedEssenceIcon then 
			frame.CostFrame.OwnedEssenceIcon:Hide();
		end
	end
end


-- Constants
ICON_TOKEN = "|TInterface\\Icons\\INV_Misc_Coin_01:14|t";

--[[=====================================================
	UPGRADE COSTS
=======================================================]]

function DarkChaos_ItemUpgrade_InitializeCosts()
	-- Initialize cost table from database schema
	DC.upgradeCosts = {};
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

DarkChaos_ItemUpgrade_ComputeCostTotals = function(tier, currentLevel, targetLevel)
	local totals = { tokens = 0, essence = 0 };
	if not tier or not targetLevel or not currentLevel or targetLevel <= currentLevel then
		return totals, nil;
	end

	local missingLevel = nil;

	for level = currentLevel + 1, targetLevel do
		local cost = DarkChaos_ItemUpgrade_GetCost(tier, level);
		if not cost then
			missingLevel = level;
			break;
		end
		totals.tokens = totals.tokens + (cost.tokens or 0);
		totals.essence = totals.essence + (cost.essence or 0);
	end

	return totals, missingLevel;
end

local lastCurrencyRequestTime = 0;

function DarkChaos_ItemUpgrade_RequestCurrencies(force)
	local now = GetTime and GetTime() or 0;
	if not force and now - (lastCurrencyRequestTime or 0) < 1 then
		return; -- throttle spammy refreshes coming from multiple events
	end

	lastCurrencyRequestTime = now;
	lastCurrencyRequestTime = now;
	DC.RequestCurrencySync();
end

DarkChaos_ItemUpgrade_RequestItemInfo = function()
	if not DC.currentItem then return end
	local bag = DC.currentItem.serverBag or DC.currentItem.bag;
	local serverSlot = DC.currentItem.serverSlot;
	if bag == nil or serverSlot == nil then return end
	local locationKey = DC.currentItem.locationKey or BuildLocationKey(bag, serverSlot);
	DC.currentItem.locationKey = locationKey;
	DC.currentItem.serverBag = bag;
	DC.currentItem.serverSlot = serverSlot;
	local cached = DarkChaos_ItemUpgrade_GetCachedDataForLocation(bag, serverSlot);
	if cached then
		DarkChaos_ItemUpgrade_ApplyQueryData(DC.currentItem, cached);
		if cached.guid then
			DC.itemLocationCache[locationKey] = cached.guid;
		end
		DarkChaos_ItemUpgrade_UpdateUI();
	end
	DC.Debug(string.format("Refreshing item query for %d:%d", bag or -1, serverSlot or -1));
	DarkChaos_ItemUpgrade_QueueQuery(bag, serverSlot, {
		type = "refresh",
		locationKey = locationKey,
	});
end

-- Initialize costs on load
DarkChaos_ItemUpgrade_InitializeCosts();

-- Settings defaults
DC.DEFAULT_SETTINGS = {
	autoEquip = true,           -- Auto-equip upgraded items if they were equipped
	debug = false,              -- Enable debug logging
	showTooltips = true,        -- Show upgrade info in tooltips
	playSounds = true,          -- Play sound effects
	showCelebration = true,     -- Show upgrade celebration animation
	batchQueryDelay = 0.1,      -- Delay between batch queries (seconds)
	maxPoolSize = 50,           -- Maximum object pool size
	itemScanCacheLifetime = 5,  -- Item scan cache lifetime (seconds)
};

-- Load settings with defaults
DC_ItemUpgrade_Settings = DC_ItemUpgrade_Settings or {};
for key, defaultValue in pairs(DC.DEFAULT_SETTINGS) do
	if DC_ItemUpgrade_Settings[key] == nil then
		DC_ItemUpgrade_Settings[key] = defaultValue;
	end
end

-- Apply settings to runtime variables
DC.itemStatePoolSize = DC.itemStatePoolSize or 0;
DC.maxPoolSize = DC_ItemUpgrade_Settings.maxPoolSize or DC.DEFAULT_SETTINGS.maxPoolSize;
DC.itemScanCacheLifetime = DC_ItemUpgrade_Settings.itemScanCacheLifetime or DC.DEFAULT_SETTINGS.itemScanCacheLifetime;
DC.batchQueryDelay = DC_ItemUpgrade_Settings.batchQueryDelay or DC.DEFAULT_SETTINGS.batchQueryDelay;

-- Helper function to play sounds with setting check
function DC.PlaySound(soundName)
	if DC_ItemUpgrade_Settings and DC_ItemUpgrade_Settings.playSounds then
		PlaySound(soundName);
	end
end

-- Settings panel functions
function DC.CreateSettingsPanel()
	local panel = CreateFrame("Frame", "DC_ItemUpgrade_SettingsPanel", UIParent);
	panel.name = "DC ItemUpgrade";
	
	-- Title
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
	title:SetPoint("TOPLEFT", 16, -16);
	title:SetText("DC ItemUpgrade Settings");
	
	-- Auto-equip checkbox
	local autoEquipCheck = CreateFrame("CheckButton", "DC_ItemUpgrade_AutoEquipCheck", panel, "InterfaceOptionsCheckButtonTemplate");
	autoEquipCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16);
	if not autoEquipCheck.Text then
		autoEquipCheck.Text = autoEquipCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
		autoEquipCheck.Text:SetPoint("LEFT", autoEquipCheck, "RIGHT", 0, 1);
	end
	autoEquipCheck.Text:SetText("Auto-equip upgraded items");
	autoEquipCheck.tooltipText = "When upgrading an equipped item, automatically place the upgraded version back in the same equipment slot.";
	autoEquipCheck:SetChecked(DC_ItemUpgrade_Settings.autoEquip);
	autoEquipCheck:SetScript("OnClick", function(self)
		DC_ItemUpgrade_Settings.autoEquip = self:GetChecked();
		if self:GetChecked() then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Auto-equip enabled.", 0.4, 0.9, 1.0);
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Auto-equip disabled.", 0.4, 0.9, 1.0);
		end
	end);
	
	-- Debug checkbox
	local debugCheck = CreateFrame("CheckButton", "DC_ItemUpgrade_DebugCheck", panel, "InterfaceOptionsCheckButtonTemplate");
	debugCheck:SetPoint("TOPLEFT", autoEquipCheck, "BOTTOMLEFT", 0, -8);
	if not debugCheck.Text then
		debugCheck.Text = debugCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
		debugCheck.Text:SetPoint("LEFT", debugCheck, "RIGHT", 0, 1);
	end
	debugCheck.Text:SetText("Enable debug logging");
	debugCheck.tooltipText = "Show detailed debug information in the debug frame and chat.";
	debugCheck:SetChecked(DC_ItemUpgrade_Settings.debug);
	debugCheck:SetScript("OnClick", function(self)
		DC_ItemUpgrade_Settings.debug = self:GetChecked();
		if self:GetChecked() then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Debug logging enabled.", 0.4, 0.9, 1.0);
			if DarkChaos_ItemUpgrade_DebugFrame then
				DarkChaos_ItemUpgrade_DebugFrame:Show();
			end
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Debug logging disabled.", 0.4, 0.9, 1.0);
			if DarkChaos_ItemUpgrade_DebugFrame then
				DarkChaos_ItemUpgrade_DebugFrame:Hide();
			end
		end
	end);
	
	-- Show tooltips checkbox
	local tooltipsCheck = CreateFrame("CheckButton", "DC_ItemUpgrade_TooltipsCheck", panel, "InterfaceOptionsCheckButtonTemplate");
	tooltipsCheck:SetPoint("TOPLEFT", debugCheck, "BOTTOMLEFT", 0, -8);
	if not tooltipsCheck.Text then
		tooltipsCheck.Text = tooltipsCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
		tooltipsCheck.Text:SetPoint("LEFT", tooltipsCheck, "RIGHT", 0, 1);
	end
	tooltipsCheck.Text:SetText("Show upgrade info in tooltips");
	tooltipsCheck.tooltipText = "Display upgrade level and stat information when hovering over items.";
	tooltipsCheck:SetChecked(DC_ItemUpgrade_Settings.showTooltips);
	tooltipsCheck:SetScript("OnClick", function(self)
		DC_ItemUpgrade_Settings.showTooltips = self:GetChecked();
		if self:GetChecked() then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Tooltip info enabled.", 0.4, 0.9, 1.0);
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Tooltip info disabled.", 0.4, 0.9, 1.0);
		end
	end);
	
	-- Play sounds checkbox
	local soundsCheck = CreateFrame("CheckButton", "DC_ItemUpgrade_SoundsCheck", panel, "InterfaceOptionsCheckButtonTemplate");
	soundsCheck:SetPoint("TOPLEFT", tooltipsCheck, "BOTTOMLEFT", 0, -8);
	if not soundsCheck.Text then
		soundsCheck.Text = soundsCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
		soundsCheck.Text:SetPoint("LEFT", soundsCheck, "RIGHT", 0, 1);
	end
	soundsCheck.Text:SetText("Play sound effects");
	soundsCheck.tooltipText = "Play sound effects for upgrade success and UI interactions.";
	soundsCheck:SetChecked(DC_ItemUpgrade_Settings.playSounds);
	soundsCheck:SetScript("OnClick", function(self)
		DC_ItemUpgrade_Settings.playSounds = self:GetChecked();
		if self:GetChecked() then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Sound effects enabled.", 0.4, 0.9, 1.0);
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Sound effects disabled.", 0.4, 0.9, 1.0);
		end
	end);
	
	-- Show celebration checkbox
	local celebrationCheck = CreateFrame("CheckButton", "DC_ItemUpgrade_CelebrationCheck", panel, "InterfaceOptionsCheckButtonTemplate");
	celebrationCheck:SetPoint("TOPLEFT", soundsCheck, "BOTTOMLEFT", 0, -8);
	if not celebrationCheck.Text then
		celebrationCheck.Text = celebrationCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
		celebrationCheck.Text:SetPoint("LEFT", celebrationCheck, "RIGHT", 0, 1);
	end
	celebrationCheck.Text:SetText("Show upgrade celebration");
	celebrationCheck.tooltipText = "Display animation effects when items are successfully upgraded.";
	celebrationCheck:SetChecked(DC_ItemUpgrade_Settings.showCelebration);
	celebrationCheck:SetScript("OnClick", function(self)
		DC_ItemUpgrade_Settings.showCelebration = self:GetChecked();
		if self:GetChecked() then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Celebration effects enabled.", 0.4, 0.9, 1.0);
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Celebration effects disabled.", 0.4, 0.9, 1.0);
		end
	end);
	
	-- Performance settings header
	local perfHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal");
	perfHeader:SetPoint("TOPLEFT", celebrationCheck, "BOTTOMLEFT", 0, -16);
	perfHeader:SetText("Performance Settings");
	
	-- Ensure settings have default values
	local batchDelay = DC_ItemUpgrade_Settings.batchQueryDelay or DC.DEFAULT_SETTINGS.batchQueryDelay or 0.1;
	local cacheLifetime = DC_ItemUpgrade_Settings.itemScanCacheLifetime or DC.DEFAULT_SETTINGS.itemScanCacheLifetime or 5;
	
	-- Batch query delay slider
	local delaySlider = CreateFrame("Slider", "DC_ItemUpgrade_DelaySlider", panel, "OptionsSliderTemplate");
	delaySlider:SetPoint("TOPLEFT", perfHeader, "BOTTOMLEFT", 0, -24);
	delaySlider:SetWidth(200);
	delaySlider:SetMinMaxValues(0.05, 0.5);
	delaySlider:SetValueStep(0.05);
	delaySlider:SetValue(batchDelay);
	
	DC_ItemUpgrade_DelaySliderText:SetText("Batch Query Delay: " .. string.format("%.2fs", batchDelay));
	DC_ItemUpgrade_DelaySliderLow:SetText("0.05s");
	DC_ItemUpgrade_DelaySliderHigh:SetText("0.5s");
	
	delaySlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value * 100 + 0.5) / 100; -- Round to 2 decimal places
		DC_ItemUpgrade_Settings.batchQueryDelay = value;
		DC.batchQueryDelay = value;
		DC_ItemUpgrade_DelaySliderText:SetText("Batch Query Delay: " .. string.format("%.2fs", value));
	end);
	
	local delayDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
	delayDesc:SetPoint("TOPLEFT", delaySlider, "BOTTOMLEFT", 0, -4);
	delayDesc:SetWidth(300);
	delayDesc:SetText("Delay between batch server queries. Lower values are faster but may cause lag.");
	delayDesc:SetTextColor(0.8, 0.8, 0.8);
	
	-- Cache lifetime slider
	local cacheSlider = CreateFrame("Slider", "DC_ItemUpgrade_CacheSlider", panel, "OptionsSliderTemplate");
	cacheSlider:SetPoint("TOPLEFT", delayDesc, "BOTTOMLEFT", 0, -16);
	cacheSlider:SetWidth(200);
	cacheSlider:SetMinMaxValues(1, 15);
	cacheSlider:SetValueStep(1);
	cacheSlider:SetValue(cacheLifetime);
	
	DC_ItemUpgrade_CacheSliderText:SetText("Cache Lifetime: " .. cacheLifetime .. "s");
	DC_ItemUpgrade_CacheSliderLow:SetText("1s");
	DC_ItemUpgrade_CacheSliderHigh:SetText("15s");
	
	cacheSlider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5);
		DC_ItemUpgrade_Settings.itemScanCacheLifetime = value;
		DC.itemScanCacheLifetime = value;
		DC_ItemUpgrade_CacheSliderText:SetText("Cache Lifetime: " .. value .. "s");
	end);
	
	local cacheDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
	cacheDesc:SetPoint("TOPLEFT", cacheSlider, "BOTTOMLEFT", 0, -4);
	cacheDesc:SetWidth(300);
	cacheDesc:SetText("How long to cache item scan results. Higher values reduce server queries but may show stale data.");
	cacheDesc:SetTextColor(0.8, 0.8, 0.8);
	
	-- Reset to defaults button
	local resetButton = CreateFrame("Button", "DC_ItemUpgrade_ResetButton", panel, "UIPanelButtonTemplate");
	resetButton:SetPoint("TOPLEFT", cacheDesc, "BOTTOMLEFT", 0, -16);
	resetButton:SetWidth(120);
	resetButton:SetHeight(24);
	resetButton:SetText("Reset to Defaults");
	resetButton:SetScript("OnClick", function()
		for key, defaultValue in pairs(DC.DEFAULT_SETTINGS) do
			DC_ItemUpgrade_Settings[key] = defaultValue;
		end
		
		-- Update UI elements
		autoEquipCheck:SetChecked(DC_ItemUpgrade_Settings.autoEquip);
		debugCheck:SetChecked(DC_ItemUpgrade_Settings.debug);
		tooltipsCheck:SetChecked(DC_ItemUpgrade_Settings.showTooltips);
		soundsCheck:SetChecked(DC_ItemUpgrade_Settings.playSounds);
		celebrationCheck:SetChecked(DC_ItemUpgrade_Settings.showCelebration);
		delaySlider:SetValue(DC_ItemUpgrade_Settings.batchQueryDelay);
		cacheSlider:SetValue(DC_ItemUpgrade_Settings.itemScanCacheLifetime);
		
		-- Apply settings
		DC.maxPoolSize = DC_ItemUpgrade_Settings.maxPoolSize;
		DC.itemScanCacheLifetime = DC_ItemUpgrade_Settings.itemScanCacheLifetime;
		DC.batchQueryDelay = DC_ItemUpgrade_Settings.batchQueryDelay;
		
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Settings reset to defaults.", 0.4, 0.9, 1.0);
	end);
	
	-- Version info
	local versionText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall");
	versionText:SetPoint("BOTTOMLEFT", 16, 16);
	versionText:SetText("DC ItemUpgrade v1.0.0");
	versionText:SetTextColor(0.6, 0.6, 0.6);
	
	InterfaceOptions_AddCategory(panel);
	
	-- Store panel reference for opening later
	DC.settingsPanel = panel;
	
	return panel;
end

--[[=====================================================
	SLASH COMMANDS
=======================================================]]

-- Helper function to open settings panel (3.3.5a compatible)
function DC.OpenSettingsPanel()
	if DC.settingsPanel then
		-- Try with panel object first (more reliable in 3.3.5)
		InterfaceOptionsFrame_OpenToCategory(DC.settingsPanel);
		InterfaceOptionsFrame_OpenToCategory(DC.settingsPanel); -- Called twice due to WoW bug
	else
		-- Fallback: try by name
		InterfaceOptionsFrame_OpenToCategory("DC ItemUpgrade");
		InterfaceOptionsFrame_OpenToCategory("DC ItemUpgrade");
	end
end

-- Register slash commands
SLASH_DCUPGRADE1 = "/dcupgrade";
SLASH_DCUPGRADE2 = "/dcu";
SLASH_DCUPGRADE3 = "/upgrade";

SlashCmdList["DCUPGRADE"] = function(msg)
	local cmd = string.lower(msg or "");
	local args = {};
	for word in string.gmatch(cmd, "%S+") do
		table.insert(args, word);
	end
	local subcmd = args[1] or "";
	
	if subcmd == "" or subcmd == "help" then
		-- Show help
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff=== DC ItemUpgrade Commands ===|r");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu|r - Open upgrade window");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu heirloom|r - Open heirloom upgrade window");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu packages|r - List available stat packages");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu package <id>|r - Select stat package (1-12)");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu history [n]|r - Show last N upgrades (default 20)");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu history clear|r - Clear upgrade history");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu settings|r - Open settings panel");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu debug|r - Toggle debug mode");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu sound|r - Toggle sound effects");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu tooltip|r - Toggle tooltip info");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu itemid|r - Toggle item ID display");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu celebrate|r - Toggle celebration effects");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu autoequip|r - Toggle auto-equip");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu status|r - Show current settings status");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu reset|r - Reset all settings to defaults");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu cache clear|r - Clear item cache");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu help|r - Show this help");
		
	elseif subcmd == "heirloom" or subcmd == "h" then
		-- Open heirloom upgrade window
		if UnitAffectingCombat("player") then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000You cannot upgrade items while in combat!|r");
			return;
		end
		DC.uiMode = "HEIRLOOM";
		if DarkChaos_ItemUpgradeFrame then
			DarkChaos_ItemUpgradeFrame:Show();
			DarkChaos_ItemUpgradeFrame.TitleText:SetText("Heirloom Upgrade");
		end
		
	elseif subcmd == "packages" or subcmd == "pkgs" then
		-- List all stat packages
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff=== Heirloom Stat Packages ===|r");
		for i = 1, 12 do
			local pkg = DC.STAT_PACKAGES[i];
			if pkg then
				local selected = (DC.selectedStatPackage == i) and " |cff00ff00[SELECTED]|r" or "";
				local colorHex = string.format("%.2x%.2x%.2x", pkg.color.r*255, pkg.color.g*255, pkg.color.b*255);
				DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffffcc00%d.|r |cff%s%s|r - %s%s", 
					i, colorHex, pkg.name, table.concat(pkg.stats, ", "), selected));
			end
		end
		DEFAULT_CHAT_FRAME:AddMessage("|cff888888Use /dcu package <number> to select a package.|r");
		
	elseif subcmd == "package" or subcmd == "pkg" then
		-- Select a stat package by ID
		local pkgId = tonumber(args[2]);
		if not pkgId or pkgId < 1 or pkgId > 12 then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Invalid package ID. Use 1-12. Type /dcu packages for list.|r");
			return;
		end
		DarkChaos_ItemUpgrade_SelectStatPackage(pkgId);
		
	elseif subcmd == "history" then
		if args[2] == "clear" then
			if DC.ClearUpgradeHistory then
				DC.ClearUpgradeHistory();
			end
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Upgrade history cleared.");
			return;
		end

		local count = tonumber(args[2]) or 20;
		if count < 1 then count = 1; end
		if count > 200 then count = 200; end

		local history = DC.GetUpgradeHistory and DC.GetUpgradeHistory() or nil;
		if not history or #history == 0 then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r No upgrade history yet.");
			return;
		end

		DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ccff=== Upgrade History (showing %d of %d) ===|r", math.min(count, #history), #history));
		for i = 1, math.min(count, #history) do
			local line = (DC.FormatUpgradeHistoryEntry and DC.FormatUpgradeHistoryEntry(history[i])) or "";
			if line ~= "" then
				DEFAULT_CHAT_FRAME:AddMessage(line);
			end
		end
		
	elseif subcmd == "settings" or subcmd == "config" or subcmd == "options" then
		-- Open settings panel
		DC.OpenSettingsPanel();
		
	elseif subcmd == "debug" then
		-- Toggle debug mode
		DC_ItemUpgrade_Settings.debug = not DC_ItemUpgrade_Settings.debug;
		if DC_ItemUpgrade_Settings.debug then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Debug mode |cff00ff00ENABLED|r");
			if DarkChaos_ItemUpgrade_DebugFrame then
				DarkChaos_ItemUpgrade_DebugFrame:Show();
			end
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Debug mode |cffff0000DISABLED|r");
			if DarkChaos_ItemUpgrade_DebugFrame then
				DarkChaos_ItemUpgrade_DebugFrame:Hide();
			end
		end
		
	elseif subcmd == "sound" or subcmd == "sounds" then
		-- Toggle sounds
		DC_ItemUpgrade_Settings.playSounds = not DC_ItemUpgrade_Settings.playSounds;
		local status = DC_ItemUpgrade_Settings.playSounds and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r";
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Sound effects " .. status);
		
	elseif subcmd == "tooltip" or subcmd == "tooltips" then
		-- Toggle tooltips
		DC_ItemUpgrade_Settings.showTooltips = not DC_ItemUpgrade_Settings.showTooltips;
		local status = DC_ItemUpgrade_Settings.showTooltips and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r";
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Tooltip info " .. status);
		
	elseif subcmd == "itemid" or subcmd == "itemids" or subcmd == "id" then
		-- Toggle item ID display in tooltips
		DC.showItemIDsInTooltips = not DC.showItemIDsInTooltips;
		local status = DC.showItemIDsInTooltips and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r";
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Item ID display " .. status);
		
	elseif subcmd == "celebrate" or subcmd == "celebration" then
		-- Toggle celebration effects
		DC_ItemUpgrade_Settings.showCelebration = not DC_ItemUpgrade_Settings.showCelebration;
		local status = DC_ItemUpgrade_Settings.showCelebration and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r";
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Celebration effects " .. status);
		
	elseif subcmd == "autoequip" or subcmd == "auto" then
		-- Toggle auto-equip
		DC_ItemUpgrade_Settings.autoEquip = not DC_ItemUpgrade_Settings.autoEquip;
		local status = DC_ItemUpgrade_Settings.autoEquip and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r";
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Auto-equip " .. status);
		
	elseif subcmd == "status" then
		-- Show current settings
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff=== DC ItemUpgrade Status ===|r");
		local function statusColor(val) return val and "|cff00ff00ON|r" or "|cffff0000OFF|r"; end
		DEFAULT_CHAT_FRAME:AddMessage("Debug Mode: " .. statusColor(DC_ItemUpgrade_Settings.debug));
		DEFAULT_CHAT_FRAME:AddMessage("Sound Effects: " .. statusColor(DC_ItemUpgrade_Settings.playSounds));
		DEFAULT_CHAT_FRAME:AddMessage("Tooltip Info: " .. statusColor(DC_ItemUpgrade_Settings.showTooltips));
		DEFAULT_CHAT_FRAME:AddMessage("Item ID Display: " .. statusColor(DC.showItemIDsInTooltips));
		DEFAULT_CHAT_FRAME:AddMessage("Celebration: " .. statusColor(DC_ItemUpgrade_Settings.showCelebration));
		DEFAULT_CHAT_FRAME:AddMessage("Auto-Equip: " .. statusColor(DC_ItemUpgrade_Settings.autoEquip));
		DEFAULT_CHAT_FRAME:AddMessage("Batch Delay: |cffffcc00" .. string.format("%.2fs", DC_ItemUpgrade_Settings.batchQueryDelay or 0.1) .. "|r");
		DEFAULT_CHAT_FRAME:AddMessage("Cache Lifetime: |cffffcc00" .. (DC_ItemUpgrade_Settings.itemScanCacheLifetime or 5) .. "s|r");
		DEFAULT_CHAT_FRAME:AddMessage("Tokens: |cffffcc00" .. (DC.playerTokens or 0) .. "|r | Essence: |cffffcc00" .. (DC.playerEssence or 0) .. "|r");
		-- Show selected stat package
		if DC.selectedStatPackage and DC.STAT_PACKAGES[DC.selectedStatPackage] then
			local pkg = DC.STAT_PACKAGES[DC.selectedStatPackage];
			local colorHex = string.format("%.2x%.2x%.2x", pkg.color.r*255, pkg.color.g*255, pkg.color.b*255);
			DEFAULT_CHAT_FRAME:AddMessage(string.format("Stat Package: |cff%s%s|r (%s)", colorHex, pkg.name, table.concat(pkg.stats, ", ")));
		else
			DEFAULT_CHAT_FRAME:AddMessage("Stat Package: |cff888888None selected|r");
		end
		
	elseif subcmd == "reset" then
		-- Reset to defaults
		for key, defaultValue in pairs(DC.DEFAULT_SETTINGS) do
			DC_ItemUpgrade_Settings[key] = defaultValue;
		end
		DC.maxPoolSize = DC.DEFAULT_SETTINGS.maxPoolSize;
		DC.itemScanCacheLifetime = DC.DEFAULT_SETTINGS.itemScanCacheLifetime;
		DC.batchQueryDelay = DC.DEFAULT_SETTINGS.batchQueryDelay;
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r All settings reset to defaults.");
		
	elseif subcmd == "cache" then
		local cacheCmd = args[2] or "";
		if cacheCmd == "clear" then
			-- Clear caches
			DC.itemUpgradeCache = {};
			DC.itemLocationCache = {};
			DC.itemScanCache = {};
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Item cache cleared.");
		else
			-- Show cache stats
			local upgradeCount = 0;
			for _ in pairs(DC.itemUpgradeCache or {}) do upgradeCount = upgradeCount + 1; end
			local locationCount = 0;
			for _ in pairs(DC.itemLocationCache or {}) do locationCount = locationCount + 1; end
			local scanCount = 0;
			for _ in pairs(DC.itemScanCache or {}) do scanCount = scanCount + 1; end
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff=== DC ItemUpgrade Cache Stats ===|r");
			DEFAULT_CHAT_FRAME:AddMessage("Upgrade Cache: |cffffcc00" .. upgradeCount .. "|r entries");
			DEFAULT_CHAT_FRAME:AddMessage("Location Cache: |cffffcc00" .. locationCount .. "|r entries");
			DEFAULT_CHAT_FRAME:AddMessage("Scan Cache: |cffffcc00" .. scanCount .. "|r entries");
			DEFAULT_CHAT_FRAME:AddMessage("Use |cffffcc00/dcu cache clear|r to clear caches.");
		end
		
	else
		-- Default: open upgrade window
		if UnitAffectingCombat("player") then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000You cannot upgrade items while in combat!|r");
			return;
		end
		DC.uiMode = "STANDARD";
		if DarkChaos_ItemUpgradeFrame then
			if DarkChaos_ItemUpgradeFrame:IsShown() then
				DarkChaos_ItemUpgradeFrame:Hide();
			else
				DarkChaos_ItemUpgradeFrame:Show();
				DarkChaos_ItemUpgradeFrame.TitleText:SetText("Item Upgrade");
			end
		end
	end
end

-- Print startup message with commands hint
local function PrintStartupMessage()
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffDC ItemUpgrade|r loaded. Type |cffffcc00/dcu help|r for commands.", 0.4, 0.9, 1.0);
end

-- Delay startup message until player enters world (3.3.5a compatible timer)
local startupFrame = CreateFrame("Frame");
startupFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
startupFrame.elapsed = 0;
startupFrame.delay = 2;
startupFrame.waiting = false;
startupFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_ENTERING_WORLD" then
		self.waiting = true;
		self:SetScript("OnUpdate", function(self, elapsed)
			if not self.waiting then return; end
			self.elapsed = self.elapsed + elapsed;
			if self.elapsed >= self.delay then
				PrintStartupMessage();
				self.waiting = false;
				self:SetScript("OnUpdate", nil);
			end
		end);
		self:UnregisterEvent("PLAYER_ENTERING_WORLD");
	end
end);

--[[=====================================================
	QUICK SETTINGS DROPDOWN MENU
=======================================================]]

function DarkChaos_ItemUpgrade_ShowQuickSettings()
	local menu = {
		{ text = "DC ItemUpgrade Settings", isTitle = true, notCheckable = true },
		{ text = " ", isTitle = true, notCheckable = true }, -- Spacer
		{
			text = "Debug Mode",
			checked = function() return DC_ItemUpgrade_Settings.debug; end,
			func = function()
				DC_ItemUpgrade_Settings.debug = not DC_ItemUpgrade_Settings.debug;
				if DC_ItemUpgrade_Settings.debug then
					if DarkChaos_ItemUpgrade_DebugFrame then DarkChaos_ItemUpgrade_DebugFrame:Show(); end
				else
					if DarkChaos_ItemUpgrade_DebugFrame then DarkChaos_ItemUpgrade_DebugFrame:Hide(); end
				end
			end,
		},
		{
			text = "Sound Effects",
			checked = function() return DC_ItemUpgrade_Settings.playSounds; end,
			func = function()
				DC_ItemUpgrade_Settings.playSounds = not DC_ItemUpgrade_Settings.playSounds;
			end,
		},
		{
			text = "Tooltip Info",
			checked = function() return DC_ItemUpgrade_Settings.showTooltips; end,
			func = function()
				DC_ItemUpgrade_Settings.showTooltips = not DC_ItemUpgrade_Settings.showTooltips;
			end,
		},
		{
			text = "Celebration Effects",
			checked = function() return DC_ItemUpgrade_Settings.showCelebration; end,
			func = function()
				DC_ItemUpgrade_Settings.showCelebration = not DC_ItemUpgrade_Settings.showCelebration;
			end,
		},
		{
			text = "Auto-Equip Items",
			checked = function() return DC_ItemUpgrade_Settings.autoEquip; end,
			func = function()
				DC_ItemUpgrade_Settings.autoEquip = not DC_ItemUpgrade_Settings.autoEquip;
			end,
		},
		{ text = " ", isTitle = true, notCheckable = true }, -- Spacer
		{
			text = "Open Full Settings",
			notCheckable = true,
			func = function()
				DC.OpenSettingsPanel();
			end,
		},
		{
			text = "Clear Item Cache",
			notCheckable = true,
			func = function()
				DC.itemUpgradeCache = {};
				DC.itemLocationCache = {};
				DC.itemScanCache = {};
				DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Item cache cleared.");
			end,
		},
		{ text = " ", isTitle = true, notCheckable = true }, -- Spacer
		{ text = "Cancel", notCheckable = true },
	};
	
	-- Use EasyMenu if available (common in 3.3.5 addons), otherwise use dropdown
	if EasyMenu then
		local menuFrame = CreateFrame("Frame", "DarkChaos_ItemUpgrade_QuickMenu", UIParent, "UIDropDownMenuTemplate");
		EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU");
	else
		-- Fallback: Create dropdown menu manually
		local menuFrame = _G["DarkChaos_ItemUpgrade_QuickMenu"] or CreateFrame("Frame", "DarkChaos_ItemUpgrade_QuickMenu", UIParent, "UIDropDownMenuTemplate");
		UIDropDownMenu_Initialize(menuFrame, function(self, level)
			for _, item in ipairs(menu) do
				local info = UIDropDownMenu_CreateInfo();
				info.text = item.text;
				info.isTitle = item.isTitle;
				info.notCheckable = item.notCheckable;
				info.checked = item.checked;
				info.func = item.func;
				info.keepShownOnClick = not item.notCheckable;
				UIDropDownMenu_AddButton(info, level);
			end
		end, "MENU");
		ToggleDropDownMenu(1, nil, menuFrame, "cursor", 0, 0);
	end
end

-- Character Frame Button Handlers (XML-defined button)
function DC_ItemUpgrade_CharFrameButton_OnLoad(self)
	self:RegisterForClicks("LeftButtonUp");
end

function DC_ItemUpgrade_CharFrameButton_OnClick(self)
	if UnitAffectingCombat("player") then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000You cannot upgrade items while in combat!|r");
		return;
	end
	
	local inInstance, instanceType = IsInInstance();
	if inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "arena" or instanceType == "pvp") then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000You cannot upgrade items while in an instance!|r");
		return;
	end
	
	DC.uiMode = "STANDARD";
	if DarkChaos_ItemUpgradeFrame:IsShown() then
		DarkChaos_ItemUpgradeFrame:Hide();
	else
		DarkChaos_ItemUpgradeFrame:Show();
		DarkChaos_ItemUpgradeFrame.TitleText:SetText("Item Upgrade");
	end
end

-- Heirloom Button Handlers (XML-defined button)
function DC_ItemUpgrade_HeirloomButton_OnLoad(self)
	self:RegisterForClicks("LeftButtonUp");
end

function DC_ItemUpgrade_HeirloomButton_OnClick(self)
	if UnitAffectingCombat("player") then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000You cannot upgrade items while in combat!|r");
		return;
	end
	
	local inInstance, instanceType = IsInInstance();
	if inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "arena" or instanceType == "pvp") then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000You cannot upgrade items while in an instance!|r");
		return;
	end
	
	DC.uiMode = "HEIRLOOM";
	
	if DarkChaos_ItemUpgradeFrame:IsShown() then
		DarkChaos_ItemUpgradeFrame:Hide();
	else
		DarkChaos_ItemUpgradeFrame:Show();
		DarkChaos_ItemUpgradeFrame.TitleText:SetText("Heirloom Upgrade");
		-- Auto-find and select the heirloom shirt
		DarkChaos_ItemUpgrade_AutoSelectHeirloomShirt();
	end
end

-- Bag Frame Button Handlers (XML-defined button)
function DC_ItemUpgrade_BagFrameButton_OnLoad(self)
	self:RegisterForClicks("LeftButtonUp");
	self:SetFrameStrata("MEDIUM");
end

function DC_ItemUpgrade_BagFrameButton_OnClick(self)
	if UnitAffectingCombat("player") then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000You cannot upgrade items while in combat!|r");
		return;
	end
	
	local inInstance, instanceType = IsInInstance();
	if inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "arena" or instanceType == "pvp") then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000You cannot upgrade items while in an instance!|r");
		return;
	end
	
	if DarkChaos_ItemUpgradeFrame:IsShown() then
		DarkChaos_ItemUpgradeFrame:Hide();
	else
		DarkChaos_ItemUpgradeFrame:Show();
	end
end

-- Memory pooling for ItemUpgradeState objects
DC.itemStatePool = DC.itemStatePool or {};
DC.itemStatePoolSize = DC.itemStatePoolSize or 0;
DC.maxPoolSize = DC.maxPoolSize or 50;

-- Batch query system
DC.batchQueryQueue = DC.batchQueryQueue or {};
DC.batchQueryTimer = DC.batchQueryTimer or 0;
DC.batchQueryDelay = DC.batchQueryDelay or 0.1; -- 100ms delay for batching

-- Optimized item scanning cache
DC.itemScanCache = DC.itemScanCache or {};
DC.itemScanCacheTime = DC.itemScanCacheTime or 0;
DC.itemScanCacheLifetime = DC.itemScanCacheLifetime or 5; -- 5 seconds cache lifetime

-- Bag constants
local BAG_BACKPACK = 0;
local BAG_BANK = _G.BANK_CONTAINER or -1;
local BAG_EQUIPPED = _G.INVENTORY_SLOT_BAG_0 or 255;

-- Equipment slots for scanning
local EQUIPMENT_SLOTS = {
	_G.INVSLOT_HEAD or 1,
	_G.INVSLOT_NECK or 2,
	_G.INVSLOT_SHOULDER or 3,
	_G.INVSLOT_BODY or 4,
	_G.INVSLOT_CHEST or 5,
	_G.INVSLOT_WAIST or 6,
	_G.INVSLOT_LEGS or 7,
	_G.INVSLOT_FEET or 8,
	_G.INVSLOT_WRIST or 9,
	_G.INVSLOT_HAND or 10,
	_G.INVSLOT_FINGER1 or 11,
	_G.INVSLOT_FINGER2 or 12,
	_G.INVSLOT_TRINKET1 or 13,
	_G.INVSLOT_TRINKET2 or 14,
	_G.INVSLOT_BACK or 15,
	_G.INVSLOT_MAINHAND or 16,
	_G.INVSLOT_OFFHAND or 17,
	_G.INVSLOT_RANGED or 18,
	_G.INVSLOT_TABARD or 19,
};

-- Helper functions for bag/slot conversion
local function IsEquippedBag(bag)
	return bag == BAG_EQUIPPED;
end

local function GetServerSlotFromClient(bag, slot)
	-- For equipped items (bag 255), convert from client 1-indexed to server 0-indexed
	-- Client: HEAD=1, NECK=2, SHOULDERS=3, BODY=4, CHEST=5, etc.
	-- Server: HEAD=0, NECK=1, SHOULDERS=2, BODY=3, CHEST=4, etc.
	if IsEquippedBag(bag) then
		return math.max(0, (slot or 1) - 1);  -- Subtract 1 to convert to 0-indexed
	end
	
	-- For bag items, subtract 1 to convert from 1-indexed to 0-indexed
	local normalizedSlot = math.max(0, (slot or 1) - 1);
	if bag == BAG_BANK then
		return BANK_SLOT_ITEM_START + normalizedSlot;
	end
	return normalizedSlot;
end

local function GetServerBagFromClient(bag)
	if IsEquippedBag(bag) then
		return BAG_EQUIPPED;
	end

	if bag == BAG_BANK then
		return BAG_EQUIPPED;
	end

	return bag;
end

local function BuildLocationKey(bag, slot)
	return string.format("%d:%d", bag or -1, slot or -1);
end

-- Helper function to get pooled ItemUpgradeState object
function DC.GetPooledItemState()
	if DC.itemStatePoolSize > 0 then
		local state = DC.itemStatePool[DC.itemStatePoolSize];
		DC.itemStatePool[DC.itemStatePoolSize] = nil;
		DC.itemStatePoolSize = DC.itemStatePoolSize - 1;
		return state;
	end
	return {};
end

-- Helper function to return ItemUpgradeState object to pool
function DC.ReturnPooledItemState(state)
	if not state or DC.itemStatePoolSize >= DC.maxPoolSize then
		return;
	end
	
	-- Clear the object
	for k in pairs(state) do
		state[k] = nil;
	end
	
	DC.itemStatePoolSize = DC.itemStatePoolSize + 1;
	DC.itemStatePool[DC.itemStatePoolSize] = state;
end

-- Batch query processing
function DC.ProcessBatchQueries()
	if #DC.batchQueryQueue == 0 then
		return;
	end

	DC.Debug(string.format("ProcessBatchQueries: flushing %d pending requests (inFlight=%s, queued=%d)",
		#DC.batchQueryQueue,
		tostring(DC.queryInFlight ~= nil),
		#DC.queryQueueList));

	-- Move pending requests into the sequential queue so responses can be tracked reliably.
	for _, request in ipairs(DC.batchQueryQueue) do
		table.insert(DC.queryQueueList, request);
	end

	DC.batchQueryQueue = {};
	
	DC.Debug("ProcessBatchQueries: Queue now has " .. #DC.queryQueueList .. " items");

	if not DC.queryInFlight then
		DC.Debug("ProcessBatchQueries: Starting query processing");
		DarkChaos_ItemUpgrade_StartNextQuery();
	else
		DC.Debug("ProcessBatchQueries: Query already in flight, will continue after response");
	end
end

-- Optimized item scanning with caching
function DC.GetScannedItems()
	local now = GetTime and GetTime() or 0;
	
	-- Return cached results if still valid
	if DC.itemScanCacheTime and (now - DC.itemScanCacheTime) < DC.itemScanCacheLifetime then
		return DC.itemScanCache;
	end
	
	-- Clear old cache
	DC.itemScanCache = {};
	
	-- Scan equipped items
	for _, slotID in ipairs(EQUIPMENT_SLOTS) do
		local link = GetInventoryItemLink("player", slotID);
		if link then
			local name, _, quality, _, _, _, _, _, equipLoc = GetItemInfo(link);
			-- Include common+ equipment (tier-1 items can be common). Avoid caching non-equippable items.
			if quality and quality >= 1 and equipLoc and equipLoc ~= "" then
				local serverBag = GetServerBagFromClient(BAG_EQUIPPED);
				local serverSlot = GetServerSlotFromClient(BAG_EQUIPPED, slotID);
				local key = BuildLocationKey(serverBag, serverSlot);
				
				DC.itemScanCache[key] = {
					bag = BAG_EQUIPPED,
					serverBag = serverBag,
					slot = slotID,
					serverSlot = serverSlot,
					link = link,
					name = name,
					quality = quality,
					isEquipped = true,
					lastSeen = now,
				};
			end
		end
	end
	
	-- Scan bag items
	for bag = BAG_BACKPACK, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot);
			if link then
				local name, _, quality, _, _, _, _, _, equipLoc = GetItemInfo(link);
				-- Include common+ equipment (tier-1 items can be common). Avoid caching non-equippable items.
				if quality and quality >= 1 and equipLoc and equipLoc ~= "" then
					local serverBag = GetServerBagFromClient(bag);
					local serverSlot = GetServerSlotFromClient(bag, slot);
					local key = BuildLocationKey(serverBag, serverSlot);
					
					DC.itemScanCache[key] = {
						bag = bag,
						serverBag = serverBag,
						slot = slot,
						serverSlot = serverSlot,
						link = link,
						name = name,
						quality = quality,
						isEquipped = false,
						lastSeen = now,
					};
				end
			end
		end
	end
	
	DC.itemScanCacheTime = now;
	return DC.itemScanCache;
end

-- Create simulated item link for upgrade preview
function DC.CreateUpgradePreviewItemLink(baseItemLink, targetUpgradeLevel, tier)
	if not baseItemLink or not targetUpgradeLevel then
		return baseItemLink;
	end
	
	if DC.currentItem then
		local cloneEntry = GetCloneEntryForLevel(DC.currentItem, targetUpgradeLevel);
		if cloneEntry then
			local cloneLink = select(2, GetItemInfo(cloneEntry));
			if cloneLink and cloneLink ~= "" then
				return cloneLink;
			end
			return "item:" .. tostring(cloneEntry);
		end
	end

	-- Parse the base item link
	local itemString = baseItemLink:match("item:([^|]+)");
	if not itemString then
		return baseItemLink;
	end
	
	local parts = {};
	for part in itemString:gmatch("([^:]+)") do
		table.insert(parts, part);
	end
	
	if #parts < 9 then
		return baseItemLink; -- Not enough parts to modify
	end
	
	-- Calculate upgraded item level using shared helpers
	local currentItem = DC.currentItem;
	local tierId = ClampTier(tier or (currentItem and currentItem.tier) or 1);
	local baseItemLevel = 0;
	if currentItem then
		local observedLevel = currentItem.upgradedLevel or currentItem.level or 0;
		local deduction = GetItemLevelBonus(currentItem.currentUpgrade or 0, tierId);
		local derivedBase = currentItem.baseLevel or (observedLevel - deduction);
		baseItemLevel = math.max(0, math.floor(derivedBase + 0.5));
	else
		baseItemLevel = tonumber(parts[8]) or 0;
	end

	local upgradedItemLevel = GetUpgradedItemLevel(baseItemLevel, targetUpgradeLevel, tierId);
	upgradedItemLevel = math.floor(upgradedItemLevel + 0.5);
	
	-- Create new item string with upgraded item level
	local newItemString = string.format("%s:%s:%s:%s:%s:%s:%s:%d:%s",
		parts[1], -- itemID
		parts[2] or "0", -- enchant
		parts[3] or "0", -- gem1
		parts[4] or "0", -- gem2
		parts[5] or "0", -- gem3
		parts[6] or "0", -- suffix
		parts[7] or "0", -- unique
		upgradedItemLevel, -- ilevel (modified)
		parts[9] or "0" -- upgrade level
	);
	
	return "item:" .. newItemString;
end

-- Helper function to get max upgrade level for a specific tier
function DC.GetMaxUpgradeLevelForTier(tier)
	if not tier or not DC.MAX_UPGRADE_LEVELS_BY_TIER[tier] then
		local fallback = DC.MAX_UPGRADE_LEVEL or 15;
		DC.Debug("GetMaxUpgradeLevelForTier: tier=" .. tostring(tier) .. " returned fallback=" .. fallback);
		return fallback;  -- fallback to global max
	end
	return DC.MAX_UPGRADE_LEVELS_BY_TIER[tier];
end

-- Quality colors (Wrath palette)
DC.ITEM_QUALITY_COLORS = DC.ITEM_QUALITY_COLORS or {
	[0] = { r = 0.62, g = 0.62, b = 0.62 },
	[1] = { r = 1.00, g = 1.00, b = 1.00 },
	[2] = { r = 0.12, g = 1.00, b = 0.00 },
	[3] = { r = 0.00, g = 0.44, b = 0.87 },
	[4] = { r = 0.64, g = 0.21, b = 0.93 },
	[5] = { r = 1.00, g = 0.50, b = 0.00 },
};

-- Tier labels matching retail naming
DC.TIER_NAMES = DC.TIER_NAMES or {
	[1] = "Veteran",
	[2] = "Adventurer",
	[3] = "Champion",
	[4] = "Hero",
	[5] = "Legendary",
};

-- Maximum upgrade levels by tier (lower tiers have lower caps)
-- NOTE: Always reset to ensure correct values (don't use "or" which would preserve old saved data)
DC.MAX_UPGRADE_LEVELS_BY_TIER = {
	[1] = 6,   -- Veteran: 6 upgrades
	[2] = 15,  -- Adventurer: 15 upgrades (full upgrades)
	[3] = 15,  -- Champion: 15 upgrades (heirloom tier)
	[4] = 8,   -- Hero: 8 upgrades (mythic tier)
	[5] = 12,  -- Legendary: 12 upgrades (artifact tier)
};

-- Runtime state defaults
DC.upgradeCosts = DC.upgradeCosts or {};
DC.playerTokens = DC.playerTokens or 0;
DC.playerEssence = DC.playerEssence or 0;
DC.arrowAnimationTime = DC.arrowAnimationTime or 0;
DC.glowAnimationTime = DC.glowAnimationTime or 0;
DC.upgradeAnimationTime = DC.upgradeAnimationTime or 0;
DC.targetUpgradeLevel = DC.targetUpgradeLevel or 1;
DC.itemTooltipCache = DC.itemTooltipCache or {};
DC.pendingUpgrade = DC.pendingUpgrade or nil;
DC.queryQueueList = DC.queryQueueList or {};
DC.queryQueueMap = DC.queryQueueMap or {};
DC.queryInFlight = DC.queryInFlight or nil;
DC.itemUpgradeCache = DC.itemUpgradeCache or {};
DC.itemLocationCache = DC.itemLocationCache or {};

-- Currency item IDs: Initialize from DCAddonProtocol if available, otherwise use defaults
local DCProtocol = rawget(_G, "DCAddonProtocol");
if DCProtocol then
    DC.TOKEN_ITEM_ID = DCProtocol.TOKEN_ITEM_ID;
    DC.ESSENCE_ITEM_ID = DCProtocol.ESSENCE_ITEM_ID;
else
    DC.TOKEN_ITEM_ID = DC.TOKEN_ITEM_ID or 300311;   -- Upgrade Token
    DC.ESSENCE_ITEM_ID = DC.ESSENCE_ITEM_ID or 300312; -- Upgrade Essence
end

local INVENTORY_SLOT_ITEM_START = _G.INVENTORY_SLOT_ITEM_START or 23;
local INVENTORY_SLOT_ITEM_END = _G.INVENTORY_SLOT_ITEM_END or 39;
local BANK_SLOT_ITEM_START = _G.BANK_SLOT_ITEM_START or 39;
local BANK_SLOT_ITEM_END = _G.BANK_SLOT_ITEM_END or 67;
local TOOLTIP_CACHE_LIFETIME = 30; -- seconds

local function GetItemLinkForLocation(bag, slot)
	if bag == nil or slot == nil then
		return nil;
	end

	if IsEquippedBag(bag) then
		return GetInventoryItemLink("player", slot);
	end

	if bag == BAG_BANK then
		return GetContainerItemLink(BAG_BANK, slot);
	end

	return GetContainerItemLink(bag, slot);
end

local function GetItemTextureForLocation(bag, slot, link)
	if bag == nil or slot == nil then
		return nil;
	end

	if IsEquippedBag(bag) then
		return GetInventoryItemTexture("player", slot);
	end

	local texture = GetContainerItemInfo(bag, slot);
	if type(texture) == "table" then
		return texture.iconFileID or texture.icon or texture.texture or texture.iconFile or texture.iconID;
	end

	if type(texture) == "string" then
		return texture;
	end

	if link then
		local itemTexture = select(10, GetItemInfo(link));
		if itemTexture then
			return itemTexture;
		end
	end

	return nil;
end

function DarkChaos_ItemUpgrade_StartNextQuery()
	local nextRequest = table.remove(DC.queryQueueList, 1);
	if not nextRequest then
		DC.queryInFlight = nil;
		DC.Debug("StartNextQuery: No more queries in queue");
		return;
	end

	DC.queryInFlight = nextRequest;
	DC.Debug("StartNextQuery: Sending query for " .. nextRequest.key);
	DC.RequestItemInfo(nextRequest.serverBag, nextRequest.serverSlot);
end

function DarkChaos_ItemUpgrade_CompleteQuery()
	local finished = DC.queryInFlight;
	if finished then
		DC.queryQueueMap[finished.key] = nil;
	end
	DarkChaos_ItemUpgrade_StartNextQuery();
	return finished;
end

function DarkChaos_ItemUpgrade_QueueQuery(serverBag, serverSlot, context)
	if serverBag == nil or serverSlot == nil then
		return;
	end

	context = context or {};
	local key = BuildLocationKey(serverBag, serverSlot);

	-- Check if already queued
	if DC.queryQueueMap[key] then
		table.insert(DC.queryQueueMap[key].contexts, context);
		return;
	end

	local request = {
		key = key,
		serverBag = serverBag,
		serverSlot = serverSlot,
		-- command removed (using direct call in StartNextQuery)
		contexts = { context },
		type = "item",
	};

	-- Add to batch queue instead of immediate processing
	table.insert(DC.batchQueryQueue, request);
	DC.queryQueueMap[key] = request;
	
	-- Start batch timer if not already running
	if not DC.batchQueryTimer or DC.batchQueryTimer == 0 then
		DC.batchQueryTimer = DC.batchQueryDelay;
		-- Ensure OnUpdate is running to process the timer
		if DarkChaos_ItemUpgradeFrame then
			DarkChaos_ItemUpgradeFrame:SetScript("OnUpdate", DarkChaos_ItemUpgrade_OnUpdate);
		end
	end
end

function DarkChaos_ItemUpgrade_GetCachedDataForLocation(serverBag, serverSlot)
	local key = BuildLocationKey(serverBag, serverSlot);
	local guid = DC.itemLocationCache[key];
	if not guid then
		return nil;
	end

	local cached = DC.itemUpgradeCache[guid];
	if not cached then
		return nil;
	end

	local now = GetTime and GetTime() or 0;
	if cached.timestamp and (now - cached.timestamp) > TOOLTIP_CACHE_LIFETIME then
		return nil;
	end

	return cached;
end

local function DarkChaos_ItemUpgrade_TooltipHasUpgradeLine(tooltip)
	if not tooltip or not tooltip.GetName then
		return false;
	end

	local name = tooltip:GetName();
	if not name then
		return false;
	end

	for i = 1, tooltip:NumLines() do
		local line = _G[name .. "TextLeft" .. i];
		if line then
			local text = line:GetText();
			if text and string.find(text, "Upgrade Level") then
				return true;
			end
		end
	end

	return false;
end

local function DarkChaos_ItemUpgrade_AttachTooltipLines(tooltip, data)
	if not tooltip or not data then
		return;
	end

	-- Check if tooltips are enabled in settings (default to true if settings not loaded)
	if DC_ItemUpgrade_Settings and DC_ItemUpgrade_Settings.showTooltips == false then
		return;
	end

	-- Check if we already added upgrade lines to prevent duplicates
	if DarkChaos_ItemUpgrade_TooltipHasUpgradeLine(tooltip) then
		return;
	end
	
	-- Prevent rapid re-processing of same tooltip
	if tooltip.__dcUpgradeProcessing then
		return;
	end

	-- Skip upgrade/tier lines for items that are not considered upgradeable.
	-- (e.g. heirlooms, bags, and non-weapon/armor items)
	local _, itemLink = tooltip:GetItem();
	if itemLink then
		local _, _, quality, _, _, itemType, _, _, equipLoc = GetItemInfo(itemLink);
		if quality == 7 then
			return;
		end
		if itemType ~= "Armor" and itemType ~= "Weapon" then
			return;
		end
		if equipLoc == "INVTYPE_BAG" or equipLoc == "INVTYPE_QUIVER" then
			return;
		end
		if itemType == "Container" then
			return;
		end
	end

	local current = tonumber(data.currentUpgrade) or 0;
	local tier = tonumber(data.tier) or 0;
	local maxUpgrade = tonumber(data.maxUpgrade) or 0;
	-- Some server responses omit maxUpgrade for tier-1 items; fall back to tier defaults.
	if maxUpgrade <= 0 and tier > 0 and DC.GetMaxUpgradeLevelForTier then
		maxUpgrade = tonumber(DC.GetMaxUpgradeLevelForTier(tier)) or 0;
	end
	if maxUpgrade <= 0 and current <= 0 then
		return;
	end
	local statMultiplier = data.statMultiplier or 1.0;
	local totalBonus = (statMultiplier - 1.0) * 100;
	local currentEntry = data.currentEntry or data.baseEntry or 0;
	-- tier is computed above
	local HEIRLOOM_SHIRT_ENTRY = 300365;
	local isHeirloom = (currentEntry == HEIRLOOM_SHIRT_ENTRY) or (data.baseEntry == HEIRLOOM_SHIRT_ENTRY);

	tooltip.__dcUpgradeProcessing = true;
	tooltip:AddLine(" ");
	
	-- Only show Entry if it differs from the base item ID (upgraded items have different entry)
	-- Item ID is already shown by Core.lua, so we skip redundant display
	local baseItemId = data.baseEntry or 0;
	if currentEntry > 0 and currentEntry ~= baseItemId and baseItemId > 0 then
		tooltip:AddLine(string.format("|cff888888Upgraded Entry: %d|r", currentEntry));
	end
	
	-- Show upgrade info if item has upgrades
	if current > 0 then
		-- Show upgrade level with color based on progress
		local progressColor = "|cffffcc00"; -- Gold for partial
		if current >= maxUpgrade then
			progressColor = "|cff00ff00"; -- Green for maxed
		end
		tooltip:AddLine(string.format("%sUpgrade Level %d / %d Tier %d|r", progressColor, current, maxUpgrade, tier));
		
		-- Show stat bonus if upgraded
		if totalBonus > 0 then
			tooltip:AddLine(string.format("|cff00ff00+%.1f%% All Stats|r", totalBonus));
		end
		
		-- For heirlooms, show the installed stat package
		if isHeirloom then
			local packageId = data.heirloomPackageId or DC.selectedStatPackage;
			if packageId and packageId > 0 and DC.STAT_PACKAGES and DC.STAT_PACKAGES[packageId] then
				local pkg = DC.STAT_PACKAGES[packageId];
				local colorHex = string.format("%.2x%.2x%.2x", pkg.color.r*255, pkg.color.g*255, pkg.color.b*255);
				tooltip:AddLine(string.format("|cff%s-- %s Package --|r", colorHex, pkg.name));
				
				-- Show package stats at current level
				local stats = DarkChaos_ItemUpgrade_GetPackageStatsAtLevel(packageId, current);
				if stats then
					for _, stat in ipairs(stats) do
						tooltip:AddLine(string.format("|cff00ff00+%d %s|r", stat.value, stat.name));
					end
				end
			end
		end
	elseif maxUpgrade > 0 then
		-- Show that item is upgradeable but not upgraded yet
		tooltip:AddLine(string.format("|cff888888Upgrade Level 0 / %d Tier %d|r", maxUpgrade, tier));
		
		-- For unupgraded heirlooms, show hint about package selection
		if isHeirloom then
			tooltip:AddLine("|cff888888Select a stat package to upgrade|r");
		end
	end
	
	tooltip:Show();
	tooltip.__dcUpgradeProcessing = nil;
end

local function DarkChaos_ItemUpgrade_HandleTooltipContext(context, data, errorMsg)
	if not context then
		return;
	end

	local tooltip = context.tooltip;
	if not tooltip or not tooltip:IsShown() then
		return;
	end

	if context.clientBag ~= nil and context.clientSlot ~= nil and context.itemLink then
		local currentLink = GetItemLinkForLocation(context.clientBag, context.clientSlot);
		if currentLink and currentLink ~= context.itemLink then
			return;
		end
	end

	if data then
		if context.locationKey and data.guid then
			DC.itemLocationCache[context.locationKey] = data.guid;
		end
		DarkChaos_ItemUpgrade_AttachTooltipLines(tooltip, data);
	elseif errorMsg then
		tooltip:AddLine(string.format("|cffff0000Upgrade data unavailable: %s|r", errorMsg));
		tooltip:Show();
	end
end

function DarkChaos_ItemUpgrade_ApplyQueryData(item, data)
	if not item or not data then
		return;
	end

	-- SPECIAL HANDLING: Heirloom Adventurer's Shirt (300365)
	-- Force tier 3 (HEIRLOOM) and 15 max levels regardless of server response
	local HEIRLOOM_SHIRT_ENTRY = 300365;
	local isHeirloomShirt = (item.itemID == HEIRLOOM_SHIRT_ENTRY) or 
	                        (item.baseEntry == HEIRLOOM_SHIRT_ENTRY) or
	                        (data.baseEntry == HEIRLOOM_SHIRT_ENTRY);
	
	if isHeirloomShirt then
		item.tier = 3;  -- TIER_HEIRLOOM
		item.maxUpgrade = 15;
		DC.Debug("ApplyQueryData: Forced HEIRLOOM tier for item 300365");
	else
		item.tier = data.tier or item.tier or 1;
		item.maxUpgrade = data.maxUpgrade or DC.GetMaxUpgradeLevelForTier(item.tier);
	end
	
	item.currentUpgrade = data.currentUpgrade or 0;
	DC.Debug("ApplyQueryData: data.maxUpgrade=" .. tostring(data.maxUpgrade) .. ", item.tier=" .. tostring(item.tier) .. ", final item.maxUpgrade=" .. tostring(item.maxUpgrade));
	item.baseLevel = data.baseItemLevel or item.baseLevel or 0;
	local calculatedLevel = data.upgradedItemLevel or GetUpgradedItemLevel(item.baseLevel, item.currentUpgrade, item.tier);
	item.upgradedLevel = calculatedLevel;
	item.level = calculatedLevel;
	item.statMultiplier = data.statMultiplier or GetStatMultiplierForLevel(item.currentUpgrade, item.tier);
	item.guid = data.guid or item.guid;
	if data.baseEntry then
		item.baseEntry = data.baseEntry;
	elseif not item.baseEntry then
		item.baseEntry = item.itemID;
	end
	if data.currentEntry then
		item.currentEntry = data.currentEntry;
		item.itemID = data.currentEntry;
	elseif not item.currentEntry then
		item.currentEntry = item.itemID;
	end
	if data.cloneEntries then
		item.cloneEntries = {};
		for level, entry in pairs(data.cloneEntries) do
			item.cloneEntries[level] = entry;
		end
	elseif not item.cloneEntries then
		item.cloneEntries = {};
	end
	if item.baseEntry and not item.cloneEntries[0] then
		item.cloneEntries[0] = item.baseEntry;
	end
	if item.currentEntry then
		item.cloneEntries[item.currentUpgrade or 0] = item.currentEntry;
	end
	if data.serverBag then
		item.serverBag = data.serverBag;
	end
	if data.serverSlot then
		item.serverSlot = data.serverSlot;
	end
	if item.serverBag and item.serverSlot then
		item.locationKey = BuildLocationKey(item.serverBag, item.serverSlot);
	end

	local baseLevel = item.baseLevel or 0;
	local current = item.currentUpgrade or 0;
	local currentLevel = GetUpgradedItemLevel(baseLevel, current, item.tier);
	local nextLevel;
	if current < (item.maxUpgrade or DC.MAX_UPGRADE_LEVEL or 15) then
		nextLevel = GetUpgradedItemLevel(baseLevel, current + 1, item.tier);
	end
	local currentCloneEntry = GetCloneEntryForLevel(item, current);
	if currentCloneEntry then
		local infoLevel = select(4, GetItemInfo(currentCloneEntry));
		if infoLevel then
			currentLevel = infoLevel;
		end
	end
	if nextLevel then
		local nextCloneEntry = GetCloneEntryForLevel(item, current + 1);
		if nextCloneEntry then
			local infoLevel = select(4, GetItemInfo(nextCloneEntry));
			if infoLevel then
				nextLevel = infoLevel;
			end
		end
		item.ilevelStep = math.max(0, nextLevel - currentLevel);
	else
		item.ilevelStep = 0;
	end
	item.statPerLevel = GetStatBonusPercent(current + 1, item.tier) - GetStatBonusPercent(current, item.tier);

	local maxUpgrade = item.maxUpgrade or DC.MAX_UPGRADE_LEVEL or 15;
	if current >= maxUpgrade then
		DC.targetUpgradeLevel = maxUpgrade;
	else
		local defaultTarget = current + 1;
		local requested = DC.targetUpgradeLevel or defaultTarget;
		DC.targetUpgradeLevel = math.max(defaultTarget, math.min(requested, maxUpgrade));
	end

	-- Mode Check (only show error if item can actually be upgraded)
	local modeError = nil;
	local canUpgrade = (current < maxUpgrade);
	if canUpgrade then
		if DC.uiMode == "HEIRLOOM" and item.tier ~= 3 then
			modeError = "This item is not an Heirloom.";
		elseif DC.uiMode == "STANDARD" and item.tier == 3 then
			modeError = "Please use the Heirloom Upgrade interface.";
		end
	end

	-- Clamp target selection within valid range
	local validTarget = math.min(math.max(DC.targetUpgradeLevel or (current + 1), current + 1), maxUpgrade);
	DC.targetUpgradeLevel = validTarget;

	-- Show mode error if applicable
	if modeError then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000" .. modeError .. "|r");
	end
end

local function ResolveInventoryLocation(slot)
	if not slot then
		return nil, nil;
	end

	if slot >= INVENTORY_SLOT_ITEM_START and slot < INVENTORY_SLOT_ITEM_END then
		local offset = slot - INVENTORY_SLOT_ITEM_START;
		return BAG_BACKPACK, offset + 1;
	end

	if slot >= BANK_SLOT_ITEM_START and slot < BANK_SLOT_ITEM_END then
		local offset = slot - BANK_SLOT_ITEM_START;
		return BAG_BANK, offset + 1;
	end

	return BAG_EQUIPPED, slot;
end

local function DarkChaos_ItemUpgrade_ResetTooltip(tooltip)
	if tooltip then
		tooltip.__dcUpgradeLastGuid = nil;
		tooltip.__dcUpgradeLastStamp = nil;
	end
end

function DarkChaos_ItemUpgrade_OnTooltipSetBagItem(tooltip, bag, slot)
	if not tooltip or bag == nil or slot == nil then
		return;
	end

	local link = GetItemLinkForLocation(bag, slot);
	if not link then
		return;
	end

	local serverBag = GetServerBagFromClient(bag);
	local serverSlot = GetServerSlotFromClient(bag, slot);
	local cached = DarkChaos_ItemUpgrade_GetCachedDataForLocation(serverBag, serverSlot);
	if cached then
		DarkChaos_ItemUpgrade_AttachTooltipLines(tooltip, cached);
		return;
	end

	DarkChaos_ItemUpgrade_QueueQuery(serverBag, serverSlot, {
		type = "tooltip",
		tooltip = tooltip,
		clientBag = bag,
		clientSlot = slot,
		serverBag = serverBag,
		serverSlot = serverSlot,
		itemLink = link,
		locationKey = BuildLocationKey(serverBag, serverSlot),
	});
end

function DarkChaos_ItemUpgrade_OnTooltipSetInventoryItem(tooltip, unit, slot)
	if unit ~= "player" then
		return;
	end

	local bag, bagSlot = ResolveInventoryLocation(slot);
	if not bag or not bagSlot then
		return;
	end

	local link = GetItemLinkForLocation(bag, bagSlot);
	if not link then
		return;
	end

	local serverBag = GetServerBagFromClient(bag);
	local serverSlot = GetServerSlotFromClient(bag, bagSlot);
	local cached = DarkChaos_ItemUpgrade_GetCachedDataForLocation(serverBag, serverSlot);
	if cached then
		DarkChaos_ItemUpgrade_AttachTooltipLines(tooltip, cached);
		return;
	end

	DarkChaos_ItemUpgrade_QueueQuery(serverBag, serverSlot, {
		type = "tooltip",
		tooltip = tooltip,
		clientBag = bag,
		clientSlot = bagSlot,
		serverBag = serverBag,
		serverSlot = serverSlot,
		itemLink = link,
		locationKey = BuildLocationKey(serverBag, serverSlot),
	});
end

local function DarkChaos_ItemUpgrade_OnTooltipSetGuildBankItem(tooltip, tab, slot)
	if not tooltip or tab == nil or slot == nil then
		return;
	end

	if DarkChaos_ItemUpgrade_TooltipHasUpgradeLine(tooltip) then
		return;
	end

	if type(GetGuildBankItemLink) ~= "function" then
		return;
	end

	local link = GetGuildBankItemLink(tab, slot);
	if not link then
		return;
	end

	local info = GetItemTooltipInfo(link);
	if not info then
		return;
	end

	if (info.upgrade or 0) > 0 then
		tooltip:AddLine(" ");
		tooltip:AddLine(string.format("|cffffcc00Upgrade Level %d / %d|r", info.upgrade or 0, info.max or DC.MAX_UPGRADE_LEVEL or 15));
		tooltip:Show();
	end
end

--[[=====================================================
	TOOLTIP HOOKS
=======================================================]]

-- Hook GameTooltip to show upgrade information AND item IDs
function DarkChaos_ItemUpgrade_HookTooltips()
	if DC.tooltipsHooked then return; end
	DC.tooltipsHooked = true;
	
	-- Use hooksecurefunc for safe hooking (doesn't replace original, just adds callback)
	if hooksecurefunc then
		-- Hook SetBagItem (items in bags)
		hooksecurefunc(GameTooltip, "SetBagItem", function(self, bag, slot)
			-- Always show item ID if enabled
			local link = GetContainerItemLink(bag, slot);
			if link and DC.showItemIDsInTooltips then
				DC.AddItemIDToTooltip(self, nil, link);
			end
			-- Then handle upgrade info
			DarkChaos_ItemUpgrade_OnTooltipSetBagItem(self, bag, slot);
		end);
		
		-- Hook SetInventoryItem (equipped items and inspection)
		hooksecurefunc(GameTooltip, "SetInventoryItem", function(self, unit, slot)
			-- Always show item ID if enabled
			local link = GetInventoryItemLink(unit, slot);
			if link and DC.showItemIDsInTooltips then
				DC.AddItemIDToTooltip(self, nil, link);
			end
			-- Then handle upgrade info
			if unit == "player" then
				DarkChaos_ItemUpgrade_OnTooltipSetInventoryItem(self, unit, slot);
			else
				DarkChaos_ItemUpgrade_OnTooltipSetInspectItem(self, unit, slot);
			end
		end);
		
		-- Hook for item links in chat, etc.
		hooksecurefunc(GameTooltip, "SetHyperlink", function(self, link)
			if link and type(link) == "string" and string.find(link, "item:") then
				-- Always show item ID if enabled
				if DC.showItemIDsInTooltips then
					DC.AddItemIDToTooltip(self, nil, link);
				end
				-- Then handle upgrade info
				DarkChaos_ItemUpgrade_OnTooltipSetHyperlink(self, link);
			end
		end);
		
		-- Hook SetMerchantItem (vendor items)
		hooksecurefunc(GameTooltip, "SetMerchantItem", function(self, index)
			if DC.showItemIDsInTooltips then
				local link = GetMerchantItemLink(index);
				if link then
					DC.AddItemIDToTooltip(self, nil, link);
				end
			end
		end);
		
		-- Hook SetLootItem (loot window items)
		hooksecurefunc(GameTooltip, "SetLootItem", function(self, slot)
			if DC.showItemIDsInTooltips then
				local link = GetLootSlotLink(slot);
				if link then
					DC.AddItemIDToTooltip(self, nil, link);
				end
			end
		end);
		
		-- Hook SetQuestItem (quest reward items)
		hooksecurefunc(GameTooltip, "SetQuestItem", function(self, type, index)
			if DC.showItemIDsInTooltips then
				local link = GetQuestItemLink(type, index);
				if link then
					DC.AddItemIDToTooltip(self, nil, link);
				end
			end
		end);
		
		-- Hook SetQuestLogItem (quest log reward items)
		hooksecurefunc(GameTooltip, "SetQuestLogItem", function(self, type, index)
			if DC.showItemIDsInTooltips then
				local link = GetQuestLogItemLink(type, index);
				if link then
					DC.AddItemIDToTooltip(self, nil, link);
				end
			end
		end);
		
		-- Hook SetAuctionItem (auction house items)
		hooksecurefunc(GameTooltip, "SetAuctionItem", function(self, type, index)
			if DC.showItemIDsInTooltips then
				local link = GetAuctionItemLink(type, index);
				if link then
					DC.AddItemIDToTooltip(self, nil, link);
				end
			end
		end);
		
		-- Hook SetAuctionSellItem (auction sell item slot)
		hooksecurefunc(GameTooltip, "SetAuctionSellItem", function(self)
			if DC.showItemIDsInTooltips then
				local name, texture, count, quality, canUse, price = GetAuctionSellItemInfo();
				if name then
					-- Try to get the link from cursor or bag
					local _, link = self:GetItem();
					if link then
						DC.AddItemIDToTooltip(self, nil, link);
					end
				end
			end
		end);
		
		-- Hook SetTradePlayerItem (trade window - your items)
		hooksecurefunc(GameTooltip, "SetTradePlayerItem", function(self, index)
			if DC.showItemIDsInTooltips then
				local link = GetTradePlayerItemLink(index);
				if link then
					DC.AddItemIDToTooltip(self, nil, link);
				end
			end
		end);
		
		-- Hook SetTradeTargetItem (trade window - their items)
		hooksecurefunc(GameTooltip, "SetTradeTargetItem", function(self, index)
			if DC.showItemIDsInTooltips then
				local link = GetTradeTargetItemLink(index);
				if link then
					DC.AddItemIDToTooltip(self, nil, link);
				end
			end
		end);
		
		-- Hook SetGuildBankItem (guild bank items)
		if GetGuildBankItemLink then
			hooksecurefunc(GameTooltip, "SetGuildBankItem", function(self, tab, slot)
				if DC.showItemIDsInTooltips then
					local link = GetGuildBankItemLink(tab, slot);
					if link then
						DC.AddItemIDToTooltip(self, nil, link);
					end
				end
			end);
		end
		
		-- Hook SetInboxItem (mailbox items)
		hooksecurefunc(GameTooltip, "SetInboxItem", function(self, mailIndex, attachmentIndex)
			if DC.showItemIDsInTooltips then
				local link = GetInboxItemLink(mailIndex, attachmentIndex or 1);
				if link then
					DC.AddItemIDToTooltip(self, nil, link);
				end
			end
		end);
		
		-- Hook SetSendMailItem (sending mail attachment)
		hooksecurefunc(GameTooltip, "SetSendMailItem", function(self, index)
			if DC.showItemIDsInTooltips then
				-- GetSendMailItem returns name, icon, count, quality
				-- GetSendMailItemLink is not a standard API, try GetItem on tooltip
				local _, link = self:GetItem();
				if link then
					DC.AddItemIDToTooltip(self, nil, link);
				end
			end
		end);
		
		-- Hook OnTooltipCleared to reset our tracking
		GameTooltip:HookScript("OnTooltipCleared", function(self)
			self.__dcItemIDAdded = nil;
			self.__dcUpgradeProcessing = nil;
		end);
	end
	
	DC.Debug("Tooltip hooks installed (including Item ID display)");
end

-- Handle inspecting other players' items
function DarkChaos_ItemUpgrade_OnTooltipSetInspectItem(tooltip, unit, slot)
	if not tooltip or not unit or not slot then return; end
	
	-- Check if tooltips are enabled
	if not (DC_ItemUpgrade_Settings and DC_ItemUpgrade_Settings.showTooltips) then
		return;
	end
	
	-- Don't add lines twice
	if DarkChaos_ItemUpgrade_TooltipHasUpgradeLine and DarkChaos_ItemUpgrade_TooltipHasUpgradeLine(tooltip) then
		return;
	end
	
	-- Get the item link from the inspected unit
	local link = GetInventoryItemLink(unit, slot);
	if not link then return; end
	
	-- Parse the item ID from the link
	local itemId = tonumber(string.match(link, "item:(%d+)"));
	if not itemId then return; end
	
	-- Check if this item ID matches any upgraded item in our cache
	for guid, data in pairs(DC.itemUpgradeCache or {}) do
		if data.currentEntry == itemId then
			DarkChaos_ItemUpgrade_AttachTooltipLines(tooltip, data);
			return;
		end
	end
	
	-- Also check clone entries map for the item
	for guid, data in pairs(DC.itemUpgradeCache or {}) do
		if data.cloneEntries then
			for level, entryId in pairs(data.cloneEntries) do
				if entryId == itemId then
					-- Found it - create a synthetic data object for display
					local displayData = {
						currentUpgrade = level,
						maxUpgrade = data.maxUpgrade,
						baseItemLevel = data.baseItemLevel,
						upgradedItemLevel = data.baseItemLevel + (level * 2), -- Estimate
						statMultiplier = 1 + (level * 0.025), -- Estimate based on level
					};
					DarkChaos_ItemUpgrade_AttachTooltipLines(tooltip, displayData);
					return;
				end
			end
		end
	end
end

-- Handle hyperlink tooltips (item links in chat) - must be defined before hooks
function DarkChaos_ItemUpgrade_OnTooltipSetHyperlink(tooltip, link)
	if not tooltip or not link then return; end
	
	-- Check if tooltips are enabled
	if not (DC_ItemUpgrade_Settings and DC_ItemUpgrade_Settings.showTooltips) then
		return;
	end
	
	-- Don't add lines twice
	if DarkChaos_ItemUpgrade_TooltipHasUpgradeLine and DarkChaos_ItemUpgrade_TooltipHasUpgradeLine(tooltip) then
		return;
	end
	
	-- For hyperlinks, we can only show basic info since we don't have location data
	-- Parse the item ID from the link and check cache
	local itemId = tonumber(string.match(link, "item:(%d+)"));
	if not itemId then return; end
	
	-- Check if this is a known upgraded item in our cache
	for guid, data in pairs(DC.itemUpgradeCache or {}) do
		if data.currentEntry == itemId or data.baseEntry == itemId then
			DarkChaos_ItemUpgrade_AttachTooltipLines(tooltip, data);
			return;
		end
	end
end

local SCAN_TOOLTIP_NAME = "DarkChaos_ItemUpgradeScanTooltip";
local scanTooltip = _G[SCAN_TOOLTIP_NAME];
if not scanTooltip then
	scanTooltip = CreateFrame("GameTooltip", SCAN_TOOLTIP_NAME, UIParent, "GameTooltipTemplate");
	scanTooltip:SetOwner(UIParent, "ANCHOR_NONE");
end

local function GetTooltipLine(index)
	local line = _G[SCAN_TOOLTIP_NAME .. "TextLeft" .. index];
	return line and line:GetText() or nil;
end

local function GetItemTooltipInfo(link, locationKey)
	if not link then return nil; end

	-- Use locationKey for cache to differentiate multiple copies of same item
	local cacheKey = locationKey or link;
	local cache = DC.itemTooltipCache[cacheKey];
	local now = GetTime and GetTime() or 0;
	if cache and ((now - (cache.timestamp or 0)) < 10) then
		return cache;
	end

	scanTooltip:SetOwner(UIParent, "ANCHOR_NONE");
	scanTooltip:ClearLines();
	scanTooltip:SetHyperlink(link);

	local itemLevel = select(4, GetItemInfo(link)) or 0;
	local upgradeLevel = 0;
	local maxLevel = DC.MAX_UPGRADE_LEVEL;  -- Fallback for tooltip parsing, tier-specific handled elsewhere
	local foundUpgrade = false;

	for i = 2, scanTooltip:NumLines() do
		local text = GetTooltipLine(i);
		if text then
			-- Try to match various formats: "Upgrade Level: 0/6", "Upgrade: 0/6", "Upgrade Rank: 0/6"
			local cur, max = text:match("[Uu]pgrade.-(%d+)%s*/%s*(%d+)");
			if cur and max then
				upgradeLevel = tonumber(cur) or upgradeLevel;
				maxLevel = tonumber(max) or maxLevel;
				foundUpgrade = true;
				break;
			end
		end
	end

	local info = {
		ilevel = itemLevel,
		upgrade = upgradeLevel,
		max = maxLevel,
		found = foundUpgrade,
		timestamp = now,
	};

	DC.itemTooltipCache[cacheKey] = info;
	return info;
end

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
		local borderTexture = _G[button:GetName().."NormalTexture"];
		if borderTexture then
			borderTexture:SetVertexColor(color.r, color.g, color.b);
		end
	end
end

local function RefreshCurrentItemMetadata(link)
	if not (DC.currentItem and link) then
		return;
	end

	if link ~= DC.currentItem.link then
		DC.currentItem.link = link;
		local name, _, quality, level = GetItemInfo(link);
		if name then
			DC.currentItem.name = name;
		end
		if quality then
			DC.currentItem.quality = quality;
		end
		if level then
			DC.currentItem.baseLevel = level;
		end
		local itemID = link:match("item:(%d+)");
		if itemID then
			DC.currentItem.itemID = tonumber(itemID) or DC.currentItem.itemID;
		end
	end
end

local function RoundStatValue(value)
	if not value then
		return 0;
	end
	if value >= 0 then
		return math.floor(value + 0.5);
	end
	return math.ceil(value - 0.5);
end

local function EnsureHiddenTooltip()
	if DC.hiddenTooltip then
		return DC.hiddenTooltip;
	end
	local tooltip = CreateFrame("GameTooltip", "DarkChaosItemUpgradeHiddenTooltip", UIParent, "GameTooltipTemplate");
	tooltip:SetOwner(UIParent, "ANCHOR_NONE");
	tooltip:Hide();
	DC.hiddenTooltip = tooltip;
	return tooltip;
end

local function GetItemStatsSafe(link)
	if not link or type(GetItemStats) ~= "function" then
		return nil;
	end
	local stats = GetItemStats(link);
	if stats and next(stats) then
		return stats;
	end
	local tooltip = EnsureHiddenTooltip();
	tooltip:SetOwner(UIParent, "ANCHOR_NONE");
	tooltip:ClearLines();
	tooltip:SetHyperlink(link);
	tooltip:Hide();
	stats = GetItemStats(link);
	if stats and next(stats) then
		return stats;
	end
	return nil;
end

local STAT_LABEL_OVERRIDES = {
	ITEM_MOD_HEALTH_REGENERATION_SHORT = "Health per 5",
	ITEM_MOD_MANA_REGENERATION_SHORT = "Mana per 5",
};

local STAT_ORDER = {
	-- Armor (always first)
	"ITEM_MOD_ARMOR_SHORT",
	-- Primary Stats
	"ITEM_MOD_STRENGTH_SHORT",
	"ITEM_MOD_AGILITY_SHORT",
	"ITEM_MOD_INTELLECT_SHORT",
	"ITEM_MOD_STAMINA_SHORT",
	"ITEM_MOD_SPIRIT_SHORT",
	-- Secondary Stats (offensive)
	"ITEM_MOD_ATTACK_POWER_SHORT",
	"ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
	"ITEM_MOD_FERAL_ATTACK_POWER_SHORT",
	"ITEM_MOD_SPELL_POWER_SHORT",
	"ITEM_MOD_DAMAGE_PER_SECOND_SHORT",
	"ITEM_MOD_CRIT_RATING_SHORT",
	"ITEM_MOD_HIT_RATING_SHORT",
	"ITEM_MOD_HASTE_RATING_SHORT",
	"ITEM_MOD_EXPERTISE_RATING_SHORT",
	"ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
	"ITEM_MOD_SPELL_PENETRATION_SHORT",
	-- Secondary Stats (defensive)
	"ITEM_MOD_RESILIENCE_RATING_SHORT",
	"ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
	"ITEM_MOD_DODGE_RATING_SHORT",
	"ITEM_MOD_PARRY_RATING_SHORT",
	"ITEM_MOD_BLOCK_RATING_SHORT",
	"ITEM_MOD_BLOCK_VALUE_SHORT",
	-- Regen/Procs
	"ITEM_MOD_HEALTH_REGENERATION_SHORT",
	"ITEM_MOD_MANA_REGENERATION_SHORT",
	-- Resistances (last)
	"RESISTANCE1_NAME",
	"RESISTANCE2_NAME",
	"RESISTANCE3_NAME",
	"RESISTANCE4_NAME",
	"RESISTANCE5_NAME",
	"RESISTANCE6_NAME",
};

local STAT_ORDER_INDEX = {};
for index, key in ipairs(STAT_ORDER) do
	STAT_ORDER_INDEX[key] = index;
end

local function ShouldSkipStatKey(statKey)
	return statKey and statKey:find("^EMPTY_SOCKET");
end

local function ResolveStatLabel(statKey)
	if STAT_LABEL_OVERRIDES[statKey] then
		return STAT_LABEL_OVERRIDES[statKey];
	end
	if _G[statKey] and type(_G[statKey]) == "string" then
		return _G[statKey];
	end
	if type(statKey) == "string" then
		return statKey:gsub("_SHORT", ""):gsub("_", " ");
	end
	return statKey;
end

local function FormatNumberWithSeparators(value)
	local sign = "";
	if value and value < 0 then
		sign = "-";
		value = math.abs(value);
	end
	local number = math.floor((value or 0) + 0.5);
	local str = tostring(number);
	local len = #str;
	if len <= 3 then
		return sign .. str;
	end
	local chunks = {};
	while len > 3 do
		table.insert(chunks, 1, string.sub(str, len - 2, len));



		str = string.sub(str, 1, len - 3);
		len = #str;
	end
	table.insert(chunks, 1, str);
	return sign .. table.concat(chunks, ",");
end

local function FormatNumericValue(value, showSign)
	if value == nil then
		return nil;
	end
	if math.abs(value) < 0.0005 then
		value = 0;
	end
	local rounded = RoundStatValue(value);
	local sign = "";
	if showSign then
		if rounded > 0 then
			sign = "+";
		elseif rounded < 0 then
			sign = "-";
		end
	elseif rounded < 0 then
		sign = "-";
	end
	local magnitude = FormatNumberWithSeparators(math.abs(rounded));
	return sign .. magnitude;
end

local function FormatStatLine(label, value, diff)
	if value == nil then
		return nil;
	end

	local valueText = FormatNumericValue(value, true);
	if not valueText then
		return nil;
	end

	local bullet = "|cff71d5ff*|r";
	local baseColor = "|cffffffff";
	local line = string.format("%s %s%s %s|r", bullet, baseColor, valueText, label);

	if diff and math.abs(diff) > 0.0005 then
		local diffRounded = RoundStatValue(diff);
		if diffRounded ~= 0 then
			local diffColor = diffRounded > 0 and "|cff00ff00" or "|cffff4c4c";
			local diffText = FormatNumericValue(diffRounded, true);
			line = string.format("%s %s(%s)|r", line, diffColor, diffText or "0");
		end
	end

	return line;
end

local function DarkChaos_ItemUpgrade_BuildStatComparison(item, targetLevel)
	if not item then
		return nil;
	end

	local currentUpgrade = item.currentUpgrade or 0;
	local tier = item.tier or 1;
	local comparison;

	local currentEntry = GetCloneEntryForLevel(item, currentUpgrade);
	local targetEntry = GetCloneEntryForLevel(item, targetLevel);

	if currentEntry and targetEntry then
		GetItemInfo(currentEntry);
		GetItemInfo(targetEntry);
		local currentLink = item.link;
		if not currentLink or not string.find(currentLink, "item:" .. currentEntry, 1, true) then
			currentLink = "item:" .. tostring(currentEntry);
		end
		local previewLink = "item:" .. tostring(targetEntry);
		local currentStats = GetItemStatsSafe(currentLink);
		local previewStats = GetItemStatsSafe(previewLink);
		if currentStats and previewStats then
			local keys = {};
			for statKey, value in pairs(currentStats) do
				if value ~= 0 and not ShouldSkipStatKey(statKey) then
					keys[statKey] = true;
				end
			end
			for statKey, value in pairs(previewStats) do
				if value ~= 0 and not ShouldSkipStatKey(statKey) then
					keys[statKey] = true;
				end
			end

			comparison = {};
			for statKey in pairs(keys) do
				local label = ResolveStatLabel(statKey);
				if label then
					local currentValue = currentStats[statKey] or 0;
					local previewValue = previewStats[statKey] or 0;
					local diff = previewValue - currentValue;
					if math.abs(currentValue) > 0.0005 or math.abs(previewValue) > 0.0005 then
						comparison[#comparison + 1] = {
							key = statKey,
							label = label,
							current = currentValue,
							preview = previewValue,
							diff = diff,
						};
					end
				end
			end

			if #comparison == 0 then
				comparison = nil;
			end
		end
	end

	if not comparison then
		if not item.link then
			return nil;
		end
		local currentStats = GetItemStatsSafe(item.link);
		if not currentStats or not next(currentStats) then
			return nil;
		end

		local currentMultiplier = GetStatMultiplierForLevel(currentUpgrade, tier);
		if currentMultiplier <= 0 then
			currentMultiplier = 1;
		end
		local previewMultiplier = GetStatMultiplierForLevel(targetLevel, tier);

		comparison = {};
		for statKey, value in pairs(currentStats) do
			if value ~= 0 and not ShouldSkipStatKey(statKey) then
				local label = ResolveStatLabel(statKey);
				if label then
					local baseValue = RoundStatValue((value or 0) / math.max(currentMultiplier, 0.0001));
					local currentValue = RoundStatValue(baseValue * currentMultiplier);
					local previewValue = RoundStatValue(baseValue * previewMultiplier);
					local diff = previewValue - currentValue;
					if currentValue ~= 0 or previewValue ~= 0 then
						comparison[#comparison + 1] = {
							key = statKey,
							label = label,
							current = currentValue,
							preview = previewValue,
							diff = diff,
						};
					end
				end
			end
		end
	end

	if not comparison or #comparison == 0 then
		return nil;
	end

	table.sort(comparison, function(a, b)
		local aIndex = STAT_ORDER_INDEX[a.key] or 1000;
		local bIndex = STAT_ORDER_INDEX[b.key] or 1000;
		if aIndex == bIndex then
			return a.label < b.label;
		end
		return aIndex < bIndex;
	end);

	return comparison;
end

function DarkChaos_ItemUpgrade_OnLoad(self)
	local BG_FELLEATHER = "Interface\\AddOns\\DC-ItemUpgrade\\Textures\\Backgrounds\\FelLeather_512.tga";
	local BG_TINT_ALPHA = 0.60;
	local function ApplyLeaderboardsStyle(frame)
		if not frame or frame.__dcLeaderboardsStyled then
			return;
		end
		frame.__dcLeaderboardsStyled = true;

		if frame.SetBackdropColor then
			frame:SetBackdropColor(0, 0, 0, 0);
		end

		local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8);
		bg:SetAllPoints();
		bg:SetTexture(BG_FELLEATHER);

		local tint = frame:CreateTexture(nil, "BACKGROUND", nil, -7);
		tint:SetAllPoints(bg);
		tint:SetTexture(0, 0, 0, BG_TINT_ALPHA);
	end

	local function ApplyLeaderboardsInsetPanel(frame)
		if not frame then
			return;
		end
		if frame.SetBackdrop then
			frame:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8X8",
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
				tile = true,
				tileSize = 32,
				edgeSize = 32,
				insets = { left = 11, right = 12, top = 12, bottom = 11 },
			});
		end
		if frame.SetBackdropColor then
			frame:SetBackdropColor(0, 0, 0, 0);
		end
		if frame.SetBackdropBorderColor then
			frame:SetBackdropBorderColor(1, 1, 1, 1);
		end
		ApplyLeaderboardsStyle(frame);
	end

	ApplyLeaderboardsStyle(self);
	ApplyLeaderboardsInsetPanel(self.CurrentPanel);
	ApplyLeaderboardsInsetPanel(self.UpgradePanel);

	ApplyLeaderboardsStyle(_G["DarkChaos_ItemUpgrade_DebugFrame"]);
	ApplyLeaderboardsStyle(_G["DarkChaos_ItemBrowserFrame"]);

	self:RegisterForDrag("LeftButton");
	self:SetMovable(true);
	self:EnableMouse(true);
	self:SetClampedToScreen(true);
	
	-- Set up drag handlers for moving the frame
	self:SetScript("OnDragStart", function(frame)
		frame:StartMoving();
	end);
	self:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing();
	end);
	
	-- SetPortraitToTexture(self.portrait, "Interface\\Icons\\Trade_BlackSmithing"); -- Removed as portrait is not used
	self:RegisterEvent("PLAYER_LOGIN");
	
	-- Initialize UI elements
	if self.TitleText then
		self.TitleText:SetText("Item Upgrade");
	end
	
	-- Hide deprecated PlayerCurrencies frame completely
	if self.PlayerCurrencies then
		self.PlayerCurrencies:Hide();
		self.PlayerCurrencies:SetAlpha(0);
		self.PlayerCurrencies:ClearAllPoints();
		self.PlayerCurrencies:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, 5000);
	end
	
	-- Initialize the dropdown using global name for WoW 3.3.5 compatibility
	local dropdown = _G["DarkChaos_ItemUpgradeFrameDropdown"] or (self.DropdownContainer and self.DropdownContainer.Dropdown);
	if dropdown then
		UIDropDownMenu_SetWidth(dropdown, 120);
		UIDropDownMenu_Initialize(dropdown, DarkChaos_ItemUpgrade_Dropdown_Initialize);
		dropdown:Show(); -- Ensure dropdown frame is visible
	end
	
	-- Create settings button in the title bar area (next to close button)
	local settingsBtn = CreateFrame("Button", "DarkChaos_ItemUpgradeSettingsBtn", self);
	settingsBtn:SetWidth(24);
	settingsBtn:SetHeight(24);
	settingsBtn:SetPoint("TOPRIGHT", self, "TOPRIGHT", -50, -6);
	settingsBtn:SetFrameLevel(self:GetFrameLevel() + 10);
	
	-- Create a visible texture background
	local btnBg = settingsBtn:CreateTexture(nil, "BACKGROUND");
	btnBg:SetAllPoints();
	btnBg:SetTexture("Interface\\Buttons\\UI-OptionsButton");
	btnBg:SetVertexColor(1, 1, 1, 1);
	
	-- Highlight on hover
	local btnHighlight = settingsBtn:CreateTexture(nil, "HIGHLIGHT");
	btnHighlight:SetAllPoints();
	btnHighlight:SetTexture("Interface\\Buttons\\ButtonHilight-Round");
	btnHighlight:SetBlendMode("ADD");
	
	settingsBtn:SetScript("OnClick", function()
		DarkChaos_ItemUpgrade_ShowQuickSettings();
	end);
	settingsBtn:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_RIGHT");
		GameTooltip:SetText("Quick Settings");
		GameTooltip:AddLine("Click to open settings menu", 1, 1, 1);
		GameTooltip:AddLine("Type /dcu help for commands", 0.7, 0.7, 0.7);
		GameTooltip:Show();
	end);
	settingsBtn:SetScript("OnLeave", function()
		GameTooltip:Hide();
	end);
	settingsBtn:Show();
	
	-- Create Stat Package Selector for Heirloom mode (hidden by default)
	DarkChaos_ItemUpgrade_CreateStatPackageSelector(self);
	
	tinsert(UISpecialFrames, self:GetName());
end

function DarkChaos_ItemUpgrade_OnShow(self)
	DC.PlaySound("igCharacterInfoOpen");
	
	self:RegisterEvent("PLAYER_MONEY");
	self:RegisterEvent("BAG_UPDATE");
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
	self:RegisterEvent("UNIT_INVENTORY_CHANGED");
	self:RegisterEvent("GET_ITEM_INFO_RECEIVED");
	self:RegisterEvent("CHAT_MSG_SYSTEM");
	self:RegisterEvent("CHAT_MSG_SAY");
	self:RegisterEvent("CHAT_MSG_WHISPER");
	self:RegisterEvent("PLAYER_REGEN_DISABLED");
	
	DarkChaos_ItemUpgrade_RequestCurrencies();
	DarkChaos_ItemUpgrade_UpdateUI();
end

function DarkChaos_ItemUpgrade_OnHide(self)
	DC.PlaySound("igCharacterInfoClose");
	DC.upgradeAnimationTime = 0;

	if self.Arrow then
		self.Arrow:Hide();
	end

	if self.UpgradeButton and self.UpgradeButton.Glow then
		self.UpgradeButton.Glow:Hide();
	end

	if self.LeftTooltip then
		self.LeftTooltip:Hide();
	end

	if self.RightTooltip then
		self.RightTooltip:Hide();
	end

	if DarkChaos_ItemBrowserFrame and DarkChaos_ItemBrowserFrame:IsShown() then
		DarkChaos_ItemBrowserFrame:Hide();
	end

	if GameTooltip and GameTooltip:IsShown() then
		GameTooltip:Hide();
	end

	-- Reset package selection mode when closing
	DC.inPackageSelectionMode = false;
	DC.isChangingPackage = false;
	
	-- Hide stat package selector
	if self.StatPackageSelector then
		self.StatPackageSelector:Hide();
	end

	DC.pendingUpgrade = nil;
end

local function InvalidateCachedItemData()
	DC.itemTooltipCache = {};
	DC.itemScanCache = {};
	DC.itemScanCacheTime = 0;
end

local function RefreshBrowserIfOpen()
	if DarkChaos_ItemBrowserFrame and DarkChaos_ItemBrowserFrame:IsShown() then
		DarkChaos_ItemBrowser_Update();
	end
end

local function RefreshCurrentSelectedItem()
	if not DC.currentItem then
		return;
	end

	local link = GetItemLinkForLocation(DC.currentItem.bag, DC.currentItem.slot);
	if not link then
		DC.Debug("Selected item link missing; deferring refresh until data is available");
		-- Item may be temporarily removed during upgrade swaps; keep state and retry on next event.
		return;
	end

	RefreshCurrentItemMetadata(link);
	DC.currentItem.texture = GetItemTextureForLocation(DC.currentItem.bag, DC.currentItem.slot, link);
	DarkChaos_ItemUpgrade_RequestItemInfo();
	DarkChaos_ItemUpgrade_UpdateUI();
end

function DarkChaos_ItemUpgrade_OnEvent(self, event, ...)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN");
		DarkChaos_ItemUpgrade_InitializeCosts();
		DC.pendingUpgrade = nil;
		DarkChaos_ItemUpgrade_RequestCurrencies();
		DarkChaos_ItemUpgrade_UpdateUI();
		-- Create and register settings panel
		if DC.CreateSettingsPanel then
			DC.CreateSettingsPanel();
		end
		-- Create Communication sub-panel (must be after main settings panel)
		if DC.CreateCommPanel then
			DC.CreateCommPanel();
		end
		-- Hook tooltip functions for upgrade info display
		DarkChaos_ItemUpgrade_HookTooltips();
		-- Load per-character settings
		DarkChaos_ItemUpgrade_LoadCharSettings();
		return;
	end
	
	-- Auto-close on combat start
	if event == "PLAYER_REGEN_DISABLED" then
		if self:IsShown() then
			self:Hide();
			DEFAULT_CHAT_FRAME:AddMessage("|cffff8800Item Upgrade window closed (entered combat).|r");
		end
		return;
	end

	if event == "CHAT_MSG_SAY" or event == "CHAT_MSG_WHISPER" then
		local message, sender = ...;
		DarkChaos_ItemUpgrade_OnChatMessage(message, sender);
		return;
	end

	if event == "CHAT_MSG_SYSTEM" then
		local message = ...;
		-- Debug: Log raw system messages that might be ours
		if type(message) == "string" and (string.find(message, "DCUPGRADE_") or string.find(message, "DCHEIRLOOM_")) then
			DC.Debug("CHAT_MSG_SYSTEM raw: " .. string.sub(message, 1, 80));
		end
		if type(message) == "string" then
			-- Handle both DCUPGRADE_ and DCHEIRLOOM_ messages
			if string.find(message, "^DCUPGRADE_") or string.find(message, "^DCHEIRLOOM_") then
				DarkChaos_ItemUpgrade_OnChatMessage(message, UnitName("player"));
			end
		end
		return;
	end

	if event == "BAG_UPDATE" then
		local bagID = ...;
		InvalidateCachedItemData();
		if DC.currentItem and not DC.currentItem.isEquipped and bagID == DC.currentItem.bag then
			RefreshCurrentSelectedItem();
		end
		RefreshBrowserIfOpen();
		return;
	end

	if event == "PLAYER_EQUIPMENT_CHANGED" then
		local slotID = ...;
		InvalidateCachedItemData();
		if DC.currentItem and DC.currentItem.isEquipped and slotID == DC.currentItem.slot then
			RefreshCurrentSelectedItem();
		end
		RefreshBrowserIfOpen();
		return;
	end

	if event == "UNIT_INVENTORY_CHANGED" then
		local unit = ...;
		if unit == "player" then
			InvalidateCachedItemData();
			if DC.currentItem and DC.currentItem.isEquipped then
				RefreshCurrentSelectedItem();
			end
			RefreshBrowserIfOpen();
		end
		return;
	end

	if event == "GET_ITEM_INFO_RECEIVED" then
		RefreshBrowserIfOpen();
		return;
	end
end

--[[=====================================================
    PER-CHARACTER SETTINGS SAVE/LOAD
=====================================================]]--

function DarkChaos_ItemUpgrade_LoadCharSettings()
	-- Initialize saved variables table if not exists
	if not DC_ItemUpgrade_CharSettings then
		DC_ItemUpgrade_CharSettings = {};
	end
	
	-- Load saved stat package selection
	if DC_ItemUpgrade_CharSettings.selectedStatPackage then
		local savedPackage = DC_ItemUpgrade_CharSettings.selectedStatPackage;
		-- Validate it's a valid package ID (1-12)
		if type(savedPackage) == "number" and savedPackage >= 1 and savedPackage <= 12 and DC.STAT_PACKAGES and DC.STAT_PACKAGES[savedPackage] then
			DC.selectedStatPackage = savedPackage;
			local pkg = DC.STAT_PACKAGES[savedPackage];
			DC.Debug("Loaded saved stat package: " .. pkg.name .. " (ID: " .. savedPackage .. ")");
		else
			DC.Debug("Invalid saved package ID, resetting: " .. tostring(savedPackage));
			DC_ItemUpgrade_CharSettings.selectedStatPackage = nil;
		end
	end
end

function DarkChaos_ItemUpgrade_SaveCharSettings()
	-- Initialize saved variables table if not exists
	if not DC_ItemUpgrade_CharSettings then
		DC_ItemUpgrade_CharSettings = {};
	end
	
	-- Save current stat package selection
	if DC.selectedStatPackage then
		DC_ItemUpgrade_CharSettings.selectedStatPackage = DC.selectedStatPackage;
		DC.Debug("Saved stat package selection: " .. DC.selectedStatPackage);
	end
end

function DarkChaos_ItemUpgrade_OnUpdate(self, elapsed)
	-- Arrow animation (bounce left-right)
	if self.Arrow and self.Arrow:IsShown() then
		DC.arrowAnimationTime = (DC.arrowAnimationTime or 0) + elapsed;
		local cycle = DC.arrowAnimationTime % 2.0; -- 2 second cycle
		local anchorFrame = self.CurrentPanel or self.LeftTooltip or self;
		local offset = math.min(cycle, 1.0) * 30;
		self.Arrow:ClearAllPoints();
		self.Arrow:SetPoint("CENTER", anchorFrame, "RIGHT", 20 + offset, -20);
		
		if cycle < 1.0 then
			-- Move right, fade in
			local alpha = math.min(1.0, cycle * 2);
			self.Arrow.Texture:SetAlpha(alpha);
		else
			-- Fade out
			local progress = cycle - 1.0;
			local alpha = math.max(0, 1.0 - progress * 2);
			self.Arrow.Texture:SetAlpha(alpha);
		end
	end
	
	-- Button glow pulse (enhanced for better visibility)
	if self.UpgradeButton and self.UpgradeButton:IsEnabled() and self.UpgradeButton.Glow:IsShown() then
		DC.glowAnimationTime = (DC.glowAnimationTime or 0) + elapsed;
		local alpha = 0.4 + math.sin(DC.glowAnimationTime * 3) * 0.35; -- Enhanced: wider range, faster pulse
		self.UpgradeButton.Glow:SetAlpha(alpha);
	end

	-- Upgrade celebration animation
	if DC.upgradeAnimationTime > 0 then
		DC.upgradeAnimationTime = DC.upgradeAnimationTime - elapsed;
		if DC.upgradeAnimationTime <= 0 then
			DC.upgradeAnimationTime = 0;
			local tooltip = self.RightTooltip;
			if tooltip and tooltip.UpgradeGlow then
				tooltip.UpgradeGlow:Hide();
			end
			DarkChaos_ItemUpgrade_UpdateUI();
		end
	end
	
	-- Process batch queries
	if DC.batchQueryTimer > 0 then
		DC.batchQueryTimer = DC.batchQueryTimer - elapsed;
		if DC.batchQueryTimer <= 0 then
			DC.batchQueryTimer = 0;
			DC.ProcessBatchQueries();
		end
	end
end

--[[=====================================================
	ITEM BROWSER
=======================================================]]

function DarkChaos_ItemBrowser_OnLoad(self)
	tinsert(UISpecialFrames, self:GetName());
	self:RegisterForDrag("LeftButton");
	
	-- Create buttons for scroll frame
	-- In WoW 3.3.5a, FauxScrollFrame buttons must be parented to the frame containing the scroll frame
	-- and positioned relative to the scroll frame's position, not as children of it
	local scrollFrame = self.ScrollFrame;
	scrollFrame.buttons = {};
	
	for i = 1, 10 do
		-- Parent to the main browser frame, not the scroll frame
		local button = CreateFrame("Button", "DarkChaos_ItemBrowserButton"..i, self);
		button:SetWidth(250);
		button:SetHeight(32);
		
		-- Position relative to the scroll frame's position in the parent
		button:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -(i-1)*32);
		
		-- Create background texture for visibility
		button.Background = button:CreateTexture(nil, "BACKGROUND");
		button.Background:SetAllPoints();
		button.Background:SetTexture("Interface\\Buttons\\WHITE8X8");
		button.Background:SetVertexColor(0.1, 0.1, 0.1, 0.3);
		
		-- Item icon
		button.Icon = button:CreateTexture(nil, "ARTWORK");
		button.Icon:SetWidth(28);
		button.Icon:SetHeight(28);
		button.Icon:SetPoint("LEFT", 2, 0);
		button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); -- Slight inset to avoid icon borders
		
		-- Item name text
		button.Name = button:CreateFontString(nil, "ARTWORK", "GameFontNormal");
		button.Name:SetPoint("LEFT", button.Icon, "RIGHT", 6, 0);
		button.Name:SetPoint("RIGHT", button, "RIGHT", -4, 0);
		button.Name:SetJustifyH("LEFT");
		button.Name:SetWordWrap(false);
		
		-- Highlight texture
		button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
		button:GetHighlightTexture():SetBlendMode("ADD");
		
		-- Make clickable
		button:EnableMouse(true);
		button:SetScript("OnClick", DarkChaos_ItemBrowserButton_OnClick);
		button:SetScript("OnEnter", function(self)
			if self.item and self.item.link then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
				GameTooltip:SetHyperlink(self.item.link);
				GameTooltip:Show();
			end
		end);
		button:SetScript("OnLeave", function(self)
			GameTooltip:Hide();
		end);
		
		-- Initially hidden
		button:Hide();
		
		scrollFrame.buttons[i] = button;
	end
	
	print("[DC-ItemUpgrade] ItemBrowser_OnLoad: Created " .. #scrollFrame.buttons .. " buttons");
end

function DarkChaos_ItemBrowser_OnShow(self)
	DarkChaos_ItemBrowser_Update();
end

-- Valid equipment slot types for upgrades (armor, weapons, trinkets, rings, etc.)
local UPGRADEABLE_EQUIP_LOCS = {
	["INVTYPE_HEAD"] = true,
	["INVTYPE_NECK"] = true,
	["INVTYPE_SHOULDER"] = true,
	["INVTYPE_BODY"] = true,       -- Shirt slot (for Heirloom Adventurer's Shirt 300365)
	["INVTYPE_CHEST"] = true,
	["INVTYPE_ROBE"] = true,
	["INVTYPE_WAIST"] = true,
	["INVTYPE_LEGS"] = true,
	["INVTYPE_FEET"] = true,
	["INVTYPE_WRIST"] = true,
	["INVTYPE_HAND"] = true,
	["INVTYPE_FINGER"] = true,
	["INVTYPE_TRINKET"] = true,
	["INVTYPE_CLOAK"] = true,
	["INVTYPE_WEAPON"] = true,
	["INVTYPE_SHIELD"] = true,
	["INVTYPE_2HWEAPON"] = true,
	["INVTYPE_WEAPONMAINHAND"] = true,
	["INVTYPE_WEAPONOFFHAND"] = true,
	["INVTYPE_HOLDABLE"] = true,
	["INVTYPE_RANGED"] = true,
	["INVTYPE_THROWN"] = true,
	["INVTYPE_RANGEDRIGHT"] = true,
	["INVTYPE_RELIC"] = true,
};

-- Check if an item is a valid upgradeable equipment piece
-- Filters based on current UI mode (STANDARD vs HEIRLOOM)
local function IsUpgradeableItem(link)
	if not link then return false end
	
	local _, _, quality, _, _, itemType, itemSubType, _, equipLoc = GetItemInfo(link);
	
	-- Must be equipment with a valid equip location
	if not equipLoc or equipLoc == "" or not UPGRADEABLE_EQUIP_LOCS[equipLoc] then
		return false;
	end
	
	-- Tier-1 items can be common (white). Exclude poor (gray) and unknown.
	if not quality or quality < 1 then
		return false;
	end
	
	-- Parse item ID from link
	local itemId = tonumber(string.match(link, "item:(%d+)"));
	
	-- Filter based on UI mode
	local isHeirloomMode = (DC.uiMode == "HEIRLOOM");
	
	-- The specific heirloom item that can be upgraded via Heirloom UI
	local HEIRLOOM_UPGRADE_ITEM = 300365; -- Heirloom Adventurer's Shirt
	
	-- Check if item is an heirloom (quality 7) or the specific heirloom upgrade item
	local isHeirloomQuality = (quality == 7);
	local isHeirloomUpgradeItem = (itemId == HEIRLOOM_UPGRADE_ITEM);
	
	if isHeirloomMode then
		-- In Heirloom mode, only show the specific heirloom upgrade item (300365)
		return isHeirloomUpgradeItem;
	else
		-- In Standard mode, exclude ALL heirloom quality items AND the specific heirloom item
		if isHeirloomQuality or isHeirloomUpgradeItem then
			return false;
		end
		return true;
	end
end

function DarkChaos_ItemBrowser_Update()
	local items = {};
	
	DC.Debug("ItemBrowser_Update called");
	
	-- Collect items from bags
	for bag = 0, 4 do
		local numSlots = GetContainerNumSlots(bag);
		for slot = 1, numSlots do
			local link = GetContainerItemLink(bag, slot);
			if link then
				local isUpgradeable = IsUpgradeableItem(link);
				if isUpgradeable then
					local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(link);
					if name then
						tinsert(items, {
							bag = bag,
							slot = slot,
							link = link,
							name = name,
							quality = quality,
							texture = texture
						});
					end
				end
			end
		end
	end
	
	-- Collect equipped items
	for _, slot in ipairs(EQUIPMENT_SLOTS) do
		local link = GetInventoryItemLink("player", slot);
		if link then
			local isUpgradeable = IsUpgradeableItem(link);
			if isUpgradeable then
				local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(link);
				if name then
					tinsert(items, {
						bag = BAG_EQUIPPED,
						slot = slot,
						link = link,
						name = name,
						quality = quality,
						texture = texture
					});
				end
			end
		end
	end
	
	DC.Debug("Found " .. #items .. " items");
	
	local scrollFrame = DarkChaos_ItemBrowserFrame.ScrollFrame;
	if not scrollFrame then
		print("[DC-ItemUpgrade] ERROR: ScrollFrame is nil!");
		return;
	end
	if not scrollFrame.buttons then
		print("[DC-ItemUpgrade] ERROR: ScrollFrame.buttons is nil!");
		return;
	end
	
	DC.Debug("ScrollFrame OK, buttons count: " .. #scrollFrame.buttons);
	
	FauxScrollFrame_Update(scrollFrame, #items, 10, 32);
	
	local offset = FauxScrollFrame_GetOffset(scrollFrame);
	DC.Debug("Offset: " .. offset);
	
	for i = 1, 10 do
		local index = offset + i;
		local button = scrollFrame.buttons[i];
		if button then
			if index <= #items then
				local item = items[index];
				DC.Debug("Button " .. i .. ": showing item " .. tostring(item.name));
				
				-- Set icon
				if button.Icon then
					button.Icon:SetTexture(item.texture);
				end
				
				-- Set name with quality color
				if button.Name then
					local color = ITEM_QUALITY_COLORS[item.quality];
					if color then
						button.Name:SetTextColor(color.r, color.g, color.b);
					else
						button.Name:SetTextColor(1, 1, 1);
					end
					button.Name:SetText(item.name);
				end
				
				-- Store item data and show
				button.item = item;
				button:Show();
			else
				button:Hide();
			end
		else
			print("[DC-ItemUpgrade] Button " .. i .. " is nil!");
		end
	end
end

function DarkChaos_ItemBrowserButton_OnClick(self)
	if self.item then
		DarkChaos_ItemUpgrade_SelectItemBySlot(self.item.bag, self.item.slot);
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

	local currentUpgrade = DC.currentItem.currentUpgrade or 0;
	local maxUpgrade = DC.currentItem.maxUpgrade or DC.MAX_UPGRADE_LEVEL;
	local tier = DC.currentItem.tier or 1;
	local targetLevel = math.floor(DC.targetUpgradeLevel or (currentUpgrade + 1));
	targetLevel = math.min(math.max(targetLevel, currentUpgrade + 1), maxUpgrade);

	-- Safety checks
	if currentUpgrade >= maxUpgrade then
		print("|cffff0000Cannot upgrade: Item is already at maximum upgrade level.|r");
		return;
	end

	if targetLevel <= currentUpgrade then
		print("|cffff0000Cannot upgrade: Target level must be higher than current level.|r");
		return;
	end

	if targetLevel > maxUpgrade then
		print("|cffff0000Cannot upgrade: Target level exceeds maximum allowed.|r");
		return;
	end

	-- Check if stat package is required for heirloom shirt
	local isHeirloomShirt = false;
	local packageId = 0;
	if DC.uiMode == "HEIRLOOM" and DC.currentItem.link then
		local itemID = tonumber(DC.currentItem.link:match("item:(%d+)"));
		if itemID == 300365 then
			isHeirloomShirt = true;
			if not DC.selectedStatPackage or DC.selectedStatPackage <= 0 then
				print("|cffff0000Please select a stat package first!|r");
				return;
			end
			packageId = DC.selectedStatPackage;
		end
	end

	local totals = DarkChaos_ItemUpgrade_ComputeCostTotals(tier, currentUpgrade, targetLevel);
	local singleCost = DarkChaos_ItemUpgrade_GetCost(tier, targetLevel);
	if (totals.tokens or 0) <= 0 and not singleCost then
		print("|cffff0000Upgrade failed:|r Unable to determine the cost for the selected level.");
		return;
	end

	local requiredTokens = singleCost and (singleCost.tokens or 0) or (totals.tokens or 0);

	if (DC.playerTokens or 0) < requiredTokens then
		print(string.format("|cffff0000Not enough Upgrade Tokens!|r Need %d but have %d.", requiredTokens, DC.playerTokens or 0));
		return;
	end

	SetButtonEnabled(self, false);
	if self.Glow then
		self.Glow:Hide();
	end

	local serverBag = DC.currentItem.serverBag or DC.currentItem.bag;
	local serverSlot = DC.currentItem.serverSlot or math.max(0, (DC.currentItem.slot or 1) - 1);
	local command;
	
	-- Use different command for heirloom shirt upgrades (includes package ID)
	if isHeirloomShirt then
		if DCProtocol and DC.useDCProtocol then
			local data = string.format("%d|%d|%d|%d", serverBag, serverSlot, targetLevel, packageId)
			DCProtocol:Send("UPG", 0x07, data) -- CMSG_HEIRLOOM_UPGRADE
			DC.Debug("Sending heirloom upgrade: " .. data)
		else
			command = string.format(".dcheirloom upgrade %d %d %d %d", serverBag, serverSlot, targetLevel, packageId);
			SendChatMessage(command, "SAY");
		end
	else
		DC.RequestUpgrade(serverBag, serverSlot, targetLevel);
	end
	
	DC.pendingUpgrade = {
		target = targetLevel,
		startLevel = currentUpgrade,
		bag = serverBag,
		slot = DC.currentItem.slot,
		serverSlot = serverSlot,
		tier = tier,
		packageId = packageId,
		isHeirloom = isHeirloomShirt,
		cost = {
			tokens = totals.tokens or requiredTokens,
		},
	};
	-- DC.Debug("Sending perform command: "..command); -- Legacy debug
	local itemLabel = DC.currentItem.link or DC.currentItem.name or "item";
	local projectedTokens = (totals.tokens or 0) > 0 and totals.tokens or requiredTokens;
	DC.Debug(string.format("Upgrading %s to level %d/%d...", itemLabel, targetLevel, maxUpgrade));
	if isHeirloomShirt then
		local pkg = DC.STAT_PACKAGES[packageId];
		if pkg then
			DC.Debug(string.format("[Stat Package] %s - %s", pkg.name, table.concat(pkg.stats, ", ")));
		end
	end
	if projectedTokens > 0 then
		DC.Debug(string.format("Projected total to reach level %d: %d Tokens", targetLevel, projectedTokens));
	end
	if singleCost and (singleCost.tokens or 0) > 0 then
		DC.Debug(string.format("Immediate cost for this step: %d Tokens", singleCost.tokens));
	end
	-- SendChatMessage(command, "SAY"); -- Moved inside block above
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
	
	local currentUpgrade = DC.currentItem.currentUpgrade or 0;
	local maxUpgrade = DC.currentItem.maxUpgrade or DC.GetMaxUpgradeLevelForTier(DC.currentItem.tier);

	-- Ensure target level is valid
	if DC.targetUpgradeLevel <= currentUpgrade then
		DC.targetUpgradeLevel = currentUpgrade + 1;
	end
	if DC.targetUpgradeLevel > maxUpgrade then
		DC.targetUpgradeLevel = maxUpgrade;
	end
	
	local info = UIDropDownMenu_CreateInfo();
	for level = currentUpgrade + 1, maxUpgrade do
		info.text = "Level " .. level .. " / " .. maxUpgrade;
		info.value = level;
		info.func = function(self)
			DC.targetUpgradeLevel = self.value;
			DarkChaos_ItemUpgrade_UpdateUI();
		end;
		info.checked = (DC.targetUpgradeLevel == level);
		
		-- Color red if can't afford
		local cost = DarkChaos_ItemUpgrade_GetCost(DC.currentItem.tier, level);
		if cost and DC.playerTokens < (cost.tokens or 0) then
			info.colorCode = "|cffff3333";
		else
			info.colorCode = "|cffffffff";
		end
		
		UIDropDownMenu_AddButton(info);
	end
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
	
	-- Find item in bags first
	for bag = BAG_BACKPACK, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot);
			if link and link == itemLink then
				DarkChaos_ItemUpgrade_SelectItemBySlot(bag, slot);
				return;
			end
		end
	end

	-- Check equipped slots
	for _, equipSlot in ipairs(EQUIPMENT_SLOTS) do
		local link = GetInventoryItemLink("player", equipSlot);
		if link and link == itemLink then
			DarkChaos_ItemUpgrade_SelectItemBySlot(BAG_EQUIPPED, equipSlot);
			return;
		end
	end

	print("|cffff0000Item not found in bags or equipped.|r");
end

function DarkChaos_ItemUpgrade_SelectItemBySlot(bag, slot)
	if bag == nil or slot == nil then
		return;
	end

	local isEquipped = IsEquippedBag(bag);
	local link = isEquipped and GetInventoryItemLink("player", slot) or GetContainerItemLink(bag, slot);
	if not link then
		print("|cffff0000No item found at that location.|r");
		return;
	end

	local name, _, quality, level = GetItemInfo(link);
	local _, _, _, _, itemID = string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?");
	itemID = tonumber(itemID);

	local serverBag = GetServerBagFromClient(bag);
	local serverSlot = GetServerSlotFromClient(bag, slot);
	local texture = GetItemTextureForLocation(bag, slot, link);
 	local locationKey = BuildLocationKey(serverBag, serverSlot);
	local cached = DC.itemUpgradeCache and DC.itemLocationCache and DC.itemLocationCache[locationKey] and DC.itemUpgradeCache[DC.itemLocationCache[locationKey]];

	-- Use pooled object for current item
	local pooledItem = DC.GetPooledItemState();
	
	pooledItem.bag = bag;
	pooledItem.serverBag = serverBag;
	pooledItem.slot = slot;
	pooledItem.serverSlot = serverSlot;
	pooledItem.locationKey = locationKey;
	pooledItem.isEquipped = isEquipped;
	pooledItem.texture = texture;
	pooledItem.link = link;
	pooledItem.itemID = itemID;
	pooledItem.quality = quality;
	pooledItem.name = name;
	pooledItem.level = level;
	pooledItem.baseLevel = level;
	pooledItem.upgradedLevel = level;
	
	-- SPECIAL HANDLING: Heirloom Adventurer's Shirt (300365)
	-- Force tier 3 with 15 max levels immediately for UI responsiveness
	local HEIRLOOM_SHIRT_ID = 300365;
	if itemID == HEIRLOOM_SHIRT_ID then
		pooledItem.tier = 3;  -- TIER_HEIRLOOM
		pooledItem.maxUpgrade = 15;
		DC.Debug("SelectItemBySlot: Initialized heirloom shirt with tier 3, max 15 levels");
	else
		pooledItem.tier = 1;
		pooledItem.maxUpgrade = DC.GetMaxUpgradeLevelForTier(1);  -- Default to tier 1, will be updated when data arrives
	end
	
	pooledItem.currentUpgrade = 0;
	pooledItem.statMultiplier = GetStatMultiplierForLevel(0, pooledItem.tier);
	pooledItem.ilevelStep = GetItemLevelBonus(1, pooledItem.tier);
	pooledItem.statPerLevel = GetStatBonusPercent(1, pooledItem.tier) - GetStatBonusPercent(0, pooledItem.tier);
	pooledItem.baseEntry = itemID;
	pooledItem.currentEntry = itemID;
	pooledItem.cloneEntries = {
		[0] = itemID,
	};

	-- Return old item to pool if it exists
	if DC.currentItem then
		DC.ReturnPooledItemState(DC.currentItem);
	end
	
	DC.currentItem = pooledItem;
	DC.targetUpgradeLevel = 1;
	
	if cached then
		DarkChaos_ItemUpgrade_ApplyQueryData(DC.currentItem, cached);
		if cached.guid then
			DC.itemLocationCache[locationKey] = cached.guid;
		end
	end

	DC.Debug(string.format("SelectItemBySlot bag=%d slot=%d serverSlot=%d", serverBag or -1, slot or -1, serverSlot));
	DarkChaos_ItemUpgrade_QueueQuery(serverBag, serverSlot, {
		type = "selection",
		locationKey = locationKey,
	});
	
	-- For heirloom items, also send a heirloom-specific query
	local HEIRLOOM_SHIRT_ID = 300365;
	if itemID == HEIRLOOM_SHIRT_ID then
		DC.Debug("SelectItemBySlot: Sending heirloom query for item 300365");
		if DCProtocol and DC.useDCProtocol then
			DCProtocol:Send("UPG", 0x06, string.format("%d|%d", serverBag, serverSlot)) -- CMSG_HEIRLOOM_QUERY
		else
			local heirloomCmd = string.format(".dcheirloom query %d %d", serverBag, serverSlot);
			SendChatMessage(heirloomCmd, "SAY");
		end
	end
	
	DarkChaos_ItemUpgrade_UpdateUI();

	if DarkChaos_ItemBrowserFrame:IsShown() then
		DarkChaos_ItemBrowserFrame:Hide();
	end
end

function DarkChaos_ItemUpgrade_ClearItem()
	-- Return current item to pool if it exists
	if DC.currentItem then
		DC.ReturnPooledItemState(DC.currentItem);
		DC.currentItem = nil;
	end
	
	DC.targetUpgradeLevel = 1;
	DC.pendingUpgrade = nil;
	DarkChaos_ItemUpgrade_UpdateUI();
end

-- Auto-find and select the Heirloom Adventurer's Shirt (item 300365)
function DarkChaos_ItemUpgrade_AutoSelectHeirloomShirt()
	local HEIRLOOM_SHIRT_ID = 300365;
	
	-- First check if wearing it (body slot = 4)
	local equippedLink = GetInventoryItemLink("player", 4);
	if equippedLink then
		local itemID = tonumber(equippedLink:match("item:(%d+)"));
		if itemID == HEIRLOOM_SHIRT_ID then
			DC.Debug("AutoSelectHeirloomShirt: Found equipped at slot 4");
			DarkChaos_ItemUpgrade_SelectItemBySlot(BAG_EQUIPPED, 4);
			return true;
		end
	end
	
	-- Check bags
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot);
			if link then
				local itemID = tonumber(link:match("item:(%d+)"));
				if itemID == HEIRLOOM_SHIRT_ID then
					DC.Debug(string.format("AutoSelectHeirloomShirt: Found in bag %d slot %d", bag, slot));
					DarkChaos_ItemUpgrade_SelectItemBySlot(bag, slot);
					return true;
				end
			end
		end
	end
	
	-- Not found
	DEFAULT_CHAT_FRAME:AddMessage("|cffff8800[DC-ItemUpgrade]|r Heirloom Adventurer's Shirt not found. Please equip or place it in your bags.");
	return false;
end

function DarkChaos_ItemUpgrade_UpdatePlayerCurrencies()
	local frame = DarkChaos_ItemUpgradeFrame;
	if not frame then return end
	
	-- Update internal currency values
	-- Use default IDs if not set
	local tokenID = DC.TOKEN_ITEM_ID or 49426; -- Frost Emblem as default placeholder
	local essenceID = DC.ESSENCE_ITEM_ID or 43102; -- Dream Shard as default placeholder
	
	DC.playerTokens = GetItemCount(tokenID) or 0;
	DC.playerEssence = GetItemCount(essenceID) or 0;
	
	-- PlayerCurrencies is deprecated - keep it hidden, CostFrame handles display now
	if frame.PlayerCurrencies then
		frame.PlayerCurrencies:Hide();
	end
end

--[[=====================================================
	UI UPDATE
=======================================================]]

function DarkChaos_ItemUpgrade_UpdateUI()
	local frame = DarkChaos_ItemUpgradeFrame;
	if not frame then return end
	if not (frame.ItemSlot and frame.ItemInfo) then return end
	-- Use global dropdown name for WoW 3.3.5 compatibility
	local dropdown = _G["DarkChaos_ItemUpgradeFrameDropdown"] or (frame.DropdownContainer and frame.DropdownContainer.Dropdown) or frame.Dropdown;

	-- Currency counts always stay in sync
	DarkChaos_ItemUpgrade_UpdatePlayerCurrencies();
	DarkChaos_ItemUpgrade_UpdateCost();

	-- Clear celebration overlay when idle
	if frame.RightTooltip and frame.RightTooltip.UpgradeGlow and DC.upgradeAnimationTime <= 0 then
		frame.RightTooltip.UpgradeGlow:Hide();
	end
	
	-- If in package selection mode, don't update the main UI elements
	if DC.inPackageSelectionMode then
		return;
	end

	if not DC.currentItem then
		-- Ensure key UI elements are visible (they may have been hidden by package selection mode)
		if frame.ItemSlot then frame.ItemSlot:Show(); end
		if frame.ItemInfo then frame.ItemInfo:Show(); end
		if frame.UpgradeButton then frame.UpgradeButton:Show(); end
		
		frame.ItemSlot.EmptyGlow:Show();
		SetItemButtonTexture(frame.ItemSlot, nil);
		local normalTexture = _G[frame.ItemSlot:GetName().."NormalTexture"];
		if normalTexture then
			normalTexture:SetTexture("Interface\\Buttons\\UI-Quickslot2");
			normalTexture:SetVertexColor(1, 1, 1);
		end
		frame.ItemInfo.MissingItemText:Show();
		frame.ItemInfo.ItemName:Hide();
		if frame.ItemInfo.ItemLevelSummary then frame.ItemInfo.ItemLevelSummary:Hide(); end
		frame.ItemInfo.UpgradeProgress:Hide();
		if frame.ItemInfo.ProgressBar then frame.ItemInfo.ProgressBar:Hide(); end
		if frame.UpgradeSelector then frame.UpgradeSelector:Hide(); end
		if dropdown then
			dropdown:Hide();
			UIDropDownMenu_SetText(dropdown, "");
		end
		if frame.CurrentPanel then
			frame.CurrentPanel:Hide();
			if frame.CurrentPanel.StatsText then frame.CurrentPanel.StatsText:SetText(""); end
			if frame.CurrentPanel.CurrencyHeader then frame.CurrentPanel.CurrencyHeader:Hide(); end
			if frame.CurrentPanel.CurrencyDetail then frame.CurrentPanel.CurrencyDetail:Hide(); end
		end
		if frame.UpgradePanel then
			frame.UpgradePanel:Hide();
			if frame.UpgradePanel.StatsText then frame.UpgradePanel.StatsText:SetText(""); end
			if frame.UpgradePanel.CostHeader then frame.UpgradePanel.CostHeader:Hide(); end
			if frame.UpgradePanel.CostDetail then frame.UpgradePanel.CostDetail:Hide(); end
		end
		if frame.DropdownContainer then frame.DropdownContainer:Hide(); end
		frame.LeftTooltip:Hide();
		frame.RightTooltip:Hide();
		if frame.Arrow then frame.Arrow:Hide(); end
		if frame.CostFrame then frame.CostFrame:Show(); end
		frame.ErrorText:Hide();
		frame.MissingDescription:Show();
		if frame.PlayerCurrencies then frame.PlayerCurrencies:Hide(); end
		if frame.StatPackageSelector then frame.StatPackageSelector:Hide(); end
		if frame.PackageIndicator then frame.PackageIndicator:Hide(); end
		if frame.ChangePackageButton then frame.ChangePackageButton:Hide(); end
		SetButtonEnabled(frame.UpgradeButton, false);
		frame.UpgradeButton.Glow:Hide();
		frame.UpgradeButton.disabledTooltip = nil;
		DarkChaos_ItemUpgrade_UpdateCost();
		return;
	end

	local item = DC.currentItem;
	local currentUpgrade = item.currentUpgrade or 0;
	local maxUpgrade = item.maxUpgrade or DC.GetMaxUpgradeLevelForTier(item.tier);
	local tierName = DC.TIER_NAMES[item.tier] or string.format("Tier %d", item.tier or 0);
	local baseLevel = ResolveBaseItemLevel(item);
	item.baseLevel = baseLevel;

	local currentLevel = ResolveUpgradeItemLevel(item, currentUpgrade, baseLevel);
	local maxPotential = ResolveUpgradeItemLevel(item, maxUpgrade, baseLevel);

	currentLevel = math.max(baseLevel, currentLevel);
	
	-- Ensure key UI elements are visible (they may have been hidden by package selection mode or other states)
	if frame.ItemSlot then frame.ItemSlot:Show(); end
	if frame.ItemInfo then frame.ItemInfo:Show(); end
	if frame.UpgradeButton then frame.UpgradeButton:Show(); end
	if frame.CostFrame then frame.CostFrame:Show(); end
	
	-- Update Item Slot
	frame.ItemSlot.EmptyGlow:Hide();
	SetItemButtonTexture(frame.ItemSlot, item.texture or "Interface\\Icons\\INV_Misc_QuestionMark");
	local normalTexture = _G[frame.ItemSlot:GetName().."NormalTexture"];
	if normalTexture then
		if item.quality and item.quality > 1 then
			local r, g, b = GetItemQualityColor(item.quality);
			normalTexture:SetVertexColor(r, g, b);
		else
			normalTexture:SetVertexColor(1, 1, 1);
		end
	end

	-- Update Item Info
	frame.ItemInfo.MissingItemText:Hide();
	frame.ItemInfo.ItemName:SetText(item.link or item.name or "Unknown Item");
	frame.ItemInfo.ItemName:Show();
	
	if frame.ItemInfo.ItemLevelSummary then
		frame.ItemInfo.ItemLevelSummary:SetText(string.format("Item Level: %d", currentLevel));
		frame.ItemInfo.ItemLevelSummary:Show();
	end
	
	if frame.ItemInfo.UpgradeProgress then
		frame.ItemInfo.UpgradeProgress:SetText(string.format("Upgrade Level: %d / %d", currentUpgrade, maxUpgrade));
		frame.ItemInfo.UpgradeProgress:Show();
	end
	
	DarkChaos_ItemUpgrade_UpdateProgressBar(currentUpgrade, maxUpgrade, item.tier);

	-- Update Dropdown
	if frame.DropdownContainer then
		frame.DropdownContainer:Show();
		if dropdown then
			dropdown:Show(); -- Explicitly show the dropdown frame
			UIDropDownMenu_SetWidth(dropdown, 120);
			UIDropDownMenu_Initialize(dropdown, DarkChaos_ItemUpgrade_Dropdown_Initialize);
			UIDropDownMenu_SetSelectedValue(dropdown, DC.targetUpgradeLevel);
			UIDropDownMenu_SetText(dropdown, "Level " .. DC.targetUpgradeLevel .. " / " .. maxUpgrade);
		end
	end

	-- Update Panels
	local comparison = DarkChaos_ItemUpgrade_BuildStatComparison(item, DC.targetUpgradeLevel);
	
	-- Check if this is the heirloom shirt for special package stat display
	local isHeirloomShirt = false;
	if DC.uiMode == "HEIRLOOM" and item.link then
		local itemID = tonumber(item.link:match("item:(%d+)"));
		isHeirloomShirt = (itemID == 300365);
	end
	
	-- Create or update package indicator for heirloom mode
	if not frame.PackageIndicator then
		local indicator = frame:CreateFontString("DarkChaos_PackageIndicator", "ARTWORK", "GameFontNormal");
		indicator:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -50, -15);
		indicator:SetJustifyH("RIGHT");
		frame.PackageIndicator = indicator;
	end
	
	if isHeirloomShirt and DC.selectedStatPackage and DC.STAT_PACKAGES[DC.selectedStatPackage] then
		local pkg = DC.STAT_PACKAGES[DC.selectedStatPackage];
		local colorHex = string.format("%.2x%.2x%.2x", pkg.color.r*255, pkg.color.g*255, pkg.color.b*255);
		frame.PackageIndicator:SetText(string.format("|cff888888Package:|r |cff%s%s|r", colorHex, pkg.name));
		frame.PackageIndicator:Show();
	else
		frame.PackageIndicator:Hide();
	end

	if frame.CurrentPanel then
		frame.CurrentPanel:Show();
		if frame.CurrentPanel.StatsText then
			local text = "";
			if comparison then
				for _, stat in ipairs(comparison) do
					local line = FormatStatLine(stat.label, stat.current);
					if line then
						text = text .. line .. "|n";
					end
				end
			else
				text = "|cff808080No stats available|r";
			end
			
			-- Add current package stats for heirloom shirt
			if isHeirloomShirt and DC.selectedStatPackage and currentUpgrade > 0 then
				text = text .. "|n|cff00ccff-- Package Stats --|r|n";
				local pkgStats = DarkChaos_ItemUpgrade_GetPackageStatsAtLevel(DC.selectedStatPackage, currentUpgrade);
				if pkgStats then
					for _, pstat in ipairs(pkgStats) do
						text = text .. string.format("|cffffffff%s: %d|r|n", pstat.name, pstat.value);
					end
				end
			end
			
			frame.CurrentPanel.StatsText:SetText(text);
		end
	end
	
	if frame.UpgradePanel then
		frame.UpgradePanel:Show();
		if frame.UpgradePanel.StatsText then
			local text = "";
			if comparison then
				for _, stat in ipairs(comparison) do
					local line = FormatStatLine(stat.label, stat.preview, stat.diff);
					if line then
						text = text .. line .. "|n";
					end
				end
			else
				text = "|cff808080No preview available|r";
			end
			
			-- Add preview package stats for heirloom shirt
			if isHeirloomShirt and DC.selectedStatPackage then
				local targetLevel = DC.targetUpgradeLevel or (currentUpgrade + 1);
				text = text .. "|n|cff00ccff-- Package Stats --|r|n";
				local pkgStats = DarkChaos_ItemUpgrade_GetPackageStatsAtLevel(DC.selectedStatPackage, targetLevel);
				local currentPkgStats = (currentUpgrade > 0) and DarkChaos_ItemUpgrade_GetPackageStatsAtLevel(DC.selectedStatPackage, currentUpgrade) or nil;
				
				if pkgStats then
					for i, pstat in ipairs(pkgStats) do
						local currentVal = (currentPkgStats and currentPkgStats[i]) and currentPkgStats[i].value or 0;
						local diff = pstat.value - currentVal;
						local diffStr = "";
						if diff > 0 then
							diffStr = string.format(" |cff00ff00(+%d)|r", diff);
						elseif diff < 0 then
							diffStr = string.format(" |cffff0000(%d)|r", diff);
						end
						text = text .. string.format("|cff00ff00%s: %d%s|r|n", pstat.name, pstat.value, diffStr);
					end
				end
			elseif isHeirloomShirt and not DC.selectedStatPackage then
				text = text .. "|n|cffff8800Select a stat package above|r|n";
			end
			
			frame.UpgradePanel.StatsText:SetText(text);
		end
	end
	
	-- Hide redundant UpgradeProgress text if bar is shown
	if frame.ItemInfo.UpgradeProgress then
		frame.ItemInfo.UpgradeProgress:Hide();
	end
	
	-- Update Upgrade Button
	local canUpgrade = currentUpgrade < maxUpgrade;
	local cost = DarkChaos_ItemUpgrade_GetCost(item.tier, DC.targetUpgradeLevel);
	local canAfford = true;
	if cost and (cost.tokens or 0) > (DC.playerTokens or 0) then
		canAfford = false;
	end
	
	-- Check if stat package is required (heirloom shirt item 300365)
	local needsPackage = false;
	local hasPackage = true;
	if DC.uiMode == "HEIRLOOM" and item.link then
		local itemID = tonumber(item.link:match("item:(%d+)"));
		if itemID == 300365 then
			needsPackage = true;
			hasPackage = (DC.selectedStatPackage ~= nil and DC.selectedStatPackage > 0);
		end
	end
	
	if canUpgrade and canAfford and (not needsPackage or hasPackage) then
		SetButtonEnabled(frame.UpgradeButton, true);
		frame.UpgradeButton.disabledTooltip = nil;
	else
		SetButtonEnabled(frame.UpgradeButton, false);
		if not canUpgrade then
			frame.UpgradeButton.disabledTooltip = "Item is fully upgraded.";
		elseif needsPackage and not hasPackage then
			frame.UpgradeButton.disabledTooltip = "Select a stat package first.";
		else
			frame.UpgradeButton.disabledTooltip = "Not enough currency.";
		end
	end
	
	-- Update stat package selector for heirloom mode
	DarkChaos_ItemUpgrade_UpdateStatPackageSelector();
	
	DarkChaos_ItemUpgrade_UpdateCost();
end

function DarkChaos_ItemUpgrade_OnChatMessage(message, sender)
	if not message then return end
	
	local function MaybeLogStandardUpgradeFromQuery(locationKey, data)
		if not locationKey or type(data) ~= "table" then
			return;
		end
		-- If DCAddonProtocol is active, Core.lua already logs via UPG 0x11
		if DCProtocol and DC.useDCProtocol then
			return;
		end

		-- Ignore heirloom shirt (handled by DCHEIRLOOM_SUCCESS)
		if tonumber(data.baseEntry) == 300365 then
			return;
		end

		local pending = DC.pendingUpgrade;
		if not pending or pending.isHeirloom then
			return;
		end

		local pendingKey = tostring(pending.bag) .. ":" .. tostring(pending.serverSlot);
		if pendingKey ~= locationKey then
			return;
		end

		local newLevel = tonumber(data.currentUpgrade);
		if not newLevel then
			return;
		end

		local target = tonumber(pending.target);
		if target and newLevel < target then
			return;
		end

		local baseEntry = tonumber(data.baseEntry) or tonumber(data.currentEntry);
		local itemName, itemLink = nil, nil;
		if baseEntry then
			itemName, itemLink = GetItemInfo(baseEntry);
		end

		if DC.AddUpgradeHistoryEntry then
			DC.AddUpgradeHistoryEntry({
				source = "chat_query",
				mode = "STANDARD",
				itemId = baseEntry,
				itemName = itemName,
				itemLink = itemLink,
				guid = data.guid,
				fromLevel = pending.startLevel,
				toLevel = newLevel,
				tier = tonumber(data.tier) or pending.tier,
				maxUpgrade = data.maxUpgrade,
			});
		end

		DC.pendingUpgrade = nil;
	end
	
	-- Debug: Log all incoming messages that might be ours
	if string.find(message, "^DCUPGRADE_") or string.find(message, "^DCHEIRLOOM_") then
		DC.Debug("OnChatMessage received: " .. string.sub(message, 1, 80) .. "...");
	end
	
	-- Handle initialization message
	-- Format (new): DCUPGRADE_INIT:tokens:essence:tokenItemId:essenceItemId
	-- Format (old): DCUPGRADE_INIT:tokens:essence
	if string.find(message, "^DCUPGRADE_INIT") then
		-- Try 4-value format first (new server)
		local _, _, tokens, essence, tokenID, essenceID = string.find(message, "^DCUPGRADE_INIT:(%d+):(%d+):(%d+):(%d+)");
		
		-- Fall back to 2-value format (old server)
		if not tokens then
			_, _, tokens, essence = string.find(message, "^DCUPGRADE_INIT:(%d+):(%d+)");
		end
		
		if tokens then
			DC.playerTokens = tonumber(tokens);
			DC.Debug("Received playerTokens: " .. tostring(DC.playerTokens));
		end
		if essence then
			DC.playerEssence = tonumber(essence);
			DC.Debug("Received playerEssence: " .. tostring(DC.playerEssence));
		end
		
		-- Use server-provided IDs if available, otherwise use hardcoded defaults
		if tokenID then
			DC.TOKEN_ITEM_ID = tonumber(tokenID);
		else
			-- Fallback to configured item IDs
			DC.TOKEN_ITEM_ID = DC.TOKEN_ITEM_ID or 300311;
		end
		DC.Debug("TOKEN_ITEM_ID: " .. tostring(DC.TOKEN_ITEM_ID));
		
		if essenceID then
			DC.ESSENCE_ITEM_ID = tonumber(essenceID);
		else
			-- Fallback to configured item IDs
			DC.ESSENCE_ITEM_ID = DC.ESSENCE_ITEM_ID or 300312;
		end
		DC.Debug("ESSENCE_ITEM_ID: " .. tostring(DC.ESSENCE_ITEM_ID));
		
		DarkChaos_ItemUpgrade_UpdatePlayerCurrencies();
		DarkChaos_ItemUpgrade_UpdateUI();
		return;
	end
	
	-- Handle query response
	-- Format: DCUPGRADE_QUERY:guid:upgradeLevel:tier:baseItemLevel:upgradedItemLevel:statMultiplier:baseEntry:currentEntry:cloneMap
	-- Example: DCUPGRADE_QUERY:190251:7:2:312:312:1.166:48228:2541151:0-48228,1-2541145,...,15-2541159
	if string.find(message, "^DCUPGRADE_QUERY") then
		local pattern = "^DCUPGRADE_QUERY:(%d+):(%d+):(%d+):(%d+):(%d+):([%d%.]+):(%d+):(%d+):(.*)$";
		local _, _, guid, serverUpgradeLevel, tier, baseLevel, upgradedLevel, statMult, baseEntry, currentEntry, cloneMapStr = string.find(message, pattern);
		
		if guid then
			guid = tonumber(guid);
			serverUpgradeLevel = tonumber(serverUpgradeLevel);  -- This is the upgrade level from server DB
			tier = tonumber(tier);
			baseLevel = tonumber(baseLevel);
			upgradedLevel = tonumber(upgradedLevel);
			statMult = tonumber(statMult);
			baseEntry = tonumber(baseEntry);
			currentEntry = tonumber(currentEntry);
			
			-- Parse the clone map and determine current upgrade level and max upgrade level
			local cloneEntries = {};
			local currentUpgrade = 0;
			local maxUpgrade = 0;
			local HEIRLOOM_SHIRT_ENTRY = 300365;
			local isHeirloom = (baseEntry == HEIRLOOM_SHIRT_ENTRY);
			
			if cloneMapStr and cloneMapStr ~= "" then
				for pair in string.gmatch(cloneMapStr, "[^,]+") do
					local levelStr, entryStr = string.match(pair, "(%d+)%-(%d+)");
					if levelStr and entryStr then
						local level = tonumber(levelStr);
						local entry = tonumber(entryStr);
						cloneEntries[level] = entry;
						if level > maxUpgrade then
							maxUpgrade = level;
						end
						-- For heirlooms, all entries are the same, so use serverUpgradeLevel instead
						-- For normal items, current upgrade is the level where the entry matches currentEntry
						if not isHeirloom and entry == currentEntry then
							currentUpgrade = level;
						end
					end
				end
			end
			
			-- For heirlooms, always use the serverUpgradeLevel since clone entries are all the same
			if isHeirloom then
				currentUpgrade = serverUpgradeLevel or 0;
				DC.Debug("Heirloom: Using serverUpgradeLevel as currentUpgrade: " .. tostring(currentUpgrade));
			end
			
			DC.Debug(string.format("ParseQueryResponse: guid=%d, tier=%d, currentUpgrade=%d, maxUpgrade=%d, baseEntry=%d, currentEntry=%d, serverUpgradeLevel=%d",
				guid, tier, currentUpgrade, maxUpgrade, baseEntry, currentEntry, serverUpgradeLevel or 0));
			
			-- Use server's upgrade level if clone map didn't give us one (fallback)
			if currentUpgrade == 0 and serverUpgradeLevel and serverUpgradeLevel > 0 then
				currentUpgrade = serverUpgradeLevel;
				DC.Debug("Using serverUpgradeLevel as currentUpgrade: " .. tostring(currentUpgrade));
			end
			
			-- Build the cached data object
			local data = {
				guid = guid,
				tier = tier,
				baseItemLevel = baseLevel,
				upgradedItemLevel = upgradedLevel,
				statMultiplier = statMult,
				baseEntry = baseEntry,
				currentEntry = currentEntry,
				currentUpgrade = currentUpgrade,
				maxUpgrade = maxUpgrade,
				cloneEntries = cloneEntries,
				timestamp = GetTime and GetTime() or 0,
			};
			
			-- For heirlooms, include the selected package ID (will be updated by DCHEIRLOOM_QUERY later)
			if isHeirloom then
				data.heirloomPackageId = DC.selectedStatPackage or 0;
			end
			
			-- Store in cache
			DC.itemUpgradeCache[guid] = data;
			
			-- Try to match this response to the correct location
			-- First, check if we have an in-flight query AND it matches this item
			local matchedInFlight = false;
			
			DC.Debug(string.format("Processing DCUPGRADE_QUERY: guid=%d, baseEntry=%d, currentEntry=%d", 
				guid, baseEntry, currentEntry));
			
			if DC.queryInFlight then
				local locationKey = DC.queryInFlight.key;
				-- Get the item at this location and check if it matches the response
				local bagStr, slotStr = string.match(locationKey, "(%d+):(%d+)");
				local queryBag = tonumber(bagStr);
				local querySlot = tonumber(slotStr);
				local queryLink = nil;
				
				DC.Debug("In-flight query for location: " .. locationKey .. " (bag=" .. tostring(queryBag) .. ", slot=" .. tostring(querySlot) .. ")");
				
				if queryBag == 255 then
					-- Equipped item (slot is 0-indexed, need to add 1 for API)
					queryLink = GetInventoryItemLink("player", querySlot + 1);
				else
					-- Bag item (slot is 0-indexed, need to add 1 for API)
					queryLink = GetContainerItemLink(queryBag, querySlot + 1);
				end
				
				if queryLink then
					local queryItemId = tonumber(string.match(queryLink, "item:(%d+)"));
					DC.Debug("Query location has item: " .. tostring(queryItemId) .. ", response has: " .. tostring(currentEntry) .. "/" .. tostring(baseEntry));
					
					-- Check if the queried item matches the response (by entry ID)
					if queryItemId == currentEntry or queryItemId == baseEntry then
						-- This response IS for our in-flight query
						DC.itemLocationCache[locationKey] = guid;
						DC.Debug("In-flight query matched: " .. locationKey .. " -> guid " .. tostring(guid));
						MaybeLogStandardUpgradeFromQuery(locationKey, data);
						matchedInFlight = true;
						
						-- Apply to current item if it matches
						if DC.currentItem and DC.currentItem.locationKey == locationKey then
							DarkChaos_ItemUpgrade_ApplyQueryData(DC.currentItem, data);
							local current = DC.currentItem.currentUpgrade or 0;
							local itemMaxUpgrade = DC.currentItem.maxUpgrade or DC.GetMaxUpgradeLevelForTier(DC.currentItem.tier);
							DC.Debug(string.format("After ApplyQueryData: tier=%d, currentUpgrade=%d, maxUpgrade=%d", 
								DC.currentItem.tier or 0, current, itemMaxUpgrade));
							if itemMaxUpgrade > 0 and current < itemMaxUpgrade then
								DC.targetUpgradeLevel = current + 1;
							else
								DC.targetUpgradeLevel = math.max(current, 1);
							end
							DC.Debug("Set targetUpgradeLevel to: " .. tostring(DC.targetUpgradeLevel));
							DarkChaos_ItemUpgrade_UpdateUI();
						end
						
						-- Notify any waiting contexts and start next query
						local finished = DarkChaos_ItemUpgrade_CompleteQuery();
						if finished and finished.contexts then
							for _, ctx in ipairs(finished.contexts) do
								if ctx.callback then
									ctx.callback(data);
								end
							end
						end
					else
						DC.Debug("In-flight query does NOT match response: queryItemId=" .. tostring(queryItemId) .. 
							", responseEntry=" .. tostring(currentEntry) .. "/" .. tostring(baseEntry));
					end
				end
			end
			
			-- If we didn't match an in-flight query, try to match by scanning items
			if not matchedInFlight then
				DC.Debug("No in-flight match, scanning items for entry: " .. tostring(currentEntry) .. " or base: " .. tostring(baseEntry));
				local matched = false;
				
				-- Scan equipped items to find which slot has this entry
				for slotID = 1, 19 do
					local link = GetInventoryItemLink("player", slotID);
					if link then
						local itemId = tonumber(string.match(link, "item:(%d+)"));
						DC.Debug("  Slot " .. slotID .. " has itemId: " .. tostring(itemId));
						if itemId == currentEntry or itemId == baseEntry then
							-- Found matching slot!
							local serverBag = 255;
							local serverSlot = slotID - 1;
							local locationKey = serverBag .. ":" .. serverSlot;
							DC.itemLocationCache[locationKey] = guid;
							DC.Debug("Matched entry " .. tostring(currentEntry) .. " to slot " .. slotID .. " (key: " .. locationKey .. ")");
							MaybeLogStandardUpgradeFromQuery(locationKey, data);
							matched = true;
							break;
						end
					end
				end
				
				-- Also scan bags
				if not matched then
					for bag = 0, 4 do
						local numSlots = GetContainerNumSlots(bag);
						for slot = 1, numSlots do
							local link = GetContainerItemLink(bag, slot);
							if link then
								local itemId = tonumber(string.match(link, "item:(%d+)"));
								if itemId == currentEntry or itemId == baseEntry then
									local serverSlot = slot - 1;
									local locationKey = bag .. ":" .. serverSlot;
									DC.itemLocationCache[locationKey] = guid;
									DC.Debug("Matched entry " .. tostring(currentEntry) .. " to bag " .. bag .. " slot " .. slot .. " (key: " .. locationKey .. ")");
									MaybeLogStandardUpgradeFromQuery(locationKey, data);
									matched = true;
									break;
								end
							end
						end
						if matched then break; end
					end
				end
				
				if not matched then
					DC.Debug("Could not match entry to any location");
				end
				
				-- If we have an in-flight query that didn't match, DON'T consume it
				-- The query is still waiting for its response
			end
		end
		return;
	end

	-- ═══════════════════════════════════════════════════════════════════════════════
	-- HEIRLOOM STAT PACKAGE HANDLERS
	-- ═══════════════════════════════════════════════════════════════════════════════

	-- Handle heirloom upgrade success
	-- Format: DCHEIRLOOM_SUCCESS:itemGUID:level:packageId:enchantId
	if string.find(message, "^DCHEIRLOOM_SUCCESS") then
		local _, _, guidStr, levelStr, packageIdStr, enchantIdStr = string.find(message, "^DCHEIRLOOM_SUCCESS:(%d+):(%d+):(%d+):(%d+)");
		
		if guidStr then
			local itemGUID = tonumber(guidStr);
			local newLevel = tonumber(levelStr);
			local packageId = tonumber(packageIdStr);
			local enchantId = tonumber(enchantIdStr);
			
			DC.Debug(string.format("DCHEIRLOOM_SUCCESS: guid=%d, level=%d, package=%d, enchant=%d",
				itemGUID, newLevel, packageId, enchantId));
			
			-- Get package info for display
			local pkg = DC.STAT_PACKAGES[packageId];
			local packageName = pkg and pkg.name or "Unknown";
			local packageStats = pkg and table.concat(pkg.stats, ", ") or "";
			
			-- Update player currencies (refresh from server)
			SendChatMessage(".dcupgrade init", "SAY");
			
			-- Clear pending upgrade
			local pending = DC.pendingUpgrade;
			DC.pendingUpgrade = nil;

			-- Record history
			local heirloomItemId = 300365;
			local fromLevel = pending and pending.startLevel or nil;
			local itemName, itemLink = GetItemInfo(heirloomItemId)
			if DC.AddUpgradeHistoryEntry then
				DC.AddUpgradeHistoryEntry({
					source = "heirloom_chat",
					mode = "HEIRLOOM",
					itemId = heirloomItemId,
					itemName = itemName,
					itemLink = itemLink,
					itemGUID = itemGUID,
					fromLevel = fromLevel,
					toLevel = newLevel,
					tier = 3,
					packageId = packageId,
					enchantId = enchantId,
				});
			end
			
			-- Show success message
			print(string.format("|cff00ff00[Heirloom Upgrade Success!]|r Level %d with |cff00ccff%s|r package", newLevel, packageName));
			if packageStats ~= "" then
				print(string.format("|cff888888Stats: %s|r", packageStats));
			end
			
			-- Play success sound
			if DC.Settings and DC.Settings.enableSounds then
				PlaySound(888); -- SOUNDKIT.LEVEL_UP
			end
			
			-- Trigger celebration animation
			if DC.Settings and DC.Settings.enableCelebration then
				DC.upgradeAnimationTime = 2.0;
			end
			
			-- Update UI
			if DC.currentItem then
				DC.currentItem.currentUpgrade = newLevel;
				DC.currentItem.heirloomPackageId = packageId;
				DC.currentItem.heirloomPackageLevel = newLevel;
				DC.targetUpgradeLevel = math.min(newLevel + 1, DC.currentItem.maxUpgrade or 15);
			end
			
			-- Re-enable upgrade button
			local mainFrame = DarkChaos_ItemUpgradeFrame;
			if mainFrame and mainFrame.UpgradeButton then
				SetButtonEnabled(mainFrame.UpgradeButton, true);
			end
			
			-- Refresh display
			InvalidateCachedItemData();
			DarkChaos_ItemUpgrade_UpdateUI();
		end
		return;
	end

	-- Handle heirloom error
	-- Format: DCHEIRLOOM_ERROR:<message>
	if string.find(message, "^DCHEIRLOOM_ERROR") then
		local _, _, errorMsg = string.find(message, "^DCHEIRLOOM_ERROR:(.+)$");
		
		errorMsg = errorMsg or "Unknown error";
		DC.Debug("DCHEIRLOOM_ERROR: " .. errorMsg);
		
		-- Show error message
		print(string.format("|cffff0000[Heirloom Upgrade Error]|r %s", errorMsg));
		
		-- Play error sound
		if DC.Settings and DC.Settings.enableSounds then
			PlaySound(847); -- SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST
		end
		
		-- Clear pending upgrade
		DC.pendingUpgrade = nil;
		
		-- Re-enable upgrade button
		local mainFrame = DarkChaos_ItemUpgradeFrame;
		if mainFrame and mainFrame.UpgradeButton then
			SetButtonEnabled(mainFrame.UpgradeButton, true);
		end
		
		return;
	end

	-- Handle heirloom query response
	-- Format: DCHEIRLOOM_QUERY:itemGUID:level:packageId:maxLevel:maxPackages
	if string.find(message, "^DCHEIRLOOM_QUERY") then
		local _, _, guidStr, levelStr, packageIdStr, maxLevelStr, maxPkgStr = string.find(message, "^DCHEIRLOOM_QUERY:(%d+):(%d+):(%d+):(%d+):(%d+)");
		
		if guidStr then
			local itemGUID = tonumber(guidStr);
			local currentLevel = tonumber(levelStr);
			local packageId = tonumber(packageIdStr);
			local maxLevel = tonumber(maxLevelStr);
			local maxPackages = tonumber(maxPkgStr);
			
			DC.Debug(string.format("DCHEIRLOOM_QUERY: guid=%d, level=%d, package=%d, maxLevel=%d, maxPkg=%d",
				itemGUID, currentLevel, packageId, maxLevel, maxPackages));
			
			-- Update cache with heirloom package data
			if DC.itemUpgradeCache[itemGUID] then
				DC.itemUpgradeCache[itemGUID].heirloomPackageId = packageId;
				DC.itemUpgradeCache[itemGUID].currentUpgrade = currentLevel;
				DC.itemUpgradeCache[itemGUID].maxUpgrade = maxLevel;
			end
			
			-- Update current item with heirloom data
			if DC.currentItem then
				DC.currentItem.guid = itemGUID;
				DC.currentItem.heirloomPackageId = packageId;
				DC.currentItem.heirloomPackageLevel = currentLevel;
				DC.currentItem.currentUpgrade = currentLevel;
				DC.currentItem.maxUpgrade = maxLevel;
				
				-- Update selected package in UI
				if packageId > 0 then
					DC.selectedStatPackage = packageId;
					-- Save to character settings
					if DarkChaos_ItemUpgrade_SaveCharSettings then
						DarkChaos_ItemUpgrade_SaveCharSettings();
					end
				end
				
				-- Set target level
				if currentLevel < maxLevel then
					DC.targetUpgradeLevel = currentLevel + 1;
				else
					DC.targetUpgradeLevel = maxLevel;
				end
				
				-- Refresh UI
				DarkChaos_ItemUpgrade_UpdateUI();
			end
		end
		return;
	end

	-- Handle heirloom packages list response
	-- Format: DCHEIRLOOM_PACKAGES:count:id1|name1|stats1:id2|name2|stats2:...
	if string.find(message, "^DCHEIRLOOM_PACKAGES") then
		DC.Debug("Received DCHEIRLOOM_PACKAGES from server (using local definitions)");
		-- We use local DC.STAT_PACKAGES definitions, but log that server confirmed availability
		return;
	end
end

--[[=====================================================
	STAT PACKAGE SELECTOR UI
	For Heirloom mode (item 300365) - allows selecting secondary stat packages
	NOTE: CreateStatPackageSelector is defined in Heirloom.lua
=======================================================]]

-- Show package info in the info frame
function DarkChaos_ItemUpgrade_ShowPackageInfo(packageId)
	local selector = DC.StatPackageSelector;
	if not selector then return end
	
	if not packageId or not DC.STAT_PACKAGES[packageId] then
		selector.InfoIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");
		selector.InfoName:SetText("Select a Package");
		selector.InfoDesc:SetText("Click on a package to select it. Stats will be applied when you upgrade.");
		selector.InfoStats:SetText("");
		return;
	end
	
	local pkg = DC.STAT_PACKAGES[packageId];
	selector.InfoIcon:SetTexture(pkg.icon);
	selector.InfoName:SetText(string.format("|cff%.2x%.2x%.2x%s|r", pkg.color.r*255, pkg.color.g*255, pkg.color.b*255, pkg.name));
	selector.InfoDesc:SetText(pkg.description);
	
	-- Build stats string
	local statsStr = "|cff00ff00Stats:|r " .. table.concat(pkg.stats, ", ");
	selector.InfoStats:SetText(statsStr);
end

-- Select a stat package
function DarkChaos_ItemUpgrade_SelectStatPackage(packageId)
	if not packageId or not DC.STAT_PACKAGES[packageId] then
		return;
	end
	
	local oldPackage = DC.selectedStatPackage;
	DC.selectedStatPackage = packageId;
	
	-- Update button highlights
	local selector = DC.StatPackageSelector;
	if selector and selector.buttons then
		for i, btn in ipairs(selector.buttons) do
			if i == packageId then
				btn.SelectedHighlight:Show();
				btn.Background:SetVertexColor(0.1, 0.2, 0.3, 1.0);
			else
				btn.SelectedHighlight:Hide();
				btn.Background:SetVertexColor(0.15, 0.15, 0.2, 0.9);
			end
		end
	end
	
	-- Update info display
	DarkChaos_ItemUpgrade_ShowPackageInfo(packageId);
	
	-- Notify user
	local pkg = DC.STAT_PACKAGES[packageId];
	DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ccff[DC-ItemUpgrade]|r Selected |cff%.2x%.2x%.2x%s|r package.", 
		pkg.color.r*255, pkg.color.g*255, pkg.color.b*255, pkg.name));
	
	-- Save the selection to per-character settings
	DarkChaos_ItemUpgrade_SaveCharSettings();
	
	-- Send package selection to server via addon message
	DarkChaos_ItemUpgrade_SendPackageSelection(packageId);
	
	-- Play sound
	DC.PlaySound("igMainMenuOptionCheckBoxOn");
end

-- Send package selection to server
function DarkChaos_ItemUpgrade_SendPackageSelection(packageId)
	if not packageId then return end
	
	-- Send addon message to server with package selection
	-- Format: DCUPGRADE:PACKAGE:<packageId>
	local message = string.format("DCUPGRADE:PACKAGE:%d", packageId);
	
	-- Try sending via addon message channel
	if ChatThrottleLib then
		ChatThrottleLib:SendAddonMessage("NORMAL", "DCUPGRADE", message, "WHISPER", UnitName("player"));
	else
		SendAddonMessage("DCUPGRADE", message, "WHISPER", UnitName("player"));
	end
	
	DC.Debug("Sent package selection to server: " .. message);
end

-- NOTE: UpdateStatPackageSelector and DarkChaos_ItemUpgrade_GetPackageStatsAtLevel 
-- are now defined in Heirloom.lua which loads first.

--[[=====================================================
	EARLY TOOLTIP INITIALIZATION & BACKGROUND QUERY PROCESSOR
	Hooks tooltips immediately on addon load so Item IDs
	are visible even before opening the upgrade window.
	Also scans equipped items when CharacterFrame opens.
=======================================================]]

-- Create a background frame for processing queries even when upgrade frame isn't open
local DC_BackgroundQueryFrame = CreateFrame("Frame");
DC_BackgroundQueryFrame.elapsed = 0;
DC_BackgroundQueryFrame:SetScript("OnUpdate", function(self, elapsed)
	self.elapsed = self.elapsed + elapsed;
	
	-- Process batch queries periodically (every 0.1 seconds)
	if self.elapsed >= 0.1 then
		self.elapsed = 0;
		
		-- Process batch query timer
		if DC.batchQueryTimer and DC.batchQueryTimer > 0 then
			DC.batchQueryTimer = DC.batchQueryTimer - 0.1;
			if DC.batchQueryTimer <= 0 then
				DC.batchQueryTimer = 0;
				if DC.ProcessBatchQueries then
					DC.ProcessBatchQueries();
				end
			end
		end
	end
end);

-- Scan all equipped items and query their upgrade status
-- This function directly sends commands to avoid dependency on local functions
local function DC_ScanEquippedItems()
	DC.Debug("DC_ScanEquippedItems: Starting scan...");
	
	-- We don't actually need to query - the server sends DCUPGRADE_QUERY responses automatically
	-- Just make sure our caches are initialized
	DC.itemLocationCache = DC.itemLocationCache or {};
	DC.itemUpgradeCache = DC.itemUpgradeCache or {};
	
	-- Count how many items we have cached upgrade data for
	local cachedCount = 0;
	local equippedCount = 0;
	
	for slotID = 1, 19 do
		local link = GetInventoryItemLink("player", slotID);
		if link then
			equippedCount = equippedCount + 1;
			local serverBag = 255;
			local serverSlot = slotID - 1;
			local locationKey = serverBag .. ":" .. serverSlot;
			if DC.itemLocationCache[locationKey] then
				cachedCount = cachedCount + 1;
			end
		end
	end
	
	DC.Debug("DC_ScanEquippedItems: " .. cachedCount .. "/" .. equippedCount .. " equipped items have cached upgrade data");
end

-- Make it accessible
DC.ScanEquippedItems = DC_ScanEquippedItems;

-- Create a hidden frame for early initialization AND persistent chat message handling
local DC_EarlyInitFrame = CreateFrame("Frame");
DC_EarlyInitFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
DC_EarlyInitFrame:RegisterEvent("CHAT_MSG_SYSTEM");
DC_EarlyInitFrame:RegisterEvent("CHAT_MSG_SAY");
DC_EarlyInitFrame:RegisterEvent("CHAT_MSG_WHISPER");
DC_EarlyInitFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD");
		-- Hook tooltips immediately so Item IDs work right away
		if DarkChaos_ItemUpgrade_HookTooltips and not DC.tooltipsHooked then
			DarkChaos_ItemUpgrade_HookTooltips();
			DC.Debug("Early tooltip hooks installed on PLAYER_ENTERING_WORLD");
		end
		
		-- Hook CharacterFrame to scan items when opened
		if CharacterFrame then
			CharacterFrame:HookScript("OnShow", function()
				DC.Debug("CharacterFrame OnShow triggered - scanning items");
				-- Scan equipped items to pre-cache upgrade data
				DC_ScanEquippedItems();
			end);
			DC.Debug("CharacterFrame OnShow hook installed");
		end
		
		-- Also scan on first login after a short delay (to let server connection establish)
		local scanFrame = CreateFrame("Frame");
		scanFrame.elapsed = 0;
		scanFrame:SetScript("OnUpdate", function(self, elapsed)
			self.elapsed = self.elapsed + elapsed;
			if self.elapsed >= 2 then
				self:SetScript("OnUpdate", nil);
				DC.Debug("Initial login scan triggered");
				DC_ScanEquippedItems();
			end
		end);
		return;
	end
	
	-- Handle chat messages persistently (even when upgrade frame is closed)
	if event == "CHAT_MSG_SYSTEM" then
		local message = ...;
		if type(message) == "string" then
			if string.find(message, "DCUPGRADE_") or string.find(message, "DCHEIRLOOM_") then
				DC.Debug("EarlyInit CHAT_MSG_SYSTEM: " .. string.sub(message, 1, 60));
				if string.find(message, "^DCUPGRADE_") or string.find(message, "^DCHEIRLOOM_") then
					DarkChaos_ItemUpgrade_OnChatMessage(message, UnitName("player"));
				end
			end
		end
		return;
	end
	
	if event == "CHAT_MSG_SAY" or event == "CHAT_MSG_WHISPER" then
		local message, sender = ...;
		if type(message) == "string" and (string.find(message, "DCUPGRADE_") or string.find(message, "DCHEIRLOOM_")) then
			DC.Debug("EarlyInit " .. event .. ": " .. string.sub(message, 1, 60));
			DarkChaos_ItemUpgrade_OnChatMessage(message, sender);
		end
		return;
	end
end);

-- =============================================================================
-- Chat Filter to hide DC protocol messages from chat
-- =============================================================================
-- In 3.3.5a, we use ChatFrame_AddMessageEventFilter to intercept and hide messages
local function DC_ChatFilter(self, event, message, ...)
	if message then
		-- Hide DC protocol messages from appearing in chat
		if string.find(message, "^DCUPGRADE_") or 
		   string.find(message, "^DCHEIRLOOM_") or
		   string.find(message, "^DC_ITEMCHECK") then
			-- Return true to block the message, and pass along all arguments
			return true
		end
	end
	return false, message, ...
end

-- Register the filter for system messages (where server sends protocol messages)
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", DC_ChatFilter)