# 🛠️ ARTIFACT SYSTEM - DETAILED IMPLEMENTATION ROADMAP

**Status:** Ready for Development  
**Estimated Duration:** 11-17 hours  
**Complexity:** High (multi-component integration)  
**Risk Level:** Low (leverages existing systems)

---

## 📋 PHASE 1: DATABASE SETUP (2-3 hours)

### **Step 1.1: Create Artifact Tables**

Execute the following SQL to create the artifact system foundation:

```sql
-- ============================================================
-- TABLE 1: Core Artifact Definitions
-- ============================================================
CREATE TABLE IF NOT EXISTS `artifact_items` (
  `artifact_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `item_template_id` INT UNSIGNED NOT NULL UNIQUE,
  `artifact_type` ENUM('WEAPON', 'SHIRT', 'BAG', 'TRINKET') NOT NULL,
  `artifact_name` VARCHAR(255) NOT NULL,
  `lore_description` TEXT COMMENT 'Tooltip flavor text',
  `rarity_color` VARCHAR(10) DEFAULT '|cffff8000',  -- Orange (epic)
  `special_ability` VARCHAR(255) COMMENT 'Flavor text for max upgrade',
  `tier_id` TINYINT UNSIGNED DEFAULT 5 COMMENT 'Always 5 for artifacts',
  `max_upgrade_level` TINYINT UNSIGNED DEFAULT 15,
  `essence_type_id` INT UNSIGNED DEFAULT 1 COMMENT 'Item ID of essence currency',
  `cosmetic_variants` TINYINT UNSIGNED DEFAULT 0 COMMENT 'How many appearance variants',
  `set_piece_id` TINYINT UNSIGNED DEFAULT 0 COMMENT 'Part of set? (0=none)',
  `requires_quest_id` INT UNSIGNED DEFAULT 0 COMMENT 'Quest to unlock',
  `creation_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `is_active` TINYINT(1) DEFAULT 1,
  `notes` TEXT,
  PRIMARY KEY (`artifact_id`),
  UNIQUE KEY `idx_item_template` (`item_template_id`),
  KEY `idx_artifact_type` (`artifact_type`),
  KEY `idx_tier_id` (`tier_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLE 2: World Loot Locations
-- ============================================================
CREATE TABLE IF NOT EXISTS `artifact_loot_locations` (
  `location_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `artifact_id` INT UNSIGNED NOT NULL,
  `map_id` INT UNSIGNED NOT NULL,
  `zone_id` INT UNSIGNED COMMENT 'Optional zone for loot restrictions',
  `x` FLOAT NOT NULL,
  `y` FLOAT NOT NULL,
  `z` FLOAT NOT NULL,
  `orientation` FLOAT NOT NULL DEFAULT 0,
  `gameobject_entry` INT UNSIGNED COMMENT 'Chest/container in world',
  `respawn_time_sec` INT UNSIGNED DEFAULT 3600,
  `loot_description` VARCHAR(255),
  `difficulty` ENUM('NORMAL', 'HEROIC', 'RAID') DEFAULT 'HEROIC',
  `location_name` VARCHAR(255),
  `is_enabled` TINYINT(1) DEFAULT 1,
  PRIMARY KEY (`location_id`),
  KEY `idx_artifact` (`artifact_id`),
  KEY `idx_map` (`map_id`),
  KEY `idx_zone` (`zone_id`),
  KEY `idx_enabled` (`is_enabled`),
  CONSTRAINT `fk_artifact_location` FOREIGN KEY (`artifact_id`) 
    REFERENCES `artifact_items` (`artifact_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLE 3: Player Artifact Progress Tracking
-- ============================================================
CREATE TABLE IF NOT EXISTS `player_artifact_data` (
  `player_guid` INT UNSIGNED NOT NULL,
  `artifact_id` INT UNSIGNED NOT NULL,
  `item_guid` INT UNSIGNED COMMENT 'Actual item instance GUID',
  `upgrade_level` TINYINT UNSIGNED DEFAULT 0 COMMENT '0-15',
  `essence_spent` INT UNSIGNED DEFAULT 0 COMMENT 'Total essence invested',
  `times_reset` INT UNSIGNED DEFAULT 0 COMMENT 'How many times reset',
  `acquired_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `last_upgraded_timestamp` TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
  `currently_equipped` TINYINT(1) DEFAULT 0,
  `is_active` TINYINT(1) DEFAULT 1,
  PRIMARY KEY (`player_guid`, `artifact_id`),
  KEY `idx_item_guid` (`item_guid`),
  KEY `idx_upgrade_level` (`upgrade_level`),
  KEY `idx_equipped` (`currently_equipped`),
  CONSTRAINT `fk_artifact_progress` FOREIGN KEY (`artifact_id`) 
    REFERENCES `artifact_items` (`artifact_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_artifact_player` FOREIGN KEY (`player_guid`) 
    REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLE 4: Artifact Set Bonuses (Optional)
-- ============================================================
CREATE TABLE IF NOT EXISTS `artifact_set_bonuses` (
  `set_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `set_name` VARCHAR(255) NOT NULL,
  `set_description` TEXT,
  `pieces_required` TINYINT UNSIGNED NOT NULL,
  `bonus_type` ENUM('STAT_BONUS', 'ABILITY', 'COSMETIC') DEFAULT 'STAT_BONUS',
  `bonus_value` FLOAT DEFAULT 1.0 COMMENT 'Multiplier or percentage',
  `bonus_spell_id` INT UNSIGNED COMMENT 'Aura/buff spell to apply',
  PRIMARY KEY (`set_id`),
  KEY `idx_pieces` (`pieces_required`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### **Step 1.2: Add Tier 5 Upgrade Costs**

```sql
-- Add Artifact (Tier 5) costs to existing upgrade system
INSERT INTO `dc_item_upgrade_costs` 
  (`tier_id`, `upgrade_level`, `token_cost`, `essence_cost`, `gold_cost`)
VALUES
(5, 1, 0, 500, 0),
(5, 2, 0, 750, 0),
(5, 3, 0, 1000, 0),
(5, 4, 0, 1250, 0),
(5, 5, 0, 1500, 0),
(5, 6, 0, 1750, 0),
(5, 7, 0, 2000, 0),
(5, 8, 0, 2250, 0),
(5, 9, 0, 2500, 0),
(5, 10, 0, 2750, 0),
(5, 11, 0, 3000, 0),
(5, 12, 0, 3250, 0),
(5, 13, 0, 3500, 0),
(5, 14, 0, 3750, 0),
(5, 15, 0, 4000, 0);
```

### **Step 1.3: Create Artifact Essence Item**

```sql
-- Artifact Essence currency (example: item 200001)
INSERT INTO `item_template` (
  `entry`, `class`, `subclass`, `name`, `display_id`, `quality`,
  `flags`, `buy_price`, `sell_price`, `container_slots`,
  `stat_type1`, `stat_value1`, `material`, `bonding`,
  `max_count`, `required_level`, `stackable`, `bag_family`
) VALUES (
  200001,  -- entry
  12,      -- class (ITEM_CLASS_QUEST)
  0,       -- subclass
  'Artifact Essence',
  194438,  -- display_id (generic essence orb)
  7,       -- quality (HEIRLOOM - shows importance)
  0,       -- flags
  0,       -- buy_price
  0,       -- sell_price
  0,       -- container_slots
  0, 0,    -- stats (none - currency)
  -1,      -- material (not applicable)
  0,       -- bonding
  999,     -- max_count (stackable)
  1,       -- required_level
  999,     -- stackable (max stack)
  0        -- bag_family
);
```

### **Step 1.4: Create Sample Artifacts**

```sql
-- Artifact 1: Worldforged Claymore (Weapon)
INSERT INTO `artifact_items` (
  `item_template_id`, `artifact_type`, `artifact_name`,
  `lore_description`, `special_ability`, `tier_id`
) VALUES (
  191001,
  'WEAPON',
  'Worldforged Claymore',
  'A legendary blade forged in the essence of chaos itself. Scales with the wielder.',
  'Increases all damage by 20% when fully upgraded',
  5
);

-- Artifact 2: Worldforged Tunic (Shirt - cosmetic/optional buff)
INSERT INTO `artifact_items` (
  `item_template_id`, `artifact_type`, `artifact_name`,
  `lore_description`, `special_ability`, `tier_id`
) VALUES (
  191002,
  'SHIRT',
  'Worldforged Tunic',
  'Mystical garments woven from chaos energy. Improves with wear.',
  'Grants 10% experience boost when fully upgraded',
  5
);

-- Artifact 3: Worldforged Satchel (Bag - growing storage)
INSERT INTO `artifact_items` (
  `item_template_id`, `artifact_type`, `artifact_name`,
  `lore_description`, `special_ability`, `tier_id`
) VALUES (
  191003,
  'BAG',
  'Worldforged Satchel',
  'An interdimensional container that expands as it\'s imbued with chaos essence.',
  'Scales to 36 slots at maximum level',
  5
);
```

### **Step 1.5: Add Loot Locations**

```sql
-- Example: Worldforged Claymore drops in Scholomance
INSERT INTO `artifact_loot_locations` (
  `artifact_id`, `map_id`, `zone_id`,
  `x`, `y`, `z`, `orientation`,
  `gameobject_entry`, `respawn_time_sec`,
  `loot_description`, `difficulty`, `location_name`
) VALUES (
  1,         -- Worldforged Claymore
  289,       -- Scholomance map
  2057,      -- Scholomance zone
  260.0, 312.0, 123.0, 0.0,
  2000005,   -- Treasure chest object
  3600,      -- 1 hour respawn
  'Gleaming Chest',
  'HEROIC',
  'Scholomance - Worldforged Claymore'
);

-- Example: Worldforged Tunic from quest completion (non-loot)
-- (Would be given via quest reward system)

-- Example: Worldforged Satchel as special drop
INSERT INTO `artifact_loot_locations` (
  `artifact_id`, `map_id`, `zone_id`,
  `x`, `y`, `z`, `orientation`,
  `gameobject_entry`, `respawn_time_sec`,
  `loot_description`, `difficulty`, `location_name`
) VALUES (
  3,         -- Worldforged Satchel
  289,       -- Scholomance
  2057,      -- Scholomance zone
  310.0, 298.0, 123.0, 0.0,
  2000006,   -- Different chest
  7200,      -- 2 hour respawn (rarer)
  'Ancient Coffer',
  'HEROIC',
  'Scholomance - Worldforged Satchel'
);
```

---

## 🎯 PHASE 2: C++ IMPLEMENTATION (4-6 hours)

### **Step 2.1: Create Core Artifact Manager**

Create file: `src/server/scripts/DC/Artifacts/ArtifactManager.h`

```cpp
#pragma once

#include "Define.h"
#include "Common.h"
#include <unordered_map>
#include <memory>

namespace DarkChaos {
namespace Artifacts {

    // Artifact type enumeration
    enum ArtifactType : uint8
    {
        ARTIFACT_TYPE_WEAPON = 1,
        ARTIFACT_TYPE_SHIRT = 2,
        ARTIFACT_TYPE_BAG = 3,
        ARTIFACT_TYPE_TRINKET = 4
    };

    // Artifact data structure
    struct ArtifactDefinition
    {
        uint32 artifact_id;
        uint32 item_template_id;
        ArtifactType artifact_type;
        std::string artifact_name;
        std::string lore_description;
        std::string special_ability;
        uint8 tier_id = 5;
        uint8 max_upgrade_level = 15;
        uint32 essence_type_id = 200001;  // Default essence item ID
        bool is_active = true;

        ArtifactDefinition() {}
    };

    // Player artifact progress
    struct PlayerArtifactProgress
    {
        uint32 player_guid;
        uint32 artifact_id;
        uint32 item_guid;
        uint8 upgrade_level = 0;
        uint32 essence_spent = 0;
        time_t acquired_timestamp;
        time_t last_upgraded_timestamp;
        bool currently_equipped = false;

        PlayerArtifactProgress() 
            : player_guid(0), artifact_id(0), item_guid(0),
              acquired_timestamp(time(nullptr)), 
              last_upgraded_timestamp(0) {}
    };

    // Manager class for artifact system
    class ArtifactManager
    {
    public:
        ArtifactManager();
        ~ArtifactManager();

        // Singleton
        static ArtifactManager* instance();

        // Load all artifact definitions from database
        void LoadArtifacts();

        // Get artifact definition
        ArtifactDefinition const* GetArtifact(uint32 artifact_id) const;
        ArtifactDefinition const* GetArtifactByItemTemplate(uint32 item_template_id) const;

        // Player progress tracking
        PlayerArtifactProgress* GetPlayerArtifact(uint32 player_guid, uint32 artifact_id);
        void SavePlayerArtifactProgress(uint32 player_guid, uint32 artifact_id, const PlayerArtifactProgress& progress);

        // Upgrade handling
        bool CanUpgradeArtifact(uint32 player_guid, uint32 artifact_id, uint32& out_essence_required);
        bool UpgradeArtifact(uint32 player_guid, uint32 artifact_id, uint32 item_guid);

        // Essence tracking
        uint32 GetPlayerEssence(uint32 player_guid) const;
        bool SpendEssence(uint32 player_guid, uint32 amount);
        void AddEssence(uint32 player_guid, uint32 amount);

        // Enchantment management
        uint32 CalculateUpgradeEnchantId(uint8 tier_id, uint8 upgrade_level) const;
        void ApplyArtifactEnchant(Player* player, Item* item, uint8 upgrade_level);
        void RemoveArtifactEnchant(Player* player, Item* item, uint8 old_upgrade_level);

    private:
        std::unordered_map<uint32, ArtifactDefinition> m_artifacts_by_id;
        std::unordered_map<uint32, uint32> m_item_template_to_artifact_id;
        std::unordered_map<uint32, std::unordered_map<uint32, PlayerArtifactProgress>> m_player_progress;
    };

    #define sArtifactMgr ArtifactManager::instance()

} // namespace Artifacts
} // namespace DarkChaos
```

### **Step 2.2: Implement Artifact Manager**

Create file: `src/server/scripts/DC/Artifacts/ArtifactManager.cpp`

```cpp
#include "ArtifactManager.h"
#include "Player.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "DatabaseEnv.h"
#include "WorldSession.h"
#include "Log.h"
#include "Common.h"

using namespace DarkChaos::Artifacts;

ArtifactManager* ArtifactManager::instance()
{
    static ArtifactManager instance;
    return &instance;
}

ArtifactManager::ArtifactManager()
{
    LOG_INFO("scripts", "ArtifactManager initialized");
}

ArtifactManager::~ArtifactManager()
{
    m_artifacts_by_id.clear();
    m_item_template_to_artifact_id.clear();
    m_player_progress.clear();
}

void ArtifactManager::LoadArtifacts()
{
    m_artifacts_by_id.clear();
    m_item_template_to_artifact_id.clear();

    QueryResult result = WorldDatabase.Query(
        "SELECT artifact_id, item_template_id, artifact_type, artifact_name, "
        "lore_description, special_ability, tier_id, max_upgrade_level, "
        "essence_type_id, is_active FROM artifact_items WHERE is_active = 1"
    );

    if (!result)
    {
        LOG_WARN("scripts", "ArtifactManager: No artifacts loaded from database");
        return;
    }

    uint32 count = 0;
    do
    {
        Field* fields = result->Fetch();
        ArtifactDefinition def;

        def.artifact_id = fields[0].GetUInt32();
        def.item_template_id = fields[1].GetUInt32();
        def.artifact_type = static_cast<ArtifactType>(fields[2].GetUInt8());
        def.artifact_name = fields[3].GetString();
        def.lore_description = fields[4].GetString();
        def.special_ability = fields[5].GetString();
        def.tier_id = fields[6].GetUInt8();
        def.max_upgrade_level = fields[7].GetUInt8();
        def.essence_type_id = fields[8].GetUInt32();
        def.is_active = fields[9].GetUInt8() == 1;

        m_artifacts_by_id[def.artifact_id] = def;
        m_item_template_to_artifact_id[def.item_template_id] = def.artifact_id;

        ++count;
    } while (result->NextRow());

    LOG_INFO("scripts", "ArtifactManager: Loaded {} artifacts", count);
}

ArtifactDefinition const* ArtifactManager::GetArtifact(uint32 artifact_id) const
{
    auto it = m_artifacts_by_id.find(artifact_id);
    if (it != m_artifacts_by_id.end())
        return &it->second;
    return nullptr;
}

ArtifactDefinition const* ArtifactManager::GetArtifactByItemTemplate(uint32 item_template_id) const
{
    auto it = m_item_template_to_artifact_id.find(item_template_id);
    if (it != m_item_template_to_artifact_id.end())
        return GetArtifact(it->second);
    return nullptr;
}

PlayerArtifactProgress* ArtifactManager::GetPlayerArtifact(uint32 player_guid, uint32 artifact_id)
{
    auto& player_artifacts = m_player_progress[player_guid];
    auto it = player_artifacts.find(artifact_id);
    if (it != player_artifacts.end())
        return &it->second;
    return nullptr;
}

void ArtifactManager::SavePlayerArtifactProgress(uint32 player_guid, uint32 artifact_id, const PlayerArtifactProgress& progress)
{
    CharacterDatabase.Execute(
        "UPDATE player_artifact_data SET upgrade_level = {}, essence_spent = {}, "
        "last_upgraded_timestamp = NOW(), currently_equipped = {} "
        "WHERE player_guid = {} AND artifact_id = {}",
        progress.upgrade_level, progress.essence_spent, progress.currently_equipped ? 1 : 0,
        player_guid, artifact_id
    );
}

uint32 ArtifactManager::CalculateUpgradeEnchantId(uint8 tier_id, uint8 upgrade_level) const
{
    // Enchant ID = 300003 + (tier_id * 100) + upgrade_level
    // Tier 5, Level 1 = 80501
    // Tier 5, Level 15 = 80515
    return 300003 + (tier_id * 100) + upgrade_level;
}

void ArtifactManager::ApplyArtifactEnchant(Player* player, Item* item, uint8 upgrade_level)
{
    if (!player || !item || upgrade_level == 0)
        return;

    ArtifactDefinition const* def = GetArtifactByItemTemplate(item->GetTemplate()->ItemId);
    if (!def)
        return;

    uint32 enchant_id = CalculateUpgradeEnchantId(def->tier_id, upgrade_level);

    // Apply to TEMP_ENCHANTMENT_SLOT
    item->SetEnchantment(TEMP_ENCHANTMENT_SLOT, enchant_id, 0, 0);
    player->ApplyEnchantment(item, TEMP_ENCHANTMENT_SLOT, true);

    LOG_DEBUG("scripts", "ArtifactManager: Applied enchant {} to item {} (tier {}, level {})",
        enchant_id, item->GetGUID().GetCounter(), def->tier_id, upgrade_level);
}

void ArtifactManager::RemoveArtifactEnchant(Player* player, Item* item, uint8 old_upgrade_level)
{
    if (!player || !item)
        return;

    uint32 old_enchant_id = item->GetEnchantmentId(TEMP_ENCHANTMENT_SLOT);
    if (old_enchant_id >= 300003 && old_enchant_id < 90000)
    {
        player->ApplyEnchantment(item, TEMP_ENCHANTMENT_SLOT, false);
        item->ClearEnchantment(TEMP_ENCHANTMENT_SLOT);
    }
}

bool ArtifactManager::CanUpgradeArtifact(uint32 player_guid, uint32 artifact_id, uint32& out_essence_required)
{
    ArtifactDefinition const* def = GetArtifact(artifact_id);
    if (!def)
        return false;

    PlayerArtifactProgress* progress = GetPlayerArtifact(player_guid, artifact_id);
    if (!progress || progress->upgrade_level >= def->max_upgrade_level)
        return false;

    // Query essence cost for next level
    QueryResult result = WorldDatabase.Query(
        "SELECT essence_cost FROM dc_item_upgrade_costs "
        "WHERE tier_id = {} AND upgrade_level = {}",
        def->tier_id, progress->upgrade_level + 1
    );

    if (!result)
        return false;

    out_essence_required = result->Fetch()[0].GetUInt32();

    // Check if player has enough essence
    uint32 player_essence = GetPlayerEssence(player_guid);
    return player_essence >= out_essence_required;
}

bool ArtifactManager::UpgradeArtifact(uint32 player_guid, uint32 artifact_id, uint32 item_guid)
{
    ArtifactDefinition const* def = GetArtifact(artifact_id);
    if (!def)
        return false;

    PlayerArtifactProgress* progress = GetPlayerArtifact(player_guid, artifact_id);
    if (!progress || progress->upgrade_level >= def->max_upgrade_level)
        return false;

    uint32 essence_required = 0;
    if (!CanUpgradeArtifact(player_guid, artifact_id, essence_required))
        return false;

    // Spend essence
    if (!SpendEssence(player_guid, essence_required))
        return false;

    // Update progress
    progress->upgrade_level++;
    progress->essence_spent += essence_required;
    progress->last_upgraded_timestamp = time(nullptr);

    SavePlayerArtifactProgress(player_guid, artifact_id, *progress);

    LOG_INFO("scripts", "ArtifactManager: Player {} upgraded artifact {} to level {} (cost: {} essence)",
        player_guid, artifact_id, progress->upgrade_level, essence_required);

    return true;
}

uint32 ArtifactManager::GetPlayerEssence(uint32 player_guid) const
{
    // Query player essence count from character_inventory
    // Assuming essence item ID is 200001
    QueryResult result = CharacterDatabase.Query(
        "SELECT COUNT(*) FROM character_inventory "
        "WHERE guid = {} AND item = 200001",
        player_guid
    );

    if (!result)
        return 0;

    return result->Fetch()[0].GetUInt32();
}

bool ArtifactManager::SpendEssence(uint32 player_guid, uint32 amount)
{
    // This should be integrated with player currency system
    // For now, assume it works via item destruction
    Player* player = ObjectAccessor::FindPlayerByGUID(nullptr, ObjectGuid(HighGuid::Player, player_guid));
    if (!player)
        return false;

    uint32 remaining = amount;
    for (auto [bag, slot] : player->IterateInventorySlots())
    {
        Item* item = player->GetItemByPos(bag, slot);
        if (!item || item->GetTemplate()->ItemId != 200001)
            continue;

        uint32 count = item->GetCount();
        uint32 to_destroy = std::min(count, remaining);
        player->DestroyItem(bag, slot, true);
        remaining -= to_destroy;

        if (remaining == 0)
            return true;
    }

    return remaining == 0;
}

void ArtifactManager::AddEssence(uint32 player_guid, uint32 amount)
{
    Player* player = ObjectAccessor::FindPlayerByGUID(nullptr, ObjectGuid(HighGuid::Player, player_guid));
    if (!player)
        return;

    player->AddItem(200001, amount);  // Artifact Essence item ID
}
```

### **Step 2.3: Create Artifact Equip Script**

Create file: `src/server/scripts/DC/Artifacts/ArtifactEquipScript.cpp`

```cpp
#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "ArtifactManager.h"

using namespace DarkChaos::Artifacts;

class ArtifactEquipScript : public PlayerScript
{
public:
    ArtifactEquipScript() : PlayerScript("ArtifactEquipScript") { }

    void OnPlayerEquip(Player* player, Item* item, uint8 /*bag*/, uint8 /*slot*/, bool /*update*/) override
    {
        if (!player || !item)
            return;

        ArtifactDefinition const* def = sArtifactMgr->GetArtifactByItemTemplate(item->GetTemplate()->ItemId);
        if (!def)
            return;  // Not an artifact

        // Get player's artifact progress
        PlayerArtifactProgress* progress = sArtifactMgr->GetPlayerArtifact(player->GetGUID().GetCounter(), def->artifact_id);
        if (!progress)
        {
            // First time equipping, create progress entry
            PlayerArtifactProgress newProgress;
            newProgress.player_guid = player->GetGUID().GetCounter();
            newProgress.artifact_id = def->artifact_id;
            newProgress.item_guid = item->GetGUID().GetCounter();
            newProgress.currently_equipped = true;

            CharacterDatabase.Execute(
                "INSERT INTO player_artifact_data "
                "(player_guid, artifact_id, item_guid, upgrade_level, currently_equipped) "
                "VALUES ({}, {}, {}, 0, 1)",
                newProgress.player_guid, newProgress.artifact_id, newProgress.item_guid
            );

            progress = sArtifactMgr->GetPlayerArtifact(player->GetGUID().GetCounter(), def->artifact_id);
        }

        if (!progress || progress->upgrade_level == 0)
            return;  // No upgrade yet, no enchant to apply

        // Apply artifact enchant
        sArtifactMgr->ApplyArtifactEnchant(player, item, progress->upgrade_level);
    }

    void OnPlayerUnequip(Player* player, Item* item, uint8 /*bag*/, uint8 /*slot*/, bool /*update*/) override
    {
        if (!player || !item)
            return;

        ArtifactDefinition const* def = sArtifactMgr->GetArtifactByItemTemplate(item->GetTemplate()->ItemId);
        if (!def)
            return;

        PlayerArtifactProgress* progress = sArtifactMgr->GetPlayerArtifact(player->GetGUID().GetCounter(), def->artifact_id);
        if (!progress)
            return;

        // Remove artifact enchant
        sArtifactMgr->RemoveArtifactEnchant(player, item, progress->upgrade_level);

        // Update database
        CharacterDatabase.Execute(
            "UPDATE player_artifact_data SET currently_equipped = 0 "
            "WHERE player_guid = {} AND artifact_id = {}",
            player->GetGUID().GetCounter(), def->artifact_id
        );
    }
};

void AddSC_ArtifactEquipScript()
{
    new ArtifactEquipScript();
}
```

---

## 📱 PHASE 3: ADDON UI UPDATES (2-3 hours)

### **Step 3.1: Update Addon Display**

Modify file: `Custom/Client addons needed/DC-ItemUpgrade/DarkChaos_ItemUpgrade_Retail.lua`

Add artifact detection and special display:

```lua
-- At the top of the file, add artifact detection
local ARTIFACT_TIER = 5
local ARTIFACT_ESSENCE_ID = 200001

-- In the tooltip building section, add:
local function IsArtifactItem(item)
    if not item or not item.tier then return false end
    return item.tier == ARTIFACT_TIER
end

-- Modify stat display for artifacts
local function GetArtifactStatDisplay(item, statMultiplier)
    if not IsArtifactItem(item) then
        return nil  -- Not an artifact, use regular display
    end
    
    local statBonus = (statMultiplier - 1.0) * 100.0
    local essenceInvested = item.essenceInvested or 0
    local maxEssence = 30250  -- Total to max level 15
    
    return string.format(
        "|cffff8000[ARTIFACT]|r\n" ..
        "  Essence Invested: |cff00ff00%u / %u|r (%.1f%%)\n" ..
        "  Upgrade Level: |cff00ff00%u / 15|r\n" ..
        "  All Stats: |cff00ff00+%.1f%%|r",
        essenceInvested, maxEssence,
        (essenceInvested / maxEssence) * 100.0,
        item.upgradeLevel or 0,
        statBonus
    )
end

-- Add artifact-specific tooltip hook
local originalSetItemTooltip = ItemTooltip.SetItem or function() end
function ItemTooltip:SetItem(item, ...)
    originalSetItemTooltip(self, item, ...)
    
    if IsArtifactItem(item) then
        -- Add artifact special display
        local artifactDisplay = GetArtifactStatDisplay(item, item.statMultiplier or 1.0)
        if artifactDisplay then
            GameTooltip:AddLine("")
            GameTooltip:AddLine(artifactDisplay)
        end
        
        -- Show upgrade requirements
        if item.upgradeLevel < 15 then
            local essenceRequired = GetNextEssenceCost(item.tier, item.upgradeLevel)
            GameTooltip:AddLine("")
            GameTooltip:AddLine("Next Upgrade:")
            GameTooltip:AddLine(string.format("  Essence Required: |cff00ff00%u|r", essenceRequired), 0.8, 0.8, 0.8)
        end
    end
end
```

---

## ✅ PHASE 4: TESTING & VALIDATION (3-5 hours)

### **Test Checklist:**

- [ ] Artifacts load correctly from database
- [ ] Loot detection recognizes artifact items
- [ ] Heirloom scaling applies to artifact weapons
- [ ] Primary stats scale with player level
- [ ] Enchants apply on equip
- [ ] Enchants remove on unequip
- [ ] Secondary stats show +% bonus in tooltips
- [ ] Essence currency can be earned/spent
- [ ] Upgrades properly increase stat multiplier
- [ ] UI displays artifact info correctly
- [ ] Bag slot scaling works on artifact bags
- [ ] Multiple artifacts can be equipped simultaneously
- [ ] Progress persists across logout/login
- [ ] Max level (15) prevents further upgrades

---

## 🎬 PHASE 5: CONFIGURATION & DEPLOYMENT (1-2 hours)

### **Pre-Launch Checklist:**

- [ ] All SQL tables created and populated
- [ ] C++ code compiled without errors
- [ ] Addon loaded without conflicts
- [ ] Essence item ID set correctly (200001)
- [ ] Tier 5 costs configured in database
- [ ] Artifact items created with proper flags
- [ ] Loot locations set in world
- [ ] Testing complete on test server
- [ ] Documentation updated
- [ ] Rollback plan prepared

---

## 💾 QUICK SQL REFERENCE

```sql
-- Check artifact definitions
SELECT * FROM artifact_items WHERE is_active = 1;

-- Check player progress
SELECT * FROM player_artifact_data WHERE player_guid = <player_id>;

-- Check essence costs
SELECT * FROM dc_item_upgrade_costs WHERE tier_id = 5;

-- Check artifact loot locations
SELECT * FROM artifact_loot_locations WHERE is_enabled = 1;

-- Update artifact
UPDATE artifact_items SET special_ability = 'New ability' WHERE artifact_id = 1;

-- Reset player progress
DELETE FROM player_artifact_data WHERE player_guid = <player_id>;
```

---

## 🚀 RECOMMENDED FIRST ARTIFACT

**Worldforged Claymore - Complete Setup**

```sql
-- 1. Item template
INSERT INTO item_template (entry, class, subclass, name, display_id, quality, 
flags, inv_type, required_level, item_level, stat_type1, stat_value1, 
scaling_stat_distribution) VALUES (
  191001, 2, 13, 'Worldforged Claymore', 79000, 7,
  1024, 45, 1, 50, 5, 250, 298
);

-- 2. Artifact definition
INSERT INTO artifact_items (item_template_id, artifact_type, artifact_name, 
lore_description, special_ability) VALUES (
  191001, 'WEAPON', 'Worldforged Claymore',
  'A legendary blade forged from chaos itself.',
  'Increases all damage by 20% when fully upgraded'
);

-- 3. Loot location
INSERT INTO artifact_loot_locations (artifact_id, map_id, zone_id, x, y, z, 
gameobject_entry, location_name) VALUES (
  1, 289, 2057, 260.0, 312.0, 123.0, 2000005, 'Scholomance - Claymore'
);
```

---

**Total Estimated Implementation Time: 11-17 hours**  
**Difficulty: Medium-High**  
**Risk: Low**

Ready to implement?

