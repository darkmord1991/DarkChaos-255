/*
 * DarkChaos Item Upgrade System - Script Loader
 * 
 * This file declares all script registration functions for the item upgrade system
 * 
 * Author: DarkChaos Development Team
 * Date: November 5, 2025
 */

#pragma once

// =====================================================================
// Phase 4A: Core System
// =====================================================================
void AddItemUpgradeCommandScript();
void AddSC_ItemUpgradeVendor();
void AddSC_ItemUpgradeCurator();
void AddSC_ItemUpgradeMechanics();

// =====================================================================
// Phase 4B: Progression System
// =====================================================================
void AddSC_ItemUpgradeProgression();

// =====================================================================
// Phase 4C: Seasonal System
// =====================================================================
void AddSC_ItemUpgradeSeasonal();

// =====================================================================
// Phase 4D: Advanced Features
// =====================================================================
void AddSC_ItemUpgradeAdvanced();

// =====================================================================
// Main Loader Function
// =====================================================================
inline void AddSC_ItemUpgradeScripts()
{
    // Phase 4A: Core
    AddItemUpgradeCommandScript();
    AddSC_ItemUpgradeVendor();
    AddSC_ItemUpgradeCurator();
    AddSC_ItemUpgradeMechanics();
    
    // Phase 4B: Progression
    AddSC_ItemUpgradeProgression();
    
    // Phase 4C: Seasonal
    AddSC_ItemUpgradeSeasonal();
    
    // Phase 4D: Advanced
    AddSC_ItemUpgradeAdvanced();
}
