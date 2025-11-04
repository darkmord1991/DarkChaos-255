/*
 * DarkChaos Item Upgrade System - Script Loader
 * 
 * This file declares all script registration functions for the item upgrade system
 * 
 * Author: DarkChaos Development Team
 * Date: November 4, 2025
 */

#pragma once

// Item Upgrade System Script Registration Functions
void AddItemUpgradeCommandScript();
void AddSC_ItemUpgradeVendor();
void AddSC_ItemUpgradeCurator();

// Main loader function
inline void AddSC_ItemUpgradeScripts()
{
    AddItemUpgradeCommandScript();
    AddSC_ItemUpgradeVendor();
    AddSC_ItemUpgradeCurator();
}
