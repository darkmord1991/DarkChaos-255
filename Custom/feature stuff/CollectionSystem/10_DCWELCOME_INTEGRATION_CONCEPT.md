# DC-Welcome Integration & Advanced Collection Features

**Component:** DC-Welcome Addon Integration  
**Related Documents:** 00-09_*.md  
**Questions Addressed:**
1. Where to add button in DC-Welcome to open Collection addon?
2. Can mount speed buff be applied via collection item?
3. Where to get data for mounts, pets, etc.?
4. Can characters summon heirlooms from account-wide collection?

---

## 1. DC-Welcome Button Integration

### Current DC-Welcome Structure

DC-Welcome has an **AddonsPanel** (`AddonsPanel.lua`) that already serves as the central hub for all DC addons. This is the ideal location for the Collection button.

### Proposed Integration: Add to RegisteredAddons

Add the Collection System to `DCWelcome.RegisteredAddons` in [AddonsPanel.lua](../../Client%20addons%20needed/DC-Welcome/AddonsPanel.lua):

```lua
-- Add to DCWelcome.RegisteredAddons table in AddonsPanel.lua
{
    id = "dc-collections",
    name = "Collections",
    description = "Mount Journal, Pet Collection, Transmog, Toys, and Heirlooms",
    icon = "Interface\\Icons\\INV_Misc_Coin_02",  -- Or custom collection icon
    color = {0.9, 0.7, 0.2},  -- Gold/amber for collections
    category = "Utility",
    minLevel = 1,
    openCommand = "/dccollection",
    settingsCommand = "/dccollection settings",
    
    -- Sub-buttons for quick access to specific tabs
    hasSecondButton = true,
    secondButtonName = "Mounts",
    secondButtonIcon = "Interface\\Icons\\Ability_Mount_RidingHorse",
    secondButtonFunc = function()
        if DCCollection and DCCollection.OpenTab then
            DCCollection:OpenTab("mounts")
        elseif SlashCmdList["DCCOLLECTION"] then
            SlashCmdList["DCCOLLECTION"]("mounts")
        end
    end,
    
    openFunc = function()
        if DCCollection and DCCollection.Toggle then
            DCCollection:Toggle()
        elseif SlashCmdList["DCCOLLECTION"] then
            SlashCmdList["DCCOLLECTION"]("")
        else
            DCWelcome.Print("Collection addon not loaded")
        end
    end,
    
    settingsFunc = function()
        if DCCollection and DCCollection.OpenSettings then
            DCCollection:OpenSettings()
        elseif SlashCmdList["DCCOLLECTION"] then
            SlashCmdList["DCCOLLECTION"]("settings")
        end
    end,
    
    isLoaded = function()
        return DCCollection ~= nil or SlashCmdList["DCCOLLECTION"] ~= nil
    end,
},
```

### Alternative: Dedicated "Collections" Button Row

For higher visibility, add a dedicated row in the AddonsPanel:

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DC ADDONS HUB                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ 📚 COLLECTIONS                                                 │ │
│  │ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────────┐│ │
│  │ │ Mounts  │ │  Pets   │ │Transmog │ │  Toys   │ │ Heirlooms   ││ │
│  │ │  (47)   │ │  (23)   │ │  (156)  │ │  (12)   │ │   (8/15)    ││ │
│  │ └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────────┘│ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  [Mythic+ Suite]    [Leaderboards]    [Item Upgrades]    ...        │
└─────────────────────────────────────────────────────────────────────┘
```

### Minimap Button Quick Access

The existing MinimapButton can have a right-click menu option:

```lua
-- In MinimapButton.lua, add to the right-click dropdown menu:
info.text = "Collections"
info.icon = "Interface\\Icons\\INV_Misc_Coin_02"
info.func = function()
    if DCCollection and DCCollection.Toggle then
        DCCollection:Toggle()
    end
end
UIDropDownMenu_AddButton(info)
```

---

## 2. Mount Speed Buff via Collection Item ✅ FEASIBLE

### Analysis: How Mount Speed Works in 3.3.5a

**Existing Mount Speed Items:**
| Item | Spell Effect | Speed Bonus |
|------|-------------|-------------|
| Carrot on a Stick | `SPELL_CARROT_ON_A_STICK_EFFECT (48402)` | +3% |
| Riding Crop | `SPELL_RIDING_CROP_EFFECT (48383)` | +10% |
| Mithril Spurs | `SPELL_MITHRIL_SPURS_EFFECT (59916)` | +4% |

**Spell Aura Used:** `SPELL_AURA_MOD_INCREASE_MOUNTED_SPEED` / `SPELL_AURA_MOD_INCREASE_MOUNTED_FLIGHT_SPEED`

### Implementation: Collection Achievement Mount Speed Bonus

**Concept:** Unlock permanent mount speed buffs by collecting mounts!

```
Milestone Rewards:
├── Collect 25 mounts  → +2% Mount Speed
├── Collect 50 mounts  → +3% Mount Speed (stacks to +5%)
├── Collect 100 mounts → +3% Mount Speed (stacks to +8%)
└── Collect 150 mounts → +2% Mount Speed (stacks to +10% total)
```

### Server-Side Implementation

```cpp
// In dc_addon_collection.cpp

// Custom spell IDs for mount speed buffs (add to spell_dbc)
enum CollectionMountSpeedSpells
{
    SPELL_COLLECTOR_MOUNT_SPEED_1 = 300500,  // +2% at 25 mounts
    SPELL_COLLECTOR_MOUNT_SPEED_2 = 300501,  // +3% at 50 mounts
    SPELL_COLLECTOR_MOUNT_SPEED_3 = 300502,  // +3% at 100 mounts
    SPELL_COLLECTOR_MOUNT_SPEED_4 = 300503,  // +2% at 150 mounts
};

// Apply mount speed based on collection count
void ApplyMountCollectionBonus(Player* player, uint32 mountCount)
{
    // Remove all collection speed buffs first
    player->RemoveAura(SPELL_COLLECTOR_MOUNT_SPEED_1);
    player->RemoveAura(SPELL_COLLECTOR_MOUNT_SPEED_2);
    player->RemoveAura(SPELL_COLLECTOR_MOUNT_SPEED_3);
    player->RemoveAura(SPELL_COLLECTOR_MOUNT_SPEED_4);
    
    // Apply based on milestones
    if (mountCount >= 25)
        player->AddAura(SPELL_COLLECTOR_MOUNT_SPEED_1, player);
    if (mountCount >= 50)
        player->AddAura(SPELL_COLLECTOR_MOUNT_SPEED_2, player);
    if (mountCount >= 100)
        player->AddAura(SPELL_COLLECTOR_MOUNT_SPEED_3, player);
    if (mountCount >= 150)
        player->AddAura(SPELL_COLLECTOR_MOUNT_SPEED_4, player);
}

// Hook into player login
class CollectionMountSpeedPlayerScript : public PlayerScript
{
public:
    void OnLogin(Player* player, bool /*firstLogin*/) override
    {
        uint32 mountCount = GetAccountMountCount(player->GetSession()->GetAccountId());
        ApplyMountCollectionBonus(player, mountCount);
    }
};
```

### DBC Entry for Speed Spell

```sql
-- Add to spell_dbc table
INSERT INTO `spell_dbc` (`Id`, `EquippedItemClass`, `SpellName`, `Effect1`, `EffectApplyAuraName1`, `EffectBasePoints1`) VALUES
(300500, -1, 'Mount Collector I', 6, 232, 2),   -- SPELL_EFFECT_APPLY_AURA, SPELL_AURA_MOD_INCREASE_MOUNTED_SPEED, +2%
(300501, -1, 'Mount Collector II', 6, 232, 3),  -- +3%
(300502, -1, 'Mount Collector III', 6, 232, 3), -- +3%
(300503, -1, 'Mount Collector IV', 6, 232, 2);  -- +2%
```

### Client Display

Show in Collection UI tooltip:
```
┌─────────────────────────────────────────────────┐
│ MOUNT COLLECTION BONUSES                        │
│                                                 │
│ ✓ 25 Mounts  - Mount Speed +2%                  │
│ ✓ 50 Mounts  - Mount Speed +5% (cumulative)     │
│ ○ 100 Mounts - Mount Speed +8% (47/100)         │
│ ○ 150 Mounts - Mount Speed +10% (47/150)        │
└─────────────────────────────────────────────────┘
```

### Alternative: Mount Speed as Lootable/Purchasable Items

Instead of (or in addition to) automatic bonuses, create **items that teach mount speed buffs**:

```sql
-- Mount speed buff items (learnable permanent spells)
INSERT INTO `item_template` 
(entry, class, subclass, name, displayid, Quality, BuyPrice, SellPrice, 
 spellid_1, spelltrigger_1, spellcharges_1, Flags, description) VALUES

-- Tier 1: Drops from dungeons, buyable with tokens
(300600, 0, 8, 'Riding Saddle Enhancement I', 63214, 2, 0, 0,
 300510, 0, -1, 64, 'Permanently increases mounted speed by 2%.'),

-- Tier 2: Rare drop or high token cost
(300601, 0, 8, 'Riding Saddle Enhancement II', 63215, 3, 0, 0,
 300511, 0, -1, 64, 'Permanently increases mounted speed by 3%. Requires Enhancement I.'),

-- Tier 3: Raid boss or collection shop exclusive
(300602, 0, 8, 'Riding Saddle Enhancement III', 63216, 4, 0, 0,
 300512, 0, -1, 64, 'Permanently increases mounted speed by 3%. Requires Enhancement II.'),

-- Tier 4: Legendary - Top collector reward
(300603, 0, 8, 'Master Rider\'s Blessing', 63217, 5, 0, 0,
 300513, 0, -1, 64, 'Permanently increases mounted speed by 2%. Requires Enhancement III.');

-- The spells these items teach (permanent passive auras)
INSERT INTO `spell_dbc` (`Id`, `SpellName`, `Effect1`, `EffectApplyAuraName1`, `EffectBasePoints1`, `Attributes`) VALUES
(300510, 'Saddle Enhancement I', 6, 232, 2, 0x00000400),   -- PASSIVE
(300511, 'Saddle Enhancement II', 6, 232, 3, 0x00000400),
(300512, 'Saddle Enhancement III', 6, 232, 3, 0x00000400),
(300513, 'Master Rider', 6, 232, 2, 0x00000400);
```

**Acquisition Sources:**
| Item | Source | Cost/Drop |
|------|--------|-----------|
| Enhancement I | Collection Shop / Dungeon Boss | 500 Collection Tokens |
| Enhancement II | Collection Shop / Raid Boss | 1500 Collection Tokens |
| Enhancement III | Raid Boss / Collection Achievement | 50+ mounts collected |
| Master Rider's Blessing | Collection Shop Exclusive | 100+ mounts + 5000 Tokens |

---

## 3. Collection Shop System

### Concept: In-Game Shop for Collectibles

A dedicated shop tab within the Collection UI where players can purchase mounts, pets, toys, and bonuses using various currencies.

### Shop UI Mockup

```
┌─────────────────────────────────────────────────────────────────────┐
│ COLLECTION SHOP                           💰 1,250 Collection Tokens │
│                                           🔮 45 Collector's Emblems  │
├─────────────────────────────────────────────────────────────────────┤
│ [All] [Mounts] [Pets] [Toys] [Bonuses] [Bundles]                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ 🐎 Swift Collector's Steed                    💰 2,000       │    │
│  │ ────────────────────────────────────────────────────────    │    │
│  │ Epic Ground Mount (100%)                                    │    │
│  │ "Awarded to dedicated collectors"                           │    │
│  │                                           [BUY]             │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ ⚡ Riding Saddle Enhancement I               💰 500          │    │
│  │ ────────────────────────────────────────────────────────    │    │
│  │ Permanently increases mounted speed by 2%                   │    │
│  │ Account-wide                                                │    │
│  │                                           [BUY]             │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ 🐾 Miniature Collector                       🔮 25           │    │
│  │ ────────────────────────────────────────────────────────    │    │
│  │ Companion Pet - A tiny treasure hunter                      │    │
│  │ Requires: 25 pets collected                                 │    │
│  │                                    [LOCKED - 12/25 pets]    │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Database Schema

```sql
-- Shop item definitions
CREATE TABLE IF NOT EXISTS `dc_collection_shop` (
    `shop_id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `item_type` ENUM('mount', 'pet', 'toy', 'heirloom', 'bonus', 'bundle') NOT NULL,
    `reward_type` ENUM('item', 'spell', 'title', 'currency') NOT NULL DEFAULT 'item',
    `reward_id` INT UNSIGNED NOT NULL COMMENT 'item_id, spell_id, or title_id',
    `reward_count` INT UNSIGNED NOT NULL DEFAULT 1,
    
    -- Pricing (can use multiple currencies)
    `cost_tokens` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Collection Tokens',
    `cost_emblems` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Collectors Emblems (rare)',
    `cost_gold` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Gold in copper',
    
    -- Requirements
    `required_mounts` INT UNSIGNED DEFAULT NULL COMMENT 'Min mounts collected',
    `required_pets` INT UNSIGNED DEFAULT NULL COMMENT 'Min pets collected',
    `required_toys` INT UNSIGNED DEFAULT NULL COMMENT 'Min toys collected',
    `required_total` INT UNSIGNED DEFAULT NULL COMMENT 'Total collectibles',
    `required_achievement` INT UNSIGNED DEFAULT NULL COMMENT 'Achievement ID',
    `required_reputation` INT UNSIGNED DEFAULT NULL COMMENT 'Faction ID',
    `required_rep_standing` TINYINT UNSIGNED DEFAULT NULL COMMENT 'Standing level',
    
    -- Display
    `name` VARCHAR(100) NOT NULL,
    `description` TEXT,
    `icon` VARCHAR(255) DEFAULT NULL,
    `rarity` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `category` VARCHAR(50) DEFAULT 'General',
    `sort_order` INT UNSIGNED NOT NULL DEFAULT 0,
    
    -- Availability
    `is_available` TINYINT(1) NOT NULL DEFAULT 1,
    `available_from` DATETIME DEFAULT NULL COMMENT 'Limited time start',
    `available_until` DATETIME DEFAULT NULL COMMENT 'Limited time end',
    `max_purchases` INT UNSIGNED DEFAULT NULL COMMENT 'Limit per account',
    `stock_limit` INT UNSIGNED DEFAULT NULL COMMENT 'Server-wide limit',
    `current_stock` INT UNSIGNED DEFAULT NULL,
    
    KEY `idx_type` (`item_type`),
    KEY `idx_available` (`is_available`, `available_from`, `available_until`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Collection shop items';

-- Track purchases
CREATE TABLE IF NOT EXISTS `dc_collection_shop_purchases` (
    `purchase_id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `account_id` INT UNSIGNED NOT NULL,
    `shop_id` INT UNSIGNED NOT NULL,
    `character_id` INT UNSIGNED NOT NULL COMMENT 'Who made purchase',
    `purchase_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `cost_tokens` INT UNSIGNED NOT NULL DEFAULT 0,
    `cost_emblems` INT UNSIGNED NOT NULL DEFAULT 0,
    `cost_gold` INT UNSIGNED NOT NULL DEFAULT 0,
    
    KEY `idx_account` (`account_id`),
    KEY `idx_shop_item` (`shop_id`),
    FOREIGN KEY (`shop_id`) REFERENCES `dc_collection_shop`(`shop_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Currency table (account-wide)
CREATE TABLE IF NOT EXISTS `dc_collection_currency` (
    `account_id` INT UNSIGNED PRIMARY KEY,
    `tokens` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Collection Tokens',
    `emblems` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Collectors Emblems',
    `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### Sample Shop Data

```sql
-- Populate shop with items
INSERT INTO `dc_collection_shop` 
(item_type, reward_type, reward_id, cost_tokens, cost_emblems, required_mounts, name, description, rarity, category) VALUES

-- MOUNTS
('mount', 'spell', 800010, 5000, 0, NULL, 'Collector\'s Charger', 'A magnificent steed for dedicated collectors.', 4, 'Exclusive'),
('mount', 'spell', 800011, 10000, 50, 50, 'Gilded Collector\'s Drake', 'Only the most dedicated collectors can tame this beast.', 5, 'Exclusive'),

-- PETS
('pet', 'item', 300700, 500, 0, NULL, 'Tiny Treasure Goblin', 'A miniature loot enthusiast.', 2, 'Companions'),
('pet', 'item', 300701, 1500, 0, NULL, 'Collection Sprite', 'Helps find hidden collectibles.', 3, 'Companions'),
('pet', 'item', 300702, 3000, 25, 25, 'Phoenix Hatchling', 'A rare and beautiful companion.', 4, 'Exclusive'),

-- TOYS
('toy', 'item', 300800, 250, 0, NULL, 'Collector\'s Display Case', 'Show off your favorite mount.', 2, 'Toys'),
('toy', 'item', 300801, 750, 0, NULL, 'Pet Parade Banner', 'Summon all your pets at once!', 3, 'Toys'),

-- MOUNT SPEED BONUSES
('bonus', 'item', 300600, 500, 0, NULL, 'Riding Saddle Enhancement I', 'Permanently increases mounted speed by 2%.', 2, 'Bonuses'),
('bonus', 'item', 300601, 1500, 0, NULL, 'Riding Saddle Enhancement II', 'Mounted speed +3%. Requires Enhancement I.', 3, 'Bonuses'),
('bonus', 'item', 300602, 4000, 25, 50, 'Riding Saddle Enhancement III', 'Mounted speed +3%. Requires Enhancement II.', 4, 'Bonuses'),
('bonus', 'item', 300603, 0, 100, 100, 'Master Rider\'s Blessing', 'Mounted speed +2%. Ultimate collector reward.', 5, 'Bonuses'),

-- BUNDLES
('bundle', 'item', 300900, 2000, 0, NULL, 'Starter Collector Bundle', '5 random mounts + 3 random pets.', 3, 'Bundles'),
('bundle', 'item', 300901, 8000, 50, NULL, 'Premium Collector Bundle', '10 random mounts + 10 random pets + Enhancement I.', 4, 'Bundles');
```

### Currency Sources

```sql
-- How players earn Collection Tokens
-- (Stored for reference, actual implementation in server scripts)

/*
 * COLLECTION TOKEN SOURCES:
 * 
 * Daily:
 *   - First mount summoned: +5 tokens
 *   - First pet summoned: +5 tokens
 *   - Complete daily heroic: +10 tokens
 * 
 * Collection Milestones:
 *   - Every 10 mounts collected: +50 tokens
 *   - Every 10 pets collected: +50 tokens
 *   - Every 5 toys collected: +25 tokens
 * 
 * Weekly:
 *   - Clear any raid boss: +20 tokens each (cap 100/week)
 *   - Complete M+ key: +15 tokens each
 * 
 * Special:
 *   - First time collecting rare mount: +100 tokens
 *   - First time collecting legendary mount: +500 tokens
 *   - Season rewards
 * 
 * COLLECTOR'S EMBLEMS SOURCES (Rare):
 *   - Collect 50 mounts: +10 emblems
 *   - Collect 100 mounts: +25 emblems
 *   - Season end rewards: 5-50 emblems based on rank
 *   - World boss drops: 1-3 emblems (low chance)
 */
```

### Server-Side Purchase Handler

```cpp
// CMSG_SHOP_PURCHASE handler
void HandleShopPurchase(Player* player, uint32 shopId)
{
    uint32 accountId = player->GetSession()->GetAccountId();
    
    // 1. Get shop item
    QueryResult shopItem = WorldDatabase.Query(
        "SELECT * FROM dc_collection_shop WHERE shop_id = {} AND is_available = 1", shopId);
    if (!shopItem)
    {
        SendShopError(player, "Item not found or unavailable.");
        return;
    }
    
    Field* fields = shopItem->Fetch();
    uint32 costTokens = fields[...].Get<uint32>();
    uint32 costEmblems = fields[...].Get<uint32>();
    uint32 requiredMounts = fields[...].Get<uint32>();
    // ... etc
    
    // 2. Check requirements
    if (requiredMounts > 0)
    {
        uint32 mountCount = GetAccountMountCount(accountId);
        if (mountCount < requiredMounts)
        {
            SendShopError(player, "You need " + std::to_string(requiredMounts) + " mounts.");
            return;
        }
    }
    
    // 3. Check currency
    QueryResult currency = CharacterDatabase.Query(
        "SELECT tokens, emblems FROM dc_collection_currency WHERE account_id = {}", accountId);
    
    uint32 playerTokens = currency ? (*currency)[0].Get<uint32>() : 0;
    uint32 playerEmblems = currency ? (*currency)[1].Get<uint32>() : 0;
    
    if (playerTokens < costTokens || playerEmblems < costEmblems)
    {
        SendShopError(player, "Insufficient currency.");
        return;
    }
    
    // 4. Check purchase limit
    QueryResult purchaseCount = CharacterDatabase.Query(
        "SELECT COUNT(*) FROM dc_collection_shop_purchases "
        "WHERE account_id = {} AND shop_id = {}", accountId, shopId);
    // ... check against max_purchases
    
    // 5. Deduct currency
    CharacterDatabase.Execute(
        "UPDATE dc_collection_currency SET tokens = tokens - {}, emblems = emblems - {} "
        "WHERE account_id = {}", costTokens, costEmblems, accountId);
    
    // 6. Grant reward
    std::string rewardType = fields[...].Get<std::string>();
    uint32 rewardId = fields[...].Get<uint32>();
    
    if (rewardType == "item")
    {
        player->AddItem(rewardId, 1);
    }
    else if (rewardType == "spell")
    {
        player->learnSpell(rewardId);
        // Also add to collection table
        AddToAccountCollection(accountId, "mount", rewardId, player->GetGUID());
    }
    
    // 7. Log purchase
    CharacterDatabase.Execute(
        "INSERT INTO dc_collection_shop_purchases "
        "(account_id, shop_id, character_id, cost_tokens, cost_emblems) "
        "VALUES ({}, {}, {}, {}, {})",
        accountId, shopId, player->GetGUID().GetCounter(), costTokens, costEmblems);
    
    // 8. Send success
    SendShopSuccess(player, shopId);
}
```

### Client-Side Shop Module

```lua
-- ShopModule.lua
DCCollection.Shop = {}
local Shop = DCCollection.Shop

Shop.items = {}        -- Cached shop items
Shop.currency = { tokens = 0, emblems = 0 }

function Shop:RequestShopData()
    DC:Request("COLL", Opcodes.CMSG_GET_SHOP, {})
end

function Shop:Purchase(shopId)
    -- Validate locally first
    local item = self.items[shopId]
    if not item then return end
    
    if item.costTokens > self.currency.tokens then
        DCCollection:Print("Not enough Collection Tokens!")
        return
    end
    
    if item.costEmblems > self.currency.emblems then
        DCCollection:Print("Not enough Collector's Emblems!")
        return
    end
    
    -- Confirm dialog
    StaticPopupDialogs["DC_COLLECTION_CONFIRM_PURCHASE"] = {
        text = "Purchase " .. item.name .. " for " .. self:FormatCost(item) .. "?",
        button1 = "Buy",
        button2 = "Cancel",
        OnAccept = function()
            DC:Request("COLL", Opcodes.CMSG_SHOP_PURCHASE, { shopId = shopId })
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("DC_COLLECTION_CONFIRM_PURCHASE")
end

function Shop:FormatCost(item)
    local parts = {}
    if item.costTokens > 0 then
        table.insert(parts, item.costTokens .. " |cffffd700Tokens|r")
    end
    if item.costEmblems > 0 then
        table.insert(parts, item.costEmblems .. " |cff9932ccEmblems|r")
    end
    return table.concat(parts, " + ")
end

function Shop:CanAfford(item)
    return self.currency.tokens >= item.costTokens 
       and self.currency.emblems >= item.costEmblems
end

function Shop:MeetsRequirements(item)
    if item.requiredMounts and DCCollection.counts.mounts < item.requiredMounts then
        return false, "Collect " .. item.requiredMounts .. " mounts"
    end
    if item.requiredPets and DCCollection.counts.pets < item.requiredPets then
        return false, "Collect " .. item.requiredPets .. " pets"
    end
    -- ... more requirements
    return true, nil
end
```

---

## 4. Data Sources for Mounts, Pets, etc.

### Mount Data Sources

| Source | Data Type | Location |
|--------|-----------|----------|
| **Spell.dbc** | Mount spell IDs, names | `deps/mysql/` extracted DBCs |
| **CreatureDisplayInfo.dbc** | Mount visual models | Client DBC files |
| **item_template** | Mount items (summoning items) | `world.item_template` |
| **spell_dbc (custom)** | Custom mount spells | `data/sql/custom/` |
| **Wowhead/Wowpedia** | Source info (drops, quests) | Manual data entry |

#### Extracting Mount Spell IDs

```sql
-- All mount spells from Spell.dbc via DB extraction
-- Effect 1 = SPELL_EFFECT_SUMMON (28) with SUMMON_TYPE_MOUNT category
-- Look for spells with AuraInterruptFlags containing AURA_INTERRUPT_FLAG_NOT_MOUNTED

-- Query item_template for mount-summoning items
SELECT entry, name, spellid_1, spelltrigger_1 
FROM item_template 
WHERE class = 15  -- ITEM_CLASS_MISCELLANEOUS
  AND subclass = 5  -- ITEM_SUBCLASS_MOUNT
  AND spellid_1 > 0;
```

#### Pre-Built Mount List

The Aldori15 account-wide module already has curated mount lists:
- [azerothcore-eluna-accountwide/Mounts](https://github.com/Aldori15/azerothcore-eluna-accountwide)

```lua
-- Example from Aldori15 pattern
local MOUNT_SPELLS = {
    458,    -- Brown Horse
    459,    -- Gray Wolf
    468,    -- White Stallion
    -- ... 200+ mount spells
}
```

### Pet Data Sources

| Source | Data Type | Location |
|--------|-----------|----------|
| **creature_template** | Pet creature entries | `world.creature_template` |
| **npc_vendor** | Purchasable pets | `world.npc_vendor` |
| **item_template** | Pet summoning items | `world.item_template` |
| **Spell.dbc** | Companion summon spells | Effect: SUMMON_TYPE_COMPANION |

```sql
-- Companion pet items
SELECT i.entry, i.name, i.spellid_1 
FROM item_template i
WHERE i.class = 15 
  AND i.subclass = 2  -- ITEM_SUBCLASS_COMPANION_PET
  AND i.spellid_1 > 0;

-- Or via creature_template with UNIT_FLAG_NON_ATTACKABLE
SELECT entry, name FROM creature_template 
WHERE type_flags & 0x2000  -- CREATURE_TYPE_FLAG_COMPANION
OR npcflag & 0x20000000;   -- UNIT_NPC_FLAG_COMPANION
```

### Transmog Data Sources

```sql
-- All transmogrifiable items (armor with display)
SELECT entry, name, class, subclass, displayid, Quality 
FROM item_template
WHERE class IN (2, 4)  -- ITEM_CLASS_WEAPON, ITEM_CLASS_ARMOR
  AND displayid > 0
  AND Quality >= 2;  -- Uncommon+
```

### Toy Data Sources

**Note:** 3.3.5a doesn't have a "toy" category. Define manually:

```sql
-- Create dc_toy_definitions with known fun items
INSERT INTO dc_toy_definitions (item_id, name, category, source) VALUES
(17712, 'Winter Veil Disguise Kit', 'Holidays', 'Winter Veil'),
(21540, 'Elune\'s Lantern', 'World Events', 'Lunar Festival'),
(33223, 'Fishing Chair', 'Profession', 'Fishing Daily'),
-- etc.
```

### Recommended: Pre-Populate Definition Tables

Create SQL files with all known collectables:

```
data/sql/custom/
├── dc_mount_definitions_data.sql    -- ~280 mounts
├── dc_pet_definitions_data.sql      -- ~150 pets
├── dc_toy_definitions_data.sql      -- ~50 toys (curated)
├── dc_heirloom_definitions_data.sql -- ~40 heirlooms
└── dc_transmog_appearances.sql      -- Generated from item_template
```

---

## 4. Heirloom Tab: Account-Wide Summoning ✅ POSSIBLE

### Concept: "Summon for Alt" Feature

When viewing the Heirloom tab, players can:
1. See all account-owned heirlooms
2. Click "Summon to Bag" to create that heirloom in current character's inventory
3. Server validates account ownership and creates item

### How It Works

```
┌─────────────────────────────────────────────────────────────────────┐
│ HEIRLOOMS                                         [Account-Wide]    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │ Polished Spaulders of Valor          [Upgrade: 3/3]             ││
│  │ ────────────────────────────────────────────────────            ││
│  │ Shoulders · Plate · Heirloom                                    ││
│  │ Obtained by: Charactername on 2024-05-15                        ││
│  │                                                                 ││
│  │ ┌─────────────────┐  ┌──────────────────────────────┐           ││
│  │ │ [Summon to Bag] │  │ [Upgrade] (Requires Tokens)  │           ││
│  │ └─────────────────┘  └──────────────────────────────┘           ││
│  └─────────────────────────────────────────────────────────────────┘│
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │ Tattered Dreadmist Robe              [Upgrade: 2/3]             ││
│  │ ... (same pattern)                                              ││
│  └─────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
```

### Server-Side Implementation

```cpp
// CMSG_SUMMON_HEIRLOOM handler
void HandleSummonHeirloom(Player* player, uint32 itemId)
{
    uint32 accountId = player->GetSession()->GetAccountId();
    
    // 1. Verify account owns this heirloom
    QueryResult result = CharacterDatabase.Query(
        "SELECT upgrade_level FROM dc_heirloom_collection "
        "WHERE account_id = {} AND item_id = {}", accountId, itemId);
    
    if (!result)
    {
        // Send error: "You don't own this heirloom"
        return;
    }
    
    uint8 upgradeLevel = (*result)[0].Get<uint8>();
    
    // 2. Check if player already has this item
    if (player->HasItemCount(itemId, 1))
    {
        // Send error: "You already have this heirloom"
        return;
    }
    
    // 3. Check bag space
    ItemPosCountVec dest;
    InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, 1);
    if (msg != EQUIP_ERR_OK)
    {
        player->SendEquipError(msg, nullptr, nullptr, itemId);
        return;
    }
    
    // 4. Create the heirloom item
    Item* item = player->StoreNewItem(dest, itemId, true);
    if (!item)
        return;
    
    // 5. Apply upgrade level (if using upgrade system)
    // This ties into existing DC-ItemUpgrade heirloom system
    ApplyHeirloomUpgrade(item, upgradeLevel);
    
    // 6. Send success message
    player->SendNewItem(item, 1, true, false);
    SendCollectionMessage(player, "HEIRLOOM_SUMMONED", itemId);
}
```

### Client-Side Request

```lua
-- In HeirloomModule.lua
function DCCollection:SummonHeirloom(itemId)
    if not self.cache.heirlooms[itemId] then
        self:Print("You don't own this heirloom.")
        return
    end
    
    -- Check if already in bags
    if GetItemCount(itemId, true) > 0 then
        self:Print("You already have this heirloom in your bags or bank.")
        return
    end
    
    -- Request from server via DCAddonProtocol
    DC:Request("COLL", Opcodes.CMSG_SUMMON_HEIRLOOM, {
        itemId = itemId
    })
end
```

### Integration with DC-ItemUpgrade Heirloom System

The existing [DC-ItemUpgrade/Heirloom.lua](../../Client%20addons%20needed/DC-ItemUpgrade/Heirloom.lua) has:
- Stat package system for heirloom shirts
- Upgrade levels tracking
- Server communication

**Tie Collection UI to ItemUpgrade:**

```lua
-- When clicking "Upgrade" in Collection UI
function DCCollection:UpgradeHeirloom(itemId)
    -- Switch DC-ItemUpgrade to heirloom mode
    if DarkChaos_ItemUpgrade then
        DarkChaos_ItemUpgrade.uiMode = "HEIRLOOM"
        DarkChaos_ItemUpgrade.selectedHeirloom = itemId
        if DarkChaos_ItemUpgradeFrame then
            DarkChaos_ItemUpgradeFrame:Show()
        end
    elseif SlashCmdList["DCUPGRADE"] then
        SlashCmdList["DCUPGRADE"]("heirloom " .. itemId)
    end
end
```

---

## 5. Data Population Strategy

### Phase 1: Auto-Extract from DBC/DB

```lua
-- Server-side Eluna script to populate dc_mount_definitions
local function PopulateMountDefinitions()
    -- Query all mount spells
    local query = [[
        SELECT s.id, s.name, i.entry as item_id
        FROM spell_dbc s
        LEFT JOIN item_template i ON i.spellid_1 = s.id
        WHERE s.effect1 = 28  -- SPELL_EFFECT_SUMMON
        -- Additional filters for mount category
    ]]
    -- Insert into dc_mount_definitions
end
```

### Phase 2: Manual Enrichment

Add source information from Wowhead/Wowpedia:

```sql
UPDATE dc_mount_definitions 
SET source = '{"type":"drop","location":"Karazhan","boss":"Attumen the Huntsman","dropRate":1}'
WHERE spell_id = 36702;  -- Fiery Warhorse
```

### Phase 3: Community Contributions

Create a simple web form or Discord bot for players to report missing source info.

---

## 6. Auto-Generating Source Info from Loot Tables ✅ FEASIBLE

### Available Loot Tables

The AzerothCore database has comprehensive loot tables we can query:

| Table | Purpose |
|-------|---------|
| `creature_loot_template` | Boss/creature drops (Entry → Item) |
| `gameobject_loot_template` | Chest/object drops |
| `reference_loot_template` | Shared loot groups |
| `npc_vendor` | Vendor purchases |
| `quest_template` | Quest rewards |
| `achievement_reward` | Achievement rewards |

### SQL Query: Auto-Generate Mount Sources

```sql
-- Find mount source from loot tables
-- Mount items have class=15, subclass=5 in item_template

-- Step 1: Get mount items and their spell IDs
CREATE OR REPLACE VIEW v_mount_items AS
SELECT 
    i.entry AS item_id,
    i.name AS item_name,
    i.spellid_1 AS spell_id,
    i.Quality AS rarity
FROM item_template i
WHERE i.class = 15 AND i.subclass = 5 AND i.spellid_1 > 0;

-- Step 2: Find creature drops with boss names
SELECT 
    mi.spell_id,
    mi.item_name,
    c.entry AS creature_entry,
    c.name AS creature_name,
    clt.Chance AS drop_rate,
    CASE 
        WHEN c.rank = 3 THEN 'World Boss'
        WHEN c.rank = 4 THEN 'Rare Elite'  
        WHEN c.unit_flags & 0x8000 THEN 'Boss'
        ELSE 'Creature'
    END AS creature_type,
    -- Try to get location from creature_template_addon or spawns
    COALESCE(
        (SELECT name FROM areaentry WHERE id = 
            (SELECT zone FROM creature WHERE id1 = c.entry LIMIT 1)
        ), 'Unknown'
    ) AS location
FROM v_mount_items mi
JOIN creature_loot_template clt ON clt.Item = mi.item_id
JOIN creature_template c ON c.lootid = clt.Entry;

-- Step 3: Find vendor mounts
SELECT 
    mi.spell_id,
    mi.item_name,
    c.entry AS vendor_entry,
    c.name AS vendor_name,
    nv.ExtendedCost,
    CASE 
        WHEN nv.ExtendedCost > 0 THEN 'token'
        ELSE 'gold'
    END AS cost_type
FROM v_mount_items mi
JOIN npc_vendor nv ON nv.item = mi.item_id
JOIN creature_template c ON c.entry = nv.entry;

-- Step 4: Quest reward mounts  
SELECT
    mi.spell_id,
    mi.item_name,
    qt.ID AS quest_id,
    qt.LogTitle AS quest_name
FROM v_mount_items mi
JOIN quest_template qt ON 
    qt.RewardItem1 = mi.item_id OR
    qt.RewardItem2 = mi.item_id OR
    qt.RewardItem3 = mi.item_id OR
    qt.RewardItem4 = mi.item_id;
```

### Automated Source JSON Generation

```sql
-- Create stored procedure to auto-populate dc_mount_definitions.source
DELIMITER //
CREATE PROCEDURE PopulateMountSources()
BEGIN
    -- Update from creature drops (bosses)
    UPDATE dc_mount_definitions md
    JOIN (
        SELECT 
            i.spellid_1 AS spell_id,
            JSON_OBJECT(
                'type', 'drop',
                'location', COALESCE(
                    (SELECT name FROM instance_template it WHERE it.map = 
                        (SELECT map FROM creature WHERE id1 = c.entry LIMIT 1)
                    ), 'World'
                ),
                'boss', c.name,
                'dropRate', ROUND(clt.Chance, 1)
            ) AS source_json
        FROM item_template i
        JOIN creature_loot_template clt ON clt.Item = i.entry
        JOIN creature_template c ON c.lootid = clt.Entry
        WHERE i.class = 15 AND i.subclass = 5 
          AND (c.rank >= 3 OR c.unit_flags & 0x8000)  -- Boss flag
    ) src ON md.spell_id = src.spell_id
    SET md.source = src.source_json
    WHERE md.source IS NULL OR md.source = '';
    
    -- Update from vendors
    UPDATE dc_mount_definitions md
    JOIN (
        SELECT 
            i.spellid_1 AS spell_id,
            JSON_OBJECT(
                'type', 'vendor',
                'npc', c.name,
                'cost', COALESCE(i.BuyPrice, 0)
            ) AS source_json
        FROM item_template i
        JOIN npc_vendor nv ON nv.item = i.entry
        JOIN creature_template c ON c.entry = nv.entry
        WHERE i.class = 15 AND i.subclass = 5
    ) src ON md.spell_id = src.spell_id
    SET md.source = src.source_json
    WHERE md.source IS NULL OR md.source = '';
END //
DELIMITER ;
```

### Accuracy Level

| Source Type | Auto-Detection | Accuracy |
|-------------|---------------|----------|
| Boss drops | ✅ creature_loot_template | ~95% |
| Vendor | ✅ npc_vendor | ~99% |
| Quest rewards | ✅ quest_template | ~95% |
| Achievements | ⚠️ achievement_reward | ~80% |
| Reputation | ⚠️ faction + npc_vendor | ~70% |
| Profession | ⚠️ skill requirements | ~60% |
| World Events | ❌ Manual | ~0% |
| PvP rewards | ❌ Manual | ~0% |

**Bottom line:** ~80% of sources can be auto-detected, remaining 20% need manual entry or can show "Unknown source".

---

## 7. Dynamic System: Auto-Extending Collections ✅ POSSIBLE

### Design Philosophy: Definition Tables vs. Dynamic Discovery

**Option A: Static Definition Tables (Current Design)**
- `dc_mount_definitions` contains all known mounts
- New mounts require SQL insert
- ❌ Not dynamic

**Option B: Hybrid Dynamic System (RECOMMENDED)**
- Definitions table for metadata (source, icon, rarity)
- BUT collection tracks ANY learned spell/item
- New items appear automatically, just without rich metadata

### Implementation: Dynamic Discovery

```cpp
// Server-side: When player learns a mount spell
void OnPlayerLearnSpell(Player* player, uint32 spellId)
{
    SpellInfo const* spell = sSpellMgr->GetSpellInfo(spellId);
    if (!spell)
        return;
    
    // Check if it's a mount spell (has SPELL_AURA_MOUNTED effect)
    bool isMount = false;
    for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
    {
        if (spell->Effects[i].ApplyAuraName == SPELL_AURA_MOUNTED)
        {
            isMount = true;
            break;
        }
    }
    
    if (!isMount)
        return;
    
    uint32 accountId = player->GetSession()->GetAccountId();
    
    // Insert into collection (works even if not in definitions!)
    CharacterDatabase.Execute(
        "INSERT IGNORE INTO dc_mount_collection "
        "(account_id, spell_id, obtained_by, obtained_date) "
        "VALUES ({}, {}, {}, NOW())",
        accountId, spellId, player->GetGUID().GetCounter()
    );
    
    // Check if definition exists, if not, auto-create basic one
    QueryResult defCheck = WorldDatabase.Query(
        "SELECT 1 FROM dc_mount_definitions WHERE spell_id = {}", spellId);
    
    if (!defCheck)
    {
        // Auto-create definition with basic info from spell
        WorldDatabase.Execute(
            "INSERT INTO dc_mount_definitions "
            "(spell_id, name, mount_type, rarity, source) "
            "VALUES ({}, '{}', {}, {}, '{}')",
            spellId,
            spell->SpellName[0],  // English name from DBC
            DetermineMountType(spell),  // 0=ground, 1=flying
            0,  // Default rarity
            "{\"type\":\"unknown\"}"  // Unknown source
        );
        
        LOG_INFO("collection", "Auto-created mount definition for spell {}", spellId);
    }
    
    // Notify addon
    SendCollectionUpdate(player, "mount", spellId);
}
```

### Client-Side: Handle Unknown Items

```lua
-- In MountModule.lua
function DCCollection:GetMountInfo(spellId)
    -- First check server definitions
    local def = self.mountDefinitions[spellId]
    
    if def then
        return {
            name = def.name,
            icon = def.icon or GetSpellTexture(spellId),
            source = self:ParseSource(def.source),
            rarity = def.rarity
        }
    end
    
    -- Fallback: Use client API for basic info
    local name, _, icon = GetSpellInfo(spellId)
    return {
        name = name or ("Mount #" .. spellId),
        icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
        source = { type = "unknown", text = "Source unknown" },
        rarity = 0  -- Common by default
    }
end
```

### Auto-Extension Flow

```
┌────────────────────────────────────────────────────────────────────┐
│                    NEW MOUNT ADDED TO SERVER                        │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  1. Admin adds mount to item_template / spell_dbc                  │
│                   ↓                                                │
│  2. Player obtains mount (learns spell)                            │
│                   ↓                                                │
│  3. OnPlayerLearnSpell hook fires                                  │
│                   ↓                                                │
│  4. Check: Is it SPELL_AURA_MOUNTED?                               │
│                   ↓ YES                                            │
│  5. INSERT INTO dc_mount_collection                                │
│                   ↓                                                │
│  6. Check: Exists in dc_mount_definitions?                         │
│        ├── YES → Use existing metadata                             │
│        └── NO  → Auto-create with spell name, unknown source       │
│                   ↓                                                │
│  7. Send SMSG_COLLECTION_UPDATE to addon                           │
│                   ↓                                                │
│  8. Addon displays mount (fallback icon if no definition)          │
│                                                                    │
│  ✅ RESULT: Mount appears immediately, even without pre-definition │
└────────────────────────────────────────────────────────────────────┘
```

### Same Pattern for Pets, Toys, Heirlooms

| Collection | Detection Method |
|------------|-----------------|
| **Mounts** | `SPELL_AURA_MOUNTED` in learned spell |
| **Pets** | Item class=15 subclass=2, or `SUMMON_TYPE_COMPANION` spell |
| **Toys** | Item with `ITEM_FLAG_TOY` (custom flag) or curated list |
| **Heirlooms** | Item quality = `ITEM_QUALITY_HEIRLOOM` (7) |
| **Transmog** | Any equippable item with displayId, when equipped |

### Definition Enrichment Workflow

```
1. IMMEDIATE: Mount appears with basic info (name from spell, unknown source)
2. BATCH JOB: Run PopulateMountSources() nightly to update from loot tables
3. MANUAL: Admin adds special source info for event/custom mounts
```

---

## Summary

| Question | Answer |
|----------|--------|
| **Button in DC-Welcome?** | Add to `RegisteredAddons` in AddonsPanel.lua - fits existing pattern |
| **Mount speed via collection?** | ✅ Yes! Items or auto-bonuses via `SPELL_AURA_MOD_INCREASE_MOUNTED_SPEED` |
| **Collection Shop?** | ✅ Yes! `dc_collection_shop` table with tokens/emblems currency |
| **Data sources?** | Auto-generated from loot tables (~80%), manual for rest |
| **Heirloom summoning?** | ✅ Yes! "Summon to Bag" with server validation of account ownership |
| **Loot table for sources?** | ✅ Yes! `creature_loot_template` + `npc_vendor` + `quest_template` |
| **Dynamic extension?** | ✅ Yes! Hook spell learning, auto-create definitions, enrich later |

---

## Dynamic System Summary

| Aspect | Static Approach | Dynamic Approach (Recommended) |
|--------|-----------------|-------------------------------|
| **New mount added** | Requires SQL insert | ✅ Auto-detected on learn |
| **Source info** | Manual JSON entry | ✅ 80% auto from loot tables |
| **Unknown items** | Error/missing | ✅ Fallback to spell API |
| **Admin effort** | High | Low (only special cases) |
| **Player experience** | Complete info | Works immediately, enriches over time |

---

## Files to Modify

| File | Change |
|------|--------|
| `DC-Welcome/AddonsPanel.lua` | Add dc-collections entry to RegisteredAddons |
| `DC-Welcome/MinimapButton.lua` | Add right-click menu option |
| `dc_addon_collection.cpp` | Add mount speed aura application + shop handlers |
| `spell_dbc` | Add mount collector speed spells |
| `DC-Collection/HeirloomModule.lua` | Add SummonHeirloom functionality |
| `DC-Collection/ShopModule.lua` | NEW: Shop UI and purchase logic |
| `dc_collection_shop` | NEW: Shop items table |
| `dc_collection_currency` | NEW: Player currency tracking |
| `dc_heirloom_collection` | Track account ownership + upgrade level |

---

## New Tables Summary

| Table | Purpose |
|-------|---------|
| `dc_collection_shop` | Shop item definitions, prices, requirements |
| `dc_collection_shop_purchases` | Purchase history per account |
| `dc_collection_currency` | Account-wide tokens & emblems |
| `dc_mount_definitions` | Mount metadata (existing) |
| `dc_mount_collection` | Player mount collection (existing) |
