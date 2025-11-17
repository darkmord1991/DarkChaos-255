# Heirloom System: Customizable Secondary Stats with 255-Level Progression

**Date:** November 16, 2025  
**Status:** DESIGN DOCUMENT  
**Complexity:** Advanced  
**Recommendation:** ⭐⭐⭐ Extremely Unique - Player Choice + Deep Progression

---

## Executive Summary

This design allows players to:

1. **Choose secondary stats** they want on their heirlooms (Crit, Haste, Mastery, etc.)
2. **Upgrade each stat independently** from Level 1 to Level 255
3. **Respec/reforge** stats at a cost (essence refund system)
4. **Mix and match** different stat combinations per item

### Example Player Experience:

```
Player equips Heirloom Flamefury Blade (Level 80)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PRIMARY STATS (auto-scale with level):
+85 Strength      (from heirloom scaling)
+70 Stamina       (from heirloom scaling)

SECONDARY STATS (player-chosen & upgraded):
┌────────────────────────────────────────┐
│ ⭐ Critical Strike: Level 50 → +125    │  ← Player chose this stat
│    (Cost to upgrade to 51: 150 essence)│
│                                         │
│ ⚡ Haste: Level 30 → +75               │  ← Player chose this stat
│    (Cost to upgrade to 31: 95 essence) │
│                                         │
│ 🎯 Mastery: Level 20 → +50             │  ← Player chose this stat
│    (Cost to upgrade to 21: 65 essence) │
└────────────────────────────────────────┘

[Upgrade Critical Strike] [Upgrade Haste] [Upgrade Mastery]
[Add New Stat] [Respec Stats (50% refund)]
```

---

## Technical Architecture

### Database Schema

#### Table 1: Heirloom Secondary Stat Slots (Per Item Instance)

```sql
-- Tracks which secondary stats a player has chosen for each heirloom
CREATE TABLE IF NOT EXISTS dc_heirloom_secondary_stats (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    item_guid INT UNSIGNED NOT NULL,              -- Item instance GUID
    player_guid INT UNSIGNED NOT NULL,             -- Owner
    stat_type TINYINT UNSIGNED NOT NULL,           -- Stat type (32=Crit, 36=Haste, etc)
    stat_level TINYINT UNSIGNED NOT NULL DEFAULT 1,-- Level of this stat (1-255)
    stat_value INT UNSIGNED NOT NULL,              -- Current stat value (calculated)
    essence_invested INT UNSIGNED NOT NULL,        -- Total essence spent on this stat
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_item_stat (item_guid, stat_type),
    KEY idx_player (player_guid),
    KEY idx_item (item_guid)
);

-- Example data:
-- item_guid=171714, player_guid=1, stat_type=32 (Crit), stat_level=50, stat_value=125, essence_invested=2358
-- item_guid=171714, player_guid=1, stat_type=36 (Haste), stat_level=30, stat_value=75, essence_invested=890
-- item_guid=171714, player_guid=1, stat_type=47 (Mastery), stat_level=20, stat_value=50, essence_invested=445
```

#### Table 2: Secondary Stat Cost Configuration

```sql
-- Defines the essence cost for each stat level (1-255)
CREATE TABLE IF NOT EXISTS dc_heirloom_stat_level_costs (
    stat_level TINYINT UNSIGNED NOT NULL PRIMARY KEY,
    essence_cost INT UNSIGNED NOT NULL,            -- Cost to reach this level
    stat_multiplier FLOAT NOT NULL,                -- Stat value multiplier
    
    -- Formula: base_value * stat_multiplier
    -- Level 1: 1.0x (no bonus)
    -- Level 50: 2.5x (150% bonus)
    -- Level 100: 5.0x (400% bonus)
    -- Level 255: 12.75x (1175% bonus)
);

-- Populate with escalating costs (logarithmic curve for 255 levels)
INSERT INTO dc_heirloom_stat_level_costs (stat_level, essence_cost, stat_multiplier) VALUES
-- Early levels: cheap
(1, 10, 1.00),       -- 10 essence total
(2, 11, 1.05),       -- 21 essence total
(3, 12, 1.10),       -- 33 essence total
(5, 15, 1.20),       -- 75 essence total (5 levels)
(10, 25, 1.45),      -- 190 essence total (10 levels)
(20, 50, 1.95),      -- 445 essence total (20 levels)
(30, 80, 2.45),      -- 890 essence total (30 levels)
(50, 150, 3.45),     -- 2,358 essence total (50 levels)
(75, 280, 4.95),     -- 6,200 essence total (75 levels)
(100, 500, 6.45),    -- 15,000 essence total (100 levels)
(150, 1000, 9.45),   -- 50,000 essence total (150 levels)
(200, 2000, 12.45),  -- 150,000 essence total (200 levels)
(255, 5000, 15.75);  -- 500,000 essence total (255 levels - MAX)

-- Total to max ONE stat to 255: ~500,000 essence
-- Players will typically have 2-3 stats upgraded moderately (levels 30-80 range)
```

#### Table 3: Available Secondary Stats Configuration

```sql
-- Defines which secondary stats players can choose from
CREATE TABLE IF NOT EXISTS dc_heirloom_available_secondary_stats (
    stat_type TINYINT UNSIGNED PRIMARY KEY,
    stat_name VARCHAR(50) NOT NULL,
    stat_description TEXT,
    base_value INT UNSIGNED NOT NULL,              -- Base value per level at 1.0x multiplier
    max_slots_per_item TINYINT UNSIGNED DEFAULT 3, -- Max secondary stats per heirloom
    is_enabled BOOLEAN DEFAULT TRUE,
    
    -- stat_type values from ItemModType enum:
    -- 32 = ITEM_MOD_CRIT_RATING
    -- 36 = ITEM_MOD_HASTE_RATING
    -- 37 = ITEM_MOD_EXPERTISE_RATING
    -- 31 = ITEM_MOD_HIT_RATING
    -- 35 = ITEM_MOD_RESILIENCE_RATING
    -- 44 = ITEM_MOD_ARMOR_PENETRATION_RATING
    -- 13 = ITEM_MOD_DODGE_RATING
    -- 14 = ITEM_MOD_PARRY_RATING
    -- 15 = ITEM_MOD_BLOCK_RATING
    -- 47 = ITEM_MOD_SPELL_PENETRATION (Mastery equivalent)
);

INSERT INTO dc_heirloom_available_secondary_stats (stat_type, stat_name, stat_description, base_value) VALUES
(32, 'Critical Strike', 'Increases your chance to critically strike', 5),
(36, 'Haste', 'Increases attack and cast speed', 5),
(37, 'Expertise', 'Reduces chance to be dodged or parried', 5),
(31, 'Hit', 'Increases chance to hit with attacks and spells', 5),
(35, 'Resilience', 'Reduces damage and effects from critical strikes', 5),
(44, 'Armor Penetration', 'Ignores target armor', 5),
(13, 'Dodge', 'Increases chance to dodge attacks', 4),
(14, 'Parry', 'Increases chance to parry attacks', 4),
(15, 'Block', 'Increases chance to block attacks', 4),
(47, 'Mastery', 'Increases mastery rating', 5);

-- Example calculation:
-- Crit at Level 50: base_value (5) × stat_multiplier (3.45) = 17.25 → 17 rating per point
-- At level 50 with 50 points invested: 17 × 50 = 850 crit rating total
```

#### Table 4: Stat Respec Log

```sql
-- Tracks when players respec their heirloom stats
CREATE TABLE IF NOT EXISTS dc_heirloom_stat_respec_log (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_guid INT UNSIGNED NOT NULL,
    item_guid INT UNSIGNED NOT NULL,
    old_stats JSON,                                 -- JSON array of old stat config
    new_stats JSON,                                 -- JSON array of new stat config
    essence_refunded INT UNSIGNED NOT NULL,         -- 50% of total essence refunded
    respec_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    KEY idx_player (player_guid),
    KEY idx_item (item_guid)
);

-- Example JSON format:
-- old_stats: [{"stat_type":32,"level":50,"value":125},{"stat_type":36,"level":30,"value":75}]
-- new_stats: [{"stat_type":32,"level":80,"value":200},{"stat_type":37,"level":10,"value":25}]
```

---

## Implementation: Enchantment-Based System

### How It Works

Instead of using **gem sockets** (which have a 3-slot limit and require gem items), we use **dynamic enchantments** that store stat data directly on the item.

#### Enchantment Slot Usage

```
PERM_ENCHANTMENT_SLOT (0)     → NOT USED (reserved for weapon enchants)
TEMP_ENCHANTMENT_SLOT (1)     → Heirloom Secondary Stat Slot 1
PROP_ENCHANTMENT_SLOT_0 (6)   → Heirloom Secondary Stat Slot 2
PROP_ENCHANTMENT_SLOT_1 (7)   → Heirloom Secondary Stat Slot 3
```

#### Enchantment ID Encoding

Since we need to store **both stat type AND level**, we encode this information:

```
Enchantment ID Formula: 90000 + (stat_type × 1000) + stat_level

Examples:
- Crit (32) Level 50:     90000 + (32 × 1000) + 50  = 90032050
- Haste (36) Level 30:    90000 + (36 × 1000) + 30  = 90036030
- Mastery (47) Level 100: 90000 + (47 × 1000) + 100 = 90047100

Decoding:
- enchant_id = 90032050
- stat_type = (90032050 - 90000) / 1000 = 32 (Crit)
- stat_level = (90032050 - 90000) % 1000 = 50
```

#### Server-Side Application (C++)

```cpp
// File: src/server/scripts/DC/ItemUpgrades/ItemUpgradeHeirloomSecondaryStats.cpp

#include "ScriptMgr.h"
#include "Player.h"
#include "Item.h"
#include "DatabaseEnv.h"
#include "ItemUpgradeManager.h"

namespace DarkChaos
{
    namespace HeirloomStats
    {
        // Enchantment slot assignments for secondary stats
        const EnchantmentSlot SECONDARY_STAT_SLOTS[3] = {
            TEMP_ENCHANTMENT_SLOT,      // Slot 1
            PROP_ENCHANTMENT_SLOT_0,    // Slot 2
            PROP_ENCHANTMENT_SLOT_1     // Slot 3
        };

        /**
         * Decode enchantment ID to get stat type and level
         */
        struct StatEnchantInfo
        {
            uint8 stat_type;
            uint8 stat_level;
            bool is_valid;
        };

        StatEnchantInfo DecodeEnchantID(uint32 enchant_id)
        {
            StatEnchantInfo info = {0, 0, false};
            
            if (enchant_id < 90000000 || enchant_id > 90255255)
                return info; // Invalid range
            
            uint32 encoded = enchant_id - 90000000;
            info.stat_type = (encoded / 1000);
            info.stat_level = (encoded % 1000);
            info.is_valid = (info.stat_level >= 1 && info.stat_level <= 255);
            
            return info;
        }

        /**
         * Encode stat type and level into enchantment ID
         */
        uint32 EncodeStatToEnchantID(uint8 stat_type, uint8 stat_level)
        {
            return 90000000 + (stat_type * 1000) + stat_level;
        }

        /**
         * Calculate stat value based on type, level, and multiplier
         */
        uint32 CalculateStatValue(uint8 stat_type, uint8 stat_level)
        {
            // Query from dc_heirloom_stat_level_costs
            QueryResult result = WorldDatabase.Query(
                "SELECT stat_multiplier FROM dc_heirloom_stat_level_costs WHERE stat_level = {}", 
                stat_level
            );
            
            if (!result)
                return 0;
            
            float multiplier = result->Fetch()[0].Get<float>();
            
            // Query base value from dc_heirloom_available_secondary_stats
            result = WorldDatabase.Query(
                "SELECT base_value FROM dc_heirloom_available_secondary_stats WHERE stat_type = {}", 
                stat_type
            );
            
            if (!result)
                return 0;
            
            uint32 base_value = result->Fetch()[0].Get<uint32>();
            
            // Calculate: base_value * multiplier * level
            return static_cast<uint32>(base_value * multiplier * stat_level);
        }

        /**
         * Apply secondary stats to equipped heirloom
         */
        void ApplyHeirloomSecondaryStats(Player* player, Item* item)
        {
            if (!player || !item)
                return;

            ItemTemplate const* proto = item->GetTemplate();
            if (!proto || proto->Quality != ITEM_QUALITY_HEIRLOOM)
                return;

            uint32 item_guid = item->GetGUID().GetCounter();

            // Query player's chosen secondary stats for this item
            QueryResult result = CharacterDatabase.Query(
                "SELECT stat_type, stat_level FROM dc_heirloom_secondary_stats "
                "WHERE item_guid = {} AND player_guid = {} ORDER BY id ASC",
                item_guid, player->GetGUID().GetCounter()
            );

            if (!result)
                return;

            uint8 slot_index = 0;
            do
            {
                if (slot_index >= 3) // Max 3 secondary stats
                    break;

                Field* fields = result->Fetch();
                uint8 stat_type = fields[0].Get<uint8>();
                uint8 stat_level = fields[1].Get<uint8>();

                // Encode into enchantment ID
                uint32 enchant_id = EncodeStatToEnchantID(stat_type, stat_level);

                // Remove old enchantment
                if (item->GetEnchantmentId(SECONDARY_STAT_SLOTS[slot_index]))
                {
                    player->ApplyEnchantment(item, SECONDARY_STAT_SLOTS[slot_index], false);
                    item->ClearEnchantment(SECONDARY_STAT_SLOTS[slot_index]);
                }

                // Apply new enchantment
                item->SetEnchantment(SECONDARY_STAT_SLOTS[slot_index], enchant_id, 0, 0);
                player->ApplyEnchantment(item, SECONDARY_STAT_SLOTS[slot_index], true);

                slot_index++;
            } while (result->NextRow());

            // Force stat update
            player->UpdateAllStats();
        }

        /**
         * Upgrade a specific secondary stat on an heirloom
         */
        bool UpgradeSecondaryStat(Player* player, Item* item, uint8 stat_type)
        {
            if (!player || !item)
                return false;

            uint32 item_guid = item->GetGUID().GetCounter();
            uint32 player_guid = player->GetGUID().GetCounter();

            // Get current level of this stat
            QueryResult result = CharacterDatabase.Query(
                "SELECT stat_level, essence_invested FROM dc_heirloom_secondary_stats "
                "WHERE item_guid = {} AND player_guid = {} AND stat_type = {}",
                item_guid, player_guid, stat_type
            );

            uint8 current_level = 0;
            uint32 essence_invested = 0;

            if (result)
            {
                Field* fields = result->Fetch();
                current_level = fields[0].Get<uint8>();
                essence_invested = fields[1].Get<uint32>();
            }

            // Check max level
            if (current_level >= 255)
                return false; // Already maxed

            uint8 next_level = current_level + 1;

            // Get upgrade cost
            result = WorldDatabase.Query(
                "SELECT essence_cost FROM dc_heirloom_stat_level_costs WHERE stat_level = {}",
                next_level
            );

            if (!result)
                return false;

            uint32 essence_cost = result->Fetch()[0].Get<uint32>();

            // Check if player has enough essence (via ItemUpgrade currency system)
            // TODO: Integrate with existing dc_player_currencies table
            // For now, assume player has essence

            // Deduct essence
            // TODO: Call ItemUpgrade::RemoveCurrency()

            // Calculate new stat value
            uint32 new_stat_value = CalculateStatValue(stat_type, next_level);

            // Update database
            if (current_level == 0)
            {
                // Insert new stat
                CharacterDatabase.Execute(
                    "INSERT INTO dc_heirloom_secondary_stats "
                    "(item_guid, player_guid, stat_type, stat_level, stat_value, essence_invested) "
                    "VALUES ({}, {}, {}, {}, {}, {})",
                    item_guid, player_guid, stat_type, next_level, new_stat_value, essence_cost
                );
            }
            else
            {
                // Update existing stat
                CharacterDatabase.Execute(
                    "UPDATE dc_heirloom_secondary_stats "
                    "SET stat_level = {}, stat_value = {}, essence_invested = essence_invested + {} "
                    "WHERE item_guid = {} AND player_guid = {} AND stat_type = {}",
                    next_level, new_stat_value, essence_cost, 
                    item_guid, player_guid, stat_type
                );
            }

            // Re-apply enchantments
            ApplyHeirloomSecondaryStats(player, item);

            return true;
        }

        /**
         * Respec all secondary stats on an heirloom (50% essence refund)
         */
        bool RespecSecondaryStats(Player* player, Item* item)
        {
            if (!player || !item)
                return false;

            uint32 item_guid = item->GetGUID().GetCounter();
            uint32 player_guid = player->GetGUID().GetCounter();

            // Get total essence invested
            QueryResult result = CharacterDatabase.Query(
                "SELECT SUM(essence_invested) FROM dc_heirloom_secondary_stats "
                "WHERE item_guid = {} AND player_guid = {}",
                item_guid, player_guid
            );

            if (!result)
                return false;

            uint32 total_essence = result->Fetch()[0].Get<uint32>();
            uint32 refund_essence = total_essence / 2; // 50% refund

            // Log the respec
            // TODO: Insert into dc_heirloom_stat_respec_log

            // Remove all secondary stats
            CharacterDatabase.Execute(
                "DELETE FROM dc_heirloom_secondary_stats "
                "WHERE item_guid = {} AND player_guid = {}",
                item_guid, player_guid
            );

            // Refund essence
            // TODO: Call ItemUpgrade::AddCurrency(player_guid, CURRENCY_ARTIFACT_ESSENCE, refund_essence)

            // Remove enchantments
            for (uint8 i = 0; i < 3; i++)
            {
                if (item->GetEnchantmentId(SECONDARY_STAT_SLOTS[i]))
                {
                    player->ApplyEnchantment(item, SECONDARY_STAT_SLOTS[i], false);
                    item->ClearEnchantment(SECONDARY_STAT_SLOTS[i]);
                }
            }

            // Update stats
            player->UpdateAllStats();

            return true;
        }

    } // namespace HeirloomStats
} // namespace DarkChaos
```

---

## Client-Side Implementation (Lua Addon)

### UI Design: Heirloom Enhancement Window

```lua
-- File: Custom/Client addons needed/DC-ItemUpgrade/DarkChaos_HeirloomEnhancement.lua

local DC = DarkChaos_ItemUpgrade or {};
DC.HeirloomEnhancement = {};

-- Available secondary stats (sync with server)
local AVAILABLE_STATS = {
    {type = 32, name = "Critical Strike", icon = "Interface\\Icons\\Ability_CriticalStrike"},
    {type = 36, name = "Haste", icon = "Interface\\Icons\\Spell_Nature_Invisibility"},
    {type = 37, name = "Expertise", icon = "Interface\\Icons\\Spell_Holy_BlessingOfStrength"},
    {type = 31, name = "Hit", icon = "Interface\\Icons\\Ability_Marksmanship"},
    {type = 35, name = "Resilience", icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing"},
    {type = 44, name = "Armor Penetration", icon = "Interface\\Icons\\Ability_Warrior_BloodFrenzy"},
    {type = 13, name = "Dodge", icon = "Interface\\Icons\\Ability_Rogue_Feint"},
    {type = 14, name = "Parry", icon = "Interface\\Icons\\Ability_Parry"},
    {type = 15, name = "Block", icon = "Interface\\Icons\\Ability_Defend"},
    {type = 47, name = "Mastery", icon = "Interface\\Icons\\Spell_Nature_Polymorph"},
};

-- Parse message from server
function DC.HeirloomEnhancement.OnServerMessage(message)
    -- Expected format: "HEIRLOOM_STATS|item_guid|stat_type:level:value|stat_type:level:value|..."
    -- Example: "HEIRLOOM_STATS|171714|32:50:125|36:30:75|47:20:50"
    
    local parts = {strsplit("|", message)};
    if parts[1] ~= "HEIRLOOM_STATS" then
        return;
    end
    
    local item_guid = tonumber(parts[2]);
    local stats = {};
    
    for i = 3, #parts do
        local stat_data = {strsplit(":", parts[i])};
        table.insert(stats, {
            type = tonumber(stat_data[1]),
            level = tonumber(stat_data[2]),
            value = tonumber(stat_data[3]),
        });
    end
    
    DC.HeirloomEnhancement.currentItemGuid = item_guid;
    DC.HeirloomEnhancement.currentStats = stats;
    DC.HeirloomEnhancement.UpdateUI();
end

-- Show enhancement UI
function DC.HeirloomEnhancement.Show(item_link)
    if not DarkChaos_HeirloomEnhancementFrame then
        DC.HeirloomEnhancement.CreateUI();
    end
    
    -- Request current stats from server
    SendChatMessage(".heirloom getstats " .. item_link, "GUILD");
    
    DarkChaos_HeirloomEnhancementFrame:Show();
end

-- Create UI frame
function DC.HeirloomEnhancement.CreateUI()
    local frame = CreateFrame("Frame", "DarkChaos_HeirloomEnhancementFrame", UIParent);
    frame:SetSize(400, 600);
    frame:SetPoint("CENTER");
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11},
    });
    frame:EnableMouse(true);
    frame:SetMovable(true);
    frame:RegisterForDrag("LeftButton");
    frame:SetScript("OnDragStart", function(self) self:StartMoving(); end);
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); end);
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
    title:SetPoint("TOP", 0, -20);
    title:SetText("Heirloom Enhancement");
    
    -- Current stats display (3 slots)
    frame.statSlots = {};
    for i = 1, 3 do
        local slot = CreateFrame("Frame", nil, frame);
        slot:SetSize(360, 80);
        slot:SetPoint("TOP", 0, -60 - (i - 1) * 90);
        slot:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = {left = 4, right = 4, top = 4, bottom = 4},
        });
        slot:SetBackdropColor(0.1, 0.1, 0.1, 0.8);
        
        -- Stat icon
        slot.icon = slot:CreateTexture(nil, "ARTWORK");
        slot.icon:SetSize(48, 48);
        slot.icon:SetPoint("LEFT", 10, 0);
        
        -- Stat name
        slot.name = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal");
        slot.name:SetPoint("TOPLEFT", slot.icon, "TOPRIGHT", 10, 0);
        slot.name:SetText("Empty Slot");
        
        -- Stat level
        slot.level = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
        slot.level:SetPoint("TOPLEFT", slot.name, "BOTTOMLEFT", 0, -5);
        slot.level:SetText("Level 0 / 255");
        
        -- Stat value
        slot.value = slot:CreateFontString(nil, "OVERLAY", "GameFontGreen");
        slot.value:SetPoint("TOPLEFT", slot.level, "BOTTOMLEFT", 0, -5);
        slot.value:SetText("+0 Rating");
        
        -- Upgrade button
        slot.upgradeBtn = CreateFrame("Button", nil, slot, "GameMenuButtonTemplate");
        slot.upgradeBtn:SetSize(100, 25);
        slot.upgradeBtn:SetPoint("RIGHT", -10, 0);
        slot.upgradeBtn:SetText("Upgrade");
        slot.upgradeBtn:SetScript("OnClick", function()
            DC.HeirloomEnhancement.UpgradeStat(i);
        end);
        
        frame.statSlots[i] = slot;
    end
    
    -- Add stat button
    local addBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate");
    addBtn:SetSize(150, 30);
    addBtn:SetPoint("BOTTOM", 0, 80);
    addBtn:SetText("Add New Stat");
    addBtn:SetScript("OnClick", function()
        DC.HeirloomEnhancement.ShowStatSelector();
    end);
    
    -- Respec button
    local respecBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate");
    respecBtn:SetSize(150, 30);
    respecBtn:SetPoint("BOTTOM", 0, 40);
    respecBtn:SetText("Respec (50% refund)");
    respecBtn:SetScript("OnClick", function()
        DC.HeirloomEnhancement.RespecStats();
    end);
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
    closeBtn:SetPoint("TOPRIGHT", -5, -5);
end

-- Update UI with current stats
function DC.HeirloomEnhancement.UpdateUI()
    if not DC.HeirloomEnhancement.currentStats then
        return;
    end
    
    local stats = DC.HeirloomEnhancement.currentStats;
    local frame = DarkChaos_HeirloomEnhancementFrame;
    
    for i = 1, 3 do
        local slot = frame.statSlots[i];
        
        if stats[i] then
            -- Find stat info
            local stat_info = nil;
            for _, s in ipairs(AVAILABLE_STATS) do
                if s.type == stats[i].type then
                    stat_info = s;
                    break;
                end
            end
            
            if stat_info then
                slot.icon:SetTexture(stat_info.icon);
                slot.name:SetText(stat_info.name);
                slot.level:SetText(string.format("Level %d / 255", stats[i].level));
                slot.value:SetText(string.format("+%d Rating", stats[i].value));
                slot.upgradeBtn:Enable();
            end
        else
            -- Empty slot
            slot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");
            slot.name:SetText("Empty Slot");
            slot.level:SetText("No stat selected");
            slot.value:SetText("");
            slot.upgradeBtn:Disable();
        end
    end
end

-- Upgrade stat (send command to server)
function DC.HeirloomEnhancement.UpgradeStat(slot_index)
    if not DC.HeirloomEnhancement.currentStats then
        return;
    end
    
    local stat = DC.HeirloomEnhancement.currentStats[slot_index];
    if not stat then
        return;
    end
    
    -- Send upgrade command to server
    SendChatMessage(string.format(".heirloom upgrade %d %d", 
        DC.HeirloomEnhancement.currentItemGuid, stat.type), "GUILD");
end

-- Respec all stats
function DC.HeirloomEnhancement.RespecStats()
    if not DC.HeirloomEnhancement.currentItemGuid then
        return;
    end
    
    -- Confirmation dialog
    StaticPopup_Show("HEIRLOOM_RESPEC_CONFIRM");
end

-- Stat selector dialog
function DC.HeirloomEnhancement.ShowStatSelector()
    -- TODO: Create UI to select from AVAILABLE_STATS
    print("Stat selector UI (to be implemented)");
end
```

---

## Player Experience Examples

### Scenario 1: New Heirloom Acquisition

```
Player loots Heirloom Flamefury Blade from treasure
→ Item has PRIMARY stats that scale with level (Str, Sta)
→ Item has NO secondary stats initially
→ Right-click item → "Enhance Heirloom"
→ UI shows 3 empty slots
→ Click "Add New Stat"
→ Select "Critical Strike" from list
→ Confirm (costs 10 essence)
→ Critical Strike now at Level 1 (+5 rating)
```

### Scenario 2: Upgrading a Stat

```
Player wants more Critical Strike
→ Open enhancement UI
→ See: Critical Strike - Level 50 (+125 rating)
→ Click "Upgrade" next to Critical Strike
→ Cost displayed: 150 essence
→ Confirm
→ Critical Strike now Level 51 (+130 rating)
→ Character sheet updates instantly
```

### Scenario 3: Respeccing

```
Player switches from DPS to Tank spec
→ Needs to change Crit/Haste to Dodge/Parry
→ Open enhancement UI
→ Click "Respec (50% refund)"
→ Confirmation: "Refund 25,000 essence (50% of 50,000 invested)?"
→ Confirm
→ All secondary stats removed
→ 25,000 essence returned
→ Start adding Dodge and Parry from Level 1
```

### Scenario 4: Min-Maxing

```
Hardcore player with 500,000 essence saved
→ Wants to maximize ONE stat to Level 255
→ Open enhancement UI
→ Add Critical Strike
→ Spam "Upgrade" button 255 times (or bulk upgrade)
→ Critical Strike reaches Level 255 (+3,937 rating!)
→ Item tooltip shows: "⭐ Critical Strike: Level 255 → +3,937"
→ Character becomes crit-focused specialist
```

---

## Scaling Formula

### Stat Value Calculation

```
Formula: base_value × stat_multiplier × stat_level

Example (Critical Strike at Level 50):
- base_value = 5 (from dc_heirloom_available_secondary_stats)
- stat_multiplier = 3.45 (from dc_heirloom_stat_level_costs for Level 50)
- stat_level = 50
- Result: 5 × 3.45 × 50 = 862.5 → 862 crit rating

Example (Critical Strike at Level 255):
- base_value = 5
- stat_multiplier = 15.75 (max multiplier)
- stat_level = 255
- Result: 5 × 15.75 × 255 = 20,081.25 → 20,081 crit rating
```

### Essence Cost Curve

```
Logarithmic progression to prevent linear grinding:

Levels 1-10:   ~10-25 essence per level
Levels 11-30:  ~30-80 essence per level
Levels 31-75:  ~100-280 essence per level
Levels 76-150: ~300-1,000 essence per level
Levels 151-255: ~1,500-5,000 essence per level

Total to max ONE stat: ~500,000 essence
Typical player with 3 stats at Level 50-80: ~15,000-40,000 essence total
```

---

## Technical Challenges & Solutions

### Challenge 1: Enchantment ID Limits

**Problem:** WoW 3.3.5a has limited enchantment ID space.  
**Solution:** Use range 90,000,000 - 90,255,255 (256M possible combinations)

### Challenge 2: Client-Side Stat Display

**Problem:** Client needs to show custom stat values.  
**Solution:** Server sends stat data via chat message, addon parses and displays in custom UI

### Challenge 3: Database Performance

**Problem:** Querying stat data on every equip could be slow.  
**Solution:**
- Cache stat data in memory (C++ std::map)
- Only query database on login, upgrade, or respec
- Use indexed queries (item_guid, player_guid)

### Challenge 4: Stat Rebalancing

**Problem:** Future updates may need stat value adjustments.  
**Solution:**
- Store formulas in database (dc_heirloom_stat_level_costs)
- Update multipliers without touching character data
- Re-apply enchantments on next login

---

## Implementation Roadmap

### Phase 1: Database & Core (Week 1)
- [ ] Create 4 database tables
- [ ] Populate dc_heirloom_stat_level_costs (255 rows)
- [ ] Populate dc_heirloom_available_secondary_stats (10 stats)
- [ ] Test table relationships and indexes

### Phase 2: C++ Backend (Week 2-3)
- [ ] Create ItemUpgradeHeirloomSecondaryStats.cpp
- [ ] Implement EncodeStatToEnchantID() / DecodeEnchantID()
- [ ] Implement ApplyHeirloomSecondaryStats()
- [ ] Implement UpgradeSecondaryStat()
- [ ] Implement RespecSecondaryStats()
- [ ] Add chat command handlers (.heirloom upgrade, .heirloom respec)
- [ ] Integrate with existing ItemUpgrade currency system

### Phase 3: Lua Addon (Week 4)
- [ ] Create DarkChaos_HeirloomEnhancement.lua
- [ ] Build enhancement UI frame
- [ ] Parse server messages
- [ ] Add stat selector dropdown
- [ ] Add upgrade confirmation dialogs
- [ ] Add respec confirmation dialog
- [ ] Integrate with main DC-ItemUpgrade addon

### Phase 4: Testing & Balance (Week 5)
- [ ] Test stat application on equip/unequip
- [ ] Test upgrade cost calculation
- [ ] Test respec functionality
- [ ] Balance essence costs for 255 levels
- [ ] Test with all 10 available stats
- [ ] Test with multiple heirlooms

### Phase 5: Polish & Release (Week 6)
- [ ] Add tooltips explaining system
- [ ] Add visual effects for upgrades
- [ ] Add sound effects
- [ ] Create player guide
- [ ] Deploy to live server

**Total Estimate:** 6 weeks (with 2-3 developers)

---

## Advantages of This System

1. **Deep Progression:** 255 levels per stat = endless grind potential
2. **Player Choice:** Choose which stats matter for your build
3. **Respec Flexibility:** Not locked into decisions (50% refund)
4. **Alt-Friendly:** Heirlooms are BoA, so alts benefit from upgrades
5. **No Item Bloat:** One heirloom serves all specs with respec
6. **Economic Sink:** Essence currency sink prevents inflation
7. **Unique System:** Unlike any other WoW private server

---

## Future Expansions

### Expansion 1: Stat Presets

```sql
-- Save/load stat configurations
CREATE TABLE dc_heirloom_stat_presets (
    preset_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_guid INT UNSIGNED NOT NULL,
    preset_name VARCHAR(50) NOT NULL,
    stat_config JSON,  -- Array of {stat_type, level}
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Example: "DPS Build", "Tank Build", "PvP Build"
-- One-click swap between presets
```

### Expansion 2: Stat Synergy Bonuses

```sql
-- Bonus effects when combining certain stats
CREATE TABLE dc_heirloom_stat_synergies (
    synergy_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    stat_type_1 TINYINT UNSIGNED NOT NULL,
    stat_type_2 TINYINT UNSIGNED NOT NULL,
    min_level_required TINYINT UNSIGNED DEFAULT 50,
    bonus_description TEXT,
    bonus_stat_type TINYINT UNSIGNED,
    bonus_value INT UNSIGNED
);

-- Example: Crit (Level 50+) + Haste (Level 50+) = +10% damage bonus
```

### Expansion 3: Essence Farming Optimization

```sql
-- Track essence sources and optimize farming routes
CREATE TABLE dc_heirloom_essence_sources (
    source_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    source_type VARCHAR(50),  -- 'quest', 'dungeon', 'raid', 'daily'
    essence_reward INT UNSIGNED,
    completion_time_minutes INT UNSIGNED,
    efficiency_score FLOAT  -- essence per hour
);

-- Addon shows: "Best essence farm: Heroic ICC (200 essence/hour)"
```

---

## Conclusion

This design provides:

- ✅ **Player choice** in secondary stat customization
- ✅ **255-level progression** per stat (scalable to max level)
- ✅ **Respec flexibility** with 50% essence refund
- ✅ **Client recognition** via enchantment system
- ✅ **Deep progression** for hardcore players
- ✅ **Alt-friendly** via BoA heirlooms
- ✅ **Economic sink** via essence costs

**Next Steps:**
1. Review and approve design
2. Decide on essence cost curve (current curve reaches 500K for max stat)
3. Begin Phase 1 (database schema creation)

---

**Author:** GitHub Copilot  
**Design Date:** November 16, 2025  
**Status:** Ready for Implementation
