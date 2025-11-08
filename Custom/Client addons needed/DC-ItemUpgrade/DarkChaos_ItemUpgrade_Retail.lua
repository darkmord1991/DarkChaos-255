--[[
	DC-ItemUpgrade - Retail 11.2.7 Backport for WoW 3.3.5a
	Based on: Blizzard_ItemUpgradeUI (11.2.7.64169)
	Adapted for: AzerothCore 3.3.5a with Eluna server communication
--]]

-- Global namespace
DarkChaos_ItemUpgrade = {};
local DC = DarkChaos_ItemUpgrade;

-- Static configuration
DC.MAX_UPGRADE_LEVEL = DC.MAX_UPGRADE_LEVEL or 15;
DC.ILEVEL_PER_UPGRADE = DC.ILEVEL_PER_UPGRADE or 3;
DC.STAT_PERCENT_PER_LEVEL = DC.STAT_PERCENT_PER_LEVEL or 2;

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

local DarkChaos_ItemUpgrade_ComputeCostTotals;
local DarkChaos_ItemUpgrade_RequestCurrencies;
local DarkChaos_ItemUpgrade_RequestItemInfo;

local BAG_BACKPACK = 0;
local BAG_BANK = _G.BANK_CONTAINER or -1;
local BAG_EQUIPPED = _G.INVENTORY_SLOT_BAG_0 or 255;
local INVENTORY_SLOT_ITEM_START = _G.INVENTORY_SLOT_ITEM_START or 23;
local INVENTORY_SLOT_ITEM_END = _G.INVENTORY_SLOT_ITEM_END or 39;
local BANK_SLOT_ITEM_START = _G.BANK_SLOT_ITEM_START or 39;
local BANK_SLOT_ITEM_END = _G.BANK_SLOT_ITEM_END or 67;
local TOOLTIP_CACHE_LIFETIME = 30; -- seconds

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

local function IsEquippedBag(bag)
	return bag == BAG_EQUIPPED;
end

local function GetServerSlotFromClient(bag, slot)
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

local function BuildLocationKey(bag, slot)
	return string.format("%d:%d", bag or -1, slot or -1);
end

local function DarkChaos_ItemUpgrade_StartNextQuery()
	local nextRequest = table.remove(DC.queryQueueList, 1);
	if not nextRequest then
		DC.queryInFlight = nil;
		return;
	end

	DC.queryInFlight = nextRequest;
	SendChatMessage(nextRequest.command, "SAY");
end

local function DarkChaos_ItemUpgrade_CompleteQuery()
	local finished = DC.queryInFlight;
	if finished then
		DC.queryQueueMap[finished.key] = nil;
	end
	DarkChaos_ItemUpgrade_StartNextQuery();
	return finished;
end

local function DarkChaos_ItemUpgrade_QueueQuery(serverBag, serverSlot, context)
	if serverBag == nil or serverSlot == nil then
		return;
	end

	context = context or {};
	local key = BuildLocationKey(serverBag, serverSlot);

	if DC.queryInFlight and DC.queryInFlight.key == key then
		table.insert(DC.queryInFlight.contexts, context);
		return;
	end

	local existing = DC.queryQueueMap[key];
	if existing then
		table.insert(existing.contexts, context);
		return;
	end

	local request = {
		key = key,
		serverBag = serverBag,
		serverSlot = serverSlot,
		command = string.format(".dcupgrade query %d %d", serverBag, serverSlot),
		contexts = { context },
	};

	DC.queryQueueMap[key] = request;

	if DC.queryInFlight then
		table.insert(DC.queryQueueList, request);
	else
		DC.queryInFlight = request;
		SendChatMessage(request.command, "SAY");
	end
end

local function DarkChaos_ItemUpgrade_GetCachedDataForLocation(serverBag, serverSlot)
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

	if DarkChaos_ItemUpgrade_TooltipHasUpgradeLine and DarkChaos_ItemUpgrade_TooltipHasUpgradeLine(tooltip) then
		if data.guid then
			tooltip.__dcUpgradeLastGuid = data.guid;
		end
		tooltip.__dcUpgradeLastStamp = GetTime and GetTime() or 0;
		return;
	end

	if tooltip.__dcUpgradeLastGuid == data.guid then
		local last = tooltip.__dcUpgradeLastStamp or 0;
		local now = GetTime and GetTime() or 0;
		if now - last < 0.25 then
			return;
		end
	end

	local current = data.currentUpgrade or 0;
	local maxUpgrade = data.maxUpgrade or DC.MAX_UPGRADE_LEVEL or 15;
	local baseLevel = data.baseItemLevel or 0;
	local upgradedLevel = data.upgradedItemLevel or baseLevel;
	local statMultiplier = data.statMultiplier or 1.0;
	local totalBonus = (statMultiplier - 1.0) * 100;

	tooltip:AddLine(" ");
	tooltip:AddLine(string.format("|cffffcc00Upgrade Level %d / %d|r", current, maxUpgrade));
	tooltip:AddLine(string.format("|cff00ff00Item Level: %d (Base %d)|r", upgradedLevel, baseLevel));
	
	-- Show stat multiplier details
	if totalBonus > 0 then
		tooltip:AddLine(string.format("|cff00ff00All Stats: +%.1f%%|r", totalBonus));
		
		-- Calculate and show what stats are increased
		if statMultiplier > 1.0 then
			tooltip:AddLine("|cff888888This includes:|r");
			tooltip:AddLine(string.format("|cff888888  • Primary Stats (Str/Agi/Sta/Int/Spi) x%.2f|r", statMultiplier));
			tooltip:AddLine(string.format("|cff888888  • Secondary Stats (Crit/Haste/Hit) x%.2f|r", statMultiplier));
			tooltip:AddLine(string.format("|cff888888  • Armor and Resistances x%.2f|r", statMultiplier));
			tooltip:AddLine(string.format("|cff888888  • Weapon Damage x%.2f|r", statMultiplier));
			tooltip:AddLine(string.format("|cff888888  • Spell Power x%.2f|r", statMultiplier));
			tooltip:AddLine(string.format("|cff888888  • Proc Effects x%.2f|r", statMultiplier));
		end
	end

	if data.guid then
		tooltip.__dcUpgradeLastGuid = data.guid;
	end
	tooltip.__dcUpgradeLastStamp = GetTime and GetTime() or 0;
	tooltip:Show();
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

local function DarkChaos_ItemUpgrade_ApplyQueryData(item, data)
	if not item or not data then
		return;
	end

	item.tier = data.tier or item.tier or 1;
	item.currentUpgrade = data.currentUpgrade or 0;
	item.maxUpgrade = data.maxUpgrade or DC.MAX_UPGRADE_LEVEL or 15;
	item.baseLevel = data.baseItemLevel or item.baseLevel or 0;
	item.upgradedLevel = data.upgradedItemLevel or item.upgradedLevel or item.baseLevel;
	item.level = item.upgradedLevel;
	item.statMultiplier = data.statMultiplier or item.statMultiplier or 1.0;
	item.guid = data.guid or item.guid;
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
	local upgraded = item.upgradedLevel or baseLevel;
	local gain = upgraded - baseLevel;
	if current > 0 and gain > 0 then
		item.ilevelStep = gain / current;
	elseif not item.ilevelStep then
		item.ilevelStep = DC.ILEVEL_PER_UPGRADE or 3;
	end

	if item.statMultiplier and current > 0 then
		item.statPerLevel = ((item.statMultiplier - 1.0) * 100) / current;
	elseif not item.statPerLevel then
		item.statPerLevel = DC.STAT_PERCENT_PER_LEVEL or 2;
	end

	local maxUpgrade = item.maxUpgrade or DC.MAX_UPGRADE_LEVEL or 15;
	if current >= maxUpgrade then
		DC.targetUpgradeLevel = maxUpgrade;
	else
		local defaultTarget = current + 1;
		local requested = DC.targetUpgradeLevel or defaultTarget;
		DC.targetUpgradeLevel = math.max(defaultTarget, math.min(requested, maxUpgrade));
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

local function DarkChaos_ItemUpgrade_OnTooltipSetBagItem(tooltip, bag, slot)
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

local function DarkChaos_ItemUpgrade_OnTooltipSetInventoryItem(tooltip, unit, slot)
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

local ICON_TOKEN = "|TInterface\\Icons\\INV_Misc_Coin_01:14:14:0:0|t";
local ICON_ESSENCE = "|TInterface\\Icons\\INV_Misc_Gem_Pearl_05:14:14:0:0|t";

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

local function GetItemTooltipInfo(link)
	if not link then return nil; end

	local cache = DC.itemTooltipCache[link];
	local now = GetTime and GetTime() or 0;
	if cache and ((now - (cache.timestamp or 0)) < 10) then
		return cache;
	end

	scanTooltip:SetOwner(UIParent, "ANCHOR_NONE");
	scanTooltip:ClearLines();
	scanTooltip:SetHyperlink(link);

	local itemLevel = select(4, GetItemInfo(link)) or 0;
	local upgradeLevel = 0;
	local maxLevel = DC.MAX_UPGRADE_LEVEL;

	for i = 2, scanTooltip:NumLines() do
		local text = GetTooltipLine(i);
		if text then
			local cur, max = text:match("Upgrade%s*[Ll]evel:?%s*(%d+)%s*/%s*(%d+)");
			if cur and max then
				upgradeLevel = tonumber(cur) or upgradeLevel;
				maxLevel = tonumber(max) or maxLevel;
				break;
			end
		end
	end

	local info = {
		ilevel = itemLevel,
		upgrade = upgradeLevel,
		max = maxLevel,
		timestamp = now,
	};

	DC.itemTooltipCache[link] = info;
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

function DarkChaos_ItemUpgrade_OnHide(self)
	PlaySound("igCharacterInfoClose");
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

	DC.pendingUpgrade = nil;
end

function DarkChaos_ItemUpgrade_OnEvent(self, event, ...)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN");
		DarkChaos_ItemUpgrade_InitializeCosts();
		DC.pendingUpgrade = nil;
		DarkChaos_ItemUpgrade_RequestCurrencies();
		DarkChaos_ItemUpgrade_UpdateUI();
		return;
	end

	if event == "CHAT_MSG_SAY" or event == "CHAT_MSG_WHISPER" then
		local message, sender = ...;
		DarkChaos_ItemUpgrade_OnChatMessage(message, sender);
		return;
	end

	if event == "CHAT_MSG_SYSTEM" then
		local message = ...;
		if type(message) == "string" and string.find(message, "^DCUPGRADE_") then
			DarkChaos_ItemUpgrade_OnChatMessage(message, UnitName("player"));
		end
		return;
	end

	if event == "BAG_UPDATE" then
		local bagID = ...;
		if DC.currentItem and not DC.currentItem.isEquipped and bagID == DC.currentItem.bag then
			local link = GetItemLinkForLocation(DC.currentItem.bag, DC.currentItem.slot);
			if not link or link ~= DC.currentItem.link then
				DarkChaos_ItemUpgrade_ClearItem();
			else
				DC.currentItem.link = link;
				DC.currentItem.texture = GetItemTextureForLocation(DC.currentItem.bag, DC.currentItem.slot, link);
				DarkChaos_ItemUpgrade_RequestItemInfo();
				DarkChaos_ItemUpgrade_UpdateUI();
			end
		end
		if DarkChaos_ItemBrowserFrame and DarkChaos_ItemBrowserFrame:IsShown() then
			DarkChaos_ItemBrowser_Update();
		end
		return;
	end

	if event == "PLAYER_EQUIPMENT_CHANGED" then
		local slotID = ...;
		if DC.currentItem and DC.currentItem.isEquipped and slotID == DC.currentItem.slot then
			local link = GetItemLinkForLocation(DC.currentItem.bag, DC.currentItem.slot);
			if not link then
				DarkChaos_ItemUpgrade_ClearItem();
			else
				DC.currentItem.link = link;
				DC.currentItem.texture = GetItemTextureForLocation(DC.currentItem.bag, DC.currentItem.slot, link);
				DarkChaos_ItemUpgrade_RequestItemInfo();
				DarkChaos_ItemUpgrade_UpdateUI();
			end
		end
		if DarkChaos_ItemBrowserFrame and DarkChaos_ItemBrowserFrame:IsShown() then
			DarkChaos_ItemBrowser_Update();
		end
		return;
	end

	if event == "UNIT_INVENTORY_CHANGED" then
		local unit = ...;
		if unit == "player" then
			if DC.currentItem and DC.currentItem.isEquipped then
				local link = GetItemLinkForLocation(DC.currentItem.bag, DC.currentItem.slot);
				if not link then
					DarkChaos_ItemUpgrade_ClearItem();
				else
					DC.currentItem.link = link;
					DC.currentItem.texture = GetItemTextureForLocation(DC.currentItem.bag, DC.currentItem.slot, link);
					DarkChaos_ItemUpgrade_RequestItemInfo();
					DarkChaos_ItemUpgrade_UpdateUI();
				end
			end
			if DarkChaos_ItemBrowserFrame and DarkChaos_ItemBrowserFrame:IsShown() then
				DarkChaos_ItemBrowser_Update();
			end
		end
		return;
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
	
	-- Button glow pulse
	if self.UpgradeButton and self.UpgradeButton:IsEnabled() and self.UpgradeButton.Glow:IsShown() then
		DC.glowAnimationTime = (DC.glowAnimationTime or 0) + elapsed;
		local alpha = 0.5 + math.sin(DC.glowAnimationTime * 2) * 0.3;
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

	local totals = DarkChaos_ItemUpgrade_ComputeCostTotals(tier, currentUpgrade, targetLevel);
	local singleCost = DarkChaos_ItemUpgrade_GetCost(tier, targetLevel);
	if (totals.tokens <= 0 and totals.essence <= 0) and not singleCost then
		print("|cffff0000Upgrade failed:|r Unable to determine the cost for the selected level.");
		return;
	end

	local requiredTokens = singleCost and (singleCost.tokens or 0) or totals.tokens;
	local requiredEssence = singleCost and (singleCost.essence or 0) or totals.essence;

	if (DC.playerTokens or 0) < requiredTokens then
		print(string.format("|cffff0000Not enough Upgrade Tokens!|r Need %d but have %d.", requiredTokens, DC.playerTokens or 0));
		return;
	end

	if (DC.playerEssence or 0) < requiredEssence then
		print(string.format("|cffff0000Not enough Artifact Essence!|r Need %d but have %d.", requiredEssence, DC.playerEssence or 0));
		return;
	end

	SetButtonEnabled(self, false);
	if self.Glow then
		self.Glow:Hide();
	end

	local serverBag = DC.currentItem.serverBag or DC.currentItem.bag;
	local serverSlot = DC.currentItem.serverSlot or math.max(0, (DC.currentItem.slot or 1) - 1);
	local command = string.format(".dcupgrade perform %d %d %d", serverBag, serverSlot, targetLevel);
	DC.pendingUpgrade = {
		target = targetLevel,
		startLevel = currentUpgrade,
		bag = serverBag,
		slot = DC.currentItem.slot,
		serverSlot = serverSlot,
		tier = tier,
		cost = totals,
	};
	DC.Debug("Sending perform command: "..command);
	local itemLabel = DC.currentItem.link or DC.currentItem.name or "item";
	local projectedTokens = totals.tokens > 0 and totals.tokens or requiredTokens;
	local projectedEssence = totals.essence > 0 and totals.essence or requiredEssence;
	print(string.format("|cff00ff00Upgrading %s to level %d/%d...|r", itemLabel, targetLevel, maxUpgrade));
	if projectedTokens > 0 or projectedEssence > 0 then
		local parts = {};
		if projectedTokens > 0 then
			table.insert(parts, string.format("%d Tokens", projectedTokens));
		end
		if projectedEssence > 0 then
			table.insert(parts, string.format("%d Essence", projectedEssence));
		end
		print(string.format("|cff00ff00Projected total to reach level %d:|r %s", targetLevel, table.concat(parts, " and ")));
	end
	if singleCost and ((singleCost.tokens or 0) > 0 or (singleCost.essence or 0) > 0) then
		local immediateParts = {};
		if (singleCost.tokens or 0) > 0 then
			table.insert(immediateParts, string.format("%d Tokens", singleCost.tokens));
		end
		if (singleCost.essence or 0) > 0 then
			table.insert(immediateParts, string.format("%d Essence", singleCost.essence));
		end
		print(string.format("|cff00ff00Immediate cost for this step:|r %s", table.concat(immediateParts, " and ")));
	end
	SendChatMessage(command, "SAY");
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
			info.arg1 = level;
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

function DarkChaos_ItemUpgrade_Dropdown_OnClick(self, level)
	local selectedLevel = tonumber(level) or tonumber(self and self.value) or nil;
	if not selectedLevel then
		return;
	end

	if DC.currentItem then
		local currentUpgrade = DC.currentItem.currentUpgrade or 0;
		local maxUpgrade = DC.currentItem.maxUpgrade or DC.MAX_UPGRADE_LEVEL;
		selectedLevel = math.min(math.max(math.floor(selectedLevel + 0.5), currentUpgrade + 1), maxUpgrade);
	end

	DC.targetUpgradeLevel = selectedLevel;
	UIDropDownMenu_SetSelectedValue(DarkChaos_ItemUpgradeFrame.Dropdown, selectedLevel);

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

	DC.currentItem = {
		bag = bag,
		serverBag = serverBag,
		slot = slot,
		serverSlot = serverSlot,
		locationKey = locationKey,
		isEquipped = isEquipped,
		texture = texture,
		link = link,
		itemID = itemID,
		quality = quality,
		name = name,
		level = level,
		baseLevel = level,
		upgradedLevel = level,
		tier = 1,
		currentUpgrade = 0,
		maxUpgrade = DC.MAX_UPGRADE_LEVEL,
		statMultiplier = 1.0,
		ilevelStep = DC.ILEVEL_PER_UPGRADE or 3,
		statPerLevel = DC.STAT_PERCENT_PER_LEVEL or 2,
	};

	DC.targetUpgradeLevel = 1;

	local cached = DarkChaos_ItemUpgrade_GetCachedDataForLocation(serverBag, serverSlot);
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

	DarkChaos_ItemUpgrade_UpdateUI();

	if DarkChaos_ItemBrowserFrame:IsShown() then
		DarkChaos_ItemBrowserFrame:Hide();
	end
end

function DarkChaos_ItemUpgrade_ClearItem()
	DC.currentItem = nil;
	DC.targetUpgradeLevel = 1;
	DC.pendingUpgrade = nil;
	DarkChaos_ItemUpgrade_UpdateUI();
end

--[[=====================================================
	UI UPDATE
=======================================================]]

function DarkChaos_ItemUpgrade_UpdateUI()
	local frame = DarkChaos_ItemUpgradeFrame;
	if not frame then return end
	if not (frame.ItemSlot and frame.ItemInfo and frame.PlayerCurrencies) then return end
	local dropdown = frame.Dropdown;

	-- Currency counts always stay in sync
	DarkChaos_ItemUpgrade_UpdatePlayerCurrencies();

	-- Clear celebration overlay when idle
	if frame.RightTooltip and frame.RightTooltip.UpgradeGlow and DC.upgradeAnimationTime <= 0 then
		frame.RightTooltip.UpgradeGlow:Hide();
	end

	if not DC.currentItem then
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
		frame.LeftTooltip:Hide();
		frame.RightTooltip:Hide();
		if frame.Arrow then frame.Arrow:Hide(); end
		if frame.CostFrame then frame.CostFrame:Hide(); end
		frame.ErrorText:Hide();
		frame.MissingDescription:Show();
		if frame.PlayerCurrencies then frame.PlayerCurrencies:Show(); end
		SetButtonEnabled(frame.UpgradeButton, false);
		frame.UpgradeButton.Glow:Hide();
		frame.UpgradeButton.disabledTooltip = nil;
		return;
	end

	local item = DC.currentItem;
	local currentUpgrade = item.currentUpgrade or 0;
	local maxUpgrade = item.maxUpgrade or DC.MAX_UPGRADE_LEVEL;
	local tierName = DC.TIER_NAMES[item.tier] or string.format("Tier %d", item.tier or 0);
	local ilvlStep = item.ilevelStep or DC.ILEVEL_PER_UPGRADE or 3;
	local baseLevel = item.baseLevel or math.max(0, (item.level or 0) - (currentUpgrade * ilvlStep));
	local currentLevel = item.upgradedLevel or item.level or (baseLevel + currentUpgrade * ilvlStep);
	local maxPotential = baseLevel + (maxUpgrade * ilvlStep);
	currentLevel = math.max(baseLevel, currentLevel);
	maxPotential = math.max(baseLevel, maxPotential);

	-- Clamp target selection within valid range
	DC.targetUpgradeLevel = math.min(math.max(DC.targetUpgradeLevel or (currentUpgrade + 1), currentUpgrade + 1), maxUpgrade);

	frame.ItemSlot.EmptyGlow:Hide();
	frame.MissingDescription:Hide();
	if frame.CurrentPanel then frame.CurrentPanel:Show(); end
	if frame.PlayerCurrencies then frame.PlayerCurrencies:Show(); end

	local texture = item.texture or GetItemTextureForLocation(item.bag, item.slot, item.link);
	if not texture and item.link then
		texture = select(10, GetItemInfo(item.link));
	end
	SetItemButtonTexture(frame.ItemSlot, texture);
	DC.currentItem.texture = texture;
	SetItemButtonQuality_335(frame.ItemSlot, item.quality);

	frame.ItemInfo.MissingItemText:Hide();
	frame.ItemInfo.ItemName:Show();
	frame.ItemInfo.ItemName:SetText(item.name or "Unknown Item");
	local color = DC.ITEM_QUALITY_COLORS[item.quality] or DC.ITEM_QUALITY_COLORS[1];
	frame.ItemInfo.ItemName:SetTextColor(color.r, color.g, color.b);

	if frame.ItemInfo.ItemLevelSummary then
		frame.ItemInfo.ItemLevelSummary:Show();
		frame.ItemInfo.ItemLevelSummary:SetText(string.format("%s %d/%d\nItem Level %d (%d-%d)",
			tierName,
			currentUpgrade,
			maxUpgrade,
			currentLevel,
			baseLevel,
			maxPotential
		));
	end

	frame.ItemInfo.UpgradeProgress:Show();
	frame.ItemInfo.UpgradeProgress:SetText(string.format("Upgrade Level %d/%d", currentUpgrade, maxUpgrade));

	if dropdown then
		UIDropDownMenu_SetWidth(dropdown, 150);
		UIDropDownMenu_SetButtonWidth(dropdown, 160);
	end

	local statStep = item.statPerLevel or DC.STAT_PERCENT_PER_LEVEL or 2;
	local currentStatBonus = currentUpgrade * statStep;
	if frame.CurrentPanel and frame.CurrentPanel.StatsText then
		local lines = {
			item.isEquipped and "Location: Equipped" or "Location: Inventory",
			string.format("Item Level: %d", currentLevel),
			string.format("Upgrade Level: %d / %d", currentUpgrade, maxUpgrade),
		};
		if statStep > 0 then
			table.insert(lines, string.format("Total Bonus: +%.1f%%", currentStatBonus));
		end
		frame.CurrentPanel.StatsText:SetText(table.concat(lines, "\n"));
	end
	if frame.CurrentPanel and frame.CurrentPanel.CurrencyHeader and frame.CurrentPanel.CurrencyDetail then
		frame.CurrentPanel.CurrencyHeader:Show();
		frame.CurrentPanel.CurrencyDetail:Show();
		local tokens = DC.playerTokens or 0;
		local essence = DC.playerEssence or 0;
		frame.CurrentPanel.CurrencyDetail:SetText(string.format("%s %d\n%s %d", ICON_TOKEN, tokens, ICON_ESSENCE, essence));
	end

	local targetLevel = DC.targetUpgradeLevel or currentUpgrade;
	local targetItemLevel = baseLevel + (targetLevel * ilvlStep);
	local ilevelGain = targetItemLevel - currentLevel;
	local targetStatBonus = targetLevel * statStep;
	local statGain = targetStatBonus - (currentUpgrade * statStep);

	if frame.UpgradePanel and frame.UpgradePanel.StatsText then
		local upgradeLines = {
			ilevelGain > 0 and string.format("Item Level: %d (+%d)", targetItemLevel, ilevelGain) or string.format("Item Level: %d", targetItemLevel),
			string.format("Upgrade Level: %d / %d", targetLevel, maxUpgrade),
		};
		if statStep > 0 then
			local diffText = statGain > 0 and string.format(" (+%.1f%%)", statGain) or "";
			table.insert(upgradeLines, string.format("Total Bonus: +%.1f%%%s", targetStatBonus, diffText));
		end
		frame.UpgradePanel.StatsText:SetText(table.concat(upgradeLines, "\n"));
	end
	if frame.UpgradePanel and frame.UpgradePanel.CostHeader then
		frame.UpgradePanel.CostHeader:Hide();
	end
	if frame.UpgradePanel and frame.UpgradePanel.CostDetail then
		frame.UpgradePanel.CostDetail:Hide();
	end

	local canUpgrade = currentUpgrade < maxUpgrade;

	if canUpgrade then
		if frame.UpgradeSelector then frame.UpgradeSelector:Show(); end
		if dropdown then
			dropdown:Show();
			UIDropDownMenu_Initialize(dropdown, DarkChaos_ItemUpgrade_Dropdown_Initialize);
			UIDropDownMenu_SetSelectedValue(dropdown, DC.targetUpgradeLevel);
			UIDropDownMenu_SetText(dropdown, string.format("Level %d/%d", DC.targetUpgradeLevel, maxUpgrade));
		end
		if frame.UpgradePanel then frame.UpgradePanel:Show(); end
		DarkChaos_ItemUpgrade_GenerateTooltips();
		if frame.LeftTooltip then frame.LeftTooltip:Show(); end
		if frame.RightTooltip then frame.RightTooltip:Show(); end
		if frame.Arrow then frame.Arrow:Show(); end
		if frame.CostFrame then frame.CostFrame:Hide(); end
		frame.ErrorText:Hide();

		local pendingTotals = DarkChaos_ItemUpgrade_ComputeCostTotals(item.tier, currentUpgrade, DC.targetUpgradeLevel);
		local perLevelCost = DarkChaos_ItemUpgrade_GetCost(item.tier, DC.targetUpgradeLevel);
		local requiredTokens = perLevelCost and (perLevelCost.tokens or 0) or pendingTotals.tokens;
		local requiredEssence = perLevelCost and (perLevelCost.essence or 0) or pendingTotals.essence;
		DarkChaos_ItemUpgrade_UpdateCost();

		if (pendingTotals.tokens > 0 or pendingTotals.essence > 0) and (DC.playerTokens or 0) >= requiredTokens and (DC.playerEssence or 0) >= requiredEssence then
			SetButtonEnabled(frame.UpgradeButton, true);
			frame.UpgradeButton.Glow:Show();
			frame.UpgradeButton.disabledTooltip = nil;
		else
			SetButtonEnabled(frame.UpgradeButton, false);
			frame.UpgradeButton.Glow:Hide();
			if pendingTotals.tokens > 0 or pendingTotals.essence > 0 then
				frame.UpgradeButton.disabledTooltip = "Not enough currency.";
			else
				frame.UpgradeButton.disabledTooltip = "Cannot determine cost.";
			end
		end
	else
		if frame.UpgradeSelector then frame.UpgradeSelector:Hide(); end
		if dropdown then dropdown:Hide(); end
		if frame.UpgradePanel then
			frame.UpgradePanel:Show();
			if frame.UpgradePanel.StatsText then
				local maxLines = {
					string.format("Item Level: %d", currentLevel),
					string.format("Upgrade Level: %d / %d", currentUpgrade, maxUpgrade),
				};
				if statStep > 0 then
					table.insert(maxLines, string.format("Total Bonus: +%d%%", currentStatBonus));
				end
				table.insert(maxLines, "Max level reached");
				frame.UpgradePanel.StatsText:SetText(table.concat(maxLines, "\n"));
			end
			if frame.UpgradePanel.CostHeader then frame.UpgradePanel.CostHeader:Hide(); end
			if frame.UpgradePanel.CostDetail then frame.UpgradePanel.CostDetail:Hide(); end
		end
		if frame.Arrow then frame.Arrow:Hide(); end
		DarkChaos_ItemUpgrade_GenerateCurrentTooltip();
		if frame.LeftTooltip then frame.LeftTooltip:Show(); end
		if frame.RightTooltip then frame.RightTooltip:Hide(); end
		if frame.CostFrame then frame.CostFrame:Hide(); end
		SetButtonEnabled(frame.UpgradeButton, false);
		frame.UpgradeButton.Glow:Hide();
		frame.UpgradeButton.disabledTooltip = "Item is fully upgraded.";
		frame.ErrorText:SetText("This item is already at maximum upgrade level.");
		frame.ErrorText:Show();
	end
end

function DarkChaos_ItemUpgrade_UpdatePlayerCurrencies()
	local parent = DarkChaos_ItemUpgradeFrame;
	if not parent then return end
	if parent.PlayerCurrencies then
		local tokens = DC.playerTokens or 0;
		local essence = DC.playerEssence or 0;
		local tokenColor = "|cffffffff";
		local essenceColor = "|cffffffff";
		if DC.currentItem then
			local currentUpgrade = DC.currentItem.currentUpgrade or 0;
			local targetLevel = DC.targetUpgradeLevel or currentUpgrade;
			local pendingTotals = DarkChaos_ItemUpgrade_ComputeCostTotals(DC.currentItem.tier, currentUpgrade, targetLevel);
			local perLevelCost = DarkChaos_ItemUpgrade_GetCost(DC.currentItem.tier, targetLevel);
			local requiredTokens = perLevelCost and (perLevelCost.tokens or 0) or pendingTotals.tokens;
			local requiredEssence = perLevelCost and (perLevelCost.essence or 0) or pendingTotals.essence;
			if tokens < requiredTokens then tokenColor = "|cffff4c4c"; end
			if essence < requiredEssence then essenceColor = "|cffff4c4c"; end
		end
		parent.PlayerCurrencies.TokenCount:SetText(string.format("%s%d|r", tokenColor, tokens));
		if parent.PlayerCurrencies.EssenceCount then
			parent.PlayerCurrencies.EssenceCount:SetText(string.format("%s%d|r", essenceColor, essence));
		end
	end
	local panel = parent.CurrentPanel;
	if not panel or not panel.CurrencyHeader or not panel.CurrencyDetail then return end
	if DC.currentItem then
		panel.CurrencyHeader:Show();
		panel.CurrencyDetail:Show();
		panel.CurrencyDetail:SetText(string.format("%s %d\n%s %d", ICON_TOKEN, DC.playerTokens or 0, ICON_ESSENCE, DC.playerEssence or 0));
	else
		panel.CurrencyHeader:Hide();
		panel.CurrencyDetail:Hide();
	end
end

function DarkChaos_ItemUpgrade_UpdateCost()
	local parent = DarkChaos_ItemUpgradeFrame;
	if not parent then return end
	if parent.CostFrame then
		parent.CostFrame:Hide();
	end
	local panel = parent.UpgradePanel;
	if not panel or not panel.CostHeader or not panel.CostDetail then return end

	if not DC.currentItem then
		panel.CostHeader:Hide();
		panel.CostDetail:Hide();
		return;
	end

	local currentUpgrade = DC.currentItem.currentUpgrade or 0;
	local targetLevel = DC.targetUpgradeLevel or currentUpgrade;
	local totals = DarkChaos_ItemUpgrade_ComputeCostTotals(DC.currentItem.tier, currentUpgrade, targetLevel);
	local perLevelCost = DarkChaos_ItemUpgrade_GetCost(DC.currentItem.tier, targetLevel);
	local immediateTokens = perLevelCost and (perLevelCost.tokens or 0) or 0;
	local immediateEssence = perLevelCost and (perLevelCost.essence or 0) or 0;
	panel.CostHeader:SetText("Cost:");
	panel.CostDetail:SetTextColor(1, 1, 1);

	if targetLevel <= currentUpgrade or (totals.tokens == 0 and totals.essence == 0) then
		panel.CostHeader:Show();
		panel.CostDetail:Show();
		panel.CostDetail:SetText("Unavailable");
		panel.CostDetail:SetTextColor(1, 0.4, 0.4);
		return;
	end

	panel.CostHeader:Show();
	panel.CostDetail:Show();
	local playerTokens = DC.playerTokens or 0;
	local playerEssence = DC.playerEssence or 0;
	local tokenTotalsEnough = playerTokens >= (totals.tokens or 0);
	local tokenImmediateEnough = playerTokens >= immediateTokens;
	local essenceTotalsEnough = playerEssence >= (totals.essence or 0);
	local essenceImmediateEnough = playerEssence >= immediateEssence;
	local lines = {};

	if totals.tokens > 0 then
		local totalColor = tokenTotalsEnough and "|cffffffff" or "|cffff4c4c";
		table.insert(lines, string.format("%s %sTotal Tokens: %d|r", ICON_TOKEN, totalColor, totals.tokens));
	end
	if immediateTokens > 0 and immediateTokens ~= totals.tokens then
		local immediateColor = tokenImmediateEnough and "|cffffffff" or "|cffff4c4c";
		table.insert(lines, string.format("    Immediate Tokens: %s%d|r", immediateColor, immediateTokens));
	end
	if totals.essence > 0 then
		local totalEssenceColor = essenceTotalsEnough and "|cffffffff" or "|cffff4c4c";
		table.insert(lines, string.format("%s %sTotal Essence: %d|r", ICON_ESSENCE, totalEssenceColor, totals.essence));
	end
	if immediateEssence > 0 and immediateEssence ~= totals.essence then
		local immediateEssenceColor = essenceImmediateEnough and "|cffffffff" or "|cffff4c4c";
		table.insert(lines, string.format("    Immediate Essence: %s%d|r", immediateEssenceColor, immediateEssence));
	end

	panel.CostDetail:SetText(table.concat(lines, "\n"));
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
	
	-- Set border color (Wrath tooltips still rely on backdrops)
	local color = DC.ITEM_QUALITY_COLORS[DC.currentItem.quality] or DC.ITEM_QUALITY_COLORS[1];
	if tooltip.SetBackdropBorderColor then
		tooltip:SetBackdropBorderColor(color.r, color.g, color.b);
	end
	
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
	local levels = math.max(0, (DC.targetUpgradeLevel or 0) - (DC.currentItem.currentUpgrade or 0));
	local statIncrease = levels * (DC.STAT_PERCENT_PER_LEVEL or 2);
	local iLevelIncrease = levels * (DC.ILEVEL_PER_UPGRADE or 3);
	local currentMultiplier = 1.0 + ((DC.currentItem.currentUpgrade or 0) * 0.025);
	local targetMultiplier = 1.0 + ((DC.targetUpgradeLevel or 0) * 0.025);
	local multiplierIncrease = ((targetMultiplier - currentMultiplier) / currentMultiplier) * 100;
	
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
	
	-- Show detailed stat increases
	if levels > 0 then
		tooltip:AddLine(" ");
		tooltip:AddLine(string.format("|cff00ff00All Stats: +%.1f%% (from x%.2f to x%.2f)|r", 
			multiplierIncrease, currentMultiplier, targetMultiplier), 1, 1, 1);
		tooltip:AddLine("|cff888888Includes:|r", 0.7, 0.7, 0.7);
		tooltip:AddLine("|cff888888  • Primary Stats (Str/Agi/Sta/Int/Spi)|r", 0.7, 0.7, 0.7);
		tooltip:AddLine("|cff888888  • Secondary Stats (Crit/Haste/Hit)|r", 0.7, 0.7, 0.7);
		tooltip:AddLine("|cff888888  • Armor and Resistances|r", 0.7, 0.7, 0.7);
		tooltip:AddLine("|cff888888  • Weapon Damage (if applicable)|r", 0.7, 0.7, 0.7);
		tooltip:AddLine("|cff888888  • Spell Power (if applicable)|r", 0.7, 0.7, 0.7);
		tooltip:AddLine("|cff888888  • Proc Effects (if applicable)|r", 0.7, 0.7, 0.7);
	end
	
	-- Set border color (use next quality if available)
	local nextQuality = math.min((DC.currentItem.quality or 1) + math.floor(levels / 3), 5);
	local color = DC.ITEM_QUALITY_COLORS[nextQuality] or DC.ITEM_QUALITY_COLORS[DC.currentItem.quality];
	if tooltip.SetBackdropBorderColor then
		tooltip:SetBackdropBorderColor(color.r, color.g, color.b);
	end
	
	tooltip:Show();
end

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
		return totals;
	end

	for level = currentLevel + 1, targetLevel do
		local cost = DarkChaos_ItemUpgrade_GetCost(tier, level);
		if not cost then
			break;
		end
		totals.tokens = totals.tokens + (cost.tokens or 0);
		totals.essence = totals.essence + (cost.essence or 0);
	end

	return totals;
end

DarkChaos_ItemUpgrade_RequestCurrencies = function()
	SendChatMessage(".dcupgrade init", "SAY");
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
		DC.Debug("INIT received: tokens="..tostring(tokens).." essence="..tostring(essence));
		DarkChaos_ItemUpgrade_UpdateUI();
		return;
	end
	
	-- DCUPGRADE_QUERY response (item upgrade info)
	-- Format from server: "DCUPGRADE_QUERY:<item_guid>:<upgrade_level>:<tier>:<base_ilvl>[:<upgraded_ilvl>:<stat_multiplier>]"
	if string.find(message, "^DCUPGRADE_QUERY") then
		local guidStr, currentLevel, tier, baseIlvl, upgradedIlvl, statMult = string.match(message, "DCUPGRADE_QUERY:(%d+):(%d+):(%d+):(%d+):(%d+):([%d%.]+)");
		if not guidStr then
			guidStr, currentLevel, tier, baseIlvl = string.match(message, "DCUPGRADE_QUERY:(%d+):(%d+):(%d+):(%d+)");
		end

		local guid = tonumber(guidStr) or 0;
		local current = tonumber(currentLevel) or 0;
		local tierId = tonumber(tier) or 1;
		local baseLevel = tonumber(baseIlvl) or 0;
		local upgradedLevel = upgradedIlvl and tonumber(upgradedIlvl) or nil;
		local statMultiplier = statMult and tonumber(statMult) or nil;

		if not upgradedLevel then
			local step = DC.ILEVEL_PER_UPGRADE or 3;
			upgradedLevel = baseLevel + (current * step);
		end

		local data = {
			guid = guid,
			currentUpgrade = current,
			tier = tierId,
			baseItemLevel = baseLevel,
			upgradedItemLevel = upgradedLevel,
			statMultiplier = statMultiplier,
			maxUpgrade = DC.MAX_UPGRADE_LEVEL or 15,
			timestamp = GetTime and GetTime() or 0,
		};

		if not data.statMultiplier and current > 0 then
			local perLevel = DC.STAT_PERCENT_PER_LEVEL or 2;
			data.statMultiplier = 1.0 + (perLevel * current) / 100;
		end

		local request = DarkChaos_ItemUpgrade_CompleteQuery();
		if request then
			data.serverBag = request.serverBag;
			data.serverSlot = request.serverSlot;
			DC.itemLocationCache[request.key] = data.guid;
		end

		DC.itemUpgradeCache[data.guid] = data;

		local matchedCurrent = false;
		if DC.currentItem then
			if (request and request.key == DC.currentItem.locationKey) or (DC.currentItem.guid and DC.currentItem.guid == data.guid) then
				DarkChaos_ItemUpgrade_ApplyQueryData(DC.currentItem, data);
				DC.itemLocationCache[DC.currentItem.locationKey or BuildLocationKey(data.serverBag or DC.currentItem.serverBag, data.serverSlot or DC.currentItem.serverSlot)] = data.guid;
				matchedCurrent = true;
			end
		end

		if matchedCurrent then
			DC.Debug(string.format("QUERY received: guid=%s cur=%s tier=%s base=%s upgraded=%s mult=%s",
				tostring(guid), tostring(currentLevel), tostring(tier), tostring(baseIlvl), upgradedIlvl or "n/a", statMult or "n/a"));
			DarkChaos_ItemUpgrade_UpdateUI();
		end

		if request then
			for _, context in ipairs(request.contexts) do
				if context.type == "tooltip" then
					DarkChaos_ItemUpgrade_HandleTooltipContext(context, data);
				end
			end
			request.contexts = nil;
		end

		return;
	end
	
	-- DCUPGRADE_SUCCESS response (upgrade complete)
	-- Format from server: "DCUPGRADE_SUCCESS:<item_guid>:<new_level>"
	if string.find(message, "^DCUPGRADE_SUCCESS") then
		local _, _, itemGUID, newLevel = string.find(message, "DCUPGRADE_SUCCESS:(%d+):(%d+)");
		
		-- Update item level (recalculate currencies from cost)
		if DC.currentItem then
			local pending = DC.pendingUpgrade;
			local oldLevel = DC.currentItem.currentUpgrade or 0;
			local newUpgradeLevel = tonumber(newLevel) or oldLevel;
			DC.currentItem.currentUpgrade = newUpgradeLevel;
			local ilvlStep = DC.currentItem.ilevelStep or DC.ILEVEL_PER_UPGRADE or 3;
			if DC.currentItem.baseLevel then
				DC.currentItem.upgradedLevel = DC.currentItem.baseLevel + (DC.currentItem.currentUpgrade * ilvlStep);
				DC.currentItem.level = DC.currentItem.upgradedLevel;
			end

			local refreshedLink = GetItemLinkForLocation(DC.currentItem.bag, DC.currentItem.slot);
			if refreshedLink then
				DC.currentItem.link = refreshedLink;
			end
			DC.currentItem.texture = GetItemTextureForLocation(DC.currentItem.bag, DC.currentItem.slot, DC.currentItem.link);

			local totals = DarkChaos_ItemUpgrade_ComputeCostTotals(DC.currentItem.tier, oldLevel, DC.currentItem.currentUpgrade);
			if pending and (totals.tokens == 0 and totals.essence == 0) then
				totals = pending.cost or totals;
			end
			if pending and pending.target and pending.target ~= newUpgradeLevel then
				local warning = string.format("Server reported upgrade level %d while target was %d.", newUpgradeLevel, pending.target);
				DC.Debug(warning);
				print("|cffffa500Warning:|r " .. warning .. " Refreshing data from server.");
			end

			-- Play celebration and refresh visuals
			DarkChaos_ItemUpgrade_PlayCelebration();

			local itemLink = DC.currentItem.link or DC.currentItem.name or "item";
			local maxUpgrade = DC.currentItem.maxUpgrade or DC.MAX_UPGRADE_LEVEL;
			print(string.format("|cff00ff00Item upgraded to level %d/%d:|r %s", DC.currentItem.currentUpgrade or 0, maxUpgrade, itemLink));
			if totals.tokens > 0 or totals.essence > 0 then
				local parts = {};
				if totals.tokens > 0 then
					table.insert(parts, string.format("%d Tokens", totals.tokens));
				end
				if totals.essence > 0 then
					table.insert(parts, string.format("%d Essence", totals.essence));
				end
				print(string.format("|cff00ff00Spent:|r %s", table.concat(parts, " and ")));
			end
		end

		DC.pendingUpgrade = nil;
		DarkChaos_ItemUpgrade_RequestCurrencies();
		DarkChaos_ItemUpgrade_RequestItemInfo();
		
		PlaySound("AuctionWindowClose");
		DC.Debug("SUCCESS received: guid="..tostring(itemGUID).." newLevel="..tostring(newLevel));
		print("|cff00ff00Item upgraded successfully!|r");
		return;
	end
	
	-- DCUPGRADE_ERROR response
	-- Format from server: "DCUPGRADE_ERROR:<error_message>"
	if string.find(message, "^DCUPGRADE_ERROR") then
		local _, _, errorMsg = string.find(message, "DCUPGRADE_ERROR:(.+)");
		print("|cffff0000Upgrade failed:|r " .. (errorMsg or "Unknown error"));
		SetButtonEnabled(DarkChaos_ItemUpgradeFrame.UpgradeButton, true);
		DC.pendingUpgrade = nil;
		DC.Debug("ERROR received: "..tostring(errorMsg));
		local request = DarkChaos_ItemUpgrade_CompleteQuery();
		if request then
			for _, context in ipairs(request.contexts or {}) do
				if context.type == "tooltip" then
					DarkChaos_ItemUpgrade_HandleTooltipContext(context, nil, errorMsg or "Unknown error");
				end
			end
			request.contexts = nil;
		end
		return;
	end
end

--[[=====================================================
	DEBUG LOGGING
=======================================================]]

function DC.Debug(msg)
	if not msg then return end
	if not (DC_ItemUpgrade_Settings and DC_ItemUpgrade_Settings.debug) then return end

	local text = tostring(msg);
	if DC.logFrame then
		DC.logFrame:AddMessage(text, 0.4, 0.9, 1.0);
	elseif DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[DC-Upgrade]|r " .. text);
	end
end

--[[=====================================================
	UPGRADE CELEBRATION
=======================================================]]

function DarkChaos_ItemUpgrade_PlayCelebration()
	local frame = DarkChaos_ItemUpgradeFrame;
	if not frame then return end

	DC.upgradeAnimationTime = 2.0; -- seconds

	if frame.RightTooltip and frame.RightTooltip.UpgradeGlow then
		frame.RightTooltip.UpgradeGlow:Show();
		frame.RightTooltip.UpgradeGlow:SetAlpha(1);
	end

	if DC.currentItem then
		local nextLevel = DC.currentItem.currentUpgrade + 1;
		local maxLevel = DC.currentItem.maxUpgrade or DC.MAX_UPGRADE_LEVEL;
		DC.targetUpgradeLevel = math.min(nextLevel, maxLevel);
	end

	DarkChaos_ItemUpgrade_UpdateUI();
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
		
		-- Add item name + detail lines
		button.name = button:CreateFontString(nil, "OVERLAY", "GameFontNormal");
		button.name:SetPoint("TOPLEFT", button, "TOPRIGHT", 6, -2);
		button.name:SetWidth(210);
		button.name:SetJustifyH("LEFT");

		button.detail = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
		button.detail:SetPoint("TOPLEFT", button.name, "BOTTOMLEFT", 0, -2);
		button.detail:SetWidth(210);
		button.detail:SetJustifyH("LEFT");
		button.detail:SetTextColor(0.75, 0.75, 0.75);
	end
end

function DarkChaos_ItemBrowser_OnShow(self)
	DarkChaos_ItemBrowser_Update();
end

function DarkChaos_ItemBrowser_Update()
	-- Scan bags for upgradeable items
	itemBrowserList = {};

	for _, slotID in ipairs(EQUIPMENT_SLOTS) do
		local link = GetInventoryItemLink("player", slotID);
		if link then
			local name, _, quality = GetItemInfo(link);
			if quality and quality >= 2 then
				local serverBag = GetServerBagFromClient(BAG_EQUIPPED);
				local serverSlot = GetServerSlotFromClient(BAG_EQUIPPED, slotID);
				table.insert(itemBrowserList, {
					bag = BAG_EQUIPPED,
					serverBag = serverBag,
					slot = slotID,
					serverSlot = serverSlot,
					link = link,
					name = name,
					quality = quality,
					isEquipped = true,
				});
			end
		end
	end

	for bag = BAG_BACKPACK, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot);
			if link then
				local name, _, quality = GetItemInfo(link);
				-- Only show quality 2+ (uncommon and above)
				if quality and quality >= 2 then
					local serverBag = GetServerBagFromClient(bag);
					local serverSlot = GetServerSlotFromClient(bag, slot);
					table.insert(itemBrowserList, {
						bag = bag,
						serverBag = serverBag,
						slot = slot,
						serverSlot = serverSlot,
						link = link,
						name = name,
						quality = quality,
						isEquipped = false,
					});
				end
			end
		end
	end
	
	-- Sort by quality (descending)
	table.sort(itemBrowserList, function(a, b)
		if a.isEquipped ~= b.isEquipped then
			return a.isEquipped and not b.isEquipped;
		end
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
			local texture = GetItemTextureForLocation(item.bag, item.slot, item.link);
			local info = GetItemTooltipInfo(item.link);
			
			SetItemButtonTexture(button, texture);
			SetItemButtonQuality_335(button, item.quality);
			button.name:SetText(item.name or "Unknown Item");
			
			local color = DC.ITEM_QUALITY_COLORS[item.quality] or DC.ITEM_QUALITY_COLORS[1];
			button.name:SetTextColor(color.r, color.g, color.b);
			
			local detailPrefix = item.isEquipped and "(Equipped) " or "";
			if info then
				button.detail:SetText(string.format("%sItem Level %d   Upgrade %d/%d", detailPrefix, info.ilevel or 0, info.upgrade or 0, info.max or DC.MAX_UPGRADE_LEVEL));
			else
				button.detail:SetText(string.format("%sItem Level --   Upgrade --", detailPrefix));
			end
			button.detail:Show();

			button.itemData = item;
			button:Show();
		else
			if button.detail then
				button.detail:Hide();
			end
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
	INITIALIZATION & COMMANDS
=======================================================]]

local function ToggleDebugFrame()
	if not DarkChaos_ItemUpgrade_DebugFrame then return end
	if DarkChaos_ItemUpgrade_DebugFrame:IsShown() then
		DarkChaos_ItemUpgrade_DebugFrame:Hide();
	else
		DarkChaos_ItemUpgrade_DebugFrame:Show();
	end
end

function DarkChaos_ItemUpgrade_OnLoad(self)
	self:RegisterEvent("PLAYER_LOGIN");
	self:RegisterEvent("CHAT_MSG_SAY");
	self:RegisterEvent("CHAT_MSG_WHISPER");
	self:RegisterEvent("CHAT_MSG_SYSTEM");
	self:RegisterEvent("BAG_UPDATE");
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
	self:RegisterEvent("UNIT_INVENTORY_CHANGED");

	self:SetMovable(true);
	self:EnableMouse(true);
	self:RegisterForDrag("LeftButton");
	self:SetScript("OnDragStart", function(frame)
		frame:StartMoving();
	end);
	self:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing();
	end);

	if self.portrait then
		self.portrait:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-REWARDS");
	end

	local dropdown = self.Dropdown;
	if dropdown then
		UIDropDownMenu_SetWidth(dropdown, 150);
		UIDropDownMenu_SetButtonWidth(dropdown, 160);
		UIDropDownMenu_Initialize(dropdown, DarkChaos_ItemUpgrade_Dropdown_Initialize);
	end

	DC_ItemUpgrade_Settings = DC_ItemUpgrade_Settings or {};
	if DC_ItemUpgrade_Settings.debug == nil then
		DC_ItemUpgrade_Settings.debug = false;
	end

	DC.logFrame = DarkChaos_ItemUpgrade_DebugFrame and DarkChaos_ItemUpgrade_DebugFrame.Scroll or nil;
	if DC.logFrame then
		DC.logFrame:SetMaxLines(1000);
		DC.logFrame:SetFading(false);
	end

	if DarkChaos_ItemUpgrade_DebugFrame then
		local debugFrame = DarkChaos_ItemUpgrade_DebugFrame;
		debugFrame:SetMovable(true);
		debugFrame:EnableMouse(true);
		debugFrame:RegisterForDrag("LeftButton");
		debugFrame:SetScript("OnDragStart", function(frame)
			frame:StartMoving();
		end);
		debugFrame:SetScript("OnDragStop", function(frame)
			frame:StopMovingOrSizing();
		end);
		if not DC_ItemUpgrade_Settings.debug then
			debugFrame:Hide();
		else
			debugFrame:Show();
		end
	end

	DC.arrowAnimationTime = 0;
	DC.glowAnimationTime = 0;
	DC.upgradeAnimationTime = 0;
	DC.currentItem = nil;
	DC.targetUpgradeLevel = 1;

	if not SlashCmdList then SlashCmdList = {}; end
	SLASH_DCUPGRADE1 = "/dcupgrade";
	SLASH_DCUPGRADE2 = "/dcup";
	SlashCmdList["DCUPGRADE"] = function(msg)
		msg = (msg or ""):lower();
		if msg == "debug" then
			DC_ItemUpgrade_Settings.debug = not DC_ItemUpgrade_Settings.debug;
			if DC_ItemUpgrade_Settings.debug then
				print("|cff00ff00Item Upgrade debug logging enabled.|r");
				if DarkChaos_ItemUpgrade_DebugFrame then
					DarkChaos_ItemUpgrade_DebugFrame:Show();
				end
			else
				print("|cffff0000Item Upgrade debug logging disabled.|r");
				if DarkChaos_ItemUpgrade_DebugFrame then
					DarkChaos_ItemUpgrade_DebugFrame:Hide();
				end
			end
			return;
		elseif msg == "log" then
			ToggleDebugFrame();
			return;
		end

		if self:IsShown() then
			self:Hide();
		else
			self:Show();
		end
	end;

	print("|cff00ff00[DC-ItemUpgrade]|r Type |cffffcc00/dcupgrade|r to open the Item Upgrade interface. Use |cffffcc00/dcupgrade debug|r to toggle logging.");

	if GameTooltip then
		GameTooltip:HookScript("OnTooltipCleared", DarkChaos_ItemUpgrade_ResetTooltip);
		if type(hooksecurefunc) == "function" then
			hooksecurefunc(GameTooltip, "SetInventoryItem", DarkChaos_ItemUpgrade_OnTooltipSetInventoryItem);
			hooksecurefunc(GameTooltip, "SetBagItem", DarkChaos_ItemUpgrade_OnTooltipSetBagItem);
			if GameTooltip.SetGuildBankItem then
				hooksecurefunc(GameTooltip, "SetGuildBankItem", DarkChaos_ItemUpgrade_OnTooltipSetGuildBankItem);
			end
		end
	end

	if type(hooksecurefunc) == "function" then
		for _, shoppingTooltip in ipairs({ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3}) do
			if shoppingTooltip then
				shoppingTooltip:HookScript("OnTooltipCleared", DarkChaos_ItemUpgrade_ResetTooltip);
				hooksecurefunc(shoppingTooltip, "SetInventoryItem", DarkChaos_ItemUpgrade_OnTooltipSetInventoryItem);
				hooksecurefunc(shoppingTooltip, "SetBagItem", DarkChaos_ItemUpgrade_OnTooltipSetBagItem);
			end
		end
	end

	if ItemRefTooltip then
		ItemRefTooltip:HookScript("OnTooltipCleared", DarkChaos_ItemUpgrade_ResetTooltip);
	end

	DarkChaos_ItemUpgrade_UpdateUI();
end

function DarkChaos_ItemUpgrade_OnShow(self)
	PlaySound("igCharacterInfoOpen");
	DC.arrowAnimationTime = 0;
	DC.glowAnimationTime = 0;

	if self.Dropdown then
		UIDropDownMenu_Initialize(self.Dropdown, DarkChaos_ItemUpgrade_Dropdown_Initialize);
	end

	DarkChaos_ItemUpgrade_RequestCurrencies();
	DarkChaos_ItemUpgrade_UpdateUI();
end
