/*
 * DarkChaos Hotspots System
 * Refactored 2026: Modularized into HotspotMgr, HotspotGrid, etc.
 */

void AddSC_HotspotScripts();
void AddSC_dc_hotspot_commandscript();

void AddSC_ac_hotspots()
{
    AddSC_HotspotScripts();
    AddSC_dc_hotspot_commandscript();
}
