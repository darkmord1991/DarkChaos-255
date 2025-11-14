/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 */

#include "ScriptMgr.h"
#include "MythicDifficultyScaling.h"
#include "Creature.h"
#include "Map.h"
#include "Log.h"

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

void AddSC_mythic_plus_core_scripts()
{
    new MythicPlusWorldScript();
    new MythicPlusCreatureScript();
}
