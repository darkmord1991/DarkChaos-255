/*
 * Giant Isles - Script Loader
 * ============================================================================
 * Registers all Giant Isles scripts with the AzerothCore script system
 * ============================================================================
 */

#ifndef GIANT_ISLES_SCRIPT_LOADER_H
#define GIANT_ISLES_SCRIPT_LOADER_H

// Zone and general scripts
void AddSC_giant_isles_zone();
void AddSC_giant_isles_cannon_quest();
void AddSC_giant_isles_invasion();
void AddSC_giant_isles_water_monster();

// World Boss scripts
void AddSC_boss_oondasta();
void AddSC_boss_thok();
void AddSC_boss_nalak();

// Master loader function
inline void AddGiantIslesScripts()
{
    // Zone scripts (announcements, area triggers, etc.)
    AddSC_giant_isles_zone();

    // Cannon quest event
    AddSC_giant_isles_cannon_quest();

    // Water monster event
    AddSC_giant_isles_water_monster();

    // Zandalari invasion event
    // AddSC_giant_isles_invasion();
    // Disabled for now: invasion script needs a rewrite (random spawns).

    // World Boss: Oondasta - King of Dinosaurs
    AddSC_boss_oondasta();

    // World Boss: Thok the Bloodthirsty
    AddSC_boss_thok();

    // World Boss: Nalak the Storm Lord
    AddSC_boss_nalak();
}

#endif // GIANT_ISLES_SCRIPT_LOADER_H
