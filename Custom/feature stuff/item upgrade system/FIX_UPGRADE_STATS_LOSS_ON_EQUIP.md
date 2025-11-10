# 🔴 CRITICAL: Upgrade Stats Lost When Item Equipped

## Problem Analysis

**Symptoms:**
1. Item shows "Upgrade Level 8/15" in backpack ✅
2. Item shows "Upgrade Level 0/15" when equipped ❌
3. Stats don't show upgraded values on character sheet ❌

**Root Causes:**
1. **Addon Cache Issue**: Upgrade data in cache is not being fetched for equipped items
2. **Enchantment Application**: Stat enchantments are not being applied when items are equipped
3. **Event Hook Missing**: OnPlayerEquip may not be firing or cache not being updated

---

## Solution: Two-Part Fix

### PART 1: Fix the OnPlayerEquip Hook

The issue is in `ItemUpgradeStatApplication.cpp` - the `OnPlayerEquip` event might not be firing correctly. We need to add additional hooks:

**File**: `src/server/scripts/DC/ItemUpgrades/ItemUpgradeStatApplication.cpp`

**Change**: Add hooks for bag/bank operations:

```cpp
// Added new hooks (find this section and verify it exists)
class ItemUpgradeStatHook : public PlayerScript
{
public:
    ItemUpgradeStatHook() : PlayerScript("ItemUpgradeStatHook") {}
    
    // Called when item equipped
    void OnPlayerEquip(Player* player, Item* item, uint8 bag, uint8 slot, bool update) override
    {
        if (!player || !item)
            return;
        
        // CRITICAL: Must refresh cache BEFORE applying enchant
        uint32 item_guid = item->GetGUID().GetCounter();
        UpgradeManager* mgr = GetUpgradeManager();
        if (mgr)
        {
            // Force reload from database
            mgr->ClearItemCache(item_guid);
            mgr->GetItemUpgradeState(item_guid);  // Reload
        }
        
        ApplyUpgradeEnchant(player, item);
    }
    
    // Called when item moved to equipped slot from bag
    void OnPlayerItemMoved(Player* player, Item* item, uint8 /*previousContainer*/, 
                          uint8 /*previousSlot*/, bool /*itemAdded*/) override
    {
        if (!player || !item)
            return;
        
        // Check if item is now in an equipment slot
        uint8 slot = player->FindEquipSlot(item, INVALID_SLOT, false);
        if (slot != INVALID_SLOT)
        {
            OnPlayerEquip(player, item, INVENTORY_SLOT_BAG_0, slot, true);
        }
    }
    
    void OnPlayerLogin(Player* player) override
    {
        if (!player)
            return;
        
        UpgradeManager* mgr = GetUpgradeManager();
        if (!mgr)
            return;
        
        // Apply upgrade enchants to all equipped items on login
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (item)
            {
                // Force cache refresh
                mgr->ClearItemCache(item->GetGUID().GetCounter());
                ApplyUpgradeEnchant(player, item);
            }
        }
        
        LOG_DEBUG("scripts", "ItemUpgrade: Reapplied enchants on login for player {}", 
                 player->GetGUID().GetCounter());
    }
    
    // NEW: Called when item unequipped  
    void OnPlayerUnequip(Player* player, Item* item, uint8 /*bag*/, uint8 /*slot*/) override
    {
        if (!player || !item)
            return;
        
        RemoveUpgradeEnchant(player, item);
    }
};
```

### PART 2: Fix Addon Cache for Equipped Items

**File**: `Custom/Client addons needed/DC-ItemUpgrade/DarkChaos_ItemUpgrade_Retail.lua`

**Add this function** to the addon to handle cache invalidation:

```lua
-- Hook into WoW events to update upgrade cache when items move
function DC_SetupEquipmentCaching()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("BAG_UPDATE")
    frame:RegisterEvent("ITEM_LOCK_CHANGED")
    frame:RegisterEvent("EQUIPMENT_SETS_CHANGED")
    
    frame:SetScript("OnEvent", function(self, event, ...)
        -- When item moved between bags/equipment
        if event == "BAG_UPDATE" then
            local bag = ...
            -- Item was moved, check if it's equipped
            for slot = EQUIPMENT_SLOT_START, EQUIPMENT_SLOT_END do
                local item = GetInventoryItemLink("player", slot)
                if item then
                    local itemId = GetInventoryItemID("player", slot)
                    -- Request server to check upgrade status
                    C_ChatInfo.SendAddonMessage("DCUPGRADE", "CHECK_EQUIPPED:" .. itemId, "WHISPER", UnitName("player"))
                end
            end
        end
    end)
end

-- Initialize on addon load
DC_SetupEquipmentCaching()
```

### PART 3: Server-Side Addon Handler Update

**File**: `src/server/scripts/DC/ItemUpgrades/ItemUpgradeAddonHandler.cpp`

**Add handler** for the CHECK_EQUIPPED message:

```cpp
// In ItemUpgradeAddonHandler addon message processing
if (msg == "CHECK_EQUIPPED")
{
    // Parse item ID
    uint32 itemId = std::stoul(params);
    
    // Find item GUID from player inventory
    for (uint8 bag = EQUIPMENT_SLOT_START; bag < EQUIPMENT_SLOT_END; ++bag)
    {
        Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, bag);
        if (item && item->GetEntry() == itemId)
        {
            uint32 itemGUID = item->GetGUID().GetCounter();
            
            // Force refresh upgrade data
            UpgradeManager* mgr = GetUpgradeManager();
            if (mgr)
            {
                ItemUpgradeState* state = mgr->GetItemUpgradeState(itemGUID);
                if (state && state->upgrade_level > 0)
                {
                    // Apply enchants
                    ItemUpgradeStatApplication::ApplyUpgradeEnchant(player, item);
                    return;
                }
            }
        }
    }
}
```

---

## Quick Deployment Checklist

- [ ] 1. Verify `OnPlayerEquip` exists in ItemUpgradeStatApplication.cpp
- [ ] 2. Add cache clear calls before ApplyUpgradeEnchant
- [ ] 3. Add OnPlayerUnequip hook to RemoveUpgradeEnchant
- [ ] 4. Update addon with DC_SetupEquipmentCaching function
- [ ] 5. Rebuild AzerothCore
- [ ] 6. Test: Equip upgraded item → Should show correct level and stats
- [ ] 7. Test: Move item between bags → Stats should persist
- [ ] 8. Test: Unequip → Stats should disappear

---

## Expected Results After Fix

**Before:**
```
Backpack:  "Upgrade Level 8/15" ✅ + green stats ✅
Equipped:  "Upgrade Level 0/15" ❌ + no green stats ❌
```

**After:**
```
Backpack:  "Upgrade Level 8/15" ✅ + green stats ✅
Equipped:  "Upgrade Level 8/15" ✅ + green stats ✅
Stats Tab: +69 Stamina (upgraded) ✅
```

---

## Debug Information

If issue persists, add these logs to verify cache is working:

```cpp
// In ApplyUpgradeEnchant
LOG_INFO("scripts", "ItemUpgrade DEBUG: Applying enchant for item {} - tier={}, level={}, state={}",
         item_guid, state->tier_id, state->upgrade_level, 
         state ? "found" : "NOT FOUND");

// In OnPlayerEquip
LOG_INFO("scripts", "ItemUpgrade DEBUG: Equip event fired - item={}, player={}", 
         item->GetGUID().GetCounter(), player->GetGUID().GetCounter());
```

Check server logs with: `tail -f worldserver.log | grep "ItemUpgrade DEBUG"`
