/*
 * DarkChaos Cross-System Script Loader
 *
 * Registers all cross-system scripts with AzerothCore.
 *
 * Author: DarkChaos Development Team
 * Date: January 2026
 */

#ifndef DC_CROSS_SYSTEM_LOADER_H
#define DC_CROSS_SYSTEM_LOADER_H

// Forward declarations
void AddSC_dc_cross_system_scripts();

// Main loader function - called from AzerothCore's ScriptLoader
void AddDCCrossSystemScripts()
{
    AddSC_dc_cross_system_scripts();
}

#endif // DC_CROSS_SYSTEM_LOADER_H
