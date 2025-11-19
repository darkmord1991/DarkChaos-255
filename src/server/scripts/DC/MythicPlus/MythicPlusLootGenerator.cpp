/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 * 
 * Mythic+ Boss Loot Generation System
 * Generates spec-appropriate loot for Mythic+ dungeons (retail-like)
 */

#include "MythicPlusRunManager.h"
#include "MythicPlusRewards.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "Log.h"
#include "LootMgr.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "Group.h"
#include <algorithm>
#include <random>
#include <vector>

namespace DarkChaos
{
    namespace MythicPlus
    {
        // Helper: Get player's current talent spec
        std::string GetPlayerSpecForLoot(Player* player)
        {
            if (!player)
                return "Unknown";
            
            uint8 classId = player->getClass();
            uint8 primaryTree = player->GetMostPointsTalentTree();
            
            switch (classId)
            {
                case CLASS_WARRIOR:
                    if (primaryTree == 0) return "Arms";
                    if (primaryTree == 1) return "Fury";
                    return "Protection";
                case CLASS_PALADIN:
                    if (primaryTree == 0) return "Holy";
                    if (primaryTree == 1) return "Protection";
                    return "Retribution";
                case CLASS_HUNTER:
                    if (primaryTree == 0) return "Beast Mastery";
                    if (primaryTree == 1) return "Marksmanship";
                    return "Survival";
                case CLASS_ROGUE:
                    if (primaryTree == 0) return "Assassination";
                    if (primaryTree == 1) return "Combat";
                    return "Subtlety";
                case CLASS_PRIEST:
                    if (primaryTree == 0) return "Discipline";
                    if (primaryTree == 1) return "Holy";
                    return "Shadow";
                case CLASS_DEATH_KNIGHT:
                    if (primaryTree == 0) return "Blood";
                    if (primaryTree == 1) return "Frost";
                    return "Unholy";
                case CLASS_SHAMAN:
                    if (primaryTree == 0) return "Elemental";
                    if (primaryTree == 1) return "Enhancement";
                    return "Restoration";
                case CLASS_MAGE:
                    if (primaryTree == 0) return "Arcane";
                    if (primaryTree == 1) return "Fire";
                    return "Frost";
                case CLASS_WARLOCK:
                    if (primaryTree == 0) return "Affliction";
                    if (primaryTree == 1) return "Demonology";
                    return "Destruction";
                case CLASS_DRUID:
                    if (primaryTree == 0) return "Balance";
                    if (primaryTree == 1) return "Feral Combat";
                    return "Restoration";
                default:
                    return "Unknown";
            }
        }

        // Helper: Get player's armor type
        std::string GetPlayerArmorTypeForLoot(Player* player)
        {
            if (!player)
                return "Misc";
            
            switch (player->getClass())
            {
                case CLASS_WARRIOR:
                case CLASS_PALADIN:
                case CLASS_DEATH_KNIGHT:
                    return "Plate";
                case CLASS_HUNTER:
                case CLASS_SHAMAN:
                    return "Mail";
                case CLASS_ROGUE:
                case CLASS_DRUID:
                    return "Leather";
                case CLASS_PRIEST:
                case CLASS_MAGE:
                case CLASS_WARLOCK:
                    return "Cloth";
                default:
                    return "Misc";
            }
        }

        // Helper: Get role mask for player
        uint8 GetPlayerRoleMask(Player* player)
        {
            if (!player)
                return 7; // Universal
            
            uint8 classId = player->getClass();
            uint8 primaryTree = player->GetMostPointsTalentTree();
            
            // 1=Tank, 2=Healer, 4=DPS
            switch (classId)
            {
                case CLASS_WARRIOR:
                    return (primaryTree == 2) ? 1 : 4; // Protection = Tank, others = DPS
                case CLASS_PALADIN:
                    if (primaryTree == 0) return 2; // Holy = Healer
                    if (primaryTree == 1) return 1; // Protection = Tank
                    return 4; // Retribution = DPS
                case CLASS_HUNTER:
                    return 4; // Always DPS
                case CLASS_ROGUE:
                    return 4; // Always DPS
                case CLASS_PRIEST:
                    return (primaryTree == 2) ? 4 : 2; // Shadow = DPS, others = Healer
                case CLASS_DEATH_KNIGHT:
                    return (primaryTree == 0) ? 1 : 4; // Blood = Tank, others = DPS
                case CLASS_SHAMAN:
                    return (primaryTree == 2) ? 2 : 4; // Restoration = Healer, others = DPS
                case CLASS_MAGE:
                    return 4; // Always DPS
                case CLASS_WARLOCK:
                    return 4; // Always DPS
                case CLASS_DRUID:
                    if (primaryTree == 0) return 4; // Balance = DPS
                    if (primaryTree == 2) return 2; // Restoration = Healer
                    return 5; // Feral = Tank + DPS (role_mask 5)
                default:
                    return 7; // Universal
            }
        }

        void MythicPlusRunManager::GenerateBossLoot(Creature* boss, Map* map, InstanceState* state)
        {
            if (!boss || !map || !state)
                return;

            // Check if loot generation is enabled
            if (!sConfigMgr->GetOption<bool>("MythicPlus.BossLoot.Enabled", true))
                return;

            // Get keystone level for item level calculation
            uint32 targetItemLevel = GetItemLevelForKeystoneLevel(state->keystoneLevel);
            
            // Get all eligible players
            std::vector<Player*> eligiblePlayers;
            Map::PlayerList const& players = map->GetPlayers();
            for (auto const& ref : players)
            {
                Player* player = ref.GetSource();
                if (player && state->participants.find(player->GetGUID().GetCounter()) != state->participants.end())
                    eligiblePlayers.push_back(player);
            }

            if (eligiblePlayers.empty())
                return;

            // Determine loot count based on boss type
            uint32 itemsToGenerate = IsFinalBoss(state->mapId, boss->GetEntry()) ? 2 : 1;
            
            LOG_INFO("mythic.loot", "Generating {} items for boss {} (entry {}) at ilvl {} for {} players",
                itemsToGenerate, boss->GetName(), boss->GetEntry(), targetItemLevel, eligiblePlayers.size());

            // Generate items for random players
            std::random_device rd;
            std::mt19937 gen(rd());
            std::shuffle(eligiblePlayers.begin(), eligiblePlayers.end(), gen);

            uint32 itemsGenerated = 0;
            for (uint32 i = 0; i < itemsToGenerate && i < eligiblePlayers.size(); ++i)
            {
                Player* player = eligiblePlayers[i];
                if (!player)
                    continue;

                // Get player's spec/class info
                std::string playerSpec = GetPlayerSpecForLoot(player);
                std::string armorType = GetPlayerArmorTypeForLoot(player);
                uint8 classId = player->getClass();
                uint8 roleMask = GetPlayerRoleMask(player);

                // Query eligible items from loot table
                QueryResult result = WorldDatabase.Query(
                    "SELECT item_id FROM dc_vault_loot_table "
                    "WHERE ((class_mask & {}) OR class_mask = 1023) "
                    "AND (spec_name = '{}' OR spec_name IS NULL) "
                    "AND (armor_type = '{}' OR armor_type = 'Misc') "
                    "AND ((role_mask & {}) OR role_mask = 7) "
                    "AND item_level_min <= {} AND item_level_max >= {} "
                    "ORDER BY RAND() LIMIT 1",
                    (1 << (classId - 1)), playerSpec, armorType, roleMask, targetItemLevel, targetItemLevel);

                if (!result)
                {
                    LOG_WARN("mythic.loot", "No eligible items found for player {} (class {}, spec {}, armor {}, role {}, ilvl {})",
                        player->GetName(), classId, playerSpec, armorType, roleMask, targetItemLevel);
                    continue;
                }

                Field* fields = result->Fetch();
                uint32 itemId = fields[0].Get<uint32>();

                // Add item to boss loot
                ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId);
                if (!itemTemplate)
                {
                    LOG_ERROR("mythic.loot", "Invalid item template for item {}", itemId);
                    continue;
                }

                // Create loot item
                LootStoreItem storeItem(itemId, 0, 100.0f, 0, 1, 1, 1);
                boss->loot.AddItem(storeItem);
                
                // Set item level on the generated item
                // Note: This requires item scaling which may need additional hooks
                
                itemsGenerated++;

                LOG_INFO("mythic.loot", "Generated item {} ({}) for player {} at ilvl {}",
                    itemId, itemTemplate->Name1, player->GetName(), targetItemLevel);

                // Send notification to player
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "|cff00ff00[Mythic+]|r %s dropped: |cff0070dd[%s]|r (ilvl %u)", 
                    boss->GetName().c_str(), itemTemplate->Name1, targetItemLevel);
            }

            LOG_INFO("mythic.loot", "Generated {} items for boss {} (requested: {})",
                itemsGenerated, boss->GetName(), itemsToGenerate);
        }

    } // namespace MythicPlus
} // namespace DarkChaos
