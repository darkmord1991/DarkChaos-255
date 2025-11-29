/*
 * Dark Chaos - Addon Extension Loader
 * ====================================
 * 
 * Loads all addon extension scripts for the DC namespace.
 * 
 * Copyright (C) 2024 Dark Chaos Development Team
 */

// Script declarations
void AddSC_dc_addon_protocol();
void AddSC_dc_addon_aoeloot();
void AddSC_dc_addon_upgrade();
void AddSC_dc_addon_mythicplus();
void AddSC_dc_addon_spectator();
void AddSC_dc_addon_hotspot();
void AddSC_dc_addon_hlbg();
void AddSC_dc_addon_seasons();
void AddSC_dc_addon_leaderboards();

// Future module handlers:
// void AddSC_dc_addon_duels();
// void AddSC_dc_addon_prestige();

void AddDCAddonExtensionScripts()
{
    // Core protocol router (must load first)
    AddSC_dc_addon_protocol();
    
    // Module handlers
    AddSC_dc_addon_aoeloot();
    AddSC_dc_addon_upgrade();
    AddSC_dc_addon_mythicplus();
    AddSC_dc_addon_spectator();
    AddSC_dc_addon_hotspot();
    AddSC_dc_addon_hlbg();
    AddSC_dc_addon_seasons();
    AddSC_dc_addon_leaderboards();
    
    // Future module handlers:
    // AddSC_dc_addon_duels();
    // AddSC_dc_addon_prestige();
}
