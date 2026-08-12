/*
 * Dark Chaos - Addon Extension Loader
 * ====================================
 *
 * Loads all addon extension scripts for the DC namespace.
 *
 * Copyright (C) 2024-2025 Dark Chaos Development Team
 */

// Script declarations
void AddSC_dc_addon_protocol();
void AddSC_dc_addon_aoeloot();
void AddSC_dc_addon_upgrade();
void AddSC_dc_addon_transmutation();
void AddSC_dc_addon_mythicplus();
void AddSC_dc_addon_spectator();
void AddSC_dc_addon_hotspot();
void AddSC_dc_addon_hlbg();
void AddSC_dc_addon_seasons();
void AddSC_dc_addon_leaderboards();
void AddSC_dc_addon_breaking_news();
void AddSC_dc_addon_welcome();
void AddSC_dc_addon_world();
void AddSC_dc_addon_groupfinder();
void AddSC_dc_addon_matchmaking();
void AddSC_DCAddon_GOMove();
void AddSC_DCAddon_NPCMove();
void AddSC_DCAddon_Decorations();
void AddSC_npc_group_finder();
void AddSC_dc_addon_duels();
void AddSC_dc_addon_prestige();
void AddDCQoSScripts();
void AddSC_dc_addon_collection();
void AddSC_dc_addon_forms();
void AddSC_dc_addon_graveyard();
void AddSC_dc_addon_death_markers();
void AddSC_dc_addon_beastmaster();
void AddSC_dc_addon_mappois();
void AddSC_dc_addon_questnav();
void AddSC_dc_addon_encounters();

namespace DCAddon { void AddTeleportScripts(); }
namespace DCAddon { void AddQuestFlowScripts(); }

void AddDCAddonExtensionScripts()
{
    // Core protocol router (must load first)
    AddSC_dc_addon_protocol();

    // Module handlers
    AddSC_dc_addon_aoeloot();
    AddSC_dc_addon_upgrade();
    AddSC_dc_addon_transmutation();
    AddSC_dc_addon_mythicplus();
    AddSC_dc_addon_spectator();
    AddSC_dc_addon_hotspot();
    AddSC_dc_addon_hlbg();
    AddSC_dc_addon_seasons();
    AddSC_dc_addon_leaderboards();
    AddSC_dc_addon_breaking_news();
    AddSC_dc_addon_welcome();
    AddSC_dc_addon_groupfinder();
    AddSC_dc_addon_matchmaking();
    AddSC_dc_addon_world();
    AddSC_DCAddon_GOMove();
    AddSC_DCAddon_NPCMove();
    AddSC_DCAddon_Decorations();
    DCAddon::AddTeleportScripts();

    // Auto-quest offer / remote turn-in popups (retail-style quest flow)
    DCAddon::AddQuestFlowScripts();

    // NPC scripts
    AddSC_npc_group_finder();

    // Duel addon handler
    AddSC_dc_addon_duels();

    // Prestige addon handler
    AddSC_dc_addon_prestige();

    // QoS addon handler (Quality of Service - QoL settings)
    AddDCQoSScripts();

    // Collection addon handler
    AddSC_dc_addon_collection();

    // Shapeshift form customization (part of the COLL module)
    AddSC_dc_addon_forms();

    // Return-to-graveyard button handler (retail-style death helper)
    AddSC_dc_addon_graveyard();

    // Death markers (world-map pins for Hardcore / Iron Prestige deaths); loads persisted
    // markers from dc_death_markers on startup.
    AddSC_dc_addon_death_markers();

    // Beastmaster hunter-pet catalog (browse + preview + adopt); reads roster
    // from dc_beastmaster_pets.
    AddSC_dc_addon_beastmaster();

    // Map POI markers (flight masters on world maps without a taxi map)
    AddSC_dc_addon_mappois();

    // Quest navigation data (native selection-circle kill entries + live
    // QuestMapData fallback resolve)
    AddSC_dc_addon_questnav();

    // Dungeon/raid boss tracker (DungeonEncounter.dbc driven checklist above
    // the quest tracker; drawn by DC-Journal)
    AddSC_dc_addon_encounters();
}
