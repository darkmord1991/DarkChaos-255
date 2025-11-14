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

// Creature script to apply scaling when creatures spawn
class MythicPlusCreatureScript : public AllCreatureScript
{
public:
    MythicPlusCreatureScript() : AllCreatureScript("MythicPlusCreatureScript") { }

    void OnCreatureAddWorld(Creature* creature) override
    {
        if (!creature)
            return;

        Map* map = creature->GetMap();
        if (!map || !map->IsDungeon())
            return;

        // Apply Mythic scaling
        sMythicScaling->ScaleCreature(creature, map);
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
