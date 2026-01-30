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

DC.TIER_ICONS = {
	[1] = "Interface\\Icons\\INV_Misc_Coin_01",        -- Leveling (Copper coin)
	[2] = "Interface\\Icons\\INV_Misc_Coin_02",        -- Heroic (Silver coin)
	[3] = "Interface\\Icons\\INV_Misc_Coin_03",        -- Raid (Gold coin)
	[4] = "Interface\\Icons\\INV_Misc_Coin_04",        -- Mythic (Platinum coin)
	[5] = "Interface\\Icons\\INV_Misc_Gem_Amethyst_01", -- Artifact (Gem)
};

DC.TIER_COLORS = {
	[1] = { r = 0.6, g = 0.6, b = 0.6 },    -- Leveling (Gray)
	[2] = { r = 0.2, g = 0.8, b = 0.2 },    -- Heroic (Green)
	[3] = { r = 0.2, g = 0.2, b = 1.0 },    -- Raid (Blue)
	[4] = { r = 0.8, g = 0.2, b = 0.8 },    -- Mythic (Purple)
	[5] = { r = 1.0, g = 0.5, b = 0.0 },    -- Artifact (Orange)
};

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
	CLONE MAP UTILITIES
=======================================================]]

function DC.CopyCloneEntries(source)
	if not source then
		return nil;
	end
	local copy = {};
	for level, entry in pairs(source) do
		copy[level] = entry;
	end
	return copy;
end

function DC.ParseCloneMap(mapString)
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

function DC.GetCloneEntryForLevel(item, level)
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
			info.cloneEntries = info.cloneEntries or DC.ParseCloneMap(info.cloneMap)
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
		DC.Debug("Received SMSG_UPGRADE_RESULT: " .. tostring(data or "nil"));
		if type(data) ~= "table" then return; end
		
		local success = data.success
		local itemId = data.itemId or data.itemID
		local newLevel = data.newLevel or 0
		local newEntry = data.newEntry
		local errorCode = data.errorCode or 0
		local errorMsg = data.errorMsg
		
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
			if DC.itemUpgradeCache and DC.itemUpgradeCache[itemId] then
				DC.itemUpgradeCache[itemId].currentUpgrade = newLevel;
				if newEntry then
					DC.itemUpgradeCache[itemId].currentEntry = newEntry;
				end
			end

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
			
			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				"|cff00ff00Upgrade successful!|r Item upgraded to level %d", newLevel));
		else
			-- Upgrade failed
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
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Upgrade failed:|r " .. msg);
		end
	end);
	
	-- SMSG_CURRENCY_UPDATE (0x14) - Token/Essence balance update
	DCProtocol:RegisterHandler("UPG", 0x14, function(data)
		DC.Debug("Received SMSG_CURRENCY_UPDATE: " .. tostring(data));
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
			
			DC.Debug(string.format("Currency updated: %d tokens, %d essence", 
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

function DC.RequestCurrencySync()
	-- Server pushes currency updates based on events.
	if DCProtocol and DC.useDCProtocol then
		DCProtocol:Request("UPG", 0x04, {})
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
