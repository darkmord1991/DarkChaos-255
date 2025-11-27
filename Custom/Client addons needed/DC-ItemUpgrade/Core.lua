--[[
	DC-ItemUpgrade - Core Module
	Shared namespace, utilities, settings, and slash commands
	
	Based on: Blizzard_ItemUpgradeUI (11.2.7.64169)
	Adapted for: AzerothCore 3.3.5a with Eluna server communication
--]]

-- Global namespace
DarkChaos_ItemUpgrade = DarkChaos_ItemUpgrade or {};
local DC = DarkChaos_ItemUpgrade;

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
function DC.AddItemIDToTooltip(tooltip, itemId, itemLink)
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
