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
void AddSC_dc_addon_welcome();
void AddSC_dc_addon_world();
void AddSC_dc_addon_groupfinder();
void AddSC_DCAddon_GOMove();
void AddSC_DCAddon_NPCMove();
void AddSC_npc_group_finder();
void AddSC_dc_addon_duels();
void AddSC_dc_addon_prestige();
void AddDCQoSScripts();
void AddSC_dc_addon_collection();

namespace DCAddon { void AddTeleportScripts(); }

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
    AddSC_dc_addon_welcome();
    AddSC_dc_addon_groupfinder();
    AddSC_dc_addon_world();
    AddSC_DCAddon_GOMove();
    AddSC_DCAddon_NPCMove();
    DCAddon::AddTeleportScripts();

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

}
