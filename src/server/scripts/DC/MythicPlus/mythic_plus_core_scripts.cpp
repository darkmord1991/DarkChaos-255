/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "ScriptMgr.h"
#include "MythicDifficultyScaling.h"
#include "Creature.h"
#include "Map.h"
#include "Log.h"
#include "Player.h"
#include "Chat.h"

// World script to load dungeon profiles on server startup
class MythicPlusWorldScript : public WorldScript
{
public:
    MythicPlusWorldScript() : WorldScript("MythicPlusWorldScript") { }

    void OnStartup() override
    {
        LOG_INFO("server.loading", ">> Loading Mythic+ system...");
        sMythicScaling->LoadDungeonProfiles();
    }
};

// Creature script to apply scaling DURING SelectLevel (proper way)
class MythicPlusCreatureScript : public AllCreatureScript
{
public:
    MythicPlusCreatureScript() : AllCreatureScript("MythicPlusCreatureScript") { }

    // Hook 1: Modify level BEFORE stats are calculated
    void OnBeforeCreatureSelectLevel(const CreatureTemplate* /*cinfo*/, Creature* creature, uint8& level) override
    {
        if (!creature)
            return;

        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon())
            return;

        // Get dungeon profile
        DungeonProfile* profile = sMythicScaling->GetDungeonProfile(map->GetId());
        if (!profile)
            return;

        Difficulty difficulty = map->GetDifficulty();
        uint32 rank = creature->GetCreatureTemplate()->rank;
        
        // Determine creature type
        bool isBoss = (rank == CREATURE_ELITE_WORLDBOSS || rank == CREATURE_ELITE_RAREELITE);
        bool isElite = (rank == CREATURE_ELITE_ELITE);
        
        uint8 newLevel = level; // Keep original by default
        
        switch (difficulty)
        {
            case DUNGEON_DIFFICULTY_HEROIC:
                // Use database configured levels (0 = keep original)
                if (isBoss && profile->heroicLevelBoss > 0)
                    newLevel = profile->heroicLevelBoss;
                else if (isElite && profile->heroicLevelElite > 0)
                    newLevel = profile->heroicLevelElite;
                else if (profile->heroicLevelNormal > 0)
                    newLevel = profile->heroicLevelNormal;
                break;
                
            case DUNGEON_DIFFICULTY_EPIC: // Mythic
                // Use database configured levels (0 = keep original)
                if (isBoss && profile->mythicLevelBoss > 0)
                    newLevel = profile->mythicLevelBoss;
                else if (isElite && profile->mythicLevelElite > 0)
                    newLevel = profile->mythicLevelElite;
                else if (profile->mythicLevelNormal > 0)
                    newLevel = profile->mythicLevelNormal;
                break;
                
            default:
                break;
        }
        
        // Modify the level reference - this will be used by SelectLevel()
        if (newLevel != level)
        {
            level = newLevel;
        }
    }

    // Hook 2: Modify HP/damage AFTER base stats are calculated
    void OnCreatureSelectLevel(const CreatureTemplate* /*cinfo*/, Creature* creature) override
    {
        if (!creature)
            return;

        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon())
            return;

        // Get dungeon profile
        DungeonProfile* profile = sMythicScaling->GetDungeonProfile(map->GetId());
        if (!profile)
            return;

        Difficulty difficulty = map->GetDifficulty();
        
        // Determine multipliers based on difficulty
        float hpMult = 1.0f;
        float damageMult = 1.0f;
        uint32 keystoneLevel = 0;

        switch (difficulty)
        {
            case DUNGEON_DIFFICULTY_NORMAL:
                // No additional scaling for Normal
                break;
                
            case DUNGEON_DIFFICULTY_HEROIC:
                if (!profile->heroicEnabled)
                    break;
                
                hpMult = profile->heroicHealthMult;
                damageMult = profile->heroicDamageMult;
                break;
                
            case DUNGEON_DIFFICULTY_EPIC: // Mythic
                if (!profile->mythicEnabled)
                    break;
                
                hpMult = profile->mythicHealthMult;
                damageMult = profile->mythicDamageMult;
                
                // Check for Mythic+ keystone
                keystoneLevel = sMythicScaling->GetKeystoneLevel(map);
                if (keystoneLevel > 0)
                {
                    float mplusHpMult = 1.0f;
                    float mplusDamageMult = 1.0f;
                    sMythicScaling->CalculateMythicPlusMultipliers(keystoneLevel, mplusHpMult, mplusDamageMult);
                    
                    hpMult *= mplusHpMult;
                    damageMult *= mplusDamageMult;
                }
                break;
                
            default:
                break;
        }
        
        // Apply multipliers to already-set stats
        if (hpMult > 1.0f || damageMult > 1.0f)
        {
            // Multiply HP
            uint32 baseHealth = creature->GetMaxHealth();
            uint32 newHealth = uint32(baseHealth * hpMult);
            creature->SetCreateHealth(newHealth);
            creature->SetMaxHealth(newHealth);
            creature->SetHealth(newHealth);
            
            // Multiply damage
            float baseMinDamage = creature->GetFloatValue(UNIT_FIELD_MINDAMAGE);
            float baseMaxDamage = creature->GetFloatValue(UNIT_FIELD_MAXDAMAGE);
            creature->SetBaseWeaponDamage(BASE_ATTACK, MINDAMAGE, baseMinDamage * damageMult);
            creature->SetBaseWeaponDamage(BASE_ATTACK, MAXDAMAGE, baseMaxDamage * damageMult);
            
            // Also scale off-hand if exists
            float baseOffhandMin = creature->GetFloatValue(UNIT_FIELD_MINOFFHANDDAMAGE);
            if (baseOffhandMin > 0.0f)
            {
                float baseOffhandMax = creature->GetFloatValue(UNIT_FIELD_MAXOFFHANDDAMAGE);
                creature->SetBaseWeaponDamage(OFF_ATTACK, MINDAMAGE, baseOffhandMin * damageMult);
                creature->SetBaseWeaponDamage(OFF_ATTACK, MAXDAMAGE, baseOffhandMax * damageMult);
            }
            
            LOG_INFO("mythic.scaling", "Scaled creature {} (entry {}) on map {} (difficulty {}) to level {} with {:.2f}x HP ({} -> {}), {:.2f}x Damage",
                      creature->GetName(), creature->GetEntry(), map->GetId(), uint32(difficulty), creature->GetLevel(), 
                      hpMult, uint32(baseHealth), newHealth, damageMult);
        }
    }
};

// Player script to announce difficulty when entering dungeons
class MythicPlusPlayerScript : public PlayerScript
{
public:
    MythicPlusPlayerScript() : PlayerScript("MythicPlusPlayerScript") { }

    void OnPlayerMapChanged(Player* player) override
    {
        if (!player)
            return;

        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
            return;

        // Announce difficulty on dungeon entry
        Difficulty diff = map->GetDifficulty();
        std::string diffName;
        std::string scaling;

        switch (diff)
        {
            case DUNGEON_DIFFICULTY_NORMAL:
                diffName = "|cffffffffNormal|r";
                scaling = "Base creature stats";
                break;
            case DUNGEON_DIFFICULTY_HEROIC:
                diffName = "|cff0070ddHeroic|r";
                scaling = "+15% HP, +10% Damage";
                break;
            case DUNGEON_DIFFICULTY_EPIC:
                diffName = "|cffff8000Mythic|r";
                scaling = "+35% HP, +20% Damage (WotLK) or +200% HP/+100% Damage (Vanilla/TBC)";
                break;
            default:
                return; // Don't announce for other difficulties
        }

        // Get dungeon name
        DungeonProfile* profile = sMythicScaling->GetDungeonProfile(map->GetId());
        std::string dungeonName = profile ? profile->name : "Unknown Dungeon";

        // Send announcement
        ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00=== Dungeon Entered ===");
        ChatHandler(player->GetSession()).SendSysMessage(("Dungeon: |cffffffff" + dungeonName + "|r").c_str());
        ChatHandler(player->GetSession()).SendSysMessage(("Difficulty: " + diffName).c_str());
        ChatHandler(player->GetSession()).SendSysMessage(("Scaling: |cffaaaaaa" + scaling + "|r").c_str());
        
        // Show keystone level if Mythic+
        uint8 keystoneLevel = sMythicScaling->GetKeystoneLevel(map);
        if (keystoneLevel > 0)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Keystone Level: |cffff8000+%u|r", keystoneLevel);
        }
    }
};

void AddSC_mythic_plus_core_scripts()
{
    new MythicPlusWorldScript();
    new MythicPlusCreatureScript();
    new MythicPlusPlayerScript();
}
