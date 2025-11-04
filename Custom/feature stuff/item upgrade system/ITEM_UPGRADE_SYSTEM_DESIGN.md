# DarkChaos-255: Item Upgrade System Design
## Foundation System for Progressive Gear Progression (Level 80→255)

**Document Type:** Technical Design & Implementation Plan  
**Version:** 1.0  
**Date:** November 4, 2025  
**Status:** Ready for Development  
**Effort Estimate:** 80-120 hours  
**Priority:** ⭐⭐⭐⭐⭐ P1 - FOUNDATIONAL

---

## 🎯 Executive Summary

The **Item Upgrade System** enables players to progressively upgrade gear using a unified token system, providing a clear progression path for Level 80→255 players across:
- ✅ HLBG (Hinterlands Battlegrounds)
- ✅ Dungeons (Normal, Heroic, Mythic)
- ✅ Raids (Normal, Heroic, Mythic)
- ✅ M+ Dungeons (future M+ system)

**Core Concept:** One universal token type, difficulty factors applied to determine upgrade-able iLvl range

**Minimum Viable Product (MVP):**
- Single upgrade token currency
- Multiple item iLvl versions created via database entries (lowest effort)
- NPC-based upgrade interface (retail-like visual)
- Blizzlike difficulty-based progression tracks

---

## 📊 System Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│              Player Gear Drop / Reward                       │
├─────────────────────────────────────────────────────────────┤
│  HLBG (iLvl 219)  │  Dungeon (iLvl 226)  │  Raid (iLvl 245) │
└─────────────┬───────────────────┬────────────────────┬──────┘
              │                   │                    │
        ┌─────▼──────────────────▼────────────────────▼──────┐
        │         NPC Item Upgrade Interface                  │
        │  Select Item → Preview Upgrade Path → Confirm      │
        └─────┬──────────────────────────────────────────────┘
              │
        ┌─────▼──────────────────────────────────────────────┐
        │     Cost Calculator (Tokens, Flightstones)          │
        │  Based on difficulty, item slot, current iLvl      │
        └─────┬──────────────────────────────────────────────┘
              │
        ┌─────▼──────────────────────────────────────────────┐
        │    Apply Upgrade: Replace Item ID → Higher iLvl     │
        │    Track upgrade history in character database      │
        └─────────────────────────────────────────────────────┘
```

---

## 🎮 Player Experience Flow

### **Scenario: Player Gets Gear**

1. Player completes Heroic Dungeon
2. Receives item: **"Heroic Chestplate of the Eternal" (iLvl 226)**
3. Inventory shows upgrade indicator (small icon)
4. Visits Item Upgrade NPC
5. Sees upgrade UI:
   ```
   Heroic Chestplate of the Eternal (226)
   ┌─────────────────────────────────────┐
   │ Upgrade to: 232 iLvl                │
   │ Cost: 15 Tokens | 50 Flightstones   │
   │ ✓ You have 25 Tokens                │
   │                                     │
   │ [Preview] [Upgrade] [Cancel]        │
   └─────────────────────────────────────┘
   ```
6. Clicks Upgrade
7. Item replaced with **"Heroic Chestplate of the Eternal (iLvl 232)"**
8. Currencies deducted
9. **"Heroic Chestplate of the Eternal (iLvl 226)"** no longer in inventory

---

## 💡 Key Design Decision: Multiple iLvl Versions

**Problem:** How to handle same item at different iLvls?

**Three Approaches Analyzed:**

| Approach | Effort | Limitations |
|----------|--------|-------------|
| **1. Item Property Modification (Runtime)** | High | Complex enchantment-like system, risky |
| **2. Reforging/Enhancement Slots** | High | Complex UI/network overhead |
| **✅ Multiple Item Entries (Database)** | LOW | Simple, proven in private servers |

### **Chosen Approach: Multiple Item Entries**

**How it works:**
- Each base item has multiple entries in `item_template`
- Example: Heroic Chestplate exists as:
  - Entry 50001 (iLvl 226)
  - Entry 50002 (iLvl 232)
  - Entry 50003 (iLvl 239)
  - Entry 50004 (iLvl 245) - max

- Upgrade system swaps item_entry ID
- **Advantages:** 
  - ✅ No runtime modification needed
  - ✅ Works with existing AzerothCore item system
  - ✅ Database-driven (no code changes to core)
  - ✅ Easy to balance/adjust

---

## 🗄️ Database Schema (`dc_` prefixed)

### **1. Core Upgrade Tracks Definition**

```sql
CREATE TABLE dc_upgrade_tracks (
  track_id INT PRIMARY KEY AUTO_INCREMENT,
  track_name VARCHAR(100),  -- 'Heroic Dungeon', 'Mythic Raid', etc.
  source_content VARCHAR(50),  -- 'dungeon', 'raid', 'hlbg', 'mythic_plus'
  difficulty VARCHAR(50),  -- 'heroic', 'mythic', 'mythic+5'
  
  -- iLvl Range for this track
  base_ilvl INT,  -- Starting iLvl
  max_ilvl INT,   -- Max after all upgrades
  upgrade_steps TINYINT,  -- Number of upgrade levels
  ilvl_per_step TINYINT,  -- +3 or +4 iLvl per step
  
  -- Currency costs
  token_cost_per_upgrade INT,  -- Flat cost (e.g., 10 tokens)
  flightstone_cost_base INT,   -- Base flightstone cost
  
  -- Progression gating
  required_player_level INT,
  required_item_level INT,  -- Entry requirement
  
  description VARCHAR(255),
  active BOOLEAN DEFAULT TRUE,
  
  KEY (source_content, difficulty)
) ENGINE=INNODB;

-- Sample data for 3.3.5a (simplified)
INSERT INTO dc_upgrade_tracks VALUES
(1, 'Heroic Dungeon', 'dungeon', 'heroic', 226, 245, 5, 4, 10, 50, 80, 210, 'Heroic dungeon upgrades', TRUE),
(2, 'Mythic Raid', 'raid', 'mythic', 245, 271, 7, 3, 15, 75, 80, 245, 'Mythic raid upgrades', TRUE),
(3, 'HLBG', 'hlbg', 'normal', 219, 239, 5, 4, 8, 40, 80, 200, 'HLBG upgrades', TRUE);
```

**Effort:** 10 hours

### **2. Item Version Mapping**

```sql
CREATE TABLE dc_item_upgrade_chains (
  chain_id INT PRIMARY KEY AUTO_INCREMENT,
  
  -- Base item identifier
  base_item_name VARCHAR(100),  -- "Heroic Chestplate"
  item_quality INT,  -- Epic = 4
  item_slot VARCHAR(50),  -- 'chest', 'head', etc.
  
  -- Track this item belongs to
  track_id INT,
  
  -- Item versions (upgrade path)
  ilvl_0_entry INT,  -- Entry ID at base iLvl
  ilvl_1_entry INT,  -- Entry ID at iLvl+4
  ilvl_2_entry INT,  -- Entry ID at iLvl+8
  ilvl_3_entry INT,  -- Entry ID at iLvl+12
  ilvl_4_entry INT,  -- Entry ID at iLvl+16
  ilvl_5_entry INT,  -- Entry ID at iLvl+20 (max)
  
  -- Metadata
  season INT,        -- Season this belongs to (0 = permanent)
  description VARCHAR(255),
  created_date TIMESTAMP,
  
  FOREIGN KEY (track_id) REFERENCES dc_upgrade_tracks(track_id),
  UNIQUE KEY (base_item_name, track_id),
  KEY (season)
) ENGINE=INNODB;

-- Example: Heroic Chestplate chain
INSERT INTO dc_item_upgrade_chains VALUES
(1, 'Heroic Chestplate of the Eternal', 4, 'chest', 1,
 50001,  -- 226 iLvl
 50002,  -- 230 iLvl
 50003,  -- 234 iLvl
 50004,  -- 238 iLvl
 50005,  -- 242 iLvl
 50006,  -- 246 iLvl (max)
 0, 'Upgradeable heroic chestplate', NOW());
```

**Effort:** 15 hours (includes creating all item entries)

### **3. Player Upgrade History & Tracking**

```sql
CREATE TABLE dc_player_item_upgrades (
  upgrade_id INT PRIMARY KEY AUTO_INCREMENT,
  character_guid INT,
  
  -- Item tracking
  item_guid INT UNIQUE,  -- Unique instance of item
  base_item_name VARCHAR(100),
  current_ilvl INT,
  max_possible_ilvl INT,  -- Max for their track
  
  -- Upgrade history
  current_upgrade_level TINYINT,  -- 0-5 usually
  last_upgraded TIMESTAMP,
  
  -- Metadata
  track_id INT,
  season INT,
  
  FOREIGN KEY (track_id) REFERENCES dc_upgrade_tracks(track_id),
  KEY (character_guid),
  KEY (season)
) ENGINE=INNODB;
```

**Effort:** 5 hours

### **4. Currency Management**

```sql
CREATE TABLE dc_upgrade_currency (
  currency_id INT PRIMARY KEY AUTO_INCREMENT,
  currency_name VARCHAR(50),  -- "Upgrade Token"
  currency_type VARCHAR(50),  -- "token", "flightstone"
  
  -- Acquisition
  sources TEXT,  -- JSON: {dungeon: 5, raid: 10, hlbg: 3}
  acquisition_rate INT,  -- Per boss/completion
  
  -- Caps
  weekly_cap INT,         -- NULL if no cap
  total_cap INT DEFAULT 9999,
  
  active BOOLEAN DEFAULT TRUE,
  season INT  -- NULL if permanent
) ENGINE=INNODB;

-- Token currency
INSERT INTO dc_upgrade_currency VALUES
(1, 'Upgrade Token', 'token', 
 '{"hlbg": 3, "heroic_dungeon": 5, "mythic_dungeon": 8, "raid_normal": 10, "raid_heroic": 15, "raid_mythic": 20}',
 1, 50, 9999, TRUE, 0);

-- Flightstone currency (secondary)
INSERT INTO dc_upgrade_currency VALUES
(2, 'Flightstone', 'flightstone',
 '{"heroic_dungeon": 25, "mythic_dungeon": 50, "raid": 75}',
 1, NULL, 2000, TRUE, 0);
```

**Effort:** 5 hours

### **5. NPC Configuration**

```sql
CREATE TABLE dc_item_upgrade_npc (
  npc_id INT PRIMARY KEY AUTO_INCREMENT,
  npc_entry INT,  -- Creature entry
  npc_name VARCHAR(100),
  
  -- Tracks they offer
  available_tracks TEXT,  -- JSON: [1, 2, 3]
  
  -- Location
  map_id INT,
  location_x FLOAT,
  location_y FLOAT,
  location_z FLOAT,
  
  season INT,  -- Season active (0 = always)
  description VARCHAR(255)
) ENGINE=INNODB;

-- Main Item Upgrade NPC
INSERT INTO dc_item_upgrade_npc VALUES
(1, 600001, 'Item Master Velisande', '[1, 2, 3]', 1, 
 -8949.95, -132.493, 83.6112, 0, 'Offer all upgrade tracks');
```

**Effort:** 5 hours

---

## 💻 C++ Implementation

### **Architecture Overview**

```cpp
// Main entry points:
// 1. ItemUpgradeManager - Core logic
// 2. ItemUpgradeNPC - Gossip handler
// 3. ItemUpgradeCommand - Optional /upgrade command
// 4. ItemUpgradeHooks - Integration with loot/quest systems
```

### **1. ItemUpgradeManager.h**

```cpp
#pragma once

#include "Define.h"
#include "Player.h"
#include "Item.h"
#include <unordered_map>

class ItemUpgradeManager {
public:
  static ItemUpgradeManager* instance();
  
  // Query upgrade possibilities
  struct UpgradeInfo {
    uint32 nextItemEntry;  // Item ID to get
    uint32 nextIlvl;
    uint32 tokenCost;
    uint32 fligstoneCost;
    bool canUpgrade;
    std::string reason;  // If can't upgrade
  };
  
  UpgradeInfo GetUpgradeInfo(Player* player, Item* item);
  UpgradeInfo GetUpgradeInfo(uint32 itemEntry);
  
  // Perform upgrade
  bool UpgradeItem(Player* player, uint32 itemGuid);
  
  // Query state
  uint32 GetPlayerTokenBalance(uint32 playerGuid);
  uint32 GetPlayerFlightstoneBalance(uint32 playerGuid);
  
  // For loot system
  void OnItemLooted(Player* player, Item* item, uint32 lootSource);
  
  // Currency operations
  void AddTokens(uint32 playerGuid, uint32 amount, const char* reason);
  void RemoveTokens(uint32 playerGuid, uint32 amount, const char* reason);
  
  void AddFlightstones(uint32 playerGuid, uint32 amount, const char* reason);
  void RemoveFlightstones(uint32 playerGuid, uint32 amount, const char* reason);
  
private:
  struct ItemChain {
    std::string baseName;
    std::vector<uint32> itemEntries;  // iLvl progression
    uint32 trackId;
  };
  
  std::unordered_map<uint32, ItemChain> chainCache;  // itemEntry -> chain
  
  ItemChain* GetItemChain(uint32 itemEntry);
  uint32 GetItemTrack(uint32 itemEntry);
};

#define sItemUpgradeManager ItemUpgradeManager::instance()
```

**Effort:** 10 hours

### **2. ItemUpgradeManager.cpp (Key Methods)**

```cpp
#include "ItemUpgradeManager.h"
#include "CharacterDatabase.h"
#include "Player.h"
#include "Item.h"
#include "ItemTemplate.h"

ItemUpgradeManager* ItemUpgradeManager::instance() {
  static ItemUpgradeManager instance;
  return &instance;
}

ItemUpgradeManager::UpgradeInfo ItemUpgradeManager::GetUpgradeInfo(
    Player* player, Item* item) {
  UpgradeInfo info{};
  
  if (!item) {
    info.canUpgrade = false;
    info.reason = "Invalid item";
    return info;
  }
  
  uint32 itemEntry = item->GetEntry();
  ItemChain* chain = GetItemChain(itemEntry);
  
  if (!chain) {
    info.canUpgrade = false;
    info.reason = "Item not upgradeable";
    return info;
  }
  
  // Find current position in chain
  uint32 currentLevel = 0;
  for (uint32 i = 0; i < chain->itemEntries.size(); ++i) {
    if (chain->itemEntries[i] == itemEntry) {
      currentLevel = i;
      break;
    }
  }
  
  // Check if at max
  if (currentLevel >= chain->itemEntries.size() - 1) {
    info.canUpgrade = false;
    info.reason = "Already at maximum upgrade level";
    return info;
  }
  
  // Get next level info
  uint32 nextLevel = currentLevel + 1;
  info.nextItemEntry = chain->itemEntries[nextLevel];
  
  // Query upgrade cost from database
  QueryResult res = CharacterDatabase.Query(
    "SELECT token_cost_per_upgrade, flightstone_cost_base FROM dc_upgrade_tracks "
    "WHERE track_id = %u", chain->trackId);
  
  if (res) {
    Field* fields = res->Fetch();
    info.tokenCost = fields[0].Get<uint32>();
    // Scale flightstone cost by item slot
    uint32 baseCost = fields[1].Get<uint32>();
    // Heavy slot (chest, legs, head): 1.5x multiplier
    if (item->GetTemplate()->InventoryType == INVTYPE_CHEST ||
        item->GetTemplate()->InventoryType == INVTYPE_LEGS ||
        item->GetTemplate()->InventoryType == INVTYPE_HEAD) {
      info.fligstoneCost = (uint32)(baseCost * 1.5f);
    } else {
      info.fligstoneCost = baseCost;
    }
  }
  
  // Check player has resources
  if (GetPlayerTokenBalance(player->GetGUID()) < info.tokenCost) {
    info.canUpgrade = false;
    info.reason = "Insufficient tokens";
    return info;
  }
  
  info.canUpgrade = true;
  return info;
}

bool ItemUpgradeManager::UpgradeItem(Player* player, uint32 itemGuid) {
  Item* item = player->GetItemByGuid(itemGuid);
  if (!item) return false;
  
  UpgradeInfo upgrade = GetUpgradeInfo(player, item);
  if (!upgrade.canUpgrade) return false;
  
  // Deduct costs
  RemoveTokens(player->GetGUID(), upgrade.tokenCost, "Item upgrade");
  RemoveFlightstones(player->GetGUID(), upgrade.fligstoneCost, "Item upgrade");
  
  // Get bag/slot info
  uint8 bag = item->GetBagSlot();
  uint8 slot = item->GetSlot();
  
  // Create new item at upgraded level
  Item* newItem = Item::CreateItem(upgrade.nextItemEntry, 1);
  if (!newItem) {
    LOG_ERROR("item_upgrade", "Failed to create upgraded item entry %u",
      upgrade.nextItemEntry);
    return false;
  }
  
  // Copy item properties (enchants, gems, etc)
  newItem->SetItemRandomPropertyId(item->GetItemRandomPropertyId());
  newItem->SetEnchantmentId(PERM_ENCHANTMENT_SLOT, item->GetEnchantmentId(PERM_ENCHANTMENT_SLOT));
  
  // Replace item
  player->RemoveItem(bag, slot, false);
  player->AddItemToSlot(newItem, bag, slot);
  
  LOG_INFO("item_upgrade", "Player %s upgraded item %u to %u",
    player->GetName().c_str(), item->GetEntry(), upgrade.nextItemEntry);
  
  return true;
}

void ItemUpgradeManager::AddTokens(uint32 playerGuid, uint32 amount, 
    const char* reason) {
  CharacterDatabase.PExecute(
    "INSERT INTO player_currency (player_guid, currency_id, amount) "
    "VALUES (%u, 1, %u) "
    "ON DUPLICATE KEY UPDATE amount = amount + %u",
    playerGuid, amount, amount);
  
  LOG_DEBUG("item_upgrade.currency", "Added %u tokens to player %u (%s)",
    amount, playerGuid, reason);
}

uint32 ItemUpgradeManager::GetPlayerTokenBalance(uint32 playerGuid) {
  QueryResult res = CharacterDatabase.Query(
    "SELECT amount FROM player_currency WHERE player_guid = %u AND currency_id = 1",
    playerGuid);
  
  if (res) {
    return res->Fetch()[0].Get<uint32>();
  }
  
  return 0;
}
```

**Effort:** 30 hours

### **3. ItemUpgradeNPC.cpp (Gossip Handler)**

```cpp
class NPC_ItemUpgradeNPC : public CreatureScript {
public:
  NPC_ItemUpgradeNPC() : CreatureScript("npc_item_upgrade") {}
  
  struct npc_upgradeAI : public ScriptedAI {
    npc_upgradeAI(Creature* creature) : ScriptedAI(creature) {}
  };
  
  CreatureAI* GetAI(Creature* creature) const override {
    return new npc_upgradeAI(creature);
  }
  
  bool OnGossipHello(Player* player, Creature* creature) override {
    std::ostringstream menu;
    menu << "|cFF00FF00Item Upgrade Master|r\n\n"
         << "Welcome! I can help you upgrade your gear to stronger levels.\n\n"
         << "|cFFFFFF00Current Currency:|r\n"
         << "Upgrade Tokens: " << sItemUpgradeManager->GetPlayerTokenBalance(player->GetGUID()) << "\n"
         << "Flightstones: " << sItemUpgradeManager->GetPlayerFlightstoneBalance(player->GetGUID());
    
    player->ADD_GOSSIP_ITEM(GOSSIP_ICON_CHAT,
      "|cFF00FF00[Upgrade Item]|r", GOSSIP_SENDER_MAIN, 1);
    
    player->ADD_GOSSIP_ITEM(GOSSIP_ICON_CHAT,
      "How does upgrading work?", GOSSIP_SENDER_MAIN, 2);
    
    player->SEND_GOSSIP_MENU(menu.str(), creature->GetGUID());
    return true;
  }
  
  bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, 
      uint32 action) override {
    player->PlayerTalkClass->ClearMenus();
    
    if (sender != GOSSIP_SENDER_MAIN) return true;
    
    switch (action) {
      case 1: {
        // List upgradeable items
        std::ostringstream text;
        text << "|cFF00FF00Select Item to Upgrade:|r\n\n";
        
        bool hasUpgradeable = false;
        
        for (uint8 bag = INVENTORY_SLOT_BAG_START; bag < INVENTORY_SLOT_BAG_END; ++bag) {
          for (uint8 slot = 0; slot < MAX_BAG_SIZE; ++slot) {
            Item* item = player->GetItemByPos(bag, slot);
            if (!item) continue;
            
            auto info = sItemUpgradeManager->GetUpgradeInfo(player, item);
            if (!info.canUpgrade) continue;
            
            hasUpgradeable = true;
            
            std::string itemName = item->GetTemplate()->Name1;
            uint32 itemGuid = item->GetGUID();
            
            // Create gossip option for this item
            // Note: This is simplified; real implementation would need dynamic gossip
            text << "• " << itemName << " (iLvl " << item->GetTemplate()->ItemLevel 
                 << ") → " << info.nextIlvl << "\n";
          }
        }
        
        if (!hasUpgradeable) {
          text << "|cFFFF0000You have no items available to upgrade.|r";
        }
        
        player->SEND_GOSSIP_MENU(text.str(), creature->GetGUID());
        break;
      }
      
      case 2: {
        // Explain system
        std::ostringstream text;
        text << "|cFF00FF00How Item Upgrading Works:|r\n\n"
             << "1. Equip or carry items you've earned\n"
             << "2. Visit an Item Upgrade NPC\n"
             << "3. Select an item to upgrade\n"
             << "4. Pay the cost in Tokens + Flightstones\n"
             << "5. Item is replaced with upgraded version\n\n"
             << "|cFFFFFF00Costs vary by:|r\n"
             << "• Item slot (heavier = more expensive)\n"
             << "• Upgrade level (higher = more costly)\n"
             << "• Source content (raid items cost more)\n\n"
             << "|cFFFFFF00Tokens are earned from:|r\n"
             << "• HLBG: 3 tokens\n"
             << "• Heroic Dungeons: 5 tokens\n"
             << "• Mythic Dungeons: 8 tokens\n"
             << "• Raid bosses: 10-20 tokens";
        
        player->SEND_GOSSIP_MENU(text.str(), creature->GetGUID());
        break;
      }
    }
    
    return true;
  }
};

void AddSC_item_upgrade_npc() {
  new NPC_ItemUpgradeNPC();
}
```

**Effort:** 20 hours

### **4. Loot Integration Hooks**

```cpp
// In Loot.cpp or Player.cpp

void OnLootItem(Player* player, Item* item, uint32 lootSource) {
  // Called whenever player gets item from:
  // - Dungeon/raid boss
  // - Quest reward
  // - Chest
  
  // Check if item is upgradeable
  auto info = sItemUpgradeManager->GetUpgradeInfo(nullptr, item);
  if (info.canUpgrade || !info.reason.empty()) {
    // Show player upgrade indicator
    // Could be chat message, visual indicator, or item tooltip update
    if (player->GetSession()) {
      player->GetSession()->SendNotification(
        "This item can be upgraded! Visit an Item Upgrade NPC.");
    }
  }
  
  // Award currency based on loot source
  if (lootSource == LOOT_SOURCE_DUNGEON_HEROIC) {
    sItemUpgradeManager->AddTokens(player->GetGUID(), 5, "Heroic dungeon loot");
  } else if (lootSource == LOOT_SOURCE_RAID_MYTHIC) {
    sItemUpgradeManager->AddTokens(player->GetGUID(), 20, "Mythic raid loot");
  }
}
```

**Effort:** 15 hours

---

## 🎨 Visual Interface (Retail-like)

### **UI Components (Lua Addon)**

```lua
-- DC-ItemUpgrade Addon
-- Displays visual upgrade interface similar to retail

local function CreateUpgradeUI()
  local frame = CreateFrame("Frame", "ItemUpgradeFrame", UIParent)
  frame:SetSize(500, 400)
  frame:SetPoint("CENTER", UIParent, "CENTER")
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 16,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
  })
  frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
  frame:Hide()
  
  -- Title
  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetText("Item Upgrade")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -20)
  
  -- Item display (left side)
  local itemButton = CreateFrame("Button", nil, frame)
  itemButton:SetSize(80, 80)
  itemButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -60)
  itemButton:SetNormalTexture("Interface\\PaperDoll\\UI-GearManager-Slot")
  
  local itemIcon = itemButton:CreateTexture(nil, "OVERLAY")
  itemIcon:SetAllPoints()
  itemButton.icon = itemIcon
  
  -- Item info
  local itemName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  itemName:SetPoint("TOPLEFT", itemButton, "TOPRIGHT", 10, 0)
  itemName:SetWidth(300)
  frame.itemName = itemName
  
  local itemilvl = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  itemilvl:SetPoint("TOPLEFT", itemName, "BOTTOMLEFT", 0, -5)
  frame.itemilvl = itemilvl
  
  -- Upgrade progression
  local upgradeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  upgradeText:SetText("Upgrade Progress:")
  upgradeText:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -180)
  
  -- Visual bar showing upgrades
  local progressBar = CreateFrame("Frame", nil, frame)
  progressBar:SetSize(400, 30)
  progressBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -210)
  frame.progressBar = progressBar
  
  -- Cost display
  local costText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  costText:SetText("Cost for next upgrade:")
  costText:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -270)
  
  -- Token cost
  local tokenCost = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  tokenCost:SetText("Upgrade Tokens: 10/25")
  tokenCost:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, -295)
  tokenCost:SetTextColor(0, 1, 0)
  frame.tokenCost = tokenCost
  
  -- Flightstone cost
  local fsCost = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fsCost:SetText("Flightstones: 50/100")
  fsCost:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, -315)
  fsCost:SetTextColor(0.5, 0.8, 1)
  frame.fsCost = fsCost
  
  -- Buttons
  local upgradeBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
  upgradeBtn:SetSize(120, 25)
  upgradeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)
  upgradeBtn:SetText("Upgrade")
  upgradeBtn:SetScript("OnClick", function()
    -- Send upgrade command to server
    SendChatMessage("/upgrade", "SYSTEM")
  end)
  
  local closeBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
  closeBtn:SetSize(120, 25)
  closeBtn:SetPoint("BOTTOMRIGHT", upgradeBtn, "BOTTOMLEFT", -10, 0)
  closeBtn:SetText("Close")
  closeBtn:SetScript("OnClick", function()
    frame:Hide()
  end)
  
  return frame
end

-- Show UI when talking to NPC
local function ShowItemUpgradeUI(itemGUID, nextIlvl, tokenCost, fsCost)
  local frame = CreateUpgradeUI()
  -- Populate frame with item data
  frame:Show()
end
```

**Effort:** 15 hours (addon UI)

---

## 📊 Difficulty-Based Progression Tracks

### **Tracks for 3.3.5a Server**

```
TRACK 1: HLBG (Normal BG)
├─ Base iLvl: 219
├─ Max iLvl: 239 (+5 steps, +4 iLvl each)
├─ Token cost: 8 per upgrade
├─ Progression: Entry → 223 → 227 → 231 → 235 → 239
└─ For: Players gearing from 80-150

TRACK 2: Heroic Dungeons
├─ Base iLvl: 226
├─ Max iLvl: 245 (+5 steps, +4 iLvl each)
├─ Token cost: 10 per upgrade
├─ Progression: 226 → 230 → 234 → 238 → 242 → 245
└─ For: Players progressing from 150-200

TRACK 3: Mythic Dungeons
├─ Base iLvl: 239
├─ Max iLvl: 258 (+5 steps, +4 iLvl each)
├─ Token cost: 12 per upgrade
├─ Progression: 239 → 243 → 247 → 251 → 255 → 258
└─ For: Players gearing 200-245

TRACK 4: Raid Normal
├─ Base iLvl: 245
├─ Max iLvl: 264 (+5 steps, +4 iLvl each)
├─ Token cost: 15 per upgrade
├─ Progression: 245 → 249 → 253 → 257 → 261 → 264
└─ For: Raid-gearing players

TRACK 5: Raid Heroic
├─ Base iLvl: 258
├─ Max iLvl: 277 (+5 steps, +4 iLvl each)
├─ Token cost: 18 per upgrade
├─ Progression: 258 → 262 → 266 → 270 → 274 → 277
└─ For: Heroic raid progression

TRACK 6: Raid Mythic
├─ Base iLvl: 271
├─ Max iLvl: 290 (+5 steps, +4 iLvl each)
├─ Token cost: 20 per upgrade
├─ Progression: 271 → 275 → 279 → 283 → 287 → 290
└─ For: Endgame raiders
```

---

## 🏗️ Item Entry Generation Strategy

### **Naming Convention**

```
BASE_ENTRY + (TRACK_ID * 1000) + (UPGRADE_LEVEL * 10)

Examples:
- Heroic Chestplate track 2 level 0: 50000
- Heroic Chestplate track 2 level 1: 50010
- Heroic Chestplate track 2 level 2: 50020

This allows:
- Easy lookup: EntryID / 10 = upgrade level
- Track identification: (EntryID % 1000) / 10 = upgrade level
- Room for 100 items per track
- Range: 50000-60000 available for custom items
```

**Script to Generate Entries:**

```sql
-- Generate upgrade chains from base items
-- For each base item from content, create upgrade versions

-- Example: Take Heroic dungeon items and create chains
SELECT 
  item_id,
  name,
  itemlevel,
  -- Generate 5 upgraded versions (iLvl +4 each)
  CONCAT('Created upgrade chain for ', name)
FROM item_template
WHERE 
  itemlevel = 226  -- Heroic dungeon base
  AND quality = 4  -- Epic only
LIMIT 50;
```

**Effort:** 20 hours (creating all item entries)

---

## 💰 Currency Acquisition

### **Token Reward Structure**

```
HLBG Victory:           3 tokens
Heroic Dungeon Clear:   5 tokens
Mythic Dungeon Clear:   8 tokens
Raid Boss Kill:
  - Normal:  10 tokens
  - Heroic:  15 tokens
  - Mythic:  20 tokens
```

### **Flightstone Distribution**

```
Heroic Dungeon:   25 flightstones
Mythic Dungeon:   50 flightstones
Raid (all):       75 flightstones

Weekly Cap: None (unlimited)
Max Hold: 2000 flightstones
```

---

## 🔌 Integration Steps

### **Step 1: Create Database Tables**
- Duration: 2-3 hours
- Files: `dc_item_upgrade.sql`

### **Step 2: Generate Item Entries**
- Duration: 15-20 hours
- Files: `dc_item_upgrade_entries.sql`
- Use Python script to generate

### **Step 3: Implement C++ Backend**
- Duration: 30 hours
- Files: `ItemUpgradeManager.h/cpp`

### **Step 4: Create NPC Script**
- Duration: 20 hours
- Files: `ItemUpgradeNPC.cpp`

### **Step 5: Loot Integration**
- Duration: 15 hours
- Modify: Creature loot loading

### **Step 6: Client Addon UI**
- Duration: 15 hours
- Files: `DC-ItemUpgrade` addon

### **Step 7: Testing & Tuning**
- Duration: 10-15 hours
- Balance currency rates
- Test upgrade paths

**Total: 80-120 hours**

---

## 🎯 MVP vs Full Feature Set

### **MVP (Weeks 1-2): 60-80 hours**
- ✅ Single token currency
- ✅ Basic upgrade paths (3-4 tracks)
- ✅ NPC-based UI
- ✅ Currency rewards from bosses
- ✅ Item entry chains
- ❌ Addon UI (basic chat commands only)
- ❌ Discount system
- ❌ Weekly caps

### **Full Feature (Weeks 3-4): Additional 20-40 hours**
- ✅ Addon retail-like UI
- ✅ Flightstone secondary currency
- ✅ Weekly currency caps
- ✅ Discount tracking
- ✅ Leaderboard integration
- ✅ Season rotation

---

## 📋 Testing Checklist

### **Functional Tests**
- [ ] Upgrade increases item iLvl correctly
- [ ] Currency properly deducted
- [ ] Cannot upgrade when insufficient currency
- [ ] Item properties preserved (enchants, gems)
- [ ] Player can equip upgraded item
- [ ] Cosmetics update in character sheet
- [ ] Tooltip shows upgrade status

### **Database Tests**
- [ ] Item chains load correctly
- [ ] Currency caps enforced
- [ ] Player history tracked
- [ ] No duplicate entries

### **Balance Tests**
- [ ] Currency earn rate balanced
- [ ] Upgrade costs reasonable
- [ ] Progression feels meaningful
- [ ] No exploits (infinite upgrading, etc)

---

## 📚 References Used

1. **mod-item-upgrade** - Proven architecture for item chains
2. **Retail WoW Dragonflight** - Track system, progression gates
3. **Wowhead Upgrade Guide** - Flightstone costs, slot scaling
4. **mod-better-item-reloading** - Item property management

---

## 🚀 Recommended Next Steps

1. **Approve** this design document
2. **Create database** schema (SQL file)
3. **Generate item entries** using Python script
4. **Implement** ItemUpgradeManager backend
5. **Create NPC** script with basic UI
6. **Test MVP** with small group
7. **Iterate** based on feedback
8. **Add client addon** UI polish

---

**Document Status:** ✅ READY FOR DEVELOPMENT

**Difficulty Breakdown:**
- Database Design: ⭐⭐ Easy
- C++ Backend: ⭐⭐⭐ Medium
- Item Entry Generation: ⭐⭐ Easy (script-based)
- NPC UI: ⭐⭐⭐ Medium
- Addon UI: ⭐⭐⭐ Medium

**Best Value Approach:** Database-driven item swapping (NOT runtime stat modification)
