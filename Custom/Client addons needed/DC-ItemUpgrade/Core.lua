--[[
	DC-ItemUpgrade - Core Module
	Shared namespace, utilities, settings, and slash commands
	
	Based on: Blizzard_ItemUpgradeUI (11.2.7.64169)
	Adapted for: AzerothCore 3.3.5a with Eluna server communication
	Updated: Now supports DCAddonProtocol for lightweight messaging
--]]

-- Global namespace
DarkChaos_ItemUpgrade = DarkChaos_ItemUpgrade or {};
local DC = DarkChaos_ItemUpgrade;

-- DCAddonProtocol integration (stored in namespace to avoid conflict with DC variable)
local DCProtocol = rawget(_G, "DCAddonProtocol");
DC.useDCProtocol = (DCProtocol ~= nil);

-- AIO detection
local hasAIO = (rawget(_G, "AIO") ~= nil);
DC.hasAIO = hasAIO;

-- Protocol mode: "dc", "aio", or "chat"
DC.protocolMode = DC.useDCProtocol and "dc" or (hasAIO and "aio" or "chat");

-- JSON mode toggle (for DC protocol)
DC.useDCProtocolJSON = true;

-- Protocol debug/verbose flag
DC.verboseProtocol = false;
DC.liveCostCache = DC.liveCostCache or {};
DC.pendingCostRequests = DC.pendingCostRequests or {};

--[[=====================================================
	QUALITY COLOR FIX & ITEM ID TOOLTIPS
	Fixes "attempt to index local 'color' (a nil value)" for quality 7+ items
=======================================================]]

-- Add missing ITEM_QUALITY_COLORS entries for quality 7+ (Heirloom, Artifact, etc.)
if ITEM_QUALITY_COLORS then
	-- Quality 7 = Heirloom (cyan/light blue)
	if not ITEM_QUALITY_COLORS[7] then
		ITEM_QUALITY_COLORS[7] = { r = 0.0, g = 0.8, b = 1.0, hex = "|cff00ccff" };
	end
	-- Quality 8 = Artifact (orange)
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

--[[=====================================================
	CORE VARIABLES
=======================================================]]

-- Setting for showing Item IDs in tooltips (default: true)
DC.showItemIDsInTooltips = true;

-- Item IDs for currency icons
DC.TOKEN_ITEM_ID = nil;
DC.ESSENCE_ITEM_ID = nil;

-- UI Mode: "STANDARD" or "HEIRLOOM"
DC.uiMode = "STANDARD";

-- Player currency
DC.playerTokens = 0;
DC.playerEssence = 0;

-- Current item being upgraded
DC.currentItem = nil;

-- Target upgrade level
DC.targetUpgradeLevel = 1;

-- Pending upgrade info
DC.pendingUpgrade = nil;

-- Animation timers
DC.upgradeAnimationTime = 0;
DC.arrowAnimationTime = 0;
DC.glowAnimationTime = 0;

-- Batch query timer
DC.batchQueryTimer = 0;

--[[=====================================================
	TIER ICONS & COLORS
=======================================================]]

local TIER_COLOR_MODULUS = 4294967296;

local function CopyColor(color)
	if type(color) ~= "table" then
		return nil;
	end

	return {
		r = tonumber(color.r) or 1.0,
		g = tonumber(color.g) or 1.0,
		b = tonumber(color.b) or 1.0,
	};
end

local function CopyTierDefinition(source)
	if type(source) ~= "table" then
		return nil;
	end

	local copy = {};
	for key, value in pairs(source) do
		if type(value) == "table" then
			local nested = {};
			for nestedKey, nestedValue in pairs(value) do
				nested[nestedKey] = nestedValue;
			end
			copy[key] = nested;
		else
			copy[key] = value;
		end
	end

	return copy;
end

local function NormalizeTierText(value)
	if type(value) ~= "string" or value == "" then
		return nil;
	end

	return value;
end

local function NormalizeTierColorARGB(value)
	local color = tonumber(value) or 0;
	if color < 0 then
		color = color + TIER_COLOR_MODULUS;
	end
	if color < 0 then
		color = 0;
	end

	return math.floor(color);
end

local function BuildTierColor(colorARGB, fallbackColor)
	local normalized = NormalizeTierColorARGB(colorARGB);
	if normalized == 0 then
		return CopyColor(fallbackColor) or { r = 1.0, g = 1.0, b = 1.0 };
	end

	local red = math.floor(normalized / 65536) % 256;
	local green = math.floor(normalized / 256) % 256;
	local blue = normalized % 256;

	return {
		r = red / 255,
		g = green / 255,
		b = blue / 255,
	};
end

local function GetTierDataRevision()
	if type(GetDCClientDataRevisions) ~= "function" then
		return 0;
	end

	local ok, revisions = pcall(GetDCClientDataRevisions);
	if not ok or type(revisions) ~= "table" then
		return 0;
	end

	return tonumber(revisions.itemUpgradeTiers or revisions.iut) or 0;
end

local function GetTierItemDataRevision()
	if type(GetDCClientDataRevisions) ~= "function" then
		return 0;
	end

	local ok, revisions = pcall(GetDCClientDataRevisions);
	if not ok or type(revisions) ~= "table" then
		return 0;
	end

	return tonumber(revisions.itemUpgradeTierItems or revisions.iuti) or 0;
end

function DC.GetNativeTierRows()
	if type(GetDCItemUpgradeTiers) ~= "function" then
		return nil;
	end

	local ok, rows = pcall(GetDCItemUpgradeTiers);
	if not ok or type(rows) ~= "table" or #rows == 0 then
		return nil;
	end

	return rows;
end

function DC.GetNativeTierItemRows()
	if type(GetDCItemUpgradeTierItems) ~= "function" then
		return nil;
	end

	local ok, rows = pcall(GetDCItemUpgradeTierItems);
	if not ok or type(rows) ~= "table" or #rows == 0 then
		return nil;
	end

	return rows;
end

function DC.NormalizeTierDefinition(row)
	if type(row) ~= "table" then
		return nil;
	end

	local tierId = tonumber(
		row.tierId or row.TierID or row.tier or row.ID or row.id);
	if not tierId or tierId <= 0 then
		return nil;
	end

	local colorARGB = NormalizeTierColorARGB(
		row.colorARGB or row.ColorARGB or 0);

	return {
		id = tonumber(row.id or row.ID) or tierId,
		tierId = tierId,
		season = tonumber(row.season or row.Season) or 0,
		sortOrder = tonumber(row.sortOrder or row.SortOrder) or (tierId * 10),
		flags = tonumber(row.flags or row.Flags) or 0,
		minItemLevel = tonumber(row.minItemLevel or row.MinItemLevel) or 0,
		maxItemLevel = tonumber(row.maxItemLevel or row.MaxItemLevel) or 0,
		maxUpgradeLevel = tonumber(
			row.maxUpgradeLevel or row.MaxUpgradeLevel),
		statMultiplierMax = tonumber(
			row.statMultiplierMax or row.StatMultiplierMax),
		upgradeCostPerLevel = tonumber(
			row.upgradeCostPerLevel or row.UpgradeCostPerLevel) or 0,
		isArtifact = tonumber(row.isArtifact or row.IsArtifact) or 0,
		enabled = tonumber(row.enabled or row.Enabled) or 0,
		colorARGB = colorARGB,
		name = NormalizeTierText(row.name or row.Name),
		description = NormalizeTierText(row.description or row.Description),
		sourceContent = NormalizeTierText(
			row.sourceContent or row.SourceContent),
		icon = NormalizeTierText(row.icon or row.Icon),
	};
end

function DC.NormalizeTierItemRow(row)
	if type(row) ~= "table" then
		return nil;
	end

	local tierId = tonumber(row.tierId or row.TierID or row.tier);
	local itemId = tonumber(row.itemId or row.ItemID or row.itemID);
	if not tierId or tierId <= 0 or not itemId or itemId <= 0 then
		return nil;
	end

	return {
		id = tonumber(row.id or row.ID) or itemId,
		tierId = tierId,
		itemId = itemId,
		sortOrder = tonumber(row.sortOrder or row.SortOrder) or 0,
		flags = tonumber(row.flags or row.Flags) or 0,
		quality = tonumber(row.quality or row.Quality) or 0,
		inventoryType = tonumber(row.inventoryType or row.InventoryType) or 0,
		itemLevel = tonumber(row.itemLevel or row.ItemLevel) or 0,
	};
end

DC.DEFAULT_TIER_DEFINITIONS = DC.DEFAULT_TIER_DEFINITIONS or {
	[1] = {
		id = 1,
		tierId = 1,
		sortOrder = 10,
		minItemLevel = 1,
		maxItemLevel = 212,
		maxUpgradeLevel = 6,
		statMultiplierMax = 2.0,
		upgradeCostPerLevel = 50,
		enabled = 1,
		name = "Leveling",
		sourceContent = "Vanilla/TBC/WotLK",
		icon = "Interface\\Icons\\INV_Misc_Coin_01",
		color = { r = 0.6, g = 0.6, b = 0.6 },
	},
	[2] = {
		id = 2,
		tierId = 2,
		sortOrder = 20,
		minItemLevel = 213,
		maxItemLevel = 226,
		maxUpgradeLevel = 15,
		statMultiplierMax = 1.5,
		upgradeCostPerLevel = 100,
		enabled = 1,
		name = "Heroic",
		sourceContent = "All Content",
		icon = "Interface\\Icons\\INV_Misc_Coin_02",
		color = { r = 0.2, g = 0.8, b = 0.2 },
	},
	[3] = {
		id = 3,
		tierId = 3,
		sortOrder = 30,
		minItemLevel = 227,
		maxItemLevel = 264,
		maxUpgradeLevel = 15,
		statMultiplierMax = 1.5,
		upgradeCostPerLevel = 150,
		enabled = 1,
		name = "Raid",
		sourceContent = "Raids",
		icon = "Interface\\Icons\\INV_Misc_Coin_03",
		color = { r = 0.2, g = 0.2, b = 1.0 },
	},
	[4] = {
		id = 4,
		tierId = 4,
		sortOrder = 40,
		minItemLevel = 265,
		maxItemLevel = 500,
		maxUpgradeLevel = 8,
		statMultiplierMax = 1.75,
		upgradeCostPerLevel = 200,
		enabled = 1,
		name = "Mythic",
		sourceContent = "Mythic Content",
		icon = "Interface\\Icons\\INV_Misc_Coin_04",
		color = { r = 0.8, g = 0.2, b = 0.8 },
	},
	[5] = {
		id = 5,
		tierId = 5,
		sortOrder = 50,
		minItemLevel = 1,
		maxItemLevel = 500,
		maxUpgradeLevel = 12,
		statMultiplierMax = 2.5,
		upgradeCostPerLevel = 250,
		isArtifact = 1,
		enabled = 1,
		name = "Artifact",
		sourceContent = "Artifacts",
		icon = "Interface\\Icons\\INV_Misc_Gem_Amethyst_01",
		color = { r = 1.0, g = 0.5, b = 0.0 },
	},
};

function DC.BootstrapTierDefinitions()
	local definitions = {};
	for tierId, definition in pairs(DC.DEFAULT_TIER_DEFINITIONS) do
		definitions[tierId] = CopyTierDefinition(definition);
	end

	local source = "default";
	local revision = 0;
	local sourceRows = nil;

	local nativeRows = DC.GetNativeTierRows();
	if type(nativeRows) == "table" and #nativeRows > 0 then
		source = "native";
		revision = GetTierDataRevision();
		sourceRows = nativeRows;
	elseif type(DC.TIER_STATIC_DATA) == "table" and #DC.TIER_STATIC_DATA > 0 then
		source = "static";
		revision = tonumber(DC.TIER_STATIC_DATA_VERSION) or 0;
		sourceRows = DC.TIER_STATIC_DATA;
	end

	if type(sourceRows) == "table" then
		for _, row in ipairs(sourceRows) do
			local normalized = DC.NormalizeTierDefinition(row);
			if normalized then
				local merged = definitions[normalized.tierId] or {
					tierId = normalized.tierId,
				};
				for key, value in pairs(normalized) do
					if type(value) == "string" then
						if value ~= "" then
							merged[key] = value;
						end
					elseif value ~= nil then
						merged[key] = value;
					end
				end

				if normalized.colorARGB and normalized.colorARGB > 0 then
					merged.color = BuildTierColor(
						normalized.colorARGB,
						merged.color);
				elseif type(merged.color) ~= "table" then
					merged.color = { r = 1.0, g = 1.0, b = 1.0 };
				end

				if not merged.name or merged.name == "" then
					merged.name = string.format(
						"Tier %d",
						normalized.tierId);
				end
				if not merged.icon or merged.icon == "" then
					merged.icon = "Interface\\Icons\\INV_Misc_QuestionMark";
				end
				if merged.enabled == nil then
					merged.enabled = 1;
				end

				definitions[normalized.tierId] = merged;
			end
		end
	end

	DC.TIER_DEFINITIONS = definitions;
	DC.TIER_NAMES = {};
	DC.TIER_ICONS = {};
	DC.TIER_COLORS = {};
	DC.MAX_UPGRADE_LEVELS_BY_TIER = {};

	for tierId, definition in pairs(definitions) do
		definition.tierId = tonumber(definition.tierId) or tierId;
		if type(definition.color) ~= "table" then
			definition.color = { r = 1.0, g = 1.0, b = 1.0 };
		end
		if not definition.name or definition.name == "" then
			definition.name = string.format("Tier %d", tierId);
		end
		if not definition.icon or definition.icon == "" then
			definition.icon = "Interface\\Icons\\INV_Misc_QuestionMark";
		end
		if not definition.maxUpgradeLevel then
			definition.maxUpgradeLevel = DC.MAX_UPGRADE_LEVEL or 15;
		end

		DC.TIER_NAMES[tierId] = definition.name;
		DC.TIER_ICONS[tierId] = definition.icon;
		DC.TIER_COLORS[tierId] = CopyColor(definition.color)
			or { r = 1.0, g = 1.0, b = 1.0 };
		DC.MAX_UPGRADE_LEVELS_BY_TIER[tierId] =
			tonumber(definition.maxUpgradeLevel) or (DC.MAX_UPGRADE_LEVEL or 15);
	end

	DC.activeTierDataSource = source;
	DC.activeTierDataRevision = revision;
	DC.activeTierRowCount = type(sourceRows) == "table" and #sourceRows or 0;

	return definitions;
end

function DC.BootstrapTierItemData()
	local rows = {};
	local byTier = {};
	local source = "none";
	local revision = 0;
	local sourceRows = nil;

	local nativeRows = DC.GetNativeTierItemRows();
	if type(nativeRows) == "table" and #nativeRows > 0 then
		source = "native";
		revision = GetTierItemDataRevision();
		sourceRows = nativeRows;
	elseif type(DC.TIER_ITEM_STATIC_DATA) == "table"
		and #DC.TIER_ITEM_STATIC_DATA > 0 then
		source = "static";
		revision = tonumber(DC.TIER_ITEM_STATIC_DATA_VERSION) or 0;
		sourceRows = DC.TIER_ITEM_STATIC_DATA;
	end

	if type(sourceRows) == "table" then
		for _, row in ipairs(sourceRows) do
			local normalized = DC.NormalizeTierItemRow(row);
			if normalized then
				table.insert(rows, normalized);
			end
		end
	end

	table.sort(rows, function(left, right)
		if (left.tierId or 0) ~= (right.tierId or 0) then
			return (left.tierId or 0) < (right.tierId or 0);
		end
		if (left.sortOrder or 0) ~= (right.sortOrder or 0) then
			return (left.sortOrder or 0) < (right.sortOrder or 0);
		end
		if (left.itemLevel or 0) ~= (right.itemLevel or 0) then
			return (left.itemLevel or 0) > (right.itemLevel or 0);
		end
		return (left.itemId or 0) < (right.itemId or 0);
	end);

	for _, row in ipairs(rows) do
		local tierId = tonumber(row.tierId) or 0;
		if not byTier[tierId] then
			byTier[tierId] = {};
		end
		table.insert(byTier[tierId], row);
	end

	DC.TIER_ITEM_ROWS = rows;
	DC.TIER_ITEMS_BY_TIER = byTier;
	DC.activeTierItemDataSource = source;
	DC.activeTierItemDataRevision = revision;
	DC.activeTierItemRowCount = #rows;

	return rows;
end

function DC.GetTierItemRows()
	if type(DC.TIER_ITEM_ROWS) ~= "table" then
		DC.BootstrapTierItemData();
	end

	return DC.TIER_ITEM_ROWS or {};
end

function DC.GetTierItemsForTier(tier)
	if type(DC.TIER_ITEMS_BY_TIER) ~= "table" then
		DC.BootstrapTierItemData();
	end

	local tierId = tonumber(tier) or 0;
	return DC.TIER_ITEMS_BY_TIER[tierId] or {};
end

function DC.GetTierItemCount(tier)
	local rows = DC.GetTierItemsForTier(tier);
	return rows and #rows or 0;
end

function DC.GetTierDefinition(tier)
	if type(DC.TIER_DEFINITIONS) ~= "table" or not next(DC.TIER_DEFINITIONS) then
		DC.BootstrapTierDefinitions();
	end

	local tierId = tonumber(tier) or 1;
	return DC.TIER_DEFINITIONS[tierId] or DC.TIER_DEFINITIONS[1];
end

function DC.GetTierDisplayName(tier)
	local definition = DC.GetTierDefinition(tier);
	if definition and definition.name then
		return definition.name;
	end

	return string.format("Tier %d", tonumber(tier) or 0);
end

function DC.GetTierIcon(tier)
	local definition = DC.GetTierDefinition(tier);
	if definition and definition.icon then
		return definition.icon;
	end

	return "Interface\\Icons\\INV_Misc_QuestionMark";
end

function DC.GetTierColor(tier)
	local definition = DC.GetTierDefinition(tier);
	if definition and type(definition.color) == "table" then
		return definition.color;
	end

	return { r = 1.0, g = 1.0, b = 1.0 };
end

function DC.GetMaxUpgradeLevelForTier(tier)
	local definition = DC.GetTierDefinition(tier);
	if not definition or not definition.maxUpgradeLevel then
		local fallback = DC.MAX_UPGRADE_LEVEL or 15;
		DC.Debug(
			"GetMaxUpgradeLevelForTier: tier=" .. tostring(tier)
			.. " returned fallback=" .. fallback);
		return fallback;
	end

	return tonumber(definition.maxUpgradeLevel) or (DC.MAX_UPGRADE_LEVEL or 15);
end

function DC.GetSortedTierDefinitions()
	local definitions = DC.BootstrapTierDefinitions();
	local rows = {};

	for tierId, definition in pairs(definitions) do
		local row = CopyTierDefinition(definition) or {};
		row.tierId = tonumber(row.tierId) or tonumber(tierId) or 0;
		row.sortOrder = tonumber(row.sortOrder) or (row.tierId * 10);
		table.insert(rows, row);
	end

	table.sort(rows, function(left, right)
		if left.sortOrder ~= right.sortOrder then
			return left.sortOrder < right.sortOrder;
		end
		return (left.tierId or 0) < (right.tierId or 0);
	end);

	return rows;
end

function DC.PrintTierDefinitions()
	local rows = DC.GetSortedTierDefinitions();

	DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff=== DC ItemUpgrade Tier Data ===|r");
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"Source: |cffffcc00%s|r  Revision: |cffffcc00%s|r  Rows: |cffffcc00%s|r",
		tostring(DC.activeTierDataSource or "default"),
		tostring(DC.activeTierDataRevision or 0),
		tostring(DC.activeTierRowCount or 0)));

	for _, definition in ipairs(rows) do
		local tierId = tonumber(definition.tierId) or 0;
		DEFAULT_CHAT_FRAME:AddMessage(string.format(
			"  Tier %d: |cff00ff00%s|r | max=%s | ilvl=%s-%s | src=%s",
			tierId,
			tostring(definition.name or ("Tier " .. tierId)),
			tostring(definition.maxUpgradeLevel or 0),
			tostring(definition.minItemLevel or 0),
			tostring(definition.maxItemLevel or 0),
			tostring(definition.sourceContent or "n/a")));
	end
end

DC.BootstrapTierDefinitions();
DC.BootstrapTierItemData();

DC.COST_COLORS = {
	cheap = { r = 0.2, g = 0.8, b = 0.2 },      -- Green (affordable)
	moderate = { r = 0.8, g = 0.8, b = 0.2 },   -- Yellow (somewhat affordable)
	expensive = { r = 0.8, g = 0.2, b = 0.2 },  -- Red (expensive)
};

--[[=====================================================
	SETTINGS
=======================================================]]

DC.DEFAULT_SETTINGS = {
	autoEquip = true,
	debug = false,
	showTooltips = true,
	playSounds = true,
	showCelebration = true,
	batchQueryDelay = 0.1,
	maxPoolSize = 50,
	itemScanCacheLifetime = 5,
	-- Protocol settings
	useDCProtocolJSON = true,
	verboseProtocol = false,
	useChatFallback = true,
	autoRetry = true,
};

-- Initialize settings (called after SavedVariables load)
function DC.InitializeSettings()
	DC_ItemUpgrade_Settings = DC_ItemUpgrade_Settings or {};
	for key, defaultValue in pairs(DC.DEFAULT_SETTINGS) do
		if DC_ItemUpgrade_Settings[key] == nil then
			DC_ItemUpgrade_Settings[key] = defaultValue;
		end
	end
	
	DC.itemStatePoolSize = DC.itemStatePoolSize or 0;
	DC.maxPoolSize = DC_ItemUpgrade_Settings.maxPoolSize or DC.DEFAULT_SETTINGS.maxPoolSize;
	DC.itemScanCacheLifetime = DC_ItemUpgrade_Settings.itemScanCacheLifetime or DC.DEFAULT_SETTINGS.itemScanCacheLifetime;
	DC.batchQueryDelay = DC_ItemUpgrade_Settings.batchQueryDelay or DC.DEFAULT_SETTINGS.batchQueryDelay;
end

--[[=====================================================
	UPGRADE HISTORY (PER-CHARACTER)
=======================================================]]

DC.UPGRADE_HISTORY_DEFAULT_MAX = 200;

function DC.EnsureUpgradeHistory()
	if not DC_ItemUpgrade_CharSettings then
		DC_ItemUpgrade_CharSettings = {};
	end

	if type(DC_ItemUpgrade_CharSettings.upgradeHistory) ~= "table" then
		DC_ItemUpgrade_CharSettings.upgradeHistory = {};
	end

	-- Optional index: last upgrade per item (keyed by guid if available, else itemId)
	if type(DC_ItemUpgrade_CharSettings.upgradeHistoryMap) ~= "table" then
		DC_ItemUpgrade_CharSettings.upgradeHistoryMap = {};
	end

	local maxEntries = tonumber(DC_ItemUpgrade_CharSettings.upgradeHistoryMax) or DC.UPGRADE_HISTORY_DEFAULT_MAX;
	if maxEntries < 10 then
		maxEntries = 10;
	end
	if maxEntries > 1000 then
		maxEntries = 1000;
	end
	DC_ItemUpgrade_CharSettings.upgradeHistoryMax = maxEntries;

	return DC_ItemUpgrade_CharSettings.upgradeHistory, maxEntries;
end

function DC.AddUpgradeHistoryEntry(entry)
	if type(entry) ~= "table" then
		return;
	end

	local history, maxEntries = DC.EnsureUpgradeHistory();
	entry.ts = tonumber(entry.ts) or time();

	-- Update per-item map (last entry)
	local key = entry.itemGUID or entry.guid or entry.itemId;
	if key then
		DC_ItemUpgrade_CharSettings.upgradeHistoryMap[tostring(key)] = entry;
	end

	table.insert(history, 1, entry);
	while #history > maxEntries do
		table.remove(history);
	end
end

function DC.ClearUpgradeHistory()
	if DC_ItemUpgrade_CharSettings and type(DC_ItemUpgrade_CharSettings.upgradeHistory) == "table" then
		DC_ItemUpgrade_CharSettings.upgradeHistory = {};
	end
	if DC_ItemUpgrade_CharSettings and type(DC_ItemUpgrade_CharSettings.upgradeHistoryMap) == "table" then
		DC_ItemUpgrade_CharSettings.upgradeHistoryMap = {};
	end
end

function DC.GetUpgradeHistory()
	local history = DC.EnsureUpgradeHistory();
	return history;
end

function DC.FormatUpgradeHistoryEntry(entry)
	if type(entry) ~= "table" then
		return "";
	end

	local ts = entry.ts and date("%m-%d %H:%M", entry.ts) or "?";
	local itemText = entry.itemLink or entry.itemName or (entry.itemId and ("ItemID " .. tostring(entry.itemId)) or "Item");
	local fromLevel = entry.fromLevel;
	local toLevel = entry.toLevel;
	local tier = entry.tier;
	local mode = entry.mode;

	local parts = {};
	table.insert(parts, "|cff888888[" .. ts .. "]|r");
	table.insert(parts, itemText);

	if fromLevel and toLevel then
		table.insert(parts, string.format("lvl %d->%d", fromLevel, toLevel));
	elseif toLevel then
		table.insert(parts, string.format("lvl %d", toLevel));
	end

	if tier then
		table.insert(parts, "tier " .. tostring(tier));
	end
	if mode then
		table.insert(parts, "(" .. tostring(mode) .. ")");
	end

	if entry.packageId then
		table.insert(parts, "pkg " .. tostring(entry.packageId));
	end

	return table.concat(parts, " - ");
end

-- Settings reference (alias for convenience)
DC.Settings = DC_ItemUpgrade_Settings;

--[[=====================================================
	DEBUG FUNCTION
=======================================================]]

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

--[[=====================================================
	UTILITY FUNCTIONS
=======================================================]]

-- Helper function to play sounds with setting check
function DC.PlaySound(soundName)
	if DC_ItemUpgrade_Settings and DC_ItemUpgrade_Settings.playSounds then
		PlaySound(soundName);
	end
end

-- Helper function to add item ID line to any tooltip
-- DEPRECATED: DC-QoS Tooltips.lua now handles this - keeping for API compatibility
function DC.AddItemIDToTooltip(tooltip, itemId, itemLink)
	-- Skip if DC-QoS is handling tooltips (preferred)
	if DCQOS and DCQOS.settings and DCQOS.settings.tooltips and DCQOS.settings.tooltips.showItemId then
		return false; -- DC-QoS will handle it
	end
	if not tooltip or not DC.showItemIDsInTooltips then
		return false;
	end
	
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
	
	if tooltip.__dcItemIDAdded == itemId then
		return false;
	end
	tooltip.__dcItemIDAdded = itemId;
	
	tooltip:AddLine(string.format("|cff888888Item ID: %d|r", itemId));
	tooltip:Show();
	return true;
end

--[[=====================================================
	STAT CALCULATION UTILITIES
=======================================================]]

DC.STAT_PERCENT_PER_LEVEL = 2.5;

local BASE_STAT_INCREMENT = 0.025; -- 2.5% per level baseline
local TIER_STAT_MULTIPLIERS = { 0.9, 0.95, 1.0, 1.15, 1.25 };
local TIER_ILVL_PER_LEVEL = { 1.0, 1.0, 1.5, 2.0, 2.5 };

function DC.ClampTier(tier)
	tier = math.floor(tonumber(tier) or 1);
	if tier < 1 then return 1; end
	if tier > #TIER_STAT_MULTIPLIERS then return #TIER_STAT_MULTIPLIERS; end
	return tier;
end

function DC.GetStatMultiplierForLevel(level, tier)
	level = math.max(tonumber(level) or 0, 0);
	local base = 1.0 + (BASE_STAT_INCREMENT * level);
	local tierMult = TIER_STAT_MULTIPLIERS[DC.ClampTier(tier)] or 1.0;
	return ((base - 1.0) * tierMult) + 1.0;
end

function DC.GetStatBonusPercent(level, tier)
	return (DC.GetStatMultiplierForLevel(level, tier) - 1.0) * 100.0;
end

function DC.GetItemLevelBonus(level, tier)
	level = math.max(tonumber(level) or 0, 0);
	local perLevel = TIER_ILVL_PER_LEVEL[DC.ClampTier(tier)] or 1.0;
	return math.ceil(level * perLevel);
end

function DC.GetUpgradedItemLevel(baseLevel, level, tier)
	baseLevel = tonumber(baseLevel) or 0;
	return baseLevel + DC.GetItemLevelBonus(level, tier);
end
--[[=====================================================
	SETTINGS PANEL
=======================================================]]

function DC.CreateSettingsPanel()
	local panel = CreateFrame("Frame", "DC_ItemUpgrade_SettingsPanel", UIParent);
	panel.name = "DC ItemUpgrade";
	
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
	autoEquipCheck:SetChecked(DC_ItemUpgrade_Settings.autoEquip);
	autoEquipCheck:SetScript("OnClick", function(self)
		DC_ItemUpgrade_Settings.autoEquip = self:GetChecked();
	end);
	
	-- Debug checkbox
	-- SMSG_COST_INFO (0x13) - Authoritative cost totals for a target range
	DCProtocol:RegisterHandler("UPG", 0x13, function(data)
		DC.Debug("Received SMSG_COST_INFO: " .. tostring(data or "nil"));
		if type(data) ~= "table" then return; end

		local tier = tonumber(data.tier) or 0;
		local fromLevel = tonumber(data.fromLevel) or 0;
		local toLevel = tonumber(data.toLevel) or 0;
		local key = DC.BuildCostCacheKey and DC.BuildCostCacheKey(tier, fromLevel, toLevel);
		if key then
			DC.pendingCostRequests[key] = nil;
		end

		if data.success == false or tier <= 0 or toLevel <= fromLevel then
			return;
		end

		if DC.CacheCostInfo then
			DC.CacheCostInfo(tier, fromLevel, toLevel, data.tokens, data.essence);
		end

		if DC.currentItem and DarkChaos_ItemUpgrade_UpdateUI then
			local currentLevel = DC.currentItem.currentUpgrade or 0;
			local targetLevel = DC.targetUpgradeLevel or currentLevel;
			if tier == (DC.currentItem.tier or 0) and fromLevel == currentLevel and toLevel == targetLevel then
				DarkChaos_ItemUpgrade_UpdateUI();
			end
		end
	end);
	
	local debugCheck = CreateFrame("CheckButton", "DC_ItemUpgrade_DebugCheck", panel, "InterfaceOptionsCheckButtonTemplate");
	debugCheck:SetPoint("TOPLEFT", autoEquipCheck, "BOTTOMLEFT", 0, -8);
	if not debugCheck.Text then
		debugCheck.Text = debugCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
		debugCheck.Text:SetPoint("LEFT", debugCheck, "RIGHT", 0, 1);
	end
	debugCheck.Text:SetText("Enable debug logging");
	debugCheck:SetChecked(DC_ItemUpgrade_Settings.debug);
	debugCheck:SetScript("OnClick", function(self)
		DC_ItemUpgrade_Settings.debug = self:GetChecked();
	end);
	
	-- Sound checkbox
	local soundsCheck = CreateFrame("CheckButton", "DC_ItemUpgrade_SoundsCheck", panel, "InterfaceOptionsCheckButtonTemplate");
	soundsCheck:SetPoint("TOPLEFT", debugCheck, "BOTTOMLEFT", 0, -8);
	if not soundsCheck.Text then
		soundsCheck.Text = soundsCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
		soundsCheck.Text:SetPoint("LEFT", soundsCheck, "RIGHT", 0, 1);
	end
	soundsCheck.Text:SetText("Play sound effects");
	soundsCheck:SetChecked(DC_ItemUpgrade_Settings.playSounds);
	soundsCheck:SetScript("OnClick", function(self)
		DC_ItemUpgrade_Settings.playSounds = self:GetChecked();
	end);
	
	-- Celebration checkbox
	local celebrationCheck = CreateFrame("CheckButton", "DC_ItemUpgrade_CelebrationCheck", panel, "InterfaceOptionsCheckButtonTemplate");
	celebrationCheck:SetPoint("TOPLEFT", soundsCheck, "BOTTOMLEFT", 0, -8);
	if not celebrationCheck.Text then
		celebrationCheck.Text = celebrationCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
		celebrationCheck.Text:SetPoint("LEFT", celebrationCheck, "RIGHT", 0, 1);
	end
	celebrationCheck.Text:SetText("Show upgrade celebration");
	celebrationCheck:SetChecked(DC_ItemUpgrade_Settings.showCelebration);
	celebrationCheck:SetScript("OnClick", function(self)
		DC_ItemUpgrade_Settings.showCelebration = self:GetChecked();
	end);
	
	-- Register panel
	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel);
	end
	DC.settingsPanel = panel;
end

function DC.OpenSettingsPanel()
	if DC.settingsPanel then
		InterfaceOptionsFrame_OpenToCategory(DC.settingsPanel);
		InterfaceOptionsFrame_OpenToCategory(DC.settingsPanel);
	end
end

--[[=====================================================
	SLASH COMMANDS
=======================================================]]

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
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff=== DC ItemUpgrade Commands ===|r");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu|r - Open upgrade window");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu heirloom|r - Open heirloom upgrade window");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu packages|r - List available stat packages");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu package <id>|r - Select stat package (1-12)");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu settings|r - Open settings panel");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu debug|r - Toggle debug mode");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu status|r - Show current settings status");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu tiers|r - Open the tier browser");
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00/dcu cache clear|r - Clear item cache");
		
	elseif subcmd == "heirloom" or subcmd == "h" then
		if UnitAffectingCombat("player") then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000You cannot upgrade items while in combat!|r");
			return;
		end
		DC.uiMode = "HEIRLOOM";
		if DarkChaos_ItemUpgradeFrame then
			DarkChaos_ItemUpgradeFrame:Show();
			if DarkChaos_ItemUpgradeFrame.TitleText then
				DarkChaos_ItemUpgradeFrame.TitleText:SetText("Heirloom Upgrade");
			end
		end
		
	elseif subcmd == "packages" or subcmd == "pkgs" then
		if DC.STAT_PACKAGES then
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
		end
		
	elseif subcmd == "package" or subcmd == "pkg" then
		local pkgId = tonumber(args[2]);
		if not pkgId or pkgId < 1 or pkgId > 12 then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Invalid package ID. Use 1-12.|r");
			return;
		end
		if DarkChaos_ItemUpgrade_SelectStatPackage then
			DarkChaos_ItemUpgrade_SelectStatPackage(pkgId);
		end
		
	elseif subcmd == "settings" or subcmd == "config" then
		DC.OpenSettingsPanel();
		
	elseif subcmd == "debug" then
		DC_ItemUpgrade_Settings.debug = not DC_ItemUpgrade_Settings.debug;
		local status = DC_ItemUpgrade_Settings.debug and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r";
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Debug mode " .. status);
		
	elseif subcmd == "status" then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff=== DC ItemUpgrade Status ===|r");
		local function statusColor(val) return val and "|cff00ff00ON|r" or "|cffff0000OFF|r"; end
		DEFAULT_CHAT_FRAME:AddMessage("Debug: " .. statusColor(DC_ItemUpgrade_Settings.debug));
		DEFAULT_CHAT_FRAME:AddMessage("Sounds: " .. statusColor(DC_ItemUpgrade_Settings.playSounds));
		DEFAULT_CHAT_FRAME:AddMessage("Celebration: " .. statusColor(DC_ItemUpgrade_Settings.showCelebration));
		DEFAULT_CHAT_FRAME:AddMessage("Tokens: |cffffcc00" .. (DC.playerTokens or 0) .. "|r");
		DEFAULT_CHAT_FRAME:AddMessage("Essence: |cffffcc00" .. (DC.playerEssence or 0) .. "|r");
		if DC.selectedStatPackage and DC.STAT_PACKAGES and DC.STAT_PACKAGES[DC.selectedStatPackage] then
			local pkg = DC.STAT_PACKAGES[DC.selectedStatPackage];
			DEFAULT_CHAT_FRAME:AddMessage("Package: " .. pkg.name);
		end

	elseif subcmd == "tiers" then
		if DC.ToggleTierBrowser then
			DC.ToggleTierBrowser(true);
		else
			DC.PrintTierDefinitions();
		end
		
	elseif subcmd == "cache" then
		if args[2] == "clear" then
			DC.itemUpgradeCache = {};
			DC.itemLocationCache = {};
			DC.itemScanCache = {};
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00DC ItemUpgrade:|r Cache cleared.");
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
				if DarkChaos_ItemUpgradeFrame.TitleText then
					DarkChaos_ItemUpgradeFrame.TitleText:SetText("Item Upgrade");
				end
			end
		end
	end
end

-- Initialize settings on load
DC.InitializeSettings();

--[[=====================================================
	DCADDONPROTOCOL INTEGRATION
	Provides lightweight server communication alongside
	existing chat command fallbacks
=======================================================]]

function DC.RegisterDCProtocolHandlers()
	if not DCProtocol then
		DC.Debug("DCAddonProtocol not available, using chat commands only");
		return;
	end
	
	DC.Debug("Registering DCAddonProtocol handlers for Upgrade module");
	
	-- SMSG_ITEM_INFO (0x10) - Item upgrade information response
	DCProtocol:RegisterHandler("UPG", 0x10, function(data)
		DC.Debug("Received SMSG_ITEM_INFO: " .. tostring(data or "nil"));
		if type(data) ~= "table" then return; end
		
		local info = data
		info.itemID = info.itemID or info.itemId
		if info then
			local entry = tonumber(info.itemEntry)
			if entry and entry > 0 then
				info.itemEntry = entry
			end
		end
		if DarkChaos_ItemUpgrade_HandleJsonItemInfo then
			DarkChaos_ItemUpgrade_HandleJsonItemInfo(info)
			return
		end
		
		if info and info.itemID then
			-- Store in cache
			DC.itemUpgradeCache = DC.itemUpgradeCache or {}
			DC.itemUpgradeCache[info.itemID] = info
			
			-- Trigger UI update if we have a pending item
			if DC.pendingUpgrade and DC.pendingUpgrade.itemID == info.itemID then
				DC.pendingUpgrade = nil
				if DarkChaos_ItemUpgrade_UpdateUI then
					DarkChaos_ItemUpgrade_UpdateUI()
				end
			end
			
			DC.Debug(string.format("Cached item %d: tier=%d, level=%d/%d", 
				info.itemID, info.tier, info.currentUpgrade, info.maxUpgrade))
		end
	end);
	
	-- SMSG_UPGRADE_RESULT (0x11) - Upgrade success/failure notification
	DCProtocol:RegisterHandler("UPG", 0x11, function(data)
		if type(data) ~= "table" then return; end
		DC.Debug(string.format(
			"Received SMSG_UPGRADE_RESULT: success=%s item=%s level=%s slot=%s:%s",
			tostring(data.success),
			tostring(data.itemId or data.itemID or "nil"),
			tostring(data.newLevel or 0),
			tostring(data.serverBag or "nil"),
			tostring(data.serverSlot or "nil")));
		
		local success = data.success
		local itemId = data.itemId or data.itemID
		local newLevel = data.newLevel or 0
		local errorCode = data.errorCode or 0
		local errorMsg = data.errorMsg
		local resultTier = tonumber(data.tier) or 0
		local resultMaxUpgrade = tonumber(data.maxUpgrade) or 0
		local nextTokenCost = tonumber(data.tokenCost) or 0
		local nextEssenceCost = tonumber(data.essenceCost) or 0
		local resultServerBag = tonumber(data.serverBag)
		local resultServerSlot = tonumber(data.serverSlot)
		local pending = DC.pendingUpgrade
		local pendingKey = nil
		if pending and pending.bag ~= nil and pending.serverSlot ~= nil then
			pendingKey = tostring(pending.bag) .. ":" .. tostring(pending.serverSlot)
		end
		
		if success then
			-- Upgrade successful
			local prevLevel, tier, maxUpgrade
			if DC.itemUpgradeCache and DC.itemUpgradeCache[itemId] then
				prevLevel = DC.itemUpgradeCache[itemId].currentUpgrade
				tier = DC.itemUpgradeCache[itemId].tier
				maxUpgrade = DC.itemUpgradeCache[itemId].maxUpgrade
			end

			DC.PlaySound("LEVELUPSOUND");
			
			-- Update cache
			DC.itemUpgradeCache = DC.itemUpgradeCache or {}
			DC.itemUpgradeCache[itemId] = DC.itemUpgradeCache[itemId] or {}
			DC.itemUpgradeCache[itemId].currentUpgrade = newLevel;
			if resultTier > 0 then
				DC.itemUpgradeCache[itemId].tier = resultTier;
			end
			if resultMaxUpgrade > 0 then
				DC.itemUpgradeCache[itemId].maxUpgrade = resultMaxUpgrade;
			end
			DC.itemUpgradeCache[itemId].tokenCost = nextTokenCost;
			DC.itemUpgradeCache[itemId].essenceCost = nextEssenceCost;

			if DC.CacheCostInfo and resultTier > 0 and resultMaxUpgrade > 0 and newLevel < resultMaxUpgrade then
				DC.CacheCostInfo(resultTier, newLevel, newLevel + 1, nextTokenCost, nextEssenceCost);
			end

			if pendingKey and DC.currentItem then
				local currentKey = tostring(DC.currentItem.serverBag or DC.currentItem.bag or -1) .. ":" .. tostring(DC.currentItem.serverSlot or -1)
				if currentKey == pendingKey then
					DC.currentItem.awaitingServerInfo = false
					DC.currentItem.hasAuthoritativeState = true
					DC.currentItem.allowBackgroundRefresh = true
					DC.currentItem.currentUpgrade = tonumber(newLevel) or DC.currentItem.currentUpgrade or 0
					if resultTier > 0 then
						DC.currentItem.tier = resultTier
					end
					if resultMaxUpgrade > 0 then
						DC.currentItem.maxUpgrade = resultMaxUpgrade
					end
					DC.currentItem.tokenCost = nextTokenCost
					DC.currentItem.essenceCost = nextEssenceCost
					if resultServerBag ~= nil then
						DC.currentItem.serverBag = resultServerBag
					end
					if resultServerSlot ~= nil then
						DC.currentItem.serverSlot = resultServerSlot
					end
					if DC.GetClientLocationFromServer and resultServerBag ~= nil and resultServerSlot ~= nil then
						local clientBag, clientSlot = DC.GetClientLocationFromServer(resultServerBag, resultServerSlot)
						if clientBag ~= nil and clientSlot ~= nil then
							DC.currentItem.bag = clientBag
							DC.currentItem.slot = clientSlot
							DC.currentItem.isEquipped = DC.IsEquippedBag and DC.IsEquippedBag(clientBag) or false
						end
					end
					if itemId then
						DC.currentItem.guid = itemId
						DC.itemLocationCache = DC.itemLocationCache or {}
						DC.itemLocationCache[pendingKey] = itemId
					end
					if DC.currentItem.serverBag ~= nil and DC.currentItem.serverSlot ~= nil then
						DC.currentItem.locationKey = tostring(DC.currentItem.serverBag) .. ":" .. tostring(DC.currentItem.serverSlot)
					end
					if DC.currentItem.maxUpgrade and newLevel < DC.currentItem.maxUpgrade then
						DC.targetUpgradeLevel = newLevel + 1
					else
						DC.targetUpgradeLevel = math.max(newLevel, 1)
					end
				end
			end

			local nextTier = resultTier or tier or (DC.currentItem and DC.currentItem.tier) or 0
			local nextMaxUpgrade = resultMaxUpgrade or maxUpgrade or (DC.currentItem and DC.currentItem.maxUpgrade) or 0
			if DC.RequestCostInfo and nextTier > 0 and nextTier ~= 3 and newLevel < nextMaxUpgrade then
				DC.RequestCostInfo(nextTier, newLevel, newLevel + 1)
			end

			DC.pendingUpgrade = nil

			-- Record history (standard upgrades only; heirloom shirt handled by DCHEIRLOOM_SUCCESS)
			if itemId ~= 300365 then
				local itemName, itemLink = GetItemInfo(itemId)
				DC.AddUpgradeHistoryEntry({
					source = "protocol",
					mode = "STANDARD",
					itemId = itemId,
					itemName = itemName,
					itemLink = itemLink,
					fromLevel = prevLevel,
					toLevel = newLevel,
					tier = tier,
					maxUpgrade = maxUpgrade,
				});
			end
			
			-- Show celebration
			if DC_ItemUpgrade_Settings.showCelebration and DC.ShowUpgradeCelebration then
				DC.ShowUpgradeCelebration(itemId, newLevel);
			end
			
			-- Refresh UI
			if DC.RefreshUpgradeFrame then
				DC.RefreshUpgradeFrame();
			end
			if DarkChaos_ItemUpgrade_UpdateUI then
				DarkChaos_ItemUpgrade_UpdateUI()
			end
			
			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				"|cff00ff00Upgrade successful!|r Item upgraded to level %d", newLevel));
		else
			-- Upgrade failed
			if pendingKey and DC.currentItem then
				local currentKey = tostring(DC.currentItem.serverBag or DC.currentItem.bag or -1) .. ":" .. tostring(DC.currentItem.serverSlot or -1)
				if currentKey == pendingKey then
					DC.currentItem.awaitingServerInfo = false
				end
			end
			DC.pendingUpgrade = nil
			DC.PlaySound("igQuestFailed");
			
			local errorMessages = {
				[1] = "Item not found",
				[2] = "Already at maximum upgrade level",
				[3] = "Insufficient tokens",
				[4] = "Insufficient essence",
				[5] = "Item is not upgradeable",
				[6] = "Cannot upgrade in combat",
			};
			
			local msg = errorMessages[errorCode] or errorMsg or "Unknown error";
			if DarkChaos_ItemUpgrade_UpdateUI then
				DarkChaos_ItemUpgrade_UpdateUI()
			end
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Upgrade failed:|r " .. msg);
		end
	end);
	
	-- SMSG_CURRENCY_UPDATE (0x14) - Token/Essence balance update
	DCProtocol:RegisterHandler("UPG", 0x14, function(data)
		if type(data) ~= "table" then return; end
		
		local tokens = data.tokens
		local essence = data.essence
		local tokenId = data.tokenId or data.tokenID
		local essenceId = data.essenceId or data.essenceID
		
		if tokens and essence then
			DC.playerTokens = tonumber(tokens) or 0;
			DC.playerEssence = tonumber(essence) or 0;
			if tokenId then
				DC.TOKEN_ITEM_ID = tonumber(tokenId) or DC.TOKEN_ITEM_ID;
			end
			if essenceId then
				DC.ESSENCE_ITEM_ID = tonumber(essenceId) or DC.ESSENCE_ITEM_ID;
			end
			
			DC.Debug(string.format("Received SMSG_CURRENCY_UPDATE: %d tokens, %d essence",
				DC.playerTokens, DC.playerEssence));
			
			-- Bridge: expose server currency into DCAddonProtocol's shared balance
			local central = rawget(_G, "DCAddonProtocol")
			if central and type(central.SetServerCurrencyBalance) == "function" then
				if tokenId then
					central.TOKEN_ITEM_ID = tonumber(tokenId) or central.TOKEN_ITEM_ID
				end
				if essenceId then
					central.ESSENCE_ITEM_ID = tonumber(essenceId) or central.ESSENCE_ITEM_ID
				end
				central:SetServerCurrencyBalance(DC.playerTokens, DC.playerEssence)
			end
			
			-- Update UI currency display
			if DC.UpdateCurrencyDisplay then
				DC.UpdateCurrencyDisplay();
			end
		end
	end);
	
	-- SMSG_BATCH_ITEM_INFO (0x12) - Multiple items info response (for inventory scan)
	DCProtocol:RegisterHandler("UPG", 0x12, function(data)
		DC.Debug("Received SMSG_BATCH_ITEM_INFO");
		if type(data) ~= "table" then return; end
		
		local items = data.items or data
		if items and type(items) == "table" then
			DC.itemUpgradeCache = DC.itemUpgradeCache or {}
			for _, item in ipairs(items) do
				if type(item) == "table" then
					local itemId = item.itemId or item.itemID
					if itemId then
						DC.itemUpgradeCache[itemId] = {
							itemID = itemId,
							currentUpgrade = item.currentUpgrade or 0,
							maxUpgrade = item.maxUpgrade or 10,
							tier = item.tier or 1,
						}
					end
				elseif type(item) == "string" then
					local bag, slot, guid, entry, tier = string.match(item, "^(%d+):(%d+):(%d+):(%d+):(%d+)")
					if entry then
						local entryId = tonumber(entry)
						DC.itemUpgradeCache[entryId] = {
							itemID = entryId,
							currentUpgrade = 0,
							maxUpgrade = 10,
							tier = tonumber(tier) or 1,
						}
					end
				end
			end
		end
		
		-- Trigger inventory refresh
		if DC.RefreshInventoryOverlays then
			DC.RefreshInventoryOverlays();
		end
	end);

	-- SMSG_HEIRLOOM_INFO (0x16) - Heirloom upgrade info
	DCProtocol:RegisterHandler("UPG", 0x16, function(data)
		DC.Debug("Received SMSG_HEIRLOOM_INFO: " .. tostring(data or "nil"));
		if type(data) ~= "table" then return; end

		local success, itemGuid, level, packageId, maxLevel, maxPackage
		success = data.success
		itemGuid = data.itemGuid or data.itemID
		level = data.level or data.upgradeLevel
		packageId = data.packageId
		maxLevel = data.maxLevel
		maxPackage = data.maxPackage

		if success then
			DC.selectedStatPackage = (packageId and packageId > 0) and packageId or DC.selectedStatPackage
			if DC.currentItem and DC.currentItem.guid == itemGuid then
				DC.currentItem.currentUpgrade = level
				DC.currentItem.maxUpgrade = maxLevel
				DC.currentItem.heirloomPackageId = packageId
			end
			if itemGuid then
				DC.itemUpgradeCache = DC.itemUpgradeCache or {}
				local cached = DC.itemUpgradeCache[itemGuid] or {}
				cached.itemID = cached.itemID or itemGuid
				cached.currentUpgrade = level or cached.currentUpgrade
				cached.maxUpgrade = maxLevel or cached.maxUpgrade
				cached.heirloomPackageId = packageId or cached.heirloomPackageId
				DC.itemUpgradeCache[itemGuid] = cached
			end
			if DarkChaos_ItemUpgrade_UpdateUI then
				DarkChaos_ItemUpgrade_UpdateUI()
			end
		else
			local msg = data.errorMsg or data.message or "Heirloom query failed."
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000" .. msg .. "|r")
		end
	end)

	-- SMSG_HEIRLOOM_RESULT (0x17) - Heirloom upgrade result
	DCProtocol:RegisterHandler("UPG", 0x17, function(data)
		DC.Debug("Received SMSG_HEIRLOOM_RESULT: " .. tostring(data or "nil"));
		if type(data) ~= "table" then return; end

		local success, itemGuid, newLevel, packageId, enchantId
		success = data.success
		itemGuid = data.itemGuid or data.itemID
		newLevel = data.newLevel or data.level
		packageId = data.packageId
		enchantId = data.enchantId

		if success then
			if DC.currentItem and DC.currentItem.guid == itemGuid then
				DC.currentItem.currentUpgrade = newLevel
				DC.currentItem.heirloomPackageId = packageId or DC.currentItem.heirloomPackageId
			end
			if itemGuid then
				DC.itemUpgradeCache = DC.itemUpgradeCache or {}
				local cached = DC.itemUpgradeCache[itemGuid] or {}
				cached.itemID = cached.itemID or itemGuid
				cached.currentUpgrade = newLevel or cached.currentUpgrade
				cached.heirloomPackageId = packageId or cached.heirloomPackageId
				DC.itemUpgradeCache[itemGuid] = cached
			end
			if packageId and packageId > 0 then
				DC.selectedStatPackage = packageId
			end
			if DarkChaos_ItemUpgrade_UpdateUI then
				DarkChaos_ItemUpgrade_UpdateUI()
			end
			DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00Heirloom upgraded to level %d.|r", newLevel))
		else
			local msg = data.errorMsg or data.message or "Heirloom upgrade failed."
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000" .. msg .. "|r")
		end
	end)
end

--[[=====================================================
	JSON PARSING UTILITY
=======================================================]]

-- Simple JSON parser for Lua (handles objects, arrays, strings, numbers, booleans, null)
function DC.ParseJSON(jsonStr)
	if not jsonStr or jsonStr == "" then return nil end
	
	local pos = 1
	local len = string.len(jsonStr)
	
	local function skipWhitespace()
		while pos <= len do
			local c = string.sub(jsonStr, pos, pos)
			if c == " " or c == "\t" or c == "\n" or c == "\r" then
				pos = pos + 1
			else
				break
			end
		end
	end
	
	local function parseString()
		if string.sub(jsonStr, pos, pos) ~= '"' then return nil end
		pos = pos + 1
		local startPos = pos
		local result = ""
		while pos <= len do
			local c = string.sub(jsonStr, pos, pos)
			if c == '"' then
				pos = pos + 1
				return result
			elseif c == '\\' then
				pos = pos + 1
				local escaped = string.sub(jsonStr, pos, pos)
				if escaped == 'n' then result = result .. "\n"
				elseif escaped == 't' then result = result .. "\t"
				elseif escaped == 'r' then result = result .. "\r"
				elseif escaped == '"' then result = result .. '"'
				elseif escaped == '\\' then result = result .. '\\'
				else result = result .. escaped end
				pos = pos + 1
			else
				result = result .. c
				pos = pos + 1
			end
		end
		return nil
	end
	
	local function parseNumber()
		local startPos = pos
		local c = string.sub(jsonStr, pos, pos)
		if c == '-' then pos = pos + 1 end
		while pos <= len do
			c = string.sub(jsonStr, pos, pos)
			if c >= '0' and c <= '9' then
				pos = pos + 1
			elseif c == '.' or c == 'e' or c == 'E' or c == '+' or c == '-' then
				pos = pos + 1
			else
				break
			end
		end
		return tonumber(string.sub(jsonStr, startPos, pos - 1))
	end
	
	local parseValue
	
	local function parseArray()
		if string.sub(jsonStr, pos, pos) ~= '[' then return nil end
		pos = pos + 1
		local arr = {}
		skipWhitespace()
		if string.sub(jsonStr, pos, pos) == ']' then
			pos = pos + 1
			return arr
		end
		while pos <= len do
			skipWhitespace()
			local val = parseValue()
			table.insert(arr, val)
			skipWhitespace()
			local c = string.sub(jsonStr, pos, pos)
			if c == ']' then
				pos = pos + 1
				return arr
			elseif c == ',' then
				pos = pos + 1
			else
				break
			end
		end
		return arr
	end
	
	local function parseObject()
		if string.sub(jsonStr, pos, pos) ~= '{' then return nil end
		pos = pos + 1
		local obj = {}
		skipWhitespace()
		if string.sub(jsonStr, pos, pos) == '}' then
			pos = pos + 1
			return obj
		end
		while pos <= len do
			skipWhitespace()
			local key = parseString()
			if not key then break end
			skipWhitespace()
			if string.sub(jsonStr, pos, pos) ~= ':' then break end
			pos = pos + 1
			skipWhitespace()
			obj[key] = parseValue()
			skipWhitespace()
			local c = string.sub(jsonStr, pos, pos)
			if c == '}' then
				pos = pos + 1
				return obj
			elseif c == ',' then
				pos = pos + 1
			else
				break
			end
		end
		return obj
	end
	
	parseValue = function()
		skipWhitespace()
		local c = string.sub(jsonStr, pos, pos)
		if c == '"' then
			return parseString()
		elseif c == '{' then
			return parseObject()
		elseif c == '[' then
			return parseArray()
		elseif c == 't' and string.sub(jsonStr, pos, pos + 3) == 'true' then
			pos = pos + 4
			return true
		elseif c == 'f' and string.sub(jsonStr, pos, pos + 4) == 'false' then
			pos = pos + 5
			return false
		elseif c == 'n' and string.sub(jsonStr, pos, pos + 3) == 'null' then
			pos = pos + 4
			return nil
		elseif c == '-' or (c >= '0' and c <= '9') then
			return parseNumber()
		end
		return nil
	end
	
	return parseValue()
end

--[[=====================================================
	COMMUNICATION SETTINGS PANEL
=======================================================]]

-- Helper function for panel printing
local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[DC-ItemUpgrade]|r " .. tostring(msg))
end

-- Create Communication Settings sub-panel
function DC.CreateCommPanel()
	local panel = CreateFrame("Frame", "DC_ItemUpgrade_CommPanel", UIParent)
	panel.name = "Communication"
	panel.parent = "DC ItemUpgrade"
	
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("DC-ItemUpgrade Communication Settings")
	
	-- Status line
	local statusLine = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	statusLine:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	local dcStatus = DC.useDCProtocol and "|cff00ff00Available|r" or "|cffff0000Not Found|r"
	local aioStatus = DC.hasAIO and "|cff00ff00Available|r" or "|cffff0000Not Found|r"
	statusLine:SetText("DC Protocol: " .. dcStatus .. "  |  AIO: " .. aioStatus .. "  |  Mode: |cffffcc00" .. DC.protocolMode .. "|r")
	panel.statusLine = statusLine
	
	-- Button layout settings
	local btnWidth = 150
	local btnHeight = 22
	local colSpacing = 160
	local rowSpacing = 28
	local startX = 20
	local startY = -70
	
	local function CreateButton(name, text, col, row, onClick)
		local btn = CreateFrame("Button", "DC_ItemUpgrade_Comm_" .. name, panel, "UIPanelButtonTemplate")
		btn:SetWidth(btnWidth)
		btn:SetHeight(btnHeight)
		btn:SetPoint("TOPLEFT", panel, "TOPLEFT", startX + (col * colSpacing), startY - (row * rowSpacing))
		btn:SetText(text)
		btn:SetScript("OnClick", onClick)
		return btn
	end
	
	-- Row 0: Test buttons
	CreateButton("PingDC", "Ping DC Protocol", 0, 0, function()
		Print("Ping disabled in JSON-only mode")
	end)
	
	CreateButton("PingAIO", "Ping AIO", 1, 0, function()
		if DC.hasAIO and AIO then
			Print("AIO detected: " .. (AIO.GetVersion and tostring(AIO.GetVersion()) or "unknown version"))
		else
			Print("|cffff0000AIO not available!|r")
		end
	end)
	
	CreateButton("TestChat", "Test Chat Cmd", 2, 0, function()
		Print("Testing chat command: .dcupgrade init")
		SendChatMessage(".dcupgrade init", "SAY")
	end)
	
	CreateButton("ShowStatus", "Show Status", 3, 0, function()
		Print("--- Protocol Status ---")
		Print("DC Protocol: " .. (DC.useDCProtocol and "Available" or "Not Found"))
		Print("AIO: " .. (DC.hasAIO and "Available" or "Not Found"))
		Print("Active Mode: " .. DC.protocolMode)
		Print("JSON Mode: " .. (DC.useDCProtocolJSON and "Enabled" or "Disabled"))
		Print("Verbose: " .. (DC.verboseProtocol and "Enabled" or "Disabled"))
		Print("Tokens: " .. (DC.playerTokens or 0) .. " | Essence: " .. (DC.playerEssence or 0))
	end)
	
	-- Row 1: Toggle buttons
	CreateButton("ToggleJSON", "Toggle JSON", 0, 1, function()
		DC.useDCProtocolJSON = not DC.useDCProtocolJSON
		DC_ItemUpgrade_Settings.useDCProtocolJSON = DC.useDCProtocolJSON
		Print("JSON Mode: " .. (DC.useDCProtocolJSON and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
	end)
	
	CreateButton("ToggleVerbose", "Toggle Verbose", 1, 1, function()
		DC.verboseProtocol = not DC.verboseProtocol
		DC_ItemUpgrade_Settings.verboseProtocol = DC.verboseProtocol
		Print("Verbose Mode: " .. (DC.verboseProtocol and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
	end)
	
	CreateButton("ToggleFallback", "Toggle Fallback", 2, 1, function()
		DC_ItemUpgrade_Settings.useChatFallback = not DC_ItemUpgrade_Settings.useChatFallback
		Print("Chat Fallback: " .. (DC_ItemUpgrade_Settings.useChatFallback and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
	end)
	
	CreateButton("ToggleRetry", "Toggle AutoRetry", 3, 1, function()
		DC_ItemUpgrade_Settings.autoRetry = not DC_ItemUpgrade_Settings.autoRetry
		Print("Auto Retry: " .. (DC_ItemUpgrade_Settings.autoRetry and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
	end)
	
	-- Row 2: Sync buttons
	CreateButton("SyncCurrency", "Sync Currency", 0, 2, function()
		DC.RequestCurrencySync()
		Print("Currency sync requested")
	end)
	
	CreateButton("ClearCache", "Clear Cache", 1, 2, function()
		DC.itemUpgradeCache = {}
		DC.itemLocationCache = {}
		DC.itemScanCache = {}
		Print("All caches cleared")
	end)
	
	CreateButton("RefreshUI", "Refresh UI", 2, 2, function()
		if DarkChaos_ItemUpgrade_UpdateUI then
			DarkChaos_ItemUpgrade_UpdateUI()
			Print("UI refreshed")
		end
	end)
	
	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
	
	DC.commPanel = panel
	return panel
end

--[[=====================================================
	PROTOCOL-AWARE REQUEST FUNCTIONS WITH FALLBACK
=======================================================]]

function DC.BuildCostCacheKey(tier, fromLevel, toLevel)
	tier = tonumber(tier) or 0;
	fromLevel = tonumber(fromLevel) or 0;
	toLevel = tonumber(toLevel) or 0;
	if tier <= 0 or fromLevel < 0 or toLevel <= fromLevel then
		return nil;
	end
	return string.format("%d:%d:%d", tier, fromLevel, toLevel);
end

function DC.CacheCostInfo(tier, fromLevel, toLevel, tokens, essence)
	local key = DC.BuildCostCacheKey(tier, fromLevel, toLevel);
	if not key then
		return nil;
	end

	DC.liveCostCache = DC.liveCostCache or {};
	DC.liveCostCache[key] = {
		tier = tonumber(tier) or 0,
		fromLevel = tonumber(fromLevel) or 0,
		toLevel = tonumber(toLevel) or 0,
		tokens = tonumber(tokens) or 0,
		essence = tonumber(essence) or 0,
		timestamp = GetTime and GetTime() or 0,
	};

	return DC.liveCostCache[key];
end

function DC.GetCachedCostInfo(tier, fromLevel, toLevel)
	local key = DC.BuildCostCacheKey(tier, fromLevel, toLevel);
	if not key or not DC.liveCostCache then
		return nil;
	end
	return DC.liveCostCache[key];
end

-- Protocol-aware request functions with fallback chain
function DC.RequestItemInfo(bag, slot, itemLink)
	-- Try DC Protocol first
	if DCProtocol and DC.useDCProtocol then
		DCProtocol:Request("UPG", 0x01, { bag = bag, slot = slot }) -- CMSG_GET_ITEM_INFO
		DC.Debug(string.format("Sent item info request via DC protocol: %d|%d", bag, slot))
		return
	end
end

function DC.RequestUpgrade(bag, slot, targetLevel)
	-- Try DC Protocol first
	if DCProtocol and DC.useDCProtocol then
		local level = targetLevel or 1
		DCProtocol:Request("UPG", 0x02, { bag = bag, slot = slot, targetLevel = level }) -- CMSG_DO_UPGRADE
		DC.Debug(string.format("Sent upgrade request via DC protocol: %d|%d|%d", bag, slot, level))
		return
	end
end

function DC.RequestCostInfo(tier, fromLevel, toLevel)
	if not (DCProtocol and DC.useDCProtocol) then
		return false;
	end

	local key = DC.BuildCostCacheKey(tier, fromLevel, toLevel);
	if not key then
		return false;
	end

	DC.liveCostCache = DC.liveCostCache or {};
	DC.pendingCostRequests = DC.pendingCostRequests or {};
	if DC.liveCostCache[key] or DC.pendingCostRequests[key] then
		return false;
	end

	DC.pendingCostRequests[key] = true;
	DCProtocol:Request("UPG", 0x04, {
		tier = tonumber(tier) or 0,
		fromLevel = tonumber(fromLevel) or 0,
		toLevel = tonumber(toLevel) or 0,
	}); -- CMSG_GET_COSTS
	DC.Debug(string.format("Sent cost info request via DC protocol: tier=%d from=%d to=%d",
		tonumber(tier) or 0,
		tonumber(fromLevel) or 0,
		tonumber(toLevel) or 0));
	return true;
end

function DC.RequestCurrencySync()
	-- Currency is server-pushed on login and after upgrade events in DC protocol mode.
	if DCProtocol and DC.useDCProtocol then
		return
	end
end

function DC.RequestBatchItemInfo(itemIds)
	if not itemIds or #itemIds == 0 then return end
	
	-- Try DC Protocol first
	if DCProtocol and DC.useDCProtocol then
		DCProtocol:Request("UPG", 0x03, { items = itemIds }) -- CMSG_BATCH_REQUEST
		DC.Debug("Sent batch item request via DC protocol: " .. #itemIds .. " items")
		return
	end
end


-- Initialize DC protocol handlers and communication panel
DC.RegisterDCProtocolHandlers()

-- Note: DC.CreateCommPanel() is called from DarkChaos_ItemUpgrade_Retail.lua's PLAYER_LOGIN handler
-- after DC.CreateSettingsPanel() to ensure proper parent panel registration order
