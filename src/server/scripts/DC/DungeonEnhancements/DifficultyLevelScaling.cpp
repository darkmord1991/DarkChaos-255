/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
 * Dark Chaos - Difficulty Level Scaling
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "Map.h"
#include "InstanceScript.h"

class DifficultyLevelScaling : public AllCreatureScript
{
public:
    DifficultyLevelScaling() : AllCreatureScript("DifficultyLevelScaling") {}

    void OnAllCreatureUpdate(Creature* creature, uint32 /*diff*/) override
    {
        // Only process once when creature is first loaded
        if (creature->GetHealthPct() < 100.0f)
            return;

        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon())
            return;

        Difficulty difficulty = map->GetDifficulty();
        uint8 baseLevel = creature->GetLevel();

        // Don't scale creatures that are already max level
        if (baseLevel >= 80)
            return;

        uint8 newLevel = baseLevel;
        bool isRaid = map->IsRaid();

        if (isRaid)
        {
            // Raid difficulty handling
            switch (difficulty)
            {
                case RAID_DIFFICULTY_10MAN_NORMAL:
                case RAID_DIFFICULTY_25MAN_NORMAL:
                    // 10/25N: Keep base level for raids
                    newLevel = baseLevel;
                    break;

                case RAID_DIFFICULTY_10MAN_HEROIC:
                case RAID_DIFFICULTY_25MAN_HEROIC:
                    // 10/25H: Scale to 80 or boost by 3 levels
                    newLevel = std::max<uint8>(baseLevel + 3, 80);
                    break;

                case RAID_DIFFICULTY_10MAN_MYTHIC:
                case RAID_DIFFICULTY_25MAN_MYTHIC:
                    // Mythic raids: Force level 80
                    newLevel = 80;
                    break;

                default:
                    newLevel = baseLevel;
                    break;
            }
        }
        else
        {
            // Dungeon difficulty handling
            switch (difficulty)
            {
                case DUNGEON_DIFFICULTY_NORMAL:
                    // Keep base level for Normal
                    newLevel = baseLevel;
                    break;

                case DUNGEON_DIFFICULTY_HEROIC:
                    // Heroic: scale to 80 or boost by 5 levels
                    newLevel = std::max<uint8>(baseLevel + 5, 80);
                    break;

                case DUNGEON_DIFFICULTY_EPIC:
                case DUNGEON_DIFFICULTY_MYTHIC:
                    // Mythic: Force level 80
                    newLevel = 80;
                    break;

                case DUNGEON_DIFFICULTY_MYTHIC_PLUS:
                    // Mythic+: Force level 80
                    newLevel = 80;
                    break;

                default:
                    // For any other difficulty, force level 80
                    if (difficulty >= 4)
                    {
                        newLevel = 80;
                    }
                    break;
            }
        }

        if (newLevel != baseLevel)
        {
            creature->SetLevel(newLevel);
            
            // Optional: Scale stats proportionally
            float scaleFactor = float(newLevel) / float(baseLevel);
            
            // Scale health
            uint32 baseMaxHealth = creature->GetCreateHealth();
            uint32 newMaxHealth = uint32(baseMaxHealth * scaleFactor);
            creature->SetCreateHealth(newMaxHealth);
            creature->SetMaxHealth(newMaxHealth);
            creature->SetHealth(newMaxHealth);
            
            // Scale damage (approximately)
            float baseDamageMin = creature->GetCreatureTemplate()->mindmg;
            float baseDamageMax = creature->GetCreatureTemplate()->maxdmg;
            creature->SetBaseWeaponDamage(BASE_ATTACK, MINDAMAGE, baseDamageMin * scaleFactor);
            creature->SetBaseWeaponDamage(BASE_ATTACK, MAXDAMAGE, baseDamageMax * scaleFactor);
            
            // Scale armor (approximately)
            uint32 baseArmor = creature->GetCreatureTemplate()->armor;
            creature->SetArmor(uint32(baseArmor * scaleFactor));
        }
    }
};

// Alternate approach: Scale based on map ID for specific dungeons
class MythicDungeonLevelScaling : public AllMapScript
{
public:
    MythicDungeonLevelScaling() : AllMapScript("MythicDungeonLevelScaling") {}

    void OnPlayerEnterMap(Map* map, Player* player) override
    {
        if (!map->IsDungeon())
            return;

        // Season 1 Mythic dungeons - force level 80
        uint32 mapId = map->GetId();
        std::vector<uint32> mythicMaps = {
            574,  // Utgarde Keep
            575,  // Utgarde Pinnacle
            576,  // The Nexus
            578,  // The Oculus
            542,  // Blood Furnace
            543,  // Hellfire Ramparts
            329,  // Stratholme
            36    // Deadmines
        };

        if (std::find(mythicMaps.begin(), mythicMaps.end(), mapId) != mythicMaps.end())
        {
            // Scale all creatures in this map to level 80
            // This would be called for each player entering
            // You'd need to iterate through creatures or use a flag
        }
    }
};

void AddSC_difficulty_level_scaling()
{
    new DifficultyLevelScaling();
    new MythicDungeonLevelScaling();
}
