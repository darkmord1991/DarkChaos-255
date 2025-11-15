/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "ScriptMgr.h"
#include "AllMapScript.h"
#include "MythicDifficultyScaling.h"
#include "MythicPlusRunManager.h"
#include "MythicPlusAffixes.h"
#include "UnitScript.h"
#include "Unit.h"
#include "Creature.h"
#include "Map.h"
#include "Log.h"
#include "Player.h"
#include "Chat.h"
#include <cmath>
#include <sstream>

// Forward declaration
void RegisterMythicPlusAffixHandlers();

// World script to load dungeon profiles on server startup
class MythicPlusWorldScript : public WorldScript
{
public:
    MythicPlusWorldScript() : WorldScript("MythicPlusWorldScript") { }

    void OnStartup() override
    {
        LOG_INFO("server.loading", ">> Loading Mythic+ system...");
        sMythicScaling->LoadDungeonProfiles();
        sMythicRuns->Reset();
        RegisterMythicPlusAffixHandlers();
        LOG_INFO("server.loading", ">> Mythic+ system loaded successfully");
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
        
        // Apply affix-specific scaling (e.g., Tyrannical, Fortified)
        sAffixMgr->OnCreatureSelectLevel(creature);
    }

    void OnCreatureAddWorld(Creature* creature) override
    {
        // Only process in Mythic difficulty
        if (map->GetDifficulty() != DUNGEON_DIFFICULTY_EPIC)
            return;
        
        // Despawn quest givers
        if (creature->IsQuestGiver())
        {
            LOG_INFO("mythic.scaling", "Despawning quest giver {} (entry {}) in Mythic mode", 
                     creature->GetName(), creature->GetEntry());
            creature->DespawnOrUnsummon();
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

        sMythicRuns->RegisterPlayerEnter(player);

        DungeonProfile* profile = sMythicScaling->GetDungeonProfile(map->GetId());

        auto FormatScalingText = [](float hpMult, float damageMult) -> std::string
        {
            auto percentString = [](float mult) -> std::string
            {
                int32 pct = int32(std::round((mult - 1.0f) * 100.0f));
                std::ostringstream stream;
                if (pct >= 0)
                    stream << "+";
                stream << pct << "%";
                return stream.str();
            };

            std::ostringstream result;
            result << percentString(hpMult) << " HP, " << percentString(damageMult) << " Damage";
            return result.str();
        };

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
                scaling = profile ? FormatScalingText(profile->heroicHealthMult, profile->heroicDamageMult)
                                   : "+15% HP, +10% Damage";
                break;
            case DUNGEON_DIFFICULTY_EPIC:
                diffName = "|cffff8000Mythic|r";
                scaling = profile ? FormatScalingText(profile->mythicHealthMult, profile->mythicDamageMult)
                                   : "+35% HP, +20% Damage";
                break;
            default:
                return; // Don't announce for other difficulties
        }

        // Get dungeon name
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
            
            // Show active affixes
            auto activeAffixes = sAffixMgr->GetActiveAffixes(map);
            if (!activeAffixes.empty())
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cffff8000Active Affixes:|r");
                // TODO: Display affix names
            }
        }
    }
};

// Additional update hook for affix periodic effects
class MythicPlusUpdateScript : public PlayerScript
{
public:
    MythicPlusUpdateScript() : PlayerScript("MythicPlusUpdateScript") { }

    void OnPlayerUpdate(Player* player, uint32 diff)
    {
        if (!player || !player->IsInWorld())
            return;
            
        Map* map = player->GetMap();
        if (!map || !map->IsDungeon())
            return;
            
        // Dispatch to affix handlers for periodic effects (e.g., Grievous)
        sAffixMgr->OnPlayerUpdate(player, diff);
    }
};

class MythicPlusAllMapScript : public AllMapScript
{
public:
    MythicPlusAllMapScript() : AllMapScript("MythicPlusAllMapScript") { }

    void OnDestroyMap(Map* map) override
    {
        if (!map || !map->IsDungeon())
            return;

        sMythicRuns->HandleInstanceReset(map);
        sAffixMgr->DeactivateAffixes(map);
    }
};

class MythicPlusUnitScript : public UnitScript
{
public:
    MythicPlusUnitScript() : UnitScript("MythicPlusUnitScript") { }

    void OnUnitDeath(Unit* unit, Unit* killer) override
    {
        if (!unit)
            return;

        Map* map = unit->GetMap();
        if (!map || !map->IsDungeon())
            return;

        if (Player* player = unit->ToPlayer())
        {
            Creature* creatureKiller = killer ? killer->ToCreature() : nullptr;
            sMythicRuns->HandlePlayerDeath(player, creatureKiller);
            return;
        }

        Creature* creature = unit->ToCreature();
        if (!creature || !creature->IsDungeonBoss())
            return;

        sMythicRuns->HandleBossDeath(creature, killer);
        sAffixMgr->OnCreatureDeath(creature, killer);
    }

    void OnUnitEnterEvadeMode(Unit* unit, uint8 /*evadeReason*/) override
    {
        if (!unit)
            return;

        Creature* creature = unit->ToCreature();
        if (!creature)
            return;

        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon())
            return;

        if (!creature->IsDungeonBoss())
            return;

        sMythicRuns->HandleBossEvade(creature);
    }
    
    void OnDamage(Unit* attacker, Unit* victim, uint32& damage) override
    {
        if (!attacker || !victim || damage == 0)
            return;
            
        Map* map = attacker->GetMap();
        if (!map || !map->IsDungeon())
            return;
            
        // Dispatch to affix handlers
        if (Creature* attackerCreature = attacker->ToCreature())
        {
            if (Player* victimPlayer = victim->ToPlayer())
                sAffixMgr->OnPlayerDamageTaken(victimPlayer, attackerCreature, damage);
            else if (Creature* victimCreature = victim->ToCreature())
                sAffixMgr->OnCreatureDamageTaken(victimCreature, attacker, damage);
                
            sAffixMgr->OnCreatureDamageDone(attackerCreature, victim, damage);
        }
    }
};

void AddSC_mythic_plus_core_scripts()
{
    new MythicPlusWorldScript();
    new MythicPlusCreatureScript();
    new MythicPlusPlayerScript();
    new MythicPlusAllMapScript();
    new MythicPlusUnitScript();
}
