--[[
	DC-ItemUpgrade - Cache Module
	Item state pooling, batch query system, and item scanning
--]]

local DC = DarkChaos_ItemUpgrade;

--[[=====================================================
	MEMORY POOLING
=======================================================]]

-- Memory pooling for ItemUpgradeState objects
DC.itemStatePool = DC.itemStatePool or {};
DC.itemStatePoolSize = DC.itemStatePoolSize or 0;
DC.maxPoolSize = DC.maxPoolSize or 50;

-- Optimized item scanning cache
DC.itemScanCache = DC.itemScanCache or {};
DC.itemScanCacheTime = DC.itemScanCacheTime or 0;
DC.itemScanCacheLifetime = DC.itemScanCacheLifetime or 5; -- 5 seconds cache lifetime

-- Batch query system
DC.batchQueryQueue = DC.batchQueryQueue or {};
DC.batchQueryTimer = DC.batchQueryTimer or 0;
DC.batchQueryDelay = DC.batchQueryDelay or 0.1; -- 100ms delay for batching

-- Runtime caches
DC.itemUpgradeCache = DC.itemUpgradeCache or {};
DC.itemLocationCache = DC.itemLocationCache or {};
DC.itemTooltipCache = DC.itemTooltipCache or {};
DC.queryQueueList = DC.queryQueueList or {};
DC.queryQueueMap = DC.queryQueueMap or {};
DC.queryInFlight = DC.queryInFlight or nil;

--[[=====================================================
	BAG CONSTANTS
=======================================================]]

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

DC.EQUIPMENT_SLOTS = EQUIPMENT_SLOTS;
DC.BAG_BACKPACK = BAG_BACKPACK;
DC.BAG_BANK = BAG_BANK;
DC.BAG_EQUIPPED = BAG_EQUIPPED;

--[[=====================================================
	HELPER FUNCTIONS
=======================================================]]

function DC.IsEquippedBag(bag)
	return bag == BAG_EQUIPPED;
end

function DC.GetServerSlotFromClient(bag, slot)
	-- For equipped items (bag 255), convert from client 1-indexed to server 0-indexed
	-- Client: HEAD=1, NECK=2, SHOULDERS=3, BODY=4, CHEST=5, etc.
	-- Server: HEAD=0, NECK=1, SHOULDERS=2, BODY=3, CHEST=4, etc.
	if DC.IsEquippedBag(bag) then
		return math.max(0, (slot or 1) - 1);  -- Subtract 1 to convert to 0-indexed
	end
	
	-- For bag items, subtract 1 to convert from 1-indexed to 0-indexed
	local normalizedSlot = math.max(0, (slot or 1) - 1);
	if bag == BAG_BANK then
		local BANK_SLOT_ITEM_START = _G.BANK_SLOT_ITEM_START or 39;
		return BANK_SLOT_ITEM_START + normalizedSlot;
	end
	return normalizedSlot;
end

function DC.GetServerBagFromClient(bag)
	if DC.IsEquippedBag(bag) then
		return BAG_EQUIPPED;
	end
	if bag == BAG_BANK then
		return BAG_EQUIPPED;
	end
	return bag;
end

function DC.BuildLocationKey(bag, slot)
	return string.format("%d:%d", bag or -1, slot or -1);
end

--[[=====================================================
	ITEM STATE POOLING
=======================================================]]

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

--[[=====================================================
	BATCH QUERY PROCESSING
=======================================================]]

function DC.ProcessBatchQueries()
	if #DC.batchQueryQueue == 0 then
		return;
	end

	DC.Debug(string.format("ProcessBatchQueries: flushing %d pending requests (inFlight=%s, queued=%d)",
		#DC.batchQueryQueue,
		tostring(DC.queryInFlight ~= nil),
		#DC.queryQueueList));

	-- Move pending requests into the sequential queue
	for _, request in ipairs(DC.batchQueryQueue) do
		table.insert(DC.queryQueueList, request);
	end

	DC.batchQueryQueue = {};

	if not DC.queryInFlight then
		DarkChaos_ItemUpgrade_StartNextQuery();
	end
end

--[[=====================================================
	ITEM SCANNING WITH CACHING
=======================================================]]

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
			local name, _, quality = GetItemInfo(link);
			if quality and quality >= 2 then -- Only uncommon and above
				local serverBag = DC.GetServerBagFromClient(BAG_EQUIPPED);
				local serverSlot = DC.GetServerSlotFromClient(BAG_EQUIPPED, slotID);
				local key = DC.BuildLocationKey(serverBag, serverSlot);
				
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
				local name, _, quality = GetItemInfo(link);
				if quality and quality >= 2 then -- Only uncommon and above
					local serverBag = DC.GetServerBagFromClient(bag);
					local serverSlot = DC.GetServerSlotFromClient(bag, slot);
					local key = DC.BuildLocationKey(serverBag, serverSlot);
					
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

--[[=====================================================
	CACHE MANAGEMENT
=======================================================]]

function DC.InvalidateCachedItemData()
	DC.itemTooltipCache = {};
	DC.itemScanCache = {};
	DC.itemScanCacheTime = 0;
end

function DC.ClearAllCaches()
	DC.itemUpgradeCache = {};
	DC.itemLocationCache = {};
	DC.itemTooltipCache = {};
	DC.itemScanCache = {};
	DC.itemScanCacheTime = 0;
	DC.Debug("All caches cleared");
end
